enum TransmissionType {
  don,
  pret,
}

extension TransmissionTypeLabel on TransmissionType {
  String get apiValue => this == TransmissionType.don ? 'don' : 'pret';

  String get label => this == TransmissionType.don ? 'Don' : 'Prêt';

  static TransmissionType fromApi(String? value) {
    return value == 'pret' ? TransmissionType.pret : TransmissionType.don;
  }
}

enum LoanStatus {
  enCours,
  rendu,
}

extension LoanStatusLabel on LoanStatus {
  String get apiValue => this == LoanStatus.rendu ? 'rendu' : 'en_cours';

  String get label => this == LoanStatus.rendu ? 'Rendu' : 'En cours';

  static LoanStatus? fromApi(String? value) {
    if (value == 'rendu') return LoanStatus.rendu;
    if (value == 'en_cours') return LoanStatus.enCours;
    return null;
  }
}

class EquipmentOption {
  final String category;
  final List<String> models;

  const EquipmentOption({
    required this.category,
    required this.models,
  });

  bool get hasModels => models.isNotEmpty;

  factory EquipmentOption.fromJson(Map<String, dynamic> json) {
    final rawModels = json['models'] as List<dynamic>? ?? const [];

    return EquipmentOption(
      category: json['category'] as String? ?? '',
      models: rawModels.map((item) => item.toString()).toList(),
    );
  }
}

class TransmissionItem {
  final String equipmentType;
  final String? equipmentModel;
  final String? customEquipment;
  final int quantity;

  const TransmissionItem({
    required this.equipmentType,
    this.equipmentModel,
    this.customEquipment,
    required this.quantity,
  });

  String get label {
    if (equipmentType.toLowerCase() == 'autre' &&
        (customEquipment?.trim().isNotEmpty ?? false)) {
      return customEquipment!.trim();
    }
    if (equipmentModel?.trim().isNotEmpty ?? false) {
      return '$equipmentType — ${equipmentModel!.trim()}';
    }
    return equipmentType;
  }

  Map<String, dynamic> toJson() => {
        'equipmentType': equipmentType,
        'equipmentModel': equipmentModel,
        'customEquipment': customEquipment,
        'quantity': quantity,
      };

  factory TransmissionItem.fromJson(Map<String, dynamic> json) =>
      TransmissionItem(
        equipmentType: json['equipmentType'] as String? ?? '',
        equipmentModel: json['equipmentModel'] as String?,
        customEquipment: json['customEquipment'] as String?,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      );
}

/// Matériels proposés automatiquement pour une remise d'ordinateur.
/// Tous sont cochés par défaut, avec une quantité initiale identique au PC.
List<TransmissionItem> defaultComputerAccessories(String equipmentType, int quantity) {
  if (equipmentType.trim().toLowerCase() != 'ordinateur') return const [];
  return [
    TransmissionItem(equipmentType: 'Souris', quantity: quantity),
    TransmissionItem(equipmentType: 'Sacoche de transport', quantity: quantity),
    TransmissionItem(equipmentType: 'Chargeur', quantity: quantity),
  ];
}

class Transmission {
  final String id;
  final TransmissionType type;
  final String equipmentType;
  final String? equipmentModel;
  final String? customEquipment;
  final int quantity;
  final List<TransmissionItem> equipmentItems;
  final String beneficiary;
  final String content;
  final String author;
  final DateTime createdAt;
  final LoanStatus? loanStatus;
  final DateTime? returnedAt;
  final String? returnedBy;
  final String? returnComment;
  final bool hasSignature;
  final String? signerName;
  final DateTime? signedAt;

  const Transmission({
    required this.id,
    required this.type,
    required this.equipmentType,
    required this.equipmentModel,
    required this.customEquipment,
    required this.quantity,
    this.equipmentItems = const [],
    required this.beneficiary,
    required this.content,
    required this.author,
    required this.createdAt,
    required this.loanStatus,
    required this.returnedAt,
    required this.returnedBy,
    this.returnComment,
    this.hasSignature = false,
    this.signerName,
    this.signedAt,
  });

  String get equipmentLabel {
    if (equipmentType.toLowerCase() == 'autre' &&
        customEquipment != null &&
        customEquipment!.trim().isNotEmpty) {
      return customEquipment!.trim();
    }

    if (equipmentModel != null && equipmentModel!.trim().isNotEmpty) {
      return '$equipmentType — ${equipmentModel!.trim()}';
    }

    return equipmentType;
  }

  /// Compatibilité avec les transmissions créées avant la migration.
  List<TransmissionItem> get allItems => equipmentItems.isNotEmpty
      ? equipmentItems
      : [
          TransmissionItem(
            equipmentType: equipmentType,
            equipmentModel: equipmentModel,
            customEquipment: customEquipment,
            quantity: quantity,
          ),
        ];

  // Un ancien prêt peut ne pas encore avoir de statut après une migration.
  // Tant qu'il n'est pas explicitement marqué comme rendu, on le considère
  // comme un prêt en cours afin de toujours proposer l'action de retour.
  bool get isActiveLoan =>
      type == TransmissionType.pret && loanStatus != LoanStatus.rendu;

  factory Transmission.fromJson(Map<String, dynamic> json) {
    final legacyTitle = json['title'] as String?;

    return Transmission(
      id: json['id'] as String? ?? '',
      type: TransmissionTypeLabel.fromApi(json['type'] as String?),
      equipmentType:
          json['equipmentType'] as String? ?? legacyTitle ?? 'Non renseigné',
      equipmentModel: json['equipmentModel'] as String?,
      customEquipment: json['customEquipment'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      equipmentItems: (json['equipmentItems'] as List<dynamic>? ?? const [])
          .map((item) => TransmissionItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      beneficiary: json['beneficiary'] as String? ?? 'Non renseigné',
      content: json['content'] as String? ?? '',
      author: json['author'] as String? ?? 'Inconnu',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      loanStatus: LoanStatusLabel.fromApi(json['loanStatus'] as String?),
      returnedAt: DateTime.tryParse(json['returnedAt'] as String? ?? ''),
      returnedBy: json['returnedBy'] as String?,
      returnComment: json['returnComment'] as String?,
      hasSignature: json['hasSignature'] == true,
      signerName: json['signerName'] as String?,
      signedAt: DateTime.tryParse(json['signedAt'] as String? ?? ''),
    );
  }
}
