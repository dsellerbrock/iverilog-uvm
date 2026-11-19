#include <vpi_user.h>
#include <sv_vpi_user.h>
#include <string.h>

static unsigned successes, failures;
static int bad;

static PLI_INT32 verdict(PLI_INT32 reason, p_vpi_time now, vpiHandle assertion,
                       p_vpi_attempt_info info, PLI_BYTE8 *data)
{
      unsigned tick, start;
      (void)assertion;
      (void)data;
      if (reason == cbAssertionSuccess) {
            tick = 43;
            start = ++successes;
      } else {
            start = 40 + failures++;
            tick = start < 44 ? 45 : 47;
      }
      if (!info || now->high || now->low != (2 * tick - 1) * 1000 ||
          info->attemptStartTime.high ||
          info->attemptStartTime.low != (2 * start - 1) * 1000)
            bad = 1;
      return 0;
}

static PLI_INT32 watch(ICARUS_VPI_CONST PLI_BYTE8 *data)
{
      vpiHandle it = vpi_iterate(vpiAssertion, 0);
      vpiHandle assertion;
      (void)data;
      while (it && (assertion = vpi_scan(it))) {
            const char *name = vpi_get_str(vpiName, assertion);
            if (name && strcmp(name, "delayed") == 0) {
                  if (!vpi_register_assertion_cb(assertion, cbAssertionSuccess, verdict, 0) ||
                      !vpi_register_assertion_cb(assertion, cbAssertionFailure, verdict, 0))
                        bad = 1;
                  vpi_free_object(it);
                  return 0;
            }
      }
      bad = 1;
      return 0;
}

static PLI_INT32 check(ICARUS_VPI_CONST PLI_BYTE8 *data)
{
      (void)data;
      if (bad || successes != 39 || failures != 6) {
            vpi_printf("incorrect nexttime VPI verdicts: passes=%u failures=%u bad=%d\n",
                       successes, failures, bad);
            vpi_control(vpiFinish, 1);
      }
      return 0;
}

static void register_tasks(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$issue3793_watch";
      tf.calltf = watch;
      vpi_register_systf(&tf);
      tf.tfname = "$issue3793_check";
      tf.calltf = check;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {register_tasks, 0};
