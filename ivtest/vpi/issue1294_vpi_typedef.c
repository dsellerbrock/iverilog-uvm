#include <string.h>
#include <sv_vpi_user.h>

static PLI_INT32 probe(p_cb_data cb)
{
      vpiHandle modules, top, iter, type;
      int ordinary = 0, vif = 0, vif_mp = 0, count = 0, ok = 1;
      (void)cb;

      modules = vpi_iterate(vpiModule, NULL);
      top = modules ? vpi_scan(modules) : NULL;
      iter = top ? vpi_iterate(vpiTypedef, top) : NULL;
      while (iter && (type = vpi_scan(iter))) {
            const char* name = vpi_get_str(vpiName, type);
            ++count;
            if (name && strcmp(name, "ordinary_t") == 0) {
                  ordinary = vpi_get(vpiType, type) == vpiIntTypespec;
            } else if (name && strcmp(name, "vif_t") == 0) {
                  const char* defname = vpi_get_str(vpiDefName, type);
                  vif = vpi_get(vpiType, type) == vpiInterfaceTypespec
                        && defname && strcmp(defname, "bus") == 0
                        && !vpi_get(vpiIsModPort, type);
            } else if (name && strcmp(name, "vif_mp_t") == 0) {
                  const char* defname = vpi_get_str(vpiDefName, type);
                  vpiHandle parent = vpi_handle(vpiParent, type);
                  const char* modport = parent
                        ? vpi_get_str(vpiDefName, parent) : NULL;
                  vif_mp = vpi_get(vpiType, type) == vpiInterfaceTypespec
                        && defname && strcmp(defname, "mp") == 0
                        && vpi_get(vpiIsModPort, type)
                        && parent && modport && strcmp(modport, "bus") == 0;
            }
      }

      if (!top || !iter || count != 3 || !ordinary || !vif || !vif_mp)
            ok = 0;
      if (ok)
            vpi_printf("PASSED\n");
      else
            vpi_printf("FAILED typedefs count=%d ordinary=%d vif=%d vif_mp=%d\n",
                       count, ordinary, vif, vif_mp);
      return 0;
}

static void startup(void)
{
      s_cb_data cb = {0};
      cb.reason = cbStartOfSimulation;
      cb.cb_rtn = probe;
      vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = { startup, 0 };
