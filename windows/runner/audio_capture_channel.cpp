#include "audio_capture_channel.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <functiondiscoverykeys_devpkey.h>
#include <shellapi.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <iostream>

namespace {

constexpr char kControlChannelName[] = "com.mitra.assistant/audio_capture_control";
constexpr char kStreamChannelName[] = "com.mitra.assistant/audio_stream";
constexpr int kTargetSampleRate = 16000;

// Convert wide string to UTF-8 std::string
std::string WideToUtf8(const std::wstring& wstr) {
  if (wstr.empty()) return std::string();
  int size_needed = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), NULL, 0, NULL, NULL);
  std::string strTo(size_needed, 0);
  WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), &strTo[0], size_needed, NULL, NULL);
  return strTo;
}

// Convert UTF-8 std::string to wide string
std::wstring Utf8ToWide(const std::string& str) {
  if (str.empty()) return std::wstring();
  int size_needed = MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), NULL, 0);
  std::wstring wstrTo(size_needed, 0);
  MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), &wstrTo[0], size_needed);
  return wstrTo;
}

// Resamples mono float buffer to 16kHz mono int16_t PCM bytes
std::vector<uint8_t> ResampleTo16kMonoPcm(const float* mono_samples, int num_samples, int in_sample_rate) {
  if (num_samples <= 0 || in_sample_rate <= 0) return {};

  double ratio = static_cast<double>(in_sample_rate) / static_cast<double>(kTargetSampleRate);
  int out_samples_count = static_cast<int>(std::floor(num_samples / ratio));
  if (out_samples_count <= 0) return {};

  std::vector<uint8_t> out_bytes;
  out_bytes.reserve(out_samples_count * sizeof(int16_t));

  for (int i = 0; i < out_samples_count; ++i) {
    double src_idx = i * ratio;
    int idx0 = static_cast<int>(src_idx);
    int idx1 = std::min(idx0 + 1, num_samples - 1);
    double frac = src_idx - idx0;

    float sample = static_cast<float>((1.0 - frac) * mono_samples[idx0] + frac * mono_samples[idx1]);
    sample = std::max(-1.0f, std::min(1.0f, sample));

    int16_t pcm_sample = static_cast<int16_t>(sample * 32767.0f);
    out_bytes.push_back(static_cast<uint8_t>(pcm_sample & 0xFF));
    out_bytes.push_back(static_cast<uint8_t>((pcm_sample >> 8) & 0xFF));
  }

  return out_bytes;
}

// Sums two 16-bit little-endian PCM buffers with clipping. Output length is the
// longer of the two; the shorter stream is treated as silence past its end.
std::vector<uint8_t> MixPcm16(const std::vector<uint8_t>& a, const std::vector<uint8_t>& b) {
  if (a.empty()) return b;
  if (b.empty()) return a;

  size_t samples_a = a.size() / 2;
  size_t samples_b = b.size() / 2;
  size_t n = std::max(samples_a, samples_b);

  std::vector<uint8_t> out;
  out.reserve(n * 2);
  for (size_t i = 0; i < n; ++i) {
    int32_t sa = (i < samples_a)
                     ? static_cast<int16_t>(static_cast<uint16_t>(a[2 * i]) | (static_cast<uint16_t>(a[2 * i + 1]) << 8))
                     : 0;
    int32_t sb = (i < samples_b)
                     ? static_cast<int16_t>(static_cast<uint16_t>(b[2 * i]) | (static_cast<uint16_t>(b[2 * i + 1]) << 8))
                     : 0;
    int32_t mixed = std::max(-32768, std::min(32767, sa + sb));
    int16_t pcm = static_cast<int16_t>(mixed);
    out.push_back(static_cast<uint8_t>(pcm & 0xFF));
    out.push_back(static_cast<uint8_t>((pcm >> 8) & 0xFF));
  }
  return out;
}

// Converts multi-channel WASAPI buffer to mono float
std::vector<float> BufferToMonoFloats(const BYTE* data, UINT32 num_frames, const WAVEFORMATEX* pwfx) {
  std::vector<float> mono(num_frames, 0.0f);
  int channels = pwfx->nChannels;

  if (pwfx->wFormatTag == WAVE_FORMAT_IEEE_FLOAT ||
      (pwfx->wFormatTag == WAVE_FORMAT_EXTENSIBLE &&
       reinterpret_cast<const WAVEFORMATEXTENSIBLE*>(pwfx)->SubFormat == KSDATAFORMAT_SUBTYPE_IEEE_FLOAT)) {
    const float* f_data = reinterpret_cast<const float*>(data);
    for (UINT32 i = 0; i < num_frames; ++i) {
      float sum = 0.0f;
      for (int c = 0; c < channels; ++c) {
        sum += f_data[i * channels + c];
      }
      mono[i] = sum / static_cast<float>(channels);
    }
  } else if (pwfx->wBitsPerSample == 16) {
    const int16_t* s_data = reinterpret_cast<const int16_t*>(data);
    for (UINT32 i = 0; i < num_frames; ++i) {
      float sum = 0.0f;
      for (int c = 0; c < channels; ++c) {
        sum += static_cast<float>(s_data[i * channels + c]) / 32768.0f;
      }
      mono[i] = sum / static_cast<float>(channels);
    }
  }

  return mono;
}

class AudioStreamHandler : public flutter::StreamHandler<flutter::EncodableValue> {
 public:
  explicit AudioStreamHandler(std::shared_ptr<AudioCaptureChannel> channel)
      : channel_(std::move(channel)) {}

 protected:
  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnListenInternal(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) override {
    return channel_->OnListen(arguments, std::move(events));
  }

  std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> OnCancelInternal(
      const flutter::EncodableValue* arguments) override {
    return channel_->OnCancel(arguments);
  }

 private:
  std::shared_ptr<AudioCaptureChannel> channel_;
};

}  // namespace

void AudioCaptureChannel::RegisterWithMessenger(flutter::BinaryMessenger* messenger) {
  auto instance = std::make_shared<AudioCaptureChannel>();

  // Method Channel for Control
  auto control_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, kControlChannelName, &flutter::StandardMethodCodec::GetInstance());

  control_channel->SetMethodCallHandler(
      [instance](const flutter::MethodCall<flutter::EncodableValue>& call,
                 std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        instance->HandleMethodCall(call, std::move(result));
      });

  // Event Channel for Audio Stream
  auto stream_channel = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      messenger, kStreamChannelName, &flutter::StandardMethodCodec::GetInstance());

  stream_channel->SetStreamHandler(std::make_unique<AudioStreamHandler>(instance));
}

AudioCaptureChannel::AudioCaptureChannel() = default;

AudioCaptureChannel::~AudioCaptureChannel() {
  StopCapture();
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
AudioCaptureChannel::OnListen(
    const flutter::EncodableValue* arguments,
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) {
  std::lock_guard<std::mutex> lock(sink_mutex_);
  event_sink_ = std::move(events);
  return nullptr;
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
AudioCaptureChannel::OnCancel(const flutter::EncodableValue* arguments) {
  std::lock_guard<std::mutex> lock(sink_mutex_);
  event_sink_.reset();
  return nullptr;
}

void AudioCaptureChannel::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();

  if (method == "startCapture") {
    bool ok = StartCapture();
    result->Success(flutter::EncodableValue(ok));
  } else if (method == "stopCapture") {
    bool ok = StopCapture();
    result->Success(flutter::EncodableValue(ok));
  } else if (method == "isCapturing") {
    result->Success(flutter::EncodableValue(IsCapturing()));
  } else if (method == "listInputDevices") {
    result->Success(flutter::EncodableValue(ListInputDevices()));
  } else if (method == "setInputDevice") {
    std::string device_id = "";
    if (call.arguments() && std::holds_alternative<std::string>(*call.arguments())) {
      device_id = std::get<std::string>(*call.arguments());
    }
    bool ok = SetInputDevice(device_id);
    result->Success(flutter::EncodableValue(ok));
  } else if (method == "setSystemAudioEnabled") {
    bool enabled = true;
    if (call.arguments() && std::holds_alternative<bool>(*call.arguments())) {
      enabled = std::get<bool>(*call.arguments());
    }
    SetSystemAudioEnabled(enabled);
    result->Success(flutter::EncodableValue(true));
  } else if (method == "checkMicrophonePermission") {
    // Windows has no per-app runtime mic prompt like macOS/iOS; capture either
    // works or fails at the WASAPI layer. Reported as always granted so the
    // shared Dart permission flow stays simple. Do not trust this cross-platform.
    result->Success(flutter::EncodableValue("granted"));
  } else if (method == "requestMicrophonePermission") {
    result->Success(flutter::EncodableValue(true));
  } else if (method == "openMicrophoneSettings") {
    ShellExecuteW(NULL, L"open", L"ms-settings:privacy-microphone", NULL, NULL, SW_SHOWNORMAL);
    result->Success(flutter::EncodableValue(true));
  } else {
    result->NotImplemented();
  }
}

bool AudioCaptureChannel::StartCapture() {
  if (is_capturing_.load()) return true;

  is_capturing_.store(true);
  if (capture_thread_.joinable()) {
    capture_thread_.join();
  }
  capture_thread_ = std::thread(&AudioCaptureChannel::CaptureWorkerThread, this);
  return true;
}

bool AudioCaptureChannel::StopCapture() {
  if (!is_capturing_.load()) return true;

  is_capturing_.store(false);
  if (capture_thread_.joinable()) {
    capture_thread_.join();
  }
  return true;
}

bool AudioCaptureChannel::IsCapturing() const {
  return is_capturing_.load();
}

bool AudioCaptureChannel::SetInputDevice(const std::string& device_id) {
  std::lock_guard<std::mutex> lock(device_mutex_);
  selected_device_id_ = device_id;
  return true;
}

void AudioCaptureChannel::SetSystemAudioEnabled(bool enabled) {
  capture_system_audio_.store(enabled);
}

flutter::EncodableList AudioCaptureChannel::ListInputDevices() {
  flutter::EncodableList device_list;
  HRESULT hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);

  IMMDeviceEnumerator* enumerator = nullptr;
  hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), NULL, CLSCTX_ALL,
                        __uuidof(IMMDeviceEnumerator), (void**)&enumerator);
  if (FAILED(hr) || !enumerator) {
    CoUninitialize();
    return device_list;
  }

  IMMDevice* default_device = nullptr;
  LPWSTR default_id_str = nullptr;
  if (SUCCEEDED(enumerator->GetDefaultAudioEndpoint(eCapture, eConsole, &default_device))) {
    default_device->GetId(&default_id_str);
  }

  IMMDeviceCollection* collection = nullptr;
  if (SUCCEEDED(enumerator->EnumAudioEndpoints(eCapture, DEVICE_STATE_ACTIVE, &collection))) {
    UINT count = 0;
    collection->GetCount(&count);
    for (UINT i = 0; i < count; ++i) {
      IMMDevice* endpoint = nullptr;
      if (SUCCEEDED(collection->Item(i, &endpoint))) {
        LPWSTR id_str = nullptr;
        endpoint->GetId(&id_str);

        IPropertyStore* props = nullptr;
        std::wstring friendly_name = L"Microphone";
        if (SUCCEEDED(endpoint->OpenPropertyStore(STGM_READ, &props))) {
          PROPVARIANT var_name;
          PropVariantInit(&var_name);
          if (SUCCEEDED(props->GetValue(PKEY_Device_FriendlyName, &var_name))) {
            if (var_name.vt == VT_LPWSTR && var_name.pwszVal) {
              friendly_name = var_name.pwszVal;
            }
            PropVariantClear(&var_name);
          }
          props->Release();
        }

        bool is_default = (default_id_str && id_str && wcscmp(default_id_str, id_str) == 0);

        flutter::EncodableMap map;
        map[flutter::EncodableValue("id")] = flutter::EncodableValue(WideToUtf8(id_str ? id_str : L""));
        map[flutter::EncodableValue("name")] = flutter::EncodableValue(WideToUtf8(friendly_name));
        map[flutter::EncodableValue("isDefault")] = flutter::EncodableValue(is_default);
        device_list.push_back(flutter::EncodableValue(map));

        if (id_str) CoTaskMemFree(id_str);
        endpoint->Release();
      }
    }
    collection->Release();
  }

  if (default_id_str) CoTaskMemFree(default_id_str);
  if (default_device) default_device->Release();
  enumerator->Release();
  CoUninitialize();

  return device_list;
}

void AudioCaptureChannel::CaptureWorkerThread() {
  HRESULT co_hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
  if (FAILED(co_hr) && co_hr != RPC_E_CHANGED_MODE) {
    std::cerr << "[mitra] CoInitializeEx failed: 0x" << std::hex << co_hr << std::dec << std::endl;
    return;
  }

  IMMDeviceEnumerator* enumerator = nullptr;
  HRESULT hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), NULL, CLSCTX_ALL,
                                __uuidof(IMMDeviceEnumerator), (void**)&enumerator);
  if (FAILED(hr) || !enumerator) {
    std::cerr << "[mitra] MMDeviceEnumerator creation failed: 0x" << std::hex << hr << std::dec << std::endl;
    CoUninitialize();
    return;
  }

  // 1. Microphone Setup
  IMMDevice* mic_device = nullptr;
  {
    std::lock_guard<std::mutex> lock(device_mutex_);
    if (!selected_device_id_.empty()) {
      std::wstring wid = Utf8ToWide(selected_device_id_);
      enumerator->GetDevice(wid.c_str(), &mic_device);
    }
  }
  if (!mic_device) {
    enumerator->GetDefaultAudioEndpoint(eCapture, eConsole, &mic_device);
  }

  IAudioClient* mic_client = nullptr;
  IAudioCaptureClient* mic_capture = nullptr;
  WAVEFORMATEX* mic_wfx = nullptr;

  if (mic_device && SUCCEEDED(mic_device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, NULL, (void**)&mic_client))) {
    if (SUCCEEDED(mic_client->GetMixFormat(&mic_wfx))) {
      hr = mic_client->Initialize(AUDCLNT_SHAREMODE_SHARED, 0, 10000000, 0, mic_wfx, NULL);
      if (SUCCEEDED(hr)) {
        mic_client->GetService(__uuidof(IAudioCaptureClient), (void**)&mic_capture);
        if (mic_capture) mic_client->Start();
      } else {
        std::cerr << "[mitra] Microphone IAudioClient::Initialize failed: 0x" << std::hex << hr << std::dec << std::endl;
      }
    }
  } else {
    std::cerr << "[mitra] No capture device available for microphone." << std::endl;
  }

  // 2. Loopback Audio (Speaker Output) Setup
  IMMDevice* loopback_device = nullptr;
  IAudioClient* loopback_client = nullptr;
  IAudioCaptureClient* loopback_capture = nullptr;
  WAVEFORMATEX* loopback_wfx = nullptr;

  if (SUCCEEDED(enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &loopback_device))) {
    if (SUCCEEDED(loopback_device->Activate(__uuidof(IAudioClient), CLSCTX_ALL, NULL, (void**)&loopback_client))) {
      if (SUCCEEDED(loopback_client->GetMixFormat(&loopback_wfx))) {
        hr = loopback_client->Initialize(
            AUDCLNT_SHAREMODE_SHARED, AUDCLNT_STREAMFLAGS_LOOPBACK, 10000000, 0, loopback_wfx, NULL);
        if (SUCCEEDED(hr)) {
          loopback_client->GetService(__uuidof(IAudioCaptureClient), (void**)&loopback_capture);
          if (loopback_capture) loopback_client->Start();
        }
      }
    }
  }

  // 3. Audio Capture Loop
  while (is_capturing_.load()) {
    std::vector<float> mic_floats;
    std::vector<float> loop_floats;

    // Read mic packet
    if (mic_capture && mic_wfx) {
      UINT32 packet_length = 0;
      while (SUCCEEDED(mic_capture->GetNextPacketSize(&packet_length)) && packet_length > 0) {
        BYTE* p_data = nullptr;
        UINT32 num_frames = 0;
        DWORD flags = 0;
        if (SUCCEEDED(mic_capture->GetBuffer(&p_data, &num_frames, &flags, NULL, NULL))) {
          if (!(flags & AUDCLNT_BUFFERFLAGS_SILENT) && p_data) {
            auto mono = BufferToMonoFloats(p_data, num_frames, mic_wfx);
            mic_floats.insert(mic_floats.end(), mono.begin(), mono.end());
          }
          mic_capture->ReleaseBuffer(num_frames);
        }
      }
    }

    // Read loopback packet
    if (capture_system_audio_.load() && loopback_capture && loopback_wfx) {
      UINT32 packet_length = 0;
      while (SUCCEEDED(loopback_capture->GetNextPacketSize(&packet_length)) && packet_length > 0) {
        BYTE* p_data = nullptr;
        UINT32 num_frames = 0;
        DWORD flags = 0;
        if (SUCCEEDED(loopback_capture->GetBuffer(&p_data, &num_frames, &flags, NULL, NULL))) {
          if (!(flags & AUDCLNT_BUFFERFLAGS_SILENT) && p_data) {
            auto mono = BufferToMonoFloats(p_data, num_frames, loopback_wfx);
            loop_floats.insert(loop_floats.end(), mono.begin(), mono.end());
          }
          loopback_capture->ReleaseBuffer(num_frames);
        }
      }
    }

    // Mix & Resample: capture mic and system audio independently, then sum so
    // both the local speaker and remote participants are present in the stream.
    std::vector<uint8_t> mic_pcm;
    std::vector<uint8_t> loop_pcm;
    if (!mic_floats.empty() && mic_wfx) {
      mic_pcm = ResampleTo16kMonoPcm(mic_floats.data(), static_cast<int>(mic_floats.size()), mic_wfx->nSamplesPerSec);
    }
    if (!loop_floats.empty() && loopback_wfx) {
      loop_pcm = ResampleTo16kMonoPcm(loop_floats.data(), static_cast<int>(loop_floats.size()), loopback_wfx->nSamplesPerSec);
    }
    std::vector<uint8_t> pcm_chunk = MixPcm16(mic_pcm, loop_pcm);

    if (!pcm_chunk.empty()) {
      std::lock_guard<std::mutex> lock(sink_mutex_);
      if (event_sink_) {
        event_sink_->Success(flutter::EncodableValue(pcm_chunk));
      }
    }

    std::this_thread::sleep_for(std::chrono::milliseconds(25));
  }

  // Cleanup
  if (mic_client) {
    mic_client->Stop();
    if (mic_capture) mic_capture->Release();
    mic_client->Release();
  }
  if (mic_wfx) CoTaskMemFree(mic_wfx);
  if (mic_device) mic_device->Release();

  if (loopback_client) {
    loopback_client->Stop();
    if (loopback_capture) loopback_capture->Release();
    loopback_client->Release();
  }
  if (loopback_wfx) CoTaskMemFree(loopback_wfx);
  if (loopback_device) loopback_device->Release();

  enumerator->Release();
  CoUninitialize();
}
