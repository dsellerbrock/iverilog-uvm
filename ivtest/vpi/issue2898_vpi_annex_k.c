/* Issue #2898: verify the IEEE 1800 Annex K object and relation names. */
#include <stdio.h>
#include <string.h>
#include "vpi_user.h"
#include "sv_vpi_user.h"

static int report(const char *name)
{
      vpi_printf("MISSING %s\n", name);
      return 1;
}

static PLI_INT32 probe(PLI_BYTE8 *ud)
{
      int bad = 0;
      (void)ud;
#if !defined(vpiAlways) || (vpiAlways) != (1)
      bad += report("vpiAlways");
#endif
#if !defined(vpiFuncCall) || (vpiFuncCall) != (19)
      bad += report("vpiFuncCall");
#endif
#if !defined(vpiGate) || (vpiGate) != (21)
      bad += report("vpiGate");
#endif
#if !defined(vpiInitial) || (vpiInitial) != (24)
      bad += report("vpiInitial");
#endif
#if !defined(vpiSchedEvent) || (vpiSchedEvent) != (53)
      bad += report("vpiSchedEvent");
#endif
#if !defined(vpiSpecParam) || (vpiSpecParam) != (54)
      bad += report("vpiSpecParam");
#endif
#if !defined(vpiSwitch) || (vpiSwitch) != (55)
      bad += report("vpiSwitch");
#endif
#if !defined(vpiUdp) || (vpiUdp) != (65)
      bad += report("vpiUdp");
#endif
#if !defined(vpiVarSelect) || (vpiVarSelect) != (68)
      bad += report("vpiVarSelect");
#endif
#if !defined(vpiAttribute) || (vpiAttribute) != (105)
      bad += report("vpiAttribute");
#endif
#if !defined(vpiBitSelect) || (vpiBitSelect) != (106)
      bad += report("vpiBitSelect");
#endif
#if !defined(vpiDelayTerm) || (vpiDelayTerm) != (108)
      bad += report("vpiDelayTerm");
#endif
#if !defined(vpiDelayDevice) || (vpiDelayDevice) != (109)
      bad += report("vpiDelayDevice");
#endif
#if !defined(vpiFrame) || (vpiFrame) != (110)
      bad += report("vpiFrame");
#endif
#if !defined(vpiGateArray) || (vpiGateArray) != (111)
      bad += report("vpiGateArray");
#endif
#if !defined(vpiModuleArray) || (vpiModuleArray) != (112)
      bad += report("vpiModuleArray");
#endif
#if !defined(vpiPrimitiveArray) || (vpiPrimitiveArray) != (113)
      bad += report("vpiPrimitiveArray");
#endif
#if !defined(vpiSwitchArray) || (vpiSwitchArray) != (117)
      bad += report("vpiSwitchArray");
#endif
#if !defined(vpiUdpArray) || (vpiUdpArray) != (118)
      bad += report("vpiUdpArray");
#endif
#if !defined(vpiContAssignBit) || (vpiContAssignBit) != (128)
      bad += report("vpiContAssignBit");
#endif
#if !defined(vpiGenScopeArray) || (vpiGenScopeArray) != (133)
      bad += report("vpiGenScopeArray");
#endif
#if !defined(vpiGenVar) || (vpiGenVar) != (135)
      bad += report("vpiGenVar");
#endif
#if !defined(vpiDriver) || (vpiDriver) != (91)
      bad += report("vpiDriver");
#endif
#if !defined(vpiLoad) || (vpiLoad) != (93)
      bad += report("vpiLoad");
#endif
#if !defined(vpiModDataPathIn) || (vpiModDataPathIn) != (94)
      bad += report("vpiModDataPathIn");
#endif
#if !defined(vpiOperand) || (vpiOperand) != (97)
      bad += report("vpiOperand");
#endif
#if !defined(vpiPortInst) || (vpiPortInst) != (98)
      bad += report("vpiPortInst");
#endif
#if !defined(vpiProcess) || (vpiProcess) != (99)
      bad += report("vpiProcess");
#endif
#if !defined(vpiUse) || (vpiUse) != (101)
      bad += report("vpiUse");
#endif
#if !defined(vpiInTerm) || (vpiInTerm) != (120)
      bad += report("vpiInTerm");
#endif
#if !defined(vpiInstanceArray) || (vpiInstanceArray) != (121)
      bad += report("vpiInstanceArray");
#endif
#if !defined(vpiLocalDriver) || (vpiLocalDriver) != (122)
      bad += report("vpiLocalDriver");
#endif
#if !defined(vpiLocalLoad) || (vpiLocalLoad) != (123)
      bad += report("vpiLocalLoad");
#endif
#if !defined(vpiOutTerm) || (vpiOutTerm) != (124)
      bad += report("vpiOutTerm");
#endif
#if !defined(vpiPorts) || (vpiPorts) != (125)
      bad += report("vpiPorts");
#endif
#if !defined(vpiSimNet) || (vpiSimNet) != (126)
      bad += report("vpiSimNet");
#endif
#if !defined(vpiTaskFunc) || (vpiTaskFunc) != (127)
      bad += report("vpiTaskFunc");
#endif
#if !defined(vpiAutomatics) || (vpiAutomatics) != (136)
      bad += report("vpiAutomatics");
#endif
      vpi_printf("MISSING_COUNT=%d\n", bad);
      if (bad == 0) vpi_printf("PASSED\n");
      return 0;
}

static void reg(void)
{
      s_vpi_systf_data d;
      memset(&d, 0, sizeof d);
      d.type = vpiSysTask;
      d.tfname = (PLI_BYTE8*)"$probe";
      d.calltf = probe;
      vpi_register_systf(&d);
}

void (*vlog_startup_routines[])(void) = { reg, 0 };
