import 'package:flutter/material.dart';
import 'package:petty_cash_app/pages/login_page.dart';
import 'package:petty_cash_app/pages/bill_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Utility function for responsive font size
double getResponsiveFontSize(BuildContext context, double baseFontSize) {
  final scaleFactor = MediaQuery.of(context).textScaleFactor;
  final screenWidth = MediaQuery.of(context).size.width;
  return baseFontSize * scaleFactor * (screenWidth / 375);
}

void main() {
  runApp(const MyApp());
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
    } else {
      return const LoginPage();
    }
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