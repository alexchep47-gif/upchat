import 'package:flutter_test/flutter_test.dart';
import 'package:upchat/data/models/message_model.dart';
import 'package:upchat/data/services/signal_crypto_service.dart';

void main() {
  group('Signal transport envelope', () {
    test('survives a map round-trip', () {
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

    test('queued is a persisted delivery state', () {
      final message = MessageModel(
        id: 'queued-message',
        conversationId: 'bob',
        senderId: 'alice',
        senderName: 'Alice',
        type: MessageType.text,
        content: 'hello',
        isMe: true,
        status: MessageStatus.queued,
      );

      final restored = MessageModel.fromMap(message.toMap());
      expect(restored.status, MessageStatus.queued);
    });
  });
}
