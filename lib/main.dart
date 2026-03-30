import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      home: LoginPage(),
    );
  }
}