/*
 * Copyright (c) 2008-2025 Stephen Williams (steve@icarus.com)
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

# include  "vvp_island.h"
# include  "compile.h"
# include  "symbols.h"
# include  "schedule.h"
# include  "resolv.h"
# include  "vpi_priv.h"
# include  <list>

# include  "delay.h"
# include  <algorithm>
# include  <bitset>
# include  <iostream>
# include  <map>
# include  <queue>
# include  <set>

using namespace std;

class vvp_island_tran : public vvp_island {

    public:
      void run_island(vvp_net_t*released) override;
      void count_drivers(vvp_island_port*port, unsigned bit_idx,
                         unsigned counts[3]) override;
      bool link_evcd_branches() override;
      void evcd_drivers(const evcd_island_endpoint&endpoint,
			const __vpiScope*scope, unsigned bit,
			evcd_island_side sides[2]) const override;
};

enum tran_state_t {
      tran_disabled,
      tran_enabled,
      tran_unknown
};

struct vvp_island_branch_tran : public vvp_island_branch {

      vvp_island_branch_tran(vvp_net_t*en__, bool active_high__,
                             unsigned width__, unsigned part__,
                             unsigned offset__, bool resistive__);
      void run_test_enabled();
      bool rerun_test_enabled(bool use_scratch = false);
      void run_resolution(island_channel channel);
      void run_output(vvp_net_t*released);

      vvp_net_t*en;
      unsigned width, part, offset;
      bool active_high, resistive;
      tran_state_t state;
      bool evcd_physical = false;

	// SDF INTERCONNECT (IEEE 1800 32.4.4): when set, values do not
	// cross this branch instantly. Each channel delays the side's
	// own drive before injecting it into the opposite port.
      struct delayed_channel {
	    vvp_net_t*out[2] = { nullptr, nullptr };
	    vvp_vector8_t sent[2];
      };
      delayed_channel visible_delay;
      delayed_channel charge_delay;
      bool delayed() const { return visible_delay.out[0] != nullptr; }
      delayed_channel& delay(island_channel channel)
      { return channel == island_channel::charge ? charge_delay : visible_delay; }
};

vvp_island_branch_tran::vvp_island_branch_tran(vvp_net_t*en__,
                                               bool active_high__,
                                               unsigned width__,
                                               unsigned part__,
                                               unsigned offset__,
                                               bool resistive__)
: en(en__), width(width__), part(part__), offset(offset__),
  active_high(active_high__), resistive(resistive__)
{
      state = en__ ? tran_disabled : tran_enabled;
}

static inline vvp_island_branch_tran* BRANCH_TRAN(vvp_island_branch*tmp)
{
      vvp_island_branch_tran*res = dynamic_cast<vvp_island_branch_tran*>(tmp);
      assert(res);
      return res;
}

/*
 * The value side SIDE of the delayed branch BR drives toward the other
 * side: everything reachable from that end through instant branches,
 * without what BR itself injects there. Sending the fully resolved value
 * instead would echo the other side's delayed value back to it.
 */
static vvp_vector8_t own_value_(vvp_island_branch_tran*br, unsigned side,
				island_channel channel)
{
      vvp_vector8_t val;
      set<vvp_net_t*> seen;
      list<vvp_branch_ptr_t> work;
      work.push_back(vvp_branch_ptr_t(br, side));
      seen.insert(side ? br->b : br->a);
      while (!work.empty()) {
	    vvp_branch_ptr_t cur = work.front();
	    work.pop_front();
	    vvp_net_t*net = cur.port() ? cur.ptr()->b : cur.ptr()->a;
	    vvp_vector8_t in = island_get_input(net, channel, br);
	    if (in.size() != 0)
		  val = val.size() == 0 ? in
			: val.size() == in.size() ? resolve(val, in) : val;

	    list<vvp_branch_ptr_t> node;
	    island_collect_node(node, cur);
	    for (vvp_branch_ptr_t end : node) {
		  vvp_island_branch_tran*other = BRANCH_TRAN(end.ptr());
		  if (other->state == tran_disabled || other->delayed()
		      || other->width != 0)
			continue;
		  vvp_branch_ptr_t far(other, end.port()^1);
		  vvp_net_t*far_net = far.port() ? other->b : other->a;
		  if (seen.insert(far_net).second)
			work.push_back(far);
	    }
      }
      return val;
}

static void send_own_value_(vvp_island_branch_tran*br, unsigned side,
			    island_channel channel)
{
      auto&delay = br->delay(channel);
      vvp_vector8_t val = own_value_(br, side, channel);
      if (val.size() == 0 || val.eeq(delay.sent[side]))
	    return;
      delay.sent[side] = val;
      vvp_net_t*out = delay.out[side];
      out->fun->recv_vec8(vvp_net_ptr_t(out, 0), val);
}

static void send_own_values_(vvp_island_branch*branches, bool with_charge)
{
      for (vvp_island_branch*cur = branches ; cur ; cur = cur->next_branch) {
	    vvp_island_branch_tran*br = BRANCH_TRAN(cur);
	    if (!br->delayed())
		  continue;
	    for (unsigned side = 0 ; side < 2 ; side += 1) {
		  send_own_value_(br, side, island_channel::visible);
		  if (with_charge)
			send_own_value_(br, side, island_channel::charge);
	    }
      }
}

static void clear_resolution_(vvp_island_branch*branches, island_channel channel)
{
      for (vvp_island_branch*cur = branches ; cur ; cur = cur->next_branch) {
	    static_cast<vvp_island_port*>(cur->a->fun)->resolution_value(channel)
		  = vvp_vector8_t::nil;
	    static_cast<vvp_island_port*>(cur->b->fun)->resolution_value(channel)
		  = vvp_vector8_t::nil;
      }
}

/*
 * The run_island() method is called by the scheduler to run the
 * entire island. We run the island by calling run_resolution() for
 * all the branches in the island.
*/
void vvp_island_tran::run_island(vvp_net_t*released)
{
	// Test to see if any of the branches are enabled. This loop
	// tests the enabled inputs for all the branches and caches
	// the results in the state for each branch.
      for (vvp_island_branch*cur = branches_ ; cur ; cur = cur->next_branch) {
	    vvp_island_branch_tran*tmp = dynamic_cast<vvp_island_branch_tran*>(cur);
	    assert(tmp);
	    tmp->run_test_enabled();
      }

      const bool with_charge = has_charge_feedback();
      unsigned long passes = 0;
rerun:
	// A network with no fixed point (a switch whose control it drives
	// off) would loop here forever; stop past the settle limit (#3472).
      if (settle_exceeded(++passes))
	    return;

	// Now resolve all the branches in the island.
      for (vvp_island_branch*cur = branches_ ; cur ; cur = cur->next_branch)
	    BRANCH_TRAN(cur)->run_resolution(island_channel::visible);

      if (with_charge) {
	      // Settle the observable switch controls before updating any
	      // stored charge. Both traversals use those same switch states.
	    bool enable_changed = false;
	    for (vvp_island_branch*cur = branches_ ; cur ; cur = cur->next_branch)
		  enable_changed |= BRANCH_TRAN(cur)->rerun_test_enabled(true);
	    if (enable_changed) {
		  clear_resolution_(branches_, island_channel::visible);
		  goto rerun;
	    }

	    for (vvp_island_branch*cur = branches_ ; cur ; cur = cur->next_branch)
		  BRANCH_TRAN(cur)->run_resolution(island_channel::charge);

	      // Feedback can change the port inputs. Deliver it only after
	      // the traversal, so every trireg sees the same resolution.
	    bool charge_changed = false;
	    for (auto*port : charge_ports_)
		  charge_changed |= port->send_charge_feedback();
	    clear_resolution_(branches_, island_channel::charge);
	    if (charge_changed) {
		  clear_resolution_(branches_, island_channel::visible);
		  goto rerun;
	    }
      }

	// Now output the resolved values.
      for (vvp_island_branch*cur = branches_ ; cur ; cur = cur->next_branch)
	    BRANCH_TRAN(cur)->run_output(released);

      send_own_values_(branches_, with_charge);
      if (with_charge)
	    return;

	// Now check if the enable inputs have been affected by the resolution.
      bool enable_changed = false;
      for (vvp_island_branch*cur = branches_ ; cur ; cur = cur->next_branch) {
	    vvp_island_branch_tran*tmp = dynamic_cast<vvp_island_branch_tran*>(cur);
	    assert(tmp);
	    enable_changed |= tmp->rerun_test_enabled();
      }
      if (enable_changed) goto rerun;
}

static void count_drivers_(vvp_branch_ptr_t cur, bool other_side_visited,
                           unsigned bit_idx, unsigned counts[3])
{
        // First count any value driven into the port associated with
        // the current endpoint.
      vvp_net_t*net = cur.port() ? cur.ptr()->b : cur.ptr()->a;
      vvp_scalar_t bit = island_get_value(net).value(bit_idx);
      update_driver_counts(bit.value(), counts);

        // Now handle all the branches attached to that port.
      vvp_branch_ptr_t idx = cur;
      do {
            vvp_island_branch_tran*tmp = BRANCH_TRAN(idx.ptr());

              // If this branch represents a tran gate, we count the
              // value on the other side of the tran (providing it is
              // enabled) as a single driver.
            if (tmp->width == 0) {
                  if (tmp->state == tran_enabled) {
                        net = idx.port() ? idx.ptr()->a : idx.ptr()->b;
                        bit = island_get_sent_value(net).value(bit_idx);
                        update_driver_counts(bit.value(), counts);
                  }
                  continue;
            }

              // If we get here, this branch is a part select. If we've
              // just come from the other end of the branch, we're done.
            if ((idx == cur) && other_side_visited)
                  continue;

              // If this is the narrow end of the part select, the other
              // end must include the bit we are interested in. Follow
              // the branch to collect any drivers on the other side.
            if (idx.port() == 1) {
                  vvp_branch_ptr_t a_side(tmp, 0);
                  count_drivers_(a_side, true, tmp->offset + bit_idx, counts);
                  continue;
            }

              // If we get here, this branch is the wide end of a part
              // select. If the bit we are interested in is within the
              // selected part, follow the branch to collect any drivers
              // on the other side.
            if ((bit_idx >= tmp->offset) && (bit_idx < tmp->offset+tmp->part)) {
                  vvp_branch_ptr_t b_side(tmp, 1);
                  count_drivers_(b_side, true, bit_idx - tmp->offset, counts);
                  continue;
            }
      } while ((idx = next(idx)) != cur);
}

void vvp_island_tran::count_drivers(vvp_island_port*port, unsigned bit_idx,
                                    unsigned counts[3])
{
        // First we need to find a branch that is attached to the specified
        // port. Unfortunately there's no quick way to do this.
      vvp_island_branch*branch = branches_;
      unsigned side = 0;
      while (branch) {
            if (branch->a->fun == port) {
                  side = 0;
                  break;
            }
            if (branch->b->fun == port) {
                  side = 1;
                  break;
            }
            branch = branch->next_branch;
      }
      assert(branch);

        // Now count the drivers, pushing through the network as necessary.
      vvp_branch_ptr_t endpoint(branch, side);
      count_drivers_(endpoint, false, bit_idx, counts);
}

bool vvp_island_tran::link_evcd_branches()
{
      for (vvp_island_branch*cur = branches_; cur; cur = cur->next_branch) {
	    const auto*branch = BRANCH_TRAN(cur);
	    auto*a = static_cast<vvp_island_port*>(cur->a->fun)->evcd;
	    auto*b = static_cast<vvp_island_port*>(cur->b->fun)->evcd;
	    if (!a || !b) return false;
	    if (branch->width) {
		  if (branch->width != a->width || branch->part != b->width ||
		      branch->offset >= a->width)
			return false;
	    } else if (a->width != b->width) {
		  return false;
	    }
	    a->anchor = vvp_branch_ptr_t(cur, 0);
	    b->anchor = vvp_branch_ptr_t(cur, 1);
      }
      return true;
}

static unsigned evcd_driver_side(const __vpiScope*owner, const __vpiScope*dut)
{
      for (const __vpiScope*scope = owner; scope; scope = scope->scope)
	    if (scope == dut) return 1;
      return 0;
}

static vvp_scalar_t pass_switch_bit(vvp_scalar_t bit, tran_state_t state,
				    const unsigned str_map[8])
{
      bit = vvp_scalar_t(bit.value(), str_map[bit.strength0()],
			 str_map[bit.strength1()]);
      if (state == tran_unknown) {
	    if (bit.value() == BIT4_0)
		  return vvp_scalar_t(BIT4_X, bit.strength0(), 0);
	    if (bit.value() == BIT4_1)
		  return vvp_scalar_t(BIT4_X, 0, bit.strength1());
      }
      return bit;
}

using evcd_port_bit = std::pair<const vvp_island_port*, unsigned>;

template <typename Visit>
static void evcd_each_peer(const evcd_port_bit&node, Visit visit)
{
      const auto end = node.first->evcd->anchor;
      auto edge = end;
      do {
	    const auto*branch = BRANCH_TRAN(edge.ptr());
	    if (branch->state == tran_disabled || branch->delayed())
		  continue;
	    unsigned bit = node.second;
	    if (branch->width) {
		  if (edge.port()) {
			// The selected part can extend past the wide endpoint.
			if (bit >= branch->width - branch->offset)
			      continue;
			bit += branch->offset;
		  } else {
			if (bit < branch->offset || bit - branch->offset >= branch->part)
			      continue;
			bit -= branch->offset;
		  }
	    }
	    const auto*net = edge.port() ? branch->a : branch->b;
	    visit(evcd_port_bit(static_cast<const vvp_island_port*>(net->fun), bit),
		  *branch);
      } while ((edge = next(edge)) != end);
}

struct evcd_bit_resolution {
      vvp_scalar_t value[2];
      // Four logic states with two three-bit strengths.
      std::bitset<256> scheduled;
};

using evcd_network = std::map<evcd_port_bit, evcd_bit_resolution>;

static vvp_scalar_t evcd_resolve_side(evcd_network&network,
				     evcd_network::iterator observed, unsigned side)
{
      struct update {
	    evcd_network::iterator node;
	    vvp_scalar_t value;
	    unsigned state;
	    unsigned strength;

	    bool operator<(const update&other) const { return strength < other.strength; }
      };
      std::priority_queue<update> work;
      auto enqueue = [&](evcd_network::iterator node) {
	    const auto&value = node->second.value[side];
	    if (value.is_hiz()) return;
	    const unsigned s0 = value.strength0(), s1 = value.strength1();
	    const unsigned state = (value.value() << 6) | (s0 << 3) | s1;
	    if (node->second.scheduled.test(state)) return;
	    node->second.scheduled.set(state);
	    work.push({node, value, state, std::max(s0, s1)});
      };
      for (auto it = network.begin(); it != network.end(); ++it) {
	    it->second.scheduled.reset();
	    enqueue(it);
      }

      // Resolve at each junction before crossing its next switch. Visit
      // stronger changes first so a weaker drive cannot escape a junction
      // before the drive that masks it arrives. Each bit can propagate each
      // of its finite scalar states once.
      while (!work.empty()) {
	    const auto item = work.top();
	    work.pop();
	    if (!item.value.eeq(item.node->second.value[side])) {
		  item.node->second.scheduled.reset(item.state);
		  continue;
	    }
	    evcd_each_peer(item.node->first, [&](const evcd_port_bit&peer,
						const vvp_island_branch_tran&branch) {
		  auto target = network.find(peer);
		  assert(target != network.end());
		  auto value = item.value;
		  if (branch.evcd_physical)
			value = pass_switch_bit(value, branch.state,
						vvp_switch_strength_map[branch.resistive]);
		  auto&dst = target->second.value[side];
		  auto merged = resolve(dst, value);
		  if (merged.eeq(dst)) return;
		  dst = merged;
		  enqueue(target);
	    });
      }
      return observed->second.value[side];
}

void vvp_island_tran::evcd_drivers(const evcd_island_endpoint&endpoint,
				  const __vpiScope*scope, unsigned bit,
				  evcd_island_side sides[2]) const
{
      evcd_network network;
      const auto end = endpoint.anchor;
      const auto*net = end.port() ? end.ptr()->b : end.ptr()->a;
      const auto*observed_port = static_cast<const vvp_island_port*>(net->fun);
      auto observed = network.emplace(evcd_port_bit(observed_port, bit),
				      evcd_bit_resolution()).first;
      std::vector<evcd_network::iterator> work{observed};
      bool physical = false;

      while (!work.empty()) {
	    const auto item = work.back();
	    work.pop_back();
	    const auto*port = item->first.first;
	    const unsigned index = item->first.second;
	    const auto&local = *port->evcd;
	    auto&local_value = item->second.value;
	    // Each endpoint/slot/bit identifies one driver, regardless of the
	    // number of paths to it. Apply local net resolution before transfer.
	    for (unsigned idx = 0; idx < local.sources.size(); idx += 1) {
		  const auto&slot = local.sources[idx];
		  if (index < slot.base || index - slot.base >= slot.width) continue;
		  const unsigned side = evcd_driver_side(slot.scope, scope);
		  sides[side].present = true;
		  vvp_scalar_t value;
		  if (idx == local.driver_count) {
			value = vvp_scalar_t(local.pull == 1 ? BIT4_0 : BIT4_1, 5, 5);
		  } else if (local.resolver) {
			value = local.resolver->evcd_driver(idx, index);
		  } else if (index < port->invalue.size()) {
			value = port->invalue.value(index);
		  }
		  if (value.is_hiz()) continue;
		  sides[side].active += 1;
		  local_value[side] = local.resolver
			? local.resolver->evcd_resolve(local_value[side], value)
			: resolve(local_value[side], value);
	    }
	    for (unsigned side = 0; side < 2; side += 1)
		  sides[side].value = resolve(sides[side].value, local_value[side]);

	    evcd_each_peer(item->first, [&](const evcd_port_bit&peer,
					    const vvp_island_branch_tran&branch) {
		  physical |= branch.evcd_physical;
		  auto entry = network.emplace(peer, evcd_bit_resolution());
		  if (entry.second)
			work.push_back(entry.first);
	    });
      }

      if (physical)
	    for (unsigned side = 0; side < 2; side += 1)
		  sides[side].value = evcd_resolve_side(network, observed, side);
}

void vvp_island_branch_tran::run_test_enabled()
{
      vvp_island_port*ep = en? dynamic_cast<vvp_island_port*> (en->fun) : NULL;

	// If there is no ep port (no "enabled" input) then this is a
	// tran branch. Assume it is always enabled.
      if (ep == 0) {
	    state = tran_enabled;
	    return;
      }

	// Get the input that is driving this enable.
	// SPECIAL NOTE: Try to get the input value from the
	// *outvalue* of the port. If the enable is connected to a
	// .port (instead of a .import) then there may be feedback
	// going on, and we need to be looking at the resolved input,
	// not the event input. For example:
	//
	//   tranif1 (pin, X, pin);
	//
	// In this case, when we test the value for "pin", we need to
	// look at the value that is resolved from this
	// island. Reading the outvalue will do the trick.
	//
	// If the outvalue is nil, then we know that this port is a
	// .import after all, so just read the invalue.
      vvp_bit4_t enable_val;
      if (ep->outvalue.size() != 0)
	    enable_val = ep->outvalue.value(0).value();
      else if (ep->invalue.size() == 0)
	    enable_val = BIT4_Z;
      else
	    enable_val = ep->invalue.value(0).value();

      switch (enable_val) {
	  case BIT4_0:
	    state = active_high ? tran_disabled : tran_enabled;
	    break;
	  case BIT4_1:
	    state = active_high ? tran_enabled : tran_disabled;
	    break;
	  default:
	    state = tran_unknown;
	    break;
      }
}

bool vvp_island_branch_tran::rerun_test_enabled(bool use_scratch)
{
      vvp_island_port*ep = en? dynamic_cast<vvp_island_port*> (en->fun) : NULL;

      if (ep == 0)
	    return false;

	// We are only looking for changes resulting from running the island
	// resolution. An .import has no resolved value.
      const vvp_vector8_t&resolved = use_scratch ? ep->value : ep->outvalue;
      if (resolved.size() == 0)
	    return false;

      vvp_bit4_t enable_val = use_scratch
	    ? island_filter_value(en, resolved).value(0).value()
	    : resolved.value(0).value();

      tran_state_t old_state = state;

      switch (enable_val) {
	  case BIT4_0:
	    state = active_high ? tran_disabled : tran_enabled;
	    break;
	  case BIT4_1:
	    state = active_high ? tran_enabled : tran_disabled;
	    break;
	  default:
	    state = tran_unknown;
	    break;
      }

      return state != old_state;
}

// The IEEE standard does not specify the behaviour when a tranif control
// input is 'x' or 'z'. We use the rules that are given for MOS switches.
inline vvp_vector8_t resolve_ambiguous(const vvp_vector8_t&a,
                                       const vvp_vector8_t&b,
                                       tran_state_t state,
                                       const unsigned str_map[8])
{
      assert(a.size() == b.size());
      vvp_vector8_t out (a.size());

      for (unsigned idx = 0 ;  idx < out.size() ; idx += 1)
	    out.set_bit(idx, resolve(a.value(idx),
				     pass_switch_bit(b.value(idx), state, str_map)));
      return out;
}

static void push_value_through_branches(const vvp_vector8_t&val,
					const list<vvp_branch_ptr_t>&connections,
					island_channel channel);

static void push_value_through_branch(const vvp_vector8_t&val,
                                      vvp_branch_ptr_t cur,
				      island_channel channel)
{
      vvp_island_branch_tran*branch = BRANCH_TRAN(cur.ptr());

        // If the branch is disabled, skip. A delayed branch never
        // carries a value across instantly.
      if (branch->state == tran_disabled || branch->delayed())
            return;

      unsigned src_ab = cur.port();
      unsigned dst_ab = src_ab^1;

      vvp_net_t*dst_net = dst_ab? branch->b : branch->a;
      vvp_island_port*dst_port = dynamic_cast<vvp_island_port*>(dst_net->fun);

      vvp_vector8_t&dst_value = dst_port->resolution_value(channel);
      vvp_vector8_t old_val = dst_value;

        // If the port on the other side has not yet been visited,
        // get its input value.
      if (dst_value.size() == 0)
            dst_value = island_get_input(dst_net, channel);

        // If we don't yet have an initial value for the port, skip.
      if (dst_value.size() == 0)
            return;

        // Now resolve the pushed value with whatever values we have
        // previously collected (and resolved) for the port.
      if (branch->width == 0) {
              // There are no part selects.
            dst_value = resolve_ambiguous(dst_value, val, branch->state,
					  vvp_switch_strength_map[branch->resistive]);

      } else if (dst_ab == 1) {
              // The other side is a strict subset (part select)
              // of this side.
            vvp_vector8_t tmp = val.subvalue(branch->offset, branch->part);
            dst_value = resolve(dst_value, tmp);

      } else {
              // The other side is a superset of this side.
            vvp_vector8_t tmp = part_expand(val, branch->width, branch->offset);
            dst_value = resolve(dst_value, tmp);
      }

        // If the resolved value for the port has changed, push the new
        // value back into the network.
      if (! dst_value.eeq(old_val)) {
            list<vvp_branch_ptr_t> connections;

	    vvp_branch_ptr_t dst_side(branch, dst_ab);
	    island_collect_node(connections, dst_side);

	    push_value_through_branches(dst_value, connections, channel);
      }
}

static void push_value_through_branches(const vvp_vector8_t&val,
					const list<vvp_branch_ptr_t>&connections,
					island_channel channel)
{
      for (list<vvp_branch_ptr_t>::const_iterator idx = connections.cbegin()
		 ; idx != connections.cend() ; ++ idx ) {

            push_value_through_branch(val, *idx, channel);
      }
}

/*
 * This method resolves the value for a branch recursively. It uses
 * recursive descent to span the graph of branches, pushing values
 * through the network until a stable state is reached.
 */
void vvp_island_branch_tran::run_resolution(island_channel channel)
{
	// Push each endpoint's input if the traversal has not reached it yet.
      for (unsigned side = 0 ; side < 2 ; side += 1) {
	    vvp_net_t*net = side ? b : a;
	    auto*port = static_cast<vvp_island_port*>(net->fun);
	    vvp_vector8_t&value = port->resolution_value(channel);
	    if (value.size() != 0)
		  continue;
	    value = island_get_input(net, channel);
	    if (value.size() == 0)
		  continue;
	    list<vvp_branch_ptr_t> connections;
	    island_collect_node(connections, vvp_branch_ptr_t(this, side));
	    push_value_through_branches(value, connections, channel);
      }
}

void vvp_island_branch_tran::run_output(vvp_net_t*released)
{
      vvp_island_port*port;

	// If the A side port hasn't already been updated, send the
        // resolved value to the output.
      port = dynamic_cast<vvp_island_port*>(a->fun);
      if (port->value.size() != 0) {
	    island_send_value(a, port->value, a == released);
	    port->value = vvp_vector8_t::nil;
      }

	// Do the same for the B side port.
      port = dynamic_cast<vvp_island_port*>(b->fun);
      if (port->value.size() != 0) {
	    island_send_value(b, port->value, b == released);
	    port->value = vvp_vector8_t::nil;
      }
}

void compile_island_tran(char*label)
{
      vvp_island*use_island = new vvp_island_tran;
      compile_island_base(label, use_island);
}

void compile_island_tranif(int sense, char*island, char*pa, char*pb, char*pe,
                           bool resistive, char*desc, bool physical)
{
      vvp_island*use_island = compile_find_island(island);
      free(island);

      if (!use_island || !use_island->find_port(pa) || !use_island->find_port(pb)) {
	    fprintf(stderr, "vvp: invalid tran island or endpoint.\n");
	    compile_errors += 1;
	    free(pa);
	    free(pb);
	    free(pe);
	    delete[] desc;
	    return;
      }

      vvp_net_t*en = NULL;

      if (pe) {
	    en = use_island->find_port(pe);
	    assert(en);
	    free(pe);
      }

      vvp_island_branch_tran*br = new vvp_island_branch_tran(en,
                                                             sense ? true :
                                                                     false,
                                                             0, 0, 0, resistive);

      br->desc = desc;
      br->evcd_physical = physical || en || resistive;
      use_island->add_branch(br, pa, pb);

      free(pa);
      free(pb);
}


void compile_island_tranvp(char*island, char*pa, char*pb,
			   unsigned wid, unsigned par, unsigned off)
{
      vvp_island*use_island = compile_find_island(island);
      free(island);

      if (!use_island || !use_island->find_port(pa) || !use_island->find_port(pb) ||
	  !wid || !par || off >= wid) {
	    fprintf(stderr, "vvp: invalid tranvp island, endpoint or range.\n");
	    compile_errors += 1;
	    free(pa);
	    free(pb);
	    return;
      }

      vvp_island_branch_tran*br = new vvp_island_branch_tran(NULL, false,
                                                             wid, par, off, false);

      use_island->add_branch(br, pa, pb);

      free(pa);
      free(pb);
}

/*
 * Receives the delayed value from a branch's intermodpath and drives it
 * into the island port on the far side, as a strong driver: the
 * intermodpath delay works on 4-state values.
 */
class vvp_island_inject : public vvp_net_fun_t {
    public:
      vvp_island_inject(vvp_net_t*port, const void*from, island_channel channel)
      : port_(port), from_(from), channel_(channel) { }
      void recv_vec4(vvp_net_ptr_t, const vvp_vector4_t&bit,
		     vvp_context_t) override
      {
	    vvp_island_port*fun = dynamic_cast<vvp_island_port*>(port_->fun);
	    fun->set_injection(channel_, from_, vvp_vector8_t(bit, 6, 6));
      }
    private:
      vvp_net_t*port_;
      const void*from_;
      island_channel channel_;
};

static vvp_net_t* make_island_delay_(vvp_island_branch_tran*br, unsigned side,
				     unsigned width, island_channel channel,
				     const vvp_fun_intermodpath*timing = nullptr)
{
      vvp_net_t*inj = new vvp_net_t;
      inj->fun = new vvp_island_inject(side ? br->a : br->b, br, channel);
      vvp_net_t*imp = new vvp_net_t;
      imp->fun = new vvp_fun_intermodpath(imp, width, timing);
      imp->out_ = vvp_net_ptr_t(inj, 0);
      return imp;
}

// ponytail: the delayed value crosses as strong 0/1/x/z (intermodpath is
// 4-state); carry strength if an inout interconnect ever needs it.
vvp_fun_intermodpath* island_tran_interconnect(vvp_net_t*inner_port,
					       bool into_inner,
					       unsigned width,
					       vvp_net_t*&path_net)
{
      path_net = 0;
      vvp_island_port*port = dynamic_cast<vvp_island_port*>(inner_port->fun);
      if (!port)
	    return 0;
      vvp_island_branch_tran*br = 0;
      for (vvp_island_branch*cur = port->island()->branches()
		 ; cur ; cur = cur->next_branch) {
	    vvp_island_branch_tran*tmp = dynamic_cast<vvp_island_branch_tran*>(cur);
	    if (tmp && tmp->b == inner_port && !tmp->en && tmp->width == 0) {
		  br = tmp;
		  break;
	    }
      }
      if (!br)
	    return 0;

      if (!br->delayed()) {
	    bool with_charge = port->island()->has_charge_feedback();
	    for (unsigned side = 0 ; side < 2 ; side += 1) {
		  vvp_net_t*visible = make_island_delay_(br, side, width,
							island_channel::visible);
		  br->visible_delay.out[side] = visible;
		  if (with_charge)
			br->charge_delay.out[side] = make_island_delay_(
			      br, side, width, island_channel::charge,
			      static_cast<const vvp_fun_intermodpath*>(visible->fun));
	    }
	      // Send the values present now while the new delays are still
	      // zero, so the annotation delays later changes only, as for an
	      // output-to-input interconnect.
	    for (unsigned side = 0 ; side < 2 ; side += 1) {
		  send_own_value_(br, side, island_channel::visible);
		  if (with_charge)
			send_own_value_(br, side, island_channel::charge);
	    }
	    port->island()->flag_island();
      }
      path_net = br->visible_delay.out[into_inner ? 0 : 1];
      return dynamic_cast<vvp_fun_intermodpath*>(path_net->fun);
}
