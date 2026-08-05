import 'package:flutter/material.dart';

import '../../../shared/design/app_spacing.dart';
import '../../../shared/widgets/app_drag_handle.dart';

final class DappSheetContainer extends StatelessWidget {
  const DappSheetContainer({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageX,
              0,
              AppSpacing.pageX,
              AppSpacing.pageX,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppDragHandle(),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
