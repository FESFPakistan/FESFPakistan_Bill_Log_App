import 'package:flutter/material.dart';
import 'package:petty_cash_app/pages/login_page.dart';

// Utility function for responsive font size
double getResponsiveFontSize(BuildContext context, double baseFontSize) {
  final scaleFactor = MediaQuery.of(context).textScaleFactor;
  final screenWidth = MediaQuery.of(context).size.width;
  // Base font size scaled by screen width and text scale factor
  return baseFontSize * scaleFactor * (screenWidth / 375); // 375 as reference width (e.g., iPhone 6)
}

void main() {
  runApp(MaterialApp(
    home: LoginPage(),
    debugShowCheckedModeBanner: false,
    theme: theme(),
  ));
}

ThemeData theme() {
  return ThemeData(
    fontFamily: 'GoogleSans',
    primarySwatch: Colors.deepPurple,
    textTheme: const TextTheme(
      // Define base font sizes that will be scaled
      titleLarge: TextStyle(fontSize: 18.0), // For AppBar titles
      bodyLarge: TextStyle(fontSize: 14.0), // For general text
      bodyMedium: TextStyle(fontSize: 12.0), // For smaller text
      bodySmall: TextStyle(fontSize: 10.0), // For very small text
    ),
  );
}