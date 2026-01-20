import 'package:fluent_ui/fluent_ui.dart';
import 'package:ktracer_center/app_state.dart';
import 'package:ktracer_center/database/database.dart';
import 'package:provider/provider.dart';
import 'package:strworks/widgets/fluent/fluent_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AvatarFlyout extends StatefulWidget {
  const AvatarFlyout({super.key});

  @override
  State<AvatarFlyout> createState() => _AvatarFlyoutState();
}

class _AvatarFlyoutState extends State<AvatarFlyout> {
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    bool authenticated = Supabase.instance.client.auth.currentUser != null;

    return FluentWidgets.acrylic(
      child: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: authenticated
              ? [
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 12, 24),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                          ),
                          child: Center(
                            child: Text(
                              user?.shortName ?? "??",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Text(
                                user?.name ?? "Unknown User",
                                style: FluentTheme.of(context)
                                    .typography
                                    .subtitle
                                    ?.copyWith(color: Colors.white),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Text(
                                Supabase
                                        .instance
                                        .client
                                        .auth
                                        .currentUser
                                        ?.email ??
                                    "No email",
                              ),
                            ),
                            const SizedBox(height: 8),
                            HyperlinkButton(
                              onPressed: () {
                                Supabase.instance.client.auth.signOut();
                              },
                              child: Text("Sign out"),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  //Divider(),
                ]
              : [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: HyperlinkButton(
                      onPressed: () async {
                        await KtUser.oauthLogin();
                      },
                      child: Text("Sign in"),
                    ),
                  ),
                ],
        ),
      ),
    );
  }
}
