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
		  if (const NetBlock*blk = dynamic_cast<const NetBlock*>(proc))
			return blk->proc_first() != 0;
		  return proc != 0;
	    }
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
      (void) des;

      NetScope*method = method_from_name(name);
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
