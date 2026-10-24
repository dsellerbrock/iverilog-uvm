#include <vpi_user.h>

static PLI_INT32 removed_calls = 0;
static PLI_INT32 time_calls = 0;
static s_cb_data removed_cb_data;
static s_cb_data time_cb_data;
static s_vpi_time removed_cb_time = { .type = vpiSimTime, .high = 0, .low = 0, .real = 0.0 };
static s_vpi_time time_cb_time = { .type = vpiSimTime, .high = 0, .low = 10, .real = 0.0 };
static s_vpi_time put_delay = { .type = vpiSimTime, .high = 0, .low = 5, .real = 0.0 };
static s_vpi_value removed_cb_value = { .format = vpiIntVal, .value.integer = 0 };
static s_vpi_value put_value = { .format = vpiIntVal, .value.integer = 7 };

static PLI_INT32 removed_cb(p_cb_data data)
{
  (void)data;
  removed_calls++;
  return 0;
}

static PLI_INT32 time_cb(p_cb_data data)
{
  s_vpi_time now = { .type = vpiSimTime, .high = 0, .low = 0, .real = 0.0 };
  (void)data;
  vpi_get_time(NULL, &now);
  time_calls++;
  vpi_printf("TIME %u %u\n", now.high, now.low);
  return 0;
}

static PLI_INT32 probe(PLI_BYTE8 *user_data)
{
  vpiHandle r, w8, mem, mem2, cb_handle;
  const char *full_name;
  s_vpi_value value = { .format = vpiIntVal, .value.integer = 0 };
  PLI_INT32 size, remove_ok;
  (void)user_data;

  r = vpi_handle_by_name("p36b.r", NULL);
  w8 = vpi_handle_by_name("p36b.w8", NULL);
  mem = vpi_handle_by_name("p36b.mem", NULL);
  if (!r || !w8 || !mem) {
    vpi_printf("FAIL handle lookup\n");
    return 1;
  }

  full_name = vpi_get_str(vpiFullName, r);
  vpi_printf("FULLNAME %s\n", full_name ? full_name : "<null>");
  size = vpi_get(vpiSize, w8);
  vpi_printf("SIZE %d\n", size);

  mem2 = vpi_handle_by_index(mem, 2);
  if (!mem2) {
    vpi_printf("FAIL mem[2] lookup\n");
    return 1;
  }
  vpi_get_value(mem2, &value);
  vpi_printf("MEM2 %d\n", value.value.integer);

  vpi_put_value(r, &put_value, &put_delay, vpiInertialDelay);
  vpi_get_value(r, &value);
  vpi_printf("IMMEDIATE %d\n", value.value.integer);

  removed_cb_data.reason = cbValueChange;
  removed_cb_data.cb_rtn = removed_cb;
  removed_cb_data.obj = r;
  removed_cb_data.time = &removed_cb_time;
  removed_cb_data.value = &removed_cb_value;
  removed_cb_data.user_data = NULL;
  cb_handle = vpi_register_cb(&removed_cb_data);
  remove_ok = cb_handle ? vpi_remove_cb(cb_handle) : 0;
  vpi_printf("REMOVE %d\n", remove_ok);

  time_cb_data.reason = cbAtStartOfSimTime;
  time_cb_data.cb_rtn = time_cb;
  time_cb_data.obj = NULL;
  time_cb_data.time = &time_cb_time;
  time_cb_data.value = NULL;
  time_cb_data.user_data = NULL;
  if (!vpi_register_cb(&time_cb_data)) vpi_printf("FAIL time callback registration\n");
  return 0;
}

static PLI_INT32 report(PLI_BYTE8 *user_data)
{
  PLI_INT32 finish_ok;
  (void)user_data;
  vpi_printf("REMOVED_CALLS %d\n", removed_calls);
  vpi_printf("TIME_CALLS %d\n", time_calls);
  finish_ok = vpi_control(vpiFinish, 0);
  vpi_printf("FINISH %d\n", finish_ok);
  return 0;
}

static void register_tasks(void)
{
  static s_vpi_systf_data probe_data = { vpiSysTask, 0, "$probe36b", probe, 0, 0, 0 };
  static s_vpi_systf_data report_data = { vpiSysTask, 0, "$report36b", report, 0, 0, 0 };
  vpi_register_systf(&probe_data);
  vpi_register_systf(&report_data);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
