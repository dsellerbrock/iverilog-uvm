/* Issue #2900: verify Annex K operator type names and values. */
#include <string.h>
#include "vpi_user.h"
#include "sv_vpi_user.h"

static PLI_INT32 probe(PLI_BYTE8*ud)
{
      int bad = 0;
      (void)ud;
#if !defined(vpiMinusOp) || (vpiMinusOp) != (1)
      vpi_printf("MISSING vpiMinusOp\n");
      bad += 1;
#endif
#if !defined(vpiPlusOp) || (vpiPlusOp) != (2)
      vpi_printf("MISSING vpiPlusOp\n");
      bad += 1;
#endif
#if !defined(vpiNotOp) || (vpiNotOp) != (3)
      vpi_printf("MISSING vpiNotOp\n");
      bad += 1;
#endif
#if !defined(vpiBitNegOp) || (vpiBitNegOp) != (4)
      vpi_printf("MISSING vpiBitNegOp\n");
      bad += 1;
#endif
#if !defined(vpiUnaryAndOp) || (vpiUnaryAndOp) != (5)
      vpi_printf("MISSING vpiUnaryAndOp\n");
      bad += 1;
#endif
#if !defined(vpiUnaryNandOp) || (vpiUnaryNandOp) != (6)
      vpi_printf("MISSING vpiUnaryNandOp\n");
      bad += 1;
#endif
#if !defined(vpiUnaryOrOp) || (vpiUnaryOrOp) != (7)
      vpi_printf("MISSING vpiUnaryOrOp\n");
      bad += 1;
#endif
#if !defined(vpiUnaryNorOp) || (vpiUnaryNorOp) != (8)
      vpi_printf("MISSING vpiUnaryNorOp\n");
      bad += 1;
#endif
#if !defined(vpiUnaryXorOp) || (vpiUnaryXorOp) != (9)
      vpi_printf("MISSING vpiUnaryXorOp\n");
      bad += 1;
#endif
#if !defined(vpiUnaryXNorOp) || (vpiUnaryXNorOp) != (10)
      vpi_printf("MISSING vpiUnaryXNorOp\n");
      bad += 1;
#endif
#if !defined(vpiSubOp) || (vpiSubOp) != (11)
      vpi_printf("MISSING vpiSubOp\n");
      bad += 1;
#endif
#if !defined(vpiDivOp) || (vpiDivOp) != (12)
      vpi_printf("MISSING vpiDivOp\n");
      bad += 1;
#endif
#if !defined(vpiModOp) || (vpiModOp) != (13)
      vpi_printf("MISSING vpiModOp\n");
      bad += 1;
#endif
#if !defined(vpiEqOp) || (vpiEqOp) != (14)
      vpi_printf("MISSING vpiEqOp\n");
      bad += 1;
#endif
#if !defined(vpiNeqOp) || (vpiNeqOp) != (15)
      vpi_printf("MISSING vpiNeqOp\n");
      bad += 1;
#endif
#if !defined(vpiCaseEqOp) || (vpiCaseEqOp) != (16)
      vpi_printf("MISSING vpiCaseEqOp\n");
      bad += 1;
#endif
#if !defined(vpiCaseNeqOp) || (vpiCaseNeqOp) != (17)
      vpi_printf("MISSING vpiCaseNeqOp\n");
      bad += 1;
#endif
#if !defined(vpiGtOp) || (vpiGtOp) != (18)
      vpi_printf("MISSING vpiGtOp\n");
      bad += 1;
#endif
#if !defined(vpiGeOp) || (vpiGeOp) != (19)
      vpi_printf("MISSING vpiGeOp\n");
      bad += 1;
#endif
#if !defined(vpiLtOp) || (vpiLtOp) != (20)
      vpi_printf("MISSING vpiLtOp\n");
      bad += 1;
#endif
#if !defined(vpiLeOp) || (vpiLeOp) != (21)
      vpi_printf("MISSING vpiLeOp\n");
      bad += 1;
#endif
#if !defined(vpiLShiftOp) || (vpiLShiftOp) != (22)
      vpi_printf("MISSING vpiLShiftOp\n");
      bad += 1;
#endif
#if !defined(vpiRShiftOp) || (vpiRShiftOp) != (23)
      vpi_printf("MISSING vpiRShiftOp\n");
      bad += 1;
#endif
#if !defined(vpiAddOp) || (vpiAddOp) != (24)
      vpi_printf("MISSING vpiAddOp\n");
      bad += 1;
#endif
#if !defined(vpiMultOp) || (vpiMultOp) != (25)
      vpi_printf("MISSING vpiMultOp\n");
      bad += 1;
#endif
#if !defined(vpiLogAndOp) || (vpiLogAndOp) != (26)
      vpi_printf("MISSING vpiLogAndOp\n");
      bad += 1;
#endif
#if !defined(vpiLogOrOp) || (vpiLogOrOp) != (27)
      vpi_printf("MISSING vpiLogOrOp\n");
      bad += 1;
#endif
#if !defined(vpiBitAndOp) || (vpiBitAndOp) != (28)
      vpi_printf("MISSING vpiBitAndOp\n");
      bad += 1;
#endif
#if !defined(vpiBitOrOp) || (vpiBitOrOp) != (29)
      vpi_printf("MISSING vpiBitOrOp\n");
      bad += 1;
#endif
#if !defined(vpiBitXorOp) || (vpiBitXorOp) != (30)
      vpi_printf("MISSING vpiBitXorOp\n");
      bad += 1;
#endif
#if !defined(vpiBitXNorOp) || (vpiBitXNorOp) != (31)
      vpi_printf("MISSING vpiBitXNorOp\n");
      bad += 1;
#endif
#if !defined(vpiConditionOp) || (vpiConditionOp) != (32)
      vpi_printf("MISSING vpiConditionOp\n");
      bad += 1;
#endif
#if !defined(vpiConcatOp) || (vpiConcatOp) != (33)
      vpi_printf("MISSING vpiConcatOp\n");
      bad += 1;
#endif
#if !defined(vpiMultiConcatOp) || (vpiMultiConcatOp) != (34)
      vpi_printf("MISSING vpiMultiConcatOp\n");
      bad += 1;
#endif
#if !defined(vpiEventOrOp) || (vpiEventOrOp) != (35)
      vpi_printf("MISSING vpiEventOrOp\n");
      bad += 1;
#endif
#if !defined(vpiListOp) || (vpiListOp) != (37)
      vpi_printf("MISSING vpiListOp\n");
      bad += 1;
#endif
#if !defined(vpiMinTypMaxOp) || (vpiMinTypMaxOp) != (38)
      vpi_printf("MISSING vpiMinTypMaxOp\n");
      bad += 1;
#endif
#if !defined(vpiPosedgeOp) || (vpiPosedgeOp) != (39)
      vpi_printf("MISSING vpiPosedgeOp\n");
      bad += 1;
#endif
#if !defined(vpiNegedgeOp) || (vpiNegedgeOp) != (40)
      vpi_printf("MISSING vpiNegedgeOp\n");
      bad += 1;
#endif
#if !defined(vpiArithLShiftOp) || (vpiArithLShiftOp) != (41)
      vpi_printf("MISSING vpiArithLShiftOp\n");
      bad += 1;
#endif
#if !defined(vpiArithRShiftOp) || (vpiArithRShiftOp) != (42)
      vpi_printf("MISSING vpiArithRShiftOp\n");
      bad += 1;
#endif
#if !defined(vpiPowerOp) || (vpiPowerOp) != (43)
      vpi_printf("MISSING vpiPowerOp\n");
      bad += 1;
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
