#include <vpi_user.h>
#include <sv_vpi_user.h>
#include <string.h>

static int vacuous_count;
static int disabled_count;
static int kill_count;
static int reset_count;
static int bad_info;

static PLI_INT32 assertion_event(PLI_INT32 reason, p_vpi_time time,
				 vpiHandle assertion,
				 p_vpi_attempt_info info, PLI_BYTE8 *user_data)
{
      (void)time;
      (void)assertion;
      (void)user_data;
      if ((reason == cbAssertionVacuousSuccess
	   || reason == cbAssertionDisabledEvaluation
	   || reason == cbAssertionKill || reason == cbAssertionReset)
	  && info != 0)
	    bad_info += 1;
      switch (reason) {
	case cbAssertionVacuousSuccess: vacuous_count += 1; break;
	case cbAssertionDisabledEvaluation: disabled_count += 1; break;
	case cbAssertionKill: kill_count += 1; break;
	case cbAssertionReset: reset_count += 1; break;
	default: break;
      }
      return 0;
}

static PLI_INT32 setup_calltf(PLI_BYTE8 *name)
{
      static const int reasons[] = {
	    cbAssertionStart, cbAssertionSuccess, cbAssertionFailure,
	    cbAssertionVacuousSuccess, cbAssertionDisabledEvaluation,
	    cbAssertionKill, cbAssertionReset
      };
      vpiHandle iter, assertion;
      size_t idx;
      (void)name;
      iter = vpi_iterate(vpiAssertion, 0);
      while (iter && (assertion = vpi_scan(iter)))
	    for (idx = 0; idx < sizeof reasons / sizeof reasons[0]; ++idx)
		  vpi_register_assertion_cb(assertion, reasons[idx],
					   assertion_event, 0);
      return 0;
}

static PLI_INT32 check_calltf(PLI_BYTE8 *name)
{
      (void)name;
      if (vacuous_count == 1 && disabled_count == 1 && kill_count == 2
	  && reset_count == 2 && bad_info == 0) {
	    vpi_printf("PASSED: assertion event callbacks vacuous=%d disabled=%d kill=%d reset=%d\n",
		       vacuous_count, disabled_count, kill_count, reset_count);
	    vpi_printf("PASSED\n");
	  } else {
	    vpi_printf("FAILED: assertion event callbacks vacuous=%d disabled=%d kill=%d reset=%d bad_info=%d\n",
		       vacuous_count, disabled_count, kill_count, reset_count,
		       bad_info);
	  }
      return 0;
}

static void register_tasks(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$issue1350_setup";
      tf.calltf = setup_calltf;
      vpi_register_systf(&tf);
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$issue1350_check";
      tf.calltf = check_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
