#include <vpi_user.h>
#include <sv_vpi_user.h>
#include <stdio.h>
#include <string.h>

static int registered_assertions;
static int top_reset_callbacks;
static int child_reset_callbacks;
static int top_disable_callbacks;
static int child_disable_callbacks;

static PLI_INT32 assertion_reset_cb(PLI_INT32 reason, p_vpi_time time,
				    vpiHandle assertion,
				    p_vpi_attempt_info attempt,
				    PLI_BYTE8* user_data)
{
      const char*name;
      (void)time;
      (void)attempt;
      (void)user_data;
      name = vpi_get_str(vpiFullName, assertion);
      if (reason == cbAssertionDisable) {
	    if (name && strstr(name, ".vpi_target"))
		  top_disable_callbacks++;
	    else if (name && strstr(name, ".child_process"))
		  child_disable_callbacks++;
      } else if (reason == cbAssertionReset) {
	    if (name && strstr(name, ".vpi_target"))
		  top_reset_callbacks++;
	    else if (name && strstr(name, ".child_process"))
		  child_reset_callbacks++;
      }
      return 0;
}

static int register_scope_assertions(const char*scope_name)
{
      vpiHandle scope = vpi_handle_by_name(scope_name, 0);
      vpiHandle it, assertion;
      int count = 0;
      if (!scope) return 0;
      it = vpi_iterate(vpiAssertion, scope);
      if (!it) return 0;
      while ((assertion = vpi_scan(it))) {
	    if (!vpi_register_assertion_cb(assertion, cbAssertionReset,
					   assertion_reset_cb, 0)
		|| !vpi_register_assertion_cb(assertion, cbAssertionDisable,
					      assertion_reset_cb, 0))
		  continue;
	    registered_assertions++;
	    count++;
      }
      return count;
}

static PLI_INT32 register_assertions_at_start(p_cb_data data)
{
      (void)data;
      register_scope_assertions(
	    "sv_deferred_vpi_kill0.vpi_target");
      register_scope_assertions(
	    "sv_deferred_vpi_kill0.child.child_process");
      vpi_printf(registered_assertions == 2
		 ? "PASS: deferred kill callbacks registered\n"
		 : "FAIL: deferred kill callbacks missing\n");
      return 0;
}

static PLI_INT32 check_kill_callbacks(PLI_BYTE8*name)
{
      int pass = registered_assertions == 2
	    && top_reset_callbacks == 1
	    && child_reset_callbacks == 0
	    && top_disable_callbacks == 1
	    && child_disable_callbacks == 0;
      (void)name;
      vpi_printf(pass ? "PASS: selected deferred kill disable/reset callbacks\n"
		      : "FAIL: selected deferred kill disable/reset callbacks\n");
      return 0;
}

static void register_tasks(void)
{
      s_vpi_systf_data tf;
      s_cb_data cb;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$check_deferred_kill_callbacks";
      tf.calltf = check_kill_callbacks;
      vpi_register_systf(&tf);

      memset(&cb, 0, sizeof cb);
      cb.reason = cbStartOfSimulation;
      cb.cb_rtn = register_assertions_at_start;
      vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
