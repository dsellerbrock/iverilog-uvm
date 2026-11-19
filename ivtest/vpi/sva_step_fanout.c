#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

#define IEEE_vpiDecompile 54

static PLI_INT32 step_cb(PLI_INT32 reason, p_vpi_time t, vpiHandle a,
                         p_vpi_attempt_info info, PLI_BYTE8 *ud)
{
      p_vpi_assertion_step_info st = info->detail.step;
      int i;
      (void)ud;
      vpi_printf("%s %s t=%u start=%u %d->%d [", vpi_get_str(vpiName, a),
                 reason == cbAssertionStepSuccess ? "STEP_OK" : "STEP_FAIL",
                 t->low, info->attemptStartTime.low, st->stateFrom, st->stateTo);
      for (i = 0 ; i < st->matched_expression_count ; ++i) {
            vpiHandle expr = st->matched_exprs[i];
            const char *file = vpi_get_str(vpiFile, expr);
            int file_ok = file && strstr(file, "sva_step_fanout.sv");
            vpi_printf("%s%s@%d%s", i ? " " : "",
                       vpi_get_str(IEEE_vpiDecompile, expr),
                       vpi_get(vpiLineNo, expr), file_ok ? "" : "(wrong file)");
      }
      vpi_printf("]\n");
      return 0;
}

static PLI_INT32 start_cb(PLI_INT32 reason, p_vpi_time t, vpiHandle a,
                          p_vpi_attempt_info info, PLI_BYTE8 *ud)
{
      int enabled = vpi_control(vpiAssertionEnableStep, a,
                                &info->attemptStartTime, vpiAssertionClockSteps);
      (void)reason;
      (void)t;
      (void)ud;
      vpi_printf("%s enable %u -> %d\n", vpi_get_str(vpiName, a),
                 info->attemptStartTime.low, enabled);
      return 0;
}

static PLI_INT32 setup(PLI_BYTE8 *ud)
{
      vpiHandle it = vpi_iterate(vpiAssertion, 0), a;
      (void)ud;
      while (it && (a = vpi_scan(it))) {
            vpi_register_assertion_cb(a, cbAssertionStart, start_cb, 0);
            vpi_register_assertion_cb(a, cbAssertionStepSuccess, step_cb, 0);
            vpi_register_assertion_cb(a, cbAssertionStepFailure, step_cb, 0);
      }
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$fanout_steps";
      tf.calltf = setup;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
