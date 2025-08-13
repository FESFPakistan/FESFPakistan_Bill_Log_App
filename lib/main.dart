import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/bill_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Utility function for responsive font size
double getResponsiveFontSize(BuildContext context, double baseFontSize) {
  final mediaQuery = MediaQuery.of(context);
  final scaler = mediaQuery.textScaler;
  final screenWidth = mediaQuery.size.width;
  final screenHeight = mediaQuery.size.height;

  // Define reference widths for different device categories
  const double smallPhoneWidth = 320.0; // e.g., iPhone SE
  const double mediumPhoneWidth = 375.0; // e.g., iPhone 6/7/8
  const double largePhoneWidth = 414.0; // e.g., iPhone 11
  const double tabletWidth = 600.0; // e.g., iPad

  // Select reference width based on screen size
  double referenceWidth;
  if (screenWidth < 360.0) {
    referenceWidth = smallPhoneWidth;
  } else if (screenWidth < 414.0) {
    referenceWidth = mediumPhoneWidth;
  } else if (screenWidth < 600.0) {
    referenceWidth = largePhoneWidth;
  } else {
    referenceWidth = tabletWidth;
  }

  // Calculate aspect ratio with safe division
  final aspectRatio = screenHeight > 0 ? screenWidth / screenHeight : 0.5625;
  final aspectRatioAdjustment = (aspectRatio / 0.5625).clamp(0.9, 1.1); // Normalize around 9:16 ratio

  // Calculate scaling factor with safe division
  final widthScalingFactor = referenceWidth > 0 ? screenWidth / referenceWidth : 1.0;

  // Combine scaling factors
  double fontSize = baseFontSize * scaler.scale(1.0) * widthScalingFactor * aspectRatioAdjustment;

  // Debug logging (optional, remove in production)
  // print('FontSize: Base=$baseFontSize, Scaler=${scaler.scale(1.0)}, Width=$screenWidth, Ref=$referenceWidth, Aspect=$aspectRatioAdjustment, Final=$fontSize');

  // Clamp font size to prevent extremes
  return fontSize.clamp(baseFontSize * 0.85, baseFontSize * 1.3);
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