import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/app_state.dart';
import 'package:ktracer_center/widgets/avatar_flyout.dart';
import 'package:provider/provider.dart';

class AvatarButton extends StatefulWidget {
  const AvatarButton({super.key});

  @override
  State<AvatarButton> createState() => _AvatarButtonState();
}

class _AvatarButtonState extends State<AvatarButton> {
  bool _hover = false;
  bool _pressed = false;
  final controller = FlyoutController();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;

    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _hover = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hover = false;
        });
      },
      child: GestureDetector(
        onTapDown: (_) {
          setState(() {
            _pressed = true;
          });
        },
        onTapUp: (_) {
          setState(() {
            _pressed = false;
          });
        },
        onTap: () {
          controller.showFlyout(
            margin: 0,
            builder: (context) => AvatarFlyout(),
            barrierColor: Colors.transparent,
            autoModeConfiguration: FlyoutAutoConfiguration(
              preferredMode: FlyoutPlacementMode.bottomRight,
            ),
          );
        },
        child: FlyoutTarget(
          controller: controller,
          child: AnimatedScale(
            scale: _pressed
                ? 0.85
                : _hover
                ? .95
                : 1,
            duration: const Duration(milliseconds: 75),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color.fromARGB(207, 193, 35, 35),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Center(
                child: user != null
                    ? Text(
                        user.shortName ?? user.name.substring(0, 1),
                        style: FluentTheme.of(context).typography.bodyStrong,
                      )
                    : Icon(FluentIcons.user_warning, size: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
