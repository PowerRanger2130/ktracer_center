import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/app_state.dart';
import 'package:provider/provider.dart';

/// Displays connection status indicators for gRPC and Supabase
class ConnectionStatusIndicator extends StatelessWidget {
  const ConnectionStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSupabaseStatus(context, appState),
        const SizedBox(width: 8),
        _buildGrpcStatus(context, appState),
      ],
    );
  }

  Widget _buildSupabaseStatus(BuildContext context, AppState appState) {
    final status = appState.supabaseStatus;
    final error = appState.supabaseError;

    return _StatusChip(
      label: 'Database',
      status: status,
      error: error,
      onRetry: status != ConnectionStatus.connecting
          ? () => appState.retrySupabaseConnection()
          : null,
      critical: true,
    );
  }

  Widget _buildGrpcStatus(BuildContext context, AppState appState) {
    final status = appState.grpcStatus;
    final error = appState.grpcError;

    return _StatusChip(
      label: 'Device Manager',
      status: status,
      error: error,
      onRetry: status != ConnectionStatus.connecting
          ? () => appState.retryGrpcConnection()
          : null,
      critical: false,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final ConnectionStatus status;
  final String? error;
  final VoidCallback? onRetry;
  final bool critical;

  const _StatusChip({
    required this.label,
    required this.status,
    this.error,
    this.onRetry,
    this.critical = false,
  });

  @override
  Widget build(BuildContext context) {
    // Only show when not connected
    if (status == ConnectionStatus.connected) {
      return const SizedBox.shrink();
    }

    final (color, icon, text) = switch (status) {
      ConnectionStatus.connecting => (
        Colors.orange,
        FluentIcons.sync_folder,
        'Connecting...',
      ),
      ConnectionStatus.disconnected => (
        Colors.grey,
        FluentIcons.plug_disconnected,
        'Disconnected',
      ),
      ConnectionStatus.error => (
        critical ? Colors.red : Colors.orange,
        FluentIcons.error_badge,
        'Error',
      ),
      ConnectionStatus.connected => (
        Colors.green,
        FluentIcons.check_mark,
        'Connected',
      ),
    };

    final controller = FlyoutController();

    return FlyoutTarget(
      controller: controller,
      child: HyperlinkButton(
        onPressed: () {
          controller.showFlyout(
            barrierDismissible: true,
            dismissOnPointerMoveAway: false,
            placementMode: FlyoutPlacementMode.bottomCenter,
            builder: (flyoutContext) {
              return FlyoutContent(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, color: color, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '$label: $text',
                            style: FluentTheme.of(
                              context,
                            ).typography.bodyStrong,
                          ),
                        ],
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          error!,
                          style: FluentTheme.of(context).typography.caption
                              ?.copyWith(color: Colors.grey[100]),
                        ),
                      ],
                      if (critical && status != ConnectionStatus.connected) ...[
                        const SizedBox(height: 8),
                        Text(
                          'The app is locked until the database connection is restored.',
                          style: FluentTheme.of(
                            context,
                          ).typography.caption?.copyWith(color: Colors.orange),
                        ),
                      ],
                      if (onRetry != null &&
                          status != ConnectionStatus.connecting) ...[
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () {
                            Flyout.maybeOf(flyoutContext)?.close();
                            onRetry?.call();
                          },
                          child: const Text('Retry Connection'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == ConnectionStatus.connecting)
              SizedBox(
                width: 12,
                height: 12,
                child: ProgressRing(strokeWidth: 2),
              )
            else
              Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: FluentTheme.of(
                context,
              ).typography.caption?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
