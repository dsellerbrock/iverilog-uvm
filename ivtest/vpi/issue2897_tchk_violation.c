#include <string.h>
#include "vpi_user.h"

static int violations;
static int valid_objects;

static PLI_INT32 on_tchk(p_cb_data cb)
{
      violations += 1;
      if (cb->obj && vpi_get(vpiType, cb->obj) == vpiTchk
	  && vpi_get(vpiTchkType, cb->obj) == vpiSetup)
	    valid_objects += 1;
      return 0;
}

static PLI_INT32 report(p_cb_data cb)
{
      (void)cb;
      vpi_printf("VIOLATION_CALLBACKS=%d OBJECTS=%d\n",
		 violations, valid_objects);
      return 0;
}

static void startup(void)
{
      s_cb_data cb;
      memset(&cb, 0, sizeof cb);
      cb.reason = cbTchkViolation;
      cb.cb_rtn = on_tchk;
      vpi_printf("REGISTER cbTchkViolation=%s\n",
		 vpi_register_cb(&cb) ? "ok" : "null");

      memset(&cb, 0, sizeof cb);
      cb.reason = cbEndOfSimulation;
      cb.cb_rtn = report;
      vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = { startup, 0 };
