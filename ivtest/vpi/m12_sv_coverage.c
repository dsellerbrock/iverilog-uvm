#include <vpi_user.h>
#include <sv_vpi_user.h>
#include <string.h>

static PLI_INT32 probe_calltf(PLI_BYTE8*ud)
{
      s_vpi_value val;
      vpiHandle it, c;
      (void)ud;
      it = vpi_iterate(vpiCovergroup, 0);
      if (!it) { vpi_printf("no covergroups\n"); return 0; }
      while ((c = vpi_scan(it))) {
	    val.format = vpiRealVal;
	    vpi_get_value(c, &val);
	    vpi_printf("covergroup %s coverage=%.2f bins=%d\n",
		       vpi_get_str(vpiName, c), val.value.real,
		       vpi_get(vpiSize, c));
      }
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$m12_cov";
      tf.calltf = probe_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
