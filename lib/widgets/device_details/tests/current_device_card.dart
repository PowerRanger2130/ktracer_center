import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/devices/device_preset.dart';
import 'package:ktracer_center/models/net_device.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

class CurrentDeviceCard extends StatelessWidget {
  const CurrentDeviceCard({required this.device, super.key});

  final NetDevice device;

  @override
  Widget build(BuildContext context) {
    final icon = device.category == NetDeviceCategory.Switch
        ? FluentIcons.switch_widget
        : FluentIcons.branch_fork2;
    final bodyStrong = FluentTheme.of(context).typography.bodyStrong;
    final caption = FluentTheme.of(context).typography.caption;

    return Card(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: device.color?.withValues(alpha: .25) ?? Colors.grey[40],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 18, color: device.color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                device.hostname,
                maxLines: 1,
                style:
                    bodyStrong?.copyWith(fontSize: 14) ??
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                device.category.name,
                maxLines: 1,
                style:
                    caption?.copyWith(fontSize: 12, color: Colors.grey[100]) ??
                    TextStyle(fontSize: 12, color: Colors.grey[100]),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(width: 12),
          FluentWidgets.chip(text: device.sku, color: device.color),
        ],
      ),
    );
  }
}

class TestDialogHeaderRow extends StatelessWidget {
  const TestDialogHeaderRow({
    required this.title,
    required this.device,
    this.afterTitle,
    super.key,
  });

  final String title;
  final NetDevice device;
  final Widget? afterTitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        if (afterTitle != null) ...[const SizedBox(width: 8), afterTitle!],
        const Spacer(),
        CurrentDeviceCard(device: device),
      ],
    );
  }
}
