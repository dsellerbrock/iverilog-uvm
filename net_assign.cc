/*
 * Copyright (c) 2000-2025 Stephen Williams (steve@icarus.com)
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

# include  "netlist.h"
# include  "netclass.h"
# include  "netdarray.h"
# include  "netparray.h"
# include  "netqueue.h"
# include  "netstruct.h"
# include  "netenum.h"
# include  "netvector.h"
# include  "netmisc.h"
# include  "ivl_assert.h"

using namespace std;

/*
 * NetAssign
 */

unsigned count_lval_width(const NetAssign_*idx)
{
      unsigned wid = 0;
      while (idx) {
	    wid += idx->lwidth();
	    idx = idx->more;
      }
      return wid;
}

NetAssign_::NetAssign_(NetAssign_*n)
: nest_(n), sig_(0), word_(0), base_(0), sel_type_(IVL_SEL_OTHER)
{
      lwid_ = 0;
      more = 0;
      signed_ = false;
      turn_sig_to_wire_on_release_ = false;
}

NetAssign_::NetAssign_(NetNet*s)
: nest_(0), sig_(s), word_(0), base_(0), sel_type_(IVL_SEL_OTHER)
{
      lwid_ = sig_->vector_width();
      sig_->incr_lref();
      sig_->register_lref(this);
      more = 0;
      signed_ = false;
      turn_sig_to_wire_on_release_ = false;
}

NetAssign_::~NetAssign_()
{
      if (sig_) {
	    sig_->unregister_lref(this);
	    sig_->decr_lref();
	    if (turn_sig_to_wire_on_release_ && sig_->peek_lref() == 0)
		  sig_->type(NetNet::WIRE);
      }

      delete more;
      delete nest_;
      delete word_;
      delete base_;
      delete stream_range_first_;
      delete stream_range_second_;
}

void NetAssign_::set_stream_range(ivl_stream_range_t kind, NetExpr*first,
                                  NetExpr*second)
{
      ivl_assert(*this, stream_range_ == IVL_STREAM_RANGE_NONE);
      ivl_assert(*this, first);
      ivl_assert(*this, kind != IVL_STREAM_RANGE_NONE);
      ivl_assert(*this, (kind == IVL_STREAM_RANGE_INDEX) == (second == 0));
      stream_range_ = kind;
      stream_range_first_ = first;
      stream_range_second_ = second;
}

string NetAssign_::get_fileline() const
{
      if (sig_) return sig_->get_fileline();
      else return nest_->get_fileline();
}

NetScope*NetAssign_::scope() const
{
      if (sig_) return sig_->scope();
      else return nest_->scope();
}

void NetAssign_::set_word(NetExpr*r)
{
      ivl_assert(*this, word_ == 0);
      word_ = r;
}

void NetAssign_::set_array_slice(NetExpr*base_word, ivl_type_t slice_type)
{
      ivl_assert(*this, word_ == 0);
      word_ = base_word;
      slice_type_ = slice_type;
}

NetExpr* NetAssign_::word()
{
      return word_;
}

const NetExpr* NetAssign_::word() const
{
      return word_;
}

const NetExpr* NetAssign_::get_base() const
{
      return base_;
}

ivl_select_type_t NetAssign_::select_type() const
{
      return sel_type_;
}

unsigned NetAssign_::lwidth() const
{
	// This gets me the type of the l-value expression, down to
	// the type of this exact member. net_type() is deliberately nil for
	// a concatenation head, so use lval_type(): falling back to the root
	// signal width makes a wide class/interface property appear one bit
	// wide whenever another l-value follows it.
      ivl_type_t ntype = lval_type();
      if (ntype)
	    return ntype->packed_width();

      return lwid_;
}

ivl_variable_type_t NetAssign_::expr_type() const
{
      ivl_type_t ntype = net_type();
      if (ntype)
	    return ntype->base_type();

	/* net_type() is deliberately nil for a concatenation head. A packed
	 * concatenation is four-state when any leaf is four-state, and two-state
	 * only when every leaf is two-state (IEEE 1800-2023 11.3.4). Using just
	 * the rightmost leaf silently converted X/Z to zero for
	 * {logic_leaf, bit_leaf} compound assignments. */
	if (more) {
	      ivl_variable_type_t aggregate = IVL_VT_NO_TYPE;
	      for (const NetAssign_*cur = this; cur; cur = cur->more) {
		    ntype = cur->lval_type();
		    if (!ntype)
			  continue;
		    ivl_variable_type_t leaf_type = ntype->base_type();
		    if (leaf_type == IVL_VT_LOGIC)
			  return IVL_VT_LOGIC;
		    if (leaf_type == IVL_VT_BOOL)
			  aggregate = IVL_VT_BOOL;
		    else if (aggregate == IVL_VT_NO_TYPE)
			  aggregate = leaf_type;
	      }
	      if (aggregate != IVL_VT_NO_TYPE)
		    return aggregate;
      }

      if (sig_ == 0) {
	    return IVL_VT_NO_TYPE;
      }
      return sig_->data_type();
}

ivl_type_t NetAssign_::net_type() const
{
	// This is a concatenation, it does not have a type
      if (more)
	    return nullptr;

      return lval_type();
}

ivl_type_t NetAssign_::lval_type() const
{

	// An unpacked-array slice presents its sub-array type to the r-value
	// (e.g. `m[i]` of int[2][3] presents int[3]); word_ is the flat base
	// index, but the type must NOT be unwrapped to the scalar element.
      if (slice_type_)
	    return slice_type_;

       // Selected sub-vector can have its own data type
      if (base_)
	    return part_data_type_;

      ivl_type_t ntype;
      if (nest_) {
	    ntype = nest_->net_type();
      } else {
	    ivl_assert(*this, sig_);

	    if (sig_->unpacked_dimensions() && !word_)
		  ntype = sig_->array_type();
	    else
		  ntype = sig_->net_type();
      }

      if (!member_.nil()) {
	    if (const netclass_t *class_type = dynamic_cast<const netclass_t*>(ntype)) {
		  ntype = class_type->get_prop_type(member_idx_);
	    } else if (const netstruct_t *struct_type = dynamic_cast<const netstruct_t*>(ntype)) {
		  const auto&members = struct_type->members();
		  if ((member_idx_ >= 0) && ((size_t)member_idx_ < members.size()))
			ntype = members[member_idx_].net_type;
		  else
			ntype = nullptr;
	    } else if (word_
		       && (dynamic_cast<const netuarray_t*>(ntype)
			   || dynamic_cast<const netdarray_t*>(ntype))) {
		    /* member-of-an-indexed-element (pool[0].x, with pool an
		       array of structs -- a static class property is how
		       this was found): this single-node l-value carries
		       both word_ and member_, and this composition means
		       the WORD selects the element the member resolves
		       against. Unwrap, then retry the member. The common
		       composition (h.arr[0]: member first, then word) is
		       the ordinary path above and stays untouched. */
		  ivl_type_t etype = ntype;
		  if (const netdarray_t *darray = dynamic_cast<const netdarray_t*>(etype))
			etype = darray->element_type();
		  else if (const netuarray_t *uarray = dynamic_cast<const netuarray_t*>(etype))
			etype = uarray->element_type();
		  if (const netstruct_t *struct_type = dynamic_cast<const netstruct_t*>(etype)) {
			const auto&members = struct_type->members();
			if ((member_idx_ >= 0) && ((size_t)member_idx_ < members.size()))
			      return members[member_idx_].net_type;
		  }
		  ntype = nullptr;
	    } else {
		    /* Unresolvable member path: a diagnostic, not an abort
		       (this used to be ivl_assert(0), which turned a merely
		       unsupported l-value shape into a compiler crash --
		       recovery D4). */
		  ntype = nullptr;
	    }
      }

      if (word_) {
	    if (const netdarray_t *darray = dynamic_cast<const netdarray_t*>(ntype))
		  ntype = darray->element_type();
	    else if (const netuarray_t *uarray = dynamic_cast<const netuarray_t*>(ntype))
		  ntype = uarray->element_type();
	    else if (const netqueue_t *queue = dynamic_cast<const netqueue_t*>(ntype))
		  ntype = queue->element_type();
      }

      return ntype;
}

perm_string NetAssign_::name() const
{
      if (sig_) {
	    return sig_->name();
      } else {
	    return perm_string::literal("");
      }
}

NetNet* NetAssign_::sig() const
{
      ivl_assert(*this, sig_ ? nest_ == 0 : nest_ != 0);
      return sig_;
}

bool NetAssign_::is_interface_member() const
{
      if (member_.nil() || member_idx_ < 0)
            return false;

      ivl_type_t owner_type = nest_ ? nest_->net_type()
                                    : sig_ ? sig_->net_type() : 0;
      const netclass_t*owner =
            dynamic_cast<const netclass_t*>(owner_type);
      return owner && owner->is_interface();
}

NetNet* NetAssign_::resolve_interface_member_signal() const
{
      if (!is_interface_member())
            return 0;

      const NetAssign_*owner = nest_ ? nest_ : this;
      NetNet*root = owner->sig_;
      if (!root)
            return 0;

      unsigned root_word = 0;
      if (root->unpacked_dimensions()) {
            const NetEConst*word = owner->word_
                  ? dynamic_cast<const NetEConst*>(owner->word_) : 0;
            if (!word || !word->value().is_defined())
                  return 0;
            unsigned long value = word->value().as_ulong();
            if (value >= root->pin_count())
                  return 0;
            root_word = static_cast<unsigned>(value);
      }

      return root->resolve_interface_member(
            root_word, static_cast<size_t>(member_idx_));
}

void NetAssign_::mark_force_lval()
{
      force_lval_ = true;
      if (nest_)
	    nest_->mark_force_lval();
      if (more)
	    more->mark_force_lval();
}

void NetAssign_::set_part(NetExpr*base, unsigned wid,
                          ivl_select_type_t sel_type)
{
      base_ = base;
      lwid_ = wid;
      sel_type_ = sel_type;
}

void NetAssign_::set_part(NetExpr*base, ivl_type_t data_type)
{
      part_data_type_ = data_type;
      set_part(base, part_data_type_->packed_width());
}

void NetAssign_::set_property(const perm_string&mname, unsigned idx)
{
      member_ = mname;
      member_idx_ = idx;
}

/*
 */
void NetAssign_::turn_sig_to_wire_on_release()
{
      turn_sig_to_wire_on_release_ = true;
}

NetNet* NetAssign_::synth_array_write_token()
{
      if (synth_array_write_token_)
	    return synth_array_write_token_;

      ivl_assert(*this, sig_);
      ivl_assert(*this, sig_->unpacked_dimensions());
      unsigned width = sig_->vector_width();
      const netvector_t*type = new netvector_t(sig_->data_type(), width-1, 0);
      synth_array_write_token_ = new NetNet(
	    sig_->scope(), sig_->scope()->local_symbol(), NetNet::WIRE, type);
      synth_array_write_token_->local_flag(true);
      synth_array_write_token_->set_line(*sig_);
      return synth_array_write_token_;
}

NetArrayDq* NetAssign_::synth_array_write_port() const
{
      return synth_array_write_port_;
}

void NetAssign_::synth_array_write_port(NetArrayDq*port)
{
      ivl_assert(*this, !synth_array_write_port_);
      ivl_assert(*this, port);
      synth_array_write_port_ = port;
}

NetAssignBase::NetAssignBase(NetAssign_*lv, NetExpr*rv)
: lval_(lv), rval_(rv), delay_(0)
{
}

NetAssignBase::~NetAssignBase()
{
      delete rval_;
      delete delay_;
      while (lval_) {
	    NetAssign_*tmp = lval_;
	    lval_ = tmp->more;
	    tmp->more = 0;
	    delete tmp;
      }
}

NetExpr* NetAssignBase::rval()
{
      return rval_;
}

const NetExpr* NetAssignBase::rval() const
{
      return rval_;
}

void NetAssignBase::set_rval(NetExpr*r)
{
      delete rval_;
      rval_ = r;
}

NetExpr* NetAssignBase::exchange_rval(NetExpr*r)
{
      NetExpr*old = rval_;
      rval_ = r;
      return old;
}

NetAssign_* NetAssignBase::l_val(unsigned idx)
{
      NetAssign_*cur = lval_;
      while (idx > 0) {
	    if (cur == 0)
		  return cur;

	    cur = cur->more;
	    idx -= 1;
      }

      ivl_assert(*this, idx == 0);
      return cur;
}

const NetAssign_* NetAssignBase::l_val(unsigned idx) const
{
      const NetAssign_*cur = lval_;
      while (idx > 0) {
	    if (cur == 0)
		  return cur;

	    cur = cur->more;
	    idx -= 1;
      }

      ivl_assert(*this, idx == 0);
      return cur;
}

unsigned NetAssignBase::l_val_count() const
{
      const NetAssign_*cur = lval_;
      unsigned cnt = 0;
      while (cur) {
	    cnt += 1;
	    cur = cur->more;
      }

      return cnt;
}

unsigned NetAssignBase::lwidth() const
{
      unsigned sum = 0;
      for (const NetAssign_*cur = lval_ ;  cur ;  cur = cur->more)
	    sum += cur->lwidth();
      return sum;
}

void NetAssignBase::set_delay(NetExpr*expr)
{
      delay_ = expr;
}

const NetExpr* NetAssignBase::get_delay() const
{
      return delay_;
}

NetAssign::NetAssign(NetAssign_*lv, NetExpr*rv)
: NetAssignBase(lv, rv), op_(0)
{
}

NetAssign::NetAssign(NetAssign_*lv, char op, NetExpr*rv)
: NetAssignBase(lv, rv), op_(op)
{
}

NetAssign::~NetAssign()
{
}

NetAssignNB::NetAssignNB(NetAssign_*lv, NetExpr*rv, NetEvWait*ev, NetExpr*cnt)
: NetAssignBase(lv, rv)
{
      event_ = ev;
      count_ = cnt;
}

NetAssignNB::~NetAssignNB()
{
      delete event_;
      delete count_;
}

unsigned NetAssignNB::nevents() const
{
      if (event_) return event_->nevents();
      return 0;
}

const NetEvent*NetAssignNB::event(unsigned idx) const
{
      if (event_) return event_->event(idx);
      return 0;
}

const NetExpr*NetAssignNB::get_count() const
{
      return count_;
}

NetCAssign::NetCAssign(NetAssign_*lv, NetExpr*rv)
: NetAssignBase(lv, rv)
{
}

NetCAssign::~NetCAssign()
{
}

NetDeassign::NetDeassign(NetAssign_*l)
: NetAssignBase(l, 0)
{
}

NetDeassign::~NetDeassign()
{
}

NetForce::NetForce(NetAssign_*lv, NetExpr*rv, NetExpr*link_rv)
: NetAssignBase(lv, rv), force_link_rval_(link_rv)
{
}

NetForce::~NetForce()
{
      delete force_link_rval_;
}

const NetExpr* NetForce::force_link_rval() const
{
      return force_link_rval_ ? force_link_rval_ : rval();
}

NetRelease::NetRelease(NetAssign_*l)
: NetAssignBase(l, 0)
{
}

NetRelease::~NetRelease()
{
}
