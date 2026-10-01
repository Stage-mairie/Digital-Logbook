import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/transmission.dart';
import 'auth_service.dart';

class TransmissionService {
  final AuthService auth;

  const TransmissionService({required this.auth});

  Future<Map<String, String>> _headers() async {
    final token = await auth.getSessionToken();

    if (token == null || token.isEmpty) {
      throw const TransmissionException('Session absente. Reconnectez-vous.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<EquipmentOption>> getEquipmentCatalog(
    TransmissionType type,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/equipment-catalog').replace(
      queryParameters: {'type': type.apiValue},
    );

    final response = await http.get(
      uri,
      headers: await _headers(),
    );

    if (response.statusCode == 401) {
      throw const TransmissionException('Session expirée. Reconnectez-vous.');
    }

    if (response.statusCode != 200) {
      throw TransmissionException(
        'Impossible de charger le catalogue (${response.statusCode}).',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = body['items'] as List<dynamic>? ?? const [];

    return items
        .map((item) => EquipmentOption.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Transmission>> getTransmissions({
    int? days,
    String? query,
  }) async {
    final parameters = <String, String>{};

    if (days != null) {
      parameters['days'] = days.toString();
    }

    if (query != null && query.trim().isNotEmpty) {
      parameters['q'] = query.trim();
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/transmissions').replace(
      queryParameters: parameters.isEmpty ? null : parameters,
    );

    final response = await http.get(
      uri,
      headers: await _headers(),
    );

    if (response.statusCode == 401) {
      throw const TransmissionException('Session expirée. Reconnectez-vous.');
    }

    if (response.statusCode != 200) {
      throw TransmissionException(
        'Impossible de charger les transmissions (${response.statusCode}).',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = body['items'] as List<dynamic>? ?? const [];

    return items
        .map(
          (item) => Transmission.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<Transmission> createTransmission({
    required TransmissionType type,
    required String equipmentType,
    String? equipmentModel,
    String? customEquipment,
    required int quantity,
    required String beneficiary,
    String content = '',
    String? signerName,
    Uint8List? signaturePng,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/transmissions'),
      headers: await _headers(),
      body: jsonEncode({
        'type': type.apiValue,
        'equipmentType': equipmentType.trim(),
        'equipmentModel': equipmentModel?.trim(),
        'customEquipment': customEquipment?.trim(),
        'quantity': quantity,
        'beneficiary': beneficiary.trim(),
        'content': content.trim(),
        if (signaturePng != null) 'signaturePngBase64': base64Encode(signaturePng),
        if (signaturePng != null) 'signerName': signerName?.trim(),
      }),
    );

    if (response.statusCode == 401) {
      throw const TransmissionException('Session expirée. Reconnectez-vous.');
    }

    if (response.statusCode != 201) {
      throw TransmissionException(_readError(
        response,
        fallback: 'Impossible d’enregistrer l’opération.',
      ));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return Transmission.fromJson(body['item'] as Map<String, dynamic>);
  }

  // Consultation authentifiée, à la demande, jamais via une URL publique.
  Future<Uint8List> getSignature(String id) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/transmissions/$id/signature'),
      headers: await _headers(),
    );
    if (response.statusCode == 401) {
      throw const TransmissionException('Session expirée. Reconnectez-vous.');
    }
    if (response.statusCode != 200) {
      throw TransmissionException(_readError(response,
          fallback: 'Signature indisponible (${response.statusCode}).'));
    }
    return response.bodyBytes;
  }

  Future<Transmission> markLoanReturned(
    String id, {
    String returnComment = '',
  }) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/transmissions/$id/return'),
      headers: await _headers(),
      body: jsonEncode({'returnComment': returnComment.trim()}),
    );

    if (response.statusCode == 401) {
      throw const TransmissionException('Session expirée. Reconnectez-vous.');
    }

    if (response.statusCode != 200) {
      throw TransmissionException(_readError(
        response,
        fallback: 'Impossible de marquer ce prêt comme rendu.',
      ));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return Transmission.fromJson(body['item'] as Map<String, dynamic>);
  }

  String _readError(
    http.Response response, {
    required String fallback,
  }) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['error'] as String? ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}

class TransmissionException implements Exception {
  final String message;

  const TransmissionException(this.message);

  @override
  String toString() => message;
}
