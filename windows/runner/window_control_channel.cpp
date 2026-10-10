#include "window_control_channel.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#ifndef WDA_EXCLUDEFROMCAPTURE
#define WDA_EXCLUDEFROMCAPTURE 0x00000011
#endif

namespace {

constexpr char kChannelName[] = "com.mitra.assistant/window_control";

}  // namespace

void WindowControlChannel::RegisterWithMessenger(flutter::BinaryMessenger* messenger,
                                                HWND window_handle) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, kChannelName, &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [window_handle](const flutter::MethodCall<flutter::EncodableValue>& method_call,
                      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const std::string& method_name = method_call.method_name();

        if (method_name == "setSharingTypeNone") {
          // Exclude window from screen capture / screen sharing (Zoom, Meet, Teams, OBS)
          BOOL success = SetWindowDisplayAffinity(window_handle, WDA_EXCLUDEFROMCAPTURE);
          if (!success) {
            // Fallback for older Windows 10 versions: WDA_MONITOR (0x00000001)
            success = SetWindowDisplayAffinity(window_handle, WDA_MONITOR);
          }
          result->Success(flutter::EncodableValue(success != FALSE));
        } else if (method_name == "setSharingTypeReadWrite") {
          // Re-enable window capture
          BOOL success = SetWindowDisplayAffinity(window_handle, WDA_NONE);
          result->Success(flutter::EncodableValue(success != FALSE));
        } else if (method_name == "panicHide") {
          ShowWindow(window_handle, SW_HIDE);
          result->Success(flutter::EncodableValue(true));
        } else if (method_name == "showWindow") {
          ShowWindow(window_handle, SW_SHOW);
          SetForegroundWindow(window_handle);
          result->Success(flutter::EncodableValue(true));
        } else {
          result->NotImplemented();
        }
      });
}
