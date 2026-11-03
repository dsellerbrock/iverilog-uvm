#include "vpi_user.h"
#include <string.h>

static s_vpi_time stmt_time = {vpiSimTime, 0, 0, 0.0};
static int deferred_display_count;
static int bad_callback_data;

static PLI_INT32 on_stmt(p_cb_data cb)
{
      const char *name = cb->obj ? vpi_get_str(vpiName, cb->obj) : 0;
      if (cb->reason != cbStmt || !cb->obj || cb->value || cb->index != 0
          || !cb->time || cb->time->type != vpiSimTime)
            bad_callback_data = 1;
      if (vpi_get(vpiType, cb->obj) == vpiSysTaskCall
          && name && strcmp(name, "$display") == 0)
            deferred_display_count++;
      return 0;
}

static PLI_INT32 on_end(p_cb_data cb)
{
      (void)cb;
      if (deferred_display_count == 1 && !bad_callback_data)
            vpi_printf("PASSED\n");
      else
            vpi_printf("FAIL display=%d bad-callback-data=%d\n",
                       deferred_display_count, bad_callback_data);
      return 0;
}

static PLI_INT32 start_of_simulation(p_cb_data cb)
{
      s_cb_data stmt = {0};
      s_cb_data end = {0};
      (void)cb;

      stmt.reason = cbStmt;
      stmt.cb_rtn = on_stmt;
      stmt.obj = vpi_handle_by_name((PLI_BYTE8*)"top", 0);
      stmt.time = &stmt_time;
      vpi_register_cb(&stmt);

      end.reason = cbEndOfSimulation;
      end.cb_rtn = on_end;
      vpi_register_cb(&end);
      return 0;
}

static void startup(void)
{
      s_cb_data cb = {0};
      cb.reason = cbStartOfSimulation;
      cb.cb_rtn = start_of_simulation;
      vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = {startup, 0};
