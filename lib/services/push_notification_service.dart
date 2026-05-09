import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _messageChannelId = 'evlumba_messages';
const _messageChannelName = 'Mesajlar';
const _messageChannelDescription = 'Yeni mesaj bildirimleri';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadDotEnvIfNeeded();
  final initialized = await PushNotificationService.ensureFirebaseInitialized();
  if (!initialized) return;

  await PushNotificationService.initializeLocalNotifications();
  await PushNotificationService.showMessageNotification(message);
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  GoRouter? _router;
  StreamSubscription<AuthState>? _authSubscription;
  bool _initialized = false;
  bool _localInitialized = false;

  static Future<bool> ensureFirebaseInitialized() async {
    if (Firebase.apps.isNotEmpty) return true;
    final options = _FirebaseEnvOptions.currentPlatform;
    if (options == null) return false;

    await Firebase.initializeApp(options: options);
    return true;
  }

  static Future<void> configureBackgroundHandling() async {
    final initialized = await ensureFirebaseInitialized();
    if (!initialized) return;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    final firebaseReady = await ensureFirebaseInitialized();
    if (!firebaseReady) return;

    _initialized = true;
    await initializeLocalNotifications(
      onTap: (payload) => _openPayload(payload),
    );
    await _configureForegroundDelivery();
    await _requestPermissions();
    await _registerCurrentUserToken();
    await _handleInitialNotificationTap();

    FirebaseMessaging.onMessage.listen((message) async {
      final senderId = message.data['senderId'];
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (senderId != null && senderId == currentUserId) return;
      await showMessageNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _openMessage(message);
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      unawaited(_registerCurrentUserToken());
    });

    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedIn ||
          event.event == AuthChangeEvent.tokenRefreshed ||
          event.event == AuthChangeEvent.userUpdated) {
        unawaited(_registerCurrentUserToken());
      } else if (event.event == AuthChangeEvent.signedOut) {
        unawaited(_deactivateCurrentDeviceToken());
      }
    });
  }

  void attachRouter(GoRouter router) {
    _router = router;
  }

  Future<void> notifyMessageCreated(String messageId) async {
    if (messageId.isEmpty) return;
    try {
      await Supabase.instance.client.functions.invoke(
        'send-message-notification',
        body: {'messageId': messageId},
      );
    } catch (_) {
      // Mesaj gönderimi başarılıysa bildirimin aksaması kullanıcı akışını bozmasın.
    }
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
  }

  static Future<void> initializeLocalNotifications({
    void Function(String? payload)? onTap,
  }) async {
    if (instance._localInitialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      settings: const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) {
        onTap?.call(response.payload);
      },
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          _messageChannelId,
          _messageChannelName,
          description: _messageChannelDescription,
          importance: Importance.high,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 180, 80, 180]),
        ),
      );
    }

    instance._localInitialized = true;
  }

  static Future<void> showMessageNotification(RemoteMessage message) async {
    if (message.data['type'] != 'message') return;

    await initializeLocalNotifications();

    final title = _textOrFallback(
      message.notification?.title ?? message.data['senderName'],
      'Yeni mesaj',
    );
    final body = _textOrFallback(
      message.notification?.body ?? message.data['body'],
      'Yeni bir mesajın var.',
    );

    await _localNotifications.show(
      id: _stableNotificationId(message),
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _messageChannelId,
          _messageChannelName,
          channelDescription: _messageChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 180, 80, 180]),
          playSound: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  Future<void> _configureForegroundDelivery() async {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );
  }

  Future<void> _requestPermissions() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> _handleInitialNotificationTap() async {
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _openMessage(initialMessage);
      return;
    }

    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    final payload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true) {
      _openPayload(payload);
    }
  }

  Future<void> _registerCurrentUserToken() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;

    try {
      await Supabase.instance.client.rpc('register_push_token', params: {
        'p_token': token,
        'p_platform': _platformName,
      });
    } catch (_) {
      // Migration uygulanmamışsa veya bağlantı kopuksa uygulama sessiz devam eder.
    }
  }

  Future<void> _deactivateCurrentDeviceToken() async {
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await Supabase.instance.client.rpc('deactivate_push_token', params: {
        'p_token': token,
      });
    } catch (_) {}
  }

  void _openMessage(RemoteMessage message) {
    _openData(message.data);
  }

  void _openPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload);
      if (data is Map<String, dynamic>) _openData(data);
    } catch (_) {}
  }

  void _openData(Map<String, dynamic> data) {
    final router = _router;
    if (router == null) return;

    final conversationId = data['conversationId']?.toString();
    if (conversationId == null || conversationId.isEmpty) {
      router.go('/messages');
      return;
    }

    final params = <String, String>{};
    _addParam(params, 'name', data['senderName']);
    _addParam(params, 'avatar', data['avatar']);
    _addParam(params, 'specialty', data['specialty']);
    _addParam(params, 'userId', data['senderId']);
    final query =
        params.isEmpty ? '' : '?${Uri(queryParameters: params).query}';

    router.go('/chat/$conversationId$query');
  }

  static void _addParam(
    Map<String, String> params,
    String key,
    Object? value,
  ) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) params[key] = text;
  }

  static String get _platformName {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  static String _textOrFallback(Object? value, String fallback) {
    final text = value?.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text == null || text.isEmpty) return fallback;
    return text.length <= 120 ? text : '${text.substring(0, 117)}...';
  }

  static int _stableNotificationId(RemoteMessage message) {
    final seed = message.messageId ?? message.data['messageId'] ?? 'evlumba';
    return seed.hashCode & 0x7fffffff;
  }
}

class _FirebaseEnvOptions {
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return null;

    final projectId = _env('FIREBASE_PROJECT_ID');
    final messagingSenderId = _env('FIREBASE_MESSAGING_SENDER_ID');
    final apiKey = switch (defaultTargetPlatform) {
      TargetPlatform.iOS =>
        _env('FIREBASE_IOS_API_KEY') ?? _env('FIREBASE_API_KEY'),
      _ => _env('FIREBASE_ANDROID_API_KEY') ?? _env('FIREBASE_API_KEY'),
    };
    final appId = switch (defaultTargetPlatform) {
      TargetPlatform.iOS =>
        _env('FIREBASE_IOS_APP_ID') ?? _env('FIREBASE_APP_ID'),
      _ => _env('FIREBASE_ANDROID_APP_ID') ?? _env('FIREBASE_APP_ID'),
    };

    if (projectId == null ||
        messagingSenderId == null ||
        apiKey == null ||
        appId == null) {
      return null;
    }

    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: _env('FIREBASE_STORAGE_BUCKET'),
      iosBundleId: defaultTargetPlatform == TargetPlatform.iOS
          ? _env('FIREBASE_IOS_BUNDLE_ID')
          : null,
    );
  }

  static String? _env(String key) {
    final value = dotenv.env[key]?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}

Future<void> _loadDotEnvIfNeeded() async {
  if (dotenv.isInitialized) return;
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
}
