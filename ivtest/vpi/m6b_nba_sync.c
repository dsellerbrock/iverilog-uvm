/* M6B-2: cbNBASynch (IEEE 1800-2017 clause 38).
 *
 * $m6b_nba_sync_setup registers one callback of each simulation-time
 * reason at the next clock edge time, in an order deliberately opposite
 * to the region order, and each prints the value of `q' when it fires.
 *
 * q is driven by a nonblocking assignment at that edge, so its value at
 * the callback is the discriminator: a callback that runs before the NBA
 * region has drained sees the OLD value.
 *
 * The expected region order is
 *     cbNBASynch -> cbReadWriteSynch -> cbAtEndOfSimTime -> cbReadOnlySynch
 * with every one of them seeing the settled q.
 */
# include  <vpi_user.h>
# include  <stdlib.h>
# include  <string.h>
# include  <assert.h>

static vpiHandle q_handle = 0;

static PLI_INT32 report_cb(p_cb_data cb)
{
      s_vpi_value value;
      s_vpi_time now;

      value.format = vpiIntVal;
      vpi_get_value(q_handle, &value);

      now.type = vpiSimTime;
      vpi_get_time(0, &now);

      vpi_printf("%s at %u: q=%d\n", (char *)cb->user_data,
		 (unsigned)now.low, (int)value.value.integer);
      return 0;
}

static void register_at(PLI_INT32 reason, PLI_UINT32 when, const char*label)
{
      s_cb_data cb;
      s_vpi_time tm;

      memset(&cb, 0, sizeof cb);
      tm.type = vpiSimTime;
      tm.high = 0;
      tm.low  = when;
      tm.real = 0.0;

      cb.reason    = reason;
      cb.cb_rtn    = report_cb;
      cb.obj       = 0;
      cb.time      = &tm;
      cb.value     = 0;
      cb.user_data = (PLI_BYTE8 *)label;
      assert(vpi_register_cb(&cb) != 0);
}

static PLI_INT32 setup_calltf(char*xx)
{
      vpiHandle sys  = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv = vpi_iterate(vpiArgument, sys);
      s_vpi_time now;

      (void)xx;

      assert(argv);
      q_handle = vpi_scan(argv);
      assert(q_handle);

      now.type = vpiSimTime;
      vpi_get_time(0, &now);

	/* Registered in reverse region order on purpose: the drain
	   order must come from the scheduler, not from this list. */
      register_at(cbReadOnlySynch,  now.low + 5, "cbReadOnlySynch");
      register_at(cbAtEndOfSimTime, now.low + 5, "cbAtEndOfSimTime");
      register_at(cbReadWriteSynch, now.low + 5, "cbReadWriteSynch");
      register_at(cbNBASynch,       now.low + 5, "cbNBASynch");
      return 0;
}

static void setup_register(void)
{
      s_vpi_systf_data tf;

      memset(&tf, 0, sizeof tf);
      tf.type      = vpiSysTask;
      tf.tfname    = "$m6b_nba_sync_setup";
      tf.calltf    = setup_calltf;
      tf.compiletf = 0;
      tf.sizetf    = 0;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {
      setup_register,
      0
};
