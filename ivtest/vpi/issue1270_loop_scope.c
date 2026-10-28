#include <stdio.h>
#include "vpi_user.h"

static PLI_INT32 probe(PLI_BYTE8 *user_data)
{
      (void)user_data;
      vpiHandle top = vpi_handle_by_name("top", NULL);
      vpiHandle scopes = vpi_iterate(vpiInternalScope, top);
      vpiHandle scope;
      int for_seen = 0;
      int foreach_seen = 0;

      while (scopes && (scope = vpi_scan(scopes))) {
            vpiHandle variables = vpi_iterate(vpiVariables, scope);
            vpiHandle variable;
            while (variables && (variable = vpi_scan(variables))) {
                  vpiHandle owner = vpi_handle(vpiScope, variable);
                  int scope_type = owner ? (int)vpi_get(vpiType, owner) : -1;
                  int variable_type = (int)vpi_get(vpiType, variable);
                  if (scope_type == vpiFor && variable_type == vpiIntVar
                      && vpi_get(vpiLocalVarDecls, owner))
                        for_seen = 1;
                  if (scope_type == vpiForeachStmt && variable_type == vpiIntVar)
                        foreach_seen = 1;
            }
      }

      if (for_seen && foreach_seen)
	    vpi_printf("PASSED\nPASSED for and foreach variable scopes\n");
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data task = {0};
      task.type = vpiSysTask;
      task.tfname = "$probe";
      task.calltf = probe;
      vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
