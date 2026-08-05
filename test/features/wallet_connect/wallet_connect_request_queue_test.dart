import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/wallet_connect/application/wallet_connect_request_queue.dart';
import 'package:safe_wallet/features/wallet_connect/domain/wallet_connect_caip.dart';
import 'package:safe_wallet/features/wallet_connect/domain/wallet_connect_models.dart';

void main() {
  WalletConnectRequest request(
    int id, {
    String topic = 'topic-a',
    DateTime? expiry,
  }) {
    return WalletConnectRequest(
      id: id,
      topic: topic,
      chain: const Caip2ChainId(namespace: 'eip155', reference: '56'),
      method: 'personal_sign',
      params: const ['0x6869', '0xabc'],
      peer: const WalletConnectPeerMetadata(
        name: 'Example dApp',
        description: 'Example',
        url: 'https://example.com',
        icons: [],
      ),
      expiry: expiry ?? DateTime.utc(2030),
    );
  }

  test('serializes requests and advances only after completion', () async {
    final queue = WalletConnectRequestQueue(now: () => DateTime.utc(2026));
    addTearDown(queue.dispose);
    final seen = <int>[];
    final subscription = queue.requests.listen((value) => seen.add(value.id));
    addTearDown(subscription.cancel);

    expect(queue.enqueue(request(1)), WalletConnectEnqueueResult.accepted);
    expect(queue.enqueue(request(2)), WalletConnectEnqueueResult.accepted);
    await pumpEventQueue();
    expect(seen, [1]);

    expect(queue.complete(topic: 'topic-a', id: 1), isTrue);
    await pumpEventQueue();
    expect(seen, [1, 2]);
  });

  test(
    'replays an active request when the UI listener attaches late',
    () async {
      final queue = WalletConnectRequestQueue(now: () => DateTime.utc(2026));
      addTearDown(queue.dispose);
      expect(queue.enqueue(request(1)), WalletConnectEnqueueResult.accepted);
      final seen = <int>[];
      final subscription = queue.requests.listen((value) => seen.add(value.id));
      addTearDown(subscription.cancel);

      queue.replayActive();
      await pumpEventQueue();

      expect(seen, [1]);
    },
  );

  test('deduplicates active, pending, and already completed requests', () {
    final queue = WalletConnectRequestQueue(now: () => DateTime.utc(2026));
    addTearDown(queue.dispose);

    expect(queue.enqueue(request(1)), WalletConnectEnqueueResult.accepted);
    expect(queue.enqueue(request(1)), WalletConnectEnqueueResult.duplicate);
    expect(queue.complete(topic: 'topic-a', id: 1), isTrue);
    expect(queue.enqueue(request(1)), WalletConnectEnqueueResult.duplicate);
  });

  test('rejects expired requests without blocking the next request', () async {
    final queue = WalletConnectRequestQueue(now: () => DateTime.utc(2026));
    addTearDown(queue.dispose);
    final seen = <int>[];
    final subscription = queue.requests.listen((value) => seen.add(value.id));
    addTearDown(subscription.cancel);

    expect(
      queue.enqueue(request(1, expiry: DateTime.utc(2025))),
      WalletConnectEnqueueResult.expired,
    );
    expect(queue.enqueue(request(2)), WalletConnectEnqueueResult.accepted);
    await pumpEventQueue();

    expect(seen, [2]);
  });

  test('cancels active and pending requests for a deleted session', () async {
    final queue = WalletConnectRequestQueue(now: () => DateTime.utc(2026));
    addTearDown(queue.dispose);
    final seen = <int>[];
    final cancelled = <int>[];
    final subscription = queue.requests.listen((value) => seen.add(value.id));
    final cancellationSubscription = queue.cancelledRequests.listen(
      (value) => cancelled.add(value.id),
    );
    addTearDown(subscription.cancel);
    addTearDown(cancellationSubscription.cancel);

    queue.enqueue(request(1));
    queue.enqueue(request(2));
    queue.enqueue(request(3, topic: 'topic-b'));
    await pumpEventQueue();

    expect(queue.cancelTopic('topic-a'), 2);
    await pumpEventQueue();
    expect(seen, [1, 3]);
    expect(cancelled, [1, 2]);
    expect(queue.activeRequest?.topic, 'topic-b');
  });

  test('allows exactly one completion for a request', () {
    final queue = WalletConnectRequestQueue(now: () => DateTime.utc(2026));
    addTearDown(queue.dispose);

    queue.enqueue(request(1));
    expect(queue.complete(topic: 'topic-a', id: 1), isTrue);
    expect(queue.complete(topic: 'topic-a', id: 1), isFalse);
  });

  test('completed request dedupe history is bounded', () {
    final queue = WalletConnectRequestQueue(now: () => DateTime.utc(2026));
    addTearDown(queue.dispose);

    for (var id = 0; id < 1500; id += 1) {
      expect(queue.enqueue(request(id)), WalletConnectEnqueueResult.accepted);
      expect(queue.complete(topic: 'topic-a', id: id), isTrue);
    }

    expect(queue.completedDedupeCount, lessThanOrEqualTo(1024));
    expect(queue.enqueue(request(1499)), WalletConnectEnqueueResult.duplicate);
  });
}
