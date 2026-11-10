#include <string.h>
#include "vpi_user.h"

static int failures;

static void check(vpiHandle handle, const char *name,
		  unsigned high, unsigned low)
{
      s_vpi_time time_value;
      s_vpi_value value;

      memset(&time_value, 0, sizeof time_value);
      memset(&value, 0, sizeof value);
      value.format = vpiTimeVal;
      value.value.time = &time_value;
      vpi_get_value(handle, &value);

      if (value.format == vpiTimeVal && value.value.time == &time_value &&
	  time_value.type == vpiSimTime && time_value.high == high &&
	  time_value.low == low) {
	    vpi_printf("VPI TIMEVAL %s=%08x:%08x\n", name,
		       (unsigned)time_value.high, (unsigned)time_value.low);
      } else {
	    vpi_printf("VPI TIMEVAL FAIL %s format=%d type=%d high=%08x low=%08x\n",
		       name, value.format, time_value.type,
		       (unsigned)time_value.high, (unsigned)time_value.low);
	    failures += 1;
      }
}

static PLI_INT32 probe(PLI_BYTE8 *data)
{
      vpiHandle handle;
      int found = 1;
      (void)data;

      handle = vpi_handle_by_name((PLI_BYTE8 *)"top.v", 0);
      if (handle)
	    check(handle, "v", 0x12345678, 0x9abcdef0);
      else
	    found = 0;

      handle = vpi_handle_by_name((PLI_BYTE8 *)"top.xz", 0);
      if (handle)
	    check(handle, "xz", 0x12340000, 0x00005678);
      else
	    found = 0;

      if (!found || failures)
	    vpi_printf("VPI TIMEVAL FAIL\n");
      else
	    vpi_printf("VPI TIMEVAL PASS\nPASSED\n");
      return 0;
}

static void reg(void)
{
      s_vpi_systf_data data;
      memset(&data, 0, sizeof data);
      data.type = vpiSysTask;
      data.tfname = (PLI_BYTE8 *)"$probe";
      data.calltf = probe;
      vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { reg, 0 };
