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

# include  "vvp_assoc.h"

vvp_assoc_base::~vvp_assoc_base()
{
      assert(element_refs_.empty());
}

vvp_assoc_element_ref::vvp_assoc_element_ref(
      vvp_assoc_base*owner, const std::string&key, kind_t kind,
      unsigned vec4_width)
: owner_(owner), key_kind_(KEY_STRING), kind_(kind), valid_(owner != 0),
  string_key_(key), vec4_value_(vec4_width, BIT4_X), real_value_(0.0)
{
      if (owner_) owner_->register_element_ref_(this);
}

vvp_assoc_element_ref::vvp_assoc_element_ref(
      vvp_assoc_base*owner, const vvp_object_t&key, kind_t kind,
      unsigned vec4_width)
: owner_(owner), key_kind_(KEY_OBJECT), kind_(kind), valid_(owner != 0),
  object_key_(key), vec4_value_(vec4_width, BIT4_X), real_value_(0.0)
{
      if (owner_) owner_->register_element_ref_(this);
}

vvp_assoc_element_ref::vvp_assoc_element_ref(
      vvp_assoc_base*owner, const vvp_vector4_t&key, kind_t kind,
      unsigned vec4_width)
: owner_(owner), key_kind_(KEY_VEC4), kind_(kind), valid_(owner != 0),
  vec4_key_(key), vec4_value_(vec4_width, BIT4_X), real_value_(0.0)
{
      if (owner_) owner_->register_element_ref_(this);
}

vvp_assoc_element_ref::~vvp_assoc_element_ref()
{
      if (owner_) owner_->unregister_element_ref_(this);
}

bool vvp_assoc_element_ref::matches(const std::string&key) const
{
      return key_kind_ == KEY_STRING && string_key_ == key;
}

bool vvp_assoc_element_ref::matches(const vvp_object_t&key) const
{
      return key_kind_ == KEY_OBJECT
          && object_key_.peek<vvp_object>() == key.peek<vvp_object>();
}

bool vvp_assoc_element_ref::matches(const vvp_vector4_t&key) const
{
      return key_kind_ == KEY_VEC4 && vec4_key_.size() == key.size()
          && vec4_key_.eeq(key);
}

template <class ASSOC, class VALUE>
static bool assoc_ref_get_(vvp_assoc_base*owner, int key_kind,
                           const std::string&string_key,
                           const vvp_object_t&object_key,
                           const vvp_vector4_t&vec4_key, VALUE&value)
{
      ASSOC*assoc = dynamic_cast<ASSOC*>(owner);
      if (!assoc) return false;
      switch (key_kind) {
          case 0: return assoc->get(string_key, value);
          case 1: return assoc->get(object_key, value);
          case 2: return assoc->get(vec4_key, value);
          default: return false;
      }
}

template <class ASSOC, class VALUE>
static bool assoc_ref_set_(vvp_assoc_base*owner, int key_kind,
                           const std::string&string_key,
                           const vvp_object_t&object_key,
                           const vvp_vector4_t&vec4_key, const VALUE&value)
{
      ASSOC*assoc = dynamic_cast<ASSOC*>(owner);
      if (!assoc) return false;
      switch (key_kind) {
          case 0: assoc->set(string_key, value); break;
          case 1: assoc->set(object_key, value); break;
          case 2: assoc->set(vec4_key, value); break;
          default: return false;
      }
      return true;
}

void vvp_assoc_element_ref::set_value(const vvp_vector4_t&value, bool notify)
{
      if (kind_ != ELEM_VEC4 || !valid_) return;
      if (!owner_ || !assoc_ref_set_<vvp_assoc_vec4>(
                         owner_, key_kind_, string_key_, object_key_,
                         vec4_key_, value))
            vec4_value_ = value;
      if (owner_) {
            owner_->touch();
            if (notify) owner_->notify_signal_aliases();
      }
      touch();
}

void vvp_assoc_element_ref::get_value(vvp_vector4_t&value)
{
      if (kind_ != ELEM_VEC4 || !valid_) {
            value = vvp_vector4_t(vec4_value_.size(), BIT4_X);
            return;
      }
      value = vec4_value_;
      if (owner_)
            assoc_ref_get_<vvp_assoc_vec4>(owner_, key_kind_, string_key_,
                                           object_key_, vec4_key_, value);
}

void vvp_assoc_element_ref::set_value(double value, bool notify)
{
      if (kind_ != ELEM_REAL || !valid_) return;
      if (!owner_ || !assoc_ref_set_<vvp_assoc_real>(
                         owner_, key_kind_, string_key_, object_key_,
                         vec4_key_, value))
            real_value_ = value;
      if (owner_) {
            owner_->touch();
            if (notify) owner_->notify_signal_aliases();
      }
      touch();
}

void vvp_assoc_element_ref::get_value(double&value)
{
      if (kind_ != ELEM_REAL || !valid_) {
            value = 0.0;
            return;
      }
      value = real_value_;
      if (owner_)
            assoc_ref_get_<vvp_assoc_real>(owner_, key_kind_, string_key_,
                                           object_key_, vec4_key_, value);
}

void vvp_assoc_element_ref::set_value(const std::string&value, bool notify)
{
      if (kind_ != ELEM_STRING || !valid_) return;
      if (!owner_ || !assoc_ref_set_<vvp_assoc_string>(
                         owner_, key_kind_, string_key_, object_key_,
                         vec4_key_, value))
            string_value_ = value;
      if (owner_) {
            owner_->touch();
            if (notify) owner_->notify_signal_aliases();
      }
      touch();
}

void vvp_assoc_element_ref::get_value(std::string&value)
{
      if (kind_ != ELEM_STRING || !valid_) {
            value.clear();
            return;
      }
      value = string_value_;
      if (owner_)
            assoc_ref_get_<vvp_assoc_string>(owner_, key_kind_, string_key_,
                                             object_key_, vec4_key_, value);
}

void vvp_assoc_element_ref::set_value(const vvp_object_t&value, bool notify)
{
      if (kind_ != ELEM_OBJECT || !valid_) return;
      if (!owner_ || !assoc_ref_set_<vvp_assoc_object>(
                         owner_, key_kind_, string_key_, object_key_,
                         vec4_key_, value))
            object_value_ = value;
      if (owner_) {
            owner_->touch();
            if (notify) owner_->notify_signal_aliases();
      }
      touch();
}

void vvp_assoc_element_ref::get_value(vvp_object_t&value)
{
      if (kind_ != ELEM_OBJECT || !valid_) {
            value = vvp_object_t();
            return;
      }
      value = object_value_;
      if (owner_)
            assoc_ref_get_<vvp_assoc_object>(owner_, key_kind_, string_key_,
                                             object_key_, vec4_key_, value);
}

vvp_object_t vvp_assoc_element_ref::attached_owner() const
{
      return owner_ ? vvp_object_t(owner_) : vvp_object_t();
}

void vvp_assoc_element_ref::detach()
{
      if (!owner_) return;

      vvp_assoc_base*old_owner = owner_;
      switch (kind_) {
          case ELEM_VEC4: get_value(vec4_value_); break;
          case ELEM_REAL: get_value(real_value_); break;
          case ELEM_STRING: get_value(string_value_); break;
          case ELEM_OBJECT: get_value(object_value_); break;
      }
      owner_ = 0;
      old_owner->unregister_element_ref_(this);
      valid_ = true;
}

void vvp_assoc_element_ref::shallow_copy(const vvp_object*that)
{
      const vvp_assoc_element_ref*src =
            dynamic_cast<const vvp_assoc_element_ref*>(that);
      assert(src);
      if (src == this) return;
      if (owner_) {
            owner_->unregister_element_ref_(this);
            owner_ = 0;
      }

      key_kind_ = src->key_kind_;
      kind_ = src->kind_;
      valid_ = src->valid_;
      string_key_ = src->string_key_;
      object_key_ = src->object_key_;
      vec4_key_ = src->vec4_key_;
      vec4_value_ = vvp_vector4_t(src->vec4_value_.size(), BIT4_X);
      real_value_ = 0.0;
      string_value_.clear();
      object_value_ = vvp_object_t();
      if (!valid_) return;

      vvp_assoc_element_ref*mutable_src =
            const_cast<vvp_assoc_element_ref*>(src);
      switch (kind_) {
          case ELEM_VEC4: mutable_src->get_value(vec4_value_); break;
          case ELEM_REAL: mutable_src->get_value(real_value_); break;
          case ELEM_STRING: mutable_src->get_value(string_value_); break;
          case ELEM_OBJECT: mutable_src->get_value(object_value_); break;
      }
}

vvp_object*vvp_assoc_element_ref::duplicate() const
{
      vvp_assoc_element_ref*copy = new vvp_assoc_element_ref(
            0, std::string(), kind_, vec4_value_.size());
      copy->shallow_copy(this);
      return copy;
}

void vvp_assoc_base::register_element_ref_(vvp_assoc_element_ref*ref)
{
      assert(ref && ref->owner_ == this);
      element_refs_.insert(ref);
}

void vvp_assoc_base::unregister_element_ref_(vvp_assoc_element_ref*ref)
{
      element_refs_.erase(ref);
}

void vvp_assoc_base::element_refs_detach_all_()
{
      while (!element_refs_.empty()) (*element_refs_.begin())->detach();
}

void vvp_assoc_base::element_refs_remove_(const std::string&key)
{
      std::vector<vvp_assoc_element_ref*> selected;
      for (vvp_assoc_element_ref*ref : element_refs_)
            if (ref->matches(key)) selected.push_back(ref);
      for (vvp_assoc_element_ref*ref : selected) ref->detach();
}

void vvp_assoc_base::element_refs_remove_(const vvp_object_t&key)
{
      std::vector<vvp_assoc_element_ref*> selected;
      for (vvp_assoc_element_ref*ref : element_refs_)
            if (ref->matches(key)) selected.push_back(ref);
      for (vvp_assoc_element_ref*ref : selected) ref->detach();
}

void vvp_assoc_base::element_refs_remove_(const vvp_vector4_t&key)
{
      std::vector<vvp_assoc_element_ref*> selected;
      for (vvp_assoc_element_ref*ref : element_refs_)
            if (ref->matches(key)) selected.push_back(ref);
      for (vvp_assoc_element_ref*ref : selected) ref->detach();
}

vvp_object_t vvp_assoc_base::capture_element_ref(
      const std::string&key, vvp_assoc_element_ref::kind_t kind,
      unsigned width)
{
      for (vvp_assoc_element_ref*ref : element_refs_)
            if (ref->matches(key)) return vvp_object_t(ref);
      return vvp_object_t(new vvp_assoc_element_ref(this, key, kind, width));
}

vvp_object_t vvp_assoc_base::capture_element_ref(
      const vvp_object_t&key, vvp_assoc_element_ref::kind_t kind,
      unsigned width)
{
      for (vvp_assoc_element_ref*ref : element_refs_)
            if (ref->matches(key)) return vvp_object_t(ref);
      return vvp_object_t(new vvp_assoc_element_ref(this, key, kind, width));
}

vvp_object_t vvp_assoc_base::capture_element_ref(
      const vvp_vector4_t&key, vvp_assoc_element_ref::kind_t kind,
      unsigned width)
{
      for (vvp_assoc_element_ref*ref : element_refs_)
            if (ref->matches(key)) return vvp_object_t(ref);
      return vvp_object_t(new vvp_assoc_element_ref(this, key, kind, width));
}

const vvp_object* vvp_assoc_base::object_key_(const vvp_object_t&key)
{
      return key.peek<vvp_object>();
}

std::string vvp_assoc_base::vec4_key_(const vvp_vector4_t&key)
{
      unsigned wid = key.size();
      std::string out;
      out.resize(4 + wid);
      out[0] = static_cast<char>((wid >> 24) & 0xff);
      out[1] = static_cast<char>((wid >> 16) & 0xff);
      out[2] = static_cast<char>((wid >> 8) & 0xff);
      out[3] = static_cast<char>(wid & 0xff);
      for (unsigned idx = 0 ; idx < wid ; idx += 1)
	    out[4 + idx] = vvp_bit4_to_ascii(key.value(wid - idx - 1));
      return out;
}

bool vvp_assoc_base::rand_mode(const std::string&key) const
{
      if (!exists_key(key)) return false;
      std::map<std::string, bool>::const_iterator it = rand_mode_str_.find(key);
      return it == rand_mode_str_.end() ? rand_mode_default_ : it->second;
}

bool vvp_assoc_base::rand_mode(const vvp_object_t&key) const
{
      if (!exists_key(key)) return false;
      const vvp_object*raw = object_key_(key);
      std::map<const vvp_object*, bool>::const_iterator it =
	    rand_mode_obj_.find(raw);
      return it == rand_mode_obj_.end() ? rand_mode_default_ : it->second;
}

bool vvp_assoc_base::rand_mode(const vvp_vector4_t&key) const
{
      if (!exists_key(key)) return false;
      std::string canon = vec4_key_(key);
      std::map<std::string, bool>::const_iterator it = rand_mode_vec_.find(canon);
      return it == rand_mode_vec_.end() ? rand_mode_default_ : it->second;
}

bool vvp_assoc_base::rand_mode_at(size_t position) const
{
      size_t current = 0;
      std::string skey;
      for (bool ok = first_key(skey); ok; ok = next_key(skey)) {
	    if (current++ == position) return rand_mode(skey);
      }
      vvp_object_t okey;
      for (bool ok = first_key(okey); ok; ok = next_key(okey)) {
	    if (current++ == position) return rand_mode(okey);
      }
      vvp_vector4_t vkey;
      for (bool ok = first_key(vkey); ok; ok = next_key(vkey)) {
	    if (current++ == position) return rand_mode(vkey);
      }
      return false;
}

bool vvp_assoc_base::rand_mode_any() const
{
      std::string skey;
      for (bool ok = first_key(skey); ok; ok = next_key(skey))
	    if (rand_mode(skey)) return true;
      vvp_object_t okey;
      for (bool ok = first_key(okey); ok; ok = next_key(okey))
	    if (rand_mode(okey)) return true;
      vvp_vector4_t vkey;
      for (bool ok = first_key(vkey); ok; ok = next_key(vkey))
	    if (rand_mode(vkey)) return true;
      return false;
}

void vvp_assoc_base::set_rand_mode(const std::string&key, bool mode)
{
      if (!exists_key(key)) return;
      if (mode == rand_mode_default_) rand_mode_str_.erase(key);
      else rand_mode_str_[key] = mode;
}

void vvp_assoc_base::set_rand_mode(const vvp_object_t&key, bool mode)
{
      if (!exists_key(key)) return;
      const vvp_object*raw = object_key_(key);
      if (mode == rand_mode_default_) rand_mode_obj_.erase(raw);
      else rand_mode_obj_[raw] = mode;
}

void vvp_assoc_base::set_rand_mode(const vvp_vector4_t&key, bool mode)
{
      if (!exists_key(key)) return;
      std::string canon = vec4_key_(key);
      if (mode == rand_mode_default_) rand_mode_vec_.erase(canon);
      else rand_mode_vec_[canon] = mode;
}

void vvp_assoc_base::set_all_rand_mode(bool mode)
{
      rand_mode_default_ = mode;
      clear_rand_modes_();
}

void vvp_assoc_base::inherit_rand_modes(const vvp_assoc_base&that)
{
      rand_mode_default_ = that.rand_mode_default_;
      rand_mode_str_ = that.rand_mode_str_;
      rand_mode_obj_ = that.rand_mode_obj_;
      rand_mode_vec_ = that.rand_mode_vec_;
}

const std::vector<bool>*vvp_assoc_base::randc_history(
	    const std::string&key) const
{
      if (!exists_key(key)) return 0;
      std::map<std::string, std::vector<bool> >::const_iterator it =
	    randc_history_str_.find(key);
      return it == randc_history_str_.end() ? 0 : &it->second;
}

const std::vector<bool>*vvp_assoc_base::randc_history(
	    const vvp_object_t&key) const
{
      if (!exists_key(key)) return 0;
      std::map<const vvp_object*, std::vector<bool> >::const_iterator it =
	    randc_history_obj_.find(object_key_(key));
      return it == randc_history_obj_.end() ? 0 : &it->second;
}

const std::vector<bool>*vvp_assoc_base::randc_history(
	    const vvp_vector4_t&key) const
{
      if (!exists_key(key)) return 0;
      std::map<std::string, std::vector<bool> >::const_iterator it =
	    randc_history_vec_.find(vec4_key_(key));
      return it == randc_history_vec_.end() ? 0 : &it->second;
}

std::vector<bool>&vvp_assoc_base::randc_history(const std::string&key)
{
      assert(exists_key(key));
      return randc_history_str_[key];
}

std::vector<bool>&vvp_assoc_base::randc_history(const vvp_object_t&key)
{
      assert(exists_key(key));
      return randc_history_obj_[object_key_(key)];
}

std::vector<bool>&vvp_assoc_base::randc_history(const vvp_vector4_t&key)
{
      assert(exists_key(key));
      return randc_history_vec_[vec4_key_(key)];
}

const std::vector<bool>*vvp_assoc_base::randc_history_at(
	    size_t position) const
{
      size_t current = 0;
      std::string skey;
      for (bool ok = first_key(skey); ok; ok = next_key(skey))
	    if (current++ == position) return randc_history(skey);
      vvp_object_t okey;
      for (bool ok = first_key(okey); ok; ok = next_key(okey))
	    if (current++ == position) return randc_history(okey);
      vvp_vector4_t vkey;
      for (bool ok = first_key(vkey); ok; ok = next_key(vkey))
	    if (current++ == position) return randc_history(vkey);
      return 0;
}

std::vector<bool>&vvp_assoc_base::randc_history_at(size_t position)
{
      size_t current = 0;
      std::string skey;
      for (bool ok = first_key(skey); ok; ok = next_key(skey))
	    if (current++ == position) return randc_history(skey);
      vvp_object_t okey;
      for (bool ok = first_key(okey); ok; ok = next_key(okey))
	    if (current++ == position) return randc_history(okey);
      vvp_vector4_t vkey;
      for (bool ok = first_key(vkey); ok; ok = next_key(vkey))
	    if (current++ == position) return randc_history(vkey);
      assert(0);
      return randc_history_str_[std::string()];
}

void vvp_assoc_base::inherit_randc_histories(const vvp_assoc_base&that)
{
      randc_history_str_ = that.randc_history_str_;
      randc_history_obj_ = that.randc_history_obj_;
      randc_history_vec_ = that.randc_history_vec_;
}

void vvp_assoc_base::erase_rand_mode_(const std::string&key)
{
      rand_mode_str_.erase(key);
}

void vvp_assoc_base::erase_randc_history_(const std::string&key)
{
      randc_history_str_.erase(key);
}

void vvp_assoc_base::erase_randc_history_(const vvp_object_t&key)
{
      randc_history_obj_.erase(object_key_(key));
}

void vvp_assoc_base::erase_randc_history_(const vvp_vector4_t&key)
{
      randc_history_vec_.erase(vec4_key_(key));
}

void vvp_assoc_base::erase_rand_mode_(const vvp_object_t&key)
{
      rand_mode_obj_.erase(object_key_(key));
}

void vvp_assoc_base::erase_rand_mode_(const vvp_vector4_t&key)
{
      rand_mode_vec_.erase(vec4_key_(key));
}

void vvp_assoc_base::clear_rand_modes_()
{
      rand_mode_str_.clear();
      rand_mode_obj_.clear();
      rand_mode_vec_.clear();
}

void vvp_assoc_base::clear_randc_histories_()
{
      randc_history_str_.clear();
      randc_history_obj_.clear();
      randc_history_vec_.clear();
}
