import 'package:flutter/material.dart';

import '../../models/transmission.dart';

enum HistoryCategory { all, dons, prets, enCours, rendus }

extension HistoryCategoryLabel on HistoryCategory {
  String get label {
    switch (this) {
      case HistoryCategory.all:
        return 'Toutes les opérations';
      case HistoryCategory.dons:
        return 'Dons uniquement';
      case HistoryCategory.prets:
        return 'Tous les prêts';
      case HistoryCategory.enCours:
        return 'Prêts en cours';
      case HistoryCategory.rendus:
        return 'Prêts rendus';
    }
  }

  bool matches(Transmission item) {
    switch (this) {
      case HistoryCategory.all:
        return true;
      case HistoryCategory.dons:
        return item.type == TransmissionType.don;
      case HistoryCategory.prets:
        return item.type == TransmissionType.pret;
      case HistoryCategory.enCours:
        return item.isActiveLoan;
      case HistoryCategory.rendus:
        return item.type == TransmissionType.pret &&
            item.loanStatus == LoanStatus.rendu;
    }
  }
}

/// Les années sont calculées à partir des vraies transmissions, sans choix
/// artificiels ni filtre de date côté serveur.
List<int> historyYears(Iterable<Transmission> transmissions) {
  final years = transmissions.map((item) => item.createdAt.toLocal().year).toSet();
  return years.toList()..sort((a, b) => b.compareTo(a));
}

/// Filtrage commun Web/Android : la recherche et les menus se combinent.
List<Transmission> filterHistory(
    Iterable<Transmission> source, {
      HistoryCategory category = HistoryCategory.all,
      int? year,
      String query = '',
    }) {
  final needle = query.trim().toLowerCase();
  return source.where((item) {
    if (!category.matches(item)) return false;
    if (year != null && item.createdAt.toLocal().year != year) return false;
    if (needle.isEmpty) return true;

    final searchable = [
      item.type.apiValue,
      item.type.label,
      item.equipmentType,
      item.equipmentModel ?? '',
      item.customEquipment ?? '',
      ...item.allItems.map((material) => material.label),
      item.beneficiary,
      item.content,
      item.author,
      item.loanStatus?.apiValue ?? '',
      item.loanStatus?.label ?? '',
      item.returnComment ?? '',
      item.signerName ?? '',
    ].join(' ').toLowerCase();
    return searchable.contains(needle);
  }).toList();
}

/// Barre de filtres compacte et responsive pour Web et Android.
/// Ne change pas les donnees ni la logique du filtrage.
class HistoryFilters extends StatelessWidget {
  final HistoryCategory category;
  final int? year;
  final List<int> years;
  final ValueChanged<HistoryCategory> onCategoryChanged;
  final ValueChanged<int?> onYearChanged;
  final VoidCallback onReset;

  const HistoryFilters({
    super.key,
    required this.category,
    required this.year,
    required this.years,
    required this.onCategoryChanged,
    required this.onYearChanged,
    required this.onReset,
  });

  static const _selected = Color(0xFF176678);
  static const _ink = Color(0xFF234B55);
  static const _subtle = Color(0xFFF4F8F9);
  static const _outline = Color(0xFFDCEBED);

  String _shortLabel(HistoryCategory value) {
    switch (value) {
      case HistoryCategory.all:
        return 'Tout';
      case HistoryCategory.dons:
        return 'Dons';
      case HistoryCategory.prets:
        return 'Prêts';
      case HistoryCategory.enCours:
        return 'En cours';
      case HistoryCategory.rendus:
        return 'Rendus';
    }
  }

  IconData _icon(HistoryCategory value) {
    switch (value) {
      case HistoryCategory.all:
        return Icons.grid_view_rounded;
      case HistoryCategory.dons:
        return Icons.card_giftcard_outlined;
      case HistoryCategory.prets:
        return Icons.swap_horiz_rounded;
      case HistoryCategory.enCours:
        return Icons.schedule_rounded;
      case HistoryCategory.rendus:
        return Icons.task_alt_rounded;
    }
  }

  Widget _categoryChip(HistoryCategory value) {
    final active = category == value;
    return ChoiceChip(
      tooltip: value.label,
      label: Text(_shortLabel(value)),
      avatar: Icon(_icon(value), size: 17, color: active ? Colors.white : _ink),
      selected: active,
      onSelected: (_) => onCategoryChanged(value),
      showCheckmark: false,
      backgroundColor: _subtle,
      selectedColor: _selected,
      side: BorderSide(color: active ? _selected : _outline),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        color: active ? Colors.white : _ink,
        fontSize: 13,
        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedYear = year;
    final yearOptions = <int>[...years];
    // Recopie locale pour garantir le typage non-null des annees ajoutees.
    if (selectedYear != null && !yearOptions.contains(selectedYear)) {
      yearOptions.add(selectedYear);
      yearOptions.sort((a, b) => b.compareTo(a));
    }
    final active = category != HistoryCategory.all || selectedYear != null;

    final categoryChoices = Wrap(
      spacing: 7,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: HistoryCategory.values.map(_categoryChip).toList(),
    );

    final yearDropdown = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: _subtle,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month_outlined, size: 18, color: _ink),
          const SizedBox(width: 7),
          const Text('Année', style: TextStyle(color: _ink, fontSize: 13)),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: selectedYear ?? 0,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 19),
              style: const TextStyle(
                color: _ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              items: [
                const DropdownMenuItem<int>(value: 0, child: Text('Toutes')),
                ...yearOptions.map(
                      (item) => DropdownMenuItem<int>(
                    value: item,
                    child: Text(item.toString()),
                  ),
                ),
              ],
              onChanged: (value) => onYearChanged(value == 0 ? null : value),
            ),
          ),
        ],
      ),
    );

    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        yearDropdown,
        if (active) ...[
          const SizedBox(width: 10),
          TextButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Effacer'),
            style: TextButton.styleFrom(
              foregroundColor: _selected,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _outline),
            borderRadius: BorderRadius.circular(16),
          ),
          child: wide
              ? Row(
            children: [
              Expanded(child: categoryChoices),
              const SizedBox(width: 14),
              controls,
            ],
          )
              : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              categoryChoices,
              const SizedBox(height: 8),
              controls,
            ],
          ),
        );
      },
    );
  }
}
