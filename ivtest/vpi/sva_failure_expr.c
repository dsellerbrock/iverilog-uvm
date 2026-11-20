/* IEEE 1800-2017 and 1800-2023 39.4.2. */
# include <vpi_user.h>
# include <sv_vpi_user.h>
# include <stdio.h>
# include <string.h>

struct probe {
      const char *name;
      unsigned step_start;
      vpiHandle step_expr;
      s_vpi_time step_time;
      unsigned count;
      char failures[12][160];
};

static struct probe probes[] = {
      {.name = "fixed_seq", .step_start = 45},
      {.name = "ranged_seq", .step_start = 55},
      {.name = "local_seq"},
      {.name = "disabled_seq"},
      {.name = "killed_seq"},
      {.name = "deep_seq"},
      {.name = "proc_seq"},
};

static PLI_INT32 start_cb(PLI_INT32 reason, p_vpi_time time, vpiHandle assertion,
                          p_vpi_attempt_info info, PLI_BYTE8 *ud)
{
      struct probe *probe = (struct probe *)ud;
      (void)reason;
      (void)time;
      if (info->attemptStartTime.high == 1 &&
          info->attemptStartTime.low == probe->step_start &&
          !vpi_control(vpiAssertionEnableStep, assertion,
                       &info->attemptStartTime, vpiAssertionClockSteps))
            vpi_printf("%s could not enable steps\n", probe->name);
      return 0;
}

static PLI_INT32 step_cb(PLI_INT32 reason, p_vpi_time time, vpiHandle assertion,
                         p_vpi_attempt_info info, PLI_BYTE8 *ud)
{
      struct probe *probe = (struct probe *)ud;
      p_vpi_assertion_step_info step = info->detail.step;
      (void)reason;
      (void)assertion;
      if (info->attemptStartTime.high != 1 ||
          info->attemptStartTime.low != probe->step_start ||
          !step || step->matched_expression_count <= 0 || probe->step_expr) {
            vpi_printf("%s unexpected failing step\n", probe->name);
      } else {
            probe->step_expr = step->matched_exprs[step->matched_expression_count - 1];
            probe->step_time = *time;
      }
      return 0;
}

static PLI_INT32 fail_cb(PLI_INT32 reason, p_vpi_time time, vpiHandle assertion,
                         p_vpi_attempt_info info, PLI_BYTE8 *ud)
{
      struct probe *probe = (struct probe *)ud;
      vpiHandle expr = info ? info->detail.failExpr : 0;
      const char *file = expr ? vpi_get_str(vpiFile, expr) : 0;
      const char *source = file ? strstr(file, "sva_failure_expr.sv") : 0;
      int source_ok = source && strcmp(source, "sva_failure_expr.sv") == 0 &&
            (source == file || source[-1] == '/' || source[-1] == '\\');
      int line = expr ? vpi_get(vpiLineNo, expr) : 0;
      const char *text = expr ? vpi_get_str(vpiDecompile, expr) : 0;
      const char *same_step = "";
      (void)reason;
      (void)assertion;
      if (!info || time->type != vpiSimTime || info->attemptStartTime.type != vpiSimTime) {
            vpi_printf("%s missing simulation timestamps\n", probe->name);
            return 0;
      }
      if (info->attemptStartTime.high == 1 &&
          info->attemptStartTime.low == probe->step_start) {
            same_step = expr && expr == probe->step_expr &&
                  time->high == probe->step_time.high && time->low == probe->step_time.low
                  ? " (same step handle)" : " (different step handle)";
      }
      if (probe->count == sizeof probe->failures / sizeof probe->failures[0]) {
            vpi_printf("Too many %s failures\n", probe->name);
            return 0;
      }
      snprintf(probe->failures[probe->count++], sizeof probe->failures[0],
               "%s t=%u:%u start=%u:%u failExpr=%s@%d%s%s", probe->name,
               (unsigned)time->high, (unsigned)time->low,
               (unsigned)info->attemptStartTime.high, (unsigned)info->attemptStartTime.low,
               text ? text : "NULL", line, source_ok ? "" : " (missing source)", same_step);
      return 0;
}

static PLI_INT32 watch_failures(PLI_BYTE8 *ud)
{
      unsigned i;
      (void)ud;
      for (i = 0; i < sizeof probes / sizeof probes[0]; ++i) {
            struct probe *probe = &probes[i];
            vpiHandle it = vpi_iterate(vpiAssertion, 0), assertion = 0;
            while (it && (assertion = vpi_scan(it))) {
                  if (strcmp(vpi_get_str(vpiName, assertion), probe->name) == 0) {
                        vpi_free_object(it);
                        break;
                  }
            }
            if (!assertion) {
                  vpi_printf("Missing assertion %s\n", probe->name);
                  continue;
            }
            if (!vpi_register_assertion_cb(assertion, cbAssertionFailure,
                                           fail_cb, (PLI_BYTE8 *)probe) ||
                !vpi_register_assertion_cb(assertion, cbAssertionStepFailure,
                                           step_cb, (PLI_BYTE8 *)probe) ||
                (probe->step_start &&
                 !vpi_register_assertion_cb(assertion, cbAssertionStart,
                                            start_cb, (PLI_BYTE8 *)probe)))
                  vpi_printf("%s could not register callbacks\n", probe->name);
      }
      return 0;
}

static PLI_INT32 print_failures(PLI_BYTE8 *ud)
{
      unsigned i, j;
      (void)ud;
      /* Check each assertion's own callback order. */
      for (i = 0; i < sizeof probes / sizeof probes[0]; ++i) {
            vpi_printf("%s failures=%u\n", probes[i].name, probes[i].count);
            for (j = 0; j < probes[i].count; ++j)
                  vpi_printf("%s\n", probes[i].failures[j]);
      }
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data tf = {0};
      tf.type = vpiSysTask;
      tf.tfname = "$watch_failures";
      tf.calltf = watch_failures;
      vpi_register_systf(&tf);
      tf.tfname = "$print_failures";
      tf.calltf = print_failures;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
