import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/transmission.dart';
import '../../services/auth_service.dart';
import '../../services/transmission_service.dart';
import '../cahier_page.dart';
import '../login_page.dart';

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

  Timer? _debounce;
  bool _loading = true;
  String? _error;
  List<Transmission> _items = const [];

  @override
  void initState() {
    super.initState();
    _service = TransmissionService(auth: widget.auth);
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({String? query}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _service.getTransmissions(query: query);
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

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _load(query: value.trim());
    });
  }

  Future<void> _markReturned(Transmission transmission) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer le retour'),
        content: Text(
          'Marquer le prêt « ${transmission.equipmentLabel} » comme rendu ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.assignment_turned_in_outlined),
            label: const Text('Marquer comme rendu'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _returningIds.add(transmission.id);
    });

    try {
      await _service.markLoanReturned(transmission.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prêt marqué comme rendu.')),
      );
      await _load(query: _searchController.text.trim());
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
            onRefresh: () => _load(query: _searchController.text.trim()),
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
                                          _load();
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
                              ],
                            );
                          }

                          return Row(
                            children: [
                              const Expanded(child: _HistoryTitle()),
                              const SizedBox(width: 28),
                              search,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 22),
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
              onPressed: () => _load(query: _searchController.text.trim()),
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (!_loading && _items.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.trim().isEmpty
              ? 'Aucune transmission enregistrée.'
              : 'Aucun résultat pour cette recherche.',
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF62818A),
          ),
        ),
      );
    }

    return Scrollbar(
      child: ListView.separated(
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final transmission = _items[index];

          return TransmissionCard(
            transmission: transmission,
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
                'assets/images/logo_saint_andre.png',
                height: 58,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.account_balance,
                  size: 34,
                  color: Color(0xFF2D9595),
                ),
              ),
              const SizedBox(width: 18),
              const Expanded(
                child: Text(
                  'Cahier de transmission',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF214B55),
                  ),
                ),
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
