#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>

struct V { uint32_t one, x, z; };
struct Out { V value; uint32_t checksum; };
struct Params { uint32_t islands, ticks, trace_enabled; };
static bool eq(V a, V b) { return a.one == b.one && a.x == b.x && a.z == b.z; }
static V and4(V a, V b) {
    uint32_t zero = ~(a.one | a.x | a.z) | ~(b.one | b.x | b.z);
    uint32_t one = a.one & b.one;
    return {one, ~(zero | one), 0};
}
static V or4(V a, V b) {
    uint32_t zero = ~(a.one | a.x | a.z) & ~(b.one | b.x | b.z);
    uint32_t one = a.one | b.one;
    return {one, ~(zero | one), 0};
}
static Out cpu_island(const V* stimulus, uint32_t ticks, uint32_t id, V* trace) {
    V input = {0, 0xffffffffu, 0};
    V reg = input, a = input, b = input, value = input;
    V mask = {0xa5a55a5au ^ (id * 0x01010101u), 0, 0};
    V delayed[2];
    bool scheduled[2] = {false, false};
    uint32_t checksum = 2166136261u;
    for (uint32_t tick = 0; tick < ticks; ++tick) {
        uint8_t queue[8];
        uint32_t head = 0, tail = 0;
        V next = stimulus[tick];
        if (!eq(input, next)) { input = next; queue[tail++] = 1; }
        for (uint32_t phase = 0; phase < 2; ++phase) {
            if (phase == 1 && scheduled[tick & 1u]) {
                V update = delayed[tick & 1u];
                scheduled[tick & 1u] = false;
                if (!eq(reg, update)) {
                    reg = update;
                    queue[tail++] = 0;
                    queue[tail++] = 1;
                }
            }
            while (head < tail) {
                uint8_t event = queue[head++];
                if (event == 0) {
                    V next_a = and4(reg, mask);
                    if (!eq(a, next_a)) { a = next_a; queue[tail++] = 2; }
                } else if (event == 1) {
                    V next_b = and4(input, reg);
                    if (!eq(b, next_b)) { b = next_b; queue[tail++] = 2; }
                } else {
                    value = or4(a, b);
                }
            }
        }
        delayed[(tick + 1u) & 1u] = input;
        scheduled[(tick + 1u) & 1u] = true;
        if (trace) trace[tick] = value;
        checksum = (checksum ^ value.one) * 16777619u + value.x + (value.z << 1);
    }
    return {value, checksum};
}
static double ms(std::chrono::steady_clock::time_point start) {
    return std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - start).count();
}
static double median(std::vector<double> v) {
    std::sort(v.begin(), v.end());
    return v[v.size() / 2];
}
static uint32_t scramble(uint32_t x) {
    x ^= x >> 16; x *= 0x7feb352du; x ^= x >> 15; x *= 0x846ca68bu; x ^= x >> 16;
    return x;
}
int main(int argc, char** argv) { @autoreleasepool {
    if (argc != 2) { fprintf(stderr, "usage: %s kernel.metal\n", argv[0]); return 2; }
    NSError* error = nil;
    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    if (!device) { fprintf(stderr, "No Metal device\n"); return 2; }
    NSString* path = [NSString stringWithUTF8String:argv[1]];
    NSString* source = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (!source) { fprintf(stderr, "Read shader: %s\n", error.description.UTF8String); return 2; }
    id<MTLLibrary> library = [device newLibraryWithSource:source options:nil error:&error];
    if (!library) { fprintf(stderr, "Compile shader: %s\n", error.description.UTF8String); return 2; }
    id<MTLComputePipelineState> pipeline = [device newComputePipelineStateWithFunction:[library newFunctionWithName:@"simulate"] error:&error];
    if (!pipeline) { fprintf(stderr, "Pipeline: %s\n", error.description.UTF8String); return 2; }
    id<MTLCommandQueue> command_queue = [device newCommandQueue];
    printf("device=%s model=isolated-event-islands trials=5\n", device.name.UTF8String);
    printf("islands ticks events_upper_bound input_MiB cpu_ms metal_submit_sync_ms metal_end_to_end_ms match\n");

    for (Params p : {Params{1, 4096, 0}, Params{64, 1024, 0}, Params{128, 256, 0}, Params{256, 256, 0}, Params{512, 256, 0}, Params{1024, 256, 0}, Params{4096, 256, 0}, Params{16384, 256, 0}}) {
        size_t input_bytes = size_t(p.islands) * p.ticks * sizeof(V);
        size_t output_bytes = size_t(p.islands) * sizeof(Out);
        std::vector<V> stimulus(size_t(p.islands) * p.ticks);
        std::vector<V> cpu_trace(stimulus.size());
        std::vector<Out> cpu(p.islands), gpu(p.islands);
        for (uint32_t island = 0; island < p.islands; ++island) {
            for (uint32_t tick = 0; tick < p.ticks; ++tick) {
                uint32_t r = scramble(island * 2654435761u + tick * 2246822519u);
                uint32_t x = r & 0x01010101u, z = (r >> 3) & 0x02020202u;
                stimulus[size_t(island) * p.ticks + tick] = {r & ~(x | z), x, z};
            }
        }
        id<MTLBuffer> inputs = [device newBufferWithLength:input_bytes options:MTLResourceStorageModeShared];
        id<MTLBuffer> outputs = [device newBufferWithLength:output_bytes options:MTLResourceStorageModeShared];
        id<MTLBuffer> trace = [device newBufferWithLength:input_bytes options:MTLResourceStorageModeShared];
        if (!inputs || !outputs || !trace) { fprintf(stderr, "Buffer allocation failed\n"); return 3; }
        std::vector<double> cpu_times, submit_times, full_times;
        for (int trial = -1; trial < 5; ++trial) {
            p.trace_enabled = trial == -1;
            auto start = std::chrono::steady_clock::now();
            for (uint32_t island = 0; island < p.islands; ++island)
                cpu[island] = cpu_island(stimulus.data() + size_t(island) * p.ticks, p.ticks, island,
                                         p.trace_enabled ? cpu_trace.data() + size_t(island) * p.ticks : nullptr);
            double cpu_elapsed = ms(start);

            start = std::chrono::steady_clock::now();
            memcpy(inputs.contents, stimulus.data(), input_bytes);
            auto submit_start = std::chrono::steady_clock::now();
            id<MTLCommandBuffer> command = [command_queue commandBuffer];
            id<MTLComputeCommandEncoder> encoder = [command computeCommandEncoder];
            [encoder setComputePipelineState:pipeline];
            [encoder setBuffer:inputs offset:0 atIndex:0];
            [encoder setBuffer:outputs offset:0 atIndex:1];
            [encoder setBytes:&p length:sizeof(p) atIndex:2];
            [encoder setBuffer:trace offset:0 atIndex:3];
            [encoder dispatchThreads:MTLSizeMake(p.islands, 1, 1) threadsPerThreadgroup:MTLSizeMake(std::min<uint32_t>(p.islands, 256), 1, 1)];
            [encoder endEncoding];
            [command commit]; [command waitUntilCompleted];
            double submit_elapsed = ms(submit_start);
            if (command.status != MTLCommandBufferStatusCompleted) {
                fprintf(stderr, "GPU command: %s\n", command.error.description.UTF8String); return 3;
            }
            memcpy(gpu.data(), outputs.contents, output_bytes);
            double full_elapsed = ms(start);
            if (memcmp(cpu.data(), gpu.data(), output_bytes) != 0) {
                fprintf(stderr, "Mismatch islands=%u ticks=%u trial=%d\n", p.islands, p.ticks, trial); return 4;
            }
            if (p.trace_enabled && memcmp(cpu_trace.data(), trace.contents, input_bytes) != 0) {
                fprintf(stderr, "Trace mismatch islands=%u ticks=%u\n", p.islands, p.ticks); return 4;
            }
            if (trial >= 0) { cpu_times.push_back(cpu_elapsed); submit_times.push_back(submit_elapsed); full_times.push_back(full_elapsed); }
        }
        printf("%u %u %llu %.2f %.4f %.4f %.4f 1\n", p.islands, p.ticks,
               (unsigned long long)p.islands * p.ticks * 6ull,
               double(input_bytes) / (1024.0 * 1024.0), median(cpu_times), median(submit_times), median(full_times));
        fflush(stdout);
    }
    return 0;
} }
