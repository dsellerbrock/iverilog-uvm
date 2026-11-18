/* IEEE 1800 39.4.2 and 39.5.2, per-attempt steps for cover and not. */
# include  <vpi_user.h>
# include  <sv_vpi_user.h>
# include  <string.h>

#define IEEE_vpiDecompile 54

static PLI_INT32 step_cb(PLI_INT32 reason, p_vpi_time t, vpiHandle a,
                         p_vpi_attempt_info info, PLI_BYTE8 *ud)
{
      p_vpi_assertion_step_info step = info->detail.step;
      int i;
      (void)ud;
      vpi_printf("%s %s t=%u start=%u %d->%d [", vpi_get_str(vpiName, a),
                 reason == cbAssertionStepSuccess ? "STEP_OK" : "STEP_FAIL",
                 t->low, info->attemptStartTime.low,
                 step->stateFrom, step->stateTo);
      for (i = 0; i < step->matched_expression_count; ++i)
            vpi_printf("%s%s", i ? " " : "",
                       vpi_get_str(IEEE_vpiDecompile, step->matched_exprs[i]));
      vpi_printf("]\n");
      return 0;
}

static PLI_INT32 start_cb(PLI_INT32 reason, p_vpi_time t, vpiHandle a,
                          p_vpi_attempt_info info, PLI_BYTE8 *ud)
{
      (void)reason; (void)t; (void)ud;
      if (!vpi_control(vpiAssertionEnableStep, a, &info->attemptStartTime,
                       vpiAssertionClockSteps))
            vpi_printf("%s enable %u refused\n", vpi_get_str(vpiName, a),
                       info->attemptStartTime.low);
      return 0;
}

static PLI_INT32 setup(PLI_BYTE8 *ud)
{
      vpiHandle it = vpi_iterate(vpiAssertion, 0), a;
      (void)ud;
      while (it && (a = vpi_scan(it))) {
            if (!vpi_register_assertion_cb(a, cbAssertionStart, start_cb, 0)
                || !vpi_register_assertion_cb(a, cbAssertionStepSuccess, step_cb, 0)
                || !vpi_register_assertion_cb(a, cbAssertionStepFailure, step_cb, 0))
                  vpi_printf("%s callback registration refused\n",
                             vpi_get_str(vpiName, a));
      }
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$step_setup";
      tf.calltf = setup;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
