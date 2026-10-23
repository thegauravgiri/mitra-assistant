import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import '../../../core/constants/app_constants.dart';

enum WindowShape { zen, compact, workspace }

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
    await enableScreenProtection();
  }

  Offset? _zenPosition;

  static const Size zenSize = Size(420, 680);
  static const Size compactSize = Size(380, 56);
  static const Size workspaceSize = Size(1100, 760);

  /// Resizes the single app window for a UI mode. [remember] stores the
  /// current position before leaving a zen shape so it can be restored.
  /// Screen protection is a property of the window and survives resizing; it
  /// is re-asserted anyway as a safety net.
  Future<void> applyShellMode(WindowShape shape, {bool remember = true}) async {
    if (shape == WindowShape.workspace) {
      if (remember) _zenPosition = await windowManager.getPosition();
      await windowManager.setMinimumSize(const Size(900, 600));
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setSize(workspaceSize);
      await windowManager.center();
    } else {
      await windowManager.setMinimumSize(const Size(320, 200));
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSize(shape == WindowShape.compact ? compactSize : zenSize);
      final pos = _zenPosition;
      if (pos != null) await windowManager.setPosition(pos);
    }
    await enableScreenProtection();
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
    final primaryModifier =
        Platform.isMacOS ? HotKeyModifier.meta : HotKeyModifier.control;

    // Panic Hide: Command/Control + Shift + H
    HotKey panicHotkey = HotKey(
      key: PhysicalKeyboardKey.keyH,
      modifiers: [primaryModifier, HotKeyModifier.shift],
      scope: HotKeyScope.system,
    );

    await hotKeyManager.register(
      panicHotkey,
      keyDownHandler: (hotKey) async {
        await panicHide();
      },
    );

    // Toggle Overlay: Command/Control + Shift + M
    HotKey toggleHotkey = HotKey(
      key: PhysicalKeyboardKey.keyM,
      modifiers: [primaryModifier, HotKeyModifier.shift],
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
