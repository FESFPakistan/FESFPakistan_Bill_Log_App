import 'package:flutter/material.dart';
import 'package:petty_cash_app/pages/login_page.dart';

void main() {
  runApp(MaterialApp(
    home: LoginPage(),
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      fontFamily: 'GoogleSans',
      primarySwatch: Colors.deepPurple,
    ),
  ));
}