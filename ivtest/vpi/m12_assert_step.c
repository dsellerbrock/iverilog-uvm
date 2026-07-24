/* M12-1: cbAssertionStepSuccess/StepFailure delivery, and the step
 * detail carried in s_vpi_attempt_info.detail.step. */
# include  <vpi_user.h>
# include  <sv_vpi_user.h>
# include  <string.h>

static PLI_INT32 acb(PLI_INT32 reason, p_vpi_time t, vpiHandle a,
		     p_vpi_attempt_info info, PLI_BYTE8 *ud)
{
      const char*w = "?";
      (void)a; (void)ud;
      switch (reason) {
	  case cbAssertionStart:       w = "START";     break;
	  case cbAssertionSuccess:     w = "SUCCESS";   break;
	  case cbAssertionFailure:     w = "FAILURE";   break;
	  case cbAssertionStepSuccess: w = "STEP_OK";   break;
	  case cbAssertionStepFailure: w = "STEP_FAIL"; break;
	  default: break;
      }
      if (reason == cbAssertionStepSuccess
	  || reason == cbAssertionStepFailure) {
	      /* the step detail union member must be usable */
	    vpi_printf("%s t=%d step(cnt=%d from=%d to=%d)\n", w, (int)t->low,
		       (int)info->detail.step->matched_expression_count,
		       (int)info->detail.step->stateFrom,
		       (int)info->detail.step->stateTo);
      } else {
	    vpi_printf("%s t=%d start=%d\n", w, (int)t->low,
		       (int)info->attemptStartTime.low);
      }
      return 0;
}

static PLI_INT32 setup(PLI_BYTE8*ud)
{
      vpiHandle it, a;
      (void)ud;
      it = vpi_iterate(vpiAssertion, 0);
      while (it && (a = vpi_scan(it))) {
	    vpi_register_assertion_cb(a, cbAssertionStepSuccess, acb, 0);
	    vpi_register_assertion_cb(a, cbAssertionStepFailure, acb, 0);
	    vpi_register_assertion_cb(a, cbAssertionFailure, acb, 0);
      }
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$m12as_setup";
      tf.calltf = setup;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
