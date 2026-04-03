import 'package:flutter/material.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../widgets/designer_card.dart';
import '../../widgets/shimmer_card.dart';

class DesignersScreen extends StatefulWidget {
  const DesignersScreen({super.key});

  @override
  State<DesignersScreen> createState() => _DesignersScreenState();
}

class _DesignersScreenState extends State<DesignersScreen> {
  List<_DesignerData> _designers = [];
  List<_DesignerData> _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchController = TextEditingController();

  // Filtre state
  String? _selectedCity;
  String? _selectedSpecialty;
  bool _verifiedOnly = false;

  // Uzmanlık seçenekleri (veriden dinamik)
  List<String> _availableSpecialties = [];

  int get _activeFilterCount =>
      (_selectedCity != null ? 1 : 0) +
      (_selectedSpecialty != null ? 1 : 0) +
      (_verifiedOnly ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _fetchDesigners();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = _designers.where((d) {
        // Arama
        if (query.isNotEmpty) {
          final name = d.profile.displayName.toLowerCase();
          final specialty = (d.profile.specialty ?? '').toLowerCase();
          final city = (d.profile.city ?? '').toLowerCase();
          if (!name.contains(query) && !specialty.contains(query) && !city.contains(query)) {
            return false;
          }
        }
        // Şehir filtresi
        if (_selectedCity != null) {
          final city = (d.profile.city ?? '').trim();
          if (city != _selectedCity) return false;
        }
        // Uzmanlık filtresi
        if (_selectedSpecialty != null) {
          final sp = (d.profile.specialty ?? '').toLowerCase();
          if (!sp.contains(_selectedSpecialty!.toLowerCase())) return false;
        }
        // Doğrulanmış filtresi
        if (_verifiedOnly) {
          if (d.profile.role != 'designer') return false;
        }
        return true;
      }).toList();
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FilterSheet(
        availableSpecialties: _availableSpecialties,
        selectedCity: _selectedCity,
        selectedSpecialty: _selectedSpecialty,
        verifiedOnly: _verifiedOnly,
        onApply: (city, specialty, verified) {
          setState(() {
            _selectedCity = city;
            _selectedSpecialty = specialty;
            _verifiedOnly = verified;
          });
          _applyFilters();
          Navigator.pop(context);
        },
        onClear: () {
          setState(() {
            _selectedCity = null;
            _selectedSpecialty = null;
            _verifiedOnly = false;
          });
          _applyFilters();
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _fetchDesigners() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profilesData = await supabase
          .from('profiles')
          .select(
            'id, full_name, role, avatar_url, business_name, specialty, city, about, cover_photo_url, tags, starting_from, created_at',
          )
          .inFilter('role', ['designer', 'designer_pending'])
          .order('created_at', ascending: false);

      final profiles = (profilesData as List)
          .map((e) => Profile.fromJson(e as Map<String, dynamic>))
          .toList();

      // Fetch review counts and project counts in parallel
      final designerDataList = await Future.wait(
        profiles.map((profile) async {
          try {
            final reviewsResult = await supabase
                .from('designer_reviews')
                .select('id, rating')
                .eq('designer_id', profile.id);

            final reviews = reviewsResult as List;
            final reviewCount = reviews.length;
            final avgRating = reviewCount > 0
                ? reviews
                        .map((r) =>
                            (r as Map<String, dynamic>)['rating'] as num? ?? 0)
                        .reduce((a, b) => a + b) /
                    reviewCount
                : 0.0;

            final projectsResult = await supabase
                .from('designer_projects')
                .select('id')
                .eq('designer_id', profile.id)
                .eq('is_published', true);

            final projectCount = (projectsResult as List).length;

            return _DesignerData(
              profile: profile,
              rating: avgRating.toDouble(),
              reviewCount: reviewCount,
              projectCount: projectCount as int,
            );
          } catch (_) {
            return _DesignerData(profile: profile);
          }
        }),
      );

      // Filtre seçeneklerini çıkar
      final specialties = designerDataList
          .map((d) => (d.profile.specialty ?? '').trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()..sort();

      if (mounted) {
        setState(() {
          _designers = designerDataList;
          _filtered = designerDataList;
          _availableSpecialties = specialties;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Tasarımcılar yüklenirken hata oluştu.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tasarımcılar'),
        actions: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'Filtrele',
                onPressed: _showFilterSheet,
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$_activeFilterCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'İsim, uzmanlık veya şehir ara...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
          ),
        ),
      ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.textSecondary,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchDesigners,
                    child: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            )
          : _loading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 5,
              itemBuilder: (_, __) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: ShimmerCard(height: 180),
              ),
            )
          : _filtered.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.people_outline,
                    color: AppColors.textSecondary,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchController.text.isNotEmpty
                        ? 'Arama sonucu bulunamadı.'
                        : 'Henüz tasarımcı yok.',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchDesigners,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final data = _filtered[index];
                  return DesignerCard(
                    designer: data.profile,
                    rating: data.rating,
                    reviewCount: data.reviewCount,
                    projectCount: data.projectCount,
                  );
                },
              ),
            ),
    );
  }
}

class _DesignerData {
  final Profile profile;
  final double rating;
  final int reviewCount;
  final int projectCount;

  _DesignerData({
    required this.profile,
    this.rating = 0,
    this.reviewCount = 0,
    this.projectCount = 0,
  });
}

// ── Filter sheet ──────────────────────────────────────────────────────────────

// Türkiye'nin 81 ili
const _turkishCities = [
  'Adana','Adıyaman','Afyonkarahisar','Ağrı','Amasya','Ankara','Antalya','Artvin',
  'Aydın','Balıkesir','Bilecik','Bingöl','Bitlis','Bolu','Burdur','Bursa','Çanakkale',
  'Çankırı','Çorum','Denizli','Diyarbakır','Edirne','Elazığ','Erzincan','Erzurum',
  'Eskişehir','Gaziantep','Giresun','Gümüşhane','Hakkari','Hatay','Isparta','Mersin',
  'İstanbul','İzmir','Kars','Kastamonu','Kayseri','Kırklareli','Kırşehir','Kocaeli',
  'Konya','Kütahya','Malatya','Manisa','Kahramanmaraş','Mardin','Muğla','Muş',
  'Nevşehir','Niğde','Ordu','Rize','Sakarya','Samsun','Siirt','Sinop','Sivas',
  'Tekirdağ','Tokat','Trabzon','Tunceli','Şanlıurfa','Uşak','Van','Yozgat',
  'Zonguldak','Aksaray','Bayburt','Karaman','Kırıkkale','Batman','Şırnak','Bartın',
  'Ardahan','Iğdır','Yalova','Karabük','Kilis','Osmaniye','Düzce',
];

class _FilterSheet extends StatefulWidget {
  final List<String> availableSpecialties;
  final String? selectedCity;
  final String? selectedSpecialty;
  final bool verifiedOnly;
  final void Function(String? city, String? specialty, bool verified) onApply;
  final VoidCallback onClear;

  const _FilterSheet({
    required this.availableSpecialties,
    required this.selectedCity,
    required this.selectedSpecialty,
    required this.verifiedOnly,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _city;
  late String? _specialty;
  late bool _verified;

  @override
  void initState() {
    super.initState();
    _city = widget.selectedCity;
    _specialty = widget.selectedSpecialty;
    _verified = widget.verifiedOnly;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle + Başlık
            Center(
              child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Filtreler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                TextButton(onPressed: widget.onClear, child: const Text('Temizle')),
              ],
            ),
            const SizedBox(height: 16),

            // Şehir
            const Text('Şehir', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _city,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: 'Tümü',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('Tümü')),
                ..._turkishCities.map((c) => DropdownMenuItem(value: c, child: Text(c))),
              ],
              onChanged: (v) => setState(() => _city = v),
            ),
            const SizedBox(height: 16),

            // Uzmanlık
            const Text('Uzmanlık', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _specialty,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: 'Tümü',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('Tümü')),
                ...widget.availableSpecialties.map((s) => DropdownMenuItem(value: s, child: Text(s))),
              ],
              onChanged: (v) => setState(() => _specialty = v),
            ),
            const SizedBox(height: 16),

            // Doğrulanmış
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Yalnızca Doğrulanmış', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              value: _verified,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _verified = v),
            ),
            const SizedBox(height: 8),

            // Uygula
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => widget.onApply(_city, _specialty, _verified),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Filtrele', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
