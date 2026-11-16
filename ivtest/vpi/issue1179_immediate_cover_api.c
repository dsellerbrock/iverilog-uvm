#include <vpi_user.h>
#include <sv_vpi_user.h>
#include <string.h>

#define IEEE_vpiAssertAttemptCovered 770
#define IEEE_vpiAssertSuccessCovered 771

static int covers;

static PLI_INT32 check_call(PLI_BYTE8 *user_data)
{
      vpiHandle call = vpi_handle(vpiSysTfCall, 0);
      vpiHandle it = vpi_iterate(vpiAssertion, 0), assertion;
      s_vpi_value value;
      int attempts = 0, successes = 0, seen = 0, bad = 0;
      (void)user_data;
      covers = 0;
      while (it && (assertion = vpi_scan(it))) {
            const char *name;
            int attempt, success, index;
            if (vpi_get(vpiType, assertion) != vpiImmediateCover) continue;
            covers++;
            name = vpi_get_str(vpiName, assertion);
            if (name && !strcmp(name, "true_cover_one")) index = 0;
            else if (name && !strcmp(name, "true_cover_two")) index = 1;
            else if (name && !strcmp(name, "false_cover")) index = 2;
            else { bad = 1; continue; }
            if (seen & (1 << index)) bad = 1;
            seen |= 1 << index;
            attempt = vpi_get(IEEE_vpiAssertAttemptCovered, assertion);
            success = vpi_get(IEEE_vpiAssertSuccessCovered, assertion);
            attempts += attempt;
            successes += success;
            if (attempt != 1 || success != (index != 2)) bad = 1;
      }
      vpi_printf("COVER_API covers=%d attempts=%d successes=%d\n",
                 covers, attempts, successes);
      value.format = vpiIntVal;
      value.value.integer = covers == 3 && attempts == 3 && successes == 2
                            && seen == 7 && !bad;
      vpi_put_value(call, &value, 0, vpiNoDelay);
      return 0;
}

static void register_tasks(void)
{
      s_vpi_systf_data tf = {0};
      tf.type = vpiSysFunc;
      tf.sysfunctype = vpiIntFunc;
      tf.tfname = "$immediate_cover_api_check";
      tf.calltf = check_call;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
