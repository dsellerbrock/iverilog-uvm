/*
 * M12B-cb: exercise assertion callbacks. At the start of simulation, for
 * every assertion in the design, register a cbAssertionSuccess and a
 * cbAssertionFailure callback. The callbacks tally per-reason counts.
 * $check_assert_cb(exp_success, exp_failure) verifies the tallies. Output
 * is a single deterministic PASS/FAIL line.
 */
#include <vpi_user.h>
#include <sv_vpi_user.h>
#include <stdio.h>
#include <string.h>

static int n_success = 0;
static int n_failure = 0;

static PLI_INT32 assert_cb(PLI_INT32 reason, p_vpi_time t, vpiHandle a,
                           p_vpi_attempt_info info, PLI_BYTE8 *ud)
{
      (void)t; (void)a; (void)info; (void)ud;
      if (reason == cbAssertionSuccess) n_success += 1;
      else if (reason == cbAssertionFailure) n_failure += 1;
      return 0;
}

/* Register callbacks on every assertion. Called from the design after
   time 0 (once the checkers' init blocks have registered themselves). */
static PLI_INT32 setup_calltf(PLI_BYTE8 *name)
{
      vpiHandle it, a;
      (void)name;
      it = vpi_iterate(vpiAssertion, NULL);
      if (it) while ((a = vpi_scan(it))) {
	    vpi_register_assertion_cb(a, cbAssertionSuccess, assert_cb, 0);
	    vpi_register_assertion_cb(a, cbAssertionFailure, assert_cb, 0);
      }
      return 0;
}

static PLI_INT32 check_calltf(PLI_BYTE8 *name)
{
      vpiHandle callh, argv, arg;
      s_vpi_value v;
      int exp_s = -1, exp_f = -1;
      (void)name;
      callh = vpi_handle(vpiSysTfCall, 0);
      argv  = vpi_iterate(vpiArgument, callh);
      if (argv) {
	    if ((arg = vpi_scan(argv))) { v.format = vpiIntVal; vpi_get_value(arg,&v); exp_s = v.value.integer; }
	    if ((arg = vpi_scan(argv))) { v.format = vpiIntVal; vpi_get_value(arg,&v); exp_f = v.value.integer; vpi_free_object(argv); }
      }
      if (n_success == exp_s && n_failure == exp_f)
	    vpi_printf("PASS: m12b-cb assertion callbacks (success=%d failure=%d)\n",
		       n_success, n_failure);
      else
	    vpi_printf("FAIL: m12b-cb got success=%d failure=%d expected %d/%d\n",
		       n_success, n_failure, exp_s, exp_f);
      return 0;
}

static void register_all(void)
{
      s_vpi_systf_data tf;

      memset(&tf, 0, sizeof tf);
      tf.type   = vpiSysTask;
      tf.tfname = "$check_assert_cb";
      tf.calltf = check_calltf;
      vpi_register_systf(&tf);

      memset(&tf, 0, sizeof tf);
      tf.type   = vpiSysTask;
      tf.tfname = "$setup_assert_cb";
      tf.calltf = setup_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_all, 0 };
