#ifndef RUNNER_WINDOW_CONTROL_CHANNEL_H_
#define RUNNER_WINDOW_CONTROL_CHANNEL_H_

#include <flutter/binary_messenger.h>
#include <windows.h>
#include <memory>

class WindowControlChannel {
 public:
  static void RegisterWithMessenger(flutter::BinaryMessenger* messenger, HWND window_handle);

 private:
  WindowControlChannel() = default;
};

#endif  // RUNNER_WINDOW_CONTROL_CHANNEL_H_
