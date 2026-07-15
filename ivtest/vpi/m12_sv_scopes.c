#include <vpi_user.h>
#include <sv_vpi_user.h>
#include <string.h>

static PLI_INT32 probe_calltf(PLI_BYTE8*ud)
{
      s_vpi_value val;
      vpiHandle h, it, c;
      (void)ud;

      /* interface instance scope type */
      h = vpi_handle_by_name((char*)"top.bus0", 0);
      if (h) vpi_printf("bus0: type=%d name=%s\n", vpi_get(vpiType, h),
			vpi_get_str(vpiName, h));
      else vpi_printf("bus0 NOT FOUND\n");

      /* modports inside the interface */
      if (h) {
	    it = vpi_iterate(vpiModport, h);
	    if (it) while ((c = vpi_scan(it)))
		  vpi_printf("modport: %s (type=%d)\n",
			     vpi_get_str(vpiName, c), vpi_get(vpiType, c));
	    else vpi_printf("no modport iterator\n");
      }

      /* interface signal through hierarchy */
      h = vpi_handle_by_name((char*)"top.bus0.data", 0);
      if (h) {
	    val.format = vpiIntVal;
	    vpi_get_value(h, &val);
	    vpi_printf("bus0.data=%d\n", (int)val.value.integer);
      } else vpi_printf("bus0.data NOT FOUND\n");

      /* package-qualified lookup */
      h = vpi_handle_by_name((char*)"p1::pv", 0);
      if (h) {
	    val.format = vpiIntVal;
	    vpi_get_value(h, &val);
	    vpi_printf("p1::pv=%d type=%d\n", (int)val.value.integer,
		       vpi_get(vpiType, h));
      } else vpi_printf("p1::pv NOT FOUND\n");

      /* package iteration from root */
      it = vpi_iterate(vpiPackage, 0);
      if (it) while ((c = vpi_scan(it)))
	    vpi_printf("package: %s\n", vpi_get_str(vpiName, c));

      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$m12_scopes";
      tf.calltf = probe_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
