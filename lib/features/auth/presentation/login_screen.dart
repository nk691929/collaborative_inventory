import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/auth_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController(text: 'manager@example.com');
  final _passwordController = TextEditingController(text: 'manager123');
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorText;

  final _mockUsers = {
    'Admin': 'admin@example.com',
    'Manager': 'manager@example.com',
    'Viewer': 'viewer@example.com',
  };

  void _login() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await ref.read(authProvider.notifier).login(
            _emailController.text,
            _passwordController.text,
          );
       if (mounted) {
         Navigator.of(context).pushReplacementNamed('/');
       }
    } catch (e) {
      setState(() {
        _errorText = 'Login failed: ${e.toString().split(':').last.trim()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/Title
              Icon(Icons.inventory, size: 80, color: Colors.indigo.shade700),
              const SizedBox(height: 16),
              const Text(
                'Collaborative Inventory',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 32),

              // Login Form Card
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email (e.g., manager@example.com)',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (v) => v!.isEmpty || !v.contains('@') ? 'Enter a valid email' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (v) => v!.isEmpty ? 'Password is required' : null,
                        ),
                        const SizedBox(height: 24),
                        
                        if (_errorText != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              _errorText!,
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('LOG IN'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        Wrap(
                          spacing: 8.0,
                          children: _mockUsers.entries.map((entry) {
                            return ActionChip(
                              label: Text(entry.key),
                              onPressed: () {
                                setState(() {
                                  _emailController.text = entry.value;
                                  _passwordController.text = '${entry.key.toLowerCase()}123'; 
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text('Tap to pre-fill credentials.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
