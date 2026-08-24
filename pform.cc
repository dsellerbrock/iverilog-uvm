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
# include  "pform_sva_nfa.h"
# include  "discipline.h"
# include  <list>
# include  <map>
# include  <set>
# include  <cassert>
# include  <stack>
# include  <typeinfo>
# include  <sstream>
# include  <cstring>
# include  <cstdlib>
# include  <cctype>
# include  <climits>
# include  <cmath>

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
extern int VLdebug;

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

bool pform_in_compilation_unit_scope(void)
{
      return lexical_scope && lexical_scope->parent_scope() == nullptr;
}

bool pform_in_task_function_scope(void)
{
      for (LexicalScope*cur = lexical_scope; cur; cur = cur->parent_scope())
	    if (PTaskFunc*sub = dynamic_cast<PTaskFunc*>(cur))
	      if (sub->is_procedural_body_scope())
		  return true;
      return false;
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
	    // IEEE 1800-2017 26.3: a wildcard-imported name may be pinned
	    // into explicit_imports either by a GENUINE reference (tracked
	    // in wildcard_pin_used) or merely by the lexer's
	    // is-this-a-type probe (a resolution cache, not a use). A
	    // local declaration shadows an un-used wildcard pin; declaring
	    // a name whose imported meaning was already used is an error.
	    // A pin from an explicit `import P::name;` is always an error.
	    bool from_wildcard = false;
	    for (PPackage*wp : scope->potential_imports) {
		  if (wp == cur_pkg->second) { from_wildcard = true; break; }
	    }
	    if (from_wildcard
		&& scope->wildcard_pin_used.find(name) == scope->wildcard_pin_used.end()) {
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
	    if (scope->explicit_imports.find(name) != scope->explicit_imports.end()) {
		    // A genuine reference to a pinned name: record the use so
		    // a later local declaration of it is correctly rejected.
		  scope->wildcard_pin_used.insert(name);
		  return;
	    }
	    if (pform_find_potential_import(loc, scope, name, tf_call, true)) {
		  scope->wildcard_pin_used.insert(name);
		  return;
	    }

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
					     LexicalScope::lifetime_t lifetime,
					     bool procedural_body)
{
      perm_string func_name = lex_strings.make(name);

      LexicalScope::lifetime_t default_lifetime = find_lifetime(lifetime);
      bool is_auto = default_lifetime == LexicalScope::AUTOMATIC;

      PFunction*func = new PFunction(func_name, lexical_scope, is_auto);
      func->set_procedural_body_scope(procedural_body);
      func->default_lifetime = default_lifetime;
      FILE_NAME(func, loc);

      PScopeExtra*scopex = find_nearest_scopex(lexical_scope);
      ivl_assert(loc, scopex);
      pform_set_scope_timescale(func, scopex);

      lexical_scope = func;
      return func;
}

// Pending DPI export declarations (IEEE 1800-2017 35.5). An export may
// legally precede the subroutine definition in the same scope, so we
// record each one and resolve them all at end of parse
// (pform_resolve_dpi_exports), once every definition exists.
struct pending_dpi_export_s {
      LexicalScope*scope;
      perm_string sv_name;
      perm_string c_name;
      bool is_task;
      std::string loc_str;
};
static std::vector<pending_dpi_export_s> pending_dpi_exports_;

void pform_set_dpi_export(const struct vlltype&loc, const char*c_name,
			  const char*sv_name, bool is_task)
{
      PScopeExtra*scopex = find_nearest_scopex(lexical_scope);
      if (scopex == 0) {
	    cerr << loc << ": error: export \"DPI-C\" must appear inside a "
		    "module, package, or compilation unit." << endl;
	    error_count += 1;
	    return;
      }

      std::ostringstream tmp;
      tmp << loc;

      pending_dpi_export_s pend;
	  /* Keep the exact lexical scope. A generate block owns its own task
	     and function maps; collapsing it to the nearest module made a
	     forward export in that block appear out of scope at resolution. */
	  pend.scope   = lexical_scope;
      pend.sv_name = lex_strings.make(sv_name);
      pend.c_name  = lex_strings.make(c_name);
      pend.is_task = is_task;
      pend.loc_str = tmp.str();
      pending_dpi_exports_.push_back(pend);
}

void pform_resolve_dpi_exports(void)
{
      for (std::vector<pending_dpi_export_s>::iterator cur
		 = pending_dpi_exports_.begin()
		 ; cur != pending_dpi_exports_.end() ; ++cur) {
	    PTaskFunc*sub = 0;
	    if (PGenerate*gen = dynamic_cast<PGenerate*>(cur->scope)) {
		  if (cur->is_task) {
			map<perm_string,PTask*>::iterator it =
			      gen->tasks.find(cur->sv_name);
			if (it != gen->tasks.end()) sub = it->second;
		  } else {
			map<perm_string,PFunction*>::iterator it =
			      gen->funcs.find(cur->sv_name);
			if (it != gen->funcs.end()) sub = it->second;
		  }
	    } else if (PScopeExtra*scopex =
		       dynamic_cast<PScopeExtra*>(cur->scope)) {
		  if (cur->is_task) {
			map<perm_string,PTask*>::iterator it =
			      scopex->tasks.find(cur->sv_name);
			if (it != scopex->tasks.end()) sub = it->second;
		  } else {
			map<perm_string,PFunction*>::iterator it =
			      scopex->funcs.find(cur->sv_name);
			if (it != scopex->funcs.end()) sub = it->second;
		  }
	    }

	    if (sub == 0) {
		    // The subroutine is not visible in the export's scope.
		    // This is a loud sorry (never a silent drop): an
		    // unresolved export would otherwise fail to link from C
		    // with no explanation.
		  cerr << cur->loc_str << ": sorry: export \"DPI-C\" "
		       << (cur->is_task ? "task" : "function") << " '"
		       << cur->sv_name << "' has no matching definition in "
			  "its scope; out-of-scope export is not yet "
			  "supported. Calls from C to '" << cur->c_name
		       << "' will not link." << endl;
		  continue;
	    }

	    if (sub->is_dpi_import()) {
		  cerr << cur->loc_str << ": error: '" << cur->sv_name
		       << "' is a DPI import; it cannot also be exported "
			  "(IEEE 1800-2017 35.5)." << endl;
		  error_count += 1;
		  continue;
	    }

	    sub->set_dpi_export(cur->c_name.str());
      }
      pending_dpi_exports_.clear();
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

namespace {

struct pattern_binding_t {
      perm_string name;
      pform_pattern_path_t path;
};

static void collect_pattern_bindings_(const PMatchPattern*pattern,
                                      pform_pattern_path_t&path,
                                      vector<pattern_binding_t>&bindings)
{
      if (!pattern)
            return;

      switch (pattern->kind()) {
          case PMatchPattern::VARIABLE: {
            pattern_binding_t binding;
            binding.name = pattern->name();
            binding.path = path;
            bindings.push_back(binding);
            break;
          }
          case PMatchPattern::TAGGED:
            path.push_back(pform_pattern_path_component_t(pattern->name()));
            if (!pattern->children().empty())
                  collect_pattern_bindings_(pattern->children().front(), path,
                                            bindings);
            path.pop_back();
            break;
          case PMatchPattern::STRUCTURE:
            for (size_t idx = 0; idx < pattern->children().size(); idx += 1) {
                  path.push_back(pform_pattern_path_component_t((unsigned)idx));
                  collect_pattern_bindings_(pattern->children()[idx], path,
                                            bindings);
                  path.pop_back();
            }
            break;
          case PMatchPattern::CONSTANT:
          case PMatchPattern::WILDCARD:
            break;
      }
}

static bool pattern_subject_path_(const struct vlltype&loc,
                                  const PExpr*subject,
                                  pform_scoped_name_t&path,
                                  unsigned&lexical_pos)
{
      const PEIdent*ident = dynamic_cast<const PEIdent*>(subject);
      if (!ident || ident->leading_type_args()) {
            VLerror(loc, "sorry: pattern variables currently require an "
                         "identifier-valued match subject.");
            return false;
      }

      for (const name_component_t&component : ident->path().name) {
            if (!component.index.empty()) {
                  VLerror(loc, "sorry: pattern variables currently require an "
                               "unindexed match subject.");
                  return false;
            }
      }

      path = ident->path();
      lexical_pos = ident->lexical_pos();
      return true;
}

static vector<pattern_binding_t>
pattern_bindings_(const struct vlltype&loc, const PMatchPattern*pattern,
                  bool diagnose_duplicates)
{
      vector<pattern_binding_t> collected;
      pform_pattern_path_t path;
      collect_pattern_bindings_(pattern, path, collected);

      vector<pattern_binding_t> bindings;
      set<perm_string> names;
      for (const pattern_binding_t&binding : collected) {
            if (!names.insert(binding.name).second) {
                  if (diagnose_duplicates) {
                        ostringstream msg;
                        msg << "error: pattern variable '" << binding.name
                            << "' is declared more than once in the same "
                               "pattern.";
		        VLerror(loc, "%s", msg.str().c_str());
                  }
                  continue;
            }
            bindings.push_back(binding);
      }
      return bindings;
}

} // namespace

PBlock* pform_pattern_push_scope(const struct vlltype&loc,
                                 const PExpr*subject,
                                 const PMatchPattern*pattern)
{
      PBlock*block = pform_push_block_scope(loc, nullptr, PBlock::BL_SEQ);

      vector<pattern_binding_t> bindings = pattern_bindings_(loc, pattern,
                                                             true);
      if (bindings.empty())
            return block;

      pform_scoped_name_t subject_path;
      unsigned lexical_pos = 0;
      if (!pattern_subject_path_(loc, subject, subject_path, lexical_pos))
            return block;

      for (const pattern_binding_t&binding : bindings) {
            PWire*wire = pform_makewire(
                  loc, pform_ident_t(binding.name, loc.lexical_pos),
                  NetNet::IMPLICIT_REG, nullptr);
            pattern_binding_type_t*type = new pattern_binding_type_t(
                  subject_path, lexical_pos, binding.path);
            FILE_NAME(type, loc);
            wire->set_data_type(type);
      }
      return block;
}

PBlock* pform_pattern_finish_scope(const struct vlltype&loc,
                                   PBlock*block,
                                   Statement*statement,
                                   const PExpr*subject,
                                   const PMatchPattern*pattern)
{
      pform_pop_scope();

      vector<Statement*> statements;
      if (statement)
            statements.push_back(statement);
      block->set_statement(statements);

      vector<pattern_binding_t> bindings = pattern_bindings_(loc, pattern,
                                                             false);
      if (bindings.empty())
            return block;

      pform_scoped_name_t subject_path;
      unsigned lexical_pos = 0;
      if (!pattern_subject_path_(loc, subject, subject_path, lexical_pos))
            return block;

      for (vector<pattern_binding_t>::reverse_iterator it = bindings.rbegin();
           it != bindings.rend(); ++it) {
            PPatternAssign*assign = new PPatternAssign(
                  subject_path, lexical_pos, it->path, it->name);
            FILE_NAME(assign, loc);
            block->push_statement_front(assign);
      }
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

static nettype_t* pform_install_nettype_(const struct vlltype&loc,
                                         perm_string name,
                                         nettype_t*nettype)
{
      FILE_NAME(nettype, loc);
      add_local_symbol(lexical_scope, name, nettype);
      map<perm_string,PNamedItem*>::const_iterator installed =
            lexical_scope->local_symbols.find(name);
      if (installed == lexical_scope->local_symbols.end()
          || installed->second != nettype) {
            delete nettype;
            return nullptr;
      }
      lexical_scope->nettypes[name] = nettype;
      return nettype;
}

nettype_t* pform_declare_nettype(
                              const struct vlltype&loc, perm_string name,
                              data_type_t*data_type,
                              const pform_scoped_name_t*resolution_function)
{
      if (!data_type) {
            VLerror(loc, "error: Nettype `%s` has no data type.", name.str());
            return nullptr;
      }
      return pform_install_nettype_(
            loc, name, new nettype_t(name, data_type, resolution_function));
}

nettype_t* pform_declare_nettype_alias(const struct vlltype&loc,
                                       perm_string name, nettype_t*alias)
{
      if (!alias) {
            VLerror(loc, "error: Nettype alias `%s` has no target.", name.str());
            return nullptr;
      }
      return pform_install_nettype_(loc, name, new nettype_t(name, alias));
}

void pform_set_nettype_referenced(const struct vlltype&loc, const char*name)
{
      check_potential_imports(loc, lex_strings.make(name), false);
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

static typedef_t* pform_find_class_typedef_graph_(PClass*class_scope,
						   perm_string name,
						   set<PClass*>&seen)
{
      if (!class_scope || !class_scope->type || !seen.insert(class_scope).second)
	    return nullptr;

      auto local = class_scope->typedefs.find(name);
      if (local != class_scope->typedefs.end())
	    return local->second;

      vector<const data_type_t*>parents;
      if (class_scope->type->base_type)
	    parents.push_back(class_scope->type->base_type.get());
      /* Implements does not inherit typedefs (8.26.3). Interface-class
	 inheritance does, so only an interface class walks these edges. */
      if (class_scope->type->interface_class) {
	    for (const std::unique_ptr<data_type_t>&parent :
		 class_scope->type->interface_types)
		  parents.push_back(parent.get());
      }

      for (const data_type_t*parent_type : parents) {
	    const typeref_t*parent_ref =
		  dynamic_cast<const typeref_t*>(parent_type);
	    if (!parent_ref || !parent_ref->typedef_ref())
		  continue;

	    PClass*parent = pform_find_visible_class_scope(
		  class_scope, parent_ref->typedef_ref()->name);
	    if (typedef_t*found = pform_find_class_typedef_graph_(
		  parent, name, seen))
		  return found;
      }

      return nullptr;
}

static typedef_t* pform_find_inherited_class_typedef(PClass*class_scope,
						      perm_string name)
{
      if (!class_scope || !class_scope->type)
	    return nullptr;

      set<PClass*>seen;
      seen.insert(class_scope);

      if (class_scope->type->base_type) {
	    const typeref_t*base_ref = dynamic_cast<const typeref_t*>(
		  class_scope->type->base_type.get());
	    PClass*base = base_ref && base_ref->typedef_ref()
		  ? pform_find_visible_class_scope(
			class_scope, base_ref->typedef_ref()->name) : nullptr;
	    if (typedef_t*found = pform_find_class_typedef_graph_(base, name, seen))
		  return found;
      }

      if (class_scope->type->interface_class) {
	    for (const std::unique_ptr<data_type_t>&parent_type :
		 class_scope->type->interface_types) {
		  const typeref_t*parent_ref = dynamic_cast<const typeref_t*>(
			parent_type.get());
		  PClass*parent = parent_ref && parent_ref->typedef_ref()
			? pform_find_visible_class_scope(
			      class_scope, parent_ref->typedef_ref()->name) : nullptr;
		  if (typedef_t*found = pform_find_class_typedef_graph_(
			parent, name, seen))
			return found;
	    }
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
      bool ambiguous = false;

      for (PPackage*search_pkg : scope->potential_imports) {
	    PPackage*decl_pkg = pform_package_importable(search_pkg, name);
	    if (!decl_pkg)
		  continue;

	    auto cur = decl_pkg->typedefs.find(name);
	    if (cur == decl_pkg->typedefs.end())
		  continue;

	    if (found_type && found_type != cur->second) {
		    // Ambiguous: do not pin and do not report from the probe
		    // (it fires for every identifier and would duplicate the
		    // message). A genuine reference reports the ambiguity via
		    // check_potential_imports / pform_find_potential_import.
		  ambiguous = true;
		  continue;
	    }

	    found_type = cur->second;
	    found_decl_pkg = decl_pkg;
	      // Do NOT pin the name into explicit_imports here. This
	      // function backs the lexer's is-this-a-type probe
	      // (pform_test_type_identifier), which fires for every
	      // identifier -- including the declarator of a local
	      // `typedef ... word;` that legitimately shadows a
	      // wildcard-imported name (IEEE 1800-2017 26.3). Pinning on a
	      // mere probe made every probed name look "referenced", which
	      // forced add_local_symbol to drop wildcard pins
	      // unconditionally and so lost the required error for
	      // declare-after-use (sv_wildcard_import4). Genuine type USES
	      // pin via pform_set_type_referenced ->
	      // check_potential_imports when a type reference reduces.
      }

	// Pin an UNAMBIGUOUS hit into explicit_imports as a resolution
	// cache: later phases (and elaboration) resolve the name through
	// the pin. This does NOT mark the name as used —
	// wildcard_pin_used tracks genuine references, so a local
	// declaration can still shadow a merely-probed name.
      if (found_type && !ambiguous) {
	    scope->explicit_imports[name] = found_decl_pkg;
	    scope->explicit_imports_from[name].insert(found_decl_pkg);
      }

      return found_type;
}

typedef_t* pform_test_type_identifier(const struct vlltype&loc, const char*txt)
{
      if (getenv("IVL_TRACE_TYPES"))
	    cerr << "TYPE_TRACE " << loc << " name=" << txt
		 << " scope=" << lexical_scope << endl;
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

	      // IEEE 1800-2017 6.18: a nearer non-type declaration
	      // shadows an outer type name. A data declaration such as
	      // `max_delay_cg_obj max_delay_cg_obj[string];` makes later
	      // bare references to the name a variable, not a type.
	    if (cur_scope->wires.find(name) != cur_scope->wires.end())
		  return 0;
	    if (PClass*shadow_class = dynamic_cast<PClass*>(cur_scope)) {
		  if (shadow_class->type
		      && shadow_class->type->properties.find(name)
			 != shadow_class->type->properties.end())
			return 0;
	    }

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

nettype_t* pform_test_nettype_identifier(PPackage*pkg, const char*txt)
{
      if (!pkg)
            return nullptr;
      perm_string name = lex_strings.make(txt);
      LexicalScope::nettype_map_t::const_iterator cur = pkg->nettypes.find(name);
      return cur == pkg->nettypes.end() ? nullptr : cur->second;
}

static nettype_t* pform_find_potential_imported_nettype_(
                                    LexicalScope*scope, perm_string name)
{
      nettype_t*found = nullptr;
      PPackage*found_decl_pkg = nullptr;
      bool ambiguous = false;
      for (PPackage*search_pkg : scope->potential_imports) {
            PPackage*decl_pkg = pform_package_importable(search_pkg, name);
            if (!decl_pkg)
                  continue;
            LexicalScope::nettype_map_t::const_iterator cur =
                  decl_pkg->nettypes.find(name);
            if (cur == decl_pkg->nettypes.end())
                  continue;
            if (found && found != cur->second) {
                  ambiguous = true;
                  continue;
            }
            found = cur->second;
            found_decl_pkg = decl_pkg;
      }
      if (found && !ambiguous) {
            scope->explicit_imports[name] = found_decl_pkg;
            scope->explicit_imports_from[name].insert(found_decl_pkg);
            return found;
      }
      return nullptr;
}

nettype_t* pform_test_nettype_identifier(const struct vlltype&loc,
                                         const char*txt)
{
      (void)loc;
      perm_string name = lex_strings.make(txt);
      for (LexicalScope*scope = lexical_scope; scope;
           scope = scope->parent_scope()) {
            map<perm_string,PPackage*>::const_iterator explicit_import =
                  scope->explicit_imports.find(name);
            if (explicit_import != scope->explicit_imports.end())
                  return pform_test_nettype_identifier(explicit_import->second,
                                                       txt);

            LexicalScope::nettype_map_t::const_iterator local =
                  scope->nettypes.find(name);
            if (local != scope->nettypes.end())
                  return local->second;

            /* A nearer declaration in the shared namespace shadows an outer
             * nettype, even when it is not itself a nettype. */
            if (scope->local_symbols.find(name) != scope->local_symbols.end())
                  return nullptr;

            if (nettype_t*imported_nettype =
                      pform_find_potential_imported_nettype_(scope, name))
                  return imported_nettype;
      }
      return nullptr;
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
      if (type_args)
	    tmp->set_scoped_type_prefix();
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
      if (const PEConcat*cat = dynamic_cast<const PEConcat*>(e)) {
	    list<PExpr*> parms;
	    for (vector<PExpr*>::const_iterator it = cat->stream_parms().begin()
		 ; it != cat->stream_parms().end() ; ++it) {
		  PExpr*sub = pform_dup_case_expr_(*it);
		  if (!sub) {
			for (list<PExpr*>::iterator jt = parms.begin()
			     ; jt != parms.end() ; ++jt)
			      delete *jt;
			return 0;
		  }
		  parms.push_back(sub);
	    }
	    PExpr*repeat = 0;
	    if (cat->has_repeat()) {
		  repeat = pform_dup_case_expr_(cat->repeat_expr());
		  if (!repeat) {
			for (list<PExpr*>::iterator jt = parms.begin()
			     ; jt != parms.end() ; ++jt)
			      delete *jt;
			return 0;
		  }
	    }
	    PEConcat*cp = new PEConcat(parms, repeat);
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

Statement* pform_make_quality_if(const struct vlltype&loc,
                                 ivl_case_quality_t qual,
                                 PExpr*cond,
                                 Statement*if_clause,
                                 Statement*else_clause)
{
      std::vector<PCase::Item*>*items = new std::vector<PCase::Item*>;

      auto append_condition = [&loc, items](PExpr*expr, Statement*stmt) {
            // An if condition is true for any nonzero integral value. Reduce
            // it to one bit before using the existing case-quality engine;
            // `case (1'b1)` must not compare 1 against an unreduced vector.
            PEUnary*not_expr = new PEUnary('!', expr);
            FILE_NAME(not_expr, loc);
            PEUnary*truth_expr = new PEUnary('!', not_expr);
            FILE_NAME(truth_expr, loc);
            PCase::Item*item = new PCase::Item;
            item->expr.push_back(truth_expr);
            item->stat = stmt;
            items->push_back(item);
      };

      append_condition(cond, if_clause);

      // The grammar has already associated a bare `else if` as a nested
      // PCondit. Flatten only that direct chain. An `else begin ... if ...`
      // remains a single default branch, as required by its block boundary.
      Statement*tail = else_clause;
      while (PCondit*next = dynamic_cast<PCondit*>(tail)) {
            if (!next->is_parsed_if_statement())
                  break;
            PExpr*next_cond = next->release_cond_expr();
            Statement*next_if = next->release_if_clause();
            tail = next->release_else_clause();
            delete next;
            append_condition(next_cond, next_if);
      }

      if (tail) {
            PCase::Item*def = new PCase::Item;
            def->stat = tail;
            items->push_back(def);
      }

      PENumber*one = new PENumber(new verinum(verinum::V1, 1));
      FILE_NAME(one, loc);
      PCase*result = new PCase(qual, NetCase::EQ, one, items, true);
      FILE_NAME(result, loc);
      return result;
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
	/* M9-SV: bind or diagnose any sampled value function still
	   waiting for a clock. Before the pop, because binding
	   synthesizes a sampler process into THIS module's scope. */
      pform_flush_pending_sampled_calls();

      Module*cur_module  = pform_cur_module.front();
      pform_cur_module.pop_front();
      perm_string mod_name = cur_module->mod_name();

	/* M9-10: an unclocked concurrent assertion that never found an
	   enclosing procedural event control is an error, reported here so
	   the whole module has been seen. */
      pform_sva_flush_pending_procedural();

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

      /* An inline `for (genvar i = ...)' declaration is visible throughout
	 the generate loop body. Register it in the lexical genvar table before
	 that body is parsed, just like a separate `genvar i;' declaration. In
	 particular, module-port expressions are scanned for implicit nets while
	 parsing; without this entry, a run-time-looking use such as `.en(i < N)'
	 manufactured an implicit wire named i in every generated scope. That wire
	 then shadowed the per-instance genvar localparam in constant contexts such
	 as an output connection `.q(array[i])'. */
      if (local_index) {
	    PGenvar*genvar = new PGenvar();
	    FILE_NAME(genvar, li);
	    add_local_symbol(pform_cur_generate,
			     pform_cur_generate->loop_index, genvar);
	    pform_cur_generate->genvars[pform_cur_generate->loop_index] = genvar;
      }
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
      if (name == "$dumpports") gn_dumpports_flag = true;
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
 * the event, and not necessarily the use of it. array_dims is the
 * declared unpacked-array bound (IEEE 1800-2017 6.20, e.g.
 * `event arr[3];`), or null for an ordinary scalar event; ownership
 * transfers to the PEvent.
 */
static void pform_make_event(const struct vlltype&loc, const pform_ident_t&name,
			      std::list<pform_range_t>*array_dims)
{
      PEvent*event = new PEvent(name.first, name.second);
      FILE_NAME(event, loc);
      if (array_dims) event->set_array_dims(array_dims);

      add_local_symbol(lexical_scope, name.first, event);
      lexical_scope->events[name.first] = event;
}

void pform_make_events(const struct vlltype&loc,
		       const list<pform_event_ident_t*>*names)
{
      for (auto cur = names->begin() ;  cur != names->end() ; ++ cur ) {
	    pform_make_event(loc, (*cur)->ident, (*cur)->array_dims);
	    delete *cur;
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
			if (cur.decl_init) {
			      decl->expr.reset(cur.decl_init);
			      cur.decl_init = 0;
			}
			decls->push_back(decl);
		  }

		  if (declaration_like) {
			  // This is a genuine use of the type name (a
			  // variable declaration through the no-port
			  // instantiation shape), so record the type
			  // reference — this pins a wildcard-imported type
			  // so a later local redeclaration of the name is
			  // correctly rejected (sv_wildcard_import4).
			pform_set_type_referenced(loc, type);
			  // Preserve a parameterized-class specialization:
			  // `box #(plain) b;` reaches here as a no-port
			  // instantiation shape whose `#(...)` module-parameter
			  // overrides are the class's type/value arguments.
			  // Thread them onto the typeref so the handle
			  // declaration specializes the class exactly as an
			  // `extends box#(plain)` clause would. Without this the
			  // generic netclass (all type parameters at their
			  // defaults) was bound, and type-parameter members kept
			  // their default types.
			typeref_t*dtype = new typeref_t(decl_type, 0, overrides);
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

	// A declaration initializer only makes sense when the construct is
	// reinterpreted as a user-type variable declaration above. Reaching
	// here with one means either the left name did not resolve to a
	// type (`unknown_t v = 0;`) or the shape really is a module
	// instantiation (`mod inst = 0;`) — both are hard errors, never a
	// silent drop of the initializer.
      for (unsigned idx = 0 ; idx < gates->size() ; idx += 1) {
	    lgate&cur = (*gates)[idx];
	    if (cur.decl_init == 0)
		  continue;
	    cerr << loc << ": error: "
		 << "Invalid declaration `" << type << " " << cur.name
		 << " = ...;`: `" << type
		 << "' is not a visible data type, and a module "
		 << "instantiation cannot have an initializer." << endl;
	    error_count += 1;
	    delete gates;
	    return;
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
	// Bind-to-instance forms: entries are plain instance names or
	// dot-joined hierarchical paths. Null for bind-to-definition.
      std::list<std::string>*inst_paths;
};
static vector<pending_bind_t> pending_binds;

/*
 * A bind directive is a generate item (IEEE 1800-2017 27.2), so a
 * directive in an unselected conditional-generate arm must not be applied.
 * Binds are normally moved into their target module after parsing, before
 * generate elaboration takes place.  Preserve the important constant-literal
 * case here rather than losing the enclosing generate context.  This is the
 * form produced by preprocessor configuration switches (for example,
 * OpenTitan's ``if (`EN_MASKING) bind ...'').
 *
 * Non-literal generate conditions continue through the normal path: they can
 * depend on parameters and therefore require the later, parameter-aware bind
 * elaboration path.  Do not guess their value here.
 */
static bool bind_in_statically_unselected_generate_()
{
      for (const PGenerate*gen = pform_cur_generate ; gen ; ) {
	    if (gen->scheme_type == PGenerate::GS_CONDIT
		|| gen->scheme_type == PGenerate::GS_ELSE) {
		  const PENumber*num = dynamic_cast<const PENumber*>(gen->loop_test);
		  if (num && num->value().is_defined()) {
			bool selected = !num->value().is_zero();
			if (gen->scheme_type == PGenerate::GS_ELSE)
			      selected = !selected;
			if (!selected) return true;
		  }
	    }

	    gen = dynamic_cast<const PGenerate*>(gen->parent_scope());
      }
      return false;
}

void pform_bind_directive(const struct vlltype&loc,
			  perm_string target,
			  perm_string type,
			  struct parmvalue_t*overrides,
			  std::vector<lgate>*gates,
			  std::list<std::string>*inst_paths)
{
      if (bind_in_statically_unselected_generate_())
	    return;

      pending_bind_t cur;
      FILE_NAME(&cur.li, loc);
      cur.target = target;
      cur.type = type;
      cur.overrides = overrides;
      cur.gates = gates;
      cur.inst_paths = inst_paths;
      pending_binds.push_back(cur);
}

/*
 * Resolve a dot-joined hierarchical instance path against the parsed
 * module tree and return the module DEFINITION instantiated at that
 * path. The first component must name a root module (root scopes take
 * their module's name); each later component must be a module instance
 * inside the previous module's definition. This is a purely syntactic
 * walk over pform, so paths that thread through generate blocks or
 * instance arrays cannot be resolved here and get a loud diagnostic.
 */
static Module* bind_resolve_instance_path_(const LineInfo&li,
					   const std::string&path)
{
      vector<string> comps;
      string::size_type pos = 0;
      while (pos <= path.size()) {
	    string::size_type dot = path.find('.', pos);
	    if (dot == string::npos) {
		  comps.push_back(path.substr(pos));
		  break;
	    }
	    comps.push_back(path.substr(pos, dot-pos));
	    pos = dot + 1;
      }

      map<perm_string,Module*>::iterator match
	    = pform_modules.find(lex_strings.make(comps[0].c_str()));
      if (match == pform_modules.end()) {
	    cerr << li.get_fileline() << ": error: "
		 << "bind target instance path '" << path
		 << "': '" << comps[0] << "' does not name a module; "
		 << "the path must start at a root (top-level) module."
		 << endl;
	    error_count += 1;
	    return 0;
      }
      Module*cur = match->second;

      for (size_t idx = 1 ; idx < comps.size() ; idx += 1) {
	    perm_string iname = lex_strings.make(comps[idx].c_str());
	    PGate*gate = cur->get_gate(iname);
	    PGModule*modgate = dynamic_cast<PGModule*>(gate);
	    if (modgate == 0) {
		  cerr << li.get_fileline() << ": error: "
		       << "bind target instance path '" << path
		       << "': no module instance '" << comps[idx]
		       << "' inside module '" << cur->mod_name()
		       << "'. Note: bind instance paths cannot reach "
		       << "through generate blocks or instance arrays."
		       << endl;
		  error_count += 1;
		  return 0;
	    }
	    map<perm_string,Module*>::iterator next
		  = pform_modules.find(modgate->get_type());
	    if (next == pform_modules.end()) {
		  cerr << li.get_fileline() << ": error: "
		       << "bind target instance path '" << path
		       << "': instance '" << comps[idx]
		       << "' is of type '" << modgate->get_type()
		       << "', which is not a module defined in this "
		       << "compilation." << endl;
		  error_count += 1;
		  return 0;
	    }
	    cur = next->second;
      }
      return cur;
}

static void bind_apply_one(Module*scope, pending_bind_t&bind,
			   const std::vector<std::string>&inst_filter)
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
			      byname[pdx].parm->reloc_lexical_pos_bind(true);
		  }
		  gate->set_parameters(byname, cnt);
	    } else if (bind.overrides && bind.overrides->by_order) {
		  for (list<PExpr*>::iterator odx = bind.overrides->by_order->begin()
			     ; odx != bind.overrides->by_order->end() ; ++odx) {
			if (*odx) (*odx)->reloc_lexical_pos_bind(true);
		  }
		  gate->set_parameters(bind.overrides->by_order);
	    }

	    if (!inst_filter.empty())
		  gate->set_bind_instance_filter(inst_filter);

	    if (cur_name != "")
		  add_local_symbol(scope, cur_name, gate);
	    scope->add_gate(gate);
      }
}

/*
 * Existence check for the plain-name entries of a bind instance list
 * (bind <mod> : u1, ...). A plain name matches any instance of the
 * target module with that instance name, wherever it occurs, so scan
 * every parsed module definition for at least one such instantiation
 * and complain loudly if there is none (a typo would otherwise make
 * the bind a silent no-op).
 */
static bool bind_instance_name_exists_(perm_string iname, perm_string type)
{
      for (map<perm_string,Module*>::iterator mod = pform_modules.begin()
		 ; mod != pform_modules.end() ; ++mod) {
	    PGModule*modgate
		  = dynamic_cast<PGModule*>(mod->second->get_gate(iname));
	    if (modgate && modgate->get_type() == type)
		  return true;
      }
      return false;
}

void pform_apply_binds(void)
{
      for (vector<pending_bind_t>::iterator cur = pending_binds.begin()
		 ; cur != pending_binds.end() ; ++cur) {

	    Module*target_mod = 0;
	    std::vector<std::string> inst_filter;

	    if (cur->target == "") {
		    // bind <hier.path> <type> <inst> (...): the target
		    // module is whatever the path instantiates.
		  ivl_assert(cur->li, cur->inst_paths
			     && cur->inst_paths->size() == 1);
		  const string&path = cur->inst_paths->front();
		  target_mod = bind_resolve_instance_path_(cur->li, path);
		  if (target_mod == 0)
			continue;
		  inst_filter.push_back(path);

	    } else {
		  map<perm_string,Module*>::iterator match
			= pform_modules.find(cur->target);
		  if (match == pform_modules.end()) {
			  // IEEE 1800-2017 23.11: a target that names no
			  // module may be a bind_target_instance. Search
			  // the parsed modules for an instantiation with
			  // this instance name; when every such instance
			  // has one module type, bind into those
			  // instances via the plain-name filter.
			perm_string inst_type;
			bool ambiguous = false;
			for (map<perm_string,Module*>::iterator mod = pform_modules.begin()
				   ; mod != pform_modules.end() ; ++mod) {
			      PGModule*modgate = dynamic_cast<PGModule*>
				    (mod->second->get_gate(cur->target));
			      if (modgate == 0)
				    continue;
			      if (!inst_type.nil()
				  && inst_type != modgate->get_type())
				    ambiguous = true;
			      inst_type = modgate->get_type();
			}
			if (!inst_type.nil() && !ambiguous) {
			      map<perm_string,Module*>::iterator tmatch
				    = pform_modules.find(inst_type);
			      if (tmatch != pform_modules.end()) {
				    target_mod = tmatch->second;
				    inst_filter.push_back(string(cur->target));
			      }
			}
			if (target_mod == 0) {
			      if (ambiguous) {
				    cerr << cur->li.get_fileline() << ": error: "
					 << "bind target instance '" << cur->target
					 << "' matches instances of different "
					 << "module types; qualify the path." << endl;
			      } else {
				    cerr << cur->li.get_fileline() << ": error: "
					 << "bind target module/interface '" << cur->target
					 << "' is not defined in this compilation." << endl;
			      }
			      error_count += 1;
			      continue;
			}
		  } else {
		  target_mod = match->second;

		  if (cur->inst_paths) {
			  // bind <mod> : <inst list> ...: validate every
			  // entry now so a typo cannot silently bind
			  // nothing.
			bool bad = false;
			for (list<string>::iterator pp = cur->inst_paths->begin()
				   ; pp != cur->inst_paths->end() ; ++pp) {
			      if (pp->find('.') == string::npos) {
				    perm_string iname
					  = lex_strings.make(pp->c_str());
				    if (!bind_instance_name_exists_(iname, target_mod->mod_name())) {
					  cerr << cur->li.get_fileline()
					       << ": error: bind instance "
					       << "list entry '" << *pp
					       << "': no instance of module '"
					       << cur->target << "' with that "
					       << "instance name exists." << endl;
					  error_count += 1;
					  bad = true;
					  continue;
				    }
			      } else {
				    Module*at = bind_resolve_instance_path_(cur->li, *pp);
				    if (at == 0) {
					  bad = true;
					  continue;
				    }
				    if (at != target_mod) {
					  cerr << cur->li.get_fileline()
					       << ": error: bind instance "
					       << "list entry '" << *pp
					       << "' is an instance of module '"
					       << at->mod_name() << "', not of "
					       << "the bind target '"
					       << cur->target << "'." << endl;
					  error_count += 1;
					  bad = true;
					  continue;
				    }
			      }
			      inst_filter.push_back(*pp);
			}
			if (bad)
			      continue;
		  }
	    }
	    }

	    if (cur->type == target_mod->mod_name()) {
		  cerr << cur->li.get_fileline() << ": error: "
		       << "bind of module '" << cur->type
		       << "' into itself would recurse forever." << endl;
		  error_count += 1;
		  continue;
	    }
	    if (target_mod->program_block) {
		  cerr << cur->li.get_fileline() << ": error: "
		       << "bind target '" << target_mod->mod_name()
		       << "' is a program block; module instantiations "
		       << "are not allowed in program blocks." << endl;
		  error_count += 1;
		  continue;
	    }

	    bind_apply_one(target_mod, *cur, inst_filter);
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

void pform_module_define_nettype_port(const struct vlltype&li,
                                     const pform_ident_t&name,
                                     NetNet::PortType port_kind,
                                     nettype_t*nettype,
                                     list<pform_range_t>*urange,
                                     list<named_pexpr_t>*attr,
                                     bool keep_attr)
{
      PWire*wire = pform_get_or_make_wire(
            li, name, NetNet::UNRESOLVED_WIRE, port_kind, SR_BOTH);
      if (!wire->set_user_nettype(nettype)) {
            cerr << li << ": error: Port `" << name.first
                 << "` is redeclared with an incompatible nettype." << endl;
            error_count += 1;
      }
      if (urange) {
            wire->set_unpacked_idx(*urange);
            delete urange;
      }
      pform_bind_attributes(wire->attributes, attr, keep_attr);
}

void pform_module_define_nettype_port(const struct vlltype&li,
                                     list<pform_port_t>*ports,
                                     NetNet::PortType port_kind,
                                     nettype_t*nettype,
                                     list<named_pexpr_t>*attr)
{
      for (list<pform_port_t>::iterator cur = ports->begin();
           cur != ports->end(); ++cur) {
            pform_module_define_nettype_port(
                  li, cur->name, port_kind, nettype, cur->udims, attr, true);
            if (cur->expr) {
                  cerr << li << ": error: User-defined nettype port `"
                       << cur->name.first << "` cannot have a default value."
                       << endl;
                  error_count += 1;
                  delete cur->expr;
            }
      }
      delete ports;
      delete attr;
}

static data_type_t* clone_interconnect_type_(const data_type_t*type,
                                             const struct vlltype&loc)
{
      if (!type)
            return nullptr;
      const vector_type_t*vec = dynamic_cast<const vector_type_t*>(type);
      if (!vec || !vec->implicit_flag) {
            VLerror(loc, "error: interconnect requires an implicit data type.");
            return nullptr;
      }
      list<pform_range_t>*dims = vec->pdims.get()
            ? new list<pform_range_t>(*vec->pdims) : nullptr;
      vector_type_t*copy = new vector_type_t(vec->base_type,
                                             vec->signed_flag, dims);
      copy->implicit_flag = true;
      FILE_NAME(copy, loc);
      return copy;
}

data_type_t* pform_module_define_interconnect_port(const struct vlltype&li,
                                     const pform_ident_t&name,
                                     NetNet::PortType port_kind,
                                     data_type_t*implicit_type,
                                     list<pform_range_t>*urange,
                                     list<named_pexpr_t>*attr,
                                     bool keep_attr)
{
      PWire*wire = pform_get_or_make_wire(
            li, name, NetNet::WIRE, port_kind, SR_BOTH);
      bool compatible = wire->set_interconnect();
      if (!compatible) {
            cerr << li << ": error: Port `" << name.first
                 << "` is redeclared with an incompatible net kind." << endl;
            error_count += 1;
      }
      if (implicit_type) {
            if (compatible && !wire->data_type()) {
                  pform_set_net_range(
                        wire, dynamic_cast<vector_type_t*>(implicit_type),
                        SR_BOTH);
                  wire->set_data_type(implicit_type);
            } else if (wire->data_type() != implicit_type) {
                  delete implicit_type;
            }
      }
      if (urange) {
            wire->set_unpacked_idx(*urange);
            delete urange;
      }
      pform_bind_attributes(wire->attributes, attr, keep_attr);
      return const_cast<data_type_t*>(wire->data_type());
}

void pform_module_define_interconnect_port(const struct vlltype&li,
                                     list<pform_port_t>*ports,
                                     NetNet::PortType port_kind,
                                     data_type_t*implicit_type,
                                     list<named_pexpr_t>*attr)
{
      for (list<pform_port_t>::iterator cur = ports->begin();
           cur != ports->end(); ++cur) {
            data_type_t*copy = clone_interconnect_type_(implicit_type, li);
            pform_module_define_interconnect_port(
                  li, cur->name, port_kind, copy, cur->udims, attr, true);
            if (cur->expr) {
                  cerr << li << ": error: interconnect port `" << cur->name.first
                       << "` cannot have a default value." << endl;
                  error_count += 1;
                  delete cur->expr;
            }
      }
      delete implicit_type;
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

void pform_set_nettype_wires(const struct vlltype&li,
                             nettype_t*nettype,
                             vector<PWire*>*wires,
                             list<named_pexpr_t>*attr)
{
      for (vector<PWire*>::iterator cur = wires->begin();
           cur != wires->end(); ++cur) {
            if (!(*cur)->set_user_nettype(nettype)) {
                  cerr << li << ": error: Net `" << (*cur)->basename()
                       << "` is redeclared with an incompatible nettype."
                       << endl;
                  error_count += 1;
            }
            pform_bind_attributes((*cur)->attributes, attr, true);
      }
      delete wires;
      delete attr;
}

void pform_make_nettype_wires(const struct vlltype&li,
                              nettype_t*nettype,
                              list<PExpr*>*delay,
                              str_pair_t str,
                              list<decl_assignment_t*>*assign_list,
                              list<named_pexpr_t>*attr)
{
      while (!assign_list->empty()) {
            decl_assignment_t*decl = assign_list->front();
            assign_list->pop_front();
            PWire*wire = pform_makewire(
                  li, decl->name, NetNet::UNRESOLVED_WIRE, &decl->index);
            if (!wire->set_user_nettype(nettype)) {
                  cerr << li << ": error: Net `" << decl->name.first
                       << "` is redeclared with an incompatible nettype."
                       << endl;
                  error_count += 1;
            }
            pform_bind_attributes(wire->attributes, attr, true);
            if (PExpr*expr = decl->expr.release()) {
                  PEIdent*lval = new PEIdent(decl->name.first,
                                             decl->name.second);
                  FILE_NAME(lval, li);
                  PGAssign*ass = pform_make_pgassign(lval, expr, delay, str);
                  FILE_NAME(ass, li);
            }
            delete decl;
      }
      delete assign_list;
      delete attr;
}

void pform_set_interconnect_wires(const struct vlltype&li,
                                  data_type_t*implicit_type,
                                  vector<PWire*>*wires,
                                  list<named_pexpr_t>*attr)
{
      for (vector<PWire*>::iterator cur = wires->begin();
           cur != wires->end(); ++cur) {
            bool compatible = (*cur)->set_interconnect();
            if (!compatible) {
                  cerr << li << ": error: Net `" << (*cur)->basename()
                       << "` is redeclared with an incompatible net kind."
                       << endl;
                  error_count += 1;
            }
            data_type_t*copy = clone_interconnect_type_(implicit_type, li);
            if (copy && compatible && !(*cur)->data_type()) {
                  pform_set_net_range(
                        *cur, dynamic_cast<vector_type_t*>(copy), SR_NET);
                  (*cur)->set_data_type(copy);
            } else {
                  delete copy;
            }
            pform_bind_attributes((*cur)->attributes, attr, true);
      }
      delete implicit_type;
      delete wires;
      delete attr;
}

void pform_make_interconnect_wires(const struct vlltype&li,
                                   data_type_t*implicit_type,
                                   list<decl_assignment_t*>*assign_list,
                                   list<named_pexpr_t>*attr)
{
      vector<PWire*>*wires = new vector<PWire*>;
      bool had_initializer = false;
      while (!assign_list->empty()) {
            decl_assignment_t*decl = assign_list->front();
            assign_list->pop_front();
            wires->push_back(pform_makewire(
                  li, decl->name, NetNet::WIRE, &decl->index));
            if (decl->expr) {
                  had_initializer = true;
                  decl->expr.reset();
            }
            delete decl;
      }
      delete assign_list;
      if (had_initializer)
            VLerror(li, "error: Interconnect nets cannot have initializers.");
      pform_set_interconnect_wires(li, implicit_type, wires, attr);
}

enum pform_struct_default_shape_t {
      PFORM_STRUCT_DEFAULT_SCALAR,
      PFORM_STRUCT_DEFAULT_FIXED_ARRAY,
      PFORM_STRUCT_DEFAULT_DYNAMIC_ARRAY,
      PFORM_STRUCT_DEFAULT_QUEUE,
      PFORM_STRUCT_DEFAULT_ASSOC_ARRAY
};

static pform_struct_default_shape_t
pform_struct_default_shape_(const list<pform_range_t>*dimensions)
{
      if (!dimensions || dimensions->empty())
            return PFORM_STRUCT_DEFAULT_SCALAR;

      const pform_range_t&dimension = dimensions->front();
      if (!dimension.first)
            return PFORM_STRUCT_DEFAULT_DYNAMIC_ARRAY;
      if (dynamic_cast<const PENull*>(dimension.first))
            return PFORM_STRUCT_DEFAULT_QUEUE;
      if (dynamic_cast<const PEAssocType*>(dimension.first))
            return PFORM_STRUCT_DEFAULT_ASSOC_ARRAY;
      return PFORM_STRUCT_DEFAULT_FIXED_ARRAY;
}

static const char*
pform_struct_default_shape_name_(pform_struct_default_shape_t shape)
{
      switch (shape) {
          case PFORM_STRUCT_DEFAULT_FIXED_ARRAY:
            return "fixed-size unpacked array";
          case PFORM_STRUCT_DEFAULT_DYNAMIC_ARRAY:
            return "dynamic array";
          case PFORM_STRUCT_DEFAULT_QUEUE:
            return "queue";
          case PFORM_STRUCT_DEFAULT_ASSOC_ARRAY:
            return "associative array";
          case PFORM_STRUCT_DEFAULT_SCALAR:
            break;
      }
      return "scalar";
}

struct pform_struct_default_type_t {
      const struct_type_t*type = 0;
      const typedef_t*defining_typedef = 0;
      pform_struct_default_shape_t shape = PFORM_STRUCT_DEFAULT_SCALAR;
};

/*
 * Resolve typedef chains without taking ownership of any of the shared pform
 * type nodes. An unpacked-array typedef is classified so callers can reject
 * shapes for which synthesizing a scalar `variable.member' lvalue would be
 * incorrect.
 */
static pform_struct_default_type_t
pform_find_struct_default_type_(const data_type_t*data_type)
{
      pform_struct_default_type_t res;
      set<const typedef_t*> seen;

      while (data_type) {
            if (const typeref_t*type_ref =
                        dynamic_cast<const typeref_t*>(data_type)) {
                  typedef_t*td = type_ref->typedef_ref();
                  if (!td || !seen.insert(td).second)
                        return res;
                  res.defining_typedef = td;
                  data_type = td->get_data_type();
                  continue;
            }

            if (const uarray_type_t*array_type =
                        dynamic_cast<const uarray_type_t*>(data_type)) {
                  if (res.shape == PFORM_STRUCT_DEFAULT_SCALAR)
                        res.shape =
                              pform_struct_default_shape_(array_type->dims.get());
                  data_type = array_type->base_type.get();
                  continue;
            }

            break;
      }

      const struct_type_t*struct_type =
            dynamic_cast<const struct_type_t*>(data_type);
      if (struct_type && !struct_type->packed_flag &&
          !struct_type->union_flag)
            res.type = struct_type;

      return res;
}

static const struct_type_t*
pform_find_struct_or_union_type_(const data_type_t*data_type)
{
      set<const typedef_t*> seen;

      while (data_type) {
            if (const typeref_t*type_ref =
                        dynamic_cast<const typeref_t*>(data_type)) {
                  typedef_t*td = type_ref->typedef_ref();
                  if (!td || !seen.insert(td).second)
                        return 0;
                  data_type = td->get_data_type();
                  continue;
            }

            if (const array_base_t*array_type =
                        dynamic_cast<const array_base_t*>(data_type)) {
                  data_type = array_type->base_type.get();
                  continue;
            }

            break;
      }

      return dynamic_cast<const struct_type_t*>(data_type);
}

static bool
pform_struct_has_direct_member_defaults_(const struct_type_t*struct_type)
{
      if (!struct_type->members)
            return false;

      for (const struct_member_t*mbrp : *struct_type->members) {
            if (!mbrp->names)
                  continue;
            for (const decl_assignment_t*mname : *mbrp->names) {
                  if (mname->expr)
                        return true;
            }
      }

      return false;
}

static perm_string
pform_struct_union_member_(const struct_type_t*struct_type)
{
      if (!struct_type->members)
            return perm_string();

      for (const struct_member_t*mbrp : *struct_type->members) {
            const struct_type_t*member_type =
                  pform_find_struct_or_union_type_(mbrp->type.get());
            if (!member_type || !member_type->union_flag ||
                !mbrp->names || mbrp->names->empty())
                  continue;
            return mbrp->names->front()->name.first;
      }

      return perm_string();
}

static bool
pform_validate_struct_member_defaults_(const vlltype&li,
                                       const struct_type_t*struct_type,
                                       perm_string variable_name,
                                       set<const struct_type_t*>&seen)
{
      if (!struct_type->members || !seen.insert(struct_type).second)
            return true;

      bool valid = true;
      const bool has_direct_defaults =
            pform_struct_has_direct_member_defaults_(struct_type);

      if (struct_type->packed_flag && !struct_type->union_flag &&
          has_direct_defaults) {
            cerr << li.get_fileline()
                 << ": error: individual member defaults are not allowed in "
                    "packed struct variable `" << variable_name << "'."
                 << endl;
            error_count += 1;
            valid = false;
      }

      if (struct_type->union_flag && has_direct_defaults) {
            cerr << li.get_fileline()
                 << ": error: individual member defaults are not allowed in "
                    "union variable `" << variable_name << "'."
                 << endl;
            error_count += 1;
            valid = false;
      }

      const perm_string union_member =
            pform_struct_union_member_(struct_type);
      if (!struct_type->packed_flag && !struct_type->union_flag &&
          !union_member.nil() &&
          has_direct_defaults) {
            cerr << li.get_fileline()
                 << ": error: individual member defaults are not allowed in "
                    "unpacked struct variable `" << variable_name
                 << "' because the struct contains union member `"
                 << union_member << "'." << endl;
            error_count += 1;
            valid = false;
      }

      for (const struct_member_t*mbrp : *struct_type->members) {
            const struct_type_t*nested =
                  pform_find_struct_or_union_type_(mbrp->type.get());
            if (nested &&
                !pform_validate_struct_member_defaults_(
                      li, nested, variable_name, seen))
                  valid = false;
      }

      return valid;
}

bool pform_validate_struct_member_defaults(
      const vlltype&li, const data_type_t*data_type,
      const decl_assignment_t*variable)
{
      const struct_type_t*root =
            pform_find_struct_or_union_type_(data_type);
      if (!root)
            return true;

      set<const struct_type_t*> seen;
      return pform_validate_struct_member_defaults_(
            li, root, variable->name.first, seen);
}

/*
 * A borrowed member-default expression must elaborate in the scope that owns
 * its typedef. Lexical ancestors remain directly resolvable, and package
 * typedefs are resolved by exact pointer identity in
 * NetScope::find_typedef_scope. Other outside scopes (notably C::T for a
 * class-scoped typedef used outside C) still have no exact owner lookup, so
 * retain the loud unsupported boundary for those cases.
 */
static bool
pform_struct_default_typedef_scope_resolvable_(
      const typedef_t*defining_typedef)
{
      if (!defining_typedef)
            return true;

      for (LexicalScope*scope = lexical_scope ; scope ;
           scope = scope->parent_scope()) {
            LexicalScope::typedef_map_t::const_iterator cur =
                  scope->typedefs.find(defining_typedef->name);
            if (cur != scope->typedefs.end() &&
                cur->second == defining_typedef)
                  return true;
      }

      for (PPackage*package_scope : pform_packages) {
            LexicalScope::typedef_map_t::const_iterator cur =
                  package_scope->typedefs.find(defining_typedef->name);
            if (cur != package_scope->typedefs.end() &&
                cur->second == defining_typedef)
                  return true;
      }

      return false;
}

static bool
pform_struct_has_member_defaults_(const struct_type_t*struct_type,
                                  set<const struct_type_t*>&active)
{
      if (!struct_type->members || !active.insert(struct_type).second)
            return false;

      bool has_defaults = false;
      for (const struct_member_t*mbrp : *struct_type->members) {
            if (!mbrp->names)
                  continue;
            for (const decl_assignment_t*mname : *mbrp->names) {
                  if (mname->expr) {
                        has_defaults = true;
                        break;
                  }

                  const pform_struct_default_type_t nested =
                        pform_find_struct_default_type_(mbrp->type.get());
                  if (nested.type &&
                      pform_struct_has_member_defaults_(nested.type, active)) {
                        has_defaults = true;
                        break;
                  }
            }
            if (has_defaults)
                  break;
      }

      active.erase(struct_type);
      return has_defaults;
}

static bool
pform_struct_has_member_defaults_(const struct_type_t*struct_type)
{
      set<const struct_type_t*> active;
      return pform_struct_has_member_defaults_(struct_type, active);
}

bool pform_has_implicit_struct_member_defaults(
      const data_type_t*data_type, const decl_assignment_t*variable)
{
      if (!variable || variable->expr)
            return false;

      const pform_struct_default_type_t info =
            pform_find_struct_default_type_(data_type);
      return info.type && pform_struct_has_member_defaults_(info.type);
}

static void
pform_append_struct_member_defaults_(const vlltype&li,
                                     const struct_type_t*struct_type,
                                     const typedef_t*defining_typedef,
                                     const pform_name_t&variable_path,
                                     perm_string variable_name,
                                     unsigned lexical_pos,
                                     vector<Statement*>&initializers,
                                     set<const struct_type_t*>&active)
{
      if (!struct_type->members || !active.insert(struct_type).second)
            return;

      for (const struct_member_t*mbrp : *struct_type->members) {
            if (!mbrp->names)
                  continue;

            for (decl_assignment_t*mname : *mbrp->names) {
                  pform_name_t member_path(variable_path);
                  member_path.push_back(name_component_t(mname->name.first));

                  const pform_struct_default_type_t member_info =
                        pform_find_struct_default_type_(mbrp->type.get());
                  pform_struct_default_shape_t member_shape =
                        member_info.shape;
                  if (member_shape == PFORM_STRUCT_DEFAULT_SCALAR)
                        member_shape =
                              pform_struct_default_shape_(&mname->index);

                  if (PExpr*default_expr = mname->expr.get()) {
                        if (member_shape != PFORM_STRUCT_DEFAULT_SCALAR) {
                              cerr << li.get_fileline()
                                   << ": sorry: unpacked-struct default "
                                      "member initializers are not yet "
                                      "supported for "
                                   << pform_struct_default_shape_name_(
                                         member_shape)
                                   << " member `" << mname->name.first
                                   << "' of variable `" << variable_name
                                   << "'; provide an explicit whole-variable "
                                      "initializer." << endl;
                              error_count += 1;
                              continue;
                        }

                        PEIdent*lval = new PEIdent(member_path, lexical_pos);
                        FILE_NAME(lval, li);
                        PAssign*ass = new PAssign(lval, default_expr,
                                                  true, true, false,
                                                  defining_typedef);
                        FILE_NAME(ass, li);
                        initializers.push_back(ass);
                        continue;
                  }

                  const pform_struct_default_type_t&nested = member_info;
                  if (!nested.type ||
                      !pform_struct_has_member_defaults_(nested.type))
                        continue;

                  if (member_shape != PFORM_STRUCT_DEFAULT_SCALAR) {
                        cerr << li.get_fileline()
                             << ": sorry: unpacked-struct default member "
                                "initializers are not yet supported through "
                             << pform_struct_default_shape_name_(member_shape)
                             << " member `" << mname->name.first
                             << "' of variable `" << variable_name << "'."
                             << endl;
                        error_count += 1;
                        continue;
                  }

                  if (!pform_struct_default_typedef_scope_resolvable_(
                            nested.defining_typedef)) {
                        cerr << li.get_fileline()
                             << ": sorry: unpacked-struct default member "
                                "initializers from typedef `"
                             << nested.defining_typedef->name
                             << "' outside the consuming lexical scope are "
                                "not yet supported for member `"
                             << mname->name.first << "' of variable `"
                             << variable_name
                             << "'; provide an explicit whole-variable "
                                "initializer." << endl;
                        error_count += 1;
                        continue;
                  }

                  pform_append_struct_member_defaults_(
                        li, nested.type,
                        nested.defining_typedef
                              ? nested.defining_typedef : defining_typedef,
                        member_path, variable_name,
                        lexical_pos, initializers, active);
            }
      }

      active.erase(struct_type);
}

/*
 * IEEE 1800-2017 7.2.2: initialize each unpacked-struct member that
 * declares a default, unless the variable has an explicit whole-variable
 * initializer. The member expressions remain owned by the reusable type
 * AST; synthesized assignments deliberately borrow them.
 *
 * Constant-expression legality is checked when the declaring type elaborates,
 * including for an unused typedef or a member default suppressed by an
 * explicit whole-variable initializer. Synthesized assignments consult that
 * declaration result before applying a valid default to each variable.
 */
void pform_make_struct_member_defaults(const vlltype&li,
                                       const data_type_t*data_type,
                                       decl_assignment_t*variable,
                                       vector<Statement*>&initializers)
{
      const pform_struct_default_type_t info =
            pform_find_struct_default_type_(data_type);
      if (!info.type || !pform_struct_has_member_defaults_(info.type))
            return;

        // An explicit initializer suppresses all member defaults.
      if (variable->expr)
            return;

      if (!pform_struct_default_typedef_scope_resolvable_(
                info.defining_typedef)) {
            cerr << li.get_fileline()
                 << ": sorry: unpacked-struct default member initializers "
                    "from typedef `" << info.defining_typedef->name
                 << "' outside the consuming lexical scope are not yet "
                    "supported for variable `" << variable->name.first
                 << "'; provide an explicit whole-variable initializer."
                 << endl;
            error_count += 1;
            return;
      }

      pform_struct_default_shape_t shape = info.shape;
      if (shape == PFORM_STRUCT_DEFAULT_SCALAR)
            shape = pform_struct_default_shape_(&variable->index);

      if (shape != PFORM_STRUCT_DEFAULT_SCALAR) {
            cerr << li.get_fileline()
                 << ": sorry: unpacked-struct default member "
                    "initializers are not yet supported for "
                 << pform_struct_default_shape_name_(shape)
                 << " variable declaration `" << variable->name.first
                 << "'; provide an explicit whole-variable initializer."
                 << endl;
            error_count += 1;
            return;
      }

      pform_name_t variable_path;
      variable_path.push_back(name_component_t(variable->name.first));
      set<const struct_type_t*> active;
      pform_append_struct_member_defaults_(
            li, info.type, info.defining_typedef,
            variable_path, variable->name.first,
            variable->name.second, initializers, active);
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
            if (type == NetNet::REG || type == NetNet::IMPLICIT_REG) {
                  if (!pform_validate_struct_member_defaults(
                            li, data_type, first)) {
                        // The validation emitted the mandatory diagnostic.
                  } else if (is_const &&
                      pform_has_implicit_struct_member_defaults(data_type,
                                                                 first)) {
                        cerr << li.get_fileline()
                             << ": sorry: unpacked-struct default member "
                                "initializers are not yet supported for const "
                                "variable declaration `" << first->name.first
                             << "'; provide an explicit whole-variable "
                                "initializer." << endl;
                        error_count += 1;
                  } else {
                        pform_make_struct_member_defaults(
                              li, data_type, first,
                              lexical_scope->var_inits);
                  }
            }
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
      FILE_NAME(type, loc);
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
	    // The dimensions are kept as declared, so an inline declaration
	    // elaborates identically to a typedef'd one and a select of X[i]
	    // addresses an inner-width ELEMENT. An earlier revision flattened
	    // the dims to a single combined range here; that made X[i] a
	    // one-bit select of the flattened vector and silently returned
	    // the wrong value (gap ledger G15).
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

void pform_set_net_delay(const struct vlltype&li, list<PExpr*>*delay,
			 vector<PWire*>*wires)
{
      if (!delay)
	    return;

      shared_ptr<PDelays> net_delay(new PDelays);
      net_delay->set_delays(delay, true);
      delete delay;

      for (vector<PWire*>::iterator cur = wires->begin();
	   cur != wires->end(); ++cur) {
	    if (!(*cur)->set_net_delay(net_delay)) {
		  cerr << li << ": error: Net `" << (*cur)->basename()
		       << "' has an incompatible or duplicate net delay."
		       << endl;
		  error_count += 1;
	    }
      }
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

/* M9-SV: bind any sampled value function calls parsed inside this
 * behavior to the block's own clocking event (IEEE 1800-2017 16.9.3,
 * clock inference 16.14.6). Defined after the sampled-value rewrite it
 * shares with the assertion engine. */
static void pform_bind_procedural_sampled_(ivl_process_type_t type,
					   Statement*st);

/* Concurrent assertions are lowered into ordinary-looking behavioral
 * processes for simulation. Keep an explicit provenance marker while that
 * lowering runs so synthesis can discard those checker processes without
 * mistaking user RTL for verification logic. The depth counter is needed
 * because named/parameterized properties recurse through
 * pform_make_assertion(). */
static unsigned pform_generated_verification_depth_ = 0;

class pform_generated_verification_scope_t {
    public:
      pform_generated_verification_scope_t()
      { pform_generated_verification_depth_ += 1; }

      ~pform_generated_verification_scope_t()
      {
	    assert(pform_generated_verification_depth_ > 0);
	    pform_generated_verification_depth_ -= 1;
      }

    private:
      pform_generated_verification_scope_t(
	    const pform_generated_verification_scope_t&) = delete;
      pform_generated_verification_scope_t& operator=(
	    const pform_generated_verification_scope_t&) = delete;
};

static void pform_mark_generated_verification_process_(PProcess*process)
{
      if (pform_generated_verification_depth_ == 0)
	    return;

      process->generated_verification();
}

PProcess* pform_make_behavior(ivl_process_type_t type, Statement*st,
			      list<named_pexpr_t>*attr)
{
      pform_bind_procedural_sampled_(type, st);

	// Add an implicit @* around the statement for the always_comb and
	// always_latch statements.
      if ((type == IVL_PR_ALWAYS_COMB) || (type == IVL_PR_ALWAYS_LATCH)) {
	    PEventStatement *tmp = new PEventStatement(true);
	    tmp->set_line(*st);
	    tmp->set_statement(st);
	    st = tmp;
      }

      PProcess*pp = new PProcess(type, st);
      pform_mark_generated_verification_process_(pp);

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

/* Defined with the concurrent-assertion helpers below. Deferred immediate
 * assertions use the same global assertion-control state. */
static PExpr* sva_enabled_expr_(const struct vlltype&loc, long inst = -1);

/* Give every source assertion a stable identity. For `assert final', repeated
 * executions by one logical process in one time slot update the same pending
 * report; the two action arms therefore deliberately carry the same id. */
static unsigned deferred_assertion_source_id_ = 0;

/* Build the internal report marker consumed by the VVP target. The source
 * process chooses an arm now, so the runtime only has to queue the already
 * selected call. The first arguments are mode (0 = #0, 1 = final), source id,
 * and action kind (0 = null, 1 = `$error', 2 = `$display'). Both modes may
 * carry the original positional action arguments after that header; the VVP
 * target evaluates those expressions before queueing the report and snapshots
 * their typed stack values. */
static Statement* deferred_enqueue_marker_(const struct vlltype&loc,
					    bool is_final,
					    unsigned source_id,
					    unsigned kind,
					    const std::vector<named_pexpr_t>*action_args = 0)
{
      std::list<named_pexpr_t> args;

      named_pexpr_t mode_arg;
      mode_arg.parm = new PENumber(
	    new verinum((uint64_t)(is_final ? 1 : 0), 32));
      FILE_NAME(mode_arg.parm, loc);
      args.push_back(mode_arg);

      named_pexpr_t source_arg;
      source_arg.parm = new PENumber(
	    new verinum((uint64_t)source_id, 32));
      FILE_NAME(source_arg.parm, loc);
      args.push_back(source_arg);

      named_pexpr_t kind_arg;
      kind_arg.parm = new PENumber(new verinum((uint64_t)kind, 32));
      FILE_NAME(kind_arg.parm, loc);
      args.push_back(kind_arg);

      if (action_args) {
	    for (const named_pexpr_t&arg : *action_args)
		  args.push_back(arg);
      }

      PCallTask*marker = new PCallTask(
	    lex_strings.make(is_final ? "$ivl_deferred_final_enqueue"
				       : "$ivl_deferred_enqueue"), args);
      FILE_NAME(marker, loc);
      return marker;
}

/* Preserve a resolved zero-actual user-task call between two target-only
 * markers. Unlike the VPI actions above, the original PCallTask must survive
 * elaboration so normal package/hierarchy/task binding decides the callee.
 * The target validates that resolved body before emitting the Postponed
 * thunk; the matching id on both markers makes malformed recovery trees fail
 * loudly instead of silently executing or dropping the source call. */
static Statement* deferred_final_task_action_(const struct vlltype&loc,
                                               unsigned source_id,
                                               PCallTask*call)
{
      auto make_marker = [&loc, source_id](const char*name) -> Statement* {
            std::list<named_pexpr_t> args;
            named_pexpr_t source_arg;
            source_arg.parm = new PENumber(
                  new verinum((uint64_t)source_id, 32));
            FILE_NAME(source_arg.parm, loc);
            args.push_back(source_arg);
            PCallTask*marker = new PCallTask(lex_strings.make(name), args);
            FILE_NAME(marker, loc);
            return marker;
      };

      std::vector<Statement*> statements;
      statements.push_back(make_marker("$ivl_deferred_final_task_begin"));
      statements.push_back(call);
      statements.push_back(make_marker("$ivl_deferred_final_task_end"));

      PBlock*block = new PBlock(PBlock::BL_SEQ);
      block->set_statement(statements);
      FILE_NAME(block, loc);
      return block;
}

/* Convert one action arm to an enqueue marker. Positional `$error' and
 * `$display' arguments are evaluated by the source process and copied into
 * the selected report before either deferred queue is touched. Other
 * subroutine calls remain a loud implementation boundary. A non-call action
 * is illegal under IEEE 1800-2017 16.4. */
static bool deferred_action_marker_(const struct vlltype&loc,
				    Statement*source,
				    bool default_error,
				    bool is_final,
				    unsigned source_id,
				    const char*arm,
				    Statement*&marker)
{
      marker = 0;
      if (source == 0) {
	    if (default_error)
		  marker = deferred_enqueue_marker_(loc, is_final,
						   source_id, 1);
	    else if (is_final)
		  marker = deferred_enqueue_marker_(loc, true, source_id, 0);
	    return true;
      }

      if (dynamic_cast<PNoop*>(source)) {
	    delete source;
	    if (is_final)
		  marker = deferred_enqueue_marker_(loc, true, source_id, 0);
	    return true;
      }

      PCallTask*call = dynamic_cast<PCallTask*>(source);
      if (call == 0) {
	    VLerror(loc, "error: The %s action of a deferred immediate "
		    "assertion must be a single subroutine call or a null "
		    "statement (IEEE 1800-2017 16.4).", arm);
	    delete source;
	    return false;
      }

      if (call->is_void_cast()) {
	    VLerror(loc, "error: The %s action of a deferred immediate "
		    "assertion must be a direct subroutine call; a void cast "
		    "is not an action call (IEEE 1800-2017 16.4).", arm);
	    delete source;
	    return false;
      }

      const pform_name_t&path = call->path();
      const std::vector<named_pexpr_t>&parms = call->parms();
      bool simple_name = path.size() == 1
	    && path.front().index.empty()
	    && call->leading_type_args() == 0
	    && call->with_constraints().empty();
      perm_string name = simple_name ? peek_head_name(path) : perm_string();
      perm_string tail_name = path.empty() ? perm_string()
                                           : peek_tail_name(path);

      if (simple_name && name == perm_string::literal("$error")) {
	    bool positional = true;
	    for (const named_pexpr_t&parm : parms)
		  positional = positional && parm.name.nil();
	    if (positional) {
		  marker = deferred_enqueue_marker_(
			loc, is_final, source_id, 1,
			&parms);
		  delete source;
		  return true;
	    }
      }

      if (simple_name && name == perm_string::literal("$display")) {
	    bool positional = true;
	    for (const named_pexpr_t&parm : parms)
		  positional = positional && parm.name.nil();
	    if (positional) {
		  marker = deferred_enqueue_marker_(loc, is_final, source_id, 2,
					  &parms);
		  delete source;
		  return true;
	    }
      }

      bool user_subroutine = !tail_name.nil() && tail_name[0] != '$';
      if (is_final && user_subroutine && parms.empty()
          && call->leading_type_args() == 0
          && call->with_constraints().empty()) {
            marker = deferred_final_task_action_(loc, source_id, call);
            return true;
      }

      if (is_final && user_subroutine) {
            if (gn_unsupported_assertions_flag)
                  VLerror(loc, "sorry: The %s action of a final-deferred "
                        "immediate assertion calls a user subroutine outside "
                        "the supported zero-actual direct-task slice; task "
                        "actuals and parameterized/constrained call forms are "
                        "not supported yet, so the assertion is dropped.",
                        arm);
            delete source;
            return false;
      }

      if (gn_unsupported_assertions_flag)
	    VLerror(loc, "sorry: The %s action of a deferred immediate "
		  "assertion is not supported yet. Final-deferred actions currently "
		  "accept null, positional $error/$display calls, and a resolved "
		  "zero-actual passive user task; #0 actions accept null or "
		  "positional $error/$display calls; the assertion is dropped.", arm);
      delete source;
      return false;
}

Statement* pform_make_deferred_assertion(const struct vlltype&loc,
					 PExpr*expr,
					 Statement*pass_stmt,
					 Statement*fail_stmt,
					 bool is_final)
{
      unsigned source_id = ++deferred_assertion_source_id_;
      if (source_id == 0)
	    source_id = ++deferred_assertion_source_id_;

      Statement*pass_marker = 0;
      if (!deferred_action_marker_(loc, pass_stmt, false, is_final,
				   source_id, "pass",
				   pass_marker)) {
	    delete expr;
	    delete fail_stmt;
	    return 0;
      }

      Statement*fail_marker = 0;
      if (!deferred_action_marker_(loc, fail_stmt, true, is_final,
				   source_id, "fail",
				   fail_marker)) {
	    delete expr;
	    delete pass_marker;
	    return 0;
      }

      PCondit*result = new PCondit(expr, pass_marker, fail_marker);
      result->immediate_assertion();
      FILE_NAME(result, loc);

      PCondit*enabled = new PCondit(sva_enabled_expr_(loc), result, 0);
      FILE_NAME(enabled, loc);
      return enabled;
}

Statement* pform_make_deferred_cover(const struct vlltype&loc,
				     PExpr*expr,
				     Statement*pass_stmt,
				     bool is_final)
{
      unsigned source_id = ++deferred_assertion_source_id_;
      if (source_id == 0)
	    source_id = ++deferred_assertion_source_id_;

      Statement*pass_marker = 0;
      if (!deferred_action_marker_(loc, pass_stmt, false, is_final,
				   source_id, "pass", pass_marker)) {
	    delete expr;
	    return 0;
      }

      /* A false final cover selection replaces an earlier true pin from the
	 same source assertion and logical process. For #0, a false evaluation
	 simply adds no report; normal process flush points handle reactivation. */
      Statement*false_marker = is_final
	    ? deferred_enqueue_marker_(loc, true, source_id, 0) : 0;

      PCondit*result = new PCondit(expr, pass_marker, false_marker);
      result->immediate_assertion();
      FILE_NAME(result, loc);

      PCondit*enabled = new PCondit(sva_enabled_expr_(loc), result, 0);
      FILE_NAME(enabled, loc);
      return enabled;
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

void pform_add_modport_clocking_port(const struct vlltype&loc,
                                     perm_string name)
{
      ivl_assert(loc, pform_cur_modport);
      pform_cur_modport->clocking_ports.insert(name);
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

/* Marks every identifier in an expression as strict. The implementation is
   shared with concurrent assertions below; randsequence code blocks use it
   so an undeclared production-condition name cannot degrade to the generic
   compile-progress warning and silently select the else branch. */
static void sva_mark_strict_(PExpr*e);
static PExpr* sva_clone_subst_(
      PExpr*e, const std::map<perm_string,PExpr*>*subst);
static parmvalue_t* sva_clone_parmvalue_(
      const parmvalue_t*source,
      const std::map<perm_string,PExpr*>*subst);

static void pform_rs_mark_conditions_strict_(Statement*stmt)
{
      if (!stmt) return;
      if (PCondit*cond = dynamic_cast<PCondit*>(stmt)) {
	    sva_mark_strict_(cond->cond_expr());
	    pform_rs_mark_conditions_strict_(cond->if_clause());
	    pform_rs_mark_conditions_strict_(cond->else_clause());
	    return;
      }
      if (PRepeat*repeat = dynamic_cast<PRepeat*>(stmt)) {
	    sva_mark_strict_(repeat->count_expr());
	    pform_rs_mark_conditions_strict_(repeat->body());
	    return;
      }
      if (PBlock*block = dynamic_cast<PBlock*>(stmt)) {
	    for (Statement*child : block->statements())
		  pform_rs_mark_conditions_strict_(child);
      }
}

/*
 * Randsequence is a grammar expansion, not a collection of ordinary loop
 * statements. In particular, IEEE 1800-2017 18.17.6 gives a production
 * `return' and a whole-randsequence `break' distinct enclosing targets. Keep
 * those domains on the generated anonymous blocks and clone every invocation
 * independently, so an acyclic production may legally be reused.
 */
struct pform_rs_expand_ctx_t {
      const struct vlltype&loc;
      std::map<perm_string,rs_production_t*>&pmap;
      std::set<perm_string> active;
      size_t nodes = 0;
      bool bad = false;

      pform_rs_expand_ctx_t(const struct vlltype&l,
			    std::map<perm_string,rs_production_t*>&m)
      : loc(l), pmap(m) { }
};

static bool pform_rs_budget_(pform_rs_expand_ctx_t&ctx)
{
      if (++ctx.nodes <= 16384) return true;
      if (!ctx.bad) {
	    cerr << ctx.loc << ": sorry: randsequence expansion exceeds the "
		 << "16384-statement safety limit." << endl;
	    error_count += 1;
      }
      ctx.bad = true;
      return false;
}

static PBlock* pform_rs_block_(const LineInfo&where,
			       const std::vector<Statement*>&stmts,
			       ivl_randsequence_block_t kind =
				 IVL_RANDSEQ_BLOCK_NONE)
{
      PBlock*blk = new PBlock(PBlock::BL_SEQ);
      blk->set_line(where);
      blk->set_statement(stmts);
      blk->randsequence_block(kind);
      return blk;
}

static PBlock* pform_rs_block_(const struct vlltype&where,
			       const std::vector<Statement*>&stmts,
			       ivl_randsequence_block_t kind =
				 IVL_RANDSEQ_BLOCK_NONE)
{
      PBlock*blk = new PBlock(PBlock::BL_SEQ);
      FILE_NAME(blk, where);
      blk->set_statement(stmts);
      blk->randsequence_block(kind);
      return blk;
}

static bool pform_rs_constant_actual_(PExpr*expr)
{
      if (!expr) return false;
      if (dynamic_cast<PENumber*>(expr) || dynamic_cast<PEFNumber*>(expr)
	  || dynamic_cast<PEString*>(expr) || dynamic_cast<PETypename*>(expr))
	    return true;
      if (PEUnary*un = dynamic_cast<PEUnary*>(expr))
	    return pform_rs_constant_actual_(un->get_expr());
      if (PEBinary*bin = dynamic_cast<PEBinary*>(expr))
	    return pform_rs_constant_actual_(bin->get_left())
		&& pform_rs_constant_actual_(bin->get_right());
      if (PETernary*ter = dynamic_cast<PETernary*>(expr))
	    return pform_rs_constant_actual_(ter->get_cond())
		&& pform_rs_constant_actual_(ter->get_true())
		&& pform_rs_constant_actual_(ter->get_false());
      if (PECastSize*cast = dynamic_cast<PECastSize*>(expr))
	    return pform_rs_constant_actual_(cast->cast_size())
		&& pform_rs_constant_actual_(cast->cast_base());
      if (PECastType*cast = dynamic_cast<PECastType*>(expr))
	    return pform_rs_constant_actual_(cast->cast_base());
      if (PECastSign*cast = dynamic_cast<PECastSign*>(expr))
	    return pform_rs_constant_actual_(cast->cast_base());
      if (PEConcat*cat = dynamic_cast<PEConcat*>(expr)) {
	    if (cat->has_repeat()
		&& !pform_rs_constant_actual_(cat->repeat_expr())) return false;
	    for (PExpr*part : cat->stream_parms())
		  if (!pform_rs_constant_actual_(part)) return false;
	    return true;
      }
      return false;
}

static void pform_rs_delete_subst_(std::map<perm_string,PExpr*>&subst)
{
      for (std::map<perm_string,PExpr*>::iterator it = subst.begin()
	 ; it != subst.end() ; ++it) delete it->second;
      subst.clear();
}

static bool pform_rs_bind_actuals_(pform_rs_expand_ctx_t&ctx,
				   const rs_production_t&prod,
				   const std::list<named_pexpr_t>*actuals,
				   const std::map<perm_string,PExpr*>*outer,
				   std::map<perm_string,PExpr*>&bound)
{
      const size_t count = prod.formals ? prod.formals->size() : 0;
      std::vector<PExpr*> values(count, nullptr);
      size_t positional = 0;
      bool named_seen = false;

      if (actuals) for (const named_pexpr_t&actual : *actuals) {
	    size_t idx = count;
	    if (actual.name.nil()) {
		  if (named_seen) {
			cerr << ctx.loc << ": error: positional randsequence actual "
			     << "follows a named actual in production `"
			     << prod.name << "'." << endl;
			error_count += 1; ctx.bad = true; break;
		  }
		  while (positional < count && values[positional]) ++positional;
		  idx = positional++;
	    } else {
		  named_seen = true;
		  for (size_t n = 0 ; n < count ; ++n)
			if ((*prod.formals)[n].name == actual.name) { idx = n; break; }
	    }
	    if (idx >= count) {
		  cerr << ctx.loc << ": error: too many or unknown randsequence "
		       << "actuals for production `" << prod.name << "'." << endl;
		  error_count += 1; ctx.bad = true; break;
	    }
	    if (values[idx]) {
		  cerr << ctx.loc << ": error: duplicate randsequence actual for `"
		       << (*prod.formals)[idx].name << "'." << endl;
		  error_count += 1; ctx.bad = true; break;
	    }
	    values[idx] = actual.parm
		? sva_clone_subst_(actual.parm, outer) : nullptr;
	    if (!values[idx] || !pform_rs_constant_actual_(values[idx])) {
		  cerr << ctx.loc << ": sorry: randsequence input actuals must be "
		       << "side-effect-free constant expressions; production `"
		       << prod.name << "' has a nonconstant actual." << endl;
		  error_count += 1; ctx.bad = true; break;
	    }
      }

      for (size_t idx = 0 ; !ctx.bad && idx < count ; ++idx) {
	    const rs_formal_t&formal = (*prod.formals)[idx];
	    if (formal.direction != NetNet::PINPUT) {
		  cerr << formal.get_fileline() << ": sorry: randsequence output, "
		       << "inout, and ref production formals are not supported yet."
		       << endl;
		  error_count += 1; ctx.bad = true; break;
	    }
	    if (!values[idx] && formal.default_expr)
		  values[idx] = sva_clone_subst_(formal.default_expr, &bound);
	    if (!values[idx] || !pform_rs_constant_actual_(values[idx])) {
		  cerr << ctx.loc << ": error: randsequence production `"
		       << prod.name << "' has no constant actual for formal `"
		       << formal.name << "'." << endl;
		  error_count += 1; ctx.bad = true; break;
	    }
	    bound[formal.name] = values[idx];
	    values[idx] = nullptr;
      }
      for (PExpr*value : values) delete value;
      if (ctx.bad) pform_rs_delete_subst_(bound);
      return !ctx.bad;
}

static Statement* pform_rs_clone_stmt_(pform_rs_expand_ctx_t&ctx,
				       Statement*stmt,
				       const std::map<perm_string,PExpr*>*subst,
				       unsigned loop_depth)
{
      if (!stmt || !pform_rs_budget_(ctx)) return nullptr;

      if (PBlock*block = dynamic_cast<PBlock*>(stmt)) {
	    if (block->bl_type() != PBlock::BL_SEQ
		|| !block->pscope_name().nil()) {
		  cerr << stmt->get_fileline() << ": sorry: randsequence code "
		       << "blocks currently require anonymous sequential blocks."
		       << endl;
		  error_count += 1; ctx.bad = true; return nullptr;
	    }
	    std::vector<Statement*> children;
	    for (Statement*child : block->statements()) {
		  Statement*copy = pform_rs_clone_stmt_(ctx, child, subst,
						 loop_depth);
		  if (copy) children.push_back(copy);
	    }
	    return pform_rs_block_(*stmt, children,
				   block->randsequence_block());
      }
      if (PAssign*assign = dynamic_cast<PAssign*>(stmt)) {
	    if (assign->has_timing_control()) goto unsupported;
	    PExpr*lhs = sva_clone_subst_(const_cast<PExpr*>(assign->lval()), subst);
	    PExpr*rhs = sva_clone_subst_(assign->rval(), subst);
	    if (!lhs || !rhs) { delete lhs; delete rhs; goto unsupported; }
	    PAssign*copy = assign->op()
		? new PAssign(lhs, assign->op(), rhs) : new PAssign(lhs, rhs);
	    copy->set_line(*stmt);
	    return copy;
      }
      if (PAssignNB*assign = dynamic_cast<PAssignNB*>(stmt)) {
	    if (assign->has_timing_control()) goto unsupported;
	    PExpr*lhs = sva_clone_subst_(const_cast<PExpr*>(assign->lval()), subst);
	    PExpr*rhs = sva_clone_subst_(assign->rval(), subst);
	    if (!lhs || !rhs) { delete lhs; delete rhs; goto unsupported; }
	    PAssignNB*copy = new PAssignNB(lhs, rhs);
	    copy->set_line(*stmt);
	    return copy;
      }
      if (PCondit*cond = dynamic_cast<PCondit*>(stmt)) {
	    PExpr*expr = sva_clone_subst_(cond->cond_expr(), subst);
	    Statement*yes = pform_rs_clone_stmt_(ctx, cond->if_clause(), subst,
						 loop_depth);
	    Statement*no = cond->else_clause()
		? pform_rs_clone_stmt_(ctx, cond->else_clause(), subst, loop_depth)
		: nullptr;
	    if (!expr) { delete yes; delete no; goto unsupported; }
	    sva_mark_strict_(expr);
	    PCondit*copy = new PCondit(expr, yes, no);
	    copy->parsed_if_statement(cond->is_parsed_if_statement());
	    copy->immediate_assertion(cond->is_immediate_assertion());
	    copy->set_line(*stmt);
	    return copy;
      }
      if (PRepeat*repeat = dynamic_cast<PRepeat*>(stmt)) {
	    PExpr*count = sva_clone_subst_(repeat->count_expr(), subst);
	    Statement*body = pform_rs_clone_stmt_(ctx, repeat->body(), subst,
						   loop_depth + 1);
	    if (!count || !body) { delete count; delete body; goto unsupported; }
	    sva_mark_strict_(count);
	    PRepeat*copy = new PRepeat(count, body);
	    copy->set_line(*stmt);
	    return copy;
      }
      if (PCallTask*call = dynamic_cast<PCallTask*>(stmt)) {
	    std::list<named_pexpr_t> parms;
	    for (const named_pexpr_t&src : call->parms()) {
		  named_pexpr_t dst;
		  dst.name = src.name;
		  dst.parm = src.parm ? sva_clone_subst_(src.parm, subst) : nullptr;
		  if (src.parm && !dst.parm) goto unsupported;
		  parms.push_back(dst);
	    }
	    PCallTask*copy;
	    if (call->receiver_expr()) {
		  if (call->path().size() != 1) goto unsupported;
		  PExpr*receiver = sva_clone_subst_(call->receiver_expr(), subst);
		  if (!receiver) goto unsupported;
		  copy = new PCallTask(receiver, call->path().front().name, parms);
	    } else if (call->package()) {
		  copy = new PCallTask(call->package(), call->path(), parms);
	    } else {
		  copy = new PCallTask(call->path(), parms);
	    }
	    if (call->leading_type_args()) {
		  parmvalue_t*args = sva_clone_parmvalue_(call->leading_type_args(),
						      subst);
		  if (!args) { delete copy; goto unsupported; }
		  copy->set_leading_type_args(args);
	    }
	    std::vector<PExpr*> with;
	    for (PExpr*src : call->with_constraints()) {
		  PExpr*dst = sva_clone_subst_(src, subst);
		  if (!dst) { delete copy; goto unsupported; }
		  with.push_back(dst);
	    }
	    copy->set_with_constraints(std::move(with));
	    if (call->has_randomize_with_identifier_list())
		  copy->set_randomize_with_identifiers(
			call->randomize_with_identifiers());
	    if (call->is_void_cast()) copy->void_cast();
	    copy->set_line(*stmt);
	    return copy;
      }
      if (PBreak*jump = dynamic_cast<PBreak*>(stmt)) {
	    ivl_flow_control_t kind = loop_depth
		? IVL_FLOW_LOOP_BREAK : IVL_FLOW_RANDSEQ_BREAK;
	    if (jump->flow_control() != IVL_FLOW_LOOP_BREAK)
		  kind = jump->flow_control();
	    PBreak*copy = new PBreak(kind);
	    copy->set_line(*stmt);
	    return copy;
      }
      if (PContinue*cont = dynamic_cast<PContinue*>(stmt)) {
	    if (!loop_depth) {
		  cerr << cont->get_fileline() << ": error: continue is not inside "
		       << "a procedural loop in this randsequence production."
		       << endl;
		  error_count += 1; ctx.bad = true; return nullptr;
	    }
	    PContinue*copy = new PContinue;
	    copy->set_line(*stmt);
	    return copy;
      }
      if (PReturn*ret = dynamic_cast<PReturn*>(stmt)) {
	    if (ret->expr()) {
		  cerr << ret->get_fileline() << ": sorry: value-returning "
		       << "randsequence productions are not supported yet." << endl;
		  error_count += 1; ctx.bad = true; return nullptr;
	    }
	    PBreak*copy = new PBreak(IVL_FLOW_RANDSEQ_RETURN);
	    copy->set_line(*stmt);
	    return copy;
      }
      if (dynamic_cast<PNoop*>(stmt)) {
	    PNoop*copy = new PNoop;
	    copy->set_line(*stmt);
	    return copy;
      }

unsupported:
      cerr << stmt->get_fileline() << ": sorry: this statement shape is not "
	   << "supported in a reusable randsequence code block yet." << endl;
      error_count += 1; ctx.bad = true;
      return nullptr;
}

static Statement* pform_rs_expand_production_(
      pform_rs_expand_ctx_t&ctx, perm_string name,
      const std::list<named_pexpr_t>*actuals,
      const std::map<perm_string,PExpr*>*outer);

static Statement* pform_rs_expand_item_(
      pform_rs_expand_ctx_t&ctx, const rs_item_t&item,
      const std::map<perm_string,PExpr*>*subst);

struct pform_rs_join_lane_t {
      const rs_production_t*production = nullptr;
      const rs_rule_t*rule = nullptr;
      std::map<perm_string,PExpr*> subst;
};

struct pform_rs_join_schedule_t {
      std::vector<size_t> lanes;
      double probability = 0.0;
};

static void pform_rs_join_schedules_(
      pform_rs_expand_ctx_t&ctx,
      const std::vector<pform_rs_join_lane_t>&lanes,
      std::vector<size_t>&positions, long previous,
      double stay_probability, double probability,
      std::vector<size_t>&order,
      std::vector<pform_rs_join_schedule_t>&out)
{
      size_t eligible = 0;
      for (size_t lane = 0 ; lane < lanes.size() ; ++lane)
	    if (positions[lane] < lanes[lane].rule->items->size()) ++eligible;
      if (!eligible) {
	    if (out.size() >= 256) {
		  if (!ctx.bad) {
			cerr << ctx.loc << ": sorry: randsequence rand join expands "
			     << "to more than 256 legal interleavings." << endl;
			error_count += 1;
		  }
		  ctx.bad = true;
		  return;
	    }
	    pform_rs_join_schedule_t schedule;
	    schedule.lanes = order;
	    schedule.probability = probability;
	    out.push_back(schedule);
	    return;
      }

      bool previous_active = previous >= 0
	    && positions[previous] < lanes[previous].rule->items->size();
      for (size_t lane = 0 ; lane < lanes.size() && !ctx.bad ; ++lane) {
	    if (positions[lane] >= lanes[lane].rule->items->size()) continue;
	    double choose = 1.0 / eligible;
	    if (previous_active) {
		  choose = (1.0 - stay_probability) / eligible;
		  if ((long)lane == previous) choose += stay_probability;
	    }
	    ++positions[lane];
	    order.push_back(lane);
	    pform_rs_join_schedules_(ctx, lanes, positions, lane,
				      stay_probability,
				      probability * choose, order, out);
	    order.pop_back();
	    --positions[lane];
      }
}

static bool pform_rs_join_probability_(pform_rs_expand_ctx_t&ctx,
				       PExpr*expr,
				       const std::map<perm_string,PExpr*>*subst,
				       double&value)
{
      if (!expr) { value = 0.5; return true; }
      PExpr*copy = sva_clone_subst_(expr, subst);
      if (PENumber*integer = dynamic_cast<PENumber*>(copy))
	    value = integer->value().as_double();
      else if (PEFNumber*real = dynamic_cast<PEFNumber*>(copy))
	    value = real->value().as_double();
      else {
	    cerr << ctx.loc << ": sorry: randsequence rand join probability "
		 << "must currently be a numeric constant." << endl;
	    error_count += 1; ctx.bad = true; delete copy; return false;
      }
      delete copy;
      if (!std::isfinite(value) || value < 0.0 || value > 1.0) {
	    cerr << ctx.loc << ": error: randsequence rand join probability "
		 << "must be between 0.0 and 1.0." << endl;
	    error_count += 1; ctx.bad = true; return false;
      }
      return true;
}

static Statement* pform_rs_expand_join_(
      pform_rs_expand_ctx_t&ctx, const rs_item_t&item,
      const std::map<perm_string,PExpr*>*outer)
{
      double stay_probability;
      if (!pform_rs_join_probability_(ctx, item.expr, outer,
				      stay_probability)) return nullptr;

      std::vector<pform_rs_join_lane_t> lanes;
      if (!item.join_items || item.join_items->size() < 2) {
	    cerr << ctx.loc << ": error: randsequence rand join requires at "
		 << "least two productions." << endl;
	    error_count += 1; ctx.bad = true; return nullptr;
      }
      for (const rs_item_t&call : *item.join_items) {
	    std::map<perm_string,rs_production_t*>::iterator found =
		  ctx.pmap.find(call.name);
	    if (found == ctx.pmap.end()) {
		  cerr << ctx.loc << ": error: randsequence production `"
		       << call.name << "' is not defined." << endl;
		  error_count += 1; ctx.bad = true; break;
	    }
	    const rs_production_t*prod = found->second;
	    if (ctx.active.count(prod->name)) {
		  cerr << ctx.loc << ": sorry: recursive randsequence production `"
		       << prod->name << "' is not supported." << endl;
		  error_count += 1; ctx.bad = true; break;
	    }
	    if (prod->return_type || !prod->rules || prod->rules->size() != 1
		|| (*prod->rules)[0].weight) {
		  cerr << ctx.loc << ": sorry: randsequence rand join currently "
		       << "requires each joined production to have one unweighted "
		       << "void rule." << endl;
		  error_count += 1; ctx.bad = true; break;
	    }
	    const rs_rule_t&rule = (*prod->rules)[0];
	    bool code_only = rule.items;
	    if (rule.items) for (const rs_item_t&part : *rule.items)
		  if (part.kind != rs_item_t::CODE) code_only = false;
	    if (!code_only) {
		  cerr << ctx.loc << ": sorry: randsequence rand join currently "
		       << "interleaves code-block items; nested production/control "
		       << "items are not supported in joined lanes yet." << endl;
		  error_count += 1; ctx.bad = true; break;
	    }
	    pform_rs_join_lane_t lane;
	    lane.production = prod;
	    lane.rule = &rule;
	    if (!pform_rs_bind_actuals_(ctx, *prod, call.actuals, outer,
					  lane.subst)) break;
	    lanes.push_back(lane);
      }
      if (ctx.bad) {
	    for (pform_rs_join_lane_t&lane : lanes)
		  pform_rs_delete_subst_(lane.subst);
	    return nullptr;
      }

      std::vector<size_t> positions(lanes.size(), 0), order;
      std::vector<pform_rs_join_schedule_t> schedules;
      pform_rs_join_schedules_(ctx, lanes, positions, -1,
				      stay_probability, 1.0, order, schedules);
      if (ctx.bad) {
	    for (pform_rs_join_lane_t&lane : lanes)
		  pform_rs_delete_subst_(lane.subst);
	    return nullptr;
      }

      std::vector<PCase::Item*>*branches = new std::vector<PCase::Item*>;
      for (const pform_rs_join_schedule_t&schedule : schedules) {
	    std::vector<size_t> used(lanes.size(), 0);
	    std::vector<Statement*> statements;
	    for (size_t lane_index : schedule.lanes) {
		  const pform_rs_join_lane_t&lane = lanes[lane_index];
		  const rs_item_t&part = (*lane.rule->items)[used[lane_index]++];
		  Statement*copy = pform_rs_clone_stmt_(ctx, part.code,
						   &lane.subst, 0);
		  if (copy) statements.push_back(copy);
	    }
	    PCase::Item*branch = new PCase::Item;
	    uint64_t weight = (uint64_t)llround(schedule.probability
						 * (double)(1ULL << 30));
	    if (!weight && schedule.probability > 0.0) weight = 1;
	    branch->expr.push_back(new PENumber(new verinum(weight, 64)));
	    branch->stat = pform_rs_block_(item, statements);
	    branches->push_back(branch);
      }
      for (pform_rs_join_lane_t&lane : lanes)
	    pform_rs_delete_subst_(lane.subst);

      if (branches->size() == 1) {
	    Statement*only = (*branches)[0]->stat;
	    (*branches)[0]->stat = nullptr;
	    delete (*branches)[0];
	    delete branches;
	    return only;
      }
      PRandCase*choice = new PRandCase(branches);
      choice->set_line(item);
      return choice;
}

static Statement* pform_rs_expand_item_(
      pform_rs_expand_ctx_t&ctx, const rs_item_t&item,
      const std::map<perm_string,PExpr*>*subst)
{
      switch (item.kind) {
      case rs_item_t::CALL:
	    return pform_rs_expand_production_(ctx, item.name, item.actuals, subst);
      case rs_item_t::CODE: {
	    Statement*copy = pform_rs_clone_stmt_(ctx, item.code, subst, 0);
	    pform_rs_mark_conditions_strict_(copy);
	    return copy;
      }
      case rs_item_t::IF_ELSE: {
	    PExpr*condition = sva_clone_subst_(item.expr, subst);
	    Statement*yes = item.first
		? pform_rs_expand_item_(ctx, *item.first, subst) : nullptr;
	    Statement*no = item.second
		? pform_rs_expand_item_(ctx, *item.second, subst) : nullptr;
	    if (!condition) {
		  cerr << item.get_fileline() << ": sorry: cannot clone this "
		       << "randsequence if condition." << endl;
		  error_count += 1; ctx.bad = true; delete yes; delete no;
		  return nullptr;
	    }
	    sva_mark_strict_(condition);
	    PCondit*result = new PCondit(condition, yes, no);
	    result->parsed_if_statement();
	    result->set_line(item);
	    return result;
      }
      case rs_item_t::REPEAT: {
	    PExpr*count = sva_clone_subst_(item.expr, subst);
	    Statement*body = item.first
		? pform_rs_expand_item_(ctx, *item.first, subst) : nullptr;
	    if (!count || !body) {
		  cerr << item.get_fileline() << ": sorry: cannot lower this "
		       << "randsequence repeat production." << endl;
		  error_count += 1; ctx.bad = true; delete count; delete body;
		  return nullptr;
	    }
	    sva_mark_strict_(count);
	    PRepeat*result = new PRepeat(count, body);
	    result->set_line(item);
	    return result;
      }
      case rs_item_t::CASE: {
	    PExpr*selector = sva_clone_subst_(item.expr, subst);
	    std::vector<PCase::Item*>*items = new std::vector<PCase::Item*>;
	    if (!selector) {
		  cerr << item.get_fileline() << ": sorry: cannot clone this "
		       << "randsequence case selector." << endl;
		  error_count += 1; ctx.bad = true;
	    } else sva_mark_strict_(selector);
	    if (item.cases) for (const rs_case_item_t&source : *item.cases) {
		  PCase::Item*target = new PCase::Item;
		  if (source.expressions)
			for (PExpr*expr : *source.expressions) {
			      PExpr*copy = sva_clone_subst_(expr, subst);
			      if (!copy) ctx.bad = true;
			      else target->expr.push_back(copy);
			}
		  target->stat = source.item
			? pform_rs_expand_item_(ctx, *source.item, subst) : nullptr;
		  items->push_back(target);
	    }
	    PCase*result = new PCase(IVL_CASE_QUALITY_BASIC, NetCase::EQ,
				      selector, items);
	    result->set_line(item);
	    return result;
      }
      case rs_item_t::RAND_JOIN:
	    return pform_rs_expand_join_(ctx, item, subst);
      }
      return nullptr;
}

static Statement* pform_rs_expand_rule_(
      pform_rs_expand_ctx_t&ctx, const rs_rule_t&rule,
      const std::map<perm_string,PExpr*>*subst,
      const struct vlltype&where)
{
      std::vector<Statement*> statements;
      if (rule.items) for (const rs_item_t&item : *rule.items) {
	    Statement*expanded = pform_rs_expand_item_(ctx, item, subst);
	    if (expanded) statements.push_back(expanded);
      }
      return pform_rs_block_(where, statements);
}

static Statement* pform_rs_expand_production_(
      pform_rs_expand_ctx_t&ctx, perm_string name,
      const std::list<named_pexpr_t>*actuals,
      const std::map<perm_string,PExpr*>*outer)
{
      std::map<perm_string,rs_production_t*>::iterator found =
	    ctx.pmap.find(name);
      if (found == ctx.pmap.end()) {
	    cerr << ctx.loc << ": error: randsequence production `" << name
		 << "' is not defined." << endl;
	    error_count += 1; ctx.bad = true; return nullptr;
      }
      rs_production_t&prod = *found->second;
      if (ctx.active.count(name)) {
	    cerr << ctx.loc << ": sorry: recursive randsequence production `"
		 << name << "' is not supported." << endl;
	    error_count += 1; ctx.bad = true; return nullptr;
      }
      if (prod.return_type) {
	    cerr << ctx.loc << ": sorry: value-returning randsequence production `"
		 << name << "' is not supported yet." << endl;
	    error_count += 1; ctx.bad = true; return nullptr;
      }

      std::map<perm_string,PExpr*> subst;
      if (!pform_rs_bind_actuals_(ctx, prod, actuals, outer, subst))
	    return nullptr;
      ctx.active.insert(name);

      Statement*body = nullptr;
      if (!prod.rules || prod.rules->empty()) {
	    std::vector<Statement*> empty;
	    body = pform_rs_block_(ctx.loc, empty);
	  } else if (prod.rules->size() == 1 && !(*prod.rules)[0].weight) {
	    body = pform_rs_expand_rule_(ctx, (*prod.rules)[0], &subst, ctx.loc);
	  } else {
	    std::vector<PCase::Item*>*alternatives =
		  new std::vector<PCase::Item*>;
	    for (const rs_rule_t&rule : *prod.rules) {
		  PCase::Item*alternative = new PCase::Item;
		  PExpr*weight = rule.weight
			? sva_clone_subst_(rule.weight, &subst)
			: new PENumber(new verinum((uint64_t)1, 32));
		  if (!weight) {
			cerr << ctx.loc << ": sorry: cannot clone randsequence "
			     << "production weight." << endl;
			error_count += 1; ctx.bad = true;
		  } else alternative->expr.push_back(weight);
		  alternative->stat = pform_rs_expand_rule_(ctx, rule, &subst,
							ctx.loc);
		  alternatives->push_back(alternative);
	    }
	    PRandCase*choice = new PRandCase(alternatives);
	    FILE_NAME(choice, ctx.loc);
	    body = choice;
      }
      ctx.active.erase(name);
      pform_rs_delete_subst_(subst);

      std::vector<Statement*> one;
      if (body) one.push_back(body);
      return pform_rs_block_(ctx.loc, one, IVL_RANDSEQ_BLOCK_PRODUCTION);
}

static void pform_rs_destroy_item_(rs_item_t&item)
{
      if (item.actuals) {
	    for (named_pexpr_t&actual : *item.actuals) delete actual.parm;
	    delete item.actuals;
      }
      delete item.code;
      delete item.expr;
      if (item.first) { pform_rs_destroy_item_(*item.first); delete item.first; }
      if (item.second) {
	    pform_rs_destroy_item_(*item.second); delete item.second;
      }
      if (item.cases) {
	    for (rs_case_item_t&case_item : *item.cases) {
		  if (case_item.expressions) {
			for (PExpr*expr : *case_item.expressions) delete expr;
			delete case_item.expressions;
		  }
		  if (case_item.item) {
			pform_rs_destroy_item_(*case_item.item);
			delete case_item.item;
		  }
	    }
	    delete item.cases;
      }
      if (item.join_items) {
	    for (rs_item_t&join_item : *item.join_items)
		  pform_rs_destroy_item_(join_item);
	    delete item.join_items;
      }
}

static void pform_rs_destroy_(std::vector<rs_production_t>*productions)
{
      if (!productions) return;
      for (rs_production_t&prod : *productions) {
	    if (prod.formals) {
		  for (rs_formal_t&formal : *prod.formals)
			delete formal.default_expr;
		  delete prod.formals;
	    }
	    if (prod.rules) {
		  for (rs_rule_t&rule : *prod.rules) {
			delete rule.weight;
			if (rule.items) {
			      for (rs_item_t&item : *rule.items)
				    pform_rs_destroy_item_(item);
			      delete rule.items;
			}
		  }
		  delete prod.rules;
	    }
      }
      delete productions;
}

Statement* pform_make_randsequence(const struct vlltype&loc, perm_string start,
				   std::vector<rs_production_t>*prods)
{
      std::vector<Statement*> root_statements;
      if (!prods || prods->empty()) {
	    pform_rs_destroy_(prods);
	    return pform_rs_block_(loc, root_statements, IVL_RANDSEQ_BLOCK_ROOT);
      }

      std::map<perm_string,rs_production_t*> pmap;
      bool duplicate = false;
      for (rs_production_t&prod : *prods) {
	    if (pmap.count(prod.name)) {
		  cerr << loc << ": error: duplicate randsequence production `"
		       << prod.name << "'." << endl;
		  error_count += 1; duplicate = true;
	    } else pmap[prod.name] = &prod;
      }

      perm_string start_name = start.nil() ? prods->front().name : start;
      pform_rs_expand_ctx_t ctx(loc, pmap);
      ctx.bad = duplicate;
      if (!ctx.bad) {
	    Statement*body = pform_rs_expand_production_(ctx, start_name,
						    nullptr, nullptr);
	    if (body) root_statements.push_back(body);
      }
      pform_rs_destroy_(prods);
      return pform_rs_block_(loc, root_statements, IVL_RANDSEQ_BLOCK_ROOT);
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

/* Named sequences and properties are scoped to the GENERATE BLOCK that
   declares them, not to the module (IEEE 1800-2017 27.3/27.6: a
   generate block is a hierarchical scope; 27.5: a conditional generate
   instantiates at most ONE of its alternatives).
 
   Keying these maps by name alone made
 
       if (ASYNC) begin : ga  sequence S1; ... endsequence  ... end
       else       begin : gb  sequence S1; ... endsequence  ... end
 
   a `duplicate sequence declaration' even though the two arms are
   disjoint scopes and only one is ever elaborated -- which is exactly
   what OpenTitan's prim_alert_sender writes for PingSigInt_S and
   AckSigInt_S.
 
   The scope half matters as much as the duplicate half: with lookup
   still keyed by name, the eight assertions in `gen_sync_assert' would
   splice `gen_async_assert''s body. That is a silent wrong result, so
   the key and the resolver change together. */
struct sva_scoped_name_t {
      perm_string name;
      const PGenerate*gen;   // nullptr == module scope

      bool operator< (const sva_scoped_name_t&that) const
      {
	    if (name != that.name) return name < that.name;
	    return gen < that.gen;
      }
};

static std::map<sva_scoped_name_t, sva_property_t*> sva_module_properties;
static std::map<sva_scoped_name_t, std::vector<sva_seq_step_t>*> sva_module_sequences;
/* Complete (clocked, multiclocked, or combinator) sequence declarations use
   the property-shaped map so assertion instantiation can retain their full
   IR.  This tag distinguishes them from actual property declarations when a
   sequence is embedded in another sequence operator. */
static std::set<sva_scoped_name_t> sva_property_shaped_sequences;
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
static std::map<sva_scoped_name_t, sva_param_seq_t> sva_param_sequences;
static std::map<sva_scoped_name_t, sva_param_prop_t> sva_param_properties;

/* Sampled calls in a DECLARATION acquire their clock only when the named
   property/sequence is instantiated. They must not remain in the generic
   procedural pending list, whose endmodule flush would diagnose them as
   unclocked and synthesize the wrong standalone fallback. */
static void sva_expr_forget_sampled_(PExpr*e);

static void sva_match_call_forget_sampled_(const PCallTask*call)
{
      if (!call) return;
      const std::vector<named_pexpr_t>&parms = call->parms();
      for (size_t i = 0 ; i < parms.size() ; i += 1)
	    sva_expr_forget_sampled_(parms[i].parm);
}

/* PCallTask deliberately does not own its argument expressions. Sequence
   match items do: until a supported call is cloned into a synthesized action,
   its arguments live solely in the step IR and must be released explicitly. */
static void sva_destroy_match_call_(PCallTask*call)
{
      if (!call) return;
      sva_match_call_forget_sampled_(call);
      const std::vector<named_pexpr_t>&parms = call->parms();
      for (size_t i = 0 ; i < parms.size() ; i += 1)
	    delete parms[i].parm;
      delete call;
}

static void sva_destroy_match_calls_(std::vector<PCallTask*>&calls)
{
      for (size_t i = 0 ; i < calls.size() ; i += 1)
	    sva_destroy_match_call_(calls[i]);
      calls.clear();
}

static void sva_decl_sequence_forget_sampled_(
				const std::vector<sva_seq_step_t>*seq)
{
      if (!seq) return;
      for (size_t i = 0 ; i < seq->size() ; i += 1) {
	    sva_expr_forget_sampled_((*seq)[i].expr);
	    sva_expr_forget_sampled_((*seq)[i].lv_rhs);
	    sva_expr_forget_sampled_((*seq)[i].delay_lo_expr);
	    sva_expr_forget_sampled_((*seq)[i].delay_hi_expr);
	    sva_expr_forget_sampled_((*seq)[i].rep_lo_expr);
	    sva_expr_forget_sampled_((*seq)[i].rep_hi_expr);
	    for (size_t c = 0 ; c < (*seq)[i].match_calls.size() ; c += 1)
		  sva_match_call_forget_sampled_((*seq)[i].match_calls[c]);
      }
}

static void sva_decl_tree_forget_sampled_(const sva_stree_t*t)
{
      if (!t) return;
      sva_decl_sequence_forget_sampled_(t->chain);
      sva_expr_forget_sampled_(t->gexpr);
      sva_decl_tree_forget_sampled_(t->a);
      sva_decl_tree_forget_sampled_(t->b);
}

static void sva_decl_property_forget_sampled_(const sva_property_t*p)
{
      if (!p) return;
      sva_expr_forget_sampled_(p->disable_iff_expr);
      sva_expr_forget_sampled_(p->abort_cond);
      sva_decl_sequence_forget_sampled_(p->antecedent);
      sva_decl_sequence_forget_sampled_(p->mc_prefix);
      sva_decl_sequence_forget_sampled_(p->seq);
      sva_decl_tree_forget_sampled_(p->ante_tree);
      sva_decl_tree_forget_sampled_(p->tree);
      if (p->mc_more)
	    for (size_t i = 0 ; i < p->mc_more->size() ; i += 1)
		  sva_decl_sequence_forget_sampled_((*p->mc_more)[i].chain);
}

/* The key a declaration made HERE gets: the innermost enclosing
   generate block, or nullptr at module scope. */
static sva_scoped_name_t sva_decl_key_(perm_string nm)
{
      sva_scoped_name_t k;
      k.name = nm;
      k.gen  = pform_cur_generate;
      return k;
}

/* Resolve a reference from the CURRENT scope outward: the innermost
   enclosing generate first, then each enclosing generate, then module
   scope. An inner declaration shadows an outer one of the same name
   (23.9), and a name declared in a sibling generate arm is correctly
   NOT visible.
 
   Returns m.end() when the name is not in scope. There is deliberately
   no unambiguous-name fallback: with one, a reference in arm `gb' that
   lexically precedes gb's own declaration would miss (S1,&gb), miss
   module scope, and then splice arm `ga''s body -- turning today's
   loud duplicate error into a silent wrong result. */
template <class MAP>
static typename MAP::iterator sva_resolve_(MAP&m, perm_string nm)
{
      for (const PGenerate*g = pform_cur_generate ; ; ) {
	    sva_scoped_name_t k;
	    k.name = nm;
	    k.gen  = g;
	    typename MAP::iterator it = m.find(k);
	    if (it != m.end()) return it;
	    if (!g) break;
	    const LexicalScope*up = g->parent_scope();
	    g = dynamic_cast<const PGenerate*>(up);
      }
      return m.end();
}

template <class MAP>
static bool sva_in_scope_(MAP&m, perm_string nm)
{
      return sva_resolve_(m, nm) != m.end();
}

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

static bool pform_sva_const_long_(PExpr*expr, long&value,
				  std::set<const PExpr*>&visiting,
				  LexicalScope*lookup_scope);

/* A repetition bound that reaches an overridable module parameter cannot be
   structurally expanded while the module is parsed: the value in the parse
   scope is only the declaration default.  Follow localparam aliases as well,
   so `localparam N = P+1; b[*N]' remains instance-correct when P is
   overridden.  This is deliberately a dependency query, not a numeric
   evaluator; ordinary elaboration remains the authority for the value. */
static bool pform_sva_overridable_bound_(
		PExpr*expr, LexicalScope*lookup_scope,
		std::set<const LexicalScope::param_expr_t*>&visiting)
{
      if (!expr) return false;
      if (PEIdent*id = dynamic_cast<PEIdent*>(expr)) {
	    if (id->path().name.empty())
		  return false;
	    for (pform_name_t::const_iterator component =
		       id->path().name.begin()
	 ; component != id->path().name.end() ; ++component)
		  if (!component->index.empty()) return false;
	    perm_string name = id->path().name.front().name;
	    LexicalScope::param_expr_t*parm = nullptr;
	    LexicalScope*parm_scope = nullptr;
	    if (id->path().package) {
		  PPackage*pkg = id->path().package;
		  std::map<perm_string,LexicalScope::param_expr_t*>::iterator it =
			pkg->parameters.find(name);
		  if (it != pkg->parameters.end()) {
			parm = it->second;
			parm_scope = pkg;
		  }
	    } else {
		  for (LexicalScope*scope = lookup_scope ; scope && !parm
		       ; scope = scope->parent_scope()) {
			std::map<perm_string,LexicalScope::param_expr_t*>::iterator it =
			      scope->parameters.find(name);
			if (it != scope->parameters.end()) {
			      parm = it->second;
			      parm_scope = scope;
			      break;
			}
			std::map<perm_string,PPackage*>::iterator imp =
			      scope->explicit_imports.find(name);
			if (imp != scope->explicit_imports.end()) {
			      PPackage*pkg = imp->second;
			      std::map<perm_string,LexicalScope::param_expr_t*>::iterator pit =
				    pkg->parameters.find(name);
			      if (pit != pkg->parameters.end()) {
				    parm = pit->second;
				    parm_scope = pkg;
				    break;
			      }
			}
		  }
	    }
	    if (!parm || parm->type_flag) return false;
	    if (parm->overridable) return true;
	    if (!parm->expr || visiting.count(parm)) return false;
	    visiting.insert(parm);
	    bool found = pform_sva_overridable_bound_(parm->expr, parm_scope,
						 visiting);
	    visiting.erase(parm);
	    return found;
      }
      if (PEUnary*un = dynamic_cast<PEUnary*>(expr))
	    return pform_sva_overridable_bound_(un->get_expr(), lookup_scope,
						 visiting);
      if (PEBinary*bin = dynamic_cast<PEBinary*>(expr))
	    return pform_sva_overridable_bound_(bin->get_left(), lookup_scope,
						 visiting)
		|| pform_sva_overridable_bound_(bin->get_right(), lookup_scope,
						   visiting);
      if (PETernary*ter = dynamic_cast<PETernary*>(expr))
	    return pform_sva_overridable_bound_(ter->get_cond(), lookup_scope,
						 visiting)
		|| pform_sva_overridable_bound_(ter->get_true(), lookup_scope,
						   visiting)
		|| pform_sva_overridable_bound_(ter->get_false(), lookup_scope,
						   visiting);
      if (PECastSize*cast = dynamic_cast<PECastSize*>(expr))
	    return pform_sva_overridable_bound_(cast->cast_size(), lookup_scope,
						 visiting)
		|| pform_sva_overridable_bound_(cast->cast_base(), lookup_scope,
						   visiting);
      if (PECastType*cast = dynamic_cast<PECastType*>(expr))
	    return pform_sva_overridable_bound_(cast->cast_base(), lookup_scope,
						 visiting);
      if (PECastSign*cast = dynamic_cast<PECastSign*>(expr))
	    return pform_sva_overridable_bound_(cast->cast_base(), lookup_scope,
						 visiting);
      if (PECallFunction*call = dynamic_cast<PECallFunction*>(expr)) {
	    const std::vector<named_pexpr_t>&args = call->get_parms();
	    for (size_t idx = 0 ; idx < args.size() ; idx += 1)
		  if (pform_sva_overridable_bound_(args[idx].parm, lookup_scope,
						      visiting))
			return true;
      }
	/* A localparam struct is commonly initialized with a named assignment
	   pattern and then selected in a delay bound (CFG.rise.min).  Keep an
	   override dependency hidden in any pattern member symbolic; folding
	   the declaration default would make different module instances share
	   the wrong checker depth. */
      if (PEAssignPattern*pattern = dynamic_cast<PEAssignPattern*>(expr)) {
	    if (pform_sva_overridable_bound_(pattern->replication(), lookup_scope,
						 visiting))
		  return true;
	    const std::vector<PExpr*>&members = pattern->parms();
	    for (size_t idx = 0 ; idx < members.size() ; idx += 1)
		  if (pform_sva_overridable_bound_(members[idx], lookup_scope,
						      visiting))
			return true;
      }
      return false;
}

bool pform_sva_overridable_bound(PExpr*expr)
{
      std::set<const LexicalScope::param_expr_t*> visiting;
      return pform_sva_overridable_bound_(expr, lexical_scope, visiting);
}

/* Resolve an enum literal directly from the parse form. Assertion delay and
   sampled-value bounds are lowered before normal elaboration has built the
   netlist enum table, so the SVA constant evaluator must understand the
   declaration's implicit numbering itself. */
static bool pform_sva_enum_long_(LexicalScope*scope, perm_string name,
				 long&value,
				 std::set<const PExpr*>&visiting)
{
      if (!scope) return false;
      for (std::vector<enum_type_t*>::const_iterator et =
		     scope->enum_sets.begin() ; et != scope->enum_sets.end(); ++et) {
	    long next = 0;
	    if (!*et || !(*et)->names) continue;
	    for (std::list<named_pexpr_t>::const_iterator nm =
		       (*et)->names->begin() ; nm != (*et)->names->end(); ++nm) {
		  long cur = next;
		  if (nm->parm && !pform_sva_const_long_(nm->parm, cur,
						     visiting, scope))
			return false;
		  if (nm->name == name) {
			value = cur;
			return true;
		  }
		  if (cur == LONG_MAX) return false;
		  next = cur + 1;
	    }
      }
      return false;
}

/* Constant classification is deliberately separate from numeric folding.
   A parameter/enum remains a constant even when its initializer is wider
   than long or uses an expression shape this early SVA evaluator does not
   fold (for example $clog2 or a concatenated sparse-FSM enum value). Such a
   name must not be sampled or reported as a live design operand. */
static bool pform_sva_enum_has_(LexicalScope*scope, perm_string name)
{
      if (!scope) return false;
      for (std::vector<enum_type_t*>::const_iterator et =
		     scope->enum_sets.begin() ; et != scope->enum_sets.end(); ++et) {
	    if (!*et || !(*et)->names) continue;
	    for (std::list<named_pexpr_t>::const_iterator nm =
		       (*et)->names->begin() ; nm != (*et)->names->end(); ++nm)
		  if (nm->name == name) return true;
      }
      return false;
}

/* Follow a selected member through a named assignment-pattern constant.
   SVA delay/repetition bounds are folded while the parse form is being
   built, before normal parameter elaboration can turn a packed struct into
   a NetEConst and apply a member select.  OpenTitan's reset assertions use
   nested localparam patterns such as:

       localparam edge_bounds_t Cycles =
           '{fall:'{min:0,max:4}, rise:'{min:2,max:8}};
       ... ##[Cycles.fall.min:Cycles.fall.max] ...

   Preserve the normal constant-expression rule by accepting only named
   (or defaulted) pattern members here.  Positional patterns still take the
   loud nonconstant-bound path until their declared struct layout is carried
   into this early evaluator. */
static bool pform_sva_named_pattern_long_(
		PExpr*expr, const std::vector<perm_string>&members,
		size_t member_idx, long&value,
		std::set<const PExpr*>&visiting,
		LexicalScope*lookup_scope)
{
      if (member_idx == members.size())
	    return pform_sva_const_long_(expr, value, visiting, lookup_scope);

      PEAssignPattern*pattern = dynamic_cast<PEAssignPattern*>(expr);
      if (!pattern || pattern->replication()) return false;
      const std::vector<PExpr*>&values = pattern->parms();
      const std::vector<perm_string>&names = pattern->parm_names();
      if (values.size() != names.size()) return false;

      PExpr*selected = nullptr;
      PExpr*default_value = nullptr;
      perm_string default_name = lex_strings.make("default");
      for (size_t idx = 0 ; idx < names.size() ; idx += 1) {
	    if (names[idx] == members[member_idx]) selected = values[idx];
	    if (names[idx] == default_name) default_value = values[idx];
      }
      if (!selected) selected = default_value;
      if (!selected) return false;
      return pform_sva_named_pattern_long_(selected, members, member_idx + 1,
					    value, visiting, lookup_scope);
}

/* Return true when the root object named by an identifier is a parameter or
   enum literal. A selected parameter array such as LUT[idx] is not itself a constant
   expression when idx is live, but the LUT storage still must not be sampled:
   only idx is a design operand. */
static bool pform_sva_ident_base_is_constant_(const PEIdent*id)
{
      if (!id || id->path().name.empty()) return false;
      perm_string name = id->path().name.front().name;
      if (id->path().package) {
	    PPackage*pkg = id->path().package;
	    std::map<perm_string,LexicalScope::param_expr_t*>::const_iterator pit =
		  pkg->parameters.find(name);
	    return (pit != pkg->parameters.end() && pit->second
		    && !pit->second->type_flag)
		  || pform_sva_enum_has_(pkg, name);
      }
      for (LexicalScope*scope = lexical_scope ; scope
	   ; scope = scope->parent_scope()) {
	    std::map<perm_string,LexicalScope::param_expr_t*>::const_iterator pit =
		  scope->parameters.find(name);
	    if (pit != scope->parameters.end())
		  return pit->second && !pit->second->type_flag;
	    if (pform_sva_enum_has_(scope, name)) return true;
	    std::map<perm_string,PPackage*>::const_iterator imp =
		  scope->explicit_imports.find(name);
	    if (imp != scope->explicit_imports.end()) {
		  PPackage*pkg = imp->second;
		  std::map<perm_string,LexicalScope::param_expr_t*>::const_iterator pp =
			pkg->parameters.find(name);
		  return (pp != pkg->parameters.end() && pp->second
			  && !pp->second->type_flag)
			|| pform_sva_enum_has_(pkg, name);
	    }
	    for (std::list<PPackage*>::const_iterator pkg =
		       scope->potential_imports.begin()
		 ; pkg != scope->potential_imports.end() ; ++pkg) {
		  std::map<perm_string,LexicalScope::param_expr_t*>::const_iterator pp =
			(*pkg)->parameters.find(name);
		  if ((pp != (*pkg)->parameters.end() && pp->second
		       && !pp->second->type_flag)
		      || pform_sva_enum_has_(*pkg, name)) return true;
	    }
      }
      return false;
}

static bool pform_sva_const_long_(PExpr*expr, long&value,
				  std::set<const PExpr*>&visiting,
				  LexicalScope*lookup_scope)
{
      if (!expr || visiting.count(expr)) return false;
      visiting.insert(expr);
      if (PENumber*num = dynamic_cast<PENumber*>(expr)) {
	    value = num->value().as_long();
	    visiting.erase(expr);
	    return true;
      }
      if (PEIdent*id = dynamic_cast<PEIdent*>(expr)) {
	    bool plain_path = !id->path().name.empty();
	    for (pform_name_t::const_iterator component =
		       id->path().name.begin()
	 ; component != id->path().name.end() ; ++component)
		  if (!component->index.empty()) plain_path = false;
	    if (plain_path) {
		  perm_string name = id->path().name.front().name;
		  std::vector<perm_string> members;
		  for (pform_name_t::const_iterator component =
			 id->path().name.begin()
		       ; component != id->path().name.end() ; ++component) {
			if (component == id->path().name.begin()) continue;
			members.push_back(component->name);
		  }
		  auto eval_parameter = [&](LexicalScope::param_expr_t*parm,
					    LexicalScope*parm_scope) -> bool {
			if (!parm || parm->type_flag || !parm->expr) return false;
			if (members.empty())
			      return pform_sva_const_long_(parm->expr, value,
						   visiting, parm_scope);
			/* A selected overridable parameter cannot be frozen at its
			   declaration default.  The same holds for a localparam whose
			   assignment pattern depends on an overridable parameter. */
			std::set<const LexicalScope::param_expr_t*> param_visiting;
			if (parm->overridable
			    || pform_sva_overridable_bound_(parm->expr, parm_scope,
							 param_visiting))
			      return false;
			return pform_sva_named_pattern_long_(parm->expr, members, 0,
						      value, visiting, parm_scope);
		  };
		  if (id->path().package) {
			PPackage*pkg = id->path().package;
			std::map<perm_string,LexicalScope::param_expr_t*>::iterator it =
			      pkg->parameters.find(name);
			bool ok = false;
			if (it != pkg->parameters.end())
			      ok = eval_parameter(it->second, pkg);
			else if (members.empty())
			      ok = pform_sva_enum_long_(pkg, name, value, visiting);
			visiting.erase(expr);
			return ok;
		  }
		  for (LexicalScope*scope = lookup_scope ; scope
		       ; scope = scope->parent_scope()) {
			std::map<perm_string,LexicalScope::param_expr_t*>::iterator it =
			      scope->parameters.find(name);
			if (it != scope->parameters.end()) {
			      bool ok = eval_parameter(it->second, scope);
			      visiting.erase(expr);
			      return ok;
			}
			if (members.empty()
			    && pform_sva_enum_long_(scope, name, value, visiting)) {
			      visiting.erase(expr);
			      return true;
			}
			std::map<perm_string,PPackage*>::iterator imp =
			      scope->explicit_imports.find(name);
			if (imp != scope->explicit_imports.end()) {
			      PPackage*pkg = imp->second;
			      std::map<perm_string,LexicalScope::param_expr_t*>::iterator
				    pit = pkg->parameters.find(name);
			      bool ok = pit != pkg->parameters.end()
				 ? eval_parameter(pit->second, pkg)
				 : members.empty()
				   && pform_sva_enum_long_(pkg, name, value, visiting);
			      visiting.erase(expr);
			      return ok;
			}

			/* A wildcard import is pinned into explicit_imports only when
			   ordinary name resolution reaches the reference. SVA delay
			   bounds are folded while the parse form is being built, before
			   that later pass. Resolve an unambiguous wildcard parameter or
			   enum here too (IEEE 1800-2017 26.3). */
			PPackage*wild_pkg = nullptr;
			for (std::list<PPackage*>::const_iterator search =
				   scope->potential_imports.begin()
			     ; search != scope->potential_imports.end() ; ++search) {
			      PPackage*decl = pform_package_importable(*search, name);
			      if (!decl) continue;
			      std::map<perm_string,LexicalScope::param_expr_t*>::iterator pit =
				    decl->parameters.find(name);
			      bool has_name = pit != decl->parameters.end()
				    || pform_sva_enum_has_(decl, name);
			      if (!has_name) continue;
			      if (wild_pkg && wild_pkg != decl) {
				    visiting.erase(expr);
				    return false;
			      }
			      wild_pkg = decl;
			}
			if (wild_pkg) {
			      std::map<perm_string,LexicalScope::param_expr_t*>::iterator pit =
				    wild_pkg->parameters.find(name);
			      bool ok = pit != wild_pkg->parameters.end()
				  ? eval_parameter(pit->second, wild_pkg)
				  : members.empty()
				    && pform_sva_enum_long_(wild_pkg, name, value, visiting);
			      visiting.erase(expr);
			      return ok;
			}
		  }
	    }
	    visiting.erase(expr);
	    return false;
      }
      if (PEUnary*un = dynamic_cast<PEUnary*>(expr)) {
	    long a = 0;
	    bool ok = pform_sva_const_long_(un->get_expr(), a, visiting,
					 lookup_scope);
	    if (ok) switch (un->get_op()) {
		case '+': value = a; break;
		case '-': value = -a; break;
		case '~': value = ~a; break;
		case '!': value = !a; break;
		default: ok = false; break;
	    }
	    visiting.erase(expr);
	    return ok;
      }
      if (PEBinary*bin = dynamic_cast<PEBinary*>(expr)) {
	    long a = 0, b = 0;
	    bool ok = pform_sva_const_long_(bin->get_left(), a, visiting,
					 lookup_scope)
		   && pform_sva_const_long_(bin->get_right(), b, visiting,
						lookup_scope);
	    if (ok) switch (bin->get_op()) {
		case '+': value = a + b; break;
		case '-': value = a - b; break;
		case '*': value = a * b; break;
		case 'p': {
		      /* Integral exponentiation. The early SVA folder only needs
			 constant delay bounds; use unsigned multiplication so the
			 machine-width wrap is defined, matching the width-agnostic
			 treatment of the other operators in this helper. */
		      if (b < 0) {
			    value = 0;
			    break;
		      }
		      unsigned long result = 1;
		      unsigned long base = static_cast<unsigned long>(a);
		      unsigned long power = static_cast<unsigned long>(b);
		      while (power) {
			    if (power & 1UL) result *= base;
			    power >>= 1;
			    if (power) base *= base;
		      }
		      value = static_cast<long>(result);
		      break;
		}
		case '/': if (b) value = a / b; else ok = false; break;
		case '%': if (b) value = a % b; else ok = false; break;
		case '&': value = a & b; break;
		case '|': value = a | b; break;
		case '^': value = a ^ b; break;
		case 'X': value = ~(a ^ b); break;
		case 'A': value = ~(a & b); break;
		case 'O': value = ~(a | b); break;
		case 'l': if (b >= 0 && b < long(sizeof(long) * CHAR_BIT))
				value = long(static_cast<unsigned long>(a) << b);
			  else ok = false; break;
		case 'r':
			  if (b >= 0 && b < long(sizeof(long) * CHAR_BIT))
				value = long(static_cast<unsigned long>(a) >> b);
			  else ok = false; break;
		case 'R':
			  if (b >= 0 && b < long(sizeof(long) * CHAR_BIT)) value = a >> b;
			  else ok = false; break;
		case '<': value = a < b; break;
		case '>': value = a > b; break;
		case 'L': value = a <= b; break;
		case 'G': value = a >= b; break;
		case 'e': case 'E': case 'w': value = a == b; break;
		case 'n': case 'N': case 'W': value = a != b; break;
		case 'a': value = a && b; break;
		case 'o': value = a || b; break;
		case 'q': value = !a || b; break;
		case 'Q': value = (!a) == (!b); break;
		default: ok = false; break;
	    }
	    visiting.erase(expr);
	    return ok;
      }
      if (PETernary*ter = dynamic_cast<PETernary*>(expr)) {
	    long cond = 0;
	    bool ok = pform_sva_const_long_(ter->get_cond(), cond, visiting,
					 lookup_scope);
	    if (ok)
		  ok = pform_sva_const_long_(cond ? ter->get_true()
					     : ter->get_false(),
					     value, visiting, lookup_scope);
	    visiting.erase(expr);
	    return ok;
      }
      visiting.erase(expr);
      return false;
}

bool pform_sva_const_long(PExpr*expr, long&value)
{
      std::set<const PExpr*> visiting;
      return pform_sva_const_long_(expr, value, visiting, lexical_scope);
}

bool pform_sva_deferred_genvar(PExpr*expr, perm_string&name)
{
      PEIdent*id = dynamic_cast<PEIdent*>(expr);
      if (!id || id->path().package || id->path().name.size() != 1
	  || !id->path().name.front().index.empty())
	    return false;

      perm_string candidate = id->path().name.front().name;
      for (LexicalScope*scope = lexical_scope ; scope
	   ; scope = scope->parent_scope()) {
	    if (scope->genvars.find(candidate) != scope->genvars.end()) {
		  name = candidate;
		  return true;
	    }
	      /* Ordinary lexical shadowing wins over an outer genvar. */
	    if (scope->parameters.find(candidate) != scope->parameters.end()
		|| scope->wires.find(candidate) != scope->wires.end())
		  return false;
      }
      return false;
}

static void sva_attach_local_declarations_(sva_property_t*prop);

void pform_sva_declare_property(const struct vlltype&loc, const char*name,
				sva_property_t*prop)
{
      sva_attach_local_declarations_(prop);
      pform_sva_end_local_declarations();
      perm_string use_name = lex_strings.make(name);
      sva_scoped_name_t key = sva_decl_key_(use_name);
      if (sva_module_properties.count(key)
	  || sva_module_sequences.count(key)) {
	    cerr << loc << ": error: duplicate property declaration `"
		 << use_name << "'." << endl;
	    error_count += 1;
	    pform_sva_destroy_property(prop);
	    return;
      }
      sva_decl_property_forget_sampled_(prop);
      sva_module_properties[key] = prop;
}

void pform_sva_declare_sequence(const struct vlltype&loc, const char*name,
				std::vector<sva_seq_step_t>*steps)
{
      pform_sva_end_local_declarations();
      perm_string use_name = lex_strings.make(name);
      sva_scoped_name_t key = sva_decl_key_(use_name);
      if (sva_module_sequences.count(key)
	  || sva_module_properties.count(key)) {
	    cerr << loc << ": error: duplicate sequence declaration `"
		 << use_name << "'." << endl;
	    error_count += 1;
	    pform_sva_destroy_sequence(steps);
	    return;
      }
      sva_decl_sequence_forget_sampled_(steps);
      sva_module_sequences[key] = steps;
}

void pform_sva_declare_sequence_spec(const struct vlltype&loc,
				     const char*name, sva_property_t*body)
{
      sva_attach_local_declarations_(body);
      pform_sva_end_local_declarations();
      perm_string use_name = lex_strings.make(name);
      sva_scoped_name_t key = sva_decl_key_(use_name);

      if (!body) return;
      if (body->op_type != 0 || body->antecedent || body->ante_tree
	  || body->disable_iff_expr || body->abort_cond
	  || body->strength != 0 || body->forbidden_consequent
	  || body->win_lo != -1 || body->win_hi != -1) {
	    cerr << loc << ": error: sequence declaration `" << use_name
		 << "' contains a property-only operator; a sequence body must be "
		 << "a sequence_expr (IEEE 1800-2017 A.2.2)." << endl;
	    error_count += 1;
	    pform_sva_destroy_property(body);
	    return;
      }

      if (sva_module_sequences.count(key)
	  || sva_module_properties.count(key)) {
	    cerr << loc << ": error: duplicate sequence declaration `"
		 << use_name << "'." << endl;
	    error_count += 1;
	    pform_sva_destroy_property(body);
	    return;
      }

	/* Preserve the legacy splice representation whenever no property-shaped
	   context exists.  This keeps every old unclocked named sequence on the
	   exact same lowering path. */
      bool plain = body->seq && !body->tree && !body->clk_evt
		 && !body->seq_clk_evt && !body->mc_prefix
		 && (!body->mc_more || body->mc_more->empty())
		 && body->mc_boundary == -1 && body->local_names.empty();
      if (plain) {
	    std::vector<sva_seq_step_t>*steps = body->seq;
	    body->seq = nullptr;
	    pform_sva_destroy_property(body);
	    sva_decl_sequence_forget_sampled_(steps);
	    sva_module_sequences[key] = steps;
	    return;
      }

      sva_decl_property_forget_sampled_(body);
      sva_module_properties[key] = body;
      sva_property_shaped_sequences.insert(key);
}

/* M9D: parameterized named property/sequence declarations. */
void pform_sva_declare_property_p(const struct vlltype&loc, const char*name,
				  std::list<perm_string>*formals,
				  sva_property_t*prop)
{
      sva_attach_local_declarations_(prop);
      pform_sva_end_local_declarations();
      perm_string use_name = lex_strings.make(name);
      if (sva_param_properties.count(sva_decl_key_(use_name))
	  || sva_module_properties.count(sva_decl_key_(use_name))) {
	    cerr << loc << ": error: duplicate property declaration `"
		 << use_name << "'." << endl;
	    error_count += 1;
	    delete formals;
	    pform_sva_destroy_property(prop);
	    return;
      }
      sva_param_prop_t rec;
      if (formals) { for (perm_string f : *formals) rec.formals.push_back(f); }
      sva_decl_property_forget_sampled_(prop);
      rec.body = prop;
      sva_param_properties[sva_decl_key_(use_name)] = rec;
      delete formals;
}

void pform_sva_declare_sequence_p(const struct vlltype&loc, const char*name,
				  std::list<perm_string>*formals,
				  std::vector<sva_seq_step_t>*steps)
{
      pform_sva_end_local_declarations();
      perm_string use_name = lex_strings.make(name);
      if (sva_param_sequences.count(sva_decl_key_(use_name))
	  || sva_module_sequences.count(sva_decl_key_(use_name))) {
	    cerr << loc << ": error: duplicate sequence declaration `"
		 << use_name << "'." << endl;
	    error_count += 1;
	    delete formals;
	    pform_sva_destroy_sequence(steps);
	    return;
      }
      sva_param_seq_t rec;
      if (formals) { for (perm_string f : *formals) rec.formals.push_back(f); }
      sva_decl_sequence_forget_sampled_(steps);
      rec.body = steps;
      sva_param_sequences[sva_decl_key_(use_name)] = rec;
      delete formals;
}

void pform_sva_module_done(void)
{
      /* Error recovery can abandon a malformed declaration before its
         ordinary declaration action runs. Do not leak its temporary type
         expressions or let them affect a later module. */
      pform_sva_end_local_declarations();
      for (std::map<sva_scoped_name_t, sva_property_t*>::iterator it =
		sva_module_properties.begin() ;
	   it != sva_module_properties.end() ; ++it)
	    pform_sva_destroy_property(it->second);
      for (std::map<sva_scoped_name_t, std::vector<sva_seq_step_t>*>::iterator it =
		sva_module_sequences.begin() ;
	   it != sva_module_sequences.end() ; ++it)
	    pform_sva_destroy_sequence(it->second);
      for (std::map<sva_scoped_name_t, sva_param_seq_t>::iterator it =
		sva_param_sequences.begin() ;
	   it != sva_param_sequences.end() ; ++it)
	    pform_sva_destroy_sequence(it->second.body);
      for (std::map<sva_scoped_name_t, sva_param_prop_t>::iterator it =
		sva_param_properties.begin() ;
	   it != sva_param_properties.end() ; ++it)
	    pform_sva_destroy_property(it->second.body);
      sva_module_properties.clear();
      sva_module_sequences.clear();
      sva_property_shaped_sequences.clear();
      sva_param_sequences.clear();
      sva_param_properties.clear();
      delete sva_default_disable;
      sva_default_disable = nullptr;
}

static PExpr* sva_clone_subst_(
      PExpr*e, const std::map<perm_string,PExpr*>*subst);

/* Class-specialization actuals are owned by their PEIdent/PECallFunction.
 * Assertion rewriting often destroys the source expression before the clone
 * is elaborated, so borrowing this list is a use-after-free. Clone the list
 * and every value actual with the same substitution rules as the containing
 * expression. */
static parmvalue_t* sva_clone_parmvalue_(
      const parmvalue_t*source,
      const std::map<perm_string,PExpr*>*subst)
{
      if (!source) return nullptr;
      parmvalue_t*copy = new parmvalue_t;
      copy->by_order = nullptr;
      copy->by_name = nullptr;

      if (source->by_order) {
	    copy->by_order = new std::list<PExpr*>;
	    for (PExpr*actual : *source->by_order) {
		  PExpr*cloned = actual ? sva_clone_subst_(actual, subst) : nullptr;
		  if (actual && !cloned) {
			delete_parmvalue(copy);
			return nullptr;
		  }
		  copy->by_order->push_back(cloned);
	    }
      }
      if (source->by_name) {
	    copy->by_name = new std::list<named_pexpr_t>;
	    for (const named_pexpr_t&actual : *source->by_name) {
		  named_pexpr_t cloned;
		  cloned.name = actual.name;
		  cloned.parm = actual.parm
			? sva_clone_subst_(actual.parm, subst) : nullptr;
		  if (actual.parm && !cloned.parm) {
			delete_parmvalue(copy);
			return nullptr;
		  }
		  copy->by_name->push_back(cloned);
	    }
      }
      return copy;
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
	    /* A formal/local can occur in a select as well as as the whole
	       identifier: `vec[idx]' is the important SVA-local case.  A
	       pform_name_t copy retains the original index-expression pointers,
	       so rebuild every index expression recursively before constructing
	       the new PEIdent.  Otherwise the per-attempt substitution stopped at
	       the vector name and left `idx' as an unresolved/shared live name. */
	    pform_name_t path = id->path().name;
	    pform_name_t::const_iterator src_comp = id->path().name.begin();
	    pform_name_t::iterator dst_comp = path.begin();
	    for ( ; src_comp != id->path().name.end();
		  ++src_comp, ++dst_comp) {
		  std::list<index_component_t>::const_iterator src_idx =
			src_comp->index.begin();
		  std::list<index_component_t>::iterator dst_idx =
			dst_comp->index.begin();
		  for ( ; src_idx != src_comp->index.end();
			++src_idx, ++dst_idx) {
			PExpr*new_msb = src_idx->msb
			      ? sva_clone_subst_(src_idx->msb, subst) : nullptr;
			if (src_idx->msb && !new_msb) return nullptr;
			PExpr*new_lsb = src_idx->lsb == src_idx->msb
			      ? new_msb
			      : (src_idx->lsb
				 ? sva_clone_subst_(src_idx->lsb, subst) : nullptr);
			if (src_idx->lsb && !new_lsb) {
			      delete new_msb;
			      return nullptr;
			}
			dst_idx->msb = new_msb;
			dst_idx->lsb = new_lsb;
		  }
	    }
	    PEIdent*cp = id->path().package
		  ? new PEIdent(id->path().package, path, id->lexical_pos())
		  : new PEIdent(path, id->lexical_pos());
	    if (id->leading_type_args()) {
		  parmvalue_t*type_args = sva_clone_parmvalue_(
			id->leading_type_args(), subst);
		  if (!type_args) { delete cp; return nullptr; }
		  cp->set_leading_type_args(type_args);
	    }
	    cp->set_scoped_type_prefix(id->has_scoped_type_prefix());
	    cp->set_line(*e);
	    return cp;
      }
      if (PENumber*num = dynamic_cast<PENumber*>(e)) {
	    PENumber*cp = new PENumber(new verinum(num->value()));
	    cp->set_line(*e);
	    return cp;
      }
	/* A real literal is as constant as an integer one; without this the
	   whole guard fell back to a live read for something as ordinary as
	   `r > 1.0'. */
      if (PEFNumber*fnum = dynamic_cast<PEFNumber*>(e)) {
	    PEFNumber*cp = new PEFNumber(new verireal(fnum->value()));
	    cp->set_line(*e);
	    return cp;
      }
      if (PEString*str = dynamic_cast<PEString*>(e)) {
	    PEString*cp = new PEString(strdup(str->value().c_str()));
	    cp->set_line(*e);
	    return cp;
      }
      if (PETypename*type = dynamic_cast<PETypename*>(e)) {
	    /* PETypename is a non-owning carrier for the parsed data_type_t.
	     * Preserve that shared type identity while giving the specialization
	     * actual its own expression node and lifetime. */
	    PETypename*cp = new PETypename(type->get_type());
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
	    else if (dynamic_cast<PEBPower*>(e))
		  cp = new PEBPower(bin->get_op(), l, r);
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
	/* Membership expressions are common in parameterized assertion
	   properties (OpenTitan uses `byte inside {'0, '1}`). Clone both
	   endpoints and any dist weight so formal substitution reaches every
	   expression owned by the node. */
      if (PEInside*inside = dynamic_cast<PEInside*>(e)) {
	    PExpr*base = sva_clone_subst_(inside->get_expr(), subst);
	    if (!base) return nullptr;
	    std::list<inside_range_t>*ranges = new std::list<inside_range_t>;
	    const std::vector<inside_range_t>&src = inside->get_ranges();
	    for (size_t k = 0 ; k < src.size() ; k += 1) {
		  inside_range_t dst;
		  dst.lo = src[k].lo ? sva_clone_subst_(src[k].lo, subst) : nullptr;
		  dst.hi = src[k].hi ? sva_clone_subst_(src[k].hi, subst) : nullptr;
		  dst.weight = src[k].weight
			? sva_clone_subst_(src[k].weight, subst) : nullptr;
		  dst.is_range = src[k].is_range;
		  dst.weight_is_divided = src[k].weight_is_divided;
		  if ((src[k].lo && !dst.lo) || (src[k].hi && !dst.hi)
		      || (src[k].weight && !dst.weight)) {
			delete dst.lo;
			delete dst.hi;
			delete dst.weight;
			delete base;
			for (std::list<inside_range_t>::iterator it = ranges->begin()
			     ; it != ranges->end() ; ++it) {
			      delete it->lo;
			      delete it->hi;
			      delete it->weight;
			}
			delete ranges;
			return nullptr;
		  }
		  ranges->push_back(dst);
	    }
	    PEInside*cp = new PEInside(base, ranges, inside->is_dist());
	    cp->set_line(*e);
	    return cp;
      }
	/* Casts are transparent to sampling but not to expression type.
	   Preserve the cast node while cloning/replacing its operand. Parse
	   data-type nodes are arena-like (PECastType does not own/delete its
	   target), so sharing the immutable target is intentional. */
      if (PECastSize*cast = dynamic_cast<PECastSize*>(e)) {
	    PExpr*size = sva_clone_subst_(cast->cast_size(), subst);
	    PExpr*base = sva_clone_subst_(cast->cast_base(), subst);
	    if (!size || !base) { delete size; delete base; return nullptr; }
	    PECastSize*cp = new PECastSize(size, base);
	    cp->set_line(*e);
	    return cp;
      }
      if (PECastType*cast = dynamic_cast<PECastType*>(e)) {
	    PExpr*base = sva_clone_subst_(cast->cast_base(), subst);
	    if (!base) return nullptr;
	    PECastType*cp = new PECastType(cast->cast_target(), base);
	    cp->set_line(*e);
	    return cp;
      }
      if (PECastSign*cast = dynamic_cast<PECastSign*>(e)) {
	    PExpr*base = sva_clone_subst_(cast->cast_base(), subst);
	    if (!base) return nullptr;
	    PECastSign*cp = new PECastSign(cast->has_sign(), base);
	    cp->set_line(*e);
	    return cp;
      }
	/* Concatenations occur frequently inside reusable named sequences
	   (for example `$countones(mask ^ {mask[..], 1'b0})'). They are
	   ordinary structural expression nodes and are safe to duplicate. */
      if (PEConcat*cat = dynamic_cast<PEConcat*>(e)) {
	    std::list<PExpr*> parms;
	    for (std::vector<PExpr*>::const_iterator it =
		       cat->stream_parms().begin()
		 ; it != cat->stream_parms().end() ; ++it) {
		  PExpr*cp = sva_clone_subst_(*it, subst);
		  if (!cp) {
			for (std::list<PExpr*>::iterator jt = parms.begin()
			     ; jt != parms.end() ; ++jt) delete *jt;
			return nullptr;
		  }
		  parms.push_back(cp);
	    }
	    PExpr*rep = nullptr;
	    if (cat->has_repeat()) {
		  rep = sva_clone_subst_(cat->repeat_expr(), subst);
		  if (!rep) {
			for (std::list<PExpr*>::iterator jt = parms.begin()
			     ; jt != parms.end() ; ++jt) delete *jt;
			return nullptr;
		  }
	    }
	    PEConcat*cp = new PEConcat(parms, rep);
	    cp->set_line(*e);
	    return cp;
      }
      /* System/sampled function calls ($rose/$past/…) with copyable
	   argument expressions — needed so a formal can appear inside a
	   sampled-value function of a parameterized body. */
      if (PECallFunction*cf = dynamic_cast<PECallFunction*>(e)) {
	    if (cf->receiver_expr()) return nullptr;
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
	    PECallFunction*cp = cf->path().package
		  ? new PECallFunction(cf->path().package, cf->path().name, np)
		  : new PECallFunction(cf->path().name, np);
	    if (cf->leading_type_args()) {
		  parmvalue_t*type_args = sva_clone_parmvalue_(
			cf->leading_type_args(), subst);
		  if (!type_args) { delete cp; return nullptr; }
		  cp->set_leading_type_args(type_args);
	    }
	    std::vector<PExpr*> with;
	    for (PExpr*source : cf->with_constraints()) {
		  PExpr*item = sva_clone_subst_(source, subst);
		  if (!item) {
			for (PExpr*prior : with) delete prior;
			delete cp;
			return nullptr;
		  }
		  with.push_back(item);
	    }
	    cp->set_with_constraints(std::move(with));
	    if (cf->has_randomize_with_identifier_list())
		  cp->set_randomize_with_identifiers(
			cf->randomize_with_identifiers());
	    cp->set_scoped_type_prefix(cf->has_scoped_type_prefix());
	    cp->set_line(*e);
	    return cp;
      }
      return nullptr;
}

static PExpr* sva_clone_expr_(PExpr*e)
{
      return sva_clone_subst_(e, nullptr);
}

struct sva_local_decl_type_t {
      PExpr*width = nullptr;
      bool signed_flag = false;
};

/* Named property/sequence local declarations are not ordinary module wires,
   but their assignment conversion still has to be preserved in the lowered
   checker (IEEE 1800-2023 16.10). Keep the declaration type only while the
   declaration body is parsed and embed its conversion directly into each
   match-item RHS. The resulting expression then survives every existing
   property/sequence clone without adding parallel type ownership to the IR. */
static std::map<perm_string,sva_local_decl_type_t> sva_local_decl_types_;

/* Transfer declaration identity into the property IR before the temporary
   type/coercion table is cleared. Assignment destinations alone are
   insufficient: a declared-but-unassigned local still shadows a module
   object of the same name. */
static void sva_attach_local_declarations_(sva_property_t*prop)
{
      if (!prop) return;
      for (std::map<perm_string,sva_local_decl_type_t>::const_iterator it =
	   sva_local_decl_types_.begin(); it != sva_local_decl_types_.end(); ++it)
	    prop->local_names.push_back(it->first);
}

void pform_sva_end_local_declarations(void)
{
      for (std::map<perm_string,sva_local_decl_type_t>::iterator it =
	   sva_local_decl_types_.begin(); it != sva_local_decl_types_.end(); ++it)
	    delete it->second.width;
      sva_local_decl_types_.clear();
}

void pform_sva_begin_local_declarations(void)
{
      /* This also recovers safely after a malformed prior declaration. */
      pform_sva_end_local_declarations();
}

static PExpr* sva_local_dimension_width_(const struct vlltype&loc,
					 PExpr*left, PExpr*right)
{
      PExpr*cl = sva_clone_expr_(left);
      PExpr*cr = sva_clone_expr_(right);
      PExpr*tl = sva_clone_expr_(left);
      PExpr*tr = sva_clone_expr_(right);
      PExpr*fl = sva_clone_expr_(left);
      PExpr*fr = sva_clone_expr_(right);
      if (!cl || !cr || !tl || !tr || !fl || !fr) {
	    delete cl; delete cr; delete tl; delete tr; delete fl; delete fr;
	    return nullptr;
      }

      PEBComp*descending = new PEBComp('G', cl, cr);
      FILE_NAME(descending, loc);
      PEBinary*tdiff = new PEBinary('-', tl, tr);
      FILE_NAME(tdiff, loc);
      PEBinary*fdiff = new PEBinary('-', fr, fl);
      FILE_NAME(fdiff, loc);
      PENumber*tone = new PENumber(new verinum((uint64_t)1, 32));
      PENumber*fone = new PENumber(new verinum((uint64_t)1, 32));
      FILE_NAME(tone, loc);
      FILE_NAME(fone, loc);
      PEBinary*twid = new PEBinary('+', tdiff, tone);
      PEBinary*fwid = new PEBinary('+', fdiff, fone);
      FILE_NAME(twid, loc);
      FILE_NAME(fwid, loc);
      PETernary*width = new PETernary(descending, twid, fwid);
      FILE_NAME(width, loc);
      return width;
}

static void sva_local_decl_insert_(const struct vlltype&loc,
				    const char*name, PExpr*width,
				    bool signed_flag)
{
      perm_string key = lex_strings.make(name);
      if (sva_local_decl_types_.count(key)) {
	    cerr << loc << ": error: duplicate assertion local variable `"
		 << key << "'." << endl;
	    error_count += 1;
	    delete width;
	    return;
      }
      sva_local_decl_type_t rec;
      rec.width = width;
      rec.signed_flag = signed_flag;
      sva_local_decl_types_[key] = rec;
}

void pform_sva_declare_int_local(const struct vlltype&loc, const char*name)
{
      PENumber*width = new PENumber(new verinum((uint64_t)32, 32));
      FILE_NAME(width, loc);
      sva_local_decl_insert_(loc, name, width, true);
}

void pform_sva_declare_logic_local(const struct vlltype&loc,
				    const char*name,
				    std::list<pform_range_t>*dimensions)
{
      PExpr*width = nullptr;
      bool failed = false;
      if (dimensions) {
	    for (std::list<pform_range_t>::iterator it = dimensions->begin();
		 it != dimensions->end(); ++it) {
		  PExpr*right = it->second ? it->second : it->first;
		  PExpr*dim = sva_local_dimension_width_(loc, it->first, right);
		  if (!dim) { failed = true; break; }
		  if (!width) width = dim;
		  else {
			PEBinary*product = new PEBinary('*', width, dim);
			FILE_NAME(product, loc);
			width = product;
		  }
	    }
      }
      if (!width && !failed) {
	    width = new PENumber(new verinum((uint64_t)1, 32));
	    FILE_NAME(width, loc);
      }

      if (dimensions) {
	    for (std::list<pform_range_t>::iterator it = dimensions->begin();
		 it != dimensions->end(); ++it) {
		  delete it->first;
		  if (it->second != it->first) delete it->second;
	    }
	    delete dimensions;
      }

      if (failed) {
	    delete width;
	    cerr << loc << ": sorry: assertion local variable `" << name
		 << "' has a packed dimension that cannot be preserved; its "
		    "declaration is rejected." << endl;
	    error_count += 1;
	    return;
      }
      sva_local_decl_insert_(loc, name, width, false);
}

PExpr* pform_sva_coerce_local_assignment(const struct vlltype&loc,
					  const char*name, PExpr*rhs)
{
      std::map<perm_string,sva_local_decl_type_t>::const_iterator it =
	    sva_local_decl_types_.find(lex_strings.make(name));
      if (it == sva_local_decl_types_.end()) return rhs;
      PExpr*width = sva_clone_expr_(it->second.width);
      if (!width) {
	    cerr << loc << ": sorry: assertion local variable `" << name
		 << "' has a declaration width that cannot be applied to its "
		    "assignment." << endl;
	    error_count += 1;
	    return rhs;
      }
      PECastSize*size = new PECastSize(width, rhs);
      FILE_NAME(size, loc);
      PECastSign*sign = new PECastSign(it->second.signed_flag, size);
      FILE_NAME(sign, loc);
      return sign;
}

/* The first executable 16.11 slice deliberately supports only a direct
   $display match item. Keeping this predicate in one place makes cloning,
   validation, and action construction agree: no package/receiver/type-arg
   call can accidentally be rebuilt as an unrelated unqualified task. */
static bool sva_match_call_is_display_(const PCallTask*call)
{
      if (!call || call->is_void_cast() || call->leading_type_args()
	  || !call->with_constraints().empty())
	    return false;
      const pform_name_t&path = call->path();
      return path.size() == 1 && path.front().index.empty()
	     && path.front().name == perm_string::literal("$display");
}

static PCallTask* sva_clone_match_call_(
      const PCallTask*source,
      const std::map<perm_string,PExpr*>*subst = nullptr)
{
      if (!sva_match_call_is_display_(source)) return nullptr;
      std::list<named_pexpr_t> parms;
      const std::vector<named_pexpr_t>&src = source->parms();
      for (size_t i = 0 ; i < src.size() ; i += 1) {
	    named_pexpr_t arg;
	    arg.name = src[i].name;
	    arg.parm = src[i].parm
		 ? sva_clone_subst_(src[i].parm, subst) : nullptr;
	    if (src[i].parm && !arg.parm) {
		  for (std::list<named_pexpr_t>::iterator it = parms.begin()
		       ; it != parms.end() ; ++it)
			delete it->parm;
		  return nullptr;
	    }
	    parms.push_back(arg);
      }
      PCallTask*out = new PCallTask(source->path(), parms);
      out->set_lineno(source->get_lineno());
      out->set_file(source->get_file());
      return out;
}

static bool sva_clone_match_calls_(
      const std::vector<PCallTask*>&source,
      std::vector<PCallTask*>&out,
      const std::map<perm_string,PExpr*>*subst = nullptr)
{
      out.clear();
      for (size_t i = 0 ; i < source.size() ; i += 1) {
	    PCallTask*copy = sva_clone_match_call_(source[i], subst);
	    if (!copy) {
		  sva_destroy_match_calls_(out);
		  return false;
	    }
	    out.push_back(copy);
      }
      return true;
}

/* Match-item calls can be parsed well before pform_make_assertion sees the
   completed property. Parse-time sequence/property rewrites must consult the
   same predicate instead of silently losing the call vector while moving only
   Boolean expressions. The definitions live with the central 16.11 validator
   below. */
static bool sva_chain_has_match_calls_(
      const std::vector<sva_seq_step_t>*steps);
static bool sva_tree_has_match_calls_(const sva_stree_t*tree);
static bool sva_property_has_match_calls_(const sva_property_t*prop);
static int sva_match_item_sorry_(const struct vlltype&loc,
				 const char*reason);

/* A cloned sampled-value call is consumed by the assertion rewrite rather
   than the later procedural/default-clock binder. */
static void sampled_pending_drop_(const PECallFunction*cf);

/* Describe the narrow whole-array shapes the assertion sampler can lower
   element-wise.  Keep this query separate from the old numeric expansion:
   an unpacked bound such as [N] may name an overridable module parameter,
   in which case its parse-time value is only the declaration default. */
struct sva_uarray_operand_t {
      PEIdent*id = nullptr;
      PECallFunction*outer = nullptr;
      PWire*wire = nullptr;
};

static bool sva_uarray_operand_(PExpr*e, sva_uarray_operand_t&out)
{
      out = sva_uarray_operand_t();
      out.outer = dynamic_cast<PECallFunction*>(e);
      out.id = dynamic_cast<PEIdent*>(e);
      if (out.outer) {
	    if (out.outer->path().package || out.outer->path().name.size() != 1)
		  return false;
	    const char*nm = peek_tail_name(out.outer->path().name).str();
	    if (strcmp(nm, "$past") && strcmp(nm, "$sampled")
		&& strcmp(nm, "$stable") && strcmp(nm, "$changed"))
		  return false;
	    const std::vector<named_pexpr_t>&args = out.outer->get_parms();
	    if (args.empty()) return false;
	    out.id = dynamic_cast<PEIdent*>(args[0].parm);
      }
      if (!out.id || out.id->path().package
	  || out.id->path().name.size() != 1
	  || !out.id->path().name.front().index.empty())
	    return false;

      out.wire = pform_get_wire_in_scope(
	    out.id->path().name.front().name);
      return out.wire && out.wire->unpacked_indices().size() == 1;
}

static bool sva_uarray_bound_is_overridable_(const sva_uarray_operand_t&op)
{
      if (!op.wire || op.wire->unpacked_indices().size() != 1)
	    return false;
      const pform_range_t&range = op.wire->unpacked_indices().front();
      return pform_sva_overridable_bound(range.first)
	  || pform_sva_overridable_bound(range.second);
}

static bool sva_uarray_value_operand_(const sva_uarray_operand_t&op)
{
      if (!op.outer) return true;
      const char*nm = peek_tail_name(op.outer->path().name).str();
      return !strcmp(nm, "$past") || !strcmp(nm, "$sampled");
}

/* Expand a whole one-dimensional fixed unpacked-array operand into one
   scalar/packed expression per declared element. This is needed before
   Preponed/$past rewriting: an array is not one packed value that can be
   captured in a single history register. The optional outer sampled-value
   call is cloned around each element, yielding the IEEE element-wise array
   comparison semantics without losing the clock context. */
static bool sva_expand_uarray_operand_(PExpr*e, std::vector<PExpr*>&items)
{
      sva_uarray_operand_t operand;
      if (!sva_uarray_operand_(e, operand)) return false;
      PECallFunction*outer = operand.outer;
      PEIdent*id = operand.id;
      PWire*wire = operand.wire;
      const pform_range_t&range = wire->unpacked_indices().front();
      long left = 0, right = 0;
      if (!pform_sva_const_long(range.first, left)) return false;
      if (!range.second) {
	    if (left <= 0) return false;
	    right = left - 1;
	    left = 0;
	  } else if (!pform_sva_const_long(range.second, right)) {
	    return false;
      }
	/* Bound the parse-time expansion against hostile gigantic ranges.
	   Ordinary large arrays still reach the elaborator's loud aggregate
	   diagnostic; no unbounded allocation is attempted here. */
      unsigned long long count = left <= right
	    ? (unsigned long long)right - (unsigned long long)left + 1
	    : (unsigned long long)left - (unsigned long long)right + 1;
      if (count == 0 || count > 65536) return false;
      long step = left <= right ? 1 : -1;

      const std::vector<named_pexpr_t>*outer_args =
	    outer ? &outer->get_parms() : nullptr;
      for (unsigned long long k = 0 ; k < count ; k += 1) {
	    long index_value = left + step * (long)k;
	    pform_name_t path = id->path().name;
	    index_component_t index;
	    index.sel = index_component_t::SEL_BIT;
	    index.msb = new PENumber(new verinum((int64_t)index_value));
	    index.lsb = index.msb;
	    path.front().index.push_back(index);
	    PEIdent*word = new PEIdent(path, id->lexical_pos());
	    word->set_line(*id);
	    if (!outer) {
		  items.push_back(word);
		  continue;
	    }

	    std::list<named_pexpr_t> args;
	    for (size_t a = 0 ; a < outer_args->size() ; a += 1) {
		  named_pexpr_t arg;
		  arg.name = (*outer_args)[a].name;
		  arg.parm = a == 0 ? static_cast<PExpr*>(word)
			: sva_clone_expr_((*outer_args)[a].parm);
		  if ((*outer_args)[a].parm && !arg.parm) return false;
		  args.push_back(arg);
	    }
	    PECallFunction*call = new PECallFunction(
		  peek_tail_name(outer->path().name), args);
	    call->set_line(*outer);
	    items.push_back(call);
      }
      if (outer) sampled_pending_drop_(outer);
      return true;
}

static PExpr* sva_wrap_preponed_(
      PExpr*e, std::map<std::string, pform_name_t>&sampled,
      unsigned&live_operands,
      const std::map<perm_string,unsigned>*unsampled_locals = nullptr);

/* Clone every select expression in an identifier while applying the same
   Preponed rewrite as an ordinary operand.  This matters twice for
   `vec[idx]': the vector value is sampled as a whole, and a DESIGN index is
   sampled independently.  A sequence-local index is recognized by
   sva_wrap_preponed_ and deliberately remains an unsampled substitution
   hole, because its value belongs to one assertion attempt rather than the
   design's Preponed snapshot. */
static bool sva_wrap_name_indices_(
      const pform_name_t&source, pform_name_t&path,
      std::map<std::string, pform_name_t>&sampled,
      unsigned&live_operands,
      const std::map<perm_string,unsigned>*unsampled_locals)
{
      pform_name_t::const_iterator src_comp = source.begin();
      pform_name_t::iterator dst_comp = path.begin();
      for ( ; src_comp != source.end(); ++src_comp, ++dst_comp) {
	    std::list<index_component_t>::const_iterator src_idx =
		  src_comp->index.begin();
	    std::list<index_component_t>::iterator dst_idx =
		  dst_comp->index.begin();
	    for ( ; src_idx != src_comp->index.end(); ++src_idx, ++dst_idx) {
		  PExpr*new_msb = src_idx->msb
			? sva_wrap_preponed_(src_idx->msb, sampled,
					       live_operands, unsampled_locals)
			: nullptr;
		  if (src_idx->msb && !new_msb) return false;
		  PExpr*new_lsb = src_idx->lsb == src_idx->msb
			? new_msb
			: (src_idx->lsb
			   ? sva_wrap_preponed_(src_idx->lsb, sampled,
						 live_operands, unsampled_locals)
			   : nullptr);
		  if (src_idx->lsb && !new_lsb) {
			delete new_msb;
			return false;
		  }
		  dst_idx->msb = new_msb;
		  dst_idx->lsb = new_lsb;
	    }
      }
      return true;
}

static void sva_note_uarray_sampled_(
      const sva_uarray_operand_t&op,
      std::map<std::string, pform_name_t>&sampled)
{
      pform_name_t base = op.id->path().name;
      for (pform_name_t::iterator it = base.begin(); it != base.end(); ++it)
	    it->index.clear();
      sampled[op.id->path().name.front().name.str()] = base;
}

/* Preserve a parameter-sized whole array until instance elaboration while
   still applying ordinary Preponed rewriting to a sampled call's gating
   expression.  The value argument itself is captured word-by-word later;
   wrapping the aggregate in $ivl_clocking_sample would lose its array type. */
static PExpr* sva_preserve_uarray_operand_(
      PExpr*e, const sva_uarray_operand_t&op,
      std::map<std::string, pform_name_t>&sampled,
      unsigned&live_operands,
      const std::map<perm_string,unsigned>*unsampled_locals)
{
      sva_note_uarray_sampled_(op, sampled);
      if (!op.outer) return sva_clone_expr_(op.id);

      const std::vector<named_pexpr_t>&src = op.outer->get_parms();
      std::list<named_pexpr_t>args;
      for (size_t k = 0 ; k < src.size() ; k += 1) {
	    named_pexpr_t arg;
	    arg.name = src[k].name;
	    if (src[k].parm) {
		  if (k == 0 || k == 1)
			arg.parm = sva_clone_expr_(src[k].parm);
		  else
			arg.parm = sva_wrap_preponed_(src[k].parm, sampled,
						 live_operands,
						 unsampled_locals);
		  if (!arg.parm) return nullptr;
	    }
	    args.push_back(arg);
      }
      PECallFunction*copy = new PECallFunction(op.outer->path().name, args);
      copy->set_line(*e);
      sampled_pending_drop_(op.outer);
      return copy;
}

/*
 * M6B-4 — Preponed sampling for concurrent assertions.
 *
 * IEEE 1800-2017 16.5.1: a concurrent assertion evaluates its operands
 * against the values they held in the PREPONED region, i.e. before any
 * update made in the current time slot. The synthesized checker is an
 * ordinary `always @(clk)' process, so reading an operand directly gave
 * the ACTIVE-region value instead: a blocking write in the same time
 * slot as the clock edge was visible to the assertion, and the verdict
 * flipped. There was no diagnostic -- just a wrong pass or fail.
 *
 *   #5 a = 1;      // Active
 *      clk = 1;    // posedge in the same slot
 *   assert property (@(posedge clk) a |-> b);
 *
 * Preponed `a' is 0, so the attempt is vacuous. Icarus saw a==1 and
 * reported a failure. (Operands written by NBA happened to be right,
 * but only because NBA updates land after edge detection -- not
 * because anything sampled.)
 *
 * The runtime already carries the machinery, built for clocking-block
 * `#1step' inputs (14.13): $ivl_clocking_hist_on(sig) turns on a 1-deep
 * driven-value history for a signal, and $ivl_clocking_sample(sig)
 * lowers to %load/preponed, which returns the value the signal held
 * when the current time step began. So the fix is a source-level
 * rewrite in the checker the SVA lowering already synthesizes: wrap
 * each operand read, and emit the matching history-enable in the
 * checker's initial block.
 *
 * Wrapping is applied to a signal read as a WHOLE (`a', `vec') and to a
 * bit- or part-select of one (`vec[3]', `vec[7:4]'). %load/preponed reads
 * a whole signal, so a select is lowered in elaboration as the select
 * applied to the sampled whole signal (see $ivl_clocking_sample in
 * elab_expr.cc) -- the operand a select cannot be sampled from, such as an
 * unpacked-array word or a real, is warned about there rather than skipped
 * here.
 *
 * A HIERARCHICAL name (`u.q', `u.q[3]') is sampled too: the history enable
 * is a system task taking the signal, so a hierarchical reference in the
 * checker's own initial block reaches the other scope's signal perfectly
 * well. Only a PACKAGE-qualified name stays live, and any expression shape
 * this copier cannot clone (which makes the caller keep the original, live
 * expression). Both are counted into `live_operands' so the caller can say
 * so: a live read where a sampled one was asked for is a wrong verdict, and
 * must not be silent.
 *
 * Returns a fresh tree (the input is borrowed and never mutated), or
 * nullptr for a shape this cannot copy -- the caller then keeps the
 * original expression, reading live.
 */
static PExpr* sva_wrap_preponed_(PExpr*e,
				 std::map<std::string, pform_name_t>&sampled,
				 unsigned&live_operands,
				 const std::map<perm_string,unsigned>*unsampled_locals)
{
      if (!e) return nullptr;

      if (PEIdent*id = dynamic_cast<PEIdent*>(e)) {
	      /* A sequence local is per assertion attempt, not a design signal.
		 The NFA caller replaces this fresh bare identifier with the
		 corresponding slot register after the rest of the expression has
		 been Preponed-wrapped. Sampling the local itself would read the
		 register's value from before a same-tick sequence match assignment. */
	    if (unsampled_locals && !id->path().package
		&& id->path().name.size() == 1
		&& id->path().name.front().index.empty()
		&& unsampled_locals->count(id->path().name.front().name)) {
		  PEIdent*cp = new PEIdent(id->path().name, id->lexical_pos());
		  cp->reloc_lexical_pos_bind(false);
		  cp->set_line(*e);
		  return cp;
	    }
	      /* Parameters, localparams, and enum literals are constants, not
		 sampled design objects. In particular a package-qualified enum
		 used to be counted as an unsampled live operand even though its
		 value cannot change. A parameter array selected by a live index
		 is subtler: retain the constant base and sample only expressions
		 inside its selects. Sampling the aggregate parameter is both
		 meaningless and illegal for an unpacked array. */
	    if (pform_sva_ident_base_is_constant_(id)) {
		  pform_name_t path = id->path().name;
		  if (!sva_wrap_name_indices_(id->path().name, path, sampled,
					      live_operands, unsampled_locals))
			return nullptr;
		  PEIdent*cp = id->path().package
			? new PEIdent(id->path().package, path,
				      id->lexical_pos())
			: new PEIdent(path, id->lexical_pos());
		    /* The checker is a compiler-generated module process and can
		       be emitted before a later module-item declaration. Resolve
		       its cloned operand against the completed module scope. */
		  cp->reloc_lexical_pos_bind(false);
		  cp->set_line(*e);
		  return cp;
	    }

	    pform_name_t path = id->path().name;
	    if (!sva_wrap_name_indices_(id->path().name, path, sampled,
					live_operands, unsampled_locals))
		  return nullptr;
	    PEIdent*cp = id->path().package
		  ? new PEIdent(id->path().package, path, id->lexical_pos())
		  : new PEIdent(path, id->lexical_pos());
	    cp->reloc_lexical_pos_bind(false);
	    cp->set_line(*e);

	      /* A bare single-name read is sampled whether or not it
		 carries a select; elaboration lowers a select as the select
		 of the sampled whole signal. A package- or hierarchy-
		 qualified name stays a live read. */
	    if (id->path().package || id->path().name.empty()) {
		  live_operands += 1;
		  return cp;
	    }

	      /* The history-enable target is the WHOLE signal, so strip any
		 select off the path; `u.q[3]' enables history on `u.q'. */
	    pform_name_t base = id->path().name;
	    std::string key;
	    pform_name_t::iterator indexed_base = base.end();
	    for (pform_name_t::iterator it = base.begin(); it != base.end(); ++it) {
		  name_component_t&comp = *it;
		  if (!comp.index.empty() && indexed_base == base.end())
			indexed_base = it;
		  comp.index.clear();
		  if (!key.empty()) key += ".";
		  key += comp.name.str();
	    }
	      /* In `packed_array[i].member', everything after the selected
	         component is a member path, not hierarchy. History belongs to
	         the whole packed_array signal. For `u.vec[i]' the indexed
	         component is last, so the hierarchical prefix is preserved. */
	    if (indexed_base != base.end()) {
		  pform_name_t::iterator after = indexed_base;
		  ++after;
		  base.erase(after, base.end());
	    }

	    std::list<named_pexpr_t> parms;
	    named_pexpr_t a0;
	    a0.parm = cp;
	    parms.push_back(a0);
	    PECallFunction*smp = new PECallFunction(
		  lex_strings.make("$ivl_clocking_sample"), parms);
	    smp->set_line(*e);
	    sampled[key] = base;
	    return smp;
      }

      if (PENumber*num = dynamic_cast<PENumber*>(e)) {
	    PENumber*cp = new PENumber(new verinum(num->value()));
	    cp->set_line(*e);
	    return cp;
      }
	/* A real literal is as constant as an integer one; without this the
	   whole guard fell back to a live read for something as ordinary as
	   `r > 1.0'. */
      if (PEFNumber*fnum = dynamic_cast<PEFNumber*>(e)) {
	    PEFNumber*cp = new PEFNumber(new verireal(fnum->value()));
	    cp->set_line(*e);
	    return cp;
      }
      if (PEString*str = dynamic_cast<PEString*>(e)) {
	    PEString*cp = new PEString(strdup(str->value().c_str()));
	    cp->set_line(*e);
	    return cp;
      }
      if (PEUnary*un = dynamic_cast<PEUnary*>(e)) {
	    PExpr*sub = sva_wrap_preponed_(un->get_expr(), sampled,
					     live_operands, unsampled_locals);
	    if (!sub) return nullptr;
	    PEUnary*cp = new PEUnary(un->get_op(), sub);
	    cp->set_line(*e);
	    return cp;
      }
      if (PEBinary*bin = dynamic_cast<PEBinary*>(e)) {
	    /* Equality on fixed unpacked arrays is element-wise (7.4.1).
	       Expand before sampling so `$past(array)' becomes one sampled
	       history per element rather than an illegal scalar capture. */
	    if (dynamic_cast<PEBComp*>(e)
		&& (bin->get_op() == 'e' || bin->get_op() == 'E'
		    || bin->get_op() == 'w' || bin->get_op() == 'n'
		    || bin->get_op() == 'N' || bin->get_op() == 'W')) {
		  sva_uarray_operand_t left_array, right_array;
		  bool have_arrays = sva_uarray_operand_(bin->get_left(), left_array)
			&& sva_uarray_operand_(bin->get_right(), right_array)
			&& sva_uarray_value_operand_(left_array)
			&& sva_uarray_value_operand_(right_array);
		  /* A parse-time expansion is valid only when both bounds are
		     invariant across every module instance.  Otherwise preserve
		     the aggregate shape; sva_rewrite_sampled_ creates symbolic
		     snapshot/history arrays and the ordinary whole-array
		     elaborator expands the comparison using the actual instance
		     ranges. */
		  if (have_arrays
		      && (sva_uarray_bound_is_overridable_(left_array)
			  || sva_uarray_bound_is_overridable_(right_array))) {
			PExpr*l = sva_preserve_uarray_operand_(
			      bin->get_left(), left_array, sampled, live_operands,
			      unsampled_locals);
			PExpr*r = sva_preserve_uarray_operand_(
			      bin->get_right(), right_array, sampled, live_operands,
			      unsampled_locals);
			if (!l || !r) { delete l; delete r; return nullptr; }
			PEBComp*copy = new PEBComp(bin->get_op(), l, r);
			copy->set_line(*e);
			return copy;
		  }
		  std::vector<PExpr*>left_items, right_items;
		  if (sva_expand_uarray_operand_(bin->get_left(), left_items)
		      && sva_expand_uarray_operand_(bin->get_right(), right_items)
		      && left_items.size() == right_items.size()
		      && !left_items.empty()) {
			PExpr*res = nullptr;
			bool equal_op = bin->get_op() == 'e' || bin->get_op() == 'E'
				     || bin->get_op() == 'w';
			for (size_t k = 0 ; k < left_items.size() ; k += 1) {
			      PExpr*l = sva_wrap_preponed_(left_items[k], sampled,
							 live_operands,
							 unsampled_locals);
			      PExpr*r = sva_wrap_preponed_(right_items[k], sampled,
							 live_operands,
							 unsampled_locals);
			      if (!l || !r) return nullptr;
			      PEBComp*cmp = new PEBComp(bin->get_op(), l, r);
			      cmp->set_line(*e);
			      if (!res) res = cmp;
			      else {
				    PEBLogic*join = new PEBLogic(equal_op ? 'a' : 'o',
							      res, cmp);
				    join->set_line(*e);
				    res = join;
			      }
			}
			return res;
		  }
	    }
	    PExpr*l = sva_wrap_preponed_(bin->get_left(), sampled,
					 live_operands, unsampled_locals);
	    PExpr*r = sva_wrap_preponed_(bin->get_right(), sampled,
					 live_operands, unsampled_locals);
	    if (!l || !r) { delete l; delete r; return nullptr; }
	    PEBinary*cp;
	    if (dynamic_cast<PEBComp*>(e))
		  cp = new PEBComp(bin->get_op(), l, r);
	    else if (dynamic_cast<PEBLogic*>(e))
		  cp = new PEBLogic(bin->get_op(), l, r);
	    else if (dynamic_cast<PEBPower*>(e))
		  cp = new PEBPower(bin->get_op(), l, r);
	    else if (dynamic_cast<PEBShift*>(e))
		  cp = new PEBShift(bin->get_op(), l, r);
	    else if (typeid(*e) == typeid(PEBinary))
		  cp = new PEBinary(bin->get_op(), l, r);
	    else { delete l; delete r; return nullptr; }
	    cp->set_line(*e);
	    return cp;
      }
      if (PETernary*ter = dynamic_cast<PETernary*>(e)) {
	    PExpr*c = sva_wrap_preponed_(ter->get_cond(), sampled,
					 live_operands, unsampled_locals);
	    PExpr*t = sva_wrap_preponed_(ter->get_true(), sampled,
					 live_operands, unsampled_locals);
	    PExpr*f = sva_wrap_preponed_(ter->get_false(), sampled,
					 live_operands, unsampled_locals);
	    if (!c || !t || !f) { delete c; delete t; delete f; return nullptr; }
	    PETernary*cp = new PETernary(c, t, f);
	    cp->set_line(*e);
	    return cp;
      }
      if (PEInside*inside = dynamic_cast<PEInside*>(e)) {
	    PExpr*base = sva_wrap_preponed_(inside->get_expr(), sampled,
					     live_operands,
					     unsampled_locals);
	    if (!base) return nullptr;
	    std::list<inside_range_t>*ranges = new std::list<inside_range_t>;
	    const std::vector<inside_range_t>&src = inside->get_ranges();
	    for (size_t k = 0 ; k < src.size() ; k += 1) {
		  inside_range_t dst;
		  dst.lo = src[k].lo
			? sva_wrap_preponed_(src[k].lo, sampled, live_operands,
					       unsampled_locals)
			: nullptr;
		  dst.hi = src[k].hi
			? sva_wrap_preponed_(src[k].hi, sampled, live_operands,
					       unsampled_locals)
			: nullptr;
		  dst.weight = src[k].weight
			? sva_wrap_preponed_(src[k].weight, sampled, live_operands,
					       unsampled_locals)
			: nullptr;
		  dst.is_range = src[k].is_range;
		  dst.weight_is_divided = src[k].weight_is_divided;
		  if ((src[k].lo && !dst.lo) || (src[k].hi && !dst.hi)
		      || (src[k].weight && !dst.weight)) {
			delete dst.lo;
			delete dst.hi;
			delete dst.weight;
			delete base;
			for (std::list<inside_range_t>::iterator it = ranges->begin()
			     ; it != ranges->end() ; ++it) {
			      delete it->lo;
			      delete it->hi;
			      delete it->weight;
			}
			delete ranges;
			return nullptr;
		  }
		  ranges->push_back(dst);
	    }
	    PEInside*cp = new PEInside(base, ranges, inside->is_dist());
	    cp->set_line(*e);
	    return cp;
      }
	/* A cast does not create a separately sampled object: recurse into
	   its value operand and rebuild the exact cast around that sample.
	   Size expressions are constant contexts and must not be wrapped. */
      if (PECastSize*cast = dynamic_cast<PECastSize*>(e)) {
	    PExpr*size = sva_clone_expr_(cast->cast_size());
	    PExpr*base = sva_wrap_preponed_(cast->cast_base(), sampled,
					   live_operands,
					   unsampled_locals);
	    if (!size || !base) { delete size; delete base; return nullptr; }
	    PECastSize*cp = new PECastSize(size, base);
	    cp->set_line(*e);
	    return cp;
      }
      if (PECastType*cast = dynamic_cast<PECastType*>(e)) {
	    PExpr*base = sva_wrap_preponed_(cast->cast_base(), sampled,
					   live_operands,
					   unsampled_locals);
	    if (!base) return nullptr;
	    PECastType*cp = new PECastType(cast->cast_target(), base);
	    cp->set_line(*e);
	    return cp;
      }
      if (PECastSign*cast = dynamic_cast<PECastSign*>(e)) {
	    PExpr*base = sva_wrap_preponed_(cast->cast_base(), sampled,
					   live_operands,
					   unsampled_locals);
	    if (!base) return nullptr;
	    PECastSign*cp = new PECastSign(cast->has_sign(), base);
	    cp->set_line(*e);
	    return cp;
      }
      if (PEConcat*cat = dynamic_cast<PEConcat*>(e)) {
	    std::list<PExpr*> parms;
	    for (std::vector<PExpr*>::const_iterator it =
		       cat->stream_parms().begin()
		 ; it != cat->stream_parms().end() ; ++it) {
		  PExpr*part = sva_wrap_preponed_(*it, sampled, live_operands,
						unsampled_locals);
		  if (!part) {
			for (std::list<PExpr*>::iterator jt = parms.begin()
			     ; jt != parms.end() ; ++jt) delete *jt;
			return nullptr;
		  }
		  parms.push_back(part);
	    }
	    PExpr*repeat = cat->has_repeat()
		  ? sva_clone_expr_(cat->repeat_expr()) : nullptr;
	    if (cat->has_repeat() && !repeat) {
		  for (std::list<PExpr*>::iterator jt = parms.begin()
		       ; jt != parms.end() ; ++jt) delete *jt;
		  return nullptr;
	    }
	    PEConcat*cp = new PEConcat(parms, repeat);
	    cp->set_line(*e);
	    return cp;
      }
	/* Sampled-value functions ($past/$rose/…) are rewritten to history
	   chains after this pass; sampling their arguments here means the
	   history captures preponed values too, which is what 16.9.3
	   requires. */
      if (PECallFunction*cf = dynamic_cast<PECallFunction*>(e)) {
	      /* A whole fixed unpacked array is not a scalar function
		 argument, but $stable/$changed are well-defined over its value.
		 Lower to per-element sampled functions: all words must be
		 stable, while any changed word changes the aggregate. */
	    if (!cf->path().package && cf->path().name.size() == 1) {
		  const char*sample_name =
			peek_tail_name(cf->path().name).str();
		  bool stable_array = !strcmp(sample_name, "$stable");
		  bool changed_array = !strcmp(sample_name, "$changed");
		  if (stable_array || changed_array) {
			sva_uarray_operand_t array;
			if (sva_uarray_operand_(cf, array)
			    && sva_uarray_bound_is_overridable_(array))
			      return sva_preserve_uarray_operand_(
				    cf, array, sampled, live_operands,
				    unsampled_locals);
			std::vector<PExpr*>items;
			if (sva_expand_uarray_operand_(cf, items)
			    && !items.empty()) {
			      PExpr*result = nullptr;
			      for (size_t k = 0 ; k < items.size() ; k += 1) {
				    PExpr*word = sva_wrap_preponed_(
					  items[k], sampled, live_operands,
					  unsampled_locals);
				    if (!word) return nullptr;
				    if (!result) result = word;
				    else {
					  PEBLogic*join = new PEBLogic(
						stable_array ? 'a' : 'o',
						result, word);
					  join->set_line(*e);
					  result = join;
				    }
			      }
			      return result;
			}
		  }
	    }
	    if (PExpr*done = cf->sampled_subst())
		  return sva_clone_expr_(done);
	    if (cf->receiver_expr()) return nullptr;
	    bool sampled_call = !cf->path().package
		  && cf->path().name.size() == 1
		  && pform_is_sampled_value_function(
		  peek_tail_name(cf->path().name).str());
	    const std::vector<named_pexpr_t>&parms = cf->get_parms();
	    std::list<named_pexpr_t> np;
	    for (size_t k = 0 ; k < parms.size() ; k += 1) {
		  named_pexpr_t a;
		  a.name = parms[k].name;
		  if (parms[k].parm) {
			/* $past's number_of_ticks is a constant context, not a
			   sampled operand. Wrapping it in $ivl_clocking_sample
			   destroys constant-expression identity (AES uses a
			   localparam arithmetic expression here). */
			a.parm = (sampled_call && k == 1)
			      ? sva_clone_expr_(parms[k].parm)
			      : sva_wrap_preponed_(parms[k].parm, sampled,
						    live_operands,
						    unsampled_locals);
			if (!a.parm) return nullptr;
		  }
		  np.push_back(a);
	    }
	    PECallFunction*cp = cf->path().package
		  ? new PECallFunction(cf->path().package, cf->path().name, np)
		  : new PECallFunction(cf->path().name, np);
	    if (cf->leading_type_args()) {
		  parmvalue_t*type_args = sva_clone_parmvalue_(
			cf->leading_type_args(), nullptr);
		  if (!type_args) { delete cp; return nullptr; }
		  cp->set_leading_type_args(type_args);
	    }
	    std::vector<PExpr*> with;
	    for (PExpr*source : cf->with_constraints()) {
		  PExpr*item = sva_wrap_preponed_(source, sampled,
					     live_operands, unsampled_locals);
		  if (!item) {
			for (PExpr*prior : with) delete prior;
			delete cp;
			return nullptr;
		  }
		  with.push_back(item);
	    }
	    cp->set_with_constraints(std::move(with));
	    if (cf->has_randomize_with_identifier_list())
		  cp->set_randomize_with_identifiers(
			cf->randomize_with_identifiers());
	    cp->set_scoped_type_prefix(cf->has_scoped_type_prefix());
	    cp->set_line(*e);
	    if (sampled_call)
		  sampled_pending_drop_(cf);
	    return cp;
      }
      return nullptr;
}

/* Build `$ivl_clocking_hist_on(sig);' — turns on the 1-deep driven-value
   history %load/preponed reads. Emitted once per sampled signal into the
   checker's initial block. */
/* R2: suspend the checker until the OBSERVED region of this time slot
 * (IEEE 1800-2017 4.4.2.4). A concurrent assertion is evaluated there, after
 * every NBA update of the step has settled -- not in Active, where the
 * checker's `always @(clk)' would otherwise run interleaved with the design
 * it is judging. Sampled operands are unaffected: %load/preponed reads the
 * value the signal held when the step began, whenever the read happens.
 *
 * The runtime already had the region and the opcode (schedule_at_observed /
 * %wait/observed), built for clocking blocks with numeric input skew; this
 * points the assertion engines at them.
 */
static Statement* sva_observed_wait_(const struct vlltype&loc)
{
      std::list<named_pexpr_t> no_args;
      PCallTask*t = new PCallTask(
	    lex_strings.make("$ivl_observed_wait"), no_args);
      FILE_NAME(t, loc);
      return t;
}

/* R2: defer an assertion ACTION block to the Reactive region of the
 * current time slot (IEEE 1800-2017 4.4.2.5), one region after the
 * Observed region the verdict was computed in.  The action therefore
 * reads the settled design state of the step it is judging, and a
 * testbench process it wakes runs in the region the LRM puts testbench
 * code in.
 *
 * The wait is emitted INSIDE the per-tick dispatch guard, so a checker
 * only suspends on a tick that actually has something to report; a
 * silent tick runs straight through and is back at its clock event
 * before the Observed region ends.
 *
 * `%wait/reactive' runs inline (no suspension) once the run loop can no
 * longer reach a Reactive region -- inside the synthesized `final'
 * block that reports an unfulfilled strong obligation, or during the
 * Postponed region.  That is what makes this deferral safe: the earlier
 * attempt at R2 dropped exactly those verdicts.
 */
static Statement* sva_reactive_wait_(const struct vlltype&loc)
{
      std::list<named_pexpr_t> no_args;
      PCallTask*t = new PCallTask(
	    lex_strings.make("$ivl_reactive_wait"), no_args);
      FILE_NAME(t, loc);
      return t;
}

/* Mark a dedicated assertion-action dispatcher as a Reactive-region
   process. Unlike the checker itself, this process does no sampling or
   verdict evaluation: every event wake, delay continuation, event wait,
   and forked action child must remain in the Reactive region set. */
static Statement* sva_reactive_process_(const struct vlltype&loc)
{
      std::list<named_pexpr_t> no_args;
      PCallTask*t = new PCallTask(
	    lex_strings.make("$ivl_reactive_process"), no_args);
      FILE_NAME(t, loc);
      return t;
}

static Statement* sva_hist_on_stmt_(const struct vlltype&loc,
				    const pform_name_t&path)
{
      std::list<named_pexpr_t> args;
      named_pexpr_t a0;
      a0.parm = new PEIdent(path, loc.lexical_pos);
      FILE_NAME(a0.parm, loc);
	/* Assertion checkers are synthesized while their source module is
	   still being parsed. Permit this bookkeeping reference to bind a
	   module-scope signal declared after the assertion item. */
      a0.parm->reloc_lexical_pos_bind();
	// Compiler-generated bookkeeping reference. It shadows a name the
	// user already wrote in the assertion, so if the name does not
	// bind, THAT reference reports it -- this one must stay silent.
	// Without this the same undefined name produced a contradictory
	// pair: one error and one compile-progress warning.
      if (PEIdent*hid = dynamic_cast<PEIdent*>(a0.parm))
	    hid->set_quiet_bind();
      args.push_back(a0);
      PCallTask*t = new PCallTask(
	    lex_strings.make("$ivl_clocking_hist_on"), args);
      FILE_NAME(t, loc);
      return t;
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
	    st.match_calls.clear();
	    st.expr = sva_clone_subst_((*decl.body)[k].expr, &subst);
	    st.lv_rhs = (*decl.body)[k].lv_rhs
		? sva_clone_subst_((*decl.body)[k].lv_rhs, &subst) : nullptr;
	    st.delay_lo_expr = (*decl.body)[k].delay_lo_expr
		? sva_clone_subst_((*decl.body)[k].delay_lo_expr, &subst) : nullptr;
	    st.delay_hi_expr = (*decl.body)[k].delay_hi_expr
		? sva_clone_subst_((*decl.body)[k].delay_hi_expr, &subst) : nullptr;
	    st.rep_lo_expr = (*decl.body)[k].rep_lo_expr
		? sva_clone_subst_((*decl.body)[k].rep_lo_expr, &subst) : nullptr;
	    st.rep_hi_expr = (*decl.body)[k].rep_hi_expr
		? sva_clone_subst_((*decl.body)[k].rep_hi_expr, &subst) : nullptr;
	    bool calls_ok = sva_clone_match_calls_(
		  (*decl.body)[k].match_calls, st.match_calls, &subst);
	    if (!st.expr || ((*decl.body)[k].lv_rhs && !st.lv_rhs)
		|| ((*decl.body)[k].delay_lo_expr && !st.delay_lo_expr)
		|| ((*decl.body)[k].delay_hi_expr && !st.delay_hi_expr)
		|| ((*decl.body)[k].rep_lo_expr && !st.rep_lo_expr)
		|| ((*decl.body)[k].rep_hi_expr && !st.rep_hi_expr)
		|| !calls_ok) {
		  cerr << loc << ": sorry: sequence `" << nm << "' has a body "
		       << "expression that cannot be instantiated with "
		       << "arguments; the assertion is dropped." << endl;
		  error_count += 1;
		  delete st.expr;
		  delete st.lv_rhs;
		  delete st.delay_lo_expr;
		  delete st.delay_hi_expr;
		  delete st.rep_lo_expr;
		  delete st.rep_hi_expr;
		  sva_destroy_match_calls_(st.match_calls);
		  pform_sva_destroy_sequence(out);
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
	    st.match_calls.clear();
	    st.expr = sva_clone_subst_((*in)[k].expr, &subst);
	    st.lv_rhs = (*in)[k].lv_rhs
		? sva_clone_subst_((*in)[k].lv_rhs, &subst) : nullptr;
	    st.delay_lo_expr = (*in)[k].delay_lo_expr
		? sva_clone_subst_((*in)[k].delay_lo_expr, &subst) : nullptr;
	    st.delay_hi_expr = (*in)[k].delay_hi_expr
		? sva_clone_subst_((*in)[k].delay_hi_expr, &subst) : nullptr;
	    st.rep_lo_expr = (*in)[k].rep_lo_expr
		? sva_clone_subst_((*in)[k].rep_lo_expr, &subst) : nullptr;
	    st.rep_hi_expr = (*in)[k].rep_hi_expr
		? sva_clone_subst_((*in)[k].rep_hi_expr, &subst) : nullptr;
	    bool calls_ok = sva_clone_match_calls_(
		  (*in)[k].match_calls, st.match_calls, &subst);
	    if (!st.expr || ((*in)[k].lv_rhs && !st.lv_rhs)
		|| ((*in)[k].delay_lo_expr && !st.delay_lo_expr)
		|| ((*in)[k].delay_hi_expr && !st.delay_hi_expr)
		|| ((*in)[k].rep_lo_expr && !st.rep_lo_expr)
		|| ((*in)[k].rep_hi_expr && !st.rep_hi_expr)
		|| !calls_ok) {
		  delete st.expr;
		  delete st.lv_rhs;
		  delete st.delay_lo_expr;
		  delete st.delay_hi_expr;
		  delete st.rep_lo_expr;
		  delete st.rep_hi_expr;
		  sva_destroy_match_calls_(st.match_calls);
		  pform_sva_destroy_sequence(out);
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

/* Compiler-generated word/bit select `name[index]'. The same helper is
   used for a packed obligation pipeline and for an unpacked sampled-value
   history ring; ordinary elaboration decides which kind of select it is
   from the declaration in the generated scope. */
static PEIdent* sva_index_(const struct vlltype&loc, perm_string name,
			   PExpr*index)
{
      pform_name_t path;
      name_component_t tail(name);
      index_component_t sel;
      sel.sel = index_component_t::SEL_BIT;
      sel.msb = index;
      tail.index.push_back(sel);
      path.push_back(tail);
      PEIdent*id = new PEIdent(path, loc.lexical_pos);
      FILE_NAME(id, loc);
      id->set_strict_bind();
      return id;
}

static PExpr* sva_bit_(const struct vlltype&loc, int v)
{
      verinum*n = new verinum(v ? verinum::V1 : verinum::V0, 1);
      PENumber*num = new PENumber(n);
      FILE_NAME(num, loc);
      return num;
}

static bool sva_data_type_signed_(const data_type_t*type)
{
      if (const vector_type_t*vec = dynamic_cast<const vector_type_t*>(type))
	    return vec->signed_flag;
      if (const atom_type_t*atom = dynamic_cast<const atom_type_t*>(type))
	    return atom->signed_flag;
      if (const enum_type_t*enm = dynamic_cast<const enum_type_t*>(type))
	    return sva_data_type_signed_(enm->base_type.get());
      if (const parray_type_t*arr = dynamic_cast<const parray_type_t*>(type))
	    return sva_data_type_signed_(arr->base_type.get());
      return false;
}

/* Infer the parse-time signedness needed by a synthesized sampled-value
   register. Width alone is insufficient: storing -2 in an unsigned history
   register makes `$past(s) < 0' false even though `s' is signed. This helper
   covers the self-determined integral shapes used during assertion lowering;
   elaboration still performs the ordinary width/type checks afterwards. */
static bool sva_expr_signed_(PExpr*expr)
{
      if (!expr) return false;
      if (PENumber*num = dynamic_cast<PENumber*>(expr))
	    return num->value().has_sign();
      if (PEIdent*id = dynamic_cast<PEIdent*>(expr)) {
	    if (!id->path().package && id->path().name.size() == 1) {
		  PWire*wire = pform_get_wire_in_scope(
			id->path().name.front().name);
		  if (wire)
			return wire->get_signed()
			    || sva_data_type_signed_(wire->data_type());
	    }
	    return false;
      }
      if (PECastSign*cast = dynamic_cast<PECastSign*>(expr))
	    return cast->has_sign();
      if (PECastSize*cast = dynamic_cast<PECastSize*>(expr))
	    return sva_expr_signed_(cast->cast_base());
      if (PECastType*cast = dynamic_cast<PECastType*>(expr))
	    return sva_data_type_signed_(cast->cast_target());
      if (dynamic_cast<PEConcat*>(expr)) return false;
      if (PEUnary*un = dynamic_cast<PEUnary*>(expr)) {
	    switch (un->get_op()) {
		case '!': case '&': case '|': case '^':
		case 'A': case 'N': case 'X': return false;
		default: return sva_expr_signed_(un->get_expr());
	    }
      }
      if (PEBinary*bin = dynamic_cast<PEBinary*>(expr)) {
	    if (dynamic_cast<PEBComp*>(expr)
		|| dynamic_cast<PEBLogic*>(expr)) return false;
	    if (dynamic_cast<PEBShift*>(expr))
		  return sva_expr_signed_(bin->get_left());
	    return sva_expr_signed_(bin->get_left())
		&& sva_expr_signed_(bin->get_right());
      }
      if (PETernary*ter = dynamic_cast<PETernary*>(expr))
	    return sva_expr_signed_(ter->get_true())
		&& sva_expr_signed_(ter->get_false());
      if (PECallFunction*call = dynamic_cast<PECallFunction*>(expr)) {
	    if (!call->path().package && call->path().name.size() == 1) {
		  const char*name = peek_tail_name(call->path().name).str();
		  if (!strcmp(name, "$signed")) return true;
		  if (!strcmp(name, "$unsigned")) return false;
		  if (!strcmp(name, "$ivl_clocking_sample")) {
			const std::vector<named_pexpr_t>&args = call->get_parms();
			return !args.empty() && sva_expr_signed_(args[0].parm);
		  }
	    }
      }
      return false;
}

/* Recover a sampled expression's nominal parse type when it can be named
   exactly. History registers store raw bits, but `$past(enum_value)' still
   has the enum type (16.9.3); without restoring it, passing that result to a
   function with an enum formal spuriously requires an explicit cast. */
static data_type_t* sva_expr_sample_type_(PExpr*expr)
{
      if (!expr) return nullptr;
      if (PECallFunction*call = dynamic_cast<PECallFunction*>(expr)) {
	    if (!call->path().package && call->path().name.size() == 1
		&& !strcmp(peek_tail_name(call->path().name).str(),
			   "$ivl_clocking_sample")) {
		  const std::vector<named_pexpr_t>&args = call->get_parms();
		  return args.empty() ? nullptr
			: sva_expr_sample_type_(args[0].parm);
	    }
	    return nullptr;
      }
      if (PECastType*cast = dynamic_cast<PECastType*>(expr))
	    return cast->cast_target();
      PEIdent*id = dynamic_cast<PEIdent*>(expr);
      if (!id || id->path().package || id->path().name.size() != 1)
	    return nullptr;
      PWire*wire = pform_get_wire_in_scope(id->path().name.front().name);
      if (!wire || !wire->data_type()) return nullptr;

      const std::list<index_component_t>&index_list =
	    id->path().name.front().index;
      std::vector<index_component_t>indices(index_list.begin(),
					     index_list.end());
      size_t unpacked = wire->unpacked_indices().size();
      if (indices.size() < unpacked) return nullptr;
      size_t packed_selects = indices.size() - unpacked;
      const data_type_t*type = wire->data_type();
      size_t pos = unpacked;
      while (packed_selects > 0) {
	    const parray_type_t*arr = dynamic_cast<const parray_type_t*>(type);
	    if (!arr || !arr->dims || arr->dims->empty()) return nullptr;
	    size_t dims = arr->dims->size();
	    if (packed_selects < dims) return nullptr;
	    for (size_t k = 0 ; k < dims ; k += 1)
		  if (indices[pos + k].sel != index_component_t::SEL_BIT)
			return nullptr;
	    pos += dims;
	    packed_selects -= dims;
	    type = arr->base_type.get();
      }
      return const_cast<data_type_t*>(type);
}

static perm_string sva_make_reg_(const struct vlltype&loc, unsigned inst,
				 const char*what, unsigned idx,
				 bool wide = false, bool as_real = false,
				 PExpr*width_from = nullptr,
				 bool signed_value = false)
{
      char buf[64];
      snprintf(buf, sizeof buf, "_ivl_sva%u_%s%u", inst, what, idx);
      perm_string name = lex_strings.make(buf);
      if (as_real) {
	      /* A real sample keeps its fraction: an integral history
		 would round it away with no diagnostic. */
	    std::list<decl_assignment_t*>*decls = new std::list<decl_assignment_t*>;
	    decl_assignment_t*decl = new decl_assignment_t;
	    decl->name = pform_ident_t(name, loc.lexical_pos);
	    decls->push_back(decl);
	    real_type_t*rtype = new real_type_t(real_type_t::REAL);
	    FILE_NAME(rtype, loc);
	    pform_make_var(loc, decls, rtype, nullptr, false);
	    return name;
      }
      PWire*w = pform_makewire(loc, pform_ident_t(name, loc.lexical_pos),
			       NetNet::REG, nullptr);
	/* A value-carrying sampled-value register has the exact packed width
	   of its operand. SystemVerilog sampled-value functions accept any
	   integral expression, including packed arrays wider than longint;
	   the former fixed 64-bit register silently truncated AES's 128-bit
	   state before an element-wise `$past(array)' comparison. Keep the
	   width expression symbolic as `$bits(operand)' so parameters and
	   typedefs are resolved in their normal elaboration context. Other
	   internal value registers that have no source expression retain the
	   established 64-bit size. Boolean state registers stay 1 bit. */
      if (wide && w) {
	    std::list<pform_range_t> range;
	    pform_range_t r;
	    if (width_from) {
		  std::list<named_pexpr_t> args;
		  named_pexpr_t arg;
		  arg.parm = sva_clone_expr_(width_from);
		  args.push_back(arg);
		  PECallFunction*bits = new PECallFunction(
			lex_strings.make("$bits"), args);
		  FILE_NAME(bits, loc);
		  PENumber*one = new PENumber(new verinum((uint64_t)1, 32));
		  FILE_NAME(one, loc);
		  r.first = new PEBinary('-', bits, one);
		  FILE_NAME(r.first, loc);
	    } else {
		  r.first = new PENumber(new verinum((uint64_t)63, 32));
	    }
	    r.second = new PENumber(new verinum((uint64_t)0, 32));
	    range.push_back(r);
	    w->set_range(range, SR_NET);
      }
      if (signed_value && w) w->set_signed(true);
      return name;
}

/* A one-bit packed pipeline [genvar:0]. Its width is intentionally left as
   a parse expression: PGenerate elaborates the same declaration separately
   in every generated scope, where the loop genvar is an implicit localparam
   with that instance's value. */
static perm_string sva_make_genvar_pipe_(const struct vlltype&loc,
					 unsigned inst, perm_string genvar)
{
      perm_string name = sva_make_reg_(loc, inst, "gpipe", 0);
      PWire*w = pform_get_wire_in_scope(name);
      if (w) {
	    std::list<pform_range_t> range;
	    pform_range_t r;
	    r.first = sva_id_(loc, genvar);
	    r.second = new PENumber(new verinum((uint64_t)0, 32));
	    FILE_NAME(r.second, loc);
	    range.push_back(r);
	    w->set_range(range, SR_NET);
      }
      return name;
}

/* Packed [top:0] Boolean age set whose top is an ordinary parse expression.
   Unlike sva_make_reg_(wide), this is not `$bits(source)' storage: `top' is
   the repetition count itself and is deliberately resolved by normal module
   elaboration after instance parameter overrides.  Takes ownership of top. */
static perm_string sva_make_parameter_pipe_(const struct vlltype&loc,
					     unsigned inst, PExpr*top,
					     const char*what = "rpipe")
{
      perm_string name = sva_make_reg_(loc, inst, what, 0);
      PWire*w = pform_get_wire_in_scope(name);
      if (w) {
	    std::list<pform_range_t> range;
	    pform_range_t r;
	    r.first = top;
	    r.second = new PENumber(new verinum((uint64_t)0, 32));
	    FILE_NAME(r.second, loc);
	    range.push_back(r);
	    w->set_range(range, SR_NET);
      } else {
	    delete top;
      }
      return name;
}

/* An unpacked [0:genvar-1] ring whose element width/type matches `arg'.
   This implements $past(arg, genvar) without fixing the history depth while
   the generate template is parsed. */
static perm_string sva_make_genvar_history_(const struct vlltype&loc,
					    unsigned inst,
					    unsigned&hist_idx,
					    PExpr*arg,
					    perm_string genvar,
					    bool signed_value)
{
      perm_string name = sva_make_reg_(loc, inst, "ghist", hist_idx++,
				       true, false, arg, signed_value);
      PWire*w = pform_get_wire_in_scope(name);
      if (w) {
	    std::list<pform_range_t> range;
	    pform_range_t r;
	    r.first = new PENumber(new verinum((uint64_t)0, 32));
	    FILE_NAME(r.first, loc);
	    PENumber*one = new PENumber(new verinum((uint64_t)1, 32));
	    FILE_NAME(one, loc);
	    r.second = new PEBinary('-', sva_id_(loc, genvar), one);
	    FILE_NAME(r.second, loc);
	    range.push_back(r);
	    w->set_unpacked_idx(range);
      }
      return name;
}

static Statement* sva_assign_(const struct vlltype&loc, perm_string lv, PExpr*rv)
{
      sva_mark_strict_(rv);
      PAssign*a = new PAssign(sva_id_(loc, lv), rv);
      FILE_NAME(a, loc);
      return a;
}

static Statement* sva_assign_index_(const struct vlltype&loc, perm_string lv,
				    PExpr*index, PExpr*rv,
				    bool nonblocking = false)
{
      sva_mark_strict_(rv);
      PEIdent*lval = sva_index_(loc, lv, index);
      Statement*a = nonblocking
	  ? static_cast<Statement*>(new PAssignNB(lval, rv))
	  : static_cast<Statement*>(new PAssign(lval, rv));
      FILE_NAME(a, loc);
      return a;
}

/* Nonblocking form (defined with the multiclock helpers below). A
   sampler that runs as its OWN process has to update its history under
   NBA: it shares a clock edge with the processes that read that
   history, and only an NBA update is guaranteed to land after every
   Active-region reader, so each reader sees the previous tick's sample
   no matter which process the scheduler runs first. */
static Statement* sva_assign_nb_(const struct vlltype&loc, perm_string lv,
				 PExpr*rv);

/*
 * Duplicate a user action block (IEEE 1800-2017 16.14.6).
 *
 * A property whose failure can be decided either DURING the run or only
 * at the end of it needs the user's statement at two sites: the
 * per-cycle dispatch in the checker's `always' process, and a `final'
 * block for an obligation that was still pending when time ran out.
 * A Statement can live at only one of them, so the second gets a copy.
 *
 * The unbounded-sequence lowering used to give the per-cycle site the
 * user's `else' and the end-of-simulation site a canned `$error', which
 * meant a strong sequence that never completed reported through a
 * message the user never wrote and their own else never ran.
 *
 * Only the shapes an action block can actually hold are duplicated --
 * a task or system-task call, an assignment, an if, a begin/end of
 * those, and an empty statement. Anything else returns null and the
 * caller says so out loud rather than quietly dropping it.
 */
static Statement* sva_clone_stmt_(Statement*st)
{
      if (!st) return nullptr;

      if (PCallTask*ct = dynamic_cast<PCallTask*> (st)) {
	      /* Receiver-method actions need a separately owned receiver
		 expression and remain outside this bounded copier. Do not turn one
		 into an unqualified call while duplicating an end-of-simulation
		 action. */
	    if (ct->receiver_expr() || ct->path().empty()) return nullptr;
	    std::list<named_pexpr_t> parms;
	    for (size_t i = 0 ; i < ct->parms().size() ; i += 1) {
		  named_pexpr_t np;
		  np.name = ct->parms()[i].name;
		  np.parm = sva_clone_expr_(ct->parms()[i].parm);
		  if (ct->parms()[i].parm && !np.parm) return nullptr;
		  parms.push_back(np);
	    }
	      /* Package qualification is part of the call target, not lookup
		 decoration. Dropping it changed pkg::report(...) into a lookup for
		 report in the synthesized checker scope; OpenTitan's strong
		 eventuality actions were consequently replaced by unknown-task
		 no-ops at end of simulation. */
	    PCallTask*out = ct->package()
		  ? new PCallTask(ct->package(), ct->path(), parms)
		  : new PCallTask(ct->path(), parms);
	    out->set_lineno(ct->get_lineno());
	    out->set_file(ct->get_file());
	    return out;
      }

      if (PAssignNB*an = dynamic_cast<PAssignNB*> (st)) {
	    PExpr*lv = sva_clone_expr_(const_cast<PExpr*>(an->lval()));
	    PExpr*rv = sva_clone_expr_(an->rval());
	    if (!lv || !rv) return nullptr;
	    PAssignNB*out = new PAssignNB(lv, rv);
	    out->set_lineno(an->get_lineno());
	    out->set_file(an->get_file());
	    return out;
      }

      if (PAssign*as = dynamic_cast<PAssign*> (st)) {
	    PExpr*lv = sva_clone_expr_(const_cast<PExpr*>(as->lval()));
	    PExpr*rv = sva_clone_expr_(as->rval());
	    if (!lv || !rv) return nullptr;
	    PAssign*out = as->op() ? new PAssign(lv, as->op(), rv)
				   : new PAssign(lv, rv);
	    out->set_lineno(as->get_lineno());
	    out->set_file(as->get_file());
	    return out;
      }

      if (PCondit*cd = dynamic_cast<PCondit*> (st)) {
	    PExpr*ce = sva_clone_expr_(cd->cond_expr());
	    if (!ce) return nullptr;
	    Statement*ic = nullptr;
	    Statement*ec = nullptr;
	    if (cd->if_clause()) {
		  ic = sva_clone_stmt_(cd->if_clause());
		  if (!ic) return nullptr;
	    }
	    if (cd->else_clause()) {
		  ec = sva_clone_stmt_(cd->else_clause());
		  if (!ec) return nullptr;
	    }
	    PCondit*out = new PCondit(ce, ic, ec);
	    if (cd->is_immediate_assertion())
		  out->immediate_assertion();
	    out->set_lineno(cd->get_lineno());
	    out->set_file(cd->get_file());
	    return out;
      }

      if (PBlock*bk = dynamic_cast<PBlock*> (st)) {
	      /* A NAMED block is a scope; duplicating it would duplicate
		 the scope with it. Only the anonymous sequential form is
		 safe to copy. */
	    if (bk->bl_type() != PBlock::BL_SEQ) return nullptr;
	    if (bk->pscope_name() != perm_string()) return nullptr;
	    std::vector<Statement*> out_list;
	    for (size_t i = 0 ; i < bk->statements().size() ; i += 1) {
		  Statement*c = sva_clone_stmt_(bk->statements()[i]);
		  if (!c) return nullptr;
		  out_list.push_back(c);
	    }
	    PBlock*out = new PBlock(PBlock::BL_SEQ);
	    out->set_statement(out_list);
	    out->set_lineno(bk->get_lineno());
	    out->set_file(bk->get_file());
	    return out;
      }

      if (dynamic_cast<PNoop*> (st))
	    return new PNoop;

      return nullptr;
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
      sva_mark_strict_(c);
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

/* Reduce a large Boolean term list as a balanced tree. Temporal windows can
   legally span thousands of cycles (OTBN uses 4000); a left-deep OR makes
   expression typing/evaluation quadratic and can exhaust the C++ stack. */
static PExpr* sva_logic_reduce_(const struct vlltype&loc, char op,
			       std::vector<PExpr*> terms)
{
      if (terms.empty()) return nullptr;
      while (terms.size() > 1) {
	    std::vector<PExpr*> next;
	    next.reserve((terms.size() + 1) / 2);
	    for (size_t idx = 0 ; idx < terms.size() ; idx += 2) {
		  if (idx + 1 < terms.size())
			next.push_back(sva_logic_(loc, op, terms[idx],
						 terms[idx+1]));
		  else
			next.push_back(terms[idx]);
	    }
	    terms.swap(next);
      }
      return terms.front();
}

static PExpr* sva_rewrite_sampled_(const struct vlltype&loc, PExpr*e,
				   unsigned inst, unsigned&hist_idx,
				   std::vector<Statement*>&pre,
				   std::vector<Statement*>&post,
				   std::vector<Statement*>&init,
				   bool cur_live);

static PECallFunction* sva_uarray_query_(const struct vlltype&loc,
					 const char*name, PEIdent*array)
{
      std::list<named_pexpr_t>args;
      named_pexpr_t arg;
      arg.parm = sva_clone_expr_(array);
      args.push_back(arg);
      PECallFunction*call = new PECallFunction(lex_strings.make(name), args);
      FILE_NAME(call, loc);
      return call;
}

/* Map a canonical left-to-right word number to the source array's declared
   index.  IEEE $increment is the right-to-left increment, hence the minus:
       declared_index = $left(a) - k * $increment(a).
   This handles ascending, descending, nonzero-based, and parameter-sized
   ranges without evaluating a declaration default in the parser. */
static PExpr* sva_uarray_declared_index_(const struct vlltype&loc,
					 PEIdent*array, perm_string counter)
{
      PExpr*mul = new PEBinary('*', sva_id_(loc, counter),
			       sva_uarray_query_(loc, "$increment", array));
      FILE_NAME(mul, loc);
      PExpr*index = new PEBinary('-',
				 sva_uarray_query_(loc, "$left", array), mul);
      FILE_NAME(index, loc);
      return index;
}

static PEIdent* sva_uarray_word_(const struct vlltype&loc, PEIdent*array,
				 PExpr*index)
{
      pform_name_t path = array->path().name;
      index_component_t select;
      select.sel = index_component_t::SEL_BIT;
      select.msb = index;
      path.front().index.push_back(select);
      PEIdent*word = new PEIdent(path, array->lexical_pos());
      word->reloc_lexical_pos_bind(false);
      word->set_line(*array);
      (void)loc;
      return word;
}

static PExpr* sva_uarray_preponed_word_(const struct vlltype&loc,
					PEIdent*array, PExpr*index)
{
      std::list<named_pexpr_t>args;
      named_pexpr_t arg;
      arg.parm = sva_uarray_word_(loc, array, index);
      args.push_back(arg);
      PECallFunction*sample = new PECallFunction(
	    lex_strings.make("$ivl_clocking_sample"), args);
      FILE_NAME(sample, loc);
      return sample;
}

static perm_string sva_make_uarray_reg_(const struct vlltype&loc,
					unsigned inst, unsigned&hist_idx,
					const char*what,
					const sva_uarray_operand_t&source)
{
      PExpr*probe = sva_uarray_word_(
	    loc, source.id, sva_uarray_query_(loc, "$left", source.id));
      bool signed_value = sva_expr_signed_(probe);
      perm_string name = sva_make_reg_(loc, inst, what, hist_idx++,
				       true, false, probe, signed_value);
      delete probe;

      PWire*wire = pform_get_wire_in_scope(name);
      if (!wire) return name;
      std::list<pform_range_t>dims;
      for (std::list<pform_range_t>::const_iterator it =
		 source.wire->unpacked_indices().begin()
	   ; it != source.wire->unpacked_indices().end() ; ++it) {
	    pform_range_t dim;
	    dim.first = sva_clone_expr_(it->first);
	    dim.second = it->second ? sva_clone_expr_(it->second) : nullptr;
	    dims.push_back(dim);
      }
      wire->set_unpacked_idx(dims);
      return name;
}

static perm_string sva_make_uarray_counter_(const struct vlltype&loc,
					    unsigned inst,
					    unsigned&hist_idx)
{
      perm_string name = sva_make_reg_(loc, inst, "uai", hist_idx++);
      PWire*wire = pform_get_wire_in_scope(name);
      if (wire)
	    wire->set_data_type(new atom_type_t(atom_type_t::INT, true));
      return name;
}

static Statement* sva_uarray_for_(const struct vlltype&loc,
				  PEIdent*array, perm_string counter,
				  Statement*body)
{
      PExpr*init = new PENumber(new verinum((uint64_t)0, 32));
      FILE_NAME(init, loc);
      PExpr*cond = new PEBComp('<', sva_id_(loc, counter),
			       sva_uarray_query_(loc, "$size", array));
      FILE_NAME(cond, loc);
      PExpr*one = new PENumber(new verinum((uint64_t)1, 32));
      FILE_NAME(one, loc);
      Statement*step = new PAssign(sva_id_(loc, counter), '+', one);
      FILE_NAME(step, loc);
      PForStatement*loop = new PForStatement(
	    sva_id_(loc, counter), init, cond, step, body);
      FILE_NAME(loop, loc);
      return loop;
}

/* Lower one symbolic whole-array sampled operand to an equally-shaped
   compiler-generated array.  All dimensions stay as parse expressions and
   are therefore resolved independently in every module instance. */
static PExpr* sva_rewrite_symbolic_uarray_operand_(
      const struct vlltype&loc, PExpr*e, const sva_uarray_operand_t&source,
      unsigned inst, unsigned&hist_idx, std::vector<Statement*>&pre,
      std::vector<Statement*>&post, std::vector<Statement*>&init,
      bool cur_live)
{
      const char*sample_name = source.outer
	    ? peek_tail_name(source.outer->path().name).str() : "$sampled";
      bool current_value = !strcmp(sample_name, "$sampled");
      bool past_value = !strcmp(sample_name, "$past");
      if (!current_value && !past_value) return nullptr;

      if (current_value) {
	    perm_string snapshot = sva_make_uarray_reg_(
		  loc, inst, hist_idx, "uacur", source);
	    perm_string counter = sva_make_uarray_counter_(
		  loc, inst, hist_idx);
	    PExpr*src_index = sva_uarray_declared_index_(
		  loc, source.id, counter);
	    PExpr*dst_index = sva_clone_expr_(src_index);
	    Statement*capture = sva_assign_index_(
		  loc, snapshot, dst_index,
		  sva_uarray_preponed_word_(loc, source.id, src_index),
		  cur_live);
	    pre.push_back(sva_uarray_for_(loc, source.id, counter, capture));
	    return sva_id_(loc, snapshot);
      }

      long depth = 1;
      const std::vector<named_pexpr_t>&args = source.outer->get_parms();
      if (args.size() > 1 && args[1].parm) {
	    if (pform_sva_overridable_bound(args[1].parm)
		|| !pform_sva_const_long(args[1].parm, depth)) {
		  cerr << loc << ": error: $past depth for a whole unpacked "
		       << "array must be an instance-invariant constant "
		       << "expression." << endl;
		  error_count += 1;
		  return nullptr;
	    }
	    if (depth < 1) {
		  cerr << loc << ": error: $past depth must be >= 1 (16.9.3); "
		       << "use $sampled() for the current sample." << endl;
		  error_count += 1;
		  return nullptr;
	    }
      }
      if (args.size() > 3 && args[3].parm) {
	    cerr << loc << ": sorry: an explicit clocking-event argument to "
		 << "$past is not supported here; it is ignored and the inferred "
		 << "clock is used." << endl;
      }

      std::vector<perm_string>history((size_t)depth);
      for (long k = 0 ; k < depth ; k += 1)
	    history[(size_t)k] = sva_make_uarray_reg_(
		  loc, inst, hist_idx, "uahist", source);

      perm_string init_counter = sva_make_uarray_counter_(
	    loc, inst, hist_idx);
      std::vector<Statement*>zero_body;
      for (long k = 0 ; k < depth ; k += 1)
	    zero_body.push_back(sva_assign_index_(
		  loc, history[(size_t)k],
		  sva_uarray_declared_index_(loc, source.id, init_counter),
		  sva_bit_(loc, 0)));
      init.push_back(sva_uarray_for_(
	    loc, source.id, init_counter, sva_block_(loc, zero_body)));

      perm_string shift_counter = sva_make_uarray_counter_(
	    loc, inst, hist_idx);
      std::vector<Statement*>shift_body;
      for (long k = depth - 1 ; k >= 1 ; k -= 1) {
	    PExpr*index = sva_uarray_declared_index_(
		  loc, source.id, shift_counter);
	    shift_body.push_back(sva_assign_index_(
		  loc, history[(size_t)k], sva_clone_expr_(index),
		  sva_index_(loc, history[(size_t)k-1], index), cur_live));
      }
      PExpr*src_index = sva_uarray_declared_index_(
	    loc, source.id, shift_counter);
      shift_body.push_back(sva_assign_index_(
	    loc, history[0], sva_clone_expr_(src_index),
	    sva_uarray_preponed_word_(loc, source.id, src_index), cur_live));
      Statement*shift = sva_uarray_for_(
	    loc, source.id, shift_counter, sva_block_(loc, shift_body));

      if (args.size() > 2 && args[2].parm) {
	    PExpr*gate_src = sva_clone_expr_(args[2].parm);
	    PExpr*gate = sva_rewrite_sampled_(loc, gate_src, inst, hist_idx,
					 pre, post, init, cur_live);
	    if (!gate) return nullptr;
	    shift = sva_if_(loc, gate, shift, nullptr);
      }
      post.push_back(shift);
      (void)e;
      return sva_id_(loc, history.back());
}

/* M12/20.12: query global immediate-assertion state (no argument), or the
   state of one synthesized concurrent assertion (instance argument). */
static PExpr* sva_enabled_expr_(const struct vlltype&loc, long inst)
{
      std::list<named_pexpr_t> parms;
      if (inst >= 0) {
	    named_pexpr_t arg;
	    arg.parm = new PENumber(new verinum((uint64_t)inst, 32));
	    parms.push_back(arg);
      }
      PECallFunction*en = new PECallFunction(
	    perm_string::literal("$ivl_sva_enabled"), parms);
      FILE_NAME(en, loc);

      /* The VPI function has a 32-bit return ABI, but every consumer uses it
	 as a Boolean.  Normalize it here so inserting the enable term into an
	 instance-sized token expression cannot widen that expression and retain
	 bits which the checker deliberately shifts out of its state vector. */
      return sva_not_(loc, sva_not_(loc, en));
}

/* Runtime assertion control keeps a kill generation per (scope, checker).
   Each generated checker process retains the generation it has already
   applied.  This is deliberately not a consumable pulse: the independent
   processes of a multiclock checker must all observe the same kill. */
static PExpr* sva_kill_generation_expr_(const struct vlltype&loc,
					 unsigned inst)
{
      std::list<named_pexpr_t> parms;
      named_pexpr_t arg;
      arg.parm = new PENumber(new verinum((uint64_t)inst, 32));
      parms.push_back(arg);
      PECallFunction*gen = new PECallFunction(
	    perm_string::literal("$ivl_sva_kill_generation"), parms);
      FILE_NAME(gen, loc);
      return gen;
}

static perm_string sva_kill_seen_reg_(const struct vlltype&loc,
				      unsigned inst, unsigned process_idx,
				      std::vector<Statement*>&init)
{
      perm_string seen = sva_make_reg_(loc, inst, "kill", process_idx, true);
      init.push_back(sva_assign_(loc, seen,
	    new PENumber(new verinum((uint64_t)0, 64))));
      return seen;
}

/* Take ownership of `clear'. A generation change first clears every piece of
   active-attempt state, then acknowledges that generation. The caller places
   this after its Observed wait (when it has one) and before advancing or
   injecting attempts, so `$assertkill; $asserton' in one time slot aborts old
   attempts while allowing a fresh attempt at the next sampled clock. */
static Statement* sva_kill_reset_stmt_(const struct vlltype&loc,
				       unsigned inst, perm_string seen,
				       Statement*clear)
{
      PEBComp*changed = new PEBComp('N',
	    sva_kill_generation_expr_(loc, inst), sva_id_(loc, seen));
      FILE_NAME(changed, loc);
      std::vector<Statement*>reset;
      reset.push_back(clear);
      reset.push_back(sva_assign_(loc, seen,
	    sva_kill_generation_expr_(loc, inst)));
      return sva_if_(loc, changed, sva_block_(loc, reset), nullptr);
}

/* Final blocks can run without another assertion clock after $assertkill.
   In that case the clocked checker has not yet acknowledged the new
   generation, so any remaining state belongs exclusively to killed attempts
   and must not produce an end-of-simulation verdict. */
static PExpr* sva_kill_generation_current_(const struct vlltype&loc,
					    unsigned inst, perm_string seen)
{
      PEBComp*same = new PEBComp('E',
	    sva_kill_generation_expr_(loc, inst), sva_id_(loc, seen));
      FILE_NAME(same, loc);
      return same;
}

/* Concurrent action blocks belong to attempts that may have started before
   `$assertoff'. IEEE 1800-2017 20.12 requires those attempts and actions to
   complete, so action execution itself is deliberately not enable-gated;
   each engine gates only new-attempt injection. */
static Statement* sva_gate_(const struct vlltype&loc, Statement*action)
{
      (void)loc;
      return action;
}

/* Active source label for the checker currently being synthesized. The
   parser-stage and recursion-depth state live with the procedural-clock
   parking code below; this declaration must precede registration helpers. */
static perm_string sva_active_assertion_label_;

/* M12B: build the one-time
   `$ivl_register_assertion(idx, "name", "file", line)` call that gives a
   synthesized concurrent-assertion checker a VPI identity
   (vpi_iterate(vpiAssertion, ...)). idx is the compile-time instance
   number, which together with the runtime scope identifies the
   assertion for callback reporting. Placed in the checker's zero-init
   initial block. */
/* M12-2: `edges' is the FIXED start->accept tick-edge count of the
   assertion automaton (from pform_sva_nfa_fixed_latency), or -1 when
   the latency is variable/unknown. The attempt's real tick latency is
   edges-1 (the first edge samples on the attempt's own start tick), so
   this emits depth_arg = edges (>=1), with the runtime looking back
   depth_arg-1 clock ticks; depth_arg = 0 means unknown (report now).

   M12-1: `fail_full_latency' says a FAILURE report can only come from
   an attempt that ran the full latency (true for implications: an
   unobligated attempt dies silently). A plain sequence also reports a
   failure for an attempt that dies at its FIRST step, whose start is
   the failing tick itself, so its start time must not be recovered
   from the latency ring. */
static Statement* sva_register_stmt_(const struct vlltype&loc, unsigned inst,
				     long edges = -1,
				     bool fail_full_latency = false,
				     PExpr*edges_expr = nullptr)
{
      char nbuf[64];
      if (sva_active_assertion_label_.nil())
	    snprintf(nbuf, sizeof nbuf, "assert_L%d_%u", loc.first_line, inst);
      else
	    snprintf(nbuf, sizeof nbuf, "%s", sva_active_assertion_label_.str());
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
      named_pexpr_t a4;
      a4.parm = edges_expr ? edges_expr : static_cast<PExpr*>(
	    new PENumber(new verinum(
		  (uint64_t)(edges >= 1 ? edges : 0), 32)));
      args.push_back(a4);
      named_pexpr_t a5;
      a5.parm = new PENumber(new verinum(
	    (uint64_t)(fail_full_latency ? 1 : 0), 32));
      args.push_back(a5);
      PCallTask*t = new PCallTask(
	    lex_strings.make("$ivl_register_assertion"), args);
      FILE_NAME(t, loc);
      return t;
}

/* Assertion callback reasons (IEEE 1800-2017 40.x; must match the
   cbAssertion* values in sv_vpi_user.h). */
static const int SVA_CB_START   = 606;   /* cbAssertionStart */
static const int SVA_CB_SUCCESS = 607;   /* cbAssertionSuccess */
static const int SVA_CB_FAILURE = 608;   /* cbAssertionFailure */
/* M12-1: per-STEP reports — an attempt advanced one step of the
   sequence (STEP_SUCCESS) or died mid-sequence (STEP_FAILURE). Only
   the automaton engine delivers these. */
static const int SVA_CB_STEP_SUCCESS = 609;  /* cbAssertionStepSuccess */
static const int SVA_CB_STEP_FAILURE = 610;  /* cbAssertionStepFailure */

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
/* R2: an assertion ACTION block runs in the Reactive region (IEEE
 * 1800-2017 4.4.2.5), one region after the Observed region the verdict
 * was computed in.  The deferral is emitted here, inside the per-tick
 * dispatch guard, so a checker suspends only on a tick that has a
 * failure to report.
 *
 * The first attempt at this was reverted because it dropped verdicts at
 * end of simulation: the `final'-block action a strong sequence uses to
 * report an unfulfilled obligation suspended and never resumed.  That is
 * fixed in the runtime instead of avoided here — `%wait/reactive' falls
 * through and runs inline whenever no Reactive region is reachable any
 * more (final blocks, Postponed, post-simulation).  See vvp/vthread.cc
 * of_WAIT_REACTIVE and schedule_regions_live(). */
static Statement* sva_fail_action_(const struct vlltype&loc, unsigned inst,
				   Statement*action)
{
      std::vector<Statement*> v;
      v.push_back(sva_reactive_wait_(loc));
      v.push_back(sva_gate_(loc, action));
      v.push_back(sva_report_stmt_(loc, inst, SVA_CB_FAILURE));
      return sva_block_(loc, v);
}

/* The pass counterpart: the cbAssertionSuccess report plus the user's
 * pass action, both deferred to the Reactive region for the same reason
 * (4.4.2.5).  Folding the deferral in here keeps both engines' success
 * paths in the same region as their failure paths. */
static Statement* sva_pass_action_(const struct vlltype&loc, unsigned inst,
				   Statement*pass_stmt)
{
      std::vector<Statement*> v;
      v.push_back(sva_reactive_wait_(loc));
      v.push_back(sva_report_stmt_(loc, inst, SVA_CB_SUCCESS));
      if (pass_stmt) v.push_back(pass_stmt);
      return sva_block_(loc, v);
}

/* A cover property executes its statement once for every sequence/property
   match, but it is not an assertion-success callback. */
static Statement* sva_cover_action_(const struct vlltype&loc,
				    Statement*pass_stmt)
{
      std::vector<Statement*> v;
      v.push_back(sva_reactive_wait_(loc));
      v.push_back(sva_gate_(loc, pass_stmt));
      return sva_block_(loc, v);
}

/* Defined with the multiclock assertion helpers below. NFA endpoint fan-out
   also uses it to dispatch one action/callback for every verdict in a
   same-tick batch. */
static Statement* sva_repeat_(const struct vlltype&loc, PExpr*count,
			      Statement*action);

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
 * Simultaneity fine points (31.4.1) are a recorded corner: a
 * scheduling race by construction. Edge-descriptor event lists
 * (edge [01, 10]) are implemented in tc_always_at_ (M13B) with a
 * synthesized previous-value tracker.
 */
static unsigned tc_gensym_counter = 0;

static perm_string tc_make_real_(const struct vlltype&loc, unsigned inst,
				 const char*what, double init_val = -1.0)
{
      char buf[64];
      snprintf(buf, sizeof buf, "_ivl_tc%u_%s", inst, what);
      perm_string name = lex_strings.make(buf);

      list<decl_assignment_t*>*decls = new list<decl_assignment_t*>;
      decl_assignment_t*decl = new decl_assignment_t;
      decl->name = pform_ident_t(name, loc.lexical_pos);
      decl->expr.reset(new PEFNumber(new verireal(init_val)));
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

/* 3-value encoding of a scalar signal for edge-descriptor matching:
   (sig === 1'b1) ? 1.0 : (sig === 1'b0) ? 0.0 : 2.0  (x and z -> 2). */
static PExpr* tc_edge_encode_(const struct vlltype&loc,
			      const pform_name_t&sig)
{
      PExpr*is1 = new PEBComp('E', tc_name_id_(loc, sig),
			      new PENumber(new verinum(verinum::V1, 1)));
      PExpr*is0 = new PEBComp('E', tc_name_id_(loc, sig),
			      new PENumber(new verinum(verinum::V0, 1)));
      PETernary*inner = new PETernary(is0, tc_real_(loc, 0.0),
				      tc_real_(loc, 2.0));
      FILE_NAME(inner, loc);
      PETernary*outer = new PETernary(is1, tc_real_(loc, 1.0), inner);
      FILE_NAME(outer, loc);
      return outer;
}

static void tc_edge_vals_(PTimingCheck::EdgeType e, double&a, double&b)
{
      switch (e) {
	  case PTimingCheck::EDGE_01: a = 0.0; b = 1.0; break;
	  case PTimingCheck::EDGE_0X: a = 0.0; b = 2.0; break;
	  case PTimingCheck::EDGE_10: a = 1.0; b = 0.0; break;
	  case PTimingCheck::EDGE_1X: a = 1.0; b = 2.0; break;
	  case PTimingCheck::EDGE_X0: a = 2.0; b = 0.0; break;
	  case PTimingCheck::EDGE_X1: a = 2.0; b = 1.0; break;
      }
}

/* Build "@(edge sig) if (cond) <body>" as an always process. For an
   edge-descriptor event list (edge [01, 10] sig) the process triggers
   on ANY change of the signal, remembers the previous 3-value-encoded
   value in a synthesized real (initialized to 2 = x, the value of any
   variable before its first assignment), and runs the body only when
   the (previous, current) transition matches one of the descriptors.
   The &&& condition, when present, gates the body but never the
   previous-value bookkeeping. */
static void tc_always_at_(const struct vlltype&loc,
			  const PTimingCheck::event_t&ev,
			  Statement*body)
{
      if (!ev.edges.empty()) {
	    unsigned inst = tc_gensym_counter++;
	    perm_string prev_var = tc_make_real_(loc, inst, "prev", 2.0);

	    PExpr*match = 0;
	    for (std::vector<PTimingCheck::EdgeType>::const_iterator ep
		       = ev.edges.begin() ; ep != ev.edges.end() ; ++ep) {
		  double a = 0.0, b = 0.0;
		  tc_edge_vals_(*ep, a, b);
		  PExpr*pa = new PEBComp('e', sva_id_(loc, prev_var),
					 tc_real_(loc, a));
		  PExpr*cb = new PEBComp('e', tc_edge_encode_(loc, ev.name),
					 tc_real_(loc, b));
		  PExpr*both = new PEBLogic('a', pa, cb);
		  match = match? new PEBLogic('o', match, both) : both;
	    }

	    if (ev.condition.get()) {
		  PExpr*cond = sva_clone_expr_(ev.condition.get());
		  if (cond == 0) {
			cerr << loc.get_fileline() << ": sorry: this timing "
			     << "check &&& condition shape is not supported; "
			     << "the check is dropped." << endl;
			error_count += 1;
			return;
		  }
		  match = new PEBLogic('a', match, cond);
	    }

	    PCondit*gated = new PCondit(match, body, nullptr);
	    FILE_NAME(gated, loc);
	    PAssign*rec = new PAssign(sva_id_(loc, prev_var),
				      tc_edge_encode_(loc, ev.name));
	    FILE_NAME(rec, loc);

	    std::vector<Statement*> stmts;
	    stmts.push_back(gated);
	    stmts.push_back(rec);

	      /* Prime the previous-value tracker with the signal's value at
		 time 0. The always block below wakes only ON a change, so
		 without this `prev' sat at the x sentinel until the first
		 transition -- and that first transition therefore matched no
		 descriptor at all. A 0->1 edge on a signal that starts at 0
		 was silently dropped, taking a real violation with it, which
		 is worse than ignoring the descriptor: `edge[01] d' reported
		 nothing where plain `d' reported the violation. */
	    PAssign*prime = new PAssign(sva_id_(loc, prev_var),
					tc_edge_encode_(loc, ev.name));
	    FILE_NAME(prime, loc);
	    pform_make_behavior(IVL_PR_INITIAL, prime, nullptr);

	    PEEvent*pe = new PEEvent(PEEvent::ANYEDGE,
				     tc_name_id_(loc, ev.name));
	    PEventStatement*es = new PEventStatement(pe);
	    FILE_NAME(es, loc);
	    es->set_statement(sva_block_(loc, stmts));
	    pform_make_behavior(IVL_PR_ALWAYS, es, nullptr);
	    return;
      }

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

/* Common validity checks; false means the check was dropped loudly.
   (Edge-descriptor event lists are handled by tc_always_at_ now, so
   nothing is rejected here at present; this remains the hook for
   future per-event validity checks.) */
static bool tc_check_supported_(const struct vlltype&loc,
				const char*check_name,
				const PTimingCheck::event_t&ev)
{
      (void)loc; (void)check_name; (void)ev;
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

/* Loud drop for the event_based/remain_active flag arguments of
   $timeskew/$fullskew: they change violation-report granularity in
   ways this synthesizer does not model. */
static bool tc_skew_flags_ok_(const struct vlltype&loc,
			      const char*check_name, bool have_flags)
{
      if (!have_flags) return true;
      cerr << loc.get_fileline() << ": sorry: " << check_name
	   << " event_based/remain_active flag arguments are not "
	   << "supported; the check is dropped." << endl;
      error_count += 1;
      return false;
}

void pform_timing_check_timeskew(const struct vlltype&loc,
				 const PTimingCheck::event_t&ref_ev,
				 const PTimingCheck::event_t&data_ev,
				 PExpr*limit,
				 const pform_name_t*notifier,
				 bool have_flags)
{
      if (!tc_active_(loc, "$timeskew")) return;
      if (!tc_skew_flags_ok_(loc, "$timeskew", have_flags)) return;
	// Default-flavor $timeskew uses the same delta test as $skew:
	// violation when data lags the reference by MORE than the
	// limit. (The flag arguments, rejected above, are what change
	// the report granularity relative to $skew.)
      tc_pair_synth_(loc, "$timeskew", ref_ev, data_ev, limit, true, notifier);
}

void pform_timing_check_fullskew(const struct vlltype&loc,
				 const PTimingCheck::event_t&ref_ev,
				 const PTimingCheck::event_t&data_ev,
				 PExpr*lim1,
				 PExpr*lim2,
				 const pform_name_t*notifier,
				 bool have_flags)
{
      if (!tc_active_(loc, "$fullskew")) return;
      if (!tc_skew_flags_ok_(loc, "$fullskew", have_flags)) return;
	// $fullskew(ref, data, l1, l2) is a skew check in both
	// directions: data may lag ref by at most l1, and ref may lag
	// data by at most l2.
      tc_pair_synth_(loc, "$fullskew", ref_ev, data_ev, lim1, true, notifier);
      tc_pair_synth_(loc, "$fullskew", data_ev, ref_ev, lim2, true, notifier);
}

static bool tc_expr_is_zero_(PExpr*e)
{
      if (PENumber*n = dynamic_cast<PENumber*>(e))
	    return n->value().is_defined() && n->value().as_ulong() == 0;
      if (PEFNumber*f = dynamic_cast<PEFNumber*>(e))
	    return f->value().as_double() == 0.0;
      return false;
}

void pform_timing_check_nochange(const struct vlltype&loc,
				 const PTimingCheck::event_t&ref_ev,
				 const PTimingCheck::event_t&data_ev,
				 PExpr*start_off,
				 PExpr*end_off,
				 const pform_name_t*notifier)
{
      if (!tc_active_(loc, "$nochange")) return;
      if (!tc_check_supported_(loc, "$nochange", ref_ev)) return;
      if (!tc_check_supported_(loc, "$nochange", data_ev)) return;

      if (!ref_ev.posedge && !ref_ev.negedge) {
	    cerr << loc.get_fileline() << ": error: $nochange requires an "
		 << "edge-qualified reference event (posedge/negedge)."
		 << endl;
	    error_count += 1;
	    return;
      }
      if (!tc_expr_is_zero_(start_off) || !tc_expr_is_zero_(end_off)) {
	    cerr << loc.get_fileline() << ": sorry: $nochange with "
		 << "non-zero start/end edge offsets is not supported; "
		 << "the check is dropped." << endl;
	    error_count += 1;
	    return;
      }

	// With zero offsets the forbidden window is exactly the level
	// of the reference signal that FOLLOWS the given edge (posedge
	// ref: while ref is high). Track it with a window flag set at
	// the reference edge and cleared at the opposite edge, and
	// report a violation when the data event fires with the window
	// open. (Data changing in the same simulation step as the
	// window edge is the 31.4.1 simultaneity race, a recorded
	// corner shared with the other checks.)
      unsigned inst = tc_gensym_counter++;
      perm_string win_var = tc_make_real_(loc, inst, "window");

      PAssign*w1 = new PAssign(sva_id_(loc, win_var), tc_real_(loc, 1.0));
      FILE_NAME(w1, loc);
      tc_always_at_(loc, ref_ev, w1);

      PTimingCheck::event_t opp;
      opp.name = ref_ev.name;
      opp.posedge = ref_ev.negedge;
      opp.negedge = ref_ev.posedge;
      if (ref_ev.condition.get()) {
	    PExpr*ccl = sva_clone_expr_(ref_ev.condition.get());
	    if (ccl == 0) {
		  cerr << loc.get_fileline() << ": sorry: this timing check "
		       << "&&& condition shape is not supported; the check "
		       << "is dropped." << endl;
		  error_count += 1;
		  return;
	    }
	    opp.condition.reset(ccl);
      }
      PAssign*w0 = new PAssign(sva_id_(loc, win_var), tc_real_(loc, 0.0));
      FILE_NAME(w0, loc);
      tc_always_at_(loc, opp, w0);

      PExpr*cond = new PEBComp('>', sva_id_(loc, win_var),
			       tc_real_(loc, 0.0));
      PCondit*chk = new PCondit(cond,
				tc_violation_(loc, "$nochange", notifier),
				nullptr);
      FILE_NAME(chk, loc);
      tc_always_at_(loc, data_ev, chk);
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
/* Synthesized processes and their state registers must land in a scope
   something actually elaborates. A named begin/end is a PBlock whose
   `behaviors' nothing walks -- and the seq_block rule deletes it
   outright when it holds no declarations -- so anything synthesized
   while parsing inside one has to be hoisted to the nearest enclosing
   non-block scope. (This is the trap that silently dropped concurrent
   assertions written inside a begin/end; see M9-10.) */
struct sva_hoist_out_of_block_t {
      LexicalScope*saved;
      sva_hoist_out_of_block_t() {
	    saved = lexical_scope;
	    LexicalScope*scope = lexical_scope;
	    while (dynamic_cast<PBlock*>(scope) && scope->parent_scope())
		  scope = scope->parent_scope();
	    lexical_scope = scope;
      }
      ~sva_hoist_out_of_block_t() { lexical_scope = saved; }
};

static PExpr* sva_rewrite_sampled_(const struct vlltype&loc, PExpr*e,
				   unsigned inst, unsigned&hist_idx,
				   std::vector<Statement*>&pre,
				   std::vector<Statement*>&post,
				   std::vector<Statement*>&init,
				     /* When true the "current sample" is
					read LIVE from the argument instead
					of from a capture register, and the
					history shifts under NBA: that is
					what a sampler running as its own
					process needs (see
					pform_bind_procedural_sampled_).
					The assertion engine leaves it
					false -- its capture and shift
					bracket the checker body. */
				   bool cur_live = false)
{
      if (!e) return e;

      if (PECallFunction*cf = dynamic_cast<PECallFunction*>(e)) {
	      /* $stable/$changed over a parameter-sized unpacked array is a
		 comparison between a current Preponed snapshot and a one-tick
		 history snapshot.  Lower both to equally-shaped symbolic arrays;
		 PEBComp expands them using the actual instance range. */
	    sva_uarray_operand_t whole_array_call;
	    if (sva_uarray_operand_(cf, whole_array_call)
		&& sva_uarray_bound_is_overridable_(whole_array_call)) {
		  const char*whole_name = peek_tail_name(cf->path().name).str();
		  bool is_whole_stable = !strcmp(whole_name, "$stable");
		  bool is_whole_changed = !strcmp(whole_name, "$changed");
		  if (is_whole_stable || is_whole_changed) {
			sva_uarray_operand_t current = whole_array_call;
			current.outer = nullptr;
			PExpr*cur = sva_rewrite_symbolic_uarray_operand_(
			      loc, current.id, current, inst, hist_idx,
			      pre, post, init, cur_live);

			std::list<named_pexpr_t>past_args;
			named_pexpr_t a0;
			a0.parm = sva_clone_expr_(whole_array_call.id);
			past_args.push_back(a0);
			PECallFunction*past_call = new PECallFunction(
			      lex_strings.make("$past"), past_args);
			FILE_NAME(past_call, loc);
			sva_uarray_operand_t previous;
			bool have_previous = sva_uarray_operand_(
			      past_call, previous);
			PExpr*old = have_previous
			      ? sva_rewrite_symbolic_uarray_operand_(
				    loc, past_call, previous, inst, hist_idx,
				    pre, post, init, cur_live)
			      : nullptr;
			if (!cur || !old) return e;
			PEBComp*cmp = new PEBComp(
			      is_whole_stable ? 'E' : 'N', cur, old);
			FILE_NAME(cmp, loc);
			return cmp;
		  }
	    }
	      /* Already bound to a clock (an inner call of a nested
		 sampled expression, bound on an earlier pass): reuse
		 that substitution rather than building a second,
		 identical history chain for the same call site. */
	    if (PExpr*done = cf->sampled_subst())
		  return done;
	    if (cf->path().name.size() == 1 && !cf->path().package) {
		  const char*nm = peek_tail_name(cf->path().name).str();
		  bool is_rose = !strcmp(nm, "$rose");
		  bool is_fell = !strcmp(nm, "$fell");
		  bool is_stbl = !strcmp(nm, "$stable");
		  bool is_chgd = !strcmp(nm, "$changed");
		  bool is_past = !strcmp(nm, "$past");
		    /* $sampled(e) is the Preponed sample of e (16.9.3) --
		       definitionally $past(e, 0). It was missing from this
		       dispatch, fell through to the live-value VPI fallback,
		       and silently returned the POST-edge value (recovery
		       C5): route it through the same capture register the
		       other sampled functions use, with no history chain. */
		  bool is_smpl = !strcmp(nm, "$sampled");
		  if (is_rose || is_fell || is_stbl || is_chgd || is_past || is_smpl) {
			const std::vector<named_pexpr_t>&parms = cf->get_parms();
			if (parms.empty() || !parms[0].parm) {
			      cerr << loc << ": error: " << nm
				   << " requires an argument." << endl;
			      error_count += 1;
			      return e;
			}
			PExpr*arg = sva_rewrite_sampled_(loc, parms[0].parm,
							 inst, hist_idx, pre, post,
							 init, cur_live);
			long depth = 1;
			perm_string deferred_depth;
			if (is_past && parms.size() > 1 && parms[1].parm) {
			      if (!pform_sva_const_long(parms[1].parm, depth)) {
				    if (!pform_sva_deferred_genvar(
					      parms[1].parm, deferred_depth)) {
					  cerr << loc << ": error: $past depth must "
					       << "be a constant expression." << endl;
					  error_count += 1;
					  return e;
				    }
			      }
			      if (deferred_depth.nil() && depth < 1) {
				    /* 16.9.3: number_of_ticks shall be >= 1. The
				       old clamp silently turned $past(x,0) into
				       $past(x,1) (recovery C5); for the current
				       sample the LRM spelling is $sampled(x). */
				    cerr << loc << ": error: $past depth must be"
					 " >= 1 (16.9.3); use $sampled() for the"
					 " current sample." << endl;
				    error_count += 1;
				    return e;
			      }
			}
			  /* $past(expr, n, GATING_EXPR): the history
			     advances only on ticks where the gating
			     expression is true (16.9.3). The argument was
			     accepted and then ignored, so a gated $past
			     silently read the ungated history. */
			PExpr*gate = nullptr;
			if (is_past && parms.size() > 2 && parms[2].parm)
			      gate = parms[2].parm;
			if (!is_past && parms.size() > 1) {
			      cerr << loc << ": sorry: a clocking-event "
				   << "argument to " << nm << " is not "
				   << "supported here; it is ignored and the "
				   << "inferred clock is used." << endl;
			}
			if (is_past && parms.size() > 3 && parms[3].parm) {
			      cerr << loc << ": sorry: an explicit "
				   << "clocking-event argument to $past is "
				   << "not supported here; it is ignored and "
				   << "the inferred clock is used." << endl;
			}
			  /* $past/$sampled preserve the value, and $stable/$changed
			     compare the FULL value even though their result is one
			     bit. Derive their capture/history width with
			     $bits(argument). Only $rose/$fell intentionally inspect
			     the least-significant bit and use one-bit history. */
			bool wide = is_past || is_smpl || is_stbl || is_chgd;
			  /* ...unless the argument is a real variable, in
			     which case an integral history would round
			     the fraction away silently. A REAL history
			     keeps it. Decided from the declaration in
			     scope, so it covers $past(r) -- the shape
			     that matters; a real-valued EXPRESSION still
			     lands in the integral chain. */
			bool as_real = false;
			if (wide) {
			      if (const PEIdent*aid =
				  dynamic_cast<const PEIdent*>(parms[0].parm)) {
				    if (aid->path().size() == 1) {
					  PWire*w = pform_get_wire_in_scope(
						aid->path().back().name);
					  if (w && dynamic_cast<const real_type_t*>(
						      w->data_type()))
						as_real = true;
				    }
			      }
			}
			bool sample_signed = wide && !as_real
			      && sva_expr_signed_(arg);
			if (!deferred_depth.nil() && as_real) {
			      cerr << loc << ": sorry: $past(real_expr, genvar) "
				   << "is not supported; the assertion is dropped."
				   << endl;
			      error_count += 1;
			      return e;
			}
			  /* The CURRENT sample. Spliced into a checker
			     body it is a capture register assigned at the
			     top of the block; in a standalone sampler
			     there is no such moment, so the value is read
			     live from the argument wherever it is needed
			     ($rose and friends compare it against the
			     history). mk_cur() hands out a fresh node
			     each time so no expression node is shared
			     between two trees. */
			perm_string cur;
			if (!cur_live) {
			      cur = sva_make_reg_(loc, inst, "smp", hist_idx++,
						  wide, as_real, arg,
						  sample_signed);
			      pre.push_back(sva_assign_(loc, cur, arg));
			}
			auto mk_cur = [&]() -> PExpr* {
			      return cur_live ? sva_clone_expr_(arg)
					      : sva_id_(loc, cur);
			};
			auto mk_assign = [&](perm_string lv, PExpr*rv) -> Statement* {
			      return cur_live ? sva_assign_nb_(loc, lv, rv)
					      : sva_assign_(loc, lv, rv);
			};
			if (is_smpl) {
			      /* No history: the Preponed capture IS the value. */
			      sampled_pending_drop_(cf);
			      return mk_cur();
			}
			if (!deferred_depth.nil()) {
			      /* A generated scope supplies a different constant depth
				 for every loop instance. Keep one circular history per
				 call site: before the bottom-of-tick write, hist[ptr]
				 is exactly the sample from `depth' enabled ticks ago. */
			      perm_string hist = sva_make_genvar_history_(
				    loc, inst, hist_idx, arg, deferred_depth,
				    sample_signed);
			      perm_string ptr = sva_make_reg_(loc, inst, "ghptr",
							 hist_idx++, true);
			      init.push_back(sva_assign_(loc, ptr,
				    new PENumber(new verinum((uint64_t)0, 32))));

			      std::vector<Statement*> shift;
			      shift.push_back(sva_assign_index_(
				    loc, hist, sva_id_(loc, ptr), mk_cur(), cur_live));
			      PENumber*one0 = new PENumber(
				    new verinum((uint64_t)1, 32));
			      FILE_NAME(one0, loc);
			      PExpr*last = new PEBinary(
				    '-', sva_id_(loc, deferred_depth), one0);
			      FILE_NAME(last, loc);
			      PExpr*at_last = new PEBComp(
				    'e', sva_id_(loc, ptr), last);
			      FILE_NAME(at_last, loc);
			      PENumber*zero = new PENumber(
				    new verinum((uint64_t)0, 32));
			      FILE_NAME(zero, loc);
			      PENumber*one1 = new PENumber(
				    new verinum((uint64_t)1, 32));
			      FILE_NAME(one1, loc);
			      PExpr*inc = new PEBinary(
				    '+', sva_id_(loc, ptr), one1);
			      FILE_NAME(inc, loc);
			      PETernary*next = new PETernary(at_last, zero, inc);
			      FILE_NAME(next, loc);
			      shift.push_back(mk_assign(ptr, next));

			      if (gate) {
				    if (!cur_live) {
					  Statement*cap = pre.back();
					  pre.pop_back();
					  pre.push_back(sva_if_(loc,
						sva_clone_expr_(gate), cap,
						nullptr));
				    }
				    post.push_back(sva_if_(loc,
					  sva_clone_expr_(gate),
					  sva_block_(loc, shift), nullptr));
			      } else {
				    post.insert(post.end(), shift.begin(), shift.end());
			      }

			      sampled_pending_drop_(cf);
			      PExpr*old_value = sva_index_(
				    loc, hist, sva_id_(loc, ptr));
			      if (data_type_t*sample_type =
					    sva_expr_sample_type_(arg)) {
				    PECastType*typed = new PECastType(
					  sample_type, old_value);
				    FILE_NAME(typed, loc);
				    return typed;
			      }
			      return old_value;
			}
			  /* ...and build the history chain, updated
			     bottom-of-block in shift order. */
			std::vector<perm_string> hist (depth);
			for (long k = 0 ; k < depth ; k += 1) {
			      hist[k] = sva_make_reg_(loc, inst, "hist", hist_idx++,
						      wide, as_real, arg,
						      sample_signed);
				/* Deterministic first-cycle behavior:
				   histories start at 0, so $stable
				   compares against 0 rather than the
				   strict-LRM x default (recorded). */
			      init.push_back(sva_assign_(loc, hist[k],
							 sva_bit_(loc, 0)));
			}
			std::vector<Statement*> shift;
			for (long k = depth-1 ; k >= 1 ; k -= 1)
			      shift.push_back(mk_assign(hist[k],
							sva_id_(loc, hist[k-1])));
			shift.push_back(mk_assign(hist[0], mk_cur()));
			if (gate) {
				/* Gated: both the capture and the shift
				   happen only on enabled ticks, so the
				   history holds the n-th ENABLED sample. */
			      if (!cur_live) {
				    Statement*cap = pre.back();
				    pre.pop_back();
				    pre.push_back(sva_if_(loc,
						sva_clone_expr_(gate),
						cap, nullptr));
			      }
			      post.push_back(sva_if_(loc, sva_clone_expr_(gate),
						     sva_block_(loc, shift),
						     nullptr));
			} else {
			      for (size_t k = 0 ; k < shift.size() ; k += 1)
				    post.push_back(shift[k]);
			}
			perm_string old_reg = hist[depth-1];

			  /* This call now has a clock; it is no longer
			     waiting for one. */
			sampled_pending_drop_(cf);

			if (is_past) {
			      PExpr*old_value = sva_id_(loc, old_reg);
			      if (data_type_t*sample_type =
					    sva_expr_sample_type_(arg)) {
				    PECastType*typed = new PECastType(sample_type,
							 old_value);
				    FILE_NAME(typed, loc);
				    return typed;
			      }
			      return old_value;
			}
			if (is_rose) {
			      PEUnary*np = new PEUnary('!', sva_id_(loc, old_reg));
			      FILE_NAME(np, loc);
			      PEBLogic*r = new PEBLogic('a', mk_cur(), np);
			      FILE_NAME(r, loc);
			      return r;
			}
			if (is_fell) {
			      PEUnary*nc = new PEUnary('!', mk_cur());
			      FILE_NAME(nc, loc);
			      PEBLogic*r = new PEBLogic('a', nc, sva_id_(loc, old_reg));
			      FILE_NAME(r, loc);
			      return r;
			}
			  /* $stable / $changed: case (in)equality on the
			     sampled pair. */
			PEBComp*r = new PEBComp(is_stbl ? 'E' : 'N',
						mk_cur(),
						sva_id_(loc, old_reg));
			FILE_NAME(r, loc);
			return r;
		  }
	    }

	      /* Ordinary function calls can contain sampled-value calls in
		 their arguments (`min($past(a), b)' is common in OpenTitan).
		 Recurse through them instead of leaving the nested call for the
		 unrelated procedural-clock binder. The function itself remains
		 in place; only its input expressions are contextualized. */
	    if (!cf->receiver_expr()) {
		  const std::vector<named_pexpr_t>&src = cf->get_parms();
		  std::vector<PExpr*>rewritten(src.size(), nullptr);
		  bool changed = false;
		  for (size_t k = 0 ; k < src.size() ; k += 1) {
			if (!src[k].parm) continue;
			rewritten[k] = sva_rewrite_sampled_(
			      loc, src[k].parm, inst, hist_idx, pre, post,
			      init, cur_live);
			changed |= rewritten[k] != src[k].parm;
		  }
		  if (changed) {
			std::list<named_pexpr_t>args;
			for (size_t k = 0 ; k < src.size() ; k += 1) {
			      named_pexpr_t arg;
			      arg.name = src[k].name;
			      arg.parm = !src[k].parm ? nullptr
				    : rewritten[k] == src[k].parm
				    ? sva_clone_expr_(src[k].parm) : rewritten[k];
			      if (src[k].parm && !arg.parm) return e;
			      args.push_back(arg);
			}
			PECallFunction*cp = cf->path().package
			      ? new PECallFunction(cf->path().package,
						   cf->path().name, args)
			      : new PECallFunction(cf->path().name, args);
			if (cf->leading_type_args()) {
			      parmvalue_t*type_args = sva_clone_parmvalue_(
				    cf->leading_type_args(), nullptr);
			      if (!type_args) { delete cp; return e; }
			      cp->set_leading_type_args(type_args);
			}
			cp->set_scoped_type_prefix(
			      cf->has_scoped_type_prefix());
			cp->set_line(*e);
			return cp;
		  }
	    }
	    return e;
      }

      if (PEUnary*un = dynamic_cast<PEUnary*>(e)) {
	    PExpr*sub = sva_rewrite_sampled_(loc, un->get_expr(),
					     inst, hist_idx, pre, post, init,
					     cur_live);
	    if (sub == un->get_expr()) return e;
	    PEUnary*cp = new PEUnary(un->get_op(), sub);
	    cp->set_line(*e);
	    return cp;
      }
      if (PEBinary*bin = dynamic_cast<PEBinary*>(e)) {
	    if (dynamic_cast<PEBComp*>(e)
		&& (bin->get_op() == 'e' || bin->get_op() == 'E'
		    || bin->get_op() == 'w' || bin->get_op() == 'n'
		    || bin->get_op() == 'N' || bin->get_op() == 'W')) {
		  sva_uarray_operand_t left_array, right_array;
		  bool symbolic_arrays =
			sva_uarray_operand_(bin->get_left(), left_array)
			&& sva_uarray_operand_(bin->get_right(), right_array)
			&& sva_uarray_value_operand_(left_array)
			&& sva_uarray_value_operand_(right_array)
			&& (sva_uarray_bound_is_overridable_(left_array)
			    || sva_uarray_bound_is_overridable_(right_array));
		  if (symbolic_arrays) {
			PExpr*l = sva_rewrite_symbolic_uarray_operand_(
			      loc, bin->get_left(), left_array, inst, hist_idx,
			      pre, post, init, cur_live);
			PExpr*r = sva_rewrite_symbolic_uarray_operand_(
			      loc, bin->get_right(), right_array, inst, hist_idx,
			      pre, post, init, cur_live);
			if (!l || !r) return e;
			PEBComp*copy = new PEBComp(bin->get_op(), l, r);
			copy->set_line(*e);
			return copy;
		  }
	    }
	    PExpr*l = sva_rewrite_sampled_(loc, bin->get_left(),
					   inst, hist_idx, pre, post, init,
					   cur_live);
	    PExpr*r = sva_rewrite_sampled_(loc, bin->get_right(),
					   inst, hist_idx, pre, post, init,
					   cur_live);
	    if (l == bin->get_left() && r == bin->get_right()) return e;
	    PEBinary*cp;
	    if (dynamic_cast<PEBComp*>(e))
		  cp = new PEBComp(bin->get_op(), l, r);
	    else if (dynamic_cast<PEBLogic*>(e))
		  cp = new PEBLogic(bin->get_op(), l, r);
	    else if (dynamic_cast<PEBPower*>(e))
		  cp = new PEBPower(bin->get_op(), l, r);
	    else if (dynamic_cast<PEBShift*>(e))
		  cp = new PEBShift(bin->get_op(), l, r);
	    else
		  cp = new PEBinary(bin->get_op(), l, r);
	    cp->set_line(*e);
	    return cp;
      }
      if (PETernary*ter = dynamic_cast<PETernary*>(e)) {
	    PExpr*c = sva_rewrite_sampled_(loc, ter->get_cond(),
					   inst, hist_idx, pre, post, init,
					   cur_live);
	    PExpr*t = sva_rewrite_sampled_(loc, ter->get_true(),
					   inst, hist_idx, pre, post, init,
					   cur_live);
	    PExpr*f = sva_rewrite_sampled_(loc, ter->get_false(),
					   inst, hist_idx, pre, post, init,
					   cur_live);
	    if (c == ter->get_cond() && t == ter->get_true()
		&& f == ter->get_false()) return e;
	    PETernary*cp = new PETernary(c, t, f);
	    cp->set_line(*e);
	    return cp;
      }
      if (PECastSize*cast = dynamic_cast<PECastSize*>(e)) {
	    PExpr*base = sva_rewrite_sampled_(loc, cast->cast_base(), inst,
					     hist_idx, pre, post, init,
					     cur_live);
	    if (base == cast->cast_base()) return e;
	    PExpr*size = sva_clone_expr_(cast->cast_size());
	    if (!size) return e;
	    PECastSize*cp = new PECastSize(size, base);
	    cp->set_line(*e);
	    return cp;
      }
      if (PECastType*cast = dynamic_cast<PECastType*>(e)) {
	    PExpr*base = sva_rewrite_sampled_(loc, cast->cast_base(), inst,
					     hist_idx, pre, post, init,
					     cur_live);
	    if (base == cast->cast_base()) return e;
	    PECastType*cp = new PECastType(cast->cast_target(), base);
	    cp->set_line(*e);
	    return cp;
      }
      if (PECastSign*cast = dynamic_cast<PECastSign*>(e)) {
	    PExpr*base = sva_rewrite_sampled_(loc, cast->cast_base(), inst,
					     hist_idx, pre, post, init,
					     cur_live);
	    if (base == cast->cast_base()) return e;
	    PECastSign*cp = new PECastSign(cast->has_sign(), base);
	    cp->set_line(*e);
	    return cp;
      }
      if (PEConcat*cat = dynamic_cast<PEConcat*>(e)) {
	    const std::vector<PExpr*>&src = cat->stream_parms();
	    std::vector<PExpr*>rewritten(src.size());
	    bool changed = false;
	    for (size_t k = 0 ; k < src.size() ; k += 1) {
		  rewritten[k] = sva_rewrite_sampled_(loc, src[k], inst,
						 hist_idx, pre, post, init,
						 cur_live);
		  changed |= rewritten[k] != src[k];
	    }
	    if (!changed) return e;
	    std::list<PExpr*>parts;
	    for (size_t k = 0 ; k < src.size() ; k += 1) {
		  PExpr*part = rewritten[k] == src[k]
			? sva_clone_expr_(src[k]) : rewritten[k];
		  if (!part) return e;
		  parts.push_back(part);
	    }
	    PExpr*repeat = cat->has_repeat()
		  ? sva_clone_expr_(cat->repeat_expr()) : nullptr;
	    if (cat->has_repeat() && !repeat) return e;
	    PEConcat*cp = new PEConcat(parts, repeat);
	    cp->set_line(*e);
	    return cp;
      }
      if (PEInside*inside = dynamic_cast<PEInside*>(e)) {
	    const std::vector<inside_range_t>&src = inside->get_ranges();
	    PExpr*base = sva_rewrite_sampled_(loc, inside->get_expr(), inst,
					       hist_idx, pre, post, init,
					       cur_live);
	    struct rewritten_range_t {
		  PExpr*lo;
		  PExpr*hi;
		  PExpr*weight;
	    };
	    std::vector<rewritten_range_t> rewritten(src.size());
	    bool changed = base != inside->get_expr();
	    for (size_t k = 0 ; k < src.size() ; k += 1) {
		  rewritten[k].lo = src[k].lo
			? sva_rewrite_sampled_(loc, src[k].lo, inst, hist_idx,
						 pre, post, init, cur_live) : nullptr;
		  rewritten[k].hi = src[k].hi
			? sva_rewrite_sampled_(loc, src[k].hi, inst, hist_idx,
						 pre, post, init, cur_live) : nullptr;
		  rewritten[k].weight = src[k].weight
			? sva_rewrite_sampled_(loc, src[k].weight, inst, hist_idx,
						 pre, post, init, cur_live) : nullptr;
		  changed |= rewritten[k].lo != src[k].lo;
		  changed |= rewritten[k].hi != src[k].hi;
		  changed |= rewritten[k].weight != src[k].weight;
	    }
	    if (!changed) return e;

	    if (base == inside->get_expr()) base = sva_clone_expr_(base);
	    if (!base) return e;
	    std::list<inside_range_t>*ranges = new std::list<inside_range_t>;
	    for (size_t k = 0 ; k < src.size() ; k += 1) {
		  inside_range_t dst;
		  dst.lo = rewritten[k].lo == src[k].lo
			? sva_clone_expr_(src[k].lo) : rewritten[k].lo;
		  dst.hi = rewritten[k].hi == src[k].hi
			? sva_clone_expr_(src[k].hi) : rewritten[k].hi;
		  dst.weight = rewritten[k].weight == src[k].weight
			? sva_clone_expr_(src[k].weight) : rewritten[k].weight;
		  dst.is_range = src[k].is_range;
		  dst.weight_is_divided = src[k].weight_is_divided;
		  if ((src[k].lo && !dst.lo) || (src[k].hi && !dst.hi)
		      || (src[k].weight && !dst.weight)) {
			delete dst.lo;
			delete dst.hi;
			delete dst.weight;
			delete base;
			for (std::list<inside_range_t>::iterator it = ranges->begin()
			     ; it != ranges->end() ; ++it) {
			      delete it->lo;
			      delete it->hi;
			      delete it->weight;
			}
			delete ranges;
			return e;
		  }
		  ranges->push_back(dst);
	    }
	    PEInside*cp = new PEInside(base, ranges, inside->is_dist());
	    cp->set_line(*e);
	    return cp;
      }
      return e;
}

/*
 * M9-SV: PROCEDURAL sampled value functions (IEEE 1800-2017 16.9.3).
 *
 * $past / $rose / $fell / $stable / $changed have a value only with
 * respect to a clocking event. Inside a concurrent assertion the SVA
 * lowering supplies that clock and rewrites them (sva_rewrite_sampled_
 * above). Everywhere else they used to be plain system-function calls
 * served by compile-progress VPI stubs that returned
 *
 *      $past(e)   -> e     (the CURRENT value)
 *      $rose(e)   -> 0
 *      $fell(e)   -> 0
 *      $stable(e) -> 1
 *
 * with no diagnostic -- so
 *
 *      always @(posedge clk) if ($rose(req)) ...
 *
 * silently never fired, and $past(d) silently read d itself. The
 * number-of-ticks argument was ignored too, and the boolean functions
 * came back 32 bits wide instead of 1.
 *
 * A sampled call is parsed into a pending list. When a behavior closes,
 * every pending call written inside it is bound to that block's own
 * clocking event (16.14.6 clock inference) by reusing the exact
 * rewrite the assertion engine uses: a per-call sample register plus a
 * history chain, with the capture spliced in at the TOP of the block
 * and the shift at the BOTTOM. Both halves run in the block itself, so
 * there is no cross-process race to reason about -- a reader in the
 * body sees the sample taken at the previous tick, which is what
 * $past(e, 1) means.
 */
struct sampled_pending_t {
      PECallFunction*call;
      struct vlltype loc;
};
static std::vector<sampled_pending_t> sampled_pending_;

bool pform_is_sampled_value_function(const char*name)
{
      if (!name) return false;
      return !strcmp(name, "$past")   || !strcmp(name, "$rose")
	  || !strcmp(name, "$fell")   || !strcmp(name, "$stable")
	  || !strcmp(name, "$changed");
}

void pform_note_sampled_call(const struct vlltype&loc, PECallFunction*cf)
{
      sampled_pending_t p;
      p.call = cf;
      p.loc = loc;
      sampled_pending_.push_back(p);
}

/* The assertion engine consumed this call itself: drop it so the
   procedural binder does not build a second, dead history chain for
   it (and does not report it as unclocked). */
static void sampled_pending_drop_(const PECallFunction*cf)
{
      for (size_t i = 0 ; i < sampled_pending_.size() ; i += 1) {
	    if (sampled_pending_[i].call == cf) {
		  sampled_pending_.erase(sampled_pending_.begin() + i);
		  return;
	    }
      }
}

/* Mark every identifier in this expression tree as coming from a
   CONCURRENT ASSERTION, so an unresolved name is an ERROR rather than
   the compile-progress warning used elsewhere.

   The warning exists so UVM-heavy code keeps building through
   parameterized-container typing losses. Inside an assertion it is
   actively harmful: `NoSuchSeq_S |=> 1'b0' cannot hold under any trace,
   yet it compiles and reports nothing. The testbench builds, the run is
   green, and a check the engineer believes exists does not -- with no
   later symptom, unlike a mistyped signal in ordinary RTL.

   Every PEIdent reached is marked, not just bare single-component
   names: `NoSuchBus[0]', `NoSuchBus[3:0] != 0' and `NoSuchStruct.fld'
   are all silently inert today. Package-qualified names are left alone;
   they resolve through a different path and already error.

   Marking happens at the pform level, so it cannot reach non-assertion
   code -- in particular uvm-core/src, which contains no concurrent
   assertions at all and whose reliance on the generic warning is
   therefore untouched. */
static void sva_mark_strict_(PExpr*e)
{
      if (!e) return;

      if (PEIdent*id = dynamic_cast<PEIdent*>(e)) {
	    if (id->path().package) return;
	    id->set_strict_bind();
	    return;
      }
      if (PECallFunction*cf = dynamic_cast<PECallFunction*>(e)) {
	    const std::vector<named<PExpr*> >&parms = cf->get_parms();
	    for (size_t i = 0 ; i < parms.size() ; i += 1)
		  sva_mark_strict_(parms[i].parm);
	    return;
      }
      if (PEUnary*un = dynamic_cast<PEUnary*>(e)) {
	    sva_mark_strict_(un->get_expr());
	    return;
      }
      if (PEBinary*bin = dynamic_cast<PEBinary*>(e)) {
	    sva_mark_strict_(bin->get_left());
	    sva_mark_strict_(bin->get_right());
	    return;
      }
      if (PETernary*ter = dynamic_cast<PETernary*>(e)) {
	    sva_mark_strict_(ter->get_cond());
	    sva_mark_strict_(ter->get_true());
	    sva_mark_strict_(ter->get_false());
	    return;
      }
      if (PECastSize*cast = dynamic_cast<PECastSize*>(e)) {
	    sva_mark_strict_(cast->cast_size());
	    sva_mark_strict_(cast->cast_base());
	    return;
      }
      if (PECastType*cast = dynamic_cast<PECastType*>(e)) {
	    sva_mark_strict_(cast->cast_base());
	    return;
      }
      if (PECastSign*cast = dynamic_cast<PECastSign*>(e)) {
	    sva_mark_strict_(cast->cast_base());
	    return;
      }
      if (PEConcat*cc = dynamic_cast<PEConcat*>(e)) {
	    const std::vector<PExpr*>&parms = cc->stream_parms();
	    for (size_t i = 0 ; i < parms.size() ; i += 1)
		  sva_mark_strict_(parms[i]);
	    sva_mark_strict_(cc->repeat_expr());
	    return;
      }
}

/* Forget every pending sampled-value call inside this expression tree,
   because the tree is about to be freed.
 
   A destructor hook on PECallFunction alone would NOT be enough:
   ~PEBinary, ~PETernary and ~PEUnary are all empty (PExpr.cc), so
   deleting `a && $rose(x)' frees the PEBinary and leaks the nested
   call without ever running its destructor. The entry would survive
   with a dangling pointer. So walk the tree explicitly, mirroring
   sva_rewrite_sampled_'s recursion.
 
   Leaving a stale entry is not merely untidy: the endmodule flush
   reports one warning per entry, so a dropped assertion would emit
   diagnostics about sampled calls the user can no longer see. */
static void sva_expr_forget_sampled_(PExpr*e)
{
      if (!e) return;

      if (PECallFunction*cf = dynamic_cast<PECallFunction*>(e)) {
	    sampled_pending_drop_(cf);
	      // A sampled call can nest inside another call's arguments.
	    const std::vector<named<PExpr*> >&parms = cf->get_parms();
	    for (size_t i = 0 ; i < parms.size() ; i += 1)
		  sva_expr_forget_sampled_(parms[i].parm);
	    return;
      }
      if (PEUnary*un = dynamic_cast<PEUnary*>(e)) {
	    sva_expr_forget_sampled_(un->get_expr());
	    return;
      }
      if (PEBinary*bin = dynamic_cast<PEBinary*>(e)) {
	    sva_expr_forget_sampled_(bin->get_left());
	    sva_expr_forget_sampled_(bin->get_right());
	    return;
      }
      if (PETernary*ter = dynamic_cast<PETernary*>(e)) {
	    sva_expr_forget_sampled_(ter->get_cond());
	    sva_expr_forget_sampled_(ter->get_true());
	    sva_expr_forget_sampled_(ter->get_false());
	    return;
      }
      if (PECastSize*cast = dynamic_cast<PECastSize*>(e)) {
	    sva_expr_forget_sampled_(cast->cast_size());
	    sva_expr_forget_sampled_(cast->cast_base());
	    return;
      }
      if (PECastType*cast = dynamic_cast<PECastType*>(e)) {
	    sva_expr_forget_sampled_(cast->cast_base());
	    return;
      }
      if (PECastSign*cast = dynamic_cast<PECastSign*>(e)) {
	    sva_expr_forget_sampled_(cast->cast_base());
	    return;
      }
      if (PEInside*inside = dynamic_cast<PEInside*>(e)) {
	    sva_expr_forget_sampled_(inside->get_expr());
	    const std::vector<inside_range_t>&ranges = inside->get_ranges();
	    for (size_t i = 0 ; i < ranges.size() ; i += 1) {
		  sva_expr_forget_sampled_(ranges[i].lo);
		  sva_expr_forget_sampled_(ranges[i].hi);
		  sva_expr_forget_sampled_(ranges[i].weight);
	    }
	    return;
      }
      if (PEConcat*cc = dynamic_cast<PEConcat*>(e)) {
	    const std::vector<PExpr*>&parms = cc->stream_parms();
	    for (size_t i = 0 ; i < parms.size() ; i += 1)
		  sva_expr_forget_sampled_(parms[i]);
	    sva_expr_forget_sampled_(cc->repeat_expr());
	    return;
      }
}

/* Is this behavior clocked by a single edge, and if so which event
   statement carries it? Only an edge qualifies: 16.14.6 infers the
   clock from an edge-sensitive event control, and a level-sensitive
   or @* block has no tick to sample on. */
static PEventStatement* sampled_clock_event_(ivl_process_type_t type,
					     Statement*st)
{
      if (type != IVL_PR_ALWAYS && type != IVL_PR_ALWAYS_FF)
	    return nullptr;
      PEventStatement*ev = dynamic_cast<PEventStatement*>(st);
      if (!ev) return nullptr;
      const std::vector<PEEvent*>&evs = ev->event_expressions();
      if (evs.empty()) return nullptr;
      for (size_t i = 0 ; i < evs.size() ; i += 1) {
	    if (!evs[i]) return nullptr;
	    PEEvent::edge_t k = evs[i]->type();
	    if (k != PEEvent::POSEDGE && k != PEEvent::NEGEDGE
		&& k != PEEvent::EDGE)
		  return nullptr;
      }
      return ev;
}

static void pform_make_sampled_history_process_(
	    const struct vlltype&loc,
	    const std::vector<PEEvent*>&events,
	    std::vector<Statement*>&post,
	    std::vector<Statement*>&init);

static void pform_bind_procedural_sampled_(ivl_process_type_t type,
					   Statement*st)
{
      if (sampled_pending_.empty() || !st)
	    return;

      PEventStatement*ev = sampled_clock_event_(type, st);
      if (!ev)
	    return;

	/* Only calls written INSIDE this block: the pending list can
	   still hold calls from an earlier construct in the same module
	   (an initial block, a task body), and those must not be
	   captured by whatever clocked block happens to come next. The
	   event control opens the block, so anything at or after its
	   line and in the same file is inside it. */
      const char*evfile = ev->get_file() ? ev->get_file().str() : nullptr;
      unsigned evline = ev->get_lineno();

      std::vector<sampled_pending_t> mine;
      std::vector<sampled_pending_t> rest;
      for (size_t i = 0 ; i < sampled_pending_.size() ; i += 1) {
	    const sampled_pending_t&p = sampled_pending_[i];
	    const char*pfile = p.call->get_file() ? p.call->get_file().str()
					          : nullptr;
	    bool inside = evfile && pfile && !strcmp(evfile, pfile)
			  && p.call->get_lineno() >= evline;
	    if (inside) mine.push_back(p);
	    else rest.push_back(p);
      }
      sampled_pending_ = rest;
      if (mine.empty())
	    return;

      unsigned inst = sva_gensym_counter++;
      unsigned hist_idx = 0;
      std::vector<Statement*> pre, post, init;

      for (size_t i = 0 ; i < mine.size() ; i += 1) {
	    PECallFunction*cf = mine[i].call;
	    if (cf->sampled_subst())
		  continue;               // already bound (nested call)
	    PExpr*sub = sva_rewrite_sampled_(mine[i].loc, cf, inst, hist_idx,
					     pre, post, init, true);
	    if (sub && sub != cf)
		  cf->set_sampled_subst(sub);
      }

      if (post.empty())
	    return;

      const struct vlltype&loc = mine[0].loc;
      pform_make_sampled_history_process_(loc, ev->event_expressions(),
					  post, init);
}

/* Build the sampler: `always @(<the same event>) <history shift>'.
 *
 * It is a SEPARATE process rather than statements spliced into the
 * reader's block, for two reasons. It must tick once per clock edge
 * whatever the reader does -- a block that waits inside its body would
 * otherwise advance the history on its own schedule, silently. And the
 * same construction then serves a reader that has no block of its own
 * to splice into (a default-clocking binding).
 *
 * The shift is NONBLOCKING, which is what makes sharing an edge with
 * the readers safe: the update lands after every Active-region read, so
 * a reader sees the previous tick's sample no matter which process the
 * scheduler picks first.
 */
static void pform_make_sampled_history_process_(
	    const struct vlltype&loc,
	    const std::vector<PEEvent*>&events,
	    std::vector<Statement*>&post,
	    std::vector<Statement*>&init)
{
      std::vector<PEEvent*> evs;
      for (size_t i = 0 ; i < events.size() ; i += 1) {
	    if (!events[i]) continue;
	    PExpr*ce = sva_clone_expr_(events[i]->expr());
	    if (!ce) return;
	    PExpr*condition = events[i]->condition()
		  ? sva_clone_expr_(events[i]->condition()) : nullptr;
	    if (events[i]->condition() && !condition) return;
	    PEEvent*ne = new PEEvent(events[i]->type(), ce, condition);
	    FILE_NAME(ne, loc);
	    evs.push_back(ne);
      }
      if (evs.empty()) return;

      PEventStatement*sampler = new PEventStatement(evs);
      FILE_NAME(sampler, loc);
      sampler->set_statement(sva_block_(loc, post));

      PProcess*pp = new PProcess(IVL_PR_ALWAYS, sampler);
      FILE_NAME(pp, loc);
      pform_mark_generated_verification_process_(pp);
      pform_put_behavior_in_scope(pp);

	/* Histories start at 0 so the first tick is deterministic. */
      if (!init.empty()) {
	    PProcess*ip = new PProcess(IVL_PR_INITIAL, sva_block_(loc, init));
	    FILE_NAME(ip, loc);
	    pform_mark_generated_verification_process_(ip);
	    pform_put_behavior_in_scope(ip);
      }
}

/* M9-SV/R14: an EXPLICIT clocking event, written as the last argument
   of the call. It outranks both the enclosing event control and the
   default clocking (IEEE 1800-2017 16.9.3, and 16.14.6's order), so it
   binds here and now rather than joining the pending list. */
void pform_bind_sampled_call_to_event(const struct vlltype&loc,
				      PECallFunction*cf,
				      PEventStatement*ev)
{
      if (!cf || !ev || ev->event_expressions().empty())
	    return;
      if (cf->sampled_subst())
	    return;

	/* Parsed mid-statement, so this can be inside a begin/end.
	   Hoist the sampler and its registers out of the PBlock. */
      sva_hoist_out_of_block_t sva_scope_guard;

      unsigned inst = sva_gensym_counter++;
      unsigned hist_idx = 0;
      std::vector<Statement*> pre, post, init;

      PExpr*sub = sva_rewrite_sampled_(loc, cf, inst, hist_idx,
				       pre, post, init, true);
      if (sub && sub != cf)
	    cf->set_sampled_subst(sub);
      if (post.empty())
	    return;

      pform_make_sampled_history_process_(loc, ev->event_expressions(),
					  post, init);
}

/* Anything still pending when a module closes was written where no
   enclosing event control could supply a clock -- in an initial block,
   a task body, a continuous assignment. IEEE 1800-2017 16.14.6 has one
   more source for those: the module's DEFAULT CLOCKING. Bind to it when
   there is one (the `$ivl_default_clock' marker resolves to the block's
   event during elaboration, so the sampler is built exactly like any
   other), and diagnose when there is not -- silence there would leave
   the VPI stub answering with the current value. */
void pform_flush_pending_sampled_calls()
{
      if (sampled_pending_.empty())
	    return;

      bool have_default = !pform_cur_module.empty()
			  && !pform_cur_module.front()->default_clocking.nil();

      if (!have_default) {
	    for (size_t i = 0 ; i < sampled_pending_.size() ; i += 1) {
		  const sampled_pending_t&p = sampled_pending_[i];
		    // p.loc, NOT p.call->get_fileline(). The call node may
		    // already be FREED: an assertion that is dropped on a
		    // `sorry' path destroys its expression tree, and this
		    // flush runs later, at endmodule. Dereferencing the
		    // stale pointer segfaulted the compiler on inputs as
		    // small as `$rose(a) |-> b and c'. The location was
		    // captured by value when the call was noted precisely
		    // so this does not have to touch the node.
		  cerr << p.loc.get_fileline() << ": warning: this sampled "
		       << "value function has no clocking event to sample on "
		       << "(IEEE 1800-2017 16.9.3): it is not inside a "
		       << "concurrent assertion, not inside an edge-triggered "
		       << "always block, and the module declares no default "
		       << "clocking. It falls back to the unsampled value -- "
		       << "$past returns the current value and $rose/$fell "
		       << "return 0." << endl;
	    }
	    sampled_pending_.clear();
	    return;
      }

      std::vector<sampled_pending_t> mine;
      mine.swap(sampled_pending_);

      const struct vlltype&loc = mine[0].loc;
      unsigned inst = sva_gensym_counter++;
      unsigned hist_idx = 0;
      std::vector<Statement*> pre, post, init;

      for (size_t i = 0 ; i < mine.size() ; i += 1) {
	    PECallFunction*cf = mine[i].call;
	    if (cf->sampled_subst())
		  continue;
	    PExpr*sub = sva_rewrite_sampled_(mine[i].loc, cf, inst, hist_idx,
					     pre, post, init, true);
	    if (sub && sub != cf)
		  cf->set_sampled_subst(sub);
      }
      if (post.empty())
	    return;

	/* `@($ivl_default_clock)': an ANYEDGE event on the marker
	   function, which PEventStatement::elaborate resolves to the
	   default clocking block's own event. */
      std::list<named_pexpr_t> no_parms;
      PECallFunction*mark = new PECallFunction(
	    perm_string::literal("$ivl_default_clock"), no_parms);
      FILE_NAME(mark, loc);
      PEEvent*devt = new PEEvent(PEEvent::ANYEDGE, mark);
      FILE_NAME(devt, loc);
      std::vector<PEEvent*> evs;
      evs.push_back(devt);

      pform_make_sampled_history_process_(loc, evs, post, init);
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
			std::map<sva_scoped_name_t, sva_param_seq_t>::iterator pit =
			      sva_resolve_(sva_param_sequences, nm);
			if (pit != sva_param_sequences.end() && pit->second.body) {
			      std::vector<sva_seq_step_t>*inst =
				    sva_instantiate_seq_(loc, nm, pit->second,
							 cf->get_parms());
			      if (inst) {
				    if (!inst->empty()) {
					  (*inst)[0].delay_lo += steps[i].delay_lo;
					  (*inst)[0].delay_hi += steps[i].delay_hi;
					  (*inst)[inst->size()-1].match_calls.insert(
						(*inst)[inst->size()-1].match_calls.end(),
						steps[i].match_calls.begin(),
						steps[i].match_calls.end());
					  steps[i].match_calls.clear();
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
	    std::map<sva_scoped_name_t, std::vector<sva_seq_step_t>*>::iterator seq_it =
		  sva_resolve_(sva_module_sequences, id->path().name.front().name);
	    if (seq_it == sva_module_sequences.end() || !seq_it->second) {
		  i += 1;
		  continue;
	    }
	    std::vector<sva_seq_step_t> body;
	    for (size_t k = 0 ; k < seq_it->second->size() ; k += 1) {
		  sva_seq_step_t st = (*seq_it->second)[k];
		  st.match_calls.clear();
		  PExpr*cp = sva_clone_expr_(st.expr);
		  PExpr*lv_cp = st.lv_rhs ? sva_clone_expr_(st.lv_rhs) : nullptr;
		  PExpr*dlo_cp = st.delay_lo_expr
			? sva_clone_expr_(st.delay_lo_expr) : nullptr;
		  PExpr*dhi_cp = st.delay_hi_expr
			? sva_clone_expr_(st.delay_hi_expr) : nullptr;
		  PExpr*rlo_cp = st.rep_lo_expr
			? sva_clone_expr_(st.rep_lo_expr) : nullptr;
		  PExpr*rhi_cp = st.rep_hi_expr
			? sva_clone_expr_(st.rep_hi_expr) : nullptr;
		  bool calls_ok = sva_clone_match_calls_(
			(*seq_it->second)[k].match_calls, st.match_calls);
		  bool had_lv = st.lv_name != perm_string();
		  if (!cp || (had_lv && !lv_cp)
		      || (st.delay_lo_expr && !dlo_cp)
		      || (st.delay_hi_expr && !dhi_cp)
		      || (st.rep_lo_expr && !rlo_cp)
		      || (st.rep_hi_expr && !rhi_cp) || !calls_ok) {
			  /* consume-once: move the tree and drop the
			     declaration so a second use is diagnosed */
			delete cp;
			delete lv_cp;
			delete dlo_cp;
			delete dhi_cp;
			delete rlo_cp;
			delete rhi_cp;
			sva_destroy_match_calls_(st.match_calls);
			cp = st.expr;
			(*seq_it->second)[k].expr = nullptr;
			lv_cp = st.lv_rhs;
			(*seq_it->second)[k].lv_rhs = nullptr;
			dlo_cp = st.delay_lo_expr;
			(*seq_it->second)[k].delay_lo_expr = nullptr;
			dhi_cp = st.delay_hi_expr;
			(*seq_it->second)[k].delay_hi_expr = nullptr;
			rlo_cp = st.rep_lo_expr;
			(*seq_it->second)[k].rep_lo_expr = nullptr;
			rhi_cp = st.rep_hi_expr;
			(*seq_it->second)[k].rep_hi_expr = nullptr;
			st.match_calls.swap((*seq_it->second)[k].match_calls);
			calls_ok = true;
		  }
		  if (!cp || (had_lv && !lv_cp)
		      || (st.delay_lo_expr && !dlo_cp)
		      || (st.delay_hi_expr && !dhi_cp)
		      || (st.rep_lo_expr && !rlo_cp)
		      || (st.rep_hi_expr && !rhi_cp) || !calls_ok) {
			cerr << loc << ": error: sequence `"
			     << seq_it->first.name << "' was already "
			     << "instantiated and its body cannot be "
			     << "copied; declare it separately for each "
			     << "use." << endl;
			error_count += 1;
			i += 1;
			cp = sva_bit_(loc, 1);
			delete lv_cp;
			lv_cp = nullptr;
			delete dlo_cp;
			delete dhi_cp;
			dlo_cp = nullptr;
			dhi_cp = nullptr;
			delete rlo_cp;
			delete rhi_cp;
			rlo_cp = nullptr;
			rhi_cp = nullptr;
			sva_destroy_match_calls_(st.match_calls);
			st.lv_name = perm_string();
		  }
		  st.expr = cp;
		  st.lv_rhs = lv_cp;
		  st.delay_lo_expr = dlo_cp;
		  st.delay_hi_expr = dhi_cp;
		  st.rep_lo_expr = rlo_cp;
		  st.rep_hi_expr = rhi_cp;
		  if (k == 0) {
			st.delay_lo += steps[i].delay_lo;
			st.delay_hi += steps[i].delay_hi;
		  }
		  body.push_back(st);
	    }
	    if (!body.empty() && !steps[i].match_calls.empty()) {
		  body.back().match_calls.insert(body.back().match_calls.end(),
			steps[i].match_calls.begin(), steps[i].match_calls.end());
		  steps[i].match_calls.clear();
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
		 std::vector<sva_seq_step_t>*steps, PExpr*lo, PExpr*hi,
		 bool unbounded)
{
      long lov = -1, hiv_eval = -1;
      bool had_hi_expr = hi != nullptr;
      bool symbolic = pform_sva_overridable_bound(lo)
		   || pform_sva_overridable_bound(hi);
      bool have_lo = pform_sva_const_long(lo, lov);
      bool have_hi = hi && pform_sva_const_long(hi, hiv_eval);
	/* `e[*m:$]' has no numeric upper bound; rep_tail = -1 marks it. */
      long hiv = unbounded ? -1 : (hi ? (have_hi ? hiv_eval : -1) : lov);

      if (!steps || steps->empty()) {
	    delete lo;
	    delete hi;
	    return steps;
      }

      for (size_t i = 0 ; i < steps->size() ; i += 1)
	    if (!(*steps)[i].match_calls.empty()) {
		  /* Keep the parsed call on the step, but mark the repeated shape
		     unsupported so the 16.11 validator emits its one targeted
		     diagnostic instead of letting expansion duplicate/drop it. */
		  delete lo;
		  delete hi;
		  (*steps)[0].delay_lo = -3;
		  (*steps)[0].delay_hi = -3;
		  return steps;
	    }

	/* An overridable parameter is not the value visible in this parse
	   scope: it is resolved separately for every elaborated module
	   instance.  Preserve the bound expressions instead of expanding the
	   declaration default into owned step nodes.  The focused implication
	   lowering below represents all ages in a parameter-sized packed vector;
	   unsupported operand/property shapes retain a loud diagnostic. */
      if (symbolic) {
	    bool plain_bool = steps->size() == 1
		&& !(*steps)[0].lv_rhs && (*steps)[0].match_calls.empty()
		&& (*steps)[0].rep_kind == 0
		&& (*steps)[0].rep_tail == 0
		&& (*steps)[0].delay_lo == 0 && (*steps)[0].delay_hi == 0;
	    if (!plain_bool || !lo || (!unbounded && had_hi_expr && !hi)) {
		  delete lo;
		  delete hi;
		  (*steps)[0].delay_lo = -3;
		  return steps;
	    }
	    (*steps)[0].rep_kind = 4;
	    (*steps)[0].rep_hi = unbounded ? -1 : 0;
	    (*steps)[0].rep_lo_expr = lo;
	    (*steps)[0].rep_hi_expr = hi;
	    return steps;
      }

      delete lo;
      delete hi;
      if (!have_lo || lov < 0) {
	    (*steps)[0].delay_lo = -3;
	    return steps;
      }
      if (!unbounded && (hiv < lov || (had_hi_expr && !have_hi))) {
	    (*steps)[0].delay_lo = -3;
	    return steps;
      }

	/* Do not expand a parse-time parameter default into billions of owned
	   expression nodes.  A later parameter override may make the effective
	   repetition small (OpenTitan prim_esc does exactly this), so the real
	   fix is symbolic/elaboration-time parameter lowering.  Until that IR
	   exists, cap both the concrete prefix and a finite optional tail to
	   preserve compiler termination and route the shape to the existing
	   loud unsupported-repetition diagnostic. */
      if (lov > 1024 || (!unbounded && hiv - lov > 1024)) {
	    (*steps)[0].delay_lo = -3;
	    (*steps)[0].delay_hi = -3;
	    return steps;
      }

	/* A zero lower bound has an empty match, which cannot be encoded by
	   cloning a concrete first step. Record this boolean consecutive
	   repetition for the automaton builder instead. */
      if (lov == 0) {
	    bool plain_bool = steps->size() == 1
		&& !(*steps)[0].lv_rhs && (*steps)[0].match_calls.empty()
		&& (*steps)[0].rep_kind == 0
		&& (*steps)[0].rep_tail == 0
		&& (*steps)[0].delay_lo == 0 && (*steps)[0].delay_hi == 0;
	    if (!plain_bool) {
		  (*steps)[0].delay_lo = -3;
		  return steps;
	    }
	    (*steps)[0].rep_kind = 3;
	    (*steps)[0].rep_lo = 0;
	    (*steps)[0].rep_hi = unbounded ? -1 : hiv;
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
		    /* A local-variable assignment rides on the step as a
		       raw owned pointer; the shallow copy above aliased it
		       across every repetition and the local-var lowering
		       then freed it once per alias -- a double-free
		       SIGSEGV for `(a, v=d)[*2]' (recovery C5). Each
		       repetition owns its own clone, so the assignment
		       re-executes per iteration (16.9.2 expansion). */
		  if (base[k].lv_rhs) {
			st.lv_rhs = sva_clone_expr_(base[k].lv_rhs);
			if (!st.lv_rhs) {
			      (*steps)[0].delay_lo = -3;
			      return steps;
			}
		  }
		  if (k == 0) {
			st.delay_lo = 1;
			st.delay_hi = 1;
		  }
		  st.rep_tail = 0;
		  steps->push_back(st);
	    }
      }
      steps->back().rep_tail = unbounded ? -1 : (hiv - lov);
      return steps;
}

/*
 * M9-NFA stage C.1: goto `b[->m:n]` (kind 1) and nonconsecutive
 * `b[=m:n]` (kind 2) repetition of a boolean (IEEE 1800-2017 16.9.2).
 * The operand must be a single boolean step; the repetition counts are
 * recorded on that step (rep_kind/rep_lo/rep_hi) for the automaton
 * engine, which builds a counting wait-loop fragment. The legacy engine
 * has no such construct and loudly rejects a rep_kind step at lowering.
 *
 * A goto/nonconsec operand that is a multi-step sequence, carries a
 * local-variable assignment, or is already a repetition is out of scope
 * (16.9.2 restricts these operators to a Boolean); such shapes are
 * marked as an unsupported repetition (delay_lo = -3), which the
 * existing lowering already diagnoses loudly. Consumes lo and hi.
 */
std::vector<sva_seq_step_t>*
pform_sva_goto_repeat(const struct vlltype&loc,
		      std::vector<sva_seq_step_t>*steps,
		      int kind, PExpr*lo, PExpr*hi, bool unbounded)
{
      (void)loc;
      long lov = -1, hiv_eval = -1;
      bool had_hi_expr = hi != nullptr;
      bool have_lo = pform_sva_const_long(lo, lov);
      bool have_hi = hi && pform_sva_const_long(hi, hiv_eval);
      long hiv = unbounded ? -1 : (hi ? (have_hi ? hiv_eval : -1) : lov);
      delete lo;
      delete hi;

      if (!steps || steps->empty())
	    return steps;

	/* Boolean-operand restriction: exactly one plain step, no local
	   variable, no existing repetition/delay shape. */
      bool ok = (steps->size() == 1)
		&& !(*steps)[0].lv_rhs
		&& (*steps)[0].match_calls.empty()
		&& (*steps)[0].rep_kind == 0
		&& (*steps)[0].rep_tail == 0
		&& (*steps)[0].delay_lo >= 0
		&& (*steps)[0].delay_lo == (*steps)[0].delay_hi;
	/* Count validity: m >= 1, and (bounded) n >= m. */
      if (ok && (!have_lo || lov < 1)) ok = false;
      if (ok && !unbounded && (hiv < lov || (had_hi_expr && !have_hi)))
	    ok = false;

      if (!ok) {
	    (*steps)[0].delay_lo = -3;
	    (*steps)[0].delay_hi = -3;
	    return steps;
      }

      (*steps)[0].rep_kind = kind;
      (*steps)[0].rep_lo = lov;
      (*steps)[0].rep_hi = hiv;   // -1 when unbounded
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
      if (sva_chain_has_match_calls_(seq)) {
	    sva_match_item_sorry_(loc,
		  "inside `throughout' are not supported yet");
	    delete guard;
	    pform_sva_destroy_sequence(seq);
	    return nullptr;
      }

	// Reject the variable-window sub-shapes up front.
      for (size_t i = 0 ; i < seq->size() ; i += 1) {
	    const sva_seq_step_t&st = (*seq)[i];
	      // rep_kind included for the same reason as in
	      // sva_chain_fixed_len_: the steps emitted below never copy
	      // rep_kind/rep_lo/rep_hi, so a repetition step that reached
	      // this legacy lowering would be silently dropped rather
	      // than diagnosed.
	    if (st.delay_lo < 0 || st.delay_lo != st.delay_hi
		|| st.rep_tail != 0 || st.rep_kind != 0) {
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
      if (sva_chain_has_match_calls_(s1)
	  || sva_chain_has_match_calls_(s2)) {
	    sva_match_item_sorry_(loc,
		  "inside `intersect' are not supported yet");
	    pform_sva_destroy_sequence(s1);
	    pform_sva_destroy_sequence(s2);
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
pform_sva_unprop(const struct vlltype&loc, int op_type, sva_property_t*sub,
		 long win_lo, long win_hi, int strength)
{
      const char*w = (op_type == 9) ? "nexttime"
		   : (op_type == 10) ? "s_nexttime"
		   : (op_type == 11) ? "s_eventually"
		   : (op_type == 12) ? (strength ? "s_always" : "always")
		   : "eventually";
      if (!sub) return nullptr;
      if (sva_property_has_match_calls_(sub)) {
	    sva_match_item_sorry_(loc,
		  "inside a unary property operator are not supported yet");
	    pform_sva_destroy_property(sub);
	    return nullptr;
      }
	/* A one-cycle `not(boolean)' is itself a one-cycle Boolean property.
	   Preserve property truth rather than applying Verilog's ordinary !:
	   an X/Z boolean does not match, so `not(p)' succeeds.  The case-
	   inequality p !== 1'b1 expresses exactly that two-state property
	   verdict and lets bounded eventual/nexttime/always compose it without
	   introducing a detached nested monitor.  Caliptra uses
	   `eventually [0:5] not(rst_n)' for reset-propagation handshakes. */
      if (sub->op_type == 3 && !sub->antecedent && !sub->tree
	  && !sub->ante_tree && sub->seq && sub->seq->size() == 1
	  && (*sub->seq)[0].delay_lo == 0 && (*sub->seq)[0].delay_hi == 0
	  && (*sub->seq)[0].rep_tail == 0 && (*sub->seq)[0].rep_kind == 0
	  && !(*sub->seq)[0].lv_rhs && !sub->clk_evt && !sub->seq_clk_evt
	  && !sub->mc_prefix && sub->mc_boundary == -1
	  && !sub->disable_iff_expr) {
	    sva_seq_step_t&st = (*sub->seq)[0];
	    PEBComp*not_true = new PEBComp('N', st.expr, sva_bit_(loc, 1));
	    FILE_NAME(not_true, loc);
	    st.expr = not_true;
	    sub->op_type = 0;
      }
      if (sub->op_type != 0 || sub->antecedent || !sub->seq
	  || sub->seq->size() != 1
	  || (*sub->seq)[0].delay_lo != 0 || (*sub->seq)[0].delay_hi != 0
	  || (*sub->seq)[0].rep_tail != 0
	  || sub->clk_evt || sub->seq_clk_evt || sub->mc_prefix
	  || sub->mc_boundary != -1 || sub->disable_iff_expr) {
	    cerr << loc << ": sorry: `" << w << "' is supported only with a "
		 << "boolean operand (no nested or sequence property); the "
		 << "assertion is dropped." << endl;
	    error_count += 1;
	    pform_sva_destroy_property(sub);
	    return nullptr;
      }
      sva_property_t*p = new sva_property_t;
      p->op_type = op_type;
      p->win_lo = win_lo;
      p->win_hi = win_hi;
      p->strength = strength;
      p->seq = sub->seq;   /* move the boolean step list */
      sub->seq = nullptr;
      pform_sva_destroy_property(sub);
      return p;
}

/*
 * M9-2: package an abort operator (IEEE 1800-2017 16.12.9). op_type:
 * 14 accept_on, 15 reject_on, 16 sync_accept_on, 17 sync_reject_on. The
 * operand must be a plain boolean property (this engine aborts a
 * single-cycle obligation); the abort condition is stored on abort_cond
 * and the boolean step list is moved onto a fresh sva_property_t lowered
 * by pform_make_assertion. Consumes cond and sub.
 */
sva_property_t*
pform_sva_abort(const struct vlltype&loc, int op_type, PExpr*cond,
		sva_property_t*sub)
{
      const char*w = (op_type == 14) ? "accept_on"
		   : (op_type == 15) ? "reject_on"
		   : (op_type == 16) ? "sync_accept_on"
		   : "sync_reject_on";
      if (!sub) { delete cond; return nullptr; }
      if (sva_property_has_match_calls_(sub)) {
	    sva_match_item_sorry_(loc,
		  "inside an abort property operator are not supported yet");
	    delete cond;
	    pform_sva_destroy_property(sub);
	    return nullptr;
      }
      if (sub->op_type != 0 || sub->antecedent || !sub->seq
	  || sub->seq->size() != 1
	  || (*sub->seq)[0].delay_lo != 0 || (*sub->seq)[0].delay_hi != 0
	  || (*sub->seq)[0].rep_tail != 0
	  || sub->clk_evt || sub->seq_clk_evt || sub->mc_prefix
	  || sub->mc_boundary != -1 || sub->disable_iff_expr) {
	    cerr << loc << ": sorry: `" << w << "' is supported only with a "
		 << "boolean operand (no nested or sequence property); the "
		 << "assertion is dropped." << endl;
	    error_count += 1;
	    delete cond;
	    pform_sva_destroy_property(sub);
	    return nullptr;
      }
      sva_property_t*p = new sva_property_t;
      p->op_type = op_type;
      p->abort_cond = cond;
      p->seq = sub->seq;   /* move the boolean step list */
      sub->seq = nullptr;
      pform_sva_destroy_property(sub);
      return p;
}

/*
 * M9-3: property combinators (IEEE 1800-2017 16.12.8). For a boolean
 * operand each combinator reduces to a single boolean property, so the
 * result is a plain op_type-0 property that the standard assertion path
 * samples and checks — no new lowering. A sequence or nested-property
 * operand cannot be collapsed this way and is a loud sorry.
 */

/* Extract the single boolean expression from a boolean sequence operand
 * (one plain step, no cycle delay or repetition). On success returns the
 * expression (ownership moved) and empties the step; on failure emits a
 * sorry and returns nullptr. The step vector is always freed. */
static PExpr* sva_take_bool_seq_(const struct vlltype&loc, const char*w,
				 std::vector<sva_seq_step_t>*seq)
{
      if (!seq) return nullptr;
      if (sva_chain_has_match_calls_(seq)) {
	    sva_match_item_sorry_(loc,
		  "inside a Boolean property combinator are not supported yet");
	    pform_sva_destroy_sequence(seq);
	    return nullptr;
      }
      PExpr*e = nullptr;
      if (seq->size() == 1 && (*seq)[0].delay_lo == 0
	  && (*seq)[0].delay_hi == 0 && (*seq)[0].rep_tail == 0) {
	    e = (*seq)[0].expr;
	    (*seq)[0].expr = nullptr;
      } else {
	    cerr << loc << ": sorry: `" << w << "' is supported only with "
		 << "boolean operands (no sequence operand); the assertion "
		 << "is dropped." << endl;
	    error_count += 1;
      }
      delete seq;
      return e;
}

/* As above but for a property operand (used by `if'/`case', whose branches
 * are property_expr). The operand must be a plain boolean property. */
static PExpr* sva_take_bool_prop_(const struct vlltype&loc, const char*w,
				  sva_property_t*sub)
{
      if (!sub) return nullptr;
      if (sva_property_has_match_calls_(sub)) {
	    sva_match_item_sorry_(loc,
		  "inside a Boolean property combinator are not supported yet");
	    pform_sva_destroy_property(sub);
	    return nullptr;
      }
      bool ok = (sub->op_type == 0 && !sub->antecedent && sub->seq
		 && sub->seq->size() == 1
		 && (*sub->seq)[0].delay_lo == 0 && (*sub->seq)[0].delay_hi == 0
		 && (*sub->seq)[0].rep_tail == 0
		 && !sub->clk_evt && !sub->seq_clk_evt && !sub->mc_prefix
		 && sub->mc_boundary == -1 && !sub->disable_iff_expr);
      PExpr*e = nullptr;
      if (ok) {
	    e = (*sub->seq)[0].expr;
	    (*sub->seq)[0].expr = nullptr;
      } else {
	    cerr << loc << ": sorry: `" << w << "' is supported only with a "
		 << "boolean branch (no sequence or nested property); the "
		 << "assertion is dropped." << endl;
	    error_count += 1;
      }
      pform_sva_destroy_property(sub);
      return e;
}

/* Wrap a boolean expression as a plain op_type-0 boolean property. */
static sva_property_t* sva_wrap_bool_(PExpr*e)
{
      if (!e) return nullptr;
      sva_property_t*p = new sva_property_t;
      p->seq = new std::vector<sva_seq_step_t>;
      sva_seq_step_t step;
      step.expr = e;
      p->seq->push_back(step);
      p->op_type = 0;
      return p;
}

sva_property_t*
pform_sva_prop_implies(const struct vlltype&loc,
		       std::vector<sva_seq_step_t>*a,
		       std::vector<sva_seq_step_t>*b)
{
      PExpr*ae = sva_take_bool_seq_(loc, "implies", a);
      PExpr*be = sva_take_bool_seq_(loc, "implies", b);
      if (!ae || !be) { delete ae; delete be; return nullptr; }
	/* a implies b  ==  !a | b */
      return sva_wrap_bool_(sva_logic_(loc, 'o', sva_not_(loc, ae), be));
}

sva_property_t*
pform_sva_prop_iff(const struct vlltype&loc,
		   std::vector<sva_seq_step_t>*a,
		   std::vector<sva_seq_step_t>*b)
{
      PExpr*ae = sva_take_bool_seq_(loc, "iff", a);
      PExpr*be = sva_take_bool_seq_(loc, "iff", b);
      if (!ae || !be) { delete ae; delete be; return nullptr; }
	/* a iff b  ==  (a & b) | (!a & !b) */
      PExpr*both = sva_logic_(loc, 'a', sva_clone_expr_(ae), sva_clone_expr_(be));
      PExpr*neither = sva_logic_(loc, 'a', sva_not_(loc, ae), sva_not_(loc, be));
      return sva_wrap_bool_(sva_logic_(loc, 'o', both, neither));
}

sva_property_t*
pform_sva_prop_if(const struct vlltype&loc, PExpr*cond,
		  sva_property_t*then_p, sva_property_t*else_p)
{
      PExpr*pe = sva_take_bool_prop_(loc, "if", then_p);
      PExpr*qe = else_p ? sva_take_bool_prop_(loc, "if", else_p) : nullptr;
      if (!cond || !pe || (else_p && !qe)) {
	    delete cond; delete pe; delete qe;
	    return nullptr;
      }
      PExpr*result;
      if (else_p) {
	      /* if (c) p else q  ==  (c & p) | (!c & q) */
	    PExpr*t = sva_logic_(loc, 'a', sva_clone_expr_(cond), pe);
	    PExpr*f = sva_logic_(loc, 'a', sva_not_(loc, cond), qe);
	    result = sva_logic_(loc, 'o', t, f);
      } else {
	      /* if (c) p  ==  !c | p  (a missing else branch is vacuously true) */
	    result = sva_logic_(loc, 'o', sva_not_(loc, cond), pe);
      }
      return sva_wrap_bool_(result);
}

sva_property_t*
pform_sva_case(const struct vlltype&loc, PExpr*sel,
	       std::vector<sva_prop_case_item_t>*items)
{
      if (!sel || !items) {
	    delete sel;
	    if (items) {
		  for (size_t k = 0 ; k < items->size() ; k += 1) {
			delete (*items)[k].vals;
			pform_sva_destroy_property((*items)[k].prop);
		  }
		  delete items;
	    }
	    return nullptr;
      }

	/* Extract a boolean expression from every branch; separate the
	   (at most one) default branch from the matched branches. */
      bool bad = false;
      PExpr*defexpr = nullptr;
      std::vector<std::pair<std::list<PExpr*>*, PExpr*> > branches;
      for (size_t k = 0 ; k < items->size() ; k += 1) {
	    PExpr*pe = sva_take_bool_prop_(loc, "case", (*items)[k].prop);
	    if (!pe) bad = true;
	    if ((*items)[k].vals == nullptr) {
		  if (defexpr) {
			cerr << loc << ": error: a `case' property has more than "
			     << "one `default' branch." << endl;
			error_count += 1;
			bad = true;
			delete pe;
		  } else {
			defexpr = pe;
		  }
	    } else {
		  branches.push_back(std::make_pair((*items)[k].vals, pe));
		  (*items)[k].vals = nullptr;   /* ownership moved */
	    }
      }
      delete items;

      if (bad) {
	    delete sel;
	    delete defexpr;
	    for (size_t k = 0 ; k < branches.size() ; k += 1) {
		  if (branches[k].first)
			for (std::list<PExpr*>::iterator it = branches[k].first->begin()
			     ; it != branches[k].first->end() ; ++it)
			      delete *it;
		  delete branches[k].first;
		  delete branches[k].second;
	    }
	    return nullptr;
      }

	/* No default -> an unmatched case evaluates to true (16.12.8). Fold
	   right-to-left so the first listed branch is checked outermost:
	     match_k ? p_k : rest   ==  (match_k & p_k) | (!match_k & rest) */
      PExpr*result = defexpr ? defexpr : sva_bit_(loc, 1);
      for (size_t i = branches.size() ; i-- > 0 ; ) {
	    std::list<PExpr*>*vals = branches[i].first;
	    PExpr*matchcond = nullptr;
	    for (std::list<PExpr*>::iterator it = vals->begin()
		 ; it != vals->end() ; ++it) {
		  PEBComp*cmp = new PEBComp('E', sva_clone_expr_(sel), *it);
		  FILE_NAME(cmp, loc);
		  matchcond = matchcond ? sva_logic_(loc, 'o', matchcond, cmp)
					: (PExpr*)cmp;
	    }
	    delete vals;   /* list shell; the value exprs are now owned by cmp */
	    if (!matchcond) matchcond = sva_bit_(loc, 0);
	    PExpr*pe = branches[i].second;
	    PExpr*t = sva_logic_(loc, 'a', sva_clone_expr_(matchcond), pe);
	    PExpr*f = sva_logic_(loc, 'a', sva_not_(loc, matchcond), result);
	    result = sva_logic_(loc, 'o', t, f);
      }
      delete sel;
      return sva_wrap_bool_(result);
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
      bool is_liveness = (op >= 9 && op <= 13);
      bool is_abort    = (op >= 14 && op <= 17);
	/* IEEE 1800-2017 A.2.10: implication with an s_eventually
	   consequent -- `a |-> s_eventually(b)' (18) and the
	   non-overlapped `a |=> s_eventually(b)' (19). */
      bool is_impl_live = (op == 18 || op == 19);
      bool with   = (op == 5 || op == 7);
      bool strong = (op == 6 || op == 7);

	/* IEEE 1800-2017 16.14.6: the action block's pass statement runs
	   when the assertion SUCCEEDS, for any property. It used to be
	   dropped here for every operator in this function, silently --
	   so `assert property (a within b) $display("ok");' never said
	   anything. It is now honoured wherever this lowering computes a
	   definite success, and refused out loud where it does not.

	   The forms it is still refused for are the ones whose obligation
	   is not discharged cycle by cycle in this lowering: the weak
	   `until' family (an attempt that has not failed yet has not
	   succeeded either), the abort operators, and the liveness
	   operators, whose per-cycle collapse settles failure but not
	   success. Refusing out loud is the point -- they used to accept
	   the statement and drop it. */
      bool pass_supported = is_within;
      if (pass_stmt && !pass_supported) {
	    cerr << loc << ": sorry: a pass action on this property "
		 << "operator is not supported (IEEE 1800-2017 16.14.6). "
		 << "Use the `else' half alone, or an `always' block on the "
		 << "same condition." << endl;
	    error_count += 1;
      }
      if (!pass_supported) {
	    delete pass_stmt;
	    pass_stmt = nullptr;
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
      perm_string r_kill = sva_kill_seen_reg_(loc, inst, 0, init_zero);
      std::vector<perm_string> attempt_state;
      attempt_state.push_back(r_f);
      std::vector<perm_string> attempt_pipe;

	/* A delayed temporal verdict is owned by the attempt that started
	   `depth' sampled clocks earlier. Keep an explicit enabled-at-start
	   pipeline instead of a time-since-start counter: `$assertoff' starts no
	   new attempts while allowing older ones to mature, and `$assertkill'
	   clears the exact live tokens without disturbing sampled-value history. */
      auto ensure_attempt_depth = [&](long depth) {
	    if (depth <= 0 || attempt_pipe.size() >= (size_t)depth) return;
	    size_t old_size = attempt_pipe.size();
	    attempt_pipe.resize((size_t)depth);
	    for (size_t k = old_size ; k < attempt_pipe.size() ; k += 1) {
		  attempt_pipe[k] = sva_make_reg_(
			loc, inst, "tpend", (unsigned)k);
		  init_zero.push_back(sva_assign_(
			loc, attempt_pipe[k], sva_bit_(loc, 0)));
		  attempt_state.push_back(attempt_pipe[k]);
	    }
      };
      auto mature_attempt = [&](long depth) -> PExpr* {
	    if (depth <= 0) return sva_enabled_expr_(loc, inst);
	    ensure_attempt_depth(depth);
	    return sva_id_(loc, attempt_pipe[(size_t)depth-1]);
      };
      auto live_attempt_range = [&](long lo, long hi) -> PExpr* {
	    ivl_assert(loc, lo >= 0 && hi >= lo);
	    ensure_attempt_depth(hi);
	    std::vector<PExpr*> terms;
	    terms.reserve((size_t)(hi - lo + 1));
	    for (long age = lo ; age <= hi ; age += 1)
		  terms.push_back(mature_attempt(age));
	    return sva_logic_reduce_(loc, 'o', terms);
      };
      bool bad = false;

      if (is_impl_live) {
	      /* ---- `a |-> s_eventually(b)' / `a |=> s_eventually(b)'.

		 For every match of the antecedent, b must hold at some
		 cycle at or after that match (`|=>': strictly after).
		 Under overlapping-attempt semantics the aggregate
		 collapses to a single pending bit: the obligation from
		 the LAST antecedent match is the strongest, because a b
		 that discharges it also discharges every earlier one. So
		 track one `pend' flag -- set by the antecedent, cleared
		 by b -- and report at end of simulation if it is still
		 set. `a' never matching leaves pend clear, which passes,
		 as it must (vacuous truth).

		 The two forms differ only in the ORDER of the set and
		 clear within a cycle:
		   |->  clear-else-set: a b in the SAME cycle as the
			antecedent match discharges it.
		   |=>  clear-then-set: b at the match cycle discharges
			only OLDER obligations; the new one needs a later b. */
	    if (kind == 2) {
		  cerr << loc << ": sorry: `cover property' of an "
		       << "implication with an `s_eventually' consequent is "
		       << "not supported; the cover is dropped." << endl;
		  error_count += 1;
		  bad = true;
	    }
	    if (!bad && (!prop->antecedent || !prop->seq)) {
		  cerr << loc << ": sorry: this `s_eventually' consequent "
		       << "shape is not supported; the assertion is dropped."
		       << endl;
		  error_count += 1;
		  bad = true;
	    }
	    if (bad) { delete fail_stmt; delete clk; delete disable; return; }

	    std::vector<sva_seq_step_t>&Aa = *prop->antecedent;
	    std::vector<sva_seq_step_t>&Bb = *prop->seq;
	    if (Aa.size() != 1 || Bb.size() != 1
		|| Aa[0].delay_lo != 0 || Aa[0].delay_hi != 0 || Aa[0].rep_tail != 0
		|| Bb[0].delay_lo != 0 || Bb[0].delay_hi != 0 || Bb[0].rep_tail != 0) {
		  cerr << loc << ": sorry: an `s_eventually' consequent is "
		       << "supported only with a boolean antecedent and a "
		       << "boolean operand (no sequence on either side); the "
		       << "assertion is dropped." << endl;
		  error_count += 1;
		  bad = true;
	    }
	    if (bad) { delete fail_stmt; delete clk; delete disable; return; }

	      /* A pass action is already refused out loud above
		 (pass_supported is false for every operator here). */

	    PExpr*ae = sva_rewrite_sampled_(loc, Aa[0].expr, inst, hist_idx,
					    pre, post, init_zero);
	    PExpr*be = sva_rewrite_sampled_(loc, Bb[0].expr, inst, hist_idx,
					    pre, post, init_zero);
	    perm_string r_a = sva_make_reg_(loc, inst, "a", 0);
	    perm_string r_b = sva_make_reg_(loc, inst, "b", 0);
	    pre.push_back(sva_assign_(loc, r_a, ae));
	    pre.push_back(sva_assign_(loc, r_b, be));

	    perm_string r_pend = sva_make_reg_(loc, inst, "pend", 0);
	    init_zero.push_back(sva_assign_(loc, r_pend, sva_bit_(loc, 0)));
	    attempt_state.push_back(r_pend);

	    Statement*set_pend = sva_assign_(loc, r_pend, sva_bit_(loc, 1));
	    Statement*clr_pend = sva_assign_(loc, r_pend, sva_bit_(loc, 0));
	    PExpr*open_cond = sva_logic_(
		  loc, 'a', sva_id_(loc, r_a), sva_enabled_expr_(loc, inst));
	    if (op == 18) {
		    /* Overlapped: if (b) pend = 0; else if (a) pend = 1; */
		  Statement*open = sva_if_(loc, open_cond, set_pend, nullptr);
		  body.push_back(sva_if_(loc, sva_id_(loc, r_b), clr_pend, open));
	    } else {
		    /* Non-overlapped: if (b) pend = 0;  then  if (a) pend = 1; */
		  body.push_back(sva_if_(loc, sva_id_(loc, r_b), clr_pend, nullptr));
		  body.push_back(sva_if_(loc, open_cond, set_pend, nullptr));
	    }

	      /* End-of-simulation obligation: s_eventually is STRONG, so a
		 still-pending obligation is a failure. */
	    Statement*action = fail_stmt;
	    if (!action) {
		  std::list<named_pexpr_t> dargs;
		  named_pexpr_t darg;
		  darg.parm = new PEString(strdup(
			"SVA: s_eventually consequent never held after the "
			"antecedent matched"));
		  dargs.push_back(darg);
		  PCallTask*warn = new PCallTask(lex_strings.make("$error"), dargs);
		  FILE_NAME(warn, loc);
		  action = warn;
	    }
	    PExpr*pending = sva_logic_(
		  loc, 'a', sva_id_(loc, r_pend),
		  sva_kill_generation_current_(loc, inst, r_kill));
	    Statement*fc = sva_if_(loc, pending,
				   sva_fail_action_(loc, inst, action), nullptr);
	    PProcess*fp = pform_make_behavior(IVL_PR_FINAL, fc, nullptr);
	    FILE_NAME(fp, loc);

      } else if (!is_within && !is_liveness && !is_abort) {
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

	    perm_string r_pend = sva_make_reg_(loc, inst, "pend", 0);
	    init_zero.push_back(sva_assign_(loc, r_pend, sva_bit_(loc, 0)));
	    attempt_state.push_back(r_pend);
	    PExpr*active = sva_logic_(loc, 'o', sva_id_(loc, r_pend),
				      sva_enabled_expr_(loc, inst));

	      /* Per-cycle weak check. */
	    PExpr*fcond;
	    if (with) {
		  fcond = sva_logic_(loc, 'a', sva_clone_expr_(active),
				 sva_not_(loc, sva_id_(loc, r_p)));
	    } else {
		  PExpr*bad_value = sva_logic_(
			loc, 'a', sva_not_(loc, sva_id_(loc, r_q)),
			sva_not_(loc, sva_id_(loc, r_p)));
		  fcond = sva_logic_(loc, 'a', sva_clone_expr_(active),
				 bad_value);
	    }
	    body.push_back(sva_if_(loc, fcond,
				   sva_assign_(loc, r_f, sva_bit_(loc, 1)),
				   nullptr));

	      /* q releases every pending attempt. A valid p keeps the collapsed
		 live set open; a failed cycle kills those attempts after their
		 failure is recorded. This state is needed for `$assertoff' even on
		 weak until: old attempts continue, but off starts no new one. */
	    Statement*open = sva_if_(loc,
		  sva_logic_(loc, 'a', active, sva_id_(loc, r_p)),
		  sva_assign_(loc, r_pend, sva_bit_(loc, 1)),
		  sva_assign_(loc, r_pend, sva_bit_(loc, 0)));
	    body.push_back(sva_if_(loc, sva_id_(loc, r_q),
		  sva_assign_(loc, r_pend, sva_bit_(loc, 0)), open));

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
		  PExpr*pending = sva_logic_(
			loc, 'a', sva_id_(loc, r_pend),
			sva_kill_generation_current_(loc, inst, r_kill));
		  Statement*fc = sva_if_(loc, pending,
					 sva_fail_action_(loc, inst, warn), nullptr);
		  PProcess*fp = pform_make_behavior(IVL_PR_FINAL, fc, nullptr);
		  FILE_NAME(fp, loc);
	    }
      } else if (is_liveness) {
	      /* ---- liveness/safety: nexttime / s_nexttime / s_eventually /
		 always / bounded eventually. The boolean operand p is in
		 prop->seq[0]. */
	    if (kind == 2) {
		  const char*w = (op == 9) ? "nexttime"
			       : (op == 10) ? "s_nexttime"
			       : (op == 11) ? "s_eventually"
			       : (op == 12) ? "always" : "eventually";
		  cerr << loc << ": sorry: `cover property' of a `" << w
		       << "' operator is not supported; the cover is dropped."
		       << endl;
		  error_count += 1;
		  delete fail_stmt; delete clk; delete disable;
		  return;
	    }
	      /* Bounded eventually (op 13) samples p across a window, so it
		 needs the raw operand; keep a clone before rewrite consumes it. */
	    PExpr*p_win_src = (op == 13)
		  ? sva_clone_expr_((*prop->seq)[0].expr) : nullptr;
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
		    /* s_eventually p (16.12.5): a STRONG obligation, and
		       `assert property' starts a fresh attempt on every
		       tick. An attempt beginning at tick t needs p at some
		       tick >= t, so the obligation window SHRINKS: later
		       attempts are strictly harder, never implied by an
		       earlier one.

		       This used to track "was p EVER seen" and report only
		       if it never was -- the cycle-0 attempt treated as
		       canonical. That silently under-reported: with p true
		       once early and never again, every later attempt is
		       undischargeable, yet the latch stayed set and NO
		       failure was reported. The identical property written
		       `1'b1 |-> s_eventually(p)' (op 18) did report it, so
		       two spellings of one property disagreed.

		       The collapse that IS valid: p holding at tick t
		       discharges every attempt started at or before t, so
		       one pending bit suffices -- set it whenever p is
		       absent (the attempt starting now is outstanding),
		       clear it whenever p holds. A trace ending with the
		       bit set has an attempt that can never complete.
		       (The same collapse is invalid for `always'-style
		       SAFETY operators, whose obligations do not shrink;
		       those keep their own per-cycle check below.) */
		  perm_string r_pend = sva_make_reg_(loc, inst, "pend", 0);
		  init_zero.push_back(sva_assign_(loc, r_pend, sva_bit_(loc, 0)));
		  attempt_state.push_back(r_pend);
		  Statement*open = sva_if_(loc, sva_enabled_expr_(loc, inst),
			sva_assign_(loc, r_pend, sva_bit_(loc, 1)), nullptr);
		  body.push_back(sva_if_(loc, sva_id_(loc, r_p),
			sva_assign_(loc, r_pend, sva_bit_(loc, 0)), open));
		  PExpr*pending = sva_logic_(
			loc, 'a', sva_id_(loc, r_pend),
			sva_kill_generation_current_(loc, inst, r_kill));
		  Statement*fc = sva_if_(loc, pending,
					 sva_fail_action_(loc, inst, action), nullptr);
		  PProcess*fp = pform_make_behavior(IVL_PR_FINAL, fc, nullptr);
		  FILE_NAME(fp, loc);
	    } else if (op == 12) {
		    /* always / always[m:n] / s_always[m:n] (16.12.7): a safety
		       obligation. With continuous checking the aggregate collapses to
		       "p holds at every cycle T >= m". Assertion control makes the
		       attempt lifetime observable, however: after Off, a finite
		       always[m:n] attempt expires at age n, while unbounded `always'
		       remains live. Keep the exact enabled-at-start age range for the
		       finite form and a persistent aggregate only for the unbounded
		       form. */
		  long lo = (prop->win_lo >= 0) ? prop->win_lo : 0;
		  bool finite = prop->win_hi >= 0;
		  perm_string r_active;
		  PExpr*active;
		  if (finite) {
			long hi = prop->win_hi < lo ? lo : prop->win_hi;
			active = live_attempt_range(lo, hi);
		  } else {
			r_active = sva_make_reg_(loc, inst, "active", 0);
			init_zero.push_back(sva_assign_(loc, r_active,
						       sva_bit_(loc, 0)));
			attempt_state.push_back(r_active);
			active = sva_logic_(loc, 'o', sva_id_(loc, r_active),
					    mature_attempt(lo));
		  }
		  PExpr*failexpr = sva_logic_(
			loc, 'a', finite ? active : sva_clone_expr_(active),
			sva_not_(loc, sva_id_(loc, r_p)));
		  PExpr*fs = sva_rewrite_sampled_(loc, failexpr, inst, hist_idx,
						  pre, post, init_zero);
		  perm_string r_ff = sva_make_reg_(loc, inst, "ff", 0);
		  pre.push_back(sva_assign_(loc, r_ff, fs));
		  attempt_state.push_back(r_ff);
		  body.push_back(sva_if_(loc, sva_id_(loc, r_ff),
					 sva_fail_action_(loc, inst, action), nullptr));
		  if (!finite)
			body.push_back(sva_assign_(loc, r_active, active));
	    } else if (op == 13) {
		    /* eventually[m:n] / s_eventually[m:n] (16.12.6): p must hold at
		       SOME cycle in the window. Checked at the window end (cycle T for
		       the attempt that started n cycles ago): that attempt fails iff p
		       held at NONE of its window cycles [T-(n-m) .. T]. Guard with
		       $past(1,n) so a window predating time 0 imposes nothing. */
		  long lo = (prop->win_lo >= 0) ? prop->win_lo : 0;
		  long hi = (prop->win_hi >= 0) ? prop->win_hi : lo;
		  if (hi < lo) hi = lo;
		  PExpr*anyp = sva_clone_expr_(p_win_src);   /* p@T */
		  for (long k = 1 ; k <= hi - lo ; k += 1) {
			PExpr*pk = sva_past_(loc, sva_clone_expr_(p_win_src), k);
			anyp = sva_logic_(loc, 'o', anyp, pk);
		  }
		  PExpr*valid = mature_attempt(hi);
		  PExpr*failexpr = sva_logic_(loc, 'a', valid, sva_not_(loc, anyp));
		  PExpr*fs = sva_rewrite_sampled_(loc, failexpr, inst, hist_idx,
						  pre, post, init_zero);
		  perm_string r_ff = sva_make_reg_(loc, inst, "ff", 0);
		  pre.push_back(sva_assign_(loc, r_ff, fs));
		  attempt_state.push_back(r_ff);
		  body.push_back(sva_if_(loc, sva_id_(loc, r_ff),
					 sva_fail_action_(loc, inst, action), nullptr));
		  delete p_win_src;
	    } else {
		    /* nexttime / s_nexttime (16.12.2): p must hold at the
		       NEXT cycle. Per attempt at cycle S that is p@(S+1);
		       aggregated, every cycle T>=1 requires p@T. A
		       $past(1,1) guard suppresses the first cycle. */
		long nt_off = (prop->win_lo >= 0) ? prop->win_lo : 1;
		PExpr*valid = mature_attempt(nt_off);
		  PExpr*failexpr = sva_logic_(loc, 'a', valid,
					      sva_not_(loc, sva_id_(loc, r_p)));
		  PExpr*fs = sva_rewrite_sampled_(loc, failexpr, inst, hist_idx,
						  pre, post, init_zero);
			  perm_string r_ff = sva_make_reg_(loc, inst, "ff", 0);
			  pre.push_back(sva_assign_(loc, r_ff, fs));
			  attempt_state.push_back(r_ff);
			  body.push_back(sva_if_(loc, sva_id_(loc, r_ff),
					 sva_fail_action_(loc, inst, action), nullptr));

		  if (op == 10) {
			  /* Strong: the attempt at the final cycle has no
			     next cycle and can never be satisfied. Report
			     once at end of simulation, guarded by a "ran"
			     flag so a zero-clock run stays quiet. */
			std::list<named_pexpr_t> dargs;
			named_pexpr_t darg;
			darg.parm = new PEString(strdup(
			      "SVA: strong nexttime obligation not met — no "
			      "next cycle for the final attempt"));
			dargs.push_back(darg);
			PCallTask*warn = new PCallTask(lex_strings.make("$error"),
						       dargs);
			FILE_NAME(warn, loc);
			PExpr*pending = nullptr;
			for (size_t k = 0 ; k < attempt_pipe.size() ; k += 1) {
			      PExpr*term = sva_id_(loc, attempt_pipe[k]);
			      pending = pending
				    ? sva_logic_(loc, 'o', pending, term) : term;
			}
			if (!pending) pending = sva_enabled_expr_(loc, inst);
			pending = sva_logic_(
			      loc, 'a', pending,
			      sva_kill_generation_current_(loc, inst, r_kill));
			Statement*fc = sva_if_(loc, pending,
					       sva_fail_action_(loc, inst, warn), nullptr);
			PProcess*fp = pform_make_behavior(IVL_PR_FINAL, fc, nullptr);
			FILE_NAME(fp, loc);
		  }
	    }
      } else if (is_abort) {
	      /* ---- abort operators (IEEE 1800-2017 16.12.9). The boolean
		 operand p is in prop->seq[0]; the abort condition is
		 prop->abort_cond. For a single-cycle boolean obligation the
		 abort collapses to a per-cycle boolean check:
		     reject_on(c) p — abort-to-FAIL on c: fail = c | !p
		     accept_on(c) p — abort-to-PASS on c: fail = !c & !p
		 Both c and p are read as sampled values at the clock tick.
		 That is exact for sync_accept_on/sync_reject_on and, for the
		 unsynced accept_on/reject_on, exact whenever the abort
		 condition changes only at the clock (the synchronous-stimulus
		 case). Like the rest of this sampled-value engine, a purely
		 asynchronous mid-cycle glitch on c is not modeled. */
	    if (kind == 2) {
		  const char*w = (op == 14) ? "accept_on"
			       : (op == 15) ? "reject_on"
			       : (op == 16) ? "sync_accept_on"
			       : "sync_reject_on";
		  cerr << loc << ": sorry: `cover property' of a `" << w
		       << "' operator is not supported; the cover is dropped."
		       << endl;
		  error_count += 1;
		  delete fail_stmt; delete clk; delete disable;
		  return;
	    }
	    bool accept = (op == 14 || op == 16);
	    PExpr*pe = (*prop->seq)[0].expr;   /* operand p (consumed below) */
	    PExpr*ce = prop->abort_cond;       /* abort condition (consumed) */
	    prop->abort_cond = nullptr;
	    PExpr*failexpr;
	    if (accept)
		  failexpr = sva_logic_(loc, 'a', sva_not_(loc, ce),
					sva_not_(loc, pe));
	    else
		  failexpr = sva_logic_(loc, 'o', ce, sva_not_(loc, pe));
	    failexpr = sva_logic_(loc, 'a', sva_enabled_expr_(loc, inst),
				 failexpr);
	    PExpr*fs = sva_rewrite_sampled_(loc, failexpr, inst, hist_idx,
					    pre, post, init_zero);
		    perm_string r_ff = sva_make_reg_(loc, inst, "ff", 0);
		    pre.push_back(sva_assign_(loc, r_ff, fs));
		    attempt_state.push_back(r_ff);
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
	      /* Kept for the success test: building the failure expression
		 below hands wmatch to it, and the sampled-value rewrite
		 then rebuilds that tree. */
	    PExpr*wmatch_pass = pass_stmt ? sva_clone_expr_(wmatch) : nullptr;

	    if (kind == 2) {
		    /* cover: count each window that matches. Warm-up
		       cycles read $past as 0, so they never miscount. */
		  PExpr*eligible = sva_logic_(
			loc, 'a', mature_attempt(L2), wmatch);
		  PExpr*ms = sva_rewrite_sampled_(loc, eligible, inst, hist_idx,
						  pre, post, init_zero);
			  perm_string r_c = sva_make_reg_(loc, inst, "m", 0);
			  pre.push_back(sva_assign_(loc, r_c, ms));
			  attempt_state.push_back(r_c);
			  perm_string r_cnt = sva_make_reg_(loc, inst, "cnt", 0, true);
		  init_zero.push_back(sva_assign_(loc, r_cnt,
			new PENumber(new verinum((uint64_t)0, 32))));
		  PEBinary*add = new PEBinary('+', sva_id_(loc, r_cnt),
					      sva_id_(loc, r_c));
		  FILE_NAME(add, loc);
		  body.push_back(sva_assign_(loc, r_cnt, add));
		  delete fail_stmt;
		  delete wmatch_pass;
		  delete pass_stmt;
		  pass_stmt = nullptr;
	    } else {
		    /* assert/assume: every mature window must match. A
		       `$past(1, L2)` guard is 0 until L2 cycles elapse, so
		       obligations that predate time 0 never fire. */
		  PExpr*valid = mature_attempt(L2);
		  PExpr*failexpr = sva_logic_(loc, 'a', valid, sva_not_(loc, wmatch));
		  PExpr*fs = sva_rewrite_sampled_(loc, failexpr, inst, hist_idx,
						  pre, post, init_zero);
			  perm_string r_ff = sva_make_reg_(loc, inst, "ff", 0);
			  pre.push_back(sva_assign_(loc, r_ff, fs));
			  attempt_state.push_back(r_ff);
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

		    /* Success: a MATURE window that matched. `valid' is the
		       same warm-up guard the failure uses, so a window that
		       predates time 0 reports neither way. Emitted only when
		       the user wrote a pass statement -- the cbAssertionSuccess
		       report for this operator is a separate gap, and adding
		       it here would change what every existing `within'
		       assertion reports to VPI. */
		  if (pass_stmt) {
			PExpr*passexpr = sva_logic_(
			      loc, 'a', mature_attempt(L2), wmatch_pass);
			wmatch_pass = nullptr;
			PExpr*ps = sva_rewrite_sampled_(loc, passexpr, inst,
							hist_idx, pre, post,
							init_zero);
				perm_string r_pf = sva_make_reg_(loc, inst, "pf", 0);
				pre.push_back(sva_assign_(loc, r_pf, ps));
				attempt_state.push_back(r_pf);
				body.push_back(sva_if_(loc, sva_id_(loc, r_pf),
				 sva_pass_action_(loc, inst, pass_stmt),
				 nullptr));
			pass_stmt = nullptr;
		  }
	    }
      }

	/* Advance enabled-at-start tokens only after this tick's verdicts have
	   consumed the old ages. Off shifts zeros in while old attempts continue;
	   kill and disable clear the whole pipe before this body can run. */
      if (!attempt_pipe.empty()) {
	    for (size_t k = attempt_pipe.size() - 1 ; k > 0 ; k -= 1)
		  body.push_back(sva_assign_(loc, attempt_pipe[k],
					     sva_id_(loc, attempt_pipe[k-1])));
	    body.push_back(sva_assign_(loc, attempt_pipe[0],
				       sva_enabled_expr_(loc, inst)));
      }

      body.insert(body.begin(), sva_if_(loc,
	    sva_enabled_expr_(loc, inst),
	    sva_report_stmt_(loc, inst, SVA_CB_START), nullptr));

      auto clear_temporal_state = [&]() -> Statement* {
	    std::vector<Statement*> clear;
	    for (size_t k = 0 ; k < attempt_state.size() ; k += 1)
		  clear.push_back(sva_assign_(
			loc, attempt_state[k], sva_bit_(loc, 0)));
	    return sva_block_(loc, clear);
      };

	/* Assemble: pre-captures; enter Observed before consulting run-time
	   assertion control; disable guard around the checker body; history
	   updates remain clock state and continue outside the attempt guard. */
      std::vector<Statement*> full = pre;
      full.push_back(sva_observed_wait_(loc));
      full.push_back(sva_kill_reset_stmt_(
	    loc, inst, r_kill, clear_temporal_state()));
      Statement*core = sva_block_(loc, body);
      if (disable) {
	    core = sva_if_(loc, disable, clear_temporal_state(), core);
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

/* M9-NFA stage A: IVL_SVA_NFA_SLOTS override for the cyclic-automaton
   attempt pool (0 = unset). */
static long sva_nfa_slots_env_()
{
      static long v = -2;
      if (v == -2) {
	    const char*env = getenv("IVL_SVA_NFA_SLOTS");
	    v = 0;
	    if (env && *env) {
		  long n = strtol(env, nullptr, 10);
		  if (n > 0) v = n;
	    }
      }
      return v;
}

/* All steps fixed literal delays (the |->/|=> antecedent EXACTNESS
   guard: a unique match length means one obligation per attempt, so
   slot emptiness is per-obligation exact). Outputs the tick-edge span
   (anchor counted) and the raw delay sum (the legacy engine's
   fixed-antecedent span measure). */
static bool sva_nfa_chain_fixed_(const std::vector<sva_seq_step_t>&steps,
				 long&edge_span, long&delay_sum)
{
      edge_span = 0;
      delay_sum = 0;
      for (size_t j = 0 ; j < steps.size() ; j += 1) {
	    const sva_seq_step_t&st = steps[j];
	    if (st.delay_lo < 0 || st.delay_lo != st.delay_hi
		|| st.rep_tail != 0 || st.rep_kind != 0)
		  return false;
	    edge_span += (j == 0 && st.delay_lo == 0) ? 1 : st.delay_lo;
	    delay_sum += st.delay_lo;
      }
      return true;
}

/* Return true when two expressions are the same simple identifier path.
   This deliberately excludes selects and every computed expression: it is
   used only by the unique-endpoint proof below, where accepting a broader
   syntactic class without a semantic equivalence proof would silently drop
   implication obligations. */
static bool sva_same_simple_ident_(PExpr*a, PExpr*b)
{
      PEIdent*ia = dynamic_cast<PEIdent*>(a);
      PEIdent*ib = dynamic_cast<PEIdent*>(b);
      if (!ia || !ib) return false;

      const pform_scoped_name_t&pa = ia->path();
      const pform_scoped_name_t&pb = ib->path();
      if (pa.package != pb.package || pa.name.size() != pb.name.size())
	    return false;

      pform_name_t::const_iterator ai = pa.name.begin();
      pform_name_t::const_iterator bi = pb.name.begin();
      for ( ; ai != pa.name.end(); ++ai, ++bi) {
	    if (ai->name != bi->name || ai->local_scope != bi->local_scope
		|| !ai->index.empty() || !bi->index.empty())
		  return false;
      }
      return true;
}

static bool sva_simple_complements_(PExpr*a, PExpr*b)
{
      PEUnary*ua = dynamic_cast<PEUnary*>(a);
      if (ua && ua->get_op() == '!'
	  && sva_same_simple_ident_(ua->get_expr(), b))
	    return true;
      PEUnary*ub = dynamic_cast<PEUnary*>(b);
      return ub && ub->get_op() == '!'
	  && sva_same_simple_ident_(a, ub->get_expr());
}

/* Recognize the canonical deterministic unbounded wait without first
   promoting its two flat chains to heap-owned tree nodes.  In

       prefix ##0 (!v)[*0:$] ##1 v |-> consequence

   each successful prefix has exactly one possible antecedent endpoint: the
   first later tick on which v is true. This is the form used by Caliptra's
   AES key-overwrite assertion. Other variable antecedents are promoted to
   trees and reach the same endpoint-obligation fan-out through the general
   path below.

   The consequence restriction is not required by the NFA constructor, but
   makes this compatibility step auditable: only the single-cycle overlapped
   property used by Caliptra enters here. */
static bool sva_nfa_unique_wait_implication_(
		const std::vector<sva_seq_step_t>&ante,
		const std::vector<sva_seq_step_t>&conseq, int op_type)
{
      if (op_type != 1 || ante.size() < 2 || conseq.size() != 1)
	    return false;

      const size_t wi = ante.size() - 2;
      const sva_seq_step_t&wait = ante[wi];
      const sva_seq_step_t&term = ante[wi + 1];
      if (wait.delay_lo != 0 || wait.delay_hi != 0
	  || wait.rep_kind != 3 || wait.rep_lo != 0 || wait.rep_hi != -1
	  || wait.rep_tail != 0 || wait.lv_rhs || !wait.match_calls.empty()
	  || term.delay_lo != 1 || term.delay_hi != 1
	  || term.rep_kind != 0 || term.rep_tail != 0 || term.lv_rhs
	  || !term.match_calls.empty()
	  || !sva_simple_complements_(wait.expr, term.expr))
	    return false;

      for (size_t i = 0 ; i < wi ; i += 1) {
	    const sva_seq_step_t&st = ante[i];
	    if (st.delay_lo < 0 || st.delay_lo != st.delay_hi
		|| st.rep_kind != 0 || st.rep_tail != 0
		|| !st.match_calls.empty())
		  return false;
      }

      const sva_seq_step_t&cs = conseq.front();
      return cs.delay_lo == 0 && cs.delay_hi == 0
	  && cs.rep_kind == 0 && cs.rep_tail == 0 && !cs.lv_rhs
	  && cs.match_calls.empty();
}

/* Would the legacy linear engine lower this chain without a sorry?
   (Mirrors the validation in pform_make_assertion below.) Consulted
   only for cyclic automata: shapes legacy handles exactly (unbounded
   final step via the pend-collapse, which cannot overflow) stay
   legacy; the NFA slot pool takes only what legacy rejects. */
static bool sva_nfa_legacy_supports_(const std::vector<sva_seq_step_t>&seq,
				     long ante_delay_sum, bool have_ante)
{
      long total = 0;
      for (size_t j = 0 ; j < seq.size() ; j += 1) {
	    bool last = (j + 1 == seq.size());
	    long lo = seq[j].delay_lo;
	    long hi = seq[j].delay_hi;
	      /* goto/nonconsecutive repetition (C.1) is automaton-only —
		 the legacy engine has no counting wait-loop for it. */
	    if (seq[j].rep_kind != 0) return false;
	    if (lo < 0) return false;
	    if (hi == -1 && !last) return false;
	    if (seq[j].rep_tail != 0 && !last) return false;
	    if (hi >= 0 && lo != hi && !last) return false;
	    total += (hi >= 0) ? hi : lo;
      }
      if (total > 512) return false;
      if (have_ante && ante_delay_sum > 128) return false;
      return true;
}

/* Stage B tree helpers: collect leaf chains; delete a tree with its
   chains (with_exprs also deletes the step expressions — used on the
   diagnostic path, where nothing consumed them). */
static void sva_tree_leaves_(sva_stree_t*t,
			     std::vector< std::vector<sva_seq_step_t>* >&out)
{
      if (!t) return;
      if (t->kind == sva_stree_t::LEAF) {
	    if (t->chain) out.push_back(t->chain);
	    return;
      }
      sva_tree_leaves_(t->a, out);
      sva_tree_leaves_(t->b, out);
}

static bool sva_chain_has_match_calls_(
      const std::vector<sva_seq_step_t>*steps)
{
      if (!steps) return false;
      for (size_t i = 0 ; i < steps->size() ; i += 1)
	    if (!(*steps)[i].match_calls.empty()) return true;
      return false;
}

static bool sva_tree_has_match_calls_(const sva_stree_t*tree)
{
      return tree && (sva_chain_has_match_calls_(tree->chain)
		      || sva_tree_has_match_calls_(tree->a)
		      || sva_tree_has_match_calls_(tree->b));
}

static bool sva_property_has_match_calls_(const sva_property_t*prop)
{
      if (!prop) return false;
      if (sva_chain_has_match_calls_(prop->antecedent)
	  || sva_chain_has_match_calls_(prop->mc_prefix)
	  || sva_chain_has_match_calls_(prop->seq)
	  || sva_tree_has_match_calls_(prop->ante_tree)
	  || sva_tree_has_match_calls_(prop->tree))
	    return true;
      if (prop->mc_more)
	    for (size_t i = 0 ; i < prop->mc_more->size() ; i += 1)
		  if (sva_chain_has_match_calls_((*prop->mc_more)[i].chain))
			return true;
      return false;
}

static int sva_match_item_sorry_(const struct vlltype&loc,
				 const char*reason)
{
      cerr << loc << ": sorry: sequence match-item subroutine calls "
	   << reason << " in the bounded IEEE 1800-2017 16.11 lowering; "
	   << "the assertion is dropped." << endl;
      error_count += 1;
      return -1;
}

/* Return 0 when there is no visible match call, 1 for the executable bounded
   shape, and -1 after exactly one targeted diagnostic. Re-run after named
   sequence splicing: a reference step itself carries no calls, while its
   declaration body does. */
static int sva_validate_match_items_(const struct vlltype&loc,
				     const sva_property_t*prop, int kind)
{
      if (!prop) return 0;
      bool tree_calls = sva_tree_has_match_calls_(prop->ante_tree)
		     || sva_tree_has_match_calls_(prop->tree);
      bool extra_clock_calls = false;
      if (prop->mc_more)
	    for (size_t i = 0 ; i < prop->mc_more->size() ; i += 1)
		  if (sva_chain_has_match_calls_((*prop->mc_more)[i].chain))
			extra_clock_calls = true;
      if (!sva_property_has_match_calls_(prop)) return 0;

      if (tree_calls)
	    return sva_match_item_sorry_(loc,
		  "inside a sequence-combinator tree are not supported yet");
      if (prop->seq_clk_evt || prop->mc_prefix || extra_clock_calls
	  || (prop->mc_more && !prop->mc_more->empty()))
	    return sva_match_item_sorry_(loc,
		  "in a multiclocked sequence are not supported yet");
      if (kind == 2)
	    return sva_match_item_sorry_(loc,
		  "in a cover property are not supported yet");
      if (prop->op_type != 0 || prop->antecedent)
	    return sva_match_item_sorry_(loc,
		  "are supported only in a flat, non-negated sequence property");
      if (!prop->seq || prop->seq->empty())
	    return sva_match_item_sorry_(loc,
		  "require a nonempty flat sequence");

      for (size_t i = 0 ; i + 1 < prop->seq->size() ; i += 1)
	    if (!(*prop->seq)[i].match_calls.empty())
		  return sva_match_item_sorry_(loc,
			"are currently supported only on the final sequence step");
      if (prop->seq->back().match_calls.empty())
	    return sva_match_item_sorry_(loc,
		  "outside the main sequence are not supported yet");

      for (size_t i = 0 ; i < prop->seq->size() ; i += 1) {
	    const sva_seq_step_t&st = (*prop->seq)[i];
	    if (st.delay_lo < 0 || st.delay_lo != st.delay_hi
		|| st.rep_tail != 0 || st.rep_kind != 0 || st.fm)
		  return sva_match_item_sorry_(loc,
			"currently require a fixed-length sequence with no repetition");
      }
      const std::vector<PCallTask*>&calls = prop->seq->back().match_calls;
      for (size_t i = 0 ; i < calls.size() ; i += 1)
	    if (!sva_match_call_is_display_(calls[i]))
		  return sva_match_item_sorry_(loc,
			"currently support only a direct $display call");
      if (!pform_sva_nfa_enabled())
	    return sva_match_item_sorry_(loc,
		  "require the automaton engine (unset IVL_SVA_LEGACY)");
      return 1;
}

static void sva_tree_delete_(sva_stree_t*t, bool with_exprs)
{
      if (!t) return;
      sva_tree_delete_(t->a, with_exprs);
      sva_tree_delete_(t->b, with_exprs);
      if (t->chain) {
	    if (with_exprs)
		  for (size_t k = 0 ; k < t->chain->size() ; k += 1) {
			  // Forget before free -- see the note in
			  // sva_expr_forget_sampled_.
			sva_expr_forget_sampled_((*t->chain)[k].expr);
			sva_expr_forget_sampled_((*t->chain)[k].lv_rhs);
			sva_expr_forget_sampled_((*t->chain)[k].delay_lo_expr);
			sva_expr_forget_sampled_((*t->chain)[k].delay_hi_expr);
			sva_expr_forget_sampled_((*t->chain)[k].rep_lo_expr);
			sva_expr_forget_sampled_((*t->chain)[k].rep_hi_expr);
			delete (*t->chain)[k].expr;
			delete (*t->chain)[k].lv_rhs;
			delete (*t->chain)[k].delay_lo_expr;
			delete (*t->chain)[k].delay_hi_expr;
			delete (*t->chain)[k].rep_lo_expr;
			delete (*t->chain)[k].rep_hi_expr;
			sva_destroy_match_calls_((*t->chain)[k].match_calls);
		  }
	    delete t->chain;
      }
      if (with_exprs && t->gexpr) {
	    sva_expr_forget_sampled_(t->gexpr);
	    delete t->gexpr;
      }
      delete t;
}

void pform_sva_destroy_sequence(std::vector<sva_seq_step_t>*seq)
{
      if (!seq) return;
      for (size_t k = 0 ; k < seq->size() ; k += 1) {
	      // Drop any pending sampled-value record that points into
	      // this tree BEFORE freeing it, or the endmodule flush will
	      // read a dangling pointer.
	    sva_expr_forget_sampled_((*seq)[k].expr);
	    sva_expr_forget_sampled_((*seq)[k].lv_rhs);
	    sva_expr_forget_sampled_((*seq)[k].delay_lo_expr);
	    sva_expr_forget_sampled_((*seq)[k].delay_hi_expr);
	    sva_expr_forget_sampled_((*seq)[k].rep_lo_expr);
	    sva_expr_forget_sampled_((*seq)[k].rep_hi_expr);
	    delete (*seq)[k].expr;
	    delete (*seq)[k].lv_rhs;
	    delete (*seq)[k].delay_lo_expr;
	    delete (*seq)[k].delay_hi_expr;
	    delete (*seq)[k].rep_lo_expr;
	    delete (*seq)[k].rep_hi_expr;
	    sva_destroy_match_calls_((*seq)[k].match_calls);
      }
      delete seq;
}

void pform_sva_destroy_mc_segments(std::vector<sva_mc_seg_t>*segs)
{
      if (!segs) return;
      for (size_t k = 0 ; k < segs->size() ; k += 1) {
	    delete (*segs)[k].clk_evt;
	    pform_sva_destroy_sequence((*segs)[k].chain);
      }
      delete segs;
}

/*
 * Is this property just a plain sequence wearing the property wrapper?
 * That is the ONE shape the flat lowerings can consume as an operand of
 * a property operator: no property operator of its own, no clock, no
 * combinator tree, no multiclock boundary, default strength.
 */
static bool sva_prop_is_plain_seq_(const sva_property_t*prop)
{
      return prop && prop->op_type == 0 && prop->seq && !prop->tree
	     && !prop->ante_tree
	     && !prop->antecedent && !prop->clk_evt && !prop->seq_clk_evt
	     && !prop->mc_prefix && (!prop->mc_more || prop->mc_more->empty())
	     && !prop->disable_iff_expr && prop->strength == 0;
}

static sva_stree_t* sva_prop_take_tree_(sva_property_t*p);

static PEventStatement* sva_clone_event_control_(
				 const PEventStatement*src,
				 const struct vlltype&loc,
				 const std::map<perm_string,PExpr*>*subst = nullptr);

static sva_stree_t* sva_chain_take_tree_(std::vector<sva_seq_step_t>*chain)
{
      if (!chain || chain->empty()) {
	    pform_sva_destroy_sequence(chain);
	    return nullptr;
      }
      sva_stree_t*t = new sva_stree_t;
      t->chain = chain;
      return t;
}

/* Non-consuming clone of a sequence-expression tree. Named sequence bodies
   are declarations and may be referenced more than once; transferring the
   declaration tree made the second assertion silently unresolved. */
static sva_stree_t* sva_tree_clone_(const struct vlltype&loc,
				    const sva_stree_t*src)
{
      if (!src) return nullptr;
      sva_stree_t*out = new sva_stree_t;
      out->kind = src->kind;
      out->concat_overlap = src->concat_overlap;
      std::map<perm_string,PExpr*> no_subst;
      if (src->chain) {
	    out->chain = sva_clone_steps_subst_(loc, src->chain, no_subst);
	    if (!out->chain) {
		  sva_tree_delete_(out, true);
		  return nullptr;
	    }
      }
      if (src->gexpr) {
	    out->gexpr = sva_clone_subst_(src->gexpr, nullptr);
	    if (!out->gexpr) {
		  sva_tree_delete_(out, true);
		  return nullptr;
	    }
      }
      if (src->a) {
	    out->a = sva_tree_clone_(loc, src->a);
	    if (!out->a) {
		  sva_tree_delete_(out, true);
		  return nullptr;
	    }
      }
      if (src->b) {
	    out->b = sva_tree_clone_(loc, src->b);
	    if (!out->b) {
		  sva_tree_delete_(out, true);
		  return nullptr;
	    }
      }
      return out;
}

/*
 * Name a property operator whose operand is a nested property rather
 * than a plain sequence. IEEE 1800-2017 A.2.10 defines property_expr
 * recursively, so these forms are LEGAL; this fork's sva_property_t
 * models a property as a flat step chain and cannot represent them yet.
 *
 * Before this existed the grammar simply had no production for them and
 * they died as a bare `syntax error', which tells the user their
 * correct code is malformed. Accepting the form and refusing it by name
 * is the honest diagnostic: it says what is unsupported, cites the
 * clause that makes it legal, and does not blame the source.
 */
static sva_property_t* sva_nested_prop_sorry_(const struct vlltype&loc,
					      const char*op,
					      const char*clause,
					      sva_property_t*sub)
{
      if (sva_property_has_match_calls_(sub)) {
	    sva_match_item_sorry_(loc,
		  "inside a nested property operator are not supported yet");
	    pform_sva_destroy_property(sub);
	    return nullptr;
      }
      cerr << loc << ": sorry: `" << op << "' with a nested property "
	   << "operand is not supported yet (IEEE 1800-2017 " << clause
	   << " makes it legal); the assertion is dropped." << endl;
      error_count += 1;
      pform_sva_destroy_property(sub);
      return nullptr;
}

/*
 * `S1 or S2 |-> c' -- a sequence combinator as an implication
 * ANTECEDENT. Legal per IEEE 1800-2017 A.2.10 (the antecedent is a
 * sequence_expr) plus 16.9.5 (or/and produce one). The flat antecedent
 * carrier cannot hold it, so this helper moves both operands into
 * sva_stree_t nodes for the automaton engine.
 *
 * The grammar previously had no production for this shape at all, so it
 * failed as a bare `syntax error'. That is much worse than it sounds:
 * the parser then desynchronizes, and when the form appears inside a
 * macro inside a generate block -- exactly how OpenTitan's alert
 * primitives write it -- the desync produces a cascade of "Invalid
 * module item" and "Malformed statement" errors attributed to
 * unrelated, perfectly good code further down the file, plus bogus
 * module end-label mismatches. The historical `_sorry' symbol name remains
 * parser ABI; supported trees now continue to NFA lowering, and an actual
 * construction refusal is still diagnosed after that offer.
 */
extern sva_property_t* pform_sva_comb_antecedent_sorry(
					const struct vlltype&loc, int op_type,
					sva_property_t*ante,
					std::vector<sva_seq_step_t>*conseq,
					bool strong_eventually);
sva_property_t* pform_sva_comb_antecedent_sorry(
					const struct vlltype&loc, int op_type,
					sva_property_t*ante,
					std::vector<sva_seq_step_t>*conseq,
					bool strong_eventually)
{
      sva_stree_t*at = sva_prop_take_tree_(ante);
      sva_stree_t*ct = sva_chain_take_tree_(conseq);
      if (!at || !ct) {
	    sva_tree_delete_(at, true);
	    sva_tree_delete_(ct, true);
	    return nullptr;
      }
      if (strong_eventually) {
	    if (!ct->chain || ct->chain->size() != 1) {
		  cerr << loc << ": sorry: an `s_eventually' consequent with a "
		       << "sequence operand is not supported yet; the assertion "
		       << "is dropped." << endl;
		  error_count += 1;
		  sva_tree_delete_(at, true);
		  sva_tree_delete_(ct, true);
		  return nullptr;
	    }
	      /* s_eventually(b) is the strong sequence ##[0:$] b. The
		 implication builder supplies the |=> boundary tick. */
	    (*ct->chain)[0].delay_lo = 0;
	    (*ct->chain)[0].delay_hi = -1;
      }
      sva_property_t*p = new sva_property_t;
      p->ante_tree = at;
      p->tree = ct;
      p->op_type = op_type;
      p->strength = strong_eventually ? 1 : 0;
      return p;
}

/* The mirror of pform_sva_comb_antecedent_sorry: move a combinator
   CONSEQUENT into the tree carrier used by the automaton engine. */
extern sva_property_t* pform_sva_comb_consequent_sorry(
					const struct vlltype&loc, int op_type,
					std::vector<sva_seq_step_t>*ante,
					sva_property_t*conseq);
sva_property_t* pform_sva_comb_consequent_sorry(
					const struct vlltype&loc, int op_type,
					std::vector<sva_seq_step_t>*ante,
					sva_property_t*conseq)
{
      sva_stree_t*at = sva_chain_take_tree_(ante);
      sva_stree_t*ct = sva_prop_take_tree_(conseq);
      if (!at || !ct) {
	    sva_tree_delete_(at, true);
	    sva_tree_delete_(ct, true);
	    return nullptr;
      }
      sva_property_t*p = new sva_property_t;
      p->ante_tree = at;
      p->tree = ct;
      p->op_type = op_type;
      return p;
}

/*
 * `a |-> ( P )' / `a |=> ( P )' -- a PARENTHESIZED property operand as
 * the consequent of an implication. IEEE 1800-2017 A.2.10 makes the
 * consequent a `property_expr', and `( property_expr )' is itself one,
 * so every property operator is legal here.
 *
 * When the parens turn out to hold a plain sequence they are pure
 * grouping: splice the chain in and build the ordinary implication,
 * identical to the unparenthesized form.
 *
 * Otherwise the operand carries property structure -- `throughout',
 * `within', an `and'/`or' combinator, a nested implication -- that
 * sva_property_t cannot hold: its consequent field `seq' is a flat
 * std::vector<sva_seq_step_t>. Refuse it BY NAME.
 *
 * Being loud here matters far beyond this one message. Without this
 * production the shape has no parse at all and dies as a bare `syntax
 * error'; the parser then desynchronizes, and when the assertion sits
 * inside a macro inside a generate block -- exactly how OpenTitan
 * writes them -- every later module item in the file is misparsed. One
 * such assertion (otbn.sv:1328, a `within') accounts for 30 of that
 * file's 43 errors, all of them attributed to unrelated, correct code.
 */
extern sva_property_t* pform_sva_paren_conseq(const struct vlltype&loc,
					      int op_type,
					      std::vector<sva_seq_step_t>*ante,
					      sva_property_t*conseq);
sva_property_t* pform_sva_paren_conseq(const struct vlltype&loc,
				       int op_type,
				       std::vector<sva_seq_step_t>*ante,
				       sva_property_t*conseq)
{
      if (!ante || !conseq) {
	    pform_sva_destroy_sequence(ante);
	    pform_sva_destroy_property(conseq);
	    return nullptr;
      }
      if (sva_chain_has_match_calls_(ante)
	  || sva_property_has_match_calls_(conseq)) {
	    sva_match_item_sorry_(loc,
		  "inside an implication property are not supported yet");
	    pform_sva_destroy_sequence(ante);
	    pform_sva_destroy_property(conseq);
	    return nullptr;
      }
      if (sva_prop_is_plain_seq_(conseq)) {
	    std::vector<sva_seq_step_t>*chain = conseq->seq;
	    conseq->seq = nullptr;
	    pform_sva_destroy_property(conseq);
	    sva_property_t*p = new sva_property_t;
	    p->antecedent = ante;
	    p->seq = chain;
	    p->op_type = op_type;
	    return p;
      }

	/* A sequence property with explicit strength is still an ordinary
	   implication consequent. Likewise, a multiclocked sequence carries
	   its first-domain prefix and later clock boundary on the property
	   wrapper itself. Move the antecedent onto that wrapper so recursive
	   grammar does not alter either representation. */
      if (conseq->op_type == 0 && conseq->seq && !conseq->tree
	  && !conseq->ante_tree && !conseq->antecedent
	  && !conseq->clk_evt && !conseq->disable_iff_expr) {
	    conseq->antecedent = ante;
	    conseq->op_type = op_type;
	    return conseq;
      }

	/* `a |-> s_eventually(b)' retains the dedicated compact liveness
	   lowering. The recursive grammar reaches the same IR that the old
	   one-off production built. */
      if (conseq->op_type == 11 && conseq->seq && !conseq->antecedent
	  && !conseq->tree && !conseq->ante_tree && !conseq->clk_evt
	  && !conseq->seq_clk_evt && !conseq->mc_prefix
	  && !conseq->disable_iff_expr) {
	    std::vector<sva_seq_step_t>*chain = conseq->seq;
	    conseq->seq = nullptr;
	    pform_sva_destroy_property(conseq);
	    sva_property_t*p = new sva_property_t;
	    p->antecedent = ante;
	    p->seq = chain;
	    p->op_type = (op_type == 1) ? 18 : 19;
	    p->strength = 1;
	    return p;
      }

	/* nexttime/s_nexttime and bounded eventually are regular sequence
	   consequences once their contextual starting point is known. */
      if ((conseq->op_type == 9 || conseq->op_type == 10
	   || conseq->op_type == 13)
	  && conseq->seq && conseq->seq->size() == 1
	  && !conseq->antecedent && !conseq->tree && !conseq->ante_tree
	  && !conseq->clk_evt && !conseq->seq_clk_evt && !conseq->mc_prefix
	  && !conseq->disable_iff_expr) {
	    sva_seq_step_t&st = (*conseq->seq)[0];
	    long lo = conseq->win_lo;
	    long hi = conseq->win_hi;
	    if (conseq->op_type == 9 || conseq->op_type == 10) {
		  if (lo < 0) lo = 1;
		  if (hi < 0) hi = lo;
	    }
	    if (lo < 0 || hi < lo) {
		  cerr << loc << ": error: invalid temporal consequent window."
		       << endl;
		  error_count += 1;
		  pform_sva_destroy_sequence(ante);
		  pform_sva_destroy_property(conseq);
		  return nullptr;
	    }
	    st.delay_lo = lo;
	    st.delay_hi = hi;
	    std::vector<sva_seq_step_t>*chain = conseq->seq;
	    int strength = (conseq->op_type == 10) ? 1 : conseq->strength;
	    conseq->seq = nullptr;
	    pform_sva_destroy_property(conseq);
	    sva_property_t*p = new sva_property_t;
	    p->antecedent = ante;
	    p->seq = chain;
	    p->op_type = op_type;
	    p->strength = strength;
	    return p;
      }

	/* Negation and safety operators are most naturally composed with an
	   implication as a forbidden sequence: a match is a failure; once the
	   antecedent has matched, death of every forbidden path is success.
	   This preserves the exact attempt boundary instead of sampling the
	   property later in a detached monitor. */
      if (conseq->op_type == 3 && conseq->seq && !conseq->antecedent
	  && !conseq->tree && !conseq->ante_tree && !conseq->clk_evt
	  && !conseq->seq_clk_evt && !conseq->mc_prefix
	  && !conseq->disable_iff_expr) {
	    std::vector<sva_seq_step_t>*bad = conseq->seq;
	    conseq->seq = nullptr;
	    pform_sva_destroy_property(conseq);
	    sva_property_t*p = new sva_property_t;
	    p->antecedent = ante;
	    p->seq = bad;
	    p->op_type = op_type;
	    p->forbidden_consequent = true;
	    return p;
      }

	/* always [m:n] p fails exactly when !p matches at any point in its
	   window. The unbounded form uses ##[0:$] !p, a looping forbidden
	   sequence whose pending state at end of simulation is success. */
      if (conseq->op_type == 12 && conseq->seq
	  && conseq->seq->size() == 1 && !conseq->antecedent
	  && !conseq->tree && !conseq->ante_tree && !conseq->clk_evt
	  && !conseq->seq_clk_evt && !conseq->mc_prefix
	  && !conseq->disable_iff_expr) {
	    sva_seq_step_t&st = (*conseq->seq)[0];
	    st.expr = sva_not_(loc, st.expr);
	    st.delay_lo = (conseq->win_lo < 0) ? 0 : conseq->win_lo;
	    st.delay_hi = (conseq->win_hi < 0) ? -1 : conseq->win_hi;
	    std::vector<sva_seq_step_t>*bad = conseq->seq;
	    conseq->seq = nullptr;
	    pform_sva_destroy_property(conseq);
	    sva_property_t*p = new sva_property_t;
	    p->antecedent = ante;
	    p->seq = bad;
	    p->op_type = op_type;
	    p->forbidden_consequent = true;
	    return p;
      }

	/* p until q is violated by the first !p&&!q tick; until_with is
	   violated by !p, including the q tick. Encode the good prefix as
	   (p&&!q)[*0:$] and fuse the bad terminal with ##0. q kills every
	   remaining path, discharging a weak obligation. A strong-until
	   property marks a still-looping path as an end-of-simulation fail. */
      if (conseq->op_type >= 4 && conseq->op_type <= 7
	  && conseq->antecedent && conseq->antecedent->size() == 1
	  && conseq->seq && conseq->seq->size() == 1
	  && !conseq->tree && !conseq->ante_tree && !conseq->clk_evt
	  && !conseq->seq_clk_evt && !conseq->mc_prefix
	  && !conseq->disable_iff_expr) {
	    sva_seq_step_t&ps = (*conseq->antecedent)[0];
	    sva_seq_step_t&qs = (*conseq->seq)[0];
	    bool plain = ps.delay_lo >= 0 && ps.delay_hi == ps.delay_lo
		       && ps.rep_tail == 0 && ps.rep_kind == 0
		       && qs.delay_lo == 0 && qs.delay_hi == 0
		       && qs.rep_tail == 0 && qs.rep_kind == 0;
	    PExpr*pc = plain ? sva_clone_expr_(ps.expr) : nullptr;
	    PExpr*qc = plain ? sva_clone_expr_(qs.expr) : nullptr;
	    if (!plain || !pc || !qc) {
		  delete pc;
		  delete qc;
		  cerr << loc << ": sorry: this `until' implication consequent "
		       << "requires boolean operands that can be contextualized; "
		       << "the assertion is dropped." << endl;
		  error_count += 1;
		  pform_sva_destroy_sequence(ante);
		  pform_sva_destroy_property(conseq);
		  return nullptr;
	    }
	    PExpr*loop = sva_logic_(loc, 'a', ps.expr,
				     sva_not_(loc, qc));
	    ps.expr = nullptr;
	    PExpr*bad = sva_not_(loc, pc);
	    bool with = conseq->op_type == 5 || conseq->op_type == 7;
	    if (!with)
		  bad = sva_logic_(loc, 'a', bad,
				   sva_not_(loc, qs.expr));
	    else
		  delete qs.expr;
	    qs.expr = nullptr;
	    int strength = (conseq->op_type == 6
			    || conseq->op_type == 7) ? 1 : 0;
	    long start_delay = ps.delay_lo;
	    pform_sva_destroy_property(conseq);

	    std::vector<sva_seq_step_t>*bad_seq =
		  new std::vector<sva_seq_step_t>;
	    sva_seq_step_t good_prefix;
	    good_prefix.expr = loop;
	    good_prefix.delay_lo = start_delay;
	    good_prefix.delay_hi = start_delay;
	    good_prefix.rep_kind = 3;
	    good_prefix.rep_lo = 0;
	    good_prefix.rep_hi = -1;
	    bad_seq->push_back(good_prefix);
	    sva_seq_step_t terminal;
	    terminal.expr = bad;
	    terminal.delay_lo = 0;
	    terminal.delay_hi = 0;
	    bad_seq->push_back(terminal);

	    sva_property_t*p = new sva_property_t;
	    p->antecedent = ante;
	    p->seq = bad_seq;
	    p->op_type = op_type;
	    p->strength = strength;
	    p->forbidden_consequent = true;
	    return p;
      }

      if (conseq->op_type == 0 && conseq->tree && !conseq->ante_tree
	  && !conseq->clk_evt && !conseq->seq_clk_evt
	  && !conseq->mc_prefix && !conseq->disable_iff_expr)
	    return pform_sva_comb_consequent_sorry(loc, op_type, ante,
						     conseq);

	/* A boolean outer implication wrapped around another implication can
	   be composed directly into the nested antecedent:

	       enable |-> (a |=> b)  ==  (enable and a) |=> b
	       enable |=> (a |=> b)  ==  (enable ##1 a) |=> b

	   For |-> both operands start on the same tick, so sequence `and'
	   correctly lets a longer nested antecedent finish later. For |=> the
	   inner property starts on the next tick, represented by a nonoverlapped
	   SEQ_CONCAT. This is the canonical expansion of OpenTitan's ASSERT_IF
	   macro and Caliptra's delayed digest/key-vault checks. */
      bool nested_impl = conseq->op_type == 1 || conseq->op_type == 2
			 || conseq->op_type == 18 || conseq->op_type == 19;
      bool outer_bool = ante->size() == 1
			&& (*ante)[0].delay_lo == 0
			&& (*ante)[0].delay_hi == 0
			&& (*ante)[0].rep_tail == 0
			&& (*ante)[0].rep_kind == 0;
      if ((op_type == 1 || op_type == 2) && nested_impl && outer_bool
	  && !conseq->clk_evt && !conseq->seq_clk_evt
	  && !conseq->mc_prefix && !conseq->disable_iff_expr) {
	    sva_stree_t*outer = sva_chain_take_tree_(ante);
	    sva_stree_t*inner_ante = conseq->ante_tree;
	    conseq->ante_tree = nullptr;
	    if (!inner_ante) {
		  inner_ante = sva_chain_take_tree_(conseq->antecedent);
		  conseq->antecedent = nullptr;
	    }
	    sva_stree_t*inner_seq = conseq->tree;
	    conseq->tree = nullptr;
	    if (!inner_seq) {
		  inner_seq = sva_chain_take_tree_(conseq->seq);
		  conseq->seq = nullptr;
	    }
	    if (!outer || !inner_ante || !inner_seq) {
		  sva_tree_delete_(outer, true);
		  sva_tree_delete_(inner_ante, true);
		  sva_tree_delete_(inner_seq, true);
		  pform_sva_destroy_property(conseq);
		  return nullptr;
	    }

	    int nested_op = conseq->op_type;
	    int strength = conseq->strength;
	    if (nested_op == 18 || nested_op == 19) {
		  if (!inner_seq->chain || inner_seq->chain->size() != 1) {
			cerr << loc << ": sorry: this nested `s_eventually' "
			     << "sequence operand is not supported; the assertion "
			     << "is dropped." << endl;
			error_count += 1;
			sva_tree_delete_(outer, true);
			sva_tree_delete_(inner_ante, true);
			sva_tree_delete_(inner_seq, true);
			pform_sva_destroy_property(conseq);
			return nullptr;
		  }
		  (*inner_seq->chain)[0].delay_lo = 0;
		  (*inner_seq->chain)[0].delay_hi = -1;
		  nested_op = (nested_op == 18) ? 1 : 2;
		  strength = 1;
	    }

	    sva_stree_t*both = new sva_stree_t;
	    both->kind = (op_type == 1) ? sva_stree_t::SEQ_AND
					 : sva_stree_t::SEQ_CONCAT;
	    both->a = outer;
	    both->b = inner_ante;
	    both->concat_overlap = false;
	    sva_property_t*p = new sva_property_t;
	    p->ante_tree = both;
	    p->tree = inner_seq;
	    p->op_type = nested_op;
	    p->strength = strength;
	    p->forbidden_consequent = conseq->forbidden_consequent;
	    pform_sva_destroy_property(conseq);
	    return p;
      }

      cerr << loc << ": sorry: a parenthesized property as the consequent "
	   << "of an implication is not supported yet (IEEE 1800-2017 "
	   << "A.2.10 makes it legal); the assertion is dropped." << endl;
      error_count += 1;
      pform_sva_destroy_sequence(ante);
      pform_sva_destroy_property(conseq);
      return nullptr;
}

/*
 * `not property_expr' (16.12.9). A plain-sequence operand lowers as it
 * always has (op_type 3); a nested property is refused by name.
 */
extern sva_property_t* pform_sva_prop_not(const struct vlltype&loc,
					  sva_property_t*sub);
sva_property_t* pform_sva_prop_not(const struct vlltype&loc,
				   sva_property_t*sub)
{
      if (!sub) return nullptr;
      if (!sva_prop_is_plain_seq_(sub))
	    return sva_nested_prop_sorry_(loc, "not", "16.12.9", sub);

      sva_property_t*p = new sva_property_t;
      p->seq = sub->seq;
      sub->seq = nullptr;
      p->op_type = 3;
      pform_sva_destroy_property(sub);
      return p;
}

void pform_sva_destroy_property(sva_property_t*prop)
{
      if (!prop) return;
      delete prop->clk_evt;
      delete prop->seq_clk_evt;
      delete prop->disable_iff_expr;
      delete prop->abort_cond;
      pform_sva_destroy_sequence(prop->antecedent);
      pform_sva_destroy_sequence(prop->mc_prefix);
      pform_sva_destroy_sequence(prop->seq);
      pform_sva_destroy_mc_segments(prop->mc_more);
      sva_tree_delete_(prop->ante_tree, true);
      sva_tree_delete_(prop->tree, true);
      delete prop;
}

/* A property_expr normally arrives without a clock and simply takes the
   property_spec prefix.  An embedded named sequence can already carry its
   declaration clock, however (`@(c) g throughout named_seq').  The old
   parse action unconditionally overwrote that clock (and even erased it
   when the outer prefix was absent).  Preserve a sole inner clock and accept
   two clocks only when their event controls are textually identical; a true
   clock-flow composition needs the dedicated 16.13 representation and must
   not be silently collapsed here.  Both disable conditions abort an attempt,
   so nested conditions compose by OR. */
sva_property_t* pform_sva_apply_property_context(
				       const struct vlltype&loc,
				       sva_property_t*prop,
				       PEventStatement*clk,
				       PExpr*disable_iff)
{
      if (!prop) {
	    delete clk;
	    delete disable_iff;
	    return nullptr;
      }
      if (prop->clk_evt && clk) {
	    ostringstream inner, outer;
	    prop->clk_evt->dump_inline(inner);
	    clk->dump_inline(outer);
	    if (inner.str() != outer.str()) {
		  cerr << loc << ": error: an embedded named sequence with clock `"
		       << inner.str() << "' is used under the incompatible clock `"
		       << outer.str() << "'; this sequence operator cannot silently "
		       << "collapse a multiclocked expression (IEEE 1800-2017 "
		       << "16.13)." << endl;
		  error_count += 1;
		  delete clk;
		  delete disable_iff;
		  pform_sva_destroy_property(prop);
		  return nullptr;
	    }
	    delete clk;
      } else if (clk) {
	    prop->clk_evt = clk;
      }
      if (disable_iff) {
	    if (prop->disable_iff_expr) {
		  PEBLogic*both = new PEBLogic(
			'o', prop->disable_iff_expr, disable_iff);
		  FILE_NAME(both, loc);
		  prop->disable_iff_expr = both;
	    } else {
		  prop->disable_iff_expr = disable_iff;
	    }
      }
      return prop;
}

sva_property_t* pform_sva_seq_comb(const struct vlltype&loc, char op,
				   std::vector<sva_seq_step_t>*s1,
				   std::vector<sva_seq_step_t>*s2)
{
      (void)loc;
      if (!s1 || !s2 || s1->empty() || s2->empty()) {
	    if (s1) {
		  for (size_t k = 0 ; k < s1->size() ; k += 1)
			delete (*s1)[k].expr;
		  delete s1;
	    }
	    if (s2) {
		  for (size_t k = 0 ; k < s2->size() ; k += 1)
			delete (*s2)[k].expr;
		  delete s2;
	    }
	    return nullptr;
      }
      sva_stree_t*la = new sva_stree_t;
      la->chain = s1;
      sva_stree_t*lb = new sva_stree_t;
      lb->chain = s2;
      sva_stree_t*t = new sva_stree_t;
      t->kind = (op == 'o') ? sva_stree_t::SEQ_OR : sva_stree_t::SEQ_AND;
      t->a = la;
      t->b = lb;
      sva_property_t*p = new sva_property_t;
      p->tree = t;
      p->op_type = 0;
      return p;
}

/* Structural fixed-length check WITHOUT consuming anything (unlike
   sva_expand_fixed_, which moves expressions as it goes): true when
   every step is a constant ##N with no repetition, with the per-cycle
   expansion length in len. */
static bool sva_chain_fixed_len_(const std::vector<sva_seq_step_t>&seq,
				 long&len)
{
      len = 0;
      for (size_t j = 0 ; j < seq.size() ; j += 1) {
	    const sva_seq_step_t&st = seq[j];
	      // rep_kind carries goto (`b[->m:n]') and nonconsecutive
	      // (`b[=m:n]') repetition, which pform_sva_goto_repeat
	      // records ONLY in rep_kind/rep_lo/rep_hi -- delay_lo and
	      // delay_hi stay at the plain 0/0 of the boolean it wraps.
	      // Omitting it here classified `b[->1]' as a fixed chain of
	      // length 1, so `g throughout b[->n]' took the legacy
	      // lowering, whose emitted steps never copy the repetition
	      // fields: the whole thing silently collapsed to `g && b'
	      // and reported violations that never happened.
	      // A goto/nonconsecutive repetition spans an unbounded
	      // number of cycles, so the chain has no fixed length.
	      // (`[*m:n]' is unaffected -- it expands into delays and
	      // rep_tail, and never sets rep_kind.)
	    if (st.delay_lo < 0 || st.delay_lo != st.delay_hi
		|| st.rep_tail != 0 || st.rep_kind != 0)
		  return false;
	    if (j == 0)
		  len = st.delay_lo + 1;
	    else if (st.delay_lo > 0)
		  len += st.delay_lo;
      }
      return true;
}

/* M9-NFA stage B.2: `intersect` entry. Equal-length fixed operands
   keep the proven legacy AND-chain lowering (identical under both
   engines); unequal FIXED lengths keep the legacy parse-time sorry
   (they can never match — both engines diagnose rather than
   synthesize an always-false checker). Only non-fixed shapes build a
   SEQ_INTERSECT product tree for the automaton engine, with the
   legacy fixed-length sorry text deferred to lowering when
   IVL_SVA_NFA is off. */
sva_property_t* pform_sva_seq_intersect(const struct vlltype&loc,
					std::vector<sva_seq_step_t>*s1,
					std::vector<sva_seq_step_t>*s2)
{
      if (!s1 || !s2 || s1->empty() || s2->empty()) {
	    delete s1; delete s2;
	    return nullptr;
      }
      long l1 = 0, l2 = 0;
      bool f1 = sva_chain_fixed_len_(*s1, l1);
      bool f2 = sva_chain_fixed_len_(*s2, l2);
      if (f1 && f2 && !sva_chain_has_match_calls_(s1)
	  && !sva_chain_has_match_calls_(s2)) {
	    std::vector<sva_seq_step_t>*tr = pform_sva_intersect(loc, s1, s2);
	    if (!tr) return nullptr;
	    sva_property_t*p = new sva_property_t;
	    p->seq = tr;
	    p->op_type = 0;
	    return p;
      }
      sva_stree_t*la = new sva_stree_t;
      la->chain = s1;
      sva_stree_t*lb = new sva_stree_t;
      lb->chain = s2;
      sva_stree_t*t = new sva_stree_t;
      t->kind = sva_stree_t::SEQ_INTERSECT;
      t->a = la;
      t->b = lb;
      sva_property_t*p = new sva_property_t;
      p->tree = t;
      p->tree_sorry = 1;
      p->op_type = 0;
      return p;
}

/* M9-NFA stage B.3: recursive combinator nesting. The grammar's
   `sva_comb_*' layer produces sva_property_t operands that already
   carry a tree (or a chain, from the legacy fixed-intersect path);
   these helpers combine them. */

/* Wrap a bare chain as a leaf-tree property (grammar `sva_comb_atom :
   sva_seq_expr'). */
sva_property_t* pform_sva_leaf_prop(std::vector<sva_seq_step_t>*chain)
{
      if (!chain || chain->empty()) {
	    if (chain) {
		  for (size_t k = 0 ; k < chain->size() ; k += 1)
			delete (*chain)[k].expr;
		  delete chain;
	    }
	    return nullptr;
      }
      sva_stree_t*t = new sva_stree_t;
      t->chain = chain;
      sva_property_t*p = new sva_property_t;
      p->tree = t;
      p->op_type = 0;
      return p;
}

/* Take the tree out of a combinator-operand property, normalizing a
   chain-bearing property (legacy fixed-intersect result) to a leaf.
   Consumes the property shell (clk/disable/antecedent are always null
   on a combinator operand). */
static sva_stree_t* sva_prop_take_tree_(sva_property_t*p)
{
      if (!p) return nullptr;
      sva_stree_t*t = nullptr;
      if (p->tree) {
	    t = p->tree;
	    p->tree = nullptr;
      } else if (p->seq) {
	    t = new sva_stree_t;
	    t->chain = p->seq;
	    p->seq = nullptr;
      }
      delete p;
      return t;
}

static bool sva_prop_is_leaf_chain_(sva_property_t*p)
{
      return p && p->tree && p->tree->kind == sva_stree_t::LEAF
	     && p->tree->chain && !p->seq;
}

sva_property_t* pform_sva_tree_comb(const struct vlltype&loc, char op,
				    sva_property_t*a, sva_property_t*b)
{
      (void)loc;
      sva_stree_t*ta = sva_prop_take_tree_(a);
      sva_stree_t*tb = sva_prop_take_tree_(b);
      if (!ta || !tb) {
	    sva_tree_delete_(ta, true);
	    sva_tree_delete_(tb, true);
	    return nullptr;
      }
      sva_stree_t*t = new sva_stree_t;
      t->kind = (op == 'o') ? sva_stree_t::SEQ_OR : sva_stree_t::SEQ_AND;
      t->a = ta;
      t->b = tb;
      sva_property_t*p = new sva_property_t;
      p->tree = t;
      p->op_type = 0;
      return p;
}

sva_property_t* pform_sva_tree_intersect(const struct vlltype&loc,
					 sva_property_t*a, sva_property_t*b)
{
	/* Both bare leaf chains: the legacy 3-way split (equal-fixed ->
	   legacy AND-chain parity, unequal-fixed -> sorry, non-fixed ->
	   product tree). This keeps a top-level `seq intersect seq'
	   identical to B.2. */
      if (sva_prop_is_leaf_chain_(a) && sva_prop_is_leaf_chain_(b)) {
	    std::vector<sva_seq_step_t>*c1 = a->tree->chain;
	    a->tree->chain = nullptr;
	    std::vector<sva_seq_step_t>*c2 = b->tree->chain;
	    b->tree->chain = nullptr;
	    sva_tree_delete_(sva_prop_take_tree_(a), false);
	    sva_tree_delete_(sva_prop_take_tree_(b), false);
	    return pform_sva_seq_intersect(loc, c1, c2);
      }
      sva_stree_t*ta = sva_prop_take_tree_(a);
      sva_stree_t*tb = sva_prop_take_tree_(b);
      if (!ta || !tb) {
	    sva_tree_delete_(ta, true);
	    sva_tree_delete_(tb, true);
	    return nullptr;
      }
      sva_stree_t*t = new sva_stree_t;
      t->kind = sva_stree_t::SEQ_INTERSECT;
      t->a = ta;
      t->b = tb;
      sva_property_t*p = new sva_property_t;
      p->tree = t;
      p->tree_sorry = 1;
      p->op_type = 0;
      return p;
}

sva_property_t* pform_sva_tree_concat(const struct vlltype&loc,
				      sva_property_t*prefix, PExpr*delay,
				      std::vector<sva_seq_step_t>*suffix)
{
      long cycles = 0;
      if (!prefix || !suffix || suffix->empty()
	  || !pform_sva_const_long(delay, cycles) || cycles < 0) {
	    if (prefix && suffix && !suffix->empty()) {
		  cerr << loc << ": error: the cycle delay after a composite "
		       << "sequence must be a known nonnegative constant "
		       << "(IEEE 1800-2017 16.9.1)." << endl;
		  error_count += 1;
	    }
	    delete delay;
	    pform_sva_destroy_property(prefix);
	    pform_sva_destroy_sequence(suffix);
	    return nullptr;
      }
      delete delay;

      sva_stree_t*left = sva_prop_take_tree_(prefix);
      if (!left) {
	    pform_sva_destroy_sequence(suffix);
	    return nullptr;
      }

	/* The suffix fragment consumes its first tick at relative offset zero.
	   ##0 therefore fuses that tick with the prefix terminal edge. For ##N,
	   N>=1, composition first crosses to a new tick and the suffix carries
	   the remaining N-1 pure-delay ticks. */
      bool overlap = cycles == 0;
      if (!overlap) {
	    sva_seq_step_t&first = suffix->front();
	    if (first.delay_lo < 0 || first.delay_hi < 0) {
		  cerr << loc << ": sorry: a composite-sequence continuation "
		       << "cannot currently combine a fixed boundary with a "
		       << "symbolic leading suffix delay; the assertion is dropped."
		       << endl;
		  error_count += 1;
		  sva_tree_delete_(left, true);
		  pform_sva_destroy_sequence(suffix);
		  return nullptr;
	    }
	    first.delay_lo += cycles - 1;
	    first.delay_hi += cycles - 1;
      }

      sva_stree_t*right = new sva_stree_t;
      right->chain = suffix;
      sva_stree_t*tree = new sva_stree_t;
      tree->kind = sva_stree_t::SEQ_CONCAT;
      tree->a = left;
      tree->b = right;
      tree->concat_overlap = overlap;
      sva_property_t*out = new sva_property_t;
      out->tree = tree;
      return out;
}

/* M9-NFA stage B.4: `within` (16.9.6). Both-fixed operands keep the
   legacy $past-sampled combinational lowering (op 8), identical under
   both engines. Any non-fixed operand builds a SEQ_WITHIN tree for the
   automaton engine (s1 padded with arbitrary prefix/suffix, then
   intersected with s2), with the legacy fixed-length sorry deferred to
   lowering when IVL_SVA_NFA is off. Consumes both chains. */
sva_property_t* pform_sva_seq_within(const struct vlltype&loc,
				     std::vector<sva_seq_step_t>*s1,
				     std::vector<sva_seq_step_t>*s2)
{
      if (!s1 || !s2 || s1->empty() || s2->empty()) {
	    delete s1; delete s2;
	    return nullptr;
      }
      long l1 = 0, l2 = 0;
      if (sva_chain_fixed_len_(*s1, l1) && sva_chain_fixed_len_(*s2, l2))
	    return pform_sva_binprop(loc, 8, s1, s2);

      sva_stree_t*la = new sva_stree_t;
      la->chain = s1;
      sva_stree_t*lb = new sva_stree_t;
      lb->chain = s2;
      sva_stree_t*t = new sva_stree_t;
      t->kind = sva_stree_t::SEQ_WITHIN;
      t->a = la;
      t->b = lb;
      sva_property_t*p = new sva_property_t;
      p->tree = t;
      p->tree_sorry = 2;
      p->op_type = 0;
      return p;
}

static sva_property_t* sva_make_throughout_tree_(PExpr*guard,
				 std::vector<sva_seq_step_t>*seq,
				 PEventStatement*clk = nullptr)
{
      sva_stree_t*leaf = new sva_stree_t;
      leaf->chain = seq;
      sva_stree_t*t = new sva_stree_t;
      t->kind = sva_stree_t::SEQ_THROUGHOUT;
      t->a = leaf;
      t->gexpr = guard;
      sva_property_t*p = new sva_property_t;
      p->tree = t;
      p->tree_sorry = 3;
      p->op_type = 0;
      p->clk_evt = clk;
      return p;
}

/* M9-NFA stage B.5: `throughout` (16.9.9). A fixed-length sequence
   keeps the legacy source-level lowering (`pform_sva_throughout` ANDs
   the invariant into every step and expands ##N gaps — exact, and
   identical under both engines). A variable-length sequence
   (##[m:n]/##[m:$]/[*m:n]), which the legacy path diagnoses, builds a
   SEQ_THROUGHOUT tree for the automaton engine (the invariant is
   AND-ed onto every tick edge, including the pure-delay window ticks),
   with the legacy sorry deferred to lowering when IVL_SVA_NFA is off.
   Consumes guard and seq. */
sva_property_t* pform_sva_seq_throughout(const struct vlltype&loc,
					 PExpr*guard,
					 std::vector<sva_seq_step_t>*seq)
{
      if (!guard || !seq || seq->empty()) {
	    delete guard;
	    if (seq) {
		  for (size_t k = 0 ; k < seq->size() ; k += 1)
			delete (*seq)[k].expr;
		  delete seq;
	    }
	    return nullptr;
      }

      /* The legacy fixed-length source rewrite moves only Boolean
	 expressions, so it cannot preserve a 16.11 action. Keep this as a
	 tree: the central validator will emit the single targeted unsupported
	 diagnostic before either engine can consume it. */
      if (sva_chain_has_match_calls_(seq))
	    return sva_make_throughout_tree_(guard, seq);

      /* A named sequence is one sequence_expr operand here, not a design
	 signal. Expand a plain declaration to a cloned chain, or a clocked /
	 combinator declaration to a cloned tree. Do this before the fixed-length
	 probe: AND-ing `guard' with the unresolved identifier would hide the
	 name from the later ordinary sequence splicer and elaborate it as a wire. */
      if (seq->size() == 1 && (*seq)[0].delay_lo == 0
	  && (*seq)[0].delay_hi == 0 && (*seq)[0].rep_tail == 0
	  && (*seq)[0].rep_kind == 0 && !(*seq)[0].lv_rhs) {
	    PEIdent*id = dynamic_cast<PEIdent*>((*seq)[0].expr);
	    if (id && !id->path().package && id->path().name.size() == 1
		&& id->path().name.front().index.empty()) {
		  perm_string nm = id->path().name.front().name;
		  std::map<sva_scoped_name_t,
			   std::vector<sva_seq_step_t>*>::iterator sit =
			sva_resolve_(sva_module_sequences, nm);
		  if (sit != sva_module_sequences.end() && sit->second) {
			std::map<perm_string,PExpr*> no_subst;
			std::vector<sva_seq_step_t>*body =
			      sva_clone_steps_subst_(loc, sit->second, no_subst);
			if (!body) {
			      cerr << loc << ": sorry: named sequence `" << nm
				   << "' cannot be cloned as the operand of "
				   << "`throughout'; the assertion is dropped."
				   << endl;
			      error_count += 1;
			      delete guard;
			      pform_sva_destroy_sequence(seq);
			      return nullptr;
			}
			pform_sva_destroy_sequence(seq);
			seq = body;
		  } else {
			std::map<sva_scoped_name_t,sva_property_t*>::iterator pit =
			      sva_resolve_(sva_module_properties, nm);
			bool is_sequence = pit != sva_module_properties.end()
			      && sva_property_shaped_sequences.count(pit->first);
			if (is_sequence) {
			      sva_property_t*decl = pit->second;
			      if (!decl) {
				    cerr << loc << ": sorry: named sequence `" << nm
					 << "' was already consumed by an unsupported "
					 << "single-use expansion; the assertion is dropped."
					 << endl;
				    error_count += 1;
				    delete guard;
				    pform_sva_destroy_sequence(seq);
				    return nullptr;
			      }
			      if (decl->seq_clk_evt || decl->mc_prefix
				  || (decl->mc_more && !decl->mc_more->empty())
				  || decl->antecedent || decl->ante_tree) {
				    cerr << loc << ": sorry: multiclocked named sequence `"
					 << nm << "' as the operand of `throughout' is not "
					 << "supported yet (IEEE 1800-2017 16.13); the "
					 << "assertion is dropped." << endl;
				    error_count += 1;
				    delete guard;
				    pform_sva_destroy_sequence(seq);
				    return nullptr;
			      }
			      sva_stree_t*body_tree = decl->tree
				    ? sva_tree_clone_(loc, decl->tree) : nullptr;
			      std::map<perm_string,PExpr*> no_subst;
			      std::vector<sva_seq_step_t>*body_seq = decl->seq
				    ? sva_clone_steps_subst_(loc, decl->seq, no_subst)
				    : nullptr;
			      PEventStatement*body_clk = decl->clk_evt
				    ? sva_clone_event_control_(decl->clk_evt, loc)
				    : nullptr;
			      if ((decl->tree && !body_tree)
				  || (decl->seq && !body_seq)
				  || (decl->clk_evt && !body_clk)) {
				    sva_tree_delete_(body_tree, true);
				    pform_sva_destroy_sequence(body_seq);
				    delete body_clk;
				    cerr << loc << ": sorry: named sequence `" << nm
					 << "' cannot be cloned as the operand of "
					 << "`throughout'; the assertion is dropped."
					 << endl;
				    error_count += 1;
				    delete guard;
				    pform_sva_destroy_sequence(seq);
				    return nullptr;
			      }
			      pform_sva_destroy_sequence(seq);
			      if (body_tree) {
				    sva_stree_t*t = new sva_stree_t;
				    t->kind = sva_stree_t::SEQ_THROUGHOUT;
				    t->a = body_tree;
				    t->gexpr = guard;
				    sva_property_t*p = new sva_property_t;
				    p->tree = t;
				    p->tree_sorry = 3;
				    p->op_type = 0;
				    p->clk_evt = body_clk;
				    pform_sva_destroy_sequence(body_seq);
				    return p;
			      }
			      seq = body_seq;
			      if (sva_chain_has_match_calls_(seq))
				    return sva_make_throughout_tree_(guard, seq,
							      body_clk);
			      /* A property-shaped declaration without a tree can still
				 carry its leading clock. Preserve it on the result below. */
			      long len = 0;
			      if (sva_chain_fixed_len_(*seq, len)) {
				    std::vector<sva_seq_step_t>*tr =
					  pform_sva_throughout(loc, guard, seq);
				    if (!tr) { delete body_clk; return nullptr; }
				    sva_property_t*p = new sva_property_t;
				    p->seq = tr;
				    p->op_type = 0;
				    p->clk_evt = body_clk;
				    return p;
			      }
			      sva_stree_t*leaf = new sva_stree_t;
			      leaf->chain = seq;
			      sva_stree_t*t = new sva_stree_t;
			      t->kind = sva_stree_t::SEQ_THROUGHOUT;
			      t->a = leaf;
			      t->gexpr = guard;
			      sva_property_t*p = new sva_property_t;
			      p->tree = t;
			      p->tree_sorry = 3;
			      p->op_type = 0;
			      p->clk_evt = body_clk;
			      return p;
			}
	  }
	}
      }
      if (sva_chain_has_match_calls_(seq))
	    return sva_make_throughout_tree_(guard, seq);
      long len = 0;
      if (sva_chain_fixed_len_(*seq, len)) {
	    std::vector<sva_seq_step_t>*tr = pform_sva_throughout(loc, guard, seq);
	    if (!tr) return nullptr;
	    sva_property_t*p = new sva_property_t;
	    p->seq = tr;
	    p->op_type = 0;
	    return p;
      }
      sva_stree_t*la = new sva_stree_t;
      la->chain = seq;
      sva_stree_t*t = new sva_stree_t;
      t->kind = sva_stree_t::SEQ_THROUGHOUT;
      t->a = la;
      t->gexpr = guard;
      sva_property_t*p = new sva_property_t;
      p->tree = t;
      p->tree_sorry = 3;
      p->op_type = 0;
      return p;
}

/* M9-NFA LV-2: does an expression read any local variable (a bare
   single-name identifier in the set)? Such guards cannot be captured
   into a shared sample register — the value is per-attempt, so they are
   evaluated per slot with the name replaced by the slot's copy. Unknown
   expression shapes conservatively return true (treated per-slot),
   which is always correct — worst case a redundant per-slot clone of a
   value-independent guard. */
static bool sva_expr_reads_lv_(PExpr*e,
			       const std::map<perm_string,unsigned>&lv)
{
      if (!e) return false;
      if (PEIdent*id = dynamic_cast<PEIdent*>(e)) {
	    /* The local may be the selected object (`v[0]') or may select a
	       design object (`vec[v]').  Both make this a per-attempt guard;
	       the latter was previously missed and collapsed all attempts into
	       one shared Boolean sample with an unresolved/live `v'. */
	    if (!id->path().package && id->path().name.size() == 1
		&& lv.count(id->path().name.front().name))
		  return true;
	    for (pform_name_t::const_iterator comp = id->path().name.begin()
		 ; comp != id->path().name.end() ; ++comp) {
		  for (std::list<index_component_t>::const_iterator idx =
			     comp->index.begin() ; idx != comp->index.end(); ++idx) {
			if (sva_expr_reads_lv_(idx->msb, lv)) return true;
			if (idx->lsb != idx->msb
			    && sva_expr_reads_lv_(idx->lsb, lv)) return true;
		  }
	    }
	    return false;
      }
      if (dynamic_cast<PENumber*>(e) || dynamic_cast<PEFNumber*>(e))
	    return false;
      if (dynamic_cast<PEString*>(e)) return false;
      if (PEUnary*un = dynamic_cast<PEUnary*>(e))
	    return sva_expr_reads_lv_(un->get_expr(), lv);
      if (PEBinary*bin = dynamic_cast<PEBinary*>(e))
	    return sva_expr_reads_lv_(bin->get_left(), lv)
		|| sva_expr_reads_lv_(bin->get_right(), lv);
      if (PEBComp*cm = dynamic_cast<PEBComp*>(e))
	    return sva_expr_reads_lv_(cm->get_left(), lv)
		|| sva_expr_reads_lv_(cm->get_right(), lv);
      if (PEBLogic*lg = dynamic_cast<PEBLogic*>(e))
	    return sva_expr_reads_lv_(lg->get_left(), lv)
		|| sva_expr_reads_lv_(lg->get_right(), lv);
      if (PETernary*t = dynamic_cast<PETernary*>(e))
	    return sva_expr_reads_lv_(t->get_cond(), lv)
		|| sva_expr_reads_lv_(t->get_true(), lv)
		|| sva_expr_reads_lv_(t->get_false(), lv);
      if (PECastSize*cast = dynamic_cast<PECastSize*>(e))
	    return sva_expr_reads_lv_(cast->cast_size(), lv)
		|| sva_expr_reads_lv_(cast->cast_base(), lv);
      if (PECastType*cast = dynamic_cast<PECastType*>(e))
	    return sva_expr_reads_lv_(cast->cast_base(), lv);
      if (PECastSign*cast = dynamic_cast<PECastSign*>(e))
	    return sva_expr_reads_lv_(cast->cast_base(), lv);
      if (PEConcat*cat = dynamic_cast<PEConcat*>(e)) {
	    const std::vector<PExpr*>&parts = cat->stream_parms();
	    for (size_t i = 0 ; i < parts.size() ; i += 1)
		  if (sva_expr_reads_lv_(parts[i], lv)) return true;
	    return sva_expr_reads_lv_(cat->repeat_expr(), lv);
      }
      if (PEInside*inside = dynamic_cast<PEInside*>(e)) {
	    if (sva_expr_reads_lv_(inside->get_expr(), lv)) return true;
	    const std::vector<inside_range_t>&ranges = inside->get_ranges();
	    for (size_t i = 0 ; i < ranges.size() ; i += 1)
		  if (sva_expr_reads_lv_(ranges[i].lo, lv)
		      || sva_expr_reads_lv_(ranges[i].hi, lv)
		      || sva_expr_reads_lv_(ranges[i].weight, lv)) return true;
	    return false;
      }
      if (PECallFunction*cf = dynamic_cast<PECallFunction*>(e)) {
	    const std::vector<named_pexpr_t>&args = cf->get_parms();
	    for (size_t i = 0 ; i < args.size() ; i += 1)
		  if (sva_expr_reads_lv_(args[i].parm, lv)) return true;
	    return false;
      }
	/* Unknown shape: be conservative (per-slot). */
      return true;
}

/* Dependent local-assignment RHS templates are cloned once per live
   attempt/obligation after their design operands are Preponed-wrapped. Keep
   that admitted expression subset structural and deliberately exclude calls:
   sampled-value calls over a per-attempt local would need per-record history,
   and a general user call has purity/lifetime requirements this lowering does
   not model. */
static bool sva_nfa_dependent_rhs_shape_(PExpr*e)
{
      if (!e) return false;
      if (PEIdent*id = dynamic_cast<PEIdent*>(e)) {
	    for (pform_name_t::const_iterator comp = id->path().name.begin()
		 ; comp != id->path().name.end() ; ++comp)
		  for (std::list<index_component_t>::const_iterator idx =
			 comp->index.begin() ; idx != comp->index.end(); ++idx) {
			if (idx->msb && !sva_nfa_dependent_rhs_shape_(idx->msb))
			      return false;
			if (idx->lsb != idx->msb && idx->lsb
			    && !sva_nfa_dependent_rhs_shape_(idx->lsb))
			      return false;
		  }
	    return true;
      }
      if (dynamic_cast<PENumber*>(e) || dynamic_cast<PEFNumber*>(e)
	  || dynamic_cast<PEString*>(e)) return true;
      if (PEUnary*un = dynamic_cast<PEUnary*>(e))
	    return sva_nfa_dependent_rhs_shape_(un->get_expr());
      if (PEBinary*bin = dynamic_cast<PEBinary*>(e)) {
	    bool known = dynamic_cast<PEBComp*>(e)
		  || dynamic_cast<PEBLogic*>(e)
		  || dynamic_cast<PEBPower*>(e)
		  || dynamic_cast<PEBShift*>(e)
		  || typeid(*e) == typeid(PEBinary);
	    return known && sva_nfa_dependent_rhs_shape_(bin->get_left())
		  && sva_nfa_dependent_rhs_shape_(bin->get_right());
      }
      if (PETernary*ter = dynamic_cast<PETernary*>(e))
	    return sva_nfa_dependent_rhs_shape_(ter->get_cond())
		  && sva_nfa_dependent_rhs_shape_(ter->get_true())
		  && sva_nfa_dependent_rhs_shape_(ter->get_false());
      if (PEInside*inside = dynamic_cast<PEInside*>(e)) {
	    if (!sva_nfa_dependent_rhs_shape_(inside->get_expr())) return false;
	    const std::vector<inside_range_t>&ranges = inside->get_ranges();
	    for (size_t i = 0 ; i < ranges.size() ; i += 1) {
		  if (ranges[i].lo
		      && !sva_nfa_dependent_rhs_shape_(ranges[i].lo)) return false;
		  if (ranges[i].hi
		      && !sva_nfa_dependent_rhs_shape_(ranges[i].hi)) return false;
		  if (ranges[i].weight
		      && !sva_nfa_dependent_rhs_shape_(ranges[i].weight))
			return false;
	    }
	    return true;
      }
      if (PECastSize*cast = dynamic_cast<PECastSize*>(e))
	    return sva_nfa_dependent_rhs_shape_(cast->cast_size())
		  && sva_nfa_dependent_rhs_shape_(cast->cast_base());
      if (PECastType*cast = dynamic_cast<PECastType*>(e))
	    return sva_nfa_dependent_rhs_shape_(cast->cast_base());
      if (PECastSign*cast = dynamic_cast<PECastSign*>(e))
	    return sva_nfa_dependent_rhs_shape_(cast->cast_base());
      if (PEConcat*cat = dynamic_cast<PEConcat*>(e)) {
	    const std::vector<PExpr*>&parts = cat->stream_parms();
	    for (size_t i = 0 ; i < parts.size() ; i += 1)
		  if (!sva_nfa_dependent_rhs_shape_(parts[i])) return false;
	    return !cat->has_repeat()
		  || sva_nfa_dependent_rhs_shape_(cat->repeat_expr());
      }
      return false;
}

/* Prove that substitution removes every property-local identifier. This
   rejects a selected local object (`first[0]') that the current structural
   substitution can copy but cannot replace, while still accepting a local
   used as a design select (`vec[first]'). */
static bool sva_nfa_dependent_rhs_substitutable_(
			       PExpr*rhs,
			       const std::map<perm_string,unsigned>&locals)
{
      if (!sva_nfa_dependent_rhs_shape_(rhs)) return false;
      std::map<perm_string,PExpr*> subst;
      for (std::map<perm_string,unsigned>::const_iterator it = locals.begin()
	   ; it != locals.end() ; ++it)
	    subst[it->first] = new PENumber(new verinum((uint64_t)0, 32));
      PExpr*copy = sva_clone_subst_(rhs, &subst);
      bool okay = copy && !sva_expr_reads_lv_(copy, locals);
      delete copy;
      for (std::map<perm_string,PExpr*>::iterator it = subst.begin()
	   ; it != subst.end() ; ++it) delete it->second;
      return okay;
}

/* A bitset NFA has one local-value carrier per attempt/obligation, not per
   simultaneously live path. A local assignment is therefore exact only when
   it occurs once on a deterministic leaf prefix, before the first construct
   that can fork that carrier into sibling paths. Reads after the fork remain
   safe when they occur on a later edge: every sibling observes the same
   captured value. A fused same-edge read is audited separately below.

   Interior tree assignments are deliberately rejected even when a particular
   SEQ_CONCAT topology might have a provable prefix. Keeping the admission
   rule syntactic and narrow prevents a branch-local write from overwriting a
   value already snapshotted by an earlier endpoint. */
static bool sva_nfa_local_prefix_safe_(
			       const sva_stree_t*tree,
			       std::map<perm_string,unsigned>&assignments,
			       const std::map<perm_string,unsigned>&locals,
			       bool&zero_inclusive_read,
			       bool&dependent_rhs_unassigned,
			       bool&dependent_rhs_unsupported)
{
      if (!tree) return true;
      if (tree->kind != sva_stree_t::LEAF) {
	    std::vector<const sva_stree_t*> pending;
	    pending.push_back(tree);
	    while (!pending.empty()) {
		  const sva_stree_t*cur = pending.back();
		  pending.pop_back();
		  if (!cur) continue;
		  if (cur->kind == sva_stree_t::LEAF) {
			if (!cur->chain) continue;
			for (size_t i = 0 ; i < cur->chain->size() ; i += 1)
			      if ((*cur->chain)[i].lv_rhs) return false;
		  } else {
			pending.push_back(cur->a);
			pending.push_back(cur->b);
		  }
	    }
	    return true;
      }
      if (!tree->chain) return true;

      bool deterministic_prefix = true;
      for (size_t i = 0 ; i < tree->chain->size() ; i += 1) {
	    const sva_seq_step_t&st = (*tree->chain)[i];
	    bool deterministic_step = st.delay_lo >= 0
		  && st.delay_lo == st.delay_hi && st.rep_tail == 0
		  && st.rep_kind == 0;
	    if (st.lv_rhs) {
		  if (!deterministic_prefix || !deterministic_step
		      || (assignments.count(st.lv_name)
			  && assignments[st.lv_name] != 0))
			return false;

		  bool dependent_rhs = false;
		  for (std::map<perm_string,unsigned>::const_iterator it =
			 locals.begin() ; it != locals.end(); ++it) {
			std::map<perm_string,unsigned>one;
			one[it->first] = 0;
			if (!sva_expr_reads_lv_(st.lv_rhs, one)) continue;
			dependent_rhs = true;
			std::map<perm_string,unsigned>::const_iterator prior =
			      assignments.find(it->first);
			if (prior == assignments.end() || prior->second == 0) {
			      dependent_rhs_unassigned = true;
			      return false;
			}
		  }
		  if (dependent_rhs
		      && !sva_nfa_dependent_rhs_substitutable_(st.lv_rhs,
							  locals)) {
			dependent_rhs_unsupported = true;
			return false;
		  }
		  assignments[st.lv_name] = 1;

		  /* Match-item assignments precede a following ##0 expression
		     semantically, but the bitset advance computes every guard before
		     it commits a local capture. Until that ordering is represented
		     explicitly, refuse a same-edge continuation that can read the
		     newly assigned local instead of silently observing its old value. */
		  std::map<perm_string,unsigned>assigned_here;
		  assigned_here[st.lv_name] = 0;
		  for (size_t j = i + 1 ; j < tree->chain->size() ; j += 1) {
			const sva_seq_step_t&next = (*tree->chain)[j];
			if (next.delay_lo != 0) break;
			if (sva_expr_reads_lv_(next.expr, assigned_here)
			    || sva_expr_reads_lv_(next.lv_rhs, assigned_here)) {
			      zero_inclusive_read = true;
			      return false;
			}
		  }
	    }
	    if (!deterministic_step) deterministic_prefix = false;
      }
      return true;
}

/*
 * M9-NFA stage A synthesizer (design: docs/conformance/
 * m9_nfa_design_2026-07-19.md). Lower a concurrent assertion through
 * the automaton engine when IVL_SVA_NFA=1 and the shape is one the
 * slot-pool model handles EXACTLY; return false to fall back to the
 * legacy linear engine. The user-visible win is mid-chain
 * window/repetition/unbounded shapes (legacy sorries); fixed chains
 * are also synthesized so the dual-run harness can prove verdict
 * parity on the shared shapes.
 *
 * Runtime model per assertion: K attempt slots, each an N-bit state
 * set over the folded tick-edge automaton. Every clock tick, the
 * first free slot is injected with the start state BEFORE the advance
 * (the anchor tick is consumed immediately, matching the legacy
 * every-cycle attempt semantics); then each slot advances:
 * nx_j = OR over edges(from->j) of (s_from && guard-sample).
 *   op 0 (plain): nx[accept] -> pass (CB-folded) once, clear slot;
 *     all-nx-dead && was-busy -> fail, clear slot; else copy.
 *   op 3 (not): accept -> fail; all-dead -> silent clear (parity: the
 *     legacy engine fires no pass action for `not`).
 *   op 1/2 (|->/|=>), fixed antecedent: composite automaton
 *     (antecedent chain ++ consequent chain, |=> as +1 on the
 *     consequent's first delay); a slot-sticky `obligated` bit marks
 *     entry into the consequence region.
 *   op 1/2 (|->/|=>), variable/combinator antecedent: the antecedent
 *     NFA remains live after an accept and every match endpoint
 *     allocates a separate consequence-NFA record.  |-> advances a
 *     newly allocated record on the endpoint tick; |=> allocates it
 *     only after existing records advance.  Each record owns its
 *     state set and a snapshot of that endpoint's sequence locals.
 * Ordinary shapes retain the legacy one-bit per-tick verdict flags. Endpoint
 * fan-out counts every consequence verdict and repeats its action/callback,
 * preserving independent obligations even when several resolve together.
 * Loop-free automata
 * get K = longest path: an attempt lives at most that many ticks, so
 * the pool provably cannot overflow. Cyclic automata (mid-chain
 * ##[m:$]) get a capped pool with a LOUD once-per-run overflow
 * warning, plus an end-of-simulation pending note matching the legacy
 * unbounded-final behavior.
 */
bool pform_sva_nfa_try_assertion(const struct vlltype&loc,
				 sva_property_t*prop,
				 Statement*fail_stmt, Statement*pass_stmt,
				 int kind)
{
      if (!prop) return false;
      bool have_tree = (prop->tree != nullptr);
      if (!have_tree && (!prop->seq || prop->seq->empty())) return false;

      if (prop->op_type < 0 || prop->op_type > 3) return false;
	/* `cover property (not ...)` is a legacy sorry; fall back for
	   the diagnostic. */
      if (kind == 2 && prop->op_type == 3) return false;
	/* An implication may carry both operands as automaton trees. */
      bool tree_implication = have_tree && prop->ante_tree
			   && (prop->op_type == 1 || prop->op_type == 2);
      if (have_tree && prop->op_type != 0 && !tree_implication)
	    return false;

	/* Expand named sequence references (idempotent; the legacy
	   path re-runs it harmlessly on fallback). */
      std::vector< std::vector<sva_seq_step_t>* > tree_leaves;
      if (have_tree) {
	    if (prop->ante_tree)
		  sva_tree_leaves_(prop->ante_tree, tree_leaves);
	    sva_tree_leaves_(prop->tree, tree_leaves);
	    for (size_t i = 0 ; i < tree_leaves.size() ; i += 1)
		  sva_splice_sequences_(loc, *tree_leaves[i]);
      } else {
	    sva_splice_sequences_(loc, *prop->seq);
	    if (prop->antecedent)
		  sva_splice_sequences_(loc, *prop->antecedent);
      }

      bool negated = (prop->op_type == 3);
      bool cover = (kind == 2);
      bool implication = (prop->op_type == 1 || prop->op_type == 2);
      bool forbidden = implication && prop->forbidden_consequent;
	/* A cover of the logical dual needs a first-class recursive-property
	   verdict rather than the assertion pass/fail dual below. Keep it on
	   the loud fallback path instead of counting forbidden matches. */
      if (cover && forbidden) return false;

      std::vector<sva_seq_step_t> chain;
      long ante_edges = 0;
      long ante_delay_sum = 0;
	/* A deterministic unbounded wait uses the implication-tree composer
	   without changing ownership: the two stack leaves borrow the property's
	   vectors until the committed cleanup below. */
      bool linear_wait_implication = false;
      if (have_tree) {
	      /* no chain: the tree is the source */
      } else if (implication) {
	    if (!prop->antecedent || prop->antecedent->empty()) return false;
	    if (!sva_nfa_chain_fixed_(*prop->antecedent,
				      ante_edges, ante_delay_sum)) {
		  if (!prop->seq || !sva_nfa_unique_wait_implication_(
			*prop->antecedent, *prop->seq, prop->op_type))
			return false;
		  linear_wait_implication = true;
	    } else {
		  std::vector<sva_seq_step_t> conseq = *prop->seq;
		  if (prop->op_type == 2) {
			conseq[0].delay_lo += 1;
			if (conseq[0].delay_hi >= 0) conseq[0].delay_hi += 1;
		  }
		    /* An overlapped (##0) consequent start fuses onto the
		       antecedent's final tick edge in the construction
		       (conjunction guards). */
		  chain = *prop->antecedent;
		  chain.insert(chain.end(), conseq.begin(), conseq.end());
	    }
      } else {
	    chain = *prop->seq;
      }

      /* The bounded 16.11 slice permits calls only on the final step of a
	 flat sequence (validated by pform_make_assertion). Keep the source
	 vector borrowed until commit, but prebuild every argument as an exact
	 Preponed expression now. If any argument cannot be represented, return
	 before synthesizing state; the caller emits the one targeted fallback
	 diagnostic instead of silently running the legacy engine. */
      const std::vector<PCallTask*>*match_calls = nullptr;
      if (!have_tree && !implication && prop->seq
	  && !prop->seq->empty() && !prop->seq->back().match_calls.empty())
	    match_calls = &prop->seq->back().match_calls;
      std::map<std::string, pform_name_t> prep_sampled;
      unsigned prep_live_operands = 0;
      std::vector< std::vector<named_pexpr_t> > match_args;
      if (match_calls) {
	    match_args.resize(match_calls->size());
	    for (size_t c = 0 ; c < match_calls->size() ; c += 1) {
		  const std::vector<named_pexpr_t>&source =
			(*match_calls)[c]->parms();
		  for (size_t a = 0 ; a < source.size() ; a += 1) {
			named_pexpr_t arg;
			arg.name = source[a].name;
			arg.parm = source[a].parm
			      ? sva_wrap_preponed_(source[a].parm, prep_sampled,
						     prep_live_operands)
			      : nullptr;
			if (source[a].parm && !arg.parm) {
			      for (size_t i = 0 ; i < match_args.size() ; i += 1)
				    for (size_t j = 0 ; j < match_args[i].size();
					 j += 1)
					  delete match_args[i][j].parm;
			      return false;
			}
			match_args[c].push_back(arg);
		  }
	    }
	      /* A match action must not read a package/unsupported operand live:
		 unlike the ordinary guard warning, doing so would violate the
		 explicit sampled-argument contract of this executable slice. */
	    if (prep_live_operands != 0) {
		  for (size_t i = 0 ; i < match_args.size() ; i += 1)
			for (size_t j = 0 ; j < match_args[i].size(); j += 1)
			      delete match_args[i][j].parm;
		  return false;
	    }
      }

	/* LV-2: collect sequence local-variable assignments left on the
	   chain by sva_lower_local_vars_ (variable-delay reads that $past
	   cannot express). Each gets per-attempt storage, and implication
	   fan-out snapshots it into every spawned obligation. */
      std::map<perm_string,unsigned> lv_index;
      std::vector<perm_string> lv_list;
      std::vector<PExpr*> lv_rhs_expr;     // per lv: rhs (borrowed)
      std::vector<PExpr*> lv_gate_expr;    // per lv: assigning-step gate (borrowed)
      {
	    std::vector<const std::vector<sva_seq_step_t>*> sources;
	    if (have_tree) {
		  for (size_t i = 0 ; i < tree_leaves.size() ; i += 1)
			sources.push_back(tree_leaves[i]);
	    } else {
		  if (linear_wait_implication) {
			sources.push_back(prop->antecedent);
			sources.push_back(prop->seq);
		  } else {
			sources.push_back(&chain);
		  }
	    }
	    for (size_t vi = 0 ; vi < sources.size() ; vi += 1)
	      for (size_t si = 0 ; si < sources[vi]->size() ; si += 1) {
			const sva_seq_step_t&st = (*sources[vi])[si];
			if (!st.lv_rhs) continue;
			perm_string nm = st.lv_name;
			if (!lv_index.count(nm)) {
			      lv_index[nm] = (unsigned)lv_list.size();
			      lv_list.push_back(nm);
			      lv_rhs_expr.push_back(st.lv_rhs);
			      lv_gate_expr.push_back(st.expr);
			}
	      }
      }
      bool has_lv = !lv_list.empty();
	/* Declaration identity is broader than storage identity. `lv_index'
	   contains assignment destinations because only those need vk/ovk
	   carriers. The dependency audit must also see declared-but-unassigned
	   locals so a bare read cannot escape to a same-named module object. */
      std::map<perm_string,unsigned> lv_analysis = lv_index;
      for (size_t li = 0 ; li < prop->local_names.size() ; li += 1)
	    lv_analysis[prop->local_names[li]] = 0;

      sva_nfa_t nfa;
      sva_stree_t linear_ante_leaf;
      sva_stree_t linear_conseq_leaf;
      if (linear_wait_implication) {
	    linear_ante_leaf.chain = prop->antecedent;
	    linear_conseq_leaf.chain = prop->seq;
      }
      bool endpoint_fanout = tree_implication || linear_wait_implication;
      /* A variable/combinator antecedent can accept at more than one tick.
	 Every such endpoint owns a separate consequence automaton.  Keep the
	 antecedent and consequence NFAs separate so accepting one consequence
	 can never clear a sibling endpoint's state. */
      sva_nfa_t consequence_nfa;
      const sva_stree_t*ante_tree = linear_wait_implication
	    ? &linear_ante_leaf : prop->ante_tree;
      const sva_stree_t*consequence_tree = linear_wait_implication
	    ? &linear_conseq_leaf : prop->tree;
	/* Assignment-bearing sibling paths need one value per live path, which
	   this bitset carrier cannot represent. Admit only the statically exact
	   deterministic-prefix subset; the caller emits the focused tree_sorry
	   diagnostic for every other topology. Apply the same proof independently
	   to the antecedent and consequence machines, and reject duplicate writes
	   to one property local across them. */
      if (endpoint_fanout && has_lv) {
	    std::map<perm_string,unsigned> assignments;
	    bool zero_inclusive_read = false;
	    bool dependent_rhs_unassigned = false;
	    bool dependent_rhs_unsupported = false;
	    if (!sva_nfa_local_prefix_safe_(ante_tree, assignments, lv_analysis,
					       zero_inclusive_read,
					       dependent_rhs_unassigned,
					       dependent_rhs_unsupported)
		|| !sva_nfa_local_prefix_safe_(consequence_tree, assignments,
					       lv_analysis, zero_inclusive_read,
					       dependent_rhs_unassigned,
					       dependent_rhs_unsupported)) {
		  prop->tree_sorry = dependent_rhs_unassigned ? 9
			: dependent_rhs_unsupported ? 8
			: zero_inclusive_read ? 7 : 6;
		  return false;
	    }
      }
      bool built = endpoint_fanout
	    ? (pform_sva_nfa_build_from_tree(nfa, ante_tree)
	       && pform_sva_nfa_build_from_tree(consequence_nfa,
					       consequence_tree))
	    : have_tree
	    ? pform_sva_nfa_build_from_tree(nfa, prop->tree)
	    : pform_sva_nfa_build_from_chain(nfa, chain);
      if (!built)
	    return false;
      if (pform_sva_nfa_dump_enabled())
	    pform_sva_nfa_dump(loc, endpoint_fanout ? "antecedent-fanout"
			   : (have_tree || linear_wait_implication) ? "tree"
				   : implication ? "composite" : "sequence",
			       nfa);
      if (endpoint_fanout && pform_sva_nfa_dump_enabled())
	    pform_sva_nfa_dump(loc, "consequence-obligation", consequence_nfa);

	/* An accept state unreachable from the start (an intersect of
	   incompatible lengths) would synthesize an always-false
	   checker; diagnose via the fallback path instead. */
      auto accept_reachable = [](const sva_nfa_t&machine) -> bool {
	    std::vector<bool> seen (machine.nstates, false);
	    std::vector<unsigned> q;
	    seen[machine.start] = true;
	    q.push_back(machine.start);
	    for (size_t h = 0 ; h < q.size() ; h += 1)
		  for (size_t i = 0 ; i < machine.edges.size() ; i += 1) {
			const sva_nfa_edge_t&ed = machine.edges[i];
			if (ed.from != q[h] || seen[ed.to]) continue;
			seen[ed.to] = true;
			q.push_back(ed.to);
		  }
	    return seen[machine.accept];
      };
      if (!accept_reachable(nfa)
	  || (endpoint_fanout && !accept_reachable(consequence_nfa)))
	    return false;

	/* LV-2: verify that each assigning-step gate survived construction.
	   A ##0-fused continuation may legitimately clone that gate onto
	   several outgoing edges (for example, the good and bad branches of
	   an `until' consequence). They all fire on the same attempt/tick and
	   store the same sampled rhs, so multiple destinations are exact, not
	   ambiguous; the capture OR below deliberately covers all of them. */
      for (unsigned li = 0 ; li < lv_list.size() ; li += 1) {
	    unsigned cnt = 0;
	    std::vector<const sva_nfa_t*> machines;
	    machines.push_back(&nfa);
	    if (endpoint_fanout) machines.push_back(&consequence_nfa);
	    for (size_t mi = 0 ; mi < machines.size() ; mi += 1)
	      for (size_t i = 0 ; i < machines[mi]->edges.size() ; i += 1)
		for (size_t g = 0 ; g < machines[mi]->edges[i].guards.size();
		     g += 1)
		  if (machines[mi]->edges[i].guards[g] == lv_gate_expr[li])
			cnt += 1;
	    if (cnt == 0) return false;
      }

      bool cyclic = pform_sva_nfa_has_cycle(nfa);
      long depth = pform_sva_nfa_depth(nfa);
      long K;
      if (!cyclic) {
	    K = depth > 0 ? depth : 1;
      } else {
	      /* Shapes the legacy engine lowers exactly stay legacy —
		 except trees (NO legacy lowering), local-variable
		 sequences (the legacy engine cannot store per-attempt
		 values), and STRONG sequence properties (C.2: the legacy
		 engine has no end-of-sim obligation for a bare sequence),
		 which MUST use the automaton's cyclic pool. */
	    if (!endpoint_fanout && !have_tree && !has_lv
		&& prop->strength == 0 && !forbidden
		&& sva_nfa_legacy_supports_(*prop->seq, ante_delay_sum,
					    implication))
		  return false;
	    K = depth > 8 ? depth : 8;
	    if (K > 16) K = 16;
	    if (sva_nfa_slots_env_() > 0) K = sva_nfa_slots_env_();
      }

      unsigned N = nfa.nstates;
      /* Preserve the established limit for ordinary one-pool NFAs. Split
	 antecedent/consequence implications need a larger aggregate allowance
	 because their exact acyclic obligation capacity is part of the checker. */
      const long generated_state_budget = endpoint_fanout ? 8192 : 1024;
      if (K <= 0 || (long)N > generated_state_budget / K) return false;
      long generated_states = (long)N * K;
      bool consequence_cyclic = endpoint_fanout
	    && pform_sva_nfa_has_cycle(consequence_nfa);
      long consequence_depth = endpoint_fanout
	    ? pform_sva_nfa_depth(consequence_nfa) : 0;
      long OK = 0;
      unsigned ON = 0;
      if (endpoint_fanout) {
	    ON = consequence_nfa.nstates;
	    long lifetime = consequence_depth > 0 ? consequence_depth : 1;
	    if (consequence_cyclic && lifetime < 8) lifetime = 8;
	    /* An antecedent slot can emit at most one endpoint per tick.
		 For an acyclic consequence, K*lifetime slots are therefore an
		 exact capacity bound. A cyclic consequence is necessarily
		 finite-pool execution; retain the established loud-overflow
		 contract and cap the generated checker size. */
	    if (K > LONG_MAX / lifetime) return false;
	    OK = K * lifetime;
	    if (consequence_cyclic && OK > 256) OK = 256;
	    if (OK < K) OK = K;
	    if (ON == 0
		|| OK > (generated_state_budget - generated_states) / (long)ON)
		  return false;
      }

	/* Obligation trigger for |->/|=>: the antecedent completes the
	   tick its final boolean fires while the attempt sits in the
	   pre-boundary state. The fixed antecedent is a single linear
	   path, so exactly one state sits at BFS depth ante_edges-1;
	   anything else is a construction surprise — fall back. */
      unsigned pre_boundary = 0;
      if (implication && !endpoint_fanout) {
	    std::vector<long> dist (N, -1);
	    std::vector<unsigned> q;
	    dist[nfa.start] = 0;
	    q.push_back(nfa.start);
	    for (size_t h = 0 ; h < q.size() ; h += 1) {
		  unsigned u = q[h];
		  for (size_t i = 0 ; i < nfa.edges.size() ; i += 1) {
			if (nfa.edges[i].from != u) continue;
			unsigned t = nfa.edges[i].to;
			if (dist[t] >= 0) continue;
			dist[t] = dist[u] + 1;
			q.push_back(t);
		  }
	    }
	    unsigned found = 0;
	    for (unsigned j = 0 ; j < N ; j += 1)
		  if (dist[j] == ante_edges - 1) {
			pre_boundary = j;
			found += 1;
		  }
	    if (found != 1) return false;
      }

	/* Clock: explicit, else the module's default clocking. On a
	   missing clock fall back — the legacy engine emits the
	   identical diagnostic. */
      PEventStatement*clk = prop->clk_evt;
      if (!clk) {
	    Module*mod = pform_cur_module.empty() ? nullptr
			 : pform_cur_module.front();
	    if (!mod || mod->default_clocking.nil())
		  return false;
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

	/* ---- Committed: everything below consumes the property. ---- */

      unsigned inst = sva_gensym_counter++;
      unsigned hist_idx = 0;
      std::vector<Statement*> pre, post, init_zero;

	/* Rewrite sampled-value functions in the already-Preponed action
	   arguments against this checker's history state, then rebuild the
	   direct $display calls in source order. These statements are folded
	   ahead of the user's property pass action below, so a successful
	   attempt observes sequence-match ordering exactly once. */
      Statement*match_action = nullptr;
      if (match_calls) {
	    std::vector<Statement*>actions;
	    for (size_t c = 0 ; c < match_calls->size() ; c += 1) {
		  std::list<named_pexpr_t>args;
		  for (size_t a = 0 ; a < match_args[c].size() ; a += 1) {
			named_pexpr_t arg = match_args[c][a];
			arg.parm = sva_rewrite_sampled_(loc, arg.parm, inst,
						 hist_idx, pre, post, init_zero);
			args.push_back(arg);
		  }
		  PCallTask*call = new PCallTask((*match_calls)[c]->path(), args);
		  call->set_lineno((*match_calls)[c]->get_lineno());
		  call->set_file((*match_calls)[c]->get_file());
		  actions.push_back(call);
	    }
	    match_action = sva_block_(loc, actions);
      }

	/* M12B-cb SUCCESS fold (the NFA hook runs before the legacy
	   fold, so replicate it): every match reports
	   cbAssertionSuccess; negated properties have no pass path and
	   cover keeps only its counter (matching the legacy engine). */
      if (!negated && !cover) {
	    if (match_action) {
		  std::vector<Statement*>ordered;
		  ordered.push_back(match_action);
		  if (pass_stmt) ordered.push_back(pass_stmt);
		  pass_stmt = sva_block_(loc, ordered);
		  match_action = nullptr;
	    }
	    pass_stmt = sva_pass_action_(loc, inst, pass_stmt);
      }

	/* disable iff: own, else the module default (cloned). */
      PExpr*disable = prop->disable_iff_expr;
      if (!disable && sva_default_disable) {
	    disable = sva_clone_expr_(sva_default_disable);
	    if (!disable) {
		  cerr << loc << ": sorry: the `default disable iff` "
		       << "expression is too complex to copy; this "
		       << "assertion runs without it." << endl;
	    }
      }

	/* Capture each DISTINCT edge guard once into a 1-bit sample
	   register (sampled-value functions rewritten to history
	   chains); the automaton's borrowed guard pointers map to the
	   samples by pointer identity. Walking the built automaton's
	   edges (rather than the source chains) captures exactly the
	   booleans actually used — chain-step exprs, ##0-fusion
	   conjuncts, and a `throughout' invariant AND-ed onto every
	   edge (which is not a chain step). */
      std::map<PExpr*, perm_string> guard_reg;
	/* A guard that also reads a per-attempt local cannot collapse into one
	   shared Boolean sample. Keep a rewritten expression template instead:
	   design-signal operands are still Preponed samples, while the bare local
	   identifiers remain holes replaced with the current slot's registers. */
      std::map<PExpr*, PExpr*> local_guard_expr;
	/* M6B-4: signals whose preponed value the guards read, and the
	   count of operands that had to stay live (see sva_wrap_preponed_). */
      {
	    unsigned bidx = 0;
	    std::vector<const sva_nfa_t*> machines;
	    machines.push_back(&nfa);
	    if (endpoint_fanout) machines.push_back(&consequence_nfa);
	    for (size_t mi = 0 ; mi < machines.size() ; mi += 1)
	      for (size_t i = 0 ; i < machines[mi]->edges.size() ; i += 1) {
		  const std::vector<PExpr*>&gs = machines[mi]->edges[i].guards;
		  for (size_t g = 0 ; g < gs.size() ; g += 1) {
			PExpr*key = gs[g];
			if (!key || guard_reg.count(key)
			    || local_guard_expr.count(key)) continue;
			bool reads_local = has_lv
			      && sva_expr_reads_lv_(key, lv_index);
			  /* M6B-4: read the guard's operands as of the
			     Preponed region (16.5.1). Done BEFORE the
			     sampled-value rewrite so $past/$rose history
			     chains capture preponed values too. A shape the
			     wrap cannot copy keeps the original expression
			     and reads live. */
			PExpr*src = key;
			PExpr*prep = sva_wrap_preponed_(key, prep_sampled,
							prep_live_operands,
							reads_local ? &lv_index : nullptr);
			if (prep) src = prep;
			else prep_live_operands += 1;
			PExpr*be = sva_rewrite_sampled_(loc, src, inst,
							hist_idx, pre, post,
							init_zero);
			if (reads_local) {
			      local_guard_expr[key] = be;
			      continue;
			}
			perm_string r = sva_make_reg_(loc, inst, "b", bidx++);
			pre.push_back(sva_assign_(loc, r, be));
			guard_reg[key] = r;
		  }
	      }
      }
	/* LV-2: an RHS with no local dependency is sampled once per tick into a
	   shared typed register. A dependent RHS instead remains a Preponed-
	   rewritten expression template whose local holes are replaced with the
	   current vk/ovk record at its assigning edge. This is what makes
	   `(first=tag) ##1 (second=first)' per attempt rather than an unresolved
	   or module-collision read. */
      std::vector<perm_string> lv_rhs_reg (lv_list.size());
      std::vector<bool> lv_rhs_reads_local (lv_list.size(), false);
      std::vector<PExpr*> local_rhs_expr (lv_list.size(), nullptr);
      for (unsigned li = 0 ; li < lv_list.size() ; li += 1) {
	    bool reads_local = sva_expr_reads_lv_(lv_rhs_expr[li], lv_index);
	    lv_rhs_reads_local[li] = reads_local;
	    PExpr*src = lv_rhs_expr[li];
	    PExpr*prep = sva_wrap_preponed_(lv_rhs_expr[li], prep_sampled,
					     prep_live_operands,
					     reads_local ? &lv_index : nullptr);
	    if (prep) src = prep;
	    else prep_live_operands += 1;
	    PExpr*rhs = sva_rewrite_sampled_(loc, src, inst, hist_idx,
					     pre, post, init_zero);
	    if (reads_local) {
		  /* The pre-commit topology/substitution audit proves this is a
		     structurally cloneable deterministic-prefix expression. */
		  local_rhs_expr[li] = rhs;
	    } else {
		  char what[24];
		  snprintf(what, sizeof what, "lvr%u", li);
		  lv_rhs_reg[li] = sva_make_reg_(loc, inst, what, 0, true, false,
						 lv_rhs_expr[li],
						 sva_expr_signed_(lv_rhs_expr[li]));
		  pre.push_back(sva_assign_(loc, lv_rhs_reg[li], rhs));
	    }
      }

	/* Enable the 1-deep driven-value history for every signal sampled by a
	   guard OR a local-assignment RHS. Ordered by name for deterministic
	   generated code. */
      for (std::map<std::string, pform_name_t>::const_iterator it =
		 prep_sampled.begin() ; it != prep_sampled.end() ; ++it)
	    init_zero.push_back(sva_hist_on_stmt_(loc, it->second));

	/* An operand this pass could not route through the Preponed read --
	   a package-qualified name, or an expression shape the copier
	   cannot clone -- still reads its ACTIVE-region value. That
	   is a wrong verdict whenever such an operand is written with a
	   blocking assignment in the same time slot as the clock, so say so
	   rather than leave it silent. One note per assertion. Operands that
	   ARE routed but cannot be sampled at the far end (an unpacked-array
	   word, a real) are reported by $ivl_clocking_sample elaboration. */
      if (prep_live_operands > 0)
	    cerr << loc << ": warning: this assertion has "
		 << prep_live_operands << " operand(s) that are read live "
		 << "instead of sampled in the Preponed region (IEEE "
		 << "1800-2017 16.5.1): a package-qualified name, or an "
		 << "expression shape the sampling rewrite cannot copy. A "
		 << "blocking write to one of them in the same time slot as "
		 << "the clock will be visible to this assertion. Local and "
		 << "hierarchical signals, including their bit- and "
		 << "part-selects, ARE sampled correctly." << endl;
	/* Per-slot local-variable copies retain that same exact packed type. */
      std::vector< std::vector<perm_string> > vk (K);
      for (long k = 0 ; k < K ; k += 1) {
	    vk[k].resize(lv_list.size());
	    for (unsigned li = 0 ; li < lv_list.size() ; li += 1) {
		  char what[24];
		  snprintf(what, sizeof what, "k%ldv%u", k, li);
		  vk[k][li] = sva_make_reg_(loc, inst, what, 0, true, false,
					   lv_rhs_expr[li],
					   sva_expr_signed_(lv_rhs_expr[li]));
		  init_zero.push_back(sva_assign_(loc, vk[k][li],
			new PENumber(new verinum((uint64_t)0, 32))));
	    }
      }
	/* Every consequence obligation gets a snapshot of the originating
	   antecedent attempt's local data. Later consequence assignments update
	   only that obligation's copy. */
      std::vector< std::vector<perm_string> > ovk (OK);
      for (long k = 0 ; k < OK ; k += 1) {
	    ovk[k].resize(lv_list.size());
	    for (unsigned li = 0 ; li < lv_list.size() ; li += 1) {
		  char what[24];
		  snprintf(what, sizeof what, "o%ldv%u", k, li);
		  ovk[k][li] = sva_make_reg_(loc, inst, what, 0, true, false,
					    lv_rhs_expr[li],
					    sva_expr_signed_(lv_rhs_expr[li]));
		  init_zero.push_back(sva_assign_(loc, ovk[k][li],
			new PENumber(new verinum((uint64_t)0, 32))));
	    }
      }

	/* State storage: s[k][j] slot-state bits; nx[j] shared
	   next-state temps (slots advance sequentially in one always
	   body, so sharing is safe). */
      std::vector< std::vector<perm_string> > s (K);
      for (long k = 0 ; k < K ; k += 1) {
	    char what[24];
	    snprintf(what, sizeof what, "k%lds", k);
	    s[k].resize(N);
	    for (unsigned j = 0 ; j < N ; j += 1) {
		  s[k][j] = sva_make_reg_(loc, inst, what, j);
		  init_zero.push_back(sva_assign_(loc, s[k][j],
						  sva_bit_(loc, 0)));
	    }
      }
      std::vector<perm_string> nx (N);
      for (unsigned j = 0 ; j < N ; j += 1) {
	    nx[j] = sva_make_reg_(loc, inst, "nx", j);
	    init_zero.push_back(sva_assign_(loc, nx[j], sva_bit_(loc, 0)));
      }
	/* Independent consequence records. Each endpoint sets one spawn bit;
	   |-> allocates before consequence advancement (same sampled tick),
	   while |=> allocates afterward (first strictly following tick). */
      std::vector< std::vector<perm_string> > os (OK);
      for (long k = 0 ; k < OK ; k += 1) {
	    char what[24];
	    snprintf(what, sizeof what, "o%lds", k);
	    os[k].resize(ON);
	    for (unsigned j = 0 ; j < ON ; j += 1) {
		  os[k][j] = sva_make_reg_(loc, inst, what, j);
		  init_zero.push_back(sva_assign_(loc, os[k][j],
					  sva_bit_(loc, 0)));
	    }
      }
      std::vector<perm_string> onx (ON);
      for (unsigned j = 0 ; j < ON ; j += 1) {
	    onx[j] = sva_make_reg_(loc, inst, "onx", j);
	    init_zero.push_back(sva_assign_(loc, onx[j], sva_bit_(loc, 0)));
      }
      std::vector<perm_string> spawn (endpoint_fanout ? K : 0);
      for (long k = 0 ; k < (long)spawn.size() ; k += 1) {
	    spawn[k] = sva_make_reg_(loc, inst, "spawn", (unsigned)k);
	    init_zero.push_back(sva_assign_(loc, spawn[k], sva_bit_(loc, 0)));
      }
      std::vector<perm_string> ob;
      bool track_ob = implication && !cover && !endpoint_fanout;
      if (track_ob) {
	    ob.resize(K);
	    for (long k = 0 ; k < K ; k += 1) {
		  ob[k] = sva_make_reg_(loc, inst, "ob", (unsigned)k);
		  init_zero.push_back(sva_assign_(loc, ob[k],
						  sva_bit_(loc, 0)));
	    }
      }
      perm_string r_f;
      if (!cover) {
	    r_f = sva_make_reg_(loc, inst, "f", 0, endpoint_fanout);
	    init_zero.push_back(sva_assign_(loc, r_f, sva_bit_(loc, 0)));
      }
      perm_string r_p;
      if (!negated && !cover) {
	    r_p = sva_make_reg_(loc, inst, "p", 0, endpoint_fanout);
	    init_zero.push_back(sva_assign_(loc, r_p, sva_bit_(loc, 0)));
      }
	// M12-1: per-tick STEP flags — set by the slot advance when an
	// attempt moves forward one step (sp) or dies mid-sequence
	// (sf), dispatched once per tick like the pass/fail flags.
	// Cover has no step notion (its counter is the record).
      perm_string r_sp, r_sf;
      if (!cover) {
	    r_sp = sva_make_reg_(loc, inst, "sp", 0);
	    init_zero.push_back(sva_assign_(loc, r_sp, sva_bit_(loc, 0)));
	    r_sf = sva_make_reg_(loc, inst, "sf", 0);
	    init_zero.push_back(sva_assign_(loc, r_sf, sva_bit_(loc, 0)));
      }
      perm_string r_cnt;
      if (cover) {
	      /* Same name as the legacy engine's counter, so tests can
		 read the count identically under either engine. */
	    r_cnt = sva_make_reg_(loc, inst, "cnt", 0, true);
	    init_zero.push_back(sva_assign_(loc, r_cnt,
			new PENumber(new verinum((uint64_t)0, 32))));
      }
      perm_string r_ovf = sva_make_reg_(loc, inst, "ovf", 0);
      init_zero.push_back(sva_assign_(loc, r_ovf, sva_bit_(loc, 0)));
      perm_string r_oovf;
      if (endpoint_fanout) {
	    r_oovf = sva_make_reg_(loc, inst, "oovf", 0);
	    init_zero.push_back(sva_assign_(loc, r_oovf, sva_bit_(loc, 0)));
      }

      auto busy_expr = [&](long k) -> PExpr* {
	    PExpr*e = sva_id_(loc, s[k][0]);
	    for (unsigned j = 1 ; j < N ; j += 1)
		  e = sva_logic_(loc, 'o', e, sva_id_(loc, s[k][j]));
	    return e;
      };
      auto clear_slot = [&](long k, std::vector<Statement*>&out) {
	    for (unsigned j = 0 ; j < N ; j += 1)
		  out.push_back(sva_assign_(loc, s[k][j], sva_bit_(loc, 0)));
      };
      auto obligation_busy_expr = [&](long k) -> PExpr* {
	    PExpr*e = sva_id_(loc, os[k][0]);
	    for (unsigned j = 1 ; j < ON ; j += 1)
		  e = sva_logic_(loc, 'o', e, sva_id_(loc, os[k][j]));
	    return e;
      };
      auto clear_obligation = [&](long k, std::vector<Statement*>&out) {
	    for (unsigned j = 0 ; j < ON ; j += 1)
		  out.push_back(sva_assign_(loc, os[k][j], sva_bit_(loc, 0)));
      };
      auto increment_verdict = [&](perm_string reg) -> Statement* {
	    PEBinary*add = new PEBinary('+', sva_id_(loc, reg),
				       sva_bit_(loc, 1));
	    FILE_NAME(add, loc);
	    return sva_assign_(loc, reg, add);
      };

      perm_string r_kill = sva_kill_seen_reg_(loc, inst, 0, init_zero);
      auto clear_attempt_state = [&]() -> Statement* {
	    std::vector<Statement*> clr;
	    for (long k = 0 ; k < K ; k += 1) {
		  clear_slot(k, clr);
		  if (track_ob)
			clr.push_back(sva_assign_(loc, ob[k], sva_bit_(loc, 0)));
		  if (endpoint_fanout)
			clr.push_back(sva_assign_(loc, spawn[k], sva_bit_(loc, 0)));
	    }
	    if (endpoint_fanout)
		  for (long k = 0 ; k < OK ; k += 1)
			clear_obligation(k, clr);
	    if (!cover) {
		  clr.push_back(sva_assign_(loc, r_f, sva_bit_(loc, 0)));
		  clr.push_back(sva_assign_(loc, r_sp, sva_bit_(loc, 0)));
		  clr.push_back(sva_assign_(loc, r_sf, sva_bit_(loc, 0)));
	    }
	    if (!negated && !cover)
		  clr.push_back(sva_assign_(loc, r_p, sva_bit_(loc, 0)));
	    return sva_block_(loc, clr);
      };

      std::vector<Statement*> body;
	/* cbAssertionStart: an attempt launches every evaluated tick
	   while this directive is enabled (inside the disable guard, like the
	   legacy engine). Existing slots continue advancing after $assertoff. */
      body.push_back(sva_observed_wait_(loc));
      body.push_back(sva_kill_reset_stmt_(
	    loc, inst, r_kill, clear_attempt_state()));
      body.push_back(sva_if_(loc, sva_enabled_expr_(loc, inst),
			     sva_report_stmt_(loc, inst, SVA_CB_START), nullptr));

      auto spawn_obligation_stmt = [&](long source) -> Statement* {
	    char msg[192];
	    snprintf(msg, sizeof msg,
		     "SVA NFA: consequence obligation pool overflow (%ld "
		     "slots) -- endpoint obligations are being dropped%s", OK,
		     consequence_cyclic ? " (finite cyclic pool)" :
					  " (internal bound bug)");
	    std::list<named_pexpr_t> dargs;
	    named_pexpr_t darg;
	    darg.parm = new PEString(strdup(msg));
	    dargs.push_back(darg);
	    PCallTask*warn = new PCallTask(lex_strings.make("$display"), dargs);
	    FILE_NAME(warn, loc);
	    std::vector<Statement*>once;
	    once.push_back(sva_assign_(loc, r_oovf, sva_bit_(loc, 1)));
	    once.push_back(warn);
	    Statement*inj = sva_if_(loc, sva_not_(loc, sva_id_(loc, r_oovf)),
				    sva_block_(loc, once), nullptr);
	    for (long o = OK - 1 ; o >= 0 ; o -= 1) {
		  std::vector<Statement*>take;
		  take.push_back(sva_assign_(loc, os[o][consequence_nfa.start],
					  sva_bit_(loc, 1)));
		  for (unsigned li = 0 ; li < lv_list.size() ; li += 1)
			take.push_back(sva_assign_(loc, ovk[o][li],
						  sva_id_(loc, vk[source][li])));
		  inj = sva_if_(loc, sva_not_(loc, obligation_busy_expr(o)),
				sva_block_(loc, take), inj);
	    }
	    std::vector<Statement*>fire;
	    fire.push_back(sva_assign_(loc, spawn[source], sva_bit_(loc, 0)));
	    fire.push_back(inj);
	    return sva_if_(loc, sva_id_(loc, spawn[source]),
			   sva_block_(loc, fire), nullptr);
      };

	/* Injection into the first free slot. The terminal else is a
	   LOUD once-per-run overflow warning — provably unreachable
	   for loop-free automata (K = longest path), kept as a
	   no-silent-drop backstop regardless. */
      {
	    char msg[192];
	    snprintf(msg, sizeof msg,
		     "SVA NFA: attempt pool overflow (%ld slots) -- "
		     "attempts are being dropped%s", K,
		     cyclic ? "; raise IVL_SVA_NFA_SLOTS" : " (internal bug)");
	    std::list<named_pexpr_t> dargs;
	    named_pexpr_t darg;
	    darg.parm = new PEString(strdup(msg));
	    dargs.push_back(darg);
	    PCallTask*warn = new PCallTask(lex_strings.make("$display"), dargs);
	    FILE_NAME(warn, loc);
	    std::vector<Statement*> once;
	    once.push_back(sva_assign_(loc, r_ovf, sva_bit_(loc, 1)));
	    once.push_back(warn);
	    Statement*inj = sva_if_(loc, sva_not_(loc, sva_id_(loc, r_ovf)),
				    sva_block_(loc, once), nullptr);
	    for (long k = K-1 ; k >= 0 ; k -= 1)
		  inj = sva_if_(loc, sva_not_(loc, busy_expr(k)),
				sva_assign_(loc, s[k][nfa.start],
					    sva_bit_(loc, 1)),
				inj);
	    body.push_back(sva_if_(loc, sva_enabled_expr_(loc, inst),
			     inj, nullptr));
      }

	/* Per-slot advance. */
      for (long k = 0 ; k < K ; k += 1) {
	      /* Obligation: set the sticky bit the tick the antecedent
		 completes — the attempt sits in the pre-boundary state
		 and the antecedent's final tick booleans fire (a
		 trailing ##0-fused run shares that tick, so ALL its
		 booleans are conjoined) — regardless of whether the
		 (possibly fused) consequent edge also fires. Evaluated
		 on the PRE-advance state bits. */
	    if (track_ob) {
		  size_t tail0 = prop->antecedent->size() - 1;
		  while (tail0 > 0
			 && (*prop->antecedent)[tail0].delay_lo == 0)
			tail0 -= 1;
		  PExpr*done = sva_id_(loc, s[k][pre_boundary]);
		  for (size_t j = tail0 ; j < prop->antecedent->size() ; j += 1) {
			std::map<PExpr*,perm_string>::iterator it =
			      guard_reg.find((*prop->antecedent)[j].expr);
			assert(it != guard_reg.end());
			done = sva_logic_(loc, 'a', done,
					  sva_id_(loc, it->second));
		  }
		  body.push_back(sva_if_(loc, done,
			sva_assign_(loc, ob[k], sva_bit_(loc, 1)), nullptr));
	    }
	      /* LV-2: per-slot substitution map (local var -> this slot's
		 copy) for guards that read a local variable. */
	    std::map<perm_string,PExpr*> lvmap;
	    for (unsigned li = 0 ; li < lv_list.size() ; li += 1)
		  lvmap[lv_list[li]] = sva_id_(loc, vk[k][li]);
	    for (unsigned j = 0 ; j < N ; j += 1) {
		  PExpr*e = nullptr;
		  for (size_t i = 0 ; i < nfa.edges.size() ; i += 1) {
			const sva_nfa_edge_t&ed = nfa.edges[i];
			if (ed.to != j) continue;
			PExpr*term = sva_id_(loc, s[k][ed.from]);
			for (size_t g = 0 ; g < ed.guards.size() ; g += 1) {
			      PExpr*gk = ed.guards[g];
			      if (has_lv && sva_expr_reads_lv_(gk, lv_index)) {
				      /* Per-attempt: clone the already-Preponed
					 nonlocal operands and replace lv -> vk. */
				    std::map<PExpr*,PExpr*>::iterator it =
					  local_guard_expr.find(gk);
				    assert(it != local_guard_expr.end());
				    PExpr*pc = sva_clone_subst_(it->second, &lvmap);
				    term = sva_logic_(loc, 'a', term, pc);
			      } else {
				    std::map<PExpr*,perm_string>::iterator it =
					  guard_reg.find(gk);
				    assert(it != guard_reg.end());
				    term = sva_logic_(loc, 'a', term,
						      sva_id_(loc, it->second));
			      }
			}
			e = e ? sva_logic_(loc, 'o', e, term) : term;
		  }
		  if (!e) e = sva_bit_(loc, 0);
		  body.push_back(sva_assign_(loc, nx[j], e));
	    }
	      /* LV-2: capture — a slot takes a local variable's rhs sample
		 exactly when the ASSIGNING EDGE fires (the gate matched
		 from the pre-advance state), NOT merely when it sits in the
		 assign state: a ##[m:$] wait self-loop re-enters that state
		 every tick and would otherwise re-capture stale data. */
	    for (unsigned li = 0 ; li < lv_list.size() ; li += 1) {
		  PExpr*cap = nullptr;
		  for (size_t i = 0 ; i < nfa.edges.size() ; i += 1) {
			const sva_nfa_edge_t&ed = nfa.edges[i];
			bool is_assign = false;
			for (size_t g = 0 ; g < ed.guards.size() ; g += 1)
			      if (ed.guards[g] == lv_gate_expr[li]) is_assign = true;
			if (!is_assign) continue;
			PExpr*t = sva_id_(loc, s[k][ed.from]);
			for (size_t g = 0 ; g < ed.guards.size() ; g += 1) {
			      PExpr*gk = ed.guards[g];
			      if (has_lv && sva_expr_reads_lv_(gk, lv_index)) {
				    std::map<PExpr*,PExpr*>::iterator it =
					  local_guard_expr.find(gk);
				    assert(it != local_guard_expr.end());
				    t = sva_logic_(loc, 'a', t,
						   sva_clone_subst_(it->second,
								    &lvmap));
			      }
			      else {
				    std::map<PExpr*,perm_string>::iterator it =
					  guard_reg.find(gk);
				    assert(it != guard_reg.end());
				    t = sva_logic_(loc, 'a', t,
						   sva_id_(loc, it->second));
			      }
			}
			cap = cap ? sva_logic_(loc, 'o', cap, t) : t;
		  }
		  if (cap)
			{
			      PExpr*rhs = lv_rhs_reads_local[li]
				    ? sva_clone_subst_(local_rhs_expr[li], &lvmap)
				    : sva_id_(loc, lv_rhs_reg[li]);
			      /* The deterministic-prefix admission proof and the
				 structural RHS proof guarantee that every local hole can be
				 replaced by this attempt's carrier. */
			      assert(rhs);
			      body.push_back(sva_if_(loc, cap,
				    sva_assign_(loc, vk[k][li], rhs), nullptr));
			}
	    }
	    for (std::map<perm_string,PExpr*>::iterator it = lvmap.begin();
		 it != lvmap.end() ; ++it)
		  delete it->second;

	    PExpr*alive = sva_id_(loc, nx[0]);
	    for (unsigned j = 1 ; j < N ; j += 1)
		  alive = sva_logic_(loc, 'o', alive, sva_id_(loc, nx[j]));
	    PExpr*dead_busy = sva_logic_(loc, 'a', busy_expr(k),
					 sva_not_(loc, alive));

	    std::vector<Statement*> acc_v, die_v, cont_v;
	    if (endpoint_fanout) {
		  acc_v.push_back(sva_assign_(loc, spawn[k], sva_bit_(loc, 1)));
		  /* Reaching an antecedent endpoint is a successful checker step.
		     For |=> the new obligation is intentionally allocated only after
		     old consequences advance, so consequence-side bookkeeping cannot
		     supply this once/checker/tick aggregate. */
		  if (!cover)
			acc_v.push_back(sva_assign_(loc, r_sp, sva_bit_(loc, 1)));
		  /* Remove only the accepted endpoint. Other active antecedent
		     states represent later match endpoints from this SAME start and
		     must remain live. */
		  for (unsigned j = 0 ; j < N ; j += 1)
			acc_v.push_back(sva_assign_(loc, s[k][j],
			      j == nfa.accept ? sva_bit_(loc, 0)
					      : sva_id_(loc, nx[j])));
	    } else if (cover) {
		    /* Count each accepting attempt (one per slot; a
		       tick can accept several — same totals as the
		       legacy per-eligible-position adds). */
		  PEBinary*add = new PEBinary('+', sva_id_(loc, r_cnt),
					      sva_bit_(loc, 1));
		  FILE_NAME(add, loc);
		  acc_v.push_back(sva_assign_(loc, r_cnt, add));
	    } else {
		  acc_v.push_back(sva_assign_(loc,
					       (negated || forbidden) ? r_f : r_p,
					      sva_bit_(loc, 1)));
	    }
	    if (!endpoint_fanout) {
		  clear_slot(k, acc_v);
		  if (track_ob)
			acc_v.push_back(sva_assign_(loc, ob[k], sva_bit_(loc, 0)));
	    }

	    if (track_ob) {
		  die_v.push_back(sva_if_(loc, sva_id_(loc, ob[k]),
					  sva_assign_(loc, forbidden ? r_p : r_f,
						      sva_bit_(loc, 1)),
					  nullptr));
		  die_v.push_back(sva_assign_(loc, ob[k], sva_bit_(loc, 0)));
	    } else if (!negated && !cover && !endpoint_fanout) {
		  die_v.push_back(sva_assign_(loc, r_f, sva_bit_(loc, 1)));
	    }
	      /* M12-1: this branch is taken only when the slot was live
		 and has no surviving next state (dead_busy), i.e. an
		 attempt just failed a step of the sequence. */
	    if (!cover)
		  die_v.push_back(sva_assign_(loc, r_sf, sva_bit_(loc, 1)));
	    clear_slot(k, die_v);

	      /* M12-1: a live slot reaching the continue branch advanced
		 one step (the accept and dead_busy branches are already
		 excluded), so a pre-advance busy test identifies exactly
		 the stepping attempts. It must precede the state writes
		 below, which overwrite the bits busy_expr reads. */
	    if (!cover)
		  cont_v.push_back(sva_if_(loc, busy_expr(k),
					   sva_assign_(loc, r_sp,
						       sva_bit_(loc, 1)),
					   nullptr));

	    for (unsigned j = 0 ; j < N ; j += 1)
		  cont_v.push_back(sva_assign_(loc, s[k][j],
					       sva_id_(loc, nx[j])));

	    Statement*st = sva_if_(loc, sva_id_(loc, nx[nfa.accept]),
				   sva_block_(loc, acc_v),
				   sva_if_(loc, dead_busy,
					   sva_block_(loc, die_v),
					   sva_block_(loc, cont_v)));
	    body.push_back(st);
      }

	/* |-> consumes the consequence's first tick on the endpoint tick. All
	   endpoint spawn bits are allocated before consequence advancement, so
	   each new record observes the current Preponed guard samples. */
      if (endpoint_fanout && prop->op_type == 1)
	    for (long k = 0 ; k < K ; k += 1)
		  body.push_back(spawn_obligation_stmt(k));

	/* Advance every independent consequence obligation. Acceptance clears
	   only this record; sibling endpoints, including endpoints from the same
	   antecedent attempt, retain their own state and local-data snapshot. */
      if (endpoint_fanout) for (long o = 0 ; o < OK ; o += 1) {
	    std::map<perm_string,PExpr*> lvmap;
	    for (unsigned li = 0 ; li < lv_list.size() ; li += 1)
		  lvmap[lv_list[li]] = sva_id_(loc, ovk[o][li]);

	    for (unsigned j = 0 ; j < ON ; j += 1) {
		  PExpr*e = nullptr;
		  for (size_t i = 0 ; i < consequence_nfa.edges.size() ; i += 1) {
			const sva_nfa_edge_t&ed = consequence_nfa.edges[i];
			if (ed.to != j) continue;
			PExpr*term = sva_id_(loc, os[o][ed.from]);
			for (size_t g = 0 ; g < ed.guards.size() ; g += 1) {
			      PExpr*gk = ed.guards[g];
			      if (has_lv && sva_expr_reads_lv_(gk, lv_index)) {
				    std::map<PExpr*,PExpr*>::iterator it =
					  local_guard_expr.find(gk);
				    assert(it != local_guard_expr.end());
				    term = sva_logic_(loc, 'a', term,
					      sva_clone_subst_(it->second, &lvmap));
			      } else {
				    std::map<PExpr*,perm_string>::iterator it =
					  guard_reg.find(gk);
				    assert(it != guard_reg.end());
				    term = sva_logic_(loc, 'a', term,
					      sva_id_(loc, it->second));
			      }
			}
			e = e ? sva_logic_(loc, 'o', e, term) : term;
		  }
		  if (!e) e = sva_bit_(loc, 0);
		  body.push_back(sva_assign_(loc, onx[j], e));
	    }

	      /* A match-item assignment in a consequence belongs to the one
		 obligation executing that edge. */
	    for (unsigned li = 0 ; li < lv_list.size() ; li += 1) {
		  PExpr*cap = nullptr;
		  for (size_t i = 0 ; i < consequence_nfa.edges.size() ; i += 1) {
			const sva_nfa_edge_t&ed = consequence_nfa.edges[i];
			bool is_assign = false;
			for (size_t g = 0 ; g < ed.guards.size() ; g += 1)
			      if (ed.guards[g] == lv_gate_expr[li]) is_assign = true;
			if (!is_assign) continue;
			PExpr*t = sva_id_(loc, os[o][ed.from]);
			for (size_t g = 0 ; g < ed.guards.size() ; g += 1) {
			      PExpr*gk = ed.guards[g];
			      if (has_lv && sva_expr_reads_lv_(gk, lv_index)) {
				    std::map<PExpr*,PExpr*>::iterator it =
					  local_guard_expr.find(gk);
				    assert(it != local_guard_expr.end());
				    t = sva_logic_(loc, 'a', t,
					   sva_clone_subst_(it->second, &lvmap));
			      } else {
				    std::map<PExpr*,perm_string>::iterator it =
					  guard_reg.find(gk);
				    assert(it != guard_reg.end());
				    t = sva_logic_(loc, 'a', t,
					   sva_id_(loc, it->second));
			      }
			}
			cap = cap ? sva_logic_(loc, 'o', cap, t) : t;
		  }
		  if (cap)
			{
			      PExpr*rhs = lv_rhs_reads_local[li]
				    ? sva_clone_subst_(local_rhs_expr[li], &lvmap)
				    : sva_id_(loc, lv_rhs_reg[li]);
			      /* Each obligation evaluates a dependent RHS against its own
				 snapshot, never against an unresolved/module-collision name. */
			      assert(rhs);
			      body.push_back(sva_if_(loc, cap,
				    sva_assign_(loc, ovk[o][li], rhs), nullptr));
			}
	    }
	    for (std::map<perm_string,PExpr*>::iterator it = lvmap.begin();
		 it != lvmap.end() ; ++it)
		  delete it->second;

	    PExpr*alive = sva_id_(loc, onx[0]);
	    for (unsigned j = 1 ; j < ON ; j += 1)
		  alive = sva_logic_(loc, 'o', alive, sva_id_(loc, onx[j]));
	    PExpr*dead_busy = sva_logic_(loc, 'a', obligation_busy_expr(o),
					 sva_not_(loc, alive));

	    std::vector<Statement*> acc_v, die_v, cont_v;
	    if (cover) {
		  PEBinary*add = new PEBinary('+', sva_id_(loc, r_cnt),
					      sva_bit_(loc, 1));
		  FILE_NAME(add, loc);
		  acc_v.push_back(sva_assign_(loc, r_cnt, add));
	    } else {
		  acc_v.push_back(increment_verdict(forbidden ? r_f : r_p));
		  die_v.push_back(increment_verdict(forbidden ? r_p : r_f));
	    }
	    if (!cover)
		  die_v.push_back(sva_assign_(loc, r_sf, sva_bit_(loc, 1)));
	    clear_obligation(o, acc_v);
	    clear_obligation(o, die_v);
	    if (!cover)
		  cont_v.push_back(sva_if_(loc, obligation_busy_expr(o),
				sva_assign_(loc, r_sp, sva_bit_(loc, 1)), nullptr));
	    for (unsigned j = 0 ; j < ON ; j += 1)
		  cont_v.push_back(sva_assign_(loc, os[o][j],
					       sva_id_(loc, onx[j])));

	    body.push_back(sva_if_(loc, sva_id_(loc, onx[consequence_nfa.accept]),
				   sva_block_(loc, acc_v),
				   sva_if_(loc, dead_busy,
					   sva_block_(loc, die_v),
					   sva_block_(loc, cont_v))));
      }

	/* |=> starts strictly after the antecedent endpoint, so allocation is
	   deliberately after every old consequence record advanced this tick. */
      if (endpoint_fanout && prop->op_type == 2)
	    for (long k = 0 ; k < K ; k += 1)
		  body.push_back(spawn_obligation_stmt(k));

	/* Pass then fail dispatch: one report site each per tick, in
	   the legacy engine's output order (pass before fail). Cover
	   has neither — the counter is the record. */
      if (!negated && !cover) {
	    std::vector<Statement*> hit;
	    if (endpoint_fanout)
		  hit.push_back(sva_repeat_(loc, sva_id_(loc, r_p), pass_stmt));
	    else
		  hit.push_back(pass_stmt);
	    hit.push_back(sva_assign_(loc, r_p, sva_bit_(loc, 0)));
	    body.push_back(sva_if_(loc, sva_id_(loc, r_p),
				   sva_block_(loc, hit), nullptr));
	    pass_stmt = nullptr;
      } else {
	    delete pass_stmt;
	    pass_stmt = nullptr;
      }
	/* A strong sequence can also fail by running out of time, and
	   that failure is reported from a `final' block further down.
	   Both sites need the user's `else', so take a copy before the
	   per-cycle dispatch below consumes the original. */
      Statement*eos_fail_stmt = nullptr;
      bool eos_fail_unclonable = false;
      if (!cover && fail_stmt) {
	    eos_fail_stmt = sva_clone_stmt_(fail_stmt);
	    if (!eos_fail_stmt) eos_fail_unclonable = true;
      }

      if (cover) {
	    delete fail_stmt;
	    fail_stmt = nullptr;
      } else {
	    Statement*action = fail_stmt;
	    if (!action) {
		  std::list<named_pexpr_t> no_args;
		  PCallTask*err = new PCallTask(
			lex_strings.make("$error"), no_args);
		  FILE_NAME(err, loc);
		  action = err;
	    }
	    std::vector<Statement*> hit;
	    Statement*fail_action = sva_fail_action_(loc, inst, action);
	    if (endpoint_fanout)
		  hit.push_back(sva_repeat_(loc, sva_id_(loc, r_f), fail_action));
	    else
		  hit.push_back(fail_action);
	    hit.push_back(sva_assign_(loc, r_f, sva_bit_(loc, 0)));
	    body.push_back(sva_if_(loc, sva_id_(loc, r_f),
				   sva_block_(loc, hit), nullptr));
	    fail_stmt = nullptr;
      }

	/* M12-1: STEP dispatch, after the pass/fail sites so no existing
	   report ordering changes. These carry no user action — they only
	   drive cbAssertionStepSuccess/StepFailure, and the report site
	   is itself gated on a callback being registered. */
      if (!cover) {
	    std::vector<Statement*> sp_hit;
	    sp_hit.push_back(sva_assign_(loc, r_sp, sva_bit_(loc, 0)));
	    sp_hit.push_back(sva_report_stmt_(loc, inst, SVA_CB_STEP_SUCCESS));
	    body.push_back(sva_if_(loc, sva_id_(loc, r_sp),
				   sva_block_(loc, sp_hit), nullptr));

	    std::vector<Statement*> sf_hit;
	    sf_hit.push_back(sva_assign_(loc, r_sf, sva_bit_(loc, 0)));
	    sf_hit.push_back(sva_report_stmt_(loc, inst, SVA_CB_STEP_FAILURE));
	    body.push_back(sva_if_(loc, sva_id_(loc, r_sf),
				   sva_block_(loc, sf_hit), nullptr));
      }

	/* Assemble: pre-captures; disable guard clears all slot state
	   with no reports; history updates outside the guard. */
      std::vector<Statement*> full = pre;
      Statement*core = sva_block_(loc, body);
	    if (disable) {
	    PCondit*dc = new PCondit(disable, clear_attempt_state(), core);
	    FILE_NAME(dc, loc);
	    full.push_back(dc);
      } else {
	    full.push_back(core);
      }
      for (size_t i = 0 ; i < post.size() ; i += 1)
	    full.push_back(post[i]);

      clk->set_statement(sva_block_(loc, full));
      PProcess*pp = pform_make_behavior(IVL_PR_ALWAYS, clk, nullptr);
      FILE_NAME(pp, loc);

	// M12-2: a fixed-latency loop-free automaton lets the runtime
	// report a correct attemptStartTime (the attempt started
	// `latency' ticks ago).
      init_zero.push_back(sva_register_stmt_(loc, inst,
					     endpoint_fanout ? -1
					       : pform_sva_nfa_fixed_latency(nfa),
					     track_ob));
      PProcess*ip = pform_make_behavior(IVL_PR_INITIAL,
					sva_block_(loc, init_zero), nullptr);
      FILE_NAME(ip, loc);

	/* End-of-simulation handling for looping obligations. Loop states
	   are self-loop wait states by construction; a slot still in one at
	   end of simulation is an attempt whose sequence never completed.
	   For a WEAK sequence property (the default) that is not a failure
	   — emit an informational note. For a STRONG sequence property
	   (`strong(seq)', 16.12.2) it IS a failure. A pending `not' attempt
	   means the negated property held (silent); a pending cover attempt
	   simply never matched (silent). */
      bool strong_seq = (prop->strength == 1);
      if (cyclic && !negated && !cover && !endpoint_fanout) {
	    std::vector<bool> loop_state (N, false);
	    for (size_t i = 0 ; i < nfa.edges.size() ; i += 1)
		  if (nfa.edges[i].from == nfa.edges[i].to)
			loop_state[nfa.edges[i].from] = true;
	    PExpr*pend = nullptr;
	    for (long k = 0 ; k < K ; k += 1)
		  for (unsigned j = 0 ; j < N ; j += 1) {
			if (!loop_state[j]) continue;
			PExpr*t = sva_id_(loc, s[k][j]);
			pend = pend ? sva_logic_(loc, 'o', pend, t) : t;
		  }
	    if (pend)
		  pend = sva_logic_(loc, 'a', pend,
			sva_kill_generation_current_(loc, inst, r_kill));
	    if (pend && strong_seq) {
		    /* strong: pending at end of simulation is a failure,
		       and it is reported through the user's own `else'
		       (16.14.6) -- eos_fail_stmt is the copy taken before
		       the per-cycle dispatch consumed the original. An
		       assertion with no else, or one whose action block
		       could not be duplicated, still gets the built-in
		       $error; the second case says so rather than
		       swallowing the statement. */
		  Statement*eos = eos_fail_stmt;
		  eos_fail_stmt = nullptr;
		  if (!eos) {
			if (eos_fail_unclonable) {
			      cerr << loc << ": sorry: this action block "
				   << "cannot be reproduced for the "
				   << "end-of-simulation failure of a strong "
				   << "sequence; that one failure reports "
				   << "through $error instead." << endl;
			      error_count += 1;
			}
			std::list<named_pexpr_t> no_args;
			PCallTask*err = new PCallTask(
			      lex_strings.make("$error"), no_args);
			FILE_NAME(err, loc);
			eos = err;
		  }
		  Statement*fa = sva_fail_action_(loc, inst, eos);
		  PCondit*fc = new PCondit(pend, fa, nullptr);
		  FILE_NAME(fc, loc);
		  PProcess*fp = pform_make_behavior(IVL_PR_FINAL, fc, nullptr);
		  FILE_NAME(fp, loc);
	    } else if (pend && !forbidden) {
		    /* weak (default): informational note only. */
		  std::list<named_pexpr_t> dargs;
		  named_pexpr_t darg;
		  darg.parm = new PEString(strdup(
			"SVA: unbounded ##[m:$] obligation still pending "
			"at end of simulation"));
		  dargs.push_back(darg);
		  PCallTask*warn = new PCallTask(
			lex_strings.make("$display"), dargs);
		  FILE_NAME(warn, loc);
		  PCondit*fc = new PCondit(pend, warn, nullptr);
		  FILE_NAME(fc, loc);
		  PProcess*fp = pform_make_behavior(IVL_PR_FINAL, fc, nullptr);
		  FILE_NAME(fp, loc);
	    }
      }

	/* A split consequence record, not its antecedent-discovery slot, owns
	   the end-of-simulation obligation. Strong fails for any live record;
	   weak reports only cyclic records that remain pending. */
      if (endpoint_fanout && !negated && !cover
	  && (strong_seq || consequence_cyclic)) {
	    if (strong_seq) {
		  /* A strong property resolves every live consequence record at
		     end of simulation. Count records (OR-reducing only the states
		     within one record), then repeat the complete failure action and
		     cbAssertionFailure report once per independent obligation. */
		  PExpr*pend_count = new PENumber(
			new verinum((uint64_t)0, 64));
		  FILE_NAME(pend_count, loc);
		  for (long o = 0 ; o < OK ; o += 1) {
			PEBinary*add = new PEBinary('+', pend_count,
					      obligation_busy_expr(o));
			FILE_NAME(add, loc);
			pend_count = add;
		  }
		  PExpr*pend_test = sva_clone_expr_(pend_count);
		  assert(pend_test);
		  pend_test = sva_logic_(loc, 'a', pend_test,
			sva_kill_generation_current_(loc, inst, r_kill));
		  Statement*eos = eos_fail_stmt;
		  eos_fail_stmt = nullptr;
		  if (!eos) {
			if (eos_fail_unclonable) {
			      cerr << loc << ": sorry: this action block cannot be "
				   << "reproduced for the end-of-simulation failure "
				   << "of a strong sequence; that one failure "
				   << "reports through $error instead." << endl;
			      error_count += 1;
			}
			std::list<named_pexpr_t> no_args;
			PCallTask*err = new PCallTask(lex_strings.make("$error"),
						       no_args);
			FILE_NAME(err, loc);
			eos = err;
		  }
		  Statement*fa = sva_fail_action_(loc, inst, eos);
		  Statement*repeat = sva_repeat_(loc, pend_count, fa);
		  PCondit*fc = new PCondit(pend_test, repeat, nullptr);
		  FILE_NAME(fc, loc);
		  PProcess*fp = pform_make_behavior(IVL_PR_FINAL, fc, nullptr);
		  FILE_NAME(fp, loc);
	    } else if (!forbidden) {
		  PExpr*pend = nullptr;
		  for (long o = 0 ; o < OK ; o += 1)
			for (unsigned j = 0 ; j < ON ; j += 1) {
			      PExpr*t = sva_id_(loc, os[o][j]);
			      pend = pend ? sva_logic_(loc, 'o', pend, t) : t;
			}
		  if (pend)
			pend = sva_logic_(loc, 'a', pend,
			      sva_kill_generation_current_(loc, inst, r_kill));
		  std::list<named_pexpr_t> dargs;
		  named_pexpr_t darg;
		  darg.parm = new PEString(strdup(
			"SVA: consequence obligation still pending at end of "
			"simulation"));
		  dargs.push_back(darg);
		  PCallTask*warn = new PCallTask(lex_strings.make("$display"),
						      dargs);
		  FILE_NAME(warn, loc);
		  if (pend) {
			PCondit*fc = new PCondit(pend, warn, nullptr);
			FILE_NAME(fc, loc);
			PProcess*fp = pform_make_behavior(IVL_PR_FINAL, fc,
						       nullptr);
			FILE_NAME(fp, loc);
		  } else {
			delete warn;
		  }
	    }
      }

      delete eos_fail_stmt;

      for (std::map<PExpr*,PExpr*>::iterator it = local_guard_expr.begin()
	   ; it != local_guard_expr.end() ; ++it) {
	    if (it->second != it->first) {
		  sva_expr_forget_sampled_(it->second);
		  delete it->second;
	    }
      }

      for (size_t li = 0 ; li < local_rhs_expr.size() ; li += 1) {
	    if (!local_rhs_expr[li]) continue;
	    sva_expr_forget_sampled_(local_rhs_expr[li]);
	    delete local_rhs_expr[li];
      }

      if (have_tree) {
	    sva_tree_delete_(prop->ante_tree, false);
	    prop->ante_tree = nullptr;
	    sva_tree_delete_(prop->tree, false);
	    prop->tree = nullptr;
      }
      if (match_calls && prop->seq && !prop->seq->empty())
	    sva_destroy_match_calls_(prop->seq->back().match_calls);
      delete prop->antecedent;
      delete prop->seq;
      delete prop;
      return true;
}

/* M9-NFA LV-1/LV-2: lower sequence local variables (IEEE 1800-2017
   16.10). Return codes: 0 = no local variables or all lowered here;
   1 = diagnosed error; 2 = variable-length local variables left on the
   steps for the automaton engine's per-slot storage (LV-2).

   LV-1 (fixed-delay) is a source transform, exact in both engines and
   needing no per-slot storage: `(a, v = rhs) ##N (read v)` pins the
   assignment exactly N cycles before the read, so a read of v at cycle
   offset D past its assignment is exactly $past(rhs, D). LV-2
   (variable-delay: a window/$/range-rep makes D non-constant per
   attempt) cannot use $past; the assignments are LEFT on the steps and
   the NFA engine gives each slot its own copy (returns 2 here). */
static int sva_lower_local_vars_(const struct vlltype&loc,
				 std::vector<sva_seq_step_t>&steps)
{
      bool has_lv = false;
      for (size_t k = 0 ; k < steps.size() ; k += 1)
	    if (steps[k].lv_rhs) { has_lv = true; break; }
      if (!has_lv) return 0;

      long len = 0;
      if (!sva_chain_fixed_len_(steps, len)) {
	      /* Variable delay: leave the assignments for LV-2 per-slot
		 storage in the automaton engine. */
	    (void)loc;
	    return 2;
      }

	/* Cumulative cycle offset of each step from the sequence start. */
      std::vector<long> offs (steps.size(), 0);
      long acc = 0;
      for (size_t k = 0 ; k < steps.size() ; k += 1) {
	    acc += steps[k].delay_lo;
	    offs[k] = acc;
      }

	/* Substitute reads. For step j, a local var assigned at an
	   EARLIER step i (i < j) is visible as $past(rhs_i, offs[j]-offs[i]);
	   a later assignment of the same name overrides an earlier one. */
      for (size_t j = 0 ; j < steps.size() ; j += 1) {
	    if (!steps[j].expr) continue;
	    std::map<perm_string,PExpr*> subst;
	    for (size_t i = 0 ; i < j ; i += 1) {
		  if (!steps[i].lv_rhs) continue;
		  long d = offs[j] - offs[i];
		  std::map<perm_string,PExpr*>::iterator it =
			subst.find(steps[i].lv_name);
		  if (it != subst.end()) { delete it->second; }
		  subst[steps[i].lv_name] =
			sva_past_(loc, sva_clone_expr_(steps[i].lv_rhs), d);
	    }
	    if (!subst.empty()) {
		  PExpr*ne = sva_clone_subst_(steps[j].expr, &subst);
		  if (ne) { delete steps[j].expr; steps[j].expr = ne; }
		  for (std::map<perm_string,PExpr*>::iterator it = subst.begin();
		       it != subst.end() ; ++it)
			delete it->second;
	    }
      }

	/* 16.11 match items run after the Boolean and after any assignment on
	   the same step. Therefore a call on step j sees assignments through
	   i == j (unlike the Boolean above, which sees only i < j). Rewrite a
	   fresh $display call because PCallTask intentionally exposes its
	   arguments read-only. The later NFA action sampler turns the resulting
	   $past/current expressions into checker history/sample registers. */
      for (size_t j = 0 ; j < steps.size() ; j += 1) {
	    if (steps[j].match_calls.empty()) continue;
	    std::map<perm_string,PExpr*> subst;
	    for (size_t i = 0 ; i <= j ; i += 1) {
		  if (!steps[i].lv_rhs) continue;
		  long d = offs[j] - offs[i];
		  std::map<perm_string,PExpr*>::iterator old =
			subst.find(steps[i].lv_name);
		  if (old != subst.end()) delete old->second;
		  PExpr*rhs = sva_clone_expr_(steps[i].lv_rhs);
		  subst[steps[i].lv_name] = sva_past_(loc, rhs, d);
	    }
	    std::vector<PCallTask*> rewritten;
	    bool ok = sva_clone_match_calls_(steps[j].match_calls, rewritten,
					     &subst);
	    for (std::map<perm_string,PExpr*>::iterator it = subst.begin()
		 ; it != subst.end() ; ++it)
		  delete it->second;
	    if (!ok) {
		  sva_match_item_sorry_(loc,
			"have an argument expression that cannot be sampled");
		  return 1;
	    }
	    sva_destroy_match_calls_(steps[j].match_calls);
	    steps[j].match_calls.swap(rewritten);
      }

	/* The assignments are consumed; free the rhs and clear them. */
      for (size_t k = 0 ; k < steps.size() ; k += 1) {
	    if (steps[k].lv_rhs) {
		  delete steps[k].lv_rhs;
		  steps[k].lv_rhs = nullptr;
		  steps[k].lv_name = perm_string();
	    }
      }
      return 0;
}

/* M9-NFA: expand a COMPOSED multi-length `first_match` (16.9.9) into a
   disjoint OR of fixed chains, so the automaton engine lowers it
   exactly. `first_match(a ##[m:n] b) ...` keeps only the EARLIEST b:
   branch k (m<=k<=n) requires b at offset k AND !b at offsets m..k-1,
   so the branches are mutually exclusive and their continuations are
   independent — if the committed (shortest) match's tail fails, the
   whole attempt fails, it does NOT fall back to a longer match, which
   is exactly first_match. Supported shape: the wrapped region contains
   exactly ONE bounded window and no local variable; returns a SEQ_OR
   tree, or nullptr if the shape is outside this (caller diagnoses).
   The chain `steps' is consumed on success (moved into the tree). */
static sva_stree_t* sva_expand_first_match_(const struct vlltype&loc,
					    std::vector<sva_seq_step_t>&steps)
{
      (void)loc;
      int lo = -1, hi = -1;
      for (size_t i = 0 ; i < steps.size() ; i += 1)
	    if (steps[i].fm) { if (lo < 0) lo = (int)i; hi = (int)i; }
      if (lo < 0) return nullptr;
	/* Find the single window inside the wrapper; reject lv, rep, or
	   a second variable step. */
      int w = -1;
      for (int i = lo ; i <= hi ; i += 1) {
	    if (steps[i].lv_rhs) return nullptr;
	    bool var = (i > lo)
		       && (steps[i].delay_lo != steps[i].delay_hi);
	    if (steps[i].rep_tail != 0) return nullptr;
	    if (steps[i].delay_lo < 0) return nullptr;   // unbounded: not here
	    if (var) { if (w >= 0) return nullptr; w = i; }
      }
      if (w < 0) return nullptr;
      long m = steps[w].delay_lo, n = steps[w].delay_hi;
      if (n < m || n - m > 64) return nullptr;       // keep the fan-out sane
      PExpr*awaited = steps[w].expr;
      if (!awaited) return nullptr;

	/* Build one branch chain per earliest-offset k. */
      sva_stree_t*tree = nullptr;
      for (long k = m ; k <= n ; k += 1) {
	    std::vector<sva_seq_step_t>*br = new std::vector<sva_seq_step_t>;
	    bool ok = true;
	      /* steps before the window: clone verbatim. */
	    for (int i = 0 ; i < w && ok ; i += 1) {
		  sva_seq_step_t st = steps[i];
		  st.fm = false; st.lv_rhs = nullptr; st.lv_name = perm_string();
		  st.expr = sva_clone_expr_(steps[i].expr);
		  if (!st.expr && steps[i].expr) ok = false;
		  br->push_back(st);
	    }
	      /* window expansion: !awaited at offsets m..k-1, awaited at k. */
	    for (long off = m ; off <= k && ok ; off += 1) {
		  sva_seq_step_t st;
		  st.delay_lo = st.delay_hi = (off == m) ? m : 1;
		  PExpr*aw = sva_clone_expr_(awaited);
		  if (!aw) { ok = false; break; }
		  if (off < k) {
			PEUnary*nb = new PEUnary('!', aw);
			FILE_NAME(nb, loc);
			st.expr = nb;
		  } else {
			st.expr = aw;
		  }
		  br->push_back(st);
	    }
	      /* steps after the window: clone verbatim (delays are relative
		 to the awaited match, which the offset-k b reproduces). */
	    for (int i = w + 1 ; i < (int)steps.size() && ok ; i += 1) {
		  sva_seq_step_t st = steps[i];
		  st.fm = false; st.lv_rhs = nullptr; st.lv_name = perm_string();
		  st.expr = sva_clone_expr_(steps[i].expr);
		  if (!st.expr && steps[i].expr) ok = false;
		  br->push_back(st);
	    }
	    if (!ok) {
		  for (size_t i = 0 ; i < br->size() ; i += 1) delete (*br)[i].expr;
		  delete br;
		  if (tree) sva_tree_delete_(tree, true);
		  return nullptr;
	    }
	    sva_stree_t*leaf = new sva_stree_t;
	    leaf->chain = br;
	    if (!tree) {
		  tree = leaf;
	    } else {
		  sva_stree_t*t = new sva_stree_t;
		  t->kind = sva_stree_t::SEQ_OR;
		  t->a = tree;
		  t->b = leaf;
		  tree = t;
	    }
      }
	/* Consume the source chain. */
      for (size_t i = 0 ; i < steps.size() ; i += 1) {
	    delete steps[i].expr;
	    delete steps[i].lv_rhs;
      }
      steps.clear();
      return tree;
}

/* M9-NFA: `first_match` (IEEE 1800-2017 16.9.9) is transparent (its
   inner sequence flows straight into the chain) — which is EXACT for a
   standalone/existence position (a cover/assert of first_match(s)
   matches iff s does, and slot-clear-on-accept already counts the first
   match once per attempt). It is WRONG only when the wrapped sequence
   has multiple match lengths AND its end feeds a continuation: then the
   cut (keep only the shortest match) changes which match continues, and
   the transparent lowering would silently OVER-match. That case needs a
   sub-sequence node in the IR (the sequence-expression tree) to carry
   the cut; until then it is a LOUD sorry rather than a silent
   miscompile. Returns false (diagnosed) for the composed multi-length
   case, true otherwise. tail_continues = something after this chain
   depends on its match end (an implication antecedent). */
static bool sva_check_first_match_(const struct vlltype&loc,
				   const std::vector<sva_seq_step_t>&steps,
				   bool tail_continues)
{
      int first_fm = -1, last_fm = -1;
      for (size_t i = 0 ; i < steps.size() ; i += 1)
	    if (steps[i].fm) { if (first_fm < 0) first_fm = (int)i; last_fm = (int)i; }
      if (first_fm < 0) return true;
	/* Variable length WITHIN the wrapper: a window/unbounded delay on
	   a non-first wrapped step, or any range repetition. (The first
	   wrapped step's incoming delay is the external gap to the
	   first_match, not internal length variability.) */
      bool fm_var = false;
      for (int i = first_fm ; i <= last_fm ; i += 1) {
	    if (i > first_fm && (steps[i].delay_lo != steps[i].delay_hi
				 || steps[i].delay_lo < 0))
		  fm_var = true;
	    if (steps[i].rep_tail != 0) fm_var = true;
      }
      if (!fm_var) return true;
      (void)loc;
      bool composed = (last_fm + 1 < (int)steps.size()) || tail_continues;
      return !composed;   // false => composed multi-length: expand or diagnose
}

/* M9-NFA stage C.3: sequence endpoint methods `seq.triggered' /
   `seq.matched' (IEEE 1800-2017 16.13.6). For a FIXED-LENGTH named
   sequence the endpoint boolean — "seq completed a match ending at this
   cycle" — is the $past-sampled conjunction of the sequence's step
   booleans, each delayed by its distance from the match end (`a ##1 b'
   -> `$past(a,1) && b'). This is the same fixed-length match indicator
   the legacy engine already builds for a fixed antecedent, so both
   engines lower it identically. Variable-length, unbounded, repetition,
   goto/nonconsec, or local-variable sequence bodies need the automaton
   endpoint signal and are a loud sorry; a base that is not a declared
   sequence is left untouched for the ordinary unresolved-reference
   diagnostic. Under a single clock `.triggered' and `.matched' coincide
   (the observed-region distinction is a stage-D multiclock concern).
   Returns false (diagnosed) on an unsupported endpoint. */
/* Build the $past-conjunction indicator for `seqname.method'. Returns
   the expression, or null: with `failed' set when the sequence exists
   but cannot be lowered (diagnosed here), clear when the name is not a
   declared sequence (caller leaves the reference alone). */
static PExpr* sva_endpoint_indicator_(const struct vlltype&loc,
				      perm_string seqname, perm_string method,
				      bool&failed)
{
      std::map<sva_scoped_name_t, std::vector<sva_seq_step_t>*>::iterator it =
	    sva_resolve_(sva_module_sequences, seqname);
      if (it == sva_module_sequences.end() || !it->second)
	    return nullptr;

      std::vector<sva_seq_step_t>&body = *it->second;
      bool ok = !body.empty();
      long L = 0;
      std::vector<long> off (body.size(), 0);
      for (size_t j = 0 ; j < body.size() && ok ; j += 1) {
	    const sva_seq_step_t&st = body[j];
	    if (st.delay_lo < 0 || st.delay_lo != st.delay_hi
		|| st.rep_tail != 0 || st.rep_kind != 0 || st.lv_rhs)
		  ok = false;
	    else { L += st.delay_lo; off[j] = L; }
      }
      if (!ok) {
	    cerr << loc << ": sorry: `" << seqname << "." << method
		 << "' is supported only for a fixed-length sequence "
		 << "(constant ##N delays, no ##[m:n]/##[m:$]/[*]/goto/"
		 << "local variables); the assertion is dropped." << endl;
	    error_count += 1;
	    failed = true;
	    return nullptr;
      }
	/* AND over j of $past(clone(e_j), L - off[j]). */
      PExpr*conj = nullptr;
      for (size_t j = 0 ; j < body.size() ; j += 1) {
	    PExpr*ej = sva_clone_expr_(body[j].expr);
	    if (!ej) { ok = false; break; }
	    PExpr*term = sva_past_(loc, ej, L - off[j]);
	    conj = conj ? sva_logic_(loc, 'a', conj, term) : term;
      }
      if (!ok || !conj) {
	    cerr << loc << ": sorry: `" << seqname << "." << method
		 << "' has a step expression that cannot be lowered; "
		 << "the assertion is dropped." << endl;
	    error_count += 1;
	    delete conj;
	    failed = true;
	    return nullptr;
      }
      return conj;
}

/* Recursively rewrite `seq.triggered'/`seq.matched' references INSIDE
   a step's boolean expression (16.13.6: the endpoint methods are
   ordinary booleans and compose with any operator). The old lowering
   only matched a step whose ENTIRE expression was the bare reference:
   `s1.triggered && e' left the reference unresolved and the assertion
   went silently wrong -- differently in each engine (recovery C5). */
static PExpr* sva_rewrite_endpoint_expr_(const struct vlltype&loc,
					 PExpr*e, bool&failed)
{
      if (!e || failed) return e;

      if (PEIdent*id = dynamic_cast<PEIdent*>(e)) {
	    if (id->path().package) return e;
	    const pform_name_t&nm = id->path().name;
	    if (nm.size() != 2) return e;
	    if (!nm.front().index.empty() || !nm.back().index.empty())
		  return e;
	    perm_string method = nm.back().name;
	    if (strcmp(method, "triggered") && strcmp(method, "matched"))
		  return e;
	    PExpr*ind = sva_endpoint_indicator_(loc, nm.front().name,
						method, failed);
	    if (!ind) return e;
	    delete e;
	    return ind;
      }

      if (PEUnary*un = dynamic_cast<PEUnary*>(e)) {
	    PExpr*sub = sva_rewrite_endpoint_expr_(loc, un->get_expr(), failed);
	    if (sub == un->get_expr()) return e;
	    PEUnary*cp = new PEUnary(un->get_op(), sub);
	    cp->set_line(*e);
	    return cp;
      }
      if (PEBinary*bin = dynamic_cast<PEBinary*>(e)) {
	    PExpr*l = sva_rewrite_endpoint_expr_(loc, bin->get_left(), failed);
	    PExpr*r = sva_rewrite_endpoint_expr_(loc, bin->get_right(), failed);
	    if (l == bin->get_left() && r == bin->get_right()) return e;
	    PEBinary*cp;
	    if (dynamic_cast<PEBComp*>(e))
		  cp = new PEBComp(bin->get_op(), l, r);
	    else if (dynamic_cast<PEBLogic*>(e))
		  cp = new PEBLogic(bin->get_op(), l, r);
	    else
		  cp = new PEBinary(bin->get_op(), l, r);
	    cp->set_line(*e);
	    return cp;
      }
      if (PETernary*ter = dynamic_cast<PETernary*>(e)) {
	    PExpr*c = sva_rewrite_endpoint_expr_(loc, ter->get_cond(), failed);
	    PExpr*t = sva_rewrite_endpoint_expr_(loc, ter->get_true(), failed);
	    PExpr*f = sva_rewrite_endpoint_expr_(loc, ter->get_false(), failed);
	    if (c == ter->get_cond() && t == ter->get_true()
		&& f == ter->get_false()) return e;
	    PETernary*cp = new PETernary(c, t, f);
	    cp->set_line(*e);
	    return cp;
      }

      return e;
}

static bool sva_lower_endpoint_methods_(const struct vlltype&loc,
					std::vector<sva_seq_step_t>&steps)
{
      for (size_t i = 0 ; i < steps.size() ; i += 1) {
	    bool failed = false;
	    steps[i].expr = sva_rewrite_endpoint_expr_(loc, steps[i].expr,
						       failed);
	    if (failed)
		  return false;
	    if (steps[i].lv_rhs) {
		  steps[i].lv_rhs = sva_rewrite_endpoint_expr_(loc,
				steps[i].lv_rhs, failed);
		  if (failed)
			return false;
	    }
      }
      return true;
}

/* Apply the endpoint-method lowering across a sequence-combinator
   tree: every LEAF chain and every throughout-invariant expression
   (the tree dispatch used to bypass the lowering entirely). */
static bool sva_lower_endpoint_methods_tree_(const struct vlltype&loc,
					     sva_stree_t*t)
{
      if (!t) return true;
      if (t->chain && !sva_lower_endpoint_methods_(loc, *t->chain))
	    return false;
      if (t->gexpr) {
	    bool failed = false;
	    t->gexpr = sva_rewrite_endpoint_expr_(loc, t->gexpr, failed);
	    if (failed) return false;
      }
      if (!sva_lower_endpoint_methods_tree_(loc, t->a)) return false;
      if (!sva_lower_endpoint_methods_tree_(loc, t->b)) return false;
      return true;
}

/* Nonblocking assignment `lv <= rv' — the multiclock handoff counters
   are written NBA so a coincident cross-domain read sees the pre-edge
   (sampled) value. */
static Statement* sva_assign_nb_(const struct vlltype&loc, perm_string lv,
				 PExpr*rv)
{
      sva_mark_strict_(rv);
      PAssignNB*a = new PAssignNB(sva_id_(loc, lv), rv);
      FILE_NAME(a, loc);
      return a;
}

static PExpr* sva_num32_(const struct vlltype&loc, uint64_t v)
{
      PENumber*n = new PENumber(new verinum(v, 32));
      FILE_NAME(n, loc);
      return n;
}

/* Execute an assertion action once per obligation in a runtime-valued
   batch. PRepeat owns both the count expression and the action. */
static Statement* sva_repeat_(const struct vlltype&loc, PExpr*count,
			      Statement*action)
{
      PRepeat*rep = new PRepeat(count, action);
      FILE_NAME(rep, loc);
      return rep;
}

/* M9-7: expand a FIXED-length sequence chain (constant ##N delays, no
   repetition/goto/local-variable/first_match) into per-tick boolean
   slots. slots[t] is the boolean checked at tick offset t (null = a
   pure delay tick). Returns false for any non-fixed shape. The
   expressions stay owned by the steps until the caller steals them. */
/* Flatten a chain into one boolean per tick (null slot = a pure delay tick).
 *
 * `window' is an out-parameter used only for the CONSEQUENT: the number of
 * EXTRA ticks the final boolean may arrive on, i.e. the `n-m' of a trailing
 * `##[m:n]'. Zero for a fixed chain. Pass null to forbid it, which is what
 * the antecedent does.
 *
 * Two relaxations apply to a consequent and NOT to an antecedent, both for
 * the same reason -- a property is satisfied by the EARLIEST match of its
 * consequent, so a longer alternative adds nothing:
 *
 *   - `rep_tail' (the `n-m' the parser leaves on a trailing `b[*m:n]' after
 *     collapsing it to `b[*m]') is simply dropped. In an antecedent it
 *     cannot be: each additional match there creates its own obligation, so
 *     ignoring it would under-count them.
 *
 *   - a bounded `##[m:n]' before the FINAL boolean becomes a window the
 *     obligation may be discharged anywhere inside. Only trailing, because
 *     a mid-chain window branches: `##[1:2] b ##1 c' can fail on the b@1
 *     branch and still match on b@2, which one alive-bit per tick cannot
 *     represent.
 */
static bool sva_mc_expand_chain_(std::vector<sva_seq_step_t>&steps,
				 std::vector<PExpr*>&slots,
				 long*window = nullptr)
{
      long off = 0;
      if (window) *window = 0;
      for (size_t j = 0 ; j < steps.size() ; j += 1) {
	    const sva_seq_step_t&st = steps[j];
	    bool last = (j + 1 == steps.size());
	    if (st.rep_kind || st.lv_rhs || st.fm) return false;
	    if (st.rep_tail && !(window && last)) return false;

	    long lo = st.delay_lo;
	    if (st.delay_lo != st.delay_hi) {
		    /* a bounded window, trailing, consequent only */
		  if (!window || !last || j == 0) return false;
		  if (st.delay_lo < 1 || st.delay_hi < st.delay_lo) return false;
		  *window = st.delay_hi - st.delay_lo;
	    }
	    if (lo < 0) return false;

	    if (j == 0) {
		  /* A sequence may begin with a cycle delay after its leading
		     clocking event: `@(c1) ##1 a ##1 @(c2) b'.  Slot zero is
		     then a pure-delay tick and the first operand lives at slot
		     `lo'.  The old zero-only check rejected this ordinary
		     16.13.1 clock-flow form even though the pipeline below already
		     represents null delay slots exactly. */
		  off = lo;
	    } else {
		  if (lo < 1) return false;
		  off += lo;
	    }
	    if ((size_t)off + 1 > slots.size())
		  slots.resize((size_t)off + 1, nullptr);
	    if (slots[(size_t)off]) return false;
	    slots[(size_t)off] = st.expr;
      }
      return true;
}

/* M9-7: multiclocked sequence/property lowering (IEEE 1800-2017 16.13).
   A fixed boolean chain may flow from c1 to c2 through either:

     prefix ##0 @(c2) suffix   -- nearest c2 tick at or after the c1 match
     prefix ##1 @(c2) suffix   -- nearest c2 tick strictly after it

   The same boundary is used after an implication. Each side pipelines in
   its own clock domain and a request/acknowledge COUNT carries every match
   across the boundary without collapsing coincident obligations.

   Lowered by a race-free request/acknowledge counter handoff. Each
   counter is written by exactly one clock domain (req by c1, ack by c2),
   so there is no cross-domain write race; the c2 block's read of `req'
   sees the value latched before the c2 edge (NBA update semantics),
   which is exactly the "strictly after" sampling `|=>' requires:

     reg [31:0] req=0, ack=0;
     always @(c1) if (a) req <= req + 1;               // outstanding++
     always @(c2) if (req != ack) begin                // due now
         ack <= req;                                    // discharge all
         if (b) <pass> else <fail>;
     end

   ##0 uses a blocking request update and lets the c2 process reach an
   Inactive-region #0 before it captures the request, so a coincident c1
   tick is visible without depending on Active-process order. ##1 uses an
   NBA request update, so a coincident c2 tick necessarily sees the old
   request. Operand reads themselves are rewritten to the runtime's
   Preponed-value loads in both domains. */
static void pform_make_multiclock_assertion_(const struct vlltype&loc,
					     sva_property_t*prop,
					     Statement*fail_stmt,
					     Statement*pass_stmt, int kind)
{
      PEventStatement*c1 = prop->clk_evt;
      PEventStatement*c2 = prop->seq_clk_evt;
      const char*why = nullptr;
      bool cover = (kind == 2);

      bool plain = (prop->op_type == 0);
      if (prop->op_type < 0 || prop->op_type > 2)
	    why = "this multiclocked property operator";
      else if (!c1)
	    why = "a multiclocked property with no explicit antecedent clock";
      else if (prop->mc_boundary != 0 && prop->mc_boundary != 1)
	    why = "a multiclocked sequence whose clock-flow boundary is "
		  "not ##0 or ##1";
      else if (!prop->seq || prop->seq->empty())
	    why = "a multiclocked property with an empty second-clock suffix";
      else if (plain && (!prop->mc_prefix || prop->mc_prefix->empty()))
	    why = "a multiclocked sequence with an empty first-clock prefix";
      else if (!plain && (!prop->antecedent || prop->antecedent->empty()))
	    why = "a multiclocked implication with an empty antecedent";

	/* M9-7: each side may be a FIXED-length boolean chain
	   (`a0 ##d a1 ...', constant delays): it pipelines exactly in
	   its own clock domain. Expand each chain to a per-tick slot
	   array (null slot = pure delay tick). */
      std::vector<PExpr*> a_slots, p_slots, b_slots;
      long b_window = 0;      /* extra ticks the final boolean may land on */
      if (!why) {
	    if (prop->antecedent)
		  sva_splice_sequences_(loc, *prop->antecedent);
	    if (prop->mc_prefix)
		  sva_splice_sequences_(loc, *prop->mc_prefix);
	    sva_splice_sequences_(loc, *prop->seq);
	    if (prop->antecedent
		&& !sva_mc_expand_chain_(*prop->antecedent, a_slots))
		  why = "a multiclocked implication whose ANTECEDENT is not "
			"a fixed-length boolean chain (constant ##N delays "
			"only; a variable-length antecedent creates one "
			"obligation per match, which the request counter "
			"cannot distinguish)";
	    else if (prop->mc_prefix
		     && !sva_mc_expand_chain_(*prop->mc_prefix, p_slots))
		  why = "a multiclocked sequence whose first-clock prefix is "
			"not a fixed-length boolean chain (constant ##N delays "
			"only)";
	    else if (!sva_mc_expand_chain_(*prop->seq, b_slots, &b_window))
		  why = "a multiclocked property's second-clock suffix is "
			"neither a fixed-length boolean chain nor one with a "
			"single trailing bounded window (`##[m:n] b', "
			"`b[*m:n]')";
	    else if (a_slots.size() > 64 || p_slots.size() > 64
		     || b_slots.size() + b_window > 64)
		  why = "a multiclocked property with a chain over "
			"64 ticks";
      }
      if (why) {
	    cerr << loc << ": sorry: " << why << " is not supported "
		 << "(IEEE 1800-2017 16.13); the assertion is dropped."
		 << endl;
	    error_count += 1;
	    delete fail_stmt; delete pass_stmt;
	    pform_sva_destroy_property(prop);
	    return;
      }

      bool overlap_boundary = (prop->mc_boundary == 0);

      unsigned inst = sva_gensym_counter++;
      perm_string req = sva_make_reg_(loc, inst, "mcreq", 0, true);
      perm_string ack = sva_make_reg_(loc, inst, "mcack", 0, true);
      perm_string req_epoch = sva_make_reg_(loc, inst, "mcrep", 0, true);

	/* A verdict can be reached in either clock domain, but a user action
	   syntax tree has exactly one owner. Domain-local monotonically
	   increasing request counters hand each verdict to one persistent
	   Reactive-region dispatcher. This is deliberately more general than
	   cloning action statements: loops, timing controls, event triggers,
	   receiver calls, named blocks, and every other legal statement keep
	   their original syntax and scope. Separate counters also preserve
	   multiplicity without giving any register more than one writer. */
      bool have_pass_action = pass_stmt != nullptr;
      perm_string pv_req, pn_req, pv_ack, pn_ack, pv_due, pn_due;
      perm_string fp_req, fs_req, fp_ack, fs_ack, fp_due, fs_due;
      if (!cover) {
	    pv_req = sva_make_reg_(loc, inst, "mcpvrq", 0, true);
	    pn_req = sva_make_reg_(loc, inst, "mcpnrq", 0, true);
	    pv_ack = sva_make_reg_(loc, inst, "mcpvak", 0, true);
	    pn_ack = sva_make_reg_(loc, inst, "mcpnak", 0, true);
	    pv_due = sva_make_reg_(loc, inst, "mcpvdu", 0, true);
	    pn_due = sva_make_reg_(loc, inst, "mcpndu", 0, true);
	    fp_req = sva_make_reg_(loc, inst, "mcfprq", 0, true);
	    fs_req = sva_make_reg_(loc, inst, "mcfsrq", 0, true);
	    fp_ack = sva_make_reg_(loc, inst, "mcfpak", 0, true);
	    fs_ack = sva_make_reg_(loc, inst, "mcfsak", 0, true);
	    fp_due = sva_make_reg_(loc, inst, "mcfpdu", 0, true);
	    fs_due = sva_make_reg_(loc, inst, "mcfsdu", 0, true);
      }

	/* M9-7: `disable iff'. The condition is a level, read in BOTH
	   domains at their own ticks, so each always block needs its own
	   copy. While it holds, the c1 side starts and matures nothing and
	   the c2 side drops any outstanding obligation -- an aborted
	   attempt neither passes nor fails (IEEE 1800-2017 16.12). */
      PExpr*dis = prop->disable_iff_expr;
      prop->disable_iff_expr = nullptr;
      PExpr*dis1 = dis ? sva_clone_expr_(dis) : nullptr;
      PExpr*dis2 = dis ? sva_clone_expr_(dis) : nullptr;
      if (dis && (!dis1 || !dis2)) {
	    cerr << loc << ": sorry: this `disable iff' condition has a "
		 << "shape that cannot be copied into both clock domains "
		 << "of a multiclocked property (IEEE 1800-2017 16.13.3); "
		 << "the assertion is dropped." << endl;
	    error_count += 1;
	    delete dis; delete dis1; delete dis2;
	    delete fail_stmt; delete pass_stmt;
	    pform_sva_destroy_property(prop);
	    return;
      }
      delete dis;

	/* Cover counts matches into the same register name the legacy and
	   automaton engines use, so a test reads the count identically
	   whichever engine or clocking shape produced it. */
      perm_string r_cnt;
      if (cover) r_cnt = sva_make_reg_(loc, inst, "cnt", 0, true);

	/* Steal the slot booleans from their steps (the slot arrays
	   alias the step expressions). */
      if (prop->antecedent)
	    for (size_t j = 0 ; j < prop->antecedent->size() ; j += 1)
		  (*prop->antecedent)[j].expr = nullptr;
      if (prop->mc_prefix)
	    for (size_t j = 0 ; j < prop->mc_prefix->size() ; j += 1)
		  (*prop->mc_prefix)[j].expr = nullptr;
      for (size_t j = 0 ; j < prop->seq->size() ; j += 1)
	    (*prop->seq)[j].expr = nullptr;

      size_t Ta = a_slots.size();
      size_t Tp = p_slots.size();
      size_t Tb = b_slots.size();

	/* Concurrent-assertion operands are sampled in Preponed (16.5.1).
	   The c1 calculation deliberately stays before Observed because a
	   coincident ##0 c2 edge must see its blocking request update. That is
	   semantically safe only when every user operand has already become a
	   Preponed load. The c2 side captures the request first (preserving the
	   ##0/##1 boundary) and waits for Observed before it evaluates these
	   same sampled expressions below. */
      std::map<std::string, pform_name_t> prep_sampled;
      unsigned prep_live_operands = 0;
      auto sample_slots = [&](std::vector<PExpr*>&slots) {
	    for (size_t k = 0 ; k < slots.size() ; k += 1) {
		  if (!slots[k]) continue;
		  PExpr*prep = sva_wrap_preponed_(
			slots[k], prep_sampled, prep_live_operands);
		  if (!prep) continue;
		  delete slots[k];
		  slots[k] = prep;
	    }
      };
      sample_slots(a_slots);
      sample_slots(p_slots);
      sample_slots(b_slots);

	/* Sampled-value histories are clock-domain state, not obligation
	   state: `$past' in the suffix must advance at every c2 edge even
	   when req==ack, and a prefix call must advance at every c1 edge.
	   The rewrite supplies a top-of-tick capture and a bottom-of-tick
	   history shift for each checker domain. Keeping both in the checker
	   (rather than a separate NBA sampler) matters because the verdict
	   waits until Observed: a separate sampler's same-edge NBA would
	   overwrite the prior value before `$past' was read. */
      unsigned mc_hist_idx = 0;
      std::vector<Statement*> mc_pre1, mc_post1, mc_init1;
      std::vector<Statement*> mc_pre2, mc_post2, mc_init2;
      auto bind_sampled = [&](std::vector<PExpr*>&slots,
			      std::vector<Statement*>&pre,
			      std::vector<Statement*>&post,
			      std::vector<Statement*>&init) {
	    for (size_t k = 0 ; k < slots.size() ; k += 1) {
		  if (!slots[k]) continue;
		  PExpr*bound = sva_rewrite_sampled_(
			loc, slots[k], inst, mc_hist_idx, pre, post, init);
		  if (bound && bound != slots[k])
			slots[k] = bound;
	    }
      };
      bind_sampled(a_slots, mc_pre1, mc_post1, mc_init1);
      bind_sampled(p_slots, mc_pre1, mc_post1, mc_init1);
      bind_sampled(b_slots, mc_pre2, mc_post2, mc_init2);

	/* M9-7: antecedent PIPELINE in the c1 domain. pa_k = "an
	   attempt matched the first k ticks and awaits the tick-k
	   check now"; a fresh attempt starts every tick (pa_0 == 1).
	   All writes are NBA, so a tick's reads see the previous
	   tick's stages. */
      std::vector<perm_string> pa (Ta);
      for (size_t k = 1 ; k < Ta ; k += 1)
	    pa[k] = sva_make_reg_(loc, inst, "mca", (unsigned)k);
	/* A first-clock prefix after an implication has its own pipeline.
	   For nonoverlapping implication, pstart delays a completed
	   antecedent by one c1 tick before prefix slot zero is tested. */
      std::vector<perm_string> pp (Tp);
      for (size_t k = 1 ; k < Tp ; k += 1)
	    pp[k] = sva_make_reg_(loc, inst, "mcp", (unsigned)k);
      perm_string pstart;
      if (!plain && Tp && prop->op_type == 2)
	    pstart = sva_make_reg_(loc, inst, "mcps", 0);
	/* Consequent pipeline stages tb_1..tb_{Tw-1} in the c2 domain. With a
	   trailing window the pipe runs b_window ticks past the fixed length:
	   ages Tb-1 .. Tb-1+b_window are all ticks the final boolean may
	   discharge the obligation on. A c2 tick can receive several c1
	   matches at once, so every age carries an obligation COUNT rather
	   than a presence bit. */
      size_t Tw = Tb + (size_t)b_window;
      std::vector<perm_string> tb (Tw);
      for (size_t k = 1 ; k < Tw ; k += 1)
	    tb[k] = sva_make_reg_(loc, inst, "mcb", (unsigned)k, true);

	/* initial: zero everything + register the assertion for VPI. */
      std::vector<Statement*> initv;
      initv.push_back(sva_assign_(loc, req, sva_num32_(loc, 0)));
      initv.push_back(sva_assign_(loc, ack, sva_num32_(loc, 0)));
      initv.push_back(sva_assign_(loc, req_epoch, sva_num32_(loc, 0)));
      if (!cover) {
	    initv.push_back(sva_assign_(loc, pv_req, sva_num32_(loc, 0)));
	    initv.push_back(sva_assign_(loc, pn_req, sva_num32_(loc, 0)));
	    initv.push_back(sva_assign_(loc, pv_ack, sva_num32_(loc, 0)));
	    initv.push_back(sva_assign_(loc, pn_ack, sva_num32_(loc, 0)));
	    initv.push_back(sva_assign_(loc, pv_due, sva_num32_(loc, 0)));
	    initv.push_back(sva_assign_(loc, pn_due, sva_num32_(loc, 0)));
	    initv.push_back(sva_assign_(loc, fp_req, sva_num32_(loc, 0)));
	    initv.push_back(sva_assign_(loc, fs_req, sva_num32_(loc, 0)));
	    initv.push_back(sva_assign_(loc, fp_ack, sva_num32_(loc, 0)));
	    initv.push_back(sva_assign_(loc, fs_ack, sva_num32_(loc, 0)));
	    initv.push_back(sva_assign_(loc, fp_due, sva_num32_(loc, 0)));
	    initv.push_back(sva_assign_(loc, fs_due, sva_num32_(loc, 0)));
      }
      for (size_t k = 1 ; k < Ta ; k += 1)
	    initv.push_back(sva_assign_(loc, pa[k], sva_bit_(loc, 0)));
      for (size_t k = 1 ; k < Tp ; k += 1)
	    initv.push_back(sva_assign_(loc, pp[k], sva_bit_(loc, 0)));
      if (pstart != perm_string())
	    initv.push_back(sva_assign_(loc, pstart, sva_bit_(loc, 0)));
      for (size_t k = 1 ; k < Tw ; k += 1)
	    initv.push_back(sva_assign_(loc, tb[k], sva_bit_(loc, 0)));
      initv.insert(initv.end(), mc_init1.begin(), mc_init1.end());
      initv.insert(initv.end(), mc_init2.begin(), mc_init2.end());
      if (cover)
	    initv.push_back(sva_assign_(loc, r_cnt,
			new PENumber(new verinum((uint64_t)0, 32))));
      perm_string r_kill1 = sva_kill_seen_reg_(loc, inst, 0, initv);
      perm_string r_kill2 = sva_kill_seen_reg_(loc, inst, 1, initv);
      for (std::map<std::string, pform_name_t>::const_iterator it =
		prep_sampled.begin() ; it != prep_sampled.end() ; ++it)
	    initv.push_back(sva_hist_on_stmt_(loc, it->second));
      if (prep_live_operands > 0)
	    cerr << loc << ": warning: this multiclocked assertion has "
		 << prep_live_operands << " operand(s) that are read live "
		 << "instead of sampled in the Preponed region (IEEE "
		 << "1800-2017 16.5.1); a blocking write in the same time "
		 << "slot as either clock can be visible to the assertion."
		 << endl;
      initv.push_back(sva_register_stmt_(loc, inst));
      PProcess*ip = pform_make_behavior(IVL_PR_INITIAL,
					sva_block_(loc, initv), nullptr);
      FILE_NAME(ip, loc);

	/* c1 body. An implication first pipelines its antecedent; a false
	   antecedent step is a vacuous success. If a first-clock consequent
	   prefix exists, its failures are real property failures. The prefix
	   starts immediately for |->, one c1 tick later for |=>, and every
	   c1 tick for a plain multiclocked sequence. */
      std::vector<Statement*> body1;
      {
	    auto ante_gate = [&](size_t k) -> PExpr* {
		  return (k == 0) ? sva_bit_(loc, 1)
				  : (PExpr*)sva_id_(loc, pa[k]);
	    };
	    perm_string vcount;
	    if (!plain && !cover && have_pass_action) {
		  vcount = sva_make_reg_(loc, inst, "mcva", 0, true);
		  body1.push_back(sva_assign_(loc, vcount,
					      sva_num32_(loc, 0)));
	    }
	    PExpr*ante_match = nullptr;
	    if (!plain) {
		  for (size_t k = 0 ; k < Ta ; k += 1) {
			PExpr*advance;
			if (a_slots[k]) {
			      perm_string adv = sva_make_reg_(
					loc, inst, "mcaadv", (unsigned)k);
			      PEBinary*advx = new PEBLogic('a', ante_gate(k),
							   a_slots[k]);
			      FILE_NAME(advx, loc);
			      body1.push_back(sva_assign_(loc, adv, advx));
			      advance = sva_id_(loc, adv);
			      if (!cover && have_pass_action) {
				    PEBinary*dead = new PEBLogic(
					      'a', ante_gate(k),
					      sva_not_(loc, sva_id_(loc, adv)));
				    FILE_NAME(dead, loc);
				    PEBinary*add = new PEBinary(
					      '+', sva_id_(loc, vcount), dead);
				    FILE_NAME(add, loc);
				    body1.push_back(
					      sva_assign_(loc, vcount, add));
			      }
			} else {
			      advance = ante_gate(k);
			}
			if (k + 1 < Ta)
			      body1.push_back(sva_assign_nb_(
					loc, pa[k+1], advance));
			else
			      ante_match = advance;
		  }
	    }

	    PExpr*match = ante_match;
	    perm_string fcount;
	    if (Tp) {
		  if (!cover) {
			fcount = sva_make_reg_(loc, inst, "mcpf", 0, true);
			body1.push_back(sva_assign_(loc, fcount,
						   sva_num32_(loc, 0)));
		  }

		  PExpr*prefix_start;
		  if (plain) {
			prefix_start = sva_bit_(loc, 1);
		  } else if (prop->op_type == 1) {
			prefix_start = ante_match;
			ante_match = nullptr;
		  } else {
			body1.push_back(sva_assign_nb_(loc, pstart,
						     ante_match));
			ante_match = nullptr;
			prefix_start = sva_id_(loc, pstart);
		  }

		  auto pgate = [&](size_t k) -> PExpr* {
			if (k != 0) return sva_id_(loc, pp[k]);
			return sva_clone_expr_(prefix_start);
		  };

		  match = nullptr;
		  for (size_t k = 0 ; k < Tp ; k += 1) {
			PExpr*advance;
			if (p_slots[k]) {
			      perm_string adv = sva_make_reg_(
					loc, inst, "mcpadv", (unsigned)k);
			      PEBinary*advx = new PEBLogic('a', pgate(k),
							   p_slots[k]);
			      FILE_NAME(advx, loc);
			      body1.push_back(sva_assign_(loc, adv, advx));
			      advance = sva_id_(loc, adv);
			      if (!cover) {
				    PEBinary*dead = new PEBLogic(
					      'a', pgate(k),
					      sva_not_(loc, sva_id_(loc, adv)));
				    FILE_NAME(dead, loc);
				    PEBinary*add = new PEBinary(
					      '+', sva_id_(loc, fcount), dead);
				    FILE_NAME(add, loc);
				    body1.push_back(
					      sva_assign_(loc, fcount, add));
			      }
			} else {
			      advance = pgate(k);
			}
			if (k + 1 < Tp)
			      body1.push_back(sva_assign_nb_(
					loc, pp[k+1], advance));
			else
			      match = advance;
		  }
		  delete prefix_start;
	    }

	    PExpr*inc = new PEBinary('+', sva_id_(loc, req), sva_num32_(loc, 1));
	    FILE_NAME(inc, loc);
	    Statement*bump = overlap_boundary
		  ? sva_assign_(loc, req, inc)
		  : sva_assign_nb_(loc, req, inc);
	    body1.push_back(sva_if_(loc, match, bump, nullptr));
	    if (!plain && !cover && have_pass_action) {
		  PEBinary*add = new PEBinary(
			'+', sva_id_(loc, pv_req), sva_id_(loc, vcount));
		  FILE_NAME(add, loc);
		  body1.push_back(sva_if_(loc, sva_id_(loc, vcount),
				sva_assign_(loc, pv_req, add), nullptr));
	    }
	    if (Tp && !cover) {
		  PEBinary*add = new PEBinary(
			'+', sva_id_(loc, fp_req), sva_id_(loc, fcount));
		  FILE_NAME(add, loc);
		  body1.push_back(sva_if_(loc, sva_id_(loc, fcount),
				sva_assign_(loc, fp_req, add), nullptr));
	    }
      }

      auto clear_domain1_state = [&]() -> Statement* {
	    std::vector<Statement*> clear;
	    for (size_t k = 1 ; k < Ta ; k += 1)
		  clear.push_back(sva_assign_(loc, pa[k], sva_bit_(loc, 0)));
	    for (size_t k = 1 ; k < Tp ; k += 1)
		  clear.push_back(sva_assign_(loc, pp[k], sva_bit_(loc, 0)));
	    if (pstart != perm_string())
		  clear.push_back(sva_assign_(loc, pstart, sva_bit_(loc, 0)));
	    if (clear.empty())
		  clear.push_back(sva_assign_(loc, req, sva_id_(loc, req)));
	    return sva_block_(loc, clear);
      };
      auto clear_domain1_kill = [&]() -> Statement* {
	    std::vector<Statement*> clear;
	    clear.push_back(clear_domain1_state());
	    clear.push_back(sva_assign_(loc, req, sva_num32_(loc, 0)));
	    clear.push_back(sva_assign_(
		  loc, req_epoch, sva_kill_generation_expr_(loc, inst)));
	    return sva_block_(loc, clear);
      };
	/* disable iff: abort in the c1 domain -- clear the stages so no
	   in-flight attempt matures, and do not bump req. */
      if (dis1) {
	    std::vector<Statement*> gated1;
	    gated1.push_back(sva_if_(loc, dis1, clear_domain1_state(),
				     sva_block_(loc, body1)));
	    body1.swap(gated1);
      }
      {
	    std::vector<Statement*> full1 = mc_pre1;
	    full1.push_back(sva_kill_reset_stmt_(
		  loc, inst, r_kill1, clear_domain1_kill()));
	    full1.insert(full1.end(), body1.begin(), body1.end());
	    full1.insert(full1.end(), mc_post1.begin(), mc_post1.end());
	    c1->set_statement(sva_block_(loc, full1));
      }
      PProcess*p1 = pform_make_behavior(IVL_PR_ALWAYS, c1, nullptr);
      FILE_NAME(p1, loc);
      prop->clk_evt = nullptr;    /* consumed by the always block */

	/* c2 body: an obligation enters the pipe at the first c2 tick
	   that sees req != ack (NBA-latched req: strictly after the
	   c1 match). `due' preserves the full req-ack multiplicity when
	   several antecedent matches accumulated before this c2 edge.
	   Each stage checks its slot boolean at its tick; a false boolean
	   FAILS every obligation in that batch, and the final stage's true
	   boolean PASSES every obligation in that batch. */
      perm_string due = sva_make_reg_(loc, inst, "mcdue", 0, true);

	/* A cover has no failure verdict. Its action stays at the one c2
	   match site; assertions retain both action trees for the persistent
	   single-owner dispatchers built below. */
      if (cover) {
	    delete fail_stmt;
	    fail_stmt = nullptr;
      }

      Statement*coverstmt = nullptr;
      if (cover && pass_stmt) {
	    coverstmt = sva_cover_action_(loc, pass_stmt);
	    pass_stmt = nullptr;
      }

      std::vector<Statement*> body2;
	/* Per-tick failure count: every stage (mid-chain or final) that
	   sees its boolean false adds its obligation multiplicity; the
	   shared fail action executes that many times at the end of the
	   tick. gate(k) below is always a synthesizer-built count
	   expression (`due' or an age register),
	   so it can be rebuilt freely; each user boolean is consumed
	   exactly once. */
      perm_string ffail = sva_make_reg_(loc, inst, "mcbf", 0, true);
      perm_string req_snapshot = sva_make_reg_(
	    loc, inst, "mcrs", 0, true);
      perm_string epoch_snapshot = sva_make_reg_(
	    loc, inst, "mces", 0, true);
      auto clear_domain2_state = [&](PExpr*ack_value) -> Statement* {
	    std::vector<Statement*> clear;
	    clear.push_back(sva_assign_(loc, ack, ack_value));
	    clear.push_back(sva_assign_(loc, due, sva_num32_(loc, 0)));
	    clear.push_back(sva_assign_(loc, ffail, sva_num32_(loc, 0)));
	    for (size_t k = 1 ; k < Tw ; k += 1)
		  clear.push_back(sva_assign_(loc, tb[k], sva_num32_(loc, 0)));
	    return sva_block_(loc, clear);
      };

	/* Capture the handoff before Observed. A coincident ##1 source update
	   is an NBA and remains invisible; a ##0 source update is blocking and
	   is visible after the enclosing Inactive-region #0. The epoch is
	   captured with the count so a later lazy kill reset cannot discard a
	   request that was launched after `$asserton'. */
      body2.push_back(sva_assign_(loc, req_snapshot, sva_id_(loc, req)));
      body2.push_back(sva_assign_(loc, epoch_snapshot,
				 sva_id_(loc, req_epoch)));
	/* `due' must be captured before this wait: for ##1 it must not see a
	   coincident c1 NBA, while for ##0 the enclosing #0 has already made
	   the coincident blocking request visible. The verdict itself is then
	   computed in Observed, like every other concurrent assertion. */
      body2.push_back(sva_observed_wait_(loc));
      body2.push_back(sva_kill_reset_stmt_(
	    loc, inst, r_kill2,
	    clear_domain2_state(sva_num32_(loc, 0))));
      std::vector<Statement*> epoch_body;
      PEBinary*duex = new PEBinary(
	    '-', sva_id_(loc, req_snapshot), sva_id_(loc, ack));
      FILE_NAME(duex, loc);
      epoch_body.push_back(sva_assign_(loc, due, duex));
      epoch_body.push_back(sva_assign_(loc, ffail, sva_num32_(loc, 0)));
      epoch_body.push_back(sva_if_(loc, sva_id_(loc, due),
	    sva_assign_nb_(loc, ack, sva_id_(loc, req_snapshot)), nullptr));
      {
	    auto gate = [&](size_t k) -> PExpr* {
		  if (k == 0) return sva_id_(loc, due);
		  return sva_id_(loc, tb[k]);
	    };
	      /* A cover has no failure verdict. For an assertion, accumulate
		 the count instead of a boolean so coincident obligations do
		 not collapse to one action. */
	    auto raise_fail = [&](PExpr*count) -> Statement* {
		  if (cover) {
			delete count;
			return sva_assign_(loc, ffail, sva_id_(loc, ffail));
		  }
		  PEBinary*add = new PEBinary('+', sva_id_(loc, ffail), count);
		  FILE_NAME(add, loc);
		  return sva_assign_(loc, ffail, add);
	    };
	      /* Mid-chain stages: a wide blocking temp holds the number
		 that advances, so the user boolean is read once and only
		 when at least one obligation is live. failure = gate-advance. */
	    for (size_t k = 0 ; k + 1 < Tb ; k += 1) {
		  PExpr*fb = b_slots[k];   /* null = pure delay tick */
		  if (!fb) {
			PExpr*g = gate(k);
			epoch_body.push_back(sva_assign_nb_(loc, tb[k+1], g));
			continue;
		  }
		  perm_string adv = sva_make_reg_(loc, inst, "mcadv",
						  (unsigned)k, true);
		  epoch_body.push_back(sva_assign_(loc, adv, sva_num32_(loc, 0)));
		  epoch_body.push_back(sva_if_(loc, gate(k),
				sva_if_(loc, fb,
					sva_assign_(loc, adv, gate(k)), nullptr),
				nullptr));
		  epoch_body.push_back(sva_assign_nb_(loc, tb[k+1],
						 sva_id_(loc, adv)));
		  PEBinary*dead = new PEBinary('-', gate(k),
					       sva_id_(loc, adv));
		  FILE_NAME(dead, loc);
		  epoch_body.push_back(raise_fail(dead));
	    }
	      /* Final boolean. Without a window this is one tick: pass on a
		 true boolean, flag on false.

		 With a trailing `##[m:n]' the same boolean is offered at
		 ages Tb-1 .. Tb-1+b_window. It is evaluated ONCE per tick
		 into a blocking temp (the user expression must be read
		 once, and every age reads the same value at the same
		 tick), then each age is settled independently: a live age
		 whose boolean is true is discharged and does NOT propagate;
		 one whose boolean is false moves to the next age; the last
		 age fails. Because at most one obligation enters per tick,
		 an age slot identifies an obligation uniquely, so
		 discharging one cannot disturb another still in flight. */
	    {
		  PExpr*fb = b_slots[Tb - 1];
		  size_t last = Tw - 1;
		  if (b_window == 0) {
			Statement*hit;
			if (cover) {
			      PEBinary*add = new PEBinary('+',
					sva_id_(loc, r_cnt), gate(Tb - 1));
			      FILE_NAME(add, loc);
			      std::vector<Statement*> hitv;
			      hitv.push_back(sva_assign_(loc, r_cnt, add));
			      if (coverstmt) {
				    hitv.push_back(sva_repeat_(loc,
					  gate(Tb - 1), coverstmt));
				    coverstmt = nullptr;
			      }
			      hit = sva_block_(loc, hitv);
			} else {
			      PEBinary*add = new PEBinary(
				    '+', sva_id_(loc, pn_req), gate(Tb - 1));
			      FILE_NAME(add, loc);
			      hit = sva_assign_(loc, pn_req, add);
			}
			epoch_body.push_back(sva_if_(loc, gate(Tb - 1),
				sva_if_(loc, fb, hit,
					raise_fail(gate(Tb - 1))),
				nullptr));
		  } else {
			perm_string fbv = sva_make_reg_(loc, inst, "mcbv", 0);
			epoch_body.push_back(sva_assign_(loc, fbv,
					fb ? fb : sva_bit_(loc, 1)));

			  /* Propagate each unsatisfied live age forward. */
			for (size_t d = Tb - 1 ; d < last ; d += 1) {
			      PETernary*keep = new PETernary(
					sva_not_(loc, sva_id_(loc, fbv)),
					gate(d), sva_num32_(loc, 0));
			      FILE_NAME(keep, loc);
			      epoch_body.push_back(sva_assign_nb_(loc, tb[d+1],
							     keep));
			}

			  /* Discharge every live age whose boolean holds. */
			perm_string fpass = sva_make_reg_(loc, inst, "mcbp",
							  0, true);
			PExpr*sum = gate(Tb - 1);
			for (size_t d = Tb ; d <= last ; d += 1) {
			      PEBinary*ad = new PEBinary('+', sum, gate(d));
			      FILE_NAME(ad, loc);
			      sum = ad;
			}
			epoch_body.push_back(sva_assign_(loc, fpass,
						    sva_num32_(loc, 0)));
			epoch_body.push_back(sva_if_(loc, sva_id_(loc, fbv),
				sva_assign_(loc, fpass, sum), nullptr));
			if (cover) {
			      PEBinary*add = new PEBinary('+',
					sva_id_(loc, r_cnt),
					sva_id_(loc, fpass));
			      FILE_NAME(add, loc);
			      epoch_body.push_back(sva_assign_(loc, r_cnt, add));
			      if (coverstmt) {
				    epoch_body.push_back(sva_repeat_(loc,
					  sva_id_(loc, fpass), coverstmt));
				    coverstmt = nullptr;
			      }
			} else {
			      PEBinary*add = new PEBinary(
				    '+', sva_id_(loc, pn_req),
				    sva_id_(loc, fpass));
			      FILE_NAME(add, loc);
			      epoch_body.push_back(sva_if_(
				    loc, sva_id_(loc, fpass),
				    sva_assign_(loc, pn_req, add), nullptr));
			}

			  /* The last age with a false boolean is the only
			     way this consequent fails. */
			epoch_body.push_back(sva_if_(loc,
				sva_not_(loc, sva_id_(loc, fbv)),
				raise_fail(gate(last)), nullptr));
		  }
	    }
	    if (!cover) {
		  PEBinary*add = new PEBinary(
			'+', sva_id_(loc, fs_req), sva_id_(loc, ffail));
		  FILE_NAME(add, loc);
		  epoch_body.push_back(sva_if_(loc, sva_id_(loc, ffail),
			sva_assign_(loc, fs_req, add), nullptr));
	    }
      }
	/* A handoff from an older kill epoch is an already-killed attempt.
	   Leave ack at zero until the source publishes the current epoch; this
	   makes post-kill attempts independent of which clock domain runs first. */
      PEBComp*epoch_current = new PEBComp(
	    'E', sva_id_(loc, epoch_snapshot),
	    sva_kill_generation_expr_(loc, inst));
      FILE_NAME(epoch_current, loc);
      body2.push_back(sva_if_(loc, epoch_current,
	    sva_block_(loc, epoch_body), nullptr));

	/* disable iff: abort in the c2 domain -- swallow the outstanding
	   obligation (ack catches up to req) and clear the stages, so the
	   attempt neither passes nor fails. */
      if (dis2) {
	    std::vector<Statement*> gated2;
	    gated2.push_back(sva_if_(loc, dis2,
		  clear_domain2_state(sva_id_(loc, req)),
				     sva_block_(loc, body2)));
	    body2.swap(gated2);
      }
      std::vector<Statement*> full2 = mc_pre2;
      full2.insert(full2.end(), body2.begin(), body2.end());
      full2.insert(full2.end(), mc_post2.begin(), mc_post2.end());
      Statement*c2body = sva_block_(loc, full2);
      if (overlap_boundary) {
	    PDelayStatement*z = new PDelayStatement(
		  sva_num32_(loc, 0), c2body);
	    FILE_NAME(z, loc);
	    c2body = z;
      }
      c2->set_statement(c2body);
      PProcess*p2 = pform_make_behavior(IVL_PR_ALWAYS, c2, nullptr);
      FILE_NAME(p2, loc);
      prop->seq_clk_evt = nullptr;

	/* Each single-owner dispatcher snapshots and acknowledges the verdict
	   counters before entering Reactive. A conditional event wait also
	   catches requests that arrive while the dispatcher is draining an
	   earlier batch: unequal request/ack counters are consumed immediately
	   on the next forever-loop iteration, without waiting for an edge that
	   has already happened.

	   The user action itself runs in a detached child, once per verdict.
	   That is essential procedural semantics: one delayed or nonterminating
	   action must not serialize or suppress another assertion action. The
	   dispatcher and its children have permanent Reactive-region affinity,
	   so a #delay or @event continuation stays in the Reactive region set
	   rather than escaping back to Active. The leading #0 lets the shared
	   initialization process establish all counters before either
	   dispatcher examines them. */
      if (!cover) {
	      /* Pass dispatcher: nonvacuous successes report the VPI
		 callback; vacuous successes do not. Both execute the same
		 single-owned user statement in independent detached
		 Reactive processes. */
	    std::vector<PEEvent*> pev;
	    pev.push_back(new PEEvent(PEEvent::ANYEDGE,
				      sva_id_(loc, pv_req)));
	    pev.push_back(new PEEvent(PEEvent::ANYEDGE,
				      sva_id_(loc, pn_req)));
	    PEventStatement*pwait = new PEventStatement(pev);
	    FILE_NAME(pwait, loc);

	    PEBComp*pveq = new PEBComp(
		  'e', sva_id_(loc, pv_req), sva_id_(loc, pv_ack));
	    FILE_NAME(pveq, loc);
	    PEBComp*pneq = new PEBComp(
		  'e', sva_id_(loc, pn_req), sva_id_(loc, pn_ack));
	    FILE_NAME(pneq, loc);
	    PEBLogic*pidle = new PEBLogic('a', pveq, pneq);
	    FILE_NAME(pidle, loc);

	    std::vector<Statement*> ploop;
	    ploop.push_back(sva_if_(loc, pidle, pwait, nullptr));
	    PEBinary*pvd = new PEBinary(
		  '-', sva_id_(loc, pv_req), sva_id_(loc, pv_ack));
	    FILE_NAME(pvd, loc);
	    ploop.push_back(sva_assign_(loc, pv_due, pvd));
	    PEBinary*pnd = new PEBinary(
		  '-', sva_id_(loc, pn_req), sva_id_(loc, pn_ack));
	    FILE_NAME(pnd, loc);
	    ploop.push_back(sva_assign_(loc, pn_due, pnd));
	    ploop.push_back(sva_assign_(
		  loc, pv_ack, sva_id_(loc, pv_req)));
	    ploop.push_back(sva_assign_(
		  loc, pn_ack, sva_id_(loc, pn_req)));
	    ploop.push_back(sva_reactive_wait_(loc));

	      /* Report every nonvacuous success before starting any user
		 action. A delayed/nonreturning action therefore cannot delay
		 or lose the assertion callback. */
	    ploop.push_back(sva_repeat_(
		  loc, sva_id_(loc, pn_due),
		  sva_report_stmt_(loc, inst, SVA_CB_SUCCESS)));

	    if (have_pass_action) {
		  PBlock*spawn = new PBlock(PBlock::BL_JOIN_NONE);
		  FILE_NAME(spawn, loc);
		  std::vector<Statement*>one;
		  one.push_back(sva_gate_(loc, pass_stmt));
		  spawn->set_statement(one);
		  pass_stmt = nullptr;
		  PEBinary*ptotal = new PEBinary(
			'+', sva_id_(loc, pn_due), sva_id_(loc, pv_due));
		  FILE_NAME(ptotal, loc);
		  ploop.push_back(sva_repeat_(loc, ptotal, spawn));
	    }

	    PForever*pforever = new PForever(sva_block_(loc, ploop));
	    FILE_NAME(pforever, loc);
	    std::vector<Statement*>pstartv;
	    pstartv.push_back(sva_reactive_process_(loc));
	    pstartv.push_back(pforever);
	    PDelayStatement*pass_start = new PDelayStatement(
		  sva_num32_(loc, 0), sva_block_(loc, pstartv));
	    FILE_NAME(pass_start, loc);
	    PProcess*pd = pform_make_behavior(
		  IVL_PR_INITIAL, pass_start, nullptr);
	    FILE_NAME(pd, loc);

	      /* Failure dispatcher: prefix and suffix failures share one
		 default/user action and one callback path, so an arbitrary
		 action statement is never copied. */
	    std::vector<PEEvent*> fev;
	    fev.push_back(new PEEvent(PEEvent::ANYEDGE,
				      sva_id_(loc, fp_req)));
	    fev.push_back(new PEEvent(PEEvent::ANYEDGE,
				      sva_id_(loc, fs_req)));
	    PEventStatement*fwait = new PEventStatement(fev);
	    FILE_NAME(fwait, loc);

	    PEBComp*fpeq = new PEBComp(
		  'e', sva_id_(loc, fp_req), sva_id_(loc, fp_ack));
	    FILE_NAME(fpeq, loc);
	    PEBComp*fseq = new PEBComp(
		  'e', sva_id_(loc, fs_req), sva_id_(loc, fs_ack));
	    FILE_NAME(fseq, loc);
	    PEBLogic*fidle = new PEBLogic('a', fpeq, fseq);
	    FILE_NAME(fidle, loc);

	    std::vector<Statement*> floop;
	    floop.push_back(sva_if_(loc, fidle, fwait, nullptr));
	    PEBinary*fpd = new PEBinary(
		  '-', sva_id_(loc, fp_req), sva_id_(loc, fp_ack));
	    FILE_NAME(fpd, loc);
	    floop.push_back(sva_assign_(loc, fp_due, fpd));
	    PEBinary*fsd = new PEBinary(
		  '-', sva_id_(loc, fs_req), sva_id_(loc, fs_ack));
	    FILE_NAME(fsd, loc);
	    floop.push_back(sva_assign_(loc, fs_due, fsd));
	    floop.push_back(sva_assign_(
		  loc, fp_ack, sva_id_(loc, fp_req)));
	    floop.push_back(sva_assign_(
		  loc, fs_ack, sva_id_(loc, fs_req)));
	    floop.push_back(sva_reactive_wait_(loc));

	    Statement*action = fail_stmt;
	    if (!action) {
		  std::list<named_pexpr_t> no_args;
		  PCallTask*err = new PCallTask(
			lex_strings.make("$error"), no_args);
		  FILE_NAME(err, loc);
		  action = err;
	    }
	    fail_stmt = nullptr;
	    PEBinary*ftotal = new PEBinary(
		  '+', sva_id_(loc, fp_due), sva_id_(loc, fs_due));
	    FILE_NAME(ftotal, loc);

	      /* Like success, failure notification precedes user code. */
	    floop.push_back(sva_repeat_(
		  loc, sva_clone_expr_(ftotal),
		  sva_report_stmt_(loc, inst, SVA_CB_FAILURE)));

	    PBlock*spawn = new PBlock(PBlock::BL_JOIN_NONE);
	    FILE_NAME(spawn, loc);
	    std::vector<Statement*>one;
	    one.push_back(sva_gate_(loc, action));
	    spawn->set_statement(one);
	    floop.push_back(sva_repeat_(loc, ftotal, spawn));

	    PForever*fforever = new PForever(sva_block_(loc, floop));
	    FILE_NAME(fforever, loc);
	    std::vector<Statement*>fstartv;
	    fstartv.push_back(sva_reactive_process_(loc));
	    fstartv.push_back(fforever);
	    PDelayStatement*fstart = new PDelayStatement(
		  sva_num32_(loc, 0), sva_block_(loc, fstartv));
	    FILE_NAME(fstart, loc);
	    PProcess*fd = pform_make_behavior(
		  IVL_PR_INITIAL, fstart, nullptr);
	    FILE_NAME(fd, loc);
      }

      delete fail_stmt;
      delete pass_stmt;
      pform_sva_destroy_property(prop);
}

/* M9-7 residual (IEEE 1800-2017 16.13.1): an N-domain (N>=3) multiclock
   sequence/property chain, e.g.
     @(c1) a ##1 @(c2) b ##1 @(c3) c
   Generalizes the 2-domain request/ack handoff above
   (`pform_make_multiclock_assertion_') to a chain of
   M = 1 + prop->mc_more->size() clock-flow segments PAST domain 0:
   domain 0 (c1) keeps its EXISTING antecedent/prefix bit-flag pipeline
   completely unchanged -- a plain sequence or an implication still
   starts exactly one attempt per c1 tick, so a 1-bit-per-age pipeline
   stays exact there. Every later domain (1..M) receives an incoming
   obligation COUNT from the domain before it (an age slot IS an
   obligation count, the same reasoning the 2-domain consequent already
   relies on: at most one batch enters a domain's own pipeline per its
   own tick) and runs its OWN local fixed chain as a counting pipeline,
   identical in shape to the 2-domain consequent's. Every domain but the
   last (1..M-1) forwards its local match COUNT to the next domain's
   request counter -- using THAT boundary's own ##0/##1 discipline --
   instead of a user pass action, and reports its own local-chain
   failures (mid-chain or final-mismatch) on its own private fail
   channel; every channel merges into the SAME shared fail dispatcher
   the 2-domain lowering already builds, so a fail anywhere in the
   chain runs the user's fail action exactly once per failing attempt,
   at that attempt's own tick -- "mid-chain failures fail at their own
   tick" generalized to however many dominos are in the chain. Only the
   LAST domain (M) computes a real pass verdict / cover count -- the
   existing final-domain logic, unchanged in shape.

   Excluded (loud sorry, not silently narrowed): `disable iff' composed
   with more than one clock-flow change (the single-boundary lowering
   above keeps supporting it), and a variable-length window anywhere but
   the LAST segment (already excluded there too). */
static void pform_make_multiclock_chain_assertion_(const struct vlltype&loc,
						   sva_property_t*prop,
						   Statement*fail_stmt,
						   Statement*pass_stmt, int kind)
{
      PEventStatement*c1 = prop->clk_evt;
      const char*why = nullptr;
      bool cover = (kind == 2);
      bool plain = (prop->op_type == 0);

      size_t M = 1 + prop->mc_more->size();

      if (prop->op_type < 0 || prop->op_type > 2)
	    why = "this multiclocked property operator";
      else if (!c1)
	    why = "a multiclocked property with no explicit antecedent clock";
      else if (prop->mc_boundary != 0 && prop->mc_boundary != 1)
	    why = "a multiclocked sequence whose clock-flow boundary is "
		  "not ##0 or ##1";
      else if (!prop->seq || prop->seq->empty())
	    why = "a multiclocked property with an empty clock-flow segment";
      else if (plain && (!prop->mc_prefix || prop->mc_prefix->empty()))
	    why = "a multiclocked sequence with an empty first-clock prefix";
      else if (!plain && (!prop->antecedent || prop->antecedent->empty()))
	    why = "a multiclocked implication with an empty antecedent";
      else if (prop->disable_iff_expr)
	    why = "`disable iff' composed with more than one clock-flow "
		  "change in the same sequence (IEEE 1800-2017 16.13.1); "
		  "the single clock-flow-boundary form supports "
		  "`disable iff'";

      for (size_t i = 0 ; !why && i < prop->mc_more->size() ; i += 1) {
	    const sva_mc_seg_t&seg = (*prop->mc_more)[i];
	    if (seg.boundary != 0 && seg.boundary != 1)
		  why = "a multiclocked sequence whose clock-flow boundary "
			"is not ##0 or ##1";
	    else if (!seg.clk_evt)
		  why = "a multiclocked sequence segment with no clocking "
			"event";
	    else if (!seg.chain || seg.chain->empty())
		  why = "a multiclocked sequence with an empty clock-flow "
			"segment";
      }

	/* Domain 0: antecedent + mc_prefix, spliced/expanded exactly as
	   the 2-domain lowering does. */
      std::vector<PExpr*> a_slots, p_slots;
      if (!why) {
	    if (prop->antecedent)
		  sva_splice_sequences_(loc, *prop->antecedent);
	    if (prop->mc_prefix)
		  sva_splice_sequences_(loc, *prop->mc_prefix);
	    if (prop->antecedent
		&& !sva_mc_expand_chain_(*prop->antecedent, a_slots))
		  why = "a multiclocked implication whose ANTECEDENT is not "
			"a fixed-length boolean chain (constant ##N delays "
			"only; a variable-length antecedent creates one "
			"obligation per match, which the request counter "
			"cannot distinguish)";
	    else if (prop->mc_prefix
		     && !sva_mc_expand_chain_(*prop->mc_prefix, p_slots))
		  why = "a multiclocked sequence whose first-clock prefix "
			"is not a fixed-length boolean chain (constant "
			"##N delays only)";
	    else if (a_slots.size() > 64 || p_slots.size() > 64)
		  why = "a multiclocked property with a chain over "
			"64 ticks";
      }

	/* Domains 1..M: chain[1] is prop->seq, chain[d>1] is
	   mc_more[d-2].chain. Only the LAST domain may carry a trailing
	   variable-length window. */
      std::vector<std::vector<PExpr*> > slots(M + 1);
      std::vector<PEventStatement*> dom_clk(M + 1, nullptr);
      std::vector<int> in_boundary(M + 1, -1);  /* boundary BEFORE domain d */
      long b_window = 0;
      if (!why) {
	    dom_clk[1] = prop->seq_clk_evt;
	    in_boundary[1] = prop->mc_boundary;
	    for (size_t d = 2 ; d <= M ; d += 1) {
		  const sva_mc_seg_t&seg = (*prop->mc_more)[d - 2];
		  dom_clk[d] = seg.clk_evt;
		  in_boundary[d] = seg.boundary;
	    }
      }
      for (size_t d = 1 ; !why && d <= M ; d += 1) {
	    std::vector<sva_seq_step_t>*chain =
		  (d == 1) ? prop->seq : (*prop->mc_more)[d - 2].chain;
	    sva_splice_sequences_(loc, *chain);
	    bool last = (d == M);
	    bool ok = last ? sva_mc_expand_chain_(*chain, slots[d], &b_window)
			   : sva_mc_expand_chain_(*chain, slots[d]);
	    if (!ok) {
		  why = last
			? "a multiclocked property's final clock-flow "
			  "segment is neither a fixed-length boolean chain "
			  "nor one with a single trailing bounded window "
			  "(`##[m:n] b', `b[*m:n]')"
			: "a multiclocked sequence whose clock-flow segment "
			  "is not a fixed-length boolean chain (constant "
			  "##N delays only)";
	    } else if (slots[d].size() + (last ? (size_t)b_window : 0) > 64) {
		  why = "a multiclocked property with a chain over 64 ticks";
	    }
      }

      if (why) {
	    cerr << loc << ": sorry: " << why << " is not supported "
		 << "(IEEE 1800-2017 16.13); the assertion is dropped."
		 << endl;
	    error_count += 1;
	    delete fail_stmt; delete pass_stmt;
	    pform_sva_destroy_property(prop);
	    return;
      }

      unsigned inst = sva_gensym_counter++;
      auto dreg = [&](const char*base, size_t d, unsigned idx,
		      bool wide = true) -> perm_string {
	    char buf[48];
	    snprintf(buf, sizeof buf, "%s%zu_", base, d);
	    return sva_make_reg_(loc, inst, buf, idx, wide);
      };

	/* req_in[d]/ack[d]/due[d]: the counter handoff INTO domain d.
	   req_in[1] is bumped by domain 0's existing pipeline below;
	   req_in[2..M] is bumped by domain 1..M-1's own local match. */
      std::vector<perm_string> req_in(M + 1), ack(M + 1), due(M + 1);
      std::vector<perm_string> req_epoch(M + 1), req_snapshot(M + 1),
	    epoch_snapshot(M + 1);
      for (size_t d = 1 ; d <= M ; d += 1) {
	    req_in[d] = dreg("mcreq", d, 0);
	    ack[d]    = dreg("mcack", d, 0);
	    due[d]    = dreg("mcdue", d, 0);
	    req_epoch[d] = dreg("mcrep", d, 0);
	    req_snapshot[d] = dreg("mcrs", d, 0);
	    epoch_snapshot[d] = dreg("mces", d, 0);
      }

      bool have_pass_action = pass_stmt != nullptr;
      perm_string pv_req, pn_req, pv_ack, pn_ack, pv_due, pn_due;
      perm_string fp_req, fp_ack, fp_due;   /* domain 0's own prefix channel */
      std::vector<perm_string> ffreq(M + 1), ffack(M + 1), ffdue(M + 1);
      if (!cover) {
	    pv_req = sva_make_reg_(loc, inst, "mcpvrq", 0, true);
	    pn_req = sva_make_reg_(loc, inst, "mcpnrq", 0, true);
	    pv_ack = sva_make_reg_(loc, inst, "mcpvak", 0, true);
	    pn_ack = sva_make_reg_(loc, inst, "mcpnak", 0, true);
	    pv_due = sva_make_reg_(loc, inst, "mcpvdu", 0, true);
	    pn_due = sva_make_reg_(loc, inst, "mcpndu", 0, true);
	    if (p_slots.size()) {
		  fp_req = sva_make_reg_(loc, inst, "mcfprq", 0, true);
		  fp_ack = sva_make_reg_(loc, inst, "mcfpak", 0, true);
		  fp_due = sva_make_reg_(loc, inst, "mcfpdu", 0, true);
	    }
	    for (size_t d = 1 ; d <= M ; d += 1) {
		  ffreq[d] = dreg("mcffrq", d, 0);
		  ffack[d] = dreg("mcffak", d, 0);
		  ffdue[d] = dreg("mcffdu", d, 0);
	    }
      }

      perm_string r_cnt;
      if (cover) r_cnt = sva_make_reg_(loc, inst, "cnt", 0, true);

      Statement*coverstmt = nullptr;
      if (cover) {
	    delete fail_stmt;
	    fail_stmt = nullptr;
	    if (pass_stmt) {
		  coverstmt = sva_cover_action_(loc, pass_stmt);
		  pass_stmt = nullptr;
	    }
      }

	/* Steal the slot booleans from their steps. */
      if (prop->antecedent)
	    for (size_t j = 0 ; j < prop->antecedent->size() ; j += 1)
		  (*prop->antecedent)[j].expr = nullptr;
      if (prop->mc_prefix)
	    for (size_t j = 0 ; j < prop->mc_prefix->size() ; j += 1)
		  (*prop->mc_prefix)[j].expr = nullptr;
      for (size_t d = 1 ; d <= M ; d += 1) {
	    std::vector<sva_seq_step_t>*chain =
		  (d == 1) ? prop->seq : (*prop->mc_more)[d - 2].chain;
	    for (size_t j = 0 ; j < chain->size() ; j += 1)
		  (*chain)[j].expr = nullptr;
      }

      size_t Ta = a_slots.size();
      size_t Tp = p_slots.size();

      std::map<std::string, pform_name_t> prep_sampled;
      unsigned prep_live_operands = 0;
      auto sample_slots = [&](std::vector<PExpr*>&s) {
	    for (size_t k = 0 ; k < s.size() ; k += 1) {
		  if (!s[k]) continue;
		  PExpr*prep = sva_wrap_preponed_(
			s[k], prep_sampled, prep_live_operands);
		  if (!prep) continue;
		  delete s[k];
		  s[k] = prep;
	    }
      };
      sample_slots(a_slots);
      sample_slots(p_slots);
      for (size_t d = 1 ; d <= M ; d += 1) sample_slots(slots[d]);

      unsigned mc_hist_idx = 0;
      std::vector<Statement*> mc_pre0, mc_post0, mc_init0;
      std::vector<std::vector<Statement*> > mc_pre(M + 1), mc_post(M + 1),
	    mc_init(M + 1);
      auto bind_sampled = [&](std::vector<PExpr*>&s,
			      std::vector<Statement*>&pre,
			      std::vector<Statement*>&post,
			      std::vector<Statement*>&init) {
	    for (size_t k = 0 ; k < s.size() ; k += 1) {
		  if (!s[k]) continue;
		  PExpr*bound = sva_rewrite_sampled_(
			loc, s[k], inst, mc_hist_idx, pre, post, init);
		  if (bound && bound != s[k]) s[k] = bound;
	    }
      };
      bind_sampled(a_slots, mc_pre0, mc_post0, mc_init0);
      bind_sampled(p_slots, mc_pre0, mc_post0, mc_init0);
      for (size_t d = 1 ; d <= M ; d += 1)
	    bind_sampled(slots[d], mc_pre[d], mc_post[d], mc_init[d]);

	/* ---- domain 0 (c1): antecedent + mc_prefix pipeline, same shape
	   as the 2-domain lowering, but its match bumps req_in[1]. ---- */
      std::vector<perm_string> pa(Ta), pp(Tp);
      for (size_t k = 1 ; k < Ta ; k += 1)
	    pa[k] = sva_make_reg_(loc, inst, "mca", (unsigned)k);
      for (size_t k = 1 ; k < Tp ; k += 1)
	    pp[k] = sva_make_reg_(loc, inst, "mcp", (unsigned)k);
      perm_string pstart;
      if (!plain && Tp && prop->op_type == 2)
	    pstart = sva_make_reg_(loc, inst, "mcps", 0);

      std::vector<size_t> Tb(M + 1), Tw(M + 1);
      std::vector<std::vector<perm_string> > tb(M + 1);
      for (size_t d = 1 ; d <= M ; d += 1) {
	    Tb[d] = slots[d].size();
	    Tw[d] = Tb[d] + ((d == M) ? (size_t)b_window : 0);
	    tb[d].resize(Tw[d]);
	    for (size_t k = 1 ; k < Tw[d] ; k += 1)
		  tb[d][k] = dreg("mcb", d, (unsigned)k);
      }

      std::vector<Statement*> initv;
      for (size_t d = 1 ; d <= M ; d += 1) {
	    initv.push_back(sva_assign_(loc, req_in[d], sva_num32_(loc, 0)));
	    initv.push_back(sva_assign_(loc, ack[d], sva_num32_(loc, 0)));
	    initv.push_back(sva_assign_(loc, req_epoch[d],
				      sva_num32_(loc, 0)));
      }
      if (!cover) {
	    initv.push_back(sva_assign_(loc, pv_req, sva_num32_(loc, 0)));
	    initv.push_back(sva_assign_(loc, pn_req, sva_num32_(loc, 0)));
	    initv.push_back(sva_assign_(loc, pv_ack, sva_num32_(loc, 0)));
	    initv.push_back(sva_assign_(loc, pn_ack, sva_num32_(loc, 0)));
	    initv.push_back(sva_assign_(loc, pv_due, sva_num32_(loc, 0)));
	    initv.push_back(sva_assign_(loc, pn_due, sva_num32_(loc, 0)));
	    if (Tp) {
		  initv.push_back(sva_assign_(loc, fp_req, sva_num32_(loc, 0)));
		  initv.push_back(sva_assign_(loc, fp_ack, sva_num32_(loc, 0)));
		  initv.push_back(sva_assign_(loc, fp_due, sva_num32_(loc, 0)));
	    }
	    for (size_t d = 1 ; d <= M ; d += 1) {
		  initv.push_back(sva_assign_(loc, ffreq[d], sva_num32_(loc, 0)));
		  initv.push_back(sva_assign_(loc, ffack[d], sva_num32_(loc, 0)));
		  initv.push_back(sva_assign_(loc, ffdue[d], sva_num32_(loc, 0)));
	    }
      }
      for (size_t k = 1 ; k < Ta ; k += 1)
	    initv.push_back(sva_assign_(loc, pa[k], sva_bit_(loc, 0)));
      for (size_t k = 1 ; k < Tp ; k += 1)
	    initv.push_back(sva_assign_(loc, pp[k], sva_bit_(loc, 0)));
      if (pstart != perm_string())
	    initv.push_back(sva_assign_(loc, pstart, sva_bit_(loc, 0)));
      for (size_t d = 1 ; d <= M ; d += 1)
	    for (size_t k = 1 ; k < Tw[d] ; k += 1)
		  initv.push_back(sva_assign_(loc, tb[d][k], sva_num32_(loc, 0)));

      initv.insert(initv.end(), mc_init0.begin(), mc_init0.end());
      for (size_t d = 1 ; d <= M ; d += 1)
	    initv.insert(initv.end(), mc_init[d].begin(), mc_init[d].end());
      if (cover)
	    initv.push_back(sva_assign_(loc, r_cnt,
			new PENumber(new verinum((uint64_t)0, 32))));
      std::vector<perm_string> r_kill(M + 1);
      for (size_t d = 0 ; d <= M ; d += 1)
	    r_kill[d] = sva_kill_seen_reg_(loc, inst, (unsigned)d, initv);
      for (std::map<std::string, pform_name_t>::const_iterator it =
		prep_sampled.begin() ; it != prep_sampled.end() ; ++it)
	    initv.push_back(sva_hist_on_stmt_(loc, it->second));
      if (prep_live_operands > 0)
	    cerr << loc << ": warning: this multiclocked assertion has "
		 << prep_live_operands << " operand(s) that are read live "
		 << "instead of sampled in the Preponed region (IEEE "
		 << "1800-2017 16.5.1); a blocking write in the same time "
		 << "slot as any of its clocks can be visible to the "
		 << "assertion." << endl;
      initv.push_back(sva_register_stmt_(loc, inst));
      PProcess*ip = pform_make_behavior(IVL_PR_INITIAL,
					sva_block_(loc, initv), nullptr);
      FILE_NAME(ip, loc);

	/* ---- domain 0 body: identical shape to the 2-domain lowering's
	   c1 body, bumping req_in[1] with boundary in_boundary[1]. ---- */
      bool overlap0 = (in_boundary[1] == 0);
      std::vector<Statement*> body0;
      {
	    auto ante_gate = [&](size_t k) -> PExpr* {
		  return (k == 0) ? sva_bit_(loc, 1) : (PExpr*)sva_id_(loc, pa[k]);
	    };
	    perm_string vcount;
	    if (!plain && !cover && have_pass_action) {
		  vcount = sva_make_reg_(loc, inst, "mcva", 0, true);
		  body0.push_back(sva_assign_(loc, vcount, sva_num32_(loc, 0)));
	    }
	    PExpr*ante_match = nullptr;
	    if (!plain) {
		  for (size_t k = 0 ; k < Ta ; k += 1) {
			PExpr*advance;
			if (a_slots[k]) {
			      perm_string adv = sva_make_reg_(
					loc, inst, "mcaadv", (unsigned)k);
			      PEBinary*advx = new PEBLogic('a', ante_gate(k),
							   a_slots[k]);
			      FILE_NAME(advx, loc);
			      body0.push_back(sva_assign_(loc, adv, advx));
			      advance = sva_id_(loc, adv);
			      if (!cover && have_pass_action) {
				    PEBinary*dead = new PEBLogic(
					      'a', ante_gate(k),
					      sva_not_(loc, sva_id_(loc, adv)));
				    FILE_NAME(dead, loc);
				    PEBinary*add = new PEBinary(
					      '+', sva_id_(loc, vcount), dead);
				    FILE_NAME(add, loc);
				    body0.push_back(
					      sva_assign_(loc, vcount, add));
			      }
			} else {
			      advance = ante_gate(k);
			}
			if (k + 1 < Ta)
			      body0.push_back(sva_assign_nb_(
					loc, pa[k+1], advance));
			else
			      ante_match = advance;
		  }
	    }

	    PExpr*match = ante_match;
	    perm_string fcount;
	    if (Tp) {
		  if (!cover) {
			fcount = sva_make_reg_(loc, inst, "mcpf", 0, true);
			body0.push_back(sva_assign_(loc, fcount,
						   sva_num32_(loc, 0)));
		  }

		  PExpr*prefix_start;
		  if (plain) {
			prefix_start = sva_bit_(loc, 1);
		  } else if (prop->op_type == 1) {
			prefix_start = ante_match;
			ante_match = nullptr;
		  } else {
			body0.push_back(sva_assign_nb_(loc, pstart,
						     ante_match));
			ante_match = nullptr;
			prefix_start = sva_id_(loc, pstart);
		  }

		  auto pgate = [&](size_t k) -> PExpr* {
			if (k != 0) return sva_id_(loc, pp[k]);
			return sva_clone_expr_(prefix_start);
		  };

		  match = nullptr;
		  for (size_t k = 0 ; k < Tp ; k += 1) {
			PExpr*advance;
			if (p_slots[k]) {
			      perm_string adv = sva_make_reg_(
					loc, inst, "mcpadv", (unsigned)k);
			      PEBinary*advx = new PEBLogic('a', pgate(k),
							   p_slots[k]);
			      FILE_NAME(advx, loc);
			      body0.push_back(sva_assign_(loc, adv, advx));
			      advance = sva_id_(loc, adv);
			      if (!cover) {
				    PEBinary*dead = new PEBLogic(
					      'a', pgate(k),
					      sva_not_(loc, sva_id_(loc, adv)));
				    FILE_NAME(dead, loc);
				    PEBinary*add = new PEBinary(
					      '+', sva_id_(loc, fcount), dead);
				    FILE_NAME(add, loc);
				    body0.push_back(
					      sva_assign_(loc, fcount, add));
			      }
			} else {
			      advance = pgate(k);
			}
			if (k + 1 < Tp)
			      body0.push_back(sva_assign_nb_(
					loc, pp[k+1], advance));
			else
			      match = advance;
		  }
		  delete prefix_start;
	    }

	    PExpr*inc = new PEBinary('+', sva_id_(loc, req_in[1]), sva_num32_(loc, 1));
	    FILE_NAME(inc, loc);
	    Statement*bump = overlap0
		  ? sva_assign_(loc, req_in[1], inc)
		  : sva_assign_nb_(loc, req_in[1], inc);
	    body0.push_back(sva_if_(loc, match, bump, nullptr));
	    if (!plain && !cover && have_pass_action) {
		  PEBinary*add = new PEBinary(
			'+', sva_id_(loc, pv_req), sva_id_(loc, vcount));
		  FILE_NAME(add, loc);
		  body0.push_back(sva_if_(loc, sva_id_(loc, vcount),
				sva_assign_(loc, pv_req, add), nullptr));
	    }
	    if (Tp && !cover) {
		  PEBinary*add = new PEBinary(
			'+', sva_id_(loc, fp_req), sva_id_(loc, fcount));
		  FILE_NAME(add, loc);
		  body0.push_back(sva_if_(loc, sva_id_(loc, fcount),
				sva_assign_(loc, fp_req, add), nullptr));
	    }
      }
      auto clear_domain0_state = [&]() -> Statement* {
	    std::vector<Statement*> clear;
	    for (size_t k = 1 ; k < Ta ; k += 1)
		  clear.push_back(sva_assign_(loc, pa[k], sva_bit_(loc, 0)));
	    for (size_t k = 1 ; k < Tp ; k += 1)
		  clear.push_back(sva_assign_(loc, pp[k], sva_bit_(loc, 0)));
	    if (pstart != perm_string())
		  clear.push_back(sva_assign_(loc, pstart, sva_bit_(loc, 0)));
	    if (clear.empty())
		  clear.push_back(sva_assign_(loc, req_in[1],
					      sva_id_(loc, req_in[1])));
	    return sva_block_(loc, clear);
      };
      auto clear_domain0_kill = [&]() -> Statement* {
	    std::vector<Statement*> clear;
	    clear.push_back(clear_domain0_state());
	    clear.push_back(sva_assign_(loc, req_in[1], sva_num32_(loc, 0)));
	    clear.push_back(sva_assign_(
		  loc, req_epoch[1], sva_kill_generation_expr_(loc, inst)));
	    return sva_block_(loc, clear);
      };
      {
	    std::vector<Statement*> full0 = mc_pre0;
	    full0.push_back(sva_kill_reset_stmt_(
		  loc, inst, r_kill[0], clear_domain0_kill()));
	    full0.insert(full0.end(), body0.begin(), body0.end());
	    full0.insert(full0.end(), mc_post0.begin(), mc_post0.end());
	    c1->set_statement(sva_block_(loc, full0));
      }
      PProcess*p0 = pform_make_behavior(IVL_PR_ALWAYS, c1, nullptr);
      FILE_NAME(p0, loc);
      prop->clk_evt = nullptr;

	/* ---- domains 1..M: each a counting pipeline over its own local
	   chain, gated by its own incoming due[d]. Every domain but the
	   last forwards its match count to req_in[d+1] (using THAT
	   boundary's ##0/##1 discipline) and its own fail count to
	   ffreq[d]; the LAST domain (M) computes the real verdict exactly
	   like the 2-domain lowering's consequent. ---- */
      for (size_t d = 1 ; d <= M ; d += 1) {
	    bool last = (d == M);
	    bool overlap_in = (in_boundary[d] == 0);
	    std::vector<Statement*> bodyd;

	    perm_string ffail = dreg("mcbf", d, 0);
	    auto clear_domaind = [&]() -> Statement* {
		  std::vector<Statement*> clear;
		  clear.push_back(sva_assign_(loc, ack[d],
						sva_num32_(loc, 0)));
		  clear.push_back(sva_assign_(loc, due[d],
						sva_num32_(loc, 0)));
		  clear.push_back(sva_assign_(loc, ffail,
						sva_num32_(loc, 0)));
		  for (size_t k = 1 ; k < Tw[d] ; k += 1)
			clear.push_back(sva_assign_(loc, tb[d][k],
						   sva_num32_(loc, 0)));
		  if (!last) {
			clear.push_back(sva_assign_(loc, req_in[d+1],
						   sva_num32_(loc, 0)));
			clear.push_back(sva_assign_(
			      loc, req_epoch[d+1],
			      sva_kill_generation_expr_(loc, inst)));
		  }
		  return sva_block_(loc, clear);
	    };
	    {
		  auto gate = [&](size_t k) -> PExpr* {
			if (k == 0) return sva_id_(loc, due[d]);
			return sva_id_(loc, tb[d][k]);
		  };
		  auto raise_fail = [&](PExpr*count) -> Statement* {
			if (cover) {
			      delete count;
			      return sva_assign_(loc, ffail, sva_id_(loc, ffail));
			}
			PEBinary*add = new PEBinary('+', sva_id_(loc, ffail), count);
			FILE_NAME(add, loc);
			return sva_assign_(loc, ffail, add);
		  };
		  for (size_t k = 0 ; k + 1 < Tb[d] ; k += 1) {
			PExpr*fb = slots[d][k];
			if (!fb) {
			      PExpr*g = gate(k);
			      bodyd.push_back(sva_assign_nb_(loc, tb[d][k+1], g));
			      continue;
			}
			perm_string adv = dreg("mcadv", d, (unsigned)k);
			bodyd.push_back(sva_assign_(loc, adv, sva_num32_(loc, 0)));
			bodyd.push_back(sva_if_(loc, gate(k),
			      sva_if_(loc, fb,
				      sva_assign_(loc, adv, gate(k)), nullptr),
			      nullptr));
			bodyd.push_back(sva_assign_nb_(loc, tb[d][k+1],
						       sva_id_(loc, adv)));
			PEBinary*dead = new PEBinary('-', gate(k), sva_id_(loc, adv));
			FILE_NAME(dead, loc);
			bodyd.push_back(raise_fail(dead));
		  }

		  PExpr*fb = slots[d][Tb[d] - 1];
		  size_t lastage = Tw[d] - 1;
		  bool has_window = last && (b_window != 0);
		  if (!has_window) {
			Statement*hit;
			if (last) {
			      if (cover) {
				    PEBinary*add = new PEBinary('+',
					      sva_id_(loc, r_cnt), gate(Tb[d] - 1));
				    FILE_NAME(add, loc);
				    std::vector<Statement*> hitv;
				    hitv.push_back(sva_assign_(loc, r_cnt, add));
				    if (coverstmt) {
					  hitv.push_back(sva_repeat_(loc,
						gate(Tb[d] - 1), coverstmt));
					  coverstmt = nullptr;
				    }
				    hit = sva_block_(loc, hitv);
			      } else {
				    PEBinary*add = new PEBinary(
					  '+', sva_id_(loc, pn_req), gate(Tb[d] - 1));
				    FILE_NAME(add, loc);
				    hit = sva_assign_(loc, pn_req, add);
			      }
			} else {
			      PEBinary*fwd = new PEBinary(
				    '+', sva_id_(loc, req_in[d+1]), gate(Tb[d] - 1));
			      FILE_NAME(fwd, loc);
			      bool overlap_out = (in_boundary[d+1] == 0);
			      hit = overlap_out
				    ? sva_assign_(loc, req_in[d+1], fwd)
				    : sva_assign_nb_(loc, req_in[d+1], fwd);
			}
			bodyd.push_back(sva_if_(loc, gate(Tb[d] - 1),
				sva_if_(loc, fb, hit,
					raise_fail(gate(Tb[d] - 1))),
				nullptr));
		  } else {
			perm_string fbv = dreg("mcbv", d, 0, false);
			bodyd.push_back(sva_assign_(loc, fbv,
					fb ? fb : sva_bit_(loc, 1)));

			for (size_t age = Tb[d] - 1 ; age < lastage ; age += 1) {
			      PETernary*keep = new PETernary(
					sva_not_(loc, sva_id_(loc, fbv)),
					gate(age), sva_num32_(loc, 0));
			      FILE_NAME(keep, loc);
			      bodyd.push_back(sva_assign_nb_(loc, tb[d][age+1],
							     keep));
			}

			perm_string fpass = dreg("mcbp", d, 0);
			PExpr*sum = gate(Tb[d] - 1);
			for (size_t age = Tb[d] ; age <= lastage ; age += 1) {
			      PEBinary*ad = new PEBinary('+', sum, gate(age));
			      FILE_NAME(ad, loc);
			      sum = ad;
			}
			bodyd.push_back(sva_assign_(loc, fpass,
						    sva_num32_(loc, 0)));
			bodyd.push_back(sva_if_(loc, sva_id_(loc, fbv),
				sva_assign_(loc, fpass, sum), nullptr));
			if (cover) {
			      PEBinary*add = new PEBinary('+',
					sva_id_(loc, r_cnt),
					sva_id_(loc, fpass));
			      FILE_NAME(add, loc);
			      bodyd.push_back(sva_assign_(loc, r_cnt, add));
			      if (coverstmt) {
				    bodyd.push_back(sva_repeat_(loc,
					  sva_id_(loc, fpass), coverstmt));
				    coverstmt = nullptr;
			      }
			} else {
			      PEBinary*add = new PEBinary(
				    '+', sva_id_(loc, pn_req),
				    sva_id_(loc, fpass));
			      FILE_NAME(add, loc);
			      bodyd.push_back(sva_if_(
				    loc, sva_id_(loc, fpass),
				    sva_assign_(loc, pn_req, add), nullptr));
			}

			bodyd.push_back(sva_if_(loc,
				sva_not_(loc, sva_id_(loc, fbv)),
				raise_fail(gate(lastage)), nullptr));
		  }
	    }
	    if (!cover) {
		  PEBinary*add = new PEBinary(
			'+', sva_id_(loc, ffreq[d]), sva_id_(loc, ffail));
		  FILE_NAME(add, loc);
		  bodyd.push_back(sva_if_(loc, sva_id_(loc, ffail),
			sva_assign_(loc, ffreq[d], add), nullptr));
	    }

	    /* Snapshot the handoff before Observed to retain the ##0/##1
	       boundary. Process it after the lazy domain reset only when its
	       epoch is current; an intermediate domain also reset its outgoing
	       epoch above, so downstream clocks cannot confuse old and new
	       attempts. */
	    std::vector<Statement*> epoch_body;
	    PEBinary*duex = new PEBinary(
		  '-', sva_id_(loc, req_snapshot[d]), sva_id_(loc, ack[d]));
	    FILE_NAME(duex, loc);
	    epoch_body.push_back(sva_assign_(loc, due[d], duex));
	    epoch_body.push_back(sva_assign_(loc, ffail,
					   sva_num32_(loc, 0)));
	    epoch_body.push_back(sva_if_(loc, sva_id_(loc, due[d]),
		  sva_assign_nb_(loc, ack[d], sva_id_(loc, req_snapshot[d])),
		  nullptr));
	    epoch_body.insert(epoch_body.end(), bodyd.begin(), bodyd.end());
	    bodyd.clear();
	    bodyd.push_back(sva_assign_(loc, req_snapshot[d],
					  sva_id_(loc, req_in[d])));
	    bodyd.push_back(sva_assign_(loc, epoch_snapshot[d],
					  sva_id_(loc, req_epoch[d])));
	    bodyd.push_back(sva_observed_wait_(loc));
	    bodyd.push_back(sva_kill_reset_stmt_(
		  loc, inst, r_kill[d], clear_domaind()));
	    PEBComp*epoch_current = new PEBComp(
		  'E', sva_id_(loc, epoch_snapshot[d]),
		  sva_kill_generation_expr_(loc, inst));
	    FILE_NAME(epoch_current, loc);
	    bodyd.push_back(sva_if_(loc, epoch_current,
		  sva_block_(loc, epoch_body), nullptr));

	    std::vector<Statement*> fulld = mc_pre[d];
	    fulld.insert(fulld.end(), bodyd.begin(), bodyd.end());
	    fulld.insert(fulld.end(), mc_post[d].begin(), mc_post[d].end());
	    Statement*bodyblk = sva_block_(loc, fulld);
	    if (overlap_in) {
		  PDelayStatement*z = new PDelayStatement(
			sva_num32_(loc, 0), bodyblk);
		  FILE_NAME(z, loc);
		  bodyblk = z;
	    }
	    dom_clk[d]->set_statement(bodyblk);
	    PProcess*pd = pform_make_behavior(IVL_PR_ALWAYS, dom_clk[d], nullptr);
	    FILE_NAME(pd, loc);
      }
      prop->seq_clk_evt = nullptr;
      for (size_t i = 0 ; i < prop->mc_more->size() ; i += 1)
	    (*prop->mc_more)[i].clk_evt = nullptr;

	/* ---- shared dispatchers: pass (fed only by domain M) and fail
	   (fed by domain 0's optional prefix channel plus every domain
	   1..M's own channel). Same single-owner Reactive-region shape as
	   the 2-domain lowering, generalized to loop over channels. ---- */
      if (!cover) {
	    std::vector<PEEvent*> pev;
	    pev.push_back(new PEEvent(PEEvent::ANYEDGE, sva_id_(loc, pv_req)));
	    pev.push_back(new PEEvent(PEEvent::ANYEDGE, sva_id_(loc, pn_req)));
	    PEventStatement*pwait = new PEventStatement(pev);
	    FILE_NAME(pwait, loc);

	    PEBComp*pveq = new PEBComp('e', sva_id_(loc, pv_req), sva_id_(loc, pv_ack));
	    FILE_NAME(pveq, loc);
	    PEBComp*pneq = new PEBComp('e', sva_id_(loc, pn_req), sva_id_(loc, pn_ack));
	    FILE_NAME(pneq, loc);
	    PEBLogic*pidle = new PEBLogic('a', pveq, pneq);
	    FILE_NAME(pidle, loc);

	    std::vector<Statement*> ploop;
	    ploop.push_back(sva_if_(loc, pidle, pwait, nullptr));
	    PEBinary*pvd = new PEBinary('-', sva_id_(loc, pv_req), sva_id_(loc, pv_ack));
	    FILE_NAME(pvd, loc);
	    ploop.push_back(sva_assign_(loc, pv_due, pvd));
	    PEBinary*pnd = new PEBinary('-', sva_id_(loc, pn_req), sva_id_(loc, pn_ack));
	    FILE_NAME(pnd, loc);
	    ploop.push_back(sva_assign_(loc, pn_due, pnd));
	    ploop.push_back(sva_assign_(loc, pv_ack, sva_id_(loc, pv_req)));
	    ploop.push_back(sva_assign_(loc, pn_ack, sva_id_(loc, pn_req)));
	    ploop.push_back(sva_reactive_wait_(loc));

	    ploop.push_back(sva_repeat_(
		  loc, sva_id_(loc, pn_due),
		  sva_report_stmt_(loc, inst, SVA_CB_SUCCESS)));

	    if (have_pass_action) {
		  PBlock*spawn = new PBlock(PBlock::BL_JOIN_NONE);
		  FILE_NAME(spawn, loc);
		  std::vector<Statement*>one;
		  one.push_back(sva_gate_(loc, pass_stmt));
		  spawn->set_statement(one);
		  pass_stmt = nullptr;
		  PEBinary*ptotal = new PEBinary(
			'+', sva_id_(loc, pn_due), sva_id_(loc, pv_due));
		  FILE_NAME(ptotal, loc);
		  ploop.push_back(sva_repeat_(loc, ptotal, spawn));
	    }

	    PForever*pforever = new PForever(sva_block_(loc, ploop));
	    FILE_NAME(pforever, loc);
	    std::vector<Statement*>pstartv;
	    pstartv.push_back(sva_reactive_process_(loc));
	    pstartv.push_back(pforever);
	    PDelayStatement*pass_start = new PDelayStatement(
		  sva_num32_(loc, 0), sva_block_(loc, pstartv));
	    FILE_NAME(pass_start, loc);
	    PProcess*pd2 = pform_make_behavior(
		  IVL_PR_INITIAL, pass_start, nullptr);
	    FILE_NAME(pd2, loc);

	      /* Fail channels: domain 0's optional prefix, then domains
		 1..M's own. All merge into one dispatcher/one user action. */
	    std::vector<perm_string> chreq, chack, chdue;
	    if (Tp) { chreq.push_back(fp_req); chack.push_back(fp_ack); chdue.push_back(fp_due); }
	    for (size_t d = 1 ; d <= M ; d += 1) {
		  chreq.push_back(ffreq[d]); chack.push_back(ffack[d]); chdue.push_back(ffdue[d]);
	    }

	    std::vector<PEEvent*> fev;
	    for (size_t c = 0 ; c < chreq.size() ; c += 1)
		  fev.push_back(new PEEvent(PEEvent::ANYEDGE, sva_id_(loc, chreq[c])));
	    PEventStatement*fwait = new PEventStatement(fev);
	    FILE_NAME(fwait, loc);

	    PExpr*fidle = nullptr;
	    for (size_t c = 0 ; c < chreq.size() ; c += 1) {
		  PEBComp*eq = new PEBComp('e', sva_id_(loc, chreq[c]), sva_id_(loc, chack[c]));
		  FILE_NAME(eq, loc);
		  if (!fidle) { fidle = eq; continue; }
		  PEBLogic*both = new PEBLogic('a', fidle, eq);
		  FILE_NAME(both, loc);
		  fidle = both;
	    }

	    std::vector<Statement*> floop;
	    floop.push_back(sva_if_(loc, fidle, fwait, nullptr));
	    PExpr*ftotal = nullptr;
	    for (size_t c = 0 ; c < chreq.size() ; c += 1) {
		  PEBinary*d1 = new PEBinary('-', sva_id_(loc, chreq[c]), sva_id_(loc, chack[c]));
		  FILE_NAME(d1, loc);
		  floop.push_back(sva_assign_(loc, chdue[c], d1));
		  floop.push_back(sva_assign_(loc, chack[c], sva_id_(loc, chreq[c])));
		  PEIdent*dv = sva_id_(loc, chdue[c]);
		  if (!ftotal) { ftotal = dv; continue; }
		  PEBinary*sum = new PEBinary('+', ftotal, dv);
		  FILE_NAME(sum, loc);
		  ftotal = sum;
	    }
	    floop.push_back(sva_reactive_wait_(loc));

	    Statement*action = fail_stmt;
	    if (!action) {
		  std::list<named_pexpr_t> no_args;
		  PCallTask*err = new PCallTask(
			lex_strings.make("$error"), no_args);
		  FILE_NAME(err, loc);
		  action = err;
	    }
	    fail_stmt = nullptr;

	    floop.push_back(sva_repeat_(
		  loc, sva_clone_expr_(ftotal),
		  sva_report_stmt_(loc, inst, SVA_CB_FAILURE)));

	    PBlock*spawn = new PBlock(PBlock::BL_JOIN_NONE);
	    FILE_NAME(spawn, loc);
	    std::vector<Statement*>one;
	    one.push_back(sva_gate_(loc, action));
	    spawn->set_statement(one);
	    floop.push_back(sva_repeat_(loc, ftotal, spawn));

	    PForever*fforever = new PForever(sva_block_(loc, floop));
	    FILE_NAME(fforever, loc);
	    std::vector<Statement*>fstartv;
	    fstartv.push_back(sva_reactive_process_(loc));
	    fstartv.push_back(fforever);
	    PDelayStatement*fstart = new PDelayStatement(
		  sva_num32_(loc, 0), sva_block_(loc, fstartv));
	    FILE_NAME(fstart, loc);
	    PProcess*fd = pform_make_behavior(
		  IVL_PR_INITIAL, fstart, nullptr);
	    FILE_NAME(fd, loc);
      }

      delete fail_stmt;
      delete pass_stmt;
      pform_sva_destroy_property(prop);
}


/* Build a fresh procedural wait `@(<clk events>)' cloning the clocking
   event of an `expect'/property so it can be reused at each tick. */
static PEventStatement* sva_clone_wait_(const struct vlltype&loc,
					PEventStatement*clk)
{
      const std::vector<PEEvent*>&evs = clk->event_expressions();
      std::vector<PEEvent*> ne;
      for (size_t i = 0 ; i < evs.size() ; i += 1) {
	    PExpr*ce = sva_clone_expr_(evs[i]->expr());
	    PExpr*condition = evs[i]->condition()
		  ? sva_clone_expr_(evs[i]->condition()) : nullptr;
	    PEEvent*pe = new PEEvent(evs[i]->type(), ce, condition);
	    ne.push_back(pe);
      }
      PEventStatement*w = new PEventStatement(ne);
      FILE_NAME(w, loc);
      return w;
}

/* M9-frontier (Phase 3): `expect (property) pass; else fail;' (IEEE
   1800-2017 16.17). Unlike `assert property' (a standing concurrent
   checker), `expect' is a PROCEDURAL statement: the executing process
   blocks at the expect until a SINGLE attempt of the property, starting
   now, completes — then the pass action runs on a match and the else
   action on a failure, and the process continues.
 *
 * For a fixed-length boolean sequence `@(clk) e0 ##d1 e1 ##d2 e2 ...' the
 * single attempt is exactly a run of procedural clock-waits and boolean
 * checks, so it lowers with no new runtime (the process blocks on the
 * ordinary `@(clk)' event controls):
 *
 *     begin
 *       m = 1'b1;
 *       @(clk);            if (!e0) m = 1'b0;         // first tick
 *       if (m) begin repeat(d1) @(clk); if (!e1) m = 1'b0; end
 *       if (m) begin repeat(d2) @(clk); if (!e2) m = 1'b0; end
 *       ...
 *       if (m) <pass> else <else>;
 *     end
 *
 * The `if (m)' guards stop waiting once a term has failed, so the else
 * runs at the failing tick (not after further waits). Variable-length,
 * unbounded, repetition, goto, local-variable, first_match, implication,
 * multiclock, or a missing clock is a loud sorry (they need the standing
 * checker plus a process-resume hook — a later increment). A `##0'-fused
 * mid-chain term is also deferred. Reentrancy caveat: the match flag is a
 * module-scope reg, so an `expect' re-entered concurrently (the same
 * statement in two live invocations of an automatic scope) shares it;
 * the common non-reentrant use (a test sequence) is unaffected.
 */
Statement* pform_make_expect(const struct vlltype&loc, sva_property_t*prop,
			     Statement*pass_stmt, Statement*else_stmt)
{
      const char*why = nullptr;
      bool have_tree = prop && prop->tree;
      if (!prop || (!have_tree && (!prop->seq || prop->seq->empty())))
	    why = "an empty `expect' property";
      else if (prop->op_type != 0 || prop->antecedent
	       || prop->seq_clk_evt || prop->strength != 0)
	    why = "an `expect' that is not a plain sequence property "
		  "(implication, strong/weak, negation, or multiclock)";
      else if (!prop->clk_evt)
	    why = "an `expect' with no explicit clocking event";
      else if (prop->disable_iff_expr)
	    why = "`disable iff' on an `expect'";

	/* Fast path: a fixed `##N' boolean chain is exactly a run of
	   clock-waits + checks (no automaton needed). */
      bool fast = false;
      if (!why && !have_tree) {
	    fast = true;
	    std::vector<sva_seq_step_t>&s = *prop->seq;
	    for (size_t j = 0 ; j < s.size() ; j += 1) {
		  if (s[j].delay_lo != s[j].delay_hi || s[j].delay_lo < 0
		      || s[j].rep_tail || s[j].rep_kind || s[j].lv_rhs
		      || s[j].fm) {
			fast = false;
			break;
		  }
		  if (j == 0 && s[j].delay_lo != 0) { fast = false; break; }
		  if (j > 0 && s[j].delay_lo < 1) { fast = false; break; }
	    }
      }

	/* M9-11: every other sequence shape (windows, repetition,
	   goto, first_match, unbounded waits, or/and/intersect trees)
	   rides the automaton engine — the blocking process itself
	   drives a SINGLE inline attempt: one 1-bit state register per
	   automaton state, advanced once per clock tick; first accept
	   is the match, an empty next-state set is the failure. */
      sva_nfa_t xnfa;
      std::vector< std::vector<sva_seq_step_t>* > xleaves;
      if (!why && !fast) {
	    if (!pform_sva_nfa_enabled())
		  why = "this `expect' sequence shape under the legacy "
			"SVA engine (unset IVL_SVA_LEGACY to use the "
			"automaton engine)";
      }
      if (!why && !fast) {
	    if (have_tree) {
		  sva_tree_leaves_(prop->tree, xleaves);
		  for (size_t i = 0 ; i < xleaves.size() ; i += 1)
			sva_splice_sequences_(loc, *xleaves[i]);
	    } else {
		  sva_splice_sequences_(loc, *prop->seq);
		  xleaves.push_back(prop->seq);
	    }
	    bool has_lv = false;
	    for (size_t i = 0 ; i < xleaves.size() ; i += 1)
		  for (size_t sj = 0 ; sj < xleaves[i]->size() ; sj += 1)
			if ((*xleaves[i])[sj].lv_rhs) has_lv = true;
	    if (has_lv)
		  why = "a sequence local variable in an `expect'";
	    else {
		  bool built = have_tree
			? pform_sva_nfa_build_from_tree(xnfa, prop->tree)
			: pform_sva_nfa_build_from_chain(xnfa, *prop->seq);
		  if (!built)
			why = "this sequence shape in an `expect' (the "
			      "automaton construction does not cover it)";
		  else if (xnfa.nstates > 128)
			why = "an `expect' automaton over 128 states";
		  else {
			  /* An unreachable accept (an intersect of
			     incompatible lengths) could never match:
			     diagnose instead of blocking forever. */
			std::vector<bool> seen (xnfa.nstates, false);
			std::vector<unsigned> q;
			seen[xnfa.start] = true;
			q.push_back(xnfa.start);
			for (size_t h = 0 ; h < q.size() ; h += 1)
			      for (size_t i = 0 ; i < xnfa.edges.size() ; i += 1) {
				    const sva_nfa_edge_t&ed = xnfa.edges[i];
				    if (ed.from != q[h] || seen[ed.to]) continue;
				    seen[ed.to] = true;
				    q.push_back(ed.to);
			      }
			if (!seen[xnfa.accept])
			      why = "an `expect' whose property can never "
				    "match (unreachable accept state)";
		  }
	    }
      }
      if (why) {
	    cerr << loc << ": sorry: " << why << " is not supported "
		 << "(IEEE 1800-2017 16.17); the expect is dropped." << endl;
	    error_count += 1;
	    delete pass_stmt;
	    delete else_stmt;
	    pform_sva_destroy_property(prop);
	    std::vector<Statement*> empty;
	    return sva_block_(loc, empty);
      }

      PEventStatement*clk = prop->clk_evt;
      unsigned inst = sva_gensym_counter++;

      if (fast) {
	    std::vector<sva_seq_step_t>&s = *prop->seq;
	    perm_string m = sva_make_reg_(loc, inst, "em", 0);   // 1-bit match flag

	    std::vector<Statement*> body;
	    body.push_back(sva_assign_(loc, m, sva_bit_(loc, 1)));

	      /* First term: wait the first tick, then check e0. */
	    body.push_back(sva_clone_wait_(loc, clk));
	    PExpr*e0 = s[0].expr; s[0].expr = nullptr;
	    body.push_back(sva_if_(loc, sva_not_(loc, e0),
				   sva_assign_(loc, m, sva_bit_(loc, 0)), nullptr));

	      /* Subsequent terms, each guarded by the running match flag. */
	    for (size_t j = 1 ; j < s.size() ; j += 1) {
		  long dj = s[j].delay_lo;
		  PExpr*ej = s[j].expr; s[j].expr = nullptr;
		  std::vector<Statement*> inner;
		  if (dj == 1) {
			inner.push_back(sva_clone_wait_(loc, clk));
		  } else {
			PENumber*cnt = new PENumber(new verinum((uint64_t)dj, 32));
			FILE_NAME(cnt, loc);
			PRepeat*rep = new PRepeat(cnt, sva_clone_wait_(loc, clk));
			FILE_NAME(rep, loc);
			inner.push_back(rep);
		  }
		  inner.push_back(sva_if_(loc, sva_not_(loc, ej),
					  sva_assign_(loc, m, sva_bit_(loc, 0)),
					  nullptr));
		  body.push_back(sva_if_(loc, sva_id_(loc, m),
					 sva_block_(loc, inner), nullptr));
	    }

	      /* Terminal dispatch: pass on a match, else on a failure. */
	    body.push_back(sva_if_(loc, sva_id_(loc, m), pass_stmt, else_stmt));

	      /* The clock was cloned per wait; the original is now free. */
	    delete prop->clk_evt;
	    delete prop->seq;      // step exprs stolen (nulled) above
	    delete prop;

	    return sva_block_(loc, body);
      }

	/* ---- M9-11: inline single-attempt automaton driver ----
	 * st_i / nx_i are 1-bit current/next state registers. Each
	 * distinct edge-guard expression (guards are BORROWED pointers
	 * shared across edges) is sampled once per tick into its own
	 * register, then every tick edge whose source state is live
	 * and whose sampled guards hold sets its destination. First
	 * accept = match; an empty next set = failure. An unbounded
	 * wait (`##[1:$]') that never resolves blocks forever, which
	 * is the specified behavior of a weak unbounded sequence. */
      unsigned N = xnfa.nstates;

      std::map<PExpr*, unsigned> gidx;
      std::vector<PExpr*> glist;
      for (size_t i = 0 ; i < xnfa.edges.size() ; i += 1)
	    for (size_t g = 0 ; g < xnfa.edges[i].guards.size() ; g += 1) {
		  PExpr*ge = xnfa.edges[i].guards[g];
		  if (!gidx.count(ge)) {
			gidx[ge] = (unsigned)glist.size();
			glist.push_back(ge);
		  }
	    }

      std::vector<perm_string> st_r (N), nx_r (N);
      for (unsigned i = 0 ; i < N ; i += 1) {
	    st_r[i] = sva_make_reg_(loc, inst, "xs", i);
	    nx_r[i] = sva_make_reg_(loc, inst, "xn", i);
      }
      std::vector<perm_string> g_r (glist.size());
      for (unsigned k = 0 ; k < glist.size() ; k += 1)
	    g_r[k] = sva_make_reg_(loc, inst, "xg", k);
      perm_string done_r = sva_make_reg_(loc, inst, "xd", 0);
      perm_string ok_r = sva_make_reg_(loc, inst, "xo", 0);

      std::vector<Statement*> body;
      for (unsigned i = 0 ; i < N ; i += 1)
	    body.push_back(sva_assign_(loc, st_r[i],
				       sva_bit_(loc, i == xnfa.start ? 1 : 0)));
      body.push_back(sva_assign_(loc, done_r, sva_bit_(loc, 0)));
      body.push_back(sva_assign_(loc, ok_r, sva_bit_(loc, 0)));

      std::vector<Statement*> tick;
      tick.push_back(sva_clone_wait_(loc, clk));
	/* Sample each distinct guard once (steals the expression). */
      for (unsigned k = 0 ; k < glist.size() ; k += 1)
	    tick.push_back(sva_assign_(loc, g_r[k], glist[k]));
      for (unsigned i = 0 ; i < N ; i += 1)
	    tick.push_back(sva_assign_(loc, nx_r[i], sva_bit_(loc, 0)));
      for (size_t i = 0 ; i < xnfa.edges.size() ; i += 1) {
	    const sva_nfa_edge_t&ed = xnfa.edges[i];
	    PExpr*cond = sva_id_(loc, st_r[ed.from]);
	    for (size_t g = 0 ; g < ed.guards.size() ; g += 1) {
		  PEBinary*bb = new PEBLogic('a', cond,
					     sva_id_(loc, g_r[gidx[ed.guards[g]]]));
		  FILE_NAME(bb, loc);
		  cond = bb;
	    }
	    tick.push_back(sva_if_(loc, cond,
				   sva_assign_(loc, nx_r[ed.to], sva_bit_(loc, 1)),
				   nullptr));
      }
      std::vector<Statement*> matched;
      matched.push_back(sva_assign_(loc, ok_r, sva_bit_(loc, 1)));
      matched.push_back(sva_assign_(loc, done_r, sva_bit_(loc, 1)));
      std::vector<Statement*> advance;
      for (unsigned i = 0 ; i < N ; i += 1)
	    advance.push_back(sva_assign_(loc, st_r[i], sva_id_(loc, nx_r[i])));
      PExpr*alive = nullptr;
      for (unsigned i = 0 ; i < N ; i += 1) {
	    PExpr*bit = sva_id_(loc, nx_r[i]);
	    if (!alive) { alive = bit; continue; }
	    PEBinary*bb = new PEBLogic('o', alive, bit);
	    FILE_NAME(bb, loc);
	    alive = bb;
      }
      advance.push_back(sva_if_(loc, sva_not_(loc, alive),
				sva_assign_(loc, done_r, sva_bit_(loc, 1)),
				nullptr));
      tick.push_back(sva_if_(loc, sva_id_(loc, nx_r[xnfa.accept]),
			     sva_block_(loc, matched),
			     sva_block_(loc, advance)));

      PWhile*loop = new PWhile(sva_not_(loc, sva_id_(loc, done_r)),
			       sva_block_(loc, tick));
      FILE_NAME(loop, loc);
      body.push_back(loop);
      body.push_back(sva_if_(loc, sva_id_(loc, ok_r), pass_stmt, else_stmt));

	/* Null the stolen guard expressions at their sources so the
	   deletes below cannot double-free them. */
      for (size_t i = 0 ; i < xleaves.size() ; i += 1)
	    for (size_t sj = 0 ; sj < xleaves[i]->size() ; sj += 1)
		  if ((*xleaves[i])[sj].expr
		      && gidx.count((*xleaves[i])[sj].expr))
			(*xleaves[i])[sj].expr = nullptr;

      delete prop->clk_evt;
      if (have_tree)
	    sva_tree_delete_(prop->tree, true);
      else
	    delete prop->seq;
      delete prop;

      return sva_block_(loc, body);
}

/*
 * M9-10: implicit clock inference for a PROCEDURAL concurrent assertion
 * (IEEE 1800-2017 16.14.6).
 *
 * An assertion written inside a procedural block need not name a clock:
 *
 *     always @(posedge clk) assert property (a |-> b);
 *
 * The inferred clocking event is the one controlling the enclosing
 * procedural block. That used to be a hard error -- correct per the clause
 * as a diagnostic, but the clause also says the clock should be inferred,
 * so the construct was simply unusable.
 *
 * The parser cannot supply it at assertion time: bison reduces the assert
 * before the statement it sits in. But `event_control' in
 * `event_control statement_or_null' reduces BEFORE its statement, so by the
 * time that rule's action runs, the assertion has been reduced and the
 * controlling event already exists. So the clock-less assertion is parked
 * here, and parse.y hands it the event from that rule -- no grammar change,
 * so the conflict baseline is untouched.
 *
 * The innermost enclosing event control wins, which is what 16.14.6 wants:
 * a nested `@(negedge clk)' inside `always @(posedge clk)' drains the
 * pending assertion first and supplies negedge.
 *
 * Anything still parked when the module ends had no enclosing event control
 * at all (`initial assert property (a |-> b);'), and gets the original
 * error.
 */
struct sva_pending_proc_t {
      struct vlltype loc;
      sva_property_t*prop;
      Statement*fail_stmt;
      Statement*pass_stmt;
      int kind;
      perm_string label;
};
static std::vector<sva_pending_proc_t> sva_pending_proc_;

/* Bison reduces concurrent_assertion_statement before its enclosing item can
   attach block_identifier_opt. The grammar stages that label before parsing
   the statement; this active scope keeps it across recursive named-property
   lowering and lets procedural clock inference retain it. */
static perm_string sva_parser_assertion_label_;
static unsigned sva_assertion_label_depth_ = 0;

void pform_sva_set_assertion_label(const char*label)
{
      sva_parser_assertion_label_ = label ? lex_strings.make(label)
					 : perm_string();
}

void pform_sva_clear_assertion_label(void)
{
      sva_parser_assertion_label_ = perm_string();
}

class sva_assertion_label_scope_t {
    public:
      explicit sva_assertion_label_scope_t(perm_string label)
      : outer_(sva_active_assertion_label_)
      {
	    if (sva_assertion_label_depth_ == 0)
		  sva_active_assertion_label_ = label.nil()
			? sva_parser_assertion_label_ : label;
	    sva_assertion_label_depth_ += 1;
      }

      ~sva_assertion_label_scope_t()
      {
	    assert(sva_assertion_label_depth_ > 0);
	    sva_assertion_label_depth_ -= 1;
	    sva_active_assertion_label_ = outer_;
      }

    private:
      perm_string outer_;
};

static PEventStatement* sva_clone_event_control_(const PEventStatement*src,
						 const struct vlltype&loc,
			 const std::map<perm_string,PExpr*>*subst)
{
      if (!src) return nullptr;
      const std::vector<PEEvent*>&evs = src->event_expressions();
      if (evs.empty()) return nullptr;

	/* The enclosing always block owns its own event control, and the
	   synthesizer takes ownership of whatever it is given, so clone. */
      std::vector<PEEvent*> copy;
      for (size_t idx = 0 ; idx < evs.size() ; idx += 1) {
	    if (!evs[idx]) continue;
	    PExpr*sub = sva_clone_subst_(evs[idx]->expr(), subst);
	    if (!sub) {
		  for (size_t k = 0 ; k < copy.size() ; k += 1) delete copy[k];
		  return nullptr;
	    }
	    PExpr*condition = evs[idx]->condition()
		  ? sva_clone_subst_(evs[idx]->condition(), subst) : nullptr;
	    if (evs[idx]->condition() && !condition) {
		  delete sub;
		  for (size_t k = 0 ; k < copy.size() ; k += 1) delete copy[k];
		  return nullptr;
	    }
	    PEEvent*ev = new PEEvent(evs[idx]->type(), sub, condition);
	    FILE_NAME(ev, loc);
	    copy.push_back(ev);
      }
      if (copy.empty()) return nullptr;

      PEventStatement*out = new PEventStatement(copy);
      FILE_NAME(out, loc);
      return out;
}

/* True when `ctl' textually encloses an assertion parked at `loc'.
 *
 * The parser walks the source in order, so an event control that encloses
 * the assertion was necessarily opened on an earlier (or the same) line of
 * the same file. A *sibling* event control that merely follows the parked
 * assertion -- the `initial assert property(p); always @(posedge clk) ...'
 * shape -- starts later and is rejected here, so it cannot adopt an
 * assertion it does not contain. Nested controls sort out naturally: the
 * inner `event_control statement_or_null' reduces first, and an assertion
 * that appears above the inner `@' is left for the outer one.
 *
 * If the two ended up in different files (a mid-block `include'), we refuse
 * rather than guess: the assertion stays parked and the module end reports
 * it, because inferring a clock the user did not write would be a silently
 * wrong assertion.
 */
static bool sva_ctl_encloses_(const PEventStatement*ctl,
			      const struct vlltype&loc)
{
      if (ctl->get_file() != filename_strings.make(loc.text)) return false;
      return ctl->get_lineno() <= (unsigned)loc.first_line;
}

/* Called from parse.y for `event_control statement_or_null'. */
void pform_sva_infer_procedural_clock(PEventStatement*ctl)
{
      if (sva_pending_proc_.empty() || !ctl) return;

      std::vector<sva_pending_proc_t> take;
      std::vector<sva_pending_proc_t> keep;
      for (size_t idx = 0 ; idx < sva_pending_proc_.size() ; idx += 1) {
	    if (sva_ctl_encloses_(ctl, sva_pending_proc_[idx].loc))
		  take.push_back(sva_pending_proc_[idx]);
	    else
		  keep.push_back(sva_pending_proc_[idx]);
      }
      sva_pending_proc_.swap(keep);
      if (take.empty()) return;

      for (size_t idx = 0 ; idx < take.size() ; idx += 1) {
	    sva_pending_proc_t&p = take[idx];
	    PEventStatement*clk = sva_clone_event_control_(ctl, p.loc);
	    if (!clk) {
		  cerr << p.loc << ": sorry: this procedural assertion's "
		       << "enclosing event control has a shape the implicit "
		       << "clock inference cannot copy (IEEE 1800-2017 "
		       << "16.14.6); give the assertion an explicit clock."
		       << endl;
		  error_count += 1;
		  delete p.fail_stmt;
		  delete p.pass_stmt;
		  pform_sva_destroy_property(p.prop);
		  continue;
	    }
	    p.prop->clk_evt = clk;
	    pform_make_assertion(p.loc, p.prop, p.fail_stmt, p.pass_stmt,
			 p.kind, p.label);
      }
}

/* Called at end of module: anything left never had an enclosing event
   control, so it is the plain 16.14.6 error. */
void pform_sva_flush_pending_procedural(void)
{
      for (size_t idx = 0 ; idx < sva_pending_proc_.size() ; idx += 1) {
	    sva_pending_proc_t&p = sva_pending_proc_[idx];
	    cerr << p.loc << ": error: concurrent assertion has no clocking "
		 << "event, no enclosing procedural event control to infer "
		 << "one from, and no default clocking block is declared "
		 << "(IEEE 1800-2017 16.14.6)." << endl;
	    error_count += 1;
	    delete p.fail_stmt;
	    delete p.pass_stmt;
	    pform_sva_destroy_property(p.prop);
      }
      sva_pending_proc_.clear();
}

/* A concurrent assertion synthesizes its own clocked always block plus the
 * state variables that block needs, and it does so at the point the
 * assertion is parsed. When the assertion sits in procedural code --
 * `always @(posedge clk) begin assert property (...); end', which is
 * ordinary SystemVerilog -- that point has lexical_scope set to the
 * enclosing begin/end PBlock.
 *
 * Nothing elaborates a PBlock's `behaviors' list (only PScope::
 * elaborate_behaviors_ for modules and PGenerate::elaborate for generate
 * blocks walk it), and the seq_block rule `delete's an unnamed block whose
 * scope holds no declarations outright. Either way the synthesized always
 * block and its variables were dropped WITH NO DIAGNOSTIC: the assertion
 * registered itself, reported nothing, and passed forever.
 *
 * So run the whole lowering against the nearest enclosing non-block scope.
 * At module or generate scope -- every non-procedural assertion, and every
 * assertion re-driven by pform_sva_infer_procedural_clock, which runs after
 * the block has already been reduced -- this is a no-op.
 */

/* True when this property is nothing but a reference to a property or
 * sequence declared in this scope -- `assert property (p);'.
 *
 * Such a reference has no clk_evt of its own, but the DECLARATION may carry
 * one (`property p; @(posedge clk) a |=> b; endproperty'), and it is only
 * substituted further down in pform_make_assertion, which then re-enters
 * with the declaration's own sva_property_t. So the park decision cannot be
 * made here: parking a reference would hide the declaration's clock and
 * report a spurious 16.14.6 error (this is what broke sv_checker_basic).
 * Skip it and let the re-entry decide -- a declaration that really has no
 * clock parks on the second pass and gets the enclosing event exactly as a
 * literal property would.
 *
 * The name is looked up without regard to the expansion's consume-once
 * flag: an already-consumed name will not expand, and parking it would
 * treat the property name as an ordinary boolean signal -- silently wrong,
 * where falling through is the pre-existing loud error.
 */
static bool sva_prop_is_named_ref_(const sva_property_t*prop)
{
      if (prop->op_type != 0 || prop->seq_clk_evt || prop->mc_prefix
	  || prop->mc_boundary != -1
	  || !prop->seq || prop->seq->size() != 1)
	    return false;
      PExpr*e = (*prop->seq)[0].expr;
      if (PEIdent*id = dynamic_cast<PEIdent*>(e)) {
	    if (id->path().package || id->path().name.size() != 1
		|| !id->path().name.front().index.empty())
		  return false;
	    perm_string nm = id->path().name.front().name;
	    return sva_in_scope_(sva_module_properties, nm)
		|| sva_in_scope_(sva_module_sequences, nm);
      }
      if (PECallFunction*cf = dynamic_cast<PECallFunction*>(e)) {
	    if (cf->path().package || cf->path().name.size() != 1)
		  return false;
	    perm_string nm = peek_tail_name(cf->path().name);
	    return sva_in_scope_(sva_param_properties, nm)
		|| sva_in_scope_(sva_param_sequences, nm);
      }
      return false;
}

/* Everything the instance-sized parameter checker must duplicate before it
   takes ownership of a property.  Keeping these objects outside the commit
   section makes a declined probe transactional: the original clock,
   disable expression, sequences, and action statements remain untouched. */
struct sva_parameter_preflight_t {
      PEventStatement*clk;
      bool owns_clk;
      PExpr*disable_level;
      PExpr*disable_event;
      PExpr*invalid_bounds;
      LexicalScope*guard_owner;

      sva_parameter_preflight_t()
      : clk(nullptr), owns_clk(false), disable_level(nullptr),
	disable_event(nullptr), invalid_bounds(nullptr), guard_owner(nullptr) { }
};

static void sva_parameter_preflight_discard_(
				sva_parameter_preflight_t&prep)
{
      if (prep.owns_clk) delete prep.clk;
      delete prep.disable_level;
      delete prep.disable_event;
      delete prep.invalid_bounds;
      prep.clk = nullptr;
      prep.owns_clk = false;
      prep.disable_level = nullptr;
      prep.disable_event = nullptr;
      prep.invalid_bounds = nullptr;
      prep.guard_owner = nullptr;
}

/* A parameter-bound predicate must be true as a 4-state expression, not just
   nonzero after a lossy native conversion.  `comparison !== 1'b1' rejects a
   negative value as well as X/Z.  The unsized zero is signed, so a negative
   signed parameter is not first converted to a large unsigned value. */
static PExpr* sva_parameter_bad_nonnegative_(
				const struct vlltype&loc, PExpr*source)
{
      PExpr*value = sva_clone_expr_(source);
      if (!value) return nullptr;
      PENumber*zero = new PENumber(new verinum((int64_t)0));
      FILE_NAME(zero, loc);
      PEBComp*valid = new PEBComp('G', value, zero);
      FILE_NAME(valid, loc);
      PEBComp*bad = new PEBComp('N', valid, sva_bit_(loc, 1));
      FILE_NAME(bad, loc);
      return bad;
}

static PExpr* sva_parameter_bad_order_(const struct vlltype&loc,
				       PExpr*hi_source, PExpr*lo_source)
{
      PExpr*hi = sva_clone_expr_(hi_source);
      PExpr*lo = sva_clone_expr_(lo_source);
      if (!hi || !lo) {
	    delete hi;
	    delete lo;
	    return nullptr;
      }
      PEBComp*valid = new PEBComp('G', hi, lo);
      FILE_NAME(valid, loc);
      PEBComp*bad = new PEBComp('N', valid, sva_bit_(loc, 1));
      FILE_NAME(bad, loc);
      return bad;
}

/* Attach a per-instance elaboration guard without consuming the user's
   genblk numbering or mutating the parser's generate-stack state.  A selected
   `$fatal' is an elaboration task, so every target rejects the invalid
   instance before simulation and reports its generated scope path. */
static void sva_parameter_add_bound_guard_(const struct vlltype&loc,
					   unsigned inst,
					   LexicalScope*owner,
					   PExpr*invalid)
{
      ivl_assert(loc, owner);
      ivl_assert(loc, invalid);
      PGenerate*gen = new PGenerate(owner, inst);
      FILE_NAME(gen, loc);
      gen->scheme_type = PGenerate::GS_CONDIT;
      gen->directly_nested = false;
      gen->loop_test = invalid;

      char scope_buf[64];
      snprintf(scope_buf, sizeof scope_buf,
	       "_ivl_sva%u_bound_invalid", inst);
      gen->scope_name = lex_strings.make(scope_buf);

      std::list<named_pexpr_t> fatal_args;
      named_pexpr_t code;
      code.parm = new PENumber(new verinum((int64_t)1));
      FILE_NAME(code.parm, loc);
      fatal_args.push_back(code);
      named_pexpr_t message;
      message.parm = new PEString(strdup(
	    "invalid parameter-valued SVA bound after instance override; "
	    "bounds must be known and nonnegative, with finite lo <= hi "
	    "(IEEE 1800-2017 16.9.2)"));
      FILE_NAME(message.parm, loc);
      fatal_args.push_back(message);
      PCallTask*fatal = new PCallTask(
	    perm_string::literal("$fatal"), fatal_args);
      FILE_NAME(fatal, loc);
      gen->elab_tasks.push_back(fatal);

      if (PGenerate*parent = dynamic_cast<PGenerate*>(owner))
	    parent->generate_schemes.push_back(gen);
      else {
	    Module*mod = dynamic_cast<Module*>(owner);
	    ivl_assert(loc, mod);
	    mod->generate_schemes.push_back(gen);
      }
}

static bool sva_parameter_checker_preflight_(
				const struct vlltype&loc,
				const sva_property_t*prop,
				PExpr*top_src,
				PExpr*repeat_lo_src,
				PExpr*repeat_hi_src,
				PExpr*window_lo_src,
				PExpr*window_hi_src,
				sva_parameter_preflight_t&prep)
{
      if (!prop || !top_src || !repeat_lo_src) return false;

	/* Bounds remain parse expressions in the eventual declarations. These
	   copies only prove that all expressions needed after commit are
	   structurally cloneable; no declaration default is evaluated here. */
      PExpr*top_test = sva_clone_expr_(top_src);
      PExpr*lo_test = sva_clone_expr_(repeat_lo_src);
      PExpr*hi_test = repeat_hi_src
	    ? sva_clone_expr_(repeat_hi_src) : nullptr;
      PExpr*window_lo_test = window_lo_src
	    ? sva_clone_expr_(window_lo_src) : nullptr;
      PExpr*window_hi_test = window_hi_src
	    ? sva_clone_expr_(window_hi_src) : nullptr;
      if (!top_test || !lo_test || (repeat_hi_src && !hi_test)
	  || (window_lo_src && !window_lo_test)
	  || (window_hi_src && !window_hi_test)
	  || ((window_lo_src == nullptr) != (window_hi_src == nullptr))) {
	    delete top_test;
	    delete lo_test;
	    delete hi_test;
	    delete window_lo_test;
	    delete window_hi_test;
	    return false;
      }
      delete top_test;
      delete lo_test;
	delete hi_test;
	delete window_lo_test;
	delete window_hi_test;

	/* Build, but do not yet attach, the per-instance validity guard. Every
	   source occurrence is cloned independently because its eventual
	   generated comparison owns that expression tree. */
      std::vector<PExpr*> bad_bounds;
      PExpr*bad = sva_parameter_bad_nonnegative_(loc, repeat_lo_src);
      if (!bad) return false;
      bad_bounds.push_back(bad);
      if (repeat_hi_src) {
	    bad = sva_parameter_bad_nonnegative_(loc, repeat_hi_src);
	    if (bad) bad_bounds.push_back(bad);
	    PExpr*order = bad
		  ? sva_parameter_bad_order_(loc, repeat_hi_src,
					     repeat_lo_src) : nullptr;
	    if (!bad || !order) {
		  for (size_t idx = 0 ; idx < bad_bounds.size() ; idx += 1)
			delete bad_bounds[idx];
		  delete order;
		  return false;
	    }
	    bad_bounds.push_back(order);
      }
      if (window_lo_src) {
	    PExpr*bad_lo = sva_parameter_bad_nonnegative_(loc, window_lo_src);
	    PExpr*bad_hi = sva_parameter_bad_nonnegative_(loc, window_hi_src);
	    PExpr*order = (bad_lo && bad_hi)
		  ? sva_parameter_bad_order_(loc, window_hi_src,
					     window_lo_src) : nullptr;
	    if (!bad_lo || !bad_hi || !order) {
		  for (size_t idx = 0 ; idx < bad_bounds.size() ; idx += 1)
			delete bad_bounds[idx];
		  delete bad_lo;
		  delete bad_hi;
		  delete order;
		  return false;
	    }
	    bad_bounds.push_back(bad_lo);
	    bad_bounds.push_back(bad_hi);
	    bad_bounds.push_back(order);
      }
      prep.invalid_bounds = sva_logic_reduce_(loc, 'o', bad_bounds);

	/* Internal conditional-generate validation is only scope-correct in the
	   module/generate locations where this focused checker is synthesized. */
      if (!dynamic_cast<Module*>(lexical_scope)
	  && !dynamic_cast<PGenerate*>(lexical_scope)) {
	    sva_parameter_preflight_discard_(prep);
	    return false;
      }
      prep.guard_owner = lexical_scope;

	/* `disable iff` has two independent consumers: its Observed-region
	   level test and the asynchronous exact-false-to-exact-true abort
	   process. Pre-create both so neither semantic half can disappear after
	   the checker has committed. */
      PExpr*disable_src = prop->disable_iff_expr
	    ? prop->disable_iff_expr : sva_default_disable;
      if (disable_src) {
	    prep.disable_level = sva_clone_expr_(disable_src);
	    prep.disable_event = sva_clone_expr_(disable_src);
	    if (!prep.disable_level || !prep.disable_event) {
		  sva_parameter_preflight_discard_(prep);
		  return false;
	    }
      }

      prep.clk = prop->clk_evt;
      if (!prep.clk) {
	    Module*mod = pform_cur_module.empty() ? nullptr
		       : pform_cur_module.front();
	    if (!mod || mod->default_clocking.nil()) {
		  sva_parameter_preflight_discard_(prep);
		  return false;
	    }
	    std::list<named_pexpr_t> no_parms;
	    PECallFunction*mark = new PECallFunction(
		  perm_string::literal("$ivl_default_clock"), no_parms);
	    FILE_NAME(mark, loc);
	    PEEvent*ev = new PEEvent(PEEvent::ANYEDGE, mark);
	    std::vector<PEEvent*> evs;
	    evs.push_back(ev);
	    prep.clk = new PEventStatement(evs);
	    FILE_NAME(prep.clk, loc);
	    prep.owns_clk = true;
      }
      return true;
}

/* IEEE 1800-2017 16.9.2: an overridable-parameter consecutive repetition
 * in the variable-length antecedent shape used by OpenTitan's
 * prim_esc_rxtx_assert_fpv:
 *
 *   prefix ##1 keep[*lo:hi] |-> ##1 result
 *   prefix ##1 keep[*lo:$]  |-> ##1 result
 *
 * cannot be expanded from the parameter DEFAULT while the containing module
 * is parsed.  Represent every live repetition age as one bit of a packed
 * [bound:0] vector.  Its range remains a parse expression, so ordinary
 * elaboration applies each module instance's parameter override before
 * sizing it.  One new prefix attempt is injected every tick; shifting under
 * `keep' advances ALL overlapping attempts.  For a bounded range every set
 * bit in [lo:hi] is an endpoint.  For an unbounded range a 64-bit mature
 * counter retains the exact multiplicity of attempts that reached lo after
 * their age bits leave the [lo:0] vector, preserving every endpoint from lo
 * onward without an attempt-pool cap. Endpoint existence is deliberately not
 * first_match: it launches a ##1 obligation on every eligible tick.
 *
 * This focused path commits only for the exact Boolean implication shape.
 * Other parameter-repetition compositions remain loud, rather than being
 * approximated by the parse default or by a capped cyclic NFA. */
static bool sva_parameter_repeat_try_assertion_(
				const struct vlltype&loc,
				sva_property_t*prop,
				Statement*fail_stmt,
				Statement*pass_stmt,
				int kind)
{
      bool cover = kind == 2;
      bool standalone_cover_rewrite = false;

	/* A standalone exact symbolic consecutive repetition has the same
	   match endpoints as an overlapped implication to literal true. Keep
	   the bound expression intact and reuse the instance-sized implication
	   state below; this is deliberately narrower than a symbolic range. */
      if (cover && prop && prop->op_type == 0
	  && !prop->tree && !prop->ante_tree && !prop->seq_clk_evt
	  && !prop->mc_prefix && (!prop->mc_more || prop->mc_more->empty())
	  && prop->mc_boundary == -1 && !prop->abort_cond
	  && prop->strength == 0 && !prop->forbidden_consequent
	  && prop->win_lo == -1 && prop->win_hi == -1
	  && !prop->antecedent && prop->seq && prop->seq->size() == 1) {
	    sva_seq_step_t&repeat = prop->seq->front();
	    bool exact_symbolic = repeat.expr
		  && repeat.delay_lo == 0 && repeat.delay_hi == 0
		  && !repeat.delay_lo_expr && !repeat.delay_hi_expr
		  && repeat.delay_genvar.nil() && repeat.rep_tail == 0
		  && repeat.rep_kind == 4 && repeat.rep_hi == 0
		  && repeat.rep_lo_expr && !repeat.rep_hi_expr
		  && !repeat.fm && !repeat.lv_rhs;
	    if (exact_symbolic) {
		  prop->antecedent = prop->seq;
		  prop->seq = new std::vector<sva_seq_step_t>;
		  sva_seq_step_t consequent;
		  consequent.expr = sva_bit_(loc, 1);
		  prop->seq->push_back(consequent);
		  prop->op_type = 1;
		  standalone_cover_rewrite = true;
	    }
      }

	/* A probe is allowed to decline. Roll the exact-cover normalization
	   back in that case so the generic engine sees precisely the property
	   and actions it was originally passed. */
      auto restore_standalone_cover = [&]() {
	    if (!standalone_cover_rewrite) return;
	    pform_sva_destroy_sequence(prop->seq);
	    prop->seq = prop->antecedent;
	    prop->antecedent = nullptr;
	    prop->op_type = 0;
	    standalone_cover_rewrite = false;
      };

      if (!prop || (kind != 0 && kind != 1 && kind != 2)
	  || (prop->op_type != 1 && prop->op_type != 2)
	  || prop->tree || prop->ante_tree || prop->seq_clk_evt
	  || prop->mc_prefix || (prop->mc_more && !prop->mc_more->empty())
	  || prop->mc_boundary != -1 || prop->abort_cond
	  || prop->strength != 0 || prop->forbidden_consequent
	  || prop->win_lo != -1 || prop->win_hi != -1
	  || !prop->antecedent
	  || (prop->antecedent->size() != 1
	      && prop->antecedent->size() != 2)
	  || !prop->seq || prop->seq->size() != 1)
	    {
	      restore_standalone_cover();
	      return false;
	    }

      bool direct_repeat = prop->antecedent->size() == 1;
      sva_seq_step_t*prefix = direct_repeat
			     ? nullptr : &(*prop->antecedent)[0];
      sva_seq_step_t&repeat = prop->antecedent->back();
      sva_seq_step_t&cons = (*prop->seq)[0];
	/* OpenTitan rstmgr uses a named antecedent with an exact
	   parameter-valued repetition, followed by the nonoverlapped bounded
	   window ##[0:RiseMax-RiseMin].  The upper bound is deliberately kept
	   as a parse expression so every interface instance sees its override. */
      bool windowed_cons = (prop->op_type == 1 || prop->op_type == 2)
	    && cons.delay_lo == -5 && cons.delay_hi == -5
	    && cons.delay_lo_expr && cons.delay_hi_expr
	    && repeat.rep_hi != -1 && !repeat.rep_hi_expr;
      bool fixed_cons = prop->op_type == 1
	    && cons.delay_lo == cons.delay_hi
	    && (cons.delay_lo == 0 || cons.delay_lo == 1);
      bool prefix_ok = direct_repeat
	    || (prefix->expr && prefix->delay_lo == 0 && prefix->delay_hi == 0
		&& prefix->delay_genvar.nil() && prefix->rep_tail == 0
		&& prefix->rep_kind == 0 && !prefix->fm && !prefix->lv_rhs);
      long repeat_delay = direct_repeat ? 0 : 1;
      if (!prefix_ok
	  || !repeat.expr || repeat.delay_lo != repeat_delay
	  || repeat.delay_hi != repeat_delay
	  || !repeat.delay_genvar.nil() || repeat.rep_tail != 0
	  || repeat.rep_kind != 4 || repeat.fm || repeat.lv_rhs
	  || !repeat.rep_lo_expr
	  || !cons.expr || (!fixed_cons && !windowed_cons)
	  || !cons.delay_genvar.nil() || cons.rep_tail != 0
	  || cons.rep_kind != 0 || cons.fm || cons.lv_rhs)
	    {
	      restore_standalone_cover();
	      return false;
	    }

      bool unbounded = repeat.rep_hi == -1;
      PExpr*top_src = unbounded || !repeat.rep_hi_expr
		     ? repeat.rep_lo_expr : repeat.rep_hi_expr;
	/* Preflight every structural clone, both disable consumers, and any
	   synthesized default-clock event before declaring checker state. */
      sva_parameter_preflight_t prepared;
      if (!sva_parameter_checker_preflight_(
		loc, prop, top_src, repeat.rep_lo_expr,
		repeat.rep_hi_expr,
		windowed_cons ? cons.delay_lo_expr : nullptr,
		windowed_cons ? cons.delay_hi_expr : nullptr, prepared)) {
	    restore_standalone_cover();
	    return false;
      }

      /* ---- Committed: everything below consumes the property. ---- */
      PEventStatement*clk = prepared.clk;
      PExpr*disable = prepared.disable_level;
      PExpr*disable_event = prepared.disable_event;
      PExpr*invalid_bounds = prepared.invalid_bounds;
      LexicalScope*guard_owner = prepared.guard_owner;
      prepared.clk = nullptr;
      prepared.owns_clk = false;
      prepared.disable_level = nullptr;
      prepared.disable_event = nullptr;
      prepared.invalid_bounds = nullptr;
      prepared.guard_owner = nullptr;
	/* The checker owns two preflighted copies now. The parse property's
	   original explicit disable expression is no longer needed. */
      delete prop->disable_iff_expr;
      prop->disable_iff_expr = nullptr;
      if (cover && pass_stmt) {
	    cerr << loc << ": warning: the pass statement of this "
		 << "`cover property' is not executed (recorded corner); "
		 << "it is dropped. The match counter still counts."
		 << endl;
	    delete pass_stmt;
	    pass_stmt = nullptr;
      }
      unsigned inst = sva_gensym_counter++;
      sva_parameter_add_bound_guard_(loc, inst, guard_owner,
				     invalid_bounds);
      unsigned hist_idx = 0;
      std::vector<Statement*> pre, post, init_zero;

      Statement*fail_action = cover ? nullptr : fail_stmt;
      if (cover) {
	    delete fail_stmt;
	    fail_stmt = nullptr;
      }
      if (!cover && !fail_action) {
	    std::list<named_pexpr_t> no_args;
	    PCallTask*err = new PCallTask(
		  lex_strings.make("$error"), no_args);
	    FILE_NAME(err, loc);
	    fail_action = err;
      }
      std::map<std::string, pform_name_t> prep_sampled;
      unsigned prep_live_operands = 0;
      auto capture = [&](PExpr*key, unsigned idx) -> perm_string {
	    PExpr*src = key;
	    PExpr*prep = sva_wrap_preponed_(key, prep_sampled,
					   prep_live_operands);
	    if (prep) src = prep;
	    else prep_live_operands += 1;
	    PExpr*be = sva_rewrite_sampled_(loc, src, inst, hist_idx,
					   pre, post, init_zero);
	    perm_string reg = sva_make_reg_(loc, inst, "rb", idx);
	    pre.push_back(sva_assign_(loc, reg, be));
	    return reg;
      };
      perm_string r_prefix;
      unsigned capture_idx = 0;
      if (prefix)
	    r_prefix = capture(prefix->expr, capture_idx++);
      perm_string r_keep = capture(repeat.expr, capture_idx++);
      perm_string r_cons = capture(cons.expr, capture_idx++);

      for (std::map<std::string, pform_name_t>::const_iterator it =
		 prep_sampled.begin() ; it != prep_sampled.end() ; ++it)
	    init_zero.push_back(sva_hist_on_stmt_(loc, it->second));
      if (prep_live_operands > 0)
	    cerr << loc << ": warning: this assertion has "
		 << prep_live_operands << " operand(s) that are read live "
		 << "instead of sampled in the Preponed region (IEEE "
		 << "1800-2017 16.5.1); a blocking write to one of them in "
		 << "the clock time slot can be visible to the assertion."
		 << endl;

      perm_string pipe = sva_make_parameter_pipe_(
		loc, inst, sva_clone_expr_(top_src));
      perm_string r_due = sva_make_reg_(loc, inst, "rdue", 0, true);
      perm_string r_fire = sva_make_reg_(loc, inst, "rfire", 0, true);
      perm_string r_end = sva_make_reg_(loc, inst, "rend", 0, true);
      perm_string r_count;
      perm_string r_pass_req;
      perm_string r_pass_ack;
      perm_string r_pass_due;
      perm_string r_fail_req;
      perm_string r_fail_ack;
      perm_string r_fail_due;
      if (cover) {
	    r_count = sva_make_reg_(loc, inst, "cnt", 0, true);
      } else {
	    r_pass_req = sva_make_reg_(loc, inst, "rpreq", 0, true);
	    r_pass_ack = sva_make_reg_(loc, inst, "rpack", 0, true);
	    r_pass_due = sva_make_reg_(loc, inst, "rpdue", 0, true);
	    r_fail_req = sva_make_reg_(loc, inst, "rfreq", 0, true);
	    r_fail_ack = sva_make_reg_(loc, inst, "rfack", 0, true);
	    r_fail_due = sva_make_reg_(loc, inst, "rfdue", 0, true);
      }
      perm_string r_mature;
      perm_string r_cpipe;
      if (unbounded)
	    r_mature = sva_make_reg_(loc, inst, "rmat", 0, true);
      if (windowed_cons)
	    r_cpipe = sva_make_parameter_pipe_(
		  loc, inst, sva_clone_expr_(cons.delay_hi_expr), "cpipe");
      init_zero.push_back(sva_assign_(loc, pipe, sva_bit_(loc, 0)));
      init_zero.push_back(sva_assign_(loc, r_due, sva_bit_(loc, 0)));
      init_zero.push_back(sva_assign_(loc, r_fire, sva_bit_(loc, 0)));
      init_zero.push_back(sva_assign_(loc, r_end, sva_bit_(loc, 0)));
      if (cover) {
	    init_zero.push_back(sva_assign_(loc, r_count, sva_bit_(loc, 0)));
      } else {
	    init_zero.push_back(sva_assign_(loc, r_pass_req,
				      sva_bit_(loc, 0)));
	    init_zero.push_back(sva_assign_(loc, r_pass_ack,
				      sva_bit_(loc, 0)));
	    init_zero.push_back(sva_assign_(loc, r_pass_due,
				      sva_bit_(loc, 0)));
	    init_zero.push_back(sva_assign_(loc, r_fail_req,
				      sva_bit_(loc, 0)));
	    init_zero.push_back(sva_assign_(loc, r_fail_ack,
				      sva_bit_(loc, 0)));
	    init_zero.push_back(sva_assign_(loc, r_fail_due,
				      sva_bit_(loc, 0)));
      }
      if (unbounded)
	    init_zero.push_back(sva_assign_(loc, r_mature,
					      sva_bit_(loc, 0)));
      if (windowed_cons)
	    init_zero.push_back(sva_assign_(loc, r_cpipe, sva_bit_(loc, 0)));
      perm_string r_kill = sva_kill_seen_reg_(loc, inst, 0, init_zero);

      auto number32 = [&](unsigned value) -> PExpr* {
	    PENumber*n = new PENumber(new verinum((uint64_t)value, 32));
	    FILE_NAME(n, loc);
	    return n;
      };
      auto exact_true = [&](PExpr*value) -> PExpr* {
	    PEBComp*is_true = new PEBComp('E', value, sva_bit_(loc, 1));
	    FILE_NAME(is_true, loc);
	    return is_true;
      };
      auto age_source = [&]() -> PExpr* {
	    if (!direct_repeat) return sva_id_(loc, pipe);
	    PEBinary*inject = new PEBinary('|', sva_id_(loc, pipe),
				      sva_enabled_expr_(loc, inst));
	    FILE_NAME(inject, loc);
	    return inject;
      };
      auto shift_left_pipe = [&]() -> PExpr* {
	    PEBShift*s = new PEBShift('l', age_source(), number32(1));
	    FILE_NAME(s, loc);
	    return s;
      };
      auto extension_at_or_above_lo = [&]() -> PExpr* {
	    PEBShift*r = new PEBShift('r', shift_left_pipe(),
				 sva_clone_expr_(repeat.rep_lo_expr));
	    FILE_NAME(r, loc);
	    return r;
      };
      auto countones = [&](PExpr*expr) -> PExpr* {
	    std::list<named_pexpr_t> args;
	    named_pexpr_t arg;
	    arg.parm = expr;
	    args.push_back(arg);
	    PECallFunction*call = new PECallFunction(
		  perm_string::literal("$countones"), args);
	    FILE_NAME(call, loc);
	    return call;
      };
      auto source_bit_zero = [&]() -> PExpr* {
	    if (!direct_repeat)
		  return sva_index_(loc, pipe, number32(0));
	    PEBinary*bit = new PEBinary(
		  '|', sva_index_(loc, pipe, number32(0)),
		  sva_enabled_expr_(loc, inst));
	    FILE_NAME(bit, loc);
	    return bit;
      };
      auto lo_is_zero = [&]() -> PExpr* {
	    PEBComp*eq = new PEBComp('e',
			       sva_clone_expr_(repeat.rep_lo_expr), number32(0));
	    FILE_NAME(eq, loc);
	    return eq;
      };

      std::vector<Statement*> body;
      body.push_back(sva_if_(loc, sva_enabled_expr_(loc, inst),
			     sva_report_stmt_(loc, inst, SVA_CB_START), nullptr));

	/* r_cpipe holds one bit for every exact-repetition endpoint whose
	   consequence window is live. Bits below `lo' are not eligible yet;
	   bits at/above it all succeed together when the Boolean consequent is
	   true. On a false tick only the inclusive `hi' endpoint expires. */
      if (windowed_cons) {
	    PEBShift*mature = new PEBShift(
		  'r', sva_id_(loc, r_cpipe),
		  sva_clone_expr_(cons.delay_lo_expr));
	    FILE_NAME(mature, loc);
	    PExpr*active_count = countones(mature);
	    PEBShift*mature_again = new PEBShift(
		  'r', sva_id_(loc, r_cpipe),
		  sva_clone_expr_(cons.delay_lo_expr));
	    FILE_NAME(mature_again, loc);
	    PEBShift*restore_mature = new PEBShift(
		  'l', mature_again, sva_clone_expr_(cons.delay_lo_expr));
	    FILE_NAME(restore_mature, loc);
	    PEBinary*young = new PEBinary(
		  '^', sva_id_(loc, r_cpipe), restore_mature);
	    FILE_NAME(young, loc);
	    PEBShift*advance_young = new PEBShift('l', young, number32(1));
	    FILE_NAME(advance_young, loc);
	    PEBShift*advance_all = new PEBShift(
		  'l', sva_id_(loc, r_cpipe), number32(1));
	    FILE_NAME(advance_all, loc);
	    std::vector<Statement*> matched;
	    if (cover) {
		  PEBinary*count_add = new PEBinary(
			'+', sva_id_(loc, r_count), active_count);
		  FILE_NAME(count_add, loc);
		  matched.push_back(sva_assign_(loc, r_count, count_add));
	    } else {
		  PEBinary*pass_add = new PEBinary(
			'+', sva_id_(loc, r_pass_req), active_count);
		  FILE_NAME(pass_add, loc);
		  matched.push_back(sva_assign_(loc, r_pass_req, pass_add));
	    }
	    matched.push_back(sva_assign_(loc, r_cpipe, advance_young));
	    std::vector<Statement*> waiting;
	    if (!cover) {
		  PExpr*expired = sva_index_(
			loc, r_cpipe, sva_clone_expr_(cons.delay_hi_expr));
		  PEBinary*fail_add = new PEBinary(
			'+', sva_id_(loc, r_fail_req), expired);
		  FILE_NAME(fail_add, loc);
		  waiting.push_back(sva_assign_(loc, r_fail_req, fail_add));
	    }
	    waiting.push_back(sva_assign_(loc, r_cpipe, advance_all));
	    body.push_back(sva_if_(loc, exact_true(sva_id_(loc, r_cons)),
				   sva_block_(loc, matched),
				   sva_block_(loc, waiting)));
      }

	/* Save a ##1 consequence's prior due bit before updating it. User
	   actions wait for the Reactive region, so all checker state must
	   advance before dispatch. A ##0 consequence takes the endpoint
	   computed below on this same sampled tick. */
      if (!windowed_cons && cons.delay_lo == 1)
	    body.push_back(sva_assign_(loc, r_fire, sva_id_(loc, r_due)));

      auto zero_count = [&]() -> PExpr* {
	    PExpr*source = direct_repeat ? sva_bit_(loc, 1)
					  : static_cast<PExpr*>(
						exact_true(
						      sva_id_(loc, r_prefix)));
	    PETernary*count = new PETernary(lo_is_zero(), source,
					       number32(0));
	    FILE_NAME(count, loc);
	    return count;
      };
      if (unbounded) {
	    auto new_mature_count = [&]() -> PExpr* {
		  PETernary*count = new PETernary(
			lo_is_zero(), source_bit_zero(),
			countones(extension_at_or_above_lo()));
		  FILE_NAME(count, loc);
		  return count;
	    };
	    auto active_mature_count = [&]() -> PExpr* {
		  PEBinary*sum = new PEBinary('+', sva_id_(loc, r_mature),
					 new_mature_count());
		  FILE_NAME(sum, loc);
		  PETernary*active = new PETernary(
			exact_true(sva_id_(loc, r_keep)), sum,
			number32(0));
		  FILE_NAME(active, loc);
		  return active;
	    };
	    PEBinary*total_end = new PEBinary(
		  '+', zero_count(), active_mature_count());
	    FILE_NAME(total_end, loc);
	    body.push_back(sva_assign_(loc, r_end, total_end));
	    body.push_back(sva_assign_(loc, r_mature,
					 active_mature_count()));
      } else {
	    PETernary*nonempty = new PETernary(
		  exact_true(sva_id_(loc, r_keep)),
		  countones(extension_at_or_above_lo()), number32(0));
	    FILE_NAME(nonempty, loc);
	    PEBinary*total_end = new PEBinary('+', zero_count(), nonempty);
	    FILE_NAME(total_end, loc);
	    body.push_back(sva_assign_(loc, r_end, total_end));
      }
      if (windowed_cons) {
	    if (prop->op_type == 2) {
		  PEBinary*inject_cons = new PEBinary(
			'|', sva_id_(loc, r_cpipe),
			exact_true(sva_id_(loc, r_end)));
		  FILE_NAME(inject_cons, loc);
		  body.push_back(sva_assign_(loc, r_cpipe, inject_cons));
	    } else {
		  auto inject_age_one = [&]() -> Statement* {
			PEBinary*inject = new PEBinary(
			      '|', sva_id_(loc, r_cpipe), number32(2));
			FILE_NAME(inject, loc);
			return sva_assign_(loc, r_cpipe, inject);
		  };
		  Statement*matched_now = nullptr;
		  Statement*not_matched = nullptr;
		  if (cover) {
			PEBinary*count_add = new PEBinary(
			      '+', sva_id_(loc, r_count), sva_id_(loc, r_end));
			FILE_NAME(count_add, loc);
			matched_now = sva_assign_(loc, r_count, count_add);
			PEBComp*hi_nonzero = new PEBComp(
			      'n', sva_clone_expr_(cons.delay_hi_expr),
			      number32(0));
			FILE_NAME(hi_nonzero, loc);
			not_matched = sva_if_(loc, hi_nonzero,
					      inject_age_one(), nullptr);
		  } else {
			PEBinary*pass_one = new PEBinary(
			      '+', sva_id_(loc, r_pass_req), number32(1));
			FILE_NAME(pass_one, loc);
			matched_now = sva_assign_(loc, r_pass_req, pass_one);
			PEBinary*fail_one = new PEBinary(
			      '+', sva_id_(loc, r_fail_req), number32(1));
			FILE_NAME(fail_one, loc);
			PEBComp*hi_zero = new PEBComp(
			      'e', sva_clone_expr_(cons.delay_hi_expr),
			      number32(0));
			FILE_NAME(hi_zero, loc);
			not_matched = sva_if_(
			      loc, hi_zero,
			      sva_assign_(loc, r_fail_req, fail_one),
			      inject_age_one());
		  }
		  Statement*at_zero = sva_if_(
			loc, exact_true(sva_id_(loc, r_cons)),
			matched_now, not_matched);
		  PEBComp*lo_zero = new PEBComp(
			'e', sva_clone_expr_(cons.delay_lo_expr), number32(0));
		  FILE_NAME(lo_zero, loc);
		  Statement*dispatch_new = sva_if_(
			loc, lo_zero, at_zero, inject_age_one());
		  body.push_back(sva_if_(
			loc, exact_true(sva_id_(loc, r_end)),
			dispatch_new, nullptr));
	    }
      } else if (cons.delay_lo == 1) {
	    body.push_back(sva_assign_(loc, r_due, sva_id_(loc, r_end)));
      } else {
	    body.push_back(sva_assign_(loc, r_fire, sva_id_(loc, r_end)));
      }

	/* Advance every active age. A direct repeat has already ORed a virtual
	   current-tick attempt into bit zero before this shift; the prefix form
	   instead injects its sampled prefix after shifting. A false keep kills
	   every nonzero repetition age simultaneously. */

      PETernary*advance = new PETernary(
					 exact_true(sva_id_(loc, r_keep)),
					 shift_left_pipe(), sva_bit_(loc, 0));
      FILE_NAME(advance, loc);
      PExpr*next_pipe = advance;
      if (!direct_repeat) {
	    PEBLogic*start = new PEBLogic(
		  'a', exact_true(sva_id_(loc, r_prefix)),
		  sva_enabled_expr_(loc, inst));
	    FILE_NAME(start, loc);
	    PEBinary*inject = new PEBinary('|', next_pipe, start);
	    FILE_NAME(inject, loc);
	    next_pipe = inject;
      }
      body.push_back(sva_assign_(loc, pipe, next_pipe));

	/* Publish verdict counts without suspending the clocked checker. A
	   dedicated permanent-Reactive dispatcher below drains each counter.
	   This handoff is what keeps detached action children in the Reactive
	   process set even after their own #delay or @event continuation. */
      if (!windowed_cons) {
	    if (cover) {
		  PEBinary*count_add = new PEBinary(
			'+', sva_id_(loc, r_count), sva_id_(loc, r_fire));
		  FILE_NAME(count_add, loc);
		  body.push_back(sva_if_(
			loc, exact_true(sva_id_(loc, r_cons)),
			sva_assign_(loc, r_count, count_add), nullptr));
	    } else {
		  PEBinary*pass_add = new PEBinary(
			'+', sva_id_(loc, r_pass_req), sva_id_(loc, r_fire));
		  FILE_NAME(pass_add, loc);
		  PEBinary*fail_add = new PEBinary(
			'+', sva_id_(loc, r_fail_req), sva_id_(loc, r_fire));
		  FILE_NAME(fail_add, loc);
		  Statement*verdict = sva_if_(
			loc, sva_id_(loc, r_cons),
			sva_assign_(loc, r_pass_req, pass_add),
			sva_assign_(loc, r_fail_req, fail_add));
		  body.push_back(sva_if_(loc, sva_id_(loc, r_fire),
					 verdict, nullptr));
	    }
      }

      auto clear_state = [&]() -> Statement* {
	    std::vector<Statement*> clear;
	    clear.push_back(sva_assign_(loc, pipe, sva_bit_(loc, 0)));
	    clear.push_back(sva_assign_(loc, r_due, sva_bit_(loc, 0)));
	    clear.push_back(sva_assign_(loc, r_fire, sva_bit_(loc, 0)));
	    clear.push_back(sva_assign_(loc, r_end, sva_bit_(loc, 0)));
	    if (windowed_cons)
		  clear.push_back(sva_assign_(loc, r_cpipe, sva_bit_(loc, 0)));
	    if (unbounded)
		  clear.push_back(sva_assign_(loc, r_mature,
					 sva_bit_(loc, 0)));
	    return sva_block_(loc, clear);
      };

	/* `disable iff` is unsampled. Evaluate its level only after the
	   checker reaches Observed, so an NBA update in this clock slot is
	   visible before any verdict is published. The independent edge
	   process below clears live attempts on the exact-false-to-exact-true
	   transition, including a pulse that falls again before that process
	   executes. */
      std::vector<Statement*> full = pre;
      full.push_back(sva_observed_wait_(loc));
      full.push_back(sva_kill_reset_stmt_(
	    loc, inst, r_kill, clear_state()));
      Statement*core = sva_block_(loc, body);
      if (disable) {
	    PCondit*dc = new PCondit(disable, clear_state(), core);
	    FILE_NAME(dc, loc);
	    full.push_back(dc);
      } else {
	    full.push_back(core);
      }
      for (size_t idx = 0 ; idx < post.size() ; idx += 1)
	    full.push_back(post[idx]);

      clk->set_statement(sva_block_(loc, full));
      PProcess*pp = pform_make_behavior(IVL_PR_ALWAYS, clk, nullptr);
      FILE_NAME(pp, loc);


      if (disable_event) {
	    PEBComp*disable_became_true = new PEBComp(
		  'E', disable_event, sva_bit_(loc, 1));
	    FILE_NAME(disable_became_true, loc);
	    std::vector<PEEvent*> abort_evs;
	    abort_evs.push_back(new PEEvent(PEEvent::POSEDGE,
					 disable_became_true));
	    PEventStatement*abort = new PEventStatement(abort_evs);
	    FILE_NAME(abort, loc);
	    abort->set_statement(clear_state());
	    PProcess*abort_process = pform_make_behavior(
		  IVL_PR_ALWAYS, abort, nullptr);
	    FILE_NAME(abort_process, loc);
      }

      init_zero.push_back(sva_register_stmt_(loc, inst, -1, !cover));
      PProcess*ip = pform_make_behavior(IVL_PR_INITIAL,
				sva_block_(loc, init_zero), nullptr);
      FILE_NAME(ip, loc);

	/* A dispatcher is a permanently Reactive process, not a checker that
	   briefly waits for Reactive and then forks from the wrong scheduler
	   set. It snapshots/acknowledges each request batch before dispatch so
	   a request posted while an older batch drains is consumed on the next
	   forever iteration without losing the already-arrived edge. Callback
	   notification precedes user code; each action is detached so one
	   delayed or nonterminating action cannot serialize its siblings. */
      auto make_dispatcher = [&](perm_string req, perm_string ack,
				 perm_string due, Statement*action,
				 int reason) {
	    std::vector<PEEvent*> evs;
	    evs.push_back(new PEEvent(PEEvent::ANYEDGE, sva_id_(loc, req)));
	    PEventStatement*wait = new PEventStatement(evs);
	    FILE_NAME(wait, loc);

	    PEBComp*idle = new PEBComp(
		  'e', sva_id_(loc, req), sva_id_(loc, ack));
	    FILE_NAME(idle, loc);
	    std::vector<Statement*> loop;
	    loop.push_back(sva_if_(loc, idle, wait, nullptr));
	    PEBinary*delta = new PEBinary(
		  '-', sva_id_(loc, req), sva_id_(loc, ack));
	    FILE_NAME(delta, loc);
	    loop.push_back(sva_assign_(loc, due, delta));
	    loop.push_back(sva_assign_(loc, ack, sva_id_(loc, req)));
	    loop.push_back(sva_reactive_wait_(loc));
	    loop.push_back(sva_repeat_(
		  loc, sva_id_(loc, due),
		  sva_report_stmt_(loc, inst, reason)));

	    if (action) {
		  PBlock*spawn = new PBlock(PBlock::BL_JOIN_NONE);
		  FILE_NAME(spawn, loc);
		  std::vector<Statement*>one;
		  one.push_back(sva_gate_(loc, action));
		  spawn->set_statement(one);
		  loop.push_back(sva_repeat_(loc, sva_id_(loc, due), spawn));
	    }

	    PForever*forever = new PForever(sva_block_(loc, loop));
	    FILE_NAME(forever, loc);
	    std::vector<Statement*>start;
	    start.push_back(sva_reactive_process_(loc));
	    start.push_back(forever);
	    PDelayStatement*start_after_init = new PDelayStatement(
		  sva_num32_(loc, 0), sva_block_(loc, start));
	    FILE_NAME(start_after_init, loc);
	    PProcess*dispatcher = pform_make_behavior(
		  IVL_PR_INITIAL, start_after_init, nullptr);
	    FILE_NAME(dispatcher, loc);
      };
      if (!cover) {
	    make_dispatcher(r_pass_req, r_pass_ack, r_pass_due,
			    pass_stmt, SVA_CB_SUCCESS);
	    pass_stmt = nullptr;
	    make_dispatcher(r_fail_req, r_fail_ack, r_fail_due,
			    fail_action, SVA_CB_FAILURE);
	    fail_action = nullptr;
      }

      delete repeat.rep_lo_expr;
      repeat.rep_lo_expr = nullptr;
      delete repeat.rep_hi_expr;
      repeat.rep_hi_expr = nullptr;
      delete cons.delay_lo_expr;
      cons.delay_lo_expr = nullptr;
      delete cons.delay_hi_expr;
      cons.delay_hi_expr = nullptr;
      delete prop->antecedent;
      delete prop->seq;
      delete prop;
      return true;
}

/* Reduce a fixed sequence to the Boolean that is true on its endpoint tick.
   Every step is sampled at its relative age; equal-span OR/AND trees can be
   reduced the same way without losing distinct endpoint timing. */
static PExpr* sva_fixed_endpoint_match_(const struct vlltype&loc,
					const std::vector<sva_seq_step_t>&source,
					long&span)
{
      std::map<perm_string,PExpr*> no_subst;
      std::vector<sva_seq_step_t>*work = sva_clone_steps_subst_(
	    loc, &source, no_subst);
      if (!work) return nullptr;
      sva_splice_sequences_(loc, *work);

      span = 0;
      std::vector<long> offsets(work->size(), 0);
      for (size_t idx = 0 ; idx < work->size() ; idx += 1) {
	    const sva_seq_step_t&st = (*work)[idx];
	    if (!st.expr || st.delay_lo < 0 || st.delay_lo != st.delay_hi
		|| st.rep_tail != 0 || st.rep_kind != 0 || st.lv_rhs
		|| !st.delay_genvar.nil()) {
		  pform_sva_destroy_sequence(work);
		  return nullptr;
	    }
	    span += st.delay_lo;
	    if (span > 128) {
		  pform_sva_destroy_sequence(work);
		  return nullptr;
	    }
	    offsets[idx] = span;
      }

      PExpr*match = nullptr;
      for (size_t idx = 0 ; idx < work->size() ; idx += 1) {
	    PExpr*term = sva_clone_expr_((*work)[idx].expr);
	    if (!term) {
		  delete match;
		  pform_sva_destroy_sequence(work);
		  return nullptr;
	    }
	    term = sva_past_(loc, term, span - offsets[idx]);
	    if (match) {
		  PEBLogic*both = new PEBLogic('a', match, term);
		  FILE_NAME(both, loc);
		  match = both;
	    } else {
		  match = term;
	    }
      }
      pform_sva_destroy_sequence(work);
      return match;
}

static PExpr* sva_fixed_endpoint_match_(const struct vlltype&loc,
					sva_stree_t*tree, long&span)
{
      if (!tree) return nullptr;
      if (tree->kind == sva_stree_t::LEAF)
	    return tree->chain
		 ? sva_fixed_endpoint_match_(loc, *tree->chain, span) : nullptr;
      if (tree->kind != sva_stree_t::SEQ_OR
	  && tree->kind != sva_stree_t::SEQ_AND)
	    return nullptr;
      long left_span = 0, right_span = 0;
      PExpr*left = sva_fixed_endpoint_match_(loc, tree->a, left_span);
      PExpr*right = sva_fixed_endpoint_match_(loc, tree->b, right_span);
      if (!left || !right || left_span != right_span) {
	    delete left;
	    delete right;
	    return nullptr;
      }
      PEBLogic*both = new PEBLogic(
	    tree->kind == sva_stree_t::SEQ_OR ? 'o' : 'a', left, right);
      FILE_NAME(both, loc);
      span = left_span;
      return both;
}

/* General parameter-aware bounded implication. Turn a fixed antecedent
   endpoint (or an equal-span OR/AND of fixed antecedents) into a Boolean
   exact-one repetition, then reuse the symbolic-window machinery above.
   The synthetic [*1] has the same endpoint tick as its Boolean operand; it
   exists only to feed the already-proven overlapping-attempt state model. */
static bool sva_parameter_window_try_assertion_(
				const struct vlltype&loc,
				sva_property_t*prop,
				Statement*fail_stmt,
				Statement*pass_stmt,
				int kind)
{
      if (!prop || (kind != 0 && kind != 1 && kind != 2)
	  || (prop->op_type != 1 && prop->op_type != 2)
	  || prop->seq_clk_evt || prop->mc_prefix
	  || (prop->mc_more && !prop->mc_more->empty())
	  || prop->mc_boundary != -1 || prop->abort_cond
	  || prop->strength != 0 || prop->forbidden_consequent
	  || prop->win_lo != -1 || prop->win_hi != -1)
	    return false;

      std::vector<sva_seq_step_t>*cons_seq = prop->seq;
      bool tree_form = prop->tree != nullptr;
      if (tree_form) {
	    if (!prop->ante_tree || prop->tree->kind != sva_stree_t::LEAF
		|| !prop->tree->chain)
		  return false;
	    cons_seq = prop->tree->chain;
      } else if (prop->ante_tree) {
	    return false;
      }
      if (!cons_seq || cons_seq->size() != 1) return false;
      sva_seq_step_t&cons = (*cons_seq)[0];
      if (!cons.expr || cons.delay_lo != -5 || cons.delay_hi != -5
	  || !cons.delay_lo_expr || !cons.delay_hi_expr
	  || !cons.delay_genvar.nil() || cons.rep_tail != 0
	  || cons.rep_kind != 0 || cons.fm || cons.lv_rhs)
	    return false;
      long span = 0;
      PExpr*match = tree_form
	    ? sva_fixed_endpoint_match_(loc, prop->ante_tree, span)
	    : (prop->antecedent
	       ? sva_fixed_endpoint_match_(loc, *prop->antecedent, span)
	       : nullptr);
      if (!match) return false;

	/* The nested symbolic-repeat helper must not be the first code to
	   discover an unclonable bound/disable or a missing clock after the
	   original antecedent tree has been destroyed. Its synthetic exact-one
	   repetition has literal top/low bounds; preflight those together with
	   the real window high and both disable consumers now. */
      PENumber*one_probe = new PENumber(new verinum((uint64_t)1, 32));
      FILE_NAME(one_probe, loc);
      sva_parameter_preflight_t prepared;
      bool nested_ready = sva_parameter_checker_preflight_(
	    loc, prop, one_probe, one_probe, nullptr,
	    cons.delay_lo_expr, cons.delay_hi_expr, prepared);
      delete one_probe;
      sva_parameter_preflight_discard_(prepared);
      if (!nested_ready) {
	    delete match;
	    return false;
      }

	/* Commit only after the complete endpoint match has been cloned. */
      if (tree_form) {
	    sva_tree_delete_(prop->ante_tree, true);
	    prop->ante_tree = nullptr;
	    prop->tree->chain = nullptr;
	    sva_tree_delete_(prop->tree, true);
	    prop->tree = nullptr;
	    prop->seq = cons_seq;
      } else {
	    pform_sva_destroy_sequence(prop->antecedent);
      }
      prop->antecedent = new std::vector<sva_seq_step_t>;
      sva_seq_step_t repeat;
      repeat.expr = match;
      repeat.rep_kind = 4;
      repeat.rep_hi = 0;
      repeat.rep_lo_expr = new PENumber(new verinum((uint64_t)1, 32));
      FILE_NAME(repeat.rep_lo_expr, loc);
      prop->antecedent->push_back(repeat);

      bool lowered = sva_parameter_repeat_try_assertion_(
	    loc, prop, fail_stmt, pass_stmt, kind);
	/* Every fallible prerequisite was checked before mutation. If a future
	   change adds a new decline path, the normalized property is still
	   self-contained and owns `match`; consume it loudly instead of
	   returning a silently altered property to another engine. */
      if (!lowered) {
	    cerr << loc << ": sorry: a parameter-valued bounded consequence "
		 << "passed checker preflight but could not be committed; the "
		 << "property is dropped rather than falling back with a "
		 << "rewritten antecedent." << endl;
	    error_count += 1;
	    delete fail_stmt;
	    delete pass_stmt;
	    pform_sva_destroy_property(prop);
	    return true;
      }
      return true;
}

/* A generate-loop variable is not a constant while its PGenerate template
 * is parsed, but it becomes an implicit localparam with a different value in
 * every elaborated generate scope.  OpenTitan's prim_arbiter assertions use
 * precisely that rule:
 *
 *   for (genvar n = 1; ...) assert property (a |-> ##n b);
 *
 * Parse-time expansion into `n' scalar pipeline registers would freeze the
 * template's initializer and give every generated instance the same delay.
 * Keep the state shape symbolic instead: a packed [n:0] shift register holds
 * one bit per launch age.  After injecting this tick's antecedent, bit n is
 * the attempt launched exactly n sampled clocks ago.  This represents every
 * overlapping attempt (one may launch on every tick) without a fixed slot
 * pool and lets ordinary generate elaboration resolve n independently in
 * each scope.
 *
 * This focused lowering deliberately accepts only the exact fixed-delay
 * implication shape.  Other uses of a deferred genvar are diagnosed after
 * the normal NFA offer, rather than being misread as one of the negative
 * delay sentinels by the legacy engine. */
static bool sva_genvar_delay_try_assertion_(const struct vlltype&loc,
					     sva_property_t*prop,
					     Statement*fail_stmt,
					     Statement*pass_stmt,
					     int kind)
{
      if (!prop || kind == 2 || prop->op_type != 1
	  || prop->tree || prop->ante_tree || prop->seq_clk_evt
	  || prop->mc_prefix || (prop->mc_more && !prop->mc_more->empty())
	  || prop->mc_boundary != -1 || prop->abort_cond
	  || prop->strength != 0 || prop->forbidden_consequent
	  || prop->win_lo != -1 || prop->win_hi != -1
	  || !prop->antecedent || prop->antecedent->size() != 1
	  || !prop->seq || prop->seq->size() != 1)
	    return false;

      const sva_seq_step_t&ante = (*prop->antecedent)[0];
      const sva_seq_step_t&cons = (*prop->seq)[0];
      if (!ante.expr || ante.delay_lo != 0 || ante.delay_hi != 0
	  || !ante.delay_genvar.nil() || ante.rep_tail != 0
	  || ante.rep_kind != 0 || ante.fm || ante.lv_rhs
	  || !cons.expr || cons.delay_lo != -4 || cons.delay_hi != -4
	  || cons.delay_genvar.nil() || cons.rep_tail != 0
	  || cons.rep_kind != 0 || cons.fm || cons.lv_rhs)
	    return false;

      /* Clock: explicit, else the module's default clocking marker.  The
	 top-level assertion dispatcher has already parked a truly unclocked
	 procedural assertion, so failure here means this is not our shape. */
      PEventStatement*clk = prop->clk_evt;
      if (!clk) {
	    Module*mod = pform_cur_module.empty() ? nullptr
		       : pform_cur_module.front();
	    if (!mod || mod->default_clocking.nil()) return false;
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

      /* ---- Committed: everything below consumes the property. ---- */
      unsigned inst = sva_gensym_counter++;
      unsigned hist_idx = 0;
      std::vector<Statement*> pre, post, init_zero;

      pass_stmt = sva_pass_action_(loc, inst, pass_stmt);
      Statement*fail_action = fail_stmt;
      if (!fail_action) {
	    std::list<named_pexpr_t> no_args;
	    PCallTask*err = new PCallTask(
		  lex_strings.make("$error"), no_args);
	    FILE_NAME(err, loc);
	    fail_action = err;
      }
      fail_action = sva_fail_action_(loc, inst, fail_action);

      PExpr*disable = prop->disable_iff_expr;
      if (!disable && sva_default_disable) {
	    disable = sva_clone_expr_(sva_default_disable);
	    if (!disable) {
		  cerr << loc << ": sorry: the `default disable iff` "
		       << "expression is too complex to copy; this "
		       << "assertion runs without it." << endl;
	    }
      }

      /* Preponed-sample both Boolean operands.  Run the sampled-value
	 rewrite afterwards so $past(..., n) builds its symbolic circular
	 history in this same generated scope. */
      std::map<std::string, pform_name_t> prep_sampled;
      unsigned prep_live_operands = 0;
      auto capture = [&](PExpr*key, unsigned idx) -> perm_string {
	    PExpr*src = key;
	    PExpr*prep = sva_wrap_preponed_(key, prep_sampled,
					     prep_live_operands);
	    if (prep) src = prep;
	    else prep_live_operands += 1;
	    PExpr*be = sva_rewrite_sampled_(loc, src, inst, hist_idx,
					     pre, post, init_zero);
	    perm_string reg = sva_make_reg_(loc, inst, "gb", idx);
	    pre.push_back(sva_assign_(loc, reg, be));
	    return reg;
      };
      perm_string r_ante = capture(ante.expr, 0);
      perm_string r_cons = capture(cons.expr, 1);

      for (std::map<std::string, pform_name_t>::const_iterator it =
		 prep_sampled.begin() ; it != prep_sampled.end() ; ++it)
	    init_zero.push_back(sva_hist_on_stmt_(loc, it->second));
      if (prep_live_operands > 0)
	    cerr << loc << ": warning: this assertion has "
		 << prep_live_operands << " operand(s) that are read live "
		 << "instead of sampled in the Preponed region (IEEE "
		 << "1800-2017 16.5.1); a blocking write to one of them in "
		 << "the clock time slot can be visible to the assertion."
		 << endl;

      perm_string pipe = sva_make_genvar_pipe_(loc, inst,
					       cons.delay_genvar);
      init_zero.push_back(sva_assign_(loc, pipe, sva_bit_(loc, 0)));
      perm_string r_kill = sva_kill_seen_reg_(loc, inst, 0, init_zero);

      std::vector<Statement*> body;
      body.push_back(sva_observed_wait_(loc));
      body.push_back(sva_kill_reset_stmt_(loc, inst, r_kill,
	    sva_assign_(loc, pipe, sva_bit_(loc, 0))));
      body.push_back(sva_if_(loc, sva_enabled_expr_(loc, inst),
			     sva_report_stmt_(loc, inst, SVA_CB_START), nullptr));

      PENumber*one_shift = new PENumber(new verinum((uint64_t)1, 32));
      FILE_NAME(one_shift, loc);
      PEBShift*aged = new PEBShift('l', sva_id_(loc, pipe), one_shift);
      FILE_NAME(aged, loc);
      PEBLogic*start = new PEBLogic(
	    'a', sva_id_(loc, r_ante), sva_enabled_expr_(loc, inst));
      FILE_NAME(start, loc);
      PEBinary*inject = new PEBinary('|', aged, start);
      FILE_NAME(inject, loc);
      body.push_back(sva_assign_(loc, pipe, inject));

      PExpr*due = sva_index_(loc, pipe,
				    sva_id_(loc, cons.delay_genvar));
      Statement*verdict = sva_if_(loc, sva_id_(loc, r_cons),
					 pass_stmt, fail_action);
      body.push_back(sva_if_(loc, due, verdict, nullptr));

      std::vector<Statement*> full = pre;
      Statement*core = sva_block_(loc, body);
      if (disable) {
	    Statement*clear = sva_assign_(loc, pipe, sva_bit_(loc, 0));
	    PCondit*dc = new PCondit(disable, clear, core);
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

      PENumber*one_depth = new PENumber(new verinum((uint64_t)1, 32));
      FILE_NAME(one_depth, loc);
      PEBinary*depth = new PEBinary('+',
				    sva_id_(loc, cons.delay_genvar), one_depth);
      FILE_NAME(depth, loc);
      init_zero.push_back(sva_register_stmt_(loc, inst, -1, true, depth));
      PProcess*ip = pform_make_behavior(IVL_PR_INITIAL,
					sva_block_(loc, init_zero), nullptr);
      FILE_NAME(ip, loc);

      /* Expressions now belong to the synthesized assignments.  Match the
	 other assertion engines' shallow vector cleanup. */
      delete prop->antecedent;
      delete prop->seq;
      delete prop;
      return true;
}

/* Lower one concurrent assertion (assert/assume/cover property) to a
   synthesized clocked checker. kind: 0=assert, 1=assume, 2=cover. */
void pform_make_assertion(const struct vlltype&loc, sva_property_t*prop,
			  Statement*fail_stmt, Statement*pass_stmt, int kind,
			  perm_string label)
{
      pform_generated_verification_scope_t verification_scope;
      sva_assertion_label_scope_t assertion_label_scope(label);

	/* `else ;' is an explicit null failure action, whereas a null
	   fail_stmt pointer means there was no else arm and requests the LRM
	   default $error action. parse.y carries the former as a PNoop sentinel.
	   A bare PNoop cannot reach statement elaboration, so consume it here
	   into an empty block. Keeping that block non-null preserves the
	   distinction through procedural-clock parking, named-property
	   expansion, and every specialized assertion lowering. */
      if (dynamic_cast<PNoop*>(fail_stmt)) {
	    delete fail_stmt;
	    PBlock*empty = new PBlock(PBlock::BL_SEQ);
	    FILE_NAME(empty, loc);
	    fail_stmt = empty;
      }

	/* M9-10: no explicit clock and no default clocking -- park it and
	   let an enclosing procedural event control supply the clock
	   (16.14.6). See pform_sva_infer_procedural_clock. */
      if (prop && !prop->clk_evt && !sva_prop_is_named_ref_(prop)) {
	    Module*mod = pform_cur_module.empty() ? nullptr
			 : pform_cur_module.front();
	    if (!mod || mod->default_clocking.nil()) {
		  sva_pending_proc_t pend;
		  pend.loc = loc;
		  pend.prop = prop;
		  pend.fail_stmt = fail_stmt;
		  pend.pass_stmt = pass_stmt;
		  pend.kind = kind;
		  pend.label = sva_active_assertion_label_;
		  sva_pending_proc_.push_back(pend);
		  return;
	    }
      }

      /* Synthesize into the nearest non-block scope; see
	   sva_hoist_out_of_block_t. */
      sva_hoist_out_of_block_t sva_scope_guard;

      /* Catch directly visible 16.11 calls before any specialized property
	 engine can consume their surrounding sequence while ignoring the
	 action. A named reference is checked again after its body is exposed. */
      if (sva_validate_match_items_(loc, prop, kind) < 0) {
	    delete fail_stmt;
	    delete pass_stmt;
	    pform_sva_destroy_property(prop);
	    return;
      }

	/* Parameter-valued repetition must commit before the generic
	   variable-antecedent promotion below: that promotion deliberately
	   erases the flat-chain shape and builds a parse-time NFA tree, while
	   this path defers the bound to ordinary instance elaboration. */
      if (sva_parameter_repeat_try_assertion_(loc, prop, fail_stmt,
					       pass_stmt, kind))
	    return;

	/* A symbolic bounded consequence behind an otherwise fixed antecedent
	   uses the same per-instance window engine. This also handles an
	   equal-span sequence OR/AND antecedent before generic tree dispatch. */
      if (sva_parameter_window_try_assertion_(loc, prop, fail_stmt,
					       pass_stmt, kind))
	    return;

	/* The general bounded-window probe may splice a named antecedent while
	   checking whether it has a fixed endpoint. That can expose a supported
	   parameter-valued repetition which was hidden from the first offer. */
      if (sva_parameter_repeat_try_assertion_(loc, prop, fail_stmt,
					       pass_stmt, kind))
	    return;

	/* A variable-length implication antecedent is a regular sequence,
	   but it cannot use the legacy flat implication bookkeeping (there
	   is no single fixed completion offset). Promote both operands to
	   trees so the NFA fan-out path can preserve every match endpoint. */
      if (prop && !prop->tree && !prop->ante_tree
	  && (prop->op_type == 1 || prop->op_type == 2)
	  && !prop->seq_clk_evt && prop->antecedent && prop->seq) {
	    bool parameter_repeat = false;
	    for (size_t idx = 0 ; idx < prop->antecedent->size() ; idx += 1)
		  if ((*prop->antecedent)[idx].rep_kind == 4)
			parameter_repeat = true;
	    long edge_span = 0, delay_sum = 0;
	    if (!sva_nfa_chain_fixed_(*prop->antecedent,
				      edge_span, delay_sum)
		&& !sva_nfa_unique_wait_implication_(
			*prop->antecedent, *prop->seq, prop->op_type)) {
		  prop->ante_tree = sva_chain_take_tree_(prop->antecedent);
		  prop->antecedent = nullptr;
		  prop->tree = sva_chain_take_tree_(prop->seq);
		  prop->seq = nullptr;
		  if (parameter_repeat) prop->tree_sorry = 5;
	    }
      }

	/* Stage B combinator trees (sequence or/and): only the
	   automaton engine lowers these — everything below assumes
	   the chain members. */
      if (prop && prop->tree) {
	    if (kind == 2 && pass_stmt) {
		  cerr << loc << ": warning: the pass statement of this "
		       << "`cover property' is not executed (recorded "
		       << "corner); it is dropped. The match counter "
		       << "still counts." << endl;
		  delete pass_stmt;
		  pass_stmt = nullptr;
	    }
	      /* The endpoint-method (.triggered/.matched) lowering must
	         also cover combinator-tree leaf chains -- the tree
	         dispatch used to bypass it, leaving the references
	         unresolved and the assertion silently wrong
	         (recovery C5). */
	    if ((prop->ante_tree
		 && !sva_lower_endpoint_methods_tree_(loc, prop->ante_tree))
		|| !sva_lower_endpoint_methods_tree_(loc, prop->tree)) {
		  sva_tree_delete_(prop->ante_tree, true);
		  prop->ante_tree = nullptr;
		  sva_tree_delete_(prop->tree, true);
		  prop->tree = nullptr;
		  delete prop->clk_evt;
		  delete prop->disable_iff_expr;
		  delete prop;
		  delete fail_stmt;
		  delete pass_stmt;
		  return;
	    }
	    if (pform_sva_nfa_enabled()
		&& pform_sva_nfa_try_assertion(loc, prop, fail_stmt,
					       pass_stmt, kind))
		  return;
	    if (prop->tree_sorry == 1)
		  cerr << loc << ": sorry: `intersect' is supported "
		       << "only over fixed-length sequences (constant ##N "
		       << "delays, no ##[m:n]/##[m:$]/[*m:n]); the assertion "
		       << "is dropped." << endl;
	    else if (prop->tree_sorry == 2)
		  cerr << loc << ": sorry: `within' is supported only over "
		       << "fixed-length sequences (constant ##N delays, no "
		       << "##[m:n]/##[m:$]/[*m:n]); the assertion is dropped."
		       << endl;
	    else if (prop->tree_sorry == 3)
		  cerr << loc << ": sorry: `throughout' over a variable-"
		       << "length sequence "
		       << (pform_sva_nfa_enabled()
			   ? "is not supported by the automaton engine in "
			     "this shape yet"
			   : "requires the automaton engine (unset "
			     "IVL_SVA_LEGACY)")
		       << "; the assertion is dropped." << endl;
	    else if (prop->tree_sorry == 4)
		  cerr << loc << ": sorry: this `first_match' shape is not "
		       << "supported by the automaton engine yet; the "
		       << "assertion is dropped." << endl;
	    else if (prop->tree_sorry == 5)
		  cerr << loc << ": sorry: this parameter-valued consecutive "
		       << "repetition composition is not supported by the "
		       << "instance-elaborated assertion engine yet; the "
		       << "assertion is dropped rather than using the parameter "
		       << "declaration default." << endl;
	    else if (prop->tree_sorry == 6)
		  cerr << loc << ": sorry: an NFA implication local-variable "
		       << "assignment must occur exactly once on a deterministic "
		       << "leaf prefix; branch-local, post-branch, repeated, and "
		       << "duplicate assignments require per-path local state and the "
		       << "assertion is dropped." << endl;
	    else if (prop->tree_sorry == 7)
		  cerr << loc << ": sorry: an NFA implication local-variable "
		       << "assignment followed by a zero-inclusive continuation "
		       << "read requires "
		       << "assignment-before-read scheduling; the assertion is "
		       << "dropped." << endl;
	    else if (prop->tree_sorry == 8)
		  cerr << loc << ": sorry: an NFA implication dependent local-"
		       << "variable assignment RHS must read only an earlier "
		       << "deterministic-prefix local through a structurally "
		       << "supported expression; the assertion is dropped." << endl;
	    else if (prop->tree_sorry == 9)
		  cerr << loc << ": sorry: an NFA implication dependent local-"
		       << "variable assignment RHS reads a declared property local "
		       << "before it is assigned on the deterministic prefix; the "
		       << "assertion is dropped." << endl;
	    else
		  cerr << loc << ": sorry: sequence `or'/`and' "
		       << (pform_sva_nfa_enabled()
			   ? "is not supported by the automaton engine in "
			     "this shape yet"
			   : "requires the automaton engine (unset "
			     "IVL_SVA_LEGACY)")
		       << "; the assertion is dropped." << endl;
	    error_count += 1;
	    sva_tree_delete_(prop->ante_tree, true);
	    prop->ante_tree = nullptr;
	    sva_tree_delete_(prop->tree, true);
	    prop->tree = nullptr;
	    delete prop->clk_evt;
	    delete prop->disable_iff_expr;
	    delete prop;
	    delete fail_stmt;
	    delete pass_stmt;
	    return;
      }
      if (!prop || !prop->seq || prop->seq->empty()) {
	    delete fail_stmt;
	    delete pass_stmt;
	    return;
      }

	/* Named property instantiation: `assert property (p);` where p
	   is a declared no-argument property of this module. */
      if (prop->op_type == 0 && prop->seq->size() == 1
	  && !prop->seq_clk_evt && !prop->mc_prefix
	  && prop->mc_boundary == -1) {
	    if (PEIdent*id = dynamic_cast<PEIdent*>((*prop->seq)[0].expr)) {
		  if (!id->path().package && id->path().name.size() == 1
		      && id->path().name.front().index.empty()) {
			std::map<sva_scoped_name_t, sva_property_t*>::iterator pit =
			      sva_resolve_(sva_module_properties, id->path().name.front().name);
			if (pit != sva_module_properties.end() && !pit->second) {
			        /* The declaration existed but was consumed by a
			           prior instantiation of a shape we cannot clone
			           yet. The old behavior fell through to plain
			           identifier resolution and the assertion went
			           SILENTLY dead (recovery C5). */
			      cerr << loc << ": sorry: named property `"
				   << id->path().name.front().name
				   << "' uses a form that supports only one"
				   << " instantiation; this additional assertion"
				   << " is dropped." << endl;
			      error_count += 1;
			      delete id;
			      delete prop->seq;
			      delete prop;
			      delete fail_stmt;
			      delete pass_stmt;
			      return;
			}
			if (pit != sva_module_properties.end() && pit->second) {
			      sva_property_t*named = pit->second;
			      PEventStatement*outer_clk = prop->clk_evt;
			      prop->clk_evt = nullptr;
			      PExpr*outer_disable = prop->disable_iff_expr;
			      prop->disable_iff_expr = nullptr;
			      bool has_outer_context = outer_clk || outer_disable;
			        /* Deep-clone the declaration per instantiation
			           (recovery C5): the old transfer-and-null
			           "consume once" made every SECOND assert of
			           the same named property an unresolved
			           reference -- silently dead on the automaton
			           engine, constantly-true on the legacy one.
			           Mirrors the parameterized-property path with
			           an empty substitution. Shapes without a clone
			           recipe (combinator trees, multiclock chains)
			           keep transfer semantics; their re-use is the
			           loud refusal above instead of silence. */
			      sva_property_t*inst = nullptr;
			      if (named->tree
				  || (named->mc_more && !named->mc_more->empty())) {
				    inst = named;
				    pit->second = nullptr;  /* consume once */
				    if (outer_clk && inst->clk_evt) {
					  cerr << loc << ": sorry: a named property with "
					       << "its own leading clock cannot also be "
					       << "instantiated under another explicit "
					       << "clock yet; the assertion is dropped."
					       << endl;
					  error_count += 1;
					  delete outer_clk;
					  delete outer_disable;
					  delete id;
					  delete prop->seq;
					  delete prop;
					  delete fail_stmt;
					  delete pass_stmt;
					  return;
				    }
				    if (outer_clk) inst->clk_evt = outer_clk;
				    if (outer_disable) {
					  if (inst->disable_iff_expr) {
						PEBLogic*both = new PEBLogic(
						      'o', outer_disable,
						      inst->disable_iff_expr);
						FILE_NAME(both, loc);
						inst->disable_iff_expr = both;
					  } else {
						inst->disable_iff_expr = outer_disable;
					  }
				    }
			      } else {
				    std::map<perm_string,PExpr*> subst;
				    bool ok = true;
				    inst = new sva_property_t;
				    inst->local_names = named->local_names;
				    inst->op_type = named->op_type;
				    inst->mc_boundary = named->mc_boundary;
				    inst->strength = named->strength;
				    inst->forbidden_consequent =
					  named->forbidden_consequent;
				    inst->win_lo = named->win_lo;
				    inst->win_hi = named->win_hi;
				    inst->tree_sorry = named->tree_sorry;
				    inst->clk_evt = outer_clk;
				    outer_clk = nullptr;
				    inst->disable_iff_expr = outer_disable;
				    outer_disable = nullptr;
				    if (named->clk_evt) {
					  if (inst->clk_evt) {
						cerr << loc << ": sorry: a named property with "
						     << "its own leading clock cannot also be "
						     << "instantiated under another explicit "
						     << "clock yet; the assertion is dropped."
						     << endl;
						error_count += 1;
						ok = false;
					  } else {
						inst->clk_evt = sva_clone_event_control_(
						      named->clk_evt, loc, &subst);
						if (!inst->clk_evt) ok = false;
					  }
				    }
				    if (ok && named->seq_clk_evt) {
					  inst->seq_clk_evt = sva_clone_event_control_(
						named->seq_clk_evt, loc, &subst);
					  if (!inst->seq_clk_evt) ok = false;
				    }
				    if (ok && named->disable_iff_expr) {
					  PExpr*dd = sva_clone_subst_(
						named->disable_iff_expr, &subst);
					  if (!dd) {
						ok = false;
					  } else if (inst->disable_iff_expr) {
						PEBLogic*both = new PEBLogic(
						      'o', inst->disable_iff_expr, dd);
						FILE_NAME(both, loc);
						inst->disable_iff_expr = both;
					  } else {
						inst->disable_iff_expr = dd;
					  }
				    }
				    if (ok && named->abort_cond) {
					  inst->abort_cond = sva_clone_subst_(
						named->abort_cond, &subst);
					  if (!inst->abort_cond) ok = false;
				    }
				    if (ok && named->seq) {
					  inst->seq = sva_clone_steps_subst_(
						loc, named->seq, subst);
					  if (!inst->seq) ok = false;
				    }
				    if (ok && named->antecedent) {
					  inst->antecedent = sva_clone_steps_subst_(
						loc, named->antecedent, subst);
					  if (!inst->antecedent) ok = false;
				    }
				    if (ok && named->mc_prefix) {
					  inst->mc_prefix = sva_clone_steps_subst_(
						loc, named->mc_prefix, subst);
					  if (!inst->mc_prefix) ok = false;
				    }
				    if (!ok) {
					  pform_sva_destroy_property(inst);
					  if (has_outer_context) {
						/* The contextual clock/disable was owned by
						   the failed clone. Do not silently discard it
						   by falling back to transfer semantics. */
						inst = nullptr;
					  } else {
						/* Preserve the historical first-use transfer
						   fallback for an uncontextualized property. */
						inst = named;
						pit->second = nullptr;
					  }
				    }
			      }
			      delete id;
			      delete prop->seq;
			      delete prop;
			      if (!inst) {
				    delete fail_stmt;
				    delete pass_stmt;
				    return;
			      }
			      pform_make_assertion(loc, inst, fail_stmt,
						   pass_stmt, kind);
			      return;
			}
		  }
	    }
      }

	/* M9D: parameterized property instantiation `p(a,b)'. Leading and
	   clock-flow events in the declaration body are cloned with formal
	   substitution; an assertion-site clock supplies the context only
	   when the declaration does not already carry one. */
      if (prop->op_type == 0 && prop->seq->size() == 1
	  && !prop->seq_clk_evt && !prop->mc_prefix
	  && prop->mc_boundary == -1
	  && (*prop->seq)[0].delay_lo == 0 && (*prop->seq)[0].delay_hi == 0
	  && (*prop->seq)[0].rep_tail == 0) {
	    if (PECallFunction*cf = dynamic_cast<PECallFunction*>((*prop->seq)[0].expr)) {
		  if (!cf->path().package && cf->path().name.size() == 1) {
			perm_string nm = peek_tail_name(cf->path().name);
			std::map<sva_scoped_name_t, sva_param_prop_t>::iterator pit =
			      sva_resolve_(sva_param_properties, nm);
			if (pit != sva_param_properties.end() && pit->second.body) {
			      sva_property_t*decl = pit->second.body;
			      bool fatal = false;
			      if (!fatal && decl->mc_more && !decl->mc_more->empty()) {
				    cerr << loc << ": sorry: a parameterized "
					 << "property with more than one "
					 << "clock-flow change in its body is not "
					 << "supported (IEEE 1800-2017 16.13.1); "
					 << "write the assertion directly instead "
					 << "of through `" << nm << "'." << endl;
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
				    inst->local_names = decl->local_names;
				    inst->op_type = decl->op_type;
				    inst->mc_boundary = decl->mc_boundary;
				    inst->strength = decl->strength;
				    inst->forbidden_consequent =
					  decl->forbidden_consequent;
				    inst->win_lo = decl->win_lo;
				    inst->win_hi = decl->win_hi;
				    bool ok = true;
				    inst->clk_evt = prop->clk_evt;
				    prop->clk_evt = nullptr;
				    inst->disable_iff_expr = prop->disable_iff_expr;
				    prop->disable_iff_expr = nullptr;
				    if (decl->clk_evt) {
					  if (inst->clk_evt) {
						cerr << loc << ": sorry: parameterized property `"
						     << nm << "' has a leading clock and cannot "
						     << "also be instantiated under another "
						     << "explicit clock yet; the assertion is "
						     << "dropped." << endl;
						error_count += 1;
						ok = false;
					  } else {
						inst->clk_evt = sva_clone_event_control_(
						      decl->clk_evt, loc, &subst);
						if (!inst->clk_evt) ok = false;
					  }
				    }
				    if (ok && decl->seq_clk_evt) {
					  inst->seq_clk_evt = sva_clone_event_control_(
						decl->seq_clk_evt, loc, &subst);
					  if (!inst->seq_clk_evt) ok = false;
				    }
				    if (ok && decl->disable_iff_expr) {
					  PExpr*dd = sva_clone_subst_(
						decl->disable_iff_expr, &subst);
					  if (!dd) {
						ok = false;
					  } else if (inst->disable_iff_expr) {
						PEBLogic*both = new PEBLogic(
						      'o', inst->disable_iff_expr, dd);
						FILE_NAME(both, loc);
						inst->disable_iff_expr = both;
					  } else {
						inst->disable_iff_expr = dd;
					  }
				    }
				    if (ok && decl->abort_cond) {
					  inst->abort_cond = sva_clone_subst_(
						decl->abort_cond, &subst);
					  if (!inst->abort_cond) ok = false;
				    }
				    if (decl->seq) {
					  inst->seq = sva_clone_steps_subst_(loc, decl->seq, subst);
					  if (!inst->seq) ok = false;
				    }
				    if (ok && decl->antecedent) {
					  inst->antecedent = sva_clone_steps_subst_(loc, decl->antecedent, subst);
					  if (!inst->antecedent) ok = false;
				    }
				    if (ok && decl->mc_prefix) {
					  inst->mc_prefix = sva_clone_steps_subst_(
						loc, decl->mc_prefix, subst);
					  if (!inst->mc_prefix) ok = false;
				    }
				    if (!ok) {
					  cerr << loc << ": sorry: property `" << nm
					       << "' has a body expression that cannot "
					       << "be instantiated with arguments; the "
					       << "assertion is dropped." << endl;
					  error_count += 1;
					  pform_sva_destroy_property(inst);
					  inst = nullptr;
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

	/* M9-NFA stage D.1: a multiclocked implication (consequent carries
	   its own clocking event) is lowered by a dedicated two-domain
	   request/ack handoff. M9-7 residual: more than one clock-flow
	   change in the same sequence (`@(c1) a ##1 @(c2) b ##1 @(c3) c')
	   generalizes that handoff to an N-domain chain instead. */
      if (prop->seq_clk_evt) {
	    if (prop->mc_more && !prop->mc_more->empty())
		  pform_make_multiclock_chain_assertion_(loc, prop, fail_stmt,
							 pass_stmt, kind);
	    else
		  pform_make_multiclock_assertion_(loc, prop, fail_stmt, pass_stmt, kind);
	    return;
      }

	/* M9-NFA (Phase 2, staged): when IVL_SVA_NFA=1, offer the
	   assertion to the automaton engine first. It returns true
	   only when it fully lowered the assertion; false means fall
	   through to the legacy linear engine below. */
	/* Neither engine executes a `cover property' pass statement
	   (the legacy engine keeps only the match counter; the NFA
	   engine matches it for parity). Dropping one SILENTLY would
	   hide that — warn loudly. Shared here so both engines behave
	   identically. */
      if (kind == 2 && pass_stmt && prop->op_type != 3) {
	    cerr << loc << ": warning: the pass statement of this "
		 << "`cover property' is not executed (recorded corner); "
		 << "it is dropped. The match counter still counts."
		 << endl;
	    delete pass_stmt;
	    pass_stmt = nullptr;
      }

	/* M9-NFA LV-1/LV-2: lower sequence local variables now, before
	   EITHER engine. Fixed-delay reads become $past (both engines);
	   variable-delay reads are left on the steps for the automaton
	   engine's per-slot storage (code 2). */
      sva_splice_sequences_(loc, *prop->seq);
      if (prop->antecedent)
	    sva_splice_sequences_(loc, *prop->antecedent);

      /* Named sequence calls become visible only after splicing. This is
	 intentionally the same validator, so every unsupported shape emits one
	 stable diagnostic whether written inline or through a declaration. */
      int match_item_state = sva_validate_match_items_(loc, prop, kind);
      if (match_item_state < 0) {
	    delete fail_stmt;
	    delete pass_stmt;
	    pform_sva_destroy_property(prop);
	    return;
      }

	/* A parameter-valued repetition can be hidden inside a named
	   antecedent sequence. The first offer near function entry necessarily
	   runs before that reference is expanded; offer the now-spliced shape
	   once more before the generic NFA sees rep_kind 4. */
      if (sva_parameter_repeat_try_assertion_(loc, prop, fail_stmt,
					       pass_stmt, kind))
	    return;

	/* M9-NFA stage C.3: lower `seq.triggered'/`seq.matched' endpoint
	   methods to their fixed-length $past match indicator (both engines
	   handle the resulting boolean). Unsupported endpoints are a loud
	   sorry with full cleanup. */
      if (!sva_lower_endpoint_methods_(loc, *prop->seq)
	  || (prop->antecedent
	      && !sva_lower_endpoint_methods_(loc, *prop->antecedent))) {
	    delete fail_stmt; delete pass_stmt;
	    delete prop->antecedent; delete prop->seq;
	    delete prop->clk_evt; delete prop->disable_iff_expr;
	    delete prop;
	    return;
      }

	/* first_match: the composed multi-length case (a first_match whose
	   variable-length match feeds a continuation) cannot ride the
	   transparent lowering without silently over-matching. Expand it
	   into a disjoint `or' of fixed-length branches whose earliest-
	   match cut is encoded by `!awaited' guards (exact first_match
	   semantics), then re-dispatch as a combinator tree. That tree is
	   automaton-only, so only attempt the rewrite when the NFA engine
	   is available; otherwise it stays a loud sorry. */
      {
	    bool seq_bad = !sva_check_first_match_(loc, *prop->seq, false);
	    bool ante_bad = prop->antecedent
			    && !sva_check_first_match_(loc, *prop->antecedent, true);
	    if (seq_bad || ante_bad) {
		  sva_stree_t*fm_tree = nullptr;
		  if (pform_sva_nfa_enabled() && !ante_bad
		      && prop->op_type == 0 && !prop->antecedent)
			fm_tree = sva_expand_first_match_(loc, *prop->seq);
		  if (fm_tree) {
			delete prop->seq;
			prop->seq = nullptr;
			prop->tree = fm_tree;
			prop->tree_sorry = 4;
			pform_make_assertion(loc, prop, fail_stmt, pass_stmt, kind);
			return;
		  }
		  cerr << loc << ": sorry: `first_match' of a variable-length "
		       << "sequence that feeds a continuation "
		       << (pform_sva_nfa_enabled()
			   ? "is not supported by the automaton engine in "
			     "this shape yet"
			   : "requires the automaton engine (unset "
			     "IVL_SVA_LEGACY)")
		       << "; the assertion is dropped." << endl;
		  error_count += 1;
		  delete fail_stmt; delete pass_stmt;
		  delete prop->antecedent; delete prop->seq;
		  delete prop->clk_evt; delete prop->disable_iff_expr;
		  delete prop;
		  return;
	    }
      }

	/* A local variable in an IMPLICATION is typically assigned in the
	   antecedent and read in the consequent — two separate chains
	   here, so the $past transform cannot connect them. Route the
	   whole property to the automaton engine, which combines
	   antecedent++consequent into one chain and gives each attempt a
	   per-slot copy. Plain sequences are self-contained: the transform
	   handles fixed delays ($past) and leaves variable delays for the
	   slot path (code 2). */
      bool prop_has_lv = false;
      for (size_t si = 0 ; si < prop->seq->size() ; si += 1)
	    if ((*prop->seq)[si].lv_rhs) prop_has_lv = true;
      if (prop->antecedent)
	    for (size_t si = 0 ; si < prop->antecedent->size() ; si += 1)
		  if ((*prop->antecedent)[si].lv_rhs) prop_has_lv = true;
      bool impl_lv = prop_has_lv
		     && (prop->op_type == 1 || prop->op_type == 2);
      bool slot_lv = impl_lv;
      if (!impl_lv) {
	    int lv_s = sva_lower_local_vars_(loc, *prop->seq);
	    int lv_a = prop->antecedent
		       ? sva_lower_local_vars_(loc, *prop->antecedent) : 0;
	    if (lv_s == 1 || lv_a == 1) {
		  delete fail_stmt;
		  delete pass_stmt;
		  pform_sva_destroy_property(prop);
		  return;
	    }
	    slot_lv = (lv_s == 2 || lv_a == 2);
      }
      if (slot_lv && !pform_sva_nfa_enabled()) {
	    cerr << loc << ": sorry: a local variable across a variable-"
		 << "length delay (##[m:n]/##[m:$]/[*m:n]) requires the "
		 << "automaton engine (compile with IVL_SVA_NFA=1 in the "
		 << "environment); the assertion is dropped." << endl;
	    error_count += 1;
	    delete fail_stmt; delete pass_stmt;
	    delete prop->antecedent; delete prop->seq;
	    delete prop->clk_evt; delete prop->disable_iff_expr;
	    delete prop;
	    return;
      }

      if (sva_genvar_delay_try_assertion_(loc, prop, fail_stmt,
					  pass_stmt, kind))
	    return;

      /* The automaton engine is essential for nondeterministic/branching
	 shapes, but synthesizing an attempt pool for every fixed Boolean chain
	 multiplies memory on assertion-dense SoCs. Keep deterministic fixed
	 chains on the linear pipeline and reserve NFA storage for constructs the
	 linear engine cannot represent. */
      bool flat_needs_nfa = slot_lv || match_item_state == 1
			 || prop->strength == 1 || prop->forbidden_consequent;
      auto scan_nfa_only = [&](const std::vector<sva_seq_step_t>*steps,
				 bool antecedent) {
	    if (!steps) return;
	    for (size_t si = 0 ; si < steps->size() ; si += 1) {
		  const sva_seq_step_t&st = (*steps)[si];
		  bool last = si + 1 == steps->size();
		  if (st.rep_kind != 0 || st.fm)
			flat_needs_nfa = true;
		  if (antecedent && (st.delay_lo < 0
			|| st.delay_lo != st.delay_hi || st.rep_tail != 0))
			flat_needs_nfa = true;
		  if (!antecedent && !last
		      && (st.delay_lo < 0 || st.delay_lo != st.delay_hi
			  || st.rep_tail != 0))
			flat_needs_nfa = true;
	    }
      };
      scan_nfa_only(prop->antecedent, true);
      scan_nfa_only(prop->seq, false);

      if (flat_needs_nfa && pform_sva_nfa_enabled()
	  && pform_sva_nfa_try_assertion(loc, prop, fail_stmt, pass_stmt, kind))
	    return;

      /* A validated match item has no legacy lowering. Any automaton
	 preflight/build refusal must therefore terminate with one stable,
	 targeted diagnostic; falling through would silently discard the call. */
      if (match_item_state == 1) {
	    sva_match_item_sorry_(loc,
		  "could not be represented by the sampled automaton action path");
	    delete fail_stmt;
	    delete pass_stmt;
	    pform_sva_destroy_property(prop);
	    return;
      }

	/* A deferred generate-local delay is a distinct sentinel, not an
	 invalid literal or a repetition marker.  Only the focused implication
	 lowering above currently models it.  Refuse every other shape loudly
	 before |=> adjustment or legacy offset arithmetic can reinterpret -4. */
      bool has_parameter_delay = false;
      for (size_t si = 0 ; si < prop->seq->size() ; si += 1)
	    if ((*prop->seq)[si].delay_lo == -5) has_parameter_delay = true;
      if (prop->antecedent)
	    for (size_t si = 0 ; si < prop->antecedent->size() ; si += 1)
		  if ((*prop->antecedent)[si].delay_lo == -5)
			has_parameter_delay = true;
      if (has_parameter_delay) {
	    cerr << loc << ": sorry: this parameter-valued bounded cycle-delay "
		 << "composition is not supported by the instance-elaborated "
		 << "assertion engine yet; the assertion is dropped rather than "
		 << "using the parameter declaration default." << endl;
	    error_count += 1;
	    delete fail_stmt;
	    delete pass_stmt;
	    pform_sva_destroy_property(prop);
	    return;
      }

      bool has_genvar_delay = false;
      for (size_t si = 0 ; si < prop->seq->size() ; si += 1)
	    if ((*prop->seq)[si].delay_lo == -4) has_genvar_delay = true;
      if (prop->antecedent)
	    for (size_t si = 0 ; si < prop->antecedent->size() ; si += 1)
		  if ((*prop->antecedent)[si].delay_lo == -4)
			has_genvar_delay = true;
      if (has_genvar_delay) {
	    cerr << loc << ": sorry: a generate-local cycle delay is currently "
		 << "supported only for a Boolean overlapped implication of "
		 << "the form `antecedent |-> ##genvar consequent`; the "
		 << "assertion is dropped." << endl;
	    error_count += 1;
	    delete fail_stmt;
	    delete pass_stmt;
	    pform_sva_destroy_property(prop);
	    return;
      }

	/* A symbolic consecutive repetition uses the internal rep_kind 4
	   sentinel. It is not goto/nonconsecutive repetition, and suggesting
	   that engine would misidentify both the syntax and the missing
	   capability. Only the focused instance-sized paths above may consume
	   it; every other composition remains a loud refusal. */
      bool has_parameter_repeat = false;
      bool has_rep_kind = false;
      for (size_t si = 0 ; si < prop->seq->size() ; si += 1) {
	    if ((*prop->seq)[si].rep_kind == 4)
		  has_parameter_repeat = true;
	    else if ((*prop->seq)[si].rep_kind != 0)
		  has_rep_kind = true;
      }
      if (prop->antecedent) {
	    for (size_t si = 0 ; si < prop->antecedent->size() ; si += 1) {
		  if ((*prop->antecedent)[si].rep_kind == 4)
			has_parameter_repeat = true;
		  else if ((*prop->antecedent)[si].rep_kind != 0)
			has_rep_kind = true;
	    }
      }
      if (has_parameter_repeat) {
	    cerr << loc << ": sorry: this parameter-valued consecutive "
		 << "repetition composition is not supported by the "
		 << "instance-elaborated assertion engine yet; the property "
		 << "is dropped rather than using the parameter declaration "
		 << "default." << endl;
	    error_count += 1;
	    delete fail_stmt;
	    delete pass_stmt;
	    pform_sva_destroy_property(prop);
	    return;
      }

	/* M9-NFA stage C.1: goto/nonconsecutive repetition (`b[->m:n]',
	   `b[=m:n]') is an automaton-only construct. If we reach here with a
	   remaining rep_kind step — the NFA engine is off, or it declined the
	   shape — the legacy engine has no such counting loop and would
	   silently drop it; diagnose loudly instead. */
      if (has_rep_kind) {
	      /* C5-2: name the true blocker. When the automaton engine is
	         already active (the default), it DECLINED this shape --
	         advising the user to enable it was misleading. */
	    if (pform_sva_nfa_enabled())
		  cerr << loc << ": sorry: this goto (`[->m:n]') / "
		       << "nonconsecutive (`[=m:n]') repetition shape is "
		       << "not supported by the automaton engine yet; the "
		       << "assertion is dropped." << endl;
	    else
		  cerr << loc << ": sorry: SVA goto (`[->m:n]') / "
		       << "nonconsecutive (`[=m:n]') repetition requires "
		       << "the automaton engine (unset IVL_SVA_LEGACY); "
		       << "the assertion is dropped." << endl;
	    error_count += 1;
	    delete fail_stmt; delete pass_stmt;
	    delete prop->antecedent; delete prop->seq;
	    delete prop->clk_evt; delete prop->disable_iff_expr;
	    delete prop;
	    return;
      }

	/* M9-NFA stage C.2: a `strong(seq)' sequence property carries an
	   end-of-simulation obligation the legacy engine cannot express —
	   it would silently lower `strong(seq)' as a plain (weak) sequence,
	   dropping the obligation. If we reach here with strength==1 (NFA
	   off, or it declined the shape), diagnose loudly. (`weak(seq)' is
	   the default and lowers on either engine identically.) */
      if (prop->strength == 1) {
	    if (pform_sva_nfa_enabled())
		  cerr << loc << ": sorry: this `strong(...)' sequence "
		       << "property shape is not supported by the automaton "
		       << "engine yet; the assertion is dropped." << endl;
	    else
		  cerr << loc << ": sorry: `strong(...)' sequence properties "
		       << "require the automaton engine (unset "
		       << "IVL_SVA_LEGACY); the assertion is dropped." << endl;
	    error_count += 1;
	    delete fail_stmt; delete pass_stmt;
	    delete prop->antecedent; delete prop->seq;
	    delete prop->clk_evt; delete prop->disable_iff_expr;
	    delete prop;
	    return;
      }

	/* If the automaton engine declined a slot-local-variable
	   assertion, the legacy engine cannot lower it (the reads are
	   unresolved identifiers) — diagnose rather than emit garbage. */
      if (slot_lv) {
	    cerr << loc << ": sorry: this local-variable assertion shape is "
		 << "not supported by the automaton engine yet; the "
		 << "assertion is dropped." << endl;
	    error_count += 1;
	    delete fail_stmt; delete pass_stmt;
	    delete prop->antecedent; delete prop->seq;
	    delete prop->clk_evt; delete prop->disable_iff_expr;
	    delete prop;
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
	      /* Preserve -1, the ##[m:$] unbounded sentinel. Turning it
	         into zero produces an inverted [m+1:0] window and used to
	         synthesize a null condition for OTBN's |=> ##[0:$] checks. */
	    if (seq[0].delay_hi >= 0) seq[0].delay_hi += 1;
      }

	/* Validate the chain shape: constant bounded delays, at most
	   one range, and only on the LAST step. */
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
	    pass_stmt = sva_pass_action_(loc, inst, pass_stmt);
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

	/* Apply the SAME Preponed rewrite used by the automaton engine before
	   binding sampled-value functions.  Besides fixing the legacy engine's
	   live Active-region reads, this is the instance-specialization point
	   for a whole unpacked array whose explicit [L:R] bounds depend on
	   overridable parameters: the aggregate stays symbolic and is lowered to
	   parameter-sized snapshot/history arrays below. */
      std::map<std::string, pform_name_t> prep_sampled;
      unsigned prep_live_operands = 0;
      auto rewrite_guard = [&](PExpr*key) -> PExpr* {
	    PExpr*src = key;
	    PExpr*prep = sva_wrap_preponed_(key, prep_sampled,
					 prep_live_operands);
	    if (prep) src = prep;
	    else prep_live_operands += 1;
	    return sva_rewrite_sampled_(loc, src, inst, hist_idx,
				 pre, post, init_zero);
      };

	/* Rewrite sampled-value functions, then capture every step
	   boolean (and the antecedent) into 1-bit sample registers at
	   the top of the checker. */
      if (ante) {
	    ante = rewrite_guard(ante);
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
		  PExpr*abe = rewrite_guard(ast.expr);
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
	    PExpr*be = rewrite_guard(seq[j].expr);
	    r_b[j] = sva_make_reg_(loc, inst, "b", (unsigned)j);
	    pre.push_back(sva_assign_(loc, r_b[j], be));
      }

      for (std::map<std::string, pform_name_t>::const_iterator it =
		 prep_sampled.begin() ; it != prep_sampled.end() ; ++it)
	    init_zero.push_back(sva_hist_on_stmt_(loc, it->second));
      if (prep_live_operands > 0)
	    cerr << loc << ": warning: this assertion has "
		 << prep_live_operands << " operand(s) that are read live "
		 << "instead of sampled in the Preponed region (IEEE "
		 << "1800-2017 16.5.1); a blocking write to one of them in "
		 << "the clock time slot can be visible to the assertion."
		 << endl;

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
      perm_string r_sp, r_sf;
      if (kind == 2) {
	    r_cnt = sva_make_reg_(loc, inst, "cnt", 0, true);
	    init_zero.push_back(sva_assign_(loc, r_cnt,
			new PENumber(new verinum((uint64_t)0, 32))));
      } else {
	    r_f = sva_make_reg_(loc, inst, "f", 0);
	    init_zero.push_back(sva_assign_(loc, r_f, sva_bit_(loc, 0)));
	    /* The compact linear checker must retain the assertion-step VPI
	       contract that the NFA checker provides. These flags aggregate all
	       attempts that advance or die during one sampled tick. */
	    r_sp = sva_make_reg_(loc, inst, "sp", 0);
	    init_zero.push_back(sva_assign_(loc, r_sp, sva_bit_(loc, 0)));
	    r_sf = sva_make_reg_(loc, inst, "sf", 0);
	    init_zero.push_back(sva_assign_(loc, r_sf, sva_bit_(loc, 0)));
      }
      perm_string r_kill = sva_kill_seen_reg_(loc, inst, 0, init_zero);

      auto clear_attempt_state = [&]() -> Statement* {
	    std::vector<Statement*> clr;
	    for (long p = 0 ; p < P ; p += 1)
		  clr.push_back(sva_assign_(loc, t_regs[p], sva_bit_(loc, 0)));
	    for (long q = 0 ; q < wregs_n ; q += 1)
		  clr.push_back(sva_assign_(loc, w_regs[q], sva_bit_(loc, 0)));
	    if (unbounded)
		  clr.push_back(sva_assign_(loc, r_pend, sva_bit_(loc, 0)));
	    clr.push_back(sva_assign_(loc, r_g, sva_bit_(loc, 0)));
	    if (kind != 2) {
		  clr.push_back(sva_assign_(loc, r_f, sva_bit_(loc, 0)));
		  clr.push_back(sva_assign_(loc, r_sp, sva_bit_(loc, 0)));
		  clr.push_back(sva_assign_(loc, r_sf, sva_bit_(loc, 0)));
	    }
	    return sva_block_(loc, clr);
      };

	/* The per-clock checker body. */
      std::vector<Statement*> body;

	/* g is the current tick's newly launched attempt. Off suppresses only
	   this injection; older pipeline/window tokens continue to mature. */
	body.push_back(sva_assign_(loc, r_g,
	      sva_logic_(loc, 'a', sva_enabled_expr_(loc, inst),
			 sva_id_(loc, r_ante))));
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
	    if (kind != 2)
		  hit.push_back(sva_assign_(loc, r_sf, sva_bit_(loc, 1)));
	    hit.push_back(sva_assign_(loc, r_g, sva_bit_(loc, 0)));
	    PCondit*c = new PCondit(cond, sva_block_(loc, hit), nullptr);
	    FILE_NAME(c, loc);
	    body.push_back(c);
	    if (kind != 2 && j + 1 < seq.size()) {
		  PExpr*advanced = sva_logic_(loc, 'a', sva_id_(loc, r_g),
					 sva_id_(loc, r_b[j]));
		  body.push_back(sva_if_(loc, advanced,
			sva_assign_(loc, r_sp, sva_bit_(loc, 1)), nullptr));
	    }
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
	    if (kind != 2)
		  hit.push_back(sva_assign_(loc, r_sf, sva_bit_(loc, 1)));
	    hit.push_back(sva_assign_(loc, treg, sva_bit_(loc, 0)));
	    PCondit*c = new PCondit(cond, sva_block_(loc, hit), nullptr);
	    FILE_NAME(c, loc);
	    body.push_back(c);
	    if (kind != 2 && j + 1 < seq.size()) {
		  PExpr*advanced = sva_logic_(loc, 'a', sva_id_(loc, treg),
					 sva_id_(loc, r_b[j]));
		  body.push_back(sva_if_(loc, advanced,
			sva_assign_(loc, r_sp, sva_bit_(loc, 1)), nullptr));
	    }
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
	      /* anyW: is any attempt in the eligible window? Keep the
	         reduction balanced so very large legal windows do not create
	         quadratic elaboration or a thousands-deep call stack. */
	    std::vector<PExpr*> anyw_terms;
	    anyw_terms.reserve(win_n - win_m + 1);
	    for (long q = win_m ; q <= win_n ; q += 1)
		  anyw_terms.push_back(sva_id_(loc, w_regs[q]));
	    PExpr*anyw = sva_logic_reduce_(loc, 'o', anyw_terms);
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
		  mhit.push_back(sva_assign_(loc, r_sf, sva_bit_(loc, 1)));
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
	    if (kind != 2) {
		  std::vector<PExpr*> live_window;
		  live_window.reserve(wregs_n);
		  for (long q = 0 ; q < wregs_n ; q += 1)
			live_window.push_back(sva_id_(loc, w_regs[q]));
		  body.push_back(sva_if_(loc,
			sva_logic_reduce_(loc, 'o', live_window),
			sva_assign_(loc, r_sp, sva_bit_(loc, 1)), nullptr));
	    }
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
	    if (kind != 2) {
		  std::vector<PExpr*> live_wait;
		  live_wait.reserve(wregs_n + 1);
		  live_wait.push_back(sva_id_(loc, r_pend));
		  for (long q = 0 ; q < wregs_n ; q += 1)
			live_wait.push_back(sva_id_(loc, w_regs[q]));
		  body.push_back(sva_if_(loc,
			sva_logic_reduce_(loc, 'o', live_wait),
			sva_assign_(loc, r_sp, sva_bit_(loc, 1)), nullptr));
	    }

	      /* End-of-simulation pending report. */
	    if (kind != 2 && !negated) {
		  std::vector<PExpr*> outstanding_terms;
		  outstanding_terms.reserve(win_m + 1);
		  outstanding_terms.push_back(sva_id_(loc, r_pend));
		  for (long q = 0 ; q < win_m ; q += 1)
			outstanding_terms.push_back(sva_id_(loc, w_regs[q]));
		  PExpr*outst = sva_logic_reduce_(loc, 'o', outstanding_terms);
		  outst = sva_logic_(loc, 'a', outst,
			sva_kill_generation_current_(loc, inst, r_kill));
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

	    std::vector<Statement*> sp_hit;
	    sp_hit.push_back(sva_assign_(loc, r_sp, sva_bit_(loc, 0)));
	    sp_hit.push_back(sva_report_stmt_(loc, inst, SVA_CB_STEP_SUCCESS));
	    body.push_back(sva_if_(loc, sva_id_(loc, r_sp),
				   sva_block_(loc, sp_hit), nullptr));

	    std::vector<Statement*> sf_hit;
	    sf_hit.push_back(sva_assign_(loc, r_sf, sva_bit_(loc, 0)));
	    sf_hit.push_back(sva_report_stmt_(loc, inst, SVA_CB_STEP_FAILURE));
	    body.push_back(sva_if_(loc, sva_id_(loc, r_sf),
				   sva_block_(loc, sf_hit), nullptr));
      } else {
	    delete fail_stmt;
      }
	/* Any pass action not consumed by a match site above (cover,
	   negated) is dropped. */
      delete pass_stmt;

	/* M12B-rest: cbAssertionStart -- an attempt starts at every
	   sampled clock tick the checker evaluates (IEEE 1800-2017
	   40.5.2; concurrent assertions launch an attempt each clock).
	   Placed inside the disable guard: a disabled tick aborts
	   attempts rather than starting one. Gated on
	   $ivl_assert_cb_active like every report, so it costs nothing
	   when no callback is registered. */
      body.insert(body.begin(), sva_if_(loc,
	    sva_enabled_expr_(loc, inst),
	    sva_report_stmt_(loc, inst, SVA_CB_START), nullptr));
      body.insert(body.begin(), sva_kill_reset_stmt_(
	    loc, inst, r_kill, clear_attempt_state()));
      body.insert(body.begin(), sva_observed_wait_(loc));

	/* Assemble: pre-captures; disable guard around the token
	   machinery; history updates. */
      std::vector<Statement*> full = pre;
      Statement*core = sva_block_(loc, body);
      if (disable) {
	    PCondit*dc = new PCondit(disable, clear_attempt_state(), core);
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

	/* Zero-initialize the synthesized state, and register a VPI identity.
	   Fixed linear chains have an exact completion latency: include the
	   antecedent history and sequence pipeline so success callbacks (and
	   implication failures) recover the launch tick rather than the verdict
	   tick. Variable final windows retain the explicit unknown marker. */
      long cb_edges = (has_window || unbounded)
	    ? -1 : ante_span + P + 1;
      bool cb_fail_full_latency = prop->op_type == 1 || prop->op_type == 2;
      init_zero.push_back(sva_register_stmt_(loc, inst, cb_edges,
					     cb_fail_full_latency));
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

/* Returns true if the current lexical scope is (or is nested inside) a
 * task or function body. The unnamed-fork scope elision uses this:
 * inside a routine the fork scope must be kept, because (a) in a
 * function it is what distinguishes a deferred task call in a
 * join_any/join_none forked process from an illegal direct call, and
 * (b) the runtime marks a %fork child whose target scope is a task
 * scope as a compiled task call sharing the caller's logical process
 * (vvp/vthread.cc of_FORK), so a real forked process elided into its
 * enclosing task scope would alias process::self() with the caller
 * (breaks the UVM sequencer handshake). */
bool pform_scope_in_routine(void)
{
      for (LexicalScope*cur = lexical_scope; cur; cur = cur->parent_scope()) {
	    if (dynamic_cast<PTaskFunc*>(cur))
		  return true;
      }
      return false;
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
      if (getenv("IVL_PARSE_TRACE")) VLdebug = 1;
      int rc = VLparse();

	/* M9-10: an unclocked assertion outside any module never reaches
	   pform_endmodule, so drain the park list here too. */
      pform_sva_flush_pending_procedural();

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

/* Resolution-function signature checks belong to elaboration, but existence
 * must be checked even when another parse error prevents elaboration from
 * running.  Perform this narrow, name-only pass after every input file has
 * been parsed so a resolver may legally be declared after its nettype. */
static bool pform_nettype_unqualified_name_exists_(LexicalScope*start,
                                                   perm_string name)
{
      for (LexicalScope*scope = start; scope; scope = scope->parent_scope()) {
            if (scope->local_symbols.find(name) != scope->local_symbols.end())
                  return true;

            map<perm_string,PPackage*>::const_iterator explicit_import =
                  scope->explicit_imports.find(name);
            if (explicit_import != scope->explicit_imports.end())
                  return true;

            for (PPackage*pkg : scope->potential_imports)
                  if (pform_package_importable(pkg, name))
                        return true;
      }
      return false;
}

static LexicalScope* pform_nettype_child_scope_(LexicalScope*scope,
                                                perm_string name,
                                                bool&name_exists)
{
      name_exists = false;
      if (!scope)
            return nullptr;

      if (PScopeExtra*scopex = dynamic_cast<PScopeExtra*>(scope)) {
            map<perm_string,PClass*>::const_iterator cls =
                  scopex->classes.find(name);
            if (cls != scopex->classes.end()) {
                  name_exists = true;
                  return cls->second;
            }
      }

      map<perm_string,PNamedItem*>::const_iterator symbol =
            scope->local_symbols.find(name);
      if (symbol == scope->local_symbols.end())
            return nullptr;

      name_exists = true;
      return dynamic_cast<LexicalScope*>(symbol->second);
}

static bool pform_nettype_resolution_name_exists_(
                                    LexicalScope*declaration_scope,
                                    const pform_scoped_name_t&path)
{
      if (path.name.empty())
            return false;

      if (!path.package && path.name.size() == 1)
            return pform_nettype_unqualified_name_exists_(
                  declaration_scope, path.name.front().name);

      LexicalScope*scope = path.package;
      pform_name_t::const_iterator component = path.name.begin();

      if (!scope && component != path.name.end()) {
            if (PPackage*pkg =
                      pform_test_package_identifier(component->name.str())) {
                  scope = pkg;
                  ++component;
            } else if (PClass*cls = pform_find_visible_class_scope(
                            declaration_scope, component->name)) {
                  scope = cls;
                  ++component;
            } else {
                  for (LexicalScope*lex = declaration_scope; lex;
                       lex = lex->parent_scope()) {
                        bool head_exists = false;
                        LexicalScope*child = pform_nettype_child_scope_(
                              lex, component->name, head_exists);
                        if (child) {
                              scope = child;
                              ++component;
                              break;
                        }
                        /* A visible non-scope head is bound; elaboration will
                         * issue the more precise wrong-kind diagnostic. */
                        if (head_exists)
                              return true;
                  }
            }
      }

      if (!scope)
            return false;

      while (component != path.name.end()) {
            pform_name_t::const_iterator next = component;
            ++next;
            if (next == path.name.end()) {
                  if (scope->local_symbols.find(component->name)
                      != scope->local_symbols.end())
                        return true;
                  if (PPackage*pkg = dynamic_cast<PPackage*>(scope))
                        if (pform_package_importable(pkg, component->name))
                              return true;
                  /* A class may inherit the named static method. Leave that
                   * semantic lookup to elaboration instead of rejecting it
                   * here as an unknown name. */
                  return dynamic_cast<PClass*>(scope) != nullptr;
            }

            bool component_exists = false;
            LexicalScope*child = pform_nettype_child_scope_(
                  scope, component->name, component_exists);
            if (!child)
                  return component_exists;
            scope = child;
            component = next;
      }

      return false;
}

static void pform_validate_nettype_resolvers_(LexicalScope*scope,
                                              set<LexicalScope*>&seen)
{
      if (!scope || !seen.insert(scope).second)
            return;

      for (LexicalScope::nettype_map_t::const_iterator cur =
                 scope->nettypes.begin(); cur != scope->nettypes.end(); ++cur) {
            const nettype_t*nettype = cur->second;
            const pform_scoped_name_t*resolver =
                  nettype ? nettype->resolution_function() : nullptr;
            if (!resolver || pform_nettype_resolution_name_exists_(
                                  scope, *resolver))
                  continue;

            cerr << nettype->get_fileline()
                 << ": error: Unable to bind resolution function `"
                 << *resolver << "'." << endl;
            error_count += 1;
      }

      if (PScopeExtra*scopex = dynamic_cast<PScopeExtra*>(scope))
            for (map<perm_string,PClass*>::const_iterator cur =
                       scopex->classes.begin(); cur != scopex->classes.end();
                 ++cur)
                  pform_validate_nettype_resolvers_(cur->second, seen);

      if (Module*module = dynamic_cast<Module*>(scope)) {
            for (map<perm_string,Module*>::const_iterator cur =
                       module->nested_modules.begin();
                 cur != module->nested_modules.end(); ++cur)
                  pform_validate_nettype_resolvers_(cur->second, seen);
            for (PGenerate*generate : module->generate_schemes)
                  pform_validate_nettype_resolvers_(generate, seen);
      }

      if (PGenerate*generate = dynamic_cast<PGenerate*>(scope))
            for (PGenerate*child : generate->generate_schemes)
                  pform_validate_nettype_resolvers_(child, seen);

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

      set<LexicalScope*>validated_scopes;
      for (PPackage*unit : pform_units)
            pform_validate_nettype_resolvers_(unit, validated_scopes);
      for (PPackage*package : pform_packages)
            pform_validate_nettype_resolvers_(package, validated_scopes);
      /* Top-level modules are owned by pform_modules. Do not rediscover them
       * by cross-casting the general local-symbol table: class property and
       * parameter entries in that table need not remain live through this
       * deferred finish pass. Nested modules, classes, and generate scopes
       * are reached recursively through their dedicated owned collections. */
      for (const pair<const perm_string,Module*>&module : pform_modules)
            pform_validate_nettype_resolvers_(module.second, validated_scopes);

      // Apply collected SystemVerilog bind directives now that every
      // target module has been parsed.
      pform_apply_binds();

      return error_count;
}

static void pform_release_scope_memory_(LexicalScope*scope,
					set<LexicalScope*>&seen)
{
      if (!scope || !seen.insert(scope).second)
	    return;

      if (PTask*task = dynamic_cast<PTask*>(scope))
	    task->release_elaboration_memory();
      else if (PFunction*func = dynamic_cast<PFunction*>(scope))
	    func->release_elaboration_memory();
      else
	    scope->release_elaboration_memory();

      if (PScopeExtra*extra = dynamic_cast<PScopeExtra*>(scope)) {
	    for (map<perm_string,PTask*>::value_type&item : extra->tasks)
		  pform_release_scope_memory_(item.second, seen);
	    for (map<perm_string,PFunction*>::value_type&item : extra->funcs)
		  pform_release_scope_memory_(item.second, seen);
	    for (map<perm_string,PClass*>::value_type&item : extra->classes)
		  pform_release_scope_memory_(item.second, seen);
      }

      if (PClass*pclass = dynamic_cast<PClass*>(scope)) {
	    /* Instance property initializers are borrowed by the synthesized
	     * constructor body released above. Drop the aliases without deleting
	     * them a second time. Static initializers have separate ownership. */
	    pclass->type->initialize.clear();
      }

      if (Module*module = dynamic_cast<Module*>(scope)) {
	    for (map<perm_string,Module*>::value_type&item :
		 module->nested_modules)
		  pform_release_scope_memory_(item.second, seen);
	    for (PGenerate*generate : module->generate_schemes)
		  pform_release_scope_memory_(generate, seen);
      }

      if (PGenerate*generate = dynamic_cast<PGenerate*>(scope)) {
	    for (map<perm_string,PTask*>::value_type&item : generate->tasks)
		  pform_release_scope_memory_(item.second, seen);
	    for (map<perm_string,PFunction*>::value_type&item : generate->funcs)
		  pform_release_scope_memory_(item.second, seen);
	    for (PGenerate*child : generate->generate_schemes)
		  pform_release_scope_memory_(child, seen);
      }
}

void pform_release_elaboration_memory()
{
      set<LexicalScope*>seen;
      for (PPackage*unit : pform_units)
	    pform_release_scope_memory_(unit, seen);
      for (PPackage*package : pform_packages)
	    pform_release_scope_memory_(package, seen);
      for (map<perm_string,Module*>::value_type&item : pform_modules)
	    pform_release_scope_memory_(item.second, seen);
}
