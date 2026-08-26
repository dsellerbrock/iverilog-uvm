/* DPI companion for m10f_dpi_export_timeconsuming_test. c_run is an
 * imported DPI *task* (so it runs on a coroutine); it calls the exported SV
 * task sv_delay_add, which blocks on #delay. The vvp runtime parks this C
 * stack across simulation time and resumes it when the SV task returns. */
#include <stdio.h>

extern void sv_delay_add(int amount, int *copied_total, int *seed);

void c_run(int reps, int *copied_total, int *seed)
{
      int i;
      int task_total;
      int task_seed = *seed;
      for (i = 0 ; i < reps ; i += 1) {
	    printf("  c_run: sv_delay_add(10) call %d\n", i);
	    sv_delay_add(10, &task_total, &task_seed);
	    /* blocks 10 ns; C stack parks meanwhile, then receives copy-out */
      }
      *copied_total = task_total;
      *seed = task_seed;
      printf("  c_run: done\n");
}
