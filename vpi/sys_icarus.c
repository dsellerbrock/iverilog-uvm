/*
 *  Copyright (C) 2008-2025  Cary R. (cygcary@yahoo.com)
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include "sys_priv.h"
#include <assert.h>
#include <stdlib.h>
#include <string.h>

static PLI_INT32 finish_and_return_calltf(ICARUS_VPI_CONST PLI_BYTE8* name)
{
    vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
    vpiHandle argv = vpi_iterate(vpiArgument, callh);
    vpiHandle arg;
    s_vpi_value val;
    (void) name;  /* Not used! */

    /* Get the return value. */
    arg = vpi_scan(argv);
    vpi_free_object(argv);
    val.format = vpiIntVal;
    vpi_get_value(arg, &val);

    /* Set the return value. */
    vpip_set_return_value(val.value.integer);

    /* Now finish. */
    vpi_control(vpiFinish, 1);
    return 0;
}

static PLI_INT32 task_not_implemented_compiletf(ICARUS_VPI_CONST PLI_BYTE8* name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);

      vpi_printf("SORRY: %s:%d: task %s() is not currently implemented.\n",
                 vpi_get_str(vpiFile, callh), (int)vpi_get(vpiLineNo, callh),
                 name);
      vpip_set_return_value(1);
      vpi_control(vpiFinish, 1);
      return 0;
}

/* No-op stub: accept any arguments, do nothing at call time. */
static PLI_INT32 noop_calltf(ICARUS_VPI_CONST PLI_BYTE8* ud)
{
      (void)ud;
      return 0;
}
/* No-op real-function stub: return 0.0. */
static PLI_INT32 noop_real_calltf(ICARUS_VPI_CONST PLI_BYTE8* ud)
{
      (void)ud;
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      s_vpi_value val;
      val.format = vpiRealVal;
      val.value.real = 0.0;
      vpi_put_value(callh, &val, 0, vpiNoDelay);
      return 0;
}
static PLI_INT32 noop_compiletf(ICARUS_VPI_CONST PLI_BYTE8* ud)
{
      (void)ud;
      return 0;
}

/*
 * Implement $system(cmd) — execute a shell command and return its exit status.
 * This matches the behavior expected by OpenTitan DV testbenches.
 */
static PLI_INT32 system_calltf(ICARUS_VPI_CONST PLI_BYTE8* name)
{
      (void)name;
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv = vpi_iterate(vpiArgument, callh);
      int ret = 0;
      if (argv) {
	    vpiHandle arg = vpi_scan(argv);
	    if (arg) {
		  s_vpi_value val;
		  val.format = vpiStringVal;
		  vpi_get_value(arg, &val);
		  if (val.value.str)
			ret = system(val.value.str);
	    }
	    vpi_free_object(argv);
      }
      vpip_set_return_value(ret);
      return 0;
}

/* $isunbounded(expr): returns 1 if the argument equals the unbounded constant
 * (represented as 0x7FFFFFFF), 0 otherwise.  IEEE 1800-2012 section 20.6. */
static PLI_INT32 isunbounded_calltf(ICARUS_VPI_CONST PLI_BYTE8* ud)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv  = vpi_iterate(vpiArgument, callh);
      (void)ud;
      if (argv == 0) { vpi_free_object(callh); return 0; }
      vpiHandle arg = vpi_scan(argv);
      vpi_free_object(argv);
      s_vpi_value val;
      val.format = vpiIntVal;
      vpi_get_value(arg, &val);
      /* The unbounded constant $ is represented as 0x7FFFFFFF. */
      s_vpi_value ret;
      ret.format = vpiIntVal;
      ret.value.integer = (val.value.integer == 0x7FFFFFFF) ? 1 : 0;
      vpi_put_value(callh, &ret, 0, vpiNoDelay);
      return 0;
}

/*
 * This is used to warn the user that the specified optional system
 * task/function is not available (from Annex C 1364-2005).
 */
static PLI_INT32 missing_optional_compiletf(ICARUS_VPI_CONST PLI_BYTE8* name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);

      vpi_printf("SORRY: %s:%d: %s() is not available in Icarus Verilog.\n",
                 vpi_get_str(vpiFile, callh), (int)vpi_get(vpiLineNo, callh),
                 name);
      vpip_set_return_value(1);
      vpi_control(vpiFinish, 1);
      return 0;
}

/*
 * Register the function with Verilog.
 */
void sys_special_register(void)
{
      s_vpi_systf_data tf_data;
      vpiHandle res;

      tf_data.type        = vpiSysTask;
      tf_data.calltf      = finish_and_return_calltf;
      tf_data.compiletf   = sys_one_numeric_arg_compiletf;
      tf_data.sizetf      = 0;
      tf_data.tfname      = "$finish_and_return";
      tf_data.user_data   = "$finish_and_return";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

	/* These tasks are not currently implemented. */
      tf_data.type        = vpiSysTask;
      tf_data.calltf      = 0;
      tf_data.sizetf      = 0;
      tf_data.compiletf   = task_not_implemented_compiletf;

      tf_data.tfname      = "$async$and$array";
      tf_data.user_data   = "$async$and$array";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$async$nand$array";
      tf_data.user_data   = "$async$nand$array";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$async$or$array";
      tf_data.user_data   = "$async$or$array";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$async$nor$array";
      tf_data.user_data   = "$async$nor$array";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$async$and$plane";
      tf_data.user_data   = "$async$and$plane";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$async$nand$plane";
      tf_data.user_data   = "$async$nand$plane";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$async$or$plane";
      tf_data.user_data   = "$async$or$plane";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$async$nor$plane";
      tf_data.user_data   = "$async$nor$plane";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$sync$and$array";
      tf_data.user_data   = "$sync$and$array";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$sync$nand$array";
      tf_data.user_data   = "$sync$nand$array";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$sync$or$array";
      tf_data.user_data   = "$sync$or$array";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$sync$nor$array";
      tf_data.user_data   = "$sync$nor$array";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$sync$and$plane";
      tf_data.user_data   = "$sync$and$plane";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$sync$nand$plane";
      tf_data.user_data   = "$sync$nand$plane";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$sync$or$plane";
      tf_data.user_data   = "$sync$or$plane";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$sync$nor$plane";
      tf_data.user_data   = "$sync$nor$plane";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      /* $dumpports* stubs — accept-and-ignore (not yet implemented but
       * must not abort the simulation so tests can run to completion). */
      tf_data.calltf      = noop_calltf;
      tf_data.compiletf   = noop_compiletf;

      tf_data.tfname      = "$dumpports";
      tf_data.user_data   = "$dumpports";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$dumpportsoff";
      tf_data.user_data   = "$dumpportsoff";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$dumpportson";
      tf_data.user_data   = "$dumpportson";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$dumpportsall";
      tf_data.user_data   = "$dumpportsall";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$dumpportslimit";
      tf_data.user_data   = "$dumpportslimit";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$dumpportsflush";
      tf_data.user_data   = "$dumpportsflush";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

	/* The following optional system tasks/functions are not implemented
	 * in Icarus Verilog (from Annex C 1364-2005). */
      tf_data.type        = vpiSysTask;
      tf_data.calltf      = 0;
      tf_data.sizetf      = 0;
      tf_data.compiletf   = missing_optional_compiletf;

      tf_data.tfname      = "$input";
      tf_data.user_data   = "$input";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$key";
      tf_data.user_data   = "$key";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$nokey";
      tf_data.user_data   = "$nokey";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$list";
      tf_data.user_data   = "$list";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$log";
      tf_data.user_data   = "$log";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$nolog";
      tf_data.user_data   = "$nolog";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$save";
      tf_data.user_data   = "$save";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$restart";
      tf_data.user_data   = "$restart";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$incsave";
      tf_data.user_data   = "$incsave";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$scope";
      tf_data.user_data   = "$scope";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$showscopes";
      tf_data.user_data   = "$showscopes";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$showvars";
      tf_data.user_data   = "$showvars";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$sreadmemb";
      tf_data.user_data   = "$sreadmemb";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$sreadmemh";
      tf_data.user_data   = "$sreadmemh";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

	/* Optional functions. */
      tf_data.type = vpiSysFunc;
      tf_data.sysfunctype = vpiIntFunc;

      tf_data.tfname      = "$getpattern";
      tf_data.user_data   = "$getpattern";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$scale";
      tf_data.user_data   = "$scale";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      /* $system(cmd) — execute a shell command, return exit status. */
      tf_data.type        = vpiSysFunc;
      tf_data.sysfunctype = vpiIntFunc;
      tf_data.calltf      = system_calltf;
      tf_data.compiletf   = 0;
      tf_data.sizetf      = 0;
      tf_data.tfname      = "$system";
      tf_data.user_data   = "$system";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      /* $isunbounded(expr) — returns 1 if expr is the unbounded constant ($),
       * represented as 0x7FFFFFFF, 0 otherwise.  IEEE 1800-2012 section 20.6. */
      tf_data.type        = vpiSysFunc;
      tf_data.sysfunctype = vpiIntFunc;
      tf_data.calltf      = isunbounded_calltf;
      tf_data.compiletf   = 0;
      tf_data.sizetf      = 0;
      tf_data.tfname      = "$isunbounded";
      tf_data.user_data   = "$isunbounded";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      /* IEEE 1800-2012 section 20.14 — coverage control functions (stubs). */

      /* $root — scope handle stub, returns 0 as integer. */
      tf_data.type        = vpiSysFunc;
      tf_data.sysfunctype = vpiIntFunc;
      tf_data.calltf      = noop_calltf;
      tf_data.compiletf   = noop_compiletf;
      tf_data.sizetf      = 0;
      tf_data.tfname      = "$root";
      tf_data.user_data   = "$root";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$coverage_control";
      tf_data.user_data   = "$coverage_control";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$coverage_get_max";
      tf_data.user_data   = "$coverage_get_max";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$coverage_merge";
      tf_data.user_data   = "$coverage_merge";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$coverage_save";
      tf_data.user_data   = "$coverage_save";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      /* $coverage_get returns real. */
      tf_data.type        = vpiSysFunc;
      tf_data.sysfunctype = vpiRealFunc;
      tf_data.calltf      = noop_real_calltf;
      tf_data.tfname      = "$coverage_get";
      tf_data.user_data   = "$coverage_get";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$get_coverage";
      tf_data.user_data   = "$get_coverage";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      /* $set_coverage_db_name, $load_coverage_db — tasks. */
      tf_data.type        = vpiSysTask;
      tf_data.sysfunctype = 0;
      tf_data.tfname      = "$set_coverage_db_name";
      tf_data.user_data   = "$set_coverage_db_name";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$load_coverage_db";
      tf_data.user_data   = "$load_coverage_db";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);
}
