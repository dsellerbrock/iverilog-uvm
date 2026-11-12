#include <string.h>
#include "vpi_user.h"
#include "sv_vpi_user.h"

static int bad;

static void report(const char *name)
{
      vpi_printf("MISSING %s\n", name);
      bad++;
}

#define CHECK_NAME(name, value) \
      static void check_##name(void) \
      { \
            if (!(name##_defined)) report(#name); \
      }

/* Each conditional turns a missing or incorrectly valued name into a
   run-time failure so this test also runs against the unfixed header. */
#if !defined(vpiIsMemory) || vpiIsMemory != 73
#define vpiIsMemory_defined 0
#else
#define vpiIsMemory_defined 1
#endif
CHECK_NAME(vpiIsMemory, 73)
#if !defined(vpiIsProtected) || vpiIsProtected != 74
#define vpiIsProtected_defined 0
#else
#define vpiIsProtected_defined 1
#endif
CHECK_NAME(vpiIsProtected, 74)
#if !defined(vpiShortIntVal) || vpiShortIntVal != 14
#define vpiShortIntVal_defined 0
#else
#define vpiShortIntVal_defined 1
#endif
CHECK_NAME(vpiShortIntVal, 14)
#if !defined(vpiLongIntVal) || vpiLongIntVal != 15
#define vpiLongIntVal_defined 0
#else
#define vpiLongIntVal_defined 1
#endif
CHECK_NAME(vpiLongIntVal, 15)
#if !defined(vpiShortRealVal) || vpiShortRealVal != 16
#define vpiShortRealVal_defined 0
#else
#define vpiShortRealVal_defined 1
#endif
CHECK_NAME(vpiShortRealVal, 16)
#if !defined(vpiRawTwoStateVal) || vpiRawTwoStateVal != 17
#define vpiRawTwoStateVal_defined 0
#else
#define vpiRawTwoStateVal_defined 1
#endif
CHECK_NAME(vpiRawTwoStateVal, 17)
#if !defined(vpiRawFourStateVal) || vpiRawFourStateVal != 18
#define vpiRawFourStateVal_defined 0
#else
#define vpiRawFourStateVal_defined 1
#endif
CHECK_NAME(vpiRawFourStateVal, 18)
#if !defined(vpiCancelEvent) || vpiCancelEvent != 7
#define vpiCancelEvent_defined 0
#else
#define vpiCancelEvent_defined 1
#endif
CHECK_NAME(vpiCancelEvent, 7)
#if !defined(vpiUserAllocFlag) || vpiUserAllocFlag != 8192
#define vpiUserAllocFlag_defined 0
#else
#define vpiUserAllocFlag_defined 1
#endif
CHECK_NAME(vpiUserAllocFlag, 8192)
#if !defined(vpiOneValue) || vpiOneValue != 16384
#define vpiOneValue_defined 0
#else
#define vpiOneValue_defined 1
#endif
CHECK_NAME(vpiOneValue, 16384)
#if !defined(vpiPropagateOff) || vpiPropagateOff != 32768
#define vpiPropagateOff_defined 0
#else
#define vpiPropagateOff_defined 1
#endif
CHECK_NAME(vpiPropagateOff, 32768)
#if !defined(cbAssign) || cbAssign != 25
#define cbAssign_defined 0
#else
#define cbAssign_defined 1
#endif
CHECK_NAME(cbAssign, 25)
#if !defined(cbDeassign) || cbDeassign != 26
#define cbDeassign_defined 0
#else
#define cbDeassign_defined 1
#endif
CHECK_NAME(cbDeassign, 26)
#if !defined(cbDisable) || cbDisable != 27
#define cbDisable_defined 0
#else
#define cbDisable_defined 1
#endif
CHECK_NAME(cbDisable, 27)
#if !defined(cbSignal) || cbSignal != 29
#define cbSignal_defined 0
#else
#define cbSignal_defined 1
#endif
CHECK_NAME(cbSignal, 29)

static PLI_INT32 probe(PLI_BYTE8 *ud)
{
      (void)ud;
      check_vpiIsMemory();
      check_vpiIsProtected();
      check_vpiShortIntVal();
      check_vpiLongIntVal();
      check_vpiShortRealVal();
      check_vpiRawTwoStateVal();
      check_vpiRawFourStateVal();
      check_vpiCancelEvent();
      check_vpiUserAllocFlag();
      check_vpiOneValue();
      check_vpiPropagateOff();
      check_cbAssign();
      check_cbDeassign();
      check_cbDisable();
      check_cbSignal();
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
