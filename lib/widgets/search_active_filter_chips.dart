import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/search_filters.dart';

typedef SearchFilterRemove = void Function(String key, String value);

class SearchActiveFilterChips extends StatelessWidget {
  final SearchFilters filters;
  final SearchFilterRemove onRemove;
  final bool includeProjectFilters;
  final bool includeProfessionalFilters;

  const SearchActiveFilterChips({
    super.key,
    required this.filters,
    required this.onRemove,
    this.includeProjectFilters = true,
    this.includeProfessionalFilters = true,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <_FilterChipData>[
      if (includeProjectFilters)
        for (final room in filters.rooms)
          _FilterChipData('room', 'Mekan', room),
      if (!includeProjectFilters && includeProfessionalFilters)
        for (final room in filters.rooms)
          _FilterChipData('area', 'Hizmet Alanı', room),
      if (includeProjectFilters)
        for (final style in filters.styles)
          _FilterChipData('style', 'Stil', style),
      if (includeProjectFilters)
        for (final budget in filters.budgetLevels)
          _FilterChipData(
            'budget',
            'Bütçe',
            budget,
            SearchFilters.labelForBudget(budget) ?? budget,
          ),
      for (final city in filters.cities) _FilterChipData('city', 'Şehir', city),
      if (includeProfessionalFilters)
        for (final professional in filters.professionals)
          _FilterChipData('professionalType', 'Profesyonel', professional),
      if (includeProfessionalFilters)
        for (final service in filters.services)
          _FilterChipData('service', 'Hizmet', service),
      if (includeProfessionalFilters)
        for (final project in filters.projectTypes)
          _FilterChipData('project', 'Proje Tipi', project),
      if (includeProfessionalFilters)
        for (final region in filters.serviceRegions)
          _FilterChipData('serviceRegion', 'Hizmet Bölgesi', region),
      if (filters.onlyProfessionals)
        const _FilterChipData('onlyProfessionals', 'Liste', 'Profesyoneller'),
      if (filters.onlyProjects)
        const _FilterChipData('onlyProjects', 'Liste', 'Projeler'),
      if (includeProfessionalFilters && filters.hasProjects)
        const _FilterChipData('hasProjects', 'Portföy', 'Projeleri olanlar'),
      if (filters.sortBy.isNotEmpty)
        _FilterChipData(
          'sort',
          'Sıralama',
          filters.sortBy,
          SearchFilters.labelForSort(filters.sortBy) ?? filters.sortBy,
        ),
    ];

    if (chips.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final chip in chips)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InputChip(
                label: Text('${chip.title}: ${chip.label}'),
                onDeleted: () => onRemove(chip.key, chip.value),
                deleteIcon: const Icon(Icons.close, size: 16),
                labelStyle: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChipData {
  final String key;
  final String title;
  final String value;
  final String label;

  const _FilterChipData(
    this.key,
    this.title,
    this.value, [
    String? label,
  ]) : label = label ?? value;
}
