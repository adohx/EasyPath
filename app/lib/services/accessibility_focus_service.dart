import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AccessibilityFocusService {
  static const _channel = MethodChannel(
    'com.ana.accessibility_nav_assistant/accessibility_focus',
  );

  /// Moves TalkBack accessibility focus to the widget identified by [key].
  /// Requires TalkBack (or another accessibility service) to be active.
  static void focusWidget(GlobalKey key) {
    // Two nested callbacks: first waits for widget rebuild,
    // second waits for semantics flush (which happens between frames).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final nodeId =
            key.currentContext?.findRenderObject()?.debugSemantics?.id;
        if (nodeId != null) {
          await _channel.invokeMethod('focusNode', {'nodeId': nodeId});
        }
      });
    });
  }
}
