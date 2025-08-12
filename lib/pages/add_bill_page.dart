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
  bool _isLoadingExpenseHeads = true;

  @override
  void initState() {
    super.initState();
    _loadExpenseHeads();
    _loadReportingPeriod();
  }

  Future<void> _loadExpenseHeads() async {
    final result = await Utils.loadExpenseHeads(context);
    if (mounted) {
      setState(() {
        _expenseHeads = result['expenseHeads'];
        _expenseHead = result['selectedHead'];
        _isLoadingExpenseHeads = false;
      });
    }
  }

  Future<void> _loadReportingPeriod() async {
    final result = await Utils.fetchReportingPeriod(context);
    if (mounted) {
      setState(() {
        _reportingPeriod = result;
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await Utils.pickAndCropImage(context);
    if (pickedFile != null && mounted) {
      setState(() {
        _imagePath = pickedFile.path;
      });
    }
  }

  Future<DateTime> _determineInitialDate(DateTime firstDate, DateTime lastDate) async {
    DateTime initialDate = _selectedDate;
    if (initialDate.isBefore(firstDate) || initialDate.isAfter(lastDate)) {
      initialDate = firstDate;
    }
    return initialDate;
  }

  Future<Map<String, dynamic>> _getDateRange() async {
    final reportingPeriod = _reportingPeriod ?? await Utils.fetchReportingPeriod(context);
    final dateFormat = DateFormat('dd-MMM-yy');
    DateTime firstDate = DateTime.now();
    DateTime lastDate = DateTime.now();

    if (reportingPeriod['period'] != null && !reportingPeriod['period'].contains('Error')) {
      try {
        final startDateStr = reportingPeriod['start_date'] as String?;
        final endDateStr = reportingPeriod['end_date'] as String?;
        if (startDateStr != null && endDateStr != null) {
          firstDate = dateFormat.parse(startDateStr);
          lastDate = dateFormat.parse(endDateStr);
        } else {
          throw Exception('Invalid reporting period dates');
        }
      } catch (e) {
        Utils.showSnackBar(context, 'Error parsing reporting period dates. Using default semi-monthly period.');
        final semiPeriod = Utils.getSemiMonthlyPeriod();
        firstDate = dateFormat.parse(semiPeriod['start_date']);
        lastDate = dateFormat.parse(semiPeriod['end_date']);
      }
    } else {
      final semiPeriod = Utils.getSemiMonthlyPeriod();
      firstDate = dateFormat.parse(semiPeriod['start_date']);
      lastDate = dateFormat.parse(semiPeriod['end_date']);
      if (reportingPeriod['period']?.contains('Error') != true) {
        Utils.showSnackBar(context, 'Using default semi-monthly period for date selection.');
      }
    }

    return {'firstDate': firstDate, 'lastDate': lastDate};
  }

  Future<void> _selectDate(BuildContext context) async {
    final dateRange = await _getDateRange();
    final firstDate = dateRange['firstDate'];
    final lastDate = dateRange['lastDate'];
    final initialDate = await _determineInitialDate(firstDate, lastDate);

    final picked = await Utils.selectDate(context, initialDate, firstDate, lastDate);
    if (picked != null && picked != _selectedDate && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  bool _isDateInRange(DateTime date, DateTime firstDate, DateTime lastDate) {
    return !date.isBefore(firstDate) && !date.isAfter(lastDate);
  }

  void _submitForm() {
    if (_expenseHeads.isEmpty) {
      Utils.showSnackBar(context, 'Cannot submit bill: No expense heads available.');
      return;
    }
    if (_formKey.currentState!.validate()) {
      if (_imagePath == null) {
        Utils.showSnackBar(context, 'Please pick an image');
        return;
      }

      if (_reportingPeriod == null || _reportingPeriod!['period'] == null || _reportingPeriod!['period'].contains('Error')) {
        final semiPeriod = Utils.getSemiMonthlyPeriod();
        final dateFormat = DateFormat('dd-MMM-yy');
        final firstDate = dateFormat.parse(semiPeriod['start_date']);
        final lastDate = dateFormat.parse(semiPeriod['end_date']);

        if (!_isDateInRange(_selectedDate, firstDate, lastDate)) {
          Utils.showSnackBar(context, 'Selected date is outside the current semi-monthly period');
          return;
        }
        Utils.showSnackBar(context, 'Bill will be saved locally due to reporting period issue.');
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
              _isLoadingExpenseHeads
                  ? const Center(child: CircularProgressIndicator())
                  : _expenseHeads.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Text(
                            'No expense heads available.',
                            style: GoogleFonts.montserrat(
                                fontSize: Utils.getResponsiveFontSize(context, 14.0),
                                fontWeight: FontWeight.w400,
                                color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : DropdownButtonFormField<String>(
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
                onPressed: _expenseHeads.isEmpty || _isLoadingExpenseHeads ? null : _submitForm,
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