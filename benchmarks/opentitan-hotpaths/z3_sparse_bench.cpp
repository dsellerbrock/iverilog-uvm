#include <algorithm>
#include <chrono>
#include <cstdint>
#include <iostream>
#include <set>
#include <string>
#include <vector>
#include <z3++.h>

static unsigned domain_size(const std::string& name)
{
    if (name == "spi") return 16;
    if (name == "i2c") return 12;
    if (name == "hmac") return 24;
    if (name == "tl") return 32;
    return 0;
}

int main(int argc, char** argv)
{
    const std::string workload = argc > 1 ? argv[1] : "spi";
    const unsigned rounds = argc > 2 ? static_cast<unsigned>(std::stoul(argv[2])) : 25;
    const unsigned size = domain_size(workload);
    if (!size || !rounds || rounds > 500) {
        std::cerr << "usage: z3_sparse_bench {spi|i2c|hmac|tl} [rounds<=500]\n";
        return 2;
    }

    z3::context ctx;
    const z3::expr x = ctx.bv_const("sparse_x", 32);
    std::vector<uint32_t> domain;
    for (unsigned i = 0; i < size; ++i)
        domain.push_back((0x10001U + i * 0x10103U) ^ (i * 0x4000001U));
    std::sort(domain.begin(), domain.end());

    uint64_t checks = 0, models = 0, blockers = 0;
    const auto started = std::chrono::steady_clock::now();
    for (unsigned round = 0; round < rounds; ++round) {
        z3::solver solver(ctx);
        z3::expr allowed = ctx.bool_val(false);
        for (const uint32_t value : domain)
            allowed = allowed || (x == ctx.bv_val(value, 32));
        solver.add(allowed);

        std::set<uint32_t> observed;
        while (true) {
            ++checks;
            const z3::check_result result = solver.check();
            if (result == z3::unsat)
                break;
            if (result != z3::sat) {
                std::cerr << "solver returned unknown\n";
                return 1;
            }
            const uint64_t value = solver.get_model().eval(x).get_numeral_uint64();
            if (!observed.insert(static_cast<uint32_t>(value)).second) {
                std::cerr << "duplicate model escaped blocking clause\n";
                return 1;
            }
            ++models;
            solver.add(x != ctx.bv_val(value, 32));
            ++blockers;
        }
        if (observed.size() != domain.size()) {
            std::cerr << "enumerated " << observed.size() << " of " << domain.size() << " values\n";
            return 1;
        }
        for (const uint32_t value : domain)
            if (!observed.count(value)) {
                std::cerr << "expected candidate missing\n";
                return 1;
            }
    }
    const auto elapsed = std::chrono::duration_cast<std::chrono::nanoseconds>(
        std::chrono::steady_clock::now() - started).count();
    std::cout << "PASS workload=" << workload << " rounds=" << rounds
              << " values_per_round=" << size << " checks=" << checks
              << " models=" << models << " blockers=" << blockers
              << " elapsed_ns=" << elapsed << '\n';
}
