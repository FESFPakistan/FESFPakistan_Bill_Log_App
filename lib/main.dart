import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../pages/login_page.dart';
import '../pages/bill_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  if (kIsWeb || !Platform.isAndroid) {
    // Display unsupported platform message for non-Android platforms
    runApp(const UnsupportedPlatformApp());
  } else {
    runApp(const MyApp());
  }
}

class UnsupportedPlatformApp extends StatelessWidget {
  const UnsupportedPlatformApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'This app is only supported on Android.',
            style: GoogleFonts.montserrat(
              fontSize: 18.0,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      theme: theme(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _getInitialScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('auth_token');
    final name = prefs.getString('name');
    final locationCode = prefs.getString('locationCode');

    if (authToken != null && name != null && locationCode != null) {
      return BillScreen(name: name, locationCode: locationCode);
    }
    return const LoginPage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FutureBuilder<Widget>(
        future: _getInitialScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data ?? const LoginPage();
        },
      ),
      debugShowCheckedModeBanner: false,
      theme: theme(),
    );
  }
}

ThemeData theme() {
  return ThemeData(
    fontFamily: 'GoogleSans',
    primarySwatch: Colors.deepPurple,
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 18.0),
      bodyLarge: TextStyle(fontSize: 14.0),
      bodyMedium: TextStyle(fontSize: 12.0),
      bodySmall: TextStyle(fontSize: 10.0),
    ),
  );
}