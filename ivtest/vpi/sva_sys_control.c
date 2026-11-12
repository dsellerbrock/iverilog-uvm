/* IEEE 1800-2023 39.5.1 assertion system control from VPI.
 * $sva_sys(op) calls vpi_control(op, NULL); $sva_sys(op, scope) passes the
 * scope argument's handle. $sva_cb_setup(assertion_name) puts a failure, a
 * start and a step-failure callback on that assertion; $sva_cb_dump prints
 * how often each fired. */
#include <stdio.h>
#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

static int n_fail, n_start, n_step;

static PLI_INT32 cb(PLI_INT32 reason, p_vpi_time t, vpiHandle a,
		    p_vpi_attempt_info info, PLI_BYTE8 *ud)
{
      (void)t; (void)a; (void)info; (void)ud;
      if (reason == cbAssertionFailure) n_fail += 1;
      else if (reason == cbAssertionStart) n_start += 1;
      else n_step += 1;
      return 0;
}

static PLI_INT32 sys_calltf(PLI_BYTE8 *ud)
{
      vpiHandle call = vpi_handle(vpiSysTfCall, 0);
      vpiHandle it = vpi_iterate(vpiArgument, call);
      vpiHandle op = vpi_scan(it), scope = vpi_scan(it);
      s_vpi_value v;
      (void)ud;
      if (scope) vpi_free_object(it);
      v.format = vpiIntVal;
      vpi_get_value(op, &v);
      {
	    s_vpi_time now;
	    PLI_INT32 rc = vpi_control(v.value.integer, scope);
	    now.type = vpiSimTime;
	    vpi_get_time(0, &now);
	    vpi_printf("%d: vpi_control(%d, %s) = %d\n", (int)now.low,
		       (int)v.value.integer,
		       scope ? vpi_get_str(vpiFullName, scope) : "NULL",
		       (int)rc);
      }
      return 0;
}

static PLI_INT32 setup_calltf(PLI_BYTE8 *ud)
{
      vpiHandle call = vpi_handle(vpiSysTfCall, 0);
      vpiHandle it = vpi_iterate(vpiArgument, call);
      vpiHandle arg = vpi_scan(it), a;
      s_vpi_value v;
      (void)ud;
      vpi_free_object(it);
      v.format = vpiStringVal;
      vpi_get_value(arg, &v);
      a = vpi_handle_by_name(v.value.str, 0);
      if (!a) { vpi_printf("no assertion %s\n", v.value.str); return 0; }
      vpi_register_assertion_cb(a, cbAssertionFailure, cb, 0);
      vpi_register_assertion_cb(a, cbAssertionStart, cb, 0);
      vpi_register_assertion_cb(a, cbAssertionStepFailure, cb, 0);
      vpi_register_assertion_cb(a, cbAssertionStepSuccess, cb, 0);
      return 0;
}

static PLI_INT32 dump_calltf(PLI_BYTE8 *ud)
{
      (void)ud;
      vpi_printf("callbacks: failure %d, start %d, step %d\n",
		 n_fail, n_start, n_step);
      return 0;
}

static void reg(const char *name, PLI_INT32 (*f)(PLI_BYTE8 *))
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = (PLI_BYTE8 *)name;
      tf.calltf = f;
      vpi_register_systf(&tf);
}

static void startup(void)
{
      reg("$sva_sys", sys_calltf);
      reg("$sva_cb_setup", setup_calltf);
      reg("$sva_cb_dump", dump_calltf);
}

void (*vlog_startup_routines[])(void) = { startup, 0 };
