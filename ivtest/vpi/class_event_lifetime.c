/*
 * Check that an explicitly static class event remains a named-event VPI
 * object with static storage when passed out of an automatic class method.
 */
#include <string.h>
#include "vpi_user.h"

static PLI_INT32 check_static_class_event(PLI_BYTE8*ud)
{
      vpiHandle call = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv = vpi_iterate(vpiArgument, call);
      vpiHandle arg = argv ? vpi_scan(argv) : 0;
      int failed = 0;
      (void)ud;

      if (!arg) {
            vpi_printf("FAILED: missing event argument\n");
            failed = 1;
      } else {
            int type = vpi_get(vpiType, arg);
            int automatic = vpi_get(vpiAutomatic, arg);
            if (type != vpiNamedEvent) {
                  vpi_printf("FAILED: type=%d expected=%d\n",
                             type, vpiNamedEvent);
                  failed = 1;
            }
            if (automatic != 0) {
                  vpi_printf("FAILED: vpiAutomatic=%d expected=0\n",
                             automatic);
                  failed = 1;
            }
      }
      if (argv && vpi_scan(argv)) {
            vpi_printf("FAILED: unexpected extra argument\n");
            failed = 1;
      }

      if (failed)
            vpi_control(vpiFinish, 1);
      else
            vpi_printf("PASSED\n");
      return 0;
}

static void register_static_class_event_check(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$check_static_class_event";
      tf.calltf = check_static_class_event;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {
      register_static_class_event_check,
      0
};
