/* M12-2: verify attemptStartTime is the completing attempt's real
 * launch tick (fixed-latency start-time recovery). */
# include  <vpi_user.h>
# include  <sv_vpi_user.h>
# include  <string.h>

static PLI_INT32 acb(PLI_INT32 reason, p_vpi_time t, vpiHandle a,
		     p_vpi_attempt_info info, PLI_BYTE8 *ud)
{
      const char*nm = vpi_get_str(vpiName, a);
      (void)ud;
      vpi_printf("%s reason=%d evt=%d start=%d\n",
		 nm ? nm : "?", (int)reason, (int)t->low,
		 (int)info->attemptStartTime.low);
      return 0;
}

static PLI_INT32 setup(PLI_BYTE8*ud)
{
      vpiHandle it, a;
      (void)ud;
      it = vpi_iterate(vpiAssertion, 0);
      while (it && (a = vpi_scan(it))) {
	    vpi_register_assertion_cb(a, cbAssertionStart, acb, 0);
	    vpi_register_assertion_cb(a, cbAssertionSuccess, acb, 0);
	    vpi_register_assertion_cb(a, cbAssertionFailure, acb, 0);
      }
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$m12aa_setup";
      tf.calltf = setup;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
