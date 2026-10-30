#include <vpi_user.h>
#include <stdio.h>

static s_vpi_time start_time;
static unsigned start_count;
static unsigned late_count;
static PLI_INT32 late_start_callback(p_cb_data data);
static PLI_INT32 check_callback(p_cb_data data);

static PLI_INT32 start_callback(p_cb_data data)
{
      (void)data;
      start_count += 1;
      printf("START_ZERO count=%u\n", start_count);
      if (start_count == 1) {
            s_cb_data cb = {0};
            start_time.low = 0;
            cb.reason = cbAtStartOfSimTime;
            cb.cb_rtn = start_callback;
            cb.time = &start_time;
            vpi_register_cb(&cb);
      }
      return 0;
}

static PLI_INT32 after_delay_callback(p_cb_data data)
{
      (void)data;
      printf("AFTER_DELAY count=1\n");
      s_vpi_time zero_time = {vpiSimTime, 0, 0, 0.0};
      s_cb_data cb = {0};
      cb.reason = cbAtStartOfSimTime;
      cb.cb_rtn = late_start_callback;
      cb.time = &zero_time;
      vpi_register_cb(&cb);
      return 0;
}

static PLI_INT32 late_start_callback(p_cb_data data)
{
      (void)data;
      late_count += 1;
      printf("LATE_START_MUST_NOT_FIRE\n");
      return 0;
}

static PLI_INT32 check_callback(p_cb_data data)
{
      (void)data;
      if (start_count == 2 && late_count == 0)
            printf("ISSUE1589_PASSED\nPASSED\n");
      else
            printf("ISSUE1589_FAILED start=%u late=%u\n", start_count, late_count);
      return 0;
}

static PLI_INT32 start_of_simulation(p_cb_data data)
{
      (void)data;
      s_vpi_time delay_time = {vpiSimTime, 0, 5, 0.0};
      s_cb_data cb = {0};
      start_time = delay_time;
      cb.reason = cbAtStartOfSimTime;
      cb.cb_rtn = start_callback;
      cb.time = &start_time;
      vpi_register_cb(&cb);
      cb.reason = cbAfterDelay;
      cb.cb_rtn = after_delay_callback;
      cb.time = &delay_time;
      vpi_register_cb(&cb);
      delay_time.low = 6;
      cb.cb_rtn = check_callback;
      cb.time = &delay_time;
      vpi_register_cb(&cb);
      return 0;
}

static void register_callbacks(void)
{
      s_cb_data cb = {0};
      cb.reason = cbStartOfSimulation;
      cb.cb_rtn = start_of_simulation;
      vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = {register_callbacks, 0};
