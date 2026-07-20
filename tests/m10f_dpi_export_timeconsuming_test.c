/* DPI companion for m10f_dpi_export_timeconsuming_test. c_run is an
 * imported DPI *task* (so it runs on a coroutine); it calls the exported SV
 * task sv_delay_add, which blocks on #delay. The vvp runtime parks this C
 * stack across simulation time and resumes it when the SV task returns. */
#include <stdio.h>

extern void sv_delay_add(int amount);

void c_run(int reps)
{
      int i;
      for (i = 0 ; i < reps ; i += 1) {
	    printf("  c_run: sv_delay_add(10) call %d\n", i);
	    sv_delay_add(10);   /* blocks 10 ns; C stack parks meanwhile */
      }
      printf("  c_run: done\n");
}
