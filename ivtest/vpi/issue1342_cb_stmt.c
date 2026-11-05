#include <vpi_user.h>

static s_vpi_time callback_time = { vpiSimTime, 0, 0, 0.0 };
static vpiHandle top_module;
static vpiHandle primary_callback;
static vpiHandle removable_callback;
static int primary_count;
static int while_count;
static int removable_count;
static int removable_status;
static int failed;

static const int expected_type[] = {
      vpiBegin, vpiAssignment, vpiDelayControl, vpiAssignment,
      vpiAssignment, vpiWhile, vpiAssignment, vpiWhile,
      vpiAssignment, vpiWhile, vpiSysTaskCall
};
static const int expected_x[] = { 0, 0, 1, 1, 2, 2, 2, 2, 2, 2, 2 };
static const int expected_i[] = { 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 2 };
static const unsigned expected_time[] = { 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1 };

static PLI_INT32 on_removable_stmt(p_cb_data cb)
{
      (void)cb;
      removable_count += 1;
      if (removable_count == 1)
            removable_status = vpi_remove_cb(removable_callback);
      return 0;
}

static PLI_INT32 on_stmt(p_cb_data cb)
{
      vpiHandle x_handle, i_handle, scope;
      s_vpi_value value;
      int x_value = -1, i_value = -1, type;

      primary_count += 1;
      if (primary_count > (int)(sizeof expected_type / sizeof expected_type[0])) {
            failed = 1;
            return 0;
      }

      type = cb->obj ? vpi_get(vpiType, cb->obj) : vpiUndefined;
      if (cb->reason != cbStmt || !cb->obj || !cb->time || cb->value
          || cb->index != 0 || cb->time->type != vpiSimTime
          || type != expected_type[primary_count - 1])
            failed = 1;
      if (cb->time && cb->time->low != expected_time[primary_count - 1])
            failed = 1;
      scope = cb->obj ? vpi_handle(vpiScope, cb->obj) : 0;
      if (scope != top_module)
            failed = 1;

      value.format = vpiIntVal;
      x_handle = vpi_handle_by_name((PLI_BYTE8*)"top.x", 0);
      i_handle = vpi_handle_by_name((PLI_BYTE8*)"top.i", 0);
      if (!x_handle || !i_handle) {
            failed = 1;
      } else {
            vpi_get_value(x_handle, &value);
            x_value = value.value.integer;
            vpi_get_value(i_handle, &value);
            i_value = value.value.integer;
            vpi_free_object(x_handle);
            vpi_free_object(i_handle);
      }
      if (x_value != expected_x[primary_count - 1]
          || i_value != expected_i[primary_count - 1])
            failed = 1;

      if (type == vpiWhile)
            while_count += 1;

      if (primary_count == (int)(sizeof expected_type / sizeof expected_type[0])) {
            int passed = !failed && primary_callback && removable_count == 1
                  && removable_status == 1 && while_count == 3;
            vpi_printf("ISSUE1342 cbStmt callbacks=%d while=%d removed=%d/%d %s\n",
                       primary_count, while_count, removable_count,
                       removable_status, passed ? "PASS" : "FAIL");
            if (passed)
                  vpi_printf("PASSED\n");
      }
      return 0;
}

static PLI_INT32 start_of_simulation(p_cb_data cb)
{
      s_cb_data data = { 0 };
      (void)cb;

      top_module = vpi_handle_by_name((PLI_BYTE8*)"top", 0);
      data.reason = cbStmt;
      data.cb_rtn = on_stmt;
      data.obj = top_module;
      data.time = &callback_time;
      primary_callback = vpi_register_cb(&data);

      data.cb_rtn = on_removable_stmt;
      removable_callback = vpi_register_cb(&data);
      vpi_printf("ISSUE1342 module registration=%s/%s\n",
                 primary_callback ? "non-null" : "null",
                 removable_callback ? "non-null" : "null");
      return 0;
}

static void register_callbacks(void)
{
      s_cb_data data = { 0 };
      data.reason = cbStartOfSimulation;
      data.cb_rtn = start_of_simulation;
      vpi_register_cb(&data);
}

void (*vlog_startup_routines[])(void) = { register_callbacks, 0 };
