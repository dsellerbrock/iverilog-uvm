#include <stdio.h>
#include <string.h>
#include <vpi_user.h>

static PLI_INT32 probe_calltf(PLI_BYTE8 *user_data)
{
      vpiHandle empty, multi, stmt, iter, child;
      unsigned count = 0;
      int ok = 1;
      (void)user_data;

      empty = vpi_handle_by_name("top.empty", NULL);
      multi = vpi_handle_by_name("top.multi", NULL);
      stmt = empty ? vpi_handle(vpiStmt, empty) : NULL;
      if (!empty || stmt) ok = 0;
      if (stmt) vpi_free_object(stmt);

      stmt = multi ? vpi_handle(vpiStmt, multi) : NULL;
      if (!stmt || vpi_get(vpiType, stmt) != vpiBegin) ok = 0;
      iter = stmt ? vpi_iterate(vpiStmt, stmt) : NULL;
      while (iter && (child = vpi_scan(iter))) {
            char *name = vpi_get_str(vpiName, child);
            if (vpi_get(vpiType, child) != vpiSysTaskCall
                || !name || strcmp(name, "$display") != 0)
                  ok = 0;
            count += 1;
      }
      if (count != 2) ok = 0;
      vpi_printf("ISSUE1267 empty=%d multi=%d children=%u %s\n",
                 empty != NULL, stmt != NULL, count,
                 ok ? "PASSED" : "FAILED");
      if (ok) vpi_printf("PASSED\n");
      if (stmt) vpi_free_object(stmt);
      if (empty) vpi_free_object(empty);
      if (multi) vpi_free_object(multi);
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data data = { vpiSysTask, 0, "$probe", probe_calltf,
                                0, 0, 0 };
      vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
