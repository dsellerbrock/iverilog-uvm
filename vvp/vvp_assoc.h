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
# include  <cassert>
# include  <string>
# include  "vvp_net.h"
# include  "vvp_object.h"

class vvp_assoc_base : public vvp_object {
    public:
      ~vvp_assoc_base() override;

      virtual size_t size() const =0;
      virtual bool exists_key(const std::string&key) const =0;
      virtual bool exists_key(const vvp_object_t&key) const =0;
      virtual bool exists_key(const vvp_vector4_t&key) const =0;
      virtual bool first_key(std::string&key) const =0;
      virtual bool first_key(vvp_object_t&key) const =0;
      virtual bool first_key(vvp_vector4_t&key) const =0;
      virtual bool last_key(std::string&key) const =0;
      virtual bool last_key(vvp_object_t&key) const =0;
      virtual bool last_key(vvp_vector4_t&key) const =0;
      virtual bool next_key(std::string&key) const =0;
      virtual bool next_key(vvp_object_t&key) const =0;
      virtual bool next_key(vvp_vector4_t&key) const =0;
      virtual bool prev_key(std::string&key) const =0;
      virtual bool prev_key(vvp_object_t&key) const =0;
      virtual bool prev_key(vvp_vector4_t&key) const =0;
      virtual void erase_key(const std::string&key) =0;
      virtual void erase_key(const vvp_object_t&key) =0;
      virtual void erase_key(const vvp_vector4_t&key) =0;

    protected:
      static const vvp_object* object_key_(const vvp_object_t&key);
      static std::string vec4_key_(const vvp_vector4_t&key);
};

template <class TYPE> class vvp_assoc_map : public vvp_assoc_base {
    public:
      inline vvp_assoc_map() { }
      ~vvp_assoc_map() override { }

      size_t size() const override
      { return str_map_.size() + obj_map_.size() + vec_map_.size(); }
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
      bool first_key(vvp_vector4_t&key) const override
      { return first_key_(vec_map_, key); }
      bool last_key(std::string&key) const override
      { return last_key_(str_map_, key); }
      bool last_key(vvp_object_t&key) const override
      { return last_key_(obj_map_, key); }
      bool last_key(vvp_vector4_t&key) const override
      { return last_key_(vec_map_, key); }
      bool next_key(std::string&key) const override
      { return next_key_(str_map_, key); }
      bool next_key(vvp_object_t&key) const override
      { return next_key_(obj_map_, key); }
      bool next_key(vvp_vector4_t&key) const override
      { return next_key_(vec_map_, key); }
      bool prev_key(std::string&key) const override
      { return prev_key_(str_map_, key); }
      bool prev_key(vvp_object_t&key) const override
      { return prev_key_(obj_map_, key); }
      bool prev_key(vvp_vector4_t&key) const override
      { return prev_key_(vec_map_, key); }
      void erase_key(const std::string&key) override
      { str_map_.erase(key); }
      void erase_key(const vvp_object_t&key) override
      { obj_map_.erase(object_key_(key)); }
      void erase_key(const vvp_vector4_t&key) override
      { vec_map_.erase(vec4_key_(key)); }

      void set(const std::string&key, const TYPE&value)
      { str_map_[key] = value; }
      void set(const vvp_object_t&key, const TYPE&value)
      { obj_map_[object_key_(key)] = value; }
      void set(const vvp_vector4_t&key, const TYPE&value)
      {
            vec_entry_t&entry = vec_map_[vec4_key_(key)];
            entry.key = key;
            entry.value = value;
      }

      bool get(const std::string&key, TYPE&value) const
      {
            typename std::map<std::string, TYPE>::const_iterator cur = str_map_.find(key);
            if (cur == str_map_.end())
                  return false;
            value = cur->second;
            return true;
      }

      bool get(const vvp_object_t&key, TYPE&value) const
      {
            typename std::map<const vvp_object*, TYPE>::const_iterator cur = obj_map_.find(object_key_(key));
            if (cur == obj_map_.end())
                  return false;
            value = cur->second;
            return true;
      }

      bool get(const vvp_vector4_t&key, TYPE&value) const
      {
            typename std::map<std::string, vec_entry_t>::const_iterator cur = vec_map_.find(vec4_key_(key));
            if (cur == vec_map_.end())
                  return false;
            value = cur->second.value;
            return true;
      }

      void shallow_copy(const vvp_object*obj) override
      {
            const vvp_assoc_map<TYPE>*that = dynamic_cast<const vvp_assoc_map<TYPE>*>(obj);
            assert(that);
            str_map_ = that->str_map_;
            obj_map_ = that->obj_map_;
            vec_map_ = that->vec_map_;
      }

      vvp_object* duplicate(void) const override
      {
            vvp_assoc_map<TYPE>*that = new vvp_assoc_map<TYPE>();
            that->str_map_ = str_map_;
            that->obj_map_ = obj_map_;
            that->vec_map_ = vec_map_;
            return that;
      }

    private:
      struct vec_entry_t {
            vvp_vector4_t key;
            TYPE value;
      };

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

      static bool first_key_(const std::map<std::string, vec_entry_t>&map,
                             vvp_vector4_t&key)
      {
            if (map.empty())
                  return false;
            assign_key_(key, map.begin()->second);
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
                            vvp_vector4_t&key)
      {
            if (map.empty())
                  return false;
            typename std::map<std::string, vec_entry_t>::const_iterator cur = map.end();
            --cur;
            assign_key_(key, cur->second);
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

      static bool next_key_(const std::map<std::string, vec_entry_t>&map, vvp_vector4_t&key)
      {
            typename std::map<std::string, vec_entry_t>::const_iterator cur =
                  map.upper_bound(vec4_key_(key));
            if (cur == map.end())
                  return false;
            assign_key_(key, cur->second);
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

      static bool prev_key_(const std::map<std::string, vec_entry_t>&map, vvp_vector4_t&key)
      {
            const std::string raw_key = vec4_key_(key);
            typename std::map<std::string, vec_entry_t>::const_iterator cur = map.lower_bound(raw_key);
            if (cur == map.begin())
                  return false;
            if (cur == map.end() || !(cur->first < raw_key))
                  --cur;
            assign_key_(key, cur->second);
            return true;
      }

      std::map<std::string, TYPE> str_map_;
      std::map<const vvp_object*, TYPE> obj_map_;
      std::map<std::string, vec_entry_t> vec_map_;
};

typedef vvp_assoc_map<double> vvp_assoc_real;
typedef vvp_assoc_map<std::string> vvp_assoc_string;
typedef vvp_assoc_map<vvp_vector4_t> vvp_assoc_vec4;
typedef vvp_assoc_map<vvp_object_t> vvp_assoc_object;

#endif /* IVL_vvp_assoc_H */
