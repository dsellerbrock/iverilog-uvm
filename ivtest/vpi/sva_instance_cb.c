/* IEEE 1800-2023 39.4.2: property and sequence instance handles. Iterate
 * vpiPropertyInst and vpiSequenceInst from NULL and from each assertion,
 * register cbAssertionStart/Success/Failure on every instance, and log each
 * callback with the handle it reports. */
#include <stdio.h>
#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

static PLI_INT32 cb(PLI_INT32 reason, p_vpi_time t, vpiHandle h,
		    p_vpi_attempt_info info, PLI_BYTE8 *ud)
{
      (void)info; (void)ud;
      vpi_printf("  %s %s at %d\n",
		 reason == cbAssertionStart ? "start"
		 : reason == cbAssertionSuccess ? "success" : "failure",
		 vpi_get_str(vpiFullName, h), (int)t->low);
      return 0;
}

static void list(int type, const char *tname, vpiHandle ref, int reg)
{
      vpiHandle it = vpi_iterate(type, ref), h;
      int n = 0;
      char rname[256], full[256];
      /* vpi_get_str() reuses one result buffer: copy each string. */
      snprintf(rname, sizeof rname, "%s",
	       ref ? vpi_get_str(vpiFullName, ref) : "NULL");
      while (it && (h = vpi_scan(it))) {
	    n += 1;
	    snprintf(full, sizeof full, "%s", vpi_get_str(vpiFullName, h));
	    vpi_printf("%s from %s: %s (%s), type %d\n", tname, rname, full,
		       vpi_get_str(vpiName, h), (int)vpi_get(vpiType, h));
	    if (reg) {
		  vpi_register_assertion_cb(h, cbAssertionStart, cb, 0);
		  vpi_register_assertion_cb(h, cbAssertionSuccess, cb, 0);
		  vpi_register_assertion_cb(h, cbAssertionFailure, cb, 0);
		  vpi_printf("  step callback on it: %s\n",
			     vpi_register_assertion_cb(h, cbAssertionStepSuccess,
						       cb, 0) ? "accepted"
							      : "refused");
	    }
      }
      vpi_printf("%s from %s: %d\n", tname, rname, n);
}

static PLI_INT32 probe(PLI_BYTE8 *ud)
{
      vpiHandle it = vpi_iterate(vpiAssertion, 0), a;
      (void)ud;
      list(vpiPropertyInst, "PropertyInst", 0, 1);
      list(vpiSequenceInst, "SequenceInst", 0, 1);
      while (it && (a = vpi_scan(it))) {
	    list(vpiPropertyInst, "PropertyInst", a, 0);
	    list(vpiSequenceInst, "SequenceInst", a, 0);
      }
      return 0;
}

static void startup(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = (PLI_BYTE8 *)"$sva_instance_probe";
      tf.calltf = probe;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { startup, 0 };
