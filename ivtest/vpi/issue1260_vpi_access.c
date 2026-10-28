#include <vpi_user.h>
#include <stdio.h>
#include <string.h>

static int failed;

static void check_access(const char *name, int expected_a, int expected_b)
{
      vpiHandle handle = vpi_handle_by_name((PLI_BYTE8 *)name, 0);
      int actual;
      if (!handle) {
	    vpi_printf("FAILED missing VPI declaration %s\n", name);
	    failed += 1;
	    return;
      }
      actual = vpi_get(vpiAccessType, handle);
      if (actual != expected_a && actual != expected_b) {
	    vpi_printf("FAILED %s vpiAccessType=%d want %d or %d\n",
		       name, actual, expected_a, expected_b);
	    failed += 1;
      }
}

static PLI_INT32 check(PLI_BYTE8 *ud)
{
      (void)ud;
      check_access("issue1260_vpi_access.bus.run", 1, 2);
      check_access("issue1260_vpi_access.bus.get", 1, 2);
      check_access("issue1260_vpi_access.dpi_import", 4, 4);
      check_access("issue1260_vpi_access.dpi_export", 3, 3);
      if (failed)
	    vpi_control(vpiFinish, 1);
      else
	    vpi_printf("PASSED\n");
      return 0;
}

static void register_check(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$check_issue1260_access";
      tf.calltf = check;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_check, 0 };
