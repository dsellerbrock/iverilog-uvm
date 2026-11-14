/*
 * Issue #1344 (IEEE 1800-2023 38.36.3): vpi_register_cb() with reason
 * cbSignal and index set to a signal traps that signal; the callback runs
 * at a safe point with cb_data.index naming the signal, and the signal's
 * default action (termination, for SIGUSR1) does not happen. A reason
 * with an index that is no signal is rejected.
 */
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include "vpi_user.h"

#ifndef cbSignal
#define cbSignal 29
#endif

static int hits, right_index;

static PLI_INT32 on_signal(p_cb_data cb)
{
      hits += 1;
      if (cb->index == SIGUSR1) right_index += 1;
      return 0;
}

static PLI_INT32 raise_calltf(PLI_BYTE8*ud)
{
      (void)ud;
      raise(SIGUSR1);
      return 0;
}

static PLI_INT32 report_calltf(PLI_BYTE8*ud)
{
      (void)ud;
      vpi_printf("SIGNAL_CALLBACKS=%d RIGHT_INDEX=%d\n", hits, right_index);
      if (hits == 1 && right_index == 1) vpi_printf("VPI CBSIGNAL PASS\nPASSED\n");
      return 0;
}

static void reg(void)
{
      s_vpi_systf_data d;
      s_cb_data cb;
      memset(&d, 0, sizeof d);
      d.type = vpiSysTask;
      d.tfname = (PLI_BYTE8*)"$raise_usr1";
      d.calltf = raise_calltf;
      vpi_register_systf(&d);
      d.tfname = (PLI_BYTE8*)"$report";
      d.calltf = report_calltf;
      vpi_register_systf(&d);

      memset(&cb, 0, sizeof cb);
      cb.reason = cbSignal;
      cb.cb_rtn = on_signal;
      cb.index = SIGUSR1;
      vpi_printf("REGISTER SIGUSR1=%s\n", vpi_register_cb(&cb) ? "ok" : "null");
      cb.index = 0;
      vpi_printf("REGISTER index0=%s\n", vpi_register_cb(&cb) ? "ok" : "null");
}

void (*vlog_startup_routines[])(void) = { reg, 0 };
