#include <string.h>
#include <vpi_user.h>

static PLI_INT32 probe(p_cb_data cb)
{
      vpiHandle modules, top, iter, decl, alias, resolver;
      int count = 0;
      int ok = 1;
      (void)cb;

      modules = vpi_iterate(vpiModule, NULL);
      top = modules ? vpi_scan(modules) : NULL;
      iter = top ? vpi_iterate(vpiNettypeDecl, top) : NULL;
      while (iter && (decl = vpi_scan(iter))) {
            const char* name = vpi_get_str(vpiName, decl);
            if (name && strcmp(name, "alias_nt") == 0) {
                  alias = vpi_handle(vpiNetTypedefAlias, decl);
                  if (!alias || strcmp(vpi_get_str(vpiName, alias), "base_nt") != 0)
                        ok = 0;
            } else if (name && strcmp(name, "resolved_nt") == 0) {
                  resolver = vpi_handle(vpiWith, decl);
                  if (!resolver || vpi_get(vpiType, resolver) != vpiFunction)
                        ok = 0;
            }
            ++count;
      }

      if (!top || !iter || count != 3)
            ok = 0;
      if (ok)
            vpi_printf("PASSED\n");
      else
            vpi_printf("FAILED declarations count=%d\n", count);
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
