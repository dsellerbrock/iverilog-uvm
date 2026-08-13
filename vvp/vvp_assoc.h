#ifndef IVL_vvp_assoc_H
#define IVL_vvp_assoc_H
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

# include  <map>
# include  <iterator>
# include  <cassert>
# include  <string>
# include  <vector>
# include  "vvp_net.h"
# include  "vvp_object.h"

// Render a vector value as a decimal string (defined in vpip_to_dec.cc,
// declared in vpi_priv.h). Forward-declared here so peek_entry can produce
// a printable key_text for vector-keyed associative arrays without pulling
// in the whole VPI-private header.
extern unsigned vpip_vec4_to_dec_str(const vvp_vector4_t&vec4,
				     char *buf, unsigned int nbuf,
				     int signed_flag);

class vvp_assoc_base : public vvp_object {
    public:
      ~vvp_assoc_base() override;

      virtual size_t size() const =0;
      virtual bool exists_key(const std::string&key) const =0;
      virtual bool exists_key(const vvp_object_t&key) const =0;
      virtual bool exists_key(const vvp_vector4_t&key) const =0;
      virtual bool first_key(std::string&key) const =0;
      virtual bool first_key(vvp_object_t&key) const =0;
      virtual bool first_key(vvp_vector4_t&key,
                             bool signed_order = false) const =0;
      virtual bool last_key(std::string&key) const =0;
      virtual bool last_key(vvp_object_t&key) const =0;
      virtual bool last_key(vvp_vector4_t&key,
                            bool signed_order = false) const =0;
      virtual bool next_key(std::string&key) const =0;
      virtual bool next_key(vvp_object_t&key) const =0;
      virtual bool next_key(vvp_vector4_t&key,
                            bool signed_order = false) const =0;
      virtual bool prev_key(std::string&key) const =0;
      virtual bool prev_key(vvp_object_t&key) const =0;
      virtual bool prev_key(vvp_vector4_t&key,
                            bool signed_order = false) const =0;
      virtual void erase_key(const std::string&key) =0;
      virtual void erase_key(const vvp_object_t&key) =0;
      virtual void erase_key(const vvp_vector4_t&key) =0;

	// IEEE 1800-2017 7.9.2: aa.delete() with no arguments removes
	// ALL entries. No single-key primitive can express this; the
	// %aa/delete/all opcode calls it.
      virtual void clear() =0;

	// M12 VPI: positional element peek in key order (string keys
	// first, then object keys, then vector keys — the same order
	// size() sums them).  key_text receives a printable form of
	// the key; val_kind receives 0=vec4, 1=real, 2=string,
	// 3=object.  Returns false when pos is out of range.
      virtual bool peek_entry(size_t pos, std::string&key_text,
			      vvp_vector4_t&val_vec, double&val_real,
			      std::string&val_str, int&val_kind) const =0;

	// M12-4 VPI: positional element WRITE, the mirror of
	// peek_entry (same key order, same val_kind tags). The entry
	// keeps its key; only the value changes, and only when
	// val_kind matches the map's value type (a vec4 write into a
	// vec4 map is resized to the stored entry's width). Returns
	// false when pos is out of range or the kind does not match
	// (object values are not writable through value puts).
      virtual bool poke_entry(size_t pos, const vvp_vector4_t&val_vec,
			      double val_real, const std::string&val_str,
			      int val_kind) =0;

	// IEEE 1800-2017 18.8 per-element mode state. Overrides are keyed by
	// the same typed key identity as the associative array and are removed
	// with the entry, so delete/reinsert creates a fresh active variable.
      bool rand_mode(const std::string&key) const;
      bool rand_mode(const vvp_object_t&key) const;
      bool rand_mode(const vvp_vector4_t&key) const;
      bool rand_mode_at(size_t position) const;
      bool rand_mode_any() const;
      void set_rand_mode(const std::string&key, bool mode);
      void set_rand_mode(const vvp_object_t&key, bool mode);
      void set_rand_mode(const vvp_vector4_t&key, bool mode);
      void set_all_rand_mode(bool mode);
      void inherit_rand_modes(const vvp_assoc_base&that);

	// Per-key randc history uses the associative array's typed key identity.
	// Deleting a key removes its cycle, while copies and canonical static
	// aliases preserve it with the value.
      const std::vector<bool>*randc_history(const std::string&key) const;
      const std::vector<bool>*randc_history(const vvp_object_t&key) const;
      const std::vector<bool>*randc_history(const vvp_vector4_t&key) const;
      const std::vector<bool>*randc_history_at(size_t position) const;
      std::vector<bool>&randc_history(const std::string&key);
      std::vector<bool>&randc_history(const vvp_object_t&key);
      std::vector<bool>&randc_history(const vvp_vector4_t&key);
      std::vector<bool>&randc_history_at(size_t position);
      void inherit_randc_histories(const vvp_assoc_base&that);

    protected:
      static const vvp_object* object_key_(const vvp_object_t&key);
      static std::string vec4_key_(const vvp_vector4_t&key);
      void erase_rand_mode_(const std::string&key);
      void erase_rand_mode_(const vvp_object_t&key);
      void erase_rand_mode_(const vvp_vector4_t&key);
      void clear_rand_modes_();
      void erase_randc_history_(const std::string&key);
      void erase_randc_history_(const vvp_object_t&key);
      void erase_randc_history_(const vvp_vector4_t&key);
      void clear_randc_histories_();

    private:
      bool rand_mode_default_ = true;
      std::map<std::string, bool> rand_mode_str_;
      std::map<const vvp_object*, bool> rand_mode_obj_;
      std::map<std::string, bool> rand_mode_vec_;
      std::map<std::string, std::vector<bool> > randc_history_str_;
      std::map<const vvp_object*, std::vector<bool> > randc_history_obj_;
      std::map<std::string, std::vector<bool> > randc_history_vec_;
};

/* An associative-array value and its per-element random modes are copied by
 * value, including when its element is itself a queue, dynamic array,
 * associative array, or synthetic unpacked
 * struct. Class objects remain handles. Keep the policy identical to other
 * object-backed containers instead of copying every vvp_object_t verbatim. */
template <class TYPE>
static inline TYPE assoc_value_copy_element_(const TYPE&value)
{
      return value;
}

static inline vvp_object_t
assoc_value_copy_element_(const vvp_object_t&value)
{
      return value.value_copy_element();
}

template <class TYPE> class vvp_assoc_map : public vvp_assoc_base {
    public:
      inline vvp_assoc_map() : has_default_(false), default_value_() { }
      ~vvp_assoc_map() override { }

      size_t size() const override
      { return str_map_.size() + obj_map_.size() + vec_map_.size(); }
      void clear() override
      {
            clear_rand_modes_();
            clear_randc_histories_();
            str_map_.clear();
            obj_map_.clear();
            obj_key_refs_.clear();
            vec_map_.clear();
      }
      bool exists_key(const std::string&key) const override
      { return str_map_.find(key) != str_map_.end(); }
      bool exists_key(const vvp_object_t&key) const override
      { return obj_map_.find(object_key_(key)) != obj_map_.end(); }
      bool exists_key(const vvp_vector4_t&key) const override
      { return vec_map_.find(vec4_key_(key)) != vec_map_.end(); }
      bool first_key(std::string&key) const override
      { return first_key_(str_map_, key); }
      bool first_key(vvp_object_t&key) const override
      { return first_key_(obj_map_, key); }
      bool first_key(vvp_vector4_t&key,
                     bool signed_order = false) const override
      { return first_key_(vec_map_, key, signed_order); }
      bool last_key(std::string&key) const override
      { return last_key_(str_map_, key); }
      bool last_key(vvp_object_t&key) const override
      { return last_key_(obj_map_, key); }
      bool last_key(vvp_vector4_t&key,
                    bool signed_order = false) const override
      { return last_key_(vec_map_, key, signed_order); }
      bool next_key(std::string&key) const override
      { return next_key_(str_map_, key); }
      bool next_key(vvp_object_t&key) const override
      { return next_key_(obj_map_, key); }
      bool next_key(vvp_vector4_t&key,
                    bool signed_order = false) const override
      { return next_key_(vec_map_, key, signed_order); }
      bool prev_key(std::string&key) const override
      { return prev_key_(str_map_, key); }
      bool prev_key(vvp_object_t&key) const override
      { return prev_key_(obj_map_, key); }
      bool prev_key(vvp_vector4_t&key,
                    bool signed_order = false) const override
      { return prev_key_(vec_map_, key, signed_order); }
      void erase_key(const std::string&key) override
      {
            erase_rand_mode_(key);
            erase_randc_history_(key);
            str_map_.erase(key);
      }
      void erase_key(const vvp_object_t&key) override
      {
            const vvp_object*raw_key = object_key_(key);
            erase_rand_mode_(key);
            erase_randc_history_(key);
            obj_map_.erase(raw_key);
            obj_key_refs_.erase(raw_key);
      }
      void erase_key(const vvp_vector4_t&key) override
      {
            erase_rand_mode_(key);
            erase_randc_history_(key);
            vec_map_.erase(vec4_key_(key));
      }

      void set(const std::string&key, const TYPE&value)
      { str_map_[key] = value; }
      void set(const vvp_object_t&key, const TYPE&value)
      {
            const vvp_object*raw_key = object_key_(key);
            obj_key_refs_[raw_key] = key;
            obj_map_[raw_key] = value;
      }
      void set(const vvp_vector4_t&key, const TYPE&value)
      {
            vec_entry_t&entry = vec_map_[vec4_key_(key)];
            entry.key = key;
            entry.value = value;
      }

	// IEEE 1800-2017 7.9.11: assigning `'{default: value}' to an
	// associative array replaces the complete array value. Existing entries
	// disappear, while the supplied value becomes the fallback for subsequent
	// reads of absent keys. The fallback is deliberately not represented in
	// any key map, so size/exists/traversal remain entry-only operations.
      void replace_default(const TYPE&value)
      {
            clear();
            default_value_ = value;
            has_default_ = true;
      }

      bool get(const std::string&key, TYPE&value) const
      {
            typename std::map<std::string, TYPE>::const_iterator cur = str_map_.find(key);
            if (cur == str_map_.end()) {
                  if (has_default_)
                        value = default_value_;
                  else
                        return false;
            } else {
                  value = cur->second;
            }
            return true;
      }

      bool get(const vvp_object_t&key, TYPE&value) const
      {
            typename std::map<const vvp_object*, TYPE>::const_iterator cur = obj_map_.find(object_key_(key));
            if (cur == obj_map_.end()) {
                  if (has_default_)
                        value = default_value_;
                  else
                        return false;
            } else {
                  value = cur->second;
            }
            return true;
      }

      bool get(const vvp_vector4_t&key, TYPE&value) const
      {
            typename std::map<std::string, vec_entry_t>::const_iterator cur = vec_map_.find(vec4_key_(key));
            if (cur == vec_map_.end()) {
                  if (has_default_)
                        value = default_value_;
                  else
                        return false;
            } else {
                  value = cur->second.value;
            }
            return true;
      }

      void shallow_copy(const vvp_object*obj) override
      {
            const vvp_assoc_map<TYPE>*that = dynamic_cast<const vvp_assoc_map<TYPE>*>(obj);
            assert(that);
            if (that == this)
                  return;
            copy_from_(*that);
            inherit_rand_modes(*that);
            inherit_randc_histories(*that);
            touch();
      }

      vvp_object* duplicate(void) const override
      {
            vvp_assoc_map<TYPE>*that = new vvp_assoc_map<TYPE>();
            that->copy_from_(*this);
            that->inherit_rand_modes(*this);
            that->inherit_randc_histories(*this);
            return that;
      }

    private:
      struct vec_entry_t {
            vvp_vector4_t key;
            TYPE value;
      };

      void copy_from_(const vvp_assoc_map<TYPE>&that)
      {
            str_map_ = that.str_map_;
            for (typename std::map<std::string, TYPE>::iterator cur =
                       str_map_.begin(); cur != str_map_.end(); ++cur)
                  cur->second = assoc_value_copy_element_(cur->second);

            obj_map_ = that.obj_map_;
            obj_key_refs_ = that.obj_key_refs_;
            for (typename std::map<const vvp_object*, TYPE>::iterator cur =
                       obj_map_.begin(); cur != obj_map_.end(); ++cur)
                  cur->second = assoc_value_copy_element_(cur->second);

            vec_map_ = that.vec_map_;
            for (typename std::map<std::string, vec_entry_t>::iterator cur =
                       vec_map_.begin(); cur != vec_map_.end(); ++cur)
                  cur->second.value =
                        assoc_value_copy_element_(cur->second.value);

            has_default_ = that.has_default_;
            default_value_ = assoc_value_copy_element_(that.default_value_);
      }

      static void assign_key_(std::string&dst, const std::string&src)
      { dst = src; }

      static void assign_key_(vvp_object_t&dst, const vvp_object*src)
      { dst = const_cast<vvp_object*>(src); }

      static void assign_key_(vvp_vector4_t&dst, const vec_entry_t&src)
      { dst = src.key; }

      template <class MAP, class KEY>
      static bool first_key_(const MAP&map, KEY&key)
      {
            if (map.empty())
                  return false;
            assign_key_(key, map.begin()->first);
            return true;
      }

      static int compare_vec_keys_(const vvp_vector4_t&lhs,
                                   const vvp_vector4_t&rhs,
                                   bool signed_order)
      {
            const unsigned lhs_wid = lhs.size();
            const unsigned rhs_wid = rhs.size();
            const bool lhs_negative = signed_order && lhs_wid
                  && lhs.value(lhs_wid-1) == BIT4_1;
            const bool rhs_negative = signed_order && rhs_wid
                  && rhs.value(rhs_wid-1) == BIT4_1;

              // A signed two's-complement value with its sign bit set sorts
              // before every non-negative value. Within each sign half the
              // ordinary most-significant-bit-first order is already numeric.
            if (lhs_negative != rhs_negative)
                  return lhs_negative ? -1 : 1;

            const unsigned wid = lhs_wid > rhs_wid ? lhs_wid : rhs_wid;
            for (unsigned pos = wid ; pos > 0 ; pos -= 1) {
                  const unsigned bit = pos - 1;
                  const vvp_bit4_t lhs_bit = bit < lhs_wid
                        ? lhs.value(bit)
                        : (lhs_negative ? BIT4_1 : BIT4_0);
                  const vvp_bit4_t rhs_bit = bit < rhs_wid
                        ? rhs.value(bit)
                        : (rhs_negative ? BIT4_1 : BIT4_0);
                  if (lhs_bit == rhs_bit)
                        continue;

                    // Integral keys normally contain only 0/1. Retain a
                    // deterministic total order for X/Z keys as well, matching
                    // the existing raw-key alphabet instead of treating two
                    // distinct keys as equal.
                  const char lhs_code = vvp_bit4_to_ascii(lhs_bit);
                  const char rhs_code = vvp_bit4_to_ascii(rhs_bit);
                  return lhs_code < rhs_code ? -1 : 1;
            }

              // Width is part of associative-key identity. If sign/zero
              // extension makes two differently sized keys numerically equal,
              // use the existing raw encoding only as a stable tie-breaker.
            const std::string lhs_raw = vec4_key_(lhs);
            const std::string rhs_raw = vec4_key_(rhs);
            if (lhs_raw == rhs_raw)
                  return 0;
            return lhs_raw < rhs_raw ? -1 : 1;
      }

      static bool first_key_(const std::map<std::string, vec_entry_t>&map,
                             vvp_vector4_t&key, bool signed_order)
      {
            if (map.empty())
                  return false;
            typename std::map<std::string, vec_entry_t>::const_iterator best =
                  map.begin();
            for (typename std::map<std::string, vec_entry_t>::const_iterator cur =
                       map.begin(); cur != map.end(); ++cur)
                  if (compare_vec_keys_(cur->second.key, best->second.key,
                                        signed_order) < 0)
                        best = cur;
            assign_key_(key, best->second);
            return true;
      }

      template <class MAP, class KEY>
      static bool last_key_(const MAP&map, KEY&key)
      {
            if (map.empty())
                  return false;
            typename MAP::const_iterator cur = map.end();
            --cur;
            assign_key_(key, cur->first);
            return true;
      }

      static bool last_key_(const std::map<std::string, vec_entry_t>&map,
                            vvp_vector4_t&key, bool signed_order)
      {
            if (map.empty())
                  return false;
            typename std::map<std::string, vec_entry_t>::const_iterator best =
                  map.begin();
            for (typename std::map<std::string, vec_entry_t>::const_iterator cur =
                       map.begin(); cur != map.end(); ++cur)
                  if (compare_vec_keys_(cur->second.key, best->second.key,
                                        signed_order) > 0)
                        best = cur;
            assign_key_(key, best->second);
            return true;
      }

      static bool next_key_(const std::map<std::string, TYPE>&map, std::string&key)
      {
            typename std::map<std::string, TYPE>::const_iterator cur = map.upper_bound(key);
            if (cur == map.end())
                  return false;
            key = cur->first;
            return true;
      }

      static bool next_key_(const std::map<const vvp_object*, TYPE>&map, vvp_object_t&key)
      {
            typename std::map<const vvp_object*, TYPE>::const_iterator cur =
                  map.upper_bound(object_key_(key));
            if (cur == map.end())
                  return false;
            assign_key_(key, cur->first);
            return true;
      }

      static bool next_key_(const std::map<std::string, vec_entry_t>&map,
                            vvp_vector4_t&key, bool signed_order)
      {
            typename std::map<std::string, vec_entry_t>::const_iterator best =
                  map.end();
            for (typename std::map<std::string, vec_entry_t>::const_iterator cur =
                       map.begin(); cur != map.end(); ++cur) {
                  if (compare_vec_keys_(cur->second.key, key, signed_order) <= 0)
                        continue;
                  if (best == map.end()
                      || compare_vec_keys_(cur->second.key, best->second.key,
                                           signed_order) < 0)
                        best = cur;
            }
            if (best == map.end())
                  return false;
            assign_key_(key, best->second);
            return true;
      }

      static bool prev_key_(const std::map<std::string, TYPE>&map, std::string&key)
      {
            typename std::map<std::string, TYPE>::const_iterator cur = map.lower_bound(key);
            if (cur == map.begin())
                  return false;
            if (cur == map.end() || cur->first >= key)
                  --cur;
            key = cur->first;
            return true;
      }

      static bool prev_key_(const std::map<const vvp_object*, TYPE>&map, vvp_object_t&key)
      {
            const vvp_object*raw_key = object_key_(key);
            typename std::map<const vvp_object*, TYPE>::const_iterator cur = map.lower_bound(raw_key);
            if (cur == map.begin())
                  return false;
            if (cur == map.end() || !(cur->first < raw_key))
                  --cur;
            assign_key_(key, cur->first);
            return true;
      }

      static bool prev_key_(const std::map<std::string, vec_entry_t>&map,
                            vvp_vector4_t&key, bool signed_order)
      {
            typename std::map<std::string, vec_entry_t>::const_iterator best =
                  map.end();
            for (typename std::map<std::string, vec_entry_t>::const_iterator cur =
                       map.begin(); cur != map.end(); ++cur) {
                  if (compare_vec_keys_(cur->second.key, key, signed_order) >= 0)
                        continue;
                  if (best == map.end()
                      || compare_vec_keys_(cur->second.key, best->second.key,
                                           signed_order) > 0)
                        best = cur;
            }
            if (best == map.end())
                  return false;
            assign_key_(key, best->second);
            return true;
      }

      bool peek_entry(size_t pos, std::string&key_text,
		      vvp_vector4_t&val_vec, double&val_real,
		      std::string&val_str, int&val_kind) const override
      {
	    if (pos < str_map_.size()) {
		  typename std::map<std::string, TYPE>::const_iterator cur
			= str_map_.begin();
		  std::advance(cur, pos);
		  key_text = cur->first;
		  val_kind = assign_entry_val_(cur->second, val_vec,
					       val_real, val_str);
		  return true;
	    }
	    pos -= str_map_.size();
	    if (pos < obj_map_.size()) {
		  typename std::map<const vvp_object*, TYPE>::const_iterator cur
			= obj_map_.begin();
		  std::advance(cur, pos);
		  key_text = "<object>";
		  val_kind = assign_entry_val_(cur->second, val_vec,
					       val_real, val_str);
		  return true;
	    }
	    pos -= obj_map_.size();
	    if (pos < vec_map_.size()) {
		  typename std::map<std::string, vec_entry_t>::const_iterator cur
			= vec_map_.begin();
		  std::advance(cur, pos);
		    // cur->first is the internal raw-byte lookup key; the
		    // caller wants a printable form, so render the stored key
		    // vector as decimal.
		  char kbuf[128];
		  vpip_vec4_to_dec_str(cur->second.key, kbuf, sizeof kbuf, 0);
		  key_text = kbuf;
		  val_kind = assign_entry_val_(cur->second.value, val_vec,
					       val_real, val_str);
		  return true;
	    }
	    return false;
      }

      bool poke_entry(size_t pos, const vvp_vector4_t&val_vec,
		      double val_real, const std::string&val_str,
		      int val_kind) override
      {
	    if (pos < str_map_.size()) {
		  typename std::map<std::string, TYPE>::iterator cur
			= str_map_.begin();
		  std::advance(cur, pos);
		  return update_entry_val_(cur->second, val_vec,
					   val_real, val_str, val_kind);
	    }
	    pos -= str_map_.size();
	    if (pos < obj_map_.size()) {
		  typename std::map<const vvp_object*, TYPE>::iterator cur
			= obj_map_.begin();
		  std::advance(cur, pos);
		  return update_entry_val_(cur->second, val_vec,
					   val_real, val_str, val_kind);
	    }
	    pos -= obj_map_.size();
	    if (pos < vec_map_.size()) {
		  typename std::map<std::string, vec_entry_t>::iterator cur
			= vec_map_.begin();
		  std::advance(cur, pos);
		  return update_entry_val_(cur->second.value, val_vec,
					   val_real, val_str, val_kind);
	    }
	    return false;
      }

    private:
	// Overload set routing the stored value into the right VPI
	// payload slot; returns the val_kind tag.
      static int assign_entry_val_(const vvp_vector4_t&src2, vvp_vector4_t&vv,
				   double&, std::string&)
      { vv = src2; return 0; }
      static int assign_entry_val_(const double&src2, vvp_vector4_t&,
				   double&rv, std::string&)
      { rv = src2; return 1; }
      static int assign_entry_val_(const std::string&src2, vvp_vector4_t&,
				   double&, std::string&sv)
      { sv = src2; return 2; }
      static int assign_entry_val_(const vvp_object_t&, vvp_vector4_t&,
				   double&, std::string&)
      { return 3; }

	// M12-4: overload set routing a VPI put into the stored value
	// (mirrors assign_entry_val_). A vec4 store is resized to the
	// existing entry's width so a 32-bit vpiIntVal put cannot
	// widen an 8-bit element.
      static bool update_entry_val_(vvp_vector4_t&dst, const vvp_vector4_t&vv,
				    double, const std::string&, int kind)
      {
	    if (kind != 0) return false;
	    if (dst.size() > 0 && vv.size() != dst.size()) {
		  vvp_vector4_t sized (dst.size(), BIT4_0);
		  for (unsigned b = 0 ; b < dst.size() && b < vv.size() ; b += 1)
			sized.set_bit(b, vv.value(b));
		  dst = sized;
	    } else {
		  dst = vv;
	    }
	    return true;
      }
      static bool update_entry_val_(double&dst, const vvp_vector4_t&,
				    double rv, const std::string&, int kind)
      { if (kind != 1) return false; dst = rv; return true; }
      static bool update_entry_val_(std::string&dst, const vvp_vector4_t&,
				    double, const std::string&sv, int kind)
      { if (kind != 2) return false; dst = sv; return true; }
      static bool update_entry_val_(vvp_object_t&, const vvp_vector4_t&,
				    double, const std::string&, int)
      { return false; }

    protected:
      bool has_default_;
      TYPE default_value_;
      std::map<std::string, TYPE> str_map_;
      // Object identity and ordering use the raw pointer, while this parallel
      // map owns one handle for every live key. Without the retained handle an
      // automatic key can be destroyed and its address reused, aliasing an
      // unrelated later key in obj_map_.
      std::map<const vvp_object*, TYPE> obj_map_;
      std::map<const vvp_object*, vvp_object_t> obj_key_refs_;
      std::map<std::string, vec_entry_t> vec_map_;
};

typedef vvp_assoc_map<double> vvp_assoc_real;
typedef vvp_assoc_map<std::string> vvp_assoc_string;
typedef vvp_assoc_map<vvp_vector4_t> vvp_assoc_vec4;
typedef vvp_assoc_map<vvp_object_t> vvp_assoc_object;

#endif /* IVL_vvp_assoc_H */
