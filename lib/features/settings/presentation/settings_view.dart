import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_providers.dart';
import '../../audio/providers/audio_providers.dart';
import '../../overlay/data/window_control_service.dart';
import '../../../core/theme/app_theme.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  late TextEditingController _deepgramController;
  late TextEditingController _geminiController;
  bool _screenProtectionEnabled = true;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsNotifierProvider);
    _deepgramController = TextEditingController(text: settings.deepgramApiKey);
    _geminiController = TextEditingController(text: settings.geminiApiKey);
  }

  @override
  void dispose() {
    _deepgramController.dispose();
    _geminiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsNotifierProvider);
    final audioState = ref.watch(audioNotifierProvider);

    // Keep controller text updated if changed from provider
    if (_deepgramController.text != settings.deepgramApiKey) {
      _deepgramController.text = settings.deepgramApiKey;
    }
    if (_geminiController.text != settings.geminiApiKey) {
      _geminiController.text = settings.geminiApiKey;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'API Credentials',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _deepgramController,
            obscureText: true,
            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Deepgram API Key (Transcription)',
              labelStyle: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
              filled: true,
              fillColor: AppTheme.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.borderSubtle),
              ),
            ),
            onChanged: (val) {
              ref
                  .read(settingsNotifierProvider.notifier)
                  .updateDeepgramApiKey(val);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _geminiController,
            obscureText: true,
            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'Gemini API Key (AI Context)',
              labelStyle: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
              filled: true,
              fillColor: AppTheme.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.borderSubtle),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppTheme.borderSubtle),
              ),
            ),
            onChanged: (val) {
              ref
                  .read(settingsNotifierProvider.notifier)
                  .updateGeminiApiKey(val);
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Audio Sources',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),

          // Microphone Input Device Dropdown
          Row(
            children: [
              const Icon(
                Icons.mic_rounded,
                size: 16,
                color: AppTheme.primaryAccent,
              ),
              const SizedBox(width: 8),
              const Text(
                'Input Mic:',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 14,
                  color: AppTheme.textMuted,
                ),
                tooltip: 'Refresh Audio Devices',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  ref.read(audioNotifierProvider.notifier).refreshDevices();
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value:
                    audioState.availableDevices.any(
                      (d) => d.id == audioState.selectedDeviceId,
                    )
                    ? audioState.selectedDeviceId
                    : (audioState.availableDevices.isNotEmpty
                          ? audioState.availableDevices.first.id
                          : null),
                hint: const Text(
                  'Default System Microphone',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                dropdownColor: AppTheme.cardBackground,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textPrimary,
                ),
                items: audioState.availableDevices.map((device) {
                  return DropdownMenuItem<String>(
                    value: device.id,
                    child: Text(
                      '${device.name}${device.isDefault ? " (Default)" : ""}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    ref.read(audioNotifierProvider.notifier).selectDevice(val);
                    ref
                        .read(settingsNotifierProvider.notifier)
                        .updateSelectedAudioDevice(val);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // System Audio Switch
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              title: const Text(
                'Capture System Audio',
                style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
              ),
              subtitle: const Text(
                'Transcribes speaker audio from meetings (ScreenCaptureKit)',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              value: audioState.captureSystemAudio,
              activeTrackColor: AppTheme.primaryAccent,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) {
                ref.read(audioNotifierProvider.notifier).toggleSystemAudio(val);
                ref
                    .read(settingsNotifierProvider.notifier)
                    .updateCaptureSystemAudio(val);
              },
            ),
          ),

          const SizedBox(height: 16),
          const Text(
            'AI Copilot Frequency',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Interval: ${settings.analysisIntervalSec} seconds',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          Slider(
            value: settings.analysisIntervalSec.toDouble(),
            min: 5,
            max: 30,
            divisions: 5,
            activeColor: AppTheme.primaryAccent,
            onChanged: (val) {
              ref
                  .read(settingsNotifierProvider.notifier)
                  .updateAnalysisIntervalSec(val.toInt());
            },
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.transparent,
            child: SwitchListTile(
              title: const Text(
                'Screen-Share Protection',
                style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
              ),
              subtitle: const Text(
                'Hides overlay window during screen share (NSWindow sharingType)',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              value: _screenProtectionEnabled,
              activeTrackColor: AppTheme.primaryAccent,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) async {
                setState(() {
                  _screenProtectionEnabled = val;
                });
                if (val) {
                  await WindowControlService.instance.enableScreenProtection();
                } else {
                  await WindowControlService.instance.disableScreenProtection();
                }
              },
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.borderSubtle),
          const SizedBox(height: 8),
          const Text(
            'Global Shortcuts',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          _ShortcutRow(
            shortcut: '⌘ + Shift + H',
            description: 'Panic Hide (Instant conceal)',
          ),
          const SizedBox(height: 6),
          _ShortcutRow(
            shortcut: '⌘ + Shift + M',
            description: 'Toggle Overlay Window',
          ),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final String shortcut;
  final String description;

  const _ShortcutRow({required this.shortcut, required this.description});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppTheme.borderSubtle),
          ),
          child: Text(
            shortcut,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryAccent,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            description,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}
