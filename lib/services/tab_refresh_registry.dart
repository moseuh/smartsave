import 'package:flutter/widgets.dart';

/// Tabs call [TabRefreshRegistry.register] in initState and [unregister] in dispose.
/// The shell calls [TabRefreshRegistry.refresh] on tab switch and app resume.
class TabRefreshRegistry {
  TabRefreshRegistry._();

  static final Map<int, VoidCallback> _callbacks = {};

  static void register(int tabIndex, VoidCallback fn) => _callbacks[tabIndex] = fn;
  static void unregister(int tabIndex) => _callbacks.remove(tabIndex);
  static void refresh(int tabIndex) => _callbacks[tabIndex]?.call();
}
