import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:petty_cash_app/pages/login_page.dart';
import 'package:petty_cash_app/pages/add_bill_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BillScreen extends StatefulWidget {
  final String name;
  final String locationCode;

  const BillScreen({super.key, required this.name, required this.locationCode});

  @override
  _BillScreenState createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  List<Map<String, dynamic>> bills = [];
  double _balance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadBills();
  }

  Future<void> _loadBills() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${widget.locationCode}_${widget.name.replaceAll(' ', '_')}_bills.json';
      final file = File('${directory.path}/$fileName');
      if (file.existsSync()) {
        final jsonString = await file.readAsString();
        setState(() {
          bills = List<Map<String, dynamic>>.from(json.decode(jsonString));
        });
      }
    } catch (e) {
      print('Error loading bills: $e');
    }
  }

  Future<void> _saveBills() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${widget.locationCode}_${widget.name.replaceAll(' ', '_')}_bills.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(json.encode(bills));
    } catch (e) {
      print('Error saving bills: $e');
    }
  }

  Future<void> _addBill(String narration, double amount, String expenseHead, DateTime date, String? imagePath) async {
    final newBill = {
      'narration': narration,
      'amount': amount,
      'expenseHead': expenseHead,
      'date': date.toIso8601String(),
      'imagePath': imagePath,
      'attached': false,
    };
    setState(() {
      bills.add(newBill);
    });
    await _saveBills();
  }

  Future<bool?> _deleteBill(int index) async {
    bool? confirm = false;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Delete', style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w500)),
        content: Text('Are you sure you want to delete this bill?', style: GoogleFonts.montserrat(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancel', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                bills.removeAt(index);
              });
              _saveBills();
              Navigator.of(context).pop();
              confirm = true;
            },
            child: Text('Delete', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
    return confirm;
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('name');
    await prefs.remove('locationCode');
    await prefs.remove('user_id');
    await prefs.remove('email');
    await prefs.remove('location_id');
    await prefs.remove('location_name');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  void _refreshBalance() {
    setState(() {
      _balance = Random().nextDouble() * 1000000;
    });
  }

  void _showBillDetails(Map<String, dynamic> bill) {
    final dateTime = DateTime.parse(bill['date']);
    final formattedDate = DateFormat('dd-MMM-yy').format(dateTime);
    final monthName = DateFormat('MMMM').format(dateTime);
    final financialPeriod = dateTime.day <= 15 ? '1st Half' : '2nd Half';
    final financialPeriodLabel = '$monthName-$financialPeriod';
    bool isAttached = bill['attached'] ?? false;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bill Details', style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Date: $formattedDate', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500)),
              Text('Expense Head: ${bill['expenseHead'] ?? 'General'}', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w400)),
              Text('Narration: ${bill['narration'] ?? ''}', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w400)),
              Text('Amount: Rs. ${NumberFormat('#,###').format(bill['amount'].round())}', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500)),
              Text('Status: ${isAttached ? 'Uploaded' : 'Not Uploaded'} ($financialPeriodLabel)', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w400)),
              if (bill['imagePath'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Image.file(
                    File(bill['imagePath']),
                    fit: BoxFit.contain,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Close', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedBills = List<Map<String, dynamic>>.from(bills)
      ..sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
    final top10Bills = sortedBills.take(10).toList();
    final currentDateTime = DateFormat('dd-MMM-yy hh:mm a').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.name, style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2.0),
                Text(widget.locationCode, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w400)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(128, 128, 128, 0.2),
              spreadRadius: 2,
              blurRadius: 5,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 2.0,
                margin: const EdgeInsets.only(bottom: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Balance', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500)),
                          Text(
                            currentDateTime,
                            style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w400, color: Colors.grey),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            'Rs. ${NumberFormat('#,###').format(_balance.round())}',
                            style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 8.0),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _refreshBalance,
                            iconSize: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: top10Bills.length,
                  itemBuilder: (context, index) {
                    final bill = top10Bills[index];
                    final dateTime = DateTime.parse(bill['date']);
                    final formattedDate = DateFormat('dd-MMM-yy').format(dateTime);
                    final monthName = DateFormat('MMMM').format(dateTime);
                    final financialPeriod = dateTime.day <= 15 ? '1st Half' : '2nd Half';
                    final financialPeriodLabel = '$monthName-$financialPeriod';
                    bool isAttached = bill['attached'] ?? false;

                    return Dismissible(
                      key: Key(bill['date'] + (bill['narration'] ?? '')),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16.0),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        return await _deleteBill(bills.indexOf(bill));
                      },
                      child: Card(
                        elevation: 2.0,
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: SizedBox(
                          height: 120.0,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Date: $formattedDate', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w500)),
                                      Text('Exp: ${bill['expenseHead'] ?? 'General'}', style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w400)),
                                      Text(
                                        bill['narration'] ?? '',
                                        style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w400),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onLongPress: () {
                                              setState(() {
                                                bill['attached'] = !(bill['attached'] ?? false);
                                              });
                                            },
                                            child: Container(
                                              color: isAttached ? Colors.green : Colors.red,
                                              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                                              child: Text(
                                                isAttached ? 'Uploaded' : 'Not Uploaded',
                                                style: GoogleFonts.montserrat(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w400),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '($financialPeriodLabel)',
                                            style: GoogleFonts.montserrat(fontSize: 8, fontWeight: FontWeight.w400),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Rs. ${NumberFormat('#,###').format(bill['amount'].round())}', style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w500)),
                                    if (bill['imagePath'] != null)
                                      GestureDetector(
                                        onDoubleTap: () {
                                          _showBillDetails(bill);
                                        },
                                        child: Image.file(
                                          File(bill['imagePath']),
                                          height: 60,
                                          width: 60,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddBillPage()),
                        );
                        if (result != null) {
                          final narration = result['narration'] as String;
                          final amount = result['amount'] as double;
                          final expenseHead = result['expenseHead'] as String;
                          final date = result['date'] as DateTime;
                          final imagePath = result['imagePath'] as String?;
                          await _addBill(narration, amount, expenseHead, date, imagePath);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(150, 40),
                        elevation: 0,
                      ),
                      child: Text('Add Bill', style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w500)),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Upload All feature coming soon!')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(150, 40),
                        elevation: 0,
                      ),
                      child: Text('Upload All', style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}