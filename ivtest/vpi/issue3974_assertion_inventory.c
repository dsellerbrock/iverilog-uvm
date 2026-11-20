#include <vpi_user.h>
#include <sv_vpi_user.h>
#include <string.h>

static struct assertion {
      const char *name;
      PLI_INT32 type;
      PLI_INT32 reason;
      PLI_UINT32 verdict_time;
      vpiHandle handle;
      unsigned callbacks;
} assertions[] = {
      { "top.concurrent_check", vpiCover, cbAssertionSuccess, 1, 0, 0 },
      { "top.g[1].generated_check", vpiAssert, cbAssertionFailure, 3, 0, 0 },
      { "top.g[2].generated_check", vpiAssert, cbAssertionFailure, 5, 0, 0 },
      { "top.proc_never", vpiAssert, cbAssertionSuccess, 0, 0, 0 },
      { "top.idle.immediate_check", vpiImmediateCover, 0, 0, 0, 0 },
};
enum { assertion_count = sizeof assertions / sizeof assertions[0] };
static int failed;

static void check_inventory(const char *phase)
{
      unsigned seen[assertion_count] = {0};
      vpiHandle it, obj;
      unsigned i;

      for (i = 0; i < assertion_count; ++i) {
            struct assertion *entry = &assertions[i];
            obj = vpi_handle_by_name(entry->name, 0);
            if (!obj || vpi_get(vpiType, obj) != entry->type
                || (entry->handle && obj != entry->handle)) {
                  vpi_printf("%s: missing or changed assertion %s\n",
                             phase, entry->name);
                  failed = 1;
            } else {
                  entry->handle = obj;
            }
      }

      it = vpi_iterate(vpiAssertion, 0);
      while (it && (obj = vpi_scan(it))) {
            for (i = 0; i < assertion_count; ++i)
                  if (obj == assertions[i].handle) break;
            if (i < assertion_count) {
                  ++seen[i];
            } else {
                  vpi_printf("%s: unexpected assertion %s\n",
                             phase, vpi_get_str(vpiFullName, obj));
                  failed = 1;
            }
      }
      for (i = 0; i < assertion_count; ++i) {
            if (seen[i] == 1) continue;
            vpi_printf("%s: expected one %s, found %u\n",
                       phase, assertions[i].name, seen[i]);
            failed = 1;
      }
}

static PLI_INT32 on_verdict(PLI_INT32 reason, p_vpi_time time,
                            vpiHandle assertion, p_vpi_attempt_info info,
                            PLI_BYTE8 *user_data)
{
      struct assertion *entry = (struct assertion *)user_data;
      ++entry->callbacks;
      if (assertion != entry->handle || reason != entry->reason
          || time->high || time->low != entry->verdict_time
          || info->attemptStartTime.high || info->attemptStartTime.low != 1) {
            vpi_printf("unexpected verdict for %s at %u (started at %u)\n",
                       entry->name, time->low, info->attemptStartTime.low);
            failed = 1;
      }
      return 0;
}

static PLI_INT32 check_phase(p_cb_data cb)
{
      unsigned i;
      if (cb->reason == cbEndOfCompile) {
            check_inventory("end of compile");
      } else if (cb->reason == cbStartOfSimulation) {
            vpiHandle cover, it, property;
            check_inventory("start of simulation");
            cover = assertions[0].handle;
            it = cover ? vpi_iterate(vpiPropertyInst, cover) : 0;
            property = it ? vpi_scan(it) : 0;
            if (!property || strcmp(vpi_get_str(vpiName, property), "p") != 0) {
                  vpi_printf("start of simulation: missing property instance p\n");
                  failed = 1;
            }
            if (property) vpi_free_object(it);
            for (i = 0; i < assertion_count; ++i) {
                  struct assertion *entry = &assertions[i];
                  if (entry->handle && entry->reason
                      && !vpi_register_assertion_cb(entry->handle, entry->reason,
                                                    on_verdict, (PLI_BYTE8 *)entry)) {
                        vpi_printf("could not subscribe to %s\n", entry->name);
                        failed = 1;
                  }
            }
      } else {
            check_inventory("end of simulation");
            for (i = 0; i < assertion_count; ++i) {
                  unsigned expected = assertions[i].verdict_time != 0;
                  if (assertions[i].callbacks == expected) continue;
                  vpi_printf("%s: expected %u verdicts, observed %u\n",
                             assertions[i].name, expected, assertions[i].callbacks);
                  failed = 1;
            }
            if (!failed) vpi_printf("PASSED: startup assertion inventory and verdicts\n");
      }
      return 0;
}

static void startup(void)
{
      s_cb_data cb = {0};
      cb.cb_rtn = check_phase;
      cb.reason = cbEndOfCompile;
      vpi_free_object(vpi_register_cb(&cb));
      cb.reason = cbStartOfSimulation;
      vpi_free_object(vpi_register_cb(&cb));
      cb.reason = cbEndOfSimulation;
      vpi_free_object(vpi_register_cb(&cb));
}

void (*vlog_startup_routines[])(void) = { startup, 0 };
