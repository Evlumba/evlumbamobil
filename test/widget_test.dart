import 'package:flutter_test/flutter_test.dart';

import 'package:evlumba_mobile/models/profile.dart';
import 'package:evlumba_mobile/models/designer_project.dart';

void main() {
  group('Profile', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'id': 'user-1',
        'full_name': 'Ali Yılmaz',
        'role': 'designer',
        'avatar_url': 'https://example.com/avatar.jpg',
        'business_name': 'Ali Tasarım',
        'specialty': 'İç Mimarlık',
        'city': 'İstanbul',
        'about': 'Deneyimli tasarımcı',
        'phone': '555-1234',
        'contact_email': 'ali@example.com',
        'address': 'Kadıköy, İstanbul',
        'website': 'https://ali.com',
        'instagram': 'ali_design',
        'facebook': 'alidesign',
        'linkedin': 'aliyilmaz',
        'cover_photo_url': 'https://example.com/cover.jpg',
        'tags': ['modern', 'minimalist'],
        'response_time': '1 saat',
        'starting_from': '5000',
        'created_at': '2024-01-15T10:30:00Z',
      };

      final profile = Profile.fromJson(json);

      expect(profile.id, 'user-1');
      expect(profile.fullName, 'Ali Yılmaz');
      expect(profile.role, 'designer');
      expect(profile.avatarUrl, 'https://example.com/avatar.jpg');
      expect(profile.businessName, 'Ali Tasarım');
      expect(profile.specialty, 'İç Mimarlık');
      expect(profile.city, 'İstanbul');
      expect(profile.about, 'Deneyimli tasarımcı');
      expect(profile.phone, '555-1234');
      expect(profile.contactEmail, 'ali@example.com');
      expect(profile.coverPhotoUrl, 'https://example.com/cover.jpg');
      expect(profile.tags, ['modern', 'minimalist']);
      expect(profile.responseTime, '1 saat');
      expect(profile.startingFrom, '5000');
      expect(profile.createdAt, DateTime.utc(2024, 1, 15, 10, 30));
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'user-2',
        'role': 'homeowner',
        'created_at': '2024-06-01T00:00:00Z',
      };

      final profile = Profile.fromJson(json);

      expect(profile.id, 'user-2');
      expect(profile.fullName, isNull);
      expect(profile.role, 'homeowner');
      expect(profile.avatarUrl, isNull);
      expect(profile.city, isNull);
      expect(profile.tags, isEmpty);
    });

    test('fromJson defaults role to homeowner when null', () {
      final json = {'id': 'user-3', 'created_at': '2024-01-01T00:00:00Z'};
      final profile = Profile.fromJson(json);
      expect(profile.role, 'homeowner');
    });

    test('displayName returns fullName when available', () {
      final profile = Profile(
        id: '1',
        role: 'homeowner',
        fullName: 'Ayşe Kara',
        createdAt: DateTime.now(),
      );
      expect(profile.displayName, 'Ayşe Kara');
    });

    test('displayName falls back to businessName', () {
      final profile = Profile(
        id: '1',
        role: 'designer',
        fullName: '',
        businessName: 'Kara Tasarım',
        createdAt: DateTime.now(),
      );
      expect(profile.displayName, 'Kara Tasarım');
    });

    test('displayName returns Kullanıcı when no name available', () {
      final profile = Profile(
        id: '1',
        role: 'homeowner',
        createdAt: DateTime.now(),
      );
      expect(profile.displayName, 'Kullanıcı');
    });

    test('isDesigner returns true for designer and designer_pending', () {
      final designer = Profile(id: '1', role: 'designer', createdAt: DateTime.now());
      final pending = Profile(id: '2', role: 'designer_pending', createdAt: DateTime.now());
      final homeowner = Profile(id: '3', role: 'homeowner', createdAt: DateTime.now());

      expect(designer.isDesigner, isTrue);
      expect(pending.isDesigner, isTrue);
      expect(homeowner.isDesigner, isFalse);
    });

    test('isAdmin returns true for admin and super_admin', () {
      final admin = Profile(id: '1', role: 'admin', createdAt: DateTime.now());
      final superAdmin = Profile(id: '2', role: 'super_admin', createdAt: DateTime.now());
      final homeowner = Profile(id: '3', role: 'homeowner', createdAt: DateTime.now());

      expect(admin.isAdmin, isTrue);
      expect(superAdmin.isAdmin, isTrue);
      expect(homeowner.isAdmin, isFalse);
    });

    test('toJson produces correct output', () {
      final profile = Profile(
        id: 'user-1',
        fullName: 'Test User',
        role: 'designer',
        city: 'Ankara',
        tags: ['modern'],
        createdAt: DateTime.now(),
      );

      final json = profile.toJson();

      expect(json['id'], 'user-1');
      expect(json['full_name'], 'Test User');
      expect(json['role'], 'designer');
      expect(json['city'], 'Ankara');
      expect(json['tags'], ['modern']);
    });

    test('copyWith overrides specified fields', () {
      final original = Profile(
        id: '1',
        fullName: 'Original',
        role: 'homeowner',
        city: 'İstanbul',
        createdAt: DateTime.now(),
      );

      final updated = original.copyWith(fullName: 'Updated', city: 'Ankara');

      expect(updated.id, '1');
      expect(updated.fullName, 'Updated');
      expect(updated.city, 'Ankara');
      expect(updated.role, 'homeowner');
    });
  });

  group('DesignerProject', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'id': 'proj-1',
        'designer_id': 'user-1',
        'title': 'Modern Salon',
        'project_type': 'Oturma Odası',
        'location': 'İstanbul',
        'description': 'Modern bir salon tasarımı',
        'tags': ['modern', 'salon'],
        'budget_level': 'medium',
        'cover_image_url': 'https://example.com/cover.jpg',
        'is_published': true,
        'created_at': '2024-03-01T12:00:00Z',
        'designer_project_images': [
          {'image_url': 'https://example.com/img2.jpg', 'sort_order': 1},
          {'image_url': 'https://example.com/img1.jpg', 'sort_order': 0},
        ],
        'designer_project_shop_links': [
          {
            'id': 'link-1',
            'image_url': 'https://example.com/img1.jpg',
            'pos_x': 30.0,
            'pos_y': 40.0,
            'product_url': 'https://shop.com/product',
            'product_title': 'Koltuk',
            'product_price': '₺5,000',
          },
        ],
        'profiles': {'full_name': 'Ali Yılmaz'},
      };

      final project = DesignerProject.fromJson(json);

      expect(project.id, 'proj-1');
      expect(project.designerId, 'user-1');
      expect(project.title, 'Modern Salon');
      expect(project.projectType, 'Oturma Odası');
      expect(project.location, 'İstanbul');
      expect(project.tags, ['modern', 'salon']);
      expect(project.budgetLevel, 'medium');
      expect(project.isPublished, isTrue);
      expect(project.designerName, 'Ali Yılmaz');
      // Images sorted by sort_order
      expect(project.images.length, 2);
      expect(project.images.first.imageUrl, 'https://example.com/img1.jpg');
      expect(project.images.last.imageUrl, 'https://example.com/img2.jpg');
      // Shop links
      expect(project.shopLinks.length, 1);
      expect(project.shopLinks.first.productTitle, 'Koltuk');
      expect(project.shopLinks.first.posX, 30.0);
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'proj-2',
        'created_at': '2024-01-01T00:00:00Z',
      };

      final project = DesignerProject.fromJson(json);

      expect(project.id, 'proj-2');
      expect(project.designerId, '');
      expect(project.title, '');
      expect(project.projectType, isNull);
      expect(project.isPublished, isFalse);
      expect(project.images, isEmpty);
      expect(project.shopLinks, isEmpty);
      expect(project.tags, isEmpty);
    });

    test('budgetLabel returns correct symbols', () {
      DesignerProject withBudget(String level) => DesignerProject(
            id: '1',
            designerId: 'd1',
            title: 'Test',
            budgetLevel: level,
            createdAt: DateTime.now(),
          );

      expect(withBudget('low').budgetLabel, '₺');
      expect(withBudget('medium').budgetLabel, '₺₺');
      expect(withBudget('high').budgetLabel, '₺₺₺');
      expect(withBudget('pro').budgetLabel, 'Pro');
      expect(withBudget('unknown').budgetLabel, '');
    });

    test('displayCoverUrl prefers first image over coverImageUrl', () {
      final project = DesignerProject(
        id: '1',
        designerId: 'd1',
        title: 'Test',
        coverImageUrl: 'https://example.com/cover.jpg',
        images: const [ProjectImage(imageUrl: 'https://example.com/img1.jpg', sortOrder: 0)],
        createdAt: DateTime.now(),
      );

      expect(project.displayCoverUrl, 'https://example.com/img1.jpg');
    });

    test('displayCoverUrl falls back to coverImageUrl', () {
      final project = DesignerProject(
        id: '1',
        designerId: 'd1',
        title: 'Test',
        coverImageUrl: 'https://example.com/cover.jpg',
        createdAt: DateTime.now(),
      );

      expect(project.displayCoverUrl, 'https://example.com/cover.jpg');
    });

    test('displayCoverUrl returns empty string when no images', () {
      final project = DesignerProject(
        id: '1',
        designerId: 'd1',
        title: 'Test',
        createdAt: DateTime.now(),
      );

      expect(project.displayCoverUrl, '');
    });

    test('toJson produces correct output', () {
      final project = DesignerProject(
        id: 'proj-1',
        designerId: 'user-1',
        title: 'Salon',
        projectType: 'Oturma Odası',
        isPublished: true,
        tags: ['modern'],
        createdAt: DateTime.now(),
      );

      final json = project.toJson();

      expect(json['designer_id'], 'user-1');
      expect(json['title'], 'Salon');
      expect(json['project_type'], 'Oturma Odası');
      expect(json['is_published'], isTrue);
      expect(json['tags'], ['modern']);
    });

    test('copyWith overrides specified fields', () {
      final original = DesignerProject(
        id: '1',
        designerId: 'd1',
        title: 'Original',
        isPublished: false,
        createdAt: DateTime.now(),
      );

      final updated = original.copyWith(title: 'Updated', isPublished: true);

      expect(updated.id, '1');
      expect(updated.title, 'Updated');
      expect(updated.isPublished, isTrue);
      expect(updated.designerId, 'd1');
    });
  });

  group('ProjectImage', () {
    test('fromJson parses correctly', () {
      final img = ProjectImage.fromJson({
        'image_url': 'https://example.com/img.jpg',
        'sort_order': 3,
      });
      expect(img.imageUrl, 'https://example.com/img.jpg');
      expect(img.sortOrder, 3);
    });

    test('fromJson handles null values', () {
      final img = ProjectImage.fromJson({});
      expect(img.imageUrl, '');
      expect(img.sortOrder, 0);
    });
  });

  group('ShopLink', () {
    test('fromJson parses correctly', () {
      final link = ShopLink.fromJson({
        'id': 'sl-1',
        'image_url': 'https://example.com/img.jpg',
        'pos_x': 25.5,
        'pos_y': 75.0,
        'product_url': 'https://shop.com/item',
        'product_title': 'Masa',
        'product_image_url': 'https://shop.com/img.jpg',
        'product_price': '₺2,500',
      });

      expect(link.id, 'sl-1');
      expect(link.posX, 25.5);
      expect(link.posY, 75.0);
      expect(link.productTitle, 'Masa');
      expect(link.productPrice, '₺2,500');
    });

    test('fromJson defaults pos to 50 when null', () {
      final link = ShopLink.fromJson({
        'id': 'sl-2',
        'product_url': '',
      });

      expect(link.posX, 50.0);
      expect(link.posY, 50.0);
      expect(link.imageUrl, '');
    });
  });
}
