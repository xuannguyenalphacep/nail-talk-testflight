import 'package:flutter/material.dart';

import '../core/localization/app_localizer.dart';
import 'metro_ui.dart';
import 'remote_image.dart';

class ListingImagePickerField extends StatelessWidget {
  const ListingImagePickerField({
    required this.imageUrls,
    required this.onPick,
    required this.onRemoveAt,
    this.uploading = false,
    this.label = 'Listing photos',
    this.helperText =
        'Choose photos from your device and the app will upload them automatically.',
    super.key,
  });

  final List<String> imageUrls;
  final Future<void> Function() onPick;
  final ValueChanged<int> onRemoveAt;
  final bool uploading;
  final String label;
  final String helperText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.tr(label),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: kMetroInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: uploading ? null : () => onPick(),
              icon: Icon(
                uploading ? Icons.sync_rounded : Icons.add_photo_alternate,
              ),
              label: Text(context.tr('Add photos')),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.tr(helperText),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: kMetroMuted, height: 1.35),
        ),
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kMetroSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: uploading
                  ? kMetroCoral.withValues(alpha: 0.4)
                  : kMetroLine,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120F172A),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: uploading
              ? _UploadingState(label: 'Uploading images...')
              : imageUrls.isEmpty
              ? _EmptyState(onPick: onPick)
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var index = 0; index < imageUrls.length; index++)
                      _PreviewTile(
                        imageUrl: imageUrls[index],
                        onRemove: () => onRemoveAt(index),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _UploadingState extends StatelessWidget {
  const _UploadingState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            context.tr(label),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: kMetroInk),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPick});

  final Future<void> Function() onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onPick(),
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        decoration: BoxDecoration(
          color: kMetroPrimarySoft.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: kMetroSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kMetroLine),
              ),
              child: const Icon(
                Icons.photo_library_outlined,
                color: kMetroPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr('Tap add photos to choose images from your device.'),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: kMetroInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.imageUrl, required this.onRemove});

  final String imageUrl;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: RemoteImage(
                url: imageUrl,
                fit: BoxFit.cover,
                errorFallback: DecoratedBox(
                  decoration: BoxDecoration(
                    color: kMetroPrimarySoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: kMetroMuted,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(999),
              child: Ink(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.58),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
