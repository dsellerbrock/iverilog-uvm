#include <vpi_user.h>

static PLI_INT32 inspect(PLI_BYTE8 *unused)
{
      vpiHandle task, block, iter, stmt;
      int types[] = { vpiDisableFork, vpiDisable, vpiSysTaskCall };
      unsigned count = 0;
      int ok = 1;
      (void)unused;

      task = vpi_handle_by_name("top.inspect_me", 0);
      block = task ? vpi_handle(vpiStmt, task) : 0;
      if (!block || vpi_get(vpiType, block) != vpiBegin) ok = 0;
      iter = block ? vpi_iterate(vpiStmt, block) : 0;
      while (iter && (stmt = vpi_scan(iter))) {
            if (count >= 3 || vpi_get(vpiType, stmt) != types[count]) ok = 0;
            count += 1;
      }
      if (count != 3) ok = 0;
      vpi_printf("issue3056 %s\n", ok ? "PASSED" : "FAILED");
      if (ok) vpi_printf("PASSED\n");
      return 0;
}

static void start(void)
{
      s_vpi_systf_data data = { vpiSysTask, 0, "$inspect", inspect, 0, 0, 0 };
      vpi_register_systf(&data);
}
void (*vlog_startup_routines[])(void) = { start, 0 };
