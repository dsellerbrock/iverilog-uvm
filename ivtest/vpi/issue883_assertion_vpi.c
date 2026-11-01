#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

static PLI_INT32 check_assertion_vpi(PLI_BYTE8* user_data)
{
      vpiHandle iterator, assertion;
      int count = 0;
      int header_ok = (vpiAssertion == 744);
      (void)user_data;

#if !defined(vpiAssertionLock) || !defined(vpiAssertionUnlock) \
    || !defined(vpiAssertionDisable) || !defined(vpiAssertionEnable) \
    || !defined(vpiAssertionReset) || !defined(vpiAssertionKill) \
    || !defined(vpiAssertionEnableStep) || !defined(vpiAssertionDisableStep) \
    || !defined(vpiAssertionClockSteps) || !defined(vpiAssertionSysLock) \
    || !defined(vpiAssertionSysUnlock) || !defined(vpiAssertionSysOn) \
    || !defined(vpiAssertionSysOff) || !defined(vpiAssertionSysKill) \
    || !defined(vpiAssertionSysEnd) || !defined(vpiAssertionSysReset) \
    || !defined(vpiAssertionDisablePassAction) \
    || !defined(vpiAssertionEnablePassAction) \
    || !defined(vpiAssertionDisableFailAction) \
    || !defined(vpiAssertionEnableFailAction) \
    || !defined(vpiAssertionDisableVacuousAction) \
    || !defined(vpiAssertionEnableNonvacuousAction) \
    || !defined(vpiAssertionSysEnablePassAction) \
    || !defined(vpiAssertionSysEnableFailAction) \
    || !defined(vpiAssertionSysDisablePassAction) \
    || !defined(vpiAssertionSysDisableFailAction) \
    || !defined(vpiAssertionSysEnableNonvacuousAction) \
    || !defined(vpiAssertionSysDisableVacuousAction)
      header_ok = 0;
#else
      header_ok = header_ok
            && vpiAssertionLock == 645 && vpiAssertionUnlock == 646
            && vpiAssertionDisable == 620 && vpiAssertionEnable == 621
            && vpiAssertionReset == 622 && vpiAssertionKill == 623
            && vpiAssertionEnableStep == 624
            && vpiAssertionDisableStep == 625
            && vpiAssertionClockSteps == 626
            && vpiAssertionSysLock == 647 && vpiAssertionSysUnlock == 648
            && vpiAssertionSysOn == 627 && vpiAssertionSysOff == 628
            && vpiAssertionSysKill == 632 && vpiAssertionSysEnd == 629
            && vpiAssertionSysReset == 630
            && vpiAssertionDisablePassAction == 633
            && vpiAssertionEnablePassAction == 634
            && vpiAssertionDisableFailAction == 635
            && vpiAssertionEnableFailAction == 636
            && vpiAssertionDisableVacuousAction == 637
            && vpiAssertionEnableNonvacuousAction == 638
            && vpiAssertionSysEnablePassAction == 639
            && vpiAssertionSysEnableFailAction == 640
            && vpiAssertionSysDisablePassAction == 641
            && vpiAssertionSysDisableFailAction == 642
            && vpiAssertionSysEnableNonvacuousAction == 643
            && vpiAssertionSysDisableVacuousAction == 644;
#endif

      /* Use the IEEE value directly to check the runtime ABI independently
       * of the value provided by the header being tested. */
      iterator = vpi_iterate(744, NULL);
      while (iterator && (assertion = vpi_scan(iterator))) {
            const char *name = vpi_get_str(vpiName, assertion);
            if (name && strcmp(name, "ap") == 0)
                  count += 1;
      }

      if (header_ok && count == 1) {
            vpi_printf("PASS: issue883 assertion VPI constants and iterator\n");
            vpi_printf("PASSED\n");
      } else {
            vpi_printf("FAIL: issue883 vpiAssertion=%d disable=%d count=%d\n",
                       vpiAssertion,
#ifdef vpiAssertionDisable
                       vpiAssertionDisable,
#else
                       -1,
#endif
                       count);
      }
      return 0;
}

static void register_check(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$check_assertion_vpi";
      tf.calltf = check_assertion_vpi;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_check, 0 };
