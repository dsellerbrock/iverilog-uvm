
#include <cstdarg>
#include <string>
#include "vpi_user.h"
#include "vpi_priv.h"
#include "vvp_vpi_callback.h"

static PLI_INT32 ivl_tchk_violation_calltf(const PLI_BYTE8*)
{
      vpiHandle call = vpi_handle(vpiSysTfCall, 0);
      vpiHandle scope = vpi_handle(vpiScope, call);
      const char*file_str = vpi_get_str(vpiFile, call);
      std::string file = file_str ? file_str : "";
      long lineno = vpi_get(vpiLineNo, call);
      vpiHandle args = vpi_iterate(vpiArgument, call);
      vpiHandle type_arg = args ? vpi_scan(args) : 0;
      s_vpi_value value;
      value.format = vpiIntVal;
      value.value.integer = vpiUndefined;
      if (type_arg) vpi_get_value(type_arg, &value);
      if (args) vpi_free_object(args);
      if (scope && !file.empty() && type_arg)
	    vpip_tchk_violation(scope, file.c_str(), lineno,
				 value.value.integer);
      return 0;
}


void vvp_vpi_init()
{
      s_vpi_systf_data task;
      task.type = vpiSysTask;
      task.sysfunctype = 0;
      task.tfname = const_cast<PLI_BYTE8*>("$ivl_tchk_violation");
      task.calltf = ivl_tchk_violation_calltf;
      task.compiletf = 0;
      task.sizetf = 0;
      task.user_data = 0;
      vpiHandle handle = vpi_register_systf(&task);
      vpip_make_systf_system_defined(handle);
}

