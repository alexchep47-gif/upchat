import 'package:flutter_test/flutter_test.dart';
import 'package:upchat/data/services/signal_crypto_service.dart';

void main() {
  group('SignalCryptoService transport envelope', () {
    test('SignalEnvelope survives a round-trip to map and back', () {
      const envelope = SignalEnvelope(
        messageId: 'msg-42',
        senderId: 'alice',
        recipientId: 'bob',
        ciphertext: 'encrypted-payload',
        preKeyMessage: true,
      );

      final decoded = SignalEnvelope.fromMap(envelope.toMap());
      expect(decoded.messageId, 'msg-42');
      expect(decoded.senderId, 'alice');
      expect(decoded.recipientId, 'bob');
      expect(decoded.ciphertext, 'encrypted-payload');
      expect(decoded.preKeyMessage, isTrue);
    });

    test('queued state is tracked explicitly in the message lifecycle', () {
      expect(MessageStatus.values.contains(MessageStatus.queued), isTrue);
    });
  });
}
