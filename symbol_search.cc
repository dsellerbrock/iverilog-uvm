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
# include  "PExpr.h"
# include  "ivl_assert.h"

using namespace std;

struct symbol_search_cache_key_t {
      const NetScope*scope;
      const NetScope*start_scope;
      const pform_scoped_name_t*path_ref;
      unsigned lexical_pos;
      bool prefix_scope;

      bool operator<(const symbol_search_cache_key_t&that) const
      {
	    if (scope != that.scope)
		  return scope < that.scope;
	    if (start_scope != that.start_scope)
		  return start_scope < that.start_scope;
	    if (path_ref != that.path_ref)
		  return path_ref < that.path_ref;
	    if (lexical_pos != that.lexical_pos)
		  return lexical_pos < that.lexical_pos;
	    if (prefix_scope != that.prefix_scope)
		  return prefix_scope < that.prefix_scope;
	    return false;
      }
};

static std::map<symbol_search_cache_key_t,symbol_search_results>
      symbol_search_cache_;

static const netclass_t* resolve_prefix_class_type_(Design*des,
						    NetScope*scope,
						    perm_string name)
{
      if (!gn_system_verilog() || !scope)
	    return nullptr;

      if (netclass_t*cls = scope->find_class(des, name))
	    return cls;

      if (typedef_t*td = scope->find_typedef(des, name)) {
	    ivl_type_t td_type = td->elaborate_type(des, scope);
	    if (const netclass_t*cls = dynamic_cast<const netclass_t*>(td_type))
		  return cls;
      }

      return nullptr;
}

/* Local-only variant of the above: search ONLY the given scope's direct
 * tables (no walking up via find_class/find_typedef).  Used inside the
 * symbol_search scope-walk so an outer class named `a` does not shadow
 * a function-local variable also named `a` declared in a closer scope.
 * The walk handles upward propagation naturally — when control reaches
 * the scope where the class is registered, the local check picks it up.
 */
static const netclass_t* resolve_prefix_class_type_local_(Design*des,
							  NetScope*scope,
							  perm_string name)
{
      if (!gn_system_verilog() || !scope)
	    return nullptr;

      auto cls_it = scope->classes_local().find(name);
      if (cls_it != scope->classes_local().end())
	    return cls_it->second;

      typedef_t*td = scope->find_typedef_local(name);
      if (td) {
	    ivl_type_t td_type = td->elaborate_type(des, scope);
	    if (const netclass_t*cls = dynamic_cast<const netclass_t*>(td_type))
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
		   NetScope*start_scope, bool prefix_scope,
		   bool resolving_prefix)
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
				      res, start_scope, prefix_scope,
				      /*resolving_prefix=*/true);
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

		    // For event arrays: if "arr" is not found directly but
		    // path_tail has a constant bit-select index, try "arr[N]".
		  if (!path_tail.index.empty()
		      && path_tail.index.size() == 1
		      && path_tail.index.front().sel == index_component_t::SEL_BIT) {
			const PENumber*idx_num = path_tail.index.front().msb
			      ? dynamic_cast<const PENumber*>(path_tail.index.front().msb)
			      : static_cast<const PENumber*>(0);
			if (idx_num) {
			      long idx_val = idx_num->value().as_long();
			      char buf[256];
			      snprintf(buf, sizeof buf, "%s[%ld]",
				       path_tail.name.str(), idx_val);
			      perm_string indexed_name = lex_strings.make(buf);
			      if (NetEvent*arr_eve = scope->find_event(indexed_name)) {
				    if (prefix_scope || (arr_eve->lexical_pos() <= lexical_pos)) {
					  name_component_t indexed_comp(indexed_name);
					  path.push_back(indexed_comp);
					  res->scope = scope;
					  res->eve = arr_eve;
					  res->path_head = path;
					  return true;
				    }
			      }
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

		    // SV compile-progress: allow class type names (including
		    // typedef aliases to class types) to act as prefix scopes in
		    // paths such as `alias_t::static_obj.member` or
		    // `ClassName.static_member`.  Use LOCAL-only class lookup so
		    // a class declared at the module/package level doesn't
		    // shadow a function-local variable with the same name in an
		    // inner scope.  The scope walk naturally reaches the
		    // class's enclosing scope on a later iteration.
		    //
		    // Only fire when resolving a prefix of a multi-component
		    // path — for a bare single-name lookup `a = ...` we want
		    // variable resolution to win.
		  if (resolving_prefix && path_tail.index.empty()) {
			if (const netclass_t*cls = resolve_prefix_class_type_local_(
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
			cerr << li->get_fileline() << ": XXXXX: Errors evaluating scope index" << endl;
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

      if (use_cache) {
	    cache_key.scope = search_scope;
	    cache_key.start_scope = search_scope;
	    cache_key.path_ref = &path;
	    cache_key.lexical_pos = lexical_pos;
	    cache_key.prefix_scope = prefix_scope;

	    std::map<symbol_search_cache_key_t,symbol_search_results>::const_iterator cached =
		  symbol_search_cache_.find(cache_key);
	    if (cached != symbol_search_cache_.end()) {
		  *res = cached->second;
		  return res->is_found();
	    }
      }

      bool found = symbol_search(li, des, search_scope, path.name, lexical_pos,
				 res, search_scope, prefix_scope);
      if (use_cache && found)
	    symbol_search_cache_[cache_key] = *res;
      return found;
}
