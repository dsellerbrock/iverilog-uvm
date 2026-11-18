/* IEEE 1800-2017 and 1800-2023 39.4.2. */
# include <vpi_user.h>
# include <sv_vpi_user.h>
# include <stdio.h>
# include <stdlib.h>
# include <string.h>

static char failures[16][128];
static size_t count;

static PLI_INT32 fail_cb(PLI_INT32 reason, p_vpi_time time, vpiHandle assertion,
                        p_vpi_attempt_info info, PLI_BYTE8 *ud)
{
      vpiHandle expr = info ? info->detail.failExpr : 0;
      const char *file = expr ? vpi_get_str(vpiFile, expr) : 0;
      int source_ok = file && strstr(file, "sva_failure_expr.sv");
      int line = expr ? vpi_get(vpiLineNo, expr) : 0;
      const char *text = expr ? vpi_get_str(vpiDecompile, expr) : 0;
      (void)reason;
      (void)assertion;
      if (count == sizeof failures / sizeof failures[0]) {
            vpi_printf("Too many assertion failures\n");
            return 0;
      }
      snprintf(failures[count++], sizeof failures[0],
               "%s t=%u start=%u failExpr=%s@%d%s", ud,
               (unsigned)time->low, info ? (unsigned)info->attemptStartTime.low : 0,
               text ? text : "NULL", line, source_ok ? "" : " (missing source)");
      return 0;
}

static PLI_INT32 watch_failures(PLI_BYTE8 *ud)
{
      vpiHandle it = vpi_iterate(vpiAssertion, 0), assertion;
      (void)ud;
      while (it && (assertion = vpi_scan(it))) {
            const char *name = vpi_get_str(vpiName, assertion);
            PLI_BYTE8 *label;
            if (strcmp(name, "fixed_seq") == 0) label = "fixed";
            else if (strcmp(name, "ranged_seq") == 0) label = "ranged";
            else continue;
            vpi_register_assertion_cb(assertion, cbAssertionFailure, fail_cb, label);
      }
      return 0;
}

static int compare(const void *lhs, const void *rhs)
{
      return strcmp(lhs, rhs);
}

static PLI_INT32 print_failures(PLI_BYTE8 *ud)
{
      size_t i;
      (void)ud;
      /* The two checkers can deliver callbacks in either order. */
      qsort(failures, count, sizeof failures[0], compare);
      for (i = 0; i < count; ++i)
            vpi_printf("%s\n", failures[i]);
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data tf = {0};
      tf.type = vpiSysTask;
      tf.tfname = "$watch_failures";
      tf.calltf = watch_failures;
      vpi_register_systf(&tf);
      tf.tfname = "$print_failures";
      tf.calltf = print_failures;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {register_probe, 0};
