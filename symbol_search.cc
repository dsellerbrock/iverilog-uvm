/*
 * Copyright (c) 2003-2024 Stephen Williams (steve@icarus.com)
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

# include  "netlist.h"
# include  "netclass.h"
# include  "netparray.h"
# include  "netmisc.h"
# include  "compiler.h"
# include  "PPackage.h"
# include  "PTask.h"
# include  "PWire.h"
# include  "pform_types.h"
# include  "ivl_assert.h"

using namespace std;

// The cache key must be the CONTENT of the query, never the address of
// the AST path object: PExpr nodes are created and deleted during
// elaboration, so a later node can reuse a freed node's address and a
// pointer-keyed cache then returns a stale, unrelated result (observed
// as `obj.predict(...)` resolving to a neighboring `obj.get_access`).
// Component names are interned perm_strings, so equal text implies
// equal pointer and a vector of them is a stable value key. Paths that
// carry index expressions are not cached at all -- their results embed
// expression pointers whose lifetime the cache cannot guarantee.
struct symbol_search_cache_key_t {
      const NetScope*scope;
      bool prefix_scope;
      std::vector<perm_string> path_names;

      bool operator<(const symbol_search_cache_key_t&that) const
      {
	    if (scope != that.scope)
		  return scope < that.scope;
	    if (prefix_scope != that.prefix_scope)
		  return prefix_scope < that.prefix_scope;
	    return path_names < that.path_names;
      }
};

static std::map<symbol_search_cache_key_t,symbol_search_results>
      symbol_search_cache_;

// See the declaration in netmisc.h: NetScope::set_signal_alias() /
// restore_signal_alias() call this so a transient name rebinding
// (IEEE 1800-2017 7.12.4 array-manipulation-method iterator names)
// cannot leave a stale cached resolution behind for the next query
// under the same (scope, name) pair. Aliasing is rare relative to
// ordinary elaboration, so an unconditional full clear is cheap and
// always correct -- no need to reason about which cache entries an
// alias could have touched.
void symbol_search_cache_clear()
{
      symbol_search_cache_.clear();
}

/* find_typedef() and find_class() intentionally search out through lexical
 * parents.  That is useful for a type-name query, but it is too broad for the
 * per-scope fallback below: while resolving the first component of `a.m', a
 * class named `a' in $unit must not be selected while the ordinary lexical
 * search still has an enclosing block/function-local variable named `a' to
 * visit.  Only accept a type at the scope that owns its declaration (or at a
 * derived class scope where a base-class typedef is inherited).  Imports are
 * entered through symbol_search()'s existing find_import() transition, so
 * they reach their owning package without preempting intervening values.
 */
static bool prefix_typedef_is_local_(Design*des, NetScope*scope,
                                     typedef_t*td)
{
      ivl_assert(*scope, td);

      NetScope*owner = scope->find_typedef_scope(des, td);
      if (owner == scope)
            return true;

      if (!owner || scope->type() != NetScope::CLASS)
            return false;

      const netclass_t*cls = scope->class_def();
      for (const netclass_t*super = cls ? cls->get_super() : 0;
           super; super = super->get_super()) {
            if (super->class_scope() == owner)
                  return true;
      }

      return false;
}

static bool prefix_class_is_local_(Design*des, NetScope*scope,
                                   const netclass_t*cls,
                                   perm_string name)
{
      ivl_assert(*scope, cls);

      /* A class-valued parameter is declared in the current scope even when
       * its actual class type was defined elsewhere. */
      ivl_type_t parameter_type = nullptr;
      (void) scope->get_parameter(des, name, parameter_type);
      if (parameter_type == cls)
            return true;

      if (scope->type() == NetScope::CLASS) {
            const netclass_t*containing = scope->class_def();
            if (containing == cls)
                  return true;
            for (const netclass_t*super = containing
                       ? containing->get_super() : 0;
                 super; super = super->get_super()) {
                  if (super == cls)
                        return true;
            }
      }

      return const_cast<netclass_t*>(cls)->definition_scope() == scope;
}

static const netclass_t* resolve_prefix_class_type_(Design*des,
						    NetScope*scope,
						    perm_string name)
{
      if (!gn_system_verilog() || !scope)
	    return nullptr;

      if (typedef_t*td = scope->find_typedef(des, name)) {
	    /* Do not let an outward-searching type query jump ahead of the
	       ordinary value lookup performed one lexical scope at a time. */
	    if (!prefix_typedef_is_local_(des, scope, td))
		  return nullptr;

	    const data_type_t*declared_type = td->get_data_type();

	    /* The parser installs a same-name class_type_t typedef for a class
	       declaration.  Preserve that direct-class path, including forward
	       declarations whose typedef has not elaborated a usable type yet. */
	    if (const class_type_t*class_pf =
		  dynamic_cast<const class_type_t*>(declared_type)) {
		  if (class_pf->name == name) {
			if (netclass_t*cls = scope->find_class(des, name))
			      return cls;
		  }
	    }

	    ivl_type_t td_type = td->elaborate_type(des, scope);
	    td_type = specialize_bare_class_at_concrete_use(
		  des, scope, declared_type, td_type, true);
	    if (const netclass_t*cls = dynamic_cast<const netclass_t*>(td_type))
		  return cls;

	    /* A concrete non-class typedef hides any outer class with the same
	       spelling.  Only a null (early/forward) typedef may recover through
	       the class table below. */
	    if (td_type)
		  return nullptr;
      }

      if (netclass_t*cls = scope->find_class(des, name)) {
	    if (prefix_class_is_local_(des, scope, cls, name))
		  return cls;
      }

      return nullptr;
}

/*
 * Search for the hierarchical name. The path may have multiple components. If
 * that's the case, then recursively pull the path apart until we find the
 * first item in the path, look that up, and work our way up. In most cases,
 * the path will be a string of scopes, with an object at the end. But if we
 * find an object before the end, then the tail will have to be figured out by
 * the initial caller.
 */

bool symbol_search(const LineInfo*li, Design*des, NetScope*scope,
		   pform_name_t path, unsigned lexical_pos,
		   struct symbol_search_results*res,
		   NetScope*start_scope, bool prefix_scope)
{
      assert(scope);

      if (debug_elaborate) {
	    cerr << li->get_fileline() << ": symbol_search: "
		 << "scope: " << scope_path(scope) << endl;
	    cerr << li->get_fileline() << ": symbol_search: "
		 << "path: " << path << endl;
	    if (start_scope)
		  cerr << li->get_fileline() << ": symbol_search: "
		       << "start_scope: " << scope_path(start_scope) << endl;
      }

      assert(li);
      ivl_assert(*li, ! path.empty());
      name_component_t path_tail = path.back();
      path.pop_back();

      // If this is a recursive call, then we need to know that so
      // that we can enable the search for scopes. Set the
      // recurse_flag to true if this is a recurse.
      if (start_scope==0)
	    start_scope = scope;

      // If there are components ahead of the tail, symbol_search
      // recursively. Ideally, the result is a scope that we search
      // for the tail key, but there are other special cases as well.
      if (! path.empty()) {
	    bool flag = symbol_search(li, des, scope, path, lexical_pos,
				      res, start_scope, prefix_scope);
	    if (! flag)
		  return false;

	    // The prefix is found to be something besides a scope. Put the
	    // tail into the path_tail of the result, and return success. The
	    // caller needs to deal with that tail bit. Note that the
	    // path_tail is a single item, but we might have been called
	    // recursively, so the complete tail will be built up as we unwind.
	    if (res->is_found() && !res->is_scope()) {
		  if (!path_tail.empty())
			res->path_tail.push_back(path_tail);
		  return true;
	    }

	    // The prefix is found to be a scope, so switch to that
	    // scope, set the hier_path to turn off upwards searches,
	    // and continue our search for the tail.
	    if (res->is_scope()) {
		  scope = res->scope;
		  prefix_scope = true;

		  if (debug_scopes || debug_elaborate) {
			cerr << li->get_fileline() << ": symbol_search: "
			     << "Prefix scope " << scope_path(scope) << endl;
		  }

		  if (scope->is_auto()) {
			cerr << li->get_fileline() << ": error: Hierarchical "
			      "reference to automatically allocated item "
			      "`" << path_tail.name << "' in path `" << path << "'" << endl;
			des->errors += 1;
		  }

	    } else {
		  // Prefix is present, but is NOT a scope. Fail! Actually, this
		  // should not happen, since this is the "not found" case, and we
		  // should have returned already.
		  ivl_assert(*li, 0);
		  return false;
	    }
      }

      bool passed_module_boundary = false;

      // At this point, we've stripped right-most components until the search
      // found the scope part of the path, or there is no scope part of the
      // path. For example, if the path in was s1.s2.x, we found the scope
      // s1.s2, res->is_scope() is true, and path_tail is x. We look for x
      // now. The preceeding code set prefix_scope=true to ease our test below.
      //
      // If the input was x (without prefixes) then we don't know if x is a
      // scope or item. In this case, res->is_found() is false and we may need
      // to scan upwards to find the scope or item.
      while (scope) {
	    if (debug_scopes || debug_elaborate) {
		  cerr << li->get_fileline() << ": symbol_search: "
		       << "Looking for " << path_tail
		       << " in scope " << scope_path(scope)
		       << " prefix_scope=" << prefix_scope << endl;
	    }
            if (scope->genvar_tmp.str() && path_tail.name == scope->genvar_tmp)
                  return false;

	    // These items cannot be seen outside the bounding module where
	    // the search starts. But we continue searching up because scope
	    // names can match. For example:
	    //
	    //    module top;
	    //        int not_ok;
	    //        dut foo(...);
	    //    endmodule
	    //    module dut;
	    //        ... not_ok; // <-- Should NOT match.
	    //        ... top.not_ok; // Matches.
	    //    endmodule
	    if (!passed_module_boundary) {
		  // Special case `super` keyword. Return the `this` object, but
		  // with the type of the base class.
		  if (path_tail.name == "#") {
			// Find 'this' by walking up the scope hierarchy.
			// In task scopes 'this' lives in the parent class scope,
			// not the task scope itself.  Walk up through TASK/FUNC/BEGIN
			// scopes but stop at module/package boundaries.
			NetNet *net = nullptr;
			for (NetScope *cur = scope; cur; cur = cur->parent()) {
			      if (cur->type() == NetScope::MODULE
				  || cur->type() == NetScope::PACKAGE)
				    break;
			      if (NetNet *found = cur->find_signal(
					perm_string::literal(THIS_TOKEN))) {
				    net = found;
				    break;
			      }
			}
			if (net) {
			      const netclass_t *class_type = dynamic_cast<const netclass_t*>(net->net_type());
			      path.push_back(path_tail);
			      res->scope = scope;
			      res->net = net;
			      res->type = class_type->get_super();
			      res->path_head = path;
			      return true;
			}
			return false;
		  }

		  if (NetNet*net = scope->find_signal(path_tail.name)) {
			if (prefix_scope || (net->lexical_pos() <= lexical_pos)) {
			      path.push_back(path_tail);
			      res->scope = scope;
			      res->net = net;
			      res->type = net->net_type();
			      res->path_head = path;
			      return true;
			} else if (!res->decl_after_use) {
			      res->decl_after_use = net;
			}
		  }

		    // Some constructors elaborate without a synthetic hidden "this"
		    // signal but still have a class-typed return signal that can act
		    // as the implicit object handle. Support direct `this` lookups in
		    // those scopes the same way class-property rewrites already do.
		  if (path_tail.name == perm_string::literal(THIS_TOKEN)
		      && !prefix_scope) {
			NetScope*scope_method = find_method_containing_scope(*li, start_scope);
			if (scope_method && scope_method->type() == NetScope::FUNC) {
			      if (NetNet*this_net = find_implicit_this_handle(des, scope_method)) {
				    path.push_back(path_tail);
				    res->scope = scope_method;
				    res->net = this_net;
				    res->type = this_net->net_type();
				    res->path_head = path;
				    return true;
			      }
			}
		  }

		  if (NetEvent*eve = scope->find_event(path_tail.name)) {
			if (prefix_scope || (eve->lexical_pos() <= lexical_pos)) {
			      path.push_back(path_tail);
			      res->scope = scope;
			      res->eve = eve;
			      res->path_head = path;
			      return true;
			} else if (!res->decl_after_use) {
			      res->decl_after_use = eve;
			}
		  }

		    // Class named events are stored in the class scope event list,
		    // but inherited class events are not found by NetScope::find_event.
		    // Search the superclass chain so derived methods can resolve
		    // members like a protected base-class event "m_event".
		  if (!prefix_scope && scope->type() == NetScope::CLASS) {
			const netclass_t*clsnet = scope->class_def();
			for (const netclass_t*sup = clsnet ? clsnet->get_super() : 0;
			     sup ; sup = sup->get_super()) {
			      const NetScope*sup_scope_c = sup->class_scope();
			      NetScope*sup_scope = const_cast<NetScope*>(sup_scope_c);
			      if (!sup_scope)
				    continue;
			      if (NetEvent*eve = sup_scope->find_event(path_tail.name)) {
				    path.push_back(path_tail);
				    res->scope = sup_scope;
				    res->eve = eve;
				    res->path_head = path;
				    return true;
			      }
			}
		  }

		  if (const NetExpr*par = scope->get_parameter(des, path_tail.name, res->type)) {
			if (prefix_scope || (scope->get_parameter_lexical_pos(path_tail.name) <= lexical_pos)) {
			      path.push_back(path_tail);
			      res->scope = scope;
			      res->par_val = par;
			      res->path_head = path;
			      return true;
			} else if (!res->decl_after_use) {
			      res->decl_after_use = par;
			}
		  }

		    // Enum literals declared in a base class are inherited class
		    // members (IEEE 1800-2017 8.3). Definitions::enumeration_expr()
		    // is intentionally local to one scope, so walk the superclass
		    // chain here after the current class's ordinary parameter/enum
		    // lookup. This also covers out-of-block derived methods whose
		    // unqualified literal is resolved through their class scope.
		  if (scope->type() == NetScope::CLASS) {
			const netclass_t*clsnet = scope->class_def();
			for (const netclass_t*sup = clsnet ? clsnet->get_super() : 0;
			     sup ; sup = sup->get_super()) {
			      NetScope*sup_scope = const_cast<NetScope*>(sup->class_scope());
			      if (!sup_scope)
				    continue;
			      const NetExpr*enum_lit =
				    sup_scope->enumeration_expr(path_tail.name);
			      if (!enum_lit)
				    continue;

			      path.push_back(path_tail);
			      res->scope = sup_scope;
			      res->par_val = enum_lit;
			      res->type = enum_lit->net_type();
			      res->path_head = path;
			      return true;
			}
		  }

		    // Extern class methods may elaborate under package scope rather
		    // than nested below the CLASS scope. In that case, use the
		    // method's implicit "this" (or constructor return handle) to
		    // resolve unqualified class properties.
		  if (!prefix_scope && scope->type() == NetScope::FUNC
		      && path_tail.index.empty()) {
			const PFunction*scope_pfunc = scope->func_pform();
			bool class_method_ctx = false;
			if (scope_pfunc && scope_pfunc->method_of())
			      class_method_ctx = true;
			if (scope->basename() == perm_string::literal("new")
			    || scope->basename() == perm_string::literal("new@"))
			      class_method_ctx = true;

			if (class_method_ctx) {
			      NetNet*this_net = find_implicit_this_handle(des, scope);
			      if (this_net == 0) {
				    if (PWire*this_pw = scope->find_signal_placeholder(
						perm_string::literal(THIS_TOKEN))) {
					  this_net = this_pw->elaborate_sig(des, scope);
				    }
			      }
			      if (this_net == 0 && scope_pfunc && scope_pfunc->method_of()) {
				    ivl_type_t this_type =
					  scope_pfunc->method_of()->elaborate_type_raw(des, scope);
				    if (const netclass_t*cls_this =
					    dynamic_cast<const netclass_t*>(this_type)) {
					  NetNet*synth_this = new NetNet(scope,
							perm_string::literal(THIS_TOKEN),
							NetNet::REG, cls_this);
					  synth_this->set_line(*li);
					  this_net = synth_this;
				    }
			      }

			      const netclass_t*clsnet = this_net
					? dynamic_cast<const netclass_t*>(this_net->net_type())
					: 0;
			      int pidx = clsnet
				    ? const_cast<netclass_t*>(clsnet)->ensure_property_decl(des, path_tail.name)
				    : -1;
			      if (pidx >= 0 && this_net) {
				    res->net = this_net;
				    res->scope = scope;
				    res->path_head = path;
				    res->path_head.push_back(name_component_t(
						perm_string::literal(THIS_TOKEN)));
				    res->path_tail.push_front(path_tail);
				    res->type = clsnet;
				    return true;
			      }
			}
		  }

		    // Static items are just normal signals and are found above.
		  if (scope->type() == NetScope::CLASS) {
			const netclass_t *clsnet = scope->class_def();
			int pidx = clsnet
			      ? const_cast<netclass_t*>(clsnet)->ensure_property_decl(des, path_tail.name)
			      : -1;
			if (pidx >= 0) {
			      // This is a class property being accessed in a
				      // class method. Return `this` for the net and the
				      // property name for the path tail.
			      NetScope *scope_method = find_method_containing_scope(*li, start_scope);
			      if (scope_method) {
			      res->net = find_implicit_this_handle(des, scope_method);
			      // SV compile-progress: if property found in class
			      // definition but "this" handle is not available, try
			      // alternative resolution strategies.
			      if (res->net == 0) {
				    // Try finding static property signal directly.
				    NetNet*sprop = clsnet->find_static_property(path_tail.name);
				    if (sprop) {
					  path.push_back(path_tail);
					  res->scope = scope;
					  res->net = sprop;
					  res->type = sprop->net_type();
					  res->path_head = path;
					  return true;
				    }
				    // Try elaborating the "this" signal from the
				    // method scope placeholder (covers extern
				    // constructors that haven't had sig elaborated).
				    PWire*this_pw = scope_method->find_signal_placeholder(
					  perm_string::literal(THIS_TOKEN));
				    if (this_pw) {
					  NetNet*this_net = this_pw->elaborate_sig(des, scope_method);
					  if (this_net)
						res->net = this_net;
				    }
				    // Also try parent scope's constructors for the
				    // "this" signal when the current method scope
				    // does not have one.
				    if (res->net == 0) {
					  NetNet*this_try = scope->find_signal(
						perm_string::literal(THIS_TOKEN));
					  if (this_try)
						res->net = this_try;
				    }
				    // SV compile-progress fallback: if the property
				    // is definitely in the class definition but we
				    // still cannot find a "this" handle, create a
				    // synthetic placeholder signal in the method
				    // scope to represent "this".
				    if (res->net == 0 && gn_system_verilog()) {
					  NetNet*synth_this = new NetNet(scope_method,
						perm_string::literal(THIS_TOKEN),
						NetNet::REG, clsnet);
					  synth_this->set_line(*li);
					  res->net = synth_this;
				    }
			      }
				      if (res->net == 0)
					    continue;
				      res->scope = scope;
				      res->path_head = path;
				      res->path_head.push_back(name_component_t(perm_string::literal(THIS_TOKEN)));
				      res->path_tail.push_front(path_tail);
				      res->type = clsnet;
				      return true;
			      }
				}
		  }

		    // Finally check the rare case of a signal that hasn't
		    // been elaborated yet.
		  if (PWire*wire = scope->find_signal_placeholder(path_tail.name)) {
			if (prefix_scope || (wire->lexical_pos() <= lexical_pos)) {
			      NetNet*net = wire->elaborate_sig(des, scope);
			      if (!net)
				    return false;
			      path.push_back(path_tail);
			      res->scope = scope;
			      res->net = net;
			      res->type = net->net_type();
			      res->path_head = path;
			      return true;
			}
		  }

		    // SV compile-progress: allow class type names (including
		    // typedef aliases to class types) to act as prefix scopes in
		    // paths such as alias_t::static_obj.member. The parser stores
		    // both "." and "::" chains in the same name list, so this
		    // fallback intentionally keys off class-type lookup only after
		    // normal object lookup fails.
		  if (path_tail.index.empty()) {
			if (const netclass_t*cls = resolve_prefix_class_type_(
				    des, scope, path_tail.name)) {
			      NetScope*cls_scope =
				    const_cast<NetScope*>(cls->class_scope());
			      if (cls_scope) {
				    path.push_back(path_tail);
				    res->scope = cls_scope;
				    res->path_head = path;
				    return true;
			      }
			}
		  }
	    }

	    // Could not find an object. Maybe this is a child scope name? If
	    // so, evaluate the path components to find the exact scope this
	    // refers to. This item might be:
	    //     <scope>.s
	    //     <scope>.s[n]
	    // etc. The scope->child_byname tests if the name exists, and if
	    // it does, the eval_path_component() evaluates any [n]
	    // expressions to constants to generate an hname_t object for a
	    // more complete scope name search. Note that the index
	    // expressions for scope names must be constant.
	    if (scope->child_byname(path_tail.name)) {
		  bool flag = false;
		  hname_t path_item = eval_path_component(des, start_scope, path_tail, flag);
		  if (flag) {
			res->scope_index_error = true;
			return false;
		  } else if (NetScope*chld = scope->child(path_item)) {
			path.push_back(path_tail);
			res->scope = chld;
			res->path_head = path;
			return true;
		  }
	    }

	    // Don't scan up if we are searching within a prefixed scope.
	    if (prefix_scope)
		  break;

	    // Imports are not visible through hierachical names
	    if (NetScope*import_scope = scope->find_import(des, path_tail.name)) {
		  scope = import_scope;
		  continue;
	    }

	    // Special case: We can match the module name of a parent
	    // module. That means if the current scope is a module of type
	    // "mod", then "mod" matches the current scope. This is fairly
	    // obscure, but looks like this:
	    //
	    //  module foo;
	    //    reg x;
	    //    ... foo.x; // This matches x in myself.
	    //  endmodule
	    //
	    // This feature recurses, so code in subscopes of foo can refer to
	    // foo by the name "foo" as well. In general, anything within
	    // "foo" can use the name "foo" to reference it.
	    if (scope->type()==NetScope::MODULE && scope->module_name()==path_tail.name) {
		  path.push_back(path_tail);
		  res->scope = scope;
		  res->path_head = path;
		  return true;
	    }

	    // If there is no prefix, then we are free to scan upwards looking
	    // for a scope name. Note that only scopes can be searched for up
	    // past module boundaries. To handle that, set a flag to indicate
	    // that we passed a module boundary on the way up.
	    if (scope->type()==NetScope::MODULE && !scope->nested_module())
		  passed_module_boundary = true;

	    scope = scope->parent();

	    // Last chance - try the compilation unit. Note that modules may
	    // reference nets/variables in the compilation unit, even if they
	    // cannot reference variables in containing scope.
	    //
	    //    int ok = 1;
	    //    module top;
	    //        int not_ok = 2;
	    //        dut foo();
	    //    endmodule
	    //
	    //    module dut;
	    //        ... = ok; // This reference is OK
	    //        ... = not_ok; // This reference is NOT OK.
	    //    endmodule
	    if (scope == 0 && start_scope != 0) {
		  scope = start_scope->unit();
		  start_scope = 0;
		  passed_module_boundary = false;
	    }
      }


      // Last chance: this is a single name, so it might be the name
      // of a root scope. Ask the design if this is a root
      // scope. This is only possible if there is no prefix.
      if (prefix_scope==false) {
	    hname_t path_item (path_tail.name);
	    scope = des->find_scope(path_item);
	    if (scope) {
		  path.push_back(path_tail);
		  res->scope = scope;
		  res->path_head = path;
		  return true;
	    }

	    // Also try as a package scope. Self-references like pkg::Y inside
	    // pkg_b parse as hierarchical when the package isn't yet registered
	    // at lex time. Resolve them here so cross-package constants work.
	    NetScope*pkg_scope = des->find_package(path_tail.name);
	    if (pkg_scope) {
		  path.push_back(path_tail);
		  res->scope = pkg_scope;
		  res->path_head = path;
		  return true;
	    }
      }

      return false;
}

bool symbol_search(const LineInfo *li, Design *des, NetScope *scope,
		   const pform_scoped_name_t &path, unsigned lexical_pos,
		   struct symbol_search_results *res)
{
      NetScope *search_scope = scope;
      bool prefix_scope = false;
      symbol_search_cache_key_t cache_key;
      bool use_cache = (lexical_pos == UINT_MAX);

      if (path.package) {
	    search_scope = des->find_package(path.package->pscope_name());
	    if (!search_scope)
		  return false;
	    prefix_scope = true;
      }

      for (list<name_component_t>::const_iterator cur = path.name.begin()
		 ; use_cache && cur != path.name.end() ; ++cur) {
	    if (! cur->index.empty())
		  use_cache = false;
      }

      if (use_cache) {
	    cache_key.scope = search_scope;
	    cache_key.prefix_scope = prefix_scope;
	    cache_key.path_names.reserve(path.name.size());
	    for (list<name_component_t>::const_iterator cur = path.name.begin()
		       ; cur != path.name.end() ; ++cur)
		  cache_key.path_names.push_back(cur->name);

	    std::map<symbol_search_cache_key_t,symbol_search_results>::const_iterator cached =
		  symbol_search_cache_.find(cache_key);
	    if (cached != symbol_search_cache_.end()) {
		  *res = cached->second;
		  return res->is_found();
	    }
      }

      bool found = symbol_search(li, des, search_scope, path.name, lexical_pos,
				 res, search_scope, prefix_scope);

	// IEEE 1800-2017 26.6: a package may re-export a name it
	// imported, and the name is then reachable through the
	// EXPORTING package -- `export inner::D;' in `outer' makes
	// `outer::D' legal even though D is declared in `inner'.
	//
	// The exports were recorded at parse time (PPackage::exports)
	// and never consulted again, so the qualified lookup only ever
	// saw `outer's own declarations and the reference failed to
	// bind. Retry it in the package the name is exported FROM.
	//
	// The exports list is the gate: a plain `import inner::D;'
	// without the matching export does NOT make `outer::D' legal,
	// so consulting the import map alone would over-accept.
      if (!found && path.package && !path.name.empty()) {
	    perm_string want = path.name.front().name;
	    for (std::vector<PPackage::export_t>::const_iterator ex
		       = path.package->exports.begin()
		       ; ex != path.package->exports.end() ; ++ex) {
		    // A NAMED export (`export inner::D;') only covers
		    // that one name.
		  if (!ex->name.nil() && ex->name != want)
			continue;

		  PPackage*src = ex->pkg;
		  if (!src) {
			  // `export *::*': whatever this package
			  // imported under that name, if anything.
			auto imp = path.package->explicit_imports.find(want);
			if (imp == path.package->explicit_imports.end())
			      continue;
			src = imp->second;
		  }
		  if (src == path.package)
			continue;

		  NetScope*src_scope = des->find_package(src->pscope_name());
		  if (!src_scope)
			continue;

		  if (symbol_search(li, des, src_scope, path.name,
				    lexical_pos, res, src_scope, true)) {
			found = true;
			break;
		  }
	    }
      }

      if (use_cache && found)
	    symbol_search_cache_[cache_key] = *res;
      return found;
}
