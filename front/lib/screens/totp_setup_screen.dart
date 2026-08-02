import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:autenticacion_seguridad/services/auth_service.dart';

class TotpSetupScreen extends StatefulWidget {
  final String preAuthToken;

  const TotpSetupScreen({super.key, required this.preAuthToken});

  @override
  State<TotpSetupScreen> createState() => _TotpSetupScreenState();
}

class _TotpSetupScreenState extends State<TotpSetupScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _codeController = TextEditingController();

  String? _secret;
  String _errorMessage = '';
  bool _isLoading = true;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _loadTotpSetup();
  }

  Future<void> _loadTotpSetup() async {
    final result = await _authService.setupTotp(widget.preAuthToken);
    setState(() {
      _isLoading = false;
      if (result['secret'] != null) {
        _secret = result['secret'];
      } else {
        _errorMessage = 'Error al cargar la configuración TOTP.';
      }
    });
  }

  Future<void> _verifyAndConfirm() async {
    setState(() {
      _isConfirming = true;
      _errorMessage = '';
    });

    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() {
        _isConfirming = false;
        _errorMessage = 'El código debe tener 6 dígitos.';
      });
      return;
    }

    final result = await _authService.confirmTotp(widget.preAuthToken, code);

    setState(() {
      _isConfirming = false;
      if (result['success'] == true) {
        Navigator.pop(context, true);
      } else {
        _errorMessage = result['error'] ?? 'Código inválido.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Colors.deepPurple;
    const Color secondaryColor = Colors.purpleAccent;
    const Color bgColor = Color(0xFFF3F4F6);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Verificación en Dos Pasos'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
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
                        padding: const EdgeInsets.all(30),
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
                        child: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(40.0),
                                child: Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.security, size: 60, color: Colors.deepPurple),
                                  const SizedBox(height: 15),
                                  const Text(
                                    'Configura tu App Autenticadora',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Ingresa esta clave secreta en Google Authenticator o Authy:',
                                    style: TextStyle(fontSize: 13, color: Colors.black54),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),

                                  if (_secret != null)
                                    Container(
                                      padding: const EdgeInsets.all(15),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                                      ),
                                      child: Column(
                                        children: [
                                          const Text('Clave secreta:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                          const SizedBox(height: 5),
                                          SelectableText(_secret!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.5)),
                                        ],
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
                                    controller: _codeController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    decoration: InputDecoration(
                                      labelText: 'Código de 6 dígitos de la app',
                                      labelStyle: const TextStyle(color: Colors.black54),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                                      counterText: '',
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  _isConfirming
                                      ? const CircularProgressIndicator(color: Colors.deepPurple)
                                      : SizedBox(
                                          width: double.infinity,
                                          height: 50,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.deepPurple,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                            ),
                                            onPressed: _verifyAndConfirm,
                                            child: const Text('Confirmar y Activar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
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
}