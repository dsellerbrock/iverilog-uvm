#include <stdio.h>
#include <string.h>
#include <vpi_user.h>

static PLI_INT32 check_source_calltf(PLI_BYTE8*user_data)
{
      (void)user_data;
      vpiHandle call = vpi_handle(vpiSysTfCall, 0);
      vpiHandle args = vpi_iterate(vpiArgument, call);
      vpiHandle object = vpi_scan(args);
      vpiHandle expected_file_arg = vpi_scan(args);
      vpiHandle expected_line_arg = vpi_scan(args);
      s_vpi_value value;
      value.format = vpiStringVal;
      vpi_get_value(expected_file_arg, &value);
      const char*expected_file = value.value.str;
      value.format = vpiIntVal;
      vpi_get_value(expected_line_arg, &value);
      int expected_line = value.value.integer;

      int line = vpi_get(vpiLineNo, object);
      const char*file = vpi_get_str(vpiFile, object);
      if (!file || strcmp(file, expected_file) || line != expected_line) {
            vpi_printf("FAIL VPI source location: expected %s:%d, got %s:%d\n",
                       expected_file, expected_line, file ? file : "<null>",
                       line);
            vpi_control(vpiFinish, 1);
      }
      vpi_free_object(args);
      return 0;
}

static void register_check_source(void)
{
      s_vpi_systf_data tf;
      tf.type = vpiSysTask;
      tf.sysfunctype = 0;
      tf.tfname = "$vpi_check_source";
      tf.calltf = check_source_calltf;
      tf.compiletf = 0;
      tf.sizetf = 0;
      tf.user_data = 0;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {register_check_source, 0};
