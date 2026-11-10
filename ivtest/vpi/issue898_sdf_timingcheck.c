#include "vpi_user.h"
#include <string.h>

/* IEEE 1800 Annex K, for a header that predates them. */
#ifndef vpiTchk
#define vpiTchk 61
#define vpiTchkType 38
#define vpiWidth 4
#define vpiNoChange 7
#define vpiSetupHold 8
#define vpiFullskew 9
#define vpiRecrem 10
#endif

/* $tchk_dump(scope): print every timing-check limit of a module. */
static PLI_INT32 tchk_dump(PLI_BYTE8*name)
{
      vpiHandle call = vpi_handle(vpiSysTfCall, 0);
      vpiHandle args = vpi_iterate(vpiArgument, call);
      vpiHandle scope = vpi_scan(args);
      vpiHandle it = vpi_iterate(vpiTchk, scope), tchk;
      (void)name;
      vpi_free_object(args);
      while (it && (tchk = vpi_scan(it))) {
	    s_vpi_delay delays;
	    s_vpi_time times[2];
	    int type = vpi_get(vpiTchkType, tchk);
	    int two = type == vpiSetupHold || type == vpiRecrem
		   || type == vpiFullskew || type == vpiNoChange || type == vpiWidth;
	    delays.da = times;
	    delays.no_of_delays = two ? 2 : 1;
	    delays.time_type = vpiScaledRealTime;
	    delays.mtm_flag = 0;
	    delays.append_flag = 0;
	    delays.pulsere_flag = 0;
	    vpi_get_delays(tchk, &delays);
	    if (two)
		  vpi_printf("LIMITS line%d type%d %g %g\n", (int)vpi_get(vpiLineNo, tchk),
			     type, times[0].real, times[1].real);
	    else
		  vpi_printf("LIMITS line%d type%d %g\n", (int)vpi_get(vpiLineNo, tchk),
			     type, times[0].real);
      }
      return 0;
}

static void startup(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$tchk_dump";
      tf.calltf = tchk_dump;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { startup, 0 };
