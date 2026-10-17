#ifndef IVL_vvp_trace_config_H
#define IVL_vvp_trace_config_H

#define VVP_TRACE_ENV_VARS(X) \
      X(IVL_ASSOC_TRACE) \
      X(IVL_ASSOC_TYPE_TRACE) \
      X(IVL_AUTO_CTX_WARN) \
      X(IVL_CALLF_DUMP_TREE) \
      X(IVL_CALLF_SYNC_DRAIN_LIMIT) \
      X(IVL_CALLF_SYNC_RESUME_LIMIT) \
      X(IVL_CALLF_TRACE) \
      X(IVL_CALLF_TRACE_LIMIT) \
      X(IVL_CALLF_TRACE_TARGET) \
      X(IVL_CLASS_TRACE) \
      X(IVL_CMPOBJ_TRACE) \
      X(IVL_COVERAGE_REPORT) \
      X(IVL_CTX_STATS) \
      X(IVL_CTX_TRACE) \
      X(IVL_EVENT_TRACE) \
      X(IVL_FLOW_TRACE) \
      X(IVL_FUNC_TRACE) \
      X(IVL_FUNC_TRACE_LIMIT) \
      X(IVL_LOAD_STR_TRACE) \
      X(IVL_LOAD_VEC_TRACE) \
      X(IVL_MBX_TRACE) \
      X(IVL_MUTATE_TRACE) \
      X(IVL_OBJ_ALIAS_TRACE) \
      X(IVL_PC_HOTTRACE) \
      X(IVL_PC_HOTTRACE_LIMIT) \
      X(IVL_PC_PROGRESS) \
      X(IVL_PC_PROGRESS_LIMIT) \
      X(IVL_PERF_STATS) \
      X(IVL_PROC_TRACE) \
      X(IVL_PROP_TRACE) \
      X(IVL_PUSH1_TRACE) \
      X(IVL_QUEUE_APPEND_TRACE) \
      X(IVL_RECV_OBJ_TRACE) \
      X(IVL_RECV_VEC_TRACE) \
      X(IVL_REGION_ASSERT) \
      X(IVL_REGION_SELFTEST) \
      X(IVL_REGION_TRACE) \
      X(IVL_SAME_TIME_LIMIT) \
      X(IVL_SCHED_DUMP_THREADS) \
      X(IVL_SEQ_TRACE) \
      X(IVL_STEP_TRACE) \
      X(IVL_STEP_TRACE_LIMIT) \
      X(IVL_STORE_OBJ_TRACE) \
      X(IVL_STORE_STR_TRACE) \
      X(IVL_TEST_NUL_TRACE) \
      X(IVL_TIME_TRACE_NS) \
      X(IVL_TRAMPOLINE_CALLF) \
      X(IVL_UNRESOLVED_DISPATCH_WARN) \
      X(IVL_VDISPATCH_TRACE) \
      X(IVL_VPI_CALL_TRACE) \
      X(IVL_VPI_CALL_TRACE_TARGET) \
      X(IVL_Z3_DYNDBG) \
      X(IVL_Z3_SOLVE_TRACE)

struct vvp_trace_config_s {
#define VVP_TRACE_ENV_FIELD(name) const char* name;
      VVP_TRACE_ENV_VARS(VVP_TRACE_ENV_FIELD)
#undef VVP_TRACE_ENV_FIELD
};

extern vvp_trace_config_s vvp_trace_config;
extern void vvp_trace_config_init(void);

#endif
