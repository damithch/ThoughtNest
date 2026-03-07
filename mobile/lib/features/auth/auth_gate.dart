import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../thoughts/ui/home_page.dart';
import 'auth_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService(FirebaseAuth.instance);
  late final Future<void> _signInFuture;

  @override
  void initState() {
    super.initState();
    _signInFuture = _authService.ensureSignedIn();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _signInFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return StreamBuilder<User?>(
          stream: _authService.authStateChanges(),
          builder: (context, authSnapshot) {
            if (!authSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: Text('Signing in...')),
              );
            }

            return HomePage(userId: authSnapshot.data!.uid);
          },
        );
      },
    );
  }
}
