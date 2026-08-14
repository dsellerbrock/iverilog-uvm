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

# include  <cstdarg>
# include  <cstring>
# include  <iostream>
# include  <list>
# include  <vector>
# include  "pform.h"
# include  "PClass.h"
# include  "PExpr.h"
# include  "parse_misc.h"
# include  "ivl_assert.h"

using namespace std;

/*
 * The functions here help the parser put together class type declarations.
 */
static PClass*pform_cur_class = 0;
static PTaskFunc* pform_recent_class_method_ = 0;

void pform_blend_class_constructors(PClass*pclass)
{
      perm_string new1 = perm_string::literal("new");
      perm_string new2 = perm_string::literal("new@");

      map<perm_string,PFunction*>::iterator iter_new = pclass->funcs.find(new1);
      PFunction*use_new = (iter_new == pclass->funcs.end()) ? 0 : iter_new->second;

      map<perm_string,PFunction*>::iterator iter_new2 = pclass->funcs.find(new2);
      PFunction*use_new2 = (iter_new2 == pclass->funcs.end()) ? 0 : iter_new2->second;

      const bool explicit_body_ready = use_new && use_new->get_statement();

      if (use_new == 0 && use_new2 == 0)
            return;

      if (use_new && use_new2 && !explicit_body_ready)
            return;

      PChainConstructor*chain_new = 0;
      if (explicit_body_ready)
            chain_new = use_new->extract_chain_constructor();
      else if (use_new2 && use_new == 0)
            chain_new = use_new2->extract_chain_constructor();
      if (chain_new == 0 && pclass->type->base_type) {
            chain_new = new PChainConstructor(pclass->type->base_args);
            chain_new->set_line(*pclass);
      }

      if (use_new && use_new2) {
            if (!use_new->method_of() && use_new2->method_of()) {
                  use_new->set_method_type_only(use_new2->method_of());
                  use_new->set_return(use_new2->method_of());
            }

            if (use_new->method_of() != use_new2->method_of()) {
                  cerr << use_new->get_fileline()
                       << ": warning: constructor merge saw mismatched method class metadata."
                       << endl;
            }

            Statement*def_new = use_new->get_statement();
            Statement*def_new2 = use_new2->get_statement();

            if (def_new == 0) {
                  def_new = new PBlock(PBlock::BL_SEQ);
                  use_new->set_statement(def_new);
            }

            if (def_new2)
                  use_new->push_statement_front(def_new2);

            pclass->funcs.erase(iter_new2);
            if (pform_recent_class_method_ == use_new2)
                  pform_recent_class_method_ = 0;
            delete use_new2;
            use_new2 = 0;
      }

      if (chain_new) {
            if (use_new2)
                  use_new2->push_statement_front(chain_new);
            else if (use_new)
                  use_new->push_statement_front(chain_new);
      }
}

/*
 * The base_type is set to the base class if this declaration is
 * starting a derived class. For example, for the syntax:
 *
 *    class foo extends bar (exprs) ...
 *
 * the base_type is the type of the class "bar", and the base_exprs,
 * if present, are the "exprs" that would be passed to a chained
 * constructor.
 */
void pform_start_class_declaration(const struct vlltype&loc,
				   class_type_t*type,
				   data_type_t*base_type,
				   list<named_pexpr_t> *base_args,
				   bool virtual_class,
				   bool interface_class,
				   list<data_type_t*>*interface_types)
{
      PClass*class_scope = pform_push_class_scope(loc, type->name);
      class_scope->type = type;
      ivl_assert(loc, pform_cur_class == 0);
      pform_cur_class = class_scope;

      ivl_assert(loc, type->base_type == 0);
      type->base_type.reset(base_type);
      type->virtual_class = virtual_class;
      type->interface_class = interface_class;

      if (interface_types) {
	    for (data_type_t*relation : *interface_types)
		  type->interface_types.emplace_back(relation);
	    delete interface_types;
      }


      ivl_assert(loc, type->base_args.empty());
      if (base_args) {
	    type->base_args.insert(type->base_args.begin(), base_args->begin(),
			           base_args->end());
	    delete base_args;
      }
}

void pform_class_property(const struct vlltype&loc,
			  property_qualifier_t property_qual,
			  data_type_t*data_type,
			  list<decl_assignment_t*>*decls)
{
      ivl_assert(loc, pform_cur_class);

	// Add the non-static properties to the class type
	// object. Unwind the list of names to make a map of name to
	// type.
      for (list<decl_assignment_t*>::iterator cur = decls->begin()
		 ; cur != decls->end() ; ++cur) {

	    decl_assignment_t*curp = *cur;
	    data_type_t*use_type = data_type;

	    if (! curp->index.empty()) {
		  list<pform_range_t>*pd = new list<pform_range_t> (curp->index);
		  use_type = new uarray_type_t(use_type, pd);
		  FILE_NAME(use_type, loc);
	    }

	    pform_cur_class->type->properties[curp->name.first]
		  = class_type_t::prop_info_t(property_qual,use_type);
	    FILE_NAME(&pform_cur_class->type->properties[curp->name.first], loc);
            pform_cur_class->type->property_order.push_back(curp->name.first);

	    vector<Statement*>&initializers = property_qual.test_static()
		  ? pform_cur_class->type->initialize_static
		  : pform_cur_class->type->initialize;
	    if (!pform_validate_struct_member_defaults(loc, use_type, curp)) {
		  // The validation emitted the mandatory diagnostic.
	    } else if (property_qual.test_const() &&
		pform_has_implicit_struct_member_defaults(use_type, curp)) {
		  cerr << loc.get_fileline()
		       << ": sorry: unpacked-struct default member initializers "
			  "are not yet supported for const class property "
			  "declaration `" << curp->name.first
		       << "'; provide an explicit whole-variable initializer."
		       << endl;
		  error_count += 1;
	    } else {
		  pform_make_struct_member_defaults(loc, use_type, curp,
					      initializers);
	    }

	    if (PExpr*rval = curp->expr.release()) {
		  PExpr*lval = new PEIdent(curp->name.first, curp->name.second);
		  FILE_NAME(lval, loc);
		    // A class-property declaration assignment is a variable
		    // initializer, just like the declaration assignments built by
		    // pform_make_var_init().  Preserve that context through l-value
		    // elaboration.  In particular, a static const property may be
		    // written by this declaration initializer and nowhere else.
		  PAssign*tmp = new PAssign(lval, rval, false, true);
		  FILE_NAME(tmp, loc);

		  initializers.push_back(tmp);
	    }
      }
}

void pform_set_this_class(const struct vlltype&loc, PTaskFunc*net)
{
      if (pform_cur_class == 0)
	    return;

      list<pform_port_t>*this_name = new list<pform_port_t>;
      this_name->push_back(pform_port_t({ perm_string::literal(THIS_TOKEN), 0 }, 0, 0));
      vector<pform_tf_port_t>*this_port = pform_make_task_ports(loc,
						       NetNet::PINPUT,
						       pform_cur_class->type,
						       this_name);
	// The pform_make_task_ports() function deletes the this_name
	// object.

      ivl_assert(loc, this_port->at(0).defe == 0);
      PWire*this_wire = this_port->at(0).port;
      delete this_port;

      net->set_this(pform_cur_class->type, this_wire);
      pform_recent_class_method_ = net;
}

void pform_mark_recent_class_method_virtual(void)
{
      if (pform_recent_class_method_)
	    pform_recent_class_method_->set_virtual_method(true);
      pform_recent_class_method_ = 0;
}

void pform_set_constructor_return(PFunction*net)
{
      ivl_assert(*net, pform_cur_class);
      net->set_return(pform_cur_class->type);
}

bool pform_reenter_class_scope(const struct vlltype&loc, const char*name)
{
      ivl_assert(loc, pform_cur_class == 0);

      for (LexicalScope*scope = pform_peek_scope(); scope; scope = scope->parent_scope()) {
	    PScopeExtra*scopex = dynamic_cast<PScopeExtra*>(scope);
	    if (scopex == 0)
		  continue;

	    for (auto it = scopex->classes.begin(); it != scopex->classes.end(); ++it) {
		  if (std::strcmp(it->first, name) != 0)
			continue;

		  pform_cur_class = it->second;
		  pform_push_existing_scope(it->second);
		  return true;
	    }
      }

      return false;
}

void pform_leave_class_scope(const struct vlltype&loc)
{
      if (pform_cur_class == 0)
	    return;

      pform_cur_class = 0;
      pform_pop_scope();
      (void)loc;
}

/*
 * A constructor is basically a function with special implications.
 */
PFunction*pform_push_constructor_scope(const struct vlltype&loc)
{
      ivl_assert(loc, pform_cur_class);
      PFunction*func = pform_push_function_scope(loc, "new", LexicalScope::AUTOMATIC);
      return func;
}

void pform_end_class_declaration(const struct vlltype&loc)
{
      ivl_assert(loc, pform_cur_class);

	// If there were initializer statements, then collect them
	// into an implicit constructor function. Also make sure that an
	// explicit constructor exists if base class constructor arguments are
	// specified, so that the base class constructor will be called.
      if (!pform_cur_class->type->initialize.empty() ||
          !pform_cur_class->type->base_args.empty()) {
	    PFunction*func = pform_push_function_scope(loc, "new@", LexicalScope::AUTOMATIC);
	    func->set_ports(0);
	    pform_set_constructor_return(func);
	    pform_set_this_class(loc, func);

	    class_type_t*use_class = pform_cur_class->type;
	    if (use_class->initialize.size() == 1) {
		  func->set_statement(use_class->initialize.front());
	    } else {
		  PBlock*tmp = new PBlock(PBlock::BL_SEQ);
		  tmp->set_statement(use_class->initialize);
		  func->set_statement(tmp);
	    }
	    pform_pop_scope();
      }

      pform_blend_class_constructors(pform_cur_class);
      pform_recent_class_method_ = 0;

      pform_cur_class = 0;
      pform_pop_scope();
}

bool pform_in_class()
{
      return pform_cur_class != 0;
}

/*
 * Bind an out-of-class function body to its extern prototype declared
 * inside the class. When an extern method is parsed out-of-class
 * (e.g. "function void MyClass::foo(...)"), the body-bearing PFunction
 * is created but not linked to the class's funcs map. This function
 * replaces the bodyless prototype with the real implementation.
 */
void pform_bind_extern_func(PFunction*func)
{
      if (pform_cur_class == 0)
	    return;

      perm_string name = func->pscope_name();
      map<perm_string,PFunction*>::iterator it = pform_cur_class->funcs.find(name);
      if (it != pform_cur_class->funcs.end()) {
	    PFunction*proto = it->second;
	    if (!func->method_of() && proto->method_of())
		  func->set_method_type_only(proto->method_of());
	    if (!func->is_virtual_method() && proto->is_virtual_method())
		  func->set_virtual_method(true);
	    it->second = func;
      } else {
	    pform_cur_class->funcs[name] = func;
      }

      if (name == perm_string::literal("new"))
            pform_blend_class_constructors(pform_cur_class);
}

/*
 * Same as above, for tasks.
 */
void pform_bind_extern_task(PTask*task)
{
      if (pform_cur_class == 0)
	    return;

      perm_string name = task->pscope_name();
      map<perm_string,PTask*>::iterator it = pform_cur_class->tasks.find(name);
      if (it != pform_cur_class->tasks.end()) {
	    PTask*proto = it->second;
	    if (!task->method_of() && proto->method_of())
		  task->set_method_type_only(proto->method_of());
	    if (!task->is_virtual_method() && proto->is_virtual_method())
		  task->set_virtual_method(true);
	    it->second = task;
      } else {
	    pform_cur_class->tasks[name] = task;
      }
}

void pform_class_constraint(const struct vlltype&loc,
			     bool is_static,
			     const char*name,
			     std::list<PExpr*>*items)
{
      if (!pform_cur_class || !name)
	    return;

      perm_string pname = lex_strings.make(name);
      auto proto = pform_cur_class->type->extern_constraints.find(pname);
      if (proto != pform_cur_class->type->extern_constraints.end()) {
	    if (proto->second.is_static != is_static) {
		  cerr << loc << ": error: Out-of-body definition of constraint `"
		       << pname << "' does not match the prototype's static "
			  "qualifier." << endl;
		  error_count += 1;
	    }
	    pform_cur_class->type->extern_constraints.erase(proto);
      }
      vector<PExpr*>& slot = pform_cur_class->type->constraints[pname];
      if (items) {
	    slot.assign(items->begin(), items->end());
	    delete items;
      }
}

void pform_class_constraint_prototype(const struct vlltype&loc,
				      bool is_static,
				      const char*name)
{
      if (!pform_cur_class || !name)
	    return;

      perm_string pname = lex_strings.make(name);
      class_type_t::extern_constraint_info_t&info =
	    pform_cur_class->type->extern_constraints[pname];
      FILE_NAME(&info, loc);
      info.is_static = is_static;
      info.reported = false;
}

// I1 (Phase 62g): forward-declared accumulator from parse.y.
extern std::vector<class_type_t::pform_cross_t> pending_crosses_;
extern std::map<perm_string, PExpr*> pending_cg_options_;

/* IEEE 1800-2017 19.6. A cross item may name either an explicitly declared
 * coverpoint or an integral variable. In the latter case the language creates
 * an implicit coverpoint equivalent to `coverpoint variable'. Do this after
 * the complete covergroup body has been parsed so a cross can precede the
 * explicit coverpoint that it names. Reuse one implicit coverpoint when the
 * same variable contributes to more than one cross. */
static void pform_covergroup_implicit_cross_coverpoints_(
      const struct vlltype&loc, class_type_t::pform_covergroup_t*cg)
{
      if (!cg) return;

      for (const auto&cross : cg->crosses) {
	    for (perm_string item : cross.cp_labels) {
		  bool declared = false;
		  for (const auto&cp : cg->coverpoints) {
			if (cp.label == item) {
			      declared = true;
			      break;
			}
		  }
		  if (declared) continue;

		  class_type_t::pform_coverpoint_t cp;
		  cp.label = item;
		  cp.expr = new PEIdent(item, loc.lexical_pos);
		  FILE_NAME(cp.expr, loc);
		  cg->coverpoints.push_back(std::move(cp));
	    }
      }
}

void pform_class_covergroup(const struct vlltype&loc,
			     const char*name,
			     std::list<class_type_t::pform_coverpoint_t*>*coverpoints,
			     std::vector<perm_string>*sample_formals,
			     std::vector<data_type_t*>*sample_formal_types,
			     std::vector<PEEvent*>*sample_events,
			     std::vector<perm_string>*ctor_formals,
			     std::vector<data_type_t*>*ctor_formal_types,
			     std::vector<PExpr*>*ctor_defaults,
			     std::vector<PExpr*>*sample_formal_defaults)
{
      if (!pform_cur_class || !name) {
	    pending_crosses_.clear();  // discard if we can't attach
	    pending_cg_options_.clear();
	    if (sample_formals) delete sample_formals;
	    if (sample_formal_types) delete sample_formal_types;
	    if (sample_formal_defaults) delete sample_formal_defaults;
	    if (sample_events) delete sample_events;
	    if (ctor_formals) delete ctor_formals;
	    if (ctor_formal_types) delete ctor_formal_types;
	    if (ctor_defaults) delete ctor_defaults;
	    return;
      }

      class_type_t::pform_covergroup_t* cg = new class_type_t::pform_covergroup_t();
      cg->name = lex_strings.make(name);
	// Constructor formals retain their declaration types/defaults so
	// the synthesized covergroup class can store per-instance values.
      if (ctor_formals) {
	    cg->ctor_formals = *ctor_formals;
	    delete ctor_formals;
      }
      if (ctor_formal_types) {
	    cg->ctor_formal_types = *ctor_formal_types;
	    delete ctor_formal_types;
      }
      if (ctor_defaults) {
	    cg->ctor_defaults = *ctor_defaults;
	    delete ctor_defaults;
      }
      if (coverpoints) {
	    for (auto* cp : *coverpoints)
		  cg->coverpoints.push_back(std::move(*cp));
	    delete coverpoints;
      }
      // I1: move accumulated cross declarations onto the covergroup.
      cg->crosses = std::move(pending_crosses_);
      pending_crosses_.clear();
      pform_covergroup_implicit_cross_coverpoints_(loc, cg);
      // M11: move accumulated covergroup-level options.
      cg->options = std::move(pending_cg_options_);
      pending_cg_options_.clear();
      // M11-4: `with function sample(<formals>)` names.
      if (sample_formals) {
	    cg->sample_formals = *sample_formals;
	    delete sample_formals;
      }
      if (sample_formal_types) {
	    cg->sample_formal_types = *sample_formal_types;
	    delete sample_formal_types;
      }
      if (sample_formal_defaults) {
	    cg->sample_formal_defaults = *sample_formal_defaults;
	    delete sample_formal_defaults;
      }
	// M11-3: declaration sampling event on a class-embedded
	// covergroup.
      if (sample_events) {
	    cg->sample_events = *sample_events;
	    delete sample_events;
      }
      pform_cur_class->type->covergroups.push_back(cg);
}

void pform_standalone_covergroup(const struct vlltype&loc,
			     const char*name,
			     std::list<class_type_t::pform_coverpoint_t*>*coverpoints,
			     std::vector<PEEvent*>*sample_events,
			     std::vector<perm_string>*sample_formals,
			     std::vector<data_type_t*>*sample_formal_types,
			     std::vector<perm_string>*ctor_formals,
			     std::vector<data_type_t*>*ctor_formal_types,
			     std::vector<PExpr*>*ctor_defaults,
			     std::vector<PExpr*>*sample_formal_defaults)
{
      if (!name) {
	    pending_crosses_.clear();
	    pending_cg_options_.clear();
	    if (sample_formals) delete sample_formals;
	    if (sample_formal_types) delete sample_formal_types;
	    if (sample_formal_defaults) delete sample_formal_defaults;
	    if (ctor_formals) delete ctor_formals;
	    if (ctor_formal_types) delete ctor_formal_types;
	    if (ctor_defaults) delete ctor_defaults;
	    return;
      }
      perm_string cg_name = lex_strings.make(name);
      PClass*cls = pform_push_class_scope(loc, cg_name);
      class_type_t*ct = new class_type_t(cg_name);
      FILE_NAME(ct, loc);
      ct->is_covergroup_standalone = true;
      cls->type = ct;
      pform_set_typedef(loc, cg_name, ct, nullptr);
	// The regular class-covergroup registration attaches the
	// covergroup (and any pending crosses/options) via
	// pform_cur_class, which only class_declaration normally
	// manages — point it at the wrapper for the call.
      PClass*save_cur = pform_cur_class;
      pform_cur_class = cls;
      pform_class_covergroup(loc, name, coverpoints, nullptr, nullptr,
			     nullptr, ctor_formals, ctor_formal_types,
			     ctor_defaults, nullptr);
      pform_cur_class = save_cur;
      if (sample_events && !ct->covergroups.empty()) {
	    ct->covergroups.back()->sample_events = *sample_events;
	    delete sample_events;
      } else if (sample_events) {
	    delete sample_events;
      }
      if (sample_formals && !ct->covergroups.empty()) {
	    ct->covergroups.back()->sample_formals = *sample_formals;
	    delete sample_formals;
      } else if (sample_formals) {
	    delete sample_formals;
      }
      if (sample_formal_types && !ct->covergroups.empty()) {
	    ct->covergroups.back()->sample_formal_types = *sample_formal_types;
	    delete sample_formal_types;
      } else if (sample_formal_types) {
	    delete sample_formal_types;
      }
      if (sample_formal_defaults && !ct->covergroups.empty()) {
	    ct->covergroups.back()->sample_formal_defaults =
		  *sample_formal_defaults;
	    delete sample_formal_defaults;
      } else if (sample_formal_defaults) {
	    delete sample_formal_defaults;
      }
      pform_pop_scope();
}
