import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
// import 'main.dart';
import 'login_page.dart';
import 'add_bill_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class BillScreen extends StatefulWidget {
  final String name;
  final String locationCode;

  const BillScreen({
    Key? key,
    required this.name,
    required this.locationCode,
  }) : super(key: key);

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  List<Map<String, dynamic>> bills = [];
  double _balance = 0.0;
  DateTime? _balanceDateTime;
  bool _isRefreshing = false;

  String _reportingPeriod = 'Loading...';
  double? _openingBalance;

  bool _isLoadingOpeningBalance = false;
  bool _isLoadingReportingPeriodCard = false;

  @override
  void initState() {
    super.initState();
    _loadBills();
    _refreshBalance();
    _fetchReportingPeriod();
  }

  Future<void> _loadBills() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final jsonString = prefs.getString('${widget.locationCode}_${widget.name.replaceAll(' ', '_')}_bills');
        if (jsonString != null) {
          final decoded = json.decode(jsonString);
          if (decoded is List) {
            setState(() {
              bills = decoded.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
            });
          }
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = '${widget.locationCode}_${widget.name.replaceAll(' ', '_')}_bills.json';
        final file = File('${directory.path}/$fileName');
        if (await file.exists()) {
          final jsonString = await file.readAsString();
          final decoded = json.decode(jsonString);
          if (decoded is List) {
            setState(() {
              bills = decoded.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e)).toList();
            });
          }
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
        title: Text('Delete Bill', style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
        content: Text('Kya aap is bill ko delete karna chahte hain?', ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('Cancel', style: GoogleFonts.montserrat( fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                if (index >= 0 && index < bills.length) {
                  bills.removeAt(index);
                }
              });
              _saveBills();
              Navigator.of(context).pop();
              confirm = true;
            },
            child: Text('Delete', style: GoogleFonts.montserrat( fontWeight: FontWeight.w500)),
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

    if (!mounted) return;
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
      if (mounted) setState(() { _isRefreshing = false; });
      return;
    }

    final url = Uri.parse('https://stage-cash.fesf-it.com/api/get-balance');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final balance = (data['current_balance'] as num?)?.toDouble() ?? 0.0;
        final updatedAtStr = data['updated_at'] as String?;
        DateTime? balanceDateTime;
        if (updatedAtStr != null && updatedAtStr.isNotEmpty) {
          try {
            balanceDateTime = DateTime.tryParse(updatedAtStr);
            if (balanceDateTime == null) {
              try {
                balanceDateTime = DateFormat('d-M-y h:mm a').parseStrict(updatedAtStr);
              } catch (_) {
                try {
                  balanceDateTime = DateFormat('d-M-y h:m a').parseLoose(updatedAtStr);
                } catch (_) {
                  balanceDateTime = null;
                }
              }
            }
          } catch (_) {
            balanceDateTime = null;
          }
        }
        if (mounted) {
          setState(() {
            _balance = balance;
            _balanceDateTime = balanceDateTime;
            _isRefreshing = false;
          });
        }
      } else {
        if (mounted) setState(() { _isRefreshing = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _isRefreshing = false; });
    }
  }

  Future<void> _refreshData() async {
    await _refreshBalance();
  }

  Future<void> _refreshOpeningBalance() async {
    if (!mounted) return;
    setState(() {
      _isLoadingOpeningBalance = true;
    });
    await _fetchReportingPeriod();
    if (mounted) {
      setState(() {
        _isLoadingOpeningBalance = false;
      });
    }
  }

  Future<void> _refreshReportingPeriod() async {
    if (!mounted) return;
    setState(() {
      _isLoadingReportingPeriodCard = true;
    });
    await _fetchReportingPeriod();
    if (mounted) {
      setState(() {
        _isLoadingReportingPeriodCard = false;
      });
    }
  }

  Future<void> _fetchReportingPeriod() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    if (token.isEmpty) {
      if (mounted) {
        setState(() {
          _reportingPeriod = 'No auth token';
          _openingBalance = null;
        });
      }
      return;
    }

    final url = Uri.parse('https://stage-cash.fesf-it.com/api/get-reporting-period');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (mounted) {
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final periodData = data['active_reporting_period'];
          final periodName = periodData['name'] ?? 'Unknown Period';
          final periodDateStr = periodData['end_date'] ?? ''; // Assuming end_date is available
          DateTime? periodEndDate;
          if (periodDateStr.isNotEmpty) {
            try {
              periodEndDate = DateTime.tryParse(periodDateStr);
            } catch (_) {
              periodEndDate = null;
            }
          }
          final currentDate = DateTime.now();
          if (periodEndDate != null && periodEndDate.isBefore(currentDate)) {
            setState(() {
              _reportingPeriod = '$periodName (Outdated)';
            });
          } else {
            setState(() {
              _reportingPeriod = periodName;
            });
          }
          _openingBalance = (periodData['pivot']['opening_balance'] as num?)?.toDouble() ?? 0.0;
        } else {
          setState(() {
            _reportingPeriod = 'Failed to load: HTTP ${response.statusCode}';
            _openingBalance = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _reportingPeriod = 'Error: $e';
          _openingBalance = null;
        });
      }
    }
  }

  void _showBillDetails(Map<String, dynamic> bill) {
    DateTime? dateTime;
    try {
      dateTime = DateTime.parse(bill['date']);
    } catch (_) {
      dateTime = null;
    }
    final formattedDate = dateTime != null
        ? DateFormat('dd-MMM-yyyy', 'en_US').format(dateTime)
        : 'Invalid date';
    final monthName = dateTime != null
        ? DateFormat('MMMM', 'en_US').format(dateTime)
        : '';
    final financialPeriod = (dateTime != null && dateTime.day <= 15) ? '1st Half' : '2nd Half';
    final financialPeriodLabel = '$monthName-$financialPeriod';
    bool isAttached = bill['attached'] ?? false;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bill Details', style: GoogleFonts.montserrat( fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Date: $formattedDate', style: GoogleFonts.montserrat( fontWeight: FontWeight.w500)),
              Text('Expense Head: ${bill['expenseHead']}', style: GoogleFonts.montserrat( fontWeight: FontWeight.w400)),
              Text('Narration: ${bill['narration'] ?? ''}', style: GoogleFonts.montserrat(  fontWeight: FontWeight.w400)),
              Text('Amount: Rs. ${NumberFormat('#,###').format((bill['amount'] as num).round())}', style: GoogleFonts.montserrat(  fontWeight: FontWeight.w500)),
              Text('Status: ${isAttached ? 'Uploaded' : 'Not Uploaded'} ($financialPeriodLabel)', style: GoogleFonts.montserrat(  fontWeight: FontWeight.w400)),
              if (bill['imagePath'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: kIsWeb
                      ? Image.network(
                          bill['imagePath'],
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 200,
                              color: Colors.grey[300],
                              child: const Center(
                                child: Icon(Icons.image, color: Colors.grey, size: 50),
                              ),
                            );
                          },
                        )
                      : Image.file(
                          File(bill['imagePath']),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 200,
                              color: Colors.grey[300],
                              child: const Center(
                                child: Icon(Icons.image, color: Colors.grey, size: 50),
                              ),
                            );
                          },
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
            child: Text('Close', style: GoogleFonts.montserrat( fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedBills = List<Map<String, dynamic>>.from(bills)
      ..sort((a, b) {
        try {
          return DateTime.parse(b['date']).compareTo(DateTime.parse(a['date']));
        } catch (_) {
          return 0;
        }
      });
    final top10Bills = sortedBills.take(10).toList();
    final currentDateTime = DateFormat('dd-MMM-yyyy', 'en_US').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.name, style: GoogleFonts.montserrat( fontWeight: FontWeight.w600)),
                const SizedBox(height: 2.0),
                Text(widget.locationCode, style: GoogleFonts.montserrat( fontWeight: FontWeight.w400)),
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
                            style: GoogleFonts.montserrat(
                                
                                fontWeight: FontWeight.w500),
                          ),
                          Text(
                            _balanceDateTime != null
                                ? 'Updated: ${DateFormat('dd-MMM-yyyy, hh:mm a').format(_balanceDateTime!)}'
                                : currentDateTime,
                            style: const TextStyle(
                                fontWeight: FontWeight.w400, color: Colors.grey),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _isRefreshing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2.0),
                                )
                              : Text(
                                  'Rs. ${NumberFormat('#,###').format(_balance.round())}',
                                  style: GoogleFonts.montserrat(
                                    
                                    fontWeight: FontWeight.w500,
                                  ),
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
                            style: GoogleFonts.montserrat(
                                
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          if (_isLoadingOpeningBalance)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.0),
                            )
                          else
                            Text(
                              _openingBalance != null
                                  ? 'Rs. ${NumberFormat('#,###').format(_openingBalance!.round())}'
                                  : 'N/A',
                              style: GoogleFonts.montserrat(
                                  
                                  fontWeight: FontWeight.w500),
                            ),
                          const SizedBox(width: 8.0),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _refreshOpeningBalance,
                            iconSize: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Reporting Period Card
              Card(
                elevation: 2.0,
                margin: const EdgeInsets.only(bottom: 16.0),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reporting Period',
                            style: GoogleFonts.montserrat(
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      SizedBox(width: 1,),
                      Row(
                        children: [
                          if (_isLoadingReportingPeriodCard)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.0),
                            )
                          else
                            Container(
                              constraints: const BoxConstraints(maxWidth: 200),
                              child: Text(
                                _reportingPeriod,
                                style: GoogleFonts.montserrat(
                                  
                                  fontWeight: FontWeight.w500,
                                  color: _reportingPeriod.contains('Error') ||
                                          _reportingPeriod.contains('Failed') ||
                                          _reportingPeriod.contains('HTTP') ||
                                          _reportingPeriod.contains('Exception') ||
                                          _reportingPeriod.contains('No auth') ||
                                          _reportingPeriod.contains('No internet') ||
                                          _reportingPeriod.contains('Outdated')
                                      ? Colors.red
                                      : const Color.fromARGB(255, 7, 1, 17),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                                textAlign: TextAlign.end,
                              ),
                            ),
                          // const SizedBox(width: 8.0),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _refreshReportingPeriod,
                            iconSize: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Bills List
              Expanded(
                child: ListView.builder(
                  itemCount: top10Bills.length,
                  itemBuilder: (context, index) {
                    final bill = top10Bills[index];
                    DateTime? dateTime;
                    try {
                      dateTime = DateTime.parse(bill['date']);
                    } catch (_) {
                      dateTime = null;
                    }
                    final formattedDate = dateTime != null
                        ? DateFormat('dd-MMM-yyyy', 'en_US').format(dateTime)
                        : 'Invalid date';
                    final monthName = dateTime != null
                        ? DateFormat('MMMM', 'en_US').format(dateTime)
                        : '';
                    final financialPeriod = (dateTime != null && dateTime.day <= 15) ? '1st Half' : '2nd Half';
                    final financialPeriodLabel = '$monthName-$financialPeriod';
                    bool isAttached = bill['attached'] ?? false;

                    return Dismissible(
                      key: Key(bill['date'].toString() + (bill['narration'] ?? '')),
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
                                      Text('Date: $formattedDate', style: GoogleFonts.montserrat( fontWeight: FontWeight.w500)),
                                      Text('Exp: ${bill['expenseHead']}', style: GoogleFonts.montserrat( fontWeight: FontWeight.w400)),
                                      Text(
                                        bill['narration'] ?? '',
                                        style: GoogleFonts.montserrat( fontWeight: FontWeight.w400),
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
                                                style: GoogleFonts.montserrat(color: Colors.white,  fontWeight: FontWeight.w400),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            '  ($financialPeriodLabel)',
                                            style: GoogleFonts.montserrat( fontWeight: FontWeight.w400),
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
                                    Text('Rs. ${NumberFormat('#,###').format((bill['amount'] as num).round())}', style: GoogleFonts.montserrat( fontWeight: FontWeight.w500)),
                                    if (bill['imagePath'] != null)
                                      GestureDetector(
                                        onDoubleTap: () {
                                          _showBillDetails(bill);
                                        },
                                        child: kIsWeb
                                            ? Image.network(
                                                bill['imagePath'],
                                                height: 60,
                                                width: 60,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(
                                                    height: 60,
                                                    width: 60,
                                                    color: Colors.grey[300],
                                                    child: const Icon(Icons.image, color: Colors.grey),
                                                  );
                                                },
                                              )
                                            : Image.file(
                                                File(bill['imagePath']),
                                                height: 60,
                                                width: 60,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(
                                                    height: 60,
                                                    width: 60,
                                                    color: Colors.grey[300],
                                                    child: const Icon(Icons.image, color: Colors.grey),
                                                  );
                                                },
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
                        if (result != null && result is Map<String, dynamic>) {
                          final narration = result['narration'] as String;
                          final amount = result['amount'] is double
                              ? result['amount'] as double
                              : (result['amount'] is int
                                  ? (result['amount'] as int).toDouble()
                                  : 0.0);
                          final expenseHead = result['expenseHead'] as String;
                          final date = result['date'] is DateTime
                              ? result['date'] as DateTime
                              : DateTime.now();
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
                      child: Text('Add Bill', style: GoogleFonts.montserrat( fontWeight: FontWeight.w500)),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        final token = prefs.getString('auth_token') ?? '';
                        if (token.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No auth token available')),
                          );
                          return;
                        }
                        for (var bill in bills) {
                          if (!(bill['attached'] ?? false)) {
                            final url = Uri.parse('https://stage-cash.fesf-it.com/api/upload-bill');
                            try {
                              final response = await http.post(
                                url,
                                headers: {
                                  'Content-Type': 'application/json',
                                  'Authorization': 'Bearer $token',
                                },
                                body: jsonEncode({
                                  'narration': bill['narration'],
                                  'amount': bill['amount'],
                                  'expenseHead': bill['expenseHead'],
                                  'date': bill['date'],
                                  'imagePath': bill['imagePath'],
                                }),
                              );
                              if (response.statusCode == 200) {
                                setState(() {
                                  bill['attached'] = true;
                                });
                                await _saveBills();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to upload bill: HTTP ${response.statusCode}')),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error uploading bill: $e')),
                              );
                            }
                          }
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('All bills uploaded successfully')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(150, 40),
                        elevation: 0,
                      ),
                      child: Text('Upload All', style: GoogleFonts.montserrat( fontWeight: FontWeight.w500)),
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