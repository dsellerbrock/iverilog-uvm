#include <metal_stdlib>
using namespace metal;

// One thread owns one isolated event island. The queue is ordered within it.
struct V { uint one, x, z; };
struct Out { V value; uint checksum; };
struct Params { uint islands, ticks, trace_enabled; };

static bool equal4(V a, V b) {
    return a.one == b.one && a.x == b.x && a.z == b.z;
}
static V and4(V a, V b) {
    uint zero = ~(a.one | a.x | a.z) | ~(b.one | b.x | b.z);
    uint one = a.one & b.one;
    return {one, ~(zero | one), 0};
}
static V or4(V a, V b) {
    uint zero = ~(a.one | a.x | a.z) & ~(b.one | b.x | b.z);
    uint one = a.one | b.one;
    return {one, ~(zero | one), 0};
}

kernel void simulate(const device V* stimulus [[buffer(0)]],
                     device Out* result [[buffer(1)]],
                     constant Params& p [[buffer(2)]],
                     device V* trace [[buffer(3)]],
                     uint id [[thread_position_in_grid]]) {
    if (id >= p.islands) return;
    V input = {0, 0xffffffffu, 0};
    V reg = input, a = input, b = input, value = input;
    V mask = {0xa5a55a5au ^ (id * 0x01010101u), 0, 0};
    V delayed[2];
    bool scheduled[2] = {false, false};
    uint checksum = 2166136261u;

    for (uint tick = 0; tick < p.ticks; ++tick) {
        uchar queue[8];
        uint head = 0, tail = 0;
        V next = stimulus[id * p.ticks + tick];
        if (!equal4(input, next)) { input = next; queue[tail++] = 1; }

        // Active region: B depends on input and reg; A depends on reg.
        // Both fan out to O. O may therefore be evaluated more than once.
        for (uint phase = 0; phase < 2; ++phase) {
            if (phase == 1 && scheduled[tick & 1u]) {
                V update = delayed[tick & 1u];
                scheduled[tick & 1u] = false;
                if (!equal4(reg, update)) {
                    reg = update;
                    queue[tail++] = 0;
                    queue[tail++] = 1;
                }
            }
            while (head < tail) {
                uchar event = queue[head++];
                if (event == 0) {
                    V next_a = and4(reg, mask);
                    if (!equal4(a, next_a)) { a = next_a; queue[tail++] = 2; }
                } else if (event == 1) {
                    V next_b = and4(input, reg);
                    if (!equal4(b, next_b)) { b = next_b; queue[tail++] = 2; }
                } else {
                    value = or4(a, b);
                }
            }
        }
        // Delay one time slot, then apply in that slot's NBA phase.
        delayed[(tick + 1u) & 1u] = input;
        scheduled[(tick + 1u) & 1u] = true;
        if (p.trace_enabled) trace[id * p.ticks + tick] = value;
        checksum = (checksum ^ value.one) * 16777619u + value.x + (value.z << 1);
    }
    result[id] = {value, checksum};
}
