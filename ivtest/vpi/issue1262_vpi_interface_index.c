#include <sv_vpi_user.h>
#include <string.h>

static PLI_INT32 probe_interface_index(PLI_BYTE8 *user_data)
{
      vpiHandle top = vpi_handle_by_name("top", NULL);
      vpiHandle interfaces = top ? vpi_iterate(vpiInterface, top) : NULL;
      vpiHandle interface;
      unsigned seen = 0;
      unsigned indices = 0;
      unsigned scalar_seen = 0;
      int failed = top == NULL || interfaces == NULL;

      (void) user_data;
      while (interfaces && (interface = vpi_scan(interfaces))) {
	    const char *name = vpi_get_str(vpiFullName, interface);
	    vpiHandle index = vpi_handle(vpiIndex, interface);
	    if (name && (strcmp(name, "top.arr[0]") == 0
			 || strcmp(name, "top.arr[1]") == 0)) {
		  s_vpi_value value;
		  int expected = name[8] - '0';
		  value.format = vpiIntVal;
		  if (!index) {
			failed = 1;
		  } else {
			vpi_get_value(index, &value);
			if (value.value.integer != expected
			    || vpi_get(vpiIndex, interface) != expected)
			      failed = 1;
		  }
		  indices |= 1u << expected;
	    } else if (name) {
		  scalar_seen += 1;
		  if (index || vpi_get(vpiIndex, interface) != vpiUndefined)
			failed = 1;
	    } else {
		  failed = 1;
	    }
	    seen += 1;
      }

      if (seen != 4 || indices != 3 || scalar_seen != 2)
	    failed = 1;
      if (failed)
	    vpi_printf("FAIL: interface index transition or value is incorrect\n");
      else
	    vpi_printf("PASSED\n");
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data task = { vpiSysTask, 0, "$probe_interface_index",
				 probe_interface_index, 0, 0, 0 };
      vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
