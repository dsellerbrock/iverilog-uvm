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
# include  "vvp_darray.h"
# include  "vvp_assoc.h"
# include  <iostream>
# include  <cassert>
# include  <cstdio>

using namespace std;

extern void vvp_covgrp_finalize_parent_bins(vvp_cobject*cobj);

vvp_cobject::vvp_cobject(const class_type*defn)
: defn_(defn), properties_(defn->instance_new()),
  union_active_member_(defn->is_tagged_union_type()
		       && defn->property_count() ? 0 : -1), union_vec4_(0),
  rand_mode_(defn->property_count(), true),
  constraint_mode_(defn->constraint_count(), true)
{
      unsigned union_width = defn_->union_vec4_width();
      if (union_width)
	    union_vec4_ = new vvp_vector4_t(
		  union_width, defn_->union_is_four_state() ? BIT4_X : BIT4_0);
	// Keep every live covergroup instance registered. Event-driven sampling
	// walks the relevant type's list, and cumulative coverage needs the live
	// instances' effective option.at_least values.
	if (defn->is_covergroup())
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
	// A dynamic array / queue / associative array is one property slot but
	// contains independently controlled unpacked variables. The aggregate
	// helper is internal (the IEEE query form still requires one index).
      if (pid < defn_->property_count()) {
	    const std::string&bt = defn_->property_base_type(pid);
	    vvp_object_t obj;
	    const_cast<vvp_cobject*>(this)->get_object(pid, obj, 0);
	    if (vvp_darray*array = obj.peek<vvp_darray>()) {
		  if (array->get_size() == 0) {
			if (defn_->property_is_static(pid))
			      return defn_->static_rand_mode(pid, 0);
			return pid < rand_mode_.size() ? rand_mode_[pid] : true;
		  }
		  for (size_t idx = 0 ; idx < array->get_size() ; idx += 1)
			if (!array->rand_mode(idx)) return false;
		  return true;
	    }
	    if (vvp_assoc_base*assoc = obj.peek<vvp_assoc_base>()) {
		  if (assoc->size() == 0) {
			if (defn_->property_is_static(pid))
			      return defn_->static_rand_mode(pid, 0);
			return pid < rand_mode_.size() ? rand_mode_[pid] : true;
		  }
		  // all-enabled = !any disabled; enumerate typed keys.
		  std::string skey;
		  for (bool ok = assoc->first_key(skey); ok; ok = assoc->next_key(skey))
			if (!assoc->rand_mode(skey)) return false;
		  vvp_object_t okey;
		  for (bool ok = assoc->first_key(okey); ok; ok = assoc->next_key(okey))
			if (!assoc->rand_mode(okey)) return false;
		  vvp_vector4_t vkey;
		  for (bool ok = assoc->first_key(vkey); ok; ok = assoc->next_key(vkey))
			if (!assoc->rand_mode(vkey)) return false;
		  return true;
	    }
	    if (!bt.empty() && (bt[0] == 'D' || bt[0] == 'Q'
				 || bt[0] == 'M'))
		  return defn_->property_is_static(pid)
			? defn_->static_rand_mode(pid, 0)
			: (pid < rand_mode_.size() ? rand_mode_[pid] : true);
      }
      uint64_t count = pid < defn_->property_count()
	    ? defn_->property_array_size(pid) : 1;
      if (count < 1) count = 1;
      for (uint64_t leaf = 0 ; leaf < count ; leaf += 1)
	    if (!rand_mode(pid, (size_t)leaf)) return false;
      return true;
}

bool vvp_cobject::rand_mode(size_t pid, size_t leaf) const
{
	// Sequential dynamic containers use their current positional element
	// identity. Queue mutation hooks move this state with shifted elements.
      if (pid < defn_->property_count()) {
	    const std::string&bt = defn_->property_base_type(pid);
	    if (!bt.empty() && (bt[0] == 'D' || bt[0] == 'Q')) {
		  vvp_object_t obj;
		  const_cast<vvp_cobject*>(this)->get_object(pid, obj, 0);
		  if (vvp_darray*array = obj.peek<vvp_darray>())
			return array->rand_mode(leaf);
		  return false;
	    }
      }
      if (pid < defn_->property_count() && defn_->property_is_static(pid))
	    return defn_->static_rand_mode(pid, leaf);
      if (pid >= rand_mode_.size()) return true;
      uint64_t count = defn_->property_array_size(pid);
      if (count < 1) count = 1;
      if (leaf >= count) return false;
      std::map<randc_key_t, bool>::const_iterator it =
	    rand_mode_leaves_.find(randc_key_t(pid, leaf));
      if (it != rand_mode_leaves_.end()) return it->second;
      return rand_mode_[pid];
}

bool vvp_cobject::rand_mode_for_randomization(size_t pid, size_t leaf) const
{
      if (pid < defn_->property_count()) {
	    const std::string&bt = defn_->property_base_type(pid);
	    if (!bt.empty() && (bt[0] == 'D' || bt[0] == 'Q')) {
		  vvp_object_t obj;
		  const_cast<vvp_cobject*>(this)->get_object(pid, obj, 0);
		  if (vvp_darray*array = obj.peek<vvp_darray>())
			return leaf < array->get_size()
			      ? array->rand_mode(leaf)
			      : array->rand_mode_default();
		    // A nil container has no existing element, but solver-created
		    // elements inherit the property-wide active state.
		  return defn_->property_is_static(pid)
			? defn_->static_rand_mode(pid, 0)
			: (pid < rand_mode_.size() ? rand_mode_[pid] : true);
	    }
	    if (!bt.empty() && bt[0] == 'M') {
		  vvp_object_t obj;
		  const_cast<vvp_cobject*>(this)->get_object(pid, obj, 0);
		  if (vvp_assoc_base*assoc = obj.peek<vvp_assoc_base>())
			return assoc->rand_mode_at(leaf);
		  return false;
	    }
      }
      return rand_mode(pid, leaf);
}

bool vvp_cobject::rand_mode_any(size_t pid) const
{
      if (pid < defn_->property_count()) {
	    const std::string&bt = defn_->property_base_type(pid);
	    vvp_object_t obj;
	    const_cast<vvp_cobject*>(this)->get_object(pid, obj, 0);
	    if (vvp_darray*array = obj.peek<vvp_darray>()) {
		  if (array->get_size()) return array->rand_mode_any();
		  return defn_->property_is_static(pid)
			? defn_->static_rand_mode(pid, 0)
			: (pid < rand_mode_.size() ? rand_mode_[pid] : true);
	    }
	    if (vvp_assoc_base*assoc = obj.peek<vvp_assoc_base>()) {
		  if (assoc->size()) return assoc->rand_mode_any();
		  return defn_->property_is_static(pid)
			? defn_->static_rand_mode(pid, 0)
			: (pid < rand_mode_.size() ? rand_mode_[pid] : true);
	    }
	    if (!bt.empty() && (bt[0] == 'D' || bt[0] == 'Q'
				 || bt[0] == 'M'))
		  return defn_->property_is_static(pid)
			? defn_->static_rand_mode(pid, 0)
			: (pid < rand_mode_.size() ? rand_mode_[pid] : true);
      }
      if (pid < defn_->property_count() && defn_->property_is_static(pid))
	    return defn_->static_rand_mode_any(pid);
      uint64_t count = pid < defn_->property_count()
	    ? defn_->property_array_size(pid) : 1;
      if (count < 1) count = 1;
      for (uint64_t leaf = 0 ; leaf < count ; leaf += 1)
	    if (rand_mode(pid, (size_t)leaf)) return true;
      return false;
}

static void erase_rand_mode_leaves_(
	    std::map<vvp_cobject::randc_key_t, bool>&modes, size_t pid)
{
      std::map<vvp_cobject::randc_key_t, bool>::iterator it =
	    modes.lower_bound(vvp_cobject::randc_key_t(pid, 0));
      while (it != modes.end() && it->first.pid == pid)
	    it = modes.erase(it);
}

void vvp_cobject::set_rand_mode(size_t pid, bool mode)
{
      if (pid < defn_->property_count() && defn_->property_is_static(pid)) {
	    defn_->set_static_rand_mode(pid, mode);
	} else if (pid < rand_mode_.size()) {
	    rand_mode_[pid] = mode;
	    erase_rand_mode_leaves_(rand_mode_leaves_, pid);
      }
	// Also update every element that exists now. The stored default on the
	// container makes elements created later inherit this property-wide mode.
      if (pid < defn_->property_count()) {
	    vvp_object_t obj;
	    get_object(pid, obj, 0);
	    if (vvp_darray*array = obj.peek<vvp_darray>())
		  array->set_all_rand_mode(mode);
	    else if (vvp_assoc_base*assoc = obj.peek<vvp_assoc_base>())
		  assoc->set_all_rand_mode(mode);
      }
}

void vvp_cobject::set_rand_mode(size_t pid, size_t leaf, bool mode)
{
	// Dynamic arrays and queues store the mode with the live container.
      if (pid < defn_->property_count()) {
	    const std::string&bt = defn_->property_base_type(pid);
	    if (!bt.empty() && (bt[0] == 'D' || bt[0] == 'Q')) {
		  vvp_object_t obj;
		  get_object(pid, obj, 0);
		  if (vvp_darray*array = obj.peek<vvp_darray>())
			array->set_rand_mode(leaf, mode);
		  return;
	    }
      }
      if (pid < defn_->property_count() && defn_->property_is_static(pid)) {
	    defn_->set_static_rand_mode(pid, leaf, mode);
	    return;
      }
      if (pid >= rand_mode_.size()) return;
      uint64_t count = defn_->property_array_size(pid);
      if (count < 1) count = 1;
      if (leaf >= count) return;
      randc_key_t key(pid, leaf);
      if (mode == rand_mode_[pid])
	    rand_mode_leaves_.erase(key);
      else
	    rand_mode_leaves_[key] = mode;
}

bool vvp_cobject::rand_mode(size_t pid, const std::string&key) const
{
      vvp_object_t obj;
      const_cast<vvp_cobject*>(this)->get_object(pid, obj, 0);
      vvp_assoc_base*assoc = obj.peek<vvp_assoc_base>();
      return assoc ? assoc->rand_mode(key) : false;
}

bool vvp_cobject::rand_mode(size_t pid, const vvp_object_t&key) const
{
      vvp_object_t obj;
      const_cast<vvp_cobject*>(this)->get_object(pid, obj, 0);
      vvp_assoc_base*assoc = obj.peek<vvp_assoc_base>();
      return assoc ? assoc->rand_mode(key) : false;
}

bool vvp_cobject::rand_mode(size_t pid, const vvp_vector4_t&key) const
{
      vvp_object_t obj;
      const_cast<vvp_cobject*>(this)->get_object(pid, obj, 0);
      vvp_assoc_base*assoc = obj.peek<vvp_assoc_base>();
      return assoc ? assoc->rand_mode(key) : false;
}

void vvp_cobject::set_rand_mode(size_t pid, const std::string&key, bool mode)
{
      vvp_object_t obj;
      get_object(pid, obj, 0);
      if (vvp_assoc_base*assoc = obj.peek<vvp_assoc_base>())
	    assoc->set_rand_mode(key, mode);
}

void vvp_cobject::set_rand_mode(size_t pid, const vvp_object_t&key, bool mode)
{
      vvp_object_t obj;
      get_object(pid, obj, 0);
      if (vvp_assoc_base*assoc = obj.peek<vvp_assoc_base>())
	    assoc->set_rand_mode(key, mode);
}

void vvp_cobject::set_rand_mode(size_t pid, const vvp_vector4_t&key, bool mode)
{
      vvp_object_t obj;
      get_object(pid, obj, 0);
      if (vvp_assoc_base*assoc = obj.peek<vvp_assoc_base>())
	    assoc->set_rand_mode(key, mode);
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
uint64_t vvp_cobject::randc_period(size_t pid, size_t leaf) const
{
      if (pid >= defn_->property_count()) return 0;
      vvp_vector4_t probe;
      const_cast<vvp_cobject*>(this)->get_vec4(pid, probe, leaf);
      unsigned w = probe.size();
      if (w == 0 || w > 20) return 0;
      return (uint64_t)1 << w;
}

const std::vector<bool>*vvp_cobject::randc_history_find_(
	    const randc_key_t&key) const
{
      size_t pid = key.pid;
      if (pid < defn_->property_count() && defn_->property_is_static(pid))
	    return &defn_->static_randc_history(pid, key.leaf);

      std::map<randc_key_t, std::vector<bool> >::const_iterator it
	    = randc_history_.find(key);
      return it == randc_history_.end() ? 0 : &it->second;
}

std::vector<bool>&vvp_cobject::randc_history_mutable_(const randc_key_t&key)
{
      size_t pid = key.pid;
      if (pid < defn_->property_count() && defn_->property_is_static(pid))
	    return defn_->static_randc_history(pid, key.leaf);
      return randc_history_[key];
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

bool vvp_cobject::randc_container_state_(size_t pid, size_t word,
	    size_t position,
	    vvp_vector4_t&value, std::vector<bool>*&history) const
{
      history = 0;
      if (pid >= defn_->property_count()) return false;
      vvp_object_t object;
      const_cast<vvp_cobject*>(this)->get_object(pid, object, word);
      if (vvp_darray*array = object.peek<vvp_darray>()) {
	    if (position >= array->get_size()) return false;
	    array->get_word((unsigned)position, value);
	    history = &array->randc_history(position);
	    return value.size() != 0;
      }
      if (vvp_assoc_base*assoc = object.peek<vvp_assoc_base>()) {
	    std::string key_text, string_value;
	    double real_value = 0.0;
	    int value_kind = -1;
	    if (!assoc->peek_entry(position, key_text, value, real_value,
				   string_value, value_kind)
		|| value_kind != 0)
		  return false;
	    history = &assoc->randc_history_at(position);
	    return value.size() != 0;
      }
      return false;
}

static bool randc_value_to_uint64_(const vvp_vector4_t&value,
	    uint64_t&actual)
{
      actual = 0;
      for (unsigned bit = 0 ; bit < value.size() ; bit += 1) {
	    vvp_bit4_t digit = value.value(bit);
	    if (digit == BIT4_1)
		  actual |= (uint64_t)1 << bit;
	    else if (digit != BIT4_0)
		  return false;
      }
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
	    randc_key_t key;
	    uint64_t period;
	    uint64_t actual;
	    randc_pending_t pending;
	    std::vector<bool>*container_history = 0;
      };
      std::vector<resolved_randc_t> resolved;

	// Validate and capture every actual final value before changing any
	// history bank. This makes a multi-property commit atomic even if an
	// unexpected X/Z reaches a supposedly successful solver result.
      for (std::map<randc_key_t, randc_pending_t>::const_iterator it =
		 pending.properties.begin(); it != pending.properties.end(); ++it) {
	    uint64_t period = randc_period(it->first.pid, it->first.leaf);
	    if (period == 0) continue;

	    vvp_vector4_t val;
	    get_vec4(it->first.pid, val, it->first.leaf);
	    uint64_t actual = 0;
	    if (!randc_value_to_uint64_(val, actual)) {
			cerr << "warning: successful randomize produced X/Z for randc "
			     << "property '" << defn_->property_name(it->first.pid)
			     << "' leaf " << it->first.leaf
			     << "; history transaction rolled back" << endl;
			return false;
	    }

	    resolved_randc_t item;
	    item.key = it->first;
	    item.period = period;
	    item.actual = actual;
	    item.pending = it->second;
	    resolved.push_back(item);
      }

      for (std::map<randc_transaction_t::container_key_t,
		 randc_pending_t>::const_iterator it =
		 pending.containers.begin(); it != pending.containers.end(); ++it) {
	    vvp_vector4_t val;
	    std::vector<bool>*history = 0;
	    if (!randc_container_state_(it->first.pid, it->first.word,
					it->first.position,
					val, history))
		  continue;
	    unsigned width = val.size();
	    if (width == 0 || width > 20) continue;
	    uint64_t period = (uint64_t)1 << width;
	    uint64_t actual = 0;
	    if (!randc_value_to_uint64_(val, actual)) {
		  cerr << "warning: successful randomize produced X/Z for randc "
		       << "container property '"
		       << defn_->property_name(it->first.pid) << "' element "
		       << it->first.position
		       << "; history transaction rolled back" << endl;
		  return false;
	    }
	    resolved_randc_t item;
	    item.key = randc_key_t(it->first.pid, it->first.position);
	    item.period = period;
	    item.actual = actual;
	    item.pending = it->second;
	    item.container_history = history;
	    resolved.push_back(item);
      }

      for (const resolved_randc_t&item : resolved) {
	    std::vector<bool>&hist = item.container_history
		  ? *item.container_history : randc_history_mutable_(item.key);
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

void vvp_cobject::randc_history_snapshot(randc_history_state_t&state) const
{
      state = randc_history_;
}

void vvp_cobject::randc_history_restore(const randc_history_state_t&state)
{
      randc_history_ = state;
}

bool vvp_cobject::randc_seen(size_t pid, uint64_t val, size_t leaf) const
{
      uint64_t period = randc_period(pid, leaf);
      const std::vector<bool>*hist =
	    randc_history_find_(randc_key_t(pid, leaf));
      if (!hist || val >= hist->size()) return false;
	// Exhaustion is a logical new-cycle view, not a mutation. If the
	// ensuing solve fails, the committed completed cycle stays intact.
      if (randc_history_full_(*hist, period)) return false;
      return (*hist)[(size_t)val];
}

void vvp_cobject::randc_mark(size_t pid, uint64_t val, size_t leaf)
{
      uint64_t period = randc_period(pid, leaf);
      if (period == 0) return;
      if (val >= period) return;
      if (randc_transactions_.empty()) {
	    cerr << "internal error: randc mark outside randomize transaction"
		 << endl;
	    abort();
      }
      randc_pending_t staged;
      staged.staged_value = val;
      randc_transactions_.back().properties[randc_key_t(pid, leaf)] = staged;
}

// RANDOM-DIST fix #4: see the declaration in vvp_cobject.h.
void vvp_cobject::randc_mark_feasible(size_t pid, uint64_t val,
                                       const std::vector<uint64_t>&feasible,
                                       size_t leaf)
{
      uint64_t period = randc_period(pid, leaf);
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
      randc_transactions_.back().properties[randc_key_t(pid, leaf)] = staged;
}

void vvp_cobject::randc_unmark(size_t pid, uint64_t val, size_t leaf)
{
      if (randc_transactions_.empty()) {
	    cerr << "internal error: randc unmark outside randomize transaction"
		 << endl;
	    abort();
      }
      randc_transaction_t&pending = randc_transactions_.back();
      std::map<randc_key_t, randc_pending_t>::iterator it =
	    pending.properties.find(randc_key_t(pid, leaf));
      if (it != pending.properties.end() && it->second.staged_value == val)
	    pending.properties.erase(it);
}

bool vvp_cobject::randc_container_seen(size_t pid, size_t position,
	    uint64_t val, size_t word) const
{
      vvp_vector4_t value;
      std::vector<bool>*history = 0;
      if (!randc_container_state_(pid, word, position, value, history))
	    return false;
      unsigned width = value.size();
      if (width == 0 || width > 20) return false;
      uint64_t period = (uint64_t)1 << width;
      if (!history || val >= history->size()) return false;
      if (randc_history_full_(*history, period)) return false;
      return (*history)[(size_t)val];
}

void vvp_cobject::randc_container_mark(size_t pid, size_t position,
	    uint64_t val, size_t word)
{
      vvp_vector4_t value;
      std::vector<bool>*history = 0;
      if (!randc_container_state_(pid, word, position, value, history)) return;
      unsigned width = value.size();
      if (width == 0 || width > 20 || val >= ((uint64_t)1 << width)) return;
      if (randc_transactions_.empty()) {
	    cerr << "internal error: container randc mark outside randomize "
		 << "transaction" << endl;
	    abort();
      }
      randc_pending_t staged;
      staged.staged_value = val;
      randc_transactions_.back().containers[
	    randc_transaction_t::container_key_t(pid, word, position)] = staged;
}

void vvp_cobject::randc_container_mark_feasible(size_t pid, size_t position,
	    uint64_t val, const std::vector<uint64_t>&feasible, size_t word)
{
      vvp_vector4_t value;
      std::vector<bool>*history = 0;
      if (!randc_container_state_(pid, word, position, value, history)) return;
      unsigned width = value.size();
      if (width == 0 || width > 20 || val >= ((uint64_t)1 << width)) return;
      if (randc_transactions_.empty()) {
	    cerr << "internal error: constrained container randc mark outside "
		 << "randomize transaction" << endl;
	    abort();
      }
      randc_pending_t staged;
      staged.staged_value = val;
      staged.feasible_domain = true;
      staged.feasible = feasible;
      randc_transactions_.back().containers[
	    randc_transaction_t::container_key_t(pid, word, position)] = staged;
}

void vvp_cobject::randc_container_unmark(size_t pid, size_t position,
	    uint64_t val, size_t word)
{
      if (randc_transactions_.empty()) {
	    cerr << "internal error: container randc unmark outside randomize "
		 << "transaction" << endl;
	    abort();
      }
      std::map<randc_transaction_t::container_key_t,
	    randc_pending_t>&pending =
	    randc_transactions_.back().containers;
      std::map<randc_transaction_t::container_key_t,
	    randc_pending_t>::iterator it = pending.find(
		  randc_transaction_t::container_key_t(pid, word, position));
      if (it != pending.end() && it->second.staged_value == val)
	    pending.erase(it);
}

vvp_cobject::~vvp_cobject()
{
	if (defn_->is_covergroup())
	    defn_->covgrp_live_remove(this);

      defn_->instance_delete(properties_);
      properties_ = 0;
      delete union_vec4_;
      union_vec4_ = 0;

	// The per-instance event vvp_net_t objects are allocated from the
	// net heap pool, which (like every other net in the design) is
	// never individually freed -- vvp_net_t::operator delete is
	// intentionally unimplemented. Dropping the map is enough; the
	// nets themselves persist for the remainder of the simulation.
      inst_events_.clear();
}

bool vvp_cobject::union_member_read_ok_(size_t pid) const
{
      if (!defn_->is_tagged_union_type()
	  || union_active_member_ == (int)pid)
	    return true;

      cerr << "runtime error: tagged union '" << defn_->class_name()
	   << "' member '" << defn_->property_name(pid)
	   << "' is inactive";
      if (union_active_member_ >= 0
	  && (size_t)union_active_member_ < defn_->property_count())
	    cerr << " (active member is '"
		 << defn_->property_name((size_t)union_active_member_) << "')";
      cerr << "." << endl;
      vpip_set_return_value(1);
      return false;
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
      if (defn_->is_union_type() && union_vec4_ && idx == 0
	  && defn_->property_array_size(pid) == 1
	  && defn_->property_vec4_width(pid)) {
	    // Let the declared property normalize width, signedness and
	    // two-state X/Z coercion, then copy its representation into the
	    // union's shared integral storage. A narrower unpacked-union member
	    // occupies the low bits; the remaining shared bits are zero.
	    vvp_vector4_t old_shared = *union_vec4_;
	    int old_active = union_active_member_;
	    defn_->set_vec4(properties_, pid, val, idx);
	    vvp_vector4_t member;
	    defn_->get_vec4(properties_, pid, member, idx);
	    vvp_vector4_t shared(union_vec4_->size(), BIT4_0);
	    unsigned copy_width = member.size() < shared.size()
		  ? member.size() : shared.size();
	    if (copy_width)
		  shared.set_vec(0, member.subvalue(0, copy_width));
	    *union_vec4_ = shared;
	    union_active_member_ = (int)pid;
	    if (old_active != union_active_member_
	        || !old_shared.eeq(*union_vec4_))
	          touch();
	    return;
      }
      vvp_vector4_t old;
      defn_->get_vec4(properties_, pid, old, idx);
      int old_active = union_active_member_;
      defn_->set_vec4(properties_, pid, val, idx);
      if (defn_->is_union_type())
	    union_active_member_ = (int)pid;
      vvp_vector4_t stored;
      defn_->get_vec4(properties_, pid, stored, idx);
      if (defn_->is_union_type() && old_active != union_active_member_) {
            /* Changing the active union member is itself observable even
               when this member's retained backing value is unchanged. */
            touch();
            return;
      }
      if (!old.eeq(stored)) {
            unsigned width = old.size() > stored.size()
                           ? old.size() : stored.size();
            for (unsigned bit = 0 ; bit < width ; bit += 1) {
                  vvp_bit4_t old_bit = bit < old.size()
                                     ? old.value(bit) : BIT4_0;
                  vvp_bit4_t new_bit = bit < stored.size()
                                     ? stored.value(bit) : BIT4_0;
                  if (old_bit != new_bit)
                        touch((unsigned)pid, (unsigned)idx, bit);
            }
      }
}

void vvp_cobject::get_vec4(size_t pid, vvp_vector4_t&val, size_t idx)
{
      if (!union_member_read_ok_(pid)) {
	    unsigned width = defn_->property_vec4_width(pid);
	    val = vvp_vector4_t(width ? width : 1, BIT4_X);
	    return;
      }
      if (defn_->is_union_type() && union_vec4_ && idx == 0
	  && defn_->property_array_size(pid) == 1
	  && defn_->property_vec4_width(pid)) {
	    // Read through the declared member type so a two-state view coerces
	    // shared X/Z bits exactly as an ordinary bit/integer read would.
	    vvp_vector4_t member = union_vec4_->subvalue(
		  0, defn_->property_vec4_width(pid));
	    const string&member_type = defn_->property_base_type(pid);
	    size_t type_pos = !member_type.empty() && member_type[0] == 's'
		  ? 1 : 0;
	    if (type_pos < member_type.size()
		&& member_type[type_pos] == 'b') {
		  for (unsigned bit = 0 ; bit < member.size() ; bit += 1)
			if (bit4_is_xz(member.value(bit)))
			      member.set_bit(bit, BIT4_0);
	    }
	    defn_->set_vec4(properties_, pid, member, idx);
	    defn_->get_vec4(properties_, pid, val, idx);
	    return;
      }
      defn_->get_vec4(properties_, pid, val, idx);
}

void vvp_cobject::set_real(size_t pid, double val, size_t idx)
{
      double old = defn_->get_real(properties_, pid, idx);
      int old_active = union_active_member_;
      defn_->set_real(properties_, pid, val, idx);
      if (defn_->is_union_type())
	    union_active_member_ = (int)pid;
      double stored = defn_->get_real(properties_, pid, idx);
      if (defn_->is_union_type() && old_active != union_active_member_) {
            touch();
            return;
      }
      if (old != stored)
            touch((unsigned)pid, (unsigned)idx);
}

double vvp_cobject::get_real(size_t pid, size_t idx)
{
      if (!union_member_read_ok_(pid))
	    return 0.0;
      return defn_->get_real(properties_, pid, idx);
}

void vvp_cobject::set_string(size_t pid, const string&val, size_t idx)
{
      string old = defn_->get_string(properties_, pid, idx);
      int old_active = union_active_member_;
      defn_->set_string(properties_, pid, val, idx);
      if (defn_->is_union_type())
	    union_active_member_ = (int)pid;
      string stored = defn_->get_string(properties_, pid, idx);
      if (defn_->is_union_type() && old_active != union_active_member_) {
            touch();
            return;
      }
      if (old != stored)
            touch((unsigned)pid, (unsigned)idx);
}

string vvp_cobject::get_string(size_t pid, size_t idx)
{
      if (!union_member_read_ok_(pid))
	    return string();
      return defn_->get_string(properties_, pid, idx);
}

void vvp_cobject::set_object(size_t pid, const vvp_object_t&val, size_t idx)
{
      vvp_object_t old;
      defn_->get_object(properties_, pid, old, idx);
      int old_active = union_active_member_;
      defn_->set_object(properties_, pid, val, idx);
      if (defn_->is_union_type())
	    union_active_member_ = (int)pid;

	// A whole-container assignment creates a new set of unpacked element
	// variables. Initialize those variables from the owning property's
	// current aggregate mode; individual overrides belong to the old set.
      if (pid < defn_->property_count() && idx == 0) {
	    bool mode = defn_->property_is_static(pid)
		  ? defn_->static_rand_mode(pid, 0)
		  : (pid < rand_mode_.size() ? rand_mode_[pid] : true);
	    vvp_object_t stored;
	    defn_->get_object(properties_, pid, stored, idx);
	    if (vvp_darray*array = stored.peek<vvp_darray>())
		  array->set_all_rand_mode(mode);
	    else if (vvp_assoc_base*assoc = stored.peek<vvp_assoc_base>())
		  assoc->set_all_rand_mode(mode);
      }

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
		  vvp_covgrp_finalize_parent_bins(cg);
	    }
      }
      vvp_object_t stored;
      defn_->get_object(properties_, pid, stored, idx);
      if (defn_->is_union_type() && old_active != union_active_member_) {
            touch();
            return;
      }
      if (old != stored)
            touch((unsigned)pid, (unsigned)idx);
}

void vvp_cobject::get_object(size_t pid, vvp_object_t&val, size_t idx)
{
      if (!union_member_read_ok_(pid)) {
	    val = vvp_object_t();
	    return;
      }
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
      rand_mode_leaves_ = that->rand_mode_leaves_;
      constraint_mode_ = that->constraint_mode_;
      randc_history_ = that->randc_history_;
	// Constructor-derived coverage topology belongs to the copied property
	// values, not to the destination's previous contents. Rebuild both caches
	// lazily so a covergroup object copy cannot retain stale dynamic ranges or
	// cross cardinalities.
      cov_dyn_states_.clear();
      cov_dyn_resolved_ = false;
      cov_cross_states_.clear();
      cov_cross_resolved_ = false;
      union_active_member_ = that->union_active_member_;
      if (union_vec4_ && that->union_vec4_)
	    *union_vec4_ = *that->union_vec4_;
      touch();

}
