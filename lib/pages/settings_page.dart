import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/app_state.dart';
import 'package:provider/provider.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final typography = FluentTheme.of(context).typography;

    return FluentWidgets.scaffold(
      header: 'Settings',
      showBackground: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Debug', style: typography.subtitle),
          const SizedBox(height: 12),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mock Device Manager connection',
                            style: typography.body,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Show Device Manager as connected and stop reconnection attempts. '
                            'Useful for debugging without the device manager running.',
                            style: typography.caption?.copyWith(
                              color: FluentTheme.of(
                                context,
                              ).resources.textFillColorSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ToggleSwitch(
                      checked: appState.mockGrpcConnected,
                      onChanged: (v) =>
                          context.read<AppState>().setMockGrpcConnected(v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
