/*
 * Check that enum records in the generated VVP file follow declaration order.
 */
#include <stdio.h>
#include <string.h>
#include "vpi_user.h"

#define ENUM_COUNT 200

static PLI_INT32 enum_order_ok(PLI_BYTE8 *ud)
{
      FILE *file;
      char line[512];
      int in_enum = 0;
      int expected = 0;
      int ok = 1;
      s_vpi_value value;
      (void)ud;

      file = fopen("work/a.out", "r");
      if (!file) {
	    vpi_printf("FAILED: cannot open generated VVP file\n");
	    ok = 0;
      } else {
	    while (fgets(line, sizeof line, file)) {
		  if (!in_enum && !strncmp(line, "enum", 4)
		      && strstr(line, ".enum")) {
			in_enum = 1;
			continue;
		  }
		  if (in_enum) {
			int index;
			if (strstr(line, "_X\"")
			    && sscanf(line, " \"A%d_X\"", &index) == 1) {
			      if (index != expected) ok = 0;
			      expected += 1;
			}
			if (line[0] == ' ' && line[1] == ';') in_enum = 0;
		  }
	    }
	    fclose(file);
	    if (expected != ENUM_COUNT) ok = 0;
	    if (!ok)
		  vpi_printf("FAILED: found %d ordered enum records, expected %d\n",
			     expected, ENUM_COUNT);
      }

      value.format = vpiIntVal;
      value.value.integer = ok;
      vpi_put_value(vpi_handle(vpiSysTfCall, 0), &value, 0, vpiNoDelay);
      return 0;
}

static void register_enum_order(void)
{
      s_vpi_systf_data task;
      memset(&task, 0, sizeof task);
      task.type = vpiSysFunc;
      task.sysfunctype = vpiIntFunc;
      task.tfname = (PLI_BYTE8*)"$enum_order_ok";
      task.calltf = enum_order_ok;
      vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = { register_enum_order, 0 };
