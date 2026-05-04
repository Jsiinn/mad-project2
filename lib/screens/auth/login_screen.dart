import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _loading = true; _errorMessage = null; });

    try {
      await context.read<AuthService>().signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // Router redirect handles navigation to /feed
    } catch (e) {
      setState(() { _errorMessage = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),

                // Logo / Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0057FF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.fitness_center, color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 16),
                      const Text('BEAST MODE',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                            color: Colors.white, letterSpacing: 2)),
                      const SizedBox(height: 4),
                      Text('Social Fitness Tracker',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined, color: Colors.grey),
                  ),
                  validator: (v) => v == null || !v.contains('@') ? 'Enter a valid email' : null,
                ),

                const SizedBox(height: 16),

                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline, color: Colors.grey),
                  ),
                  validator: (v) => v == null || v.length < 6 ? 'Min 6 characters' : null,
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFF3B30).withOpacity(0.3)),
                    ),
                    child: Text(_errorMessage!,
                        style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 13)),
                  ),
                ],

                const SizedBox(height: 24),

                // Login button
                ElevatedButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),

                const SizedBox(height: 16),

                // Register link
                Center(
                  child: TextButton(
                    onPressed: () => context.go('/register'),
                    child: Text("Don't have an account? Sign up",
                        style: TextStyle(color: Colors.white.withOpacity(0.7))),
                  ),
                ),

                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
