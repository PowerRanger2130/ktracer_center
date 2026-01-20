import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/services/update_service.dart';
import 'package:provider/provider.dart';

/// Dialog shown when an update is available
class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final updateService = context.watch<UpdateService>();
    final update = updateService.availableUpdate;

    if (update == null) {
      return const SizedBox.shrink();
    }

    return ContentDialog(
      title: Row(
        children: [
          Icon(FluentIcons.download, color: Colors.blue),
          const SizedBox(width: 12),
          const Text('Update Available'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVersionInfo(context, updateService, update),
          if (update.changelog != null && update.changelog!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildChangelog(context, update.changelog!),
          ],
          if (updateService.isDownloading) ...[
            const SizedBox(height: 16),
            _buildDownloadProgress(context, updateService),
          ],
          if (updateService.error != null) ...[
            const SizedBox(height: 16),
            _buildError(context, updateService.error!),
          ],
        ],
      ),
      actions: [
        if (!updateService.isDownloading) ...[
          Button(
            onPressed: () {
              updateService.dismissUpdate();
              Navigator.of(context).pop();
            },
            child: const Text('Later'),
          ),
          Button(
            onPressed: () => updateService.openReleasePage(),
            child: const Text('View on GitHub'),
          ),
          FilledButton(
            onPressed: () => updateService.downloadAndInstall(),
            child: const Text('Download & Install'),
          ),
        ] else ...[
          Button(onPressed: null, child: const Text('Downloading...')),
        ],
      ],
    );
  }

  Widget _buildVersionInfo(
    BuildContext context,
    UpdateService service,
    UpdateInfo update,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current version: ${service.currentVersion}',
                style: FluentTheme.of(context).typography.body,
              ),
              const SizedBox(height: 4),
              Text(
                'New version: ${update.version}',
                style: FluentTheme.of(
                  context,
                ).typography.bodyStrong?.copyWith(color: Colors.green),
              ),
              if (update.publishedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Released: ${_formatDate(update.publishedAt!)}',
                  style: FluentTheme.of(context).typography.caption,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChangelog(BuildContext context, String changelog) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "What's new:",
          style: FluentTheme.of(context).typography.bodyStrong,
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: Colors.grey[190].withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              changelog,
              style: FluentTheme.of(context).typography.body,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadProgress(BuildContext context, UpdateService service) {
    final progress = service.downloadProgress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const ProgressRing(strokeWidth: 3),
            const SizedBox(width: 12),
            if (progress != null) ...[
              Expanded(
                child: Text(
                  'Downloading... ${progress.percentage.toStringAsFixed(1)}%',
                  style: FluentTheme.of(context).typography.body,
                ),
              ),
              Text(
                '${_formatBytes(progress.downloaded)} / ${_formatBytes(progress.total)}',
                style: FluentTheme.of(context).typography.caption,
              ),
            ] else ...[
              Text(
                'Starting download...',
                style: FluentTheme.of(context).typography.body,
              ),
            ],
          ],
        ),
        if (progress != null) ...[
          const SizedBox(height: 8),
          ProgressBar(value: progress.percentage),
        ],
      ],
    );
  }

  Widget _buildError(BuildContext context, String error) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.error_badge, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: FluentTheme.of(
                context,
              ).typography.caption?.copyWith(color: Colors.red.lighter),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Small indicator shown in the UI when an update is available
class UpdateIndicator extends StatelessWidget {
  const UpdateIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final updateService = context.watch<UpdateService>();

    if (!updateService.hasUpdate) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: 'Update available: v${updateService.availableUpdate?.version}',
      child: IconButton(
        icon: Stack(
          children: [
            const Icon(FluentIcons.download, size: 16),
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        onPressed: () => _showUpdateDialog(context),
      ),
    );
  }

  void _showUpdateDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const UpdateDialog());
  }
}

/// Helper function to show update dialog from anywhere
void showUpdateDialog(BuildContext context) {
  showDialog(context: context, builder: (context) => const UpdateDialog());
}

/// Mixin to add update checking functionality to a StatefulWidget
mixin UpdateCheckMixin<T extends StatefulWidget> on State<T> {
  /// Call this after the widget is built to show update dialog if available
  void checkAndShowUpdateDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final updateService = context.read<UpdateService>();
      if (updateService.hasUpdate) {
        showUpdateDialog(context);
      }
    });
  }
}
