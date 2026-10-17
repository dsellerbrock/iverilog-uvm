#include <algorithm>
#include <array>
#include <cassert>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <iterator>
#include <stdexcept>
#include <string>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include <vector>

#if !defined(__x86_64__) || !defined(__linux__)
#error "This throwaway stencil is for x86-64 Linux only."
#endif

namespace {

constexpr uint32_t kPatch = 0x13579bdfU;
constexpr unsigned nblk = 800;
constexpr unsigned nblocks = 2 * nblk;
constexpr unsigned rounds = 64;
constexpr unsigned workloads_per_sample = 100;

const uint32_t kSha256[rounds] = {
    0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
};

struct V4 { uint32_t a = 0; uint32_t b = 0; };
struct State4 { uint32_t a[8] = {}; uint32_t b[8] = {}; };
struct Schedule4 { uint32_t a[rounds] = {}; uint32_t b[rounds] = {}; };

static inline __attribute__((always_inline)) uint32_t rotr32(uint32_t v, unsigned n)
{
    return (v >> n) | (v << (32 - n));
}

static inline __attribute__((always_inline)) V4 v4_xor(V4 x, V4 y)
{
    return {(x.a ^ y.a) | x.b | y.b, x.b | y.b};
}

static inline __attribute__((always_inline)) V4 v4_and(V4 x, V4 y)
{
    const uint32_t xp = x.a | x.b;
    const uint32_t yp = y.a | y.b;
    return {xp & yp, (xp & y.b) | (yp & x.b)};
}

static inline __attribute__((always_inline)) V4 v4_not(V4 x)
{
    return {~x.a | x.b, x.b};
}

static inline __attribute__((always_inline)) V4 v4_add(V4 x, V4 y)
{
    if (x.b | y.b)
        return {0xffffffffU, 0xffffffffU};
    return {x.a + y.a, 0};
}

static inline __attribute__((always_inline)) V4 v4_rotr(V4 x, unsigned n)
{
    return {rotr32(x.a, n), rotr32(x.b, n)};
}

static inline __attribute__((always_inline)) V4 v4_shr(V4 x, unsigned n)
{
    return {x.a >> n, x.b >> n};
}

static inline __attribute__((always_inline)) V4 state_get(const State4& s, unsigned i)
{
    return {s.a[i], s.b[i]};
}

static inline __attribute__((always_inline)) void state_set(State4& s, unsigned i, V4 v)
{
    s.a[i] = v.a;
    s.b[i] = v.b;
}

static inline __attribute__((always_inline)) V4 sched_get(const Schedule4& w, unsigned i)
{
    return {w.a[i], w.b[i]};
}

static inline __attribute__((always_inline)) void sched_set(Schedule4& w, unsigned i, V4 v)
{
    w.a[i] = v.a;
    w.b[i] = v.b;
}

enum class Op : uint8_t { load_state, load_w, load_k, mov, rotr, bit_xor, bit_and, bit_not, add, store_state };
struct Insn { Op op; uint8_t d; uint8_t x; uint8_t y; uint8_t index; uint8_t shift; };
using Handler = void (*)(V4*, State4&, const Schedule4&, unsigned, uint32_t, const Insn&);

__attribute__((noinline)) void op_load_state(V4* r, State4& s, const Schedule4&, unsigned, uint32_t, const Insn& i)
{ r[i.d] = state_get(s, i.index); }
__attribute__((noinline)) void op_load_w(V4* r, State4&, const Schedule4& w, unsigned t, uint32_t, const Insn& i)
{ r[i.d] = sched_get(w, t); }
__attribute__((noinline)) void op_load_k(V4* r, State4&, const Schedule4&, unsigned, uint32_t k, const Insn& i)
{ r[i.d] = {k, 0}; }
__attribute__((noinline)) void op_mov(V4* r, State4&, const Schedule4&, unsigned, uint32_t, const Insn& i)
{ r[i.d] = r[i.x]; }
__attribute__((noinline)) void op_rotr(V4* r, State4&, const Schedule4&, unsigned, uint32_t, const Insn& i)
{ r[i.d] = v4_rotr(r[i.x], i.shift); }
__attribute__((noinline)) void op_xor(V4* r, State4&, const Schedule4&, unsigned, uint32_t, const Insn& i)
{ r[i.d] = v4_xor(r[i.x], r[i.y]); }
__attribute__((noinline)) void op_and(V4* r, State4&, const Schedule4&, unsigned, uint32_t, const Insn& i)
{ r[i.d] = v4_and(r[i.x], r[i.y]); }
__attribute__((noinline)) void op_not(V4* r, State4&, const Schedule4&, unsigned, uint32_t, const Insn& i)
{ r[i.d] = v4_not(r[i.x]); }
__attribute__((noinline)) void op_add(V4* r, State4&, const Schedule4&, unsigned, uint32_t, const Insn& i)
{ r[i.d] = v4_add(r[i.x], r[i.y]); }
__attribute__((noinline)) void op_store_state(V4* r, State4& s, const Schedule4&, unsigned, uint32_t, const Insn& i)
{ state_set(s, i.index, r[i.x]); }

const Handler handlers[] = {
    op_load_state, op_load_w, op_load_k, op_mov, op_rotr,
    op_xor, op_and, op_not, op_add, op_store_state
};

std::vector<Insn> make_round_program()
{
    std::vector<Insn> p;
    auto emit = [&p](Op op, int d, int x=0, int y=0, int index=0, int shift=0) {
        p.push_back({op, static_cast<uint8_t>(d), static_cast<uint8_t>(x),
                     static_cast<uint8_t>(y), static_cast<uint8_t>(index),
                     static_cast<uint8_t>(shift)});
    };
    for (int i = 0; i < 8; ++i) emit(Op::load_state, i, 0, 0, i);
    emit(Op::load_w, 8);
    emit(Op::load_k, 9);
    emit(Op::rotr, 10, 4, 0, 0, 6);
    emit(Op::rotr, 11, 4, 0, 0, 11);
    emit(Op::rotr, 12, 4, 0, 0, 25);
    emit(Op::bit_xor, 13, 10, 11);
    emit(Op::bit_xor, 14, 13, 12);
    emit(Op::bit_and, 15, 4, 5);
    emit(Op::bit_not, 16, 4);
    emit(Op::bit_and, 17, 16, 6);
    emit(Op::bit_xor, 18, 15, 17);
    emit(Op::add, 19, 7, 14);
    emit(Op::add, 19, 19, 18);
    emit(Op::add, 19, 19, 8);
    emit(Op::add, 19, 19, 9);
    emit(Op::rotr, 20, 0, 0, 0, 2);
    emit(Op::rotr, 21, 0, 0, 0, 13);
    emit(Op::rotr, 22, 0, 0, 0, 22);
    emit(Op::bit_xor, 23, 20, 21);
    emit(Op::bit_xor, 24, 23, 22);
    emit(Op::bit_and, 25, 0, 1);
    emit(Op::bit_and, 26, 0, 2);
    emit(Op::bit_xor, 27, 25, 26);
    emit(Op::bit_and, 28, 1, 2);
    emit(Op::bit_xor, 29, 27, 28);
    emit(Op::add, 30, 24, 29);
    emit(Op::add, 31, 19, 30);
    emit(Op::add, 32, 3, 19);
    emit(Op::store_state, 0, 31, 0, 0);
    emit(Op::store_state, 1, 0, 0, 1);
    emit(Op::store_state, 2, 1, 0, 2);
    emit(Op::store_state, 3, 2, 0, 3);
    emit(Op::store_state, 4, 32, 0, 4);
    emit(Op::store_state, 5, 4, 0, 5);
    emit(Op::store_state, 6, 5, 0, 6);
    emit(Op::store_state, 7, 6, 0, 7);
    return p;
}

void interpret_round(State4& s, const Schedule4& w, unsigned t, uint32_t k,
                     const std::vector<Insn>& program)
{
    V4 regs[40] = {};
    for (const Insn& i : program)
        handlers[static_cast<unsigned>(i.op)](regs, s, w, t, k, i);
}

static inline __attribute__((always_inline)) uint32_t rotr_plain(uint32_t x, unsigned n)
{ return rotr32(x, n); }

// This function is extracted as a standalone stencil. Its marker immediate is
// replaced with K[t] after its bytes are copied to a private executable page.
extern "C" __attribute__((noinline, used, section(".text.sha256_round_stencil")))
void sha256_round_stencil(uint32_t* s, const uint32_t* w)
{
    uint32_t k;
    asm volatile("movl $0x13579bdf, %0" : "=r"(k));
    const uint32_t a=s[0], b=s[1], c=s[2], d=s[3];
    const uint32_t e=s[4], f=s[5], g=s[6], h=s[7];
    const uint32_t sum1=rotr_plain(e,6)^rotr_plain(e,11)^rotr_plain(e,25);
    const uint32_t ch=(e&f)^((~e)&g);
    const uint32_t t1=h+sum1+ch+w[0]+k;
    const uint32_t sum0=rotr_plain(a,2)^rotr_plain(a,13)^rotr_plain(a,22);
    const uint32_t maj=(a&b)^(a&c)^(b&c);
    const uint32_t t2=sum0+maj;
    s[0]=t1+t2; s[1]=a; s[2]=b; s[3]=c;
    s[4]=d+t1; s[5]=e; s[6]=f; s[7]=g;
}

using JitFn = void (*)(uint32_t*, const uint32_t*);

struct Jit {
    void* mapping = MAP_FAILED;
    size_t mapping_bytes = 0;
    size_t stencil_bytes = 0;
    size_t stride = 0;
    size_t patch_offset = 0;
    JitFn entry[rounds] = {};
    double compile_seconds = 0;
};

double now_seconds()
{
    timespec ts{};
    clock_gettime(CLOCK_MONOTONIC_RAW, &ts);
    return static_cast<double>(ts.tv_sec) + static_cast<double>(ts.tv_nsec) / 1e9;
}

Jit build_jit(const std::string& path)
{
    const double start = now_seconds();
    std::ifstream file(path, std::ios::binary);
    if (!file) throw std::runtime_error("cannot open stencil.bin");
    std::vector<uint8_t> stencil((std::istreambuf_iterator<char>(file)), {});
    if (stencil.empty()) throw std::runtime_error("empty stencil.bin");
    const uint8_t marker[] = {0xdf, 0x9b, 0x57, 0x13};
    auto first = std::search(stencil.begin(), stencil.end(), std::begin(marker), std::end(marker));
    if (first == stencil.end()) throw std::runtime_error("K marker not found in stencil");
    auto second = std::search(first + 1, stencil.end(), std::begin(marker), std::end(marker));
    if (second != stencil.end()) throw std::runtime_error("K marker is not unique");

    Jit jit;
    jit.stencil_bytes = stencil.size();
    jit.patch_offset = static_cast<size_t>(first - stencil.begin());
    jit.stride = (stencil.size() + 15U) & ~size_t(15U);
    const size_t need = jit.stride * rounds;
    const long page = sysconf(_SC_PAGESIZE);
    if (page <= 0) throw std::runtime_error("invalid page size");
    jit.mapping_bytes = ((need + static_cast<size_t>(page) - 1) / static_cast<size_t>(page)) * static_cast<size_t>(page);
    jit.mapping = mmap(nullptr, jit.mapping_bytes, PROT_READ | PROT_WRITE,
                       MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (jit.mapping == MAP_FAILED) throw std::runtime_error("mmap failed");
    auto* bytes = static_cast<uint8_t*>(jit.mapping);
    for (unsigned t = 0; t < rounds; ++t) {
        uint8_t* dst = bytes + t * jit.stride;
        std::memcpy(dst, stencil.data(), stencil.size());
        std::memcpy(dst + jit.patch_offset, &kSha256[t], sizeof(uint32_t));
        jit.entry[t] = reinterpret_cast<JitFn>(dst);
    }
    __builtin___clear_cache(reinterpret_cast<char*>(jit.mapping),
                            reinterpret_cast<char*>(jit.mapping) + need);
    if (mprotect(jit.mapping, jit.mapping_bytes, PROT_READ | PROT_EXEC) != 0)
        throw std::runtime_error("mprotect RX failed");
    jit.compile_seconds = now_seconds() - start;
    return jit;
}

bool all_defined(const State4& s, const Schedule4& w, unsigned t)
{
    uint32_t bits = w.b[t];
    for (unsigned i = 0; i < 8; ++i) bits |= s.b[i];
    return bits == 0;
}

void sha_round(State4& s, const Schedule4& w, unsigned t,
               const std::vector<Insn>& program, const Jit* jit,
               uint64_t& jit_rounds, uint64_t& fallback_rounds)
{
    if (jit && all_defined(s, w, t)) {
        jit->entry[t](s.a, &w.a[t]);
        ++jit_rounds;
    } else {
        interpret_round(s, w, t, kSha256[t], program);
        if (jit) ++fallback_rounds;
    }
}

void compress(State4& digest, const uint32_t block[16],
              const std::vector<Insn>& program, const Jit* jit,
              uint64_t& jit_rounds, uint64_t& fallback_rounds)
{
    Schedule4 w{};
    for (unsigned i = 0; i < 16; ++i) w.a[i] = block[i];
    for (unsigned i = 16; i < rounds; ++i) {
        const V4 x = sched_get(w, i - 15);
        const V4 s0 = v4_xor(v4_xor(v4_rotr(x, 7), v4_rotr(x, 18)), v4_shr(x, 3));
        const V4 y = sched_get(w, i - 2);
        const V4 s1 = v4_xor(v4_xor(v4_rotr(y, 17), v4_rotr(y, 19)), v4_shr(y, 10));
        V4 value = v4_add(sched_get(w, i - 16), s0);
        value = v4_add(value, sched_get(w, i - 7));
        value = v4_add(value, s1);
        sched_set(w, i, value);
    }
    State4 work = digest;
    for (unsigned t = 0; t < rounds; ++t)
        sha_round(work, w, t, program, jit, jit_rounds, fallback_rounds);
    for (unsigned i = 0; i < 8; ++i)
        state_set(digest, i, v4_add(state_get(digest, i), state_get(work, i)));
}

struct Output { std::array<uint32_t, 8> digest; uint64_t sum; };

Output run_workload(const std::vector<Insn>& program, const Jit* jit,
                    uint64_t& jit_rounds, uint64_t& fallback_rounds)
{
    State4 h{};
    const uint32_t iv[8] = {0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,
                            0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19};
    for (unsigned i = 0; i < 8; ++i) h.a[i] = iv[i];
    for (uint32_t n = 0; n < nblocks; ++n) {
        uint32_t block[16];
        if (n == 0) {
            // tb_sha256.sv drives its first block while digest is still reset to zero.
            std::fill(std::begin(block), std::end(block), 0U);
        } else {
            for (unsigned i = 0; i < 8; ++i) {
                block[i] = h.a[i];
                block[i + 8] = h.a[i] ^ n;
            }
        }
        compress(h, block, program, jit, jit_rounds, fallback_rounds);
    }
    Output out{};
    for (unsigned i = 0; i < 8; ++i) {
        if (h.b[i] != 0) throw std::runtime_error("unexpected X/Z in defined SHA workload");
        out.digest[i] = h.a[i];
    }
    for (unsigned k = 0; k < 4; ++k)
        out.sum ^= static_cast<uint64_t>(out.digest[7 - 2 * k]) ^
                   (static_cast<uint64_t>(out.digest[6 - 2 * k]) << 32);
    return out;
}

bool operator==(const Output& x, const Output& y)
{ return x.digest == y.digest && x.sum == y.sum; }

double spread(const std::vector<double>& values)
{
    auto [lo, hi] = std::minmax_element(values.begin(), values.end());
    std::vector<double> sorted = values;
    std::sort(sorted.begin(), sorted.end());
    const double median = sorted[sorted.size() / 2];
    return (*hi - *lo) / median * 100.0;
}

double median(std::vector<double> values)
{
    std::sort(values.begin(), values.end());
    return values[values.size() / 2];
}

} // namespace

int main(int argc, char** argv)
{
    try {
        if (argc != 2) throw std::runtime_error("usage: copy_patch_sha256 stencil.bin");
        const auto program = make_round_program();
        Jit jit = build_jit(argv[1]);

        uint64_t warm_jit = 0, warm_fallback = 0;
        const Output interpreted = run_workload(program, nullptr, warm_jit, warm_fallback);
        const Output patched = run_workload(program, &jit, warm_jit, warm_fallback);
        if (!(interpreted == patched)) throw std::runtime_error("interpreter/JIT output mismatch");

        std::vector<double> interpreted_times, jit_times;
        uint64_t total_jit_rounds = 0, total_fallback_rounds = 0;
        for (unsigned repeat = 0; repeat < 9; ++repeat) {
            uint64_t a_jit = 0, a_fallback = 0;
            uint64_t b_jit = 0, b_fallback = 0;
            const auto time_interpreter = [&]() {
                const double start = now_seconds();
                Output out{};
                for (unsigned i = 0; i < workloads_per_sample; ++i) {
                    out = run_workload(program, nullptr, a_jit, a_fallback);
                    if (!(out == interpreted)) throw std::runtime_error("interpreter output changed");
                }
                const double end = now_seconds();
                interpreted_times.push_back((end - start) / workloads_per_sample);
            };
            const auto time_jit = [&]() {
                const double start = now_seconds();
                Output out{};
                for (unsigned i = 0; i < workloads_per_sample; ++i) {
                    out = run_workload(program, &jit, b_jit, b_fallback);
                    if (!(out == interpreted)) throw std::runtime_error("JIT output changed");
                }
                const double end = now_seconds();
                jit_times.push_back((end - start) / workloads_per_sample);
                total_jit_rounds += b_jit;
                total_fallback_rounds += b_fallback;
            };
            if ((repeat & 1U) == 0) { time_interpreter(); time_jit(); }
            else { time_jit(); time_interpreter(); }
        }
        const double i_med = median(interpreted_times);
        const double j_med = median(jit_times);
        std::cout << "NBLK=" << nblk << " sha256=" << std::hex << std::setw(8)
                  << std::setfill('0') << interpreted.digest[0]
                  << " sum=" << std::setw(16) << interpreted.sum << std::dec << '\n';
        std::cout << "blocks=" << nblocks << " rounds=" << (nblocks * rounds)
                  << " repeats=" << interpreted_times.size()
                  << " workloads_per_sample=" << workloads_per_sample << '\n';
        std::cout << "stencil_bytes=" << jit.stencil_bytes << " code_bytes=" << (jit.stride * rounds)
                  << " patch_offset=" << jit.patch_offset << '\n';
        std::cout << "copy_patch_compile_seconds=" << jit.compile_seconds << '\n';
        std::cout << "round_interpreter_median_seconds=" << i_med
                  << " spread_percent=" << spread(interpreted_times) << '\n';
        std::cout << "copy_patch_jit_median_seconds=" << j_med
                  << " spread_percent=" << spread(jit_times) << '\n';
        std::cout << "round_kernel_speedup=" << (i_med / j_med) << "x\n";
        std::cout << "jit_rounds=" << total_jit_rounds << " fallback_rounds=" << total_fallback_rounds << '\n';

        // An X/Z value must miss the two-state stencil and use the exact 4-state interpreter.
        State4 with_x{};
        with_x.a[0] = 0x12345678;
        with_x.b[0] = 0x00000001;
        Schedule4 one_word{};
        one_word.a[0] = 0xabcdef01;
        uint64_t xjit = 0, xfallback = 0;
        sha_round(with_x, one_word, 0, program, &jit, xjit, xfallback);
        if (xjit != 0 || xfallback != 1)
            throw std::runtime_error("X/Z guard did not deopt to the 4-state interpreter");
        std::cout << "xz_guard=fallback_to_4state_interpreter\n";
        return 0;
    } catch (const std::exception& e) {
        std::cerr << "copy-patch spike error: " << e.what() << '\n';
        return 1;
    }
}
