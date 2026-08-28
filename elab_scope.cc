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
# include  <vector>
# include  <algorithm>
# include  <ctime>
# include  <stdint.h>
# include  <iomanip>
# include  <limits>

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
# include  "PModport.h"
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
# include  "netstruct.h"
# include  "parse_api.h"
# include  "util.h"
# include  <typeinfo>
# include  "ivl_assert.h"

using namespace std;

void NetScope::add_nettypes(Design*des,
                            const LexicalScope::nettype_map_t*types)
{
      if (!types)
            return;

      for (LexicalScope::nettype_map_t::const_iterator cur = types->begin();
           cur != types->end(); ++cur) {
            const nettype_t*decl = cur->second;
            if (!decl || nettypes_.find(decl) != nettypes_.end())
                  continue;

            unique_ptr<NetNetType>info(new NetNetType(decl, this));
            NetNetType*raw = info.get();
            nettypes_[decl] = std::move(info);
            nettypes_by_name_[cur->first] = raw;
            des->register_nettype_scope(decl, this);
      }
}

NetNetType* NetScope::find_local_nettype(const nettype_t*type)
{
      map<const nettype_t*,unique_ptr<NetNetType> >::iterator cur =
            nettypes_.find(type);
      return cur == nettypes_.end() ? 0 : cur->second.get();
}

const NetNetType* NetScope::find_local_nettype(const nettype_t*type) const
{
      map<const nettype_t*,unique_ptr<NetNetType> >::const_iterator cur =
            nettypes_.find(type);
      return cur == nettypes_.end() ? 0 : cur->second.get();
}

static void elaborate_scope_class(Design*des, NetScope*scope, PClass*pclass);
static void complete_class_scope_in_place_(Design*des, NetScope*scope,
					   PClass*pclass, netclass_t*use_class,
					   NetScope*class_scope);

// Guard against infinite recursion between ensure_visible_class_type
// and elaborate_scope_class / complete_class_scope_in_place_.  UVM
// class hierarchies have mutual references that trigger unbounded
// re-entry, exhausting memory.
static set<const PClass*> classes_being_scope_elaborated_;
static set<const PClass*> classes_with_randomization_methods_validated_;
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

	// Class methods and parameterized type specializations may ask the
	// same lexical scope to elaborate more than once. Enum literals are
	// immutable once closed; reinserting them diagnoses each name as a
	// duplicate and used to assert in netenum_t::insert_name. Treat the
	// completed typespec as the idempotence boundary.
      if (use_enum->names_closed())
	    return;

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
					const parmvalue_t*overrides,
					const PClass*target_class = 0);
static void append_cache_data_type_key_(Design*des, NetScope*call_scope,
					std::ostringstream&out,
					const data_type_t*type);
static bool cache_value_parameter_is_deferred_(Design*des, NetScope*scope,
					       const PExpr*expr);

/* Specialization-key construction repeatedly renders the same source and
 * elaborated objects. Keep these caches for the whole elaboration phase, but
 * make their storage visible to the terminal phase release below instead of
 * hiding it in function-static maps that survive target emission. */
static std::map<const NetScope*,std::string> specialization_scope_path_cache_;
static std::map<const PExpr*,std::string> specialization_pexpr_dump_cache_;
static std::map<const NetExpr*,std::string>
      specialization_netexpr_value_key_cache_;
static std::map<ivl_type_t,std::string> specialization_type_dump_cache_;
static std::map<const data_type_t*,std::string>
      specialization_data_type_dump_cache_;
static std::map<std::string,const netclass_t*>
      specialized_class_source_key_cache_;
static std::map<std::string,const netclass_t*>
      specialized_class_semantic_key_cache_;

static const std::string& cached_scope_path_(const NetScope*scope)
{
      if (!scope) {
	    static const std::string empty;
	    return empty;
      }

      std::map<const NetScope*,std::string>::iterator it =
	    specialization_scope_path_cache_.find(scope);
      if (it != specialization_scope_path_cache_.end())
	    return it->second;

      std::ostringstream out;
      out << scope_path(scope);
      return specialization_scope_path_cache_
	    .insert(std::make_pair(scope, out.str())).first->second;
}

static const std::string& cached_pexpr_dump_(const PExpr*expr)
{
      if (!expr) {
	    static const std::string empty;
	    return empty;
      }

      std::map<const PExpr*,std::string>::iterator it =
	    specialization_pexpr_dump_cache_.find(expr);
      if (it != specialization_pexpr_dump_cache_.end())
	    return it->second;

      std::ostringstream out;
      // PExpr dumps can contain real literals below an operator. Preserve
      // enough digits to round-trip every binary64 value instead of allowing
      // the stream's default six significant digits to merge source keys.
      out << setprecision(numeric_limits<double>::max_digits10);
      out << *expr;
      return specialization_pexpr_dump_cache_
	    .insert(std::make_pair(expr, out.str())).first->second;
}

static void append_exact_double_key_(std::ostream&out, double value)
{
      static_assert(numeric_limits<double>::is_iec559
		    && sizeof(double) == sizeof(uint64_t),
		    "specialization keys require 64-bit IEEE-754 doubles");
      static const char hex_digits[] = "0123456789abcdef";
      uint64_t bits = 0;
      memcpy(&bits, &value, sizeof(bits));
      for (int shift = 60 ; shift >= 0 ; shift -= 4)
	out << hex_digits[(bits >> shift) & 0xf];
}

static void append_exact_verinum_key_(std::ostream&out, const verinum&value)
{
      out << "value-width=" << value.len()
	  << ":sized=" << value.has_len()
	  << ":signed=" << value.has_sign()
	  << ":single=" << value.is_single()
	  << ":string=" << value.is_string()
	  << ":raw-bits=";
      for (unsigned idx = value.len() ; idx > 0 ; --idx)
	out << value.get(idx-1);
}

static void append_cache_netexpr_value_key_(std::ostringstream&out,
					     const NetExpr*expr)
{
      if (!expr) {
	out << "<nil-value>";
	return;
      }

      if (const NetECReal*real_value = dynamic_cast<const NetECReal*>(expr)) {
	out << "<real:ieee754=";
	append_exact_double_key_(out, real_value->value().as_double());
	out << ">";
	return;
      }

      if (const NetEConst*constant = dynamic_cast<const NetEConst*>(expr)) {
	const verinum&value = constant->value();
	out << "<constant:variant=";
	if (dynamic_cast<const NetECString*>(constant) || value.is_string())
	      out << "string";
	else if (dynamic_cast<const NetEConstEnum*>(constant))
	      out << "enum";
	else
	      out << "integral";
	out << ":expr-type=" << static_cast<int>(expr->expr_type())
	    << ":expr-width=" << expr->expr_width()
	    << ":expr-signed=" << expr->has_sign()
	    << ":unbounded=" << constant->is_unbounded() << ":";
	append_exact_verinum_key_(out, value);
	out << ">";
	return;
      }

      if (const NetEArrayPattern*pattern =
		dynamic_cast<const NetEArrayPattern*>(expr)) {
	out << "<aggregate:expr-type=" << static_cast<int>(expr->expr_type())
	    << ":expr-width=" << expr->expr_width()
	    << ":expr-signed=" << expr->has_sign()
	    << ":active-member=" << pattern->union_active_member()
	    << ":items=" << pattern->item_size() << ":";
	for (size_t idx = 0 ; idx < pattern->item_size() ; ++idx) {
	      std::ostringstream item;
	      append_cache_netexpr_value_key_(item, pattern->item(idx));
	      const std::string item_key = item.str();
	      out << item_key.size() << ":";
	      out.write(item_key.data(), item_key.size());
	}
	out << ">";
	return;
      }

      if (dynamic_cast<const NetENull*>(expr)) {
	out << "<null>";
	return;
      }

      /* Parameter evaluation currently yields scalar constants or an
	 * unpacked-struct assignment pattern. Keep a length-delimited fallback
	 * for a future constant expression variant so it cannot silently alias a
	 * known variant while its exact serializer is added. */
      std::ostringstream rendered;
      rendered << setprecision(numeric_limits<double>::max_digits10);
      rendered << *expr;
      const std::string dump = rendered.str();
      out << "<expression:expr-type=" << static_cast<int>(expr->expr_type())
	  << ":expr-width=" << expr->expr_width()
	  << ":expr-signed=" << expr->has_sign()
	  << ":dump-size=" << dump.size() << ":";
      out.write(dump.data(), dump.size());
      out << ">";
}

static const std::string& cached_netexpr_value_key_(const NetExpr*expr)
{
      if (!expr) {
	static const std::string nil("<nil-value>");
	return nil;
      }

      std::map<const NetExpr*,std::string>::iterator it =
	specialization_netexpr_value_key_cache_.find(expr);
      if (it != specialization_netexpr_value_key_cache_.end())
	return it->second;

      std::ostringstream out;
      append_cache_netexpr_value_key_(out, expr);
      return specialization_netexpr_value_key_cache_
	.insert(std::make_pair(expr, out.str())).first->second;
}

static const std::string& cached_type_dump_(ivl_type_t type)
{
      if (!type) {
	    static const std::string empty;
	    return empty;
      }

      std::map<ivl_type_t,std::string>::iterator it =
	    specialization_type_dump_cache_.find(type);
      if (it != specialization_type_dump_cache_.end())
	    return it->second;

      std::ostringstream out;
      type->debug_dump(out);
      return specialization_type_dump_cache_
	    .insert(std::make_pair(type, out.str())).first->second;
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
			std::map<perm_string,NetScope::param_expr_t>::const_iterator
			      parameter = class_scope->parameters.find(*cur);
			const bool type_parameter =
			      parameter != class_scope->parameters.end()
			      && parameter->second.type_flag;
			const PExpr*source_expr =
			      parameter != class_scope->parameters.end()
			      ? (parameter->second.source_expr
				    ? parameter->second.source_expr
				    : parameter->second.val_expr)
			      : 0;
			NetScope*source_scope =
			      parameter != class_scope->parameters.end()
			      ? (parameter->second.source_scope
				    ? parameter->second.source_scope
				    : parameter->second.val_scope)
			      : 0;
			const bool deferred_value = !type_parameter
			      && source_expr && source_scope
			      && cache_value_parameter_is_deferred_(
				    des, source_scope, source_expr);

			/* For a type parameter, ivl_type is the actual type.  For a
			 * value parameter it is only the declared type, so the value is
			 * also part of class-specialization identity. */
			if (type_parameter) {
			      if (parm_type)
				    append_cache_ivl_type_key_(des, out, parm_type, active);
			      else
				    out << "<unset-type>";
			} else if (deferred_value) {
			      if (parm_type) {
				    append_cache_ivl_type_key_(des, out, parm_type, active);
				    out << "=";
			      }
			      out << "<forwarded-value-param@"
				  << (const void*)pclass << ":expr@"
				  << (const void*)source_expr << ">";
			} else if (parm_type || parm_expr) {
			      if (parm_type)
				    append_cache_ivl_type_key_(des, out, parm_type, active);
			      if (parm_expr) {
				    if (parm_type)
					  out << "=";
				    out << cached_netexpr_value_key_(parm_expr);
			      }
			} else {
			      out << "<unset>";
			}
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

static bool pexpr_matches_parameter_name_(const PExpr*expr, perm_string name);

static const NetScope* normalize_class_scope_(const NetScope*scope)
{
      if (!scope)
	    return 0;
      if (scope->type() == NetScope::CLASS)
	    return scope;
      return scope->get_class_scope();
}

static bool find_class_type_parameter_reference_(
	const PClass*pclass, const data_type_t*type,
	std::set<const data_type_t*>&seen, perm_string&name)
{
      if (!pclass || !type || !seen.insert(type).second)
	    return false;

      if (const type_parameter_t*type_param =
		dynamic_cast<const type_parameter_t*>(type)) {
	    std::map<perm_string,LexicalScope::param_expr_t*>::const_iterator param =
		  pclass->parameters.find(type_param->name);
	    PScope::typedef_map_t::const_iterator declared =
		  pclass->typedefs.find(type_param->name);
	    if (param == pclass->parameters.end() || !param->second
		|| !param->second->type_flag
		|| declared == pclass->typedefs.end()
		|| declared->second->get_data_type() != type)
		  return false;
	    name = type_param->name;
	    return true;
      }

      const typeref_t*type_ref = dynamic_cast<const typeref_t*>(type);
      if (!type_ref)
	    return false;

	/* A qualified or parameterized reference is an external/concrete type.
	 * Do not follow its implementation typedefs: a package is allowed to
	 * contain a typedef whose terminal spelling happens to match this
	 * class's type parameter. */
      if (type_ref->scope_ref() || type_ref->parameter_values())
	    return false;

      typedef_t*td = type_ref->typedef_ref();
      if (!td)
	    return false;

      std::map<perm_string,LexicalScope::param_expr_t*>::const_iterator param =
	    pclass->parameters.find(td->name);
      PScope::typedef_map_t::const_iterator declared =
	    pclass->typedefs.find(td->name);
	/* Compare the typedef object, not only its name. This distinguishes the
	 * parameter from an unqualified alias imported/declared in an outer
	 * scope with the same spelling. */
      if (param != pclass->parameters.end() && param->second
	  && param->second->type_flag
	  && declared != pclass->typedefs.end() && declared->second == td) {
	    name = td->name;
	    return true;
      }

      return find_class_type_parameter_reference_(
	    pclass, td->get_data_type(), seen, name);
}

bool find_class_type_parameter_reference(const NetScope*scope,
					  const data_type_t*type,
					  perm_string&name)
{
      const NetScope*class_scope = normalize_class_scope_(scope);
      const PClass*pclass = class_scope ? class_scope->class_pform() : 0;
      std::set<const data_type_t*>seen;
      return find_class_type_parameter_reference_(pclass, type, seen, name);
}

bool find_class_type_parameter_reference(Design*des, const NetScope*scope,
					  const PExpr*expr,
					  perm_string&name)
{
      const NetScope*class_scope = normalize_class_scope_(scope);
      const PClass*pclass = class_scope ? class_scope->class_pform() : 0;
      if (!pclass || !expr)
	    return false;

      if (const PETypename*type_expr = dynamic_cast<const PETypename*>(expr))
	    return find_class_type_parameter_reference(
		  class_scope, type_expr->get_type(), name);

	/* Some parameter overrides retain a bare identifier expression rather
	 * than PETypename. It is a forwarding reference only when it is the
	 * unqualified name of a type parameter in this exact class. */
      const PEIdent*ident = dynamic_cast<const PEIdent*>(expr);
      if (!ident)
	    return false;
      const pform_scoped_name_t&path = ident->path();
      if (path.package || path.name.size() != 1
	  || !path.name.front().index.empty())
	    return false;

      perm_string use_name = path.name.front().name;
      std::map<perm_string,LexicalScope::param_expr_t*>::const_iterator param =
	    pclass->parameters.find(use_name);
      PScope::typedef_map_t::const_iterator declared =
	    pclass->typedefs.find(use_name);
      if (param == pclass->parameters.end() || !param->second
	  || !param->second->type_flag
	  || declared == pclass->typedefs.end()
	  || !des
	  || const_cast<NetScope*>(scope)->find_typedef(des, use_name)
		!= declared->second)
	    return false;

      name = use_name;
      return true;
}

static bool class_type_parameter_is_deferred_(
	Design*des, const NetScope*scope, perm_string name,
	std::set<std::pair<const NetScope*,perm_string> >&seen)
{
      const NetScope*class_scope = normalize_class_scope_(scope);
      const netclass_t*class_type = class_scope
	    ? class_scope->class_def() : 0;
      const PClass*pclass = class_scope
	    ? class_scope->class_pform() : 0;
      if (!class_scope || !class_type || !pclass)
	    return false;

      std::map<perm_string,LexicalScope::param_expr_t*>::const_iterator pparam =
	    pclass->parameters.find(name);
      if (pparam == pclass->parameters.end() || !pparam->second
	  || !pparam->second->type_flag)
	    return false;

      if (!seen.insert(std::make_pair(class_scope, name)).second)
	    return false;

	/* The generic master represents every future specialization and must
	 * keep the call deferred. In a concrete specialization, inspect both an
	 * explicit actual and the declaration default: a dependent default such
	 * as RSP=IMP inherits IMP's symbolic state, while an ordinary concrete
	 * default remains concrete. */
      if (!class_type->specialized_instance())
	    return true;

      std::map<perm_string,NetScope::param_expr_t>::const_iterator parameter =
	    class_scope->parameters.find(name);
      if (parameter == class_scope->parameters.end()
	  || !parameter->second.type_flag
	  || !parameter->second.val_expr)
	    return false;

      const NetScope*source_use_scope = parameter->second.val_scope;
      const NetScope*source_scope = normalize_class_scope_(source_use_scope);
      perm_string source_name;
      if (!find_class_type_parameter_reference(
		    des, source_use_scope, parameter->second.val_expr, source_name))
	    return false;

      return class_type_parameter_is_deferred_(
	    des, source_scope, source_name, seen);
}

bool class_type_parameter_is_deferred(Design*des,
					      const NetScope*class_scope,
					      perm_string name)
{
      std::set<std::pair<const NetScope*,perm_string> >seen;
      return class_type_parameter_is_deferred_(des, class_scope, name, seen);
}

static bool is_bare_class_reference_(const data_type_t*type,
				      std::set<const typedef_t*>&seen)
{
      if (!type)
	    return false;

      if (dynamic_cast<const class_type_t*>(type))
	    return true;

      if (const array_base_t*array_type =
		dynamic_cast<const array_base_t*>(type))
	    return is_bare_class_reference_(array_type->base_type.get(), seen);

      const typeref_t*type_ref = dynamic_cast<const typeref_t*>(type);
      if (!type_ref || type_ref->parameter_values())
	    return false;

      typedef_t*td = type_ref->typedef_ref();
      if (!td || !seen.insert(td).second)
	    return false;

      return is_bare_class_reference_(td->get_data_type(), seen);
}

static const netclass_t* resolve_bare_class_reference_(
		Design*des, NetScope*scope, const data_type_t*type,
		std::set<const typedef_t*>&seen)
{
      if (!(des && scope && type))
	    return 0;

      if (const class_type_t*class_type =
		    dynamic_cast<const class_type_t*>(type))
	    return ensure_visible_class_type(des, scope, class_type->name);

      if (const array_base_t*array_type =
		    dynamic_cast<const array_base_t*>(type))
	    return resolve_bare_class_reference_(
		  des, scope, array_type->base_type.get(), seen);

      const typeref_t*type_ref = dynamic_cast<const typeref_t*>(type);
      if (!type_ref || type_ref->parameter_values())
	    return 0;

      typedef_t*td = type_ref->typedef_ref();
      if (!td || !seen.insert(td).second)
	    return 0;

      NetScope*type_scope = type_ref->find_scope(des, scope);
      if (!type_scope)
	    type_scope = scope;

	/* A synthetic forward declaration has a same-name class_type_t and may
	 * still point at its early placeholder after the complete PClass is
	 * registered. Only that shape is recovered by name. A user typedef alias
	 * must follow its exact target first: an unrelated class may legally have
	 * the alias's spelling in an outer/imported scope. */
      const class_type_t*forward_type =
	    dynamic_cast<const class_type_t*>(td->get_data_type());
      if (forward_type && forward_type->name == td->name) {
	    if (netclass_t*visible =
		  ensure_visible_class_type(des, type_scope, td->name))
		  return visible;
      }

      return resolve_bare_class_reference_(
	    des, type_scope, td->get_data_type(), seen);
}

ivl_type_t specialize_bare_class_at_concrete_use(
		Design*des, NetScope*call_scope,
		const data_type_t*declared_type, ivl_type_t current_type,
		bool fully_elaborate)
{
      if (!des || !call_scope)
	    return current_type;

      std::set<const typedef_t*>bare_seen;
      if (!is_bare_class_reference_(declared_type, bare_seen))
	    return current_type;

	/* Preserve every already-elaborated array/container wrapper while
	 * normalizing its terminal bare class.  A bare class declaration can be
	 * wrapped directly or through typedef aliases; treating the whole
	 * netarray_t as a class would collapse C q[$] into scalar C#(). */
      if (const netarray_t*array_type =
	    dynamic_cast<const netarray_t*>(current_type)) {
	    ivl_type_t repaired_element = specialize_bare_class_at_concrete_use(
		  des, call_scope, declared_type, array_type->element_type(),
		  fully_elaborate);
	    if (!repaired_element || repaired_element == array_type->element_type())
		  return current_type;

	    if (const netqueue_t*queue_type =
		  dynamic_cast<const netqueue_t*>(current_type))
		  return new netqueue_t(repaired_element, queue_type->max_idx(),
					queue_type->assoc_compat(),
					queue_type->assoc_index_type(),
					queue_type->assoc_wildcard());
	    if (const netuarray_t*fixed_type =
		  dynamic_cast<const netuarray_t*>(current_type))
		  return new netuarray_t(fixed_type->static_dimensions(),
					 repaired_element);
	    if (const netparray_t*packed_type =
		  dynamic_cast<const netparray_t*>(current_type))
		  return new netparray_t(packed_type->static_dimensions(),
					 repaired_element);
	    if (dynamic_cast<const netdarray_t*>(current_type))
		  return new netdarray_t(repaired_element);
	    return current_type;
      }

      const netclass_t*base_class =
	    dynamic_cast<const netclass_t*>(current_type);
	/* Late repair of a forward declaration must not trust the early class
	 * placeholder stored in current_type. Resolve the same bare parse-form
	 * name again after all class scopes are registered. */
      const NetScope*base_scope = base_class ? base_class->class_scope() : 0;
      const PClass*base_pclass = base_scope
	    ? base_scope->class_pform() : 0;
      if (!base_class || !base_pclass || !base_pclass->has_parameter_port_list) {
	    std::set<const typedef_t*>resolve_seen;
	    if (const netclass_t*visible = resolve_bare_class_reference_(
		      des, call_scope, declared_type, resolve_seen)) {
		  base_class = visible;
		  base_scope = base_class->class_scope();
		  base_pclass = base_scope ? base_scope->class_pform() : 0;
	    }
      }
      if (!base_class || base_class->specialized_instance())
	    return current_type;

      if (!base_pclass || !base_pclass->has_parameter_port_list)
	    return current_type;

      perm_string class_name = base_class->get_name();
      if (class_name == perm_string::literal("mailbox")
	  || class_name == perm_string::literal("semaphore")
	  || class_name == perm_string::literal("process"))
	    return current_type;

      const NetScope*caller_class_scope = call_scope->get_class_scope();
      const netclass_t*caller_class = caller_class_scope
	    ? caller_class_scope->class_def() : 0;
      const PClass*caller_pclass = caller_class_scope
	    ? caller_class_scope->class_pform() : 0;

	/* A bare self reference inside a concrete specialization denotes that
	 * same specialization, not a new specialization using the declaration
	 * defaults. */
      if (caller_class && caller_pclass == base_pclass
	  && caller_class->specialized_instance())
	    return caller_class;

	/* An unspecialized parameterized class scope is a template seed, not a
	 * concrete use site.  Its body is checked again when a real enclosing
	 * specialization is elaborated. */
      if (caller_class && caller_pclass
	  && caller_pclass->has_parameter_port_list
	  && !caller_class->specialized_instance())
	    return current_type;

      std::list<PExpr*>empty_order;
      parmvalue_t defaults;
      defaults.by_order = &empty_order;
      defaults.by_name = 0;
      return const_cast<netclass_t*>(elaborate_specialized_class_type(
	    des, call_scope, base_class, &defaults, fully_elaborate));
}

ivl_type_t specialize_bare_class_receiver_on_use(
		Design*des, NetScope*call_scope,
		const data_type_t*declared_type, ivl_type_t current_type)
{
      return specialize_bare_class_at_concrete_use(
	    des, call_scope, declared_type, current_type, true);
}

/* Keep a generic forwarding actual (inner#(outer_T)) distinct in the
 * specialization cache from a concrete type that currently happens to equal
 * outer_T's default. Otherwise whichever spelling populates the cache first
 * controls whether the inner method body is deferred, making elaboration
 * order-dependent. Concrete outer specializations use their resolved type and
 * retain ordinary semantic class identity. */
static perm_string unresolved_forwarded_type_parameter_(
	Design*des, NetScope*call_scope, const PExpr*expr, const PClass*&owner)
{
      owner = 0;
      const NetScope*class_scope = call_scope
	    ? call_scope->get_class_scope() : 0;
      const PClass*pclass = class_scope
	    ? class_scope->class_pform() : 0;
      if (!class_scope || !pclass)
	    return perm_string();

      perm_string name;
        /* Resolve the actual in its original lexical scope. A method/block
         * typedef can deliberately shadow a class type parameter with the
         * same spelling; normalizing to class_scope here would turn that
         * concrete local type into a false forwarding reference. */
      if (!find_class_type_parameter_reference(des, call_scope, expr, name)
	  || !class_type_parameter_is_deferred(des, class_scope, name))
	    return perm_string();

      owner = pclass;
      return name;
}

static const std::string& cached_data_type_dump_(const data_type_t*type)
{
      if (!type) {
	    static const std::string empty;
	    return empty;
      }

      std::map<const data_type_t*,std::string>::iterator it =
	    specialization_data_type_dump_cache_.find(type);
      if (it != specialization_data_type_dump_cache_.end())
	    return it->second;

      std::ostringstream out;
      type->debug_dump(out);
      return specialization_data_type_dump_cache_
	    .insert(std::make_pair(type, out.str())).first->second;
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
				   const PExpr*expr,
				   int formal_kind = -1)
{
	/* Preserve the exact lexical lookup scope for provenance. The normalized
	 * class scope below is desirable for stable semantic cache keys, but it
	 * must not make a method/block typedef named like a class type parameter
	 * disappear before forwarding identity is decided. */
      NetScope*lookup_scope = call_scope;
      call_scope = specialization_key_scope_(call_scope);

      if (!expr)
	    return;

      const PClass*forward_owner = 0;
      perm_string forward_name;
      if (formal_kind != 0)
	    forward_name = unresolved_forwarded_type_parameter_(
		des, lookup_scope, expr, forward_owner);
      if (forward_name)
	    out << "<forwarded-type-param@" << (const void*)forward_owner
		<< ":" << forward_name << "=";
      const auto close_forward = [&out, &forward_name]() {
	    if (forward_name)
		  out << ">";
      };

	/* A value actual forwarded through an unspecialized class template is
	 * symbolic even when its provisional NetExpr equals the formal default.
	 * Keep that template seed out of the concrete source-key namespace; the
	 * concrete specialization will use the ordinary exact value key after the
	 * forwarding parameter has been replaced. */
      if (formal_kind == 0
	  && cache_value_parameter_is_deferred_(des, lookup_scope, expr)) {
	const NetScope*class_scope = lookup_scope
	      ? lookup_scope->get_class_scope() : 0;
	const PClass*pclass = class_scope ? class_scope->class_pform() : 0;
	out << "<forwarded-value-param@" << (const void*)pclass
	    << ":expr@" << (const void*)expr << ">";
	close_forward();
	return;
      }

      if (const PEFNumber*real_value =
		dynamic_cast<const PEFNumber*>(expr)) {
	out << "<real:ieee754=";
	append_exact_double_key_(out, real_value->value().as_double());
	out << ">";
	close_forward();
	return;
      }

      if (const PENumber*number = dynamic_cast<const PENumber*>(expr)) {
	out << "<number:";
	append_exact_verinum_key_(out, number->value());
	out << ">";
	close_forward();
	return;
      }

      if (const PEString*string_value = dynamic_cast<const PEString*>(expr)) {
	out << "<string:";
	append_exact_verinum_key_(out, string_value->parsed_value());
	out << ">";
	close_forward();
	return;
      }

      if (dynamic_cast<const PEUnbounded*>(expr)) {
	out << "<unbounded>";
	close_forward();
	return;
      }

      if (dynamic_cast<const PENull*>(expr)) {
	out << "<null>";
	close_forward();
	return;
      }

      if (const PETypename*type_expr = dynamic_cast<const PETypename*>(expr)) {
	    if (lookup_scope) {
		  ivl_type_t resolved_type = resolve_class_type_reference(
			des, lookup_scope, type_expr->get_type());
		  if (!resolved_type)
			resolved_type = const_cast<data_type_t*>(
			      type_expr->get_type())->elaborate_type(des, lookup_scope);
		  if (resolved_type) {
			append_cache_ivl_type_key_(des, out, resolved_type);
			close_forward();
			return;
		  }
	    }

	    out << "<typename:";
	    append_cache_data_type_key_(des, call_scope, out, type_expr->get_type());
	    out << ">";
	    close_forward();
	    return;
      }

      if (const PEIdent*ident = dynamic_cast<const PEIdent*>(expr)) {
	    const pform_scoped_name_t&path = ident->path();
	    if (lookup_scope && path.package == 0 && path.name.size() == 1 &&
	        path.name.front().index.empty()) {
		  perm_string ident_name = path.name.front().name;
		    /* Implicit named actuals retain a bare identifier for both
		     * type and value formals. Resolve in the namespace selected by
		     * the destination formal instead of guessing from the spelling:
		     * a nearer typedef T must win for `.T' on a type formal, while a
		     * value parameter P must not be replaced by an unrelated typedef
		     * P declared elsewhere in the lexical chain. */
		  if (formal_kind == 1) {
			if (typedef_t*td = lookup_scope->find_typedef(des, ident_name)) {
			      if (const data_type_t*declared_type = td->get_data_type()) {
				    if (ivl_type_t resolved_type =
					  const_cast<data_type_t*>(declared_type)->elaborate_type(
						des, lookup_scope)) {
					  append_cache_ivl_type_key_(des, out, resolved_type);
					  close_forward();
					  return;
				    }
			      }
			}
		  }

		  if (formal_kind != 1) {
			symbol_search_results search;
			const NetExpr*resolved_expr = 0;
			ivl_type_t resolved_type = 0;
			if (symbol_search(ident, des, lookup_scope, path,
					  ident->lexical_pos(),
					  &search)
			    && search.par_val) {
			      resolved_expr = search.par_val;
			      resolved_type = search.type;
			}
			if (resolved_expr || resolved_type) {
			      if (resolved_type)
				    append_cache_ivl_type_key_(des, out, resolved_type);
			      if (resolved_expr) {
				    if (resolved_type)
					  out << "=";
				    out << cached_netexpr_value_key_(resolved_expr);
			      }
			      close_forward();
			      return;
			}
		  }

		  if (formal_kind < 0) {
			if (typedef_t*td = lookup_scope->find_typedef(des, ident_name)) {
			      if (const data_type_t*declared_type = td->get_data_type()) {
				    if (ivl_type_t resolved_type =
					  const_cast<data_type_t*>(declared_type)->elaborate_type(
						des, lookup_scope)) {
					  append_cache_ivl_type_key_(des, out, resolved_type);
					  close_forward();
					  return;
				    }
			      }
			}
		  }
	    }
      }

      out << cached_pexpr_dump_(expr);

      // Keep cache entries scope-sensitive only for expressions that we
      // could not canonicalize to resolved parameter/type values.
      if (call_scope && expr_cache_key_needs_scope_(expr))
	    out << "@scope=" << cached_scope_path_(call_scope);
      close_forward();
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
					const parmvalue_t*overrides,
					const PClass*target_class)
{
      if (!overrides)
	    return std::string();

	/* Keep the original lexical scope until append_cache_expr_key_ has
	 * resolved whether an actual names a nearer method/block typedef or a
	 * class type parameter. That helper normalizes the scope only after the
	 * provenance decision. Normalizing here first makes an implicit named
	 * actual such as `.T' incorrectly bypass a local typedef T and produces a
	 * distinct specialization-cache entry for an otherwise identical type. */

      std::ostringstream out;
      if (overrides->by_order) {
	    out << "O";
	    std::list<perm_string>::const_iterator formal_name = target_class
		  ? target_class->parameter_order.begin()
		  : std::list<perm_string>::const_iterator();
	    for (std::list<PExpr*>::const_iterator cur = overrides->by_order->begin()
		 ; cur != overrides->by_order->end() ; ++cur) {
		  out << "|";
		  int formal_kind = -1;
		  if (target_class
		      && formal_name != target_class->parameter_order.end()) {
			std::map<perm_string,LexicalScope::param_expr_t*>::const_iterator formal =
			      target_class->parameters.find(*formal_name);
			if (formal != target_class->parameters.end() && formal->second)
			      formal_kind = formal->second->type_flag ? 1 : 0;
			++formal_name;
		  }
		  append_cache_expr_key_(des, call_scope, out, *cur, formal_kind);
	    }
      } else if (overrides->by_name) {
	    out << "N";
	    for (std::list<named_pexpr_t>::const_iterator cur = overrides->by_name->begin()
		 ; cur != overrides->by_name->end() ; ++cur) {
		  out << "|" << cur->name << "=";
		  int formal_kind = -1;
		  if (target_class) {
			std::map<perm_string,LexicalScope::param_expr_t*>::const_iterator formal =
			      target_class->parameters.find(cur->name);
			if (formal != target_class->parameters.end() && formal->second)
			      formal_kind = formal->second->type_flag ? 1 : 0;
		  }
		  append_cache_expr_key_(des, call_scope, out, cur->parm, formal_kind);
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

static bool cache_integral_expression_signed_(Design*des, NetScope*scope,
					       const PExpr*expr,
					       bool&is_signed)
{
      if (!expr)
	return false;

      if (dynamic_cast<const PEUnbounded*>(expr)) {
	is_signed = true;
	return true;
      }

      if (const PENumber*number = dynamic_cast<const PENumber*>(expr)) {
	is_signed = number->value().has_sign();
	return true;
      }

      if (const PEUnary*unary = dynamic_cast<const PEUnary*>(expr)) {
	switch (unary->get_op()) {
	    case '+':
	    case '-':
	    case '~':
	      return cache_integral_expression_signed_(
		    des, scope, unary->get_expr(), is_signed);
	    default:
	      return false;
	}
      }

      if (const PEBinary*binary = dynamic_cast<const PEBinary*>(expr)) {
	switch (binary->get_op()) {
	    case '+':
	    case '-':
	    case '*':
	    case '/':
	    case '%':
	      break;
	    default:
	      return false;
	}
	bool left_signed = false;
	bool right_signed = false;
	if (!cache_integral_expression_signed_(
	      des, scope, binary->get_left(), left_signed)
	    || !cache_integral_expression_signed_(
	      des, scope, binary->get_right(), right_signed))
	      return false;
	is_signed = left_signed && right_signed;
	return true;
      }

      const PEIdent*ident = dynamic_cast<const PEIdent*>(expr);
      if (!ident || !scope)
	return false;
      const pform_scoped_name_t&path = ident->path();
      if (path.name.size() != 1)
	return false;
      symbol_search_results search;
      if (!symbol_search(ident, des, scope, path,
			 ident->lexical_pos(), &search)
	  || !search.par_val)
	return false;
      const NetEConst*constant = dynamic_cast<const NetEConst*>(search.par_val);
      if (!constant || constant->value().is_string())
	return false;
      if (!path.name.front().index.empty()) {
	is_signed = false;
	return true;
      }
      if (!search.path_tail.empty())
	return false;
      is_signed = constant->value().has_sign();
      return true;
}

static void cache_apply_integral_context_(verinum&value,
					  unsigned context_width,
					  bool signed_override,
					  bool context_signed)
{
      if (context_width == 0)
	return;
      if (signed_override)
	value.has_sign(context_signed);
      value = cast_to_width(value, std::max(value.len(), context_width));
      if (signed_override)
	value.has_sign(context_signed);
      value.has_len(true);
}

/* Assignment context contributes width throughout an arithmetic tree.  The
 * signed override is the containing expression's common signedness, matching
 * PEBinary/PEUnary elaboration; the destination formal's signedness is a final
 * assignment conversion and must not make a direct unsigned select sign-
 * extend (for example, int'(P[1]) where P[1] is one). */
static bool cache_integral_constant_value_(Design*des, NetScope*scope,
					   const PExpr*expr,
					   verinum&value,
					   bool&unbounded,
					   unsigned context_width = 0,
					   bool signed_override = false,
					   bool context_signed = false)
{
      unbounded = false;

      if (!expr)
	return false;

      if (dynamic_cast<const PEUnbounded*>(expr)) {
	value = verinum(verinum::Vx, integer_width, true);
	unbounded = true;
	return true;
      }

      if (const PENumber*number = dynamic_cast<const PENumber*>(expr)) {
	    value = number->value();
	    if (!value.has_len()) {
		  const bool single = value.is_single();
		  value = cast_to_width(
			value, std::max(value.len(), integer_width));
		  value.has_len(true);
		  value.is_single(single);
	    }
	    cache_apply_integral_context_(
		  value, context_width, signed_override, context_signed);
	    return true;
      }

      if (const PEUnary*unary = dynamic_cast<const PEUnary*>(expr)) {
	bool unary_signed = context_signed;
	bool unary_signed_override = signed_override;
	if (context_width && !unary_signed_override) {
	      if (!cache_integral_expression_signed_(
		    des, scope, unary, unary_signed))
		    return false;
	      unary_signed_override = true;
	}
	verinum operand;
	bool operand_unbounded = false;
	if (!cache_integral_constant_value_(
	      des, scope, unary->get_expr(), operand, operand_unbounded,
	      context_width, unary_signed_override, unary_signed)
	    || operand_unbounded)
	      return false;
	switch (unary->get_op()) {
	    case '+': value = operand; break;
	    case '-': value = -operand; break;
	    case '~': value = ~operand; break;
	    default: return false;
	}
	cache_apply_integral_context_(
	      value, context_width, unary_signed_override, unary_signed);
	return true;
      }

      if (const PEBinary*binary = dynamic_cast<const PEBinary*>(expr)) {
	bool binary_signed = context_signed;
	bool binary_signed_override = signed_override;
	if (context_width && !binary_signed_override) {
	      if (!cache_integral_expression_signed_(
		    des, scope, binary, binary_signed))
		    return false;
	      binary_signed_override = true;
	}
	verinum left;
	verinum right;
	bool left_unbounded = false;
	bool right_unbounded = false;
	if (!cache_integral_constant_value_(
	      des, scope, binary->get_left(), left, left_unbounded,
	      context_width, binary_signed_override, binary_signed)
	    || !cache_integral_constant_value_(
	      des, scope, binary->get_right(), right, right_unbounded,
	      context_width, binary_signed_override, binary_signed)
	    || left_unbounded || right_unbounded)
	      return false;

	/* IEEE 1800-2017 11.8.1: arithmetic operands first acquire the
	 * expression's common width and signedness.  Change signedness before
	 * extending: 8'shff combined with a wider unsigned operand denotes
	 * 16'h00ff, not 16'hffff. */
	const unsigned width = std::max(
	      context_width, std::max(left.len(), right.len()));
	const bool is_signed = binary_signed_override
	      ? binary_signed : left.has_sign() && right.has_sign();
	left.has_sign(is_signed);
	right.has_sign(is_signed);
	left = cast_to_width(left, width);
	right = cast_to_width(right, width);
	left.has_sign(is_signed);
	right.has_sign(is_signed);

	switch (binary->get_op()) {
	    case '+': value = left + right; break;
	    case '-': value = left - right; break;
	    case '*': value = left * right; break;
	    case '/':
	      if (right.is_zero())
		    return false;
	      value = left / right;
	      break;
	    case '%':
	      if (right.is_zero())
		    return false;
	      value = left % right;
	      break;
	    default: return false;
	}
	value = cast_to_width(value, width);
	value.has_sign(is_signed);
	value.has_len(true);
	return true;
      }

      const PEIdent*ident = dynamic_cast<const PEIdent*>(expr);
      if (!ident || !scope)
	    return false;

      const pform_scoped_name_t&path = ident->path();
      if (path.name.size() != 1)
	return false;

      symbol_search_results search;
      if (!symbol_search(ident, des, scope, path,
			 ident->lexical_pos(), &search)
	  || !search.par_val)
	    return false;
      const NetEConst*constant = dynamic_cast<const NetEConst*>(search.par_val);
      if (!constant || constant->value().is_string())
	    return false;

      /* Resolve one constant packed bit/element select without expression
       * elaboration.  symbol_search returns the whole parameter for P[1]; using
       * that value directly made P[1] collide with P. */
      const std::list<index_component_t>&indices = path.name.front().index;
      if (!indices.empty()) {
	if (indices.size() != 1 || !search.path_tail.empty())
	      return false;
	const index_component_t&index = indices.front();
	if (index.sel != index_component_t::SEL_BIT
	    || !index.msb || index.lsb)
	      return false;
	verinum index_value;
	bool index_unbounded = false;
	if (!cache_integral_constant_value_(
	      des, scope, index.msb, index_value, index_unbounded)
	    || index_unbounded || !index_value.is_defined())
	      return false;
	long parameter_msb = 0;
	long parameter_lsb = 0;
	unsigned long slice_width = 1;
	if (!calculate_param_range(
	      *ident, search.type, parameter_msb, parameter_lsb,
	      constant->value().len(), &slice_width))
	      return false;
	long offset = index_value.as_long();
	if (parameter_msb >= parameter_lsb)
	      offset -= parameter_lsb;
	else
	      offset = parameter_lsb - offset;
	const long base = offset * static_cast<long>(slice_width);
	if (offset < 0 || base < 0
	    || static_cast<unsigned long>(base) + slice_width
		  > constant->value().len())
	      return false;
	value = verinum(verinum::Vx, static_cast<unsigned>(slice_width), true);
	for (unsigned long bit = 0 ; bit < slice_width ; ++bit)
	      value.set(static_cast<unsigned>(bit),
		constant->value().get(static_cast<unsigned long>(base) + bit));
	value.has_sign(false);
	value.has_len(true);
	cache_apply_integral_context_(
	      value, context_width, signed_override, context_signed);
	unbounded = false;
	return true;
      }

      if (!search.path_tail.empty())
	      return false;
      value = constant->value();
      unbounded = constant->is_unbounded();
	if (!unbounded)
	      cache_apply_integral_context_(
		    value, context_width, signed_override, context_signed);
      return true;
}

/* Resolve only a bare/package-qualified parameter name.  Unlike expression
 * elaboration, this lookup is diagnostic-free on failure; hierarchical or
 * selected names conservatively retain their source cache key. */
static const NetExpr* cache_simple_parameter_value_(Design*des,
						     NetScope*scope,
						     const PExpr*expr,
						     ivl_type_t&type)
{
      type = 0;
      const PEIdent*ident = dynamic_cast<const PEIdent*>(expr);
      if (!ident || !scope)
	return 0;

      const pform_scoped_name_t&path = ident->path();
      if (path.name.size() != 1 || !path.name.front().index.empty())
	return 0;

      symbol_search_results search;
      if (!symbol_search(ident, des, scope, path, ident->lexical_pos(), &search)
	  || !search.par_val || !search.path_tail.empty())
	return 0;
      type = search.type;
      return search.par_val;
}

/* Follow a concrete parameter reference back to the PExpr that supplied its
 * value.  Unsupported semantic probes then key both the direct spelling and
 * a dependent forwarded spelling from the same source lineage. */
static bool cache_parameter_source_lineage_(Design*des, NetScope*&scope,
					     const PExpr*&expr)
{
      std::set<std::pair<const NetScope*,const NetExpr*> >seen;
      while (const PEIdent*ident = dynamic_cast<const PEIdent*>(expr)) {
	const pform_scoped_name_t&path = ident->path();
	if (!scope || path.name.size() != 1
	    || !path.name.front().index.empty())
	      break;

	symbol_search_results search;
	if (!symbol_search(ident, des, scope, path, ident->lexical_pos(), &search)
	    || !search.par_val || !search.scope || !search.path_tail.empty())
	      break;
	if (!seen.insert(std::make_pair(search.scope, search.par_val)).second)
	      return false;

	perm_string parameter_name = path.name.front().name;
	NetScope*parameter_scope = search.scope;
	std::map<perm_string,NetScope::param_expr_t>::const_iterator parameter =
	      parameter_scope->parameters.find(parameter_name);
	const NetScope*owner_scope = normalize_class_scope_(search.scope);
	if (parameter == parameter_scope->parameters.end() && owner_scope) {
	      parameter_scope = const_cast<NetScope*>(owner_scope);
	      parameter = parameter_scope->parameters.find(parameter_name);
	}
	if (parameter == parameter_scope->parameters.end())
	      break;

	const PExpr*source_expr = parameter->second.source_expr
	      ? parameter->second.source_expr : parameter->second.val_expr;
	NetScope*source_scope = parameter->second.source_scope
	      ? parameter->second.source_scope : parameter->second.val_scope;
	if (!source_expr || !source_scope)
	      break;
	expr = source_expr;
	scope = source_scope;
      }
      return true;
}

static bool cache_source_lineage_key_(Design*des, NetScope*scope,
				       const PExpr*expr, std::string&key)
{
      if (!expr || !cache_parameter_source_lineage_(des, scope, expr))
	return false;

      std::ostringstream source;
      append_cache_expr_key_(des, scope, source, expr, 0);
      const std::string source_key = source.str();
      if (source_key.empty())
	return false;

      std::ostringstream out;
      out << "<source-lineage:size=" << source_key.size() << ":";
      out.write(source_key.data(), source_key.size());
      out << ">";
      key = out.str();
      return true;
}

/* Evaluate the small scalar subset needed to canonicalize real class values
 * without invoking elaboration. Integral subexpressions remain verinum
 * operations until real arithmetic or assignment conversion, preserving
 * width, sign, overflow, division and unary semantics. A failed probe is
 * silent and leaves the caller on its source-sensitive key; the ordinary
 * specialization pass then owns any legitimate diagnostic. */
static bool cache_real_constant_operand_(Design*des, NetScope*scope,
					  const PExpr*expr, double&real_value,
					  verinum&integral_value,
					  bool&real_expression)
{
      bool unbounded = false;
      if (cache_integral_constant_value_(
	    des, scope, expr, integral_value, unbounded)) {
	if (unbounded || !integral_value.is_defined())
	      return false;
	real_expression = false;
	return true;
      }

      if (const PEFNumber*number = dynamic_cast<const PEFNumber*>(expr)) {
	real_value = number->value().as_double();
	real_expression = true;
	return true;
      }

      ivl_type_t parameter_type = 0;
      if (const NetExpr*parameter = cache_simple_parameter_value_(
		des, scope, expr, parameter_type)) {
	if (const NetECReal*real_constant =
	      dynamic_cast<const NetECReal*>(parameter)) {
	      real_value = real_constant->value().as_double();
	      real_expression = true;
	      return true;
	}
	return false;
      }

      if (const PEUnary*unary = dynamic_cast<const PEUnary*>(expr)) {
	double operand_real = 0.0;
	verinum operand_integral;
	bool operand_is_real = false;
	if (!cache_real_constant_operand_(
	      des, scope, unary->get_expr(), operand_real, operand_integral,
	      operand_is_real))
	      return false;
	switch (unary->get_op()) {
	    case '+':
	      if (!operand_is_real)
		    return false;
	      real_value = operand_real;
	      real_expression = true;
	      return true;
	    case '-':
	      if (!operand_is_real)
		    return false;
	      real_value = -operand_real;
	      real_expression = true;
	      return true;
	    default: return false;
	}
      }

      if (const PEBinary*binary = dynamic_cast<const PEBinary*>(expr)) {
	double left_real = 0.0;
	double right_real = 0.0;
	verinum left_integral;
	verinum right_integral;
	bool left_is_real = false;
	bool right_is_real = false;
	if (!cache_real_constant_operand_(
	      des, scope, binary->get_left(), left_real, left_integral,
	      left_is_real)
	    || !cache_real_constant_operand_(
	      des, scope, binary->get_right(), right_real, right_integral,
	      right_is_real))
	      return false;
	if (!left_is_real && !right_is_real)
	      return false;
	const double left = left_is_real
	      ? left_real : left_integral.as_double();
	const double right = right_is_real
	      ? right_real : right_integral.as_double();
	real_expression = true;
	switch (binary->get_op()) {
	    case '+': real_value = left + right; return true;
	    case '-': real_value = left - right; return true;
	    case '*': real_value = left * right; return true;
	    case '/':
	      real_value = left / right;
	      return true;
	    default: return false;
	}
      }

      return false;
}

static bool cache_real_constant_value_(Design*des, NetScope*scope,
					const PExpr*expr, double&value)
{
      bool real_expression = false;
      verinum integral_value;
      if (!cache_real_constant_operand_(
	    des, scope, expr, value, integral_value, real_expression))
	    return false;
      if (!real_expression)
	    value = integral_value.as_double();
      return true;
}

static NetExpr* cache_typed_literal_value_(Design*des, NetScope*scope,
					    const PExpr*expr,
					    ivl_type_t formal_type);
static NetExpr* cache_typed_netexpr_value_(const NetExpr*expr,
					    ivl_type_t formal_type);

static void delete_cache_literal_items_(std::vector<NetExpr*>&items)
{
      for (std::vector<NetExpr*>::iterator cur = items.begin()
	   ; cur != items.end(); ++cur)
	delete *cur;
}

/* Materialize a diagnostic-free, fully typed fixed-array literal.  Keep the
 * same declared-index ordering as PEAssignPattern::elaborate_expr_uarray_ so
 * its exact NetEArrayPattern key matches an already evaluated parameter. */
static NetExpr* cache_typed_literal_uarray_(Design*des, NetScope*scope,
					     const PEAssignPattern*pattern,
					     const netuarray_t*array_type,
					     unsigned dimension)
{
      if (!pattern || !array_type || !pattern->keys().empty()
	  || !pattern->parm_names().empty() || pattern->replication())
	return 0;

      const netranges_t&dimensions = array_type->static_dimensions();
      if (dimension >= dimensions.size())
	return 0;
      const std::vector<PExpr*>&parms = pattern->parms();
      const size_t count = dimensions[dimension].width();
      if (parms.size() != count)
	return 0;

      const bool ascending =
	    dimensions[dimension].get_msb() < dimensions[dimension].get_lsb();
      std::vector<NetExpr*>items(count, 0);
      for (size_t idx = 0 ; idx < count ; ++idx) {
	NetExpr*item = 0;
	if (dimension + 1 < dimensions.size()) {
	      item = cache_typed_literal_uarray_(
		    des, scope, dynamic_cast<const PEAssignPattern*>(parms[idx]),
		    array_type, dimension + 1);
	} else {
	      item = cache_typed_literal_value_(
		    des, scope, parms[idx], array_type->element_type());
	}
	if (!item) {
	      delete_cache_literal_items_(items);
	      return 0;
	}
	items[ascending ? idx : count - 1 - idx] = item;
      }
      return new NetEArrayPattern(const_cast<netuarray_t*>(array_type), items);
}

/* Build only values whose syntax and safely resolved scalar constants can be
 * checked without ordinary expression elaboration. Unsupported keyed,
 * replicated, union, or unresolved identifier-bearing shapes return null and
 * retain the caller's scope-sensitive source key. */
static NetExpr* cache_typed_literal_value_(Design*des, NetScope*scope,
					    const PExpr*expr,
					    ivl_type_t formal_type)
{
      if (!des || !scope || !expr || !formal_type)
	return 0;

      if (formal_type->base_type() == IVL_VT_REAL) {
	double value = 0.0;
	if (!cache_real_constant_value_(des, scope, expr, value))
	      return 0;
	return new NetECReal(verireal(value));
      }

      if (formal_type->base_type() == IVL_VT_STRING) {
	if (const PEString*literal = dynamic_cast<const PEString*>(expr))
	      return new NetECString(literal->parsed_value());
	ivl_type_t parameter_type = 0;
	const NetEConst*constant = dynamic_cast<const NetEConst*>(
	      cache_simple_parameter_value_(des, scope, expr, parameter_type));
	if (!constant || (!dynamic_cast<const NetECString*>(constant)
		      && !constant->value().is_string()))
	      return 0;
	return new NetECString(constant->value());
      }

      if (const netstruct_t*struct_type =
	    dynamic_cast<const netstruct_t*>(formal_type)) {
	if (struct_type->packed() || struct_type->union_flag())
	      return 0;
	const PEAssignPattern*pattern =
	      dynamic_cast<const PEAssignPattern*>(expr);
	if (!pattern || !pattern->keys().empty()
	    || !pattern->parm_names().empty() || pattern->replication())
	      return 0;
	const std::vector<netstruct_t::member_t>&members =
	      struct_type->members();
	const std::vector<PExpr*>&parms = pattern->parms();
	if (parms.size() != members.size())
	      return 0;
	std::vector<NetExpr*>items(members.size(), 0);
	for (size_t idx = 0 ; idx < members.size() ; ++idx) {
	      items[idx] = cache_typed_literal_value_(
		    des, scope, parms[idx], members[idx].net_type);
	      if (!items[idx]) {
		    delete_cache_literal_items_(items);
		    return 0;
	      }
	}
	return new NetEArrayPattern(formal_type, items);
      }

      if (const netuarray_t*array_type =
	    dynamic_cast<const netuarray_t*>(formal_type))
	return cache_typed_literal_uarray_(
	      des, scope, dynamic_cast<const PEAssignPattern*>(expr),
	      array_type, 0);

      if (!formal_type->packed()
	  || (formal_type->base_type() != IVL_VT_BOOL
	      && formal_type->base_type() != IVL_VT_LOGIC)
	  || formal_type->packed_width() <= 0)
	return 0;

      verinum value;
      bool unbounded = false;
      if (!cache_integral_constant_value_(
	    des, scope, expr, value, unbounded,
	    formal_type->packed_width())
	  || unbounded)
	return 0;
      value = cast_to_width(value, formal_type->packed_width());
      value.has_sign(formal_type->get_signed());
      value.has_len(true);
      if (formal_type->base_type() == IVL_VT_BOOL)
	value.cast_to_int2();
      return new NetEConst(formal_type, value);
}

static NetExpr* cache_typed_netexpr_uarray_(const NetEArrayPattern*pattern,
					     const netuarray_t*array_type,
					     unsigned dimension)
{
      if (!pattern || !array_type)
	return 0;
      const netranges_t&dimensions = array_type->static_dimensions();
      if (dimension >= dimensions.size()
	  || pattern->item_size() != dimensions[dimension].width())
	return 0;

      std::vector<NetExpr*>items(pattern->item_size(), 0);
      for (size_t idx = 0 ; idx < pattern->item_size() ; ++idx) {
	if (dimension + 1 < dimensions.size()) {
	      items[idx] = cache_typed_netexpr_uarray_(
		    dynamic_cast<const NetEArrayPattern*>(pattern->item(idx)),
		    array_type, dimension + 1);
	} else {
	      items[idx] = cache_typed_netexpr_value_(
		    pattern->item(idx), array_type->element_type());
	}
	if (!items[idx]) {
	      delete_cache_literal_items_(items);
	      return 0;
	}
      }
      return new NetEArrayPattern(const_cast<netuarray_t*>(array_type), items);
}

/* Reapply a declared aggregate type to an already evaluated parameter.  Raw
 * NetEArrayPattern leaves retain details of their source elaboration (a
 * string leaf can look vector-typed, and an array element can retain source
 * signedness); those are not part of the effective parameter value. */
static NetExpr* cache_typed_netexpr_value_(const NetExpr*expr,
					    ivl_type_t formal_type)
{
      if (!expr || !formal_type)
	return 0;

      if (formal_type->base_type() == IVL_VT_REAL) {
	if (const NetECReal*real_value = dynamic_cast<const NetECReal*>(expr))
	      return new NetECReal(real_value->value());
	const NetEConst*integral = dynamic_cast<const NetEConst*>(expr);
	if (!integral || integral->is_unbounded()
	    || !integral->value().is_defined())
	      return 0;
	return new NetECReal(verireal(integral->value().as_double()));
      }

      if (formal_type->base_type() == IVL_VT_STRING) {
	const NetEConst*constant = dynamic_cast<const NetEConst*>(expr);
	if (!constant || !constant->value().is_string())
	      return 0;
	return new NetECString(constant->value());
      }

      if (const netstruct_t*struct_type =
	    dynamic_cast<const netstruct_t*>(formal_type)) {
	const NetEArrayPattern*pattern =
	      dynamic_cast<const NetEArrayPattern*>(expr);
	if (!pattern || struct_type->packed() || struct_type->union_flag())
	      return 0;
	const std::vector<netstruct_t::member_t>&members =
	      struct_type->members();
	if (pattern->item_size() != members.size())
	      return 0;
	std::vector<NetExpr*>items(members.size(), 0);
	for (size_t idx = 0 ; idx < members.size() ; ++idx) {
	      items[idx] = cache_typed_netexpr_value_(
		    pattern->item(idx), members[idx].net_type);
	      if (!items[idx]) {
		    delete_cache_literal_items_(items);
		    return 0;
	      }
	}
	return new NetEArrayPattern(formal_type, items);
      }

      if (const netuarray_t*array_type =
	    dynamic_cast<const netuarray_t*>(formal_type))
	return cache_typed_netexpr_uarray_(
	      dynamic_cast<const NetEArrayPattern*>(expr), array_type, 0);

      if (!formal_type->packed()
	  || (formal_type->base_type() != IVL_VT_BOOL
	      && formal_type->base_type() != IVL_VT_LOGIC)
	  || formal_type->packed_width() <= 0)
	return 0;
      const NetEConst*constant = dynamic_cast<const NetEConst*>(expr);
      if (!constant || constant->is_unbounded()
	  || constant->value().is_string())
	return 0;
      verinum value = constant->value();
      value = cast_to_width(value, formal_type->packed_width());
      value.has_sign(formal_type->get_signed());
      value.has_len(true);
      if (formal_type->base_type() == IVL_VT_BOOL)
	value.cast_to_int2();
      return new NetEConst(formal_type, value);
}

static bool cache_typed_constant_value_key_(Design*des, NetScope*scope,
					     const PExpr*expr,
					     ivl_type_t formal_type,
					     std::string&key)
{
      if (!des || !scope || !expr || !formal_type)
	return false;

      if (formal_type->base_type() == IVL_VT_REAL) {
	double value = 0.0;
	if (!cache_real_constant_value_(des, scope, expr, value))
	      return false;
	std::ostringstream out;
	out << "<real:ieee754=";
	append_exact_double_key_(out, value);
	out << ">";
	key = out.str();
	return true;
      }

      if (formal_type->base_type() == IVL_VT_STRING) {
	std::ostringstream out;
	if (const PEString*literal = dynamic_cast<const PEString*>(expr)) {
	      NetECString value(literal->parsed_value());
	      append_cache_netexpr_value_key_(out, &value);
	} else {
	      ivl_type_t parameter_type = 0;
	      const NetExpr*parameter = cache_simple_parameter_value_(
		    des, scope, expr, parameter_type);
	      const NetEConst*constant =
		    dynamic_cast<const NetEConst*>(parameter);
	      if (!constant || (!dynamic_cast<const NetECString*>(constant)
				&& !constant->value().is_string()))
		    return false;
	      append_cache_netexpr_value_key_(out, constant);
	}
	key = out.str();
	return true;
      }

      if (const netstruct_t*struct_type =
	    dynamic_cast<const netstruct_t*>(formal_type)) {
	if (struct_type->packed())
	      return false;
	ivl_type_t parameter_type = 0;
	if (const NetEArrayPattern*parameter =
	      dynamic_cast<const NetEArrayPattern*>(
		    cache_simple_parameter_value_(
			des, scope, expr, parameter_type))) {
	      std::unique_ptr<NetExpr>normalized(
		    cache_typed_netexpr_value_(parameter, formal_type));
	      if (!normalized)
		    return false;
	      std::ostringstream out;
	      append_cache_netexpr_value_key_(out, normalized.get());
	      key = out.str();
	      return true;
	}
	std::unique_ptr<NetExpr>literal(
	      cache_typed_literal_value_(des, scope, expr, formal_type));
	if (!literal)
	      return false;
	std::ostringstream out;
	append_cache_netexpr_value_key_(out, literal.get());
	key = out.str();
	return true;
      }

      return false;
}

static bool cache_value_parameter_is_deferred_(
	Design*des, NetScope*scope, const PExpr*expr,
	std::set<std::pair<const NetScope*,const NetExpr*> >&seen)
{
      if (!expr || !scope)
	    return false;

	/* A concrete intermediate parameter may have been assigned a compound
	 * expression in another (possibly still generic) class. Walk the common
	 * constant-expression wrappers so that N=M+1 retains M's symbolic
	 * provenance instead of being mistaken for N's currently evaluated
	 * provisional number. */
      if (const PEUnary*unary = dynamic_cast<const PEUnary*>(expr))
	    return cache_value_parameter_is_deferred_(
		des, scope, unary->get_expr(), seen);

      if (const PEBinary*binary = dynamic_cast<const PEBinary*>(expr))
	    return cache_value_parameter_is_deferred_(
		des, scope, binary->get_left(), seen)
		|| cache_value_parameter_is_deferred_(
		      des, scope, binary->get_right(), seen);

      if (const PETernary*ternary = dynamic_cast<const PETernary*>(expr))
	    return cache_value_parameter_is_deferred_(
		des, scope, ternary->get_cond(), seen)
		|| cache_value_parameter_is_deferred_(
		      des, scope, ternary->get_true(), seen)
		|| cache_value_parameter_is_deferred_(
		      des, scope, ternary->get_false(), seen);

      if (const PEConcat*concat = dynamic_cast<const PEConcat*>(expr)) {
	    if (concat->repeat_expr()
		&& cache_value_parameter_is_deferred_(
		      des, scope, concat->repeat_expr(), seen))
		  return true;
	    const std::vector<PExpr*>&parms = concat->stream_parms();
	    for (std::vector<PExpr*>::const_iterator cur = parms.begin()
		 ; cur != parms.end(); ++cur) {
		  if (cache_value_parameter_is_deferred_(
			des, scope, *cur, seen))
			return true;
	    }
	    return false;
      }

      if (const PECastSize*cast = dynamic_cast<const PECastSize*>(expr))
	    return cache_value_parameter_is_deferred_(
		des, scope, cast->cast_size(), seen)
		|| cache_value_parameter_is_deferred_(
		      des, scope, cast->cast_base(), seen);

      if (const PECastType*cast = dynamic_cast<const PECastType*>(expr))
	    return cache_value_parameter_is_deferred_(
		des, scope, cast->cast_base(), seen);

      if (const PECastSign*cast = dynamic_cast<const PECastSign*>(expr))
	    return cache_value_parameter_is_deferred_(
		des, scope, cast->cast_base(), seen);

      const PEIdent*ident = dynamic_cast<const PEIdent*>(expr);
	/* Literal leaves are concrete. Other expression shapes cannot reach the
	 * typed single-parameter semantic value path directly, and remain
	 * source-sensitive there. */
      if (!ident)
	    return false;

      const pform_scoped_name_t&path = ident->path();
	/* Use the same symbol-search domain as cache_integral_constant_value_.
	 * A qualified reference can still select a parameter in an enclosing
	 * unspecialized class. */
      if (path.name.empty())
	    return false;

      symbol_search_results search;
      if (!symbol_search(ident, des, scope, path, ident->lexical_pos(), &search)
	  || !search.par_val || !search.scope)
	    return false;
	if (!seen.insert(std::make_pair(search.scope, search.par_val)).second)
	    return false;

      const NetScope*owner_scope = normalize_class_scope_(search.scope);
      const netclass_t*owner_class = owner_scope
	    ? owner_scope->class_def() : 0;
      const PClass*owner_pclass = owner_scope
	    ? owner_scope->class_pform() : 0;
      if (owner_class && owner_pclass
	  && owner_pclass->has_parameter_port_list
	  && !owner_class->specialized_instance())
	    return true;

	/* A concrete intermediate specialization can retain a symbolic source
	 * from its enclosing generic master. Follow that source rather than
	 * treating its currently evaluated provisional value as concrete. */
      perm_string parameter_name = path.name.back().name;
      const NetScope*parameter_scope = search.scope;
      std::map<perm_string,NetScope::param_expr_t>::const_iterator parameter =
	    parameter_scope->parameters.find(parameter_name);
      if (parameter == parameter_scope->parameters.end() && owner_scope) {
	    parameter_scope = owner_scope;
	    parameter = parameter_scope->parameters.find(parameter_name);
      }
      if (parameter == parameter_scope->parameters.end())
	    return false;

      const PExpr*source_expr = parameter->second.source_expr
	    ? parameter->second.source_expr : parameter->second.val_expr;
      NetScope*source_scope = parameter->second.source_scope
	    ? parameter->second.source_scope : parameter->second.val_scope;
      if (!source_expr || !source_scope)
	    return false;

      return cache_value_parameter_is_deferred_(
	    des, source_scope, source_expr, seen);
}

static bool cache_value_parameter_is_deferred_(Design*des, NetScope*scope,
					       const PExpr*expr)
{
      std::set<std::pair<const NetScope*,const NetExpr*> >seen;
      return cache_value_parameter_is_deferred_(des, scope, expr, seen);
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

/* Class specializations are types, so equivalent named and positional
 * parameter assignments must select the same netclass_t.  In particular,
 * UVM parameterized registries commonly spell a class once as C#(A,B) and
 * again in a self typedef as C#(.T(A),.U(B),.R(A)), where R defaults to T.
 * Keeping the source spelling in the cache key makes those two legal uses
 * unrelated class types and causes derived-to-base $cast operations to fail.
 *
 * Express the complete effective parameter list in declaration order.  A
 * default which is a bare reference to an earlier formal uses that formal's
 * effective key. The diagnostic-free scalar evaluator also handles the
 * bounded arithmetic subset below; broader dependency graphs remain
 * conservatively source-sensitive.
 */
static std::string canonical_specialization_parm_key_(
		Design*des, NetScope*call_scope, NetScope*definition_scope,
		const parmvalue_t*overrides, const PClass*pclass)
{
      if (!overrides || !pclass)
	    return parmvalue_cache_key_(des, call_scope, overrides, pclass);

	/* A single parameter has no dependency graph to traverse, so express its
	 * effective value independent of whether the use is bare, #(), named, or
	 * positional. Bare uses inside an unspecialized generic master are kept
	 * deferred by specialize_bare_class_at_concrete_use(); an empty override
	 * which reaches this helper is therefore a concrete default specialization,
	 * not the generic master itself. */
      if (pclass->parameter_order.size() == 1) {
	    perm_string formal_name = pclass->parameter_order.front();
	    std::map<perm_string,LexicalScope::param_expr_t*>::const_iterator formal =
		  pclass->parameters.find(formal_name);
	    if (formal == pclass->parameters.end() || !formal->second)
		  return parmvalue_cache_key_(des, call_scope, overrides, pclass);

	    const PExpr*actual = 0;
	    NetScope*actual_scope = call_scope;
	    if (overrides->by_order) {
		  if (overrides->by_order->size() > 1)
			return parmvalue_cache_key_(des, call_scope, overrides, pclass);
		  if (!overrides->by_order->empty())
			actual = overrides->by_order->front();
	    } else if (overrides->by_name) {
		  if (overrides->by_name->size() > 1)
			return parmvalue_cache_key_(des, call_scope, overrides, pclass);
		  if (!overrides->by_name->empty()) {
			if (overrides->by_name->front().name != formal_name)
			      return parmvalue_cache_key_(des, call_scope, overrides, pclass);
			actual = overrides->by_name->front().parm;
		  }
	    } else {
		  return parmvalue_cache_key_(des, call_scope, overrides, pclass);
	    }
	    if (!actual) {
		  actual = formal->second->expr;
		  actual_scope = definition_scope;
	    }
	    if (!actual)
		  return parmvalue_cache_key_(des, call_scope, overrides, pclass);
	    if (!formal->second->type_flag
		&& cache_value_parameter_is_deferred_(des, actual_scope, actual))
		  return parmvalue_cache_key_(des, call_scope, overrides, pclass);

	    std::ostringstream out;
	    out << "C|" << formal_name << "=";
	    if (formal->second->type_flag) {
		  std::ostringstream actual_key;
		  append_cache_expr_key_(des, actual_scope, actual_key, actual, 1);
		  const std::string key = actual_key.str();
		  if (key.empty()
		      || key.find("<forwarded-type-param@") != std::string::npos
		      || key.find("@scope=") != std::string::npos)
			return parmvalue_cache_key_(des, call_scope, overrides, pclass);
		  out << key;
		  return out.str();
	    }

	      /* An explicitly typed integral value formal gives every actual one
	       * common width/sign context. Canonicalize constants after that
	       * conversion. For an untyped formal retain the actual's cache key,
	       * including its source width: #(8'd3) and #(32'd3) remain distinct,
	       * while the same effective default in named/positional/omitted form
	       * selects one specialization. */
	    if (!formal->second->data_type) {
		  std::ostringstream actual_key;
		  append_cache_expr_key_(des, actual_scope, actual_key, actual, 0);
		  const std::string key = actual_key.str();
		  if (key.empty()
		      || key.find("<forwarded-type-param@") != std::string::npos
		      || key.find("@scope=") != std::string::npos)
			return parmvalue_cache_key_(des, call_scope, overrides, pclass);
		  out << key;
		  return out.str();
	    }
	    ivl_type_t formal_type = formal->second->data_type->elaborate_type(
		  des, definition_scope);
	    if (!formal_type)
		  return parmvalue_cache_key_(des, call_scope, overrides, pclass);

	      /* Real and string values, plus the supported constant unpacked-
	       * struct pattern, need the same semantic key whether an actual is a
	       * literal/expression or a parameter reference. Their source forms
	       * are not a class type identity. */
	    const bool aggregate_constant =
		  dynamic_cast<const netstruct_t*>(formal_type)
		  && !formal_type->packed();
	    if (formal_type->base_type() == IVL_VT_REAL
		|| formal_type->base_type() == IVL_VT_STRING
		|| aggregate_constant) {
		  std::string value_key;
		  if (!cache_typed_constant_value_key_(
			des, actual_scope, actual, formal_type, value_key)) {
			const PExpr*origin = actual;
			NetScope*origin_scope = actual_scope;
			if (!cache_parameter_source_lineage_(
			      des, origin_scope, origin)
			    || (!cache_typed_constant_value_key_(
				des, origin_scope, origin,
				formal_type, value_key)
				&& !cache_source_lineage_key_(
				      des, origin_scope, origin, value_key)))
			      return parmvalue_cache_key_(
				    des, call_scope, overrides, pclass);
		  }
		  append_cache_ivl_type_key_(des, out, formal_type);
		  out << "=" << value_key;
		  return out.str();
	    }

	    if (!formal_type->packed()
		|| (formal_type->base_type() != IVL_VT_BOOL
		    && formal_type->base_type() != IVL_VT_LOGIC)
		|| formal_type->packed_width() <= 0)
		  return parmvalue_cache_key_(des, call_scope, overrides, pclass);

	    verinum value;
	    bool unbounded = false;
	    if (!cache_integral_constant_value_(
		  des, actual_scope, actual, value, unbounded,
		  formal_type->packed_width()))
		  return parmvalue_cache_key_(des, call_scope, overrides, pclass);
	    value = cast_to_width(value, formal_type->packed_width());
	    value.has_sign(formal_type->get_signed());
	    value.has_len(true);
	    if (formal_type->base_type() == IVL_VT_BOOL)
		  value.cast_to_int2();
	    append_cache_ivl_type_key_(des, out, formal_type);
	    out << "=<constant:variant=integral:unbounded=" << unbounded << ":";
	    append_exact_verinum_key_(out, value);
	    out << ">";
	    return out.str();
      }

	/* Keep the broad semantic cache limited to the multi-parameter class
	 * pattern it was introduced for. The single-parameter path above rejects
	 * unresolved forwarded/scope-sensitive keys, and bare generic-master uses
	 * are deferred before reaching this helper. */
      if (pclass->parameter_order.size() < 2)
	    return parmvalue_cache_key_(des, call_scope, overrides, pclass);

      bool has_bare_dependent_default = false;
      std::set<perm_string> prior_formals;
      for (std::list<perm_string>::const_iterator name_it =
		   pclass->parameter_order.begin()
	   ; name_it != pclass->parameter_order.end(); ++name_it) {
	    std::map<perm_string,LexicalScope::param_expr_t*>::const_iterator formal =
		  pclass->parameters.find(*name_it);
	    if (formal != pclass->parameters.end() && formal->second) {
		  for (std::set<perm_string>::const_iterator prior =
		       prior_formals.begin(); prior != prior_formals.end(); ++prior) {
			if (pexpr_matches_parameter_name_(formal->second->expr, *prior)) {
			      has_bare_dependent_default = true;
			      break;
			}
		  }
	    }
	    prior_formals.insert(*name_it);
      }
      if (!has_bare_dependent_default)
	    return parmvalue_cache_key_(des, call_scope, overrides, pclass);

      std::map<perm_string,const PExpr*> supplied;
      if (overrides->by_order) {
	    std::list<perm_string>::const_iterator name_it =
		  pclass->parameter_order.begin();
	    for (std::list<PExpr*>::const_iterator expr_it =
		       overrides->by_order->begin()
		 ; expr_it != overrides->by_order->end(); ++expr_it) {
		  if (name_it == pclass->parameter_order.end())
			return parmvalue_cache_key_(des, call_scope, overrides, pclass);
		  supplied[*name_it++] = *expr_it;
	    }
      } else if (overrides->by_name) {
	    for (std::list<named_pexpr_t>::const_iterator cur =
		       overrides->by_name->begin()
		 ; cur != overrides->by_name->end(); ++cur) {
		  if (pclass->parameters.find(cur->name) == pclass->parameters.end()
		      || supplied.find(cur->name) != supplied.end())
			return parmvalue_cache_key_(des, call_scope, overrides, pclass);
		  supplied[cur->name] = cur->parm;
	    }
      } else {
	    return parmvalue_cache_key_(des, call_scope, overrides, pclass);
      }

      std::map<perm_string,std::string> effective;
      std::ostringstream out;
      out << "C";
      for (std::list<perm_string>::const_iterator name_it =
		   pclass->parameter_order.begin()
	   ; name_it != pclass->parameter_order.end(); ++name_it) {
	    std::map<perm_string,LexicalScope::param_expr_t*>::const_iterator formal =
		  pclass->parameters.find(*name_it);
	    if (formal == pclass->parameters.end() || !formal->second
		|| !formal->second->expr || !formal->second->type_flag)
		  return parmvalue_cache_key_(des, call_scope, overrides, pclass);
	    const int formal_kind = 1;

	    const PExpr*default_expr = formal->second->expr;
	    std::string default_key;
	    for (std::map<perm_string,std::string>::const_iterator prior =
		       effective.begin(); prior != effective.end(); ++prior) {
		  if (pexpr_matches_parameter_name_(default_expr, prior->first)) {
			default_key = prior->second;
			break;
		  }
	    }
	    if (default_key.empty()) {
		  std::ostringstream tmp;
		  append_cache_expr_key_(des, definition_scope, tmp, default_expr,
					 formal_kind);
		  default_key = tmp.str();
	    }
	    if (default_key.empty()
		|| default_key.find("<forwarded-type-param@") != std::string::npos
		|| default_key.find("@scope=") != std::string::npos)
		  return parmvalue_cache_key_(des, call_scope, overrides, pclass);

	    std::map<perm_string,const PExpr*>::const_iterator actual =
		  supplied.find(*name_it);
	    if (actual == supplied.end()) {
		  if (default_key.compare(0, 12, "<class-type:") != 0)
			return parmvalue_cache_key_(des, call_scope, overrides, pclass);
		  effective[*name_it] = default_key;
		  out << "|" << *name_it << "=" << default_key;
		  continue;
	    }

	    std::ostringstream tmp;
	    append_cache_expr_key_(des, call_scope, tmp, actual->second,
				   formal_kind);
	    const std::string actual_key = tmp.str();
	    if (actual_key.empty()
		|| actual_key.find("<forwarded-type-param@") != std::string::npos
		|| actual_key.find("@scope=") != std::string::npos)
		  return parmvalue_cache_key_(des, call_scope, overrides, pclass);
	    if (actual_key.compare(0, 12, "<class-type:") != 0)
		  return parmvalue_cache_key_(des, call_scope, overrides, pclass);
	    effective[*name_it] = actual_key;
	    out << "|" << *name_it << "=" << actual_key;
      }

      return out.str();
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
static std::vector<netclass_t*> all_specialized_classes_;
static std::set<netclass_t*> all_specialized_class_set_;
static std::set<netclass_t*> repaired_specialized_class_set_;

void release_elaboration_specialization_caches()
{
      specialization_scope_path_cache_.clear();
      specialization_pexpr_dump_cache_.clear();
      specialization_netexpr_value_key_cache_.clear();
      specialization_type_dump_cache_.clear();
      specialization_data_type_dump_cache_.clear();
      specialized_class_source_key_cache_.clear();
      specialized_class_semantic_key_cache_.clear();

      classes_being_scope_elaborated_.clear();
      classes_with_randomization_methods_validated_.clear();
      pending_specialized_body_elaboration_set_.clear();
      pending_specialized_method_seed_set_.clear();
      all_specialized_class_set_.clear();
      repaired_specialized_class_set_.clear();

	/* clear() retains vector capacity; swap with empty storage because no
	 * later target callback consults these elaboration work registries. */
      std::vector<netclass_t*>().swap(pending_specialized_body_elaboration_);
      std::vector<netclass_t*>().swap(pending_specialized_method_seed_);
      std::vector<netclass_t*>().swap(all_specialized_classes_);
}

static bool is_randomize_hook_name_(perm_string name)
{
      return name == perm_string::literal("pre_randomize")
	  || name == perm_string::literal("post_randomize");
}

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

static bool should_seed_specialized_function_body_(perm_string name)
{
      /* IEEE 1800-2023 18.6.2 defines the randomization callbacks as void
       * functions. A specialized class must retain their bodies even though
       * the callbacks are invoked implicitly by the built-in randomize(). */
      return is_randomize_hook_name_(name)
	  || should_seed_specialized_method_body_(name);
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

	// Seed the always-needed housekeeping methods (new/get_type/...)
	// AND every VIRTUAL method. A virtual override is a runtime
	// dispatch target: when a base handle to this specialization is
	// dispatched, the object's actual class must carry an elaborated
	// (and therefore emitted) override body, or dispatch silently
	// falls through to the base method. Handle/variable declarations
	// specialize with fully_elaborate=false (seed only), so without
	// this the override for e.g. `sequencer#(item)::get_next` was
	// never elaborated and virtual dispatch resolved to the base stub.
	      for (map<perm_string,PFunction*>::iterator cur = pclass->funcs.begin()
		 ; cur != pclass->funcs.end() ; ++cur) {
		    NetScope*scope = class_scope->child(hname_t(cur->first));
		    if (!scope)
			  continue;
		    // IEEE 1800-2017 8.20 makes an override of an inherited
		    // virtual method implicitly virtual. elaborate_sig records that
		    // semantic fact on the elaborated method scope; the parse-form
		    // method flag only records an explicit `virtual' keyword. Using
		    // only the latter here skipped bodies such as
		    // uvm_analysis_imp#(...)::write, so runtime dispatch through the
		    // virtual interface fell back to the base error stub.
		    if (!should_seed_specialized_function_body_(cur->first)
			&& !cur->second->is_virtual_method()
			&& !scope->is_virtual_method())
			  continue;
		    if (cur->second->get_statement() == 0)
			  continue;
		    cur->second->elaborate_sig(des, scope);
		    cur->second->elaborate(des, scope);
	      }

	      for (map<perm_string,PTask*>::iterator cur = pclass->tasks.begin()
		 ; cur != pclass->tasks.end() ; ++cur) {
		    NetScope*scope = class_scope->child(hname_t(cur->first));
		    if (!scope)
			  continue;
		    if (!should_seed_specialized_method_body_(cur->first)
			&& !cur->second->is_virtual_method()
			&& !scope->is_virtual_method())
			  continue;
		    if (cur->second->get_statement() == 0)
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

void repair_specialized_class_property_types(Design*des)
{
      size_t idx = 0;
      while (idx < all_specialized_classes_.size()) {
	    netclass_t*cls = all_specialized_classes_[idx++];
	    if (!cls)
		  continue;

	    /* A type-only use creates the specialization scope with
	     * fully_elaborate=false. Complete its signature now, before any
	     * expression can snapshot property or signal types. elaborate_sig's
	     * own guard and the specialization cache make mutual A#()<->B#()
	     * references terminate; newly created specializations append to this
	     * same work list. */
	    const NetScope*class_scope = cls->class_scope();
	    const PClass*pclass = class_scope ? class_scope->class_pform() : 0;
	    if (pclass && cls->scope_ready()
		&& !cls->sig_elaborated() && !cls->sig_elaborating())
		  cls->elaborate_sig(des, const_cast<PClass*>(pclass));

	    if (cls->sig_elaborated()
		&& repaired_specialized_class_set_.insert(cls).second)
		  cls->repair_bare_class_property_types(des);
      }
}

/* Resolve the interface-class graph independently of the concrete super
 * chain. This function is deliberately shared by generic, specialized and
 * in-place class-scope construction so all three paths enforce identical
 * 8.26 semantics. */
static const netclass_t* resolve_class_relation_type_(Design*des,
					       NetScope*class_scope,
					       const data_type_t*relation_type)
{
      if (!relation_type)
	    return 0;

      ivl_type_t resolved = const_cast<data_type_t*>(relation_type)
	    ->elaborate_type(des, class_scope);
      const netclass_t*relation = dynamic_cast<const netclass_t*>(resolved);
      if (relation)
	    return relation;

      perm_string relation_name;
      if (const typeref_t*relation_ref =
		    dynamic_cast<const typeref_t*>(relation_type)) {
	    if (typedef_t*td = relation_ref->typedef_ref())
		  relation_name = td->name;
      } else if (const class_type_t*relation_class =
		       dynamic_cast<const class_type_t*>(relation_type)) {
	    relation_name = relation_class->name;
      }

      if (relation_name) {
	    relation = class_scope->find_class(des, relation_name);
	    if (!relation)
		  relation = ensure_visible_class_type(des, class_scope,
					       relation_name);
      }
      return relation;
}

static void resolve_class_interface_relations_(Design*des,
					NetScope*class_scope,
					PClass*pclass,
					netclass_t*use_class)
{
      if (!(class_scope && pclass && pclass->type && use_class))
	    return;

      class_type_t*use_type = pclass->type;
      use_class->set_interface_class(use_type->interface_class);

      for (const std::unique_ptr<data_type_t>&relation_type :
		 use_type->interface_types) {
	    const netclass_t*relation = resolve_class_relation_type_(
		  des, class_scope, relation_type.get());
	    if (!relation) {
		  cerr << relation_type->get_fileline() << ": error: "
		       << "Interface relationship of class `" << use_type->name
		       << "' does not resolve to a class type." << endl;
		  des->errors += 1;
		  continue;
	    }

	    if (!relation->is_interface_class()) {
		  cerr << relation_type->get_fileline() << ": error: Class `"
		       << relation->get_name()
		       << "' is not an interface class and cannot appear in an "
		       << (use_type->interface_class ? "interface extends"
						     : "implements")
		       << " list." << endl;
		  des->errors += 1;
		  continue;
	    }

	    if (relation == use_class || relation->implements_interface(use_class)) {
		  cerr << relation_type->get_fileline() << ": error: Cyclic "
		       << "interface-class relationship involving `"
		       << use_type->name << "'." << endl;
		  des->errors += 1;
		  continue;
	    }

	    use_class->add_interface(relation);
      }
}

const netclass_t* elaborate_specialized_class_type(Design*des, NetScope*call_scope,
						   const netclass_t*base_class,
						   const parmvalue_t*overrides,
						   bool fully_elaborate)
{
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

      std::ostringstream key_prefix;
	// Use the pclass (parse-tree) pointer as the stable key prefix.
	// The netclass_t (base_class) pointer is NOT stable — the same
	// parsed class can be elaborated into multiple netclass_t objects
	// when mutual-reference cycles are resolved.  pclass is the
	// unique canonical representative of the class definition.
      key_prefix << (const void*)pclass << "|";
      const std::string source_key_str = key_prefix.str()
	    + parmvalue_cache_key_(des, call_scope, overrides, pclass);
      const std::string semantic_parms = canonical_specialization_parm_key_(
	    des, call_scope, definition_scope, overrides, pclass);
      const bool has_semantic_key = semantic_parms.compare(0, 2, "C|") == 0;
      const std::string semantic_key_str = has_semantic_key
	    ? key_prefix.str() + semantic_parms : std::string();
      if (trace_specialization_key_(base_class)) {
	    cerr << pclass->get_fileline() << ": trace spec-key"
		 << " class=" << specialization_perf_base_label_(base_class)
		 << " caller=";
	    if (call_scope)
		  cerr << scope_path(call_scope);
	    else
		  cerr << "<null>";
	    cerr << " key=" << source_key_str;
	    if (has_semantic_key)
		  cerr << " semantic-key=" << semantic_key_str;
	    cerr << endl;
      }
	      const netclass_t*cached_result = 0;
	      std::map<std::string,const netclass_t*>::const_iterator cached =
		    specialized_class_source_key_cache_.find(source_key_str);
	      if (cached != specialized_class_source_key_cache_.end()) {
		    cached_result = cached->second;
	      } else if (has_semantic_key) {
		    std::map<std::string,const netclass_t*>::const_iterator semantic_cached =
			  specialized_class_semantic_key_cache_.find(semantic_key_str);
		    if (semantic_cached != specialized_class_semantic_key_cache_.end()) {
			  cached_result = semantic_cached->second;
			  specialized_class_source_key_cache_[source_key_str] = cached_result;
		    }
	      }
	      if (cached_result) {
		    note_specialization_cache_hit_();
		    netclass_t*cached_class = const_cast<netclass_t*>(cached_result);
		    if (!fully_elaborate) {
			  enqueue_pending_specialized_method_seed_(cached_class);
			  return cached_result;
		    }
		    const PClass*cached_pclass = cached_class->class_scope()
			  ? cached_class->class_scope()->class_pform() : 0;
		    if (cached_pclass && cached_class->scope_ready()) {
			  if (!cached_class->sig_elaborated() && !cached_class->sig_elaborating())
				cached_class->elaborate_sig(des, const_cast<PClass*>(cached_pclass));
			  // Cache hits need the same post-root body deferral as misses.
			  // Queue even during recursive signature elaboration so a full
			  // elaboration request is not lost before that recursion unwinds.
			  enqueue_pending_specialized_class_body_(cached_class);
		    }
	    return cached_result;
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
      use_class->set_interface_class(use_type->interface_class);
      if (use_type->is_covergroup_stub)
	    use_class->set_is_covergroup(true);
      if (!use_type->covergroups.empty())
	    use_class->set_has_embedded_covergroups(true);
      use_class->set_specialized_instance(true);
      if (all_specialized_class_set_.insert(use_class).second)
	    all_specialized_classes_.push_back(use_class);
      set_scope_timescale(des, class_scope, pclass);
      specialized_class_source_key_cache_[source_key_str] = use_class;
      if (has_semantic_key)
	    specialized_class_semantic_key_cache_[semantic_key_str] = use_class;

      class_scope->add_typedefs(&pclass->typedefs);
      class_scope->add_nettypes(des, &pclass->nettypes);
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
		       << " overrides=" << parmvalue_cache_key_(des, call_scope, overrides, pclass)
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
	    base_type = specialize_bare_class_at_concrete_use(
	          des, class_scope, use_type->base_type.get(), base_type, true);
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
      use_class->configure_pure_constraints(des, pclass);
      resolve_class_interface_relations_(des, class_scope,
					 const_cast<PClass*>(pclass), use_class);

      collect_scope_signals(class_scope, pclass->wires);
      elaborate_scope_events_(des, class_scope, pclass->events);
	// Non-static class `event` properties are per-instance: flag each
	// so trigger/wait elaboration routes them through per-object
	// runtime storage (IEEE 1800-2017 15.5). An explicitly static
	// property remains the one class-scope event shared by all objects
	// (IEEE 1800-2017 8.9).
      for (std::map<perm_string,PEvent*>::const_iterator et = pclass->events.begin()
		 ; et != pclass->events.end() ; ++et) {
	    if (NetEvent*ev = class_scope->find_event(et->first)) {
		  if (ev->lifetime_override() != IVL_VLT_STATIC)
			ev->set_class_event();
	    }
      }
      elaborate_scope_enumerations(des, class_scope, pclass->enum_sets);

      for (std::map<perm_string,PTask*>::const_iterator cur = pclass->tasks.begin()
		 ; cur != pclass->tasks.end() ; ++cur) {
	    hname_t use_name(cur->first);
	    NetScope*method_scope = new NetScope(class_scope, use_name, NetScope::TASK);
	    method_scope->is_auto(true);
	    method_scope->is_virtual_method(method_scope->is_virtual_method()
					    || cur->second->is_virtual_method());
	    method_scope->set_line(cur->second);
	    method_scope->add_imports(&cur->second->explicit_imports);
	    cur->second->elaborate_scope(des, method_scope);
      }

      for (std::map<perm_string,PFunction*>::const_iterator cur = pclass->funcs.begin()
		 ; cur != pclass->funcs.end() ; ++cur) {
		    hname_t use_name(cur->first);
		    NetScope*method_scope = new NetScope(class_scope, use_name, NetScope::FUNC);
		    method_scope->is_auto(true);
	    method_scope->is_virtual_method(method_scope->is_virtual_method()
					    || cur->second->is_virtual_method());
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
      if (classes_with_randomization_methods_validated_.insert(pclass).second) {
	    /* IEEE 1800-2017 18.6, 18.8 and 18.9: every class has these
	     * built-in randomization methods, and user declarations cannot
	     * override them.  Diagnose the declaration itself instead of
	     * allowing an ordinary class method to silently replace the
	     * language-defined operation. */
	    const perm_string randomize = perm_string::literal("randomize");
	    const perm_string rand_mode = perm_string::literal("rand_mode");
	    const perm_string constraint_mode =
		  perm_string::literal("constraint_mode");
	    const perm_string pre_randomize =
		  perm_string::literal("pre_randomize");
	    const perm_string post_randomize =
		  perm_string::literal("post_randomize");

	    for (map<perm_string,PFunction*>::const_iterator cur =
		       pclass->funcs.begin(); cur != pclass->funcs.end(); ++cur) {
		  if (cur->first != randomize && cur->first != rand_mode
		      && cur->first != constraint_mode)
			continue;
		  cerr << cur->second->get_fileline() << ": error: Class method `"
		       << cur->first << "' is a built-in randomization method and "
		       << "cannot be overridden." << endl;
		  des->errors += 1;
	    }

	    for (map<perm_string,PTask*>::const_iterator cur =
		       pclass->tasks.begin(); cur != pclass->tasks.end(); ++cur) {
		  if (cur->first == pre_randomize || cur->first == post_randomize) {
			cerr << cur->second->get_fileline()
			     << ": error: Class randomization hook `" << cur->first
			     << "' shall be declared as a void function." << endl;
			des->errors += 1;
			continue;
		  }
		  if (cur->first != randomize && cur->first != rand_mode
		      && cur->first != constraint_mode)
			continue;
		  cerr << cur->second->get_fileline() << ": error: Class method `"
		       << cur->first << "' is a built-in randomization method and "
		       << "cannot be overridden." << endl;
		  des->errors += 1;
	    }
      }

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
	// M11-1/2: a standalone covergroup type IS a covergroup class;
	// mark it at creation so method dispatch (sample(),
	// get_inst_coverage()...) recognizes instances before the
	// body-elaboration pass synthesizes the bins.
      if (use_type->is_covergroup_standalone)
	    use_class->set_is_covergroup(true);

      NetScope*class_scope = new NetScope(scope, hname_t(pclass->pscope_name()),
					  NetScope::CLASS, scope->unit());
      class_scope->set_line(pclass);
      class_scope->set_class_def(use_class);
      class_scope->set_class_pform(pclass);
      use_class->set_class_scope(class_scope);
      use_class->set_definition_scope(scope);
      use_class->set_virtual(use_type->virtual_class);
      use_class->set_interface_class(use_type->interface_class);
      if (use_type->is_covergroup_stub)
	    use_class->set_is_covergroup(true);
      if (!use_type->covergroups.empty())
	    use_class->set_has_embedded_covergroups(true);
      set_scope_timescale(des, class_scope, pclass);
      scope->add_class(use_class);

      class_scope->add_typedefs(&pclass->typedefs);
      class_scope->add_nettypes(des, &pclass->nettypes);
      collect_scope_parameters(des, class_scope, pclass->parameters);

      const netclass_t*use_base_class = 0;
      if (use_type->base_type) {
	    ivl_type_t base_type = use_type->base_type->elaborate_type(des, class_scope);
	    base_type = specialize_bare_class_at_concrete_use(
	          des, class_scope, use_type->base_type.get(), base_type, true);
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
      use_class->configure_pure_constraints(des, pclass);
      resolve_class_interface_relations_(des, class_scope, pclass, use_class);

      collect_scope_signals(class_scope, pclass->wires);

        // Class named events (e.g. "event m_event;") are stored in the
        // pform class scope event table, but need to be emitted into the
        // elaborated class NetScope so method symbol lookup can resolve
        // @m_event / ->m_event / m_event references.
      elaborate_scope_events_(des, class_scope, pclass->events);
	// Non-static class `event` properties are per-instance: flag each
	// so trigger/wait elaboration routes them through per-object
	// runtime storage (IEEE 1800-2017 15.5). An explicitly static
	// property remains the one class-scope event shared by all objects
	// (IEEE 1800-2017 8.9).
      for (std::map<perm_string,PEvent*>::const_iterator et = pclass->events.begin()
		 ; et != pclass->events.end() ; ++et) {
	    if (NetEvent*ev = class_scope->find_event(et->first)) {
		  if (ev->lifetime_override() != IVL_VLT_STATIC)
			ev->set_class_event();
	    }
      }

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
	    method_scope->is_virtual_method(method_scope->is_virtual_method()
					    || cur->second->is_virtual_method());
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
	    method_scope->is_virtual_method(method_scope->is_virtual_method()
					    || cur->second->is_virtual_method());
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
      use_class->set_interface_class(use_type->interface_class);

      const netclass_t*use_base_class = 0;
      if (use_type->base_type) {
	    ivl_type_t base_type = use_type->base_type->elaborate_type(des, class_scope);
	    base_type = specialize_bare_class_at_concrete_use(
	          des, class_scope, use_type->base_type.get(), base_type, true);
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
      use_class->configure_pure_constraints(des, pclass);
      resolve_class_interface_relations_(des, class_scope, pclass, use_class);

      for (map<perm_string,PTask*>::iterator cur = pclass->tasks.begin()
		 ; cur != pclass->tasks.end() ; ++cur) {
	    hname_t use_name(cur->first);
	    NetScope*method_scope = class_scope->child(use_name);
	    if (!method_scope)
		  method_scope = new NetScope(class_scope, use_name, NetScope::TASK);
	    method_scope->is_auto(true);
	    method_scope->is_virtual_method(method_scope->is_virtual_method()
					    || cur->second->is_virtual_method());
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
	    method_scope->is_virtual_method(method_scope->is_virtual_method()
					    || cur->second->is_virtual_method());
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

      NetScope*task_scope = scope->child(use_name);
	// Class specialization can resolve a package subroutine before the
	// package's ordinary subroutine pass reaches it. Keep that lazily
	// materialized scope: replacing it would strand its procedure graph on
	// objects that are no longer reachable through the scope tree.
      if (task_scope && task_scope->type() == NetScope::TASK
          && task_scope->task_pform() == task)
	    return;

      if (!task_scope || task_scope->type() != NetScope::TASK
          || task_scope->task_pform())
	    task_scope = new NetScope(scope, use_name, NetScope::TASK);
      task_scope->is_auto(task->is_auto());
      task_scope->is_virtual_method(task_scope->is_virtual_method()
				     || task->is_virtual_method());
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

      NetScope*task_scope = scope->child(use_name);
	// Match the task path above. Package functions can also be materialized
	// by an early class/type lookup and must remain the canonical scope.
      if (task_scope && task_scope->type() == NetScope::FUNC
          && task_scope->func_pform() == task)
	    return;

      if (!task_scope || task_scope->type() != NetScope::FUNC
          || task_scope->func_pform())
	    task_scope = new NetScope(scope, use_name, NetScope::FUNC);
      task_scope->is_auto(task->is_auto());
      task_scope->is_virtual_method(task_scope->is_virtual_method()
				     || task->is_virtual_method());
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
      scope->add_nettypes(des, &nettypes);

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
	// M12: record modport names on interface scopes for VPI —
	// M12-6 adds each modport's port list with VPI direction
	// codes (ref ports map to vpiNoDirection).
      if (is_interface) {
	    for (std::map<perm_string,PModport*>::const_iterator mp = modports.begin()
		       ; mp != modports.end() ; ++ mp) {
		  scope->add_modport_name(mp->first);
		  NetScope::modport_port_list_t ports;
		  if (mp->second) {
			for (std::map<perm_string,PModport::simple_port_t>::const_iterator
				   sp = mp->second->simple_ports.begin()
				   ; sp != mp->second->simple_ports.end() ; ++ sp) {
			      int dir;
			      switch (sp->second.first) {
				  case NetNet::PINPUT:  dir = 1; break; // vpiInput
				  case NetNet::POUTPUT: dir = 2; break; // vpiOutput
				  case NetNet::PINOUT:  dir = 3; break; // vpiInout
				  default:              dir = 5; break; // vpiNoDirection
			      }
			      ports.push_back(std::make_pair(sp->first, dir));
			}
		  }
		  scope->add_modport_ports(ports);
	    }
      }

	// M13: make let declarations visible to expression elaboration.
      for (std::map<perm_string,PLet*>::const_iterator lt = lets.begin()
		 ; lt != lets.end() ; ++ lt)
	    scope->add_let(lt->first, lt->second);
      if (debug_scopes) {
	    cerr << get_fileline() << ": Module::elaborate_scope: "
		 << "Elaborate " << scope_path(scope) << "." << endl;
      }

      scope->add_typedefs(&typedefs);
      scope->add_nettypes(des, &nettypes);

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
      set<long> seen_genvars;
      vector<long> genvar_values;
      while (test->value().as_long()) {

	      // Validate the complete control sequence before allocating any
	      // generated scopes. An invalid loop used to retain hundreds of
	      // thousands of NetScope trees before reaching the existing
	      // infinite-loop guard, consuming gigabytes merely to issue an
	      // error. The loop test and step are constant expressions in the
	      // containing scope, so their values do not depend on elaborating
	      // the generated body.
	    hname_t use_name (scope_name, genvar);
	    if (container->child(use_name)
	        || !seen_genvars.insert(genvar).second) {
		  cerr << get_fileline() << ": error: "
		          "Trying to create a duplicate generate scope named \""
		       << use_name << "\"." << endl;
		  des->errors += 1;
		  return false;
	    }
	    genvar_values.push_back(genvar);

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

      delete test_ex;

      for (vector<long>::const_iterator cur = genvar_values.begin()
	     ; cur != genvar_values.end(); ++cur) {
	    genvar = *cur;
	    container->genvar_tmp_val = genvar;

	      // The actual name of the scope includes the genvar so
	      // that each instance has a unique name in the
	      // container. The format of using [] is part of the
	      // Verilog standard.
	    hname_t use_name(scope_name, genvar);

	    if (debug_scopes)
		  cerr << get_fileline() << ": debug: "
		          "Create generated scope " << use_name << endl;

	    NetScope*scope = new NetScope(container, use_name,
					  NetScope::GENBLOCK);
	    scope->set_generate_definition(this);
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
      scope->set_generate_definition(this);
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
      scope->set_generate_definition(item);
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
      scope->set_generate_definition(this);
      scope->set_line(get_file(), get_lineno());
      scope->add_imports(&explicit_imports);

      elaborate_subscope_(des, scope);

      return true;
}

void PGenerate::elaborate_subscope_direct_(Design*des, NetScope*scope)
{
      scope->add_active_generate(this);
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
      scope->add_nettypes(des, &nettypes);

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
      bool selected_bind_target = false;
      if (is_bind_instance_) {
	    for (vector<bind_instance_filter_t*>::const_iterator filter
		       = bind_filter_.begin() ; filter != bind_filter_.end()
		       ; ++filter) {
		  if ((*filter)->mode != bind_instance_filter_t::DEFINITION) {
			selected_bind_target = true;
			break;
		  }
	    }
      }
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
	    if (selected_bind_target) continue;

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
	    my_scope->set_module_definition(mod);
	    my_scope->is_bind_instance(is_bind_instance_);
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
void PEvent::elaborate_scope(Design*des, NetScope*scope) const
{
      NetEvent*ev = new NetEvent(name_);
      ev->lexical_pos(lexical_pos_);
      ev->lifetime_override(lifetime_override_);
      ev->set_line(*this);

	// An unpacked array of named events (IEEE 1800-2017 6.20, e.g.
	// `event arr[3];`): each element is its own independent named
	// event. The declared bound must resolve to a constant range;
	// reserve a contiguous run of design-global slots, one per
	// element, for the runtime's flat per-slot event table.
      if (array_dims_ && !array_dims_->empty()) {
	    if (array_dims_->size() > 1) {
		    // Parser already rejects this, but guard here too in
		    // case this ever gets reached some other way.
		  cerr << get_fileline() << ": sorry: multi-dimensional "
		          "named-event arrays are not supported (`" << name_
		       << "')." << endl;
		  des->errors += 1;
	    } else {
		  long msb = 0, lsb = 0;
		  bool ok = evaluate_range(des, scope, this,
					    array_dims_->front(), msb, lsb);
		  if (ok) {
			unsigned count = (msb >= lsb) ? (unsigned)(msb-lsb+1)
			                              : (unsigned)(lsb-msb+1);
			ev->set_event_array(msb, lsb, count);
		  }
	    }
      }

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
      scope->add_nettypes(des, &nettypes);

	// Scan the parameters in the function, and store the information
        // needed to evaluate the parameter expressions.

      collect_scope_parameters(des, scope, parameters);

      collect_scope_signals(scope, wires);

	// A typedef enum declared directly in a function belongs to the
	// function lexical scope. Elaborating only enums from nested named
	// blocks leaves the netenum_t shape allocated but all literal/name
	// slots empty, which later makes enum methods and target metadata
	// unusable. Populate the function-local enum before its declarations
	// and body are elaborated.
      elaborate_scope_enumerations(des, scope, enum_sets);

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
      scope->add_nettypes(des, &nettypes);

	// Scan the parameters in the task, and store the information
        // needed to evaluate the parameter expressions.

      collect_scope_parameters(des, scope, parameters);

      collect_scope_signals(scope, wires);

	// Match functions and every other lexical scope: task-local enum
	// typedefs must be fully elaborated before local variables use them.
      elaborate_scope_enumerations(des, scope, enum_sets);

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

	      /* A named block scope is elaborated ONCE per parent scope.
		 Some paths reach the same body twice -- a class
		 constructor at $unit scope is one -- and building a
		 second NetScope for the same name under the same parent
		 orphans the first: the signature pass declares the
		 block's locals into the scope it saw, and the body is
		 then elaborated against the newer, EMPTY one. That is
		 how `foreach' over a runtime-sized array inside such a
		 constructor reached elaborate_runtime_array_ with no
		 loop-variable signal and aborted the compiler
		 (elaborate.cc, assert idx_sig).

		 Two blocks of the same name cannot legitimately share a
		 parent -- unnamed blocks get generated unique names, and
		 separate module instances or generate iterations have
		 separate parent scopes -- so an existing child of this
		 name IS this block, and is reused. Its parameters,
		 signals, events and enums were collected on the first
		 pass; redoing them would duplicate the declarations. */
	    if (NetScope*prior = scope->child(use_name)) {
		  my_scope = prior;
		  for (unsigned idx = 0 ; idx < list_.size() ; idx += 1)
			list_[idx] -> elaborate_scope(des, my_scope);
		  return;
	    }

	      // The scope type is begin-end or fork-join. The
	      // sub-types of fork-join are not interesting to the scope.
	    my_scope = new NetScope(scope, use_name, bl_type_!=BL_SEQ
				    ? NetScope::FORK_JOIN
				    : NetScope::BEGIN_END);
	    my_scope->set_line(get_file(), get_lineno());
	      // The block itself inherits the enclosing lifetime. An explicit
	      // automatic declaration in a static block must not turn its
	      // inherited siblings automatic; the declaration carries its own
	      // lifetime marker and the backend gives this otherwise-static
	      // block a context solely for those marked locals.
            my_scope->is_auto(scope->is_auto());
	      // Automatic block scopes that run to completion before the
	      // parent resumes — named begin blocks and blocking fork/join
	      // — are collapsed into the enclosing activation frame when
	      // the parent scope is automatic: their locals get context
	      // indices in the frame-owning ancestor scope and no
	      // %alloc/%free is emitted for them (upstream
	      // single-task-frame model). A frame of its own remains for
	      // join_any/join_none forks (detached branches outlive the
	      // statement) and for automatic blocks with a static parent
	      // (no enclosing frame exists).
	      //
	      // Exception (IEEE 1800-2017 9.3.2): a block that declares
	      // its own automatic locals AND lexically contains a detached
	      // fork (join_none/join_any) must keep a per-entry frame.
	      // Collapsing it into the shared task frame would give every
	      // loop iteration the same storage slot, so a detached branch
	      // that captures the local by reference — and reads it after
	      // the iteration completes — would see only the final value
	      // instead of that iteration's copy. Keeping the frame makes
	      // each entry allocate a fresh copy that the spawned branch
	      // retains, matching the module-scope behaviour.
	    bool keeps_frame_for_capture =
		  scope_has_automatic_signal_locals_(wires)
		  && contains_detached_fork();
	    if (my_scope->is_auto() && scope->is_auto()
		&& (bl_type_ == BL_SEQ || bl_type_ == BL_PAR)
		&& !keeps_frame_for_capture)
		  my_scope->auto_frame(false);
	    my_scope->add_imports(&explicit_imports);
	    my_scope->add_typedefs(&typedefs);
	    my_scope->add_nettypes(des, &nettypes);

	      // Scan the parameters in the scope, and store the information
	      // needed to evaluate the parameter expressions.

            collect_scope_parameters(des, my_scope, parameters);

	    collect_scope_signals(my_scope, wires);

              // Scan through all the named events in this scope.
            elaborate_scope_events_(des, my_scope, events);

	    /* Phase 63b: enum types declared inside a begin/end block
	       must be elaborated so their named values are visible
	       inside the block.  Without this, `typedef enum {RED,
	       GREEN} c; c x = GREEN;` failed at use of GREEN with
	       "Unable to bind wire/reg/memory `GREEN'". */
	    elaborate_scope_enumerations(des, my_scope, enum_sets);
      }

      for (unsigned idx = 0 ;  idx < list_.size() ;  idx += 1)
	    list_[idx] -> elaborate_scope(des, my_scope);
}

/*
 * The case statement itself does not introduce scope, but contains
 * other statements that may be named blocks. So scan the case items
 * with the elaborate_scope method.
 */
void PRandCase::elaborate_scope(Design*des, NetScope*scope) const
{
      if (!items_)
	    return;
      for (PCase::Item*cur : *items_) {
	    if (cur && cur->stat)
		  cur->stat->elaborate_scope(des, scope);
      }
}

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

void PCycleDelay::elaborate_scope(Design*des, NetScope*scope) const
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
