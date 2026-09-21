#include <stdio.h>
#include <string.h>
#include "sv_vpi_user.h"

static int failures, sig_changes, leaf_changes, mem_changes, forces, releases;
static vpiHandle sig_sel, leaf_sel, mem_sel;

static void expect(int ok, const char*what) {
  if (!ok) { vpi_printf("FAIL %s\n", what); failures++; }
}
static int intval(vpiHandle h) {
  s_vpi_value v = {vpiIntVal, {0}}; vpi_get_value(h, &v); return v.value.integer;
}
static PLI_INT32 changed(p_cb_data cb) {
  expect(cb->obj == sig_sel || cb->obj == leaf_sel || cb->obj == mem_sel,
         "callback object identity");
  expect(cb->value && cb->value->format == vpiIntVal,
         "callback selected value supplied");
  if (cb->value) expect(cb->value->value.integer == intval(cb->obj),
                        "callback selected value matches object");
  if (cb->obj == sig_sel) sig_changes++;
  else if (cb->obj == leaf_sel) leaf_changes++;
  else mem_changes++;
  return 0;
}
static PLI_INT32 forced(p_cb_data cb) {
  expect(cb->obj == mem_sel, "force callback object identity");
  expect(cb->value && cb->value->format == vpiIntVal &&
         cb->value->value.integer == intval(mem_sel), "force callback value");
  forces++; return 0;
}
static PLI_INT32 released(p_cb_data cb) {
  expect(cb->obj == mem_sel, "release callback object identity");
  expect(cb->value && cb->value->format == vpiIntVal &&
         cb->value->value.integer == intval(mem_sel), "release callback value");
  releases++; return 0;
}
static void register_cb(vpiHandle obj, int reason, PLI_INT32 (*fn)(p_cb_data)) {
  s_vpi_value value = {vpiIntVal, {0}};
  s_cb_data cb = {0}; cb.reason=reason; cb.cb_rtn=fn; cb.obj=obj; cb.value=&value;
  expect(vpi_register_cb(&cb)!=0, "callback registration");
}
static PLI_INT32 setup_call(char*unused) {
  (void)unused;
  vpiHandle root=vpi_handle_by_name("packed_api.descending",0);
  sig_sel=vpi_handle_by_name("packed_api.descending[1]",0);
  vpiHandle bit=vpi_handle_by_name("packed_api.descending[1][2]",0);
  leaf_sel=bit;
  mem_sel=vpi_handle_by_name("packed_api.memory[5][1]",0);
  vpiHandle net=vpi_handle_by_name("packed_api.packed_net[0]",0);
  vpiHandle net_word=vpi_handle_by_name("packed_api.net_memory[7]",0);
  vpiHandle net_word_sel=vpi_handle_by_name("packed_api.net_memory[7][1]",0);
  vpiHandle mem_leaf=vpi_handle_by_name("packed_api.memory[5][1][2]",0);
  vpiHandle net_leaf=vpi_handle_by_name("packed_api.packed_net[0][0]",0);
  expect(root && sig_sel && bit && mem_sel && net && net_word && net_word_sel,
         "selected handles");
  if (!sig_sel || !mem_sel) return 0;
  expect(vpi_get(vpiSize,sig_sel)==3,"signal prefix width");
  expect(vpi_get(vpiLeftRange,sig_sel)==2 &&
         vpi_get(vpiRightRange,sig_sel)==0,"signal prefix range");
  expect(!strcmp(vpi_get_str(vpiName,sig_sel),"descending[1]"),"prefix name");
  expect(!strcmp(vpi_get_str(vpiFullName,sig_sel),"packed_api.descending[1]"),
         "prefix full name");
  expect(vpi_get(vpiType,sig_sel)==vpiReg || vpi_get(vpiType,sig_sel)==vpiLogicVar,
         "signal prefix type");
  expect(bit && vpi_get(vpiType,bit)==vpiRegBit,
         "final bit type");
  expect(vpi_handle(vpiParent,sig_sel)==root,"largest packed signal parent");
  expect(vpi_handle(vpiParent,bit)==root,"largest packed bit parent");
  expect(vpi_get(vpiSize,mem_sel)==3,"array-word prefix width");
  expect(vpi_get(vpiLeftRange,mem_sel)==2 &&
         vpi_get(vpiRightRange,mem_sel)==0,"array prefix range");
  expect(vpi_handle(vpiParent,mem_sel)==vpi_handle_by_name("packed_api.memory[5]",0),
         "largest packed array-word parent");
  expect(vpi_get(vpiType,net_word_sel)==vpiNet &&
         vpi_handle(vpiParent,net_word_sel)==net_word &&
         intval(net_word_sel)==4,"packed net-array word selection");
  expect(!strcmp(vpi_get_str(vpiFullName,net_word_sel),
                 "packed_api.net_memory[7][1]"),"net-array selected fullname");
  s_cb_data rejected={0}; rejected.reason=cbForce; rejected.cb_rtn=forced;
  rejected.obj=bit;
  expect(vpi_register_cb(&rejected)==0,"signal variable-bit force cb rejected");
  rejected.obj=mem_leaf;
  expect(mem_leaf && vpi_register_cb(&rejected)==0,
         "array variable-bit force cb rejected");
  rejected.obj=net_leaf;
  vpiHandle legal_net_cb=vpi_register_cb(&rejected);
  expect(net_leaf && legal_net_cb,"net-bit force cb remains legal");
  if (legal_net_cb) vpi_remove_cb(legal_net_cb);
  expect(intval(sig_sel)==4,"descending mapping");
  expect(intval(mem_sel)==3,"array mapping");
  s_vpi_value hex={vpiHexStrVal,{0}}; vpi_get_value(sig_sel,&hex);
  expect(hex.value.str && !strcmp(hex.value.str,"4"),"selected hex offset");
  expect(vpi_handle_by_name("packed_api.descending[2]",0)==0,"outer OOB null");
  expect(vpi_handle_by_name("packed_api.descending[1][3]",0)==0,"inner OOB null");
  expect(vpi_handle_by_name("packed_api.descending[1][2][2]",0)==0,
         "scalar cannot be indexed again");
  expect(vpi_handle_by_name("packed_api.ascending[3][-2]",0)!=0,"negative index");
  vpiHandle escaped=vpi_handle_by_name("packed_api.\\escaped[unit] [1]",0);
  expect(escaped && intval(escaped)==6,"escaped packed selected name");

  s_vpi_value v={vpiIntVal,{0}}; v.value.integer=6;
  vpi_put_value(mem_sel,&v,0,vpiNoDelay); expect(intval(mem_sel)==6,"selected deposit");
  v.value.integer=3; vpi_put_value(mem_sel,&v,0,vpiForceFlag);
  expect(intval(mem_sel)==3,"selected force");
  v.value.integer=0; vpi_put_value(mem_sel,&v,0,vpiNoDelay);
  expect(intval(mem_sel)==3,"deposit hidden by force");
  vpi_put_value(mem_sel,&v,0,vpiReleaseFlag);
  register_cb(sig_sel,cbValueChange,changed);
  register_cb(leaf_sel,cbValueChange,changed);
  register_cb(mem_sel,cbValueChange,changed);
  register_cb(mem_sel,cbForce,forced);
  register_cb(mem_sel,cbRelease,released);
  v.value.integer=5; vpi_put_value(mem_sel,&v,0,vpiForceFlag);
  vpi_put_value(mem_sel,&v,0,vpiReleaseFlag);
  return 0;
}
static PLI_INT32 check_call(char*unused) {
  (void)unused;
  expect(sig_changes==1,"signal selected callback filtering");
  expect(leaf_changes==1,"leaf selected callback filtering");
  expect(mem_changes==2,"array selected callback and sibling filtering");
  expect(forces==1 && releases==1,"array force/release callbacks");
  vpi_printf("PACKED_API_RESULT failures=%d sig=%d leaf=%d mem=%d force=%d release=%d\n",
             failures,sig_changes,leaf_changes,mem_changes,forces,releases);
  return 0;
}
static void reg(void) {
  s_vpi_systf_data a={vpiSysTask,0,"$packed_api_setup",setup_call,0,0,0};
  s_vpi_systf_data b={vpiSysTask,0,"$packed_api_check",check_call,0,0,0};
  vpi_register_systf(&a); vpi_register_systf(&b);
}
void (*vlog_startup_routines[])(void)={reg,0};
