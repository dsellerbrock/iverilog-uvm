#include <string.h>
#include <vpi_user.h>

static int check_property(vpiHandle module, const char *path, PLI_INT32 code,
                          const char *property, const char *expected)
{
      const char *actual = vpi_get_str(code, module);
      if (expected ? actual && !strcmp(actual, expected) : !actual)
            return 0;
      vpi_printf("FAIL: %s %s = %s (expected %s)\n", path, property,
                 actual ? actual : "<null>", expected ? expected : "<null>");
      return 1;
}

static int check_binding(const char *path, const char *library,
                         const char *cell, const char *config)
{
      vpiHandle module = vpi_handle_by_name((PLI_BYTE8 *)path, NULL);
      if (!module || vpi_get(vpiType, module) != vpiModule) {
            vpi_printf("FAIL: missing module %s\n", path);
            return 1;
      }
      int failures = check_property(module, path, vpiLibrary, "vpiLibrary", library);
      failures += check_property(module, path, vpiCell, "vpiCell", cell);
      failures += check_property(module, path, vpiConfig, "vpiConfig", config);
      return failures;
}

static PLI_INT32 inspect(PLI_BYTE8 *user)
{
      (void)user;
      int failures = check_binding("plain_top", "work", "plain_top", NULL);
      failures += check_binding("plain_top.u", "gateLib", "gate_leaf", NULL);
      failures += check_binding("cfg_top", "work", "cfg_top", "work.outer_cfg");
      failures += check_binding("cfg_top.u", "gateLib", "bound_leaf", "work.outer_cfg");
      failures += check_binding("cfg_top.branch", "gateLib", "branch_body", "gateLib.inner_cfg");
      failures += check_binding("cfg_top.branch.u", "gateLib", "bound_leaf", "gateLib.inner_cfg");
      if (!failures) vpi_printf("PASSED\n");
      return 0;
}

static void register_inspect(void)
{
      s_vpi_systf_data data = {0};
      data.type = vpiSysTask;
      data.tfname = "$inspect_library_binding";
      data.calltf = inspect;
      vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = {register_inspect, NULL};
