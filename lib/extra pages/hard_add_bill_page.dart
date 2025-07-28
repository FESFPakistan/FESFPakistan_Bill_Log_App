// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:image_cropper/image_cropper.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:intl/intl.dart';
// import 'dart:io';

// class HardAddBillPage extends StatefulWidget {
//   const HardAddBillPage({Key? key}) : super(key: key);

//   @override
//   _HardAddBillPageState createState() => _HardAddBillPageState();
// }

// class _HardAddBillPageState extends State<HardAddBillPage> {
//   final _formKey = GlobalKey<FormState>();
//   final _narrationController = TextEditingController();
//   final _amountController = TextEditingController();
//   String? _expenseHead;
//   DateTime _selectedDate = DateTime.now();
//   String? _imagePath;

//   // Hardcoded expense heads
//   final List<String> _expenseHeads = ['General', 'Travel', 'Food', 'Office Supplies'];

//   Future<void> _pickImage() async {
//     final picker = ImagePicker();
//     String? sourcePath;

//     final source = await showDialog<ImageSource>(
//       context: context,
//       builder: (BuildContext context) {
//         return SimpleDialog(
//           title: Text('Select Image Source', style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w500)),
//           children: [
//             SimpleDialogOption(
//               onPressed: () => Navigator.pop(context, ImageSource.gallery),
//               child: Text('Gallery', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w400)),
//             ),
//             SimpleDialogOption(
//               onPressed: () => Navigator.pop(context, ImageSource.camera),
//               child: Text('Camera', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w400)),
//             ),
//           ],
//         );
//       },
//     );

//     if (source != null) {
//       final pickedFile = await picker.pickImage(source: source);
//       if (pickedFile != null) {
//         sourcePath = pickedFile.path;
//       }
//     }

//     if (sourcePath != null) {
//       final croppedFile = await ImageCropper().cropImage(
//         sourcePath: sourcePath!,
//         aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
//         compressQuality: 80,
//         uiSettings: [
//           AndroidUiSettings(
//             toolbarTitle: 'Edit Image',
//             toolbarColor: Colors.deepPurple,
//             toolbarWidgetColor: Colors.white,
//             initAspectRatio: CropAspectRatioPreset.square,
//             lockAspectRatio: false,
//           ),
//           IOSUiSettings(
//             title: 'Edit Image',
//             rotateButtonsHidden: false,
//             rotateClockwiseButtonHidden: false,
//           ),
//         ],
//       );

//       if (croppedFile != null) {
//         setState(() {
//           _imagePath = croppedFile.path;
//         });
//       }
//     }
//   }

//   Future<void> _selectDate(BuildContext context) async {
//     final now = DateTime.now();
//     final currentMonth = now.month;
//     final currentYear = now.year;
//     final currentDay = now.day;

//     DateTime firstAllowedDate;
//     DateTime lastAllowedDate;

//     if (currentDay > 15) {
//       firstAllowedDate = DateTime(currentYear, currentMonth, 16);
//       lastAllowedDate = DateTime(currentYear, currentMonth + 1, 0); // Last day of current month
//     } else {
//       firstAllowedDate = DateTime(currentYear, currentMonth, 1);
//       lastAllowedDate = DateTime(currentYear, currentMonth, 15);
//       if (currentDay <= 15) {
//         final prevMonth = currentMonth == 1 ? 12 : currentMonth - 1;
//         final prevYear = currentMonth == 1 ? currentYear - 1 : currentYear;
//         firstAllowedDate = DateTime(prevYear, prevMonth, 16);
//         lastAllowedDate = DateTime(prevYear, prevMonth + 1, 0); // Last day of previous month
//       }
//     }

//     final DateTime? picked = await showDatePicker(
//       context: context,
//       initialDate: _selectedDate,
//       firstDate: firstAllowedDate,
//       lastDate: lastAllowedDate,
//     );
//     if (picked != null && picked != _selectedDate) {
//       setState(() {
//         _selectedDate = picked;
//       });
//     }
//   }

//   void _submitForm() {
//     if (_formKey.currentState!.validate()) {
//       final result = {
//         'narration': _narrationController.text,
//         'amount': double.tryParse(_amountController.text) ?? 0.0,
//         'expenseHead': _expenseHead ?? 'General',
//         'date': _selectedDate,
//         'imagePath': _imagePath,
//       };
//       Navigator.pop(context, result);
//     }
//   }

//   @override
//   void dispose() {
//     _narrationController.dispose();
//     _amountController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Add Bill', style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w600)),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Form(
//           key: _formKey,
//           child: ListView(
//             children: [
//               TextFormField(
//                 controller: _narrationController,
//                 decoration: InputDecoration(labelText: 'Narration', labelStyle: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w400)),
//                 validator: (value) => value!.isEmpty ? 'Please enter narration' : null,
//               ),
//               TextFormField(
//                 controller: _amountController,
//                 decoration: InputDecoration(labelText: 'Amount', labelStyle: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w400)),
//                 keyboardType: TextInputType.number,
//                 validator: (value) => value!.isEmpty ? 'Please enter amount' : null,
//               ),
//               DropdownButtonFormField<String>(
//                 value: _expenseHead,
//                 decoration: InputDecoration(labelText: 'Expense Head', labelStyle: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w400)),
//                 items: _expenseHeads.map((head) {
//                   return DropdownMenuItem<String>(
//                     value: head,
//                     child: Text(head, style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w400)),
//                   );
//                 }).toList(),
//                 onChanged: (value) {
//                   setState(() {
//                     _expenseHead = value;
//                   });
//                 },
//                 validator: (value) => value == null ? 'Please select an expense head' : null,
//               ),
//               ListTile(
//                 title: Text('Date: ${DateFormat('dd/MM/yy').format(_selectedDate)}', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w400)),
//                 trailing: const Icon(Icons.calendar_today),
//                 onTap: () => _selectDate(context),
//               ),
//               if (_imagePath != null)
//                 Padding(
//                   padding: const EdgeInsets.only(top: 16.0),
//                   child: Image.file(File(_imagePath!), height: 100),
//                 ),
//               ElevatedButton(
//                 onPressed: _pickImage,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.deepPurple,
//                   foregroundColor: Colors.white,
//                   minimumSize: const Size(150, 40),
//                   elevation: 0,
//                 ),
//                 child: Text('Pick Image', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500)),
//               ),
//               ElevatedButton(
//                 onPressed: _submitForm,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.deepPurple,
//                   foregroundColor: Colors.white,
//                   minimumSize: const Size(150, 40),
//                   elevation: 0,
//                 ),
//                 child: Text('Submit', style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500)),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }