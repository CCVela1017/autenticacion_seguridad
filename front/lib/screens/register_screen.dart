import 'package:flutter/material.dart';
import 'package:autenticacion_seguridad/services/auth_service.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final AuthService _authService = AuthService();


  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();


  String _selectedRole = 'Usuario';
  final List<String> _roles = ['Usuario', 'Administrador'];


  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasDigit = false;
  bool _hasSpecialChar = false;
  bool _passwordsMatch = false;

  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);
    _confirmController.addListener(_validatePassword);
  }

  void _validatePassword() {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasDigit = password.contains(RegExp(r'\d'));
      _hasSpecialChar = password.contains(RegExp(r'[@$!%*?&._-]'));
      _passwordsMatch = password.isNotEmpty && password == confirm;
    });
  }

  Future<void> _registerUser() async {
    if (_usernameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Por favor ingrese un nombre de usuario.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
    
      final result = await _authService.registerUser(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole,
      );

      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Usuario registrado con éxito! Inicia sesión.')),
        );
        Navigator.pop(context);
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'No se pudo completar el registro.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error de conexión: $e';
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro Seguro'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      backgroundColor: const Color(0xFFF3F4F6),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Center(
                  child: Icon(Icons.person_add_alt_1, size: 60, color: Colors.deepPurple),
                ),
                const SizedBox(height: 15),
                const Center(
                  child: Text(
                    'Crea una cuenta',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ),
                const SizedBox(height: 20),

                if (_errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 15),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent),
                    ),
                    child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ),


                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Usuario / Correo / Carnet',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
                const SizedBox(height: 15),

                // Campo Contraseña
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
                const SizedBox(height: 15),


                TextField(
                  controller: _confirmController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Confirmar Contraseña',
                    prefixIcon: const Icon(Icons.lock_reset),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
                const SizedBox(height: 15),


                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: InputDecoration(
                    labelText: 'Rol del sistema',
                    prefixIcon: const Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  items: _roles.map((role) {
                    return DropdownMenuItem(value: role, child: Text(role));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value!;
                    });
                  },
                ),
                const SizedBox(height: 20),

                const Text(
                  'Requisitos de seguridad:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 8),

                _buildRequirementRow('Mínimo 8 caracteres', _hasMinLength),
                _buildRequirementRow('Al menos una letra mayúscula', _hasUppercase),
                _buildRequirementRow('Al menos una letra minúscula', _hasLowercase),
                _buildRequirementRow('Al menos un número', _hasDigit),
                _buildRequirementRow('Al menos un carácter especial (@\$!%*?&._-)', _hasSpecialChar),
                _buildRequirementRow('Las contraseñas coinciden', _passwordsMatch),

                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: (_isLoading ||
                            !(_hasMinLength &&
                                _hasUppercase &&
                                _hasLowercase &&
                                _hasDigit &&
                                _hasSpecialChar &&
                                _passwordsMatch))
                        ? null
                        : _registerUser,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Registrarse', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequirementRow(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isMet ? Colors.green : Colors.grey,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isMet ? Colors.green[700] : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}