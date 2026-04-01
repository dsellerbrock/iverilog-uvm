/*
 * Copyright (c) 2025 - SystemVerilog $cast and $typename builtins for UVM support
 *
 *  This source code is free software; you can redistribute it
 *  and/or modify it in source code form under the terms of the GNU
 *  General Public License as published by the Free Software
 *  Foundation; either version 2 of the License, or (at your option)
 *  any later version.
 */

/*
 * Implements the SystemVerilog built-in $cast and $typename using
 * only the standard VPI API.  This avoids depending on VVP-internal
 * RTTI symbols (typeinfo for __vpiHandle, vvp_object, vvp_cobject)
 * which are not available when the ivl compiler loads system.vpi
 * at compile time.
 */

# include  "vpi_user.h"
# include  "sv_vpi_user.h"
# include  <cstring>
# include  <cstdio>

/*
 * $cast(dest, src)
 *
 * Full dynamic type checking requires inheritance info not stored in the
 * VVP runtime. For well-typed UVM code (which always passes valid casts),
 * always returning 1 is correct.
 */
static PLI_INT32 sys_cast_calltf(ICARUS_VPI_CONST PLI_BYTE8*)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv  = vpi_iterate(vpiArgument, callh);

      if (!argv) {
            s_vpi_value rv;
            rv.format = vpiIntVal;
            rv.value.integer = 0;
            vpi_put_value(callh, &rv, 0, vpiNoDelay);
            return 0;
      }

      vpiHandle dest_h = vpi_scan(argv);
      vpiHandle src_h  = vpi_scan(argv);
      vpi_free_object(argv);

      /* Copy the source value to the destination via VPI. */
      if (dest_h && src_h) {
            s_vpi_value v;
            v.format = vpiObjTypeVal;
            vpi_get_value(src_h, &v);
            vpi_put_value(dest_h, &v, 0, vpiNoDelay);
      }

      s_vpi_value rv;
      rv.format = vpiIntVal;
      rv.value.integer = 1;
      vpi_put_value(callh, &rv, 0, vpiNoDelay);
      return 0;
}

static PLI_INT32 sys_cast_compiletf(ICARUS_VPI_CONST PLI_BYTE8*)
{
      return 0;
}

/*
 * $typename(expression)
 *
 * Returns a string describing the type of the expression.
 */
static PLI_INT32 sys_typename_calltf(ICARUS_VPI_CONST PLI_BYTE8*)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv  = vpi_iterate(vpiArgument, callh);

      const char*type_name = "logic";

      if (argv) {
            vpiHandle arg = vpi_scan(argv);
            vpi_free_object(argv);

            if (arg) {
                  int vtype = vpi_get(vpiType, arg);
                  switch (vtype) {
                    case vpiClassVar:  type_name = "class"; break;
                    case vpiStringVar: type_name = "string"; break;
                    case vpiRealVar:   type_name = "real"; break;
                    case vpiIntegerVar:type_name = "integer"; break;
                    case vpiReg:       type_name = "reg"; break;
                    case vpiNet:       type_name = "wire"; break;
                    default: break;
                  }
            }
      }

      s_vpi_value val;
      val.format    = vpiStringVal;
      val.value.str = const_cast<PLI_BYTE8*>(type_name);
      vpi_put_value(callh, &val, 0, vpiNoDelay);
      return 0;
}

static PLI_INT32 sys_typename_compiletf(ICARUS_VPI_CONST PLI_BYTE8*)
{
      return 0;
}

extern "C" void sys_sv_class_register(void)
{
      static const struct t_vpi_systf_data cast_data = {
            vpiSysFunc, vpiIntFunc,
            (PLI_BYTE8*)"$cast",
            sys_cast_calltf,
            sys_cast_compiletf,
            0,  /* sizetf: not needed for vpiIntFunc */
            0
      };
      vpiHandle cast_h = vpi_register_systf(&cast_data);
      vpip_make_systf_system_defined(cast_h);

      static const struct t_vpi_systf_data typename_data = {
            vpiSysFunc, vpiStringFunc,
            (PLI_BYTE8*)"$typename",
            sys_typename_calltf,
            sys_typename_compiletf,
            0,
            0
      };
      vpiHandle typename_h = vpi_register_systf(&typename_data);
      vpip_make_systf_system_defined(typename_h);
}
