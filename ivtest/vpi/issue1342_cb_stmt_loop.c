#include "vpi_user.h"

static s_vpi_time stmt_time = {vpiSimTime, 0, 0, 0.0};
static int repeat_count;
static int while_count;
static int for_count;
static int forever_count;
static int event_control_count;
static int assignment_count;
static int bad_callback_data;

static PLI_INT32 on_stmt(p_cb_data cb)
{
      int type = vpi_get(vpiType, cb->obj);
      if (cb->reason != cbStmt || !cb->obj || cb->value || cb->index != 0
          || !cb->time || cb->time->type != vpiSimTime)
            bad_callback_data = 1;
      if (type == vpiRepeat) repeat_count++;
      if (type == vpiWhile) while_count++;
      if (type == vpiFor) for_count++;
      if (type == vpiForever) forever_count++;
      if (type == vpiEventControl) event_control_count++;
      if (type == vpiAssignment) {
            assignment_count++;
      }
      return 0;
}

static PLI_INT32 on_end(p_cb_data cb)
{
      (void)cb;
      if (repeat_count == 3 && while_count == 3 && for_count == 3
          && forever_count == 2 && event_control_count == 1
          && assignment_count == 10
          && !bad_callback_data)
            vpi_printf("PASSED\n");
      else
            vpi_printf("FAIL repeat=%d while=%d for=%d forever=%d event=%d assign=%d\n",
                       repeat_count, while_count, for_count, forever_count,
                       event_control_count, assignment_count);
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
