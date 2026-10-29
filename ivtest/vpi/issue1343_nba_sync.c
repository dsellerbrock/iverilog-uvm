#include <vpi_user.h>
#include <assert.h>
#include <string.h>

static vpiHandle watched;

static PLI_INT32 check_nba_sync(p_cb_data cb)
{
      s_vpi_value value;

      (void)cb;
      value.format = vpiIntVal;
      vpi_get_value(watched, &value);
      if (value.value.integer == 0)
            vpi_printf("ISSUE1343_NBA_SYNC_PASS\nPASSED\n");
      else
            vpi_printf("ISSUE1343_NBA_SYNC_FAIL x=%d\n", value.value.integer);
      return 0;
}

static PLI_INT32 register_callback(char*unused)
{
      vpiHandle call = vpi_handle(vpiSysTfCall, 0);
      vpiHandle args = vpi_iterate(vpiArgument, call);
      s_vpi_time now, when;
      s_cb_data cb;

      (void)unused;
      assert(args);
      watched = vpi_scan(args);
      assert(watched);
      now.type = vpiSimTime;
      vpi_get_time(0, &now);

      memset(&cb, 0, sizeof cb);
      when.type = vpiSimTime;
      when.high = 0;
      when.low = now.low + 5;
      when.real = 0.0;
      cb.reason = cbNBASynch;
      cb.cb_rtn = check_nba_sync;
      cb.time = &when;
      assert(vpi_register_cb(&cb));
      return 0;
}

static void register_system_task(void)
{
      s_vpi_systf_data task;

      memset(&task, 0, sizeof task);
      task.type = vpiSysTask;
      task.tfname = "$issue1343_register";
      task.calltf = register_callback;
      vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = { register_system_task, 0 };
