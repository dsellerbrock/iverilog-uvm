#include <vpi_user.h>
#include <sv_vpi_user.h>

static int removed_hits;
static int remaining_hits;
static vpiHandle remaining_cb;

static PLI_INT32 removed_callback(PLI_INT32 reason, p_vpi_time time,
                                 vpiHandle assertion,
                                 p_vpi_attempt_info info,
                                 PLI_BYTE8 *user_data)
{
      (void)reason;
      (void)time;
      (void)assertion;
      (void)info;
      (void)user_data;
      removed_hits += 1;
      return 0;
}

static PLI_INT32 remaining_callback(PLI_INT32 reason, p_vpi_time time,
                                    vpiHandle assertion,
                                    p_vpi_attempt_info info,
                                    PLI_BYTE8 *user_data)
{
      (void)reason;
      (void)time;
      (void)assertion;
      (void)info;
      (void)user_data;
      remaining_hits += 1;
      return 0;
}

static PLI_INT32 setup_calltf(PLI_BYTE8 *name)
{
      vpiHandle iterator = vpi_iterate(vpiAssertion, 0);
      vpiHandle assertion = iterator ? vpi_scan(iterator) : 0;
      vpiHandle removed_cb = assertion
            ? vpi_register_assertion_cb(assertion, cbAssertionSuccess,
                                        removed_callback, 0) : 0;
      remaining_cb = assertion
            ? vpi_register_assertion_cb(assertion, cbAssertionSuccess,
                                        remaining_callback, 0) : 0;
      int distinct = assertion && removed_cb && remaining_cb
            && !vpi_compare_objects(assertion, removed_cb)
            && !vpi_compare_objects(assertion, remaining_cb)
            && !vpi_compare_objects(removed_cb, remaining_cb);
      PLI_INT32 removed = removed_cb ? vpi_remove_cb(removed_cb) : 0;
      vpi_printf("REGISTERED=%d distinct=%d REMOVE=%d\n",
                 removed_cb != 0 && remaining_cb != 0, distinct, removed);
      (void)name;
      return 0;
}

static PLI_INT32 check_calltf(PLI_BYTE8 *name)
{
      PLI_INT32 removed = remaining_cb ? vpi_remove_cb(remaining_cb) : 0;
      if (removed_hits == 0 && remaining_hits == 2 && removed)
            vpi_printf("PASSED\n");
      else
            vpi_printf("FAILED\n");
      vpi_printf("HITS=%d/%d REMOVE_REMAINING=%d\n",
                 removed_hits, remaining_hits, removed);
      (void)name;
      return 0;
}

static void register_tasks(void)
{
      s_vpi_systf_data task = {0};
      task.type = vpiSysTask;
      task.tfname = "$setup_remove_assertion_cb";
      task.calltf = setup_calltf;
      vpi_register_systf(&task);
      task.tfname = "$check_remove_assertion_cb";
      task.calltf = check_calltf;
      vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
