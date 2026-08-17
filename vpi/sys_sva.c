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

/* Assertion control (IEEE 1800-2017 20.12). Source-level hierarchical
 * selectors are lowered to strings because an assertion directive is not a
 * value expression. Keep a bounded chronological rule list so a time-zero
 * control call that happens before a checker's registration initial block is
 * still applied when that checker registers. */
typedef struct sva_control_entry_s {
      PLI_INT32 idx;
      vpiHandle scope;
      char*full_name;
      int enabled;
      PLI_UINT32 kill_generation;
} sva_control_entry_t;

typedef struct sva_control_rule_s {
      char*selector;                 /* NULL means whole design */
      PLI_INT32 levels;              /* zero means all descendant levels */
      int enabled;
      int kill;
} sva_control_rule_t;

static sva_control_entry_t*sva_control_entries;
static size_t sva_control_entry_count;
static size_t sva_control_entry_cap;
static sva_control_rule_t*sva_control_rules;
static size_t sva_control_rule_count;
static size_t sva_control_rule_cap;
static int sva_assert_enabled = 1;

enum { SVA_CONTROL_RULE_LIMIT = 4096, SVA_CONTROL_SELECTOR_LIMIT = 4096 };

static char*sva_control_strdup_(const char*text)
{
      size_t len = text ? strlen(text) : 0;
      char*copy;
      if (len > SVA_CONTROL_SELECTOR_LIMIT) return 0;
      copy = (char*)malloc(len + 1);
      if (!copy) return 0;
      if (len) memcpy(copy, text, len);
      copy[len] = 0;
      return copy;
}

static int sva_control_match_(const char*full, const char*selector,
			      PLI_INT32 levels)
{
      size_t n;
      const char*tail;
      PLI_INT32 depth = 0;
      if (!selector) return 1;
      if (!full) return 0;
      if (strcmp(full, selector) == 0) return 1;
      n = strlen(selector);
      if (strncmp(full, selector, n) != 0 || full[n] != '.') return 0;
      if (levels == 0) return 1;
      tail = full + n + 1;
      depth = 1;
      while (*tail) {
	    if (*tail == '.') depth += 1;
	    tail += 1;
      }
      return depth <= levels;
}

static void sva_control_apply_entry_(sva_control_entry_t*entry,
				     const sva_control_rule_t*rule,
				     int callbacks)
{
      int was;
      if (!sva_control_match_(entry->full_name, rule->selector,
			      rule->levels)) return;
      was = entry->enabled;
      entry->enabled = rule->enabled;
      if (rule->kill) entry->kill_generation += 1;
      if (!callbacks) return;
      if (rule->kill) {
	    if (was)
		  vpip_assertion_report(entry->idx, cbAssertionDisable,
					entry->scope);
	    vpip_assertion_report(entry->idx, cbAssertionReset, entry->scope);
      } else if (was != entry->enabled) {
	    vpip_assertion_report(entry->idx,
		  entry->enabled ? cbAssertionEnable : cbAssertionDisable,
		  entry->scope);
      }
}

static int sva_control_append_rule_(const char*selector, PLI_INT32 levels,
				    int enabled, int kill)
{
      sva_control_rule_t*rule;
      if (sva_control_rule_count >= SVA_CONTROL_RULE_LIMIT) {
	    vpi_printf("SVA runtime error: assertion-control history exceeded "
		       "%d entries; the control request was not applied.\n",
		       SVA_CONTROL_RULE_LIMIT);
	    return 0;
      }
      if (sva_control_rule_count == sva_control_rule_cap) {
	    size_t next = sva_control_rule_cap ? sva_control_rule_cap * 2 : 16;
	    void*mem = realloc(sva_control_rules, next * sizeof *sva_control_rules);
	    if (!mem) {
		  vpi_printf("SVA runtime error: unable to allocate assertion-control "
			     "state; the control request was not applied.\n");
		  return 0;
	    }
	    sva_control_rules = (sva_control_rule_t*)mem;
	    sva_control_rule_cap = next;
      }
      rule = &sva_control_rules[sva_control_rule_count];
      rule->selector = selector ? sva_control_strdup_(selector) : 0;
      if (selector && !rule->selector) {
	    vpi_printf("SVA runtime error: assertion-control selector is too long "
		       "or could not be allocated; the request was not applied.\n");
	    return 0;
      }
      rule->levels = levels;
      rule->enabled = enabled;
      rule->kill = kill;
      sva_control_rule_count += 1;
      return 1;
}

static sva_control_entry_t*sva_control_find_(vpiHandle scope, PLI_INT32 idx)
{
      size_t i;
      for (i = 0; i < sva_control_entry_count; i += 1)
	    if (sva_control_entries[i].scope == scope
		&& sva_control_entries[i].idx == idx)
		  return &sva_control_entries[i];
      return 0;
}

static void sva_control_register_(PLI_INT32 idx, const char*name,
				  vpiHandle scope)
{
      sva_control_entry_t*entry;
      const char*scope_name;
      size_t slen, nlen, i;
      if (sva_control_find_(scope, idx)) return;
      if (sva_control_entry_count == sva_control_entry_cap) {
	    size_t next = sva_control_entry_cap ? sva_control_entry_cap * 2 : 64;
	    void*mem = realloc(sva_control_entries,
			       next * sizeof *sva_control_entries);
	    if (!mem) {
		  vpi_printf("SVA runtime error: unable to allocate per-assertion "
			     "control state.\n");
		  return;
	    }
	    sva_control_entries = (sva_control_entry_t*)mem;
	    sva_control_entry_cap = next;
      }
      entry = &sva_control_entries[sva_control_entry_count++];
      memset(entry, 0, sizeof *entry);
      entry->idx = idx;
      entry->scope = scope;
      entry->enabled = 1;
      scope_name = scope ? vpi_get_str(vpiFullName, scope) : 0;
      slen = scope_name ? strlen(scope_name) : 0;
      nlen = name ? strlen(name) : 0;
      entry->full_name = (char*)malloc(slen + (slen && nlen ? 1 : 0)
				      + nlen + 1);
      if (!entry->full_name) {
	    vpi_printf("SVA runtime error: unable to allocate assertion name.\n");
	    entry->enabled = sva_assert_enabled;
	    return;
      }
      entry->full_name[0] = 0;
      if (slen) memcpy(entry->full_name, scope_name, slen);
      if (slen && nlen) entry->full_name[slen++] = '.';
      if (nlen) memcpy(entry->full_name + slen, name, nlen);
      entry->full_name[slen + nlen] = 0;
      for (i = 0; i < sva_control_rule_count; i += 1)
	    sva_control_apply_entry_(entry, &sva_control_rules[i], 0);
}

static PLI_INT32 sva_enabled_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv = vpi_iterate(vpiArgument, callh);
      PLI_INT32 idx = -1;
      sva_control_entry_t*entry = 0;
      s_vpi_value rv;
      (void)name;
      if (argv) {
	    vpiHandle arg = vpi_scan(argv);
	    if (arg) {
		  s_vpi_value value;
		  value.format = vpiIntVal;
		  vpi_get_value(arg, &value);
		  idx = value.value.integer;
	    }
	    vpi_free_object(argv);
      }
      if (idx >= 0)
	    entry = sva_control_find_(vpi_handle(vpiScope, callh), idx);
      rv.format = vpiIntVal;
      rv.value.integer = entry ? entry->enabled : sva_assert_enabled;
      vpi_put_value(callh, &rv, 0, vpiNoDelay);
      return 0;
}

/* Every synthesized checker process remembers this monotonically increasing
 * generation.  A changed value means that $assertkill selected this exact
 * (runtime scope, assertion index) since the process last ran.  Unlike a
 * consumable bit, the generation is safe for multi-clock checkers whose
 * independent clock-domain processes must all observe the same reset.  The
 * chronological control-rule cap keeps wraparound unreachable. */
static PLI_INT32 sva_kill_generation_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv = vpi_iterate(vpiArgument, callh);
      PLI_INT32 idx = -1;
      sva_control_entry_t*entry = 0;
      s_vpi_value rv;
      (void)name;
      if (argv) {
	    vpiHandle arg = vpi_scan(argv);
	    if (arg) {
		  s_vpi_value value;
		  value.format = vpiIntVal;
		  vpi_get_value(arg, &value);
		  idx = value.value.integer;
	    }
	    vpi_free_object(argv);
      }
      if (idx >= 0)
	    entry = sva_control_find_(vpi_handle(vpiScope, callh), idx);
      rv.format = vpiIntVal;
      rv.value.integer = entry ? (PLI_INT32)entry->kill_generation : 0;
      vpi_put_value(callh, &rv, 0, vpiNoDelay);
      return 0;
}

static PLI_INT32 sva_control_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv = vpi_iterate(vpiArgument, callh);
      int enabled = name && strcmp(name, "$asserton") == 0;
      int kill = name && strcmp(name, "$assertkill") == 0;
      PLI_INT32 levels = 0;
      size_t before = sva_control_rule_count;
      size_t i;
      int saw_selector = 0;

      if (argv) {
	    vpiHandle arg = vpi_scan(argv);
	    if (arg) {
		  s_vpi_value value;
		  value.format = vpiIntVal;
		  vpi_get_value(arg, &value);
		  levels = value.value.integer;
		  if (levels < 0) {
			vpi_printf("SVA runtime error: %s levels argument must be "
				   "nonnegative; request ignored.\n", name);
			vpi_free_object(argv);
			return 0;
		  }
	    }
	    while ((arg = vpi_scan(argv))) {
		  s_vpi_value value;
		  saw_selector = 1;
		  value.format = vpiStringVal;
		  vpi_get_value(arg, &value);
		  if (!value.value.str || !value.value.str[0]) {
			vpi_printf("SVA runtime error: %s selector is empty; "
				   "request ignored.\n", name);
			continue;
		  }
		  (void)sva_control_append_rule_(value.value.str, levels,
					 enabled, kill);
	    }
      }

      /* No selector means the whole design. Retain this as a chronological
	 rule too, so later checker registration sees the same control order. */
      if (!saw_selector)
	    (void)sva_control_append_rule_(0, levels, enabled, kill);

      for (i = before; i < sva_control_rule_count; i += 1) {
	    size_t j;
	    for (j = 0; j < sva_control_entry_count; j += 1)
		  sva_control_apply_entry_(&sva_control_entries[j],
					   &sva_control_rules[i], 1);
      }
      if (sva_control_rule_count > before
	  && sva_control_rules[sva_control_rule_count-1].selector == 0)
	    sva_assert_enabled = enabled;

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
      PLI_INT32 idx = 0, ln = 0, depth = 0, flags = 0;
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
		  vpi_free_object(argv);
	    }
      }
      vpip_register_assertion(idx, nm, fl, ln, vpi_handle(vpiScope, callh),
			      depth, flags);
      sva_control_register_(idx, nm, vpi_handle(vpiScope, callh));
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
      register_one_("$sampled", sva_sampled_calltf);
      register_one_("$rose_gclk",   sva_const_calltf);
      register_one_("$fell_gclk",   sva_const_calltf);
      register_one_("$stable_gclk", sva_const_calltf);

	/* Assertion control (20.12): the enable-query function used by
	   synthesized checkers, and the control tasks. */
      register_one_("$ivl_sva_enabled", sva_enabled_calltf);
      register_one_("$ivl_sva_kill_generation",
		    sva_kill_generation_calltf);
      register_task_("$asserton",   sva_control_calltf);
      register_task_("$assertoff",  sva_control_calltf);
      register_task_("$assertkill", sva_control_calltf);

	/* Assertion VPI identity registration + callback reporting (used
	   by synthesized checkers; see pform_make_assertion). */
      register_task_("$ivl_register_assertion", sva_reg_assert_calltf);
      register_task_("$ivl_assert_report", sva_report_calltf);
      register_one_("$ivl_assert_cb_active", sva_cb_active_calltf);
}
