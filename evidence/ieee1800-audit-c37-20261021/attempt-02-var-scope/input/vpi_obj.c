#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

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
            vpi_printf("variable=%s type=%d size=%d\n",
                       vpi_get_str(vpiName, item),
                       vpi_get(vpiType, item), vpi_get(vpiSize, item));
            count += 1;
      }
      vpi_printf("variables_count=%d\n", count);

      iter = vpi_iterate(vpiReg, top);
      count = 0;
      while (iter && (item = vpi_scan(iter))) {
            vpi_printf("reg=%s size=%d\n", vpi_get_str(vpiName, item),
                       vpi_get(vpiSize, item));
            count += 1;
      }
      vpi_printf("regs_count=%d\n", count);

      iter = vpi_iterate(vpiModule, top);
      count = 0;
      while (iter && (item = vpi_scan(iter))) {
            if (strcmp(vpi_get_str(vpiName, item), "u") == 0) {
                  vpiHandle scope = vpi_handle(vpiScope, item);
                  vpiHandle module = vpi_handle(vpiModule, item);
                  vpiHandle instance = vpi_handle(vpiInstance, item);
                  vpi_printf("child=");
                  vpi_printf("%s", vpi_get_str(vpiFullName, item));
                  vpi_printf(" def=");
                  vpi_printf("%s", vpi_get_str(vpiDefName, item));
                  vpi_printf(" instance=");
                  if (instance)
                        vpi_printf("%s", vpi_get_str(vpiFullName, instance));
                  else
                        vpi_printf("<null>");
                  vpi_printf(" scope=");
                  if (scope)
                        vpi_printf("%s", vpi_get_str(vpiFullName, scope));
                  else
                        vpi_printf("<null>");
                  vpi_printf(" module=");
                  if (module)
                        vpi_printf("%s", vpi_get_str(vpiFullName, module));
                  else
                        vpi_printf("<null>");
                  vpi_printf("\n");
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
