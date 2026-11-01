#include <vpi_user.h>
#include <sv_vpi_user.h>

static vpiHandle assertions[16];
static unsigned assertion_count;
static unsigned successes;
static unsigned failures;
static unsigned disables;
static unsigned enables;
static unsigned resets;
static unsigned identity_errors;
static unsigned result_errors;

static PLI_INT32 assertion_callback(PLI_INT32 reason, p_vpi_time time,
                                    vpiHandle assertion,
                                    p_vpi_attempt_info info,
                                    PLI_BYTE8 *user_data)
{
      unsigned matches = 0;
      PLI_INT32 line;
      (void)time;
      (void)info;
      (void)user_data;
      for (unsigned idx = 0; idx < assertion_count; idx++)
            if (vpi_compare_objects(assertions[idx], assertion)) matches++;
      if (matches != 1) identity_errors++;

      line = vpi_get(vpiLineNo, assertion);
      if (reason == cbAssertionSuccess) {
            successes++;
            if (line != 11 && line != 15 && line != 25) result_errors++;
      } else if (reason == cbAssertionFailure) {
            failures++;
            if (line != 13 && line != 17) result_errors++;
      } else if (reason == cbAssertionDisable) {
            disables++;
      } else if (reason == cbAssertionEnable) {
            enables++;
      } else if (reason == cbAssertionReset) {
            resets++;
      }
      vpi_printf("CALLBACK reason=%d line=%d\n", reason, line);
      return 0;
}

static PLI_INT32 setup_calltf(PLI_BYTE8 *name)
{
      vpiHandle iterator = vpi_iterate(vpiAssertion, 0);
      vpiHandle assertion;
      (void)name;
      while (iterator && (assertion = vpi_scan(iterator))) {
            if (assertion_count == sizeof assertions / sizeof assertions[0])
                  continue;
            assertions[assertion_count++] = assertion;
            vpi_register_assertion_cb(assertion, cbAssertionSuccess,
                                      assertion_callback, 0);
            vpi_register_assertion_cb(assertion, cbAssertionFailure,
                                      assertion_callback, 0);
            vpi_register_assertion_cb(assertion, cbAssertionDisable,
                                      assertion_callback, 0);
            vpi_register_assertion_cb(assertion, cbAssertionEnable,
                                      assertion_callback, 0);
            vpi_register_assertion_cb(assertion, cbAssertionReset,
                                      assertion_callback, 0);
      }
      vpi_printf("REGISTERED=%u\n", assertion_count);
      return 0;
}

static PLI_INT32 check_calltf(PLI_BYTE8 *name)
{
      int passed;
      (void)name;
      passed = assertion_count == 7 && successes == 3 && failures == 2
            && disables == 14 && enables == 14 && resets == 7
            && identity_errors == 0 && result_errors == 0;
      vpi_printf("RESULTS success=%u failure=%u disable=%u enable=%u reset=%u\n",
                 successes, failures, disables, enables, resets);
      vpi_printf("IDENTITY_ERRORS=%u RESULT_ERRORS=%u\n",
                 identity_errors, result_errors);
      vpi_printf(passed ? "PASSED: deferred assertion VPI results\n"
                        : "FAILED: deferred assertion VPI results\n");
      if (passed) vpi_printf("PASSED\n");
      return 0;
}

static void register_tasks(void)
{
      s_vpi_systf_data task = {0};
      task.type = vpiSysTask;
      task.tfname = "$setup_issue445_deferred_vpi";
      task.calltf = setup_calltf;
      vpi_register_systf(&task);
      task.tfname = "$check_issue445_deferred_vpi";
      task.calltf = check_calltf;
      vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
