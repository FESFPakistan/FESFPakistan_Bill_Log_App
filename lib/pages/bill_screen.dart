import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../utils.dart';
import 'add_bill_page.dart';
import 'login_page.dart';

class BillScreen extends StatefulWidget {
  final String name;
  final String locationCode;

  const BillScreen({super.key, required this.name, required this.locationCode});

  @override
  _BillScreenState createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  List<Map<String, dynamic>> bills = [];
  double? _balance;
  double? _openingBalance;
  bool _isRefreshingBalance = false;
  bool _isRefreshingPeriod = false;
  bool _isUploading = false;
  String? _activeReportingPeriod;

  @override
  void initState() {
    super.initState();
    _loadBills();
    _refreshReportingPeriod();
    _refreshBalance();
  }

  Future<void> _loadBills() async {
    final loadedBills = await Utils.loadBills(widget.locationCode, widget.name);
    if (mounted) {
      setState(() {
        bills = loadedBills;
      });
    }
  }

  Future<void> _saveBills() async {
    await Utils.saveBills(bills, widget.locationCode, widget.name);
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
    if (mounted) {
      setState(() {
        bills.add(newBill);
      });
    }
    await _saveBills();
  }

  Future<bool?> _deleteBill(int index) async {
    return await Utils.showConfirmDialog(
      context,
      'Confirm Delete',
      'Are you sure you want to delete this bill?',
      () {
        if (mounted) {
          setState(() {
            bills.removeAt(index);
          });
        }
        _saveBills();
      },
    );
  }

  Future<void> _logout() async {
    await Utils.clearAuthPrefs();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  Future<void> _refreshBalance() async {
    if (mounted) setState(() => _isRefreshingBalance = true);
    final balance = await Utils.fetchBalance(context);
    if (mounted) {
      setState(() {
        _balance = balance ?? 0.0;
        _isRefreshingBalance = false;
      });
    }
  }

  Future<void> _refreshReportingPeriod() async {
    if (mounted) setState(() => _isRefreshingPeriod = true);
    final result = await Utils.fetchReportingPeriod(context);
    await Utils.loadExpenseHeads(context); // Update expense heads cache
    if (mounted) {
      setState(() {
        _activeReportingPeriod = result['period'] ?? 'Current Semi-Month';
        _openingBalance = result['openingBalance'] ?? 0.0;
        _isRefreshingPeriod = false;
      });
    }
  }

  Future<void> _launchHelpUrl() async {
    final url = Uri.parse('https://fest-it.com/help/cash/app.html');
    try {
      await launchUrl(
        url,
        mode: LaunchMode.platformDefault,
      );
    } catch (e) {
      Utils.showSnackBar(context, 'Failed to open help page: $e');
    }
  }

  void _handleAddBill() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddBillPage()),
    ).then((result) async {
      if (result != null && mounted) {
        await _addBill(
          result['narration'],
          result['amount'],
          result['expenseHead'],
          result['date'],
          result['imagePath'],
        );
      }
    });
  }

  Future<bool> _preUploadChecks(List<Map<String, dynamic>> nonUploadedBills) async {
    if (bills.isEmpty) {
      Utils.showSnackBar(context, 'No bills to upload');
      return false;
    }

    if (nonUploadedBills.isEmpty) {
      Utils.showSnackBar(context, 'All bills are already uploaded');
      return false;
    }

    if (!await Utils.hasInternetConnection()) {
      Utils.showSnackBar(context, 'No internet connection. Please try again later.');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    if (token.isEmpty) {
      Utils.showSnackBar(context, 'No authentication token found. Please log in again.');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
      return false;
    }

    return true;
  }

  void _showUploadDialog(int numBills) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Uploading $numBills bill(s)...',
              style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUploadResults(int successfulUploads, int failedUploads) async {
    await _saveBills();

    if (mounted) {
      setState(() => _isUploading = false);
    }
    Navigator.of(context).pop(); // Close dialog

    if (successfulUploads > 0) {
      Utils.showSnackBar(context, 'Successfully uploaded $successfulUploads bill(s)');
    }
    if (failedUploads > 0) {
      Utils.showSnackBar(context, '$failedUploads bill(s) failed to upload');
    }
  }

  Future<void> _uploadAllBills() async {
    final nonUploadedBills = bills.where((bill) => bill['attached'] != true).toList();

    final canUpload = await _preUploadChecks(nonUploadedBills);
    if (!canUpload) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    if (mounted) {
      setState(() => _isUploading = true);
    }
    _showUploadDialog(nonUploadedBills.length);

    int successfulUploads = 0;
    int failedUploads = 0;
    const int maxRetries = 2;

    bool batchSuccess = await _tryBatchUpload(nonUploadedBills, token);
    if (batchSuccess) {
      if (mounted) {
        setState(() {
          for (var bill in nonUploadedBills) {
            bill['attached'] = true;
          }
        });
      }
      successfulUploads = nonUploadedBills.length;
    } else {
      for (var bill in nonUploadedBills) {
      
        for (int i = 1; i <= maxRetries; i++) {
          try {
            final result = await _uploadSingleBill(bill, token, i);
            if (result['success']) {
              if (mounted) {
                setState(() {
                  bill['attached'] = true;
                });
              }
              successfulUploads++;
              break;
            } else if (result['statusCode'] == 401) {
              Utils.showSnackBar(context, 'Authentication failed. Please log in again.');
              await Utils.clearAuthPrefs();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              }
              if (mounted) setState(() => _isUploading = false);
              Navigator.of(context).pop(); // Close dialog
              return;
            }
          } catch (e) {
            if (i == maxRetries) {
              failedUploads++;
              Utils.showSnackBar(context, 'Failed to upload bill "${bill['narration']}" after $maxRetries attempts');
            } else {
              await Future.delayed(Duration(milliseconds: 500 * i));
            }
          }
        }
      }
    }

    _handleUploadResults(successfulUploads, failedUploads);
  }

  Future<bool> _tryBatchUpload(List<Map<String, dynamic>> bills, String token) async {
    try {
      final url = Uri.parse('https://stage-cash.fesf-it.com/api/bills/batch');
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Content-Type'] = 'multipart/form-data';

      for (int i = 0; i < bills.length; i++) {
        final bill = bills[i];
        request.fields['bills[$i][narration]'] = bill['narration'] ?? '';
        request.fields['bills[$i][amount]'] = bill['amount'].toString();
        request.fields['bills[$i][expense_head]'] = bill['expenseHead'] ?? 'General';
        request.fields['bills[$i][date]'] = bill['date'];
        if (bill['imagePath'] != null) {
          final file = File(bill['imagePath']);
          if (file.existsSync()) {
            request.files.add(await http.MultipartFile.fromPath('bills[$i][image]', file.path));
          } else {
            return false;
          }
        }
      }

      final response = await request.send().timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> _uploadSingleBill(Map<String, dynamic> bill, String token, int attempt) async {
    try {
      final url = Uri.parse('https://stage-cash.fesf-it.com/api/bills');
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Content-Type'] = 'multipart/form-data';

      request.fields['narration'] = bill['narration'] ?? '';
      request.fields['amount'] = bill['amount'].toString();
      if (bill['expenseHead'] != null && bill['expenseHead'].isNotEmpty) {
        request.fields['expense_head'] = bill['expenseHead'];
      }
      request.fields['date'] = bill['date'];

      if (bill['imagePath'] != null) {
        final file = File(bill['imagePath']);
        if (file.existsSync()) {
          request.files.add(await http.MultipartFile.fromPath('image', file.path));
        } else {
          return {'success': false, 'statusCode': 0, 'message': 'Image file not found'};
        }
      }

      final response = await request.send().timeout(const Duration(seconds: 10));
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true};
      } else {
        return {'success': false, 'statusCode': response.statusCode, 'message': responseBody};
      }
    } catch (e) {
      throw Exception('Attempt $attempt failed for bill "${bill['narration']}": $e');
    }
  }

  void _showBillDetails(Map<String, dynamic> bill) {
    Utils.showBillDetails(context, bill);
  }

  @override
  Widget build(BuildContext context) {
    final top10Bills = bills.length > 10 ? bills.sublist(0, 10) : bills;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.name,
                style: GoogleFonts.montserrat(
                    fontSize: Utils.getResponsiveFontSize(context, 18.0),
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2.0),
            Text(widget.locationCode,
                style: GoogleFonts.montserrat(
                    fontSize: Utils.getResponsiveFontSize(context, 12.0),
                    fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _launchHelpUrl,
            tooltip: 'Help',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
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
              Utils.buildBalanceCard(
                context,
                'Current Balance',
                Utils.currentDateTime,
                _balance != null
                    ? 'Rs. ${NumberFormat('#,###').format(_balance!.round())}'
                    : 'N/A',
                isRefreshing: _isRefreshingBalance,
                onRefresh: _refreshBalance,
              ),
              Utils.buildBalanceAndPeriodCard(
                context,
                _activeReportingPeriod ?? 'N/A',
                _isRefreshingPeriod,
                _openingBalance != null
                    ? 'Rs. ${NumberFormat('#,###').format(_openingBalance!.round())}'
                    : 'N/A',
                onRefresh: _refreshReportingPeriod,
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: top10Bills.length,
                  itemBuilder: (context, index) {
                    final bill = top10Bills[index];
                    return Utils.buildBillCard(
                      context,
                      bill,
                      bills.indexOf(bill),
                      _deleteBill,
                      _showBillDetails,
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Utils.buildElevatedButton(
                      onPressed: _isUploading ? null : _handleAddBill,
                      label: 'Add Bill',
                      context: context,
                      fontSize: 18.0,
                    ),
                    Utils.buildElevatedButton(
                      onPressed: _isUploading ? null : _uploadAllBills,
                      label: _isUploading ? 'Uploading...' : 'Upload All',
                      context: context,
                      fontSize: 18.0,
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