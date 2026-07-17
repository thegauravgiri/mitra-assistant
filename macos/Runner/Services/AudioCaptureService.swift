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
    setupAudioEngine()
    if captureSystemAudio {
      if #available(macOS 13.0, *) {
        let systemAudio = SystemAudioCapture()
        systemAudio.start(eventSink: self.eventSink)
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

    isCapturing = false
    result?(true)
  }

  private func setupAudioEngine() {
    let inputNode = audioEngine.inputNode
    let inputFormat = inputNode.outputFormat(forBus: 0)

    guard inputFormat.channelCount > 0 && inputFormat.sampleRate > 0 else {
      print("Invalid audio input node format: \(inputFormat)")
      return
    }

    applySelectedInputDevice()

    // Target format: 16kHz Mono 16-bit PCM
    guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: true) else {
      return
    }

    guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
      return
    }

    inputNode.removeTap(onBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] (buffer, time) in
      guard let self = self, let eventSink = self.eventSink else { return }

      let capacity = UInt32(Double(buffer.frameLength) * (16000.0 / inputFormat.sampleRate)) + 100
      guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

      var error: NSError?
      var allSamplesProcessed = false

      converter.convert(to: convertedBuffer, error: &error) { packetCount, outStatus in
        if allSamplesProcessed {
          outStatus.pointee = .noDataNow
          return nil
        }
        outStatus.pointee = .haveData
        allSamplesProcessed = true
        return buffer
      }

      if let pcmData = self.bufferToData(buffer: convertedBuffer) {
        DispatchQueue.main.async {
          eventSink(FlutterStandardTypedData(bytes: pcmData))
        }
      }
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
      AudioUnitSetProperty(
        audioUnit,
        kAudioOutputUnitProperty_CurrentDevice,
        kAudioUnitScope_Global,
        0,
        &deviceID,
        UInt32(MemoryLayout<AudioObjectID>.size)
      )
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

  private func bufferToData(buffer: AVAudioPCMBuffer) -> Data? {
    let channelCount = Int(buffer.format.channelCount)
    let length = Int(buffer.frameLength) * channelCount * 2
    guard let int16Data = buffer.int16ChannelData else { return nil }
    return Data(bytes: int16Data[0], count: length)
  }
}

@available(macOS 13.0, *)
private class SystemAudioCapture {
  private var stream: SCStream?
  private var streamOutput: AudioStreamOutput?

  func start(eventSink: FlutterEventSink?) {
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
        let output = AudioStreamOutput(onAudioData: { data in
          guard let eventSink = eventSink else { return }
          DispatchQueue.main.async {
            eventSink(FlutterStandardTypedData(bytes: data))
          }
        })
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

  func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
    guard type == .audio, CMSampleBufferDataIsReady(sampleBuffer) else { return }
    guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }

    var lengthAtOffset = 0
    var totalLength = 0
    var dataPointer: UnsafeMutablePointer<Int8>?

    if CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: &lengthAtOffset, totalLengthOut: &totalLength, dataPointerOut: &dataPointer) == kCMBlockBufferNoErr {
      if let dataPointer = dataPointer {
        let data = Data(bytes: dataPointer, count: totalLength)
        onAudioData(data)
      }
    }
  }
}


