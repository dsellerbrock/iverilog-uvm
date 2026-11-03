#include "vpi_user.h"

static s_vpi_time stmt_time = {vpiSimTime, 0, 0, 0.0};
static vpiHandle stmt_callback_a;
static int callback_a_count;
static int callback_b_count;
static int callback_remove_result;
static int failed;

static const PLI_INT32 expected_types[] = {
      vpiBegin, vpiAssignment, vpiDelayControl, vpiAssignment,
      vpiSysTaskCall
};

static void check_value(const char*name, PLI_INT32 expected)
{
      vpiHandle value_handle = vpi_handle_by_name((PLI_BYTE8*)name, 0);
      s_vpi_value value = {0};
      value.format = vpiIntVal;
      if (!value_handle) {
            failed = 1;
            return;
      }
      vpi_get_value(value_handle, &value);
      if (value.value.integer != expected) failed = 1;
}

static PLI_INT32 on_stmt(p_cb_data cb)
{
      int *count = (int*)cb->user_data;
      int current;
      if (cb->reason != cbStmt || !cb->obj || cb->value || cb->index != 0
          || !cb->time || cb->time->type != vpiSimTime || !count) {
            failed = 1;
            return 0;
      }

      current = ++*count;
      if (current > (int)(sizeof(expected_types) / sizeof(expected_types[0]))
          || vpi_get(vpiType, cb->obj) != expected_types[current-1]) {
            failed = 1;
            return 0;
      }
      if (cb->time->high != 0
          || cb->time->low != (current < 4 ? 0 : 1))
            failed = 1;

      if (current == 4) {
            check_value("top.x", 1);
            if (count == &callback_a_count)
                  callback_remove_result = vpi_remove_cb(stmt_callback_a);
      } else if (current == 5 && count == &callback_b_count) {
            check_value("top.x", 2);
      }
      return 0;
}

static PLI_INT32 on_end(p_cb_data cb)
{
      (void)cb;
      check_value("top.x", 2);
      if (!failed && callback_a_count == 4 && callback_b_count == 5
          && callback_remove_result != 0)
            vpi_printf("PASSED\n");
      else
            vpi_printf("FAIL: cbStmt counts A=%d B=%d remove=%d\n",
                       callback_a_count, callback_b_count,
                       callback_remove_result);
      return 0;
}

static PLI_INT32 start_of_simulation(p_cb_data cb)
{
      s_cb_data stmt = {0};
      s_cb_data end = {0};
      vpiHandle top = vpi_handle_by_name((PLI_BYTE8*)"top", 0);
      vpiHandle callback_b;
      (void)cb;

      stmt.reason = cbStmt;
      stmt.cb_rtn = on_stmt;
      stmt.obj = top;
      stmt.time = &stmt_time;
      stmt.user_data = (PLI_BYTE8*)&callback_a_count;
      stmt_callback_a = vpi_register_cb(&stmt);
      stmt.user_data = (PLI_BYTE8*)&callback_b_count;
      callback_b = vpi_register_cb(&stmt);

      end.reason = cbEndOfSimulation;
      end.cb_rtn = on_end;
      vpi_register_cb(&end);

      if (stmt_callback_a && callback_b && stmt_callback_a != callback_b)
            vpi_printf("MODULE_STMT_REGISTRATION=PASS\n");
      else {
            failed = 1;
            vpi_printf("MODULE_STMT_REGISTRATION=FAIL\n");
      }
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
