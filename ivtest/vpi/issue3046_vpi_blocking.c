#include <vpi_user.h>

static PLI_INT32 check_events(PLI_BYTE8 *unused)
{
      vpiHandle task, block, iter, stmt;
      int count = 0, failures = 0;
      (void)unused;
      task = vpi_handle_by_name("top.inspect_me", 0);
      block = task ? vpi_handle(vpiStmt, task) : 0;
      iter = block ? vpi_iterate(vpiStmt, block) : 0;
      if (!iter) {
            vpi_printf("FAIL: missing statement iterator\n");
            failures++;
      }
      while (iter && (stmt = vpi_scan(iter))) {
            if (count >= 4 || vpi_get(vpiType, stmt) != vpiEventStmt ||
                vpi_get(vpiBlocking, stmt) != (count % 2 == 0)) {
                  vpi_printf("FAIL: statement %d type=%d blocking=%d\n", count,
                             vpi_get(vpiType, stmt), vpi_get(vpiBlocking, stmt));
                  failures++;
            }
            count++;
      }
      if (count != 4) {
            vpi_printf("FAIL: expected four statements, got %d\n", count);
            failures++;
      }
      if (!failures) vpi_printf("ISSUE3046 PASSED\nPASSED\n");
      return 0;
}

static void start(void)
{
      s_vpi_systf_data task = {0};
      task.type = vpiSysTask;
      task.tfname = "$check_event_blocking";
      task.calltf = check_events;
      vpi_register_systf(&task);
}
void (*vlog_startup_routines[])(void) = {start, 0};
