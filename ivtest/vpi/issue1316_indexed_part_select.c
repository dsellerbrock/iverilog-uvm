#include <stdio.h>
#include <string.h>
#include <vpi_user.h>

static int calls;
static int failed_any;

static PLI_INT32 selectprobe_calltf(PLI_BYTE8 *userdata)
{
      vpiHandle call = vpi_handle(vpiSysTfCall, 0);
      vpiHandle args = vpi_iterate(vpiArgument, call);
      vpiHandle select = vpi_scan(args);
      vpiHandle base = vpi_handle(vpiBaseExpr, select);
      vpiHandle width = vpi_handle(vpiWidthExpr, select);
      vpiHandle parent = vpi_handle(vpiParent, select);
      s_vpi_value value;
      int expected_type = calls == 1 ? vpiNegIndexed : vpiPosIndexed;
      int expected_base = calls++ == 1 ? 7 : 4;
      int failed = 0;

      if (vpi_get(vpiType, select) != vpiIndexedPartSelect
          || vpi_get(vpiIndexedPartSelectType, select) != expected_type
          || !base || !width || !parent
          || vpi_get_str(vpiName, parent) == NULL
          || strcmp(vpi_get_str(vpiName, parent), "data") != 0)
            failed = 1;

      value.format = vpiIntVal;
      if (base) {
            vpi_get_value(base, &value);
            if (value.value.integer != expected_base)
                  failed = 1;
      } else {
            failed = 1;
      }
      if (width) {
            vpi_get_value(width, &value);
            if (value.value.integer != 4)
                  failed = 1;
      } else {
            failed = 1;
      }
      vpi_get_value(select, &value);
      if (value.value.integer != 5)
            failed = 1;

      failed_any |= failed;
      if (calls == 3)
            printf("%s\n", failed_any ? "FAILED" : "PASSED");
      return 0;
}

static void register_selectprobe(void)
{
      s_vpi_systf_data tf;
      tf.type = vpiSysTask;
      tf.tfname = "$selectprobe";
      tf.calltf = selectprobe_calltf;
      tf.compiletf = NULL;
      tf.sizetf = NULL;
      tf.user_data = NULL;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_selectprobe, 0 };
