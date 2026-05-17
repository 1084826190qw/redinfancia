import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ui/home_page.dart';
import 'ui/login_page.dart';

// Attempt to load .env from filesystem or bundled asset.
Future<Map<String, String>> _loadEnv() async {
  String contents = '';
  try {
    final file = File('.env');
    if (await file.exists()) {
      contents = await file.readAsString();
    } else {
      try {
        contents = await rootBundle.loadString('assets/.env');
      } catch (_) {
        throw Exception(
          'No .env file found at project root and no bundled asset available.\n'
          'Create a .env file (copy .env.example) and run again.'
        );
      }
    }
  } catch (e) {
    throw Exception('Failed to read .env: $e');
  }

  return _parseEnv(contents);
}

Map<String, String> _parseEnv(String contents) {
  final Map<String, String> result = {};
  for (var rawLine in contents.split('\n')) {
    var line = rawLine.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#')) continue;
    final idx = line.indexOf('=');
    if (idx <= 0) continue;
    final key = line.substring(0, idx).trim();
    var val = line.substring(idx + 1).trim();
    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
      val = val.substring(1, val.length - 1);
    }
    result[key] = val;
  }
  return result;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
    // Load .env (local) first, then fall back to asset-embedded .env.
    final env = await _loadEnv();
    final rawSupabaseUrl = env['SUPABASE_URL']?.trim() ?? '';
    final supabaseUrl = rawSupabaseUrl.replaceAll(RegExp(r'/+$'), '');
    final supabaseAnonKey = env['SUPABASE_ANON_KEY']?.trim() ?? '';

  if (rawSupabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw Exception(
      'Supabase configuration missing in .env.\n'
      'Create a .env file at the project root (you can copy .env.example) and set:\n'
      'SUPABASE_URL and SUPABASE_ANON_KEY (do NOT include <>).'
    );
  }

  // Basic validation: ensure the URL is https and looks like a Supabase project URL.
  bool _isValidSupabaseUrl(String url) {
    if (url.contains('<') || url.contains('>') || url.contains('%')) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.scheme != 'https') return false;
    final host = uri.host;
    if (host.isEmpty) return false;
    if (!host.endsWith('.supabase.co')) return false;
    if (uri.path.isNotEmpty && uri.path != '/') return false;
    if (uri.hasQuery || uri.hasFragment) return false;
    return true;
  }

  if (!_isValidSupabaseUrl(supabaseUrl)) {
    throw Exception(
      'Supabase URL appears invalid: "$rawSupabaseUrl".\n'
      'Use the project URL without a path or endpoint suffix, for example:\n'
      'https://my-project.supabase.co\n'
      'Do not use /rest/v1/ or any other path segment.\n'
      'Also ensure your machine can resolve the host (DNS / network).'
    );
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } catch (e) {
    throw Exception(
      'Failed to initialize Supabase client: $e\n'
      'Check SUPABASE_URL and SUPABASE_ANON_KEY values and network/DNS connectivity.'
    );
  }

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
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) async {
        print('Auth state changed: ${data.event}, session: ${data.session}');
        if (data.event == AuthChangeEvent.initialSession) return;
        
        // When user signs in, ensure their record exists in usuarios table
        if (data.event == AuthChangeEvent.signedIn && data.session?.user != null) {
          await _ensureUserExists(data.session!.user);
        }
        
        if (!mounted) return;
        setState(() {
          _session = data.session;
          _isLoading = false;
        });
      },
      onError: (error) {
        print('Auth error: $error');
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
      },
    );

    await Supabase.instance.client.auth.signOut();

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted || !_isLoading) return;
      setState(() {
        _isLoading = false;
      });
    });
  }

  /// Ensure the user has a record in the usuarios table.
  /// This prevents foreign key constraint violations when creating child records.
  Future<void> _ensureUserExists(User user) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Check if user already exists in usuarios table
      final existing = await supabase
          .from('usuarios')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();
      
      if (existing == null) {
        // User does not exist, create their record
        await supabase.from('usuarios').insert({
          'id': user.id,
          'email': user.email ?? '',
          'nombre': user.userMetadata?['nombre'] ?? user.email ?? 'Usuario',
          'rol': 'educador',
          'activo': true,
        });
        print('Created user record in usuarios table for ${user.id}');
      } else {
        print('User record already exists in usuarios table for ${user.id}');
      }
    } catch (e) {
      print('Error ensuring user exists: $e');
      // Don't throw - allow the app to continue even if this fails
    }
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
