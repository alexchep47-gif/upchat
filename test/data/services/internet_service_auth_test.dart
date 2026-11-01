import 'package:flutter_test/flutter_test.dart';
import 'package:upchat/data/services/internet_service.dart';

void main() {
  group('InternetService.selectBearerToken', () {
    test(
      'utilise le secret appareil avec le relais legacy même si Firebase est connecté',
      () {
        expect(
          InternetService.selectBearerToken(
            firebaseAdmin: false,
            firebaseToken: 'firebase-id-token',
            deviceSecret: 'device-secret',
          ),
          'device-secret',
        );
      },
    );

    test(
      'utilise le jeton Firebase lorsque le serveur vérifie Firebase Admin',
      () {
        expect(
          InternetService.selectBearerToken(
            firebaseAdmin: true,
            firebaseToken: 'firebase-id-token',
            deviceSecret: 'device-secret',
          ),
          'firebase-id-token',
        );
      },
    );

    test('refuse Firebase Admin sans session authentifiée', () {
      expect(
        () => InternetService.selectBearerToken(
          firebaseAdmin: true,
          firebaseToken: null,
          deviceSecret: 'device-secret',
        ),
        throwsStateError,
      );
    });
  });
}
