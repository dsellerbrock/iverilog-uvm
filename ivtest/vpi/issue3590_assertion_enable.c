#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>
static vpiHandle target;
static int starts, successes, failures, enables, disables, errors;
static PLI_INT32 assertion_cb(PLI_INT32 reason, p_vpi_time t, vpiHandle a,
                              p_vpi_attempt_info info, PLI_BYTE8 *data)
{
      (void)t; (void)a; (void)info; (void)data;
      if (reason == cbAssertionStart) starts++;
      if (reason == cbAssertionSuccess) successes++;
      if (reason == cbAssertionFailure) failures++;
      if (reason == cbAssertionEnable) enables++;
      if (reason == cbAssertionDisable) disables++;
      return 0;
}
static PLI_INT32 setup(PLI_BYTE8 *data)
{
      int reasons[] = {cbAssertionStart, cbAssertionSuccess, cbAssertionFailure,
                       cbAssertionEnable, cbAssertionDisable};
      unsigned i;
      (void)data;
      target = vpi_handle_by_name("top.target", 0);
      if (!target) { vpi_printf("ERROR: no assertion handle\n"); errors++; return 0; }
      for (i = 0; i < sizeof(reasons)/sizeof(reasons[0]); i++)
            vpi_register_assertion_cb(target, reasons[i], assertion_cb, 0);
      return 0;
}
static PLI_INT32 control(PLI_BYTE8 *data)
{
      int op = data ? vpiAssertionEnable : vpiAssertionDisable;
      if (!target || vpi_control(op, target) != 1) errors++;
      return 0;
}
static PLI_INT32 check(PLI_BYTE8 *data)
{
      (void)data;
      if (starts != 3 || successes != 1 || failures != 1 ||
          enables != 1 || disables != 1 || errors != 0)
            vpi_printf("ERROR: starts=%d success=%d failures=%d enable=%d disable=%d errors=%d\n",
                       starts, successes, failures, enables, disables, errors);
      else vpi_printf("VPI control counts OK\n");
      return 0;
}
static void reg(const char *name, PLI_INT32 (*fn)(PLI_BYTE8 *), PLI_BYTE8 *data)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask; tf.tfname = (PLI_BYTE8 *)name;
      tf.calltf = fn; tf.user_data = data;
      vpi_register_systf(&tf);
}
static void startup(void)
{
      reg("$setup3590", setup, 0);
      reg("$disable3590", control, 0);
      reg("$enable3590", control, (PLI_BYTE8 *)"enable");
      reg("$check3590", check, 0);
}
void (*vlog_startup_routines[])(void) = {startup, 0};
