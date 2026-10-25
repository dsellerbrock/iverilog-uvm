/*
 * Print the vpiTypespec of each argument of $show_typespec: enum names and
 * values, and packed struct/union members with their types.
 */
#include <stdio.h>
#include <string.h>
#include "sv_vpi_user.h"

static const char *type_name(PLI_INT32 type)
{
      switch (type) {
	  case vpiEnumTypespec:   return "enum";
	  case vpiStructTypespec: return "struct";
	  case vpiUnionTypespec:  return "union";
	  case vpiLogicTypespec:  return "logic";
	  case vpiBitTypespec:    return "bit";
	  default:                return "?";
      }
}

static void show(vpiHandle ts, int indent, PLI_INT32 width)
{
      PLI_INT32 type = vpi_get(vpiType, ts);
      vpiHandle iter, item;

      vpi_printf("%s", type_name(type));
      switch (type) {
	  case vpiEnumTypespec:
	    vpi_printf(" %d\n", (int)width);
	    iter = vpi_iterate(vpiEnumConst, ts);
	    while ((item = vpi_scan(iter))) {
		  s_vpi_value val;
		  val.format = vpiBinStrVal;
		  vpi_get_value(item, &val);
		  vpi_printf("%*s%s = %s\n", indent + 2, "",
		             vpi_get_str(vpiName, item), val.value.str);
	    }
	    break;
	  case vpiStructTypespec:
	  case vpiUnionTypespec:
	    vpi_printf(" %d packed=%d\n", (int)vpi_get(vpiSize, ts),
	               (int)vpi_get(vpiPacked, ts));
	    iter = vpi_iterate(vpiTypespecMember, ts);
	    while ((item = vpi_scan(iter))) {
		  vpi_printf("%*s%s: ", indent + 2, "", vpi_get_str(vpiName, item));
		  show(vpi_handle(vpiTypespec, item), indent + 2,
		       vpi_get(vpiSize, item));
	    }
	    break;
	  default:
	    vpi_printf(" [%d:%d]\n", (int)vpi_get(vpiLeftRange, ts),
	               (int)vpi_get(vpiRightRange, ts));
	    break;
      }
}

static PLI_INT32 show_typespec_calltf(PLI_BYTE8 *user)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv = vpi_iterate(vpiArgument, callh);
      vpiHandle arg;

      (void)user;
      while ((arg = vpi_scan(argv))) {
	    vpiHandle ts = vpi_handle(vpiTypespec, arg);
	    vpi_printf("%s: ", vpi_get_str(vpiFullName, arg));
	    if (ts) show(ts, 0, vpi_get(vpiSize, arg));
	    else vpi_printf("no typespec\n");
      }
      return 0;
}

static void register_show_typespec(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$show_typespec";
      tf.calltf = show_typespec_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_show_typespec, 0 };
