#include <vpi_user.h>
#include <sv_vpi_user.h>

/* These two callback reasons are not yet present in all installed headers. */
#define CB_ASSERTION_VACUOUS_SUCCESS 657
#define CB_ASSERTION_DISABLED_EVALUATION 658

static int vacuous;
static int disabled;
static int killed;
static int assertion_count;

static PLI_INT32 assertion_cb(PLI_INT32 reason, p_vpi_time time,
                              vpiHandle assertion,
                              p_vpi_attempt_info info,
                              PLI_BYTE8 *user_data)
{
      (void)time;
      (void)assertion;
      (void)info;
      (void)user_data;
      if (reason == CB_ASSERTION_VACUOUS_SUCCESS) vacuous += 1;
      if (reason == CB_ASSERTION_DISABLED_EVALUATION) disabled += 1;
      if (reason == cbAssertionKill) killed += 1;
      return 0;
}

static PLI_INT32 setup_calltf(PLI_BYTE8 *name)
{
      vpiHandle iterator, assertion;
      (void)name;
      iterator = vpi_iterate(vpiAssertion, 0);
      while (iterator && (assertion = vpi_scan(iterator))) {
            assertion_count += 1;
            vpi_register_assertion_cb(assertion,
                  CB_ASSERTION_VACUOUS_SUCCESS, assertion_cb, 0);
            vpi_register_assertion_cb(assertion,
                  CB_ASSERTION_DISABLED_EVALUATION, assertion_cb, 0);
            vpi_register_assertion_cb(assertion, cbAssertionKill,
                                      assertion_cb, 0);
      }
      return 0;
}

static PLI_INT32 check_calltf(PLI_BYTE8 *name)
{
      (void)name;
      if (assertion_count == 2 && vacuous == 1 && disabled == 1 &&
          killed == 2)
            vpi_printf("PASSED\n");
      else
            vpi_printf("FAILED: assertions=%d vacuous=%d disabled=%d killed=%d\n",
                       assertion_count, vacuous, disabled, killed);
      return 0;
}

static void register_tasks(void)
{
      s_vpi_systf_data task;
      task.type = vpiSysTask;
      task.tfname = "$setup_issue1350_callbacks";
      task.calltf = setup_calltf;
      task.compiletf = 0;
      task.sizetf = 0;
      task.user_data = 0;
      vpi_register_systf(&task);
      task.tfname = "$check_issue1350_callbacks";
      task.calltf = check_calltf;
      vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
