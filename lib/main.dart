import 'package:flutter/material.dart';
import 'package:petty_cash_app/extra%20pages/new_login_page.dart';

void main() {
  runApp(MaterialApp(
    home: NewLoginPage(),
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      fontFamily: 'GoogleSans',
      primarySwatch: Colors.deepPurple,
    ),
  ));
}