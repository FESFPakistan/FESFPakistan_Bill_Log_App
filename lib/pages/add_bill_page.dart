import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../utils.dart';

class AddBillPage extends StatefulWidget {
  const AddBillPage({super.key});

  @override
  _AddBillPageState createState() => _AddBillPageState();
}

class _AddBillPageState extends State<AddBillPage> {
  final _formKey = GlobalKey<FormState>();
  final _narrationController = TextEditingController();
  final _amountController = TextEditingController();
  String? _expenseHead;
  DateTime _selectedDate = DateTime.now();
  String? _imagePath;
  List<Map<String, dynamic>> _expenseHeads = [];
  Map<String, dynamic>? _reportingPeriod;

  @override
  void initState() {
    super.initState();
    _loadExpenseHeads();
    _loadReportingPeriod();
  }

  Future<void> _loadExpenseHeads() async {
    final result = await Utils.loadExpenseHeads(context);
    setState(() {
      _expenseHeads = result['expenseHeads'];
      _expenseHead = result['selectedHead'];
    });
  }

  Future<void> _loadReportingPeriod() async {
    final result = await Utils.fetchReportingPeriod(context);
    setState(() {
      _reportingPeriod = result;
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await Utils.pickAndCropImage(context);
    if (pickedFile != null) {
      setState(() {
        _imagePath = pickedFile.path;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    // Fetch the active reporting period to get start and end dates
    final reportingPeriod = _reportingPeriod ?? await Utils.fetchReportingPeriod(context);
    DateTime firstDate = DateTime.now();
    DateTime lastDate = DateTime.now();
    DateTime initialDate = _selectedDate;

    if (reportingPeriod['period'] != null && !reportingPeriod['period'].contains('Error')) {
      try {
        final startDateStr = reportingPeriod['start_date'];
        final endDateStr = reportingPeriod['end_date'];
        final dateFormat = DateFormat('dd-MMM-yy');
        firstDate = dateFormat.parse(startDateStr);
        lastDate = dateFormat.parse(endDateStr);

        // Ensure initialDate is within the reporting period
        if (initialDate.isBefore(firstDate) || initialDate.isAfter(lastDate)) {
          initialDate = firstDate; // Set to start_date if outside range
        }
      } catch (e) {
        Utils.showSnackBar(context, 'Error parsing reporting period dates: $e');
        return;
      }
    } else {
      Utils.showSnackBar(context, 'Failed to load reporting period');
      return;
    }

    final picked = await Utils.selectDate(context, initialDate, firstDate, lastDate);
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (_imagePath == null) {
        Utils.showSnackBar(context, 'Please pick an image');
        return;
      }
      if (_reportingPeriod == null || _reportingPeriod!['period'] == null || _reportingPeriod!['period'].contains('Error')) {
        Utils.showSnackBar(context, 'Cannot add bill: Reporting period not loaded');
        return;
      }
      Navigator.pop(context, {
        'narration': _narrationController.text,
        'amount': double.tryParse(_amountController.text) ?? 0.0,
        'expenseHead': _expenseHead,
        'date': _selectedDate,
        'imagePath': _imagePath,
      });
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
        title: Text(
          'Add Bill',
          style: GoogleFonts.montserrat(
              fontSize: Utils.getResponsiveFontSize(context, 18.0),
              fontWeight: FontWeight.w600),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Utils.buildTextFormField(
                controller: _narrationController,
                label: 'Narration',
                context: context,
                validator: (value) => value!.isEmpty ? 'Please enter narration' : null,
              ),
              Utils.buildTextFormField(
                controller: _amountController,
                label: 'Amount',
                context: context,
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Please enter amount' : null,
              ),
              DropdownButtonFormField<String>(
                value: _expenseHead,
                decoration: Utils.inputDecoration(context, 'Expense Head'),
                items: _expenseHeads.map((head) {
                  return DropdownMenuItem<String>(
                    value: head['name'],
                    child: Text(
                      head['name'],
                      style: GoogleFonts.montserrat(
                          fontSize: Utils.getResponsiveFontSize(context, 10.0),
                          fontWeight: FontWeight.w400),
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _expenseHead = value),
                validator: (value) => value == null ? 'Please select an expense head' : null,
              ),
              ListTile(
                title: Text(
                  'Date: ${DateFormat('dd/MM/yy').format(_selectedDate)}',
                  style: GoogleFonts.montserrat(
                      fontSize: Utils.getResponsiveFontSize(context, 14.0),
                      fontWeight: FontWeight.w400),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context),
              ),
              if (_imagePath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Image.file(File(_imagePath!), height: 100),
                ),
              Utils.buildElevatedButton(
                onPressed: _pickImage,
                label: 'Pick Image',
                context: context,
              ),
              Utils.buildElevatedButton(
                onPressed: _submitForm,
                label: 'Submit',
                context: context,
              ),
            ],
          ),
        ),
      ),
    );
  }
}