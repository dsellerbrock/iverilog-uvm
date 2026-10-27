#include <string.h>
#include <vpi_user.h>

static PLI_INT32 probe_calltf(PLI_BYTE8 *user_data)
{
      vpiHandle top = vpi_handle_by_name("p37", NULL);
      vpiHandle iter, item;
      int count = 0;

      (void)user_data;
      if (!top) {
            vpi_printf("top=null\n");
            return 0;
      }

      iter = vpi_iterate(vpiPort, top);
      while (iter && (item = vpi_scan(iter))) {
            vpi_printf("port=%s direction=%d size=%d\n",
                       vpi_get_str(vpiName, item),
                       vpi_get(vpiDirection, item), vpi_get(vpiSize, item));
            count += 1;
      }
      vpi_printf("port_count=%d\n", count);

      iter = vpi_iterate(vpiParameter, top);
      count = 0;
      while (iter && (item = vpi_scan(iter))) {
            if (strcmp(vpi_get_str(vpiName, item), "P") == 0) {
                  s_vpi_value value;
                  value.format = vpiIntVal;
                  vpi_get_value(item, &value);
                  vpi_printf("parameter=P value=%d\n", value.value.integer);
                  count += 1;
            }
      }
      vpi_printf("parameter_p_count=%d\n", count);

      iter = vpi_iterate(vpiVariables, top);
      count = 0;
      while (iter && (item = vpi_scan(iter))) {
            if (strcmp(vpi_get_str(vpiName, item), "v") == 0) {
                  vpi_printf("variable=v size=%d\n", vpi_get(vpiSize, item));
                  count += 1;
            }
      }
      vpi_printf("variable_v_count=%d\n", count);

      iter = vpi_iterate(vpiModule, top);
      count = 0;
      while (iter && (item = vpi_scan(iter))) {
            if (strcmp(vpi_get_str(vpiName, item), "u") == 0) {
                  vpiHandle scope = vpi_handle(vpiScope, item);
                  vpiHandle module = vpi_handle(vpiModule, item);
                  vpi_printf("child=u def=%s scope=%s module=%s\n",
                             vpi_get_str(vpiDefName, item),
                             scope ? vpi_get_str(vpiName, scope) : "<null>",
                             module ? vpi_get_str(vpiName, module) : "<null>");
                  count += 1;
            }
      }
      vpi_printf("child_u_count=%d\n", count);
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data tf = {0};
      tf.type = vpiSysTask;
      tf.tfname = "$probe37";
      tf.calltf = probe_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
