import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/media_asset.dart';
import '../../../viewmodels/admin_auth_viewmodel.dart';
import '../../../viewmodels/admin_media_viewmodel.dart';
import 'admin_theme.dart';

/// Attach a picture to a card or a quiz question.
///
/// A picture belongs to one card or one question, which is how images are
/// organised: the level editor puts one of these on every card and every
/// question, and each holds a single address. Choosing opens the media
/// library for the module being edited, where an existing picture can be
/// reused or a new one uploaded on the spot.
class AdminImageField extends StatelessWidget {
  const AdminImageField({
    super.key,
    required this.url,
    required this.moduleId,
    required this.onChanged,
    this.label = 'Picture',
  });

  final String? url;

  /// The module the picture is filed under in the media library.
  final String moduleId;
  final ValueChanged<String?> onChanged;
  final String label;

  bool get _hasImage => url != null && url!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 64,
              height: 64,
              color: AppColors.line.withValues(alpha: 0.4),
              child: _hasImage
                  ? Image.network(
                      url!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_rounded,
                        color: AppColors.coral,
                      ),
                    )
                  : const Icon(Icons.image_outlined, color: AppColors.ink),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                Text(
                  _hasImage ? url! : 'None — the card shows its words only.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                if (_hasImage && url!.startsWith('memory://'))
                  Text(
                    'Stored in memory only: it will not show on a phone. '
                    'Set up Cloudinary to keep real pictures.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.coral),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              final chosen = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _ImageChooserSheet(moduleId: moduleId),
              );
              if (chosen != null) onChanged(chosen);
            },
            child: Text(_hasImage ? 'Change' : 'Choose'),
          ),
          if (_hasImage)
            IconButton(
              tooltip: 'Remove picture',
              color: AppColors.coral,
              onPressed: () => onChanged(null),
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
    );
  }
}

class _ImageChooserSheet extends StatefulWidget {
  const _ImageChooserSheet({required this.moduleId});

  final String moduleId;

  @override
  State<_ImageChooserSheet> createState() => _ImageChooserSheetState();
}

class _ImageChooserSheetState extends State<_ImageChooserSheet> {
  final _link = TextEditingController();
  var _showAllModules = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final media = context.read<AdminMediaViewModel>();
      if (media.assets.isEmpty && !media.isLoading) media.load();
    });
  }

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _upload() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.image,
      // Bytes in memory, which is the only thing web can give us.
      withData: true,
    );
    final file = picked?.files.firstOrNull;
    if (file == null || !mounted) return;
    final bytes = file.bytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read that file.')),
      );
      return;
    }

    final media = context.read<AdminMediaViewModel>();
    final ok = await media.upload(
      adminId: context.read<AdminAuthViewModel>().admin?.uid ?? '',
      moduleId: widget.moduleId,
      type: MediaAssetType.image,
      fileName: file.name,
      contentType: _imageContentType(file.extension),
      bytes: bytes,
    );
    if (!mounted) return;
    final uploaded = media.lastUploaded;
    if (ok && uploaded != null) {
      Navigator.of(context).pop(uploaded.downloadUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = context.watch<AdminMediaViewModel>();
    final theme = Theme.of(context);
    final images = [
      for (final asset in media.assets)
        if (asset.type == MediaAssetType.image &&
            (_showAllModules || asset.moduleId == widget.moduleId))
          asset,
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AdminSectionHeading(
                title: 'Choose a picture',
                subtitle: _showAllModules
                    ? 'Pictures from every module'
                    : 'Pictures filed under "${widget.moduleId}"',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: media.isUploading ? null : _upload,
                      icon: media.isUploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.upload_rounded),
                      label: Text(media.isUploading
                          ? 'Uploading…'
                          : 'Upload a new picture'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('All modules'),
                    selected: _showAllModules,
                    onSelected: (value) =>
                        setState(() => _showAllModules = value),
                  ),
                ],
              ),
              if (media.errorMessage != null) ...[
                const SizedBox(height: 8),
                AdminInlineError(message: media.errorMessage!),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: media.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : images.isEmpty
                        ? const AdminEmptyState(
                            icon: Icons.photo_library_outlined,
                            title: 'No pictures here yet',
                            message: 'Upload one above, or paste a link '
                                'below.',
                          )
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 120,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                            ),
                            itemCount: images.length,
                            itemBuilder: (context, index) {
                              final asset = images[index];
                              return Tooltip(
                                message: asset.fileName,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => Navigator.of(context)
                                      .pop(asset.downloadUrl),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      asset.downloadUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          ColoredBox(
                                        color: AppColors.line,
                                        child: Center(
                                          child: Text(
                                            asset.fileName,
                                            textAlign: TextAlign.center,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.labelSmall,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _link,
                      decoration: const InputDecoration(
                        labelText: 'Or paste a picture link (https://…)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      final value = _link.text.trim();
                      if (value.isEmpty) return;
                      Navigator.of(context).pop(value);
                    },
                    child: const Text('Use link'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _imageContentType(String? extension) {
  return switch (extension?.toLowerCase()) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    _ => 'image/png',
  };
}
