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

// =====================================================================
// S6 framework: seq_synth_result_t-based composition.
// =====================================================================

namespace {

// Build a 1-bit "1" literal for use as match_started for SEQ_BOOL
// and other unconditional-attempt nodes.
PExpr* literal_one_(const vlltype&loc)
{
      PExpr*one = new PENumber(new verinum((uint64_t)1, 1));
      FILE_NAME(one, loc);
      return one;
}

seq_synth_result_t* synth_bool_(const sva_seq_t*seq, const vlltype&loc)
{
      // SEQ_BOOL: every cycle a non-vacuous attempt starts; the
      // attempt matches in the same cycle if expr is 1.
      seq_synth_result_t*r = new seq_synth_result_t;
      r->match_started_expr = literal_one_(loc);
      r->match_done_expr    = clone_pe_or_share_(seq->expr_);
      r->length_lo = 0;
      r->length_hi = 0;
      r->unbounded_hi = false;
      return r;
}

seq_synth_result_t* synth_concat_(const sva_seq_t*seq, const vlltype&loc,
                                  unsigned line, const char*file)
{
      // For step 2, both operands must be SEQ_BOOL.  Composite
      // operands need recursive composition that follows in step 7+.
      if (!is_pure_bool_(seq->kids_[0]) || !is_pure_bool_(seq->kids_[1])) {
            cerr << file << ":" << line << ": sorry: SEQ_CONCAT with"
                 << " composite (non-BOOL) operands not yet migrated"
                 << " to the framework." << endl;
            return nullptr;
      }
      if (seq->unbounded_hi) {
            cerr << file << ":" << line << ": sorry: ##[N:$] unbounded"
                 << " delay not supported." << endl;
            return nullptr;
      }
      PExpr*a_expr = seq->kids_[0]->expr_;
      PExpr*b_expr = seq->kids_[1]->expr_;
      unsigned n_lo = seq->n_lo, n_hi = seq->n_hi;

      seq_synth_result_t*r = new seq_synth_result_t;
      r->length_lo = n_lo;
      r->length_hi = n_hi;
      r->unbounded_hi = false;

      if (n_hi == 0) {
            // ##0: same-cycle conjunction.  match_started filters
            // non-vacuous attempts via a; match_done = a && b at X.
            r->match_started_expr = clone_pe_or_share_(a_expr);
            PExpr*both = new PEBLogic('a',
                                       clone_pe_or_share_(a_expr),
                                       clone_pe_or_share_(b_expr));
            FILE_NAME(both, loc);
            r->match_done_expr = both;
            return r;
      }

      // n_hi >= 1: need a's history.  Track via shift register width n_hi.
      perm_string a_reg = declare_shift_reg_(n_hi, loc);

      // match_started filter: a held this cycle (so an attempt
      // could begin here).  The framework will track this in its
      // started_dly so the deadline check at X gates on a@(X-n_hi).
      r->match_started_expr = clone_pe_or_share_(a_expr);

      // match_done: the OLDEST attempt at X-n_hi matches at X iff
      // (started: framework gates on a@(X-n_hi)) AND b@X.
      // For range, the oldest attempt could match at any cycle in
      // [X-n_hi+n_lo, X] -- but we report match_done at the deadline
      // cycle so the framework's deadline_match wraps correctly.
      // Simplification: for fixed delay, match_done = b@X.
      // For range, use OR(b_dly[hi-d] for d in [n_lo, n_hi]).
      // The framework's range branch reduces this further; but we
      // produce match_done as "any cycle in window matched B" via
      // its own b_dly tracking the cycle-by-cycle match condition.
      //
      // Specifically: match_done at cycle Y = b@Y for ANY Y where the
      // attempt could match.  For deterministic delay (n_lo == n_hi),
      // the match cycle is unique: Y = T + n_hi.
      // For range, multiple Y candidates in [T+n_lo, T+n_hi].
      //
      // We expose match_done as the per-cycle indicator "an attempt
      // at any started point could have matched here, given B@Y".
      // For SEQ_CONCAT(a, b, n_lo, n_hi):
      //   match_done@Y = (a@(Y-d) for some d in [n_lo, n_hi]) && b@Y
      //                = (OR of a_dly[d-1] for d in [n_lo, n_hi]) && b@Y
      // For n_lo == 0, include a@Y itself for d=0:
      PExpr*a_window_or = nullptr;
      for (unsigned d = n_lo; d <= n_hi; ++d) {
            PExpr*a_at_xd;
            if (d == 0) a_at_xd = clone_pe_or_share_(a_expr);
            else        a_at_xd = make_bit_select_(a_reg, d - 1, loc);
            if (!a_window_or) a_window_or = a_at_xd;
            else {
                  PExpr*o = new PEBLogic('o', a_window_or, a_at_xd);
                  FILE_NAME(o, loc);
                  a_window_or = o;
            }
      }
      PExpr*md = new PEBLogic('a', a_window_or,
                              clone_pe_or_share_(b_expr));
      FILE_NAME(md, loc);
      r->match_done_expr = md;

      // NBA: a_reg <= {a_reg[n_hi-2:0], a_expr}.
      PExpr*shift_rhs = (n_hi == 1)
                          ? clone_pe_or_share_(a_expr)
                          : build_shift_concat_(a_reg, n_hi,
                                                clone_pe_or_share_(a_expr),
                                                loc);
      pform_name_t pn;
      pn.push_back(name_component_t(a_reg));
      PEIdent*lhs = pform_new_ident(loc, pn);
      FILE_NAME(lhs, loc);
      PAssignNB*nba = new PAssignNB(lhs, shift_rhs);
      FILE_NAME(nba, loc);
      r->nba_stmts.push_back(nba);

      return r;
}

seq_synth_result_t* synth_repeat_(const sva_seq_t*seq, const vlltype&loc,
                                  unsigned line, const char*file)
{
      // Step 4: only SEQ_BOOL operand with fixed count.
      if (!is_pure_bool_(seq->kids_[0])) {
            cerr << file << ":" << line << ": sorry: SVA `[*N]'"
                 << " repetition with composite operand not yet"
                 << " supported." << endl;
            return nullptr;
      }
      if (seq->unbounded_hi) {
            cerr << file << ":" << line << ": sorry: `[*N:$]'"
                 << " unbounded repetition not supported." << endl;
            return nullptr;
      }
      unsigned lo = seq->n_lo, hi = seq->n_hi;
      if (lo == 0) {
            cerr << file << ":" << line << ": sorry: `[*0...]'"
                 << " (empty-match start) not supported." << endl;
            return nullptr;
      }

      PExpr*b_expr = seq->kids_[0]->expr_;

      seq_synth_result_t*r = new seq_synth_result_t;
      r->length_lo = lo - 1;
      r->length_hi = hi - 1;
      r->unbounded_hi = false;
      r->match_started_expr = clone_pe_or_share_(b_expr);

      if (lo == 1 && hi == 1) {
            // [*1]: identical to b alone.  L=0.
            r->match_done_expr = clone_pe_or_share_(b_expr);
            return r;
      }

      // Need b_dly of width lo-1 to express "run of length >= lo
      // ending at this cycle".  For lo == 1, no register needed.
      PExpr*all = clone_pe_or_share_(b_expr);
      if (lo >= 2) {
            perm_string b_reg = declare_shift_reg_(lo - 1, loc);
            for (unsigned i = 0; i + 1 < lo; ++i) {
                  PEIdent*bit = make_bit_select_(b_reg, i, loc);
                  PExpr*and_ = new PEBLogic('a', all, bit);
                  FILE_NAME(and_, loc);
                  all = and_;
            }

            // NBA: b_reg <= {b_reg[lo-3:0], b}.
            PExpr*shift_rhs = (lo - 1 == 1)
                                ? clone_pe_or_share_(b_expr)
                                : build_shift_concat_(b_reg, lo - 1,
                                                      clone_pe_or_share_(b_expr),
                                                      loc);
            pform_name_t pn;
            pn.push_back(name_component_t(b_reg));
            PEIdent*lhs = pform_new_ident(loc, pn);
            FILE_NAME(lhs, loc);
            PAssignNB*nba = new PAssignNB(lhs, shift_rhs);
            FILE_NAME(nba, loc);
            r->nba_stmts.push_back(nba);
      }
      r->match_done_expr = all;

      return r;
}

seq_synth_result_t* synth_or_(const sva_seq_t*seq, const vlltype&loc,
                              unsigned line, const char*file)
{
      seq_synth_result_t*a = sva_seq_synth(seq->kids_[0], line, file);
      seq_synth_result_t*b = sva_seq_synth(seq->kids_[1], line, file);
      if (!a || !b) { delete a; delete b; return nullptr; }
      if (a->unbounded_hi || b->unbounded_hi) {
            cerr << file << ":" << line << ": sorry: SEQ_OR with"
                 << " unbounded sub-sequence." << endl;
            delete a; delete b; return nullptr;
      }
      if (a->length_lo != b->length_lo || a->length_hi != b->length_hi) {
            cerr << file << ":" << line << ": sorry: SEQ_OR currently"
                 << " requires sub-sequences with the same length range."
                 << "  Different lengths need per-sub deadline tracking;"
                 << " not silently approximated." << endl;
            delete a; delete b; return nullptr;
      }

      seq_synth_result_t*r = new seq_synth_result_t;
      r->match_started_expr = new PEBLogic('o', a->match_started_expr,
                                           b->match_started_expr);
      FILE_NAME(r->match_started_expr, loc);
      r->match_done_expr = new PEBLogic('o', a->match_done_expr,
                                        b->match_done_expr);
      FILE_NAME(r->match_done_expr, loc);
      r->length_lo = a->length_lo;
      r->length_hi = a->length_hi;
      r->unbounded_hi = false;
      for (auto*nba : a->nba_stmts) r->nba_stmts.push_back(nba);
      for (auto*nba : b->nba_stmts) r->nba_stmts.push_back(nba);
      delete a; delete b;  // shells freed; contents now owned by r
      return r;
}

}  // anonymous

seq_synth_result_t* sva_seq_synth(const sva_seq_t*seq,
                                  unsigned line, const char*file)
{
      if (!seq) return nullptr;
      vlltype loc = make_loc_(line, file);
      switch (seq->kind) {
          case sva_seq_t::SEQ_BOOL:
            return synth_bool_(seq, loc);
          case sva_seq_t::SEQ_CONCAT:
            return synth_concat_(seq, loc, line, file);
          case sva_seq_t::SEQ_OR:
            return synth_or_(seq, loc, line, file);
          case sva_seq_t::SEQ_REPEAT:
            return synth_repeat_(seq, loc, line, file);
          default:
            // Other operators not yet migrated to the framework.
            cerr << file << ":" << line << ": sva_seq_synth: operator"
                 << " not yet migrated to seq_synth_result_t framework."
                 << endl;
            return nullptr;
      }
}

void sva_seq_synth_free(seq_synth_result_t*r)
{
      delete r;
}

Statement* sva_seq_assert_wrap(seq_synth_result_t*r,
                               Statement*fail,
                               unsigned line, const char*file)
{
      if (!r) return nullptr;
      vlltype loc = make_loc_(line, file);

      if (r->unbounded_hi) {
            cerr << file << ":" << line << ": sorry: unbounded sequence"
                 << " length not supported by assert framework." << endl;
            return nullptr;
      }

      Statement*body = nullptr;

      // Note on cycle accounting: at the active region of cycle X,
      // the NBAs from cycle X-1 have already executed.  So a shift
      // register `dly` updated with `dly <= {dly[w-2:0], v}` at each
      // clock has, at the active region of X, dly[i] = v@(X-1-i) for
      // i = 0..w-1.  To read v from k cycles ago (i.e. v@(X-k)) we
      // index dly[k-1].  Width w = k_max means bit w-1 holds v@(X-w).
      //
      // For deadline checks, the oldest in-flight attempt at cycle X
      // started at X - L_hi.  We need started_dly[L_hi - 1].

      if (r->length_lo == 0 && r->length_hi == 0) {
            // Deterministic L=0 (e.g. SEQ_BOOL): attempt matches or
            // fails at the same cycle.  Fire iff match_started &&
            // !match_done at this cycle.  No shift register needed.
            PExpr*not_done = new PEUnary('!', r->match_done_expr);
            FILE_NAME(not_done, loc);
            PExpr*cond = new PEBLogic('a', r->match_started_expr, not_done);
            FILE_NAME(cond, loc);
            PCondit*chk = new PCondit(cond, fail, nullptr);
            FILE_NAME(chk, loc);

            std::vector<Statement*> stmts;
            stmts.push_back(chk);
            for (auto*nba : r->nba_stmts) stmts.push_back(nba);
            if (stmts.size() == 1) { body = chk; }
            else {
                  PBlock*blk = new PBlock(PBlock::BL_SEQ);
                  blk->set_statement(stmts);
                  FILE_NAME(blk, loc);
                  body = blk;
            }
      } else if (r->length_lo == r->length_hi) {
            // Fixed-length deterministic seq with L>=1.  Track
            // started in a width-L shift register; at cycle X the
            // oldest in-flight attempt (started at X-L) is read at
            // started_dly[L-1].
            unsigned L = r->length_hi;
            perm_string sreg = declare_shift_reg_(L, loc);

            PEIdent*sm = make_bit_select_(sreg, L - 1, loc);
            PExpr*not_done = new PEUnary('!', r->match_done_expr);
            FILE_NAME(not_done, loc);
            PExpr*cond = new PEBLogic('a', sm, not_done);
            FILE_NAME(cond, loc);
            PCondit*chk = new PCondit(cond, fail, nullptr);
            FILE_NAME(chk, loc);

            // NBA: sreg <= {sreg[L-2:0], match_started}.
            PExpr*shift_rhs = (L == 1)
                                 ? r->match_started_expr
                                 : build_shift_concat_(sreg, L,
                                                       r->match_started_expr,
                                                       loc);
            pform_name_t spn;
            spn.push_back(name_component_t(sreg));
            PEIdent*slhs = pform_new_ident(loc, spn);
            FILE_NAME(slhs, loc);
            PAssignNB*snba = new PAssignNB(slhs, shift_rhs);
            FILE_NAME(snba, loc);

            std::vector<Statement*> stmts;
            stmts.push_back(chk);
            for (auto*nba : r->nba_stmts) stmts.push_back(nba);
            stmts.push_back(snba);
            PBlock*blk = new PBlock(PBlock::BL_SEQ);
            blk->set_statement(stmts);
            FILE_NAME(blk, loc);
            body = blk;
      } else {
            // Range-length seq.  started_dly width = L_hi (so
            // started_dly[L_hi-1] = match_started@(X-L_hi)).
            // match_window register tracks match_done over the
            // [L_lo, L_hi] window for the OLDEST attempt; we OR
            // across the window at deadline.
            unsigned Lhi = r->length_hi;
            unsigned Llo = r->length_lo;
            unsigned win = Lhi - Llo + 1;

            perm_string sreg = declare_shift_reg_(Lhi, loc);
            perm_string mreg = declare_shift_reg_(win, loc);

            // any_match = match_done@X (for d=L_lo if Llo==0, but
            // generally L_lo>=1) OR mreg[i] for older d's.
            // Indexing: at active of X, mreg[i] = match_done@(X-1-i).
            // Window: cycles [X-L_hi+L_lo, X].  X = mreg index -1
            // (live).  cycle X-k = mreg[k-1] for k>=1.  Cycle X is
            // the live match_done.
            PExpr*any_match = clone_pe_or_share_(r->match_done_expr);
            for (unsigned i = 0; i < win; ++i) {
                  PEIdent*bit = make_bit_select_(mreg, i, loc);
                  PExpr*o = new PEBLogic('o', any_match, bit);
                  FILE_NAME(o, loc);
                  any_match = o;
            }

            PEIdent*sm = make_bit_select_(sreg, Lhi - 1, loc);
            PExpr*not_match = new PEUnary('!', any_match);
            FILE_NAME(not_match, loc);
            PExpr*cond = new PEBLogic('a', sm, not_match);
            FILE_NAME(cond, loc);
            PCondit*chk = new PCondit(cond, fail, nullptr);
            FILE_NAME(chk, loc);

            auto build_nba = [&](perm_string reg, unsigned w, PExpr*rhs_val)
                              -> PAssignNB* {
                  PExpr*rhs = (w == 1) ? rhs_val
                                       : build_shift_concat_(reg, w, rhs_val, loc);
                  pform_name_t pn;
                  pn.push_back(name_component_t(reg));
                  PEIdent*lhs = pform_new_ident(loc, pn);
                  FILE_NAME(lhs, loc);
                  PAssignNB*nba = new PAssignNB(lhs, rhs);
                  FILE_NAME(nba, loc);
                  return nba;
            };
            PAssignNB*snba = build_nba(sreg, Lhi, r->match_started_expr);
            PAssignNB*mnba = build_nba(mreg, win,
                                       clone_pe_or_share_(r->match_done_expr));

            std::vector<Statement*> stmts;
            stmts.push_back(chk);
            for (auto*nba : r->nba_stmts) stmts.push_back(nba);
            stmts.push_back(snba);
            stmts.push_back(mnba);
            PBlock*blk = new PBlock(PBlock::BL_SEQ);
            blk->set_statement(stmts);
            FILE_NAME(blk, loc);
            body = blk;
      }

      return body;
}

// =====================================================================
// Legacy direct synthesizer; operators migrate one-by-one to the
// seq_synth_result_t framework above.
// =====================================================================

Statement* sva_seq_synthesize_check(const sva_seq_t*seq,
                                    Statement*fail,
                                    unsigned line, const char*file)
{
      if (!seq) return nullptr;
      vlltype loc = make_loc_(line, file);

      switch (seq->kind) {
          case sva_seq_t::SEQ_BOOL:
          case sva_seq_t::SEQ_CONCAT:
          case sva_seq_t::SEQ_OR:
          case sva_seq_t::SEQ_REPEAT: {
            // Migrated to the framework path.
            seq_synth_result_t*r = sva_seq_synth(seq, line, file);
            if (!r) return nullptr;
            Statement*s = sva_seq_assert_wrap(r, fail, line, file);
            sva_seq_synth_free(r);
            return s;
          }

          // SEQ_OR migrated to the framework — handled above.

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

          // SEQ_REPEAT migrated to the framework — handled above.
          case sva_seq_t::SEQ_WITHIN:
          case sva_seq_t::SEQ_GOTO:
          case sva_seq_t::SEQ_NONCONS:
            cerr << file << ":" << line << ": sorry: SVA `within' /"
                 << " `[->N]' / `[=N]' operators require per-attempt"
                 << " tracking not yet implemented; not silently"
                 << " approximated." << endl;
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
