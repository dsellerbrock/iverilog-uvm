/*
 * Copyright (c) 1998-2026 Stephen Williams (steve@icarus.com)
 * Copyright CERN 2013 / Stephen Williams (steve@icarus.com)
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

# include  <cstdarg>
# include  "compiler.h"
# include  "pform.h"
# include  "parse_misc.h"
# include  "parse_api.h"
# include  "PClass.h"
# include  "PEvent.h"
# include  "PPackage.h"
# include  "PUdp.h"
# include  "PGenerate.h"
# include  "PModport.h"
# include  "PSpec.h"
# include  "PTask.h"
# include  "Statement.h"
# include  "PTimingCheck.h"
# include  "discipline.h"
# include  <list>
# include  <map>
# include  <cassert>
# include  <stack>
# include  <typeinfo>
# include  <sstream>
# include  <cstring>
# include  <cstdlib>
# include  <cctype>

# include  "ivl_assert.h"
# include  "ivl_alloc.h"

using namespace std;

/*
 * The "// synthesis translate_on/off" meta-comments cause this flag
 * to be turned off or on. The pform_make_behavior and similar
 * functions look at this flag and may choose to add implicit ivl
 * synthesis flags.
 */
static bool pform_mc_translate_flag = true;
void pform_mc_translate_on(bool flag) { pform_mc_translate_flag = flag; }

/*
 * The pform_modules is a map of the modules that have been defined in
 * the top level. This should not contain nested modules/programs.
 * pform_primitives is similar, but for UDP primitives.
 */
map<perm_string,Module*> pform_modules;
map<perm_string,PUdp*> pform_primitives;

/*
 * The pform_units is a list of the SystemVerilog compilation unit scopes.
 * The current compilation unit is the last element in the list. All items
 * declared or defined at the top level (outside any design element) are
 * added to the current compilation unit scope.
 */
vector<PPackage*> pform_units;

static bool is_compilation_unit(LexicalScope*scope)
{
	// A compilation unit is the only scope that doesn't have a parent.
      assert(scope);
      return scope->parent_scope() == 0;
}

std::string vlltype::get_fileline() const
{
      ostringstream buf;
      buf << (text? text : "") << ":" << first_line;
      string res = buf.str();
      return res;

}

static bool is_hex_digit_str(const char *str)
{
      while (*str) {
	    if (!isxdigit(*str)) return false;
	    str++;
      }
      return true;
}

static bool is_dec_digit_str(const char *str)
{
      while (*str) {
	    if (!isdigit(*str)) return false;
	    str++;
      }
      return true;
}

static bool is_oct_digit_str(const char *str)
{
      while (*str) {
	    if (*str < '0' || *str > '7') return false;
	    str++;
      }
      return true;
}

static bool is_bin_digit_str(const char *str)
{
      while (*str) {
	    if (*str != '0' && *str != '1') return false;
	    str++;
      }
      return true;
}

/*
 * Parse configuration file with format <key>=<value>, where key
 * is the hierarchical name of a valid parameter name, and value
 * is the value user wants to assign to. The value should be constant.
 */
void parm_to_defparam_list(const string&param)
{
    char* key;
    char* value;
    unsigned off = param.find('=');
    if (off > param.size()) {
        key = strdup(param.c_str());
        value = static_cast<char*>(malloc(1));
        *value = '\0';

    } else {
        key = strdup(param.substr(0, off).c_str());
        value = strdup(param.substr(off+1).c_str());
    }

    // Resolve hierarchical name for defparam. Remember
    // to deal with bit select for generate scopes. Bit
    // select expression should be constant integer.
    pform_name_t name;
    char *nkey = key;
    char *ptr = strchr(key, '.');
    while (ptr != 0) {
        *ptr++ = '\0';
        // Find if bit select is applied, this would be something
        // like - scope[2].param = 10
        char *bit_l = strchr(nkey, '[');
        if (bit_l !=0) {
            *bit_l++ = '\0';
            char *bit_r = strchr(bit_l, ']');
            if (bit_r == 0) {
                cerr << "<command line>: error: missing ']' for defparam: " << nkey << endl;
                free(key);
                free(value);
                return;
            }
            *bit_r = '\0';
            int i = 0;
            while (*(bit_l+i) != '\0')
                if (!isdigit(*(bit_l+i++))) {
                    cerr << "<command line>: error: scope index expression is not constant: " << nkey << endl;
                    free(key);
                    free(value);
                    return;
                }
            name_component_t tmp(lex_strings.make(nkey));
            index_component_t index;
            index.sel = index_component_t::SEL_BIT;
            verinum *seln = new verinum(atoi(bit_l));
            PENumber *sel = new PENumber(seln);
            index.msb = sel;
            index.lsb = sel;
            tmp.index.push_back(index);
            name.push_back(tmp);
        }
        else    // no bit select
            name.push_back(name_component_t(lex_strings.make(nkey)));

        nkey = ptr;
        ptr = strchr(nkey, '.');
    }
    name.push_back(name_component_t(lex_strings.make(nkey)));
    free(key);

    // Resolve value to PExpr class. Should support all kind of constant
    // format including based number, dec number, real number and string.

    // Is it a string?
    if (*value == '"') {
	char *buf = strdup (value);
	char *buf_ptr = buf+1;
	// Parse until another '"' or '\0'
	while (*buf_ptr != '"' && *buf_ptr != '\0') {
	    buf_ptr++;
	    // Check for escape, especially '\"', which does not mean the
	    // end of string.
	    if (*buf_ptr == '\\' && *(buf_ptr+1) != '\0')
		buf_ptr += 2;
	}
	if (*buf_ptr == '\0')	// String end without '"'
	    cerr << "<command line>: error: missing close quote of string for defparam: " << name << endl;
	else if (*(buf_ptr+1) != 0) { // '"' appears within string with no escape
	    cerr << buf_ptr << endl;
	    cerr << "<command line>: error: \'\"\' appears within string value for defparam: " << name
		 << ". Ignore characters after \'\"\'" << endl;
	}

	*buf_ptr = '\0';
	buf_ptr = buf+1;
	// Remember to use 'new' to allocate string for PEString
	// because 'delete' is used by its destructor.
	char *nchar = strcpy(new char [strlen(buf_ptr)+1], buf_ptr);
	PExpr* ndec = new PEString(nchar);
	Module::user_defparms.push_back( make_pair(name, ndec) );
	free(buf);
	free(value);
	return;
    }

    // Is it a based number?
    char *num = strchr(value, '\'');
    if (num != 0) {
	verinum *val;
	const char *base = num + 1;
	if (*base == 's' || *base == 'S')
	    base++;
	switch (*base) {
	  case 'h':
	  case 'H':
	    if (is_hex_digit_str(base+1)) {
		val = make_unsized_hex(num);
	    } else {
		cerr << "<command line>: error: invalid digit in hex value specified for defparam: " << name << endl;
		free(value);
		return;
	    }
	    break;
	  case 'd':
	  case 'D':
	    if (is_dec_digit_str(base+1)) {
		val = make_unsized_dec(num);
	    } else {
		cerr << "<command line>: error: invalid digit in decimal value specified for defparam: " << name << endl;
		free(value);
		return;
	    }
	    break;
	  case 'o':
	  case 'O':
	    if (is_oct_digit_str(base+1)) {
		val = make_unsized_octal(num);
	    } else {
		cerr << "<command line>: error: invalid digit in octal value specified for defparam: " << name << endl;
		free(value);
		return;
	    }
	    break;
	  case 'b':
	  case 'B':
	    if (is_bin_digit_str(base+1)) {
		val = make_unsized_binary(num);
	    } else {
		cerr << "<command line>: error: invalid digit in binary value specified for defparam: " << name << endl;
		free(value);
		return;
	    }
	    break;
	  default:
	    cerr << "<command line>: error: invalid numeric base specified for defparam: " << name << endl;
	    free(value);
	    return;
	}
	if (num != value) {  // based number with size
	    *num = 0;
	    if (is_dec_digit_str(value)) {
		verinum *siz = make_unsized_dec(value);
		val = pform_verinum_with_size(siz, val, "<command line>", 0);
	    } else {
		cerr << "<command line>: error: invalid size for value specified for defparam: " << name << endl;
		free(value);
		return;
	    }
	}
	PExpr* ndec = new PENumber(val);
	Module::user_defparms.push_back( make_pair(name, ndec) );
	free(value);
	return;
    }

    // Is it a decimal number?
    num = (value[0] == '-') ? value + 1 : value;
    if (num[0] != '\0' && is_dec_digit_str(num)) {
	verinum *val = make_unsized_dec(num);
	if (value[0] == '-') *val = -(*val);
	PExpr* ndec = new PENumber(val);
	Module::user_defparms.push_back( make_pair(name, ndec) );
	free(value);
	return;
    }

    // Is it a real number?
    char *end = 0;
    double rval = strtod(value, &end);
    if (end != value && *end == 0) {
	verireal *val = new verireal(rval);
	PExpr* nreal = new PEFNumber(val);
	Module::user_defparms.push_back( make_pair(name, nreal) );
	free(value);
	return;
    }

    // None of the above.
    cerr << "<command line>: error: invalid value specified for defparam: " << name << endl;
    free(value);
}

/*
 * The lexor accesses the vl_* variables.
 */
string vl_file = "";

extern int VLparse();

  /* This tracks the current module being processed. There can only be
     exactly one module currently being parsed, since Verilog does not
     allow nested module definitions. */
static list<Module*>pform_cur_module;

bool pform_library_flag = false;

/*
 * Give each unnamed block that has a variable declaration a unique name.
 */
static unsigned scope_unnamed_block_with_decl = 1;

  /* This tracks the current generate scheme being processed. This is
     always within a module. */
static PGenerate*pform_cur_generate = 0;

  /* This indicates whether a new generate construct can be directly
     nested in the current generate construct. */
bool pform_generate_single_item = false;

  /* Blocks within the same conditional generate construct may have
     the same name. Here we collect the set of names used in each
     construct, so they can be added to the local scope without
     conflicting with each other. Generate constructs may nest, so
     we need a stack. */
static list<set<perm_string> > conditional_block_names;

  /* This tracks the current modport list being processed. This is
     always within an interface. */
static PModport*pform_cur_modport = 0;
static Module::PClocking*pform_cur_clocking = 0;
static bool pform_cur_clocking_is_global = false;

static NetNet::Type pform_default_nettype = NetNet::WIRE;

/*
 * These variables track the time scale set by the most recent `timescale
 * directive. Time scales set by SystemVerilog timeunit and timeprecision
 * declarations are stored directly in the current lexical scope.
 */
static int pform_time_unit;
static int pform_time_prec;

/*
 * These variables track where the most recent `timescale directive
 * occurred. This allows us to warn about time scales that are inherited
 * from another file.
 */
static char*pform_timescale_file = 0;
static unsigned pform_timescale_line;

/*
 * These variables track whether we can accept new timeunits declarations.
 */
bool allow_timeunit_decl = true;
bool allow_timeprec_decl = true;

// Track whether the current parameter declaration is in a parameter port list
static bool pform_in_parameter_port_list = false;

/*
 * The lexical_scope keeps track of the current lexical scope that is
 * being parsed. The lexical scope may stack, so the current scope may
 * have a parent, that is restored when the current scope ends.
 *
 * Items that have scoped names are put in the lexical_scope object.
 */
static LexicalScope* lexical_scope = 0;

LexicalScope* pform_peek_scope(void)
{
      assert(lexical_scope);
      return lexical_scope;
}

void pform_push_existing_scope(LexicalScope*scope)
{
      assert(scope);
      lexical_scope = scope;
}

static void pform_check_possible_imports(LexicalScope *scope)
{
      map<perm_string,PPackage*>::const_iterator cur;
      for (cur = scope->possible_imports.begin(); cur != scope->possible_imports.end(); ++cur) {
            if (scope->local_symbols.find(cur->first) == scope->local_symbols.end())
                  scope->explicit_imports[cur->first] = cur->second;
      }
      scope->possible_imports.clear();
}

void pform_pop_scope()
{
      LexicalScope*scope = lexical_scope;
      assert(scope);

      pform_check_possible_imports(scope);

      lexical_scope = scope->parent_scope();
      assert(lexical_scope);
}

static LexicalScope::lifetime_t find_lifetime(LexicalScope::lifetime_t lifetime)
{
      if (lifetime != LexicalScope::INHERITED)
	    return lifetime;

      return lexical_scope->default_lifetime;
}

static ivl_lifetime_t current_var_lifetime_ = IVL_VLT_INHERITED;

void pform_set_var_lifetime(ivl_lifetime_t lifetime)
{
      current_var_lifetime_ = lifetime;
}

static bool procedural_var_lifetime_context_()
{
      return dynamic_cast<PTaskFunc*>(lexical_scope)
          || dynamic_cast<PBlock*>(lexical_scope);
}

static void apply_var_lifetime_override_(PWire*wire)
{
      if (!wire || !procedural_var_lifetime_context_())
            return;
      if (current_var_lifetime_ == IVL_VLT_INHERITED)
            return;
      wire->lifetime_override(current_var_lifetime_);
}

static PScopeExtra* find_nearest_scopex(LexicalScope*scope)
{
      PScopeExtra*scopex = dynamic_cast<PScopeExtra*> (scope);
      while (scope && !scopex) {
	    scope = scope->parent_scope();
	    scopex = dynamic_cast<PScopeExtra*> (scope);
      }
      return scopex;
}

static void add_local_symbol(LexicalScope*scope, perm_string name, PNamedItem*item)
{
      assert(scope);

	// Check for conflict with another local symbol.
      map<perm_string,PNamedItem*>::const_iterator cur_sym
	    = scope->local_symbols.find(name);
      if (cur_sym != scope->local_symbols.end()) {
	    cerr << item->get_fileline() << ": error: "
		    "'" << name << "' has already been declared "
		    "in this scope." << endl;
	    cerr << cur_sym->second->get_fileline() << ":      : "
		    "It was declared here as "
		 << cur_sym->second->symbol_type() << "." << endl;
	    error_count += 1;
	    return;
      }

	// Check for conflict with an explicit import.
      map<perm_string,PPackage*>::const_iterator cur_pkg
	    = scope->explicit_imports.find(name);
      if (cur_pkg != scope->explicit_imports.end()) {
	    // IEEE 1800-2012 26.3: a wildcard import is a "tentative" import
	    // that gets pinned to explicit_imports the first time the name is
	    // referenced. A subsequent local declaration of the same name
	    // shadows the pinned import. Detect this case by checking whether
	    // the pinned package is in the scope's potential_imports list — if
	    // so, drop the pin and let the local declaration take precedence.
	    bool from_wildcard = false;
	    for (PPackage*wp : scope->potential_imports) {
		  if (wp == cur_pkg->second) { from_wildcard = true; break; }
	    }
	    if (from_wildcard) {
		  scope->explicit_imports.erase(cur_pkg);
		  scope->explicit_imports_from.erase(name);
	    } else {
		  cerr << item->get_fileline() << ": error: "
			  "'" << name << "' has already been "
			  "imported into this scope from package '"
		       << cur_pkg->second->pscope_name() << "'." << endl;
		  error_count += 1;
		  return;
	    }
      }

      scope->local_symbols[name] = item;
}

static void check_potential_imports(const struct vlltype&loc, perm_string name, bool tf_call)
{
      LexicalScope*scope = lexical_scope;
      while (scope) {
	    if (scope->local_symbols.find(name) != scope->local_symbols.end())
		  return;
	    if (scope->explicit_imports.find(name) != scope->explicit_imports.end())
		  return;
	    if (pform_find_potential_import(loc, scope, name, tf_call, true))
		  return;

	    scope = scope->parent_scope();
      }
}

/*
 * Set the local time unit/precision. This version is used for setting
 * the time scale for design elements (modules, packages, etc.) and is
 * called after any initial timeunit and timeprecision declarations
 * have been parsed.
 */
void pform_set_scope_timescale(const struct vlltype&loc)
{
      PScopeExtra*scope = dynamic_cast<PScopeExtra*>(lexical_scope);
      ivl_assert(loc, scope);

      PScopeExtra*parent = find_nearest_scopex(scope->parent_scope());

      bool used_global_timescale = false;
      if (scope->time_unit_is_default) {
            if (is_compilation_unit(scope)) {
                  scope->time_unit = def_ts_units;
            } else if (!is_compilation_unit(parent)) {
                  scope->time_unit = parent->time_unit;
                  scope->time_unit_is_default = parent->time_unit_is_default;
            } else if (pform_timescale_file != 0) {
                  scope->time_unit = pform_time_unit;
                  scope->time_unit_is_default = false;
                  used_global_timescale = true;
            } else /* parent is compilation unit */ {
                  scope->time_unit = parent->time_unit;
                  scope->time_unit_is_default = parent->time_unit_is_default;
            }
      }
      if (scope->time_prec_is_default) {
            if (is_compilation_unit(scope)) {
                  scope->time_precision = def_ts_prec;
            } else if (!is_compilation_unit(parent)) {
                  scope->time_precision = parent->time_precision;
                  scope->time_prec_is_default = parent->time_prec_is_default;
            } else if (pform_timescale_file != 0) {
                  scope->time_precision = pform_time_prec;
                  scope->time_prec_is_default = false;
                  used_global_timescale = true;
            } else {
                  scope->time_precision = parent->time_precision;
                  scope->time_prec_is_default = parent->time_prec_is_default;
            }
      }

      if (gn_system_verilog() && (scope->time_unit < scope->time_precision)) {
	    if (scope->time_unit_is_local || scope->time_prec_is_local) {
		  VLerror("error: A timeprecision is missing or is too large!");
	    }
      } else {
            ivl_assert(loc, scope->time_unit >= scope->time_precision);
      }

      if (warn_timescale && used_global_timescale
	  && (strcmp(pform_timescale_file, loc.text) != 0)) {

	    cerr << loc.get_fileline() << ": warning: "
		 << "timescale for " << scope->pscope_name()
		 << " inherited from another file." << endl;
	    cerr << pform_timescale_file << ":" << pform_timescale_line
		 << ": ...: The inherited timescale is here." << endl;
      }

      allow_timeunit_decl = false;
      allow_timeprec_decl = false;
}

/*
 * Set the local time unit/precision. This version is used for setting
 * the time scale for subsidiary items (classes, subroutines, etc.),
 * which simply inherit their time scale from their parent scope.
 *
 * Phase 60: when the parent is the compilation unit ($unit) and a
 * `timescale directive is in effect, prefer the directive's values
 * over $unit's defaults.  Without this, classes declared at file scope
 * inherit $unit->time_unit=0 (which is `def_ts_units`, default 1 sec)
 * instead of the file's `timescale, and time literals like `100ns`
 * inside class methods scale incorrectly.
 */
static void pform_set_scope_timescale(PScope*scope, const PScope*parent)
{
      scope->time_unit            = parent->time_unit;
      scope->time_precision       = parent->time_precision;
      scope->time_unit_is_default = parent->time_unit_is_default;
      scope->time_prec_is_default = parent->time_prec_is_default;

      if (parent->time_unit_is_default && pform_timescale_file != 0) {
            scope->time_unit            = pform_time_unit;
            scope->time_unit_is_default = false;
      }
      if (parent->time_prec_is_default && pform_timescale_file != 0) {
            scope->time_precision       = pform_time_prec;
            scope->time_prec_is_default = false;
      }
}

PClass* pform_push_class_scope(const struct vlltype&loc, perm_string name)
{
      PClass*class_scope = new PClass(name, lexical_scope);
      class_scope->default_lifetime = LexicalScope::AUTOMATIC;
      FILE_NAME(class_scope, loc);

      PScopeExtra*scopex = find_nearest_scopex(lexical_scope);
      ivl_assert(loc, scopex);
      ivl_assert(loc, !pform_cur_generate);

      pform_set_scope_timescale(class_scope, scopex);

      scopex->classes[name] = class_scope;
      scopex->classes_lexical .push_back(class_scope);

      lexical_scope = class_scope;
      return class_scope;
}

PPackage* pform_push_package_scope(const struct vlltype&loc, perm_string name,
				   LexicalScope::lifetime_t lifetime)
{
      PPackage*pkg_scope = new PPackage(name, lexical_scope);
      pkg_scope->default_lifetime = find_lifetime(lifetime);
      FILE_NAME(pkg_scope, loc);

      allow_timeunit_decl = true;
      allow_timeprec_decl = true;

      lexical_scope = pkg_scope;
      return pkg_scope;
}

PTask* pform_push_task_scope(const struct vlltype&loc, const char*name,
			     LexicalScope::lifetime_t lifetime)
{
      perm_string task_name = lex_strings.make(name);

      LexicalScope::lifetime_t default_lifetime = find_lifetime(lifetime);
      bool is_auto = default_lifetime == LexicalScope::AUTOMATIC;

      PTask*task = new PTask(task_name, lexical_scope, is_auto);
      task->default_lifetime = default_lifetime;
      FILE_NAME(task, loc);

      PScopeExtra*scopex = find_nearest_scopex(lexical_scope);
      ivl_assert(loc, scopex);
      if (is_compilation_unit(scopex) && !gn_system_verilog()) {
	    cerr << task->get_fileline() << ": error: task declarations "
		  "must be contained within a module." << endl;
	    error_count += 1;
      }

      pform_set_scope_timescale(task, scopex);

      if (pform_cur_generate) {
	    add_local_symbol(pform_cur_generate, task_name, task);
	    pform_cur_generate->tasks[task_name] = task;
      } else {
	    add_local_symbol(scopex, task_name, task);
	    scopex->tasks[task_name] = task;
      }

      lexical_scope = task;

      return task;
}

PTask* pform_push_task_scope_unbound(const struct vlltype&loc, const char*name,
				     LexicalScope::lifetime_t lifetime)
{
      perm_string task_name = lex_strings.make(name);

      LexicalScope::lifetime_t default_lifetime = find_lifetime(lifetime);
      bool is_auto = default_lifetime == LexicalScope::AUTOMATIC;

      PTask*task = new PTask(task_name, lexical_scope, is_auto);
      task->default_lifetime = default_lifetime;
      FILE_NAME(task, loc);

      PScopeExtra*scopex = find_nearest_scopex(lexical_scope);
      ivl_assert(loc, scopex);
      pform_set_scope_timescale(task, scopex);

      lexical_scope = task;
      return task;
}

PFunction* pform_push_function_scope(const struct vlltype&loc, const char*name,
                                     LexicalScope::lifetime_t lifetime)
{
      perm_string func_name = lex_strings.make(name);

      LexicalScope::lifetime_t default_lifetime = find_lifetime(lifetime);
      bool is_auto = default_lifetime == LexicalScope::AUTOMATIC;

      PFunction*func = new PFunction(func_name, lexical_scope, is_auto);
      func->default_lifetime = default_lifetime;
      FILE_NAME(func, loc);

      PScopeExtra*scopex = find_nearest_scopex(lexical_scope);
      ivl_assert(loc, scopex);
      if (is_compilation_unit(scopex) && !gn_system_verilog()) {
	    cerr << func->get_fileline() << ": error: function declarations "
		  "must be contained within a module." << endl;
	    error_count += 1;
      }

      pform_set_scope_timescale(func, scopex);

      if (pform_cur_generate) {
	    add_local_symbol(pform_cur_generate, func_name, func);
	    pform_cur_generate->funcs[func_name] = func;

      } else {
	    add_local_symbol(scopex, func_name, func);
	    scopex->funcs[func_name] = func;
      }

      lexical_scope = func;

      return func;
}

PFunction* pform_push_function_scope_unbound(const struct vlltype&loc, const char*name,
					     LexicalScope::lifetime_t lifetime)
{
      perm_string func_name = lex_strings.make(name);

      LexicalScope::lifetime_t default_lifetime = find_lifetime(lifetime);
      bool is_auto = default_lifetime == LexicalScope::AUTOMATIC;

      PFunction*func = new PFunction(func_name, lexical_scope, is_auto);
      func->default_lifetime = default_lifetime;
      FILE_NAME(func, loc);

      PScopeExtra*scopex = find_nearest_scopex(lexical_scope);
      ivl_assert(loc, scopex);
      pform_set_scope_timescale(func, scopex);

      lexical_scope = func;
      return func;
}

PBlock* pform_push_block_scope(const struct vlltype&loc, const char*name,
			       PBlock::BL_TYPE bt)
{
      perm_string block_name;
      if (name) block_name = lex_strings.make(name);
      else {
	      // Create a unique name for this unnamed block.
	    char tmp[32];
	    snprintf(tmp, sizeof tmp, "$unm_blk_%u",
	             scope_unnamed_block_with_decl);
	    block_name = lex_strings.make(tmp);
	    scope_unnamed_block_with_decl += 1;
      }

      PBlock*block = new PBlock(block_name, lexical_scope, bt);
      FILE_NAME(block, loc);
      block->default_lifetime = find_lifetime(LexicalScope::INHERITED);
      if (name) add_local_symbol(lexical_scope, block_name, block);
      lexical_scope = block;

      return block;
}

/*
 * Create a new identifier.
 */
PEIdent* pform_new_ident(const struct vlltype&loc, const pform_name_t&name)
{
      if (gn_system_verilog())
	    check_potential_imports(loc, name.front().name, false);

      return new PEIdent(name, loc.lexical_pos);
}

PTrigger* pform_new_trigger(const struct vlltype&loc, PPackage*pkg,
			    const pform_name_t&name, unsigned lexical_pos)
{
      if (gn_system_verilog())
	    check_potential_imports(loc, name.front().name, false);

      PTrigger*tmp = new PTrigger(pkg, name, lexical_pos);
      FILE_NAME(tmp, loc);
      return tmp;
}

PNBTrigger* pform_new_nb_trigger(const struct vlltype&loc,
			         const list<PExpr*>*dly,
			         const pform_name_t&name,
			         unsigned lexical_pos)
{
      if (gn_system_verilog())
	    check_potential_imports(loc, name.front().name, false);

      PExpr*tmp_dly = 0;
      if (dly) {
	    ivl_assert(loc, dly->size() == 1);
	    tmp_dly = dly->front();
      }

      PNBTrigger*tmp = new PNBTrigger(name, lexical_pos, tmp_dly);
      FILE_NAME(tmp, loc);
      return tmp;
}

PGenerate* pform_parent_generate(void)
{
      return pform_cur_generate;
}

bool pform_error_in_generate(const vlltype&loc, const char *type)
{
	if (!pform_parent_generate())
		return false;

	VLerror(loc, "error: %s is not allowed in generate block.", type);
	return true;
}

void pform_bind_attributes(map<perm_string,PExpr*>&attributes,
			   list<named_pexpr_t>*attr, bool keep_attrs)
{
      if (attr == 0)
	    return;

      while (! attr->empty()) {
	    named_pexpr_t tmp = attr->front();
	    attr->pop_front();
	    attributes[tmp.name] = tmp.parm;
      }
      if (!keep_attrs)
	    delete attr;
}

bool pform_in_program_block()
{
      if (pform_cur_module.empty())
	    return false;
      if (pform_cur_module.front()->program_block)
	    return true;
      return false;
}

bool pform_in_interface()
{
      if (pform_cur_module.empty())
	    return false;
      if (pform_cur_module.front()->is_interface)
	    return true;
      return false;
}

static bool pform_at_module_level()
{
      return (!pform_cur_module.empty() && (lexical_scope == pform_cur_module.front())) ||
             (lexical_scope == pform_cur_generate);
}

PWire*pform_get_wire_in_scope(perm_string name)
{
      return lexical_scope->wires_find(name);
}

static void pform_put_wire_in_scope(perm_string name, PWire*net)
{
      add_local_symbol(lexical_scope, name, net);
      lexical_scope->wires[name] = net;
}

void pform_put_enum_type_in_scope(enum_type_t*enum_set)
{
      if (std::find(lexical_scope->enum_sets.begin(),
		    lexical_scope->enum_sets.end(), enum_set) !=
          lexical_scope->enum_sets.end())
	    return;

      set<perm_string> enum_names;
      list<named_pexpr_t>::const_iterator cur;
      for (cur = enum_set->names->begin(); cur != enum_set->names->end(); ++cur) {
	    if (enum_names.count(cur->name)) {
		  cerr << enum_set->get_fileline() << ": error: "
			  "Duplicate enumeration name '"
		       << cur->name << "'." << endl;
		  error_count += 1;
	    } else {
		  add_local_symbol(lexical_scope, cur->name, enum_set);
		  enum_names.insert(cur->name);
	    }
      }

      lexical_scope->enum_sets.push_back(enum_set);
}

static typedef_t *pform_get_typedef(const struct vlltype&loc, perm_string name)
{
      typedef_t *&td = lexical_scope->typedefs[name];
      if (!td) {
	    td = new typedef_t(name);
	    FILE_NAME(td, loc);
	    add_local_symbol(lexical_scope, name, td);
      }
      return td;
}

void pform_forward_typedef(const struct vlltype&loc, perm_string name,
			   enum typedef_t::basic_type basic_type)
{
      typedef_t *td = pform_get_typedef(loc, name);

      if (!td->set_basic_type(basic_type)) {
	    cout << loc << " error: Incompatible basic type `" << basic_type
	         << "` for `" << name
		 << "`. Previously declared in this scope as `"
		 << td->get_basic_type() << "` at " << td->get_fileline() << "."
	         << endl;
	    error_count++;
      }
}

void pform_set_typedef(const struct vlltype&loc, perm_string name,
		       data_type_t*data_type,
		       std::list<pform_range_t>*unp_ranges)
{
      typedef_t *td = pform_get_typedef(loc, name);

      if(unp_ranges)
	    data_type = new uarray_type_t(data_type, unp_ranges);

      if (!td->set_data_type(data_type)) {
	    cerr << loc << " error: Type identifier `" << name
		 << "` has already been declared in this scope at "
		 << td->get_data_type()->get_fileline() << "."
		 << endl;
	    error_count++;
	    delete data_type;
      }
}

void pform_set_type_referenced(const struct vlltype&loc, const char*name)
{
      perm_string lex_name = lex_strings.make(name);
      check_potential_imports(loc, lex_name, false);
}

static PClass* pform_find_visible_class_scope(LexicalScope*start, perm_string name)
{
      for (LexicalScope*cur = start ; cur ; cur = cur->parent_scope()) {
	    if (PScopeExtra*scopex = dynamic_cast<PScopeExtra*>(cur)) {
		  auto cls = scopex->classes.find(name);
		  if (cls != scopex->classes.end())
			return cls->second;
	    }

	    auto imp = cur->explicit_imports.find(name);
	    if (imp != cur->explicit_imports.end()) {
		  PPackage*pkg = imp->second;
		  auto cls = pkg->classes.find(name);
		  if (cls != pkg->classes.end())
			return cls->second;
	    }

	    for (PPackage*pkg : cur->potential_imports) {
		  auto cls = pkg->classes.find(name);
		  if (cls != pkg->classes.end())
			return cls->second;
	    }
      }

      return nullptr;
}

static typedef_t* pform_find_inherited_class_typedef(PClass*class_scope, perm_string name)
{
      set<perm_string> seen;
      PClass*cur_class = class_scope;

      while (cur_class && cur_class->type && cur_class->type->base_type.get()) {
	    const typeref_t*base_ref = dynamic_cast<const typeref_t*>(cur_class->type->base_type.get());
	    if (!base_ref)
		  break;

	    typedef_t*base_td = base_ref->typedef_ref();
	    if (!base_td)
		  break;

	    perm_string base_name = base_td->name;
	    if (!seen.insert(base_name).second)
		  break;

	    cur_class = pform_find_visible_class_scope(cur_class, base_name);
	    if (!cur_class)
		  break;

	    auto cur = cur_class->typedefs.find(name);
	    if (cur != cur_class->typedefs.end())
		  return cur->second;
      }

      return nullptr;
}

static typedef_t* pform_find_interface_typedef(perm_string name)
{
      static map<perm_string,typedef_t*> interface_typedef_cache;

      auto cached = interface_typedef_cache.find(name);
      if (cached != interface_typedef_cache.end())
	    return cached->second;

      auto mod = pform_modules.find(name);
      if (mod == pform_modules.end() || !mod->second->is_interface)
	    return nullptr;

      typedef_t* td = new typedef_t(name);
      td->set_data_type(new interface_type_t(name));
      interface_typedef_cache[name] = td;
      return td;
}

static typedef_t* pform_bind_visible_class_typedef(const struct vlltype&loc,
                                                   perm_string name,
                                                   PClass*class_scope)
{
      if (!class_scope || !class_scope->type)
            return nullptr;

      LexicalScope*decl_scope = class_scope->parent_scope();
      if (!decl_scope)
            return nullptr;

      typedef_t*&td = decl_scope->typedefs[name];
      if (!td) {
            td = new typedef_t(name);
            FILE_NAME(td, loc);
            add_local_symbol(decl_scope, name, td);
      }

      if (!td->set_basic_type(typedef_t::CLASS)) {
            cerr << loc << " error: Incompatible basic type `" << td->get_basic_type()
                 << "` for `" << name << "`." << endl;
            error_count++;
            return td;
      }

      if (!td->get_data_type())
            td->set_data_type(class_scope->type);

      return td;
}

static typedef_t* pform_find_potential_imported_type(const struct vlltype&loc,
						     LexicalScope*scope,
						     perm_string name)
{
      typedef_t*found_type = nullptr;
      PPackage*found_decl_pkg = nullptr;

      for (PPackage*search_pkg : scope->potential_imports) {
	    PPackage*decl_pkg = pform_package_importable(search_pkg, name);
	    if (!decl_pkg)
		  continue;

	    auto cur = decl_pkg->typedefs.find(name);
	    if (cur == decl_pkg->typedefs.end())
		  continue;

	    if (found_type && found_type != cur->second) {
		  cerr << loc.get_fileline() << ": error: "
		       << "Ambiguous use of type '" << name << "'. "
		       << "It is exported by both '"
		       << found_decl_pkg->pscope_name()
		       << "' and by '"
		       << decl_pkg->pscope_name()
		       << "'." << endl;
		  error_count++;
		  continue;
	    }

	    found_type = cur->second;
	    found_decl_pkg = decl_pkg;
	    scope->explicit_imports[name] = decl_pkg;
	    scope->explicit_imports_from[name].insert(search_pkg);
      }

      return found_type;
}

typedef_t* pform_test_type_identifier(const struct vlltype&loc, const char*txt)
{
      perm_string name = lex_strings.make(txt);
      if (name == lex_strings.make("process")) {
	    static typedef_t*process_type = nullptr;
	    if (!process_type) {
		  process_type = new typedef_t(lex_strings.make("process"));
		  process_type->set_data_type(new type_parameter_t(process_type->name));
	    }
	    return process_type;
      }
      if (name == lex_strings.make("semaphore")) {
	    static typedef_t*semaphore_type = nullptr;
	    if (!semaphore_type) {
		  semaphore_type = new typedef_t(lex_strings.make("semaphore"));
		  semaphore_type->set_data_type(new type_parameter_t(semaphore_type->name));
	    }
	    return semaphore_type;
      }
      if (name == lex_strings.make("mailbox")) {
	    static typedef_t*mailbox_type = nullptr;
	    if (!mailbox_type) {
		  mailbox_type = new typedef_t(lex_strings.make("mailbox"));
		  mailbox_type->set_data_type(new type_parameter_t(mailbox_type->name));
	    }
	    return mailbox_type;
      }

      LexicalScope*cur_scope = lexical_scope;
      do {
	    LexicalScope::typedef_map_t::iterator cur;

	      // First look to see if this identifier is imported from
	      // a package. If it is, see if it is a type in that
	      // package. If it is, then great. If imported as
	      // something other than a type, then give up now because
	      // the name has at least shadowed any other possible
	      // meaning for this name.
	    map<perm_string,PPackage*>::iterator cur_pkg;
	    cur_pkg = cur_scope->explicit_imports.find(name);
	    if (cur_pkg != cur_scope->explicit_imports.end()) {
		  PPackage*pkg = cur_pkg->second;
		  cur = pkg->typedefs.find(name);
		  if (cur != pkg->typedefs.end())
			return cur->second;

		    // Not a type. Give up.
		  return 0;
	    }

	    cur = cur_scope->typedefs.find(name);
	    if (cur != cur_scope->typedefs.end())
		  return cur->second;

	    if (typedef_t*imported_type =
		    pform_find_potential_imported_type(loc, cur_scope, name))
		  return imported_type;

	    cur_scope = cur_scope->parent_scope();
      } while (cur_scope);

      // If we are inside a class scope, also search inherited class typedefs.
      for (LexicalScope*cls = lexical_scope ; cls ; cls = cls->parent_scope()) {
	    if (PClass*class_scope = dynamic_cast<PClass*>(cls)) {
		  if (typedef_t*td = pform_find_inherited_class_typedef(class_scope, name))
			return td;
		  break;
	    }
      }

      if (PClass*class_scope = pform_find_visible_class_scope(lexical_scope, name))
            return pform_bind_visible_class_typedef(loc, name, class_scope);

      if (typedef_t*td = pform_find_interface_typedef(name))
	    return td;

      return 0;
}

void delete_parmvalue(struct parmvalue_t*parms)
{
      if (parms == 0)
	    return;

      if (parms->by_order) {
	    for (list<PExpr*>::iterator cur = parms->by_order->begin()
		 ; cur != parms->by_order->end() ; ++cur)
		  delete *cur;
	    delete parms->by_order;
      }

      if (parms->by_name) {
	    for (list<named_pexpr_t>::iterator cur = parms->by_name->begin()
		 ; cur != parms->by_name->end() ; ++cur)
		  delete cur->parm;
	    delete parms->by_name;
      }

      delete parms;
}

PECallFunction* pform_make_call_function(const struct vlltype&loc,
					 const pform_name_t&name,
					 const list<named_pexpr_t> &parms,
					 struct parmvalue_t*type_args)
{
      if (gn_system_verilog())
	    check_potential_imports(loc, name.front().name, true);

      PECallFunction*tmp = new PECallFunction(name, parms);
      tmp->set_leading_type_args(type_args);
      FILE_NAME(tmp, loc);
      return tmp;
}

/*
 * M14: structural deep-copy of the common expression shapes that a
 * `case (X) inside` selector takes. Returns nullptr for shapes it
 * cannot copy so the caller can diagnose loudly rather than share a
 * node (which would double-free) or silently miscompile.
 */
static PExpr* pform_dup_case_expr_(const PExpr*e)
{
      if (e == 0) return 0;

      if (const PEIdent*id = dynamic_cast<const PEIdent*>(e)) {
	    PEIdent*cp = id->path().package
		  ? new PEIdent(id->path().package, id->path().name,
				id->lexical_pos())
		  : new PEIdent(id->path().name, id->lexical_pos());
	    cp->set_line(*e);
	    return cp;
      }
      if (const PENumber*num = dynamic_cast<const PENumber*>(e)) {
	    PENumber*cp = new PENumber(new verinum(num->value()));
	    cp->set_line(*e);
	    return cp;
      }
      if (const PEUnary*un = dynamic_cast<const PEUnary*>(e)) {
	    PExpr*sub = pform_dup_case_expr_(un->get_expr());
	    if (!sub) return 0;
	    PEUnary*cp = new PEUnary(un->get_op(), sub);
	    cp->set_line(*e);
	    return cp;
      }
      if (const PEBinary*bin = dynamic_cast<const PEBinary*>(e)) {
	    PExpr*l = pform_dup_case_expr_(bin->get_left());
	    PExpr*r = pform_dup_case_expr_(bin->get_right());
	    if (!l || !r) { delete l; delete r; return 0; }
	    PEBinary*cp;
	    if (dynamic_cast<const PEBComp*>(e))
		  cp = new PEBComp(bin->get_op(), l, r);
	    else if (dynamic_cast<const PEBLogic*>(e))
		  cp = new PEBLogic(bin->get_op(), l, r);
	    else if (dynamic_cast<const PEBShift*>(e))
		  cp = new PEBShift(bin->get_op(), l, r);
	    else if (typeid(*e) == typeid(PEBinary))
		  cp = new PEBinary(bin->get_op(), l, r);
	    else { delete l; delete r; return 0; }
	    cp->set_line(*e);
	    return cp;
      }
      return 0;
}

/*
 * M14: lower `case (X) inside { items }` (IEEE 1800-2017 12.5.4) to a
 * `case (1'b1)` whose item expressions are `X inside { ranges_i }`
 * membership tests (PEInside), which already implement full set/range
 * membership. Previously the parser collapsed range items to their
 * lower bound and treated the whole thing as an ordinary case — a
 * silent miscompile where interior range values never matched.
 *
 * The selector X is duplicated into each item's membership test. For
 * the common case of a variable selector this re-reference is exact;
 * a selector with side effects would be evaluated per item, which is
 * diagnosed (a non-duplicable selector shape produces a loud sorry).
 */
Statement* pform_make_case_inside(const struct vlltype&loc,
				  ivl_case_quality_t qual,
				  PExpr*sel,
				  std::vector<PCase::Item*>*items)
{
      bool ok = true;
      for (unsigned idx = 0 ; idx < items->size() ; idx += 1) {
	    PCase::Item*cur = (*items)[idx];

	      // The default item has neither values nor ranges.
	    if (cur->expr.empty() && cur->inside_ranges.empty())
		  continue;

	    std::list<inside_range_t> ranges;
	      // Single (or comma-separated) values become is_range=false
	      // membership entries (held in inside_range_t::hi).
	    for (std::list<PExpr*>::iterator it = cur->expr.begin()
		       ; it != cur->expr.end() ; ++it) {
		  inside_range_t r;
		  r.lo = 0;
		  r.hi = *it;
		  r.is_range = false;
		  ranges.push_back(r);
	    }
	    cur->expr.clear();
	      // [lo:hi] range items.
	    for (std::list<inside_range_t>::iterator it = cur->inside_ranges.begin()
		       ; it != cur->inside_ranges.end() ; ++it)
		  ranges.push_back(*it);
	    cur->inside_ranges.clear();

	    PExpr*sel_dup = pform_dup_case_expr_(sel);
	    if (sel_dup == 0) {
		  cerr << loc.get_fileline() << ": sorry: the selector "
		       << "expression of this `case ... inside` has a shape "
		       << "the compiler cannot duplicate; use a variable "
		       << "selector." << endl;
		  error_count += 1;
		  ok = false;
		  sel_dup = new PENumber(new verinum(verinum::V0, 1));
		  FILE_NAME(sel_dup, loc);
	    }

	    std::list<inside_range_t>*ranges_heap =
		  new std::list<inside_range_t>(ranges);
	    PEInside*ins = new PEInside(sel_dup, ranges_heap);
	    FILE_NAME(ins, loc);
	    cur->expr.push_back(ins);
      }
      (void)ok;

      PENumber*one = new PENumber(new verinum(verinum::V1, 1));
      FILE_NAME(one, loc);
      PCase*tmp = new PCase(qual, NetCase::EQ, one, items);
      FILE_NAME(tmp, loc);
      delete sel;
      return tmp;
}

PCallTask* pform_make_call_task(const struct vlltype&loc,
				const pform_name_t&name,
				const list<named_pexpr_t> &parms,
				struct parmvalue_t*type_args)
{
      if (gn_system_verilog())
	    check_potential_imports(loc, name.front().name, true);

      /* If the head of the path matches a known package name, attach the
         package context so symbol_search resolves into that package
         directly. This recovers the package qualifier when the parser
         produced an IDENTIFIER K_SCOPE_RES IDENTIFIER form rather than
         the explicit package_scope rule (e.g. statement form
         `mypkg::func();`). */
      PPackage*pkg = nullptr;
      if (gn_system_verilog() && name.size() >= 2) {
	    pkg = pform_test_package_identifier(name.front().name.str());
      }

      PCallTask*tmp;
      if (pkg) {
	    pform_name_t tail_path = name;
	    tail_path.pop_front();
	    tmp = new PCallTask(pkg, tail_path, parms);
      } else {
	    tmp = new PCallTask(name, parms);
      }
      tmp->set_leading_type_args(type_args);
      FILE_NAME(tmp, loc);
      return tmp;
}

void pform_make_var(const struct vlltype&loc,
		    std::list<decl_assignment_t*>*assign_list,
		    data_type_t*data_type, std::list<named_pexpr_t>*attr,
		    bool is_const)
{
      static const struct str_pair_t str = { IVL_DR_STRONG, IVL_DR_STRONG };

      pform_makewire(loc, 0, str, assign_list, NetNet::REG, data_type, attr,
		     is_const);
}

void pform_make_foreach_declarations(const struct vlltype&loc,
				     const pform_name_t*array_name,
				     std::list<perm_string>*loop_vars)
{
      bool resolvable_target = array_name != 0;
      std::vector<perm_string> target_path;
      if (array_name) {
	    for (pform_name_t::const_iterator cur = array_name->begin()
		       ; cur != array_name->end() ; ++cur) {
		  if (!cur->index.empty()) {
			resolvable_target = false;
			break;
		  }
		  target_path.push_back(cur->name);
	    }
      }
      size_t index_depth = 0;

      for (list<perm_string>::const_iterator cur = loop_vars->begin()
		 ; cur != loop_vars->end() ; ++ cur, index_depth += 1) {
	    if (cur->nil())
		  continue;

	    list<decl_assignment_t*>assign_list;
	    decl_assignment_t*tmp_assign = new decl_assignment_t;
	    tmp_assign->name = { lex_strings.make(*cur), 0 };
	    assign_list.push_back(tmp_assign);

	    data_type_t*index_type = resolvable_target
		  ? static_cast<data_type_t*>(new foreach_index_type_t(
			target_path, index_depth, loc.lexical_pos))
		  : static_cast<data_type_t*>(new atom_type_t(atom_type_t::INT, true));
	    pform_make_var(loc, &assign_list, index_type);
      }
}

PForeach* pform_make_foreach(const struct vlltype&loc,
			     const pform_name_t&name,
			     list<perm_string>*loop_vars,
			     Statement*stmt)
{
      if (loop_vars==0 || loop_vars->empty()) {
	    cerr << loc.get_fileline() << ": error: "
		 << "No loop variables at all in foreach index." << endl;
	    error_count += 1;
      }

      ivl_assert(loc, loop_vars);
      PForeach*fe = new PForeach(name, *loop_vars, stmt, loc.lexical_pos);
      FILE_NAME(fe, loc);

      delete loop_vars;

      return fe;
}

static void pform_put_behavior_in_scope(PProcess*pp)
{
      lexical_scope->behaviors.push_back(pp);
}

void pform_put_behavior_in_scope(AProcess*pp)
{
      lexical_scope->analog_behaviors.push_back(pp);
}

void pform_set_default_nettype(NetNet::Type type,
			       const char*file, unsigned lineno)
{
      pform_default_nettype = type;

      if (! pform_cur_module.empty()) {
	    cerr << file<<":"<<lineno << ": error: "
		 << "`default_nettype directives must appear" << endl;
	    cerr << file<<":"<<lineno << ":      : "
		 << "outside module definitions. The containing" << endl;
	    cerr << file<<":"<<lineno << ":      : "
		 << "module " << pform_cur_module.back()->mod_name()
		 << " starts on line "
		 << pform_cur_module.back()->get_fileline() << "." << endl;
	    error_count += 1;
      }
}

static void pform_declare_implicit_nets(PExpr*expr)
{
	/* If implicit net creation is turned off, then stop now. */
      if (pform_default_nettype == NetNet::NONE)
	    return;

      if (expr)
            expr->declare_implicit_nets(lexical_scope, pform_default_nettype);
}

/*
 * The lexor calls this function to set the active timescale when it
 * detects a `timescale directive. The function saves the directive
 * values (for use by subsequent design elements) and if warnings are
 * enabled checks to see if some design elements have no timescale.
 */
void pform_set_timescale(int unit, int prec,
			 const char*file, unsigned lineno)
{
      assert(unit >= prec);
      pform_time_unit = unit;
      pform_time_prec = prec;

      if (pform_timescale_file) {
	    free(pform_timescale_file);
      }

      if (file) pform_timescale_file = strdup(file);
      else pform_timescale_file = 0;
      pform_timescale_line = lineno;
}

bool get_time_unit(const char*cp, int &unit)
{
	const char *c;
	bool        rc = true;

	if (strchr(cp, '_')) {
		VLerror(yylloc, "error: Invalid timeunit constant ('_' is not "
				"supported).");
		return false;
	}

	c = strpbrk(cp, "munpfs");
	if (!c)
		return false;

	if (*c == 's')
		unit = 0;
	else if (!strncmp(c, "ms", 2))
		unit = -3;
	else if (!strncmp(c, "us", 2))
		unit = -6;
	else if (!strncmp(c, "ns", 2))
		unit = -9;
	else if (!strncmp(c, "ps", 2))
		unit = -12;
	else if (!strncmp(c, "fs", 2))
		unit = -15;
	else {
		rc = false;

		ostringstream msg;
		msg << "error: Invalid timeunit scale '" << cp << "'.";
		VLerror(msg.str().c_str());
	}

	return rc;
}

/*
 * Get a timeunit or timeprecision value from a string.  This is
 * similar to the code in lexor.lex for the `timescale directive.
 */
static bool get_time_unit_prec(const char*cp, int &res, bool is_unit)
{
	/* We do not support a '_' in these time constants. */
      if (strchr(cp, '_')) {
	    if (is_unit) {
		  VLerror(yylloc, "error: Invalid timeunit constant ('_' "
		                  "is not supported).");
	    } else {
		  VLerror(yylloc, "error: Invalid timeprecision constant ('_' "
		                  "is not supported).");
	    }
	    return true;
      }

	/* Check for the 1 digit. */
      if (*cp != '1') {
	    if (is_unit) {
		  VLerror(yylloc, "error: Invalid timeunit constant "
                                  "(1st digit).");
	    } else {
		  VLerror(yylloc, "error: Invalid timeprecision constant "
                                  "(1st digit).");
	    }
	    return true;
      }
      cp += 1;

	/* Check the number of zeros after the 1. */
      res = strspn(cp, "0");
      if (res > 2) {
	    if (is_unit) {
		  VLerror(yylloc, "error: Invalid timeunit constant "
		                  "(number of zeros).");
	    } else {
		  VLerror(yylloc, "error: Invalid timeprecision constant "
		                  "(number of zeros).");
	    }
	    return true;
      }
      cp += res;

	/* Now process the scaling string. */
      if (strncmp("s", cp, 1) == 0) {
	    res -= 0;
	    return false;

      } else if (strncmp("ms", cp, 2) == 0) {
	    res -= 3;
	    return false;

      } else if (strncmp("us", cp, 2) == 0) {
	    res -= 6;
	    return false;

      } else if (strncmp("ns", cp, 2) == 0) {
	    res -= 9;
	    return false;

      } else if (strncmp("ps", cp, 2) == 0) {
	    res -= 12;
	    return false;

      } else if (strncmp("fs", cp, 2) == 0) {
	    res -= 15;
	    return false;

      }

      ostringstream msg;
      msg << "error: Invalid ";
      if (is_unit) msg << "timeunit";
      else msg << "timeprecision";
      msg << " scale '" << cp << "'.";
      VLerror(msg.str().c_str());
      return true;
}

void pform_set_timeunit(const char*txt, bool initial_decl)
{
      int val;

      if (get_time_unit_prec(txt, val, true)) return;

      PScopeExtra*scope = dynamic_cast<PScopeExtra*>(lexical_scope);
      if (!scope)
	    return;

      if (initial_decl) {
            scope->time_unit = val;
            scope->time_unit_is_local = true;
            scope->time_unit_is_default = false;
            allow_timeunit_decl = false;
      } else if (!scope->time_unit_is_local) {
            VLerror(yylloc, "error: Repeat timeunit found and the initial "
                            "timeunit for this scope is missing.");
      } else if (scope->time_unit != val) {
            VLerror(yylloc, "error: Repeat timeunit does not match the "
                            "initial timeunit for this scope.");
      }
}

// Walk up parent_scope chain looking for a PScopeExtra whose time_unit/prec
// has been explicitly set (is_default=false).  PClass is a PScopeExtra but
// usually has no `timescale` directive of its own; the timescale should
// come from the enclosing module or compilation-unit scope.  Without this
// walk, time literals like `100ns` inside class methods evaluate to 0
// because they see PClass's default time_unit=0 (PClass scope's parents
// haven't been finalized yet when the time literal is parsed).
static PScopeExtra* find_scopex_with_explicit_time_unit_(LexicalScope*scope)
{
      PScopeExtra*best = 0;
      LexicalScope*cur = scope;
      while (cur) {
            if (PScopeExtra*sx = dynamic_cast<PScopeExtra*>(cur)) {
                  if (!best) best = sx;
                  if (!sx->time_unit_is_default) return sx;
            }
            cur = cur->parent_scope();
      }
      return best;
}

static PScopeExtra* find_scopex_with_explicit_time_prec_(LexicalScope*scope)
{
      PScopeExtra*best = 0;
      LexicalScope*cur = scope;
      while (cur) {
            if (PScopeExtra*sx = dynamic_cast<PScopeExtra*>(cur)) {
                  if (!best) best = sx;
                  if (!sx->time_prec_is_default) return sx;
            }
            cur = cur->parent_scope();
      }
      return best;
}

int pform_get_timeunit()
{
      PScopeExtra*scopex = find_scopex_with_explicit_time_unit_(lexical_scope);
      assert(scopex);
      // If we couldn't find any scope with an explicit time_unit, fall
      // back to the global pform_time_unit set by the most recent
      // `timescale directive (if any).  Without this, time literals
      // parsed during a class body whose parent module hasn't yet been
      // finalized see scope->time_unit=0.
      if (scopex->time_unit_is_default && pform_timescale_file != 0)
            return pform_time_unit;
      return scopex->time_unit;
}

int pform_get_timeprec()
{
      PScopeExtra*scopex = find_scopex_with_explicit_time_prec_(lexical_scope);
      assert(scopex);
      if (scopex->time_prec_is_default && pform_timescale_file != 0)
            return pform_time_prec;
      return scopex->time_precision;
}

void pform_set_timeprec(const char*txt, bool initial_decl)
{
      int val;

      if (get_time_unit_prec(txt, val, false)) return;

      PScopeExtra*scope = dynamic_cast<PScopeExtra*>(lexical_scope);
      if (!scope)
	    return;

      if (initial_decl) {
            scope->time_precision = val;
            scope->time_prec_is_local = true;
            scope->time_prec_is_default = false;
            allow_timeprec_decl = false;
      } else if (!scope->time_prec_is_local) {
            VLerror(yylloc, "error: Repeat timeprecision found and the initial "
                            "timeprecision for this scope is missing.");
      } else if (scope->time_precision != val) {
            VLerror(yylloc, "error: Repeat timeprecision does not match the "
                            "initial timeprecision for this scope.");
      }
}

verinum* pform_verinum_with_size(verinum*siz, verinum*val,
				 const char*file, unsigned lineno)
{
      assert(siz->is_defined());
      unsigned long size = siz->as_ulong();

      if (size == 0) {
	    cerr << file << ":" << lineno << ": error: Sized numeric constant "
		    "must have a size greater than zero." << endl;
	    error_count += 1;
      }

      verinum::V pad;

      if (val->len() == 0) {
	    pad = verinum::Vx;
      } else {

	    switch (val->get(val->len()-1)) {
		case verinum::Vz:
		  pad = verinum::Vz;
		  break;
		case verinum::Vx:
		  pad = verinum::Vx;
		  break;
		default:
		  pad = verinum::V0;
		  break;
	    }
      }

      verinum*res = new verinum(pad, size, true);

      unsigned copy = val->len();
      if (res->len() < copy)
	    copy = res->len();

      for (unsigned idx = 0 ;  idx < copy ;  idx += 1) {
	    res->set(idx, val->get(idx));
      }

      res->has_sign(val->has_sign());

      bool trunc_flag = false;
      for (unsigned idx = copy ;  idx < val->len() ;  idx += 1) {
	    if (val->get(idx) != pad) {
		  trunc_flag = true;
		  break;
	    }
      }

      if (trunc_flag) {
	    cerr << file << ":" << lineno << ": warning: Numeric constant "
		 << "truncated to " << copy << " bits." << endl;
      }

      delete siz;
      delete val;
      return res;
}

void pform_startmodule(const struct vlltype&loc, const char*name,
		       bool program_block, bool is_interface,
		       LexicalScope::lifetime_t lifetime,
		       list<named_pexpr_t>*attr)
{
      if (! pform_cur_module.empty() && !gn_system_verilog()) {
	    cerr << loc << ": error: Module definition " << name
		 << " cannot nest into module " << pform_cur_module.front()->mod_name() << "." << endl;
	    error_count += 1;
      }


      if (lifetime != LexicalScope::INHERITED) {
	    pform_requires_sv(loc, "Default subroutine lifetime");
      }

      if (gn_system_verilog() && ! pform_cur_module.empty()) {
	    if (pform_cur_module.front()->program_block) {
		  cerr << loc << ": error: module, program, or interface "
				 "declarations are not allowed in program "
				 "blocks." << endl;
		  error_count += 1;
	    }
	    if (pform_cur_module.front()->is_interface
		&& !(program_block || is_interface)) {
		  cerr << loc << ": error: module declarations are not "
				 "allowed in interfaces." << endl;
		  error_count += 1;
	    }
      }

      perm_string lex_name = lex_strings.make(name);
      Module*cur_module = new Module(lexical_scope, lex_name);
      cur_module->program_block = program_block;
      cur_module->is_interface = is_interface;
      cur_module->default_lifetime = find_lifetime(lifetime);

      FILE_NAME(cur_module, loc);

      cur_module->library_flag = pform_library_flag;

      pform_cur_module.push_front(cur_module);

      allow_timeunit_decl = true;
      allow_timeprec_decl = true;

      pform_generate_single_item = false;

      add_local_symbol(lexical_scope, lex_name, cur_module);

      lexical_scope = cur_module;

      pform_bind_attributes(cur_module->attributes, attr);
}

void pform_start_parameter_port_list()
{
      pform_in_parameter_port_list = true;
      pform_peek_scope()->has_parameter_port_list = true;
}

void pform_end_parameter_port_list()
{
      pform_in_parameter_port_list = false;
}

/*
 * This function is called by the parser to make a simple port
 * reference. This is a name without a .X(...), so the internal name
 * should be generated to be the same as the X.
 */
Module::port_t* pform_module_port_reference(const struct vlltype&loc,
					    perm_string name)
{
      Module::port_t*ptmp = new Module::port_t;
      PEIdent*tmp = new PEIdent(name, loc.lexical_pos);
      FILE_NAME(tmp, loc);
      ptmp->name = name;
      ptmp->expr.push_back(tmp);
      ptmp->default_value = 0;

      return ptmp;
}

void pform_module_set_ports(vector<Module::port_t*>*ports)
{
      assert(! pform_cur_module.empty());

	/* The parser parses ``module foo()'' as having one
	   unconnected port, but it is really a module with no
	   ports. Fix it up here. */
      if (ports && (ports->size() == 1) && ((*ports)[0] == 0)) {
	    delete ports;
	    ports = 0;
      }

      if (ports != 0) {
	    pform_cur_module.front()->ports = *ports;
	    delete ports;
      }
}

void pform_endmodule(const char*name, bool inside_celldefine,
                     Module::UCDriveType uc_drive_def)
{
	// The parser will not call pform_endmodule() without first
	// calling pform_startmodule(). Thus, it is impossible for the
	// pform_cur_module stack to be empty at this point.
      assert(! pform_cur_module.empty());
      Module*cur_module  = pform_cur_module.front();
      pform_cur_module.pop_front();
      perm_string mod_name = cur_module->mod_name();

	/* M9: named property/sequence declarations and the default
	   disable are module-scoped. */
      pform_sva_module_done();

	/* IEEE 1800-2017 14.12: a `default clocking <id>;` item must name
	   a clocking block declared in this scope. (Declaration forms
	   register the block themselves, so only the reference form can
	   leave a dangling name.) */
      if (!cur_module->default_clocking.nil()
	  && (cur_module->clocking_blocks.find(cur_module->default_clocking)
	      == cur_module->clocking_blocks.end())) {
	    ostringstream msg;
	    msg << "error: default clocking block `"
		<< cur_module->default_clocking
		<< "' is not declared in `" << mod_name << "'.";
	    VLerror(msg.str().c_str());
	    cur_module->default_clocking = perm_string();
      }

	// Oops, there may be some sort of nesting problem. If
	// SystemVerilog is activated, it is possible for modules to
	// be nested. But if the nested module is broken, the parser
	// will recover and treat is as an invalid module item,
	// leaving the pform_cur_module stack in an inconsistent
	// state. For example, this:
	//    module foo;
	//      module bar blah blab blah error;
	//    endmodule
	// may leave the pform_cur_module stack with the dregs of the
	// bar module. Try to find the foo module in the stack, and
	// print error messages as we go.
      if (strcmp(name, mod_name) != 0) {
	    while (!pform_cur_module.empty()) {
		  Module*tmp_module = pform_cur_module.front();
		  perm_string tmp_name = tmp_module->mod_name();
		  pform_cur_module.pop_front();
		  ostringstream msg;
		  msg << "error: Module " << mod_name
		      << " was nested within " << tmp_name
		      << " but broken.";
		  VLerror(msg.str().c_str());

		  ivl_assert(*cur_module, lexical_scope == cur_module);
		  pform_pop_scope();
		  delete cur_module;

		  cur_module = tmp_module;
		  mod_name = tmp_name;
		  if (strcmp(name, mod_name) == 0)
			break;
	    }
      }
      assert(strcmp(name, mod_name) == 0);

      cur_module->is_cell = inside_celldefine;
      cur_module->uc_drive = uc_drive_def;

	// If this is a root module, then there is no parent module
	// and we try to put this newly defined module into the global
	// root list of modules. Otherwise, this is a nested module
	// and we put it into the parent module scope to be elaborated
	// if needed.
      map<perm_string,Module*>&use_module_map = (pform_cur_module.empty())
	    ? pform_modules
	    : pform_cur_module.front()->nested_modules;

      map<perm_string,Module*>::const_iterator test =
	    use_module_map.find(mod_name);

      if (test != use_module_map.end()) {
	    ostringstream msg;
	    msg << "error: Module " << name << " was already declared here: "
		<< test->second->get_fileline() << endl;
	    VLerror(msg.str().c_str());
      } else {
	    use_module_map[mod_name] = cur_module;
      }

	// The current lexical scope should be this module by now.
      ivl_assert(*cur_module, lexical_scope == cur_module);
      pform_pop_scope();
}

void pform_genvars(const struct vlltype&li, list<pform_ident_t>*names)
{
      list<pform_ident_t>::const_iterator cur;
      for (cur = names->begin(); cur != names->end() ; ++cur) {
	    PGenvar*genvar = new PGenvar();
	    FILE_NAME(genvar, li);

	    if (pform_cur_generate) {
		  add_local_symbol(pform_cur_generate, cur->first, genvar);
		  pform_cur_generate->genvars[cur->first] = genvar;
	    } else {
		  add_local_symbol(pform_cur_module.front(), cur->first, genvar);
		  pform_cur_module.front()->genvars[cur->first] = genvar;
	    }
      }

      delete names;
}

static unsigned detect_directly_nested_generate()
{
      if (pform_cur_generate && pform_generate_single_item)
	    switch (pform_cur_generate->scheme_type) {
		case PGenerate::GS_CASE_ITEM:
		  // fallthrough
		case PGenerate::GS_CONDIT:
		  // fallthrough
		case PGenerate::GS_ELSE:
		  pform_cur_generate->directly_nested = true;
		  return pform_cur_generate->id_number;
		default:
		  break;
	    }

      return ++lexical_scope->generate_counter;
}

void pform_start_generate_for(const struct vlltype&li,
			      bool local_index,
			      char*ident1, PExpr*init,
			      PExpr*test,
			      char*ident2, PExpr*next)
{
      PGenerate*gen = new PGenerate(lexical_scope, ++lexical_scope->generate_counter);
      lexical_scope = gen;

      FILE_NAME(gen, li);

      pform_cur_generate = gen;

      pform_cur_generate->scheme_type = PGenerate::GS_LOOP;

      pform_cur_generate->local_index = local_index;
      pform_cur_generate->loop_index = lex_strings.make(ident1);
      pform_cur_generate->loop_init = init;
      pform_cur_generate->loop_test = test;
      pform_cur_generate->loop_step = next;

      if (strcmp(ident1, ident2)) {
	    cerr << li << ": error: "
	         << "A generate \"loop\" requires the initialization genvar ("
	         << ident1 << ") to match the iteration genvar ("
	         << ident2 << ")." << endl;
	    error_count += 1;
      }

      delete[]ident1;
      delete[]ident2;
}

void pform_start_generate_if(const struct vlltype&li, PExpr*test)
{
      unsigned id_number = detect_directly_nested_generate();

      PGenerate*gen = new PGenerate(lexical_scope, id_number);
      lexical_scope = gen;

      FILE_NAME(gen, li);

      pform_cur_generate = gen;

      pform_cur_generate->scheme_type = PGenerate::GS_CONDIT;

      pform_cur_generate->loop_init = 0;
      pform_cur_generate->loop_test = test;
      pform_cur_generate->loop_step = 0;

      conditional_block_names.push_front(set<perm_string>());
}

void pform_start_generate_else(const struct vlltype&li)
{
      ivl_assert(li, pform_cur_generate);
      ivl_assert(li, pform_cur_generate->scheme_type == PGenerate::GS_CONDIT);

      PGenerate*cur = pform_cur_generate;
      pform_endgenerate(false);

      PGenerate*gen = new PGenerate(lexical_scope, cur->id_number);
      lexical_scope = gen;

      FILE_NAME(gen, li);

      pform_cur_generate = gen;

      pform_cur_generate->scheme_type = PGenerate::GS_ELSE;

      pform_cur_generate->loop_init = 0;
      pform_cur_generate->loop_test = cur->loop_test;
      pform_cur_generate->loop_step = 0;
}

/*
 * The GS_CASE version of the PGenerate contains only case items. The
 * items in turn contain the generated items themselves.
 */
void pform_start_generate_case(const struct vlltype&li, PExpr*expr)
{
      unsigned id_number = detect_directly_nested_generate();

      PGenerate*gen = new PGenerate(lexical_scope, id_number);
      lexical_scope = gen;

      FILE_NAME(gen, li);

      pform_cur_generate = gen;

      pform_cur_generate->scheme_type = PGenerate::GS_CASE;

      pform_cur_generate->loop_init = 0;
      pform_cur_generate->loop_test = expr;
      pform_cur_generate->loop_step = 0;

      conditional_block_names.push_front(set<perm_string>());
}

/*
 * The named block generate case.
 */
void pform_start_generate_nblock(const struct vlltype&li, char*name)
{
      PGenerate*gen = new PGenerate(lexical_scope, ++lexical_scope->generate_counter);
      lexical_scope = gen;

      FILE_NAME(gen, li);

      pform_cur_generate = gen;

      pform_cur_generate->scheme_type = PGenerate::GS_NBLOCK;

      pform_cur_generate->loop_init = 0;
      pform_cur_generate->loop_test = 0;
      pform_cur_generate->loop_step = 0;

      pform_cur_generate->scope_name = lex_strings.make(name);
      delete[]name;

      add_local_symbol(pform_cur_generate->parent_scope(),
                       pform_cur_generate->scope_name,
                       pform_cur_generate);
}

/*
 * The generate case item is a special case schema that takes its id
 * from the case schema that it is a part of. The idea is that the
 * case schema can only instantiate exactly one item, so the items
 * need not have a unique number.
 */
void pform_generate_case_item(const struct vlltype&li, list<PExpr*>*expr_list)
{
      ivl_assert(li, pform_cur_generate);
      ivl_assert(li, pform_cur_generate->scheme_type == PGenerate::GS_CASE);

      PGenerate*gen = new PGenerate(lexical_scope, pform_cur_generate->id_number);
      lexical_scope = gen;

      FILE_NAME(gen, li);

      gen->directly_nested = pform_cur_generate->directly_nested;

      pform_cur_generate = gen;

      pform_cur_generate->scheme_type = PGenerate::GS_CASE_ITEM;

      pform_cur_generate->loop_init = 0;
      pform_cur_generate->loop_test = 0;
      pform_cur_generate->loop_step = 0;

      if (expr_list != 0) {
	    list<PExpr*>::iterator expr_cur = expr_list->begin();
	    pform_cur_generate->item_test.resize(expr_list->size());
	    for (unsigned idx = 0 ; idx < expr_list->size() ; idx += 1) {
		  pform_cur_generate->item_test[idx] = *expr_cur;
		  ++ expr_cur;
	    }
	    ivl_assert(li, expr_cur == expr_list->end());
      }
}

void pform_generate_block_name(const char*name)
{
      assert(pform_cur_generate != 0);
      assert(pform_cur_generate->scope_name == 0);
      perm_string scope_name = lex_strings.make(name);
      pform_cur_generate->scope_name = scope_name;

      if (pform_cur_generate->scheme_type == PGenerate::GS_CONDIT
       || pform_cur_generate->scheme_type == PGenerate::GS_ELSE
       || pform_cur_generate->scheme_type == PGenerate::GS_CASE_ITEM) {

            if (conditional_block_names.front().count(scope_name))
                  return;

            conditional_block_names.front().insert(scope_name);
      }

      LexicalScope*parent_scope = pform_cur_generate->parent_scope();
      assert(parent_scope);
      if (pform_cur_generate->scheme_type == PGenerate::GS_CASE_ITEM)
	      // Skip over the PGenerate::GS_CASE container.
	    parent_scope = parent_scope->parent_scope();

      add_local_symbol(parent_scope, scope_name, pform_cur_generate);
}

void pform_endgenerate(bool end_conditional)
{
      assert(pform_cur_generate != 0);
      assert(! pform_cur_module.empty());

      if (end_conditional)
            conditional_block_names.pop_front();

	// If there is no explicit block name then generate a temporary
	// name. This will be replaced by the correct name later, once
	// we know all the explicit names in the surrounding scope. If
	// the naming scheme used here is changed, PGenerate::elaborate
	// must be changed to match.
      if (pform_cur_generate->scope_name == 0) {
	    char tmp[16];
	    snprintf(tmp, sizeof tmp, "$gen%u", pform_cur_generate->id_number);
	    pform_cur_generate->scope_name = lex_strings.make(tmp);
      }

	// The current lexical scope should be this generate construct by now
      ivl_assert(*pform_cur_generate, lexical_scope == pform_cur_generate);
      pform_pop_scope();

      PGenerate*parent_generate = dynamic_cast<PGenerate*>(lexical_scope);
      if (parent_generate) {
	    assert(pform_cur_generate->scheme_type == PGenerate::GS_CASE_ITEM
		   || parent_generate->scheme_type != PGenerate::GS_CASE);
	    parent_generate->generate_schemes.push_back(pform_cur_generate);
      } else {
	    assert(pform_cur_generate->scheme_type != PGenerate::GS_CASE_ITEM);
	    pform_cur_module.front()->generate_schemes.push_back(pform_cur_generate);
      }
      pform_cur_generate = parent_generate;
}

void pform_make_elab_task(const struct vlltype&li,
                          perm_string name,
                          const list<named_pexpr_t> &params)
{
      PCallTask*elab_task = new PCallTask(name, params);
      FILE_NAME(elab_task, li);

      lexical_scope->elab_tasks.push_back(elab_task);
}

MIN_TYP_MAX min_typ_max_flag = TYP;
unsigned min_typ_max_warn = 10;

PExpr* pform_select_mtm_expr(PExpr*min, PExpr*typ, PExpr*max)
{
      PExpr*res = 0;

      switch (min_typ_max_flag) {
	  case MIN:
	    res = min;
	    delete typ;
	    delete max;
	    break;
	  case TYP:
	    res = typ;
	    delete min;
	    delete max;
	    break;
	  case MAX:
	    res = max;
	    delete min;
	    delete typ;
	    break;
      }

      if (min_typ_max_warn > 0) {
	    cerr << res->get_fileline() << ": warning: Choosing ";
	    switch (min_typ_max_flag) {
		case MIN:
		  cerr << "min";
		  break;
		case TYP:
		  cerr << "typ";
		  break;
		case MAX:
		  cerr << "max";
		  break;
	    }

	    cerr << " expression." << endl;
	    min_typ_max_warn -= 1;
      }

      return res;
}

static void process_udp_table(PUdp*udp, list<string>*table,
			      const struct vlltype&loc)
{
      const bool synchronous_flag = udp->sequential;

	/* Interpret and check the table entry strings, to make sure
	   they correspond to the inputs, output and output type. Make
	   up vectors for the fully interpreted result that can be
	   placed in the PUdp object.

	   The table strings are made up by the parser to be two or
	   three substrings separated by ':', i.e.:

	   0101:1:1  (synchronous device entry)
	   0101:0    (combinational device entry)

	   The parser doesn't check that we got the right kind here,
	   so this loop must watch out. */
      std::vector<string> &input   = udp->tinput;
      std::vector<char>   &current = udp->tcurrent;
      std::vector<char>   &output  = udp->toutput;

      input.resize(table->size());
      current.resize(table->size());
      output.resize(table->size());

      { unsigned idx = 0;
        for (list<string>::iterator cur = table->begin() ;
             cur != table->end() ; ++cur , idx += 1) {
	      string tmp = *cur;

		/* Pull the input values from the string. */
	      if (tmp.find(':') != (udp->ports.size()-1)) {
		    cerr << loc << ": error: "
		         << "The UDP input port count (" << (udp->ports.size()-1)
		         << ") does not match the number of input table entries ("
		         << tmp.find(':') << ") in primitive \""
		         << udp->name_ << "\"." << endl;
		    error_count += 1;
		    break;
	      }
	      input[idx] = tmp.substr(0, udp->ports.size()-1);
	      tmp = tmp.substr(udp->ports.size()-1);


		/* If this is a synchronous device, get the current
		   output string. */
	      if (synchronous_flag) {
		    assert(tmp[0] == ':');
		    assert(tmp.size() == 4);
		    current[idx] = tmp[1];
		    tmp = tmp.substr(2);

	      }

		/* Finally, extract the desired output. */
	      assert(tmp[0] == ':');
	      assert(tmp.size() == 2);
	      output[idx] = tmp[1];
	}
      }

}

void pform_make_udp(const struct vlltype&loc, perm_string name,
		    list<pform_ident_t>*parms, vector<PWire*>*decl,
		    list<string>*table, Statement*init_expr)
{
      unsigned local_errors = 0;
      ivl_assert(loc, !parms->empty());

      ivl_assert(loc, decl);

	/* Put the declarations into a map, so that I can check them
	   off with the parameters in the list. If the port is already
	   in the map, merge the port type. I will rebuild a list
	   of parameters for the PUdp object. */
      map<perm_string,PWire*> defs;
      for (unsigned idx = 0 ;  idx < decl->size() ;  idx += 1) {

	    perm_string port_name = (*decl)[idx]->basename();

	    if (PWire*cur = defs[port_name]) {
		  ivl_assert(loc, (*decl)[idx]);
		  if ((*decl)[idx]->get_port_type() != NetNet::PIMPLICIT) {
			bool rc = cur->set_port_type((*decl)[idx]->get_port_type());
			ivl_assert(loc, rc);
		  }
		  if ((*decl)[idx]->get_wire_type() != NetNet::IMPLICIT) {
			bool rc = cur->set_wire_type((*decl)[idx]->get_wire_type());
			ivl_assert(loc, rc);
		  }

	    } else {
		  defs[port_name] = (*decl)[idx];
	    }
      }


	/* Put the parameters into a vector of wire descriptions. Look
	   in the map for the definitions of the name. In this loop,
	   the parms list in the list of ports in the port list of the
	   UDP declaration, and the defs map maps that name to a
	   PWire* created by an input or output declaration. */
      std::vector<PWire*> pins(parms->size());
      std::vector<perm_string> pin_names(parms->size());
      { list<pform_ident_t>::iterator cur;
        unsigned idx;
        for (cur = parms->begin(), idx = 0
		   ; cur != parms->end()
		   ; ++ idx, ++ cur) {
	      pins[idx] = defs[cur->first];
	      pin_names[idx] = cur->first;
	}
      }

	/* Check that the output is an output and the inputs are
	   inputs. I can also make sure that only the single output is
	   declared a register, if anything. The possible errors are:

	      -- an input port (not the first) is missing an input
	         declaration.

	      -- An input port is declared output.

	*/
      ivl_assert(loc, pins.size() > 0);
      do {
	    if (pins[0] == 0) {
		  cerr << loc << ": error: "
		       << "Output port of primitive " << name
		       << " missing output declaration." << endl;
		  cerr << loc << ":      : "
		       << "Try: output " << pin_names[0] << ";"
		       << endl;
		  error_count += 1;
		  local_errors += 1;
		  break;
	    }
	    if (pins[0]->get_port_type() != NetNet::POUTPUT) {
		  cerr << loc << ": error: "
		       << "The first port of a primitive"
		       << " must be an output." << endl;
		  cerr << loc << ":      : "
		       << "Try: output " << pin_names[0] << ";"
		       << endl;
		  error_count += 1;
		  local_errors += 1;
		  break;;
	    }
      } while (0);

      for (unsigned idx = 1 ;  idx < pins.size() ;  idx += 1) {
	    if (pins[idx] == 0) {
		  cerr << loc << ": error: "
		       << "Port " << (idx+1)
		       << " of primitive " << name << " missing"
		       << " input declaration." << endl;
		  cerr << loc << ":      : "
		       << "Try: input " << pin_names[idx] << ";"
		       << endl;
		  error_count += 1;
		  local_errors += 1;
		  continue;
	    }
	    if (pins[idx]->get_port_type() != NetNet::PINPUT) {
		  cerr << loc << ": error: "
		       << "Input port " << (idx+1)
		       << " of primitive " << name
		       << " has an output (or missing) declaration." << endl;
		  cerr << loc << ":      : "
		       << "Note that only the first port can be an output."
		       << endl;
		  cerr << loc << ":      : "
		       << "Try \"input " << name << ";\""
		       << endl;
		  error_count += 1;
		  local_errors += 1;
		  continue;
	    }

	    if (pins[idx]->get_wire_type() == NetNet::REG) {
		  cerr << loc << ": error: "
		       << "Port " << (idx+1)
		       << " of primitive " << name << " is an input port"
		       << " with a reg declaration." << endl;
		  cerr << loc << ":      : "
		       << "primitive inputs cannot be reg."
		       << endl;
		  error_count += 1;
		  local_errors += 1;
		  continue;
	    }
      }

      if (local_errors > 0) {
	    delete parms;
	    delete decl;
	    delete table;
	    delete init_expr;
	    return;
      }


	/* Verify the "initial" statement, if present, to be sure that
	   it only assigns to the output and the output is
	   registered. Then save the initial value that I get. */
      verinum::V init = verinum::Vx;
      if (init_expr) {
	      // XXXX
	    ivl_assert(loc, pins[0]->get_wire_type() == NetNet::REG);

	    const PAssign*pa = dynamic_cast<PAssign*>(init_expr);
	    ivl_assert(*init_expr, pa);

	    const PEIdent*id = dynamic_cast<const PEIdent*>(pa->lval());
	    ivl_assert(*init_expr, id);

	      // XXXX
	      //ivl_assert(*init_expr, id->name() == pins[0]->name());

	    const PENumber*np = dynamic_cast<const PENumber*>(pa->rval());
	    ivl_assert(*init_expr, np);

	    init = np->value()[0];
      }

	// Put the primitive into the primitives table
      if (pform_primitives[name]) {
	    VLwarn("warning: UDP primitive already exists.");

      } else {
	    PUdp*udp = new PUdp(name, parms->size());
	    FILE_NAME(udp, loc);

	      // Detect sequential udp.
	    if (pins[0]->get_wire_type() == NetNet::REG)
		  udp->sequential = true;

	      // Make the port list for the UDP
	    for (unsigned idx = 0 ;  idx < pins.size() ;  idx += 1)
		  udp->ports[idx] = pins[idx]->basename();

	    process_udp_table(udp, table, loc);
	    udp->initial  = init;

	    pform_primitives[name] = udp;
      }


	/* Delete the excess tables and lists from the parser. */
      delete parms;
      delete decl;
      delete table;
      delete init_expr;
}

void pform_make_udp(const struct vlltype&loc, perm_string name,
		    bool synchronous_flag, const pform_ident_t&out_name,
		    PExpr*init_expr, list<pform_ident_t>*parms,
		    list<string>*table)
{

      std::vector<PWire*> pins(parms->size() + 1);

	/* Make the PWire for the output port. */
      pins[0] = new PWire(out_name.first, out_name.second,
			  synchronous_flag? NetNet::REG : NetNet::WIRE,
			  NetNet::POUTPUT);
      FILE_NAME(pins[0], loc);

	/* Make the PWire objects for the input ports. */
      { list<pform_ident_t>::iterator cur;
        unsigned idx;
        for (cur = parms->begin(), idx = 1
		   ;  cur != parms->end()
		   ;  idx += 1, ++ cur) {
	      ivl_assert(loc, idx < pins.size());
	      pins[idx] = new PWire(cur->first, cur->second, NetNet::WIRE,
				    NetNet::PINPUT);
	      FILE_NAME(pins[idx], loc);
	}
	ivl_assert(loc, idx == pins.size());
      }

	/* Verify the initial expression, if present, to be sure that
	   it only assigns to the output and the output is
	   registered. Then save the initial value that I get. */
      verinum::V init = verinum::Vx;
      if (init_expr) {
	      // XXXX
	    ivl_assert(*init_expr, pins[0]->get_wire_type() == NetNet::REG);

	    const PAssign*pa = dynamic_cast<PAssign*>(init_expr);
	    ivl_assert(*init_expr, pa);

	    const PEIdent*id = dynamic_cast<const PEIdent*>(pa->lval());
	    ivl_assert(*init_expr, id);

	      // XXXX
	      //ivl_assert(*init_expr, id->name() == pins[0]->name());

	    const PENumber*np = dynamic_cast<const PENumber*>(pa->rval());
	    ivl_assert(*init_expr, np);

	    init = np->value()[0];
      }

	// Put the primitive into the primitives table
      if (pform_primitives[name]) {
	    ostringstream msg;
	    msg << "error: Primitive " << name << " was already declared here: "
		<< pform_primitives[name]->get_fileline() << endl;
	      // Some compilers warn if there is just a single C string.
	    VLerror(loc, msg.str().c_str(), "");

      } else {
	    PUdp*udp = new PUdp(name, pins.size());
	    FILE_NAME(udp, loc);

	      // Detect sequential udp.
	    udp->sequential = synchronous_flag;

	      // Make the port list for the UDP
	    for (unsigned idx = 0 ;  idx < pins.size() ;  idx += 1)
		  udp->ports[idx] = pins[idx]->basename();

	    ivl_assert(loc, udp);
	    if (table) {
		  process_udp_table(udp, table, loc);
		  udp->initial  = init;

		  pform_primitives[name] = udp;
	    } else {
		  ostringstream msg;
		  msg << "error: Invalid table for UDP primitive " << name
		      << "." << endl;
		    // Some compilers warn if there is just a single C string.
		  VLerror(loc, msg.str().c_str(), "");
	    }
      }

      delete parms;
      delete table;
      delete init_expr;
}

/*
 * This function attaches a range to a given name. The function is
 * only called by the parser within the scope of the net declaration,
 * and the name that I receive only has the tail component.
 */
static void pform_set_net_range(PWire *wire,
			        const vector_type_t *vec_type,
				PWSRType rt = SR_NET,
				std::list<named_pexpr_t>*attr = 0)
{
      pform_bind_attributes(wire->attributes, attr, true);

      if (!vec_type)
	    return;

      const list<pform_range_t> *range = vec_type->pdims.get();
      if (range)
	    wire->set_range(*range, rt);
      wire->set_signed(vec_type->signed_flag);
}

/*
 * This is invoked to make a named event. This is the declaration of
 * the event, and not necessarily the use of it.
 */
static void pform_make_event(const struct vlltype&loc, const pform_ident_t&name)
{
      PEvent*event = new PEvent(name.first, name.second);
      FILE_NAME(event, loc);

      add_local_symbol(lexical_scope, name.first, event);
      lexical_scope->events[name.first] = event;
}

void pform_make_events(const struct vlltype&loc, const list<pform_ident_t>*names)
{
      for (auto cur = names->begin() ;  cur != names->end() ; ++ cur ) {
	    pform_make_event(loc, *cur);
      }

      delete names;
}

/*
 * pform_makegates is called when a list of gates (with the same type)
 * are ready to be instantiated. The function runs through the list of
 * gates and calls the pform_makegate function to make the individual gate.
 */
static void pform_makegate(PGBuiltin::Type type,
			   struct str_pair_t str,
			   const list<PExpr*>*delay,
			   const lgate&info,
			   list<named_pexpr_t>*attr)
{
      if (info.parms_by_name) {
	    cerr << info.get_fileline() << ": error: Gates do not have port names."
		 << endl;
	    error_count += 1;
	    return;
      }

      if (info.parms) {
	    for (list<PExpr*>::iterator cur = info.parms->begin()
		       ; cur != info.parms->end() ; ++cur) {
		  pform_declare_implicit_nets(*cur);
	    }
      }

      perm_string dev_name = lex_strings.make(info.name);
      PGBuiltin*cur = new PGBuiltin(type, dev_name, info.parms, delay);
      cur->set_ranges(info.ranges);

	// The pform_makegates() that calls me will take care of
	// deleting the attr pointer, so tell the
	// pform_bind_attributes function to keep the attr object.
      pform_bind_attributes(cur->attributes, attr, true);

      cur->strength0(str.str0);
      cur->strength1(str.str1);
      cur->set_line(info);

      if (pform_cur_generate) {
	    if (dev_name != "") add_local_symbol(pform_cur_generate, dev_name, cur);
	    pform_cur_generate->add_gate(cur);
      } else {
	    if (dev_name != "") add_local_symbol(pform_cur_module.front(), dev_name, cur);
	    pform_cur_module.front()->add_gate(cur);
      }
}

void pform_makegates(const struct vlltype&loc,
		     PGBuiltin::Type type,
		     struct str_pair_t str,
		     const list<PExpr*>*delay,
		     std::vector<lgate>*gates,
		     list<named_pexpr_t>*attr)
{
      ivl_assert(loc, !pform_cur_module.empty());
      if (pform_cur_module.front()->program_block) {
	    cerr << loc << ": error: Gates and switches may not be instantiated in "
		 << "program blocks." << endl;
	    error_count += 1;
      }
      if (pform_cur_module.front()->is_interface) {
	    cerr << loc << ": error: Gates and switches may not be instantiated in "
		 << "interfaces." << endl;
	    error_count += 1;
      }

      for (unsigned idx = 0 ;  idx < gates->size() ;  idx += 1) {
	    pform_makegate(type, str, delay, (*gates)[idx], attr);
      }

      if (attr) delete attr;
      delete gates;
}

/*
 * A module is different from a gate in that there are different
 * constraints, and sometimes different syntax. The X_modgate
 * functions handle the instantiations of modules (and UDP objects) by
 * making PGModule objects.
 *
 * The first pform_make_modgate handles the case of a module
 * instantiated with ports passed by position. The "wires" is an
 * ordered array of port expressions.
 *
 * The second pform_make_modgate handles the case of a module
 * instantiated with ports passed by name. The "bind" argument is the
 * ports matched with names.
 */
static void pform_make_modgate(perm_string type,
			       perm_string name,
			       struct parmvalue_t*overrides,
			       list<PExpr*>*wires,
			       list<pform_range_t>*ranges,
			       const LineInfo&li,
			       std::list<named_pexpr_t>*attr)
{
      for (list<PExpr*>::iterator idx = wires->begin()
		 ; idx != wires->end() ; ++idx) {
	    pform_declare_implicit_nets(*idx);
      }

      PGModule*cur = new PGModule(type, name, wires);
      cur->set_line(li);
      cur->set_ranges(ranges);

      if (overrides && overrides->by_name) {
	    unsigned cnt = overrides->by_name->size();
	    named_pexpr_t *byname = new named_pexpr_t[cnt];

	    std::copy(overrides->by_name->begin(), overrides->by_name->end(),
		      byname);

	    cur->set_parameters(byname, cnt);

      } else if (overrides && overrides->by_order) {
	    cur->set_parameters(overrides->by_order);
      }

      if (pform_cur_generate) {
	    if (name != "") add_local_symbol(pform_cur_generate, name, cur);
	    pform_cur_generate->add_gate(cur);
      } else {
	    if (name != "") add_local_symbol(pform_cur_module.front(), name, cur);
	    pform_cur_module.front()->add_gate(cur);
      }
      pform_bind_attributes(cur->attributes, attr);
}

static void pform_make_modgate(perm_string type,
			       perm_string name,
			       struct parmvalue_t*overrides,
			       list<named_pexpr_t>*bind,
			       list<pform_range_t>*ranges,
			       const LineInfo&li,
			       std::list<named_pexpr_t>*attr)
{
      unsigned npins = bind->size();
      named_pexpr_t *pins = new named_pexpr_t[npins];
      for (const auto &bind_cur : *bind)
            pform_declare_implicit_nets(bind_cur.parm);

      std::copy(bind->begin(), bind->end(), pins);

      PGModule*cur = new PGModule(type, name, pins, npins);
      cur->set_line(li);
      cur->set_ranges(ranges);

      if (overrides && overrides->by_name) {
	    unsigned cnt = overrides->by_name->size();
	    named_pexpr_t *byname = new named_pexpr_t[cnt];

	    std::copy(overrides->by_name->begin(), overrides->by_name->end(),
		      byname);

	    cur->set_parameters(byname, cnt);

      } else if (overrides && overrides->by_order) {

	    cur->set_parameters(overrides->by_order);
      }

      if (pform_cur_generate) {
	    add_local_symbol(pform_cur_generate, name, cur);
	    pform_cur_generate->add_gate(cur);
      } else {
	    add_local_symbol(pform_cur_module.front(), name, cur);
	    pform_cur_module.front()->add_gate(cur);
      }
      pform_bind_attributes(cur->attributes, attr);
}

void pform_make_modgates(const struct vlltype&loc,
			 perm_string type,
			 struct parmvalue_t*overrides,
			 std::vector<lgate>*gates,
			 std::list<named_pexpr_t>*attr)
{
	// SystemVerilog user-type declarations at module scope (e.g. `foo_t x;`)
	// parse through the same no-port shape as degenerate module instances.
	// If the left token is a visible type and every item is a no-port
	// instance, reinterpret the whole construct as a variable declaration.
	//
	// Also handles parameterized built-in class types like `mailbox #(T) m;`
	// where overrides contains the type parameter.
      {
	    typedef_t*decl_type = pform_test_type_identifier(loc, type);
	    // Parameterized built-in class types (mailbox #(T)) are reinterpreted
	    // as variable declarations even when overrides is non-null, provided
	    // the type is a known built-in class.
	    // If the name resolves to a type (class, typedef, built-in), treat
	    // it as a variable declaration regardless of parameter overrides.
	    if (decl_type) {
		  bool declaration_like = true;
		  std::list<decl_assignment_t*>*decls =
			new std::list<decl_assignment_t*>;
		  for (unsigned idx = 0 ; idx < gates->size() ; idx += 1) {
			lgate&cur = (*gates)[idx];
			if (cur.parms || cur.parms_by_name) {
			      declaration_like = false;
			      break;
			}

			decl_assignment_t*decl = new decl_assignment_t;
			decl->name = { lex_strings.make(cur.name), loc.lexical_pos };
			if (cur.ranges) {
			      decl->index.swap(*cur.ranges);
			      delete cur.ranges;
			      cur.ranges = 0;
			}
			decls->push_back(decl);
		  }

		  if (declaration_like) {
			typeref_t*dtype = new typeref_t(decl_type);
			FILE_NAME(dtype, loc);
			pform_make_var(loc, decls, dtype, attr, false);
			delete gates;
			return;
		  }

		  for (std::list<decl_assignment_t*>::iterator cur = decls->begin()
			     ; cur != decls->end() ; ++cur)
			delete *cur;
		  delete decls;
	    }
      }

	// The grammer should not allow module gates to happen outside
	// an active module. But if really bad input errors combine in
	// an ugly way with error recovery, then catch this
	// implausible situation and return an error.
      if (pform_cur_module.empty()) {
	    cerr << loc << ": internal error: "
		 << "Module instantiations outside module scope are not possible."
		 << endl;
	    error_count += 1;
	    delete gates;
	    return;
      }
      ivl_assert(loc, !pform_cur_module.empty());

	// Detect some more realistic errors.

      if (pform_cur_module.front()->program_block) {
	    cerr << loc << ": error: Module instantiations are not allowed in "
		 << "program blocks." << endl;
	    error_count += 1;
      }
      if (pform_cur_module.front()->is_interface) {
	    /* Interface instantiation inside interfaces is allowed in SV LRM.
	       Accept it silently; elaboration may warn if it cannot resolve. */
      }

      for (unsigned idx = 0 ;  idx < gates->size() ;  idx += 1) {
	    lgate cur = (*gates)[idx];
	    perm_string cur_name = lex_strings.make(cur.name);

	    if (cur.parms_by_name) {
		  pform_make_modgate(type, cur_name, overrides,
				     cur.parms_by_name, cur.ranges,
				     cur, attr);

	    } else if (cur.parms) {

		    /* If there are no parameters, the parser will be
		       tricked into thinking it is one empty
		       parameter. This fixes that. */
		  if ((cur.parms->size() == 1) && (cur.parms->front() == 0)) {
			delete cur.parms;
			cur.parms = new list<PExpr*>;
		  }
		  pform_make_modgate(type, cur_name, overrides,
				     cur.parms, cur.ranges,
				     cur, attr);

	    } else {
		  list<PExpr*>*wires = new list<PExpr*>;
		  pform_make_modgate(type, cur_name, overrides,
				     wires, cur.ranges,
				     cur, attr);
	    }
      }

      delete gates;
}

/*
 * SystemVerilog bind directives (IEEE 1800-2017 23.11). A bind
 * directive adds a module instantiation into a TARGET module (or
 * interface) definition, so that every instance of the target
 * elaborates the bound instance exactly as if it were written inside
 * the target's body. Port connection expressions therefore resolve
 * against the target's internal names, which is the point of bind:
 * attaching checkers/monitors to a design without editing it.
 *
 * A bind may be parsed before its target module is defined (even in
 * a different source file), so directives are collected in a pending
 * list and applied by pform_apply_binds() once all files are parsed.
 */
struct pending_bind_t {
      LineInfo li;
      perm_string target;
      perm_string type;
      struct parmvalue_t*overrides;
      std::vector<lgate>*gates;
};
static vector<pending_bind_t> pending_binds;

void pform_bind_directive(const struct vlltype&loc,
			  perm_string target,
			  perm_string type,
			  struct parmvalue_t*overrides,
			  std::vector<lgate>*gates)
{
      pending_bind_t cur;
      FILE_NAME(&cur.li, loc);
      cur.target = target;
      cur.type = type;
      cur.overrides = overrides;
      cur.gates = gates;
      pending_binds.push_back(cur);
}

static void bind_apply_one(Module*scope, pending_bind_t&bind)
{
      for (unsigned idx = 0 ; idx < bind.gates->size() ; idx += 1) {
	    lgate&cur = (*bind.gates)[idx];
	    perm_string cur_name = lex_strings.make(cur.name);

	      // Unlike an in-body instantiation, bind port expressions
	      // must reference names that already exist inside the
	      // target, so no implicit nets are declared here. The
	      // expressions resolve as if written at the END of the
	      // target body (the bind may even be in another file), so
	      // relocate identifier lexical positions past the
	      // declaration-before-use check.
	    PGModule*gate;
	    if (cur.parms_by_name) {
		  unsigned npins = cur.parms_by_name->size();
		  named_pexpr_t*pins = new named_pexpr_t[npins];
		  std::copy(cur.parms_by_name->begin(),
			    cur.parms_by_name->end(), pins);
		  for (unsigned pdx = 0 ; pdx < npins ; pdx += 1) {
			if (pins[pdx].parm)
			      pins[pdx].parm->reloc_lexical_pos_bind();
		  }
		  gate = new PGModule(bind.type, cur_name, pins, npins);
	    } else {
		  list<PExpr*>*wires = cur.parms;
		  if (wires && wires->size() == 1 && wires->front() == 0) {
			  /* The parser reports an empty port list as one
			     null parameter. Fix that. */
			delete wires;
			wires = new list<PExpr*>;
		  }
		  if (wires == 0)
			wires = new list<PExpr*>;
		  for (list<PExpr*>::iterator wdx = wires->begin()
			     ; wdx != wires->end() ; ++wdx) {
			if (*wdx) (*wdx)->reloc_lexical_pos_bind();
		  }
		  gate = new PGModule(bind.type, cur_name, wires);
	    }
	    gate->set_line(bind.li);
	    gate->set_ranges(cur.ranges);

	    if (cur.ranges) {
		  for (list<pform_range_t>::iterator rdx = cur.ranges->begin()
			     ; rdx != cur.ranges->end() ; ++rdx) {
			if (rdx->first) rdx->first->reloc_lexical_pos_bind();
			if (rdx->second) rdx->second->reloc_lexical_pos_bind();
		  }
	    }

	    if (bind.overrides && bind.overrides->by_name) {
		  unsigned cnt = bind.overrides->by_name->size();
		  named_pexpr_t*byname = new named_pexpr_t[cnt];
		  std::copy(bind.overrides->by_name->begin(),
			    bind.overrides->by_name->end(), byname);
		  for (unsigned pdx = 0 ; pdx < cnt ; pdx += 1) {
			if (byname[pdx].parm)
			      byname[pdx].parm->reloc_lexical_pos_bind();
		  }
		  gate->set_parameters(byname, cnt);
	    } else if (bind.overrides && bind.overrides->by_order) {
		  for (list<PExpr*>::iterator odx = bind.overrides->by_order->begin()
			     ; odx != bind.overrides->by_order->end() ; ++odx) {
			if (*odx) (*odx)->reloc_lexical_pos_bind();
		  }
		  gate->set_parameters(bind.overrides->by_order);
	    }

	    if (cur_name != "")
		  add_local_symbol(scope, cur_name, gate);
	    scope->add_gate(gate);
      }
}

void pform_apply_binds(void)
{
      for (vector<pending_bind_t>::iterator cur = pending_binds.begin()
		 ; cur != pending_binds.end() ; ++cur) {

	    map<perm_string,Module*>::iterator match
		  = pform_modules.find(cur->target);
	    if (match == pform_modules.end()) {
		  cerr << cur->li.get_fileline() << ": error: "
		       << "bind target module/interface '" << cur->target
		       << "' is not defined in this compilation." << endl;
		  error_count += 1;
		  continue;
	    }
	    if (cur->type == cur->target) {
		  cerr << cur->li.get_fileline() << ": error: "
		       << "bind of module '" << cur->type
		       << "' into itself would recurse forever." << endl;
		  error_count += 1;
		  continue;
	    }
	    if (match->second->program_block) {
		  cerr << cur->li.get_fileline() << ": error: "
		       << "bind target '" << cur->target
		       << "' is a program block; module instantiations "
		       << "are not allowed in program blocks." << endl;
		  error_count += 1;
		  continue;
	    }

	    bind_apply_one(match->second, *cur);
      }
      pending_binds.clear();
}

static PGAssign* pform_make_pgassign(PExpr*lval, PExpr*rval,
			      list<PExpr*>*del,
			      struct str_pair_t str)
{
        /* Implicit declaration of nets on the LHS of a continuous
           assignment was introduced in IEEE1364-2001. */
      if (generation_flag != GN_VER1995)
            pform_declare_implicit_nets(lval);

      list<PExpr*>*wires = new list<PExpr*>;
      wires->push_back(lval);
      wires->push_back(rval);

      PGAssign*cur;

      if (del == 0)
	    cur = new PGAssign(wires);
      else
	    cur = new PGAssign(wires, del);

      cur->strength0(str.str0);
      cur->strength1(str.str1);

      if (pform_cur_generate)
	    pform_cur_generate->add_gate(cur);
      else
	    pform_cur_module.front()->add_gate(cur);

      return cur;
}

void pform_make_pgassign_list(const struct vlltype&loc,
			      list<PExpr*>*alist,
			      list<PExpr*>*del,
			      struct str_pair_t str)
{
      ivl_assert(loc, alist->size() % 2 == 0);
      while (! alist->empty()) {
	    PExpr*lval = alist->front(); alist->pop_front();
	    PExpr*rval = alist->front(); alist->pop_front();
	    PGAssign*tmp = pform_make_pgassign(lval, rval, del, str);
	    FILE_NAME(tmp, loc);
      }
}

/*
 * This function makes the initial assignment to a variable as given
 * in the source. It handles the case where a variable is assigned
 * where it is declared, e.g.
 *
 *    reg foo = <expr>;
 *
 * In Verilog-2001 this is only supported at the module level, and is
 * equivalent to the combination of statements:
 *
 *    reg foo;
 *    initial foo = <expr>;
 *
 * In SystemVerilog, variable initializations are allowed in any scope.
 * For static variables, initializations are performed before the start
 * of simulation. For automatic variables, initializations are performed
 * each time the enclosing block is entered. Here we store the variable
 * assignments in the current scope, and later elaboration creates an
 * initialization block that will be executed at the appropriate time.
 *
 * This syntax is not part of the IEEE1364-1995 standard, but is
 * approved by OVI as enhancement BTF-B14.
 */
void pform_make_var_init(const struct vlltype&li, const pform_ident_t&name,
			 PExpr*expr)
{
      if (! pform_at_module_level() && !gn_system_verilog()) {
	    VLerror(li, "error: Variable declaration assignments are only "
                        "allowed at the module level.");
	    delete expr;
	    return;
      }

      PEIdent*lval = new PEIdent(name.first, name.second);
      FILE_NAME(lval, li);
      PAssign*ass = new PAssign(lval, expr, !gn_system_verilog(), true);
      FILE_NAME(ass, li);

      lexical_scope->var_inits.push_back(ass);
}

/*
 * This function makes a single signal (a wire, a reg, etc) as
 * requested by the parser. The name is unscoped, so I attach the
 * current scope to it (with the scoped_name function) and I try to
 * resolve it with an existing PWire in the scope.
 *
 * The wire might already exist because of an implicit declaration in
 * a module port, i.e.:
 *
 *     module foo (bar...
 *
 *         reg bar;
 *
 * The output (or other port direction indicator) may or may not have
 * been seen already, so I do not do any checking with it yet. But I
 * do check to see if the name has already been declared, as this
 * function is called for every declaration.
 */


static PWire* pform_get_or_make_wire(const struct vlltype&li,
				     const pform_ident_t&name,
				     NetNet::Type type,
				     NetNet::PortType ptype,
				     PWSRType rt)
{
      PWire *cur = 0;

	// If this is not a full declaration check if there is already a signal
	// with the same name that can be extended.
      if (rt != SR_BOTH)
	    cur = pform_get_wire_in_scope(name.first);

	// If the wire already exists but isn't yet fully defined,
	// carry on adding details.
      if (rt == SR_NET && cur && !cur->is_net()) {
	      // At the moment there can only be one location for the PWire, if
	      // there is both a port and signal declaration use the location of
	      // the signal.
	    FILE_NAME(cur, li);
	    cur->set_net(type);
            apply_var_lifetime_override_(cur);
	    return cur;
      }

      if (rt == SR_PORT && cur && !cur->is_port()) {
	    cur->set_port(ptype);
            apply_var_lifetime_override_(cur);
	    return cur;
      }

	// If the wire already exists and is fully defined, this
	// must be a redeclaration. Start again with a new wire.
	// The error will be reported when we add the new wire
	// to the scope. Do not delete the old wire - it will
	// remain in the local symbol map.

      cur = new PWire(name.first, name.second, type, ptype, rt);
      FILE_NAME(cur, li);
      apply_var_lifetime_override_(cur);

      pform_put_wire_in_scope(name.first, cur);

      return cur;
}


/*
 * This function is used by the parser when I have port definition of
 * the form like this:
 *
 *     input wire signed [7:0] nm;
 *
 * The port_type, type, signed_flag and range are known all at once,
 * so we can create the PWire object all at once instead of piecemeal
 * as is done for the old method.
 */
void pform_module_define_port(const struct vlltype&li,
			      const pform_ident_t&name,
			      NetNet::PortType port_kind,
			      NetNet::Type type,
			      data_type_t*vtype,
			      list<pform_range_t>*urange,
			      list<named_pexpr_t>*attr,
			      bool keep_attr)
{
      pform_check_net_data_type(li, type, vtype);

      PWire *cur = pform_get_or_make_wire(li, name, type, port_kind, SR_BOTH);

      pform_set_net_range(cur, dynamic_cast<vector_type_t*> (vtype), SR_BOTH);

      if (vtype)
	    cur->set_data_type(vtype);

      if (urange) {
	    cur->set_unpacked_idx(*urange);
	    delete urange;
      }

      pform_bind_attributes(cur->attributes, attr, keep_attr);
}

void pform_module_define_port(const struct vlltype&li,
			      list<pform_port_t>*ports,
			      NetNet::PortType port_kind,
			      NetNet::Type type,
			      data_type_t*vtype,
			      list<named_pexpr_t>*attr)
{
      for (list<pform_port_t>::iterator cur = ports->begin()
		 ; cur != ports->end() ; ++ cur ) {

	    data_type_t*use_type = vtype;

	    pform_module_define_port(li, cur->name, port_kind, type, use_type,
				     cur->udims, attr, true);

	    if (cur->expr)
		  pform_make_var_init(li, cur->name, cur->expr);
      }

      delete ports;
      delete attr;
}

/*
 * this is the basic form of pform_makewire. This takes a single simple
 * name, port type, net type, data type, and attributes, and creates
 * the variable/net. Other forms of pform_makewire ultimately call
 * this one to create the wire and stash it.
 */
PWire *pform_makewire(const vlltype&li, const pform_ident_t&name,
		      NetNet::Type type, const std::list<pform_range_t> *indices)
{
      PWire*cur = pform_get_or_make_wire(li, name, type, NetNet::NOT_A_PORT, SR_NET);
      ivl_assert(li, cur);

      if (indices && !indices->empty())
	    cur->set_unpacked_idx(*indices);

      return cur;
}

void pform_makewire(const struct vlltype&li,
		    std::list<PExpr*>*delay,
		    str_pair_t str,
		    std::list<decl_assignment_t*>*assign_list,
		    NetNet::Type type,
		    data_type_t*data_type,
		    list<named_pexpr_t>*attr,
		    bool is_const)
{
      if (is_compilation_unit(lexical_scope) && !gn_system_verilog()) {
	    VLerror(li, "error: Variable declarations must be contained within a module.");
	    return;
      }

      std::vector<PWire*> *wires = new std::vector<PWire*>;

      for (list<decl_assignment_t*>::iterator cur = assign_list->begin()
		 ; cur != assign_list->end() ; ++ cur) {
	    decl_assignment_t* curp = *cur;
	    PWire *wire = pform_makewire(li, curp->name, type, &curp->index);
	    wires->push_back(wire);
      }

      pform_set_data_type(li, data_type, wires, type, attr, is_const);

      while (! assign_list->empty()) {
	    decl_assignment_t*first = assign_list->front();
	    assign_list->pop_front();
            if (PExpr*expr = first->expr.release()) {
                  if (type == NetNet::REG || type == NetNet::IMPLICIT_REG) {
                        pform_make_var_init(li, first->name, expr);
                  } else {
		        PEIdent*lval = new PEIdent(first->name.first,
						   first->name.second);
		        FILE_NAME(lval, li);
		        PGAssign*ass = pform_make_pgassign(lval, expr, delay, str);
		        FILE_NAME(ass, li);
                  }
            }
	    delete first;
      }
}

/*
 * This function is called by the parser to create task ports. The
 * resulting wire (which should be a register) is put into a list to
 * be packed into the task parameter list.
 *
 * It is possible that the wire (er, register) was already created,
 * but we know that if the name matches it is a part of the current
 * task, so in that case I just assign direction to it.
 *
 * The following example demonstrates some of the issues:
 *
 *   task foo;
 *      input a;
 *      reg a, b;
 *      input b;
 *      [...]
 *   endtask
 *
 * This function is called when the parser matches the "input a" and
 * the "input b" statements. For ``a'', this function is called before
 * the wire is declared as a register, so I create the foo.a
 * wire. For ``b'', I will find that there is already a foo.b and I
 * just set the port direction. In either case, the ``reg a, b''
 * statement is caught by the block_item non-terminal and processed
 * there.
 *
 * Ports are implicitly type reg, because it must be possible for the
 * port to act as an l-value in a procedural assignment. It is obvious
 * for output and inout ports that the type is reg, because the task
 * only contains behavior (no structure) to a procedural assignment is
 * the *only* way to affect the output. It is less obvious for input
 * ports, but in practice an input port receives its value as if by a
 * procedural assignment from the calling behavior.
 *
 * This function also handles the input ports of function
 * definitions. Input ports to function definitions have the same
 * constraints as those of tasks, so this works fine. Functions have
 * no output or inout ports.
 */
vector<pform_tf_port_t>*pform_make_task_ports(const struct vlltype&loc,
				      NetNet::PortType pt,
				      data_type_t*vtype,
				      list<pform_port_t>*ports,
				      bool allow_implicit)
{
      ivl_assert(loc, pt != NetNet::PIMPLICIT && pt != NetNet::NOT_A_PORT);
      ivl_assert(loc, ports);

      vector<pform_tf_port_t>*res = new vector<pform_tf_port_t>(0);
      PWSRType rt = SR_BOTH;

      // If this is a non-ansi port declaration and the type is an implicit type
      // this is only a port declaration.
      const vector_type_t*vec_type = dynamic_cast<vector_type_t*>(vtype);
      if (allow_implicit && (!vtype || (vec_type && vec_type->implicit_flag)))
	    rt = SR_PORT;

      for (list<pform_port_t>::iterator cur = ports->begin();
	   cur != ports->end(); ++cur) {
	    PWire*curw = pform_get_or_make_wire(loc, cur->name,
						NetNet::IMPLICIT_REG, pt, rt);
	    if (rt == SR_BOTH)
		  curw->set_data_type(vtype);

	    pform_set_net_range(curw, vec_type, rt);

	    if (cur->udims) {
		  if (pform_requires_sv(loc, "Task/function port with unpacked dimensions"))
			curw->set_unpacked_idx(*cur->udims);
	    }

	    res->push_back(pform_tf_port_t(curw));
      }

      delete ports;
      return res;
}

/*
 * The parser calls this in the rule that matches increment/decrement
 * statements. The rule that does the matching creates a PEUnary with
 * all the information we need, but here we convert that expression to
 * a compressed assignment statement.
 */
PAssign* pform_compressed_assign_from_inc_dec(const struct vlltype&loc, PExpr*exp)
{
      PEUnary*expu = dynamic_cast<PEUnary*> (exp);
      ivl_assert(*exp, expu != 0);

      char use_op = 0;
      switch (expu->get_op()) {
	  case 'i':
	  case 'I':
	    use_op = '+';
	    break;
	  case 'd':
	  case 'D':
	    use_op = '-';
	    break;
	  default:
	    ivl_assert(*exp, 0);
	    break;
      }

      PExpr*lval = expu->get_expr();
      PExpr*rval = new PENumber(new verinum((uint64_t)1, 1));
      FILE_NAME(rval, loc);

      PAssign*tmp = new PAssign(lval, use_op, rval);
      FILE_NAME(tmp, loc);

      delete exp;
      return tmp;
}

PExpr* pform_genvar_inc_dec(const struct vlltype&loc, const char*name, bool inc_flag)
{
      pform_requires_sv(loc, "Increment/decrement operator");

      PExpr*lval = new PEIdent(lex_strings.make(name), loc.lexical_pos);
      PExpr*rval = new PENumber(new verinum(1));
      FILE_NAME(lval, loc);
      FILE_NAME(rval, loc);

      PEBinary*tmp = new PEBinary(inc_flag ? '+' : '-', lval, rval);
      FILE_NAME(tmp, loc);

      return tmp;
}

PExpr* pform_genvar_compressed(const struct vlltype &loc, const char *name,
			       char op, PExpr *rval)
{
      pform_requires_sv(loc, "Compressed assignment operator");

      PExpr *lval = new PEIdent(lex_strings.make(name), loc.lexical_pos);
      FILE_NAME(lval, loc);

      PExpr *expr;
      switch (op) {
	  case 'l':
	  case 'r':
	  case 'R':
	    expr = new PEBShift(op, lval, rval);
	    break;
	  default:
	    expr = new PEBinary(op, lval, rval);
	    break;
      }
      FILE_NAME(expr, loc);

      return expr;
}

void pform_set_attrib(perm_string name, perm_string key, char*value)
{
      if (PWire*cur = lexical_scope->wires_find(name)) {
	    cur->attributes[key] = new PEString(value);

      } else if (PGate*curg = pform_cur_module.front()->get_gate(name)) {
	    curg->attributes[key] = new PEString(value);

      } else {
	    delete[] value;
	    VLerror("error: Unable to match name for setting attribute.");

      }
}

/*
 * Set the attribute of a TYPE. This is different from an object in
 * that this applies to every instantiation of the given type.
 */
void pform_set_type_attrib(perm_string name, const string&key,
			   char*value)
{
      map<perm_string,PUdp*>::const_iterator udp = pform_primitives.find(name);
      if (udp == pform_primitives.end()) {
	    VLerror("error: Type name is not (yet) defined.");
	    delete[] value;
	    return;
      }

      (*udp).second ->attributes[key] = new PEString(value);
}

LexicalScope::range_t* pform_parameter_value_range(bool exclude_flag,
					     bool low_open, PExpr*low_expr,
					     bool hig_open, PExpr*hig_expr)
{
	// Detect +-inf and make the the *_open flags false to force
	// the range interpretation as inf.
      if (low_expr == 0) low_open = false;
      if (hig_expr == 0) hig_open = false;

      LexicalScope::range_t*tmp = new LexicalScope::range_t;
      tmp->exclude_flag = exclude_flag;
      tmp->low_open_flag = low_open;
      tmp->low_expr = low_expr;
      tmp->high_open_flag = hig_open;
      tmp->high_expr = hig_expr;
      tmp->next = 0;
      return tmp;
}

static void pform_set_type_parameter(const struct vlltype&loc, perm_string name,
				     const LexicalScope::range_t*value_range)
{
      pform_requires_sv(loc, "Type parameter");

      if (value_range)
	    VLerror(loc, "error: Type parameter must not have value range.");

      type_parameter_t *type = new type_parameter_t(name);
      pform_set_typedef(loc, name, type, 0);
}

void pform_set_parameter(const struct vlltype&loc,
			 perm_string name, bool is_local, bool is_type,
			 data_type_t*data_type, const list<pform_range_t>*udims,
			 PExpr*expr, LexicalScope::range_t*value_range)
{
      LexicalScope*scope = lexical_scope;
      if (is_compilation_unit(scope) && !gn_system_verilog()) {
	    VLerror(loc, "error: %s declarations must be contained within a module.",
		         is_local ? "localparam" : "parameter");
	    return;
      }

      if (expr == 0) {
	    if (is_local) {
		  VLerror(loc, "error: localparam must have a value.");
	    } else if (!pform_in_parameter_port_list) {
		  VLerror(loc, "error: parameter declared outside parameter "
			        "port list must have a default value.");
	    } else {
		  pform_requires_sv(loc, "parameter without default value");
	    }
      }

      vector_type_t*vt = dynamic_cast<vector_type_t*>(data_type);
      if (vt && vt->pdims && vt->pdims->size() > 1) {
	    if (!pform_requires_sv(loc, "packed array parameter")) {
		  return;
	    }
	    // Multi-dim packed parameter (e.g., logic [N-1:0][W-1:0] X = ...).
	    // Flatten the packed dims into a single combined range whose
	    // width is the product of the inner widths. The flattened param
	    // is stored as a flat bit-vector; multi-dim element indexing
	    // (e.g., X[i] returning an inner-width slice) is NOT preserved.
	    // This is sufficient for compile-only consumers (e.g., upstream
	    // packages that declare cipher SBOXes the testbench never
	    // exercises).
	    //
	    // When all bounds are constant we collapse to a numeric literal
	    // up front; otherwise we build a multiplicative expression that
	    // elaboration evaluates per parameter binding. This handles the
	    // common OpenTitan idiom `[NumCnt-1:0][Width-1:0]`.
	    uint64_t const_width = 1;
	    PExpr*expr_width = 0;
	    bool all_constants = true;
	    auto width_of = [&](const pform_range_t&dim) -> PExpr* {
		  // Build expression: (msb - lsb + 1)
		  PExpr*one = new PENumber(new verinum((uint64_t)1, 32));
		  return new PEBinary('+',
				new PEBinary('-', dim.first, dim.second),
				one);
	    };
	    for (const auto&dim : *vt->pdims) {
		  PENumber*hi = dynamic_cast<PENumber*>(dim.first);
		  PENumber*lo = dynamic_cast<PENumber*>(dim.second);
		  if (hi && lo) {
			long h = hi->value().as_long();
			long l = lo->value().as_long();
			long w = (h >= l) ? (h - l + 1) : (l - h + 1);
			if (w <= 0) {
			      all_constants = false;
			      break;
			}
			const_width *= (uint64_t)w;
		  } else {
			all_constants = false;
			PExpr*w = width_of(dim);
			expr_width = expr_width
				? new PEBinary('*', expr_width, w) : w;
		  }
	    }
	    PExpr*new_msb;
	    if (all_constants) {
		  new_msb = new PENumber(
			new verinum((uint64_t)(const_width - 1), 32));
	    } else {
		  // Combine const part with expr part: total_w = const_width * expr_width
		  PExpr*total_w;
		  if (expr_width && const_width != 1) {
			total_w = new PEBinary('*',
				    new PENumber(new verinum(const_width, 32)),
				    expr_width);
		  } else if (expr_width) {
			total_w = expr_width;
		  } else {
			total_w = new PENumber(new verinum(const_width, 32));
		  }
		  new_msb = new PEBinary('-', total_w,
				new PENumber(new verinum((uint64_t)1, 32)));
	    }
	    auto*new_pd = new std::list<pform_range_t>;
	    new_pd->push_back(pform_range_t(
		    new_msb,
		    new PENumber(new verinum((uint64_t)0, 32))));
	    vt->pdims.reset(new_pd);
      }

      if (udims) {
	    if (!pform_requires_sv(loc, "unpacked array parameter")) {
		  return;
	    }
	    // In SV mode: allow 1D unpacked array params; elements expanded at elaboration
      }

      bool overridable = !is_local;

      if (scope == pform_cur_generate && !is_local) {
	    if (!gn_system_verilog()) {
		  VLerror(loc, "parameter declarations are not permitted in generate blocks");
		  return;
	    }
	    // SystemVerilog allows `parameter` in generate blocks, but it has
	    // the same semantics as `localparam` in that scope.
	    overridable = false;
      }

      bool in_module = dynamic_cast<Module*>(scope) &&
		       scope == pform_cur_module.front();

      if (!pform_in_parameter_port_list && in_module &&
          scope->has_parameter_port_list)
	    overridable = false;

      if (pform_in_class())
	    overridable = false;

      Module::param_expr_t*parm = new Module::param_expr_t();
      FILE_NAME(parm, loc);

      if (is_type)
	    pform_set_type_parameter(loc, name, value_range);
      else
	    add_local_symbol(scope, name, parm);

      parm->expr = expr;
      parm->data_type = data_type;
      parm->range = value_range;
      parm->local_flag = is_local;
      parm->overridable = overridable;
      parm->type_flag = is_type;
      parm->lexical_pos = loc.lexical_pos;
      parm->udims = udims;

      bool new_parameter = (scope->parameters.find(name) == scope->parameters.end());
      scope->parameters[name] = parm;
      if (new_parameter)
	    scope->parameter_order.push_back(name);

      // Only a module keeps the position of the parameter.
      if (overridable && in_module)
	    pform_cur_module.front()->param_names.push_back(name);
}

void pform_set_specparam(const struct vlltype&loc, perm_string name,
			 list<pform_range_t>*range, PExpr*expr)
{
      ivl_assert(loc, !pform_cur_module.empty());
      Module*scope = pform_cur_module.front();
      if (scope != lexical_scope) {
	    delete range;
	    delete expr;
	    return;
      }

      ivl_assert(loc, expr);
      Module::param_expr_t*parm = new Module::param_expr_t();
      FILE_NAME(parm, loc);

      add_local_symbol(scope, name, parm);
      pform_cur_module.front()->specparams[name] = parm;

      parm->expr = expr;
      parm->range = 0;

      if (range) {
	    ivl_assert(loc, range->size() == 1);
	    parm->data_type = new vector_type_t(IVL_VT_LOGIC, false, range);
	    parm->range = 0;
      }
}

void pform_set_defparam(const pform_name_t&name, PExpr*expr)
{
      assert(expr);
      if (pform_cur_generate)
            pform_cur_generate->defparms.push_back(make_pair(name,expr));
      else
            pform_cur_module.front()->defparms.push_back(make_pair(name,expr));
}

void pform_make_let(const struct vlltype&loc,
                    perm_string name,
                    list<PLet::let_port*>*ports,
                    PExpr*expr)
{
      LexicalScope*scope =  pform_peek_scope();
      Module*mod = pform_cur_module.empty()? 0 : pform_cur_module.front();

	// let declarations are supported directly in module/interface
	// scope (the overwhelmingly common placement). Lets nested in
	// generate blocks or other scopes are a recorded corner.
      if (mod == 0 || pform_cur_generate != 0
	  || scope != static_cast<LexicalScope*>(mod)) {
	    cerr << loc.get_fileline() << ": sorry: let declaration `"
		 << name << "' outside direct module/interface scope is "
		 << "not supported yet; the let is dropped." << endl;
	    error_count += 1;
	    if (ports) {
		  for (list<PLet::let_port_t*>::iterator cur = ports->begin()
			     ; cur != ports->end() ; ++cur)
			delete *cur;
		  delete ports;
	    }
	    delete expr;
	    return;
      }

      if (mod->lets.count(name)) {
	    cerr << loc.get_fileline() << ": error: duplicate let "
		 << "declaration `" << name << "' in module `"
		 << mod->mod_name() << "'." << endl;
	    error_count += 1;
	    delete expr;
	    return;
      }

      PLet*res = new PLet(name, scope, ports, expr);
      FILE_NAME(res, loc);
      mod->lets[name] = res;
}

PLet::let_port_t* pform_make_let_port(data_type_t*data_type,
                                      perm_string name,
                                      list<pform_range_t>*range,
                                      PExpr*def)
{
      PLet::let_port_t*res = new PLet::let_port_t;

      res->type_ = data_type;
      res->name_ = name;
      res->range_ = range;
      res->def_ = def;

      return res;
}

/*
 * Specify paths.
 */
extern PSpecPath* pform_make_specify_path(const struct vlltype&li,
					  list<perm_string>*src, char pol,
					  bool full_flag, list<perm_string>*dst)
{
      PSpecPath*path = new PSpecPath(*src, *dst, pol, full_flag);
      FILE_NAME(path, li);

      delete src;
      delete dst;

      return path;
}

extern PSpecPath*pform_make_specify_edge_path(const struct vlltype&li,
					 int edge_flag, /*posedge==true */
					 list<perm_string>*src, char pol,
					 bool full_flag, list<perm_string>*dst,
					 PExpr*data_source_expression)
{
      PSpecPath*tmp = pform_make_specify_path(li, src, pol, full_flag, dst);
      tmp->edge = edge_flag;
      tmp->data_source_expression = data_source_expression;
      return tmp;
}

extern PSpecPath* pform_assign_path_delay(PSpecPath*path, list<PExpr*>*del)
{
      if (path == 0)
	    return 0;

      ivl_assert(*path, path->delays.empty());

      path->delays.resize(del->size());
      for (unsigned idx = 0 ;  idx < path->delays.size() ;  idx += 1) {
	    path->delays[idx] = del->front();
	    del->pop_front();
      }

      delete del;

      return path;
}


extern void pform_module_specify_path(PSpecPath*obj)
{
      if (obj == 0)
	    return;
      pform_cur_module.front()->specify_paths.push_back(obj);
}

/*
 * Timing checks.
 */
 extern PRecRem* pform_make_recrem(const struct vlltype&li,
			 PTimingCheck::event_t*reference_event,
			 PTimingCheck::event_t*data_event,
			 PExpr*setup_limit,
			 PExpr*hold_limit,
			 PTimingCheck::optional_args_t* args)
{
      ivl_assert(li, args);

      PRecRem*recrem = new PRecRem(
	      reference_event,
	      data_event,
	      setup_limit,
	      hold_limit,
	      args->notifier,
	      args->timestamp_cond,
	      args->timecheck_cond,
	      args->delayed_reference,
	      args->delayed_data
      );

      FILE_NAME(recrem, li);

      return recrem;
}
extern PSetupHold* pform_make_setuphold(const struct vlltype&li,
			 PTimingCheck::event_t*reference_event,
			 PTimingCheck::event_t*data_event,
			 PExpr*setup_limit,
			 PExpr*hold_limit,
			 PTimingCheck::optional_args_t* args)
{
      ivl_assert(li, args);

      PSetupHold*setuphold = new PSetupHold(
	      reference_event,
	      data_event,
	      setup_limit,
	      hold_limit,
	      args->notifier,
	      args->timestamp_cond,
	      args->timecheck_cond,
	      args->delayed_reference,
	      args->delayed_data
      );

      FILE_NAME(setuphold, li);

      return setuphold;
}

extern void pform_module_timing_check(PTimingCheck*obj)
{
      if (!obj)
	    return;

      pform_cur_module.front()->timing_checks.push_back(obj);
}


void pform_set_port_type(const struct vlltype&li,
			 list<pform_port_t>*ports,
			 NetNet::PortType pt,
			 data_type_t*dt,
			 list<named_pexpr_t>*attr)
{
      ivl_assert(li, pt != NetNet::PIMPLICIT && pt != NetNet::NOT_A_PORT);

      const vector_type_t *vt = dynamic_cast<vector_type_t*> (dt);

      bool have_init_expr = false;
      for (list<pform_port_t>::iterator cur = ports->begin()
		 ; cur != ports->end() ; ++ cur ) {

	    PWire *wire = pform_get_or_make_wire(li, cur->name,
						 NetNet::IMPLICIT, pt, SR_PORT);
	    pform_set_net_range(wire, vt, SR_PORT, attr);

	    if (cur->udims) {
		  cerr << li << ": warning: "
		       << "Array dimensions in incomplete port declarations "
		       << "are currently ignored." << endl;
		  cerr << li << ":        : "
		       << "The dimensions specified in the net or variable "
		       << "declaration will be used." << endl;
		  delete cur->udims;
	    }
	    if (cur->expr) {
		  have_init_expr = true;
		  delete cur->expr;
	    }
      }
      if (have_init_expr) {
	    cerr << li << ": error: "
		 << "Incomplete port declarations cannot be initialized."
		 << endl;
	    error_count += 1;
      }

      delete ports;
      delete dt;
      delete attr;
}

/*
 * This function detects the derived class for the given type and
 * dispatches the type to the proper subtype function.
 */
void pform_set_data_type(const struct vlltype&li, data_type_t*data_type,
			 std::vector<PWire*> *wires, NetNet::Type net_type,
			 list<named_pexpr_t>*attr, bool is_const)
{
      if (data_type == 0) {
	    VLerror(li, "internal error: data_type==0.");
	    ivl_assert(li, 0);
      }

      const vector_type_t*vec_type = dynamic_cast<vector_type_t*> (data_type);

      for (std::vector<PWire*>::iterator it= wires->begin();
	   it != wires->end() ; ++it) {
	    PWire *wire = *it;

	    pform_set_net_range(wire, vec_type);

	    // If these fail there is a bug somewhere else. pform_set_data_type()
	    // is only ever called on a fresh wire that already exists.
	    bool rc = wire->set_wire_type(net_type);
	    ivl_assert(li, rc);

	    wire->set_data_type(data_type);
	    wire->set_const(is_const);

	    pform_bind_attributes(wire->attributes, attr, true);
      }

      delete wires;
}

vector<PWire*>* pform_make_udp_input_ports(list<pform_ident_t>*names)
{
      vector<PWire*>*out = new vector<PWire*>(names->size());

      unsigned idx = 0;
      for (list<pform_ident_t>::iterator cur = names->begin()
		 ; cur != names->end() ; ++ cur ) {
	    PWire*pp = new PWire(cur->first, cur->second,
				 NetNet::IMPLICIT,
				 NetNet::PINPUT);
	    (*out)[idx] = pp;
	    idx += 1;
      }

      delete names;
      return out;
}

PProcess* pform_make_behavior(ivl_process_type_t type, Statement*st,
			      list<named_pexpr_t>*attr)
{
	// Add an implicit @* around the statement for the always_comb and
	// always_latch statements.
      if ((type == IVL_PR_ALWAYS_COMB) || (type == IVL_PR_ALWAYS_LATCH)) {
	    PEventStatement *tmp = new PEventStatement(true);
	    tmp->set_line(*st);
	    tmp->set_statement(st);
	    st = tmp;
      }

      PProcess*pp = new PProcess(type, st);

	// If we are in a part of the code where the meta-comment
	// synthesis translate_off is in effect, then implicitly add
	// the ivl_synthesis_off attribute to any behavioral code that
	// we run into.
      if (pform_mc_translate_flag == false) {
	    if (attr == 0) attr = new list<named_pexpr_t>;
	    named_pexpr_t tmp;
	    tmp.name = perm_string::literal("ivl_synthesis_off");
	    tmp.parm = 0;
	    attr->push_back(tmp);
      }

      pform_bind_attributes(pp->attributes, attr);

      pform_put_behavior_in_scope(pp);

      ivl_assert(*st, ! pform_cur_module.empty());
      if (pform_cur_module.front()->program_block &&
          ((type == IVL_PR_ALWAYS) || (type == IVL_PR_ALWAYS_COMB) ||
           (type == IVL_PR_ALWAYS_FF) || (type == IVL_PR_ALWAYS_LATCH))) {
	    cerr << st->get_fileline() << ": error: Always statements are not allowed"
		 << " in program blocks." << endl;
	    error_count += 1;
      }

      return pp;
}

void pform_start_modport_item(const struct vlltype&loc, const char*name)
{
      Module*scope = pform_cur_module.front();
      ivl_assert(loc, scope && scope->is_interface);
      ivl_assert(loc, pform_cur_modport == 0);

      perm_string use_name = lex_strings.make(name);
      pform_cur_modport = new PModport(use_name);
      FILE_NAME(pform_cur_modport, loc);

      add_local_symbol(scope, use_name, pform_cur_modport);
      scope->modports[use_name] = pform_cur_modport;

      delete[] name;
}

void pform_end_modport_item(const struct vlltype&loc)
{
      ivl_assert(loc, pform_cur_modport);
      pform_cur_modport = 0;
}

void pform_add_modport_tf_port(const struct vlltype&loc,
                               bool is_import, perm_string name)
{
      ivl_assert(loc, pform_cur_modport);
      if (is_import)
	    pform_cur_modport->import_ports.insert(name);
      else
	    pform_cur_modport->export_ports.insert(name);
}

void pform_add_modport_port(const struct vlltype&loc,
                            NetNet::PortType port_type,
                            perm_string name, PExpr*expr)
{
      ivl_assert(loc, pform_cur_modport);

      if (pform_cur_modport->simple_ports.find(name)
	  != pform_cur_modport->simple_ports.end()) {
	    cerr << loc << ": error: duplicate declaration of port '"
		 << name << "' in modport list '"
		 << pform_cur_modport->name() << "'." << endl;
	    error_count += 1;
      }
      pform_cur_modport->simple_ports[name] = make_pair(port_type, expr);
}

void pform_start_clocking_block(const struct vlltype&loc,
				const char*name,
				PEventStatement*event,
				bool is_default,
				bool is_global)
{
      Module*scope = pform_cur_module.front();
	/* IEEE 1800-2017 14.3: clocking blocks may be declared in a
	   module, interface, program, or checker. */
      ivl_assert(loc, scope);
      /* On parse error, a previous clocking block may not have been ended. Reset it. */
      if (pform_cur_clocking) pform_cur_clocking = 0;

      if (is_default && !scope->default_clocking.nil()) {
	    cerr << loc << ": error: multiple default clocking declarations "
		 << "in `" << scope->mod_name() << "' (IEEE 1800-2017 14.12 "
		 << "allows at most one per module, interface, or program)."
		 << endl;
	    error_count += 1;
	    delete[] name;
	    delete event;
	    return;
      }

      if (is_global && !scope->global_clocking.nil()) {
	    cerr << loc << ": error: multiple global clocking declarations "
		 << "in `" << scope->mod_name() << "' (IEEE 1800-2017 14.14 "
		 << "allows at most one per module or program)." << endl;
	    error_count += 1;
	    delete[] name;
	    delete event;
	    return;
      }

	/* An anonymous `default clocking @(event); ... endclocking`
	   (14.12) is registered under an internal name that no source
	   identifier can collide with. Same for an anonymous global
	   clocking (14.14). */
      perm_string use_name = name
	    ? lex_strings.make(name)
	    : (is_global ? perm_string::literal("$global_clocking")
			 : perm_string::literal("$default_clocking"));
      if (scope->clocking_blocks.find(use_name) != scope->clocking_blocks.end()) {
	    cerr << loc << ": error: duplicate declaration of clocking block `"
		 << use_name << "'." << endl;
	    error_count += 1;
	    delete[] name;
	    delete event;
	    return;
      }

      pform_cur_clocking = new Module::PClocking(use_name, event);
      pform_cur_clocking_is_global = is_global;
      FILE_NAME(pform_cur_clocking, loc);
      scope->clocking_blocks[use_name] = pform_cur_clocking;
      if (is_default)
	    scope->default_clocking = use_name;
      if (is_global)
	    scope->global_clocking = use_name;

      delete[] name;
}

void pform_set_default_clocking_ref(const struct vlltype&loc,
				    const char*name)
{
      Module*scope = pform_cur_module.front();
      ivl_assert(loc, scope);

      if (!scope->default_clocking.nil()) {
	    cerr << loc << ": error: multiple default clocking declarations "
		 << "in `" << scope->mod_name() << "' (IEEE 1800-2017 14.12 "
		 << "allows at most one per module, interface, or program)."
		 << endl;
	    error_count += 1;
	    delete[] name;
	    return;
      }

	/* Existence is validated in pform_endmodule so the referenced
	   block may be declared before or after this item. */
      scope->default_clocking = lex_strings.make(name);
      delete[] name;
}

void pform_add_clocking_signal(const struct vlltype&loc, perm_string name,
			       NetNet::PortType dir,
			       const pform_clocking_skew_t*in_skew,
			       const pform_clocking_skew_t*out_skew,
			       PExpr*decl_assign)
{
	/* The enclosing block open may have failed (duplicate name) or
	   been skipped on a parse error; drop the signal quietly — an
	   error has already been reported. */
      if (pform_cur_clocking == 0) return;

	/* IEEE 1800-2017 14.14: a global clocking declaration only
	   specifies the clocking event; it shall not contain clocking
	   items. */
      if (pform_cur_clocking_is_global) {
	    cerr << loc << ": error: global clocking blocks cannot "
		 << "declare clocking signals (IEEE 1800-2017 14.14)."
		 << endl;
	    error_count += 1;
	    return;
      }

      if (!pform_cur_clocking->add_signal(name, dir, in_skew, out_skew)) {
	    cerr << loc << ": error: duplicate signal `" << name
		 << "' in clocking block `" << pform_cur_clocking->name << "'." << endl;
	    error_count += 1;
	    return;
      }
      if (decl_assign)
	    pform_cur_clocking->decl_assigns[name] = decl_assign;
}

void pform_set_clocking_default_skews(const struct vlltype&loc,
				      const pform_clocking_skew_t*in_skew,
				      const pform_clocking_skew_t*out_skew)
{
      if (pform_cur_clocking == 0) return;
      pform_cur_clocking->set_default_skews(in_skew, out_skew);
}

void pform_end_clocking_block(const struct vlltype&loc)
{
      /* May be 0 if the block body had a parse error and was skipped */
      pform_cur_clocking = 0;
      pform_cur_clocking_is_global = false;
}

/* IEEE 1800-2017 14.16: `cb.out <= ##N v`. Lower the cycle-delayed
   clocking drive to the intra-assignment repeat-event form
   `lval <= repeat (N) @(<clocking prefix of lval>) v` — the value is
   captured now, the drive lands at the Nth clocking event (the @(cb)
   wait resolves through the clocking machinery, including the
   sampler-trigger redirect). Only the clockvar-prefix form is
   supported; the scalar default-clocking form is a sorry. */
Statement* pform_make_clocking_drive(const struct vlltype&loc,
				     PExpr*lval, PExpr*cycles, PExpr*rval)
{
      PEIdent*lid = dynamic_cast<PEIdent*>(lval);
      if (!lid) {
	    cerr << loc << ": sorry: `<= ##N` cycle-delay drives require "
		 << "a simple l-value." << endl;
	    error_count += 1;
	    PAssignNB*deg = new PAssignNB(lval, rval);
	    FILE_NAME(deg, loc);
	    return deg;
      }

	/* Scalar form `x <= ##N v` (14.16): cycles count the DEFAULT
	   clocking block of the enclosing scope, resolved at
	   elaboration via the $ivl_default_clock marker. */
      PExpr*ev_expr;
      if (lid->path().size() < 2) {
	    std::list<named_pexpr_t> no_parms;
	    PECallFunction*mark = new PECallFunction(
		  perm_string::literal("$ivl_default_clock"), no_parms);
	    FILE_NAME(mark, loc);
	    ev_expr = mark;
      } else {
	    pform_name_t cb_path = lid->path().name;
	    cb_path.pop_back();
	    PEIdent*cb_ident = lid->path().package
		  ? new PEIdent(lid->path().package, cb_path, lid->lexical_pos())
		  : new PEIdent(cb_path, lid->lexical_pos());
	    FILE_NAME(cb_ident, loc);
	    ev_expr = cb_ident;
      }
      PEEvent*ev = new PEEvent(PEEvent::ANYEDGE, ev_expr);
      std::vector<PEEvent*> evs;
      evs.push_back(ev);
      PEventStatement*ectl = new PEventStatement(evs);
      FILE_NAME(ectl, loc);

      PAssignNB*tmp = new PAssignNB(lval, cycles, ectl, rval);
      FILE_NAME(tmp, loc);
      return tmp;
}

/*
 * M9: core SVA engine (IEEE 1800-2017 clause 16, gaps G05/G06).
 *
 * Concurrent assertions lower at parse time to a synthesized clocked
 * checker built on the token-pipeline construction: an attempt token
 * is injected when the antecedent samples true and shifts through
 * 1-bit pipeline registers, checked against each consequent step at
 * its cycle offset. A single trailing ##[m:n] range is a parallel
 * window register bank: the awaited boolean satisfies every attempt
 * whose eligible window covers the current cycle; a token shifting
 * past the window end fails. This is deterministic, handles
 * overlapping attempts, and needs no runtime threads.
 *
 * Sampling model: step booleans are captured at the clocking event in
 * the Active region, before the NBA updates of that edge land — equal
 * to the Preponed (sampled) value for NBA-driven logic, which is the
 * norm in RTL. Blocking-assignment races against the clock edge are
 * outside this equivalence (they are races in event semantics too).
 *
 * Sampled-value functions ($rose/$fell/$stable/$changed/$past) inside
 * property expressions get real clocked-history semantics via
 * synthesized history registers (outside assertions they keep the
 * legacy VPI stubs).
 */

static std::map<perm_string, sva_property_t*> sva_module_properties;
static std::map<perm_string, std::vector<sva_seq_step_t>*> sva_module_sequences;
static PExpr* sva_default_disable = nullptr;
static unsigned sva_gensym_counter = 0;

/* M9D: parameterized named property/sequence declarations. The formal
   argument names are substituted with the actual argument expressions at
   each instantiation (signal/boolean formals only — a formal used as a
   delay bound is already a non-constant `##` and diagnosed at lowering). */
struct sva_param_seq_t {
      std::vector<perm_string> formals;
      std::vector<sva_seq_step_t>* body = nullptr;
};
struct sva_param_prop_t {
      std::vector<perm_string> formals;
      sva_property_t* body = nullptr;
};
static std::map<perm_string, sva_param_seq_t> sva_param_sequences;
static std::map<perm_string, sva_param_prop_t> sva_param_properties;

void pform_sva_set_default_disable(PExpr*expr)
{
      sva_default_disable = expr;
}

void pform_sva_sorry(const struct vlltype&loc, const char*what)
{
	/* Compile-progress: the assertion is dropped LOUDLY but the
	   compile continues, so SVA-heavy code (checkers, tlul_assert
	   shapes) still elaborates and runs its non-assertion logic.
	   This mirrors the fork-wide sorry convention. */
      cerr << loc << ": sorry: the SVA `" << what << "' operator is "
	   << "not supported by the assertion engine; the assertion "
	   << "is dropped (IEEE 1800-2017 clause 16)." << endl;
}

void pform_sva_declare_property(const struct vlltype&loc, const char*name,
				sva_property_t*prop)
{
      perm_string use_name = lex_strings.make(name);
      if (sva_module_properties.count(use_name)) {
	    cerr << loc << ": error: duplicate property declaration `"
		 << use_name << "'." << endl;
	    error_count += 1;
	    return;
      }
      sva_module_properties[use_name] = prop;
}

void pform_sva_declare_sequence(const struct vlltype&loc, const char*name,
				std::vector<sva_seq_step_t>*steps)
{
      perm_string use_name = lex_strings.make(name);
      if (sva_module_sequences.count(use_name)) {
	    cerr << loc << ": error: duplicate sequence declaration `"
		 << use_name << "'." << endl;
	    error_count += 1;
	    return;
      }
      sva_module_sequences[use_name] = steps;
}

/* M9D: parameterized named property/sequence declarations. */
void pform_sva_declare_property_p(const struct vlltype&loc, const char*name,
				  std::list<perm_string>*formals,
				  sva_property_t*prop)
{
      perm_string use_name = lex_strings.make(name);
      if (sva_param_properties.count(use_name) || sva_module_properties.count(use_name)) {
	    cerr << loc << ": error: duplicate property declaration `"
		 << use_name << "'." << endl;
	    error_count += 1;
	    delete formals;
	    return;
      }
      sva_param_prop_t rec;
      if (formals) { for (perm_string f : *formals) rec.formals.push_back(f); }
      rec.body = prop;
      sva_param_properties[use_name] = rec;
      delete formals;
}

void pform_sva_declare_sequence_p(const struct vlltype&loc, const char*name,
				  std::list<perm_string>*formals,
				  std::vector<sva_seq_step_t>*steps)
{
      perm_string use_name = lex_strings.make(name);
      if (sva_param_sequences.count(use_name) || sva_module_sequences.count(use_name)) {
	    cerr << loc << ": error: duplicate sequence declaration `"
		 << use_name << "'." << endl;
	    error_count += 1;
	    delete formals;
	    return;
      }
      sva_param_seq_t rec;
      if (formals) { for (perm_string f : *formals) rec.formals.push_back(f); }
      rec.body = steps;
      sva_param_sequences[use_name] = rec;
      delete formals;
}

void pform_sva_module_done(void)
{
      sva_module_properties.clear();
      sva_module_sequences.clear();
      sva_param_sequences.clear();
      sva_param_properties.clear();
      sva_default_disable = nullptr;
}

/* Structural clone for the expression shapes that appear in disable
   iff conditions and reusable named-property bodies. Returns nil for
   shapes it cannot copy; callers fall back to consume-once.

   When `subst` is non-null (M9D parameterized property/sequence
   instantiation), a bare single-name identifier that matches a formal
   is replaced with a fresh clone of the actual argument expression. */
static PExpr* sva_clone_subst_(PExpr*e,
			       const std::map<perm_string,PExpr*>*subst)
{
      if (!e) return nullptr;
      if (PEIdent*id = dynamic_cast<PEIdent*>(e)) {
	    if (subst && !id->path().package && id->path().name.size() == 1
		&& id->path().name.front().index.empty()) {
		  std::map<perm_string,PExpr*>::const_iterator it =
			subst->find(id->path().name.front().name);
		  if (it != subst->end())
			return sva_clone_subst_(it->second, nullptr);
	    }
	    PEIdent*cp = id->path().package
		  ? new PEIdent(id->path().package, id->path().name, id->lexical_pos())
		  : new PEIdent(id->path().name, id->lexical_pos());
	    cp->set_line(*e);
	    return cp;
      }
      if (PENumber*num = dynamic_cast<PENumber*>(e)) {
	    PENumber*cp = new PENumber(new verinum(num->value()));
	    cp->set_line(*e);
	    return cp;
      }
      if (PEUnary*un = dynamic_cast<PEUnary*>(e)) {
	    PExpr*sub = sva_clone_subst_(un->get_expr(), subst);
	    if (!sub) return nullptr;
	    PEUnary*cp = new PEUnary(un->get_op(), sub);
	    cp->set_line(*e);
	    return cp;
      }
      if (PEBinary*bin = dynamic_cast<PEBinary*>(e)) {
	    PExpr*l = sva_clone_subst_(bin->get_left(), subst);
	    PExpr*r = sva_clone_subst_(bin->get_right(), subst);
	    if (!l || !r) { delete l; delete r; return nullptr; }
	    PEBinary*cp;
	    if (dynamic_cast<PEBComp*>(e))
		  cp = new PEBComp(bin->get_op(), l, r);
	    else if (dynamic_cast<PEBLogic*>(e))
		  cp = new PEBLogic(bin->get_op(), l, r);
	    else if (dynamic_cast<PEBShift*>(e))
		  cp = new PEBShift(bin->get_op(), l, r);
	    else if (typeid(*e) == typeid(PEBinary))
		  cp = new PEBinary(bin->get_op(), l, r);
	    else { delete l; delete r; return nullptr; }
	    cp->set_line(*e);
	    return cp;
      }
      if (PETernary*ter = dynamic_cast<PETernary*>(e)) {
	    PExpr*c = sva_clone_subst_(ter->get_cond(), subst);
	    PExpr*t = sva_clone_subst_(ter->get_true(), subst);
	    PExpr*f = sva_clone_subst_(ter->get_false(), subst);
	    if (!c || !t || !f) { delete c; delete t; delete f; return nullptr; }
	    PETernary*cp = new PETernary(c, t, f);
	    cp->set_line(*e);
	    return cp;
      }
	/* System/sampled function calls ($rose/$past/…) with copyable
	   argument expressions — needed so a formal can appear inside a
	   sampled-value function of a parameterized body. */
      if (PECallFunction*cf = dynamic_cast<PECallFunction*>(e)) {
	    if (cf->path().package || cf->path().name.size() != 1)
		  return nullptr;
	    const std::vector<named_pexpr_t>&parms = cf->get_parms();
	    std::list<named_pexpr_t> np;
	    for (size_t k = 0 ; k < parms.size() ; k += 1) {
		  named_pexpr_t a;
		  a.name = parms[k].name;
		  if (parms[k].parm) {
			a.parm = sva_clone_subst_(parms[k].parm, subst);
			if (!a.parm) return nullptr;
		  }
		  np.push_back(a);
	    }
	    PECallFunction*cp = new PECallFunction(
		  peek_tail_name(cf->path().name), np);
	    cp->set_line(*e);
	    return cp;
      }
      return nullptr;
}

static PExpr* sva_clone_expr_(PExpr*e)
{
      return sva_clone_subst_(e, nullptr);
}

/* M9D: build a formal->actual substitution map from a call's arguments,
   checking arity. Returns false (diagnosed) on a mismatch or empty arg. */
static bool sva_build_subst_(const struct vlltype&loc, const char*what,
			     perm_string nm,
			     const std::vector<perm_string>&formals,
			     const std::vector<named_pexpr_t>&parms,
			     std::map<perm_string,PExpr*>&subst)
{
      if (parms.size() != formals.size()) {
	    cerr << loc << ": error: " << what << " `" << nm << "' expects "
		 << formals.size() << " argument(s), got " << parms.size()
		 << "." << endl;
	    error_count += 1;
	    return false;
      }
      for (size_t k = 0 ; k < formals.size() ; k += 1) {
	    if (!parms[k].parm) {
		  cerr << loc << ": error: " << what << " `" << nm
		       << "' argument " << (k+1) << " is empty." << endl;
		  error_count += 1;
		  return false;
	    }
	    subst[formals[k]] = parms[k].parm;
      }
      return true;
}

/* M9D: instantiate a parameterized sequence — clone its body with the
   formals substituted. Returns nullptr (diagnosed) on failure. */
static std::vector<sva_seq_step_t>*
sva_instantiate_seq_(const struct vlltype&loc, perm_string nm,
		     const sva_param_seq_t&decl,
		     const std::vector<named_pexpr_t>&parms)
{
      std::map<perm_string,PExpr*> subst;
      if (!sva_build_subst_(loc, "sequence", nm, decl.formals, parms, subst))
	    return nullptr;
      std::vector<sva_seq_step_t>*out = new std::vector<sva_seq_step_t>;
      for (size_t k = 0 ; k < decl.body->size() ; k += 1) {
	    sva_seq_step_t st = (*decl.body)[k];   /* copies delays */
	    st.expr = sva_clone_subst_((*decl.body)[k].expr, &subst);
	    if (!st.expr) {
		  cerr << loc << ": sorry: sequence `" << nm << "' has a body "
		       << "expression that cannot be instantiated with "
		       << "arguments; the assertion is dropped." << endl;
		  error_count += 1;
		  for (size_t j = 0 ; j < out->size() ; j += 1) delete (*out)[j].expr;
		  delete out;
		  return nullptr;
	    }
	    out->push_back(st);
      }
      return out;
}

/* M9D: clone a step list with a substitution applied (for property
   antecedent/consequent instantiation). Returns nullptr on failure. */
static std::vector<sva_seq_step_t>*
sva_clone_steps_subst_(const struct vlltype&loc,
		       const std::vector<sva_seq_step_t>*in,
		       const std::map<perm_string,PExpr*>&subst)
{
      if (!in) return nullptr;
      std::vector<sva_seq_step_t>*out = new std::vector<sva_seq_step_t>;
      for (size_t k = 0 ; k < in->size() ; k += 1) {
	    sva_seq_step_t st = (*in)[k];
	    st.expr = sva_clone_subst_((*in)[k].expr, &subst);
	    if (!st.expr) {
		  for (size_t j = 0 ; j < out->size() ; j += 1) delete (*out)[j].expr;
		  delete out;
		  (void)loc;
		  return nullptr;
	    }
	    out->push_back(st);
      }
      return out;
}

static PEIdent* sva_id_(const struct vlltype&loc, perm_string name)
{
      PEIdent*id = new PEIdent(name, loc.lexical_pos);
      FILE_NAME(id, loc);
      return id;
}

static PExpr* sva_bit_(const struct vlltype&loc, int v)
{
      verinum*n = new verinum(v ? verinum::V1 : verinum::V0, 1);
      PENumber*num = new PENumber(n);
      FILE_NAME(num, loc);
      return num;
}

static perm_string sva_make_reg_(const struct vlltype&loc, unsigned inst,
				 const char*what, unsigned idx,
				 bool wide32 = false)
{
      char buf[64];
      snprintf(buf, sizeof buf, "_ivl_sva%u_%s%u", inst, what, idx);
      perm_string name = lex_strings.make(buf);
      PWire*w = pform_makewire(loc, pform_ident_t(name, loc.lexical_pos),
			       NetNet::REG, nullptr);
      if (wide32 && w) {
	    std::list<pform_range_t> range;
	    pform_range_t r;
	    r.first = new PENumber(new verinum((uint64_t)31, 32));
	    r.second = new PENumber(new verinum((uint64_t)0, 32));
	    range.push_back(r);
	    w->set_range(range, SR_NET);
      }
      return name;
}

static Statement* sva_assign_(const struct vlltype&loc, perm_string lv, PExpr*rv)
{
      PAssign*a = new PAssign(sva_id_(loc, lv), rv);
      FILE_NAME(a, loc);
      return a;
}

static Statement* sva_block_(const struct vlltype&loc,
			     const std::vector<Statement*>&stmts)
{
      if (stmts.size() == 1) return stmts[0];
      PBlock*blk = new PBlock(PBlock::BL_SEQ);
      FILE_NAME(blk, loc);
      std::vector<Statement*>copy = stmts;
      blk->set_statement(copy);
      return blk;
}

/* Small expression/statement constructors used by the temporal-operator
   lowering (until family, within) below. */
static Statement* sva_if_(const struct vlltype&loc, PExpr*c,
			  Statement*t, Statement*e)
{
      PCondit*p = new PCondit(c, t, e);
      FILE_NAME(p, loc);
      return p;
}

static PExpr* sva_not_(const struct vlltype&loc, PExpr*e)
{
      PEUnary*u = new PEUnary('!', e);
      FILE_NAME(u, loc);
      return u;
}

static PExpr* sva_logic_(const struct vlltype&loc, char op,
			 PExpr*l, PExpr*r)
{
      PEBLogic*b = new PEBLogic(op, l, r);
      FILE_NAME(b, loc);
      return b;
}

/* M12/20.12: wrap a fail action so it only fires while assertions are
   enabled. `$assertoff`/`$assertkill` clear the global enable flag that
   `$ivl_sva_enabled()` returns; `$asserton` sets it. Gating the action
   (rather than the whole checker) keeps token/pipeline state advancing so
   re-enabling resumes cleanly. */
static Statement* sva_gate_(const struct vlltype&loc, Statement*action)
{
      if (!action) return action;
      std::list<named_pexpr_t> no_parms;
      PECallFunction*en = new PECallFunction(
	    perm_string::literal("$ivl_sva_enabled"), no_parms);
      FILE_NAME(en, loc);
      PCondit*c = new PCondit(en, action, nullptr);
      FILE_NAME(c, loc);
      return c;
}

/* M12B: build the one-time
   `$ivl_register_assertion(idx, "name", "file", line)` call that gives a
   synthesized concurrent-assertion checker a VPI identity
   (vpi_iterate(vpiAssertion, ...)). idx is the compile-time instance
   number, which together with the runtime scope identifies the
   assertion for callback reporting. Placed in the checker's zero-init
   initial block. */
static Statement* sva_register_stmt_(const struct vlltype&loc, unsigned inst)
{
      char nbuf[64];
      snprintf(nbuf, sizeof nbuf, "assert_L%d_%u", loc.first_line, inst);
      std::list<named_pexpr_t> args;
      named_pexpr_t a0;
      a0.parm = new PENumber(new verinum((uint64_t)inst, 32));
      args.push_back(a0);
      named_pexpr_t a1; a1.parm = new PEString(strdup(nbuf));
      args.push_back(a1);
      named_pexpr_t a2; a2.parm = new PEString(strdup(loc.text ? loc.text : ""));
      args.push_back(a2);
      named_pexpr_t a3;
      a3.parm = new PENumber(new verinum((uint64_t)loc.first_line, 32));
      args.push_back(a3);
      PCallTask*t = new PCallTask(
	    lex_strings.make("$ivl_register_assertion"), args);
      FILE_NAME(t, loc);
      return t;
}

/* Assertion callback reasons (IEEE 1800-2017 40.x; must match the
   cbAssertion* values in sv_vpi_user.h). */
static const int SVA_CB_SUCCESS = 607;   /* cbAssertionSuccess */
static const int SVA_CB_FAILURE = 608;   /* cbAssertionFailure */

/* M12B-cb: build `if ($ivl_assert_cb_active()) $ivl_assert_report(inst,
   reason);` — a synthesized checker reports a success or failure event,
   gated so nothing runs when no callback is registered. */
static Statement* sva_report_stmt_(const struct vlltype&loc, unsigned inst,
				   int reason)
{
      std::list<named_pexpr_t> args;
      named_pexpr_t a0;
      a0.parm = new PENumber(new verinum((uint64_t)inst, 32));
      args.push_back(a0);
      named_pexpr_t a1;
      a1.parm = new PENumber(new verinum((uint64_t)reason, 32));
      args.push_back(a1);
      PCallTask*rep = new PCallTask(
	    lex_strings.make("$ivl_assert_report"), args);
      FILE_NAME(rep, loc);

      std::list<named_pexpr_t> no_parms;
      PECallFunction*active = new PECallFunction(
	    perm_string::literal("$ivl_assert_cb_active"), no_parms);
      FILE_NAME(active, loc);
      PCondit*c = new PCondit(active, rep, nullptr);
      FILE_NAME(c, loc);
      return c;
}

/* M12B/M12B-cb: the effect of an assertion failure — the (enable-gated)
   user/default fail action, plus a cbAssertionFailure report. */
static Statement* sva_fail_action_(const struct vlltype&loc, unsigned inst,
				   Statement*action)
{
      std::vector<Statement*> v;
      v.push_back(sva_gate_(loc, action));
      v.push_back(sva_report_stmt_(loc, inst, SVA_CB_FAILURE));
      return sva_block_(loc, v);
}

/* $past(e, d) as a sampled-value function call the SVA rewrite pass
   (sva_rewrite_sampled_) expands into an explicit history chain. d<=0
   returns e unchanged (the current sample). */
static PExpr* sva_past_(const struct vlltype&loc, PExpr*e, long d)
{
      if (d <= 0) return e;
      std::list<named_pexpr_t> parms;
      named_pexpr_t a0; a0.parm = e; parms.push_back(a0);
      named_pexpr_t a1;
      a1.parm = new PENumber(new verinum((uint64_t)d, 32));
      parms.push_back(a1);
      PECallFunction*cf = new PECallFunction(
	    perm_string::literal("$past"), parms);
      FILE_NAME(cf, loc);
      return cf;
}

/*
 * M13: timing checks (IEEE 1800-2017 clause 31) synthesize to plain
 * checker processes at parse time, the same construction strategy as
 * the M8 clocking and M9 SVA engines. Each check records the last
 * occurrence time of its timestamp event in a synthesized realtime
 * variable and, at the timecheck event, compares the elapsed time
 * against the limit, reporting a violation with $display and toggling
 * the notifier register when one is given. Checks are ACTIVE when
 * specify blocks are enabled (-gspecify), consistent with path
 * delays; without -gspecify every check gets a loud "ignored"
 * warning instead of today's silence.
 *
 * Simultaneity fine points (31.4.1) and edge-descriptor event lists
 * (edge [01, 10]) are recorded corners: the former is a scheduling
 * race by construction, the latter gets a loud sorry.
 */
static unsigned tc_gensym_counter = 0;

static perm_string tc_make_real_(const struct vlltype&loc, unsigned inst,
				 const char*what)
{
      char buf[64];
      snprintf(buf, sizeof buf, "_ivl_tc%u_%s", inst, what);
      perm_string name = lex_strings.make(buf);

      list<decl_assignment_t*>*decls = new list<decl_assignment_t*>;
      decl_assignment_t*decl = new decl_assignment_t;
      decl->name = pform_ident_t(name, loc.lexical_pos);
      decl->expr.reset(new PEFNumber(new verireal(-1.0)));
      decls->push_back(decl);

      real_type_t*rtype = new real_type_t(real_type_t::REAL);
      FILE_NAME(rtype, loc);
      pform_make_var(loc, decls, rtype, nullptr, false);
      return name;
}

static PExpr* tc_realtime_(const struct vlltype&loc)
{
      PECallFunction*rt
	    = new PECallFunction(perm_string::literal("$realtime"));
      FILE_NAME(rt, loc);
      return rt;
}

static PExpr* tc_real_(const struct vlltype&loc, double v)
{
      PEFNumber*num = new PEFNumber(new verireal(v));
      FILE_NAME(num, loc);
      return num;
}

static PEIdent* tc_name_id_(const struct vlltype&loc, const pform_name_t&name)
{
      PEIdent*id = new PEIdent(name, loc.lexical_pos);
      FILE_NAME(id, loc);
      return id;
}

/* Build "@(edge sig) if (cond) <body>" as an always process. */
static void tc_always_at_(const struct vlltype&loc,
			  const PTimingCheck::event_t&ev,
			  Statement*body)
{
      PEEvent::edge_t edge = PEEvent::ANYEDGE;
      if (ev.posedge) edge = PEEvent::POSEDGE;
      if (ev.negedge) edge = PEEvent::NEGEDGE;

      if (ev.condition.get()) {
	    PExpr*cond = sva_clone_expr_(ev.condition.get());
	    if (cond == 0) {
		  cerr << loc.get_fileline() << ": sorry: this timing check "
		       << "&&& condition shape is not supported; the check "
		       << "is dropped." << endl;
		  error_count += 1;
		  return;
	    }
	    PCondit*c = new PCondit(cond, body, nullptr);
	    FILE_NAME(c, loc);
	    body = c;
      }

      PEEvent*pe = new PEEvent(edge, tc_name_id_(loc, ev.name));
      PEventStatement*es = new PEventStatement(pe);
      FILE_NAME(es, loc);
      es->set_statement(body);
      pform_make_behavior(IVL_PR_ALWAYS, es, nullptr);
}

/* The violation action: $display diagnostic + optional notifier toggle. */
static Statement* tc_violation_(const struct vlltype&loc,
				const char*check_name,
				const pform_name_t*notifier)
{
      char msg[256];
      snprintf(msg, sizeof msg,
	       "%s:%u: Timing violation: %s check in %%m at time %%0t",
	       loc.text? loc.text : "", loc.first_line, check_name);
      char*txt = new char[strlen(msg)+1];
      strcpy(txt, msg);
      PEString*fmt = new PEString(txt);
      FILE_NAME(fmt, loc);

      list<named_pexpr_t> parms;
      named_pexpr_t p1;
      p1.name = perm_string();
      p1.parm = fmt;
      parms.push_back(p1);
      named_pexpr_t p2;
      p2.name = perm_string();
      p2.parm = tc_realtime_(loc);
      parms.push_back(p2);

      PCallTask*disp
	    = new PCallTask(perm_string::literal("$display"), parms);
      FILE_NAME(disp, loc);

      if (notifier == 0)
	    return disp;

      PAssign*tog = new PAssign(tc_name_id_(loc, *notifier),
				new PEUnary('~', tc_name_id_(loc, *notifier)));
      FILE_NAME(tog, loc);

      std::vector<Statement*> stmts;
      stmts.push_back(disp);
      stmts.push_back(tog);
      return sva_block_(loc, stmts);
}

/* Common validity checks; false means the check was dropped loudly. */
static bool tc_check_supported_(const struct vlltype&loc,
				const char*check_name,
				const PTimingCheck::event_t&ev)
{
      if (!ev.edges.empty()) {
	    cerr << loc.get_fileline() << ": sorry: edge-descriptor event "
		 << "lists (edge [...]) in " << check_name << " are not "
		 << "supported; the check is dropped." << endl;
	    error_count += 1;
	    return false;
      }
      return true;
}

static bool tc_active_(const struct vlltype&loc, const char*check_name)
{
      (void)loc; (void)check_name;
      if (pform_cur_module.empty()) return false;
	// The specify block as a whole (path delays and timing checks
	// alike) is inert without -gspecify; that is the established
	// opt-in contract, so ignoring the check is silent here.
      if (!gn_specify_blocks_flag) return false;
      return true;
}

static void tc_pair_synth_(const struct vlltype&loc,
			   const char*check_name,
			   const PTimingCheck::event_t&stamp_ev,
			   const PTimingCheck::event_t&check_ev,
			   PExpr*limit,
			   bool violation_if_greater,
			   const pform_name_t*notifier)
{
      if (!tc_check_supported_(loc, check_name, stamp_ev)) return;
      if (!tc_check_supported_(loc, check_name, check_ev)) return;

      unsigned inst = tc_gensym_counter++;
      perm_string stamp_var = tc_make_real_(loc, inst, "stamp");

	// Timestamp process: stamp = $realtime.
      PAssign*rec = new PAssign(sva_id_(loc, stamp_var), tc_realtime_(loc));
      FILE_NAME(rec, loc);
      tc_always_at_(loc, stamp_ev, rec);

	// Timecheck process:
	//   if (stamp >= 0 && (($realtime - stamp) <op> limit)) violation;
      PExpr*guard = new PEBComp('G', sva_id_(loc, stamp_var),
				tc_real_(loc, 0.0));
      PExpr*delta = new PEBinary('-', tc_realtime_(loc),
				 sva_id_(loc, stamp_var));
      PExpr*cmp = new PEBComp(violation_if_greater? '>' : '<',
			      delta, limit);
      PExpr*cond = new PEBLogic('a', guard, cmp);
      PCondit*chk = new PCondit(cond,
				tc_violation_(loc, check_name, notifier),
				nullptr);
      FILE_NAME(chk, loc);
      tc_always_at_(loc, check_ev, chk);
}

void pform_timing_check_pair(const struct vlltype&loc,
			     const char*check_name,
			     const PTimingCheck::event_t&stamp_ev,
			     const PTimingCheck::event_t&check_ev,
			     PExpr*limit,
			     bool violation_if_greater,
			     const pform_name_t*notifier)
{
      if (!tc_active_(loc, check_name)) return;
      tc_pair_synth_(loc, check_name, stamp_ev, check_ev, limit,
		     violation_if_greater, notifier);
}

/* $setuphold and $recrem are two paired checks in one directive. The
   limit expressions are BORROWED (the caller passes the originals on
   to PSetupHold/PRecRem for delayed-signal aliasing), so the
   synthesized checkers use structural clones. */
void pform_timing_check_setuphold_recrem(const struct vlltype&loc,
					 const char*base_name,
					 const PTimingCheck::event_t&ref_ev,
					 const PTimingCheck::event_t&data_ev,
					 PExpr*lim1,
					 PExpr*lim2,
					 const pform_name_t*notifier)
{
      if (!tc_active_(loc, base_name)) return;

      PExpr*lim1c = sva_clone_expr_(lim1);
      PExpr*lim2c = sva_clone_expr_(lim2);
      if (lim1c == 0 || lim2c == 0) {
	    cerr << loc.get_fileline() << ": sorry: " << base_name
		 << " limit expression shape is not supported by the "
		 << "timing-check synthesizer; the violation checks are "
		 << "dropped." << endl;
	    error_count += 1;
	    delete lim1c;
	    delete lim2c;
	    return;
      }

      char nam1[48], nam2[48];
      if (strcmp(base_name, "$recrem") == 0) {
	    snprintf(nam1, sizeof nam1, "%s(recovery)", base_name);
	    snprintf(nam2, sizeof nam2, "%s(removal)", base_name);
	      // recovery: stamp=async ref, check=clock data
	    tc_pair_synth_(loc, nam1, ref_ev, data_ev, lim1c, false, notifier);
	      // removal: stamp=clock data, check=async ref
	    tc_pair_synth_(loc, nam2, data_ev, ref_ev, lim2c, false, notifier);
      } else {
	    snprintf(nam1, sizeof nam1, "%s(setup)", base_name);
	    snprintf(nam2, sizeof nam2, "%s(hold)", base_name);
	      // setup: stamp=data, check=clock ref
	    tc_pair_synth_(loc, nam1, data_ev, ref_ev, lim1c, false, notifier);
	      // hold: stamp=clock ref, check=data
	    tc_pair_synth_(loc, nam2, ref_ev, data_ev, lim2c, false, notifier);
      }
}

void pform_timing_check_period(const struct vlltype&loc,
			       const PTimingCheck::event_t&ev,
			       PExpr*limit,
			       const pform_name_t*notifier)
{
      if (!tc_active_(loc, "$period")) return;
      if (!tc_check_supported_(loc, "$period", ev)) return;

      unsigned inst = tc_gensym_counter++;
      perm_string last_var = tc_make_real_(loc, inst, "last");

	// One process: check against the previous edge, then record.
      PExpr*guard = new PEBComp('G', sva_id_(loc, last_var),
				tc_real_(loc, 0.0));
      PExpr*delta = new PEBinary('-', tc_realtime_(loc),
				 sva_id_(loc, last_var));
      PExpr*cmp = new PEBComp('<', delta, limit);
      PExpr*cond = new PEBLogic('a', guard, cmp);
      PCondit*chk = new PCondit(cond,
				tc_violation_(loc, "$period", notifier),
				nullptr);
      FILE_NAME(chk, loc);
      PAssign*rec = new PAssign(sva_id_(loc, last_var), tc_realtime_(loc));
      FILE_NAME(rec, loc);

      std::vector<Statement*> stmts;
      stmts.push_back(chk);
      stmts.push_back(rec);
      tc_always_at_(loc, ev, sva_block_(loc, stmts));
}

void pform_timing_check_width(const struct vlltype&loc,
			      const PTimingCheck::event_t&ev,
			      PExpr*limit,
			      PExpr*threshold,
			      const pform_name_t*notifier)
{
      if (!tc_active_(loc, "$width")) return;
      if (!tc_check_supported_(loc, "$width", ev)) return;
      if (!ev.posedge && !ev.negedge) {
	    cerr << loc.get_fileline() << ": error: $width requires an "
		 << "edge-qualified reference event (posedge/negedge)."
		 << endl;
	    error_count += 1;
	    return;
      }

      unsigned inst = tc_gensym_counter++;
      perm_string stamp_var = tc_make_real_(loc, inst, "stamp");

	// Record at the qualified edge.
      PAssign*rec = new PAssign(sva_id_(loc, stamp_var), tc_realtime_(loc));
      FILE_NAME(rec, loc);
      tc_always_at_(loc, ev, rec);

	// Check at the opposite edge: threshold < delta < limit.
      PTimingCheck::event_t opp;
      opp.name = ev.name;
      opp.posedge = ev.negedge;
      opp.negedge = ev.posedge;
      if (ev.condition.get()) {
	    PExpr*ccl = sva_clone_expr_(ev.condition.get());
	    if (ccl == 0) {
		  cerr << loc.get_fileline() << ": sorry: this timing check "
		       << "&&& condition shape is not supported; the check "
		       << "is dropped." << endl;
		  error_count += 1;
		  return;
	    }
	    opp.condition.reset(ccl);
      }

      PExpr*guard = new PEBComp('G', sva_id_(loc, stamp_var),
				tc_real_(loc, 0.0));
      PExpr*delta = new PEBinary('-', tc_realtime_(loc),
				 sva_id_(loc, stamp_var));
      PExpr*cmp = new PEBComp('<', delta, limit);
      PExpr*cond = new PEBLogic('a', guard, cmp);
      if (threshold) {
	    PExpr*delta2 = new PEBinary('-', tc_realtime_(loc),
					sva_id_(loc, stamp_var));
	    PExpr*thr = new PEBComp('>', delta2, threshold);
	    cond = new PEBLogic('a', cond, thr);
      }
      PCondit*chk = new PCondit(cond,
				tc_violation_(loc, "$width", notifier),
				nullptr);
      FILE_NAME(chk, loc);
      tc_always_at_(loc, opp, chk);
}

void pform_timing_check_sorry(const struct vlltype&loc,
			      const char*check_name)
{
	// Silent when specify is disabled (see tc_active_); loud when
	// the user asked for specify semantics but the check shape is
	// not modeled.
      if (!gn_specify_blocks_flag) return;
      cerr << loc.get_fileline() << ": sorry: the " << check_name
	   << " timing check is not supported yet; the check is dropped."
	   << endl;
      error_count += 1;
}

/* Rewrite sampled-value functions inside a property expression:
   $rose/$fell/$stable/$changed/$past calls become references to
   synthesized 1-cycle (or N-cycle) history registers. The argument
   is captured once at the top of the checker (pre) and shifted into
   the history at the bottom (post), so no subtree is shared. */
static PExpr* sva_rewrite_sampled_(const struct vlltype&loc, PExpr*e,
				   unsigned inst, unsigned&hist_idx,
				   std::vector<Statement*>&pre,
				   std::vector<Statement*>&post,
				   std::vector<Statement*>&init)
{
      if (!e) return e;

      if (PECallFunction*cf = dynamic_cast<PECallFunction*>(e)) {
	    if (cf->path().name.size() == 1 && !cf->path().package) {
		  const char*nm = peek_tail_name(cf->path().name).str();
		  bool is_rose = !strcmp(nm, "$rose");
		  bool is_fell = !strcmp(nm, "$fell");
		  bool is_stbl = !strcmp(nm, "$stable");
		  bool is_chgd = !strcmp(nm, "$changed");
		  bool is_past = !strcmp(nm, "$past");
		  if (is_rose || is_fell || is_stbl || is_chgd || is_past) {
			const std::vector<named_pexpr_t>&parms = cf->get_parms();
			if (parms.empty() || !parms[0].parm) {
			      cerr << loc << ": error: " << nm
				   << " requires an argument." << endl;
			      error_count += 1;
			      return e;
			}
			PExpr*arg = sva_rewrite_sampled_(loc, parms[0].parm,
							 inst, hist_idx, pre, post, init);
			long depth = 1;
			if (is_past && parms.size() > 1 && parms[1].parm) {
			      PENumber*dn = dynamic_cast<PENumber*>(parms[1].parm);
			      if (!dn) {
				    cerr << loc << ": sorry: $past depth must "
					 << "be a literal constant here." << endl;
				    error_count += 1;
				    return e;
			      }
			      depth = dn->value().as_long();
			      if (depth < 1) depth = 1;
			}
			  /* Capture the argument now... */
			perm_string cur = sva_make_reg_(loc, inst, "smp", hist_idx++);
			pre.push_back(sva_assign_(loc, cur, arg));
			  /* ...and build the history chain, updated
			     bottom-of-block in shift order. */
			std::vector<perm_string> hist (depth);
			for (long k = 0 ; k < depth ; k += 1) {
			      hist[k] = sva_make_reg_(loc, inst, "hist", hist_idx++);
				/* Deterministic first-cycle behavior:
				   histories start at 0, so $stable
				   compares against 0 rather than the
				   strict-LRM x default (recorded). */
			      init.push_back(sva_assign_(loc, hist[k],
							 sva_bit_(loc, 0)));
			}
			for (long k = depth-1 ; k >= 1 ; k -= 1)
			      post.push_back(sva_assign_(loc, hist[k],
							 sva_id_(loc, hist[k-1])));
			post.push_back(sva_assign_(loc, hist[0], sva_id_(loc, cur)));
			perm_string old_reg = hist[depth-1];

			if (is_past)
			      return sva_id_(loc, old_reg);
			if (is_rose) {
			      PEUnary*np = new PEUnary('!', sva_id_(loc, old_reg));
			      FILE_NAME(np, loc);
			      PEBLogic*r = new PEBLogic('a', sva_id_(loc, cur), np);
			      FILE_NAME(r, loc);
			      return r;
			}
			if (is_fell) {
			      PEUnary*nc = new PEUnary('!', sva_id_(loc, cur));
			      FILE_NAME(nc, loc);
			      PEBLogic*r = new PEBLogic('a', nc, sva_id_(loc, old_reg));
			      FILE_NAME(r, loc);
			      return r;
			}
			  /* $stable / $changed: case (in)equality on the
			     sampled pair. */
			PEBComp*r = new PEBComp(is_stbl ? 'E' : 'N',
						sva_id_(loc, cur),
						sva_id_(loc, old_reg));
			FILE_NAME(r, loc);
			return r;
		  }
	    }
	    return e;
      }

      if (PEUnary*un = dynamic_cast<PEUnary*>(e)) {
	    PExpr*sub = sva_rewrite_sampled_(loc, un->get_expr(),
					     inst, hist_idx, pre, post, init);
	    if (sub == un->get_expr()) return e;
	    PEUnary*cp = new PEUnary(un->get_op(), sub);
	    cp->set_line(*e);
	    return cp;
      }
      if (PEBinary*bin = dynamic_cast<PEBinary*>(e)) {
	    PExpr*l = sva_rewrite_sampled_(loc, bin->get_left(),
					   inst, hist_idx, pre, post, init);
	    PExpr*r = sva_rewrite_sampled_(loc, bin->get_right(),
					   inst, hist_idx, pre, post, init);
	    if (l == bin->get_left() && r == bin->get_right()) return e;
	    PEBinary*cp;
	    if (dynamic_cast<PEBComp*>(e))
		  cp = new PEBComp(bin->get_op(), l, r);
	    else if (dynamic_cast<PEBLogic*>(e))
		  cp = new PEBLogic(bin->get_op(), l, r);
	    else if (dynamic_cast<PEBShift*>(e))
		  cp = new PEBShift(bin->get_op(), l, r);
	    else
		  cp = new PEBinary(bin->get_op(), l, r);
	    cp->set_line(*e);
	    return cp;
      }
      if (PETernary*ter = dynamic_cast<PETernary*>(e)) {
	    PExpr*c = sva_rewrite_sampled_(loc, ter->get_cond(),
					   inst, hist_idx, pre, post, init);
	    PExpr*t = sva_rewrite_sampled_(loc, ter->get_true(),
					   inst, hist_idx, pre, post, init);
	    PExpr*f = sva_rewrite_sampled_(loc, ter->get_false(),
					   inst, hist_idx, pre, post, init);
	    if (c == ter->get_cond() && t == ter->get_true()
		&& f == ter->get_false()) return e;
	    PETernary*cp = new PETernary(c, t, f);
	    cp->set_line(*e);
	    return cp;
      }
      return e;
}

/* Substitute named sequence references: a step whose expression is a
   bare identifier naming a declared sequence splices that sequence's
   steps (first spliced delay adds the step's own delay). */
static void sva_splice_sequences_(const struct vlltype&loc,
				  std::vector<sva_seq_step_t>&steps)
{
      static int splice_depth = 0;
      if (++splice_depth > 64) {
	    cerr << loc << ": error: SVA sequence instantiation nested too "
		 << "deeply (a recursive sequence?)." << endl;
	    error_count += 1;
	    --splice_depth;
	    return;
      }
      for (size_t i = 0 ; i < steps.size() ; ) {
	      /* M9D: parameterized sequence instantiation `name(args)`. */
	    if (PECallFunction*cf = dynamic_cast<PECallFunction*>(steps[i].expr)) {
		  if (!cf->path().package && cf->path().name.size() == 1) {
			perm_string nm = peek_tail_name(cf->path().name);
			std::map<perm_string, sva_param_seq_t>::iterator pit =
			      sva_param_sequences.find(nm);
			if (pit != sva_param_sequences.end() && pit->second.body) {
			      std::vector<sva_seq_step_t>*inst =
				    sva_instantiate_seq_(loc, nm, pit->second,
							 cf->get_parms());
			      if (inst) {
				    if (!inst->empty()) {
					  (*inst)[0].delay_lo += steps[i].delay_lo;
					  (*inst)[0].delay_hi += steps[i].delay_hi;
				    }
				    sva_splice_sequences_(loc, *inst);
				    delete steps[i].expr;
				    steps.erase(steps.begin() + i);
				    steps.insert(steps.begin() + i,
						 inst->begin(), inst->end());
				    size_t n = inst->size();
				    delete inst;
				    i += n;
				    continue;
			      }
			      delete steps[i].expr;
			      steps[i].expr = sva_bit_(loc, 1);
			      i += 1;
			      continue;
			}
		  }
	    }
	    PEIdent*id = dynamic_cast<PEIdent*>(steps[i].expr);
	    if (!id || id->path().package || id->path().name.size() != 1
		|| !id->path().name.front().index.empty()) {
		  i += 1;
		  continue;
	    }
	    std::map<perm_string, std::vector<sva_seq_step_t>*>::iterator seq_it =
		  sva_module_sequences.find(id->path().name.front().name);
	    if (seq_it == sva_module_sequences.end() || !seq_it->second) {
		  i += 1;
		  continue;
	    }
	    std::vector<sva_seq_step_t> body;
	    for (size_t k = 0 ; k < seq_it->second->size() ; k += 1) {
		  sva_seq_step_t st = (*seq_it->second)[k];
		  PExpr*cp = sva_clone_expr_(st.expr);
		  if (!cp) {
			  /* consume-once: move the tree and drop the
			     declaration so a second use is diagnosed */
			cp = st.expr;
			(*seq_it->second)[k].expr = nullptr;
		  }
		  if (!cp) {
			cerr << loc << ": error: sequence `"
			     << seq_it->first << "' was already "
			     << "instantiated and its body cannot be "
			     << "copied; declare it separately for each "
			     << "use." << endl;
			error_count += 1;
			i += 1;
			cp = sva_bit_(loc, 1);
		  }
		  st.expr = cp;
		  if (k == 0) {
			st.delay_lo += steps[i].delay_lo;
			st.delay_hi += steps[i].delay_hi;
		  }
		  body.push_back(st);
	    }
	    steps.erase(steps.begin() + i);
	    steps.insert(steps.begin() + i, body.begin(), body.end());
	    i += body.size();
      }
      --splice_depth;
}

/* M9-2: consecutive repetition (IEEE 1800-2017 16.9.2). e[*N]
   desugars to e ##1 e ... (N times); e[*m:n] expands to [*m] with a
   rep_tail marker — in the FINAL chain position a length-k match
   (m<=k<=n) exists iff the first m cycles match, so [*m] is
   match-equivalent there; any other position is diagnosed at
   lowering. Unsupported shapes (non-literal bounds, zero repetition,
   uncopyable operands) mark the chain with delay_lo=-3 for a single
   clear sorry. */
std::vector<sva_seq_step_t>*
pform_sva_repeat(const struct vlltype&loc,
		 std::vector<sva_seq_step_t>*steps, PExpr*lo, PExpr*hi)
{
      PENumber*lon = dynamic_cast<PENumber*>(lo);
      PENumber*hin = dynamic_cast<PENumber*>(hi);
      long lov = lon ? lon->value().as_long() : -1;
      long hiv = hi ? (hin ? hin->value().as_long() : -1) : lov;
      delete lo;
      delete hi;

      if (!steps || steps->empty())
	    return steps;
      if (lov < 1 || hiv < lov || !lon || (hi && !hin)) {
	    (*steps)[0].delay_lo = -3;
	    return steps;
      }

	/* Clone the base list lov-1 times, concatenated with ##1. */
      std::vector<sva_seq_step_t> base = *steps;
      for (long r = 1 ; r < lov ; r += 1) {
	    for (size_t k = 0 ; k < base.size() ; k += 1) {
		  sva_seq_step_t st = base[k];
		  st.expr = sva_clone_expr_(base[k].expr);
		  if (!st.expr) {
			(*steps)[0].delay_lo = -3;
			return steps;
		  }
		  if (k == 0) {
			st.delay_lo = 1;
			st.delay_hi = 1;
		  }
		  st.rep_tail = 0;
		  steps->push_back(st);
	    }
      }
      steps->back().rep_tail = hiv - lov;
      return steps;
}

/*
 * M9C: `expr throughout seq` (IEEE 1800-2017 16.9.9). The boolean `expr`
 * must hold at every clock tick from the start of `seq` until it
 * completes. Rather than extend the token-pipeline runtime, we lower
 * throughout by a source-level transformation into an ordinary
 * unit-delay sequence that the existing engine already handles exactly:
 *
 *   - `expr` is AND-ed into every step's boolean (so it is checked at
 *     each matched cycle), and
 *   - every multi-cycle `##N` gap is expanded into N-1 intermediate
 *     unit steps whose boolean is `expr` alone (so it is also checked at
 *     the wait cycles).
 *
 * This is exact for constant, bounded delays. Range (`##[m:n]`),
 * unbounded (`##[m:$]`), and range-repetition (`[*m:n]`) sub-shapes make
 * the throughout window variable-length; those are diagnosed loudly
 * (the sequence is dropped) rather than approximated, so no silent
 * miscompile is introduced. Returns nullptr on an unsupported shape or
 * a non-clonable guard, after emitting the diagnostic.
 */
std::vector<sva_seq_step_t>*
pform_sva_throughout(const struct vlltype&loc, PExpr*guard,
		     std::vector<sva_seq_step_t>*seq)
{
      if (!seq || seq->empty()) {
	    delete guard;
	    delete seq;
	    return nullptr;
      }

	// Reject the variable-window sub-shapes up front.
      for (size_t i = 0 ; i < seq->size() ; i += 1) {
	    const sva_seq_step_t&st = (*seq)[i];
	    if (st.delay_lo < 0 || st.delay_lo != st.delay_hi
		|| st.rep_tail != 0) {
		  cerr << loc << ": sorry: `throughout' is supported only "
		       << "over a fixed-length sequence (constant ##N "
		       << "delays, no ##[m:n]/##[m:$]/[*m:n]); the "
		       << "assertion is dropped." << endl;
		  error_count += 1;
		  delete guard;
		  delete seq;
		  return nullptr;
	    }
      }

      std::vector<sva_seq_step_t>*out = new std::vector<sva_seq_step_t>;

      for (size_t i = 0 ; i < seq->size() ; i += 1) {
	    const sva_seq_step_t&st = (*seq)[i];
	    long d = st.delay_lo;

	      // Intermediate wait cycles: guard alone, one per skipped
	      // cycle. (For the leading step d is usually 0 — no wait.)
	    for (long j = 1 ; j < d ; j += 1) {
		  PExpr*gj = sva_clone_expr_(guard);
		  if (!gj) goto unclonable;
		  sva_seq_step_t wait_st;
		  wait_st.delay_lo = 1;
		  wait_st.delay_hi = 1;
		  wait_st.rep_tail = 0;
		  wait_st.expr = gj;
		  out->push_back(wait_st);
	    }

	      // The step's own cycle: guard && original boolean.
	    {
		  PExpr*gi = sva_clone_expr_(guard);
		  if (!gi) goto unclonable;
		  PExpr*conj = new PEBLogic('a', gi, st.expr);
		  FILE_NAME(conj, loc);
		  sva_seq_step_t use_st;
		  use_st.delay_lo = (d == 0) ? 0 : 1;
		  use_st.delay_hi = use_st.delay_lo;
		  use_st.rep_tail = 0;
		  use_st.expr = conj;
		  out->push_back(use_st);
	    }
      }

      delete guard;
      delete seq;      // step exprs were moved into `out`
      return out;

 unclonable:
      cerr << loc << ": sorry: the `throughout' guard expression has a "
	   << "shape the assertion engine cannot duplicate; the "
	   << "assertion is dropped." << endl;
      error_count += 1;
	// out may hold clones; drop them.
      for (size_t k = 0 ; k < out->size() ; k += 1)
	    delete (*out)[k].expr;
      delete out;
      delete guard;
	// original step exprs still owned by seq if not yet moved; the
	// loud drop leaks at most the remaining originals (process is
	// exiting on error anyway).
      delete seq;
      return nullptr;
}

/*
 * Expand a fixed-length sequence into a per-cycle boolean array. cyc[k]
 * holds the boolean required at cycle k (0..L, where L is the total
 * span), or nullptr for an unconstrained gap cycle. Ownership of each
 * step's expression is MOVED into cyc (the step's expr is cleared).
 * Returns false — after a loud diagnostic — for any non-fixed-length
 * shape (ranged/unbounded/non-constant delay, or a range repetition).
 */
static bool sva_expand_fixed_(const struct vlltype&loc, const char*what,
			      std::vector<sva_seq_step_t>&seq,
			      std::vector<PExpr*>&cyc)
{
      cyc.clear();
      for (size_t j = 0 ; j < seq.size() ; j += 1) {
	    sva_seq_step_t&st = seq[j];
	    if (st.delay_lo < 0 || st.delay_lo != st.delay_hi
		|| st.rep_tail != 0) {
		  cerr << loc << ": sorry: `" << what << "' is supported "
		       << "only over fixed-length sequences (constant ##N "
		       << "delays, no ##[m:n]/##[m:$]/[*m:n]); the assertion "
		       << "is dropped." << endl;
		  error_count += 1;
		  return false;
	    }
	    long d = st.delay_lo;
	    if (j == 0) {
		  for (long i = 0 ; i < d ; i += 1) cyc.push_back(nullptr);
		  cyc.push_back(st.expr);
	    } else if (d == 0) {
		    /* `##0`: same cycle as the previous step — AND in. */
		  PExpr*prev = cyc.back();
		  if (!prev) {
			cyc.back() = st.expr;
		  } else {
			PEBLogic*c = new PEBLogic('a', prev, st.expr);
			FILE_NAME(c, loc);
			cyc.back() = c;
		  }
	    } else {
		  for (long i = 1 ; i < d ; i += 1) cyc.push_back(nullptr);
		  cyc.push_back(st.expr);
	    }
	    st.expr = nullptr;
      }
      return true;
}

/*
 * M9B: `s1 intersect s2` (IEEE 1800-2017 16.9.6). Both operands must
 * match over the SAME interval — same start and same end — so a match
 * requires them to have equal length. For fixed-length operands we
 * expand each to a per-cycle boolean array and build a single unit-delay
 * chain whose cycle-k boolean is `a[k] && b[k]`. Unequal fixed lengths
 * can never match; rather than synthesize an always-false checker we
 * diagnose that loudly. Variable-length operands are a loud sorry.
 */
std::vector<sva_seq_step_t>*
pform_sva_intersect(const struct vlltype&loc,
		    std::vector<sva_seq_step_t>*s1,
		    std::vector<sva_seq_step_t>*s2)
{
      if (!s1 || !s2 || s1->empty() || s2->empty()) {
	    delete s1; delete s2;
	    return nullptr;
      }

      std::vector<PExpr*> A, B;
      bool ok = sva_expand_fixed_(loc, "intersect", *s1, A);
      if (ok) ok = sva_expand_fixed_(loc, "intersect", *s2, B);
      if (ok && A.size() != B.size()) {
	    cerr << loc << ": sorry: `intersect' requires both operands to "
		 << "have the same length (IEEE 1800-2017 16.9.6); the "
		 << "assertion is dropped." << endl;
	    error_count += 1;
	    ok = false;
      }
      if (!ok) {
	    for (size_t k = 0 ; k < A.size() ; k += 1) delete A[k];
	    for (size_t k = 0 ; k < B.size() ; k += 1) delete B[k];
	    delete s1; delete s2;
	    return nullptr;
      }

      std::vector<sva_seq_step_t>*out = new std::vector<sva_seq_step_t>;
      for (size_t k = 0 ; k < A.size() ; k += 1) {
	    PExpr*ex;
	    if (A[k] && B[k]) {
		  PEBLogic*c = new PEBLogic('a', A[k], B[k]);
		  FILE_NAME(c, loc);
		  ex = c;
	    } else if (A[k]) {
		  ex = A[k];
	    } else if (B[k]) {
		  ex = B[k];
	    } else {
		  ex = sva_bit_(loc, 1);
	    }
	    sva_seq_step_t st;
	    st.delay_lo = (k == 0) ? 0 : 1;
	    st.delay_hi = st.delay_lo;
	    st.rep_tail = 0;
	    st.expr = ex;
	    out->push_back(st);
      }
      delete s1; delete s2;
      return out;
}

/*
 * M9C: package a binary temporal/sequence property operator whose
 * semantics do not fit the linear token pipeline (`within` and the
 * `until` family). The operands are carried on the sva_property_t and
 * lowered by pform_make_assertion once `kind` is known. op_type:
 *   4 = until, 5 = until_with, 6 = s_until, 7 = s_until_with, 8 = within.
 */
sva_property_t*
pform_sva_binprop(const struct vlltype&loc, int op_type,
		  std::vector<sva_seq_step_t>*sub,
		  std::vector<sva_seq_step_t>*obj)
{
      if (!sub || !obj || sub->empty() || obj->empty()) {
	    delete sub; delete obj;
	    return nullptr;
      }
      sva_property_t*p = new sva_property_t;
      p->antecedent = sub;
      p->seq = obj;
      p->op_type = op_type;
      (void)loc;
      return p;
}

/*
 * M9C-live: package a unary liveness operator (nexttime / s_nexttime /
 * s_eventually). The operand must be a plain boolean property; the
 * boolean is moved onto a fresh sva_property_t with the dedicated
 * op_type and lowered by pform_make_assertion. op_type: 9 nexttime,
 * 10 s_nexttime, 11 s_eventually.
 */
sva_property_t*
pform_sva_unprop(const struct vlltype&loc, int op_type, sva_property_t*sub)
{
      const char*w = (op_type == 9) ? "nexttime"
		   : (op_type == 10) ? "s_nexttime" : "s_eventually";
      if (!sub) return nullptr;
      if (sub->op_type != 0 || sub->antecedent || !sub->seq
	  || sub->seq->size() != 1
	  || (*sub->seq)[0].delay_lo != 0 || (*sub->seq)[0].delay_hi != 0
	  || (*sub->seq)[0].rep_tail != 0
	  || sub->clk_evt || sub->disable_iff_expr) {
	    cerr << loc << ": sorry: `" << w << "' is supported only with a "
		 << "boolean operand (no nested or sequence property); the "
		 << "assertion is dropped." << endl;
	    error_count += 1;
	    if (sub) { delete sub->antecedent; delete sub->seq; delete sub; }
	    return nullptr;
      }
      sva_property_t*p = new sva_property_t;
      p->op_type = op_type;
      p->seq = sub->seq;   /* move the boolean step list */
      sub->seq = nullptr;
      delete sub;
      return p;
}

/*
 * M9C: lower the temporal/sequence property operators that do not fit
 * the linear token pipeline.
 *
 *   until family (booleans; op 4/5/6/7): `p until q` holds iff, at every
 *   attempt, p holds at each cycle before q first holds (until_with:
 *   through the q cycle too). Under the overlapping-attempt semantics a
 *   fresh attempt starts every clock, and the aggregate obligation
 *   collapses to a per-cycle boolean check:
 *       until       — fail at any cycle with !p && !q
 *       until_with  — fail at any cycle with !p
 *   The strong forms (s_until/s_until_with) add a liveness obligation:
 *   q must eventually hold. A `pend` flag tracks an outstanding attempt
 *   still waiting for q; if it survives to end-of-simulation, that is a
 *   strong-until failure.
 *
 *   within (fixed-length sequences; op 8): `s1 within s2` matches over
 *   s2's interval iff s2 matches and s1 matches at some embedded offset.
 *   Both operands are expanded to per-cycle boolean arrays and the match
 *   at the window end (now) is written as one combinational indicator
 *   over $past samples: AND of s2's cycles, AND'd with the OR (over
 *   embedding offsets) of s1's cycles. A `$past(1, L2)` warm-up guard
 *   suppresses obligations for windows that predate time 0. Requires
 *   len(s1) <= len(s2).
 *
 * Operands: prop->antecedent = left (p / s1), prop->seq = right (q / s2).
 */
static void pform_make_temporal_assertion_(const struct vlltype&loc,
					   sva_property_t*prop,
					   Statement*fail_stmt,
					   Statement*pass_stmt, int kind)
{
      int op = prop->op_type;
      bool is_within   = (op == 8);
      bool is_liveness = (op >= 9);
      bool with   = (op == 5 || op == 7);
      bool strong = (op == 6 || op == 7);

	/* A pass action is not meaningful for these forms. */
      delete pass_stmt;
      pass_stmt = nullptr;

	/* Clock: explicit, else the module's default clocking. */
      PEventStatement*clk = prop->clk_evt;
      if (!clk) {
	    Module*mod = pform_cur_module.empty() ? nullptr
			 : pform_cur_module.front();
	    if (!mod || mod->default_clocking.nil()) {
		  cerr << loc << ": error: concurrent assertion has no "
		       << "clocking event and no default clocking block "
		       << "is declared (IEEE 1800-2017 16.14.6)." << endl;
		  error_count += 1;
		  delete fail_stmt;
		  return;
	    }
	    std::list<named_pexpr_t> no_parms;
	    PECallFunction*mark = new PECallFunction(
		  perm_string::literal("$ivl_default_clock"), no_parms);
	    FILE_NAME(mark, loc);
	    PEEvent*ev = new PEEvent(PEEvent::ANYEDGE, mark);
	    std::vector<PEEvent*> evs;
	    evs.push_back(ev);
	    clk = new PEventStatement(evs);
	    FILE_NAME(clk, loc);
      }

	/* disable iff: own, else the module default. */
      PExpr*disable = prop->disable_iff_expr;
      if (!disable && sva_default_disable)
	    disable = sva_clone_expr_(sva_default_disable);

      unsigned inst = sva_gensym_counter++;
      unsigned hist_idx = 0;
      std::vector<Statement*> pre, post, init_zero, body;

	/* The fail flag / dispatch is shared by both forms. */
      perm_string r_f = sva_make_reg_(loc, inst, "f", 0);
      init_zero.push_back(sva_assign_(loc, r_f, sva_bit_(loc, 0)));
      bool bad = false;

      if (!is_within && !is_liveness) {
	      /* ---- until family (boolean operands only). ---- */
	    if (kind == 2) {
		  cerr << loc << ": sorry: `cover property' of an `until' "
		       << "operator is not supported; the cover is dropped."
		       << endl;
		  error_count += 1;
		  bad = true;
	    }
	    std::vector<sva_seq_step_t>&Pp = *prop->antecedent;
	    std::vector<sva_seq_step_t>&Qq = *prop->seq;
	    if (!bad && (Pp.size() != 1 || Qq.size() != 1
		|| Pp[0].delay_lo != 0 || Pp[0].delay_hi != 0 || Pp[0].rep_tail != 0
		|| Qq[0].delay_lo != 0 || Qq[0].delay_hi != 0 || Qq[0].rep_tail != 0)) {
		  cerr << loc << ": sorry: the `until' family is supported "
		       << "only with boolean operands (no sequence operands); "
		       << "the assertion is dropped." << endl;
		  error_count += 1;
		  bad = true;
	    }
	    if (bad) { delete fail_stmt; delete clk; delete disable; return; }

	    PExpr*pe = sva_rewrite_sampled_(loc, Pp[0].expr, inst, hist_idx,
					   pre, post, init_zero);
	    PExpr*qe = sva_rewrite_sampled_(loc, Qq[0].expr, inst, hist_idx,
					   pre, post, init_zero);
	    perm_string r_p = sva_make_reg_(loc, inst, "p", 0);
	    perm_string r_q = sva_make_reg_(loc, inst, "q", 0);
	    pre.push_back(sva_assign_(loc, r_p, pe));
	    pre.push_back(sva_assign_(loc, r_q, qe));

	    perm_string r_pend;
	    if (strong) {
		  r_pend = sva_make_reg_(loc, inst, "pend", 0);
		  init_zero.push_back(sva_assign_(loc, r_pend, sva_bit_(loc, 0)));
	    }

	      /* Per-cycle weak check. */
	    PExpr*fcond;
	    if (with) {
		  fcond = sva_not_(loc, sva_id_(loc, r_p));
	    } else {
		  fcond = sva_logic_(loc, 'a', sva_not_(loc, sva_id_(loc, r_q)),
				     sva_not_(loc, sva_id_(loc, r_p)));
	    }
	    body.push_back(sva_if_(loc, fcond,
				   sva_assign_(loc, r_f, sva_bit_(loc, 1)),
				   nullptr));

	      /* Strong liveness bookkeeping: q releases the pending
		 obligation; otherwise a true p opens a new one. */
	    if (strong) {
		  Statement*open = sva_if_(loc, sva_id_(loc, r_p),
			sva_assign_(loc, r_pend, sva_bit_(loc, 1)), nullptr);
		  body.push_back(sva_if_(loc, sva_id_(loc, r_q),
			sva_assign_(loc, r_pend, sva_bit_(loc, 0)), open));
	    }

	      /* Fail dispatch (assert/assume). */
	    Statement*action = fail_stmt;
	    if (!action) {
		  std::list<named_pexpr_t> no_args;
		  PCallTask*err = new PCallTask(lex_strings.make("$error"), no_args);
		  FILE_NAME(err, loc);
		  action = err;
	    }
	    std::vector<Statement*> hit;
	    hit.push_back(sva_assign_(loc, r_f, sva_bit_(loc, 0)));
	    hit.push_back(sva_fail_action_(loc, inst, action));
	    body.push_back(sva_if_(loc, sva_id_(loc, r_f),
				   sva_block_(loc, hit), nullptr));

	      /* End-of-simulation strong check. */
	    if (strong) {
		  std::list<named_pexpr_t> dargs;
		  named_pexpr_t darg;
		  darg.parm = new PEString(strdup(
			"SVA: strong until obligation not met — the awaited "
			"condition never asserted"));
		  dargs.push_back(darg);
		  PCallTask*warn = new PCallTask(lex_strings.make("$error"), dargs);
		  FILE_NAME(warn, loc);
		  Statement*fc = sva_if_(loc, sva_id_(loc, r_pend),
					 sva_fail_action_(loc, inst, warn), nullptr);
		  PProcess*fp = pform_make_behavior(IVL_PR_FINAL, fc, nullptr);
		  FILE_NAME(fp, loc);
	    }
      } else if (is_liveness) {
	      /* ---- liveness: nexttime / s_nexttime / s_eventually. ----
		 The boolean operand p is in prop->seq[0]. */
	    if (kind == 2) {
		  const char*w = (op == 9) ? "nexttime"
			       : (op == 10) ? "s_nexttime" : "s_eventually";
		  cerr << loc << ": sorry: `cover property' of a `" << w
		       << "' operator is not supported; the cover is dropped."
		       << endl;
		  error_count += 1;
		  delete fail_stmt; delete clk; delete disable;
		  return;
	    }
	    PExpr*pe = sva_rewrite_sampled_(loc, (*prop->seq)[0].expr, inst,
					    hist_idx, pre, post, init_zero);
	    perm_string r_p = sva_make_reg_(loc, inst, "p", 0);
	    pre.push_back(sva_assign_(loc, r_p, pe));

	    Statement*action = fail_stmt;
	    if (!action) {
		  std::list<named_pexpr_t> no_args;
		  PCallTask*err = new PCallTask(lex_strings.make("$error"), no_args);
		  FILE_NAME(err, loc);
		  action = err;
	    }

	    if (op == 11) {
		    /* s_eventually p (16.12.5): p must hold at least once.
		       Track whether p was ever seen; report at end of
		       simulation if it never was. (Standalone liveness: the
		       cycle-0 attempt is the canonical obligation.) */
		  perm_string r_seen = sva_make_reg_(loc, inst, "seen", 0);
		  init_zero.push_back(sva_assign_(loc, r_seen, sva_bit_(loc, 0)));
		  body.push_back(sva_if_(loc, sva_id_(loc, r_p),
			sva_assign_(loc, r_seen, sva_bit_(loc, 1)), nullptr));
		  Statement*fc = sva_if_(loc, sva_not_(loc, sva_id_(loc, r_seen)),
					 sva_fail_action_(loc, inst, action), nullptr);
		  PProcess*fp = pform_make_behavior(IVL_PR_FINAL, fc, nullptr);
		  FILE_NAME(fp, loc);
	    } else {
		    /* nexttime / s_nexttime (16.12.2): p must hold at the
		       NEXT cycle. Per attempt at cycle S that is p@(S+1);
		       aggregated, every cycle T>=1 requires p@T. A
		       $past(1,1) guard suppresses the first cycle. */
		  PExpr*valid = sva_past_(loc, sva_bit_(loc, 1), 1);
		  PExpr*failexpr = sva_logic_(loc, 'a', valid,
					      sva_not_(loc, sva_id_(loc, r_p)));
		  PExpr*fs = sva_rewrite_sampled_(loc, failexpr, inst, hist_idx,
						  pre, post, init_zero);
		  perm_string r_ff = sva_make_reg_(loc, inst, "ff", 0);
		  pre.push_back(sva_assign_(loc, r_ff, fs));
		  body.push_back(sva_if_(loc, sva_id_(loc, r_ff),
					 sva_fail_action_(loc, inst, action), nullptr));

		  if (op == 10) {
			  /* Strong: the attempt at the final cycle has no
			     next cycle and can never be satisfied. Report
			     once at end of simulation, guarded by a "ran"
			     flag so a zero-clock run stays quiet. */
			perm_string r_ran = sva_make_reg_(loc, inst, "ran", 0);
			init_zero.push_back(sva_assign_(loc, r_ran, sva_bit_(loc, 0)));
			body.push_back(sva_assign_(loc, r_ran, sva_bit_(loc, 1)));
			std::list<named_pexpr_t> dargs;
			named_pexpr_t darg;
			darg.parm = new PEString(strdup(
			      "SVA: strong nexttime obligation not met — no "
			      "next cycle for the final attempt"));
			dargs.push_back(darg);
			PCallTask*warn = new PCallTask(lex_strings.make("$error"),
						       dargs);
			FILE_NAME(warn, loc);
			Statement*fc = sva_if_(loc, sva_id_(loc, r_ran),
					       sva_fail_action_(loc, inst, warn), nullptr);
			PProcess*fp = pform_make_behavior(IVL_PR_FINAL, fc, nullptr);
			FILE_NAME(fp, loc);
		  }
	    }
      } else {
	      /* ---- within (fixed-length sequences). ---- */
	    std::vector<PExpr*> A, B;
	    bool ok = sva_expand_fixed_(loc, "within", *prop->antecedent, A);
	    if (ok) ok = sva_expand_fixed_(loc, "within", *prop->seq, B);
	    long L1 = (long)A.size() - 1;
	    long L2 = (long)B.size() - 1;
	    if (ok && L1 > L2) {
		  cerr << loc << ": sorry: `within' requires the left operand "
		       << "to be no longer than the right (IEEE 1800-2017 "
		       << "16.9.6); the assertion is dropped." << endl;
		  error_count += 1;
		  ok = false;
	    }
	    if (!ok) {
		  for (size_t k = 0 ; k < A.size() ; k += 1) delete A[k];
		  for (size_t k = 0 ; k < B.size() ; k += 1) delete B[k];
		  delete fail_stmt; delete clk; delete disable;
		  return;
	    }

	      /* s2 term: every constrained cycle of s2 must hold. Cycle p
		 (0..L2) is now sampled at $past depth (L2 - p). */
	    PExpr*s2term = nullptr;
	    for (long p = 0 ; p <= L2 ; p += 1) {
		  if (!B[p]) continue;
		  PExpr*c = sva_clone_expr_(B[p]);
		  if (!c) { ok = false; break; }
		  PExpr*t = sva_past_(loc, c, L2 - p);
		  s2term = s2term ? sva_logic_(loc, 'a', s2term, t) : t;
	    }
	      /* s1 embed: s1 matches at some offset j in [0, L2-L1]. For a
		 given j, cycle i of s1 lands at window position j+i, now
		 sampled at $past depth L2 - (j+i). */
	    PExpr*s1embed = nullptr;
	    if (ok) for (long j = 0 ; j <= L2 - L1 ; j += 1) {
		  PExpr*conj = nullptr;
		  for (long i = 0 ; i <= L1 ; i += 1) {
			if (!A[i]) continue;
			PExpr*c = sva_clone_expr_(A[i]);
			if (!c) { ok = false; break; }
			PExpr*t = sva_past_(loc, c, L2 - (j + i));
			conj = conj ? sva_logic_(loc, 'a', conj, t) : t;
		  }
		  if (!ok) break;
		  if (!conj) conj = sva_bit_(loc, 1);
		  s1embed = s1embed ? sva_logic_(loc, 'o', s1embed, conj) : conj;
	    }

	    for (size_t k = 0 ; k < A.size() ; k += 1) delete A[k];
	    for (size_t k = 0 ; k < B.size() ; k += 1) delete B[k];

	    if (!ok) {
		  cerr << loc << ": sorry: a `within' operand has a shape the "
		       << "assertion engine cannot duplicate; the assertion "
		       << "is dropped." << endl;
		  error_count += 1;
		  delete fail_stmt; delete clk; delete disable;
		  return;
	    }

	    if (!s2term) s2term = sva_bit_(loc, 1);
	    if (!s1embed) s1embed = sva_bit_(loc, 1);
	    PExpr*wmatch = sva_logic_(loc, 'a', s2term, s1embed);

	    if (kind == 2) {
		    /* cover: count each window that matches. Warm-up
		       cycles read $past as 0, so they never miscount. */
		  PExpr*ms = sva_rewrite_sampled_(loc, wmatch, inst, hist_idx,
						  pre, post, init_zero);
		  perm_string r_c = sva_make_reg_(loc, inst, "m", 0);
		  pre.push_back(sva_assign_(loc, r_c, ms));
		  perm_string r_cnt = sva_make_reg_(loc, inst, "cnt", 0, true);
		  init_zero.push_back(sva_assign_(loc, r_cnt,
			new PENumber(new verinum((uint64_t)0, 32))));
		  PEBinary*add = new PEBinary('+', sva_id_(loc, r_cnt),
					      sva_id_(loc, r_c));
		  FILE_NAME(add, loc);
		  body.push_back(sva_assign_(loc, r_cnt, add));
		  delete fail_stmt;
	    } else {
		    /* assert/assume: every mature window must match. A
		       `$past(1, L2)` guard is 0 until L2 cycles elapse, so
		       obligations that predate time 0 never fire. */
		  PExpr*valid = sva_past_(loc, sva_bit_(loc, 1), L2);
		  PExpr*failexpr = sva_logic_(loc, 'a', valid, sva_not_(loc, wmatch));
		  PExpr*fs = sva_rewrite_sampled_(loc, failexpr, inst, hist_idx,
						  pre, post, init_zero);
		  perm_string r_ff = sva_make_reg_(loc, inst, "ff", 0);
		  pre.push_back(sva_assign_(loc, r_ff, fs));
		  Statement*action = fail_stmt;
		  if (!action) {
			std::list<named_pexpr_t> no_args;
			PCallTask*err = new PCallTask(lex_strings.make("$error"),
						      no_args);
			FILE_NAME(err, loc);
			action = err;
		  }
		  body.push_back(sva_if_(loc, sva_id_(loc, r_ff),
					 sva_fail_action_(loc, inst, action), nullptr));
	    }
      }

	/* Assemble: pre-captures; disable guard around the checker body;
	   history updates. */
      std::vector<Statement*> full = pre;
      Statement*core = sva_block_(loc, body);
      if (disable) {
	    core = sva_if_(loc, disable, sva_assign_(loc, r_f, sva_bit_(loc, 0)),
			   core);
      }
      full.push_back(core);
      for (size_t k = 0 ; k < post.size() ; k += 1)
	    full.push_back(post[k]);

      clk->set_statement(sva_block_(loc, full));
      PProcess*pp = pform_make_behavior(IVL_PR_ALWAYS, clk, nullptr);
      FILE_NAME(pp, loc);

	/* M12B: VPI identity. */
      init_zero.push_back(sva_register_stmt_(loc, inst));
      PProcess*ip = pform_make_behavior(IVL_PR_INITIAL,
					sva_block_(loc, init_zero), nullptr);
      FILE_NAME(ip, loc);

      delete prop->antecedent;
      delete prop->seq;
      delete prop;
}

/* Lower one concurrent assertion (assert/assume/cover property) to a
   synthesized clocked checker. kind: 0=assert, 1=assume, 2=cover. */
void pform_make_assertion(const struct vlltype&loc, sva_property_t*prop,
			  Statement*fail_stmt, Statement*pass_stmt, int kind)
{
      if (!prop || !prop->seq || prop->seq->empty()) {
	    delete fail_stmt;
	    delete pass_stmt;
	    return;
      }

	/* Named property instantiation: `assert property (p);` where p
	   is a declared no-argument property of this module. */
      if (prop->op_type == 0 && prop->seq->size() == 1
	  && !prop->clk_evt && !prop->disable_iff_expr) {
	    if (PEIdent*id = dynamic_cast<PEIdent*>((*prop->seq)[0].expr)) {
		  if (!id->path().package && id->path().name.size() == 1
		      && id->path().name.front().index.empty()) {
			std::map<perm_string, sva_property_t*>::iterator pit =
			      sva_module_properties.find(id->path().name.front().name);
			if (pit != sva_module_properties.end() && pit->second) {
			      sva_property_t*named = pit->second;
			      pit->second = nullptr;  /* consume once */
			      delete id;
			      delete prop->seq;
			      delete prop;
			      pform_make_assertion(loc, named, fail_stmt,
						   pass_stmt, kind);
			      return;
			}
		  }
	    }
      }

	/* M9D: parameterized property instantiation `p(a,b)`. The clock
	   comes from the assertion site (`assert property (@(clk) p(...))`);
	   a clock in the property body is unsupported (would need per-
	   instantiation cloning of the event). */
      if (prop->op_type == 0 && prop->seq->size() == 1
	  && (*prop->seq)[0].delay_lo == 0 && (*prop->seq)[0].delay_hi == 0
	  && (*prop->seq)[0].rep_tail == 0) {
	    if (PECallFunction*cf = dynamic_cast<PECallFunction*>((*prop->seq)[0].expr)) {
		  if (!cf->path().package && cf->path().name.size() == 1) {
			perm_string nm = peek_tail_name(cf->path().name);
			std::map<perm_string, sva_param_prop_t>::iterator pit =
			      sva_param_properties.find(nm);
			if (pit != sva_param_properties.end() && pit->second.body) {
			      sva_property_t*decl = pit->second.body;
			      bool fatal = false;
			      if (decl->clk_evt) {
				    cerr << loc << ": sorry: a parameterized "
					 << "property with a clock in its body is "
					 << "not supported; put the clock at the "
					 << "assertion (`@(clk) " << nm << "(...)`)."
					 << endl;
				    error_count += 1;
				    fatal = true;
			      }
			      std::map<perm_string,PExpr*> subst;
			      if (!fatal && !sva_build_subst_(loc, "property", nm,
					pit->second.formals, cf->get_parms(), subst))
				    fatal = true;
			      sva_property_t*inst = nullptr;
			      if (!fatal) {
				    inst = new sva_property_t;
				    inst->op_type = decl->op_type;
				    inst->clk_evt = prop->clk_evt;
				    prop->clk_evt = nullptr;
				    inst->disable_iff_expr = prop->disable_iff_expr;
				    prop->disable_iff_expr = nullptr;
				    bool ok = true;
				    if (decl->seq) {
					  inst->seq = sva_clone_steps_subst_(loc, decl->seq, subst);
					  if (!inst->seq) ok = false;
				    }
				    if (ok && decl->antecedent) {
					  inst->antecedent = sva_clone_steps_subst_(loc, decl->antecedent, subst);
					  if (!inst->antecedent) ok = false;
				    }
				    if (!ok) {
					  cerr << loc << ": sorry: property `" << nm
					       << "' has a body expression that cannot "
					       << "be instantiated with arguments; the "
					       << "assertion is dropped." << endl;
					  error_count += 1;
					  delete inst->seq; delete inst->antecedent;
					  delete inst; inst = nullptr;
					  fatal = true;
				    }
			      }
			      delete (*prop->seq)[0].expr;
			      delete prop->seq;
			      delete prop;
			      if (fatal) { delete fail_stmt; delete pass_stmt; return; }
			      pform_make_assertion(loc, inst, fail_stmt, pass_stmt, kind);
			      return;
			}
		  }
	    }
      }

	/* M9C: temporal/sequence property operators (until family,
	   within) do not fit the linear token pipeline; dispatch them to
	   a dedicated lowering now that `kind` is known. */
      if (prop->op_type >= 4) {
	    pform_make_temporal_assertion_(loc, prop, fail_stmt, pass_stmt, kind);
	    return;
      }

      sva_splice_sequences_(loc, *prop->seq);
      if (prop->antecedent)
	    sva_splice_sequences_(loc, *prop->antecedent);

	/* Negated properties (op 3) and plain sequences (op 0) attempt
	   every cycle. */
      bool negated = (prop->op_type == 3);
      if (kind == 2 && negated) {
	    cerr << loc << ": sorry: `cover property (not ...)` is not "
		 << "supported; the cover is dropped." << endl;
	    error_count += 1;
	    delete fail_stmt; delete pass_stmt;
	    return;
      }

	/* Antecedent: op 0/3 check the sequence every cycle (constant
	   true); op 1/2 accept a boolean or a FIXED-delay sequence
	   antecedent (16.9.2): a chain match at offset P_a is the AND
	   of each step boolean delayed by (P_a - D_j) cycles, built on
	   the same history machinery as $past. Ranged or repetition-
	   marked antecedent steps are diagnosed. */
      PExpr*ante = nullptr;
      long ante_span = 0;
      if (prop->op_type == 0 || negated) {
	    ante = sva_bit_(loc, 1);
      } else if (prop->antecedent && prop->antecedent->size() == 1
		 && (*prop->antecedent)[0].delay_lo == 0
		 && (*prop->antecedent)[0].delay_hi == 0
		 && (*prop->antecedent)[0].rep_tail == 0) {
	    ante = (*prop->antecedent)[0].expr;
      } else {
	    bool ok = (prop->antecedent != nullptr);
	    long pa = 0;
	    if (ok) for (size_t j = 0 ; j < prop->antecedent->size() ; j += 1) {
		  const sva_seq_step_t&st = (*prop->antecedent)[j];
		  if (st.delay_lo < 0 || st.delay_lo != st.delay_hi
		      || st.rep_tail != 0) {
			ok = false;
			break;
		  }
		  pa += st.delay_lo;
	    }
	    if (!ok || pa > 128) {
		  cerr << loc << ": sorry: this assertion antecedent "
		       << "shape is not supported (fixed-delay sequence "
		       << "chains up to 128 cycles only); the assertion "
		       << "is dropped." << endl;
		  error_count += 1;
		  delete fail_stmt; delete pass_stmt;
		  return;
	    }
	    ante_span = pa;
      }

	/* |=> is |-> with one extra leading cycle. */
      std::vector<sva_seq_step_t>&seq = *prop->seq;
      if (prop->op_type == 2) {
	    seq[0].delay_lo += 1;
	    seq[0].delay_hi += 1;
      }

	/* Validate the chain shape: constant bounded delays, at most
	   one range, and only on the LAST step. */
      long total = 0;
      for (size_t j = 0 ; j < seq.size() ; j += 1) {
	    if (seq[j].delay_hi == -1 && j + 1 != seq.size()) {
		  cerr << loc << ": sorry: an unbounded ##[m:$] delay is "
		       << "only supported as the final step of a "
		       << "sequence; the assertion is dropped." << endl;
		  error_count += 1;
		  delete fail_stmt; delete pass_stmt;
		  return;
	    }
	    if (seq[j].delay_lo == -2) {
		  cerr << loc << ": sorry: sequence cycle delays must be "
		       << "literal constants; the assertion is dropped."
		       << endl;
		  error_count += 1;
		  delete fail_stmt; delete pass_stmt;
		  return;
	    }
	    if (seq[j].delay_lo == -3) {
		  cerr << loc << ": sorry: this repetition shape is not "
		       << "supported (literal bounds >= 1 on copyable "
		       << "operands only); the assertion is dropped."
		       << endl;
		  error_count += 1;
		  delete fail_stmt; delete pass_stmt;
		  return;
	    }
	    if (seq[j].rep_tail != 0 && j + 1 != seq.size()) {
		  cerr << loc << ": sorry: a [*m:n] range repetition is "
		       << "only supported as the final element of a "
		       << "sequence; the assertion is dropped." << endl;
		  error_count += 1;
		  delete fail_stmt; delete pass_stmt;
		  return;
	    }
	    if (seq[j].delay_lo != seq[j].delay_hi && j + 1 != seq.size()) {
		  cerr << loc << ": sorry: a ##[m:n] range is only "
		       << "supported as the final step of a sequence; "
		       << "the assertion is dropped." << endl;
		  error_count += 1;
		  delete fail_stmt; delete pass_stmt;
		  return;
	    }
	    if (seq[j].delay_hi >= 0)
		  total += seq[j].delay_hi;
	    else
		  total += seq[j].delay_lo;
      }
      if (total > 512) {
	    cerr << loc << ": sorry: sequence spans more than 512 cycles; "
		 << "the assertion is dropped." << endl;
	    error_count += 1;
	    delete fail_stmt; delete pass_stmt;
	    return;
      }

      bool unbounded = seq.back().delay_hi == -1;
      bool has_window = !unbounded
	    && seq.back().delay_lo != seq.back().delay_hi;
      size_t nfixed = seq.size() - ((has_window || unbounded) ? 1 : 0);
	/* P = pipeline depth: cycle offset of the last FIXED step
	   (or of the window entry point). */
      long P = 0;
      std::vector<long> offs (nfixed);
      for (size_t j = 0 ; j < nfixed ; j += 1) {
	    P += seq[j].delay_lo;
	    offs[j] = P;
      }
      long win_m = (has_window || unbounded) ? seq.back().delay_lo : 0;
      long win_n = has_window ? seq.back().delay_hi : 0;

      unsigned inst = sva_gensym_counter++;
      unsigned hist_idx = 0;
      std::vector<Statement*> pre, post, init_zero;

	/* M12B-cb: for assert/assume, report cbAssertionSuccess at each
	   match by folding the report into the pass action (which the
	   match machinery below fires). This also makes the match block
	   run when the user gave no pass statement. */
      if (kind != 2 && !negated) {
	    Statement*succ = sva_report_stmt_(loc, inst, SVA_CB_SUCCESS);
	    if (pass_stmt) {
		  std::vector<Statement*> v;
		  v.push_back(succ);
		  v.push_back(pass_stmt);
		  pass_stmt = sva_block_(loc, v);
	    } else {
		  pass_stmt = succ;
	    }
      }

	/* Clock: explicit, else the module's default clocking. */
      PEventStatement*clk = prop->clk_evt;
      if (!clk) {
	    Module*mod = pform_cur_module.empty() ? nullptr
			 : pform_cur_module.front();
	    if (!mod || mod->default_clocking.nil()) {
		  cerr << loc << ": error: concurrent assertion has no "
		       << "clocking event and no default clocking block "
		       << "is declared (IEEE 1800-2017 16.14.6)." << endl;
		  error_count += 1;
		  delete fail_stmt; delete pass_stmt;
		  return;
	    }
	    std::list<named_pexpr_t> no_parms;
	    PECallFunction*mark = new PECallFunction(
		  perm_string::literal("$ivl_default_clock"), no_parms);
	    FILE_NAME(mark, loc);
	    PEEvent*ev = new PEEvent(PEEvent::ANYEDGE, mark);
	    std::vector<PEEvent*> evs;
	    evs.push_back(ev);
	    clk = new PEventStatement(evs);
	    FILE_NAME(clk, loc);
      }

	/* disable iff: own, else the module `default disable iff`
	   (cloned so every assertion can use it). */
      PExpr*disable = prop->disable_iff_expr;
      if (!disable && sva_default_disable) {
	    disable = sva_clone_expr_(sva_default_disable);
	    if (!disable) {
		  cerr << loc << ": sorry: the `default disable iff` "
		       << "expression is too complex to copy; this "
		       << "assertion runs without it." << endl;
	    }
      }

	/* Rewrite sampled-value functions, then capture every step
	   boolean (and the antecedent) into 1-bit sample registers at
	   the top of the checker. */
      if (ante) {
	    ante = sva_rewrite_sampled_(loc, ante, inst, hist_idx, pre, post, init_zero);
      } else {
	      /* Fixed-delay sequence antecedent: match(now) is the AND
		 of each step boolean delayed by (span - offset) cycles,
		 via per-step capture + history chains. Zero-initialized
		 histories keep startup quiet (AND of 0 terms is 0). */
	    PExpr*conj = nullptr;
	    long doff = 0;
	    for (size_t j = 0 ; j < prop->antecedent->size() ; j += 1) {
		  sva_seq_step_t&ast = (*prop->antecedent)[j];
		  doff += ast.delay_lo;
		  long depth = ante_span - doff;
		  PExpr*abe = sva_rewrite_sampled_(loc, ast.expr, inst,
						   hist_idx, pre, post,
						   init_zero);
		  perm_string cap = sva_make_reg_(loc, inst, "ac", (unsigned)j);
		  pre.push_back(sva_assign_(loc, cap, abe));
		  init_zero.push_back(sva_assign_(loc, cap, sva_bit_(loc, 0)));
		  PExpr*term;
		  if (depth == 0) {
			term = sva_id_(loc, cap);
		  } else {
			std::vector<perm_string> ahist (depth);
			for (long k = 0 ; k < depth ; k += 1) {
			      ahist[k] = sva_make_reg_(loc, inst, "ah", hist_idx++);
			      init_zero.push_back(sva_assign_(loc, ahist[k],
							      sva_bit_(loc, 0)));
			}
			for (long k = depth-1 ; k >= 1 ; k -= 1)
			      post.push_back(sva_assign_(loc, ahist[k],
							 sva_id_(loc, ahist[k-1])));
			post.push_back(sva_assign_(loc, ahist[0], sva_id_(loc, cap)));
			term = sva_id_(loc, ahist[depth-1]);
		  }
		  if (conj) {
			PEBLogic*n2 = new PEBLogic('a', conj, term);
			FILE_NAME(n2, loc);
			conj = n2;
		  } else {
			conj = term;
		  }
	    }
	    ante = conj;
      }
      perm_string r_ante = sva_make_reg_(loc, inst, "b", 999);
      pre.push_back(sva_assign_(loc, r_ante, ante));
      std::vector<perm_string> r_b (seq.size());
      for (size_t j = 0 ; j < seq.size() ; j += 1) {
	    PExpr*be = sva_rewrite_sampled_(loc, seq[j].expr, inst,
					    hist_idx, pre, post, init_zero);
	    r_b[j] = sva_make_reg_(loc, inst, "b", (unsigned)j);
	    pre.push_back(sva_assign_(loc, r_b[j], be));
      }

	/* Pipeline, window, and bookkeeping registers. */
      std::vector<perm_string> t_regs (P > 0 ? P : 0);
      for (long p = 0 ; p < P ; p += 1) {
	    t_regs[p] = sva_make_reg_(loc, inst, "t", (unsigned)(p+1));
	    init_zero.push_back(sva_assign_(loc, t_regs[p], sva_bit_(loc, 0)));
      }
      long wregs_n = has_window ? win_n + 1 : (unbounded ? win_m : 0);
      std::vector<perm_string> w_regs (wregs_n);
      for (long q = 0 ; q < wregs_n ; q += 1) {
	    w_regs[q] = sva_make_reg_(loc, inst, "w", (unsigned)q);
	    init_zero.push_back(sva_assign_(loc, w_regs[q], sva_bit_(loc, 0)));
      }
      perm_string r_pend;
      if (unbounded) {
	    r_pend = sva_make_reg_(loc, inst, "pend", 0);
	    init_zero.push_back(sva_assign_(loc, r_pend, sva_bit_(loc, 0)));
      }
      perm_string r_g = sva_make_reg_(loc, inst, "g", 0);
      init_zero.push_back(sva_assign_(loc, r_g, sva_bit_(loc, 0)));
      perm_string r_f;
      perm_string r_cnt;
      if (kind == 2) {
	    r_cnt = sva_make_reg_(loc, inst, "cnt", 0, true);
	    init_zero.push_back(sva_assign_(loc, r_cnt,
			new PENumber(new verinum((uint64_t)0, 32))));
      } else {
	    r_f = sva_make_reg_(loc, inst, "f", 0);
	    init_zero.push_back(sva_assign_(loc, r_f, sva_bit_(loc, 0)));
      }

	/* The per-clock checker body. */
      std::vector<Statement*> body;

	/* g = antecedent sample; gate through the offset-0 steps. */
      body.push_back(sva_assign_(loc, r_g, sva_id_(loc, r_ante)));
      for (size_t j = 0 ; j < nfixed ; j += 1) {
	    if (offs[j] != 0) continue;
	      /* if (g && !b_j) begin [f=1;] g=0; end */
	    PEUnary*nb = new PEUnary('!', sva_id_(loc, r_b[j]));
	    FILE_NAME(nb, loc);
	    PEBLogic*cond = new PEBLogic('a', sva_id_(loc, r_g), nb);
	    FILE_NAME(cond, loc);
	    std::vector<Statement*> hit;
	    if (kind != 2 && !negated)
		  hit.push_back(sva_assign_(loc, r_f, sva_bit_(loc, 1)));
	    hit.push_back(sva_assign_(loc, r_g, sva_bit_(loc, 0)));
	    PCondit*c = new PCondit(cond, sva_block_(loc, hit), nullptr);
	    FILE_NAME(c, loc);
	    body.push_back(c);
      }

	/* Checks at offsets >= 1 run against the PRE-shift pipeline:
	   a token in t_p before this cycle's shift was injected p
	   cycles ago, exactly the age offset-p steps test. */
      for (size_t j = 0 ; j < nfixed ; j += 1) {
	    if (offs[j] == 0) continue;
	    perm_string treg = t_regs[offs[j]-1];
	    PEUnary*nb = new PEUnary('!', sva_id_(loc, r_b[j]));
	    FILE_NAME(nb, loc);
	    PEBLogic*cond = new PEBLogic('a', sva_id_(loc, treg), nb);
	    FILE_NAME(cond, loc);
	    std::vector<Statement*> hit;
	    if (kind != 2 && !negated)
		  hit.push_back(sva_assign_(loc, r_f, sva_bit_(loc, 1)));
	    hit.push_back(sva_assign_(loc, treg, sva_bit_(loc, 0)));
	    PCondit*c = new PCondit(cond, sva_block_(loc, hit), nullptr);
	    FILE_NAME(c, loc);
	    body.push_back(c);
      }

      if (has_window) {
	      /* Window updates also use the pre-shift t_P: a token
		 completing the fixed prefix (age P, checks passed)
		 enters the window at age 0 THIS cycle. */
	    for (long q = win_n ; q >= 1 ; q -= 1)
		  body.push_back(sva_assign_(loc, w_regs[q],
					     sva_id_(loc, w_regs[q-1])));
	    PExpr*enter = (P == 0) ? (PExpr*)sva_id_(loc, r_g)
				   : (PExpr*)sva_id_(loc, t_regs[P-1]);
	    body.push_back(sva_assign_(loc, w_regs[0], enter));

	      /* On the awaited boolean: satisfy every eligible
		 attempt (positions m..n); for cover, count them.
		 Otherwise an attempt at position n has failed. */
	    perm_string bw = r_b[seq.size()-1];
	      /* anyW: is any attempt in the eligible window? */
	    PExpr*anyw = nullptr;
	    for (long q = win_m ; q <= win_n ; q += 1) {
		  if (anyw) {
			PEBLogic*n2 = new PEBLogic('o', anyw,
						   sva_id_(loc, w_regs[q]));
			FILE_NAME(n2, loc);
			anyw = n2;
		  } else {
			anyw = sva_id_(loc, w_regs[q]);
		  }
	    }
	    std::vector<Statement*> sat;
	    if (negated) {
		    /* A match under `not` is the failure. */
		  PCondit*nm = new PCondit(anyw,
			sva_assign_(loc, r_f, sva_bit_(loc, 1)), nullptr);
		  FILE_NAME(nm, loc);
		  sat.push_back(nm);
		  anyw = nullptr;
	    } else if (pass_stmt && kind != 2) {
		  PCondit*pm = new PCondit(anyw, pass_stmt, nullptr);
		  FILE_NAME(pm, loc);
		  sat.push_back(pm);
		  pass_stmt = nullptr;
		  anyw = nullptr;
	    }
	    for (long q = win_m ; q <= win_n ; q += 1) {
		  if (kind == 2) {
			PEBinary*add = new PEBinary('+', sva_id_(loc, r_cnt),
						    sva_id_(loc, w_regs[q]));
			FILE_NAME(add, loc);
			sat.push_back(sva_assign_(loc, r_cnt, add));
		  }
		  sat.push_back(sva_assign_(loc, w_regs[q], sva_bit_(loc, 0)));
	    }
	    std::vector<Statement*> miss;
	    if (kind != 2 && !negated) {
		  std::vector<Statement*> mhit;
		  mhit.push_back(sva_assign_(loc, r_f, sva_bit_(loc, 1)));
		  mhit.push_back(sva_assign_(loc, w_regs[win_n], sva_bit_(loc, 0)));
		  PCondit*mc = new PCondit(sva_id_(loc, w_regs[win_n]),
					   sva_block_(loc, mhit), nullptr);
		  FILE_NAME(mc, loc);
		  miss.push_back(mc);
	    }
	    PCondit*wc = new PCondit(sva_id_(loc, bw), sva_block_(loc, sat),
				     miss.empty() ? nullptr
						  : sva_block_(loc, miss));
	    FILE_NAME(wc, loc);
	    body.push_back(wc);
      } else if (unbounded) {
	      /* Unbounded final window ##[m:$] — weak eventually
		 (16.9.2): an obligation can never fail in finite
		 time; it matures after m cycles and then waits. The
		 awaited boolean satisfies every mature obligation.
		 A final process reports obligations still pending at
		 end of simulation. */
	    perm_string bw = r_b[seq.size()-1];
	    PExpr*enter = (P == 0) ? (PExpr*)sva_id_(loc, r_g)
				   : (PExpr*)sva_id_(loc, t_regs[P-1]);
	      /* mature = the oldest immature slot (pre-shift), or the
		 entering token itself when m == 0. */
	    PExpr*mature = (win_m == 0) ? enter
			 : (PExpr*)sva_id_(loc, w_regs[win_m-1]);
	    perm_string r_mat = sva_make_reg_(loc, inst, "mat", 0);
	    init_zero.push_back(sva_assign_(loc, r_mat, sva_bit_(loc, 0)));
	    body.push_back(sva_assign_(loc, r_mat, mature));
	      /* maturity shift + entry */
	    for (long q = win_m-1 ; q >= 1 ; q -= 1)
		  body.push_back(sva_assign_(loc, w_regs[q],
					     sva_id_(loc, w_regs[q-1])));
	    if (win_m >= 1)
		  body.push_back(sva_assign_(loc, w_regs[0],
			(P == 0) ? (PExpr*)sva_id_(loc, r_g)
				 : (PExpr*)sva_id_(loc, t_regs[P-1])));
	      /* eligible = pend || mature */
	    PEBLogic*elig = new PEBLogic('o', sva_id_(loc, r_pend),
					 sva_id_(loc, r_mat));
	    FILE_NAME(elig, loc);
	    std::vector<Statement*> sat;
	    if (negated) {
		  PCondit*nm = new PCondit(elig,
			sva_assign_(loc, r_f, sva_bit_(loc, 1)), nullptr);
		  FILE_NAME(nm, loc);
		  sat.push_back(nm);
	    } else if (kind == 2) {
		  PEBinary*add = new PEBinary('+', sva_id_(loc, r_cnt), elig);
		  FILE_NAME(add, loc);
		  sat.push_back(sva_assign_(loc, r_cnt, add));
	    } else if (pass_stmt) {
		  PCondit*pm = new PCondit(elig, pass_stmt, nullptr);
		  FILE_NAME(pm, loc);
		  sat.push_back(pm);
		  pass_stmt = nullptr;
	    }
	    sat.push_back(sva_assign_(loc, r_pend, sva_bit_(loc, 0)));
	    std::vector<Statement*> miss;
	    PEBLogic*acc = new PEBLogic('o', sva_id_(loc, r_pend),
					sva_id_(loc, r_mat));
	    FILE_NAME(acc, loc);
	    miss.push_back(sva_assign_(loc, r_pend, acc));
	    PCondit*wc = new PCondit(sva_id_(loc, bw),
				     sva_block_(loc, sat),
				     sva_block_(loc, miss));
	    FILE_NAME(wc, loc);
	    body.push_back(wc);

	      /* End-of-simulation pending report. */
	    if (kind != 2 && !negated) {
		  PExpr*outst = sva_id_(loc, r_pend);
		  for (long q = 0 ; q < win_m ; q += 1) {
			PEBLogic*n2 = new PEBLogic('o', outst,
						   sva_id_(loc, w_regs[q]));
			FILE_NAME(n2, loc);
			outst = n2;
		  }
		  std::list<named_pexpr_t> dargs;
		  named_pexpr_t darg;
		  darg.parm = new PEString(strdup(
			"SVA: unbounded ##[m:$] obligation still pending "
			"at end of simulation"));
		  dargs.push_back(darg);
		  PCallTask*warn = new PCallTask(
			lex_strings.make("$display"), dargs);
		  FILE_NAME(warn, loc);
		  PCondit*fc = new PCondit(outst, warn, nullptr);
		  FILE_NAME(fc, loc);
		  PProcess*fp = pform_make_behavior(IVL_PR_FINAL, fc, nullptr);
		  FILE_NAME(fp, loc);
	    }
      } else if (kind == 2 || negated || pass_stmt) {
	      /* Fixed-final match: the token that survived the final
		 step (pre-shift age P, checks already applied). */
	    PExpr*match = (P == 0) ? (PExpr*)sva_id_(loc, r_g)
				   : (PExpr*)sva_id_(loc, t_regs[P-1]);
	    if (kind == 2) {
		  PEBinary*add = new PEBinary('+', sva_id_(loc, r_cnt), match);
		  FILE_NAME(add, loc);
		  body.push_back(sva_assign_(loc, r_cnt, add));
	    } else if (negated) {
		  PCondit*nm = new PCondit(match,
			sva_assign_(loc, r_f, sva_bit_(loc, 1)), nullptr);
		  FILE_NAME(nm, loc);
		  body.push_back(nm);
	    } else {
		  PCondit*pm = new PCondit(match, pass_stmt, nullptr);
		  FILE_NAME(pm, loc);
		  body.push_back(pm);
		  pass_stmt = nullptr;
	    }
      }

	/* Shift the token pipeline (descending) and inject this
	   cycle's attempt — after all age-based checks. */
      for (long p = P ; p >= 2 ; p -= 1)
	    body.push_back(sva_assign_(loc, t_regs[p-1],
				       sva_id_(loc, t_regs[p-2])));
      if (P >= 1)
	    body.push_back(sva_assign_(loc, t_regs[0], sva_id_(loc, r_g)));

	/* Fail dispatch (assert/assume). */
      if (kind != 2) {
	    Statement*action = fail_stmt;
	    if (!action) {
		  std::list<named_pexpr_t> no_args;
		  PCallTask*err = new PCallTask(
			lex_strings.make("$error"), no_args);
		  FILE_NAME(err, loc);
		  action = err;
	    }
	    std::vector<Statement*> hit;
	    hit.push_back(sva_assign_(loc, r_f, sva_bit_(loc, 0)));
	    hit.push_back(sva_fail_action_(loc, inst, action));
	    PCondit*fc = new PCondit(sva_id_(loc, r_f),
				     sva_block_(loc, hit), nullptr);
	    FILE_NAME(fc, loc);
	    body.push_back(fc);
      } else {
	    delete fail_stmt;
      }
	/* Any pass action not consumed by a match site above (cover,
	   negated) is dropped. */
      delete pass_stmt;

	/* Assemble: pre-captures; disable guard around the token
	   machinery; history updates. */
      std::vector<Statement*> full = pre;
      Statement*core = sva_block_(loc, body);
      if (disable) {
	    std::vector<Statement*> clr;
	    for (long p = 0 ; p < P ; p += 1)
		  clr.push_back(sva_assign_(loc, t_regs[p], sva_bit_(loc, 0)));
	    for (long q = 0 ; q < wregs_n ; q += 1)
		  clr.push_back(sva_assign_(loc, w_regs[q], sva_bit_(loc, 0)));
	    if (unbounded)
		  clr.push_back(sva_assign_(loc, r_pend, sva_bit_(loc, 0)));
	    clr.push_back(sva_assign_(loc, r_g, sva_bit_(loc, 0)));
	    if (kind != 2)
		  clr.push_back(sva_assign_(loc, r_f, sva_bit_(loc, 0)));
	    PCondit*dc = new PCondit(disable, sva_block_(loc, clr), core);
	    FILE_NAME(dc, loc);
	    full.push_back(dc);
      } else {
	    full.push_back(core);
      }
      for (size_t k = 0 ; k < post.size() ; k += 1)
	    full.push_back(post[k]);

      clk->set_statement(sva_block_(loc, full));
      PProcess*pp = pform_make_behavior(IVL_PR_ALWAYS, clk, nullptr);
      FILE_NAME(pp, loc);

	/* Zero-initialize the synthesized state, and register a VPI
	   identity for the assertion (M12B). */
      init_zero.push_back(sva_register_stmt_(loc, inst));
      PProcess*ip = pform_make_behavior(IVL_PR_INITIAL,
					sva_block_(loc, init_zero), nullptr);
      FILE_NAME(ip, loc);

      delete prop->antecedent;
      delete prop->seq;
      delete prop;
}

bool pform_requires_sv(const struct vlltype&loc, const char *feature)
{
      if (gn_system_verilog())
	    return true;

      VLerror(loc, "error: %s requires SystemVerilog.", feature);

      return false;
}

void pform_block_decls_requires_sv(void)
{
      for (auto const& wire : lexical_scope->wires) {
	    struct vlltype loc;
	    loc.text = wire.second->get_file();
	    loc.first_line = wire.second->get_lineno();
	    pform_requires_sv(loc, "Variable declaration in unnamed block");
      }
}

/* Returns true if the current block scope has no wires, parameters, or events
 * (i.e. no declarations were added, including inline SV-style declarations). */
bool pform_block_scope_is_empty(void)
{
      return lexical_scope->wires.empty()
	  && lexical_scope->parameters.empty()
	  && lexical_scope->events.empty();
}

void pform_check_net_data_type(const struct vlltype&loc, NetNet::Type net_type,
			       const data_type_t *data_type)
{
      // For SystemVerilog the type is checked during elaboration since due to
      // forward typedefs and type parameters the actual type might not be known
      // yet.
      if (gn_system_verilog())
	    return;

      switch (net_type) {
      case NetNet::REG:
      case NetNet::IMPLICIT_REG:
	    return;
      default:
	    break;
      }

      if (!data_type)
	    return;

      const vector_type_t*vec_type = dynamic_cast<const vector_type_t*>(data_type);
      if (vec_type && vec_type->implicit_flag)
	    return;

      if (!gn_cadence_types_flag)
	    VLerror(loc, "Net data type requires SystemVerilog or -gxtypes.");

      if (vec_type)
	    return;

      const real_type_t*rtype = dynamic_cast<const real_type_t*>(data_type);
      if (rtype && rtype->type_code() == real_type_t::REAL)
	    return;

      pform_requires_sv(loc, "Net data type");
}

FILE*vl_input = 0;
extern void reset_lexor();

int pform_parse(const char*path)
{
      vl_file = path;
      if (strcmp(path, "-") == 0) {
	    vl_input = stdin;
      } else if (ivlpp_string) {
	    char*cmdline = static_cast<char*>(malloc(strlen(ivlpp_string) +
	                                             strlen(path) + 4));
	    strcpy(cmdline, ivlpp_string);
	    strcat(cmdline, " \"");
	    strcat(cmdline, path);
	    strcat(cmdline, "\"");

	    if (verbose_flag)
		  cerr << "Executing: " << cmdline << endl<< flush;

	    vl_input = popen(cmdline, "r");
	    if (vl_input == 0) {
		  cerr << "Unable to preprocess " << path << "." << endl;
		  return 1;
	    }

	    if (verbose_flag)
		  cerr << "...parsing output from preprocessor..." << endl << flush;

	    free(cmdline);
      } else {
	    vl_input = fopen(path, "r");
	    if (vl_input == 0) {
		  cerr << "Unable to open " << path << "." << endl;
		  return 1;
	    }
      }

      if (pform_units.empty() || separate_compilation) {
	    char unit_name[20];
	    static unsigned nunits = 0;
	    if (separate_compilation)
		  snprintf(unit_name, sizeof(unit_name)-1, "$unit#%u", ++nunits);
	    else
		  snprintf(unit_name, sizeof(unit_name)-1, "$unit");

	    PPackage*unit = new PPackage(lex_strings.make(unit_name), 0);
	    unit->default_lifetime = LexicalScope::STATIC;
	    unit->set_file(filename_strings.make(path));
	    unit->set_lineno(1);
	    pform_units.push_back(unit);

            pform_cur_module.clear();
            pform_cur_generate = 0;
            pform_cur_modport = 0;

	    pform_set_timescale(def_ts_units, def_ts_prec, 0, 0);

	    allow_timeunit_decl = true;
	    allow_timeprec_decl = true;

	    lexical_scope = unit;
      }
      reset_parser_file_state();
      reset_lexor();
      error_count = 0;
      warn_count = 0;
      int rc = VLparse();

      if (vl_input != stdin) {
	    if (ivlpp_string)
		  pclose(vl_input);
	    else
		  fclose(vl_input);
      }

      if (rc) {
	    cerr << "I give up." << endl;
	    error_count += 1;
      }

      destroy_lexor();
      return error_count;
}

int pform_finish()
{
	// Any errors counted here were already reported by pform_parse
	// for their own file; count only what the finish steps add.
      error_count = 0;

      // Wait until all parsing is done and all symbols in the unit scope are
      // known before importing possible imports.
      for (auto unit : pform_units)
	    pform_check_possible_imports(unit);

      // Apply collected SystemVerilog bind directives now that every
      // target module has been parsed.
      pform_apply_binds();

      return error_count;
}
