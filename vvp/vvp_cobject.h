#ifndef IVL_vvp_cobject_H
#define IVL_vvp_cobject_H
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

# include  <string>
# include  <stdint.h>
# include  <map>
# include  <vector>
# include  "vvp_object.h"
# include  "class_type.h"

class vvp_vector4_t;

class vvp_cobject : public vvp_object {

    public:
      explicit vvp_cobject(const class_type*defn);
      ~vvp_cobject() override;

      void set_vec4(size_t pid, const vvp_vector4_t&val, size_t idx = 0);
      void get_vec4(size_t pid, vvp_vector4_t&val, size_t idx = 0);

      void set_real(size_t pid, double val, size_t idx = 0);
      double get_real(size_t pid, size_t idx = 0);

      void set_string(size_t pid, const std::string&val, size_t idx = 0);
      std::string get_string(size_t pid, size_t idx = 0);

      void set_object(size_t pid, const vvp_object_t&val, size_t idx);
      void get_object(size_t pid, vvp_object_t&val, size_t idx);

	// Per-instance dynamic named event storage (IEEE 1800-2017 15.5).
	// A non-static class `event` property is backed by its own
	// vvp_net_t (a vvp_named_event_dyn functor), allocated lazily and
	// keyed by the compiler-assigned global event slot, so a trigger on
	// one object's event wakes only that object's waiters. Returns the
	// per-instance event net, creating it on first use.
      class vvp_net_t* get_inst_event(uint32_t slot);

      void shallow_copy(const vvp_object*that) override;

      const class_type* get_defn() const { return defn_; }

      bool rand_mode(size_t pid) const;
      void set_rand_mode(size_t pid, bool mode);
      void set_all_rand_mode(bool mode);

      bool constraint_mode(size_t cid) const;
      void set_constraint_mode(size_t cid, bool mode);

      // C1 (Phase 62a): randc cyclic state.
      bool randc_seen(size_t pid, uint64_t val) const;
      void randc_mark(size_t pid, uint64_t val);
      uint64_t randc_period(size_t pid) const;

	// M11: covergroup transition-bin progress state — active-
	// position masks keyed by (prop_idx << 8) | seq_id.
      uint64_t cov_trans_mask(uint64_t key) const {
	    auto it = cov_trans_.find(key);
	    return (it == cov_trans_.end()) ? 0 : it->second;
      }
      void set_cov_trans_mask(uint64_t key, uint64_t mask) {
	    cov_trans_[key] = mask;
      }
	// M11: covergroup start()/stop() sampling enable.
      bool cov_enabled() const { return cov_enabled_; }
      void set_cov_enabled(bool f) { cov_enabled_ = f; }

    private:
      const class_type* defn_;
	// For now, only support 32bit bool signed properties.
      class_type::inst_t properties_;
      std::vector<bool> rand_mode_;
      std::vector<bool> constraint_mode_;
      std::map<size_t, std::vector<bool> > randc_history_;
      std::map<uint64_t, uint64_t> cov_trans_;
      bool cov_enabled_ = true;
	// Lazily-allocated per-instance event nets, keyed by event slot.
      std::map<uint32_t, class vvp_net_t*> inst_events_;
};

#endif /* IVL_vvp_cobject_H */
