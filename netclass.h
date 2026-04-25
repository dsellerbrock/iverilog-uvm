#ifndef IVL_netclass_H
#define IVL_netclass_H
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

# include  "LineInfo.h"
# include  "ivl_target.h"
# include  "nettypes.h"
# include  "property_qual.h"
# include  <iostream>
# include  <map>

class Design;
class NetExpr;
class NetNet;
class NetScope;
class PClass;
class PExpr;
class PEventStatement;

class netclass_t : public ivl_type_s {
    public:
      netclass_t(perm_string class_name, const netclass_t*super);
      ~netclass_t() override;

	// Set the property of the class during elaboration. Set the
	// name and type, and return true. If the name is already
	// present, then return false.
      bool set_property(perm_string pname, property_qualifier_t qual, ivl_type_t ptype);

	// Set the scope for the class. The scope has no parents and
	// is used for the elaboration of methods
	// (tasks/functions). In other words, this is the class itself.
      void set_class_scope(NetScope*cscope);

      inline const NetScope* class_scope(void) const { return class_scope_; }

	// Set the scope for the class definition. This is the scope
	// where the class definition was encountered, and may be used
	// to locate symbols that the class definition may inherit
	// from its context. This can be nil, or a package or module
	// where a class is defined.
      void set_definition_scope(NetScope*dscope);

      NetScope*definition_scope(void);

	// As an ivl_type_s object, the netclass is always an
	// ivl_VT_CLASS object.
      ivl_variable_type_t base_type() const override;

	// This is the name of the class type
      inline perm_string get_name() const { return name_; }

	// If this is derived from another class, then this method
	// returns a pointer to the super-class.
      inline const netclass_t* get_super() const { return super_; }
      inline const std::vector<const netclass_t*>& derived_types() const { return derived_types_; }
      void set_super(const netclass_t*super);

	// Get the number of properties in this class. Include
	// properties in the parent class.
      size_t get_properties(void) const;
	// Get information about each property.
      const char*get_prop_name(size_t idx) const;
      property_qualifier_t get_prop_qual(size_t idx) const;
      ivl_type_t get_prop_type(size_t idx) const;

	// These methods are used by the elaborator to note the
	// initializer for constant properties. Properties start out
	// as not initialized, and when elaboration detects an
	// assignment to the property, it is marked initialized.
      bool get_prop_initialized(size_t idx) const;
      void set_prop_initialized(size_t idx) const;

      bool test_for_missing_initializers(void) const;

	// Map the name of a property to its index. Return <0 if the
	// name is not a property in the class.
      int property_idx_from_name(perm_string pname) const;

	// The task method scopes from the method name.
      NetScope*method_from_name(perm_string mname) const;

	// Resolve an object method call. This normally returns the method
	// found on the static class type, but if that resolves to an
	// abstract/bodyless prototype then this may redirect to a unique
	// concrete override found in a descendant class.
      NetScope*resolve_method_call_scope(const Design*des, perm_string mname) const;

	// Returns the constructor task method of the class. Might be nullptr if
	// there is nothing to do in the constructor.
      NetScope* get_constructor() const;

	// Find the elaborated signal (NetNet) for a static
	// property. Search by name. The signal is created by the
	// elaborate_sig pass.
      NetNet*find_static_property(perm_string name) const;

	// Test if this scope is a method within the class. This is
	// used to check scope for handling data protection keywords
	// "local" and "protected".
      bool test_scope_is_method(const NetScope*scope) const;

      void elaborate_sig(Design*des, PClass*pclass);
      void elaborate(Design*des, PClass*pclass);

      void emit_scope(struct target_t*tgt) const;
      bool emit_defs(struct target_t*tgt) const;
      int ensure_property_decl(Design*des, perm_string pname);

      // Ensure ALL properties in this class and its entire super chain are
      // declared. This makes get_properties() return a stable final count so
      // that property_idx_from_name() computes correct absolute indices even
      // when called early during incremental elaboration.
      void ensure_all_properties_declared(Design*des);

      // Overwrite the stored type for an already-declared property.
      // Used by elaborate_sig to repair types that were stored as
      // integer fallbacks due to circular elaboration order.
      void repair_property_type(perm_string pname, ivl_type_t new_type);

      std::ostream& debug_dump(std::ostream&fd) const override;
      void dump_scope(std::ostream&fd) const;

      const NetExpr* get_parameter(Design *des, perm_string name,
				   ivl_type_t &par_type) const;

      void set_virtual(bool virtual_class) { virtual_class_ = virtual_class; }
      bool is_virtual() const { return virtual_class_; }
      void set_interface(bool interface_type) { interface_type_ = interface_type; }
      bool is_interface() const { return interface_type_; }
      void set_sig_elaborated(bool flag) { sig_elaborated_ = flag; }
      bool sig_elaborated() const { return sig_elaborated_; }
      void set_sig_elaborating(bool flag) { sig_elaborating_ = flag; }
      bool sig_elaborating() const { return sig_elaborating_; }

	// Constraint IR: simple token-stream representation of constraint blocks.
	// Format: each item is "name\tir_string" where ir_string is an
	// S-expression like "(lt p:1:8 c:255)".
      void add_constraint_ir(const std::string&name, const std::string&ir);
      size_t constraint_ir_count() const { return constraint_irs_.size(); }
      const std::string& constraint_ir_name(size_t idx) const;
      const std::string& constraint_ir_str(size_t idx)  const;
      void set_body_elaborated(bool flag) { body_elaborated_ = flag; }
      bool body_elaborated() const { return body_elaborated_; }
      void set_body_elaborating(bool flag) { body_elaborating_ = flag; }
      bool body_elaborating() const { return body_elaborating_; }
      void set_scope_ready(bool flag) { scope_ready_ = flag; }
      bool scope_ready() const { return scope_ready_; }
      void set_specialized_instance(bool flag) { specialized_instance_ = flag; }
      bool specialized_instance() const { return specialized_instance_; }

      struct clocking_block_t {
	    perm_string name;
	    const PEventStatement* event;
	    std::vector<perm_string> signals;
      };
      bool add_clocking_block(perm_string name, const PEventStatement*event,
			      const std::vector<perm_string>&signals);
      const clocking_block_t* find_clocking_block(perm_string name) const;

    protected:
      bool test_compatibility(ivl_type_t that) const override;

    private:
      void add_derived_type_(const netclass_t*derived);

      perm_string name_;
	// If this is derived from another base class, point to it
	// here.
      const netclass_t*super_;
      std::vector<const netclass_t*> derived_types_;
	// Map property names to property table index.
      std::map<perm_string,size_t> properties_;
	// Vector of properties.
      struct prop_t {
	    perm_string name;
	    property_qualifier_t qual;
	    ivl_type_t type;
	    mutable bool initialized_flag;
      };
      std::vector<prop_t> property_table_;

	// This holds task/function definitions for methods.
      NetScope*class_scope_;

	// This holds the context for the class type definition.
      NetScope*definition_scope_;

      bool virtual_class_;
      bool interface_type_;
      bool sig_elaborated_;
      bool sig_elaborating_;
      bool props_declaring_;  // guard for ensure_all_properties_declared re-entry
      bool body_elaborated_;
      bool body_elaborating_;
      bool scope_ready_;
      bool specialized_instance_;
      std::map<perm_string,size_t> clocking_blocks_;
      std::vector<clocking_block_t> clocking_table_;

      struct constraint_ir_t {
	    std::string name;
	    std::string ir;
      };
      std::vector<constraint_ir_t> constraint_irs_;

    public:
	// Covergroup bin metadata (for synthesized covergroup class types).
	// Each entry represents one bin: the cp_idx selects which
	// coverpoint value to sample (matches the order they are pushed
	// on the vec4 stack at the sample() call site), prop_idx is the
	// property index in THIS class that holds the bin hit count,
	// and lo/hi define the inclusive range.
      struct covgrp_bin_t {
	    unsigned cp_idx;
	    unsigned prop_idx;
	    uint64_t lo;
	    uint64_t hi;
      };

      void add_covgrp_bin(unsigned cp, unsigned prop, uint64_t lo, uint64_t hi);
      size_t covgrp_bin_count() const { return covgrp_bins_.size(); }
      const covgrp_bin_t& covgrp_bin(size_t idx) const { return covgrp_bins_[idx]; }
      bool is_covergroup() const { return is_covergroup_; }
      void set_is_covergroup(bool f) { is_covergroup_ = f; }
      unsigned covgrp_ncoverpoints() const { return covgrp_ncoverpoints_; }
      void set_covgrp_ncoverpoints(unsigned n) { covgrp_ncoverpoints_ = n; }

	// Property index in the PARENT class for each coverpoint
	// (in coverpoint order). Used at sample() call sites.
      void add_covgrp_cp_parent_prop(int pidx) { covgrp_cp_parent_props_.push_back(pidx); }
      int covgrp_cp_parent_prop(unsigned cp_idx) const {
	    if (cp_idx < covgrp_cp_parent_props_.size()) return covgrp_cp_parent_props_[cp_idx];
	    return -1;
      }

    private:
      std::vector<covgrp_bin_t> covgrp_bins_;
      std::vector<int> covgrp_cp_parent_props_;
      bool is_covergroup_ = false;
      unsigned covgrp_ncoverpoints_ = 0;
};

inline NetScope*netclass_t::definition_scope(void)
{
      return definition_scope_;
}

extern netclass_t* builtin_class_type(perm_string name);

#endif /* IVL_netclass_H */
