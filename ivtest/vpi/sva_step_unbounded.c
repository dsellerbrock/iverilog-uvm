/* IEEE 1800 39.4.2 / 39.5.2: per-attempt callbacks on a final ##[m:$]. */
#include <stdint.h>
#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

#define IEEE_vpiDecompile 54

static vpiHandle find(const char *name)
{
      vpiHandle it = vpi_iterate(vpiAssertion, 0), a;
      while (it && (a = vpi_scan(it))) {
	    if (strcmp(vpi_get_str(vpiName, a), name) == 0) {
		  vpi_free_object(it);
		  return a;
	    }
      }
      vpi_printf("missing assertion %s\n", name);
      return 0;
}

static int source_matches(vpiHandle expr, int line)
{
      const char *file = vpi_get_str(vpiFile, expr);
      return file && strstr(file, "sva_step_unbounded.sv")
	    && vpi_get(vpiLineNo, expr) == line;
}

static PLI_INT32 report(PLI_INT32 reason, p_vpi_time t, vpiHandle a,
			p_vpi_attempt_info info, PLI_BYTE8 *name)
{
      p_vpi_assertion_step_info st = info->detail.step;
      int i;
      vpi_printf("%s %s t=%u start=%u %d->%d [", name,
		 reason == cbAssertionStepSuccess ? "OK" : "FAIL",
		 (unsigned)t->low, (unsigned)info->attemptStartTime.low,
		 (int)st->stateFrom, (int)st->stateTo);
      for (i = 0; i < st->matched_expression_count; ++i) {
	    vpiHandle expr = st->matched_exprs[i];
	    int line = vpi_get(vpiLineNo, expr);
	    int ok = source_matches(expr, line);
	    vpi_printf("%s%s@%d%s", i ? " " : "",
		       vpi_get_str(IEEE_vpiDecompile, expr), line, ok ? "" : "(no file)");
      }
      vpi_printf("]\n");
      /* Off inside the step must preserve the current start and older waits. */
      if (strcmp(name, "linear") == 0 && t->low == 26 && st->stateFrom == 0) {
	    if (!vpi_control(vpiAssertionDisable, a)) vpi_printf("off refused\n");
      }
      /* Kill from the first mature waiter's callback, while iterating. */
      if (strcmp(name, "cancel") == 0 && t->low == 218 && st->stateFrom == 2) {
	    if (!vpi_control(vpiAssertionSysKill, (vpiHandle)0)
		|| !vpi_control(vpiAssertionSysOn, (vpiHandle)0))
		  vpi_printf("kill/on refused\n");
      }
      return 0;
}

static PLI_INT32 start(PLI_INT32 reason, p_vpi_time t, vpiHandle a,
		       p_vpi_attempt_info info, PLI_BYTE8 *name)
{
      unsigned s = info->attemptStartTime.low;
      (void)t; (void)reason;
      if (strcmp(name, "linear") == 0 && s == 16) return 0;
      if (!vpi_control(vpiAssertionEnableStep, a, &info->attemptStartTime,
		       vpiAssertionClockSteps))
	    vpi_printf("%s enable %u refused\n", name, s);
      return 0;
}

enum { WATCHED_ASSERTIONS = 4, CALLBACKS_PER_ASSERTION = 3 };
static vpiHandle callbacks[WATCHED_ASSERTIONS * CALLBACKS_PER_ASSERTION];
static int ncallbacks;

static void watch(const char *name)
{
      vpiHandle a = find(name);
      callbacks[ncallbacks++] =
	    vpi_register_assertion_cb(a, cbAssertionStart, start, (PLI_BYTE8 *)name);
      callbacks[ncallbacks++] =
	    vpi_register_assertion_cb(a, cbAssertionStepSuccess, report, (PLI_BYTE8 *)name);
      callbacks[ncallbacks++] =
	    vpi_register_assertion_cb(a, cbAssertionStepFailure, report, (PLI_BYTE8 *)name);
}

static PLI_INT32 setup(PLI_BYTE8 *ud)
{
      (void)ud;
      watch("linear");
      watch("zero_wait");
      watch("delayed");
      watch("cancel");
      return 0;
}

static PLI_INT32 enable(PLI_BYTE8 *ud)
{
      (void)ud;
      if (!vpi_control(vpiAssertionEnable, find("linear"))) vpi_printf("on refused\n");
      return 0;
}

enum { STRESS_ATTEMPTS = 20, FIRST_OBSERVED = 2, ACCEPT_CLOCK = 299 };
static int next_clock[STRESS_ATTEMPTS];
static uint64_t first_start;

static uint64_t raw_time(const s_vpi_time *t)
{
      return ((uint64_t)t->high << 32) | t->low;
}

static PLI_INT32 stress_arm(PLI_BYTE8 *ud)
{
      s_vpi_time ts;
      vpiHandle a = find("stress");
      int i;
      (void)ud;
      /* Exercise handoff with no assertion callbacks registered anywhere. */
      for (i = 0; i < ncallbacks; ++i)
	    if (callbacks[i] && !vpi_remove_cb(callbacks[i]))
		  vpi_printf("callback removal refused\n");
      ts.type = vpiSimTime;
      vpi_get_time(0, &ts);
      first_start = raw_time(&ts) + 5;
      for (i = 0; i < STRESS_ATTEMPTS; ++i) {
	    uint64_t when = first_start + 10 * i;
	    ts.high = when >> 32;
	    ts.low = (uint32_t)when;
	    if (!vpi_control(vpiAssertionEnableStep, a, &ts, vpiAssertionClockSteps))
		  vpi_printf("stress enable %d refused\n", i);
	    next_clock[i] = i < FIRST_OBSERVED ? FIRST_OBSERVED : i;
      }
      return 0;
}

static PLI_INT32 stress_step(PLI_INT32 reason, p_vpi_time t, vpiHandle a,
			     p_vpi_attempt_info info, PLI_BYTE8 *ud)
{
      const s_vpi_time *st = &info->attemptStartTime;
      p_vpi_assertion_step_info step = info->detail.step;
      uint64_t offset = raw_time(st) - first_start;
      int i, tick, from, to;
      const char *expr;
      (void)a; (void)ud;
      if (t->type != vpiSimTime || st->type != vpiSimTime
	  || offset >= 10 * STRESS_ATTEMPTS || offset % 10) {
	    vpi_printf("bad stress attempt time\n");
	    return 0;
      }
      i = (int)(offset / 10);
      tick = next_clock[i]++;
      from = tick == i ? 0 : 2;
      to = tick == ACCEPT_CLOCK ? 1 : 2;
      expr = from == 0 ? "sa" : to == 1 ? "sb" : 0;
      if (raw_time(t) != first_start + 10 * tick
	  || reason != cbAssertionStepSuccess
	  || step->stateFrom != from || step->stateTo != to
	  || step->matched_expression_count != (expr != 0)
	  || (expr && (!source_matches(step->matched_exprs[0], 13)
		       || strcmp(vpi_get_str(IEEE_vpiDecompile, step->matched_exprs[0]), expr))))
	    vpi_printf("bad stress step for start %d at clock %d\n", i, tick);
      return 0;
}

static PLI_INT32 stress_watch(PLI_BYTE8 *ud)
{
      vpiHandle a = find("stress");
      (void)ud;
      vpi_register_assertion_cb(a, cbAssertionStepSuccess, stress_step, 0);
      vpi_register_assertion_cb(a, cbAssertionStepFailure, stress_step, 0);
      return 0;
}

static PLI_INT32 stress_check(PLI_BYTE8 *ud)
{
      int i;
      (void)ud;
      for (i = 0; i < STRESS_ATTEMPTS; ++i)
	    if (next_clock[i] != ACCEPT_CLOCK + 1)
		  vpi_printf("missing or extra stress steps for start %d\n", i);
      vpi_printf("checked %d enabled waits through clock %d\n", STRESS_ATTEMPTS,
		 ACCEPT_CLOCK);
      return 0;
}

static void reg(const char *name, PLI_INT32 (*fn)(PLI_BYTE8 *))
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = (PLI_BYTE8 *)name;
      tf.calltf = fn;
      vpi_register_systf(&tf);
}

static void startup(void)
{
      reg("$wait_setup", setup);
      reg("$wait_on", enable);
      reg("$wait_stress_arm", stress_arm);
      reg("$wait_stress_watch", stress_watch);
      reg("$wait_stress_check", stress_check);
}

void (*vlog_startup_routines[])(void) = { startup, 0 };
