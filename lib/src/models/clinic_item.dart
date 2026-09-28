import '../core/utils/app_date_utils.dart';

int _readInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class ClinicItem {
  ClinicItem({
    required this.id,
    required this.uuid,
    required this.serviceCategoryId,
    required this.serviceSlug,
    required this.serviceName,
    required this.name,
    required this.slug,
    required this.clinicType,
    required this.summary,
    required this.description,
    required this.province,
    required this.district,
    required this.addressLine,
    required this.contactPhone,
    required this.contactEmail,
    required this.websiteUrl,
    required this.mapUrl,
    required this.specialtyNames,
    required this.serviceTags,
    required this.imageUrls,
    required this.openingHours,
    required this.isPartner,
    required this.status,
  });

  final int id;
  final String uuid;
  final int serviceCategoryId;
  final String serviceSlug;
  final String serviceName;
  final String name;
  final String slug;
  final String clinicType;
  final String summary;
  final String description;
  final String province;
  final String district;
  final String addressLine;
  final String contactPhone;
  final String contactEmail;
  final String websiteUrl;
  final String mapUrl;
  final List<String> specialtyNames;
  final List<String> serviceTags;
  final List<String> imageUrls;
  final List<String> openingHours;
  final bool isPartner;
  final String status;

  String get primaryImageUrl => imageUrls.isEmpty ? '' : imageUrls.first;

  String get locationLabel {
    final parts = [
      district,
      province,
    ].map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
    return parts.join(', ');
  }

  factory ClinicItem.fromJson(Map<String, dynamic> json) {
    return ClinicItem(
      id: _readInt(json['id']),
      uuid: (json['uuid'] ?? '').toString(),
      serviceCategoryId: _readInt(json['service_category_id']),
      serviceSlug: (json['service_slug'] ?? '').toString(),
      serviceName: (json['service_name'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      clinicType: (json['clinic_type'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      province: (json['province'] ?? '').toString(),
      district: (json['district'] ?? '').toString(),
      addressLine: (json['address_line'] ?? '').toString(),
      contactPhone: (json['contact_phone'] ?? '').toString(),
      contactEmail: (json['contact_email'] ?? '').toString(),
      websiteUrl: (json['website_url'] ?? '').toString(),
      mapUrl: (json['map_url'] ?? '').toString(),
      specialtyNames:
          (json['specialty_names'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item.toString())
              .toList(),
      serviceTags: (json['service_tags'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      imageUrls: (json['image_urls'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      openingHours:
          (json['opening_hours'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item.toString())
              .toList(),
      isPartner: json['is_partner'] == true || json['is_partner'] == 1,
      status: (json['status'] ?? '').toString(),
    );
  }

  ClinicItem copyWith({List<String>? imageUrls}) {
    return ClinicItem(
      id: id,
      uuid: uuid,
      serviceCategoryId: serviceCategoryId,
      serviceSlug: serviceSlug,
      serviceName: serviceName,
      name: name,
      slug: slug,
      clinicType: clinicType,
      summary: summary,
      description: description,
      province: province,
      district: district,
      addressLine: addressLine,
      contactPhone: contactPhone,
      contactEmail: contactEmail,
      websiteUrl: websiteUrl,
      mapUrl: mapUrl,
      specialtyNames: specialtyNames,
      serviceTags: serviceTags,
      imageUrls: imageUrls ?? this.imageUrls,
      openingHours: openingHours,
      isPartner: isPartner,
      status: status,
    );
  }
}

class ClinicBookingResult {
  ClinicBookingResult({
    required this.id,
    required this.uuid,
    required this.status,
    required this.message,
    required this.appointmentDate,
  });

  final int id;
  final String uuid;
  final String status;
  final String message;
  final DateTime? appointmentDate;

  factory ClinicBookingResult.fromJson(Map<String, dynamic> json) {
    return ClinicBookingResult(
      id: _readInt(json['id']),
      uuid: (json['uuid'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      appointmentDate: AppDateUtils.tryParse(json['appointment_date']),
    );
  }
}
