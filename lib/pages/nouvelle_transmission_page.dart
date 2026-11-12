import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'widgets/person_suggestion_field.dart';
import 'widgets/signature_capture.dart';
import 'widgets/privacy_notice.dart';

import '../models/transmission.dart';
import '../services/auth_service.dart';
import '../services/transmission_service.dart';

class NouvelleTransmissionPage extends StatefulWidget {
  final AuthService auth;
  final TransmissionType type;

  const NouvelleTransmissionPage({
    super.key,
    required this.auth,
    required this.type,
  });

  @override
  State<NouvelleTransmissionPage> createState() =>
      _NouvelleTransmissionPageState();
}

class _NouvelleTransmissionPageState extends State<NouvelleTransmissionPage> {
  final _formKey = GlobalKey<FormState>();
  final _customEquipmentController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _beneficiaryController = TextEditingController();
  final _contentController = TextEditingController();
  final _signerController = TextEditingController();
  final _signatureKey = GlobalKey<SignatureCaptureState>();

  late final TransmissionService _service;

  List<EquipmentOption> _catalog = const [];
  String? _selectedEquipment;
  String? _selectedModel;
  bool _loadingCatalog = true;
  bool _saving = false;
  String? _error;
  List<_AccessoryDraft> _accessories = [];
  int _previousMainQuantity = 1;

  EquipmentOption? get _selectedOption {
    for (final option in _catalog) {
      if (option.category == _selectedEquipment) {
        return option;
      }
    }
    return null;
  }

  bool get _isOther => _selectedEquipment == 'Autre';

  String get _pageTitle => widget.type == TransmissionType.don
      ? 'Enregistrer un don'
      : 'Enregistrer un prêt';

  String get _helperText => widget.type == TransmissionType.don
      ? 'Renseignez le matériel donné et son bénéficiaire.'
      : 'Renseignez le matériel prêté et son bénéficiaire.';

  @override
  void initState() {
    super.initState();
    _service = TransmissionService(auth: widget.auth);
    _quantityController.addListener(_onMainQuantityChanged);
    _loadCatalog();
  }

  @override
  void dispose() {
    _customEquipmentController.dispose();
    _quantityController.dispose();
    _beneficiaryController.dispose();
    _contentController.dispose();
    _signerController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loadingCatalog = true;
      _error = null;
    });

    try {
      final catalog = await _service.getEquipmentCatalog(widget.type);
      if (!mounted) return;

      setState(() {
        _catalog = catalog;
        _selectedEquipment = catalog.isEmpty ? null : catalog.first.category;
        _selectedModel = catalog.isEmpty || catalog.first.models.isEmpty
            ? null
            : catalog.first.models.first;
        _setDefaultAccessories();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingCatalog = false;
        });
      }
    }
  }

  void _selectEquipment(String value) {
    final option = _catalog.firstWhere((item) => item.category == value);

    setState(() {
      _selectedEquipment = value;
      _selectedModel = option.models.isEmpty ? null : option.models.first;
      _setDefaultAccessories();

      if (value != 'Autre') {
        _customEquipmentController.clear();
      }
    });
  }

  void _setDefaultAccessories() {
    final count = int.tryParse(_quantityController.text) ?? 1;
    _previousMainQuantity = count;
    _accessories = defaultComputerAccessories(_selectedEquipment ?? '', count)
        .map((item) => _AccessoryDraft(item.equipmentType, item.quantity))
        .toList();
  }

  void _onMainQuantityChanged() {
    final count = int.tryParse(_quantityController.text);
    if (count == null || count < 1 || count > 999 ||
        count == _previousMainQuantity) return;
    final previous = _previousMainQuantity;
    _previousMainQuantity = count;
    if (_accessories.isEmpty || !mounted) return;
    setState(() {
      for (final accessory in _accessories) {
        // Suivre la quantité principale uniquement si non personnalisée.
        if (accessory.quantity == previous) accessory.quantity = count;
      }
    });
  }

  Future<void> _addAccessory() async {
    if (_accessories.length >= 19) return;
    var accessoryName = '';
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ajouter un accessoire'),
        content: TextField(
          autofocus: true,
          maxLength: 80,
          onChanged: (value) => accessoryName = value,
          decoration: const InputDecoration(
            labelText: 'Désignation',
            hintText: 'Ex. Câble HDMI',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, accessoryName.trim()),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    if (!mounted || name == null) return;
    if (name.length < 2 ||
        name.toLowerCase() == (_selectedEquipment ?? '').toLowerCase() ||
        _accessories.any((item) => item.name.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Désignation invalide ou déjà présente.')),
      );
      return;
    }
    setState(() {
      _accessories.add(_AccessoryDraft(
        name, int.tryParse(_quantityController.text) ?? 1,
      ));
    });
  }

  Widget _accessoriesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Accessoires remis avec le matériel',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        const Text('Pour un ordinateur : souris, sacoche et chargeur sont cochés par défaut. '
            'Décochez ce qui n’est pas remis.',
            style: TextStyle(color: Color(0xFF62818A), fontSize: 12)),
        const SizedBox(height: 10),
        for (final accessory in _accessories)
          Padding(
            key: ValueKey(accessory.name),
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFDCEBED)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: accessory.selected,
                    onChanged: _saving ? null : (value) => setState(() {
                      accessory.selected = value ?? false;
                    }),
                  ),
                  Expanded(child: Text(accessory.name,
                      maxLines: 2, overflow: TextOverflow.ellipsis)),
                  IconButton(
                    tooltip: 'Retirer une unité de ${accessory.name}',
                    onPressed: _saving || !accessory.selected || accessory.quantity <= 1
                        ? null
                        : () => setState(() => accessory.quantity--),
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                  ),
                  Text('${accessory.quantity}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  IconButton(
                    tooltip: 'Ajouter une unité de ${accessory.name}',
                    onPressed: _saving || !accessory.selected || accessory.quantity >= 999
                        ? null
                        : () => setState(() => accessory.quantity++),
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Supprimer ${accessory.name}',
                    onPressed: _saving ? null : () => setState(() => _accessories.remove(accessory)),
                    icon: const Icon(Icons.close, size: 17),
                  ),
                ],
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _saving || _accessories.length >= 19 ? null : _addAccessory,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un accessoire'),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    if (_selectedEquipment == null) {
      setState(() {
        _error = 'Le catalogue de matériel est vide.';
      });
      return;
    }

    final hasSignature = _signatureKey.currentState?.hasSignature ?? false;
    if (hasSignature && _signerController.text.trim().length < 2) {
      setState(() => _error = 'Indiquez le nom de la personne qui signe.');
      return;
    }
    if (!hasSignature && _signerController.text.trim().isNotEmpty) {
      setState(() =>
          _error = 'Ajoutez la signature ou effacez le nom du signataire.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final signaturePng = await _signatureKey.currentState?.exportPng();
      if (hasSignature && signaturePng == null) {
        throw const TransmissionException(
            'Impossible de capturer la signature. Réessayez.');
      }
      await _service.createTransmission(
        type: widget.type,
        equipmentType: _selectedEquipment!,
        equipmentModel: _selectedModel,
        customEquipment: _isOther ? _customEquipmentController.text : null,
        quantity: int.parse(_quantityController.text),
        equipmentItems: [
          TransmissionItem(
            equipmentType: _selectedEquipment!,
            equipmentModel: _selectedModel,
            customEquipment: _isOther ? _customEquipmentController.text : null,
            quantity: int.parse(_quantityController.text),
          ),
          ..._accessories.where((accessory) => accessory.selected).map(
                (accessory) => TransmissionItem(
                  equipmentType: accessory.name, quantity: accessory.quantity,
                ),
              ),
        ],
        beneficiary: _beneficiaryController.text,
        content: _contentController.text,
        signerName: signaturePng == null ? null : _signerController.text,
        signaturePng: signaturePng,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.type == TransmissionType.don
                ? 'Don enregistré.'
                : 'Prêt enregistré.',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.type == TransmissionType.don
        ? const Color(0xFF2D9595)
        : const Color(0xFF5EA0D9);

    return Scaffold(
      backgroundColor: const Color(0xFFF6FBFC),
      appBar: AppBar(
        title: Text(_pageTitle),
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: const BorderSide(color: Color(0xFFE2EEF0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildContent(accent),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Color accent) {
    if (_loadingCatalog) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 70),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_catalog.isEmpty) {
      return Column(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 48),
          const SizedBox(height: 14),
          Text(
            _error ?? 'Aucun matériel disponible dans le catalogue.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _loadCatalog,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      );
    }

    final selectedOption = _selectedOption;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  widget.type == TransmissionType.don
                      ? Icons.card_giftcard_outlined
                      : Icons.handshake_outlined,
                  color: accent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pageTitle,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF214B55),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _helperText,
                      style: const TextStyle(color: Color(0xFF62818A)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          DropdownButtonFormField<String>(
            value: _selectedEquipment,
            decoration: const InputDecoration(
              labelText: 'Matériel',
              border: OutlineInputBorder(),
            ),
            items: _catalog
                .map(
                  (item) => DropdownMenuItem(
                    value: item.category,
                    child: Text(item.category),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) _selectEquipment(value);
                  },
          ),
          if (selectedOption != null && selectedOption.hasModels) ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedModel,
              decoration: const InputDecoration(
                labelText: 'Modèle',
                border: OutlineInputBorder(),
              ),
              items: selectedOption.models
                  .map(
                    (model) => DropdownMenuItem(
                      value: model,
                      child: Text(model),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      setState(() {
                        _selectedModel = value;
                      });
                    },
              validator: (value) {
                if (selectedOption.hasModels &&
                    (value == null || value.trim().isEmpty)) {
                  return 'Sélectionnez un modèle.';
                }
                return null;
              },
            ),
          ],
          if (_isOther) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _customEquipmentController,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Précisez le matériel',
                hintText: 'Ex. Bac de récupération',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (_isOther && (value == null || value.trim().isEmpty)) {
                  return 'Précisez le matériel.';
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Quantité',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final quantity = int.tryParse(value ?? '');
              if (quantity == null || quantity <= 0) {
                return 'Indiquez une quantité valide.';
              }
              if (quantity > 999) {
                return 'La quantité maximale est 999.';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          _accessoriesSection(),
          const SizedBox(height: 16),
          PersonSuggestionField(
            controller: _beneficiaryController,
            service: _service,
            kind: 'beneficiary',
            label: 'Bénéficiaire / service',
            hint: 'Ex. Service RH, Mme Payet…',
            requiredField: true,
            enabled: !_saving,
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: _contentController,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Commentaire / observations (facultatif)',
              hintText: 'Référence, numéro de série, état du matériel…',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          const PrivacyFormInfo(),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 10),
          const Text('Accusé de remise du matériel',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 9),
          PersonSuggestionField(
            controller: _signerController,
            service: _service,
            kind: 'signer',
            label: 'Nom de la personne qui signe',
            hint: 'Prénom et nom du bénéficiaire',
            enabled: !_saving,
          ),
          SignatureCapture(key: _signatureKey),
          const SizedBox(height: 8),
          const Text(
            'En signant, la personne confirme la réception du matériel renseigné '
            'dans ce formulaire. Une image PNG et le nom seront enregistrés '
            'dans le cahier interne, sous réserve des règles de conservation '
            'et d’accès validées par la collectivité.',
            style: TextStyle(fontSize: 12, color: Color(0xFF62818A)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
          ),
        ],
      ),
    );
  }
}

class _AccessoryDraft {
  final String name;
  int quantity;
  bool selected;

  _AccessoryDraft(this.name, this.quantity, {this.selected = true});
}
