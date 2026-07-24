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
      if (pid < rand_mode_.size()) return rand_mode_[pid];
      return true;
}

void vvp_cobject::set_rand_mode(size_t pid, bool mode)
{
      if (pid < rand_mode_.size()) rand_mode_[pid] = mode;
}

void vvp_cobject::set_all_rand_mode(bool mode)
{
      for (size_t i = 0 ; i < rand_mode_.size() ; i += 1)
	    rand_mode_[i] = mode;
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

// C1 (Phase 62a): randc cyclic state.  Cycle period = 2^width capped at
// 65536 so the bitmap stays bounded.  Wider properties fall back to plain
// rand (period reported as 0).
uint64_t vvp_cobject::randc_period(size_t pid) const
{
      if (pid >= defn_->property_count()) return 0;
      vvp_vector4_t probe;
      const_cast<vvp_cobject*>(this)->get_vec4(pid, probe);
      unsigned w = probe.size();
      if (w == 0 || w > 16) return 0;
      return (uint64_t)1 << w;
}

bool vvp_cobject::randc_seen(size_t pid, uint64_t val) const
{
      std::map<size_t, std::vector<bool> >::const_iterator it
            = randc_history_.find(pid);
      if (it == randc_history_.end()) return false;
      if (val >= it->second.size()) return false;
      return it->second[val];
}

void vvp_cobject::randc_mark(size_t pid, uint64_t val)
{
      uint64_t period = randc_period(pid);
      if (period == 0) return;
      std::vector<bool>&hist = randc_history_[pid];
      if (hist.size() != period) hist.assign((size_t)period, false);
      if (val >= period) return;
      hist[val] = true;
      bool all_used = true;
      for (size_t i = 0; i < hist.size(); i += 1) {
            if (!hist[i]) { all_used = false; break; }
      }
      if (all_used) {
            for (size_t i = 0; i < hist.size(); i += 1) hist[i] = false;
      }
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

      for (size_t idx = 0 ; idx < defn_->property_count() ; idx += 1)
	    defn_->copy_property(properties_, idx, that->properties_);
      touch();

}
