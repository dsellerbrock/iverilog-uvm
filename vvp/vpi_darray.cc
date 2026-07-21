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
# include  "array_common.h"
# include  "schedule.h"
#ifdef CHECK_WITH_VALGRIND
# include  "vvp_cleanup.h"
#endif
# include  <cstdio>
# include  <cstdlib>
# include  <cstring>
# include  <cassert>
# include  "ivl_alloc.h"

using namespace std;

__vpiDarrayVar::__vpiDarrayVar(__vpiScope*sc, const char*na, vvp_net_t*ne)
: __vpiBaseVar(sc, na, ne)
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
      left_range_.set_value(0);
      return &left_range_;
}

vpiHandle __vpiDarrayVar::get_right_range()
{
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
		  if (mobj->peek_entry(index, key, vval, rval, sval, kind))
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
		  if (! mobj->peek_entry(index, key, vval, rval, sval, kind)) {
			vp->format = vpiSuppressVal;
			return;
		  }
		  switch (kind) {
		      case 0:
			if (vp->format == vpiObjTypeVal)
			      vp->format = vpiVectorVal;
			vpip_vec4_get_value(vval, vval.size(), false, vp);
			return;
		      case 1:
			vp->format = vpiRealVal;
			vpip_real_get_value(rval, vp);
			return;
		      case 2:
			vp->format = vpiStringVal;
			vpip_string_get_value(sval, vp);
			return;
		      default:
			vp->format = vpiSuppressVal;
			return;
		  }
	    }
	    vp->format = vpiSuppressVal;
	    return;
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
          vpip_vec4_get_value(v, v.size(), false, vp);  // TODO sign?
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
	      // M12: associative array elements are keyed, not
	      // positional — VPI writes are diagnosed, not guessed.
	    fprintf(stderr, "vpi sorry: writing associative array "
		    "elements through VPI is not supported.\n");
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
            new_bit = ((b & 1) << 2) | (a & 1);
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
      }
}

vpiHandle __vpiDarrayVar::get_iter_index(struct __vpiArrayIterator*, int idx)
{
      if (vals_words == 0) make_vals_words();

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

      if (vals_words == 0)
	    make_vals_words();

      return &(vals_words[index].as_word);
}

void __vpiDarrayVar::vpi_get_value(p_vpi_value val)
{
      val->format = vpiSuppressVal;
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

vpiHandle vpip_make_darray_var(const char*name, vvp_net_t*net)
{
      __vpiScope*scope = vpip_peek_current_scope();
      const char*use_name = name ? vpip_name_string(name) : NULL;

      __vpiDarrayVar*obj = new __vpiDarrayVar(scope, use_name, net);

      return obj;
}

/* M12: queues (and associative arrays, which are declared through
 * the queue path with 'M*' kinds) now share the full __vpiDarrayVar
 * element-access machinery; the array kind is detected from the live
 * object. */
__vpiQueueVar::__vpiQueueVar(__vpiScope*sc, const char*na, vvp_net_t*ne)
: __vpiDarrayVar(sc, na, ne)
{
      default_array_type_ = vpiQueueArray;
}

vpiHandle vpip_make_queue_var(const char*name, vvp_net_t*net)
{
      __vpiScope*scope = vpip_peek_current_scope();
      const char*use_name = name ? vpip_name_string(name) : NULL;

      __vpiQueueVar*obj = new __vpiQueueVar(scope, use_name, net);

      return obj;
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
