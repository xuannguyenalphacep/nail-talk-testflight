double _readDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

int _readInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class MarketplaceItem {
  MarketplaceItem({
    required this.id,
    required this.uuid,
    required this.title,
    required this.description,
    required this.price,
    required this.currency,
    required this.condition,
    required this.city,
    required this.state,
    required this.contactName,
    required this.contactPhone,
    required this.contactEmail,
    required this.imageUrls,
    required this.status,
    required this.userId,
    required this.categoryName,
    required this.userName,
    required this.userAvatarUrl,
    required this.sourceName,
    required this.sourceUrl,
    required this.externalId,
    required this.saved,
  });

  final int id;
  final String uuid;
  final String title;
  final String description;
  final double price;
  final String currency;
  final String condition;
  final String city;
  final String state;
  final String contactName;
  final String contactPhone;
  final String contactEmail;
  final List<String> imageUrls;
  final String status;
  final int userId;
  final String categoryName;
  final String userName;
  final String userAvatarUrl;
  final String sourceName;
  final String sourceUrl;
  final String externalId;
  final bool saved;

  bool get isImportedSource =>
      sourceName.trim().isNotEmpty ||
      sourceUrl.trim().isNotEmpty ||
      externalId.trim().isNotEmpty;

  bool get hasPublicContact =>
      contactName.trim().isNotEmpty ||
      contactPhone.trim().isNotEmpty ||
      contactEmail.trim().isNotEmpty ||
      sourceUrl.trim().isNotEmpty;

  factory MarketplaceItem.fromJson(Map<String, dynamic> json) {
    final category = json['category'] is Map<String, dynamic>
        ? json['category'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return MarketplaceItem(
      id: _readInt(json['id']),
      uuid: (json['uuid'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      price: _readDouble(json['price']),
      currency: (json['currency'] ?? 'USD').toString(),
      condition: (json['condition'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      contactName: (json['contact_name'] ?? '').toString(),
      contactPhone: (json['contact_phone'] ?? '').toString(),
      contactEmail: (json['contact_email'] ?? '').toString(),
      imageUrls: (json['image_urls'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      status: (json['status'] ?? '').toString(),
      userId: _readInt(user['id']) > 0
          ? _readInt(user['id'])
          : _readInt(json['user_id']),
      categoryName: (category['name'] ?? '').toString(),
      userName: (user['name'] ?? json['user_name'] ?? '').toString(),
      userAvatarUrl: (user['avatar_url'] ?? json['user_avatar_url'] ?? '')
          .toString(),
      sourceName: (json['source_name'] ?? '').toString(),
      sourceUrl: (json['source_url'] ?? '').toString(),
      externalId: (json['external_id'] ?? '').toString(),
      saved: json['saved'] == true || json['saved'] == 1,
    );
  }

  MarketplaceItem copyWith({bool? saved}) {
    return MarketplaceItem(
      id: id,
      uuid: uuid,
      title: title,
      description: description,
      price: price,
      currency: currency,
      condition: condition,
      city: city,
      state: state,
      contactName: contactName,
      contactPhone: contactPhone,
      contactEmail: contactEmail,
      imageUrls: imageUrls,
      status: status,
      userId: userId,
      categoryName: categoryName,
      userName: userName,
      userAvatarUrl: userAvatarUrl,
      sourceName: sourceName,
      sourceUrl: sourceUrl,
      externalId: externalId,
      saved: saved ?? this.saved,
    );
  }
}
