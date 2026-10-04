#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <map>
#include <set>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

using Key = std::vector<char>; // bit 0 is LSB; 0 < 1 < X < Z
using Clock = std::chrono::steady_clock;

static uint64_t comparisons;
static uint64_t scanned_entries;

static std::string raw_key(const Key& key)
{
    const unsigned width = static_cast<unsigned>(key.size());
    std::string raw(4 + width, '\0');
    raw[0] = static_cast<char>((width >> 24) & 0xff);
    raw[1] = static_cast<char>((width >> 16) & 0xff);
    raw[2] = static_cast<char>((width >> 8) & 0xff);
    raw[3] = static_cast<char>(width & 0xff);
    for (unsigned bit = 0; bit < width; ++bit)
        raw[4 + bit] = key[width - bit - 1];
    return raw;
}

static int compare_key(const Key& lhs, const Key& rhs, bool signed_order = false)
{
    ++comparisons;
    const unsigned lhs_width = static_cast<unsigned>(lhs.size());
    const unsigned rhs_width = static_cast<unsigned>(rhs.size());
    const bool lhs_negative = signed_order && lhs_width && lhs.back() == '1';
    const bool rhs_negative = signed_order && rhs_width && rhs.back() == '1';
    if (lhs_negative != rhs_negative)
        return lhs_negative ? -1 : 1;

    const unsigned width = std::max(lhs_width, rhs_width);
    for (unsigned pos = width; pos > 0; --pos) {
        const unsigned bit = pos - 1;
        const char lhs_bit = bit < lhs_width ? lhs[bit] : (lhs_negative ? '1' : '0');
        const char rhs_bit = bit < rhs_width ? rhs[bit] : (rhs_negative ? '1' : '0');
        if (lhs_bit != rhs_bit)
            return lhs_bit < rhs_bit ? -1 : 1;
    }
    const std::string lhs_raw = raw_key(lhs);
    const std::string rhs_raw = raw_key(rhs);
    if (lhs_raw == rhs_raw)
        return 0;
    return lhs_raw < rhs_raw ? -1 : 1;
}

// Independent, allocation-heavy oracle for the source comparator's ordering
// rules. Comparing every short 0/1/X/Z key pair checks mixed widths and both
// signed and unsigned modes before timing the large unsigned walk.
static int reference_compare(const Key& lhs, const Key& rhs, bool signed_order)
{
    const bool lhs_negative = signed_order && !lhs.empty() && lhs.back() == '1';
    const bool rhs_negative = signed_order && !rhs.empty() && rhs.back() == '1';
    if (lhs_negative != rhs_negative)
        return lhs_negative ? -1 : 1;
    const unsigned width = std::max(lhs.size(), rhs.size());
    std::string lhs_extended, rhs_extended;
    lhs_extended.reserve(width);
    rhs_extended.reserve(width);
    for (unsigned bit = width; bit > 0; --bit) {
        const unsigned index = bit - 1;
        lhs_extended.push_back(index < lhs.size() ? lhs[index] : (lhs_negative ? '1' : '0'));
        rhs_extended.push_back(index < rhs.size() ? rhs[index] : (rhs_negative ? '1' : '0'));
    }
    if (lhs_extended != rhs_extended)
        return lhs_extended < rhs_extended ? -1 : 1;
    const std::string lhs_raw = raw_key(lhs);
    const std::string rhs_raw = raw_key(rhs);
    if (lhs_raw == rhs_raw)
        return 0;
    return lhs_raw < rhs_raw ? -1 : 1;
}

static uint64_t check_comparator_exhaustive()
{
    const char symbols[] = {'0', '1', 'X', 'Z'};
    std::vector<Key> keys;
    for (unsigned width = 1; width <= 4; ++width) {
        unsigned limit = 1;
        for (unsigned i = 0; i < width; ++i)
            limit *= 4;
        for (unsigned encoding = 0; encoding < limit; ++encoding) {
            unsigned value = encoding;
            Key key(width);
            for (unsigned bit = 0; bit < width; ++bit) {
                key[bit] = symbols[value & 3U];
                value >>= 2;
            }
            keys.push_back(key);
        }
    }
    uint64_t cases = 0;
    comparisons = 0;
    for (bool signed_order : {false, true})
        for (const Key& lhs : keys)
            for (const Key& rhs : keys) {
                if (compare_key(lhs, rhs, signed_order) !=
                    reference_compare(lhs, rhs, signed_order)) {
                    std::cerr << "source comparator mismatch\n";
                    std::exit(1);
                }
                ++cases;
            }
    return cases;
}

struct KeyLess {
    bool signed_order = false;
    bool operator()(const Key& lhs, const Key& rhs) const
    {
        return compare_key(lhs, rhs, signed_order) < 0;
    }
};

static Key unsigned_key(uint32_t value, unsigned width)
{
    Key key(width, '0');
    for (unsigned bit = 0; bit < width; ++bit)
        if ((value >> bit) & 1U)
            key[bit] = '1';
    return key;
}

static std::vector<Key> make_keys(unsigned count)
{
    constexpr unsigned width = 18;
    std::vector<Key> keys;
    keys.reserve(count + 4);
    for (unsigned i = 0; i < count; ++i)
        keys.push_back(unsigned_key(i, width));
    for (const auto [position, symbol] : std::vector<std::pair<unsigned, char>>{
             {0, 'X'}, {0, 'Z'}, {5, 'X'}, {5, 'Z'}}) {
        Key key(width, '0');
        key[position] = symbol;
        keys.push_back(key);
    }
    return keys;
}

static std::vector<Key> sorted_reference(std::vector<Key> keys)
{
    comparisons = 0;
    std::sort(keys.begin(), keys.end(), KeyLess{});
    return keys;
}

static bool full_scan_successor(const std::map<std::string, Key>& entries, Key& key,
                                bool signed_order = false)
{
    auto best = entries.end();
    for (auto cur = entries.begin(); cur != entries.end(); ++cur) {
        ++scanned_entries;
        if (compare_key(cur->second, key, signed_order) <= 0)
            continue;
        if (best == entries.end() ||
            compare_key(cur->second, best->second, signed_order) < 0)
            best = cur;
    }
    if (best == entries.end())
        return false;
    key = best->second;
    return true;
}

static uint64_t check_current_next_order()
{
    const char symbols[] = {'0', '1', 'X', 'Z'};
    std::vector<Key> keys;
    for (unsigned width = 1; width <= 4; ++width) {
        unsigned limit = 1;
        for (unsigned i = 0; i < width; ++i)
            limit *= 4;
        for (unsigned encoding = 0; encoding < limit; ++encoding) {
            unsigned value = encoding;
            Key key(width);
            for (unsigned bit = 0; bit < width; ++bit) {
                key[bit] = symbols[value & 3U];
                value >>= 2;
            }
            keys.push_back(key);
        }
    }

    uint64_t successor_steps = 0;
    for (bool signed_order : {false, true}) {
        const std::vector<Key> expected = [&] {
            std::vector<Key> sorted = keys;
            std::sort(sorted.begin(), sorted.end(), KeyLess{signed_order});
            return sorted;
        }();
        std::map<std::string, Key> entries;
        for (const Key& key : keys)
            entries.emplace(raw_key(key), key);
        Key cursor;
        if (signed_order) {
            cursor.assign(5, '0');
            cursor[4] = '1'; // -16, below every signed key of width <= 4
        }
        scanned_entries = 0;
        size_t emitted = 0;
        while (full_scan_successor(entries, cursor, signed_order)) {
            if (emitted >= expected.size() || cursor != expected[emitted]) {
                std::cerr << "current next() order mismatch for short mixed-width keys\n";
                std::exit(1);
            }
            ++emitted;
        }
        if (emitted != expected.size()) {
            std::cerr << "current next() omitted short mixed-width keys\n";
            std::exit(1);
        }
        successor_steps += emitted;
    }
    return successor_steps;
}

template <class F>
static uint64_t elapsed_ns(F&& fn)
{
    const auto start = Clock::now();
    fn();
    return static_cast<uint64_t>(
        std::chrono::duration_cast<std::chrono::nanoseconds>(Clock::now() - start).count());
}

int main(int argc, char** argv)
{
    const unsigned scan_count = argc > 1 ? static_cast<unsigned>(std::strtoul(argv[1], nullptr, 10)) : 1024;
    const unsigned indexed_count = argc > 2 ? static_cast<unsigned>(std::strtoul(argv[2], nullptr, 10)) : 262144;
    if (!scan_count || scan_count > 4096 || !indexed_count || indexed_count > 262144) {
        std::cerr << "usage: flash_aa_walk [scan_count<=4096] [indexed_count<=262144]\n";
        return 2;
    }
    const uint64_t comparator_cases = check_comparator_exhaustive();
    const uint64_t mixed_width_successors = check_current_next_order();

    // The current vector-key implementation scans the backing map for every
    // successor. Cap this O(N^2) path at 4,096 entries; other variants use the
    // full 262,144-key Flash shape by default.
    const std::vector<Key> scan_keys = make_keys(scan_count);
    const std::vector<Key> scan_expected = sorted_reference(scan_keys);
    std::map<std::string, Key> scan_entries;
    const uint64_t scan_build_ns = elapsed_ns([&] {
        for (const Key& key : scan_keys)
            scan_entries.emplace(raw_key(key), key);
    });
    comparisons = 0;
    scanned_entries = 0;
    uint64_t scan_successors = 0;
    const uint64_t scan_walk_ns = elapsed_ns([&] {
        Key cursor = unsigned_key(0, 17); // just below the 18-bit zero key
        while (full_scan_successor(scan_entries, cursor)) {
            if (scan_successors >= scan_expected.size() ||
                cursor != scan_expected[scan_successors]) {
                std::cerr << "full-scan successor order mismatch\n";
                std::exit(1);
            }
            ++scan_successors;
        }
    });
    if (scan_successors != scan_expected.size()) {
        std::cerr << "full-scan iteration lost keys\n";
        return 1;
    }
    const uint64_t scan_compare_calls = comparisons;
    const uint64_t scan_scanned_entries = scanned_entries;

    const std::vector<Key> indexed_keys = make_keys(indexed_count);
    const std::vector<Key> indexed_expected = sorted_reference(indexed_keys);
    std::set<Key, KeyLess> ordered;
    comparisons = 0;
    const uint64_t tree_build_ns = elapsed_ns([&] {
        for (const Key& key : indexed_keys)
            ordered.insert(key);
    });
    const uint64_t tree_compare_calls_build = comparisons;
    uint64_t tree_upper_bound_calls = 0;
    uint64_t tree_upper_bound_successors = 0;
    comparisons = 0;
    const uint64_t tree_upper_bound_ns = elapsed_ns([&] {
        Key cursor = unsigned_key(0, 17);
        while (true) {
            const auto it = ordered.upper_bound(cursor);
            ++tree_upper_bound_calls;
            if (it == ordered.end())
                break;
            if (tree_upper_bound_successors >= indexed_expected.size() ||
                *it != indexed_expected[tree_upper_bound_successors]) {
                std::cerr << "tree upper_bound successor order mismatch\n";
                std::exit(1);
            }
            cursor = *it;
            ++tree_upper_bound_successors;
        }
    });
    const uint64_t tree_upper_bound_comparisons = comparisons;
    uint64_t tree_successors = 0;
    comparisons = 0;
    const uint64_t tree_walk_ns = elapsed_ns([&] {
        auto it = ordered.upper_bound(unsigned_key(0, 17));
        for (; it != ordered.end(); ++it) {
            if (tree_successors >= indexed_expected.size() ||
                *it != indexed_expected[tree_successors]) {
                std::cerr << "tree successor order mismatch\n";
                std::exit(1);
            }
            ++tree_successors;
        }
    });
    const uint64_t tree_compare_calls_walk = comparisons;
    if (tree_successors != indexed_expected.size()) {
        std::cerr << "tree iteration lost keys\n";
        return 1;
    }

    std::unordered_map<std::string, Key> hashed_storage;
    std::set<Key, KeyLess> hash_order;
    hashed_storage.reserve(indexed_keys.size());
    comparisons = 0;
    const uint64_t hash_index_build_ns = elapsed_ns([&] {
        for (const Key& key : indexed_keys) {
            const std::string raw = raw_key(key);
            hashed_storage.emplace(raw, key);
            hash_order.insert(key);
        }
    });
    const uint64_t hash_index_build_comparisons = comparisons;
    uint64_t hash_order_lookups = 0;
    uint64_t hash_upper_bound_calls = 0;
    uint64_t hash_upper_bound_lookups = 0;
    uint64_t hash_upper_bound_successors = 0;
    uint64_t hash_successors = 0;
    comparisons = 0;
    const uint64_t hash_upper_bound_ns = elapsed_ns([&] {
        Key cursor = unsigned_key(0, 17);
        while (true) {
            const auto it = hash_order.upper_bound(cursor);
            ++hash_upper_bound_calls;
            if (it == hash_order.end())
                break;
            const auto found = hashed_storage.find(raw_key(*it));
            ++hash_upper_bound_lookups;
            if (found == hashed_storage.end() || found->second != *it ||
                hash_upper_bound_successors >= indexed_expected.size() ||
                *it != indexed_expected[hash_upper_bound_successors]) {
                std::cerr << "hash-plus-order upper_bound mismatch\n";
                std::exit(1);
            }
            cursor = found->second;
            ++hash_upper_bound_successors;
        }
    });
    const uint64_t hash_upper_bound_comparisons = comparisons;
    comparisons = 0;
    const uint64_t hash_walk_ns = elapsed_ns([&] {
        auto it = hash_order.upper_bound(unsigned_key(0, 17));
        for (; it != hash_order.end(); ++it) {
            const auto found = hashed_storage.find(raw_key(*it));
            ++hash_order_lookups;
            if (found == hashed_storage.end() || found->second != *it ||
                hash_successors >= indexed_expected.size() ||
                *it != indexed_expected[hash_successors]) {
                std::cerr << "hash-plus-order iteration mismatch\n";
                std::exit(1);
            }
            ++hash_successors;
        }
    });
    const uint64_t hash_walk_comparisons = comparisons;
    if (hash_successors != indexed_expected.size() ||
        tree_upper_bound_successors != indexed_expected.size() ||
        hash_upper_bound_successors != indexed_expected.size() ||
        hashed_storage.size() != indexed_expected.size() ||
        hash_order.size() != indexed_expected.size()) {
        std::cerr << "hash-plus-order iteration lost semantic keys\n";
        return 1;
    }

    std::cout << "PASS comparator_pairs=" << comparator_cases
              << " mixed_width_XZ_next_successors=" << mixed_width_successors << '\n'
              << "scan count=" << scan_entries.size()
              << " build_ns=" << scan_build_ns
              << " full_iteration_ns=" << scan_walk_ns
              << " successors=" << scan_successors
              << " scanned_entries=" << scan_scanned_entries
              << " comparator_calls=" << scan_compare_calls << '\n'
              << "tree count=" << ordered.size()
              << " build_ns=" << tree_build_ns
              << " full_upper_bound_iteration_ns=" << tree_upper_bound_ns
              << " upper_bound_calls=" << tree_upper_bound_calls
              << " upper_bound_comparisons=" << tree_upper_bound_comparisons
              << " iterator_stream_ns=" << tree_walk_ns
              << " successors=" << tree_successors
              << " build_comparator_calls=" << tree_compare_calls_build
              << " iteration_comparator_calls=" << tree_compare_calls_walk << '\n'
              << "hash_plus_order count=" << hashed_storage.size()
              << " build_ns=" << hash_index_build_ns
              << " full_upper_bound_iteration_ns=" << hash_upper_bound_ns
              << " upper_bound_calls=" << hash_upper_bound_calls
              << " upper_bound_comparisons=" << hash_upper_bound_comparisons
              << " ordered_hash_lookups=" << hash_upper_bound_lookups
              << " iterator_stream_ns=" << hash_walk_ns
              << " successors=" << hash_successors
              << " iterator_hash_lookups=" << hash_order_lookups
              << " build_comparator_calls=" << hash_index_build_comparisons
              << " iteration_comparator_calls=" << hash_walk_comparisons << '\n'
              << "limits scan_count=" << scan_count
              << " indexed_count=" << indexed_count
              << " (262144-key scan intentionally not run)\n";
    return 0;
}
