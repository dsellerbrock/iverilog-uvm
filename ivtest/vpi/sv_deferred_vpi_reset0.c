#include <vpi_user.h>
#include <sv_vpi_user.h>
#include <stdio.h>
#include <string.h>

static int registered_before_simulation;
static int deferred_metadata_valid;
static int assertion_reset_callbacks;
static int assertion_disable_callbacks;
static int assertion_enable_callbacks;
static int reset_control_valid = 1;

static PLI_INT32 assertion_reset_cb(PLI_INT32 reason, p_vpi_time time,
				    vpiHandle assertion,
				    p_vpi_attempt_info attempt,
				    PLI_BYTE8* user_data)
{
      (void)time;
      (void)assertion;
      (void)attempt;
      (void)user_data;
      if (reason == cbAssertionReset) assertion_reset_callbacks++;
      return 0;
}

static PLI_INT32 assertion_control_cb(PLI_INT32 reason, p_vpi_time time,
				      vpiHandle assertion,
				      p_vpi_attempt_info attempt,
				      PLI_BYTE8* user_data)
{
      (void)time;
      (void)assertion;
      (void)attempt;
      (void)user_data;
      if (reason == cbAssertionDisable) assertion_disable_callbacks++;
      if (reason == cbAssertionEnable) assertion_enable_callbacks++;
      return 0;
}

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

static int check_deferred_metadata(const char*scope_name, int expected_type,
				   const char*expected_type_name,
				   int expected_line)
{
      vpiHandle scope = vpi_handle_by_name(scope_name, 0);
      vpiHandle it, assertion;
      int count = 0;
      if (!scope) return 0;
      it = vpi_iterate(vpiAssertion, scope);
      if (!it) return 0;
      while ((assertion = vpi_scan(it))) {
	    const char*file = vpi_get_str(vpiFile, assertion);
	    const char*type_name = vpi_get_str(vpiType, assertion);
	    if (vpi_get(vpiType, assertion) != expected_type) continue;
	    if (vpi_get(vpiLineNo, assertion) != expected_line
		|| !file || !strstr(file, "sv_deferred_vpi_reset0.v")
		|| !type_name || strcmp(type_name, expected_type_name) != 0) {
		  vpi_free_object(it);
		  return 0;
	    }
	    count++;
      }
      return count == 1;
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
		  "sv_deferred_vpi_reset0.vpi_process.vpi_final_shared")
	    + count_assertions(
		  "sv_deferred_vpi_reset0.vpi_process.vpi_kinds");
      (void)data;
      registered_before_simulation = count == 8;
      deferred_metadata_valid = check_deferred_metadata(
	    "sv_deferred_vpi_reset0.vpi_process.vpi_target",
	    vpiImmediateAssert, "vpiImmediateAssert", 7)
	    && check_deferred_metadata(
		  "sv_deferred_vpi_reset0.vpi_process.vpi_kinds",
	    vpiImmediateAssume, "vpiImmediateAssume", 29)
	    && check_deferred_metadata(
		  "sv_deferred_vpi_reset0.vpi_process.vpi_kinds",
		  vpiImmediateCover, "vpiImmediateCover", 30);
      vpi_printf(registered_before_simulation
		 ? "PASS: deferred assertions registered before simulation\n"
		 : "FAIL: deferred assertions missing before simulation\n");
      vpi_printf(deferred_metadata_valid
		 ? "PASS: deferred assertion VPI source metadata\n"
		 : "FAIL: deferred assertion VPI source metadata\n");
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
	    if (found
		|| !vpi_register_assertion_cb(assertion, cbAssertionReset,
					     assertion_reset_cb, 0)
		|| !vpi_control(vpiAssertionReset, assertion)) {
		  vpi_free_object(it);
		  return 0;
	    }
	    found = 1;
      }
      return found;
}

static vpiHandle deferred_target_assertion_(void)
{
	  vpiHandle scope = vpi_handle_by_name(
	    "sv_deferred_vpi_reset0.vpi_process.vpi_target", 0);
	  vpiHandle it, assertion;
	  if (!scope) return 0;
	  it = vpi_iterate(vpiAssertion, scope);
	  if (!it) return 0;
	  assertion = vpi_scan(it);
	  if (!assertion || vpi_scan(it)) {
	    vpi_free_object(it);
	    return 0;
	  }
	  vpi_free_object(it);
	  return assertion;
}

static PLI_INT32 disable_reset_target_calltf(PLI_BYTE8*name)
{
	  vpiHandle assertion = deferred_target_assertion_();
	  int reset_before = assertion_reset_callbacks;
	  int disable_before = assertion_disable_callbacks;
	  int enable_before = assertion_enable_callbacks;
	  (void)name;
	  reset_control_valid = assertion
	    && vpi_register_assertion_cb(assertion, cbAssertionReset,
					 assertion_reset_cb, 0)
	    && vpi_register_assertion_cb(assertion, cbAssertionDisable,
					 assertion_control_cb, 0)
	    && vpi_register_assertion_cb(assertion, cbAssertionEnable,
					 assertion_control_cb, 0)
	    && vpi_control(vpiAssertionDisable, assertion)
	    && vpi_control(vpiAssertionReset, assertion)
	    && assertion_reset_callbacks == reset_before + 1
	    && assertion_disable_callbacks == disable_before + 1
	    && assertion_enable_callbacks == enable_before;
	  return 0;
}

static PLI_INT32 enable_target_calltf(PLI_BYTE8*name)
{
	  vpiHandle assertion = deferred_target_assertion_();
	  int enable_before = assertion_enable_callbacks;
	  (void)name;
	  reset_control_valid = assertion && reset_control_valid
	    && vpi_control(vpiAssertionEnable, assertion)
	    && assertion_enable_callbacks == enable_before + 1;
	  return 0;
}

static int reset_one_of_two(const char*scope_name)
{
      vpiHandle scope = vpi_handle_by_name(scope_name, 0);
      vpiHandle it, assertion;
      int count = 0, reset = 0, pass = 1;
      int callbacks_before = assertion_reset_callbacks;
      if (!scope) return 0;
      it = vpi_iterate(vpiAssertion, scope);
      if (!it) return 0;
      while ((assertion = vpi_scan(it))) {
	    count++;
	    if (!vpi_register_assertion_cb(assertion, cbAssertionReset,
					   assertion_reset_cb, 0))
		  pass = 0;
	    if (!reset) {
		  if (!vpi_control(vpiAssertionReset, assertion))
			pass = 0;
		  reset = 1;
	    }
      }
      return pass && count == 2
	    && assertion_reset_callbacks == callbacks_before + 1;
}

static PLI_INT32 reset_calltf(PLI_BYTE8*name)
{
      int pass;
      (void)name;
	/* The target was already disabled/reset/re-enabled around repeated
	   executions. Keep its final queued report to verify only the re-enabled
	   attempt reports. */
	  pass = reset_control_valid;
	  pass = reset_one(
	    "sv_deferred_vpi_reset0.vpi_process.vpi_final_target") && pass;
      pass = reset_one_of_two(
	    "sv_deferred_vpi_reset0.vpi_process.vpi_shared") && pass;
      pass = reset_one_of_two(
	    "sv_deferred_vpi_reset0.vpi_process.vpi_final_shared") && pass;
      pass = assertion_reset_callbacks == 4 && pass;
      pass = assertion_disable_callbacks == 1 && pass;
      pass = assertion_enable_callbacks == 1 && pass;
      pass = registered_before_simulation && pass;
      pass = deferred_metadata_valid && pass;
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
	  tf.tfname = "$disable_reset_deferred_target";
	  tf.calltf = disable_reset_target_calltf;
	  vpi_register_systf(&tf);

	  memset(&tf, 0, sizeof tf);
	  tf.type = vpiSysTask;
	  tf.tfname = "$enable_deferred_target";
	  tf.calltf = enable_target_calltf;
	  vpi_register_systf(&tf);

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
