/*
 * Copyright (c) 2026 Stephen Williams (steve@icarus.com)
 *
 *    This source code is free software; you can redistribute it
 *    and/or modify it in source code form under the terms of the GNU
 *    General Public License as published by the Free Software
 *    Foundation; either version 2 of the License, or (at your option)
 *    any later version.
 *
 *    This program is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with this program; if not, write to the Free Software
 *    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

/*
 * IEEE 1800-2017 40.3 code-coverage access.
 *
 * Icarus implements functional coverage (Clause 19), but it does not
 * instrument statement, toggle, FSM, or assertion code coverage.  The
 * standard gives that state an exact observable result: SV_COV_NOCOV.
 * These routines therefore validate every argument and report the
 * unavailable coverage honestly instead of pretending an operation
 * succeeded or silently discarding it.
 */

# include "sys_priv.h"
# include <assert.h>
# include <limits.h>
# include <string.h>

enum {
      SV_COV_START = 0,
      SV_COV_STOP = 1,
      SV_COV_RESET = 2,
      SV_COV_CHECK = 3,
      SV_COV_MODULE = 10,
      SV_COV_HIER = 11,
      SV_COV_ASSERTION = 20,
      SV_COV_FSM_STATE = 21,
      SV_COV_STATEMENT = 22,
      SV_COV_TOGGLE = 23,
      SV_COV_ERROR = -1,
      SV_COV_NOCOV = 0
};

enum coverage_call_kind {
      COVERAGE_CONTROL,
      COVERAGE_QUERY,
      COVERAGE_DATABASE
};

static void coverage_compile_error(vpiHandle callh, const char*name,
                                   const char*message)
{
      vpi_printf("ERROR: %s:%d: %s %s.\n",
                 vpi_get_str(vpiFile, callh),
                 (int)vpi_get(vpiLineNo, callh), name, message);
      vpip_set_return_value(1);
      vpi_control(vpiFinish, 1);
}

static void coverage_runtime_warning(vpiHandle callh, const char*name,
                                     const char*message)
{
      vpi_printf("WARNING: %s:%d: %s %s.\n",
                 vpi_get_str(vpiFile, callh),
                 (int)vpi_get(vpiLineNo, callh), name, message);
}

static int coverage_is_integral(vpiHandle arg)
{
      PLI_INT32 type = vpi_get(vpiType, arg);

      switch (type) {
          case vpiConstant:
          case vpiParameter:
            return vpi_get(vpiConstType, arg) != vpiRealConst
                && vpi_get(vpiConstType, arg) != vpiStringConst;

          case vpiIntegerVar:
          case vpiBitVar:
          case vpiByteVar:
          case vpiShortIntVar:
          case vpiIntVar:
          case vpiLongIntVar:
          case vpiMemoryWord:
          case vpiNet:
          case vpiPartSelect:
          case vpiReg:
          case vpiTimeVar:
            return 1;

          default:
            return 0;
      }
}

static int coverage_is_string(vpiHandle arg)
{
      PLI_INT32 type = vpi_get(vpiType, arg);
      if (type == vpiStringVar)
            return 1;
      return (type == vpiConstant || type == vpiParameter)
          && vpi_get(vpiConstType, arg) == vpiStringConst;
}

static int coverage_is_target(vpiHandle arg)
{
      return vpi_get(vpiType, arg) == vpiModule || coverage_is_string(arg);
}

static enum coverage_call_kind coverage_kind(const char*name)
{
      if (strcmp(name, "$coverage_control") == 0)
            return COVERAGE_CONTROL;
      if (strcmp(name, "$coverage_get") == 0
          || strcmp(name, "$coverage_get_max") == 0)
            return COVERAGE_QUERY;
      return COVERAGE_DATABASE;
}

static PLI_INT32 coverage_compiletf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv = vpi_iterate(vpiArgument, callh);
      enum coverage_call_kind kind = coverage_kind((const char*)name);
      unsigned expected = kind == COVERAGE_CONTROL ? 4
                        : kind == COVERAGE_QUERY ? 3 : 2;
      unsigned idx;

      assert(callh);
      for (idx = 0 ; idx < expected ; idx += 1) {
            vpiHandle arg = argv ? vpi_scan(argv) : 0;
            int valid;
            if (!arg) {
                  coverage_compile_error(callh, (const char*)name,
                                         "requires more arguments");
                  return 0;
            }

            if ((kind == COVERAGE_CONTROL && idx == 3)
                || (kind == COVERAGE_QUERY && idx == 2))
                  valid = coverage_is_target(arg);
            else if (kind == COVERAGE_DATABASE && idx == 1)
                  valid = coverage_is_string(arg);
            else
                  valid = coverage_is_integral(arg);

            if (!valid) {
                  coverage_compile_error(callh, (const char*)name,
                       ((kind == COVERAGE_CONTROL && idx == 3)
                        || (kind == COVERAGE_QUERY && idx == 2))
                         ? "requires a module instance or string target"
                         : (kind == COVERAGE_DATABASE && idx == 1)
                             ? "requires a string database name"
                             : "requires integral control arguments");
                  return 0;
            }
      }

      if (argv && vpi_scan(argv)) {
            coverage_compile_error(callh, (const char*)name,
                                   "has too many arguments");
      }
      return 0;
}

/* Read an exact, known, nonnegative integer without truncating a wide value. */
static int coverage_get_int(vpiHandle arg, int*result)
{
      s_vpi_value val;
      const char*cp;
      unsigned long accum = 0;

      val.format = vpiBinStrVal;
      vpi_get_value(arg, &val);
      cp = val.value.str;
      if (!cp || !*cp)
            return 0;

      while (*cp) {
            if (*cp != '0' && *cp != '1')
                  return 0;
            if (accum > ((unsigned long)INT_MAX >> 1))
                  return 0;
            accum = (accum << 1) | (*cp == '1');
            cp += 1;
      }

      *result = (int)accum;
      return 1;
}

static int coverage_type_valid(int value)
{
      return value == SV_COV_ASSERTION || value == SV_COV_FSM_STATE
          || value == SV_COV_STATEMENT || value == SV_COV_TOGGLE;
}

static int coverage_scope_valid(int value)
{
      return value == SV_COV_MODULE || value == SV_COV_HIER;
}

static int coverage_control_valid(int value)
{
      return value == SV_COV_START || value == SV_COV_STOP
          || value == SV_COV_RESET || value == SV_COV_CHECK;
}

static int coverage_has_module_definition(const char*name, vpiHandle scope)
{
      vpiHandle iter = vpi_iterate(vpiModule, scope);
      vpiHandle item;

      while (iter && (item = vpi_scan(iter))) {
            const char*defname = vpi_get_str(vpiDefName, item);
            if (defname && strcmp(defname, name) == 0)
                  return 1;
            if (coverage_has_module_definition(name, item))
                  return 1;
      }
      return 0;
}

static int coverage_target_valid(vpiHandle arg)
{
      s_vpi_value val;

      if (vpi_get(vpiType, arg) == vpiModule)
            return 1;
      if (!coverage_is_string(arg))
            return 0;

      val.format = vpiStringVal;
      vpi_get_value(arg, &val);
      if (!val.value.str || !*val.value.str)
            return 0;
      if (strcmp(val.value.str, "$root") == 0)
            return 1;
      return coverage_has_module_definition(val.value.str, 0);
}

static void coverage_put_result(vpiHandle callh, int result)
{
      s_vpi_value val;
      val.format = vpiIntVal;
      val.value.integer = result;
      vpi_put_value(callh, &val, 0, vpiNoDelay);
}

static PLI_INT32 coverage_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv = vpi_iterate(vpiArgument, callh);
      enum coverage_call_kind kind = coverage_kind((const char*)name);
      vpiHandle arg;
      int control = -1;
      int type = -1;
      int scope = -1;
      int valid = 1;
      int result = SV_COV_ERROR;

      assert(callh);
      assert(argv);

      if (kind == COVERAGE_CONTROL) {
            arg = vpi_scan(argv);
            valid = coverage_get_int(arg, &control)
                 && coverage_control_valid(control);
      }

      arg = vpi_scan(argv);
      valid = valid && coverage_get_int(arg, &type)
           && coverage_type_valid(type);

      if (kind != COVERAGE_DATABASE) {
            arg = vpi_scan(argv);
            valid = valid && coverage_get_int(arg, &scope)
                 && coverage_scope_valid(scope);
            arg = vpi_scan(argv);
            valid = valid && coverage_target_valid(arg);
      } else {
            arg = vpi_scan(argv);
            valid = valid && coverage_is_string(arg);
      }

      if (!valid) {
            coverage_runtime_warning(callh, (const char*)name,
                                     "received an invalid argument and returns SV_COV_ERROR");
            coverage_put_result(callh, SV_COV_ERROR);
            return 0;
      }

      if (kind == COVERAGE_QUERY) {
            result = SV_COV_NOCOV;
            coverage_runtime_warning(callh, (const char*)name,
                 "returns SV_COV_NOCOV because code coverage is not instrumented");
      } else if (kind == COVERAGE_DATABASE) {
            if (strcmp((const char*)name, "$coverage_save") == 0) {
                  result = SV_COV_NOCOV;
                  coverage_runtime_warning(callh, (const char*)name,
                       "returns SV_COV_NOCOV because no code coverage is available to save");
            } else {
                  result = SV_COV_ERROR;
                  coverage_runtime_warning(callh, (const char*)name,
                       "returns SV_COV_ERROR because no code-coverage database backend is available");
            }
      } else if (control == SV_COV_START || control == SV_COV_CHECK) {
            result = SV_COV_NOCOV;
            coverage_runtime_warning(callh, (const char*)name,
                 "returns SV_COV_NOCOV because code coverage is not instrumented");
      } else {
            result = SV_COV_ERROR;
            coverage_runtime_warning(callh, (const char*)name,
                 "returns SV_COV_ERROR because code-coverage collection is unavailable");
      }

      coverage_put_result(callh, result);
      return 0;
}

static PLI_INT32 coverage_db_compiletf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv = vpi_iterate(vpiArgument, callh);
      vpiHandle arg = argv ? vpi_scan(argv) : 0;

      assert(callh);
      if (!arg) {
            coverage_compile_error(callh, (const char*)name,
                                   "requires one string argument");
            return 0;
      }
      if (!coverage_is_string(arg)) {
            coverage_compile_error(callh, (const char*)name,
                                   "requires one string argument");
            return 0;
      }
      if (argv && vpi_scan(argv))
            coverage_compile_error(callh, (const char*)name,
                                   "takes exactly one argument");
      return 0;
}

static PLI_INT32 coverage_db_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);

      assert(callh);
      if (strcmp((const char*)name, "$set_coverage_db_name") == 0)
            coverage_runtime_warning(callh, (const char*)name,
                 "cannot select a functional-coverage database because that backend is unavailable");
      else
            coverage_runtime_warning(callh, (const char*)name,
                 "cannot load a functional-coverage database because that backend is unavailable");
      return 0;
}

static void coverage_register_function(const char*name)
{
      s_vpi_systf_data tf_data;
      vpiHandle res;

      memset(&tf_data, 0, sizeof tf_data);
      tf_data.type = vpiSysFunc;
      tf_data.sysfunctype = vpiIntFunc;
      tf_data.tfname = (PLI_BYTE8*)name;
      tf_data.calltf = coverage_calltf;
      tf_data.compiletf = coverage_compiletf;
      tf_data.user_data = (PLI_BYTE8*)name;
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);
}

static void coverage_register_task(const char*name)
{
      s_vpi_systf_data tf_data;
      vpiHandle res;

      memset(&tf_data, 0, sizeof tf_data);
      tf_data.type = vpiSysTask;
      tf_data.tfname = (PLI_BYTE8*)name;
      tf_data.calltf = coverage_db_calltf;
      tf_data.compiletf = coverage_db_compiletf;
      tf_data.user_data = (PLI_BYTE8*)name;
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);
}

void sys_coverage_register(void)
{
      coverage_register_function("$coverage_control");
      coverage_register_function("$coverage_get_max");
      coverage_register_function("$coverage_get");
      coverage_register_function("$coverage_merge");
      coverage_register_function("$coverage_save");
      coverage_register_task("$set_coverage_db_name");
      coverage_register_task("$load_coverage_db");
}
