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
# include  <string>
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
      inline const std::string&scope_path(void) const { return scope_path_; }
      inline const std::string&dispatch_prefix(void) const { return dispatch_prefix_; }
      inline const std::string&super_dispatch_prefix(void) const { return super_dispatch_prefix_; }
      void set_scope_path(const std::string&path);
      void set_dispatch_prefix(const std::string&path);
      void set_super_dispatch_prefix(const std::string&path);
      const class_type* runtime_super(void) const;
	// Number of properties in the class definition.
      inline size_t property_count(void) const { return properties_.size(); }
      const std::string& property_name(size_t idx) const;

	// Set the details about the property. This is used during
	// parse of the .vvp file to fill in the details of the
	// property for the class definition.
      void set_property(size_t idx, const std::string&name, const std::string&type, uint64_t array_size);

      bool property_is_rand(size_t idx) const;
      bool property_is_randc(size_t idx) const;

	// Base type text (rand prefix stripped, e.g. "sb32", "o") and
	// static array element count (1 for scalars) as recorded from
	// the .class directive. Used by randomize to fill and write
	// back array-typed rand properties.
      const std::string& property_base_type(size_t idx) const;
      uint64_t property_array_size(size_t idx) const;

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
      std::string scope_path_;
      std::string dispatch_prefix_;
      std::string super_dispatch_prefix_;

      struct prop_t {
	    std::string name;
	    class_property_t*type;
	    bool rand_flag  = false;
	    bool randc_flag = false;
	    std::string base_type;
	    uint64_t array_size = 1;
      };
      std::vector<prop_t> properties_;
      size_t instance_size_;

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
	    //           4=transition step (tuple = (seq<<8)|step)
	    // kind & 8: wildcard match ((v ^ lo) & hi == 0)
	    unsigned kind = 0;
	    unsigned tuple = 0;
	    unsigned item_idx = 0;
      };
      struct cov_item_t {
	    unsigned at_least = 1;
	    unsigned weight = 1;
	    bool is_cross = false;
      };
      static const unsigned COV_NO_PROP = 0xFFFFFFFFu;
      void add_covgrp_bin(unsigned cp_idx, unsigned prop_idx, uint64_t lo, uint64_t hi,
			  unsigned kind = 0, unsigned tuple = 0,
			  unsigned item_idx = 0);
      void add_covgrp_item(unsigned at_least, unsigned weight, bool is_cross)
      { cov_item_t it;
	it.at_least = at_least;
	it.weight = weight;
	it.is_cross = is_cross;
	covgrp_items_.push_back(it); }
      size_t covgrp_bin_count() const { return covgrp_bins_.size(); }
      const cov_bin_t& covgrp_bin(size_t idx) const { return covgrp_bins_[idx]; }
      size_t covgrp_item_count() const { return covgrp_items_.size(); }
      const cov_item_t& covgrp_item(size_t idx) const { return covgrp_items_[idx]; }
      bool is_covergroup() const { return !covgrp_bins_.empty(); }

	// M11: TYPE-level (merged across all instances) hit counters
	// indexed by counter property, and the type coverage computed
	// from them with the same per-item weighted model as instance
	// coverage.
      void type_bump(unsigned prop) const;
      uint32_t type_count(unsigned prop) const;
      double type_coverage() const;

	// M11: registry of covergroup types for $get_coverage and the
	// end-of-simulation report.
      static const std::vector<const class_type*>& covgrp_registry();
      static void covgrp_register(const class_type*ct);
      static void covgrp_report(FILE*fd);

    private:
      std::vector<cov_bin_t> covgrp_bins_;
      std::vector<cov_item_t> covgrp_items_;
      mutable std::vector<uint32_t> type_counts_;
};

const class_type* class_type_from_dispatch_prefix(const std::string&prefix);

#endif /* IVL_class_type_H */
