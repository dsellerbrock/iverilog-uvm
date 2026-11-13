/* IEEE 1800-2023 39.4.2 / 39.5.2 per-attempt step callbacks. */
# include  <vpi_user.h>
# include  <sv_vpi_user.h>
# include  <string.h>

#define IEEE_vpiDecompile 54

static vpiHandle find(const char*name)
{
      vpiHandle it = vpi_iterate(vpiAssertion, 0), a;
      while (it && (a = vpi_scan(it))) {
	    if (strcmp(vpi_get_str(vpiName, a), name) == 0) {
		  vpi_free_object(it);
		  return a;
	    }
      }
      return 0;
}

static int ctl(int op, vpiHandle a, int start)
{
      s_vpi_time t;
      t.type = vpiSimTime;
      t.high = 0;
      t.low = start;
      if (op == vpiAssertionEnableStep)
	    return vpi_control(op, a, &t, vpiAssertionClockSteps);
      return vpi_control(op, a, &t);
}

static PLI_INT32 step_cb(PLI_INT32 reason, p_vpi_time t, vpiHandle a,
			 p_vpi_attempt_info info, PLI_BYTE8 *ud)
{
      p_vpi_assertion_step_info st = info->detail.step;
      int i;
      (void)ud;
      vpi_printf("%s %s t=%d start=%d %d->%d [",
		 vpi_get_str(vpiName, a),
		 reason == cbAssertionStepSuccess ? "STEP_OK" : "STEP_FAIL",
		 (int)t->low, (int)info->attemptStartTime.low,
		 (int)st->stateFrom, (int)st->stateTo);
      for (i = 0 ; i < st->matched_expression_count ; i += 1) {
	    const char*file = vpi_get_str(vpiFile, st->matched_exprs[i]);
	    int ok = file && strstr(file, "sva_step_attempt.sv") != 0;
	    vpi_printf("%s%s@%d%s", i ? " " : "",
		       vpi_get_str(IEEE_vpiDecompile, st->matched_exprs[i]),
		       (int)vpi_get(vpiLineNo, st->matched_exprs[i]),
		       ok ? "" : "(no file)");
      }
      vpi_printf("]\n");
      return 0;
}

/* Enable stepping from the attempt's own cbAssertionStart. */
static PLI_INT32 start_cb(PLI_INT32 reason, p_vpi_time t, vpiHandle a,
			  p_vpi_attempt_info info, PLI_BYTE8 *ud)
{
      int s = (int)info->attemptStartTime.low;
      (void)reason; (void)t;
      if (strcmp(ud, "seq") == 0 && s != 5 && s != 25) return 0;
      if (strcmp(ud, "win") == 0 && s != 25) return 0;
      if (strcmp(ud, "imp") == 0 && s != 5 && s != 15) return 0;
      if (strcmp(ud, "rep") == 0 && s != 25) return 0;
      if (strcmp(ud, "rim") == 0 && s != 5 && s != 15) return 0;
      if (s > 25) return 0;
      vpi_printf("%s enable %d -> %d\n", ud, s,
		 vpi_control(vpiAssertionEnableStep, a,
			     &info->attemptStartTime,
			     vpiAssertionClockSteps));
      return 0;
}

static void watch(const char*name, int enable_in_start)
{
      vpiHandle a = find(name);
      vpi_register_assertion_cb(a, cbAssertionStepSuccess, step_cb, 0);
      vpi_register_assertion_cb(a, cbAssertionStepFailure, step_cb, 0);
      if (enable_in_start)
	    vpi_register_assertion_cb(a, cbAssertionStart, start_cb,
				      (PLI_BYTE8*)name);
}

static PLI_INT32 setup(PLI_BYTE8*ud)
{
      vpiHandle seq = find("seq");
      (void)ud;
      watch("seq", 1);
      watch("win", 1);
      watch("imp", 1);
      watch("off", 0);
      watch("rep", 1);
      watch("rim", 1);
      watch("aim", 1);
      watch("nxt", 1);
      watch("nim", 1);
      watch("exl", 1);
      watch("exn", 1);
      vpi_printf("seq enable 45 ahead -> %d\n",
		 ctl(vpiAssertionEnableStep, seq, 45));
      vpi_printf("seq enable 35 ahead -> %d\n",
		 ctl(vpiAssertionEnableStep, seq, 35));
      vpi_printf("seq disable 35 ahead -> %d\n",
		 ctl(vpiAssertionDisableStep, seq, 35));
      return 0;
}

static PLI_INT32 late(PLI_BYTE8*ud)
{
      (void)ud;
      vpi_printf("seq enable 15 late -> %d\n",
		 ctl(vpiAssertionEnableStep, find("seq"), 15));
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
      tf.tfname = "$step_late";
      tf.calltf = late;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
