/*
 * IEEE 1800 declaration lifetime is a property of the variable, not merely
 * its enclosing task. Check both lifetime overrides through the VPI surface
 * used by callback registration and delayed vpi_put_value validation.
 */
#include <vpi_user.h>
#include <sv_vpi_user.h>
#include <string.h>

static int failed;

static void fail_arg(int index, const char*what, int got, int want)
{
      vpi_printf("FAILED argument %d %s: got %d want %d\n",
                 index, what, got, want);
      failed += 1;
}

static PLI_INT32 check_decl_lifetime_calltf(PLI_BYTE8*ud)
{
      static const int expected_types[] = {
            vpiReg, vpiRealVar, vpiStringVar,
            vpiArrayVar, vpiArrayVar, vpiClassVar
      };
      vpiHandle call = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv = vpi_iterate(vpiArgument, call);
      vpiHandle arg;
      s_vpi_value value;
      int expected_auto;
      unsigned idx;
      (void)ud;

      arg = argv ? vpi_scan(argv) : 0;
      if (!arg) {
            vpi_printf("FAILED missing expected-lifetime argument\n");
            failed += 1;
            vpi_control(vpiFinish, 1);
            return 0;
      }
      value.format = vpiIntVal;
      vpi_get_value(arg, &value);
      expected_auto = value.value.integer != 0;

      for (idx = 0; idx < sizeof expected_types / sizeof expected_types[0];
           idx += 1) {
            int actual_type;
            int actual_auto;
            arg = vpi_scan(argv);
            if (!arg) {
                  vpi_printf("FAILED missing variable argument %u\n", idx + 1);
                  failed += 1;
                  break;
            }
            actual_type = vpi_get(vpiType, arg);
            actual_auto = vpi_get(vpiAutomatic, arg);
            if (actual_type != expected_types[idx])
                  fail_arg((int)idx + 1, "type", actual_type,
                           expected_types[idx]);
            if (actual_auto != expected_auto)
                  fail_arg((int)idx + 1, "vpiAutomatic", actual_auto,
                           expected_auto);
      }

      if (idx == sizeof expected_types / sizeof expected_types[0]
          && vpi_scan(argv)) {
            vpi_printf("FAILED unexpected extra variable argument\n");
            failed += 1;
      }
      if (failed)
            vpi_control(vpiFinish, 1);
      return 0;
}

static void register_decl_lifetime(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$check_decl_lifetime";
      tf.calltf = check_decl_lifetime_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_decl_lifetime, 0 };
