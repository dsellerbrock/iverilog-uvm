#include <stdio.h>
#include <string.h>
#include "sv_vpi_user.h"

static unsigned failures;

static PLI_INT32 probe_typespec(PLI_BYTE8*ud)
{
      static const char*names[] = {
	    "top.v", "top.bt", "top.sv", "top.i", "top.r", "top.s",
	    "top.us.a", 0
      };
      static const int expected[] = {
	    vpiLogicTypespec, vpiLogicTypespec, vpiLogicTypespec, vpiIntTypespec,
	    vpiRealTypespec, vpiStringTypespec, vpiIntTypespec
      };
      static const int expected_left[] = { 7, 7, 0 };
      static const int expected_right[] = { 0, 0, 7 };
      static const int signed_flag[] = { 0, 0, 1 };
      (void)ud;
	/* Follow the issue reproducer's aggregate lookups before us.a. */
	{
	      static const char*aggregates[] = {
		    "top.ps", "top.us", "top.pu", "top.c", 0
	      };
	      for (unsigned n = 0; aggregates[n]; n += 1) {
		    vpiHandle aggregate =
			  vpi_handle_by_name((PLI_BYTE8*)aggregates[n], 0);
		    vpiHandle members = aggregate
			  ? vpi_iterate(vpiMember, aggregate) : 0;
		    while (members && vpi_scan(members)) { }
	      }
	}
      for (unsigned k = 0; names[k]; k += 1) {
	    vpiHandle var = vpi_handle_by_name((PLI_BYTE8*)names[k], 0);
	    vpiHandle typespec = var ? vpi_handle(vpiTypespec, var) : 0;
	    int type = typespec ? vpi_get(vpiType, typespec) : 0;
	    if (!typespec || type != expected[k]) {
		  vpi_printf("FAILED: %s vartype=%d typespec=%d expected=%d\n",
		             names[k], var ? vpi_get(vpiType, var) : 0,
		             type, expected[k]);
		  failures += 1;
		  continue;
	    }
	    if (k < 3) {
		  vpiHandle it = vpi_iterate(vpiRange, typespec);
		  vpiHandle range = it ? vpi_scan(it) : 0;
		  vpiHandle left_handle =
			 range ? vpi_handle(vpiLeftRange, range) : 0;
		  vpiHandle right_handle =
			 range ? vpi_handle(vpiRightRange, range) : 0;
		  s_vpi_value lvalue, rvalue;
		  lvalue.format = rvalue.format = vpiIntVal;
		  if (left_handle) vpi_get_value(left_handle, &lvalue);
		  if (right_handle) vpi_get_value(right_handle, &rvalue);
		  int lval = left_handle ? lvalue.value.integer : -1;
		  int rval = right_handle ? rvalue.value.integer : -1;
		  if (lval != expected_left[k] || rval != expected_right[k] ||
		      vpi_get(vpiSize, typespec) != 8 ||
		      vpi_get(vpiSigned, typespec) != signed_flag[k])
			{
			      vpi_printf("FAILED: %s range=%d:%d size=%d signed=%d\n",
				 names[k], lval, rval, vpi_get(vpiSize, typespec),
				 vpi_get(vpiSigned, typespec));
			      failures += 1;
			}
		  else
			vpi_printf("%s: typespec=%d range=%d:%d size=%d signed=%d\n",
			           names[k], type, lval, rval,
			           vpi_get(vpiSize, typespec),
			           vpi_get(vpiSigned, typespec));
	    } else {
		  vpi_printf("%s: typespec=%d\n", names[k], type);
	    }
	    vpi_free_object(typespec);
	    if (vpi_get(vpiType, typespec) != expected[k])
		  {
			vpi_printf("FAILED: %s typespec invalid after free\n", names[k]);
			failures += 1;
		  }
      }
      if (!failures) vpi_printf("PASSED\n");
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data data;
      memset(&data, 0, sizeof data);
      data.type = vpiSysTask;
      data.tfname = (PLI_BYTE8*)"$probe_typespec";
      data.calltf = probe_typespec;
      vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
