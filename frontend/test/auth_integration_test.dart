import 'package:flutter_test/flutter_test.dart';
import 'package:xueba_app/services/auth_service.dart';
import 'package:xueba_app/services/backend_api_service.dart';
import 'dart:math';

void main() {
  group('Auth integration', () {
    test('Backend health check', () async {
      final healthy = await BackendApiService.healthCheck();
      expect(healthy, isTrue, reason: 'Backend should be running at ${healthy}');
    });

    test('Register then login', () async {
      final rand = Random();
      final phone = '139${rand.nextInt(90000000).toString().padLeft(8, '0')}';
      final password = 'pass${rand.nextInt(100000)}';

      // Register
      final register = await AuthService.instance.register(
        phone: phone,
        code: '123456',
        password: password,
      );
      expect(register.success, isTrue, reason: register.error ?? 'register failed');

      // Login
      final login = await AuthService.instance.loginWithPassword(
        phone: phone,
        password: password,
      );
      expect(login.success, isTrue, reason: login.error ?? 'login failed');
    });
  });
}
