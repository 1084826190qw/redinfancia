import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ui/home_page.dart';
import 'ui/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://nmlzqpoyjnmvaomtjfsu.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5tbHpxcG95am5tdmFvbXRqZnN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MDA1MDIsImV4cCI6MjA5MDQ3NjUwMn0.fs5ZCHf_u_lxImr875Erv1jzQsgwoStn8QfThu1bV7E',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RedInfancia',
      debugShowCheckedModeBanner: false,
      locale: const Locale('es'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es'),
        Locale('en'),
      ],
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Session? _session;
  bool _isLoading = true;
  bool _initialCheckDone = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    // Limpiar cualquier sesión existente al iniciar la app
    await Supabase.instance.client.auth.signOut();

    // Esperar un momento para que se complete el signOut
    await Future.delayed(const Duration(milliseconds: 200));

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        print('Auth state changed: ${data.event}');
        setState(() {
          _session = data.session;
          _isLoading = false;
          _initialCheckDone = true;
        });
      },
      onError: (error) {
        print('Auth error: $error');
        setState(() {
          _isLoading = false;
          _initialCheckDone = true;
        });
      },
    );

    // Forzar que termine la carga después de un tiempo
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
          _initialCheckDone = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _session == null ? const LoginPage() : const HomePage();
  }
}
