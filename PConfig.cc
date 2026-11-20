/*
 * Copyright (c) 2026 Stephen Williams (steve@icarus.com)
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

/*
 * IEEE 1800 33.4 config declarations: the pform of a config, the choice of
 * the root cells, and the binding of each instance to a library cell.
 */

# include  "config.h"
# include  "PConfig.h"
# include  "compiler.h"
# include  "Module.h"
# include  "PExpr.h"
# include  "PGate.h"
# include  "PPackage.h"
# include  "netlist.h"
# include  "netmisc.h"
# include  "parse_api.h"
# include  "parse_misc.h"
# include  "pform.h"
# include  <iostream>
# include  <set>

using namespace std;

typedef PConfig::rule_t rule_t;
typedef PConfig::cell_ref_t cell_ref_t;

map<perm_string, map<perm_string,PConfig*> > pform_configs;

static map<perm_string, map<perm_string,Module*> > cells;

void config_add_cell(Module*mod)
{
      cells[mod->library][mod->cell] = mod;
}

static Module* find_cell(perm_string library, perm_string cell)
{
      map<perm_string, map<perm_string,Module*> >::const_iterator lib
	    = cells.find(library);
      if (lib == cells.end())
	    return 0;
      map<perm_string,Module*>::const_iterator cur = lib->second.find(cell);
      return cur == lib->second.end()? 0 : cur->second;
}

static PConfig* find_config(perm_string library, perm_string name)
{
      map<perm_string, map<perm_string,PConfig*> >::const_iterator lib
	    = pform_configs.find(library);
      if (lib == pform_configs.end())
	    return 0;
      map<perm_string,PConfig*>::const_iterator cur = lib->second.find(name);
      return cur == lib->second.end()? 0 : cur->second;
}

/* A config or a cell by name alone: the first library that has one. */
static PConfig* find_config(perm_string name)
{
      for (const auto&lib : pform_configs) {
	    map<perm_string,PConfig*>::const_iterator cur = lib.second.find(name);
	    if (cur != lib.second.end())
		  return cur->second;
      }
      return 0;
}

static bool cell_exists(perm_string name)
{
      for (const auto&lib : cells)
	    if (lib.second.find(name) != lib.second.end())
		  return true;
      return false;
}

static ostream& operator<< (ostream&out, const cell_ref_t&ref)
{
      if (!ref.library.nil())
	    out << ref.library << ".";
      return out << ref.cell;
}

/*
 * The parser side.
 */

static PConfig*cur_config = 0;
static rule_t pending_use;

static cell_ref_t make_cell_ref(list<perm_string>*names)
{
      cell_ref_t ref;
      if (names) {
	    ref.cell = names->back();
	    if (names->size() > 1)
		  ref.library = names->front();
	    delete names;
      }
      return ref;
}

static void config_error(const LineInfo&loc, const char*msg)
{
      cerr << loc.get_fileline() << ": error: " << msg << endl;
      error_count += 1;
}

struct config_param_expr {
      explicit config_param_expr(PExpr*expr) : root(expr) {}
      PExpr*const root;
      vector<pair<const PEIdent*, NetScope*> > refs;
      vector<const PECallFunction*> unresolved_calls;
      map<const NetScope*, bool> checked_scopes;
      const PECallFunction*invalid_call = nullptr;
      bool needs_lookup = false;
      bool diagnosed = false;
};

struct config_param_reference_t {
      config_param_expr*expr;
      bool entire_expression;
};

static list<config_param_expr> parameter_expressions;
static map<const PExpr*, config_param_expr*> parameter_overrides;
// Dotted names also represent member selects. Remember their containing
// override until symbol_search can tell whether they actually name a scope.
static map<const LineInfo*, config_param_reference_t> parameter_references;
static set<pair<const PEIdent*, const NetScope*> > searched_parameter_refs;
static map<const PExpr*, map<const NetScope*, PExpr*> > parameter_let_expansions;

PExpr** config_let_expansion_slot(const PExpr*expr, const NetScope*scope)
{
      auto expansion = parameter_let_expansions.find(expr);
      if (expansion == parameter_let_expansions.end())
	    return nullptr;
      auto use = expansion->second.find(scope);
      return use == expansion->second.end() ? nullptr : &use->second;
}

bool config_rejects_parameter_override(const PExpr*expr, const NetScope*scope)
{
      auto param = parameter_overrides.find(expr);
      if (param == parameter_overrides.end())
	    return false;
      auto checked = param->second->checked_scopes.find(scope);
      if (checked != param->second->checked_scopes.end())
	    return !checked->second;
      return param->second->invalid_call != nullptr;
}

bool config_note_parameter_search(const LineInfo*expr, const NetScope*scope,
				  const pform_scoped_name_t&path)
{
      if (!parameter_references.count(expr))
	    return false;
      const PEIdent*id = static_cast<const PEIdent*>(expr);
      if (&path == &id->path())
	    searched_parameter_refs.emplace(id, scope);
      return true;
}

bool config_check_parameter_scope(Design*des, const LineInfo*expr,
				  const NetScope*scope)
{
      auto ref = parameter_references.find(expr);
      if (ref == parameter_references.end())
	    return false;

      config_param_expr&override_expr = *ref->second.expr;
      const char*msg;
      if (scope->type() == NetScope::GENBLOCK)
	    msg = "A configuration parameter override cannot reference a generate scope";
      else if (scope->type() == NetScope::MODULE && scope->fullname().has_numbers())
	    msg = "A configuration parameter override cannot reference an instance array scope";
      else if (scope->type() == NetScope::CLASS || scope->type() == NetScope::PACKAGE
	       || ref->second.entire_expression)
	    return false;
      else
	    msg = "A hierarchical identifier must be the entire configuration parameter override expression";

      if (!override_expr.diagnosed) {
	    cerr << expr->get_fileline() << ": error: " << msg
		 << " (IEEE 1800 33.4.3)." << endl;
	    des->errors += 1;
	    override_expr.diagnosed = true;
      }
      return true;
}

static bool config_constant_system_function(const PECallFunction&call)
{
      if (call.receiver_expr() || call.path().package || call.path().size() != 1)
	    return false;

      const perm_string name = call.path().name.front().name;
      if (generation_flag >= GN_VER2023 &&
	  (name == "$timeunit" || name == "$timeprecision" || name == "$sformatf"))
	    return true;

      // The built-in constant system functions of 11.2.1. The ordinary
      // constant evaluator still checks the arguments of each call.
      static const char*const functions[] = {
	    "$rtoi", "$itor", "$realtobits", "$bitstoreal", "$shortrealtobits",
	    "$bitstoshortreal", "$signed", "$unsigned",
	    "$typename", "$bits", "$isunbounded",
	    "$dimensions", "$unpacked_dimensions", "$left", "$right", "$low",
	    "$high", "$increment", "$size",
	    "$clog2", "$ln", "$log10", "$exp", "$sqrt", "$pow", "$floor",
	    "$ceil", "$sin", "$cos", "$tan", "$asin", "$acos", "$atan", "$atan2",
	    "$hypot", "$sinh", "$cosh", "$tanh", "$asinh", "$acosh", "$atanh",
	    "$countbits", "$countones", "$onehot", "$onehot0", "$isunknown",
	    "$ivl_const_cast" // Parser representation of const'(expr).
      };
      for (const char*function : functions)
	    if (name == function)
		  return true;
      return false;
}

static bool could_be_let(const PECallFunction&call)
{
      if (call.receiver_expr() || call.path().size() != 1
	  || call.leading_type_args() || !call.with_constraints().empty())
	    return false;
      const name_component_t&name = call.path().name.front();
      return name.index.empty() && name.name[0] != '$';
}

/* Visit expressions in a use-clause override before constant folding or a
   type query can discard a subtree. A call-shaped name can be a let
   expression (11.12), so resolve those names when the use scope is known. */
class config_param_check {
    public:
      explicit config_param_check(config_param_expr&expr,
				  Design*des = nullptr, NetScope*scope = nullptr)
      : expr_(expr), des_(des), scope_(scope) {}
      bool check();

    private:
      void visit(PExpr*, bool entire_expression = false);
      void visit_type(const data_type_t*);
      void visit_args(const parmvalue_t*);
      void visit_ranges(const list<pform_range_t>*);
      void visit_index(const index_component_t&);
      void visit_pattern(const PMatchPattern*);
      template <class Expr> bool visit_let(const Expr&, bool entire_expression);

      config_param_expr&expr_;
      Design*const des_;
      NetScope*const scope_;
      int let_depth_ = 0;
      bool expand_lets_ = false;
      bool expansion_error_ = false;
};

bool config_param_check::check()
{
      if (scope_) {
	    // Check calls in source arguments even if let expansion drops
	    // an unused formal. A package-qualified name can also be a let.
	    for (const PECallFunction*call : expr_.unresolved_calls) {
		  const PPackage*pkg = call->path().package;
		  const NetScope*lookup = pkg ? des_->find_package(pkg->pscope_name())
					      : scope_;
		  const NetScope*owner = nullptr;
		  if (!lookup || !lookup->find_let(des_, peek_tail_name(call->path()),
						   call->lexical_pos(), &owner)) {
			expr_.invalid_call = call;
			return false;
		  }
	    }
      }
      visit(expr_.root, true);
      if (scope_ && !expr_.invalid_call) {
	    expand_lets_ = true;
	    visit(expr_.root, true);
      }
      return !expr_.invalid_call && !expansion_error_;
}

template <class Expr>
bool config_param_check::visit_let(const Expr&expr, bool entire_expression)
{
      if (expr.path().size() != 1 || !expr.path().name.front().index.empty())
	    return false;

      // A cell clause can use the same parse expression in different
      // parent scopes, each with its own let declaration.
      parameter_let_expansions[&expr].emplace(scope_, nullptr);
      unsigned old_errors = des_->errors;
      PExpr*sub = expr.constraint_let_substitution(des_, scope_);
      if (des_->errors != old_errors) {
	    expansion_error_ = true;
	    return true;
      }
      if (!sub)
	    return false;
      if (let_depth_ >= LET_EXPAND_DEPTH_MAX) {
	    if (!expr_.diagnosed) {
		  cerr << expr.get_fileline() << ": error: let expansion is "
		       << "too deep (recursive let?)." << endl;
		  des_->errors += 1;
		  expr_.diagnosed = true;
	    }
	    expansion_error_ = true;
	    return true;
      }
      ++let_depth_;
      visit(sub, entire_expression);
      --let_depth_;
      return true;
}

void config_param_check::visit_args(const parmvalue_t*args)
{
      if (!args) return;
      if (args->by_order)
	    for (PExpr*arg : *args->by_order)
		  visit(arg);
      if (args->by_name)
	    for (const auto&arg : *args->by_name)
		  visit(arg.parm);
}

void config_param_check::visit_ranges(const list<pform_range_t>*ranges)
{
      if (!ranges) return;
      for (const auto&range : *ranges) {
	    visit(range.first);
	    visit(range.second);
      }
}

void config_param_check::visit_type(const data_type_t*type)
{
      if (auto*ref = dynamic_cast<const type_reference_t*>(type)) {
	    visit(ref->expr);
	    visit_type(ref->named_type);
      } else if (auto*vec = dynamic_cast<const vector_type_t*>(type)) {
	    visit_ranges(vec->pdims.get());
      } else if (auto*array = dynamic_cast<const array_base_t*>(type)) {
	    visit_type(array->base_type.get());
	    visit_ranges(array->dims.get());
      } else if (auto*enm = dynamic_cast<const enum_type_t*>(type)) {
	    visit_type(enm->base_type.get());
	    if (enm->names)
		  for (const auto&item : *enm->names)
			visit(item.parm);
      } else if (auto*str = dynamic_cast<const struct_type_t*>(type)) {
	    if (str->members)
		  for (const auto*member : *str->members) {
			visit_type(member->type.get());
			for (const auto*decl : *member->names) {
			      visit_ranges(&decl->index);
			      visit(decl->expr.get());
			}
		  }
      } else if (auto*alias = dynamic_cast<const typeref_t*>(type)) {
	    visit_args(alias->parameter_values());
	    if (auto*member = dynamic_cast<const class_scoped_typeref_t*>(alias))
		  visit_type(member->qualifier());
      } else if (auto*iface = dynamic_cast<const interface_type_t*>(type)) {
	    visit_args(iface->parameter_values());
      }
}

void config_param_check::visit_index(const index_component_t&index)
{
      visit(index.msb);
      visit(index.lsb);
}

void config_param_check::visit_pattern(const PMatchPattern*pattern)
{
      if (!pattern) return;
      visit(pattern->expression());
      for (const PMatchPattern*child : pattern->children())
	    visit_pattern(child);
}

void config_param_check::visit(PExpr*expr, bool entire_expression)
{
      if (!expr || expr_.invalid_call || expansion_error_) return;
      if (auto*id = dynamic_cast<PEIdent*>(expr)) {
	    expr_.needs_lookup = true;
	    if (scope_) {
		  if (expand_lets_ && visit_let(*id, entire_expression))
			return;
		  if (id->path().size() > 1) {
			parameter_references[id] = { &expr_, entire_expression };
			expr_.refs.emplace_back(id, scope_);
			if (entire_expression)
			      id->allow_bind_parameter_reference();
		  }
	    }
	    for (const auto&component : id->path().name)
		  for (const auto&index : component.index)
			visit_index(index);
	    visit_args(id->leading_type_args());
      } else if (auto*call = dynamic_cast<PECallFunction*>(expr)) {
	    if (!config_constant_system_function(*call)) {
		  if (!could_be_let(*call)) {
			expr_.invalid_call = call;
			return;
		  }
		  if (expand_lets_) {
			if (!visit_let(*call, entire_expression))
			      expr_.invalid_call = call;
			return;
		  }
		  if (!scope_) {
			call->set_lexical_pos(UINT_MAX);
			expr_.needs_lookup = true;
			expr_.unresolved_calls.push_back(call);
		  }
	    }
	    const perm_string name = call->path().name.front().name;
	    for (const auto&arg : call->get_parms()) {
		  // The timescale queries accept $root as a scope argument.
		  if (name == "$timeunit" || name == "$timeprecision")
			if (auto*root = dynamic_cast<const PECallFunction*>(arg.parm))
			      if (!root->receiver_expr() && !root->path().package
				  && root->path().size() == 1
				  && root->path().name.front().name == "$root"
				  && root->get_parms().empty())
				    continue;
		  visit(arg.parm);
	    }
      } else if (auto*unary = dynamic_cast<PEUnary*>(expr)) {
	    visit(unary->get_expr());
      } else if (auto*binary = dynamic_cast<PEBinary*>(expr)) {
	    visit(binary->get_left());
	    visit(binary->get_right());
      } else if (auto*cond = dynamic_cast<PETernary*>(expr)) {
	    visit(cond->get_cond());
	    visit(cond->get_true());
	    visit(cond->get_false());
      } else if (auto*concat = dynamic_cast<PEConcat*>(expr)) {
	    visit(concat->repeat_expr());
	    for (PExpr*term : concat->stream_parms())
		  visit(term);
      } else if (auto*pattern = dynamic_cast<PEAssignPattern*>(expr)) {
	    visit(pattern->replication());
	    for (PExpr*term : pattern->parms())
		  visit(term);
	    for (const auto&key : pattern->keys()) {
		  visit(key.expr);
		  visit_type(key.type);
	    }
      } else if (auto*member = dynamic_cast<PEMemberAccess*>(expr)) {
	    visit(member->base());
      } else if (auto*select = dynamic_cast<PEPostSelect*>(expr)) {
	    visit(select->base());
	    visit_index(select->index());
      } else if (auto*size_cast = dynamic_cast<PECastSize*>(expr)) {
	    visit(size_cast->cast_size());
	    visit(size_cast->cast_base());
      } else if (auto*sign_cast = dynamic_cast<PECastSign*>(expr)) {
	    visit(sign_cast->cast_base());
      } else if (auto*cast = dynamic_cast<PECastType*>(expr)) {
	    visit_type(cast->cast_target());
	    visit(cast->cast_base());
      } else if (auto*type = dynamic_cast<PETypename*>(expr)) {
	    visit_type(type->get_type());
      } else if (auto*stream = dynamic_cast<PEStreaming*>(expr)) {
	    visit_type(stream->get_slice_type());
	    visit(stream->get_slice_expr());
	    visit(stream->get_inner());
      } else if (auto*with = dynamic_cast<PEStreamWith*>(expr)) {
	    visit(with->base());
	    visit(with->range_first());
	    visit(with->range_second());
      } else if (auto*inside = dynamic_cast<PEInside*>(expr)) {
	    visit(inside->get_expr());
	    for (const auto&range : inside->get_ranges()) {
		  visit(range.lo);
		  visit(range.hi);
	    }
      } else if (auto*matches = dynamic_cast<PEMatches*>(expr)) {
	    visit(matches->subject());
	    visit_pattern(matches->pattern());
	    visit(matches->conditional_tail());
      } else if (auto*index_type = dynamic_cast<PEAssocType*>(expr)) {
	    visit_type(index_type->index_type());
      }
}

void config_check_parameter_overrides(Design*des)
{
      for (const auto&expr : parameter_expressions) {
	    if (expr.diagnosed)
		  continue;
	    if (expr.invalid_call) {
		  cerr << expr.invalid_call->get_fileline()
		       << ": error: A configuration parameter override may call only"
			  " built-in constant system functions (IEEE 1800 33.4.3)."
		       << endl;
		  des->errors += 1;
		  continue;
	    }

	    // A type query can determine its result without looking up every
	    // operand. Check the scope prefixes of references that were skipped.
	    for (const auto&ref : expr.refs) {
		  if (expr.diagnosed)
			break;
		  const PEIdent*id = ref.first;
		  NetScope*scope = ref.second;
		  if (!searched_parameter_refs.emplace(id, scope).second)
			continue;
		  pform_scoped_name_t prefix = id->path();
		  prefix.name.pop_back();
		  symbol_search_results binding;
		  if (symbol_search(id, des, scope, prefix, id->lexical_pos(), &binding)
		      && binding.is_scope())
			config_check_parameter_scope(des, id, binding.scope);
	    }
      }
}

void pform_config_start(const struct vlltype&loc, const char*name)
{
      cur_config = new PConfig;
      FILE_NAME(cur_config, loc);
      cur_config->name = lex_strings.make(name);
      cur_config->library = libmap_file_library(loc.text);
}

bool pform_config_localparam(const struct vlltype&loc, perm_string name,
			     PExpr*expr)
{
      if (cur_config == 0)
	    return false;

	/* 33.4.3: a localparam of a config shall be set to a literal. */
      if (!dynamic_cast<PENumber*>(expr) && !dynamic_cast<PEString*>(expr)
	  && !dynamic_cast<PEFNumber*>(expr)) {
	    VLerror(loc, "error: localparam `%s' of a config must be set to "
		    "a literal value.", name.str());
	    return true;
      }
      if (!cur_config->localparams.insert(make_pair(name, expr)).second)
	    VLerror(loc, "error: localparam `%s' is already declared in this "
		    "config.", name.str());
      return true;
}

PExpr* pform_config_localparam_value(const pform_name_t&name)
{
      if (cur_config == 0 || name.size() != 1 || !name.front().index.empty())
	    return 0;
      map<perm_string,PExpr*>::const_iterator cur
	    = cur_config->localparams.find(name.front().name);
      return cur == cur_config->localparams.end()? 0 : cur->second;
}

void pform_config_design(const struct vlltype&, list<perm_string>*cell)
{
      cur_config->design.push_back(make_cell_ref(cell));
}

void pform_config_use(list<perm_string>*cell, bool has_params,
		      list<named_pexpr_t>*params, bool is_config)
{
      pending_use = rule_t();
      pending_use.has_use = true;
      pending_use.use = make_cell_ref(cell);
      pending_use.use_config = is_config;
      pending_use.has_params = has_params;
      if (params) {
	    pending_use.params = *params;
	    delete params;
      }
	/* 33.4.3: the overrides are elaborated in the parent scope of the
	   instance, with the identifiers that are legal in a bind statement:
	   names are not looked up by their position in this file, and a
	   hierarchical name may be a parameter. */
      for (named_pexpr_t&param : pending_use.params) {
	    if (param.parm) {
		  param.parm->reloc_lexical_pos_bind(true);
		  parameter_expressions.emplace_back(param.parm);
		  config_param_expr&expr = parameter_expressions.back();
		  config_param_check(expr).check();
		  if (expr.invalid_call || expr.needs_lookup) {
			parameter_overrides[param.parm] = &expr;
		  } else {
			parameter_expressions.pop_back();
		  }
	    }
      }
}

void pform_config_rule(const struct vlltype&loc, rule_t::select_t select,
		       pform_name_t*instance, list<perm_string>*cell,
		       list<perm_string>*liblist)
{
      rule_t rule;
      if (liblist) {
	    rule.has_liblist = true;
	    rule.liblist.assign(liblist->begin(), liblist->end());
	    delete liblist;
      } else {
	    rule = pending_use;
      }
      FILE_NAME(&rule, loc);
      rule.select = select;
      rule.cell = make_cell_ref(cell);

      if (instance) {
	    for (const name_component_t&comp : *instance) {
		  if (!comp.index.empty())
			config_error(rule, "an instance clause names instances "
				     "by identifier, without an index.");
		  rule.instance.push_back(comp.name);
	    }
	    delete instance;
      }

      if (select == rule_t::CELL && rule.has_liblist && !rule.cell.library.nil()) {
	    config_error(rule, "a cell clause that names a library cannot "
			 "have a liblist clause (IEEE 1800 33.4.1.4).");
	    return;
      }

	/* One liblist and one use clause per selection. */
      for (const rule_t&cur : cur_config->rules) {
	    if (cur.select != select || cur.has_liblist != rule.has_liblist
		|| cur.instance != rule.instance
		|| cur.cell.library != rule.cell.library
		|| cur.cell.cell != rule.cell.cell)
		  continue;
	    config_error(rule, select == rule_t::DEFAULT
			 ? "a config has at most one default liblist clause "
			   "(IEEE 1800 33.4.1.2)."
			 : "this selection clause already has a clause of "
			   "the same kind.");
	    cerr << cur.get_fileline() << ":      : The earlier clause is "
		 << "here." << endl;
	    return;
      }

      cur_config->rules.push_back(rule);
}

void pform_config_end(const struct vlltype&, const char*name)
{
      PConfig*cfg = cur_config;
      cur_config = 0;
	// A config that failed to parse is dropped.
      if (name == 0 || cfg == 0) {
	    delete cfg;
	    return;
      }

      if (cfg->design.empty())
	    config_error(*cfg, "the design statement of a config names at "
			 "least one cell.");

	/* 33.4.1.3: an instance name starts at a top-level cell of the
	   design statement. */
      for (const rule_t&rule : cfg->rules) {
	    if (rule.select != rule_t::INSTANCE)
		  continue;
	    bool found = false;
	    for (const cell_ref_t&top : cfg->design)
		  if (top.cell == rule.instance.front())
			found = true;
	    if (!found)
		  config_error(rule, "the instance name does not start with "
			       "a cell of the design statement.");
      }

      PConfig*&slot = pform_configs[cfg->library][cfg->name];
      if (slot) {
	    config_error(*cfg, "this config is already declared.");
	    cerr << slot->get_fileline() << ":      : It was declared here."
		 << endl;
	    return;
      }
      slot = cfg;
}

/*
 * The root cells.
 */

static map<const Module*,const PConfig*> root_config;

/* The config that a use clause names, when the library of the parent cell
   is not known yet. */
static const PConfig* used_config(const rule_t&rule)
{
      if (!rule.has_use || rule.use.cell.nil())
	    return 0;
      if (!rule.use.library.nil()) {
	    if (!rule.use_config && find_cell(rule.use.library, rule.use.cell))
		  return 0;
	    return find_config(rule.use.library, rule.use.cell);
      }
      if (!rule.use_config && cell_exists(rule.use.cell))
	    return 0;
      return find_config(rule.use.cell);
}

int config_select_roots(list<perm_string>&roots)
{
      if (pform_configs.empty())
	    return 0;

      vector<const PConfig*> tops;
      if (roots.empty()) {
	      /* 33.5.4: a config in the source files makes the cells of
		 its design statement the top-level cells. A config that
		 another config uses configures a part of that design. */
	    set<const PConfig*> used;
	    for (const auto&lib : pform_configs)
		  for (const auto&cfg : lib.second)
			for (const rule_t&rule : cfg.second->rules)
			      if (const PConfig*sub = used_config(rule))
				    used.insert(sub);
	    for (const auto&lib : pform_configs)
		  for (const auto&cfg : lib.second)
			if (used.find(cfg.second) == used.end())
			      tops.push_back(cfg.second);
      } else {
	      /* -s NAME selects a config if NAME is not a module. */
	    list<perm_string> keep;
	    for (perm_string name : roots) {
		  const PConfig*cfg = pform_modules.find(name) == pform_modules.end()
			? find_config(name) : 0;
		  if (cfg)
			tops.push_back(cfg);
		  else
			keep.push_back(name);
	    }
	    roots = keep;
      }

      int errors = 0;
      set<perm_string> root_names;
      for (const PConfig*cfg : tops) {
	    for (const cell_ref_t&ref : cfg->design) {
		  perm_string library = ref.library.nil()? cfg->library : ref.library;
		  Module*mod = find_cell(library, ref.cell);
		  if (mod == 0) {
			cerr << cfg->get_fileline() << ": error: config "
			     << cfg->name << ": design cell " << library << "."
			     << ref.cell << " not found";
			if (find_config(library, ref.cell))
			      cerr << " (a design cell cannot be a config, "
				   << "IEEE 1800 33.4.1.1)";
			cerr << "." << endl;
			errors += 1;
			continue;
		  }
		  if (!root_names.insert(mod->cell).second) {
			cerr << cfg->get_fileline() << ": error: config "
			     << cfg->name << ": top-level cell " << mod->cell
			     << " is configured more than once; select "
			     << "one config with -s." << endl;
			errors += 1;
			continue;
		  }
		  root_config[mod] = cfg;
		  roots.push_back(mod->mod_name());
	    }
      }
      return errors;
}

/*
 * Binding.
 */

/* What a module instance scope inherits from its configuration. */
struct context_t {
      const PConfig*cfg = 0;
	/* The instance name as the config writes it: the top-level cell,
	   then the instance names. Empty if the scope cannot be named
	   (33.4.1.3 has no notation for generate scopes or array elements). */
      vector<perm_string> path;
	/* The library list (33.4.1.5). */
      vector<perm_string> liblist;
};

struct binding_t {
      Module*mod = 0;
      context_t context;
      const rule_t*params = 0;
};

static map<const NetScope*,context_t> scope_context;
static map<pair<const NetScope*,const PGModule*>,binding_t> bindings;
static set<pair<const NetScope*,const PGModule*> > reported;
static map<pair<const NetScope*,const PGModule*>,
	   pair<const PConfig*,vector<perm_string> > > unbound;
static map<const NetScope*,set<perm_string> > locked_params;
static set<const NetScope*> locked_scopes;

static context_t top_context(const PConfig*cfg, perm_string top)
{
      context_t res;
      res.cfg = cfg;
      res.path.push_back(top);
      for (const rule_t&rule : cfg->rules)
	    if (rule.select == rule_t::DEFAULT)
		  res.liblist = rule.liblist;
      return res;
}

/* 33.4.3: the named overrides of a use clause. #() sets all the parameters
   back to their defaults and .P() sets P back. */
static void apply_params(Design*des, const rule_t&rule, NetScope*scope,
			 map<perm_string,PExpr*>&replace)
{
      if (rule.params.empty()) {
	    replace.clear();
	    locked_scopes.insert(scope);
	    return;
      }
      for (const named_pexpr_t&param : rule.params) {
	    auto check = parameter_overrides.find(param.parm);
	    if (check != parameter_overrides.end() && !check->second->invalid_call) {
		  config_param_expr&expr = *check->second;
		  NetScope*use_scope = scope->parent();
		  if (!use_scope)
			use_scope = scope->unit();
		  if (use_scope) {
			auto entry = expr.checked_scopes.emplace(use_scope, false);
			if (entry.second)
			      entry.first->second =
				    config_param_check(expr, des, use_scope).check();
		  }
	    }
	    if (param.parm)
		  replace[param.name] = param.parm;
	    else
		  replace.erase(param.name);
	    locked_params[scope].insert(param.name);
      }
}

bool config_param_locked(const NetScope*scope, perm_string name)
{
      if (locked_scopes.find(scope) != locked_scopes.end())
	    return true;
      map<const NetScope*,set<perm_string> >::const_iterator cur
	    = locked_params.find(scope);
      return cur != locked_params.end()
	  && cur->second.find(name) != cur->second.end();
}

void config_root_scope(Design*des, NetScope*scope, const Module*mod,
		       map<perm_string,PExpr*>&replace)
{
      map<const Module*,const PConfig*>::const_iterator cur
	    = root_config.find(mod);
      if (cur == root_config.end())
	    return;

      const PConfig*cfg = cur->second;
      context_t context = top_context(cfg, mod->cell);

	/* Clauses that select the top-level instance itself. */
      for (const rule_t&rule : cfg->rules) {
	    if (rule.select != rule_t::INSTANCE || rule.instance != context.path)
		  continue;
	    if (rule.has_liblist) {
		  context.liblist = rule.liblist;
	    } else if (!rule.use.cell.nil()) {
		  cerr << rule.get_fileline() << ": error: the design "
		       << "statement binds top-level cell " << mod->cell
		       << "; a use clause cannot bind it again." << endl;
		  des->errors += 1;
	    } else if (rule.has_params) {
		  apply_params(des, rule, scope, replace);
	    }
      }
      scope_context[scope] = context;
}

/* What an instance inherits. It has a name in the config if it is declared
   directly in a module that has one, and is not an array. */
static context_t child_context(const context_t&parent, const PGModule*inst,
			       bool in_module)
{
      context_t res;
      res.cfg = parent.cfg;
      res.liblist = parent.liblist;
      if (in_module && !parent.path.empty() && !inst->is_array()) {
	    res.path = parent.path;
	    res.path.push_back(inst->get_name());
      }
      return res;
}

/* The context of the module instance that contains scope SC. */
static const context_t* enclosing_context(const NetScope*sc,
					  const NetScope*&parent)
{
      parent = sc;
      while (parent && parent->type() != NetScope::MODULE)
	    parent = parent->parent();
      map<const NetScope*,context_t>::const_iterator cur
	    = scope_context.find(parent);
      return cur == scope_context.end()? 0 : &cur->second;
}

bool config_bind(Design*des, const PGModule*inst, const NetScope*sc,
		 perm_string type, Module*&mod)
{
      if (scope_context.empty())
	    return false;

      const NetScope*parent;
      const context_t*ctx = enclosing_context(sc, parent);
      if (ctx == 0)
	    return false;

      pair<const NetScope*,const PGModule*> key (sc, inst);
      map<pair<const NetScope*,const PGModule*>,binding_t>::const_iterator
	    known = bindings.find(key);
      if (known != bindings.end()) {
	    mod = known->second.mod;
	    return true;
      }

      const PConfig*cfg = ctx->cfg;
      perm_string parent_library = parent->module_definition()->library;

      binding_t res;
      res.context = child_context(*ctx, inst, sc == parent);

	/* The selection clauses, most specific first: instance, cell with
	   a library, cell, default. The default liblist is already in the
	   inherited list. */
      const rule_t*liblist_rule = 0;
      const rule_t*use_rule = 0;
      const rule_t*cell_use_rule = 0;
      for (const rule_t&rule : cfg->rules) {
	    if (rule.select != rule_t::INSTANCE || res.context.path.empty()
		|| rule.instance != res.context.path)
		  continue;
	    (rule.has_liblist? liblist_rule : use_rule) = &rule;
      }
      for (const rule_t&rule : cfg->rules) {
	    if (rule.select != rule_t::CELL || !rule.cell.library.nil()
		|| rule.cell.cell != type)
		  continue;
	    if (rule.has_liblist && !liblist_rule) liblist_rule = &rule;
	    if (rule.has_use) cell_use_rule = &rule;
      }
      if (liblist_rule)
	    res.context.liblist = liblist_rule->liblist;

	/* 33.4.1.5: search the library list; an empty list stands for
	   the library of the parent cell. */
      vector<perm_string> search = res.context.liblist;
      if (search.empty())
	    search.push_back(parent_library);
      for (perm_string library : search) {
	    res.mod = find_cell(library, type);
	    if (res.mod) break;
      }

	/* 33.4.1.4: a cell clause with a library selects an instance that
	   is about to be bound to that library and cell. */
      if (!use_rule && res.mod) {
	    for (const rule_t&rule : cfg->rules)
		  if (rule.select == rule_t::CELL && rule.has_use
		      && rule.cell.cell == type
		      && rule.cell.library == res.mod->library) {
			use_rule = &rule;
			break;
		  }
      }
      if (!use_rule)
	    use_rule = cell_use_rule;

      bool error = false;
      if (use_rule) {
	    if (use_rule->has_params)
		  res.params = use_rule;
	    if (!use_rule->use.cell.nil()) {
		    /* 33.4.1.6: the exact library and cell; without a
		       library name, the library of the parent cell. */
		  cell_ref_t use = use_rule->use;
		  if (use.library.nil())
			use.library = parent_library;
		  res.mod = use_rule->use_config? 0 : find_cell(use.library, use.cell);
		  const PConfig*sub = res.mod? 0 : find_config(use.library, use.cell);
		  if (sub) {
			  /* 33.4.2: the design statement of the config
			     binds the instance and its rules bind what
			     is below. No rule of this config may reach
			     into that hierarchy. */
			for (const rule_t&rule : cfg->rules) {
			      const vector<perm_string>&here = res.context.path;
			      if (rule.select != rule_t::INSTANCE || here.empty()
				  || rule.instance.size() <= here.size()
				  || !equal(here.begin(), here.end(), rule.instance.begin()))
				    continue;
			      cerr << rule.get_fileline() << ": error: the "
				   << "instance clause names an instance in "
				   << "the hierarchy that config " << sub->name
				   << " configures (IEEE 1800 33.4.2)." << endl;
			      error = true;
			}
			if (sub->design.size() != 1) {
			      cerr << use_rule->get_fileline() << ": error: "
				   << "config " << sub->name << " is bound to "
				   << "an instance, so its design statement "
				   << "must name one cell." << endl;
			      error = true;
			} else {
			      cell_ref_t top = sub->design[0];
			      if (top.library.nil())
				    top.library = sub->library;
			      res.mod = find_cell(top.library, top.cell);
			      res.context = top_context(sub, top.cell);
			}
		  }
		  if (res.mod == 0 && !error) {
			cerr << use_rule->get_fileline() << ": error: the use "
			     << "clause names " << use
			     << (use_rule->use_config? ":config" : "")
			     << ", which is not found." << endl;
			error = true;
		  }
	    }
      }

      if (error && reported.insert(key).second)
	    des->errors += 1;

	/* An unbound instance is looked up again after a -y search. */
      if (res.mod)
	    bindings[key] = res;
      else if (!error)
	    unbound[key] = make_pair(cfg, search);
      mod = res.mod;
      return true;
}

void config_explain_unbound(const PGModule*inst, const NetScope*sc)
{
      auto cur = unbound.find(make_pair(sc, inst));
      if (cur == unbound.end())
	    return;
      cerr << inst->get_fileline() << ":      : config "
	   << cur->second.first->name << " searched the libraries:";
      for (perm_string library : cur->second.second)
	    cerr << " " << library;
      cerr << endl;
}

void config_instance_scope(Design*des, const PGModule*inst, const NetScope*sc,
			   NetScope*inst_scope,
			   map<perm_string,PExpr*>&replace)
{
      map<pair<const NetScope*,const PGModule*>,binding_t>::const_iterator
	    cur = bindings.find(make_pair(sc, inst));
      if (cur == bindings.end()) {
	      /* A nested module is not a library cell, but the instances
		 below it are still configured. */
	    const NetScope*parent;
	    if (const context_t*ctx = enclosing_context(sc, parent))
		  scope_context[inst_scope] = child_context(*ctx, inst, sc == parent);
	    return;
      }

      scope_context[inst_scope] = cur->second.context;
      if (cur->second.params)
	    apply_params(des, *cur->second.params, inst_scope, replace);
}
