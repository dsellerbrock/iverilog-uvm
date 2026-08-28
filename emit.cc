/*
 * Copyright (c) 1998-2025 Stephen Williams (steve@icarus.com)
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

# include  <iostream>
# include  <sstream>

/*
 * The emit function is called to generate the output required of the
 * target.
 */
# include  "target.h"
# include  "netclass.h"
# include  "netlist.h"
# include  "compiler.h"
# include  <typeinfo>
# include  <algorithm>
# include  <cassert>
# include  <cstring>

using namespace std;

bool NetNode::emit_node(struct target_t*) const
{
      cerr << "EMIT: Gate type? " << typeid(*this).name() << endl;
      return false;
}

bool NetLogic::emit_node(struct target_t*tgt) const
{
      tgt->logic(this);
      return true;
}

bool NetUDP::emit_node(struct target_t*tgt) const
{
      tgt->udp(this);
      return true;
}

bool NetAbs::emit_node(struct target_t*tgt) const
{
      tgt->lpm_abs(this);
      return true;
}

bool NetAddSub::emit_node(struct target_t*tgt) const
{
      tgt->lpm_add_sub(this);
      return true;
}

bool NetArrayDq::emit_node(struct target_t*tgt) const
{
      return tgt->lpm_array_dq(this);
}

bool NetCaseCmp::emit_node(struct target_t*tgt) const
{
      tgt->net_case_cmp(this);
      return true;
}

bool NetCastInt2::emit_node(struct target_t*tgt) const
{
      return tgt->lpm_cast_int2(this);
}

bool NetCastInt4::emit_node(struct target_t*tgt) const
{
      return tgt->lpm_cast_int4(this);
}

bool NetCastReal::emit_node(struct target_t*tgt) const
{
      return tgt->lpm_cast_real(this);
}

bool NetCLShift::emit_node(struct target_t*tgt) const
{
      tgt->lpm_clshift(this);
      return true;
}

bool NetCompare::emit_node(struct target_t*tgt) const
{
      tgt->lpm_compare(this);
      return true;
}

bool NetConcat::emit_node(struct target_t*tgt) const
{
      return tgt->concat(this);
}

bool NetConst::emit_node(struct target_t*tgt) const
{
      return tgt->net_const(this);
}

bool NetDivide::emit_node(struct target_t*tgt) const
{
      tgt->lpm_divide(this);
      return true;
}

bool NetFF::emit_node(struct target_t*tgt) const
{
      tgt->lpm_ff(this);
      return true;
}

bool NetLatch::emit_node(struct target_t*tgt) const
{
      tgt->lpm_latch(this);
      return true;
}

bool NetLiteral::emit_node(struct target_t*tgt) const
{
      return tgt->net_literal(this);
}

bool NetModulo::emit_node(struct target_t*tgt) const
{
      tgt->lpm_modulo(this);
      return true;
}

bool NetMult::emit_node(struct target_t*tgt) const
{
      tgt->lpm_mult(this);
      return true;
}

bool NetMux::emit_node(struct target_t*tgt) const
{
      tgt->lpm_mux(this);
      return true;
}

bool NetPartSelect::emit_node(struct target_t*tgt) const
{
      return tgt->part_select(this);
}

bool NetPow::emit_node(struct target_t*tgt) const
{
      tgt->lpm_pow(this);
      return true;
}

bool NetReplicate::emit_node(struct target_t*tgt) const
{
      return tgt->replicate(this);
}

bool NetSignExtend::emit_node(struct target_t*tgt) const
{
      return tgt->sign_extend(this);
}

bool NetSubstitute::emit_node(struct target_t*tgt) const
{
      return tgt->substitute(this);
}

bool NetUReduce::emit_node(struct target_t*tgt) const
{
      return tgt->ureduce(this);
}

bool NetSysFunc::emit_node(struct target_t*tgt) const
{
      return tgt->net_sysfunction(this);
}

bool NetUserFunc::emit_node(struct target_t*tgt) const
{
      return tgt->net_function(this);
}

bool NetTran::emit_node(struct target_t*tgt) const
{
      return tgt->tran(this);
}

bool NetBUFZ::emit_node(struct target_t*tgt) const
{
      return tgt->bufz(this);
}

bool NetProcTop::emit(struct target_t*tgt) const
{
      return tgt->process(this);
}

bool NetAnalogTop::emit(struct target_t*tgt) const
{
      return tgt->process(this);
}

bool NetProc::emit_proc(struct target_t*) const
{
      cerr << "EMIT: Proc type? " << typeid(*this).name() << endl;
      return false;
}

bool NetAlloc::emit_proc(struct target_t*tgt) const
{
      tgt->proc_alloc(this);
      return true;
}

bool NetAssign::emit_proc(struct target_t*tgt) const
{
      return tgt->proc_assign(this);
}

bool NetAssignNB::emit_proc(struct target_t*tgt) const
{
      tgt->proc_assign_nb(this);
      return true;
}

bool NetBlock::emit_proc(struct target_t*tgt) const
{
      return tgt->proc_block(this);
}

bool NetBreak::emit_proc(struct target_t*tgt) const
{
      return tgt->proc_break(this);
}

bool NetCase::emit_proc(struct target_t*tgt) const
{
      tgt->proc_case(this);
      return true;
}

bool NetCAssign::emit_proc(struct target_t*tgt) const
{
      return tgt->proc_cassign(this);
}

bool NetCondit::emit_proc(struct target_t*tgt) const
{
      return tgt->proc_condit(this);
}

bool NetContinue::emit_proc(struct target_t*tgt) const
{
      return tgt->proc_continue(this);
}

bool NetContribution::emit_proc(struct target_t*tgt) const
{
      return tgt->proc_contribution(this);
}

bool NetDeassign::emit_proc(struct target_t*tgt) const
{
      return tgt->proc_deassign(this);
}

bool NetDisable::emit_proc(struct target_t*tgt) const
{
      return tgt->proc_disable(this);
}

bool NetDoWhile::emit_proc(struct target_t*tgt) const
{
      tgt->proc_do_while(this);
      return true;
}

void NetDoWhile::emit_proc_recurse(struct target_t*tgt) const
{
      proc_->emit_proc(tgt);
}

bool NetForce::emit_proc(struct target_t*tgt) const
{
      return tgt->proc_force(this);
}

bool NetForever::emit_proc(struct target_t*tgt) const
{
      tgt->proc_forever(this);
      return true;
}

bool NetForLoop::emit_proc(struct target_t*tgt) const
{
      return tgt->proc_forloop(this);
}

bool NetForLoop::emit_recurse_init(struct target_t*tgt) const
{
      if (init_statement_) return init_statement_->emit_proc(tgt);
      return true;
}

bool NetForLoop::emit_recurse_stmt(struct target_t*tgt) const
{
      if (statement_) return statement_->emit_proc(tgt);
      return true;
}

bool NetForLoop::emit_recurse_step(struct target_t*tgt) const
{
      if (step_statement_) return step_statement_->emit_proc(tgt);
      return true;
}

bool NetForLoop::emit_recurse_condition(struct expr_scan_t*tgt) const
{
      if (condition_) condition_->expr_scan(tgt);
      return true;
}

bool NetFree::emit_proc(struct target_t*tgt) const
{
      tgt->proc_free(this);
      return true;
}

bool NetPDelay::emit_proc(struct target_t*tgt) const
{
      return tgt->proc_delay(this);
}

bool NetPDelay::emit_proc_recurse(struct target_t*tgt) const
{
      if (statement_) return statement_->emit_proc(tgt);
      return true;
}

bool NetRelease::emit_proc(struct target_t*tgt) const
{
      return tgt->proc_release(this);
}

bool NetRepeat::emit_proc(struct target_t*tgt) const
{
      tgt->proc_repeat(this);
      return true;
}

bool NetSTask::emit_proc(struct target_t*tgt) const
{
      tgt->proc_stask(this);
      return true;
}

bool NetUTask::emit_proc(struct target_t*tgt) const
{
      tgt->proc_utask(this);
      return true;
}

bool NetWhile::emit_proc(struct target_t*tgt) const
{
      tgt->proc_while(this);
      return true;
}

void NetWhile::emit_proc_recurse(struct target_t*tgt) const
{
      proc_->emit_proc(tgt);
}

void NetBlock::emit_recurse(struct target_t*tgt) const
{
      if (last_ == 0)
	    return;

      const NetProc*cur = last_;
      do {
	    cur = cur->next_;
	    cur->emit_proc(tgt);
      } while (cur != last_);
}

bool NetCondit::emit_recurse_if(struct target_t*tgt) const
{
      if (if_)
	    return if_->emit_proc(tgt);
      else
	    return true;
}

bool NetCondit::emit_recurse_else(struct target_t*tgt) const
{
      if (else_)
	    return else_->emit_proc(tgt);
      else
	    return true;
}

bool NetEvProbe::emit_node(struct target_t*tgt) const
{
      tgt->net_probe(this);
      return true;
}

bool NetEvTrig::emit_proc(struct target_t*tgt) const
{
      return tgt->proc_trigger(this);
}

bool NetEvNBTrig::emit_proc(struct target_t*tgt) const
{
      return tgt->proc_nb_trigger(this);
}

bool NetEvWait::emit_proc(struct target_t*tgt) const
{
      return tgt->proc_wait(this);
}

bool NetEvTrigObj::emit_proc(struct target_t*tgt) const
{
      return tgt->proc_trigger_obj(this);
}

bool NetEvWaitObj::emit_proc(struct target_t*tgt) const
{
      return tgt->proc_wait_obj(this);
}

bool NetEvWaitObj::emit_recurse(struct target_t*tgt) const
{
      if (!statement_) return true;
      return statement_->emit_proc(tgt);
}

bool NetEvTrigArr::emit_proc(struct target_t*tgt) const
{
      return tgt->proc_trigger_arr(this);
}

bool NetEvWaitArr::emit_proc(struct target_t*tgt) const
{
      return tgt->proc_wait_arr(this);
}

bool NetEvWaitArr::emit_recurse(struct target_t*tgt) const
{
      if (!statement_) return true;
      return statement_->emit_proc(tgt);
}

bool NetEvWait::emit_recurse(struct target_t*tgt) const
{
      if (!statement_) return true;
      return statement_->emit_proc(tgt);
}

void NetForever::emit_recurse(struct target_t*tgt) const
{
      if (statement_)
	    statement_->emit_proc(tgt);
}

void NetRepeat::emit_recurse(struct target_t*tgt) const
{
      if (statement_)
	    statement_->emit_proc(tgt);
}

void netclass_t::emit_scope(struct target_t*tgt) const
{
      class_scope_->emit_scope(tgt);
}

void NetScope::emit_scope(struct target_t*tgt) const
{
      if (debug_emit) {
	    cerr << "NetScope::emit_scope: "
		 << "Emit scope " << scope_path(this) << endl;
      }

      tgt->scope(this);

      for (const NetEvent*cur = events_ ;  cur ;  cur = cur->snext_)
	    tgt->event(cur);

      for (map<perm_string,netclass_t*>::const_iterator cur = classes_.begin()
		 ; cur != classes_.end() ; ++cur) {
	    cur->second->emit_scope(tgt);
	    tgt->class_type(this, cur->second);
      }

      for (map<const enum_type_t*,netenum_t*>::const_iterator cur = enum_sets_.begin()
		 ; cur != enum_sets_.end() ;  ++cur)
	    tgt->enumeration(this, cur->second);

      for (map<hname_t,NetScope*>::const_iterator cur = children_.begin()
		 ; cur != children_.end() ; ++ cur )
	    cur->second->emit_scope(tgt);

      for (signals_map_iter_t cur = signals_map_.begin()
		 ; cur != signals_map_.end() ; ++ cur ) {
	    tgt->signal(cur->second);
      }

	// Run the signals again, but this time to connect the
	// delay paths. This is done as a second pass because
	// the paths reference other signals that may be later
	// in the list. We can do it here because delay paths are
	// always connected within the scope.
      for (signals_map_iter_t cur = signals_map_.begin()
		 ; cur != signals_map_.end() ; ++ cur) {

	    tgt->signal_paths(cur->second);
      }

      if (type_ == MODULE) tgt->convert_module_ports(this);

	/* Delay paths and declaration-delay boundary indexes are complete once
	 * both signal passes and module-port conversion have run. Interface
	 * binding metadata remains live for later procedural property lowering. */
      for (signals_map_iter_t cur = signals_map_.begin()
		 ; cur != signals_map_.end() ; ++cur) {
	    cur->second->release_emitted_signal_aux();
      }
}

bool NetScope::emit_defs(struct target_t*tgt) const
{
      bool flag = true;

      if (debug_emit) {
	    cerr << "NetScope::emit_defs: "
		 << "Emit definitions for " << scope_path(this) << endl;
      }

      switch (type_) {
	  case PACKAGE:
	  case MODULE:
	    for (map<hname_t,NetScope*>::const_iterator cur = children_.begin()
		       ; cur != children_.end() ; ++ cur )
		  flag &= cur->second->emit_defs(tgt);
	    for (map<perm_string,netclass_t*>::const_iterator cur = classes_.begin()
		       ; cur != classes_.end() ; ++ cur)
		  flag &= cur->second->emit_defs(tgt);
	    break;

	  case FUNC:
	    flag &= tgt->func_def(this);
	    if (func_def())
		  const_cast<NetFuncDef*>(func_def())->release_proc();
	    break;
	  case TASK:
	    tgt->task_def(this);
	    if (task_def())
		  const_cast<NetTaskDef*>(task_def())->release_proc();
	    break;
	  default:  /* BEGIN_END and FORK_JOIN, GENERATE... */
	    for (map<hname_t,NetScope*>::const_iterator cur = children_.begin()
		       ; cur != children_.end() ; ++ cur )
		  flag &= cur->second->emit_defs(tgt);
	    break;
      }

      return flag;
}

bool netclass_t::emit_defs(struct target_t*tgt) const
{
      return class_scope_->emit_defs(tgt);
}

int Design::emit(struct target_t*tgt)
{
      int rc = 0;

      if (tgt->start_design(this) == false)
	    return -2;

	/* A validation-only target has already received the fully parsed,
	   elaborated, and post-processed Design through start_design(). Avoid
	   constructing a second target-side copy when it accepts the skeletal
	   API design initialized there. The null target uses this path;
	   ordinary code generators retain the complete traversal below. */
      if (!tgt->needs_design())
	    return tgt->end_design(this);

      /* Converted procedure trees are released below. Preserve shared event
       * objects until every later process has been converted by the target.
       * Validation-only and failed targets returned before entering this
       * terminal release phase. */
      net_event_target_release_mode(true);

	// enumerate package scopes
      for (map<perm_string,NetScope*>::const_iterator scope = packages_.begin()
		 ; scope != packages_.end() ; ++ scope) {
	    scope->second->emit_scope(tgt);
      }

	// enumerate root scopes
      for (list<NetScope*>::const_iterator scope = root_scopes_.begin()
		 ; scope != root_scopes_.end(); ++ scope ) {
	    (*scope)->emit_scope(tgt);
      }
      size_t released_heap_bytes = release_unused_heap_pages();
      if (verbose_flag)
	    cout << " ... target scopes and signals complete" << endl;

	// emit nodes
      bool nodes_rc = true;
      while (nodes_) {
	    NetNode*cur = nodes_->node_next_;
	    if (nodes_rc)
		  nodes_rc = cur->emit_node(tgt);
	    delete cur;
      }

      released_heap_bytes += release_unused_heap_pages();


      bool branches_rc = true;
      for (const NetBranch*cur = branches_ ; cur ; cur = cur->next_) {
	    branches_rc = tgt->branch(cur) && branches_rc;
      }

      bool end_nodes_rc = tgt->end_nodes();
      nodes_rc = end_nodes_rc && nodes_rc;

      size_t released_connectivity_links = 0;
      if (tgt->can_release_source_connectivity()) {
            for (map<perm_string,NetScope*>::const_iterator scope = packages_.begin()
                       ; scope != packages_.end() ; ++scope)
                  released_connectivity_links +=
                        scope->second->release_signal_connectivity();
            for (list<NetScope*>::const_iterator scope = root_scopes_.begin()
                       ; scope != root_scopes_.end(); ++scope)
                  released_connectivity_links +=
                        (*scope)->release_signal_connectivity();
            for (NetBranch*cur = branches_; cur; cur = cur->next_)
                  released_connectivity_links +=
                        cur->release_terminal_connectivity();
            released_heap_bytes += release_unused_heap_pages();
      }
      if (verbose_flag)
            cout << " ... target structural nodes complete" << endl;

      if (verbose_flag && released_connectivity_links)
            cout << " ... source connectivity released ("
                 << released_connectivity_links << " pin records)" << endl;

      if (verbose_flag && released_heap_bytes)
	    cout << " ... allocator released " << released_heap_bytes
		 << " bytes while converting target records" << endl;

      if (verbose_flag)
	    cout << " ... source structural nodes released" << endl;

	/* DLL targets materialize statements without consulting the target-side
	 * task/function definitions. Convert ordinary processes first for targets
	 * that advertise this ordering, so their source trees can be released
	 * before definition conversion builds another large set of records. */
      bool proc_rc = true;
      const bool emit_processes_before_definitions =
	    tgt->can_emit_processes_before_definitions();
      const bool ordered_process_callbacks =
	    tgt->ordered_process_callbacks();
      assert(!ordered_process_callbacks ||
	     !emit_processes_before_definitions);
      const auto emit_ordinary_processes = [&]() {
	    while (procs_) {
		  NetProcTop*idx = procs_;
		  proc_rc &= idx->emit(tgt);
		  if (idx->scope()->var_init() == idx->statement())
			idx->scope()->set_var_init(0);
		  delete_process(idx);
	    }
      };

      if (emit_processes_before_definitions) {
	    emit_ordinary_processes();
	    size_t process_released_heap_bytes = release_unused_heap_pages();
	    if (verbose_flag)
		  cout << " ... target ordinary processes complete" << endl;
	    if (verbose_flag && process_released_heap_bytes)
		  cout << " ... allocator released "
		       << process_released_heap_bytes
		       << " bytes after source process release" << endl;
      }

	// emit task and function definitions
      bool tasks_rc = true;
      for (map<perm_string,NetScope*>::const_iterator scope = packages_.begin()
		 ; scope != packages_.end() ; ++ scope )
	    tasks_rc &= scope->second->emit_defs(tgt);
      for (list<NetScope*>::const_iterator scope = root_scopes_.begin()
		 ; scope != root_scopes_.end(); ++ scope )
	    tasks_rc &= (*scope)->emit_defs(tgt);
      if (verbose_flag)
	    cout << " ... target task/function definitions complete" << endl;

	/* A target that applies its own final process ordering receives a compact
	 * source-only index before any procedure is lowered. Start with the exact
	 * base order historically observed through the DLL design list: callbacks
	 * were prepended, and analog callbacks came last, so reversed analogs form
	 * a prefix followed by reversed ordinary processes. */
      vector<target_process_ref_t> ordered_processes;
      bool process_order_rc = true;
      if (ordered_process_callbacks) {
	    for (NetAnalogTop*idx = aprocs_; idx; idx = idx->next_)
		  ordered_processes.push_back(target_process_ref_t(idx));
	    reverse(ordered_processes.begin(), ordered_processes.end());

	    const size_t ordinary_begin = ordered_processes.size();
	    for (NetProcTop*idx = procs_; idx; idx = idx->next_)
		  ordered_processes.push_back(target_process_ref_t(idx));
	    reverse(ordered_processes.begin() + ordinary_begin,
		    ordered_processes.end());
	    process_order_rc = tgt->order_processes(ordered_processes);
      }

	/* Incremental targets initialize their procedural handoff only after
	 * every task/function body is available. Legacy targets use no-op hooks
	 * and retain their complete process list for end_design(). */
      bool processes_started = false;
      bool process_handoff_rc = process_order_rc;
      if (process_order_rc) {
	    process_handoff_rc = tgt->start_processes();
	    processes_started = true;
      }

	// emit the processes
      if (ordered_process_callbacks && process_order_rc) {
	    /* The ordered vector now owns reachability for ordinary source
	     * processes. Detach the list so each tree can be destroyed as soon as
	     * its synchronous target callback returns, regardless of permutation. */
	    procs_ = 0;
	    procs_idx_ = 0;
	    for (vector<target_process_ref_t>::const_iterator cur =
		       ordered_processes.begin();
		 cur != ordered_processes.end(); ++cur) {
		  if (cur->analog) {
			proc_rc &= cur->analog->emit(tgt);
		  } else {
			assert(cur->net);
			proc_rc &= cur->net->emit(tgt);
			if (cur->net->scope()->var_init() ==
			    cur->net->statement())
			      cur->net->scope()->set_var_init(0);
			delete cur->net;
		  }
	    }
	} else if (ordered_process_callbacks) {
	    /* Ordering failed before the target design began. Release the source
	     * process trees without invoking callbacks. */
	    while (procs_) {
		  NetProcTop*idx = procs_;
		  procs_ = idx->next_;
		  if (idx->scope()->var_init() == idx->statement())
			idx->scope()->set_var_init(0);
		  delete idx;
	    }
	    procs_idx_ = 0;
	} else {
	    if (!emit_processes_before_definitions)
		  emit_ordinary_processes();
	    for (const NetAnalogTop*idx = aprocs_ ; idx ; idx = idx->next_)
		  proc_rc &= idx->emit(tgt);
      }
      if (processes_started)
	    process_handoff_rc = tgt->end_processes() && process_handoff_rc;
      if (verbose_flag)
	    cout << " ... target processes complete" << endl;

      if (nodes_rc == false)
	    tgt->errors += 1;
      if (tasks_rc == false)
	    tgt->errors += 1;
      if (proc_rc == false)
	    tgt->errors += 1;
      if (process_handoff_rc == false)
	    tgt->errors += 1;
      if (branches_rc == false)
	    tgt->errors += 1;

      rc = tgt->end_design(this);

      net_event_target_release_mode(false);

      if (nodes_rc == false)
	    return -1;
      if (tasks_rc == false)
	    return -2;
      if (proc_rc == false)
	    return -3;
      if (branches_rc == false)
	    return -4;

      return rc;
}

void NetEAccess::expr_scan(struct expr_scan_t*tgt) const
{
      tgt->expr_access_func(this);
}

void NetEArrayPattern::expr_scan(struct expr_scan_t*tgt) const
{
      tgt->expr_array_pattern(this);
}

void NetEArraySlice::expr_scan(struct expr_scan_t*tgt) const
{
      tgt->expr_array_slice(this);
}

void NetEBinary::expr_scan(struct expr_scan_t*tgt) const
{
      tgt->expr_binary(this);
}

void NetEConcat::expr_scan(struct expr_scan_t*tgt) const
{
      tgt->expr_concat(this);
}

void NetEConst::expr_scan(struct expr_scan_t*tgt) const
{
      tgt->expr_const(this);
}

void NetEConstEnum::expr_scan(struct expr_scan_t*tgt) const
{
      tgt->expr_const(this);
}

void NetEConstParam::expr_scan(struct expr_scan_t*tgt) const
{
      tgt->expr_param(this);
}

void NetECReal::expr_scan(struct expr_scan_t*tgt) const
{
      tgt->expr_creal(this);
}

void NetECRealParam::expr_scan(struct expr_scan_t*tgt) const
{
      tgt->expr_rparam(this);
}

void NetEEvent::expr_scan(struct expr_scan_t*tgt) const
{
      tgt->expr_event(this);
}

void NetELast::expr_scan(struct expr_scan_t*tgt) const
{
      tgt->expr_last(this);
}

void NetENetenum::expr_scan(struct expr_scan_t*tgt) const
{
      tgt->expr_netenum(this);
}

void NetENew::expr_scan(struct expr_scan_t*tgt) const
{
      tgt->expr_new(this);
}

void NetENull::expr_scan(struct expr_scan_t*tgt) const
{
      tgt->expr_null(this);
}

void NetEProperty::expr_scan(struct expr_scan_t*tgt) const
{
      tgt->expr_property(this);
}

void NetEScope::expr_scan(struct expr_scan_t*tgt) const
{
      tgt->expr_scope(this);
}

void NetESelect::expr_scan(struct expr_scan_t*tgt) const
{
      tgt->expr_select(this);
}

void NetESFunc::expr_scan(struct expr_scan_t*tgt) const
{
      tgt->expr_sfunc(this);
}

void NetEShallowCopy::expr_scan(struct expr_scan_t*tgt) const
{
      tgt->expr_scopy(this);
}

void NetEShallowCopy::expr_scan_oper1(struct expr_scan_t*tgt) const
{
      arg1_->expr_scan(tgt);
}

void NetEShallowCopy::expr_scan_oper2(struct expr_scan_t*tgt) const
{
      arg2_->expr_scan(tgt);
}

void NetEUFunc::expr_scan(struct expr_scan_t*tgt) const
{
      tgt->expr_ufunc(this);
}

void NetESignal::expr_scan(struct expr_scan_t*tgt) const
{
      tgt->expr_signal(this);
}

void NetETernary::expr_scan(struct expr_scan_t*tgt) const
{
      tgt->expr_ternary(this);
}

void NetEUnary::expr_scan(struct expr_scan_t*tgt) const
{
      tgt->expr_unary(this);
}
