#include <vpi_user.h>
#include <sv_vpi_user.h>

static PLI_INT32 check_coverage(p_cb_data cb)
{
      vpiHandle it, assertion;
      int attempts = 0, successes = 0, immediate = 0;
      int bad_type = 0;
      (void)cb;

      it = vpi_iterate(vpiAssertion, NULL);
      while (it && (assertion = vpi_scan(it))) {
            attempts += vpi_get(vpiAssertAttemptCovered, assertion);
            successes += vpi_get(vpiAssertSuccessCovered, assertion);
            if (vpi_get(vpiType, assertion) == vpiImmediateCover) {
                  immediate += 1;
                  if (vpi_get(vpiAssertAttemptCovered, assertion) != 1)
                        bad_type += 1;
            }
      }

      if (attempts == 5 && successes == 3 && immediate == 2 && !bad_type)
            vpi_printf("PASS: assertion cover API attempts=5 successes=3 immediate=2\nPASSED\n");
      else
            vpi_printf("FAIL: assertion cover API attempts=%d successes=%d immediate=%d bad_type=%d\n",
                       attempts, successes, immediate, bad_type);
      return 0;
}

static void register_check(void)
{
      s_cb_data cb;
      cb.reason = cbEndOfSimulation;
      cb.cb_rtn = check_coverage;
      cb.user_data = 0;
      cb.obj = 0;
      cb.time = 0;
      cb.value = 0;
      vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = { register_check, 0 };
