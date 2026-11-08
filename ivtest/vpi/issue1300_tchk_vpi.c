#include "vpi_user.h"
#include <string.h>

/* IEEE 1800 Annex K, for a header that predates them. */
#ifndef vpiTchk
#define vpiTchk 61
#define vpiTchkTerm 62
#define vpiTchkDataTerm 86
#define vpiTchkNotifier 87
#define vpiTchkRefTerm 88
#define vpiTchkType 38
#endif

static const char*name_of(vpiHandle h)
{
      return h ? vpi_get_str(vpiName, h) : "-";
}

static void show_term(const char*what, vpiHandle term)
{
      if (!term) {
	    vpi_printf(" %s=none", what);
	    return;
      }
      vpiHandle expr = vpi_handle(vpiExpr, term);
      vpiHandle cond = vpi_handle(vpiCondition, term);
      vpi_printf(" %s=%s/%d/edge%d/cond:%s", what,
		 expr ? vpi_get_str(vpiFullName, expr) : "-",
		 vpi_get(vpiType, term), (int)vpi_get(vpiEdge, term),
		 cond ? "yes" : "no");
}

static PLI_INT32 probe(p_cb_data cb)
{
      (void)cb;
      vpiHandle cell = vpi_handle_by_name("top.u1", 0);
      vpiHandle it = vpi_iterate(vpiTchk, cell);
      vpiHandle tchk, setup = 0;
      int count = 0;
      while (it && (tchk = vpi_scan(it))) {
	    s_vpi_delay delays;
	    s_vpi_time times[2];
	    int nexpr = 0, nterm = 0;
	    vpiHandle eit, expr;

	    count += 1;
	    if (vpi_get(vpiTchkType, tchk) == 1) setup = tchk;
	    vpi_printf("TCHK type=%d line=%d", (int)vpi_get(vpiTchkType, tchk),
		       (int)vpi_get(vpiLineNo, tchk));
	    show_term("ref", vpi_handle(vpiTchkRefTerm, tchk));
	    show_term("data", vpi_handle(vpiTchkDataTerm, tchk));
	    vpi_printf(" notifier=%s", name_of(vpi_handle(vpiTchkNotifier, tchk)));

	    delays.da = times;
	    delays.no_of_delays = vpi_get(vpiTchkType, tchk) == 8 ? 2 : 1;
	    delays.time_type = vpiScaledRealTime;
	    delays.mtm_flag = 0;
	    delays.append_flag = 0;
	    delays.pulsere_flag = 0;
	    vpi_get_delays(tchk, &delays);
	    vpi_printf(" limits=%g", times[0].real);
	    if (delays.no_of_delays == 2) vpi_printf(",%g", times[1].real);

	    eit = vpi_iterate(vpiExpr, tchk);
	    while (eit && (expr = vpi_scan(eit))) {
		  nexpr += 1;
		  if (vpi_get(vpiType, expr) == vpiTchkTerm) nterm += 1;
	    }
	    vpi_printf(" exprs=%d terms=%d\n", nexpr, nterm);
      }
      vpi_printf("TCHK_COUNT=%d\n", count);

      if (setup) {
	    s_vpi_delay delays;
	    s_vpi_time time;
	    delays.da = &time;
	    delays.no_of_delays = 1;
	    delays.time_type = vpiScaledRealTime;
	    delays.mtm_flag = 0;
	    delays.append_flag = 0;
	    delays.pulsere_flag = 0;
	    time.type = vpiScaledRealTime;
	    time.real = 5.0;
	    vpi_put_delays(setup, &delays);
	    time.real = 0.0;
	    vpi_get_delays(setup, &delays);
	    vpi_printf("SETUP_LIMIT=%g\n", time.real);
      }
      return 0;
}

static void startup(void)
{
      s_cb_data cb;
      memset(&cb, 0, sizeof cb);
      cb.reason = cbStartOfSimulation;
      cb.cb_rtn = probe;
      vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = { startup, 0 };
