#include "svdpi.h"
#include "vpi_user.h"

/* IEEE 1800 H.8.2: exported tasks have an int status result even though the
 * SystemVerilog task declaration has no result type. The generated export
 * stubs define these same standard signatures. */
extern int sv_normal_task(void);
extern int sv_direct_task(void);
extern int sv_ancestor_task(void);
extern int sv_disable_function_caller(void);

enum observation {
      OBS_NORMAL_STATUS = 0,
      OBS_NORMAL_QUERY = 1,
      OBS_NORMAL_CONTINUED = 2,
      OBS_DIRECT_STATUS = 3,
      OBS_DIRECT_QUERY = 4,
      OBS_DIRECT_CONTINUED = 5,
      OBS_ANCESTOR_STATUS = 6,
      OBS_ANCESTOR_QUERY = 7,
      OBS_ANCESTOR_RESUMED = 8,
      OBS_ANCESTOR_CLEANUP = 9,
      OBS_FUNCTION_QUERY = 10,
      OBS_FUNCTION_RESUMED = 11,
      OBS_FUNCTION_CLEANUP = 12,
      OBS_FUNCTION_ACKED = 13,
      OBS_CONCURRENT_STATUS_0 = 14,
      OBS_CONCURRENT_QUERY_0 = 15,
      OBS_CONCURRENT_STATUS_1 = 16,
      OBS_CONCURRENT_QUERY_1 = 17,
      OBS_REENTRY_STATUS = 18,
      OBS_REENTRY_QUERY = 19,
      OBS_REENTRY_RESUMED = 20,
      OBS_REENTRY_CLEANUP = 21,
      OBS_VPI_CONTEXT_ERROR_0 = 22,
      OBS_VPI_CONTEXT_ERROR_1 = 23
};

static int normal_status = -1;
static int normal_query = -1;
static int normal_continued;

static int direct_status = -1;
static int direct_query = -1;
static int direct_continued;

static int ancestor_status = -1;
static int ancestor_query = -1;
static int ancestor_resumed;
static int ancestor_cleanup;

static int function_query = -1;
static int function_resumed;
static int function_cleanup;
static int function_acked;
static int concurrent_status[2] = {-1, -1};
static int concurrent_query[2] = {-1, -1};
static int reentry_status = -1;
static int reentry_query = -1;
static int reentry_resumed;
static int reentry_cleanup;
static int vpi_context_error[2];

extern int sv_concurrent_task(int id);
extern int sv_reentry_delay_task(void);
extern int sv_reentry_disable_caller(void);
extern int sv_vpi_context_delay_task(int id);

/* Imported DPI tasks use their C int result to acknowledge the state that was
 * observed after the export returns: 0 for a normal call, 1 for a disabled
 * call. Returning the query makes the test protocol-correct even if a status
 * observation fails independently. */
int c_normal(void)
{
      normal_status = sv_normal_task();
      normal_query = svIsDisabledState();
      normal_continued += 1;
      return normal_query ? 1 : 0;
}

int c_direct(void)
{
      direct_status = sv_direct_task();
      direct_query = svIsDisabledState();
      direct_continued += 1;
      return direct_query ? 1 : 0;
}

int c_ancestor(void)
{
      ancestor_status = sv_ancestor_task();
      ancestor_resumed += 1;
      ancestor_query = svIsDisabledState();
      if (ancestor_query)
            ancestor_cleanup += 1;
      return ancestor_query ? 1 : 0;
}

int c_concurrent(int id)
{
      concurrent_status[id] = sv_concurrent_task(id);
      concurrent_query[id] = svIsDisabledState();
      return concurrent_query[id] ? 1 : 0;
}

/* Resume from a normally completing time-consuming export, then re-enter SV
 * synchronously and disable this import's ancestor. The old export child and
 * imported-task vthread are still part of the scheduler's resume frame while
 * the second export runs, so this also checks their lifetime/owning-reap path. */
int c_resumed_reentry(void)
{
      reentry_status = sv_reentry_delay_task();
      reentry_resumed += 1;
      (void)sv_reentry_disable_caller();
      reentry_query = svIsDisabledState();
      if (reentry_query)
            reentry_cleanup += 1;
      return reentry_query ? 1 : 0;
}

/* After scheduler resume, resolve and write the caller's automatic local.
 * The two concurrent callers must retain distinct VPI activation contexts. */
int c_resumed_vpi_context(int id)
{
      int status = sv_vpi_context_delay_task(id);
      vpiHandle probe;
      s_vpi_value value;

      if (status != 0)
            return status;
      probe = vpi_handle_by_name(
            "m10l_dpi_disable_protocol_test.run_vpi_context_case.cleanup_probe",
            0);
      if (!probe) {
            vpi_context_error[id] = 1;
            return 0;
      }

      value.format = vpiIntVal;
      value.value.integer = 37 + id;
      vpi_put_value(probe, &value, 0, vpiNoDelay);
      return 0;
}

/* Imported functions acknowledge with the API rather than their result. Once
 * the query reports disabled, this code performs only local cleanup and the
 * acknowledgment; 35.9(d) forbids another exported-subroutine call. */
int c_disabled_function(void)
{
      (void)sv_disable_function_caller();
      function_resumed += 1;
      function_query = svIsDisabledState();
      if (function_query) {
            function_cleanup += 1;
            svAckDisabledState();
            function_acked += 1;
      }
      return -1; /* Undefined to SystemVerilog while the disable is active. */
}

int c_observe(int selector)
{
      switch (selector) {
          case OBS_NORMAL_STATUS: return normal_status;
          case OBS_NORMAL_QUERY: return normal_query;
          case OBS_NORMAL_CONTINUED: return normal_continued;
          case OBS_DIRECT_STATUS: return direct_status;
          case OBS_DIRECT_QUERY: return direct_query;
          case OBS_DIRECT_CONTINUED: return direct_continued;
          case OBS_ANCESTOR_STATUS: return ancestor_status;
          case OBS_ANCESTOR_QUERY: return ancestor_query;
          case OBS_ANCESTOR_RESUMED: return ancestor_resumed;
          case OBS_ANCESTOR_CLEANUP: return ancestor_cleanup;
          case OBS_FUNCTION_QUERY: return function_query;
          case OBS_FUNCTION_RESUMED: return function_resumed;
          case OBS_FUNCTION_CLEANUP: return function_cleanup;
          case OBS_FUNCTION_ACKED: return function_acked;
          case OBS_CONCURRENT_STATUS_0: return concurrent_status[0];
          case OBS_CONCURRENT_QUERY_0: return concurrent_query[0];
          case OBS_CONCURRENT_STATUS_1: return concurrent_status[1];
          case OBS_CONCURRENT_QUERY_1: return concurrent_query[1];
          case OBS_REENTRY_STATUS: return reentry_status;
          case OBS_REENTRY_QUERY: return reentry_query;
          case OBS_REENTRY_RESUMED: return reentry_resumed;
          case OBS_REENTRY_CLEANUP: return reentry_cleanup;
          case OBS_VPI_CONTEXT_ERROR_0: return vpi_context_error[0];
          case OBS_VPI_CONTEXT_ERROR_1: return vpi_context_error[1];
          default: return -999;
      }
}
