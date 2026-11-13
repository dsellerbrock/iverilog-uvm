#include <string.h>
#include "vpi_user.h"
#include "sv_vpi_user.h"

static int report(const char*name)
{
      vpi_printf("MISSING %s\n", name);
      return 1;
}

static PLI_INT32 probe(PLI_BYTE8*ud)
{
      int bad = 0;
      (void)ud;
#if !defined(vpiIntConst) || (vpiIntConst) != 7
      bad += report("vpiIntConst");
#endif
#if !defined(vpiTimeConst) || (vpiTimeConst) != 8
      bad += report("vpiTimeConst");
#endif
#if !defined(vpiCaseExact) || (vpiCaseExact) != 1
      bad += report("vpiCaseExact");
#endif
#if !defined(vpiNetDeclAssign) || (vpiNetDeclAssign) != 43
      bad += report("vpiNetDeclAssign");
#endif
#if !defined(vpiScheduled) || (vpiScheduled) != 46
      bad += report("vpiScheduled");
#endif
#if !defined(vpiActive) || (vpiActive) != 49
      bad += report("vpiActive");
#endif
#if !defined(vpiCell) || (vpiCell) != 51
      bad += report("vpiCell");
#endif
#if !defined(vpiConfig) || (vpiConfig) != 52
      bad += report("vpiConfig");
#endif
#if !defined(vpiDecompile) || (vpiDecompile) != 54
      bad += report("vpiDecompile");
#endif
#if !defined(vpiDelayType) || (vpiDelayType) != 56
      bad += report("vpiDelayType");
#endif
#if !defined(vpiModPathDelay) || (vpiModPathDelay) != 1
      bad += report("vpiModPathDelay");
#endif
#if !defined(vpiInterModPathDelay) || (vpiInterModPathDelay) != 2
      bad += report("vpiInterModPathDelay");
#endif
#if !defined(vpiMIPDelay) || (vpiMIPDelay) != 3
      bad += report("vpiMIPDelay");
#endif
#if !defined(vpiLibrary) || (vpiLibrary) != 58
      bad += report("vpiLibrary");
#endif
#if !defined(vpiOffset) || (vpiOffset) != 60
      bad += report("vpiOffset");
#endif
#if !defined(vpiResolvedNetType) || (vpiResolvedNetType) != 61
      bad += report("vpiResolvedNetType");
#endif
#if !defined(vpiSaveRestartID) || (vpiSaveRestartID) != 62
      bad += report("vpiSaveRestartID");
#endif
#if !defined(vpiSaveRestartLocation) || (vpiSaveRestartLocation) != 63
      bad += report("vpiSaveRestartLocation");
#endif
#if !defined(vpiValid) || (vpiValid) != 64
      bad += report("vpiValid");
#endif
#if !defined(vpiValidFalse) || (vpiValidFalse) != 0
      bad += report("vpiValidFalse");
#endif
#if !defined(vpiValidTrue) || (vpiValidTrue) != 1
      bad += report("vpiValidTrue");
#endif
#if !defined(vpiModPathHasIfNone) || (vpiModPathHasIfNone) != 71
      bad += report("vpiModPathHasIfNone");
#endif
#if !defined(vpiIndexedPartSelectType) || (vpiIndexedPartSelectType) != 72
      bad += report("vpiIndexedPartSelectType");
#endif
#if !defined(vpiPosIndexed) || (vpiPosIndexed) != 1
      bad += report("vpiPosIndexed");
#endif
#if !defined(vpiNegIndexed) || (vpiNegIndexed) != 2
      bad += report("vpiNegIndexed");
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
