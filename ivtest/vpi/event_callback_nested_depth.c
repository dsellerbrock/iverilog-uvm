#include <vpi_user.h>
#include <assert.h>

static int outer_fired;
static int nested_active;
static int nested_fired;
static int seen[8];
static int seen_count;
static int immediate_failed;

static vpiHandle value_handle(void)
{
      vpiHandle handle = vpi_handle_by_name("test.value", 0);
      assert(handle);
      return handle;
}

static int read_value(vpiHandle handle)
{
      s_vpi_value value;
      value.format = vpiIntVal;
      vpi_get_value(handle, &value);
      return value.value.integer;
}

static void write_and_check(vpiHandle handle, int number)
{
      s_vpi_value value;
      value.format = vpiIntVal;
      value.value.integer = number;
      vpi_put_value(handle, &value, 0, vpiNoDelay);
      if (read_value(handle) != number)
            immediate_failed = 1;
}

static PLI_INT32 on_value(p_cb_data cb)
{
      vpiHandle target = value_handle();
      (void)cb;
      if (seen_count < 8)
            seen[seen_count++] = read_value(target);
      if (nested_active || nested_fired)
            return 0;
      nested_fired = 1;
      nested_active = 1;
      write_and_check(target, 1);
      write_and_check(target, 3);
      nested_active = 0;
      return 0;
}

static PLI_INT32 on_trigger(p_cb_data cb)
{
      vpiHandle target = value_handle();
      (void)cb;
      if (outer_fired)
            return 0;
      outer_fired = 1;
      write_and_check(target, 3);
      write_and_check(target, 2);
      return 0;
}

static void register_change(vpiHandle object, PLI_INT32 (*callback)(p_cb_data))
{
      static s_vpi_time time = {vpiSuppressTime, 0, 0, 0};
      static s_vpi_value value = {.format = vpiSuppressVal};
      s_cb_data cb = {0};
      cb.reason = cbValueChange;
      cb.cb_rtn = callback;
      cb.obj = object;
      cb.time = &time;
      cb.value = &value;
      assert(vpi_register_cb(&cb));
}

static PLI_INT32 arm(PLI_BYTE8*unused)
{
      (void)unused;
      register_change(value_handle(), on_value);
      register_change(vpi_handle_by_name("test.tap", 0), on_trigger);
      return 0;
}

static PLI_INT32 check(PLI_BYTE8*unused)
{
      static const int expected[] = {3, 1, 3, 2};
      unsigned idx;
      (void)unused;
      if (immediate_failed || seen_count != (int)(sizeof expected / sizeof expected[0])) {
            vpi_printf("nested callback immediate/order failure count=%d immediate=%d\n",
                       seen_count, immediate_failed);
            vpi_control(vpiFinish, 1);
            return 0;
      }
      for (idx = 0; idx < sizeof expected / sizeof expected[0]; ++idx) {
            if (seen[idx] != expected[idx]) {
                  vpi_printf("nested callback order[%u]=%d expected=%d\n",
                             idx, seen[idx], expected[idx]);
                  vpi_control(vpiFinish, 1);
                  return 0;
            }
      }
      return 0;
}

static void register_test(void)
{
      s_vpi_systf_data tf = {0};
      tf.type = vpiSysTask;
      tf.tfname = "$arm_nested_callback";
      tf.calltf = arm;
      vpi_register_systf(&tf);
      tf.tfname = "$check_nested_callback";
      tf.calltf = check;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {register_test, 0};
