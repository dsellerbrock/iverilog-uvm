/* IEEE 1800-2017/2023 6.21: an array word has the storage lifetime of its
 * declaring container, including an explicit override of lexical lifetime. */
#include <vpi_user.h>
#include <sv_vpi_user.h>
#include <string.h>

static int failed;

static PLI_INT32 check_word_lifetime_calltf(PLI_BYTE8*ud)
{
      vpiHandle call = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv = vpi_iterate(vpiArgument, call);
      vpiHandle expected_arg;
      s_vpi_value value;
      int expected;
      int idx;
      (void)ud;

      expected_arg = argv ? vpi_scan(argv) : 0;
      if (!expected_arg) {
            vpi_printf("FAILED missing expected-lifetime argument\n");
            vpi_control(vpiFinish, 1);
            return 0;
      }
      value.format = vpiIntVal;
      vpi_get_value(expected_arg, &value);
      expected = value.value.integer != 0;

      for (idx = 0; idx < 2; idx += 1) {
            vpiHandle container = vpi_scan(argv);
            vpiHandle word = container ? vpi_handle_by_index(container, 0) : 0;
            int actual;
            if (!word) {
                  vpi_printf("FAILED container %d has no word zero\n", idx);
                  failed += 1;
                  continue;
            }
            /* IEEE 1800 retains vpiMemoryWord as a relationship, not as the
             * required object type of the returned element. This reducer is
             * about declaration lifetime, so deliberately do not freeze a
             * legacy vpiMemoryWord object-type spelling here. */
            actual = vpi_get(vpiAutomatic, word);
            if (actual != expected) {
                  vpi_printf("FAILED container %d word vpiAutomatic=%d want=%d\n",
                             idx, actual, expected);
                  failed += 1;
            }
      }

      if (failed)
            vpi_control(vpiFinish, 1);
      return 0;
}

static void register_word_lifetime(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$check_word_lifetime";
      tf.calltf = check_word_lifetime_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_word_lifetime, 0 };
