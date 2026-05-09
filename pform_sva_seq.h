#ifndef IVL_pform_sva_seq_H
#define IVL_pform_sva_seq_H
/*
 * Copyright (c) 2026 Stephen Williams (steve@icarus.com)
 *
 *    This source code is free software; you can redistribute it
 *    and/or modify it in source code form under the terms of the GNU
 *    Library General Public License as published by the Free Software
 *    Foundation; either version 2 of the License, or (at your option)
 *    any later version.
 */

# include <vector>

class PExpr;
class Statement;

/*
 * S5 (sva-temporal): sequence-expression IR.
 *
 * A `sva_seq_t` is the parsed-but-not-yet-synthesized form of a
 * SystemVerilog sequence_expr.  It's a tree whose leaves are
 * boolean expressions (sampled at the property's clock) and whose
 * interior nodes are sequence operators.  An NFA-style matcher is
 * synthesized from this IR at assertion-synthesis time.
 *
 * The IR captures only what's needed for chapter-16 / common DV
 * patterns; advanced pieces (multi-clock, property-local vars,
 * first_match, strong/weak qualifiers) are explicitly excluded.
 */
struct sva_seq_t {
      enum kind_t {
            SEQ_BOOL,        // expr_  (single-cycle boolean primitive)
            SEQ_CONCAT,      // kids_[0] ##N..M kids_[1]
            SEQ_AND,         // kids_[0] and kids_[1]
            SEQ_OR,          // kids_[0] or  kids_[1]
            SEQ_INTERSECT,   // kids_[0] intersect kids_[1]
            SEQ_THROUGHOUT,  // expr_ throughout kids_[0]
            SEQ_WITHIN,      // kids_[0] within kids_[1]
            SEQ_REPEAT,      // kids_[0] [*N..M]
            SEQ_GOTO,        // kids_[0] [->N..M]
            SEQ_NONCONS      // kids_[0] [=N..M]
      };

      kind_t kind;
      PExpr* expr_;                       // SEQ_BOOL, SEQ_THROUGHOUT
      std::vector<sva_seq_t*> kids_;
      unsigned n_lo;                      // delay/repeat lower bound
      unsigned n_hi;                      // delay/repeat upper bound (== n_lo for fixed)
      bool unbounded_hi;                  // true for ##[N:$], [*N:$], etc.

      sva_seq_t() : kind(SEQ_BOOL), expr_(nullptr), n_lo(0), n_hi(0),
                    unbounded_hi(false) {}
};

// Helper constructors for parser actions.
extern sva_seq_t* sva_seq_make_bool(PExpr*e);
extern sva_seq_t* sva_seq_make_concat(sva_seq_t*a, sva_seq_t*b,
                                      unsigned n_lo, unsigned n_hi,
                                      bool unbounded_hi);
extern sva_seq_t* sva_seq_make_and(sva_seq_t*a, sva_seq_t*b);
extern sva_seq_t* sva_seq_make_or(sva_seq_t*a, sva_seq_t*b);
extern sva_seq_t* sva_seq_make_intersect(sva_seq_t*a, sva_seq_t*b);
extern sva_seq_t* sva_seq_make_throughout(PExpr*guard, sva_seq_t*seq);
extern sva_seq_t* sva_seq_make_within(sva_seq_t*a, sva_seq_t*b);
extern sva_seq_t* sva_seq_make_repeat(sva_seq_t*a,
                                      unsigned n_lo, unsigned n_hi,
                                      bool unbounded_hi);
extern sva_seq_t* sva_seq_make_goto(sva_seq_t*a,
                                    unsigned n_lo, unsigned n_hi,
                                    bool unbounded_hi);
extern sva_seq_t* sva_seq_make_noncons(sva_seq_t*a,
                                       unsigned n_lo, unsigned n_hi,
                                       bool unbounded_hi);

extern void sva_seq_free(sva_seq_t*s);

/*
 * NFA built from sva_seq_t.  States are numbered 0..N-1.  Each
 * transition has a guard expression and a target state.  state 0
 * is start.  accept_ contains the set of accept states.
 *
 * For SVA, "match completes at cycle T" means an active thread is
 * in an accept state at cycle T.  A new match attempt starts each
 * cycle by initializing a thread at state 0.
 */
struct sva_nfa_trans_t {
      unsigned to;
      PExpr* guard;        // boolean expr; nullptr means epsilon (always)
};

struct sva_nfa_state_t {
      std::vector<sva_nfa_trans_t> trans;
};

struct sva_nfa_t {
      std::vector<sva_nfa_state_t> states_;
      unsigned start_;
      std::vector<unsigned> accept_;     // sorted unique
      // Maximum match length (in clock cycles) — used to size the
      // active-thread tracking shift register.  ~unsigned(0) for
      // unbounded sequences, which we hard-error on.
      unsigned max_len;
};

// Build an NFA from the sequence IR.  Returns nullptr if the
// sequence is unbounded (reports a hard error to the user).
extern sva_nfa_t* sva_seq_build_nfa(const sva_seq_t*s);
extern void sva_nfa_free(sva_nfa_t*n);

// S6 framework: each sva_seq_t lowers to a `seq_synth_result_t`
// exposing the signals an enclosing operator (or the assert wrapper)
// needs to compose with.
//
// match_started_expr: 1-bit PExpr that's true when a non-vacuous
//   attempt could begin at this cycle.  Used by the assert wrapper
//   as the "started" gate for deadline-fail; used by enclosing ops
//   (or, and, intersect) to compose start conditions.
// match_done_expr:    1-bit PExpr that's true when some in-flight
//   attempt completes a match at this cycle.
// length_lo/length_hi: the range of possible match lengths in
//   cycles.  Both 0 for SEQ_BOOL.
// unbounded_hi:       true for ##[N:$] / [*N:$] (currently always
//   refused with hard-error before reaching here).
// nba_stmts:          per-cycle NBA shift-register updates that the
//   enclosing always block must execute every clock for the synth
//   state to track input history correctly.
struct seq_synth_result_t {
      class PExpr* match_started_expr;
      class PExpr* match_done_expr;
      unsigned length_lo;
      unsigned length_hi;
      bool unbounded_hi;
      std::vector<class Statement*> nba_stmts;
};

// Build a synth result for a sequence.  Returns nullptr on error
// (a "sorry: ..." message has already been printed to stderr).
extern seq_synth_result_t* sva_seq_synth(const sva_seq_t*seq,
                                         unsigned line, const char*file);
extern void sva_seq_synth_free(seq_synth_result_t*r);

// Wrap a synthesized sequence as an assert-property check.  The
// wrapper synthesizes the deadline machinery (per-attempt history
// shift register) and produces a Statement to splice into the
// always block.  `fail` is the failure action.
extern Statement* sva_seq_assert_wrap(seq_synth_result_t*r,
                                      Statement*fail,
                                      unsigned line, const char*file);

// Legacy direct-synthesis path.  Used while operators are migrated
// to the seq_synth_result_t framework one-at-a-time.
extern Statement* sva_seq_synthesize_check(const sva_seq_t*seq,
                                           Statement*fail,
                                           unsigned line, const char*file);

// S2 hookup: walk the sequence IR and apply the SVA sampled-value
// rewriter (pform_sva_rewrite_sampling) to each SEQ_BOOL leaf's
// expression.  This way `$past` etc. work inside sequences too.
struct pform_sva_capture_t;
extern void sva_seq_rewrite_sampling(sva_seq_t*s,
                                     std::vector<pform_sva_capture_t>&caps);

#endif /* IVL_pform_sva_seq_H */
