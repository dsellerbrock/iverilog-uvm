/*
 * Copyright (c) 2000-2021 Stephen Williams (steve@icarus.com)
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

# include  <set>

# include  "netlist.h"
# include  "netmisc.h"
# include  "ivl_assert.h"

using namespace std;

namespace {

class nexus_recursion_guard_t {

    public:
      nexus_recursion_guard_t(set<const Nexus*>&active, unsigned&depth,
			      const Nexus*nexus)
      : active_(active), depth_(depth), nexus_(nexus), owner_(false)
      {
	    /* Bound acyclic as well as cyclic traversal. A pathologically deep
	     * fixed-select/substitute chain must not exhaust the compiler stack. */
	    static const unsigned max_depth = 512;
	    if (depth_ < max_depth && active_.insert(nexus_).second) {
		  depth_ += 1;
		  owner_ = true;
	    }
      }

      ~nexus_recursion_guard_t()
      {
	    if (owner_) {
		  depth_ -= 1;
		  active_.erase(nexus_);
	    }
      }

      bool owner() const { return owner_; }

    private:
      set<const Nexus*>&active_;
      unsigned&depth_;
      const Nexus*nexus_;
      bool owner_;
};

static bool fixed_part_select_output_(const Link*link,
				       const NetPartSelect*&part)
{
      part = dynamic_cast<const NetPartSelect*>(link->get_obj());
      return part && part->dir() == NetPartSelect::VP
	    && part->pin_count() == 2 && link->get_pin() == 0;
}

static bool part_select_in_range_(const NetPartSelect*part,
				   unsigned source_width)
{
      return part->width() != 0 && part->base() <= source_width
	    && part->width() <= source_width-part->base();
}

static bool fixed_part_select_shape_(const Nexus*output,
				      const NetPartSelect*part)
{
      const Nexus*source = part->pin(1).nexus();
      if (!source || !part_select_in_range_(part, source->vector_width()))
	    return false;

	/* A nexus with no NetNet has no independently declared output width.
	 * Otherwise the selected driver must cover that complete vector. */
      unsigned output_width = output->vector_width();
      return output_width == 0 || output_width == part->width();
}

static verinum unknown_vector_(const Nexus*nexus)
{
      return verinum(verinum::Vx, nexus->vector_width());
}

}

/*
 * Scan the link for drivers. If there are only constant drivers, then
 * the nexus has a known constant value.
 */
bool Nexus::drivers_constant() const
{
      if (driven_ == VAR)
	    return false;
      if (driven_ != NO_GUESS)
	    return true;

	/* NetPartSelect outputs can form a cycle when a zero-delay continuous
	 * assignment nexus-merges a fixed select with its source. Such a graph is
	 * legal, but it is not a provable constant. Stop at the first revisit and
	 * let every caller on that path conservatively cache VAR. */
      static thread_local set<const Nexus*> active_queries;
      static thread_local unsigned active_depth = 0;
      nexus_recursion_guard_t recursion(active_queries, active_depth, this);
      if (!recursion.owner()) {
	    driven_ = VAR;
	    return false;
      }

      unsigned constant_drivers = 0;
      for (const Link*cur = first_nlink() ; cur  ;  cur = cur->next_nlink()) {

	      /* A target of a procedural assign or force statement
		 can't be treated as constant. */
	    const NetNet*sig = dynamic_cast<const NetNet*>(cur->get_obj());
	    if (sig && (sig->peek_lref() > 0)) {
		  driven_ = VAR;
		  return false;
	    }

	      /* If we are connected to a tran, there may be a driver
		 on the other side of the tran. We could try checking
		 for this, but for now, be pessimistic. */
	    if (dynamic_cast<const NetTran*>(cur->get_obj())) {
		  driven_ = VAR;
		  return false;
	    }

	    Link::DIR cur_dir = cur->get_dir();
	    if (cur_dir == Link::INPUT)
		  continue;

	      /* If this is an input or inout port of a root module,
		 then this is probably not a constant value. I
		 certainly don't know what the value is, anyhow. This
		 can happen in cases like this:

		 module main(sig);
		     input sig;
		 endmodule

		 If main is a root module (it has no parent) then sig
		 is not constant because it connects to an unspecified
		 outside world. */

	    if (cur_dir == Link::PASSIVE) {
		  if (sig == 0 || sig->scope()->parent() != 0)
			continue;

		  if (sig->port_type() == NetNet::NOT_A_PORT)
			continue;

		  if (sig->port_type() == NetNet::POUTPUT)
			continue;

		  driven_ = VAR;
		  return false;
	    }

	      /* If there is an implicit pullup/pulldown on a net,
		 count it as a constant driver. */
	    if (sig)
		  switch (sig->type()) {
		      case NetNet::SUPPLY0:
		      case NetNet::TRI0:
			constant_drivers += 1;
			driven_ = V0;
			continue;
		      case NetNet::SUPPLY1:
		      case NetNet::TRI1:
			constant_drivers += 1;
			driven_ = V1;
			continue;
		      default:
			break;
		  }

	    const NetPartSelect*part = 0;
	    if (fixed_part_select_output_(cur, part)) {
		  const Nexus*source = part->pin(1).nexus();
		  if (fixed_part_select_shape_(this, part)
		      && source->drivers_constant()) {
			constant_drivers += 1;
			continue;
		  }
		  driven_ = VAR;
		  return false;
	    }

	    const NetSubstitute*ps = dynamic_cast<const NetSubstitute*>(cur->get_obj());
	    if (ps) {
		  if (ps->pin(1).nexus()->drivers_constant() &&
		      ps->pin(2).nexus()->drivers_constant() ) {
			constant_drivers += 1;
			continue;
		  }
		  driven_ = VAR;
		  return false;
	    }

	    if (! dynamic_cast<const NetConst*>(cur->get_obj())) {
		  driven_ = VAR;
		  return false;
	    }

	    constant_drivers += 1;
      }

	/* If there is more than one constant driver for this nexus, we
	   would need to resolve the constant value, taking into account
	   the drive strengths. This is a lot of work for something that
	   will rarely occur, so for now leave the resolution to be done
	   at run time. */
      if (constant_drivers > 1) {
	    driven_ = VAR;
	    return false;
      }

      return true;
}

verinum::V Nexus::driven_value() const
{
	/* Preserve the public contract even for a defensive caller: a variable or
	 * cyclic driver has no constant scalar value. Normal callers test
	 * drivers_constant() before asking for the value. */
      if (!drivers_constant())
	    return verinum::Vx;

      switch (driven_) {
	  case V0:
	    return verinum::V0;
	  case V1:
	    return verinum::V1;
	  case Vx:
	    return verinum::Vx;
	  case Vz:
	    return verinum::Vz;
	  case VAR:
	    assert(0);
	    break;
	  case NO_GUESS:
	    break;
      }

      const Link*cur = list_;

      verinum::V val = verinum::Vz;

      for (cur = first_nlink() ; cur  ;  cur = cur->next_nlink()) {

	    const NetPartSelect*part;
	    const NetConst*obj;
	    const NetNet*sig;
	    if ((obj = dynamic_cast<const NetConst*>(cur->get_obj()))) {
		    // Multiple drivers are not currently supported.
		  ivl_assert(*obj, val == verinum::Vz);
		  val = obj->value(cur->get_pin());

	    } else if (fixed_part_select_output_(cur, part)) {
		    // Multiple drivers are not currently supported.
		  ivl_assert(*part, val == verinum::Vz);
		  const Nexus*source_nexus = part->pin(1).nexus();
		  if (!fixed_part_select_shape_(this, part))
			return verinum::Vx;
		  verinum source = source_nexus->driven_vector();
		  if (!part_select_in_range_(part, source.len()))
			return verinum::Vx;
		  val = source.get(part->base());

	    } else if ((sig = dynamic_cast<const NetNet*>(cur->get_obj()))) {

		    // If we find an implicit pullup or pulldown on a
		    // net, this is a good guess for the driven value,
		    // but keep looking for other drivers.
		  if ((sig->type() == NetNet::SUPPLY0) ||
		      (sig->type() == NetNet::TRI0)) {
			  // Multiple drivers are not currently supported.
			ivl_assert(*sig, val == verinum::Vz);
			val = verinum::V0;
		  }
		  if ((sig->type() == NetNet::SUPPLY1) ||
		      (sig->type() == NetNet::TRI1)) {
			  // Multiple drivers are not currently supported.
			ivl_assert(*sig, val == verinum::Vz);
			val = verinum::V1;
		  }
	    }
      }

	/* Cache the result. */
      switch (val) {
	  case verinum::V0:
	    driven_ = V0;
	    break;
	  case verinum::V1:
	    driven_ = V1;
	    break;
	  case verinum::Vx:
	    driven_ = Vx;
	    break;
	  case verinum::Vz:
	    driven_ = Vz;
	    break;
      }

      return val;
}


verinum Nexus::driven_vector() const
{
	/* This also makes a direct value query cycle-safe. The documented caller
	 * contract is to ask drivers_constant() first, but returning X here is a
	 * conservative result if a future caller omits that gate. */
      if (!drivers_constant())
	    return unknown_vector_(this);

      const Link*cur = list_;

      verinum val;
      verinum pval;
      unsigned width = 0;

      for (cur = first_nlink() ; cur  ;  cur = cur->next_nlink()) {

	    const NetPartSelect*part;
	    const NetSubstitute*ps;
	    const NetConst*obj;
	    const NetNet*sig;
	    if ((obj = dynamic_cast<const NetConst*>(cur->get_obj()))) {
		    // Multiple drivers are not currently supported.
		  ivl_assert(*obj, val.len() == 0);
		  ivl_assert(*obj, cur->get_pin() == 0);
		  val = obj->value();
		  width = val.len();

	    } else if (fixed_part_select_output_(cur, part)) {
		    // A fixed vector-to-part projection of a constant remains a
		    // constant. This occurs when synthesis shares a concatenated
		    // r-value and gives each l-value leaf a static slice.
		  ivl_assert(*part, val.len() == 0);
		  const Nexus*source_nexus = part->pin(1).nexus();
		  if (!fixed_part_select_shape_(this, part))
			return unknown_vector_(this);
		  verinum source = source_nexus->driven_vector();
		  if (!part_select_in_range_(part, source.len()))
			return unknown_vector_(this);
		  val = verinum(verinum::Vx, part->width());
		  for (unsigned idx = 0; idx < part->width(); idx += 1)
			val.set(idx, source.get(part->base()+idx));
		  width = val.len();

	    } else if ((ps = dynamic_cast<const NetSubstitute*>(cur->get_obj()))) {
		  if (cur->get_pin() != 0)
			continue;

		    // Multiple drivers are not currently supported.
		  ivl_assert(*ps, val.len() == 0);
		  val  = ps->pin(1).nexus()->driven_vector();
		  pval = ps->pin(2).nexus()->driven_vector();
		  for (unsigned idx = 0; idx < pval.len(); idx += 1)
			val.set(ps->base() + idx, pval.get(idx));
		  width = val.len();

	    } else if ((sig = dynamic_cast<const NetNet*>(cur->get_obj()))) {

		  width = sig->vector_width();

		    // If we find an implicit pullup or pulldown on a
		    // net, this is a good guess for the driven value,
		    // but keep looking for other drivers.
		  if ((sig->type() == NetNet::SUPPLY0) ||
		      (sig->type() == NetNet::TRI0)) {
			  // Multiple drivers are not currently supported.
			ivl_assert(*sig, val.len() == 0);
			val = verinum(verinum::V0, width);
		  }
		  if ((sig->type() == NetNet::SUPPLY1) ||
		      (sig->type() == NetNet::TRI1)) {
			  // Multiple drivers are not currently supported.
			ivl_assert(*sig, val.len() == 0);
			val = verinum(verinum::V1, width);
		  }
	    }
      }

	// If we have a width but not a value, this must be an undriven net.
      if (val.len() != width)
	    val = verinum(verinum::Vz, width);

      return val;
}

/*
 * Calculate a vector that represent all the bits of the vector, with
 * each driven bit set to true, otherwise false.
 */
vector<bool> Nexus::driven_mask(void) const
{
      vector<bool> mask (vector_width());

      for (const Link*cur = first_nlink() ; cur ; cur = cur->next_nlink()) {

	    Link::DIR link_dir = cur->get_dir();
	    if (link_dir==Link::PASSIVE)
		  continue;
	    if (link_dir==Link::INPUT)
		  continue;

	    const NetPins*obj = cur->get_obj();

	      // If the link is to a variable (REG or INTEGER) then
	      // the variable is driving all the bits. We have our
	      // complete answer, mark all the bits as driven and
	      // finish. Otherwise, we are not going to get new
	      // information from this node, move on.
	    if (const NetNet*sig = dynamic_cast<const NetNet*> (obj)) {
		  NetNet::Type sig_type = sig->type();
		  if (sig_type==NetNet::REG) {
			for (size_t idx = 0 ; idx < mask.size() ; idx += 1)
			      mask[idx] = true;
			return mask;
		  }
		  continue;
	    }

	    const NetPartSelect*obj_ps = dynamic_cast<const NetPartSelect*>(obj);
	    if(obj_ps) {
		  if (obj_ps->dir()==NetPartSelect::VP) {
			if(cur->get_pin() != 0)
			      continue;
			for (size_t idx = 0 ; idx < mask.size() ; idx += 1)
			      mask[idx] = true;
			return mask;
		  } else {
			if (cur->get_pin() != 1)
			      continue;
		  }
		  for (unsigned idx = 0 ; idx < obj_ps->width() ; idx += 1) {
			size_t bit = idx + obj_ps->base();
			ivl_assert(*obj, bit < mask.size());
			mask[bit] = true;
		  }
		  continue;
	    }

	    for (size_t idx = 0 ; idx < mask.size() ; idx += 1)
		  mask[idx] = true;
	    return mask;
      }

      return mask;
}
