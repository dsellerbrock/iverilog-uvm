#ifndef IVL_class_type_H
#define IVL_class_type_H
/*
 * Copyright (c) 2012-2025 Stephen Williams (steve@icarus.com)
 *
 *    This source code is free software; you can redistribute it
 *    and/or modify it in source code form under the terms of the GNU
 *    General Public License as published by the Free Software
 *    Foundation; either version 2 of the License, or (at your option)
 *    any later version
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

# include  <cstdint>
# include  <map>
# include  <set>
# include  <string>
# include  <utility>
# include  <vector>
# include  "vpi_priv.h"

class class_property_t;
class vvp_vector4_t;

/*
 * This represents the TYPE information for a class. A %new operator
 * uses this information to figure out how to construct an actual
 * instance.
 */
class class_type : public __vpiHandle {

    public:
      struct inst_x;
      typedef inst_x*inst_t;

    public:
      explicit class_type(const std::string&nam, size_t nprop);
      ~class_type() override;

	// This is the name of the class type.
      inline const std::string&class_name(void) const { return class_name_; }

	// True for the synthetic class that implements an unpacked
	// STRUCT type: struct-typed objects copy BY VALUE wherever they
	// are stored; class objects copy as handles.
      inline bool is_struct_type(void) const { return is_struct_type_; }
      inline void set_struct_type(void) { is_struct_type_ = true; }
      inline bool is_union_type(void) const { return is_union_type_; }
      inline bool is_tagged_union_type(void) const
	    { return is_union_type_ && is_tagged_union_type_; }
      inline void set_union_type(bool tagged)
	    { is_struct_type_ = true; is_union_type_ = true;
	      is_tagged_union_type_ = tagged; }
      inline const std::string&scope_path(void) const { return scope_path_; }
      inline const std::string&dispatch_prefix(void) const { return dispatch_prefix_; }
      inline const std::string&super_dispatch_prefix(void) const { return super_dispatch_prefix_; }
      inline const std::vector<std::string>&interface_dispatch_prefixes(void) const
	    { return interface_dispatch_prefixes_; }
      void set_scope_path(const std::string&path);
      void set_dispatch_prefix(const std::string&path);
      void set_super_dispatch_prefix(const std::string&path);
      void add_interface_dispatch_prefix(const std::string&path);
      bool assignment_compatible_with(const class_type*want) const;
      const class_type* runtime_super(void) const;
	// Number of properties in the class definition.
      inline size_t property_count(void) const { return properties_.size(); }
      const std::string& property_name(size_t idx) const;

	// Set the details about the property. This is used during
	// parse of the .vvp file to fill in the details of the
	// property for the class definition.
      void set_property(size_t idx, const std::string&name,
                        const std::string&type,
                        const std::vector<std::pair<int,int> >&dimensions);

      bool property_is_rand(size_t idx) const;
      bool property_is_randc(size_t idx) const;
      bool property_is_static(size_t idx) const;
      bool property_is_enum(size_t idx) const;
      unsigned property_qualifier(size_t idx) const;
      const std::vector<vvp_vector4_t>&property_enum_values(size_t idx) const;

	// Return the canonical declaring-scope VPI storage for a static
	// property. This resolves inherited absolute property indexes and
	// validates that deferred label resolution produced an actual signal
	// or fixed array, never the unresolved null-constant sentinel.
      vpiHandle static_property_storage(size_t idx) const;

	// Bind an absolute static-property index to the VPI handle for the
	// declaring class-scope variable (or fixed-array object). The label
	// may be forward-referenced in the VVP stream.
      void bind_static_property(size_t idx, char*storage);

	// A static random variable has one mode for the class declaration,
	// not one mode in every object. Inherited property indexes delegate
	// through runtime_super(), so base and sibling-derived objects share
	// the declaring class's state. Parameter specializations are distinct
	// class_type objects and therefore remain isolated.
      bool static_rand_mode(size_t idx) const;
      bool static_rand_mode(size_t idx, size_t leaf) const;
      bool static_rand_mode_any(size_t idx) const;
      void set_static_rand_mode(size_t idx, bool mode) const;
      void set_static_rand_mode(size_t idx, size_t leaf, bool mode) const;

	// Return the committed randc history for one scalar/aggregate leaf of
	// a static property. The history lives in the same canonical cell as
	// VALUE and rand_mode, so duplicate runtime class records and inherited
	// receivers cannot fork the cycle. Phase R1 uses leaf 0 for scalars;
	// the leaf key keeps the storage hook ready for indexed aggregate mode.
      std::vector<bool>&static_randc_history(size_t idx, size_t leaf) const;

	// Delay canonical static-value publication while an object graph is
	// being randomized. Getters see the overlay immediately, but VPI/signal
	// callbacks see only a successful final commit; rollback discards every
	// tentative value without exposing it.
      bool static_randomize_transaction_begin(size_t idx) const;
      void static_randomize_transaction_mark_dirty(size_t idx,
						    size_t leaf) const;
      void static_randomize_transaction_commit(size_t idx) const;
      void static_randomize_transaction_rollback(size_t idx) const;

	// Base type text (rand prefix stripped, e.g. "sb32", "o") and
	// static array element count (1 for scalars) as recorded from
	// the .class directive. Used by randomize to fill and write
	// back array-typed rand properties.
      const std::string& property_base_type(size_t idx) const;
      unsigned property_vec4_width(size_t idx) const;
      unsigned union_vec4_width(void) const;
      bool union_is_four_state(void) const;
      bool property_is_void(size_t idx) const;
      const class_type*property_declared_class_type(size_t idx) const;
      uint64_t property_array_size(size_t idx) const;
      const std::vector<std::pair<int,int> >&
            property_dimensions(size_t idx) const;

      void add_constraint(const std::string&name, const std::string&ir);
      size_t constraint_count() const { return constraints_.size(); }
      const std::string& constraint_name(size_t idx) const;
      const std::string& constraint_ir(size_t idx) const;

	// This method is called after all the properties are
	// defined. This calculates information about the definition.
      void finish_setup(void);

    public:
	// Constructors and destructors for making instances.
      inst_t instance_new() const;
      void instance_delete(inst_t) const;

      void set_vec4(inst_t inst, size_t pid, const vvp_vector4_t&val, size_t idx = 0) const;
      void get_vec4(inst_t inst, size_t pid, vvp_vector4_t&val, size_t idx = 0) const;
      void set_real(inst_t inst, size_t pid, double val, size_t idx = 0) const;
      double get_real(inst_t inst, size_t pid, size_t idx = 0) const;
      void set_string(inst_t inst, size_t pid, const std::string&val, size_t idx = 0) const;
      std::string get_string(inst_t inst, size_t pid, size_t idx = 0) const;
      void set_object(inst_t inst, size_t pid, const vvp_object_t&val, size_t idx) const;
      void get_object(inst_t inst, size_t pid, vvp_object_t&val, size_t idx) const;

      void copy_property(inst_t dst, size_t idx, inst_t src) const;

    public: // VPI related methods
      int get_type_code(void) const override;
      char* vpi_get_str(int code) override;
      vpiHandle vpi_handle(int code) override;

    private:
      std::string class_name_;
      bool is_struct_type_ = false;
      bool is_union_type_ = false;
      bool is_tagged_union_type_ = false;
      std::string scope_path_;
      std::string dispatch_prefix_;
      std::string super_dispatch_prefix_;
      std::vector<std::string> interface_dispatch_prefixes_;

      struct prop_t {
	    std::string name;
	    class_property_t*type;
	    unsigned qualifier = 0;
	    bool rand_flag  = false;
	    bool randc_flag = false;
	    std::string base_type;
	    std::vector<vvp_vector4_t> enum_values;
	    vpiHandle declared_class_type = 0;
	    uint64_t array_size = 1;
	    std::vector<std::pair<int,int> > dimensions;
      };
      std::vector<prop_t> properties_;
      struct static_property_cell_t {
	    static_property_cell_t() : storage(0), rand_mode(true) { }
	    vpiHandle storage;
	    std::string storage_label;
	    bool rand_mode;
	    std::map<size_t, bool> rand_mode_leaves;
	    std::map<size_t, std::vector<bool> > randc_history;
	    bool randomize_transaction_active = false;
	    std::map<size_t, vvp_vector4_t> randomize_vec4;
	    std::map<size_t, double> randomize_real;
	    std::map<size_t, std::string> randomize_string;
	    std::map<size_t, vvp_object_t> randomize_object;
	    std::set<size_t> randomize_dirty;
      };
      std::vector<static_property_cell_t*> static_properties_;
      size_t instance_size_;

	// Inherited absolute pids always resolve to the declaring runtime
	// class's cell. This shares both VALUE and rand_mode across sibling
	// derived types while leaving parameter specializations isolated.
      static_property_cell_t*static_property_cell_(size_t idx) const;
      vpiHandle static_property_storage_(size_t idx) const;

      struct constraint_t {
	    std::string name;
	    std::string ir;
      };
      std::vector<constraint_t> constraints_;

    public:
	// M11: one predicate record of a coverage bin.  Records with
	// the same (prop_idx, tuple) AND together; distinct tuples of
	// one prop OR together.  item_idx groups props into coverage
	// items (coverpoints, then crosses).
      struct cov_bin_t {
	    unsigned cp_idx;
	    unsigned prop_idx;   // 0xFFFFFFFF: no counter (ignore bins)
	    uint64_t lo;         // wildcard: value
	    uint64_t hi;         // wildcard: care mask
	    // kind & 7: 0=normal, 1=ignore, 2=illegal, 3=default,
	    //           4=transition step (tuple = (seq<<8)|step),
	    //           5=illegal default, 6=ignore default
	    // kind & 8: wildcard match ((v ^ lo) & hi == 0)
	    unsigned kind = 0;
	    unsigned tuple = 0;
	    unsigned item_idx = 0;
	    unsigned trans_repeat = 0;
	    uint64_t trans_min = 1;
	    uint64_t trans_max = 1;
	    unsigned trans_alt = 0;
	    unsigned trans_alt_count = 1;
	    unsigned trans_family = 0xFFFFFFFFu;
	    uint64_t trans_base = 0;
	    unsigned guard_idx = 0xFFFFFFFFu;
      };
      struct cov_item_t {
	    unsigned at_least = 1;
	    unsigned weight = 1;
	    std::string weight_ir;
	    bool is_cross = false;
	    std::string name;   // M12-7: coverpoint/cross label
	    int iff_src = -1;   // parent property for event-driven cross iff
      };
      struct cov_dyn_bin_t {
	    unsigned cp_idx = 0;
	    unsigned item_idx = 0;
	    unsigned kind = 0;
	    unsigned family = 0;
	    uint64_t array_size = 0;
	    std::string name;
	    std::string lo_ir;
	    std::string hi_ir;
	    unsigned guard_idx = 0xFFFFFFFFu;
      };
      static const unsigned COV_NO_PROP = 0xFFFFFFFFu;
	static const unsigned COV_NO_FAMILY = 0xFFFFFFFFu;
	static const unsigned COV_NO_GUARD = 0xFFFFFFFFu;
      void add_covgrp_bin(unsigned cp_idx, unsigned prop_idx, uint64_t lo, uint64_t hi,
			  unsigned kind = 0, unsigned tuple = 0,
			  unsigned item_idx = 0, unsigned trans_repeat = 0,
			  uint64_t trans_min = 1, uint64_t trans_max = 1,
			  unsigned trans_alt = 0, unsigned trans_alt_count = 1,
			  unsigned trans_family = COV_NO_FAMILY,
			  uint64_t trans_base = 0,
			  unsigned guard_idx = COV_NO_GUARD);
      void add_covgrp_item(unsigned at_least, unsigned weight, bool is_cross,
			   const std::string&name = std::string(),
			   const std::string&weight_ir = std::string(),
			   int iff_src = -1)
      { cov_item_t it;
	it.at_least = at_least;
	it.weight = weight;
	it.weight_ir = weight_ir;
	it.is_cross = is_cross;
	it.name = name;
	it.iff_src = iff_src;
	covgrp_items_.push_back(it); }
      size_t covgrp_bin_count() const { return covgrp_bins_.size(); }
      const cov_bin_t& covgrp_bin(size_t idx) const { return covgrp_bins_[idx]; }
      void add_covgrp_dyn_bin(unsigned cp, unsigned item, unsigned kind,
			      unsigned family, uint64_t array_size,
			      const std::string&name,
			      const std::string&lo_ir,
			      const std::string&hi_ir,
			      unsigned guard_idx = COV_NO_GUARD)
      { cov_dyn_bin_t b;
	b.cp_idx = cp; b.item_idx = item; b.kind = kind; b.family = family;
	b.array_size = array_size; b.name = name; b.lo_ir = lo_ir; b.hi_ir = hi_ir;
	b.guard_idx = guard_idx;
	covgrp_dyn_bins_.push_back(b); }
      size_t covgrp_dyn_bin_count() const { return covgrp_dyn_bins_.size(); }
      const cov_dyn_bin_t& covgrp_dyn_bin(size_t idx) const
      { return covgrp_dyn_bins_[idx]; }
      size_t covgrp_item_count() const { return covgrp_items_.size(); }
      const cov_item_t& covgrp_item(size_t idx) const { return covgrp_items_[idx]; }
      unsigned covgrp_item_weight(class vvp_cobject*obj, size_t idx) const;
      bool covgrp_eval_ir(class vvp_cobject*obj, const std::string&ir,
			  uint64_t&value) const;
      bool is_covergroup() const
      { return !covgrp_bins_.empty() || !covgrp_dyn_bins_.empty(); }

	// M11: TYPE-level (merged across all instances) hit counters
	// indexed by counter property, and the type coverage computed
	// from them with the same per-item weighted model as instance
	// coverage.
      void type_bump(unsigned prop) const;
      uint32_t type_count(unsigned prop) const;
      void dyn_type_bump(unsigned family, uint64_t bin) const
      { covgrp_dyn_type_counts_[std::make_pair(family, bin)] += 1; }
      uint32_t dyn_type_count(unsigned family, uint64_t bin) const
      { auto it = covgrp_dyn_type_counts_.find(std::make_pair(family, bin));
	return it == covgrp_dyn_type_counts_.end() ? 0 : it->second; }
	uint64_t dyn_type_hits(unsigned family, unsigned at_least) const
	{ uint64_t hits = 0;
	  for (auto&entry : covgrp_dyn_type_counts_)
		if (entry.first.first == family && entry.second >= at_least)
		      hits += 1;
	  return hits; }
	uint64_t covgrp_trans_family_size(unsigned family) const;
	unsigned covgrp_trans_family_item(unsigned family) const;
      double type_coverage(class vvp_cobject*context = 0) const;

	// M11: registry of covergroup types for $get_coverage and the
	// end-of-simulation report.
      static const std::vector<const class_type*>& covgrp_registry();
      static void covgrp_register(const class_type*ct);
      static void covgrp_report(FILE*fd);

	// M11-3: event-driven sampling of class-embedded covergroup
	// instances. The parent-handle property links each covergroup
	// object back to its containing object; per-coverpoint source
	// and guard property indexes name the PARENT properties the
	// event process reads; the live-instance list is walked by
	// %covgrp/sample/all.
      void set_covgrp_parent_prop(int p) { covgrp_parent_prop_ = p; }
      int covgrp_parent_prop() const { return covgrp_parent_prop_; }
      void add_covgrp_src(int srcprop, int guardsrc)
      { covgrp_srcprops_.push_back(srcprop);
	covgrp_guardsrcs_.push_back(guardsrc); }
      int covgrp_srcprop(size_t cp) const
      { return cp < covgrp_srcprops_.size() ? covgrp_srcprops_[cp] : -1; }
      int covgrp_guardsrc(size_t cp) const
      { return cp < covgrp_guardsrcs_.size() ? covgrp_guardsrcs_[cp] : -1; }
      size_t covgrp_src_count() const { return covgrp_srcprops_.size(); }
      void covgrp_live_add(class vvp_cobject*obj) const
      { covgrp_live_.push_back(obj); }
      void covgrp_live_remove(class vvp_cobject*obj) const
      { for (size_t i = 0; i < covgrp_live_.size(); i += 1)
	      if (covgrp_live_[i] == obj) {
		    covgrp_live_.erase(covgrp_live_.begin() + (long)i);
		    return;
	      } }
      const std::vector<class vvp_cobject*>& covgrp_live() const
      { return covgrp_live_; }

    private:
      std::vector<cov_bin_t> covgrp_bins_;
      std::vector<cov_dyn_bin_t> covgrp_dyn_bins_;
      std::vector<cov_item_t> covgrp_items_;
      mutable std::vector<uint32_t> type_counts_;
      mutable std::map<std::pair<unsigned,uint64_t>,uint32_t>
	    covgrp_dyn_type_counts_;
      int covgrp_parent_prop_ = -1;
      std::vector<int> covgrp_srcprops_;
      std::vector<int> covgrp_guardsrcs_;
      mutable std::vector<class vvp_cobject*> covgrp_live_;
};

const class_type* class_type_from_dispatch_prefix(const std::string&prefix);

#endif /* IVL_class_type_H */
