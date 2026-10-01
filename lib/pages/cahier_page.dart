import 'dart:async';

import 'package:flutter/material.dart';

import '../models/transmission.dart';
import '../services/auth_service.dart';
import '../services/transmission_service.dart';
import 'widgets/return_loan_dialog.dart';

class CahierPage extends StatefulWidget {
  final AuthService auth;

  const CahierPage({
    super.key,
    required this.auth,
  });

  @override
  State<CahierPage> createState() => _CahierPageState();
}

class _CahierPageState extends State<CahierPage> {
  final _searchController = TextEditingController();
  final Set<String> _returningIds = <String>{};
  late final TransmissionService _service;
  late Future<List<Transmission>> _future;
  Timer? _debounce;

  bool get _isSearching => _searchController.text.trim().isNotEmpty;

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

  void _load() {
    final query = _searchController.text.trim();
    _future = query.isEmpty
        ? _service.getTransmissions(days: 7)
        : _service.getTransmissions(query: query);
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(_load);
    });
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  void _clearSearch() {
    _searchController.clear();
    _debounce?.cancel();
    setState(_load);
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
      setState(_load);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6FBFC),
      appBar: AppBar(
        title: const Text('Consulter le cahier'),
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Rechercher dans tout l’historique…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Effacer la recherche',
                            onPressed: _clearSearch,
                            icon: const Icon(Icons.close),
                          ),
                    filled: true,
                    fillColor: const Color(0xFFF6FBFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE0F1F3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE0F1F3)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isSearching
                      ? 'Résultats dans tout l’historique'
                      : 'Historique des 7 derniers jours',
                  style: const TextStyle(
                    color: Color(0xFF62818A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Transmission>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _ErrorState(
                    message: snapshot.error.toString(),
                    onRetry: () => setState(_load),
                  );
                }

                final transmissions = snapshot.data ?? const [];

                if (transmissions.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 150),
                        const Icon(
                          Icons.menu_book_outlined,
                          size: 56,
                          color: Color(0xFF8AA5AB),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            _isSearching
                                ? 'Aucun résultat pour cette recherche.'
                                : 'Aucune opération sur les 7 derniers jours.',
                            style: const TextStyle(
                              color: Color(0xFF62818A),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: transmissions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final transmission = transmissions[index];

                      return TransmissionCard(
                        transmission: transmission,
                        markingReturned:
                            _returningIds.contains(transmission.id),
                        onMarkReturned: transmission.isActiveLoan
                            ? () => _markReturned(transmission)
                            : null,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TransmissionCard extends StatelessWidget {
  final Transmission transmission;
  final VoidCallback? onMarkReturned;
  final bool markingReturned;

  const TransmissionCard({
    super.key,
    required this.transmission,
    this.onMarkReturned,
    this.markingReturned = false,
  });

  String _date(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} à $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final isDonation = transmission.type == TransmissionType.don;
    final accent = isDonation
        ? const Color(0xFF2D9595)
        : const Color(0xFF5EA0D9);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE2EEF0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _TypeChip(
                  label: transmission.type.label,
                  color: accent,
                ),
                if (transmission.type == TransmissionType.pret)
                  _LoanStatusChip(status: transmission.loanStatus),
                Text(
                  transmission.equipmentLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF214B55),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _date(transmission.createdAt),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF78939A),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 18,
              runSpacing: 10,
              children: [
                _InfoLine(
                  icon: Icons.inventory_2_outlined,
                  label: 'Quantité : ${transmission.quantity}',
                ),
                _InfoLine(
                  icon: Icons.person_pin_outlined,
                  label: transmission.beneficiary,
                ),
              ],
            ),
            if (transmission.content.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                transmission.content,
                style: const TextStyle(
                  height: 1.45,
                  color: Color(0xFF345D66),
                ),
              ),
            ],
            if (transmission.returnedAt != null) ...[
              const SizedBox(height: 12),
              _InfoLine(
                icon: Icons.assignment_turned_in_outlined,
                label:
                    'Rendu le ${_date(transmission.returnedAt!)}${transmission.returnedBy == null ? '' : ' par ${transmission.returnedBy}'}',
              ),
            ],
            if (transmission.returnComment?.trim().isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Text(
                'Commentaire au retour : ${transmission.returnComment!.trim()}',
                style: const TextStyle(
                  height: 1.4,
                  color: Color(0xFF4C6E76),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Saisi par ${transmission.author}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
            if (onMarkReturned != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: markingReturned ? null : onMarkReturned,
                  icon: markingReturned
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.assignment_turned_in_outlined),
                  label: Text(
                    markingReturned
                        ? 'Enregistrement du retour…'
                        : 'Marquer ce prêt comme rendu',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TypeChip({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LoanStatusChip extends StatelessWidget {
  final LoanStatus? status;

  const _LoanStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final returned = status == LoanStatus.rendu;
    final color = returned ? const Color(0xFF2E8B57) : const Color(0xFFD48724);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        returned ? 'Rendu' : 'En cours',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoLine({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF62818A)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF4C6E76),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
