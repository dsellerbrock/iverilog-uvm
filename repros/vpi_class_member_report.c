#include <vpi_user.h>
#include <sv_vpi_user.h>
#include <stdio.h>
#include <string.h>

static int probe_calltf(char*ud)
{
      vpiHandle sysh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argi = vpi_iterate(vpiArgument, sysh);
      vpiHandle obj  = vpi_scan(argi);         /* the class handle */
      s_vpi_value val;
      vpiHandle it, prop;
      (void)ud;
      if (!obj) { vpi_printf("PROBE: no arg\n"); return 0; }

      val.format = vpiObjTypeVal;
      it = vpi_iterate(vpiMember, obj);
      if (!it) { vpi_printf("PROBE: no vpiMember iterator on the object\n"); return 0; }
      while ((prop = vpi_scan(it))) {
            const char*nm = vpi_get_str(vpiName, prop);
            int ty = vpi_get(vpiType, prop);
            const char*tys = vpi_get_str(vpiType, prop);
            int sz = vpi_get(vpiSize, prop);
            vpi_printf("PROBE member %-6s type=%d(%s) size=%d\n",
                       nm ? nm : "?", ty, tys ? tys : "?", sz);
      }
      return 0;
}

static void probe_register(void)
{
      s_vpi_systf_data d;
      memset(&d, 0, sizeof d);
      d.type      = vpiSysTask;
      d.tfname    = "$probe_members";
      d.calltf    = probe_calltf;
      d.compiletf = 0;
      vpi_register_systf(&d);
}

void (*vlog_startup_routines[])(void) = { probe_register, 0 };
