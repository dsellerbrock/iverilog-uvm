#include <string.h>
#include <vpi_user.h>

static PLI_INT32 probe_imports(PLI_BYTE8 *user_data)
{
      vpiHandle top = vpi_handle_by_name((PLI_BYTE8*)"top", 0);
      vpiHandle iterator = top ? vpi_iterate(vpiImport, top) : 0;
      vpiHandle item;
      unsigned count = 0;
      int failed = top == 0;
      (void)user_data;

      while (iterator && (item = vpi_scan(iterator))) {
	    s_vpi_value value;
	    const char*name = vpi_get_str(vpiName, item);
	    value.format = vpiIntVal;
	    vpi_get_value(item, &value);
	    vpi_printf("IMPORT %s VALUE=%d\n", name ? name : "<null>",
		       value.value.integer);
	    if (!name || strcmp(name, "used") != 0 || value.value.integer != 17)
		  failed = 1;
	    count += 1;
      }

      vpi_printf("IMPORT_COUNT=%u\n", count);
      if (count != 1) failed = 1;
      vpi_printf("%s\n", failed ? "IMPORT_TEST_FAILED" : "PASSED");
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data task;
      memset(&task, 0, sizeof task);
      task.type = vpiSysTask;
      task.tfname = "$probe_imports";
      task.calltf = probe_imports;
      vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
