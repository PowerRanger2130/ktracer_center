import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/ai_chat/models/chat_message.dart';

/// Widget to display proposed JSON changes with accept/decline buttons
/// Similar to VSCode Copilot inline suggestions
class JsonChangeWidget extends StatelessWidget {
  const JsonChangeWidget({
    required this.change,
    required this.onAccept,
    required this.onDecline,
    super.key,
  });

  final JsonChange change;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isPending = change.status == JsonChangeStatus.pending;
    final isAccepted = change.status == JsonChangeStatus.accepted;
    final isDeclined = change.status == JsonChangeStatus.declined;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: isAccepted
              ? Colors.green.withValues(alpha: 0.5)
              : isDeclined
              ? Colors.red.withValues(alpha: 0.5)
              : Colors.grey.withValues(alpha: 0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with description and status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isAccepted
                  ? Colors.green.withValues(alpha: 0.1)
                  : isDeclined
                  ? Colors.red.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(5),
                topRight: Radius.circular(5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  change.targetType == 'device'
                      ? FluentIcons.developer_tools
                      : FluentIcons.settings,
                  size: 14,
                  color: theme.typography.caption?.color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    change.description,
                    style: theme.typography.caption?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!isPending)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isAccepted
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isAccepted ? 'Accepted' : 'Declined',
                      style: theme.typography.caption?.copyWith(
                        color: isAccepted ? Colors.green : Colors.red,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Target info
          if (change.deviceName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                'Device: ${change.deviceName} • Path: ${change.path}',
                style: theme.typography.caption?.copyWith(
                  color: Colors.grey[100],
                  fontSize: 11,
                ),
              ),
            ),

          // Diff view
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Original value
                Expanded(
                  child: _buildJsonBlock(
                    context,
                    'Before',
                    change.originalJson,
                    Colors.red.withValues(alpha: 0.1),
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                // Arrow
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Icon(
                    FluentIcons.forward,
                    size: 16,
                    color: Colors.grey[100],
                  ),
                ),
                const SizedBox(width: 8),
                // New value
                Expanded(
                  child: _buildJsonBlock(
                    context,
                    'After',
                    change.newJson,
                    Colors.green.withValues(alpha: 0.1),
                    Colors.green,
                  ),
                ),
              ],
            ),
          ),

          // Action buttons (only shown when pending)
          if (isPending)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Button(
                    onPressed: onDecline,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.cancel, size: 12),
                        const SizedBox(width: 6),
                        const Text('Decline'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: onAccept,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.accept, size: 12),
                        const SizedBox(width: 6),
                        const Text('Accept'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJsonBlock(
    BuildContext context,
    String label,
    String json,
    Color bgColor,
    Color labelColor,
  ) {
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: theme.typography.caption?.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: labelColor.withValues(alpha: 0.3)),
          ),
          child: SelectableText(
            json,
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 11,
              color: theme.typography.body?.color,
            ),
          ),
        ),
      ],
    );
  }
}
