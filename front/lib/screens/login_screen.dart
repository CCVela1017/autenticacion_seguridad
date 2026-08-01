import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:local_auth/local_auth.dart';
import 'package:autenticacion_seguridad/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final LocalAuthentication _localAuth = LocalAuthentication();

  int _currentStep = 1;

  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();

  String _userRole = '';
  String _userName = '';
  String _errorMessage = '';
  bool _isLoading = false;
  bool _biometricVerified = false;

  Future<void> _verifyIdentity() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    String input = _idController.text.trim();
    final result = await _authService.identifyUser(input);

    setState(() {
      _isLoading = false;
      if (result['exists'] == true) {
        _userName = result['name'] ?? 'Usuario';
        _currentStep = 2;
      } else {
        _errorMessage = 'Usuario inexistente en el sistema.';
      }
    });
  }

  Future<void> _authenticateBiometrics() async {
    try {
      bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      bool isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        setState(() {
          _errorMessage = 'Este dispositivo no soporta biometría.';
        });
        return;
      }

      bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Por favor, autentícate para continuar',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      setState(() {
        _biometricVerified = didAuthenticate;
        if (!didAuthenticate) {
          _errorMessage = 'Autenticación biométrica cancelada o fallida.';
        } else {
          _errorMessage = '';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error en biometría: $e';
      });
    }
  }

  Future<void> _authenticateAllFactors() async {
    if (!_biometricVerified) {
      setState(() {
        _errorMessage = 'Debe verificar su biometría (Face ID / Huella) antes de ingresar.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final result = await _authService.authenticateUser(
      identifier: _idController.text.trim(),
      password: _passController.text,
      otpCode: _pinController.text.trim(),
      biometricVerified: _biometricVerified,
    );

    setState(() {
      _isLoading = false;
      if (result['success'] == true) {
        _userRole = result['role'] ?? 'Usuario';
        _currentStep = 3;
      } else {
        _errorMessage = 'Autenticación fallida: Verifique contraseña, PIN o biometría.';
      }
    });
  }

  void _logout() {
    setState(() {
      _currentStep = 1;
      _idController.clear();
      _passController.clear();
      _pinController.clear();
      _userRole = '';
      _userName = '';
      _errorMessage = '';
      _biometricVerified = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Colors.deepPurple;
    final Color secondaryColor = Colors.purpleAccent;
    final Color bgColor = const Color(0xFFF3F4F6);

    return Scaffold(
      body: Stack(
        children: [
          Container(color: bgColor),
          Positioned(
            top: -100, left: -100,
            child: Container(
              height: 300, width: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: primaryColor.withValues(alpha: 0.2)),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100), child: Container()),
            ),
          ),
          Positioned(
            bottom: -150, right: -100,
            child: Container(
              height: 400, width: 400,
              decoration: BoxDecoration(shape: BoxShape.circle, color: secondaryColor.withValues(alpha: 0.2)),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120), child: Container()),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        width: 420,
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline, size: 70, color: Colors.deepPurple),
                            const SizedBox(height: 15),
                            const Text(
                              'Inicio de Sesión',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 25),

                            if (_errorMessage.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(10),
                                margin: const EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.redAccent),
                                ),
                                child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                              ),

                            _isLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(20.0),
                                    child: CircularProgressIndicator(color: Colors.deepPurple),
                                  )
                                : _buildStepContent(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return Column(
          children: [
            _customTextField(_idController, 'Usuario, Correo o Carnet', Icons.person_outline),
            const SizedBox(height: 25),
            _actionButton('Siguiente', _verifyIdentity),
          ],
        );
      case 2:
        return Column(
          children: [
            Text('Bienvenido, $_userName', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _customTextField(_passController, 'Contraseña', Icons.lock_outline, obscure: true),
            const SizedBox(height: 15),
            _customTextField(_pinController, 'PIN de seguridad', Icons.pin, obscure: true, numeric: true),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 45,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _biometricVerified ? Colors.green : Colors.deepPurple),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _authenticateBiometrics,
                icon: Icon(
                  _biometricVerified ? Icons.check_circle : Icons.fingerprint,
                  color: _biometricVerified ? Colors.green : Colors.deepPurple,
                ),
                label: Text(
                  _biometricVerified ? 'Biometría verificada' : 'Escanear Huella / Face ID',
                  style: TextStyle(color: _biometricVerified ? Colors.green : Colors.deepPurple, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 25),
            _actionButton('Autenticar', _authenticateAllFactors),
          ],
        );
      case 3:
        return Column(
          children: [
            const Icon(Icons.verified_user, size: 70, color: Colors.green),
            const SizedBox(height: 15),
            Text(
              'Acceso autorizado — Rol: $_userRole',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            _actionButton('Cerrar sesión', _logout, color: Colors.redAccent),
          ],
        );
      default:
        return Container();
    }
  }

  Widget _customTextField(TextEditingController controller, String label, IconData icon, {bool obscure = false, bool numeric = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        style: const TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.black54),
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: Colors.black54),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _actionButton(String text, VoidCallback onPressed, {Color color = Colors.deepPurple}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}