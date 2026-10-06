#include <chrono>
#include <cstdint>
#include <iostream>
#include <set>
#include <tuple>
#include <vector>
#include <z3++.h>

using Tuple = std::tuple<unsigned, unsigned, unsigned>;

int main(int argc, char** argv)
{
    const unsigned rounds = argc > 1 ? static_cast<unsigned>(std::stoul(argv[1])) : 25;
    if (!rounds || rounds > 500) {
        std::cerr << "usage: z3_joint_bench [rounds<=500]\n";
        return 2;
    }
    constexpr unsigned size = 32;
    std::vector<Tuple> expected;
    for (unsigned i = 0; i < size; ++i)
        expected.emplace_back((i * 7 + 13) % 251, (i ^ 0xa5U), (i * 3) % 16);

    z3::context ctx;
    const z3::expr a = ctx.bv_const("joint_a", 8);
    const z3::expr b = ctx.bv_const("joint_b", 8);
    const z3::expr c = ctx.bv_const("joint_c", 4);
    uint64_t checks = 0, models = 0, blockers = 0;
    const auto started = std::chrono::steady_clock::now();
    for (unsigned round = 0; round < rounds; ++round) {
        z3::solver solver(ctx);
        z3::expr allowed = ctx.bool_val(false);
        for (const auto& [av, bv, cv] : expected)
            allowed = allowed || ((a == ctx.bv_val(av, 8)) &&
                                  (b == ctx.bv_val(bv, 8)) &&
                                  (c == ctx.bv_val(cv, 4)));
        solver.add(allowed);

        std::set<Tuple> observed;
        while (true) {
            ++checks;
            const z3::check_result result = solver.check();
            if (result == z3::unsat)
                break;
            if (result != z3::sat) {
                std::cerr << "solver returned unknown\n";
                return 1;
            }
            const z3::model model = solver.get_model();
            const Tuple value{
                static_cast<unsigned>(model.eval(a).get_numeral_uint64()),
                static_cast<unsigned>(model.eval(b).get_numeral_uint64()),
                static_cast<unsigned>(model.eval(c).get_numeral_uint64())};
            if (!observed.insert(value).second) {
                std::cerr << "duplicate tuple escaped blocking clause\n";
                return 1;
            }
            ++models;
            const auto [av, bv, cv] = value;
            solver.add((a != ctx.bv_val(av, 8)) ||
                       (b != ctx.bv_val(bv, 8)) ||
                       (c != ctx.bv_val(cv, 4)));
            ++blockers;
        }
        if (observed.size() != expected.size()) {
            std::cerr << "tuple count mismatch\n";
            return 1;
        }
        for (const auto& value : expected)
            if (!observed.count(value)) {
                std::cerr << "expected tuple missing\n";
                return 1;
            }
    }
    const auto elapsed = std::chrono::duration_cast<std::chrono::nanoseconds>(
        std::chrono::steady_clock::now() - started).count();
    std::cout << "PASS rounds=" << rounds << " tuples_per_round=" << size
              << " checks=" << checks << " models=" << models
              << " tuple_blockers=" << blockers << " elapsed_ns=" << elapsed << '\n';
}
