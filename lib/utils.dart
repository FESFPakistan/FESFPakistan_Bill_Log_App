import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'pages/login_page.dart';

class Utils {
  static double getResponsiveFontSize(BuildContext context, double baseFontSize) {
    final mediaQuery = MediaQuery.of(context);
    final scaler = mediaQuery.textScaler;
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    const double smallPhoneWidth = 320.0;
    const double mediumPhoneWidth = 375.0;
    const double largePhoneWidth = 414.0;
    const double tabletWidth = 600.0;

    double referenceWidth = screenWidth < 360.0
        ? smallPhoneWidth
        : screenWidth < 414.0
            ? mediumPhoneWidth
            : screenWidth < 600.0
                ? largePhoneWidth
                : tabletWidth;

    final aspectRatio = screenHeight > 0 ? screenWidth / screenHeight : 0.5625;
    final aspectRatioAdjustment = (aspectRatio / 0.5625).clamp(0.9, 1.1);
    final widthScalingFactor = referenceWidth > 0 ? screenWidth / referenceWidth : 1.0;

    return (baseFontSize * scaler.scale(1.0) * widthScalingFactor * aspectRatioAdjustment)
        .clamp(baseFontSize * 0.85, baseFontSize * 1.3);
  }

  static InputDecoration inputDecoration(BuildContext context, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.montserrat(
        fontSize: getResponsiveFontSize(context, 14.0),
        fontWeight: FontWeight.w400,
      ),
    );
  }

  static Widget buildTextFormField({
    required TextEditingController controller,
    required String label,
    required BuildContext context,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: inputDecoration(context, label),
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
    );
  }

  static Widget buildElevatedButton({
    required VoidCallback? onPressed,
    required String label,
    required BuildContext context,
    double fontSize = 14.0,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        minimumSize: const Size(150, 40),
        elevation: 0,
      ),
      child: Text(
        label,
        style: GoogleFonts.montserrat(
          fontSize: getResponsiveFontSize(context, fontSize),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static void showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(fontSize: getResponsiveFontSize(context, 14.0)),
        ),
      ),
    );
  }

  static Future<bool> hasInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return false;
    }
    try {
      final result = await InternetAddress.lookup('8.8.8.8').timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> loadExpenseHeads(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final cachedExpenseHeads = prefs.getString('expense_heads');
    List<Map<String, dynamic>> expenseHeads = [
      {'id': 0, 'name': 'General', 'code': 'GENERAL'}
    ];
    String selectedHead = 'General';

    if (cachedExpenseHeads != null) {
      try {
        expenseHeads = List<Map<String, dynamic>>.from(jsonDecode(cachedExpenseHeads));
        selectedHead = expenseHeads.isNotEmpty ? expenseHeads[0]['name'] : 'General';
      } catch (e) {
        showSnackBar(context, 'Error reading cached expense heads. Using default.');
      }
    }

    if (await hasInternetConnection()) {
      final url = Uri.parse("https://stage-cash.fesf-it.com/api/expense-heads");
      final token = prefs.getString('auth_token') ?? '';
      if (token.isEmpty) {
        showSnackBar(context, 'No authentication token found. Please log in again.');
        return {'expenseHeads': expenseHeads, 'selectedHead': selectedHead};
      }

      try {
        final response = await http.get(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          expenseHeads = List<Map<String, dynamic>>.from(jsonDecode(response.body))
              .map((item) => {'id': item['id'], 'name': item['name'], 'code': item['code']})
              .toList();
          if (!expenseHeads.any((head) => head['name'] == 'General')) {
            expenseHeads.insert(0, {'id': 0, 'name': 'General', 'code': 'GENERAL'});
          }
          selectedHead = expenseHeads.isNotEmpty ? expenseHeads[0]['name'] : 'General';
          await prefs.setString('expense_heads', jsonEncode(expenseHeads));
        } else if (response.statusCode == 401) {
          showSnackBar(context, 'Authentication failed. Please log in again.');
          await clearAuthPrefs();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        } else {
          showSnackBar(context, 'Failed to load expense heads: HTTP ${response.statusCode}');
        }
      } catch (e) {
        showSnackBar(context, 'Error loading expense heads: $e');
      }
    } else if (cachedExpenseHeads == null) {
      showSnackBar(context, 'No internet connection. Using default expense head.');
    }

    return {'expenseHeads': expenseHeads, 'selectedHead': selectedHead};
  }

  static Future<CroppedFile?> pickAndCropImage(BuildContext context) async {
    final picker = ImagePicker();
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(
            'Select Image Source',
            style: GoogleFonts.montserrat(
                fontSize: getResponsiveFontSize(context, 16.0), fontWeight: FontWeight.w500),
          ),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              child: Text(
                'Gallery',
                style: GoogleFonts.montserrat(
                    fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w400),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              child: Text(
                'Camera',
                style: GoogleFonts.montserrat(
                    fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w400),
              ),
            ),
          ],
        );
      },
    );

    if (source != null) {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        return await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
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
          ],
        );
      }
    }
    return null;
  }

  static Future<DateTime?> selectDate(
      BuildContext context, DateTime initialDate, DateTime firstDate, DateTime lastDate) async {
    return await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: Colors.deepPurple,
            colorScheme: const ColorScheme.light(primary: Colors.deepPurple),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
            textTheme: TextTheme(
              bodyLarge: TextStyle(fontSize: getResponsiveFontSize(context, 14.0)),
            ),
          ),
          child: child!,
        );
      },
    );
  }

  static Future<List<Map<String, dynamic>>> loadBills(String locationCode, String name) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${locationCode}_${name.replaceAll(' ', '_')}_bills.json';
      final file = File('${directory.path}/$fileName');
      if (file.existsSync()) {
        final jsonString = await file.readAsString();
        return List<Map<String, dynamic>>.from(json.decode(jsonString));
      }
    } catch (e) {
      // Handle error silently or log
    }
    return [];
  }

  static Future<void> saveBills(List<Map<String, dynamic>> bills, String locationCode, String name) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = '${locationCode}_${name.replaceAll(' ', '_')}_bills.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(json.encode(bills));
    } catch (e) {
      // Handle error silently or log
    }
  }

  static Future<bool?> showConfirmDialog(
      BuildContext context, String title, String content, VoidCallback onConfirm) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title,
            style: GoogleFonts.montserrat(
                fontSize: getResponsiveFontSize(context, 16.0), fontWeight: FontWeight.w500)),
        content: Text(content,
            style: GoogleFonts.montserrat(fontSize: getResponsiveFontSize(context, 14.0))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel',
                style: GoogleFonts.montserrat(
                    fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () {
              onConfirm();
              Navigator.of(context).pop(true);
            },
            child: Text('Delete',
                style: GoogleFonts.montserrat(
                    fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  static Future<void> clearAuthPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('name');
    await prefs.remove('locationCode');
    await prefs.remove('user_id');
    await prefs.remove('email');
    await prefs.remove('location_id');
    await prefs.remove('location_name');
  }

  static Future<double?> fetchBalance(BuildContext context) async {
    if (!await hasInternetConnection()) {
      showSnackBar(context, 'No internet connection. Cannot fetch balance.');
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    if (token.isEmpty) {
      showSnackBar(context, 'No authentication token found. Please log in again.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
      return null;
    }

    final url = Uri.parse('https://stage-cash.fesf-it.com/api/balance');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return double.tryParse(jsonDecode(response.body)['balance'].toString()) ?? 0.0;
      } else if (response.statusCode == 401) {
        showSnackBar(context, 'Authentication failed. Please log in again.');
        await clearAuthPrefs();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      } else {
        showSnackBar(context, 'Failed to fetch balance: HTTP ${response.statusCode}');
      }
    } catch (e) {
      showSnackBar(context, 'Error fetching balance: $e');
    }
    return null;
  }

  static Map<String, dynamic> getSemiMonthlyPeriod() {
    final now = DateTime.now();
    late DateTime startDate, endDate;
    if (now.day <= 15) {
      startDate = DateTime(now.year, now.month, 1);
      endDate = DateTime(now.year, now.month, 15);
    } else {
      startDate = DateTime(now.year, now.month, 16);
      endDate = DateTime(now.year, now.month + 1, 0);
    }
    final dateFormat = DateFormat('dd-MMM-yy');
    return {
      'period': '${dateFormat.format(startDate)} to ${dateFormat.format(endDate)}',
      'start_date': dateFormat.format(startDate),
      'end_date': dateFormat.format(endDate),
      'openingBalance': 0.0,
    };
  }

  static Future<Map<String, dynamic>> fetchReportingPeriod(BuildContext context) async {
    if (!await hasInternetConnection()) {
      showSnackBar(context, 'No internet connection. Using default semi-monthly period.');
      return getSemiMonthlyPeriod();
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    if (token.isEmpty) {
      showSnackBar(context, 'No authentication token found. Please log in again.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
      return getSemiMonthlyPeriod();
    }

    final url = Uri.parse('https://stage-cash.fesf-it.com/api/reporting-period');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'period': '${data['start_date']} to ${data['end_date']}',
          'start_date': data['start_date'],
          'end_date': data['end_date'],
          'openingBalance': double.tryParse(data['opening_balance'].toString()) ?? 0.0,
        };
      } else if (response.statusCode == 401) {
        showSnackBar(context, 'Authentication failed. Please log in again.');
        await clearAuthPrefs();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      } else {
        showSnackBar(context, 'Failed to fetch reporting period: HTTP ${response.statusCode}');
      }
    } catch (e) {
      showSnackBar(context, 'Error fetching reporting period: $e');
    }
    return getSemiMonthlyPeriod();
  }

  static void showBillDetails(BuildContext context, Map<String, dynamic> bill) {
    final dateTime = DateTime.parse(bill['date']);
    final formattedDate = DateFormat('dd-MMM-yyyy', 'en_US').format(dateTime);
    final monthName = DateFormat('MMMM', 'en_US').format(dateTime);
    final financialPeriod = dateTime.day <= 15 ? '1st Half' : '2nd Half';
    final financialPeriodLabel = '$monthName-$financialPeriod';
    bool isAttached = bill['attached'] ?? false;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          bill['narration'] ?? '',
          style: GoogleFonts.montserrat(
              fontSize: getResponsiveFontSize(context, 16.0), fontWeight: FontWeight.w500),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date: $formattedDate',
                  style: GoogleFonts.montserrat(
                      fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w500)),
              Text('Expense Head: ${bill['expenseHead'] ?? 'General'}',
                  style: GoogleFonts.montserrat(
                      fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w500)),
              Text('Amount: Rs. ${NumberFormat('#,###').format(bill['amount'].round())}',
                  style: GoogleFonts.montserrat(
                      fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w500)),
              Text('Period: $financialPeriodLabel',
                  style: GoogleFonts.montserrat(
                      fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w500)),
              Text('Status: ${isAttached ? 'Uploaded' : 'Not Uploaded'}',
                  style: GoogleFonts.montserrat(
                      fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w500)),
              if (bill['imagePath'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Image.file(File(bill['imagePath']), height: 100),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close',
                style: GoogleFonts.montserrat(
                    fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  static Widget buildBalanceCard(
      BuildContext context, String title, String subtitle, String? value,
      {bool isRefreshing = false, VoidCallback? onRefresh}) {
    return Card(
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
                  title,
                  style: GoogleFonts.montserrat(
                      fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w500),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.montserrat(
                      fontSize: getResponsiveFontSize(context, 10.0),
                      fontWeight: FontWeight.w400,
                      color: Colors.grey),
                ),
              ],
            ),
            Row(
              children: [
                if (isRefreshing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.0),
                  )
                else
                  Text(
                    value ?? 'N/A',
                    style: GoogleFonts.montserrat(
                        fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w500),
                  ),
                if (onRefresh != null) ...[
                  const SizedBox(width: 8.0),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: onRefresh,
                    iconSize: 18,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildBalanceAndPeriodCard(
      BuildContext context, String period, bool isLoading, String? openingBalance,
      {VoidCallback? onRefresh}) {
    return Card(
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
                  'Opening Balance',
                  style: GoogleFonts.montserrat(
                      fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4.0),
                Text(
                  'Financial Period',
                  style: GoogleFonts.montserrat(
                      fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w500),
                ),
              ],
            ),
            Row(
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.0),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        openingBalance ?? 'N/A',
                        style: GoogleFonts.montserrat(
                            fontSize: getResponsiveFontSize(context, 14.0), fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4.0),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Text(
                          period,
                          style: GoogleFonts.montserrat(
                            fontSize: getResponsiveFontSize(context, 14.0),
                            fontWeight: FontWeight.w500,
                            color: period.contains('Error') ||
                                    period.contains('Failed') ||
                                    period.contains('HTTP') ||
                                    period.contains('Exception') ||
                                    period.contains('No auth') ||
                                    period.contains('No internet')
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
                if (onRefresh != null) ...[
                  const SizedBox(width: 8.0),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: onRefresh,
                    iconSize: 18,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildBillCard(
      BuildContext context,
      Map<String, dynamic> bill,
      int index,
      Future<bool?> Function(int) onDelete,
      void Function(Map<String, dynamic>) onShowDetails) {
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
      confirmDismiss: (direction) async => await onDelete(index),
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
                      Text('Date: $formattedDate',
                          style: GoogleFonts.montserrat(
                              fontSize: getResponsiveFontSize(context, 12.0),
                              fontWeight: FontWeight.w500)),
                      Text('Exp: ${bill['expenseHead'] ?? 'General'}',
                          style: GoogleFonts.montserrat(
                              fontSize: getResponsiveFontSize(context, 10.0),
                              fontWeight: FontWeight.w400)),
                      Text(
                        bill['narration'] ?? '',
                        style: GoogleFonts.montserrat(
                            fontSize: getResponsiveFontSize(context, 10.0),
                            fontWeight: FontWeight.w400),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onLongPress: () {
                              isAttached = !isAttached;
                              bill['attached'] = isAttached;
                            },
                            child: Container(
                              color: isAttached ? Colors.green : Colors.red,
                              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                              child: Text(
                                isAttached ? 'Uploaded' : 'Not Uploaded',
                                style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                    fontSize: getResponsiveFontSize(context, 10.0),
                                    fontWeight: FontWeight.w400),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          Text(
                            '  ($financialPeriodLabel)',
                            style: GoogleFonts.montserrat(
                                fontSize: getResponsiveFontSize(context, 8.0),
                                fontWeight: FontWeight.w400),
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
                    Text('Rs. ${NumberFormat('#,###').format(bill['amount'].round())}',
                        style: GoogleFonts.montserrat(
                            fontSize: getResponsiveFontSize(context, 12.0),
                            fontWeight: FontWeight.w500)),
                    if (bill['imagePath'] != null)
                      GestureDetector(
                        onDoubleTap: () => onShowDetails(bill),
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
  }

  static String get currentDateTime =>
      DateFormat('dd-MMM-yyyy', 'en_US').format(DateTime.now());
}