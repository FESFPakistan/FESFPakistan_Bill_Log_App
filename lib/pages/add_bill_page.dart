import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

double getResponsiveFontSize(BuildContext context, double baseSize) {
  double width = MediaQuery.of(context).size.width;
  if (width < 360) return baseSize * 0.85;
  if (width > 600) return baseSize * 1.1;
  return baseSize;
}

// List of allowed expense head names (for filtering)
const List<String> allowedExpenseHeadNames = [
  'Travel',
  'Food',
  'Stationery',
  'Miscellaneous',
  // Add or remove as needed to "small" the list
];

class AddBillPage extends StatefulWidget {
  const AddBillPage({Key? key}) : super(key: key);

  @override
  State<AddBillPage> createState() => _AddBillPageState();
}

class _AddBillPageState extends State<AddBillPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _narrationController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String? _expenseHead;
  DateTime _selectedDate = DateTime.now();
  String? _imagePath;
  XFile? _pickedXFile;
  List<Map<String, dynamic>> _expenseHeads = [];

  @override
  void initState() {
    super.initState();
    _loadExpenseHeads();
    // Remove yellow error box
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Container(
        color: Colors.white,
        alignment: Alignment.center,
        child: Text(
          'Something went wrong!',
          style: TextStyle(
            color: Colors.red,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
      );
    };
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (_) {
      return false;
    }
  }

  bool _shouldFetchExpenseHeads() {
    final now = DateTime.now();
    return now.day == 1 || now.day == 16;
  }

  // Filter the expense heads to only allowed ones
  List<Map<String, dynamic>> _filterExpenseHeads(List<Map<String, dynamic>> heads) {
    return heads.where((head) {
      final name = head['name']?.toString() ?? '';
      return allowedExpenseHeadNames.contains(name);
    }).toList();
  }

  Future<void> _loadExpenseHeads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedExpenseHeads = prefs.getString('expense_heads');

      if (cachedExpenseHeads != null) {
        try {
          final decoded = jsonDecode(cachedExpenseHeads);
          if (decoded is List) {
            if (mounted) {
              setState(() {
                _expenseHeads = _filterExpenseHeads(List<Map<String, dynamic>>.from(decoded));
                if (_expenseHeads.isNotEmpty) {
                  _expenseHead = _expenseHeads.first['name']?.toString();
                }
              });
            }
          }
        } catch (_) {
          if (mounted) {
            setState(() {
              _expenseHeads = [];
              _expenseHead = null;
            });
          }
        }
      }

      bool hasInternet = await _hasInternetConnection();

      if (hasInternet && _shouldFetchExpenseHeads()) {
        await _fetchExpenseHeads();
      } else if (_expenseHeads.isEmpty && hasInternet) {
        await _fetchExpenseHeads();
      } else if (_expenseHeads.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No internet connection. Expense heads not available.',
                style: TextStyle(fontSize: getResponsiveFontSize(context, 14.0)),
              ),
            ),
          );
        }
        if (mounted) {
          setState(() {
            _expenseHeads = [];
            _expenseHead = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading expense heads: $e',
              style: TextStyle(fontSize: getResponsiveFontSize(context, 14.0)),
            ),
          ),
        );
      }
    }
  }

  Future<void> _fetchExpenseHeads() async {
    final url = Uri.parse("https://stage-cash.fesf-it.com/api/get-expense-heads");
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    if (token.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No auth token found. Please log in again.')),
        );
      }
      return;
    }

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        // The API now returns a map with a 'data' key containing the list
        final data = jsonDecode(response.body);
        List<dynamic> expenseList;
        if (data is Map && data.containsKey('data') && data['data'] is List) {
          expenseList = data['data'];
        } else if (data is List) {
          expenseList = data;
        } else {
          expenseList = [];
        }
        final filtered = _filterExpenseHeads(
          expenseList
              .map<Map<String, dynamic>>((item) => {
                    'id': item['id'],
                    'name': item['name'],
                    'code': item['code'],
                  })
              .toList(),
        );
        if (mounted) {
          setState(() {
            _expenseHeads = filtered;
            if (_expenseHeads.isNotEmpty) {
              _expenseHead = _expenseHeads.first['name']?.toString();
            } else {
              _expenseHead = null;
            }
          });
        }
        await prefs.setString('expense_heads', jsonEncode(filtered));
      } else {
        String errorMsg = 'Failed to load expense heads: ${response.statusCode}';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data.containsKey('message')) {
            errorMsg = data['message'].toString();
          }
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorMsg,
                style: TextStyle(fontSize: getResponsiveFontSize(context, 14.0)),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error loading expense heads: $e',
              style: TextStyle(fontSize: getResponsiveFontSize(context, 14.0)),
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.of(context).pop();
                await _pickImageFromSource(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.of(context).pop();
                await _pickImageFromSource(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      bool hasPermission = true;

      if (source == ImageSource.camera) {
        var cameraStatus = await Permission.camera.request();
        hasPermission = cameraStatus.isGranted;
      } else {
        if (Platform.isAndroid) {
          var photosStatus = await Permission.photos.request();
          hasPermission = photosStatus.isGranted;
        } else {
          var photosStatus = await Permission.photos.request();
          hasPermission = photosStatus.isGranted;
        }
      }

      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Permission denied for ${source == ImageSource.camera ? "camera" : "gallery"}.',
                style: TextStyle(fontSize: getResponsiveFontSize(context, 14.0)),
              ),
            ),
          );
        }
        return;
      }

      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No image selected.'),
            ),
          );
        }
        return;
      }

      _pickedXFile = pickedFile;

      CroppedFile? croppedFile;
      try {
        croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Image',
              toolbarColor: Colors.deepPurple,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: true,
            ),
            IOSUiSettings(title: 'Crop Image'),
          ],
        );
      } catch (e) {
        croppedFile = null;
      }

      if (croppedFile == null || !(await File(croppedFile.path).exists())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image cropping cancelled or failed.')),
          );
        }
        return;
      }

      if (mounted) {
        setState(() {
          _imagePath = croppedFile!.path;
          _pickedXFile = XFile(croppedFile.path);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image selected successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing image: $e')),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return;
    if (_imagePath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an image.')),
        );
      }
      return;
    }
    if (_expenseHead == null || _expenseHead!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an expense head.')),
        );
      }
      return;
    }

    Map<String, dynamic> selectedExpenseHead = {};
    try {
      selectedExpenseHead = _expenseHeads.firstWhere(
        (head) => head['name'] == _expenseHead,
        orElse: () => <String, dynamic>{},
      );
    } catch (_) {
      selectedExpenseHead = {};
    }

    final result = {
      'narration': _narrationController.text,
      'amount': double.tryParse(_amountController.text) ?? 0.0,
      'expenseHead': _expenseHead,
      'expenseHeadId': selectedExpenseHead['id'],
      'date': _selectedDate,
      'imagePath': _imagePath,
    };

    if (mounted) {
      Navigator.pop(context, result);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    final currentDay = now.day;

    DateTime firstAllowedDate;
    DateTime lastAllowedDate = now;

    if (currentDay > 15) {
      firstAllowedDate = DateTime(currentYear, currentMonth, 1);
    } else {
      final prevMonth = currentMonth == 1 ? 12 : currentMonth - 1;
      final prevYear = currentMonth == 1 ? currentYear - 1 : currentYear;
      firstAllowedDate = DateTime(prevYear, prevMonth, 16);
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstAllowedDate,
      lastDate: lastAllowedDate,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.deepPurple),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
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
            fontSize: getResponsiveFontSize(context, 18.0),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _narrationController,
                decoration: const InputDecoration(labelText: 'Narration'),
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Please enter narration' : null,
              ),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter amount';
                  final parsed = double.tryParse(value);
                  if (parsed == null || parsed <= 0) return 'Please enter a valid amount';
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                value: _expenseHead,
                decoration: const InputDecoration(labelText: 'Expense Head'),
                items: _expenseHeads.isEmpty
                    ? [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('No expense heads available'),
                        )
                      ]
                    : _expenseHeads
                        .map(
                          (head) => DropdownMenuItem<String>(
                            value: head['name']?.toString(),
                            child: Text(head['name']?.toString() ?? ''),
                          ),
                        )
                        .toList(),
                onChanged: _expenseHeads.isEmpty
                    ? null
                    : (value) {
                        setState(() => _expenseHead = value);
                      },
                validator: (value) =>
                    (_expenseHeads.isNotEmpty && (value == null || value.isEmpty))
                        ? 'Please select an expense head'
                        : null,
              ),
              ListTile(
                title: Text(
                    'Date: ${DateFormat('dd/MM/yy').format(_selectedDate)}'),
                trailing: const Icon(Icons.event),
                onTap: () => _selectDate(context),
              ),
              if (_imagePath != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_imagePath!),
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 120,
                        width: 120,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image_outlined, size: 48),
                      ),
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _pickImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 20),
                          SizedBox(width: 8),
                          Text('Pick Image'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 20),
                          SizedBox(width: 8),
                          Text('Submit'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
