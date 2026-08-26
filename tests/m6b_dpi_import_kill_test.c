/* DPI companion for m6b_dpi_import_kill_test.
 *
 * c_block is an imported DPI *task*, so it runs on a coroutine and may
 * block: it calls the exported SV task sv_block, which waits #100. The
 * testbench kills the surrounding fork branch at t=10, while this stack
 * is parked. IEEE 1800 35.9 requires the exported task to return status 1,
 * after which C observes the disabled state, performs cleanup, and returns
 * 1 to acknowledge the imported-task disable. The killed SV tails stay dead.
 */
#include "svdpi.h"

extern int sv_block(void);

static int cleanup_count;
static int export_status = -1;
static int disabled_state = -1;

int c_block(void)
{
      export_status = sv_block(); /* parks; enclosing branch is disabled */
      disabled_state = svIsDisabledState();
      cleanup_count += 1;
      return disabled_state ? 1 : 0;
}

int c_returns(void)
{
      return cleanup_count;
}

int c_export_status(void)
{
      return export_status;
}

int c_disabled_state(void)
{
      return disabled_state;
}
