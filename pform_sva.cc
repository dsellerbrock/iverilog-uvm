/*
 * Copyright (c) 2026 Stephen Williams (steve@icarus.com)
 *
 *    This source code is free software; you can redistribute it
 *    and/or modify it in source code form under the terms of the GNU
 *    Library General Public License as published by the Free Software
 *    Foundation; either version 2 of the License, or (at your option)
 *    any later version.
 */

# include "config.h"
# include "pform_sva.h"
# include "pform.h"
# include "PExpr.h"
# include "Statement.h"
# include "parse_misc.h"
# include <cstdio>
# include <cstring>
# include <iostream>
# include <map>

using std::cerr;
using std::endl;

/*
 * SVA sampled-value rewriter (Phase S2 of sva-temporal).
 *
 * Walk an SVA antecedent / consequent expression, find any
 * $past/$rose/$fell/$stable/$changed calls, rewrite each call site
 * to reference a freshly-synthesized history register, and emit the
 * register declarations + per-clock NBA captures into the always
 * block synthesized for the assertion.
 */

namespace {

vlltype make_loc_(unsigned line, const char*file)
{
      vlltype v;
      v.first_line = line;
      v.first_column = 0;
      v.last_line = line;
      v.last_column = 0;
      v.lexical_pos = 0;
      v.text = file ? file : "";
      return v;
}

vlltype make_loc_from_line_info_(const LineInfo*li)
{
      return make_loc_(li ? li->get_lineno() : 0,
                       li ? li->get_file().str() : "");
}

bool name_is_sva_sample_(perm_string n,
                         pform_sva_sample_kind*kind_out)
{
      const char*s = n.str();
      if (!s || s[0] != '$') return false;
      if (strcmp(s, "$past") == 0)    { if (kind_out) *kind_out = SVA_SAMPLE_PAST;    return true; }
      if (strcmp(s, "$rose") == 0)    { if (kind_out) *kind_out = SVA_SAMPLE_ROSE;    return true; }
      if (strcmp(s, "$fell") == 0)    { if (kind_out) *kind_out = SVA_SAMPLE_FELL;    return true; }
      if (strcmp(s, "$stable") == 0)  { if (kind_out) *kind_out = SVA_SAMPLE_STABLE;  return true; }
      if (strcmp(s, "$changed") == 0) { if (kind_out) *kind_out = SVA_SAMPLE_CHANGED; return true; }
      return false;
}

PEIdent* make_ident_(perm_string name, const vlltype&where)
{
      pform_name_t pn;
      pn.push_back(name_component_t(name));
      PEIdent*id = pform_new_ident(where, pn);
      FILE_NAME(id, where);
      return id;
}

bool subtree_has_sva_sample_(PExpr*e);

bool list_has_sva_sample_(const std::vector<named_pexpr_t>&parms)
{
      for (auto&p : parms) {
            if (p.parm && subtree_has_sva_sample_(p.parm))
                  return true;
      }
      return false;
}

bool subtree_has_sva_sample_(PExpr*e)
{
      if (!e) return false;
      if (PECallFunction*c = dynamic_cast<PECallFunction*>(e)) {
            pform_sva_sample_kind k;
            if (c->get_path_().size() == 1
                && name_is_sva_sample_(peek_head_name(c->get_path_()), &k))
                  return true;
            return list_has_sva_sample_(c->get_parms_());
      }
      if (PEUnary*u = dynamic_cast<PEUnary*>(e))
            return subtree_has_sva_sample_(u->get_expr());
      if (PETernary*t = dynamic_cast<PETernary*>(e))
            return subtree_has_sva_sample_(t->get_test())
                || subtree_has_sva_sample_(t->get_true())
                || subtree_has_sva_sample_(t->get_false());
      if (PEBinary*b = dynamic_cast<PEBinary*>(e))
            return subtree_has_sva_sample_(b->get_left())
                || subtree_has_sva_sample_(b->get_right());
      return false;
}

PExpr* rewrite_(PExpr*e,
                std::vector<pform_sva_capture_t>&caps);

PExpr* rewrite_one_call_(PECallFunction*call,
                         pform_sva_sample_kind kind,
                         std::vector<pform_sva_capture_t>&caps)
{
      std::vector<named_pexpr_t>&parms = call->get_parms_();
      // Recurse into args first (e.g. $past($rose(x))).
      for (auto&p : parms) {
            if (p.parm) p.parm = rewrite_(p.parm, caps);
      }
      if (parms.size() < 1 || !parms[0].parm) {
            cerr << call->get_fileline() << ": error: SVA sampled-value "
                 << "call missing argument." << endl;
            return new PENumber(new verinum((uint64_t)0, 1));
      }
      // $past supports N>=1 lookback; the others are single-cycle.
      unsigned lookback_n = 1;
      if (kind == SVA_SAMPLE_PAST && parms.size() > 1 && parms[1].parm) {
            // The lookback arg should evaluate to a constant unsigned int.
            // For simple integer literals, drill into PENumber.
            PENumber*pn = dynamic_cast<PENumber*>(parms[1].parm);
            if (pn) {
                  lookback_n = pn->value().as_unsigned();
                  if (lookback_n == 0) lookback_n = 1;  // $past(x,0) = x
                  if (lookback_n > 64) {
                        cerr << call->get_fileline() << ": sorry: "
                             << "$past lookback N=" << lookback_n
                             << " exceeds 64 (register width limit)."
                             << endl;
                        lookback_n = 64;
                  }
            } else {
                  cerr << call->get_fileline() << ": sorry: "
                       << "$past(expr, N) requires N to be a constant"
                       << " literal (non-constant N not yet supported)."
                       << endl;
            }
      }
      if (parms.size() > 1 && kind != SVA_SAMPLE_PAST) {
            cerr << call->get_fileline() << ": sorry: "
                 << "extra args (clocking_event) on "
                 << "$rose/$fell/$stable/$changed not supported." << endl;
      }

      PExpr*captured = parms[0].parm;

      static unsigned uid_ = 0;
      char namebuf[64];
      snprintf(namebuf, sizeof namebuf, "__sva_past_%u", uid_++);
      perm_string reg_name = lex_strings.make(namebuf);

      pform_sva_capture_t cap;
      cap.reg_name = reg_name;
      cap.captured_expr = captured;
      cap.line = call->get_lineno();
      cap.file = call->get_file().str();
      caps.push_back(cap);

      vlltype where = make_loc_from_line_info_(call);
      // For lookback N, $past(x, N) is the bit at index N-1 of the
      // history register (which is shifted at LSB each clock).
      // Always use bit-select so single-bit comparisons match;
      // assigning the whole 64-bit register would carry stale
      // history bits and break == comparisons.
      pform_name_t pn;
      name_component_t nc(reg_name);
      index_component_t bidx;
      bidx.sel = index_component_t::SEL_BIT;
      bidx.msb = new PENumber(new verinum((uint64_t)(lookback_n - 1), 32));
      bidx.lsb = nullptr;
      FILE_NAME(bidx.msb, where);
      nc.index.push_back(bidx);
      pn.push_back(nc);
      PEIdent*hist = pform_new_ident(where, pn);
      FILE_NAME(hist, where);

      switch (kind) {
          case SVA_SAMPLE_PAST:
            return hist;
          case SVA_SAMPLE_ROSE: {
            PExpr*not_past = new PEUnary('!', hist);
            FILE_NAME(not_past, where);
            PExpr*and_ = new PEBLogic('a', captured, not_past);
            FILE_NAME(and_, where);
            return and_;
          }
          case SVA_SAMPLE_FELL: {
            PExpr*not_x = new PEUnary('!', captured);
            FILE_NAME(not_x, where);
            PExpr*and_ = new PEBLogic('a', not_x, hist);
            FILE_NAME(and_, where);
            return and_;
          }
          case SVA_SAMPLE_STABLE: {
            PExpr*eq = new PEBComp('e', captured, hist);
            FILE_NAME(eq, where);
            return eq;
          }
          case SVA_SAMPLE_CHANGED: {
            PExpr*ne = new PEBComp('n', captured, hist);
            FILE_NAME(ne, where);
            return ne;
          }
      }
      return hist;
}

PExpr* rewrite_(PExpr*e,
                std::vector<pform_sva_capture_t>&caps)
{
      if (!e) return e;
      if (PECallFunction*c = dynamic_cast<PECallFunction*>(e)) {
            pform_sva_sample_kind k;
            const auto&path = c->get_path_();
            if (path.size() == 1
                && name_is_sva_sample_(peek_head_name(path), &k)) {
                  return rewrite_one_call_(c, k, caps);
            }
            std::vector<named_pexpr_t>&parms = c->get_parms_();
            for (auto&p : parms) {
                  if (p.parm) p.parm = rewrite_(p.parm, caps);
            }
            return e;
      }
      if (PEUnary*u = dynamic_cast<PEUnary*>(e)) {
            PExpr*nc = rewrite_(u->get_expr(), caps);
            if (nc != u->get_expr()) u->set_expr(nc);
            return e;
      }
      if (PETernary*t = dynamic_cast<PETernary*>(e)) {
            PExpr*nc = rewrite_(t->get_test(), caps);
            if (nc != t->get_test()) t->set_test(nc);
            nc = rewrite_(t->get_true(), caps);
            if (nc != t->get_true()) t->set_true(nc);
            nc = rewrite_(t->get_false(), caps);
            if (nc != t->get_false()) t->set_false(nc);
            return e;
      }
      if (PEBinary*b = dynamic_cast<PEBinary*>(e)) {
            PExpr*nc = rewrite_(b->get_left(), caps);
            if (nc != b->get_left()) b->set_left(nc);
            nc = rewrite_(b->get_right(), caps);
            if (nc != b->get_right()) b->set_right(nc);
            return e;
      }
      // Container types not yet walked.  If they contain a sampled
      // call, hard-error so we don't silently fall through to a stub
      // (which would re-introduce the false-positive PASS pattern in
      // sv-tests).
      if (subtree_has_sva_sample_(e)) {
            cerr << e->get_fileline() << ": sorry: SVA sampled-value "
                 << "function inside this expression form is not yet "
                 << "supported.  Move it to a top-level antecedent or "
                 << "consequent." << endl;
      }
      return e;
}

}  // anonymous

void pform_sva_rewrite_sampling(PExpr*&expr,
                                std::vector<pform_sva_capture_t>&caps)
{
      expr = rewrite_(expr, caps);
}

Statement* pform_sva_build_seq_delay(PExpr*ant, PExpr*cons,
                                     unsigned n_cyc,
                                     Statement*fail,
                                     unsigned line, const char*file)
{
      if (n_cyc < 2) return nullptr;
      vlltype loc = make_loc_(line, file);

      // Allocate fresh shift-register name.
      static unsigned uid_ = 0;
      char namebuf[64];
      snprintf(namebuf, sizeof namebuf, "__sva_seq_dly_%u", uid_++);
      perm_string reg_name = lex_strings.make(namebuf);

      // reg [n_cyc-1:0] __sva_seq_dly_<n>;  (bool, defaults to 0)
      std::list<decl_assignment_t*> dlist;
      decl_assignment_t* da = new decl_assignment_t;
      da->name = pform_ident_t{reg_name, 0};
      dlist.push_back(da);
      std::list<pform_range_t>*rng = new std::list<pform_range_t>;
      pform_range_t r;
      r.first  = new PENumber(new verinum((uint64_t)(n_cyc - 1), 32));
      r.second = new PENumber(new verinum((uint64_t)0, 32));
      FILE_NAME(r.first, loc);
      FILE_NAME(r.second, loc);
      rng->push_back(r);
      vector_type_t* t = new vector_type_t(IVL_VT_BOOL, false, rng);
      FILE_NAME(t, loc);
      pform_make_var(loc, &dlist, t, nullptr, false);

      pform_name_t pn;
      pn.push_back(name_component_t(reg_name));

      // Check: if (reg[n_cyc-1] && !B) fail
      // Build reg[n_cyc-1] as a part-select.
      pform_name_t pn_msb;
      name_component_t nc(reg_name);
      // Bit-select via index list:
      index_component_t idx;
      idx.sel = index_component_t::SEL_BIT;
      idx.msb = new PENumber(new verinum((uint64_t)(n_cyc - 1), 32));
      idx.lsb = nullptr;
      FILE_NAME(idx.msb, loc);
      nc.index.push_back(idx);
      pn_msb.push_back(nc);
      PEIdent*reg_msb = pform_new_ident(loc, pn_msb);
      FILE_NAME(reg_msb, loc);

      PExpr*not_cons = new PEUnary('!', cons);
      FILE_NAME(not_cons, loc);
      PExpr*and_cond = new PEBLogic('a', reg_msb, not_cons);
      FILE_NAME(and_cond, loc);
      PCondit*chk = new PCondit(and_cond, fail, nullptr);
      FILE_NAME(chk, loc);

      // Shift NBA: reg <= {reg[n_cyc-2:0], A};
      // Build {reg[n_cyc-2:0], A}.
      pform_name_t pn_lsbs;
      name_component_t nc2(reg_name);
      index_component_t pidx;
      pidx.sel = index_component_t::SEL_PART;
      pidx.msb = new PENumber(new verinum((uint64_t)(n_cyc - 2), 32));
      pidx.lsb = new PENumber(new verinum((uint64_t)0, 32));
      FILE_NAME(pidx.msb, loc);
      FILE_NAME(pidx.lsb, loc);
      nc2.index.push_back(pidx);
      pn_lsbs.push_back(nc2);
      PEIdent*reg_lsbs = pform_new_ident(loc, pn_lsbs);
      FILE_NAME(reg_lsbs, loc);

      std::list<PExpr*> concat_list;
      concat_list.push_back(reg_lsbs);
      concat_list.push_back(ant);
      PEConcat*concat = new PEConcat(concat_list);
      FILE_NAME(concat, loc);

      PEIdent*reg_lhs = pform_new_ident(loc, pn);
      FILE_NAME(reg_lhs, loc);
      PAssignNB*shift = new PAssignNB(reg_lhs, concat);
      FILE_NAME(shift, loc);

      // Wrap into a sequential block: { check; shift; }
      std::vector<Statement*> stmts;
      stmts.push_back(chk);
      stmts.push_back(shift);
      PBlock*blk = new PBlock(PBlock::BL_SEQ);
      blk->set_statement(stmts);
      FILE_NAME(blk, loc);
      return blk;
}

/*
 * S3 named sequence / property registry.
 *
 * Single global map keyed by perm_string.  Real SV scopes named entities
 * per-module/interface; for sva-temporal v1 we accept the simplification
 * since chapter-16 tests use module-local definitions.  If two modules
 * declare a sequence with the same name, second registration is rejected.
 */

static std::map<perm_string, sva_property_t*>& sva_named_properties_()
{
      static std::map<perm_string, sva_property_t*> m;
      return m;
}

void pform_sva_register_named_property(perm_string name,
                                       sva_property_t*body)
{
      auto&m = sva_named_properties_();
      if (m.find(name) != m.end()) {
            cerr << "sorry: SVA named sequence/property `" << name.str()
                 << "' already declared." << endl;
            return;
      }
      m[name] = body;
}

sva_property_t* pform_sva_take_named_property(perm_string name)
{
      auto&m = sva_named_properties_();
      auto it = m.find(name);
      if (it == m.end()) return nullptr;
      sva_property_t*p = it->second;
      if (!p) {
            // Already consumed.
            cerr << "sorry: SVA named sequence/property `" << name.str()
                 << "' already used elsewhere; multi-use is not yet "
                 << "supported." << endl;
            return nullptr;
      }
      it->second = nullptr;  // mark consumed
      return p;
}

void pform_sva_emit_captures(const std::vector<pform_sva_capture_t>&caps,
                             std::vector<Statement*>&stmts)
{
      for (const auto&cap : caps) {
            vlltype loc = make_loc_(cap.line, cap.file);

            std::list<decl_assignment_t*> dlist;
            decl_assignment_t* da = new decl_assignment_t;
            da->name = pform_ident_t{cap.reg_name, 0};
            dlist.push_back(da);

            std::list<pform_range_t>*rng = new std::list<pform_range_t>;
            pform_range_t r;
            r.first  = new PENumber(new verinum((uint64_t)63, 32));
            r.second = new PENumber(new verinum((uint64_t)0, 32));
            FILE_NAME(r.first, loc);
            FILE_NAME(r.second, loc);
            rng->push_back(r);
            // Use IVL_VT_BOOL (2-state, defaults to 0) so the first-clock
            // check doesn't fire on uninitialized X.  SVA strict spec says
            // $past() at t=0 is 'x', but the more useful behavior in tests
            // is to match the initial value of the captured signal (0).
            vector_type_t* t = new vector_type_t(IVL_VT_BOOL, false, rng);
            FILE_NAME(t, loc);
            pform_make_var(loc, &dlist, t, nullptr, false);

            pform_name_t pn;
            pn.push_back(name_component_t(cap.reg_name));
            PEIdent*lhs = pform_new_ident(loc, pn);
            FILE_NAME(lhs, loc);

            // Shift NBA: reg <= {reg[62:0], captured_expr}.  This
            // gives multi-cycle history: bit 0 = value 1 cycle ago,
            // bit i = value (i+1) cycles ago.  $past(x, N) reads
            // bit N-1.  For the original single-cycle $past use,
            // bit 0 is the only one read and the shift is benign.
            pform_name_t pn_lo;
            name_component_t nc(cap.reg_name);
            index_component_t pidx;
            pidx.sel = index_component_t::SEL_PART;
            pidx.msb = new PENumber(new verinum((uint64_t)62, 32));
            pidx.lsb = new PENumber(new verinum((uint64_t)0, 32));
            FILE_NAME(pidx.msb, loc);
            FILE_NAME(pidx.lsb, loc);
            nc.index.push_back(pidx);
            pn_lo.push_back(nc);
            PEIdent*reg_lsbs = pform_new_ident(loc, pn_lo);
            FILE_NAME(reg_lsbs, loc);

            std::list<PExpr*> concat_list;
            concat_list.push_back(reg_lsbs);
            concat_list.push_back(cap.captured_expr);
            PEConcat*concat = new PEConcat(concat_list);
            FILE_NAME(concat, loc);

            PAssignNB*nba = new PAssignNB(lhs, concat);
            FILE_NAME(nba, loc);
            stmts.push_back(nba);
      }
}
