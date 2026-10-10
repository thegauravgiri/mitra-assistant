#ifndef RUNNER_AUDIO_CAPTURE_CHANNEL_H_
#define RUNNER_AUDIO_CAPTURE_CHANNEL_H_

#include <flutter/binary_messenger.h>
#include <flutter/event_channel.h>
#include <flutter/event_sink.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <mmdeviceapi.h>
#include <audioclient.h>

#include <atomic>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

class AudioCaptureChannel {
 public:
  static void RegisterWithMessenger(flutter::BinaryMessenger* messenger);

  AudioCaptureChannel();
  ~AudioCaptureChannel();

  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListen(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events);

  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnCancel(
      const flutter::EncodableValue* arguments);

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  bool StartCapture();
  bool StopCapture();
  bool IsCapturing() const;
  flutter::EncodableList ListInputDevices();
  bool SetInputDevice(const std::string& device_id);
  void SetSystemAudioEnabled(bool enabled);

  void CaptureWorkerThread();

  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
  std::mutex sink_mutex_;

  std::atomic<bool> is_capturing_{false};
  std::atomic<bool> capture_system_audio_{true};
  std::string selected_device_id_;
  std::mutex device_mutex_;

  std::thread capture_thread_;
};

#endif  // RUNNER_AUDIO_CAPTURE_CHANNEL_H_
