#include <stdint.h>
#include <string.h>
#include "vpi_user.h"
typedef struct { const char *name; vpiHandle handle; s_cb_data cb; } probe_t;
static probe_t probes[] = {
  {"caliptra_top_tb.core_clk"},
  {"caliptra_top_tb.cptra_pwrgood"},
  {"caliptra_top_tb.cptra_rst_b"},
  {"caliptra_top_tb.caliptra_top_dut.rvtop.veer.core_rst_l"},
  {"caliptra_top_tb.caliptra_top_dut.rvtop.veer.ifu.ifc_fetch_req_f"},
  {"caliptra_top_tb.caliptra_top_dut.rvtop.veer.dec.tlu.dbg_tlu_halted_f"},
  {"caliptra_top_tb.caliptra_top_dut.rvtop.veer.dec.tlu.dcsr_single_step_running"},
  {"caliptra_top_tb.caliptra_top_dut.rvtop.veer.dma_ctrl.fifo_done"},
  {"caliptra_top_tb.caliptra_top_dut.rvtop.veer.dma_ctrl.fifo_valid"},
  {"caliptra_top_tb.caliptra_top_dut.rvtop.veer.lsu.bus_intf.bus_buffer.lsu_bus_buffer_empty_any"},
  {"caliptra_top_tb.caliptra_top_dut.rvtop.veer.lsu.stbuf.stbuf_specvld_any"},
  {"caliptra_top_tb.caliptra_top_dut.rvtop.veer.dec.arf.write_collision_unused"},
  {"caliptra_top_tb.caliptra_top_dut.rvtop.veer.dec.tlu.take_ext_int_start_d1"},
  {"caliptra_top_tb.caliptra_top_dut.rvtop.veer.dec.tlu.take_ext_int_start_d2"},
  {"caliptra_top_tb.caliptra_top_dut.rvtop.veer.dec.tlu.dec_tlu_flush_lower_r"},
  {"caliptra_top_tb.caliptra_top_dut.rvtop.veer.dec.tlu.tlu_i0_commit_cmt"},
  {"caliptra_top_tb.caliptra_top_dut.rvtop.veer.dec.tlu.o_cpu_halt_status"},
  {"caliptra_top_tb.caliptra_top_dut.doe.doe_inst.doe_fsm1.hard_rst_b"},
  {"caliptra_top_tb.caliptra_top_dut.doe.doe_inst.doe_fsm1.lock_uds_flow"},
  {"caliptra_top_tb.caliptra_top_dut.doe.doe_inst.doe_fsm1.lock_fe_flow"},
  {"caliptra_top_tb.caliptra_top_dut.doe.doe_inst.doe_fsm1.lock_hek_flow"},
  {"caliptra_top_tb.caliptra_top_dut.abr_inst.abr_reg_inst.external_wr_ack"},
  {"caliptra_top_tb.caliptra_top_dut.abr_inst.abr_reg_inst.external_rd_ack"},
  {"caliptra_top_tb.caliptra_top_dut.abr_inst.abr_reg_inst.external_pending"},
  {"caliptra_top_tb.caliptra_top_dut.abr_inst.abr_reg_inst.external_req"},
  {"caliptra_top_tb.caliptra_top_dut.abr_inst.rst_b"},
  {"caliptra_top_tb.caliptra_top_dut.abr_inst.abr_ctrl_inst.rst_b"},
  {"caliptra_top_tb.caliptra_top_dut.abr_inst.abr_reg_inst.rst"},
  {"caliptra_top_tb.caliptra_top_dut.abr_inst.abr_reg_hwif_in.reset_b"},
  {"caliptra_top_tb.caliptra_top_dut.abr_inst.abr_ctrl_inst.abr_reg_hwif_in.reset_b"},
  {"caliptra_top_tb.caliptra_top_dut.abr_inst.abr_reg_inst.hwif_in.reset_b"},
};
static void stamp(const char *tag) {
  s_vpi_time t={vpiSimTime,0,0,0}; vpi_get_time(NULL,&t);
  vpi_printf("STARTUP %s t=%llu\n",tag,((unsigned long long)t.high<<32)|t.low);
}
static void value(probe_t *p) {
  s_vpi_value v={vpiBinStrVal,{0}};
  vpi_get_value(p->handle,&v);
  vpi_printf("  %s=%s\n",p->name,v.value.str ? v.value.str : "<null>");
}
static PLI_INT32 changed(p_cb_data cb) {
  probe_t *p=(probe_t*)cb->user_data;
  stamp("CHANGE"); value(p); return 0;
}
static PLI_INT32 sample(p_cb_data cb) {
  size_t i; stamp(cb->user_data);
  for(i=0;i<sizeof(probes)/sizeof(probes[0]);i++) if(probes[i].handle) value(&probes[i]);
  if(!strcmp(cb->user_data,"STOP")) vpi_control(vpiFinish,0);
  return 0;
}
static void at(uint32_t delay,const char *label) {
  s_vpi_time time={vpiSimTime,0,delay,0};
  s_cb_data cb={0}; cb.reason=cbAfterDelay; cb.cb_rtn=sample; cb.time=&time; cb.user_data=(PLI_BYTE8*)label;
  vpi_register_cb(&cb);
}
static PLI_INT32 started(p_cb_data cb) {
  size_t i; (void)cb;
  vpi_printf("STARTUP precision=%d\n",vpi_get(vpiTimePrecision,NULL));
  for(i=0;i<sizeof(probes)/sizeof(probes[0]);i++) {
    probe_t *p=&probes[i];
    p->handle=vpi_handle_by_name((PLI_BYTE8*)p->name,NULL);
    if(!p->handle) { vpi_printf("STARTUP MISSING %s\n",p->name); continue; }
    memset(&p->cb,0,sizeof(p->cb));
    p->cb.reason=cbValueChange; p->cb.cb_rtn=changed; p->cb.obj=p->handle; p->cb.user_data=(PLI_BYTE8*)p;
    vpi_register_cb(&p->cb);
  }
  at(1,"POST-T0"); at(4999,"PRE-FIRST-CLK"); at(5001,"POST-FIRST-CLK"); at(6000,"STOP");
  return 0;
}
static void register_probe(void) {
  s_cb_data cb={0}; cb.reason=cbStartOfSimulation; cb.cb_rtn=started; vpi_register_cb(&cb);
}
void (*vlog_startup_routines[])(void)={register_probe,0};
