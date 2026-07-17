class AudioDevice {
  final String id;
  final String name;
  final bool isDefault;

  AudioDevice({
    required this.id,
    required this.name,
    this.isDefault = false,
  });

  factory AudioDevice.fromMap(Map<String, dynamic> map) {
    return AudioDevice(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Unknown Microphone',
      isDefault: map['isDefault'] as bool? ?? false,
    );
  }
}
