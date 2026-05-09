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

// Synthesize the assertion check for `sequence` interpreted as
// "every cycle the sequence is attempted, it must complete".
// Returns the body Statement to splice into the always block (the
// parser's site is responsible for the disable-iff guard, the
// always wrapper, etc.), or nullptr on error.
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
