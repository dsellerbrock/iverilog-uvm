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
# include "pform_sva_seq.h"
# include "pform_sva.h"
# include "pform.h"
# include "PExpr.h"
# include "Statement.h"
# include "parse_misc.h"
# include <cstdio>
# include <cstring>
# include <iostream>

using std::cerr;
using std::endl;

/*
 * S5 (sva-temporal): sequence-expression IR + NFA matcher.
 *
 * Phased rollout:
 *   Step 1 (this commit): IR + synthesis for SEQ_BOOL and SEQ_CONCAT
 *     (the latter subsuming the standalone S4 helper).
 *   Step 2+: SEQ_OR, SEQ_AND, SEQ_INTERSECT, ##[N:M] range,
 *     SEQ_THROUGHOUT, repetition operators, with one validation pair
 *     per step.
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

} // anonymous

sva_seq_t* sva_seq_make_bool(PExpr*e)
{
      sva_seq_t*s = new sva_seq_t;
      s->kind = sva_seq_t::SEQ_BOOL;
      s->expr_ = e;
      return s;
}

sva_seq_t* sva_seq_make_concat(sva_seq_t*a, sva_seq_t*b,
                               unsigned n_lo, unsigned n_hi,
                               bool unbounded_hi)
{
      sva_seq_t*s = new sva_seq_t;
      s->kind = sva_seq_t::SEQ_CONCAT;
      s->kids_.push_back(a);
      s->kids_.push_back(b);
      s->n_lo = n_lo;
      s->n_hi = n_hi;
      s->unbounded_hi = unbounded_hi;
      return s;
}

sva_seq_t* sva_seq_make_and(sva_seq_t*a, sva_seq_t*b)
{
      sva_seq_t*s = new sva_seq_t;
      s->kind = sva_seq_t::SEQ_AND;
      s->kids_.push_back(a);
      s->kids_.push_back(b);
      return s;
}

sva_seq_t* sva_seq_make_or(sva_seq_t*a, sva_seq_t*b)
{
      sva_seq_t*s = new sva_seq_t;
      s->kind = sva_seq_t::SEQ_OR;
      s->kids_.push_back(a);
      s->kids_.push_back(b);
      return s;
}

sva_seq_t* sva_seq_make_intersect(sva_seq_t*a, sva_seq_t*b)
{
      sva_seq_t*s = new sva_seq_t;
      s->kind = sva_seq_t::SEQ_INTERSECT;
      s->kids_.push_back(a);
      s->kids_.push_back(b);
      return s;
}

sva_seq_t* sva_seq_make_throughout(PExpr*guard, sva_seq_t*seq)
{
      sva_seq_t*s = new sva_seq_t;
      s->kind = sva_seq_t::SEQ_THROUGHOUT;
      s->expr_ = guard;
      s->kids_.push_back(seq);
      return s;
}

sva_seq_t* sva_seq_make_within(sva_seq_t*a, sva_seq_t*b)
{
      sva_seq_t*s = new sva_seq_t;
      s->kind = sva_seq_t::SEQ_WITHIN;
      s->kids_.push_back(a);
      s->kids_.push_back(b);
      return s;
}

sva_seq_t* sva_seq_make_repeat(sva_seq_t*a,
                               unsigned n_lo, unsigned n_hi,
                               bool unbounded_hi)
{
      sva_seq_t*s = new sva_seq_t;
      s->kind = sva_seq_t::SEQ_REPEAT;
      s->kids_.push_back(a);
      s->n_lo = n_lo;
      s->n_hi = n_hi;
      s->unbounded_hi = unbounded_hi;
      return s;
}

sva_seq_t* sva_seq_make_goto(sva_seq_t*a,
                             unsigned n_lo, unsigned n_hi,
                             bool unbounded_hi)
{
      sva_seq_t*s = new sva_seq_t;
      s->kind = sva_seq_t::SEQ_GOTO;
      s->kids_.push_back(a);
      s->n_lo = n_lo;
      s->n_hi = n_hi;
      s->unbounded_hi = unbounded_hi;
      return s;
}

sva_seq_t* sva_seq_make_noncons(sva_seq_t*a,
                                unsigned n_lo, unsigned n_hi,
                                bool unbounded_hi)
{
      sva_seq_t*s = new sva_seq_t;
      s->kind = sva_seq_t::SEQ_NONCONS;
      s->kids_.push_back(a);
      s->n_lo = n_lo;
      s->n_hi = n_hi;
      s->unbounded_hi = unbounded_hi;
      return s;
}

void sva_seq_free(sva_seq_t*s)
{
      if (!s) return;
      for (auto*k : s->kids_) sva_seq_free(k);
      delete s;
}

void sva_nfa_free(sva_nfa_t*n)
{
      delete n;
}

// =====================================================================
// Step 1: synthesis for SEQ_BOOL and SEQ_CONCAT (fixed delay).
// Reuses the S4 shift-register approach for CONCAT(BOOL, BOOL, N).
//
// For arbitrary nesting and other operators, return nullptr with a
// hard error so the assertion site can fall back to error-pathway
// (no silent drop).
// =====================================================================

namespace {

// True if this seq is a single-cycle boolean primitive.
bool is_pure_bool_(const sva_seq_t*s)
{
      return s && s->kind == sva_seq_t::SEQ_BOOL;
}

PExpr* clone_pe_or_share_(PExpr*e)
{
      // pform doesn't have a deep-copy API; expressions are intended
      // to be referenced once.  For now, just share — the elaborator
      // tolerates shared sub-expressions in most cases.  Where it
      // doesn't, we'll refactor to a copy.
      return e;
}

// Build {reg[N-2:0], A} concat for the shift NBA when N>=2.
PEConcat* build_shift_concat_(perm_string reg_name, unsigned n_cyc,
                              PExpr*a, const vlltype&loc)
{
      pform_name_t pn_lsbs;
      name_component_t nc(reg_name);
      index_component_t pidx;
      pidx.sel = index_component_t::SEL_PART;
      pidx.msb = new PENumber(new verinum((uint64_t)(n_cyc - 2), 32));
      pidx.lsb = new PENumber(new verinum((uint64_t)0, 32));
      FILE_NAME(pidx.msb, loc);
      FILE_NAME(pidx.lsb, loc);
      nc.index.push_back(pidx);
      pn_lsbs.push_back(nc);
      PEIdent*reg_lsbs = pform_new_ident(loc, pn_lsbs);
      FILE_NAME(reg_lsbs, loc);

      std::list<PExpr*> concat_list;
      concat_list.push_back(reg_lsbs);
      concat_list.push_back(a);
      PEConcat*concat = new PEConcat(concat_list);
      FILE_NAME(concat, loc);
      return concat;
}

// Build a fresh shift register of width n_cyc bits, returns its name.
perm_string declare_shift_reg_(unsigned n_cyc, const vlltype&loc)
{
      static unsigned uid_ = 0;
      char namebuf[64];
      snprintf(namebuf, sizeof namebuf, "__sva_seq_dly_%u", uid_++);
      perm_string reg_name = lex_strings.make(namebuf);

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
      return reg_name;
}

// Construct a bit-select PEIdent: reg[idx].
PEIdent* make_bit_select_(perm_string reg_name, unsigned idx,
                          const vlltype&loc)
{
      pform_name_t pn;
      name_component_t nc(reg_name);
      index_component_t bidx;
      bidx.sel = index_component_t::SEL_BIT;
      bidx.msb = new PENumber(new verinum((uint64_t)idx, 32));
      bidx.lsb = nullptr;
      FILE_NAME(bidx.msb, loc);
      nc.index.push_back(bidx);
      pn.push_back(nc);
      PEIdent*id = pform_new_ident(loc, pn);
      FILE_NAME(id, loc);
      return id;
}

// Build the body for a CONCAT-range `A ##[N:M] B`.  Strategy:
// maintain a length-M shift register of A's sampled values, plus a
// length-(M-N+1) "deadline" register tracking attempts that have
// not yet matched.  At each clock:
//   match_now  := B && OR(dly[N-1..M-1])    -- A matched at any
//                                              cycle T-(N..M) and B now
//   deadline_t := dly[M-1] && !match_in_T_window
//   if deadline_t fire $error.
// Equivalently, the simpler form: compute "fail at cycle T" =
//   "A held at T-M but no B in window T-(M-N) .. T".
//
// Implementation: track A_dly[M-1:0] and a parallel "matched" flag
// for each in-flight attempt that already saw B in window.
//
// Because attempts can match at any cycle in the window, we use a
// per-cycle "match_progress" reduction rather than per-attempt regs.
Statement* synth_bool_concat_range_(PExpr*ant, PExpr*cons,
                                    unsigned n_lo, unsigned n_hi,
                                    Statement*fail, const vlltype&loc)
{
      // Allocate A history shift register of width n_hi (track A
      // up to n_hi cycles back).
      perm_string a_reg = declare_shift_reg_(n_hi, loc);
      // Allocate "still-waiting" register: bit i is 1 if there is an
      // in-flight attempt whose A fired i+1 cycles ago AND B has not
      // matched in any cycle since.  Width n_hi - n_lo + 1 tracks
      // the active window; bit (n_hi - n_lo) being 1 at the next
      // clock and B==0 means deadline missed.
      // For simplicity, use the A history alone and OR over the
      // window: an attempt fails at cycle T = T_start + n_hi if A
      // held at T_start AND B never held during T_start+n_lo ..
      // T_start+n_hi.
      // To check "B never held during a window of size n_hi-n_lo+1",
      // maintain a B-history register of width n_hi-n_lo+1.

      // Allocate B history shift register of width win (= n_hi - n_lo + 1).
      unsigned win = n_hi - n_lo + 1;
      perm_string b_reg = declare_shift_reg_(win, loc);

      // Build "any_b_in_window" =  OR(b_reg[win-1:0]) || cons (the
      // current cycle).  cons fires the same cycle as we're checking
      // T = T_start + n_hi; the attempt's deadline window is
      // T_start+n_lo .. T_start+n_hi, which corresponds to b_reg
      // bits 0..win-2 and cons (the current cycle).
      // Build the OR via a chain of PEBLogic('o', ...).
      PExpr*any_b = clone_pe_or_share_(cons);
      for (unsigned i = 0; i < win; ++i) {
            PEIdent*bit = make_bit_select_(b_reg, i, loc);
            PExpr*e = new PEBLogic('o', any_b, bit);
            FILE_NAME(e, loc);
            any_b = e;
      }

      // Failure condition: a_reg[n_hi-1] && !any_b_in_window.
      PEIdent*a_msb = make_bit_select_(a_reg, n_hi - 1, loc);
      PExpr*not_any_b = new PEUnary('!', any_b);
      FILE_NAME(not_any_b, loc);
      PExpr*fail_cond = new PEBLogic('a', a_msb, not_any_b);
      FILE_NAME(fail_cond, loc);
      PCondit*chk = new PCondit(fail_cond, fail, nullptr);
      FILE_NAME(chk, loc);

      // Build NBA shifters for both registers.
      // a_reg <= {a_reg[n_hi-2:0], ant}
      PExpr*a_shift_rhs;
      if (n_hi == 1) a_shift_rhs = ant;
      else a_shift_rhs = build_shift_concat_(a_reg, n_hi, ant, loc);
      pform_name_t a_pn;
      a_pn.push_back(name_component_t(a_reg));
      PEIdent*a_lhs = pform_new_ident(loc, a_pn);
      FILE_NAME(a_lhs, loc);
      PAssignNB*a_shift_nba = new PAssignNB(a_lhs, a_shift_rhs);
      FILE_NAME(a_shift_nba, loc);

      // b_reg <= {b_reg[win-2:0], cons}
      PExpr*b_shift_rhs;
      if (win == 1) b_shift_rhs = clone_pe_or_share_(cons);
      else b_shift_rhs = build_shift_concat_(b_reg, win,
                                             clone_pe_or_share_(cons), loc);
      pform_name_t b_pn;
      b_pn.push_back(name_component_t(b_reg));
      PEIdent*b_lhs = pform_new_ident(loc, b_pn);
      FILE_NAME(b_lhs, loc);
      PAssignNB*b_shift_nba = new PAssignNB(b_lhs, b_shift_rhs);
      FILE_NAME(b_shift_nba, loc);

      std::vector<Statement*> stmts;
      stmts.push_back(chk);
      stmts.push_back(a_shift_nba);
      stmts.push_back(b_shift_nba);
      PBlock*blk = new PBlock(PBlock::BL_SEQ);
      blk->set_statement(stmts);
      FILE_NAME(blk, loc);
      return blk;
}

// Build the body for `guard throughout (A_ant ##A_lo..A_hi A_cons)`.
// guard must hold at every cycle of the matched span.  For an attempt
// started at T, the span is [T, T+d] where d ∈ [a_lo, a_hi] is the
// chosen delay.  guard must be 1 at every cycle in [T, T+d].
//
// Implementation: track A_ant in a length-a_hi shift register; track
// guard (sampled per cycle) in a length-(a_hi+1) shift register.  At
// cycle X, the oldest in-flight attempt (started at X-a_hi) fails
// iff: A_ant held at start AND no successful match across the window
// (all-guard-held && A_cons-at-this-cycle).
//
// "all-guard-held over window" means: for some d ∈ [a_lo, a_hi] such
// that an attempt started at T = X-d found A_cons@(T+d)==A_cons@X
// AND guard held at every cycle T..X.
//
// For tractability we check the OLDEST attempt's deadline; later
// attempts that succeed will retire themselves.  At deadline X for
// start T = X-a_hi: any d in [a_lo, a_hi] gives a candidate match
// cycle T+d = X-a_hi+d.  For each such candidate Y, success iff
// A_cons@Y AND guard held at every cycle in [T, Y] = [X-a_hi, Y].
//
// Implemented via an "any-match-success" reduction across candidate
// match cycles: any_match = OR over d ∈ [a_lo, a_hi] of
//   guard_dly[a_hi-d:a_hi] all 1 AND A_cons sampled at cycle X-a_hi+d.
Statement* synth_throughout_(PExpr*guard, const sva_seq_t*sub,
                              Statement*fail, const vlltype&loc)
{
      PExpr*a_ant  = clone_pe_or_share_(sub->kids_[0]->expr_);
      PExpr*a_cons = clone_pe_or_share_(sub->kids_[1]->expr_);
      unsigned a_lo = sub->n_lo, a_hi = sub->n_hi;

      // a_ant_dly[a_hi-1:0]
      perm_string a_reg = declare_shift_reg_(a_hi, loc);
      // guard_dly[a_hi:0] -- includes current cycle's guard plus
      // a_hi cycles of history.  Width = a_hi + 1.
      perm_string g_reg = declare_shift_reg_(a_hi + 1, loc);
      // a_cons_dly[a_hi-a_lo:0] -- A_cons over candidate match cycles.
      unsigned win = a_hi - a_lo + 1;
      perm_string c_reg = declare_shift_reg_(win, loc);

      // any_match: OR over d ∈ [a_lo, a_hi] of:
      //   (a_cons sampled at start_cycle + d, currently in c_reg
      //    or being sampled this cycle for d=a_hi)
      //   AND  guard held at every cycle in start..(start+d), which
      //        means every guard_dly bit covering [a_hi-d, a_hi] is 1.
      // For start T = X-a_hi, after a_hi clocks: at cycle X we evaluate.
      //
      // Indexing convention:
      //   a_cons sampled at cycle (X - a_hi + d):
      //     if d == a_hi -> current cycle's a_cons (not yet shifted in)
      //     else         -> c_reg[a_hi - 1 - d]   (shifted in d cycles ago,
      //                       at cycle X-a_hi+d, currently at offset a_hi-1-d)
      //   guard at cycle (X - a_hi + i) for i ∈ [0, d]:
      //     if i == a_hi -> current cycle's guard (not yet shifted in)
      //     else         -> g_reg[a_hi - 1 - i]
      // For a span of d+1 cycles starting at X-a_hi, all guard bits
      // [a_hi - d, a_hi] over the g_reg index space (with bit a_hi
      // representing the current cycle, not shifted in) must be 1.
      //
      // We model bit a_hi of "guard" as the live `guard` expr; for
      // shifted bits use g_reg[i].
      PExpr*any_match = nullptr;
      for (unsigned d = a_lo; d <= a_hi; ++d) {
            // Build all_guard for this d: guard_at(X-a_hi+i) for
            // i ∈ [0..d].
            PExpr*all_guard = nullptr;
            for (unsigned i = 0; i <= d; ++i) {
                  PExpr*g_i;
                  if (i == a_hi) {
                        g_i = clone_pe_or_share_(guard);
                  } else if (i < a_hi) {
                        g_i = make_bit_select_(g_reg, a_hi - 1 - i, loc);
                  } else {
                        // Shouldn't happen: i > a_hi.
                        continue;
                  }
                  if (!all_guard) all_guard = g_i;
                  else {
                        PExpr*c = new PEBLogic('a', all_guard, g_i);
                        FILE_NAME(c, loc);
                        all_guard = c;
                  }
            }
            // Build a_cons_at(X-a_hi+d).
            PExpr*c_d;
            if (d == a_hi) c_d = clone_pe_or_share_(a_cons);
            else c_d = make_bit_select_(c_reg, a_hi - 1 - d, loc);

            PExpr*span_match = new PEBLogic('a', all_guard, c_d);
            FILE_NAME(span_match, loc);

            if (!any_match) any_match = span_match;
            else {
                  PExpr*o = new PEBLogic('o', any_match, span_match);
                  FILE_NAME(o, loc);
                  any_match = o;
            }
      }

      // started: A_ant held at X-a_hi.
      PEIdent*a_msb = make_bit_select_(a_reg, a_hi - 1, loc);
      PExpr*not_match = new PEUnary('!', any_match);
      FILE_NAME(not_match, loc);
      PExpr*fail_cond = new PEBLogic('a', a_msb, not_match);
      FILE_NAME(fail_cond, loc);
      PCondit*chk = new PCondit(fail_cond, fail, nullptr);
      FILE_NAME(chk, loc);

      auto build_nba = [&](perm_string reg, unsigned w, PExpr*rhs_val) -> PAssignNB* {
            PExpr*rhs = (w == 1) ? rhs_val : build_shift_concat_(reg, w, rhs_val, loc);
            pform_name_t pn;
            pn.push_back(name_component_t(reg));
            PEIdent*lhs = pform_new_ident(loc, pn);
            FILE_NAME(lhs, loc);
            PAssignNB*nba = new PAssignNB(lhs, rhs);
            FILE_NAME(nba, loc);
            return nba;
      };

      PAssignNB*a_nba = build_nba(a_reg, a_hi, a_ant);
      PAssignNB*g_nba = build_nba(g_reg, a_hi + 1, clone_pe_or_share_(guard));
      PAssignNB*c_nba = build_nba(c_reg, win, clone_pe_or_share_(a_cons));

      std::vector<Statement*> stmts;
      stmts.push_back(chk);
      stmts.push_back(a_nba);
      stmts.push_back(g_nba);
      stmts.push_back(c_nba);
      PBlock*blk = new PBlock(PBlock::BL_SEQ);
      blk->set_statement(stmts);
      FILE_NAME(blk, loc);
      return blk;
}

// Build the body for `intersect((A_ant ##A_lo..A_hi A_cons),
// (B_ant ##B_lo..B_hi B_cons))`.  Both sub-sequences must match
// starting at the same cycle T and ending at the same cycle X.
// The shared window [s_lo, s_hi] = [max(A_lo,B_lo), min(A_hi,B_hi)].
//
// Allocate three shift registers:
//   a_ant_dly[s_hi-1:0]    A's first cond history
//   b_ant_dly[s_hi-1:0]    B's first cond history
//   match_win[(s_hi-s_lo):0]   `(A_cons && B_cons)` history over
//                              the shared window
//
// At cycle X, the OLDEST attempt that started at T = X - s_hi
// fails iff `a_ant_dly[s_hi-1] && b_ant_dly[s_hi-1]`
// (both first conds held at T) and no cycle in
// [T+s_lo, T+s_hi] showed (A_cons && B_cons).
Statement* synth_intersect_concat_(const sva_seq_t*a, const sva_seq_t*b,
                                   unsigned s_lo, unsigned s_hi,
                                   Statement*fail, const vlltype&loc)
{
      PExpr*a_ant  = clone_pe_or_share_(a->kids_[0]->expr_);
      PExpr*a_cons = clone_pe_or_share_(a->kids_[1]->expr_);
      PExpr*b_ant  = clone_pe_or_share_(b->kids_[0]->expr_);
      PExpr*b_cons = clone_pe_or_share_(b->kids_[1]->expr_);

      // Compute shared-window match condition: (a_cons && b_cons).
      PExpr*match_now = new PEBLogic('a', a_cons, b_cons);
      FILE_NAME(match_now, loc);

      perm_string a_reg = declare_shift_reg_(s_hi, loc);
      perm_string b_reg = declare_shift_reg_(s_hi, loc);
      unsigned win = s_hi - s_lo + 1;
      perm_string m_reg = declare_shift_reg_(win, loc);

      // any_match_in_window: OR(m_reg[win-1:0]) || match_now (current).
      PExpr*any_match = match_now;
      for (unsigned i = 0; i < win; ++i) {
            PEIdent*bit = make_bit_select_(m_reg, i, loc);
            PExpr*o = new PEBLogic('o', any_match, bit);
            FILE_NAME(o, loc);
            any_match = o;
      }

      // started_at_oldest: a_ant_dly[s_hi-1] && b_ant_dly[s_hi-1].
      PEIdent*a_msb = make_bit_select_(a_reg, s_hi - 1, loc);
      PEIdent*b_msb = make_bit_select_(b_reg, s_hi - 1, loc);
      PExpr*started = new PEBLogic('a', a_msb, b_msb);
      FILE_NAME(started, loc);

      PExpr*not_match = new PEUnary('!', any_match);
      FILE_NAME(not_match, loc);
      PExpr*fail_cond = new PEBLogic('a', started, not_match);
      FILE_NAME(fail_cond, loc);
      PCondit*chk = new PCondit(fail_cond, fail, nullptr);
      FILE_NAME(chk, loc);

      // NBA shifters.
      auto build_nba = [&](perm_string reg, unsigned w, PExpr*rhs_val) -> PAssignNB* {
            PExpr*rhs = (w == 1) ? rhs_val : build_shift_concat_(reg, w, rhs_val, loc);
            pform_name_t pn;
            pn.push_back(name_component_t(reg));
            PEIdent*lhs = pform_new_ident(loc, pn);
            FILE_NAME(lhs, loc);
            PAssignNB*nba = new PAssignNB(lhs, rhs);
            FILE_NAME(nba, loc);
            return nba;
      };

      PAssignNB*a_nba = build_nba(a_reg, s_hi, a_ant);
      PAssignNB*b_nba = build_nba(b_reg, s_hi, b_ant);
      PAssignNB*m_nba = build_nba(m_reg, win, match_now);

      std::vector<Statement*> stmts;
      stmts.push_back(chk);
      stmts.push_back(a_nba);
      stmts.push_back(b_nba);
      stmts.push_back(m_nba);
      PBlock*blk = new PBlock(PBlock::BL_SEQ);
      blk->set_statement(stmts);
      FILE_NAME(blk, loc);
      return blk;
}

// Build the body for a CONCAT-of-bools sequence (`A ##N B`).  Reuses
// the S4 shift-register technique.  N==0: A&&B same-cycle; N==1:
// caller should handle as |=> via S1 (this returns a synthesized
// equivalent for completeness).  N>=2: shift register of length N.
Statement* synth_bool_concat_(PExpr*ant, PExpr*cons, unsigned n_cyc,
                              Statement*fail, const vlltype&loc)
{
      if (n_cyc == 0) {
            // (a && b) checked at this cycle.
            PEBLogic*conj = new PEBLogic('a', ant, cons);
            FILE_NAME(conj, loc);
            PExpr*not_conj = new PEUnary('!', conj);
            FILE_NAME(not_conj, loc);
            PCondit*chk = new PCondit(not_conj, fail, nullptr);
            FILE_NAME(chk, loc);
            return chk;
      }
      // n_cyc >= 1: maintain a length-n_cyc shift register of A's
      // sampled value; check B when the MSB is 1.
      perm_string reg_name = declare_shift_reg_(n_cyc, loc);
      PEIdent*reg_msb = make_bit_select_(reg_name, n_cyc - 1, loc);

      PExpr*not_cons = new PEUnary('!', cons);
      FILE_NAME(not_cons, loc);
      PExpr*and_cond = new PEBLogic('a', reg_msb, not_cons);
      FILE_NAME(and_cond, loc);
      PCondit*chk = new PCondit(and_cond, fail, nullptr);
      FILE_NAME(chk, loc);

      // Shift NBA.
      PExpr*shift_rhs;
      if (n_cyc == 1) {
            shift_rhs = ant;  // single-bit reg <= A
      } else {
            shift_rhs = build_shift_concat_(reg_name, n_cyc, ant, loc);
      }
      pform_name_t pn;
      pn.push_back(name_component_t(reg_name));
      PEIdent*reg_lhs = pform_new_ident(loc, pn);
      FILE_NAME(reg_lhs, loc);
      PAssignNB*shift = new PAssignNB(reg_lhs, shift_rhs);
      FILE_NAME(shift, loc);

      std::vector<Statement*> stmts;
      stmts.push_back(chk);
      stmts.push_back(shift);
      PBlock*blk = new PBlock(PBlock::BL_SEQ);
      blk->set_statement(stmts);
      FILE_NAME(blk, loc);
      return blk;
}

} // anonymous

Statement* sva_seq_synthesize_check(const sva_seq_t*seq,
                                    Statement*fail,
                                    unsigned line, const char*file)
{
      if (!seq) return nullptr;
      vlltype loc = make_loc_(line, file);

      switch (seq->kind) {
          case sva_seq_t::SEQ_BOOL: {
            // Plain assert(seq) — fail if seq is false at the clock.
            PExpr*e = clone_pe_or_share_(seq->expr_);
            PCondit*chk = new PCondit(e, nullptr, fail);
            FILE_NAME(chk, loc);
            return chk;
          }

          case sva_seq_t::SEQ_CONCAT: {
            // A ##N B (fixed) or A ##[N:M] B (range, both bool ops).
            if (!is_pure_bool_(seq->kids_[0]) || !is_pure_bool_(seq->kids_[1])) {
                  cerr << file << ":" << line << ": sorry: SVA `##N'/`##[N:M]'"
                       << " with non-boolean (composite) operands not yet"
                       << " supported." << endl;
                  return nullptr;
            }
            PExpr*a = clone_pe_or_share_(seq->kids_[0]->expr_);
            PExpr*b = clone_pe_or_share_(seq->kids_[1]->expr_);
            if (seq->n_lo == seq->n_hi && !seq->unbounded_hi)
                  return synth_bool_concat_(a, b, seq->n_lo, fail, loc);
            if (seq->unbounded_hi) {
                  cerr << file << ":" << line << ": sorry: SVA `##[N:$]'"
                       << " unbounded delay not supported (would need"
                       << " unbounded match-tracking buffer)." << endl;
                  return nullptr;
            }
            return synth_bool_concat_range_(a, b, seq->n_lo, seq->n_hi,
                                            fail, loc);
          }

          case sva_seq_t::SEQ_OR: {
            // seq1 or seq2 — at every cycle, at least one sub-sequence's
            // attempt (started L cycles ago) must complete here, where L
            // is the per-sub-sequence length.  For step 3 we restrict to
            // the case where both sub-seqs are SEQ_BOOL (L==0): in that
            // case, fail = !(a || b).
            // The general case requires per-attempt tracking which we
            // hard-error on rather than silently approximate.
            if (!is_pure_bool_(seq->kids_[0]) || !is_pure_bool_(seq->kids_[1])) {
                  cerr << file << ":" << line << ": sorry: SVA `or'"
                       << " with multi-cycle sub-sequences not yet"
                       << " supported (step 3 covers only single-cycle"
                       << " bool operands)." << endl;
                  return nullptr;
            }
            PExpr*a = clone_pe_or_share_(seq->kids_[0]->expr_);
            PExpr*b = clone_pe_or_share_(seq->kids_[1]->expr_);
            PExpr*ored = new PEBLogic('o', a, b);
            FILE_NAME(ored, loc);
            PCondit*chk = new PCondit(ored, nullptr, fail);
            FILE_NAME(chk, loc);
            return chk;
          }

          case sva_seq_t::SEQ_INTERSECT: {
            // intersect requires same start AND same end across both
            // sub-sequences.  We currently support intersect of two
            // SEQ_CONCAT operands whose match-windows overlap.  The
            // shared-window range determines deadline; the consequent
            // is the AND of both sub-seqs' second conditions; the
            // first conditions must both hold at the start.
            sva_seq_t*a = seq->kids_[0];
            sva_seq_t*b = seq->kids_[1];
            if (a->kind != sva_seq_t::SEQ_CONCAT
                || b->kind != sva_seq_t::SEQ_CONCAT
                || !is_pure_bool_(a->kids_[0]) || !is_pure_bool_(a->kids_[1])
                || !is_pure_bool_(b->kids_[0]) || !is_pure_bool_(b->kids_[1])
                || a->unbounded_hi || b->unbounded_hi) {
                  cerr << file << ":" << line << ": sorry: SVA `intersect'"
                       << " currently supports only two `expr ##N..M expr'"
                       << " sub-sequences with bounded delay." << endl;
                  return nullptr;
            }
            unsigned s_lo = a->n_lo > b->n_lo ? a->n_lo : b->n_lo;
            unsigned s_hi = a->n_hi < b->n_hi ? a->n_hi : b->n_hi;
            if (s_hi < s_lo) {
                  cerr << file << ":" << line << ": error: SVA `intersect'"
                       << " sub-sequence windows do not overlap [" << a->n_lo
                       << ":" << a->n_hi << "] vs [" << b->n_lo << ":"
                       << b->n_hi << "]; the property is unsatisfiable."
                       << endl;
                  return nullptr;
            }
            return synth_intersect_concat_(a, b, s_lo, s_hi, fail, loc);
          }

          case sva_seq_t::SEQ_AND: {
            // `and`: both sub-sequences must match starting at same T;
            // end time is max of the two ends.  We restrict to two
            // SEQ_CONCAT operands with the same upper-bound delay
            // (same end time); for SEQ_BOOL pair it degenerates to
            // single-cycle &&.
            sva_seq_t*a = seq->kids_[0];
            sva_seq_t*b = seq->kids_[1];
            if (is_pure_bool_(a) && is_pure_bool_(b)) {
                  PExpr*ax = clone_pe_or_share_(a->expr_);
                  PExpr*bx = clone_pe_or_share_(b->expr_);
                  PExpr*both = new PEBLogic('a', ax, bx);
                  FILE_NAME(both, loc);
                  PCondit*chk = new PCondit(both, nullptr, fail);
                  FILE_NAME(chk, loc);
                  return chk;
            }
            if (a->kind != sva_seq_t::SEQ_CONCAT
                || b->kind != sva_seq_t::SEQ_CONCAT
                || !is_pure_bool_(a->kids_[0]) || !is_pure_bool_(a->kids_[1])
                || !is_pure_bool_(b->kids_[0]) || !is_pure_bool_(b->kids_[1])
                || a->unbounded_hi || b->unbounded_hi
                || a->n_hi != b->n_hi) {
                  cerr << file << ":" << line << ": sorry: SVA `and'"
                       << " currently supports only two `expr ##N..M expr'"
                       << " sub-sequences with the same upper-bound delay"
                       << " (so end-time is shared)." << endl;
                  return nullptr;
            }
            // Same end time => same as intersect with merged windows.
            unsigned s_lo = a->n_lo > b->n_lo ? a->n_lo : b->n_lo;
            unsigned s_hi = a->n_hi;
            return synth_intersect_concat_(a, b, s_lo, s_hi, fail, loc);
          }

          case sva_seq_t::SEQ_THROUGHOUT: {
            // `expr throughout seq`: expr must hold at every cycle of
            // seq's match span.  We support `bool throughout
            // SEQ_CONCAT(bool, bool, lo, hi)` and `bool throughout
            // SEQ_BOOL`; multi-cycle and intersect/and inside the seq
            // need composability that we don't yet provide.
            PExpr*guard = clone_pe_or_share_(seq->expr_);
            sva_seq_t*sub = seq->kids_[0];
            if (is_pure_bool_(sub)) {
                  PExpr*sx = clone_pe_or_share_(sub->expr_);
                  PExpr*both = new PEBLogic('a', guard, sx);
                  FILE_NAME(both, loc);
                  PCondit*chk = new PCondit(both, nullptr, fail);
                  FILE_NAME(chk, loc);
                  return chk;
            }
            if (sub->kind != sva_seq_t::SEQ_CONCAT
                || !is_pure_bool_(sub->kids_[0])
                || !is_pure_bool_(sub->kids_[1])
                || sub->unbounded_hi) {
                  cerr << file << ":" << line << ": sorry: SVA `throughout'"
                       << " currently supports `expr throughout"
                       << " (a ##N..M b)' or `expr throughout bool'."
                       << endl;
                  return nullptr;
            }
            return synth_throughout_(guard, sub, fail, loc);
          }

          case sva_seq_t::SEQ_WITHIN:
          case sva_seq_t::SEQ_REPEAT:
          case sva_seq_t::SEQ_GOTO:
          case sva_seq_t::SEQ_NONCONS:
            cerr << file << ":" << line << ": sorry: SVA `within' and"
                 << " repetition operators require per-attempt tracking"
                 << " not yet implemented; not silently approximated."
                 << endl;
            return nullptr;
      }
      return nullptr;
}

sva_nfa_t* sva_seq_build_nfa(const sva_seq_t*)
{
      // NFA construction is part of step 2+.  Step 1 uses direct
      // synthesis without an explicit NFA representation.
      return nullptr;
}

void sva_seq_rewrite_sampling(sva_seq_t*s,
                              std::vector<pform_sva_capture_t>&caps)
{
      if (!s) return;
      switch (s->kind) {
          case sva_seq_t::SEQ_BOOL:
            pform_sva_rewrite_sampling(s->expr_, caps);
            break;
          case sva_seq_t::SEQ_THROUGHOUT:
            pform_sva_rewrite_sampling(s->expr_, caps);
            for (auto*k : s->kids_) sva_seq_rewrite_sampling(k, caps);
            break;
          default:
            for (auto*k : s->kids_) sva_seq_rewrite_sampling(k, caps);
            break;
      }
}
