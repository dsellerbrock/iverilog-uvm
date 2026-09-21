#include <stdio.h>
#include "sv_vpi_user.h"

static int failures;
static int a_force, a_late_force, b_force, a_release, b_release;
static vpiHandle a, b, a_force_handle;

static void expect(int ok, const char *what)
{
  if (!ok) { vpi_printf("FAIL %s\n", what); failures++; }
}

static int intval(vpiHandle obj)
{
  s_vpi_value value = {vpiIntVal, {0}};
  vpi_get_value(obj, &value);
  return value.value.integer;
}

static vpiHandle add_cb(vpiHandle obj, int reason,
                        PLI_INT32 (*fn)(p_cb_data));
static void put(vpiHandle obj, int value, int flag);

static PLI_INT32 late_a_forced(p_cb_data cb)
{
  expect(cb->obj == a, "late A force object");
  expect(cb->value && cb->value->format == vpiIntVal &&
         cb->value->value.integer == intval(a), "late A force value");
  a_late_force++;
  return 0;
}

static PLI_INT32 a_forced(p_cb_data cb)
{
  expect(cb->obj == a, "A force object");
  expect(cb->value && cb->value->format == vpiIntVal &&
         cb->value->value.integer == intval(a), "A force value");
  a_force++;
  if (a_force == 1) {
    expect(add_cb(a, cbForce, late_a_forced) != 0,
           "register callback during dispatch");
    expect(vpi_remove_cb(a_force_handle) == 1,
           "remove callback during dispatch");
    put(b, 0, vpiForceFlag);
  }
  return 0;
}

static PLI_INT32 b_forced(p_cb_data cb)
{
  expect(cb->obj == b, "B force object");
  expect(cb->value && cb->value->format == vpiIntVal &&
         cb->value->value.integer == intval(b), "B force value");
  b_force++;
  return 0;
}

static PLI_INT32 released(p_cb_data cb)
{
  expect(cb->value && cb->value->format == vpiIntVal &&
         cb->value->value.integer == intval(cb->obj), "release selected value");
  if (cb->obj == a) a_release++;
  else if (cb->obj == b) b_release++;
  else expect(0, "release selected object");
  return 0;
}

static vpiHandle add_cb(vpiHandle obj, int reason,
                        PLI_INT32 (*fn)(p_cb_data))
{
  s_vpi_value value = {vpiIntVal, {0}};
  s_cb_data cb = {0};
  cb.reason = reason;
  cb.cb_rtn = fn;
  cb.obj = obj;
  cb.value = &value;
  return vpi_register_cb(&cb);
}

static void put(vpiHandle obj, int value, int flag)
{
  s_vpi_value data = {vpiIntVal, {0}};
  data.value.integer = value;
  vpi_put_value(obj, &data, 0, flag);
}

static PLI_INT32 check(char *unused)
{
  (void)unused;
  a = vpi_handle_by_name("packed_force_overlap.value[1]", 0);
  b = vpi_handle_by_name("packed_force_overlap.value[0]", 0);
  expect(a && b && vpi_get(vpiSize, a) == 3 && vpi_get(vpiSize, b) == 3,
         "sibling packed-prefix handles");
  if (!a || !b) return 0;

  a_force_handle = add_cb(a, cbForce, a_forced);
  expect(a_force_handle && add_cb(b, cbForce, b_forced), "force callbacks");
  expect(add_cb(a, cbRelease, released) && add_cb(b, cbRelease, released),
         "release callbacks");

  put(a, 0, vpiForceFlag);
  expect(intval(a) == 0 && intval(b) == 0,
         "nested callback force reaches B");
  put(a, 0, vpiReleaseFlag);
  expect(intval(a) == 0 && intval(b) == 0, "variable release retains A value");
  put(b, 0, vpiReleaseFlag);

  put(a, 0, vpiForceFlag);
  put(a, 0, vpiReleaseFlag);

  expect(a_force == 1, "removed A callback exact count");
  expect(a_late_force == 1, "new A callback delayed and overlap filtered");
  expect(b_force == 1, "B callback overlap filtered");
  expect(a_release == 2 && b_release == 1, "release overlap filtering");
  vpi_printf("PACKED_FORCE_RESULT failures=%d af=%d late=%d bf=%d ar=%d br=%d\n",
             failures, a_force, a_late_force, b_force, a_release, b_release);
  if (failures) vpi_sim_control(vpiFinish, 1);
  return 0;
}

static void reg(void)
{
  s_vpi_systf_data tf = {vpiSysTask, 0, "$packed_force_overlap_check",
                         check, 0, 0, 0};
  vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {reg, 0};
