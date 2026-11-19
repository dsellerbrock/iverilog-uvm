#include <string.h>
#include <sv_vpi_user.h>

struct verdict {
      unsigned time;
      unsigned start;
};

struct trace {
      const char *name;
      PLI_INT32 reason;
      unsigned count;
      struct verdict expected[7];
      unsigned seen;
      int registered;
};

static struct trace traces[] = {
      {"weak_until", cbAssertionSuccess, 4,
       {{20, 6}, {20, 13}, {20, 20}, {42, 42}}, 0, 0},
      {"strong_with", cbAssertionFailure, 7,
       {{20, 6}, {20, 13}, {20, 20}, {28, 28}, {35, 35}, {56, 49}, {56, 56}},
       0, 0},
      {"weak_finish", cbAssertionSuccess, 3, {{58, 6}, {58, 13}, {58, 20}}, 0, 0},
      {"strong_finish", cbAssertionFailure, 3, {{58, 6}, {58, 13}, {58, 20}}, 0, 0},
      {"off_finish", cbAssertionSuccess, 2, {{58, 6}, {58, 13}}, 0, 0},
      {"after_kill", cbAssertionSuccess, 1, {{58, 20}}, 0, 0},
      {"after_disable", cbAssertionSuccess, 1, {{58, 20}}, 0, 0},
};

static PLI_INT32 report(PLI_INT32 reason, p_vpi_time time, vpiHandle assertion,
                        p_vpi_attempt_info info, PLI_BYTE8 *user_data)
{
      struct trace *trace = (struct trace *)user_data;
      unsigned i = trace->seen++;
      (void)reason;
      (void)assertion;
      if (i >= trace->count || !info || time->high || info->attemptStartTime.high ||
          time->low != trace->expected[i].time ||
          info->attemptStartTime.low != trace->expected[i].start)
            vpi_printf("wrong callback identity for %s verdict %u\n", trace->name, i);
      return 0;
}

static PLI_INT32 watch(PLI_BYTE8 *user_data)
{
      vpiHandle iter = vpi_iterate(vpiAssertion, 0);
      vpiHandle assertion;
      (void)user_data;
      while (iter && (assertion = vpi_scan(iter))) {
            const char *name = vpi_get_str(vpiName, assertion);
            for (unsigned i = 0; i < sizeof traces / sizeof traces[0]; i++) {
                  struct trace *trace = &traces[i];
                  if (!strcmp(name, trace->name))
                        trace->registered = vpi_register_assertion_cb(
                              assertion, trace->reason, report, (PLI_BYTE8 *)trace) != 0;
            }
      }
      return 0;
}

static PLI_INT32 check(PLI_BYTE8 *user_data)
{
      (void)user_data;
      for (unsigned i = 0; i < sizeof traces / sizeof traces[0]; i++) {
            const struct trace *trace = &traces[i];
            if (!trace->registered || trace->seen != trace->count)
                  vpi_printf("wrong callback count for %s: %u of %u\n",
                             trace->name, trace->seen, trace->count);
      }
      return 0;
}

static void register_tasks(void)
{
      s_vpi_systf_data tf = {0};
      tf.type = vpiSysTask;
      tf.tfname = "$until_cohort_watch";
      tf.calltf = watch;
      vpi_register_systf(&tf);
      tf.tfname = "$until_cohort_check";
      tf.calltf = check;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
