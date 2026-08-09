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

class JobListingItem {
  JobListingItem({
    required this.id,
    required this.uuid,
    required this.listingMode,
    required this.title,
    required this.salonName,
    required this.description,
    required this.requirements,
    required this.salaryMin,
    required this.salaryMax,
    required this.salaryCurrency,
    required this.city,
    required this.state,
    required this.contactPhone,
    required this.contactEmail,
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
  final String salonName;
  final String description;
  final String requirements;
  final double? salaryMin;
  final double? salaryMax;
  final String salaryCurrency;
  final String city;
  final String state;
  final String contactPhone;
  final String contactEmail;
  final List<String> imageUrls;
  final String status;
  final int userId;
  final String userName;
  final String userAvatarUrl;
  final bool saved;

  factory JobListingItem.fromJson(Map<String, dynamic> json) {
    final user = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return JobListingItem(
      id: _readInt(json['id']),
      uuid: (json['uuid'] ?? '').toString(),
      listingMode: (json['listing_mode'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      salonName: (json['salon_name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      requirements: (json['requirements'] ?? '').toString(),
      salaryMin: _readNullableDouble(json['salary_min']),
      salaryMax: _readNullableDouble(json['salary_max']),
      salaryCurrency: (json['salary_currency'] ?? 'USD').toString(),
      city: (json['city'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      contactPhone: (json['contact_phone'] ?? '').toString(),
      contactEmail: (json['contact_email'] ?? '').toString(),
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

  JobListingItem copyWith({bool? saved}) {
    return JobListingItem(
      id: id,
      uuid: uuid,
      listingMode: listingMode,
      title: title,
      salonName: salonName,
      description: description,
      requirements: requirements,
      salaryMin: salaryMin,
      salaryMax: salaryMax,
      salaryCurrency: salaryCurrency,
      city: city,
      state: state,
      contactPhone: contactPhone,
      contactEmail: contactEmail,
      imageUrls: imageUrls,
      status: status,
      userId: userId,
      userName: userName,
      userAvatarUrl: userAvatarUrl,
      saved: saved ?? this.saved,
    );
  }
}
