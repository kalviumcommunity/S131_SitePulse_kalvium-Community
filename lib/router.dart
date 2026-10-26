import 'package:go_router/go_router.dart';
import 'features/auth/boot_screen.dart';

GoRouter buildRouter({required bool firebaseReady}) => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => BootScreen(firebaseReady: firebaseReady),
        ),
      ],
    );