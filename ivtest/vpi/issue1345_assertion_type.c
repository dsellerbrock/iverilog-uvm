#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

static PLI_INT32 check_assertion_types(PLI_BYTE8* user_data)
{
      vpiHandle iterator = vpi_iterate(vpiAssertion, 0), assertion;
      int saw_assert = 0, saw_assume = 0, saw_cover = 0;
      int bad = 0, passed;
      (void)user_data;
      while (iterator && (assertion = vpi_scan(iterator))) {
	    const char* name = vpi_get_str(vpiName, assertion);
	    int type = vpi_get(vpiType, assertion);
	    if (name && strcmp(name, "ap1") == 0) {
		  saw_assert += 1;
		  if (type != vpiAssert) bad += 1;
	    } else if (name && strcmp(name, "as1") == 0) {
		  saw_assume += 1;
		  if (type != vpiAssume) bad += 1;
	    } else if (name && strcmp(name, "cp1") == 0) {
		  saw_cover += 1;
		  if (type != vpiCover) bad += 1;
	    } else {
		  bad += 1;
	    }
      }
      if (saw_assert == 1 && saw_assume == 1 && saw_cover == 1 && bad == 0)
	    vpi_printf("PASS: issue1345 assertion types assert=%d assume=%d cover=%d\n",
		       vpiAssert, vpiAssume, vpiCover);
      else
	    vpi_printf("FAIL: issue1345 assertion types assert=%d assume=%d cover=%d bad=%d\n",
		       saw_assert, saw_assume, saw_cover, bad);
	  passed = saw_assert == 1 && saw_assume == 1
		&& saw_cover == 1 && bad == 0;
	  if (passed)
	    vpi_printf("PASSED\n");
      return 0;
}

static void register_check(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$check_assertion_types";
      tf.calltf = check_assertion_types;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_check, 0 };
