import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:safe_wallet/features/dapp/application/dapp_request_queue.dart';

void main() {
  test(
    'serializes dApp requests and keeps processing after an error',
    () async {
      final queue = DappRequestQueue();
      final releaseFirst = Completer<void>();
      final events = <String>[];

      final first = queue.enqueue(() async {
        events.add('first-start');
        await releaseFirst.future;
        events.add('first-end');
        throw StateError('first failed');
      });
      final second = queue.enqueue(() async {
        events.add('second-start');
        return 'second-result';
      });

      await Future<void>.delayed(Duration.zero);
      expect(events, ['first-start']);

      releaseFirst.complete();
      await expectLater(first, throwsStateError);
      expect(await second, 'second-result');
      expect(events, ['first-start', 'first-end', 'second-start']);
    },
  );
}
