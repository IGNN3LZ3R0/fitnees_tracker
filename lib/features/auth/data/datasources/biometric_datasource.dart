import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import '../../domain/entities/auth_result.dart';

abstract class BiometricDataSource {
  Future<bool> canAuthenticate();
  Future<AuthResult> authenticate();
}

class BiometricDataSourceImpl implements BiometricDataSource {
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  Future<bool> canAuthenticate() async {
    try {
      // Verificar si el dispositivo tiene hardware biométrico
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = await _localAuth.isDeviceSupported();
      
      return canAuthenticateWithBiometrics || canAuthenticate;
    } catch (e) {
      print('Error verificando biometria: $e');
      return false;
    }
  }

  @override
  Future<AuthResult> authenticate() async {
    try {
      // Verificar disponibilidad
      final canAuth = await canAuthenticate();
      if (!canAuth) {
        return const AuthResult(
          success: false,
          message: 'Biometria no disponible en este dispositivo',
        );
      }

      // Obtener biometrías disponibles
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      print('Biometrias disponibles: $availableBiometrics');

      // Autenticar
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Autentícate para acceder a la app',
        options: const AuthenticationOptions(
          stickyAuth: true,  // No cancelar si sale de la app
          biometricOnly: false,  // Permitir PIN/Patrón como alternativa
        ),
      );

      if (didAuthenticate) {
        return const AuthResult(
          success: true,
          message: 'Autenticacion exitosa',
        );
      } else {
        return const AuthResult(
          success: false,
          message: 'Autenticacion cancelada',
        );
      }

    } catch (e) {
      // Manejar errores específicos
      String errorMessage = 'Error desconocido';
      
      if (e.toString().contains(auth_error.notAvailable)) {
        errorMessage = 'Biometria no disponible';
      } else if (e.toString().contains(auth_error.notEnrolled)) {
        errorMessage = 'No hay huellas registradas';
      } else if (e.toString().contains(auth_error.lockedOut)) {
        errorMessage = 'Bloqueado temporalmente';
      } else if (e.toString().contains(auth_error.permanentlyLockedOut)) {
        errorMessage = 'Bloqueado permanentemente';
      }

      print('Error en autenticacion: $e');
      return AuthResult(
        success: false,
        message: errorMessage,
      );
    }
  }
}