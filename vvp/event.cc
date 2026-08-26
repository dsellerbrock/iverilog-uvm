/*
 * Copyright (c) 2004-2025 Stephen Williams (steve@icarus.com)
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

# include  "event.h"
# include  "compile.h"
# include  "vthread.h"
# include  "schedule.h"
# include  "vpi_priv.h"
# include  "config.h"
# include  <cstring>
# include  <cassert>
# include  <cstdlib>
# include  <cstdint>
# include  <map>
# include  <set>
# include  <vector>

# include <iostream>

static bool event_trace_enabled_()
{
      static int enabled = -1;
      if (enabled < 0) {
            const char*env = getenv("IVL_EVENT_TRACE");
            enabled = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
      }
      return enabled != 0;
}

/* Commercial event simulators commonly optimize side-effect-free
   combinational procedures as a fixed-point network, while still preserving
   ordinary procedural event/VPI semantics. Model that distinction narrowly:
   during one statically proven pure always_comb evaluation, keep other pure
   combinational waiters armed until every changed sensitivity leaf has its
   final value. Ordinary waiters, event-controlled assignments, signal
   storage, and VPI callbacks are untouched.

   Event-or cascades carry no value of their own. A synchronous token around
   the originating anyedge delivery therefore follows the cascade and records
   which leaf caused each retained waiter head to trigger. */
struct pure_comb_change_s {
      vvp_vector4_t initial;
      vvp_vector4_t final;
};

static vthread_t pure_comb_source_ = 0;
static const void*pure_comb_origin_ = 0;
static std::map<const void*, pure_comb_change_s> pure_comb_changes_;
static std::map<vthread_t*, std::set<const void*> > pure_comb_wait_heads_;
static std::vector<vthread_t*> pure_comb_wait_order_;

static void pure_comb_clear_(bool wake_waiters)
{
      /* Clear the source before scheduling: a woken process must begin a new
	 transaction, never inherit the interrupted source's journal. */
      pure_comb_source_ = 0;
      pure_comb_origin_ = 0;
      if (wake_waiters && !schedule_finished())
	    for (std::vector<vthread_t*>::const_iterator head =
		       pure_comb_wait_order_.begin();
		 head != pure_comb_wait_order_.end(); ++head)
		  if (*head && **head)
			vthread_schedule_pure_comb_waiters(**head);
      pure_comb_wait_order_.clear();
      pure_comb_wait_heads_.clear();
      pure_comb_changes_.clear();
}

void vvp_pure_comb_evaluation_begin(vthread_t source)
{
      assert(source);
      assert(pure_comb_source_ == 0);
      assert(pure_comb_origin_ == 0);
      assert(pure_comb_changes_.empty());
      assert(pure_comb_wait_heads_.empty());
      assert(pure_comb_wait_order_.empty());
      pure_comb_source_ = source;
}

static void pure_comb_commit_()
{
      /* Scheduling does not execute a waiter synchronously. Clear the active
	 source first so the next process starts a distinct transaction. */
      pure_comb_source_ = 0;
      pure_comb_origin_ = 0;

      for (std::vector<vthread_t*>::const_iterator ordered_head =
		 pure_comb_wait_order_.begin();
	   ordered_head != pure_comb_wait_order_.end(); ++ordered_head) {
	    std::map<vthread_t*, std::set<const void*> >::const_iterator head =
		  pure_comb_wait_heads_.find(*ordered_head);
	    assert(head != pure_comb_wait_heads_.end());
	    bool final_change = false;
	    for (std::set<const void*>::const_iterator origin = head->second.begin();
		 origin != head->second.end(); ++origin) {
		  std::map<const void*, pure_comb_change_s>::const_iterator change =
			pure_comb_changes_.find(*origin);
		  assert(change != pure_comb_changes_.end());
		  if (!change->second.initial.eeq(change->second.final)) {
			final_change = true;
			break;
		  }
	    }
	    if (final_change && head->first)
		  vthread_schedule_pure_comb_waiters(*head->first);
      }

      pure_comb_wait_order_.clear();
      pure_comb_wait_heads_.clear();
      pure_comb_changes_.clear();
}

void vvp_pure_comb_evaluation_end(vthread_t source)
{
      /* A synchronous VPI finish/disable can close the transaction before
	 control reaches the compiler-emitted end marker. */
      if (!pure_comb_source_) {
	    assert(pure_comb_origin_ == 0);
	    assert(pure_comb_changes_.empty());
	    assert(pure_comb_wait_heads_.empty());
	    assert(pure_comb_wait_order_.empty());
	    return;
      }
      assert(source && pure_comb_source_ == source);
      assert(pure_comb_origin_ == 0);
      pure_comb_commit_();
}

void vvp_pure_comb_evaluation_abort(vthread_t source)
{
      if (pure_comb_source_ != source)
	    return;
      pure_comb_clear_(true);
}

void vvp_pure_comb_evaluation_finish(void)
{
      if (!pure_comb_source_)
	    return;

      /* vpiFinish may be called synchronously from a value-change callback,
	 while pure_comb_origin_ still names the transition whose delivery is on
	 the C++ stack. The values already recorded in the journal are the final
	 observable values at the finish boundary. Commit their net changes and
	 release the corresponding pre-finish waiters before the scheduler closes;
	 the transition guard restores a null origin when that callback unwinds. */
      pure_comb_commit_();
}

bool vvp_pure_comb_evaluation_active(vthread_t source)
{
      return source && pure_comb_source_ == source;
}

void vvp_pure_comb_evaluation_discard(void)
{
      if (!pure_comb_source_)
	    return;
      pure_comb_clear_(false);
}

class pure_comb_transition_guard_s {
    public:
      pure_comb_transition_guard_s(const void*origin,
				   const vvp_vector4_t&before,
				   const vvp_vector4_t&after)
	    : active_(pure_comb_source_ != 0), saved_(pure_comb_origin_)
      {
	    if (!active_)
		  return;
	    assert(origin);
	    std::map<const void*, pure_comb_change_s>::iterator found =
		  pure_comb_changes_.find(origin);
	    if (found == pure_comb_changes_.end()) {
		  pure_comb_change_s change;
		  change.initial = before;
		  change.final = after;
		  pure_comb_changes_[origin] = change;
	    } else {
		  found->second.final = after;
	    }
	    pure_comb_origin_ = origin;
      }

      ~pure_comb_transition_guard_s()
      {
	    if (active_)
		  pure_comb_origin_ = pure_comb_source_ ? saved_ : 0;
      }

    private:
      bool active_;
      const void*saved_;
};

static vvp_context_t recover_automatic_event_context_(vvp_context_t context,
                                                      __vpiScope*scope,
                                                      const char*where)
{
      static bool warned_missing = false;
      static bool warned_scoped = false;

      if (!scope)
            return context;

      vvp_context_t resolved = vthread_recover_context_for_scope(context, scope);
      if (!context && resolved)
            ctx_stats_bump("recv-ev.missing-recovered");
      else if (context && resolved && context != resolved)
            ctx_stats_bump("recv-ev.mismatch-repaired");
      if (auto_ctx_warn_enabled()) {
            if (!warned_missing && !context && resolved) {
                  fprintf(stderr,
                          "Warning: recovered missing automatic event context during %s"
                          " (further similar warnings suppressed)\n",
                          where ? where : "<unknown>");
                  warned_missing = true;
            }
            if (!warned_scoped && context && resolved && context != resolved) {
                  fprintf(stderr,
                          "Warning: repaired automatic event context scope mismatch during %s"
                          " (further similar warnings suppressed)\n",
                          where ? where : "<unknown>");
                  warned_scoped = true;
            }
      }
      return resolved;
}

void waitable_hooks_s::run_waiting_threads_(vthread_t&threads)
{
	// Run the non-blocking event controls.
      last = &event_ctls;
      for (evctl*cur = event_ctls; cur != 0;) {
	    if (cur->dec_and_run()) {
		  evctl*nxt = cur->next;
		  delete cur;
		  cur = nxt;
		  *last = cur;
	    } else {
		  last = &(cur->next);
		  cur = cur->next;
	    }
	      }

	/* A transition token exists only while a proven-pure combinational
	   source is synchronously propagating one sensitivity-leaf change.
	   Wake ordinary observers now, retain pure combinational consumers,
	   and let the source evaluation's end decide whether their inputs have
	   a net final change. */
      if (pure_comb_source_ && pure_comb_origin_) {
	    if (vthread_schedule_non_pure_comb_waiters(threads)) {
		  std::map<vthread_t*, std::set<const void*> >::iterator found =
			pure_comb_wait_heads_.find(&threads);
		  if (found == pure_comb_wait_heads_.end()) {
			pure_comb_wait_order_.push_back(&threads);
			found = pure_comb_wait_heads_
			      .insert(std::make_pair(
				    &threads, std::set<const void*>())).first;
		  }
		  found->second.insert(pure_comb_origin_);
	    }
	    return;
      }

	/* Before $finish, wake the whole list. During the finishing slot,
	   wake only processes whose event control was armed before $finish;
	   a process that completes and re-arms after $finish remains parked.
	   This drains already-scheduled work without allowing it to respawn. */
      vthread_schedule_event_waiters(threads);
}

evctl::evctl(unsigned long ecount)
{
      ecount_ = ecount;
      next = 0;
}

bool evctl::dec_and_run()
{
      assert(ecount_ != 0);

      ecount_ -= 1;
      if (ecount_ == 0) run_run();

      return ecount_ == 0;
}

evctl_real::evctl_real(__vpiHandle*handle, double value,
                       unsigned long ecount)
:evctl(ecount)
{
      handle_ = handle;
      value_ = value;
}

void evctl_real::run_run()
{
      t_vpi_value val;

      val.format = vpiRealVal;
      val.value.real = value_;
      vpi_put_value(handle_, &val, 0, vpiNoDelay);
}

void schedule_evctl(__vpiHandle*handle, double value,
                    vvp_net_t*event, unsigned long ecount)
{
	// Get the functor we are going to wait on.
      waitable_hooks_s*ep = dynamic_cast<waitable_hooks_s*> (event->fun);
      assert(ep);
	// Now add this call to the end of the event list.
      *(ep->last) = new evctl_real(handle, value, ecount);
      ep->last = &((*(ep->last))->next);
}

evctl_vector::evctl_vector(vvp_net_ptr_t ptr, const vvp_vector4_t&value,
                           unsigned off, unsigned wid, unsigned long ecount)
:evctl(ecount), ptr_(ptr), value_(value)
{
      off_ = off;
      wid_ = wid;
}

void evctl_vector::run_run()
{
      if (wid_ != 0) {
	    vvp_send_vec4_pv(ptr_, value_, off_, wid_, 0);
      } else {
	    vvp_send_vec4(ptr_, value_, 0);
      }
}

void schedule_evctl(vvp_net_ptr_t ptr, const vvp_vector4_t&value,
                    unsigned offset, unsigned wid,
                    vvp_net_t*event, unsigned long ecount)
{
	// Get the functor we are going to wait on.
      waitable_hooks_s*ep = dynamic_cast<waitable_hooks_s*> (event->fun);
      assert(ep);
	// Now add this call to the end of the event list.
      *(ep->last) = new evctl_vector(ptr, value, offset, wid, ecount);
      ep->last = &((*(ep->last))->next);
}

evctl_array::evctl_array(vvp_array_t memory, unsigned index,
                         const vvp_vector4_t&value, unsigned off,
                         unsigned long ecount)
:evctl(ecount), value_(value)
{
      mem_ = memory;
      idx_ = index;
      off_ = off;
}

void evctl_array::run_run()
{
      mem_->set_word(idx_, off_, value_);
}

void schedule_evctl(vvp_array_t memory, unsigned index,
                    const vvp_vector4_t&value, unsigned offset,
                    vvp_net_t*event, unsigned long ecount)
{
	// Get the functor we are going to wait on.
      waitable_hooks_s*ep = dynamic_cast<waitable_hooks_s*> (event->fun);
      assert(ep);
	// Now add this call to the end of the event list.
      *(ep->last) = new evctl_array(memory, index, value, offset, ecount);
      ep->last = &((*(ep->last))->next);
}

evctl_array_r::evctl_array_r(vvp_array_t memory, unsigned index,
                             double value, unsigned long ecount)
:evctl(ecount)
{
      mem_ = memory;
      idx_ = index;
      value_ = value;
}

void evctl_array_r::run_run()
{
      mem_->set_word(idx_, value_);
}

void schedule_evctl(vvp_array_t memory, unsigned index,
                    double value,
                    vvp_net_t*event, unsigned long ecount)
{
	// Get the functor we are going to wait on.
      waitable_hooks_s*ep = dynamic_cast<waitable_hooks_s*> (event->fun);
      assert(ep);
	// Now add this call to the end of the event list.
      *(ep->last) = new evctl_array_r(memory, index, value, ecount);
      ep->last = &((*(ep->last))->next);
}

inline vvp_fun_edge::edge_t VVP_EDGE(vvp_bit4_t from, vvp_bit4_t to)
{
      return 1 << ((from << 2) | to);
}

const vvp_fun_edge::edge_t vvp_edge_posedge
      = VVP_EDGE(BIT4_0,BIT4_1)
      | VVP_EDGE(BIT4_0,BIT4_X)
      | VVP_EDGE(BIT4_0,BIT4_Z)
      | VVP_EDGE(BIT4_X,BIT4_1)
      | VVP_EDGE(BIT4_Z,BIT4_1)
      ;

const vvp_fun_edge::edge_t vvp_edge_negedge
      = VVP_EDGE(BIT4_1,BIT4_0)
      | VVP_EDGE(BIT4_1,BIT4_X)
      | VVP_EDGE(BIT4_1,BIT4_Z)
      | VVP_EDGE(BIT4_X,BIT4_0)
      | VVP_EDGE(BIT4_Z,BIT4_0)
      ;

const vvp_fun_edge::edge_t vvp_edge_edge
      = VVP_EDGE(BIT4_0,BIT4_1)
      | VVP_EDGE(BIT4_1,BIT4_0)
      | VVP_EDGE(BIT4_0,BIT4_X)
      | VVP_EDGE(BIT4_X,BIT4_0)
      | VVP_EDGE(BIT4_0,BIT4_Z)
      | VVP_EDGE(BIT4_Z,BIT4_0)
      | VVP_EDGE(BIT4_X,BIT4_1)
      | VVP_EDGE(BIT4_1,BIT4_X)
      | VVP_EDGE(BIT4_Z,BIT4_1)
      | VVP_EDGE(BIT4_1,BIT4_Z)
      ;

const vvp_fun_edge::edge_t vvp_edge_none    = 0;

struct vvp_fun_edge_state_s : public waitable_state_s {
      vvp_fun_edge_state_s()
      {
            for (unsigned idx = 0 ;  idx < 4 ;  idx += 1)
                  bits[idx] = BIT4_X;
      }

      vvp_bit4_t bits[4];
};

vvp_fun_edge::vvp_fun_edge(edge_t e)
: edge_(e)
{
      for (unsigned idx = 0 ;  idx < 4 ;  idx += 1)
            bits_[idx] = BIT4_X;
}

vvp_fun_edge::~vvp_fun_edge()
{
}

bool vvp_fun_edge::recv_vec4_(const vvp_vector4_t&bit,
                              vvp_bit4_t&old_bit, vthread_t&threads)
{
	/* See what kind of edge this represents. */
      edge_t mask = VVP_EDGE(old_bit, bit.value(0));

	/* Save the current input for the next time around. */
      old_bit = bit.value(0);

      if ((edge_ == vvp_edge_none) || (edge_ & mask)) {
	    run_waiting_threads_(threads);
            return true;
      }
      return false;
}

static std::map<vthread_t, std::set<vvp_fun_edge_sa*> >
      vif_multi_wait_edges_;

vvp_fun_edge_sa::vvp_fun_edge_sa(edge_t e)
: vvp_fun_edge(e), threads_(0)
{
}

vvp_fun_edge_sa::~vvp_fun_edge_sa()
{
      for (std::set<vthread_t>::const_iterator cur = multi_threads_.begin();
           cur != multi_threads_.end(); ++cur) {
            std::map<vthread_t, std::set<vvp_fun_edge_sa*> >::iterator found =
                  vif_multi_wait_edges_.find(*cur);
            if (found == vif_multi_wait_edges_.end())
                  continue;
            found->second.erase(this);
            if (found->second.empty())
                  vif_multi_wait_edges_.erase(found);
      }
}

vthread_t vvp_fun_edge_sa::add_waiting_thread(vthread_t thread)
{
      return vthread_add_event_wait(thread, &threads_);
}

void vvp_fun_edge_sa::add_multi_waiting_thread(vthread_t thread)
{
      if (!thread)
            return;
      multi_threads_.insert(thread);
      vif_multi_wait_edges_[thread].insert(this);
}

void vvp_fun_edge_sa::run_multi_waiting_threads_()
{
      std::set<vthread_t>waiters;
      waiters.swap(multi_threads_);
      for (std::set<vthread_t>::const_iterator cur = waiters.begin();
           cur != waiters.end(); ++cur) {
            vthread_t thread = *cur;
            std::map<vthread_t, std::set<vvp_fun_edge_sa*> >::iterator found =
                  vif_multi_wait_edges_.find(thread);
            if (found != vif_multi_wait_edges_.end()) {
                  std::set<vvp_fun_edge_sa*> siblings = found->second;
                  vif_multi_wait_edges_.erase(found);
                  for (std::set<vvp_fun_edge_sa*>::const_iterator edge =
                       siblings.begin(); edge != siblings.end(); ++edge)
                        (*edge)->multi_threads_.erase(thread);
            }
            vthread_schedule_mutation_waiter(thread);
      }
}

void vvp_fun_edge_sa::recv_vec4(vvp_net_ptr_t port, const vvp_vector4_t&bit,
                                vvp_context_t)
{
      if (recv_vec4_(bit, bits_[port.port()], threads_)) {
	    run_multi_waiting_threads_();
	    vvp_net_t*net = port.ptr();
	    net->send_vec4(bit, 0);
      }
}

void vvp_fun_edge_sa::recv_vec4_pv(vvp_net_ptr_t port, const vvp_vector4_t&bit,
				   unsigned base, unsigned vwid, vvp_context_t)
{
      assert(base == 0);
      if (recv_vec4_(bit, bits_[port.port()], threads_)) {
	    run_multi_waiting_threads_();
	    vvp_net_t*net = port.ptr();
	    net->send_vec4_pv(bit, base, vwid, 0);
      }
}

vvp_fun_edge_aa::vvp_fun_edge_aa(edge_t e)
: vvp_fun_edge(e)
{
      context_scope_ = vpip_peek_context_scope();
      context_idx_ = vpip_add_item_to_context(this, context_scope_);
}

vvp_fun_edge_aa::~vvp_fun_edge_aa()
{
}

void vvp_fun_edge_aa::alloc_instance(vvp_context_t context)
{
      vvp_set_context_item(context, context_idx_, new vvp_fun_edge_state_s);
      reset_instance(context);
}

void vvp_fun_edge_aa::reset_instance(vvp_context_t context)
{
      vvp_fun_edge_state_s*state = static_cast<vvp_fun_edge_state_s*>
            (vvp_get_context_item(context, context_idx_));

      assert(state->threads == 0);
      state->threads = 0;
      for (unsigned idx = 0 ;  idx < 4 ;  idx += 1)
            state->bits[idx] = bits_[idx];
}

#ifdef CHECK_WITH_VALGRIND
void vvp_fun_edge_aa::free_instance(vvp_context_t context)
{
      vvp_fun_edge_state_s*state = static_cast<vvp_fun_edge_state_s*>
            (vvp_get_context_item(context, context_idx_));
      delete state;
}
#endif

vthread_t vvp_fun_edge_aa::add_waiting_thread(vthread_t thread)
{
      vvp_fun_edge_state_s*state = static_cast<vvp_fun_edge_state_s*>
            (vthread_get_wt_context_item(context_idx_));

      return vthread_add_event_wait(thread, &state->threads);
}

void vvp_fun_edge_aa::recv_object(vvp_net_ptr_t, vvp_object_t, vvp_context_t)
{
      // Silently ignore object values on automatic edge events.
}

void vvp_fun_edge_aa::recv_vec4(vvp_net_ptr_t port, const vvp_vector4_t&bit,
                                vvp_context_t context)
{
	/* Only accept a context that is a live frame of this probe's
	   scope (a native delivery). Nil or foreign contexts (static
	   sources, cross-scope notifications) take the per-context
	   fanout below, where each frame's state decides
	   independently. (The former recover step never repaired
	   anything here per the 2026-07 engagement census; misses
	   always fell through to the fanout.) */
      if (!(context && vthread_context_live_matches_scope(context, context_scope_)))
	    context = 0;
      if (context) {
            vvp_fun_edge_state_s*state = static_cast<vvp_fun_edge_state_s*>
                  (vvp_get_context_item(context, context_idx_));

            if (recv_vec4_(bit, state->bits[port.port()], state->threads)) {
                  vvp_net_t*net = port.ptr();
                  net->send_vec4(bit, context);
            }
      } else {
            context = context_scope_->live_contexts;
            while (context) {
                  recv_vec4(port, bit, context);
                  context = vvp_get_next_context(context);
            }
            bits_[port.port()] = bit.value(0);
      }
}

class anyedge_value {

    public:
      anyedge_value() {};
      virtual ~anyedge_value() {};

      virtual void reset() = 0;

      virtual void duplicate(anyedge_value*&dup) = 0;
};

class anyedge_vec4_value : public anyedge_value {

    public:
      anyedge_vec4_value() {};
      virtual ~anyedge_vec4_value() override {};

      void reset() override { old_bits.set_to_x(); }

      void set(const vvp_vector4_t&bit) { old_bits = bit; };

      void duplicate(anyedge_value*&dup) override;

      bool recv_vec4(const vvp_vector4_t&bit,
		     vvp_vector4_t*previous = 0);

      bool recv_vec4_pv(const vvp_vector4_t&bit, unsigned base,
			unsigned vwid, vvp_vector4_t*previous = 0);

      const vvp_vector4_t&current() const { return old_bits; }

    private:
      vvp_vector4_t old_bits;
};

static anyedge_vec4_value*get_vec4_value(anyedge_value*&value)
{
      anyedge_vec4_value*vec4_value = dynamic_cast<anyedge_vec4_value*>(value);
      if (!value) {
	    vec4_value = new anyedge_vec4_value();
	    delete value;
	    value = vec4_value;
      }
      return vec4_value;
}

class anyedge_real_value : public anyedge_value {

    public:
      anyedge_real_value() : old_bits(0.0) {};
      virtual ~anyedge_real_value() override {};

      void reset() override { old_bits = 0.0; }

      void set(double bit) { old_bits = bit; };

      void duplicate(anyedge_value*&dup) override;

      bool recv_real(double bit);

    private:
      double old_bits;
};

static anyedge_real_value*get_real_value(anyedge_value*&value)
{
      anyedge_real_value*real_value = dynamic_cast<anyedge_real_value*>(value);
      if (!value) {
	    real_value = new anyedge_real_value();
	    delete value;
	    value = real_value;
      }
      return real_value;
}

class anyedge_string_value : public anyedge_value {

    public:
      anyedge_string_value() {};
      virtual ~anyedge_string_value() override {};

      void reset() override { old_bits.clear(); }

      void set(const std::string&bit) { old_bits = bit; };

      void duplicate(anyedge_value*&dup) override;

      bool recv_string(const std::string&bit);

    private:
      std::string old_bits;
};

static anyedge_string_value*get_string_value(anyedge_value*&value)
{
      anyedge_string_value*string_value = dynamic_cast<anyedge_string_value*>(value);
      if (!value) {
	    string_value = new anyedge_string_value();
	    delete value;
	    value = string_value;
      }
      return string_value;
}

class anyedge_object_value : public anyedge_value {

    public:
      anyedge_object_value() {}
      virtual ~anyedge_object_value() override {}

      void reset() override { old_bits_ = vvp_object_t(); }
      void set(const vvp_object_t&bit) { old_bits_ = bit; }
      void duplicate(anyedge_value*&dup) override;
      bool recv_object(const vvp_object_t&bit);

    private:
      vvp_object_t old_bits_;
};

static anyedge_object_value*get_object_value(anyedge_value*&value)
{
      anyedge_object_value*object_value =
            dynamic_cast<anyedge_object_value*>(value);
      if (!value) {
            object_value = new anyedge_object_value();
            value = object_value;
      }
      return object_value;
}

struct vvp_fun_anyedge_state_s : public waitable_state_s {
      vvp_fun_anyedge_state_s()
      {
            for (unsigned idx = 0 ;  idx < 4 ;  idx += 1)
                  last_value_[idx] = 0;
      }

      ~vvp_fun_anyedge_state_s()
      {
            for (unsigned idx = 0 ;  idx < 4 ;  idx += 1)
                  delete last_value_[idx];
      }

      anyedge_value *last_value_[4];
};

vvp_fun_anyedge::vvp_fun_anyedge(bool object_handle_change)
: object_handle_change_(object_handle_change)
{
      for (unsigned idx = 0 ;  idx < 4 ;  idx += 1)
	    last_value_[idx] = 0;
}

vvp_fun_anyedge::~vvp_fun_anyedge()
{
      for (unsigned idx = 0 ;  idx < 4 ;  idx += 1)
	    delete last_value_[idx];
}

void anyedge_vec4_value::duplicate(anyedge_value*&dup)
{
      anyedge_vec4_value*dup_vec4 = get_vec4_value(dup);
      assert(dup_vec4);
      dup_vec4->set(old_bits);
}

bool anyedge_vec4_value::recv_vec4(const vvp_vector4_t&bit,
				   vvp_vector4_t*previous)
{
      bool flag = false;

      if (old_bits.size() != bit.size()) {
	    if (old_bits.size() == 0) {
		    // Special case: If we've not seen any input yet
		    // (old_bits.size()==0) then replace it will a reference
		    // vector that is 'bx. Then compare that with the input
		    // to see if we are processing a change from 'bx.
		  old_bits = vvp_vector4_t(bit.size(), BIT4_X);
		  if (old_bits.eeq(bit))
			flag = false;
		  else
			flag = true;

	    } else {
		  flag = true;
	    }

      } else {
	    for (unsigned idx = 0 ;  idx < bit.size() ;  idx += 1) {
		  if (old_bits.value(idx) != bit.value(idx)) {
			flag = true;
			break;
		  }
	    }
      }

      if (flag) {
	    if (previous)
		  *previous = old_bits;
	    old_bits = bit;
      }

      return flag;
}

bool anyedge_vec4_value::recv_vec4_pv(const vvp_vector4_t&bit, unsigned base,
				      unsigned vwid,
				      vvp_vector4_t*previous)
{
      vvp_vector4_t tmp = old_bits;
      if (tmp.size() == 0)
	    tmp = vvp_vector4_t(vwid, BIT4_Z);
      assert(base + bit.size()<= vwid);
      assert(tmp.size() == vwid);
      tmp.set_vec(base, bit);

      return recv_vec4(tmp, previous);
}

void anyedge_real_value::duplicate(anyedge_value*&dup)
{
      anyedge_real_value*dup_real = get_real_value(dup);
      assert(dup_real);
      dup_real->set(old_bits);
}

bool anyedge_real_value::recv_real(double bit)
{
      if (old_bits != bit) {
	    old_bits = bit;
            return true;
      }
      return false;
}

void anyedge_string_value::duplicate(anyedge_value*&dup)
{
      anyedge_string_value*dup_string = get_string_value(dup);
      assert(dup_string);
      dup_string->set(old_bits);
}

bool anyedge_string_value::recv_string(const std::string&bit)
{
      if (old_bits != bit) {
	    old_bits = bit;
            return true;
      }
      return false;
}

void anyedge_object_value::duplicate(anyedge_value*&dup)
{
      anyedge_object_value*dup_object = get_object_value(dup);
      assert(dup_object);
      dup_object->set(old_bits_);
}

bool anyedge_object_value::recv_object(const vvp_object_t&bit)
{
      if (old_bits_ != bit) {
            old_bits_ = bit;
            return true;
      }
      return false;
}

vvp_fun_anyedge_sa::vvp_fun_anyedge_sa(bool object_handle_change)
: vvp_fun_anyedge(object_handle_change), threads_(0)
{
}

static std::map<vthread_t, std::set<vvp_fun_anyedge_sa*> >
      vif_multi_wait_anyedges_;

vvp_fun_anyedge_sa::~vvp_fun_anyedge_sa()
{
      for (std::set<vthread_t>::const_iterator cur = multi_threads_.begin();
           cur != multi_threads_.end(); ++cur) {
            std::map<vthread_t, std::set<vvp_fun_anyedge_sa*> >::iterator found =
                  vif_multi_wait_anyedges_.find(*cur);
            if (found == vif_multi_wait_anyedges_.end())
                  continue;
            found->second.erase(this);
            if (found->second.empty())
                  vif_multi_wait_anyedges_.erase(found);
      }
}

vthread_t vvp_fun_anyedge_sa::add_waiting_thread(vthread_t thread)
{
      return vthread_add_event_wait(thread, &threads_);
}

void vvp_fun_anyedge_sa::add_multi_waiting_thread(vthread_t thread)
{
      if (!thread)
            return;
      multi_threads_.insert(thread);
      vif_multi_wait_anyedges_[thread].insert(this);
}

bool vvp_cancel_multi_waiting_thread(vthread_t thread)
{
      if (!thread)
            return false;

      bool removed = false;
      std::map<vthread_t, std::set<vvp_fun_edge_sa*> >::iterator edge_it =
            vif_multi_wait_edges_.find(thread);
      if (edge_it != vif_multi_wait_edges_.end()) {
            std::set<vvp_fun_edge_sa*> edges = edge_it->second;
            vif_multi_wait_edges_.erase(edge_it);
            for (std::set<vvp_fun_edge_sa*>::const_iterator edge = edges.begin();
                 edge != edges.end(); ++edge)
                  (*edge)->multi_threads_.erase(thread);
            removed = true;
      }

      std::map<vthread_t, std::set<vvp_fun_anyedge_sa*> >::iterator any_it =
            vif_multi_wait_anyedges_.find(thread);
      if (any_it != vif_multi_wait_anyedges_.end()) {
            std::set<vvp_fun_anyedge_sa*> edges = any_it->second;
            vif_multi_wait_anyedges_.erase(any_it);
            for (std::set<vvp_fun_anyedge_sa*>::const_iterator edge =
                       edges.begin(); edge != edges.end(); ++edge)
                  (*edge)->multi_threads_.erase(thread);
            removed = true;
      }

      return removed;
}

void vvp_fun_anyedge_sa::run_multi_waiting_threads_()
{
      std::set<vthread_t>waiters;
      waiters.swap(multi_threads_);
      for (std::set<vthread_t>::const_iterator cur = waiters.begin();
           cur != waiters.end(); ++cur) {
            vthread_t thread = *cur;
            std::map<vthread_t, std::set<vvp_fun_anyedge_sa*> >::iterator found =
                  vif_multi_wait_anyedges_.find(thread);
            if (found != vif_multi_wait_anyedges_.end()) {
                  std::set<vvp_fun_anyedge_sa*> siblings = found->second;
                  vif_multi_wait_anyedges_.erase(found);
                  for (std::set<vvp_fun_anyedge_sa*>::const_iterator edge =
                       siblings.begin(); edge != siblings.end(); ++edge)
                        (*edge)->multi_threads_.erase(thread);
            }
            vthread_schedule_mutation_waiter(thread);
      }
}

void vvp_fun_anyedge_sa::recv_vec4(vvp_net_ptr_t port, const vvp_vector4_t&bit,
                                   vvp_context_t)
{
      anyedge_vec4_value*value = get_vec4_value(last_value_[port.port()]);
      assert(value);
	  vvp_vector4_t previous;
      if (value->recv_vec4(bit, &previous)) {
	    pure_comb_transition_guard_s transition(value, previous,
						 value->current());
	    run_waiting_threads_(threads_);
	    run_multi_waiting_threads_();
	    vvp_net_t*net = port.ptr();
	    net->send_vec4(bit, 0);
      }
}

void vvp_fun_anyedge_sa::recv_vec4_pv(vvp_net_ptr_t port, const vvp_vector4_t&bit,
				      unsigned base, unsigned vwid, vvp_context_t)
{
      anyedge_vec4_value*value = get_vec4_value(last_value_[port.port()]);
      assert(value);
	  vvp_vector4_t previous;
      if (value->recv_vec4_pv(bit, base, vwid, &previous)) {
	    pure_comb_transition_guard_s transition(value, previous,
						 value->current());
	    run_waiting_threads_(threads_);
	    run_multi_waiting_threads_();
	    vvp_net_t*net = port.ptr();
	    net->send_vec4(bit, 0);
      }
}

void vvp_fun_anyedge_sa::recv_real(vvp_net_ptr_t port, double bit,
                                   vvp_context_t)
{
      anyedge_real_value*value = get_real_value(last_value_[port.port()]);
      assert(value);
      if (value->recv_real(bit)) {
	    run_waiting_threads_(threads_);
	    run_multi_waiting_threads_();
	    vvp_net_t*net = port.ptr();
	    net->send_vec4(vvp_vector4_t(), 0);
      }
}

void vvp_fun_anyedge_sa::recv_string(vvp_net_ptr_t port, const std::string&bit,
				     vvp_context_t)
{
      anyedge_string_value*value = get_string_value(last_value_[port.port()]);
      assert(value);
      if (value->recv_string(bit)) {
	    run_waiting_threads_(threads_);
	    run_multi_waiting_threads_();
	    vvp_net_t*net = port.ptr();
	    net->send_vec4(vvp_vector4_t(), 0);
      }
}

/*
 * An anyedge receiving an object should do nothing with it, but should
 * trigger waiting threads.
 */
void vvp_fun_anyedge_sa::recv_object(vvp_net_ptr_t port, vvp_object_t bit,
				     vvp_context_t)
{
      if (event_trace_enabled_()) {
            fprintf(stderr, "trace anyedge-sa recv_object net=%p\n", (void*)port.ptr());
      }
      bool trigger = true;
      if (object_handle_change_) {
            anyedge_object_value*value =
                  get_object_value(last_value_[port.port()]);
            assert(value);
            trigger = value->recv_object(bit);
      }
      if (trigger) {
            run_waiting_threads_(threads_);
            run_multi_waiting_threads_();
            vvp_net_t*net = port.ptr();
            net->send_vec4(vvp_vector4_t(), 0);
      }
}

vvp_fun_anyedge_aa::vvp_fun_anyedge_aa(bool object_handle_change)
: vvp_fun_anyedge(object_handle_change)
{
      context_scope_ = vpip_peek_context_scope();
      context_idx_ = vpip_add_item_to_context(this, context_scope_);
}

vvp_fun_anyedge_aa::~vvp_fun_anyedge_aa()
{
}

void vvp_fun_anyedge_aa::alloc_instance(vvp_context_t context)
{
      vvp_set_context_item(context, context_idx_, new vvp_fun_anyedge_state_s);
      reset_instance(context);
}

void vvp_fun_anyedge_aa::reset_instance(vvp_context_t context)
{
      vvp_fun_anyedge_state_s*state = static_cast<vvp_fun_anyedge_state_s*>
            (vvp_get_context_item(context, context_idx_));

      assert(state->threads == 0);
      state->threads = 0;
      for (unsigned idx = 0 ;  idx < 4 ;  idx += 1) {
	    if (last_value_[idx])
	          last_value_[idx]->duplicate(state->last_value_[idx]);
	    else if (state->last_value_[idx])
		  state->last_value_[idx]->reset();
      }
}

#ifdef CHECK_WITH_VALGRIND
void vvp_fun_anyedge_aa::free_instance(vvp_context_t context)
{
      vvp_fun_anyedge_state_s*state = static_cast<vvp_fun_anyedge_state_s*>
            (vvp_get_context_item(context, context_idx_));
      delete state;
}
#endif

vthread_t vvp_fun_anyedge_aa::add_waiting_thread(vthread_t thread)
{
      vvp_fun_anyedge_state_s*state = static_cast<vvp_fun_anyedge_state_s*>
            (vthread_get_wt_context_item(context_idx_));

      return vthread_add_event_wait(thread, &state->threads);
}

void vvp_fun_anyedge_aa::recv_vec4(vvp_net_ptr_t port, const vvp_vector4_t&bit,
                                   vvp_context_t context)
{
      if (event_trace_enabled_()) {
            fprintf(stderr, "trace anyedge-aa recv_vec4 net=%p ctx=%p wid=%u\n",
                    (void*)port.ptr(), context, bit.size());
      }
	/* Only accept a context that is a live frame of this probe's
	   scope (a native delivery). Nil or foreign contexts (static
	   sources, cross-scope notifications) take the per-context
	   fanout below, where each frame's state decides
	   independently. (The former recover step never repaired
	   anything here per the 2026-07 engagement census; misses
	   always fell through to the fanout.) */
      if (!(context && vthread_context_live_matches_scope(context, context_scope_)))
	    context = 0;
      if (context) {
            vvp_fun_anyedge_state_s*state = static_cast<vvp_fun_anyedge_state_s*>
                  (vvp_get_context_item(context, context_idx_));

            anyedge_vec4_value*value = get_vec4_value(state->last_value_[port.port()]);
            assert(value);
            if (value->recv_vec4(bit)) {
                  run_waiting_threads_(state->threads);
                  vvp_net_t*net = port.ptr();
                  net->send_vec4(bit, context);
            }
      } else {
            context = context_scope_->live_contexts;
            while (context) {
                  recv_vec4(port, bit, context);
                  context = vvp_get_next_context(context);
            }
            anyedge_vec4_value*value = get_vec4_value(last_value_[port.port()]);
            assert(value);
            value->set(bit);
      }
}

void vvp_fun_anyedge_aa::recv_real(vvp_net_ptr_t port, double bit,
                                   vvp_context_t context)
{
      if (event_trace_enabled_()) {
            fprintf(stderr, "trace anyedge-aa recv_real net=%p ctx=%p val=%g\n",
                    (void*)port.ptr(), context, bit);
      }
	/* Only accept a context that is a live frame of this probe's
	   scope (a native delivery). Nil or foreign contexts (static
	   sources, cross-scope notifications) take the per-context
	   fanout below, where each frame's state decides
	   independently. (The former recover step never repaired
	   anything here per the 2026-07 engagement census; misses
	   always fell through to the fanout.) */
      if (!(context && vthread_context_live_matches_scope(context, context_scope_)))
	    context = 0;
      if (context) {
            vvp_fun_anyedge_state_s*state = static_cast<vvp_fun_anyedge_state_s*>
                  (vvp_get_context_item(context, context_idx_));

            anyedge_real_value*value = get_real_value(state->last_value_[port.port()]);
            assert(value);
            if (value->recv_real(bit)) {
                  run_waiting_threads_(state->threads);
                  vvp_net_t*net = port.ptr();
                  net->send_vec4(vvp_vector4_t(), context);
            }
      } else {
            context = context_scope_->live_contexts;
            while (context) {
                  recv_real(port, bit, context);
                  context = vvp_get_next_context(context);
            }
            anyedge_real_value*value = get_real_value(last_value_[port.port()]);
            assert(value);
            value->set(bit);
      }
}

void vvp_fun_anyedge_aa::recv_string(vvp_net_ptr_t port, const std::string&bit,
				     vvp_context_t context)
{
      if (event_trace_enabled_()) {
            fprintf(stderr, "trace anyedge-aa recv_string net=%p ctx=%p val=%s\n",
                    (void*)port.ptr(), context, bit.c_str());
      }
	/* Only accept a context that is a live frame of this probe's
	   scope (a native delivery). Nil or foreign contexts (static
	   sources, cross-scope notifications) take the per-context
	   fanout below, where each frame's state decides
	   independently. (The former recover step never repaired
	   anything here per the 2026-07 engagement census; misses
	   always fell through to the fanout.) */
      if (!(context && vthread_context_live_matches_scope(context, context_scope_)))
	    context = 0;
      if (context) {
            vvp_fun_anyedge_state_s*state = static_cast<vvp_fun_anyedge_state_s*>
                  (vvp_get_context_item(context, context_idx_));

            anyedge_string_value*value = get_string_value(state->last_value_[port.port()]);
            assert(value);
            if (value->recv_string(bit)) {
                  run_waiting_threads_(state->threads);
                  vvp_net_t*net = port.ptr();
                  net->send_vec4(vvp_vector4_t(), context);
            }
      } else {
            context = context_scope_->live_contexts;
            while (context) {
                  recv_string(port, bit, context);
                  context = vvp_get_next_context(context);
            }
            anyedge_string_value*value = get_string_value(last_value_[port.port()]);
            assert(value);
	    value->set(bit);
      }
}

void vvp_fun_anyedge_aa::recv_object(vvp_net_ptr_t port, vvp_object_t bit,
                                     vvp_context_t context)
{
      static bool seq_trace = (getenv("IVL_SEQ_TRACE") && *getenv("IVL_SEQ_TRACE"));
      if (event_trace_enabled_()) {
            fprintf(stderr, "trace anyedge-aa recv_object net=%p ctx=%p\n",
                    (void*)port.ptr(), context);
      }
      vvp_context_t input_context = context;
	/* Only accept the supplied context when it is a live frame of
	   THIS probe's scope (a native delivery). A foreign context is an
	   object-mutation notification relayed from another scope's
	   thread; recovering it to the first live frame of this scope
	   (the old behavior) woke only that one frame and silently missed
	   waiters in every other frame. Foreign deliveries take the
	   per-context fanout below, which wakes every frame that has
	   waiting threads. */
      if (!(context && vthread_context_live_matches_scope(context, context_scope_))) {
            if (context)
                  ctx_stats_bump("recv-anyedge-obj.foreign-fanout");
            context = 0;
      }
      if (seq_trace) {
            const char*sn = context_scope_ ? vpi_get_str(vpiFullName, context_scope_) : 0;
            fprintf(stderr,
                    "[SEQ_TRACE anyedge recv_object] net=%p scope=%s"
                    " in_ctx=%p native_ctx=%p\n",
                    (void*)port.ptr(), sn ? sn : "<null>",
                    input_context, context);
      }
      if (context) {
            vvp_fun_anyedge_state_s*state = static_cast<vvp_fun_anyedge_state_s*>
                  (vvp_get_context_item(context, context_idx_));
            if (seq_trace) {
                  fprintf(stderr,
                          "[SEQ_TRACE anyedge recv_object] ctx=%p state=%p threads=%p\n",
                          context, (void*)state, state ? (void*)state->threads : 0);
            }
            bool trigger = true;
            if (object_handle_change_) {
                  anyedge_object_value*value =
                        get_object_value(state->last_value_[port.port()]);
                  assert(value);
                  trigger = value->recv_object(bit);
            }
            if (trigger) {
                  run_waiting_threads_(state->threads);
                  vvp_net_t*net = port.ptr();
                  net->send_vec4(vvp_vector4_t(), context);
            }
      } else {
            if (seq_trace && context_scope_) {
                  int n = 0;
                  for (vvp_context_t c = context_scope_->live_contexts; c;
                       c = vvp_get_next_context(c)) n++;
                  fprintf(stderr,
                          "[SEQ_TRACE anyedge recv_object] recovery failed,"
                          " iterating %d live_contexts of scope=%s\n",
                          n, vpi_get_str(vpiFullName, context_scope_));
            }
            // Phase 61: skip per-context recursive delivery when that
            // context has no waiting threads.  vvp_fun_anyedge_aa::recv_object
            // only wakes threads; the upstream vvp_fun_signal_object_aa
            // already did the storage and downstream propagation.  Without
            // this gate, OT-class testbenches with many automatic contexts
            // per scope (deep fork chains) burned CPU walking
            // vthread_recover_context_for_scope chains for contexts with
            // no waiters, hanging smoke vseq at sim ~30us.
            //
            // Phase 61b: hoist the bounds check out of the loop.  All live
            // contexts of the same scope have the same allocation size, so
            // one malloc_usable_size check suffices for the head; subsequent
            // iterations can read context[context_idx_] directly.  This
            // eliminates K calls to malloc_usable_size per delivery.
            context = context_scope_->live_contexts;
            if (context) {
                  size_t need = ((size_t)context_idx_ + 1) * sizeof(void*);
                  if (need > vvp_malloc_usable_size(context)) {
                        // bounds-check fail (uninitialized scope); abandon
                        return;
                  }
            }
            while (context) {
                  vvp_fun_anyedge_state_s*state =
                        static_cast<vvp_fun_anyedge_state_s*>(context[context_idx_]);
                  if (object_handle_change_ && state) {
                        anyedge_object_value*value =
                              get_object_value(
                                    state->last_value_[port.port()]);
                        assert(value);
                        bool changed = value->recv_object(bit);
                        if (changed) {
                              run_waiting_threads_(state->threads);
                              vvp_net_t*net = port.ptr();
                              net->send_vec4(vvp_vector4_t(), context);
                        }
                  } else if (state && state->threads) {
                        recv_object(port, vvp_object_t(), context);
                  }
                  context = vvp_get_next_context(context);
            }
            if (object_handle_change_) {
                  anyedge_object_value*value =
                        get_object_value(last_value_[port.port()]);
                  assert(value);
                  value->set(bit);
            }
      }
}

vvp_fun_event_or::vvp_fun_event_or(vvp_net_t*base_net)
: base_net_(base_net)
{
}

vvp_fun_event_or::~vvp_fun_event_or()
{
}

vvp_fun_event_or_sa::vvp_fun_event_or_sa(vvp_net_t*base_net)
: vvp_fun_event_or(base_net), threads_(0)
{
}

vvp_fun_event_or_sa::~vvp_fun_event_or_sa()
{
}

vthread_t vvp_fun_event_or_sa::add_waiting_thread(vthread_t thread)
{
      return vthread_add_event_wait(thread, &threads_);
}

void vvp_fun_event_or_sa::recv_vec4(vvp_net_ptr_t, const vvp_vector4_t&bit,
                                    vvp_context_t)
{
      run_waiting_threads_(threads_);
      base_net_->send_vec4(bit, 0);
}

vvp_fun_event_or_aa::vvp_fun_event_or_aa(vvp_net_t*base_net)
: vvp_fun_event_or(base_net)
{
      context_scope_ = vpip_peek_context_scope();
      context_idx_ = vpip_add_item_to_context(this, context_scope_);
}

vvp_fun_event_or_aa::~vvp_fun_event_or_aa()
{
}

void vvp_fun_event_or_aa::alloc_instance(vvp_context_t context)
{
      vvp_set_context_item(context, context_idx_, new waitable_state_s);
}

void vvp_fun_event_or_aa::reset_instance(vvp_context_t context)
{
      waitable_state_s*state = static_cast<waitable_state_s*>
            (vvp_get_context_item(context, context_idx_));

      assert(state->threads == 0);
      state->threads = 0;
}

#ifdef CHECK_WITH_VALGRIND
void vvp_fun_event_or_aa::free_instance(vvp_context_t context)
{
      waitable_state_s*state = static_cast<waitable_state_s*>
            (vvp_get_context_item(context, context_idx_));
      delete state;
}
#endif

vthread_t vvp_fun_event_or_aa::add_waiting_thread(vthread_t thread)
{
      waitable_state_s*state = static_cast<waitable_state_s*>
            (vthread_get_wt_context_item(context_idx_));

      return vthread_add_event_wait(thread, &state->threads);
}

void vvp_fun_event_or_aa::recv_vec4(vvp_net_ptr_t port, const vvp_vector4_t&bit,
                                    vvp_context_t context)
{
	/* Only accept a context that is a live frame of this probe's
	   scope (a native delivery). Nil or foreign contexts (static
	   sources, cross-scope notifications) take the per-context
	   fanout below, where each frame's state decides
	   independently. (The former recover step never repaired
	   anything here per the 2026-07 engagement census; misses
	   always fell through to the fanout.) */
      if (!(context && vthread_context_live_matches_scope(context, context_scope_)))
	    context = 0;
      if (context) {
            waitable_state_s*state = static_cast<waitable_state_s*>
                  (vvp_get_context_item(context, context_idx_));

            run_waiting_threads_(state->threads);
            base_net_->send_vec4(bit, context);
      } else {
            context = context_scope_->live_contexts;
            while (context) {
                  recv_vec4(port, bit, context);
                  context = vvp_get_next_context(context);
            }
      }
}

vvp_named_event::vvp_named_event(__vpiHandle*h)
{
      handle_ = h;
}

vvp_named_event::~vvp_named_event()
{
}

vvp_named_event_sa::vvp_named_event_sa(__vpiHandle*h)
: vvp_named_event(h), threads_(0)
{
}

vvp_named_event_sa::~vvp_named_event_sa()
{
}

vthread_t vvp_named_event_sa::add_waiting_thread(vthread_t thread)
{
      return vthread_add_event_wait(thread, &threads_);
}

void vvp_named_event::note_triggered(void)
{
      last_trigger_time_ = schedule_simtime();
      ever_triggered_ = true;
}

bool vvp_named_event::triggered_now(void) const
{
      return ever_triggered_ && last_trigger_time_ == schedule_simtime();
}

void vvp_named_event_sa::recv_vec4(vvp_net_ptr_t port, const vvp_vector4_t&bit,
                                   vvp_context_t)
{
      note_triggered();
      run_waiting_threads_(threads_);
      vvp_net_t*net = port.ptr();
      net->send_vec4(bit, 0);

      __vpiNamedEvent*obj = dynamic_cast<__vpiNamedEvent*>(handle_);
      assert(obj);
      obj->run_vpi_callbacks();
}

vvp_named_event_aa::vvp_named_event_aa(__vpiHandle*h)
: vvp_named_event(h)
{
      context_scope_ = vpip_peek_context_scope();
      context_idx_ = vpip_add_item_to_context(this, context_scope_);
}

vvp_named_event_aa::~vvp_named_event_aa()
{
}

void vvp_named_event_aa::alloc_instance(vvp_context_t context)
{
      vvp_set_context_item(context, context_idx_, new waitable_state_s);
}

void vvp_named_event_aa::reset_instance(vvp_context_t context)
{
      waitable_state_s*state = static_cast<waitable_state_s*>
            (vvp_get_context_item(context, context_idx_));

      assert(state->threads == 0);
      state->threads = 0;
}

#ifdef CHECK_WITH_VALGRIND
void vvp_named_event_aa::free_instance(vvp_context_t context)
{
      waitable_state_s*state = static_cast<waitable_state_s*>
            (vvp_get_context_item(context, context_idx_));
      delete state;
}
#endif

vthread_t vvp_named_event_aa::add_waiting_thread(vthread_t thread)
{
      waitable_state_s*state = static_cast<waitable_state_s*>
            (vthread_get_wt_context_item(context_idx_));

      return vthread_add_event_wait(thread, &state->threads);
}

vvp_named_event_dyn::vvp_named_event_dyn()
: vvp_named_event(0), threads_(0)
{
}

vvp_named_event_dyn::~vvp_named_event_dyn()
{
}

vthread_t vvp_named_event_dyn::add_waiting_thread(vthread_t thread)
{
      return vthread_add_event_wait(thread, &threads_);
}

void vvp_named_event_dyn::recv_vec4(vvp_net_ptr_t, const vvp_vector4_t&,
                                    vvp_context_t)
{
      note_triggered();
      run_waiting_threads_(threads_);
	/* A per-instance dynamic event has no fanout net graph and no
	   VPI __vpiNamedEvent handle, so unlike vvp_named_event_sa there
	   is nothing to propagate to and no VPI callbacks to run. */
}

/*
 * Named-event array element storage (IEEE 1800-2017 6.20): each element
 * of an unpacked array of events (`event arr[3];`) is its own
 * independent named event. The compiler assigns each element a
 * contiguous design-global slot (NetEvent::set_event_array()); this flat
 * table maps that slot to a lazily-allocated vvp_net_t/vvp_named_event_dyn,
 * exactly like vvp_cobject::get_inst_event() does for per-instance class
 * events, but keyed globally rather than per-object (there is only ever
 * one instance of a module-level event array, so no per-object map is
 * needed). Like every other vvp_net_t, these are never individually
 * freed -- they persist for the life of the simulation.
 */
static std::vector<vvp_net_t*> event_array_slots_;

vvp_net_t* event_array_slot_net(uint32_t slot)
{
      if (slot >= event_array_slots_.size())
	    event_array_slots_.resize(slot+1, 0);

      vvp_net_t*net = event_array_slots_[slot];
      if (!net) {
	    net = new vvp_net_t;
	    net->fun = new vvp_named_event_dyn;
	    event_array_slots_[slot] = net;
      }
      return net;
}

void vvp_named_event_aa::recv_vec4(vvp_net_ptr_t port, const vvp_vector4_t&bit,
                                   vvp_context_t context)
{
      context = recover_automatic_event_context_(context, context_scope_,
                                                 "recv-named-event-aa");
      assert(context);

      waitable_state_s*state = static_cast<waitable_state_s*>
            (vvp_get_context_item(context, context_idx_));

      note_triggered();
      run_waiting_threads_(state->threads);
      vvp_net_t*net = port.ptr();
      net->send_vec4(bit, context);
}

/*
**  Create an event functor
**  edge:  compile_event(label, type, argc, argv, debug_flag)
**  or:    compile_event(label, NULL, argc, argv, debug_flag)
**
**  Named events are handled elsewhere.
*/

static void compile_event_or(char*label, unsigned argc, struct symb_s*argv);

void compile_event(char*label, char*type, unsigned argc, struct symb_s*argv)
{
      vvp_net_fun_t*fun = 0;

      if (type == 0) {
	    compile_event_or(label, argc, argv);
	    return;
      }

      if (strcmp(type,"anyedge") == 0 || strcmp(type,"handleedge") == 0) {

            bool object_handle_change = strcmp(type,"handleedge") == 0;

	    free(type);

            if (vpip_peek_current_scope()->is_automatic()) {
                  fun = new vvp_fun_anyedge_aa(object_handle_change);
            } else {
                  fun = new vvp_fun_anyedge_sa(object_handle_change);
            }

      } else {

	    vvp_fun_edge::edge_t edge_type = vvp_edge_none;

	    if (strcmp(type,"posedge") == 0)
		  edge_type = vvp_edge_posedge;
	    else if (strcmp(type,"negedge") == 0)
		  edge_type = vvp_edge_negedge;
	    else if (strcmp(type,"edge") == 0)
		  edge_type = vvp_edge_edge;

	    assert(argc <= 4);
	    free(type);

            if (vpip_peek_current_scope()->is_automatic()) {
                  fun = new vvp_fun_edge_aa(edge_type);
            } else {
                  fun = new vvp_fun_edge_sa(edge_type);
            }

      }

      vvp_net_t* ptr = new vvp_net_t;
      ptr->fun = fun;

      define_functor_symbol(label, ptr);
      free(label);

      inputs_connect(ptr, argc, argv);
      free(argv);
}

static void compile_event_or(char*label, unsigned argc, struct symb_s*argv)
{
      vvp_net_t*base_net = new vvp_net_t;
      if (vpip_peek_current_scope()->is_automatic()) {
            base_net->fun = new vvp_fun_event_or_aa(base_net);
      } else {
            base_net->fun = new vvp_fun_event_or_sa(base_net);
      }
      define_functor_symbol(label, base_net);
      free(label);

	/* This is a simplified version of a wide functor. We don't
	   care about the data values or what port they arrived on,
	   so we can use a single shared functor. */
      vvp_net_t*curr_net = base_net;
      for (unsigned idx = 0 ;  idx < argc ;  idx += 1) {
	    if (idx > 0 && (idx % 4) == 0) {
		  curr_net = new vvp_net_t;
		  curr_net->fun = base_net->fun;
	    }
	    input_connect(curr_net, idx % 4, argv[idx].text);
      }
      free(argv);
}

/*
 * This handles the compile of named events. This functor has no
 * inputs, it is only accessed by behavioral trigger statements, which
 * in vvp are %set instructions.
 */
void compile_named_event(char*label, char*name, bool local_flag)
{
      vvp_net_t*ptr = new vvp_net_t;

      vpiHandle obj = vpip_make_named_event(name, ptr);

      if (vpip_peek_current_scope()->is_automatic()) {
            ptr->fun = new vvp_named_event_aa(obj);
      } else {
            ptr->fun = new vvp_named_event_sa(obj);
      }
      define_functor_symbol(label, ptr);
      compile_vpi_symbol(label, obj);
      if (! local_flag) vpip_attach_to_current_scope(obj);

      free(label);
      delete[] name;
}

#ifdef CHECK_WITH_VALGRIND
void named_event_delete(__vpiHandle*handle)
{
      delete dynamic_cast<__vpiNamedEvent *>(handle);
}
#endif
