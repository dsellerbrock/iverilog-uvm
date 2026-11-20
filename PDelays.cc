/*
 * Copyright (c) 1999-2025 Stephen Williams (steve@icarus.com)
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

# include  "PDelays.h"
# include  "PExpr.h"
# include  "verinum.h"
# include  "netmisc.h"
# include  "netstruct.h"

using namespace std;

PDelays::PDelays()
{
      delete_flag_ = true;
      for (unsigned idx = 0 ;  idx < 3 ;  idx += 1)
	    delay_[idx] = 0;
}

PDelays::~PDelays()
{
      if (delete_flag_) {
	    for (unsigned idx = 0 ;  idx < 3 ;  idx += 1)
		  delete delay_[idx];
      }
}

void PDelays::set_delay(PExpr*del)
{
      assert(del);
      assert(delay_[0] == 0);
      delay_[0] = del;
      delete_flag_ = true;
}


void PDelays::set_delays(const list<PExpr*>*del, bool df)
{
      assert(del);
      assert(del->size() <= 3);

      list<PExpr*>::const_iterator cur = del->begin();
      for (unsigned idx = 0 ;  cur != del->end() ;  idx += 1, ++cur)
	    delay_[idx] = *cur;

      delete_flag_ = df;
}

unsigned PDelays::delay_count() const
{
      unsigned dly_cnt = 0;
      for (unsigned idx = 0 ;  idx < 3 ;  idx += 1)
	    if (delay_[idx]) dly_cnt += 1;

      return dly_cnt;
}

static NetExpr*calculate_val(Design*des, NetScope*scope, PExpr*expr)
{
      const PEFNumber*real_expr = dynamic_cast<const PEFNumber*>(expr);
      if (real_expr && real_expr->is_one_step()) {
	    NetEConst*delay = new NetEConst(verinum(uint64_t(1), 64));
	    delay->set_line(*expr);
	    return delay;
      }

      NetExpr*dex = elab_and_eval(des, scope, expr, -1);

      check_for_inconsistent_delays(scope);

	/* If the delay expression is a real constant or vector
	   constant, then evaluate it, scale it to the local time
	   units, and return an adjusted value. */

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

	/* Oops, cannot evaluate down to a constant. */
      return dex;
}

// A continuous-assignment delay can read unindexed numeric fields of a
// static unpacked struct directly from its object storage at an RHS change.
static bool is_struct_delay_member(const NetEProperty*member)
{
      if (!member || (member->expr_type() != IVL_VT_REAL
		      && !type_is_vectorable(member->expr_type())))
	    return false;

      while (member) {
	    if (member->get_index())
		  return false;
	    const NetNet*sig = member->get_sig();
	    const NetExpr*base = member->get_base();
	    const auto*owner = dynamic_cast<const netstruct_t*>(
		  sig ? sig->net_type() : base->net_type());
	    if (!owner || owner->packed() || owner->union_flag())
		  return false;

	    if (const auto*root = dynamic_cast<const NetESignal*>(base)) {
		  if (root->word_index())
			return false;
		  sig = root->sig();
	    }
	    if (sig)
		  return sig->type() == NetNet::REG
			&& sig->port_type() != NetNet::PREF
			&& sig->unpacked_dimensions() == 0
			&& sig->lifetime_override() != IVL_VLT_AUTOMATIC
			&& (sig->lifetime_override() == IVL_VLT_STATIC
			    || !sig->scope()->is_auto());
	    member = dynamic_cast<const NetEProperty*>(base);
      }
      return false;
}

static NetExpr* make_delay_nets(Design*des, NetScope*scope, NetExpr*expr,
			       PDelays::mode_t mode)
{
      if (expr == 0)
            return 0;

      if (mode == PDelays::CONTINUOUS_ASSIGN
	  && is_struct_delay_member(dynamic_cast<const NetEProperty*>(expr)))
	    return expr;

      if (NetESignal*sig = dynamic_cast<NetESignal*> (expr))
	    if (!sig->word_index()) return expr;

      if (dynamic_cast<NetEConst*> (expr))
	    return expr;

      NetNet*sig = expr->synthesize(des, scope, expr);
      if (sig == 0) {
	    cerr << expr->get_fileline() << ": error: Expression " << *expr
		 << " is not suitable as a delay expression." << endl;
	    des->errors += 1;
	    delete expr;
	    return 0;
      }

      /* synthesize() consumes neither the root expression nor this caller's
       * ownership. Nodes added to Design copy the expression's LineInfo and
       * do not retain the NetExpr pointer, so release it on both paths. */
      delete expr;
      expr = new NetESignal(sig);
      return expr;
}

static NetExpr* calc_decay_time(NetExpr *rise, NetExpr *fall)
{
      const NetEConst *c_rise = dynamic_cast<NetEConst*>(rise);
      const NetEConst *c_fall = dynamic_cast<NetEConst*>(fall);
      if (c_rise && c_fall) {
	    if (c_rise->value() < c_fall->value()) return rise;
	    else return fall;
      }

      return 0;
}

void PDelays::eval_delays(Design*des, NetScope*scope,
			  NetExpr*&rise_time,
			  NetExpr*&fall_time,
			  NetExpr*&decay_time,
			  mode_t mode) const
{
      assert(scope);


      if (delay_[0]) {
	    rise_time = calculate_val(des, scope, delay_[0]);
	    if (mode != EXPRESSIONS)
		  rise_time = make_delay_nets(des, scope, rise_time, mode);

	    if (delay_[1]) {
		  fall_time = calculate_val(des, scope, delay_[1]);
		  if (mode != EXPRESSIONS)
			fall_time = make_delay_nets(des, scope, fall_time, mode);

		  if (delay_[2]) {
			decay_time = calculate_val(des, scope, delay_[2]);
			if (mode != EXPRESSIONS)
			      decay_time = make_delay_nets(des, scope,
			                                   decay_time, mode);

		  } else {
			// If this is zero then we need to do the min()
			// at run time.
			decay_time = calc_decay_time(rise_time, fall_time);
		  }
	    } else {
		  assert(delay_[2] == 0);
		  fall_time = rise_time;
		  decay_time = rise_time;
	    }
      } else {
	    rise_time = 0;
	    fall_time = 0;
	    decay_time = 0;
      }
}
