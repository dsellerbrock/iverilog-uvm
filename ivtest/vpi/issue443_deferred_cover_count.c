#include <stdio.h>
#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

enum { COVER_COUNT = 5 };

static const char *cover_names[COVER_COUNT] = {
      "observed_hit", "observed_miss", "observed_boundary",
      "final_hit", "final_miss"
};

static const int expected[COVER_COUNT][2] = {
      { 2, 2 }, { 1, 0 }, { 1, 1 }, { 1, 1 }, { 1, 0 }
};

static int actual[COVER_COUNT][2];

static int cover_index(const char *full_name)
{
      int idx;
      if (!full_name) return -1;
      for (idx = 0; idx < COVER_COUNT; idx += 1) {
            if (strstr(full_name, cover_names[idx])) return idx;
      }
      return -1;
}

static PLI_INT32 check_deferred_cover_counts(p_cb_data cb)
{
      vpiHandle iter = vpi_iterate(vpiAssertion, NULL);
      vpiHandle assertion;
      int found = 0;
      int passed = 1;
      int idx;
      (void)cb;

      while (iter && (assertion = vpi_scan(iter))) {
            if (vpi_get(vpiType, assertion) != vpiImmediateCover) continue;
            idx = cover_index(vpi_get_str(vpiFullName, assertion));
            if (idx < 0) continue;
            actual[idx][0] = vpi_get(vpiAssertAttemptCovered, assertion);
            actual[idx][1] = vpi_get(vpiAssertSuccessCovered, assertion);
            found |= 1 << idx;
      }

      for (idx = 0; idx < COVER_COUNT; idx += 1) {
            if (!(found & (1 << idx))
                || actual[idx][0] != expected[idx][0]
                || actual[idx][1] != expected[idx][1]) {
                  vpi_printf("FAIL: %s found=%d attempts=%d successes=%d "
                             "expected=%d/%d\n",
                             cover_names[idx], !!(found & (1 << idx)),
                             actual[idx][0], actual[idx][1],
                             expected[idx][0], expected[idx][1]);
                  passed = 0;
            }
      }

      if (passed) vpi_printf("PASS: issue443 deferred cover VPI counts\n");
      return 0;
}

static void issue443_deferred_cover_count_init(void)
{
      s_cb_data cb;
      memset(&cb, 0, sizeof cb);
      cb.reason = cbEndOfSimulation;
      cb.cb_rtn = check_deferred_cover_counts;
      vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = {
      issue443_deferred_cover_count_init,
      0
};
