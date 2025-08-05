import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:petty_cash_app/main.dart';
import 'package:petty_cash_app/pages/login_page.dart';
import 'package:petty_cash_app/pages/add_bill_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

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
  double? _openingBalance;
  String? _formattedStartDate;
  bool _isRefreshing = false;
  String? _activeReportingPeriod;
  bool _isLoadingReportingPeriod = false;

  @override
  void initState() {
    super.initState();
    _loadBills();
    _loadActiveReportingPeriod();
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<void> _loadActiveReportingPeriod() async {
    if (!mounted) return;
    setState(() {
      _isLoadingReportingPeriod = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    
    print('=== REPORTING PERIOD DEBUG START ===');
    print('Auth token exists: ${token.isNotEmpty}');
    print('Auth token (first 20 chars): ${token.length > 20 ? "${token.substring(0, 20)}..." : token}');
    
    if (token.isEmpty) {
      print('ERROR: No auth token found for reporting period.');
      if (mounted) {
        setState(() { 
          _activeReportingPeriod = 'No auth token';
          _openingBalance = null;
          _formattedStartDate = null;
          _isLoadingReportingPeriod = false; 
        });
      }
      print('=== REPORTING PERIOD DEBUG END ===');
      return;
    }

    // Check internet connection
    final hasInternet = await _hasInternetConnection();
    print('Internet connection available: $hasInternet');
    if (!hasInternet) {
      print('ERROR: No internet connection for reporting period.');
      if (mounted) {
        setState(() { 
          _activeReportingPeriod = 'No internet';
          _openingBalance = null;
          _formattedStartDate = null;
          _isLoadingReportingPeriod = false; 
        });
      }
      print('=== REPORTING PERIOD DEBUG END ===');
      return;
    }

    final url = Uri.parse('https://stage-cash.fesf-it.com/api/reporting-period');
    print('Making request to: $url');
    print('Request headers: Content-Type: application/json, Authorization: Bearer ${token.substring(0, 10)}...');
    
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: 10));

      print('=== API RESPONSE ===');
      print('Status Code: ${response.statusCode}');
      print('Response Headers: ${response.headers}');
      try {
        final prettyJson = JsonEncoder.withIndent('  ').convert(jsonDecode(response.body));
        print('Raw JSON Response:\n$prettyJson');
      } catch (e) {
        print('Raw Response (unformatted): ${response.body}');
      }
      print('Response Body Length: ${response.body.length}');

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          print('Parsed JSON data type: ${data.runtimeType}');
          
          if (data is Map<String, dynamic>) {
            final reportingPeriod = data['active_reporting_period'];
            print('Active reporting period value: $reportingPeriod');
            print('Active reporting period type: ${reportingPeriod.runtimeType}');
            
            if (reportingPeriod is Map<String, dynamic>) {
              print('Active reporting period is an object with fields:');
              reportingPeriod.forEach((key, value) {
                print('  $key: $value (type: ${value.runtimeType})');
              });
              String displayValue = reportingPeriod['name']?.toString() ?? 
                                  reportingPeriod['period']?.toString() ?? 
                                  reportingPeriod['title']?.toString() ?? 
                                  reportingPeriod.toString();
              double? openingBalance = reportingPeriod['pivot']?['opening_balance']?.toDouble();
              String? formattedStartDate;
              final startDate = reportingPeriod['start_date'];
              if (startDate != null) {
                try {
                  final dateFormat = DateFormat('dd-MMM-yy', 'en_US');
                  final parsedDate = dateFormat.parseLoose(startDate);
                  formattedStartDate = DateFormat('dd-MMM-yyyy', 'en_US').format(parsedDate);
                  print('Parsed start_date: $startDate to $formattedStartDate');
                } catch (e) {
                  print('ERROR: Failed to parse start_date ($startDate): $e');
                  formattedStartDate = null;
                }
              }
              print('Selected display value: $displayValue');
              print('Opening balance: $openingBalance');
              print('Formatted start date: $formattedStartDate');
              if (mounted) {
                setState(() {
                  _activeReportingPeriod = displayValue;
                  _openingBalance = openingBalance;
                  _formattedStartDate = formattedStartDate;
                  _isLoadingReportingPeriod = false;
                });
              }
            } else if (reportingPeriod is String) {
              print('Active reporting period is a string.');
              if (mounted) {
                setState(() {
                  _activeReportingPeriod = reportingPeriod;
                  _openingBalance = null;
                  _formattedStartDate = null;
                  _isLoadingReportingPeriod = false;
                });
              }
            } else if (reportingPeriod != null) {
              print('Active reporting period is neither object nor string, converting to string.');
              if (mounted) {
                setState(() {
                  _activeReportingPeriod = reportingPeriod.toString();
                  _openingBalance = null;
                  _formattedStartDate = null;
                  _isLoadingReportingPeriod = false;
                });
              }
            } else {
              print('ERROR: active_reporting_period is null.');
              if (mounted) {
                setState(() { 
                  _activeReportingPeriod = 'No active period found';
                  _openingBalance = null;
                  _formattedStartDate = null;
                  _isLoadingReportingPeriod = false; 
                });
              }
            }
          } else {
            print('ERROR: Response data is not a Map, it is: ${data.runtimeType}');
            if (mounted) {
              setState(() { 
                _activeReportingPeriod = 'Invalid response format';
                _openingBalance = null;
                _formattedStartDate = null;
                _isLoadingReportingPeriod = false; 
              });
            }
          }
        } catch (jsonError) {
          print('ERROR: JSON parsing failed: $jsonError');
          if (mounted) {
            setState(() { 
              _activeReportingPeriod = 'JSON parse error';
              _openingBalance = null;
              _formattedStartDate = null;
              _isLoadingReportingPeriod = false; 
            });
          }
        }
      } else {
        print('ERROR: HTTP ${response.statusCode} - ${response.reasonPhrase}');
        print('Error response body: ${response.body}');
        if (mounted) {
          setState(() { 
            _activeReportingPeriod = 'HTTP ${response.statusCode}';
            _openingBalance = null;
            _formattedStartDate = null;
            _isLoadingReportingPeriod = false; 
          });
        }
      }
    } catch (e) {
      print('ERROR: Exception during API call: $e');
      print('Exception type: ${e.runtimeType}');
      if (e is SocketException) {
        print('Socket Exception details: ${e.message}');
        print('OS Error: ${e.osError}');
      }
      if (mounted) {
        setState(() { 
          _activeReportingPeriod = 'Exception: ${e.toString()}';
          _openingBalance = null;
          _formattedStartDate = null;
          _isLoadingReportingPeriod = false; 
        });
      }
    }
    
    print('Final active reporting period set to: $_activeReportingPeriod');
    print('Final opening balance set to: $_openingBalance');
    print('Final formatted start date set to: $_formattedStartDate');
    print('=== REPORTING PERIOD DEBUG END ===');
  }

  Future<void> _loadBills() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final jsonString = prefs.getString('${widget.locationCode}_${widget.name.replaceAll(' ', '_')}_bills');
        if (jsonString != null) {
          setState(() {
            bills = List<Map<String, dynamic>>.from(json.decode(jsonString));
          });
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = '${widget.locationCode}_${widget.name.replaceAll(' ', '_')}_bills.json';
        final file = File('${directory.path}/$fileName');
        if (file.existsSync()) {
          final jsonString = await file.readAsString();
          setState(() {
            bills = List<Map<String, dynamic>>.from(json.decode(jsonString));
          });
        }
      }
    } catch (e) {
      print('Error loading bills: $e');
    }
  }

  Future<void> _saveBills() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('${widget.locationCode}_${widget.name.replaceAll(' ', '_')}_bills', json.encode(bills));
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = '${widget.locationCode}_${widget.name.replaceAll(' ', '_')}_bills.json';
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(json.encode(bills));
      }
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
        title: Text('Confirm Delete', style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 16.0), fontWeight: FontWeight.w500)),
        content: Text('Are you sure you want to delete this bill?', style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 14.0))),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancel', style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w500)),
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
            child: Text('Delete', style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w500)),
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

  Future<void> _refreshBalance() async {
    if (!mounted) return;
    setState(() {
      _isRefreshing = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    if (token.isEmpty) {
      print('No auth token found in shared_preferences.');
      if (mounted) setState(() { _isRefreshing = false; });
      return;
    }
    print('Using auth token: $token');
    print('Current balance before refresh: $_balance');

    final url = Uri.parse('https://stage-cash.fesf-it.com/api/balance');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      print('API response status: ${response.statusCode}');
      print('API response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final balance = (data['current_balance'] as num?)?.toDouble() ?? 0.0;
        if (mounted) {
          setState(() {
            _balance = balance;
            _isRefreshing = false;
          });
          print('Balance set to: $_balance after setState');
        }
      } else {
        print('Failed to refresh balance: ${response.statusCode} - ${response.body}');
        if (mounted) setState(() { _isRefreshing = false; });
      }
    } catch (e) {
      print('Error refreshing balance: $e');
      if (e is SocketException) {
        print('Network issue: Check internet connection or domain name: $url');
      }
      if (mounted) setState(() { _isRefreshing = false; });
    }
  }

  Future<void> _refreshData() async {
    await Future.wait([
      _refreshBalance(),
      _loadActiveReportingPeriod(),
    ]);
  }

  void _showBillDetails(Map<String, dynamic> bill) {
    final dateTime = DateTime.parse(bill['date']);
    final formattedDate = DateFormat('dd-MMM-yyyy', 'en_US').format(dateTime);
    final monthName = DateFormat('MMMM', 'en_US').format(dateTime);
    final financialPeriod = dateTime.day <= 15 ? '1st Half' : '2nd Half';
    final financialPeriodLabel = '$monthName-$financialPeriod';
    bool isAttached = bill['attached'] ?? false;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bill Details', style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 18.0), fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Date: $formattedDate', style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w500)),
              Text('Expense Head: ${bill['expenseHead'] ?? 'General'}', style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w400)),
              Text('Narration: ${bill['narration'] ?? ''}', style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w400)),
              Text('Amount: Rs. ${NumberFormat('#,###').format(bill['amount'].round())}', style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w500)),
              Text('Status: ${isAttached ? 'Uploaded' : 'Not Uploaded'} ($financialPeriodLabel)', style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w400)),
              if (bill['imagePath'] != null && !kIsWeb)
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
            child: Text('Close', style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('Rendering UI with balance: $_balance, opening balance: $_openingBalance');
    final sortedBills = List<Map<String, dynamic>>.from(bills)
      ..sort((a, b) => DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));
    final top10Bills = sortedBills.take(10).toList();
    final currentDateTime = DateFormat('dd-MMM-yyyy', 'en_US').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.name, style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 18.0), fontWeight: FontWeight.w600)),
                const SizedBox(height: 2.0),
                Text(widget.locationCode, style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 12.0), fontWeight: FontWeight.w400)),
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
              // Opening Balance Card
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
                          Text(
                            'Opening Balance',
                            style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w500),
                          ),
                          Text(
                            _formattedStartDate ?? 'N/A',
                            style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 10.0), fontWeight: FontWeight.w400, color: Colors.grey),
                          ),
                        ],
                      ),
                      Text(
                        _openingBalance != null ? 'Rs. ${NumberFormat('#,###').format(_openingBalance!.round())}' : 'N/A',
                        style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              // Current Balance Card
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
                          Text(
                            'Current Balance',
                            style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w500),
                          ),
                          Text(
                            currentDateTime,
                            style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 10.0), fontWeight: FontWeight.w400, color: Colors.grey),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (_isRefreshing)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.0),
                            )
                          else
                            Text(
                              'Rs. ${NumberFormat('#,###').format(_balance.round())}',
                              style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w500),
                            ),
                          const SizedBox(width: 8.0),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _refreshData,
                            iconSize: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Active Reporting Period Card
              Card(
                elevation: 2.0,
                margin: const EdgeInsets.only(bottom: 16.0),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Active Reporting Period', style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w500)),
                        ],
                      ),
                      Row(
                        children: [
                          if (_isLoadingReportingPeriod)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.0),
                            )
                          else
                            Container(
                              constraints: BoxConstraints(maxWidth: 200),
                              child: Text(
                                _activeReportingPeriod ?? 'Loading...',
                                style: GoogleFonts.montserrat(
                                  fontSize: getResponsiveFontSize(context, 14.0),
                                  fontWeight: FontWeight.w500,
                                  color: _activeReportingPeriod?.contains('Error') == true || 
                                         _activeReportingPeriod?.contains('Failed') == true ||
                                         _activeReportingPeriod?.contains('HTTP') == true ||
                                         _activeReportingPeriod?.contains('Exception') == true ||
                                         _activeReportingPeriod?.contains('No auth') == true ||
                                         _activeReportingPeriod?.contains('No internet') == true
                                      ? Colors.red
                                      : const Color.fromARGB(255, 7, 1, 17),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                                textAlign: TextAlign.end,
                              ),
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
                    final formattedDate = DateFormat('dd-MMM-yyyy', 'en_US').format(dateTime);
                    final monthName = DateFormat('MMMM', 'en_US').format(dateTime);
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
                                      Text('Date: $formattedDate', style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 12.0), fontWeight: FontWeight.w500)),
                                      Text('Exp: ${bill['expenseHead'] ?? 'General'}', style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 10.0), fontWeight: FontWeight.w400)),
                                      Text(
                                        bill['narration'] ?? '',
                                        style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 10.0), fontWeight: FontWeight.w400),
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
                                                style: GoogleFonts.montserrat(color: Colors.white, fontSize: getResponsiveFontSize(context, 10.0), fontWeight: FontWeight.w400),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '  ($financialPeriodLabel)',
                                            style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 8.0), fontWeight: FontWeight.w400),
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
                                    Text('Rs. ${NumberFormat('#,###').format(bill['amount'].round())}', style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 12.0), fontWeight: FontWeight.w500)),
                                    if (bill['imagePath'] != null && !kIsWeb)
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
                      child: Text('Add Bill', style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 18.0), fontWeight: FontWeight.w500)),
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
                      child: Text('Upload All', style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 18.0), fontWeight: FontWeight.w500)),
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