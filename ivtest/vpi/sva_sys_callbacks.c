/* IEEE 1800-2023 39.4.1 assertion system callbacks. Every reason is
 * registered at startup and logs its name and time; $sva_sys(op) calls
 * vpi_control(op, NULL). */
#include <stdio.h>
#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

static const struct { int reason; const char *name; } reasons[] = {
      { 615, "SysInitialized" }, { 616, "SysOn" }, { 617, "SysOff" },
      { 618, "SysEnd" }, { 619, "SysReset" }, { 631, "SysKill" },
      { 651, "SysEnablePassAction" }, { 652, "SysEnableFailAction" },
      { 653, "SysDisablePassAction" }, { 654, "SysDisableFailAction" },
      { 655, "SysEnableNonvacuousAction" }, { 656, "SysDisableVacuousAction" },
      { 659, "SysLock" }, { 660, "SysUnlock" },
};

static PLI_INT32 cb(p_cb_data d)
{
      vpi_printf("%s at %d\n", (const char *)d->user_data,
		 d->time ? (int)d->time->low : -1);
      return 0;
}

/* 39.4.2 per-assertion control reasons (Annex M values). */
static const struct { int reason; const char *name; } assert_reasons[] = {
      { 661, "Lock" }, { 662, "Unlock" },
      { 645, "EnablePassAction" }, { 646, "EnableFailAction" },
      { 647, "DisablePassAction" }, { 648, "DisableFailAction" },
      { 649, "EnableNonvacuousAction" }, { 650, "DisableVacuousAction" },
};

static PLI_INT32 assert_cb(PLI_INT32 reason, p_vpi_time t, vpiHandle a,
			   p_vpi_attempt_info info, PLI_BYTE8 *ud)
{
      (void)reason; (void)a;
      vpi_printf("  a1 %s at %d%s\n", (const char *)ud, (int)t->low,
		 info ? " (attempt info?)" : "");
      return 0;
}

static PLI_INT32 assert_cbs_calltf(PLI_BYTE8 *ud)
{
      vpiHandle call = vpi_handle(vpiSysTfCall, 0);
      vpiHandle it = vpi_iterate(vpiArgument, call);
      vpiHandle arg = vpi_scan(it), a;
      s_vpi_value v;
      size_t i;
      (void)ud;
      vpi_free_object(it);
      v.format = vpiStringVal;
      vpi_get_value(arg, &v);
      a = vpi_handle_by_name(v.value.str, 0);
      if (!a) { vpi_printf("no assertion %s\n", v.value.str); return 0; }
      for (i = 0; i < sizeof assert_reasons / sizeof *assert_reasons; i += 1)
	    vpi_register_assertion_cb(a, assert_reasons[i].reason, assert_cb,
				      (PLI_BYTE8 *)assert_reasons[i].name);
      return 0;
}

static PLI_INT32 sys_calltf(PLI_BYTE8 *ud)
{
      vpiHandle call = vpi_handle(vpiSysTfCall, 0);
      vpiHandle it = vpi_iterate(vpiArgument, call);
      vpiHandle op = vpi_scan(it);
      s_vpi_value v;
      (void)ud;
      vpi_free_object(it);
      v.format = vpiIntVal;
      vpi_get_value(op, &v);
      vpi_control(v.value.integer, (vpiHandle)0);
      return 0;
}

static void startup(void)
{
      s_vpi_systf_data tf;
      size_t i;
      for (i = 0; i < sizeof reasons / sizeof *reasons; i += 1) {
	    s_cb_data d;
	    memset(&d, 0, sizeof d);
	    d.reason = reasons[i].reason;
	    d.cb_rtn = cb;
	    d.user_data = (PLI_BYTE8 *)reasons[i].name;
	    if (!vpi_register_cb(&d))
		  vpi_printf("register %s failed\n", reasons[i].name);
      }
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = (PLI_BYTE8 *)"$sva_sys";
      tf.calltf = sys_calltf;
      vpi_register_systf(&tf);
      tf.tfname = (PLI_BYTE8 *)"$sva_assert_cbs";
      tf.calltf = assert_cbs_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { startup, 0 };
