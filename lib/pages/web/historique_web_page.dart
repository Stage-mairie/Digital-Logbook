import 'package:flutter/material.dart';

import '../../models/transmission.dart';
import '../../services/auth_service.dart';
import '../../services/history_export.dart';
import '../../services/transmission_service.dart';
import '../cahier_page.dart';
import '../login_page.dart';
import '../widgets/return_loan_dialog.dart';
import '../widgets/history_filters.dart';
import '../widgets/privacy_notice.dart';

class HistoriqueWebPage extends StatefulWidget {
  final AuthService auth;

  const HistoriqueWebPage({
    super.key,
    required this.auth,
  });

  @override
  State<HistoriqueWebPage> createState() => _HistoriqueWebPageState();
}

class _HistoriqueWebPageState extends State<HistoriqueWebPage> {
  final _searchController = TextEditingController();
  final Set<String> _returningIds = <String>{};
  late final TransmissionService _service;

  bool _loading = true;
  String? _error;
  HistoryCategory _category = HistoryCategory.all;
  int? _year;
  List<Transmission> _items = const [];

  List<Transmission> get _visibleItems => filterHistory(
        _items,
        category: _category,
        year: _year,
        query: _searchController.text,
      );

  @override
  void initState() {
    super.initState();
    _service = TransmissionService(auth: widget.auth);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _service.getTransmissions();
      if (!mounted) return;

      setState(() {
        _items = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) => setState(() {});

  bool get _canExport =>
      !_loading && _error == null && _visibleItems.isNotEmpty;

  void _export(HistoryExportFormat format) {
    if (!_canExport) return;
    try {
      HistoryExport.export(_visibleItems, format);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export impossible : $error')),
      );
    }
  }

  Widget _exportMenu() {
    return PopupMenuButton<HistoryExportFormat>(
      tooltip: 'Exporter les résultats affichés',
      enabled: _canExport,
      onSelected: _export,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: HistoryExportFormat.csv,
          child: Text('CSV (.csv)'),
        ),
        PopupMenuItem(
          value: HistoryExportFormat.json,
          child: Text('JSON (.json)'),
        ),
        PopupMenuItem(
          value: HistoryExportFormat.xlsx,
          child: Text('Excel (.xlsx)'),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _canExport ? Colors.white : const Color(0xFFF4F7F7),
          border: Border.all(color: const Color(0xFFDCEBED)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.file_download_outlined,
                size: 20,
                color: _canExport
                    ? const Color(0xFF214B55)
                    : const Color(0xFF9DAFB3)),
            const SizedBox(width: 8),
            Text(
              'Exporter',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _canExport
                    ? const Color(0xFF214B55)
                    : const Color(0xFF9DAFB3),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _markReturned(Transmission transmission) async {
    final returnComment = await showReturnLoanDialog(
      context,
      transmission.equipmentLabel,
    );
    if (returnComment == null || !mounted) return;

    setState(() {
      _returningIds.add(transmission.id);
    });

    try {
      await _service.markLoanReturned(
        transmission.id,
        returnComment: returnComment,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prêt marqué comme rendu.')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _returningIds.remove(transmission.id);
        });
      }
    }
  }

  Future<void> _logout() async {
    await widget.auth.logout();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => LoginPage(auth: widget.auth)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAFB),
      body: Column(
        children: [
          _WebHeader(
            onRefresh: _load,
            onLogout: _logout,
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 720;
                          final search = SizedBox(
                            width: compact ? double.infinity : 390,
                            child: TextField(
                              controller: _searchController,
                              onChanged: _onSearchChanged,
                              decoration: InputDecoration(
                                hintText: 'Rechercher dans l’historique…',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchController.text.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: 'Effacer',
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {});
                                          // Le filtrage est local : aucune requête réseau.
                                        },
                                        icon: const Icon(Icons.close),
                                      ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFDCEBED),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFDCEBED),
                                  ),
                                ),
                              ),
                            ),
                          );

                          if (compact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const _HistoryTitle(),
                                const SizedBox(height: 18),
                                search,
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: _exportMenu(),
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              const Expanded(child: _HistoryTitle()),
                              const SizedBox(width: 20),
                              search,
                              const SizedBox(width: 12),
                              _exportMenu(),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      HistoryFilters(
                        category: _category,
                        year: _year,
                        years: historyYears(_items),
                        onCategoryChanged: (value) => setState(() => _category = value),
                        onYearChanged: (value) => setState(() => _year = value),
                        onReset: () => setState(() {
                          _category = HistoryCategory.all;
                          _year = null;
                        }),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_visibleItems.length} résultat(s)',
                        style: const TextStyle(color: Color(0xFF62818A)),
                      ),
                      const SizedBox(height: 10),
                      if (_loading) const LinearProgressIndicator(minHeight: 2),
                      const SizedBox(height: 10),
                      Expanded(child: _buildContent()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (!_loading && _visibleItems.isEmpty) {
      return Center(
        child: Text(
          _items.isEmpty
              ? 'Aucune transmission enregistrée.'
              : 'Aucun résultat pour ces filtres ou cette recherche.',
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF62818A),
          ),
        ),
      );
    }

    final visibleItems = _visibleItems;
    return Scrollbar(
      child: ListView.separated(
        itemCount: visibleItems.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final transmission = visibleItems[index];

          return TransmissionCard(
            transmission: transmission,
            signatureLoader: _service.getSignature,
            markingReturned: _returningIds.contains(transmission.id),
            onMarkReturned: transmission.isActiveLoan
                ? () => _markReturned(transmission)
                : null,
          );
        },
      ),
    );
  }
}

class _WebHeader extends StatelessWidget {
  final VoidCallback onRefresh;
  final Future<void> Function() onLogout;

  const _WebHeader({
    required this.onRefresh,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          child: Row(
            children: [
              Image.asset(
                'assets/images/app_icon_ct.png',
                width: 52,
                height: 52,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 18),
              const Expanded(
                child: Text(
                  'Cahier de Transmission',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF214B55),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Protection des données personnelles',
                onPressed: () => PrivacyNotice.show(context),
                icon: const Icon(Icons.privacy_tip_outlined),
              ),
              IconButton(
                tooltip: 'Actualiser',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout_outlined),
                label: const Text('Déconnexion'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryTitle extends StatelessWidget {
  const _HistoryTitle();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Historique des transmissions',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Color(0xFF214B55),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Historique complet et gestion du retour des prêts',
          style: TextStyle(
            fontSize: 15,
            color: Color(0xFF62818A),
          ),
        ),
      ],
    );
  }
}
