/*
 * M12B-rest: exercise the extended assertion callback reasons.
 * cbAssertionStart fires at every sampled attempt tick;
 * cbAssertionDisable/cbAssertionEnable fire on $assertoff/$asserton
 * transitions; cbAssertionReset fires on $assertkill.
 * $check_assert_cb2(exp_start, exp_disable, exp_enable, exp_reset)
 * verifies the tallies with a single deterministic PASS/FAIL line.
 */
#include <vpi_user.h>
#include <sv_vpi_user.h>
#include <stdio.h>

static int n_start = 0;
static int n_disable = 0;
static int n_enable = 0;
static int n_reset = 0;

static PLI_INT32 assert_cb(PLI_INT32 reason, p_vpi_time t, vpiHandle a,
                           p_vpi_attempt_info info, PLI_BYTE8 *ud)
{
      (void)t; (void)a; (void)info; (void)ud;
      switch (reason) {
	  case cbAssertionStart:   n_start += 1;   break;
	  case cbAssertionDisable: n_disable += 1; break;
	  case cbAssertionEnable:  n_enable += 1;  break;
	  case cbAssertionReset:   n_reset += 1;   break;
	  default: break;
      }
      return 0;
}

static PLI_INT32 setup_calltf(PLI_BYTE8 *name)
{
      vpiHandle it, a;
      (void)name;
      it = vpi_iterate(vpiAssertion, NULL);
      if (it) while ((a = vpi_scan(it))) {
	    vpi_register_assertion_cb(a, cbAssertionStart, assert_cb, 0);
	    vpi_register_assertion_cb(a, cbAssertionDisable, assert_cb, 0);
	    vpi_register_assertion_cb(a, cbAssertionEnable, assert_cb, 0);
	    vpi_register_assertion_cb(a, cbAssertionReset, assert_cb, 0);
      }
      return 0;
}

static PLI_INT32 check_calltf(PLI_BYTE8 *name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv = vpi_iterate(vpiArgument, callh);
      s_vpi_value v;
      int exp[4] = {0,0,0,0};
      int idx = 0;
      vpiHandle arg;
      (void)name;
      if (argv) while ((arg = vpi_scan(argv)) && idx < 4) {
	    v.format = vpiIntVal;
	    vpi_get_value(arg, &v);
	    exp[idx++] = v.value.integer;
      }
      if (n_start == exp[0] && n_disable == exp[1]
	  && n_enable == exp[2] && n_reset == exp[3])
	    vpi_printf("PASS: start=%d disable=%d enable=%d reset=%d\n",
	               n_start, n_disable, n_enable, n_reset);
      else
	    vpi_printf("FAIL: start=%d/%d disable=%d/%d enable=%d/%d "
	               "reset=%d/%d\n", n_start, exp[0], n_disable, exp[1],
	               n_enable, exp[2], n_reset, exp[3]);
      return 0;
}

static void register_funcs(void)
{
      s_vpi_systf_data tf;
      tf.type = vpiSysTask;
      tf.tfname = "$setup_assert_cb2";
      tf.calltf = setup_calltf;
      tf.compiletf = 0;
      tf.sizetf = 0;
      tf.user_data = 0;
      vpi_register_systf(&tf);
      tf.tfname = "$check_assert_cb2";
      tf.calltf = check_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {
      register_funcs,
      0
};
