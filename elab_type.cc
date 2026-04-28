/*
 * Copyright (c) 2012-2024 Stephen Williams (steve@icarus.com)
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

# include  "PExpr.h"
# include  "PClass.h"
# include  "PScope.h"
# include  "PWire.h"
# include  "Module.h"
# include  "compiler.h"
# include  "pform.h"
# include  "parse_api.h"
# include  "pform_types.h"
# include  "netlist.h"
# include  "netclass.h"
# include  "netdarray.h"
# include  "netenum.h"
# include  "netqueue.h"
# include  "netparray.h"
# include  "netscalar.h"
# include  "netstruct.h"
# include  "netvector.h"
# include  "netmisc.h"
# include  <set>
# include  <sstream>
# include  <typeinfo>
# include  <cstring>
# include  "ivl_assert.h"

using namespace std;

namespace {

static bool pexpr_matches_parameter_name_(const PExpr*expr, perm_string name)
{
      if (const PEIdent*ident = dynamic_cast<const PEIdent*>(expr)) {
	    const pform_scoped_name_t&path = ident->path();
	    if (path.package == 0 && path.name.size() == 1 &&
	        path.name.front().index.empty() &&
	        path.name.front().name == name)
		  return true;
      }

      if (const PETypename*type_expr = dynamic_cast<const PETypename*>(expr)) {
	    if (const type_parameter_t*type_param =
	        dynamic_cast<const type_parameter_t*>(type_expr->get_type())) {
		  if (type_param->name == name)
			return true;
	    }

	    if (const typeref_t*type_ref =
	        dynamic_cast<const typeref_t*>(type_expr->get_type())) {
		  if (type_ref->scope_ref() == 0 && type_ref->parameter_values() == 0) {
			if (typedef_t*td = type_ref->typedef_ref()) {
			      if (td->name == name)
				    return true;
			}
		  }
	    }
      }

      return false;
}

static bool overrides_match_parameter_order_(const parmvalue_t*overrides,
					     const std::list<perm_string>&param_order)
{
      if (!overrides || !overrides->by_order)
	    return false;

      std::list<PExpr*>::const_iterator expr_it = overrides->by_order->begin();
      std::list<perm_string>::const_iterator name_it = param_order.begin();
      while (expr_it != overrides->by_order->end() && name_it != param_order.end()) {
	    if (!*expr_it || !pexpr_matches_parameter_name_(*expr_it, *name_it))
		  return false;
	    ++expr_it;
	    ++name_it;
      }

      return expr_it == overrides->by_order->end() && name_it == param_order.end();
}

static const netclass_t* resolve_current_class_typeref_(NetScope*scope,
							const typeref_t*type_ref)
{
      if (!scope || !type_ref)
	    return 0;

      const NetScope*class_scope = scope->get_class_scope();
      const netclass_t*current_class = class_scope ? class_scope->class_def() : 0;
      const PClass*current_pclass = class_scope ? class_scope->class_pform() : 0;
      if (!current_class || !current_pclass)
	    return 0;

      typedef_t*td = type_ref->typedef_ref();
      if (!td)
	    return 0;

      const parmvalue_t*overrides = type_ref->parameter_values();
      if (td->name == current_class->get_name()) {
	    if (!overrides
	        || overrides_match_parameter_order_(overrides, current_pclass->parameter_order))
		  return current_class;
      }

      const data_type_t*alias_type = td->get_data_type();
      if (!alias_type)
	    return 0;

      if (const class_type_t*class_ref =
	          dynamic_cast<const class_type_t*>(alias_type)) {
	    if (class_ref->name == current_class->get_name() && !overrides)
		  return current_class;
      }

      if (const typeref_t*alias_ref =
	          dynamic_cast<const typeref_t*>(alias_type)) {
	    return resolve_current_class_typeref_(scope, alias_ref);
      }

      return 0;
}

static ivl_type_t resolve_circular_class_handle_type_(Design*des,
						      NetScope*scope,
						      const data_type_t*type_pf,
						      set<const typedef_t*>&seen);

static ivl_type_t resolve_circular_typedef_alias_class_handle_type_(Design*des,
								    NetScope*scope,
								    typedef_t*td,
								    set<const typedef_t*>&seen)
{
      if (!td || !td->get_data_type())
	    return 0;

      pair<set<const typedef_t*>::iterator,bool> insert_rc = seen.insert(td);
      if (!insert_rc.second)
	    return 0;

      return resolve_circular_class_handle_type_(des, scope, td->get_data_type(), seen);
}

static ivl_type_t resolve_circular_class_handle_type_(Design*des,
						      NetScope*scope,
						      const data_type_t*type_pf,
						      set<const typedef_t*>&seen)
{
      if (!des || !scope || !type_pf)
	    return 0;

      if (const class_type_t*class_pf = dynamic_cast<const class_type_t*>(type_pf))
	    return ensure_visible_class_type(des, scope, class_pf->name);

      if (const type_parameter_t*type_par = dynamic_cast<const type_parameter_t*>(type_pf)) {
	    ivl_type_t par_type = 0;
	    scope->get_parameter(des, type_par->name, par_type);
	    if (dynamic_cast<const netclass_t*>(par_type))
		  return par_type;
	    return 0;
      }

      const typeref_t*type_ref = dynamic_cast<const typeref_t*>(type_pf);
      if (!type_ref)
	    return 0;

      NetScope*type_scope = type_ref->find_scope(des, scope);
      if (!type_scope)
	    return 0;

      if (const netclass_t*self_class = resolve_current_class_typeref_(type_scope, type_ref))
	    return const_cast<netclass_t*>(self_class);

      typedef_t*td = type_ref->typedef_ref();
      if (!td)
	    return 0;

      if (ivl_type_t alias_class =
		  resolve_circular_typedef_alias_class_handle_type_(des, type_scope, td, seen)) {
	    if (const parmvalue_t*overrides = type_ref->parameter_values()) {
		  if (const netclass_t*base_class =
			      dynamic_cast<const netclass_t*>(alias_class))
			return const_cast<netclass_t*>(
			      elaborate_specialized_class_type(des, type_scope, base_class,
						       overrides, false));
	    }
	    return alias_class;
      }

      netclass_t*base_class = ensure_visible_class_type(des, type_scope, td->name);
      if (!base_class)
	    return 0;

      if (const parmvalue_t*overrides = type_ref->parameter_values())
	    return const_cast<netclass_t*>(
		  elaborate_specialized_class_type(des, type_scope, base_class, overrides,
						   false));

      return base_class;
}

static ivl_type_t resolve_circular_class_handle_type_(Design*des,
						      NetScope*scope,
						      const data_type_t*type_pf)
{
      set<const typedef_t*>seen;
      return resolve_circular_class_handle_type_(des, scope, type_pf, seen);
}

netclass_t* make_builtin_process_type_()
{
      static netclass_t*builtin_process_type = nullptr;
      if (!builtin_process_type) {
	    builtin_process_type = new netclass_t(perm_string::literal("process"), 0);
	    builtin_process_type->set_property(perm_string::literal("status"),
					       property_qualifier_t::make_none(),
					       &netvector_t::atom2s32);
      }
      return builtin_process_type;
}

netclass_t* make_builtin_semaphore_type_()
{
      static netclass_t*builtin_semaphore_type = nullptr;
      if (!builtin_semaphore_type)
	    builtin_semaphore_type = new netclass_t(perm_string::literal("semaphore"), 0);
      return builtin_semaphore_type;
}

netclass_t* make_builtin_mailbox_type_()
{
      static netclass_t*builtin_mailbox_type = nullptr;
      if (!builtin_mailbox_type)
	    builtin_mailbox_type = new netclass_t(perm_string::literal("mailbox"), 0);
      return builtin_mailbox_type;
}

static map<Module*, netclass_t*> interface_type_cache_;

static netclass_t* elaborate_interface_type_(Design*des, NetScope*scope, Module*mod)
{
      map<Module*, netclass_t*>::const_iterator found = interface_type_cache_.find(mod);
      if (found != interface_type_cache_.end())
	    return found->second;

      netclass_t*iface_type = new netclass_t(mod->mod_name(), 0);
      iface_type->set_interface(true);
      iface_type->set_definition_scope(scope);
      interface_type_cache_[mod] = iface_type;

      // Use the interface module's own root scope (which has its parameters
      // bound to defaults) instead of the calling scope (which may be a class
      // scope that doesn't contain the interface's parameter names).
      // This avoids "Unable to bind parameter" errors for parameterized
      // interfaces used as virtual interface types in parameterized classes.
      //
      // Two cases where the normal root scope isn't ready:
      //  1. The interface is also instantiated in the design (tb.sv), so it
      //     is not in root_scopes_ — its scope is created later via PGModule.
      //  2. The root scope exists but hasn't had its parameters collected yet
      //     because packages elaborate before root-scope work items run.
      // In both cases we build a minimal temporary scope from the module's
      // pform parameters so wire dimensions can be resolved.
      NetScope*iface_scope = des->find_scope(hname_t(mod->mod_name()));
      NetScope*temp_scope = nullptr;
      if (!iface_scope || (iface_scope->parameters.empty() && !mod->parameters.empty())) {
	    if (!iface_scope) {
		  // Interface is NOT a root — create a disposable scope.
		  temp_scope = new NetScope(nullptr, hname_t(mod->mod_name()),
					   NetScope::MODULE, nullptr,
					   false, false, true, false);
		  iface_scope = temp_scope;
	    }
	    // Pre-populate default parameters so dimension expressions resolve.
	    for (auto& kv : mod->parameters)
		  iface_scope->set_parameter(kv.first, false, *kv.second, nullptr);
      }

      for (map<perm_string,PWire*>::const_iterator cur = mod->wires.begin()
		 ; cur != mod->wires.end() ; ++cur) {
	    ivl_type_t prop_type = cur->second->elaborate_sig_type(des, iface_scope);
	    iface_type->set_property(cur->first, property_qualifier_t::make_none(),
				     prop_type);
      }

      for (map<perm_string,Module::PClocking*>::const_iterator cur = mod->clocking_blocks.begin()
		 ; cur != mod->clocking_blocks.end() ; ++cur) {
	    iface_type->add_clocking_block(cur->first, cur->second->event,
					   cur->second->signals);
      }

      // If a real interface instance scope exists somewhere in the design,
      // attach it as the netclass_t's class_scope so virtual-interface method
      // dispatch (`vif.task()` / `vif.func()`) can find the per-instance task
      // and function child scopes. Without this, `method_from_name` returns
      // null and the elaborator falls into the "scope incomplete" warn-and-noop
      // path. module_name() asserts type_==MODULE||PACKAGE, so we must guard
      // the call when walking arbitrary children.
      NetScope*method_scope = des->find_scope(hname_t(mod->mod_name()));
      if (method_scope && method_scope->type() != NetScope::MODULE)
            method_scope = nullptr;
      if (!method_scope) {
            // The interface might be instantiated as a child of some other
            // module (the typical OpenTitan tb.sv pattern). Walk every root
            // scope and its MODULE children whose module_name matches.
            for (NetScope*root_scope : des->find_root_scopes()) {
                  for (auto&kv : root_scope->children()) {
                        NetScope*child = kv.second;
                        if (!child || child->type() != NetScope::MODULE)
                              continue;
                        if (child->module_name() == mod->mod_name()) {
                              method_scope = child;
                              break;
                        }
                  }
                  if (method_scope) break;
            }
      }
      if (method_scope && iface_type->class_scope() == nullptr)
            iface_type->set_class_scope(method_scope);

      // Do NOT set scope_ready=true: when class_scope_ is null at the time
      // of method dispatch (because the interface's instance scope hasn't
      // been elaborated yet), the elaborator's NOOP fallback is the safe
      // path. The lazy lookup in `resolve_method_call_scope` upgrades this
      // to a real call when an instance is available.

      delete temp_scope;
      return iface_type;
}

}

netclass_t* builtin_class_type(perm_string name)
{
      if (name == perm_string::literal("process"))
	    return make_builtin_process_type_();
      if (name == perm_string::literal("semaphore"))
	    return make_builtin_semaphore_type_();
      if (name == perm_string::literal("mailbox"))
	    return make_builtin_mailbox_type_();
      return nullptr;
}

// When a typeref_t with package-scoped overrides is being elaborated, this
// holds the original caller scope so override expressions (e.g. #(.AddrWidth(AddrWidth)))
// can be evaluated in the scope where the type reference appears rather than in
// the package that defines the class.
static NetScope* s_type_elaborate_caller_scope_ = nullptr;

/*
 * Elaborations of types may vary depending on the scope that it is
 * done in, so keep a per-scope cache of the results.
 */
ivl_type_t data_type_t::elaborate_type(Design*des, NetScope*scope)
{
      // Save the caller scope before find_scope changes it. typeref_t uses
      // this to pass the correct call_scope to elaborate_specialized_class_type.
      NetScope* saved_caller_scope = s_type_elaborate_caller_scope_;
      s_type_elaborate_caller_scope_ = scope;

      scope = find_scope(des, scope);

      Definitions*use_definitions = scope;

      map<Definitions*,ivl_type_t>::iterator pos = cache_type_elaborate_.lower_bound(use_definitions);
	  if (pos != cache_type_elaborate_.end() && pos->first == use_definitions) {
	     s_type_elaborate_caller_scope_ = saved_caller_scope;
	     return pos->second;
	  }

      ivl_type_t tmp;
      if (elaborating) {
	    tmp = resolve_circular_class_handle_type_(des, scope, this);
	    if (!tmp) {
		  des->errors++;
		  cerr << get_fileline() << ": error: "
		       << "Circular type definition found involving `" << *this << "`."
		       << endl;
		  // Try to recover
		  tmp = netvector_t::integer_type();
	    }
      } else {
	    elaborating = true;
	    tmp = elaborate_type_raw(des, scope);
	    elaborating = false;
      }

      if (tmp)
	    cache_type_elaborate_.insert(pos, pair<NetScope*,ivl_type_t>(scope, tmp));
      s_type_elaborate_caller_scope_ = saved_caller_scope;  // always restore
      return tmp;
}

NetScope *data_type_t::find_scope(Design *, NetScope *scope) const
{
	return scope;
}

ivl_type_t data_type_t::elaborate_type_raw(Design*des, NetScope*) const
{
      cerr << get_fileline() << ": internal error: "
	   << "Elaborate method not implemented for " << typeid(*this).name()
	   << "." << endl;
      des->errors += 1;
      return 0;
}

ivl_type_t atom_type_t::elaborate_type_raw(Design*des, NetScope*) const
{
      switch (type_code) {
	  case INTEGER:
	    return netvector_t::integer_type(signed_flag);

	  case TIME:
	    if (signed_flag)
		  return &netvector_t::time_signed;
	    else
		  return &netvector_t::time_unsigned;

	  case LONGINT:
	    if (signed_flag)
		  return &netvector_t::atom2s64;
	    else
		  return &netvector_t::atom2u64;

	  case INT:
	    if (signed_flag)
		  return &netvector_t::atom2s32;
	    else
		  return &netvector_t::atom2u32;

	  case SHORTINT:
	    if (signed_flag)
		  return &netvector_t::atom2s16;
	    else
		  return &netvector_t::atom2u16;

	  case BYTE:
	    if (signed_flag)
		  return &netvector_t::atom2s8;
	    else
		  return &netvector_t::atom2u8;

	  default:
	    cerr << get_fileline() << ": internal error: "
		 << "atom_type_t type_code=" << type_code << "." << endl;
	    des->errors += 1;
	    return 0;
      }
}

static string foreach_target_path_string_(const vector<perm_string>&target_path)
{
      ostringstream ss;
      for (size_t idx = 0 ; idx < target_path.size() ; idx += 1) {
	    if (idx > 0)
		  ss << ".";
	    ss << target_path[idx];
      }
      return ss.str();
}

static const PWire* find_foreach_array_placeholder_(NetScope*scope,
						    const vector<perm_string>&target_path)
{
      if (target_path.size() != 1)
	    return 0;

      perm_string name = target_path.front();
      for (NetScope*cur = scope ; cur ; cur = cur->parent()) {
	    if (PWire*wire = cur->find_signal_placeholder(name))
		  return wire;
      }

      return 0;
}

static const data_type_t* unwrap_foreach_array_type_alias_(const data_type_t*type_pf)
{
      std::set<const typedef_t*>seen;

      while (const typeref_t*type_ref = dynamic_cast<const typeref_t*>(type_pf)) {
	    typedef_t*td = type_ref->typedef_ref();
	    if (!td || !td->get_data_type())
		  break;
	    if (!seen.insert(td).second)
		  break;
	    type_pf = td->get_data_type();
      }

      return type_pf;
}

static const data_type_t* find_foreach_assoc_index_type_in_data_type_(
		const data_type_t*type_pf, size_t index_depth)
{
      type_pf = unwrap_foreach_array_type_alias_(type_pf);
      if (!type_pf)
	    return 0;

      const uarray_type_t*uarray = dynamic_cast<const uarray_type_t*>(type_pf);
      if (!uarray)
	    return 0;

      if (uarray->dims && index_depth < uarray->dims->size()) {
	    list<pform_range_t>::const_iterator cur = uarray->dims->begin();
	    std::advance(cur, index_depth);
	    if (const PEAssocType*assoc_idx = dynamic_cast<const PEAssocType*>(cur->first))
		  return assoc_idx->index_type();
	    return 0;
      }

      if (!uarray->dims)
	    return 0;

      return find_foreach_assoc_index_type_in_data_type_(
	    uarray->base_type.get(), index_depth - uarray->dims->size());
}

static const data_type_t* find_foreach_wire_index_type_(
		const PWire*wire, size_t index_depth)
{
      if (!wire)
	    return 0;

      const list<pform_range_t>&unpacked = wire->unpacked_indices();
      if (index_depth < unpacked.size()) {
	    list<pform_range_t>::const_iterator cur = unpacked.begin();
	    advance(cur, index_depth);
	    if (const PEAssocType*assoc_idx = dynamic_cast<const PEAssocType*>(cur->first))
		  return assoc_idx->index_type();
      }

      return find_foreach_assoc_index_type_in_data_type_(wire->data_type(), index_depth);
}

static const data_type_t* find_foreach_simple_class_property_index_type_(
		NetScope*scope, perm_string name, size_t index_depth)
{
	// Look up `name` in the immediate class scope, walking up the super
	// class chain when the property is inherited (a derived class's pform
	// only contains its own declarations, not those of its base classes).
      const NetScope*class_scope = scope ? scope->get_class_scope() : 0;
      const netclass_t*search_class = class_scope ? class_scope->class_def() : 0;
      (void)index_depth;
      while (search_class) {
            const NetScope*sc = search_class->class_scope();
            const PClass*pclass = sc ? sc->class_pform() : 0;
            if (pclass && pclass->type) {
                  std::map<perm_string,class_type_t::prop_info_t>::const_iterator pcur =
                        pclass->type->properties.find(name);
                  if (pcur != pclass->type->properties.end()
                      && pcur->second.type.get())
                        // Return the property's full data_type_t; the caller
                        // (find_foreach_class_property_index_type_) extracts
                        // the index dimension via
                        // find_foreach_assoc_index_type_in_data_type_.
                        return pcur->second.type.get();
            }
            search_class = search_class->get_super();
      }

	// Fall back to the original scope-tree walk (e.g. for non-class
	// scopes that nonetheless host a class_pform).
      for (NetScope*cur = scope ; cur ; cur = cur->parent()) {
	    const PClass*pclass = cur->class_pform();
	    if (!pclass || !pclass->type)
		  continue;

	    std::map<perm_string,class_type_t::prop_info_t>::const_iterator pcur =
		  pclass->type->properties.find(name);
	    if (pcur == pclass->type->properties.end())
		  continue;

	    return find_foreach_assoc_index_type_in_data_type_(
		  pcur->second.type.get(), index_depth);
      }

      return 0;
}

static bool find_foreach_path_root_type_(Design*des, NetScope*scope,
					 perm_string name,
					 ivl_type_t&root_type)
{
      root_type = 0;

      if (name == perm_string::literal(THIS_TOKEN)) {
	    const NetScope*class_scope = scope ? scope->get_class_scope() : 0;
	    if (!class_scope)
		  return false;
	    root_type = const_cast<netclass_t*>(class_scope->class_def());
	    return root_type != 0;
      }

      if (name == perm_string::literal(SUPER_TOKEN)) {
	    const NetScope*class_scope = scope ? scope->get_class_scope() : 0;
	    const netclass_t*class_type = class_scope ? class_scope->class_def() : 0;
	    const netclass_t*super_type = class_type ? class_type->get_super() : 0;
	    if (!super_type)
		  return false;
	    root_type = const_cast<netclass_t*>(super_type);
	    return true;
      }

      for (NetScope*cur = scope ; cur ; cur = cur->parent()) {
	    if (PWire*wire = cur->find_signal_placeholder(name))
		  root_type = wire->elaborate_sig_type(des, cur);

	    if (root_type)
		  return true;

	    const PClass*pclass = cur->class_pform();
	    if (!pclass || !pclass->type)
		  continue;

	    // Look for the property in this class first; if not found,
	    // walk up the super-class chain. A class's own pform only
	    // lists declarations made directly in that class -- if `cfg`
	    // is inherited (e.g. cip_base_env extends dv_base_env where
	    // dv_base_env declares cfg), the immediate pform has no
	    // entry for `cfg` but a super pform does.
	    const PClass*search_pclass = pclass;
	    const netclass_t*search_class = cur->class_def();
	    map<perm_string,class_type_t::prop_info_t>::const_iterator pcur =
		  search_pclass->type->properties.find(name);
	    while (pcur == search_pclass->type->properties.end()
	           && search_class) {
		  search_class = search_class->get_super();
		  if (!search_class) break;
		  const NetScope*sc = search_class->class_scope();
		  search_pclass = sc ? sc->class_pform() : 0;
		  if (!search_pclass || !search_pclass->type) break;
		  pcur = search_pclass->type->properties.find(name);
	    }
	    if (!search_pclass || !search_pclass->type
	        || pcur == search_pclass->type->properties.end())
		  continue;

	    if (!pcur->second.type.get())
		  return false;
	    root_type = const_cast<data_type_t*>(pcur->second.type.get())->elaborate_type(des, cur);
	    return root_type != 0;
      }

      root_type = ensure_visible_class_type(des, scope, name);
      return root_type != 0;
}

// Walk a class's pform property table, then climb the inheritance
// chain until we find the named property (or run out of supers).
// Needed because a foreach over `derived.<prop>` resolves the receiver
// class to the derived class, but the property declaration may live on
// a base class's pform (derived adds no new properties of its own).
static const class_type_t::prop_info_t*
find_class_property_via_inheritance_(const netclass_t*cur_class,
                                     perm_string prop_name)
{
      while (cur_class) {
            const NetScope*class_scope = cur_class->class_scope();
            const PClass*pclass = class_scope ? class_scope->class_pform() : 0;
            if (pclass && pclass->type) {
                  map<perm_string,class_type_t::prop_info_t>::const_iterator pcur =
                        pclass->type->properties.find(prop_name);
                  if (pcur != pclass->type->properties.end()
                      && pcur->second.type.get())
                        return &pcur->second;
            }
            cur_class = cur_class->get_super();
      }
      return 0;
}

static const data_type_t* find_foreach_selected_path_type_(
		Design*des, NetScope*scope, const vector<perm_string>&target_path)
{
      if (target_path.size() < 2)
	    return 0;

      ivl_type_t cur_type = 0;
      if (!find_foreach_path_root_type_(des, scope, target_path.front(), cur_type))
	    return 0;

      for (size_t idx = 1 ; idx < target_path.size() ; idx += 1) {
	    const netclass_t*cur_class = dynamic_cast<const netclass_t*>(cur_type);
	    if (!cur_class)
		  return 0;

	    const class_type_t::prop_info_t*prop =
		  find_class_property_via_inheritance_(cur_class, target_path[idx]);
	    if (!prop)
		  return 0;

	    if (idx + 1 == target_path.size())
		  return prop->type.get();

	    cur_type = const_cast<data_type_t*>(prop->type.get())->elaborate_type(des, scope);
	    if (!cur_type)
		  return 0;
      }

      return 0;
}

static const data_type_t* find_foreach_class_property_index_type_(
		Design*des, NetScope*scope,
		const vector<perm_string>&target_path, size_t index_depth)
{
      const data_type_t*type_pf = 0;

      if (target_path.size() == 1)
	    type_pf = find_foreach_simple_class_property_index_type_(
		  scope, target_path.front(), index_depth);
      else
	    type_pf = find_foreach_selected_path_type_(des, scope, target_path);

      if (!type_pf)
	    return 0;

      return find_foreach_assoc_index_type_in_data_type_(type_pf, index_depth);
}

ivl_type_t foreach_index_type_t::elaborate_type_raw(Design*des, NetScope*scope) const
{
      const char*trace = getenv("IVL_FOREACH_TYPE_TRACE");
      const PWire*array_wire = scope ? find_foreach_array_placeholder_(scope, target_path) : 0;
      const data_type_t*wire_index_type =
	    array_wire ? find_foreach_wire_index_type_(array_wire, index_depth) : 0;
      const data_type_t*class_prop_index_type =
	    scope ? find_foreach_class_property_index_type_(des, scope, target_path, index_depth) : 0;
      string target_path_string = foreach_target_path_string_(target_path);
      if (trace && *trace) {
	    cerr << "foreach-type: scope=";
	    if (scope)
		  cerr << scope_path(scope);
	    else
		  cerr << "<nil>";
	    cerr << " array=" << target_path_string
		 << " depth=" << index_depth
		 << " found_wire=" << (array_wire ? "yes" : "no")
		 << " found_wire_type=" << (wire_index_type ? "yes" : "no")
		 << " found_class_prop=" << (class_prop_index_type ? "yes" : "no");
	    if (array_wire)
		  cerr << " unpacked=" << array_wire->unpacked_indices().size();
	    cerr << endl;
      }
      if (wire_index_type) {
	    if (trace && *trace)
		  cerr << "foreach-type: wire assoc index type resolved for "
		       << target_path_string << "[" << index_depth << "]" << endl;
	    ivl_type_t index_type =
		  const_cast<data_type_t*>(wire_index_type)->elaborate_type(des, scope);
	    if (index_type)
		  return index_type;
      }

      if (class_prop_index_type) {
	    if (trace && *trace)
		  cerr << "foreach-type: class property assoc index type resolved for "
		       << target_path_string << "[" << index_depth << "]"
		       << " kind=" << typeid(*class_prop_index_type).name() << endl;
	    ivl_type_t index_type =
		  const_cast<data_type_t*>(class_prop_index_type)->elaborate_type(des, scope);
	    if (trace && *trace) {
		  cerr << "foreach-type: elaborate_type for " << target_path_string << " returned ";
		  if (index_type)
			cerr << "base=" << ivl_type_base(index_type);
		  else
			cerr << "<nil>";
		  cerr << endl;
	    }
	    if (index_type)
		  return index_type;
      }

      if (trace && *trace)
	    cerr << "foreach-type: fallback to int for "
		 << target_path_string << "[" << index_depth << "]" << endl;
      return size_type.elaborate_type(des, scope);
}

ivl_type_t class_type_t::elaborate_type_raw(Design*des, NetScope*scope) const
{
      return ensure_visible_class_type(des, scope, name);
}

ivl_type_t interface_type_t::elaborate_type_raw(Design*des, NetScope*scope) const
{
      map<perm_string,Module*>::const_iterator cur = pform_modules.find(name);
      if (cur == pform_modules.end() || !cur->second->is_interface) {
	    cerr << get_fileline() << ": error: "
		 << "Unknown interface type `" << name << "'." << endl;
	    des->errors += 1;
	    return 0;
      }

      return elaborate_interface_type_(des, scope, cur->second);
}

/*
 * elaborate_type_raw for enumerations is actually mostly performed
 * during scope elaboration so that the enumeration literals are
 * available at the right time. At that time, the netenum_t* object is
 * stashed in the scope so that I can retrieve it here.
 */
ivl_type_t enum_type_t::elaborate_type_raw(Design *des, NetScope *scope) const
{
      ivl_type_t base = base_type->elaborate_type(des, scope);

      const class netvector_t *vec_type = dynamic_cast<const netvector_t*>(base);

      if (!vec_type && !dynamic_cast<const netparray_t*>(base)) {
	    cerr << get_fileline() << ": error: "
		 << "Invalid enum base type `" << *base << "`."
		 << endl;
	    des->errors++;
      } else if (base->slice_dimensions().size() > 1) {
	    cerr << get_fileline() << ": error: "
		 << "Enum type must not have more than 1 packed dimension."
		 << endl;
	    des->errors++;
      }

      bool integer_flag = false;
      if (vec_type)
	    integer_flag = vec_type->get_isint();

      netenum_t *type = new netenum_t(base, names->size(), integer_flag);
      type->set_line(*this);

      scope->add_enumeration_set(this, type);

      return type;
}

ivl_type_t vector_type_t::elaborate_type_raw(Design*des, NetScope*scope) const
{
      netranges_t packed;
      if (pdims.get())
	    evaluate_ranges(des, scope, this, packed, *pdims);

      netvector_t*tmp = new netvector_t(packed, base_type);
      tmp->set_signed(signed_flag);
      tmp->set_isint(integer_flag);
      tmp->set_implicit(implicit_flag);

      return tmp;
}

ivl_type_t real_type_t::elaborate_type_raw(Design*, NetScope*) const
{
      switch (type_code_) {
	  case REAL:
	    return &netreal_t::type_real;
	  case SHORTREAL:
	    return &netreal_t::type_shortreal;
      }
      return 0;
}

ivl_type_t string_type_t::elaborate_type_raw(Design*, NetScope*) const
{
      return &netstring_t::type_string;
}

ivl_type_t parray_type_t::elaborate_type_raw(Design*des, NetScope*scope) const
{
      netranges_t packed;
      if (dims.get())
	    evaluate_ranges(des, scope, this, packed, *dims);

      ivl_type_t etype = base_type->elaborate_type(des, scope);
      if (!etype->packed()) {
		cerr << this->get_fileline() << " error: Packed array ";
		cerr << "base-type `";
		cerr << *base_type;
		cerr << "` is not packed." << endl;
		des->errors++;
      }

      return new netparray_t(packed, etype);
}

ivl_type_t struct_type_t::elaborate_type_raw(Design*des, NetScope*scope) const
{
      netstruct_t*res = new netstruct_t;

      res->set_line(*this);

      res->packed(packed_flag);
      res->set_signed(signed_flag);

      if (union_flag)
	    res->union_flag(true);

      for (list<struct_member_t*>::iterator cur = members->begin()
		 ; cur != members->end() ; ++ cur) {

	      // Elaborate the type of the member.
	    struct_member_t*curp = *cur;
	    ivl_type_t mem_vec = curp->type->elaborate_type(des, scope);
	    if (mem_vec == 0)
		  continue;

	      // There may be several names that are the same type:
	      //   <data_type> name1, name2, ...;
	      // Process all the member, and give them a type.
	    for (list<decl_assignment_t*>::iterator cur_name = curp->names->begin()
		       ; cur_name != curp->names->end() ;  ++ cur_name) {
		  decl_assignment_t*namep = *cur_name;

		  if (packed_flag && namep->expr) {
			cerr << namep->expr->get_fileline() << " error: "
			     << "Packed structs must not have default member values."
			     << endl;
			des->errors++;
		  }

		  netstruct_t::member_t memb;
		  memb.name = namep->name.first;
		  memb.net_type = elaborate_array_type(des, scope, *this,
						       mem_vec, namep->index);
		  res->append_member(des, memb);
	    }
      }

      return res;
}

static ivl_type_t elaborate_darray_check_type(Design *des, const LineInfo &li,
					      ivl_type_t type,
					      const char *darray_type)
{
      // A null type means element-type elaboration already failed and
      // reported an error; just recover without adding another message.
      if (type == nullptr)
	    return new netvector_t(IVL_VT_LOGIC);

      if (dynamic_cast<const netvector_t*>(type) ||
	  dynamic_cast<const netparray_t*>(type) ||
	  dynamic_cast<const netdarray_t*>(type) ||
	  dynamic_cast<const netqueue_t*>(type) ||
	  dynamic_cast<const netenum_t*>(type) ||
	  dynamic_cast<const netstruct_t*>(type) ||
	  dynamic_cast<const netclass_t*>(type) ||
	  dynamic_cast<const netreal_t*>(type) ||
	  dynamic_cast<const netstring_t*>(type))
	    return type;

      cerr << li.get_fileline() << ": Sorry: "
           << darray_type << " of type `" << *type
	   << "` is not yet supported." << endl;
      des->errors++;

      // Return something to recover
      return new netvector_t(IVL_VT_LOGIC);
}

static ivl_type_t elaborate_queue_type(Design *des, NetScope *scope,
				       const LineInfo &li, ivl_type_t base_type,
				       PExpr *ridx,
				       bool assoc_compat = false)
{
      base_type = elaborate_darray_check_type(des, li, base_type, "Queue");

      long max_idx = -1;
      if (ridx) {
	    NetExpr*tmp = elab_and_eval(des, scope, ridx, -1, true);
	    NetEConst*cv = dynamic_cast<NetEConst*>(tmp);
	    if (cv == 0) {
		  cerr << li.get_fileline() << ": error: "
		       << "queue bound must be constant."
		       << endl;
		  des->errors++;
	    } else {
		  verinum res = cv->value();
		  if (res.is_defined()) {
			max_idx = res.as_long();
			if (max_idx < 0) {
			      cerr << li.get_fileline() << ": error: "
				   << "queue bound must be positive ("
				   << max_idx << ")." << endl;
			      des->errors++;
			      max_idx = -1;
			}
		  } else {
			cerr << li.get_fileline() << ": error: "
			     << "queue bound must be defined."
			     << endl;
			des->errors++;
		  }
	    }
	    delete cv;
      }

      return new netqueue_t(base_type, max_idx, assoc_compat);
}

static bool finite_enum_index_range_(const netenum_t*enum_type,
				     long&index_msb, long&index_lsb)
{
      if (!enum_type || enum_type->size() == 0)
	    return false;

      std::set<long> seen_vals;
      bool first = true;
      long min_val = 0;
      long max_val = 0;

      for (size_t idx = 0 ; idx < enum_type->size() ; idx += 1) {
	    verinum val = enum_type->value_at(idx);
	    if (!val.is_defined())
		  return false;

	    long use_val = val.as_long();
	    if (first) {
		  min_val = use_val;
		  max_val = use_val;
		  first = false;
	    } else {
		  if (use_val < min_val)
			min_val = use_val;
		  if (use_val > max_val)
			max_val = use_val;
	    }

	    if (!seen_vals.insert(use_val).second)
		  return false;
      }

      if ((max_val - min_val + 1) != static_cast<long>(enum_type->size()))
	    return false;

      index_msb = max_val;
      index_lsb = min_val;
      return true;
}

static ivl_type_t elaborate_assoc_array_type(Design *des, NetScope *scope,
					     const LineInfo &li,
					     ivl_type_t base_type,
					     const PEAssocType*assoc_idx)
{
      ivl_assert(li, assoc_idx);
      ivl_assert(li, assoc_idx->index_type());

      data_type_t*index_type_pf = const_cast<PEAssocType*>(assoc_idx)->index_type();
      ivl_type_t index_type = index_type_pf->elaborate_type(des, scope);

      (void) index_type;

      // Keep associative arrays in the assoc-compat queue representation even
      // for finite enum-key cases. Lowering them to a plain unpacked array
      // loses exists/delete/iteration semantics, which UVM relies on.
      return elaborate_queue_type(des, scope, li, base_type, 0, true);
}

// If dims is not empty create a unpacked array type and clear dims, otherwise
// return the base type. Also check that we actually support the base type.
static ivl_type_t elaborate_static_array_type(Design *des, const LineInfo &li,
					      ivl_type_t base_type,
					      netranges_t &dims)
{
      if (dims.empty())
	    return base_type;

      if (dynamic_cast<const netqueue_t*>(base_type)) {
	    cerr << li.get_fileline() << ": sorry: "
		 << "array of queue type is not yet supported."
		 << endl;
	    des->errors++;
	    // Recover
	    base_type = new netvector_t(IVL_VT_LOGIC);
      } else if (dynamic_cast<const netdarray_t*>(base_type)) {
	    cerr << li.get_fileline() << ": sorry: "
		 << "array of dynamic array type is not yet supported."
		 << endl;
	    des->errors++;
	    // Recover
	    base_type = new netvector_t(IVL_VT_LOGIC);
      }

      ivl_type_t type = new netuarray_t(dims, base_type);
      dims.clear();

      return type;
}

ivl_type_t elaborate_array_type(Design *des, NetScope *scope,
			        const LineInfo &li, ivl_type_t base_type,
			        const list<pform_range_t> &dims)
{
      const long warn_dimension_size = 1 << 30;
      netranges_t dimensions;
      dimensions.reserve(dims.size());

      ivl_type_t type = base_type;

      for (list<pform_range_t>::const_iterator cur = dims.begin();
	   cur != dims.end() ; ++cur) {
	    PExpr *lidx = cur->first;
	    PExpr *ridx = cur->second;

	    if (lidx == 0 && ridx == 0) {
		    // Special case: If we encounter an undefined dimensions,
		    // then turn this into a dynamic array and put all the
		    // packed dimensions there.
		  type = elaborate_static_array_type(des, li, type, dimensions);
		  type = elaborate_darray_check_type(des, li, type, "Dynamic array");
		  type = new netdarray_t(type);
		  continue;
	    } else if (const PEAssocType*assoc_idx = dynamic_cast<PEAssocType*>(lidx)) {
		    // Preserve associative-array semantics through lowering.
		  type = elaborate_static_array_type(des, li, type, dimensions);
		  type = elaborate_assoc_array_type(des, scope, li, type, assoc_idx);
		  continue;
	    } else if (dynamic_cast<PENull*>(lidx)) {
		    // Special case: Detect the mark for a QUEUE declaration,
		    // which is the dimensions [null:max_idx].
		  type = elaborate_static_array_type(des, li, type, dimensions);
		  type = elaborate_queue_type(des, scope, li, type, ridx);
		  continue;
	    }

	    long index_l, index_r;
	    evaluate_range(des, scope, &li, *cur, index_l, index_r);

	    if (abs(index_r - index_l) > warn_dimension_size) {
		  cerr << li.get_fileline() << ": warning: "
		       << "Array dimension is greater than "
		       << warn_dimension_size << "."
		       << endl;
	    }

	    dimensions.push_back(netrange_t(index_l, index_r));
      }

      return elaborate_static_array_type(des, li, type, dimensions);
}

ivl_type_t uarray_type_t::elaborate_type_raw(Design*des, NetScope*scope) const
{
      ivl_type_t btype = base_type->elaborate_type(des, scope);

      return elaborate_array_type(des, scope, *this, btype, *dims.get());
}

ivl_type_t typeref_t::elaborate_type_raw(Design*des, NetScope*s) const
{
      if (!s) {
	    // Try to recover
	    return new netvector_t(IVL_VT_LOGIC);
      }

      if (const netclass_t*self_class = resolve_current_class_typeref_(s, this))
	    return const_cast<netclass_t*>(self_class);

      ivl_type_t use_type = type->elaborate_type(des, s);
      if (!overrides)
	    return use_type;

      const netclass_t*class_type = dynamic_cast<const netclass_t*>(use_type);
      if (!class_type)
	    return use_type;

      // Built-in class types (mailbox, semaphore, process) are not template
      // classes — their "type parameter" is used only for SV type-checking.
      // Do not specialize them; return the base built-in class type so that
      // method dispatch (e.g. mailbox.put/get) continues to work.
      {
	    perm_string cn = class_type->get_name();
	    if (cn == perm_string::literal("mailbox") ||
		cn == perm_string::literal("semaphore") ||
		cn == perm_string::literal("process"))
		  return use_type;
      }

      // Use the original caller scope (saved before find_scope changed s to the
      // package scope) so that parameter override expressions like #(.AddrWidth(AddrWidth))
      // are evaluated in the scope where the type reference appears (e.g. the enclosing
      // parameterized class), not in the package that defines the type. Fall back to s
      // (the package scope) if the caller scope is not available.
      NetScope* call_scope = s_type_elaborate_caller_scope_ ? s_type_elaborate_caller_scope_ : s;
      return const_cast<netclass_t*>(
	    elaborate_specialized_class_type(des, call_scope, class_type, overrides));
}

NetScope *typeref_t::find_scope(Design *des, NetScope *s) const
{
        // If a scope has been specified use that as a starting point for the
	// search
      if (scope) {
	    if (NetScope*pkg = des->find_package(scope->pscope_name())) {
		  s = pkg;
	    } else if (s) {
		  if (netclass_t*cls = ensure_visible_class_type(des, s, scope->pscope_name()))
			s = const_cast<NetScope*>(cls->class_scope());
	    }
      }

      return s;
}

ivl_type_t typedef_t::elaborate_type(Design *des, NetScope *scope)
{
      if (name == "process" || name == "semaphore" || name == "mailbox") {
	    return builtin_class_type(name);
      }

      if (!data_type.get()) {
	    cerr << get_fileline() << ": error: Undefined type `" << name << "`."
		 << endl;
	    des->errors++;

	    // Try to recover
	    return netvector_t::integer_type();
      }

        // Search upwards from where the type was referenced
      scope = scope->find_typedef_scope(des, this);
      if (!scope) {
	      // Compiler-synthesized internal typedefs (e.g. __tmp_int_t__
	      // from UVM macros) may fail scope lookup when the enclosing
	      // class was incompletely elaborated by the recursion guard.
	      // Treat as a compile-progress warning rather than a fatal error
	      // so the VVP file can still be generated.
	    cerr << get_fileline() << ": warning: "
		 << "Can not find the scope type definition `" << name
		 << "' (compile-progress fallback)."
		 << endl;

	    // Try to recover
	    return netvector_t::integer_type();
      }

      // Some elaboration paths synthesize wrapper typedef_t nodes that are
      // equivalent to, but not pointer-identical with, the defining scope
      // entry. Delegate to the canonical scope entry so repeated references
      // share the same elaborated type object.
      if (typedef_t*canonical_td = scope->find_typedef(des, name)) {
	    if (canonical_td != this)
		  return canonical_td->elaborate_type(des, scope);
      }

      ivl_type_t elab_type = data_type->elaborate_type(des, scope);
      if (!elab_type)
	    return netvector_t::integer_type();

      bool type_ok = true;
      switch (basic_type) {
      case ENUM:
	    type_ok = dynamic_cast<const netenum_t *>(elab_type);
	    break;
      case STRUCT: {
	    const netstruct_t *struct_type = dynamic_cast<const netstruct_t *>(elab_type);
	    type_ok = struct_type && !struct_type->union_flag();
	    break;
      }
      case UNION: {
	    const netstruct_t *struct_type = dynamic_cast<const netstruct_t *>(elab_type);
	    type_ok = struct_type && struct_type->union_flag();
	    break;
      }
      case CLASS:
	    type_ok = dynamic_cast<const netclass_t *>(elab_type);
	    break;
      default:
	    break;
      }

      if (!type_ok) {
	    cerr << data_type->get_fileline() << " error: "
	         << "Unexpected type `" << *elab_type << "` for `" << name
		 << "`. It was forward declared as `" << basic_type
		 << "` at " << get_fileline() << "."
		 << endl;
	    des->errors++;
      }

      return elab_type;
}

ivl_type_t type_parameter_t::elaborate_type_raw(Design *des, NetScope*scope) const
{
      ivl_type_t type;

      scope->get_parameter(des, name, type);

      // Recover
      if (!type)
	    return netvector_t::integer_type();

      return type;
}
