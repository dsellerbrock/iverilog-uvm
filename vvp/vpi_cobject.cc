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
# include  "class_type.h"
# include  "vpi_priv.h"
# include  "vvp_cobject.h"
# include  "vvp_net_sig.h"
# include  "config.h"
#ifdef CHECK_WITH_VALGRIND
# include  "vvp_cleanup.h"
#endif
# include  <cstring>
# include  <string>
# include  <cstdlib>

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

static class_type* get_declared_class_type_(vvp_fun_signal_object*fun)
{
      return fun ? fun->declared_type() : 0;
}

}

/* Shared object -> `'{name:value, ...}` renderer for %p and object string
   value fetches (see vpi_priv.h). Used by the static-array element path
   (array.cc), the dynamic-array/queue element path (the thread object stack
   handle in vpi_vthr_vector.cc), and any other object string fetch. */
std::string vvp_format_cobject_p(const vvp_object_t&obj, int depth)
{
      vvp_cobject*cobj = obj.peek<vvp_cobject>();
      if (!cobj)
	    return std::string("null");
      const class_type*defn = cobj->get_defn();
      if (!defn)
	    return std::string("null");
	// Bound recursion so a cyclic object graph (a class handle that
	// references itself, directly or transitively) cannot loop forever.
      if (depth > 32)
	    return std::string("...");

      std::string out = "'{";
      for (size_t i = 0 ; i < defn->property_count() ; i += 1) {
	    if (i) out += ", ";
	    out += defn->property_name(i);
	    out += ":";
	    const std::string&bt = defn->property_base_type(i);
	    if (bt == "r") {
		  char b[64];
		  snprintf(b, sizeof b, "%g", cobj->get_real(i));
		  out += b;
	    } else if (bt == "S") {
		  out += "\"";
		  out += cobj->get_string(i);
		  out += "\"";
	    } else if (!bt.empty() && bt[0] == 'o') {
		  vvp_object_t sub;
		  cobj->get_object(i, sub, 0);
		  out += vvp_format_cobject_p(sub, depth+1);
	    } else if (!bt.empty() && (bt[0] == 'Q' || bt[0] == 'M')) {
		  out += "<container>";
	    } else {
		    // Integral property: read the vector and print in decimal.
		  vvp_vector4_t v;
		  cobj->get_vec4(i, v);
		  bool is_signed = (!bt.empty() && bt[0] == 's');
		  char b[256];
		  vpip_vec4_to_dec_str(v, b, sizeof b, is_signed);
		  out += b;
	    }
      }
      out += "}";
      return out;
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
	    return vpiUndefined;
      }
}

void __vpiCobjectVar::vpi_get_value(p_vpi_value val)
{
      vvp_fun_signal_object*fun = get_object_fun_(this);
      assert(fun);
      vvp_object_t obj = fun->peek_object();

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

vpiHandle __vpiCobjectVar::vpi_handle(int code)
{
      vvp_fun_signal_object*fun = get_object_fun_(this);

      switch (code) {
          case vpiClassTypespec:
            return get_declared_class_type_(fun);

          case vpiClassDefn:
            if (fun) {
                  vvp_object_t obj = fun->peek_object();
                  if (vvp_cobject*cobj = obj.peek<vvp_cobject>())
                        return const_cast<class_type*>(cobj->get_defn());
            }
            return 0;

          default:
            return __vpiBaseVar::vpi_handle(code);
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
                  /* iverilog emits the wrapping vpiClassVar handle
                     when a class-property of string type is used as
                     the destination of $value$plusargs (or similar
                     VPI lvalue). VPI doesn't have a way for us to
                     reach the inner string field from here, so this
                     assignment is silently dropped. The plusarg's
                     return value (matched/not-matched) is unaffected.
                     One-shot warning so the user knows the value did
                     not propagate. */
                  static bool warned = false;
                  if (!warned) {
                        fprintf(stderr, "vvp warning: dropping string put"
                                " of '%s' to a vpiClassVar — class string"
                                " properties cannot yet receive VPI string"
                                " writes (further similar warnings"
                                " suppressed)\n", val->value.str);
                        warned = true;
                  }
                  return 0;
            }
            break;

          default:
            fprintf(stderr, "vvp error: format %d not supported "
                            "for vpiClassVar put\n", (int)val->format);
            return 0;
      }

      vvp_net_ptr_t dest(get_net(), 0);
      vvp_send_object(dest, obj, vthread_get_wt_context());
      return 0;
}


/*
 * M12: a VPI handle for one member (property) of a live class object.
 * The handle binds the OWNING class variable and a property index; the
 * live object is re-fetched on every access, so the handle stays valid
 * across object re-assignment (and reports nil values when the
 * variable holds null).
 */
class __vpiClassMember : public __vpiHandle {
    public:
      __vpiClassMember(__vpiCobjectVar*parent, const class_type*defn,
		       unsigned idx)
      : parent_(parent), defn_(defn), idx_(idx)
      {
	    decode_type_();
      }

      int get_type_code(void) const override { return type_code_; }

      int vpi_get(int code) override
      {
	    switch (code) {
		case vpiSize:      return (int)width_;
		case vpiSigned:    return signed_ ? 1 : 0;
		case vpiAutomatic: return 0;
		case vpiArrayType:
		  return (kind_ == 'q') ? vpiQueueArray : vpiUndefined;
		default:
		  return vpiUndefined;
	    }
      }

      char* vpi_get_str(int code) override
      {
	    const std::string&nm = defn_->property_name(idx_);
	    switch (code) {
		case vpiName: {
		      char*rbuf = (char*)need_result_buf(nm.size()+1, RBUF_STR);
		      strcpy(rbuf, nm.c_str());
		      return rbuf;
		}
		case vpiFullName: {
		      char*pn = parent_->vpi_get_str(vpiFullName);
		      std::string full = std::string(pn ? pn : "?") + "." + nm;
		      char*rbuf = (char*)need_result_buf(full.size()+1, RBUF_STR);
		      strcpy(rbuf, full.c_str());
		      return rbuf;
		}
		default:
		  return 0;
	    }
      }

      void vpi_get_value(p_vpi_value val) override
      {
	    vvp_cobject*cobj = live_object_();
	    if (!cobj) {
		  val->format = vpiSuppressVal;
		  return;
	    }
	    switch (kind_) {
		case 'v': {
		      vvp_vector4_t vec;
		      cobj->get_vec4(idx_, vec);
		      if (val->format == vpiObjTypeVal)
			    val->format = (width_ <= 32) ? vpiIntVal
							 : vpiVectorVal;
		      vpip_vec4_get_value(vec, vec.size() ? vec.size() : width_,
					  signed_, val);
		      return;
		}
		case 'r': {
		      if (val->format == vpiObjTypeVal)
			    val->format = vpiRealVal;
		      if (val->format == vpiRealVal) {
			    val->value.real = cobj->get_real(idx_);
			    return;
		      }
		      vpip_real_get_value(cobj->get_real(idx_), val);
		      return;
		}
		case 'S': {
		      std::string s = cobj->get_string(idx_);
		      val->format = vpiStringVal;
		      char*rbuf = (char*)need_result_buf(s.size()+1, RBUF_VAL);
		      memcpy(rbuf, s.c_str(), s.size()+1);
		      val->value.str = rbuf;
		      return;
		}
		case 'o': {
		      vvp_object_t obj;
		      cobj->get_object(idx_, obj, 0);
		      val->format = vpiStringVal;
		      const char*desc = describe_class_object_(obj);
		      char*rbuf = (char*)need_result_buf(strlen(desc)+1, RBUF_VAL);
		      strcpy(rbuf, desc);
		      val->value.str = rbuf;
		      return;
		}
		default:
		  fprintf(stderr, "vpi sorry: reading class member '%s' "
			  "(type '%s') through VPI is not supported.\n",
			  defn_->property_name(idx_).c_str(),
			  defn_->property_base_type(idx_).c_str());
		  val->format = vpiSuppressVal;
		  return;
	    }
      }

      vpiHandle vpi_put_value(p_vpi_value val, int) override
      {
	    vvp_cobject*cobj = live_object_();
	    if (!cobj)
		  return 0;
	    switch (kind_) {
		case 'v': {
		      vvp_vector4_t vec(width_, BIT4_0);
		      if (val->format == vpiIntVal) {
			    unsigned long raw =
				  (unsigned long)(PLI_UINT32)val->value.integer;
			    unsigned w32 = width_ < 32 ? width_ : 32;
			    vec.setarray(0, w32, &raw);
			      // sign-extend negative ints into wider members
			    if (width_ > 32 && val->value.integer < 0)
				  for (unsigned b = 32 ; b < width_ ; b += 1)
					vec.set_bit(b, BIT4_1);
		      } else if (val->format == vpiScalarVal) {
			    vec.set_bit(0, (val->value.scalar == vpi1)
					   ? BIT4_1 : BIT4_0);
		      } else if (val->format == vpiVectorVal) {
			    p_vpi_vecval vp = val->value.vector;
			    for (unsigned b = 0 ; b < width_ ; b += 1) {
				  int word = b / 32, bit = b % 32;
				  int a = (vp[word].aval >> bit) & 1;
				  int bb = (vp[word].bval >> bit) & 1;
				  vec.set_bit(b, (vvp_bit4_t)((bb << 2) | a));
			    }
		      } else {
			    fprintf(stderr, "vpi sorry: format %d not "
				    "supported for class member writes.\n",
				    (int)val->format);
			    return 0;
		      }
		      cobj->set_vec4(idx_, vec);
		      return 0;
		}
		case 'r':
		  if (val->format == vpiRealVal) {
			cobj->set_real(idx_, val->value.real);
		  } else if (val->format == vpiIntVal) {
			cobj->set_real(idx_, (double)val->value.integer);
		  } else {
			fprintf(stderr, "vpi sorry: format %d not supported "
				"for real class member writes.\n",
				(int)val->format);
		  }
		  return 0;
		case 'S':
		  if (val->format == vpiStringVal && val->value.str) {
			cobj->set_string(idx_, std::string(val->value.str));
		  } else {
			fprintf(stderr, "vpi sorry: format %d not supported "
				"for string class member writes.\n",
				(int)val->format);
		  }
		  return 0;
		default:
		  fprintf(stderr, "vpi sorry: writing class member '%s' "
			  "(type '%s') through VPI is not supported.\n",
			  defn_->property_name(idx_).c_str(),
			  defn_->property_base_type(idx_).c_str());
		  return 0;
	    }
      }

      vpiHandle vpi_handle(int code) override
      {
	    if (code == vpiParent || code == vpiScope)
		  return parent_;
	    return 0;
      }

    private:
      vvp_cobject* live_object_()
      {
	    vvp_fun_signal_object*fun = get_object_fun_(parent_);
	    if (!fun) return 0;
	    vvp_object_t obj = fun->peek_object();
	    return obj.peek<vvp_cobject>();
      }

	// Decode the property base-type string into (vpi type code,
	// width, signedness, access kind). kinds: 'v' vec4, 'r' real,
	// 'S' string, 'o' object, 'q' container, '?' unknown.
      void decode_type_()
      {
	    const std::string&bt = defn_->property_base_type(idx_);
	    signed_ = false;
	    width_ = 32;
	    kind_ = '?';
	    type_code_ = vpiClassVar;
	    const char*t = bt.c_str();
	    if (bt == "r") {
		  kind_ = 'r'; type_code_ = vpiRealVar; width_ = 1;
		  return;
	    }
	    if (bt == "S") {
		  kind_ = 'S'; type_code_ = vpiStringVar; width_ = 8;
		  return;
	    }
	    if (bt == "o" || bt.compare(0, 3, "oc:") == 0) {
		  kind_ = 'o'; type_code_ = vpiClassVar; width_ = 64;
		  return;
	    }
	    if (bt.size() >= 1 && (t[0] == 'Q' || t[0] == 'M')) {
		  kind_ = 'q'; type_code_ = vpiArrayVar; width_ = 0;
		  return;
	    }
	    bool sgn = (t[0] == 's');
	    const char*base = sgn ? t+1 : t;
	    if (base[0] == 'b' || base[0] == 'L') {
		  bool logic = (base[0] == 'L');
		  unsigned w = (unsigned)strtoul(base+1, 0, 0);
		  if (w == 0) w = 1;
		  signed_ = sgn;
		  width_ = w;
		  kind_ = 'v';
		  if (logic) {
			type_code_ = vpiLogicVar;
		  } else switch (w) {
		      case 8:  type_code_ = vpiByteVar; break;
		      case 16: type_code_ = vpiShortIntVar; break;
		      case 32: type_code_ = vpiIntVar; break;
		      case 64: type_code_ = vpiLongIntVar; break;
		      default: type_code_ = vpiBitVar; break;
		  }
		  return;
	    }
      }

      __vpiCobjectVar*parent_;
      const class_type*defn_;
      unsigned idx_;
      int type_code_;
      unsigned width_;
      bool signed_;
      char kind_;
};

void __vpiCobjectVar::refresh_members_()
{
      vvp_fun_signal_object*fun = get_object_fun_(this);
      const class_type*defn = 0;
      if (fun) {
	    vvp_object_t obj = fun->peek_object();
	    if (vvp_cobject*cobj = obj.peek<vvp_cobject>())
		  defn = cobj->get_defn();
      }
	// Fall back to the declared type for null handles so member
	// introspection works before construction.
      if (!defn && fun)
	    defn = get_declared_class_type_(fun);
      if (defn == members_defn_)
	    return;
      members_.clear();
      members_defn_ = defn;
      if (!defn)
	    return;
      for (size_t idx = 0 ; idx < defn->property_count() ; idx += 1)
	    members_.push_back(new __vpiClassMember(this, defn, idx));
}

vpiHandle __vpiCobjectVar::vpi_iterate(int code)
{
      if (code != vpiMember && code != vpiVariables)
	    return 0;
      refresh_members_();
      if (members_.empty())
	    return 0;
	// Hand the iterator its own malloc'd copy of the handle array
	// (freed with the iterator); the member handles themselves are
	// owned by this variable and stay stable.
      vpiHandle*args = (vpiHandle*)malloc(members_.size() * sizeof(vpiHandle));
      for (size_t idx = 0 ; idx < members_.size() ; idx += 1)
	    args[idx] = members_[idx];
      return vpip_make_iterator(members_.size(), args, true);
}

vpiHandle __vpiCobjectVar::member_by_name(const char*name)
{
      refresh_members_();
      if (!members_defn_)
	    return 0;
      for (size_t idx = 0 ; idx < members_.size() ; idx += 1) {
	    if (members_defn_->property_name(idx) == name)
		  return members_[idx];
      }
      return 0;
}

vpiHandle vpip_make_cobject_var(const char*name, vvp_net_t*net)
{
      __vpiScope*scope = vpip_peek_current_scope();
      const char*use_name = name ? vpip_name_string(name) : NULL;

      __vpiCobjectVar*obj = new __vpiCobjectVar(scope, use_name, net);

      return obj;
}

/*
 * Phase 51: a VPI handle that targets a specific string property of a
 * class instance. The wrapping handle for the class instance does not
 * carry a property index; without one, a vpi_put_value(vpiStringVal)
 * has nowhere to write to. tgt-vvp emits this property-aware handle
 * (via the &cprop_str<ADDR,N> token) when a class string property is
 * passed as an lvalue to a sysfunc such as $value$plusargs.
 *
 * Both get_value(vpiStringVal) and put_value(vpiStringVal) delegate
 * to the cobject's get_string/set_string at the captured property
 * index. Other format codes report a clear error so we don't silently
 * mishandle them.
 */
class __vpiClassPropertyStringVar : public __vpiHandle {
    public:
      __vpiClassPropertyStringVar(size_t prop_idx)
            : cobj_net_(nullptr), prop_idx_(prop_idx) {}

      vvp_net_t*cobj_net_;

      int get_type_code(void) const override { return vpiStringVar; }

      int vpi_get(int code) override
      {
            switch (code) {
                case vpiSize:        return 8;
                case vpiAutomatic:   return 0;
                case vpiSigned:      return 0;
                case vpiConstType:   return vpiNullConst;
                default: return 0;
            }
      }

      char* vpi_get_str(int) override { return nullptr; }

      void vpi_get_value(p_vpi_value val) override
      {
            std::string current = read_property_string_();
            if (val->format == vpiObjTypeVal)
                  val->format = vpiStringVal;
            if (val->format != vpiStringVal) {
                  val->format = vpiSuppressVal;
                  return;
            }
            char*rbuf = static_cast<char*>(
                  need_result_buf(current.size()+1, RBUF_VAL));
            memcpy(rbuf, current.c_str(), current.size()+1);
            val->value.str = rbuf;
      }

      vpiHandle vpi_put_value(p_vpi_value val, int) override
      {
            if (val->format != vpiStringVal || !val->value.str)
                  return 0;
            write_property_string_(val->value.str);
            return 0;
      }

      vpiHandle vpi_handle(int) override { return nullptr; }

    private:
      size_t prop_idx_;

      std::string read_property_string_()
      {
            vvp_object_t obj;
            vvp_fun_signal_object*fun =
                  cobj_net_ ? dynamic_cast<vvp_fun_signal_object*>(cobj_net_->fun) : nullptr;
            if (!fun)
                  fun = cobj_net_ ? dynamic_cast<vvp_fun_signal_object*>(cobj_net_->fil) : nullptr;
            if (fun) obj = fun->peek_object();
            if (vvp_cobject*cobj = obj.peek<vvp_cobject>())
                  return cobj->get_string(prop_idx_);
            return std::string();
      }

      void write_property_string_(const char*s)
      {
            vvp_object_t obj;
            vvp_fun_signal_object*fun =
                  cobj_net_ ? dynamic_cast<vvp_fun_signal_object*>(cobj_net_->fun) : nullptr;
            if (!fun)
                  fun = cobj_net_ ? dynamic_cast<vvp_fun_signal_object*>(cobj_net_->fil) : nullptr;
            if (!fun) return;
            obj = fun->peek_object();
            if (vvp_cobject*cobj = obj.peek<vvp_cobject>())
                  cobj->set_string(prop_idx_, std::string(s));
      }

};

vpiHandle vpip_make_cobject_property_string_var(char*label, size_t prop_idx)
{
      __vpiClassPropertyStringVar*obj = new __vpiClassPropertyStringVar(prop_idx);
      functor_ref_lookup(&obj->cobj_net_, label);
      return obj;
}

#ifdef CHECK_WITH_VALGRIND
void class_delete(vpiHandle item)
{
      __vpiCobjectVar*obj = dynamic_cast<__vpiCobjectVar*>(item);
      delete obj;
}
#endif
