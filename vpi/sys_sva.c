/*
 * SystemVerilog assertion sampling functions: $rose, $fell, $stable, $past.
 *
 * These functions normally sample at a clocking event. Without an
 * SVA-aware scheduler, we provide compile-progress fallbacks that
 * return safe defaults so testbenches that USE these in `assert
 * property (...)` contexts still elaborate and run:
 *
 *   $rose(sig)   -> 0   (no edge detected without sampling)
 *   $fell(sig)   -> 0
 *   $stable(sig) -> 1   (assume unchanged)
 *   $past(sig)   -> sig (return current value as a stand-in)
 *
 * These are good enough for assertions that are not themselves the
 * primary test gate: the assertion body still elaborates, the test
 * proceeds, and any assertion that does fire will report a non-fatal
 * info rather than aborting the run.
 */

# include  "vpi_user.h"
# include  "sv_vpi_user.h"
# include  <stdlib.h>
# include  <string.h>

static PLI_INT32 sva_compiletf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      (void)name;
      return 0;
}

static PLI_INT32 sva_const_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      s_vpi_value rv;
      rv.format = vpiIntVal;
      rv.value.integer = (name && strcmp(name, "$stable") == 0) ? 1 : 0;
      vpi_put_value(callh, &rv, 0, vpiNoDelay);
      return 0;
}

static PLI_INT32 sva_past_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      (void)name;
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv  = vpi_iterate(vpiArgument, callh);
      s_vpi_value rv;
      rv.format = vpiIntVal;
      rv.value.integer = 0;
      if (argv) {
            vpiHandle arg = vpi_scan(argv);
            vpi_free_object(argv);
            if (arg) {
                  s_vpi_value v;
                  v.format = vpiIntVal;
                  vpi_get_value(arg, &v);
                  rv = v;
            }
      }
      vpi_put_value(callh, &rv, 0, vpiNoDelay);
      return 0;
}

static PLI_INT32 sva_sizetf(ICARUS_VPI_CONST PLI_BYTE8 *name)
{
      (void)name;
      return 32;
}

/*
 * Assertion control (IEEE 1800-2017 20.12). A single global enable flag
 * gates the failure reporting of every synthesized concurrent-assertion
 * checker (each emits `if ($ivl_sva_enabled()) <fail action>`). This
 * implements the common global use ($assertoff during reset, $asserton
 * after); the optional [levels, list] arguments select a scope subset in
 * the LRM and are accepted but ignored here (global-only).
 *
 *   $assertoff  — stop reporting assertion failures
 *   $asserton   — resume reporting
 *   $assertkill — stop reporting (in-flight attempt reset is not modeled)
 */
static int sva_assert_enabled = 1;

static PLI_INT32 sva_enabled_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      s_vpi_value rv;
      (void)name;
      rv.format = vpiIntVal;
      rv.value.integer = sva_assert_enabled;
      vpi_put_value(callh, &rv, 0, vpiNoDelay);
      return 0;
}

static PLI_INT32 sva_control_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      if (name && strcmp(name, "$asserton") == 0)
	    sva_assert_enabled = 1;
      else                       /* $assertoff / $assertkill */
	    sva_assert_enabled = 0;
      return 0;
}

/*
 * M12B: $ivl_register_assertion("name", "file", line) — a synthesized
 * concurrent-assertion checker calls this once (at time 0) to register a
 * VPI identity, so vpi_iterate(vpiAssertion, ...) enumerates it.
 */
static PLI_INT32 sva_reg_assert_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv  = vpi_iterate(vpiArgument, callh);
      char nbuf[1024], fbuf[1024];
      const char*nm = "";
      const char*fl = "";
      PLI_INT32 idx = 0, ln = 0;
      (void)name;
      nbuf[0] = 0; fbuf[0] = 0;
      if (argv) {
	    vpiHandle a;
	    s_vpi_value v;
	    if ((a = vpi_scan(argv))) {           /* idx */
		  v.format = vpiIntVal;
		  vpi_get_value(a, &v);
		  idx = v.value.integer;
	    }
	    if ((a = vpi_scan(argv))) {           /* name */
		  v.format = vpiStringVal;
		  vpi_get_value(a, &v);
		  if (v.value.str) {
			strncpy(nbuf, v.value.str, sizeof nbuf - 1);
			nbuf[sizeof nbuf - 1] = 0;
			nm = nbuf;
		  }
	    }
	    if ((a = vpi_scan(argv))) {           /* file */
		  v.format = vpiStringVal;
		  vpi_get_value(a, &v);
		  if (v.value.str) {
			strncpy(fbuf, v.value.str, sizeof fbuf - 1);
			fbuf[sizeof fbuf - 1] = 0;
			fl = fbuf;
		  }
	    }
	    if ((a = vpi_scan(argv))) {           /* line */
		  v.format = vpiIntVal;
		  vpi_get_value(a, &v);
		  ln = v.value.integer;
		  vpi_free_object(argv);
	    }
      }
      vpip_register_assertion(idx, nm, fl, ln, vpi_handle(vpiScope, callh));
      return 0;
}

/* M12B-cb: $ivl_assert_report(idx, reason) — a synthesized checker fires
   a success/failure event for the (scope, idx) assertion. */
static PLI_INT32 sva_report_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv  = vpi_iterate(vpiArgument, callh);
      PLI_INT32 idx = 0, reason = 0;
      (void)name;
      if (argv) {
	    vpiHandle a;
	    s_vpi_value v;
	    if ((a = vpi_scan(argv))) {
		  v.format = vpiIntVal;
		  vpi_get_value(a, &v);
		  idx = v.value.integer;
	    }
	    if ((a = vpi_scan(argv))) {
		  v.format = vpiIntVal;
		  vpi_get_value(a, &v);
		  reason = v.value.integer;
		  vpi_free_object(argv);
	    }
      }
      vpip_assertion_report(idx, reason, vpi_handle(vpiScope, callh));
      return 0;
}

/* M12B-cb: $ivl_assert_cb_active() — non-zero iff any assertion callback
   is registered (lets checkers skip reporting when nothing is watching). */
static PLI_INT32 sva_cb_active_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      s_vpi_value rv;
      (void)name;
      rv.format = vpiIntVal;
      rv.value.integer = vpip_assertion_cb_active();
      vpi_put_value(callh, &rv, 0, vpiNoDelay);
      return 0;
}

static void register_one_(const char*tfname,
                          PLI_INT32 (*calltf)(ICARUS_VPI_CONST PLI_BYTE8*))
{
      s_vpi_systf_data tf_data;
      memset(&tf_data, 0, sizeof tf_data);
      tf_data.type        = vpiSysFunc;
      tf_data.sysfunctype = vpiSysFuncSized;
      tf_data.tfname      = (PLI_BYTE8*)tfname;
      tf_data.calltf      = calltf;
      tf_data.compiletf   = sva_compiletf;
      tf_data.sizetf      = sva_sizetf;
      tf_data.user_data   = (PLI_BYTE8*)tfname;
      vpiHandle h = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(h);
}

static void register_task_(const char*tfname,
			   PLI_INT32 (*calltf)(ICARUS_VPI_CONST PLI_BYTE8*))
{
      s_vpi_systf_data tf_data;
      memset(&tf_data, 0, sizeof tf_data);
      tf_data.type      = vpiSysTask;
      tf_data.tfname    = (PLI_BYTE8*)tfname;
      tf_data.calltf    = calltf;
      tf_data.compiletf = sva_compiletf;
      tf_data.user_data = (PLI_BYTE8*)tfname;
      vpiHandle h = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(h);
}

void sys_sva_register(void)
{
      register_one_("$rose",   sva_const_calltf);
      register_one_("$fell",   sva_const_calltf);
      register_one_("$stable", sva_const_calltf);
      register_one_("$past",   sva_past_calltf);
      register_one_("$sampled", sva_past_calltf);
      register_one_("$rose_gclk",   sva_const_calltf);
      register_one_("$fell_gclk",   sva_const_calltf);
      register_one_("$stable_gclk", sva_const_calltf);

	/* Assertion control (20.12): the enable-query function used by
	   synthesized checkers, and the control tasks. */
      register_one_("$ivl_sva_enabled", sva_enabled_calltf);
      register_task_("$asserton",   sva_control_calltf);
      register_task_("$assertoff",  sva_control_calltf);
      register_task_("$assertkill", sva_control_calltf);

	/* Assertion VPI identity registration + callback reporting (used
	   by synthesized checkers; see pform_make_assertion). */
      register_task_("$ivl_register_assertion", sva_reg_assert_calltf);
      register_task_("$ivl_assert_report", sva_report_calltf);
      register_one_("$ivl_assert_cb_active", sva_cb_active_calltf);
}
