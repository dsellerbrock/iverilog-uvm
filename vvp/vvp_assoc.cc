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
