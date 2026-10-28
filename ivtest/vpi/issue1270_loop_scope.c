#include <stdio.h>
#include <string.h>
#include "vpi_user.h"

static PLI_INT32 probe(PLI_BYTE8 *user_data)
{
      vpiHandle top = vpi_handle_by_name((PLI_BYTE8*)"top", 0);
      vpiHandle scopes = top ? vpi_iterate(vpiInternalScope, top) : 0;
      vpiHandle scope;
      int for_ok = 0;
      int foreach_ok = 0;

      (void)user_data;
      while (scopes && (scope = vpi_scan(scopes))) {
	    int type = vpi_get(vpiType, scope);
	    vpiHandle vars = vpi_iterate(vpiVariables, scope);
	    vpiHandle var;
	    while (vars && (var = vpi_scan(vars))) {
		  const char *name = vpi_get_str(vpiName, var);
		  vpiHandle target = vpi_handle(vpiScope, var);
		  if (!name || strcmp(name, "i") != 0 || target != scope)
			continue;
		  if (type == vpiFor
		      && vpi_get(vpiLocalVarDecls, scope) == 1)
			for_ok = 1;
		  if (type == vpiForeachStmt)
			foreach_ok = 1;
	    }
      }

      if (for_ok)
	    vpi_printf("PASS for loop variable scope type %d\n", vpiFor);
      if (foreach_ok)
	    vpi_printf("PASS foreach loop variable scope type %d\n", vpiForeachStmt);
      if (!for_ok || !foreach_ok)
	    vpi_printf("FAIL loop scope for=%d foreach=%d\n", for_ok, foreach_ok);
	  else
	    vpi_printf("PASSED\n");
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$probe";
      tf.calltf = probe;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
