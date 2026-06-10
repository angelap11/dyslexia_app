// import 'package:flutter/material.dart';
// import 'files_service.dart';
//
// class FilesScreen extends StatefulWidget {
//   const FilesScreen({super.key});
//
//   @override
//   State<FilesScreen> createState() => _FilesScreenState();
// }
//
// class _FilesScreenState extends State<FilesScreen> {
//
//   final FileService _fileService = FileService();
//
//   Future<void> pickFile() async {
//
//     final text = await _fileService.pickTextFile();
//
//     if (text != null) {
//       Navigator.pop(context, text);
//     }
//
//   }
//
//   @override
//   Widget build(BuildContext context) {
//
//     return Scaffold(
//
//       appBar: AppBar(
//         title: const Text('Upload File'),
//       ),
//
//       body: Center(
//
//         child: ElevatedButton(
//           onPressed: pickFile,
//           child: const Text('📄 Select TXT File'),
//         ),
//
//       ),
//
//     );
//   }
// }