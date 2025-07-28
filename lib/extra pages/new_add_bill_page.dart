import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NewAddBillPage extends StatefulWidget {
  const NewAddBillPage({Key? key}) : super(key: key);

  @override
  _NewAddBillPageState createState() => _NewAddBillPageState();
}

class _NewAddBillPageState extends State<NewAddBillPage> {
  final _formKey = GlobalKey<FormState>();
  final _narrationController = TextEditingController();
  final _amountController = TextEditingController();
  String? _expenseHead;
  DateTime _selectedDate = DateTime.now();
  String? _imagePath;
  List<Map<String, dynamic>> _expenseHeads = [];

  @override
  void initState() {
    super.initState();
    _loadSavedExpenseHeads();
    _checkRefreshCondition();
  }

  Future<void> _loadSavedExpenseHeads() async {
    final prefs = await SharedPreferences.getInstance();
    final savedExpenseHeads = prefs.getString('expense_heads');
    if (savedExpenseHeads != null) {
      setState(() {
        _expenseHeads = List<Map<String, dynamic>>.from(json.decode(savedExpenseHeads));
      });
    }
  }

  Future<void> _checkRefreshCondition() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRefresh = prefs.getInt('last_refresh_date') ?? 0;
    final now = DateTime.now();
    final currentDay = now.day;
    final connectivityResult = await Connectivity().checkConnectivity();

    if ((currentDay == 1 || currentDay == 16 || lastRefresh == 0) && connectivityResult != ConnectivityResult.none) {
      await _fetchExpenseHeads();
    }
  }

  Future<void> _fetchExpenseHeads() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null) return;

    final url = Uri.parse("https://stage-cash.fesf-it.com/api/expense-heads");
    try {
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          _expenseHeads = data.map((item) => {'id': item['id'], 'name': item['name'], 'code': item['code']}).toList();
        });
        await prefs.setString('expense_heads', json.encode(_expenseHeads));
        await prefs.setInt('last_refresh_date', DateTime.now().day);
      } else {
        throw Exception('Failed to load expense heads: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading expense heads: $e')),
      );
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    String? sourcePath;

    final source = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text('Select Image Source', style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w500)),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              child: Text('Gallery', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w400)),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              child: Text('Camera', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w400)),
            ),
          ],
        );
      },
    );

    if (source != null) {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        sourcePath = pickedFile.path;
      }
    }

    if (sourcePath != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: sourcePath!,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 80,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Edit Image',
            toolbarColor: Colors.deepPurple,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Edit Image',
            rotateButtonsHidden: false,
            rotateClockwiseButtonHidden: false,
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _imagePath = croppedFile.path;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    final currentDay = now.day;

    DateTime firstAllowedDate;
    DateTime lastAllowedDate;

    if (currentDay > 15) {
      firstAllowedDate = DateTime(currentYear, currentMonth, 1);
      lastAllowedDate = now;
    } else {
      final prevMonth = currentMonth == 1 ? 12 : currentMonth - 1;
      final prevYear = currentMonth == 1 ? currentYear - 1 : currentYear;
      firstAllowedDate = DateTime(prevYear, prevMonth, 16);
      lastAllowedDate = now;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstAllowedDate,
      lastDate: lastAllowedDate,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.deepPurple,
            colorScheme: ColorScheme.light(primary: Colors.deepPurple),
            buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submitForm() {
    if (_formKey.currentState != null && _formKey.currentState!.validate()) {
      final result = {
        'narration': _narrationController.text,
        'amount': double.tryParse(_amountController.text) ?? 0.0,
        'expenseHead': _expenseHead ?? 'General',
        'date': _selectedDate,
        'imagePath': _imagePath,
      };
      Navigator.pop(context, result);
    }
  }

  @override
  void dispose() {
    _narrationController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Bill', style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _narrationController,
                decoration: InputDecoration(labelText: 'Narration', labelStyle: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w400)),
                validator: (value) => value!.isEmpty ? 'Please enter narration' : null,
              ),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(labelText: 'Amount', labelStyle: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w400)),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Please enter amount' : null,
              ),
              DropdownButtonFormField<String>(
                value: _expenseHead,
                decoration: InputDecoration(labelText: 'Expense Head', labelStyle: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w400)),
                items: _expenseHeads.map((head) {
                  return DropdownMenuItem<String>(
                    value: head['name'],
                    child: Text(head['name'], style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w400)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _expenseHead = value;
                  });
                },
                validator: (value) => value == null ? 'Please select an expense head' : null,
              ),
              ListTile(
                title: Text('Date: ${DateFormat('dd/MM/yy').format(_selectedDate)}', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w400)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
              ),
              if (_imagePath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Image.file(File(_imagePath!), height: 100),
                ),
              ElevatedButton(
                onPressed: _pickImage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(150, 40),
                  elevation: 0,
                ),
                child: Text('Pick Image', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500)),
              ),
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(150, 40),
                  elevation: 0,
                ),
                child: Text('Submit', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}