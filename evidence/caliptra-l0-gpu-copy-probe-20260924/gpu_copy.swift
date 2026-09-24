import Foundation
import Metal
import Darwin

let shader = """
#include <metal_stdlib>
using namespace metal;
kernel void copy_planes(device const ulong *src [[buffer(0)]],
                        device ulong *dst [[buffer(1)]],
                        constant uint &words [[buffer(2)]],
                        uint id [[thread_position_in_grid]]) {
    if (id < words) dst[id] = src[id];
}
"""

guard let device = MTLCreateSystemDefaultDevice(),
      let queue = device.makeCommandQueue() else { fatalError("Metal unavailable") }
let library = try device.makeLibrary(source: shader, options: nil)
let pipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "copy_planes")!)
print("device=\(device.name) execution=single shared-memory Metal dispatch plus waitUntilCompleted; setup excluded")
print("payload_bytes vectors vector_bytes cpu_vector_ns cpu_flat_ns gpu_ns ratio_gpu_vector ratio_gpu_flat valid")

func measure(_ body: () -> Void, reps: Int) -> Double {
    body()
    let start = DispatchTime.now().uptimeNanoseconds
    for _ in 0..<reps { body() }
    return Double(DispatchTime.now().uptimeNanoseconds - start) / Double(reps)
}

for vectorBytes in [16, 128, 1024, 8192, 65536, 1048576, 4194304, 16777216] {
    for vectors in [1, 16, 256] {
        let bytes = vectorBytes * vectors
        if bytes > 64 * 1024 * 1024 { continue }
        let reps = bytes <= 65536 ? 200 : bytes <= 1048576 ? 50 : 8
        guard let src = device.makeBuffer(length: bytes, options: .storageModeShared),
              let cpuDst = device.makeBuffer(length: bytes, options: .storageModeShared),
              let gpuDst = device.makeBuffer(length: bytes, options: .storageModeShared) else {
            fatalError("buffer allocation failed for \(bytes)")
        }
        let source = src.contents().assumingMemoryBound(to: UInt64.self)
        let cpu = cpuDst.contents().assumingMemoryBound(to: UInt64.self)
        let gpu = gpuDst.contents().assumingMemoryBound(to: UInt64.self)
        for i in 0..<(bytes / 8) { source[i] = UInt64(i) &* 0x9e3779b97f4a7c15 }
        let cpuNS = measure({
            for i in 0..<vectors {
                memcpy(cpuDst.contents().advanced(by: i * vectorBytes),
                       src.contents().advanced(by: i * vectorBytes), vectorBytes)
            }
        }, reps: reps)
        let cpuFlatNS = measure({
            memcpy(cpuDst.contents(), src.contents(), bytes)
        }, reps: reps)
        let gpuNS = measure({
            let cb = queue.makeCommandBuffer()!
            let encoder = cb.makeComputeCommandEncoder()!
            encoder.setComputePipelineState(pipeline)
            encoder.setBuffer(src, offset: 0, index: 0)
            encoder.setBuffer(gpuDst, offset: 0, index: 1)
            var words = UInt32(bytes / 8)
            encoder.setBytes(&words, length: MemoryLayout<UInt32>.size, index: 2)
            encoder.dispatchThreads(MTLSize(width: bytes / 8, height: 1, depth: 1),
                                    threadsPerThreadgroup: MTLSize(width: min(pipeline.maxTotalThreadsPerThreadgroup, 256), height: 1, depth: 1))
            encoder.endEncoding()
            cb.commit()
            cb.waitUntilCompleted()
            guard cb.status == .completed else { fatalError("Metal command failed: \(String(describing: cb.error))") }
        }, reps: reps)
        var valid = true
        for i in 0..<(bytes / 8) { if cpu[i] != source[i] || gpu[i] != source[i] { valid = false; break } }
        print("\(bytes) \(vectors) \(vectorBytes) \(Int(cpuNS)) \(Int(cpuFlatNS)) \(Int(gpuNS)) \(String(format: "%.2f", gpuNS / cpuNS)) \(String(format: "%.2f", gpuNS / cpuFlatNS)) \(valid)")
    }
}
