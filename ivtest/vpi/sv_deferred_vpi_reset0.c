#include <vpi_user.h>
#include <sv_vpi_user.h>
#include <stdio.h>
#include <string.h>

static int registered_before_simulation;

static int count_assertions(const char*scope_name)
{
      vpiHandle scope = vpi_handle_by_name(scope_name, 0);
      vpiHandle it, assertion;
      int count = 0;
      if (!scope) return -1;
      it = vpi_iterate(vpiAssertion, scope);
      if (!it) return 0;
      while ((assertion = vpi_scan(it))) count++;
      return count;
}

static PLI_INT32 check_registered_at_start(p_cb_data data)
{
      int count =
	    count_assertions("sv_deferred_vpi_reset0.vpi_process.vpi_target")
	    + count_assertions(
		  "sv_deferred_vpi_reset0.vpi_process.vpi_final_target")
	    + count_assertions(
		  "sv_deferred_vpi_reset0.vpi_process.vpi_shared")
	    + count_assertions(
		  "sv_deferred_vpi_reset0.vpi_process.vpi_final_shared");
      (void)data;
      registered_before_simulation = count == 6;
      vpi_printf(registered_before_simulation
		 ? "PASS: deferred assertions registered before simulation\n"
		 : "FAIL: deferred assertions missing before simulation\n");
      return 0;
}

static int reset_one(const char*scope_name)
{
      vpiHandle scope = vpi_handle_by_name(scope_name, 0);
      vpiHandle it, assertion;
      int found = 0;
      if (!scope) return 0;
      it = vpi_iterate(vpiAssertion, scope);
      if (!it) return 0;
      while ((assertion = vpi_scan(it))) {
	    if (found || !vpi_control(vpiAssertionReset, assertion)) {
		  vpi_free_object(it);
		  return 0;
	    }
	    found = 1;
      }
      return found;
}

static int reset_one_of_two(const char*scope_name)
{
      vpiHandle scope = vpi_handle_by_name(scope_name, 0);
      vpiHandle it, assertion;
      int count = 0, reset = 0, pass = 1;
      if (!scope) return 0;
      it = vpi_iterate(vpiAssertion, scope);
      if (!it) return 0;
      while ((assertion = vpi_scan(it))) {
	    count++;
	    if (!reset) {
		  if (!vpi_control(vpiAssertionReset, assertion))
			pass = 0;
		  reset = 1;
	    }
      }
      return pass && count == 2;
}

static PLI_INT32 reset_calltf(PLI_BYTE8*name)
{
      int pass;
      (void)name;
      pass = reset_one(
	    "sv_deferred_vpi_reset0.vpi_process.vpi_target");
      pass = reset_one(
	    "sv_deferred_vpi_reset0.vpi_process.vpi_final_target") && pass;
      pass = reset_one_of_two(
	    "sv_deferred_vpi_reset0.vpi_process.vpi_shared") && pass;
      pass = reset_one_of_two(
	    "sv_deferred_vpi_reset0.vpi_process.vpi_final_shared") && pass;
      pass = registered_before_simulation && pass;
      vpi_printf(pass ? "PASS: deferred assertion VPI reset\n"
		      : "FAIL: deferred assertion VPI reset\n");
      return 0;
}

static void register_reset(void)
{
      s_vpi_systf_data tf;
      s_cb_data cb;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$reset_deferred_assertions";
      tf.calltf = reset_calltf;
      vpi_register_systf(&tf);

      memset(&cb, 0, sizeof cb);
      cb.reason = cbStartOfSimulation;
      cb.cb_rtn = check_registered_at_start;
      vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = { register_reset, 0 };
