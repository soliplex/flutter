import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:soliplex_frontend/shared/utils/platform_resolver.dart';

class PlatformAdaptiveProgressIndicator extends StatelessWidget {
  const PlatformAdaptiveProgressIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    if (isCupertino(context)) {
      return const CupertinoActivityIndicator();
    }

    return const CircularProgressIndicator();
  }
}
