import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/ai_chat/ai_chat_state.dart';
import 'package:ktracer_center/ai_chat/widgets/chat_message_widget.dart';
import 'package:provider/provider.dart';

/// The main AI Chat panel widget that slides in from the right
class AiChatPanel extends StatefulWidget {
  const AiChatPanel({super.key});

  @override
  State<AiChatPanel> createState() => _AiChatPanelState();
}

class _AiChatPanelState extends State<AiChatPanel> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(AiChatState chatState) {
    final text = _inputController.text.trim();
    if (text.isEmpty || chatState.isProcessing) return;

    chatState.sendMessage(text);
    _inputController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = context.watch<AiChatState>();

    // Auto-scroll when new messages arrive
    if (chatState.messages.isNotEmpty) {
      _scrollToBottom();
    }

    return Container(
      width: 420,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        border: Border(
          left: BorderSide(color: Colors.grey.withValues(alpha: 0.2), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(context, chatState),

          // Messages list
          Expanded(
            child: chatState.messages.isEmpty
                ? _buildEmptyState(context)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      final message = chatState.messages[index];
                      return ChatMessageWidget(
                        message: message,
                        onAcceptChange: (changeId) =>
                            chatState.acceptChange(changeId),
                        onDeclineChange: (changeId) =>
                            chatState.declineChange(changeId),
                        onAcceptAll: chatState.hasPendingChanges
                            ? () => chatState.acceptAllPendingChanges()
                            : null,
                      );
                    },
                  ),
          ),

          // Input area
          _buildInputArea(context, chatState),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AiChatState chatState) {
    final theme = FluentTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              FluentIcons.robot,
              size: 16,
              color: Colors.purple.lighter,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Assistant', style: theme.typography.bodyStrong),
                // Model selector
                SizedBox(
                  height: 24,
                  child: DropDownButton(
                    title: Text(
                      chatState.selectedModel.displayName,
                      style: theme.typography.caption?.copyWith(
                        color: Colors.purple.lighter,
                      ),
                    ),
                    items: GeminiModel.values.map((model) {
                      return MenuFlyoutItem(
                        leading: Icon(
                          chatState.selectedModel == model
                              ? FluentIcons.radio_btn_on
                              : FluentIcons.radio_btn_off,
                          size: 12,
                        ),
                        text: Text(
                          '${model.displayName} - ${model.description}',
                        ),
                        onPressed: () => chatState.setModel(model),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          if (chatState.messages.isNotEmpty)
            Tooltip(
              message: 'Clear conversation',
              child: IconButton(
                icon: Icon(FluentIcons.delete, size: 14),
                onPressed: () {
                  chatState.clearMessages();
                },
              ),
            ),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Close',
            child: IconButton(
              icon: Icon(FluentIcons.chrome_close, size: 10),
              onPressed: () {
                chatState.close();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                FluentIcons.robot,
                size: 48,
                color: Colors.purple.lighter,
              ),
            ),
            const SizedBox(height: 16),
            Text('AI Assistant', style: theme.typography.subtitle),
            const SizedBox(height: 8),
            Text(
              'Ask me about your network configuration.\nI can help you manage devices, settings, and more.',
              textAlign: TextAlign.center,
              style: theme.typography.body?.copyWith(color: Colors.grey[100]),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildSuggestionChip(context, 'List all devices'),
                _buildSuggestionChip(context, 'Show available presets'),
                _buildSuggestionChip(context, 'Help'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(BuildContext context, String text) {
    final chatState = context.read<AiChatState>();
    return HoverButton(
      onPressed: () {
        chatState.sendMessage(text);
      },
      builder: (context, states) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: states.isHovered
                ? Colors.purple.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          child: Text(text, style: FluentTheme.of(context).typography.caption),
        );
      },
    );
  }

  Widget _buildInputArea(BuildContext context, AiChatState chatState) {
    final pendingCount = chatState.pendingChangesCount;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        border: Border(
          top: BorderSide(color: Colors.grey.withValues(alpha: 0.2), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Accept All button - shown when there are pending changes
          if (pendingCount > 0) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 10),
              child: FilledButton(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.isDisabled) return Colors.grey[80];
                    if (states.isHovered) return Colors.green.lighter;
                    return Colors.green;
                  }),
                ),
                onPressed: chatState.isProcessing
                    ? null
                    : () => chatState.acceptAllPendingChanges(),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(FluentIcons.check_mark, size: 14),
                    const SizedBox(width: 8),
                    Text(
                      'Accept All Changes ($pendingCount)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
          // Input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextBox(
                  controller: _inputController,
                  focusNode: _inputFocusNode,
                  placeholder: 'Ask about your network...',
                  maxLines: 4,
                  minLines: 1,
                  enabled: !chatState.isProcessing,
                  onSubmitted: (_) => _sendMessage(chatState),
                  suffix: chatState.isProcessing
                      ? Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: ProgressRing(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: chatState.isProcessing
                    ? null
                    : () => _sendMessage(chatState),
                child: Icon(FluentIcons.send, size: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
