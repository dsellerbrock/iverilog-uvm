/* DPI companion for m10d_dpi_export_multiinst_test: an imported "context"
 * function selects each instance of the exported `addk' via svSetScope and
 * verifies the per-instance parameter is honored. The exported symbol
 * `addk' is provided by the generated .dpiexport.c stub (one instance-
 * agnostic C entry point; the vvp runtime dispatches to the instance the
 * active svScope names). */
#include <stdio.h>
#include "svdpi.h"

extern int addk(int a);

int c_run(void)
{
      int fails = 0;
      const char* top = "m10d_dpi_export_multiinst_test";
      char nm[128];

      snprintf(nm, sizeof nm, "%s.u1", top);
      svScope u1 = svGetScopeFromName(nm);
      snprintf(nm, sizeof nm, "%s.u2", top);
      svScope u2 = svGetScopeFromName(nm);
      if (!u1 || !u2) {
	    printf("  FAIL: could not resolve instance scopes (u1=%p u2=%p)\n",
		   u1, u2);
	    return 1;
      }

      svSetScope(u1);
      int r1 = addk(5);          /* 5 + 100 */
      printf("  u1.addk(5)=%d\n", r1);   if (r1 != 105) fails += 1;

      svSetScope(u2);
      int r2 = addk(5);          /* 5 + 200 */
      printf("  u2.addk(5)=%d\n", r2);   if (r2 != 205) fails += 1;

      /* Switch back to confirm selection is per-call, not sticky-wrong. */
      svSetScope(u1);
      int r3 = addk(0);          /* 100 */
      printf("  u1.addk(0)=%d\n", r3);   if (r3 != 100) fails += 1;

      return fails;
}
