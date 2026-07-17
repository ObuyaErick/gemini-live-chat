import 'package:flutter/material.dart';

/// Wraps a below-the-thread affordance (tool chip, confirmation / clarification
/// card) in the same centered 760px column the messages use.
class CenteredBand extends StatelessWidget {
  final Widget child;
  const CenteredBand({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Align(alignment: Alignment.centerLeft, child: child),
        ),
      ),
    );
  }
}
