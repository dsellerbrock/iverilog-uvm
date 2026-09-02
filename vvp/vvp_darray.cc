/*
 * Copyright (c) 2012-2025 Stephen Williams (steve@icarus.com)
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

# include  "vvp_darray.h"
# include  <iostream>
# include  <typeinfo>

/* Value-copy policy for one container element (see vvp_object.h).
   A struct compiles to a synthetic class marked .class/struct, so a
   cobject element deep-copies exactly when its definition carries that
   marker -- a real class object stays a shared handle, preserving
   handle identity through whole-container copies. */
# include  "vvp_cobject.h"
# include  "class_type.h"
# include  "vvp_assoc.h"

vvp_object_t vvp_object_t::value_copy_element(void) const
{
      if (test_nil())
	    return vvp_object_t();
      if (peek<vvp_darray>() || peek<vvp_assoc_base>())
	    return duplicate();
      if (vvp_cobject*cobj = peek<vvp_cobject>()) {
	    const class_type*defn = cobj->get_defn();
	    if (defn && defn->is_struct_type()) {
		  vvp_cobject*copy = new vvp_cobject(defn);
		  copy->shallow_copy(cobj);
		  return vvp_object_t(copy);
	    }
      }
      return *this;
}

using namespace std;

vvp_darray_element_ref::vvp_darray_element_ref(vvp_darray*owner,
                                               size_t index, kind_t kind,
                                               unsigned vec4_width)
: owner_(0), index_(index), kind_(kind), valid_(false),
  vec4_value_(vec4_width, BIT4_X), real_value_(0.0)
{
      if (owner && index < owner->get_size()) {
            owner_ = owner;
            valid_ = true;
            owner_->register_element_ref(this);
      }
}

vvp_darray_element_ref::~vvp_darray_element_ref()
{
      if (owner_) owner_->unregister_element_ref(this);
}

void vvp_darray_element_ref::detach()
{
      if (!owner_) return;

      vvp_darray*old_owner = owner_;
      switch (kind_) {
          case ELEM_VEC4:
            old_owner->get_word((unsigned)index_, vec4_value_);
            break;
          case ELEM_REAL:
            old_owner->get_word((unsigned)index_, real_value_);
            break;
          case ELEM_STRING:
            old_owner->get_word((unsigned)index_, string_value_);
            break;
          case ELEM_OBJECT:
            old_owner->get_word((unsigned)index_, object_value_);
            break;
      }
      owner_ = 0;
      old_owner->unregister_element_ref(this);
      valid_ = true;
}

void vvp_darray_element_ref::shift_up(size_t at)
{
      if (owner_ && index_ >= at) index_ += 1;
}

void vvp_darray_element_ref::shift_down(size_t after)
{
      if (owner_ && index_ > after) index_ -= 1;
}

void vvp_darray_element_ref::set_value(const vvp_vector4_t&value, bool notify)
{
      if (kind_ != ELEM_VEC4 || !valid_) return;
      if (owner_) {
            owner_->set_word((unsigned)index_, value);
            if (notify) owner_->notify_signal_aliases();
      }
      else vec4_value_ = value;
      touch();
}

void vvp_darray_element_ref::get_value(vvp_vector4_t&value)
{
      if (kind_ != ELEM_VEC4 || !valid_) {
            value = vvp_vector4_t(vec4_value_.size(), BIT4_X);
            return;
      }
      if (owner_) owner_->get_word((unsigned)index_, value);
      else value = vec4_value_;
}

void vvp_darray_element_ref::set_value(double value, bool notify)
{
      if (kind_ != ELEM_REAL || !valid_) return;
      if (owner_) {
            owner_->set_word((unsigned)index_, value);
            if (notify) owner_->notify_signal_aliases();
      }
      else real_value_ = value;
      touch();
}

void vvp_darray_element_ref::get_value(double&value)
{
      if (kind_ != ELEM_REAL || !valid_) {
            value = 0.0;
            return;
      }
      if (owner_) owner_->get_word((unsigned)index_, value);
      else value = real_value_;
}

void vvp_darray_element_ref::set_value(const string&value, bool notify)
{
      if (kind_ != ELEM_STRING || !valid_) return;
      if (owner_) {
            owner_->set_word((unsigned)index_, value);
            if (notify) owner_->notify_signal_aliases();
      }
      else string_value_ = value;
      touch();
}

void vvp_darray_element_ref::get_value(string&value)
{
      if (kind_ != ELEM_STRING || !valid_) {
            value.clear();
            return;
      }
      if (owner_) owner_->get_word((unsigned)index_, value);
      else value = string_value_;
}

void vvp_darray_element_ref::set_value(const vvp_object_t&value, bool notify)
{
      if (kind_ != ELEM_OBJECT || !valid_) return;
      if (owner_) {
            owner_->set_word((unsigned)index_, value);
            if (notify) owner_->notify_signal_aliases();
      }
      else object_value_ = value;
      touch();
}

void vvp_darray_element_ref::get_value(vvp_object_t&value)
{
      if (kind_ != ELEM_OBJECT || !valid_) {
            value = vvp_object_t();
            return;
      }
      if (owner_) owner_->get_word((unsigned)index_, value);
      else value = object_value_;
}

vvp_object_t vvp_darray_element_ref::attached_owner() const
{
      return owner_ ? vvp_object_t(owner_) : vvp_object_t();
}

void vvp_darray_element_ref::shallow_copy(const vvp_object*that)
{
      const vvp_darray_element_ref*src =
            dynamic_cast<const vvp_darray_element_ref*>(that);
      assert(src);
      if (src == this) return;
      if (owner_) {
            owner_->unregister_element_ref(this);
            owner_ = 0;
      }

      kind_ = src->kind_;
      valid_ = src->valid_;
      vec4_value_ = vvp_vector4_t(src->vec4_value_.size(), BIT4_X);
      real_value_ = 0.0;
      string_value_.clear();
      object_value_ = vvp_object_t();
      if (!valid_) return;

      vvp_darray_element_ref*mutable_src =
            const_cast<vvp_darray_element_ref*>(src);
      switch (kind_) {
          case ELEM_VEC4: mutable_src->get_value(vec4_value_); break;
          case ELEM_REAL: mutable_src->get_value(real_value_); break;
          case ELEM_STRING: mutable_src->get_value(string_value_); break;
          case ELEM_OBJECT: mutable_src->get_value(object_value_); break;
      }
}

vvp_object*vvp_darray_element_ref::duplicate() const
{
      vvp_darray_element_ref*copy =
            new vvp_darray_element_ref(0, index_, kind_, vec4_value_.size());
      copy->shallow_copy(this);
      return copy;
}

vvp_darray::~vvp_darray()
{
      assert(element_refs_.empty());
}

void vvp_darray::register_element_ref(vvp_darray_element_ref*ref)
{
      assert(ref && ref->is_attached_to(this));
      element_refs_.insert(ref);
}

void vvp_darray::unregister_element_ref(vvp_darray_element_ref*ref)
{
      element_refs_.erase(ref);
}

vvp_object_t vvp_darray::capture_element_ref(size_t idx, unsigned vec4_width)
{
      if (idx < get_size()) {
            for (vvp_darray_element_ref*ref : element_refs_)
                  if (ref->index_ == idx) return vvp_object_t(ref);
      }

      vvp_darray_element_ref::kind_t kind = vvp_darray_element_ref::ELEM_VEC4;
      if (dynamic_cast<vvp_darray_real*>(this)
          || dynamic_cast<vvp_queue_real*>(this))
            kind = vvp_darray_element_ref::ELEM_REAL;
      else if (dynamic_cast<vvp_darray_string*>(this)
               || dynamic_cast<vvp_queue_string*>(this))
            kind = vvp_darray_element_ref::ELEM_STRING;
      else if (dynamic_cast<vvp_darray_object*>(this)
               || dynamic_cast<vvp_queue_object*>(this))
            kind = vvp_darray_element_ref::ELEM_OBJECT;

      return vvp_object_t(new vvp_darray_element_ref(
            idx < get_size() ? this : 0, idx, kind, vec4_width));
}

void vvp_darray::element_refs_detach_all()
{
      while (!element_refs_.empty()) (*element_refs_.begin())->detach();
}

void vvp_darray::element_refs_insert(size_t idx)
{
      for (vvp_darray_element_ref*ref : element_refs_) ref->shift_up(idx);
}

void vvp_darray::element_refs_remove(size_t idx)
{
      vector<vvp_darray_element_ref*> refs(element_refs_.begin(),
                                           element_refs_.end());
      for (vvp_darray_element_ref*ref : refs) {
            if (ref->index_ == idx) ref->detach();
            else ref->shift_down(idx);
      }
}

void vvp_darray::element_refs_remove_tail(size_t idx)
{
      vector<vvp_darray_element_ref*> refs(element_refs_.begin(),
                                           element_refs_.end());
      for (vvp_darray_element_ref*ref : refs)
            if (ref->index_ >= idx) ref->detach();
}

void vvp_darray::element_refs_push_front(bool discard_back)
{
      if (discard_back && get_size()) element_refs_remove(get_size()-1);
      element_refs_insert(0);
}

void vvp_darray::element_refs_pop_back()
{
      if (get_size()) element_refs_remove(get_size()-1);
}

void vvp_darray::element_refs_pop_front()
{
      if (get_size()) element_refs_remove(0);
}

void vvp_darray::reorder_element_refs(
      const vector<size_t>&source_indices)
{
      vector<vvp_darray_element_ref*> refs(element_refs_.begin(),
                                           element_refs_.end());
      for (vvp_darray_element_ref*ref : refs) {
            size_t dst = 0;
            while (dst < source_indices.size()
                   && source_indices[dst] != ref->index_)
                  dst += 1;
            if (dst == source_indices.size()) ref->detach();
            else ref->index_ = dst;
      }
}

static void sync_rand_modes_(const vvp_darray*array,
			     std::vector<unsigned char>&modes,
			     bool default_mode)
{
      modes.resize(array->get_size(), default_mode ? 1 : 0);
}

bool vvp_darray::rand_mode(size_t idx) const
{
      sync_rand_modes_(this, rand_modes_, rand_mode_default_);
      return idx < rand_modes_.size() ? rand_modes_[idx] != 0 : false;
}

bool vvp_darray::rand_mode_any() const
{
      sync_rand_modes_(this, rand_modes_, rand_mode_default_);
      for (unsigned char mode : rand_modes_)
	    if (mode) return true;
      return false;
}

void vvp_darray::set_rand_mode(size_t idx, bool mode)
{
      sync_rand_modes_(this, rand_modes_, rand_mode_default_);
      if (idx < rand_modes_.size()) rand_modes_[idx] = mode ? 1 : 0;
}

void vvp_darray::set_all_rand_mode(bool mode)
{
      rand_mode_default_ = mode;
      rand_modes_.assign(get_size(), mode ? 1 : 0);
}

void vvp_darray::inherit_rand_modes(const vvp_darray&that)
{
      rand_mode_default_ = that.rand_mode_default_;
      sync_rand_modes_(&that, that.rand_modes_, that.rand_mode_default_);
      rand_modes_.assign(get_size(), rand_mode_default_ ? 1 : 0);
      size_t count = std::min(rand_modes_.size(), that.rand_modes_.size());
      for (size_t idx = 0 ; idx < count ; idx += 1)
	    rand_modes_[idx] = that.rand_modes_[idx];
}

const std::vector<bool>*vvp_darray::randc_history(size_t idx) const
{
      if (idx >= get_size() || randc_histories_.empty()) return 0;
      assert(randc_histories_.size() == get_size());
      return &randc_histories_[idx];
}

std::vector<bool>&vvp_darray::randc_history(size_t idx)
{
      if (randc_histories_.empty()) randc_histories_.resize(get_size());
      else assert(randc_histories_.size() == get_size());
      assert(idx < randc_histories_.size());
      return randc_histories_[idx];
}

void vvp_darray::inherit_randc_histories(const vvp_darray&that)
{
      if (that.randc_histories_.empty()) {
	    randc_histories_.clear();
	    return;
      }
      assert(that.randc_histories_.size() == that.get_size());
      randc_histories_.assign(get_size(), std::vector<bool>());
      size_t count = std::min(randc_histories_.size(),
			      that.randc_histories_.size());
      for (size_t idx = 0 ; idx < count ; idx += 1)
	    randc_histories_[idx] = that.randc_histories_[idx];
}

void vvp_darray::reorder_rand_modes(
      const std::vector<size_t>&source_indices)
{
      sync_rand_modes_(this, rand_modes_, rand_mode_default_);
      std::vector<unsigned char> original = rand_modes_;
      std::vector<std::vector<bool> > original_histories;
      if (!randc_histories_.empty()) {
	    assert(randc_histories_.size() == get_size());
	    original_histories = randc_histories_;
      }
      rand_modes_.assign(source_indices.size(),
			 rand_mode_default_ ? 1 : 0);
      if (!original_histories.empty())
	    randc_histories_.assign(source_indices.size(), std::vector<bool>());
      for (size_t dst = 0 ; dst < source_indices.size() ; dst += 1) {
	    size_t src = source_indices[dst];
	    if (src < original.size()) rand_modes_[dst] = original[src];
	    if (src < original_histories.size())
		  randc_histories_[dst] = original_histories[src];
      }
}

void vvp_darray::rand_mode_insert(size_t idx, bool discard_back)
{
      sync_rand_modes_(this, rand_modes_, rand_mode_default_);
      bool have_histories = !randc_histories_.empty();
      if (have_histories) assert(randc_histories_.size() == get_size());
      if (discard_back && !rand_modes_.empty()) {
	    rand_modes_.pop_back();
	    if (have_histories) randc_histories_.pop_back();
      }
      if (idx <= rand_modes_.size())
	    rand_modes_.insert(rand_modes_.begin() + idx,
			       rand_mode_default_ ? 1 : 0);
      if (have_histories && idx <= randc_histories_.size())
	    randc_histories_.insert(randc_histories_.begin() + idx,
				    std::vector<bool>());
}

void vvp_darray::rand_mode_push_back()
{
      sync_rand_modes_(this, rand_modes_, rand_mode_default_);
      bool have_histories = !randc_histories_.empty();
      if (have_histories) assert(randc_histories_.size() == get_size());
      rand_modes_.push_back(rand_mode_default_ ? 1 : 0);
      if (have_histories) randc_histories_.push_back(std::vector<bool>());
}

void vvp_darray::rand_mode_push_front(bool discard_back)
{
      rand_mode_insert(0, discard_back);
}

void vvp_darray::rand_mode_pop_back()
{
      sync_rand_modes_(this, rand_modes_, rand_mode_default_);
      bool have_histories = !randc_histories_.empty();
      if (have_histories) assert(randc_histories_.size() == get_size());
      if (!rand_modes_.empty()) {
	    rand_modes_.pop_back();
	    if (have_histories) randc_histories_.pop_back();
      }
}

void vvp_darray::rand_mode_pop_front()
{
      sync_rand_modes_(this, rand_modes_, rand_mode_default_);
      bool have_histories = !randc_histories_.empty();
      if (have_histories) assert(randc_histories_.size() == get_size());
      if (!rand_modes_.empty()) {
	    rand_modes_.erase(rand_modes_.begin());
	    if (have_histories) randc_histories_.erase(randc_histories_.begin());
      }
}

void vvp_darray::rand_mode_erase(size_t idx)
{
      sync_rand_modes_(this, rand_modes_, rand_mode_default_);
      bool have_histories = !randc_histories_.empty();
      if (have_histories) assert(randc_histories_.size() == get_size());
      if (idx < rand_modes_.size()) {
	    rand_modes_.erase(rand_modes_.begin()+idx);
	    if (have_histories)
		  randc_histories_.erase(randc_histories_.begin()+idx);
      }
}

void vvp_darray::rand_mode_erase_tail(size_t idx)
{
      sync_rand_modes_(this, rand_modes_, rand_mode_default_);
      bool have_histories = !randc_histories_.empty();
      if (have_histories) assert(randc_histories_.size() == get_size());
      if (idx < rand_modes_.size()) {
	    rand_modes_.resize(idx);
	    if (have_histories) randc_histories_.resize(idx);
      }
}

// Type-mismatched set_word/get_word fallback. These methods are
// virtual on vvp_darray and are overridden in concrete subclasses for
// the concrete element type (vec4, double, string, object). Calls
// reaching the base class indicate a code-gen mismatch — typically a
// foreach over a queue-of-objects emitting a vec4 read. Rather than
// spam the log on every hit (which can flood megabytes inside a hot
// loop and stall sim runs), suppress repeats globally and zero-init
// the out parameter so the caller sees a well-defined fallback value.

namespace {
unsigned darray_typemismatch_warn_count = 0;
const unsigned darray_typemismatch_warn_max = 4;

void darray_typemismatch_warn(const char *op, const char *type, const char *cls)
{
      if (darray_typemismatch_warn_count < darray_typemismatch_warn_max) {
            cerr << "Warning: " << op << "(" << type
                 << ") not implemented for " << cls
                 << " (further suppressed; code-gen type mismatch)" << endl;
            ++darray_typemismatch_warn_count;
            if (darray_typemismatch_warn_count == darray_typemismatch_warn_max)
                  cerr << "Warning: further darray type-mismatch warnings suppressed."
                       << endl;
      }
}
} // namespace

void vvp_darray::set_word(unsigned, const vvp_vector4_t&)
{
      darray_typemismatch_warn("set_word", "vvp_vector4_t", typeid(*this).name());
}

void vvp_darray::set_word(unsigned, double)
{
      darray_typemismatch_warn("set_word", "double", typeid(*this).name());
}

void vvp_darray::set_word(unsigned, const string&)
{
      darray_typemismatch_warn("set_word", "string", typeid(*this).name());
}

void vvp_darray::set_word(unsigned, const vvp_object_t&)
{
      darray_typemismatch_warn("set_word", "vvp_object_t", typeid(*this).name());
}

void vvp_darray::get_word(unsigned, vvp_vector4_t&out)
{
      darray_typemismatch_warn("get_word", "vvp_vector4_t", typeid(*this).name());
      out = vvp_vector4_t();
}

void vvp_darray::get_word(unsigned, double&out)
{
      darray_typemismatch_warn("get_word", "double", typeid(*this).name());
      out = 0.0;
}

void vvp_darray::get_word(unsigned, string&out)
{
      darray_typemismatch_warn("get_word", "string", typeid(*this).name());
      out.clear();
}

void vvp_darray::get_word(unsigned, vvp_object_t&out)
{
      darray_typemismatch_warn("get_word", "vvp_object_t", typeid(*this).name());
      out = vvp_object_t();
}

vvp_vector4_t vvp_darray::get_bitstream(bool)
{
      cerr << "XXXX get_bitstream() not implemented for " << typeid(*this).name() << endl;
      return vvp_vector4_t();
}

template <class TYPE> vvp_darray_atom<TYPE>::~vvp_darray_atom()
{
      element_refs_detach_all();
}

template <class TYPE> size_t vvp_darray_atom<TYPE>::get_size() const
{
      return array_.size();
}

template <class TYPE> void vvp_darray_atom<TYPE>::clear()
{
      if (array_.empty()) return;
      element_refs_remove_tail(0);
      rand_mode_erase_tail(0);
      array_.clear();
      touch();
}

template <class TYPE> void vvp_darray_atom<TYPE>::set_word(unsigned adr, const vvp_vector4_t&value)
{
      if (adr >= array_.size())
	    return;
      TYPE tmp;
      vector4_to_value(value, tmp, true, false);
      array_[adr] = tmp;
      touch();
}

template <class TYPE> void vvp_darray_atom<TYPE>::get_word(unsigned adr, vvp_vector4_t&value)
{
      if (adr >= array_.size()) {
	    value = vvp_vector4_t(8*sizeof(TYPE), BIT4_X);
	    return;
      }

      TYPE word = array_[adr];
      vvp_vector4_t tmp (8*sizeof(TYPE), BIT4_0);
      for (unsigned idx = 0 ; idx < tmp.size() ; idx += 1) {
	    if (word&1) tmp.set_bit(idx, BIT4_1);
	    word >>= 1;
      }
      value = tmp;
}

template <class TYPE> void vvp_darray_atom<TYPE>::shallow_copy(const vvp_object*obj)
{
      element_refs_detach_all();
      if (obj == 0) return;
      const vvp_darray_atom<TYPE>*that = dynamic_cast<const vvp_darray_atom<TYPE>*>(obj);
      if (that == 0) {
	      // Cross-flavor copy: `new [n](src)` may initialize this
	      // array from a queue (or another darray flavor). The fork
	      // allocates queue objects eagerly, so even an EMPTY queue
	      // arrives here as a real object rather than nil (upstream
	      // relies on the nil guard in of_SCOPY), and a non-empty
	      // queue is a vvp_queue, never this exact class. Copy
	      // element-wise through the virtual get/set interface
	      // instead of asserting (ivtest sv_darray_copy_empty4).
	    const vvp_darray*src = dynamic_cast<const vvp_darray*>(obj);
	    assert(src);
	    size_t num_items = min(array_.size(), src->get_size());
	    vvp_vector4_t tmp;
	    for (unsigned idx = 0 ; idx < num_items ; idx += 1) {
		  const_cast<vvp_darray*>(src)->get_word(idx, tmp);
		  this->set_word(idx, tmp);
	    }
	    touch();
	    return;
      }

      unsigned num_items = min(array_.size(), that->array_.size());
      for (unsigned idx = 0 ; idx < num_items ; idx += 1)
	    array_[idx] = that->array_[idx];
      touch();
}

template <class TYPE> vvp_object* vvp_darray_atom<TYPE>::duplicate(void) const
{
      vvp_darray_atom<TYPE>*that = new vvp_darray_atom<TYPE>(array_.size());
      for (size_t idx = 0 ; idx < array_.size() ; idx += 1)
	    that->array_[idx] = array_[idx];

      copy_value_metadata_(that);
      return that;
}

template <class TYPE> vvp_vector4_t vvp_darray_atom<TYPE>::get_bitstream(bool)
{
      const unsigned word_wid = sizeof(TYPE) * 8;

      vvp_vector4_t vec(array_.size() * word_wid, BIT4_0);

      unsigned adx = 0;
      unsigned vdx = vec.size();
      while (vdx > 0) {
            TYPE word = array_[adx++];
            vdx -= word_wid;
            for (unsigned bdx = 0; bdx < word_wid; bdx += 1) {
                  if (word & 1)
                        vec.set_bit(vdx+bdx, BIT4_1);
                  word >>= 1;
            }
      }

      return vec;
}

template class vvp_darray_atom<uint8_t>;
template class vvp_darray_atom<uint16_t>;
template class vvp_darray_atom<uint32_t>;
template class vvp_darray_atom<uint64_t>;
template class vvp_darray_atom<int8_t>;
template class vvp_darray_atom<int16_t>;
template class vvp_darray_atom<int32_t>;
template class vvp_darray_atom<int64_t>;

vvp_darray_vec4::~vvp_darray_vec4()
{
      element_refs_detach_all();
}

size_t vvp_darray_vec4::get_size(void) const
{
      return array_.size();
}

void vvp_darray_vec4::clear()
{
      if (array_.empty()) return;
      element_refs_remove_tail(0);
      rand_mode_erase_tail(0);
      array_.clear();
      touch();
}

void vvp_darray_vec4::set_word(unsigned adr, const vvp_vector4_t&value)
{
      if (adr >= array_.size()) return;
      assert(value.size() == word_wid_);
      array_[adr] = value;
      touch();
}

void vvp_darray_vec4::get_word(unsigned adr, vvp_vector4_t&value)
{
	/*
	 * Return an undefined value for an out of range address or if the
	 * value has not been written yet (has a size of zero).
	 */
      if ((adr >= array_.size()) || (array_[adr].size() == 0)) {
	    value = vvp_vector4_t(word_wid_, BIT4_X);
	    return;
      }
      value = array_[adr];
      assert(value.size() == word_wid_);
}

void vvp_darray_vec4::shallow_copy(const vvp_object*obj)
{
      element_refs_detach_all();
      if (obj == 0) return;
      const vvp_darray_vec4*that = dynamic_cast<const vvp_darray_vec4*>(obj);
      if (that == 0) {
	      // Cross-flavor copy: `new [n](src)` may initialize this
	      // array from a queue (or another darray flavor). The fork
	      // allocates queue objects eagerly, so even an EMPTY queue
	      // arrives here as a real object rather than nil (upstream
	      // relies on the nil guard in of_SCOPY), and a non-empty
	      // queue is a vvp_queue, never this exact class. Copy
	      // element-wise through the virtual get/set interface
	      // instead of asserting (ivtest sv_darray_copy_empty4).
	    const vvp_darray*src = dynamic_cast<const vvp_darray*>(obj);
	    assert(src);
	    size_t num_items = min(array_.size(), src->get_size());
	    vvp_vector4_t tmp;
	    for (unsigned idx = 0 ; idx < num_items ; idx += 1) {
		  const_cast<vvp_darray*>(src)->get_word(idx, tmp);
		  this->set_word(idx, tmp);
	    }
	    touch();
	    return;
      }

      unsigned num_items = min(array_.size(), that->array_.size());
      for (unsigned idx = 0 ; idx < num_items ; idx += 1)
	    array_[idx] = that->array_[idx];
      touch();
}

vvp_object* vvp_darray_vec4::duplicate(void) const
{
      vvp_darray_vec4*that = new vvp_darray_vec4(array_.size(), word_wid_);

      for (size_t idx = 0 ; idx < array_.size() ; idx += 1)
	    that->array_[idx] = array_[idx];

      copy_value_metadata_(that);
      return that;
}

vvp_vector4_t vvp_darray_vec4::get_bitstream(bool as_vec4)
{
      vvp_vector4_t vec(array_.size() * word_wid_, BIT4_0);

      unsigned adx = 0;
      unsigned vdx = vec.size();
      while (vdx > 0) {
            vdx -= word_wid_;
            for (unsigned bdx = 0; bdx < word_wid_; bdx += 1) {
                  vvp_bit4_t bit = array_[adx].value(bdx);
                  if (as_vec4 || (bit == BIT4_1))
                        vec.set_bit(vdx+bdx, bit);
            }
            adx++;
      }

      return vec;
}

vvp_darray_vec2::~vvp_darray_vec2()
{
      element_refs_detach_all();
}

size_t vvp_darray_vec2::get_size(void) const
{
      return array_.size();
}

void vvp_darray_vec2::clear()
{
      if (array_.empty()) return;
      element_refs_remove_tail(0);
      rand_mode_erase_tail(0);
      array_.clear();
      touch();
}

void vvp_darray_vec2::set_word(unsigned adr, const vvp_vector4_t&value)
{
      if (adr >= array_.size()) return;
      assert(value.size() == word_wid_);
      array_[adr] = value;
      touch();
}

void vvp_darray_vec2::get_word(unsigned adr, vvp_vector4_t&value)
{
	/*
	 * Return a zero value for an out of range address or if the
	 * value has not been written yet (has a size of zero).
	 */
      if ((adr >= array_.size()) || (array_[adr].size() == 0)) {
	    value = vvp_vector4_t(word_wid_, BIT4_0);
	    return;
      }
      assert(array_[adr].size() == word_wid_);
      value.resize(word_wid_);
      for (unsigned idx = 0; idx < word_wid_; idx += 1) {
	    value.set_bit(idx, array_[adr].value4(idx));
      }
}

void vvp_darray_vec2::shallow_copy(const vvp_object*obj)
{
      element_refs_detach_all();
      if (obj == 0) return;
      const vvp_darray_vec2*that = dynamic_cast<const vvp_darray_vec2*>(obj);
      if (that == 0) {
	      // Cross-flavor copy: `new [n](src)` may initialize this
	      // array from a queue (or another darray flavor). The fork
	      // allocates queue objects eagerly, so even an EMPTY queue
	      // arrives here as a real object rather than nil (upstream
	      // relies on the nil guard in of_SCOPY), and a non-empty
	      // queue is a vvp_queue, never this exact class. Copy
	      // element-wise through the virtual get/set interface
	      // instead of asserting (ivtest sv_darray_copy_empty4).
	    const vvp_darray*src = dynamic_cast<const vvp_darray*>(obj);
	    assert(src);
	    size_t num_items = min(array_.size(), src->get_size());
	    vvp_vector4_t tmp;
	    for (unsigned idx = 0 ; idx < num_items ; idx += 1) {
		  const_cast<vvp_darray*>(src)->get_word(idx, tmp);
		  this->set_word(idx, tmp);
	    }
	    touch();
	    return;
      }

      unsigned num_items = min(array_.size(), that->array_.size());
      for (unsigned idx = 0 ; idx < num_items ; idx += 1)
	    array_[idx] = that->array_[idx];
      touch();
}

vvp_object* vvp_darray_vec2::duplicate(void) const
{
      vvp_darray_vec2*that = new vvp_darray_vec2(array_.size(), word_wid_);

      for (size_t idx = 0 ; idx < array_.size() ; idx += 1)
	    that->array_[idx] = array_[idx];

      copy_value_metadata_(that);
      return that;
}

vvp_vector4_t vvp_darray_vec2::get_bitstream(bool)
{
      vvp_vector4_t vec(array_.size() * word_wid_, BIT4_0);

      unsigned adx = 0;
      unsigned vdx = vec.size();
      while (vdx > 0) {
            vdx -= word_wid_;
            for (unsigned bdx = 0; bdx < word_wid_; bdx += 1) {
                  if (array_[adx].value(bdx))
                        vec.set_bit(vdx+bdx, BIT4_1);
            }
            adx++;
      }

      return vec;
}

vvp_darray_object::~vvp_darray_object()
{
      element_refs_detach_all();
}

size_t vvp_darray_object::get_size() const
{
      return array_.size();
}

void vvp_darray_object::clear()
{
      if (array_.empty()) return;
      element_refs_remove_tail(0);
      rand_mode_erase_tail(0);
      array_.clear();
      touch();
}

void vvp_darray_object::set_word(unsigned adr, const vvp_object_t&value)
{
      if (adr >= array_.size())
	    return;
      array_[adr] = value;
      touch();
}

void vvp_darray_object::get_word(unsigned adr, vvp_object_t&value)
{
      if (adr >= array_.size()) {
	    value = vvp_object_t();
	    return;
      }

      value = array_[adr];
}

void vvp_darray_object::shallow_copy(const vvp_object*obj)
{
      element_refs_detach_all();
      if (obj == 0) return;
      const vvp_darray_object*that = dynamic_cast<const vvp_darray_object*>(obj);
      if (that == 0) {
	      // Cross-flavor copy: `new [n](src)` may initialize this
	      // array from a queue (or another darray flavor). The fork
	      // allocates queue objects eagerly, so even an EMPTY queue
	      // arrives here as a real object rather than nil (upstream
	      // relies on the nil guard in of_SCOPY), and a non-empty
	      // queue is a vvp_queue, never this exact class. Copy
	      // element-wise through the virtual get/set interface
	      // instead of asserting (ivtest sv_darray_copy_empty4).
	    const vvp_darray*src = dynamic_cast<const vvp_darray*>(obj);
	    assert(src);
	    size_t num_items = min(array_.size(), src->get_size());
	    vvp_object_t tmp;
	    for (unsigned idx = 0 ; idx < num_items ; idx += 1) {
		  const_cast<vvp_darray*>(src)->get_word(idx, tmp);
		  this->set_word(idx, tmp.value_copy_element());
	    }
	    if (declared_element_container_layout())
		  rebind_declared_element_container_layout(
			declared_element_container_layout());
	    touch();
	    return;
      }

      unsigned num_items = min(array_.size(), that->array_.size());
      for (unsigned idx = 0 ; idx < num_items ; idx += 1)
	    array_[idx] = that->array_[idx].value_copy_element();
      if (declared_element_container_layout())
	    rebind_declared_element_container_layout(
		  declared_element_container_layout());
      touch();
}

vvp_object* vvp_darray_object::duplicate(void) const
{
      vvp_darray_object*that = new vvp_darray_object(array_.size());

	/* Element policy (recovery D11): container and struct elements
	   copy by value; class handles stay shared. */
      for (size_t idx = 0 ; idx < array_.size() ; idx += 1)
            that->array_[idx] = array_[idx].value_copy_element();

      copy_value_metadata_(that);
      return that;
}

void vvp_darray_object::rebind_declared_element_container_layout(
      const vvp_container_layout_t&element_layout)
{
      for (size_t idx = 0 ; idx < array_.size() ; idx += 1)
	    if (vvp_object*value = array_[idx].peek<vvp_object>())
		  value->set_declared_container_layout(element_layout);
}

vvp_darray_real::~vvp_darray_real()
{
      element_refs_detach_all();
}

size_t vvp_darray_real::get_size() const
{
      return array_.size();
}

void vvp_darray_real::clear()
{
      if (array_.empty()) return;
      element_refs_remove_tail(0);
      rand_mode_erase_tail(0);
      array_.clear();
      touch();
}

void vvp_darray_real::set_word(unsigned adr, double value)
{
      if (adr >= array_.size())
	    return;
      array_[adr] = value;
      touch();
}

void vvp_darray_real::get_word(unsigned adr, double&value)
{
      if (adr >= array_.size()) {
	    value = 0.0;
	    return;
      }

      value = array_[adr];
}

void vvp_darray_real::shallow_copy(const vvp_object*obj)
{
      element_refs_detach_all();
      if (obj == 0) return;
      const vvp_darray_real*that = dynamic_cast<const vvp_darray_real*>(obj);
      if (that == 0) {
	      // Cross-flavor copy: `new [n](src)` may initialize this
	      // array from a queue (or another darray flavor). The fork
	      // allocates queue objects eagerly, so even an EMPTY queue
	      // arrives here as a real object rather than nil (upstream
	      // relies on the nil guard in of_SCOPY), and a non-empty
	      // queue is a vvp_queue, never this exact class. Copy
	      // element-wise through the virtual get/set interface
	      // instead of asserting (ivtest sv_darray_copy_empty4).
	    const vvp_darray*src = dynamic_cast<const vvp_darray*>(obj);
	    assert(src);
	    size_t num_items = min(array_.size(), src->get_size());
	    double tmp = 0.0;
	    for (unsigned idx = 0 ; idx < num_items ; idx += 1) {
		  const_cast<vvp_darray*>(src)->get_word(idx, tmp);
		  this->set_word(idx, tmp);
	    }
	    touch();
	    return;
      }

      unsigned num_items = min(array_.size(), that->array_.size());
      for (unsigned idx = 0 ; idx < num_items ; idx += 1)
	    array_[idx] = that->array_[idx];
      touch();
}

vvp_object* vvp_darray_real::duplicate(void) const
{
      vvp_darray_real*that = new vvp_darray_real(array_.size());

      for (size_t idx = 0 ; idx < array_.size() ; idx += 1)
	    that->array_[idx] = array_[idx];

      copy_value_metadata_(that);
      return that;
}

vvp_vector4_t vvp_darray_real::get_bitstream(bool)
{
      const unsigned word_wid = sizeof(double) * 8;
      assert(word_wid == 64);

      vvp_vector4_t vec(array_.size() * word_wid, BIT4_0);

      unsigned adx = 0;
      unsigned vdx = vec.size();
      while (vdx > 0) {
            union {
                double   value;
                uint64_t bits;
            } word;
            word.value = array_[adx++];
            vdx -= word_wid;
            for (unsigned bdx = 0; bdx < word_wid; bdx += 1) {
                  if (word.bits & 1)
                        vec.set_bit(vdx+bdx, BIT4_1);
                  word.bits >>= 1;
            }
      }

      return vec;
}

vvp_darray_string::~vvp_darray_string()
{
      element_refs_detach_all();
}

size_t vvp_darray_string::get_size() const
{
      return array_.size();
}

void vvp_darray_string::clear()
{
      if (array_.empty()) return;
      element_refs_remove_tail(0);
      rand_mode_erase_tail(0);
      array_.clear();
      touch();
}

void vvp_darray_string::set_word(unsigned adr, const string&value)
{
      if (adr >= array_.size())
	    return;
      array_[adr] = value;
      touch();
}

void vvp_darray_string::get_word(unsigned adr, string&value)
{
      if (adr >= array_.size()) {
	    value = "";
	    return;
      }

      value = array_[adr];
}

void vvp_darray_string::shallow_copy(const vvp_object*obj)
{
      element_refs_detach_all();
      if (obj == 0) return;
      const vvp_darray_string*that = dynamic_cast<const vvp_darray_string*>(obj);
      if (that == 0) {
	      // Cross-flavor copy: `new [n](src)` may initialize this
	      // array from a queue (or another darray flavor). The fork
	      // allocates queue objects eagerly, so even an EMPTY queue
	      // arrives here as a real object rather than nil (upstream
	      // relies on the nil guard in of_SCOPY), and a non-empty
	      // queue is a vvp_queue, never this exact class. Copy
	      // element-wise through the virtual get/set interface
	      // instead of asserting (ivtest sv_darray_copy_empty4).
	    const vvp_darray*src = dynamic_cast<const vvp_darray*>(obj);
	    assert(src);
	    size_t num_items = min(array_.size(), src->get_size());
	    std::string tmp;
	    for (unsigned idx = 0 ; idx < num_items ; idx += 1) {
		  const_cast<vvp_darray*>(src)->get_word(idx, tmp);
		  this->set_word(idx, tmp);
	    }
	    touch();
	    return;
      }

      unsigned num_items = min(array_.size(), that->array_.size());
      for (unsigned idx = 0 ; idx < num_items ; idx += 1)
	    array_[idx] = that->array_[idx];
      touch();
}

vvp_object* vvp_darray_string::duplicate(void) const
{
      vvp_darray_string*that = new vvp_darray_string(array_.size());

      for (size_t idx = 0 ; idx < array_.size() ; idx += 1)
	    that->array_[idx] = array_[idx];

      copy_value_metadata_(that);
      return that;
}

/*
 * Flatten to a bit stream (IEEE 1800-2017 11.4.14.1): elements in
 * index order, element 0 leftmost; each string contributes 8 bits per
 * character, first character leftmost.
 */
vvp_vector4_t vvp_darray_string::get_bitstream(bool)
{
      size_t total_chars = 0;
      for (size_t idx = 0 ; idx < array_.size() ; idx += 1)
	    total_chars += array_[idx].size();

      vvp_vector4_t vec(total_chars * 8, BIT4_0);

      unsigned vdx = vec.size();
      for (size_t idx = 0 ; idx < array_.size() ; idx += 1) {
	    const std::string&str = array_[idx];
	    for (size_t cdx = 0 ; cdx < str.size() ; cdx += 1) {
		  unsigned char ch = (unsigned char)str[cdx];
		  vdx -= 8;
		  for (unsigned bdx = 0 ; bdx < 8 ; bdx += 1) {
			if ((ch >> bdx) & 1)
			      vec.set_bit(vdx + bdx, BIT4_1);
		  }
	    }
      }

      return vec;
}

vvp_queue::~vvp_queue()
{
}

void vvp_queue::apply_declared_container_layout_own(
      const vvp_container_layout_t&layout)
{
      if (!layout || layout->kind != VVP_CONTAINER_QUEUE
	  || !layout->queue_bound_known || layout->queue_max_size == 0)
	    return;

      const uint64_t max_size = layout->queue_max_size;
      if (static_cast<uint64_t>(get_size()) <= max_size)
	    return;
      if (max_size <= UINT_MAX) {
	    erase_tail(static_cast<unsigned>(max_size));
	    return;
      }
      while (static_cast<uint64_t>(get_size()) > max_size)
	    pop_back();
}

void vvp_queue::copy_elems(vvp_object_t, uint64_t)
{
      cerr << "Sorry: copy_elems() not implemented for " << typeid(*this).name() << endl;
}

void vvp_queue::set_word_max(unsigned, const vvp_vector4_t&, uint64_t)
{
      cerr << "XXXX set_word_max(vvp_vector4_t) not implemented for " << typeid(*this).name() << endl;
}

void vvp_queue::insert(unsigned, const vvp_vector4_t&, uint64_t)
{
      cerr << "XXXX insert(vvp_vector4_t) not implemented for " << typeid(*this).name() << endl;
}

void vvp_queue::push_back(const vvp_vector4_t&, uint64_t)
{
      cerr << "XXXX push_back(vvp_vector4_t) not implemented for " << typeid(*this).name() << endl;
}

void vvp_queue::push_front(const vvp_vector4_t&, uint64_t)
{
      cerr << "XXXX push_front(vvp_vector4_t) not implemented for " << typeid(*this).name() << endl;
}

void vvp_queue::set_word_max(unsigned, double, uint64_t)
{
      cerr << "XXXX set_word_max(double) not implemented for " << typeid(*this).name() << endl;
}

void vvp_queue::insert(unsigned, double, uint64_t)
{
      cerr << "XXXX set_word_max(double) not implemented for " << typeid(*this).name() << endl;
}

void vvp_queue::push_back(double, uint64_t)
{
      cerr << "XXXX push_back(double) not implemented for " << typeid(*this).name() << endl;
}

void vvp_queue::push_front(double, uint64_t)
{
      cerr << "XXXX push_front(double) not implemented for " << typeid(*this).name() << endl;
}

void vvp_queue::set_word_max(unsigned, const string&, uint64_t)
{
      cerr << "XXXX set_word_max(string) not implemented for " << typeid(*this).name() << endl;
}

void vvp_queue::insert(unsigned, const string&, uint64_t)
{
      cerr << "XXXX set_word_max(string) not implemented for " << typeid(*this).name() << endl;
}

void vvp_queue::push_back(const string&, uint64_t)
{
      cerr << "XXXX push_back(string) not implemented for " << typeid(*this).name() << endl;
}

void vvp_queue::push_front(const string&, uint64_t)
{
      cerr << "XXXX push_front(string) not implemented for " << typeid(*this).name() << endl;
}

void vvp_queue::set_word_max(unsigned, const vvp_object_t&, uint64_t)
{
      cerr << "XXXX set_word_max(vvp_object_t) not implemented for " << typeid(*this).name() << endl;
}

void vvp_queue::insert(unsigned, const vvp_object_t&, uint64_t)
{
      cerr << "XXXX insert(vvp_object_t) not implemented for " << typeid(*this).name() << endl;
}

void vvp_queue::push_back(const vvp_object_t&, uint64_t)
{
      cerr << "XXXX push_back(vvp_object_t) not implemented for " << typeid(*this).name() << endl;
}

void vvp_queue::push_front(const vvp_object_t&, uint64_t)
{
      cerr << "XXXX push_front(vvp_object_t) not implemented for " << typeid(*this).name() << endl;
}

/*
 * Helper functions used while copying multiple elements into a queue.
 */
static void print_copy_is_too_big(size_t src_size, uint64_t max_size, const string&qtype)
{
      cerr << get_fileline()
           << "Warning: queue<" << qtype << "> is bounded to have at most "
           << max_size << " elements, source has " << src_size << " elements." << endl;
}

static void print_copy_is_too_big(double&, size_t src_size, uint64_t max_size)
{
      print_copy_is_too_big(src_size, max_size, "real");
}

static void print_copy_is_too_big(string&, size_t src_size, uint64_t max_size)
{
      print_copy_is_too_big(src_size, max_size, "string");
}

static void print_copy_is_too_big(vvp_vector4_t&, size_t src_size, uint64_t max_size)
{
      print_copy_is_too_big(src_size, max_size, "vector");
}

static void print_copy_is_too_big(vvp_object_t&, size_t src_size, uint64_t max_size)
{
      print_copy_is_too_big(src_size, max_size, "object");
}

/* Element value policy for whole-container copies (IEEE 1800-2017
   7.9.9/7.6): container and struct elements copy by value; class
   handles stay shared. Only object elements carry a policy. */
static inline void copy_element_value_(vvp_object_t&val)
{
      val = val.value_copy_element();
}
static inline void copy_element_value_(double&) { }
static inline void copy_element_value_(std::string&) { }
static inline void copy_element_value_(vvp_vector4_t&) { }

template <typename ELEM, class QTYPE, class SRC_TYPE>
static void copy_elements(QTYPE*queue, SRC_TYPE*src, uint64_t max_size)
{
      size_t src_size = src->get_size();
      if ((max_size != 0) && (src_size > max_size)) {
	    ELEM tmp;
	    print_copy_is_too_big(tmp, src_size, max_size);
      }
      size_t copy_size = ((max_size == 0)
			  || static_cast<uint64_t>(src_size) < max_size)
	    ? src_size : static_cast<size_t>(max_size);
      if (copy_size < queue->get_size())
	    queue->erase_tail(copy_size);
      for (size_t idx=0; idx < copy_size; ++idx) {
	    ELEM value;
	    src->get_word(static_cast<unsigned>(idx), value);
	    copy_element_value_(value);
	    queue->set_word_max(static_cast<unsigned>(idx), value, max_size);
      }
}

vvp_queue_real::~vvp_queue_real()
{
      element_refs_detach_all();
}

void vvp_queue_real::copy_elems(vvp_object_t src, uint64_t max_size)
{
      element_refs_detach_all();
      if (vvp_queue*src_queue = src.peek<vvp_queue>())
	    copy_elements<double, vvp_queue_real, vvp_queue>(this, src_queue, max_size);
      else if (vvp_darray*src_darray = src.peek<vvp_darray>())
	    copy_elements<double, vvp_queue_real, vvp_darray>(this, src_darray, max_size);
      else
	    cerr << get_fileline() << "Sorry: cannot copy object to real queue." << endl;
}

vvp_object* vvp_queue_real::duplicate(void) const
{
      vvp_queue_real*that = new vvp_queue_real;
      that->queue = queue;
      copy_value_metadata_(that);
      return that;
}

void vvp_queue_real::set_word_max(unsigned adr, double value, uint64_t max_size)
{
      if (adr == queue.size())
	    if (!max_size || (queue.size() < max_size))
		  rand_mode_push_back(), queue.push_back(value), touch();
	    else
		  cerr << get_fileline()
		       << "Warning: assigning to queue<real>[" << adr << "] is"
		          " outside bound (" << max_size << "). " << value
		       << " was not added." << endl;
      else
	    set_word(adr, value);
}

void vvp_queue_real::set_word(unsigned adr, double value)
{
      if (adr < queue.size())
	    queue[adr] = value, touch();
      else
	    cerr << get_fileline()
	         << "Warning: assigning to queue<real>[" << adr << "] is outside "
	            "of size (" << queue.size() << "). " << value
	         << " was not added." << endl;
}

void vvp_queue_real::get_word(unsigned adr, double&value)
{
      if (adr >= queue.size())
	    value = 0.0;
      else
	    value = queue[adr];
}

void vvp_queue_real::insert(unsigned idx, double value, uint64_t max_size)
{
	// Inserting past the end of the queue
      if (idx > queue.size())
	    cerr << get_fileline()
	         << "Warning: inserting to queue<real>[" << idx << "] is "
	            "outside of size (" << queue.size() << "). " << value
	         << " was not added." << endl;
	// Inserting at the end
      else if (idx == queue.size())
	    if (!max_size || (queue.size() < max_size))
		  rand_mode_push_back(), queue.push_back(value), touch();
	    else
		  cerr << get_fileline()
		       << "Warning: inserting to queue<real>[" << idx << "] is"
		          " outside bound (" << max_size << "). " << value
		       << " was not added." << endl;
      else  {
	    if (max_size && (queue.size() == max_size)) {
		  cerr << get_fileline()
		       << "Warning: insert("<< idx << ", " << value << ") removed "
		       << queue.back() << " from already full bounded queue<real> ["
		       << max_size << "]." << endl;
		  element_refs_pop_back();
		  queue.pop_back();
	    }
	    element_refs_insert(idx);
	    rand_mode_insert(idx);
	    queue.insert(queue.begin()+idx, value);
            touch();
      }
}

void vvp_queue_real::push_back(double value, uint64_t max_size)
{
      if (!max_size || (queue.size() < max_size))
	    rand_mode_push_back(), queue.push_back(value), touch();
      else
	    cerr << get_fileline()
	         << "Warning: push_back(" << value
	         << ") skipped for already full bounded queue<real> ["
	         << max_size << "]." << endl;
}

void vvp_queue_real::push_front(double value, uint64_t max_size)
{
      if (max_size && (queue.size() == max_size)) {
	    cerr << get_fileline()
	         << "Warning: push_front(" << value << ") removed "
	         << queue.back() << " from already full bounded queue<real> ["
	         << max_size << "]." << endl;
	    element_refs_pop_back();
	    queue.pop_back();
      }
      element_refs_insert(0);
      rand_mode_push_front();
      queue.push_front(value);
      touch();
}

void vvp_queue_real::erase(unsigned idx)
{
      assert(queue.size() > idx);
      element_refs_remove(idx);
      rand_mode_erase(idx);
      queue.erase(queue.begin()+idx);
      touch();
}

void vvp_queue_real::erase_tail(unsigned idx)
{
      assert(queue.size() >= idx);
      if (queue.size() > idx) {
            element_refs_remove_tail(idx);
	    rand_mode_erase_tail(idx), queue.resize(idx), touch();
      }
}

vvp_queue_string::~vvp_queue_string()
{
      element_refs_detach_all();
}

void vvp_queue_string::copy_elems(vvp_object_t src, uint64_t max_size)
{
      element_refs_detach_all();
      if (vvp_queue*src_queue = src.peek<vvp_queue>())
	    copy_elements<string, vvp_queue_string, vvp_queue>(this, src_queue, max_size);
      else if (vvp_darray*src_darray = src.peek<vvp_darray>())
	    copy_elements<string, vvp_queue_string, vvp_darray>(this, src_darray, max_size);
      else
	    cerr << get_fileline() << "Sorry: cannot copy object to string queue." << endl;
}

vvp_object* vvp_queue_string::duplicate(void) const
{
      vvp_queue_string*that = new vvp_queue_string;
      that->queue = queue;
      copy_value_metadata_(that);
      return that;
}

void vvp_queue_string::set_word_max(unsigned adr, const string&value, uint64_t max_size)
{
      if (adr == queue.size())
	    if (!max_size || (queue.size() < max_size))
		  rand_mode_push_back(), queue.push_back(value), touch();
	    else
		  cerr << get_fileline()
		       << "Warning: assigning to queue<string>[" << adr << "] is"
		          " outside bound (" << max_size << "). \"" << value
		       << "\" was not added." << endl;
      else
	    set_word(adr, value);
}

void vvp_queue_string::set_word(unsigned adr, const string&value)
{
      if (adr < queue.size())
	    queue[adr] = value, touch();
      else
	    cerr << get_fileline()
	         << "Warning: assigning to queue<string>[" << adr << "] is outside "
	            "of size (" << queue.size() << "). \"" << value
	         << "\" was not added." << endl;
}

void vvp_queue_string::get_word(unsigned adr, string&value)
{
      if (adr >= queue.size())
	    value = "";
      else
	    value = queue[adr];
}

void vvp_queue_string::insert(unsigned idx, const string&value, uint64_t max_size)
{
	// Inserting past the end of the queue
      if (idx > queue.size())
	    cerr << get_fileline()
	         << "Warning: inserting to queue<string>[" << idx << "] is "
	            "outside of size (" << queue.size() << "). \"" << value
	         << "\" was not added." << endl;
	// Inserting at the end
      else if (idx == queue.size())
	    if (!max_size || (queue.size() < max_size))
		  rand_mode_push_back(), queue.push_back(value), touch();
	    else
		  cerr << get_fileline()
		       << "Warning: inserting to queue<string>[" << idx << "] is"
		          " outside bound (" << max_size << "). \"" << value
		       << "\" was not added." << endl;
      else  {
	    if (max_size && (queue.size() == max_size)) {
		  cerr << get_fileline()
		       << "Warning: insert("<< idx << ", \"" << value << "\") removed \""
		       << queue.back() << "\" from already full bounded queue<string> ["
		       << max_size << "]." << endl;
		  element_refs_pop_back();
		  queue.pop_back();
	    }
	    element_refs_insert(idx);
	    rand_mode_insert(idx);
	    queue.insert(queue.begin()+idx, value);
            touch();
      }
}

void vvp_queue_string::push_back(const string&value, uint64_t max_size)
{
      if (!max_size || (queue.size() < max_size))
	    rand_mode_push_back(), queue.push_back(value), touch();
      else
	    cerr << get_fileline()
	         << "Warning: push_back(\"" << value
	         << "\") skipped for already full bounded queue<string> ["
	         << max_size << "]." << endl;
}

void vvp_queue_string::push_front(const string&value, uint64_t max_size)
{
      if (max_size && (queue.size() == max_size)) {
	    cerr << get_fileline()
	         << "Warning: push_front(\"" << value << "\") removed \""
	         << queue.back() << "\" from already full bounded queue<string> ["
	         << max_size << "]." << endl;
	    element_refs_pop_back();
	    queue.pop_back();
      }
      element_refs_insert(0);
      rand_mode_push_front();
      queue.push_front(value);
      touch();
}

void vvp_queue_string::erase(unsigned idx)
{
      assert(queue.size() > idx);
      element_refs_remove(idx);
      rand_mode_erase(idx);
      queue.erase(queue.begin()+idx);
      touch();
}

void vvp_queue_string::erase_tail(unsigned idx)
{
      assert(queue.size() >= idx);
      if (queue.size() > idx) {
            element_refs_remove_tail(idx);
	    rand_mode_erase_tail(idx), queue.resize(idx), touch();
      }
}

vvp_vector4_t vvp_queue_string::get_bitstream(bool)
{
      size_t total_chars = 0;
      for (size_t idx = 0 ; idx < queue.size() ; idx += 1)
	    total_chars += queue[idx].size();

      vvp_vector4_t vec(total_chars * 8, BIT4_0);

      unsigned vdx = vec.size();
      for (size_t idx = 0 ; idx < queue.size() ; idx += 1) {
	    const std::string&str = queue[idx];
	    for (size_t cdx = 0 ; cdx < str.size() ; cdx += 1) {
		  unsigned char ch = (unsigned char)str[cdx];
		  vdx -= 8;
		  for (unsigned bdx = 0 ; bdx < 8 ; bdx += 1) {
			if ((ch >> bdx) & 1)
			      vec.set_bit(vdx + bdx, BIT4_1);
		  }
	    }
      }

      return vec;
}

vvp_queue_vec4::~vvp_queue_vec4()
{
      element_refs_detach_all();
}

void vvp_queue_vec4::copy_elems(vvp_object_t src, uint64_t max_size)
{
      element_refs_detach_all();
      if (vvp_queue*src_queue = src.peek<vvp_queue>())
	    copy_elements<vvp_vector4_t, vvp_queue_vec4, vvp_queue>(this, src_queue, max_size);
      else if (vvp_darray*src_darray = src.peek<vvp_darray>())
	    copy_elements<vvp_vector4_t, vvp_queue_vec4, vvp_darray>(this, src_darray, max_size);
      else
	    cerr << get_fileline() << "Sorry: cannot copy object to vector queue." << endl;
}

vvp_object* vvp_queue_vec4::duplicate(void) const
{
      vvp_queue_vec4*that = new vvp_queue_vec4;
      that->queue = queue;
      copy_value_metadata_(that);
      return that;
}

void vvp_queue_vec4::set_word_max(unsigned adr, const vvp_vector4_t&value, uint64_t max_size)
{
      if (adr == queue.size())
	    if (!max_size || (queue.size() < max_size))
		  rand_mode_push_back(), queue.push_back(value), touch();
	    else
		  cerr << get_fileline()
		       << "Warning: assigning to queue<vector>[" << adr << "] is"
		          " outside bound (" << max_size << "). " << value
		       << " was not added." << endl;
      else
	    set_word(adr, value);
}

void vvp_queue_vec4::set_word(unsigned adr, const vvp_vector4_t&value)
{
      if (adr < queue.size())
	    queue[adr] = value, touch();
      else
	    cerr << get_fileline()
	         << "Warning: assigning to queue<vector>[" << adr << "] is outside "
	            "of size (" << queue.size() << "). " << value
	         << " was not added." << endl;
}

void vvp_queue_vec4::get_word(unsigned adr, vvp_vector4_t&value)
{
      if (adr >= queue.size())
	    value = vvp_vector4_t(queue[0].size());
      else
	    value = queue[adr];
}

void vvp_queue_vec4::insert(unsigned idx, const vvp_vector4_t&value, uint64_t max_size)
{
	// Inserting past the end of the queue
      if (idx > queue.size())
	    cerr << get_fileline()
	         << "Warning: inserting to queue<vector[" << value.size()
	         << "]>[" << idx << "] is outside of size (" << queue.size()
	         << "). " << value << " was not added." << endl;
	// Inserting at the end
      else if (idx == queue.size())
	    if (!max_size || (queue.size() < max_size))
		  rand_mode_push_back(), queue.push_back(value), touch();
	    else
		  cerr << get_fileline()
		       << "Warning: inserting to queue<vector[" << value.size()
		       << "]>[" << idx << "] is outside bound (" << max_size
		       << "). " << value << " was not added." << endl;
      else  {
	    if (max_size && (queue.size() == max_size)) {
		  cerr << get_fileline()
		       << "Warning: insert("<< idx << ", " << value << ") removed "
		       << queue.back() << " from already full bounded queue<vector["
		       << value.size() << "]> [" << max_size << "]." << endl;
		  element_refs_pop_back();
		  queue.pop_back();
	    }
	    element_refs_insert(idx);
	    rand_mode_insert(idx);
	    queue.insert(queue.begin()+idx, value);
            touch();
      }
}

void vvp_queue_vec4::push_back(const vvp_vector4_t&value, uint64_t max_size)
{
      if (!max_size || (queue.size() < max_size))
	    rand_mode_push_back(), queue.push_back(value), touch();
      else
	    cerr << get_fileline()
	         << "Warning: push_back(" << value
	         << ") skipped for already full bounded queue<vector["
	         << value.size() << "]> [" << max_size << "]." << endl;
}

void vvp_queue_vec4::push_front(const vvp_vector4_t&value, uint64_t max_size)
{
      if (max_size && (queue.size() == max_size)) {
	    cerr << get_fileline()
	         << "Warning: push_front(" << value << ") removed "
	         << queue.back() << " from already full bounded queue<vector["
	         << value.size() << "]> [" << max_size << "]." << endl;
	    element_refs_pop_back();
	    queue.pop_back();
      }
      element_refs_insert(0);
      rand_mode_push_front();
      queue.push_front(value);
      touch();
}

void vvp_queue_vec4::erase(unsigned idx)
{
      assert(queue.size() > idx);
      element_refs_remove(idx);
      rand_mode_erase(idx);
      queue.erase(queue.begin()+idx);
      touch();
}

void vvp_queue_vec4::erase_tail(unsigned idx)
{
      assert(queue.size() >= idx);
      if (queue.size() > idx) {
            element_refs_remove_tail(idx);
	    rand_mode_erase_tail(idx), queue.resize(idx), touch();
      }
}

/*
 * Flatten to a bit stream (IEEE 1800-2017 11.4.14.1): elements in
 * index order, element 0 leftmost.  Element widths are taken from the
 * stored vectors (uniform in practice).
 */
vvp_vector4_t vvp_queue_vec4::get_bitstream(bool as_vec4)
{
      size_t total_bits = 0;
      for (size_t idx = 0 ; idx < queue.size() ; idx += 1)
	    total_bits += queue[idx].size();

      vvp_vector4_t vec(total_bits, BIT4_0);

      unsigned vdx = vec.size();
      for (size_t idx = 0 ; idx < queue.size() ; idx += 1) {
	    const vvp_vector4_t&word = queue[idx];
	    vdx -= word.size();
	    for (unsigned bdx = 0 ; bdx < word.size() ; bdx += 1) {
		  vvp_bit4_t bit = word.value(bdx);
		  if (as_vec4 || (bit == BIT4_1))
			vec.set_bit(vdx + bdx, bit);
	    }
      }

      return vec;
}

vvp_queue_object::~vvp_queue_object()
{
      element_refs_detach_all();
}

void vvp_queue_object::copy_elems(vvp_object_t src, uint64_t max_size)
{
      element_refs_detach_all();
      if (vvp_queue*src_queue = src.peek<vvp_queue>())
	    copy_elements<vvp_object_t, vvp_queue_object, vvp_queue>(this, src_queue, max_size);
      else if (vvp_darray*src_darray = src.peek<vvp_darray>())
	    copy_elements<vvp_object_t, vvp_queue_object, vvp_darray>(this, src_darray, max_size);
      else
	    cerr << get_fileline() << "Sorry: cannot copy object to object queue." << endl;
}

vvp_object* vvp_queue_object::duplicate(void) const
{
      vvp_queue_object*that = new vvp_queue_object;
	/* Element policy (recovery D11): container and struct elements
	   copy by value; class handles stay shared. */
      that->queue.resize(queue.size());
      for (size_t idx = 0 ; idx < queue.size() ; idx += 1)
	    that->queue[idx] = queue[idx].value_copy_element();
      copy_value_metadata_(that);
      return that;
}

void vvp_queue_object::rebind_declared_element_container_layout(
      const vvp_container_layout_t&element_layout)
{
      for (size_t idx = 0 ; idx < queue.size() ; idx += 1)
	    if (vvp_object*value = queue[idx].peek<vvp_object>())
		  value->set_declared_container_layout(element_layout);
}

void vvp_queue_object::set_word_max(unsigned adr, const vvp_object_t&value, uint64_t max_size)
{
      if (adr == queue.size())
	    if (!max_size || (queue.size() < max_size))
		  rand_mode_push_back(), queue.push_back(value), touch();
	    else
		  cerr << get_fileline()
		       << "Warning: assigning to queue<object>[" << adr << "] is"
		          " outside bound (" << max_size << "). Object was not added."
		       << endl;
      else
	    set_word(adr, value);
}

void vvp_queue_object::set_word(unsigned adr, const vvp_object_t&value)
{
      if (adr < queue.size()) {
	    queue[adr] = value;
            touch();
	    return;
      }

      if (adr == queue.size()) {
	    rand_mode_push_back();
	    queue.push_back(value);
            touch();
	    return;
      }

      // Compile-progress fallback: permit sparse queue<object> indexed stores
      // by growing and null-filling intermediate elements.
      while (queue.size() < adr + 1) rand_mode_push_back();
      queue.resize(adr+1);
      queue[adr] = value;
      touch();
}

void vvp_queue_object::get_word(unsigned adr, vvp_object_t&value)
{
      if (adr >= queue.size())
	    value = vvp_object_t();
      else
	    value = queue[adr];
}

void vvp_queue_object::insert(unsigned idx, const vvp_object_t&value, uint64_t max_size)
{
      if (idx > queue.size()) {
	    cerr << get_fileline()
	         << "Warning: inserting to queue<object>[" << idx << "] is "
	            "outside of size (" << queue.size()
	         << "). Object was not added." << endl;
      } else if (idx == queue.size()) {
	    if (!max_size || (queue.size() < max_size))
		  rand_mode_push_back(), queue.push_back(value), touch();
	    else
		  cerr << get_fileline()
		       << "Warning: inserting to queue<object>[" << idx << "] is"
		          " outside bound (" << max_size
		       << "). Object was not added." << endl;
      } else {
	    if (max_size && (queue.size() == max_size)) {
		  cerr << get_fileline()
		       << "Warning: insert(" << idx << ", <object>) removed tail"
		          " from already full bounded queue<object> ["
		       << max_size << "]." << endl;
		  element_refs_pop_back();
		  queue.pop_back();
	    }
	    element_refs_insert(idx);
	    rand_mode_insert(idx);
	    queue.insert(queue.begin()+idx, value);
            touch();
      }
}

void vvp_queue_object::push_back(const vvp_object_t&value, uint64_t max_size)
{
      if (!max_size || (queue.size() < max_size))
	    rand_mode_push_back(), queue.push_back(value), touch();
      else
	    cerr << get_fileline()
	         << "Warning: push_back(<object>) skipped for already full bounded"
	            " queue<object> [" << max_size << "]." << endl;
}

void vvp_queue_object::push_front(const vvp_object_t&value, uint64_t max_size)
{
      if (max_size && (queue.size() == max_size)) {
	    cerr << get_fileline()
	         << "Warning: push_front(<object>) removed tail from already full"
	            " bounded queue<object> [" << max_size << "]." << endl;
	    element_refs_pop_back();
	    queue.pop_back();
      }
      element_refs_insert(0);
      rand_mode_push_front();
      queue.push_front(value);
      touch();
}

void vvp_queue_object::erase(unsigned idx)
{
      assert(queue.size() > idx);
      element_refs_remove(idx);
      rand_mode_erase(idx);
      queue.erase(queue.begin()+idx);
      touch();
}

void vvp_queue_object::erase_tail(unsigned idx)
{
      assert(queue.size() >= idx);
      if (queue.size() > idx) {
            element_refs_remove_tail(idx);
	    rand_mode_erase_tail(idx), queue.resize(idx), touch();
      }
}
