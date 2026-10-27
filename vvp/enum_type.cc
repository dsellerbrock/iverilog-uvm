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
# include  "enum_type.h"
# include  "vpi_priv.h"
#ifdef CHECK_WITH_VALGRIND
# include  "vvp_cleanup.h"
#endif
# include  <iostream>
# include  <cassert>
# include  <cstdlib>
# include  <cstring>

using namespace std;

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
      vpiHandle vpi_iterate(int code) override;

      std::vector<enumconst_s> names;
      int base_type_code;
      bool is_signed;
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
      spec->is_signed = signed_flag;
      spec->base_type_code = vpiBitVar;

      size_t idx = 0;
      for (list<struct enum_name_s>::iterator cur = names->begin()
		 ; cur != names->end() ;  ++cur, ++idx) {
	    assert(cur->val4 == 0);
	    spec->names[idx].name = cur->text;
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
      __vpiVectorTypespec(int code, int left, int right)
      : code_(code), left_(left), right_(right) { }
      int get_type_code(void) const override { return code_; }
      int vpi_get(int code) override
      {
	    switch (code) {
		case vpiSize: return abs(left_ - right_) + 1;
		case vpiLeftRange: return left_;
		case vpiRightRange: return right_;
		default: return 0;
	    }
      }
    private:
      int code_, left_, right_;
};

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
    private:
      int code_;
};

/* Parse one type of a .vartype string (see tgt-vvp emit_signal_vartypes).
 * Return 0 and set *missing when an enum label is not defined yet. */
static vpiHandle parse_vartype(const char*&cp, unsigned&width, bool&missing)
{
      char*end;
      switch (*cp) {
	  case 'V':
	  case 'B': {
		int code = *cp == 'V' ? vpiLogicTypespec : vpiBitTypespec;
		long left = strtol(cp+1, &end, 10);
		if (end == cp+1 || *end != ':') return 0;
		cp = end + 1;
		long right = strtol(cp, &end, 10);
		if (end == cp) return 0;
		cp = end;
		width = labs(left - right) + 1;
		return new __vpiVectorTypespec(code, left, right);
	  }
	  case 'E': {
		width = strtoul(cp+1, &end, 10);
		if (end == cp+1 || *end != ':') return 0;
		cp = end + 1;
		size_t len = strcspn(cp, ",}");
		std::string label(cp, len);
		cp += len;
		vpiHandle enum_type = vvp_lookup_handle(label.c_str());
		if (!enum_type) missing = true;
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
		      size_t len = strcspn(cp, "=");
		      if (cp[len] != '=') return 0;
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
			    spec->width += member->width;
		      }
		      if (*cp == ',') cp += 1;
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
	    __vpiSignal*sig = dynamic_cast<__vpiSignal*>(vvp_lookup_handle(label()));
	    const char*cp = text_;
	    unsigned width = 0;
	    bool missing = false;
	    vpiHandle spec = sig ? parse_vartype(cp, width, missing) : 0;
	    if ((!sig || missing) && !message_flag) return false;
	    if (!sig || !spec || *cp || width != sig->width()) {
		  yyerror("invalid .vartype metadata");
		  compile_errors += 1;
		  return true;
	    }
	    sig->typespec = spec;
	    return true;
      }

    private:
      char*text_;
};

void compile_vartype(char*label, char*text)
{
      resolv_submit(new vartype_resolv_t(label, text));
}
