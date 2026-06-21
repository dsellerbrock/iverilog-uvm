/*
 * Copyright (c) 1999-2021 Stephen Williams (steve@icarus.com)
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
# include  <cassert>
# include  <cstdlib>
# include  "ivl_assert.h"

using namespace std;

/*
 * Rebind references to a method's `this` (its port-0 net, `old_this`) to a
 * different receiver expression `recv`, recursing through subexpressions.
 *
 * This fixes up a default-argument expression that was elaborated in the
 * callee's scope (so its `this` references are the callee's port-0 net) when
 * it is used at a call site whose actual receiver differs. The rewrite runs
 * on a fresh dup_expr() copy and mutates it in place.
 *
 * rebind_default_this() handles one expression pointer: a direct
 * NetESignal of old_this (including the top-level default itself) is replaced
 * by a fresh dup of the receiver; otherwise the node recurses via its
 * replace_this_refs() override. `recv` is duplicated per occurrence so no
 * node is shared across substitutions. The base replace_this_refs() is a
 * no-op, so node types without an override simply keep their current behavior.
 */
void rebind_default_this(NetExpr*&expr, const NetNet*old_this,
			 const NetExpr*recv)
{
      if (!expr || !old_this || !recv) return;
      if (NetESignal*sig = dynamic_cast<NetESignal*>(expr)) {
	    if (sig->sig() == old_this) {
		  delete expr;
		  expr = recv->dup_expr();
		  return;
	    }
      }
      expr->replace_this_refs(old_this, recv);
}

void NetExpr::replace_this_refs(const NetNet*, const NetExpr*)
{
}

void NetEUFunc::replace_this_refs(const NetNet*old_this, const NetExpr*recv)
{
      for (unsigned idx = 0 ; idx < parms_.size() ; idx += 1)
	    rebind_default_this(parms_[idx], old_this, recv);
}

void NetESFunc::replace_this_refs(const NetNet*old_this, const NetExpr*recv)
{
      for (unsigned idx = 0 ; idx < parms_.size() ; idx += 1)
	    rebind_default_this(parms_[idx], old_this, recv);
}

void NetEBinary::replace_this_refs(const NetNet*old_this, const NetExpr*recv)
{
      rebind_default_this(left_, old_this, recv);
      rebind_default_this(right_, old_this, recv);
}

void NetEUnary::replace_this_refs(const NetNet*old_this, const NetExpr*recv)
{
      rebind_default_this(expr_, old_this, recv);
}

void NetETernary::replace_this_refs(const NetNet*old_this, const NetExpr*recv)
{
      rebind_default_this(cond_, old_this, recv);
      rebind_default_this(true_val_, old_this, recv);
      rebind_default_this(false_val_, old_this, recv);
}

void NetEConcat::replace_this_refs(const NetNet*old_this, const NetExpr*recv)
{
      for (unsigned idx = 0 ; idx < parms_.size() ; idx += 1)
	    rebind_default_this(parms_[idx], old_this, recv);
}

void NetESelect::replace_this_refs(const NetNet*old_this, const NetExpr*recv)
{
      rebind_default_this(expr_, old_this, recv);
      rebind_default_this(base_, old_this, recv);
}

void NetEProperty::replace_this_refs(const NetNet*old_this, const NetExpr*recv)
{
      if (expr_) {
	    rebind_default_this(expr_, old_this, recv);
      } else if (net_ && net_ == old_this) {
	      // `this.member` form stores the base as a direct net. Redirect
	      // it when the receiver is a simple signal (no array word index);
	      // a complex receiver is left unchanged as a safe fallback.
	    const NetESignal*rs = dynamic_cast<const NetESignal*>(recv);
	    if (rs && rs->word_index() == 0)
		  net_ = const_cast<NetNet*>(rs->sig());
      }
      rebind_default_this(index_, old_this, recv);
}

NetEAccess* NetEAccess::dup_expr() const
{
      NetEAccess*tmp = new NetEAccess(branch_, nature_);
      ivl_assert(*this, tmp);
      tmp->set_line(*this);
      return tmp;
}

NetEArrayPattern*NetEArrayPattern::dup_expr() const
{
      vector<NetExpr*>tmp (items_.size());
      for (size_t idx = 0 ; idx < tmp.size() ; idx += 1)
	    tmp[idx] = items_[idx]->dup_expr();

      NetEArrayPattern*res = new NetEArrayPattern(net_type(), tmp);
      res->set_line(*this);
      return res;
}

NetEBinary* NetEBinary::dup_expr() const
{
      ivl_assert(*this, 0);
      return 0;
}

NetEBAdd* NetEBAdd::dup_expr() const
{
      NetEBAdd*tmp = new NetEBAdd(op_, left_->dup_expr(), right_->dup_expr(),
                                  expr_width(), has_sign());
      ivl_assert(*this, tmp);
      tmp->set_line(*this);
      return tmp;
}

NetEBBits* NetEBBits::dup_expr() const
{
      NetEBBits*tmp = new NetEBBits(op_, left_->dup_expr(), right_->dup_expr(),
                                    expr_width(), has_sign());
      ivl_assert(*this, tmp);
      tmp->set_line(*this);
      return tmp;
}

NetEBComp* NetEBComp::dup_expr() const
{
      NetEBComp*tmp = new NetEBComp(op_, left_->dup_expr(), right_->dup_expr());
      ivl_assert(*this, tmp);
      tmp->set_line(*this);
      return tmp;
}

NetEBDiv* NetEBDiv::dup_expr() const
{
      NetEBDiv*tmp = new NetEBDiv(op_, left_->dup_expr(), right_->dup_expr(),
                                  expr_width(), has_sign());
      ivl_assert(*this, tmp);
      tmp->set_line(*this);
      return tmp;
}

NetEBLogic* NetEBLogic::dup_expr() const
{
      NetEBLogic*tmp = new NetEBLogic(op_, left_->dup_expr(), right_->dup_expr());
      ivl_assert(*this, tmp);
      tmp->set_line(*this);
      return tmp;
}

NetEBMult* NetEBMult::dup_expr() const
{
      NetEBMult*tmp = new NetEBMult(op_, left_->dup_expr(), right_->dup_expr(),
                                    expr_width(), has_sign());
      ivl_assert(*this, tmp);
      tmp->set_line(*this);
      return tmp;
}

NetEBPow* NetEBPow::dup_expr() const
{
      NetEBPow*tmp = new NetEBPow(op_, left_->dup_expr(), right_->dup_expr(),
                                  expr_width(), has_sign());
      ivl_assert(*this, tmp);
      tmp->set_line(*this);
      return tmp;
}

NetEBShift* NetEBShift::dup_expr() const
{
      NetEBShift*tmp = new NetEBShift(op_, left_->dup_expr(), right_->dup_expr(),
                                      expr_width(), has_sign());
      ivl_assert(*this, tmp);
      tmp->set_line(*this);
      return tmp;
}

NetEConcat* NetEConcat::dup_expr() const
{
      NetEConcat*dup = new NetEConcat(parms_.size(), repeat_, expr_type_);
      ivl_assert(*this, dup);
      dup->set_line(*this);
      for (unsigned idx = 0 ;  idx < parms_.size() ;  idx += 1)
	    if (parms_[idx]) {
		  NetExpr*tmp = parms_[idx]->dup_expr();
                  ivl_assert(*this, tmp);
		  dup->parms_[idx] = tmp;
	    }

      dup->expr_width(expr_width());

      return dup;
}

NetEConst* NetEConst::dup_expr() const
{
      NetEConst*tmp = new NetEConst(value_);
      ivl_assert(*this, tmp);
      tmp->set_line(*this);
      return tmp;
}

NetEConstEnum* NetEConstEnum::dup_expr() const
{
      NetEConstEnum*tmp = new NetEConstEnum(name_, enumeration(), value());
      ivl_assert(*this, tmp);
      tmp->set_line(*this);
      return tmp;
}

NetEConstParam* NetEConstParam::dup_expr() const
{
      NetEConstParam*tmp = new NetEConstParam(scope_, name_, value());
      ivl_assert(*this, tmp);
      tmp->set_line(*this);
      return tmp;
}

NetECReal* NetECReal::dup_expr() const
{
      NetECReal*tmp = new NetECReal(value_);
      ivl_assert(*this, tmp);
      tmp->set_line(*this);
      return tmp;
}

NetECString* NetECString::dup_expr() const
{
      NetECString*tmp = new NetECString(value());
      ivl_assert(*this, tmp);
      tmp->set_line(*this);
      return tmp;
}

NetECRealParam* NetECRealParam::dup_expr() const
{
      NetECRealParam*tmp = new NetECRealParam(scope_, name_, value());
      ivl_assert(*this, tmp);
      tmp->set_line(*this);
      return tmp;
}

NetEEvent* NetEEvent::dup_expr() const
{
      ivl_assert(*this, 0);
      return 0;
}

NetELast* NetELast::dup_expr() const
{
      NetELast*tmp = new NetELast(sig_);
      ivl_assert(*this, tmp);
      tmp->set_line(*this);
      return tmp;
}

NetENetenum* NetENetenum::dup_expr() const
{
      ivl_assert(*this, 0);
      return 0;
}

NetENew* NetENew::dup_expr() const
{
      ivl_assert(*this, 0);
      return 0;
}

NetENull* NetENull::dup_expr() const
{
      NetENull*tmp = new NetENull();
      ivl_assert(*this, tmp);
      tmp->set_line(*this);
      return tmp;
}

NetEProperty* NetEProperty::dup_expr() const
{
      NetEProperty*tmp = 0;
      if (get_base()) {
	    tmp = new NetEProperty(get_base()->dup_expr(), property_idx(),
				   get_index()? get_index()->dup_expr() : 0);
      } else {
	    tmp = new NetEProperty(const_cast<NetNet*>(get_sig()), property_idx(),
				   get_index()? get_index()->dup_expr() : 0);
      }
      ivl_assert(*this, tmp);
      tmp->cast_signed(has_sign());
      tmp->set_line(*this);
      return tmp;
}

NetEScope* NetEScope::dup_expr() const
{
      NetEScope*tmp = new NetEScope(const_cast<NetScope*>(scope()), net_type());
      tmp->set_line(*this);
      return tmp;
}

NetESelect* NetESelect::dup_expr() const
{
      NetESelect*tmp = new NetESelect(expr_->dup_expr(),
			              base_? base_->dup_expr() : 0,
			              expr_width(), sel_type_);
      ivl_assert(*this, tmp);
      tmp->cast_signed(has_sign());
      tmp->set_line(*this);
      return tmp;
}

NetESFunc* NetESFunc::dup_expr() const
{
      NetESFunc*tmp = new NetESFunc(name_, type_, expr_width(), nparms(), is_overridden_);
      ivl_assert(*this, tmp);

      tmp->cast_signed(has_sign());
      for (unsigned idx = 0 ;  idx < nparms() ;  idx += 1) {
	    ivl_assert(*this, parm(idx));
	    tmp->parm(idx, parm(idx)->dup_expr());
      }

      tmp->set_line(*this);
      return tmp;
}

NetEShallowCopy* NetEShallowCopy::dup_expr() const
{
      ivl_assert(*this, 0);
      return 0;
}

NetESignal* NetESignal::dup_expr() const
{
      NetESignal*tmp = new NetESignal(net_, word_);
      ivl_assert(*this, tmp);
      tmp->expr_width(expr_width());
      tmp->cast_signed(has_sign());
      tmp->set_line(*this);
      return tmp;
}

NetETernary* NetETernary::dup_expr() const
{
      NetETernary*tmp = new NetETernary(cond_->dup_expr(),
					true_val_->dup_expr(),
					false_val_->dup_expr(),
                                        expr_width(),
                                        has_sign());
      ivl_assert(*this, tmp);
      tmp->set_line(*this);
      return tmp;
}

NetEUFunc* NetEUFunc::dup_expr() const
{
      NetEUFunc*tmp;
      vector<NetExpr*> tmp_parms (parms_.size());

      for (unsigned idx = 0 ;  idx < tmp_parms.size() ;  idx += 1) {
	    ivl_assert(*this, parms_[idx]);
	    tmp_parms[idx] = parms_[idx]->dup_expr();
      }

      tmp = new NetEUFunc(scope_, func_, result_sig_->dup_expr(), tmp_parms,
                          need_const_, super_call_);

      ivl_assert(*this, tmp);
      tmp->set_line(*this);
      return tmp;
}

NetEUBits* NetEUBits::dup_expr() const
{
      NetEUBits*tmp = new NetEUBits(op_, expr_->dup_expr(), expr_width(), has_sign());
      ivl_assert(*this, tmp);
      tmp->set_line(*this);
      return tmp;
}

NetEUnary* NetEUnary::dup_expr() const
{
      NetEUnary*tmp = new NetEUnary(op_, expr_->dup_expr(), expr_width(), has_sign());
      ivl_assert(*this, tmp);
      tmp->set_line(*this);
      return tmp;
}

NetEUReduce* NetEUReduce::dup_expr() const
{
      NetEUReduce*tmp = new NetEUReduce(op_, expr_->dup_expr());
      ivl_assert(*this, tmp);
      tmp->set_line(*this);
      return tmp;
}

NetECast* NetECast::dup_expr() const
{
      NetECast*tmp = new NetECast(op_, expr_->dup_expr(), expr_width(), has_sign());
      ivl_assert(*this, tmp);
      tmp->set_line(*this);
      return tmp;
}
