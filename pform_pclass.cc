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
# include  <sstream>
# include  <vector>
# include  "pform.h"
# include  "PClass.h"
# include  "PExpr.h"
# include  "PTask.h"
# include  "parse_misc.h"
# include  "ivl_assert.h"

using namespace std;

/*
 * The functions here help the parser put together class type declarations.
 * pform_class_stack_ supports nested class declarations; pform_cur_class
 * always points to the innermost class being parsed (top of the stack).
 */
static vector<PClass*> pform_class_stack_;
static PClass*pform_cur_class = 0;
static bool pform_next_method_is_pure_virtual_ = false;

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
extern std::vector<class_type_t::iface_ref_t> pending_implements_list_;
extern std::vector<class_type_t::iface_ref_t> pending_extends_extra_;

/*
 * S7: lookup helper.  Walk up the lexical scope chain from `from_scope`
 * looking for a class with the given name registered in any enclosing
 * scope's `classes` map.  Returns nullptr if not found.
 */
static PClass* lookup_class_by_name_(LexicalScope*from_scope, perm_string name)
{
      LexicalScope*scope = from_scope;
      while (scope) {
            PScopeExtra*sx = dynamic_cast<PScopeExtra*>(scope);
            if (sx) {
                  auto it = sx->classes.find(name);
                  if (it != sx->classes.end()) return it->second;
            }
            scope = scope->parent_scope();
      }
      return nullptr;
}

/*
 * S7: collect pure-virtual method signatures (name + return-type-name)
 * from a given class scope.  Returns a map of name → typeref-string.
 * Used by the implements-conflict check.
 */
static std::map<perm_string, std::string>
collect_pure_virtual_signatures_(PClass*ifc)
{
      std::map<perm_string, std::string> sigs;
      if (!ifc) return sigs;
      // Collect from this class's funcs (return-typed methods).
      for (auto&it : ifc->funcs) {
            if (it.second && it.second->is_pure_virtual()) {
                  // Use the function's return-type name as the signature.
                  std::ostringstream os;
                  if (auto*rt = it.second->get_return_type()) {
                        os << *rt;
                  } else {
                        os << "<no-return-type>";
                  }
                  sigs[it.first] = os.str();
            }
      }
      // Tasks have no return type so we don't conflict-check those.
      // Recurse into base interface (if it's an interface class).
      if (ifc->type && ifc->type->is_interface_class) {
            // base_type
            if (typeref_t*tr = dynamic_cast<typeref_t*>(ifc->type->base_type.get())) {
                  if (tr->typedef_ref()) {
                        PClass*base_pc = lookup_class_by_name_(ifc, tr->typedef_ref()->name);
                        if (base_pc) {
                              auto base_sigs = collect_pure_virtual_signatures_(base_pc);
                              for (auto&p : base_sigs) {
                                    if (sigs.find(p.first) == sigs.end())
                                          sigs[p.first] = p.second;
                              }
                        }
                  }
            }
            // extends_extra
            for (auto&ref : ifc->type->extends_extra) {
                  PClass*ex_pc = lookup_class_by_name_(ifc, ref.name);
                  if (ex_pc) {
                        auto base_sigs = collect_pure_virtual_signatures_(ex_pc);
                        for (auto&p : base_sigs) {
                              if (sigs.find(p.first) == sigs.end())
                                    sigs[p.first] = p.second;
                        }
                  }
            }
      }
      return sigs;
}

/*
 * S7: walk full ancestor chain (recursively) and record (name, args)
 * pairs.  Args are serialized to a textual signature so that
 * different specializations (ibase#(bit) vs ibase#(string)) compare
 * as distinct.
 */
struct ancestor_visit_t {
      perm_string name;
      std::string args_sig;
};

static std::string serialize_typeref_args_(typeref_t*tr)
{
      std::ostringstream os;
      const parmvalue_t*pv = tr ? tr->parameter_values() : nullptr;
      if (pv && pv->by_order) {
            os << "<" << pv->by_order->size() << ":";
            for (auto*e : *pv->by_order) {
                  if (PETypename*tn = dynamic_cast<PETypename*>(e)) {
                        // Dump the contained data_type more concretely
                        // so different types (bit vs string) compare distinct.
                        if (tn->get_type()) {
                              os << typeid(*tn->get_type()).name();
                              // For atom types, the type-tag distinguishes
                              // signed int vs unsigned bit etc.; that's
                              // enough for our diamond check.
                        } else {
                              os << "?";
                        }
                  } else if (e) {
                        e->dump(os);
                  }
                  os << ",";
            }
            os << ">";
      } else if (pv && pv->by_name) {
            os << "<n" << pv->by_name->size() << ">";
      }
      return os.str();
}

static void collect_ancestors_(PClass*ifc,
                               std::vector<ancestor_visit_t>&out)
{
      if (!ifc || !ifc->type || !ifc->type->is_interface_class) return;
      if (typeref_t*tr = dynamic_cast<typeref_t*>(ifc->type->base_type.get())) {
            if (tr->typedef_ref()) {
                  ancestor_visit_t v;
                  v.name = tr->typedef_ref()->name;
                  v.args_sig = serialize_typeref_args_(tr);
                  out.push_back(v);
                  PClass*base_pc = lookup_class_by_name_(ifc, v.name);
                  if (base_pc) collect_ancestors_(base_pc, out);
            }
      }
      for (auto&ref : ifc->type->extends_extra) {
            ancestor_visit_t v;
            v.name = ref.name;
            v.args_sig = "<" + std::to_string(ref.args.size()) + ":>";
            out.push_back(v);
            PClass*pc = lookup_class_by_name_(ifc, ref.name);
            if (pc) collect_ancestors_(pc, out);
      }
}

/*
 * S7: run interface class semantic checks on the just-finished class
 * declaration.  Currently catches:
 *  - implements with conflicting same-name pure-virtual return types
 *  - interface-class diamond with same ancestor at different
 *    specialization arg counts
 *  - parametrized interface class extending two parametrized
 *    interfaces with the same type-parameter name (per LRM 8.26.6.2)
 */
static void check_interface_class_conflicts_(PClass*pc)
{
      if (!pc || !pc->type) return;
      class_type_t*ct = pc->type;

      // Check 1 (LRM 8.26.6.1): regular class implementing multiple
      // interfaces with conflicting same-name pure-virtual methods.
      if (!ct->is_interface_class && !ct->implements_list.empty()) {
            std::map<perm_string, std::string> all_sigs;
            for (auto&ref : ct->implements_list) {
                  PClass*ifc = lookup_class_by_name_(pc, ref.name);
                  if (!ifc) continue;
                  auto sigs = collect_pure_virtual_signatures_(ifc);
                  for (auto&p : sigs) {
                        auto found = all_sigs.find(p.first);
                        if (found != all_sigs.end() && found->second != p.second) {
                              cerr << pc->get_fileline() << ": error: class `"
                                   << pc->pscope_name() << "' implements multiple"
                                   << " interface classes that declare method `"
                                   << p.first << "' with conflicting return types: `"
                                   << found->second << "' vs `" << p.second
                                   << "'.  IEEE 1800-2017 §8.26.6.1: this conflict"
                                   << " must be explicitly resolved." << endl;
                              error_count++;
                              return;
                        }
                        all_sigs[p.first] = p.second;
                  }
            }
      }

      // Check 2 (LRM 8.26.6.3): interface class diamond inheritance with
      // different specializations.  Walk full ancestor chain; if the
      // same ancestor name appears multiple times with different arg
      // counts (different specializations), error.
      if (ct->is_interface_class
          && (ct->base_type.get() != nullptr || !ct->extends_extra.empty())) {
            std::vector<ancestor_visit_t> ancestors;
            collect_ancestors_(pc, ancestors);
            std::map<perm_string, std::string> seen;
            for (auto&v : ancestors) {
                  auto it = seen.find(v.name);
                  if (it != seen.end() && it->second != v.args_sig) {
                        cerr << pc->get_fileline() << ": error: interface class `"
                             << pc->pscope_name() << "' has ancestor `"
                             << v.name << "' with conflicting specializations"
                             << " (`" << it->second << "' vs `"
                             << v.args_sig << "').  IEEE 1800-2017 §8.26.6.3:"
                             << " different specializations are unique types."
                             << endl;
                        error_count++;
                        return;
                  }
                  seen[v.name] = v.args_sig;
            }
      }

      // Check 3 (LRM 8.26.6.2): parametrized interface class extending
      // multiple parametrized interface classes with the same
      // type-parameter name in their port lists.  Detected when
      // extends_extra has 1+ entries AND multiple parents declare a
      // type parameter with the same name AND the derived class
      // doesn't redeclare that parameter to disambiguate.
      if (ct->is_interface_class && !ct->extends_extra.empty()) {
            // Collect type-parameter names from each parent.
            std::map<perm_string, int> tparam_counts;
            auto collect_parent_tparams = [&](perm_string parent_name) {
                  PClass*pp = lookup_class_by_name_(pc, parent_name);
                  if (!pp || !pp->type) return;
                  // The class's parameters are tracked via its scope's
                  // parameter map.
                  for (auto&pp_param : pp->parameters) {
                        if (pp_param.second && pp_param.second->type_flag) {
                              tparam_counts[pp_param.first]++;
                        }
                  }
            };
            // base_type (first parent)
            if (typeref_t*tr = dynamic_cast<typeref_t*>(ct->base_type.get())) {
                  if (tr->typedef_ref())
                        collect_parent_tparams(tr->typedef_ref()->name);
            }
            for (auto&ref : ct->extends_extra)
                  collect_parent_tparams(ref.name);
            // If any tparam name appears in 2+ parents AND this class
            // doesn't redeclare it (as a parameter OR a typedef), error.
            for (auto&p : tparam_counts) {
                  if (p.second < 2) continue;
                  bool resolved = pc->parameters.find(p.first) != pc->parameters.end()
                               || pc->typedefs.find(p.first) != pc->typedefs.end();
                  if (!resolved) {
                        cerr << pc->get_fileline() << ": error: interface class `"
                             << pc->pscope_name() << "' extends multiple"
                             << " parametrized interfaces that share type"
                             << " parameter name `" << p.first << "' but"
                             << " does not redeclare it.  IEEE 1800-2017"
                             << " §8.26.6.2: type parameter conflicts must"
                             << " be resolved by the derived class." << endl;
                        error_count++;
                        return;
                  }
            }
      }
}

void pform_start_class_declaration(const struct vlltype&loc,
				   class_type_t*type,
				   data_type_t*base_type,
				   list<named_pexpr_t> *base_args,
				   bool virtual_class)
{
      PClass*class_scope = pform_push_class_scope(loc, type->name);
      class_scope->type = type;
      pform_class_stack_.push_back(pform_cur_class);
      pform_cur_class = class_scope;

      ivl_assert(loc, type->base_type == 0);
      type->base_type.reset(base_type);
      type->virtual_class = virtual_class;


      ivl_assert(loc, type->base_args.empty());
      if (base_args) {
	    type->base_args.insert(type->base_args.begin(), base_args->begin(),
			           base_args->end());
	    delete base_args;
      }

      // S7: drain pending implements / extends-extra lists into this class.
      // For interface classes, extra `extends` parents go through
      // implements_class_list (grammar reuse) — route them to
      // extends_extra.  For regular classes, implements_class_list
      // entries are actual `implements` interfaces.
      if (type->is_interface_class) {
            type->extends_extra = std::move(pending_implements_list_);
      } else {
            type->implements_list = std::move(pending_implements_list_);
      }
      pending_implements_list_.clear();
      pending_extends_extra_.clear();
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

	    if (PExpr*rval = curp->expr.release()) {
		  PExpr*lval = new PEIdent(curp->name.first, curp->name.second);
		  FILE_NAME(lval, loc);
		  PAssign*tmp = new PAssign(lval, rval);
		  FILE_NAME(tmp, loc);

		  if (property_qual.test_static())
			pform_cur_class->type->initialize_static.push_back(tmp);
		  else
			pform_cur_class->type->initialize.push_back(tmp);
	    }
      }
}

static PTaskFunc* pform_recent_class_method_ = 0;

void pform_set_this_class(const struct vlltype&loc, PTaskFunc*net)
{
      if (pform_cur_class == 0)
	    return;

      /* IEEE 1800-2017 §18.6.3/§18.8/§18.9: randomize(), rand_mode(), and
       * constraint_mode() are built-in methods that cannot be overridden. */
      static const char* const builtin_no_override[] = {
	    "randomize", "rand_mode", "constraint_mode", nullptr
      };
      const char* mname = net->pscope_name();
      for (int bi = 0; builtin_no_override[bi]; ++bi) {
	    if (strcmp(mname, builtin_no_override[bi]) == 0) {
		  cerr << loc << ": error: method `" << mname
		       << "' is a built-in method and cannot be overridden."
		       << endl;
		  error_count += 1;
		  break;
	    }
      }

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
      if (pform_next_method_is_pure_virtual_) {
	    net->set_pure_virtual();
	    pform_next_method_is_pure_virtual_ = false;
      }
      pform_recent_class_method_ = net;
}

void pform_mark_recent_class_method_virtual(void)
{
      if (pform_recent_class_method_)
	    pform_recent_class_method_->set_virtual_method(true);
      pform_recent_class_method_ = 0;
}

void pform_mark_next_method_pure_virtual(void)
{
      pform_next_method_is_pure_virtual_ = true;
}

void pform_set_constructor_return(PFunction*net)
{
      ivl_assert(*net, pform_cur_class);
      net->set_return(pform_cur_class->type);
}

bool pform_reenter_class_scope(const struct vlltype&loc, const char*name)
{
      (void)loc;
      for (LexicalScope*scope = pform_peek_scope(); scope; scope = scope->parent_scope()) {
	    PScopeExtra*scopex = dynamic_cast<PScopeExtra*>(scope);
	    if (scopex == 0)
		  continue;

	    for (auto it = scopex->classes.begin(); it != scopex->classes.end(); ++it) {
		  if (std::strcmp(it->first, name) != 0)
			continue;

		  pform_class_stack_.push_back(pform_cur_class);
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

      if (!pform_class_stack_.empty()) {
	    pform_cur_class = pform_class_stack_.back();
	    pform_class_stack_.pop_back();
      } else {
	    pform_cur_class = 0;
      }
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

      // Pure virtual methods are only allowed in virtual classes (8.21)
      if (!pform_cur_class->type->virtual_class) {
	    for (auto&it : pform_cur_class->tasks) {
		  if (it.second->is_pure_virtual()) {
			cerr << it.second->get_file() << ":"
			     << it.second->get_lineno() << ": error: "
			     << "pure virtual method `" << it.first
			     << "' declared in non-virtual class `"
			     << pform_cur_class->pscope_name() << "'." << endl;
			error_count += 1;
		  }
	    }
	    for (auto&it : pform_cur_class->funcs) {
		  if (it.second->is_pure_virtual()) {
			cerr << it.second->get_file() << ":"
			     << it.second->get_lineno() << ": error: "
			     << "pure virtual method `" << it.first
			     << "' declared in non-virtual class `"
			     << pform_cur_class->pscope_name() << "'." << endl;
			error_count += 1;
		  }
	    }
      }

      // S7: run interface class semantic checks before popping.
      check_interface_class_conflicts_(pform_cur_class);

      if (!pform_class_stack_.empty()) {
	    pform_cur_class = pform_class_stack_.back();
	    pform_class_stack_.pop_back();
      } else {
	    pform_cur_class = 0;
      }
      pform_pop_scope();
}

bool pform_in_class()
{
      return pform_cur_class != 0;
}

bool pform_in_virtual_class()
{
      return pform_cur_class != 0 && pform_cur_class->type->virtual_class;
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

void pform_class_constraint(const struct vlltype& /*loc*/,
			     bool /*is_static*/,
			     const char*name,
			     std::list<PExpr*>*items)
{
      if (!pform_cur_class || !name)
	    return;

      perm_string pname = lex_strings.make(name);
      vector<PExpr*>& slot = pform_cur_class->type->constraints[pname];
      if (items) {
	    slot.assign(items->begin(), items->end());
	    delete items;
      }
}

// I1 (Phase 62g): forward-declared accumulator from parse.y.
extern std::vector<class_type_t::pform_cross_t> pending_crosses_;

void pform_class_covergroup(const struct vlltype& /*loc*/,
			     const char*name,
			     std::list<class_type_t::pform_coverpoint_t*>*coverpoints)
{
      if (!pform_cur_class || !name) {
	    pending_crosses_.clear();  // discard if we can't attach
	    return;
      }

      class_type_t::pform_covergroup_t* cg = new class_type_t::pform_covergroup_t();
      cg->name = lex_strings.make(name);
      if (coverpoints) {
	    for (auto* cp : *coverpoints)
		  cg->coverpoints.push_back(std::move(*cp));
	    delete coverpoints;
      }
      // I1: move accumulated cross declarations onto the covergroup.
      cg->crosses = std::move(pending_crosses_);
      pending_crosses_.clear();
      pform_cur_class->type->covergroups.push_back(cg);
}
