import '../core/utils/app_date_utils.dart';

double _readDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

int _readInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

class MoviePlanModel {
  MoviePlanModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.durationDays,
    required this.isActive,
  });

  final int id;
  final String name;
  final String description;
  final double price;
  final String currency;
  final int durationDays;
  final bool isActive;

  factory MoviePlanModel.fromJson(Map<String, dynamic> json) {
    return MoviePlanModel(
      id: _readInt(json['id']),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      price: _readDouble(json['price']),
      currency: (json['currency'] ?? 'USD').toString(),
      durationDays: _readInt(json['duration_days'], fallback: 30),
      isActive: json['is_active'] == true || json['is_active'] == 1,
    );
  }
}

class MovieSubscriptionModel {
  MovieSubscriptionModel({
    required this.id,
    required this.status,
    required this.amount,
    required this.currency,
    required this.startsAt,
    required this.endsAt,
    required this.planName,
  });

  final int id;
  final String status;
  final double amount;
  final String currency;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String planName;

  bool get isActive =>
      status == 'active' && (endsAt?.isAfter(DateTime.now()) ?? false);

  factory MovieSubscriptionModel.fromJson(Map<String, dynamic> json) {
    final plan = json['plan'] is Map<String, dynamic>
        ? json['plan'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return MovieSubscriptionModel(
      id: _readInt(json['id']),
      status: (json['status'] ?? '').toString(),
      amount: _readDouble(json['amount']),
      currency: (json['currency'] ?? 'USD').toString(),
      startsAt: AppDateUtils.tryParse(json['starts_at']),
      endsAt: AppDateUtils.tryParse(json['ends_at']),
      planName: (plan['name'] ?? '').toString(),
    );
  }
}
