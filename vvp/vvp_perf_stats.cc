#include "config.h"
#include "vvp_perf_stats.h"

#ifdef VVP_PERF_STATS

#include "codes.h"
#include <array>
#include <cstdlib>
#include <stdint.h>
#include <functional>
#include <iostream>
#include <map>
#include <string>
#include <typeindex>
#include <utility>

namespace {
struct opcode_pair_less_s {
      bool operator()(const std::pair<vvp_perf_opcode_t, vvp_perf_opcode_t>& left,
                      const std::pair<vvp_perf_opcode_t, vvp_perf_opcode_t>& right) const
      {
            std::less<vvp_perf_opcode_t> less;
            if (less(left.first, right.first)) return true;
            if (less(right.first, left.first)) return false;
            return less(left.second, right.second);
      }
};

struct perf_stats_s {
      uint64_t thread_creations = 0;
      uint64_t thread_wakes = 0;
      uint64_t context_allocations = 0;
      uint64_t z3_contexts = 0;
      uint64_t z3_checks = 0;
      uint64_t z3_model_evaluations = 0;
      uint64_t z3_isolated_count_cache_hits = 0;
      uint64_t z3_hull_cache_hits = 0;
      std::array<uint64_t, 5> randomize_tiers = {{0}};
      uint64_t time_list_insertions = 0;
      uint64_t time_list_steps = 0;
      unsigned time_list_max = 0;
      std::array<uint64_t, 32> events_by_region = {{0}};
      std::array<const char*, 32> region_names = {{0}};
      std::map<std::type_index, uint64_t> functor_recv_vec4;
      std::map<vvp_perf_opcode_t, uint64_t, std::less<vvp_perf_opcode_t> > opcode_histogram;
      std::map<std::pair<vvp_perf_opcode_t, vvp_perf_opcode_t>, uint64_t,
               opcode_pair_less_s> opcode_pairs;
};

static perf_stats_s stats;
static bool stats_enabled = false;

static void json_string(std::ostream& out, const std::string& value)
{
      out << '"';
      for (std::string::const_iterator it = value.begin(); it != value.end(); ++it) {
            unsigned char ch = static_cast<unsigned char>(*it);
            switch (ch) {
                case '"': out << "\\\""; break;
                case '\\': out << "\\\\"; break;
                case '\n': out << "\\n"; break;
                case '\r': out << "\\r"; break;
                case '\t': out << "\\t"; break;
                default:
                  if (ch < 0x20) {
                        static const char hex[] = "0123456789abcdef";
                        out << "\\u00" << hex[ch >> 4] << hex[ch & 0x0f];
                  } else {
                        out << static_cast<char>(ch);
                  }
            }
      }
      out << '"';
}

static void dump_stats(void)
{
      if (!stats_enabled)
            return;

      std::map<std::string, uint64_t> opcode_names;
      std::map<std::string, uint64_t> pair_names;
      uint64_t callf_count = 0;
      uint64_t fork_count = 0;
      for (std::map<vvp_perf_opcode_t, uint64_t,
                    std::less<vvp_perf_opcode_t> >::const_iterator it =
                    stats.opcode_histogram.begin();
           it != stats.opcode_histogram.end(); ++it) {
            const char* name = vvp_opcode_mnemonic(it->first);
            opcode_names[name] += it->second;
            if (std::string(name).compare(0, 6, "%callf") == 0)
                  callf_count += it->second;
            if (std::string(name).compare(0, 5, "%fork") == 0)
                  fork_count += it->second;
      }
      for (std::map<std::pair<vvp_perf_opcode_t, vvp_perf_opcode_t>, uint64_t,
                    opcode_pair_less_s>::const_iterator it =
                    stats.opcode_pairs.begin();
           it != stats.opcode_pairs.end(); ++it) {
            const std::string previous = vvp_opcode_mnemonic(it->first.first);
            const std::string current = vvp_opcode_mnemonic(it->first.second);
            pair_names[previous + " -> " + current] += it->second;
      }

      std::cerr << "VVP_PERF_STATS {\"events_by_region\":{";
      bool comma = false;
      for (size_t idx = 0; idx < stats.events_by_region.size(); ++idx) {
            if (!stats.events_by_region[idx]) continue;
            if (comma) std::cerr << ',';
            json_string(std::cerr, stats.region_names[idx]
                                  ? stats.region_names[idx] : "unknown");
            std::cerr << ':' << stats.events_by_region[idx];
            comma = true;
      }
      std::cerr << "},\"thread_creations\":" << stats.thread_creations
                << ",\"thread_wakes\":" << stats.thread_wakes
                << ",\"context_allocations\":" << stats.context_allocations
                << ",\"functor_recv_vec4\":{";
      comma = false;
      for (std::map<std::type_index, uint64_t>::const_iterator it =
                    stats.functor_recv_vec4.begin();
           it != stats.functor_recv_vec4.end(); ++it) {
            if (comma) std::cerr << ',';
            json_string(std::cerr, it->first.name());
            std::cerr << ':' << it->second;
            comma = true;
      }
      std::cerr << "},\"callf\":" << callf_count
                << ",\"fork\":" << fork_count
                << ",\"opcode_histogram\":{";
      comma = false;
      for (std::map<std::string, uint64_t>::const_iterator it = opcode_names.begin();
           it != opcode_names.end(); ++it) {
            if (comma) std::cerr << ',';
            json_string(std::cerr, it->first);
            std::cerr << ':' << it->second;
            comma = true;
      }
      std::cerr << "},\"opcode_pairs\":{";
      comma = false;
      for (std::map<std::string, uint64_t>::const_iterator it = pair_names.begin();
           it != pair_names.end(); ++it) {
            if (comma) std::cerr << ',';
            json_string(std::cerr, it->first);
            std::cerr << ':' << it->second;
            comma = true;
      }
      std::cerr << "},\"scheduler_time_list\":{\"insertions\":"
                << stats.time_list_insertions
                << ",\"total_steps\":" << stats.time_list_steps
                << ",\"max_steps\":" << stats.time_list_max
                << "},\"z3\":{\"contexts\":" << stats.z3_contexts
                << ",\"checks\":" << stats.z3_checks
                << ",\"model_evaluations\":" << stats.z3_model_evaluations
                << ",\"isolated_count_cache_hits\":"
                << stats.z3_isolated_count_cache_hits
                << ",\"hull_cache_hits\":"
                << stats.z3_hull_cache_hits
                << "},\"randomize_tiers\":{";
      for (unsigned tier = 0; tier < stats.randomize_tiers.size(); ++tier) {
            if (tier) std::cerr << ',';
            std::cerr << "\"T" << tier << "\":" << stats.randomize_tiers[tier];
      }
      std::cerr << "}}" << std::endl;
}
}

void vvp_perf_stats_init(void)
{
      const char* env = std::getenv("IVL_PERF_STATS");
      stats_enabled = env && *env && std::string(env) != "0";
      if (stats_enabled)
            std::atexit(dump_stats);
}

void vvp_perf_stats_event_region(unsigned region, const char* name)
{
      if (!stats_enabled) return;
      if (region < stats.events_by_region.size()) {
            stats.events_by_region[region] += 1;
            stats.region_names[region] = name;
      }
}

void vvp_perf_stats_thread_created(void)
{
      if (stats_enabled) stats.thread_creations += 1;
}

void vvp_perf_stats_thread_wake(void)
{
      if (stats_enabled) stats.thread_wakes += 1;
}

void vvp_perf_stats_context_alloc(void)
{
      if (stats_enabled) stats.context_allocations += 1;
}

void vvp_perf_stats_recv_vec4(const std::type_info& kind)
{
      if (stats_enabled) stats.functor_recv_vec4[std::type_index(kind)] += 1;
}

void vvp_perf_stats_opcode(vvp_perf_opcode_t previous,
                           vvp_perf_opcode_t current)
{
      if (!stats_enabled) return;
      stats.opcode_histogram[current] += 1;
      if (previous)
            stats.opcode_pairs[std::make_pair(previous, current)] += 1;
}

void vvp_perf_stats_time_list_walk(unsigned length)
{
      if (!stats_enabled) return;
      stats.time_list_insertions += 1;
      stats.time_list_steps += length;
      if (length > stats.time_list_max)
            stats.time_list_max = length;
}

void vvp_perf_stats_z3_context(void)
{
      if (stats_enabled) stats.z3_contexts += 1;
}

void vvp_perf_stats_z3_check(void)
{
      if (stats_enabled) stats.z3_checks += 1;
}

void vvp_perf_stats_z3_model_eval(void)
{
      if (stats_enabled) stats.z3_model_evaluations += 1;
}

void vvp_perf_stats_z3_isolated_count_cache_hit(void)
{
      if (stats_enabled) stats.z3_isolated_count_cache_hits += 1;
}

void vvp_perf_stats_z3_hull_cache_hit(void)
{
      if (stats_enabled) stats.z3_hull_cache_hits += 1;
}

void vvp_perf_stats_randomize_tier(unsigned tier)
{
      if (stats_enabled && tier < stats.randomize_tiers.size())
            stats.randomize_tiers[tier] += 1;
}

#endif
