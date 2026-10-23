import Cocoa
import FlutterMacOS
import AVFoundation
import ScreenCaptureKit
import CoreAudio

class AudioCaptureService: NSObject, FlutterStreamHandler {
  static let shared = AudioCaptureService()

  private var eventSink: FlutterEventSink?
  private var audioEngine = AVAudioEngine()
  private var isCapturing = false
  private var captureSystemAudio: Bool = true
  private var selectedDeviceUID: String? = nil
  private let mixer = PcmMixer()

  // ScreenCaptureKit system audio wrapper for macOS 13+ stored as Any? for deployment target compatibility
  private var systemAudioCapture: Any?

  func setup(binaryMessenger: FlutterBinaryMessenger) {
    let methodChannel = FlutterMethodChannel(
      name: "com.mitra.assistant/audio_capture_control",
      binaryMessenger: binaryMessenger
    )
    
    let eventChannel = FlutterEventChannel(
      name: "com.mitra.assistant/audio_stream",
      binaryMessenger: binaryMessenger
    )
    
    eventChannel.setStreamHandler(self)

    methodChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }
      switch call.method {
      case "startCapture":
        self.startCapture(result: result)
      case "stopCapture":
        self.stopCapture(result: result)
      case "isCapturing":
        result(self.isCapturing)
      case "listInputDevices":
        result(self.listInputDevices())
      case "setInputDevice":
        if let uid = call.arguments as? String {
          self.selectedDeviceUID = uid.isEmpty ? nil : uid
          if self.isCapturing {
            self.applySelectedInputDevice()
          }
          result(true)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected device UID string", details: nil))
        }
      case "checkMicrophonePermission":
        result(self.checkMicrophonePermission())
      case "requestMicrophonePermission":
        AVCaptureDevice.requestAccess(for: .audio) { granted in
          DispatchQueue.main.async {
            result(granted)
          }
        }
      case "openMicrophoneSettings":
        result(self.openMicrophoneSettings())
      case "setSystemAudioEnabled":
        if let enabled = call.arguments as? Bool {
          self.captureSystemAudio = enabled
          result(true)
        } else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Expected boolean", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // FlutterStreamHandler methods
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }

  private func checkMicrophonePermission() -> String {
    let status = AVCaptureDevice.authorizationStatus(for: .audio)
    switch status {
    case .authorized:
      return "authorized"
    case .denied:
      return "denied"
    case .restricted:
      return "restricted"
    case .notDetermined:
      return "notDetermined"
    @unknown default:
      return "unknown"
    }
  }

  private func openMicrophoneSettings() -> Bool {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
      return NSWorkspace.shared.open(url)
    }
    return false
  }

  private func startCapture(result: FlutterResult?) {
    guard !isCapturing else {
      result?(true)
      return
    }

    let status = AVCaptureDevice.authorizationStatus(for: .audio)
    switch status {
    case .authorized:
      DispatchQueue.main.async {
        self.performStartCapture(result: result)
      }
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
        guard let self = self else { return }
        DispatchQueue.main.async {
          if granted {
            self.performStartCapture(result: result)
          } else {
            result?(FlutterError(code: "PERMISSION_DENIED", message: "Microphone permission denied by user", details: nil))
          }
        }
      }
    case .denied:
      result?(FlutterError(code: "PERMISSION_DENIED", message: "Microphone permission is denied in System Settings. Please allow Microphone access in Privacy & Security -> Microphone.", details: nil))
    case .restricted:
      result?(FlutterError(code: "PERMISSION_RESTRICTED", message: "Microphone access is restricted on this device.", details: nil))
    @unknown default:
      result?(FlutterError(code: "PERMISSION_UNKNOWN", message: "Unknown microphone permission status.", details: nil))
    }
  }

  private func performStartCapture(result: FlutterResult?) {
    // Mic (left) and system audio (right) go out as ONE stereo stream. Sending each
    // source's chunks straight to Deepgram would interleave them in time (audio
    // at double speed) and break both transcription and speaker separation.
    mixer.start { [weak self] data in
      DispatchQueue.main.async { self?.eventSink?(FlutterStandardTypedData(bytes: data)) }
    }
    setupAudioEngine()
    if captureSystemAudio {
      if #available(macOS 13.0, *) {
        let systemAudio = SystemAudioCapture()
        systemAudio.start { [weak self] data in self?.mixer.push(.system, pcm: data) }
        self.systemAudioCapture = systemAudio
      }
    }
    isCapturing = true
    result?(true)
  }

  private func stopCapture(result: FlutterResult?) {
    if audioEngine.isRunning {
      audioEngine.stop()
      audioEngine.inputNode.removeTap(onBus: 0)
    }

    if #available(macOS 13.0, *) {
      (systemAudioCapture as? SystemAudioCapture)?.stop()
      systemAudioCapture = nil
    }

    mixer.stop()
    isCapturing = false
    result?(true)
  }

  private func setupAudioEngine() {
    // Switch device BEFORE reading the format: changing the input device can
    // change the hardware format, and installing a tap with a stale format
    // throws "Failed to create tap due to format mismatch".
    applySelectedInputDevice()

    let inputNode = audioEngine.inputNode
    let inputFormat = inputNode.outputFormat(forBus: 0)

    guard inputFormat.channelCount > 0 && inputFormat.sampleRate > 0 else {
      print("Invalid audio input node format: \(inputFormat)")
      return
    }

    // Rebuilds its converter from the actual buffer format, so a device or
    // sample-rate change while running doesn't feed mismatched audio.
    let converter = PcmConverter()

    inputNode.removeTap(onBus: 0)
    // format: nil lets the node supply its current format to the tap.
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] (buffer, time) in
      guard let self = self, let pcmData = converter.int16Mono16k(from: buffer) else { return }
      self.mixer.push(.mic, pcm: pcmData)
    }

    audioEngine.prepare()
    do {
      try audioEngine.start()
    } catch {
      print("Failed to start AVAudioEngine: \(error)")
    }
  }

  private func applySelectedInputDevice() {
    guard let uid = selectedDeviceUID, let audioUnit = audioEngine.inputNode.audioUnit else { return }
    var deviceID = getAudioObjectID(for: uid)
    if deviceID != kAudioObjectUnknown {
      let status = AudioUnitSetProperty(
        audioUnit,
        kAudioOutputUnitProperty_CurrentDevice,
        kAudioUnitScope_Global,
        0,
        &deviceID,
        UInt32(MemoryLayout<AudioObjectID>.size)
      )
      if status != noErr {
        print("Failed to select input device \(uid): \(status)")
        return
      }

      // Re-binding the device changes the hardware (input-side) format, but the
      // node's output side keeps its old rate (e.g. 44.1kHz speakers vs a 48kHz
      // mic). AVAudioEngine then fails to start with -10868 (format not
      // supported). Make the output side match the hardware.
      var hardwareFormat = audioEngine.inputNode.inputFormat(forBus: 0).streamDescription.pointee
      let fmtStatus = AudioUnitSetProperty(
        audioUnit,
        kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Output,
        1,
        &hardwareFormat,
        UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
      )
      if fmtStatus != noErr {
        print("Failed to match input node format to hardware: \(fmtStatus)")
      }
    }
  }

  private func getAudioObjectID(for uid: String) -> AudioObjectID {
    var deviceID = kAudioObjectUnknown
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else {
      return kAudioObjectUnknown
    }
    let deviceCount = Int(size) / MemoryLayout<AudioObjectID>.size
    var devices = [AudioObjectID](repeating: 0, count: deviceCount)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &devices) == noErr else {
      return kAudioObjectUnknown
    }

    for dev in devices {
      var uidAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceUID,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
      )
      var cfString: Unmanaged<CFString>? = nil
      var cfSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
      if AudioObjectGetPropertyData(dev, &uidAddress, 0, nil, &cfSize, &cfString) == noErr, let unmanagedStr = cfString {
        let str = unmanagedStr.takeRetainedValue() as String
        if str == uid {
          deviceID = dev
          break
        }
      }
    }
    return deviceID
  }

  private func listInputDevices() -> [[String: Any]] {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else {
      return []
    }
    let deviceCount = Int(size) / MemoryLayout<AudioObjectID>.size
    var devices = [AudioObjectID](repeating: 0, count: deviceCount)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &devices) == noErr else {
      return []
    }

    var defaultAddress = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultInputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var defaultInputID: AudioObjectID = kAudioObjectUnknown
    var defaultSize = UInt32(MemoryLayout<AudioObjectID>.size)
    AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &defaultAddress, 0, nil, &defaultSize, &defaultInputID)

    var result: [[String: Any]] = []

    for dev in devices {
      var streamAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyStreamConfiguration,
        mScope: kAudioDevicePropertyScopeInput,
        mElement: kAudioObjectPropertyElementMain
      )
      var streamSize: UInt32 = 0
      guard AudioObjectGetPropertyDataSize(dev, &streamAddress, 0, nil, &streamSize) == noErr, streamSize > 0 else {
        continue
      }
      let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: Int(streamSize))
      defer { bufferListPointer.deallocate() }
      guard AudioObjectGetPropertyData(dev, &streamAddress, 0, nil, &streamSize, bufferListPointer) == noErr else {
        continue
      }
      let buffers = UnsafeMutableAudioBufferListPointer(bufferListPointer)
      var inputChannels = 0
      for buf in buffers {
        inputChannels += Int(buf.mNumberChannels)
      }
      if inputChannels == 0 { continue }

      var nameAddress = AudioObjectPropertyAddress(
        mSelector: kAudioObjectPropertyName,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
      )
      var nameString: Unmanaged<CFString>? = nil
      var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
      AudioObjectGetPropertyData(dev, &nameAddress, 0, nil, &nameSize, &nameString)

      var uidAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceUID,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
      )
      var uidString: Unmanaged<CFString>? = nil
      var uidSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
      AudioObjectGetPropertyData(dev, &uidAddress, 0, nil, &uidSize, &uidString)

      let devName = nameString?.takeRetainedValue() as String? ?? "Audio Input"
      let devUID = uidString?.takeRetainedValue() as String? ?? "\(dev)"

      result.append([
        "id": devUID,
        "name": devName,
        "isDefault": (dev == defaultInputID)
      ])
    }

    return result
  }
}

// MARK: PcmConverter begin
/// Any PCM buffer -> 16 kHz mono Int16 bytes (what Deepgram expects). The
/// AVAudioConverter is rebuilt whenever the incoming format changes.
final class PcmConverter {
  private let target = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true)!
  private var converter: AVAudioConverter?
  private var sourceFormat: AVAudioFormat?

  func int16Mono16k(from buffer: AVAudioPCMBuffer) -> Data? {
    if converter == nil || sourceFormat != buffer.format {
      converter = AVAudioConverter(from: buffer.format, to: target)
      sourceFormat = buffer.format
    }
    guard let converter = converter else { return nil }

    let capacity = UInt32(Double(buffer.frameLength) * (16000.0 / buffer.format.sampleRate)) + 100
    guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return nil }

    var error: NSError?
    var consumed = false
    converter.convert(to: out, error: &error) { _, status in
      if consumed {
        status.pointee = .noDataNow
        return nil
      }
      consumed = true
      status.pointee = .haveData
      return buffer
    }
    guard error == nil, let ints = out.int16ChannelData, out.frameLength > 0 else { return nil }
    return Data(bytes: ints[0], count: Int(out.frameLength) * 2)
  }
}
// MARK: PcmConverter end

// MARK: PcmMixer begin
/// Combines microphone and system audio into ONE stereo stream, 16 kHz Int16,
/// interleaved: left = microphone ("you"), right = system audio (the call).
/// Keeping them on separate channels lets Deepgram transcribe each on its own,
/// so who spoke is known exactly instead of guessed from a mixed recording.
///
/// Channels must stay sample-aligned with real time. While BOTH sources are
/// delivering, only as many samples as both have are emitted (nothing is
/// padded, so neither channel is stretched). A source that has gone quiet for
/// 500 ms is treated as silent and its channel is filled with zeros. Backlog is
/// capped at 300 ms so latency cannot build up.
final class PcmMixer {
  enum Source { case mic, system }

  private let queue = DispatchQueue(label: "mitra.pcm.mixer")
  private var mic: [Int16] = []
  private var system: [Int16] = []
  private var lastMic = Date.distantPast
  private var lastSystem = Date.distantPast
  private var timer: DispatchSourceTimer?
  private var sink: ((Data) -> Void)?

  static let frameSamples = 1600 // 100 ms at 16 kHz, per channel
  static let maxBufferedSamples = 4800 // 300 ms
  static let inactiveAfter: TimeInterval = 0.5

  func start(sink: @escaping (Data) -> Void) {
    stop()
    queue.sync {
      self.sink = sink
      let t = DispatchSource.makeTimerSource(queue: queue)
      t.schedule(deadline: .now() + .milliseconds(100), repeating: .milliseconds(100))
      t.setEventHandler { [weak self] in self?.tick() }
      t.resume()
      timer = t
    }
  }

  func stop() {
    queue.sync {
      timer?.cancel()
      timer = nil
      sink = nil
      mic.removeAll()
      system.removeAll()
      lastMic = .distantPast
      lastSystem = .distantPast
    }
  }

  func push(_ source: Source, pcm: Data) {
    let samples = pcm.withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) }
    let now = Date()
    queue.async {
      switch source {
      case .mic:
        self.mic.append(contentsOf: samples)
        self.lastMic = now
      case .system:
        self.system.append(contentsOf: samples)
        self.lastSystem = now
      }
      if self.mic.count > PcmMixer.maxBufferedSamples { self.mic.removeFirst(self.mic.count - PcmMixer.maxBufferedSamples) }
      if self.system.count > PcmMixer.maxBufferedSamples { self.system.removeFirst(self.system.count - PcmMixer.maxBufferedSamples) }
    }
  }

  private func tick() {
    let now = Date()
    let micActive = now.timeIntervalSince(lastMic) < PcmMixer.inactiveAfter
    let sysActive = now.timeIntervalSince(lastSystem) < PcmMixer.inactiveAfter

    var n: Int
    if micActive && sysActive {
      n = min(mic.count, system.count) // wait for the slower source, never pad
    } else if micActive {
      n = mic.count
    } else if sysActive {
      n = system.count
    } else {
      n = max(mic.count, system.count) // both idle: flush what is left
    }
    n = min(n, PcmMixer.frameSamples)
    guard n > 0, let sink = sink else { return }

    var out = [Int16](repeating: 0, count: n * 2)
    for i in 0..<n {
      out[2 * i] = i < mic.count ? mic[i] : 0
      out[2 * i + 1] = i < system.count ? system[i] : 0
    }
    mic.removeFirst(min(n, mic.count))
    system.removeFirst(min(n, system.count))
    sink(out.withUnsafeBufferPointer { Data(buffer: $0) })
  }
}
// MARK: PcmMixer end

@available(macOS 13.0, *)
private class SystemAudioCapture {
  private var stream: SCStream?
  private var streamOutput: AudioStreamOutput?

  func start(onData: @escaping (Data) -> Void) {
    SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { [weak self] content, error in
      guard let self = self, let content = content, error == nil else { return }
      guard let display = content.displays.first else { return }

      let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
      let config = SCStreamConfiguration()
      config.capturesAudio = true
      config.excludesCurrentProcessAudio = true
      config.sampleRate = 16000
      config.channelCount = 1

      do {
        self.stream = SCStream(filter: filter, configuration: config, delegate: nil)
        let output = AudioStreamOutput(onAudioData: onData)
        self.streamOutput = output
        try self.stream?.addStreamOutput(output, type: .audio, sampleHandlerQueue: DispatchQueue.global(qos: .userInteractive))
        self.stream?.startCapture()
      } catch {
        print("Failed to start SCStream system audio capture: \(error)")
      }
    }
  }

  func stop() {
    stream?.stopCapture()
    stream = nil
    streamOutput = nil
  }
}

@available(macOS 13.0, *)
private class AudioStreamOutput: NSObject, SCStreamOutput {
  let onAudioData: (Data) -> Void

  init(onAudioData: @escaping (Data) -> Void) {
    self.onAudioData = onAudioData
  }

  private let converter = PcmConverter()

  func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
    guard type == .audio, CMSampleBufferDataIsReady(sampleBuffer) else { return }

    // ScreenCaptureKit audio is not guaranteed to be 16-bit integers (it is
    // typically 32-bit float, possibly planar). Read the real format and
    // convert, instead of forwarding raw bytes as if they were Int16.
    guard let desc = CMSampleBufferGetFormatDescription(sampleBuffer),
          var asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc)?.pointee,
          let format = AVAudioFormat(streamDescription: &asbd) else { return }
    let frames = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
    guard frames > 0, let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return }
    pcm.frameLength = frames
    guard CMSampleBufferCopyPCMDataIntoAudioBufferList(
      sampleBuffer, at: 0, frameCount: Int32(frames), into: pcm.mutableAudioBufferList
    ) == noErr else { return }

    if let data = converter.int16Mono16k(from: pcm) {
      onAudioData(data)
    }
  }
}


