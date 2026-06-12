import 'package:flutter/material.dart';
import 'auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final AuthService _authService = AuthService();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;

  Future<void> register() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пополни ги сите полиња.')),
      );
      return;
    }

    setState(() => isLoading = true);

    final user = await _authService.registerUser(
      name: name,
      email: email,
      password: password,
    );

    if (!mounted) return;

    setState(() => isLoading = false);

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Грешка при регистрација.')),
      );
      return;
    }

    // 🔥 SUCCESS → Firebase already logs user in
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Успешна регистрација!')),
    );

    // optional: go back to login OR go home automatically
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFAF3),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 80),

              const Text('Креирај профил',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800)),

              const SizedBox(height: 34),

              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Име'),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Лозинка'),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isLoading ? null : register,
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Регистрирај се'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}