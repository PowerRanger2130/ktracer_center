import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/ai_chat/widgets/ai_chat_button.dart';
import 'package:ktracer_center/widgets/avatar_button.dart';
import 'package:ktracer_center/widgets/connection_status_indicator.dart';

class TitleBarContent extends StatelessWidget {
  const TitleBarContent({
    required this.menus,
    required this.selectedMenu,
    required this.onMenuChanged,
    super.key,
  });
  final List<String> menus;
  final String? selectedMenu;
  final void Function(String) onMenuChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 16),
        SizedBox(
          height: 34,
          child: ComboBox(
            value: selectedMenu,
            items: menus
                .map((e) => ComboBoxItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) {
              if (v != null) onMenuChanged(v);
            },
          ),
        ),
        const SizedBox(width: 16),
        const ConnectionStatusIndicator(),
        Spacer(),
        const AiChatButton(),
        const SizedBox(width: 8),
        AvatarButton(),
        const SizedBox(width: 16),
      ],
    );
  }
}
