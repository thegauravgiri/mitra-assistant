import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import '../../../core/constants/app_constants.dart';

class WindowControlService {
  static final WindowControlService instance = WindowControlService._();
  WindowControlService._();

  final MethodChannel _channel = const MethodChannel(AppConstants.windowControlChannel);

  Future<void> initializeWindow() async {
    await windowManager.ensureInitialized();
    await hotKeyManager.unregisterAll();

    WindowOptions windowOptions = const WindowOptions(
      size: Size(420, 680),
      minimumSize: Size(320, 200),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      alwaysOnTop: true,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.setAsFrameless();
      await windowManager.setHasShadow(false);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.show();
      await windowManager.focus();
    });

    await _registerGlobalHotkeys();
  }

  Future<bool> enableScreenProtection() async {
    try {
      final bool result = await _channel.invokeMethod('setSharingTypeNone');
      return result;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<bool> disableScreenProtection() async {
    try {
      final bool result = await _channel.invokeMethod('setSharingTypeReadWrite');
      return result;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<void> panicHide() async {
    try {
      await _channel.invokeMethod('panicHide');
    } on PlatformException catch (_) {
      await windowManager.hide();
    }
  }

  Future<void> showWindow() async {
    try {
      await _channel.invokeMethod('showWindow');
    } on PlatformException catch (_) {
      await windowManager.show();
    }
  }

  Future<void> _registerGlobalHotkeys() async {
    // Panic Hide: Command + Shift + H
    HotKey panicHotkey = HotKey(
      key: PhysicalKeyboardKey.keyH,
      modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
      scope: HotKeyScope.system,
    );

    await hotKeyManager.register(
      panicHotkey,
      keyDownHandler: (hotKey) async {
        await panicHide();
      },
    );

    // Toggle Overlay: Command + Shift + M
    HotKey toggleHotkey = HotKey(
      key: PhysicalKeyboardKey.keyM,
      modifiers: [HotKeyModifier.meta, HotKeyModifier.shift],
      scope: HotKeyScope.system,
    );

    await hotKeyManager.register(
      toggleHotkey,
      keyDownHandler: (hotKey) async {
        bool isVisible = await windowManager.isVisible();
        if (isVisible) {
          await windowManager.hide();
        } else {
          await showWindow();
        }
      },
    );
  }
}
