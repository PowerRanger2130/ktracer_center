import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/ai_chat/ai_chat_state.dart';
import 'package:provider/provider.dart';

/// Button to toggle the AI chat panel
class AiChatButton extends StatelessWidget {
  const AiChatButton({super.key});

  @override
  Widget build(BuildContext context) {
    final chatState = context.watch<AiChatState>();
    final isOpen = chatState.isOpen;

    return Tooltip(
      message: isOpen ? 'Close AI Chat' : 'Open AI Chat',
      child: HoverButton(
        onPressed: () {
          chatState.toggleOpen();
        },
        builder: (context, states) {
          return Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isOpen
                  ? Colors.purple.withValues(alpha: 0.3)
                  : states.isHovered
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: isOpen
                  ? Border.all(
                      color: Colors.purple.withValues(alpha: 0.5),
                      width: 1,
                    )
                  : null,
            ),
            child: Center(
              child: Icon(
                FluentIcons.robot,
                size: 16,
                color: isOpen ? Colors.purple.lighter : null,
              ),
            ),
          );
        },
      ),
    );
  }
}
