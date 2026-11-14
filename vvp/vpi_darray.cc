/*
 * Copyright (c) 2012-2026 Stephen Williams (steve@icarus.com)
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
# include  "vvp_net_sig.h"
# include  "vvp_darray.h"
# include  "vvp_assoc.h"
# include  "vvp_cobject.h"
# include  "class_type.h"
# include  "array_common.h"
# include  "schedule.h"
#ifdef CHECK_WITH_VALGRIND
# include  "vvp_cleanup.h"
#endif
# include  <cstdio>
# include  <cstdlib>
# include  <cstring>
# include  <algorithm>
# include  <cstdint>
# include  <cassert>
# include  "ivl_alloc.h"

using namespace std;

__vpiDarrayVar::__vpiDarrayVar(__vpiScope*sc, const char*na, vvp_net_t*ne,
                               bool automatic_storage)
: __vpiBaseVar(sc, na, ne, automatic_storage)
{
}

unsigned __vpiDarrayVar::get_size() const
{
      const vvp_fun_signal_object*fun = dynamic_cast<vvp_fun_signal_object*> (get_net()->fun);
      if(!fun)
        return 0;

      vvp_object_t val = fun->get_object();
      if (const vvp_darray*aval = val.peek<vvp_darray>())
	    return aval->get_size();
	// M12: associative arrays flow through this handle class too.
      if (const vvp_assoc_base*mval = val.peek<vvp_assoc_base>())
	    return mval->size();
      return 0;
}

vpiHandle __vpiDarrayVar::get_left_range()
{
      if (get_size() == 0 || get_vvp_assoc())
	    return 0;
      left_range_.set_value(0);
      return &left_range_;
}

vpiHandle __vpiDarrayVar::get_right_range()
{
      if (get_size() == 0 || get_vvp_assoc())
	    return 0;
      right_range_.set_value(get_size() - 1);
      return &right_range_;
}

int __vpiDarrayVar::get_word_size() const
{
      vvp_vector4_t new_vec;
      vvp_darray*aobj = get_vvp_darray();
      if (!aobj || aobj->get_size() == 0)
	    return 32;
      aobj->get_word(0, new_vec);
      return new_vec.size();
}

char*__vpiDarrayVar::get_word_str(struct __vpiArrayWord*word, int code)
{
      unsigned index = word->get_index();

      if (code == vpiFile) {  // Not implemented for now!
	    return simple_set_rbuf_str(file_names[0]);
      }

	// For an associative-array element the "name" is its key text (the
	// positional index is meaningless to the user). %p uses this to
	// print '{key:value, ...}'.
      if (code == vpiName || code == vpiFullName) {
	    if (const vvp_assoc_base*mobj = get_vvp_assoc()) {
		  std::string key, sval;
		  vvp_vector4_t vval;
		  double rval = 0.0;
		  int kind = -1;
		  if (mobj->peek_entry(index, key, vval, rval, sval, kind,
				       readmem_index_signed_))
			return simple_set_rbuf_str(key.c_str());
	    }
      }

      char sidx [64];
      snprintf(sidx, 63, "%d", (int)index);
      return generic_get_str(code, scope_, name_, sidx);
}

void __vpiDarrayVar::get_word_value(struct __vpiArrayWord*word, p_vpi_value vp)
{
      unsigned index = word->get_index();
      vvp_darray*aobj = get_vvp_darray();

	// M12: associative array elements — positional access in key
	// order.
      if (!aobj) {
	    if (const vvp_assoc_base*mobj = get_vvp_assoc()) {
		  std::string key, sval;
		  vvp_vector4_t vval;
		  double rval = 0.0;
		  int kind = -1;
		  if (! mobj->peek_entry(index, key, vval, rval, sval, kind,
				       readmem_index_signed_)) {
			vp->format = vpiSuppressVal;
			return;
		  }
		  switch (kind) {
		      case 0:
			if (vp->format == vpiObjTypeVal)
			      vp->format = vpiVectorVal;
			vpip_vec4_get_value(vval, vval.size(), element_signed_, vp);
			return;
		      case 1:
			vp->format = vpiRealVal;
			vpip_real_get_value(rval, vp);
			return;
		      case 2:
			vp->format = vpiStringVal;
			vpip_string_get_value(sval, vp);
			return;
		      case 3: {
			    int key_kind = -1;
			    std::string string_key;
			    const vvp_object*object_key = 0;
			    vvp_vector4_t vector_key;
			    vvp_object_t object_value;
			    if (!mobj->peek_entry_identity(index, key_kind, string_key,
						   object_key, vector_key,
						   object_value)) {
				  vp->format = vpiSuppressVal;
				  return;
			    }
			    if (vp->format == vpiObjTypeVal) {
				  vp->value.misc = reinterpret_cast<char*>(
					object_value.peek<vvp_object>());
				  return;
			    }
			    switch (vp->format) {
				case vpiBinStrVal:
				case vpiOctStrVal:
				case vpiDecStrVal:
				case vpiHexStrVal:
				case vpiStringVal: {
				      std::string text =
					vvp_format_cobject_p(object_value);
				      char*rbuf = (char*)need_result_buf(
					text.size()+1, RBUF_VAL);
				      strcpy(rbuf, text.c_str());
				      vp->value.str = rbuf;
				      return;
				}
				default:
				  vp->format = vpiSuppressVal;
				  return;
			    }
		      }
		      default:
			vp->format = vpiSuppressVal;
			return;
		  }
	    }
	    vp->format = vpiSuppressVal;
	    return;
      }

	// An object-backed element (a class handle or an object-backed
	// unpacked struct) cannot be read through the vec4 path below —
	// aobj->get_word(index, vvp_vector4_t) reads the object handle as a
	// garbage vector and warns. Render it as `'{...}` for %p / string
	// fetches so a whole dynamic array or queue of structs prints like a
	// static array. A nil struct element (never member-written) is shown
	// as its default value by rendering a temporary default-constructed
	// instance, matching the static-array element semantics; a nil class
	// handle element renders as "null".
      if (dynamic_cast<vvp_darray_object*>(aobj)
	  || dynamic_cast<vvp_queue_object*>(aobj)) {
	    switch (vp->format) {
		case vpiObjTypeVal:
		  vp->format = vpiIntVal;
		  vp->value.integer = 0;
		  return;
		case vpiBinStrVal:
		case vpiOctStrVal:
		case vpiDecStrVal:
		case vpiHexStrVal:
		case vpiStringVal: {
		      vvp_object_t oval;
		      aobj->get_word(index, oval);
		      if (oval.test_nil()) {
			    const vvp_fun_signal_object*fun =
				  dynamic_cast<vvp_fun_signal_object*>(get_net()->fun);
			    class_type*defn = fun ? fun->declared_type() : 0;
			    if (defn)
				  oval = vvp_object_t(new vvp_cobject(defn));
		      }
		      std::string s = vvp_format_cobject_p(oval);
		      char*rbuf = (char*)need_result_buf(s.size()+1, RBUF_VAL);
		      strcpy(rbuf, s.c_str());
		      vp->value.str = rbuf;
		      return;
		}
		default:
		  vp->value.integer = 0;
		  return;
	    }
      }

      if(vp->format == vpiObjTypeVal) {
	    // Resolve the natural element format. Queues carry the same
	    // element kinds as dynamic arrays but through a separate class
	    // hierarchy (vvp_queue_real / vvp_queue_string / ...), so both
	    // families must be probed or a real/string queue would fall
	    // through to the vec4 path and read back as x.
          if(dynamic_cast<vvp_darray_real*>(aobj)
	     || dynamic_cast<vvp_queue_real*>(aobj))
              vp->format = vpiRealVal;
          else if(dynamic_cast<vvp_darray_string*>(aobj)
		  || dynamic_cast<vvp_queue_string*>(aobj))
              vp->format = vpiStringVal;
          else
              vp->format = vpiVectorVal;
      }

      switch(vp->format) {
      case vpiBinStrVal:
      case vpiOctStrVal:
      case vpiDecStrVal:
      case vpiHexStrVal:
      case vpiScalarVal:
      case vpiIntVal:
      case vpiVectorVal:
      {
          vvp_vector4_t v;
          aobj->get_word(index, v);
	    // Use the declared element signedness so a signed element (e.g.
	    // int/byte queue or dynamic array) renders negative values
	    // correctly under vpiDecStrVal / %p instead of as a large
	    // unsigned number.
          vpip_vec4_get_value(v, v.size(), element_signed_, vp);
      }
      break;

      case vpiRealVal:
      {
          double d;
          aobj->get_word(index, d);
          vpip_real_get_value(d, vp);
      }
      break;

      case vpiStringVal:
      {
          string s;
          aobj->get_word(index, s);
          vpip_string_get_value(s, vp);
      }
      break;

      default:
          fprintf(stderr, "vpi sorry: value format %d is not implemented "
		  "for array elements.\n", (int)vp->format);
	  vp->format = vpiSuppressVal;
      }
}

void __vpiDarrayVar::put_word_value(struct __vpiArrayWord*word, p_vpi_value vp, int)
{
      unsigned index = word->get_index();
      vvp_darray*aobj = get_vvp_darray();

      if (!aobj) {
	      // M12-4: associative array elements — positional write
	      // in key order, the mirror of get_word_value. The
	      // existing entry supplies the value kind (and the vec4
	      // width); the put format must be convertible to it.
	    vvp_assoc_base*mobj = const_cast<vvp_assoc_base*>(get_vvp_assoc());
	    if (!mobj) {
		  fprintf(stderr, "vpi sorry: this array element kind "
			  "cannot be written through VPI.\n");
		  return;
	    }
	    std::string key, cur_str;
	    vvp_vector4_t cur_vec;
	    double cur_real = 0.0;
	    int kind = -1;
	    if (! mobj->peek_entry(index, key, cur_vec, cur_real,
				   cur_str, kind, readmem_index_signed_)) {
		  fprintf(stderr, "vpi error: associative array element "
			  "index %u does not exist.\n", index);
		  return;
	    }
	    vvp_vector4_t new_vec;
	    double new_real = 0.0;
	    std::string new_str;
	    bool ok = true;
	    switch (kind) {
		case 0: {   // vec4-valued entry
		      unsigned wid = cur_vec.size() ? cur_vec.size() : 32;
		      switch (vp->format) {
			  case vpiScalarVal:
			    new_vec = vvp_vector4_t(wid, BIT4_0);
			    new_vec.set_bit(0, vp->value.scalar ? BIT4_1 : BIT4_0);
			    break;
			  case vpiIntVal: {
				new_vec = vvp_vector4_t(wid, BIT4_0);
				unsigned long uval =
				      (unsigned long)(PLI_UINT32)vp->value.integer;
				for (unsigned b = 0 ; b < wid && b < 32 ; b += 1)
				      new_vec.set_bit(b, (uval >> b) & 1
						      ? BIT4_1 : BIT4_0);
				break;
			  }
			  case vpiVectorVal: {
				new_vec = vvp_vector4_t(wid, BIT4_0);
				p_vpi_vecval vec = vp->value.vector;
				for (unsigned b = 0 ; b < wid ; b += 1) {
				      unsigned wrd = b / 32, bit = b % 32;
				      int aa = (vec[wrd].aval >> bit) & 1;
				      int bb = (vec[wrd].bval >> bit) & 1;
				      new_vec.set_bit(b,
					    bb ? (aa ? BIT4_X : BIT4_Z)
					       : (aa ? BIT4_1 : BIT4_0));
				}
				break;
			  }
			  default:
			    ok = false;
			    break;
		      }
		      break;
		}
		case 1:     // real-valued entry
		      if (vp->format == vpiRealVal)
			    new_real = vp->value.real;
		      else if (vp->format == vpiIntVal)
			    new_real = (double)vp->value.integer;
		      else
			    ok = false;
		      break;
		case 2:     // string-valued entry
		      if (vp->format == vpiStringVal && vp->value.str)
			    new_str = vp->value.str;
		      else
			    ok = false;
		      break;
		default:    // object-valued entry
		      ok = false;
		      break;
	    }
	    if (!ok || ! mobj->poke_entry(index, new_vec, new_real,
					  new_str, kind,
					  readmem_index_signed_)) {
		  fprintf(stderr, "vpi sorry: value format %d cannot be "
			  "written to this associative array element "
			  "(value kind %d).\n", (int)vp->format, kind);
		  return;
	    }
	    mobj->touch();
	    if (vvp_fun_signal_base*fun = get_callback_functor())
		  fun->run_sv_vpi_callbacks();
	    return;
      }

      switch(vp->format) {
      case vpiScalarVal:
      {
          vvp_vector4_t vec(1, vp->value.scalar);
          aobj->set_word(index, vec);
      }
      break;

      case vpiIntVal:
      {
	    // M12: the vector must be SIZED before setarray (this
	    // path used to assert on any VPI element write).
	  unsigned wid = 8 * sizeof(PLI_INT32);
	  vvp_vector4_t vec(wid, BIT4_0);
	  unsigned long val = (unsigned long)(PLI_UINT32)vp->value.integer;
          vec.setarray(0, wid, &val);
          aobj->set_word(index, vec);
      }
      break;

      case vpiVectorVal:        // 2 vs 4 state logic?
      {
          int size = get_word_size();
          PLI_INT32 a = 0, b = 0;
          vvp_vector4_t new_vec(size);
          p_vpi_vecval vec = vp->value.vector;
          vec--; // it will be increased in the first loop iteration

          for(int i = 0; i < size; ++i) {
            int new_bit;
            if(i % (8 * sizeof(vec->aval)) == 0) {
                ++vec;
                a = vec->aval;
                b = vec->bval;
            }

            // convert to vvp_bit4_t
            new_bit = ((b & 1) << 1) | (a & 1);
            new_vec.set_bit(i, (vvp_bit4_t) new_bit);

            a >>= 1;
            b >>= 1;
          }
          aobj->set_word(index, new_vec);
      }
      break;

      case vpiRealVal:
        aobj->set_word(index, vp->value.real);
        break;

      case vpiStringVal:
        aobj->set_word(index, std::string(vp->value.str));
        break;

      default:
          fprintf(stderr, "vpi sorry: value format %d is not implemented "
			  "for array element writes.\n", (int)vp->format);
		  return;
      }

      if (vvp_fun_signal_base*fun = get_callback_functor())
	    fun->run_sv_vpi_callbacks();
}

vpiHandle __vpiDarrayVar::get_iter_index(struct __vpiArrayIterator*, int idx)
{
      make_vals_words();

      return &(vals_words[idx].as_word);
}

int __vpiDarrayVar::vpi_get(int code)
{
      switch (code) {
	  case vpiArrayType: {
	      // M12: one handle class serves dynamic arrays, queues
	      // and associative arrays — report the LIVE kind.
	    vvp_fun_signal_object*fun =
		  dynamic_cast<vvp_fun_signal_object*> (get_net()->fun);
	    if (fun) {
		  vvp_object_t val = fun->get_object();
		  if (val.peek<vvp_queue>())
			return vpiQueueArray;
		  if (val.peek<vvp_assoc_base>())
			return vpiAssocArray;
	    }
	    return default_array_type_;
	  }
	  case vpiLeftRange:
	    return 0;
	  case vpiRightRange:
	    return get_size() - 1;
	  case vpiSize:
            return get_size();
	  case vpiAutomatic:
	    return automatic_storage() ? 1 : 0;
	  case vpiSigned:
	    return 0;

	  default:
	    fprintf(stderr, "vpi sorry: array property %d is not "
		    "implemented.\n", code);
	    return vpiUndefined;
      }
}

char* __vpiDarrayVar::vpi_get_str(int code)
{
      if (code == vpiFile) {  // Not implemented for now!
            return simple_set_rbuf_str(file_names[0]);
      }

      return generic_get_str(code, scope_, name_, NULL);
}

vpiHandle __vpiDarrayVar::vpi_handle(int code)
{
      switch (code) {
          case vpiLeftRange:
            return get_left_range();

          case vpiRightRange:
            return get_right_range();

          case vpiScope:
            return scope_;

          case vpiModule:
            return vpip_module(scope_);
      }

      return 0;
}

vpiHandle __vpiDarrayVar::vpi_index(int index)
{
      if (index >= (long) get_size())
	    return 0;
      if (index < 0)
	    return 0;

      make_vals_words();

      return &(vals_words[index].as_word);
}

void __vpiDarrayVar::vpi_get_value(p_vpi_value val)
{
      val->format = vpiSuppressVal;
}

vvp_fun_signal_base*__vpiDarrayVar::get_callback_functor() const
{
      if (!get_net())
	    return 0;
      vvp_fun_signal_base*fun =
	    dynamic_cast<vvp_fun_signal_base*>(get_net()->fun);
      if (!fun)
	    fun = dynamic_cast<vvp_fun_signal_base*>(get_net()->fil);
      return fun;
}

vvp_darray*__vpiDarrayVar::get_vvp_darray() const
{
      vvp_fun_signal_object*fun = dynamic_cast<vvp_fun_signal_object*> (get_net()->fun);
      assert(fun);
      vvp_object_t obj = fun->get_object();

      return obj.peek<vvp_darray>();
}

const vvp_assoc_base*__vpiDarrayVar::get_vvp_assoc() const
{
      vvp_fun_signal_object*fun = dynamic_cast<vvp_fun_signal_object*> (get_net()->fun);
      if (!fun) return 0;
      vvp_object_t obj = fun->get_object();
      return obj.peek<vvp_assoc_base>();
}

bool __vpiDarrayVar::assoc_readmem_legal() const
{
      return readmem_element_width_ > 0 && readmem_index_width_ > 0
	    && dynamic_cast<const vvp_assoc_vec4*>(get_vvp_assoc()) != 0;
}

static vvp_vector4_t assoc_readmem_int_key_(int value, unsigned width)
{
      vvp_vector4_t key(width, BIT4_0);
      const uint32_t bits = static_cast<uint32_t>(value);
      for (unsigned idx = 0 ; idx < width ; idx += 1) {
	    const bool set = idx < 32 ? ((bits >> idx) & 1) != 0 : value < 0;
	    if (set) key.set_bit(idx, BIT4_1);
      }
      return key;
}

static int assoc_readmem_compare_(const vvp_vector4_t&left,
				  const vvp_vector4_t&right,
				  bool signed_order)
{
      const unsigned width = std::min(left.size(), right.size());
      if (signed_order && width) {
	    const vvp_bit4_t lsign = left.value(width-1);
	    const vvp_bit4_t rsign = right.value(width-1);
	    if (lsign != rsign)
		  return lsign == BIT4_1 ? -1 : 1;
      }
      for (unsigned idx = width ; idx > 0 ; idx -= 1) {
	    const vvp_bit4_t lbit = left.value(idx-1);
	    const vvp_bit4_t rbit = right.value(idx-1);
	    if (lbit == rbit) continue;
	    if (lbit != BIT4_0 && lbit != BIT4_1)
		  return 0;
	    if (rbit != BIT4_0 && rbit != BIT4_1)
		  return 0;
	    return lbit == BIT4_1 ? 1 : -1;
      }
      return 0;
}

int __vpiDarrayVar::assoc_readmem_in_range(
      const struct t_vpi_vecval*key_value, unsigned key_width,
      int start, int stop, bool has_start, bool has_stop) const
{
      if (!assoc_readmem_legal() || !key_value)
	    return -1;

      vvp_vector4_t key(readmem_index_width_, BIT4_0);
      for (unsigned idx = 0 ; idx < readmem_index_width_ && idx < key_width ; idx += 1) {
	    const unsigned word = idx / 32;
	    const unsigned bit = idx % 32;
	    const bool a = (key_value[word].aval >> bit) & 1;
	    const bool b = (key_value[word].bval >> bit) & 1;
	    key.set_bit(idx, b ? (a ? BIT4_X : BIT4_Z)
			    : (a ? BIT4_1 : BIT4_0));
      }
	  for (unsigned idx = 0 ; idx < key.size() ; idx += 1)
	    if (key.value(idx) != BIT4_0 && key.value(idx) != BIT4_1)
		  return -1;

      if (!has_start && !has_stop)
	    return 1;

      vvp_vector4_t start_key = assoc_readmem_int_key_(start,
							  readmem_index_width_);
      vvp_vector4_t stop_key = assoc_readmem_int_key_(stop,
							 readmem_index_width_);
      const int cmp_start = assoc_readmem_compare_(key, start_key,
							   readmem_index_signed_);
      if (has_start && cmp_start < 0)
	    return 0;
      if (!has_stop)
	    return 1;

      const int cmp_stop = assoc_readmem_compare_(key, stop_key,
							  readmem_index_signed_);
      return cmp_stop <= 0;
}

bool __vpiDarrayVar::assoc_readmem_put(const struct t_vpi_vecval*key_value,
				       unsigned key_width,
				       p_vpi_value value)
{
      if (!assoc_readmem_legal() || !key_value || !value
	  || value->format != vpiVectorVal || !value->value.vector)
	    return false;

      vvp_assoc_vec4*assoc = const_cast<vvp_assoc_vec4*>(
	    dynamic_cast<const vvp_assoc_vec4*>(get_vvp_assoc()));
      if (!assoc) return false;

      vvp_vector4_t key(readmem_index_width_, BIT4_0);
      for (unsigned idx = 0 ; idx < readmem_index_width_ && idx < key_width ; idx += 1) {
	    const unsigned word = idx / 32;
	    const unsigned bit = idx % 32;
	    const bool a = (key_value[word].aval >> bit) & 1;
	    const bool b = (key_value[word].bval >> bit) & 1;
	    key.set_bit(idx, b ? (a ? BIT4_X : BIT4_Z)
			    : (a ? BIT4_1 : BIT4_0));
      }

      vvp_vector4_t element(readmem_element_width_, BIT4_0);
      for (unsigned idx = 0 ; idx < readmem_element_width_ ; idx += 1) {
	    const unsigned word = idx / 32;
	    const unsigned bit = idx % 32;
	    const bool a = (value->value.vector[word].aval >> bit) & 1;
	    const bool b = (value->value.vector[word].bval >> bit) & 1;
	    element.set_bit(idx, b ? (a ? BIT4_X : BIT4_Z)
			       : (a ? BIT4_1 : BIT4_0));
      }

      assoc->set(key, element);
      assoc->touch();
      if (vvp_fun_signal_base*fun = get_callback_functor())
	    fun->run_sv_vpi_callbacks();
      return true;
}

int __vpiDarrayVar::assoc_writemem_key(unsigned position, int start,
				       int stop, bool has_start,
				       bool has_stop, char*buffer,
				       unsigned buffer_size) const
{
      if (!assoc_readmem_legal() || !buffer)
	    return -1;

      const vvp_assoc_base*assoc = get_vvp_assoc();
      int key_kind = -1;
      std::string str_key;
      const vvp_object*obj_key = 0;
      vvp_vector4_t vec_key;
      vvp_object_t obj_val;
      if (!assoc->peek_entry_identity(position, key_kind, str_key,
					      obj_key, vec_key, obj_val)
	  || key_kind != 2)
	    return -1;

      struct t_vpi_vecval*key_value = new t_vpi_vecval[(readmem_index_width_+31)/32]();
      for (unsigned idx = 0 ; idx < readmem_index_width_ ; idx += 1) {
	    const vvp_bit4_t bit_value = vec_key.value(idx);
	    if (bit_value == BIT4_X || bit_value == BIT4_Z) {
		  delete[] key_value;
		  return -1;
	    }
	    const unsigned bit = idx % 32;
	    if (bit_value == BIT4_1)
		  key_value[idx/32].aval |= (PLI_UINT32)1 << bit;
      }

      const int in_range = assoc_readmem_in_range(
	    key_value, readmem_index_width_, start, stop, has_start, has_stop);
      delete[] key_value;
      if (in_range <= 0)
	    return in_range;

      const unsigned digits = (readmem_index_width_ + 3) / 4;
      if (buffer_size <= digits)
	    return -1;
      static const char hex_digits[] = "0123456789abcdef";
      for (unsigned digit = 0 ; digit < digits ; digit += 1) {
	    unsigned value = 0;
	    for (unsigned bit = 0 ; bit < 4 ; bit += 1) {
		  unsigned bit_index = digit*4 + bit;
		  if (bit_index < readmem_index_width_
		      && vec_key.value(bit_index) == BIT4_1)
			value |= 1U << bit;
	    }
	    buffer[digits-digit-1] = hex_digits[value];
      }
      buffer[digits] = 0;
      return 1;
}

vpiHandle vpip_make_darray_var(const char*name, vvp_net_t*net,
			       bool automatic_storage,
                                      bool element_signed, unsigned element_width)
{
      __vpiScope*scope = vpip_peek_current_scope();
      const char*use_name = name ? vpip_name_string(name) : NULL;

      __vpiDarrayVar*obj = new __vpiDarrayVar(scope, use_name, net,
                                              automatic_storage);
      obj->set_element_signed(element_signed);
      obj->declared_element_width = element_width;

      return obj;
}

/* M12: queues (and associative arrays, which are declared through
 * the queue path with 'M*' kinds) now share the full __vpiDarrayVar
 * element-access machinery; the array kind is detected from the live
 * object. */
__vpiQueueVar::__vpiQueueVar(__vpiScope*sc, const char*na, vvp_net_t*ne,
                             bool automatic_storage, unsigned element_width,
                             unsigned assoc_index_width,
                             bool assoc_index_signed)
: __vpiDarrayVar(sc, na, ne, automatic_storage)
{
      default_array_type_ = vpiQueueArray;
      declared_element_width = element_width;
      set_assoc_readmem_type(element_width, assoc_index_width,
			     assoc_index_signed);
}

vpiHandle vpip_make_queue_var(const char*name, vvp_net_t*net,
			      bool automatic_storage,
                              bool element_signed,
                              unsigned element_width,
                              unsigned assoc_index_width,
                              bool assoc_index_signed)
{
      __vpiScope*scope = vpip_peek_current_scope();
      const char*use_name = name ? vpip_name_string(name) : NULL;

      __vpiQueueVar*obj = new __vpiQueueVar(scope, use_name, net,
					    automatic_storage, element_width,
					    assoc_index_width,
					    assoc_index_signed);
      obj->set_element_signed(element_signed);

      return obj;
}

extern "C" int vpip_assoc_readmem_legal(vpiHandle array)
{
      __vpiDarrayVar*obj = dynamic_cast<__vpiDarrayVar*>(array);
      return obj && obj->vpi_get(vpiArrayType) == vpiAssocArray
	    && obj->assoc_readmem_legal();
}

extern "C" unsigned vpip_assoc_readmem_width(vpiHandle array)
{
      __vpiDarrayVar*obj = dynamic_cast<__vpiDarrayVar*>(array);
      return obj && obj->assoc_readmem_legal()
	    ? obj->assoc_readmem_element_width() : 0;
}

extern "C" unsigned vpip_assoc_readmem_index_width(vpiHandle array)
{
      __vpiDarrayVar*obj = dynamic_cast<__vpiDarrayVar*>(array);
      return obj && obj->assoc_readmem_legal()
	    ? obj->assoc_readmem_index_width() : 0;
}

extern "C" vpiHandle vpip_assoc_readmem_typespec(vpiHandle array)
{
      __vpiDarrayVar*obj = dynamic_cast<__vpiDarrayVar*>(array);
      return obj ? obj->element_typespec : 0;
}

extern "C" int vpip_assoc_readmem_in_range(
      vpiHandle array, const struct t_vpi_vecval*key, unsigned key_width,
      int start, int stop, int has_start, int has_stop)
{
      __vpiDarrayVar*obj = dynamic_cast<__vpiDarrayVar*>(array);
      return obj ? obj->assoc_readmem_in_range(key, key_width, start, stop,
						       has_start != 0,
						       has_stop != 0) : -1;
}

extern "C" int vpip_assoc_readmem_put(vpiHandle array,
				      const struct t_vpi_vecval*key,
				      unsigned key_width, p_vpi_value value)
{
      __vpiDarrayVar*obj = dynamic_cast<__vpiDarrayVar*>(array);
      return obj && obj->assoc_readmem_put(key, key_width, value);
}

extern "C" int vpip_assoc_writemem_key(vpiHandle array, unsigned position,
				       int start, int stop,
				       int has_start, int has_stop,
				       char*buffer, unsigned buffer_size)
{
      __vpiDarrayVar*obj = dynamic_cast<__vpiDarrayVar*>(array);
      return obj ? obj->assoc_writemem_key(position, start, stop,
						   has_start != 0,
						   has_stop != 0,
						   buffer, buffer_size) : -1;
}

#ifdef CHECK_WITH_VALGRIND
void array_delete(vpiHandle item)
{
      __vpiDarrayVar*dobj = dynamic_cast<__vpiDarrayVar*>(item);
      if (dobj) {
	    if (dobj->vals_words) delete [] (dobj->vals_words-1);
	    delete dobj;
	    return;
      }

      __vpiQueueVar*qobj = dynamic_cast<__vpiQueueVar*>(item);
      if (qobj) {
	    delete qobj;
	    return;
      }

      fprintf(stderr, "Need support for deleting array type: %d\n", item->vpi_get(vpiArrayType));
      assert(0);
}
#endif
