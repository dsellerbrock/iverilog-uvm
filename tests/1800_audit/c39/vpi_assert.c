#include <vpi_user.h>
#include <sv_vpi_user.h>

/* The simulator header omits this IEEE Annex K constant; test its standard value. */
#ifndef vpiAssertionDisable
#define vpiAssertionDisable 620
#define A3_HEADER_MISSING_ASSERTION_DISABLE 1
#endif

static PLI_INT32 failure_count = 0;
static PLI_INT32 success_count = 0;
static PLI_INT32 assertion_count = 0;
static PLI_INT32 callbacks_registered = 0;
static PLI_INT32 disable_result = 0;
static PLI_INT32 ieee_constant_assertion_count = 0;

static PLI_INT32 assertion_cb(PLI_INT32 reason, p_vpi_time cb_time,
                              vpiHandle assertion, p_vpi_attempt_info info,
                              PLI_BYTE8 *user_data)
{
  (void)cb_time;
  (void)assertion;
  (void)info;
  (void)user_data;
  if (reason == cbAssertionFailure) failure_count++;
  if (reason == cbAssertionSuccess) success_count++;
  return 0;
}

static PLI_INT32 probe(PLI_BYTE8 *user_data)
{
  vpiHandle call, args, arg, it, assertion, ieee_it;
  s_vpi_value mode = { .format = vpiIntVal, .value.integer = 0 };
  PLI_INT32 disable = 0;
  (void)user_data;

  call = vpi_handle(vpiSysTfCall, NULL);
  args = vpi_iterate(vpiArgument, call);
  arg = args ? vpi_scan(args) : NULL;
  if (arg) {
    vpi_get_value(arg, &mode);
    disable = mode.value.integer != 0;
  }
  if (args) vpi_free_object(args);

#ifdef A3_HEADER_MISSING_ASSERTION_DISABLE
  vpi_printf("HEADER_MISSING vpiAssertionDisable\n");
#endif
  vpi_printf("HEADER_VPI_ASSERTION %d\n", vpiAssertion);
  ieee_it = vpi_iterate(744, NULL);
  while (ieee_it && vpi_scan(ieee_it)) ieee_constant_assertion_count++;
  vpi_printf("ANNEX_ASSERTIONS %d\n", ieee_constant_assertion_count);

  it = vpi_iterate(vpiAssertion, NULL);
  if (!it) {
    vpi_printf("ASSERTIONS 0\n");
    return 0;
  }
  while ((assertion = vpi_scan(it))) {
    const char *full_name = vpi_get_str(vpiFullName, assertion);
    vpiHandle failure_cb, success_cb;
    assertion_count++;
    vpi_printf("ASSERT %s\n", full_name ? full_name : "<null>");
    failure_cb = vpi_register_assertion_cb(assertion, cbAssertionFailure,
                                            assertion_cb, NULL);
    success_cb = vpi_register_assertion_cb(assertion, cbAssertionSuccess,
                                            assertion_cb, NULL);
    if (failure_cb) callbacks_registered++;
    if (success_cb) callbacks_registered++;
    if (disable) disable_result = vpi_control(vpiAssertionDisable, assertion);
  }

  vpi_printf("ASSERTIONS %d\n", assertion_count);
  vpi_printf("CALLBACKS %d\n", callbacks_registered);
  if (disable) vpi_printf("DISABLE %d\n", disable_result);
  return 0;
}

static PLI_INT32 report(PLI_BYTE8 *user_data)
{
  (void)user_data;
  vpi_printf("COUNTS %d %d\n", failure_count, success_count);
  return 0;
}

static void register_tasks(void)
{
  static s_vpi_systf_data probe_data = { vpiSysTask, 0, "$probe39", probe, 0, 0, 0 };
  static s_vpi_systf_data report_data = { vpiSysTask, 0, "$report39", report, 0, 0, 0 };
  vpi_register_systf(&probe_data);
  vpi_register_systf(&report_data);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
