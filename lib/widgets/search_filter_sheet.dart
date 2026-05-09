import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/search_filters.dart';

enum SearchFilterSheetMode { home, designers, explore }

enum SearchFilterSheetContent { filters, sort, all }

class SearchFilterSheet extends StatefulWidget {
  final SearchFilters filters;
  final SearchFilterSheetMode mode;
  final bool expandSort;
  final SearchFilterSheetContent content;

  const SearchFilterSheet({
    super.key,
    required this.filters,
    this.mode = SearchFilterSheetMode.home,
    this.expandSort = false,
    this.content = SearchFilterSheetContent.all,
  });

  @override
  State<SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<SearchFilterSheet> {
  late SearchFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.filters;
  }

  @override
  Widget build(BuildContext context) {
    final showSort = _showSort;
    final showFilters = _showFilters;

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize:
            widget.content == SearchFilterSheetContent.sort ? 0.38 : 0.82,
        minChildSize:
            widget.content == SearchFilterSheetContent.sort ? 0.26 : 0.45,
        maxChildSize:
            widget.content == SearchFilterSheetContent.sort ? 0.58 : 0.94,
        builder: (context, controller) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(
                            _clearVisibleContent,
                          ),
                          child: const Text('Temizle'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  children: [
                    if (showSort)
                      _SortSection(
                        selectedValue: _filters.sortBy,
                        options: _sortOptions,
                        initiallyExpanded:
                            widget.content == SearchFilterSheetContent.sort ||
                                widget.expandSort,
                        onChanged: (value) => setState(
                          () => _filters = _filters.copyWith(sortBy: value),
                        ),
                      ),
                    if (showFilters &&
                        widget.mode == SearchFilterSheetMode.home) ...[
                      SearchMultiSelectSection(
                        title: 'Mekan',
                        selectedValues: _filters.rooms,
                        options: SearchFilters.roomOptions,
                        onToggle: (value) => setState(
                          () => _filters = _filters.toggleValue('room', value),
                        ),
                        onSetValues: (values) => setState(
                          () => _filters = _filters.copyWith(rooms: values),
                        ),
                      ),
                      SearchMultiSelectSection(
                        title: 'Stil',
                        selectedValues: _filters.styles,
                        options: SearchFilters.styleOptions,
                        onToggle: (value) => setState(
                          () => _filters = _filters.toggleValue('style', value),
                        ),
                        onSetValues: (values) => setState(
                          () => _filters = _filters.copyWith(styles: values),
                        ),
                      ),
                      SearchMultiSelectSection(
                        title: 'Bütçe',
                        selectedValues: _filters.budgetLevels,
                        options: SearchFilters.budgetLabels.keys.toList(),
                        labelForValue: (value) =>
                            SearchFilters.labelForBudget(value) ?? value,
                        onToggle: (value) => setState(
                          () =>
                              _filters = _filters.toggleValue('budget', value),
                        ),
                        onSetValues: (values) => setState(
                          () => _filters =
                              _filters.copyWith(budgetLevels: values),
                        ),
                      ),
                      SearchMultiSelectSection(
                        title: 'Şehir',
                        selectedValues: _filters.cities,
                        options: SearchFilters.cityOptions,
                        onToggle: (value) => setState(
                          () => _filters = _filters.toggleValue('city', value),
                        ),
                        onSetValues: (values) => setState(
                          () => _filters = _filters.copyWith(cities: values),
                        ),
                      ),
                      SearchMultiSelectSection(
                        title: 'Profesyonel',
                        selectedValues: _filters.professionals,
                        options: SearchFilters.professionalOptions,
                        onToggle: (value) => setState(
                          () => _filters =
                              _filters.toggleValue('professional', value),
                        ),
                        onSetValues: (values) => setState(
                          () => _filters =
                              _filters.copyWith(professionals: values),
                        ),
                      ),
                      _SwitchTile(
                        title: 'Sadece profesyonelleri listele',
                        value: _filters.onlyProfessionals,
                        onChanged: (value) => setState(
                          () => _filters = _filters.copyWith(
                            onlyProfessionals: value,
                            onlyProjects: value ? false : _filters.onlyProjects,
                          ),
                        ),
                      ),
                      _SwitchTile(
                        title: 'Sadece projeleri listele',
                        value: _filters.onlyProjects,
                        onChanged: (value) => setState(
                          () => _filters = _filters.copyWith(
                            onlyProjects: value,
                            onlyProfessionals:
                                value ? false : _filters.onlyProfessionals,
                          ),
                        ),
                      ),
                    ] else if (showFilters &&
                        widget.mode == SearchFilterSheetMode.designers) ...[
                      SearchMultiSelectSection(
                        title: 'Profesyonel Türü',
                        selectedValues: _filters.professionals,
                        options: SearchFilters.professionalOptions,
                        onToggle: (value) => setState(
                          () => _filters =
                              _filters.toggleValue('professionalType', value),
                        ),
                        onSetValues: (values) => setState(
                          () => _filters =
                              _filters.copyWith(professionals: values),
                        ),
                      ),
                      SearchMultiSelectSection(
                        title: 'Hizmetler',
                        selectedValues: _filters.services,
                        options: SearchFilters.serviceOptions,
                        onToggle: (value) => setState(
                          () =>
                              _filters = _filters.toggleValue('service', value),
                        ),
                        onSetValues: (values) => setState(
                          () => _filters = _filters.copyWith(services: values),
                        ),
                      ),
                      SearchMultiSelectSection(
                        title: 'Proje Tipleri',
                        selectedValues: _filters.projectTypes,
                        options: SearchFilters.projectTypeOptions,
                        onToggle: (value) => setState(
                          () =>
                              _filters = _filters.toggleValue('project', value),
                        ),
                        onSetValues: (values) => setState(
                          () => _filters =
                              _filters.copyWith(projectTypes: values),
                        ),
                      ),
                      SearchMultiSelectSection(
                        title: 'Hizmet Alanları',
                        selectedValues: _filters.rooms,
                        options: SearchFilters.roomOptions,
                        onToggle: (value) => setState(
                          () => _filters = _filters.toggleValue('area', value),
                        ),
                        onSetValues: (values) => setState(
                          () => _filters = _filters.copyWith(rooms: values),
                        ),
                      ),
                      SearchMultiSelectSection(
                        title: 'Şehir',
                        selectedValues: _filters.cities,
                        options: SearchFilters.cityOptions,
                        onToggle: (value) => setState(
                          () => _filters = _filters.toggleValue('city', value),
                        ),
                        onSetValues: (values) => setState(
                          () => _filters = _filters.copyWith(cities: values),
                        ),
                      ),
                      SearchMultiSelectSection(
                        title: 'Hizmet Bölgeleri',
                        selectedValues: _filters.serviceRegions,
                        options: SearchFilters.serviceRegionOptions,
                        onToggle: (value) => setState(
                          () => _filters =
                              _filters.toggleValue('serviceRegion', value),
                        ),
                        onSetValues: (values) => setState(
                          () => _filters =
                              _filters.copyWith(serviceRegions: values),
                        ),
                      ),
                      _SwitchTile(
                        title: 'Sadece projeleri olan profesyonelleri göster',
                        value: _filters.hasProjects,
                        onChanged: (value) => setState(
                          () =>
                              _filters = _filters.copyWith(hasProjects: value),
                        ),
                      ),
                    ] else if (showFilters) ...[
                      SearchMultiSelectSection(
                        title: 'Stil',
                        selectedValues: _filters.styles,
                        options: SearchFilters.styleOptions,
                        onToggle: (value) => setState(
                          () => _filters = _filters.toggleValue('style', value),
                        ),
                        onSetValues: (values) => setState(
                          () => _filters = _filters.copyWith(styles: values),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _filters),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Uygula',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<String> get _sortOptions {
    return switch (widget.mode) {
      SearchFilterSheetMode.explore => SearchFilters.exploreSortOptions,
      SearchFilterSheetMode.designers => SearchFilters.designerSortOptions,
      SearchFilterSheetMode.home => SearchFilters.sortOptions,
    };
  }

  bool get _showSort =>
      widget.content == SearchFilterSheetContent.sort ||
      widget.content == SearchFilterSheetContent.all;

  bool get _showFilters =>
      widget.content == SearchFilterSheetContent.filters ||
      widget.content == SearchFilterSheetContent.all;

  String get _title {
    return switch (widget.content) {
      SearchFilterSheetContent.sort => 'Sıralama',
      SearchFilterSheetContent.filters => 'Filtreleme',
      SearchFilterSheetContent.all =>
        _sortOptions.isEmpty ? 'Filtreleme' : 'Filtreleme ve Sıralama',
    };
  }

  void _clearVisibleContent() {
    if (widget.content == SearchFilterSheetContent.sort) {
      _filters = _filters.copyWith(clearSort: true);
      return;
    }

    if (widget.content == SearchFilterSheetContent.filters) {
      _filters = _filters.copyWith(
        clearRooms: true,
        clearStyles: true,
        clearBudgets: true,
        clearCities: true,
        clearProfessionals: true,
        clearServices: true,
        clearProjectTypes: true,
        clearServiceRegions: true,
        onlyProfessionals: false,
        onlyProjects: false,
        hasProjects: false,
      );
      return;
    }

    _filters = const SearchFilters();
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile.adaptive(
        value: value,
        activeThumbColor: AppColors.primary,
        onChanged: onChanged,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _SortSection extends StatefulWidget {
  final String selectedValue;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final bool initiallyExpanded;

  const _SortSection({
    required this.selectedValue,
    required this.options,
    required this.onChanged,
    this.initiallyExpanded = false,
  });

  @override
  State<_SortSection> createState() => _SortSectionState();
}

class _SortSectionState extends State<_SortSection> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final summary =
        SearchFilters.labelForSort(widget.selectedValue) ?? 'Varsayılan';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.sort_rounded,
                      size: 19,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sıralama',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          summary,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            fontWeight: widget.selectedValue.isEmpty
                                ? FontWeight.w400
                                : FontWeight.w700,
                            color: widget.selectedValue.isEmpty
                                ? AppColors.textSecondary
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 0, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _SortOptionRow(
                      label: 'Varsayılan',
                      selected: widget.selectedValue.isEmpty,
                      showDivider: true,
                      onTap: () => widget.onChanged(''),
                    ),
                    for (var i = 0; i < widget.options.length; i++)
                      _SortOptionRow(
                        label: SearchFilters.labelForSort(
                              widget.options[i],
                            ) ??
                            widget.options[i],
                        selected: widget.selectedValue == widget.options[i],
                        showDivider: i < widget.options.length - 1,
                        onTap: () => widget.onChanged(widget.options[i]),
                      ),
                  ],
                ),
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 160),
            firstCurve: Curves.easeOut,
            secondCurve: Curves.easeOut,
            sizeCurve: Curves.easeOut,
          ),
          const Divider(height: 1, color: AppColors.border),
        ],
      ),
    );
  }
}

class SearchMultiSelectSection extends StatefulWidget {
  final String title;
  final List<String> selectedValues;
  final List<String> options;
  final String Function(String value)? labelForValue;
  final ValueChanged<String> onToggle;
  final ValueChanged<List<String>>? onSetValues;
  final bool initiallyExpanded;

  const SearchMultiSelectSection({
    super.key,
    required this.title,
    required this.selectedValues,
    required this.options,
    required this.onToggle,
    this.onSetValues,
    this.labelForValue,
    this.initiallyExpanded = false,
  });

  @override
  State<SearchMultiSelectSection> createState() =>
      _SearchMultiSelectSectionState();
}

class _SearchMultiSelectSectionState extends State<SearchMultiSelectSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = widget.options.isNotEmpty &&
        widget.options.every(widget.selectedValues.contains);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _summary,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            fontWeight: widget.selectedValues.isEmpty
                                ? FontWeight.w400
                                : FontWeight.w700,
                            color: widget.selectedValues.isEmpty
                                ? AppColors.textSecondary
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 0, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    if (widget.onSetValues != null)
                      _OptionRow(
                        label: allSelected ? 'Tümünü kaldır' : 'Tümünü seç',
                        selected: allSelected,
                        showDivider: widget.options.isNotEmpty,
                        onTap: () => widget.onSetValues!(
                          allSelected ? const [] : [...widget.options],
                        ),
                      ),
                    for (var i = 0; i < widget.options.length; i++)
                      _OptionRow(
                        label: _label(widget.options[i]),
                        selected:
                            widget.selectedValues.contains(widget.options[i]),
                        showDivider: i < widget.options.length - 1,
                        onTap: () => widget.onToggle(widget.options[i]),
                      ),
                  ],
                ),
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 160),
            firstCurve: Curves.easeOut,
            secondCurve: Curves.easeOut,
            sizeCurve: Curves.easeOut,
          ),
          const Divider(height: 1, color: AppColors.border),
        ],
      ),
    );
  }

  String get _summary {
    if (widget.selectedValues.isEmpty) return 'Tümü';
    return widget.selectedValues.map(_label).join(', ');
  }

  String _label(String value) => widget.labelForValue?.call(value) ?? value;
}

class _SortOptionRow extends StatelessWidget {
  final String label;
  final bool selected;
  final bool showDivider;
  final VoidCallback onTap;

  const _SortOptionRow({
    required this.label,
    required this.selected,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            color: selected ? AppColors.primary.withValues(alpha: 0.06) : null,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      color:
                          selected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 44, color: AppColors.border),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String label;
  final bool selected;
  final bool showDivider;
  final VoidCallback onTap;

  const _OptionRow({
    required this.label,
    required this.selected,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Container(
            color: selected ? AppColors.primary.withValues(alpha: 0.06) : null,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: selected,
                    onChanged: (_) => onTap(),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color:
                          selected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 44, color: AppColors.border),
      ],
    );
  }
}
