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
# include  "PPackage.h"
# include  "PScope.h"
# include  "PWire.h"
# include  "PTask.h"
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
# include  <algorithm>
# include  <functional>
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
			      elaborate_specialized_class_type(des, scope, base_class,
						       overrides, false));
	    }
	    return alias_class;
      }

      netclass_t*base_class = ensure_visible_class_type(des, type_scope, td->name);
      if (!base_class)
	    return 0;

      if (const parmvalue_t*overrides = type_ref->parameter_values())
	    return const_cast<netclass_t*>(
		  elaborate_specialized_class_type(des, scope, base_class, overrides,
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

struct typed_mailbox_key_t {
      Design*design;
      string message_type;

      bool operator < (const typed_mailbox_key_t&that) const
      {
	    if (design != that.design)
		  return std::less<Design*>()(design, that.design);
	    return message_type < that.message_type;
      }
};

static map<typed_mailbox_key_t,netclass_t*> typed_mailbox_cache_;

static ivl_type_t elaborate_mailbox_message_type_(
		Design*des, NetScope*scope, const PExpr*actual)
{
      if (!des || !scope || !actual)
	    return nullptr;

      if (const PETypename*type_actual =
		dynamic_cast<const PETypename*>(actual)) {
	    ivl_type_t type = resolve_class_type_reference(
		  des, scope, type_actual->get_type());
	    if (!type)
		  type = const_cast<data_type_t*>(
			type_actual->get_type())->elaborate_type(des, scope);
	    return type;
      }

	/* A forwarded class type parameter can retain its bare identifier
	 * expression instead of PETypename. Resolve only the unqualified type
	 * namespaces here; an ordinary value expression is not a legal mailbox
	 * message-type actual. */
      const PEIdent*ident = dynamic_cast<const PEIdent*>(actual);
      if (!ident)
	    return nullptr;
      const pform_scoped_name_t&path = ident->path();
      if (path.package || path.name.size() != 1
	  || !path.name.front().index.empty())
	    return nullptr;

      perm_string name = path.name.front().name;
      ivl_type_t parameter_type = nullptr;
      scope->get_parameter(des, name, parameter_type);
      if (parameter_type)
	    return parameter_type;
      if (typedef_t*td = scope->find_typedef(des, name))
	    return td->elaborate_type(des, scope);
      return nullptr;
}

static const netclass_t* elaborate_builtin_mailbox_specialization_(
		Design*des, NetScope*scope, const parmvalue_t*actuals,
		const LineInfo*location)
{
      netclass_t*untyped = make_builtin_mailbox_type_();
      if (!actuals)
	    return untyped;

      const bool has_named = actuals->by_name && !actuals->by_name->empty();
      const size_t ordered_count = actuals->by_order
	    ? actuals->by_order->size() : 0;
      if (!has_named && ordered_count == 0)
	    return untyped;

      const PExpr*actual = nullptr;
      if (!has_named && ordered_count == 1)
	    actual = actuals->by_order->front();
	/* Preserve explicit mailbox#() as the untyped mailbox. Some parser paths
	 * retain the empty slot as a null list element. */
      if (!has_named && ordered_count == 1 && !actual)
	    return untyped;
      if (has_named || ordered_count != 1 || !actual) {
	    cerr << (location ? location->get_fileline() : string("<unknown>"))
		 << ": error: mailbox#(...) accepts "
		 << "either no type actual or exactly one message type."
		 << endl;
	    des->errors += 1;
	    return untyped;
      }

      ivl_type_t message_type = elaborate_mailbox_message_type_(
	    des, scope, actual);
      if (!message_type) {
	    cerr << (location ? location->get_fileline() : string("<unknown>"))
		 << ": error: mailbox#(...) message "
		 << "parameter must be a data type." << endl;
	    des->errors += 1;
	    return untyped;
      }

      string matching_key;
      if (!evaluated_type_signature(des, message_type, matching_key))
	    return untyped;
      typed_mailbox_key_t key = { des, matching_key };
      map<typed_mailbox_key_t,netclass_t*>::const_iterator found =
	    typed_mailbox_cache_.find(key);
      if (found != typed_mailbox_cache_.end())
	    return found->second;

      netclass_t*typed = new netclass_t(
	    perm_string::literal("mailbox"), nullptr);
      typed->set_mailbox_message_type(message_type, matching_key);
	/* Built-in dispatch is name/metadata based and owns no PClass scope. Mark
	 * this complete so generic late-visibility repair cannot replace the
	 * specialized carrier with the untyped singleton. */
      typed->set_scope_ready(true);
      typed->set_specialized_instance(true);
      typed_mailbox_cache_[key] = typed;
      return typed;
}

struct interface_layout_key_t {
      Design*design;
      Module*definition;
      string layout_parameters;

      bool operator < (const interface_layout_key_t&that) const
      {
	    if (design != that.design)
		  return std::less<Design*>()(design, that.design);
	    if (definition != that.definition)
		  return std::less<Module*>()(definition, that.definition);
	    return layout_parameters < that.layout_parameters;
      }
};

struct interface_layout_record_t {
      Design*design;
      Module*definition;
      string parameters;
      string layout_parameters;
      NetScope*declaration_scope;
      // perm_string's ordering requires a non-null interned string. The
      // unqualified interface view is represented by a nil perm_string, so
      // use an ordinary string key and reserve the impossible empty
      // SystemVerilog identifier for that view.
      map<string,netclass_t*>views;
      bool complete;
};

struct interface_instance_view_key_t {
      Design*design;
      NetScope*instance_scope;
      // Empty means the unqualified view. Keep nullable perm_string values
      // out of ordered containers because their comparator dereferences the
      // interned spelling.
      string modport;

      bool operator < (const interface_instance_view_key_t&that) const
      {
	    if (design != that.design)
		  return std::less<Design*>()(design, that.design);
	    if (instance_scope != that.instance_scope)
		  return std::less<NetScope*>()(instance_scope,
					that.instance_scope);
	    return modport < that.modport;
      }
};

static map<interface_layout_key_t,interface_layout_record_t*>
      interface_layout_cache_;
static map<interface_instance_view_key_t,netclass_t*>
      interface_instance_type_cache_;

/* Published layout types and their rootless declaration scopes remain part of
 * the elaborated Net* type graph through target emission. Cache retirement
 * therefore transfers ownership here instead of losing the final owning
 * pointers or deleting them while target callbacks can still dereference
 * class_scope()/definition_scope(). */
static vector<interface_layout_record_t*> retired_interface_layouts_;
static vector<netclass_t*> retired_interface_instance_types_;
static vector<netclass_t*> retired_typed_mailboxes_;

/* A semantic cache hit has already caused parameter data types to remember
 * this Definitions* as an elaboration-cache key. Release its evaluated values
 * immediately, but retain the empty scope object until the terminal
 * elaboration boundary so allocator address reuse cannot turn that dangling
 * key into a false cache hit. */
static vector<NetScope*> discarded_interface_parameter_scopes_;

static NetScope* interface_definition_unit_scope_(Design*des,
						   NetScope*caller_scope,
						   Module*mod)
{
      NetScope*unit_scope = nullptr;
      if (const PScope*lexical_parent =
		dynamic_cast<const PScope*>(mod->parent_scope()))
	    unit_scope = des->find_package(lexical_parent->pscope_name());

        // SystemVerilog modules normally have a compilation-unit PScope as
        // their lexical parent. Keep a conservative fallback for parse forms
        // that lack that parent without borrowing the caller as a hierarchy
        // parent: only the caller's compilation-unit link is relevant here.
      if (!unit_scope && caller_scope)
	    unit_scope = caller_scope->unit();
      return unit_scope;
}

/* Create only the declaration object needed for name/type binding in a
 * rootless interface signature scope. PWire::elaborate_sig() is intentionally
 * not used here: net declaration delays, supplies, resolvers and similar
 * constructs add target-visible Design nodes. A rootless signal is never
 * emitted by the target scope walk, so such a node would reference an
 * unexported nexus. Concrete interface instances still use the complete
 * PWire path and retain all of those run-time semantics. */
static NetNet* elaborate_interface_declaration_signal_(
		Design*des, NetScope*scope, PWire*wire)
{
      if (!des || !scope || !wire)
	    return nullptr;
      if (NetNet*existing = scope->find_signal(wire->basename()))
	    return existing;

      ivl_type_t type = wire->elaborate_sig_type(des, scope);
      if (!type)
	    return nullptr;

      netranges_t unpacked_dimensions;
      while (const netuarray_t*array = dynamic_cast<const netuarray_t*>(type)) {
	    unpacked_dimensions.insert(unpacked_dimensions.begin(),
		  array->static_dimensions().begin(),
		  array->static_dimensions().end());
	    type = array->element_type();
      }

      NetNet::Type wire_type = wire->get_wire_type();
      if (wire_type == NetNet::IMPLICIT)
	    wire_type = NetNet::WIRE;
      else if (wire_type == NetNet::IMPLICIT_REG)
	    wire_type = NetNet::REG;
      if (const netclass_t*class_type = dynamic_cast<const netclass_t*>(type))
	    if (class_type->is_interface())
		  wire_type = NetNet::REG;

      NetNet*signal = new NetNet(
	    scope, wire->basename(), wire_type, unpacked_dimensions, type);
      if (wire_type == NetNet::WIRE)
	    signal->devirtualize_pins();
      signal->set_line(*wire);
      signal->port_type(wire->get_port_type());
      signal->lexical_pos(wire->lexical_pos());
      signal->set_const(wire->get_const());
      signal->lifetime_override(wire->lifetime_override());
      if (ivl_discipline_t discipline = wire->get_discipline())
	    signal->set_discipline(discipline);
      if (const nettype_t*user_type = wire->user_nettype())
	    signal->set_user_nettype(scope->elaborate_nettype(des, user_type));
      return signal;
}

static NetScope* make_interface_parameter_scope_(Design*des,
						   NetScope*caller_scope,
						   Module*mod)
{
      if (!des || !mod || !mod->is_interface)
	    return nullptr;

        // This scope represents the interface declaration, not an elaborated
        // instance. In particular it has no hierarchy parent and is never
        // registered as a Design root, so runtime method candidate walks
        // cannot observe it.
      NetScope*scope = new NetScope(
	    nullptr, hname_t(mod->mod_name()), NetScope::MODULE,
	    interface_definition_unit_scope_(des, caller_scope, mod),
	    false, mod->program_block, true, false);
      scope->set_module_definition(mod);
      scope->set_module_name(mod->mod_name());
      scope->set_line(mod);
      scope->time_unit(mod->time_unit);
      scope->time_precision(mod->time_precision);
      scope->time_from_timescale(mod->has_explicit_timescale());
      des->set_precision(mod->time_precision);

      scope->add_imports(&mod->explicit_imports);
      scope->add_typedefs(&mod->typedefs);
      collect_module_parameter_declarations(des, scope, mod);
      return scope;
}

static void discard_interface_parameter_scope_(NetScope*scope)
{
      if (!scope)
	    return;
      scope->release_parameters();
      discarded_interface_parameter_scopes_.push_back(scope);
}

static bool apply_interface_parameter_actuals_(
		Design*des, NetScope*parameter_scope, NetScope*caller_scope,
		Module*mod, const parmvalue_t*actuals)
{
      if (!des || !parameter_scope || !mod || !actuals)
	    return true;

      const unsigned errors_before = des->errors;
      if (actuals->by_order) {
	    list<perm_string>::const_iterator formal = mod->param_names.begin();
	    list<PExpr*>::const_iterator actual = actuals->by_order->begin();
	    for (; actual != actuals->by_order->end()
		   && formal != mod->param_names.end(); ++actual, ++formal) {
		  if (*actual)
			parameter_scope->replace_parameter(
			      des, *formal, *actual, caller_scope, false);
	    }
	    if (actual != actuals->by_order->end()) {
		  const PExpr*where = *actual;
		  cerr << (where ? where->get_fileline() : mod->get_fileline())
		       << ": error: Too many parameter overrides for interface `"
		       << mod->mod_name() << "' (got "
		       << actuals->by_order->size() << ", expecting at most "
		       << mod->param_names.size() << ")." << endl;
		  des->errors += 1;
	    }
	}

      if (actuals->by_name) {
	    set<perm_string>seen;
	    for (list<named_pexpr_t>::const_iterator actual =
		       actuals->by_name->begin();
		 actual != actuals->by_name->end(); ++actual) {
		  if (!seen.insert(actual->name).second) {
			cerr << (actual->parm ? actual->parm->get_fileline()
					     : mod->get_fileline())
			     << ": error: Parameter `" << actual->name
			     << "' is overridden more than once for interface `"
			     << mod->mod_name() << "'." << endl;
			des->errors += 1;
			continue;
		  }
		  if (find(mod->param_names.begin(), mod->param_names.end(),
			   actual->name) == mod->param_names.end()) {
			cerr << actual->get_fileline()
			     << ": error: Parameter `" << actual->name
			     << "' is not declared in interface `"
			     << mod->mod_name() << "'." << endl;
			des->errors += 1;
			continue;
		  }
		  if (actual->parm)
			parameter_scope->replace_parameter(
			      des, actual->name, actual->parm,
			      caller_scope, false);
	    }
	}

      return des->errors == errors_before;
}

static bool apply_interface_instance_parameters_(
		Design*des, NetScope*parameter_scope,
		NetScope*actual_interface_scope, Module*mod)
{
      if (!des || !parameter_scope || !actual_interface_scope || !mod)
	    return false;

      const unsigned errors_before = des->errors;
      for (list<perm_string>::const_iterator formal = mod->param_names.begin();
		 formal != mod->param_names.end(); ++formal) {
	    map<perm_string,NetScope::param_expr_t>::const_iterator actual =
		  actual_interface_scope->parameters.find(*formal);
	    if (actual == actual_interface_scope->parameters.end()) {
		  cerr << actual_interface_scope->get_fileline()
		       << ": error: Interface instance `"
		       << scope_path(actual_interface_scope)
		       << "' has no effective value for parameter `" << *formal
		       << "'." << endl;
		  des->errors += 1;
		  continue;
	    }
	    if (actual->second.source_expr) {
		  NetScope*source_scope = actual->second.source_scope
			? actual->second.source_scope : actual_interface_scope;
		  parameter_scope->replace_parameter(
			des, *formal, actual->second.source_expr,
			source_scope, false);
	    }
	}
      return des->errors == errors_before;
}

static void finish_interface_declaration_scope_(Design*des, NetScope*scope,
						  Module*mod)
{
      ivl_assert(*mod, des);
      ivl_assert(*mod, scope);

      scope->add_nettypes(des, &mod->nettypes);
      elaborate_scope_declaration_enumerations(des, scope, mod->enum_sets);

        // A function-port default is elaborated in the declaration scope,
        // not the caller's scope (IEEE 1800-2017 13.5.3). Mirror the
        // declaration namespace that such an expression can name. Add every
        // member placeholder first so declarations may depend on later
        // members, and create every sibling subroutine scope before any
        // signature is requested so a default may call a later function.
      for (map<perm_string,PWire*>::const_iterator cur = mod->wires.begin();
		 cur != mod->wires.end(); ++cur)
	    if (cur->second)
		  scope->add_signal_placeholder(cur->second);

      for (map<perm_string,PLet*>::const_iterator cur = mod->lets.begin();
		 cur != mod->lets.end(); ++cur)
	    scope->add_let(cur->first, cur->second);

	/* Match Module::elaborate_scope's enum-then-class declaration order.
	 * The detached scope already has evaluated interface parameters and member
	 * placeholders, so a local class specialization can resolve outer values
	 * such as C#(N+1) without borrowing a concrete instance's class scope. */
      elaborate_interface_declaration_classes(des, scope, mod);

      for (map<perm_string,PTask*>::const_iterator cur = mod->tasks.begin();
		 cur != mod->tasks.end(); ++cur) {
	    hname_t use_name(cur->first);
	    if (!scope->child(use_name))
		  new NetScope(scope, use_name, NetScope::TASK);
      }
      for (map<perm_string,PFunction*>::const_iterator cur = mod->funcs.begin();
		 cur != mod->funcs.end(); ++cur) {
	    hname_t use_name(cur->first);
	    if (!scope->child(use_name))
		  new NetScope(scope, use_name, NetScope::FUNC);
      }

      for (map<perm_string,PTask*>::const_iterator cur = mod->tasks.begin();
		 cur != mod->tasks.end(); ++cur) {
	    NetScope*method_scope = scope->child(hname_t(cur->first));
	    if (!method_scope || method_scope->type() != NetScope::TASK
		|| method_scope->task_pform())
		  continue;
	    method_scope->is_auto(cur->second->is_auto());
	    method_scope->is_virtual_method(cur->second->is_virtual_method());
	    method_scope->set_line(cur->second);
	    method_scope->add_imports(&cur->second->explicit_imports);
	    cur->second->elaborate_scope(des, method_scope);
      }
      for (map<perm_string,PFunction*>::const_iterator cur = mod->funcs.begin();
		 cur != mod->funcs.end(); ++cur) {
	    NetScope*method_scope = scope->child(hname_t(cur->first));
	    if (!method_scope || method_scope->type() != NetScope::FUNC
		|| method_scope->func_pform())
		  continue;
	    method_scope->is_auto(cur->second->is_auto());
	    method_scope->is_virtual_method(cur->second->is_virtual_method());
	    method_scope->set_line(cur->second);
	    method_scope->add_imports(&cur->second->explicit_imports);
	    cur->second->elaborate_scope(des, method_scope);
      }

        // Defaults need actual declaration NetNets, rather than only PWire
        // placeholders, when they bind an interface member. This remains a
        // signature-only scope: declaration initializers and processes are
        // deliberately not elaborated here.
      for (map<perm_string,PWire*>::const_iterator cur = mod->wires.begin();
		 cur != mod->wires.end(); ++cur)
	    if (cur->second)
		  elaborate_interface_declaration_signal_(
			des, scope, cur->second);
      scope->elaborate_nettypes(des);
}

static void populate_interface_type_(Design*des, NetScope*member_scope,
				     Module*mod, netclass_t*iface_type)
{
      ivl_assert(*mod, member_scope);
      ivl_assert(*mod, iface_type);

      for (map<perm_string,PWire*>::const_iterator cur = mod->wires.begin()
		 ; cur != mod->wires.end() ; ++cur) {
	    ivl_type_t prop_type = cur->second->elaborate_sig_type(des, member_scope);
	    iface_type->set_property(cur->first,
				     property_qualifier_t::make_none(), prop_type);
      }

      for (map<perm_string,Module::PClocking*>::const_iterator cur =
		 mod->clocking_blocks.begin()
		 ; cur != mod->clocking_blocks.end() ; ++cur) {
	    map<perm_string,int> dirs;
	    map<perm_string,perm_string> aliases;
	    for (map<perm_string,NetNet::PortType>::const_iterator dir =
		       cur->second->directions.begin()
		 ; dir != cur->second->directions.end() ; ++dir)
		  dirs[dir->first] = static_cast<int>(dir->second);
	    for (map<perm_string,PExpr*>::const_iterator da =
		       cur->second->decl_assigns.begin()
		 ; da != cur->second->decl_assigns.end() ; ++da) {
		  const PEIdent*id = dynamic_cast<const PEIdent*>(da->second);
		  if (id && !id->path().package && id->path().name.size() == 1
		      && id->path().name.front().index.empty())
			aliases[da->first] = id->path().name.front().name;
	    }
	    iface_type->add_clocking_block(cur->first, cur->second->event,
			   cur->second->signals, dirs, aliases);

	      /* M8-2a-4: register the hidden clocking sample variables and
		 clocking-event tick bits as interface properties, so
		 `vif.cb.sig` reads rewritten to `vif._ivl_smp$cb$sig`
		 elaborate as property accesses. The runtime resolves
		 properties BY NAME in the bound instance scope, where
		 elaborate_sig created the matching signals. Mirror the
		 sampleable predicate (vec4, not a dynamic container);
		 unsampleable signals get no property and their reads
		 keep the alias rewrite — consistent by construction. */
	    const Module::PClocking*cb = cur->second;
	    bool any_sampled = false;
	    bool any_output = false;
	    for (vector<perm_string>::const_iterator sig_it = cb->signals.begin()
		       ; sig_it != cb->signals.end() ; ++sig_it) {
		  NetNet::PortType dir = cb->signal_direction(*sig_it);
		  bool is_in  = (dir==NetNet::PINPUT || dir==NetNet::PINOUT);
		  bool is_out = (dir==NetNet::POUTPUT || dir==NetNet::PINOUT);
		  if (!is_in && !is_out)
			continue;
		  ivl_type_t rt = nullptr;
		  map<perm_string,PExpr*>::const_iterator da =
			cb->decl_assigns.find(*sig_it);
		  if (da != cb->decl_assigns.end()) {
			const PEIdent*id = dynamic_cast<const PEIdent*>(da->second);
			if (!id || id->path().name.empty()
			    || !id->path().name.back().index.empty())
			      continue;
			map<perm_string,perm_string>::const_iterator alias =
			      aliases.find(*sig_it);
			map<perm_string,PWire*>::const_iterator wt =
			      alias == aliases.end() ? mod->wires.end()
					     : mod->wires.find(alias->second);
			if (wt != mod->wires.end())
			      rt = wt->second->elaborate_sig_type(des, member_scope);
			else {
			      rt = id->test_type_of_ident(des, member_scope);
			      if (!rt) {
				    wt = mod->wires.find(*sig_it);
				    if (wt != mod->wires.end())
					  rt = wt->second->elaborate_sig_type(
						des, member_scope);
			      }
			}
		  } else {
			map<perm_string,PWire*>::const_iterator wt =
			      mod->wires.find(*sig_it);
			if (wt != mod->wires.end())
			      rt = wt->second->elaborate_sig_type(des, member_scope);
		  }
		  if (!rt)
			continue;
		  if (rt->base_type() != IVL_VT_LOGIC
		      && rt->base_type() != IVL_VT_BOOL)
			continue;
		  if (dynamic_cast<const netdarray_t*>(rt)
		      || dynamic_cast<const netuarray_t*>(rt)
		      || dynamic_cast<const netqueue_t*>(rt))
			continue;
		  if (is_in) {
			string sname = string("_ivl_smp$") + cur->first.str()
			      + "$" + sig_it->str();
			iface_type->set_property(lex_strings.make(sname.c_str()),
					 property_qualifier_t::make_none(), rt);
		  }
		    /* M8-tail: output drive buffer + per-bit pending state as
		       properties, so vif.cb.out <= v drives resolve
		       against the bound instance's buffered-drive vars
		       (created by elaborate_sig; the instance's apply
		       process lands buffered drives at each event). */
		  if (is_out) {
			string bname = string("_ivl_obuf$") + cur->first.str()
			      + "$" + sig_it->str();
			iface_type->set_property(lex_strings.make(bname.c_str()),
					 property_qualifier_t::make_none(), rt);
			string pname = string("_ivl_opend$") + cur->first.str()
			      + "$" + sig_it->str();
			iface_type->set_property(lex_strings.make(pname.c_str()),
					 property_qualifier_t::make_none(), rt);
			any_output = true;
		  }
		  any_sampled = true;
	    }
	      /* The public clocking-event tick exists even for an itemless
		 block, allowing @(vif.cb) to preserve clocking-region timing. */
	    string tname = string("_ivl_cbtick$") + cur->first.str();
	    netvector_t*tick_vec = new netvector_t(IVL_VT_BOOL,
					  0, 0, false);
	    iface_type->set_property(lex_strings.make(tname.c_str()),
			 property_qualifier_t::make_none(), tick_vec);
	      /* Preserve the existing internal sample/output tick. */
	    if (any_sampled) {
		  string sname = string("_ivl_smptick$") + cur->first.str();
		  netvector_t*sample_tick_vec = new netvector_t(IVL_VT_LOGIC,
							 0, 0, false);
		  iface_type->set_property(lex_strings.make(sname.c_str()),
			 property_qualifier_t::make_none(), sample_tick_vec);
	    }
	    if (any_output) {
		  string dname = string("_ivl_odkick$") + cur->first.str();
		  netvector_t*kick_vec = new netvector_t(IVL_VT_LOGIC,
						     0, 0, false);
		  iface_type->set_property(lex_strings.make(dname.c_str()),
			   property_qualifier_t::make_none(), kick_vec);
	    }
      }
}

static netclass_t* interface_layout_view_(
		interface_layout_record_t*layout, perm_string modport)
{
      if (!layout || !layout->definition || !layout->declaration_scope)
	    return nullptr;

      if (!modport.nil()
	  && layout->definition->modports.find(modport)
		== layout->definition->modports.end()) {
	    cerr << layout->definition->get_fileline()
		 << ": error: Interface `" << layout->definition->mod_name()
		 << "' has no modport named `" << modport << "'." << endl;
	    layout->design->errors += 1;
	    return nullptr;
      }

	const string view_key = modport.nil() ? string() : modport.str();
	map<string,netclass_t*>::const_iterator found =
	    layout->views.find(view_key);
      if (found != layout->views.end())
	    return found->second;

      netclass_t*iface_type = new netclass_t(
	    layout->definition->mod_name(), nullptr);
      iface_type->set_interface(true);
        // Publish complete semantic identity before this type can enter a
        // recursive member or class-specialization cache.
      iface_type->set_interface_identity(
	    layout->definition, layout->parameters,
	    layout->layout_parameters, modport);
      iface_type->set_definition_scope(layout->declaration_scope);
      iface_type->set_class_scope(layout->declaration_scope);
      layout->views[view_key] = iface_type;

      if (layout->complete) {
	    populate_interface_type_(layout->design, layout->declaration_scope,
				     layout->definition, iface_type);
	    iface_type->set_scope_ready(true);
      }
      return iface_type;
}

static interface_layout_record_t* publish_interface_layout_(
		Design*des, Module*mod, const string&parameter_key,
		const string&layout_parameter_key,
		NetScope*parameter_scope)
{
      interface_layout_key_t key = { des, mod, layout_parameter_key };
      map<interface_layout_key_t,interface_layout_record_t*>::const_iterator
	    found = interface_layout_cache_.find(key);
      if (found != interface_layout_cache_.end()) {
	    discard_interface_parameter_scope_(parameter_scope);
	    return found->second;
      }

      interface_layout_record_t*layout = new interface_layout_record_t;
      layout->design = des;
      layout->definition = mod;
      layout->parameters = parameter_key;
      layout->layout_parameters = layout_parameter_key;
      layout->declaration_scope = parameter_scope;
      layout->complete = false;
      interface_layout_cache_[key] = layout;

	/* Nominal declarations inside two specializations of the same parsed
	 * interface are distinct even when their visible member shapes happen to
	 * match. Publish the semantic owner before enumerations, structs, classes,
	 * members, or method signatures are elaborated in this detached scope. */
      ostringstream owner;
      owner << "interface@" << (const void*)mod
	    << ":parameters=" << parameter_key.size() << ":";
      owner.write(parameter_key.data(), parameter_key.size());
      parameter_scope->type_owner_identity(owner.str());

        // The unqualified view is the recursion anchor. Its identity must be
        // visible before member and method types are elaborated.
      interface_layout_view_(layout, perm_string());
      finish_interface_declaration_scope_(des, parameter_scope, mod);

        // A member can recursively request another modport view while the
        // declaration scope is being completed. Populate every view exactly
        // once, including any view inserted during this loop.
      set<netclass_t*>populated;
      while (populated.size() < layout->views.size()) {
	    for (map<string,netclass_t*>::iterator cur =
		       layout->views.begin(); cur != layout->views.end(); ++cur) {
		  if (!populated.insert(cur->second).second)
			continue;
		  populate_interface_type_(des, parameter_scope, mod, cur->second);
	    }
      }
      layout->complete = true;
      for (map<string,netclass_t*>::iterator cur = layout->views.begin();
	 cur != layout->views.end(); ++cur)
	    cur->second->set_scope_ready(true);
      return layout;
}

static interface_layout_record_t* elaborate_interface_layout_(
		Design*des, NetScope*caller_scope, Module*mod,
		const parmvalue_t*actuals, NetScope*actual_interface_scope)
{
      if (!des || !mod || !mod->is_interface)
	    return nullptr;

        // Concrete instances already hold their final values after ordinary
        // override/defparam elaboration. Use that evaluated identity for the
        // fast lookup, then reconstruct a rootless declaration scope only on
        // a semantic cache miss.
      string actual_parameter_key;
      string actual_layout_parameter_key;
      if (actual_interface_scope) {
	    if (!evaluated_parameter_signatures(
		  des, actual_interface_scope, mod->param_names,
		  actual_parameter_key, actual_layout_parameter_key))
		  return nullptr;
	    interface_layout_key_t actual_key = {
		  des, mod, actual_layout_parameter_key
	    };
	    map<interface_layout_key_t,
		interface_layout_record_t*>::const_iterator found =
		  interface_layout_cache_.find(actual_key);
	    if (found != interface_layout_cache_.end())
		  return found->second;
      }

      NetScope*parameter_scope = make_interface_parameter_scope_(
	    des, caller_scope ? caller_scope : actual_interface_scope, mod);
      if (!parameter_scope)
	    return nullptr;

      const unsigned errors_before = des->errors;
      bool applied = actual_interface_scope
	    ? apply_interface_instance_parameters_(
		  des, parameter_scope, actual_interface_scope, mod)
	    : apply_interface_parameter_actuals_(
		  des, parameter_scope,
		  caller_scope ? caller_scope : parameter_scope,
		  mod, actuals);
      string parameter_key;
      string layout_parameter_key;
	      bool evaluated = applied && evaluated_parameter_signatures(
	    des, parameter_scope, mod->param_names, parameter_key,
	    layout_parameter_key);
      if (!evaluated || des->errors != errors_before) {
	    discard_interface_parameter_scope_(parameter_scope);
	    return nullptr;
      }

      if (actual_interface_scope
	  && (parameter_key != actual_parameter_key
	      || layout_parameter_key != actual_layout_parameter_key)) {
	    cerr << actual_interface_scope->get_fileline()
		 << ": error: Internal interface-specialization reconstruction "
		    "mismatch for `" << scope_path(actual_interface_scope) << "'."
		 << " Reconstructed matching/layout key lengths "
		 << parameter_key.size() << "/" << layout_parameter_key.size()
		 << ", effective key lengths " << actual_parameter_key.size()
		 << "/" << actual_layout_parameter_key.size()
		 << endl;
	    des->errors += 1;
	    discard_interface_parameter_scope_(parameter_scope);
	    return nullptr;
      }

      return publish_interface_layout_(des, mod, parameter_key,
					layout_parameter_key, parameter_scope);
}

static netclass_t* elaborate_interface_type_(
		Design*des, NetScope*scope, Module*mod,
		const parmvalue_t*actuals = nullptr,
		perm_string modport = perm_string())
{
      interface_layout_record_t*layout = elaborate_interface_layout_(
	    des, scope, mod, actuals, nullptr);
      return interface_layout_view_(layout, modport);
}

}

const netclass_t* elaborate_builtin_mailbox_specialization(
		Design*des, NetScope*scope, const parmvalue_t*actuals,
		const LineInfo*location)
{
      return elaborate_builtin_mailbox_specialization_(
	    des, scope, actuals, location);
}

NetScope* ensure_interface_declaration_method_scope(
		Design*des, NetScope*caller_scope,
		const netclass_t*interface_type, perm_string method_name)
{
      if (!des || !interface_type || !interface_type->is_interface()
	  || !method_name)
	    return nullptr;

      Module*mod = const_cast<Module*>(interface_type->interface_definition());
      NetScope*interface_scope =
	    const_cast<netclass_t*>(interface_type)->definition_scope();
      if (!mod || !interface_scope || !mod->is_interface)
	    return nullptr;
      (void)caller_scope;
      PTask*task = nullptr;
      PFunction*func = nullptr;
      map<perm_string,PTask*>::const_iterator task_it =
	    mod->tasks.find(method_name);
      if (task_it != mod->tasks.end()) {
	    task = task_it->second;
      } else {
	    map<perm_string,PFunction*>::const_iterator func_it =
		  mod->funcs.find(method_name);
	    if (func_it != mod->funcs.end())
		  func = func_it->second;
      }
      if (!task && !func)
	    return nullptr;

      hname_t use_name(method_name);
      if (NetScope*existing = interface_scope->child(use_name)) {
	    if (task && existing->type() == NetScope::TASK
		&& existing->task_pform() == task)
		  return existing;
	    if (func && existing->type() == NetScope::FUNC
		&& existing->func_pform() == func)
		  return existing;
	    return nullptr;
      }

      NetScope*method_scope = new NetScope(
	    interface_scope, use_name,
	    task ? NetScope::TASK : NetScope::FUNC);
      if (task) {
	    method_scope->is_auto(task->is_auto());
	    method_scope->is_virtual_method(task->is_virtual_method());
	    method_scope->set_line(task);
	    method_scope->add_imports(&task->explicit_imports);
	    task->elaborate_scope(des, method_scope);
      } else {
	    method_scope->is_auto(func->is_auto());
	    method_scope->is_virtual_method(func->is_virtual_method());
	    method_scope->set_line(func);
	    method_scope->add_imports(&func->explicit_imports);
	    func->elaborate_scope(des, method_scope);
      }
      return method_scope;
}

const netclass_t* elaborate_interface_instance_type(Design*des,
						     NetScope*actual_interface_scope,
						     perm_string modport)
{
      if (!des || !actual_interface_scope
	  || actual_interface_scope->type() != NetScope::MODULE
	  || !actual_interface_scope->is_interface())
	    return 0;

      map<perm_string,Module*>::const_iterator module_it =
	    pform_modules.find(actual_interface_scope->module_name());
      if (module_it == pform_modules.end() || !module_it->second->is_interface)
	    return 0;

      interface_instance_view_key_t instance_key = {
	    des, actual_interface_scope,
	    modport.nil() ? string() : string(modport.str())
      };
      map<interface_instance_view_key_t,netclass_t*>::const_iterator found =
	    interface_instance_type_cache_.find(instance_key);
      if (found != interface_instance_type_cache_.end())
	    return found->second;

      Module*mod = module_it->second;
      interface_layout_record_t*layout = elaborate_interface_layout_(
	    des, actual_interface_scope, mod, nullptr, actual_interface_scope);
      if (!layout || !interface_layout_view_(layout, modport))
	    return nullptr;

	/* The layout view is the semantic type used for 6.22.1/25.9 matching,
	 * but a physical interface handle must retain the exact instance scope.
	 * VVP class definitions use netclass_t identity and class_scope() to bind
	 * their properties to a vvp_vinterface. Reusing one layout view for several
	 * physical instances makes an interface-port object and its backing scope
	 * acquire unrelated target class identities (notably for port arrays).
	 *
	 * Publish this exact carrier before populating it so recursive member types
	 * see one stable object for this instance/view. Its semantic identity remains
	 * the layout's parameter key, so distinct instances still compare and assign
	 * according to their matching interface type rather than pointer identity. */
      netclass_t*iface_type = new netclass_t(mod->mod_name(), nullptr);
      iface_type->set_interface(true);
      iface_type->set_interface_identity(
	    mod, layout->parameters, layout->layout_parameters, modport);
      iface_type->set_definition_scope(actual_interface_scope);
      iface_type->set_class_scope(actual_interface_scope);
      interface_instance_type_cache_[instance_key] = iface_type;
      populate_interface_type_(des, actual_interface_scope, mod, iface_type);
      return iface_type;
}

bool interface_instance_vif_bindable(const NetScope*actual_interface_scope)
{
      if (!actual_interface_scope
	  || actual_interface_scope->type() != NetScope::MODULE
	  || !actual_interface_scope->is_interface())
	    return false;

      vector<const NetScope*>pending(1, actual_interface_scope);
      while (!pending.empty()) {
	    const NetScope*target_scope = pending.back();
	    pending.pop_back();

	    for (map<perm_string,NetScope::param_expr_t>::const_iterator cur =
		       target_scope->parameters.begin();
		 cur != target_scope->parameters.end(); ++cur) {
		  const set<const NetScope*>&declarations =
			cur->second.defparam_source_scopes;
		  for (set<const NetScope*>::const_iterator declaration =
			     declarations.begin();
		       declaration != declarations.end(); ++declaration) {
			bool declared_within_interface = false;
			for (const NetScope*owner = *declaration; owner;
			     owner = owner->parent()) {
			      if (owner == actual_interface_scope) {
				    declared_within_interface = true;
				    break;
			      }
			}
			if (!declared_within_interface)
			      return false;
		  }
	    }

	    const map<hname_t,NetScope*>&children = target_scope->children();
	    for (map<hname_t,NetScope*>::const_iterator child = children.begin();
		 child != children.end(); ++child)
		  if (child->second)
			pending.push_back(child->second);
      }
      return true;
}

void release_elaboration_interface_caches()
{
      for (map<interface_layout_key_t,
		interface_layout_record_t*>::iterator cur =
		   interface_layout_cache_.begin();
	   cur != interface_layout_cache_.end(); ++cur) {
	    if (cur->second) {
		  if (cur->second->declaration_scope)
			cur->second->declaration_scope->release_elaboration_caches();
		  for (map<string,netclass_t*>::iterator view =
			     cur->second->views.begin();
		       view != cur->second->views.end(); ++view)
			view->second->retire_interface_definition();
		  retired_interface_layouts_.push_back(cur->second);
	    }
      }
      interface_layout_cache_.clear();

      for (map<interface_instance_view_key_t,netclass_t*>::iterator cur =
		 interface_instance_type_cache_.begin();
	   cur != interface_instance_type_cache_.end(); ++cur) {
	    if (!cur->second)
		  continue;
	    cur->second->retire_interface_definition();
	    retired_interface_instance_types_.push_back(cur->second);
      }
      interface_instance_type_cache_.clear();

      for (map<typed_mailbox_key_t,netclass_t*>::iterator cur =
		 typed_mailbox_cache_.begin();
	   cur != typed_mailbox_cache_.end(); ++cur)
	    retired_typed_mailboxes_.push_back(cur->second);
      typed_mailbox_cache_.clear();

      for (vector<NetScope*>::iterator cur =
		 discarded_interface_parameter_scopes_.begin();
	   cur != discarded_interface_parameter_scopes_.end(); ++cur)
	    delete *cur;
      vector<NetScope*>().swap(discarded_interface_parameter_scopes_);
}

void release_elaboration_interface_types()
{
      for (vector<interface_layout_record_t*>::iterator cur =
		 retired_interface_layouts_.begin();
	   cur != retired_interface_layouts_.end(); ++cur) {
	    interface_layout_record_t*layout = *cur;
	    if (!layout)
		  continue;
	    for (map<string,netclass_t*>::iterator view = layout->views.begin();
		 view != layout->views.end(); ++view)
		  delete view->second;
	    delete layout->declaration_scope;
	    delete layout;
      }
      vector<interface_layout_record_t*>().swap(retired_interface_layouts_);

      for (vector<netclass_t*>::iterator cur =
		 retired_interface_instance_types_.begin();
	   cur != retired_interface_instance_types_.end(); ++cur)
	    delete *cur;
      vector<netclass_t*>().swap(retired_interface_instance_types_);

      for (vector<netclass_t*>::iterator cur =
		 retired_typed_mailboxes_.begin();
	   cur != retired_typed_mailboxes_.end(); ++cur)
	    delete *cur;
      vector<netclass_t*>().swap(retired_typed_mailboxes_);
}

ivl_type_t resolve_class_type_reference(Design*des, NetScope*scope,
					 const data_type_t*type)
{
      ivl_type_t resolved = resolve_circular_class_handle_type_(
	    des, scope, type);
      return specialize_bare_class_at_concrete_use(
	    des, scope, type, resolved, false);
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

static bool user_nettype_data_type_valid_(ivl_type_t type)
{
      if (!type)
            return false;

      if (type == &netvector_t::chandle_type)
            return false;
      if (dynamic_cast<const netvector_t*>(type)
          || dynamic_cast<const netenum_t*>(type)
          || dynamic_cast<const netreal_t*>(type))
            return true;

      /* Dynamic arrays, queues, and associative-array compatibility objects
       * derive from netarray_t too, so reject them before accepting the fixed
       * packed/unpacked array representations. */
      if (dynamic_cast<const netdarray_t*>(type))
            return false;
      if (const netparray_t*array = dynamic_cast<const netparray_t*>(type))
            return user_nettype_data_type_valid_(array->element_type());
      if (const netuarray_t*array = dynamic_cast<const netuarray_t*>(type))
            return user_nettype_data_type_valid_(array->element_type());

      if (const netstruct_t*record = dynamic_cast<const netstruct_t*>(type)) {
            const vector<netstruct_t::member_t>&members = record->members();
            for (vector<netstruct_t::member_t>::const_iterator cur =
                       members.begin(); cur != members.end(); ++cur)
                  if (!user_nettype_data_type_valid_(cur->net_type))
                        return false;
            return true;
      }

      return false;
}

static bool exact_nettype_match_(ivl_type_t left, ivl_type_t right)
{
      if (left == right)
            return true;
      return left && right && left->type_equivalent(right)
             && right->type_equivalent(left);
}

static string nettype_data_type_name_(ivl_type_t type)
{
      ostringstream out;
      if (type == &netvector_t::chandle_type) {
            out << "chandle";
      } else if (type == &netstring_t::type_string) {
            out << "string";
      } else if (type == &netreal_t::type_shortreal) {
            out << "shortreal";
      } else if (dynamic_cast<const netreal_t*>(type)) {
            out << "real";
      } else if (const netvector_t*vec =
                       dynamic_cast<const netvector_t*>(type)) {
            switch (vec->base_type()) {
                case IVL_VT_BOOL:
                  out << "bit";
                  break;
                case IVL_VT_LOGIC:
                  out << "logic";
                  break;
                default:
                  out << "integral";
                  break;
            }
            out << vec->packed_dims();
      } else if (type) {
            type->debug_dump(out);
      } else {
            out << "<unresolved>";
      }
      return out.str();
}

static string declared_nettype_data_type_name_(const data_type_t*declared,
                                                ivl_type_t elaborated)
{
      if (const typeref_t*ref = dynamic_cast<const typeref_t*>(declared)) {
            ostringstream out;
            out << *ref;
            return out.str();
      }
      return nettype_data_type_name_(elaborated);
}

static NetScope* resolver_lookup_scope_(Design*des, NetScope*decl_scope,
                                        const pform_scoped_name_t&path,
                                        pform_name_t&use_name)
{
      use_name = path.name;
      if (path.package)
            return des->find_package(path.package->pscope_name());

      if (path.name.size() == 2) {
            NetScope*pkg = des->find_package(peek_head_name(path.name));
            if (pkg) {
                  use_name.clear();
                  use_name.push_back(path.name.back());
                  return pkg;
            }
      }
      return decl_scope;
}

static bool validate_nettype_resolver_(Design*des, NetNetType*info,
                                       NetFuncDef*&resolved)
{
      resolved = 0;
      const nettype_t*decl = info->pform_type();
      const pform_scoped_name_t*path = decl->resolution_function();
      if (!path)
            return true;

      pform_name_t use_name;
      NetScope*lookup_scope = resolver_lookup_scope_(
            des, info->declaration_scope(), *path, use_name);
      NetFuncDef*func = lookup_scope && !use_name.empty()
            ? des->find_function(lookup_scope, use_name) : 0;
      if (!func) {
            NetScope*task = lookup_scope && !use_name.empty()
                  ? des->find_task(lookup_scope, use_name) : 0;
            if (task) {
                  cerr << decl->get_fileline()
                       << ": error: Resolution function for nettype `"
                       << decl->name()
                       << "' must be a function, not a task." << endl;
            } else {
                  cerr << decl->get_fileline() << ": error: Unable to bind "
                       << "resolution function `" << *path << "'." << endl;
            }
            des->errors += 1;
            return false;
      }

      NetScope*func_scope = func->scope();
      const PFunction*pfunc = func_scope ? func_scope->func_pform() : 0;
      if (!func_scope || !pfunc) {
            cerr << decl->get_fileline() << ": error: resolution function for "
                 << "nettype '" << decl->name()
                 << "' has no elaborated SystemVerilog function declaration."
                 << endl;
            des->errors += 1;
            return false;
      }

      if (func->port_count() != 1) {
            cerr << decl->get_fileline() << ": error: Resolution function for "
                 << "nettype `" << decl->name() << "' must have exactly one "
                 << "input dynamic-array argument of type "
                 << nettype_data_type_name_(info->data_type()) << "." << endl;
            des->errors += 1;
            return false;
      }

      if (func_scope->parent()
          && func_scope->parent()->type() == NetScope::CLASS) {
            cerr << decl->get_fileline() << ": sorry: class-method resolution "
                 << "function '" << func_scope->basename()
                 << "' cannot be used for nettype '" << decl->name()
                 << "' because this frontend does not preserve the static "
                 << "method qualifier needed to distinguish the legal form."
                 << endl;
            des->errors += 1;
            return false;
      }

      if (pfunc->is_virtual_method() || pfunc->is_pure_method()
          || pfunc->is_dpi_import()) {
            cerr << decl->get_fileline() << ": error: resolution function '"
                 << func_scope->basename() << "' for nettype '" << decl->name()
                 << "' must be an ordinary non-virtual SystemVerilog function."
                 << endl;
            des->errors += 1;
            return false;
      }

      if (func->is_void()
          || !exact_nettype_match_(func->return_sig()->net_type(),
                                   info->data_type())) {
            cerr << decl->get_fileline() << ": error: Resolution function for "
                 << "nettype `" << decl->name() << "' must return "
                 << nettype_data_type_name_(info->data_type()) << "." << endl;
            des->errors += 1;
            return false;
      }

      const NetNet*arg = func->port(0);
      const netdarray_t*arg_array = arg
            ? dynamic_cast<const netdarray_t*>(arg->net_type()) : 0;
      if (!arg || arg->port_type() != NetNet::PINPUT || !arg_array
          || dynamic_cast<const netqueue_t*>(arg->net_type())
          || !exact_nettype_match_(arg_array->element_type(),
                                   info->data_type())) {
            cerr << decl->get_fileline() << ": error: Resolution function for "
                 << "nettype `" << decl->name() << "' must have exactly one "
                 << "input dynamic-array argument of type "
                 << nettype_data_type_name_(info->data_type()) << "." << endl;
            des->errors += 1;
            return false;
      }

      resolved = func;
      return true;
}

NetNetType* NetScope::elaborate_nettype(Design*des, const nettype_t*type)
{
      if (!type)
            return 0;

      NetScope*decl_scope = des->find_nettype_scope(type, this);
      NetNetType*info = decl_scope ? decl_scope->find_local_nettype(type) : 0;
      if (!info) {
            cerr << type->get_fileline() << ": error: user-defined nettype '"
                 << type->name() << "' has no elaborated declaration scope."
                 << endl;
            des->errors += 1;
            return 0;
      }

      if (info->state_ == NetNetType::VALID)
            return info;
      if (info->state_ == NetNetType::INVALID)
            return 0;
      if (info->state_ == NetNetType::ELABORATING) {
            cerr << type->get_fileline() << ": error: cyclic user-defined "
                 << "nettype alias involving '" << type->name() << "'." << endl;
            des->errors += 1;
            info->state_ = NetNetType::INVALID;
            return 0;
      }
      info->state_ = NetNetType::ELABORATING;

      const nettype_t*canonical_decl = type->canonical_type();
      if (!canonical_decl) {
            cerr << type->get_fileline() << ": error: cyclic user-defined "
                 << "nettype alias involving '" << type->name() << "'." << endl;
            des->errors += 1;
            info->state_ = NetNetType::INVALID;
            return 0;
      }

      if (canonical_decl != type) {
            NetScope*canonical_scope = des->find_nettype_scope(canonical_decl,
                                                               decl_scope);
            NetNetType*canonical = canonical_scope
                  ? canonical_scope->elaborate_nettype(des, canonical_decl) : 0;
            if (!canonical) {
                  info->state_ = NetNetType::INVALID;
                  return 0;
            }
            info->canonical_type_ = canonical;
            info->data_type_ = canonical->data_type_;
            info->state_ = NetNetType::VALID;
            return info;
      }

      info->canonical_type_ = info;
      const data_type_t*direct = canonical_decl->direct_type();
      info->data_type_ = direct
            ? const_cast<data_type_t*>(direct)->elaborate_type(des, decl_scope)
            : 0;
      if (!user_nettype_data_type_valid_(info->data_type_)) {
            cerr << canonical_decl->get_fileline() << ": error: '"
                 << declared_nettype_data_type_name_(direct, info->data_type_)
                 << "' is not a valid type for a user-defined nettype; only "
                 << "integral types, floating types, and fixed-size unpacked "
                 << "aggregates of such types are allowed." << endl;
            des->errors += 1;
            info->state_ = NetNetType::INVALID;
            return 0;
      }

      if (!info->resolver_checked_) {
            info->resolver_checked_ = true;
            NetFuncDef*resolved = 0;
            if (!validate_nettype_resolver_(des, info, resolved)) {
                  info->state_ = NetNetType::INVALID;
                  return 0;
            }
            info->resolution_function_ = resolved;
      }

      info->state_ = NetNetType::VALID;
      return info;
}

void NetScope::elaborate_nettypes(Design*des)
{
      vector<const nettype_t*>decls;
      decls.reserve(nettypes_.size());
      for (map<const nettype_t*,unique_ptr<NetNetType> >::const_iterator cur =
                 nettypes_.begin(); cur != nettypes_.end(); ++cur)
            decls.push_back(cur->first);
      stable_sort(decls.begin(), decls.end(),
                  [](const nettype_t*left, const nettype_t*right) {
                        int file_cmp = strcmp(left->get_file().str(),
                                              right->get_file().str());
                        if (file_cmp != 0)
                              return file_cmp < 0;
                        if (left->get_lineno() != right->get_lineno())
                              return left->get_lineno() < right->get_lineno();
                        return left < right;
                  });
      for (vector<const nettype_t*>::const_iterator cur = decls.begin();
           cur != decls.end(); ++cur)
            elaborate_nettype(des, *cur);
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

ostream& pattern_binding_type_t::debug_dump(ostream&out) const
{
      out << "<pattern binding type>";
      return out;
}

ivl_type_t pattern_binding_type_t::elaborate_type_raw(Design*des,
                                                       NetScope*scope) const
{
      PEIdent subject(subject_.package, subject_.name, lexical_pos_);
      subject.set_line(*this);
      // The binding is declared in the match arm's implicit scope. Resolve
      // the already-parsed subject from the enclosing scope so a binding with
      // the same spelling cannot create a circular self-type dependency.
      NetScope*subject_scope = scope->parent() ? scope->parent() : scope;
      ivl_type_t type = subject.test_type_of_ident(des, subject_scope);
      if (!type) {
            cerr << get_fileline() << ": error: Unable to determine the type "
                 << "of the pattern-matching subject." << endl;
            des->errors += 1;
            return netvector_t::integer_type();
      }

      for (const pform_pattern_path_component_t&component : path_) {
            const netstruct_t*structure =
                  dynamic_cast<const netstruct_t*>(type);
            if (!structure) {
                  cerr << get_fileline() << ": error: Pattern variable "
                       << "selects a member of a non-structure value." << endl;
                  des->errors += 1;
                  return netvector_t::integer_type();
            }

            const netstruct_t::member_t*member = nullptr;
            if (component.kind ==
                pform_pattern_path_component_t::NAMED_MEMBER) {
                  for (const netstruct_t::member_t&candidate :
                       structure->members()) {
                        if (candidate.name == component.name) {
                              member = &candidate;
                              break;
                        }
                  }
            } else if (component.position < structure->members().size()) {
                  member = &structure->members()[component.position];
            }

            if (!member) {
                  cerr << get_fileline() << ": error: Pattern variable "
                       << "selects a member that does not exist." << endl;
                  des->errors += 1;
                  return netvector_t::integer_type();
            }
            type = member->net_type;
      }

      return type;
}

ivl_type_t data_type_t::elaborate_type_raw(Design*des, NetScope*) const
{
      cerr << get_fileline() << ": internal error: "
	   << "Elaborate method not implemented for " << typeid(*this).name()
	   << "." << endl;
      des->errors += 1;
      return 0;
}

/* R20 (roadmap): elaborate a `void` tagged-union member (IEEE
 * 1800-2017 7.3.2). There is no real payload to store, so this
 * returns a 1-bit IVL_VT_VOID marker type. The single bit gives it
 * concrete, non-zero storage (matching how every other member_t is
 * represented) while IVL_VT_VOID lets member-pattern elaboration
 * (PEAssignPattern::elaborate_expr_struct_) recognize "this member
 * carries no value" and skip generating/needing one. struct_union_member
 * is the only pform production that builds a void_type_t, and
 * struct_type_t::elaborate_type_raw rejects it outside a `union
 * tagged`, so reaching here always means a legitimate tag-only member. */
ivl_type_t void_type_t::elaborate_type_raw(Design*, NetScope*) const
{
      return new netvector_t(IVL_VT_VOID);
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

	  case CHANDLE:
	      // Storage-compatible with an unsigned longint (64-bit,
	      // 2-state), but kept as its own singleton so type-name
	      // introspection ($typename) can print "chandle" instead of
	      // "longint". See the CHANDLE comment in pform_types.h.
	    return &netvector_t::chandle_type;

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
	    (!array_wire && scope)
	      ? find_foreach_class_property_index_type_(
		    des, scope, target_path, index_depth)
	      : 0;
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
	    if (allow_unresolved) {
		  if (!unresolved_type) {
			unresolved_type = new netclass_t(name, 0);
			unresolved_type->set_interface(true);
			unresolved_type->set_unresolved_interface(true);
			unresolved_type->set_scope_ready(true);
			unresolved_type->set_body_elaborated(true);
		  }
		  return unresolved_type;
	    }
	    cerr << get_fileline() << ": error: "
		 << "Unknown interface type `" << name << "'." << endl;
	    des->errors += 1;
	    return 0;
      }

      return elaborate_interface_type_(
	    des, scope, cur->second, parameter_values_, modport);
}

/*
 * elaborate_type_raw for enumerations is actually mostly performed
 * during scope elaboration so that the enumeration literals are
 * available at the right time. At that time, the netenum_t* object is
 * stashed in the scope so that I can retrieve it here.
 */
static string nominal_type_owner_key_(const NetScope*scope)
{
      if (!scope)
	    return string();
      if (!scope->type_owner_identity().empty())
	    return scope->type_owner_identity();

	/* IEEE 1800-2017/2023 6.22 gives an in-instance user-defined type a
	 * distinct nominal identity. Package and compilation-unit declarations
	 * naturally share their one declaration scope, while concrete module
	 * hierarchy paths keep otherwise identical instance-local declarations
	 * separate. Detached parameterized interface/class scopes use the
	 * semantic owner installed above instead. */
      ostringstream out;
      out << scope_path(scope);
      return out.str();
}

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
      type->set_nominal_identity(
	    this, nominal_type_owner_key_(scope));
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

static bool struct_has_direct_member_defaults_(const struct_type_t*type)
{
      if (!type || !type->members)
	    return false;

      for (const struct_member_t*member : *type->members) {
	    if (!member || !member->names)
		  continue;
	    for (const decl_assignment_t*name : *member->names) {
		  if (name && name->expr)
			return true;
	    }
      }

      return false;
}

static const netstruct_t* net_type_struct_or_union_(ivl_type_t type)
{
      while (type) {
	    if (const netarray_t*array = dynamic_cast<const netarray_t*>(type)) {
		  type = array->element_type();
		  continue;
	    }
	    return dynamic_cast<const netstruct_t*>(type);
      }

      return 0;
}

static const char* struct_random_member_forbidden_type_(ivl_type_t type)
{
      while (const netarray_t*array = dynamic_cast<const netarray_t*>(type))
	    type = array->element_type();

      if (type == &netreal_t::type_real
	  || type == &netreal_t::type_shortreal
	  || (type && type->base_type() == IVL_VT_REAL))
	    return "real/shortreal";
      if (type == &netstring_t::type_string
	  || (type && type->base_type() == IVL_VT_STRING))
	    return "string";
      return 0;
}

/* The runtime cycle bitmap is per packed randc leaf. Peel only unpacked
 * array layers; a packed array is one cyclic value and its complete packed
 * width must be checked against the implementation cap. */
static long struct_randc_member_leaf_width_(ivl_type_t type)
{
      while (type) {
	    const netarray_t*array = dynamic_cast<const netarray_t*>(type);
	    if (!array || type->packed())
		  break;
	    type = array->element_type();
      }
      return type ? type->packed_width() : 0;
}

/* Keep this predicate in lockstep with assignment_rval_is_constant_ in
 * elaborate.cc. Most constant expressions reduce to NetEConst (including
 * NetECString) or NetECReal. A literal class-handle null deliberately remains
 * NetENull; accepting that result for any other source would also admit
 * nonconstant object expressions such as `new'. */
static bool struct_member_default_is_constant_(const PExpr*source,
						const NetExpr*result)
{
      if (dynamic_cast<const NetEConst*>(result)) return true;
      if (dynamic_cast<const NetECReal*>(result)) return true;
      return dynamic_cast<const PENull*>(source)
	    && dynamic_cast<const NetENull*>(result);
}

static const char* unsupported_struct_member_default_shape_(ivl_type_t type)
{
      if (dynamic_cast<const netuarray_t*>(type))
	    return "fixed-size unpacked array";

      if (const netqueue_t*queue = dynamic_cast<const netqueue_t*>(type))
	    return queue->assoc_compat() ? "associative array" : "queue";

      if (dynamic_cast<const netdarray_t*>(type))
	    return "dynamic array";

      return 0;
}

static bool elaborate_struct_member_default_(Design*des, NetScope*scope,
					     ivl_type_t member_type,
					     const decl_assignment_t*name)
{
      ivl_assert(*name->expr, des);
      ivl_assert(*name->expr, scope);
      ivl_assert(*name->expr, member_type);

      PExpr*source = name->expr.get();
      bool cached = false;
      if (des->get_struct_member_default_validation(source, scope, cached))
	    return cached;

	// Mark before descending so a pathological recursive declaration
	// cannot re-enter the same check indefinitely.
      des->record_struct_member_default_validation(source, scope, false);

      if (const char*shape =
		    unsupported_struct_member_default_shape_(member_type)) {
	    cerr << source->get_fileline() << ": sorry: unpacked-struct "
		 << "default member initializers are not yet supported for "
		 << shape << " member `" << name->name.first
		 << "' in a type declaration." << endl;
	    des->errors += 1;
	    return false;
      }

      unsigned errors_before = des->errors;
      NetExpr*value = elaborate_rval_expr(des, scope, member_type,
					  source, true);
      bool valid = value
	    && des->errors == errors_before
	    && struct_member_default_is_constant_(source, value);

      if (value && des->errors == errors_before && !valid) {
	    cerr << source->get_fileline() << ": error: "
		 << "The RHS expression must be constant." << endl;
	    cerr << source->get_fileline() << "       : "
		 << "This expression violates the rule: " << *value << endl;
	    des->errors += 1;
      } else if (!value && des->errors == errors_before) {
	    cerr << source->get_fileline() << ": error: Unable to elaborate "
		 << "the default value for unpacked struct member `"
		 << name->name.first << "' as a constant expression." << endl;
	    des->errors += 1;
      }

      delete value;
      des->record_struct_member_default_validation(source, scope, valid);
      return valid;
}

ivl_type_t struct_type_t::elaborate_type_raw(Design*des, NetScope*scope) const
{
      netstruct_t*res = new netstruct_t;
      res->set_nominal_identity(
	    this, nominal_type_owner_key_(scope));

      res->set_line(*this);

      res->packed(packed_flag);
      res->set_signed(signed_flag);

      if (union_flag)
	    res->union_flag(true);
      if (tagged_flag)
	    res->tagged_flag(true);

      const bool has_direct_defaults =
	    struct_has_direct_member_defaults_(this);
      bool reported_union_member = false;

      for (list<struct_member_t*>::iterator cur = members->begin()
		 ; cur != members->end() ; ++ cur) {

	      // Elaborate the type of the member.
	    struct_member_t*curp = *cur;

	      // IEEE 1800-2017 7.2/18.4 permits a random qualifier on a
	      // member only when the containing aggregate is an unpacked
	      // structure. Diagnose the declaration here, where the enclosing
	      // packed/union shape is known, instead of accepting and silently
	      // discarding a modifier that cannot have legal semantics.
	    if ((curp->qualifier.test_rand() || curp->qualifier.test_randc())
		&& (packed_flag || union_flag)) {
		  cerr << curp->get_fileline() << ": error: a random qualifier on "
		       << "a struct/union member is only legal within an unpacked "
		       << "structure (IEEE 1800-2017 7.2 and 18.4)." << endl;
		  des->errors += 1;
	    }

	      // R20: a `void` member (IEEE 1800-2017 7.3.2 tag-only
	      // member) is only legal inside a `union tagged`. Reject
	      // it loudly everywhere else instead of quietly building
	      // a bogus 1-bit member -- there is no sensible fallback
	      // meaning for `void` in a struct or a plain union.
	    if (dynamic_cast<void_type_t*>(curp->type.get())
		&& !(union_flag && tagged_flag)) {
		  cerr << curp->get_fileline() << ": error: "
		       << "A `void` member is only allowed in a `union "
		       << "tagged`." << endl;
		  des->errors++;
		  continue;
	    }

	    ivl_type_t mem_vec = curp->type->elaborate_type(des, scope);
	    if (mem_vec == 0)
		  continue;

	      // IEEE 1800-2017/2023 25.9 permits virtual-interface handles
	      // in unpacked structs, but explicitly forbids them as union
	      // members. Check the source type (including typedef and array
	      // carriers) so ordinary interface-port types remain unaffected.
	    if (union_flag
		&& pform_is_virtual_interface_type(
		      des, scope, curp->type.get())) {
		  cerr << curp->get_fileline() << ": error: a virtual interface "
		       << "shall not be used as a union member "
		       << "(IEEE 1800-2017/2023 25.9)." << endl;
		  des->errors += 1;
		  continue;
	    }

	    if (!packed_flag && !union_flag && has_direct_defaults
		&& !reported_union_member) {
		  const netstruct_t*nested = net_type_struct_or_union_(mem_vec);
		  if (nested && nested->union_flag()
		      && curp->names && !curp->names->empty()) {
			cerr << get_fileline() << ": error: individual member "
			     << "defaults are not allowed in an unpacked struct "
			     << "type because it contains union member `"
			     << curp->names->front()->name.first << "'." << endl;
			des->errors += 1;
			reported_union_member = true;
		  }
	    }

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

		  if (union_flag && namep->expr) {
			cerr << namep->expr->get_fileline() << ": error: "
			     << "Union members must not have default values."
			     << endl;
			des->errors++;
		  }

		  if (dynamic_cast<void_type_t*>(curp->type.get())) {
			if (namep->expr) {
			      cerr << namep->expr->get_fileline() << ": error: "
				   << "A `void` tagged-union member must not have "
				   << "a default value." << endl;
			      des->errors++;
			}
			if (!namep->index.empty()) {
			      cerr << curp->get_fileline() << ": error: "
				   << "A `void` tagged-union member must not have "
				   << "array dimensions." << endl;
			      des->errors++;
			      continue;
			}
		  }

		  netstruct_t::member_t memb;
		  memb.name = namep->name.first;
		  memb.qualifier = curp->qualifier;
		  memb.interface_modport =
			pform_interface_modport(des, scope, curp->type.get());
		  memb.net_type = elaborate_array_type(des, scope, *this,
							       mem_vec, namep->index);

		    // IEEE 1800-2017 18.4 restricts random variables to
		    // integral/enum/aggregate values. Reject forbidden source types
		    // at declaration time instead of accepting an illegal qualifier.
		  bool bad_random_type = false;
		  if (!packed_flag && !union_flag
		      && (curp->qualifier.test_rand()
			  || curp->qualifier.test_randc())) {
			const char*what =
			      struct_random_member_forbidden_type_(memb.net_type);
			if (what) {
			      bad_random_type = true;
			      cerr << curp->get_fileline() << ": error: member '"
				   << memb.name << "' of unpacked struct is declared "
				   << (curp->qualifier.test_randc() ? "randc" : "rand")
				   << " but has type " << what << ", which is not an "
				   << "integral type (IEEE 1800-2017 18.4 restricts "
				   << "rand/randc to 2-state/4-state types, enums, "
				   << "and aggregates thereof)." << endl;
			      des->errors += 1;
			}
		  }

		    // Keep this limit in sync with vvp_cobject::randc_period()
		    // and the class-property check in elab_sig.cc. Values above
		    // it fall back to plain random bits, so the loss of cyclic
		    // semantics must never be silent.
		  if (!packed_flag && !union_flag && !bad_random_type
		      && curp->qualifier.test_randc()
		      && memb.net_type) {
			long pw = struct_randc_member_leaf_width_(memb.net_type);
			const long randc_cap_bits = 20;
			if (pw > randc_cap_bits) {
			      cerr << curp->get_fileline() << ": warning: randc member '"
				   << memb.name << "' of unpacked struct has a " << pw
				   << "-bit cyclic leaf, beyond the "
				   << randc_cap_bits << "-bit randc cycle-tracking cap; "
				   << "it will randomize as plain (non-cyclic) rand "
				   << "instead of guaranteeing a full permutation "
				   << "before any repeat." << endl;
			}
		  }

		  if (namep->expr && !packed_flag && !union_flag
		      && !reported_union_member && memb.net_type)
			elaborate_struct_member_default_(des, scope,
							 memb.net_type, namep);
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
				       bool assoc_compat = false,
				       ivl_type_t assoc_index_type = 0,
				       bool assoc_wildcard = false)
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

      return new netqueue_t(base_type, max_idx, assoc_compat,
			    assoc_index_type, assoc_wildcard);
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

      // Keep associative arrays in the assoc-compat queue representation even
      // for finite enum-key cases. Lowering them to a plain unpacked array
      // loses exists/delete/iteration semantics, which UVM relies on. The
      // index type is threaded through (rather than discarded) so type-name
      // introspection ($typename, IEEE 1800-2017 20.6.1) can print the
      // "$[<index type>]" suffix for an associative array.
      return elaborate_queue_type(des, scope, li, base_type, 0, true,
				  index_type, assoc_idx->wildcard_index());
}

// If dims is not empty create an unpacked array type and clear dims, otherwise
// return the base type. Also check that we actually support the base type.
//
// Keep a dynamic-container leaf here. A fixed unpacked array of queue,
// dynamic-array, or associative-array values is a legal SystemVerilog type;
// the object-array backend represents one independent container value per
// fixed slot. Unsupported aggregate nestings are diagnosed after signal and
// class-property materialization, when their storage path is unambiguous.
static ivl_type_t elaborate_static_array_type(Design*, const LineInfo&,
					      ivl_type_t base_type,
					      netranges_t &dims)
{
      if (dims.empty())
	    return base_type;

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

	// IEEE 1800-2017 7.4.5 / 20.7: the rightmost unpacked dimension
	// varies most rapidly, so it is the INNERMOST constructed type.
	// Compose right-to-left so mixed dimension lists nest correctly
	// (`int aq[int][$]` is an associative array of int queues, not
	// a queue of associative arrays).  Runs of contiguous static
	// dimensions collapse into one unpacked-array type, preserving
	// their source order.
      for (list<pform_range_t>::const_reverse_iterator cur = dims.rbegin();
	   cur != dims.rend() ; ++cur) {
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

	      // Reverse iteration delivers static dims innermost-first;
	      // re-insert at the front to keep the source order inside
	      // the collapsed unpacked-array type.
	    dimensions.insert(dimensions.begin(), netrange_t(index_l, index_r));
      }

      return elaborate_static_array_type(des, li, type, dimensions);
}

ivl_type_t uarray_type_t::elaborate_type_raw(Design*des, NetScope*scope) const
{
      ivl_type_t btype = base_type->elaborate_type(des, scope);

      return elaborate_array_type(des, scope, *this, btype, *dims.get());
}

/* A forward or aliased class typedef can temporarily elaborate to the shared
 * integer recovery type while its complete class scope is still being
 * constructed.  Keep that compile-progress state distinct from a genuine
 * scalar/enum/aggregate typedef followed by illegal #(...) overrides. */
static bool typedef_has_class_provenance_(
      const typedef_t*td, std::set<const typedef_t*>&seen)
{
      if (!td || !seen.insert(td).second)
            return false;
      if (td->get_basic_type() == typedef_t::CLASS)
            return true;

      const data_type_t*declared_type = td->get_data_type();
      if (dynamic_cast<const class_type_t*>(declared_type))
            return true;
      if (const typeref_t*alias =
            dynamic_cast<const typeref_t*>(declared_type))
            return typedef_has_class_provenance_(
                  alias->typedef_ref(), seen);
      return false;
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
	/* A #(...) suffix is class specialization syntax. Do not silently
	 * discard it when an exact scalar/enum/aggregate typedef shadows a
	 * same-named class in an outer scope. Besides accepting invalid source,
	 * that lets later weak class recovery bind the unrelated outer class. */
      if (!class_type) {
            std::set<const typedef_t*>class_seen;
            if (use_type == netvector_t::integer_type()
                && typedef_has_class_provenance_(type, class_seen))
                  return use_type;
            cerr << get_fileline() << ": error: Parameter overrides require a "
		 << "class type, but `" << type->name
		 << "` resolves to a non-class type." << endl;
	    des->errors += 1;
	    return use_type;
      }

      /* The parser represents an explicit parameterized interface port such
	 as `bus_if #(16) p` as a typeref to its synthetic interface typedef
	 followed by this override list. Interface implementations share the
	 netclass carrier with classes, but their #(...) suffix is IEEE 1800
	 interface specialization, not class specialization. Route it through the
	 semantic interface interner and preserve any selected modport from the
	 base type. */
      if (class_type->is_interface()) {
	    Module*definition =
		  const_cast<Module*>(class_type->interface_definition());
	    if (!definition)
		  return use_type;
	    NetScope*call_scope = s_type_elaborate_caller_scope_
		  ? s_type_elaborate_caller_scope_ : s;
	    return elaborate_interface_type_(
		  des, call_scope, definition, overrides,
		  class_type->interface_modport());
      }

	/* A typed mailbox is a real parameterized built-in class for matching and
	 * method checking (IEEE 1800-2017/2023 15.4.9). Its method implementation
	 * remains built-in, but its message actual must survive elaboration on a
	 * distinct, semantically interned carrier. */
      {
	    perm_string cn = class_type->get_name();
	    if (cn == perm_string::literal("mailbox")) {
		  NetScope*call_scope = s_type_elaborate_caller_scope_
			? s_type_elaborate_caller_scope_ : s;
		  return const_cast<netclass_t*>(
			elaborate_builtin_mailbox_specialization(
			      des, call_scope, overrides, this));
	    }
	    if (cn == perm_string::literal("semaphore") ||
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

/*
 * IEEE 1800-2017 6.23 `type()` operator. See the type_reference_t
 * comment in pform_types.h for the overall design.
 */
ivl_type_t type_reference_t::elaborate_type_raw(Design*des, NetScope*scope) const
{
      if (named_type)
	    return named_type->elaborate_type(des, scope);

      ivl_assert(*this, expr);

	// A plain (possibly indexed/hierarchical/member-selected)
	// identifier: resolve its exact declared type without evaluating
	// anything -- not even the index expressions, which are only
	// counted structurally by PEIdent::test_type_of_ident().
      if (const PEIdent*ident = dynamic_cast<const PEIdent*>(expr)) {
	    ivl_type_t use_type = ident->test_type_of_ident(des, scope);
	    if (!use_type) {
		  cerr << get_fileline() << ": sorry: type() could not resolve "
		       << "the type of this identifier reference (hierarchical "
		       << "or forward references are not supported)." << endl;
		  des->errors += 1;
	    }
	    return use_type;
      }

	// Any other expression shape: fall back to the same evaluation-free
	// self-determined width/type inference that $bits()/$sizeof() use
	// for their type-name-or-expression argument (PExpr::test_width()).
	// This never elaborates (and so never evaluates) the expression --
	// a side-effecting function call in e.g. `type(f(x))` is never run.
      PExpr::width_mode_t mode = PExpr::SIZED;
      PExpr*mut_expr = const_cast<PExpr*>(expr);
      mut_expr->test_width(des, scope, mode);

      ivl_variable_type_t vt = mut_expr->expr_type();
      unsigned wid = mut_expr->expr_width();

      switch (vt) {
	  case IVL_VT_BOOL:
	  case IVL_VT_LOGIC:
	    if (wid == 0) {
		  cerr << get_fileline() << ": sorry: type() could not "
		       << "determine a self-determined width for this "
		       << "expression." << endl;
		  des->errors += 1;
		  return 0;
	    }
	    return new netvector_t(vt, (long)wid - 1, 0, mut_expr->has_sign());

	  case IVL_VT_REAL:
	    return &netreal_t::type_real;

	  case IVL_VT_STRING:
	    return &netstring_t::type_string;

	  default:
	    cerr << get_fileline() << ": sorry: type() of an expression whose "
		 << "self-determined type is not an integral, real or string "
		 << "value (e.g. a class handle, struct, or array produced by "
		 << "a computed expression rather than a plain identifier) is "
		 << "not supported." << endl;
	    des->errors += 1;
	    return 0;
      }
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

NetScope* class_scoped_typeref_t::find_scope(Design*des, NetScope*s) const
{
      ivl_type_t qualifier_type = resolve_class_type_reference(
            des, s, qualifier());
      const netclass_t*class_type =
            dynamic_cast<const netclass_t*>(qualifier_type);
      if (class_type && class_type->class_scope())
            return const_cast<NetScope*>(class_type->class_scope());

      cerr << get_fileline() << ": error: Class-scoped type qualifier `";
      qualifier()->debug_dump(cerr);
      cerr << "' does not resolve to a class type." << endl;
      des->errors += 1;

      /* Retain the generic member scope only as diagnostic recovery. The
         compilation is already failed, so this cannot silently substitute a
         member from an unrelated visible class. */
      return typeref_t::find_scope(des, s);
}

ivl_type_t typedef_t::elaborate_type(Design *des, NetScope *scope)
{
      if (name == "process" || name == "semaphore" || name == "mailbox") {
	    return builtin_class_type(name);
      }

      if (!data_type.get()) {
	    if (report_unresolved_once()) {
		  cerr << get_fileline() << ": error: Forward typedef `" << name
		       << "` does not resolve to a data type in the same scope."
		       << endl;
		  des->errors++;
	    }

	    // Try to recover
	    return netvector_t::integer_type();
      }

        // Search upwards from where the type was referenced
      scope = scope->find_typedef_scope(des, this);
      if (!scope) {
	      // An unresolved type name that names an INTERFACE module
	      // is an interface type reference — e.g. an interface
	      // port formal `bus_if m` (IEEE 1800-2017 25.3). In this
	      // implementation interfaces are modeled as classes, so
	      // resolve to the interface class type (the same type
	      // `virtual bus_if` produces) instead of degrading the
	      // port to a 32-bit vector.
	    {
		  map<perm_string,Module*>::const_iterator im =
			pform_modules.find(name);
		  if (im != pform_modules.end() && im->second->is_interface) {
			ivl_type_t itype = elaborate_interface_type_(
			      des, nullptr, im->second, nullptr,
			      perm_string());
			if (itype)
			      return itype;
		  }
	    }
	      // Phase 63a/A5: UVM macros declare compiler-synthesized
	      // typedefs like `__tmp_int_t__` (uvm_resource_defines.svh)
	      // inside a begin/end block, then reference them as a
	      // parameter to a parameterized class specialization.  The
	      // specialization runs in the class's scope, not the caller
	      // block, so the typedef lookup misses.  The
	      // netvector_t::integer_type() fallback below is the
	      // intended recovery (the macro expands to `bit [N-1:0]`
	      // with bounded N, which an integer_type approximates
	      // adequately for read-back contexts).  Suppress the noisy
	      // warning for these recognizable UVM-internal typedef
	      // names so a clean UVM compile reports zero warnings on
	      // the standard library.
	      bool is_uvm_internal = false;
	      const std::string sname = std::string(name);
	      if (sname.size() >= 4
		  && sname.compare(0, 2, "__") == 0
		  && sname.compare(sname.size() - 2, 2, "__") == 0)
		    is_uvm_internal = true;
	      if (!is_uvm_internal) {
		    cerr << get_fileline() << ": warning: "
			 << "Can not find the scope type definition `" << name
			 << "' (compile-progress fallback)."
			 << endl;
	      }

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

      if (const netclass_t*class_type = dynamic_cast<const netclass_t*>(type)) {
	    if (class_type->is_unresolved_interface()
		&& !unresolved_interface_reported) {
		  /* Signatures on the unspecialized parameterized-class master
		   * are templates. They may retain an opaque unresolved default;
		   * only a concrete default-selected specialization owes the
		   * diagnostic. Keep this guard here so properties, ports, and
		   * method returns all observe the same lifecycle. */
		  const NetScope*class_scope = scope->get_class_scope();
		  const netclass_t*owner = class_scope
			? class_scope->class_def() : 0;
		  const PClass*pclass = class_scope
			? class_scope->class_pform() : 0;
		  bool generic_master = owner && !owner->specialized_instance()
			&& pclass && pclass->has_parameter_port_list;
		  if (!generic_master) {
			unresolved_interface_reported = true;
			cerr << get_fileline() << ": error: Virtual interface type `"
			     << class_type->get_name()
			     << "` selected by type parameter `" << name
			     << "` is not declared." << endl;
			des->errors += 1;
		  }
	    }
      }

      // Recover
      if (!type)
	    return netvector_t::integer_type();

      return type;
}
