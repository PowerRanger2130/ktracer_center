import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/utils/synced_controller.dart';

class SyncedToggleSwitch extends StatefulWidget {
  const SyncedToggleSwitch({
    required this.label,
    required this.controller,
    super.key,
  });

  final String label;
  final SyncedController<bool> controller;

  @override
  State<SyncedToggleSwitch> createState() => _SyncedToggleSwitchState();
}

class _SyncedToggleSwitchState extends State<SyncedToggleSwitch> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        return Row(
          children: [
            Text(widget.label),
            const SizedBox(width: 12),
            ToggleSwitch(
              checked: value,
              onChanged: (v) {
                widget.controller.onChanged(v);
              },
            ),
          ],
        );
      },
    );
  }
}
