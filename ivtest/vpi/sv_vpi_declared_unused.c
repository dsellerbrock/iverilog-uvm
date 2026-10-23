#include <vpi_user.h>
#include <string.h>

static int check_declared_variables(char *user_data)
{
      vpiHandle scope = vpi_handle_by_name("sv_vpi_declared_unused", 0);
      vpiHandle iter = vpi_iterate(vpiReg, scope);
      vpiHandle obj;
      int seen_logic = 0;
      int seen_reg = 0;
      int seen_live = 0;
      int count = 0;
      vpiHandle unused_logic = vpi_handle_by_name(
            "sv_vpi_declared_unused.unused_logic", 0);
      vpiHandle unused_reg = vpi_handle_by_name(
            "sv_vpi_declared_unused.unused_reg", 0);

      (void) user_data;
      while (iter && (obj = vpi_scan(iter)) != 0) {
            const char *name = vpi_get_str(vpiName, obj);
            int size = vpi_get(vpiSize, obj);
            if (name && !strcmp(name, "unused_logic") && size == 8)
                  seen_logic = 1;
            if (name && !strcmp(name, "unused_reg") && size == 8)
                  seen_reg = 1;
            if (name && !strcmp(name, "live") && size == 4)
                  seen_live = 1;
            count++;
      }

      if (unused_logic && unused_reg && seen_logic && seen_reg && seen_live
          && count == 3) {
            vpi_printf("PASSED\n");
      } else {
            vpi_printf("FAIL: VPI iteration found %d variables; logic=%d reg=%d live=%d by_name=%d/%d\n",
                       count, seen_logic, seen_reg, seen_live,
                       unused_logic != 0, unused_reg != 0);
      }
      return 0;
}

static void register_check(void)
{
      s_vpi_systf_data tf_data;
      tf_data.type = vpiSysTask;
      tf_data.calltf = check_declared_variables;
      tf_data.compiletf = 0;
      tf_data.sizetf = 0;
      tf_data.tfname = "$check_declared_variables";
      tf_data.user_data = 0;
      vpi_register_systf(&tf_data);
}

void (*vlog_startup_routines[])(void) = { register_check, 0 };
