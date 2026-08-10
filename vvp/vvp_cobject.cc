/*
 * Copyright (c) 2012-2013 Stephen Williams (steve@icarus.com)
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

# include  "vvp_cobject.h"
# include  "class_type.h"
# include  "vvp_net.h"
# include  "event.h"
# include  <iostream>
# include  <cassert>
# include  <cstdio>

using namespace std;

vvp_cobject::vvp_cobject(const class_type*defn)
: defn_(defn), properties_(defn->instance_new()),
  rand_mode_(defn->property_count(), true),
  constraint_mode_(defn->constraint_count(), true)
{
	// M11-3: covergroup instances with a declaration sampling
	// event register so %covgrp/sample/all can walk them.
      if (defn->covgrp_parent_prop() >= 0)
	    defn->covgrp_live_add(this);
}

/*
 * M3B-5 (IEEE 1800-2017 18.13): the object's own RNG.
 *
 * xorshift64* -- one 64-bit word of state, so get_randstate() is just
 * that word printed, and set_randstate() reads it back exactly. 18.13.3
 * leaves the string's contents implementation-defined; it only has to
 * round-trip through this implementation, which the tagged prefix below
 * lets us check.
 */
static const char rng_state_tag[] = "ivl1:";

void vvp_cobject::rng_srandom(int32_t seed)
{
	// A zero state is the one xorshift64* fixed point (it would emit
	// only zeroes), and srandom(0) is perfectly legal, so fold the seed
	// through splitmix64 first. That also spreads adjacent seeds --
	// srandom(1) and srandom(2) must not give correlated streams.
      uint64_t z = (uint64_t)(uint32_t)seed + 0x9E3779B97F4A7C15ull;
      z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ull;
      z = (z ^ (z >> 27)) * 0x94D049BB133111EBull;
      z = z ^ (z >> 31);
      rng_state_ = z ? z : 0x9E3779B97F4A7C15ull;
      rng_seeded_ = true;
}

uint32_t vvp_cobject::rng_next()
{
      if (! rng_seeded_)
	    rng_srandom(0);
      uint64_t x = rng_state_;
      x ^= x >> 12;
      x ^= x << 25;
      x ^= x >> 27;
      rng_state_ = x;
      return (uint32_t)((x * 0x2545F4914F6CDD1Dull) >> 32);
}

std::string vvp_cobject::rng_get_state() const
{
      char buf[32];
	// Report the state even if the object has never been seeded, so
	// get_randstate() then set_randstate() round-trips either way.
      uint64_t st = rng_seeded_ ? rng_state_ : 0;
      snprintf(buf, sizeof buf, "%s%016llx", rng_state_tag,
	       (unsigned long long)st);
      return std::string(buf);
}

bool vvp_cobject::rng_set_state(const std::string&state)
{
      size_t tag_len = sizeof rng_state_tag - 1;
      if (state.compare(0, tag_len, rng_state_tag) != 0)
	    return false;

      uint64_t st = 0;
      if (sscanf(state.c_str() + tag_len, "%16llx",
		 (unsigned long long*)&st) != 1)
	    return false;

	// A state of 0 means "was never seeded" (see rng_get_state), so
	// restoring it puts the object back in that state rather than
	// installing the generator's fixed point.
      if (st == 0) {
	    rng_state_ = 0;
	    rng_seeded_ = false;
	    return true;
      }
      rng_state_ = st;
      rng_seeded_ = true;
      return true;
}

bool vvp_cobject::rand_mode(size_t pid) const
{
      if (pid < defn_->property_count() && defn_->property_is_static(pid))
	    return defn_->static_rand_mode(pid);
      if (pid < rand_mode_.size()) return rand_mode_[pid];
      return true;
}

void vvp_cobject::set_rand_mode(size_t pid, bool mode)
{
      if (pid < defn_->property_count() && defn_->property_is_static(pid)) {
	    defn_->set_static_rand_mode(pid, mode);
	    return;
      }
      if (pid < rand_mode_.size()) rand_mode_[pid] = mode;
}

void vvp_cobject::set_all_rand_mode(bool mode)
{
      for (size_t i = 0 ; i < rand_mode_.size() ; i += 1) {
	    if (defn_->property_is_rand(i))
		  set_rand_mode(i, mode);
      }
}

bool vvp_cobject::constraint_mode(size_t cid) const
{
      if (cid < constraint_mode_.size()) return constraint_mode_[cid];
      return true;
}

void vvp_cobject::set_constraint_mode(size_t cid, bool mode)
{
      if (cid < constraint_mode_.size()) constraint_mode_[cid] = mode;
}

// R1: committed randc state and per-randomize transaction staging. Cycle
// period = 2^width, capped at
// 20 bits (a 2^20-entry, 128KB std::vector<bool> bitmap per instance --
// the old 16-bit/65536-entry cap was stale conservatism; 128KB is a
// trivial per-object cost for the guarantee of no repeat before a full
// cycle). Wider properties fall back to plain rand (period reported as
// 0); elab_sig.cc warns at compile time, by name, when that degrade
// happens -- keep this bound in sync with the literal there.
uint64_t vvp_cobject::randc_period(size_t pid) const
{
      if (pid >= defn_->property_count()) return 0;
      vvp_vector4_t probe;
      const_cast<vvp_cobject*>(this)->get_vec4(pid, probe);
      unsigned w = probe.size();
      if (w == 0 || w > 20) return 0;
      return (uint64_t)1 << w;
}

const std::vector<bool>*vvp_cobject::randc_history_find_(size_t pid) const
{
      if (pid < defn_->property_count() && defn_->property_is_static(pid))
	    return &defn_->static_randc_history(pid, 0);

      std::map<size_t, std::vector<bool> >::const_iterator it
	    = randc_history_.find(pid);
      return it == randc_history_.end() ? 0 : &it->second;
}

std::vector<bool>&vvp_cobject::randc_history_mutable_(size_t pid)
{
      if (pid < defn_->property_count() && defn_->property_is_static(pid))
	    return defn_->static_randc_history(pid, 0);
      return randc_history_[pid];
}

bool vvp_cobject::randc_history_full_(const std::vector<bool>&hist,
				      uint64_t period)
{
      if (period == 0 || hist.size() != period)
	    return false;
      for (size_t idx = 0 ; idx < hist.size() ; idx += 1)
	    if (!hist[idx]) return false;
      return true;
}

void vvp_cobject::randc_transaction_begin()
{
	// A map frame holds one final event per pid. Merging an overlapping
	// same-object randomize would silently collapse two successful calls and
	// let the outer call re-emit the inner value because randc_seen() reads
	// only committed history. Reject that latent path until an ordered event
	// log plus transaction-local history projection is implemented.
      if (!randc_transactions_.empty()) {
	    cerr << "internal error: overlapping randc transactions for class '"
		 << defn_->class_name() << "' are not supported" << endl;
	    abort();
      }
      randc_transactions_.push_back(randc_transaction_t());
}

bool vvp_cobject::randc_transaction_commit()
{
      if (randc_transactions_.empty()) {
	    cerr << "internal error: randc transaction commit without begin"
		 << endl;
	    abort();
      }

      randc_transaction_t pending = randc_transactions_.back();
      randc_transactions_.pop_back();
      assert(randc_transactions_.empty());

      struct resolved_randc_t {
	    size_t pid;
	    uint64_t period;
	    uint64_t actual;
	    randc_pending_t pending;
      };
      std::vector<resolved_randc_t> resolved;

	// Validate and capture every actual final value before changing any
	// history bank. This makes a multi-property commit atomic even if an
	// unexpected X/Z reaches a supposedly successful solver result.
      for (randc_transaction_t::const_iterator it = pending.begin();
	   it != pending.end(); ++it) {
	    uint64_t period = randc_period(it->first);
	    if (period == 0) continue;

	    vvp_vector4_t val;
	    get_vec4(it->first, val);
	    uint64_t actual = 0;
	    for (unsigned bit = 0 ; bit < val.size() ; bit += 1) {
		  vvp_bit4_t digit = val.value(bit);
		  if (digit == BIT4_1)
			actual |= (uint64_t)1 << bit;
		  else if (digit != BIT4_0) {
			cerr << "warning: successful randomize produced X/Z for randc "
			     << "property '" << defn_->property_name(it->first)
			     << "'; history transaction rolled back" << endl;
			return false;
		  }
	    }

	    resolved_randc_t item;
	    item.pid = it->first;
	    item.period = period;
	    item.actual = actual;
	    item.pending = it->second;
	    resolved.push_back(item);
      }

      for (const resolved_randc_t&item : resolved) {
	    std::vector<bool>&hist = randc_history_mutable_(item.pid);
	    if (hist.size() != item.period)
		  hist.assign((size_t)item.period, false);

	    bool reset = randc_history_full_(hist, item.period);
	    if (reset) {
		  // A completed cycle remains visibly complete until this next
		  // successful choice. Its reset and new mark commit together.
		  for (size_t idx = 0 ; idx < hist.size() ; idx += 1)
			hist[idx] = false;
	    } else if (item.pending.feasible_domain) {
		  bool any = false;
		  bool all_used = true;
		  for (uint64_t value : item.pending.feasible) {
			if (value >= item.period) continue;
			any = true;
			if (!hist[(size_t)value]) all_used = false;
		  }
		  if (any && all_used)
			for (uint64_t value : item.pending.feasible)
			      if (value < item.period)
				    hist[(size_t)value] = false;
	    }

	    if (item.actual < item.period)
		  hist[(size_t)item.actual] = true;
      }
      return true;
}

void vvp_cobject::randc_transaction_rollback()
{
      if (randc_transactions_.empty()) {
	    cerr << "internal error: randc transaction rollback without begin"
		 << endl;
	    abort();
      }
      randc_transactions_.pop_back();
}

bool vvp_cobject::randc_seen(size_t pid, uint64_t val) const
{
      uint64_t period = randc_period(pid);
      const std::vector<bool>*hist = randc_history_find_(pid);
      if (!hist || val >= hist->size()) return false;
	// Exhaustion is a logical new-cycle view, not a mutation. If the
	// ensuing solve fails, the committed completed cycle stays intact.
      if (randc_history_full_(*hist, period)) return false;
      return (*hist)[(size_t)val];
}

void vvp_cobject::randc_mark(size_t pid, uint64_t val)
{
      uint64_t period = randc_period(pid);
      if (period == 0) return;
      if (val >= period) return;
      if (randc_transactions_.empty()) {
	    cerr << "internal error: randc mark outside randomize transaction"
		 << endl;
	    abort();
      }
      randc_pending_t staged;
      staged.staged_value = val;
      randc_transactions_.back()[pid] = staged;
}

// RANDOM-DIST fix #4: see the declaration in vvp_cobject.h.
void vvp_cobject::randc_mark_feasible(size_t pid, uint64_t val,
                                       const std::vector<uint64_t>&feasible)
{
      uint64_t period = randc_period(pid);
      if (period == 0) return;
      if (val >= period) return;
      if (randc_transactions_.empty()) {
	    cerr << "internal error: constrained randc mark outside randomize "
		 << "transaction" << endl;
	    abort();
      }
      randc_pending_t staged;
      staged.staged_value = val;
      staged.feasible_domain = true;
      staged.feasible = feasible;
      randc_transactions_.back()[pid] = staged;
}

void vvp_cobject::randc_unmark(size_t pid, uint64_t val)
{
      if (randc_transactions_.empty()) {
	    cerr << "internal error: randc unmark outside randomize transaction"
		 << endl;
	    abort();
      }
      randc_transaction_t&pending = randc_transactions_.back();
      randc_transaction_t::iterator it = pending.find(pid);
      if (it != pending.end() && it->second.staged_value == val)
	    pending.erase(it);
}

vvp_cobject::~vvp_cobject()
{
      if (defn_->covgrp_parent_prop() >= 0)
	    defn_->covgrp_live_remove(this);

      defn_->instance_delete(properties_);
      properties_ = 0;

	// The per-instance event vvp_net_t objects are allocated from the
	// net heap pool, which (like every other net in the design) is
	// never individually freed -- vvp_net_t::operator delete is
	// intentionally unimplemented. Dropping the map is enough; the
	// nets themselves persist for the remainder of the simulation.
      inst_events_.clear();
}

vvp_net_t* vvp_cobject::get_inst_event(uint32_t slot)
{
      std::map<uint32_t, vvp_net_t*>::iterator it = inst_events_.find(slot);
      if (it != inst_events_.end())
	    return it->second;

      vvp_net_t*net = new vvp_net_t;
      net->fun = new vvp_named_event_dyn;
      inst_events_[slot] = net;
      return net;
}

void vvp_cobject::set_vec4(size_t pid, const vvp_vector4_t&val, size_t idx)
{
      defn_->set_vec4(properties_, pid, val, idx);
      touch();
}

void vvp_cobject::get_vec4(size_t pid, vvp_vector4_t&val, size_t idx)
{
      defn_->get_vec4(properties_, pid, val, idx);
}

void vvp_cobject::set_real(size_t pid, double val, size_t idx)
{
      defn_->set_real(properties_, pid, val, idx);
      touch();
}

double vvp_cobject::get_real(size_t pid, size_t idx)
{
      return defn_->get_real(properties_, pid, idx);
}

void vvp_cobject::set_string(size_t pid, const string&val, size_t idx)
{
      defn_->set_string(properties_, pid, val, idx);
      touch();
}

string vvp_cobject::get_string(size_t pid, size_t idx)
{
      return defn_->get_string(properties_, pid, idx);
}

void vvp_cobject::set_object(size_t pid, const vvp_object_t&val, size_t idx)
{
      defn_->set_object(properties_, pid, val, idx);

	// M11-3: storing a covergroup object that has a declaration
	// sampling event into an object property links the covergroup
	// back to its containing object through the hidden parent
	// slot, so %covgrp/sample/all can read the coverpoint source
	// properties. (The resulting reference cycle is intentional:
	// coverage state persists for the whole simulation.)
      if ((int)pid != defn_->covgrp_parent_prop())
      if (vvp_cobject*cg = val.peek<vvp_cobject>()) {
	    int pp = cg->get_defn()->covgrp_parent_prop();
	    if (pp >= 0 && cg != this) {
		  vvp_object_t self(this);
		  cg->set_object((size_t)pp, self, 0);
	    }
      }
      touch();
}

void vvp_cobject::get_object(size_t pid, vvp_object_t&val, size_t idx)
{
      return defn_->get_object(properties_, pid, val, idx);
}

void vvp_cobject::shallow_copy(const vvp_object*obj)
{
      const vvp_cobject*that = dynamic_cast<const vvp_cobject*>(obj);
      assert(that);

      assert(defn_ == that->defn_);

      for (size_t idx = 0 ; idx < defn_->property_count() ; idx += 1) {
	    if (defn_->property_is_static(idx))
		  continue;
	    defn_->copy_property(properties_, idx, that->properties_);
      }
	// Shallow object copy includes per-object randomization control and
	// committed cycle state. Static mode/history is intentionally absent
	// here: it is already shared by declaration through class_type's
	// canonical static cell. An in-flight transaction belongs to the
	// active call and is never copied.
      rand_mode_ = that->rand_mode_;
      constraint_mode_ = that->constraint_mode_;
      randc_history_ = that->randc_history_;
      touch();

}
