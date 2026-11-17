#include <string.h>
#include "vpi_user.h"
#include "sv_vpi_user.h"

static unsigned failures;

static void check(const char *signal, const char *const *names, unsigned count)
{
      vpiHandle var = vpi_handle_by_name((PLI_BYTE8 *)signal, 0);
      vpiHandle spec = var ? vpi_handle(vpiTypespec, var) : 0;
      unsigned i;
      for (i = 0; i < count; ++i) {
            const char *name = spec ? vpi_get_str(vpiName, spec) : 0;
            if (!spec || vpi_get(vpiType, spec) != vpiTimeTypespec ||
                (names[i] ? !name || strcmp(name, names[i]) : name != 0)) {
                  vpi_printf("FAIL %s typespec at level %u\n", signal, i);
                  ++failures;
                  return;
            }
            spec = vpi_handle(vpiTypedefAlias, spec);
      }
      if (spec) {
            vpi_printf("FAIL %s unexpected alias\n", signal);
            ++failures;
      }
}

static PLI_INT32 calltf(PLI_BYTE8 *unused)
{
      static const char *const plain[] = {0};
      static const char *const named[] = {"my_time", 0};
      static const char *const chained[] = {"other_time", "my_time", 0};
      (void)unused;
      check("top.plain", plain, 1);
      check("top.named_time", named, 2);
      check("top.chained_time", chained, 3);
      if (!failures) vpi_printf("TIME TYPESPEC PASS\nPASSED\n");
      return 0;
}

static void register_check(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$check_time_typespec";
      tf.calltf = calltf;
      vpi_register_systf(&tf);
}
void (*vlog_startup_routines[])(void) = {register_check, 0};
