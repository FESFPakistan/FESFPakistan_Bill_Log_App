import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../pages/login_page.dart';
import '../pages/add_bill_page.dart';
import '../utils.dart';
import 'package:url_launcher/url_launcher.dart';

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
  String? _activeReportingPeriod;
  // ignore: unused_field
  String? _formattedStartDate;

  @override
  void initState() {
    super.initState();
    _loadBills();
    _refreshReportingPeriod();
    _refreshBalance();
  }

  Future<void> _loadBills() async {
    final loadedBills = await Utils.loadBills(widget.locationCode, widget.name);
    setState(() {
      bills = loadedBills;
    });
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
    setState(() {
      bills.add(newBill);
    });
    await _saveBills();
  }

  Future<bool?> _deleteBill(int index) async {
    return await Utils.showConfirmDialog(
      context,
      'Confirm Delete',
      'Are you sure you want to delete this bill?',
      () {
        setState(() {
          bills.removeAt(index);
        });
        _saveBills();
      },
    );
  }

  Future<void> _logout() async {
    await Utils.clearAuthPrefs();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  Future<void> _refreshBalance() async {
    setState(() => _isRefreshingBalance = true);
    final balance = await Utils.fetchBalance(context);
    if (mounted) {
      setState(() {
        _balance = balance;
        _isRefreshingBalance = false;
      });
    }
  }

  Future<void> _refreshReportingPeriod() async {
    setState(() => _isRefreshingPeriod = true);
    final result = await Utils.fetchReportingPeriod(context);
    if (mounted) {
      setState(() {
        _activeReportingPeriod = result['period'];
        _openingBalance = result['openingBalance'];
        _formattedStartDate = result['formattedStartDate'];
        _isRefreshingPeriod = false;
      });
    }
  }

  Future<void> _launchHelpUrl() async {
    final url = Uri.parse('https://fest-it.com/help/cash/app.html');
    try {
      await launchUrl(
        url,
        mode: LaunchMode.platformDefault, // Use default browser to maximize compatibility
      );
    } catch (e) {
      Utils.showSnackBar(context, 'Failed to open help page. Attempted to launch anyway.');
      print('Error launching help URL: $e');
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
                    : null,
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
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddBillPage()),
                        );
                        if (result != null) {
                          await _addBill(
                            result['narration'],
                            result['amount'],
                            result['expenseHead'],
                            result['date'],
                            result['imagePath'],
                          );
                        }
                      },
                      label: 'Add Bill',
                      context: context,
                      fontSize: 18.0,
                    ),
                    Utils.buildElevatedButton(
                      onPressed: () => Utils.showSnackBar(context, 'Upload All feature coming soon!'),
                      label: 'Upload All',
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