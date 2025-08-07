import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../pages/bill_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
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
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final email = _usernameController.text;
      final password = _passwordController.text;
      final url = Uri.parse("https://stage-cash.fesf-it.com/api/login");

      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body)['data'];
          final user = data['user'];
          final token = data['token'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('name', user['name']);
          await prefs.setString('locationCode', user['location']['code']);
          await prefs.setString('auth_token', token);
          await prefs.setInt('user_id', user['id']);
          await prefs.setString('email', user['email']);
          await prefs.setInt('location_id', user['location']['id']);
          await prefs.setString('location_name', user['location']['name']);

          if (_rememberMe) {
            await prefs.setString('saved_email', email);
            await prefs.setString('saved_password', password);
            await prefs.setBool('remember_me', true);
          } else {
            await prefs.remove('saved_email');
            await prefs.remove('saved_password');
            await prefs.remove('remember_me');
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BillScreen(
                name: user['name'],
                locationCode: user['location']['code'],
              ),
            ),
          );
        } else {
          Utils.showSnackBar(context, jsonDecode(response.body)['message'] ?? "Login failed");
        }
      } catch (e) {
        Utils.showSnackBar(context, "Error: $e");
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
            fontSize: Utils.getResponsiveFontSize(context, 18.0),
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
            children: [
              Utils.buildTextFormField(
                controller: _usernameController,
                label: 'Email',
                context: context,
                validator: (value) => value!.isEmpty ? 'Please enter email' : null,
                keyboardType: TextInputType.emailAddress,
              ),
              Utils.buildTextFormField(
                controller: _passwordController,
                label: 'Password',
                context: context,
                obscureText: true,
                validator: (value) => value!.isEmpty ? 'Please enter password' : null,
              ),
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (value) => setState(() => _rememberMe = value ?? false),
                  ),
                  Text(
                    'Remember Me',
                    style: GoogleFonts.montserrat(
                      fontSize: Utils.getResponsiveFontSize(context, 14.0),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20.0),
              _isLoading
                  ? const CircularProgressIndicator()
                  : Utils.buildElevatedButton(
                      onPressed: _login,
                      label: 'Login',
                      context: context,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}