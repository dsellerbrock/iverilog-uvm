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
# include  "netlist.h"
# include  "parse_api.h"
# include  "parse_misc.h"
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
      for (named_pexpr_t&param : pending_use.params)
	    if (param.parm)
		  param.parm->reloc_lexical_pos_bind(true);
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
static void apply_params(const rule_t&rule, const NetScope*scope,
			 map<perm_string,PExpr*>&replace)
{
      if (rule.params.empty()) {
	    replace.clear();
	    locked_scopes.insert(scope);
	    return;
      }
      for (const named_pexpr_t&param : rule.params) {
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
		  apply_params(rule, scope, replace);
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

void config_instance_scope(Design*, const PGModule*inst, const NetScope*sc,
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
	    apply_params(*cur->second.params, inst_scope, replace);
}
