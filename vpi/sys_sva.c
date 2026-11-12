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
# include  <stdio.h>
# include  <stdlib.h>
# include  <string.h>
# include  <stdint.h>

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

/*
 * $sampled outside a property/sequence expression (e.g. in an action
 * block or plain procedural code). In assertion contexts the front end
 * rewrites $sampled to the Preponed capture register; when the call
 * survives to this VPI fallback there is no capture, so we return the
 * live value — which per 16.9.3 is what $sampled means in procedural
 * code sampled in the Observed region, but our read happens at call
 * time rather than Observed. Warn once so the approximation is loud.
 */
static PLI_INT32 sva_sampled_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      static int warned = 0;
      if (!warned) {
	    warned = 1;
	    vpi_printf("SVA warning: $sampled outside a property expression "
		       "returns the live value at call time, not the "
		       "Observed-region sample (compile-progress "
		       "approximation).\n");
      }
      return sva_past_calltf(name);
}

static PLI_INT32 sva_sizetf(ICARUS_VPI_CONST PLI_BYTE8 *name)
{
      (void)name;
      return 32;
}

/* Assertion control (IEEE 1800-2023 20.11, 1800-2017 20.12). The state and
 * its chronological rule history live with the assertions in the simulator
 * (vpip_assertion_control / vpip_assertion_state); these tasks only decode
 * their arguments. Source-level hierarchical selectors are lowered to
 * strings because an assertion directive is not a value expression. */

/* An omitted positional argument, as in $assertcontrol(9, , , 0, a1). The
   simulator hands built-in tasks a blank string constant in its place. */
static int sva_arg_omitted_(vpiHandle arg)
{
      s_vpi_value value;
      if (vpi_get(vpiType, arg) == vpiOperation)
	    return vpi_get(vpiOpType, arg) == vpiNullOp;
      if (vpi_get(vpiType, arg) != vpiConstant
	  || vpi_get(vpiConstType, arg) != vpiStringConst)
	    return 0;
      value.format = vpiStringVal;
      vpi_get_value(arg, &value);
      return value.value.str && strcmp(value.value.str, " ") == 0;
}

static PLI_INT32 sva_int_arg_(vpiHandle argv, PLI_INT32 dflt, int*present)
{
      vpiHandle arg = argv ? vpi_scan(argv) : 0;
      s_vpi_value value;
      if (present) *present = arg != 0;
      if (!arg || sva_arg_omitted_(arg)) return dflt;
      value.format = vpiIntVal;
      vpi_get_value(arg, &value);
      return value.value.integer;
}

/* One state query: $ivl_sva_state(space, id, what), answered for the
   assertion that the front end numbered id in the calling scope. A
   concurrent kill generation is 0 until its assertion exists. */
static PLI_INT32 sva_state_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv = vpi_iterate(vpiArgument, callh);
      PLI_INT32 space = sva_int_arg_(argv, 0, 0);
      PLI_INT32 id = sva_int_arg_(argv, 0, 0);
      PLI_INT32 what = sva_int_arg_(argv, 0, 0);
      s_vpi_value rv;
      (void)name;
      if (argv) vpi_free_object(argv);
      rv.format = vpiIntVal;
      rv.value.integer = vpip_assertion_state(vpi_handle(vpiScope, callh),
					      space, id, what);
      if (rv.value.integer < 0) rv.value.integer = 1;
      vpi_put_value(callh, &rv, 0, vpiNoDelay);
      return 0;
}

/* IEEE 1800-2023 16.14.6: $ivl_sva_proc_enqueue(pid) queues a pending
   instance of a procedural concurrent assertion where its statement runs;
   $ivl_sva_proc_register(idx, pid) ties pid to checker idx of the calling
   scope. */
static PLI_INT32 sva_proc_enqueue_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv = vpi_iterate(vpiArgument, callh);
      PLI_INT32 pid = sva_int_arg_(argv, 0, 0);
      (void)name;
      if (argv) vpi_free_object(argv);
      vpip_proc_assert_enqueue(pid, vpi_handle(vpiScope, callh));
      return 0;
}

static PLI_INT32 sva_proc_register_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv = vpi_iterate(vpiArgument, callh);
      PLI_INT32 idx = sva_int_arg_(argv, 0, 0);
      PLI_INT32 pid = sva_int_arg_(argv, 0, 0);
      (void)name;
      if (argv) vpi_free_object(argv);
      vpip_register_proc_assertion(idx, pid, vpi_handle(vpiScope, callh));
      return 0;
}

/* Each assertion control task is the 20.11 $assertcontrol call it is
   defined as: control_type, assertion_type, directive_type. */
static const struct {
      const char*name;
      PLI_INT32 ctl, atype;
} sva_control_tasks[] = {
      { "$asserton",          3, 15 },
      { "$assertoff",         4, 15 },
      { "$assertkill",        5, 15 },
      { "$assertpasson",      6, 31 },
      { "$assertpassoff",     7, 31 },
      { "$assertfailon",      8, 31 },
      { "$assertfailoff",     9, 31 },
      { "$assertnonvacuouson", 10, 31 },
      { "$assertvacuousoff",  11, 31 },
};

enum { SVA_CONTROL_SELECTOR_LIMIT = 256 };

static PLI_INT32 sva_control_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv = vpi_iterate(vpiArgument, callh);
      PLI_INT32 ctl = 0, atype = 255, dtype = 7, levels;
      char*selectors[SVA_CONTROL_SELECTOR_LIMIT];
      PLI_INT32 nsel = 0, i;
      vpiHandle arg;
      int present;

      if (strcmp(name, "$assertcontrol") == 0) {
	    ctl = sva_int_arg_(argv, 0, &present);
	    if (present) atype = sva_int_arg_(argv, 255, &present);
	    if (present) dtype = sva_int_arg_(argv, 7, &present);
      } else {
	    size_t t;
	    for (t = 0; t < sizeof sva_control_tasks / sizeof *sva_control_tasks;
		 t += 1)
		  if (strcmp(name, sva_control_tasks[t].name) == 0) {
			ctl = sva_control_tasks[t].ctl;
			atype = sva_control_tasks[t].atype;
		  }
	    present = 1;
      }
      levels = present ? sva_int_arg_(argv, 0, &present) : 0;
      if (ctl < 1 || ctl > 11) {
	    vpi_printf("SVA runtime error: %s control_type %d is not one of the "
		       "values 1-11 of IEEE 1800-2023 Table 20-5; request "
		       "ignored.\n", name, (int)ctl);
	    if (argv && present) vpi_free_object(argv);
	    return 0;
      }
      if (levels < 0) {
	    vpi_printf("SVA runtime error: %s levels argument must be "
		       "nonnegative; request ignored.\n", name);
	    if (argv && present) vpi_free_object(argv);
	    return 0;
      }
      while (present && argv && (arg = vpi_scan(argv))) {
	    s_vpi_value value;
	    value.format = vpiStringVal;
	    vpi_get_value(arg, &value);
	    if (!value.value.str || !value.value.str[0]) {
		  vpi_printf("SVA runtime error: %s selector is empty; "
			     "request ignored.\n", name);
		  continue;
	    }
	    if (nsel == SVA_CONTROL_SELECTOR_LIMIT) {
		  vpi_printf("SVA runtime error: %s has more than %d selectors; "
			     "the rest are ignored.\n", name,
			     SVA_CONTROL_SELECTOR_LIMIT);
		  vpi_free_object(argv);
		  break;
	    }
	    selectors[nsel++] = strdup(value.value.str);
      }
      vpip_assertion_control(ctl, atype, dtype, levels,
			     (const char*const*)selectors, nsel);
      for (i = 0; i < nsel; i += 1) free(selectors[i]);
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
      PLI_INT32 idx = 0, ln = 0, depth = 0, flags = 0, assertion_kind = 1;
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
	    }
	      /* M12-2: optional depth_arg (fixed attempt latency + 1;
		 0 = variable/unknown). Absent in older .vvp output. */
	    if ((a = vpi_scan(argv))) {           /* depth_arg */
		  v.format = vpiIntVal;
		  vpi_get_value(a, &v);
		  depth = v.value.integer;
	    }
	      /* M12-1: optional flags (bit0 = failures always run the
		 full latency). Absent in older .vvp output. */
	    if ((a = vpi_scan(argv))) {           /* flags */
		  v.format = vpiIntVal;
		  vpi_get_value(a, &v);
		  flags = v.value.integer;
		  if ((a = vpi_scan(argv))) {           /* assertion_kind */
			v.format = vpiIntVal;
			vpi_get_value(a, &v);
			assertion_kind = v.value.integer;
		  }
		  vpi_free_object(argv);
	    }
      }
      vpip_register_assertion(idx, nm, fl, ln, vpi_handle(vpiScope, callh),
			      depth, flags, assertion_kind);
      return 0;
}

/* Immediate cover identity/result hooks emitted by the front end. */
static PLI_INT32 sva_immediate_cover_register_calltf(
	ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv = vpi_iterate(vpiArgument, callh);
      PLI_INT32 id = 0, line = 0;
      char nbuf[1024] = "", fbuf[1024] = "";
      (void)name;
      if (argv) {
	    vpiHandle a;
	    s_vpi_value v;
	    if ((a = vpi_scan(argv))) {
		  v.format = vpiIntVal;
		  vpi_get_value(a, &v);
		  id = v.value.integer;
	    }
	    if ((a = vpi_scan(argv))) {
		  v.format = vpiStringVal;
		  vpi_get_value(a, &v);
		  if (v.value.str) {
			strncpy(nbuf, v.value.str, sizeof nbuf - 1);
			nbuf[sizeof nbuf - 1] = 0;
		  }
	    }
	    if ((a = vpi_scan(argv))) {
		  v.format = vpiStringVal;
		  vpi_get_value(a, &v);
		  if (v.value.str) {
			strncpy(fbuf, v.value.str, sizeof fbuf - 1);
			fbuf[sizeof fbuf - 1] = 0;
		  }
	    }
	    if ((a = vpi_scan(argv))) {
		  v.format = vpiIntVal;
		  vpi_get_value(a, &v);
		  line = v.value.integer;
	    }
	    vpi_free_object(argv);
      }
      vpip_register_immediate_cover(id, nbuf, fbuf, line,
				    vpi_handle(vpiScope, callh));
      return 0;
}

static PLI_INT32 sva_immediate_cover_report_calltf(
	ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv = vpi_iterate(vpiArgument, callh);
      PLI_INT32 id = 0, success = 0;
      (void)name;
      if (argv) {
	    vpiHandle a;
	    s_vpi_value v;
	    if ((a = vpi_scan(argv))) {
		  v.format = vpiIntVal;
		  vpi_get_value(a, &v);
		  id = v.value.integer;
	    }
	    if ((a = vpi_scan(argv))) {
		  v.format = vpiIntVal;
		  vpi_get_value(a, &v);
		  success = v.value.integer;
	    }
	    vpi_free_object(argv);
      }
      vpip_report_immediate_cover(id, success, vpi_handle(vpiScope, callh));
      return 0;
}

static PLI_INT32 sva_immediate_assertion_report_calltf(
	ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv = vpi_iterate(vpiArgument, callh);
      PLI_INT32 id = 0, success = 0;
      (void)name;
      if (argv) {
	    vpiHandle a;
	    s_vpi_value v;
	    if ((a = vpi_scan(argv))) {
		  v.format = vpiIntVal;
		  vpi_get_value(a, &v);
		  id = v.value.integer;
	    }
	    if ((a = vpi_scan(argv))) {
		  v.format = vpiIntVal;
		  vpi_get_value(a, &v);
		  success = v.value.integer;
	    }
	    vpi_free_object(argv);
      }
      vpip_report_immediate_assertion(id, success,
				      vpi_handle(vpiScope, callh));
      return 0;
}

/* M12B-cb: $ivl_assert_report(idx, reason) — a synthesized checker fires
   a success/failure event for the (scope, idx) assertion. */
static PLI_INT32 sva_report_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv  = vpi_iterate(vpiArgument, callh);
      PLI_INT32 idx = 0, reason = 0, age = -1;
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
	    }
	    if ((a = vpi_scan(argv))) {
		  v.format = vpiIntVal;
		  vpi_get_value(a, &v);
		  age = v.value.integer;
		  vpi_free_object(argv);
	    }
      }
      if (age >= 0)
	    vpip_assertion_report_age(idx, reason,
				      vpi_handle(vpiScope, callh), age);
      else
	    vpip_assertion_report(idx, reason, vpi_handle(vpiScope, callh));
      return 0;
}

static PLI_INT32 sva_clock_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv = vpi_iterate(vpiArgument, callh);
      PLI_INT32 idx = 0;
      (void)name;
      if (argv) {
	    vpiHandle a = vpi_scan(argv);
	    if (a) {
		  s_vpi_value v;
		  v.format = vpiIntVal;
		  vpi_get_value(a, &v);
		  idx = v.value.integer;
		  vpi_free_object(argv);
	    }
      }
      vpip_assertion_clock(idx, vpi_handle(vpiScope, callh));
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
      register_one_("$sampled", sva_sampled_calltf);
	/* The 16.9.4 global clocking past functions are rewritten by the
	   parser to the functions above sampled on @$global_clock. */

	/* Assertion control (20.12): the enable-query function used by
	   synthesized checkers, and the control tasks. */
      register_one_("$ivl_sva_state", sva_state_calltf);
      register_task_("$ivl_sva_proc_enqueue", sva_proc_enqueue_calltf);
      register_task_("$ivl_sva_proc_register", sva_proc_register_calltf);
      register_task_("$assertcontrol", sva_control_calltf);
      {
	    size_t t;
	    for (t = 0; t < sizeof sva_control_tasks / sizeof *sva_control_tasks;
		 t += 1)
		  register_task_(sva_control_tasks[t].name, sva_control_calltf);
      }

	/* Assertion VPI identity registration + callback reporting (used
	   by synthesized checkers; see pform_make_assertion). */
      register_task_("$ivl_register_assertion", sva_reg_assert_calltf);
      register_task_("$ivl_register_immediate_cover",
		     sva_immediate_cover_register_calltf);
      register_task_("$ivl_report_immediate_cover",
		     sva_immediate_cover_report_calltf);
      register_task_("$ivl_report_immediate_assertion",
		     sva_immediate_assertion_report_calltf);
      register_task_("$ivl_assert_report", sva_report_calltf);
      register_task_("$ivl_assert_clock", sva_clock_calltf);
      register_one_("$ivl_assert_cb_active", sva_cb_active_calltf);
}
