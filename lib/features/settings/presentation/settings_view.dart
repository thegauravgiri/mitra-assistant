import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_providers.dart';
import '../../audio/providers/audio_providers.dart';
import '../../overlay/data/window_control_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/widgets/app_text_field.dart';

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

    if (_deepgramController.text != settings.deepgramApiKey) {
      _deepgramController.text = settings.deepgramApiKey;
    }
    if (_geminiController.text != settings.geminiApiKey) {
      _geminiController.text = settings.geminiApiKey;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: API Credentials Card
          _SettingsCard(
            title: 'API Credentials',
            icon: Icons.key_rounded,
            child: Column(
              children: [
                AppTextField(
                  controller: _deepgramController,
                  labelText: 'Deepgram API Key (Transcription)',
                  hintText: 'Enter your Deepgram key...',
                  obscureText: true,
                  onChanged: (val) {
                    ref.read(settingsNotifierProvider.notifier).updateDeepgramApiKey(val);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _geminiController,
                  labelText: 'Gemini API Key (AI Context Engine)',
                  hintText: 'Enter your Gemini key...',
                  obscureText: true,
                  onChanged: (val) {
                    ref.read(settingsNotifierProvider.notifier).updateGeminiApiKey(val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Section 2: Audio Configuration Card
          _SettingsCard(
            title: 'Audio Settings',
            icon: Icons.mic_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Input Microphone:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 14, color: AppTheme.primaryAccent),
                      tooltip: 'Refresh Audio Devices',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        ref.read(audioNotifierProvider.notifier).refreshDevices();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundDark,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: audioState.availableDevices.any((d) => d.id == audioState.selectedDeviceId)
                          ? audioState.selectedDeviceId
                          : (audioState.availableDevices.isNotEmpty ? audioState.availableDevices.first.id : null),
                      hint: const Text('Default System Microphone', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      dropdownColor: AppTheme.cardBackground,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
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
                          ref.read(settingsNotifierProvider.notifier).updateSelectedAudioDevice(val);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    title: const Text('Capture System Audio', style: TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Transcribes speaker audio from meetings (ScreenCaptureKit)', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                    value: audioState.captureSystemAudio,
                    activeTrackColor: AppTheme.primaryAccent,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      ref.read(audioNotifierProvider.notifier).toggleSystemAudio(val);
                      ref.read(settingsNotifierProvider.notifier).updateCaptureSystemAudio(val);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Section 3: AI & Privacy Card
          _SettingsCard(
            title: 'AI Copilot & Privacy',
            icon: Icons.tune_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Analysis Frequency:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        'Every ${settings.analysisIntervalSec}s',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryAccent),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: settings.analysisIntervalSec.toDouble(),
                  min: 5,
                  max: 30,
                  divisions: 5,
                  activeColor: AppTheme.primaryAccent,
                  inactiveColor: AppTheme.borderSubtle,
                  onChanged: (val) {
                    ref.read(settingsNotifierProvider.notifier).updateAnalysisIntervalSec(val.toInt());
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    title: const Text('Screen-Share Protection', style: TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Hides overlay window during screen share (NSWindow sharingType)', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
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
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Section 4: Global Shortcuts Card
          _SettingsCard(
            title: 'Global Shortcuts',
            icon: Icons.keyboard_rounded,
            child: Column(
              children: const [
                _ShortcutRow(shortcut: '⌘ + Shift + H', description: 'Panic Hide (Instant conceal window)'),
                SizedBox(height: AppSpacing.sm),
                _ShortcutRow(shortcut: '⌘ + Shift + M', description: 'Toggle Overlay Window visibility'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SettingsCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppTheme.backgroundPureDark.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
              border: const Border(bottom: BorderSide(color: AppTheme.borderSubtle)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 14, color: AppTheme.primaryAccent),
                const SizedBox(width: AppSpacing.xs + 2),
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: child,
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
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs + 1),
          decoration: BoxDecoration(
            color: AppTheme.backgroundDark,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppTheme.primaryAccent.withValues(alpha: 0.4)),
          ),
          child: Text(
            shortcut,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryAccent,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            description,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}
