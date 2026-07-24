#include <vpi_user.h>
static void show(const char*tag){
  vpiHandle h = vpi_handle_by_name("top.b", 0);
  s_vpi_value v; v.format = vpiIntVal; vpi_get_value(h, &v);
  s_vpi_time t; t.type = vpiSimTime; vpi_get_time(0, &t);
  vpi_printf("  [%d] %-18s b=%d\n", (int)t.low, tag, (int)v.value.integer);
}
static PLI_INT32 rw(p_cb_data c){ (void)c; show("cbReadWriteSynch"); return 0; }
static PLI_INT32 ro(p_cb_data c){ (void)c; show("cbReadOnlySynch");  return 0; }
static PLI_INT32 ae(p_cb_data c){ (void)c; show("cbAtEndOfSimTime"); return 0; }
static PLI_INT32 arm(PLI_BYTE8*u){ (void)u;
  s_vpi_time t; t.type=vpiSimTime; t.high=0; t.low=0; s_cb_data c;
  c.obj=0; c.time=&t; c.value=0; c.index=0; c.user_data=0;
  c.reason=cbReadWriteSynch; c.cb_rtn=rw; vpi_register_cb(&c);
  c.reason=cbAtEndOfSimTime; c.cb_rtn=ae; vpi_register_cb(&c);
  c.reason=cbReadOnlySynch;  c.cb_rtn=ro; vpi_register_cb(&c);
  return 0; }
static void reg(void){ s_vpi_systf_data d;
  d.type=vpiSysTask; d.sysfunctype=0; d.tfname="$arm_cbs";
  d.calltf=arm; d.compiletf=0; d.sizetf=0; d.user_data=0;
  vpi_register_systf(&d); }
void (*vlog_startup_routines[])(void) = { reg, 0 };
