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

class Transmission {
  final String id;
  final TransmissionType type;
  final String equipmentType;
  final String? equipmentModel;
  final String? customEquipment;
  final int quantity;
  final String beneficiary;
  final String content;
  final String author;
  final DateTime createdAt;
  final LoanStatus? loanStatus;
  final DateTime? returnedAt;
  final String? returnedBy;
  final String? returnComment;

  const Transmission({
    required this.id,
    required this.type,
    required this.equipmentType,
    required this.equipmentModel,
    required this.customEquipment,
    required this.quantity,
    required this.beneficiary,
    required this.content,
    required this.author,
    required this.createdAt,
    required this.loanStatus,
    required this.returnedAt,
    required this.returnedBy,
    this.returnComment,
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
      beneficiary: json['beneficiary'] as String? ?? 'Non renseigné',
      content: json['content'] as String? ?? '',
      author: json['author'] as String? ?? 'Inconnu',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      loanStatus: LoanStatusLabel.fromApi(json['loanStatus'] as String?),
      returnedAt: DateTime.tryParse(json['returnedAt'] as String? ?? ''),
      returnedBy: json['returnedBy'] as String?,
      returnComment: json['returnComment'] as String?,
    );
  }
}
