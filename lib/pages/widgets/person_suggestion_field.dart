import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/transmission_service.dart';

/// Saisie libre avec suggestions partagees entre les appareils.
class PersonSuggestionField extends StatefulWidget {
  final TextEditingController controller;
  final TransmissionService service;
  final String kind;
  final String label;
  final String hint;
  final bool requiredField;
  final bool enabled;

  const PersonSuggestionField({
    super.key,
    required this.controller,
    required this.service,
    required this.kind,
    required this.label,
    required this.hint,
    this.requiredField = false,
    this.enabled = true,
  });

  @override
  State<PersonSuggestionField> createState() => _PersonSuggestionFieldState();
}

class _PersonSuggestionFieldState extends State<PersonSuggestionField> {
  Timer? _debounce;
  int _requestId = 0;
  List<String> _suggestions = [];

  void _onChanged(String value) {
    _debounce?.cancel();
    final requestId = ++_requestId;

    if (value.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await widget.service.getPersonSuggestions(
          kind: widget.kind,
          query: value,
        );
        if (!mounted ||
            requestId != _requestId ||
            widget.controller.text != value) {
          return;
        }
        setState(() => _suggestions = results);
      } catch (_) {
        // Une erreur reseau n'empeche pas la saisie manuelle.
        if (!mounted || requestId != _requestId) return;
        setState(() => _suggestions = []);
      }
    });
  }

  void _choose(String name) {
    _debounce?.cancel();
    _requestId++;
    widget.controller.value = TextEditingValue(
      text: name,
      selection: TextSelection.collapsed(offset: name.length),
    );
    setState(() => _suggestions = []);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          maxLength: 120,
          onChanged: _onChanged,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            border: const OutlineInputBorder(),
          ),
          validator: widget.requiredField
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Indiquez le b├®n├®ficiaire ou le service.';
                  }
                  return null;
                }
              : null,
        ),
        if (widget.enabled && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4, bottom: 8),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE2EEF0)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final name = _suggestions[index];
                return ListTile(
                  dense: true,
                  title: Text(name),
                  leading: const Icon(Icons.person_outline),
                  onTap: () => _choose(name),
                );
              },
            ),
          ),
      ],
    );
  }
}
