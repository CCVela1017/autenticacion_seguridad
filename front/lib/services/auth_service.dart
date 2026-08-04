import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {

  final String baseUrl = 'https://autenticacion-app-zjuo.onrender.com/auth';

  Future<Map<String, dynamic>> identifyUser(String identifier) async {
    try {
      
      
      final response = await http.post(
        Uri.parse('$baseUrl/identify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'identifier': identifier}),
      );

     

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'exists': false};
      }
    } catch (e) {
      return {'exists': false};
    }
  }

  Future<Map<String, dynamic>> loginPassword({
    required String username,
    required String password,
  }) async {
    try {
     
      
      final response = await http.post(
        Uri.parse('$baseUrl/login-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );


      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'preAuthToken': data['preAuthToken'],
          'needsTotpSetup': data['needsTotpSetup'],
        };
      } else {
        return {'success': false, 'error': data['error'] ?? 'Credenciales inválidas'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }


  Future<Map<String, dynamic>> authenticateUser({
    required String identifier,
    required String password,
    required String otpCode,
    required bool biometricVerified,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/authenticate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': identifier,
          'password': password,
          'otpCode': otpCode,
          'biometricVerified': biometricVerified,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'role': data['role'], 'token': data['token']};
      } else {
        return {'success': false};
      }
    } catch (e) {
      return {'success': false};
    }
  }

  
  Future<Map<String, dynamic>> registerUser({
    required String username,
    required String password,
    required String role,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'role': role,
        }),
      );

      if (response.statusCode == 201) {
        return {'success': true, 'message': 'Usuario creado con éxito'};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'error': data['error'] ?? 'Error al registrar'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }

  
  Future<Map<String, dynamic>> setupTotp(String preAuthToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/totp/setup'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $preAuthToken',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {'error': 'No se pudo generar el código QR'};
      }
    } catch (e) {
      return {'error': 'Error de conexión: $e'};
    }
  }


  Future<Map<String, dynamic>> confirmTotp(String preAuthToken, String code) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/totp/confirm'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $preAuthToken',
        },
        body: jsonEncode({'code': code}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'token': data['token']};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Código inválido'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }


  Future<Map<String, dynamic>> verifyLoginTotp(String preAuthToken, String code) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/totp/verify'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $preAuthToken',
        },
        body: jsonEncode({'code': code}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'token': data['token']};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Código inválido'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión: $e'};
    }
  }
}