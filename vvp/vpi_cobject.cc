/*
 * Copyright (c) 2012-2025 Picture Elements, Inc.
 *    Stephen Williams (steve@icarus.com)
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

# include  "compile.h"
# include  "vpi_priv.h"
# include  "vvp_cobject.h"
# include  "vvp_net_sig.h"
# include  "config.h"
#ifdef CHECK_WITH_VALGRIND
# include  "vvp_cleanup.h"
#endif
# include  <cstring>

namespace {

static vvp_fun_signal_object* get_object_fun_(__vpiBaseVar*var)
{
      if (!var || !var->get_net())
            return 0;

      vvp_fun_signal_object*fun =
            dynamic_cast<vvp_fun_signal_object*>(var->get_net()->fun);
      if (!fun)
            fun = dynamic_cast<vvp_fun_signal_object*>(var->get_net()->fil);
      return fun;
}

static const char* describe_class_object_(const vvp_object_t&obj)
{
      if (obj.test_nil())
            return "null";

      if (vvp_cobject*cobj = obj.peek<vvp_cobject>()) {
            const class_type*defn = cobj->get_defn();
            if (defn)
                  return defn->class_name().c_str();
      }

      return "<object>";
}

}

__vpiCobjectVar::__vpiCobjectVar(__vpiScope*sc, const char*na, vvp_net_t*ne)
: __vpiBaseVar(sc, na, ne)
{
}

int __vpiCobjectVar::get_type_code(void) const
{ return vpiClassVar; }

int __vpiCobjectVar::vpi_get(int code)
{
      switch (code) {
	case vpiLineNo:
	    return 0;  // Not implemented for now!

	case vpiSize:
	    return 64;

	case vpiConstType:
	    return vpiNullConst;

	case vpiSigned:
	    return 0;

	case vpiAutomatic:
	    return 0;

#if defined(CHECK_WITH_VALGRIND) || defined(BR916_STOPGAP_FIX)
	case _vpiFromThr:
	    return _vpiNoThr;
#endif

	default:
	    fprintf(stderr, "vvp error: get %d not supported "
	                    "by vpiClassVar\n", code);
	    assert(0);
	    return 0;
      }
}

void __vpiCobjectVar::vpi_get_value(p_vpi_value val)
{
      vvp_fun_signal_object*fun = get_object_fun_(this);
      assert(fun);
      vvp_object_t obj = fun->get_object();

      switch (val->format) {
	case vpiObjTypeVal:
	    val->value.misc = reinterpret_cast<char*>(obj.peek<vvp_object>());
	    break;
	case vpiBinStrVal:
	case vpiDecStrVal:
	case vpiOctStrVal:
	case vpiHexStrVal:
	case vpiStringVal:
	    {
	          const char*desc = describe_class_object_(obj);
	          char*rbuf = static_cast<char *>(need_result_buf(strlen(desc)+1, RBUF_VAL));
	          strcpy(rbuf, desc);
	    val->value.str = rbuf;
	    }
	    break;

	case vpiScalarVal:
	    val->value.scalar = obj.test_nil() ? vpi0 : vpi1;
	    break;

	case vpiIntVal:
	    val->value.integer = obj.test_nil() ? 0 : 1;
	    break;

	case vpiVectorVal:
	    val->value.vector = static_cast<p_vpi_vecval>
	                        (need_result_buf(2*sizeof(s_vpi_vecval),
	                                         RBUF_VAL));
	    val->value.vector[0].aval = obj.test_nil() ? 0 : 1;
	    val->value.vector[0].bval = 0;
	    val->value.vector[1].aval = 0;
	    val->value.vector[1].bval = 0;
	    break;

	case vpiRealVal:
	    val->value.real = obj.test_nil() ? 0.0 : 1.0;
	    break;

	default:
	    fprintf(stderr, "vvp error: format %d not supported "
	                    "by vpiClassVar\n", (int)val->format);
	    val->format = vpiSuppressVal;
	    break;
      }
}

vpiHandle __vpiCobjectVar::vpi_put_value(p_vpi_value val, int)
{
      vvp_object_t obj;

      switch (val->format) {
          case vpiObjTypeVal:
            obj = reinterpret_cast<vvp_object*>(val->value.misc);
            break;

          case vpiStringVal:
            if (val->value.str
                && strcmp(val->value.str, "null") != 0
                && strcmp(val->value.str, "    null") != 0) {
                  fprintf(stderr, "vvp error: string value '%s' not supported "
                                  "for vpiClassVar put\n", val->value.str);
                  assert(0);
            }
            break;

          default:
            fprintf(stderr, "vvp error: format %d not supported "
                            "for vpiClassVar put\n", (int)val->format);
            assert(0);
            break;
      }

      vvp_net_ptr_t dest(get_net(), 0);
      vvp_send_object(dest, obj, vthread_get_wt_context());
      return 0;
}

vpiHandle vpip_make_cobject_var(const char*name, vvp_net_t*net)
{
      __vpiScope*scope = vpip_peek_current_scope();
      const char*use_name = name ? vpip_name_string(name) : NULL;

      __vpiCobjectVar*obj = new __vpiCobjectVar(scope, use_name, net);

      return obj;
}

#ifdef CHECK_WITH_VALGRIND
void class_delete(vpiHandle item)
{
      __vpiCobjectVar*obj = dynamic_cast<__vpiCobjectVar*>(item);
      delete obj;
}
#endif
