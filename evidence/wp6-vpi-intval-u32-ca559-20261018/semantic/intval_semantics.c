#include <string.h>
#include <vpi_user.h>

static unsigned failures;

static void expect_int(const char*name, PLI_INT32 expected)
{
      vpiHandle handle = vpi_handle_by_name((PLI_BYTE8*)name, 0);
      s_vpi_value value = {vpiIntVal, {0}};
      if (!handle) {
            vpi_printf("FAIL missing signal %s\n", name);
            failures += 1;
            return;
      }
      vpi_get_value(handle, &value);
      if (value.value.integer != expected) {
            vpi_printf("FAIL %s: got %d want %d\n", name,
                       value.value.integer, expected);
            failures += 1;
      }
}

static PLI_INT32 check_values(PLI_BYTE8*unused)
{
      (void)unused;
      expect_int("top.signed_one", -1);
      expect_int("top.signed_byte", -5);
      expect_int("top.signed_31", -1073741823);
      expect_int("top.signed_32", (-2147483647 - 1));
      expect_int("top.unsigned_33", (-2147483647 - 1));
      expect_int("top.unsigned_xz", 8);
      expect_int("top.signed_xz", -8);
      expect_int("top.signed_z_sign", 1);
      expect_int("top.unsigned_one", 1);
      vpi_printf("%s vpiIntVal conversion\n",
                 failures ? "FAIL" : "PASS");
      return 0;
}

static void register_task(void)
{
      s_vpi_systf_data task;
      memset(&task, 0, sizeof task);
      task.type = vpiSysTask;
      task.tfname = "$check_intval_values";
      task.calltf = check_values;
      vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = {register_task, 0};
