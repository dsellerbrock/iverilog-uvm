/*
 * Copyright (c) 2010-2025 Stephen Williams (steve@icarus.com)
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
# include  "enum_type.h"
# include  "vpi_priv.h"
#ifdef CHECK_WITH_VALGRIND
# include  "vvp_cleanup.h"
#endif
# include  <iostream>
# include  <cassert>
# include  <climits>
# include  <cstdlib>
# include  <cstring>

using namespace std;

class __vpiTypeParameter : public __vpiHandle {
    public:
      __vpiTypeParameter(__vpiScope*scope, const char*name, bool local,
                         unsigned file_idx, unsigned lineno, vpiHandle typespec)
      : scope_(scope), name_(strdup(name)), local_(local), file_idx_(file_idx),
        lineno_(lineno), typespec_(typespec) { }
      ~__vpiTypeParameter() override { free(name_); }
      int get_type_code(void) const override { return vpiTypeParameter; }
      int vpi_get(int code) override
      {
            switch (code) {
                case vpiLocalParam: return local_;
                case vpiLineNo: return lineno_;
                default: return vpiUndefined;
            }
      }
      char* vpi_get_str(int code) override
      {
            if (code == vpiFile) return simple_set_rbuf_str(file_names[file_idx_]);
            return generic_get_str(code, scope_, name_, nullptr);
      }
      vpiHandle vpi_handle(int code) override
      {
            switch (code) {
                case vpiScope: return scope_;
                case vpiModule: return vpip_module(scope_);
                case vpiTypespec: return typespec_;
                default: return nullptr;
            }
      }
    private:
      __vpiScope* scope_;
      char* name_;
      bool local_;
      unsigned file_idx_;
      unsigned lineno_;
      vpiHandle typespec_;
};

void vpip_type_parameter_delete(__vpiHandle*item)
{
      delete dynamic_cast<__vpiTypeParameter*>(item);
}

struct enumconst_s : public __vpiHandle {
      enumconst_s();
      int get_type_code(void) const override;
      int vpi_get(int code) override;
      char* vpi_get_str(int code) override;
      void vpi_get_value(p_vpi_value val) override;

      const char*name;
      vvp_vector2_t val2;
      vvp_vector4_t val4;
};

struct __vpiEnumTypespec : public __vpiHandle {
      __vpiEnumTypespec();
      int get_type_code(void) const override;
      int vpi_get(int code) override;
      char* vpi_get_str(int code) override
      { return code == vpiName ? const_cast<char*>(typedef_name) : 0; }
      vpiHandle vpi_iterate(int code) override;

      std::vector<enumconst_s> names;
      unsigned width;
      int base_type_code;
      bool is_signed;
	/* The typedef name (37.25 detail 1), or nil. */
      const char*typedef_name = 0;
};


inline __vpiEnumTypespec::__vpiEnumTypespec()
{ }

int __vpiEnumTypespec::get_type_code(void) const
{ return vpiEnumTypespec; }

int __vpiEnumTypespec::vpi_get(int code)
{
      switch (code) {
	  case vpiSize:
	    return names.size();

	    /* This is not currently set correctly. We always use vpiReg for
	     * four state variables and vpiBitVar for two state variables.
	     * This minimal functionality is needed to get the next() and
	     * prev() methods to work correctly with invalid values. */
	  case vpiBaseTypespec:
	    return base_type_code;

	  case vpiSigned:
	    return is_signed;

	  default:
	    fprintf(stderr, "vvp error: get %d not supported "
		    "by __vpiEnumTypespec\n", code);
	    assert(0);
	    return 0;
      }
}


vpiHandle __vpiEnumTypespec::vpi_iterate(int code)
{
      if (code == vpiEnumConst) {
	    vpiHandle*args = static_cast<vpiHandle*>
	                                (calloc(names.size(), sizeof(vpiHandle*)));
	    for (size_t idx = 0 ; idx < names.size() ; idx += 1)
		  args[idx] = &names[idx];

	    return vpip_make_iterator(names.size(), args, true);
      }

      return 0;
}


inline enumconst_s::enumconst_s()
{ }

int enumconst_s::get_type_code(void) const
{ return vpiEnumConst; }

int enumconst_s::vpi_get(int code)
{
      switch (code) {
	  case vpiSize:
	    return val4.size()? val4.size() : val2.size();
	  default:
	    return 0;
      }
}


char* enumconst_s::vpi_get_str(int code)
{
      switch (code) {
	  case vpiName:
	    return const_cast<char*> (name);
	  default:
	    return 0;
      }
}


void enumconst_s::vpi_get_value(p_vpi_value val)
{
      if (val4.size() > 0)
	    vpip_vec4_get_value(val4, val4.size(), false, val);
      else if (val->format == vpiIntVal || val->format == vpiObjTypeVal ||
               val->format == vpiVectorVal || val->format == vpiSuppressVal)
	    vpip_vec2_get_value(val2, val2.size(), false, val);
      else  /* The string formats exist only for 4-state vectors. */
	    vpip_vec4_get_value(vector2_to_vector4(val2, val2.size()),
	                        val2.size(), false, val);
}


void compile_enum2_type(char*label, long width, bool signed_flag,
                        std::list<struct enum_name_s>*names)
{
      struct __vpiEnumTypespec*spec = new struct __vpiEnumTypespec;
      spec->names = std::vector<enumconst_s> (names->size());
      spec->width = width;
      spec->is_signed = signed_flag;
      spec->base_type_code = vpiBitVar;

      size_t idx = 0;
      for (list<struct enum_name_s>::iterator cur = names->begin()
		 ; cur != names->end() ;  ++cur, ++idx) {
	    spec->names[idx].name = cur->text;
	    if (cur->val4) {
		  vvp_vector4_t value4 = vector4_from_text(cur->val4, width);
		  spec->names[idx].val2 = vvp_vector2_t(value4);
		  free(cur->val4);
	    } else
		  spec->names[idx].val2 = vvp_vector2_t(cur->val2, width);
      }

      assert(idx == spec->names.size());
      compile_vpi_symbol(label, spec);
      vpip_attach_to_current_scope(spec);

      free(label);
      delete names;
}

void compile_enum4_type(char*label, long width, bool signed_flag,
                        std::list<struct enum_name_s>*names)
{
      struct __vpiEnumTypespec*spec = new struct __vpiEnumTypespec;
      spec->names = std::vector<enumconst_s> (names->size());
      spec->width = width;
      spec->is_signed = signed_flag;
      spec->base_type_code = vpiReg;

      size_t idx = 0;
      for (list<struct enum_name_s>::iterator cur = names->begin()
		 ; cur != names->end() ;  ++cur, ++idx) {
	    spec->names[idx].name = cur->text;
	    assert(cur->val4);
	    spec->names[idx].val4 = vector4_from_text(cur->val4, width);
	    free(cur->val4);
	    cur->val4 = 0;
      }

      assert(idx == spec->names.size());
      compile_vpi_symbol(label, spec);
      vpip_attach_to_current_scope(spec);

      free(label);
      delete names;
}

#ifdef CHECK_WITH_VALGRIND
void enum_delete(vpiHandle item)
{
      struct __vpiEnumTypespec*obj = dynamic_cast<__vpiEnumTypespec*>(item);

      for (vector<enumconst_s>::iterator iter = obj->names.begin();
           iter != obj->names.end(); ++ iter ) {
	    delete [] iter->name;
      }

      delete obj;
}
#endif

/*
 * Typespecs that .vartype attaches to a signal (vpiTypespec), so VPI
 * applications such as waveform dumpers see enum and packed struct/union
 * types. A plain vector member has a vpiLogicTypespec or vpiBitTypespec.
 */
struct __vpiVectorTypespec : public __vpiHandle {
      __vpiVectorTypespec(int code, int left, int right, bool signed_flag)
      : code_(code), left_(left), right_(right), signed_(signed_flag) { }
      int get_type_code(void) const override { return code_; }
      char* vpi_get_str(int code) override
      { return code == vpiName ? const_cast<char*>(typedef_name) : 0; }
      vpiHandle vpi_handle(int code) override
      {
	    switch (code) {
		case vpiLeftRange: return new __vpiDecConst(left_);
		case vpiRightRange: return new __vpiDecConst(right_);
		default: return 0;
	    }
      }
      vpiHandle vpi_iterate(int code) override
      {
	    if (code != vpiRange) return 0;
	    vpiHandle*args = new vpiHandle[1];
	    args[0] = vpip_make_range(left_, right_);
	    return vpip_make_iterator(1, args, true);
      }
      int vpi_get(int code) override
      {
	    switch (code) {
		case vpiSize: return abs(left_ - right_) + 1;
		case vpiLeftRange: return left_;
		case vpiRightRange: return right_;
		case vpiSigned: return signed_;
		default: return 0;
	    }
      }
      const char*typedef_name = 0;
    private:
      int code_, left_, right_;
      bool signed_;
};

class __vpiBuiltinTypespec : public __vpiHandle {
    public:
      explicit __vpiBuiltinTypespec(int code) : code_(code) { }
      int get_type_code(void) const override { return code_; }
      int vpi_get(int code) override
      {
	    if (code == vpiSize) return code_ == vpiIntTypespec ? 32 : 1;
	    if (code == vpiSigned) return code_ == vpiIntTypespec;
	    return 0;
      }
    private:
      int code_;
};

vpiHandle vpip_make_builtin_typespec(int type_code)
{
      static __vpiBuiltinTypespec int_typespec(vpiIntTypespec);
      static __vpiBuiltinTypespec real_typespec(vpiRealTypespec);
      static __vpiBuiltinTypespec string_typespec(vpiStringTypespec);
      switch (type_code) {
	  case vpiIntTypespec: return &int_typespec;
	  case vpiRealTypespec: return &real_typespec;
	  case vpiStringTypespec: return &string_typespec;
	  default: return 0;
      }
}

vpiHandle vpip_make_vector_typespec(int type_code, int left, int right,
                                    bool signed_flag)
{
      if (type_code != vpiLogicTypespec && type_code != vpiBitTypespec)
	    return 0;
      return new __vpiVectorTypespec(type_code, left, right, signed_flag);
}

struct __vpiTypespecMember : public __vpiHandle {
      int get_type_code(void) const override { return vpiTypespecMember; }
      int vpi_get(int code) override
      { return code == vpiSize ? (int)width : 0; }
      char* vpi_get_str(int code) override
      { return code == vpiName ? name : 0; }
      vpiHandle vpi_handle(int code) override
      { return code == vpiTypespec ? typespec : 0; }

      char*name = 0;
      unsigned width = 0;
      vpiHandle typespec = 0;
};

struct __vpiStructTypespec : public __vpiHandle {
      explicit __vpiStructTypespec(int code) : code_(code) { }
      int get_type_code(void) const override { return code_; }
      char* vpi_get_str(int code) override
      { return code == vpiName ? const_cast<char*>(typedef_name) : 0; }
      int vpi_get(int code) override
      {
	    switch (code) {
		case vpiSize: return width;
		case vpiPacked: return 1;
		default: return 0;
	    }
      }
      vpiHandle vpi_iterate(int code) override
      {
	    if (code != vpiTypespecMember || members.empty()) return 0;
	    vpiHandle*args = static_cast<vpiHandle*>
		  (calloc(members.size(), sizeof(vpiHandle)));
	    for (size_t idx = 0 ; idx < members.size() ; idx += 1)
		  args[idx] = members[idx];
	    return vpip_make_iterator(members.size(), args, true);
      }

      unsigned width = 0;
      std::vector<__vpiTypespecMember*> members;
      const char*typedef_name = 0;
    private:
      int code_;
};

/* A typedef alias (37.25 detail 1): its own name, vpiTypedefAlias to the
   typespec of the typedef it aliases; everything else is that typespec's. */
class __vpiTypespecAlias : public __vpiHandle {
    public:
      __vpiTypespecAlias(const char*name, vpiHandle aliased)
      : name_(name), aliased_(aliased) { }
      int get_type_code(void) const override
      { return aliased_->get_type_code(); }
      int vpi_get(int code) override { return aliased_->vpi_get(code); }
      char* vpi_get_str(int code) override
      {
	    if (code == vpiName) return const_cast<char*>(name_);
	    return aliased_->vpi_get_str(code);
      }
      vpiHandle vpi_handle(int code) override
      {
	    if (code == vpiTypedefAlias) return aliased_;
	    return aliased_->vpi_handle(code);
      }
      vpiHandle vpi_iterate(int code) override
      { return aliased_->vpi_iterate(code); }
    private:
      const char*name_;
      vpiHandle aliased_;
};

/* Render the declared type of a packed value for %p. Struct members are
   laid out MSB first. */
std::string vpip_format_packed_value(vpiHandle spec, vvp_vector4_t value,
				    bool assignment_pattern)
{
      while (auto*alias = dynamic_cast<__vpiTypespecAlias*>(spec))
	    spec = alias->vpi_handle(vpiTypedefAlias);

      const bool is_union = spec->get_type_code() == vpiUnionTypespec;
      if (spec->get_type_code() == vpiStructTypespec
	  || (assignment_pattern && is_union)) {
	    auto*aggregate = static_cast<__vpiStructTypespec*>(spec);
	    if (value.size() != aggregate->width) return {};
	    std::string result = "'{";
	    unsigned remaining = value.size();
	    for (const auto*member : aggregate->members) {
		  remaining = is_union ? 0 : remaining - member->width;
		  if (member != aggregate->members.front()) result += ", ";
		  result += member->name;
		  result += ':';
		  result += vpip_format_packed_value(member->typespec,
		        value.subvalue(remaining, member->width), assignment_pattern);
		  if (is_union) break;
	    }
	    result += '}';
	    return result;
      }

      if (auto*enumeration = dynamic_cast<__vpiEnumTypespec*>(spec)) {
	    if (value.size() != enumeration->width) return {};
	    if (enumeration->base_type_code == vpiBitVar) value.cast2();
	    for (const auto&literal : enumeration->names) {
		  if (literal.val4.size() ? value.eeq(literal.val4)
		      : value.eeq(vector2_to_vector4(literal.val2, literal.val2.size())))
			return literal.name;
	    }
      } else if (spec->get_type_code() == vpiBitTypespec) {
	    value.cast2();
      }

      const bool is_signed = spec->vpi_get(vpiSigned);
      if (assignment_pattern)
	    return vpip_format_integral_literal(value, is_signed);

      // log10(2) < 0.30103. Leave space for the sign and the terminator.
      unsigned cap = value.size() * 30103ULL / 100000 + 3;
      std::vector<char> decimal(cap);
      vpip_vec4_to_dec_str(value, decimal.data(), cap, is_signed);
      return decimal.data();
}

std::string vpip_format_integral_literal(const vvp_vector4_t&value, bool is_signed)
{
      if (value.has_xz()) {
	    // Preserve every X and Z in a legal literal.
	    std::string out = std::to_string(value.size());
	    out += is_signed ? "'sb" : "'b";
	    for (unsigned bit = value.size(); bit > 0; --bit)
		  out += vvp_bit4_to_ascii(value.value(bit - 1));
	    return out;
      }

      unsigned cap = value.size() * 30103ULL / 100000 + 3;
      std::vector<char> decimal(cap);
      vpip_vec4_to_dec_str(value, decimal.data(), cap, is_signed);
      return decimal.data();
}

/* Parse one type of a .vartype string (see tgt-vvp emit_vartypes).
 * Return 0 and set *missing when an enum label is not defined yet. */
static vpiHandle parse_vartype(const char*&cp, unsigned&width, bool&missing)
{
      char*end;
      switch (*cp) {
	  case 'N': {
		/* N<name>:<type> -- the typedef name of the type (37.25
		   detail 1). An enum keeps the first name it is given. On a
		   type that already has a name it is a typedef alias. */
		size_t len = strcspn(cp + 1, ":");
		if (len == 0 || cp[1 + len] != ':') return 0;
		const char*name = vpip_name_string(std::string(cp + 1, len).c_str());
		cp += len + 2;
		bool inner_named = *cp == 'N';
		bool inner_time = *cp == 'T';
		vpiHandle type = parse_vartype(cp, width, missing);
		if (type && inner_time)
		      return new __vpiTypespecAlias(name, type);
		if (type && inner_named && type->vpi_get_str(vpiName))
		      return new __vpiTypespecAlias(name, type);
		if (__vpiStructTypespec*st = dynamic_cast<__vpiStructTypespec*>(type))
		      st->typedef_name = name;
		else if (__vpiVectorTypespec*vt = dynamic_cast<__vpiVectorTypespec*>(type))
		      vt->typedef_name = name;
		else if (__vpiEnumTypespec*et = dynamic_cast<__vpiEnumTypespec*>(type)) {
		      if (!et->typedef_name) et->typedef_name = name;
		}
		return type;
	  }
	  case 'T': {
		++cp;
		bool signed_flag = *cp == 's';
		if (signed_flag) ++cp;
		width = 64;
		return new __vpiVectorTypespec(vpiTimeTypespec, 63, 0, signed_flag);
	  }
	  case 'V':
	  case 'B': {
		int code = *cp == 'V' ? vpiLogicTypespec : vpiBitTypespec;
		++cp;
		bool signed_flag = *cp == 's';
		if (signed_flag) ++cp;
		long long left = strtoll(cp, &end, 10);
		if (end == cp || *end != ':' || left < INT_MIN || left > INT_MAX)
		      return 0;
		cp = end + 1;
		long long right = strtoll(cp, &end, 10);
		if (end == cp || right < INT_MIN || right > INT_MAX)
		      return 0;
		long long size = llabs(left - right) + 1;
		if (size > INT_MAX) return 0;
		cp = end;
		width = size;
		return new __vpiVectorTypespec(code, left, right, signed_flag);
	  }
	  case 'E': {
		unsigned long size = strtoul(cp+1, &end, 10);
		if (end == cp+1 || *end != ':' || size == 0 || size > INT_MAX)
		      return 0;
		cp = end + 1;
		size_t len = strcspn(cp, ",}");
		if (len == 0) return 0;
		std::string label(cp, len);
		cp += len;
		vpiHandle handle = vvp_lookup_handle(label.c_str());
		if (!handle) missing = true;
		auto*enum_type = dynamic_cast<__vpiEnumTypespec*>(handle);
		if (!enum_type || enum_type->width != size) return 0;
		width = size;
		return enum_type;
	  }
	  case 'S':
	  case 'U': {
		bool is_union = *cp == 'U';
		if (cp[1] != '{') return 0;
		cp += 2;
		__vpiStructTypespec*spec = new __vpiStructTypespec(
		      is_union ? vpiUnionTypespec : vpiStructTypespec);
		while (*cp && *cp != '}') {
		      __vpiTypespecMember*member = new __vpiTypespecMember;
		      size_t len = strspn(cp,
		            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_$");
		      if (len == 0 || cp[len] != '=') return 0;
		      member->name = static_cast<char*>(malloc(len + 1));
		      memcpy(member->name, cp, len);
		      member->name[len] = 0;
		      cp += len + 1;
		      member->typespec = parse_vartype(cp, member->width, missing);
		      if (!member->typespec) return 0;
		      spec->members.push_back(member);
		      if (is_union) {
			    if (member->width > spec->width)
				  spec->width = member->width;
		      } else {
			    if (member->width > INT_MAX - spec->width) return 0;
			    spec->width += member->width;
		      }
		      if (*cp == '}') break;
		      if (*cp != ',' || cp[1] == '}') return 0;
		      cp += 1;
		}
		if (*cp != '}' || spec->members.empty()) return 0;
		cp += 1;
		width = spec->width;
		return spec;
	  }
	  default:
	    return 0;
      }
}

class vartype_resolv_t : public resolv_list_s {
    public:
      vartype_resolv_t(char*label, char*text)
      : resolv_list_s(label), text_(text) { }
      ~vartype_resolv_t() override { delete[] text_; }

      bool resolve(bool message_flag) override
      {
	    __vpiCobjectVar*cobject = dynamic_cast<__vpiCobjectVar*>(vvp_lookup_handle(label()));
	    __vpiArray*vif_array = dynamic_cast<__vpiArray*>(vvp_lookup_handle(label()));
	    if ((cobject || vif_array) && text_[0] == 'I') {
		  char*sep;
		  unsigned long len = strtoul(text_ + 1, &sep, 10);
		  if (sep == text_ + 1 || *sep != ':' || len == 0 ||
		      len > strlen(sep + 1) ||
		      !(cobject ? cobject->get_type_code() == vpiVirtualInterfaceVar
		                 : vif_array->is_virtual_interface_array())) {
			  yyerror("invalid .vartype metadata");
			  compile_errors += 1;
		  } else {
			  std::string defname(sep + 1, len);
			  vpiHandle type = vpip_make_interface_typespec(defname.c_str(), sep + 1 + len);
			  if (cobject) cobject->set_interface_typespec(type);
			  else vif_array->typespec = type;
		  }
		  return true;
	    }
	    __vpiSignal*sig = dynamic_cast<__vpiSignal*>(vvp_lookup_handle(label()));
	    __vpiArray*array = dynamic_cast<__vpiArray*>(vvp_lookup_handle(label()));
	    __vpiDarrayVar*darray = dynamic_cast<__vpiDarrayVar*>(vvp_lookup_handle(label()));
	    const char*cp = text_;
	    unsigned width = 0;
	    bool missing = false;
	    vpiHandle spec = (sig || array || darray)
		  ? parse_vartype(cp, width, missing) : 0;
	    bool aggregate_type = spec &&
	          (spec->get_type_code() == vpiStructTypespec ||
	           spec->get_type_code() == vpiUnionTypespec ||
	           spec->get_type_code() == vpiEnumTypespec);
	    bool signal_width_matches = sig && width == sig->width();
	    bool packed_aggregate_width_candidate = sig && aggregate_type &&
	          width > 0 && sig->width() > width && sig->width() % width == 0;
	    if (packed_aggregate_width_candidate &&
	        sig->declared_packed_ranges.empty() && !message_flag)
	      return false;
	    bool packed_base_dimension_matches = sig &&
	          sig->declared_packed_ranges.size() > 1 && width > 0 &&
	          static_cast<unsigned>(labs(static_cast<long>(
	                sig->declared_packed_ranges.back().left) -
	                sig->declared_packed_ranges.back().right) + 1) == width;
	    bool packed_aggregate_width_matches =
	          packed_aggregate_width_candidate &&
	          packed_base_dimension_matches;
	    const vvp_container_layout_s*layout = darray
		  ? darray->container_layout() : nullptr;
	    bool nested_container = layout && layout->element;
	    bool darray_type_matches = darray && spec &&
		  (nested_container
		    ? spec->get_type_code() == vpiStructTypespec &&
		      width == vvp_packed_container_leaf_width(layout)
		    : width == darray->declared_element_width &&
		      (spec->get_type_code() == vpiEnumTypespec ||
		       spec->get_type_code() == vpiStructTypespec));
	    if (((!sig && !array && !darray) || missing) && !message_flag) return false;
	    if ((!sig && !array && !darray) || !spec || *cp ||
	        !(signal_width_matches || packed_aggregate_width_matches ||
	          (array && width == static_cast<unsigned>(array->get_word_size())) ||
	          darray_type_matches)) {
		  yyerror("invalid .vartype metadata");
		  compile_errors += 1;
		  return true;
	    }
	    if (sig) {
		  sig->typespec = spec;
		  if (packed_aggregate_width_matches) {
			sig->packed_base_width = width;
			vpip_trim_packed_base_dimension(sig);
		  }
	    } else if (array) array->typespec = spec;
	    else if (nested_container) darray->packed_leaf_typespec = spec;
	    else darray->element_typespec = spec;
	    return true;
      }

    private:
      char*text_;
};

void compile_vartype(char*label, char*text)
{
      resolv_submit(new vartype_resolv_t(label, text));
}

class packed_vartype_resolv_t : public resolv_list_s {
    public:
      packed_vartype_resolv_t(char*label, char*text)
      : resolv_list_s(label), text_(text) { }
      ~packed_vartype_resolv_t() override { delete[] text_; }

      bool resolve(bool message_flag) override
      {
	    const char*cp = text_;
	    unsigned width = 0;
	    bool missing = false;
	    vpiHandle spec = parse_vartype(cp, width, missing);
	    if (missing && !message_flag) return false;
	    if (spec && !*cp && spec->get_type_code() == vpiStructTypespec
	        && !vvp_lookup_handle(label())) {
		  compile_vpi_symbol(label(), spec);
	    } else {
		  yyerror("invalid .vartype/packed metadata");
		  compile_errors += 1;
	    }
	    return true;
      }

    private:
      char*text_;
};

void compile_packed_vartype(char*label, char*text)
{
      resolv_submit(new packed_vartype_resolv_t(label, text));
}

class property_vartype_resolv_t : public resolv_list_s {
    public:
      property_vartype_resolv_t(char*label, uint64_t idx, char*text)
      : resolv_list_s(label), idx_(idx), text_(text) { }
      ~property_vartype_resolv_t() override { delete[] text_; }

      bool resolve(bool message_flag) override
      {
	    vpiHandle handle = vvp_lookup_handle(label());
	    if (!handle && !message_flag) return false;
	    auto*defn = dynamic_cast<class_type*>(handle);
	    if (defn && idx_ < defn->property_count()) {
		  const char*cp = text_;
		  unsigned width = 0;
		  bool missing = false;
		  vpiHandle spec = parse_vartype(cp, width, missing);
		  if (missing && !message_flag) return false;
		  const auto*layout = defn->property_container_layout(idx_);
		  const int kind = spec ? spec->get_type_code() : 0;
		  if (spec && !*cp && (kind == vpiStructTypespec
		      || (layout && layout->assoc.index_width
			  && (kind == vpiEnumTypespec || kind == vpiUnionTypespec)))
		      && width == defn->property_typespec_width(idx_)
		      && !defn->property_typespec(idx_)) {
			defn->set_property_typespec(idx_, spec);
			return true;
		  }
	    }
	    yyerror("invalid .vartype property metadata");
	    compile_errors += 1;
	    return true;
      }

    private:
      uint64_t idx_;
      char*text_;
};

void compile_property_vartype(char*label, uint64_t idx, char*text)
{
      resolv_submit(new property_vartype_resolv_t(label, idx, text));
}

class typeparam_resolv_t : public resolv_list_s {
    public:
      typeparam_resolv_t(char*label, const char*name, char*text, bool local,
                         long file_idx, long lineno)
      : resolv_list_s(label), name_(strdup(name)), text_(text), local_(local),
        file_idx_(file_idx), lineno_(lineno), scope_(vpip_peek_current_scope()) { }
      ~typeparam_resolv_t() override { free(name_); delete[] text_; }
      bool resolve(bool message_flag) override
      {
            const char*cp = text_;
            unsigned width = 0;
            bool missing = false;
            vpiHandle typespec = parse_vartype(cp, width, missing);
            if (missing && !message_flag) return false;
            if (!typespec || *cp) {
                  yyerror("invalid .param/type metadata");
                  compile_errors += 1;
                  return true;
            }
            vpiHandle param = new __vpiTypeParameter(scope_, name_, local_,
                  file_idx_, lineno_, typespec);
            compile_vpi_symbol(label(), param);
            vpip_attach_to_scope(scope_, param);
            return true;
      }
    private:
      char* name_;
      char* text_;
      bool local_;
      unsigned file_idx_;
      unsigned lineno_;
      __vpiScope* scope_;
};

void compile_type_param(char*label, const char*name, char*type,
                        bool local_flag, long file_idx, long lineno)
{
      resolv_submit(new typeparam_resolv_t(label, name, type, local_flag,
                                           file_idx, lineno));
      free(const_cast<char*>(name));
}
