/* DPI companion for m6b_dpi_import_kill_test.
 *
 * c_block is an imported DPI *task*, so it runs on a coroutine and may
 * block: it calls the exported SV task sv_block, which waits #100. The
 * testbench kills the surrounding fork branch at t=10, while this stack
 * is parked. c_returns reports whether the call after the block was ever
 * reached -- it must stay 0.
 */
#include <stdio.h>

extern void sv_block(void);

static int returns = 0;

void c_block(void)
{
      sv_block();      /* parks here; the fork branch is disabled meanwhile */
      returns += 1;    /* must never be reached */
      printf("  c_block: returned (UNEXPECTED)\n");
}

int c_returns(void)
{
      return returns;
}
