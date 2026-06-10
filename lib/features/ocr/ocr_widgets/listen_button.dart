import 'package:flutter/material.dart';

class ListenButton extends StatelessWidget {
  final VoidCallback onTap;

  const ListenButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 70,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF63B5D2), Color(0xFF638FDF)],
          ),
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        child: const Center(
          child: Text(
            'Слушај',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}