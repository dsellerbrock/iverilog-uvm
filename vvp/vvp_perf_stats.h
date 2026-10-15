#ifndef IVL_VVP_PERF_STATS_H
#define IVL_VVP_PERF_STATS_H

#ifdef VVP_PERF_STATS
#include "vthread.h"
#include <typeinfo>

typedef bool (*vvp_perf_opcode_t)(vthread_t, vvp_code_t);

void vvp_perf_stats_init(void);
void vvp_perf_stats_event_region(unsigned region, const char* name);
void vvp_perf_stats_thread_created(void);
void vvp_perf_stats_thread_wake(void);
void vvp_perf_stats_context_alloc(void);
void vvp_perf_stats_recv_vec4(const std::type_info& kind);
void vvp_perf_stats_opcode(vvp_perf_opcode_t previous,
                           vvp_perf_opcode_t current);
void vvp_perf_stats_time_list_walk(unsigned length);
void vvp_perf_stats_z3_context(void);
void vvp_perf_stats_z3_check(void);
void vvp_perf_stats_z3_model_eval(void);

#endif
#endif
