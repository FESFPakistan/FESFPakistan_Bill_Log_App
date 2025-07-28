import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:petty_cash_app/pages/bill_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NewLoginPage extends StatefulWidget {
  @override
  _NewLoginPageState createState() => _NewLoginPageState();
}

class _NewLoginPageState extends State<NewLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _checkTokenAndNavigate();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _usernameController.text = prefs.getString('saved_email') ?? '';
      _passwordController.text = prefs.getString('saved_password') ?? '';
      _rememberMe = prefs.getBool('remember_me') ?? false;
    });
  }

  Future<void> _checkTokenAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('auth_token');
    if (savedToken != null) {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        if (await _validateToken(savedToken)) {
          final name = prefs.getString('name') ?? '';
          final locationCode = prefs.getString('locationCode') ?? '';
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BillScreen(name: name, locationCode: locationCode),
            ),
          );
        }
      } else {
        final name = prefs.getString('name') ?? '';
        final locationCode = prefs.getString('locationCode') ?? '';
        if (name.isNotEmpty && locationCode.isNotEmpty) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => BillScreen(name: name, locationCode: locationCode),
            ),
          );
        }
      }
    }
  }

  Future<bool> _validateToken(String token) async {
    final url = Uri.parse("https://stage-cash.fesf-it.com/api/validate-token");
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      final email = _usernameController.text;
      final password = _passwordController.text;

      final url = Uri.parse("https://stage-cash.fesf-it.com/api/login");
      try {
        setState(() => _isLoading = true);
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
          await prefs.setString('auth_token', token);
          await prefs.setString('name', user['name']);
          await prefs.setString('locationCode', user['location']['code']);
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Login failed")),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
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
        title: Text('Login', style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: 'Email', labelStyle: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w400)),
                validator: (value) => value!.isEmpty ? 'Please enter email' : null,
                keyboardType: TextInputType.emailAddress,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Password', labelStyle: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w400)),
                obscureText: true,
                validator: (value) => value!.isEmpty ? 'Please enter password' : null,
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
                  Text('Remember Me', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w400)),
                ],
              ),
              SizedBox(height: 20.0),
              _isLoading
                  ? CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(150, 40),
                        elevation: 0,
                      ),
                      child: Text('Login', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}