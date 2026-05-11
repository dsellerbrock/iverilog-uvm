/*
 * Copyright (c) 1998-2025 Stephen Williams (steve@icarus.com)
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

/*
 * Elaboration takes as input a complete parse tree and the name of a
 * root module, and generates as output the elaborated design. This
 * elaborated design is presented as a Module, which does not
 * reference any other modules. It is entirely self contained.
 */

# include  <algorithm>
# include  <functional>
# include  <typeinfo>
# include  <climits>
# include  <cstdlib>
# include  <cstring>
# include  <ctime>
# include  <iostream>
# include  <sstream>
# include  <list>
# include  "pform.h"
# include  "PClass.h"
# include  "PEvent.h"
# include  "PGenerate.h"
# include  "PPackage.h"
# include  "PScope.h"
# include  "PSpec.h"
# include  "PTimingCheck.h"
# include  "netlist.h"
# include  "netenum.h"
# include  "netvector.h"
# include  "netdarray.h"
# include  "netqueue.h"
# include  "netparray.h"
# include  "netscalar.h"
# include  "netclass.h"
# include  "netmisc.h"
# include  "util.h"
# include  "parse_api.h"
# include  "compiler.h"
# include  "ivl_assert.h"
# include "map_named_args.h"
# include "pform_sva.h"
# include "pform_sva_seq.h"
# include "parse_misc.h"

using namespace std;

static bool elaboration_perf_trace_enabled_()
{
      static bool initialized = false;
      static bool enabled = false;

      if (!initialized) {
	    const char*trace = getenv("IVL_PERF_TRACE");
	    enabled = (trace && *trace);
	    initialized = true;
      }

      return enabled;
}

static void report_elaboration_perf_phase_(const char*phase,
					   size_t done = 0, size_t total = 0)
{
      static time_t start_time = 0;

      if (!elaboration_perf_trace_enabled_())
	    return;

      time_t now = time(0);
      if (start_time == 0)
	    start_time = now;

      unsigned long long elapsed = 0;
      if (now >= start_time)
	    elapsed = now - start_time;

      cerr << "ivl-perf-phase: t=" << elapsed << "s phase=" << phase;
      if (total)
	    cerr << " done=" << done << "/" << total;
      cerr << endl;
}

// Implemented in elab_scope.cc
extern void set_scope_timescale(Design*des, NetScope*scope, const PScope*pscope);
static bool warned_event_control_empty_set = false;
static bool warned_wait_no_event_sources = false;
static bool warned_wait_empty_event_set = false;
static bool warned_indexed_object_method_ignored = false;
static bool warned_class_property_event_expr_ignored = false;

static void elaborate_function_outside_caller_fork_(Design*des,
						    const PFunction*pfunc,
						    NetScope*scope)
{
      unsigned saved_fork_depth = des->fork_depth();
      des->restore_fork_depth(0);
      pfunc->elaborate(des, scope);
      des->restore_fork_depth(saved_fork_depth);
}

static void elaborate_task_outside_caller_fork_(Design*des,
						const PTask*ptask,
						NetScope*scope)
{
      unsigned saved_fork_depth = des->fork_depth();
      des->restore_fork_depth(0);
      ptask->elaborate(des, scope);
      des->restore_fork_depth(saved_fork_depth);
}

static inline bool should_eagerly_elaborate_class_method_(perm_string name)
{
      return name == perm_string::literal("new")
	  || name == perm_string::literal("new@")
	  || name == perm_string::literal("get")
	  || name == perm_string::literal("get_type")
	  || name == perm_string::literal("get_object_type")
	  || name == perm_string::literal("get_type_name")
	  || name == perm_string::literal("type_name")
	  || name == perm_string::literal("initialize")
	  || name == perm_string::literal("m_initialize")
	  // I5 (Phase 62o): virtual override targets for the
	  // uvm_callbacks#(T,CB) lazy-elaborated classes.  Without
	  // these in the eager set, the parameterized specialization's
	  // m_is_registered / m_is_for_me / m_am_i_a are not emitted,
	  // and virtual dispatch falls through to the base class
	  // (which returns 0), causing CBUNREG warnings even after a
	  // valid m_register_pair() call.
	  || name == perm_string::literal("m_is_registered")
	  || name == perm_string::literal("m_is_for_me")
	  || name == perm_string::literal("m_am_i_a");
}

static inline bool should_lazy_specialized_class_body_(const netclass_t*cls)
{
      if (!cls || !cls->specialized_instance())
	    return false;

      const NetScope*class_scope = cls->class_scope();
      const PClass*pclass = class_scope ? class_scope->class_pform() : 0;
      if (!pclass || !pclass->type)
	    return false;

      perm_string class_name = pclass->type->name;
      return class_name == perm_string::literal("uvm_callbacks")
	  || class_name == perm_string::literal("uvm_typed_callbacks");
}

static const netclass_t* resolve_scoped_class_type_name_task_(Design*des,
							      NetScope*scope,
							      perm_string name)
{
      if (!scope)
	    return nullptr;

      if (netclass_t*cls = scope->find_class(des, name))
	    return cls;

      for (NetScope*cur = scope ; cur ; cur = cur->parent()) {
	    ivl_type_t param_type = nullptr;
	    (void) cur->get_parameter(des, name, param_type);
	    if (param_type) {
		  if (const netclass_t*cls = dynamic_cast<const netclass_t*>(param_type))
			return cls;
	    }
      }

      if (NetScope*unit = scope->unit()) {
	    ivl_type_t param_type = nullptr;
	    (void) unit->get_parameter(des, name, param_type);
	    if (param_type) {
		  if (const netclass_t*cls = dynamic_cast<const netclass_t*>(param_type))
			return cls;
	    }
      }

      if (typedef_t*td = scope->find_typedef(des, name)) {
	    ivl_type_t td_type = td->elaborate_type(des, scope);
	    if (const netclass_t*cls = dynamic_cast<const netclass_t*>(td_type))
		  return cls;
      }

      return nullptr;
}

static NetScope* resolve_scoped_class_method_task_(Design*des, NetScope*scope,
						   const pform_name_t&type_path,
						   perm_string method_name,
						   const parmvalue_t*leading_type_args = 0)
{
      if (!gn_system_verilog())
	    return nullptr;
      if (type_path.empty())
	    return nullptr;

      const netclass_t*class_type = nullptr;
      bool first_comp = true;
      for (const auto&comp : type_path) {
	    if (!comp.index.empty())
		  return nullptr;

	    NetScope*comp_scope = scope;
	    if (!first_comp) {
		  if (!class_type || !class_type->class_scope())
			return nullptr;
		  comp_scope = const_cast<NetScope*>(class_type->class_scope());
	    }

	    class_type = resolve_scoped_class_type_name_task_(des, comp_scope, comp.name);
            if ((!class_type || !class_type->class_scope()) && comp_scope)
                  class_type = ensure_visible_class_type(des, comp_scope, comp.name);
	    if (!class_type)
		  return nullptr;
	    if (first_comp && leading_type_args) {
		  NetScope*spec_scope = comp_scope;
		  // Keep the current lexical scope so block-local typedefs used in
		  // type arguments remain visible during specialization.
		  class_type = elaborate_specialized_class_type(des, spec_scope,
						       class_type,
						       leading_type_args,
						       false);
	    }

	    first_comp = false;
      }

      if (!class_type)
	    return nullptr;

      NetScope*method_scope = class_type->method_from_name(method_name);
      if (!method_scope)
	    return nullptr;
      if (method_scope->type() != NetScope::TASK && method_scope->type() != NetScope::FUNC)
	    return nullptr;

      return method_scope;
}

static NetEvent* resolve_named_event_member_from_search_(const symbol_search_results&sr)
{
      if (sr.eve && sr.path_tail.empty())
	    return sr.eve;

      if (!sr.net || sr.path_tail.empty())
	    return nullptr;

      auto find_class_event = [](const netclass_t*cls, perm_string name) -> NetEvent* {
	    for (const netclass_t*cur = cls ; cur ; cur = cur->get_super()) {
		  const NetScope*cls_scope_const = cur->class_scope();
		  NetScope*cls_scope = const_cast<NetScope*>(cls_scope_const);
		  if (!cls_scope)
			continue;
		  if (NetEvent*eve = cls_scope->find_event(name))
			return eve;
	    }
	    return nullptr;
      };

      const netclass_t*cls = dynamic_cast<const netclass_t*>(sr.type);
      if (!cls)
	    return nullptr;

      pform_name_t::const_iterator comp_it = sr.path_tail.begin();
      while (comp_it != sr.path_tail.end()) {
	    const name_component_t&comp = *comp_it;
	    pform_name_t::const_iterator next_it = comp_it;
	    ++next_it;
	    bool is_last = (next_it == sr.path_tail.end());

	    if (is_last) {
		  if (!comp.index.empty())
			return nullptr;
		  return find_class_event(cls, comp.name);
	    }

	    int pidx = cls->property_idx_from_name(comp.name);
	    if (pidx < 0)
		  return nullptr;

	    ivl_type_t ptype = cls->get_prop_type(pidx);
	    if (!comp.index.empty()) {
		  if (comp.index.size() != 1)
			return nullptr;
		  if (const netdarray_t*darr = dynamic_cast<const netdarray_t*>(ptype)) {
			ptype = darr->element_type();
		  } else if (const netuarray_t*uarr = dynamic_cast<const netuarray_t*>(ptype)) {
			ptype = uarr->element_type();
		  } else if (const netarray_t*arr = dynamic_cast<const netarray_t*>(ptype)) {
			ptype = arr->element_type();
		  } else {
			return nullptr;
		  }
	    }

	    cls = dynamic_cast<const netclass_t*>(ptype);
	    if (!cls)
		  return nullptr;
	    comp_it = next_it;
      }

      return nullptr;
}

/* Resolve `<iface_instance_scope>` (no NetNet, but path consumed) to the
   clocking block named by the LAST component of the original path. This
   handles the @(bif.cb) case where symbol_search resolves `bif` as a
   sub-scope of the current module and absorbs `cb` as part of the scope
   path. */
static const PEventStatement*
resolve_interface_pform_clocking_event_(const PEIdent*id,
					const symbol_search_results&sr,
					perm_string&cb_name_out,
					size_t&base_path_components)
{
      if (sr.net || !sr.scope) return nullptr;
      if (!sr.scope->is_interface()) return nullptr;
      if (id->path().size() < 2) return nullptr;

      perm_string iface_module = sr.scope->module_name();
      if (iface_module.nil()) return nullptr;
      auto cur = pform_modules.find(iface_module);
      if (cur == pform_modules.end() || !cur->second->is_interface)
	    return nullptr;
      perm_string cb_name = id->path().name.back().name;
      auto cb_it = cur->second->clocking_blocks.find(cb_name);
      if (cb_it == cur->second->clocking_blocks.end()) return nullptr;
      base_path_components = id->path().size() - 1;
      cb_name_out = cb_name;
      return cb_it->second->event;
}

static const netclass_t::clocking_block_t* resolve_interface_clocking_block_from_search_(
					      const symbol_search_results&sr,
					      size_t&base_path_components)
{
      if (!sr.net || sr.path_tail.empty())
	    return nullptr;

      const netclass_t*class_type = dynamic_cast<const netclass_t*>(sr.type);
      if (!class_type)
	    return nullptr;

      size_t offset = 0;
      for (pform_name_t::const_iterator it = sr.path_tail.begin()
		 ; it != sr.path_tail.end() ; ++it, ++offset) {
	    pform_name_t::const_iterator next = it;
	    ++next;

	    if (class_type->is_interface()) {
		  if (next == sr.path_tail.end() && it->index.empty()) {
			if (const netclass_t::clocking_block_t*clocking =
				    class_type->find_clocking_block(it->name)) {
                              base_path_components = offset;
                              return clocking;
			}
		  }
	    }

	    int pidx = class_type->property_idx_from_name(it->name);
	    if (pidx < 0)
		  return nullptr;

	    ivl_type_t ptype = class_type->get_prop_type(pidx);
	    if (!it->index.empty()) {
		  if (const netdarray_t*darr = dynamic_cast<const netdarray_t*>(ptype))
			ptype = darr->element_type();
		  else if (const netuarray_t*uarr = dynamic_cast<const netuarray_t*>(ptype))
			ptype = uarr->element_type();
		  else if (const netarray_t*arr = dynamic_cast<const netarray_t*>(ptype))
			ptype = arr->element_type();
		  else if (const netqueue_t*que = dynamic_cast<const netqueue_t*>(ptype))
			ptype = que->element_type();
		  else
			return nullptr;
	    }

	    class_type = dynamic_cast<const netclass_t*>(ptype);
	    if (!class_type)
		  return nullptr;
      }

      return nullptr;
}

static bool build_interface_clocking_event_path_(const PEIdent*root_id,
						 size_t base_path_components,
						 const PEIdent*event_id,
						 pform_name_t&mapped_path)
{
      if (event_id->path().package)
	    return false;

      mapped_path.clear();
      size_t count = 0;
      for (pform_name_t::const_iterator it = root_id->path().name.begin()
		 ; it != root_id->path().name.end() && count < base_path_components
		 ; ++it, ++count)
	    mapped_path.push_back(*it);
      if (count != base_path_components)
	    return false;

      mapped_path.insert(mapped_path.end(),
			 event_id->path().name.begin(),
			 event_id->path().name.end());
      return true;
}

static bool assoc_compat_selected_component_method_allowed_(perm_string method_name)
{
	      return method_name == perm_string::literal("do_flush")
		  || method_name == perm_string::literal("do_resolve_bindings")
		  || method_name == perm_string::literal("set_domain")
		  || method_name == perm_string::literal("set_phase_imp")
		  || method_name == perm_string::literal("set_report_id_verbosity_hier")
		  || method_name == perm_string::literal("set_report_severity_id_verbosity_hier")
	  || method_name == perm_string::literal("set_report_severity_action_hier")
	  || method_name == perm_string::literal("set_report_id_action_hier")
	  || method_name == perm_string::literal("set_report_severity_id_action_hier")
	  || method_name == perm_string::literal("set_report_severity_file_hier")
	  || method_name == perm_string::literal("set_report_default_file_hier")
	  || method_name == perm_string::literal("set_report_id_file_hier")
	  || method_name == perm_string::literal("set_report_severity_id_file_hier")
	  || method_name == perm_string::literal("set_report_verbosity_level_hier")
		  || method_name == perm_string::literal("set_recording_enabled_hier")
		  || method_name == perm_string::literal("m_do_pre_abort");
}

static bool assoc_compat_selected_reg_block_method_allowed_(perm_string method_name)
{
	      return method_name == perm_string::literal("lock_model")
		  || method_name == perm_string::literal("unlock_model")
		  || method_name == perm_string::literal("set_lock")
		  || method_name == perm_string::literal("get_blocks")
		  || method_name == perm_string::literal("get_registers")
		  || method_name == perm_string::literal("get_fields")
		  || method_name == perm_string::literal("get_memories")
		  || method_name == perm_string::literal("get_virtual_registers")
		  || method_name == perm_string::literal("get_virtual_fields")
		  || method_name == perm_string::literal("set_coverage")
		  || method_name == perm_string::literal("sample_values")
		  || method_name == perm_string::literal("reset")
		  || method_name == perm_string::literal("update")
		  || method_name == perm_string::literal("mirror");
}

static bool assoc_compat_selected_reg_method_allowed_(perm_string method_name)
{
	      return method_name == perm_string::literal("Xlock_modelX")
		  || method_name == perm_string::literal("Xunlock_modelX")
		  || method_name == perm_string::literal("get_maps")
		  || method_name == perm_string::literal("get_fields")
		  || method_name == perm_string::literal("set_coverage")
		  || method_name == perm_string::literal("sample_values")
		  || method_name == perm_string::literal("reset")
		  || method_name == perm_string::literal("update")
		  || method_name == perm_string::literal("mirror");
}

static bool assoc_compat_selected_mem_method_allowed_(perm_string method_name)
{
	      return method_name == perm_string::literal("Xlock_modelX")
		  || method_name == perm_string::literal("get_maps")
		  || method_name == perm_string::literal("get_virtual_registers")
		  || method_name == perm_string::literal("set_coverage");
}

static bool assoc_compat_selected_vreg_method_allowed_(perm_string method_name)
{
	      return method_name == perm_string::literal("Xlock_modelX")
		  || method_name == perm_string::literal("get_maps")
		  || method_name == perm_string::literal("get_fields");
}

static bool assoc_compat_selected_collection_method_allowed_(ivl_type_t type,
							     perm_string method_name)
{
	      const netdarray_t*darray = dynamic_cast<const netdarray_t*>(type);
	      if (!darray)
		    return false;

	      if (method_name == perm_string::literal("delete")
		  || method_name == perm_string::literal("size")
		  || method_name == perm_string::literal("reverse")
		  || method_name == perm_string::literal("sort")
		  || method_name == perm_string::literal("rsort")
		  || method_name == perm_string::literal("shuffle"))
		    return true;

	      if (!dynamic_cast<const netqueue_t*>(type))
		    return false;

	      return method_name == perm_string::literal("push_back")
		  || method_name == perm_string::literal("push_front")
		  || method_name == perm_string::literal("insert")
		  || method_name == perm_string::literal("pop_front")
		  || method_name == perm_string::literal("pop_back");
}

static bool assoc_compat_supports_indexed_method_target_(ivl_type_t type,
							 perm_string method_name)
{
      const netqueue_t*queue = dynamic_cast<const netqueue_t*>(type);
      if (!queue || !queue->assoc_compat())
	    return true;

      const netclass_t*elem_cls =
	    dynamic_cast<const netclass_t*>(queue->element_type());

      if (assoc_compat_selected_collection_method_allowed_(queue->element_type(),
							   method_name))
	    return true;

      // Any user-defined class element type: allow the call attempt.
      // The method lookup will fail gracefully if the method doesn't exist.
      if (elem_cls)
	    return true;

      for (const netclass_t*cur = elem_cls ; cur ; cur = cur->get_super()) {
	    if (cur->get_name() == perm_string::literal("uvm_queue"))
		  return true;
	    if (assoc_compat_selected_component_method_allowed_(method_name)
		&& cur->get_name() == perm_string::literal("uvm_component"))
		  return true;
	    if (assoc_compat_selected_reg_block_method_allowed_(method_name)
		&& cur->get_name() == perm_string::literal("uvm_reg_block"))
		  return true;
	    if (assoc_compat_selected_reg_method_allowed_(method_name)
		&& cur->get_name() == perm_string::literal("uvm_reg"))
		  return true;
	    if (assoc_compat_selected_mem_method_allowed_(method_name)
		&& cur->get_name() == perm_string::literal("uvm_mem"))
		  return true;
	    if (assoc_compat_selected_vreg_method_allowed_(method_name)
		&& cur->get_name() == perm_string::literal("uvm_vreg"))
		  return true;
      }

      return false;
}

static NetExpr* elaborate_root_indexed_method_target_expr_(const LineInfo*li,
							   Design*des,
							   NetScope*scope,
							   NetExpr*base_expr,
							   ivl_type_t base_type,
							   const list<index_component_t>&base_index,
							   perm_string method_name,
							   ivl_type_t&out_type)
{
      if (!base_expr)
	    return nullptr;

      out_type = base_type;
      if (base_index.empty())
	    return base_expr;

      const netdarray_t*darray = dynamic_cast<const netdarray_t*>(base_type);
      if (!darray)
	    return base_expr;
      if (!assoc_compat_supports_indexed_method_target_(base_type, method_name)) {
	    delete base_expr;
	    return nullptr;
      }

      if (base_index.size() != 1) {
	    cerr << li->get_fileline() << ": sorry: "
		 << "Only single-dimension index of dynamic/queue method targets is supported."
		 << endl;
	    des->errors += 1;
	    delete base_expr;
	    return nullptr;
      }

      const index_component_t&root_index = base_index.back();
      if (root_index.sel == index_component_t::SEL_BIT_LAST) {
	    cerr << li->get_fileline() << ": sorry: "
		 << "Last element select of dynamic/queue method targets is not supported."
		 << endl;
	    des->errors += 1;
	    delete base_expr;
	    return nullptr;
      }
      if (root_index.msb == 0 || root_index.lsb != 0
	  || root_index.sel != index_component_t::SEL_BIT) {
	    cerr << li->get_fileline() << ": sorry: "
		 << "Only simple index selects of dynamic/queue method targets are supported."
		 << endl;
	    des->errors += 1;
	    delete base_expr;
	    return nullptr;
      }

      NetExpr*mux = elab_and_eval(des, scope, root_index.msb, -1, false);
      if (!mux) {
	    delete base_expr;
	    return nullptr;
      }

      NetESelect*tmp = new NetESelect(base_expr, mux,
				      darray->element_width(),
				      darray->element_type());
      tmp->set_line(*li);
      out_type = darray->element_type();
      return tmp;
}

static NetExpr* elaborate_nested_method_target_property_task_(const LineInfo*li,
							      Design*des,
							      NetScope*scope,
							      NetExpr*base_expr,
							      const netclass_t*class_type,
							      const name_component_t&comp,
							      perm_string method_name,
							      ivl_type_t&out_type)
{
      if (!class_type || !base_expr)
	    return nullptr;

      int pidx = class_type->property_idx_from_name(comp.name);
      if (pidx < 0) {
	    delete base_expr;
	    return nullptr;
      }

      property_qualifier_t qual = class_type->get_prop_qual(pidx);
      if (qual.test_local() && !class_type->test_scope_is_method(scope)) {
	    cerr << li->get_fileline() << ": error: "
		 << "Local property " << class_type->get_prop_name(pidx)
		 << " is not accessible in this context."
		 << " (scope=" << scope_path(scope) << ")" << endl;
	    des->errors += 1;
	    delete base_expr;
	    return nullptr;
      }

      if (qual.test_static()) {
	    if (!comp.index.empty()) {
		  cerr << li->get_fileline() << ": sorry: "
		       << "Indexed static method targets are not supported yet." << endl;
		  des->errors += 1;
		  delete base_expr;
		  return nullptr;
	    }

	    NetNet*psig = class_type->find_static_property(comp.name);
	    if (!psig) {
		  cerr << li->get_fileline() << ": error: Failed to resolve static property "
		       << comp.name << " in class " << class_type->get_name() << "." << endl;
		  des->errors += 1;
		  delete base_expr;
		  return nullptr;
	    }

	    delete base_expr;
	    NetESignal*expr = new NetESignal(psig);
	    expr->set_line(*li);
	    out_type = psig->net_type();
	    return expr;
      }

      ivl_type_t prop_type = class_type->get_prop_type(pidx);

      if (comp.index.empty()) {
	    NetEProperty*prop_expr = new NetEProperty(base_expr, pidx, nullptr);
	    prop_expr->set_line(*li);
	    out_type = prop_type;
	    return prop_expr;
      }
      if (!assoc_compat_supports_indexed_method_target_(prop_type, method_name)) {
	    delete base_expr;
	    return nullptr;
      }

      if (const netuarray_t*tmp_ua = dynamic_cast<const netuarray_t*>(prop_type)) {
	    const auto&dims = tmp_ua->static_dimensions();
	    if (dims.size() != comp.index.size()) {
		  cerr << li->get_fileline() << ": error: "
		       << "Got " << comp.index.size() << " indices, expecting "
		       << dims.size() << " to index the property "
		       << class_type->get_prop_name(pidx) << "." << endl;
		  des->errors += 1;
		  delete base_expr;
		  return nullptr;
	    }
	    NetExpr*canon_index = make_canonical_index(des, scope, li,
						       comp.index, tmp_ua, false);
	    if (!canon_index) {
		  delete base_expr;
		  return nullptr;
	    }
	    NetEProperty*indexed_expr = new NetEProperty(base_expr, pidx, canon_index);
	    indexed_expr->set_line(*li);
	    out_type = tmp_ua->element_type();
	    return indexed_expr;
      }

      NetEProperty*prop_expr = new NetEProperty(base_expr, pidx, nullptr);
      prop_expr->set_line(*li);

      if (comp.index.size() != 1) {
	    cerr << li->get_fileline() << ": sorry: "
		 << "Only single-dimension indexed method targets are supported."
		 << endl;
	    des->errors += 1;
	    delete prop_expr;
	    return nullptr;
      }

      const index_component_t&idx_comp = comp.index.front();
      if (idx_comp.sel == index_component_t::SEL_BIT_LAST) {
	    cerr << li->get_fileline() << ": sorry: "
		 << "Last element select of indexed method targets is not supported."
		 << endl;
	    des->errors += 1;
	    delete prop_expr;
	    return nullptr;
      }
      if (idx_comp.msb == 0 || idx_comp.lsb != 0
	  || idx_comp.sel != index_component_t::SEL_BIT) {
	    cerr << li->get_fileline() << ": sorry: "
		 << "Only simple index selects of indexed method targets are supported."
		 << endl;
	    des->errors += 1;
	    delete prop_expr;
	    return nullptr;
      }

      NetExpr*idx_expr = elab_and_eval(des, scope, idx_comp.msb, -1, false);
      if (!idx_expr) {
	    delete prop_expr;
	    return nullptr;
      }

      ivl_type_t elem_type = nullptr;
      unsigned elem_width = 1;
      if (const netarray_t*arr = dynamic_cast<const netarray_t*>(prop_type)) {
	    elem_type = arr->element_type();
	    if (elem_type)
		  elem_width = elem_type->packed_width();
      } else if (const netdarray_t*darr = dynamic_cast<const netdarray_t*>(prop_type)) {
	    elem_type = darr->element_type();
	    elem_width = darr->element_width();
      } else {
	    delete idx_expr;
	    out_type = prop_type;
	    return prop_expr;
      }

      if (elem_width == 0)
	    elem_width = 1;

      NetESelect*sel = elem_type
	    ? new NetESelect(prop_expr, idx_expr, elem_width, elem_type)
	    : new NetESelect(prop_expr, idx_expr, elem_width);
      sel->set_line(*li);
      out_type = elem_type;
      return sel;
}

static bool is_uvm_compile_progress_task_stub_candidate_(const pform_name_t&path);

static NetExpr* elaborate_return_enum_literal_fallback_(Design*,
							NetScope*,
							ivl_type_t ret_type,
							PExpr*expr)
{
      if (!gn_system_verilog())
	    return nullptr;

      const netenum_t*ret_enum = dynamic_cast<const netenum_t*>(ret_type);
      if (!ret_enum)
	    return nullptr;

      const PEIdent*id = dynamic_cast<const PEIdent*>(expr);
      if (!id)
	    return nullptr;

      const pform_scoped_name_t&path = id->path();
      if (path.package || path.name.size() != 1)
	    return nullptr;
      const name_component_t&comp = path.name.front();
      if (!comp.index.empty())
	    return nullptr;

      netenum_t::iterator item = ret_enum->find_name(comp.name);
      if (item == ret_enum->end_name())
	    return nullptr;

      NetEConstEnum*tmp = new NetEConstEnum(item->first, ret_enum, item->second);
      tmp->set_line(*expr);
      return tmp;
}

void PGate::elaborate(Design*, NetScope*) const
{
      cerr << "internal error: what kind of gate? " <<
	    typeid(*this).name() << endl;
}

unsigned PGate::calculate_array_size_(Design*des, NetScope*scope,
				      long&high, long&low) const
{
      if (ranges_ && ranges_->size() > 1) {
	    if (gn_system_verilog()) {
		  cerr << get_fileline() << ": sorry: Multi-dimensional"
		       << " arrays of instances are not yet supported." << endl;
	    } else {
		  cerr << get_fileline() << ": error: Multi-dimensional"
		       << " arrays of instances require SystemVerilog." << endl;
	    }
	    des->errors += 1;
	    return 0;
      }

      unsigned size = 1;
      high = 0;
      low = 0;

      if (ranges_) {
	    if (!evaluate_range(des, scope, this, ranges_->front(), high, low))
		return 0;

	    if (high > low)
		  size = high - low + 1;
	    else
		  size = low - high + 1;

	    if (debug_elaborate) {
		  cerr << get_fileline() << ": debug: PGate: Make array "
		       << "[" << high << ":" << low << "]" << " of "
		       << size << " instances for " << get_name() << endl;
	    }
      }

      return size;
}

/*
 * Elaborate the continuous assign. (This is *not* the procedural
 * assign.) Elaborate the lvalue and rvalue, and do the assignment.
 */
void PGAssign::elaborate(Design*des, NetScope*scope) const
{
      ivl_assert(*this, scope);

      NetExpr* rise_time, *fall_time, *decay_time;
      eval_delays(des, scope, rise_time, fall_time, decay_time, true);

      ivl_drive_t drive0 = strength0();
      ivl_drive_t drive1 = strength1();

      ivl_assert(*this, pin(0));
      ivl_assert(*this, pin(1));

	/* Elaborate the l-value. */
        // A continuous assignment can drive a variable if the default strength is used.
      bool var_allowed_in_sv = (drive0 == IVL_DR_STRONG &&
                                drive1 == IVL_DR_STRONG) ? true : false;
      NetNet*lval = pin(0)->elaborate_lnet(des, scope, var_allowed_in_sv);
      if (lval == 0) {
	    return;
      }

	// If this turns out to be an assignment to an unpacked array,
	// then handle that special case elsewhere.
      if (lval->pin_count() > 1) {
	    elaborate_unpacked_array_(des, scope, lval);
	    return;
      }

      ivl_assert(*this, lval->pin_count() == 1);

      if (debug_elaborate) {
	    cerr << get_fileline() << ": PGAssign::elaborate: elaborated l-value"
		 << " width=" << lval->vector_width()
		 << ", pin_count=" << lval->pin_count() << endl;
      }

      NetExpr*rval_expr = elaborate_rval_expr(des, scope, lval->net_type(), pin(1));

      if (rval_expr == 0) {
	    cerr << get_fileline() << ": error: Unable to elaborate r-value: "
		 << *pin(1) << endl;
	    des->errors += 1;
	    return;
      }

      NetNet*rval = rval_expr->synthesize(des, scope, rval_expr);

      if (rval == 0) {
	    cerr << get_fileline() << ": internal error: "
		 << "Failed to synthesize expression: " << *rval_expr << endl;
	    des->errors += 1;
	    return;
      }

      if (debug_elaborate) {
	    cerr << get_fileline() << ": debug: PGAssign: elaborated r-value"
		 << " width="<< rval->vector_width()
		 << ", type="<< rval->data_type()
		 << ", expr=" << *rval_expr << endl;
      }

      ivl_assert(*this, lval && rval);
      ivl_assert(*this, rval->pin_count() == 1);

	// Detect the case that the rvalue-expression is a simple
	// expression. In this case, we will need to create a driver
	// (later) to carry strengths.
      bool need_driver_flag = false;
      if (dynamic_cast<NetESignal*>(rval_expr) ||!rval->is_linked())
	    need_driver_flag = true;

	// expression elaboration should have caused the rval width to
	// match the l-value by now.
      if (rval->vector_width() < lval->vector_width()) {
	    cerr << get_fileline() << ": internal error: "
		 << "lval-rval width mismatch: "
		 << "rval->vector_width()==" << rval->vector_width()
		 << ", lval->vector_width()==" << lval->vector_width() << endl;
      }
      ivl_assert(*this, rval->vector_width() >= lval->vector_width());

	/* If the r-value insists on being larger than the l-value,
	   use a part select to chop it down down to size. */
      if (lval->vector_width() < rval->vector_width()) {
	    NetPartSelect*tmp = new NetPartSelect(rval, 0,lval->vector_width(),
						  NetPartSelect::VP);
	    des->add_node(tmp);
	    tmp->set_line(*this);
	    const netvector_t*osig_vec = new netvector_t(rval->data_type(),
	                                                 lval->vector_width()-1,0);
	    NetNet*osig = new NetNet(scope, scope->local_symbol(),
				     NetNet::TRI, osig_vec);
	    osig->set_line(*this);
	    osig->local_flag(true);
	    connect(osig->pin(0), tmp->pin(0));
	    rval = osig;
	    need_driver_flag = false;
      }

	/* When we are given a non-default strength value and if the drive
	 * source is a bit, part, indexed select or a concatenation we need
	 * to add a driver (BUFZ) to convey the strength information. */
      if ((drive0 != IVL_DR_STRONG || drive1 != IVL_DR_STRONG) &&
          ((dynamic_cast<NetESelect*>(rval_expr)) ||
	   (dynamic_cast<NetEConcat*>(rval_expr)))) {
	    need_driver_flag = true;
      }

      if (need_driver_flag) {
	    NetBUFZ*driver = new NetBUFZ(scope, scope->local_symbol(),
					 rval->vector_width(), false);
	    driver->set_line(*this);
	    des->add_node(driver);

	    connect(rval->pin(0), driver->pin(1));

	    const netvector_t*tmp_vec = new netvector_t(rval->data_type(),
	                                                rval->vector_width()-1,0);
	    NetNet*tmp = new NetNet(scope, scope->local_symbol(),
				    NetNet::WIRE, tmp_vec);
	    tmp->set_line(*this);
	    tmp->local_flag(true);

	    connect(driver->pin(0), tmp->pin(0));

	    rval = tmp;
      }

	/* Set the drive and delays for the r-val. */

      if (drive0 != IVL_DR_STRONG || drive1 != IVL_DR_STRONG)
	    rval->pin(0).drivers_drive(drive0, drive1);

      if (rise_time || fall_time || decay_time)
	    rval->pin(0).drivers_delays(rise_time, fall_time, decay_time);

      connect(lval->pin(0), rval->pin(0));

      if (lval->local_flag())
	    delete lval;

}

NetNet *elaborate_unpacked_array(Design *des, NetScope *scope, const LineInfo &loc,
			         const NetNet *lval, PExpr *expr)
{
      NetNet *expr_net;
      const PEIdent* ident = dynamic_cast<PEIdent*> (expr);
      if (!ident) {
	    if (dynamic_cast<PEConcat*> (expr)) {
		  cout << loc.get_fileline() << ": sorry: Continuous assignment"
		       << " of array concatenation is not yet supported."
		       << endl;
		  des->errors++;
		  return nullptr;
	    } else if (dynamic_cast<PEAssignPattern*> (expr)) {
		  auto net_expr = elaborate_rval_expr(des, scope, lval->array_type(), expr);
		  if (! net_expr) return nullptr;
		  expr_net = net_expr->synthesize(des, scope, net_expr);
	    } else {
		  cout << loc.get_fileline() << ": error: Can not assign"
		       << " non-array expression `" << *expr << "` to array."
		       << endl;
		  des->errors++;
		  return nullptr;
	    }
      } else {
	    expr_net = ident->elaborate_unpacked_net(des, scope);
      }

      if (!expr_net)
	    return nullptr;

      auto const &lval_dims = lval->unpacked_dims();
      auto const &expr_dims = expr_net->unpacked_dims();

      if (expr_dims.empty()) {
	    cerr << loc.get_fileline() << ": error: Can not assign"
	         << " non-array identifier `" << *expr << "` to array."
		 << endl;
	    des->errors++;
	    return nullptr;
      }

      if (!netrange_equivalent(lval_dims, expr_dims)) {
	    cerr << loc.get_fileline() << ": error: Unpacked dimensions"
		 << " are not compatible in array assignment." << endl;
	    des->errors++;
	    return nullptr;
      }

      if (!lval->net_type()->type_equivalent(expr_net->net_type())) {
	    cerr << loc.get_fileline() << ": error: Element types are not"
	         << " compatible in array assignment." << endl;
	    des->errors++;
	    return nullptr;
      }

      return expr_net;
}

void PGAssign::elaborate_unpacked_array_(Design*des, NetScope*scope, NetNet*lval) const
{
      NetNet *rval_net = elaborate_unpacked_array(des, scope, *this, lval, pin(1));
      if (rval_net)
	    assign_unpacked_with_bufz(des, scope, lval, lval, rval_net);
}

void PGBuiltin::calculate_gate_and_lval_count_(unsigned&gate_count,
                                               unsigned&lval_count) const
{
      switch (type()) {
	  case BUF:
	  case NOT:
	    if (pin_count() > 2) gate_count = pin_count() - 1;
	    else gate_count = 1;
            lval_count = gate_count;
	    break;
	  case PULLDOWN:
	  case PULLUP:
	    gate_count = pin_count();
            lval_count = gate_count;
	    break;
	  case TRAN:
	  case RTRAN:
	  case TRANIF0:
	  case TRANIF1:
	  case RTRANIF0:
	  case RTRANIF1:
	    gate_count = 1;
            lval_count = 2;
	    break;
	  default:
	    gate_count = 1;
            lval_count = 1;
	    break;
      }
}

NetNode* PGBuiltin::create_gate_for_output_(Design*des, NetScope*scope,
					    perm_string inst_name,
					    unsigned instance_width) const
{
      NetNode*gate = 0;

      switch (type()) {

	  case AND:
	    if (pin_count() < 2) {
		  cerr << get_fileline() << ": error: the AND "
			"primitive must have an input." << endl;
		  des->errors += 1;
	    } else {
		  gate = new NetLogic(scope, inst_name, pin_count(),
				      NetLogic::AND, instance_width);
	    }
	    break;

	  case BUF:
	    if (pin_count() < 2) {
		  cerr << get_fileline() << ": error: the BUF "
			"primitive must have an input." << endl;
		  des->errors += 1;
	    } else {
		  gate = new NetLogic(scope, inst_name, 2,
		                      NetLogic::BUF, instance_width);
	    }
	    break;

	  case BUFIF0:
	    if (pin_count() != 3) {
		  cerr << get_fileline() << ": error: the BUFIF0 "
			"primitive must have three arguments." << endl;
		  des->errors += 1;
	    } else {
		  gate = new NetLogic(scope, inst_name, pin_count(),
					  NetLogic::BUFIF0, instance_width);
	    }
	    break;

	  case BUFIF1:
	    if (pin_count() != 3) {
		  cerr << get_fileline() << ": error: the BUFIF1 "
			"primitive must have three arguments." << endl;
		  des->errors += 1;
	    } else {
		  gate = new NetLogic(scope, inst_name, pin_count(),
					  NetLogic::BUFIF1, instance_width);
	    }
	    break;

	  case CMOS:
	    if (pin_count() != 4) {
		  cerr << get_fileline() << ": error: the CMOS "
			"primitive must have four arguments." << endl;
		  des->errors += 1;
	    } else {
		  gate = new NetLogic(scope, inst_name, pin_count(),
				      NetLogic::CMOS, instance_width);
	    }
	    break;

	  case NAND:
	    if (pin_count() < 2) {
		  cerr << get_fileline() << ": error: the NAND "
			"primitive must have an input." << endl;
		  des->errors += 1;
	    } else {
		  gate = new NetLogic(scope, inst_name, pin_count(),
				      NetLogic::NAND, instance_width);
	    }
	    break;

	  case NMOS:
	    if (pin_count() != 3) {
		  cerr << get_fileline() << ": error: the NMOS "
			"primitive must have three arguments." << endl;
		  des->errors += 1;
	    } else {
		  gate = new NetLogic(scope, inst_name, pin_count(),
				      NetLogic::NMOS, instance_width);
	    }
	    break;

	  case NOR:
	    if (pin_count() < 2) {
		  cerr << get_fileline() << ": error: the NOR "
			"primitive must have an input." << endl;
		  des->errors += 1;
	    } else {
		  gate = new NetLogic(scope, inst_name, pin_count(),
				      NetLogic::NOR, instance_width);
	    }
	    break;

	  case NOT:
	    if (pin_count() < 2) {
		  cerr << get_fileline() << ": error: the NOT "
			"primitive must have an input." << endl;
		  des->errors += 1;
	    } else {
		  gate = new NetLogic(scope, inst_name, 2,
		                      NetLogic::NOT, instance_width);
	    }
	    break;

	  case NOTIF0:
	    if (pin_count() != 3) {
		  cerr << get_fileline() << ": error: the NOTIF0 "
			"primitive must have three arguments." << endl;
		  des->errors += 1;
	    } else {
		  gate = new NetLogic(scope, inst_name, pin_count(),
				      NetLogic::NOTIF0, instance_width);
	    }
	    break;

	  case NOTIF1:
	    if (pin_count() != 3) {
		  cerr << get_fileline() << ": error: the NOTIF1 "
			"primitive must have three arguments." << endl;
		  des->errors += 1;
	    } else {
		  gate = new NetLogic(scope, inst_name, pin_count(),
				      NetLogic::NOTIF1, instance_width);
	    }
	    break;

	  case OR:
	    if (pin_count() < 2) {
		  cerr << get_fileline() << ": error: the OR "
			"primitive must have an input." << endl;
		  des->errors += 1;
	    } else {
		  gate = new NetLogic(scope, inst_name, pin_count(),
				      NetLogic::OR, instance_width);
	    }
	    break;

	  case RCMOS:
	    if (pin_count() != 4) {
		  cerr << get_fileline() << ": error: the RCMOS "
			"primitive must have four arguments." << endl;
		  des->errors += 1;
	    } else {
		  gate = new NetLogic(scope, inst_name, pin_count(),
				      NetLogic::RCMOS, instance_width);
	    }
	    break;

	  case RNMOS:
	    if (pin_count() != 3) {
		  cerr << get_fileline() << ": error: the RNMOS "
			"primitive must have three arguments." << endl;
		  des->errors += 1;
	    } else {
		  gate = new NetLogic(scope, inst_name, pin_count(),
				      NetLogic::RNMOS, instance_width);
	    }
	    break;

	  case RPMOS:
	    if (pin_count() != 3) {
		  cerr << get_fileline() << ": error: the RPMOS "
			"primitive must have three arguments." << endl;
		  des->errors += 1;
	    } else {
		  gate = new NetLogic(scope, inst_name, pin_count(),
				      NetLogic::RPMOS, instance_width);
	    }
	    break;

	  case PMOS:
	    if (pin_count() != 3) {
		  cerr << get_fileline() << ": error: the PMOS "
			"primitive must have three arguments." << endl;
		  des->errors += 1;
	    } else {
		  gate = new NetLogic(scope, inst_name, pin_count(),
				      NetLogic::PMOS, instance_width);
	    }
	    break;

	  case PULLDOWN:
	    gate = new NetLogic(scope, inst_name, 1,
				NetLogic::PULLDOWN, instance_width);
	    break;

	  case PULLUP:
	    gate = new NetLogic(scope, inst_name, 1,
				NetLogic::PULLUP, instance_width);
	    break;

	  case XNOR:
	    if (pin_count() < 2) {
		  cerr << get_fileline() << ": error: the XNOR "
			"primitive must have an input." << endl;
		  des->errors += 1;
	    } else {
		  gate = new NetLogic(scope, inst_name, pin_count(),
				      NetLogic::XNOR, instance_width);
	    }
	    break;

	  case XOR:
	    if (pin_count() < 2) {
		  cerr << get_fileline() << ": error: the XOR "
			"primitive must have an input." << endl;
		  des->errors += 1;
	    } else {
		  gate = new NetLogic(scope, inst_name, pin_count(),
				      NetLogic::XOR, instance_width);
	    }
	    break;

	  case TRAN:
	    if (pin_count() != 2) {
		  cerr << get_fileline() << ": error: Pin count for "
		       << "tran device." << endl;
		  des->errors += 1;
	    } else {
		  gate = new NetTran(scope, inst_name, IVL_SW_TRAN,
		                     instance_width);
	    }
	    break;

	  case RTRAN:
	    if (pin_count() != 2) {
		  cerr << get_fileline() << ": error: Pin count for "
		       << "rtran device." << endl;
		  des->errors += 1;
	    } else {
		  gate = new NetTran(scope, inst_name, IVL_SW_RTRAN,
		                     instance_width);
	    }
	    break;

	  case TRANIF0:
	    if (pin_count() != 3) {
		  cerr << get_fileline() << ": error: Pin count for "
		       << "tranif0 device." << endl;
		  des->errors += 1;
	    } else {
		  gate = new NetTran(scope, inst_name, IVL_SW_TRANIF0,
		                     instance_width);
	    }
	    break;

	  case RTRANIF0:
	    if (pin_count() != 3) {
		  cerr << get_fileline() << ": error: Pin count for "
		       << "rtranif0 device." << endl;
		  des->errors += 1;
	    } else {
		  gate = new NetTran(scope, inst_name, IVL_SW_RTRANIF0,
		                     instance_width);
	    }
	    break;

	  case TRANIF1:
	    if (pin_count() != 3) {
		  cerr << get_fileline() << ": error: Pin count for "
		       << "tranif1 device." << endl;
		  des->errors += 1;
	    } else {
		  gate = new NetTran(scope, inst_name, IVL_SW_TRANIF1,
		                     instance_width);
	    }
	    break;

	  case RTRANIF1:
	    if (pin_count() != 3) {
		  cerr << get_fileline() << ": error: Pin count for "
		       << "rtranif1 device." << endl;
		  des->errors += 1;
	    } else {
		  gate = new NetTran(scope, inst_name, IVL_SW_RTRANIF1,
		                     instance_width);
	    }
	    break;

	  default:
	    cerr << get_fileline() << ": internal error: unhandled "
		  "gate type." << endl;
	    des->errors += 1;
	    break;
      }

      return gate;
}

bool PGBuiltin::check_delay_count(Design*des) const
{
      switch (type()) {
	  case AND:
	  case NAND:
	  case OR:
	  case NOR:
	  case XOR:
	  case XNOR:
	  case BUF:
	  case NOT:
	    if (delay_count() > 2) {
		  cerr << get_fileline() << ": error: More than two delays "
		       << "given to a " << gate_name() << " gate." << endl;
		  des->errors += 1;
		  return true;
	    }
	    break;

	  case BUFIF0:
	  case NOTIF0:
	  case BUFIF1:
	  case NOTIF1:
	    if (delay_count() > 3) {
		  cerr << get_fileline() << ": error: More than three delays "
		       << "given to a " << gate_name() << " gate." << endl;
		  des->errors += 1;
		  return true;
	    }
	    break;

	  case NMOS:
	  case RNMOS:
	  case PMOS:
	  case RPMOS:
	  case CMOS:
	  case RCMOS:
	    if (delay_count() > 3) {
		  cerr << get_fileline() << ": error: More than three delays "
		       << "given to a " << gate_name() << " switch." << endl;
		  des->errors += 1;
		  return true;
	    }
	    break;

	  case TRAN:
	  case RTRAN:
	    if (delay_count() != 0) {
		  cerr << get_fileline() << ": error: A " << gate_name()
		       << " switch does not take any delays." << endl;
		  des->errors += 1;
		  return true;
	    }
	    break;

	  case TRANIF0:
	  case TRANIF1:
	    if (delay_count() > 2) {
		  cerr << get_fileline() << ": error: More than two delays "
		       << "given to a " << gate_name() << " switch." << endl;
		  des->errors += 1;
		  return true;
	    }
	    break;

	  case RTRANIF0:
	  case RTRANIF1:
	    if (delay_count() > 2) {
		  cerr << get_fileline() << ": error: More than two delays "
		       << "given to an " << gate_name() << " switch." << endl;
		  des->errors += 1;
		  return true;
	    }
	    break;

	  case PULLUP:
	  case PULLDOWN:
	    if (delay_count() != 0) {
		  cerr << get_fileline() << ": error: A " << gate_name()
		       << " source does not take any delays." << endl;
		  des->errors += 1;
		  return true;
	    }
	    break;

	  default:
	    cerr << get_fileline() << ": internal error: unhandled "
		  "gate type." << endl;
	    des->errors += 1;
	    return true;
	    break;
      }

      return false;
}

/*
 * Elaborate a Builtin gate. These normally get translated into
 * NetLogic nodes that reflect the particular logic function.
 */
void PGBuiltin::elaborate(Design*des, NetScope*scope) const
{
      unsigned instance_width = 1;
      perm_string name = get_name();

      if (name == "") name = scope->local_symbol();

	/* Calculate the array bounds and instance count for the gate,
	   as described in the Verilog source. If there is none, then
	   the count is 1, and high==low==0. */

      long low=0, high=0;
      unsigned array_count = calculate_array_size_(des, scope, high, low);
      if (array_count == 0) return;

      unsigned gate_count = 0, lval_count = 0;
      calculate_gate_and_lval_count_(gate_count, lval_count);

	/* Now we have a gate count. Elaborate the lval (output or
           bi-directional) expressions only. We do it early so that
           we can see if we can make wide gates instead of an array
           of gates. */

      vector<NetNet*>lval_sigs (lval_count);

      for (unsigned idx = 0 ; idx < lval_count ; idx += 1) {
	    if (pin(idx) == 0) {
		  cerr << get_fileline() << ": error: Logic gate port "
			"expressions are not optional." << endl;
		  des->errors += 1;
		  return;
	    }
	      // Gates can never have variable output ports.
            if (lval_count > gate_count)
	          lval_sigs[idx] = pin(idx)->elaborate_bi_net(des, scope, false);
            else
	          lval_sigs[idx] = pin(idx)->elaborate_lnet(des, scope, false);

	      // The only way this should return zero is if an error
	      // happened, so for that case just return.
	    if (lval_sigs[idx] == 0) {
		  cerr << get_fileline() << ": error: "
		       << "Failed to elaborate primitive output expression "
		       << scope_path(scope) << "." << *pin(idx) << "." << endl;
		  des->errors += 1;
		  return;
	    }

	      // For now, assume all the outputs are the same width.
	    ivl_assert(*this, idx == 0 || lval_sigs[idx]->vector_width() == lval_sigs[0]->vector_width());
      }

	/* Detect the special case that the l-value width exactly
	   matches the gate count. In this case, we will make a single
	   gate that has the desired vector width.

	   NOTE: This assumes that all the outputs have the same
	   width. For gates with 1 output, this is trivially true. */
      if (lval_sigs[0]->vector_width() == array_count) {
	    instance_width = array_count;
	    array_count = 1;

	    if (debug_elaborate && instance_width != 1)
		  cerr << get_fileline() << ": debug: PGBuiltin: "
			"Collapsed gate array into single wide "
			"(" << instance_width << ") instance." << endl;
      }

	/* Calculate the gate delays from the delay expressions
	   given in the source. For logic gates, the decay time
	   is meaningless because it can never go to high
	   impedance. However, the bufif devices can generate
	   'bz output, so we will pretend that anything can.

	   If only one delay value expression is given (i.e., #5
	   nand(foo,...)) then rise, fall and decay times are
	   all the same value. If two values are given, rise and
	   fall times are use, and the decay time is the minimum
	   of the rise and fall times. Finally, if all three
	   values are given, they are taken as specified. */

      if (check_delay_count(des)) return;
      NetExpr* rise_time, *fall_time, *decay_time;
      eval_delays(des, scope, rise_time, fall_time, decay_time, true);

      struct attrib_list_t*attrib_list;
      unsigned attrib_list_n = 0;
      attrib_list = evaluate_attributes(attributes, attrib_list_n,
					des, scope);

	/* Allocate all the netlist nodes for the gates. */
      vector<NetNode*>cur (array_count*gate_count);

	/* Now make as many gates as the bit count dictates. Give each
	   a unique name, and set the delay times. */

      for (unsigned idx = 0 ;  idx < array_count*gate_count ;  idx += 1) {
	    unsigned array_idx = idx/gate_count;
	    unsigned gate_idx = idx%gate_count;

	    ostringstream tmp;
	    unsigned index = (low < high)? (low+array_idx) : (low-array_idx);

	    tmp << name << "<" << index << "." << gate_idx << ">";
	    perm_string inm = lex_strings.make(tmp.str());

	    cur[idx] = create_gate_for_output_(des, scope, inm, instance_width);
	    if (cur[idx] == 0)
		  return;

	    for (unsigned adx = 0 ;  adx < attrib_list_n ;  adx += 1)
		  cur[idx]->attribute(attrib_list[adx].key,
				      attrib_list[adx].val);

	      /* Set the delays and drive strength for all built in gates. */
	    cur[idx]->rise_time(rise_time);
	    cur[idx]->fall_time(fall_time);
	    cur[idx]->decay_time(decay_time);

	    cur[idx]->pin(0).drive0(strength0());
	    cur[idx]->pin(0).drive1(strength1());

	    cur[idx]->set_line(*this);
	    des->add_node(cur[idx]);
      }


      delete[]attrib_list;

	/* The gates have all been allocated, this loop runs through
	   the parameters and attaches the ports of the objects. */

      for (unsigned idx = 0 ;  idx < pin_count() ;  idx += 1) {

	    PExpr*ex = pin(idx);
	    if (ex == 0) {
		  cerr << get_fileline() << ": error: Logic gate port "
		          "expressions are not optional." << endl;
		  des->errors += 1;
		  return;
	    }
	    NetNet*sig = 0;
	    if (idx < lval_count) {
		  sig = lval_sigs[idx];

	    } else {
                    // If this is an array, the port expression is required
                    // to be the exact width required (this will be checked
                    // later). But if this is a single instance, consensus
                    // is that we just take the LSB of the port expression.
		  NetExpr*tmp = elab_and_eval(des, scope, ex, is_array() ? -1 : 1);
                  if (tmp == 0)
                        continue;
                  if (!is_array() && tmp->expr_width() != 1)
                        tmp = new NetESelect(tmp, make_const_0(1), 1,
                                             IVL_SEL_IDX_UP);
		  sig = tmp->synthesize(des, scope, tmp);
		  delete tmp;
	    }

	    if (sig == 0)
		  continue;

	    ivl_assert(*this, sig);

	    if (array_count == 1) {
		    /* Handle the case where there is one gate that
		       carries the whole vector width. */

		  if (1 == sig->vector_width() && instance_width != 1) {

			ivl_assert(*this, sig->vector_width() == 1);
			NetReplicate*rep
			      = new NetReplicate(scope,
						 scope->local_symbol(),
						 instance_width,
						 instance_width);
			rep->set_line(*this);
			des->add_node(rep);
			connect(rep->pin(1), sig->pin(0));

			const netvector_t*osig_vec = new netvector_t(IVL_VT_LOGIC,
			                                             instance_width-1,0);
			sig = new NetNet(scope, scope->local_symbol(),
					 NetNet::WIRE, osig_vec);
			sig->set_line(*this);
			sig->local_flag(true);
			connect(rep->pin(0), sig->pin(0));

		  }

		  if (instance_width != sig->vector_width()) {

			cerr << get_fileline() << ": error: "
			     << "Expression width " << sig->vector_width()
			     << " does not match width " << instance_width
			     << " of logic gate array port " << idx+1
			     << "." << endl;
			des->errors += 1;
		  }

		    // There is only 1 instance, but there may be
		    // multiple outputs to that gate. That would
		    // potentially mean multiple actual gates.
		    // Although in Verilog proper a multiple
		    // output gate has only 1 input, this conditional
		    // handles gates with N outputs and M inputs.
		  if (idx < gate_count) {
			connect(cur[idx]->pin(0), sig->pin(0));
		  } else {
			for (unsigned dev = 0 ; dev < gate_count; dev += 1)
			      connect(cur[dev]->pin(idx-gate_count+1), sig->pin(0));
		  }

	    } else if (sig->vector_width() == 1) {

		    /* Handle the case where a single bit is connected
		       repetitively to all the instances. If idx is an
		       output port, connect it to all array_count
		       devices that have outputs at this
		       position. Otherwise, idx is an input to all
		       array_count*gate_count devices. */

		  if (idx < gate_count) {
			for (unsigned gdx = 0 ; gdx < array_count ; gdx += 1) {
			      unsigned dev = gdx*gate_count;
			      connect(cur[dev+idx]->pin(0), sig->pin(0));
			}
		  } else {
			unsigned use_idx = idx - gate_count + 1;
			for (unsigned gdx = 0 ;  gdx < cur.size() ;  gdx += 1)
			      connect(cur[gdx]->pin(use_idx), sig->pin(0));
		  }

	    } else if (sig->vector_width() == array_count) {

                    /* Bi-directional switches should get collapsed into
                       a single wide instance, so should never reach this
                       point. Check this is so, as the following code
                       doesn't handle bi-directional connections. */
                  ivl_assert(*this, lval_count == gate_count);

		    /* Handle the general case that each bit of the
		       value is connected to a different instance. In
		       this case, the output is handled slightly
		       different from the inputs. */
		  if (idx < gate_count) {
			NetConcat*cc = new NetConcat(scope,
						     scope->local_symbol(),
						     sig->vector_width(),
						     array_count);
			cc->set_line(*this);
			des->add_node(cc);

			  /* Connect the concat to the signal. */
			connect(cc->pin(0), sig->pin(0));

			  /* Connect the outputs of the gates to the concat. */
			for (unsigned gdx = 0 ;  gdx < array_count;  gdx += 1) {
			      unsigned dev = gdx*gate_count;
			      connect(cur[dev+idx]->pin(0), cc->pin(gdx+1));

			      const netvector_t*tmp2_vec = new netvector_t(IVL_VT_LOGIC);
			      NetNet*tmp2 = new NetNet(scope,
						       scope->local_symbol(),
						       NetNet::WIRE, tmp2_vec);
			      tmp2->set_line(*this);
			      tmp2->local_flag(true);
			      connect(cc->pin(gdx+1), tmp2->pin(0));
			}

		  } else for (unsigned gdx = 0 ;  gdx < array_count ;  gdx += 1) {
			  /* Use part selects to get the bits
			     connected to the inputs of out gate. */
			NetPartSelect*tmp1 = new NetPartSelect(sig, gdx, 1,
							   NetPartSelect::VP);
			tmp1->set_line(*this);
			des->add_node(tmp1);
			connect(tmp1->pin(1), sig->pin(0));
			const netvector_t*tmp2_vec = new netvector_t(sig->data_type());
			NetNet*tmp2 = new NetNet(scope, scope->local_symbol(),
						 NetNet::WIRE, tmp2_vec);
			tmp2->set_line(*this);
			tmp2->local_flag(true);
			connect(tmp1->pin(0), tmp2->pin(0));
			unsigned use_idx = idx - gate_count + 1;
			unsigned dev = gdx*gate_count;
			for (unsigned gdx2 = 0 ; gdx2 < gate_count ; gdx2 += 1)
			      connect(cur[dev+gdx2]->pin(use_idx), tmp1->pin(0));
		  }

	    } else {
		  cerr << get_fileline() << ": error: Gate count of " <<
			array_count << " does not match net width of " <<
			sig->vector_width() << " at pin " << idx << "."
		       << endl;
		  des->errors += 1;
	    }

      }

}

NetNet*PGModule::resize_net_to_port_(Design*des, NetScope*scope,
				     NetNet*sig, unsigned port_wid,
				     NetNet::PortType dir, bool as_signed) const
{
      ivl_assert(*this, dir != NetNet::NOT_A_PORT);
      ivl_assert(*this, dir != NetNet::PIMPLICIT);

      const netvector_t*tmp_type = new netvector_t(IVL_VT_LOGIC, port_wid-1, 0);
      NetNet*tmp = new NetNet(scope, scope->local_symbol(),
			      NetNet::WIRE, tmp_type);
      tmp->local_flag(true);
      tmp->set_line(*this);

	// Handle the special case of a bi-directional part
	// select. Create a NetTran(VP) instead of a uni-directional
	// NetPartSelect node.
      if (dir == NetNet::PINOUT) {
	    unsigned wida = sig->vector_width();
	    unsigned widb = tmp->vector_width();
	    bool part_b = widb < wida;
	      // This needs to pad the value!
	      // Also delete the inout specific warning when this is fixed.
	      // It is located just before this routine is called.
	    NetTran*node = new NetTran(scope, scope->local_symbol(),
				       part_b? wida : widb,
				       part_b? widb : wida,
				       0);
	    if (part_b) {
		  connect(node->pin(0), sig->pin(0));
		  connect(node->pin(1), tmp->pin(0));
	    } else {
		  connect(node->pin(0), tmp->pin(0));
		  connect(node->pin(1), sig->pin(0));
	    }

	    node->set_line(*this);
	    des->add_node(node);

	    return tmp;
      }

      unsigned pwidth = tmp->vector_width();
      unsigned swidth = sig->vector_width();
      switch (dir) {
	  case NetNet::POUTPUT:
	    if (pwidth > swidth) {
		  NetPartSelect*node = new NetPartSelect(tmp, 0, swidth,
					   NetPartSelect::VP);
		  connect(node->pin(0), sig->pin(0));
		  des->add_node(node);
	    } else {
		  NetNet*osig;
		  if (as_signed) {
			osig = pad_to_width_signed(des, tmp, swidth, *this);
		  } else {
			osig = pad_to_width(des, tmp, swidth, *this);
		  }
		  connect(osig->pin(0), sig->pin(0));
	    }
	    break;

	  case NetNet::PINPUT:
	    if (pwidth > swidth) {
		  delete tmp;
		  if (as_signed) {
			tmp = pad_to_width_signed(des, sig, pwidth, *this);
		  } else {
			tmp = pad_to_width(des, sig, pwidth, *this);
		  }
	    } else {
		  NetPartSelect*node = new NetPartSelect(sig, 0, pwidth,
					   NetPartSelect::VP);
		  connect(node->pin(0), tmp->pin(0));
		  des->add_node(node);
	    }
	    break;

	  case NetNet::PINOUT:
	    ivl_assert(*this, 0);
	    break;

	  case NetNet::PREF:
	    ivl_assert(*this, 0);
	    break;

	  default:
	    ivl_assert(*this, 0);
      }

      return tmp;
}

static bool need_bufz_for_input_port(const vector<NetNet*>&prts)
{
      if (prts.empty()) return false;
      if (prts[0]->port_type() != NetNet::PINPUT) return false;
      if (prts[0]->pin(0).nexus()->drivers_present()) return true;
      return false;
}

/*
 * Convert a wire or tri to a tri0 or tri1 as needed to make
 * an unconnected drive pull for floating inputs.
 */
static void convert_net(Design*des, const LineInfo *line,
                        NetNet *net, NetNet::Type type)
{
	// If the types already match just return.
      if (net->type() == type) return;

	// We can only covert a wire or tri to have a default pull.
      if (net->type() == NetNet::WIRE || net->type() == NetNet::TRI) {
	    net->type(type);
	    return;
      }

	// We may have to support this at some point in time!
      cerr << line->get_fileline() << ": sorry: Can not pull floating "
              "input type '" << net->type() << "'." << endl;
      des->errors += 1;
}

static void isolate_and_connect(Design*des, NetScope*scope, const PGModule*mod,
				NetNet*port, NetNet*sig, NetNet::PortType ptype, int idx = -1)
{
      switch (ptype) {
	  case NetNet::POUTPUT:
	    {
		  NetBUFZ*tmp = new NetBUFZ(scope, scope->local_symbol(),
					    sig->vector_width(), true, idx);
		  tmp->set_line(*mod);
		  des->add_node(tmp);
		  connect(tmp->pin(1), port->pin(0));
		  connect(tmp->pin(0), sig->pin(0));
	    }
	    break;
	  case NetNet::PINOUT:
	    {
		  NetTran*tmp = new NetTran(scope, scope->local_symbol(),
					    sig->vector_width(),
					    sig->vector_width(), 0);
		  tmp->set_line(*mod);
		  des->add_node(tmp);
		  connect(tmp->pin(1), port->pin(0));
		  connect(tmp->pin(0), sig->pin(0));
	    }
	    break;
	  default:
	    ivl_assert(*mod, 0);
	    break;
      }
}

void elaborate_unpacked_port(Design *des, NetScope *scope, NetNet *port_net,
			     PExpr *expr, NetNet::PortType port_type,
			     const Module *mod, unsigned int port_idx)
{
      NetNet *expr_net = elaborate_unpacked_array(des, scope, *expr, port_net,
						  expr);
      if (!expr_net) {
	    perm_string port_name = mod->get_port_name(port_idx);
	    cerr << expr->get_fileline() << ":      : Port "
		<< port_idx+1 << " (" << port_name << ") of "
	        << mod->mod_name() << " is connected to "
	        << *expr << endl;

	    return;
      }

      ivl_assert(*port_net, expr_net->pin_count() == port_net->pin_count());
      if (port_type == NetNet::POUTPUT) {
	    // elaborate_unpacked_array normally elaborates a RHS expression
	    // so does not perform this check.
	    if (gn_var_can_be_uwire() && (expr_net->type() == NetNet::REG)) {
		  if (expr_net->peek_lref() > 0) {
			perm_string port_name = mod->get_port_name(port_idx);
			cerr << expr->get_fileline() << ": error: "
				"Cannot connect port '" << port_name
			     << "' to variable '" << expr_net->name()
			     << "'. This conflicts with a procedural "
				"assignment." << endl;
			des->errors += 1;
			return;
		  }
		  expr_net->type(NetNet::UNRESOLVED_WIRE);
	    }
	    assign_unpacked_with_bufz(des, scope, port_net, expr_net, port_net);
      } else
	    assign_unpacked_with_bufz(des, scope, port_net, port_net, expr_net);
}

/*
 * Instantiate a module by recursively elaborating it. Set the path of
 * the recursive elaboration so that signal names get properly
 * set. Connect the ports of the instantiated module to the signals of
 * the parameters. This is done with BUFZ gates so that they look just
 * like continuous assignment connections.
 */
void PGModule::elaborate_mod_(Design*des, Module*rmod, NetScope*scope) const
{

      ivl_assert(*this, scope);

      if (debug_elaborate) {
	    cerr << get_fileline() << ": debug: Instantiate module "
		 << rmod->mod_name() << " with instance name "
		 << get_name() << " in scope " << scope_path(scope) << endl;
      }

	// This is the array of pin expressions, shuffled to match the
	// order of the declaration. If the source instantiation uses
	// bind by order, this is the same as the source list. Otherwise,
	// the source list is rearranged by name binding into this list.
      vector<PExpr*>pins (rmod->port_count());
      vector<bool>pins_fromwc (rmod->port_count(), false);
      vector<bool>pins_is_explicitly_not_connected (rmod->port_count(), false);

	// If the instance has a pins_ member, then we know we are
	// binding by name. Therefore, make up a pins array that
	// reflects the positions of the named ports.
      if (pins_) {
	    unsigned nexp = rmod->port_count();

	      // Scan the bindings, matching them with port names.
	    for (unsigned idx = 0 ;  idx < npins_ ;  idx += 1) {

		    // Handle wildcard named port
		  if (pins_[idx].name[0] == '*') {
			for (unsigned j = 0 ; j < nexp ; j += 1) {
			      if (rmod->ports[j] && !pins[j] && !pins_is_explicitly_not_connected[j]) {
				    pins_fromwc[j] = true;
				    pform_name_t path_;
				    path_.push_back(name_component_t(rmod->ports[j]->name));
				    symbol_search_results sr;
				    symbol_search(this, des, scope, path_, UINT_MAX, &sr);
				    if (sr.net != 0) {
					  pins[j] = new PEIdent(rmod->ports[j]->name, UINT_MAX, true);
					  pins[j]->set_lineno(get_lineno());
					  pins[j]->set_file(get_file());
				    }
			      }
			}
			continue;
		  }

		    // Given a binding, look at the module port names
		    // for the position that matches the binding name.
		  unsigned pidx = rmod->find_port(pins_[idx].name);

		    // If the port name doesn't exist, the find_port
		    // method will return the port count. Detect that
		    // as an error.
		  if (pidx == nexp) {
			cerr << get_fileline() << ": error: port ``" <<
			      pins_[idx].name << "'' is not a port of "
			     << get_name() << "." << endl;
			des->errors += 1;
			continue;
		  }

		    // If I am overriding a wildcard port, delete and
		    // override it
		  if (pins_fromwc[pidx]) {
			delete pins[pidx];
			pins_fromwc[pidx] = false;

		    // If I already explicitly bound something to
		    // this port, then the pins array will already
		    // have a pointer value where I want to place this
		    // expression.
		  } else if (pins[pidx]) {
			cerr << get_fileline() << ": error: port ``" <<
			      pins_[idx].name << "'' already bound." <<
			      endl;
			des->errors += 1;
			continue;
		  }

		    // OK, do the binding by placing the expression in
		    // the right place.
		  pins[pidx] = pins_[idx].parm;
		  if (!pins[pidx])
			pins_is_explicitly_not_connected[pidx] = true;
	    }


      } else if (pin_count() == 0) {

	      /* Handle the special case that no ports are
		 connected. It is possible that this is an empty
		 connect-by-name list, so we'll allow it and assume
		 that is the case. */

	    for (unsigned idx = 0 ;  idx < rmod->port_count() ;  idx += 1)
		  pins[idx] = 0;

      } else {

	      /* Otherwise, this is a positional list of port
		 connections. Use as many ports as provided. Trailing
		 missing ports will be left unconnect or use the default
		 value if one is available */

	    if (pin_count() > rmod->port_count()) {
		  cerr << get_fileline() << ": error: Wrong number "
			"of ports. Expecting at most " << rmod->port_count() <<
			", got " << pin_count() << "."
		       << endl;
		  des->errors += 1;
		  return;
	    }

	    std::copy(get_pins().begin(), get_pins().end(), pins.begin());
      }

	// Elaborate these instances of the module. The recursive
	// elaboration causes the module to generate a netlist with
	// the ports represented by NetNet objects. I will find them
	// later.

      NetScope::scope_vec_t&instance = scope->instance_arrays[get_name()];
      if (debug_elaborate) cerr << get_fileline() << ": debug: start "
	    "recursive elaboration of " << instance.size() << " instance(s) of " <<
	    get_name() << "..." << endl;
      for (unsigned inst = 0 ;  inst < instance.size() ;  inst += 1) {
	    rmod->elaborate(des, instance[inst]);
	    instance[inst]->set_num_ports( rmod->port_count() );
      }
      if (debug_elaborate) cerr << get_fileline() << ": debug: ...done." << endl;


	// Now connect the ports of the newly elaborated designs to
	// the expressions that are the instantiation parameters. Scan
	// the pins, elaborate the expressions attached to them, and
	// bind them to the port of the elaborated module.

	// This can get rather complicated because the port can be
	// unconnected (meaning an empty parameter is passed) connected
	// to a concatenation, or connected to an internally
	// unconnected port.

      for (unsigned idx = 0 ;  idx < pins.size() ;  idx += 1) {
	    bool unconnected_port = false;
	    bool using_default = false;

	    perm_string port_name = rmod->get_port_name(idx);

	      // If the port is unconnected, substitute the default
	      // value. The parser ensures that a default value only
	      // exists for input ports.
	    if (pins[idx] == 0) {
		  PExpr*default_value = rmod->get_port_default_value(idx);
		  if (default_value) {
			pins[idx] = default_value;
			using_default = true;
		  }
	    }

	      // Skip unconnected module ports. This happens when a
	      // null parameter is passed in and there is no default
	      // value.
	    if (pins[idx] == 0) {

		  if (pins_fromwc[idx]) {
			cerr << get_fileline() << ": error: Wildcard named "
			        "port connection (.*) did not find a matching "
			        "identifier for port " << (idx+1) << " ("
			     << port_name << ")." << endl;
			des->errors += 1;
			return;
		  }

		    // We need this information to support the
		    // unconnected_drive directive and for a
		    // unconnected input warning when asked for.
		  vector<PEIdent*> mport = rmod->get_port(idx);
		  if (mport.empty()) continue;

		  perm_string pname = peek_tail_name(mport[0]->path().name);

		  NetNet*tmp = instance[0]->find_signal(pname);

		    // Handle the error case where there is no internal
		    // signal connected to the port.
		  if (!tmp) continue;
		  ivl_assert(*this, tmp);

		  if (tmp->port_type() == NetNet::PINPUT) {
			  // If we have an unconnected input convert it
			  // as needed if an unconnected_drive directive
			  // was given. This only works for tri or wire!
			switch (rmod->uc_drive) {
			    case Module::UCD_PULL0:
			      convert_net(des, this, tmp, NetNet::TRI0);
			      break;
			    case Module::UCD_PULL1:
			      convert_net(des, this, tmp, NetNet::TRI1);
			      break;
			    case Module::UCD_NONE:
			      break;
			}

			  // Print a warning for an unconnected input.
			if (warn_portbinding) {
			      cerr << get_fileline() << ": warning: "
				   << "Instantiating module "
				   << rmod->mod_name()
				   << " with dangling input port "
				   << (idx+1) << " (" << port_name;
			      switch (rmod->uc_drive) {
				  case Module::UCD_PULL0:
				    cerr << ") pulled low." << endl;
				    break;
				  case Module::UCD_PULL1:
				    cerr << ") pulled high." << endl;
				    break;
				  case Module::UCD_NONE:
				    cerr << ") floating." << endl;
				    break;
			      }
			}
		  }
		  unconnected_port = true;
	    }

	      // Inside the module, the port connects zero or more signals
	      // that were already elaborated. List all those signals
	      // and the NetNet equivalents, for all the instances.
	    vector<PEIdent*> mport = rmod->get_port(idx);
	    vector<NetNet*>  prts (mport.size() * instance.size());

	    if (debug_elaborate) {
		  cerr << get_fileline() << ": debug: " << get_name()
		       << ": Port " << (idx+1) << " (" << port_name
		       << ") has " << prts.size() << " sub-ports." << endl;
	    }

	      // Count the internal vector bits of the port.
	    unsigned prts_vector_width = 0;


	      // The input expression is normally elaborated in the calling
	      // scope, except when the defult expression is used which is
	      // elaborated in the instance scope.
	    vector<NetScope*> elab_scope_inst(instance.size());
	    for (unsigned inst = 0 ;  inst < instance.size() ;  inst += 1) {
		  elab_scope_inst[inst] = scope;
		    // Scan the instances from MSB to LSB. The port
		    // will be assembled in that order as well.
		  NetScope*inst_scope = instance[instance.size()-inst-1];
		  if (using_default) elab_scope_inst[inst] = inst_scope;

		  unsigned int prt_vector_width = 0;
		  PortType::Enum ptype = PortType::PIMPLICIT;
		    // Scan the module sub-ports for this instance...
		    // (Sub-ports are concatenated ports that form the
		    // single port for the instance. This is not a
		    // commonly used feature.)
		  for (unsigned ldx = 0 ;  ldx < mport.size() ;  ldx += 1) {
			unsigned lbase = inst * mport.size();
			const PEIdent*pport = mport[ldx];
			ivl_assert(*this, pport);
			NetNet *netnet = pport->elaborate_subport(des, inst_scope);
			prts[lbase + ldx] = netnet;
			if (netnet == 0)
			      continue;

			ivl_assert(*this, netnet);
			unsigned port_width = netnet->vector_width() * netnet->pin_count();
			prts_vector_width += port_width;
			prt_vector_width += port_width;
			ptype = PortType::merged(netnet->port_type(), ptype);
		  }
		  inst_scope->add_module_port_info(idx, port_name, ptype, prt_vector_width );
	    }

	      // If I find that the port is unconnected inside the
	      // module, then there is nothing to connect. Skip the
	      // argument.
	    if ((prts_vector_width == 0) || unconnected_port) {
		  continue;
	    }

	      // We know by design that each instance has the same
	      // width port. Therefore, the prts_pin_count must be an
	      // even multiple of the instance count.
	    ivl_assert(*this, prts_vector_width % instance.size() == 0);

	    if (!prts.empty() && (prts[0]->port_type() == NetNet::PINPUT)
	        && prts[0]->pin(0).nexus()->drivers_present()
	        && pins[idx]->is_collapsible_net(des, scope,
	                                         prts[0]->port_type())) {
                  prts[0]->port_type(NetNet::PINOUT);

		  cerr << pins[idx]->get_fileline() << ": warning: input port "
		       << prts[0]->name() << " is coerced to inout." << endl;
	    }

	    if (!prts.empty() && (prts[0]->port_type() == NetNet::POUTPUT)
	        && (prts[0]->type() != NetNet::REG)
	        && prts[0]->pin(0).nexus()->has_floating_input()
	        && pins[idx]->is_collapsible_net(des, scope,
	                                         prts[0]->port_type())) {
                  prts[0]->port_type(NetNet::PINOUT);

		  cerr << pins[idx]->get_fileline() << ": warning: output port "
		       << prts[0]->name() << " is coerced to inout." << endl;
	    }

	      // Elaborate the expression that connects to the
	      // module[s] port. sig is the thing outside the module
	      // that connects to the port.

	    NetNet*sig = 0;
	    NetNet::PortType ptype;
	    if (prts.empty())
		   ptype = NetNet::NOT_A_PORT;
	    else
		   ptype = prts[0]->port_type();
	    if (prts.empty() || (ptype == NetNet::PINPUT)) {

		    // Special case: If the input port is an unpacked
		    // array, then there should be no sub-ports and
		    // the r-value expression is processed
		    // differently.
		  if (!prts.empty() && prts[0]->unpacked_dimensions() > 0) {
			ivl_assert(*this, prts.size()==1);
			elaborate_unpacked_port(des, scope, prts[0], pins[idx],
						ptype, rmod, idx);
			continue;
		  }

		    /* Input to module. Here we elaborate the source expression
		       using its self-determined width. This allows us to check
		       for and warn about port width mismatches. But in the
		       special case that the source expression is a SV unbased
		       unsized literal, we need to force the expression width
		       to match the destination.

		       NOTE that this also handles the case that the
		       port is actually empty on the inside. We assume
		       in that case that the port is input. */

		  int context_width = -1;
		  if (const PENumber*literal = dynamic_cast<PENumber*>(pins[idx])) {
			if (literal->value().is_single())
			      context_width = prts_vector_width;
		  }
		    // FIXME: The default value is getting the wrong value for
		    //        an array instance since only one scope is used
		    //        and the value can be different for each scope.
		    //        Need to rework the code to support this.
		  NetScope* elab_scope = scope;
		  if (using_default) {
//if (instance.size() > 1) {
//      for (unsigned inst = 0 ;  inst < instance.size() ;  inst += 1) {
//	    cerr << get_fileline() << ": FIXME: Instance " << inst
//	         << " has scope: " << elab_scope_inst[inst]->fullname() << endl;
//      }
//}
			if (instance.size() > 1) {
			      cerr << get_fileline() << ": sorry: An input port "
			           << "default value is not currently supported "
			           << "for a module instance array." << endl;
			      des->errors += 1;
			      continue;
			}
			elab_scope = elab_scope_inst[0];
		  }
		  NetExpr*tmp_expr = elab_and_eval(des, elab_scope, pins[idx], context_width, using_default);
		  if (tmp_expr == 0) {
			cerr << pins[idx]->get_fileline()
			     << ": error: Failed to elaborate input port '"
			     << port_name << "' "
			     << (using_default ? "default value" : "expression")
			     << " (" << *pins[idx] << ") in instance "
			     << scope->fullname() << "." << get_name()
			     << " of module: " << rmod->mod_name() << "." << endl;
			des->errors += 1;
			continue;
		  }

		  if (debug_elaborate) {
			cerr << get_fileline() << ": debug: "
			     << "Elaborating INPUT port expression: " << *tmp_expr << endl;
		  }

		  sig = tmp_expr->synthesize(des, scope, tmp_expr);
		  if (sig == 0) {
			cerr << pins[idx]->get_fileline()
			     << ": internal error: Port expression "
			     << "too complicated for elaboration." << endl;
			continue;
		  }

		  delete tmp_expr;
		  if (!sig->get_lineno()) sig->set_line(*this);

		  if (ptype == NetNet::PINPUT && gn_var_can_be_uwire()) {
			for (unsigned int i = 0; i < prts.size(); i++) {
			      if (prts[i]->type() == NetNet::REG)
				    prts[i]->type(NetNet::UNRESOLVED_WIRE);
			}
		  }

		    // Add module input buffers if needed
		  if (need_bufz_for_input_port(prts) || gn_interconnect_flag == true) {
			  // FIXME improve this for multiple module instances
			NetScope* inner_scope = scope->instance_arrays[get_name()][0];

			NetBUFZ*tmp = new NetBUFZ(inner_scope, inner_scope->local_symbol(),
			                          sig->vector_width(), true, gn_interconnect_flag ? idx : -1);
			tmp->set_line(*this);
			des->add_node(tmp);
			connect(tmp->pin(1), sig->pin(0));

			const netvector_t*tmp2_vec = new netvector_t(sig->data_type(),
			                                             sig->vector_width()-1,0);
			NetNet*tmp2 = new NetNet(inner_scope, inner_scope->local_symbol(),
			                         NetNet::WIRE, tmp2_vec);
			tmp2->local_flag(true);
			tmp2->set_line(*this);
			connect(tmp->pin(0), tmp2->pin(0));
			sig = tmp2;
		  }

		    // If we have a real signal driving a bit/vector port
		    // then we convert the real value using the appropriate
		    // width cast. Since a real is only one bit the whole
		    // thing needs to go to each instance when arrayed.
		  if ((sig->data_type() == IVL_VT_REAL ) &&
		      !prts.empty() && (prts[0]->data_type() != IVL_VT_REAL )) {
			sig = cast_to_int4(des, scope, sig,
			                   prts_vector_width/instance.size());
		  }
		    // If we have a bit/vector signal driving a real port
		    // then we convert the value to a real.
		  if ((sig->data_type() != IVL_VT_REAL ) &&
		      !prts.empty() && (prts[0]->data_type() == IVL_VT_REAL )) {
			sig = cast_to_real(des, scope, sig);
		  }
		    // If we have a 4-state bit/vector signal driving a
		    // 2-state port then we convert the value to 2-state.
		  if ((sig->data_type() == IVL_VT_LOGIC ) &&
		      !prts.empty() && (prts[0]->data_type() == IVL_VT_BOOL )) {
			sig = cast_to_int2(des, scope, sig,
					   sig->vector_width());
		  }

	    } else if (ptype == NetNet::PINOUT) {

		    // For now, do not support unpacked array outputs.
		  ivl_assert(*this, prts[0]->unpacked_dimensions()==0);

		    /* Inout to/from module. This is a more
		       complicated case, where the expression must be
		       an lnet, but also an r-value net.

		       Normally, this winds up being the same as if we
		       just elaborated as an lnet, as passing a simple
		       identifier elaborates to the same NetNet in
		       both cases so the extra elaboration has no
		       effect. But if the expression passed to the
		       inout port is a part select, a special part
		       select must be created that can pass data in
		       both directions.

		       Use the elaborate_bi_net method to handle all
		       the possible cases. */

		    // A module inout port cannot drive a variable.
		  sig = pins[idx]->elaborate_bi_net(des, scope, false);
		  if (sig == 0) {
			cerr << pins[idx]->get_fileline() << ": error: "
			     << "Inout port expression must support "
			     << "continuous assignment." << endl;
			cerr << pins[idx]->get_fileline() << ":      : Port "
			     << (idx+1) << " (" << port_name << ") of "
			     << rmod->mod_name() << " is connected to "
			     << *pins[idx] << endl;
			des->errors += 1;
			continue;
		  }

		    // We do not support automatic bits to real conversion
		    // for inout ports.
		  if ((sig->data_type() == IVL_VT_REAL ) &&
		      !prts.empty() && (prts[0]->data_type() != IVL_VT_REAL )) {
			cerr << pins[idx]->get_fileline() << ": error: "
			     << "Cannot automatically connect bit based "
			        "inout port " << (idx+1) << " (" << port_name
			     << ") of module " << rmod->mod_name()
			     << " to real signal " << sig->name() << "." << endl;
			des->errors += 1;
			continue;
		  }

		    // We do not support real inout ports at all.
		  if (!prts.empty() && (prts[0]->data_type() == IVL_VT_REAL )) {
			cerr << pins[idx]->get_fileline() << ": error: "
			     << "No support for connecting real inout ports ("
			        "port " << (idx+1) << " (" << port_name
			     << ") of module " << rmod->mod_name() << ")." << endl;
			des->errors += 1;
			continue;
		  }


	    } else {

		    /* Port type must be OUTPUT here. */
		  ivl_assert(*this, ptype == NetNet::POUTPUT);

		    // Special case: If the output port is an unpacked
		    // array, then there should be no sub-ports and
		    // the passed port expression is processed
		    // differently. Note that we are calling it the
		    // "r-value" expression, but since this is an
		    // output port, we assign to it from the internal object.
		  if (prts[0]->unpacked_dimensions() > 0) {
			elaborate_unpacked_port(des, scope, prts[0], pins[idx],
						ptype, rmod, idx);
			continue;
		  }

		    // At this point, arrays are handled.
		  ivl_assert(*this, prts[0]->unpacked_dimensions()==0);

		    /* Output from module. Elaborate the port
		       expression as the l-value of a continuous
		       assignment, as the port will continuous assign
		       into the port. */

		    // A module output port can drive a variable.
		  sig = pins[idx]->elaborate_lnet(des, scope, true);
		  if (sig == 0) {
			cerr << pins[idx]->get_fileline() << ": error: "
			     << "Output port expression must support a "
			     << "continuous assignment." << endl;
			cerr << pins[idx]->get_fileline() << ":      : Port "
			     << (idx+1) << " (" << port_name << ") of "
			     << rmod->mod_name() << " is connected to "
			     << scope_path(scope) << "." << *pins[idx] << endl;
			des->errors += 1;
			continue;
		  }

		    // If we have a real port driving a bit/vector signal
		    // then we convert the real value using the appropriate
		    // width cast. Since a real is only one bit the whole
		    // thing needs to go to each instance when arrayed.
		  if ((sig->data_type() != IVL_VT_REAL ) &&
		      !prts.empty() && (prts[0]->data_type() == IVL_VT_REAL )) {
			if (sig->vector_width() % instance.size() != 0) {
			      cerr << pins[idx]->get_fileline() << ": error: "
			              "When automatically converting a real "
			              "port of an arrayed instance to a bit "
			              "signal" << endl;
			      cerr << pins[idx]->get_fileline() << ":      : "
			              "the signal width ("
			           << sig->vector_width() << ") must be an "
			              "integer multiple of the instance count ("
			           << instance.size() << ")." << endl;
			      des->errors += 1;
			      continue;
			}
			prts_vector_width = sig->vector_width();
			for (unsigned pidx = 0; pidx < prts.size(); pidx += 1) {
			      prts[pidx] = cast_to_int4(des, scope, prts[pidx],
			                               prts_vector_width /
			                               instance.size());
			}
		  }

		    // If we have a bit/vector port driving a single real
		    // signal then we convert the value to a real.
		  if ((sig->data_type() == IVL_VT_REAL ) &&
		      !prts.empty() && (prts[0]->data_type() != IVL_VT_REAL )) {
			prts_vector_width -= prts[0]->vector_width() - 1;
			prts[0] = cast_to_real(des, scope, prts[0]);
			  // No support for multiple real drivers.
			if (instance.size() != 1) {
			      cerr << pins[idx]->get_fileline() << ": error: "
			           << "Cannot connect an arrayed instance of "
			              "module " << rmod->mod_name() << " to "
			              "real signal " << sig->name() << "."
			           << endl;
			      des->errors += 1;
			      continue;
			}
		  }

		    // If we have a 4-state bit/vector port driving a
		    // 2-state signal then we convert the value to 2-state.
		  if ((sig->data_type() == IVL_VT_BOOL ) &&
		      !prts.empty() && (prts[0]->data_type() == IVL_VT_LOGIC )) {
			for (unsigned pidx = 0; pidx < prts.size(); pidx += 1) {
			      prts[pidx] = cast_to_int2(des, scope, prts[pidx],
			                                prts[pidx]->vector_width());
			}
		  }

		    // A real to real connection is not allowed for arrayed
		    // instances. You cannot have multiple real drivers.
		  if ((sig->data_type() == IVL_VT_REAL ) &&
		      !prts.empty() && (prts[0]->data_type() == IVL_VT_REAL ) &&
		      instance.size() != 1) {
			cerr << pins[idx]->get_fileline() << ": error: "
			     << "An arrayed instance of " << rmod->mod_name()
			     << " cannot have a real port (port " << (idx+1)
			     << " : " << port_name << ") connected to a "
			        "real signal (" << sig->name() << ")." << endl;
			des->errors += 1;
			continue;
		  }

	    }

	    ivl_assert(*this, sig);

#ifndef NDEBUG
	    if ((! prts.empty())
		&& (ptype != NetNet::PINPUT)) {
		  ivl_assert(*this, sig->type() != NetNet::REG);
	    }
#endif

	      /* If we are working with an instance array, then the
		 signal width must match the port width exactly. */
	    if ((instance.size() != 1)
		&& (sig->vector_width() != prts_vector_width)
		&& (sig->vector_width() != prts_vector_width/instance.size())) {
		  cerr << pins[idx]->get_fileline() << ": error: "
		       << "Port expression width " << sig->vector_width()
		       << " does not match expected width "<< prts_vector_width
		       << " or " << (prts_vector_width/instance.size())
		       << "." << endl;
		  des->errors += 1;
		  continue;
	    }

	    if (debug_elaborate) {
		  cerr << get_fileline() << ": debug: " << get_name()
		       << ": Port " << (idx+1) << " (" << port_name
		       << ") has vector width of " << prts_vector_width
		       << "." << endl;
	    }

	      // Check that the parts have matching pin counts. If
	      // not, they are different widths. Note that idx is 0
	      // based, but users count parameter positions from 1.
	    if ((instance.size() == 1)
		&& (prts_vector_width != sig->vector_width())) {
		  bool as_signed = false;

		  switch (ptype) {
		    case NetNet::POUTPUT:
			as_signed = prts[0]->get_signed();
			break;
		    case NetNet::PINPUT:
			as_signed = sig->get_signed();
			break;
		    case NetNet::PINOUT:
			  /* This may not be correct! */
			as_signed = prts[0]->get_signed() && sig->get_signed();
			break;
		    case NetNet::PREF:
			ivl_assert(*this, 0);
			break;
		    default:
			ivl_assert(*this, 0);
		  }

		  cerr << get_fileline() << ": warning: Port " << (idx+1)
		       << " (" << port_name << ") of module "
		       << type_ << " expects " << prts_vector_width <<
			" bit(s), given " << sig->vector_width() << "." << endl;

		    // Delete this when inout ports pad correctly.
		  if (ptype == NetNet::PINOUT) {
		     if (prts_vector_width > sig->vector_width()) {
			cerr << get_fileline() << ":        : Leaving "
			     << (prts_vector_width-sig->vector_width())
			     << " high bits of the port unconnected."
			     << endl;
		     } else {
			cerr << get_fileline() << ":        : Leaving "
			     << (sig->vector_width()-prts_vector_width)
			     << " high bits of the expression dangling."
			     << endl;
		     }
		    // Keep the if, but delete the "} else" when fixed.
		  } else if (prts_vector_width > sig->vector_width()) {
			cerr << get_fileline() << ":        : Padding ";
			if (as_signed) cerr << "(signed) ";
			cerr << (prts_vector_width-sig->vector_width())
			     << " high bits of the port."
			     << endl;
		  } else {
			if (ptype == NetNet::PINPUT) {
			      cerr << get_fileline() << ":        : Pruning ";
			} else {
			      cerr << get_fileline() << ":        : Padding ";
			}
			if (as_signed) cerr << "(signed) ";
			cerr << (sig->vector_width()-prts_vector_width)
			     << " high bits of the expression."
			     << endl;
		  }

		  sig = resize_net_to_port_(des, scope, sig, prts_vector_width,
					    ptype, as_signed);
	    }

	      // Connect the sig expression that is the context of the
	      // module instance to the ports of the elaborated module.

	      // The prts_pin_count variable is the total width of the
	      // port and is the maximum number of connections to
	      // make. sig is the elaborated expression that connects
	      // to that port. If sig has too few pins, then reduce
	      // the number of connections to make.

	      // Connect this many of the port pins. If the expression
	      // is too small, then reduce the number of connects.
	    unsigned ccount = prts_vector_width;
	    if (instance.size() == 1 && sig->vector_width() < ccount)
		  ccount = sig->vector_width();

	      // Now scan the concatenation that makes up the port,
	      // connecting pins until we run out of port pins or sig
	      // pins. The sig object is the NetNet that is connected
	      // to the port from the outside, and the prts object is
	      // an array of signals to be connected to the sig.


	    if (prts.size() == 1) {

		    // The simplest case, there are no
		    // parts/concatenations on the inside of the
		    // module, so the port and sig need simply be
		    // connected directly. But don't collapse ports
		    // that are a delay path destination, to avoid
		    // the delay being applied to other drivers of
		    // the external signal.
		  if (prts[0]->delay_paths() > 0 || (gn_interconnect_flag == true && ptype == NetNet::POUTPUT)) {
			  // FIXME improve this for multiple module instances
			NetScope* inner_scope = scope->instance_arrays[get_name()][0];

			isolate_and_connect(des, inner_scope, this, prts[0], sig, ptype, gn_interconnect_flag ? idx : -1);
		  } else {
			connect(prts[0]->pin(0), sig->pin(0));
		  }

	    } else if (sig->vector_width()==prts_vector_width/instance.size()
		       && prts.size()/instance.size() == 1) {

		  if (debug_elaborate){
			cerr << get_fileline() << ": debug: " << get_name()
			     << ": Replicating " << prts_vector_width
			     << " bits across all "
			     << prts_vector_width/instance.size()
			     << " sub-ports." << endl;
		  }

		    // The signal width is exactly the width of a
		    // single instance of the port. In this case,
		    // connect the sig to all the ports identically.
		  for (unsigned ldx = 0 ;  ldx < prts.size() ;	ldx += 1) {
			if (prts[ldx]->delay_paths() > 0) {
			      isolate_and_connect(des, scope, this, prts[ldx], sig, ptype);
			} else {
			      connect(prts[ldx]->pin(0), sig->pin(0));
			}
		  }

	    } else switch (ptype) {
		case NetNet::POUTPUT:
		  NetConcat*ctmp;
		  ctmp = new NetConcat(scope, scope->local_symbol(),
				       prts_vector_width, prts.size());
		  ctmp->set_line(*this);
		  des->add_node(ctmp);
		  connect(ctmp->pin(0), sig->pin(0));
		  for (unsigned ldx = 0 ;  ldx < prts.size() ;  ldx += 1) {
			connect(ctmp->pin(ldx+1),
				prts[prts.size()-ldx-1]->pin(0));
		  }
		  break;

		case NetNet::PINPUT:
		  if (debug_elaborate){
			cerr << get_fileline() << ": debug: " << get_name()
			     << ": Dividing " << prts_vector_width
			     << " bits across all "
			     << prts_vector_width/instance.size()
			     << " input sub-ports of port "
			     << (idx+1) << "." << endl;
		  }

		  for (unsigned ldx = 0, spin = 0 ;
		       ldx < prts.size() ;  ldx += 1) {
			NetNet*sp = prts[prts.size()-ldx-1];
			NetPartSelect*ptmp = new NetPartSelect(sig, spin,
							   sp->vector_width(),
							   NetPartSelect::VP);
			ptmp->set_line(*this);
			des->add_node(ptmp);
			connect(ptmp->pin(0), sp->pin(0));
			spin += sp->vector_width();
		  }
		  break;

		case NetNet::PINOUT:
		  for (unsigned ldx = 0, spin = 0 ;
		       ldx < prts.size() ;  ldx += 1) {
			NetNet*sp = prts[prts.size()-ldx-1];
			NetTran*ttmp = new NetTran(scope,
			                           scope->local_symbol(),
			                           sig->vector_width(),
			                           sp->vector_width(),
			                           spin);
			ttmp->set_line(*this);
			des->add_node(ttmp);
			connect(ttmp->pin(0), sig->pin(0));
			connect(ttmp->pin(1), sp->pin(0));
			spin += sp->vector_width();
		  }
		  break;

		case NetNet::PREF:
		  cerr << get_fileline() << ": sorry: "
		       << "Reference ports not supported yet." << endl;
		  des->errors += 1;
		  break;

		case NetNet::PIMPLICIT:
		  cerr << get_fileline() << ": internal error: "
		       << "Unexpected IMPLICIT port" << endl;
		  des->errors += 1;
		  break;
		case NetNet::NOT_A_PORT:
		  cerr << get_fileline() << ": internal error: "
		       << "Unexpected NOT_A_PORT port." << endl;
		  des->errors += 1;
		  break;
	    }

      }

}

/*
 * From a UDP definition in the source, make a NetUDP
 * object. Elaborate the pin expressions as netlists, then connect
 * those networks to the pins.
 */

void PGModule::elaborate_udp_(Design*des, PUdp*udp, NetScope*scope) const
{
      NetExpr*rise_expr =0, *fall_expr =0, *decay_expr =0;

      perm_string my_name = get_name();
      if (my_name == 0)
	    my_name = scope->local_symbol();

	/* When the parser notices delay expressions in front of a
	   module or primitive, it interprets them as parameter
	   overrides. Correct that misconception here. */
      if (overrides_) {
	    if (overrides_->size() > 2) {
		  cerr << get_fileline() << ": error: UDPs take at most two "
		          "delay arguments." << endl;
		  des->errors += 1;
	    } else {
		  PDelays tmp_del;
		  tmp_del.set_delays(overrides_, false);
		  tmp_del.eval_delays(des, scope, rise_expr, fall_expr,
		                      decay_expr, true);
	    }
      }

      long low = 0, high = 0;
      unsigned inst_count = calculate_array_size_(des, scope, high, low);
      if (inst_count == 0) return;

      if (inst_count != 1) {
	    cerr << get_fileline() << ": sorry: UDPs with a range ("
	         << my_name << " [" << high << ":" << low << "]) are "
	         << "not supported." << endl;
	    des->errors += 1;
	    return;
      }

      ivl_assert(*this, udp);
      NetUDP*net = new NetUDP(scope, my_name, udp->ports.size(), udp);
      net->set_line(*this);
      net->rise_time(rise_expr);
      net->fall_time(fall_expr);
      net->decay_time(decay_expr);

      struct attrib_list_t*attrib_list;
      unsigned attrib_list_n = 0;
      attrib_list = evaluate_attributes(attributes, attrib_list_n,
					des, scope);

      for (unsigned adx = 0 ;  adx < attrib_list_n ;  adx += 1)
	    net->attribute(attrib_list[adx].key, attrib_list[adx].val);

      delete[]attrib_list;


	// This is the array of pin expressions, shuffled to match the
	// order of the declaration. If the source instantiation uses
	// bind by order, this is the same as the source
	// list. Otherwise, the source list is rearranged by name
	// binding into this list.
      vector<PExpr*>pins;

	// Detect binding by name. If I am binding by name, then make
	// up a pins array that reflects the positions of the named
	// ports. If this is simply positional binding in the first
	// place, then get the binding from the base class.
      if (pins_) {
	    unsigned nexp = udp->ports.size();
	    pins = vector<PExpr*>(nexp);

	      // Scan the bindings, matching them with port names.
	    for (unsigned idx = 0 ;  idx < npins_ ;  idx += 1) {

		    // Given a binding, look at the module port names
		    // for the position that matches the binding name.
		  unsigned pidx = udp->find_port(pins_[idx].name);

		    // If the port name doesn't exist, the find_port
		    // method will return the port count. Detect that
		    // as an error.
		  if (pidx == nexp) {
			cerr << get_fileline() << ": error: port ``" <<
			      pins_[idx].name << "'' is not a port of "
			     << get_name() << "." << endl;
			des->errors += 1;
			continue;
		  }

		    // If I already bound something to this port, then
		    // the (*exp) array will already have a pointer
		    // value where I want to place this expression.
		  if (pins[pidx]) {
			cerr << get_fileline() << ": error: port ``" <<
			      pins_[idx].name << "'' already bound." <<
			      endl;
			des->errors += 1;
			continue;
		  }

		    // OK, do the binding by placing the expression in
		    // the right place.
		  pins[pidx] = pins_[idx].parm;
	    }

      } else {

	      /* Otherwise, this is a positional list of port
		 connections. In this case, the port count must be
		 right. Check that is is, the get the pin list. */

	    if (pin_count() != udp->ports.size()) {
		  cerr << get_fileline() << ": error: Wrong number "
			"of ports. Expecting " << udp->ports.size() <<
			", got " << pin_count() << "."
		       << endl;
		  des->errors += 1;
		  return;
	    }

	      // No named bindings, just use the positional list I
	      // already have.
	    ivl_assert(*this, pin_count() == udp->ports.size());
	    pins = get_pins();
      }


	/* Handle the output port of the primitive special. It is an
	   output port (the only output port) so must be passed an
	   l-value net. */
      if (pins[0] == 0) {
	    cerr << get_fileline() << ": warning: output port unconnected."
		 << endl;

      } else {
	      // A UDP can drive a variable.
	    NetNet*sig = pins[0]->elaborate_lnet(des, scope, true);
	    if (sig == 0) {
		  cerr << get_fileline() << ": error: "
		       << "Output port expression is not valid." << endl;
		  cerr << get_fileline() << ":      : Output "
		       << "port of " << udp->name_
		       << " is " << udp->ports[0] << "." << endl;
		  des->errors += 1;
		  return;
	    } else {
		  connect(sig->pin(0), net->pin(0));
	    }
	    if (sig->vector_width() != 1) {
		  cerr << get_fileline() << ": error: "
		       << "Output port expression " << *pins[0]
		       << " is too wide (" << sig->vector_width()
		       << ") expected 1." << endl;
		  des->errors += 1;
	    }
      }

	/* Run through the pins, making netlists for the pin
	   expressions and connecting them to the pin in question. All
	   of this is independent of the nature of the UDP. */
      for (unsigned idx = 1 ;  idx < net->pin_count() ;  idx += 1) {
	    if (pins[idx] == 0)
		  continue;

	    NetExpr*expr_tmp = elab_and_eval(des, scope, pins[idx], 1);
	    if (expr_tmp == 0) {
		  cerr << "internal error: Expression too complicated "
			"for elaboration:" << *pins[idx] << endl;
		  continue;
	    }
	    NetNet*sig = expr_tmp->synthesize(des, scope, expr_tmp);
	    ivl_assert(*this, sig);
	    sig->set_line(*this);

	    delete expr_tmp;

	    connect(sig->pin(0), net->pin(idx));
	    if (sig->vector_width() != 1) {
		  cerr << get_fileline() << ": error: "
		       << "Input port expression " << *pins[idx]
		       << " is too wide (" << sig->vector_width()
		       << ") expected 1." << endl;
		  des->errors += 1;
	    }
      }

	// All done. Add the object to the design.
      des->add_node(net);
}


bool PGModule::elaborate_sig(Design*des, NetScope*scope) const
{
      if (bound_type_) {
	    return elaborate_sig_mod_(des, scope, bound_type_);
      }

	// Look for the module type
      map<perm_string,Module*>::const_iterator mod = pform_modules.find(type_);
      if (mod != pform_modules.end())
	    return elaborate_sig_mod_(des, scope, (*mod).second);

	// elaborate_sig_udp_ currently always returns true so skip all this
	// for now.
#if 0
      map<perm_string,PUdp*>::const_iterator udp = pform_primitives.find(type_);
      if (udp != pform_primitives.end())
	    return elaborate_sig_udp_(des, scope, (*udp).second);
#endif

      return true;
}


void PGModule::elaborate(Design*des, NetScope*scope) const
{
      if (bound_type_) {
	    elaborate_mod_(des, bound_type_, scope);
	    return;
      }

	// Look for the module type
      map<perm_string,Module*>::const_iterator mod = pform_modules.find(type_);
      if (mod != pform_modules.end()) {
	    elaborate_mod_(des, (*mod).second, scope);
	    return;
      }

	// Try a primitive type
      map<perm_string,PUdp*>::const_iterator udp = pform_primitives.find(type_);
      if (udp != pform_primitives.end()) {
	    ivl_assert(*this, (*udp).second);
	    elaborate_udp_(des, (*udp).second, scope);
	    return;
      }

      if (!ignore_missing_modules) {
        cerr << get_fileline() << ": internal error: Unknown module type: " <<
	      type_ << endl;
      }
}

void PGModule::elaborate_scope(Design*des, NetScope*sc) const
{
	// If the module type is known by design, then go right to it.
      if (bound_type_) {
	    elaborate_scope_mod_(des, bound_type_, sc);
	    return;
      }

	// Look for the module type
      map<perm_string,Module*>::const_iterator mod = pform_modules.find(type_);
      if (mod != pform_modules.end()) {
	    elaborate_scope_mod_(des, mod->second, sc);
	    return;
      }

	// Try a primitive type
      map<perm_string,PUdp*>::const_iterator udp = pform_primitives.find(type_);
      if (udp != pform_primitives.end())
	    return;

	// Not a module or primitive that I know about yet, so try to
	// load a library module file (which parses some new Verilog
	// code) and try again.
      int parser_errors = 0;
      if (load_module(type_, parser_errors)) {

	      // Try again to find the module type
	    mod = pform_modules.find(type_);
	    if (mod != pform_modules.end()) {
		  elaborate_scope_mod_(des, mod->second, sc);
		  return;
	    }

	      // Try again to find a primitive type
	    udp = pform_primitives.find(type_);
	    if (udp != pform_primitives.end())
		  return;
      }

      if (parser_errors) {
            cerr << get_fileline() << ": error: Failed to parse library file." << endl;
            des->errors += parser_errors + 1;
      }

	// Not a module or primitive that I know about or can find by
	// any means, so give up.
      if (!ignore_missing_modules) {
        cerr << get_fileline() << ": error: Unknown module type: " << type_ << endl;
        missing_modules[type_] += 1;
        des->errors += 1;
      }
}


NetProc* Statement::elaborate(Design*des, NetScope*) const
{
      cerr << get_fileline() << ": internal error: elaborate: "
	    "What kind of statement? " << typeid(*this).name() << endl;
      NetProc*cur = new NetProc;
      des->errors += 1;
      return cur;
}

NetProc* PNoop::elaborate(Design*, NetScope*) const
{
      return new NetBlock(NetBlock::SEQU, 0);
}


NetAssign_* PAssign_::elaborate_lval(Design*des, NetScope*scope) const
{
	// A function called as a task does not have an L-value.
      if (! lval_) {
	      // The R-value must be a simple function call.
	    assert (dynamic_cast<PECallFunction*>(rval_));
	    PExpr::width_mode_t mode = PExpr::SIZED;
	    rval_->test_width(des, scope, mode);
	      // Create a L-value that matches the function return type.
	    NetNet*tmp;
	    const netvector_t*tmp_vec = new netvector_t(rval_->expr_type(),
	                                                rval_->expr_width()-1, 0,
	                                                rval_->has_sign());

	    if(rval_->expr_type() == IVL_VT_DARRAY) {
		const netdarray_t*darray = new netdarray_t(tmp_vec);
		tmp = new NetNet(scope, scope->local_symbol(), NetNet::REG, darray);
	    } else {
		tmp = new NetNet(scope, scope->local_symbol(), NetNet::REG, tmp_vec);
	    }

	    tmp->set_file(rval_->get_file());
	    tmp->set_lineno(rval_->get_lineno());
	    NetAssign_*lv = new NetAssign_(tmp);
	    return lv;
      }

      if (debug_elaborate) {
	    cerr << get_fileline() << ": PAssign_::elaborate_lval: "
		 << "lval_ = " << *lval_ << endl;
	    cerr << get_fileline() << ": PAssign_::elaborate_lval: "
		 << "lval_ expr type = " << typeid(*lval_).name() << endl;
      }

      return lval_->elaborate_lval(des, scope, false, false, is_init_);
}

NetExpr* PAssign_::elaborate_rval_(Design*des, NetScope*scope,
				   ivl_type_t net_type) const
{
      ivl_assert(*this, rval_);

      NetExpr*rv = elaborate_rval_expr(des, scope, net_type, rval_,
				       is_constant_);

      if (!is_constant_ || !rv) return rv;

      cerr << get_fileline() << ": error: "
            "The RHS expression must be constant." << endl;
      cerr << get_fileline() << "       : "
            "This expression violates the rule: " << *rv << endl;
      des->errors += 1;
      delete rv;
      return 0;
}

NetExpr* PAssign_::elaborate_rval_(Design*des, NetScope*scope,
				   ivl_type_t lv_net_type,
				   ivl_variable_type_t lv_type,
				   unsigned lv_width,
				   bool force_unsigned) const
{
      ivl_assert(*this, rval_);

      NetExpr*rv = elaborate_rval_expr(des, scope, lv_net_type, lv_type, lv_width,
				       rval(), is_constant_, force_unsigned);

      if (!is_constant_ || !rv) return rv;

      if (dynamic_cast<NetEConst*>(rv)) return rv;
      if (dynamic_cast<NetECReal*>(rv)) return rv;

      cerr << get_fileline() << ": error: "
            "The RHS expression must be constant." << endl;
      cerr << get_fileline() << "       : "
            "This expression violates the rule: " << *rv << endl;
      des->errors += 1;
      delete rv;
      return 0;
}

/*
 * This function elaborates delay expressions. This is a little
 * different from normal elaboration because the result may need to be
 * scaled.
 */
static NetExpr*elaborate_delay_expr(PExpr*expr, Design*des, NetScope*scope)
{
      NetExpr*dex = elab_and_eval(des, scope, expr, -1);

	// If the elab_and_eval returns nil, then the function
	// failed. It should already have printed an error message,
	// but we can add some detail. Lets add the error count, just
	// in case.
      if (dex == 0) {
	    cerr << expr->get_fileline() << ": error: "
		 << "Unable to elaborate (or evaluate) delay expression."
		 << endl;
	    des->errors += 1;
	    return 0;
      }

      check_for_inconsistent_delays(scope);

	/* If the delay expression is a real constant or vector
	   constant, then evaluate it, scale it to the local time
	   units, and return an adjusted NetEConst. */

      if (NetECReal*tmp = dynamic_cast<NetECReal*>(dex)) {
	    uint64_t delay = get_scaled_time_from_real(des, scope, tmp);

	    delete tmp;
	    NetEConst*tmp2 = new NetEConst(verinum(delay, 64));
	    tmp2->set_line(*expr);
	    return tmp2;
      }


      if (NetEConst*tmp = dynamic_cast<NetEConst*>(dex)) {
	    verinum fn = tmp->value();
	    uint64_t delay = des->scale_to_precision(fn.as_ulong64(), scope);

	    delete tmp;
	    NetEConst*tmp2 = new NetEConst(verinum(delay, 64));
	    tmp2->set_line(*expr);
	    return tmp2;
      }


	/* The expression is not constant, so generate an expanded
	   expression that includes the necessary scale shifts, and
	   return that expression. */
      ivl_assert(*expr, dex);
      if (dex->expr_type() == IVL_VT_REAL) {
	      // Scale the real value.
	    int shift = scope->time_unit() - scope->time_precision();
	    ivl_assert(*expr, shift >= 0);
	    double round = 1;
	    for (int lp = 0; lp < shift; lp += 1) round *= 10.0;

	    NetExpr*scal_val = new NetECReal(verireal(round));
	    scal_val->set_line(*expr);
	    dex = new NetEBMult('*', dex, scal_val, 1, true);
	    dex->set_line(*expr);

	      // Cast this part of the expression to an integer.
	    dex = new NetECast('v', dex, 64, false);
	    dex->set_line(*expr);

	      // Now scale the integer value.
	    shift = scope->time_precision() - des->get_precision();
	    ivl_assert(*expr, shift >= 0);
	    uint64_t scale = 1;
	    for (int lp = 0; lp < shift; lp += 1) scale *= 10;

	    scal_val = new NetEConst(verinum(scale, 64));
	    scal_val->set_line(*expr);
	    dex = new NetEBMult('*', dex, scal_val, 64, false);
	    dex->set_line(*expr);
      } else {
	    int shift = scope->time_unit() - des->get_precision();
	    ivl_assert(*expr, shift >= 0);
	    uint64_t scale = 1;
	    for (int lp = 0; lp < shift; lp += 1) scale *= 10;

	    NetExpr*scal_val = new NetEConst(verinum(scale, 64));
	    scal_val->set_line(*expr);
	    dex = new NetEBMult('*', dex, scal_val, 64, false);
	    dex->set_line(*expr);
      }

      return dex;
}

NetProc* PAssign::elaborate_compressed_(Design*des, NetScope*scope) const
{
      ivl_assert(*this, ! delay_);
      ivl_assert(*this, ! count_);
      ivl_assert(*this, ! event_);

      NetAssign_*lv = elaborate_lval(des, scope);
      if (lv == 0) return 0;

	// Compressed assignments should behave identically to the
	// equivalent uncompressed assignments. This means we need
	// to take the type of the LHS into account when determining
	// the type of the RHS expression.
      bool force_unsigned;
      switch (op_) {
	  case 'l':
	  case 'r':
	  case 'R':
	      // The right-hand operand of shift operations is
	      // self-determined.
	    force_unsigned = false;
	    break;
	  default:
	    force_unsigned = !lv->get_signed();
	    break;
      }
      NetExpr*rv = elaborate_rval_(des, scope, 0, lv->expr_type(),
				   count_lval_width(lv), force_unsigned);
      if (rv == 0) return 0;

      /* IEEE 1800-2017 §6.19.4: compound assignments on enum variables
         produce a non-enum integer result that cannot be implicitly
         stored back to the enum.  Error unless the lval is not an enum. */
      if (lv->sig()) {
	    if (dynamic_cast<const netenum_t*>(lv->sig()->net_type())) {
		  cerr << get_fileline() << ": error: "
		       << "Compound assignment on enum variable without explicit cast."
		       << endl;
		  des->errors += 1;
	    }
      }

	// The ivl_target API doesn't support signalling the type
	// of a lval, so convert arithmetic shifts into logical
	// shifts now if the lval is unsigned.
      char op = op_;
      if ((op == 'R') && !lv->get_signed())
	    op = 'r';

      NetAssign*cur = new NetAssign(lv, op, rv);
      cur->set_line(*this);

      return cur;
}

/*
 * Assignments within program blocks are supposed to be run
 * in the Reactive region, but that is currently not supported
 * so find out if we are assigning to something outside a
 * program block and print a warning for that.
 */
static bool lval_not_program_variable(const NetAssign_*lv)
{
      while (lv) {
	    const NetScope*sig_scope = lv->scope();
	    if (! sig_scope->program_block()) return true;
	    lv = lv->more;
      }
      return false;
}

/* Phase 63b/B7 (gap close): when assigning a tagged-union constructor
 * `u = '{TAG: val}` (or equivalently `u = tagged TAG val`), build a
 * NetAssign that updates the companion tag NetNet to the member index.
 * Returns null if no companion update is needed. */
static NetProc*build_tagged_union_companion_set_(Design*des, NetScope*scope,
                                                 NetAssign_*lv,
                                                 const PAssign_*paf)
{
      if (!lv || !paf) return nullptr;
      NetNet*lv_sig = lv->sig();
      if (!lv_sig) return nullptr;
      const netstruct_t*nst = dynamic_cast<const netstruct_t*>(lv_sig->net_type());
      if (!nst || !nst->tagged_flag()) return nullptr;

      const PEAssignPattern*pat = dynamic_cast<const PEAssignPattern*>(paf->rval());
      if (!pat) return nullptr;
      if (pat->parm_names().size() != 1) return nullptr;
      perm_string tag_name = pat->parm_names().front();

      unsigned tag_idx = nst->member_index(tag_name);
      if (tag_idx == (unsigned)-1) return nullptr;

      perm_string companion_name =
            lex_strings.make(string(lv_sig->name().str()) + "__tag_companion");
      NetScope*decl_scope = lv_sig->scope();
      if (!decl_scope) decl_scope = scope;
      NetNet*companion = decl_scope->find_signal(companion_name);
      if (!companion) return nullptr;

      NetAssign_*comp_lv = new NetAssign_(companion);
      verinum vi((uint64_t)tag_idx, 32);
      NetEConst*idx_e = new NetEConst(vi);
      idx_e->set_line(*paf);
      NetAssign*comp_as = new NetAssign(comp_lv, idx_e);
      comp_as->set_line(*paf);
      (void)des;
      return comp_as;
}

// Chapter-11 LHS closure: `{<<8 {o_hdr, ..., o_data}} = pkt` where o_data
// is a byte darray (LSB position) and pkt is a byte queue.  The parse-time
// rewrite for `{<<N {ops}} = rhs` with N>1 produces `{ops} = {<<N {rhs}}`,
// which keeps the same darray-width gap as the RHS path plus a multi-lval
// assign that tgt-vvp doesn't support.  Lower to a NetSTask call that
// emits the runtime byte unpacking:
//   pkt[0..darray_size-1]            → darray bytes (reverse: pkt[0] = LSB byte)
//   pkt[darray_size..darray_size+W0] → first fixed op (LSB first, low byte of op)
//   ...
static const netdarray_t* lval_byte_darray_(Design*des, NetScope*scope, PExpr*op);
static bool lval_byte_multiple_vec_(Design*des, NetScope*scope, PExpr*op, unsigned*wid_out);

static NetProc* build_stream_unpack_byte_queue_(Design*des, NetScope*scope,
                                                 const PEConcat*lhs_concat,
                                                 PEStreaming*rhs_stream,
                                                 const LineInfo&loc)
{
      if (!lhs_concat || !rhs_stream) return nullptr;
      if (rhs_stream->get_dir() != PEStreaming::DIR_LSHIFT) return nullptr;
      if (rhs_stream->get_slice() != 8) return nullptr;

      // RHS inner must be a PEIdent that resolves to a byte queue.
      PExpr*inner = rhs_stream->get_inner();
      const PEIdent*pkt_id = dynamic_cast<const PEIdent*>(inner);
      if (!pkt_id) return nullptr;
      symbol_search_results sr;
      if (!symbol_search(pkt_id, des, scope, pkt_id->path(),
                         pkt_id->lexical_pos(), &sr))
            return nullptr;
      if (!sr.net) return nullptr;
      const netqueue_t*pkt_q = dynamic_cast<const netqueue_t*>(sr.net->net_type());
      if (!pkt_q) return nullptr;
      ivl_type_t pkt_elt = pkt_q->element_type();
      if (!pkt_elt) return nullptr;
      if (pkt_elt->base_type() != IVL_VT_BOOL && pkt_elt->base_type() != IVL_VT_LOGIC)
            return nullptr;
      if (pkt_elt->packed_width() != 8) return nullptr;

      const std::vector<PExpr*>&ops = lhs_concat->parms();
      if (ops.empty()) return nullptr;

      // Last operand must be a byte darray.
      PExpr*last_op = ops.back();
      if (!lval_byte_darray_(des, scope, last_op)) return nullptr;

      // All other operands must be byte-multiple-width fixed-width vecs.
      std::vector<unsigned> fixed_widths;
      for (size_t k = 0; k+1 < ops.size(); k++) {
            unsigned w = 0;
            if (!lval_byte_multiple_vec_(des, scope, ops[k], &w)) return nullptr;
            fixed_widths.push_back(w);
      }

      // Build the NetSTask call:
      //   $ivl_q_unpack_byte_dar_ops(pkt_sig, darray_sig, fixed_op0, fixed_op1, ...)
      //   (fixed ops in original concat order — MSB-first.)
      std::vector<NetExpr*> argv;

      // arg[0] = pkt
      NetESignal*pkt_sig = new NetESignal(sr.net);
      pkt_sig->set_line(loc);
      argv.push_back(pkt_sig);

      // arg[1] = darray
      const PEIdent*da_id = dynamic_cast<const PEIdent*>(last_op);
      symbol_search_results da_sr;
      if (!symbol_search(da_id, des, scope, da_id->path(),
                         da_id->lexical_pos(), &da_sr) || !da_sr.net)
            return nullptr;
      NetESignal*da_sig = new NetESignal(da_sr.net);
      da_sig->set_line(loc);
      argv.push_back(da_sig);

      // args[2..] = fixed ops in original (MSB-first) concat order.
      for (size_t k = 0; k+1 < ops.size(); k++) {
            const PEIdent*op_id = dynamic_cast<const PEIdent*>(ops[k]);
            if (!op_id) return nullptr;
            symbol_search_results op_sr;
            if (!symbol_search(op_id, des, scope, op_id->path(),
                               op_id->lexical_pos(), &op_sr) || !op_sr.net)
                  return nullptr;
            NetESignal*op_sig = new NetESignal(op_sr.net);
            op_sig->set_line(loc);
            argv.push_back(op_sig);
      }

      NetSTask*task = new NetSTask("$ivl_q_unpack_byte_dar_ops",
                                   IVL_SFUNC_AS_TASK_IGNORE, argv);
      task->set_line(loc);
      return task;
}

static const netdarray_t* lval_byte_darray_(Design*des, NetScope*scope, PExpr*op)
{
      const PEIdent*id = dynamic_cast<const PEIdent*>(op);
      if (!id) return nullptr;
      symbol_search_results sr;
      if (!symbol_search(id, des, scope, id->path(),
                         id->lexical_pos(), &sr))
            return nullptr;
      if (!sr.net) return nullptr;
      const netdarray_t*da = dynamic_cast<const netdarray_t*>(sr.net->net_type());
      if (!da) return nullptr;
      // Reject queues here — only plain darrays (byte d[]).
      if (dynamic_cast<const netqueue_t*>(sr.net->net_type())) return nullptr;
      ivl_type_t et = da->element_type();
      if (!et) return nullptr;
      if (et->base_type() != IVL_VT_BOOL && et->base_type() != IVL_VT_LOGIC)
            return nullptr;
      if (et->packed_width() != 8) return nullptr;
      return da;
}

static bool lval_byte_multiple_vec_(Design*des, NetScope*scope, PExpr*op,
                                     unsigned*wid_out)
{
      const PEIdent*id = dynamic_cast<const PEIdent*>(op);
      if (!id) return false;
      symbol_search_results sr;
      if (!symbol_search(id, des, scope, id->path(),
                         id->lexical_pos(), &sr))
            return false;
      if (!sr.net) return false;
      ivl_type_t t = sr.net->net_type();
      if (!t) return false;
      // Reject darray/queue/class/string types — only plain vectors.
      if (dynamic_cast<const netdarray_t*>(t)) return false;
      if (dynamic_cast<const netuarray_t*>(t)) return false;
      if (dynamic_cast<const netclass_t*>(t)) return false;
      if (t->base_type() != IVL_VT_BOOL && t->base_type() != IVL_VT_LOGIC)
            return false;
      long w = t->packed_width();
      if (w <= 0 || (w % 8) != 0) return false;
      if (wid_out) *wid_out = (unsigned)w;
      return true;
}

// Chapter-11 closure: streaming concat with darray operand → byte queue.
// `pkt = {<<8 {hdr, len, crc, data}}` where data is a byte darray.  The
// streaming-concat width is unknown at elaboration time (darrays size at
// runtime), so the standard NetEConcat-of-NetESelect lowering produces
// wrong widths.  Instead, lower to a procedural NetBlock that pushes
// bytes one at a time:
//   pkt = empty
//   for each operand from RIGHT to LEFT (LSB position first):
//     if darray of byte: push darray[size-1], darray[size-2], ..., darray[0]
//     if fixed-width vec: push byte 0, byte 1, ..., byte N-1
static const netdarray_t* operand_byte_darray_(Design*des, NetScope*scope,
                                                PExpr*op)
{
      const PEIdent*id = dynamic_cast<const PEIdent*>(op);
      if (!id) return nullptr;
      symbol_search_results sr;
      if (!symbol_search(id, des, scope, id->path(),
                         id->lexical_pos(), &sr))
            return nullptr;
      if (!sr.net) return nullptr;
      ivl_type_t t = sr.net->net_type();
      const netdarray_t*da = dynamic_cast<const netdarray_t*>(t);
      if (!da) return nullptr;
      ivl_type_t et = da->element_type();
      if (!et) return nullptr;
      if (et->base_type() != IVL_VT_BOOL && et->base_type() != IVL_VT_LOGIC)
            return nullptr;
      long w = et->packed_width();
      if (w != 8) return nullptr;  // byte-element darrays only for chapter-11
      return da;
}

static NetProc* build_stream_pack_to_byte_queue_(Design*des, NetScope*scope,
                                                  NetAssign_*lv,
                                                  const PEStreaming*stream,
                                                  const PEConcat*inner,
                                                  const LineInfo&loc)
{
      if (!lv || !stream || !inner) return nullptr;
      if (stream->get_dir() != PEStreaming::DIR_LSHIFT) return nullptr;
      unsigned slice = stream->get_slice();
      if (slice != 8) return nullptr;

      const netqueue_t*lvq = dynamic_cast<const netqueue_t*>(lv->net_type());
      if (!lvq) return nullptr;
      ivl_type_t elt = lvq->element_type();
      if (!elt) return nullptr;
      if (elt->base_type() != IVL_VT_BOOL && elt->base_type() != IVL_VT_LOGIC)
            return nullptr;
      if (elt->packed_width() != 8) return nullptr;

      const std::vector<PExpr*>&ops = inner->parms();
      if (ops.empty()) return nullptr;

      // Need at least one byte-darray operand; otherwise the existing
      // fixed-width vec→queue path handles the case correctly.
      bool has_darray = false;
      for (PExpr*op : ops) {
            if (operand_byte_darray_(des, scope, op)) {
                  has_darray = true;
                  break;
            }
      }
      if (!has_darray) return nullptr;

      NetNet*tgt_sig = lv->sig();
      if (!tgt_sig) return nullptr;

      NetBlock*blk = new NetBlock(NetBlock::SEQU, 0);
      blk->set_line(loc);

      // Step 1: clear the queue via $ivl_q_clear system task.
      {
            std::vector<NetExpr*> argv;
            NetESignal*qsig = new NetESignal(tgt_sig);
            qsig->set_line(loc);
            argv.push_back(qsig);
            NetSTask*clear = new NetSTask("$ivl_q_clear",
                                          IVL_SFUNC_AS_TASK_IGNORE, argv);
            clear->set_line(loc);
            blk->append(clear);
      }

      // Step 2: for each operand from RIGHT to LEFT (LSB first):
      for (size_t k = ops.size(); k > 0; k--) {
            PExpr*op = ops[k-1];
            const netdarray_t*opda = operand_byte_darray_(des, scope, op);
            if (opda) {
                  // Darray of bytes: push darray[size-1..0] via system task.
                  NetExpr*op_expr = op->elaborate_expr(des, scope,
                                                       (ivl_type_t)opda,
                                                       PExpr::NO_FLAGS);
                  if (!op_expr) {
                        delete blk;
                        return nullptr;
                  }
                  std::vector<NetExpr*> argv;
                  NetESignal*qsig = new NetESignal(tgt_sig);
                  qsig->set_line(loc);
                  argv.push_back(qsig);
                  argv.push_back(op_expr);
                  NetSTask*pack = new NetSTask("$ivl_q_pack_dar_byte",
                                               IVL_SFUNC_AS_TASK_IGNORE, argv);
                  pack->set_line(loc);
                  blk->append(pack);
            } else {
                  // Fixed-width operand: emit byte-by-byte push_back via
                  // $ivl_queue_method$push_back with NetESelect for each byte.
                  PExpr::width_mode_t m = PExpr::SIZED;
                  unsigned w = op->test_width(des, scope, m);
                  if (w == 0 || (w % 8) != 0) {
                        cerr << loc.get_fileline() << ": sorry: streaming "
                             << "concat operand width " << w
                             << " not a byte multiple."
                             << endl;
                        des->errors += 1;
                        delete blk;
                        return nullptr;
                  }
                  unsigned nbytes = w / 8;
                  NetExpr*body = op->elaborate_expr(des, scope, w, PExpr::NO_FLAGS);
                  if (!body) {
                        delete blk;
                        return nullptr;
                  }
                  for (unsigned j = 0; j < nbytes; j++) {
                        NetExpr*body_dup = body->dup_expr();
                        NetEConst*idxe = new NetEConst(verinum((uint64_t)(j*8), 32u));
                        idxe->set_line(loc);
                        NetESelect*sel = new NetESelect(body_dup, idxe, 8);
                        sel->set_line(loc);
                        std::vector<NetExpr*> argv;
                        NetESignal*qsig = new NetESignal(tgt_sig);
                        qsig->set_line(loc);
                        argv.push_back(qsig);
                        argv.push_back(sel);
                        NetSTask*push = new NetSTask("$ivl_queue_method$push_back",
                                                     IVL_SFUNC_AS_TASK_IGNORE,
                                                     argv);
                        push->set_line(loc);
                        blk->append(push);
                  }
                  delete body;
            }
      }

      return blk;
}

NetProc* PAssign::elaborate(Design*des, NetScope*scope) const
{
      ivl_assert(*this, scope);

	/* If this is a compressed assignment, then handle the
	   elaboration in a specialized function. */
      if (op_ != 0)
	    return elaborate_compressed_(des, scope);

        // SV/UVM compile-progress fallback: class members declared as named
        // events ("event m_event;") resolve as NetEvent objects, but there is
        // no procedural event-handle l-value assignment path yet. Ignore plain
        // assignments to named events in class methods to allow UVM event-base
        // helpers (reset/do_copy) to elaborate further.
      if (gn_system_verilog() && delay_ == 0 && event_ == 0 && count_ == 0) {
	    if (find_class_containing_scope(*this, scope) != 0) {
		  if (const PEIdent*id_lval = dynamic_cast<const PEIdent*>(lval())) {
			symbol_search_results sr;
			if (symbol_search(this, des, scope, id_lval->path(),
					  id_lval->lexical_pos(), &sr)
			    && sr.eve != 0 && sr.net == 0 && sr.path_tail.empty()) {
			      NetBlock*noop = new NetBlock(NetBlock::SEQU, 0);
			      noop->set_line(*this);
			      return noop;
			}
		  }
	    }
      }

	/* elaborate the lval. This detects any part selects and mux
	   expressions that might exist. */
      NetAssign_*lv = elaborate_lval(des, scope);
      if (lv == 0) return 0;

      if (scope->program_block() && lval_not_program_variable(lv)) {
	    cerr << get_fileline() << ": warning: Program blocking "
	            "assignments are not currently scheduled in the "
	            "Reactive region."
	         << endl;
      }

	/* If there is an internal delay expression, elaborate it. */
      NetExpr*delay = 0;
      if (delay_ != 0)
	    delay = elaborate_delay_expr(delay_, des, scope);

      NetExpr*rv;
      const ivl_type_s*lv_net_type = lv->net_type();

      if (debug_elaborate) {
	    cerr << get_fileline() << ": PAssign::elaborate: ";
	    if (lv_net_type)
		  cerr << "lv_net_type=" << *lv_net_type << endl;
	    else
		  cerr << "lv_net_type=<nil>" << endl;
      }

	// Chapter-11 closure: detect `<byte_queue> = {<<8 {..., <byte_darray>, ...}}`
	// and lower to a procedural NetBlock that pushes bytes one at a time.
	// The standard NetEConcat-of-NetESelect lowering produces wrong widths
	// because PEIdent::test_width returns 1 for darray references.
      if (!delay && !event_ && !count_) {
	    if (dynamic_cast<const netqueue_t*>(lv_net_type)) {
		  if (PEStreaming*pst = dynamic_cast<PEStreaming*>(rval())) {
			if (PEConcat*pinner = dynamic_cast<PEConcat*>(pst->get_inner())) {
			      NetProc*p = build_stream_pack_to_byte_queue_(
					des, scope, lv, pst, pinner, *this);
			      if (p) return p;
			}
		  }
	    }
      }

	// Chapter-11 LHS closure: detect `{ops..., <byte_darray>} = {<<8 {<byte_queue>}}`
	// (the parse-time rewrite for `{<<8 {ops..., darray}} = pkt`).  The fixed
	// LHS multi-lval path can't handle a darray element, so lower the whole
	// statement to a $ivl_q_unpack_byte_dar_ops system task that codegen
	// expands to a runtime byte unpacking sequence.
      if (!delay && !event_ && !count_) {
	    if (const PEConcat*lhs_concat = dynamic_cast<const PEConcat*>(lval())) {
		  if (PEStreaming*pst = dynamic_cast<PEStreaming*>(rval())) {
			NetProc*p = build_stream_unpack_byte_queue_(
				  des, scope, lhs_concat, pst, *this);
			if (p) {
			      delete lv;
			      return p;
			}
		  }
	    }
      }

	/* If the l-value is a compound type of some sort, then use
	   the newer net_type form of the elaborate_rval_ method to
	   handle the new types. */
      if (dynamic_cast<const netclass_t*> (lv_net_type)) {
	    ivl_assert(*this, lv->more==0);
	    rv = elaborate_rval_(des, scope, lv_net_type);

      } else if (dynamic_cast<const netdarray_t*> (lv_net_type)) {
	    ivl_assert(*this, lv->more==0);
	    if (debug_elaborate) {
		  if (lv->word())
			cerr << get_fileline() << ": PAssign::elaborate: "
			     << "lv->word() = " << *lv->word() << endl;
		  else
			cerr << get_fileline() << ": PAssign::elaborate: "
			     << "lv->word() = <nil>" << endl;
	    }
	    // C3 (Phase 62n): NetAssign_::net_type() already accounts for
	    // lv->word() by unwrapping one layer of darray/queue/uarray
	    // when an assoc/queue index is present.  Stripping again here
	    // turns `assoc[K] = inner_queue` into `assoc-elem.elem = ...`
	    // which mismatches and gets degraded to NetENull during the
	    // class-cast fallback in elab_and_eval.  Leave use_lv_type
	    // as net_type() returned it.
	    rv = elaborate_rval_(des, scope, lv_net_type);

      } else if (dynamic_cast<const netuarray_t*>(lv_net_type)) {
	    ivl_assert(*this, lv->more==0);
	    if (debug_elaborate) {
		  if (lv->word())
			cerr << get_fileline() << ": PAssign::elaborate: "
			     << "lv->word() = " << *lv->word() << endl;
		  else
			cerr << get_fileline() << ": PAssign::elaborate: "
			     << "lv->word() = <nil>" << endl;
	    }
	    // Same C3 reasoning as above for netuarray l-values.
	    ivl_assert(*this, lv_net_type);
	    rv = elaborate_rval_(des, scope, lv_net_type);

      } else {
	      /* Elaborate the r-value expression, then try to evaluate it. */
	    rv = elaborate_rval_(des, scope, lv_net_type, lv->expr_type(), count_lval_width(lv));
      }

      if (rv == 0) {
	    delete lv;
	    return 0;
      }
      ivl_assert(*this, rv);

      if (count_) ivl_assert(*this, event_);

	/* Rewrite delayed assignments as assignments that are
	   delayed. For example, a = #<d> b; becomes:

	     begin
	        tmp = b;
		#<d> a = tmp;
	     end

	   If the delay is an event delay, then the transform is
	   similar, with the event delay replacing the time delay. It
	   is an event delay if the event_ member has a value.

	   This rewriting of the expression allows me to not bother to
	   actually and literally represent the delayed assign in the
	   netlist. The compound statement is exactly equivalent. */

      if (delay || event_) {
	    unsigned wid = count_lval_width(lv);

	    const netvector_t*tmp2_vec = new netvector_t(rv->expr_type(),wid-1,0);
	    NetNet*tmp = new NetNet(scope, scope->local_symbol(),
				    NetNet::REG, tmp2_vec);
	    tmp->local_flag(true);
	    tmp->set_line(*this);

	    NetESignal*sig = new NetESignal(tmp);

	      /* Generate an assignment of the l-value to the temporary... */
	    NetAssign_*lvt = new NetAssign_(tmp);

	    NetAssign*a1 = new NetAssign(lvt, rv);
	    a1->set_line(*this);

	      /* Generate an assignment of the temporary to the r-value... */
	    NetAssign*a2 = new NetAssign(lv, sig);
	    a2->set_line(*this);

	      /* Generate the delay statement with the final
		 assignment attached to it. If this is an event delay,
		 elaborate the PEventStatement. Otherwise, create the
		 right NetPDelay object. For a repeat event control
		 repeat the event and then do the final assignment.  */
	    NetProc*st;
	    if (event_) {
		  if (count_) {
			NetExpr*count = elab_and_eval(des, scope, count_, -1);
			if (count == 0) {
			      cerr << get_fileline() << ": Unable to "
			              "elaborate repeat expression." << endl;
			      des->errors += 1;
			      return 0;
			}
			st = event_->elaborate(des, scope);
			if (st == 0) {
			      cerr << event_->get_fileline() << ": error: "
			              "unable to elaborate event expression."
			      << endl;
			      des->errors += 1;
			      return 0;
			}
			st->set_line(*this);

			  // If the expression is a constant, handle
			  // certain special iteration counts.
			if (const NetEConst*ce = dynamic_cast<NetEConst*>(count)) {
			      long val = ce->value().as_long();
				// We only need the real statement.
			      if (val <= 0) {
				    delete count;
				    delete st;
				    st = 0;

				// We don't need the repeat statement.
			      } else if (val == 1) {
				    delete count;

				// We need a repeat statement.
			      } else {
				    st = new NetRepeat(count, st);
				    st->set_line(*this);
			      }
			} else {
			      st = new NetRepeat(count, st);
			      st->set_line(*this);
			}
		  } else {
			st = event_->elaborate_st(des, scope, a2);
			if (st == 0) {
			      cerr << event_->get_fileline() << ": error: "
			              "unable to elaborate event expression."
			      << endl;
			      des->errors += 1;
			      return 0;
			}
			st->set_line(*this);
		  }
	    } else {
		  NetPDelay*de = new NetPDelay(delay, a2);
		  de->set_line(*this);
		  st = de;
	    }

	      /* And build up the complex statement. */
	    NetBlock*bl = new NetBlock(NetBlock::SEQU, 0);
	    bl->append(a1);
	    if (st) bl->append(st);
	    if (count_) bl->append(a2);
	    bl->set_line(*this);

	    return bl;
      }

      // SV §7.6: B = A where both B and A are static unpacked arrays
      // (netuarray_t) and no element index on either side.  tgt-vvp cannot
      // handle a direct whole-array NetAssign; expand into N element-wise
      // copies.  Declaration-order copy: position i of A → position i of B,
      // where position counts from MSB end of the declared range.  This
      // matches the SV spec behavior for arrays with different index
      // orientations (e.g., int B[0:3] = A[3:0]).
      if (!delay && !event_
	  && dynamic_cast<const netuarray_t*>(lv_net_type)
	  && lv->word() == nullptr) {
	    if (const NetESignal*rsig = dynamic_cast<const NetESignal*>(rv)) {
		  NetNet*rnet = const_cast<NetNet*>(rsig->sig());
		  NetNet*lnet = lv->sig();
		  if (rnet && lnet
		      && rnet->unpacked_dimensions() > 0
		      && lnet->unpacked_dimensions() > 0) {
		        const netranges_t&dims_lv = lnet->unpacked_dims();
		        const netranges_t&dims_rv = rnet->unpacked_dims();
		        long N = dims_lv[0].width();
		        long msb_lv = dims_lv[0].get_msb(), lsb_lv = dims_lv[0].get_lsb();
		        long msb_rv = dims_rv[0].get_msb(), lsb_rv = dims_rv[0].get_lsb();
		        NetBlock*bl = new NetBlock(NetBlock::SEQU, 0);
		        bl->set_line(*this);
		        for (long pos = 0; pos < N; pos++) {
			      long canon_lv = (msb_lv >= lsb_lv) ? (N-1-pos) : pos;
			      long canon_rv = (msb_rv >= lsb_rv) ? (N-1-pos) : pos;
			      NetEConst*li = new NetEConst(verinum(canon_lv));
			      li->set_line(*this);
			      NetEConst*ri = new NetEConst(verinum(canon_rv));
			      ri->set_line(*this);
			      NetAssign_*elv = new NetAssign_(lnet);
			      elv->set_word(li);
			      NetESignal*erv = new NetESignal(rnet, ri);
			      erv->set_line(*this);
			      NetAssign*ea = new NetAssign(elv, erv);
			      ea->set_line(*this);
			      bl->append(ea);
		        }
		        delete lv;
		        delete rv;
		        return bl;
		  }
	    }
      }

      NetAssign*cur = new NetAssign(lv, rv);
      cur->set_line(*this);

      /* Phase 63b/B7: tagged-union write — also update companion tag. */
      if (NetProc*tag_set = build_tagged_union_companion_set_(des, scope,
                                                              lv, this)) {
            NetBlock*blk = new NetBlock(NetBlock::SEQU, 0);
            blk->set_line(*this);
            blk->append(cur);
            blk->append(tag_set);
            return blk;
      }

      return cur;
}

/*
 * Elaborate non-blocking assignments. The statement is of the general
 * form:
 *
 *    <lval> <= #<delay> <rval> ;
 */
NetProc* PAssignNB::elaborate(Design*des, NetScope*scope) const
{
      ivl_assert(*this, scope);

      if (scope->in_func()) {
	    if (gn_system_verilog()) {
		  // SV compile-progress: some tools allow non-blocking assignments
		  // in functions for interface signal driving. Treat as blocking.
		  cerr << get_fileline() << ": warning: non-blocking assignment in "
			  "function (compile-progress: treated as blocking)." << endl;
		  // Actually elaborate as blocking assignment to avoid NB-in-function assert.
		  NetAssign_*lv_blk = elaborate_lval(des, scope);
		  if (lv_blk == 0) return 0;
		  NetExpr*rv_blk = elaborate_rval_(des, scope, lv_blk->net_type(),
						   lv_blk->expr_type(),
						   count_lval_width(lv_blk));
		  if (rv_blk == 0) return 0;
		  NetAssign*cur_blk = new NetAssign(lv_blk, rv_blk);
		  cur_blk->set_line(*this);
		  return cur_blk;
	    } else {
		  cerr << get_fileline() << ": error: functions cannot have non "
			  "blocking assignment statements." << endl;
		  des->errors += 1;
		  return 0;
	    }
      }

      if (scope->in_final()) {
	    cerr << get_fileline() << ": error: final procedures cannot have "
		    "non blocking assignment statements." << endl;
	    des->errors += 1;
	    return 0;
      }

      if (scope->is_auto() && lval()->has_aa_term(des, scope)) {
	    cerr << get_fileline() << ": error: automatically allocated "
                    "variables may not be assigned values using non-blocking "
	            "assignments." << endl;
	    des->errors += 1;
	    return 0;
      }

	/* Elaborate the l-value. */
      NetAssign_*lv = elaborate_lval(des, scope);
      if (lv == 0) return 0;

      if (scope->program_block() && lval_not_program_variable(lv)) {
	    cerr << get_fileline() << ": warning: Program non-blocking "
	            "assignments are not currently scheduled in the "
	            "Reactive-NBA region."
	         << endl;
      }

      NetExpr*rv = elaborate_rval_(des, scope, lv->net_type(), lv->expr_type(), count_lval_width(lv));
      if (rv == 0) return 0;

      NetExpr*delay = 0;
      if (delay_ != 0) {
	    ivl_assert(*this, count_ == 0 && event_ == 0);
	    delay = elaborate_delay_expr(delay_, des, scope);
      }

      NetExpr*count = 0;
      NetEvWait*event = 0;
      if (count_ != 0 || event_ != 0) {
	    if (count_ != 0) {
                  if (scope->is_auto() && count_->has_aa_term(des, scope)) {
                        cerr << get_fileline() << ": error: automatically "
                                "allocated variables may not be referenced "
                                "in intra-assignment event controls of "
                                "non-blocking assignments." << endl;
                        des->errors += 1;
                        return 0;
                  }

		  ivl_assert(*this, event_ != 0);
		  count = elab_and_eval(des, scope, count_, -1);
		  if (count == 0) {
			cerr << get_fileline() << ": Unable to elaborate "
			        "repeat expression." << endl;
			des->errors += 1;
			return 0;
		  }
	    }

            if (scope->is_auto() && event_->has_aa_term(des, scope)) {
                  cerr << get_fileline() << ": error: automatically "
                          "allocated variables may not be referenced "
                          "in intra-assignment event controls of "
                          "non-blocking assignments." << endl;
                  des->errors += 1;
                  return 0;
            }

	    NetProc*st = event_->elaborate(des, scope);
	    if (st == 0) {
		  cerr << get_fileline() << ": unable to elaborate "
		          "event expression." << endl;
		  des->errors += 1;
		  return 0;
	    }
	    event = dynamic_cast<NetEvWait*>(st) ;
	    ivl_assert(*this, event);

	      // Some constant values are special.
	    if (const NetEConst*ce = dynamic_cast<NetEConst*>(count)) {
		  long val = ce->value().as_long();
		    // We only need the assignment statement.
		  if (val <= 0) {
			delete count;
			delete event;
			count = 0;
			event = 0;
		    // We only need the event.
		  } else if (val == 1) {
			delete count;
			count = 0;
		  }
	    }
      }

	/* All done with this node. Mark its line number and check it in. */
      NetAssignNB*cur = new NetAssignNB(lv, rv, event, count);
      cur->set_delay(delay);
      cur->set_line(*this);
      return cur;
}


/*
 * This is the elaboration method for a begin-end block. Try to
 * elaborate the entire block, even if it fails somewhere. This way I
 * get all the error messages out of it. Then, if I detected a failure
 * then pass the failure up.
 */
NetProc* PBlock::elaborate(Design*des, NetScope*scope) const
{
      ivl_assert(*this, scope);

      NetBlock::Type type;
      switch (bl_type_) {
	  case PBlock::BL_SEQ:
	    type = NetBlock::SEQU;
	    break;
	  case PBlock::BL_PAR:
	    type = NetBlock::PARA;
	    break;
	  case PBlock::BL_JOIN_NONE:
	    type = NetBlock::PARA_JOIN_NONE;
	    break;
	  case PBlock::BL_JOIN_ANY:
	    type = NetBlock::PARA_JOIN_ANY;
	    break;
	    // Added to remove a "type" uninitialized compiler warning.
	    // This should never be reached since all the PBlock enumeration
	    // cases are handled above.
	  default:
	    type = NetBlock::SEQU;
	    ivl_assert(*this, 0);
      }

      NetScope*nscope = 0;
      if (pscope_name() != 0) {
	    nscope = scope->child(hname_t(pscope_name()));
	    if (nscope == 0) {
		  cerr << get_fileline() << ": internal error: "
			"unable to find block scope " << scope_path(scope)
		       << "." << pscope_name() << endl;
		  des->errors += 1;
		  return 0;
	    }
	    ivl_assert(*this, nscope);
      }

      NetBlock*cur = new NetBlock(type, nscope);
      NetBlock*prefix = 0;

      if (nscope) {
	      // Handle any variable initialization statements in this scope.
	      // For automatic scopes, stage a fresh activation frame before
	      // any block-entry initializers run, then free it after the
	      // block finishes. This covers automatic named begin/fork blocks
	      // in the same way automatic task calls use %alloc/%free around
	      // input setup and execution.
	    if (nscope->is_auto()) {
		  prefix = new NetBlock(NetBlock::SEQU, 0);
		  NetAlloc*ap = new NetAlloc(nscope);
		  ap->set_line(*this);
		  prefix->append(ap);

		  NetBlock*init_block = prefix;
		  for (unsigned idx = 0; idx < var_inits.size(); idx += 1) {
			NetProc*tmp = var_inits[idx]->elaborate(des, nscope);
			if (tmp) init_block->append(tmp);
		  }
	    } else {
		  elaborate_var_inits_(des, nscope);
	    }
      }

      if (nscope == 0)
	    nscope = scope;

	// Handle the special case that the sequential block contains
	// only one statement. There is no need to keep the block node.
	// Also, don't elide named blocks, because they might be
	// referenced elsewhere.
      if ((type == NetBlock::SEQU) && (list_.size() == 1) &&
          (pscope_name() == 0)) {
	    ivl_assert(*this, list_[0]);
	    NetProc*tmp = list_[0]->elaborate(des, nscope);
	    return tmp;
      }

      if (type != NetBlock::SEQU)
	    des->fork_enter();

      for (unsigned idx = 0 ;  idx < list_.size() ;  idx += 1) {
	    ivl_assert(*this, list_[idx]);

	      // Detect the error that a super.new() statement is in the
	      // midst of a block. Report the error. Continue on with the
	      // elaboration so that other errors might be found.
	    if (const PChainConstructor*supernew = dynamic_cast<PChainConstructor*> (list_[idx])) {
	          if (debug_elaborate) {
		        cerr << get_fileline() << ": PBlock::elaborate: "
			     << "Found super.new statement, idx=" << idx << ", "
			     << " at " << supernew->get_fileline() << "."
			     << endl;
		  }
		  if (idx > 0) {
		        des->errors += 1;
			cerr << supernew->get_fileline() << ": error: "
			     << "super.new(...) must be the first statement in a block."
			     << endl;
		  }
	    }

	    NetProc*tmp = list_[idx]->elaborate(des, nscope);
	      // If the statement fails to elaborate, then simply
	      // ignore it. Presumably, the elaborate for the
	      // statement already generated an error message and
	      // marked the error count in the design so no need to
	      // do any of that here.
	    if (tmp == 0) {
		  continue;
	    }

	      // If the result turns out to be a noop, then skip it.
	    if (NetBlock*tbl = dynamic_cast<NetBlock*>(tmp))
		  if (tbl->proc_first() == 0) {
			delete tbl;
			continue;
		  }

	    cur->append(tmp);
      }

      if (type != NetBlock::SEQU)
	    des->fork_exit();

	// Update flags in parent scope.
      if (!nscope->is_const_func())
	    scope->is_const_func(false);
      if (nscope->calls_sys_task())
	    scope->calls_sys_task(true);

      cur->set_line(*this);
      if (prefix) {
	    prefix->set_line(*this);
	    if (cur->proc_first())
		  prefix->append(cur);
	    else
		  delete cur;
	    NetFree*fp = new NetFree(nscope);
	    fp->set_line(*this);
	    prefix->append(fp);
	    return prefix;
      }
      return cur;
}

NetProc* PBreak::elaborate(Design*des, NetScope*) const
{
      if (!gn_system_verilog()) {
	    cerr << get_fileline() << ": error: "
		<< "'break' jump statement requires SystemVerilog." << endl;
	    des->errors += 1;
	    return nullptr;
      }


      NetBreak*res = new NetBreak;
      res->set_line(*this);
      return res;
}

static int test_case_width(Design*des, NetScope*scope, PExpr*pe,
			   PExpr::width_mode_t&mode)
{
      unsigned expr_width = pe->test_width(des, scope, mode);
      if (debug_elaborate) {
	    cerr << pe->get_fileline() << ": debug: test_width "
		 << "of case expression " << *pe
		 << endl;
	    cerr << pe->get_fileline() << ":        "
		 << "returns type=" << pe->expr_type()
		 << ", width="      << expr_width
		 << ", signed="     << pe->has_sign()
		 << ", mode="       << PExpr::width_mode_name(mode)
		 << endl;
      }
      return expr_width;
}

static NetExpr*elab_and_eval_case(Design*des, NetScope*scope, PExpr*pe,
				  bool context_is_real, bool context_unsigned,
				  unsigned context_width)
{
      if (context_unsigned)
	    pe->cast_signed(false);

      unsigned width = context_is_real ? pe->expr_width() : context_width;
      NetExpr*expr = pe->elaborate_expr(des, scope, width, PExpr::NO_FLAGS);
      if (expr == 0) return 0;

      if (context_is_real)
	    expr = cast_to_real(expr);

      eval_expr(expr, context_width);

      return expr;
}

/* Phase 63b/B7 (gap close): elaborate `case (X) matches` for tagged
 * unions.  Lower to an if-else cascade testing the companion-tag
 * NetNet of X.  Each tagged item generates:
 *   if (X__tag_companion == TAG_INDEX) { /bind/; stmt; }
 * Default item is the final else branch.
 *
 * The expr_ must elaborate to a NetESignal of a tagged-union typed
 * NetNet so we can find the companion via name convention.  If not,
 * we emit a warning and degrade to a sequential block (each branch
 * runs in order; first wins). */
NetProc* PCaseMatches::elaborate(Design*des, NetScope*scope) const
{
      ivl_assert(*this, scope);
      if (!expr_) return new NetBlock(NetBlock::SEQU, 0);

      /* Resolve expr_ to a NetNet so we can find its companion.
         Handle the common case where expr_ is a simple PEIdent. */
      NetNet*u_sig = nullptr;
      const netstruct_t*nst = nullptr;
      if (const PEIdent*id = dynamic_cast<const PEIdent*>(expr_)) {
            symbol_search_results sr;
            if (symbol_search(this, des, scope, id->path(),
                              id->lexical_pos(), &sr)) {
                  u_sig = sr.net;
            }
      }
      if (u_sig)
            nst = dynamic_cast<const netstruct_t*>(u_sig->net_type());

      if (!u_sig || !nst || !nst->tagged_flag()) {
            cerr << get_fileline() << ": warning: case-matches expression "
                 << "is not a tagged-union variable; degrading to "
                 << "sequential dispatch (first matching branch wins)."
                 << endl;
            NetBlock*blk = new NetBlock(NetBlock::SEQU, 0);
            blk->set_line(*this);
            if (items_ && !items_->empty()) {
                  Item*first = items_->front();
                  if (first && first->stat) {
                        if (NetProc*s = first->stat->elaborate(des, scope))
                              blk->append(s);
                  }
            }
            return blk;
      }

      /* Find the companion NetNet. */
      perm_string companion_name =
            lex_strings.make(string(u_sig->name().str()) + "__tag_companion");
      NetScope*decl_scope = u_sig->scope() ? u_sig->scope() : scope;
      NetNet*companion = decl_scope->find_signal(companion_name);
      if (!companion) {
            cerr << get_fileline() << ": warning: case-matches: tagged-union "
                 << "companion not found for `" << u_sig->name() << "'."
                 << endl;
            return new NetBlock(NetBlock::SEQU, 0);
      }

      /* Build the if-else cascade from the bottom up.  Default first
         (becomes else of the final if); each tagged branch wraps it. */
      NetProc*cascade = nullptr;
      Item*default_item = nullptr;
      if (items_) {
            for (auto*it : *items_)
                  if (it && it->is_default) { default_item = it; break; }
      }
      if (default_item && default_item->stat)
            cascade = default_item->stat->elaborate(des, scope);

      if (items_) {
            /* Walk in reverse so the first item ends up at the top of
               the cascade. */
            for (auto rit = items_->rbegin(); rit != items_->rend(); ++rit) {
                  Item*it = *rit;
                  if (!it || it->is_default) continue;
                  unsigned tidx = nst->member_index(it->tag);
                  if (tidx == (unsigned)-1) {
                        cerr << get_fileline() << ": warning: case-matches: "
                             << "tag `" << it->tag.str() << "' not a member "
                             << "of tagged union `" << u_sig->name() << "'; "
                             << "branch dropped." << endl;
                        continue;
                  }
                  /* Build: companion == tidx */
                  NetESignal*comp_e = new NetESignal(companion);
                  comp_e->set_line(*this);
                  verinum vi((uint64_t)tidx, 32);
                  NetEConst*idx_e = new NetEConst(vi);
                  idx_e->set_line(*this);
                  NetEBComp*cmp = new NetEBComp('e', comp_e, idx_e);
                  cmp->set_line(*this);

                  /* Body: optional binding then stmt. */
                  NetProc*body = it->stat ? it->stat->elaborate(des, scope) : nullptr;
                  if (it->bind != perm_string()) {
                        /* `tagged TAG .var: stmt` — assign .var = u.
                           The user must have declared `.var` as a regular
                           variable in scope before the case-matches; we
                           look it up and emit a NetAssign that copies the
                           tagged-union storage into it.  Since union
                           members share storage, reading u and writing
                           the bind var gives the value that was last
                           written via tagged TAG (in the ordinary sense
                           of union semantics, with the tag-companion
                           protecting against cross-tag reads). */
                        /* Look up the binding by walking enclosing
                           scopes manually — symbol_search uses the
                           PExpr's lexical position, but case-matches
                           items are anonymous statements without
                           lexical context. */
                        NetNet*bind_net = nullptr;
                        for (NetScope*s = scope; s != nullptr; s = s->parent()) {
                              if (NetNet*n = s->find_signal(it->bind)) {
                                    bind_net = n; break;
                              }
                        }
                        if (!bind_net) {
                              cerr << get_fileline() << ": warning: case-matches "
                                   << "binding `." << it->bind.str()
                                   << "': no variable named `" << it->bind.str()
                                   << "' found in scope; binding skipped." << endl;
                        } else {
                              /* Build: bind_net = u (with implicit
                                 width adjust). */
                              NetAssign_*bind_lv = new NetAssign_(bind_net);
                              NetESignal*u_e = new NetESignal(u_sig);
                              u_e->set_line(*this);
                              NetAssign*bind_as = new NetAssign(bind_lv, u_e);
                              bind_as->set_line(*this);
                              NetBlock*body_blk = new NetBlock(NetBlock::SEQU, 0);
                              body_blk->set_line(*this);
                              body_blk->append(bind_as);
                              if (body) body_blk->append(body);
                              body = body_blk;
                        }
                  }
                  NetCondit*cond = new NetCondit(cmp, body, cascade);
                  cond->set_line(*this);
                  cascade = cond;
            }
      }
      if (!cascade) cascade = new NetBlock(NetBlock::SEQU, 0);
      return cascade;
}

/*
 * Elaborate a case statement.
 */
NetProc* PCase::elaborate(Design*des, NetScope*scope) const
{
      ivl_assert(*this, scope);

	/* The type of the case expression and case item expressions is
	   determined according to the following rules:

	    - if any of the expressions is real, all the expressions are
	      evaluated as real (non-real expressions will be treated as
	      self-determined, then converted to real)

	    - otherwise if any of the expressions is unsigned, all the
	      expressions are evaluated as unsigned

	    - otherwise all the expressions are evaluated as signed

	   If the type is not real, the bit width is determined by the
	   largest self-determined width of any of the expressions. */

      PExpr::width_mode_t context_mode = PExpr::SIZED;
      unsigned context_width = test_case_width(des, scope, expr_, context_mode);
      bool context_is_real = (expr_->expr_type() == IVL_VT_REAL);
      bool context_unsigned = !expr_->has_sign();

      for (unsigned idx = 0; idx < items_->size(); idx += 1) {

	    PCase::Item*cur = (*items_)[idx];

	    for (list<PExpr*>::iterator idx_expr = cur->expr.begin()
		 ; idx_expr != cur->expr.end() ; ++idx_expr) {

		  PExpr*cur_expr = *idx_expr;
		  ivl_assert(*this, cur_expr);

		  PExpr::width_mode_t cur_mode = PExpr::SIZED;
		  unsigned cur_width = test_case_width(des, scope, cur_expr,
						       cur_mode);
		  if (cur_mode > context_mode)
			context_mode = cur_mode;
		  if (cur_width > context_width)
			context_width = cur_width;
		  if (cur_expr->expr_type() == IVL_VT_REAL)
			context_is_real = true;
		  if (!cur_expr->has_sign())
			context_unsigned = true;
	    }
      }

      if (context_is_real) {
	    context_width = 1;
	    context_unsigned = false;

      } else if (context_mode >= PExpr::LOSSLESS) {

	      /* Expressions may choose a different size if they are
		 in a lossless context, so we need to run through the
		 process again to get the final expression width. */

	    context_width = test_case_width(des, scope, expr_, context_mode);

	    for (unsigned idx = 0; idx < items_->size(); idx += 1) {

		  PCase::Item*cur = (*items_)[idx];

		  for (list<PExpr*>::iterator idx_expr = cur->expr.begin()
		       ; idx_expr != cur->expr.end() ; ++idx_expr) {

			PExpr*cur_expr = *idx_expr;
			ivl_assert(*this, cur_expr);

			unsigned cur_width = test_case_width(des, scope, cur_expr,
							     context_mode);
			if (cur_width > context_width)
			      context_width = cur_width;
		  }
	    }

	    if (context_width < integer_width)
		  context_width += 1;
      }

      if (debug_elaborate) {
	    cerr << get_fileline() << ": debug: case context is ";
	    if (context_is_real) {
		  cerr << "real" << endl;
	    } else {
		  cerr << (context_unsigned ? "unsigned" : "signed")
		       << " vector, width=" << context_width << endl;
	    }
      }
      NetExpr*expr = elab_and_eval_case(des, scope, expr_,
					context_is_real,
					context_unsigned,
					context_width);
      if (expr == 0) {
	    cerr << get_fileline() << ": error: Unable to elaborate this case"
		  " expression." << endl;
	    return 0;
      }

	/* Count the items in the case statement. Note that there may
	   be some cases that have multiple guards. Count each as a
	   separate item. */
      unsigned icount = 0;
      for (unsigned idx = 0 ;  idx < items_->size() ;  idx += 1) {
	    PCase::Item*cur = (*items_)[idx];

	    if (cur->expr.empty())
		  icount += 1;
	    else
		  icount += cur->expr.size();
      }

      NetCase*res = new NetCase(quality_, type_, expr, icount);
      res->set_line(*this);

	/* Iterate over all the case items (guard/statement pairs)
	   elaborating them. If the guard has no expression, then this
	   is a "default" case. Otherwise, the guard has one or more
	   expressions, and each guard is a case. */
      unsigned inum = 0;
      for (unsigned idx = 0 ;  idx < items_->size() ;  idx += 1) {

	    ivl_assert(*this, inum < icount);
	    PCase::Item*cur = (*items_)[idx];

	    if (cur->expr.empty()) {
		    /* If there are no expressions, then this is the
		       default case. */
		  NetProc*st = 0;
		  if (cur->stat)
			st = cur->stat->elaborate(des, scope);

		  res->set_case(inum, 0, st);
		  inum += 1;

	    } else for (list<PExpr*>::iterator idx_expr = cur->expr.begin()
			      ; idx_expr != cur->expr.end() ; ++idx_expr) {

		    /* If there are one or more expressions, then
		       iterate over the guard expressions, elaborating
		       a separate case for each. (Yes, the statement
		       will be elaborated again for each.) */
		  PExpr*cur_expr = *idx_expr;
		  ivl_assert(*this, cur_expr);
		  NetExpr*gu = elab_and_eval_case(des, scope, cur_expr,
						  context_is_real,
						  context_unsigned,
						  context_width);

		  NetProc*st = 0;
		  if (cur->stat)
			st = cur->stat->elaborate(des, scope);

		  res->set_case(inum, gu, st);
		  inum += 1;
	    }
      }

      res->prune();

      return res;
}

NetProc* PChainConstructor::elaborate(Design*des, NetScope*scope) const
{
      ivl_assert(*this, scope);

      if (debug_elaborate) {
	    cerr << get_fileline() << ": PChainConstructor::elaborate: "
		 << "Elaborate constructor chain in scope=" << scope_path(scope) << endl;
      }

	// The scope is the <class>.new function, so scope->parent()
	// is the class. Use that to get the class type that we are
	// constructing.
      const NetScope*scope_class = scope->parent();
      const netclass_t*class_this = scope_class->class_def();
      ivl_assert(*this, class_this);

	// We also need the super-class.
      const netclass_t*class_super = class_this->get_super();
      if (class_super == 0) {
	    cerr << get_fileline() << ": error: "
		 << "Class " << class_this->get_name()
		 << " has no parent class for super.new constructor chaining." << endl;
	    des->errors += 1;
	    NetBlock*tmp = new NetBlock(NetBlock::SEQU, 0);
	    tmp->set_line(*this);
	    return tmp;
      }

	// Need the "this" variable for the current constructor. We're
	// going to pass this to the chained constructor.
      NetNet*var_this = scope->find_signal(perm_string::literal(THIS_TOKEN));
      if (var_this == 0) {
	    const NetFuncDef*cur_def = scope->func_def();
	    if (cur_def == 0) {
		  const PFunction*cur_pfunc = scope->func_pform();
		  if (cur_pfunc)
			elaborate_function_outside_caller_fork_(des, cur_pfunc, scope);
		  cur_def = scope->func_def();
	    }
	    if (cur_def)
		  var_this = const_cast<NetNet*> (cur_def->return_sig());
      }
      if (var_this == 0) {
	    cerr << get_fileline() << ": internal error: constructor "
		 << scope_path(scope)
		 << " has no synthetic \"this\" or constructor return signal for super.new chain."
		 << endl;
	    des->errors += 1;
	    NetBlock*tmp = new NetBlock(NetBlock::SEQU, 0);
	    tmp->set_line(*this);
	    return tmp;
      }

	// If super.new(...) is a user defined constructor, then call
	// it. This is a bit more complicated because there may be arguments.
	      if (NetScope*new_scope = class_super->get_constructor()) {

	    int missing_parms = 0;
		    const NetFuncDef*def = new_scope->func_def();
		    if (def == 0 || def->proc() == 0) {
			  const PFunction*pfunc = new_scope->func_pform();
			  if (pfunc)
				elaborate_function_outside_caller_fork_(des, pfunc, new_scope);
			  def = new_scope->func_def();
		    }
	    if (def == 0) {
		  cerr << get_fileline() << ": internal error: constructor "
		       << scope_path(new_scope)
		       << " is missing definition for super.new chain." << endl;
		  des->errors += 1;
		  NetBlock*tmp = new NetBlock(NetBlock::SEQU, 0);
		  tmp->set_line(*this);
		  return tmp;
	    }

	    unsigned parm_off = 0;
	    if (def->port_count() > 0) {
		  NetNet*port0 = def->port(0);
		  if (port0 && port0->name() == perm_string::literal(THIS_TOKEN))
			parm_off = 1;
	    }

	    if ((parms_.size()+parm_off) > def->port_count()) {
		  cerr << get_fileline() << ": error: Argument count mismatch."
		       << " Passing " << parms_.size() << " arguments"
		       << " to constructor expecting "
		       << (def->port_count()-parm_off)
		       << " arguments." << endl;
		  des->errors += 1;
	    }

	    NetESignal*eres = new NetESignal(var_this);
	    vector<NetExpr*> parms (def->port_count());
	    if (parm_off > 0)
		  parms[0] = eres;

	    auto args = map_named_args(des, def, parms_, parm_off);
	    for (size_t idx = parm_off ; idx < parms.size() ; idx += 1) {
		  if (args[idx - parm_off]) {
			parms[idx] = elaborate_rval_expr(des, scope,
							 def->port(idx)->net_type(),
							 args[idx - parm_off], false);
			continue;
		  }

		  if (const NetExpr*tmp = def->port_defe(idx)) {
			parms[idx] = tmp->dup_expr();
			continue;
		  }

		  missing_parms += 1;
		  parms[idx] = 0;
	    }

	    if (missing_parms) {
		  if (gn_system_verilog()
		      && scope->basename() == perm_string::literal("new@")) {
			// Compile-progress fallback: synthetic implicit constructors
			// (`new@`) are generated before out-of-class constructor
			// bodies and may emit a premature implicit super.new() with no
			// arguments. Skip the synthetic chain and let the explicit
			// out-of-class constructor body elaborate later.
			NetBlock*tmp = new NetBlock(NetBlock::SEQU, 0);
			tmp->set_line(*this);
			return tmp;
		  }
		  if (gn_system_verilog()
		      && scope->basename() == perm_string::literal("new")) {
			if (const PFunction*cur_ctor = scope->func_pform()) {
			      // Another compile-progress case: constructor blending can
			      // attach a synthetic chain call (line at class declaration)
			      // to an extern constructor prototype (line later in class),
			      // before the out-of-class body is elaborated.
			    if (cur_ctor->get_file() == get_file()
				&& get_lineno() > 0 && cur_ctor->get_lineno() > get_lineno()) {
				  NetBlock*tmp = new NetBlock(NetBlock::SEQU, 0);
				  tmp->set_line(*this);
				  return tmp;
			    }
			}
		  }
		  cerr << get_fileline() << ": error: "
		       << "Missing " << missing_parms
		       << " arguments to constructor " << scope_path(new_scope) << "." << endl;
		  des->errors += 1;
	    }

	    NetEUFunc*tmp = new NetEUFunc(scope, new_scope, eres, parms, true, true);
	    tmp->set_line(*this);

	    NetNet*ret_sink = scope->find_signal(scope->basename());
	    if (!ret_sink) {
		  ret_sink = new NetNet(scope, scope->basename(), NetNet::REG,
				        var_this->net_type());
	    }
	    NetAssign_*lval_ret = new NetAssign_(ret_sink);
	    NetAssign*stmt = new NetAssign(lval_ret, tmp);
	    stmt->set_line(*this);

	    // Some constructor definitions arrive without a synthetic "this"
	    // function port in their NetFuncDef. In that case, seed the callee
	    // @ handle explicitly before the call expression.
	    if (parm_off == 0) {
		  NetNet*super_this = new_scope->find_signal(perm_string::literal(THIS_TOKEN));
		  if (!super_this) {
			if (const PFunction*pfunc = new_scope->func_pform())
			      pfunc->elaborate_sig(des, new_scope);
			super_this = new_scope->find_signal(perm_string::literal(THIS_TOKEN));
		  }
		  if (super_this) {
			NetBlock*blk = new NetBlock(NetBlock::SEQU, 0);
			blk->set_line(*this);
			NetAssign_*lv_super = new NetAssign_(super_this);
			NetESignal*rv_this = new NetESignal(var_this);
			rv_this->set_line(*this);
			NetAssign*set_this = new NetAssign(lv_super, rv_this);
			set_this->set_line(*this);
			blk->append(set_this);
			blk->append(stmt);
			return blk;
		  }
	    }
	    return stmt;
      }

	// There is no constructor at all in the parent, so skip it.
      NetBlock*tmp = new NetBlock(NetBlock::SEQU, 0);
      tmp->set_line(*this);
      return tmp;
}

NetProc* PCondit::elaborate(Design*des, NetScope*scope) const
{
      ivl_assert(*this, scope);

      if (debug_elaborate)
	    cerr << get_fileline() << ":  PCondit::elaborate: "
		 << "Elaborate condition statement"
		 << " with conditional: " << *expr_ << endl;

	// Elaborate and try to evaluate the conditional expression.
      NetExpr*expr = elab_and_eval(des, scope, expr_, -1);
      if (expr == 0) {
	    // Compile-progress fallback: Some UVM patterns involve checking
	    // inherited method results without parentheses (e.g. port.size<1)
	    // which may fail to elaborate in complex class hierarchies.
	    // If in SystemVerilog mode and inside a function, assume the
	    // condition is false and continue elaboration as a no-op.
	    if (gn_system_verilog()) {
		  if (debug_elaborate)
			cerr << get_fileline() << ": debug: "
			     << "condition expression failed to elaborate; "
			     << (else_ ? "using else branch" : "using empty block")
			     << " as fallback (compile-progress fallback)." << endl;
		  // Elaborate only the else branch (if present) or return empty block
		  if (else_)
			return else_->elaborate(des, scope);
		  else {
			NetBlock*tmp = new NetBlock(NetBlock::SEQU, 0);
			tmp->set_line(*this);
			return tmp;
		  }
	    }
	    cerr << get_fileline() << ": error: Unable to elaborate"
		  " condition expression." << endl;
	    des->errors += 1;
	    return 0;
      }

	// If the condition of the conditional statement is constant,
	// then look at the value and elaborate either the if statement
	// or the else statement. I don't need both. If there is no
	// else_ statement, then use an empty block as a noop.
      if (const NetEConst*ce = dynamic_cast<NetEConst*>(expr)) {
	    verinum val = ce->value();
	    if (debug_elaborate) {
		  cerr << get_fileline() << ": debug: Condition expression "
		       << "is a constant " << val << "." << endl;
	    }

	    verinum::V reduced = verinum::V0;
	    for (unsigned idx = 0 ;  idx < val.len() ;  idx += 1)
		  reduced = reduced | val[idx];

	    delete expr;
	    if (reduced == verinum::V1)
		  if (if_) {
			return if_->elaborate(des, scope);
		  } else {
			NetBlock*tmp = new NetBlock(NetBlock::SEQU, 0);
			tmp->set_line(*this);
			return tmp;
		  }
	    else if (else_)
		  return else_->elaborate(des, scope);
	    else
		  return new NetBlock(NetBlock::SEQU, 0);
      }

	// If the condition expression is more than 1 bits, then
	// generate a comparison operator to get the result down to
	// one bit. Turn <e> into <e> != 0;

      if (expr->expr_width() < 1) {
	    // Compile-progress: class-typed expressions (e.g. foreach index
	    // variables with class-type keys) have width 0. Replace with a
	    // 1-bit true constant so the if-branch elaborates.
	    if (gn_system_verilog() && expr->expr_type() == IVL_VT_CLASS) {
		  delete expr;
		  expr = make_const_val(1);
	    } else {
		  cerr << get_fileline() << ": internal error: "
			"incomprehensible expression width (0) in scope "
		       << scope_path(scope) << ", expr=";
		  expr->dump(cerr);
		  cerr << endl;
		  return 0;
	    }
      }

	// Make sure the condition expression evaluates to a condition.
      expr = condition_reduce(expr);

	// Well, I actually need to generate code to handle the
	// conditional, so elaborate.
      NetProc*i = if_? if_->elaborate(des, scope) : NULL;
      NetProc*e = else_? else_->elaborate(des, scope) : NULL;

	// Detect the special cases that the if or else statements are
	// empty blocks. If this is the case, remove the blocks as
	// null statements.
      if (const NetBlock*tmp = dynamic_cast<NetBlock*>(i)) {
	    if (tmp->proc_first() == 0) {
		  delete i;
		  i = 0;
	    }
      }

      if (const NetBlock*tmp = dynamic_cast<NetBlock*>(e)) {
	    if (tmp->proc_first() == 0) {
		  delete e;
		  e = 0;
	    }
      }

      NetCondit*res = new NetCondit(expr, i, e);
      res->set_line(*this);
      return res;
}

NetProc* PContinue::elaborate(Design*des, NetScope*) const
{
      if (!gn_system_verilog()) {
	    cerr << get_fileline() << ": error: "
		<< "'continue' jump statement requires SystemVerilog." << endl;
	    des->errors += 1;
	    return nullptr;
      }

      NetContinue*res = new NetContinue;
      res->set_line(*this);
      return res;
}

NetProc* PCallTask::elaborate(Design*des, NetScope*scope) const
{
      if (peek_tail_name(path_)[0] == '$') {
	    if (void_cast_)
		  return elaborate_non_void_function_(des, scope);
	    else
		  return elaborate_sys(des, scope);
      } else {
	    return elaborate_usr(des, scope);
      }
}

/*
 * A call to a system task involves elaborating all the parameters,
 * then passing the list to the NetSTask object.
 *XXXX
 * There is a single special case in the call to a system
 * task. Normally, an expression cannot take an unindexed
 * memory. However, it is possible to take a system task parameter a
 * memory if the expression is trivial.
 */
NetProc* PCallTask::elaborate_sys(Design*des, NetScope*scope) const
{
      ivl_assert(*this, scope);

      if (path_.size() > 1) {
	    cerr << get_fileline() << ": error: Hierarchical system task names"
		 << " make no sense: " << path_ << endl;
	    des->errors += 1;
      }

      unsigned parm_count = parms_.size();
      vector<NetExpr*>eparms (parm_count);

      perm_string name = peek_tail_name(path_);

      for (unsigned idx = 0 ;  idx < parm_count ;  idx += 1) {
	    auto &parm = parms_[idx];

	    // System functions don't have named parameters
	    if (!parm.name.nil()) {
		  cerr << parm.get_fileline() << ": error: "
		       << "The system task `" << name
		       << "` has no argument called `" << parm.name
		       << "`." << endl;
		  des->errors++;
	    }

	    eparms[idx] = elab_sys_task_arg(des, scope, name, idx,
					    parm.parm);
      }

	// Special case: Specify blocks and interconnects are turned off,
	// and this is an $sdf_annotate system task. There will be nothing for
	// $sdf to annotate, and the user is intending to turn the behavior
	// off anyhow, so replace the system task invocation with a no-op.
      if (gn_specify_blocks_flag == false && gn_interconnect_flag == false && name == "$sdf_annotate") {

	    cerr << get_fileline() << ": warning: Omitting $sdf_annotate() "
	         << "since specify blocks and interconnects are being omitted." << endl;
	    NetBlock*noop = new NetBlock(NetBlock::SEQU, scope);
	    noop->set_line(*this);
	    return noop;
      }

      scope->calls_sys_task(true);

      NetSTask*cur = new NetSTask(name, def_sfunc_as_task, eparms);
      cur->set_line(*this);
      return cur;
}

/*
 * A call to a user defined task is different from a call to a system
 * task because a user task in a netlist has no parameters: the
 * assignments are done by the calling thread. For example:
 *
 *  task foo;
 *    input a;
 *    output b;
 *    [...]
 *  endtask;
 *
 *  [...] foo(x, y);
 *
 * is really:
 *
 *  task foo;
 *    reg a;
 *    reg b;
 *    [...]
 *  endtask;
 *
 *  [...]
 *  begin
 *    a = x;
 *    foo;
 *    y = b;
 *  end
 */
NetProc* PCallTask::elaborate_usr(Design*des, NetScope*scope) const
{
      ivl_assert(*this, scope);

      /* Phase 63b/B8 (real impl): lower `std::randomize(args);' to a
	 sequential block of NetAssign(arg, $random).  Catches both the
	 plain statement form and the void'(std::randomize(...)) form,
	 since both arrive here as PCallTask with path `std.randomize`.
	 The with-clause variant is handled at parse time (see parse.y);
	 this catches the without-with form. */
      if (gn_system_verilog() && path_.size() == 2
	  && path_.front().name == perm_string::literal("std")
	  && path_.back().name == perm_string::literal("randomize")
	  && !parms_.empty()) {
	    NetBlock*blk = new NetBlock(NetBlock::SEQU, 0);
	    blk->set_line(*this);
	    for (unsigned i = 0; i < parms_.size(); i++) {
		  PExpr*lvexpr = parms_[i].parm;
		  if (!lvexpr) continue;
		  NetAssign_*lv = lvexpr->elaborate_lval(des, scope, false, false);
		  if (!lv) continue;
		  NetESFunc*rhs = new NetESFunc(
			"$random", IVL_VT_LOGIC, 32, 0);
		  rhs->set_line(*this);
		  NetAssign*as = new NetAssign(lv, rhs);
		  as->set_line(*this);
		  blk->append(as);
	    }
	    return blk;
      }

      bool has_indexed_path_component = false;
      for (const auto& comp : path_) {
	    if (!comp.index.empty()) {
		  has_indexed_path_component = true;
		  break;
	    }
      }

      NetScope*pscope = scope;
      if (package_) {
	    pscope = des->find_package(package_->pscope_name());
	    ivl_assert(*this, pscope);
      }

	      if (gn_system_verilog() && has_indexed_path_component) {
		      // Hierarchical task lookup treats indexed path components as scope
		      // indices (which must be constant). For SV object methods like
		      // q[idx].method(), try method elaboration first and otherwise
		      // degrade to a warning/no-op to keep UVM compilation progressing.
		    NetProc *tmp = elaborate_method_(des, scope, false);
		    if (tmp) return tmp;
		    if (is_uvm_compile_progress_task_stub_candidate_(path_)) {
			  NetBlock*noop = new NetBlock(NetBlock::SEQU, 0);
			  noop->set_line(*this);
			  return noop;
		    }
		    if (peek_tail_name(path_) == perm_string::literal("clear")) {
			  NetBlock*noop = new NetBlock(NetBlock::SEQU, 0);
			  noop->set_line(*this);
			  return noop;
		    }
		    if (!warned_indexed_object_method_ignored) {
			  cerr << get_fileline() << ": warning: indexed object method call `"
			       << path_ << "' ignored (limited support, further similar warnings suppressed)." << endl;
			  warned_indexed_object_method_ignored = true;
		    }
		    NetBlock*noop = new NetBlock(NetBlock::SEQU, 0);
		    noop->set_line(*this);
		    return noop;
	      }

      NetScope*task = des->find_task(pscope, path_);
      if (gn_system_verilog() && leading_type_args()
	  && path_.size() > 1 && !has_indexed_path_component) {
	    pform_name_t type_path = path_;
	    perm_string method_name = peek_tail_name(type_path);
	    type_path.pop_back();

	    if (NetScope*static_method = resolve_scoped_class_method_task_(des, pscope,
								       type_path, method_name,
								       leading_type_args())) {
		  if (task == 0 || task != static_method)
			task = static_method;
	    }
      }

      if (task == 0) {
	      // For SystemVerilog this may be a few other things.
	    if (gn_system_verilog()) {
		  NetProc *tmp;
		    // If a package was explicitly named (`pkg::name(...)` form),
		    // resolve as a package function call directly. Do NOT try
		    // implicit-this method dispatch — that would mis-resolve to
		    // a virtual method on the calling class with the same name
		    // (e.g. dv_base_env_cfg::reset_asserted calling
		    // csr_utils_pkg::reset_asserted would otherwise recurse).
		  if (package_) {
			tmp = elaborate_function_(des, scope);
			if (tmp) return tmp;
		  }
		    // This could be a method attached to a signal
		    // or defined in this object?
		  bool try_implicit_this = scope->get_class_scope() && path_.size() == 1;
		  tmp = elaborate_method_(des, scope, try_implicit_this);
		  if (tmp) return tmp;
		    // Or it could be a function call ignoring the return?
		  tmp = elaborate_function_(des, scope);
		  if (tmp) return tmp;
	    }

	    if (gn_system_verilog() && is_uvm_compile_progress_task_stub_candidate_(path_)) {
		  NetBlock*noop = new NetBlock(NetBlock::SEQU, 0);
		  noop->set_line(*this);
		  return noop;
	    }

	    // Route `<assoc>.first/last/next/prev(key)` task calls through
	    // the existing assoc-method runtime hooks. This case typically
	    // arrives via `void'(m_maps.first(map))` — UVM does this in
	    // get_default_map / get_local_map. Without this, the call falls
	    // into the "unknown task" warning path and silently NOOPs, so
	    // `map` stays null and the register layer trips a null-map
	    // UVM_ERROR.
	    if (gn_system_verilog() && path_.size() >= 2 && parms_.size() == 1) {
		  perm_string mname = peek_tail_name(path_);
		  bool is_aa_traversal =
			(mname == perm_string::literal("first")
			 || mname == perm_string::literal("last")
			 || mname == perm_string::literal("next")
			 || mname == perm_string::literal("prev"));
		  if (is_aa_traversal) {
			// Build the receiver via PEIdent so class-property
			// chains (this.m_maps) resolve through NetEProperty,
			// not just bare signals.
			pform_name_t obj_path = path_;
			obj_path.pop_back();
			PEIdent*obj_id = new PEIdent(obj_path, /*lexical_pos*/0);
			obj_id->set_file(get_file());
			obj_id->set_lineno(get_lineno());
			NetExpr*obj_expr = obj_id->elaborate_expr(des, scope, /*expr_wid*/0u, /*flags*/0u);
			if (obj_expr) {
			      NetExpr*key_expr = elab_and_eval(des, scope, parms_[0].parm, -1, false);
			      if (key_expr) {
				    string sys_name = "$ivl_assoc_method$";
				    sys_name += mname.str();
				    NetESFunc*sys_expr = new NetESFunc(
					    sys_name.c_str(), &netvector_t::atom2u32, 2);
				    sys_expr->set_line(*this);
				    sys_expr->parm(0, obj_expr);
				    sys_expr->parm(1, key_expr);
				    NetNet*tmp = new NetNet(scope, scope->local_symbol(),
					    NetNet::REG, &netvector_t::atom2u32);
				    tmp->set_line(*this);
				    NetAssign_*lv = new NetAssign_(tmp);
				    NetAssign*na = new NetAssign(lv, sys_expr);
				    na->set_line(*this);
				    delete obj_id;
				    return na;
			      }
			      delete obj_expr;
			}
			delete obj_id;
		  }
	    }

	    if (gn_system_verilog() && path_.size() > 1) {
		    // Compile-progress fallback: multi-component task path
		    // that couldn't be resolved as a method call.
		  perm_string tail = peek_tail_name(path_);
		  // obj.constraint_name.constraint_mode(mode) — enable/disable a specific constraint.
		  // path_ = [obj..., constraint_name, constraint_mode]
		  if (tail == perm_string::literal("constraint_mode")
		      && path_.size() >= 2 && parms_.size() == 1) {
			// pform_name_t is a list; get second-to-last element
			perm_string cname = std::next(path_.end(), -2)->name;

			// Resolve the receiver via the full pform path_:
			// path_ = [a, b, ..., cname, constraint_mode]
			// Leading components (before cname) are property
			// accesses on a base receiver.  Start from `this`
			// or a scope signal, then walk each component as
			// a property of the current class.
			NetNet *base_net = nullptr;
			for (NetScope *s = scope; s && !base_net; s = s->parent())
			      base_net = s->find_signal(perm_string::literal(THIS_TOKEN));
			if (!base_net && !path_.empty()) {
			      // Top-level call (not inside a class method) —
			      // try to find the first path component as a
			      // module-level signal.
			      symbol_search_results sr0;
			      pform_name_t head; head.push_back(path_.front());
			      symbol_search(this, des, scope, head, UINT_MAX, &sr0);
			      base_net = sr0.net;
			}
			NetExpr *recv = nullptr;
			const netclass_t *recv_class = nullptr;
			if (base_net) {
			      recv_class = dynamic_cast<const netclass_t*>(
				    base_net->net_type());
			      recv = new NetESignal(base_net);
			      recv->set_line(*this);
			}
			// Walk property components: everything between the
			// receiver root and the trailing [cname, constraint_mode].
			size_t leading = path_.size() - 2;
			size_t skip_first =
			      (base_net && path_.front().name
				 == base_net->name()) ? 1 : 0;
			auto pit = path_.begin();
			for (size_t i = 0; i < skip_first && pit != path_.end(); ++i)
			      ++pit;
			for (size_t step = skip_first; step < leading && recv_class
				 && pit != path_.end(); ++step, ++pit) {
			      perm_string pname = pit->name;
			      int pidx = recv_class->property_idx_from_name(pname);
			      if (pidx < 0) {
				    delete recv; recv = nullptr; recv_class = nullptr;
				    break;
			      }
			      ivl_type_t pt = recv_class->get_prop_type(pidx);
			      const netclass_t *next_class =
				    dynamic_cast<const netclass_t*>(pt);
			      if (!next_class) {
				    delete recv; recv = nullptr; recv_class = nullptr;
				    break;
			      }
			      recv = new NetEProperty(recv, (size_t)pidx);
			      recv->set_line(*this);
			      recv_class = next_class;
			}
			if (recv && recv_class) {
			      size_t cid = recv_class->constraint_ir_count();
			      for (size_t ci = 0;
				   ci < recv_class->constraint_ir_count(); ++ci) {
				    if (recv_class->constraint_ir_name(ci)
					== string(cname)) {
					  cid = ci; break;
				    }
			      }
			      if (cid < recv_class->constraint_ir_count()) {
				    NetExpr *mode_expr =
					  elab_sys_task_arg(des, scope, tail, 0,
							    parms_[0].parm);
				    NetExpr *cid_expr = new NetEConst(
					  verinum((uint64_t)cid, 32));
				    cid_expr->set_line(*this);
				    vector<NetExpr*> argv(3);
				    argv[0] = recv;
				    argv[1] = mode_expr;
				    argv[2] = cid_expr;
				    NetSTask *sys = new NetSTask(
					  "$ivl_class_method$constraint_mode",
					  IVL_SFUNC_AS_TASK_IGNORE, argv);
				    sys->set_line(*this);
				    return sys;
			      }
			}
			if (recv) delete recv;
			// Fallthrough: constraint name not found — silent noop
			NetBlock*noop = new NetBlock(NetBlock::SEQU, 0);
			noop->set_line(*this);
			return noop;
		  }
		  // rand_mode with multi-component path is still a noop.
		  bool silent_noop = (tail == perm_string::literal("rand_mode"));
		  // Phase 63b/B3: silence task-enable warnings for known
		  // UVM dead-spec patterns (uvm_pair.first.copy() /
		  // uvm_pair.second.copy() etc., where T=int default).
		  if (!silent_noop && (
			tail == perm_string::literal("copy")
			|| tail == perm_string::literal("do_copy")
			|| tail == perm_string::literal("print")
			|| tail == perm_string::literal("record")
			// Phase 63b/B4: uvm_registry.svh:656 calls
			// rgtry.initialize() inside a static
			// __deferred_init.  The spec class doesn't always
			// elaborate initialize() at static init time, so
			// the call appears unresolved.  The task is
			// otherwise resolved later via uvm_init's
			// deferred-init queue, so the static-time
			// no-op is safe.
			|| tail == perm_string::literal("initialize")
			|| tail == perm_string::literal("m_initialize"))) {
			silent_noop = true;
		  }
		  if (!silent_noop) {
			cerr << get_fileline() << ": warning: Enable of unknown task "
			     << "``" << path_ << "'' ignored (compile-progress fallback)." << endl;
		  }
		  NetBlock*noop = new NetBlock(NetBlock::SEQU, 0);
		  noop->set_line(*this);
		  return noop;
	    }

	    if (gn_system_verilog()) {
		  // Compile-progress: covergroup sample(), interface methods, and
		  // other SV constructs may not resolve as tasks. Drop silently.
		  cerr << get_fileline() << ": warning: Enable of unknown task "
		       << "``" << path_ << "'' ignored (compile-progress)." << endl;
		  NetBlock*noop = new NetBlock(NetBlock::SEQU, 0);
		  noop->set_line(*this);
		  return noop;
	    }
	    cerr << get_fileline() << ": error: Enable of unknown task "
		 << "``" << path_ << "''." << endl;
	    des->errors += 1;
	    return 0;
      }

      if (task->type() == NetScope::FUNC)
	    return elaborate_build_call_(des, scope, task, nullptr);

	      ivl_assert(*this, task);
	      ivl_assert(*this, task->type() == NetScope::TASK);
		    const NetTaskDef*def = task->task_def();
		    if (def == 0 || def->proc() == 0) {
			  const PTask*ptask = task->task_pform();
			  if (ptask) {
				ptask->elaborate_sig(des, task);
				if (task->task_def() && task->task_def()->proc() == 0)
					elaborate_task_outside_caller_fork_(des, ptask, task);
			  def = task->task_def();
		    }
	      }
      if (def == 0) {
	    cerr << get_fileline() << ": internal error: task " << path_
		 << " doesn't have a definition in " << scope_path(scope)
		 << "." << endl;
	    des->errors += 1;
	    return 0;
      }
      ivl_assert(*this, def);

	/* In SystemVerilog a method calling another method in the
	 * current class needs to be elaborated as a method with an
	 * implicit this added.  */
      if (gn_system_verilog() && (path_.size() == 1)) {
	    const NetScope *c_scope = scope->get_class_scope();
	    if (c_scope && (c_scope == task->get_class_scope())) {
		  NetProc *tmp = elaborate_method_(des, scope, true);
		  ivl_assert(*this, tmp);
		  return tmp;
	    }
      }

      unsigned parm_count = def->port_count();

	/* Handle non-automatic tasks with no parameters specially. There is
           no need to make a sequential block to hold the generated code. */
      if ((parm_count == 0) && !task->is_auto()) {
	      // Check if a task call is allowed in this context.
	    test_task_calls_ok_(des, scope);

	    NetUTask*cur = new NetUTask(task);
	    cur->set_line(*this);
	    return cur;
      }

      return elaborate_build_call_(des, scope, task, 0);
}

/*
 * This private method is called to elaborate built-in methods. The
 * method_name is the detected name of the built-in method, and the
 * sys_task_name is the internal system-task name to use.
 */
NetProc* PCallTask::elaborate_sys_task_method_(Design*des, NetScope*scope,
					       NetExpr*obj,
					       ivl_type_t obj_type,
					       perm_string method_name,
					       const char *sys_task_name,
					       const std::vector<perm_string> &parm_names) const
{
      unsigned nparms = parms_.size();

      vector<NetExpr*>argv (1 + nparms);
      argv[0] = obj;

      if (method_name == "delete") {
	      // The queue delete method takes an optional element.
	    if (dynamic_cast<const netqueue_t*>(obj_type)
		|| dynamic_cast<const netuarray_t*>(obj_type)) {
		  if (nparms > 1)  {
			cerr << get_fileline() << ": error: queue delete() "
			     << "method takes zero or one argument." << endl;
			des->errors += 1;
		  }
	    } else if (nparms > 0) {
		  cerr << get_fileline() << ": error: darray delete() "
		       << "method takes no arguments." << endl;
		  des->errors += 1;
	    }
      } else if (parm_names.size() != parms_.size()) {
	    cerr << get_fileline() << ": error: " << method_name
	         << "() method takes " << parm_names.size() << " arguments, got "
		 << parms_.size() << "." << endl;
	    des->errors++;
      }

      auto args = map_named_args(des, parm_names, parms_);
      for (unsigned idx = 0 ; idx < nparms ; idx += 1) {
	    argv[idx + 1] = elab_sys_task_arg(des, scope, method_name,
					      idx, args[idx]);
      }

      NetSTask*sys = new NetSTask(sys_task_name, IVL_SFUNC_AS_TASK_IGNORE, argv);
      sys->set_line(*this);
      return sys;
}

/*
 * This private method is called to elaborate queue push methods. The
 * sys_task_name is the internal system-task name to use.
 */
NetProc* PCallTask::elaborate_queue_method_(Design*des, NetScope*scope,
					    NetExpr*obj,
					    const netdarray_t*obj_darray,
					    perm_string method_name,
					    const char *sys_task_name,
					    const std::vector<perm_string> &parm_names) const
{
      unsigned nparms = parms_.size();
      ivl_type_t element_type = obj_darray ? obj_darray->element_type() : 0;
	// insert() requires two arguments.
      if ((method_name == "insert") && (nparms != 2)) {
	    cerr << get_fileline() << ": error: " << method_name
		 << "() method requires two arguments." << endl;
	    des->errors += 1;
      }
	// push_front() and push_back() require one argument.
      if ((method_name != "insert") && (nparms != 1)) {
	    cerr << get_fileline() << ": error: " << method_name
		 << "() method requires a single argument." << endl;
	    des->errors += 1;
      }

	// Get the context width if this is a logic type.
      ivl_assert(*this, obj_darray);
      ivl_variable_type_t base_type = obj_darray->element_base_type();
      int context_width = -1;
      switch (base_type) {
	  case IVL_VT_BOOL:
	  case IVL_VT_LOGIC:
	    context_width = obj_darray->element_width();
	    break;
	  default:
	    break;
      }

      vector<NetExpr*>argv (nparms+1);
      argv[0] = obj;

      auto args = map_named_args(des, parm_names, parms_);
      if (method_name != "insert") {
	    if (nparms == 0 || !args[0]) {
		  argv[1] = nullptr;
		  cerr << get_fileline() << ": error: " << method_name
		       << "() methods first argument is missing." << endl;
		  des->errors += 1;
	    } else {
		  if (element_type)
			argv[1] = elaborate_rval_expr(des, scope, element_type,
						      args[0], false, false);
		  else
			argv[1] = elab_and_eval(des, scope, args[0], context_width,
						false, false, base_type);
		  if (!argv[1]) {
			cerr << get_fileline() << ": error: " << method_name
			     << "() methods first argument could not be elaborated." << endl;
			des->errors += 1;
		  }
	    }
      } else {
	    if (nparms == 0 || !args[0]) {
		  argv[1] = nullptr;
		  cerr << get_fileline() << ": error: " << method_name
		       << "() methods first argument is missing." << endl;
		  des->errors += 1;
	    } else {
		  argv[1] = elab_and_eval(des, scope, args[0], context_width,
		                          false, false, IVL_VT_LOGIC);
	    }

	    if (nparms < 2 || !args[1]) {
		  argv[2] = nullptr;
		  cerr << get_fileline() << ": error: " << method_name
		       << "() methods second argument is missing." << endl;
		  des->errors += 1;
	    } else {
		  if (element_type)
			argv[2] = elaborate_rval_expr(des, scope, element_type,
						      args[1], false, false);
		  else
			argv[2] = elab_and_eval(des, scope, args[1], context_width,
						false, false, base_type);
		  if (!argv[2]) {
			cerr << get_fileline() << ": error: " << method_name
			     << "() methods second argument could not be elaborated." << endl;
			des->errors += 1;
		  }
	    }
      }

      NetSTask*sys = new NetSTask(sys_task_name, IVL_SFUNC_AS_TASK_IGNORE, argv);
      sys->set_line(*this);
      return sys;
}

/*
 * This is used for array/queue function methods called as tasks.
 */
NetProc* PCallTask::elaborate_method_func_(NetScope*scope,
                                           NetExpr*obj,
					   ivl_type_t type,
					   perm_string method_name,
                                           const char*sys_task_name) const
{
      if (!void_cast_) {
	    cerr << get_fileline() << ": warning: method function '"
		 << method_name << "' is being called as a task." << endl;
      }

	// Generate the function.
      NetESFunc*sys_expr = new NetESFunc(sys_task_name, type, 1);
      sys_expr->set_line(*this);
      sys_expr->parm(0, obj);
	// Create a L-value that matches the function return type.
      NetNet*tmp;
      tmp = new NetNet(scope, scope->local_symbol(), NetNet::REG, type);
      tmp->set_line(*this);
      NetAssign_*lv = new NetAssign_(tmp);
	// Generate an assign to the fake L-value.
      NetAssign*cur = new NetAssign(lv, sys_expr);
      cur->set_line(*this);
      return cur;
}

static bool is_tlm_forward_task_stub_candidate_(const pform_name_t&use_path,
						perm_string method_name)
{
      if (use_path.empty())
	    return false;

      perm_string target_name = peek_tail_name(use_path);
      if (target_name != perm_string::literal("m_if")
	  && target_name != perm_string::literal("m_imp")
	  && target_name != perm_string::literal("m_req_imp")
	  && target_name != perm_string::literal("m_rsp_imp")
	  && target_name != perm_string::literal("m_port")
	  && target_name != perm_string::literal("m"))
	    return false;

      if (target_name == perm_string::literal("m_port")) {
	    return method_name == perm_string::literal("resolve_bindings")
		|| method_name == perm_string::literal("get_connected_to")
		|| method_name == perm_string::literal("get_provided_to");
      }

      return method_name == perm_string::literal("put")
	  || method_name == perm_string::literal("get")
	  || method_name == perm_string::literal("peek")
	  || method_name == perm_string::literal("write")
	  || method_name == perm_string::literal("transport")
	  || method_name == perm_string::literal("b_transport")
	  || method_name == perm_string::literal("get_next_item")
	  || method_name == perm_string::literal("try_next_item")
	  || method_name == perm_string::literal("item_done")
	  || method_name == perm_string::literal("put_response")
	  || method_name == perm_string::literal("wait_for_sequences")
	  || method_name == perm_string::literal("disable_auto_item_recording");
}

static bool is_multi_hop_collection_task_stub_candidate_(const pform_name_t&use_path,
							  perm_string method_name)
{
      if (use_path.size() < 2)
	    return false;

      return method_name == perm_string::literal("delete")
	  || method_name == perm_string::literal("push_front")
	  || method_name == perm_string::literal("push_back")
	  || method_name == perm_string::literal("insert")
	  || method_name == perm_string::literal("sort")
	  || method_name == perm_string::literal("rsort")
	  || method_name == perm_string::literal("shuffle")
	  || method_name == perm_string::literal("reverse");
}

static bool is_uvm_compile_progress_task_stub_candidate_(const pform_name_t&path)
{
      if (path.empty())
	    return false;

      perm_string tail = peek_tail_name(path);

      // UVM register-model internals: these methods are genuinely complex/incomplete
      // in iverilog's implementation and must remain as noops.
      if (tail == perm_string::literal("get_fields")
	  || tail == perm_string::literal("get_maps")
	  || tail == perm_string::literal("reset")
	  || tail == perm_string::literal("set_lock")
	  || tail == perm_string::literal("get_virtual_registers")
	  || tail == perm_string::literal("get_submaps")
	  || tail == perm_string::literal("get_blocks")
	  || tail == perm_string::literal("mirror")
	  || tail == perm_string::literal("set_local")
	  || tail == perm_string::literal("init_address_map")
	  || tail == perm_string::literal("Xinit_address_mapX")
	  || tail == perm_string::literal("do_predict"))
	    return true;

      // UVM phase recursion guards: these appear in loop-like UVM internal
      // constructs that would cause elaboration recursion if not stubbed.
      if (tail == perm_string::literal("m_print_successors")
	  || tail == perm_string::literal("kill_successors")
	  || tail == perm_string::literal("clear_successors")
	  || tail == perm_string::literal("process_guard_triggered"))
	    return true;

      // SV semaphore/mailbox operations that map to UVM internal synchronization
      // primitives not yet supported in the iverilog VVP runtime.
      if (tail == perm_string::literal("put")
	  || tail == perm_string::literal("get")
	  || tail == perm_string::literal("try_get")) {
	    pform_name_t use_path = path;
	    use_path.pop_back();
	    if (!use_path.empty()) {
		  perm_string parent = peek_tail_name(use_path);
		  if (parent == perm_string::literal("m_sequence_state_mutex")
		      || parent == perm_string::literal("m_atomic")
		      || parent == perm_string::literal("m_frontdoor_mutex")
		      || parent == perm_string::literal("atomic"))
			return true;
	    }
      }

      // (Previously stubbed `m_maps.first/last/next/prev` here because
      // the codegen for `%aa/first/sig/obj` pushed a 1-bit success flag
      // while the caller expected 32 bits, tripping an of_STORE_VEC4
      // assertion. That width mismatch is now fixed in
      // `tgt-vvp/eval_vec4.c` — a `%pad/u` is emitted after the /sig/
      // form so the result extends to the expected width. With the
      // codegen fixed, UVM `get_default_map` returns the registered
      // map and the null-map UVM_ERROR no longer fires.)

      return false;
}

NetProc* PCallTask::elaborate_method_(Design*des, NetScope*scope,
				      bool add_this_flag) const
{
      static int trace_class_method = -1;
      auto scope_text = [](const NetScope*use_scope) -> std::string {
            if (!use_scope)
                  return "<null>";
            std::ostringstream out;
            out << scope_path(use_scope);
            return out.str();
      };
      if (trace_class_method < 0) {
            const char*env = getenv("IVL_CLASS_METHOD_TRACE");
            trace_class_method = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
      }
      NetScope*search_scope = scope;
      if (package_) {
	    search_scope = des->find_package(package_->pscope_name());
	    ivl_assert(*this, search_scope);
      }

      pform_name_t use_path = path_;
      perm_string method_name = peek_tail_name(use_path);
      use_path.pop_back();
      bool explicit_super =
	    !use_path.empty()
	    && use_path.front().name == perm_string::literal(SUPER_TOKEN);

	/* Add the implicit this reference when requested. */
      if (add_this_flag) {
	    ivl_assert(*this, use_path.empty());
	    use_path.push_front(name_component_t(perm_string::literal(THIS_TOKEN)));
      }

      if (debug_elaborate) {
	    cerr << get_fileline() << ": PCallTask::elaborate_method_: "
		 << "use_path=" << use_path
		 << ", method_name=" << method_name
		 << ", add_this_flag=" << add_this_flag
		 << endl;
      }

	// There is no signal to search for so this cannot be a method.
      if (use_path.empty()) return 0;

	// Search for an object using the use_path. This should
	// resolve to a class object. Note that the "this" symbol
	// (internally represented as "@") is handled by there being a
	// "this" object in the instance scope.
      symbol_search_results sr;
      symbol_search(this, des, search_scope, use_path, UINT_MAX, &sr);

      if (!package_ && sr.net == 0 && use_path.size() >= 2) {
	    pform_name_t pkg_use_path = use_path;
	    perm_string pkg_name = pkg_use_path.front().name;

	    for (NetScope*pkg_scope : des->find_package_scopes()) {
		  if (pkg_scope->basename() != pkg_name)
			continue;

		  pkg_use_path.pop_front();
		  symbol_search(this, des, pkg_scope, pkg_use_path, UINT_MAX, &sr);
		  if (sr.net != 0)
			break;
	    }
      }

      NetNet*net = sr.net;
      if (net == 0) {
	    if (NetScope*static_method = resolve_scoped_class_method_task_(des, search_scope,
								       use_path, method_name,
								       leading_type_args())) {
		  return elaborate_build_call_(des, scope, static_method, nullptr);
	    }
	    return 0;
      }

      NetExpr*obj_expr = new NetESignal(net);
      obj_expr->set_line(*this);
      ivl_type_t obj_type = sr.type? sr.type : net->net_type();
      // For unpacked arrays: net_type() returns the element type but
      // array_type() returns the netuarray_t container; prefer the latter.
      if (!dynamic_cast<const netdarray_t*>(obj_type)
	  && !dynamic_cast<const netuarray_t*>(obj_type)) {
	    if (const netarray_t*arr = net->array_type())
		  obj_type = arr;
      }

      if (!sr.path_head.empty() && !sr.path_head.back().index.empty()) {
	    obj_expr = elaborate_root_indexed_method_target_expr_(this, des, scope,
								  obj_expr, obj_type,
								  sr.path_head.back().index,
								  method_name,
								  obj_type);
	    if (!obj_expr)
		  return 0;
      }

      if (!sr.path_tail.empty()) {
	    while (!sr.path_tail.empty()) {
		  const netclass_t*class_type = dynamic_cast<const netclass_t*>(obj_type);
		  const name_component_t&comp = sr.path_tail.front();
		  if (!class_type) {
			delete obj_expr;
			return 0;
		  }
		  obj_expr = elaborate_nested_method_target_property_task_(this, des, scope,
									   obj_expr, class_type,
									   comp, method_name,
									   obj_type);
		  if (!obj_expr)
			return 0;

		  sr.path_tail.pop_front();
	    }
      }

      if (debug_elaborate) {
	    cerr << get_fileline() << ": PCallTask::elaborate_method_: "
		 << "Try to match method " << method_name
		 << " of object " << net->name()
		 << "." << endl;
	    if (net->net_type())
		  cerr << get_fileline() << ": PCallTask::elaborate_method_: "
		       << net->name() << ".net_type() --> "
		       << *net->net_type() << endl;
	    cerr << get_fileline() << ": PCallTask::elaborate_method_: "
		 << net->name() << ".data_type() --> " << net->data_type() << endl;
      }

      // Skip TLM stub for built-in class types that have real implementations
      // (mailbox/semaphore/process) — their variable names may collide with
      // TLM port variable name patterns (e.g. a mailbox named "m").
      {
	    bool is_builtin_type = false;
	    if (const netclass_t*ct = dynamic_cast<const netclass_t*>(obj_type)) {
		  perm_string cn = ct->get_name();
		  is_builtin_type = (cn == perm_string::literal("mailbox") ||
				     cn == perm_string::literal("semaphore") ||
				     cn == perm_string::literal("process"));
	    }
	    if (!is_builtin_type && is_tlm_forward_task_stub_candidate_(use_path, method_name)) {
		  // Certain TLM methods must NOT be early-stubbed because the class
		  // type is known here and the real method can be found.
		  // - m_port.resolve_bindings(): port binding resolution needs real impl.
		  // - m_if.{get_next_item,try_next_item,item_done,put_response}: the
		  //   seq/driver TLM handshake requires real virtual dispatch through
		  //   the sequencer imp.
		  // When method lookup later fails (e.g. generic specializations),
		  // the post-lookup stub below handles it safely.
		  perm_string path_target = peek_tail_name(use_path);
		  bool is_real_call_candidate = false;
		  if (path_target == perm_string::literal("m_port")
		      && method_name == perm_string::literal("resolve_bindings")) {
			is_real_call_candidate = true;
		  } else if (path_target == perm_string::literal("m_if")
			     || path_target == perm_string::literal("m_imp")
			     || path_target == perm_string::literal("m_req_imp")
			     || path_target == perm_string::literal("m_rsp_imp")) {
			// All TLM data-transfer methods on m_if/m_imp/m_req_imp/m_rsp_imp
			// must be elaborated for real virtual dispatch. If method lookup
			// fails (e.g. abstract base type), the post-lookup stub handles it.
			is_real_call_candidate = true;
		  }
		  if (!is_real_call_candidate) {
			delete obj_expr;
			NetBlock*noop = new NetBlock(NetBlock::SEQU, 0);
			noop->set_line(*this);
			return noop;
		  }
	    }
      }

	// Is this a method of a "string" type?
      if (dynamic_cast<const netstring_t*>(obj_type)) {
	    if (method_name == "itoa") {
		  static const std::vector<perm_string> parm_names = {
			perm_string::literal("i")
		  };

		  return elaborate_sys_task_method_(des, scope, obj_expr, obj_type, method_name,
						    "$ivl_string_method$itoa",
						    parm_names);
	    } else if (method_name == "hextoa") {
		  static const std::vector<perm_string> parm_names = {
			perm_string::literal("i")
		  };

		  return elaborate_sys_task_method_(des, scope, obj_expr, obj_type, method_name,
						    "$ivl_string_method$hextoa",
						    parm_names);
	    } else if (method_name == "octtoa") {
		  static const std::vector<perm_string> parm_names = {
			perm_string::literal("i")
		  };

		  return elaborate_sys_task_method_(des, scope, obj_expr, obj_type, method_name,
						    "$ivl_string_method$octtoa",
						    parm_names);
	    } else if (method_name == "bintoa") {
		  static const std::vector<perm_string> parm_names = {
			perm_string::literal("i")
		  };

		  return elaborate_sys_task_method_(des, scope, obj_expr, obj_type, method_name,
						    "$ivl_string_method$bintoa",
						    parm_names);
	    } else if (method_name == "realtoa") {
		  static const std::vector<perm_string> parm_names = {
			perm_string::literal("r")
		  };

		  return elaborate_sys_task_method_(des, scope, obj_expr, obj_type, method_name,
						    "$ivl_string_method$realtoa",
						    parm_names);
	    } else if (method_name == "putc") {
		  static const std::vector<perm_string> parm_names = {
			perm_string::literal("index"),
			perm_string::literal("c"),
		  };

		  return elaborate_sys_task_method_(des, scope, obj_expr, obj_type, method_name,
						    "$ivl_string_method$putc",
						    parm_names);
	    }
      }

      const netdarray_t*obj_darray = dynamic_cast<const netdarray_t*>(obj_type);
      const netuarray_t*obj_uarray = dynamic_cast<const netuarray_t*>(obj_type);

	// Is this a delete method for dynamic arrays or queues?
      if (obj_darray) {
	    if (method_name == "delete") {
		  static const std::vector<perm_string> parm_names = {
			perm_string::literal("index")
		  };

		  return elaborate_sys_task_method_(des, scope, obj_expr, obj_type, method_name,
		                                    "$ivl_darray_method$delete",
						    parm_names);
		    } else if (method_name == "size") {
			    // This returns an int. It could be removed, but keep for now.
			  return elaborate_method_func_(scope, obj_expr,
			                                &netvector_t::atom2s32,
			                                method_name, "$size");
			    } else if (method_name == "reverse") {
				  if (gn_system_verilog()) {
					/* Phase 63b/Q-methods (gap close): wire to %qreverse. */
					vector<NetExpr*> argv(1);
					argv[0] = obj_expr;
					NetSTask*sys = new NetSTask("$ivl_queue_method$reverse",
								    IVL_SFUNC_AS_TASK_IGNORE, argv);
					sys->set_line(*this);
					return sys;
			  }
			  cerr << get_fileline() << ": sorry: 'reverse()' "
			          "array sorting method is not currently supported."
			       << endl;
			  des->errors += 1;
				  delete obj_expr;
				  return 0;
			    } else if (method_name=="sort"
				       || method_name=="rsort"
				       || method_name=="unique") {
				  if (gn_system_verilog()) {
					/* Phase 63b/Q-methods (gap close): when a with-
					   clause is present, route through a sort_with
					   variant that the tgt-vvp codegen lowers to an
					   inline insertion sort using the predicate as
					   key extractor.  Without a with-clause, use
					   the existing default-compare runtime path. */
					if (!with_constraints().empty()) {
					      ivl_type_t element_type = nullptr;
					      if (auto que = dynamic_cast<const netqueue_t*>(obj_type))
						    element_type = que->element_type();
					      else if (auto darr = dynamic_cast<const netdarray_t*>(obj_type))
						    element_type = darr->element_type();
					      if (element_type) {
						    /* Determine the iterator name: parms_[0] if set,
						       else "item" per LRM default. */
						    perm_string iter_name = perm_string::literal("item");
						    if (!parms_.empty() && parms_[0].parm) {
							  if (auto ip = dynamic_cast<const PEIdent*>(parms_[0].parm))
								if (ip->path().size() == 1)
								      iter_name = ip->path().back().name;
						    }
						    NetNet*iter_net = scope->find_signal(iter_name);
						    if (!iter_net) {
							  iter_net = new NetNet(scope, iter_name,
										NetNet::REG, element_type);
							  iter_net->set_line(*this);
							  iter_net->local_flag(true);
						    }
						    /* Allocate a keys queue (vec4 32-bit) — predicate
						       result is stored here for paired sort. */
						    netqueue_t*keys_qtype = new netqueue_t(
							  &netvector_t::atom2s32, -1, false);
						    NetNet*keys_net = new NetNet(scope, scope->local_symbol(),
										 NetNet::REG, keys_qtype);
						    keys_net->set_line(*this);
						    keys_net->local_flag(true);
						    /* Loop-counter NetNet (s32) for the inline key-build loop. */
						    NetNet*idx_net = new NetNet(scope, scope->local_symbol(),
										NetNet::REG, &netvector_t::atom2s32);
						    idx_net->set_line(*this);
						    idx_net->local_flag(true);
						    PExpr*pred_pe = with_constraints().front();
						    NetExpr*pred_expr = pred_pe
							  ? elab_and_eval(des, scope, pred_pe, -1, false)
							  : nullptr;
						    if (pred_expr) {
							  vector<NetExpr*> argv(5);
							  argv[0] = obj_expr;
							  NetESignal*iter_e = new NetESignal(iter_net);
							  iter_e->set_line(*this);
							  argv[1] = iter_e;
							  NetESignal*keys_e = new NetESignal(keys_net);
							  keys_e->set_line(*this);
							  argv[2] = keys_e;
							  NetESignal*idx_e = new NetESignal(idx_net);
							  idx_e->set_line(*this);
							  argv[3] = idx_e;
							  argv[4] = pred_expr;
							  string sys_name = string("$ivl_queue_method$") +
								(method_name == "sort"  ? "sort_with"
								 : method_name == "rsort" ? "rsort_with"
								 : "unique_with_kx");
							  NetSTask*sys = new NetSTask(
								sys_name.c_str(),
								IVL_SFUNC_AS_TASK_IGNORE, argv);
							  sys->set_line(*this);
							  return sys;
						    }
					      }
					}
					/* No with-clause (or fallback): default compare. */
					vector<NetExpr*> argv(1);
					argv[0] = obj_expr;
					const char*sys_name =
					      (method_name == "sort")  ? "$ivl_queue_method$sort"  :
					      (method_name == "rsort") ? "$ivl_queue_method$rsort" :
					                                 "$ivl_queue_method$unique";
					NetSTask*sys = new NetSTask(sys_name,
								    IVL_SFUNC_AS_TASK_IGNORE,
								    argv);
					sys->set_line(*this);
					return sys;
				  }
				  cerr << get_fileline() << ": sorry: '"
				       << method_name
				       << "()' array sorting method is not currently supported."
				       << endl;
				  des->errors += 1;
				  delete obj_expr;
				  return 0;
			    } else if (method_name=="shuffle") {
				  if (gn_system_verilog()) {
					/* Phase 63b/Q-methods (gap close): wire to %qshuffle. */
					vector<NetExpr*> argv(1);
					argv[0] = obj_expr;
					NetSTask*sys = new NetSTask("$ivl_queue_method$shuffle",
								    IVL_SFUNC_AS_TASK_IGNORE, argv);
					sys->set_line(*this);
					return sys;
			  }
			  cerr << get_fileline() << ": sorry: 'shuffle()' "
			          "array sorting method is not currently supported."
			       << endl;
			  des->errors += 1;
			  delete obj_expr;
			  return 0;
		    }
	      }

      if (obj_uarray && method_name == "reverse") {
	    static const std::vector<perm_string> no_parms;
	    return elaborate_sys_task_method_(des, scope, obj_expr, obj_type,
					      method_name,
					      "$ivl_uarray_method$reverse",
					      no_parms);
      }

      if (obj_uarray && (method_name == "sort" || method_name == "rsort")) {
	    static const std::vector<perm_string> no_parms;
	    const char*sys_name = (method_name == "sort")
		  ? "$ivl_uarray_method$sort" : "$ivl_uarray_method$rsort";
	    return elaborate_sys_task_method_(des, scope, obj_expr, obj_type,
					      method_name, sys_name, no_parms);
      }

      if (obj_uarray && method_name == "shuffle") {
	    static const std::vector<perm_string> no_parms;
	    return elaborate_sys_task_method_(des, scope, obj_expr, obj_type,
					      method_name,
					      "$ivl_uarray_method$shuffle",
					      no_parms);
      }

      if (obj_uarray && method_name == "delete" && parms_.size() == 1) {
	    static const std::vector<perm_string> parm_names = {
		  perm_string::literal("index")
	    };

	    return elaborate_sys_task_method_(des, scope, obj_expr, obj_type, method_name,
					      "$ivl_darray_method$delete",
					      parm_names);
      }

      if (const netqueue_t*obj_queue = dynamic_cast<const netqueue_t*>(obj_type)) {
	    const netdarray_t*use_darray = obj_queue;
	    if (!use_darray) {
		  delete obj_expr;
		  return 0;
	    }
	    if (method_name == "push_back") {
		  static const std::vector<perm_string> parm_names = {
			perm_string::literal("item")
		  };

		  return elaborate_queue_method_(des, scope, obj_expr, use_darray, method_name,
						 "$ivl_queue_method$push_back",
						 parm_names);
	    } else if (method_name == "push_front") {
		  static const std::vector<perm_string> parm_names = {
			perm_string::literal("item")
		  };

		  return elaborate_queue_method_(des, scope, obj_expr, use_darray, method_name,
						 "$ivl_queue_method$push_front",
						 parm_names);
	    } else if (method_name == "insert") {
		  static const std::vector<perm_string> parm_names = {
			perm_string::literal("index"),
			perm_string::literal("item")
		  };

		  return elaborate_queue_method_(des, scope, obj_expr, use_darray, method_name,
						 "$ivl_queue_method$insert",
						 parm_names);
	    } else if (method_name == "pop_front") {
		  return elaborate_method_func_(scope, obj_expr,
		                                use_darray->element_type(),
		                                method_name,
		                                "$ivl_queue_method$pop_front");
	    } else if (method_name == "pop_back") {
		  return elaborate_method_func_(scope, obj_expr,
		                                use_darray->element_type(),
		                                method_name,
		                                "$ivl_queue_method$pop_back");
	    }
      }

      if (const netclass_t*class_type = dynamic_cast<const netclass_t*>(obj_type)) {
	    if (!class_type->scope_ready()) {
		  if (netclass_t*visible_class = ensure_visible_class_type(des, scope,
								       class_type->get_name()))
			class_type = visible_class;
	    }
	    perm_string cname = class_type->get_name();
	    if (cname == perm_string::literal("process")
		&& (method_name == perm_string::literal("kill")
		    || method_name == perm_string::literal("await")
		    || method_name == perm_string::literal("suspend")
		    || method_name == perm_string::literal("resume"))) {
		  static const std::vector<perm_string> no_parm_names;
		  const char*sys_task_name;
		  if (method_name == perm_string::literal("kill"))
			sys_task_name = "$ivl_process$kill";
		  else if (method_name == perm_string::literal("await"))
			sys_task_name = "$ivl_process$await";
		  else if (method_name == perm_string::literal("suspend"))
			sys_task_name = "$ivl_process$suspend";
		  else
			sys_task_name = "$ivl_process$resume";
		  return elaborate_sys_task_method_(des, scope, obj_expr, obj_type,
						    method_name, sys_task_name,
						    no_parm_names);
	    }
	    if (method_name == perm_string::literal("set_randstate")
		|| method_name == perm_string::literal("srandom")) {
		  delete obj_expr;
		  NetBlock*noop = new NetBlock(NetBlock::SEQU, 0);
		  noop->set_line(*this);
		  return noop;
	    }
	      // Built-in mailbox task methods: generate real opcodes.
	    if (cname == perm_string::literal("mailbox")) {
		  if (method_name == perm_string::literal("put")) {
			static const std::vector<perm_string> parm_names = {
			      perm_string::literal("message")
			};
			return elaborate_sys_task_method_(des, scope, obj_expr, obj_type,
							  method_name, "$ivl_mailbox$put",
							  parm_names);
		  }
		  if (method_name == perm_string::literal("get")) {
			static const std::vector<perm_string> parm_names = {
			      perm_string::literal("message")
			};
			return elaborate_sys_task_method_(des, scope, obj_expr, obj_type,
							  method_name, "$ivl_mailbox$get",
							  parm_names);
		  }
		  if (method_name == perm_string::literal("peek")) {
			static const std::vector<perm_string> parm_names = {
			      perm_string::literal("message")
			};
			return elaborate_sys_task_method_(des, scope, obj_expr, obj_type,
							  method_name, "$ivl_mailbox$peek",
							  parm_names);
		  }
		  if (method_name == perm_string::literal("try_put")) {
			static const std::vector<perm_string> parm_names = {
			      perm_string::literal("message")
			};
			return elaborate_sys_task_method_(des, scope, obj_expr, obj_type,
							  method_name, "$ivl_mailbox$try_put",
							  parm_names);
		  }
		  if (method_name == perm_string::literal("try_get")) {
			static const std::vector<perm_string> parm_names = {
			      perm_string::literal("message")
			};
			return elaborate_sys_task_method_(des, scope, obj_expr, obj_type,
							  method_name, "$ivl_mailbox$try_get",
							  parm_names);
		  }
		  if (method_name == perm_string::literal("try_peek")) {
			static const std::vector<perm_string> parm_names = {
			      perm_string::literal("message")
			};
			return elaborate_sys_task_method_(des, scope, obj_expr, obj_type,
							  method_name, "$ivl_mailbox$try_peek",
							  parm_names);
		  }
		  if (method_name == perm_string::literal("num")) {
			static const std::vector<perm_string> no_parm_names;
			return elaborate_sys_task_method_(des, scope, obj_expr, obj_type,
							  method_name, "$ivl_mailbox$num",
							  no_parm_names);
		  }
	    }
	      // Built-in semaphore task methods: generate real opcodes.
	      // get/put/try_get accept an optional keycount argument (default 1).
	    if (cname == perm_string::literal("semaphore")) {
		  static const std::vector<perm_string> sem_no_parms;
		  static const std::vector<perm_string> sem_one_parm = {
			perm_string::literal("keycount")
		  };
		  if (method_name == perm_string::literal("get")) {
			return elaborate_sys_task_method_(des, scope, obj_expr, obj_type,
							  method_name, "$ivl_semaphore$get",
							  parms_.empty() ? sem_no_parms : sem_one_parm);
		  }
		  if (method_name == perm_string::literal("put")) {
			return elaborate_sys_task_method_(des, scope, obj_expr, obj_type,
							  method_name, "$ivl_semaphore$put",
							  parms_.empty() ? sem_no_parms : sem_one_parm);
		  }
		  if (method_name == perm_string::literal("try_get")) {
			return elaborate_sys_task_method_(des, scope, obj_expr, obj_type,
							  method_name, "$ivl_semaphore$try_get",
							  parms_.empty() ? sem_no_parms : sem_one_parm);
		  }
	    }
	    // Built-in SV randomize() method: generates %randomize opcode.
	    // This is not a regular class task; handle it specially so that
	    // both expression context (elab_expr.cc) and statement context
	    // (void'(obj.randomize())) work correctly.
	    if (method_name == perm_string::literal("randomize")) {
		  static const std::vector<perm_string> no_parms;
		  return elaborate_method_func_(scope, obj_expr,
					        &netvector_t::atom2s32,
					        method_name,
					        "$ivl_class_method$randomize");
	    }

	    NetScope*task = class_type->resolve_method_call_scope(des, method_name);
	    if (trace_class_method) {
                  cerr << get_fileline() << ": trace task-method "
                       << "class=" << class_type->get_name()
                       << " class_ptr=" << (const void*)class_type
                       << " scope_ready=" << class_type->scope_ready()
                       << " class_scope_ptr=" << (const void*)class_type->class_scope()
                       << " class_scope=" << scope_text(class_type->class_scope())
                       << " method=" << method_name
                       << " found=" << scope_text(task)
                       << endl;
            }
	    if (task == 0) {
		  pform_name_t full_path = use_path;
		  full_path.push_back(name_component_t(method_name));
		  if (is_tlm_forward_task_stub_candidate_(use_path, method_name)) {
			delete obj_expr;
			NetBlock*noop = new NetBlock(NetBlock::SEQU, 0);
			noop->set_line(*this);
			return noop;
		  }
		  if (is_uvm_compile_progress_task_stub_candidate_(full_path)) {
			delete obj_expr;
			NetBlock*noop = new NetBlock(NetBlock::SEQU, 0);
			noop->set_line(*this);
			return noop;
		  }
		  // obj.constraint_mode(en): enable/disable all constraints on the object.
		  // Emit a separate %constraint_mode N for each N in the class.
		  if (method_name == perm_string::literal("constraint_mode")
		      && parms_.size() == 1) {
			const netclass_t*ctype = dynamic_cast<const netclass_t*>(obj_type);
			if (ctype && ctype->constraint_ir_count() > 0) {
			      NetBlock*blk = new NetBlock(NetBlock::SEQU, 0);
			      blk->set_line(*this);
			      NetExpr*mode_expr = elab_sys_task_arg(des, scope,
						method_name, 0, parms_[0].parm);
			      for (size_t ci = 0; ci < ctype->constraint_ir_count(); ++ci) {
				    NetExpr*obj_copy = obj_expr->dup_expr();
				    NetExpr*mode_copy = mode_expr->dup_expr();
				    NetExpr*cid_expr = new NetEConst(
					  verinum((uint64_t)ci, 32));
				    cid_expr->set_line(*this);
				    vector<NetExpr*> argv(3);
				    argv[0] = obj_copy;
				    argv[1] = mode_copy;
				    argv[2] = cid_expr;
				    NetSTask*sys = new NetSTask(
					  "$ivl_class_method$constraint_mode",
					  IVL_SFUNC_AS_TASK_IGNORE, argv);
				    sys->set_line(*this);
				    blk->append(sys);
			      }
			      delete obj_expr;
			      delete mode_expr;
			      return blk;
			}
			delete obj_expr;
			NetBlock*noop = new NetBlock(NetBlock::SEQU, 0);
			noop->set_line(*this);
			return noop;
		  }
		  if (method_name == perm_string::literal("constraint_mode")) {
			delete obj_expr;
			NetBlock*noop = new NetBlock(NetBlock::SEQU, 0);
			noop->set_line(*this);
			return noop;
		  }
		  if (method_name == perm_string::literal("rand_mode")) {
			static const std::vector<perm_string> parm_en = {
			      perm_string::literal("en")
			};
			if (parms_.size() == 1) {
			      return elaborate_sys_task_method_(des, scope,
							       obj_expr, obj_type,
							       method_name,
							       "$ivl_class_method$rand_mode",
							       parm_en);
			}
			  // Query form (0 args): noop stub
			delete obj_expr;
			NetBlock*noop = new NetBlock(NetBlock::SEQU, 0);
			noop->set_line(*this);
			return noop;
		  }

		  // Covergroup sample(): emit system task that pushes coverpoint
		  // values (from the parent object's properties) + the cg object,
		  // then calls %covgrp/sample.
		  if (method_name == perm_string::literal("sample")) {
			const netclass_t*cgtype = dynamic_cast<const netclass_t*>(obj_type);
			if (cgtype && cgtype->is_covergroup()) {
			      unsigned ncp = cgtype->covgrp_ncoverpoints();
			      vector<NetExpr*> argv;
			      // arg 0 = cg object expression
			      argv.push_back(obj_expr);

			      // args 1..ncp: coverpoint values from parent class
			      NetNet* this_net = find_implicit_this_handle(des, scope);
			      if (this_net) {
				    for (unsigned cpi = 0; cpi < ncp; ++cpi) {
					  int pp = cgtype->covgrp_cp_parent_prop(cpi);
					  if (pp >= 0) {
					      NetESignal* sig = new NetESignal(this_net);
					      sig->set_line(*this);
					      NetEProperty* prop = new NetEProperty(sig, pp, nullptr);
					      prop->set_line(*this);
					      argv.push_back(prop);
					  } else {
					      // Unknown coverpoint: push zero
					      argv.push_back(new NetEConst(verinum((uint64_t)0, 32)));
					  }
				    }
			      }

			      NetSTask* sys = new NetSTask(
				    "$ivl_class_method$covgrp_sample",
				    IVL_SFUNC_AS_TASK_IGNORE, argv);
			      sys->set_line(*this);
			      return sys;
			}
		  }

		  // Covergroup get_inst_coverage(): handled in elab_expr.cc.
		  // For task context (e.g. void'(cg.get_inst_coverage())), emit noop.
		  if (method_name == perm_string::literal("get_inst_coverage")) {
			const netclass_t*cgtype = dynamic_cast<const netclass_t*>(obj_type);
			if (cgtype && cgtype->is_covergroup()) {
			      delete obj_expr;
			      NetBlock*noop = new NetBlock(NetBlock::SEQU, 0);
			      noop->set_line(*this);
			      return noop;
			}
		  }

		    // If an implicit this was added it is not an error if we
		    // don't find a method. It might actually be a call to a
		    // function outside of the class.
		  // If the class scope was not fully ready (due to the
		  // recursion guard during elaboration of mutually-referencing
		  // class hierarchies), treat the missing inherited method as
		  // a compile-progress warning and emit a noop stub so
		  // elaboration can continue producing a VVP file.
		  if (!class_type->scope_ready() || class_type->is_covergroup()) {
			// Phase 54: deferred interface task dispatch.  When the
			// caller is a parameterized class body that elaborates
			// before the interface's testbench instance scope is
			// populated, the regular method lookup fails and we
			// fall through here.  For interface types where the
			// pform definition exists and contains the requested
			// task, emit a deferred NetSTask with name
			// "$ivl_iface_late$<iface>$<method>".  The caller-
			// supplied arguments are passed through as parms; the
			// task will use the .var auto-init zero defaults for
			// any unspecified ports (sufficient for the common
			// OpenTitan apply_reset/drive_rst_pin pattern, since
			// `repeat (0)` is a no-op and rst_n_scheme=0 picks the
			// sync-deassert path that still toggles rst_n).
			// tgt-vvp recognizes the name prefix, walks the design
			// for a unique IVL_SCT_MODULE scope whose module_name
			// matches <iface>, finds the child task scope by
			// basename, and emits %callf/void with the resolved
			// scope handle.
			if (class_type->is_interface() && gn_system_verilog()) {
			      auto pmod_it = pform_modules.find(class_type->get_name());
			      if (pmod_it != pform_modules.end()
				  && pmod_it->second->is_interface) {
				    auto task_it =
					  pmod_it->second->tasks.find(method_name);
				    if (task_it != pmod_it->second->tasks.end()) {
				    PTask*ptask = task_it->second;
				    std::string defer_name = "$ivl_iface_late$";
				    defer_name += class_type->get_name().str();
				    defer_name += "$";
				    defer_name += method_name.str();
				    std::vector<NetExpr*> argv;
				    for (size_t pi = 0 ; pi < parms_.size() ; pi += 1) {
					  if (!parms_[pi].parm) {
						argv.push_back(0);
						continue;
					  }
					  NetExpr*ev =
						elab_sys_task_arg(des, scope,
								  method_name,
								  pi, parms_[pi].parm);
					  argv.push_back(ev);
				    }
				    // Pad missing args with the pform default
				    // expressions evaluated in the caller's
				    // scope.  This preserves SV semantics where
				    // unsupplied args use the task's declared
				    // default (e.g. apply_reset(reset_width_clks
				    // = $urandom_range(50, 100), ...) requires
				    // a non-zero width or rst_n won't actually
				    // toggle through 0 to fire negedge events).
				    const std::vector<pform_tf_port_t>*pports =
					  ptask->peek_ports();
				    if (pports) {
					  for (size_t pi = parms_.size();
					       pi < pports->size() ; pi += 1) {
						pform_tf_port_t pp = (*pports)[pi];
						if (pp.defe) {
						      NetExpr*ev =
							    elab_sys_task_arg(
								des, scope,
								method_name,
								pi, pp.defe);
						      argv.push_back(ev);
						} else {
						      argv.push_back(0);
						}
					  }
				    }
				    perm_string pn = perm_string::literal(strdup(defer_name.c_str()));
				    NetSTask*sys = new NetSTask(pn.str(),
								IVL_SFUNC_AS_TASK_IGNORE,
								argv);
				    sys->set_line(*this);
				    delete obj_expr;
				    return sys;
				    }
			      }
			}
			cerr << get_fileline() << ": warning: "
			     << "Enable of unknown task ``"
			     << method_name << "'' ignored"
			     << " (class " << class_type->get_name()
			     << (class_type->is_covergroup() ? " is covergroup stub" : " scope incomplete")
			     << "; compile-progress fallback)."
			     << endl;
			delete obj_expr;
			NetBlock*noop = new NetBlock(NetBlock::SEQU, 0);
			noop->set_line(*this);
			return noop;
		  }
		  if (!add_this_flag) {
			cerr << get_fileline() << ": error: "
			     << "Can't find task " << method_name
			     << " in class " << class_type->get_name() << endl;
			des->errors += 1;
		  }
		  delete obj_expr;
		  return 0;
	    }

	    if (debug_elaborate) {
		  cerr << get_fileline() << ": PCallTask::elaborate_method_: "
		       << "Elaborate " << class_type->get_name()
		       << " method " << task->basename() << endl;
	    }

	    // Virtual-interface task dispatch: the resolved task lives in an
	    // interface scope and is NOT a class method, so there is no `this`
	    // first port. Drop the receiver expression and call as a free task.
	    if (class_type->is_interface()) {
		  delete obj_expr;
		  return elaborate_build_call_(des, scope, task, nullptr);
	    }
	    return elaborate_build_call_(des, scope, task, obj_expr, explicit_super);
      }

      if (is_multi_hop_collection_task_stub_candidate_(use_path, method_name)) {
	    if (getenv("IVL_PHASE50D_TRACE"))
		  fprintf(stderr, "[P50D-NOOP] method=%s use_path.size=%zu obj_type=%s\n",
			  method_name.str(), use_path.size(),
			  obj_type ? typeid(*obj_type).name() : "<null>");
	    delete obj_expr;
	    NetBlock*noop = new NetBlock(NetBlock::SEQU, 0);
	    noop->set_line(*this);
	    return noop;
      }

      // For TLM stub candidates (m_if.put, m_imp.get, etc.) on non-class types
      // (e.g., base-class instantiations with IMP=int where the type parameter
      // is not a class), return a silent noop. Concrete specializations with a
      // real class type will have succeeded above via the class method lookup.
      if (is_tlm_forward_task_stub_candidate_(use_path, method_name)) {
	    delete obj_expr;
	    NetBlock*noop = new NetBlock(NetBlock::SEQU, 0);
	    noop->set_line(*this);
	    return noop;
      }

      delete obj_expr;
      return 0;
}

/*
 * If during elaboration we determine (for sure) that we are calling a
 * task (and not just a void function) then this method tests if that
 * task call is allowed in the current context. If so, return true. If
 * not, print an error message and return false;
 */
bool PCallTask::test_task_calls_ok_(Design*des, const NetScope*scope) const
{
      if (scope->in_func()) {
	    cerr << get_fileline() << ": error: Functions cannot enable/call "
	            "tasks." << endl;
	    des->errors += 1;
	    return false;
      }

      if (scope->in_final()) {
	    cerr << get_fileline() << ": error: final procedures cannot "
	            "enable/call tasks." << endl;
	    des->errors += 1;
	    return false;
      }

      return true;
}

NetProc *PCallTask::elaborate_non_void_function_(Design *des, NetScope *scope) const
{
	// Generate a function call version of this task call.
      PExpr*rval = new PECallFunction(package_, path_, parms_);
      rval->set_file(get_file());
      rval->set_lineno(get_lineno());
	// Generate an assign to nothing.
      PAssign*tmp = new PAssign(0, rval);
      tmp->set_file(get_file());
      tmp->set_lineno(get_lineno());
      if (!void_cast_) {
	    cerr << get_fileline() << ": warning: User function '"
		 << peek_tail_name(path_) << "' is being called as a task." << endl;
      }

	// Elaborate the assignment to a dummy variable.
      return tmp->elaborate(des, scope);
}

NetProc* PCallTask::elaborate_function_(Design*des, NetScope*scope) const
{
      NetFuncDef*func = nullptr;

	// When a package_ pointer is set (from PACKAGE_IDENTIFIER::func grammar
	// or recovered via pform_make_call_task), look up the function ONLY in
	// the package scope. Do not fall back to the caller scope: that would
	// re-find a same-named class method on `this` and cause infinite
	// virtual-dispatch recursion (see csr_utils_pkg::reset_asserted being
	// called from dv_base_env_cfg::reset_asserted).
      if (package_) {
	    if (NetScope*pkg_scope = des->find_package(package_->pscope_name()))
		  func = des->find_function(pkg_scope, path_);
	    if (!func) return nullptr;
      } else {
	    func = des->find_function(scope, path_);

	      // If the normal lookup failed and path_ has 2 components, check
	      // if the first component is a package name (Form 2 of pkg::fn
	      // parsed as a hierarchical path inside the same package body
	      // before it is registered).
	    if (!func && path_.size() == 2) {
		  perm_string possible_pkg = path_.front().name;
		  if (NetScope*pkg_scope = des->find_package(possible_pkg)) {
			pform_name_t tail_path;
			tail_path.push_back(path_.back());
			func = des->find_function(pkg_scope, tail_path);
		  }
	    }
      }

	// This is not a function, so this task call cannot be a function
	// call with a missing return assignment.
      if (!func)
	    return nullptr;

      if (gn_system_verilog() && func->is_void())
	    return elaborate_void_function_(des, scope, func);

      return elaborate_non_void_function_(des, scope);
}

NetProc* PCallTask::elaborate_void_function_(Design*des, NetScope*scope,
					     NetFuncDef*def) const
{
      NetScope*dscope = def->scope();

      if (debug_elaborate) {
	    cerr << get_fileline() << ": PCallTask::elaborate_void_function_: "
		 << "function void " << scope_path(dscope)
		 << endl;
      }

	// If we haven't already elaborated the function, do so now.
	// This allows elaborate_build_call_ to elide the function call
	// if the function body is empty.
      if (dscope->elab_stage() < 3) {
	    const PFunction*pfunc = dscope->func_pform();
	    ivl_assert(*this, pfunc);
	    elaborate_function_outside_caller_fork_(des, pfunc, dscope);
      }
      return elaborate_build_call_(des, scope, dscope, 0);
}

NetProc* PCallTask::elaborate_build_call_(Design*des, NetScope*scope,
					  NetScope*task, NetExpr*use_this,
					  bool super_call) const
{
	      const NetBaseDef*def = 0;
		      if (task->type() == NetScope::TASK) {
			    def = task->task_def();
			    if (def == 0 || def->proc() == 0) {
				  const PTask*ptask = task->task_pform();
				  if (ptask) {
					ptask->elaborate_sig(des, task);
					if (task->task_def() && task->task_def()->proc() == 0)
					      elaborate_task_outside_caller_fork_(des, ptask, task);
				def = task->task_def();
			  }
		    }

	      // OK, this is certainly a TASK that I'm calling. Make
	      // sure that is OK where I am. Even if this test fails,
	      // continue with the elaboration as if it were OK so
	      // that we can catch more errors.
	    test_task_calls_ok_(des, scope);

	    if (void_cast_) {
		  cerr << get_fileline() << ": error: void casting user task '"
		       << peek_tail_name(path_) << "' is not allowed." << endl;
		  des->errors++;
	    }

	      } else if (task->type() == NetScope::FUNC) {
		    const NetFuncDef*tmp = task->func_def();
		    if (tmp == 0 || tmp->proc() == 0) {
			  // Class-scoped method calls can reach this path before the
			  // function has been elaborated. Mirror the on-demand behavior
			  // used by elaborate_void_function_().
			const PFunction*pfunc = task->func_pform();
			if (pfunc)
		      elaborate_function_outside_caller_fork_(des, pfunc, task);
		tmp = task->func_def();
	    }
	    if (tmp == 0) {
		  cerr << get_fileline() << ": internal error: function "
		       << scope_path(task)
		       << " has no elaborated function definition." << endl;
		  des->errors += 1;
		  return 0;
	    }
	    if (!tmp->is_void())
		  return elaborate_non_void_function_(des, scope);
	    def = tmp;

	    if (void_cast_) {
		  cerr << get_fileline() << ": error: void casting user void function '"
		       << peek_tail_name(path_) << "' is not allowed." << endl;
		  des->errors++;
	    }
      }

      /* The caller has checked the parms_ size to make sure it
	   matches the task definition, so we can just use the task
	   definition to get the parm_count. */

      if (def == 0) {
	    if (gn_system_verilog()) {
		  perm_string tail_name = peek_tail_name(path_);
		  bool suppress_noop_warn =
			(tail_name == perm_string::literal("start_item")) ||
			(tail_name == perm_string::literal("finish_item"));
		  if (!suppress_noop_warn) {
			cerr << get_fileline() << ": warning: "
			     << "Unable to elaborate call to task/function "
			     << scope_path(task)
			     << " (no definition available, using no-op fallback)." << endl;
		  }
		  NetBlock*noop = new NetBlock(NetBlock::SEQU, 0);
		  noop->set_line(*this);
		  return noop;
	    }
	    cerr << get_fileline() << ": sorry: "
		 << "Unable to elaborate call to task/function "
		 << scope_path(task)
		 << " (no definition available)." << endl;
	    des->errors += 1;
	    return 0;
      }

      unsigned parm_count = def->port_count();

      if (parms_.size() > parm_count) {
	    cerr << get_fileline() << ": error: "
		 << "Too many arguments (" << parms_.size()
		 << ", expecting " << parm_count << ")"
		 << " in call to task." << endl;
	    des->errors += 1;
      }

      NetBlock*block = new NetBlock(NetBlock::SEQU, 0);
      block->set_line(*this);

      if (!use_this && scope_method_uses_implicit_this(des, task)) {
	    if (path_.size() == 1) {
		  // Implicit local class method call used as a statement
		  // (including void functions): fill the hidden `this` port
		  // from the enclosing method scope instead of treating it as
		  // a missing user argument.
		  NetNet*this_net = find_implicit_this_handle(des, scope);
		  if (this_net) {
			NetESignal*sig_this = new NetESignal(this_net);
			sig_this->set_line(*this);
			use_this = sig_this;
		  }
	    } else if (path_.size() >= 2) {
		  NetENull*null_this = new NetENull;
		  null_this->set_line(*this);
		  use_this = null_this;
	    }
      }

	/* Detect the case where the definition of the task is known
	   empty. In this case, we need not bother with calls to the
	   task, all the assignments, etc. Just return a no-op. */

      if (const NetBlock*tp = dynamic_cast<const NetBlock*>(def->proc())) {
	    if (tp->proc_first() == 0) {
		  bool keep_for_dynamic_dispatch = false;
		  if (!super_call && use_this && task->parent()
		      && task->parent()->type() == NetScope::CLASS) {
			/* Preserve empty base-method calls for dynamic dispatch.
			 * UVM registry wrappers rely on queue/base-handle calls such as
			 * uvm_deferred_init[idx].initialize(), where the static target
			 * is the empty uvm_object_wrapper.initialize() prototype and the
			 * real work lives in derived overrides selected at runtime. */
			keep_for_dynamic_dispatch = true;
		  }
		  if (!keep_for_dynamic_dispatch) {
			if (debug_elaborate) {
			      cerr << get_fileline() << ": PCallTask::elaborate_build_call_: "
				   << "Eliding call to empty task " << task->basename() << endl;
			}
			return block;
		  }
	    }
      }

        /* If this is an automatic task, generate a statement to
           allocate the local storage. */

      if (task->is_auto()) {
	    NetAlloc*ap = new NetAlloc(task);
	    ap->set_line(*this);
	    block->append(ap);
      }

	/* If this is a method call, then the use_this pointer will
	   have an expression for the "this" argument. The "this"
	   argument is the first argument of any method, so emit it
	   here. */

      if (use_this) {
	    ivl_assert(*this, def->port_count() >= 1);
	    NetNet*port = def->port(0);
	    ivl_assert(*this, port->port_type()==NetNet::PINPUT);

	    NetAssign_*lv = new NetAssign_(port);
	    NetAssign*pr = new NetAssign(lv, use_this);
	    pr->set_line(*this);
	    block->append(pr);
      }

	/* Generate assignment statement statements for the input and
	   INOUT ports of the task. These are managed by writing
	   assignments with the task port the l-value and the passed
	   expression the r-value. We know by definition that the port
	   is a reg type, so this elaboration is pretty obvious. */

      unsigned int off = use_this ? 1 : 0;

      auto args = map_named_args(des, def, parms_, off);
      for (unsigned int idx = off; idx < parm_count; idx++) {
	    size_t parms_idx = idx - off;

	    NetNet*port = def->port(idx);
	    ivl_assert(*this, port->port_type() != NetNet::NOT_A_PORT);
	    if (port->port_type() == NetNet::POUTPUT)
		  continue;

	      /* SV §7.4.2: 1D static unpacked array port — generate
	       * element-wise copy-in when the argument is a bare array
	       * identifier so that every element is transferred, not just
	       * the first word. */
	    if (gn_system_verilog()
		&& port->unpacked_dimensions() == 1
		&& args[parms_idx]) {
		  if (PEIdent *arg_id = dynamic_cast<PEIdent*>(args[parms_idx])) {
			if (arg_id->path().back().index.empty()) {
			      symbol_search_results arg_sr;
			      symbol_search(arg_id, des, scope,
					    arg_id->path(), arg_id->lexical_pos(), &arg_sr);
			      if (arg_sr.net && arg_sr.net->unpacked_dimensions() == 1) {
				    NetNet *arg_net = arg_sr.net;
				    const netranges_t& dims = port->unpacked_dims();
				    long lo = std::min(dims[0].get_msb(), dims[0].get_lsb());
				    long hi = std::max(dims[0].get_msb(), dims[0].get_lsb());
				    bool elem_ok = true;
				    for (long elem = lo; elem <= hi && elem_ok; elem++) {
					  list<long> idx_l(1, elem);
					  NetExpr *pidx = normalize_variable_unpacked(port, idx_l);
					  NetExpr *aidx = normalize_variable_unpacked(arg_net, idx_l);
					  if (!pidx || !aidx) {
						delete pidx; delete aidx;
						elem_ok = false;
						break;
					  }
					  pidx->set_line(*this);
					  aidx->set_line(*this);
					  NetAssign_*elv = new NetAssign_(port);
					  elv->set_word(pidx);
					  NetESignal*erv = new NetESignal(arg_net, aidx);
					  erv->set_line(*this);
					  NetAssign*pr = new NetAssign(elv, erv);
					  pr->set_line(*this);
					  block->append(pr);
				    }
				    if (elem_ok)
					  continue;
			      }
			}
		  }
	    }

	    NetAssign_*lv = new NetAssign_(port);
	    unsigned wid = count_lval_width(lv);
	    ivl_variable_type_t lv_type = lv->expr_type();

	    NetExpr*rv = 0;

	    if (args[parms_idx]) {
		  rv = elaborate_rval_expr(des, scope, port->net_type(),
					   args[parms_idx]);
		  if (const NetEEvent*evt = dynamic_cast<NetEEvent*> (rv)) {
			cerr << evt->get_fileline() << ": error: An event '"
			     << evt->event()->name() << "' can not be a user "
			      "task argument." << endl;
			des->errors += 1;
			continue;
		  }

	    } else if (def->port_defe(idx)) {
		  if (! gn_system_verilog()) {
			cerr << get_fileline() << ": internal error: "
			     << "Found (and using) default task expression "
			        "requires SystemVerilog." << endl;
			des->errors += 1;
		  }
		  rv = def->port_defe(idx)->dup_expr();
		  if (lv_type==IVL_VT_BOOL||lv_type==IVL_VT_LOGIC)
			rv = pad_to_width(rv, wid, *this);

	    } else {
		  cerr << get_fileline() << ": error: "
		       << "Missing argument " << (idx+1)
		       << " of call to task." << endl;
		  des->errors += 1;
		  continue;
	    }

	    NetAssign*pr = new NetAssign(lv, rv);
	    pr->set_line(*this);
	    block->append(pr);
      }

	/* Generate the task call proper... */
      NetUTask*cur = new NetUTask(task, super_call);
      cur->set_line(*this);
      block->append(cur);

	/* Generate assignment statements for the output and INOUT
	   ports of the task. The l-value in this case is the
	   expression passed as a parameter, and the r-value is the
	   port to be copied out.

	   We know by definition that the r-value of this copy-out is
	   the port, which is a reg. The l-value, however, may be any
	   expression that can be a target to a procedural
	   assignment, including a memory word. */

      for (unsigned int idx = off; idx < parm_count; idx++) {

	    size_t parms_idx = idx - off;

	    NetNet*port = def->port(idx);

	      /* Skip input ports. */
	    ivl_assert(*this, port->port_type() != NetNet::NOT_A_PORT);
	    if (port->port_type() == NetNet::PINPUT)
		  continue;

	      /* SV §7.4.2: 1D static unpacked array port — element-wise copy-out. */
	    if (gn_system_verilog()
		&& port->unpacked_dimensions() == 1
		&& args[parms_idx]) {
		  if (PEIdent *arg_id = dynamic_cast<PEIdent*>(args[parms_idx])) {
			if (arg_id->path().back().index.empty()) {
			      symbol_search_results arg_sr;
			      symbol_search(arg_id, des, scope,
					    arg_id->path(), arg_id->lexical_pos(), &arg_sr);
			      if (arg_sr.net && arg_sr.net->unpacked_dimensions() == 1) {
				    NetNet *arg_net = arg_sr.net;
				    const netranges_t& dims = port->unpacked_dims();
				    long lo = std::min(dims[0].get_msb(), dims[0].get_lsb());
				    long hi = std::max(dims[0].get_msb(), dims[0].get_lsb());
				    bool elem_ok = true;
				    for (long elem = lo; elem <= hi && elem_ok; elem++) {
					  list<long> idx_l(1, elem);
					  NetExpr *pidx = normalize_variable_unpacked(port, idx_l);
					  NetExpr *aidx = normalize_variable_unpacked(arg_net, idx_l);
					  if (!pidx || !aidx) {
						delete pidx; delete aidx;
						elem_ok = false;
						break;
					  }
					  pidx->set_line(*this);
					  aidx->set_line(*this);
					  NetAssign_*elv = new NetAssign_(arg_net);
					  elv->set_word(aidx);
					  NetESignal*erv = new NetESignal(port, pidx);
					  erv->set_line(*this);
					  NetAssign*pr = new NetAssign(elv, erv);
					  pr->set_line(*this);
					  block->append(pr);
				    }
				    if (elem_ok)
					  continue;
			      }
			}
		  }
	    }

	      /* Elaborate an l-value version of the port expression
		 for output and inout ports. If the expression does
		 not exist or is not a valid l-value print an error
		 message. Note that the elaborate_lval method already
		 printed a detailed message for the latter case. */
	    NetAssign_*lv = 0;
	    if (args[parms_idx]) {
		  lv = args[parms_idx]->elaborate_lval(des, scope, false, false);
		  if (lv == 0) {
			cerr << args[parms_idx]->get_fileline() << ": error: "
			     << "I give up on task port " << (idx+1)
			     << " expression: " << *args[parms_idx] << endl;
		  }
	    } else if (port->port_type() == NetNet::POUTPUT) {
		    // Output ports were skipped earlier, so
		    // report the error now.
		  cerr << get_fileline() << ": error: "
		       << "Missing argument " << (idx+1)
		       << " of call to task." << endl;
		  des->errors += 1;
	    }

	    if (lv == 0)
		  continue;

	    NetExpr*rv = new NetESignal(port);

		  /* Handle any implicit cast. */
			unsigned lv_width = count_lval_width(lv);
			ivl_variable_type_t lv_type = lv->expr_type();
			ivl_variable_type_t rv_type = rv->expr_type();
			bool pad_vector_copyback = (lv_type == IVL_VT_BOOL || lv_type == IVL_VT_LOGIC);
			if (lv_type != rv_type) {
			      bool container_copyback_passthrough =
				      (lv_type == IVL_VT_DARRAY || lv_type == IVL_VT_QUEUE) &&
				      (rv_type == IVL_VT_DARRAY || rv_type == IVL_VT_QUEUE);
				      // Keep task copy-back behavior aligned with assignment cast
				      // fallback in netmisc.cc: darray<->queue passes through.
			      if (container_copyback_passthrough) {
				    pad_vector_copyback = false;
			      } else {
			      switch (lv_type) {
				  case IVL_VT_REAL:
				rv = cast_to_real(rv);
				break;
			  case IVL_VT_BOOL:
			rv = cast_to_int2(rv, lv_width);
			break;
			  case IVL_VT_LOGIC:
			rv = cast_to_int4(rv, lv_width);
			break;
				  case IVL_VT_STRING:
				  case IVL_VT_DARRAY:
				  case IVL_VT_QUEUE:
				cerr << get_fileline() << ": warning: "
				     << "limited task port copy-back cast from "
				     << int(rv_type) << " to " << int(lv_type)
				     << "; leaving value uncast." << endl;
				pad_vector_copyback = false;
				break;
				  case IVL_VT_CLASS:
				      // Keep compile-progress class semantics aligned with
				      // netmisc.cc fallback: degrade mismatched copy-back to null.
				delete rv;
				rv = new NetENull();
				rv->set_line(*this);
				pad_vector_copyback = false;
				break;
				  default:
			      /* Don't yet know how to handle this. */
			cerr << get_fileline() << ": warning: "
			     << "unsupported task port copy-back cast from "
			     << int(rv_type) << " to " << int(lv_type)
			     << "; assignment skipped." << endl;
			des->errors += 1;
				delete rv;
				continue;
				}
			      }
			}
			if (pad_vector_copyback)
			      rv = pad_to_width(rv, lv_width, *this);

		  /* Generate the assignment statement. */
		NetAssign*ass = new NetAssign(lv, rv);
	    ass->set_line(*this);

	    block->append(ass);
      }

        /* If this is an automatic task, generate a statement to free
           the local storage. */
      if (task->is_auto()) {
	    NetFree*fp = new NetFree(task);
	    fp->set_line(*this);
	    block->append(fp);
      }

      return block;
}

static bool check_parm_is_const(NetExpr*param)
{
// FIXME: Are these actually needed and are others needed?
//      if (dynamic_cast<NetEConstEnum*>(param)) { cerr << "Enum" << endl; return; }
//      if (dynamic_cast<NetECString*>(param)) { cerr << "String" << endl; return; }
      if (dynamic_cast<NetEConstParam*>(param)) return true;
      if (dynamic_cast<NetECReal*>(param)) return true;
      if (dynamic_cast<NetECRealParam*>(param)) return true;
      if (dynamic_cast<NetEConst*>(param)) return true;

      return false;
}

static bool get_value_as_long(const NetExpr*expr, long&val)
{
      switch(expr->expr_type()) {
	  case IVL_VT_REAL: {
	    const NetECReal*c = dynamic_cast<const NetECReal*> (expr);
	    ivl_assert(*expr, c);
	    verireal tmp = c->value();
	    val = tmp.as_long();
	    break;
	  }

	  case IVL_VT_BOOL:
	  case IVL_VT_LOGIC: {
	    const NetEConst*c = dynamic_cast<const NetEConst*>(expr);
	    ivl_assert(*expr, c);
	    verinum tmp = c->value();
	    if (tmp.is_string()) return false;
	    val = tmp.as_long();
	    break;
	  }

	  default:
	    return false;
      }

      return true;
}

static bool get_value_as_string(const NetExpr*expr, string&str)
{
      switch(expr->expr_type()) {
	  case IVL_VT_REAL:
	    return false;
	    break;

	  case IVL_VT_BOOL:
	  case IVL_VT_LOGIC: {
	    const NetEConst*c = dynamic_cast<const NetEConst*>(expr);
	    ivl_assert(*expr, c);
	    verinum tmp = c->value();
	    if (!tmp.is_string()) return false;
	    str = tmp.as_string();
	    break;
	  }

	  default:
	    return false;
      }

      return true;
}

/* Elaborate an elaboration task. */
bool PCallTask::elaborate_elab(Design*des, NetScope*scope) const
{
      ivl_assert(*this, scope);
      ivl_assert(*this, path_.size() == 1);

      unsigned parm_count = parms_.size();

      perm_string name = peek_tail_name(path_);

      if (!gn_system_verilog()) {
	    cerr << get_fileline() << ": error: Elaboration task '"
	         << name << "' requires SystemVerilog." << endl;
	    des->errors += 1;
	    return false;
      }

      if (name != "$fatal" &&
          name != "$error" &&
          name != "$warning" &&
          name != "$info") {
	    cerr << get_fileline() << ": error: '" << name
	         << "' is not a valid elaboration task." << endl;
	    des->errors += 1;
	    return true;
      }

      vector<NetExpr*>eparms (parm_count);

      bool const_parms = true;
      for (unsigned idx = 0 ;  idx < parm_count ;  idx += 1) {
	    auto &parm = parms_[idx];

	    // Elaboration tasks don't have named parameters
	    if (!parm.name.nil()) {
		  cerr << parm.get_fileline() << ": error: "
		       << "The elaboration system task `" << name
		       << "` has no argument called `" << parm.name
		       << "`." << endl;
		  des->errors++;
	    }

	    eparms[idx] = elab_sys_task_arg(des, scope, name, idx, parm.parm);
	    if (!check_parm_is_const(eparms[idx])) {
		  cerr << get_fileline() << ": error: Elaboration task "
		       << name << "() parameter [" << idx+1 << "] '"
		       << *eparms[idx] << "' is not constant." << endl;
		  des->errors += 1;
		  const_parms = false;
	    }
      }
      if (!const_parms) return true;

	// Drop the $ and convert to upper case for the severity string
      string sstr = name.str()+1;
      transform(sstr.begin(), sstr.end(), sstr.begin(), ::toupper);

      cerr << sstr << ": " << get_fileline() << ":";
      if (parm_count != 0) {
	    unsigned param_start = 0;
	      // Drop the finish number, but check it is actually valid!
	    if (name == "$fatal") {
		  long finish_num = 1;
		  if (!get_value_as_long(eparms[0],finish_num)) {
			cerr << endl;
			cerr << get_fileline() << ": error: Elaboration task "
			        "$fatal() finish number argument must be "
			        "numeric." << endl;;
			des->errors += 1;
			cerr << string(sstr.size()+1, ' ');
		  } else if ((finish_num < 0) || (finish_num > 2)) {
			cerr << endl;
			cerr << get_fileline() << ": error: Elaboration task "
			        "$fatal() finish number argument must be in "
			        "the range [0-2], given '" << finish_num
			     << "'." << endl;;
			des->errors += 1;
			cerr << string(sstr.size()+1, ' ');
		  }
		  param_start += 1;
	    }

	      // FIXME: For now just handle a single string value.
	    string str;
	    if ((parm_count == param_start + 1) && (get_value_as_string(eparms[param_start], str))) {
		  cerr << " " << str;
	    } else if (param_start < parm_count) {
		  cerr << endl;
		  cerr << get_fileline() << ": sorry: Elaboration tasks "
		          "currently only support a single string argument.";
		  des->errors += 1;
	    }
/*
	    cerr << *eparms[0];
	    for (unsigned idx = 1; idx < parm_count; idx += 1) {
	    cerr << ", " << *eparms[idx];
	    }
*/
      }
      cerr << endl;

      cerr << string(sstr.size(), ' ') << "  During elaboration  Scope: "
           << scope->fullname() << endl;

	// For a fatal mark as an error and fail elaboration.
      if (name == "$fatal") {
	    des->errors += 1;
	    return false;
      }

	// For an error just set it as an error.
      if (name == "$error") des->errors += 1;

      return true;
}

/*
 * Elaborate a procedural continuous assign. This really looks very
 * much like other procedural assignments, at this point, but there
 * is no delay to worry about. The code generator will take care of
 * the differences between continuous assign and normal assignments.
 */
NetCAssign* PCAssign::elaborate(Design*des, NetScope*scope) const
{
      NetCAssign*dev = 0;
      ivl_assert(*this, scope);

      if (scope->is_auto() && lval_->has_aa_term(des, scope)) {
	    cerr << get_fileline() << ": error: automatically allocated "
                    "variables may not be assigned values using procedural "
	            "continuous assignments." << endl;
	    des->errors += 1;
	    return 0;
      }

      if (scope->is_auto() && expr_->has_aa_term(des, scope)) {
	    cerr << get_fileline() << ": error: automatically allocated "
                    "variables may not be referenced in procedural "
	            "continuous assignments." << endl;
	    des->errors += 1;
	    return 0;
      }

      NetAssign_*lval = lval_->elaborate_lval(des, scope, true, false);
      if (lval == 0)
	    return 0;

      unsigned lwid = count_lval_width(lval);
      ivl_variable_type_t ltype = lval->expr_type();

      NetExpr*rexp = elaborate_rval_expr(des, scope, lval->net_type(), ltype, lwid, expr_);
      if (rexp == 0)
	    return 0;

      dev = new NetCAssign(lval, rexp);

      if (debug_elaborate) {
	    cerr << get_fileline() << ": debug: Elaborate cassign,"
		 << " lval width=" << lwid
		 << " rval width=" << rexp->expr_width()
		 << " rval=" << *rexp
		 << endl;
      }

      dev->set_line(*this);
      return dev;
}

NetDeassign* PDeassign::elaborate(Design*des, NetScope*scope) const
{
      ivl_assert(*this, scope);

      if (scope->is_auto() && lval_->has_aa_term(des, scope)) {
	    cerr << get_fileline() << ": error: automatically allocated "
                    "variables may not be assigned values using procedural "
	            "continuous assignments." << endl;
	    des->errors += 1;
	    return 0;
      }

      NetAssign_*lval = lval_->elaborate_lval(des, scope, true, false);
      if (lval == 0)
	    return 0;

      NetDeassign*dev = new NetDeassign(lval);
      dev->set_line( *this );
      return dev;
}

/*
 * Elaborate the delay statement (of the form #<expr> <statement>) as a
 * NetPDelay object. If the expression is constant, evaluate it now
 * and make a constant delay. If not, then pass an elaborated
 * expression to the constructor of NetPDelay so that the code
 * generator knows to evaluate the expression at run time.
 */
NetProc* PDelayStatement::elaborate(Design*des, NetScope*scope) const
{
      ivl_assert(*this, scope);

      if (scope->in_func()) {
	    cerr << get_fileline() << ": error: functions cannot have "
	            "delay statements." << endl;
	    des->errors += 1;
	    return 0;
      }

      if (scope->in_final()) {
	    cerr << get_fileline() << ": error: final procedures cannot "
	            "have delay statements." << endl;
	    des->errors += 1;
	    return 0;
      }

	/* This call evaluates the delay expression to a NetEConst, if
	   possible. This includes transforming NetECReal values to
	   integers, and applying the proper scaling. */
      NetExpr*dex = elaborate_delay_expr(delay_, des, scope);

      NetPDelay *obj;
      if (const NetEConst*tmp = dynamic_cast<NetEConst*>(dex)) {
	    if (statement_)
		  obj = new NetPDelay(tmp->value().as_ulong64(),
		                      statement_->elaborate(des, scope));
	    else
		  obj = new NetPDelay(tmp->value().as_ulong64(), 0);

	    delete dex;

      } else {
	    if (statement_)
		  obj = new NetPDelay(dex, statement_->elaborate(des, scope));
	    else
		  obj = new NetPDelay(dex, 0);
      }
      obj->set_line(*this);
      return obj;
}

/*
 * The disable statement is not yet supported.
 */
NetProc* PDisable::elaborate(Design*des, NetScope*scope) const
{
      ivl_assert(*this, scope);

	/* If the disable scope_ is empty then this is a SystemVerilog
	 * disable fork statement. */
      if (scope_.empty()) {
	    if (gn_system_verilog()) {
		  NetDisable*obj = new NetDisable(0);
		  obj->set_line(*this);
		  return obj;
	    } else {
		  cerr << get_fileline()
		       << ": error: 'disable fork' requires SystemVerilog."
		       << endl;
		  des->errors += 1;
		  return 0;
	    }
      }

      list<hname_t> spath = eval_scope_path(des, scope, scope_);

      NetScope*target = des->find_scope(scope, spath);
      if (target == 0) {
	    cerr << get_fileline() << ": error: Cannot find scope "
		 << scope_ << " in " << scope_path(scope) << endl;
	    des->errors += 1;
	    return 0;
      }

      switch (target->type()) {
	  case NetScope::FUNC:
	    cerr << get_fileline() << ": error: Cannot disable functions." << endl;
	    des->errors += 1;
	    return 0;

	  case NetScope::MODULE:
	    cerr << get_fileline() << ": error: Cannot disable modules." << endl;
	    des->errors += 1;
	    return 0;

	  default:
	    break;
      }

      NetDisable*obj = new NetDisable(target);
      obj->set_line(*this);
      return obj;
}

/*
 * The do/while loop is fairly directly represented in the netlist.
 */
NetProc* PDoWhile::elaborate(Design*des, NetScope*scope) const
{
      NetExpr*ce = nullptr;
      if (gn_system_verilog()) {
	    PExpr::width_mode_t mode = PExpr::SIZED;
	    cond_->test_width(des, scope, mode);
	    ce = cond_->elaborate_expr(des, scope, cond_->expr_width(),
				       PExpr::NO_FLAGS);
      } else {
	    ce = elab_and_eval(des, scope, cond_, -1);
      }
      NetProc*sub;
      if (statement_)
	    sub = statement_->elaborate(des, scope);
      else
	    sub = new NetBlock(NetBlock::SEQU, 0);
      if (ce == 0 || sub == 0) {
	    delete ce;
	    delete sub;
	    return 0;
      }
      NetDoWhile*loop = new NetDoWhile(ce, sub);
      loop->set_line(*this);
      return loop;
}

/*
 * An event statement is an event delay of some sort, attached to a
 * statement. Some Verilog examples are:
 *
 *      @(posedge CLK) $display("clock rise");
 *      @event_1 $display("event triggered.");
 *      @(data or negedge clk) $display("data or clock fall.");
 *
 * The elaborated netlist uses the NetEvent, NetEvWait and NetEvProbe
 * classes. The NetEvWait class represents the part of the netlist
 * that is executed by behavioral code. The process starts waiting on
 * the NetEvent when it executes the NetEvWait step. Net NetEvProbe
 * and NetEvTrig are structural and behavioral equivalents that
 * trigger the event, and awakens any processes blocking in the
 * associated wait.
 *
 * The basic data structure is:
 *
 *       NetEvWait ---/--->  NetEvent  <----\---- NetEvProbe
 *        ...         |                     |         ...
 *       NetEvWait ---+                     +---- NetEvProbe
 *                                          |         ...
 *                                          +---- NetEvTrig
 *
 * That is, many NetEvWait statements may wait on a single NetEvent
 * object, and Many NetEvProbe objects may trigger the NetEvent
 * object. The many NetEvWait objects pointing to the NetEvent object
 * reflects the possibility of different places in the code blocking
 * on the same named event, like so:
 *
 *         event foo;
 *           [...]
 *         always begin @foo <statement1>; @foo <statement2> end
 *
 * This tends to not happen with signal edges. The multiple probes
 * pointing to the same event reflect the possibility of many
 * expressions in the same blocking statement, like so:
 *
 *         wire reset, clk;
 *           [...]
 *         always @(reset or posedge clk) <stmt>;
 *
 * Conjunctions like this cause a NetEvent object be created to
 * represent the overall conjunction, and NetEvProbe objects for each
 * event expression.
 *
 * If the NetEvent object represents a named event from the source,
 * then there are NetEvTrig objects that represent the trigger
 * statements instead of the NetEvProbe objects representing signals.
 * For example:
 *
 *         event foo;
 *         always @foo <stmt>;
 *         initial begin
 *                [...]
 *            -> foo;
 *                [...]
 *            -> foo;
 *                [...]
 *         end
 *
 * Each trigger statement in the source generates a separate NetEvTrig
 * object in the netlist. Those trigger objects are elaborated
 * elsewhere.
 *
 * Additional complications arise when named events show up in
 * conjunctions. An example of such a case is:
 *
 *         event foo;
 *         wire bar;
 *         always @(foo or posedge bar) <stmt>;
 *
 * Since there is by definition a NetEvent object for the foo object,
 * this is handled by allowing the NetEvWait object to point to
 * multiple NetEvent objects. All the NetEvProbe based objects are
 * collected and pointed as the synthetic NetEvent object, and all the
 * named events are added into the list of NetEvent object that the
 * NetEvWait object can refer to.
 */

/* Phase 78: extract the terminal boolean condition E_last from an SVA
 * sequence body so that `@<seq>` can wait until E_last evaluates true
 * at the sequence's clocking event.  Supports two pform shapes:
 *  - op_type==0 plain antecedent (single bool):     E_last = antecedent
 *  - op_type==4 seq_form CONCAT chain of SEQ_BOOLs: E_last = rightmost
 *    leaf's expression
 * Returns nullptr for shapes outside the linear-chain subset (operators
 * AND/OR/INTERSECT/THROUGHOUT/REPEAT/GOTO/NONCONS); caller falls back
 * to the existing skip-with-warning path and prints a `sorry: ...`.
 */
static PExpr* sva_seq_extract_terminal_(const sva_seq_t*s)
{
      if (!s) return nullptr;
      while (s->kind == sva_seq_t::SEQ_CONCAT) {
	    if (s->kids_.size() != 2) return nullptr;
	    s = s->kids_[1];
	    if (!s) return nullptr;
      }
      if (s->kind != sva_seq_t::SEQ_BOOL) return nullptr;
      return s->expr_;
}

NetProc* PEventStatement::elaborate_st(Design*des, NetScope*scope,
				       NetProc*enet) const
{
      ivl_assert(*this, scope);

      if (scope->in_func()) {
	    cerr << get_fileline() << ": error: functions cannot have "
	            "event statements." << endl;
	    des->errors += 1;
	    return 0;
      }

      if (scope->in_final()) {
	    cerr << get_fileline() << ": error: final procedures cannot "
	            "have event statements." << endl;
	    des->errors += 1;
	    return 0;
      }

	/* Phase 78: `@<seq>` where <seq> is a registered SVA named
	 * sequence/property.  Synthesize a procedural wait whose loop
	 * iterates on the sequence's clocking event until the terminal
	 * boolean of the sequence body is true.  This is approximate
	 * for non-trivial sequences (it doesn't track prefix history),
	 * but it produces real timing behaviour and is strictly better
	 * than the prior "compile-progress: event skipped" no-op.
	 *
	 * Triggers only for simple `@ident` references (single PEEvent
	 * whose expression is a single-component PEIdent), and only
	 * when symbol_search would otherwise fail to resolve the name
	 * as a signal/event/clocking-block (we let the existing
	 * resolvers run first).
	 */
      if (gn_system_verilog() && expr_.size() == 1
	  && expr_[0]->type() == PEEvent::ANYEDGE) {
	    const PEIdent*pid = dynamic_cast<const PEIdent*>(expr_[0]->expr());
	    if (pid && pid->path().size() == 1) {
		  perm_string nm = peek_head_name(pid->path().name);
		  symbol_search_results sr_chk;
		  symbol_search(this, des, scope, pid->path(),
				pid->lexical_pos(), &sr_chk);
		  bool resolves_as_event = (sr_chk.net != nullptr);
		  if (!resolves_as_event) {
			sva_property_t*prop = pform_sva_take_named_property(nm);
			if (prop) {
			      PExpr*e_last = nullptr;
			      if (prop->op_type == 0 && prop->antecedent
				  && !prop->consequent) {
				    e_last = prop->antecedent;
				    prop->antecedent = nullptr;
			      } else if (prop->op_type == 4 && prop->seq_form) {
				    e_last = sva_seq_extract_terminal_(prop->seq_form);
			      }
			      PEventStatement*clk = prop->clk_evt;
			      prop->clk_evt = nullptr;
			      if (clk && e_last) {
				    char nbuf[64];
				    snprintf(nbuf, sizeof nbuf,
					     "__sv_seq_wait_%u", get_lineno());
				    perm_string blk_name =
					  lex_strings.make(nbuf);
				    PBlock*outer = new PBlock(
					  blk_name,
					  dynamic_cast<LexicalScope*>(scope),
					  PBlock::BL_SEQ);
				    outer->set_file(get_file());
				    outer->set_lineno(get_lineno());

				    pform_name_t disable_path;
				    disable_path.push_back(
					  name_component_t(blk_name));
				    PDisable*disable_stmt =
					  new PDisable(disable_path);
				    disable_stmt->set_file(get_file());
				    disable_stmt->set_lineno(get_lineno());

				    PCondit*check = new PCondit(
					  e_last, disable_stmt, nullptr);
				    check->set_file(get_file());
				    check->set_lineno(get_lineno());

				    clk->set_statement(check);

				    PForever*loop = new PForever(clk);
				    loop->set_file(get_file());
				    loop->set_lineno(get_lineno());

				    std::vector<Statement*> outer_stmts;
				    outer_stmts.push_back(loop);
				    outer->set_statement(outer_stmts);

				      // PBlock with a name needs a NetScope
				      // registered before elaborate() can find
				      // it (for `disable` target resolution).
				      // Run the same elaborate_scope/elaborate_sig
				      // sequence the module-level pass does.
				    outer->elaborate_scope(des, scope);
				    outer->elaborate_sig(des, scope);
				    NetProc*wait_net =
					  outer->elaborate(des, scope);
				    if (wait_net) {
					  NetBlock*combo = new NetBlock(
						NetBlock::SEQU, 0);
					  combo->set_line(*this);
					  combo->append(wait_net);
					  if (enet) combo->append(enet);
					  return combo;
				    }
			      }
			      delete prop;
			}
		  }
	    }
      }

      if (expr_.size() == 1) {
	    const PEIdent*id = dynamic_cast<const PEIdent*>(expr_[0]->expr());
	    if (id) {
		  symbol_search_results sr;
		  symbol_search(this, des, scope, id->path(), id->lexical_pos(), &sr);
		  size_t base_path_components = 0;

		  /* Phase 55: simple clocking-block reference like `@cb` from
		   * inside the same interface (or task within it) -- the
		   * `cb` identifier is a single-name path that doesn't pass
		   * the path_tail check in resolve_interface_clocking_block_from_search_.
		   * Walk the scope chain looking for an enclosing class
		   * (interface) that defines the named clocking block.  If
		   * found, fall through to the existing rewrite that
		   * substitutes the clocking-block's underlying event
		   * expression (e.g. @(posedge clk)).  Without this, the
		   * `@cb` event got skipped at compile-progress fallback,
		   * which broke wait_clks (= repeat (N) @cb) -- it would
		   * return without waiting and apply_reset's o_rst_n NBAs
		   * collapsed before the testbench clock could start. */
		  /* Cache for the pform PClocking we discovered while walking
		   * scopes -- used by the rewrite path below to substitute
		   * the underlying event expression. */
		  const Module::PClocking*pform_clocking_inner = nullptr;
		  if (id->path().size() == 1 && gn_system_verilog()) {
			perm_string cb_name = id->path().back().name;
			for (NetScope*walker = scope ; walker ; walker = walker->parent()) {
			      /* Interface scopes appear as MODULE-type NetScopes
			       * with is_interface()==true; their pform side has
			       * the clocking_blocks map.  Class scopes use
			       * netclass_t::find_clocking_block (already covered
			       * by the existing path_tail-based resolver). */
			      if (walker->type() != NetScope::MODULE)
				    continue;
			      perm_string mn = walker->module_name();
			      if (mn.nil()) continue;
			      auto pmod_it = pform_modules.find(mn);
			      if (pmod_it == pform_modules.end()) continue;
			      auto cb_it = pmod_it->second->clocking_blocks.find(cb_name);
			      if (cb_it != pmod_it->second->clocking_blocks.end()) {
				    pform_clocking_inner = cb_it->second;
				    break;
			      }
			}
		  }

		  const netclass_t::clocking_block_t*clocking =
			resolve_interface_clocking_block_from_search_(sr, base_path_components);
		  /* resolve_interface_clocking_block_from_search_ sets
		     base_path_components = offset (0-based index into
		     sr.path_tail where the clocking block was found).
		     Adjust to account for the root_id components consumed
		     before path_tail: add (id->path().size() - path_tail.size()). */
		  if (clocking)
			base_path_components += id->path().size() - sr.path_tail.size();
		  perm_string scope_cb_name;
		  const PEventStatement*pform_event = clocking
			? clocking->event
			: resolve_interface_pform_clocking_event_(id, sr, scope_cb_name,
							      base_path_components);
		  /* Phase 55: pform-side clocking-block lookup for the simple
		   * `@cb` form within the same interface body or task. */
		  if (!pform_event && pform_clocking_inner) {
			pform_event = pform_clocking_inner->event;
			scope_cb_name = pform_clocking_inner->name;
			/* Same-scope clocking block: the underlying event
			 * identifier (e.g. `clk`) resolves in the caller's
			 * scope without any prefix.  base_path_components=0
			 * makes build_interface_clocking_event_path_ skip
			 * prefix prepending. */
			base_path_components = 0;
		  }
		  if (clocking || pform_event) {
			if (expr_[0]->type() != PEEvent::ANYEDGE) {
			      cerr << get_fileline() << ": error: edge qualifiers may not be applied "
				   << "to clocking block event controls." << endl;
			      des->errors += 1;
			      return 0;
			}
			if (!pform_event || pform_event->event_expressions().empty()) {
			      cerr << get_fileline() << ": error: clocking block "
				   << (clocking ? clocking->name : scope_cb_name)
				   << " has no event expression." << endl;
			      des->errors += 1;
			      return 0;
			}

			std::vector<PEEvent*> mapped_events;
			for (const PEEvent*cb_event : pform_event->event_expressions()) {
			      const PEIdent*cb_ident = cb_event
				    ? dynamic_cast<const PEIdent*>(cb_event->expr()) : nullptr;
			      if (!cb_ident) {
				    cerr << get_fileline() << ": sorry: clocking block event expressions "
					 << "currently require simple identifier paths." << endl;
				    des->errors += 1;
				    return 0;
			      }

			      pform_name_t mapped_path;
			      if (!build_interface_clocking_event_path_(id, base_path_components,
									 cb_ident, mapped_path)) {
				    cerr << get_fileline() << ": sorry: failed to map clocking block "
					 << "event expression for "
					 << (clocking ? clocking->name : scope_cb_name)
					 << "." << endl;
				    des->errors += 1;
				    return 0;
			      }

			      PEIdent*mapped_ident = id->path().package
				    ? new PEIdent(id->path().package, mapped_path, id->lexical_pos())
				    : new PEIdent(mapped_path, id->lexical_pos());
			      mapped_events.push_back(new PEEvent(cb_event->type(), mapped_ident));
			}

			PEventStatement mapped_stmt(mapped_events);
			mapped_stmt.set_statement(statement_);
			return mapped_stmt.elaborate_st(des, scope, enet);
		  }
	    }
      }

	/* Create a single NetEvent and NetEvWait. Then, create a
	   NetEvProbe for each conjunctive event in the event
	   list. The NetEvProbe objects all refer back to the NetEvent
	   object. */

      NetEvent*ev = new NetEvent(scope->local_symbol());
      ev->set_line(*this);
      ev->local_flag(true);
      unsigned expr_count = 0;

      NetEvWait*wa = new NetEvWait(enet);
      wa->set_line(*this);
      bool ignored_class_property_event_expr = false;

	/* If there are no expressions, this is a signal that it is an
	   @* statement. Generate an expression to use. */

	      if (expr_.size() == 0) {
	    ivl_assert(*this, enet);
	     /* For synthesis or always_comb/latch we want just the inputs,
	      * but for the rest we want inputs and outputs that may cause
	      * a value to change. */
	    extern bool synthesis; /* Synthesis flag from main.cc */
	    bool rem_out = false;
	    if (synthesis || always_sens_) {
		  rem_out = true;
	    }
	      // If this is an always_comb/latch then we need an implicit T0
	      // trigger of the event expression.
	    if (always_sens_) wa->set_t0_trigger();
	    NexusSet*nset = enet->nex_input(rem_out, always_sens_);
	    if (nset == 0) {
		  cerr << get_fileline() << ": error: Unable to elaborate:"
		       << endl;
		  enet->dump(cerr, 6);
		  des->errors += 1;
		  return enet;
	    }

	    if (nset->size() == 0) {
                  if (always_sens_) return wa;

		  cerr << get_fileline() << ": warning: @* found no "
		          "sensitivities so it will never trigger."
		       << endl;
		    /* Add the currently unreferenced event to the scope. */
		  scope->add_event(ev);
		    /* Delete the current wait, create a new one with no
		     * statement and add the event to it. This creates a
		     * perpetual wait since nothing will ever trigger the
		     * unreferenced event. */
		  delete wa;
		  wa = new NetEvWait(0);
		  wa->set_line(*this);
		  wa->add_event(ev);
		  return wa;
	    }

	    NetEvProbe*pr = new NetEvProbe(scope, scope->local_symbol(),
					   ev, NetEvProbe::ANYEDGE,
					   nset->size());
	    for (unsigned idx = 0 ;  idx < nset->size() ;  idx += 1) {
		  unsigned wid = nset->at(idx).wid;
		  unsigned vwid = nset->at(idx).lnk.nexus()->vector_width();
		    // Is this a part select?
		  if (always_sens_ && (wid != vwid)) {
# if 0
// Once this is fixed, enable constant bit/part select sensitivity in
// NetESelect::nex_input().
			unsigned base = nset->at(idx).base;
cerr << get_fileline() << ": base = " << base << endl;
// FIXME: make this work with selects that go before the base.
			ivl_assert(*this, base < vwid);
			if (base + wid > vwid) wid = vwid - base;
cerr << get_fileline() << ": base = " << base << ", width = " << wid
     << ", expr width = " << vwid << endl;
nset->at(idx).lnk.dump_link(cerr, 4);
cerr << endl;
// FIXME: Convert the link to the appropriate NetNet
			netvector_t*tmp_vec = new netvector_t(IVL_VT_BOOL, vwid, 0);
			NetNet*sig = new NetNet(scope, scope->local_symbol(), NetNet::IMPLICIT, tmp_vec);
			NetPartSelect*tmp = new NetPartSelect(sig, base, wid, NetPartSelect::VP);
			des->add_node(tmp);
			tmp->set_line(*this);
// FIXME: create a part select to get the correct bits to connect.
			connect(tmp->pin(1), nset->at(idx).lnk);
			connect(tmp->pin(0), pr->pin(idx));
# endif
			connect(nset->at(idx).lnk, pr->pin(idx));
		  } else {
			connect(nset->at(idx).lnk, pr->pin(idx));
		  }
	    }

	    delete nset;
	    des->add_node(pr);

	    expr_count = 1;

	      } else for (unsigned idx = 0 ;  idx < expr_.size() ;  idx += 1) {

	    ivl_assert(*this, expr_[idx]->expr());

	      /* If the expression is an identifier that matches a
		 named event, then handle this case all at once and
		 skip the rest of the expression handling. */

		    if (const PEIdent*id = dynamic_cast<PEIdent*>(expr_[idx]->expr())) {
			  symbol_search_results sr;
			  symbol_search(this, des, scope, id->path(), id->lexical_pos(), &sr);

		  if (NetEvent*named_eve = resolve_named_event_member_from_search_(sr)) {
			wa->add_event(named_eve);
			  /* You can not look for the posedge or negedge of
			   * an event. */
			if (expr_[idx]->type() != PEEvent::ANYEDGE) {
                              cerr << get_fileline() << ": error: ";
                              switch (expr_[idx]->type()) {
				  case PEEvent::POSEDGE:
				    cerr << "posedge";
				    break;
				  case PEEvent::NEGEDGE:
				    cerr << "negedge";
				    break;
				  default:
				    cerr << "unknown edge type!";
				    ivl_assert(*this, 0);
			      }
			      cerr << " can not be used with a named event ("
			           << named_eve->name() << ")." << endl;
                              des->errors += 1;
				}
				continue;
			  }

			  if (gn_system_verilog()
			      && id->path().size() == 1
			      && id->path().back().index.empty()
			      && id->path().back().name == perm_string::literal("on")) {
				pform_scoped_name_t mapped_path = id->path();
				mapped_path.name.back().name = perm_string::literal("m_event");
				symbol_search_results mapped_sr;
				symbol_search(this, des, scope, mapped_path, id->lexical_pos(), &mapped_sr);
				if (NetEvent*mapped_eve = resolve_named_event_member_from_search_(mapped_sr)) {
				      wa->add_event(mapped_eve);
				      if (expr_[idx]->type() != PEEvent::ANYEDGE) {
					    cerr << get_fileline() << ": error: ";
					    switch (expr_[idx]->type()) {
						case PEEvent::POSEDGE:
						  cerr << "posedge";
						  break;
						case PEEvent::NEGEDGE:
						  cerr << "negedge";
						  break;
						default:
						  cerr << "unknown edge type!";
						  ivl_assert(*this, 0);
					    }
					    cerr << " can not be used with a named event ("
						 << mapped_eve->name() << ")." << endl;
					    des->errors += 1;
				      }
				      continue;
				}
			  }
		    }


	      /* So now we have a normal event expression. Elaborate
		 the sub-expression as a net and decide how to handle
		 the edge. */

            if (scope->is_auto()) {
                  if (! dynamic_cast<PEIdent*>(expr_[idx]->expr())) {
                        if (gn_system_verilog()) {
                              cerr << get_fileline() << ": warning: complex event "
                                      "expressions are not yet supported in "
                                      "automatic tasks (compile-progress: event skipped)." << endl;
                              continue;
                        }
                        cerr << get_fileline() << ": sorry, complex event "
                                "expressions are not yet supported in "
                                "automatic tasks." << endl;
                        des->errors += 1;
                        return 0;
                  }
            }

	    NetExpr*tmp = elab_and_eval(des, scope, expr_[idx]->expr(), -1);
	    if (tmp == 0) {
		  // Compile-progress: clocking block or complex VIF event references
		  // (e.g. @(vif.mp.cb)) may not yet be resolvable. Warn and skip.
		  cerr << get_fileline() << ": warning: "
			  "Failed to evaluate event expression '"
		       << *expr_[idx] << "' (compile-progress: event skipped)." << endl;
		  continue;
	    }
	    // Compile-progress: clocking block refs that came back as NetEScope
	    // (e.g. @(monitor_cb) where monitor_cb is a child clocking block scope)
	    // cannot be synthesized. Skip gracefully.
	    if (gn_system_verilog() && dynamic_cast<NetEScope*>(tmp)) {
		  cerr << get_fileline() << ": warning: "
			  "Scope used as event expression (compile-progress: event skipped)." << endl;
		  delete tmp;
		  continue;
	    }

	      // posedge, negedge and edge are not allowed on real expressions.
	    if ((tmp->expr_type() == IVL_VT_REAL) &&
	        (expr_[idx]->type() != PEEvent::ANYEDGE)) {
		  cerr << get_fileline() << ": error: '";
		  switch (expr_[idx]->type()) {
		    case PEEvent::POSEDGE:
			cerr << "posedge";
			break;
		    case PEEvent::NEGEDGE:
			cerr << "negedge";
			break;
		    case PEEvent::EDGE:
			cerr << "edge";
			break;
		    default:
			ivl_assert(*this, 0);
		  }
		  cerr << "' cannot be used with real expressions '"
		       << *expr_[idx]->expr() << "'." << endl;
		  des->errors += 1;
		  continue;
	    }

	    if (gn_system_verilog()
		&& dynamic_cast<NetEProperty*>(tmp)) {
		  // Compile-progress semantic support: class-property expressions
		  // do not generally synthesize into a NetNet, but we can still
		  // derive a sensitivity set from their input dependencies.
		  NexusSet*prop_set = tmp->nex_input();
		  if (prop_set && prop_set->size() > 0) {
			unsigned pins = (expr_[idx]->type() == PEEvent::ANYEDGE)
				      ? prop_set->size() : 1;
			NetEvProbe*pr = 0;
			switch (expr_[idx]->type()) {
			    case PEEvent::POSEDGE:
			      pr = new NetEvProbe(scope, scope->local_symbol(), ev,
						  NetEvProbe::POSEDGE, pins);
			      break;
			    case PEEvent::NEGEDGE:
			      pr = new NetEvProbe(scope, scope->local_symbol(), ev,
						  NetEvProbe::NEGEDGE, pins);
			      break;
			    case PEEvent::EDGE:
			      pr = new NetEvProbe(scope, scope->local_symbol(), ev,
						  NetEvProbe::EDGE, pins);
			      break;
			    case PEEvent::ANYEDGE:
			      pr = new NetEvProbe(scope, scope->local_symbol(), ev,
						  NetEvProbe::ANYEDGE, pins);
			      break;
			    default:
			      ivl_assert(*this, 0);
			}

			for (unsigned p = 0 ; p < pr->pin_count() ; p += 1) {
			      unsigned src = (expr_[idx]->type() == PEEvent::ANYEDGE) ? p : 0;
			      connect(prop_set->at(src).lnk, pr->pin(p));
			}

			// Detect VIF edge chain:
			//   2-level: outer(M)->mid(N)->NetESignal(base)
			//     base.vif[N].sig[M] — emits %load/obj base; %prop/obj N; %wait/vif/edge M
			//   3-level: outer(M)->mid(N)->cfg_p(pre_N)->NetESignal(base)
			//     base.cfg[pre_N].vif[N].sig[M] — emits extra %prop/obj pre_N first
			// mid's resolved type must be a virtual interface class.
			{
			      PEEvent::edge_t etype = expr_[idx]->type();
			      if (etype == PEEvent::POSEDGE || etype == PEEvent::NEGEDGE
				  || etype == PEEvent::ANYEDGE) {
				    NetEProperty*outer_p = dynamic_cast<NetEProperty*>(tmp);
				    if (outer_p && !outer_p->get_sig()) {
					  NetEProperty*mid_p = dynamic_cast<NetEProperty*>(
					      const_cast<NetExpr*>(outer_p->get_base()));
					  if (mid_p && !mid_p->get_sig()) {
					      // Try 2-level first: mid->NetESignal
					      const NetESignal*root_e = dynamic_cast<NetESignal*>(
						  const_cast<NetExpr*>(mid_p->get_base()));
					      NetEProperty*cfg_p = nullptr;
					      if (!root_e) {
						    // Try 3-level: mid->cfg_p->NetESignal
						    cfg_p = dynamic_cast<NetEProperty*>(
							const_cast<NetExpr*>(mid_p->get_base()));
						    if (cfg_p && !cfg_p->get_sig())
							  root_e = dynamic_cast<NetESignal*>(
							      const_cast<NetExpr*>(cfg_p->get_base()));
					      }
					      if (root_e && root_e->sig()) {
						    const netclass_t*base_cls = dynamic_cast<const netclass_t*>(
							root_e->sig()->net_type());
						    if (base_cls) {
							  // For 3-level: base_cls → cfg property → vif class
							  // For 2-level: base_cls → vif property directly
							  const netclass_t*vif_host_cls = base_cls;
							  unsigned pre_N = UINT_MAX;
							  if (cfg_p) {
								unsigned cfg_idx = cfg_p->property_idx();
								ivl_type_t cfg_pt = base_cls->get_prop_type(cfg_idx);
								const netclass_t*cfg_cls = dynamic_cast<const netclass_t*>(cfg_pt);
								if (cfg_cls) {
								      pre_N = cfg_idx;
								      vif_host_cls = cfg_cls;
								} else {
								      root_e = nullptr; // cfg not a class → skip
								}
							  }
							  if (root_e) {
								ivl_type_t pt = vif_host_cls->get_prop_type(
								    mid_p->property_idx());
								const netclass_t*vif_cls = dynamic_cast<const netclass_t*>(pt);
								if (vif_cls && vif_cls->is_interface()) {
								      unsigned N = mid_p->property_idx();
								      unsigned M = outer_p->property_idx();
								      if (etype == PEEvent::POSEDGE)
									    pr->set_vif_posedge(N, M, pre_N);
								      else if (etype == PEEvent::NEGEDGE)
									    pr->set_vif_negedge(N, M, pre_N);
								      else
									    pr->set_vif_anyedge(N, M, pre_N);
								}
							  }
						    }
					      }
					  }
				    }
			      }
			}

			delete prop_set;
			delete tmp;
			des->add_node(pr);
			expr_count += 1;
			continue;
		  }

		  if (!warned_class_property_event_expr_ignored) {
			cerr << get_fileline() << ": warning: "
			     << "class-property event expression '" << *expr_[idx]
			     << "' ignored (compile-progress fallback, "
			     << "further similar warnings suppressed)." << endl;
			warned_class_property_event_expr_ignored = true;
		  }
		  delete prop_set;
		  delete tmp;
		  ignored_class_property_event_expr = true;
		  continue;
	    }

	    NetNet*expr = tmp->synthesize(des, scope, tmp);
	    if (expr == 0) {
		  if (gn_system_verilog()) {
			// Compile-progress: SV expressions with class properties or
			// clocking block refs cannot always synthesize. Warn and skip.
			cerr << get_fileline() << ": warning: Failed to synthesize event "
				"expression (compile-progress: event skipped)." << endl;
		  } else {
			expr_[idx]->dump(cerr);
			cerr << endl;
			des->errors += 1;
		  }
		  continue;
	    }
	    ivl_assert(*this, expr);

	    delete tmp;

	    unsigned pins = (expr_[idx]->type() == PEEvent::ANYEDGE)
		  ? expr->pin_count() : 1;

	    NetEvProbe*pr;
	    switch (expr_[idx]->type()) {
		case PEEvent::POSEDGE:
		  pr = new NetEvProbe(scope, scope->local_symbol(), ev,
				      NetEvProbe::POSEDGE, pins);
		  break;

		case PEEvent::NEGEDGE:
		  pr = new NetEvProbe(scope, scope->local_symbol(), ev,
				      NetEvProbe::NEGEDGE, pins);
		  break;

		case PEEvent::EDGE:
		  pr = new NetEvProbe(scope, scope->local_symbol(), ev,
				      NetEvProbe::EDGE, pins);
		  break;

		case PEEvent::ANYEDGE:
		  pr = new NetEvProbe(scope, scope->local_symbol(), ev,
				      NetEvProbe::ANYEDGE, pins);
		  break;

		default:
		  pr = NULL;
		  ivl_assert(*this, 0);
	    }

	    for (unsigned p = 0 ;  p < pr->pin_count() ; p += 1)
		  connect(pr->pin(p), expr->pin(p));

	    des->add_node(pr);
	    expr_count += 1;
      }

      if (ignored_class_property_event_expr && expr_count == 0 && wa->nevents() == 0) {
	    if (!warned_event_control_empty_set) {
		  cerr << get_fileline() << ": warning: event control has empty event set; "
		       << "ignoring event control (compile-progress fallback,"
		       << " further similar warnings suppressed)." << endl;
		  warned_event_control_empty_set = true;
	    }
	    delete ev;
	    return enet;
      }

	/* If there was at least one conjunction that was an
	   expression (and not a named event) then add this
	   event. Otherwise, we didn't use it so delete it. */
      if (expr_count > 0) {
	    scope->add_event(ev);
	    wa->add_event(ev);
	      /* NOTE: This event that I am adding to the wait may be
		 a duplicate of another event somewhere else. However,
		 I don't know that until all the modules are hooked
		 up, so it is best to leave find_similar_event to
		 after elaboration. */
      } else {
	    delete ev;
      }

      // Compile-progress: if all event expressions were skipped (e.g. complex
      // SV event expressions we can't synthesize) and the wait has no events,
      // handle based on scope:
      //  - Non-automatic: set t0_trigger (triggers at T=0 like always_comb)
      //  - Automatic (class tasks/functions): return just the body (skip wait)
      //    because E_0x0 is invalid inside automatic scopes.
      if (gn_system_verilog() && wa->nevents() == 0 && !wa->has_t0_trigger()) {
	    if (scope->is_auto()) {
		  // Can't use E_0x0 in automatic scope — skip the wait entirely.
		  NetProc*body = wa->statement();
		  wa->set_statement(0);
		  delete wa;
		  return body;
	    } else {
		  wa->set_t0_trigger();
	    }
      }

      return wa;
}

/*
 * This is the special case of the event statement, the wait
 * statement. This is elaborated into a slightly more complicated
 * statement that uses non-wait statements:
 *
 *     wait (<expr>)  <statement>
 *
 * becomes
 *
 *     begin
 *         while (1 !== <expr>)
 *           @(<expr inputs>) <noop>;
 *         <statement>;
 *     end
 */
NetProc* PEventStatement::elaborate_wait(Design*des, NetScope*scope,
					 NetProc*enet) const
{
      ivl_assert(*this, scope);
      ivl_assert(*this, expr_.size() == 1);

      if (scope->in_func()) {
	    cerr << get_fileline() << ": error: functions cannot have "
	            "wait statements." << endl;
	    des->errors += 1;
	    return 0;
      }

      if (scope->in_final()) {
	    cerr << get_fileline() << ": error: final procedures cannot "
	            "have wait statements." << endl;
	    des->errors += 1;
	    return 0;
      }

      PExpr *pe = expr_[0]->expr();

	/* Elaborate wait expression. Don't eval yet, we will do that
	   shortly, after we apply a reduction or. */

      PExpr::width_mode_t mode = PExpr::SIZED;
      pe->test_width(des, scope, mode);
      NetExpr*expr = pe->elaborate_expr(des, scope, pe->expr_width(),
                                        PExpr::NO_FLAGS);
      if (expr == 0) {
	    if (gn_system_verilog()) {
		  // Compile-progress fallback: wait on a constant-true expression
		  // when the condition can't be elaborated (e.g. nested class
		  // property access). The runtime will never wait.
		  cerr << get_fileline() << ": warning: Unable to elaborate"
			" wait condition expression (compile-progress fallback)." << endl;
		  expr = make_const_val(1);
	    } else {
		  cerr << get_fileline() << ": error: Unable to elaborate"
			" wait condition expression." << endl;
		  des->errors += 1;
		  return 0;
	    }
      }

	// If the condition expression is more than 1 bits, then
	// generate a reduction operator to get the result down to
	// one bit. In other words, Turn <e> into |<e>;

      if (expr->expr_width() < 1) {
	    cerr << get_fileline() << ": internal error: "
		  "incomprehensible wait expression width (0) in scope "
		 << scope_path(scope) << ", expr=";
	    expr->dump(cerr);
	    cerr << endl;
	    return 0;
      }

      if (expr->expr_width() > 1) {
	    ivl_assert(*this, expr->expr_width() > 1);
	    NetEUReduce*cmp = new NetEUReduce('|', expr);
	    cmp->set_line(*pe);
	    expr = cmp;
      }

      NetEvent*triggered_event = 0;
      if (NetEEvent*eve_expr = dynamic_cast<NetEEvent*>(expr))
	    triggered_event = const_cast<NetEvent*>(eve_expr->event());

	/* precalculate as much as possible of the wait expression. */
      eval_expr(expr);

	/* Detect the unusual case that the wait expression is
	   constant. Constant true is OK (it becomes transparent) but
	   constant false is almost certainly not what is intended. */
      ivl_assert(*this, expr->expr_width() == 1);
      if (const NetEConst*ce = dynamic_cast<NetEConst*>(expr)) {
	    verinum val = ce->value();
	    ivl_assert(*this, val.len() == 1);

	      /* Constant true -- wait(1) <s1> reduces to <s1>. */
	    if (val[0] == verinum::V1) {
		  delete expr;
		  ivl_assert(*this, enet);
		  return enet;
	    }

	      /* Otherwise, false. wait(0) blocks permanently. */

	      /* Create an event wait and an otherwise unreferenced
		 event variable to force a perpetual wait. */
	    NetEvent*wait_event = new NetEvent(scope->local_symbol());
	    wait_event->set_line(*this);
	    wait_event->local_flag(true);
	    scope->add_event(wait_event);

	    NetEvWait*wait = new NetEvWait(0);
	    wait->add_event(wait_event);
	    wait->set_line(*this);

	    delete expr;
	    delete enet;
	    return wait;
      }

	/* Invert the sense of the test with an exclusive NOR. In
	   other words, if this adjusted expression returns TRUE, then
	   wait. */
      ivl_assert(*this, expr->expr_width() == 1);
      expr = new NetEBComp('N', expr, new NetEConst(verinum(verinum::V1)));
      expr->set_line(*pe);
      eval_expr(expr);

      if (triggered_event) {
	    NetEvWait*wait = new NetEvWait(0 /* noop */);
	    wait->add_event(triggered_event);
	    wait->set_line(*this);

	    NetWhile*loop = new NetWhile(expr, wait);
	    loop->set_line(*this);

	    if (enet == 0)
		  return loop;

	    NetBlock*block = new NetBlock(NetBlock::SEQU, 0);
	    block->append(loop);
	    block->append(enet);
	    block->set_line(*this);
	    return block;
      }

      NetEvent*wait_event = new NetEvent(scope->local_symbol());
      wait_event->set_line(*this);
      wait_event->local_flag(true);
      scope->add_event(wait_event);

      NetEvWait*wait = new NetEvWait(0 /* noop */);
      wait->add_event(wait_event);
      wait->set_line(*this);

	      NexusSet*wait_set = expr->nex_input();
              if (NetNet*this_net = find_implicit_this_handle(des, scope)) {
                    if (this_net->pin_count() > 0) {
                          if (Nexus*nx = const_cast<Nexus*>(this_net->pin(0).nexus()))
                                wait_set->add(nx, 0, nx->vector_width());
                    }
              }
	      if (wait_set == 0) {
		    if (gn_system_verilog()) {
			  if (!warned_wait_no_event_sources) {
				cerr << get_fileline() << ": warning: wait expression has no event "
				     << "sources; ignoring wait (compile-progress fallback, "
				     << "further similar warnings suppressed)." << endl;
				warned_wait_no_event_sources = true;
			  }
			  delete expr;
			  return enet;
		    }
	    cerr << get_fileline() << ": internal error: No NexusSet"
		 << " from wait expression." << endl;
	    des->errors += 1;
	    return 0;
      }

	      if (wait_set->size() == 0) {
		    if (gn_system_verilog()) {
			  if (!warned_wait_empty_event_set) {
				cerr << get_fileline() << ": warning: wait expression has empty event "
				     << "set; ignoring wait (compile-progress fallback, "
				     << "further similar warnings suppressed)." << endl;
				warned_wait_empty_event_set = true;
			  }
			  delete wait_set;
			  delete expr;
			  return enet;
	    }
	    cerr << get_fileline() << ": internal error: Empty NexusSet"
		 << " from wait expression." << endl;
	    des->errors += 1;
	    return 0;
      }

      NetEvProbe*wait_pr = new NetEvProbe(scope, scope->local_symbol(),
					  wait_event, NetEvProbe::ANYEDGE,
					  wait_set->size());
      for (unsigned idx = 0; idx < wait_set->size() ;  idx += 1)
	    connect(wait_set->at(idx).lnk, wait_pr->pin(idx));

      delete wait_set;
      des->add_node(wait_pr);

      // Phase 55/58: Detect VIF signal chain in wait() for RTL-driven wakeup.
      // Mirrors the @(posedge/anyedge) detection at lines ~7067-7123.
      // expr here is NetEBComp('N', original_cond, 1'b1) due to the inversion
      // above, plus an optional NetEUReduce wrapper for multi-bit conditions.
      // Recurse into binary, unary, and system-function subexpressions to find
      // the chain. Stop on first match so we don't double-record the slot.
      {
	    std::function<bool(const NetExpr*)> try_set_vif_anyedge;
	    try_set_vif_anyedge = [&](const NetExpr*e) -> bool {
		  if (!e) return false;
		  NetEProperty*outer_p = dynamic_cast<NetEProperty*>(
		      const_cast<NetExpr*>(e));
		  if (outer_p && !outer_p->get_sig()) {
			NetEProperty*mid_p = dynamic_cast<NetEProperty*>(
			    const_cast<NetExpr*>(outer_p->get_base()));
			if (mid_p && !mid_p->get_sig()) {
			      const NetESignal*root_e = dynamic_cast<NetESignal*>(
				  const_cast<NetExpr*>(mid_p->get_base()));
			      NetEProperty*cfg_p = nullptr;
			      if (!root_e) {
				    cfg_p = dynamic_cast<NetEProperty*>(
					const_cast<NetExpr*>(mid_p->get_base()));
				    if (cfg_p && !cfg_p->get_sig())
					  root_e = dynamic_cast<NetESignal*>(
					      const_cast<NetExpr*>(cfg_p->get_base()));
			      }
			      if (root_e && root_e->sig()) {
				    const netclass_t*base_cls = dynamic_cast<const netclass_t*>(
					root_e->sig()->net_type());
				    if (base_cls) {
					  const netclass_t*vif_host_cls = base_cls;
					  unsigned pre_N = UINT_MAX;
					  if (cfg_p) {
						unsigned cfg_idx = cfg_p->property_idx();
						ivl_type_t cfg_pt = base_cls->get_prop_type(cfg_idx);
						const netclass_t*cfg_cls = dynamic_cast<const netclass_t*>(cfg_pt);
						if (cfg_cls) {
						      pre_N = cfg_idx;
						      vif_host_cls = cfg_cls;
						} else {
						      return false;
						}
					  }
					  ivl_type_t pt = vif_host_cls->get_prop_type(
					      mid_p->property_idx());
					  const netclass_t*vif_cls = dynamic_cast<const netclass_t*>(pt);
					  if (vif_cls && vif_cls->is_interface()) {
						wait_pr->set_vif_anyedge(mid_p->property_idx(),
									 outer_p->property_idx(), pre_N);
						return true;
					  }
				    }
			      }
			}
			return false;
		  }
		  if (const NetEBinary*bin = dynamic_cast<const NetEBinary*>(e)) {
			if (try_set_vif_anyedge(bin->left())) return true;
			return try_set_vif_anyedge(bin->right());
		  }
		  // Phase 58: dive through NetEUnary so wait(!$isunknown(vif.sig))
		  // and the implicit NetEUReduce wrapper for multi-bit conditions
		  // can find the chain.
		  if (const NetEUnary*un = dynamic_cast<const NetEUnary*>(e)) {
			return try_set_vif_anyedge(un->expr());
		  }
		  // Phase 58: dive through system-function args so vif chains
		  // inside $isunknown / $past / etc. are detected.
		  if (const NetESFunc*sf = dynamic_cast<const NetESFunc*>(e)) {
			for (unsigned i = 0; i < sf->nparms(); ++i) {
			      if (try_set_vif_anyedge(sf->parm(i))) return true;
			}
			return false;
		  }
		  return false;
	    };
	    try_set_vif_anyedge(expr);
      }

      NetWhile*loop = new NetWhile(expr, wait);
      loop->set_line(*this);

	/* If there is no real substatement (i.e., "wait (foo) ;") then
	   we are done. */
      if (enet == 0)
	    return loop;

	/* Create a sequential block to combine the wait loop and the
	   delayed statement. */
      NetBlock*block = new NetBlock(NetBlock::SEQU, 0);
      block->append(loop);
      block->append(enet);
      block->set_line(*this);

      return block;
}

/*
 * This is a special case of the event statement, the wait fork
 * statement. This is elaborated into a simplified statement.
 *
 *     wait fork;
 *
 * becomes
 *
 *     @(0) <noop>;
 */
NetProc* PEventStatement::elaborate_wait_fork(Design*des, const NetScope*scope) const
{
      ivl_assert(*this, scope);
      ivl_assert(*this, expr_.size() == 1);
      ivl_assert(*this, expr_[0] == 0);
      ivl_assert(*this, ! statement_);

      if (scope->in_func()) {
	    cerr << get_fileline() << ": error: functions cannot have "
	            "wait fork statements." << endl;
	    des->errors += 1;
	    return 0;
      }

      if (scope->in_final()) {
	    cerr << get_fileline() << ": error: final procedures cannot "
	            "have wait fork statements." << endl;
	    des->errors += 1;
	    return 0;
      }

      if (gn_system_verilog()) {
	    NetEvWait*wait = new NetEvWait(0 /* noop */);
	    wait->add_event(0);
	    wait->set_line(*this);
	    return wait;
      } else {
	    cerr << get_fileline()
	         << ": error: 'wait fork' requires SystemVerilog." << endl;
	    des->errors += 1;
	    return 0;
      }

}

NetProc* PEventStatement::elaborate(Design*des, NetScope*scope) const
{
	/* Check to see if this is a wait fork statement. */
      if ((expr_.size() == 1) && (expr_[0] == 0))
		  return elaborate_wait_fork(des, scope);

      NetProc*enet = 0;
      if (statement_) {
	    enet = statement_->elaborate(des, scope);
	    if (enet == 0)
		  return 0;

      } else {
	    enet = new NetBlock(NetBlock::SEQU, 0);
	    enet->set_line(*this);
      }

      if ((expr_.size() == 1) && (expr_[0]->type() == PEEvent::POSITIVE))
	    return elaborate_wait(des, scope, enet);

      return elaborate_st(des, scope, enet);
}

/*
 * Forever statements are represented directly in the netlist. It is
 * theoretically possible to use a while structure with a constant
 * expression to represent the loop, but why complicate the code
 * generators so?
 */
NetProc* PForever::elaborate(Design*des, NetScope*scope) const
{
      NetProc*stat;
      if (statement_)
	    stat = statement_->elaborate(des, scope);
      else
	    stat = new NetBlock(NetBlock::SEQU, 0);
      if (stat == 0) return 0;

      NetForever*proc = new NetForever(stat);
      proc->set_line(*this);
      return proc;
}

/*
 * Force is like a procedural assignment, most notably procedural
 * continuous assignment:
 *
 *    force <lval> = <rval>
 *
 * The <lval> can be anything that a normal behavioral assignment can
 * take, plus net signals. This is a little bit more lax than the
 * other procedural assignments.
 */
NetForce* PForce::elaborate(Design*des, NetScope*scope) const
{
      NetForce*dev = 0;
      ivl_assert(*this, scope);

      if (scope->is_auto() && lval_->has_aa_term(des, scope)) {
	    cerr << get_fileline() << ": error: automatically allocated "
                    "variables may not be assigned values using procedural "
	            "force statements." << endl;
	    des->errors += 1;
	    return 0;
      }

      if (scope->is_auto() && expr_->has_aa_term(des, scope)) {
	    cerr << get_fileline() << ": error: automatically allocated "
                    "variables may not be referenced in procedural force "
	            "statements." << endl;
	    des->errors += 1;
	    return 0;
      }

      NetAssign_*lval = lval_->elaborate_lval(des, scope, false, true);
      if (lval == 0)
	    return 0;

      unsigned lwid = count_lval_width(lval);
      ivl_variable_type_t ltype = lval->expr_type();

	// Like a variety of other assigns, we need to figure out a
	// better way to get a reasonable lv_net_type value, and that
	// probably will involve NetAssign_ having a method for
	// synthesizing one as needed.
      NetExpr*rexp = elaborate_rval_expr(des, scope, lval->net_type(), ltype, lwid, expr_);
      if (rexp == 0)
	    return 0;

      dev = new NetForce(lval, rexp);

      if (debug_elaborate) {
	    cerr << get_fileline() << ": debug: Elaborate force,"
		 << " lval width=" << lval->lwidth()
		 << " rval width=" << rexp->expr_width()
		 << " rval=" << *rexp
		 << endl;
      }

      dev->set_line(*this);
      return dev;
}

static void find_property_in_class(Design*des, const LineInfo&loc, const NetScope*scope,
				   perm_string name, const netclass_t*&found_in,
				   int&property)
{
      found_in = find_class_containing_scope(loc, scope);
      property = -1;

      if (found_in==0) return;

      property = const_cast<netclass_t*>(found_in)->ensure_property_decl(des, name);
      if (property < 0) {
	    found_in = 0;
	    return;
      }
}

static NetNet* find_foreach_this_handle_(Design*des, NetScope*scope)
{
      return find_implicit_this_handle(des, scope);
}

static NetExpr* make_assoc_foreach_method_call_(const LineInfo&li,
						const char*method_name,
						NetExpr*array_expr,
						NetNet*idx_sig)
{
      NetESFunc*call = new NetESFunc(method_name, &netvector_t::atom2u32, 2);
      call->set_line(li);
      call->parm(0, array_expr);

      NetESignal*idx_expr = new NetESignal(idx_sig);
      idx_expr->set_line(li);
      call->parm(1, idx_expr);

      return call;
}

static NetNet* find_assoc_foreach_index_signal_(Design*des, NetScope*scope,
						perm_string index_name)
{
      (void)des;
      NetNet*idx_sig = scope ? scope->find_signal(index_name) : 0;
      if (!idx_sig)
            return 0;

      // If the immediate scope is a foreach autobegin (e.g. $ivl_foreach...),
      // the local index_name signal IS the real foreach loop variable for
      // this foreach. Do not walk up looking for a "real" outer match -- a
      // nested `foreach (regs[i])` inside an outer `foreach (m_aa[i])` must
      // bind the inner `i` to the inner foreach's signal, not the outer.
      auto is_foreach_scope_ = [](NetScope*s) {
            if (!s)
                  return false;
            const char*nm = s->basename().str();
            return nm && (strncmp(nm, "$ivl_foreach", 12) == 0);
      };
      if (is_foreach_scope_(scope))
            return idx_sig;

      bool is_sized_int_shadow =
            idx_sig->get_signed()
         && idx_sig->vector_width() == 32
         && (idx_sig->data_type() == IVL_VT_BOOL
             || idx_sig->data_type() == IVL_VT_LOGIC);

      if (!is_sized_int_shadow)
            return idx_sig;

      for (NetScope*cur = scope ? scope->parent() : 0 ; cur ; cur = cur->parent()) {
            NetNet*outer = cur->find_signal(index_name);
            if (!outer || outer == idx_sig)
                  continue;

            bool outer_is_same_shadow =
                  outer->get_signed()
               && outer->vector_width() == 32
               && (outer->data_type() == IVL_VT_BOOL
                   || outer->data_type() == IVL_VT_LOGIC);

            if (!outer_is_same_shadow)
                  return outer;
      }

      return idx_sig;
}

static NetExpr* make_foreach_array_element_expr_(const LineInfo&li,
						 NetExpr*array_expr,
						 NetNet*idx_sig)
{
      ivl_assert(li, array_expr);
      ivl_assert(li, idx_sig);

      const netarray_t*array_type = dynamic_cast<const netarray_t*>(array_expr->net_type());
      if (!array_type) {
	    delete array_expr;
	    return 0;
      }

      ivl_type_t elem_type = array_type->element_type();
      unsigned elem_width = elem_type ? elem_type->packed_width() : 1;
      if (const netdarray_t*darr = dynamic_cast<const netdarray_t*>(array_type))
	    elem_width = darr->element_width();
      if (elem_width == 0)
	    elem_width = 1;

      NetESignal*idx_expr = new NetESignal(idx_sig);
      idx_expr->set_line(li);

      NetESelect*sel = elem_type
	    ? new NetESelect(array_expr, idx_expr, elem_width, elem_type)
	    : new NetESelect(array_expr, idx_expr, elem_width);
      sel->set_line(li);
      return sel;
}

static NetExpr* make_foreach_queue_size_expr_(const LineInfo&li,
					      NetExpr*array_expr)
{
      ivl_assert(li, array_expr);
      NetESFunc*size_expr = new NetESFunc("$ivl_queue_method$size",
					  &netvector_t::atom2u32, 1);
      size_expr->set_line(li);
      size_expr->parm(0, array_expr);
      return size_expr;
}

static bool foreach_target_is_simple_(const pform_name_t&array_path)
{
      return array_path.size() == 1 && array_path.front().index.empty();
}

static bool foreach_target_is_non_simple_(const pform_name_t&array_path)
{
      if (array_path.size() <= 1)
	    return false;

      for (pform_name_t::const_iterator cur = array_path.begin()
		 ; cur != array_path.end() ; ++cur) {
	    if (!cur->index.empty())
		  return false;
      }

      return true;
}

static NetExpr* elaborate_foreach_target_expr_(Design*des,
					       const LineInfo&li,
					       unsigned lexical_pos,
					       NetScope*scope,
					       const pform_name_t&array_path,
					       ivl_type_t&ptype)
{
      ptype = 0;
      if (!foreach_target_is_non_simple_(array_path))
	    return 0;

      PEIdent ident(array_path, lexical_pos);
      ident.set_line(li);
      NetExpr*target_expr = ident.elaborate_expr(des, scope, 0u, 0u);
      if (!target_expr)
	    return 0;

      ptype = target_expr->net_type();
      return target_expr;
}

/*
 * The foreach statement can be written as a for statement like so:
 *
 *     for (<idx> = $left(<array>) ; <idx> {<,>}= $right(<array>) ; <idx> {+,-}= 1)
 *          <statement_>
 *
 * The <idx> variable is already known to be in the containing named
 * block scope, which was created by the parser.
 */
NetProc* PForeach::elaborate(Design*des, NetScope*scope) const
{
      if (foreach_target_is_non_simple_(array_path_)) {
	    ivl_type_t ptype = 0;
	    NetExpr*array_expr = elaborate_foreach_target_expr_(
		  des, *this, lexical_pos_, scope, array_path_, ptype);

	    if (!array_expr) {
		  cerr << get_fileline() << ": error:"
		       << " Unable to resolve foreach target " << array_path_
		       << " in scope " << scope_path(scope)
		       << "." << endl;
		  des->errors += 1;
		  return 0;
	    }

	    if (const netqueue_t*aq = dynamic_cast<const netqueue_t*>(ptype)) {
		  if (aq->assoc_compat())
			return elaborate_assoc_array_(des, scope, array_expr);
	    }

	    if (const netsarray_t*atype = dynamic_cast<const netsarray_t*>(ptype)) {
		  const netranges_t&dims = atype->static_dimensions();
		  if (dims.size() < index_vars_.size()) {
			delete array_expr;
			cerr << get_fileline() << ": error: "
			     << "property target " << array_path_
			     << " has too few dimensions for foreach dimension list." << endl;
			des->errors += 1;
			return 0;
		  }

		  delete array_expr;
		  return elaborate_static_array_(des, scope, dims);
	    }

	    if (dynamic_cast<const netstring_t*>(ptype)) {
		  delete array_expr;
		  NetProc*sub;
		  if (statement_)
			sub = statement_->elaborate(des, scope);
		  else
			sub = new NetBlock(NetBlock::SEQU, 0);
		  return sub;
	    }

	    if (dynamic_cast<const netarray_t*>(ptype))
		  return elaborate_runtime_array_(des, scope, array_expr);

	    if (const netvector_t*vec = dynamic_cast<const netvector_t*>(ptype)) {
		  // foreach over packed vector: iterate over bits/dims
		  delete array_expr;
		  const netranges_t&dims = vec->packed_dims();
		  if (!dims.empty())
			return elaborate_static_array_(des, scope, dims);
	    }

	    delete array_expr;
	    cerr << get_fileline() << ": error: "
		 << "I can't handle the type of " << array_path_
		 << " as a foreach loop." << endl;
	    des->errors += 1;
	    return 0;
      }

      if (!foreach_target_is_simple_(array_path_)) {
	    cerr << get_fileline() << ": sorry: "
		 << "foreach target " << array_path_
		 << " is not yet supported." << endl;
	    des->errors += 1;
	    return 0;
      }

      perm_string array_var = array_path_.front().name;
	// Locate the signal for the array variable
      pform_name_t array_name = array_path_;
      NetNet*array_sig = des->find_signal(scope, array_name);

	// And if necessary, look for the class property that is
	// referenced.
      const netclass_t*class_scope = 0;
      int class_property = -1;
      if (array_sig == 0)
	    find_property_in_class(des, *this, scope, array_var, class_scope, class_property);

      if (debug_elaborate && array_sig) {
	    cerr << get_fileline() << ": PForeach::elaborate: "
		 << "Found array_sig in " << scope_path(array_sig->scope()) << "." << endl;
      }

      if (debug_elaborate && class_scope) {
	    cerr << get_fileline() << ": PForeach::elaborate: "
		 << "Found array_sig property (" << class_property
		 << ") in class " << class_scope->get_name()
		 << " as " << *class_scope->get_prop_type(class_property) << "." << endl;
      }

      if (class_scope!=0 && class_property >= 0) {
	    ivl_type_t ptype = class_scope->get_prop_type(class_property);
	    if (const netqueue_t*aq = dynamic_cast<const netqueue_t*>(ptype)) {
		  if (aq->assoc_compat()) {
			NetExpr*array_expr = 0;
			property_qualifier_t qual = class_scope->get_prop_qual(class_property);
			if (qual.test_static()) {
			      NetNet*psig = class_scope->find_static_property(array_var);
			      if (!psig) {
			            cerr << get_fileline() << ": error: Failed to resolve static property "
			                 << array_var << " in class " << class_scope->get_name() << "." << endl;
			            des->errors += 1;
			            return 0;
			      }
			      NetESignal*sig_expr = new NetESignal(psig);
			      sig_expr->set_line(*this);
			      array_expr = sig_expr;
			} else {
			      NetNet*this_net = find_foreach_this_handle_(des, scope);
			      if (!this_net) {
			            cerr << get_fileline() << ": internal error: missing synthetic `"
			                 << THIS_TOKEN << "' handle in foreach scope `"
			                 << scope_path(scope) << "'." << endl;
			            des->errors += 1;
			            return 0;
			      }
			      if (!this_net->net_type()
			          || ivl_type_base(this_net->net_type()) != IVL_VT_CLASS) {
			            cerr << get_fileline() << ": error: foreach class-property base is not a class handle"
			                 << " in scope " << scope_path(scope) << "." << endl;
			            des->errors += 1;
			            return 0;
			      }
			      NetESignal*this_expr = new NetESignal(this_net);
			      this_expr->set_line(*this);
			      NetEProperty*prop_expr = new NetEProperty(this_expr, class_property);
			      prop_expr->set_line(*this);
			      array_expr = prop_expr;
			}

			return elaborate_assoc_array_(des, scope, array_expr);
		  }
	    }
	    const netsarray_t*atype = dynamic_cast<const netsarray_t*> (ptype);
	    if (atype != 0) {
		  const netranges_t&dims = atype->static_dimensions();
		  if (dims.size() < index_vars_.size()) {
			cerr << get_fileline() << ": error: "
			     << "class " << class_scope->get_name()
			     << " property " << array_var
			     << " has too few dimensions for foreach dimension list." << endl;
			des->errors += 1;
			return 0;
		  }

		  return elaborate_static_array_(des, scope, dims);
	    }

	    if (dynamic_cast<const netstring_t*>(ptype)) {
		    // String foreach: iterate over characters. For compile-
		    // progress, just elaborate the body without the loop.
		  NetProc*sub;
		  if (statement_)
			sub = statement_->elaborate(des, scope);
		  else
			sub = new NetBlock(NetBlock::SEQU, 0);
		  return sub;
	    }

	    if (dynamic_cast<const netarray_t*>(ptype)) {
		  NetExpr*array_expr = 0;
		  property_qualifier_t qual = class_scope->get_prop_qual(class_property);
		  if (qual.test_static()) {
			NetNet*psig = class_scope->find_static_property(array_var);
			if (!psig) {
			      cerr << get_fileline() << ": error: Failed to resolve static property "
			           << array_var << " in class " << class_scope->get_name() << "." << endl;
			      des->errors += 1;
			      return 0;
			}
			NetESignal*sig_expr = new NetESignal(psig);
			sig_expr->set_line(*this);
			array_expr = sig_expr;
		  } else {
			NetNet*this_net = find_foreach_this_handle_(des, scope);
			if (!this_net) {
			      cerr << get_fileline() << ": internal error: missing synthetic `"
			           << THIS_TOKEN << "' handle in foreach scope `"
			           << scope_path(scope) << "'." << endl;
			      des->errors += 1;
			      return 0;
			}
			if (!this_net->net_type()
			    || ivl_type_base(this_net->net_type()) != IVL_VT_CLASS) {
			      cerr << get_fileline() << ": error: foreach class-property base is not a class handle"
			           << " in scope " << scope_path(scope) << "." << endl;
			      des->errors += 1;
			      return 0;
			}
			NetESignal*this_expr = new NetESignal(this_net);
			this_expr->set_line(*this);
			NetEProperty*prop_expr = new NetEProperty(this_expr, class_property);
			prop_expr->set_line(*this);
			array_expr = prop_expr;
		  }

		  return elaborate_runtime_array_(des, scope, array_expr);
	    }

	    if (const netvector_t*vec = dynamic_cast<const netvector_t*>(ptype)) {
		  // foreach over packed-vector class property: iterate over its bits
		  const netranges_t&dims = vec->packed_dims();
		  if (!dims.empty())
			return elaborate_static_array_(des, scope, dims);
	    }

	    cerr << get_fileline() << ": error: "
		 << "I can't handle the type of " << array_var
		 << " as a foreach loop." << endl;
	    des->errors += 1;
	    return 0;
      }

      if (array_sig == 0) {
	    cerr << get_fileline() << ": error:"
		 << " Unable to find foreach array " << array_name
		 << " in scope " << scope_path(scope)
		 << "." << endl;
	    des->errors += 1;
	    return 0;
      }

      ivl_assert(*this, array_sig);

      if (const netqueue_t*aq = dynamic_cast<const netqueue_t*>(array_sig->net_type())) {
	    if (aq->assoc_compat()) {
		  NetESignal*array_expr = new NetESignal(array_sig);
		  array_expr->set_line(*this);
		  return elaborate_assoc_array_(des, scope, array_expr);
	    }
      }

      if (debug_elaborate) {
	    cerr << get_fileline() << ": PForeach::elaborate: "
		 << "Scan array " << array_sig->name()
		 << " of " << array_sig->data_type()
		 << " with " << array_sig->unpacked_dimensions() << " unpacked"
		 << " and " << array_sig->packed_dimensions()
		 << " packed dimensions." << endl;
      }

      netranges_t dims = array_sig->unpacked_dims();
      if (array_sig->packed_dimensions() > 0) {
            dims.insert(dims.end(), array_sig->packed_dims().begin(), array_sig->packed_dims().end());
      }

	// Classic arrays are processed this way.
      if (array_sig->data_type()==IVL_VT_BOOL)
	    return elaborate_static_array_(des, scope, dims);
      if (array_sig->data_type()==IVL_VT_LOGIC)
	    return elaborate_static_array_(des, scope, dims);
      if (array_sig->unpacked_dimensions() >= index_vars_.size())
	    return elaborate_static_array_(des, scope, dims);

	// At this point, we know that the array is dynamic so we
	// handle that slightly differently, using run-time tests.

      NetESignal*array_expr = new NetESignal(array_sig);
      array_expr->set_line(*this);
      return elaborate_runtime_array_(des, scope, array_expr);
}

/*
 * This is a variant of the PForeach::elaborate() method that handles
 * the case that the array has static dimensions. We can use constants
 * and possibly do some optimizations.
 */
NetProc* PForeach::elaborate_static_array_(Design*des, NetScope*scope,
					   const netranges_t&dims) const
{
      if (debug_elaborate) {
	    cerr << get_fileline() << ": PForeach::elaborate_static_array_: "
		 << "Handle as array with static dimensions." << endl;
      }

      NetProc*sub;
      if (statement_)
	    sub = statement_->elaborate(des, scope);
      else
	    sub = new NetBlock(NetBlock::SEQU, 0);
      NetForLoop*stmt = 0;

      if (index_vars_.size() > dims.size()) {
	    delete sub;
	    cerr << get_fileline() << ": error: Number of foreach loop variables"
	         << "(" << index_vars_.size() << ") must not exceed number of "
		 << "array dimensions (" << dims.size() << ")." << endl;
	    des->errors++;
	    return nullptr;
      }

      for (int idx_idx = index_vars_.size()-1 ; idx_idx >= 0 ; idx_idx -= 1) {
	    const netrange_t&idx_range = dims[idx_idx];

	      // It is possible to skip dimensions by not providing a identifier
	      // name for it. E.g. `int x[1][2][3]; foreach(x[a,,b]) ...`
	    if (index_vars_[idx_idx].nil())
		  continue;

	      // Get the $high and $low constant values for this slice
	      // of the array.
	    NetEConst*left_expr = make_const_val_s(idx_range.get_msb());
	    NetEConst*right_expr = make_const_val_s(idx_range.get_lsb());

	    bool up = idx_range.get_msb() < idx_range.get_lsb();

	    left_expr->set_line(*this);
	    right_expr->set_line(*this);

	    pform_name_t idx_name;
	    idx_name.push_back(name_component_t(index_vars_[idx_idx]));
	    NetNet*idx_sig = des->find_signal(scope, idx_name);
	    ivl_assert(*this, idx_sig);

	      // Make the condition expression <idx> {<,>}= $right(slice)
	    NetESignal*idx_expr = new NetESignal(idx_sig);
	    idx_expr->set_line(*this);

	    NetEBComp*cond_expr = new NetEBComp(up ? 'L' : 'G', idx_expr, right_expr);
	    cond_expr->set_line(*this);

	      // Make the step statement: <idx> {+,-}= 1
	    NetAssign_*idx_lv = new NetAssign_(idx_sig);
	    NetEConst*step_val = make_const_val_s(1);
	    NetAssign*step = new NetAssign(idx_lv, up ? '+' : '-', step_val);
	    step->set_line(*this);

	    stmt = new NetForLoop(idx_sig, left_expr, cond_expr, sub, step);
	    stmt->set_line(*this);

	    sub = stmt;
      }

        // If there are no loop variables elide the whole block
      if (!stmt) {
	    delete sub;
	    return new NetBlock(NetBlock::SEQU, 0);
      }

      return stmt;
}

NetProc* PForeach::elaborate_runtime_array_(Design*des, NetScope*scope,
					    NetExpr*array_expr) const
{
      return elaborate_runtime_array_(des, scope, array_expr, 0);
}

NetProc* PForeach::elaborate_runtime_array_(Design*des, NetScope*scope,
					    NetExpr*array_expr,
					    size_t index_var_start) const
{
      ivl_assert(*this, array_expr);

      if (index_var_start >= index_vars_.size()) {
	    delete array_expr;
	    if (statement_)
		  return statement_->elaborate(des, scope);
	    return new NetBlock(NetBlock::SEQU, 0);
      }

      if (index_vars_[index_var_start].nil()) {
	    delete array_expr;
	    cerr << get_fileline() << ": sorry: runtime-array foreach requires"
	         << " named index variables for iterated dimensions." << endl;
	    des->errors += 1;
	    return 0;
      }

      if (index_vars_.size() != index_var_start + 1) {
	    if (gn_system_verilog()) {
	    } else {
		  cerr << get_fileline() << ": sorry: "
		       << "Multi-index foreach loops not supported." << endl;
		  des->errors += 1;
	    }
      }

      pform_name_t index_name;
      index_name.push_back(name_component_t(index_vars_[index_var_start]));
      NetNet*idx_sig = find_assoc_foreach_index_signal_(des, scope,
							index_vars_[index_var_start]);
      ivl_assert(*this, idx_sig);

      NetESignal*idx_exp = new NetESignal(idx_sig);
      idx_exp->set_line(*this);

      NetExpr*init_expr = 0;
      NetExpr*limit_expr = 0;
      char cond_op = 'L';
      if (dynamic_cast<const netqueue_t*>(array_expr->net_type())) {
	    init_expr = make_const_val(0);
	    init_expr->set_line(*this);
	    limit_expr = make_foreach_queue_size_expr_(*this, array_expr);
	    cond_op = '<';
      } else {
	    NetESFunc*low_expr = new NetESFunc("$low", &netvector_t::atom2s32, 1);
	    low_expr->set_line(*this);
	    low_expr->parm(0, array_expr);
	    init_expr = low_expr;

	    NetESFunc*high_expr = new NetESFunc("$high", &netvector_t::atom2s32, 1);
	    high_expr->set_line(*this);
	    high_expr->parm(0, array_expr->dup_expr());
	    limit_expr = high_expr;
      }

      NetEBComp*cond_expr = new NetEBComp(cond_op, idx_exp, limit_expr);
      cond_expr->set_line(*this);

      NetProc*sub;
      if (index_var_start + 1 < index_vars_.size()) {
	    NetExpr*elem_expr = make_foreach_array_element_expr_(*this,
								 array_expr->dup_expr(),
								 idx_sig);
	    if (!elem_expr) {
		  delete array_expr;
		  return 0;
	    }
	    sub = elaborate_runtime_array_(des, scope, elem_expr, index_var_start + 1);
	    if (!sub) {
		  delete array_expr;
		  return 0;
	    }
      } else if (statement_) {
	    sub = statement_->elaborate(des, scope);
      } else {
	    sub = new NetBlock(NetBlock::SEQU, 0);
      }

      NetAssign_*idx_lv = new NetAssign_(idx_sig);
      NetEConst*step_val = make_const_val(1);
      NetAssign*step = new NetAssign(idx_lv, '+', step_val);
      step->set_line(*this);

      NetForLoop*stmt = new NetForLoop(idx_sig, init_expr, cond_expr, sub, step);
      stmt->set_line(*this);
      return stmt;
}

NetProc* PForeach::elaborate_assoc_array_(Design*des, NetScope*scope,
					  NetExpr*array_expr) const
{
      ivl_assert(*this, array_expr);

      if (index_vars_.empty() || index_vars_[0].nil()) {
	    delete array_expr;
	    cerr << get_fileline() << ": sorry: associative-array foreach"
	         << " requires a named associative index variable." << endl;
	    des->errors += 1;
	    return 0;
      }

      pform_name_t index_name;
      index_name.push_back(name_component_t(index_vars_[0]));
      NetNet*idx_sig = find_assoc_foreach_index_signal_(des, scope, index_vars_[0]);
      ivl_assert(*this, idx_sig);

      NetProc*sub;
      if (index_vars_.size() > 1) {
	    NetExpr*elem_expr = make_foreach_array_element_expr_(*this,
								 array_expr->dup_expr(),
								 idx_sig);
	    if (!elem_expr) {
		  delete array_expr;
		  cerr << get_fileline() << ": warning: associative-array foreach"
		       << " can only descend into array-like element types"
		       << " (compile-progress: loop body dropped)." << endl;
		  return 0;
	    }
	    sub = elaborate_runtime_array_(des, scope, elem_expr, 1);
	    if (!sub) {
		  delete array_expr;
		  return 0;
	    }
      } else if (statement_) {
	    sub = statement_->elaborate(des, scope);
      } else {
	    sub = new NetBlock(NetBlock::SEQU, 0);
      }

      NetExpr*next_expr = make_assoc_foreach_method_call_(*this,
							  "$ivl_assoc_method$next",
							  array_expr->dup_expr(),
							  idx_sig);
      NetDoWhile*loop = new NetDoWhile(next_expr, sub);
      loop->set_line(*this);

      NetExpr*first_expr = make_assoc_foreach_method_call_(*this,
							   "$ivl_assoc_method$first",
							   array_expr,
							   idx_sig);
      NetBlock*noop = new NetBlock(NetBlock::SEQU, 0);
      NetCondit*stmt = new NetCondit(first_expr, loop, noop);
      stmt->set_line(*this);
      return stmt;
}

/*
 * Elaborate the PForStatement as discovered by the parser into a
 * NetForLoop object. The parser detects the:
 *
 *  - index variable (name1_)  (optional)
 *  - initial value (expr1_)   (only if name1_ is present)
 *  - condition expression (cond_) (optional)
 *  - step statement (step_)   (optional)
 *  - sub-statement (statement_)
 *
 * The rules that lead to the PForStatment look like:
 *
 *    for ( <name1_> = <expr1_> ; <cond_> ; <step_> ) <statement_>
 *    for ( ; <cond_ ; <step_> ) <statement_>
 */
NetProc* PForStatement::elaborate(Design*des, NetScope*scope) const
{
      NetExpr*initial_expr;
      NetNet*sig;
      bool error_flag = false;
      ivl_assert(*this, scope);

      if (!name1_) {
	    // If there is no initial assignment expression, then mark that
	    // fact with null pointers.
	    ivl_assert(*this, !expr1_);
	    sig = nullptr;
	    initial_expr = nullptr;

      } else if (const PEIdent*id1 = dynamic_cast<const PEIdent*>(name1_)) {
	    // If there is an initialization assignment, make the expression,
	    // and later the initial assignment to the condition variable. The
	    // statement in the for loop is very specifically an assignment.
	    sig = des->find_signal(scope, id1->path().name);
	    if (sig == 0) {
		  cerr << id1->get_fileline() << ": register ``" << id1->path()
		       << "'' unknown in " << scope_path(scope) << "." << endl;
		  des->errors += 1;
		  return 0;
	    }

	    // Make the r-value of the initial assignment, and size it
	    // properly. Then use it to build the assignment statement.
	    initial_expr = elaborate_rval_expr(des, scope, sig->net_type(),
					       expr1_);
	    if (!initial_expr)
		  error_flag = true;

	    if (debug_elaborate && initial_expr) {
		  cerr << get_fileline() << ": debug: FOR initial assign: "
		       << sig->name() << " = " << *initial_expr << endl;
	    }

      } else {
	    cerr << get_fileline() << ": internal error: "
		 << "Index name " << *name1_ << " is not a PEIdent." << endl;
	    des->errors += 1;
	    return 0;
      }

      // Elaborate the statement that is contained in the for
      // loop. If there is an error, this will return 0 and I should
      // skip the append. No need to worry, the error has been
      // reported so it's OK that the netlist is bogus.
      NetProc*sub;
      if (statement_) {
	    sub = statement_->elaborate(des, scope);
	    if (sub == 0)
		  error_flag = true;
      } else {
	    sub = new NetBlock(NetBlock::SEQU, 0);
      }

      // Now elaborate the for_step statement. I really should do
      // some error checking here to make sure the step statement
      // really does step the variable.
      NetProc*step = nullptr;
      if (step_) {
	    step = step_->elaborate(des, scope);
	    if (!step)
		  error_flag = true;
      }

      // Elaborate the condition expression, but do not aggressively
      // constant-fold it here. In SV/UVM code, method/property-based
      // conditions (e.g. queue.size()) must remain runtime-evaluated.
      NetExpr*ce = nullptr;
      if (cond_) {
	    PExpr::width_mode_t mode = PExpr::SIZED;
	    cond_->test_width(des, scope, mode);
	    ce = cond_->elaborate_expr(des, scope, cond_->expr_width(),
				       PExpr::NO_FLAGS);
	    if (!ce)
		  error_flag = true;
      }

      // Error recovery - if we failed to elaborate any of the loop
      // expressions, give up now. Error counts where handled elsewhere.
      if (error_flag) {
	    if (initial_expr) delete initial_expr;
	    if (ce) delete ce;
	    if (step) delete step;
	    if (sub) delete sub;
	    return 0;
      }

      // All done, build up the loop. Note that sig and initial_expr may be
      // nil. But if one is nil, then so is the other. The follow-on code
      // can handle that case, but let's make sure with an assert that we
      // have a consistent input.
      ivl_assert(*this, sig || !initial_expr);

      NetForLoop*loop = new NetForLoop(sig, initial_expr, ce, sub, step);
      loop->set_line(*this);
      return loop;
}

/*
 * (See the PTask::elaborate methods for basic common stuff.)
 *
 * The return value of a function is represented as a reg variable
 * within the scope of the function that has the name of the
 * function. So for example with the function:
 *
 *    function [7:0] incr;
 *      input [7:0] in1;
 *      incr = in1 + 1;
 *    endfunction
 *
 * The scope of the function is <parent>.incr and there is a reg
 * variable <parent>.incr.incr. The elaborate_1 method is called with
 * the scope of the function, so the return reg is easily located.
 *
 * The function parameters are all inputs, except for the synthetic
 * output parameter that is the return value. The return value goes
 * into port 0, and the parameters are all the remaining ports.
 */

void PFunction::elaborate(Design*des, NetScope*scope) const
{
      if (scope->elab_stage() > 2)
            return;

      NetFuncDef*def = scope->func_def();
      if (def == 0) {
	    // On-demand function elaboration can reach here before the signal
	    // elaboration pass has created the NetFuncDef (common for extern
	    // class methods). Build the signature now if needed.
	    elaborate_sig(des, scope);
	    def = scope->func_def();
      }

      scope->set_elab_stage(3);

      if (def == 0) {
	    cerr << get_fileline() << ": internal error: "
		 << "No function definition for function "
		 << scope_path(scope) << endl;
	    des->errors += 1;
	    return;
      }
      ivl_assert(*this, def);

      NetProc*st;
      if (statement_ == 0) {
	    st = new NetBlock(NetBlock::SEQU, 0);
      } else {
	    if (const char*env = getenv("IVL_CTOR_BLEND_TRACE")) {
		  if (*env && strcmp(env, "0") != 0
		      && scope->basename() == perm_string::literal("new")
		      && scope->parent() && scope->parent()->basename() == perm_string::literal("uvm_default_report_server")) {
			cerr << get_fileline()
			     << ": debug: ctor-dump before elaborate scope=" << scope_path(scope)
			     << endl;
			statement_->dump(cerr, 2);
		  }
	    }
	    st = statement_->elaborate(des, scope);
	    if (st == 0) {
		  cerr << statement_->get_fileline() << ": error: Unable to elaborate "
			  "statement in function " << scope->basename() << "." << endl;
		  scope->is_const_func(true); // error recovery
		  des->errors += 1;
		  return;
	    }
      }

	// Handle any variable initialization statements in this scope.
	// For automatic functions, these statements need to be executed
	// each time the function is called, so insert them at the start
	// of the elaborated definition. For static functions, put them
	// in a separate process that will be executed before the start
	// of simulation.
      if (is_auto_) {
	      // Split var_inits by the target variable's lifetime.
	      // Variables explicitly declared `static` inside an automatic
	      // function should be initialized ONCE at simulation start, not
	      // on every call. Auto-lifetime initializers go into the
	      // function body so they run on each entry.
	    std::vector<Statement*> static_inits;
	    std::vector<Statement*> auto_inits;
	    for (Statement*stmt : var_inits) {
		  bool is_static_init = false;
		  if (const PAssign_*as = dynamic_cast<const PAssign_*>(stmt)) {
			if (const PEIdent*id = dynamic_cast<const PEIdent*>(as->lval())) {
			      perm_string nm = peek_tail_name(id->path());
			      if (PWire*pw =
				    const_cast<PFunction*>(this)->wires_find(nm)) {
				    if (pw->lifetime_override() == IVL_VLT_STATIC)
					  is_static_init = true;
			      }
			}
		  }
		  if (is_static_init)
			static_inits.push_back(stmt);
		  else
			auto_inits.push_back(stmt);
	    }

	    if (!auto_inits.empty()) {
		    // Get the NetBlock of the statement. If it is not a
		    // NetBlock then create one to wrap the initialization
		    // statements and the original statement.
		  NetBlock*blk = dynamic_cast<NetBlock*> (st);
		  if (blk == 0) {
			blk = new NetBlock(NetBlock::SEQU, scope);
			blk->set_line(*this);
			blk->append(st);
			st = blk;
		  }
		  for (size_t idx = auto_inits.size(); idx > 0; idx -= 1) {
			NetProc*tmp = auto_inits[idx-1]->elaborate(des, scope);
			if (tmp) blk->prepend(tmp);
		  }
	    }

	    if (!static_inits.empty()) {
		    // Emit the static initializers as a one-shot module-init
		    // process so each runs once at sim start.
		  NetProc*proc = 0;
		  if (static_inits.size() == 1) {
			proc = static_inits[0]->elaborate(des, scope);
		  } else {
			NetBlock*blk = new NetBlock(NetBlock::SEQU, 0);
			for (Statement*s : static_inits) {
			      NetProc*tmp = s->elaborate(des, scope);
			      if (tmp) blk->append(tmp);
			}
			proc = blk;
		  }
		  if (proc) {
			NetProcTop*top = new NetProcTop(scope, IVL_PR_INITIAL, proc);
			if (const LineInfo*li = dynamic_cast<const LineInfo*>(this)) {
			      top->set_line(*li);
			}
			if (gn_system_verilog())
			      top->attribute(perm_string::literal("_ivl_schedule_init"),
					     verinum(1));
			des->add_process(top);
		  }
	    }
      } else {
	    elaborate_var_inits_(des, scope);
      }

      def->set_proc(st);
}

NetProc* PRelease::elaborate(Design*des, NetScope*scope) const
{
      ivl_assert(*this, scope);

      if (scope->is_auto() && lval_->has_aa_term(des, scope)) {
	    cerr << get_fileline() << ": error: automatically allocated "
                    "variables may not be assigned values using procedural "
	            "force statements." << endl;
	    des->errors += 1;
	    return 0;
      }

      NetAssign_*lval = lval_->elaborate_lval(des, scope, false, true);
      if (lval == 0)
	    return 0;

      NetRelease*dev = new NetRelease(lval);
      dev->set_line( *this );
      return dev;
}

NetProc* PRepeat::elaborate(Design*des, NetScope*scope) const
{
      ivl_assert(*this, scope);

      NetExpr*expr = nullptr;
      if (gn_system_verilog()) {
	    PExpr::width_mode_t mode = PExpr::SIZED;
	    expr_->test_width(des, scope, mode);
	    expr = expr_->elaborate_expr(des, scope, expr_->expr_width(),
					 PExpr::NO_FLAGS);
      } else {
	    expr = elab_and_eval(des, scope, expr_, -1);
      }
      if (expr == 0) {
	    cerr << get_fileline() << ": Unable to elaborate"
		  " repeat expression." << endl;
	    des->errors += 1;
	    return 0;
      }
	// If the expression is real, convert to an integer. 64 bits
	// should be more enough for any real use case.
      if (expr->expr_type() == IVL_VT_REAL)
	    expr = cast_to_int4(expr, 64);

      NetProc*stat;
      if (statement_)
	    stat = statement_->elaborate(des, scope);
      else
	    stat = new NetBlock(NetBlock::SEQU, 0);
      if (stat == 0) return 0;

	// If the expression is a constant, handle certain special
	// iteration counts.
      if (const NetEConst*ce = dynamic_cast<NetEConst*>(expr)) {
	    long val = ce->value().as_long();
	    if (val <= 0) {
		  delete expr;
		  delete stat;
		  return new NetBlock(NetBlock::SEQU, 0);
	    } else if (val == 1) {
		  delete expr;
		  return stat;
	    }
      }

      NetRepeat*proc = new NetRepeat(expr, stat);
      proc->set_line( *this );
      return proc;
}

NetProc* PReturn::elaborate(Design*des, NetScope*scope) const
{
      NetScope*target = scope;

      if (des->is_in_fork()) {
	    cerr << get_fileline() << ": error: "
		 << "Return statement is not allowed within fork-join block." << endl;
	    des->errors += 1;
	    return 0;
      }

      for (;;) {
	    if (target == 0) {
		  cerr << get_fileline() << ": error: "
		       << "Return statement is not in a function or task."
		       << endl;
		  des->errors += 1;
		  return 0;
	    }

	    if (target->type() == NetScope::FUNC)
		  break;
	    if (target->type() == NetScope::TASK)
		  break;

	    if (target->type()==NetScope::BEGIN_END) {
		  target = target->parent();
		  continue;
	    }

	    cerr << get_fileline() << ": error: "
		 << "Cannot \"return\" from this scope: " << scope_path(target) << endl;
	    des->errors += 1;
	    return 0;
      }

      if (target->type() == NetScope::TASK) {
	    if (expr_) {
		  cerr << get_fileline() << ": error: "
		       << "A value cannot be returned from a task." << endl;
		  des->errors += 1;
		  return 0;
	    }
	    NetDisable *disa = new NetDisable(target, true);
	    disa->set_line(*this);
	    return disa;
      }

      ivl_assert(*this, target->type() == NetScope::FUNC);

      if (target->func_def()->is_void()) {
	    if (expr_) {
		  cerr << get_fileline() << ": error: "
		       << "A value can't be returned from a void function." << endl;
		  des->errors += 1;
		  return 0;
	    }
	    NetDisable*disa = new NetDisable(target, true);
	    disa->set_line( *this );
	    return disa;
      }

      if (expr_ == 0) {
	      // SV constructors (new/new@) implicitly return the constructed
	      // object.  A bare "return;" is valid and just exits early.
	    if (gn_system_verilog()
		&& (target->basename() == perm_string::literal("new")
		    || target->basename() == perm_string::literal("new@"))) {
		  NetDisable*disa = new NetDisable(target, true);
		  disa->set_line(*this);
		  return disa;
	    }
	    cerr << get_fileline() << ": error: "
		 << "Return from " << scope_path(target)
		 << " requires a return value expression." << endl;
	    des->errors += 1;
	    return 0;
      }

      NetNet*res = target->find_signal(target->basename());
      ivl_assert(*this, res);
      NetAssign_*lv = new NetAssign_(res);

      NetExpr*val = elaborate_return_enum_literal_fallback_(des, scope, res->net_type(), expr_);
      if (!val)
	    val = elaborate_rval_expr(des, scope, res->net_type(), expr_);

      NetBlock*proc = new NetBlock(NetBlock::SEQU, 0);
      proc->set_line( *this );

      NetAssign*assn = new NetAssign(lv, val);
      assn->set_line( *this );
      proc->append(assn);

      NetDisable*disa = new NetDisable(target, true);
      disa->set_line( *this );
      proc->append( disa );

      return proc;
}

/*
 * A task definition is elaborated by elaborating the statement that
 * it contains, and connecting its ports to NetNet objects. The
 * netlist doesn't really need the array of parameters once elaboration
 * is complete, but this is the best place to store them.
 *
 * The first elaboration pass finds the reg objects that match the
 * port names, and creates the NetTaskDef object. The port names are
 * in the form task.port.
 *
 *      task foo;
 *        output blah;
 *        begin <body> end
 *      endtask
 *
 * So in the foo example, the PWire objects that represent the ports
 * of the task will include a foo.blah for the blah port. This port is
 * bound to a NetNet object by looking up the name. All of this is
 * handled by the PTask::elaborate_sig method and the results stashed
 * in the created NetTaskDef attached to the scope.
 *
 * Elaboration pass 2 for the task definition causes the statement of
 * the task to be elaborated and attached to the NetTaskDef object
 * created in pass 1.
 *
 * NOTE: I am not sure why I bothered to prepend the task name to the
 * port name when making the port list. It is not really useful, but
 * that is what I did in pform_make_task_ports, so there it is.
 */

void PTask::elaborate(Design*des, NetScope*task) const
{
      if (task->elab_stage() > 2)
	    return;

      NetTaskDef*def = task->task_def();
      if (def == 0) {
	    elaborate_sig(des, task);
	    def = task->task_def();
      }

      task->set_elab_stage(3);
      ivl_assert(*this, def);

      NetProc*st;
      if (statement_ == 0) {
	    st = new NetBlock(NetBlock::SEQU, 0);
      } else {
	    st = statement_->elaborate(des, task);
	    if (st == 0) {
		  cerr << statement_->get_fileline() << ": Unable to elaborate "
			"statement in task " << scope_path(task)
		       << " at " << get_fileline() << "." << endl;
		  return;
	    }
      }

	// Handle any variable initialization statements in this scope.
	// For automatic tasks , these statements need to be executed
	// each time the task is called, so insert them at the start
	// of the elaborated definition. For static tasks, put them
	// in a separate process that will be executed before the start
	// of simulation.
      if (is_auto_) {
	      // Get the NetBlock of the statement. If it is not a
	      // NetBlock then create one to wrap the initialization
	      // statements and the original statement.
	    NetBlock*blk = dynamic_cast<NetBlock*> (st);
	    if ((blk == 0) && (var_inits.size() > 0)) {
		  blk = new NetBlock(NetBlock::SEQU, task);
		  blk->set_line(*this);
		  blk->append(st);
		  st = blk;
	    }
	    for (unsigned idx = var_inits.size(); idx > 0; idx -= 1) {
		  NetProc*tmp = var_inits[idx-1]->elaborate(des, task);
		  if (tmp) blk->prepend(tmp);
	    }
      } else {
	    elaborate_var_inits_(des, task);
      }

      def->set_proc(st);
}

NetProc* PTrigger::elaborate(Design*des, NetScope*scope) const
{
      ivl_assert(*this, scope);

      symbol_search_results sr;
      if (!symbol_search(this, des, scope, event_, lexical_pos_, &sr)) {
	    cerr << get_fileline() << ": error: event <" << event_ << ">"
		 << " not found." << endl;
	    if (sr.decl_after_use) {
		  cerr << sr.decl_after_use->get_fileline() << ":      : "
			  "A symbol with that name was declared here. "
			  "Check for declaration after use." << endl;
	    }
	    des->errors += 1;
	    return 0;
      }

      NetEvent*eve = resolve_named_event_member_from_search_(sr);
      if (!eve) {
	    cerr << get_fileline() << ": error:  <" << event_ << ">"
		 << " is not a named event." << endl;
	    des->errors += 1;
	    return 0;
      }

      NetEvTrig*trig = new NetEvTrig(eve);
      trig->set_line(*this);
      return trig;
}

NetProc* PNBTrigger::elaborate(Design*des, NetScope*scope) const
{
      ivl_assert(*this, scope);

      symbol_search_results sr;
      if (!symbol_search(this, des, scope, event_, lexical_pos_, &sr)) {
	    cerr << get_fileline() << ": error: event <" << event_ << ">"
		 << " not found." << endl;
	    if (sr.decl_after_use) {
		  cerr << sr.decl_after_use->get_fileline() << ":      : "
			  "A symbol with that name was declared here. "
			  "Check for declaration after use." << endl;
	    }
	    des->errors += 1;
	    return 0;
      }

      NetEvent*eve = resolve_named_event_member_from_search_(sr);
      if (eve == 0) {
	    cerr << get_fileline() << ": error:  <" << event_ << ">"
		 << " is not a named event." << endl;
	    des->errors += 1;
	    return 0;
      }

      NetExpr*dly = 0;
      if (dly_) dly = elab_and_eval(des, scope, dly_, -1);
      NetEvNBTrig*trig = new NetEvNBTrig(eve, dly);
      trig->set_line(*this);
      return trig;
}

/*
 * The while loop is fairly directly represented in the netlist.
 */
NetProc* PWhile::elaborate(Design*des, NetScope*scope) const
{
      NetExpr*ce = nullptr;
      if (gn_system_verilog()) {
	    PExpr::width_mode_t mode = PExpr::SIZED;
	    cond_->test_width(des, scope, mode);
	    ce = cond_->elaborate_expr(des, scope, cond_->expr_width(),
				       PExpr::NO_FLAGS);
      } else {
	    ce = elab_and_eval(des, scope, cond_, -1);
      }
      NetProc*sub;
      if (statement_)
	    sub = statement_->elaborate(des, scope);
      else
	    sub = new NetBlock(NetBlock::SEQU, 0);
      if (ce == 0 || sub == 0) {
	    delete ce;
	    delete sub;
	    return 0;
      }
      NetWhile*loop = new NetWhile(ce, sub);
      loop->set_line(*this);
      return loop;
}

bool PProcess::elaborate(Design*des, NetScope*scope) const
{
      scope->in_final(type() == IVL_PR_FINAL);
      NetProc*cur = statement_->elaborate(des, scope);
      scope->in_final(false);
      if (cur == 0) {
	    return false;
      }

      NetProcTop*top=new NetProcTop(scope, type(), cur);
      ivl_assert(*this, top);

	// Evaluate the attributes for this process, if there
	// are any. These attributes are to be attached to the
	// NetProcTop object.
      struct attrib_list_t*attrib_list;
      unsigned attrib_list_n = 0;
      attrib_list = evaluate_attributes(attributes, attrib_list_n, des, scope);

      for (unsigned adx = 0 ;  adx < attrib_list_n ;  adx += 1)
	    top->attribute(attrib_list[adx].key,
			   attrib_list[adx].val);

      delete[]attrib_list;

      top->set_line(*this);
      des->add_process(top);

	/* Detect the special case that this is a combinational
	always block. We want to attach an _ivl_schedule_push
	attribute to this process so that it starts up and
	gets into its wait statement before non-combinational
	code is executed. */
      do {
	    if ((top->type() != IVL_PR_ALWAYS) &&
	        (top->type() != IVL_PR_ALWAYS_COMB) &&
	        (top->type() != IVL_PR_ALWAYS_FF) &&
	        (top->type() != IVL_PR_ALWAYS_LATCH))
		  break;

	    NetEvWait*st = dynamic_cast<NetEvWait*>(top->statement());
	    if (st == 0)
		  break;

	    if (st->nevents() != 1)
		  break;

	    NetEvent*ev = st->event(0);

	    if (ev->nprobe() == 0)
		  break;

	    bool anyedge_test = true;
	    for (unsigned idx = 0 ;  anyedge_test && (idx<ev->nprobe())
		       ; idx += 1) {
		  const NetEvProbe*pr = ev->probe(idx);
		  if (pr->edge() != NetEvProbe::ANYEDGE)
			anyedge_test = false;
	    }

	    if (! anyedge_test)
		  break;

	    top->attribute(perm_string::literal("_ivl_schedule_push"),
			   verinum(1));
      } while (0);

      return true;
}

void PSpecPath::elaborate(Design*des, NetScope*scope) const
{
      uint64_t delay_value[12];
      unsigned ndelays = 0;

	/* Do not elaborate specify delay paths if this feature is
	   turned off. */
      if (!gn_specify_blocks_flag) return;

      ivl_assert(*this, conditional || (condition==0));

      ndelays = delays.size();
      if (ndelays > 12) ndelays = 12;

      check_for_inconsistent_delays(scope);

	/* Elaborate the delay values themselves. Remember to scale
	   them for the timescale/precision of the scope. */
      for (unsigned idx = 0 ;  idx < ndelays ;  idx += 1) {
	    PExpr*exp = delays[idx];
	    NetExpr*cur = elab_and_eval(des, scope, exp, -1);

	    if (const NetEConst*con = dynamic_cast<NetEConst*> (cur)) {
		  verinum fn = con->value();
		  delay_value[idx] = des->scale_to_precision(fn.as_ulong64(),
		                                             scope);

	    } else if (const NetECReal*rcon = dynamic_cast<NetECReal*>(cur)) {
		  delay_value[idx] = get_scaled_time_from_real(des, scope,
		                                               rcon);

	    } else {
		  cerr << get_fileline() << ": error: Path delay value "
		       << "must be constant (" << *cur << ")." << endl;
		  delay_value[idx] = 0;
		  des->errors += 1;
	    }
	    delete cur;
      }

      switch (delays.size()) {
	  case 1:
	  case 2:
	  case 3:
	  case 6:
	  case 12:
	    break;
	  default:
	    cerr << get_fileline() << ": error: Incorrect delay configuration."
		 << " Given " << delays.size() << " delay expressions." << endl;
	    ndelays = 1;
	    des->errors += 1;
	    break;
      }

      NetNet*condit_sig = 0;
      if (conditional && condition) {

	    NetExpr*tmp = elab_and_eval(des, scope, condition, -1);
	    ivl_assert(*condition, tmp);

	      // FIXME: Look for constant expressions here?

	      // Get a net form.
	    condit_sig = tmp->synthesize(des, scope, tmp);
	    ivl_assert(*condition, condit_sig);
      }

	/* A parallel connection does not support more than a one to one
	   connection (source/destination). */
      if (! full_flag_ && ((src.size() != 1) || (dst.size() != 1))) {
	    /* To be compatible with NC-Verilog we allow a parallel connection
	     * with multiple sources/destinations if all the paths are only a
	     * single bit wide (a scalar or a one bit vector). */
	    bool all_single = true;
	    typedef std::vector<perm_string>::const_iterator str_vec_iter;
	    for (str_vec_iter cur = src.begin();
		 ( cur != src.end() && all_single); ++ cur) {
		  const NetNet *psig = scope->find_signal(*cur);
		    /* We will report a missing signal as invalid later. For
		     * now assume it's a single bit. */
		  if (psig == 0) continue;
		  if (psig->vector_width() != 1) all_single = false;
	    }
	    for (str_vec_iter cur = dst.begin();
		 ( cur != dst.end() && all_single); ++ cur) {
		  const NetNet *psig = scope->find_signal(*cur);
		    /* The same as above for source paths. */
		  if (psig == 0) continue;
		  if (psig->vector_width() != 1) all_single = false;
	    }

	    if (! all_single) {
		  cerr << get_fileline() << ": error: Parallel connections "
		          "only support one source/destination path found ("
		       << src.size() << "/" << dst.size() << ")." << endl;
		  des->errors += 1;
	    }
      }

	/* Create all the various paths from the path specifier. */
      typedef std::vector<perm_string>::const_iterator str_vector_iter;
      for (str_vector_iter cur = dst.begin()
		 ; cur != dst.end() ; ++ cur ) {

	    if (debug_elaborate) {
		  cerr << get_fileline() << ": debug: Path to " << (*cur);
		  if (condit_sig)
			cerr << " if " << condit_sig->name();
		  else if (conditional)
			cerr << " ifnone";
		  cerr << " from ";
	    }

	    NetNet*dst_sig = scope->find_signal(*cur);
	    if (dst_sig == 0) {
		  cerr << get_fileline() << ": error: No wire '"
		       << *cur << "' in this module." << endl;
		  des->errors += 1;
		  continue;
	    }

	    unsigned long dst_wid = dst_sig->vector_width();

	    if (dst_sig->port_type() != NetNet::POUTPUT
		&& dst_sig->port_type() != NetNet::PINOUT) {

		  cerr << get_fileline() << ": error: Path destination "
		       << *cur << " must be an output or inout port." << endl;
		  des->errors += 1;
	    }

	    NetDelaySrc*path = new NetDelaySrc(scope, scope->local_symbol(),
					       src.size(), condit_sig,
					       conditional, !full_flag_);
	    path->set_line(*this);

	      // The presence of the data_source_expression indicates
	      // that this is an edge sensitive path. If so, then set
	      // the edges. Note that edge==0 is BOTH edges.
	    if (data_source_expression) {
		  if (edge >= 0) path->set_posedge();
		  if (edge <= 0) path->set_negedge();
	    }

	    switch (ndelays) {
		case 12:
		  path->set_delays(delay_value[0],  delay_value[1],
				   delay_value[2],  delay_value[3],
				   delay_value[4],  delay_value[5],
				   delay_value[6],  delay_value[7],
				   delay_value[8],  delay_value[9],
				   delay_value[10], delay_value[11]);
		  break;
		case 6:
		  path->set_delays(delay_value[0], delay_value[1],
				   delay_value[2], delay_value[3],
				   delay_value[4], delay_value[5]);
		  break;
		case 3:
		  path->set_delays(delay_value[0], delay_value[1],
				   delay_value[2]);
		  break;
		case 2:
		  path->set_delays(delay_value[0], delay_value[1]);
		  break;
		case 1:
		  path->set_delays(delay_value[0]);
		  break;
	    }

	    unsigned idx = 0;
	    for (str_vector_iter cur_src = src.begin()
		       ; cur_src != src.end() ; ++ cur_src ) {
		  NetNet*src_sig = scope->find_signal(*cur_src);
		  if (src_sig == 0) {
			cerr << get_fileline() << ": error: No wire '"
			     << *cur_src << "' in this module." << endl;
			des->errors += 1;
			continue;
		  }

		  if (debug_elaborate) {
			if (cur_src != src.begin()) cerr << " and ";
			cerr << src_sig->name();
		  }

		  if ( (src_sig->port_type() != NetNet::PINPUT)
		    && (src_sig->port_type() != NetNet::PINOUT) ) {

			cerr << get_fileline() << ": error: Path source "
			     << *cur_src << " must be an input or inout port."
			     << endl;
			des->errors += 1;
		  }

		    // For a parallel connection the source and destination
		    // must be the same width.
		  if (! full_flag_) {
			unsigned long src_wid = src_sig->vector_width();
			if (src_wid != dst_wid) {
			      cerr << get_fileline() << ": error: For a "
			              "parallel connection the "
			              "source/destination width must match "
			              "found (" << src_wid << "/" << dst_wid
			           << ")." << endl;
			      des->errors += 1;
			}
		  }

		  connect(src_sig->pin(0), path->pin(idx));
		  idx += 1;
	    }
	    if (debug_elaborate) {
		  cerr << endl;
	    }

	    if (condit_sig)
		  connect(condit_sig->pin(0), path->pin(idx));

	    dst_sig->add_delay_path(path);
      }
}

void PRecRem::elaborate(Design*des, NetScope*scope) const
{
      // At present, no timing checks are supported.
      // Still, in order to get some models working
      // assign the original reference and data signals to
      // the delayed reference and data signals as per
      // 15.5.4 Option behavior

      if (delayed_reference_ != nullptr)
      {
	      if (debug_elaborate) {
		    cerr << get_fileline() << ": PRecRem::elaborate: Assigning "
		       << reference_event_->name
		       << " to " << *delayed_reference_ << endl;
	      }

	      NetNet*sig = des->find_signal(scope, reference_event_->name);

	      if (sig == nullptr) {
		    cerr << get_fileline() << ": error: Cannot find: "
		       << reference_event_->name << endl;
		    des->errors += 1;
		    return;
	      }

	      NetNet*sig_delayed = des->find_signal(scope, *delayed_reference_);

	      if (sig_delayed == nullptr) {
		    cerr << get_fileline() << ": error: Cannot find: "
		       << *delayed_reference_ << endl;
		    des->errors += 1;
		    return;
	      }

	      connect(sig->pin(0), sig_delayed->pin(0));
      }

      if (delayed_data_ != nullptr)
      {
	      if (debug_elaborate) {
		    cerr << get_fileline() << ": PRecRem::elaborate: Assigning "
		       << data_event_->name
		       << " to " << *delayed_data_ << endl;
	      }

	      NetNet*sig = des->find_signal(scope, data_event_->name);

	      if (sig == nullptr) {
		    cerr << get_fileline() << ": error: Cannot find: "
		       << data_event_->name << endl;
		    des->errors += 1;
		    return;
	      }

	      NetNet*sig_delayed = des->find_signal(scope, *delayed_data_);

	      if (sig_delayed == nullptr) {
		    cerr << get_fileline() << ": error: Cannot find: "
		       << *delayed_data_ << endl;
		    des->errors += 1;
		    return;
	      }

	      connect(sig->pin(0), sig_delayed->pin(0));
      }
}

void PSetupHold::elaborate(Design*des, NetScope*scope) const
{
      // At present, no timing checks are supported.
      // Still, in order to get some models working
      // assign the original reference and data signals to
      // the delayed reference and data signals as per
      // 15.5.4 Option behavior

      if (delayed_reference_ != nullptr)
      {
	      if (debug_elaborate) {
		    cerr << get_fileline() << ": PSetupHold::elaborate: Assigning"
		       << reference_event_->name
		       << " to " << *delayed_reference_ << endl;
	      }

	      NetNet*sig = des->find_signal(scope, reference_event_->name);

	      if (sig == nullptr) {
		    cerr << get_fileline() << ": error: Cannot find: "
		       << reference_event_->name << endl;
		    des->errors += 1;
		    return;
	      }

	      NetNet*sig_delayed = des->find_signal(scope, *delayed_reference_);

	      if (sig_delayed == nullptr) {
		    cerr << get_fileline() << ": error: Cannot find: "
		       << *delayed_reference_ << endl;
		    des->errors += 1;
		    return;
	      }

	      connect(sig->pin(0), sig_delayed->pin(0));
      }

      if (delayed_data_ != nullptr)
      {
	      if (debug_elaborate) {
		    cerr << get_fileline() << ": PSetupHold::elaborate: Assigning"
		       << data_event_->name
		       << " to " << *delayed_data_ << endl;
	      }

	      NetNet*sig = des->find_signal(scope, data_event_->name);

	      if (sig == nullptr) {
		    cerr << get_fileline() << ": error: Cannot find: "
		       << data_event_->name << endl;
		    des->errors += 1;
		    return;
	      }

	      NetNet*sig_delayed = des->find_signal(scope, *delayed_data_);

	      if (sig_delayed == nullptr) {
		    cerr << get_fileline() << ": error: Cannot find: "
		       << *delayed_data_ << endl;
		    des->errors += 1;
		    return;
	      }

	      connect(sig->pin(0), sig_delayed->pin(0));
      }
}

static void elaborate_functions(Design*des, NetScope*scope,
				const map<perm_string,PFunction*>&funcs)
{
      typedef map<perm_string,PFunction*>::const_iterator mfunc_it_t;
      for (mfunc_it_t cur = funcs.begin()
		 ; cur != funcs.end() ; ++ cur ) {

	    hname_t use_name ( (*cur).first );
	    NetScope*fscope = scope->child(use_name);
	    ivl_assert(*(*cur).second, fscope);
	    (*cur).second->elaborate(des, fscope);
      }
}

static void elaborate_tasks(Design*des, NetScope*scope,
			    const map<perm_string,PTask*>&tasks)
{
      typedef map<perm_string,PTask*>::const_iterator mtask_it_t;
      for (mtask_it_t cur = tasks.begin()
		 ; cur != tasks.end() ; ++ cur ) {

	    hname_t use_name ( (*cur).first );
	    NetScope*tscope = scope->child(use_name);
	    ivl_assert(*(*cur).second, tscope);
	    (*cur).second->elaborate(des, tscope);
      }
}


// I5 (Phase 62i): elaborate package/module classes in declaration
// (lexical) order rather than alphabetical (std::map).  Class-static
// initializers are emitted as IVL_PR_INITIAL processes via
// `des->add_process` (which prepends).  In vvp's schedule_init_list the
// run order ends up matching the order classes are processed here, so
// patterns like UVM `uvm_register_cb` — where a base-class static
// initializer must run before a derived-class one mutates state on the
// same object — only work when classes here iterate in source order.
static void elaborate_classes_lexical(Design*des, NetScope*scope,
			      const std::vector<PClass*>&classes_lexical)
{
      for (PClass*pcl : classes_lexical) {
	    if (!pcl) continue;
	    netclass_t*use_class = scope->find_class(des, pcl->pscope_name());
	    if (!use_class) continue;
	    use_class->elaborate(des, pcl);

	    if (use_class->test_for_missing_initializers()) {
		  cerr << pcl->get_fileline() << ": error: "
		       << "Const properties of class " << use_class->get_name()
		       << " are missing initialization." << endl;
		  des->errors += 1;
	    }
      }
}

bool PPackage::elaborate(Design*des, NetScope*scope) const
{
      bool result_flag = true;

	// Elaborate function methods, and...
      elaborate_functions(des, scope, funcs);

	// Elaborate task methods.
      elaborate_tasks(des, scope, tasks);

	// Elaborate class definitions in declaration (lexical) order so
	// the static initializers run in declaration order (I5 fix —
	// uvm_register_cb relies on the base typed_callbacks#(T)::m_b_inst
	// being initialized before the derived class's m_register_pair).
      elaborate_classes_lexical(des, scope, classes_lexical);

	// Elaborate the variable initialization statements, making a
	// single initial process out of them.
      result_flag &= elaborate_var_inits_(des, scope);

      return result_flag;
}

/*
 * When a module is instantiated, it creates the scope then uses this
 * method to elaborate the contents of the module.
 */

bool Module::elaborate(Design*des, NetScope*scope) const
{
      bool result_flag = true;

	// Elaborate the elaboration tasks.
      for (const auto et : elab_tasks) {
	    result_flag &= et->elaborate_elab(des, scope);
	      // Only elaborate until a fatal elab task.
	    if (!result_flag) break;
      }

	// If there are no fatal elab tasks then elaborate the rest.
      if (result_flag) {
	      // Elaborate within the generate blocks.
	    for (const auto cur : generate_schemes) cur->elaborate(des, scope);

	      // Elaborate functions.
	    elaborate_functions(des, scope, funcs);

	      // Elaborate the task definitions. This is done before the
	      // behaviors so that task calls may reference these, and after
	      // the signals so that the tasks can reference them.
	    elaborate_tasks(des, scope, tasks);

	      // Elaborate class definitions in declaration (lexical) order
	      // so static initializers fire in declaration order (I5 fix).
	    elaborate_classes_lexical(des, scope, classes_lexical);

	      // Get all the gates of the module and elaborate them by
	      // connecting them to the signals. The gate may be simple or
	      // complex.
	    const list<PGate*>&gl = get_gates();

	    for (const auto gt : gl) gt->elaborate(des, scope);

	      // Elaborate the variable initialization statements, making a
	      // single initial process out of them.
	    result_flag &= elaborate_var_inits_(des, scope);

	      // Elaborate the behaviors, making processes out of them. This
	      // involves scanning the PProcess* list, creating a NetProcTop
	      // for each process.
	    result_flag &= elaborate_behaviors_(des, scope);

	      // Elaborate the specify paths of the module.
	    for (const auto sp : specify_paths) sp->elaborate(des, scope);

	      // Elaborate the timing checks of the module.
	    for (const auto tc : timing_checks) tc->elaborate(des, scope);
      }

      return result_flag;
}

/*
 * Convert a constraint PExpr* to a simple S-expression IR string.
 * Property references become "p:N:W" (index, width).
 * Constants become "c:V".
 * Operators become S-expr form.
 * Returns empty string if the expression is not expressible.
 */
/* Convert a constraint PExpr to our Z3 IR string.
 * cls:          class being constrained (for property lookup).
 * value_slots:  if non-null, non-property caller-scope identifiers are
 *               collected here (returned as "v:N:W" placeholders in IR).
 *               Caller must elaborate and push these at the call site. */
// Phase 81: per-thread loop-variable substitution map used when expanding
// `foreach (B[i]) ...` constraint blocks.  The map is populated by the
// PEForeachConstraint expansion driver below and consulted by the
// PEIdent / array-element branches to materialise concrete literals.
static thread_local std::map<perm_string, long>* g_constraint_loop_subs = nullptr;

string pexpr_to_constraint_ir(const PExpr*expr,
			      const netclass_t*cls,
			      vector<const PExpr*>*value_slots)
{
      using namespace std;

      if (!expr) return "";

      if (const PENumber*num = dynamic_cast<const PENumber*>(expr)) {
	    const verinum&v = num->value();
	    uint64_t val = 0;
	    unsigned bits = v.len();
	    for (unsigned i = 0 ; i < bits && i < 64 ; i += 1)
		  if (v.get(i) == verinum::V1)
			val |= (uint64_t)1 << i;
	    return "c:" + to_string(val);
      }

      if (const PEIdent*id = dynamic_cast<const PEIdent*>(expr)) {
	    perm_string name = id->path().back().name;

	      // Phase 81: foreach loop-variable substitution.  Bare PEIdent
	      // whose name matches an active loop var is materialised as a
	      // constant literal.
	    if (id->path().size() == 1 && id->path().back().index.empty()
		&& g_constraint_loop_subs) {
		  auto it = g_constraint_loop_subs->find(name);
		  if (it != g_constraint_loop_subs->end())
			return "c:" + to_string((uint64_t)it->second);
	    }

	    int idx = cls->property_idx_from_name(name);
	    if (idx >= 0) {
		  property_qualifier_t q = cls->get_prop_qual((size_t)idx);
		  if (!q.test_rand()) return "";
		  ivl_type_t ptype = cls->get_prop_type((size_t)idx);

		    // Phase 81: indexed access on an unpacked-array property —
		    // `B[i]` or `B[const]`.  Emit `(extract p:idx:flat hi lo)`
		    // so the element's bit range inside the flat property BV
		    // is constrained.  Single-dim arrays only.
		  const netuarray_t *ua =
			dynamic_cast<const netuarray_t*>(ptype);
		  if (ua && ua->static_dimensions().size() == 1
		      && id->path().back().index.size() == 1) {
			const index_component_t&ic = id->path().back().index.back();
			if (ic.sel == index_component_t::SEL_BIT && ic.msb) {
			      long ival = LONG_MIN;
			      if (const PENumber*pn =
					dynamic_cast<const PENumber*>(ic.msb)) {
				    ival = pn->value().as_long();
			      } else if (const PEIdent*pi =
					dynamic_cast<const PEIdent*>(ic.msb)) {
				    if (pi->path().size() == 1
					&& g_constraint_loop_subs) {
					  perm_string lv =
						pi->path().back().name;
					  auto it =
						g_constraint_loop_subs->find(lv);
					  if (it != g_constraint_loop_subs->end())
						ival = it->second;
				    }
			      }
			      if (ival != LONG_MIN) {
				    const netrange_t &dim =
					  ua->static_dimensions().front();
				    if (dim.defined()) {
					  long lsb = dim.get_lsb();
					  long msb = dim.get_msb();
					  long lo_b = lsb < msb ? lsb : msb;
					  long elem_idx = ival - lo_b;
					  unsigned elem_wid = 32;
					  if (ivl_type_t et = ua->element_type())
						elem_wid =
						      et->packed_width() > 0
						      ? (unsigned)et->packed_width()
						      : 32;
					  unsigned n = (unsigned)dim.width();
					  if (elem_idx >= 0
					      && (unsigned)elem_idx < n) {
						unsigned flat = n * elem_wid;
						unsigned hi =
						      ((unsigned)elem_idx + 1)
						      * elem_wid - 1;
						unsigned lo =
						      (unsigned)elem_idx
						      * elem_wid;
						return "(extract p:"
						      + to_string(idx)
						      + ":" + to_string(flat)
						      + " " + to_string(hi)
						      + " " + to_string(lo)
						      + ")";
					  }
				    }
			      }
			}
		  }

		  unsigned wid = 0;
		  if (ptype) {
			const netvector_t*nvec = dynamic_cast<const netvector_t*>(ptype);
			if (nvec) wid = nvec->packed_width();
			    // Phase 81 follow-up: unpacked-array property referenced
			    // as a bare PEIdent (no element index) must declare its
			    // flat width (N × elem_wid).  The Z3 builder's
			    // `get_prop_var` dedupes by idx and the first emission's
			    // width wins, so mixing this with a `.sum()` fold (which
			    // also references `p:idx:flat`) needs both sites to agree.
			    // Without the consistency, the second emission's value
			    // would be silently truncated to the first one's width.
			else if (const netuarray_t*ua =
					dynamic_cast<const netuarray_t*>(ptype)) {
			      if (ua->static_dimensions().size() == 1) {
				    const netrange_t &dim =
					  ua->static_dimensions().front();
				    if (dim.defined()) {
					  unsigned elem_wid = 32;
					  if (ivl_type_t et = ua->element_type())
						elem_wid =
						      et->packed_width() > 0
						      ? (unsigned)et->packed_width()
						      : 32;
					  unsigned n = (unsigned)dim.width();
					  wid = n * elem_wid;
				    }
			      }
			}
		  }
		  if (wid == 0) wid = 32;
		  return "p:" + to_string(idx) + ":" + to_string(wid);
	    }
	    // Non-class-property identifier: treat as caller-scope runtime value.
	    if (value_slots) {
		  unsigned slot = (unsigned)value_slots->size();
		  value_slots->push_back(expr);
		  return "v:" + to_string(slot) + ":32";
	    }
	    return "";
      }

	// Phase 81: foreach (B[i]) <body> — expand the loop over B's element
	// count and emit the body N times with the loop variable bound to
	// each literal index.  Multiple bodies in the constraint_set are
	// space-separated (top-level IR conjunction).
      if (const PEForeachConstraint*fc =
		dynamic_cast<const PEForeachConstraint*>(expr)) {
	    int arr_idx = cls->property_idx_from_name(fc->array_name());
	    if (arr_idx < 0) return "";
	    ivl_type_t arr_type = cls->get_prop_type((size_t)arr_idx);
	    const netuarray_t *ua =
		  dynamic_cast<const netuarray_t*>(arr_type);
	    if (!ua || ua->static_dimensions().size() != 1) return "";
	    const netrange_t &dim = ua->static_dimensions().front();
	    if (!dim.defined()) return "";
	    long lsb = dim.get_lsb();
	    long msb = dim.get_msb();
	    long lo = lsb < msb ? lsb : msb;
	    long hi = lsb < msb ? msb : lsb;
	    if (fc->loop_vars().size() != 1) return "";
	    perm_string lv = fc->loop_vars().front();
	    std::map<perm_string,long> *prev = g_constraint_loop_subs;
	    std::map<perm_string,long> local;
	    if (prev) local = *prev;
	    string out;
	    for (long i = lo; i <= hi; ++i) {
		  local[lv] = i;
		  g_constraint_loop_subs = &local;
		  for (const PExpr *bexp : *fc->body()) {
			string s = pexpr_to_constraint_ir(bexp, cls, value_slots);
			if (s.empty()) continue;
			if (!out.empty()) out += " ";
			out += s;
		  }
	    }
	    g_constraint_loop_subs = prev;
	    return out;
      }

	// Phase 81: array reduction `arr.sum()` on a fixed-size unpacked
	// rand array property — fold into a bitvector sum of per-element
	// extract slices.  Z3 backend gains an `extract` operator to
	// materialise the slices.  Constraints like `B.sum() == 5` thus
	// become Z3 `(add (extract bv 31 0) (extract bv 63 32) ...)` and
	// constrain the actual values of B[0..N-1] inside the flat BV.
      if (const PECallFunction*call = dynamic_cast<const PECallFunction*>(expr)) {
	    const pform_name_t&pn = call->get_path_().name;
	    if (call->get_parms_().empty()
		&& pn.size() == 2
		&& pn.back().name == perm_string::literal("sum")) {
		  perm_string arr_name = pn.front().name;
		  int idx = cls->property_idx_from_name(arr_name);
		  if (idx >= 0) {
			property_qualifier_t q =
			      cls->get_prop_qual((size_t)idx);
			if (!q.test_rand()) return "";
			ivl_type_t ptype =
			      cls->get_prop_type((size_t)idx);
			const netuarray_t *ua =
			      dynamic_cast<const netuarray_t*>(ptype);
			if (ua && ua->static_dimensions().size() == 1) {
			      const netrange_t &dim =
				    ua->static_dimensions().front();
			      if (dim.defined()) {
				    unsigned elem_wid = 32;
				    if (ivl_type_t et = ua->element_type())
					  elem_wid = et->packed_width() > 0
						? (unsigned)et->packed_width()
						: 32;
				    unsigned n = (unsigned)dim.width();
				    unsigned flat_wid = n * elem_wid;
				    string p_tok = "p:" + to_string(idx) + ":"
					    + to_string(flat_wid);
				    string acc = p_tok;
				    // Build nested (add (extract …) (add (extract …) …))
				    // since the IR's add is binary.
				    string fold;
				    for (unsigned i = 0 ; i < n ; i += 1) {
					  unsigned hi = (i + 1) * elem_wid - 1;
					  unsigned lo = i * elem_wid;
					  string ex = "(extract " + p_tok
						+ " " + to_string(hi)
						+ " " + to_string(lo) + ")";
					  if (fold.empty()) fold = ex;
					  else fold = "(add " + fold
						+ " " + ex + ")";
				    }
				    return fold;
			      }
			}
		  }
	    }
      }

      // I4 (Phase 62c): soft constraint wrapper.  Emit `(soft <expr>)`
      // so the Z3 backend applies the inner expression via
      // Z3_optimize_assert_soft (default weight 1) instead of a hard
      // conjunct.
      if (const PESoft*sf = dynamic_cast<const PESoft*>(expr)) {
	    string s = pexpr_to_constraint_ir(sf->get_inner(), cls, value_slots);
	    if (s.empty() || s[0] == '?') return "";
	    return "(soft " + s + ")";
      }

      if (const PEInside*ins = dynamic_cast<const PEInside*>(expr)) {
	    string s = pexpr_to_constraint_ir(ins->get_expr(), cls, value_slots);
	    if (s.empty() || s[0] == '?') return "";
	    // C7 (Phase 62b): dist form preserves per-branch weights as
	    // `(dist <expr> (b W <range>) ...)` where W is the literal
	    // weight integer.  Plain inside emits the existing form.
	    bool is_dist = ins->is_dist();

	    // G18: if subject is an enum-typed class property, resolve enum
	    // name identifiers in the range list to their numeric values.
	    const netenum_t* subj_enum = nullptr;
	    if (const PEIdent*sid = dynamic_cast<const PEIdent*>(ins->get_expr())) {
		  perm_string sname = sid->path().back().name;
		  int sidx = cls->property_idx_from_name(sname);
		  if (sidx >= 0) {
			ivl_type_t stype = cls->get_prop_type((size_t)sidx);
			subj_enum = dynamic_cast<const netenum_t*>(stype);
		  }
	    }

	    string result = is_dist ? "(dist " : "(inside ";
	    result += s;
	    for (auto& r : ins->get_ranges()) {
		  string range_ir;
		  if (r.is_range) {
			string lo = pexpr_to_constraint_ir(r.lo, cls, value_slots);
			string hi = pexpr_to_constraint_ir(r.hi, cls, value_slots);
			if (lo.empty() || hi.empty()) continue;
			range_ir = "[" + lo + "," + hi + "]";
		  } else {
			string v = pexpr_to_constraint_ir(r.hi, cls, value_slots);
			// G18: if v is empty and subject is enum-typed, try to
			// resolve the identifier as an enum literal name.
			if (v.empty() && subj_enum) {
			      if (const PEIdent*eid = dynamic_cast<const PEIdent*>(r.hi)) {
				    perm_string ename = eid->path().back().name;
				    netenum_t::iterator it = subj_enum->find_name(ename);
				    if (it != subj_enum->end_name())
					  v = "c:" + std::to_string(it->second.as_unsigned());
			      }
			}
			if (v.empty()) continue;
			range_ir = v;
		  }
		  if (is_dist) {
			// Default weight 1 for unweighted branches in a
			// dist (rare, but legal in mixed forms).
			string w = "1";
			if (r.weight) {
			      string we = pexpr_to_constraint_ir(r.weight, cls, value_slots);
			      if (!we.empty()) w = we;
			}
			result += " (b " + w + " " + range_ir + ")";
		  } else {
			result += " " + range_ir;
		  }
	    }
	    result += ")";
	    return result;
      }

      if (const PEBinary*bin = dynamic_cast<const PEBinary*>(expr)) {
	    string left = pexpr_to_constraint_ir(bin->get_left(), cls, value_slots);
	    string right = pexpr_to_constraint_ir(bin->get_right(), cls, value_slots);
	    if (left.empty() || right.empty()) return "";
	    string op;
	    switch (bin->get_op()) {
		case '<': op = "lt";  break;
		case '>': op = "gt";  break;
		case 'L': op = "le";  break;  // K_LE
		case 'G': op = "ge";  break;  // K_GE
		case 'e': op = "eq";  break;  // K_EQ (==)
		case 'n': op = "ne";  break;  // K_NE (!=)
		case 'a': op = "and"; break;  // && (K_LAND)
		case 'o': op = "or";  break;  // || (K_LOR)
		case '+': op = "add"; break;
		case '-': op = "sub"; break;
		case '*': op = "mul"; break;
		case 'q': op = "implies"; break;  // -> (K_TRIGGER, implication)
		default:  return "";
	    }
	    return "(" + op + " " + left + " " + right + ")";
      }

      if (const PEUnary*un = dynamic_cast<const PEUnary*>(expr)) {
	    string sub = pexpr_to_constraint_ir(un->get_expr(), cls, value_slots);
	    if (sub.empty()) return "";
	    if (un->get_op() == '!') return "(not " + sub + ")";
	    return "";
      }

      // G17 (Phase 66): if-block constraint → (implies cond then) [&& (implies !cond else)]
      if (const PEConstraintIf*cif = dynamic_cast<const PEConstraintIf*>(expr)) {
	    string cond_s = pexpr_to_constraint_ir(cif->get_cond(), cls, value_slots);
	    if (cond_s.empty()) return "";

	    // Build AND of then-branch items: each item implies cond
	    string then_ir;
	    if (cif->get_then()) {
		  for (auto* item : *cif->get_then()) {
			if (!item) continue;
			string s = pexpr_to_constraint_ir(item, cls, value_slots);
			if (s.empty()) continue;
			then_ir = then_ir.empty() ? s
			        : "(and " + then_ir + " " + s + ")";
		  }
	    }
	    string result = then_ir.empty() ? ""
	                  : "(implies " + cond_s + " " + then_ir + ")";

	    // Build AND of else-branch items: each item implies !cond
	    if (cif->get_else() && !cif->get_else()->empty()) {
		  string else_ir;
		  for (auto* item : *cif->get_else()) {
			if (!item) continue;
			string s = pexpr_to_constraint_ir(item, cls, value_slots);
			if (s.empty()) continue;
			else_ir = else_ir.empty() ? s
			        : "(and " + else_ir + " " + s + ")";
		  }
		  if (!else_ir.empty()) {
			string not_cond = "(not " + cond_s + ")";
			string else_clause = "(implies " + not_cond + " " + else_ir + ")";
			result = result.empty() ? else_clause
			       : "(and " + result + " " + else_clause + ")";
		  }
	    }
	    return result;
      }

      return "";
}

/*
 * Elaborating a netclass_t means elaborating the PFunction and PTask
 * objects that it contains. The scopes and signals have already been
 * elaborated in the class of the netclass_t scope, so we can get the
 * child scope for each definition and use that for the context of the
 * function.
 */
void netclass_t::elaborate(Design*des, PClass*pclass)
{
      if (body_elaborated_ || body_elaborating_)
	    return;
      body_elaborating_ = true;
      elaborate_sig(des, pclass);
      const bool lazy_specialized_body =
	    should_lazy_specialized_class_body_(this);

	      if (! pclass->type->initialize_static.empty()) {
		    const std::vector<Statement*>&stmt_list = pclass->type->initialize_static;
		    NetBlock*stmt = new NetBlock(NetBlock::SEQU, 0);
		    for (size_t idx = 0 ; idx < stmt_list.size() ; idx += 1) {
			  NetProc*tmp = stmt_list[idx]->elaborate(des, class_scope_);
			  if (tmp == 0) continue;
			  stmt->append(tmp);
		    }
		    NetProcTop*top = new NetProcTop(class_scope_, IVL_PR_INITIAL, stmt);
		    top->set_line(*pclass);
		    if (gn_system_verilog()) {
			  top->attribute(perm_string::literal("_ivl_schedule_init"),
					 verinum(1));
		    }
		    // I5 (Phase 62m): for parameterized-class specializations,
		    // append at the TAIL so the static init runs FIRST in vvp's
		    // schedule_init list (after two reversals via emit/dll).
		    // Without this, code patterns like UVM `uvm_register_cb`
		    // see the spec's `static = 0` reset wipe state set by a
		    // user-class static initializer that called into the spec.
		    if (this->specialized_instance())
			  des->add_process_at_tail(top);
		    else
			  des->add_process(top);
	      }

	      // Elaborate constraint blocks: convert PExpr* to IR strings.
	      // Names are pre-registered (empty IR) in elaborate_sig so the
	      // setter / getter paths can resolve `obj.<cname>.constraint_mode`
	      // by name even when the IR translation drops to "".  Here we
	      // either populate the IR for an already-registered name, or
	      // register a fresh entry if it wasn't pre-registered (defensive).
	      for (auto& cit : pclass->type->constraints) {
		    string ir;
		    for (PExpr*item : cit.second) {
			  if (!item) continue;
			  string s = pexpr_to_constraint_ir(item, this, nullptr);
			  if (!s.empty()) {
				if (!ir.empty()) ir += " ";
				ir += s;
			  }
		    }
		    if (getenv("IVL_CIR_TRACE"))
			  cerr << "[CIR] class=" << get_name()
			       << " constraint=" << cit.first
			       << " ir=" << ir << endl;
		    add_constraint_ir(string(cit.first), ir);
	      }

	      // Phase 49: synthesize an `inside` constraint for every rand
	      // (or randc) property whose type is an enum. Without this,
	      // %randomize seeds the property with raw rand() bits and the
	      // resulting value almost never lands on a valid enum label
	      // (causing UVM_FATAL "Unsupported <enum>" downstream).
	      for (size_t pid = 0; pid < get_properties(); ++pid) {
		    property_qualifier_t qual = get_prop_qual(pid);
		    if (!qual.test_rand() && !qual.test_randc())
			  continue;
		    ivl_type_t ptype = get_prop_type(pid);
		    const netenum_t*etype = dynamic_cast<const netenum_t*>(ptype);
		    if (!etype || etype->size() == 0)
			  continue;
		    unsigned wid = (unsigned)etype->packed_width();
		    if (wid == 0) wid = 32;
		    std::ostringstream ir;
		    ir << "(inside p:" << pid << ":" << wid;
		    for (size_t v = 0; v < etype->size(); ++v) {
			  uint64_t val = etype->value_at(v).as_unsigned();
			  ir << " c:" << val;
		    }
		    ir << ")";
		    std::ostringstream nm;
		    nm << "_enum_" << get_prop_name(pid);
		    add_constraint_ir(nm.str(), ir.str());
	      }

	      // Elaborate covergroup declarations: synthesize a hidden
	      // class type for each covergroup with one int property per
	      // bin (holding the hit count).  The covergroup property on
	      // the parent class is set to this synthesized type so that
	      // the normal %new/cobj mechanism can create instances.
	      for (auto* cgdef : pclass->type->covergroups) {
		    if (!cgdef) continue;

		    // Build synthesized class name
		    string cg_cname = string("__covgrp_")
				      + string(name_.str())
				      + "_" + string(cgdef->name.str()) + "_t";
		    perm_string cg_class_pname = lex_strings.make(cg_cname.c_str());

		    // Reuse the CG class stub if elaborate_sig() already created it,
		    // otherwise create a fresh one (no bins yet).
		    netclass_t* cg_class = nullptr;
		    {
			  int existing_idx = property_idx_from_name(cgdef->name);
			  if (existing_idx >= 0)
				cg_class = const_cast<netclass_t*>(
					dynamic_cast<const netclass_t*>(get_prop_type(existing_idx)));
		    }
		    if (!cg_class) {
			  cg_class = new netclass_t(cg_class_pname, nullptr);
			  cg_class->set_scope_ready(true);
			  cg_class->set_body_elaborated(true);
			  cg_class->set_is_covergroup(true);
		    }

		    unsigned prop_idx = 0;
		    unsigned cp_idx  = 0;
		    for (auto& cp : cgdef->coverpoints) {
			  // Resolve coverpoint expression to a parent property index.
			  // For now, handle simple identifiers only (most common case).
			  int parent_prop = -1;
			  if (const PEIdent* pe = dynamic_cast<const PEIdent*>(cp.expr)) {
				perm_string cp_var_name = peek_head_name(pe->path());
				parent_prop = property_idx_from_name(cp_var_name);
			  }
			  cg_class->add_covgrp_cp_parent_prop(parent_prop);

			  for (auto& bin : cp.bins) {
				// I1 (Phase 62o): ignore_bins are excluded
				// from coverage entirely — drop them now so
				// they don't affect prop_idx layout or the
				// runtime sample/coverage logic.
				if (bin.kind == class_type_t::pform_cov_bins_t::BIN_IGNORE)
				      continue;

				unsigned bkind = 0;
				if (bin.kind == class_type_t::pform_cov_bins_t::BIN_ILLEGAL)
				      bkind = 2;

				// Add one int32 property for this bin's hit count
				string bpname = string("__bin_")
						+ string(cp.label)
						+ "_" + string(bin.name);
				perm_string bpp = lex_strings.make(bpname.c_str());
				cg_class->set_property(bpp,
						       property_qualifier_t::make_none(),
						       &netvector_t::atom2s32);

				// Collect bin ranges and store as metadata
				for (auto& range : bin.ranges) {
				      if (!range.first || !range.second) continue;
				      // Evaluate lo and hi as compile-time constants
				      NetExpr* lo_e = elab_and_eval(des, class_scope_,
								    range.first, -1,
								    false, false);
				      NetExpr* hi_e = elab_and_eval(des, class_scope_,
								    range.second, -1,
								    false, false);
				      NetEConst* lo_c = dynamic_cast<NetEConst*>(lo_e);
				      NetEConst* hi_c = dynamic_cast<NetEConst*>(hi_e);
				      if (lo_c && hi_c) {
					    uint64_t lo = lo_c->value().as_ulong64();
					    uint64_t hi = hi_c->value().as_ulong64();
					    cg_class->add_covgrp_bin(cp_idx, prop_idx, lo, hi, bkind);
				      }
				      delete lo_e;
				      delete hi_e;
				}
				prop_idx++;
			  }
			  cp_idx++;
		    }
		    cg_class->set_covgrp_ncoverpoints(cp_idx);

		    // I1 (Phase 62l): generate cartesian-product bins for
		    // each cross declaration.  Resolve each named
		    // contributing coverpoint to its index; for each
		    // combination of bins from each contributing cp, emit
		    // one int32 counter property.  Bin metadata
		    // (cpi, prop_idx, lo, hi) is added once per range.
		    for (auto& cross : cgdef->crosses) {
			  std::vector<unsigned> cp_indexes;
			  cp_indexes.reserve(cross.cp_labels.size());
			  bool resolved = true;
			  for (perm_string cp_label : cross.cp_labels) {
				int found = -1;
				for (size_t i = 0;
				     i < cgdef->coverpoints.size(); i++) {
				      if (cgdef->coverpoints[i].label
					  == cp_label) {
					    found = static_cast<int>(i);
					    break;
				      }
				}
				if (found < 0) { resolved = false; break; }
				cp_indexes.push_back(found);
			  }
			  if (!resolved) continue;
			  if (cp_indexes.empty()) continue;

			  std::vector<unsigned> idx(cp_indexes.size(), 0);
			  bool done = false;
			  while (!done) {
				std::string bpname = std::string("__xbin_");
				bpname += cross.label.nil()
					    ? std::string("auto")
					    : std::string(cross.label.str());
				for (size_t k = 0; k < idx.size(); k++) {
				      bpname += "_";
				      bpname += std::to_string(idx[k]);
				}
				perm_string bpp = lex_strings.make(bpname.c_str());
				cg_class->set_property(bpp,
				      property_qualifier_t::make_none(),
				      &netvector_t::atom2s32);

				for (size_t k = 0; k < idx.size(); k++) {
				      unsigned cpi = cp_indexes[k];
				      auto& cp_x = cgdef->coverpoints[cpi];
				      if (idx[k] >= cp_x.bins.size()) break;
				      auto& xbin = cp_x.bins[idx[k]];
				      for (auto& range : xbin.ranges) {
					    if (!range.first ||
						!range.second) continue;
					    NetExpr* lo_e =
					      elab_and_eval(des, class_scope_,
							    range.first, -1,
							    false, false);
					    NetExpr* hi_e =
					      elab_and_eval(des, class_scope_,
							    range.second, -1,
							    false, false);
					    NetEConst* lo_c =
					      dynamic_cast<NetEConst*>(lo_e);
					    NetEConst* hi_c =
					      dynamic_cast<NetEConst*>(hi_e);
					    if (lo_c && hi_c) {
						  uint64_t lo =
						    lo_c->value().as_ulong64();
						  uint64_t hi =
						    hi_c->value().as_ulong64();
						  cg_class->add_covgrp_bin(
						    cpi, prop_idx, lo, hi);
					    }
					    delete lo_e;
					    delete hi_e;
				      }
				}
				prop_idx++;

				size_t k = 0;
				while (k < idx.size()) {
				      auto& cp_x =
					cgdef->coverpoints[cp_indexes[k]];
				      idx[k]++;
				      if (idx[k] < cp_x.bins.size()) break;
				      idx[k] = 0;
				      k++;
				}
				if (k == idx.size()) done = true;
			  }
		    }

		    // Replace the covergroup property declaration on the
		    // parent class with a handle to the synthesized class.
		    set_property(cgdef->name,
				 property_qualifier_t::make_none(),
				 cg_class);
	      }

	      for (map<perm_string,PFunction*>::iterator cur = pclass->funcs.begin()
		 ; cur != pclass->funcs.end() ; ++ cur) {
		    if (lazy_specialized_body &&
			!should_eagerly_elaborate_class_method_(cur->first))
			  continue;
		    // Dynamic dispatch needs emitted bodies for override targets even
		    // when they have no direct static call sites. Skip only bodyless
		    // prototypes unless they are part of the explicit eager set.
		    if (!should_eagerly_elaborate_class_method_(cur->first)
			&& cur->second->get_statement() == 0)
			  continue;
		    if (debug_elaborate) {
			  cerr << cur->second->get_fileline() << ": netclass_t::elaborate: "
			       << "Elaborate class " << scope_path(class_scope_)
		       << " function method " << cur->first << endl;
	    }

	    NetScope*scope = class_scope_->child( hname_t(cur->first) );
	    ivl_assert(*cur->second, scope);
	    if (const char*env = getenv("IVL_CTOR_BLEND_TRACE")) {
		  if (*env && strcmp(env, "0") != 0
		      && cur->first == perm_string::literal("new")
		      && pclass->type->name == perm_string::literal("uvm_default_report_server")) {
			cerr << cur->second->get_fileline()
			     << ": debug: ctor-elab class=uvm_default_report_server"
			     << " func_ptr=" << (const void*)cur->second
			     << " scope_func_ptr=" << (const void*)scope->func_pform()
			     << " stmt_func=" << (cur->second->get_statement() ? 1 : 0)
			     << " stmt_scope=" << (scope->func_pform() && scope->func_pform()->get_statement() ? 1 : 0)
			     << endl;
		  }
	    }
	    cur->second->elaborate(des, scope);
      }

	      for (map<perm_string,PTask*>::iterator cur = pclass->tasks.begin()
		 ; cur != pclass->tasks.end() ; ++ cur) {
		    if (lazy_specialized_body &&
			!should_eagerly_elaborate_class_method_(cur->first))
			  continue;
		    if (!should_eagerly_elaborate_class_method_(cur->first)
			&& cur->second->get_statement() == 0)
			  continue;
	    if (debug_elaborate) {
		  cerr << cur->second->get_fileline() << ": netclass_t::elaborate: "
		       << "Elaborate class " << scope_path(class_scope_)
		       << " task method " << cur->first << endl;
	    }

	    NetScope*scope = class_scope_->child( hname_t(cur->first) );
	    ivl_assert(*cur->second, scope);
	    cur->second->elaborate(des, scope);
      }

      body_elaborating_ = false;
      body_elaborated_ = true;
}

bool PGenerate::elaborate(Design*des, NetScope*container) const
{
      if (directly_nested)
	    return elaborate_direct_(des, container);

      bool flag = true;

      if (debug_elaborate) {
	    cerr << get_fileline() << ": PGenerate::elaborate: "
		  "generate " << scheme_type
		 << " elaborating in scope " << scope_path(container)
		 << "." << endl;
	    cerr << get_fileline() << ": PGenerate::elaborate: "
		  "generate scope_name=" << scope_name
		 << ", id_number=" << id_number << endl;
      }

	// Handle the special case that this is a CASE scheme. In this
	// case the PGenerate itself does not have the generated
	// item. Look instead for the case ITEM that has a scope
	// generated for it.
      if (scheme_type == PGenerate::GS_CASE) {

	    typedef list<PGenerate*>::const_iterator generate_it_t;
	    for (generate_it_t cur = generate_schemes.begin()
		       ; cur != generate_schemes.end() ; ++ cur ) {
		  PGenerate*item = *cur;
		  if (item->directly_nested || !item->scope_list_.empty()) {
			flag &= item->elaborate(des, container);
		  }
	    }
	    return flag;
      }

      typedef list<NetScope*>::const_iterator scope_list_it_t;
      for (scope_list_it_t cur = scope_list_.begin()
		 ; cur != scope_list_.end() ; ++ cur ) {

	    NetScope*scope = *cur;
	      // Check that this scope is one that is contained in the
	      // container that the caller passed in.
	    if (scope->parent() != container)
		  continue;

	      // If this was an unnamed generate block, replace its
	      // temporary name with a name generated using the naming
	      // scheme defined in the Verilog-2005 standard.
	    const char*name = scope_name.str();
	    if (name[0] == '$') {

		  if (!scope->auto_name("genblk", '0', name + 4)) {
			cerr << get_fileline() << ": warning: Couldn't build"
			     << " unique name for unnamed generate block"
			     << " - using internal name " << name << endl;
		  }
	    }
	    if (debug_elaborate)
		  cerr << get_fileline() << ": debug: Elaborate in "
		       << "scope " << scope_path(scope) << endl;

	    flag = elaborate_(des, scope) && flag;
      }

      return flag;
}

bool PGenerate::elaborate_direct_(Design*des, NetScope*container) const
{
      bool flag = true;

      if (debug_elaborate) {
	    cerr << get_fileline() << ": debug: "
		 << "Direct nesting elaborate in scope "
		 << scope_path(container)
		 << ", scheme_type=" << scheme_type << endl;
      }

	// Elaborate for a direct nested generated scheme knows
	// that there are only sub_schemes to be elaborated.  There
	// should be exactly 1 active generate scheme, search for it
	// using this loop.
      typedef list<PGenerate*>::const_iterator generate_it_t;
      for (generate_it_t cur = generate_schemes.begin()
		 ; cur != generate_schemes.end() ; ++ cur ) {
	    PGenerate*item = *cur;
	    if (debug_elaborate) {
		  cerr << get_fileline() << ": PGenerate::elaborate_direct_: "
		       << "item->scope_name=" << item->scope_name
		       << ", item->scheme_type=" << item->scheme_type
		       << ", item->directly_nested=" << item->directly_nested
		       << ", item->scope_list_.size()=" << item->scope_list_.size()
		       << "." << endl;
	    }

	      // Special case: If this is a case generate scheme, then
	      // the PGenerate object (item) does not actually
	      // contain anything. Instead scan the case items, which
	      // are listed as sub-schemes of the item.
	    if (item->scheme_type == PGenerate::GS_CASE) {
		  for (generate_it_t icur = item->generate_schemes.begin()
			     ; icur != item->generate_schemes.end() ; ++ icur ) {
			PGenerate*case_item = *icur;
			if (case_item->directly_nested || !case_item->scope_list_.empty()) {
			      flag &= case_item->elaborate(des, container);
			}
		  }
	    } else {
		  if (item->directly_nested || !item->scope_list_.empty()) {
			  // Found the item, and it is direct nested.
			flag &= item->elaborate(des, container);
		  }
	    }
      }
      return flag;
}

bool PGenerate::elaborate_(Design*des, NetScope*scope) const
{
      bool result_flag = true;

	// Elaborate the elaboration tasks.
      for (const auto et : elab_tasks) {
	    result_flag &= et->elaborate_elab(des, scope);
	      // Only elaborate until a fatal elab task.
	    if (!result_flag) break;
      }

	// If there are no fatal elab tasks then elaborate the rest.
      if (result_flag) {
	    elaborate_functions(des, scope, funcs);
	    elaborate_tasks(des, scope, tasks);

	    for (const auto gt : gates) gt->elaborate(des, scope);

	    result_flag &= elaborate_var_inits_(des, scope);

	    for (const auto bh : behaviors) bh->elaborate(des, scope);

	    for (const auto gs : generate_schemes) gs->elaborate(des, scope);
      }

      return result_flag;
}

bool PScope::elaborate_behaviors_(Design*des, NetScope*scope) const
{
      bool result_flag = true;

	// Elaborate the behaviors, making processes out of them. This
	// involves scanning the PProcess* list, creating a NetProcTop
	// for each process.
      for (list<PProcess*>::const_iterator st = behaviors.begin()
		 ; st != behaviors.end() ; ++ st ) {

	    result_flag &= (*st)->elaborate(des, scope);
      }

      for (list<AProcess*>::const_iterator st = analog_behaviors.begin()
		 ; st != analog_behaviors.end() ; ++ st ) {

	    result_flag &= (*st)->elaborate(des, scope);
      }

      return result_flag;
}

bool LexicalScope::elaborate_var_inits_(Design*des, NetScope*scope) const
{
      if (var_inits.size() == 0)
	    return true;

      NetProc*proc = 0;
      if (var_inits.size() == 1) {
	    proc = var_inits[0]->elaborate(des, scope);
      } else {
	    NetBlock*blk = new NetBlock(NetBlock::SEQU, 0);
	    bool flag = true;
	    for (unsigned idx = 0; idx < var_inits.size(); idx += 1) {
		  NetProc*tmp = var_inits[idx]->elaborate(des, scope);
		  if (tmp)
			blk->append(tmp);
		  else
			flag = false;
	    }
	    if (flag) proc = blk;
      }
      if (proc == 0)
	    return false;

      NetProcTop*top = new NetProcTop(scope, IVL_PR_INITIAL, proc);
      if (const LineInfo*li = dynamic_cast<const LineInfo*>(this)) {
	    top->set_line(*li);
      }
      if (gn_system_verilog()) {
	    top->attribute(perm_string::literal("_ivl_schedule_init"),
			   verinum(1));
      }
      des->add_process(top);

      scope->set_var_init(proc);

      return true;
}

class elaborate_package_t : public elaborator_work_item_t {
    public:
      elaborate_package_t(Design*d, NetScope*scope, PPackage*p)
      : elaborator_work_item_t(d), scope_(scope), package_(p)
      { }

      ~elaborate_package_t() override { }

      virtual void elaborate_runrun() override
      {
	    if (! package_->elaborate_scope(des, scope_))
		  des->errors += 1;
      }

    private:
      NetScope*scope_;
      PPackage*package_;
};

class elaborate_root_scope_t : public elaborator_work_item_t {
    public:
      elaborate_root_scope_t(Design*des__, NetScope*scope, Module*rmod)
      : elaborator_work_item_t(des__), scope_(scope), rmod_(rmod)
      { }

      ~elaborate_root_scope_t() override { }

      virtual void elaborate_runrun() override
      {
	    Module::replace_t root_repl;
	    for (list<Module::named_expr_t>::iterator cur = Module::user_defparms.begin()
		       ; cur != Module::user_defparms.end() ; ++ cur ) {

		  pform_name_t tmp_name = cur->first;
		  if (peek_head_name(tmp_name) != scope_->basename())
			continue;

		  tmp_name.pop_front();
		  if (tmp_name.size() != 1)
			continue;

		  root_repl[peek_head_name(tmp_name)] = cur->second;
	    }

	    if (! rmod_->elaborate_scope(des, scope_, root_repl))
		  des->errors += 1;
      }

    private:
      NetScope*scope_;
      Module*rmod_;
};

class top_defparams : public elaborator_work_item_t {
    public:
      explicit top_defparams(Design*des__)
      : elaborator_work_item_t(des__)
      { }

      ~top_defparams() override { }

      virtual void elaborate_runrun() override
      {
	    if (debug_scopes) {
		  cerr << "debug: top_defparams::elaborate_runrun()" << endl;
	    }
	      // This method recurses through the scopes, looking for
	      // defparam assignments to apply to the parameters in the
	      // various scopes. This needs to be done after all the scopes
	      // and basic parameters are taken care of because the defparam
	      // can assign to a parameter declared *after* it.
	    des->run_defparams();

	      // At this point, all parameter overrides are done. Scan the
	      // scopes and evaluate the parameters all the way down to
	      // constants.
	    des->evaluate_parameters();

	    if (debug_scopes) {
		  cerr << "debug: top_defparams::elaborate_runrun() done" << endl;
	    }
      }
};

class later_defparams : public elaborator_work_item_t {
    public:
      explicit later_defparams(Design*des__)
      : elaborator_work_item_t(des__)
      { }

      ~later_defparams() override { }

      virtual void elaborate_runrun() override
      {
	    if (debug_scopes) {
		  cerr << "debug: later_defparams::elaborate_runrun()" << endl;
	    }

	    list<NetScope*>tmp_list;
	    for (set<NetScope*>::iterator cur = des->defparams_later.begin()
		       ; cur != des->defparams_later.end() ; ++ cur )
		  tmp_list.push_back(*cur);

	    des->defparams_later.clear();

	    while (! tmp_list.empty()) {
		  NetScope*cur = tmp_list.front();
		  tmp_list.pop_front();
		  cur->run_defparams_later(des);
	    }

	      // The overridden parameters will be evaluated later in
	      // a top_defparams work item.

	    if (debug_scopes) {
		  cerr << "debuf: later_defparams::elaborate_runrun() done" << endl;
	    }
      }
};

static ostream& operator<< (ostream&o, ivl_process_type_t t)
{
      switch (t) {
	case IVL_PR_ALWAYS:
	    o << "always";
	    break;
	case IVL_PR_ALWAYS_COMB:
	    o << "always_comb";
	    break;
	case IVL_PR_ALWAYS_FF:
	    o << "always_ff";
	    break;
	case IVL_PR_ALWAYS_LATCH:
	    o << "always_latch";
	    break;
	case IVL_PR_INITIAL:
	    o << "initial";
	    break;
	case IVL_PR_FINAL:
	    o << "final";
	    break;
      }
      return o;
}

bool Design::check_proc_delay() const
{
      bool result = false;

      for (const NetProcTop*pr = procs_ ;  pr ;  pr = pr->next_) {
	      /* If this is an always process and we have no or zero delay then
	       * a runtime infinite loop will happen. If we possibly have some
	       * delay then print a warning that an infinite loop is possible.
	       */
	    if (pr->type() == IVL_PR_ALWAYS) {
		  DelayType dly_type = pr->statement()->delay_type();

		  if (dly_type == NO_DELAY || dly_type == ZERO_DELAY) {
			cerr << pr->get_fileline() << ": error: always "
			        "process does not have any delay." << endl;
			cerr << pr->get_fileline() << ":      : A runtime "
			        "infinite loop will occur." << endl;
			result = true;

		  } else if (dly_type == POSSIBLE_DELAY && warn_inf_loop) {
			cerr << pr->get_fileline() << ": warning: always "
			        "process may not have any delay." << endl;
			cerr << pr->get_fileline() << ":        : A runtime "
			     << "infinite loop may be possible." << endl;
		  }
	    }

	      // The always_comb/ff/latch processes have special delay rules
	      // that need to be checked.
	    if ((pr->type() == IVL_PR_ALWAYS_COMB) ||
	        (pr->type() == IVL_PR_ALWAYS_FF) ||
	        (pr->type() == IVL_PR_ALWAYS_LATCH)) {
		  const NetEvWait *wait = dynamic_cast<const NetEvWait*> (pr->statement());
		  if (! wait) {
			  // The always_comb/latch processes have an event
			  // control added automatically by the compiler.
			ivl_assert(*pr, pr->type() == IVL_PR_ALWAYS_FF);
			cerr << pr->get_fileline() << ": error: the first "
			        "statement of an always_ff process must be "
			        "an event control statement." << endl;
			result = true;
		  } else if (wait->statement()->delay_type(true) != NO_DELAY) {
			cerr << pr->get_fileline() << ": error: there must ";

			if (pr->type() == IVL_PR_ALWAYS_FF) {
			      cerr << "only be a single event control and "
			              "no blocking delays in an always_ff "
			              "process.";
			} else {
			      cerr << "be no event controls or blocking "
			              "delays in an " << pr->type()
			           << " process.";
			}
			cerr << endl;
			result = true;
		  }

		  if ((pr->type() != IVL_PR_ALWAYS_FF) &&
		      (wait->nevents() == 0)) {
			if (pr->type() == IVL_PR_ALWAYS_LATCH) {
			      cerr << pr->get_fileline() << ": error: "
			              "always_latch process has no event "
			              "control." << endl;
			      result = true;
			} else {
			      ivl_assert(*pr, pr->type() == IVL_PR_ALWAYS_COMB);
			      cerr << pr->get_fileline() << ": warning: "
			              "always_comb process has no "
			              "sensitivities." << endl;
			}
		  }
	    }

	        /* If this is a final block it must not have a delay,
		   but this should have been caught by the statement
		   elaboration, so maybe this should be an internal
		   error? */
	    if (pr->type() == IVL_PR_FINAL) {
		  DelayType dly_type = pr->statement()->delay_type();

		  if (dly_type != NO_DELAY) {
			cerr << pr->get_fileline() << ": error: final"
			     << " statement contains a delay." << endl;
			result = true;
		  }
	    }
      }

      return result;
}

static void print_nexus_name(const Nexus*nex)
{
      for (const Link*cur = nex->first_nlink(); cur; cur = cur->next_nlink()) {
	    if (cur->get_dir() != Link::OUTPUT) continue;
	    const NetPins*obj = cur->get_obj();
	      // For a NetNet (signal) just use the name.
	    if (const NetNet*net = dynamic_cast<const NetNet*>(obj)) {
		  cerr << net->name();
		  return;
	      // For a NetPartSelect calculate the name.
	    } else if (const NetPartSelect*ps = dynamic_cast<const NetPartSelect*>(obj)) {
		  ivl_assert(*ps, ps->pin_count() >= 2);
		  ivl_assert(*ps, ps->pin(1).get_dir() == Link::INPUT);
		  ivl_assert(*ps, ps->pin(1).is_linked());
		  print_nexus_name(ps->pin(1).nexus());
		  cerr << "[]";
		  return;
	      // For a NetUReduce calculate the name.
	    } else if (const NetUReduce*reduce = dynamic_cast<const NetUReduce*>(obj)) {
		  ivl_assert(*reduce, reduce->pin_count() == 2);
		  ivl_assert(*reduce, reduce->pin(1).get_dir() == Link::INPUT);
		  ivl_assert(*reduce, reduce->pin(1).is_linked());
		  switch (reduce->type()) {
		    case NetUReduce::AND:
			cerr << "&";
			break;
		    case NetUReduce::OR:
			cerr << "|";
			break;
		    case NetUReduce::XOR:
			cerr << "^";
			break;
		    case NetUReduce::NAND:
			cerr << "~&";
			break;
		    case NetUReduce::NOR:
			cerr << "~|";
			break;
		    case NetUReduce::XNOR:
			cerr << "~^";
			break;
		    case NetUReduce::NONE:
			ivl_assert(*reduce, 0);
		  }
		  print_nexus_name(reduce->pin(1).nexus());
		  return;
	    } else if (const NetLogic*logic = dynamic_cast<const NetLogic*>(obj)) {
		  ivl_assert(*logic, logic->pin_count() >= 2);
		  ivl_assert(*logic, logic->pin(1).get_dir() == Link::INPUT);
		  ivl_assert(*logic, logic->pin(1).is_linked());
		  switch (logic->type()) {
		    case NetLogic::NOT:
			cerr << "~";
			break;
		    default:
			  // The other operators should never be used here,
			  // so just return the nexus name.
			cerr << nex->name();
			return;
		  }
		  print_nexus_name(logic->pin(1).nexus());
		  return;
	    }
	// Use the following to find the type of anything that may be missing:
	//    cerr << "(" << typeid(*obj).name() << ") ";
      }
	// Otherwise just use the nexus name so somthing is printed.
      cerr << nex->name();
}

static void print_event_probe_name(const NetEvProbe *prb)
{
      ivl_assert(*prb, prb->pin_count() == 1);
      ivl_assert(*prb, prb->pin(0).get_dir() == Link::INPUT);
      ivl_assert(*prb, prb->pin(0).is_linked());
      print_nexus_name(prb->pin(0).nexus());
}

static void check_event_probe_width(const LineInfo *info, const NetEvProbe *prb)
{
      ivl_assert(*prb, prb->pin_count() == 1);
      ivl_assert(*prb, prb->pin(0).get_dir() == Link::INPUT);
      ivl_assert(*prb, prb->pin(0).is_linked());
      if (prb->edge() == NetEvProbe::ANYEDGE) return;
      if (prb->pin(0).nexus()->vector_width() > 1) {
	    cerr << info->get_fileline() << " warning: Synthesis wants "
                    "the sensitivity list expressions for '";
	    switch (prb->edge()) {
	      case NetEvProbe::POSEDGE:
		  cerr << "posedge ";
		  break;
	      case NetEvProbe::NEGEDGE:
		  cerr << "negedge ";
		  break;
	      default:
		  break;
	    }
	    print_nexus_name(prb->pin(0).nexus());
	    cerr << "' to be a single bit." << endl;
      }
}

static void check_ff_sensitivity(const NetProc* statement)
{
      const NetEvWait *evwt = dynamic_cast<const NetEvWait*> (statement);
	// We have already checked for and reported if the first statmemnt is
	// not a wait.
      if (! evwt) return;

      for (unsigned cevt = 0; cevt < evwt->nevents(); cevt += 1) {
	    const NetEvent *evt = evwt->event(cevt);
	    for (unsigned cprb = 0; cprb < evt->nprobe(); cprb += 1) {
		  const NetEvProbe *prb = evt->probe(cprb);
		  check_event_probe_width(evwt, prb);
		  if (prb->edge() == NetEvProbe::ANYEDGE) {
			cerr << evwt->get_fileline() << " warning: Synthesis "
			        "requires the sensitivity list of an "
			        "always_ff process to only be edge "
			        "sensitive. ";
			print_event_probe_name(prb);
			cerr  << " is missing a pos/negedge." << endl;
		  }
	    }
      }
}

/*
 * Check to see if the always_* processes only contain synthesizable
 * constructs.
 */
bool Design::check_proc_synth() const
{
      bool result = false;
      for (const NetProcTop*pr = procs_ ;  pr ;  pr = pr->next_) {
	    if ((pr->type() == IVL_PR_ALWAYS_COMB) ||
	        (pr->type() == IVL_PR_ALWAYS_FF) ||
	        (pr->type() == IVL_PR_ALWAYS_LATCH)) {
		  result |= pr->statement()->check_synth(pr->type(),
		                                         pr->scope());
		  if (pr->type() == IVL_PR_ALWAYS_FF) {
			check_ff_sensitivity(pr->statement());
		  }
	    }
      }
      return result;
}

/*
 * Check whether all design elements have an explicit timescale or all
 * design elements use the default timescale. If a mixture of explicit
 * and default timescales is found, a warning message is output. Note
 * that we only need to check the top level design elements - nested
 * design elements will always inherit the timescale from their parent
 * if they don't have any local timescale declarations.
 *
 * NOTE: Strictly speaking, this should be an error for SystemVerilog
 * (1800-2012 section 3.14.2).
 */
static void check_timescales(bool&some_explicit, bool&some_implicit,
			     const PScope*scope)
{
      if (scope->time_unit_is_default)
	    some_implicit = true;
      else
	    some_explicit = true;
      if (scope->time_prec_is_default)
	    some_implicit = true;
      else
	    some_explicit = true;
}

static void check_timescales()
{
      bool some_explicit = false;
      bool some_implicit = false;
      map<perm_string,Module*>::iterator mod;
      for (mod = pform_modules.begin(); mod != pform_modules.end(); ++mod) {
	    const Module*mp = (*mod).second;
	    check_timescales(some_explicit, some_implicit, mp);
	    if (some_explicit && some_implicit)
		  break;
      }
      vector<PPackage*>::iterator pkg;
      if (gn_system_verilog() && !(some_explicit && some_implicit)) {
	    for (pkg = pform_packages.begin(); pkg != pform_packages.end(); ++pkg) {
		  const PPackage*pp = *pkg;
		  check_timescales(some_explicit, some_implicit, pp);
		  if (some_explicit && some_implicit)
			break;
	    }
      }
      if (gn_system_verilog() && !(some_explicit && some_implicit)) {
	    for (pkg = pform_units.begin(); pkg != pform_units.end(); ++pkg) {
		  const PPackage*pp = *pkg;
		    // We don't need a timescale if the compilation unit
		    // contains no items outside a design element.
		  if (pp->parameters.empty() &&
		      pp->wires.empty() &&
		      pp->tasks.empty() &&
		      pp->funcs.empty() &&
		      pp->classes.empty())
			continue;

		  check_timescales(some_explicit, some_implicit, pp);
		  if (some_explicit && some_implicit)
			break;
	    }
      }

      if (!(some_explicit && some_implicit))
	    return;

      if (gn_system_verilog()) {
	    cerr << "warning: "
		 << "Some design elements have no explicit time unit and/or"
		 << endl;
	    cerr << "       : "
		 << "time precision. This may cause confusing timing results."
		 << endl;
	    cerr << "       : "
		 << "Affected design elements are:"
		 << endl;
      } else {
	    cerr << "warning: "
		 << "Some modules have no timescale. This may cause"
		 << endl;
	    cerr << "       : "
		 << "confusing timing results.	Affected modules are:"
		 << endl;
      }

      for (mod = pform_modules.begin(); mod != pform_modules.end(); ++mod) {
	    const Module*mp = (*mod).second;
	    if (mp->has_explicit_timescale())
		  continue;
	    cerr << "       :   -- module " << (*mod).first
		 << " declared here: " << mp->get_fileline() << endl;
      }

      if (!gn_system_verilog())
	    return;

      for (pkg = pform_packages.begin(); pkg != pform_packages.end(); ++pkg) {
	    const PPackage*pp = *pkg;
	    if (pp->has_explicit_timescale())
		  continue;
	    cerr << "       :   -- package " << pp->pscope_name()
		 << " declared here: " << pp->get_fileline() << endl;
      }

      for (pkg = pform_units.begin(); pkg != pform_units.end(); ++pkg) {
	    PPackage*pp = *pkg;
	    if (pp->has_explicit_timescale())
		  continue;

	    if (pp->parameters.empty() &&
		pp->wires.empty() &&
		pp->tasks.empty() &&
		pp->funcs.empty() &&
		pp->classes.empty())
		  continue;

	    cerr << "       :   -- compilation unit";
	    if (pform_units.size() > 1) {
		  cerr << " from: " << pp->get_file();
	    }
	    cerr << endl;
      }
}

/*
 * This function is the root of all elaboration. The input is the list
 * of root module names. The function locates the Module definitions
 * for each root, does the whole elaboration sequence, and fills in
 * the resulting Design.
 */

struct pack_elem {
      PPackage*pack;
      NetScope*scope;
};

struct root_elem {
      Module *mod;
      NetScope *scope;
};

Design* elaborate(list<perm_string>roots)
{
      unsigned npackages = pform_packages.size();
      if (gn_system_verilog())
	    npackages += pform_units.size();

      vector<struct root_elem> root_elems(roots.size());
      vector<struct pack_elem> pack_elems(npackages);
      map<LexicalScope*,NetScope*> unit_scopes;
      bool rc = true;
      unsigned i = 0;

	// This is the output design. I fill it in as I scan the root
	// module and elaborate what I find.
      Design*des = new Design;

	// Create NetScope objects for compilation units first so that
	// unit_scopes is populated before packages are processed.
	// Compilation units may import from packages, so their ELABORATION
	// is deferred until after packages (see below).
      if (gn_system_verilog()) {
	    for (vector<PPackage*>::iterator pkg = pform_units.begin()
		       ; pkg != pform_units.end() ; ++pkg) {
		  PPackage*unit = *pkg;
		  NetScope*scope = des->make_package_scope(unit->pscope_name(), 0, true);
		  scope->set_line(unit);
		  scope->add_imports(&unit->explicit_imports);
		  set_scope_timescale(des, scope, unit);
		  unit_scopes[unit] = scope;

		  // Save for later — work item added AFTER packages
		  pack_elems[i].pack = unit;
		  pack_elems[i].scope = scope;
		  i += 1;
	    }
      }

	// Elaborate the packages. Package elaboration is simpler
	// because there are fewer sub-scopes involved. Note that
	// in SystemVerilog, packages are not allowed to refer to
	// the compilation unit scope, but the VHDL preprocessor
	// assumes they can.
	// Packages are added to the work list BEFORE compilation units
	// so that UVM/library packages are fully elaborated before user
	// classes at the compilation-unit scope try to extend them.
      for (vector<PPackage*>::iterator pkg = pform_packages.begin()
		 ; pkg != pform_packages.end() ; ++pkg) {
	    PPackage*pack = *pkg;
	    NetScope*unit_scope = unit_scopes[pack->parent_scope()];
	    NetScope*scope = des->make_package_scope(pack->pscope_name(), unit_scope, false);
	    scope->set_line(pack);
	    scope->add_imports(&pack->explicit_imports);
	    set_scope_timescale(des, scope, pack);

	    elaborator_work_item_t*es = new elaborate_package_t(des, scope, pack);
	    des->elaboration_work_list.push_back(es);

	    pack_elems[i].pack = pack;
	    pack_elems[i].scope = scope;
	    i += 1;
      }

	// Now add compilation units to the work list (after packages) so
	// that user classes defined outside any module can safely extend
	// library classes from imported packages.
      if (gn_system_verilog()) {
	    for (unsigned j = 0; j < pform_units.size(); j++) {
		  // pack_elems[0..pform_units.size()-1] were filled above
		  elaborator_work_item_t*es =
			new elaborate_package_t(des, pack_elems[j].scope,
						pack_elems[j].pack);
		  des->elaboration_work_list.push_back(es);
	    }
      }

	// Scan the root modules by name, and elaborate their scopes.
      i = 0;
      for (list<perm_string>::const_iterator root = roots.begin()
		 ; root != roots.end() ; ++ root ) {

	      // Look for the root module in the list.
	    map<perm_string,Module*>::const_iterator mod = pform_modules.find(*root);
	    if (mod == pform_modules.end()) {
		  cerr << "error: Unable to find the root module \""
		       << (*root) << "\" in the Verilog source." << endl;
		  cerr << "     : Perhaps ``-s " << (*root)
		       << "'' is incorrect?" << endl;
		  des->errors++;
		  continue;
	    }

	      // Get the module definition for this root instance.
	    Module *rmod = (*mod).second;

	      // Get the compilation unit scope for this module.
	    NetScope*unit_scope = unit_scopes[rmod->parent_scope()];

	      // Make the root scope. This makes a NetScope object and
	      // pushes it into the list of root scopes in the Design.
	    NetScope*scope = des->make_root_scope(*root, unit_scope,
						  rmod->program_block,
						  rmod->is_interface);

	      // Collect some basic properties of this scope from the
	      // Module definition.
	    scope->set_line(rmod);
	    scope->add_imports(&rmod->explicit_imports);
	    set_scope_timescale(des, scope, rmod);

	      // Save this scope, along with its definition, in the
	      // "root_elems" list for later passes.
	    root_elems[i].mod = rmod;
	    root_elems[i].scope = scope;
	    i += 1;

	      // Arrange for these scopes to be elaborated as root
	      // scopes. Create an "elaborate_root_scope" object to
	      // contain the work item, and append it to the scope
	      // elaborations work list.
	    elaborator_work_item_t*es = new elaborate_root_scope_t(des, scope, rmod);
	    des->elaboration_work_list.push_back(es);
      }

	// Run the work list of scope elaborations until the list is
	// empty. This list is initially populated above where the
	// initial root scopes are primed.
      while (! des->elaboration_work_list.empty()) {
	      // Push a work item to process the defparams of any scopes
	      // that are elaborated during this pass. For the first pass
	      // this will be all the root scopes. For subsequent passes
	      // it will be any scopes created during the previous pass
	      // by a generate construct or instance array.
	    des->elaboration_work_list.push_back(new top_defparams(des));

	      // Transfer the queue to a temporary queue.
	    list<elaborator_work_item_t*> cur_queue;
	    std::swap(cur_queue, des->elaboration_work_list);

	      // Run from the temporary queue. If the temporary queue
	      // items create new work queue items, they will show up
	      // in the elaboration_work_list and then we get to run
	      // through them in the next pass.
	    while (! cur_queue.empty()) {
		  elaborator_work_item_t*tmp = cur_queue.front();
		  cur_queue.pop_front();
		  tmp->elaborate_runrun();
		  delete tmp;
	    }

	    if (! des->elaboration_work_list.empty()) {
		  des->elaboration_work_list.push_back(new later_defparams(des));
	    }
      }

      if (debug_elaborate) {
	    cerr << "<toplevel>: elaborate: "
		 << "elaboration work list done. Start processing residual defparams." << endl;
      }

	// Look for residual defparams (that point to a non-existent
	// scope) and clean them out.
      des->residual_defparams();

	// Errors already? Probably missing root modules. Just give up
	// now and return nothing.
      if (des->errors > 0)
	    return des;

	// Now we have the full design, check for timescale inconsistencies.
      if (warn_timescale)
	    check_timescales();

      if (debug_elaborate) {
	    cerr << "<toplevel>: elaborate: "
		 << "Start calling Package elaborate_sig methods." << endl;
      }

	// With the parameters evaluated down to constants, we have
	// what we need to elaborate signals and memories. This pass
	// creates all the NetNet and NetMemory objects for declared
	// objects.
      for (i = 0; i < pack_elems.size(); i += 1) {
	    const PPackage*pack = pack_elems[i].pack;
	    NetScope*scope= pack_elems[i].scope;

	    if (! pack->elaborate_sig(des, scope)) {
		  if (debug_elaborate) {
			cerr << "<toplevel>" << ": debug: " << pack->pscope_name()
			     << ": elaborate_sig failed!!!" << endl;
		  }
		  delete des;
		  return 0;
	    }
      }

      if (debug_elaborate) {
	    cerr << "<toplevel>: elaborate: "
		 << "Start calling $root elaborate_sig methods." << endl;
      }

      if (debug_elaborate) {
	    cerr << "<toplevel>: elaborate: "
		 << "Start calling root module elaborate_sig methods." << endl;
      }

      for (i = 0; i < root_elems.size(); i++) {
	    const Module *rmod = root_elems[i].mod;
	    NetScope *scope = root_elems[i].scope;
	    scope->set_num_ports( rmod->port_count() );

	    if (debug_elaborate) {
		  cerr << "<toplevel>" << ": debug: " << rmod->mod_name()
		       << ": port elaboration root "
		       << rmod->port_count() << " ports" << endl;
	    }

	    if (! rmod->elaborate_sig(des, scope)) {
		  if (debug_elaborate) {
			cerr << "<toplevel>" << ": debug: " << rmod->mod_name()
			     << ": elaborate_sig failed!!!" << endl;
		  }
		  delete des;
		  return 0;
	    }

	      // Some of the generators need to have the ports correctly
	      // defined for the root modules. This code does that.
	    for (unsigned idx = 0; idx < rmod->port_count(); idx += 1) {
		  vector<PEIdent*> mport = rmod->get_port(idx);
                  unsigned int prt_vector_width = 0;
                  PortType::Enum ptype = PortType::PIMPLICIT;
		  for (unsigned pin = 0; pin < mport.size(); pin += 1) {
			  // This really does more than we need and adds extra
			  // stuff to the design that should be cleaned later.
			const NetNet *netnet = mport[pin]->elaborate_subport(des, scope);
			if (netnet != 0) {
			  // Elaboration may actually fail with
			  // erroneous input source
                          prt_vector_width += netnet->vector_width() * netnet->pin_count();
                          ptype = PortType::merged(netnet->port_type(), ptype);
			}
		  }
                  if (debug_elaborate) {
                           cerr << "<toplevel>" << ": debug: " << rmod->mod_name()
                                << ": adding module port "
                                << rmod->get_port_name(idx) << endl;
                     }
		  scope->add_module_port_info(idx, rmod->get_port_name(idx), ptype, prt_vector_width );
	    }
      }

	// I2 (Phase 62m): now that elaborate_sig has been called for
	// all packages and root modules (so all classes are
	// registered), run a repair pass to patch signals whose
	// typeref-to-class data type was unresolvable at PWire::elaborate_sig
	// time.  Those signals fell through to a logic-vector net_type;
	// re-resolve them to the proper netclass_t before statement
	// elaboration emits assignments against them.  Without this,
	// e.g. `uvm_default_table_printer = new()` compiles as
	// "%null; %store/obj v..." (number-fallback rhs) and the
	// assignment silently no-ops at runtime.
      for (NetScope*pkg : des->find_package_scopes())
	    pkg->repair_typed_class_signals(des);
      for (NetScope*root : des->find_root_scopes())
	    root->repair_typed_class_signals(des);

	// Now that the structure and parameters are taken care of,
	// run through the pform again and generate the full netlist.

      report_elaboration_perf_phase_("packages-begin", 0, pack_elems.size());
      for (i = 0; i < pack_elems.size(); i += 1) {
	    const PPackage*pkg = pack_elems[i].pack;
	    NetScope*scope = pack_elems[i].scope;
	    report_elaboration_perf_phase_("package-elaborate", i+1, pack_elems.size());
	    rc &= pkg->elaborate(des, scope);
      }

      report_elaboration_perf_phase_("packages-end", pack_elems.size(), pack_elems.size());
      report_elaboration_perf_phase_("roots-begin", 0, root_elems.size());
      for (i = 0; i < root_elems.size(); i++) {
	    const Module *rmod = root_elems[i].mod;
	    NetScope *scope = root_elems[i].scope;
	    report_elaboration_perf_phase_("root-elaborate", i+1, root_elems.size());
	    rc &= rmod->elaborate(des, scope);
      }
      report_elaboration_perf_phase_("roots-end", root_elems.size(), root_elems.size());

      report_elaboration_perf_phase_("specialized-bodies-begin");
      finalize_pending_specialized_class_elaboration(des);
      report_elaboration_perf_phase_("specialized-bodies-end");

      if (rc == false) {
	    delete des;
	    return 0;
      }

	// Now that everything is fully elaborated verify that we do
	// not have an always block with no delay (an infinite loop),
        // or a final block with a delay.
      bool has_failure = des->check_proc_delay();

	// Check to see if the always_comb/ff/latch processes only have
	// synthesizable constructs
      has_failure |= des->check_proc_synth();

      if (debug_elaborate) {
               cerr << "<toplevel>" << ": debug: "
                    << " finishing with "
                    <<  des->find_root_scopes().size() << " root scopes " << endl;
         }

      if (has_failure) {
	    delete des;
	    des = 0;
      }

      return des;
}
