/*
 * Copyright (c) 2000-2026 Stephen Williams (steve@icarus.com)
 * Copyright CERN 2012 / Stephen Williams (steve@icarus.com)
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

# include "config.h"

# include  <typeinfo>
# include  <cstdlib>
# include  <cstring>
# include  <iostream>
# include  <sstream>
# include  <set>

# include  "Module.h"
# include  "PClass.h"
# include  "PEvent.h"
# include  "PExpr.h"
# include  "PGate.h"
# include  "PGenerate.h"
# include  "PPackage.h"
# include  "PTask.h"
# include  "PWire.h"
# include  "Statement.h"
# include  "compiler.h"
# include  "netlist.h"
# include  "netmisc.h"
# include  "netclass.h"
# include  "netstruct.h"
# include  "netenum.h"
# include  "netvector.h"
# include  "netdarray.h"
# include  "netparray.h"
# include  "netqueue.h"
# include  "netscalar.h"
# include  "util.h"
# include  "ivl_assert.h"

using namespace std;

static ivl_type_t resolve_class_handle_type_weak_(Design*des, NetScope*scope,
						  const data_type_t*type_pf,
						  set<const typedef_t*>&seen);
static ivl_type_t resolve_class_handle_placeholder_type_weak_(Design*des,
							      NetScope*scope,
							      const data_type_t*type_pf,
							      set<const typedef_t*>&seen);
static ivl_type_t resolve_class_handle_type_weak_(Design*des, NetScope*scope,
						  const data_type_t*type_pf);
static ivl_type_t resolve_class_handle_placeholder_type_weak_(Design*des,
						      NetScope*scope,
						      const data_type_t*type_pf);

/* IEEE 1800 Annex H.8.9 restricts a DPI function result to the small-value
 * C ABI types. Keep this check on elaborated type identity so typedef aliases
 * work naturally, and recurse through an enum to its H.7.3 base type. */
static bool dpi_function_result_type_allowed_(ivl_type_t type)
{
      if (const netenum_t*enum_type = dynamic_cast<const netenum_t*>(type))
	    return dpi_function_result_type_allowed_(enum_type->base_type_obj());

      if (dynamic_cast<const netreal_t*>(type)
	  || dynamic_cast<const netstring_t*>(type))
	    return true;

      if (type == &netvector_t::chandle_type
	  || type == &netvector_t::atom2s8
	  || type == &netvector_t::atom2u8
	  || type == &netvector_t::atom2s16
	  || type == &netvector_t::atom2u16
	  || type == &netvector_t::atom2s32
	  || type == &netvector_t::atom2u32
	  || type == &netvector_t::atom2s64
	  || type == &netvector_t::atom2u64)
	    return true;

      const netvector_t*vec = dynamic_cast<const netvector_t*>(type);
      return vec && vec->get_scalar()
	  && (vec->base_type() == IVL_VT_BOOL
	      || vec->base_type() == IVL_VT_LOGIC);
}

/* elaborate_class_property_type_ deliberately follows typedef declarations
 * directly so it can repair late class handles without re-entering a class
 * signature through typedef_t::elaborate_type. Preserve the forward-typedef
 * kind check that the generic typedef elaborator would otherwise perform. */
static void validate_class_property_typedef_kind_(Design*des, typedef_t*td,
						   ivl_type_t resolved_type)
{
      if (!des || !td || !resolved_type)
	    return;

      bool type_ok = true;
      switch (td->get_basic_type()) {
      case typedef_t::ENUM:
	    type_ok = dynamic_cast<const netenum_t*>(resolved_type);
	    break;
      case typedef_t::STRUCT: {
	    const netstruct_t*structure =
		  dynamic_cast<const netstruct_t*>(resolved_type);
	    type_ok = structure && !structure->union_flag();
	    break;
      }
      case typedef_t::UNION: {
	    const netstruct_t*structure =
		  dynamic_cast<const netstruct_t*>(resolved_type);
	    type_ok = structure && structure->union_flag();
	    break;
      }
      case typedef_t::CLASS:
	    type_ok = dynamic_cast<const netclass_t*>(resolved_type);
	    break;
      default:
	    break;
      }

      if (type_ok)
	    return;

      const data_type_t*declared_type = td->get_data_type();
      cerr << (declared_type ? declared_type->get_fileline()
			    : td->get_fileline())
	   << ": error: Unexpected resolved type for `" << td->name
	   << "`. It was forward declared as `" << td->get_basic_type()
	   << "` at " << td->get_fileline() << "." << endl;
      des->errors += 1;
}

/* Name recovery is only valid for the compiler's class-forward placeholders.
 * An exact non-class alias can legally shadow an outer class with the same
 * spelling; falling through to ensure_visible_class_type in that case changes
 * the declaration's meaning. Built-in generic classes and interface typedefs
 * use synthetic typedef nodes, so retain their established recovery paths. */
static bool typedef_allows_class_name_recovery_(const typedef_t*td)
{
      if (!td)
	    return false;
      if (td->get_basic_type() == typedef_t::CLASS)
	    return true;
      if (td->name == perm_string::literal("mailbox")
	  || td->name == perm_string::literal("semaphore")
	  || td->name == perm_string::literal("process"))
	    return true;

      const data_type_t*declared_type = td->get_data_type();
      if (dynamic_cast<const interface_type_t*>(declared_type))
	    return true;
      if (const class_type_t*forward_type =
		dynamic_cast<const class_type_t*>(declared_type))
	    return forward_type->name == td->name;
      return false;
}

static ivl_type_t elaborate_class_property_type_(Design*des, NetScope*class_scope,
						 const data_type_t*prop_type,
						 set<const typedef_t*>&seen,
						 bool validate_typedef_kinds)
{
      if (!prop_type)
	    return 0;

      if (const array_base_t*array_type = dynamic_cast<const array_base_t*>(prop_type)) {
	    ivl_type_t base_use_type =
		  elaborate_class_property_type_(des, class_scope,
						 array_type->base_type.get(), seen,
						 validate_typedef_kinds);
	    if (base_use_type && array_type->dims)
		  return elaborate_array_type(des, class_scope, *array_type,
					      base_use_type, *array_type->dims.get());
	    if (base_use_type)
		  return base_use_type;
      }

      /* A typedef can hide the array wrapper itself (`typedef C A[2]`).
       * Follow unparameterized aliases in their declaration scope so the
       * recursive branch above can rebuild the wrapper around the canonical
       * late-resolved class. */
	if (const typeref_t*type_ref = dynamic_cast<const typeref_t*>(prop_type)) {
	    typedef_t*td = type_ref->typedef_ref();
	    if (td && !type_ref->parameter_values() && seen.insert(td).second) {
		  /* mailbox, semaphore and process are represented by synthetic
		   * typedefs whose declaration payload is only a parser placeholder.
		   * Unwrapping that payload as an ordinary alias turns the builtin
		   * class into an unresolved type parameter and eventually into int.
		   * Recover the canonical builtin before following user aliases. */
		  if (netclass_t*builtin = builtin_class_type(td->name))
			return builtin;

		  /* This branch deliberately unwraps the typedef so an array
		   * alias can be rebuilt around a late-resolved class element.
		   * Elaborate that borrowed declaration in the typedef's own
		   * scope. Using the reference scope here creates a second
		   * nominal type for non-class aliases, notably a package enum
		   * used by a class property. */
		  NetScope*type_scope =
			class_scope->find_typedef_scope(des, td);
		  if (!type_scope)
			type_scope = type_ref->find_scope(des, class_scope);
		  if (!type_scope)
			type_scope = class_scope;
		  if (ivl_type_t alias_type = elaborate_class_property_type_(
			des, type_scope, td->get_data_type(), seen,
			validate_typedef_kinds)) {
			if (validate_typedef_kinds)
			      validate_class_property_typedef_kind_(des, td, alias_type);
			return alias_type;
		  }
	    }
      }

      if (ivl_type_t class_prop_type =
              resolve_class_handle_type_weak_(des, class_scope, prop_type)) {
            /* Class-handle properties can initially elaborate through generic
             * or placeholder aliases. Resolve them before the generic type
             * elaborator: the latter may fully elaborate a cached
             * specialization while one of its method signatures is still in
             * progress. Apart from doing unnecessary work, that re-entry can
             * request the method body before its NetFuncDef is attached. */
            return class_prop_type;
      }

      ivl_type_t use_type =
            const_cast<data_type_t*>(prop_type)->elaborate_type(des, class_scope);
      if (ivl_type_t placeholder_prop_type =
              resolve_class_handle_placeholder_type_weak_(des, class_scope, prop_type)) {
            return placeholder_prop_type;
      }

      return use_type;
}

static ivl_type_t elaborate_class_property_type_(Design*des,
						 NetScope*class_scope,
						 const data_type_t*prop_type,
						 bool validate_typedef_kinds = false)
{
      set<const typedef_t*>seen;
      return elaborate_class_property_type_(des, class_scope, prop_type, seen,
					     validate_typedef_kinds);
}

/* Re-elaborate class property types from their parse-form declarations after
 * every class definition is visible.  Do not transform the type already in
 * property_table_: a forward declaration can leave a perfectly class-typed,
 * but non-canonical, placeholder or default specialization there.  Starting
 * from the declaration also lets elaborate_class_property_type_ rebuild the
 * complete fixed/dynamic/queue wrapper around a repaired class element. */
void netclass_t::repair_bare_class_property_types(Design*des)
{
      if (!des || !class_scope_)
	    return;

      const PClass*pclass = class_scope_->class_pform();
      if (!pclass || !pclass->type)
	    return;

      for (map<perm_string,size_t>::iterator cur = properties_.begin()
	       ; cur != properties_.end() ; ++cur) {
	    map<perm_string,class_type_t::prop_info_t>::const_iterator declared =
		  pclass->type->properties.find(cur->first);
	    if (declared == pclass->type->properties.end()
		|| !declared->second.type)
		  continue;
	    if (!specialize_bare_class_at_concrete_use(
		  des, class_scope_, declared->second.type.get(), 0, false))
		  continue;

	    ivl_type_t repaired = elaborate_class_property_type_(
		  des, class_scope_, declared->second.type.get());
	    if (!repaired)
		  continue;

	    prop_t&property = property_table_[cur->second];
	    property.type = repaired;

	    if (!declared->second.qual.test_static())
		  continue;
	    NetNet*sig = class_scope_->find_signal(cur->first);
	    if (!sig)
		  continue;

	    /* Fixed unpacked dimensions live on NetNet separately from its
	     * element net_type.  Other containers are scalar NetNets whose full
	     * queue/darray type belongs in net_type. */
	    if (const netuarray_t*array_type =
		  dynamic_cast<const netuarray_t*>(repaired))
		  sig->set_net_type(array_type->element_type());
	    else
		  sig->set_net_type(repaired);
      }
}

static ivl_type_t resolve_typedef_alias_class_handle_type_weak_(Design*des,
								NetScope*scope,
								typedef_t*td,
								set<const typedef_t*>&seen,
								bool placeholder)
{
      if (!td || !td->get_data_type())
	    return 0;

      pair<set<const typedef_t*>::iterator,bool> insert_rc = seen.insert(td);
      if (!insert_rc.second)
	    return 0;

      const data_type_t*alias_type = td->get_data_type();
      if (placeholder)
	    return resolve_class_handle_placeholder_type_weak_(des, scope, alias_type, seen);

      return resolve_class_handle_type_weak_(des, scope, alias_type, seen);
}

static ivl_type_t resolve_class_handle_type_weak_(Design*des, NetScope*scope,
						  const data_type_t*type_pf,
						  set<const typedef_t*>&seen)
{
      if (!des || !scope || !type_pf)
	    return 0;

      if (const array_base_t*array_type =
	    dynamic_cast<const array_base_t*>(type_pf)) {
	    ivl_type_t element_type = resolve_class_handle_type_weak_(
		  des, scope, array_type->base_type.get(), seen);
	    if (element_type && array_type->dims)
		  return elaborate_array_type(des, scope, *array_type,
					      element_type, *array_type->dims.get());
	    return element_type;
      }

      if (const class_type_t*class_pf = dynamic_cast<const class_type_t*>(type_pf))
	    return ensure_visible_class_type(des, scope, class_pf->name);

      if (const type_parameter_t*type_par = dynamic_cast<const type_parameter_t*>(type_pf)) {
	    ivl_type_t par_type = 0;
	    scope->get_parameter(des, type_par->name, par_type);
	    if (const netclass_t*class_type =
		  dynamic_cast<const netclass_t*>(par_type)) {
		    /* Resolving a class-valued type parameter here means it is the
		     * type of a concrete declaration (property, signal, or return),
		     * not merely another type-parameter default.  Force the narrow
		     * type-parameter elaborator so a lazily accepted unresolved
		     * virtual-interface default is diagnosed at this first use. */
		    if (class_type->is_unresolved_interface())
			  return const_cast<type_parameter_t*>(type_par)
				->elaborate_type(des, scope);
		    return par_type;
	    }
	    return 0;
      }

      const typeref_t*type_ref = dynamic_cast<const typeref_t*>(type_pf);
      if (!type_ref)
	    return 0;

      NetScope*type_scope = type_ref->find_scope(des, scope);
      if (!type_scope)
	    return 0;

      typedef_t*td = type_ref->typedef_ref();
      if (!td)
	    return 0;

      if (ivl_type_t alias_class =
		  resolve_typedef_alias_class_handle_type_weak_(des, type_scope, td, seen, false)) {
	    if (const parmvalue_t*overrides = type_ref->parameter_values()) {
		  if (const netclass_t*base_class =
			      dynamic_cast<const netclass_t*>(alias_class))
			// Use the original caller scope (not the package scope) so
			// override expressions like #(.AddrWidth(AddrWidth)) are
			// evaluated in the scope where the type reference appears.
			return const_cast<netclass_t*>(
			      elaborate_specialized_class_type(des, scope, base_class,
						       overrides, false));
	    }
	    return alias_class;
      }

      if (!typedef_allows_class_name_recovery_(td))
	    return 0;

      netclass_t*base_class = ensure_visible_class_type(des, type_scope, td->name);
      if (!base_class)
	    return 0;

      if (const parmvalue_t*overrides = type_ref->parameter_values())
	    // Use the original caller scope, not type_scope (the package scope).
	    return const_cast<netclass_t*>(
		  elaborate_specialized_class_type(des, scope, base_class, overrides,
						   false));

      return base_class;
}

static ivl_type_t resolve_class_handle_placeholder_type_weak_(Design*des,
							      NetScope*scope,
							      const data_type_t*type_pf,
							      set<const typedef_t*>&seen)
{
      if (!des || !scope || !type_pf)
	    return 0;

      if (const array_base_t*array_type =
	    dynamic_cast<const array_base_t*>(type_pf)) {
	    ivl_type_t element_type = resolve_class_handle_placeholder_type_weak_(
		  des, scope, array_type->base_type.get(), seen);
	    if (element_type && array_type->dims)
		  return elaborate_array_type(des, scope, *array_type,
					      element_type, *array_type->dims.get());
	    return element_type;
      }

      if (getenv("IVL_FOREACH_TYPE_TRACE")) {
            cerr << "[resolve-placeholder] type_pf="
                 << typeid(*type_pf).name() << endl;
      }

      if (const class_type_t*class_pf = dynamic_cast<const class_type_t*>(type_pf))
	    return ensure_visible_class_type(des, scope, class_pf->name);

      if (const type_parameter_t*type_par = dynamic_cast<const type_parameter_t*>(type_pf)) {
	    ivl_type_t par_type = 0;
	    scope->get_parameter(des, type_par->name, par_type);
	    if (dynamic_cast<const netclass_t*>(par_type))
		  return par_type;
	    return 0;
      }

      // Foreach loop variables for class-keyed assoc arrays (e.g.
      //   bit m_maps[uvm_reg_map];
      //   foreach (m_maps[map]) ...)
      // arrive here as `foreach_index_type_t`. Evaluate it to the
      // resolved key type so the loop var is predeclared as a cobj
      // signal instead of a default string. Without this the foreach
      // index var ends up `IVL_VT_STRING`, which mistypes downstream
      // codegen (`%aa/first/str` instead of `%aa/first/obj`) and
      // breaks UVM register-model traversals.
      if (const foreach_index_type_t*idx_type =
		dynamic_cast<const foreach_index_type_t*>(type_pf)) {
	    ivl_type_t resolved =
		  const_cast<foreach_index_type_t*>(idx_type)->elaborate_type(des, scope);
	    if (getenv("IVL_FOREACH_TYPE_TRACE")) {
		  cerr << "[resolve-placeholder/foreach] resolved=";
		  if (resolved)
			cerr << "base=" << ivl_type_base(resolved);
		  else
			cerr << "<nil>";
		  cerr << endl;
	    }
	    if (resolved && ivl_type_base(resolved) == IVL_VT_CLASS)
		  return resolved;
	    return 0;
      }

      const typeref_t*type_ref = dynamic_cast<const typeref_t*>(type_pf);
      if (!type_ref)
	    return 0;

      NetScope*type_scope = type_ref->find_scope(des, scope);
      if (!type_scope)
	    return 0;

      typedef_t*td = type_ref->typedef_ref();
      if (!td)
	    return 0;

      if (ivl_type_t alias_class =
		  resolve_typedef_alias_class_handle_type_weak_(des, type_scope, td, seen, true)) {
	    return alias_class;
      }

      if (!typedef_allows_class_name_recovery_(td))
	    return 0;

      netclass_t*base_class = ensure_visible_class_type(des, type_scope, td->name);
      return base_class;
}

static ivl_type_t resolve_class_handle_type_weak_(Design*des, NetScope*scope,
						  const data_type_t*type_pf)
{
      set<const typedef_t*>seen;
      ivl_type_t resolved =
	    resolve_class_handle_type_weak_(des, scope, type_pf, seen);

	/* The recursive resolver deliberately leaves circular placeholders and
	 * bare class references generic.  At this top-level declaration use,
	 * however, IEEE 1800-2017 8.25 requires a bare parameterized class to
	 * denote the same default specialization as C#().  Normalize only here:
	 * the placeholder resolver below must stay generic while breaking
	 * declaration cycles. */
      return specialize_bare_class_at_concrete_use(
	    des, scope, type_pf, resolved, false);
}

static ivl_type_t resolve_class_handle_placeholder_type_weak_(Design*des,
							      NetScope*scope,
							      const data_type_t*type_pf)
{
      set<const typedef_t*>seen;
      return resolve_class_handle_placeholder_type_weak_(des, scope, type_pf, seen);
}

#if 0
/* These functions are not currently used. */
static bool get_const_argument(NetExpr*exp, verinum&res)
{
      switch (exp->expr_type()) {
	  case IVL_VT_REAL: {
	    NetECReal*cv = dynamic_cast<NetECReal*>(exp);
	    if (cv == 0) return false;
	    verireal tmp = cv->value();
	    res = verinum(tmp.as_long());
	    break;
	  }

	  case IVL_VT_BOOL:
	  case IVL_VT_LOGIC: {
	    NetEConst*cv = dynamic_cast<NetEConst*>(exp);
	    if (cv == 0) return false;
	    res = cv->value();
	    break;
	  }

	  default:
	    ivl_assert(*exp, 0);;
      }

      return true;
}

static bool get_const_argument(NetExpr*exp, long&res)
{
      verinum tmp;
      bool rc = get_const_argument(exp, tmp);
      if (rc == false) return false;
      res = tmp.as_long();
      return true;
}
#endif

void Statement::elaborate_sig(Design*, NetScope*) const
{
}

static void sig_check_data_type(Design*des, const NetScope*scope,
			        const PWire *wire, NetNet *sig)
{
      ivl_type_t type = sig->net_type();

      if (!type)
	    return;

      /* The underlying type of a user-defined nettype was validated when
       * NetNetType was elaborated.  Do not feed it back through the legacy
       * builtin-net filter below: that filter coerces non-logic wires to
       * unresolved wires and rejects unpacked aggregate nets, both of which
       * are wrong for a valid UDNT (and would discard a resolution function
       * on bit/real nettypes). */
      if (sig->user_nettype())
	    return;

      if ((sig->type() == NetNet::WIRE) && (sig->data_type() != IVL_VT_LOGIC)) {
	    if (gn_cadence_types_flag) {
		  sig->type(NetNet::UNRESOLVED_WIRE);
	    } else {
		  cerr << wire->get_fileline() << ": error: Net `"
		       << wire->basename() << "` can not be of type `"
		       << sig->data_type() << "`." << endl;
		  des->errors++;
	    }
      }

      if (type->packed()) {
	    switch (type->base_type()) {
	    case IVL_VT_LOGIC: // 4-state packed is allowed by the standard
	    case IVL_VT_BOOL: // Icarus allows 2-state packed as an extension
		  return;
	    default:
		  break;
	    }
      }

      // Icarus allows real nets as an extension
      if (type->base_type() == IVL_VT_REAL)
	    return;

      // Phase 63a/A1: allow interface-typed module ports.  Interfaces
      // elaborate to netclass_t with is_interface()==true; treat them
      // as a permitted port type even though netclass_t isn't a wire.
      // Modport direction enforcement is a follow-up.
      if (const netclass_t*nc = dynamic_cast<const netclass_t*>(type)) {
	    if (nc->is_interface())
		  return;
      }
      if (wire->symbol_type() == PNamedItem::NET) {
	    cerr << wire->get_fileline() << ": error: Net `"
	         << wire->basename() << "` can not be of type `"
		 << sig->data_type() << "`." << endl;
	    des->errors++;
      } else if (scope->type() == NetScope::MODULE &&
	         sig->port_type() != NetNet::NOT_A_PORT) {
	    // Module ports only support wire types a the moment
	    cerr << wire->get_fileline() << ": sorry: Port `"
	         << wire->basename() << "` of module `"
	         << scope->module_name()
	         << "` with type `" << sig->data_type()
		 << "` is not supported."
	         << endl;
	    des->errors++;
      }
}

static void sig_check_port_type(Design*des, const NetScope*scope,
			        const PWire *wire, const NetNet *sig)
{
      if (sig->port_type() == NetNet::PREF
          && scope->type() == NetScope::MODULE) {
	    cerr << wire->get_fileline() << ": warning: "
		 << "Reference ports on modules are not fully supported." << endl;
      }

      // Some extra checks for module ports
      if (scope->type() != NetScope::MODULE)
	    return;

	/* If the signal is an input and is also declared as a
	   reg, then report an error. In SystemVerilog a input
	   is allowed to be a register. It will get converted
	   to a unresolved wire when the port is connected. */

      if (sig->port_type() == NetNet::PINPUT &&
	  sig->type() == NetNet::REG && !gn_var_can_be_uwire()) {
	    cerr << wire->get_fileline() << ": error: Port `"
		 << wire->basename() << "` of module `"
		 << scope->module_name()
		 << "` is declared as input and as a reg type." << endl;
	    des->errors += 1;
      }

      if (sig->port_type() == NetNet::PINOUT &&
	  sig->type() == NetNet::REG) {
	      // Interface-typed ports (IEEE 1800-2017 25.3) are class
	      // handles held in variables; the inout-vs-reg wire rule
	      // does not apply to them.
	    const netclass_t*ifc =
		  dynamic_cast<const netclass_t*>(sig->net_type());
	    if (!ifc || !ifc->is_interface()) {
		  cerr << wire->get_fileline() << ": error: Port `"
		       << wire->basename() << "` of module `"
		       << scope->module_name()
		       << "` is declared as inout and as a reg type." << endl;
		  des->errors += 1;
	    }
      }

      if (sig->port_type() == NetNet::PINOUT &&
	  sig->data_type() == IVL_VT_REAL) {
	    cerr << wire->get_fileline() << ": error: Port `"
		 << wire->basename() << "` of module `"
		 << scope->module_name()
		 << "` is declared as a real inout port." << endl;
	    des->errors += 1;
      }
}

/* Find only typedef graphs whose declarations require validation even when
 * the alias is never referenced: explicit dimensions must bind to constants,
 * while struct/union member defaults and random qualifiers carry
 * declaration-time constraints.
 * Eagerly elaborating every typedef is both unnecessary and harmful for large
 * class libraries whose unused parameterized aliases are intentionally lazy. */
static bool pform_type_needs_declaration_validation_(
		const data_type_t*type, map<const data_type_t*,unsigned char>&memo)
{
      if (!type)
	    return false;

      map<const data_type_t*,unsigned char>::iterator prior = memo.find(type);
      if (prior != memo.end()) {
	    if (prior->second == 1)
		  return false;
	    return prior->second == 3;
      }

      memo[type] = 1;
      bool found = false;

      if (const typeref_t*ref = dynamic_cast<const typeref_t*>(type)) {
	    typedef_t*td = ref->typedef_ref();
	    found = td && pform_type_needs_declaration_validation_(
		  td->get_data_type(), memo);
      } else if (const array_base_t*array =
		       dynamic_cast<const array_base_t*>(type)) {
	    found = (array->dims && !array->dims->empty())
		 || pform_type_needs_declaration_validation_(
		      array->base_type.get(), memo);
      } else if (const vector_type_t*vector =
		       dynamic_cast<const vector_type_t*>(type)) {
	    found = vector->pdims && !vector->pdims->empty();
      } else if (const enum_type_t*enumeration =
		       dynamic_cast<const enum_type_t*>(type)) {
	    found = pform_type_needs_declaration_validation_(
		  enumeration->base_type.get(), memo);
      } else if (const struct_type_t*structure =
		       dynamic_cast<const struct_type_t*>(type)) {
	    if (structure->members) {
		  for (const struct_member_t*member : *structure->members) {
			if (!member)
			      continue;
			if (member->qualifier.test_rand()
			    || member->qualifier.test_randc()) {
			      found = true;
			      break;
			}
			if (member->names) {
			      for (const decl_assignment_t*name : *member->names) {
				    if (name && name->expr) {
					  found = true;
					  break;
				    }
			      }
			}
			if (found)
			      break;
			found = pform_type_needs_declaration_validation_(
			      member->type.get(), memo);
			if (found)
			      break;
		  }
	    }
      }

      memo[type] = found ? 3 : 2;
      return found;
}

static void elaborate_sig_required_typedefs_(
		Design*des, NetScope*scope,
		const map<perm_string,typedef_t*>&typedefs)
{
      map<const data_type_t*,unsigned char> memo;
      for (const auto&entry : typedefs) {
	    typedef_t*td = entry.second;
	    if (!td)
		  continue;
	    if (td->get_data_type()
		&& !pform_type_needs_declaration_validation_(
		      td->get_data_type(), memo))
		  continue;
	    td->elaborate_type(des, scope);
      }
}

bool PScope::elaborate_sig_wires_(Design*des, NetScope*scope) const
{
      bool flag = true;

      for (map<perm_string,PWire*>::const_iterator wt = wires.begin()
		 ; wt != wires.end() ; ++ wt ) {

	    PWire*cur = (*wt).second;
	    NetNet*sig = cur->elaborate_sig(des, scope);

	    if (!sig || sig->scope() != scope)
		  continue;

	    sig_check_data_type(des, scope, cur, sig);
	    sig_check_port_type(des, scope, cur, sig);

      }

      elaborate_sig_required_typedefs_(des, scope, typedefs);

      return flag;
}

static void elaborate_sig_funcs(Design*des, NetScope*scope,
				const map<perm_string,PFunction*>&funcs)
{
      typedef map<perm_string,PFunction*>::const_iterator mfunc_it_t;

      for (mfunc_it_t cur = funcs.begin()
		 ; cur != funcs.end() ; ++ cur ) {

	    hname_t use_name ( (*cur).first );
	    NetScope*fscope = scope->child(use_name);
	    if (fscope == 0) {
		  cerr << (*cur).second->get_fileline() << ": internal error: "
		       << "Child scope for function " << (*cur).first
		       << " missing in " << scope_path(scope) << "." << endl;
		  des->errors += 1;
		  continue;
	    }

	    if (debug_elaborate) {
		  cerr << cur->second->get_fileline() << ": elaborate_sig_funcs: "
		       << "Elaborate function " << use_name
		       << " in " << scope_path(fscope) << endl;
	    }

	    cur->second->elaborate_sig(des, fscope);
      }
}

static void elaborate_sig_tasks(Design*des, NetScope*scope,
				const map<perm_string,PTask*>&tasks)
{
      typedef map<perm_string,PTask*>::const_iterator mtask_it_t;

      for (mtask_it_t cur = tasks.begin()
		 ; cur != tasks.end() ; ++ cur ) {
	    NetScope*tscope = scope->child( hname_t((*cur).first) );
	    ivl_assert(*(*cur).second, tscope);
	    (*cur).second->elaborate_sig(des, tscope);
      }
}

static void elaborate_sig_classes(Design*des, NetScope*scope,
				  const map<perm_string,PClass*>&classes)
{
      for (map<perm_string,PClass*>::const_iterator cur = classes.begin()
		 ; cur != classes.end() ; ++ cur) {
	    netclass_t*use_class = scope->find_class(des, cur->second->pscope_name());
	    use_class->elaborate_sig(des, cur->second);
      }
}

bool PPackage::elaborate_sig(Design*des, NetScope*scope) const
{
      bool flag = true;

      if (debug_elaborate) {
	    cerr << get_fileline() << ": PPackage::elaborate_sig: "
		 << "Start package scope=" << scope_path(scope) << endl;
      }

      flag = elaborate_sig_wires_(des, scope) && flag;

	// After all the wires are elaborated, we are free to
	// elaborate the ports of the tasks defined within this
	// module. Run through them now.

      elaborate_sig_funcs(des, scope, funcs);
      elaborate_sig_tasks(des, scope, tasks);
      elaborate_sig_classes(des, scope, classes);
      scope->elaborate_nettypes(des);

      if (debug_elaborate) {
	    cerr << get_fileline() << ": PPackage::elaborate_sig: "
		 << "Done package scope=" << scope_path(scope)
		 << ", flag=" << flag << endl;
      }

      return flag;
}

/* M8 increment 2a (IEEE 1800-2017 14.13): create a per-instance public
   synchronization event/tick for EVERY clocking block (`_ivl_cbtrig$<cb>`
   and `_ivl_cbtick$<cb>`), plus sample variables for sampleable inputs.
   A clocking block remains a synchronization event even when it declares no
   items; making the trigger conditional on a sample variable incorrectly
   reduced an itemless @(cb) to its raw Active-region edge. The process that
   fires/toggles these names is synthesized later in Module::elaborate. The
   names are created in the signal pass so static and virtual-interface event
   references can resolve them from any scope. Blocks with sampleable items
   also retain the existing `_ivl_smptrig$<cb>`/`_ivl_smptick$<cb>` pair:
   that pair is internal to input sampling and output-drive scheduling, while
   the universal pair represents the public clocking synchronization event.

   Inputs that cannot be sampled (non-vector types, arrays) keep the existing
   alias behavior; the read-rewrite helpers key off the presence of the sample
   variable, so the two stay consistent. */
static void elaborate_sig_clocking_samples_(Design*des, NetScope*scope, const Module*mod)
{
      typedef std::map<perm_string,Module::PClocking*>::const_iterator cb_it_t;
      for (cb_it_t cur = mod->clocking_blocks.begin()
		 ; cur != mod->clocking_blocks.end() ; ++cur) {
	    const Module::PClocking*cb = cur->second;
	    if (!cb->event || cb->event->event_expressions().empty())
		  continue;

	    bool any = false;
	    bool any_output = false;
	    for (vector<perm_string>::const_iterator sig_it = cb->signals.begin()
		       ; sig_it != cb->signals.end() ; ++sig_it) {
		  NetNet::PortType dir = cb->signal_direction(*sig_it);
		  bool is_in  = (dir==NetNet::PINPUT || dir==NetNet::PINOUT);
		  bool is_out = (dir==NetNet::POUTPUT || dir==NetNet::PINOUT);

		  NetNet*raw = resolve_clocking_raw_signal(des, scope, cb, *sig_it);
		  if (!raw) {
			if (cb->decl_assigns.count(*sig_it))
			      cerr << cb->get_fileline() << ": sorry: "
				   << "clocking_decl_assign for `" << *sig_it
				   << "' is not a resolvable signal path; "
				   << "the clockvar is not sampled." << endl;
			continue;   // otherwise reported when used
		  }
		  if (raw->data_type() != IVL_VT_LOGIC
		      && raw->data_type() != IVL_VT_BOOL) {
			cerr << cb->get_fileline() << ": sorry: clocking "
			     << "signal `" << *sig_it << "' of block `"
			     << cb->name << "' has a non-vector type; "
			     << "it keeps the alias behavior." << endl;
			continue;
		  }
		  if (raw->pin_count() != 1 || raw->unpacked_dimensions() > 0) {
			cerr << cb->get_fileline() << ": sorry: clocking "
			     << "signal `" << *sig_it << "' of block `"
			     << cb->name << "' is an array; it keeps the "
			     << "alias behavior." << endl;
			continue;
		  }

		  ivl_type_t vt = raw->net_type();

		    /* Edge-qualified skews (14.4 `input negedge [#d]`):
		       the delay/#1step part is honored; the edge
		       qualifier itself is not applied. Diagnose rather
		       than silently ignore. */
		  {
			const pform_clocking_skew_t*esk = nullptr;
			std::map<perm_string,pform_clocking_skew_t>::const_iterator eit;
			if (is_in) {
			      eit = cb->in_skews.find(*sig_it);
			      if (eit != cb->in_skews.end()) esk = &eit->second;
			      else if (cb->default_in_set) esk = &cb->default_in;
			}
			if ((!esk || !esk->edge) && is_out) {
			      eit = cb->out_skews.find(*sig_it);
			      if (eit != cb->out_skews.end()) esk = &eit->second;
			      else if (cb->default_out_set) esk = &cb->default_out;
			}
			if (esk && esk->edge) {
			      cerr << cb->get_fileline() << ": sorry: the "
				   << "edge qualifier on the skew of clocking "
				   << "signal `" << *sig_it << "' (block `"
				   << cb->name << "') is not applied; the "
				   << "delay part is honored (IEEE 1800-2017 "
				   << "14.4)." << endl;
			}
		  }

		  if (is_in) {
			string sname = string("_ivl_smp$") + cb->name.str()
			      + "$" + sig_it->str();
			perm_string smp_name = lex_strings.make(sname.c_str());
			if (!scope->find_signal(smp_name)) {
			      NetNet*smp;
			      if (vt) {
				    smp = new NetNet(scope, smp_name, NetNet::REG, vt);
			      } else {
				    netvector_t*vec = new netvector_t(raw->data_type(),
								      raw->vector_width()-1,
								      0, raw->get_signed());
				    smp = new NetNet(scope, smp_name, NetNet::REG, vec);
			      }
			      smp->set_line(*cb);
			}

			  /* Numeric input skew (14.4, M8-2d): the sample
			     source is a #d-delayed shadow of the raw
			     signal, read after the NBA region of the
			     event step (so #0 sees this step's NBA
			     updates -- the Observed value). */
			PExpr*skew_delay = nullptr;
			if (cb->input_skew(*sig_it, skew_delay)
			    == Module::PClocking::SKEW_DELAY) {
			      string wname = string("_ivl_sshw$") + cb->name.str()
				    + "$" + sig_it->str();
			      perm_string shw_name = lex_strings.make(wname.c_str());
			      if (!scope->find_signal(shw_name)) {
				    NetNet*shw;
				    if (vt) {
					  shw = new NetNet(scope, shw_name, NetNet::REG, vt);
				    } else {
					  netvector_t*vec = new netvector_t(raw->data_type(),
									    raw->vector_width()-1,
									    0, raw->get_signed());
					  shw = new NetNet(scope, shw_name, NetNet::REG, vec);
				    }
				    shw->set_line(*cb);
			      }
			}
			any = true;
		  }

		    /* Output clockvars get a drive buffer + per-bit pending state
		       (IEEE 1800-2017 14.16, M8-2b): drives issued between
		       clocking events are buffered and applied at the next
		       event by the synthesized apply process. */
		  if (is_out) {
			string bname = string("_ivl_obuf$") + cb->name.str()
			      + "$" + sig_it->str();
			perm_string obuf_name = lex_strings.make(bname.c_str());
			if (!scope->find_signal(obuf_name)) {
			      NetNet*obuf;
			      if (vt) {
				    obuf = new NetNet(scope, obuf_name, NetNet::REG, vt);
			      } else {
				    netvector_t*vec = new netvector_t(raw->data_type(),
								      raw->vector_width()-1,
								      0, raw->get_signed());
				    obuf = new NetNet(scope, obuf_name, NetNet::REG, vec);
			      }
			      obuf->set_line(*cb);
			}
			string pname = string("_ivl_opend$") + cb->name.str()
			      + "$" + sig_it->str();
			perm_string opend_name = lex_strings.make(pname.c_str());
			if (!scope->find_signal(opend_name)) {
			      NetNet*opend;
			      if (vt) {
				    opend = new NetNet(scope, opend_name, NetNet::REG, vt);
			      } else {
				    netvector_t*pvec = new netvector_t(raw->data_type(),
							  raw->vector_width()-1,
							  0, false);
				    opend = new NetNet(scope, opend_name, NetNet::REG, pvec);
			      }
			      opend->set_line(*cb);
			}
			any_output = true;
			any = true;
		  }
	    }

	    string tname = string("_ivl_cbtrig$") + cb->name.str();
	    perm_string trig_name = lex_strings.make(tname.c_str());
	    if (!scope->find_event(trig_name)) {
		  NetEvent*trig = new NetEvent(trig_name);
		  trig->set_line(*cb);
		  scope->add_event(trig);
	    }

	      /* The synchronizer also toggles a tick bit after the Observed
		 boundary and all sample stores. @(vif.cb) maps to an anyedge
		 wait on this interface-class property because a named event
		 cannot be reached through a class handle. */
	    string kname = string("_ivl_cbtick$") + cb->name.str();
	    perm_string tick_name = lex_strings.make(kname.c_str());
	    if (!scope->find_signal(tick_name)) {
		    /* A 2-state tick defaults to zero before any initial process
		       runs. The explicit prologue assignment is therefore 0->0,
		       not the spurious X->0 ANYEDGE a virtual-interface waiter
		       could otherwise observe at time zero. */
		  netvector_t*tvec = new netvector_t(IVL_VT_BOOL, 0, 0, false);
		  NetNet*tick = new NetNet(scope, tick_name, NetNet::REG, tvec);
		  tick->set_line(*cb);
	    }

	      /* Keep the established sample/output trigger and tick for blocks
		 with usable items. Their NBA-region timing is part of the output
		 buffering protocol; the public pair above must not move it. */
	    if (any) {
		  string stname = string("_ivl_smptrig$") + cb->name.str();
		  perm_string strig_name = lex_strings.make(stname.c_str());
		  if (!scope->find_event(strig_name)) {
			NetEvent*strig = new NetEvent(strig_name);
			strig->set_line(*cb);
			scope->add_event(strig);
		  }

		  string skname = string("_ivl_smptick$") + cb->name.str();
		  perm_string stick_name = lex_strings.make(skname.c_str());
		  if (!scope->find_signal(stick_name)) {
			netvector_t*svec = new netvector_t(IVL_VT_LOGIC, 0, 0, false);
			NetNet*stick = new NetNet(scope, stick_name, NetNet::REG, svec);
			stick->set_line(*cb);
		  }
	    }

	      /* A VIF drive issued after @(vif.cb) toggles this per-instance
		 kick bit. The output-apply process waits on it as well as on the
		 ordinary clocking trigger, so current-event drives use the same
		 resolved raw target and skew as buffered drives. */
	    if (any_output) {
		  string dname = string("_ivl_odkick$") + cb->name.str();
		  perm_string kick_name = lex_strings.make(dname.c_str());
		  if (!scope->find_signal(kick_name)) {
			netvector_t*dvec = new netvector_t(IVL_VT_LOGIC, 0, 0, false);
			NetNet*kick = new NetNet(scope, kick_name, NetNet::REG, dvec);
			kick->set_line(*cb);
		  }
	    }
      }
}

bool Module::elaborate_sig(Design*des, NetScope*scope) const
{
      bool flag = true;

	// Scan all the ports of the module, and make sure that each
	// is connected to wires that have port declarations.
      for (unsigned idx = 0 ;  idx < ports.size() ;  idx += 1) {
	    Module::port_t*pp = ports[idx];
	    if (pp == 0)
		  continue;

	      // The port has a name and an array of expressions. The
	      // expression are all identifiers that should reference
	      // wires within the scope.
	    map<perm_string,PWire*>::const_iterator wt;
	    for (unsigned cc = 0 ;  cc < pp->expr.size() ;  cc += 1) {
		  pform_name_t port_path (pp->expr[cc]->path().name);
		    // A concatenated wire of a port really should not
		    // have any hierarchy.
		  if (port_path.size() != 1) {
			cerr << get_fileline() << ": internal error: "
			     << "Port " << port_path << " has a funny name?"
			     << endl;
			des->errors += 1;
		  }

		  wt = wires.find(peek_tail_name(port_path));

		  if (wt == wires.end()) {
			cerr << get_fileline() << ": error: "
			     << "Port " << port_path << " ("
			     << (idx+1) << ") of module " << mod_name()
			     << " is not declared within module." << endl;
			des->errors += 1;
			continue;
		  }

		  if ((*wt).second->get_port_type() == NetNet::NOT_A_PORT) {
			cerr << get_fileline() << ": error: "
			     << "Port " << pp->expr[cc]->path() << " ("
			     << (idx+1) << ") of module " << mod_name()
			     << " has no direction declaration."
			     << endl;
			des->errors += 1;
		  }
	    }
      }

      flag = elaborate_sig_wires_(des, scope) && flag;

	// Clocking-block input sample variables and trigger events
	// (IEEE 1800-2017 14.13) -- after the wires so the underlying
	// signals exist to copy types from.
      elaborate_sig_clocking_samples_(des, scope, this);

	// Run through all the generate schemes to elaborate the
	// signals that they hold. Note that the generate schemes hold
	// the scopes that they instantiated, so we don't pass any
	// scope in.
      typedef list<PGenerate*>::const_iterator generate_it_t;
      for (generate_it_t cur = generate_schemes.begin()
		 ; cur != generate_schemes.end() ; ++ cur ) {
	    (*cur) -> elaborate_sig(des, scope);
      }

	// Get all the gates of the module and elaborate them by
	// connecting them to the signals. The gate may be simple or
	// complex. What we are looking for is gates that are modules
	// that can create scopes and signals.

      const list<PGate*>&gl = get_gates();

      for (list<PGate*>::const_iterator gt = gl.begin()
		 ; gt != gl.end() ; ++ gt ) {

	    flag &= (*gt)->elaborate_sig(des, scope);
      }

	// After all the wires are elaborated, we are free to
	// elaborate the ports of the tasks defined within this
	// module. Run through them now.

      elaborate_sig_funcs(des, scope, funcs);
      elaborate_sig_tasks(des, scope, tasks);
      elaborate_sig_classes(des, scope, classes);
      scope->elaborate_nettypes(des);

	// initial and always blocks may contain begin-end and
	// fork-join blocks that can introduce scopes. Therefore, I
	// get to scan processes here.

      typedef list<PProcess*>::const_iterator proc_it_t;

      for (proc_it_t cur = behaviors.begin()
		 ; cur != behaviors.end() ; ++ cur ) {

	    (*cur) -> statement() -> elaborate_sig(des, scope);
      }

      return flag;
}

/* IEEE 1800-2017 18.4 gives randc a narrower type domain than rand:
 * each cyclic leaf must be integral. Unpacked containers preserve the leaf
 * rule, while a packed aggregate is legal only when all of its members are
 * themselves legal cyclic leaves. Keep this recursive so typedef-expanded
 * arrays and nested packed records receive one declaration diagnostic rather
 * than being judged by a misleading outer base_type(). */
static bool class_randc_property_type_ok_(ivl_type_t type)
{
      if (!type)
	    return false;

      if (const netarray_t*array = dynamic_cast<const netarray_t*>(type))
	    return class_randc_property_type_ok_(array->element_type());

      if (type == &netvector_t::chandle_type)
	    return false;

      if (dynamic_cast<const netenum_t*>(type))
	    return true;

      if (const netvector_t*vec = dynamic_cast<const netvector_t*>(type)) {
	    ivl_variable_type_t base = vec->base_type();
	    return base == IVL_VT_BOOL || base == IVL_VT_LOGIC;
      }

      if (const netstruct_t*record = dynamic_cast<const netstruct_t*>(type)) {
	    if (!record->packed())
		  return false;
	    for (const netstruct_t::member_t&member : record->members())
		  if (!class_randc_property_type_ok_(member.net_type))
			return false;
	    return true;
      }

      return false;
}

/* The runtime cycle bitmap is per packed randc value. For an unpacked
 * container that value is one element, whereas a packed array is itself one
 * value. Peel only unpacked array/container layers before applying the
 * implementation width cap. */
static long class_randc_property_leaf_width_(ivl_type_t type)
{
      while (type) {
	    const netarray_t*array = dynamic_cast<const netarray_t*>(type);
	    if (!array || type->packed())
		  break;
	    type = array->element_type();
      }
      return type ? type->packed_width() : 0;
}

static bool interface_method_type_equivalent_(ivl_type_t left,
					       ivl_type_t right)
{
      if (left == right)
	    return true;
      return left && right && left->type_equivalent(right)
	  && right->type_equivalent(left);
}

static const NetBaseDef*interface_method_def_(const NetScope*method)
{
      if (!method)
	    return 0;
      if (method->type() == NetScope::FUNC)
	    return method->func_def();
      if (method->type() == NetScope::TASK)
	    return method->task_def();
      return 0;
}

static bool interface_method_signatures_match_(const NetScope*left,
						const NetScope*right)
{
      if (!(left && right) || left->type() != right->type())
	    return false;

      const NetBaseDef*left_def = interface_method_def_(left);
      const NetBaseDef*right_def = interface_method_def_(right);
      if (!(left_def && right_def))
	    return false;

      unsigned left_first = 0;
      unsigned right_first = 0;
      if (left_def->port_count() && left_def->port(0)
	  && left_def->port(0)->name() == perm_string::literal("@"))
	    left_first = 1;
      if (right_def->port_count() && right_def->port(0)
	  && right_def->port(0)->name() == perm_string::literal("@"))
	    right_first = 1;
      if (left_def->port_count() - left_first
	  != right_def->port_count() - right_first)
	    return false;

      for (unsigned idx = 0 ; idx < left_def->port_count() - left_first
		 ; idx += 1) {
	    const NetNet*left_port = left_def->port(left_first + idx);
	    const NetNet*right_port = right_def->port(right_first + idx);
	    if (!(left_port && right_port)
		|| left_port->port_type() != right_port->port_type()
		|| !interface_method_type_equivalent_(left_port->net_type(),
						       right_port->net_type()))
		  return false;
      }

      if (left->type() == NetScope::FUNC) {
	    const NetFuncDef*left_func = left->func_def();
	    const NetFuncDef*right_func = right->func_def();
	    if (!(left_func && right_func)
		|| left_func->is_void() != right_func->is_void())
		  return false;
	    if (!left_func->is_void()
		&& !interface_method_type_equivalent_(
		      left_func->return_sig()->net_type(),
		      right_func->return_sig()->net_type()))
		  return false;
      }

      return true;
}

static bool interface_method_has_body_(const NetScope*method)
{
      if (!method)
	    return false;
      if (method->type() == NetScope::FUNC) {
	    if (const PFunction*pfunc = method->func_pform())
		  return pfunc->get_statement() != 0;
	    const NetFuncDef*def = method->func_def();
	    return def && def->proc();
      }
      if (method->type() == NetScope::TASK) {
	    if (const PTask*ptask = method->task_pform())
		  return ptask->get_statement() != 0;
	    const NetTaskDef*def = method->task_def();
	    return def && def->proc();
      }
      return false;
}

static void collect_interface_class_graph_(const netclass_t*type,
					   vector<const netclass_t*>&nodes,
					   set<const netclass_t*>&seen)
{
      if (!type || !seen.insert(type).second)
	    return;
      nodes.push_back(type);
      for (const netclass_t*parent : type->interface_types())
	    collect_interface_class_graph_(parent, nodes, seen);
}

static NetScope*find_concrete_class_method_(const netclass_t*type,
					     perm_string name)
{
      for (const netclass_t*cur = type ; cur ; cur = cur->get_super()) {
	    const NetScope*scope = cur->class_scope();
	    NetScope*method = scope ? const_cast<NetScope*>(
		  scope->child(hname_t(name))) : 0;
	    if (method && (method->type() == NetScope::FUNC
		|| method->type() == NetScope::TASK))
		  return method;
      }
      return 0;
}

static void validate_interface_class_relations_(Design*des,
					 netclass_t*use_class,
					 PClass*pclass)
{
      if (!(des && use_class && pclass))
	    return;

      vector<const netclass_t*>interfaces;
      set<const netclass_t*>seen;
      for (const netclass_t*cur = use_class ; cur ; cur = cur->get_super())
	    for (const netclass_t*relation : cur->interface_types())
		  collect_interface_class_graph_(relation, interfaces, seen);

      map<perm_string,vector<NetScope*> >requirements;
      map<perm_string,set<const PClass*> >type_declarations;
      map<const PClass*,const netclass_t*>specializations;
      set<const PClass*>reported_specializations;

      for (const netclass_t*interface_type : interfaces) {
	    const NetScope*interface_scope = interface_type
		  ? interface_type->class_scope() : 0;
	    const PClass*interface_pclass = interface_scope
		  ? interface_scope->class_pform() : 0;
	    if (!(interface_scope && interface_pclass))
		  continue;

	    auto prior = specializations.find(interface_pclass);
	    if (prior == specializations.end()) {
		  specializations[interface_pclass] = interface_type;
	    } else if (prior->second != interface_type) {
		  if (reported_specializations.insert(interface_pclass).second) {
			cerr << pclass->get_fileline()
			     << ": error: Interface class `"
			     << interface_type->get_name()
			     << "' is inherited through incompatible parameter "
			     << "specializations in the same interface graph."
			     << endl;
			des->errors += 1;
		  }
		  /* The specialization conflict is the root cause. Do not also
		     compare the two specializations' method signatures and emit a
		     derivative second diagnostic for the same invalid edge. */
		  continue;
	    }

	    for (const auto&cur : interface_pclass->funcs) {
		  NetScope*method = const_cast<NetScope*>(
			interface_scope->child(hname_t(cur.first)));
		  if (method)
			requirements[cur.first].push_back(method);
	    }
	    for (const auto&cur : interface_pclass->tasks) {
		  NetScope*method = const_cast<NetScope*>(
			interface_scope->child(hname_t(cur.first)));
		  if (method)
			requirements[cur.first].push_back(method);
	    }

	    for (const auto&cur : interface_pclass->parameters)
		  if (cur.second && cur.second->type_flag)
			type_declarations[cur.first].insert(interface_pclass);
	    for (const auto&cur : interface_pclass->typedefs)
		  type_declarations[cur.first].insert(interface_pclass);
      }

      if (use_class->is_interface_class()) {
	    for (const auto&cur : type_declarations) {
		  if (cur.second.size() < 2
		      || pclass->typedefs.find(cur.first) != pclass->typedefs.end())
			continue;
		  cerr << pclass->get_fileline() << ": error: Interface class `"
		       << use_class->get_name() << "' inherits conflicting type `"
		       << cur.first << "' from multiple interface classes and must "
		       << "declare a local resolution." << endl;
		  des->errors += 1;
	    }
      }

      for (const auto&cur : requirements) {
	    const vector<NetScope*>&methods = cur.second;
	    bool signatures_conflict = false;
	    for (size_t idx = 1 ; idx < methods.size() ; idx += 1) {
		  if (!interface_method_signatures_match_(methods[0], methods[idx])) {
			signatures_conflict = true;
			break;
		  }
	    }
	    if (signatures_conflict) {
		  cerr << pclass->get_fileline() << ": error: Interface method `"
		       << cur.first << "' has incompatible inherited prototypes in `"
		       << use_class->get_name() << "'." << endl;
		  des->errors += 1;
		  continue;
	    }

	    if (use_class->is_interface_class())
		  continue;

	    NetScope*implementation = find_concrete_class_method_(use_class,
							     cur.first);
	    if (implementation && !implementation->is_virtual_method()) {
		  cerr << pclass->get_fileline() << ": error: Method `" << cur.first
		       << "' in class `" << use_class->get_name()
		       << "' must be virtual to implement an interface-class method."
		       << endl;
		  des->errors += 1;
		  continue;
	    }
	    if (implementation
		&& !interface_method_signatures_match_(methods[0], implementation)) {
		  cerr << pclass->get_fileline() << ": error: Method `" << cur.first
		       << "' in class `" << use_class->get_name()
		       << "' does not match its interface-class prototype." << endl;
		  des->errors += 1;
		  continue;
	    }

	    if (!use_class->is_virtual()
		&& (!implementation || !interface_method_has_body_(implementation))) {
		  cerr << pclass->get_fileline() << ": error: Non-virtual class `"
		       << use_class->get_name() << "' does not implement interface "
		       << "method `" << cur.first << "'." << endl;
		  des->errors += 1;
	    }
      }
}

static void validate_interface_class_items_(Design*des, const PClass*pclass)
{
      if (!(des && pclass && pclass->type
	    && pclass->type->interface_class))
	    return;

      for (const auto&cur : pclass->type->properties) {
	    cerr << cur.second.get_fileline() << ": error: Data property `"
		 << cur.first << "' is not allowed in an interface class."
		 << endl;
	    des->errors += 1;
      }

      for (const auto&cur : pclass->type->constraints) {
	    const LineInfo*source = cur.second.empty()
		  ? static_cast<const LineInfo*>(pclass)
		  : static_cast<const LineInfo*>(cur.second.front());
	    cerr << source->get_fileline() << ": error: Constraint `"
		 << cur.first << "' is not allowed in an interface class."
		 << endl;
	    des->errors += 1;
      }

      for (const auto&cur : pclass->funcs) {
	    if (!cur.second || !cur.second->is_pure_method()) {
		  cerr << (cur.second ? cur.second->get_fileline()
			       : pclass->get_fileline())
		       << ": error: Function `" << cur.first
		       << "' in an interface class must be a pure virtual method."
		       << endl;
		  des->errors += 1;
		  continue;
	    }
	    if (!cur.second->interface_qualifier_valid()) {
		  cerr << cur.second->get_fileline()
		       << ": error: Access or static qualifiers are not allowed "
			  "on an interface-class method." << endl;
		  des->errors += 1;
	    }
      }

      for (const auto&cur : pclass->tasks) {
	    if (!cur.second || !cur.second->is_pure_method()) {
		  cerr << (cur.second ? cur.second->get_fileline()
			       : pclass->get_fileline())
		       << ": error: Task `" << cur.first
		       << "' in an interface class must be a pure virtual method."
		       << endl;
		  des->errors += 1;
		  continue;
	    }
	    if (!cur.second->interface_qualifier_valid()) {
		  cerr << cur.second->get_fileline()
		       << ": error: Access or static qualifiers are not allowed "
			  "on an interface-class method." << endl;
		  des->errors += 1;
	    }
      }

      for (const auto&cur : pclass->events) {
	    cerr << (cur.second ? cur.second->get_fileline()
			       : pclass->get_fileline())
		 << ": error: Event `" << cur.first
		 << "' is not allowed in an interface class." << endl;
	    des->errors += 1;
      }

      for (const auto&cur : pclass->classes) {
	    cerr << (cur.second ? cur.second->get_fileline()
			       : pclass->get_fileline())
		 << ": error: Nested class `" << cur.first
		 << "' is not allowed in an interface class." << endl;
	    des->errors += 1;
      }

      for (const auto*cur : pclass->type->covergroups) {
	    cerr << pclass->get_fileline()
		 << ": error: Covergroup `" << (cur ? cur->name : perm_string())
		 << "' is not allowed in an interface class." << endl;
	    des->errors += 1;
      }
}

static void validate_external_class_constraints_(Design*des, PClass*pclass)
{
      if (!(des && pclass && pclass->type))
	    return;

      for (auto&cur : pclass->type->extern_constraints) {
	    class_type_t::extern_constraint_info_t&info = cur.second;
	    if (info.reported)
		  continue;
	    cerr << info.get_fileline() << ": error: Extern constraint `"
		 << cur.first << "' has no out-of-body definition in class `"
		 << pclass->pscope_name() << "'." << endl;
	    des->errors += 1;
	    info.reported = true;
      }
}

/* PExpr keeps source syntax, not a persistent symbol binding. Bind names in
 * covergroup ranges as soon as the enclosing class signature is complete so a
 * found mutable/ref/inaccessible name cannot later fall through to an enum or
 * parameter with the same spelling. */
static void bind_covergroup_range_expr_(
      Design*des, netclass_t*parent, netclass_t*cg_class,
      const class_type_t::pform_covergroup_t*cgdef, perm_string bin_name,
      const PExpr*expr, bool standalone)
{
      if (!expr) return;

      if (const PEIdent*id = dynamic_cast<const PEIdent*>(expr)) {
	    const pform_scoped_name_t&path = id->path();
	    bool direct = !path.package && !id->has_scoped_type_prefix()
		  && path.size() == 1 && !path.name.front().local_scope
		  && path.name.front().index.empty();
	    if (direct && !cg_class->covgrp_range_ref(expr)) {
		  perm_string name = peek_head_name(path);
		  for (size_t idx = 0; idx < cgdef->ctor_formals.size(); idx += 1) {
			if (cgdef->ctor_formals[idx] != name) continue;
			bool is_ref = idx < cgdef->ctor_formal_is_ref.size()
			      && cgdef->ctor_formal_is_ref[idx];
			cg_class->bind_covgrp_range_ref(
			      expr, is_ref ? netclass_t::COVGRP_RANGE_CTOR_REF
					   : netclass_t::COVGRP_RANGE_CTOR_VALUE,
			      -1, (unsigned)idx);
			if (is_ref) {
			      cerr << expr->get_fileline()
				   << ": error: covergroup bin `" << bin_name
				   << "' range expression references ref covergroup "
				      "argument `" << name
				   << "'; IEEE 1800 19.5 permits only non-ref "
				      "covergroup arguments." << endl;
			      des->errors += 1;
			}
			return;
		  }

		  if (!standalone) {
			int prop = parent->property_idx_from_name(name);
			if (prop >= 0) {
			      property_qualifier_t qual =
				    parent->get_prop_qual((size_t)prop);
			      const netclass_t*owner =
				    parent->get_prop_declaring_class((size_t)prop);
			      bool has_initializer =
				    parent->get_prop_has_decl_initializer((size_t)prop);
			      netclass_t::covgrp_range_ref_kind_t kind;
			      if (qual.test_local() && owner != parent)
				    kind = netclass_t::COVGRP_RANGE_PARENT_LOCAL;
			      else if (!qual.test_const())
				    kind = netclass_t::COVGRP_RANGE_PARENT_MUTABLE;
			      else if (qual.test_static() && !has_initializer)
				    kind = netclass_t::COVGRP_RANGE_PARENT_BAD_CONST;
			      else if (has_initializer)
				    kind = netclass_t::COVGRP_RANGE_PARENT_GLOBAL_CONST;
			      else
				    kind = netclass_t::COVGRP_RANGE_PARENT_INSTANCE_CONST;

			      cg_class->bind_covgrp_range_ref(expr, kind, prop);
			      if (kind == netclass_t::COVGRP_RANGE_PARENT_INSTANCE_CONST)
				    cg_class->add_covgrp_parent_const_dependency(
					  (unsigned)prop, expr);

			      if (kind == netclass_t::COVGRP_RANGE_PARENT_MUTABLE) {
				    cerr << expr->get_fileline()
					 << ": error: covergroup bin `" << bin_name
					 << "' range expression references mutable "
					 << (qual.test_static() ? "static " : "")
					 << "enclosing-class property `" << name
					 << "'; IEEE 1800 19.5 permits only constant "
					    "expressions, enclosing-class global or "
					    "instance constants, or non-ref covergroup "
					    "arguments." << endl;
				    des->errors += 1;
			      } else if (kind == netclass_t::COVGRP_RANGE_PARENT_LOCAL) {
				    cerr << expr->get_fileline()
					 << ": error: covergroup bin `" << bin_name
					 << "' range expression references local property `"
					 << name << "' of base class `" << owner->get_name()
					 << "'; it is not visible in the derived enclosing "
					    "class (IEEE 1800 8.18, 19.4)." << endl;
				    des->errors += 1;
			      } else if (kind == netclass_t::COVGRP_RANGE_PARENT_BAD_CONST) {
				    cerr << expr->get_fileline()
					 << ": error: covergroup bin `" << bin_name
					 << "' range expression references static const "
					    "enclosing-class property `" << name
					 << "' without a declaration initializer; IEEE "
					    "1800 8.19 requires a global constant to be "
					    "initialized in its declaration." << endl;
				    des->errors += 1;
			      }
			      return;
			}
		  }
	    }

	    for (const name_component_t&component : path.name)
		  for (const index_component_t&index : component.index) {
			bind_covergroup_range_expr_(des, parent, cg_class, cgdef,
						    bin_name, index.msb,
						    standalone);
			bind_covergroup_range_expr_(des, parent, cg_class, cgdef,
						    bin_name, index.lsb,
						    standalone);
		  }
	    return;
      }
      if (const PEUnary*unary = dynamic_cast<const PEUnary*>(expr)) {
	    bind_covergroup_range_expr_(des, parent, cg_class, cgdef, bin_name,
					unary->get_expr(), standalone);
	    return;
      }
      if (const PEBinary*binary = dynamic_cast<const PEBinary*>(expr)) {
	    bind_covergroup_range_expr_(des, parent, cg_class, cgdef, bin_name,
					binary->get_left(), standalone);
	    bind_covergroup_range_expr_(des, parent, cg_class, cgdef, bin_name,
					binary->get_right(), standalone);
	    return;
      }
      if (const PETernary*ternary = dynamic_cast<const PETernary*>(expr)) {
	    bind_covergroup_range_expr_(des, parent, cg_class, cgdef, bin_name,
					ternary->get_cond(), standalone);
	    bind_covergroup_range_expr_(des, parent, cg_class, cgdef, bin_name,
					ternary->get_true(), standalone);
	    bind_covergroup_range_expr_(des, parent, cg_class, cgdef, bin_name,
					ternary->get_false(), standalone);
	    return;
      }
      if (const PECallFunction*call = dynamic_cast<const PECallFunction*>(expr)) {
	    bind_covergroup_range_expr_(des, parent, cg_class, cgdef, bin_name,
					call->receiver_expr(), standalone);
	    for (const named_pexpr_t&parm : call->get_parms())
		  bind_covergroup_range_expr_(des, parent, cg_class, cgdef, bin_name,
					      parm.parm, standalone);
	    for (const PExpr*with : call->with_constraints())
		  bind_covergroup_range_expr_(des, parent, cg_class, cgdef, bin_name,
					      with, standalone);
	    return;
      }
      if (const PEMemberAccess*member = dynamic_cast<const PEMemberAccess*>(expr)) {
	    bind_covergroup_range_expr_(des, parent, cg_class, cgdef, bin_name,
					member->base(), standalone);
	    return;
      }
      if (const PEConcat*concat = dynamic_cast<const PEConcat*>(expr)) {
	    bind_covergroup_range_expr_(des, parent, cg_class, cgdef, bin_name,
					concat->repeat_expr(), standalone);
	    for (const PExpr*part : concat->stream_parms())
		  bind_covergroup_range_expr_(des, parent, cg_class, cgdef, bin_name,
					      part, standalone);
	    return;
      }
      if (const PEAssignPattern*pattern = dynamic_cast<const PEAssignPattern*>(expr)) {
	    bind_covergroup_range_expr_(des, parent, cg_class, cgdef, bin_name,
					pattern->replication(), standalone);
	    for (const PExpr*part : pattern->parms())
		  bind_covergroup_range_expr_(des, parent, cg_class, cgdef, bin_name,
					      part, standalone);
	    return;
      }
      if (const PEStreaming*stream = dynamic_cast<const PEStreaming*>(expr)) {
	    bind_covergroup_range_expr_(des, parent, cg_class, cgdef, bin_name,
					stream->get_inner(), standalone);
	    return;
      }
      if (const PECastSize*cast = dynamic_cast<const PECastSize*>(expr)) {
	    bind_covergroup_range_expr_(des, parent, cg_class, cgdef, bin_name,
					cast->cast_size(), standalone);
	    bind_covergroup_range_expr_(des, parent, cg_class, cgdef, bin_name,
					cast->cast_base(), standalone);
	    return;
      }
      if (const PECastType*cast = dynamic_cast<const PECastType*>(expr)) {
	    bind_covergroup_range_expr_(des, parent, cg_class, cgdef, bin_name,
					cast->cast_base(), standalone);
	    return;
      }
      if (const PECastSign*cast = dynamic_cast<const PECastSign*>(expr)) {
	    bind_covergroup_range_expr_(des, parent, cg_class, cgdef, bin_name,
					cast->cast_base(), standalone);
	    return;
      }
      if (const PEInside*inside = dynamic_cast<const PEInside*>(expr)) {
	    bind_covergroup_range_expr_(des, parent, cg_class, cgdef, bin_name,
					inside->get_expr(), standalone);
	    for (const inside_range_t&range : inside->get_ranges()) {
		  bind_covergroup_range_expr_(des, parent, cg_class, cgdef, bin_name,
					      range.lo, standalone);
		  bind_covergroup_range_expr_(des, parent, cg_class, cgdef, bin_name,
					      range.hi, standalone);
		  bind_covergroup_range_expr_(des, parent, cg_class, cgdef, bin_name,
					      range.weight, standalone);
	    }
      }
}

static void bind_covergroup_select_ranges_(
      Design*des, netclass_t*parent, netclass_t*cg_class,
      const class_type_t::pform_covergroup_t*cgdef, perm_string bin_name,
      const class_type_t::pform_cross_t::select_t*select, bool standalone)
{
      if (!select) return;
      for (const std::pair<PExpr*,PExpr*>&range : select->intersect_ranges) {
	    bind_covergroup_range_expr_(des, parent, cg_class, cgdef, bin_name,
					range.first, standalone);
	    bind_covergroup_range_expr_(des, parent, cg_class, cgdef, bin_name,
					range.second, standalone);
      }
      bind_covergroup_select_ranges_(des, parent, cg_class, cgdef, bin_name,
				     select->a, standalone);
      bind_covergroup_select_ranges_(des, parent, cg_class, cgdef, bin_name,
				     select->b, standalone);
}

static void bind_covergroup_ranges_(
      Design*des, netclass_t*parent, netclass_t*cg_class,
      const class_type_t::pform_covergroup_t*cgdef, bool standalone)
{
      if (!cg_class || cg_class->covgrp_range_bindings_complete()) return;

      for (const class_type_t::pform_coverpoint_t&cp : cgdef->coverpoints)
	    for (const class_type_t::pform_cov_bins_t&bin : cp.bins) {
		  for (const std::pair<PExpr*,PExpr*>&range : bin.ranges) {
			bind_covergroup_range_expr_(des, parent, cg_class, cgdef,
						    bin.name, range.first,
						    standalone);
			bind_covergroup_range_expr_(des, parent, cg_class, cgdef,
						    bin.name, range.second,
						    standalone);
		  }
		  for (const std::vector<class_type_t::pform_cov_trans_term_t>&seq :
		       bin.trans_seqs)
			for (const class_type_t::pform_cov_trans_term_t&term : seq) {
			      for (const std::pair<PExpr*,PExpr*>&range : term.ranges) {
				    bind_covergroup_range_expr_(
					  des, parent, cg_class, cgdef, bin.name,
					  range.first, standalone);
				    bind_covergroup_range_expr_(
					  des, parent, cg_class, cgdef, bin.name,
					  range.second, standalone);
			      }
			      bind_covergroup_range_expr_(des, parent, cg_class,
						  cgdef, bin.name,
						  term.repeat_lo, standalone);
			      bind_covergroup_range_expr_(des, parent, cg_class,
						  cgdef, bin.name,
						  term.repeat_hi, standalone);
			}
	    }

      for (const class_type_t::pform_cross_t&cross : cgdef->crosses)
	    for (const class_type_t::pform_cross_t::cross_bin_t&bin : cross.bins)
		  bind_covergroup_select_ranges_(des, parent, cg_class, cgdef,
					 bin.name, bin.select, standalone);

      cg_class->set_covgrp_range_bindings_complete(true);
}

/* Resolve only the two pform l-value spellings that can denote a property of
 * the object being constructed: `prop' and `this.prop'.  Keep this binding
 * deliberately narrower than PEIdent elaboration.  In particular, a method
 * local/formal must win over an unqualified property name, and assigning a
 * selected element is not initialization of the instance constant itself. */
class covergroup_constructor_order_classifier_t :
      public pform_constructor_order_classifier_t {
    public:
      covergroup_constructor_order_classifier_t(
	    const netclass_t*parent, const PFunction*constructor,
	    const map<size_t,const netclass_t*>&embedded_covergroups)
      : parent_(parent), constructor_(constructor),
	embedded_covergroups_(embedded_covergroups)
      { }

      bool classify_instance_constant_initializer(
	    const pform_constructor_order_assignment_t&assignment,
	    size_t&property_idx) const override
      {
	    if (!assignment.plain_blocking)
		  return false;

	    int prop = property_from_lval_(assignment);
	    if (prop < 0)
		  return false;

	    size_t idx = static_cast<size_t>(prop);
	    property_qualifier_t qual = parent_->get_prop_qual(idx);
	    if (!qual.test_const() || qual.test_static()
		|| parent_->get_prop_has_decl_initializer(idx)
		|| parent_->get_prop_declaring_class(idx) != parent_)
		  return false;

	    property_idx = idx;
	    return true;
      }

      bool classify_embedded_covergroup_constructor(
	    const pform_constructor_order_assignment_t&assignment,
	    vector<pform_constructor_order_dependency_t>&dependencies)
	    const override
      {
	    if (!assignment.plain_blocking
		|| !dynamic_cast<const PENewClass*>(assignment.rval))
		  return false;

	    int prop = property_from_lval_(assignment);
	    if (prop < 0)
		  return false;

	    map<size_t,const netclass_t*>::const_iterator found =
		  embedded_covergroups_.find(static_cast<size_t>(prop));
	    if (found == embedded_covergroups_.end() || !found->second
		|| !found->second->covgrp_range_bindings_complete())
		  return false;

	    for (const netclass_t::covgrp_parent_const_dep_t&dep :
		 found->second->covgrp_parent_const_dependencies()) {
		  pform_constructor_order_dependency_t use_dep;
		  use_dep.property_idx = dep.parent_prop;
		  use_dep.reference_site = dep.ref_site;
		  use_dep.covergroup_name = parent_->get_prop_name((size_t)prop);
		  dependencies.push_back(use_dep);
	    }
	    return !dependencies.empty();
      }

      bool classify_repeat_count(const PExpr*count,
				 const vector<const PBlock*>*block_stack,
				 long&iterations) const override
      {
	    const PEIdent*ident = dynamic_cast<const PEIdent*>(count);
	    if (!ident || !parent_)
		  return false;

	    const pform_scoped_name_t&path = ident->path();
	    if (path.package || ident->has_scoped_type_prefix()
		|| path.size() != 1 || path.name.front().local_scope
		|| !path.name.front().index.empty())
		  return false;

	    perm_string name = path.name.front().name;
	    if (unqualified_name_is_shadowed_(name, block_stack))
		  return false;

	    // Stay aligned with ordinary unqualified constructor-body lookup:
	    // inherited value parameters are not currently resolved there, so
	    // recognizing them only in this audit would create a semantic split.
	    const NetScope*class_scope = parent_->class_scope();
	    if (!class_scope)
		  return false;
	    map<perm_string,NetScope::param_expr_t>::const_iterator found =
		  class_scope->parameters.find(name);
	    if (found == class_scope->parameters.end())
		  return false;

	    const NetScope::param_expr_t&parameter = found->second;
	    // The class-scope pass evaluates specialization parameters before
	    // this audit. Never force evaluation here: doing so would repeat
	    // diagnostics and elaborate method expressions out of order.
	    if (parameter.type_flag || parameter.is_array_param
		|| parameter.val_expr || !parameter.val)
		  return false;

	    const NetEConst*constant =
		  dynamic_cast<const NetEConst*>(parameter.val);
	    if (!constant || constant->is_unbounded()
		|| !constant->value().is_defined())
		  return false;

	    const verinum&value = constant->value();
	    if (value.is_zero() || value.is_negative()) {
		  iterations = 0;
		  return true;
	    }
	    if (value.as_ulong64() == 1) {
		  iterations = 1;
		  return true;
	    }
	    return false;
      }

    private:
      const netclass_t*parent_;
      const PFunction*constructor_;
      const map<size_t,const netclass_t*>&embedded_covergroups_;

      static bool scope_declares_(const LexicalScope*scope, perm_string name)
      {
	    return scope && (scope->wires.find(name) != scope->wires.end()
			     || scope->local_symbols.find(name)
				!= scope->local_symbols.end()
			     || scope->explicit_imports.find(name)
				!= scope->explicit_imports.end());
      }

      bool unqualified_name_is_shadowed_(
	    perm_string name,
	    const vector<const PBlock*>*block_stack) const
      {
	    if (block_stack)
		  for (vector<const PBlock*>::const_reverse_iterator cur =
		       block_stack->rbegin(); cur != block_stack->rend(); ++cur)
			if (scope_declares_(*cur, name))
			      return true;

	    if (scope_declares_(constructor_, name))
		  return true;

	    const vector<pform_tf_port_t>*ports = constructor_
		  ? constructor_->peek_ports() : nullptr;
	    if (ports)
		  for (const pform_tf_port_t&port : *ports)
			if (port.port && port.port->basename() == name)
			      return true;
	    return false;
      }

      int property_from_lval_(
	    const pform_constructor_order_assignment_t&assignment) const
      {
	    perm_string property_name;
	    bool explicit_this = false;

	    if (const PEIdent*ident =
		  dynamic_cast<const PEIdent*>(assignment.lval)) {
		  const pform_scoped_name_t&path = ident->path();
		  if (path.package || ident->has_scoped_type_prefix()
		      || path.name.empty())
			return -1;

		  pform_name_t::const_iterator cur = path.name.begin();
		  if (path.size() == 1) {
			if (cur->local_scope || !cur->index.empty())
			      return -1;
			property_name = cur->name;
		  } else if (path.size() == 2
			     && cur->name == perm_string::literal(THIS_TOKEN)
			     && !cur->local_scope && cur->index.empty()) {
			explicit_this = true;
			++cur;
			if (cur->local_scope || !cur->index.empty())
			      return -1;
			property_name = cur->name;
		  } else {
			return -1;
		  }
	    } else if (const PEMemberAccess*member =
		       dynamic_cast<const PEMemberAccess*>(assignment.lval)) {
		  const PEIdent*base = dynamic_cast<const PEIdent*>(member->base());
		  if (!base)
			return -1;
		  const pform_scoped_name_t&path = base->path();
		  if (path.package || base->has_scoped_type_prefix()
		      || path.size() != 1 || path.name.front().local_scope
		      || !path.name.front().index.empty()
		      || path.name.front().name
			   != perm_string::literal(THIS_TOKEN))
			return -1;
		  explicit_this = true;
		  property_name = member->member_name();
	    } else {
		  return -1;
	    }

	    if (property_name.nil()
		|| (!explicit_this && unqualified_name_is_shadowed_(
		      property_name, assignment.block_stack)))
		  return -1;
	    return parent_->property_idx_from_name(property_name);
      }
};

static void report_constructor_order_violations_(
      Design*des, const netclass_t*parent,
      const pform_constructor_order_result_t&result)
{
      for (const pform_constructor_order_violation_t&violation :
	   result.violations) {
	    const char*property = parent->get_prop_name(violation.property_idx);
	    const char*covergroup = violation.covergroup_name
		  ? violation.covergroup_name : "<unknown>";
	    const LineInfo*site = violation.constructor_site
		  ? violation.constructor_site
		  : violation.initializer_site
		    ? violation.initializer_site : violation.reference_site;
	    string fileline = site ? site->get_fileline() : string("<unknown>");

	    cerr << fileline << ": error: ";
	    switch (violation.kind) {
		case PFORM_CTOR_ORDER_NOT_INITIALIZED:
		  cerr << "enclosing-class instance constant `" << property
		       << "' used by covergroup `" << covergroup
		       << "' must be initialized before the covergroup constructor "
			  "call (IEEE 1800 19.5).";
		  break;
		case PFORM_CTOR_ORDER_SHARED_LOOP:
		  cerr << "initializer for enclosing-class instance constant `"
		       << property << "' and covergroup `" << covergroup
		       << "' constructor call may not appear in the same looping "
			  "statement (IEEE 1800 19.5).";
		  break;
		case PFORM_CTOR_ORDER_SHARED_JOIN_NONE:
		  cerr << "initializer for enclosing-class instance constant `"
		       << property << "' and covergroup `" << covergroup
		       << "' constructor call may not appear in the same "
			  "fork-join_none statement (IEEE 1800 19.5).";
		  break;
		case PFORM_CTOR_ORDER_REASSIGNMENT:
		  cerr << "instance constant `" << property
		       << "' can be assigned only once along every reachable path "
			  "through its corresponding class constructor "
			  "(IEEE 1800 8.19).";
		  break;
	    }
	    cerr << endl;
	    des->errors += 1;

	    if (violation.initializer_site
		&& (violation.kind == PFORM_CTOR_ORDER_SHARED_LOOP
		    || violation.kind == PFORM_CTOR_ORDER_SHARED_JOIN_NONE))
		  cerr << violation.initializer_site->get_fileline()
		       << ": note: instance constant initializer is here." << endl;
	    if (violation.reference_site)
		  cerr << violation.reference_site->get_fileline()
		       << ": note: covergroup expression reference is here." << endl;
      }
}

void netclass_t::elaborate_sig(Design*des, PClass*pclass)
{
      if (sig_elaborated_ || sig_elaborating_)
	    return;
      sig_elaborating_ = true;

	// Ensure the super-class is sig-elaborated BEFORE we process our own
	// properties.  elaborate_sig_classes() iterates a std::map<perm_string,...>
	// in alphabetical order, so a derived class (e.g. uvm_sequence_item) may
	// be processed before its base class (e.g. uvm_transaction).  If the base
	// class hasn't been elaborated yet, super_->get_properties() returns 0 and
	// the compile-time property index assigned to each derived-class property
	// will be wrong.  The resulting VVP %prop/v indices won't match the runtime
	// class layout, causing type/width mismatches at run time.
      if (super_ && !super_->sig_elaborated() && !super_->sig_elaborating()) {
	    const NetScope*super_scope = super_->class_scope();
	    const PClass*super_pclass = super_scope ? super_scope->class_pform() : nullptr;
	    if (super_pclass)
		  const_cast<netclass_t*>(super_)->elaborate_sig(des,
					    const_cast<PClass*>(super_pclass));
      }

      for (const netclass_t*interface_type : interface_types_) {
	    if (!interface_type || interface_type->sig_elaborated()
		|| interface_type->sig_elaborating())
		  continue;
	    const NetScope*interface_scope = interface_type->class_scope();
	    const PClass*interface_pclass = interface_scope
		  ? interface_scope->class_pform() : 0;
	    if (interface_pclass)
		  const_cast<netclass_t*>(interface_type)->elaborate_sig(
			des, const_cast<PClass*>(interface_pclass));
      }

      validate_external_class_constraints_(des, pclass);
      validate_interface_class_items_(des, pclass);

	// IEEE 1800-2017 8.20: a method that overrides an inherited virtual
	// method is itself virtual, whether or not the declaration repeats
	// the keyword. The pform flag only records an explicit keyword (or
	// an extern prototype's), so walk the super chain here -- supers are
	// sig-elaborated first, so their own implicit flags are already
	// settled -- and mark keyword-less overrides. Without this, codegen
	// emitted a NON-dispatching call for such an override: combined with
	// the sole-override static binding below (resolve_method_call_scope),
	// EVERY receiver of the base method -- including base-class objects
	// that must run the base body -- ran the derived body with a
	// wrong-class `this'. One user component overriding a UVM
	// runtime-schedule task-phase hook without the keyword sent uvm_root
	// through the override; the first property access then read a
	// wrong-width value and aborted vvp (vvp_vector4_t::add).
      if (super_ && class_scope_) {
	    for (auto&kv : class_scope_->children()) {
		  NetScope*method = kv.second;
		  if (!method)
			continue;
		  if (method->type() != NetScope::TASK
		      && method->type() != NetScope::FUNC)
			continue;
		  if (method->is_virtual_method())
			continue;
		  NetScope*sup = super_->method_from_name(kv.first.peek_name());
		  if (sup && sup->type() == method->type()
		      && sup->is_virtual_method())
			method->is_virtual_method(true);
	    }
      }

	// Collect the properties, elaborate them, and add them to the
	// elaborated class definition.
      for (std::vector<perm_string>::const_iterator name_it =
                  pclass->type->property_order.begin()
             ; name_it != pclass->type->property_order.end() ; ++name_it) {
            map<perm_string,struct class_type_t::prop_info_t>::iterator cur =
                  pclass->type->properties.find(*name_it);
            ivl_assert(*pclass, cur != pclass->type->properties.end());

	    ivl_type_t use_type = elaborate_class_property_type_(
		  des, class_scope_, cur->second.type.get(), true);
	    if (const char*trace = getenv("IVL_NESTED_PATH_TRACE")) {
		  if (cur->first == perm_string::literal("m_time_settings")
		      || cur->first == perm_string::literal("m_verbosity_settings")
		      || cur->first == perm_string::literal("m_regs_info")
		      || cur->first == perm_string::literal("m_mems_info")) {
			cerr << pclass->get_fileline() << ": debug: "
			     << "elaborate_sig trace=" << trace
			     << " class=" << get_name()
			     << " prop=" << cur->first
			     << " type=";
			if (use_type)
			      use_type->debug_dump(cerr);
			else
			      cerr << "<null>";
			cerr << endl;
		  }
	    }
	    if (debug_scopes) {
		  cerr << pclass->get_fileline() << ": elaborate_scope_class: "
		       << "  Property " << cur->first
		       << " type=" << *use_type << endl;
	    }

	      // real/shortreal, string, and chandle are not randomizable
	      // leaves for either qualifier. Class handles and unpacked
	      // structures, however, are legal recursive `rand` properties;
	      // the narrower integral-leaf rule for `randc` is checked below.
	      // `event` never reaches this loop because the parser diagnoses
	      // its qualifier in the class-item rule.
	    bool bad_type = false;
	    if (cur->second.qual.test_rand() || cur->second.qual.test_randc()) {
		  ivl_type_t elem_type = use_type;
		  while (elem_type) {
			const netarray_t*arr = dynamic_cast<const netarray_t*>(elem_type);
			if (!arr) break;
			elem_type = arr->element_type();
		  }
		  const char*what = 0;
		  if (elem_type == &netreal_t::type_real
		      || elem_type == &netreal_t::type_shortreal
		      || (elem_type && elem_type->base_type() == IVL_VT_REAL)) {
			bad_type = true; what = "real/shortreal";
		  } else if (elem_type == &netstring_t::type_string
			     || (elem_type && elem_type->base_type() == IVL_VT_STRING)) {
			bad_type = true; what = "string";
		  } else if (elem_type == &netvector_t::chandle_type) {
			bad_type = true; what = "chandle";
		  }
		  if (bad_type) {
			cerr << cur->second.get_fileline() << ": error: property '"
			     << cur->first << "' of class " << get_name()
			     << " is declared " << (cur->second.qual.test_randc() ? "randc" : "rand")
			     << " but has type " << what << ", which is not an "
			     << "integral type (IEEE 1800-2017 18.4 restricts "
			     << "rand/randc to 2-state/4-state types, enums, and "
			     << "aggregates thereof)." << endl;
				des->errors += 1;
			  }
	    }

	      // A randc declaration denotes one cycle over an integral, enum,
	      // or packed-aggregate leaf, or an unpacked container composed of
	      // those leaves. In particular, a class handle or unpacked struct
	      // (including either beneath nested arrays) is legal for rand but
	      // not randc. Diagnose the declaration once, after complete type
	      // elaboration, instead of once per nested array/member.
	    if (!bad_type && cur->second.qual.test_randc() && use_type
		&& !class_randc_property_type_ok_(use_type)) {
		  bad_type = true;
		  cerr << cur->second.get_fileline() << ": error: property '"
		       << cur->first << "' of class " << get_name()
		       << " has a type that is not valid for a randc property; "
		       << "randc requires an integral, enum, or packed-aggregate "
		       << "leaf, or an array thereof (IEEE 1800-2017 18.4)."
		       << endl;
		  des->errors += 1;
	    }

	      // C1 (Phase 62a) capped randc's cycle bitmap at a 16-bit
	      // width (2^16 entries) and silently degraded anything wider
	      // to plain (non-cyclic) rand -- no diagnostic at all. The cap
	      // is now 20 bits (2^20-entry bitmap, 128KB: vvp/vvp_cobject.cc
	      // randc_period() -- keep this bound in sync with that one),
	      // but the same silent-degrade risk exists beyond THAT bound,
	      // so name it here instead of letting it pass quietly.
	    if (!bad_type && cur->second.qual.test_randc() && use_type) {
	      long pw = class_randc_property_leaf_width_(use_type);
	      const long randc_cap_bits = 20;
	      if (pw > randc_cap_bits) {
		cerr << cur->second.get_fileline() << ": warning: randc property '"
			     << cur->first << "' of class " << get_name()
			     << " has a " << pw << "-bit cyclic leaf, beyond the "
			     << randc_cap_bits << "-bit randc cycle-tracking cap; "
			     << "it will randomize as plain (non-cyclic) rand instead "
			     << "of guaranteeing a full permutation before any repeat."
			     << endl;
		  }
	    }

	    perm_string interface_modport =
		  pform_interface_modport(
			des, class_scope_, cur->second.type.get());
	    set_property(cur->first, cur->second.qual, use_type,
			 interface_modport, cur->second.has_decl_initializer);

	    if (! cur->second.qual.test_static())
		  continue;

	    if (debug_elaborate) {
		  cerr << pclass->get_fileline() << ": netclass_t::elaborate_sig: "
		       << "Elaborate static property " << cur->first
		       << " as signal in scope " << scope_path(class_scope_)
		       << "." << endl;
	    }

	    NetNet*static_sig = class_scope_->find_signal(cur->first);
	    if (static_sig == 0) {
		    // A static property is a real signal in the class
		    // scope. A FIXED-ARRAY property must be created with
		    // its unpacked dimensions -- the type-only NetNet
		    // constructor makes a single-word signal, so the
		    // variable reached the runtime as a scalar while
		    // codegen addressed it as an array: every element
		    // store failed at runtime ("unresolved %store/vec4a")
		    // and reads came back zero with exit status 0
		    // (recovery D9 family).
		  if (const netuarray_t*ua =
			    dynamic_cast<const netuarray_t*>(use_type)) {
			static_sig = new NetNet(class_scope_, cur->first, NetNet::REG,
					ua->static_dimensions(),
					ua->element_type());
		  } else {
			static_sig = new NetNet(class_scope_, cur->first, NetNet::REG,
					use_type);
		  }
	    }
	    if (!interface_modport.nil())
		  static_sig->attribute(perm_string::literal("ivl_modport"),
				verinum(std::string(interface_modport.str())));
	    static_sig->set_const(cur->second.qual.test_const());
      }

      // Synthesize properties for class-embedded covergroups so they are
      // visible inside the constructor (new()) when it is elaborated.
      // This must happen before function body elaboration, which may be
      // triggered lazily by PENew before netclass_t::elaborate() has run.
      map<size_t,const netclass_t*> embedded_covergroups;
      for (auto* cgdef : pclass->type->covergroups) {
	    if (!cgdef) continue;
	    bool standalone = pclass->type->is_covergroup_standalone;
	    netclass_t*cg_class = standalone ? this : nullptr;
	    if (!standalone) {
		  int existing = property_idx_from_name(cgdef->name);
		  if (existing >= 0)
			cg_class = const_cast<netclass_t*>(
			      dynamic_cast<const netclass_t*>(
				    get_prop_type((size_t)existing)));
		  if (!cg_class) {
			string cg_cname = string("__covgrp_")
				      + string(name_.str())
				      + "_" + string(cgdef->name.str()) + "_t";
			perm_string cg_class_pname =
			      lex_strings.make(cg_cname.c_str());
			cg_class = new netclass_t(cg_class_pname, nullptr);
			cg_class->set_scope_ready(true);
			cg_class->set_body_elaborated(true);
			cg_class->set_is_covergroup(true);
			set_property(cgdef->name,
				     property_qualifier_t::make_none(), cg_class);
		  }
	    }
	    bind_covergroup_ranges_(des, this, cg_class, cgdef, standalone);
	    if (!standalone && cg_class) {
		  int cg_property = property_idx_from_name(cgdef->name);
		  if (cg_property >= 0)
			embedded_covergroups[static_cast<size_t>(cg_property)] =
			      cg_class;
	    }
      }

      // A `new' expression can lazily enter PFunction::elaborate before
      // netclass_t::elaborate.  Audit the unlowered constructor here, after
      // all covergroup dependency metadata is stable and before function
      // signatures or bodies can be elaborated.
      map<perm_string,PFunction*>::const_iterator constructor =
	    pclass->funcs.find(perm_string::literal("new"));
      if (constructor == pclass->funcs.end())
	    constructor = pclass->funcs.find(perm_string::literal("new@"));
      const PFunction*constructor_function =
	    constructor == pclass->funcs.end() ? nullptr : constructor->second;
      const Statement*constructor_body = constructor_function
	    ? constructor_function->get_statement() : nullptr;
      covergroup_constructor_order_classifier_t classifier(
	    this, constructor_function, embedded_covergroups);
      set<size_t> initially_initialized;
      const netclass_t*super = get_super();
      if (super && super->constructor_initialization_audited())
	    initially_initialized =
		  super->constructor_definitely_initialized();

      pform_constructor_order_result_t order =
	    audit_pform_constructor_order(constructor_body, classifier,
				      initially_initialized);
      set_constructor_initializer_sites(
	    order.authorized_instance_constant_initializers,
	    order.rejected_instance_constant_initializers,
	    order.instance_constant_initializer_properties);
      report_constructor_order_violations_(des, this, order);
      if (order.has_reachable_exit)
	    set_constructor_definitely_initialized(
		  order.definitely_initialized_at_exit);
      else
	    set_constructor_definitely_initialized(set<size_t>());

      for (map<perm_string,PFunction*>::iterator cur = pclass->funcs.begin()
		 ; cur != pclass->funcs.end() ; ++ cur) {
	    if (debug_elaborate) {
		  cerr << cur->second->get_fileline() << ": netclass_t::elaborate_sig: "
		       << "Elaborate signals in function method " << cur->first << endl;
	    }

	    NetScope*scope = class_scope_->child( hname_t(cur->first) );
	    ivl_assert(*cur->second, scope);
	    cur->second->elaborate_sig(des, scope);
      }

      for (map<perm_string,PTask*>::iterator cur = pclass->tasks.begin()
		 ; cur != pclass->tasks.end() ; ++ cur) {
	    if (debug_elaborate) {
		  cerr << cur->second->get_fileline() << ": netclass_t::elaborate_sig: "
		       << "Elaborate signals in task method " << cur->first << endl;
	    }

	    NetScope*scope = class_scope_->child( hname_t(cur->first) );
	    ivl_assert(*cur->second, scope);
	    cur->second->elaborate_sig(des, scope);
      }

      class_scope_->elaborate_nettypes(des);

      validate_interface_class_relations_(des, this, pclass);

      elaborate_sig_required_typedefs_(des, class_scope_, pclass->typedefs);

      /* Parameterized class specializations are allowed to keep method
	 bodies lazy, but constraints are part of the class type and must be
	 emitted for every specialization. Property and method signature types
	 are now final, so parameter references lower against the exact scope. */
      if (specialized_instance())
	    elaborate_constraints(des, pclass);

      sig_elaborating_ = false;
      sig_elaborated_ = true;
}

bool PGate::elaborate_sig(Design*, NetScope*) const
{
      return true;
}

bool PGModule::elaborate_sig_mod_(Design*des, NetScope*scope,
				  const Module*rmod) const
{
      bool flag = true;

      NetScope::scope_vec_t instance = scope->instance_arrays[get_name()];

      for (unsigned idx = 0 ;  idx < instance.size() ;  idx += 1) {
	      // I know a priori that the elaborate_scope created the scope
	      // already, so just look it up as a child of the current scope.
	    NetScope*my_scope = instance[idx];
	    ivl_assert(*this, my_scope);

	    if (my_scope->parent() != scope) {
		  cerr << get_fileline() << ": internal error: "
		       << "Instance " << scope_path(my_scope)
		       << " is in parent " << scope_path(my_scope->parent())
		       << " instead of " << scope_path(scope)
		       << endl;
	    }
	    ivl_assert(*this, my_scope->parent() == scope);

	    if (! rmod->elaborate_sig(des, my_scope))
		  flag = false;

      }

      return flag;
}

	// Not currently used.
#if 0
bool PGModule::elaborate_sig_udp_(Design*des, NetScope*scope, PUdp*udp) const
{
      return true;
}
#endif

bool PGenerate::elaborate_sig(Design*des,  NetScope*container) const
{
      if (directly_nested)
	    return elaborate_sig_direct_(des, container);

      bool flag = true;

	// Handle the special case that this is a CASE scheme. In this
	// case the PGenerate itself does not have the generated
	// item. Look instead for the case ITEM that has a scope
	// generated for it.
      if (scheme_type == PGenerate::GS_CASE) {
	    if (debug_elaborate)
		  cerr << get_fileline() << ": debug: generate case"
		       << " elaborate_sig in scope "
		       << scope_path(container) << "." << endl;

	    typedef list<PGenerate*>::const_iterator generate_it_t;
	    for (generate_it_t cur = generate_schemes.begin()
		       ; cur != generate_schemes.end() ; ++ cur ) {
		  PGenerate*item = *cur;
		  if (item->directly_nested || !item->scope_list_.empty()) {
			flag &= item->elaborate_sig(des, container);
		  }
	    }
	    return flag;
      }

      typedef list<NetScope*>::const_iterator scope_list_it_t;
      for (scope_list_it_t cur = scope_list_.begin()
		 ; cur != scope_list_.end() ; ++ cur ) {

	    NetScope*scope = *cur;

	    if (scope->parent() != container)
		  continue;

	    if (debug_elaborate)
		  cerr << get_fileline() << ": debug: Elaborate nets in "
		       << "scope " << scope_path(*cur)
		       << " in generate " << id_number << endl;
	    flag &= elaborate_sig_(des, *cur) && flag;
      }

      return flag;
}

bool PGenerate::elaborate_sig_direct_(Design*des, NetScope*container) const
{
      if (debug_elaborate)
	    cerr << get_fileline() << ": debug: "
		 << "Direct nesting " << scope_name
		 << " (scheme_type=" << scheme_type << ")"
		 << " elaborate_sig in scope "
		 << scope_path(container) << "." << endl;

	// Elaborate_sig for a direct nested generated scheme knows
	// that there are only sub_schemes to be elaborated.  There
	// should be exactly 1 active generate scheme, search for it
	// using this loop.
      bool flag = true;
      typedef list<PGenerate*>::const_iterator generate_it_t;
      for (generate_it_t cur = generate_schemes.begin()
		 ; cur != generate_schemes.end() ; ++ cur ) {
	    PGenerate*item = *cur;
	    if (item->scheme_type == PGenerate::GS_CASE) {
		  for (generate_it_t icur = item->generate_schemes.begin()
			     ; icur != item->generate_schemes.end() ; ++ icur ) {
			PGenerate*case_item = *icur;
			if (case_item->directly_nested || !case_item->scope_list_.empty()) {
			      flag &= case_item->elaborate_sig(des, container);
			}
		  }
	    } else {
		  if (item->directly_nested || !item->scope_list_.empty()) {
			  // Found the item, and it is direct nested.
			flag &= item->elaborate_sig(des, container);
		  }
	    }
      }
      return flag;
}

bool PGenerate::elaborate_sig_(Design*des, NetScope*scope) const
{
	// Scan the declared PWires to elaborate the obvious signals
	// in the current scope.
      bool flag = true;
      typedef map<perm_string,PWire*>::const_iterator wires_it_t;
      for (wires_it_t wt = wires.begin()
		 ; wt != wires.end() ; ++ wt ) {

	    PWire*cur = (*wt).second;

	    if (debug_elaborate)
		  cerr << get_fileline() << ": debug: Elaborate PWire "
		       << cur->basename() << " in scope " << scope_path(scope) << endl;

	    const NetNet* res = cur->elaborate_sig(des, scope);
	    flag &= (res != nullptr);
      }

      elaborate_sig_funcs(des, scope, funcs);
      elaborate_sig_tasks(des, scope, tasks);
      scope->elaborate_nettypes(des);

      typedef list<PGenerate*>::const_iterator generate_it_t;
      for (generate_it_t cur = generate_schemes.begin()
		 ; cur != generate_schemes.end() ; ++ cur ) {
	    flag &= (*cur)->elaborate_sig(des, scope);
      }

      typedef list<PGate*>::const_iterator pgate_list_it_t;
      for (pgate_list_it_t cur = gates.begin()
		 ; cur != gates.end() ; ++ cur ) {
	    flag &= (*cur)->elaborate_sig(des, scope);
      }

      typedef list<PProcess*>::const_iterator proc_it_t;
      for (proc_it_t cur = behaviors.begin()
		 ; cur != behaviors.end() ; ++ cur ) {
	    (*cur)->statement()->elaborate_sig(des, scope);
      }

      elaborate_sig_required_typedefs_(des, scope, typedefs);


      return flag;
}

// Seed all inherited properties into the super chain, bottom-up, before
// seeding the derived class.  This ensures that when a method body is
// compiled the super-class property count is already stable, so
// property_idx_from_name() returns the correct absolute index.
static void seed_super_chain_properties_(Design*des, const netclass_t*cls)
{
      if (!cls) return;
      const netclass_t*super = cls->get_super();
      if (!super) return;

      // Recurse: seed the grandparent chain first.
      seed_super_chain_properties_(des, super);

      const NetScope*super_scope = super->class_scope();
      if (!super_scope) return;
      const PClass*super_pclass = super_scope->class_pform();
      if (!super_pclass || !super_pclass->type) return;

      netclass_t*super_mut = const_cast<netclass_t*>(super);
      NetScope*super_scope_mut = const_cast<NetScope*>(super_scope);

      for (map<perm_string,struct class_type_t::prop_info_t>::const_iterator
		 cur = super_pclass->type->properties.begin()
	       ; cur != super_pclass->type->properties.end() ; ++cur) {
	    ivl_type_t use_type = elaborate_class_property_type_(
		  des, super_scope_mut, cur->second.type.get());
	    if (!use_type) continue;
	    perm_string interface_modport =
		  pform_interface_modport(
			des, super_scope_mut, cur->second.type.get());
	    super_mut->set_property(cur->first, cur->second.qual, use_type,
				    interface_modport,
				    cur->second.has_decl_initializer);
	    if (cur->second.qual.test_static()) {
		  NetNet*sig = super_scope_mut->find_signal(cur->first);
		if (sig == 0)
		      sig = new NetNet(super_scope_mut, cur->first,
					 NetNet::REG, use_type);
		if (!interface_modport.nil())
		      sig->attribute(perm_string::literal("ivl_modport"),
				     verinum(std::string(interface_modport.str())));
		  sig->set_const(cur->second.qual.test_const());
	    }
      }
}

static void seed_class_scope_properties_for_method_elab_(Design*des,
							 NetScope*scope,
							 const PTaskFunc*ptf,
							 const data_type_t*ctor_return_type)
{
      if (!gn_system_verilog())
	    return;

      NetScope*class_scope = scope ? scope->parent() : 0;
      if (!class_scope || class_scope->type() != NetScope::CLASS)
	    return;

      netclass_t*clsnet = const_cast<netclass_t*>(class_scope->class_def());
      if (!clsnet)
	    return;

      const class_type_t*pclass_type = ptf ? ptf->method_of() : 0;
      if (!pclass_type) {
	    if (const PClass*pclass = class_scope->class_pform())
		  pclass_type = pclass->type;
      }
      if (!pclass_type && ctor_return_type)
	    pclass_type = dynamic_cast<const class_type_t*>(ctor_return_type);
      if (!pclass_type)
	    return;

	// Before seeding this class's own properties, ensure the entire
	// super-class chain has its properties seeded.  This guarantees that
	// super_->get_properties() returns the correct count when
	// property_idx_from_name() is called during the method body
	// elaboration that follows immediately after this function returns.
      seed_super_chain_properties_(des, clsnet);

      for (map<perm_string,struct class_type_t::prop_info_t>::const_iterator
		 cur = pclass_type->properties.begin()
	       ; cur != pclass_type->properties.end() ; ++ cur) {
	    ivl_type_t use_type = elaborate_class_property_type_(
		  des, class_scope, cur->second.type.get());
	    perm_string interface_modport =
		  pform_interface_modport(
			des, class_scope, cur->second.type.get());
	    clsnet->set_property(cur->first, cur->second.qual, use_type,
				 interface_modport,
				 cur->second.has_decl_initializer);
	    if (cur->second.qual.test_static()) {
		  NetNet*sig = class_scope->find_signal(cur->first);
		if (sig == 0)
		      sig = new NetNet(class_scope, cur->first,
					 NetNet::REG, use_type);
		if (!interface_modport.nil())
		      sig->attribute(perm_string::literal("ivl_modport"),
				     verinum(std::string(interface_modport.str())));
		  sig->set_const(cur->second.qual.test_const());
	    }
      }
}


/*
 * A function definition exists within an elaborated module. This
 * matters when elaborating signals, as the ports of the function are
 * created as signals/variables for each instance of the
 * function. That is why PFunction has an elaborate_sig method.
 */
void PFunction::elaborate_sig(Design*des, NetScope*scope) const
{
      const char*func_sig_trace = getenv("IVL_FUNC_SIG_TRACE");
      std::ostringstream trace_scope_path;
      trace_scope_path << scope_path(scope);
      bool trace_func_sig = func_sig_trace && *func_sig_trace
			 && strstr(trace_scope_path.str().c_str(), func_sig_trace);
      if (trace_func_sig) {
	    cerr << get_fileline() << ": trace func-sig enter"
		 << " scope=" << trace_scope_path.str()
		 << " elab_stage=" << scope->elab_stage()
		 << " func_def=" << (const void*)scope->func_def()
		 << " return_pf=";
	    if (return_type_)
		  cerr << *return_type_;
	    else
		  cerr << "<null>";
	    cerr << endl;
      }

      bool can_resume_missing_void_sig =
	    scope->elab_stage() > 1
	 && !scope->func_def()
	 && return_type_
	 && dynamic_cast<const struct void_type_t*>(return_type_);

      if (scope->elab_stage() > 1 && !can_resume_missing_void_sig)
            return;

      if (scope->elab_stage() < 2)
            scope->set_elab_stage(2);

      perm_string fname = scope->basename();
      ivl_assert(*this, scope->type() == NetScope::FUNC);

      const char*uvm_cb_trace = getenv("IVL_UVM_CB_SIG_TRACE");
      const netclass_t*method_owner = scope->parent() ? scope->parent()->class_def() : 0;
      bool trace_uvm_cb_sig = uvm_cb_trace
                           && method_owner
                           && method_owner->class_scope()
                           && method_owner->class_scope()->class_pform()
                           && method_owner->class_scope()->class_pform()->type
                           && (method_owner->class_scope()->class_pform()->type->name
                               == perm_string::literal("uvm_callbacks")
                            || method_owner->class_scope()->class_pform()->type->name
                               == perm_string::literal("uvm_typed_callbacks"));
      if (trace_uvm_cb_sig) {
            ivl_type_t cb_type = 0;
            ivl_type_t t_type = 0;
            scope->parent()->get_parameter(des, perm_string::literal("CB"), cb_type);
            scope->parent()->get_parameter(des, perm_string::literal("T"), t_type);
            cerr << get_fileline() << ": trace: uvm_cb_sig scope=" << scope_path(scope)
                 << " owner=" << scope_path(scope->parent())
                 << " method=" << fname
                 << " T=";
            if (t_type) t_type->debug_dump(cerr); else cerr << "<null>";
            cerr << " CB=";
            if (cb_type) cb_type->debug_dump(cerr); else cerr << "<null>";
            if (return_type_) {
                  cerr << " return_pf=`" << *return_type_ << "`";
            } else {
                  cerr << " return_pf=<null>";
            }
            cerr << endl;
      }

      seed_class_scope_properties_for_method_elab_(des, scope, this,
						   (fname == perm_string::literal("new")
						    || fname == perm_string::literal("new@"))
						     ? return_type_ : 0);

      elaborate_sig_wires_(des, scope);

      NetNet*ret_sig;
      if (gn_system_verilog() && (fname=="new" || fname=="new@")) {
	      // Special case: this is a constructor, so the return
	      // signal is also the first argument. For example, the
	      // source code for the definition may be:
	      //   function new(...);
	      //   endfunction
	      // In this case, the "@" port (THIS_TOKEN) is the synthetic
	      // "this" argument and we also use it as a return value at
	      // the same time.
	    static bool warned_ctor_missing_this_void = false;
	    ret_sig = scope->find_signal(perm_string::literal(THIS_TOKEN));
	    if (!ret_sig) {
		  const netclass_t*cls_type = scope->parent() ? scope->parent()->class_def() : 0;
		  if (cls_type) {
			/* Compile-progress fallback: if the hidden constructor
			 * "this" signal is missing, synthesize it for name lookup
			 * and keep constructor return bound to "this". */
			NetNet*this_sig = new NetNet(scope, perm_string::literal(THIS_TOKEN),
						     NetNet::REG, cls_type);
			this_sig->set_line(*this);
			this_sig->port_type(NetNet::PINPUT);
			ret_sig = this_sig;
		  } else {
			if (!warned_ctor_missing_this_void) {
			      cerr << get_fileline() << ": warning: constructor missing synthetic "
			           << "\"this\" port and class return type; using void fallback."
				           << " (suppressing further similar warnings)" << endl;
				      warned_ctor_missing_this_void = true;
				}
			  }
		    }

	    if (debug_elaborate)
		  cerr << get_fileline() << ": PFunction::elaborate_sig: "
		       << "Scope " << scope_path(scope)
		       << " is a CONSTRUCTOR, so use \"this\" argument"
		       << " as return value." << endl;

      } else {
	    ivl_type_t ret_type;
	    NetScope*ret_scope = scope->parent() ? scope->parent() : scope;

	    if (return_type_) {
		  if (dynamic_cast<const struct void_type_t*> (return_type_)) {
			ret_type = 0;
		  } else {
			ret_type = return_type_->elaborate_type(des, ret_scope);
			if (ivl_type_t class_ret_type =
			    resolve_class_handle_type_weak_(des, ret_scope, return_type_)) {
			      /* Parameterized class methods can arrive here with
			       * the generic/default scalar return elaborated first.
			       * Prefer the resolved class handle when available so
			       * method bodies and callers use object-return lowering. */
			      ret_type = class_ret_type;
			} else if (ivl_type_t placeholder_ret_type =
				   resolve_class_handle_placeholder_type_weak_(des, ret_scope,
								 return_type_)) {
			      /* Some specialized factory/helper methods still see the
			       * type parameter only as a placeholder during the first
			       * return-signal pass. Keep the return signal object-typed
			       * so later lowering does not degrade it to a scalar. */
			      ret_type = placeholder_ret_type;
				}
				ivl_assert(*this, ret_type);
				if ((is_dpi_import() || is_dpi_export())
				    && !dpi_function_result_type_allowed_(ret_type)) {
				      cerr << get_fileline() << ": error: DPI function result "
				           << "type is not permitted by IEEE 1800 Annex H.8.9; "
				           << "use void, an integer atom, scalar bit/logic, "
				           << "shortreal, real, chandle, or string." << endl;
				      des->errors += 1;
				}
			  }
	    } else {
		  const netvector_t*tmp = new netvector_t(IVL_VT_LOGIC);
		  ret_type = tmp;
	    }

	    if (ret_type) {
		  if (trace_uvm_cb_sig) {
			cerr << get_fileline() << ": trace: uvm_cb_sig return scope="
			     << scope_path(scope) << " method=" << fname << " ret_type=";
			ret_type->debug_dump(cerr);
			cerr << endl;
		  }
		  if (ret_type->base_type() == IVL_VT_NO_TYPE
		      && dynamic_cast<const netstruct_t*>(ret_type) == 0) {
			cerr << get_fileline() << ": internal debug: "
			     << "function " << scope_path(scope)
			     << " elaborated unresolved return type";
			if (return_type_)
			      cerr << " from `" << *return_type_ << "`";
			cerr << "." << endl;
		  }
		  if (debug_elaborate) {
			cerr << get_fileline() << ": PFunction::elaborate_sig: "
			     << "return type: " << *ret_type << endl;
			if (return_type_)
			      return_type_->pform_dump(cerr, 8);
		  }
		  if (const netuarray_t*ret_ua =
			dynamic_cast<const netuarray_t*>(ret_type)) {
			  // A function returning an unpacked array (issue
			  // #99): the return signal must be a real array --
			  // the NetNet needs its unpacked dimensions split
			  // out, else it degenerates to a scalar of array
			  // type, the body's element stores target an array
			  // that is never emitted, and callers see a 1-bit
			  // return. The function body stores the result into
			  // this array and the caller copies the words out
			  // after the call.
			ret_sig = new NetNet(scope, fname, NetNet::REG,
					     ret_ua->static_dimensions(),
					     ret_ua->element_type());
		  } else {
			ret_sig = new NetNet(scope, fname, NetNet::REG, ret_type);
		  }

		  ret_sig->set_line(*this);
		  ret_sig->port_type(NetNet::POUTPUT);
	    } else {
		  ret_sig = 0;
		  if (debug_elaborate) {
			cerr << get_fileline() << ": PFunction::elaborate_sig: "
			     << "Detected that function is void." << endl;
		  }
	    }
      }

      vector<NetNet*>ports;
      vector<NetExpr*>pdef;
      vector<perm_string> port_names;
      elaborate_sig_ports_(des, scope, ports, pdef, port_names);

      if (gn_system_verilog()
	  && ret_sig
	  && (fname == perm_string::literal("new")
	      || fname == perm_string::literal("new@"))
	  && ret_sig->name() == perm_string::literal(THIS_TOKEN)) {
	    bool have_this_port = !ports.empty()
			       && ports[0]
			       && ports[0]->name() == perm_string::literal(THIS_TOKEN);
	    if (!have_this_port) {
		  ports.insert(ports.begin(), ret_sig);
		  pdef.insert(pdef.begin(), 0);
		  port_names.insert(port_names.begin(), perm_string::literal(THIS_TOKEN));
	    }
      }

      NetFuncDef*def = scope->func_def();
      if (!def) {
	    def = new NetFuncDef(scope, ret_sig, ports, pdef);

	    if (debug_elaborate)
		  cerr << get_fileline() << ": PFunction::elaborate_sig: "
		       << "Attach function definition " << scope_path(scope)
		       << " with ret_sig width=" << (ret_sig? ret_sig->vector_width() : 0)
		       << "." << endl;

	    scope->set_func_def(def);
      }

      if (trace_func_sig) {
	    cerr << get_fileline() << ": trace func-sig exit"
		 << " scope=" << trace_scope_path.str()
		 << " elab_stage=" << scope->elab_stage()
		 << " func_def=" << (const void*)scope->func_def()
		 << " ret_sig=" << (const void*)ret_sig;
	    if (ret_sig)
		  cerr << " data_type=" << ret_sig->data_type()
		       << " width=" << ret_sig->vector_width();
	    cerr << endl;
      }

      scope->elaborate_nettypes(des);

	// Look for further signals in the sub-statement
      if (statement_)
	    statement_->elaborate_sig(des, scope);
}

/*
 * A task definition is a scope within an elaborated module. When we
 * are elaborating signals, the scopes have already been created, as
 * have the reg objects that are the parameters of this task. The
 * elaborate_sig method of PTask is therefore left to connect the
 * signals to the ports of the NetTaskDef definition. We know for
 * certain that signals exist (They are in my scope!) so the port
 * binding is sure to work.
 */
void PTask::elaborate_sig(Design*des, NetScope*scope) const
{
      ivl_assert(*this, scope->type() == NetScope::TASK);

      if (scope->elab_stage() > 1)
	    return;

      scope->set_elab_stage(2);

      seed_class_scope_properties_for_method_elab_(des, scope, this, 0);

      elaborate_sig_wires_(des, scope);

      vector<NetNet*>ports;
      vector<NetExpr*>pdefs;
      vector<perm_string> port_names;
      elaborate_sig_ports_(des, scope, ports, pdefs, port_names);
      NetTaskDef*def = new NetTaskDef(scope, ports, pdefs);
      scope->set_task_def(def);
      scope->elaborate_nettypes(des);

	// R25 (Option B, IEEE 1800-2017 13.5.2): a real/string/container
	// `ref' formal that is not bound as a real reference still takes
	// the copy-in/copy-out pair; if this task's own body contains a
	// detached fork (join_none/join_any) anywhere, a branch that
	// outlives the call can write the formal after the copy-out has
	// already run, and the write is lost silently. Flag it here, once
	// per (task, formal), regardless of how many places call this task.
      for (unsigned int idx = 0 ; idx < ports.size() ; idx += 1) {
	    NetNet*port = ports[idx];
	    if (port == 0 || port->port_type() != NetNet::PREF)
		  continue;
	    if (ref_formal_is_bound(port))
		  continue;
	    warn_ref_formal_fork_hazard(port, statement_);
      }

	// Look for further signals in the sub-statement
      if (statement_)
	    statement_->elaborate_sig(des, scope);
}

void PTaskFunc::elaborate_sig_ports_(Design*des, NetScope*scope,
				     vector<NetNet*> &ports,
				     vector<NetExpr*> &pdefs,
				     vector<perm_string> &port_names) const
{
      if (ports_ == 0) {
	    ports.clear();
	    pdefs.clear();
	    port_names.clear();

	      /* Make sure the function has at least one input
		 port. If it fails this test, print an error
		 message. Keep going so we can find more errors. */
	    if (scope->type()==NetScope::FUNC && !gn_system_verilog()) {
		  cerr << get_fileline() << ": error: "
		       << "Function " << scope->basename()
		       << " has no ports." << endl;
		  cerr << get_fileline() << ":      : "
		       << "Functions must have at least one input port." << endl;
		  des->errors += 1;
	    }

	    return;
      }

      ports.resize(ports_->size());
      pdefs.resize(ports_->size());
      port_names.resize(ports_->size());

      for (size_t idx = 0 ; idx < ports_->size() ; idx += 1) {

	    perm_string port_name = ports_->at(idx).port->basename();

	    ports[idx] = 0;
	    pdefs[idx] = 0;
	    NetNet*tmp = scope->find_signal(port_name);
	    NetExpr*tmp_def = 0;
	    if (tmp == 0) {
		  cerr << get_fileline() << ": internal error: "
		       << "task/function " << scope_path(scope)
		       << " is missing port " << port_name << "." << endl;
		  scope->dump(cerr);
		  cerr << get_fileline() << ": Continuing..." << endl;
		  des->errors += 1;
		  continue;
	    }

		      // If the port has a default expression, elaborate
		      // that expression here.
		    if (ports_->at(idx).defe != 0) {
			  if (tmp->port_type() == NetNet::PINPUT) {
				ivl_type_t formal_type = tmp->unpacked_dimensions() > 0
				      && tmp->array_type()
				      ? static_cast<ivl_type_t>(tmp->array_type())
				      : tmp->net_type();
				  // Accept the common SV/UVM pattern of class handle
				  // defaults set to null (e.g. constructor parent=null).
				if (tmp->data_type() == IVL_VT_CLASS
				    && dynamic_cast<const PENull*>(ports_->at(idx).defe)) {
				      NetENull*nval = new NetENull;
				      nval->set_line(*ports_->at(idx).defe);
				      tmp_def = nval;
				} else
				  // SV: {} (empty concat) as default for queue/darray port —
				  // synthesize a null placeholder (empty queue default).
				if ((tmp->data_type() == IVL_VT_QUEUE
				     || tmp->data_type() == IVL_VT_DARRAY)
				    && dynamic_cast<const PEConcat*>(ports_->at(idx).defe)
				    && static_cast<const PEConcat*>(ports_->at(idx).defe)->is_empty_concat()) {
				      NetENull*nval = new NetENull(tmp->net_type());
				      nval->set_line(*ports_->at(idx).defe);
				      tmp_def = nval;
				} else if (formal_type) {
				      /* IEEE 1800-2017 13.5.3: a default argument is an
				       * assignment-like context supplied by its formal. Use the
				       * ordinary r-value contextualizer here: integral formals
				       * need their packed width propagated into binary operands,
				       * while aggregate/container formals still take the full
				       * ivl_type_t path and its exact compatibility checks. Calling
				       * the generic typed elaborator for every type instead made
				       * its legacy vector fallback request width 1; an int enum
				       * expression such as (UVM_LOG | UVM_RM_RECORD) then had a
				       * 1-bit operator with 32-bit operands and aborted constant
				       * folding. */
				      tmp_def = elaborate_rval_expr(
					    des, scope, formal_type,
					    ports_->at(idx).defe,
					    scope->need_const_func());
				} else {
				      tmp_def = elab_and_eval(
					    des, scope, ports_->at(idx).defe, -1,
					    scope->need_const_func());
				}
			if (tmp_def == 0) {
			      cerr << get_fileline()
				   << ": error: Unable to evaluate "
				   << *ports_->at(idx).defe
				   << " as a port default expression." << endl;
			      des->errors += 1;
			}
		  } else {
			cerr << get_fileline() << ": sorry: Default arguments "
			        "for subroutine output or inout ports are not "
			        "yet supported." << endl;
			des->errors += 1;
		  }
	    }

	    if (tmp->port_type() == NetNet::NOT_A_PORT) {
		  cerr << get_fileline() << ": internal error: "
		       << "task/function " << scope_path(scope)
		       << " port " << port_name
		       << " is a port but is not a port?" << endl;
		  des->errors += 1;
		  scope->dump(cerr);
		  continue;
	    }

	    ports[idx] = tmp;
	    port_names[idx] = port_name;
	    pdefs[idx] = tmp_def;
	    if (scope->type()==NetScope::FUNC && tmp->port_type()!=NetNet::PINPUT) {
		  if (gn_system_verilog()) {
		  } else {
			cerr << tmp->get_fileline() << ": error: "
			     << "Function " << scope_path(scope)
			     << " port " << port_name
			     << " is not an input port." << endl;
			cerr << tmp->get_fileline() << ":      : "
			     << "Function arguments must be input ports." << endl;
			des->errors += 1;
		  }
	    }
	      // Fixed unpacked arrays use the ordinary subroutine
	      // copy-in/copy-out lowering for every direction. Keeping a
	      // declaration-time rejection here made legal output/inout/ref
	      // formals fail even though the caller retains the complete
	      // array type and the target already carries word-array stores.
      }
}

void PBlock::elaborate_sig(Design*des, NetScope*scope) const
{
      NetScope*my_scope = scope;

      if (pscope_name() != 0) {
	    hname_t use_name (pscope_name());
	    my_scope = scope->child(use_name);
	    if (my_scope == 0) {
		  cerr << get_fileline() << ": internal error: "
		       << "Unable to find child scope " << pscope_name()
		       << " in this context?" << endl;
		  des->errors += 1;
		  my_scope = scope;
	    } else {
		  if (debug_elaborate)
			cerr << get_fileline() << ": debug: "
			     << "elaborate_sig descending into "
			     << scope_path(my_scope) << "." << endl;

		  elaborate_sig_wires_(des, my_scope);
		  my_scope->elaborate_nettypes(des);
	    }
      }

	// elaborate_sig in the statements included in the
	// block. There may be named blocks in there.
      for (unsigned idx = 0 ;  idx < list_.size() ;  idx += 1)
	    list_[idx] -> elaborate_sig(des, my_scope);
}

void PRandCase::elaborate_sig(Design*des, NetScope*scope) const
{
      if (!items_)
	    return;
      for (PCase::Item*cur : *items_) {
	    if (cur && cur->stat)
		  cur->stat->elaborate_sig(des, scope);
      }
}

void PCase::elaborate_sig(Design*des, NetScope*scope) const
{
      if (items_ == 0)
	    return;

      for (unsigned idx = 0 ; idx < items_->size() ; idx += 1) {
	    if ( (*items_)[idx]->stat )
		  (*items_)[idx]->stat ->elaborate_sig(des,scope);
      }
}

void PCondit::elaborate_sig(Design*des, NetScope*scope) const
{
      if (if_)
	    if_->elaborate_sig(des, scope);
      if (else_)
	    else_->elaborate_sig(des, scope);
}

void PDelayStatement::elaborate_sig(Design*des, NetScope*scope) const
{
      if (statement_)
	    statement_->elaborate_sig(des, scope);
}

void PCycleDelay::elaborate_sig(Design*des, NetScope*scope) const
{
      if (statement_)
	    statement_->elaborate_sig(des, scope);
}

void PDoWhile::elaborate_sig(Design*des, NetScope*scope) const
{
      if (statement_)
	    statement_->elaborate_sig(des, scope);
}

void PEventStatement::elaborate_sig(Design*des, NetScope*scope) const
{
      if (statement_)
	    statement_->elaborate_sig(des, scope);
}

void PForeach::elaborate_sig(Design*des, NetScope*scope) const
{
      if (statement_)
	    statement_->elaborate_sig(des, scope);
}

void PForever::elaborate_sig(Design*des, NetScope*scope) const
{
      if (statement_)
	    statement_->elaborate_sig(des, scope);
}

void PForStatement::elaborate_sig(Design*des, NetScope*scope) const
{
      if (statement_)
	    statement_->elaborate_sig(des, scope);
}

void PRepeat::elaborate_sig(Design*des, NetScope*scope) const
{
      if (statement_)
	    statement_->elaborate_sig(des, scope);
}

void PWhile::elaborate_sig(Design*des, NetScope*scope) const
{
      if (statement_)
	    statement_->elaborate_sig(des, scope);
}

bool test_ranges_eeq(const netranges_t&lef, const netranges_t&rig)
{
      if (lef.size() != rig.size())
	    return false;

      netranges_t::const_iterator lcur = lef.begin();
      netranges_t::const_iterator rcur = rig.begin();
      while (lcur != lef.end()) {
	    if (lcur->get_msb() != rcur->get_msb())
		  return false;
	    if (lcur->get_lsb() != rcur->get_lsb())
		  return false;

	    ++ lcur;
	    ++ rcur;
      }

      return true;
}

ivl_type_t PWire::elaborate_type(Design*des, NetScope*scope,
			         const netranges_t &packed_dimensions) const
{
      if (const nettype_t*decl = user_nettype()) {
            NetNetType*info = scope->elaborate_nettype(des, decl);
            if (info && info->data_type()) {
                  if (!packed_dimensions.empty()) {
                        cerr << get_fileline() << ": error: signal '" << name_
                             << "' adds packed dimensions to user-defined "
                             << "nettype '" << decl->name() << "'." << endl;
                        des->errors += 1;
                  }
                  return info->data_type();
            }
      }

      const vector_type_t *vec_type = dynamic_cast<vector_type_t*>(set_data_type_.get());
      if (set_data_type_ && !vec_type) {
	    ivl_assert(*this, packed_dimensions.empty());
	    if (ivl_type_t class_type =
		      resolve_class_handle_type_weak_(des, scope,
					      set_data_type_.get()))
		  return class_type;
	    return set_data_type_->elaborate_type(des, scope);
      }

      // Fallback method. Create vector type.

      ivl_variable_type_t use_data_type;
      if (vec_type) {
	    use_data_type = vec_type->base_type;
      } else {
	    use_data_type = IVL_VT_LOGIC;
      }

      if (use_data_type == IVL_VT_NO_TYPE) {
	    use_data_type = IVL_VT_LOGIC;
	    if (debug_elaborate) {
		  cerr << get_fileline() << ": PWire::elaborate_sig: "
		       << "Signal " << name_
		       << " in scope " << scope_path(scope)
		       << " defaults to data type " << use_data_type << endl;
	    }
      }

      ivl_assert(*this, use_data_type == IVL_VT_LOGIC ||
			use_data_type == IVL_VT_BOOL);

      netvector_t*vec = new netvector_t(packed_dimensions, use_data_type);
      vec->set_signed(get_signed());

      return vec;
}

ivl_type_t PWire::elaborate_sig_type(Design*des, NetScope*scope) const
{
      netranges_t packed_dimensions;
      if (port_set_ || net_set_) {
	    bool dimensions_ok = true;
	    netranges_t plist, nlist;
	    if (port_set_ && !port_.empty())
		  dimensions_ok &= evaluate_ranges(des, scope, this, plist, port_);
	    if (net_set_ && !net_.empty() && dimensions_ok)
		  dimensions_ok &= evaluate_ranges(des, scope, this, nlist, net_);
	    packed_dimensions = net_set_ ? nlist : plist;
      }

      ivl_type_t type = elaborate_type(des, scope, packed_dimensions);
      return elaborate_array_type(des, scope, *this, type, unpacked_);
}

/*
 * Elaborate a source wire. The "wire" is the declaration of wires,
 * registers, ports and memories. The parser has already merged the
 * multiple properties of a wire (i.e., "input wire"), so come the
 * elaboration this creates an object in the design that represents the
 * defined item.
 */
NetNet* PWire::elaborate_sig(Design*des, NetScope*scope)
{
		// This sets the vector or array dimension size that will
		// cause a warning. For now, these warnings are permanently
		// enabled.
      const long warn_dimension_size = 1 << 30;

		// Check if we elaborated this signal earlier because it was
		// used in another declaration.
      if (NetNet*sig = scope->find_signal(name_))
            return sig;

	// IEEE 1800-2017/2023 25.9 forbids a virtual-interface variable
	// from being used as any module, interface, or program port. Ordinary
	// interface ports use the same eventual netclass representation, so
	// key this check to the preserved source-type provenance instead.
      const bool source_virtual_interface = set_data_type_
	    && pform_is_virtual_interface_type(set_data_type_.get());
      const bool resolved_virtual_interface = set_data_type_
	    && (source_virtual_interface || pform_is_virtual_interface_type(
		  des, scope, set_data_type_.get()));
      const NetScope*interface_item_scope = scope;
      while (interface_item_scope->type() == NetScope::GENBLOCK)
	    interface_item_scope = interface_item_scope->parent();
      if (scope->type() == NetScope::MODULE
	  && port_type_ != NetNet::NOT_A_PORT
	  && resolved_virtual_interface) {
	    cerr << get_fileline() << ": error: virtual interface variable `"
		 << name_ << "' shall not be used as a module, interface, or "
		 << "program port (IEEE 1800-2017/2023 25.9)." << endl;
	    des->errors += 1;
      }

	// Direct and typedef-led interface items are diagnosed during parsing.
	// A type parameter needs the concrete elaborated value before its
	// virtual-interface provenance is known, so catch that remaining form
	// in the instantiated interface or interface-generate scope without
	// duplicating the earlier diagnostic.
      if (interface_item_scope->type() == NetScope::MODULE
	  && interface_item_scope->is_interface()
	  && port_type_ == NetNet::NOT_A_PORT
	  && resolved_virtual_interface
	  && !virtual_interface_item_error_reported()) {
	    cerr << get_fileline() << ": error: virtual interface variable `"
		 << name_ << "' shall not be declared as an interface item "
		 << "(IEEE 1800-2017/2023 25.9)." << endl;
	    des->errors += 1;
      }

      NetNet::Type wtype = type_;
      if (wtype == NetNet::IMPLICIT)
	    wtype = NetNet::WIRE;
      if (wtype == NetNet::IMPLICIT_REG)
	    wtype = NetNet::REG;

      NetNetType*user_type = user_nettype()
            ? scope->elaborate_nettype(des, user_nettype()) : 0;
      /* A resolver-bearing user net is multiply driven by definition.  Keep
       * no-resolver UDNTs as UNRESOLVED_WIRE so the ordinary driver mask
       * enforces their single whole-net driver, but lower resolved UDNTs as a
       * resolved net and carry their resolver identity in NetNetType for the
       * target/runtime stream. */
      if (user_type && user_type->has_resolution_function())
            wtype = NetNet::WIRE;

      NetNet*sig = 0;
      bool sig_predeclared = false;
      if (set_data_type_ && port_.empty() && net_.empty() && unpacked_.empty()) {
	    if (ivl_type_t placeholder_type =
			resolve_class_handle_placeholder_type_weak_(des, scope,
							    set_data_type_.get())) {
		  sig = new NetNet(scope, name_, wtype, placeholder_type);
		  sig->set_line(*this);
		  sig->port_type(port_type_);
		  sig->lexical_pos(lexical_pos_);
		  sig->set_const(is_const_);
		  sig_predeclared = true;
	    }
      }

      if (is_elaborating_) {
	    if (sig_predeclared)
		  return sig;
		    cerr << get_fileline() << ": error: Circular dependency "
			    "detected in declaration of '" << name_ << "'."
			 << " scope=" << scope_path(scope) << endl;
		    des->errors += 1;
		    return 0;
      }
      is_elaborating_ = true;

		// Certain contexts, such as arguments to functions, presume
		// "reg" instead of "wire". The parser reports these as
		// IMPLICIT_REG.

      if (debug_elaborate) {
	    cerr << get_fileline() << ": PWire::elaborate_sig: "
		 << "Signal " << basename()
		 << ", wtype=" << wtype;
	    if (set_data_type_)
		  cerr << ", set_data_type_=" << *set_data_type_;
	    cerr << ", unpacked_.size()=" << unpacked_.size()
		 << endl;
      }

      unsigned wid = 1;
      netranges_t packed_dimensions;

      des->errors += error_cnt_;

      if (port_set_ || net_set_) {

	    if (warn_implicit_dimensions
		&& port_set_ && net_set_
		&& net_.empty() && !port_.empty()) {
		  cerr << get_fileline() << ": warning: "
		       << "var/net declaration of " << basename()
		       << " inherits dimensions from port declaration." << endl;
	    }

	    if (warn_implicit_dimensions
		&& port_set_ && net_set_
		&& port_.empty() && !net_.empty()) {
		  cerr << get_fileline() << ": warning: "
		       << "Port declaration of " << basename()
		       << " inherits dimensions from var/net." << endl;
	    }

	    bool dimensions_ok = true;
	    netranges_t plist, nlist;
	    /* If they exist get the port definition MSB and LSB */
	    if (port_set_ && !port_.empty()) {
		  if (debug_elaborate) {
			cerr << get_fileline() << ": PWire::elaborate_sig: "
			     << "Evaluate ranges for port " << basename() << endl;
		  }
		  dimensions_ok &= evaluate_ranges(des, scope, this, plist, port_);
	    }
            ivl_assert(*this, port_set_ || port_.empty());

	    /* If they exist get the net/etc. definition MSB and LSB */
	    if (net_set_ && !net_.empty() && dimensions_ok) {
		  nlist.clear();
		  if (debug_elaborate) {
			cerr << get_fileline() << ": PWire::elaborate_sig: "
			     << "Evaluate ranges for net " << basename() << endl;
		  }
		  dimensions_ok &= evaluate_ranges(des, scope, this, nlist, net_);
	    }
            ivl_assert(*this, net_set_ || net_.empty());

	    if (debug_elaborate) {
		  cerr << get_fileline() << ": PWire::elaborate_sig: "
		       << "Calculated ranges for " << basename()
		       << ". Now check for consistency." << endl;
	    }

	    /* We have a port size error. Skip this if the dimensions could not
	     * be evaluated since it will likely print nonsensical errors. */
            if (port_set_ && net_set_ && !test_ranges_eeq(plist, nlist) &&
	        dimensions_ok) {
		  /* Scalar port with a vector net/etc. definition */
		  if (port_.empty()) {
			if (gn_io_range_error_flag) {
			      cerr << get_fileline()
			           << ": error: Scalar port ``" << name_
			           << "'' has a vectored net declaration "
				   << nlist << "." << endl;
			      des->errors += 1;
			} else if (warn_anachronisms) {
			      cerr << get_fileline()
			           << ": warning: Scalar port ``" << name_
			           << "'' has a vectored net declaration "
				   << nlist << "." << endl;
			}
		  }

		  /* Vectored port with a scalar net/etc. definition */
		  if (net_.empty()) {
			cerr << port_.front().first->get_fileline()
			     << ": error: Vectored port ``"
			     << name_ << "'' " << plist
			     << " has a scalar net declaration at "
			     << get_fileline() << "." << endl;
			des->errors += 1;
		  }

		  /* Both vectored, but they have different ranges. */
		  if (!port_.empty() && !net_.empty()) {
			cerr << port_.front().first->get_fileline()
			     << ": error: Vectored port ``"
			     << name_ << "'' " << plist
			     << " has a net declaration " << nlist
			     << " at " << net_.front().first->get_fileline()
			     << " that does not match." << endl;
			des->errors += 1;
		  }
            }

	    packed_dimensions = net_set_ ? nlist : plist;
	    wid = netrange_width(packed_dimensions);
	    if (wid > warn_dimension_size) {
		  cerr << get_fileline() << ": warning: Vector size "
		          "is greater than " << warn_dimension_size
		       << "." << endl;
	    }
      }

      unsigned nattrib = 0;
      const attrib_list_t*attrib_list = evaluate_attributes(attributes, nattrib,
                                                            des, scope);

      if (!sig_predeclared && set_data_type_ && packed_dimensions.empty() && unpacked_.empty()) {
	    if (ivl_type_t placeholder_type =
			resolve_class_handle_placeholder_type_weak_(des, scope,
							    set_data_type_.get())) {
		  if (debug_elaborate) {
			cerr << get_fileline() << ": PWire::elaborate_sig: "
			     << "predeclare class-handle signal " << name_
			     << " with placeholder type " << *placeholder_type
			     << " in scope " << scope_path(scope) << endl;
		  }
		  sig = new NetNet(scope, name_, wtype, placeholder_type);
		  sig->set_line(*this);
		  sig->port_type(port_type_);
		  sig->lexical_pos(lexical_pos_);
		  sig->set_const(is_const_);
		  sig_predeclared = true;
	    }
      }

      ivl_type_t early_class_type = 0;
      if (set_data_type_ && packed_dimensions.empty() && unpacked_.empty()) {
	    early_class_type = resolve_class_handle_type_weak_(des, scope,
					       set_data_type_.get());
      }

      NetNet::Type declared_wtype = wtype;

	/* If the net type is supply0 or supply1, replace it
	   with a simple wire with a pulldown/pullup with supply
	   strength. In other words, transform:

	   supply0 foo;

	   to:

	   wire foo;
	   pulldown #(supply0) (foo);

	   This reduces the backend burden, and behaves exactly
	   the same. */

      NetLogic*pull = 0;
      if (wtype == NetNet::SUPPLY0 || wtype == NetNet::SUPPLY1) {
	    if (debug_elaborate) {
		  cerr << get_fileline() << ": debug: "
		       << "Generate a SUPPLY pull for the ";
		  if (wtype == NetNet::SUPPLY0) cerr << "supply0";
		  else cerr << "supply1";
		  cerr << " net." << endl;
	    }

	    NetLogic::TYPE pull_type = (wtype==NetNet::SUPPLY1)
		  ? NetLogic::PULLUP
		  : NetLogic::PULLDOWN;
	    pull = new NetLogic(scope, scope->local_symbol(),
				1, pull_type, wid);
	    pull->set_line(*this);
	    pull->pin(0).drive0(IVL_DR_SUPPLY);
	    pull->pin(0).drive1(IVL_DR_SUPPLY);
	    des->add_node(pull);
	    wtype = NetNet::WIRE;

      } else if (net_delay()
		 && (wtype == NetNet::TRI0 || wtype == NetNet::TRI1)) {
	    /* A delayed tri0/tri1 needs its default pull on the hidden raw
	     * resolver. Leaving the public signal typed TRI0/TRI1 would create
	     * an immediate second pull after the delay. Undelayed nets retain
	     * their declared target/VPI type; a port collapse canonicalizes their
	     * implicit pull only when nexus retyping is actually required. */
	    NetLogic::TYPE pull_type = (wtype == NetNet::TRI1)
		  ? NetLogic::PULLUP : NetLogic::PULLDOWN;
	    pull = new NetLogic(scope, scope->local_symbol(), 1,
				pull_type, wid);
	    pull->set_line(*this);
	    pull->pin(0).drive0(IVL_DR_PULL);
	    pull->pin(0).drive1(IVL_DR_PULL);
	    des->add_node(pull);
	    wtype = NetNet::TRI;
      }

	// M5-5: GENERIC interface port (`interface i` / `interface.mp
	// i`, IEEE 1800-2017 25.3.3): the concrete interface type comes
	// from the ACTUAL at each instantiation. Create the signal with
	// a placeholder type and mark it; the port-binding code in
	// PGModule elaboration retypes it from the connected instance
	// and binds the vif handle.
      bool generic_iface = false;
      perm_string generic_modport;
      if (const interface_type_t*git =
	    dynamic_cast<const interface_type_t*>(set_data_type_.get())) {
	    if (git->name.nil()) {
		  generic_iface = true;
		  generic_modport = git->modport;
	    }
      }
      if (generic_iface && wtype != NetNet::REG)
	    wtype = NetNet::REG;

      ivl_type_t type = generic_iface
		      ? (ivl_type_t)&netvector_t::atom2s32
		      : early_class_type
		      ? early_class_type
		      : elaborate_type(des, scope, packed_dimensions);
	// Create the type for the unpacked dimensions. If the
	// unpacked_dimensions are empty this will just return the base type.
      type = elaborate_array_type(des, scope, *this, type, unpacked_);

      netranges_t unpacked_dimensions;
	// If this is an unpacked array extract the base type and unpacked
	// dimensions as these are separate properties of the NetNet.
      while (const netuarray_t *atype = dynamic_cast<const netuarray_t*>(type)) {
	    unpacked_dimensions.insert(unpacked_dimensions.begin(),
				       atype->static_dimensions().begin(),
				       atype->static_dimensions().end());
	    type = atype->element_type();
      }

      if (debug_elaborate) {
	    cerr << get_fileline() << ": debug: Create signal " << wtype;
	    if (set_data_type_)
		  cout << " " << *set_data_type_;
	    cout << " " << name_ << unpacked_dimensions << " in scope "
		 << scope_path(scope) << endl;
      }

	// An interface-typed PORT (IEEE 1800-2017 25.3) is a handle to
	// an interface instance, not a wire: in this implementation it
	// is a class-typed variable (the virtual-interface model), so
	// force variable kind — the net default would reject property
	// writes (`m.data = ...` errored as "declared as a uwire").
      if (const netclass_t*ifc = dynamic_cast<const netclass_t*>(type)) {
	    if (ifc->is_interface()) {
		  if (wtype != NetNet::REG)
			wtype = NetNet::REG;
	    }
      }

      if (sig_predeclared) {
	    sig->set_net_type(type);
      } else {
	    sig = new NetNet(scope, name_, wtype, unpacked_dimensions, type);

	    if (wtype == NetNet::WIRE) sig->devirtualize_pins();
	    sig->set_line(*this);
	    sig->port_type(port_type_);
	    sig->lexical_pos(lexical_pos_);
      }

      if (user_type) {
            sig->set_user_nettype(user_type);
      }

      if (is_interconnect()) {
            sig->mark_interconnect(!sig->packed_dims().empty()
                                   || !unpacked_dimensions.empty());
            des->register_interconnect(sig);
      }

	// A modport-qualified interface port (`bus_if.mst m`) records
	// its modport name so l-value elaboration can enforce the
	// modport member directions (IEEE 1800-2017 25.5).
      if (set_data_type_) {
	    perm_string interface_modport = pform_interface_modport(
		  des, scope, set_data_type_.get());
	    if (!interface_modport.nil())
		  sig->attribute(perm_string::literal("ivl_modport"),
				 verinum(std::string(interface_modport.str())));
      }

      if (generic_iface) {
	    sig->attribute(perm_string::literal("ivl_generic_iface"),
			   verinum(1));
	    if (!generic_modport.nil())
		  sig->attribute(perm_string::literal("ivl_modport"),
				 verinum(std::string(generic_modport.str())));
      }

      if (ivl_discipline_t dis = get_discipline()) {
	    sig->set_discipline(dis);
      }
      sig->lifetime_override(lifetime_override());

      if (net_delay() || declared_wtype == NetNet::SUPPLY0
	  || declared_wtype == NetNet::SUPPLY1) {
	    sig->net_delay_declared_type(declared_wtype);
	    if (pull)
		  sig->net_delay_pull(pull);
      }

      NetNet*delay_driver = sig;
      if (const PDelays*net_delay = this->net_delay()) {
	    NetExpr*rise_expr = 0;
	    NetExpr*fall_expr = 0;
	    NetExpr*decay_expr = 0;
	    net_delay->eval_delays(des, scope, rise_expr, fall_expr,
				   decay_expr, true);

	    if (rise_expr) {
		  /* Resolve every driver on a hidden net, then delay the one
		   * resolved vector that reaches the declared signal. Applying
		   * this delay to each driver independently changes multi-driver
		   * behavior and is not a declaration delay (1800-2023 10.3.3). */
		  delay_driver = new NetNet(scope, scope->local_symbol(), wtype,
					    unpacked_dimensions, type);
		  delay_driver->set_line(*this);
		  /* This anonymous net is persistent state, not an ephemeral l-value
		   * view. PGAssign deletes local_flag() l-values after connecting
		   * them, which would leave net_delay_driver() dangling. */
		  delay_driver->local_flag(false);
		  if (wtype == NetNet::WIRE)
			delay_driver->devirtualize_pins();
		  if (ivl_discipline_t dis = get_discipline())
			delay_driver->set_discipline(dis);
		  sig->net_delay_driver(delay_driver);
		  sig->net_delay_public(sig);
		  delay_driver->net_delay_public(sig);

		  bool per_bit = sig->data_type() != IVL_VT_REAL
			&& !sig->get_scalar();
		  for (unsigned idx = 0; idx < sig->pin_count(); idx += 1) {
			NetBUFZ*boundary = new NetBUFZ(
			      scope, scope->local_symbol(), sig->vector_width(), true);
			boundary->set_line(*this);
			boundary->rise_time(rise_expr);
			boundary->fall_time(fall_expr);
			boundary->decay_time(decay_expr);
			boundary->per_bit_delay(per_bit);
			des->add_node(boundary);
			sig->add_net_delay_boundary(boundary);
			connect(boundary->pin(1), delay_driver->pin(idx));
			connect(boundary->pin(0), sig->pin(idx));
		  }
	    }
      }

      if (pull)
	    connect(delay_driver->pin(0), pull->pin(0));

      for (unsigned idx = 0 ;  idx < nattrib ;  idx += 1)
	    sig->attribute(attrib_list[idx].key, attrib_list[idx].val);

      sig->set_const(is_const_);

      /* Phase 63b/B7 (gap close): for `union tagged` typed variables,
         allocate a companion int NetNet that tracks the currently-active
         member.  Member writes set the companion to the member index;
         `case (u) matches` reads it for dispatch.  Naming convention:
         `<varname>__tag_companion` lives in the same scope as `varname`. */
      if (const netstruct_t*nst = dynamic_cast<const netstruct_t*>(type)) {
            if (nst->tagged_flag()) {
                  perm_string companion_name =
                        lex_strings.make(string(name_.str())
                                         + "__tag_companion");
                  if (!scope->find_signal(companion_name)) {
                        ivl_type_t int32 = &netvector_t::atom2s32;
                        NetNet*companion = new NetNet(scope, companion_name,
                                                      NetNet::REG, int32);
                        companion->set_line(*this);
                        companion->local_flag(true);
                        /* No initial assignment — companion stays X until
                           first tagged-union write.  case-matches default
                           branch handles the unset case. */
                  }
            }
      }

      // Keep the source placeholder available after elaboration so later
      // passes can recover typedef-backed foreach key types from the original
      // declaration instead of the lowered signal form.
      is_elaborating_ = false;

      return sig;
}
