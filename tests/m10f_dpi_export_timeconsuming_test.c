/* DPI companion for m10f_dpi_export_timeconsuming_test. c_run is an
 * imported DPI *task* (so it runs on a coroutine); it calls the exported SV
 * task sv_delay_add, which blocks on #delay. The vvp runtime parks this C
 * stack across simulation time and resumes it when the SV task returns. The
 * exported-task status is propagated as this imported task's acknowledgement. */
#include <stdio.h>

extern int sv_delay_add(int amount, int *copied_total, int *seed);

int c_run(int reps, int *copied_total, int *seed)
{
      int i;
      int status;
      int task_total;
      int task_seed = *seed;
      for (i = 0 ; i < reps ; i += 1) {
	    printf("  c_run: sv_delay_add(10) call %d\n", i);
	    status = sv_delay_add(10, &task_total, &task_seed);
	    if (status != 0)
		  return status;
	    /* blocks 10 ns; C stack parks meanwhile, then receives copy-out */
      }
      *copied_total = task_total;
      *seed = task_seed;
      printf("  c_run: done\n");
      return 0;
}
