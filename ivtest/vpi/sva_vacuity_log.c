/* Log every success (P), vacuous success (V) and failure (F) of every
 * assertion with its time, grouped by assertion, so the order of same-time
 * callbacks across assertions does not matter. */
#include <stdio.h>
#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

#define CB_ASSERTION_VACUOUS_SUCCESS 657
#define MAX_A 8

static vpiHandle handles[MAX_A];
static char logs[MAX_A][1024];
static int count;

static PLI_INT32 cb(PLI_INT32 reason, p_vpi_time t, vpiHandle a,
		    p_vpi_attempt_info info, PLI_BYTE8 *ud)
{
      int i = (int)(long)ud;
      size_t n = strlen(logs[i]);
      (void)a; (void)info;
      snprintf(logs[i] + n, sizeof logs[i] - n, " %s%d",
	       reason == CB_ASSERTION_VACUOUS_SUCCESS ? "V"
	       : reason == cbAssertionFailure ? "F" : "P", (int)t->low);
      return 0;
}

static PLI_INT32 setup(PLI_BYTE8 *ud)
{
      vpiHandle it, a;
      (void)ud;
      it = vpi_iterate(vpiAssertion, 0);
      while (it && (a = vpi_scan(it)) && count < MAX_A) {
	    handles[count] = a;
	    vpi_register_assertion_cb(a, cbAssertionSuccess, cb,
				      (PLI_BYTE8 *)(long)count);
	    vpi_register_assertion_cb(a, CB_ASSERTION_VACUOUS_SUCCESS, cb,
				      (PLI_BYTE8 *)(long)count);
	    vpi_register_assertion_cb(a, cbAssertionFailure, cb,
				      (PLI_BYTE8 *)(long)count);
	    count += 1;
      }
      return 0;
}

static PLI_INT32 dump(PLI_BYTE8 *ud)
{
      (void)ud;
      for (int i = 0 ; i < count ; i += 1)
	    vpi_printf("%s:%s\n", vpi_get_str(vpiName, handles[i]), logs[i]);
      return 0;
}

static void register_tasks(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$vac_setup";
      tf.calltf = setup;
      vpi_register_systf(&tf);
      tf.tfname = "$vac_dump";
      tf.calltf = dump;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
