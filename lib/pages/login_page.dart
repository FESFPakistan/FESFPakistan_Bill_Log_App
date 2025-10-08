import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'bill_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _usernameController.text = prefs.getString('saved_email') ?? '';
      _passwordController.text = prefs.getString('saved_password') ?? '';
      _rememberMe = prefs.getBool('remember_me') ?? false;
    });
  }

  Future<void> _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      final email = _usernameController.text.trim();
      final password = _passwordController.text;

      final url = Uri.parse("https://stage-cash.fesf-it.com/api/login");
      try {
        setState(() => _isLoading = true);
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json', 'Accept': 'application/json',},
          body: jsonEncode({'email': email, 'password': password}),
        );

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final data = decoded['data'];
          final user = data['user'];
          final token = data['token'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('name', user['name'] ?? '');
          await prefs.setString('locationCode', user['location']?['code'] ?? '');
          await prefs.setString('auth_token', token ?? '');
          await prefs.setInt('user_id', user['id'] ?? 0);
          await prefs.setString('email', user['email'] ?? '');
          await prefs.setInt('location_id', user['location']?['id'] ?? 0);
          await prefs.setString('location_name', user['location']?['name'] ?? '');

          if (_rememberMe) {
            await prefs.setString('saved_email', email);
            await prefs.setString('saved_password', password);
            await prefs.setBool('remember_me', true);
          } else {
            await prefs.remove('saved_email');
            await prefs.remove('saved_password');
            await prefs.remove('remember_me');
          }

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) {
                final name = user['name'] ?? '';
                final locationCode = user['location']?['code'] ?? '';
                return BillScreen(name: name, locationCode: locationCode);
              },
            ),
          );
        } else {
          String errorMsg = "Login failed";
          try {
            final errorData = jsonDecode(response.body);
            if (errorData is Map && errorData['message'] != null) {
              errorMsg = errorData['message'];
            }
          } catch (_) {}
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorMsg,
                style: TextStyle(fontSize: getResponsiveFontSize(context, 14.0)),
              ),
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Error: $e",
              style: TextStyle(fontSize: getResponsiveFontSize(context, 14.0)),
            ),
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Login',
          style: GoogleFonts.montserrat(
            fontSize: getResponsiveFontSize(context, 18.0),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: GoogleFonts.montserrat(
                    fontSize: getResponsiveFontSize(context, 14.0),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Please enter email' : null,
                keyboardType: TextInputType.emailAddress,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: GoogleFonts.montserrat(
                    fontSize: getResponsiveFontSize(context, 14.0),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                obscureText: true,
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Please enter password' : null,
              ),
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (value) {
                      setState(() {
                        _rememberMe = value ?? false;
                      });
                    },
                  ),
                  Text(
                    'Remember Me',
                    style: GoogleFonts.montserrat(
                      fontSize: getResponsiveFontSize(context, 14.0),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20.0),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(150, 40),
                        elevation: 0,
                      ),
                      child: Text(
                        'Login',
                        style: GoogleFonts.montserrat(
                          fontSize: getResponsiveFontSize(context, 14.0),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}