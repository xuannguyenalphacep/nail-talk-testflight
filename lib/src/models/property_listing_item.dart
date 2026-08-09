import '../core/utils/app_date_utils.dart';

double _readDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

double? _readNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int _readInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class PropertyListingItem {
  PropertyListingItem({
    required this.id,
    required this.uuid,
    required this.listingMode,
    required this.title,
    required this.description,
    required this.price,
    required this.depositAmount,
    required this.currency,
    required this.city,
    required this.state,
    required this.addressLine,
    required this.availableFrom,
    required this.amenities,
    required this.imageUrls,
    required this.status,
    required this.userId,
    required this.userName,
    required this.userAvatarUrl,
    required this.saved,
  });

  final int id;
  final String uuid;
  final String listingMode;
  final String title;
  final String description;
  final double price;
  final double? depositAmount;
  final String currency;
  final String city;
  final String state;
  final String addressLine;
  final DateTime? availableFrom;
  final List<String> amenities;
  final List<String> imageUrls;
  final String status;
  final int userId;
  final String userName;
  final String userAvatarUrl;
  final bool saved;

  factory PropertyListingItem.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return PropertyListingItem(
      id: _readInt(json['id']),
      uuid: (json['uuid'] ?? '').toString(),
      listingMode: (json['listing_mode'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      price: _readDouble(json['price']),
      depositAmount: _readNullableDouble(json['deposit_amount']),
      currency: (json['currency'] ?? 'USD').toString(),
      city: (json['city'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      addressLine: (json['address_line'] ?? '').toString(),
      availableFrom: AppDateUtils.tryParse(json['available_from']),
      amenities: (json['amenities'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      imageUrls: (json['image_urls'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      status: (json['status'] ?? '').toString(),
      userId: _readInt(user['id']),
      userName: (user['name'] ?? '').toString(),
      userAvatarUrl: (user['avatar_url'] ?? '').toString(),
      saved: json['saved'] == true || json['saved'] == 1,
    );
  }

  PropertyListingItem copyWith({bool? saved}) {
    return PropertyListingItem(
      id: id,
      uuid: uuid,
      listingMode: listingMode,
      title: title,
      description: description,
      price: price,
      depositAmount: depositAmount,
      currency: currency,
      city: city,
      state: state,
      addressLine: addressLine,
      availableFrom: availableFrom,
      amenities: amenities,
      imageUrls: imageUrls,
      status: status,
      userId: userId,
      userName: userName,
      userAvatarUrl: userAvatarUrl,
      saved: saved ?? this.saved,
    );
  }
}
