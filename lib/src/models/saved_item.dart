class SavedItemModel {
  SavedItemModel({
    required this.id,
    required this.savableType,
    required this.savableId,
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final int id;
  final String savableType;
  final int savableId;
  final String title;
  final String subtitle;
  final String status;

  factory SavedItemModel.fromJson(Map<String, dynamic> json) {
    final resource = json['resource'] is Map<String, dynamic>
        ? json['resource'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return SavedItemModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      savableType: (json['savable_type'] ?? '').toString(),
      savableId: (json['savable_id'] as num?)?.toInt() ?? 0,
      title: (resource['title'] ?? '').toString(),
      subtitle: (resource['slug'] ?? resource['listing_mode'] ?? '').toString(),
      status: (resource['status'] ?? '').toString(),
    );
  }
}
