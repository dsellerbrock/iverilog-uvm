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
# include  <cstdlib>
# include  <cstring>
# include  <cstdio>
# include  <string>
# include  <vector>

static int class_cast_is_null_(vpiHandle src_h)
{
      s_vpi_value val;
      val.format = vpiIntVal;
      vpi_get_value(src_h, &val);
      return val.value.integer == 0;
}

static std::string class_cast_name_(vpiHandle ref);
static std::string class_cast_key_(vpiHandle ref);

static int class_cast_compatible_(vpiHandle dest_type, vpiHandle src_type)
{
      std::string dest_name = class_cast_key_(dest_type);

      while (src_type) {
            if (src_type == dest_type)
                  return 1;
            if (class_cast_key_(src_type) == dest_name)
                  return 1;
            src_type = vpi_handle(vpiBaseTypespec, src_type);
      }

      return 0;
}

static int class_cast_trace_enabled_(void)
{
      static int enabled = -1;
      if (enabled < 0) {
            const char*env = getenv("IVL_CAST_TRACE");
            enabled = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
      }
      return enabled;
}

static std::string class_cast_name_(vpiHandle ref)
{
      const char*name;

      if (!ref)
            return "<null>";

      name = vpi_get_str(vpiFullName, ref);
      if (!(name && *name))
            name = vpi_get_str(vpiName, ref);
      return (name && *name) ? std::string(name) : std::string("<unnamed>");
}

static std::string class_cast_key_(vpiHandle ref)
{
      const char*name;

      if (!ref)
            return "<null>";

      /* Use the dispatch prefix (exposed through vpiDefName) as the type
         key.  It is a stable, one-per-definition name that gives each
         specialization of a parameterized class a distinct value, so
         $cast between different specializations of the same class -- for
         example Box#(byte) versus Box#(shortint) -- is correctly rejected.
         vpiName is only the bare class name ("Box"), which collides across
         specializations, and vpiFullName varies with the referencing
         scope; fall back to them only if the dispatch prefix is missing. */
      name = vpi_get_str(vpiDefName, ref);
      if (!(name && *name))
            name = vpi_get_str(vpiName, ref);
      if (!(name && *name))
            name = vpi_get_str(vpiFullName, ref);
      return (name && *name) ? std::string(name) : std::string("<unnamed>");
}

/*
 * $cast(dest, src)
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
      vpiHandle enum_ts = src_h ? vpi_scan(argv) : 0;
      if (!enum_ts)
            argv = 0;      /* iterator auto-freed by the final vpi_scan */
      if (argv)
            vpi_free_object(argv);

      int ok = 1;

      /* Enum destination (hidden third argument = the enum typespec,
         appended by elaboration): the cast succeeds only if the source
         value matches a member (IEEE 1800-2017 6.19.4/8.16); on failure
         the destination is left unmodified and 0 is returned. Values are
         compared as full vectors (any width); a source carrying x/z bits
         matches no member and fails the cast. */
      if (dest_h && src_h && enum_ts
          && vpi_get(vpiType, enum_ts) == vpiEnumTypespec) {
            int src_size = vpi_get(vpiSize, src_h);
            int src_words = (src_size + 31) / 32;
            if (src_words < 1) src_words = 1;
            std::vector<PLI_UINT32> src_a(src_words, 0);
            int src_has_xz = 0;
            {
                  s_vpi_value sv;
                  sv.format = vpiVectorVal;
                  vpi_get_value(src_h, &sv);
                  for (int w = 0; w < src_words; w += 1) {
                        src_a[w] = sv.value.vector[w].aval;
                        if (sv.value.vector[w].bval)
                              src_has_xz = 1;
                  }
                    /* Mask unused high bits of the top word. */
                  if (src_size % 32)
                        src_a[src_words-1] &= (1u << (src_size % 32)) - 1;
            }
            int found = 0;
            vpiHandle members = vpi_iterate(vpiEnumConst, enum_ts);
            if (members && !src_has_xz) {
                  vpiHandle m;
                  while ((m = vpi_scan(members))) {
                        int m_size = vpi_get(vpiSize, m);
                        int m_words = (m_size + 31) / 32;
                        if (m_words < 1) m_words = 1;
                        s_vpi_value mv;
                        mv.format = vpiVectorVal;
                        vpi_get_value(m, &mv);
                        int match = 1;
                        int maxw = src_words > m_words ? src_words : m_words;
                        for (int w = 0; w < maxw; w += 1) {
                              PLI_UINT32 sa = w < src_words ? src_a[w] : 0;
                              PLI_UINT32 ma = w < m_words
                                    ? mv.value.vector[w].aval : 0;
                              PLI_UINT32 mb = w < m_words
                                    ? mv.value.vector[w].bval : 0;
                              if (w == m_words-1 && (m_size % 32)) {
                                    PLI_UINT32 mask = (1u << (m_size % 32)) - 1;
                                    ma &= mask; mb &= mask;
                              }
                              if (mb) { match = 0; break; }
                              if (sa != ma) { match = 0; break; }
                        }
                        if (match)
                              found = 1;
                  }
            } else if (members) {
                  vpi_free_object(members);
            }
            ok = found;
            if (ok) {
                  s_vpi_value v;
                  v.format = vpiObjTypeVal;
                  vpi_get_value(src_h, &v);
                  vpi_put_value(dest_h, &v, 0, vpiNoDelay);
            }
            s_vpi_value rv2;
            rv2.format = vpiIntVal;
            rv2.value.integer = ok;
            vpi_put_value(callh, &rv2, 0, vpiNoDelay);
            return 0;
      }

      if (dest_h && src_h) {
            vpiHandle dest_type = vpi_handle(vpiClassTypespec, dest_h);
            vpiHandle src_decl_type = vpi_handle(vpiClassTypespec, src_h);
            int src_is_null = class_cast_is_null_(src_h);

            if (class_cast_trace_enabled_()) {
                  fprintf(stderr,
                          "trace $cast: dest_arg=%s src_arg=%s dest_type=%s src_decl=%s src_is_null=%d dest_arg_type=%d src_arg_type=%d\n",
                          class_cast_name_(dest_h).c_str(), class_cast_name_(src_h).c_str(),
                          class_cast_name_(dest_type).c_str(), class_cast_name_(src_decl_type).c_str(), src_is_null,
                          dest_h ? vpi_get(vpiType, dest_h) : -1,
                          src_h ? vpi_get(vpiType, src_h) : -1);
                  fprintf(stderr, "trace $cast: dest_arg_h=%p src_arg_h=%p\n", dest_h, src_h);
            }

            if (dest_type) {
                  if (src_is_null) {
                        ok = 1;
                  } else {
                        vpiHandle src_type = vpi_handle(vpiClassDefn, src_h);
                        ok = src_type && class_cast_compatible_(dest_type, src_type);
                        if (class_cast_trace_enabled_()) {
                              fprintf(stderr,
                                      "trace $cast: dest=%s src=%s dest_key=%s src_key=%s ok=%d dest_h=%p src_h=%p\n",
                                      class_cast_name_(dest_type).c_str(),
                                      class_cast_name_(src_type).c_str(),
                                      class_cast_key_(dest_type).c_str(),
                                      class_cast_key_(src_type).c_str(),
                                      ok, dest_type, src_type);
                        }
                  }
            } else if (class_cast_trace_enabled_()) {
                  fprintf(stderr, "trace $cast: missing dest class type\n");
            }

            if (ok) {
                  s_vpi_value v;
                  v.format = vpiObjTypeVal;
                  vpi_get_value(src_h, &v);
                  vpi_put_value(dest_h, &v, 0, vpiNoDelay);
            }
      }

      s_vpi_value rv;
      rv.format = vpiIntVal;
      rv.value.integer = ok;
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
