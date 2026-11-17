#include <vpi_user.h>
#include <sv_vpi_user.h>

static int errors;

static PLI_INT32 control(PLI_BYTE8 *unused)
{
      vpiHandle call = vpi_handle(vpiSysTfCall, 0);
      vpiHandle args = vpi_iterate(vpiArgument, call);
      vpiHandle arg = vpi_scan(args);
      vpiHandle iter = vpi_iterate(vpiAssertion, 0);
      vpiHandle assertion = iter ? vpi_scan(iter) : 0;
      s_vpi_value value;
      (void)unused;
      value.format = vpiIntVal;
      vpi_get_value(arg, &value);
      if (!assertion || vpi_control(value.value.integer, assertion) != 1) {
            vpi_printf("FAILED control %d\n", value.value.integer);
            errors++;
      }
      return 0;
}

static PLI_INT32 check(PLI_BYTE8 *unused)
{
      (void)unused;
      if (!errors) vpi_printf("controls passed\n");
      return 0;
}

static void setup(void)
{
      s_vpi_systf_data task = {0};
      task.type = vpiSysTask;
      task.tfname = "$control_assertion";
      task.calltf = control;
      vpi_register_systf(&task);
      task.tfname = "$check_controls";
      task.calltf = check;
      vpi_register_systf(&task);
}
void (*vlog_startup_routines[])(void) = { setup, 0 };
