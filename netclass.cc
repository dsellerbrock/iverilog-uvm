/*
 * Copyright (c) 2012-2017 Stephen Williams (steve@icarus.com)
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

# include  "netclass.h"
# include  "netlist.h"
# include  "PClass.h"
# include  "PTask.h"
# include  "pform_types.h"
# include  <cassert>
# include  <cstdlib>
# include  <iostream>

using namespace std;

namespace {

static bool method_scope_has_concrete_body_(const NetScope*scope)
{
      if (!scope)
	    return false;

      switch (scope->type()) {
	  case NetScope::FUNC:
	    if (const PFunction*pfunc = scope->func_pform())
		  return pfunc->get_statement() != 0;
	    if (const NetFuncDef*def = scope->func_def()) {
		  const NetProc*proc = def->proc();
		  if (const NetBlock*blk = dynamic_cast<const NetBlock*>(proc))
			return blk->proc_first() != 0;
		  return proc != 0;
	    }
	    return false;

	  case NetScope::TASK:
	    if (const NetTaskDef*def = scope->task_def()) {
		  const NetProc*proc = def->proc();
		  // proc may be null when body not yet elaborated; fall back to pform
		  if (proc) {
			if (const NetBlock*blk = dynamic_cast<const NetBlock*>(proc))
			      return blk->proc_first() != 0;
			return true;
		  }
	    }
	    // task_def() null or proc null: check pform body
	    if (const PTask*ptask = scope->task_pform())
		  return ptask->get_statement() != 0;
	    return false;

	  default:
	    return false;
      }
}

static void collect_unique_method_overrides_(const netclass_t*base_type,
					     perm_string method_name,
					     NetScope::TYPE method_type,
					     vector<NetScope*>&matches)
{
      if (!base_type || matches.size() > 1)
	    return;

      for (const netclass_t*derived : base_type->derived_types()) {
	    if (!derived)
		  continue;

	    NetScope*class_scope = const_cast<NetScope*>(derived->class_scope());
	    if (class_scope) {
		  const NetScope*override_scope = class_scope->child(hname_t(method_name));
		  if (override_scope && override_scope->type() == method_type
		      && method_scope_has_concrete_body_(override_scope)) {
			matches.push_back(const_cast<NetScope*>(override_scope));
			if (matches.size() > 1)
			      return;
		  }
	    }

	    collect_unique_method_overrides_(derived, method_name, method_type, matches);
	    if (matches.size() > 1)
		  return;
      }
}

}

netclass_t::netclass_t(perm_string name, const netclass_t*super)
: name_(name), super_(super), class_scope_(0), definition_scope_(0),
  virtual_class_(false), interface_type_(false),
  sig_elaborated_(false), sig_elaborating_(false),
  props_declaring_(false),
  body_elaborated_(false), body_elaborating_(false),
  scope_ready_(false),
  specialized_instance_(false)
{
}

netclass_t::~netclass_t()
{
}

void netclass_t::add_derived_type_(const netclass_t*derived)
{
      if (!derived)
	    return;

      for (const netclass_t*cur : derived_types_) {
	    if (cur == derived)
		  return;
      }

      derived_types_.push_back(derived);
}

void netclass_t::set_super(const netclass_t*super)
{
      if (super_ == super)
	    return;

      assert(super_ == 0 || super == 0);
      super_ = super;
      if (super_)
	    const_cast<netclass_t*>(super_)->add_derived_type_(this);
}

bool netclass_t::set_property(perm_string pname, property_qualifier_t qual,
			      ivl_type_t ptype)
{
      map<perm_string,size_t>::const_iterator cur;
      cur = properties_.find(pname);
      if (cur != properties_.end())
	    return false;

      prop_t tmp;
      tmp.name = pname;
      tmp.qual = qual;
      tmp.type = ptype;
      tmp.initialized_flag = false;
      property_table_.push_back(tmp);

      properties_[pname] = property_table_.size()-1;


      return true;
}

void netclass_t::repair_property_type(perm_string pname, ivl_type_t new_type)
{
      map<perm_string,size_t>::const_iterator cur = properties_.find(pname);
      if (cur == properties_.end())
	    return;   // not yet declared, nothing to repair
      property_table_[cur->second].type = new_type;
}

bool netclass_t::add_clocking_block(perm_string name,
				    const PEventStatement*event,
				    const vector<perm_string>&signals)
{
      if (clocking_blocks_.find(name) != clocking_blocks_.end())
	    return false;

      clocking_block_t tmp;
      tmp.name = name;
      tmp.event = event;
      tmp.signals = signals;
      clocking_table_.push_back(tmp);
      clocking_blocks_[name] = clocking_table_.size() - 1;
      return true;
}

const netclass_t::clocking_block_t* netclass_t::find_clocking_block(perm_string name) const
{
      map<perm_string,size_t>::const_iterator cur = clocking_blocks_.find(name);
      if (cur == clocking_blocks_.end())
	    return 0;

      return &clocking_table_[cur->second];
}

void netclass_t::set_class_scope(NetScope*class_scope__)
{
      assert(class_scope_ == 0);
      class_scope_ = class_scope__;
}

void netclass_t::set_definition_scope(NetScope*use_definition_scope)
{
      assert(definition_scope_ == 0);
      definition_scope_ = use_definition_scope;
}

int netclass_t::ensure_property_decl(Design*des, perm_string pname)
{
      int pidx = property_idx_from_name(pname);
      if (pidx >= 0 || !des)
	    return pidx;

      if (super_) {
	    pidx = const_cast<netclass_t*>(super_)->ensure_property_decl(des, pname);
	    if (pidx >= 0)
		  return property_idx_from_name(pname);
      }

      if (!class_scope_)
	    return -1;

      const PClass*pclass = class_scope_->class_pform();
      if (!pclass || !pclass->type)
	    return -1;

      if (pclass->type->properties.find(pname) == pclass->type->properties.end())
	    return -1;

      for (std::vector<perm_string>::const_iterator name_it =
                  pclass->type->property_order.begin()
             ; name_it != pclass->type->property_order.end() ; ++name_it) {
            map<perm_string,struct class_type_t::prop_info_t>::const_iterator cur =
                  pclass->type->properties.find(*name_it);
            assert(cur != pclass->type->properties.end());
            ivl_type_t use_type = 0;

            if (properties_.find(cur->first) != properties_.end())
                  continue;

            if (const typeref_t*type_ref =
                        dynamic_cast<const typeref_t*>(cur->second.type.get())) {
                  typedef_t*td = type_ref->typedef_ref();
                  if (td && td->name == get_name() && type_ref->parameter_values()) {
                        // Self-referential parameterized class properties such as
                        // uvm_callbacks#(T,uvm_callback) m_base_inst should reuse the
                        // current class handle type for member lookup instead of
                        // recursively specializing the same class again.
                        use_type = this;
                  }
            }

            if (!use_type)
                  use_type = cur->second.type->elaborate_type(des, class_scope_);
            if (!use_type)
                  return -1;

            bool added = set_property(cur->first, cur->second.qual, use_type);
            if (added && cur->second.qual.test_static()) {
                  if (class_scope_->find_signal(cur->first) == 0)
                        /* NetNet*sig = */ new NetNet(class_scope_, cur->first,
                                                     NetNet::REG, use_type);
            }
      }

      return property_idx_from_name(pname);
}

// Ensure ALL properties in this class and its entire super chain are declared.
// This stabilises get_properties() so that property_idx_from_name() returns
// correct absolute indices even when called during incremental elaboration
// (before the super chain's elaborate_sig has finished).
void netclass_t::ensure_all_properties_declared(Design*des)
{
      if (!des) return;
      if (sig_elaborated_) return;   // already fully done by elaborate_sig
      if (props_declaring_) return;  // re-entry guard
      props_declaring_ = true;

      // Recurse so ancestors are fully declared first.
      if (super_)
            const_cast<netclass_t*>(super_)->ensure_all_properties_declared(des);

      // Add any properties not yet in our properties_ map, and repair
      // properties that were stored with the wrong type (e.g. netvector
      // integer-handle fallback from a circular elaboration detection).
      if (class_scope_) {
            const PClass*pclass = class_scope_->class_pform();
            if (pclass && pclass->type) {
                  for (std::vector<perm_string>::const_iterator name_it =
                              pclass->type->property_order.begin()
                       ; name_it != pclass->type->property_order.end()
                       ; ++name_it) {

                        map<perm_string,struct class_type_t::prop_info_t>::const_iterator cur =
                              pclass->type->properties.find(*name_it);
                        if (cur == pclass->type->properties.end())
                              continue;

                        // Check if already declared with wrong type.
                        map<perm_string,size_t>::iterator already =
                              properties_.find(*name_it);
                        if (already != properties_.end()) {
                              // If the property is stored as a non-class type but the parse form
                              // says it should be a class, try to re-elaborate the type now that
                              // more classes may be visible (circular-fallback repair).
                              ivl_type_t stored = property_table_[already->second].type;
                              bool needs_repair =
                                    !dynamic_cast<const netclass_t*>(stored)
                                    && (dynamic_cast<const class_type_t*>(cur->second.type.get())
                                        || dynamic_cast<const typeref_t*>(cur->second.type.get()));
                              if (needs_repair) {
                                    ivl_type_t repaired = cur->second.type->elaborate_type(des, class_scope_);
                                    if (dynamic_cast<const netclass_t*>(repaired))
                                          property_table_[already->second].type = repaired;
                              }
                              continue;
                        }

                        ivl_type_t use_type = 0;

                        if (const typeref_t*type_ref =
                                    dynamic_cast<const typeref_t*>(cur->second.type.get())) {
                              typedef_t*td = type_ref->typedef_ref();
                              if (td && td->name == get_name()
                                  && type_ref->parameter_values()) {
                                    use_type = this;
                              }
                        }

                        if (!use_type)
                              use_type = cur->second.type->elaborate_type(des, class_scope_);
                        if (!use_type)
                              continue;   // skip unresolvable types

                        bool added = set_property(cur->first, cur->second.qual, use_type);
                        if (added && cur->second.qual.test_static()) {
                              if (class_scope_->find_signal(cur->first) == 0)
                                    new NetNet(class_scope_, cur->first,
                                               NetNet::REG, use_type);
                        }
                  }
            }
      }

      props_declaring_ = false;
}

ivl_variable_type_t netclass_t::base_type() const
{
      return IVL_VT_CLASS;
}

size_t netclass_t::get_properties(void) const
{
      size_t res = properties_.size();
      if (super_) res += super_->get_properties();
      return res;
}

int netclass_t::property_idx_from_name(perm_string pname) const
{
      map<perm_string,size_t>::const_iterator cur;
      cur = properties_.find(pname);
      if (cur == properties_.end()) {
	    if (super_)
		  return super_->property_idx_from_name(pname);
	    else
		  return -1;
      }

      int pidx = cur->second;
      if (super_) pidx += super_->get_properties();
      return pidx;
}

const char*netclass_t::get_prop_name(size_t idx) const
{
      size_t super_size = 0;
      if (super_) super_size = super_->get_properties();

      assert(idx < (super_size + property_table_.size()));
      if (idx < super_size)
	    return super_->get_prop_name(idx);
      else
	    return property_table_[idx-super_size].name;
}

property_qualifier_t netclass_t::get_prop_qual(size_t idx) const
{
      size_t super_size = 0;
      if (super_) super_size = super_->get_properties();

      assert(idx < (super_size+property_table_.size()));
      if (idx < super_size)
	    return super_->get_prop_qual(idx);
      else
	    return property_table_[idx-super_size].qual;
}

ivl_type_t netclass_t::get_prop_type(size_t idx) const
{
      size_t super_size = 0;
      if (super_) super_size = super_->get_properties();

      assert(idx < (super_size+property_table_.size()));
      if (idx < super_size)
	    return super_->get_prop_type(idx);
      else
	    return property_table_[idx-super_size].type;
}

bool netclass_t::get_prop_initialized(size_t idx) const
{
      size_t super_size = 0;
      if (super_) super_size = super_->get_properties();

      assert(idx < (super_size+property_table_.size()));
      if (idx < super_size)
	    return super_->get_prop_initialized(idx);
      else
	    return property_table_[idx].initialized_flag;
}

void netclass_t::set_prop_initialized(size_t idx) const
{
      size_t super_size = 0;
      if (super_) super_size = super_->get_properties();

      assert(idx >= super_size && idx < (super_size+property_table_.size()));
      idx -= super_size;

      assert(! property_table_[idx].initialized_flag);
      property_table_[idx].initialized_flag = true;
}

bool netclass_t::test_for_missing_initializers() const
{
      for (size_t idx = 0 ; idx < property_table_.size() ; idx += 1) {
	    if (property_table_[idx].initialized_flag)
		  continue;
	    if (property_table_[idx].qual.test_const())
		  return true;
      }

      return false;
}

NetScope*netclass_t::method_from_name(perm_string name) const
{
      NetScope*task = 0;
      if (class_scope_)
	    task = class_scope_->child( hname_t(name) );
      if ((task == 0) && super_)
	    task = super_->method_from_name(name);
      return task;

}

NetScope*netclass_t::resolve_method_call_scope(const Design*des, perm_string name) const
{
      // For interface types, the netclass_t is created (and cached) before
      // the interface's actual instance scope is elaborated, so class_scope_
      // is often null at method-dispatch time. Look it up lazily by walking
      // the design's root scopes for a MODULE child whose module_name matches
      // this interface's name. Once found, attach it so subsequent lookups
      // hit the fast path.
      if (interface_type_ && class_scope_ == nullptr && des) {
            NetScope*found = nullptr;
            for (NetScope*root_scope : const_cast<Design*>(des)->find_root_scopes()) {
                  for (auto&kv : root_scope->children()) {
                        NetScope*child = kv.second;
                        if (!child || child->type() != NetScope::MODULE)
                              continue;
                        if (child->module_name() == get_name()) {
                              found = child;
                              break;
                        }
                  }
                  if (found) break;
            }
            if (found) {
                  // const_cast is safe here -- this is a one-shot lazy
                  // attachment, observed only on the first method dispatch.
                  const_cast<netclass_t*>(this)->set_class_scope(found);
            }
      }

      NetScope*method = method_from_name(name);
      if (!method) {
	    const char*trace = getenv("IVL_CLASS_METHOD_TRACE");
	    if (trace && *trace && class_scope_
		&& (name == perm_string::literal("start")
		    || name == perm_string::literal("atomic_lock")
		    || name == perm_string::literal("atomic_unlock"))) {
		  cerr << "trace method-miss class=" << get_name()
		       << " scope=" << scope_path(class_scope_)
		       << " scope_ready=" << scope_ready()
		       << " class_pform=" << (const void*)(class_scope_ ? class_scope_->class_pform() : 0)
		       << " want=" << name
		       << " children={";
		  bool first = true;
		  for (const auto&cur : class_scope_->children()) {
			if (!first)
			      cerr << ", ";
			first = false;
			cerr << cur.first.peek_name();
			if (cur.second)
			      cerr << ":" << cur.second->type();
		  }
		  cerr << "}" << endl;
	    }
      }
      if (!method)
	    return 0;

      if (method_scope_has_concrete_body_(method))
	    return method;

      vector<NetScope*>matches;
      collect_unique_method_overrides_(this, name, method->type(), matches);

      if (matches.size() == 1)
	    return matches[0];

      return method;
}

NetScope* netclass_t::get_constructor() const
{
      auto task = class_scope_ ? class_scope_->child(hname_t(perm_string::literal("new"))) : nullptr;
      if (task)
	    return task;

      task = class_scope_ ? class_scope_->child(hname_t(perm_string::literal("new@"))) : nullptr;
      if (task)
	    return task;

      if (super_)
	    return super_->get_constructor();

      return nullptr;
}

NetNet* netclass_t::find_static_property(perm_string name) const
{
      NetNet *net = class_scope_->find_signal(name);
      if (net)
	    return net;

      if (super_)
	    return super_->find_static_property(name);

      return nullptr;
}

bool netclass_t::test_scope_is_method(const NetScope*scope) const
{
      while (scope && scope != class_scope_) {
	    scope = scope->parent();
      }

      if (scope == 0)
	    return false;
      else
	    return true;
}

const NetExpr* netclass_t::get_parameter(Design *des, perm_string name,
					 ivl_type_t &par_type) const
{
      if (class_scope_ == 0) {
	    par_type = 0;
	    return 0;
      }
      return class_scope_->get_parameter(des, name, par_type);
}

bool netclass_t::test_compatibility(ivl_type_t that) const
{
      for (const netclass_t *class_type = dynamic_cast<const netclass_t *>(that);
	    class_type; class_type = class_type->get_super()) {
	    if (class_type == this)
		  return true;
      }

      return false;
}

void netclass_t::add_constraint_ir(const string&name, const string&ir)
{
      constraint_ir_t c;
      c.name = name;
      c.ir = ir;
      constraint_irs_.push_back(c);
}

void netclass_t::add_covgrp_bin(unsigned cp, unsigned prop, uint64_t lo, uint64_t hi,
				unsigned kind)
{
      covgrp_bin_t b;
      b.cp_idx   = cp;
      b.prop_idx = prop;
      b.lo = lo;
      b.hi = hi;
      b.kind = kind;
      covgrp_bins_.push_back(b);
}

const string& netclass_t::constraint_ir_name(size_t idx) const
{
      return constraint_irs_[idx].name;
}

const string& netclass_t::constraint_ir_str(size_t idx) const
{
      return constraint_irs_[idx].ir;
}
