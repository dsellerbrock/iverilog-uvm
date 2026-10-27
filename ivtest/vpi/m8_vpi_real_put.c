#include <vpi_user.h>
#include <string.h>

static int failed;

static void check_real(vpiHandle target, const char* name, double expected)
{
      s_vpi_value value;

      if (target == 0) {
            vpi_printf("FAIL %s: no handle\n", name);
            failed = 1;
            return;
      }

      value.format = vpiRealVal;
      vpi_get_value(target, &value);
      if (value.value.real != expected) {
            vpi_printf("FAIL %s: got %.17g expected %.17g\n",
                       name, value.value.real, expected);
            failed = 1;
      }
}

static void put_value(vpiHandle target, PLI_INT32 format, PLI_INT32 value)
{
      s_vpi_value put;

      memset(&put, 0, sizeof put);
      put.format = format;
      put.value.scalar = value;
      vpi_put_value(target, &put, 0, vpiNoDelay);
}

static void put_vector(vpiHandle target, PLI_INT32 aval, PLI_INT32 bval)
{
      s_vpi_value put;
      s_vpi_vecval vector = { aval, bval };

      memset(&put, 0, sizeof put);
      put.format = vpiVectorVal;
      put.value.vector = &vector;
      vpi_put_value(target, &put, 0, vpiNoDelay);
}

static PLI_INT32 check_put_calltf(PLI_BYTE8* user_data)
{
      vpiHandle target = vpi_handle_by_name("test.target", 0);
      vpiHandle array = vpi_handle_by_name("test.mem", 0);
      vpiHandle element = array ? vpi_handle_by_index(array, 0) : 0;
      s_vpi_value put;

      (void)user_data;
      if (target == 0 || element == 0) {
            vpi_printf("FAIL: missing real or array handle\n");
            return 0;
      }

      memset(&put, 0, sizeof put);
      put.format = vpiIntVal;
      put.value.integer = 7;
      vpi_put_value(target, &put, 0, vpiNoDelay);
      check_real(target, "integer", 7.0);

      memset(&put, 0, sizeof put);
      put.format = vpiBinStrVal;
      put.value.str = (PLI_BYTE8*)"101";
      vpi_put_value(target, &put, 0, vpiNoDelay);
      check_real(target, "binary string", 5.0);

      put_value(target, vpiScalarVal, vpi1);
      check_real(target, "scalar one", 1.0);
      put_value(target, vpiScalarVal, vpiX);
      check_real(target, "scalar x", 0.0);
      put_value(target, vpiScalarVal, vpiZ);
      check_real(target, "scalar z", 0.0);

      put_vector(target, 5, 0);
      check_real(target, "vector", 5.0);
      put_vector(target, 0x80000000, 0);
      check_real(target, "unsigned vector", 2147483648.0);
      put_vector(target, 5, 2);
      check_real(target, "vector x bit", 5.0);

      put_vector(element, 13, 0);
      check_real(element, "real array vector", 13.0);

      vpi_printf(failed ? "FAIL vpi_put_value real formats\n"
                        : "PASS vpi_put_value real formats\n");
      return 0;
}

static void register_check(void)
{
      s_vpi_systf_data data;

      memset(&data, 0, sizeof data);
      data.type = vpiSysTask;
      data.tfname = "$check_real_put";
      data.calltf = check_put_calltf;
      vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = {
      register_check,
      0
};
