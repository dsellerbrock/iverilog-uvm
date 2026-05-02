/*
 * Copyright (c) 2000-2025 Stephen Williams (steve@icarus.com)
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

# include  "config.h"
# include  "compiler.h"
# include  "netmisc.h"
# include  "netvector.h"
# include  "netparray.h"
# include  <cstring>
# include  <iostream>
# include  <cstdlib>
# include  <cstdio>
# include  <sstream>
# include  <set>
# include  <algorithm>
# include  <ctime>

/*
 * Elaboration happens in two passes, generally. The first scans the
 * pform to generate the NetScope tree and attach it to the Design
 * object. The methods in this source file implement the elaboration
 * of the scopes.
 */

# include  "Module.h"
# include  "PClass.h"
# include  "PExpr.h"
# include  "PEvent.h"
# include  "PClass.h"
# include  "PGate.h"
# include  "PGenerate.h"
# include  "PPackage.h"
# include  "PTask.h"
# include  "PWire.h"
# include  "Statement.h"
# include  "AStatement.h"
# include  "pform.h"
# include  "netlist.h"
# include  "netclass.h"
# include  "netenum.h"
# include  "netqueue.h"
# include  "parse_api.h"
# include  "util.h"
# include  <typeinfo>
# include  "ivl_assert.h"

using namespace std;

static void elaborate_scope_class(Design*des, NetScope*scope, PClass*pclass);
static void complete_class_scope_in_place_(Design*des, NetScope*scope,
					   PClass*pclass, netclass_t*use_class,
					   NetScope*class_scope);

// Guard against infinite recursion between ensure_visible_class_type
// and elaborate_scope_class / complete_class_scope_in_place_.  UVM
// class hierarchies have mutual references that trigger unbounded
// re-entry, exhausting memory.
static set<const PClass*> classes_being_scope_elaborated_;
static unsigned ensure_visible_depth_ = 0;
static const unsigned ENSURE_VISIBLE_MAX_DEPTH_ = 20;

// Track total specialization allocs to catch any remaining runaway cases.
static unsigned total_class_allocs_ = 0;
static unsigned total_spec_allocs_ = 0;

struct specialization_perf_metrics_t {
      specialization_perf_metrics_t()
      : enabled(false), initialized(false), start_time(0), last_report(0),
	cache_hits(0), cache_misses(0), created(0), pending_peak(0), flushes(0),
	ops_since_report(0)
      {
      }

      bool enabled;
      bool initialized;
      time_t start_time;
      time_t last_report;
      unsigned long long cache_hits;
      unsigned long long cache_misses;
      unsigned long long created;
      unsigned long long pending_peak;
      unsigned long long flushes;
      unsigned long long ops_since_report;
      std::map<std::string,unsigned long long> miss_by_base;
};

static specialization_perf_metrics_t specialization_perf_state_;

typedef std::pair<std::string,unsigned long long> specialization_perf_count_t;

static specialization_perf_metrics_t& specialization_perf_metrics_()
{
      specialization_perf_metrics_t&metrics = specialization_perf_state_;
      if (!metrics.initialized) {
	    const char*trace = getenv("IVL_PERF_TRACE");
	    metrics.enabled = (trace && *trace);
	    metrics.initialized = true;
	    metrics.start_time = time(0);
      }
      return metrics;
}

static std::string specialization_perf_base_label_(const netclass_t*base_class)
{
      if (!base_class)
	    return "(null)";

      // For interface types, the netclass_t's class_scope_ may be set
      // lazily (Phase 45) to whichever instance scope happened to be
      // visible at the time of first method dispatch. That makes the
      // label time-dependent and breaks the specialization cache: a
      // `uvm_resource#(virtual <iface>)` reference elaborated before
      // class_scope_ is attached produces a different key than one
      // elaborated after, even though both should resolve to the same
      // specialized netclass_t. Use the bare type name (which is the
      // interface module name) as the canonical label.
      if (base_class->is_interface()) {
	    if (perm_string name = base_class->get_name())
		  return name.str();
      }

      if (const NetScope*base_scope = base_class->class_scope()) {
	    if (const PClass*pclass = base_scope->class_pform()) {
		  std::ostringstream tmp;
		  if (NetScope*definition_scope =
		      const_cast<netclass_t*>(base_class)->definition_scope()) {
			tmp << scope_path(definition_scope) << "::";
		  }
		  tmp << pclass->pscope_name();
		  return tmp.str();
	    }

	    std::ostringstream tmp;
	    tmp << scope_path(base_scope);
	    return tmp.str();
      }

      if (perm_string name = base_class->get_name())
	    return name.str();

      std::ostringstream tmp;
      tmp << "(class@" << (const void*)base_class << ")";
      return tmp.str();
}

static bool trace_specialization_key_(const netclass_t*base_class)
{
      const char*trace = getenv("IVL_SPEC_KEY_TRACE");
      if (!trace || !*trace)
	    return false;

      if (strcmp(trace, "1") == 0)
	    return true;

      if (!base_class)
	    return false;

      perm_string name = base_class->get_name();
      if (!name)
	    return false;

      return strstr(trace, name) != 0;
}

static bool specialization_perf_count_cmp_(const specialization_perf_count_t&lhs,
					   const specialization_perf_count_t&rhs)
{
      if (lhs.second != rhs.second)
	    return lhs.second > rhs.second;
      return lhs.first < rhs.first;
}

static void maybe_report_specialization_perf_top_misses_(
		const specialization_perf_metrics_t&metrics)
{
      if (metrics.miss_by_base.empty())
	    return;

      std::vector<specialization_perf_count_t> top_counts;
      top_counts.reserve(metrics.miss_by_base.size());
      for (std::map<std::string,unsigned long long>::const_iterator cur =
		     metrics.miss_by_base.begin()
		 ; cur != metrics.miss_by_base.end() ; ++cur)
	    top_counts.push_back(*cur);

      size_t limit = 5;
      if (top_counts.size() > limit) {
	    std::partial_sort(top_counts.begin(), top_counts.begin()+limit,
			      top_counts.end(),
			      specialization_perf_count_cmp_);
      } else {
	    std::sort(top_counts.begin(), top_counts.end(),
		      specialization_perf_count_cmp_);
      }

      cerr << "ivl-perf-top-misses:";
      for (size_t idx = 0 ; idx < top_counts.size() && idx < limit ; ++idx) {
	    cerr << (idx? ", " : " ");
	    cerr << top_counts[idx].first << "=" << top_counts[idx].second;
      }
      cerr << endl;
}

static void maybe_report_specialization_perf_(bool force = false)
{
      specialization_perf_metrics_t&metrics = specialization_perf_metrics_();
      if (!metrics.enabled)
	    return;

      time_t now = time(0);
      if (!force) {
	    if (metrics.ops_since_report < 1024)
		  return;
	    if (metrics.last_report != 0 && now == metrics.last_report)
		  return;
      }

      metrics.last_report = now;
      metrics.ops_since_report = 0;
      unsigned long long elapsed = 0;
      if (metrics.start_time != 0 && now >= metrics.start_time)
	    elapsed = now - metrics.start_time;

      cerr << "ivl-perf: t=" << elapsed << "s"
	   << " specialization_ops=" << (metrics.cache_hits + metrics.cache_misses)
	   << " hits=" << metrics.cache_hits
	   << " misses=" << metrics.cache_misses
	   << " created=" << metrics.created
	   << " miss_families=" << metrics.miss_by_base.size()
	   << " pending_peak=" << metrics.pending_peak
	   << " flushes=" << metrics.flushes
	   << endl;
      maybe_report_specialization_perf_top_misses_(metrics);
}

static void maybe_report_specialization_pending_body_(
		size_t done, size_t total, const netclass_t*cls)
{
      specialization_perf_metrics_t&metrics = specialization_perf_metrics_();
      if (!metrics.enabled)
	    return;

      time_t now = time(0);
      unsigned long long elapsed = 0;
      if (metrics.start_time != 0 && now >= metrics.start_time)
	    elapsed = now - metrics.start_time;

      cerr << "ivl-perf-pending: t=" << elapsed << "s"
	   << " done=" << done << "/" << total
	   << " class=" << specialization_perf_base_label_(cls)
	   << endl;
}

static void note_specialization_cache_hit_()
{
      specialization_perf_metrics_t&metrics = specialization_perf_metrics_();
      if (!metrics.enabled)
	    return;

      metrics.cache_hits += 1;
      metrics.ops_since_report += 1;
      maybe_report_specialization_perf_();
}

static void note_specialization_cache_miss_(const netclass_t*base_class)
{
      specialization_perf_metrics_t&metrics = specialization_perf_metrics_();
      if (!metrics.enabled)
	    return;

      metrics.cache_misses += 1;
      metrics.created += 1;
      metrics.ops_since_report += 1;
      metrics.miss_by_base[specialization_perf_base_label_(base_class)] += 1;
      maybe_report_specialization_perf_();
}

static void note_specialization_pending_peak_(size_t pending_size)
{
      specialization_perf_metrics_t&metrics = specialization_perf_metrics_();
      if (!metrics.enabled)
	    return;

      if (pending_size > metrics.pending_peak)
	    metrics.pending_peak = pending_size;
}

static void note_specialization_flush_()
{
      specialization_perf_metrics_t&metrics = specialization_perf_metrics_();
      if (!metrics.enabled)
	    return;

      metrics.flushes += 1;
      maybe_report_specialization_perf_(true);
}

struct visible_pclass_match_t {
      visible_pclass_match_t() : pclass(0), owner_scope(0) { }
      PClass*pclass;
      NetScope*owner_scope;
};

void set_scope_timescale(Design*des, NetScope*scope, const PScope*pscope)
{
      scope->time_unit(pscope->time_unit);
      scope->time_precision(pscope->time_precision);
      scope->time_from_timescale(pscope->has_explicit_timescale());
      des->set_precision(pscope->time_precision);
}

typedef map<perm_string,LexicalScope::param_expr_t*>::const_iterator mparm_it_t;

static void elaborate_scope_events_(Design*des, NetScope*scope,
                                    const map<perm_string,PEvent*>&events);

static void collect_parm_item(Design*des, NetScope*scope, perm_string name,
			      const LexicalScope::param_expr_t&cur,
			      bool is_annotatable)
{
      if (debug_scopes) {
	    cerr << cur.get_fileline() << ": " << __func__  << ": "
		 << "parameter " << name << " ";
	    if (cur.data_type)
		  cerr << *cur.data_type;
	    else
		  cerr << "(nil type)";
	    ivl_assert(cur, cur.expr);
	    cerr << " = " << *cur.expr << "; ";
	    if (cur.range)
		  cerr << "with ranges ";
	    else
		  cerr << "without ranges ";
	    cerr << "; in scope " << scope_path(scope) << endl;
      }

      NetScope::range_t*range_list = 0;
      for (LexicalScope::range_t*range = cur.range ; range ; range = range->next) {
	    NetScope::range_t*tmp = new NetScope::range_t;
	    tmp->exclude_flag = range->exclude_flag;
	    tmp->low_open_flag = range->low_open_flag;
	    tmp->high_open_flag = range->high_open_flag;

	    if (range->low_expr) {
		  tmp->low_expr = elab_and_eval(des, scope, range->low_expr, -1);
		  ivl_assert(*range->low_expr, tmp->low_expr);
	    } else {
		  tmp->low_expr = 0;
	    }

	    if (range->high_expr && range->high_expr==range->low_expr) {
		    // Detect the special case of a "point"
		    // range. These are called out by setting the high
		    // and low expression ranges to the same
		    // expression. The exclude_flags should be false
		    // in this case
		  ivl_assert(*range->high_expr, tmp->low_open_flag==false && tmp->high_open_flag==false);
		  tmp->high_expr = tmp->low_expr;

	    } else if (range->high_expr) {
		  tmp->high_expr = elab_and_eval(des, scope, range->high_expr, -1);
		  ivl_assert(*range->high_expr, tmp->high_expr);
	    } else {
		  tmp->high_expr = 0;
	    }

	    tmp->next = range_list;
	    range_list = tmp;
      }

      // The type of the parameter, if unspecified in the source, will come
      // from the type of the value assigned to it. Therefore, if the type is
      // not yet known, don't try to guess here, put the type guess off. Also
      // don't try to elaborate it here, because there may be references to
      // other parameters still being located during scope elaboration.
      scope->set_parameter(name, is_annotatable, cur, range_list);
}

static void collect_scope_parameters(Design*des, NetScope*scope,
      const map<perm_string,LexicalScope::param_expr_t*>&parameters)
{
      if (debug_scopes) {
	    cerr << scope->get_fileline() << ": " << __func__ << ": "
		 << "collect parameters for " << scope_path(scope) << "." << endl;
      }

      for (mparm_it_t cur = parameters.begin()
		 ; cur != parameters.end() ;  ++ cur ) {

	    collect_parm_item(des, scope, cur->first, *(cur->second), false);
      }
}

static void collect_scope_specparams(Design*des, NetScope*scope,
      const map<perm_string,LexicalScope::param_expr_t*>&specparams)
{
      if (debug_scopes) {
	    cerr << scope->get_fileline() << ": " << __func__ << ": "
		 << "collect specparams for " << scope_path(scope) << "." << endl;
      }

      for (mparm_it_t cur = specparams.begin()
		 ; cur != specparams.end() ;  ++ cur ) {

	    collect_parm_item(des, scope, cur->first, *(cur->second), true);
      }
}

static void collect_scope_signals(NetScope*scope,
      const map<perm_string,PWire*>&wires)
{
      for (map<perm_string,PWire*>::const_iterator cur = wires.begin()
		 ; cur != wires.end() ; ++ cur ) {

	    PWire*wire = (*cur).second;
	    if (debug_scopes) {
		  cerr << wire->get_fileline() << ": " << __func__ << ": "
		       << "adding placeholder for signal '" << wire->basename()
		       << "' in scope '" << scope_path(scope) << "'." << endl;
	    }
	    scope->add_signal_placeholder(wire);
      }
}

static bool scope_has_automatic_signal_locals_(
      const map<perm_string,PWire*>&wires)
{
      for (map<perm_string,PWire*>::const_iterator cur = wires.begin()
		 ; cur != wires.end() ; ++ cur ) {
	    const PWire*wire = cur->second;
	    if (wire && wire->lifetime_override() == IVL_VLT_AUTOMATIC)
		  return true;
      }

      return false;
}

/*
 * Elaborate the enumeration into the given scope.
 */
static void elaborate_scope_enumeration(Design*des, NetScope*scope,
					enum_type_t*enum_type)
{
      bool rc_flag;

      enum_type->elaborate_type(des, scope);

      netenum_t *use_enum = scope->enumeration_for_key(enum_type);

      size_t name_idx = 0;
	// Find the enumeration width.
      long raw_width = use_enum->packed_width();
      ivl_assert(*use_enum, raw_width > 0);
      unsigned enum_width = (unsigned)raw_width;
      bool is_signed = use_enum->get_signed();
	// Define the default start value and the increment value to be the
	// correct type for this enumeration.
      verinum cur_value ((uint64_t)0, enum_width);
      cur_value.has_sign(is_signed);
      verinum one_value ((uint64_t)1, enum_width);
      one_value.has_sign(is_signed);
	// Find the maximum allowed enumeration value.
      verinum max_value (0);
      if (is_signed) {
	    max_value = pow(verinum(2), verinum(enum_width-1)) - one_value;
      } else {
	    max_value = pow(verinum(2), verinum(enum_width)) - one_value;
      }
      max_value.has_sign(is_signed);
	// Variable to indicate when a defined value wraps.
      bool implicit_wrapped = false;
	// Process the enumeration definition.
      for (list<named_pexpr_t>::const_iterator cur = enum_type->names->begin()
		 ; cur != enum_type->names->end() ;  ++ cur, name_idx += 1) {
	      // Check to see if the enumeration name has a value given.
	    if (cur->parm) {
		    // There is an explicit value. elaborate/evaluate
		    // the value and assign it to the enumeration name.
		  NetExpr*val = elab_and_eval(des, scope, cur->parm, -1);
		  const NetEConst*val_const = dynamic_cast<NetEConst*> (val);
		  if (val_const == 0) {
			cerr << use_enum->get_fileline()
			     << ": error: Enumeration expression for "
			     << cur->name <<" is not an integer constant."
			     << endl;
			des->errors += 1;
			continue;
		  }
		  cur_value = val_const->value();
		    // Clear the implicit wrapped flag if a parameter is given.
		  implicit_wrapped = false;

		    // A 2-state value can not have a constant with X/Z bits.
		  if (use_enum->base_type() == IVL_VT_BOOL &&
		      ! cur_value.is_defined()) {
			cerr << use_enum->get_fileline()
			     << ": error: Enumeration name " << cur->name
			     << " can not have an undefined value." << endl;
			des->errors += 1;
		  }
		    // If this is a literal constant and it has a defined
		    // width then the width must match the enumeration width.
		  if (const PENumber *tmp = dynamic_cast<PENumber*>(cur->parm)) {
			if (tmp->value().has_len() &&
			    (tmp->value().len() != enum_width)) {
			      cerr << use_enum->get_fileline()
			           << ": error: Enumeration name " << cur->name
			           << " has an incorrectly sized constant."
			           << endl;
			      des->errors += 1;
			}
		  }

		    // If we are padding/truncating a negative value for an
		    // unsigned enumeration that is an error or if the new
		    // value does not have a defined width.
		  if (((cur_value.len() != enum_width) ||
		       ! cur_value.has_len()) &&
		      ! is_signed && cur_value.is_negative()) {
			cerr << use_enum->get_fileline()
			     << ": error: Enumeration name " << cur->name
			     << " has a negative value." << endl;
			des->errors += 1;
		  }

		    // Narrower values need to be padded to the width of the
		    // enumeration and defined to have the specified width.
		  if (cur_value.len() < enum_width) {
			cur_value = pad_to_width(cur_value, enum_width);
		  }

		    // Some wider values can be truncated.
		  if (cur_value.len() > enum_width) {
			unsigned check_width = enum_width - 1;
			  // Check that the upper bits match the MSB
			for (unsigned idx = enum_width;
			     idx < cur_value.len();
			     idx += 1) {
			      if (cur_value[idx] != cur_value[check_width]) {
				      // If this is an unsigned enumeration
				      // then zero padding is okay.
				    if (!is_signed &&
				        (idx == enum_width) &&
				        (cur_value[idx] == verinum::V0)) {
					  check_width += 1;
					  continue;
				    }
				    if (cur_value.is_defined()) {
					  cerr << use_enum->get_fileline()
					       << ": error: Enumeration name "
					       << cur->name
					       << " has a value that is too "
					       << ((cur_value > max_value) ?
					           "large" : "small")
					       << " " << cur_value << "."
					       << endl;
				    } else {
					  cerr << use_enum->get_fileline()
					       << ": error: Enumeration name "
					       << cur->name
					       << " has trimmed bits that do "
					       << "not match the enumeration "
					       << "MSB: " << cur_value << "."
					       << endl;
				    }
				    des->errors += 1;
				    break;
			      }
			}
			  // If this is an unsigned value then make sure
			  // The upper bits are not 1.
			if (! cur_value.has_sign() &&
			    (cur_value[enum_width] == verinum::V1)) {
			      cerr << use_enum->get_fileline()
			           << ": error: Enumeration name "
			           << cur->name
			           << " has a value that is too large: "
			           << cur_value << "." << endl;
			      des->errors += 1;
			      break;
			}
			cur_value = verinum(cur_value, enum_width);
		  }

		    // At this point the value has the correct size and needs
		    // to have the correct sign attribute set.
		  cur_value.has_len(true);
		  cur_value.has_sign(is_signed);

	    } else if (! cur_value.is_defined()) {
		  cerr << use_enum->get_fileline()
		       << ": error: Enumeration name " << cur->name
		       << " has an undefined inferred value." << endl;
		  des->errors += 1;
		  continue;
	    }

	      // Check to see if an implicitly wrapped value is used.
	    if (implicit_wrapped) {
		  cerr << use_enum->get_fileline()
		       << ": error: Enumeration name " << cur->name
		       << " has an inferred value that overflowed." << endl;
		  des->errors += 1;
	    }

	    // The enumeration value must be unique.
	    perm_string dup_name = use_enum->find_value(cur_value);
	    if (dup_name) {
		  cerr << use_enum->get_fileline()
		       << ": error: Enumeration name "
		       << cur->name << " and " << dup_name
		       << " have the same value: " << cur_value << endl;
		  des->errors += 1;
	    }

	    rc_flag = use_enum->insert_name(name_idx, cur->name, cur_value);
	    rc_flag &= scope->add_enumeration_name(use_enum, cur->name);

	    if (! rc_flag) {
		  cerr << use_enum->get_fileline()
		       << ": error: Duplicate enumeration name "
		       << cur->name << endl;
		  des->errors += 1;
	    }

	      // In case the next name has an implicit value,
	      // increment the current value by one.
	    if (cur_value.is_defined()) {
		  if (cur_value == max_value) implicit_wrapped = true;
		  cur_value = cur_value + one_value;
	    }
      }

      use_enum->insert_name_close();
}

static void elaborate_scope_enumerations(Design*des, NetScope*scope,
					 const vector<enum_type_t*>&enum_types)
{
      if (debug_scopes) {
	    cerr << scope->get_fileline() << ": " << __func__ << ": "
		 << "Elaborate " << enum_types.size() << " enumerations"
		 << " in scope " << scope_path(scope) << "."
		 << endl;
      }

      for (vector<enum_type_t*>::const_iterator cur = enum_types.begin()
		 ; cur != enum_types.end() ; ++ cur) {
	    enum_type_t*curp = *cur;
	    elaborate_scope_enumeration(des, scope, curp);
      }
}

/*
 * If the pclass includes an implicit and explicit constructor, then
 * merge the implicit constructor into the explicit constructor as
 * statements in the beginning.
 *
 * This is not necessary for proper functionality, it is an
 * optimization, so we can easily give up if it doesn't seem like it
 * will obviously work.
 */
static void blend_class_constructors(PClass*pclass)
{
      pform_blend_class_constructors(pclass);
}

static visible_pclass_match_t find_visible_pclass_here_(Design*des,
							NetScope*owner_scope,
							LexicalScope*scope,
							perm_string name)
{
      visible_pclass_match_t match;
      if (!scope)
	    return match;

      if (PScopeExtra*scopex = dynamic_cast<PScopeExtra*>(scope)) {
	    auto cls = scopex->classes.find(name);
	    if (cls != scopex->classes.end()) {
		  match.pclass = cls->second;
		  match.owner_scope = owner_scope;
		  return match;
	    }
      }

      auto imp = scope->explicit_imports.find(name);
      if (imp != scope->explicit_imports.end()) {
	    PPackage*pkg = imp->second;
	    auto cls = pkg->classes.find(name);
	    if (cls != pkg->classes.end()) {
		  match.pclass = cls->second;
		  match.owner_scope = des->find_package(pkg->pscope_name());
		  return match;
	    }
      }

      for (PPackage*pkg : scope->potential_imports) {
	    auto cls = pkg->classes.find(name);
	    if (cls != pkg->classes.end()) {
		  match.pclass = cls->second;
		  match.owner_scope = des->find_package(pkg->pscope_name());
		  return match;
	    }
      }

      return match;
}

netclass_t* ensure_visible_class_type(Design*des, NetScope*scope, perm_string name)
{
      if (!des || !scope || name.nil())
	    return 0;

	// Depth guard: if we are already too deep in recursive class
	// elaboration, return whatever we have (possibly null) rather
	// than recursing further.  This prevents unbounded memory
	// growth from mutually-referencing class hierarchies.
      if (ensure_visible_depth_ >= ENSURE_VISIBLE_MAX_DEPTH_)
	    return scope->find_class(des, name);

      ensure_visible_depth_ += 1;

      netclass_t*incomplete_cls = 0;
      if (netclass_t*cls = scope->find_class(des, name)) {
            if (cls->class_scope() && cls->scope_ready()) {
                  ensure_visible_depth_ -= 1;
                  return cls;
            }
            incomplete_cls = cls;

            if (cls->class_scope() && !cls->scope_ready()) {
                  const PClass*pclass = cls->class_scope()->class_pform();
                  NetScope*definition_scope = cls->definition_scope();
		    // Only recurse if this class is not already being
		    // elaborated (cycle guard).
                  if (pclass && definition_scope
		      && classes_being_scope_elaborated_.count(pclass) == 0) {
                        elaborate_scope_class(des, definition_scope,
                                              const_cast<PClass*>(pclass));
                        if (cls->scope_ready()) {
                              ensure_visible_depth_ -= 1;
                              return cls;
                        }
                  }
            }
      }

      if (netclass_t*cls = builtin_class_type(name)) {
	    ensure_visible_depth_ -= 1;
	    return cls;
      }

      NetScope*owner_scope = 0;
      LexicalScope*lex_scope = 0;
      for (NetScope*cur = scope ; cur ; cur = cur->parent()) {
	    if (const PFunction*pfunc = cur->func_pform()) {
		  owner_scope = cur;
		  lex_scope = const_cast<PFunction*>(pfunc);
		  break;
	    }
	    if (const PClass*pclass = cur->class_pform()) {
		  owner_scope = cur;
		  lex_scope = const_cast<PClass*>(pclass);
		  break;
	    }
      }

      while (owner_scope && lex_scope) {
	    visible_pclass_match_t match =
		  find_visible_pclass_here_(des, owner_scope, lex_scope, name);
	    if (match.pclass) {
		  if (match.owner_scope
		      && classes_being_scope_elaborated_.count(match.pclass) == 0)
			elaborate_scope_class(des, match.owner_scope, match.pclass);
		  break;
	    }

	    owner_scope = owner_scope->parent();
	    lex_scope = lex_scope->parent_scope();
      }

      if (netclass_t*cls = scope->find_class(des, name)) {
	    ensure_visible_depth_ -= 1;
	    return cls;
      }

      ensure_visible_depth_ -= 1;
      return incomplete_cls;
}

static std::string parmvalue_cache_key_(Design*des, NetScope*call_scope,
					const parmvalue_t*overrides);
static void append_cache_data_type_key_(Design*des, NetScope*call_scope,
					std::ostringstream&out,
					const data_type_t*type);

static const std::string& cached_scope_path_(const NetScope*scope)
{
      static std::map<const NetScope*,std::string> cache;

      if (!scope) {
	    static const std::string empty;
	    return empty;
      }

      std::map<const NetScope*,std::string>::iterator it = cache.find(scope);
      if (it != cache.end())
	    return it->second;

      std::ostringstream out;
      out << scope_path(scope);
      return cache.insert(std::make_pair(scope, out.str())).first->second;
}

static const std::string& cached_pexpr_dump_(const PExpr*expr)
{
      static std::map<const PExpr*,std::string> cache;

      if (!expr) {
	    static const std::string empty;
	    return empty;
      }

      std::map<const PExpr*,std::string>::iterator it = cache.find(expr);
      if (it != cache.end())
	    return it->second;

      std::ostringstream out;
      out << *expr;
      return cache.insert(std::make_pair(expr, out.str())).first->second;
}

static const std::string& cached_netexpr_dump_(const NetExpr*expr)
{
      static std::map<const NetExpr*,std::string> cache;

      if (!expr) {
	    static const std::string empty;
	    return empty;
      }

      std::map<const NetExpr*,std::string>::iterator it = cache.find(expr);
      if (it != cache.end())
	    return it->second;

      std::ostringstream out;
      out << *expr;
      return cache.insert(std::make_pair(expr, out.str())).first->second;
}

static const std::string& cached_type_dump_(ivl_type_t type)
{
      static std::map<ivl_type_t,std::string> cache;

      if (!type) {
	    static const std::string empty;
	    return empty;
      }

      std::map<ivl_type_t,std::string>::iterator it = cache.find(type);
      if (it != cache.end())
	    return it->second;

      std::ostringstream out;
      type->debug_dump(out);
      return cache.insert(std::make_pair(type, out.str())).first->second;
}

static void append_cache_ivl_type_key_(Design*des, std::ostringstream&out,
				       ivl_type_t type,
				       std::set<ivl_type_t>&active)
{
      if (!type) {
	    out << "<nil-ivl-type>";
	    return;
      }

      if (!active.insert(type).second) {
	    if (const netclass_t*class_type = dynamic_cast<const netclass_t*>(type))
		  out << "<type-cycle:" << specialization_perf_base_label_(class_type) << ">";
	    else
		  out << "<type-cycle:" << cached_type_dump_(type) << ">";
	    return;
      }

      if (const netclass_t*class_type = dynamic_cast<const netclass_t*>(type)) {
	    out << "<class-type:" << specialization_perf_base_label_(class_type);
	    const NetScope*class_scope = class_type->class_scope();
	    const PClass*pclass = class_scope ? class_scope->class_pform() : 0;
	    if (class_scope && pclass && !pclass->parameter_order.empty()) {
		  out << "(";
		  bool first = true;
		  for (std::list<perm_string>::const_iterator cur =
			       pclass->parameter_order.begin()
			     ; cur != pclass->parameter_order.end() ; ++cur) {
			if (!first)
			      out << ",";
			first = false;
			out << *cur << "=";
			ivl_type_t parm_type = 0;
			const NetExpr*parm_expr =
			      const_cast<NetScope*>(class_scope)->get_parameter(des,
								    *cur,
								    parm_type);
			if (parm_type)
			      append_cache_ivl_type_key_(des, out, parm_type, active);
			else if (parm_expr)
			      out << cached_netexpr_dump_(parm_expr);
			else
			      out << "<unset>";
		  }
		  out << ")";
	    }
	    out << ">";
	    active.erase(type);
	    return;
      }

      if (const netenum_t*enum_type = dynamic_cast<const netenum_t*>(type)) {
	    out << "<enum-type:@" << (const void*)enum_type
	        << ":base=" << cached_type_dump_(type) << ">";
	    active.erase(type);
	    return;
      }

      out << cached_type_dump_(type);
      active.erase(type);
}

static void append_cache_ivl_type_key_(Design*des, std::ostringstream&out,
				       ivl_type_t type)
{
      std::set<ivl_type_t> active;
      append_cache_ivl_type_key_(des, out, type, active);
}

static bool expr_cache_key_needs_scope_(const PExpr*expr)
{
      if (!expr)
	    return false;

      if (dynamic_cast<const PENumber*>(expr))
	    return false;
      if (dynamic_cast<const PEFNumber*>(expr))
	    return false;
      if (dynamic_cast<const PEString*>(expr))
	    return false;
      if (dynamic_cast<const PENull*>(expr))
	    return false;

      return true;
}

static NetScope* specialization_key_scope_(NetScope*call_scope)
{
      if (!call_scope)
	    return 0;

	// Normalize to the enclosing class scope so that all methods
	// within the same class produce the same specialization key.
	// Without this, each method call site gets a unique key and
	// uvm_callbacks is re-specialized thousands of times.
      if (const NetScope*class_scope = call_scope->get_class_scope())
	    return const_cast<NetScope*>(class_scope);

      return call_scope;
}

static const std::string& cached_data_type_dump_(const data_type_t*type)
{
      static std::map<const data_type_t*,std::string> cache;

      if (!type) {
	    static const std::string empty;
	    return empty;
      }

      std::map<const data_type_t*,std::string>::iterator it = cache.find(type);
      if (it != cache.end())
	    return it->second;

      std::ostringstream out;
      type->debug_dump(out);
      return cache.insert(std::make_pair(type, out.str())).first->second;
}

static bool append_cache_typedef_alias_key_(Design*des, NetScope*call_scope,
					    std::ostringstream&out,
					    typedef_t*td)
{
      static std::set<const typedef_t*> active;
      static const perm_string k_common_type = perm_string::literal("common_type");

      if (!td || td->name != k_common_type)
	    return false;

      const data_type_t*alias_type = td->get_data_type();
      if (!alias_type)
	    return false;

      if (!active.insert(td).second)
	    return false;

      out << "<typedef-alias:" << td->name << "=";
      append_cache_data_type_key_(des, call_scope, out, alias_type);
      out << ">";
      active.erase(td);
      return true;
}

static void append_cache_expr_key_(Design*des, NetScope*call_scope,
				   std::ostringstream&out,
				   const PExpr*expr)
{
      call_scope = specialization_key_scope_(call_scope);

      if (!expr)
	    return;

      if (const PETypename*type_expr = dynamic_cast<const PETypename*>(expr)) {
	    if (call_scope) {
		  ivl_type_t resolved_type =
			const_cast<data_type_t*>(type_expr->get_type())->elaborate_type(des, call_scope);
		  if (resolved_type) {
			append_cache_ivl_type_key_(des, out, resolved_type);
			return;
		  }
	    }

	    out << "<typename:";
	    append_cache_data_type_key_(des, call_scope, out, type_expr->get_type());
	    out << ">";
	    return;
      }

      if (const PEIdent*ident = dynamic_cast<const PEIdent*>(expr)) {
	    const pform_scoped_name_t&path = ident->path();
	    if (call_scope && path.package == 0 && path.name.size() == 1 &&
	        path.name.front().index.empty()) {
		  perm_string ident_name = path.name.front().name;
		  ivl_type_t resolved_type = 0;
		  const NetExpr*resolved_expr =
			call_scope->get_parameter(des, ident_name, resolved_type);
		  if (resolved_expr || resolved_type) {
			if (resolved_type)
			      append_cache_ivl_type_key_(des, out, resolved_type);
			if (resolved_expr) {
			      if (resolved_type)
				    out << "=";
			      out << cached_netexpr_dump_(resolved_expr);
			}
			return;
		  }
	    }
      }

      out << cached_pexpr_dump_(expr);

      // Keep cache entries scope-sensitive only for expressions that we
      // could not canonicalize to resolved parameter/type values.
      if (call_scope && expr_cache_key_needs_scope_(expr))
	    out << "@scope=" << cached_scope_path_(call_scope);
}

static void append_cache_data_type_key_(Design*des, NetScope*call_scope,
					std::ostringstream&out,
					const data_type_t*type)
{
      call_scope = specialization_key_scope_(call_scope);

      if (!type) {
	    out << "<nil>";
	    return;
      }

      if (const typeref_t*type_ref = dynamic_cast<const typeref_t*>(type)) {
	    if (typedef_t*td = type_ref->typedef_ref()) {
		  if (append_cache_typedef_alias_key_(des, call_scope, out, td)) {
			if (const parmvalue_t*overrides = type_ref->parameter_values())
			      out << parmvalue_cache_key_(des, call_scope, overrides);
			return;
		  }
	    }

	    if (call_scope && type_ref->scope_ref() == 0) {
		  if (typedef_t*td = type_ref->typedef_ref()) {
			ivl_type_t resolved_type = 0;
			call_scope->get_parameter(des, td->name, resolved_type);
			if (resolved_type) {
			      out << "<resolved-typeref:" << td->name << "=";
			      append_cache_ivl_type_key_(des, out, resolved_type);
			      if (const parmvalue_t*overrides = type_ref->parameter_values())
				    out << parmvalue_cache_key_(des, call_scope, overrides);
			      out << ">";
			      return;
			}
		  }
	    }

	    if (type_ref->scope_ref())
		  out << type_ref->scope_ref()->pscope_name() << "::";
	    if (typedef_t*td = type_ref->typedef_ref())
		  out << td->name;
	    else
		  out << "<anon-typeref>";
	    if (const parmvalue_t*overrides = type_ref->parameter_values())
		  out << parmvalue_cache_key_(des, call_scope, overrides);
	    return;
      }

      if (const type_parameter_t*type_param = dynamic_cast<const type_parameter_t*>(type)) {
	    out << "typeparam:" << type_param->name;
	    if (call_scope) {
		  ivl_type_t resolved_type = 0;
		  call_scope->get_parameter(des, type_param->name, resolved_type);
		  if (resolved_type) {
			out << "=";
			append_cache_ivl_type_key_(des, out, resolved_type);
		  }
	    }
	    return;
      }

      if (const class_type_t*class_type = dynamic_cast<const class_type_t*>(type)) {
	    if (call_scope) {
		  if (ivl_type_t resolved_type =
			      const_cast<class_type_t*>(class_type)->elaborate_type(des, call_scope)) {
			append_cache_ivl_type_key_(des, out, resolved_type);
			return;
		  }
	    }
	    out << "class:" << class_type->name;
	    return;
      }

      if (const interface_type_t*iface_type = dynamic_cast<const interface_type_t*>(type)) {
	    if (call_scope) {
		  if (ivl_type_t resolved_type =
			      const_cast<interface_type_t*>(iface_type)->elaborate_type(des, call_scope)) {
			append_cache_ivl_type_key_(des, out, resolved_type);
			return;
		  }
	    }
	    out << "interface:" << iface_type->name;
	    return;
      }

      out << cached_data_type_dump_(type);
}

static std::string parmvalue_cache_key_(Design*des, NetScope*call_scope,
					const parmvalue_t*overrides)
{
      call_scope = specialization_key_scope_(call_scope);

      if (!overrides)
	    return std::string();

      std::ostringstream out;
      if (overrides->by_order) {
	    out << "O";
	    for (std::list<PExpr*>::const_iterator cur = overrides->by_order->begin()
		 ; cur != overrides->by_order->end() ; ++cur) {
		  out << "|";
		  append_cache_expr_key_(des, call_scope, out, *cur);
	    }
      } else if (overrides->by_name) {
	    out << "N";
	    for (std::list<named_pexpr_t>::const_iterator cur = overrides->by_name->begin()
		 ; cur != overrides->by_name->end() ; ++cur) {
		  out << "|" << cur->name << "=";
		  append_cache_expr_key_(des, call_scope, out, cur->parm);
	    }
      }

      return out.str();
}

static bool pexpr_matches_parameter_name_(const PExpr*expr, perm_string name)
{
      if (const PEIdent*ident = dynamic_cast<const PEIdent*>(expr)) {
	    const pform_scoped_name_t&path = ident->path();
	    if (path.package == 0 && path.name.size() == 1 &&
	        path.name.front().index.empty() &&
	        path.name.front().name == name)
		  return true;
      }

      if (const PETypename*type_expr = dynamic_cast<const PETypename*>(expr)) {
	    if (const type_parameter_t*type_param =
	        dynamic_cast<const type_parameter_t*>(type_expr->get_type())) {
		  if (type_param->name == name)
			return true;
	    }

	    if (const typeref_t*type_ref =
	        dynamic_cast<const typeref_t*>(type_expr->get_type())) {
		  if (type_ref->scope_ref() == 0 && type_ref->parameter_values() == 0) {
			if (typedef_t*td = type_ref->typedef_ref()) {
			      if (td->name == name)
				    return true;
			}
		  }
	    }
      }

      return false;
}

static bool overrides_match_parameter_order_(const parmvalue_t*overrides,
					     const std::list<perm_string>&param_order)
{
      if (!overrides || !overrides->by_order)
	    return false;

      std::list<PExpr*>::const_iterator expr_it = overrides->by_order->begin();
      std::list<perm_string>::const_iterator name_it = param_order.begin();
      while (expr_it != overrides->by_order->end() && name_it != param_order.end()) {
	    if (!*expr_it || !pexpr_matches_parameter_name_(*expr_it, *name_it))
		  return false;
	    ++expr_it;
	    ++name_it;
      }

      return expr_it == overrides->by_order->end() && name_it == param_order.end();
}

static void apply_specialized_class_overrides_(Design*des, NetScope*class_scope,
					       const parmvalue_t*overrides,
					       NetScope*call_scope,
					       const std::list<perm_string>*param_order)
{
      if (!class_scope || !overrides)
	    return;

      if (overrides->by_name) {
	    for (std::list<named_pexpr_t>::const_iterator cur = overrides->by_name->begin()
		 ; cur != overrides->by_name->end() ; ++cur) {
		  if (cur->parm)
			class_scope->replace_parameter(des, cur->name, cur->parm,
						      call_scope, false);
	    }
	    return;
      }

      if (!overrides->by_order)
	    return;

      std::vector<perm_string> names;
      if (param_order) {
	    for (std::list<perm_string>::const_iterator cur = param_order->begin()
		 ; cur != param_order->end() ; ++cur) {
		  if (class_scope->parameters.find(*cur) != class_scope->parameters.end())
			names.push_back(*cur);
	    }
      }
      if (names.empty()) {
	    std::vector<std::pair<unsigned,perm_string> > sorted_names;
	    for (std::map<perm_string,NetScope::param_expr_t>::const_iterator cur = class_scope->parameters.begin()
		       ; cur != class_scope->parameters.end() ; ++cur) {
		  sorted_names.push_back(std::make_pair(cur->second.lexical_pos, cur->first));
	    }
	    std::sort(sorted_names.begin(), sorted_names.end());
	    for (std::vector<std::pair<unsigned,perm_string> >::const_iterator cur = sorted_names.begin()
		       ; cur != sorted_names.end() ; ++cur)
		  names.push_back(cur->second);
      }

      std::list<PExpr*>::const_iterator expr_it = overrides->by_order->begin();
      size_t param_idx = 0;
      while (expr_it != overrides->by_order->end() && param_idx < names.size()) {
	    if (*expr_it)
		  class_scope->replace_parameter(des, names[param_idx], *expr_it,
						      call_scope, false);
	    ++expr_it;
	    ++param_idx;
      }
}

static void flush_pending_specialized_class_bodies_(Design*des,
						    std::vector<netclass_t*>&pending)
{
      note_specialization_flush_();

      size_t idx = 0;
      while (idx < pending.size()) {
	    netclass_t*cls = pending[idx++];
	    if (!cls || cls->body_elaborated())
		  continue;

	    if (idx == 1 || idx == pending.size() || (idx % 16) == 0)
		  maybe_report_specialization_pending_body_(idx, pending.size(), cls);

	    const NetScope*class_scope = cls->class_scope();
	    const PClass*pclass = class_scope ? class_scope->class_pform() : 0;
	    if (!pclass)
		  continue;

	    cls->elaborate(des, const_cast<PClass*>(pclass));
      }

      pending.clear();
}

static std::vector<netclass_t*> pending_specialized_body_elaboration_;
static std::set<netclass_t*> pending_specialized_body_elaboration_set_;
static std::vector<netclass_t*> pending_specialized_method_seed_;
static std::set<netclass_t*> pending_specialized_method_seed_set_;

static bool should_seed_specialized_method_body_(perm_string name)
{
      return name == perm_string::literal("new")
	  || name == perm_string::literal("new@")
	  || name == perm_string::literal("make")
	  || name == perm_string::literal("get")
	  || name == perm_string::literal("get_type")
	  || name == perm_string::literal("get_object_type")
	  || name == perm_string::literal("get_type_name")
	  || name == perm_string::literal("type_name")
	  || name == perm_string::literal("initialize")
	  || name == perm_string::literal("m_initialize")
	  // I5 (Phase 62o): keep in sync with
	  // should_eagerly_elaborate_class_method_ in elaborate.cc —
	  // these are virtual override targets for uvm_callbacks#(T,CB).
	  || name == perm_string::literal("m_is_registered")
	  || name == perm_string::literal("m_is_for_me")
	  || name == perm_string::literal("m_am_i_a");
}

static void seed_specialized_method_bodies_(Design*des, netclass_t*cls,
					    PClass*pclass)
{
      if (!(des && cls && pclass))
	    return;
      if (cls->body_elaborating())
	    return;

      NetScope*class_scope = const_cast<NetScope*>(cls->class_scope());
      if (!class_scope)
	    return;

      cls->set_body_elaborating(true);

      for (map<perm_string,PFunction*>::iterator cur = pclass->funcs.begin()
		 ; cur != pclass->funcs.end() ; ++cur) {
	    if (!should_seed_specialized_method_body_(cur->first))
		  continue;
	    if (cur->second->get_statement() == 0)
		  continue;
	    NetScope*scope = class_scope->child(hname_t(cur->first));
	    if (!scope)
		  continue;
	    cur->second->elaborate_sig(des, scope);
	    cur->second->elaborate(des, scope);
      }

      for (map<perm_string,PTask*>::iterator cur = pclass->tasks.begin()
		 ; cur != pclass->tasks.end() ; ++cur) {
	    if (!should_seed_specialized_method_body_(cur->first))
		  continue;
	    if (cur->second->get_statement() == 0)
		  continue;
	    NetScope*scope = class_scope->child(hname_t(cur->first));
	    if (!scope)
		  continue;
	    cur->second->elaborate_sig(des, scope);
	    cur->second->elaborate(des, scope);
      }

      cls->set_body_elaborating(false);
}

static void enqueue_pending_specialized_class_body_(netclass_t*cls)
{
      if (!cls || cls->body_elaborated() || cls->body_elaborating())
	    return;

      if (pending_specialized_body_elaboration_set_.insert(cls).second) {
	    pending_specialized_body_elaboration_.push_back(cls);
	    note_specialization_pending_peak_(pending_specialized_body_elaboration_.size());
      }
}

static void enqueue_pending_specialized_method_seed_(netclass_t*cls)
{
      if (!cls || cls->body_elaborated())
	    return;

      if (pending_specialized_method_seed_set_.insert(cls).second)
	    pending_specialized_method_seed_.push_back(cls);
}

static void flush_pending_specialized_method_seeds_(Design*des,
						    std::vector<netclass_t*>&pending)
{
      size_t idx = 0;
      while (idx < pending.size()) {
	    netclass_t*cls = pending[idx++];
	    if (!cls || cls->body_elaborated())
		  continue;

	    const NetScope*class_scope = cls->class_scope();
	    const PClass*pclass = class_scope ? class_scope->class_pform() : 0;
	    if (!pclass)
		  continue;

	    seed_specialized_method_bodies_(des, cls, const_cast<PClass*>(pclass));

	    // If the class has static variable initializers (e.g.,
	    // `local static bit m__initialized = __deferred_init()` in
	    // uvm_registry_common), the seed path alone is not enough.
	    // netclass_t::elaborate() must run to generate the $init thread
	    // that calls those initializers at simulation start.
	    // The seed already elaborated the named methods (elab_stage guard
	    // prevents double-elaboration), so this only adds the missing
	    // initialize_static $init thread and any un-seeded methods.
	    if (!pclass->type->initialize_static.empty() && !cls->body_elaborated())
		  cls->elaborate(des, const_cast<PClass*>(pclass));
      }

      pending.clear();
}

void finalize_pending_specialized_class_elaboration(Design*des)
{
      flush_pending_specialized_class_bodies_(des, pending_specialized_body_elaboration_);
      pending_specialized_body_elaboration_set_.clear();
      flush_pending_specialized_method_seeds_(des, pending_specialized_method_seed_);
      pending_specialized_method_seed_set_.clear();
}

const netclass_t* elaborate_specialized_class_type(Design*des, NetScope*call_scope,
						   const netclass_t*base_class,
						   const parmvalue_t*overrides,
						   bool fully_elaborate)
{
      static unsigned elaboration_depth = 0;

      if (!base_class || !overrides)
	    return base_class;

      const NetScope*base_scope_const = base_class->class_scope();
      NetScope*base_scope = const_cast<NetScope*>(base_scope_const);
      NetScope*definition_scope = const_cast<netclass_t*>(base_class)->definition_scope();
      const PClass*pclass = base_scope ? base_scope->class_pform() : 0;
      if (!base_scope || !definition_scope || !pclass)
	    return base_class;

      if (call_scope) {
	    const NetScope*caller_class_scope = call_scope->get_class_scope();
	    if (caller_class_scope && caller_class_scope->class_pform() == pclass &&
	        overrides_match_parameter_order_(overrides, pclass->parameter_order)) {
		  if (const netclass_t*caller_class = caller_class_scope->class_def())
			return caller_class;
	    }
      }

      static std::map<std::string,const netclass_t*> cache;
      std::ostringstream key;
	// Use the pclass (parse-tree) pointer as the stable key prefix.
	// The netclass_t (base_class) pointer is NOT stable — the same
	// parsed class can be elaborated into multiple netclass_t objects
	// when mutual-reference cycles are resolved.  pclass is the
	// unique canonical representative of the class definition.
      key << (const void*)pclass << "|";
      key << parmvalue_cache_key_(des, call_scope, overrides);
      std::string key_str = key.str();
      if (trace_specialization_key_(base_class)) {
	    cerr << pclass->get_fileline() << ": trace spec-key"
		 << " class=" << specialization_perf_base_label_(base_class)
		 << " caller=";
	    if (call_scope)
		  cerr << scope_path(call_scope);
	    else
		  cerr << "<null>";
	    cerr << " key=" << key_str << endl;
      }
	      std::map<std::string,const netclass_t*>::const_iterator cached = cache.find(key_str);
	      if (cached != cache.end()) {
		    note_specialization_cache_hit_();
		    netclass_t*cached_class = const_cast<netclass_t*>(cached->second);
		    if (!fully_elaborate) {
			  enqueue_pending_specialized_method_seed_(cached_class);
			  return cached->second;
		    }
		    const PClass*cached_pclass = cached_class->class_scope()
			  ? cached_class->class_scope()->class_pform() : 0;
		    if (elaboration_depth == 0 && cached_pclass && cached_class->scope_ready()) {
			  if (!cached_class->sig_elaborated() && !cached_class->sig_elaborating())
				cached_class->elaborate_sig(des, const_cast<PClass*>(cached_pclass));
			  if (cached_class->sig_elaborated() &&
			      !cached_class->body_elaborated() &&
			      !cached_class->body_elaborating())
			cached_class->elaborate(des, const_cast<PClass*>(cached_pclass));
	    }
	    return cached->second;
      }
      note_specialization_cache_miss_(base_class);

      class_type_t*use_type = pclass->type;
      total_spec_allocs_ += 1;
      if (total_spec_allocs_ > 8000) {
	    cerr << pclass->get_fileline() << ": sorry: "
		 << "specialization limit (8000) exceeded for class "
		 << use_type->name << "; aborting further specialization." << endl;
	    des->errors += 1;
	    return base_class;
      }
      netclass_t*use_class = new netclass_t(use_type->name, 0);
      use_class->set_interface(base_class->is_interface());

      NetScope*class_scope = new NetScope(definition_scope, hname_t(definition_scope->local_symbol()),
					  NetScope::CLASS, definition_scope->unit());
      class_scope->set_line(pclass);
      class_scope->set_class_def(use_class);
      class_scope->set_class_pform(pclass);
      use_class->set_class_scope(class_scope);
      use_class->set_definition_scope(definition_scope);
      use_class->set_virtual(use_type->virtual_class);
      if (use_type->is_covergroup_stub)
	    use_class->set_is_covergroup(true);
      if (!use_type->covergroups.empty())
	    use_class->set_has_embedded_covergroups(true);
      use_class->set_specialized_instance(true);
      set_scope_timescale(des, class_scope, pclass);
      cache[key_str] = use_class;

      class_scope->add_typedefs(&pclass->typedefs);
      collect_scope_parameters(des, class_scope, pclass->parameters);
      for (std::map<perm_string,NetScope::param_expr_t>::iterator cur = class_scope->parameters.begin()
		 ; cur != class_scope->parameters.end() ; ++cur) {
	    if (!cur->second.local_flag)
		  cur->second.overridable = true;
      }
      apply_specialized_class_overrides_(des, class_scope, overrides,
					 call_scope ? call_scope : definition_scope,
					 &pclass->parameter_order);
      class_scope->evaluate_parameters(des);
      if (const char*trace = getenv("IVL_UVM_CB_SPEC_TRACE")) {
	    if (pclass->type
	        && (pclass->type->name == perm_string::literal("uvm_callbacks")
	         || pclass->type->name == perm_string::literal("uvm_typed_callbacks")
	         || pclass->type->name == perm_string::literal("uvm_derived_callbacks")
	         || pclass->type->name == perm_string::literal("uvm_callback_iter"))) {
		  cerr << pclass->get_fileline() << ": trace: uvm_cb_spec class="
		       << scope_path(class_scope)
		       << " base=" << pclass->type->name
		       << " caller=";
		  if (call_scope)
			cerr << scope_path(call_scope);
		  else
			cerr << "<null>";
		  cerr << " trace=" << trace
		       << " overrides=" << parmvalue_cache_key_(des, call_scope, overrides)
		       << endl;
		  for (std::list<perm_string>::const_iterator cur = pclass->parameter_order.begin()
			     ; cur != pclass->parameter_order.end() ; ++cur) {
			auto param_it = class_scope->parameters.find(*cur);
			if (param_it == class_scope->parameters.end())
			      continue;
			cerr << "  param " << *cur << " type_flag=" << param_it->second.type_flag
			     << " expr=";
			if (param_it->second.val_expr)
			      cerr << *param_it->second.val_expr;
			else
			      cerr << "<null>";
			cerr << " ivl_type=";
			if (param_it->second.ivl_type)
			      param_it->second.ivl_type->debug_dump(cerr);
			else
			      cerr << "<null>";
			cerr << endl;
		  }
	    }
      }

      const netclass_t*use_base_class = 0;
      if (use_type->base_type) {
	    ivl_type_t base_type = use_type->base_type->elaborate_type(des, class_scope);
	    use_base_class = dynamic_cast<const netclass_t*>(base_type);
	    if (!use_base_class) {
		  perm_string base_name;
		  if (const typeref_t*base_ref = dynamic_cast<const typeref_t*>(use_type->base_type.get())) {
			if (typedef_t*base_td = base_ref->typedef_ref())
			      base_name = base_td->name;
		  } else if (const class_type_t*base_class_type =
			     dynamic_cast<const class_type_t*>(use_type->base_type.get())) {
			base_name = base_class_type->name;
		  }

		  if (base_name) {
			use_base_class = class_scope->find_class(des, base_name);
			if (!use_base_class)
			      use_base_class = ensure_visible_class_type(des, class_scope, base_name);
		  }
	    }
      }
      use_class->set_super(use_base_class);

      collect_scope_signals(class_scope, pclass->wires);
      elaborate_scope_events_(des, class_scope, pclass->events);
      elaborate_scope_enumerations(des, class_scope, pclass->enum_sets);

      for (std::map<perm_string,PTask*>::const_iterator cur = pclass->tasks.begin()
		 ; cur != pclass->tasks.end() ; ++cur) {
	    hname_t use_name(cur->first);
	    NetScope*method_scope = new NetScope(class_scope, use_name, NetScope::TASK);
	    method_scope->is_auto(true);
	    method_scope->is_virtual_method(cur->second->is_virtual_method());
	    method_scope->set_line(cur->second);
	    method_scope->add_imports(&cur->second->explicit_imports);
	    cur->second->elaborate_scope(des, method_scope);
      }

      for (std::map<perm_string,PFunction*>::const_iterator cur = pclass->funcs.begin()
		 ; cur != pclass->funcs.end() ; ++cur) {
		    hname_t use_name(cur->first);
		    NetScope*method_scope = new NetScope(class_scope, use_name, NetScope::FUNC);
		    method_scope->is_auto(true);
	    method_scope->is_virtual_method(cur->second->is_virtual_method());
	    method_scope->set_line(cur->second);
	    method_scope->add_imports(&cur->second->explicit_imports);
		    cur->second->elaborate_scope(des, method_scope);
	      }

      const char*trace = getenv("IVL_CLASS_METHOD_TRACE");
      if (trace && *trace && pclass->pscope_name() == perm_string::literal("uvm_reg_frontdoor")) {
	    cerr << pclass->get_fileline() << ": trace specialized-class-scope"
		 << " class=" << pclass->pscope_name()
		 << " pclass=" << (const void*)pclass
		 << " netclass=" << (const void*)use_class
		 << " scope_ready=" << use_class->scope_ready()
		 << " class_scope_ptr=" << (const void*)class_scope
		 << " class_scope=" << scope_path(class_scope)
		 << " tasks={";
	    bool first = true;
	    for (std::map<perm_string,PTask*>::const_iterator cur = pclass->tasks.begin()
		       ; cur != pclass->tasks.end() ; ++cur) {
		  if (!first)
			cerr << ", ";
		  first = false;
		  cerr << cur->first;
	    }
	    cerr << "} children={";
	    first = true;
	    for (const auto&cur : class_scope->children()) {
		  if (!first)
			cerr << ", ";
		  first = false;
		  cerr << cur.first.peek_name();
		  if (cur.second)
			cerr << ":" << cur.second->type();
	    }
	    cerr << "}" << endl;
      }

	      use_class->set_scope_ready(true);

	      if (!fully_elaborate) {
		    enqueue_pending_specialized_method_seed_(use_class);
		    return use_class;
	      }

	      // Specialized classes created during expression/type lowering
	      // still need method signatures so target export can emit real
	      // function/task scopes even if full body elaboration is deferred.
	      use_class->elaborate_sig(des, const_cast<PClass*>(pclass));

      // Phase 50: Always queue specialized-class body elaboration.  The
      // previous code ran depth==0 eagerly, which fires while $unit-level
      // typedefs are being processed.  At that moment, root MODULE scopes
      // are present but their bodies haven't elaborated, so child instances
      // (notably virtual-interface targets) are not yet visible to method
      // dispatch.  Queueing defers the body until finalize_pending_
      // specialized_class_elaboration, which runs after all root bodies —
      // letting interface instances be reachable for method_from_name lookup.
      enqueue_pending_specialized_class_body_(use_class);

      return use_class;
}

static void elaborate_scope_class(Design*des, NetScope*scope, PClass*pclass)
{
      if (const NetScope*existing_scope = scope->child_byname(pclass->pscope_name())) {
	    if (existing_scope->type() == NetScope::CLASS &&
	        existing_scope->class_pform() == pclass) {
		  netclass_t*existing_class =
			const_cast<netclass_t*>(existing_scope->class_def());
		  if (existing_class && !existing_class->scope_ready()) {
			complete_class_scope_in_place_(des, scope, pclass, existing_class,
						      const_cast<NetScope*>(existing_scope));
		  }
		  return;
	    }
      }

      class_type_t*use_type = pclass->type;

	// Mark this class as being elaborated so recursive lookups
	// through ensure_visible_class_type do not re-enter.
      classes_being_scope_elaborated_.insert(pclass);

      if (debug_scopes) {
	    cerr << pclass->get_fileline() <<": elaborate_scope_class: "
		 << "Elaborate scope class " << pclass->pscope_name()
		 << " within scope " << scope_path(scope)
		 << endl;
      }

      total_class_allocs_ += 1;
      netclass_t*use_class = new netclass_t(use_type->name, 0);

      NetScope*class_scope = new NetScope(scope, hname_t(pclass->pscope_name()),
					  NetScope::CLASS, scope->unit());
      class_scope->set_line(pclass);
      class_scope->set_class_def(use_class);
      class_scope->set_class_pform(pclass);
      use_class->set_class_scope(class_scope);
      use_class->set_definition_scope(scope);
      use_class->set_virtual(use_type->virtual_class);
      if (use_type->is_covergroup_stub)
	    use_class->set_is_covergroup(true);
      if (!use_type->covergroups.empty())
	    use_class->set_has_embedded_covergroups(true);
      set_scope_timescale(des, class_scope, pclass);
      scope->add_class(use_class);

      class_scope->add_typedefs(&pclass->typedefs);
      collect_scope_parameters(des, class_scope, pclass->parameters);

      const netclass_t*use_base_class = 0;
      if (use_type->base_type) {
	    ivl_type_t base_type = use_type->base_type->elaborate_type(des, class_scope);
	    use_base_class = dynamic_cast<const netclass_t *>(base_type);
	    if (!use_base_class) {
		  perm_string base_name;
		  if (const typeref_t*base_ref = dynamic_cast<const typeref_t*>(use_type->base_type.get())) {
			if (typedef_t*base_td = base_ref->typedef_ref())
			      base_name = base_td->name;
		  } else if (const class_type_t*base_class_type =
			     dynamic_cast<const class_type_t*>(use_type->base_type.get())) {
			base_name = base_class_type->name;
		  }

		  if (base_name) {
			use_base_class = class_scope->find_class(des, base_name);
			if (!use_base_class)
			      use_base_class = ensure_visible_class_type(des, class_scope, base_name);
		  }
	    }
	    if (!use_base_class) {
		  cerr << pclass->get_fileline() << ": error: "
		       << "Base type of " << use_type->name
		       << " is not a class." << endl;
			  des->errors += 1;
		    }
	      }
      use_class->set_super(use_base_class);

      collect_scope_signals(class_scope, pclass->wires);

        // Class named events (e.g. "event m_event;") are stored in the
        // pform class scope event table, but need to be emitted into the
        // elaborated class NetScope so method symbol lookup can resolve
        // @m_event / ->m_event / m_event references.
      elaborate_scope_events_(des, class_scope, pclass->events);

	// Elaborate enum types declared in the class. We need these
	// now because enumeration constants can be used during scope
	// elaboration.
      if (debug_scopes) {
	    cerr << pclass->get_fileline() << ": elaborate_scope_class: "
		 << "Elaborate " << pclass->enum_sets.size() << " enumerations"
		 << " in class " << scope_path(class_scope)
		 << ", scope=" << scope_path(scope) << "."
		 << endl;
      }
      elaborate_scope_enumerations(des, class_scope, pclass->enum_sets);

      for (map<perm_string,PTask*>::iterator cur = pclass->tasks.begin()
		 ; cur != pclass->tasks.end() ; ++cur) {

	    hname_t use_name (cur->first);
	    NetScope*method_scope = new NetScope(class_scope, use_name, NetScope::TASK);

	      // Task methods are always automatic...
	    if (!cur->second->is_auto()) {
		  cerr << "error: Lifetime of method `"
		       << scope_path(method_scope)
		       << "` must not be static" << endl;
		  des->errors += 1;
	    }
	    method_scope->is_auto(true);
	    method_scope->is_virtual_method(cur->second->is_virtual_method());
	    method_scope->set_line(cur->second);
	    method_scope->add_imports(&cur->second->explicit_imports);

	    if (debug_scopes) {
		  cerr << cur->second->get_fileline() << ": elaborate_scope_class: "
		       << "Elaborate method (task) scope "
		       << scope_path(method_scope) << endl;
	    }

	    cur->second->elaborate_scope(des, method_scope);
      }

      for (map<perm_string,PFunction*>::iterator cur = pclass->funcs.begin()
		 ; cur != pclass->funcs.end() ; ++cur) {

	    hname_t use_name (cur->first);
	    NetScope*method_scope = new NetScope(class_scope, use_name, NetScope::FUNC);

	      // Function methods are always automatic...
	    if (!cur->second->is_auto()) {
		  cerr << "error: Lifetime of method `"
		       << scope_path(method_scope)
		       << "` must not be static" << endl;
		  des->errors += 1;
	    }
	    method_scope->is_auto(true);
	    method_scope->is_virtual_method(cur->second->is_virtual_method());
	    method_scope->set_line(cur->second);
	    method_scope->add_imports(&cur->second->explicit_imports);

	    if (debug_scopes) {
		  cerr << cur->second->get_fileline() << ": elaborate_scope_class: "
		       << "Elaborate method (function) scope "
		       << scope_path(method_scope) << endl;
	    }

	    cur->second->elaborate_scope(des, method_scope);
      }

      const char*trace = getenv("IVL_CLASS_METHOD_TRACE");
      if (trace && *trace && pclass->pscope_name() == perm_string::literal("uvm_reg_frontdoor")) {
	    cerr << pclass->get_fileline() << ": trace class-scope"
		 << " class=" << pclass->pscope_name()
		 << " pclass=" << (const void*)pclass
		 << " netclass=" << (const void*)use_class
		 << " scope_ready=" << use_class->scope_ready()
		 << " class_scope_ptr=" << (const void*)class_scope
		 << " class_scope=" << scope_path(class_scope)
		 << " tasks={";
	    bool first = true;
	    for (map<perm_string,PTask*>::iterator cur = pclass->tasks.begin()
		       ; cur != pclass->tasks.end() ; ++cur) {
		  if (!first)
			cerr << ", ";
		  first = false;
		  cerr << cur->first;
	    }
	    cerr << "} children={";
	    first = true;
	    for (const auto&cur : class_scope->children()) {
		  if (!first)
			cerr << ", ";
		  first = false;
		  cerr << cur.first.peek_name();
		  if (cur.second)
			cerr << ":" << cur.second->type();
	    }
	    cerr << "}" << endl;
      }

      classes_being_scope_elaborated_.erase(pclass);
}

static void elaborate_scope_classes(Design*des, NetScope*scope,
				    const vector<PClass*>&classes)
{
      if (debug_scopes) {
	    cerr << scope->get_fileline() << ": " << __func__ << ": "
		 << "Elaborate " << classes.size() << " classes"
		 << " in scope " << scope_path(scope) << "."
		 << endl;
      }

      for (size_t idx = 0 ; idx < classes.size() ; idx += 1) {
	    blend_class_constructors(classes[idx]);
	    elaborate_scope_class(des, scope, classes[idx]);
      }
}

static void replace_scope_parameters(Design *des, NetScope*scope, const LineInfo&loc,
				     const Module::replace_t&replacements)
{
      if (debug_scopes) {
	    cerr << scope->get_fileline() << ": " << __func__ << ": "
		 << "Replace scope parameters for " << scope_path(scope) << "." << endl;
      }

      for (Module::replace_t::const_iterator cur = replacements.begin()
		 ; cur != replacements.end() ;  ++ cur ) {

	    PExpr*val = (*cur).second;
	    if (val == 0) {
		  cerr << loc.get_fileline() << ": internal error: "
		       << "Missing expression in parameter replacement for "
		       << (*cur).first << endl;;
	    }
	    ivl_assert(loc, val);
	    if (debug_scopes) {
		  cerr << loc.get_fileline() << ": debug: "
		       << "Replace " << (*cur).first
		       << " with expression " << *val
		       << " from " << val->get_fileline() << "." << endl;
		  cerr << loc.get_fileline() << ":      : "
		       << "Type=" << val->expr_type() << endl;
	    }
	    scope->replace_parameter(des, (*cur).first, val, scope->parent());
      }
}

static void elaborate_scope_events_(Design*des, NetScope*scope,
                                    const map<perm_string,PEvent*>&events)
{
      for (map<perm_string,PEvent*>::const_iterator et = events.begin()
		 ; et != events.end() ;  ++ et ) {

	    (*et).second->elaborate_scope(des, scope);
      }
}

static void complete_class_scope_in_place_(Design*des, NetScope*scope,
					   PClass*pclass, netclass_t*use_class,
					   NetScope*class_scope)
{
	// If this class is already being elaborated higher up the
	// call stack, skip to avoid infinite recursion.
      if (classes_being_scope_elaborated_.count(pclass))
	    return;
      classes_being_scope_elaborated_.insert(pclass);

      class_type_t*use_type = pclass->type;

      const netclass_t*use_base_class = 0;
      if (use_type->base_type) {
	    ivl_type_t base_type = use_type->base_type->elaborate_type(des, class_scope);
	    use_base_class = dynamic_cast<const netclass_t*>(base_type);
	    if (!use_base_class) {
		  perm_string base_name;
		  if (const typeref_t*base_ref =
			      dynamic_cast<const typeref_t*>(use_type->base_type.get())) {
			if (typedef_t*base_td = base_ref->typedef_ref())
			      base_name = base_td->name;
		  } else if (const class_type_t*base_class_type =
			     dynamic_cast<const class_type_t*>(use_type->base_type.get())) {
			base_name = base_class_type->name;
		  }

		  if (base_name) {
			use_base_class = class_scope->find_class(des, base_name);
			if (!use_base_class)
			      use_base_class = ensure_visible_class_type(des, class_scope, base_name);
		  }
	    }
	    if (!use_base_class) {
		  cerr << pclass->get_fileline() << ": error: "
		       << "Base type of " << use_type->name
		       << " is not a class." << endl;
		  des->errors += 1;
	    }
      }
      use_class->set_super(use_base_class);

      for (map<perm_string,PTask*>::iterator cur = pclass->tasks.begin()
		 ; cur != pclass->tasks.end() ; ++cur) {
	    hname_t use_name(cur->first);
	    NetScope*method_scope = class_scope->child(use_name);
	    if (!method_scope)
		  method_scope = new NetScope(class_scope, use_name, NetScope::TASK);
	    method_scope->is_auto(true);
	    method_scope->is_virtual_method(cur->second->is_virtual_method());
	    method_scope->set_line(cur->second);
	    method_scope->add_imports(&cur->second->explicit_imports);
	    cur->second->elaborate_scope(des, method_scope);
      }

      for (map<perm_string,PFunction*>::iterator cur = pclass->funcs.begin()
		 ; cur != pclass->funcs.end() ; ++cur) {
	    hname_t use_name(cur->first);
	    NetScope*method_scope = class_scope->child(use_name);
	    if (!method_scope)
		  method_scope = new NetScope(class_scope, use_name, NetScope::FUNC);
	    method_scope->is_auto(true);
	    method_scope->is_virtual_method(cur->second->is_virtual_method());
	    method_scope->set_line(cur->second);
	    method_scope->add_imports(&cur->second->explicit_imports);
	    cur->second->elaborate_scope(des, method_scope);
      }

      use_class->set_scope_ready(true);
      classes_being_scope_elaborated_.erase(pclass);
}

static void elaborate_scope_task(Design*des, NetScope*scope, PTask*task)
{
      hname_t use_name( task->pscope_name() );

      NetScope*task_scope = new NetScope(scope, use_name, NetScope::TASK);
      task_scope->is_auto(task->is_auto());
      task_scope->is_virtual_method(task->is_virtual_method());
      task_scope->set_line(task);
      task_scope->add_imports(&task->explicit_imports);

      if (debug_scopes) {
	    cerr << task->get_fileline() << ": elaborate_scope_task: "
		 << "Elaborate task scope " << scope_path(task_scope) << endl;
      }

      task->elaborate_scope(des, task_scope);
}

static void elaborate_scope_tasks(Design*des, NetScope*scope,
				  const map<perm_string,PTask*>&tasks)
{
      typedef map<perm_string,PTask*>::const_iterator tasks_it_t;

      for (tasks_it_t cur = tasks.begin()
		 ; cur != tasks.end() ;  ++ cur ) {

	    elaborate_scope_task(des, scope, cur->second);
      }

}

static void elaborate_scope_func(Design*des, NetScope*scope, PFunction*task)
{
      hname_t use_name( task->pscope_name() );

      NetScope*task_scope = new NetScope(scope, use_name, NetScope::FUNC);
      task_scope->is_auto(task->is_auto());
      task_scope->is_virtual_method(task->is_virtual_method());
      task_scope->set_line(task);
      task_scope->add_imports(&task->explicit_imports);

      if (debug_scopes) {
	    cerr << task->get_fileline() << ": elaborate_scope_func: "
		 << "Elaborate function scope " << scope_path(task_scope)
		 << endl;
      }

      task->elaborate_scope(des, task_scope);
}

static void elaborate_scope_funcs(Design*des, NetScope*scope,
				  const map<perm_string,PFunction*>&funcs)
{
      typedef map<perm_string,PFunction*>::const_iterator funcs_it_t;

      for (funcs_it_t cur = funcs.begin()
		 ; cur != funcs.end() ;  ++ cur ) {

	    elaborate_scope_func(des, scope, cur->second);
      }

}

class generate_schemes_work_item_t : public elaborator_work_item_t {
    public:
      generate_schemes_work_item_t(Design*des__, NetScope*scope, Module*mod)
      : elaborator_work_item_t(des__), scope_(scope), mod_(mod)
      { }

      void elaborate_runrun() override
      {
	    if (debug_scopes)
		  cerr << mod_->get_fileline() << ": debug: "
		       << "Processing generate schemes for "
		       << scope_path(scope_) << endl;

	      // Generate schemes can create new scopes in the form of
	      // generated code. Scan the generate schemes, and *generate*
	      // new scopes, which is slightly different from simple
	      // elaboration.
	    typedef list<PGenerate*>::const_iterator generate_it_t;
	    for (generate_it_t cur = mod_->generate_schemes.begin()
		       ; cur != mod_->generate_schemes.end() ; ++ cur ) {
		  (*cur) -> generate_scope(des, scope_);
	    }
      }

    private:
	// The scope_ is the scope that contains the generate scheme
	// we are to work on. the mod_ is the Module definition for
	// that scope, and contains the parsed generate schemes.
      NetScope*scope_;
      Module*mod_;
};

bool PPackage::elaborate_scope(Design*des, NetScope*scope)
{
      if (debug_scopes) {
	    cerr << get_fileline() << ": PPackage::elaborate_scope: "
		 << "Elaborate package " << scope_path(scope) << "." << endl;
      }

      scope->add_typedefs(&typedefs);

      collect_scope_parameters(des, scope, parameters);

      collect_scope_signals(scope, wires);

      if (debug_scopes) {
	    cerr << get_fileline() << ": PPackage::elaborate_scope: "
		 << "Elaborate " << enum_sets.size() << " enumerations"
		 << " in package scope " << scope_path(scope) << "."
		 << endl;
      }
      elaborate_scope_enumerations(des, scope, enum_sets);

      elaborate_scope_classes(des, scope, classes_lexical);
      elaborate_scope_funcs(des, scope, funcs);
      elaborate_scope_tasks(des, scope, tasks);
      elaborate_scope_events_(des, scope, events);
      return true;
}

bool Module::elaborate_scope(Design*des, NetScope*scope,
			     const replace_t&replacements)
{
      if (debug_scopes) {
	    cerr << get_fileline() << ": Module::elaborate_scope: "
		 << "Elaborate " << scope_path(scope) << "." << endl;
      }

      scope->add_typedefs(&typedefs);

	// Add the genvars to the scope.
      typedef map<perm_string,LineInfo*>::const_iterator genvar_it_t;
      for (genvar_it_t cur = genvars.begin(); cur != genvars.end(); ++ cur ) {
	    scope->add_genvar((*cur).first, (*cur).second);
      }

	// Scan the parameters in the module, and store the information
	// needed to evaluate the parameter expressions. The expressions
	// will be evaluated later, once all parameter overrides for this
	// module have been done.

      collect_scope_parameters(des, scope, parameters);

      collect_scope_specparams(des, scope, specparams);

      collect_scope_signals(scope, wires);

	// Run parameter replacements that were collected from the
	// containing scope and meant for me.

      replace_scope_parameters(des, scope, *this, replacements);

      elaborate_scope_enumerations(des, scope, enum_sets);

      ivl_assert(*this, classes.size() == classes_lexical.size());
      elaborate_scope_classes(des, scope, classes_lexical);

	// Run through the defparams for this module and save the result
	// in a table for later final override.

      typedef list<Module::named_expr_t>::const_iterator defparms_iter_t;
      for (defparms_iter_t cur = defparms.begin()
		 ; cur != defparms.end() ; ++ cur ) {
	    scope->defparams.push_back(make_pair(cur->first, cur->second));
      }

	// Evaluate the attributes. Evaluate them in the scope of the
	// module that the attribute is attached to. Is this correct?
      unsigned nattr;
      attrib_list_t*attr = evaluate_attributes(attributes, nattr, des, scope);

      for (unsigned idx = 0 ;  idx < nattr ;  idx += 1)
	    scope->attribute(attr[idx].key, attr[idx].val);

      delete[]attr;

	// Generate schemes need to have their scopes elaborated, but
	// we can not do that until defparams are run, so push it off
	// into an elaborate work item.
      if (debug_scopes)
	    cerr << get_fileline() << ": " << __func__ << ": "
		 << "Schedule generates within " << scope_path(scope)
		 << " for elaboration after defparams." << endl;

      des->elaboration_work_list.push_back(new generate_schemes_work_item_t(des, scope, this));

	// Tasks introduce new scopes, so scan the tasks in this
	// module. Create a scope for the task and pass that to the
	// elaborate_scope method of the PTask for detailed
	// processing.

      elaborate_scope_tasks(des, scope, tasks);


	// Functions are very similar to tasks, at least from the
	// perspective of scopes. So handle them exactly the same
	// way.

      elaborate_scope_funcs(des, scope, funcs);

	// Look for implicit modules and implicit gates for them.

      for (map<perm_string,Module*>::iterator cur = nested_modules.begin()
		 ; cur != nested_modules.end() ; ++cur) {
	      // Skip modules that must be explicitly instantiated.
	    if (cur->second->port_count() > 0)
		  continue;

	    PGModule*nested_gate = new PGModule(cur->second, cur->second->mod_name());
	    nested_gate->set_line(*cur->second);
	    gates_.push_back(nested_gate);
      }

	// Gates include modules, which might introduce new scopes, so
	// scan all of them to create those scopes.

      typedef list<PGate*>::const_iterator gates_it_t;
      for (gates_it_t cur = gates_.begin()
		 ; cur != gates_.end() ; ++ cur ) {

	    (*cur) -> elaborate_scope(des, scope);
      }


	// initial and always blocks may contain begin-end and
	// fork-join blocks that can introduce scopes. Therefore, I
	// get to scan processes here.

      typedef list<PProcess*>::const_iterator proc_it_t;

      for (proc_it_t cur = behaviors.begin()
		 ; cur != behaviors.end() ; ++ cur ) {

	    (*cur) -> statement() -> elaborate_scope(des, scope);
      }

	// Scan through all the named events in this scope. We do not
	// need anything more than the current scope to do this
	// elaboration, so do it now. This allows for normal
	// elaboration to reference these events.

      elaborate_scope_events_(des, scope, events);

      scope->is_cell(is_cell);

      return des->errors == 0;
}

bool PGenerate::generate_scope(Design*des, NetScope*container)
{
      switch (scheme_type) {
	  case GS_LOOP:
	    return generate_scope_loop_(des, container);

	  case GS_CONDIT:
	    return generate_scope_condit_(des, container, false);

	  case GS_ELSE:
	    return generate_scope_condit_(des, container, true);

	  case GS_CASE:
	    return generate_scope_case_(des, container);

	  case GS_NBLOCK:
	    return generate_scope_nblock_(des, container);

	  case GS_CASE_ITEM:
	    cerr << get_fileline() << ": internal error: "
		 << "Case item outside of a case generate scheme?" << endl;
	    return false;

	  default:
	    cerr << get_fileline() << ": sorry: Generate of this sort"
		 << " is not supported yet!" << endl;
	    return false;
      }
}

void PGenerate::check_for_valid_genvar_value_(long value)
{
      if (generation_flag < GN_VER2005 && value < 0) {
	    cerr << get_fileline() << ": warning: A negative value (" << value
		 << ") has been assigned to genvar '" << loop_index << "'."
		 << endl;
	    cerr << get_fileline() << ":        : This is illegal in "
		    "Verilog-2001. Use at least -g2005 to remove this warning."
		 << endl;
      }
}

/*
 * This is the elaborate scope method for a generate loop.
 */
bool PGenerate::generate_scope_loop_(Design*des, NetScope*container)
{
      if (!local_index) {
	      // Check that the loop_index variable was declared in a
	      // genvar statement.
	    NetScope*cscope = container;
	    while (cscope && !cscope->find_genvar(loop_index)) {
		  if (cscope->symbol_exists(loop_index)) {
			cerr << get_fileline() << ": error: "
			     << "generate \"loop\" variable '" << loop_index
			     << "' is not a genvar in this scope." << endl;
			des->errors += 1;
			return false;
		  }
		  cscope = cscope->parent();
            }
	    if (!cscope) {
		  cerr << get_fileline() << ": error: genvar is missing for "
			  "generate \"loop\" variable '" << loop_index << "'."
		       << endl;
		  des->errors += 1;
		  return false;
	    }
      }

	// We're going to need a genvar...
      long genvar;

	// The initial value for the genvar does not need (nor can it
	// use) the genvar itself, so we can evaluate this expression
	// the same way any other parameter value is evaluated.
      NetExpr*init_ex = elab_and_eval(des, container, loop_init, -1, true);
      const NetEConst*init = dynamic_cast<NetEConst*> (init_ex);
      if (init == 0) {
	    cerr << get_fileline() << ": error: "
	            "Cannot evaluate generate \"loop\" initialization "
		    "expression: " << *loop_init << endl;
	    des->errors += 1;
	    return false;
      }
      if (! init->value().is_defined()) {
	    cerr << get_fileline() << ": error: "
	         << "Generate \"loop\" initialization expression cannot have "
		    "undefined bits. given (" << *loop_init << ")." << endl;
	    des->errors += 1;
	    return false;
      }

      genvar = init->value().as_long();
      check_for_valid_genvar_value_(genvar);
      delete init_ex;

      if (debug_scopes)
	    cerr << get_fileline() << ": debug: genvar init = " << genvar << endl;

      container->genvar_tmp = loop_index;
      container->genvar_tmp_val = genvar;
      NetExpr*test_ex = elab_and_eval(des, container, loop_test, -1, true);
      const NetEConst*test = dynamic_cast<NetEConst*>(test_ex);
      if (test == 0) {
	    cerr << get_fileline() << ": error: Cannot evaluate generate \"loop\" "
		    "conditional expression: " << *loop_test << endl;
	    des->errors += 1;
	    return false;
      }
      if (! test->value().is_defined()) {
	    cerr << get_fileline() << ": error: "
		    "Generate \"loop\" conditional expression cannot have "
	            "undefined bits. given (" << *loop_test << ")." << endl;
	    des->errors += 1;
	    return false;
      }
      unsigned long loop_count = 1;
      while (test->value().as_long()) {

	      // The actual name of the scope includes the genvar so
	      // that each instance has a unique name in the
	      // container. The format of using [] is part of the
	      // Verilog standard.
	    hname_t use_name (scope_name, genvar);
	    if (container->child(use_name)) {
		  cerr << get_fileline() << ": error: "
		          "Trying to create a duplicate generate scope named \""
		       << use_name << "\"." << endl;
		  des->errors += 1;
		  return false;
	    }

	    if (debug_scopes)
		  cerr << get_fileline() << ": debug: "
		          "Create generated scope " << use_name << endl;

	    NetScope*scope = new NetScope(container, use_name,
					  NetScope::GENBLOCK);
	    scope->set_line(get_file(), get_lineno());
	    scope->add_imports(&explicit_imports);

	      // Set in the scope a localparam for the value of the
	      // genvar within this instance of the generate
	      // block. Code within this scope thus has access to the
	      // genvar as a constant.
	    {
		  verinum genvar_verinum;
		  if (gn_strict_expr_width_flag)
			genvar_verinum = verinum(genvar, integer_width);
		  else
			genvar_verinum = verinum(genvar);
		  genvar_verinum.has_sign(true);
		  NetEConstParam*gp = new NetEConstParam(scope,
							 loop_index,
							 genvar_verinum);
		    // The file and line information should really come
		    // from the genvar statement, not the for loop.
		  scope->set_parameter(loop_index, gp, *this);
		  if (debug_scopes)
			cerr << get_fileline() << ": debug: "
			        "Create implicit localparam "
			     << loop_index << " = " << genvar_verinum << endl;
	    }

	    elaborate_subscope_(des, scope);

	      // Calculate the step for the loop variable.
	    NetExpr*step_ex = elab_and_eval(des, container, loop_step, -1, true);
	    NetEConst*step = dynamic_cast<NetEConst*>(step_ex);
	    if (step == 0) {
		  cerr << get_fileline() << ": error: Cannot evaluate generate "
		          "\"loop\" increment expression: " << *loop_step << endl;
		  des->errors += 1;
		  return false;
	    }
	    if (debug_scopes)
		  cerr << get_fileline() << ": debug: genvar step from "
		       << genvar << " to " << step->value().as_long() << endl;

	    if (! step->value().is_defined()) {
		  cerr << get_fileline() << ": error: "
		          "Generate \"loop\" increment expression cannot have "
		          "undefined bits, given (" << *loop_step << ")." << endl;
		  des->errors += 1;
		  return false;
	    }
	    long next_genvar;
	    next_genvar = step->value().as_long();
	    if (next_genvar == genvar) {
		  cerr << get_fileline() << ": error: "
		       << "The generate \"loop\" is not incrementing. The "
		          "previous and next genvar values are ("
		       << genvar << ")." << endl;
		  des->errors += 1;
		  return false;
	    }
	    genvar = next_genvar;
	    check_for_valid_genvar_value_(genvar);
	    container->genvar_tmp_val = genvar;
	    delete step;
	    delete test_ex;
	    test_ex = elab_and_eval(des, container, loop_test, -1, true);
	    test = dynamic_cast<NetEConst*>(test_ex);
	    ivl_assert(*this, test);
	    if (! test->value().is_defined()) {
		  cerr << get_fileline() << ": error: "
		          "The generate \"loop\" conditional expression cannot have "
		          "undefined bits. given (" << *loop_test << ")." << endl;
		  des->errors += 1;
		  return false;
	    }

	    // If there are half a million iterations this is likely an infinite loop!
	    if (loop_count > 500000) {
		  cerr << get_fileline() << ": error: "
		       << "Probable infinite loop detected in generate \"loop\". "
		          "It has run for " << loop_count
		       << " iterations." << endl;
		  des->errors += 1;
		  return false;
	    }
	    ++loop_count;
      }

	// Clear the genvar_tmp field in the scope to reflect that the
	// genvar is no longer valid for evaluating expressions.
      container->genvar_tmp = perm_string();

      return true;
}

bool PGenerate::generate_scope_condit_(Design*des, NetScope*container, bool else_flag)
{
      NetExpr*test_ex = elab_and_eval(des, container, loop_test, -1, true);
      const NetEConst*test = dynamic_cast<NetEConst*> (test_ex);
      if (test == 0) {
	    cerr << get_fileline() << ": error: Cannot evaluate genvar"
		 << " conditional expression: " << *loop_test << endl;
	    des->errors += 1;
	    return false;
      }

	// If the condition evaluates as false, then do not create the
	// scope.
      if ( (test->value().as_long() == 0 && !else_flag)
	|| (test->value().as_long() != 0 &&  else_flag) ) {
	    if (debug_scopes)
		  cerr << get_fileline() << ": debug: Generate condition "
		       << (else_flag? "(else)" : "(if)")
		       << " value=" << test->value() << ": skip generation"
		       << endl;
	    delete test_ex;
	    return true;
      }

      hname_t use_name (scope_name);
      if (debug_scopes)
	    cerr << get_fileline() << ": debug: Generate condition "
		 << (else_flag? "(else)" : "(if)")
		 << " value=" << test->value() << ": Generate scope="
		 << use_name << endl;

      if (directly_nested) {
	    if (debug_scopes)
		  cerr << get_fileline() << ": debug: Generate condition "
		       << (else_flag? "(else)" : "(if)")
		       << " detected direct nesting." << endl;
	    elaborate_subscope_direct_(des, container);
	    return true;
      }

	// If this is not directly nested, then generate a scope
	// for myself. That is what I will pass to the subscope.
      NetScope*scope = new NetScope(container, use_name, NetScope::GENBLOCK);
      scope->set_line(get_file(), get_lineno());
      scope->add_imports(&explicit_imports);

      elaborate_subscope_(des, scope);

      return true;
}

bool PGenerate::generate_scope_case_(Design*des, NetScope*container)
{
      NetExpr*case_value_ex = elab_and_eval(des, container, loop_test, -1, true);
      NetEConst*case_value_co = dynamic_cast<NetEConst*>(case_value_ex);
      if (case_value_co == 0) {
	    cerr << get_fileline() << ": error: Cannot evaluate genvar case"
		 << " expression: " << *loop_test << endl;
	    des->errors += 1;
	    return false;
      }

      if (debug_scopes)
	    cerr << get_fileline() << ": debug: Generate case "
		 << "switch value=" << case_value_co->value() << endl;

      PGenerate*default_item = 0;

      typedef list<PGenerate*>::const_iterator generator_it_t;
      generator_it_t cur = generate_schemes.begin();
      while (cur != generate_schemes.end()) {
	    PGenerate*item = *cur;
	    ivl_assert(*item, item->scheme_type == PGenerate::GS_CASE_ITEM);

	      // Detect that the item is a default.
	    if (item->item_test.size() == 0) {
		  default_item = item;
		  ++ cur;
		  continue;
	    }

	    bool match_flag = false;
	    for (unsigned idx = 0 ; idx < item->item_test.size() && !match_flag ; idx +=1 ) {
		  NetExpr*item_value_ex = elab_and_eval(des, container,
                                                        item->item_test[idx],
                                                        -1, true);
		  NetEConst*item_value_co = dynamic_cast<NetEConst*>(item_value_ex);
		  if (item_value_co == 0) {
			cerr << get_fileline() << ": error: Cannot evaluate "
			     << " genvar case item expression: "
			     << *item->item_test[idx] << endl;
			des->errors += 1;
			return false;
		  }

		  if (debug_scopes)
			cerr << get_fileline() << ": debug: Generate case "
			     << "item value=" << item_value_co->value() << endl;

		  if (case_value_co->value() == item_value_co->value())
			match_flag = true;
		  delete item_value_co;
	    }

	      // If we stumble on the item that matches, then break out now.
	    if (match_flag)
		  break;

	    ++ cur;
      }

      delete case_value_co;

      PGenerate*item = (cur == generate_schemes.end())? default_item : *cur;
      if (item == 0) {
	    cerr << get_fileline() << ": debug: "
		 << "No generate items found" << endl;
	    return true;
      }

      if (debug_scopes)
	    cerr << get_fileline() << ": debug: "
		 << "Generate case matches item at "
		 << item->get_fileline() << endl;

	// The name of the scope to generate, whatever that item is.
      hname_t use_name (item->scope_name);

      if (item->directly_nested) {
	    if (debug_scopes)
		  cerr << get_fileline() << ": debug: Generate case item " << scope_name
		       << " detected direct nesting." << endl;
	    item->elaborate_subscope_direct_(des, container);
	    return true;
      }

      if (debug_scopes) {
	    cerr << get_fileline() << ": PGenerate::generate_scope_case_: "
		 << "Generate subscope " << use_name
		 << " and elaborate." << endl;
      }

      NetScope*scope = new NetScope(container, use_name,
				    NetScope::GENBLOCK);
      scope->set_line(get_file(), get_lineno());
      scope->add_imports(&explicit_imports);

      item->elaborate_subscope_(des, scope);

      return true;
}

bool PGenerate::generate_scope_nblock_(Design*des, NetScope*container)
{
      hname_t use_name (scope_name);
      if (debug_scopes)
	    cerr << get_fileline() << ": debug: Generate named block "
		 << ": Generate scope=" << use_name << endl;

      NetScope*scope = new NetScope(container, use_name,
				    NetScope::GENBLOCK);
      scope->set_line(get_file(), get_lineno());
      scope->add_imports(&explicit_imports);

      elaborate_subscope_(des, scope);

      return true;
}

void PGenerate::elaborate_subscope_direct_(Design*des, NetScope*scope)
{
      typedef list<PGenerate*>::const_iterator generate_it_t;
      for (generate_it_t cur = generate_schemes.begin()
		 ; cur != generate_schemes.end() ; ++ cur ) {
	    PGenerate*curp = *cur;
	    if (debug_scopes) {
		  cerr << get_fileline() << ": elaborate_subscope_direct_: "
		       << "Elaborate direct subscope " << curp->scope_name
		       << " within scope " << scope_name << endl;
	    }
	    curp -> generate_scope(des, scope);
      }
}

void PGenerate::elaborate_subscope_(Design*des, NetScope*scope)
{
      scope->add_typedefs(&typedefs);

	// Add the genvars to this scope.
      typedef map<perm_string,LineInfo*>::const_iterator genvar_it_t;
      for (genvar_it_t cur = genvars.begin(); cur != genvars.end(); ++ cur ) {
	    scope->add_genvar((*cur).first, (*cur).second);
      }

	// Elaborate enum types declared inside the generate block so their
	// named values (e.g., IsStd, SigInt) are visible inside always_comb
	// and always_ff blocks that live in the same generate scope.
      elaborate_scope_enumerations(des, scope, enum_sets);

	// Scan the parameters in this scope, and store the information
        // needed to evaluate the parameter expressions. The expressions
	// will be evaluated later, once all parameter overrides for this
	// module have been done.
      collect_scope_parameters(des, scope, parameters);

      collect_scope_signals(scope, wires);

	// Run through the defparams for this scope and save the result
	// in a table for later final override.

      typedef list<PGenerate::named_expr_t>::const_iterator defparms_iter_t;
      for (defparms_iter_t cur = defparms.begin()
		 ; cur != defparms.end() ; ++ cur ) {
	    scope->defparams.push_back(make_pair(cur->first, cur->second));
      }

	// Scan the generated scope for nested generate schemes,
	// and *generate* new scopes, which is slightly different
	// from simple elaboration.

      typedef list<PGenerate*>::const_iterator generate_it_t;
      for (generate_it_t cur = generate_schemes.begin()
		 ; cur != generate_schemes.end() ; ++ cur ) {
	    (*cur) -> generate_scope(des, scope);
      }

        // Scan through all the task and function declarations in this
        // scope.
      elaborate_scope_tasks(des, scope, tasks);
      elaborate_scope_funcs(des, scope, funcs);

	// Scan the generated scope for gates that may create
	// their own scopes.
      typedef list<PGate*>::const_iterator pgate_list_it_t;
      for (pgate_list_it_t cur = gates.begin()
		 ; cur != gates.end() ; ++ cur ) {
	    (*cur) ->elaborate_scope(des, scope);
      }

      typedef list<PProcess*>::const_iterator proc_it_t;
      for (proc_it_t cur = behaviors.begin()
		 ; cur != behaviors.end() ; ++ cur ) {
	    (*cur) -> statement() -> elaborate_scope(des, scope);
      }

	// Scan through all the named events in this scope.
      elaborate_scope_events_(des, scope, events);

      if (debug_scopes)
	    cerr << get_fileline() << ": debug: Generated scope " << scope_path(scope)
		 << " for generate block " << scope_name << endl;

	// Save the scope that we created, for future use.
      scope_list_.push_back(scope);
}

class delayed_elaborate_scope_mod_instances : public elaborator_work_item_t {

    public:
      delayed_elaborate_scope_mod_instances(Design*des__,
					    const PGModule*obj,
					    Module*mod,
					    NetScope*sc)
      : elaborator_work_item_t(des__), obj_(obj), mod_(mod), sc_(sc)
      { }
      ~delayed_elaborate_scope_mod_instances() override { }

      virtual void elaborate_runrun() override;

    private:
      const PGModule*obj_;
      Module*mod_;
      NetScope*sc_;
};

void delayed_elaborate_scope_mod_instances::elaborate_runrun()
{
      if (debug_scopes)
	    cerr << obj_->get_fileline() << ": debug: "
		 << "Resume scope elaboration of instances of "
		 << mod_->mod_name() << "." << endl;

      obj_->elaborate_scope_mod_instances_(des, mod_, sc_);
}

/*
 * Here we handle the elaborate scope of a module instance. The caller
 * has already figured out that this "gate" is a module, and has found
 * the module definition. The "sc" argument is the scope that will
 * contain this instance.
 */
void PGModule::elaborate_scope_mod_(Design*des, Module*mod, NetScope*sc) const
{
      if (get_name() == "") {
	    cerr << get_fileline() << ": error: Instantiation of module "
		 << mod->mod_name() << " requires an instance name." << endl;
	    des->errors += 1;
	    return;
      }

	// Missing module instance names have already been rejected.
      ivl_assert(*this, get_name() != "");

	// check for recursive instantiation by scanning the current
	// scope and its parents. Look for a module instantiation of
	// the same module, but farther up in the scope.
      unsigned rl_count = 0;
      bool in_genblk = false;
      for (NetScope*scn = sc ;  scn ;  scn = scn->parent()) {
	      // We need to know if we are inside a generate block to allow
	      // recursive instances.
	    if (scn->type() == NetScope::GENBLOCK) {
		  in_genblk = true;
		  continue;
	    }

	    if (scn->type() != NetScope::MODULE) continue;

	    if (strcmp(mod->mod_name(), scn->module_name()) != 0) continue;

	      // We allow nested scopes if they are inside a generate block,
	      // but only to a certain nesting depth.
	    if (in_genblk) {
		  rl_count += 1;
		  if (rl_count > recursive_mod_limit) {
			cerr << get_fileline() << ": error: instance "
			     << scope_path(sc) << "." << get_name()
			     << " of module " << mod->mod_name()
			     << " is nested too deep." << endl;
			cerr << get_fileline() << ":      : check for "
			        "proper recursion termination or increase the "
			        "limit (" << recursive_mod_limit
			     << ") with the -pRECURSIVE_MOD_LIMIT flag."
			     << endl;
			des->errors += 1;
			return;
		  }
		  continue;
	    }

	    cerr << get_fileline() << ": error: You can not instantiate "
		 << "module " << mod->mod_name() << " within itself." << endl;
	    cerr << get_fileline() << ":      : The offending instance is "
		 << get_name() << " within " << scope_path(scn) << "." << endl;
	    des->errors += 1;
	    return;
      }

      if (is_array()) {
	      // If there are expressions to evaluate in order to know
	      // the actual number of instances that will be
	      // instantiated, then we have to delay further scope
	      // elaboration until after defparams (above me) are
	      // run. Do that by appending a work item to the
	      // elaboration work list.
	    if (debug_scopes)
		  cerr << get_fileline() << ": debug: delay elaborate_scope"
		       << " of array of " << get_name()
		       << " in scope " << scope_path(sc) << "." << endl;

	    elaborator_work_item_t*tmp
		  = new delayed_elaborate_scope_mod_instances(des, this, mod, sc);
	    des->elaboration_work_list.push_back(tmp);

      } else {
	      // If there are no expressions that need to be evaluated
	      // to elaborate the scope of this next instances, then
	      // get right to it.
	    elaborate_scope_mod_instances_(des, mod, sc);
      }
}

/*
 * This method is called to process a module instantiation after basic
 * sanity testing is already complete.
 */
void PGModule::elaborate_scope_mod_instances_(Design*des, Module*mod, NetScope*sc) const
{
      long instance_low  = 0;
      long instance_high = 0;
      long instance_count = calculate_array_size_(des, sc, instance_high, instance_low);
      if (instance_count == 0)
	    return;

      NetScope::scope_vec_t instances (instance_count);

      struct attrib_list_t*attrib_list;
      unsigned attrib_list_n = 0;
      attrib_list = evaluate_attributes(attributes, attrib_list_n, des, sc);

	// Run through the module instances, and make scopes out of
	// them. Also do parameter overrides that are done on the
	// instantiation line.
      for (int idx = 0 ;  idx < instance_count ;  idx += 1) {

	    hname_t use_name (get_name());

	    if (is_array()) {
		  int instance_idx;
		  if (instance_low < instance_high)
			instance_idx = instance_low + idx;
		  else
			instance_idx = instance_low - idx;

		  use_name = hname_t(get_name(), instance_idx);
	    }

	    if (debug_scopes) {
		  cerr << get_fileline() << ": debug: Module instance " << use_name
		       << " becomes child of " << scope_path(sc)
		       << "." << endl;
	    }

	      // Create the new scope as a MODULE with my name. Note
	      // that if this is a nested module, mark it thus so that
	      // scope searches will continue into the parent scope.
	    NetScope*my_scope = new NetScope(sc, use_name, NetScope::MODULE, 0,
					     bound_type_? true : false,
					     mod->program_block,
					     mod->is_interface);
	    my_scope->set_line(get_file(), mod->get_file(),
	                       get_lineno(), mod->get_lineno());
	    my_scope->set_module_name(mod->mod_name());
	    my_scope->add_imports(&mod->explicit_imports);

	    for (unsigned adx = 0 ;  adx < attrib_list_n ;  adx += 1)
	      my_scope->attribute(attrib_list[adx].key, attrib_list[adx].val);

	    instances[idx] = my_scope;

	    set_scope_timescale(des, my_scope, mod);

	      // Look for module parameter replacements. The "replace" map
	      // maps parameter name to replacement expression that is
	      // passed. It is built up by the ordered overrides or named
	      // overrides.

	    Module::replace_t replace;

	      // Positional parameter overrides are matched to parameter
	      // names by using the param_names list of parameter
	      // names. This is an ordered list of names so the first name
	      // is parameter 0, the second parameter 1, and so on.

	    if (overrides_) {
		  ivl_assert(*this, parms_ == 0);
		  list<perm_string>::const_iterator cur
			= mod->param_names.begin();
		  list<PExpr*>::const_iterator jdx = overrides_->begin();
		  for (;;) {
			if (jdx == overrides_->end())
			      break;
			  // If we reached here we have more overrides than
			  // module parameters, so print a warning.
			if (cur == mod->param_names.end()) {
			      cerr << get_fileline() << ": warning: "
			              "ignoring "
			           << overrides_->size() -
			              mod->param_names.size()
			           << " extra parameter override(s) for "
			              "instance '" << use_name
			           << "' of module '" << mod->mod_name()
			           << "' which expects "
			           << mod->param_names.size()
			           << " parameter(s)." << endl;
			      break;
			}

		          // No expression means that the parameter is not
		          // replaced at all.
			if (*jdx)
			      replace[*cur] = *jdx;

			++ jdx;
			++ cur;
		  }
	    }

	      // Named parameter overrides carry a name with each override
	      // so the mapping into the replace list is much easier.
	    if (parms_) {
		  ivl_assert(*this, overrides_ == 0);
		  for (unsigned jdx = 0 ;  jdx < nparms_ ;  jdx += 1) {
		          // No expression means that the parameter is not
		          // replaced.
			if (parms_[jdx].parm)
			      replace[parms_[jdx].name] = parms_[jdx].parm;
		  }

	    }

	      // This call actually arranges for the description of the
	      // module type to process this instance and handle parameters
	      // and sub-scopes that might occur. Parameters are also
	      // created in that scope, as they exist. (I'll override them
	      // later.)
	    mod->elaborate_scope(des, my_scope, replace);

      }
	    delete[]attrib_list;

	/* Stash the instance array of scopes into the parent
	   scope. Later elaboration passes will use this vector to
	   further elaborate the array.

	   Note that the array is ordered from LSB to MSB. We will use
	   that fact in the main elaborate to connect things in the
	   correct order. */
      sc->instance_arrays[get_name()] = instances;
}

/*
 * The isn't really able to create new scopes, but it does create the
 * event name in the current scope, so can be done during the
 * elaborate_scope scan. Note that the name_ of the PEvent object has
 * no hierarchy, but neither does the NetEvent, until it is stored in
 * the NetScope object.
 */
void PEvent::elaborate_scope(Design*, NetScope*scope) const
{
      NetEvent*ev = new NetEvent(name_);
      ev->lexical_pos(lexical_pos_);
      ev->set_line(*this);
      scope->add_event(ev);
}

void PFunction::elaborate_scope(Design*des, NetScope*scope) const
{
      ivl_assert(*this, scope->type() == NetScope::FUNC);

        // Save a reference to the pform representation of the function
        // in case we need to perform early elaboration.
      scope->set_func_pform(this);

        // Assume the function is a constant function until we
        // find otherwise.
      scope->is_const_func(true);

      scope->add_typedefs(&typedefs);

	// Scan the parameters in the function, and store the information
        // needed to evaluate the parameter expressions.

      collect_scope_parameters(des, scope, parameters);

      collect_scope_signals(scope, wires);

	// Scan through all the named events in this scope.
      elaborate_scope_events_(des, scope, events);

      if (statement_)
	    statement_->elaborate_scope(des, scope);
}

void PTask::elaborate_scope(Design*des, NetScope*scope) const
{
      ivl_assert(*this, scope->type() == NetScope::TASK);

      scope->set_task_pform(this);

      scope->add_typedefs(&typedefs);

	// Scan the parameters in the task, and store the information
        // needed to evaluate the parameter expressions.

      collect_scope_parameters(des, scope, parameters);

      collect_scope_signals(scope, wires);

	// Scan through all the named events in this scope.
      elaborate_scope_events_(des, scope, events);

      if (statement_)
	    statement_->elaborate_scope(des, scope);
}


/*
 * The base statement does not have sub-statements and does not
 * introduce any scope, so this is a no-op.
 */
void Statement::elaborate_scope(Design*, NetScope*) const
{
}

/*
 * When I get a behavioral block, check to see if it has a name. If it
 * does, then create a new scope for the statements within it,
 * otherwise use the current scope. Use the selected scope to scan the
 * statements that I contain.
 */
void PBlock::elaborate_scope(Design*des, NetScope*scope) const
{
      NetScope*my_scope = scope;

      if (pscope_name() != 0) {
	    hname_t use_name(pscope_name());
	    if (debug_scopes)
		  cerr << get_fileline() << ": debug: "
		       << "Elaborate block scope " << use_name
		       << " within " << scope_path(scope) << endl;

	      // The scope type is begin-end or fork-join. The
	      // sub-types of fork-join are not interesting to the scope.
	    my_scope = new NetScope(scope, use_name, bl_type_!=BL_SEQ
				    ? NetScope::FORK_JOIN
				    : NetScope::BEGIN_END);
	    my_scope->set_line(get_file(), get_lineno());
	      // A block with explicitly automatic local declarations must
	      // elaborate as an automatic scope even if the parent scope is
	      // static. This is required so backend scope emission can mark
	      // fork blocks as "autofork" and allocate block-entry storage.
            my_scope->is_auto(scope->is_auto()
			      || scope_has_automatic_signal_locals_(wires));
	    my_scope->add_imports(&explicit_imports);
	    my_scope->add_typedefs(&typedefs);

	      // Scan the parameters in the scope, and store the information
	      // needed to evaluate the parameter expressions.

            collect_scope_parameters(des, my_scope, parameters);

	    collect_scope_signals(my_scope, wires);

              // Scan through all the named events in this scope.
            elaborate_scope_events_(des, my_scope, events);
      }

      for (unsigned idx = 0 ;  idx < list_.size() ;  idx += 1)
	    list_[idx] -> elaborate_scope(des, my_scope);
}

/*
 * The case statement itself does not introduce scope, but contains
 * other statements that may be named blocks. So scan the case items
 * with the elaborate_scope method.
 */
void PCase::elaborate_scope(Design*des, NetScope*scope) const
{
      ivl_assert(*this, items_);
      for (unsigned idx = 0 ;  idx < (*items_).size() ;  idx += 1) {
	    ivl_assert(*this, (*items_)[idx]);

	    if (const Statement*sp = (*items_)[idx]->stat)
		  sp -> elaborate_scope(des, scope);
      }
}

/*
 * The conditional statement (if-else) does not introduce scope, but
 * the statements of the clauses may, so elaborate_scope the contained
 * statements.
 */
void PCondit::elaborate_scope(Design*des, NetScope*scope) const
{
      if (if_)
	    if_ -> elaborate_scope(des, scope);

      if (else_)
	    else_ -> elaborate_scope(des, scope);
}

/*
 * Statements that contain a further statement but do not
 * intrinsically add a scope need to elaborate_scope the contained
 * statement.
 */
void PDelayStatement::elaborate_scope(Design*des, NetScope*scope) const
{
      if (statement_)
	    statement_ -> elaborate_scope(des, scope);
}

/*
 * Statements that contain a further statement but do not
 * intrinsically add a scope need to elaborate_scope the contained
 * statement.
 */
void PDoWhile::elaborate_scope(Design*des, NetScope*scope) const
{
      if (statement_)
	    statement_ -> elaborate_scope(des, scope);
}

/*
 * Statements that contain a further statement but do not
 * intrinsically add a scope need to elaborate_scope the contained
 * statement.
 */
void PEventStatement::elaborate_scope(Design*des, NetScope*scope) const
{
      if (statement_)
	    statement_ -> elaborate_scope(des, scope);
}

/*
 * The standard says that we create an implicit scope for foreach
 * loops, but that is just to hold the index variables, and we'll
 * handle them by creating unique names. So just jump into the
 * contained statement for scope elaboration.
 */
void PForeach::elaborate_scope(Design*des, NetScope*scope) const
{
      if (statement_)
	    statement_ -> elaborate_scope(des, scope);
}

/*
 * Statements that contain a further statement but do not
 * intrinsically add a scope need to elaborate_scope the contained
 * statement.
 */
void PForever::elaborate_scope(Design*des, NetScope*scope) const
{
      if (statement_)
	    statement_ -> elaborate_scope(des, scope);
}

/*
 * Statements that contain a further statement but do not
 * intrinsically add a scope need to elaborate_scope the contained
 * statement.
 */
void PForStatement::elaborate_scope(Design*des, NetScope*scope) const
{
      if (statement_)
	    statement_ -> elaborate_scope(des, scope);
}

/*
 * Statements that contain a further statement but do not
 * intrinsically add a scope need to elaborate_scope the contained
 * statement.
 */
void PRepeat::elaborate_scope(Design*des, NetScope*scope) const
{
      if (statement_)
	    statement_ -> elaborate_scope(des, scope);
}

/*
 * Statements that contain a further statement but do not
 * intrinsically add a scope need to elaborate_scope the contained
 * statement.
 */
void PWhile::elaborate_scope(Design*des, NetScope*scope) const
{
      if (statement_)
	    statement_ -> elaborate_scope(des, scope);
}
