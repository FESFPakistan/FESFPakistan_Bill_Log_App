import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:petty_cash_app/pages/bill_screen.dart';

class HardLoginPage extends StatefulWidget {
  @override
  _HardLoginPageState createState() => _HardLoginPageState();
}

class _HardLoginPageState extends State<HardLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      if (_isLoading) return;
      setState(() => _isLoading = true);

      final email = _usernameController.text;
      final password = _passwordController.text;

      // Hardcoded credentials
      const String validEmail = 'test@example.com';
      const String validPassword = 'password123';

      if (email == validEmail && password == validPassword) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() => _isLoading = false);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => BillScreen(
                  name: 'Test User',
                  locationCode: 'LOC001',
                ),
              ),
            );
          }
        });
      } else {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Invalid email or password')),
            );
          }
        });
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