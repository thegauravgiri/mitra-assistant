import Foundation

func data(_ v: [Int16]) -> Data { v.withUnsafeBufferPointer { Data(buffer: $0) } }
func samples(_ d: Data) -> [Int16] { d.withUnsafeBytes { Array($0.bindMemory(to: Int16.self)) } }
var failures = 0
func check(_ ok: Bool, _ name: String) { print(ok ? "PASS" : "FAIL", name); if !ok { failures += 1 } }

func run(_ body: (PcmMixer) -> Void, wait: Double = 0.35) -> [[Int16]] {
  let m = PcmMixer()
  var out: [[Int16]] = []
  let lock = NSLock()
  m.start { d in lock.lock(); out.append(samples(d)); lock.unlock() }
  body(m)
  Thread.sleep(forTimeInterval: wait)
  m.stop()
  return out
}

// 1. stereo: left = mic, right = system, interleaved, length = 2 x one source (no double speed)
var r = run { m in
  m.push(.mic, pcm: data([Int16](repeating: 100, count: 1600)))
  m.push(.system, pcm: data([Int16](repeating: 200, count: 1600)))
}
var f = r.first ?? []
check(f.count == 3200, "stereo output is 2 x 1600 samples")
check(stride(from: 0, to: f.count, by: 2).allSatisfy { f[$0] == 100 }, "left channel is the microphone")
check(stride(from: 1, to: f.count, by: 2).allSatisfy { f[$0] == 200 }, "right channel is system audio")

// 2. channels are never summed or clipped: loud sources stay intact
r = run { m in
  m.push(.mic, pcm: data([Int16](repeating: 30000, count: 800)))
  m.push(.system, pcm: data([Int16](repeating: -30000, count: 800)))
}
f = r.first ?? []
check(f.count == 1600 && f[0] == 30000 && f[1] == -30000, "loud channels are kept separate, not summed")

// 3. samples stay in order and aligned
r = run { m in
  m.push(.mic, pcm: data([1, 2, 3, 4]))
  m.push(.system, pcm: data([10, 20, 30, 40]))
}
check(r.first == [1, 10, 2, 20, 3, 30, 4, 40], "interleaving order is mic, system, mic, system...")

// 4. while both are active, the faster source is NOT padded: only the common length is emitted
r = run { m in
  m.push(.mic, pcm: data([Int16](repeating: 10, count: 1000)))
  m.push(.system, pcm: data([Int16](repeating: 5, count: 400)))
}
f = r.first ?? []
check(f.count == 800 && f[0] == 10 && f[1] == 5, "waits for the slower source instead of padding (no time stretch)")

// 5. a source that never delivers is treated as silent after 500 ms; the other still flows
r = run({ m in m.push(.mic, pcm: data([7, 8, 9])) }, wait: 0.3)
check(r.first == [7, 0, 8, 0, 9, 0], "mic alone: right channel is silence")
r = run({ m in m.push(.system, pcm: data([7, 8, 9])) }, wait: 0.3)
check(r.first == [0, 7, 0, 8, 0, 9], "system alone: left channel is silence")

// 6. 100 ms frames, in order, nothing lost
r = run({ m in
  m.push(.mic, pcm: data((0..<3200).map { Int16($0 % 1000) }))
  m.push(.system, pcm: data([Int16](repeating: 1, count: 3200)))
}, wait: 0.45)
check(r.count >= 2 && r[0].count == 3200 && r[1].count == 3200 && r[1][0] == Int16(1600 % 1000), "chunked into 100 ms frames, in order")

// 7. backlog trimmed to 300 ms per channel
r = run({ m in m.push(.mic, pcm: data([Int16](repeating: 7, count: 20000))) }, wait: 0.15)
check(r.reduce(0, { $0 + $1.count }) <= 4800 * 2, "backlog trimmed to 300 ms")

// 8. stop clears
let m = PcmMixer()
var after = 0
m.start { _ in after += 1 }
m.stop()
m.push(.mic, pcm: data([1, 2, 3]))
Thread.sleep(forTimeInterval: 0.3)
check(after == 0, "nothing emitted after stop")

// 9. no input -> no output
r = run({ _ in }, wait: 0.3)
check(r.isEmpty, "no audio in, no chunks out")

print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
