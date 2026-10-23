import 'dart:typed_data';

/// Interleaved stereo 16-bit little-endian PCM -> mono, by adding the two
/// channels (clipped). Used when "separate my voice from the call" is off, so
/// the old single-stream behaviour (and single-channel billing) still works.
class PcmDownmix {
  static Uint8List stereoToMono(Uint8List stereo) {
    final frames = stereo.length ~/ 4;
    final out = Uint8List(frames * 2);
    final inView = ByteData.sublistView(stereo);
    final outView = ByteData.sublistView(out);
    for (var i = 0; i < frames; i++) {
      final sum = inView.getInt16(i * 4, Endian.little) + inView.getInt16(i * 4 + 2, Endian.little);
      outView.setInt16(i * 2, sum.clamp(-32768, 32767), Endian.little);
    }
    return out;
  }
}
