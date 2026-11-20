#ifndef IVL_PConfig_H
#define IVL_PConfig_H
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

# include  "LineInfo.h"
# include  "StringHeap.h"
# include  "pform_types.h"
# include  <list>
# include  <map>
# include  <vector>

class Design;
class Module;
class NetScope;
class PExpr;
class PGModule;

/*
 * A config declaration (IEEE 1800 33.4): the rules that select the library
 * cell each instance of a design is bound to.
 */
class PConfig : public LineInfo {

    public:
	/* [library.]cell. A nil library means "not given". */
      struct cell_ref_t {
	    perm_string library;
	    perm_string cell;
      };

	/* One config_rule_statement: a selection clause (default, instance
	   or cell) with a liblist clause or a use clause. */
      struct rule_t : public LineInfo {
	    enum select_t { DEFAULT, INSTANCE, CELL };
	    select_t select = DEFAULT;
	    std::vector<perm_string> instance;  // top cell, then instance names
	    cell_ref_t cell;

	    bool has_liblist = false;
	    std::vector<perm_string> liblist;

	    bool has_use = false;
	    cell_ref_t use;         // use.cell is nil for a parameters-only use
	    bool use_config = false; // use ... :config
	    bool has_params = false; // use #(...); an empty list is #()
	    std::list<named_pexpr_t> params;
      };

      perm_string name;
      perm_string library;
      std::map<perm_string,PExpr*> localparams;
      std::vector<cell_ref_t> design;
      std::vector<rule_t> rules;
};

/* All the configs, by library and then by name. A config may have the
   name of a module of the same library (33.2.1). */
extern std::map<perm_string, std::map<perm_string,PConfig*> > pform_configs;

/*
 * The parser builds a config with these calls. A reference to a cell is a
 * list of one (cell) or two (library, cell) names.
 */
struct vlltype;
extern void pform_config_start(const struct vlltype&loc, const char*name);
extern void pform_config_design(const struct vlltype&loc,
				std::list<perm_string>*cell);
  /* The use clause of the rule that pform_config_rule() is about to add. */
extern void pform_config_use(std::list<perm_string>*cell, bool has_params,
			     std::list<named_pexpr_t>*params, bool is_config);
  /* LIBLIST is nil for a rule with a use clause. */
extern void pform_config_rule(const struct vlltype&loc,
			      PConfig::rule_t::select_t select,
			      pform_name_t*instance,
			      std::list<perm_string>*cell,
			      std::list<perm_string>*liblist);
  /* NAME is nil for a config with a syntax error, which is dropped. */
extern void pform_config_end(const struct vlltype&loc, const char*name);
  /* A localparam declaration is for the config being parsed, if any. */
extern bool pform_config_localparam(const struct vlltype&loc,
				    perm_string name, PExpr*expr);
  /* The literal that a localparam of the config being parsed stands for. */
extern PExpr* pform_config_localparam_value(const pform_name_t&name);

/* The cells that can be bound, by library and cell name. */
extern void config_add_cell(Module*mod);

/*
 * 33.5.4: turn the configs that are selected (by -s, or by being in the
 * source files) into root cells. Returns the number of errors.
 */
extern int config_select_roots(std::list<perm_string>&roots);

/*
 * Elaboration. config_root_scope() and config_instance_scope() are called
 * when the scope of a root cell or of an instance is created; they add the
 * parameter overrides of the config to REPLACE. config_bind() returns true
 * if a config decides the binding of an instance in scope SC; MOD is then
 * the bound cell, or nil if there is none.
 */
extern void config_root_scope(Design*des, NetScope*scope, const Module*mod,
			      std::map<perm_string,PExpr*>&replace);
extern bool config_bind(Design*des, const PGModule*inst, const NetScope*sc,
			perm_string type, Module*&mod);
  /* Says where a config looked for the cell of an instance left unbound. */
extern void config_explain_unbound(const PGModule*inst, const NetScope*sc);
extern void config_instance_scope(Design*des, const PGModule*inst,
				  const NetScope*sc, NetScope*inst_scope,
				  std::map<perm_string,PExpr*>&replace);
  /* 33.4.3: a config override takes precedence over a defparam. */
extern bool config_param_locked(const NetScope*scope, perm_string name);
  /* 33.4.3: restrictions on the expressions in config parameter overrides. */
extern bool config_rejects_parameter_override(const PExpr*expr, const NetScope*scope);
extern PExpr** config_let_expansion_slot(const PExpr*expr, const NetScope*scope);
extern bool config_note_parameter_search(const LineInfo*expr, const NetScope*scope,
					 const pform_scoped_name_t&path);
extern bool config_check_parameter_scope(Design*des, const LineInfo*expr,
					const NetScope*scope);
extern void config_check_parameter_overrides(Design*des);

#endif /* IVL_PConfig_H */
