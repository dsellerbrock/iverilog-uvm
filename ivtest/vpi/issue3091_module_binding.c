#include <string.h>
#include <vpi_user.h>

static int check(const char *path, const char *cell)
{
      vpiHandle module = vpi_handle_by_name((PLI_BYTE8 *)path, 0);
      const char *value;
      if (!module || vpi_get(vpiType, module) != vpiModule) return 1;
      value = vpi_get_str(vpiLibrary, module);
      if (!value || strcmp(value, "work")) return 1;
      value = vpi_get_str(vpiCell, module);
      if (!value || strcmp(value, cell)) return 1;
      return 0;
}

static PLI_INT32 inspect(PLI_BYTE8 *user)
{
      (void)user;
      if (check("top", "top") || check("top.u", "leaf"))
            vpi_printf("FAIL: module binding properties\n");
      else
            vpi_printf("PASSED\n");
      return 0;
}

static void register_inspect(void)
{
      s_vpi_systf_data data = {0};
      data.type = vpiSysTask;
      data.tfname = "$inspect_binding";
      data.calltf = inspect;
      vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = {register_inspect, 0};
