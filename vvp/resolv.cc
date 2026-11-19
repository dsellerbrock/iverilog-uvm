/*
 * Copyright (c) 2001-2021 Stephen Williams (steve@icarus.com)
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

# include  "resolv.h"
# include  "part.h"
# include  "schedule.h"
# include  "compile.h"
# include  "statistics.h"
# include  "vpi_priv.h"
# include  <iostream>
# include  <algorithm>
# include  <cassert>

using namespace std;

/*
 * The core functor for a resolver node stores all the input values
 * received by that node. This provides the necessary information
 * for implementing the $countdrivers system call. For efficiency,
 * the resolver is implemented using a balanced quaternary tree, so
 * the core functor also stores the current value for each branch
 * of the tree, to eliminate the need to re-evaluate branches whose
 * inputs haven't changed. Nodes are numbered by level, starting with
 * the inputs, then the first level of branches, down to the output.
 */


resolv_core::resolv_core(unsigned nports, vvp_net_t*net)
: nports_(nports), net_(net), notify_driver_activity_(false),
  input_sources_(nports, nullptr)
{
      count_functors_resolv += 1;
}

resolv_core::~resolv_core()
{
}

void resolv_core::set_input_source(unsigned port, vvp_net_t*source)
{
      assert(port < nports_);
      input_sources_[port] = source;
}

bool resolv_core::sole_part_pv_source(unsigned bit,
                                     const vvp_net_t*source,
                                     unsigned source_port) const
{
      if (source_port >= nports_ || input_sources_[source_port] != source)
	    return false;
      bool found = false;
      for (unsigned port = 0; port < nports_; ++port) {
	    const vvp_net_t*input = input_sources_[port];
	    // Constants, unresolved links, and full-width drivers may drive bit.
	    if (!input)
		  return false;
	    const auto*part = dynamic_cast<const vvp_fun_part_pv*>(input->fun);
	    if (!part)
		  return false;
	    if (bit < part->get_base() || bit - part->get_base() >= part->get_wid())
		  continue;
	    if (port != source_port || found)
		  return false;
	    found = true;
      }
      return found;
}

void resolv_core::notify_driver_activity()
{
      if (notify_driver_activity_ && net_->fil)
            net_->fil->notify_driver_activity();
}

void resolv_core::recv_vec4_pv_(unsigned port, const vvp_vector4_t&bit,
				unsigned base, unsigned vwid)
{
      unsigned wid = bit.size();
      vvp_vector4_t res (vwid);

      for (unsigned idx = 0 ;  idx < base ;  idx += 1)
	    res.set_bit(idx, BIT4_Z);

      for (unsigned idx = 0 ;  idx < wid && idx+base < vwid;  idx += 1)
	    res.set_bit(idx+base, bit.value(idx));

      for (unsigned idx = base+wid ;  idx < vwid ;  idx += 1)
	    res.set_bit(idx, BIT4_Z);

      recv_vec4_(port, res);
}

void resolv_core::recv_vec8_pv_(unsigned port, const vvp_vector8_t&bit,
				unsigned base, unsigned vwid)
{
      unsigned wid = bit.size();
      vvp_vector8_t res (vwid);

      for (unsigned idx = 0 ;  idx < base ;  idx += 1)
	    res.set_bit(idx, vvp_scalar_t());

      for (unsigned idx = 0 ;  idx < wid && idx+base < vwid;  idx += 1)
	    res.set_bit(idx+base, bit.value(idx));

      for (unsigned idx = base+wid ;  idx < vwid ;  idx += 1)
	    res.set_bit(idx, vvp_scalar_t());

      recv_vec8_(port, res);
}


resolv_extend::resolv_extend(resolv_core*core, unsigned port_base)
: core_(core), port_base_(port_base)
{
}

resolv_extend::~resolv_extend()
{
}


// Keep the original ambiguous ranges separate from the strongest known
// drivers. Resolving a partial driver set to vec8 loses that distinction.
struct resolv_tri::strength_summary {
      enum { ZERO = 1, ONE = 2, BOTH = ZERO | ONE };

      signed char low = 7;
      signed char high = -7;
      unsigned char strength = 0;
      unsigned char polarities = 0;

      void add_known(unsigned char str, unsigned char mask)
      {
            if (str > strength) {
                  strength = str;
                  polarities = mask;
            } else if (str == strength) {
                  polarities |= mask;
            }
      }

      void add_driver(vvp_scalar_t driver)
      {
            if (driver.is_hiz())
                  return;
            int lo = driver.low_endpoint();
            int hi = driver.high_endpoint();
            if (lo == hi) {
                  add_known(lo < 0 ? -lo : lo, lo < 0 ? ZERO : ONE);
            } else {
                  low = min<int>(low, lo);
                  high = max<int>(high, hi);
            }
      }

      void merge(const strength_summary& that)
      {
            low = min(low, that.low);
            high = max(high, that.high);
            add_known(that.strength, that.polarities);
      }

      bool operator==(const strength_summary& that) const
      {
            return low == that.low && high == that.high
                && strength == that.strength && polarities == that.polarities;
      }

      vvp_scalar_t result() const
      {
            // IEEE 1800 28.12.1-3: the strongest known drivers either
            // form another ambiguous range or apply the mixed rule once.
            if (polarities == BOTH)
                  return vvp_scalar_t::from_endpoints(min<int>(low, -strength),
                                                      max<int>(high, strength));

            vvp_scalar_t ambiguous;
            if (low <= high)
                  ambiguous = vvp_scalar_t::from_endpoints(low, high);
            if (polarities == 0)
                  return ambiguous;
            vvp_scalar_t known(polarities == ZERO ? BIT4_0 : BIT4_1,
                               strength, strength);
            return resolve(known, ambiguous);
      }
};

resolv_tri::resolv_tri(unsigned nports, vvp_net_t*net, vvp_scalar_t hiz_value)
: resolv_core(nports, net), hiz_value_(hiz_value),
  val_(new vvp_vector8_t[nports]), branches_(nullptr)
{
      unsigned nbranches = 0;
      while (nports > 4) {
            nports = (nports + 3) / 4;
            nbranches += nports;
      }
      if (nbranches)
            branches_ = new vector<strength_summary>[nbranches];
}

resolv_tri::~resolv_tri()
{
      delete[] val_;
      delete[] branches_;
}

void resolv_tri::replay_input(unsigned port, vvp_net_ptr_t dest) const
{
      if (val_[port].size() > 0)
	    dest.ptr()->fun->recv_vec8(dest, val_[port]);
}

void resolv_tri::recv_vec4_(unsigned port, const vvp_vector4_t&bit)
{
      recv_vec8_(port, vvp_vector8_t(bit, 6,6 /* STRONG */));
}

void resolv_tri::recv_vec8_(unsigned port, const vvp_vector8_t&bit)
{
      assert(port < nports_);

      if (val_[port].eeq(bit))
	    return;

      val_[port] = bit;

        // Rebuild the group of up to four nodes containing the changed
        // port. Then propagate its summary toward the root.
      unsigned base = 0;
      unsigned span = nports_;
      do {
            unsigned next_base = base + span;
            unsigned first = base + (port & ~0x3);
            unsigned limit = min(first + 4, next_base);
            unsigned width = 0;
            for (unsigned node = first; node < limit; ++node) {
                  unsigned size = base == 0 ? val_[node].size()
                                           : branches_[node - nports_].size();
                  if (size == 0)
                        continue;
                  assert(width == 0 || width == size);
                  width = size;
            }

            const auto summarize_bit = [&](unsigned idx) {
                  strength_summary summary;
                  if (base == 0) {
                        for (unsigned node = first; node < limit; ++node) {
                              const auto& input = val_[node];
                              if (input.size())
                                    summary.add_driver(input.value(idx));
                        }
                  } else {
                        for (unsigned node = first; node < limit; ++node) {
                              const auto& input = branches_[node - nports_];
                              if (!input.empty())
                                    summary.merge(input[idx]);
                        }
                  }
                  return summary;
            };

            if (span <= 4) {
                  vvp_vector8_t out(width);
                  for (unsigned idx = 0; idx < width; ++idx) {
                        strength_summary summary = summarize_bit(idx);
                        summary.add_driver(hiz_value_);
                        out.set_bit(idx, summary.result());
                  }
                  if (out_.eeq(out)) {
                        notify_driver_activity();
                  } else {
                        out_ = out;
                        net_->send_vec8(out);
                  }
                  return;
            }

            port /= 4;
            auto& cached = branches_[next_base + port - nports_];
            bool changed = cached.size() != width;
            cached.resize(width);
            for (unsigned idx = 0; idx < width; ++idx) {
                  strength_summary summary = summarize_bit(idx);
                  if (!(cached[idx] == summary)) {
                        cached[idx] = summary;
                        changed = true;
                  }
            }
            if (!changed) {
                  notify_driver_activity();
                  return;
            }
            base = next_base;
            span = (span + 3) / 4;
      } while (span > 1);
}

void resolv_tri::count_drivers(unsigned bit_idx, unsigned counts[3])
{
      for (unsigned idx = 0 ; idx < nports_ ; idx += 1) {
	    if (val_[idx].size() == 0)
	          continue;

            update_driver_counts(val_[idx].value(bit_idx).value(), counts);
      }
}


// Each scalar encodes the endpoints of a contiguous range on the
// signed strength scale (-7 is supply0, +7 is supply1). Resolve every
// pair of possible strengths and retain the resulting range.
vvp_scalar_t resolve_wired(vvp_scalar_t a, vvp_scalar_t b, bool is_or)
{
      int alo = (a.value_ & 8) ? (a.value_ & 7) : -(a.value_ & 7);
      int ahi = (a.value_ & 128) ? ((a.value_ >> 4) & 7) : -((a.value_ >> 4) & 7);
      int blo = (b.value_ & 8) ? (b.value_ & 7) : -(b.value_ & 7);
      int bhi = (b.value_ & 128) ? ((b.value_ >> 4) & 7) : -((b.value_ >> 4) & 7);
      int lo = 7, hi = -7;
      for (int x = alo; x <= ahi; x += 1) {
            for (int y = blo; y <= bhi; y += 1) {
                  int ax = x < 0 ? -x : x;
                  int ay = y < 0 ? -y : y;
                  int result = ax > ay ? x : ay > ax ? y :
                               is_or ? (x > y ? x : y) : (x < y ? x : y);
                  if (result < lo) lo = result;
                  if (result > hi) hi = result;
            }
      }
      unsigned low = lo < 0 ? -lo : (lo ? lo | 8 : 0);
      unsigned high = hi < 0 ? -hi : (hi || lo < 0 ? hi | 8 : 0);
      return vvp_scalar_t(static_cast<unsigned char>(low | (high << 4)));
}

resolv_wired_logic::resolv_wired_logic(unsigned nports, vvp_net_t*net)
: resolv_core(nports, net)
{
        // count the input (leaf) nodes
      unsigned nnodes = nports;

        // add in the intermediate branch nodes
      while (nports > 4) {
            nports = (nports + 3) / 4;
            nnodes += nports;
      }
        // add one more node for storing the output value
        // (not needed if there is only one input)
      if (nnodes > 1)
            nnodes += 1;

      val_ = new vvp_vector8_t [nnodes];
}

resolv_wired_logic::~resolv_wired_logic()
{
      delete[] val_;
}

void resolv_wired_logic::replay_input(unsigned port, vvp_net_ptr_t dest) const
{
      if (val_[port].size() > 0)
	    dest.ptr()->fun->recv_vec8(dest, val_[port]);
}

void resolv_wired_logic::recv_vec4_(unsigned port, const vvp_vector4_t&bit)
{
      recv_vec8_(port, vvp_vector8_t(bit, 6, 6));
}

void resolv_wired_logic::recv_vec8_(unsigned port, const vvp_vector8_t&bit)
{
      assert(port < nports_);

      if (val_[port].eeq(bit))
	    return;

      val_[port] = bit;

        // Starting at the leaf level, work down the tree, resolving
        // the changed values. base is the first node in the current
        // level and span is the number of nodes at that level. ip
        // is the first node in the group of four nodes at that level
        // that include the node that has changed, and op is the node
        // at the next level that stores the resolved value from that
        // group.
      unsigned base = 0;
      unsigned span = nports_;
      while (span > 1) {
            unsigned next_base = base + span;
            unsigned ip = base + (port & ~0x3);
            unsigned op = next_base + (port / 4);
            unsigned ll = min(ip + 4, next_base);

            vvp_vector8_t out = val_[ip];
            for (ip = ip + 1; ip < ll; ip += 1) {
                  if (val_[ip].size() == 0)
                        continue;
                  if (out.size() == 0)
                        out = val_[ip];
                  else {
                        assert(out.size() == val_[ip].size());
                        for (unsigned idx = 0; idx < out.size(); idx += 1)
                              out.set_bit(idx, resolve_wired(out.value(idx),
                                                           val_[ip].value(idx), wired_or_()));
                  }
            }
            if (val_[op].eeq(out)) {
                  notify_driver_activity();
                  return;
            }
            val_[op] = out;

            base = next_base;
            span = (span + 3) / 4;
            port = port / 4;
      }

      net_->send_vec8(val_[base]);
}

void resolv_wired_logic::count_drivers(unsigned bit_idx, unsigned counts[3])
{
      for (unsigned idx = 0 ; idx < nports_ ; idx += 1) {
	    if (val_[idx].size() == 0)
	          continue;

            update_driver_counts(val_[idx].value(bit_idx).value(), counts);
      }
}


resolv_triand::resolv_triand(unsigned nports, vvp_net_t*net)
: resolv_wired_logic(nports, net)
{
}

resolv_triand::~resolv_triand()
{
}

resolv_trior::resolv_trior(unsigned nports, vvp_net_t*net)
: resolv_wired_logic(nports, net)
{
}

resolv_trior::~resolv_trior()
{
}

/*
 * The trireg charge storage. See resolv.h for the model.
 */
vvp_fun_trireg::vvp_fun_trireg(vvp_net_t*net, unsigned wid, unsigned charge,
			       bool has_decay, vvp_time64_t decay,
			       bool has_feedback)
: net_(net), wid_(wid), charge_(charge), has_decay_(has_decay), decay_(decay),
  has_feedback_(has_feedback), store_(wid, BIT4_X), hold_(wid, false),
  gen_(wid, 0)
{
	// A decay time from a net is in the time units of the scope, as
	// for a .delay with net inputs.
      const __vpiScope*scope = vpip_peek_current_scope();
      round_ = 1;
      for (int lp = scope->time_units - scope->time_precision; lp > 0; lp -= 1)
	    round_ *= 10;
      scale_ = 1;
      for (int lp = scope->time_precision - vpip_get_time_precision(); lp > 0; lp -= 1)
	    scale_ *= 10;

	// The net starts as x at the charge strength, whether or not a
	// driver ever sends anything.
      schedule_init_vector(vvp_net_ptr_t(net, 3), vvp_vector4_t(1, BIT4_X));
}

vvp_fun_trireg::~vvp_fun_trireg()
{
}

namespace {
struct trireg_decay_event : public vvp_gen_event_s {
      vvp_fun_trireg*fun;
      std::vector<std::pair<unsigned,unsigned> > bits;
      void run_run() override { fun->decay(bits); }
};
}

void vvp_fun_trireg::recv_vec4(vvp_net_ptr_t port, const vvp_vector4_t&bit,
			       vvp_context_t)
{
      switch (port.port()) {
	  case 2: {
		vvp_time64_t val = 0;
		vector4_to_value(bit, val);
		decay_ = val * round_ * scale_;
		return;
	  }
	  case 3:
	    update_();
	    return;
	  default:
	    recv_vec8(port, vvp_vector8_t(bit, 6,6 /* STRONG */));
	    return;
      }
}

void vvp_fun_trireg::recv_real(vvp_net_ptr_t port, double bit, vvp_context_t)
{
      if (port.port() != 2 || bit < 0)
	    return;
      decay_ = (vvp_time64_t) (bit * round_ + 0.5) * scale_;
}

void vvp_fun_trireg::recv_vec8(vvp_net_ptr_t port, const vvp_vector8_t&bit)
{
      if (port.port() > 1)
	    return;
      assert(bit.size() == wid_);

      (port.port() == 0 ? drv_ : fb_) = bit;

	// The store follows the value of the net: what a driver puts on
	// it, and in an island what the island makes of it.
      for (unsigned idx = 0 ; idx < wid_ ; idx += 1) {
	    if (! bit.value(idx).is_hiz())
		  store_.set_bit(idx, bit.value(idx).value());
      }
      update_();
}

void vvp_fun_trireg::decay(const std::vector<std::pair<unsigned,unsigned> >&bits)
{
      bool changed = false;
      for (size_t idx = 0 ; idx < bits.size() ; idx += 1) {
	    unsigned bit = bits[idx].first;
	    if (!hold_[bit] || gen_[bit] != bits[idx].second)
		  continue;
	    if (store_.value(bit) == BIT4_0 || store_.value(bit) == BIT4_1) {
		  store_.set_bit(bit, BIT4_X);
		  changed = true;
	    }
      }
      if (changed)
	    update_();
}

void vvp_fun_trireg::update_()
{
      vvp_vector8_t out (wid_);
      trireg_decay_event*ev = 0;

      for (unsigned idx = 0 ; idx < wid_ ; idx += 1) {
	    vvp_scalar_t drv = drv_.size() ? drv_.value(idx) : vvp_scalar_t();
	    vvp_scalar_t bit = drv.is_hiz()
		  ? vvp_scalar_t(store_.value(idx), charge_, charge_)
		  : drv;
	    out.set_bit(idx, bit);

	    bool hold = drv.is_hiz()
		  && (!has_feedback_
		      || (fb_.size() && fb_.value(idx).eeq(bit)));
	    if (hold == hold_[idx])
		  continue;
	    hold_[idx] = hold;
	    gen_[idx] += 1;
	    if (hold && has_decay_
		&& (store_.value(idx) == BIT4_0 || store_.value(idx) == BIT4_1)) {
		  if (ev == 0) {
			ev = new trireg_decay_event;
			ev->fun = this;
		  }
		  ev->bits.push_back(std::make_pair(idx, gen_[idx]));
	    }
      }

      if (ev)
	    schedule_generic(ev, decay_, false, true, true);

      if (out.eeq(out_))
	    return;
      out_ = out;
      net_->send_vec8(out_);
}
