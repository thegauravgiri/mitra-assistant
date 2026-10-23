#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstddef>
#include <thread>
#include <vector>
#include <cstdio>
class StereoInterleaver {
 public:
  void PushMic(const std::vector<uint8_t>& pcm) {
    Append(mic_, pcm);
    last_mic_ = Clock::now();
  }

  void PushLoopback(const std::vector<uint8_t>& pcm) {
    Append(loop_, pcm);
    last_loop_ = Clock::now();
  }

  // Returns interleaved stereo bytes (possibly empty). At most 100 ms per call.
  std::vector<uint8_t> Take() {
    const auto now = Clock::now();
    const bool mic_active = now - last_mic_ < kInactiveAfter;
    const bool loop_active = now - last_loop_ < kInactiveAfter;

    size_t n;
    if (mic_active && loop_active) {
      n = std::min(mic_.size(), loop_.size());
    } else if (mic_active) {
      n = mic_.size();
    } else if (loop_active) {
      n = loop_.size();
    } else {
      n = std::max(mic_.size(), loop_.size());
    }
    n = std::min(n, kFrameSamples);

    std::vector<uint8_t> out;
    if (n == 0) return out;
    out.reserve(n * 4);
    for (size_t i = 0; i < n; ++i) {
      PushSample(out, i < mic_.size() ? mic_[i] : 0);
      PushSample(out, i < loop_.size() ? loop_[i] : 0);
    }
    mic_.erase(mic_.begin(), mic_.begin() + static_cast<std::ptrdiff_t>(std::min(n, mic_.size())));
    loop_.erase(loop_.begin(), loop_.begin() + static_cast<std::ptrdiff_t>(std::min(n, loop_.size())));
    return out;
  }

 private:
  using Clock = std::chrono::steady_clock;
  static constexpr size_t kFrameSamples = 1600;       // 100 ms at 16 kHz, per channel
  static constexpr size_t kMaxBufferedSamples = 4800; // 300 ms
  static constexpr std::chrono::milliseconds kInactiveAfter{500};

  static void Append(std::vector<int16_t>& queue, const std::vector<uint8_t>& pcm) {
    for (size_t i = 0; i + 1 < pcm.size(); i += 2) {
      queue.push_back(static_cast<int16_t>(static_cast<uint16_t>(pcm[i]) | (static_cast<uint16_t>(pcm[i + 1]) << 8)));
    }
    if (queue.size() > kMaxBufferedSamples) {
      queue.erase(queue.begin(), queue.begin() + static_cast<std::ptrdiff_t>(queue.size() - kMaxBufferedSamples));
    }
  }

  static void PushSample(std::vector<uint8_t>& out, int16_t sample) {
    out.push_back(static_cast<uint8_t>(sample & 0xFF));
    out.push_back(static_cast<uint8_t>((sample >> 8) & 0xFF));
  }

  std::vector<int16_t> mic_;
  std::vector<int16_t> loop_;
  Clock::time_point last_mic_{};
  Clock::time_point last_loop_{};
};


static std::vector<uint8_t> bytes(std::vector<int16_t> v){ std::vector<uint8_t> o; for(auto s: v){o.push_back(s&0xFF);o.push_back((s>>8)&0xFF);} return o; }
static std::vector<int16_t> samples(const std::vector<uint8_t>& b){ std::vector<int16_t> o; for(size_t i=0;i+1<b.size();i+=2) o.push_back((int16_t)(b[i]|(b[i+1]<<8))); return o; }
int main(){
  int fail=0;
  auto check=[&](bool ok,const char* n){ printf("%s %s\n", ok?"PASS":"FAIL", n); if(!ok) fail++; };
  { StereoInterleaver s; s.PushMic(bytes({1,2,3})); s.PushLoopback(bytes({10,20,30})); auto o=samples(s.Take());
    check(o==std::vector<int16_t>({1,10,2,20,3,30}), "interleaves mic(left) and loopback(right)"); }
  { StereoInterleaver s; s.PushMic(bytes({1,2,3,4})); s.PushLoopback(bytes({10,20})); auto o=samples(s.Take());
    check(o==std::vector<int16_t>({1,10,2,20}), "both active: emits only the common length, no padding");
    s.PushLoopback(bytes({30,40})); auto o2=samples(s.Take());
    check(o2==std::vector<int16_t>({3,30,4,40}), "the rest follows when the slower source catches up"); }
  { StereoInterleaver s; s.PushMic(bytes({7,8})); auto o=samples(s.Take());
    check(o==std::vector<int16_t>({7,0,8,0}), "mic alone: right channel silent"); }
  { StereoInterleaver s; s.PushLoopback(bytes({7,8})); auto o=samples(s.Take());
    check(o==std::vector<int16_t>({0,7,0,8}), "loopback alone: left channel silent"); }
  { StereoInterleaver s; check(s.Take().empty(), "nothing in, nothing out"); }
  { StereoInterleaver s; std::vector<int16_t> big(20000, 5); s.PushMic(bytes(big)); auto o=s.Take(); check(o.size()==1600*4, "capped at 100 ms per call"); }
  printf(fail?"%d FAILED\n":"ALL PASSED\n", fail); return fail?1:0;
}
