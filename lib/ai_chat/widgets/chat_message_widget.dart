import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/ai_chat/models/chat_message.dart';
import 'package:ktracer_center/ai_chat/widgets/json_change_widget.dart';

/// Widget to display a single chat message
class ChatMessageWidget extends StatelessWidget {
  const ChatMessageWidget({
    required this.message,
    required this.onAcceptChange,
    required this.onDeclineChange,
    this.onAcceptAll,
    super.key,
  });

  final ChatMessage message;
  final void Function(String changeId) onAcceptChange;
  final void Function(String changeId) onDeclineChange;
  final VoidCallback? onAcceptAll;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isUser = message.role == ChatRole.user;
    final isAssistant = message.role == ChatRole.assistant;
    final isPending = message.status == MessageStatus.pending;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Role indicator
          Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (isAssistant) ...[
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    FluentIcons.robot,
                    size: 12,
                    color: Colors.purple.lighter,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                isUser ? 'You' : 'AI Assistant',
                style: theme.typography.caption?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[100],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(message.timestamp),
                style: theme.typography.caption?.copyWith(
                  color: Colors.grey[120],
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Message content
          Container(
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            decoration: BoxDecoration(
              color: isUser
                  ? Colors.blue.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isUser
                    ? Colors.blue.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.2),
              ),
            ),
            child: isPending
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: ProgressRing(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Thinking...',
                        style: theme.typography.body?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[100],
                        ),
                      ),
                    ],
                  )
                : _buildMessageContent(context),
          ),

          // Tool calls (if any)
          if (message.toolCalls != null && message.toolCalls!.isNotEmpty)
            _buildToolCallsSection(context),

          // Proposed changes (if any)
          if (message.proposedChanges != null &&
              message.proposedChanges!.isNotEmpty)
            _buildProposedChangesSection(context),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    final theme = FluentTheme.of(context);
    final content = message.content;

    // Check if content has any markdown formatting
    final hasMarkdown =
        content.contains('```') ||
        content.contains('**') ||
        content.contains('`') ||
        content.contains('- ') ||
        content.contains('• ') ||
        RegExp(r'^#+\s', multiLine: true).hasMatch(content);

    if (hasMarkdown) {
      return _buildMarkdownContent(context, content);
    }

    return SelectableText(content, style: theme.typography.body);
  }

  Widget _buildMarkdownContent(BuildContext context, String content) {
    final theme = FluentTheme.of(context);
    final widgets = <Widget>[];

    // Split by code blocks first
    final codeBlockRegex = RegExp(r'```(\w*)\n([\s\S]*?)```', multiLine: true);
    int lastEnd = 0;

    for (final match in codeBlockRegex.allMatches(content)) {
      // Add text before code block
      if (match.start > lastEnd) {
        final textBefore = content.substring(lastEnd, match.start).trim();
        if (textBefore.isNotEmpty) {
          widgets.addAll(_buildTextLines(context, textBefore));
        }
      }

      // Add code block
      final code = match.group(2) ?? '';
      widgets.add(
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          child: SelectableText(
            code.trim(),
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 12,
              color: theme.typography.body?.color,
            ),
          ),
        ),
      );
      lastEnd = match.end;
    }

    // Add remaining text after last code block
    if (lastEnd < content.length) {
      final remaining = content.substring(lastEnd).trim();
      if (remaining.isNotEmpty) {
        widgets.addAll(_buildTextLines(context, remaining));
      }
    }

    // If no code blocks found, parse entire content
    if (widgets.isEmpty) {
      widgets.addAll(_buildTextLines(context, content));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  List<Widget> _buildTextLines(BuildContext context, String text) {
    final theme = FluentTheme.of(context);
    final widgets = <Widget>[];
    final lines = text.split('\n');

    for (final line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // Check for headers
      final headerMatch = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(line);
      if (headerMatch != null) {
        final level = headerMatch.group(1)!.length;
        final headerText = headerMatch.group(2)!;
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: level == 1 ? 8 : 4, bottom: 4),
            child: SelectableText(
              headerText,
              style: theme.typography.body?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: level == 1
                    ? 16
                    : level == 2
                    ? 14
                    : 13,
              ),
            ),
          ),
        );
        continue;
      }

      // Check for bullet points
      final bulletMatch = RegExp(r'^[\-•\*]\s+(.+)$').firstMatch(line.trim());
      if (bulletMatch != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: theme.typography.body),
                Expanded(
                  child: _buildInlineFormatted(context, bulletMatch.group(1)!),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Regular text with inline formatting
      widgets.add(_buildInlineFormatted(context, line));
    }

    return widgets;
  }

  Widget _buildInlineFormatted(BuildContext context, String text) {
    final theme = FluentTheme.of(context);
    final spans = <InlineSpan>[];

    // Regex for bold, inline code, and regular text
    final regex = RegExp(r'\*\*([^*]+)\*\*|`([^`]+)`|([^*`]+)');

    for (final match in regex.allMatches(text)) {
      if (match.group(1) != null) {
        // Bold text **text**
        spans.add(
          TextSpan(
            text: match.group(1),
            style: theme.typography.body?.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      } else if (match.group(2) != null) {
        // Inline code `code`
        spans.add(
          TextSpan(
            text: match.group(2),
            style: TextStyle(
              fontFamily: 'Consolas',
              fontSize: 12,
              backgroundColor: Colors.black.withValues(alpha: 0.2),
              color: theme.typography.body?.color,
            ),
          ),
        );
      } else if (match.group(3) != null) {
        // Regular text
        spans.add(TextSpan(text: match.group(3), style: theme.typography.body));
      }
    }

    if (spans.isEmpty) {
      return SelectableText(text, style: theme.typography.body);
    }

    return SelectableText.rich(TextSpan(children: spans));
  }

  Widget _buildToolCallsSection(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: message.toolCalls!.map((call) {
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  call.status == ToolCallStatus.success
                      ? FluentIcons.completed
                      : call.status == ToolCallStatus.error
                      ? FluentIcons.error_badge
                      : FluentIcons.processing,
                  size: 12,
                  color: call.status == ToolCallStatus.success
                      ? Colors.green
                      : call.status == ToolCallStatus.error
                      ? Colors.red
                      : Colors.orange,
                ),
                const SizedBox(width: 6),
                Text(
                  call.name.replaceAll('_', ' '),
                  style: theme.typography.caption?.copyWith(
                    fontFamily: 'Consolas',
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProposedChangesSection(BuildContext context) {
    final pendingChanges = message.proposedChanges!
        .where((c) => c.status == JsonChangeStatus.pending)
        .toList();
    final showAcceptAll = pendingChanges.length > 1 && onAcceptAll != null;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Accept All button when multiple pending changes
          if (showAcceptAll)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    onPressed: onAcceptAll,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(Colors.green),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.accept_medium, size: 14),
                        const SizedBox(width: 6),
                        Text('Accept All (${pendingChanges.length})'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          // Individual change widgets
          ...message.proposedChanges!
              .map(
                (change) => JsonChangeWidget(
                  change: change,
                  onAccept: () => onAcceptChange(change.id),
                  onDecline: () => onDeclineChange(change.id),
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
