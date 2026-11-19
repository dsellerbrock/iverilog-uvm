#include "vpi_user.h"

struct trace {
      const char *name;
      unsigned times[2];
      char values[2];
      unsigned count;
};

static struct trace net = {"resolved net", {0, 4}, {'1', '0'}, 0};
static struct trace driver = {"weak driver", {0, 3}, {'1', 'z'}, 0};
static struct trace bit = {"weak driver bit", {0, 3}, {'1', 'z'}, 0};
static unsigned failures;

static PLI_INT32 changed(p_cb_data cb)
{
      struct trace *trace = (struct trace *)cb->user_data;
      unsigned idx = trace->count++;
      unsigned tick = cb->time->low;
      const char *value = cb->value->value.str;
      if (idx >= 2 || cb->time->high || tick != trace->times[idx]
          || !value || value[0] != trace->values[idx] || value[1] != '\0') {
            vpi_printf("FAIL: %s callback %u at %u gave %s\n",
                       trace->name, idx, tick, value ? value : "<null>");
            failures++;
      }
      return 0;
}

static void watch(vpiHandle handle, struct trace *trace)
{
      s_vpi_time time = {vpiSimTime, 0, 0, 0};
      s_vpi_value value = {vpiBinStrVal, {0}};
      s_cb_data cb = {0};
      cb.reason = cbValueChange;
      cb.cb_rtn = changed;
      cb.obj = handle;
      cb.time = &time;
      cb.value = &value;
      cb.user_data = (PLI_BYTE8 *)trace;
      if (!handle || !vpi_register_cb(&cb)) {
            vpi_printf("FAIL: could not watch %s\n", trace->name);
            failures++;
      }
}

static vpiHandle weak_assign(void)
{
      vpiHandle top = vpi_handle_by_name("top", 0);
      vpiHandle assignments = top ? vpi_iterate(vpiContAssign, top) : 0;
      vpiHandle handle;

      while (assignments && (handle = vpi_scan(assignments))) {
            if (vpi_get(vpiStrength0, handle) == vpiWeakDrive) {
                  vpi_free_object(assignments);
                  return handle;
            }
      }
      return 0;
}

static PLI_INT32 start(p_cb_data cb)
{
      vpiHandle ca = weak_assign();
      vpiHandle bits = ca ? vpi_iterate(vpiBit, ca) : 0;
      vpiHandle first_bit = bits ? vpi_scan(bits) : 0;
      (void)cb;

      watch(vpi_handle_by_name("top.observed", 0), &net);
      watch(ca, &driver);
      watch(first_bit, &bit);
      if (first_bit) vpi_free_object(bits);
      return 0;
}

static PLI_INT32 finish(p_cb_data cb)
{
      (void)cb;
      if (failures == 0 && net.count == 2 && driver.count == 2 && bit.count == 2)
            vpi_printf("PASSED\n");
      else
            vpi_printf("FAIL: callback counts net=%u driver=%u bit=%u\n",
                       net.count, driver.count, bit.count);
      return 0;
}

static void register_callbacks(void)
{
      s_cb_data cb = {0};
      cb.reason = cbStartOfSimulation;
      cb.cb_rtn = start;
      vpi_register_cb(&cb);
      cb.reason = cbEndOfSimulation;
      cb.cb_rtn = finish;
      vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = {register_callbacks, 0};
