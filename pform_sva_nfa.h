#ifndef IVL_pform_sva_nfa_H
#define IVL_pform_sva_nfa_H
/*
 * M9-NFA (Phase 2): automaton-based SVA engine — construction API.
 * Design: docs/conformance/m9_nfa_design_2026-07-19.md
 *
 * pform_sva_nfa.cc builds and analyzes the automata; the stage-A
 * synthesizer (pform.cc pform_sva_nfa_try_assertion) consumes them.
 *
 *    This source code is free software; you can redistribute it
 *    and/or modify it in source code form under the terms of the GNU
 *    General Public License as published by the Free Software
 *    Foundation; either version 2 of the License, or (at your option)
 *    any later version.
 */

# include  <vector>

class PExpr;
struct vlltype;
struct sva_seq_step_t;

/*
 * The automaton. States are dense indices. Delivered edges are TICK
 * edges only: epsilon structure from the construction is folded before
 * the automaton is handed out, so every surviving edge consumes exactly
 * one clock tick, guarded by a sampled boolean. guard == nullptr
 * encodes the constant-true guard (a pure delay tick). Guards are
 * BORROWED PExpr pointers into the property chain — the synthesizer
 * maps them to sample registers by pointer identity and never
 * dereferences them.
 */
struct sva_nfa_edge_t {
      unsigned from = 0;
      unsigned to = 0;
      PExpr*guard = nullptr;      // null = always true
      bool epsilon = false;       // construction-time only
};

struct sva_nfa_t {
      unsigned nstates = 0;
      unsigned start = 0;
      unsigned accept = 0;
      std::vector<sva_nfa_edge_t> edges;

      unsigned new_state() { return nstates++; }
      void tick(unsigned f, unsigned t, PExpr*g)
      { sva_nfa_edge_t e; e.from=f; e.to=t; e.guard=g; edges.push_back(e); }
      void eps(unsigned f, unsigned t)
      { sva_nfa_edge_t e; e.from=f; e.to=t; e.epsilon=true; edges.push_back(e); }
};

/* IVL_SVA_NFA / IVL_SVA_NFA_DUMP environment flags. */
extern bool pform_sva_nfa_enabled();
extern bool pform_sva_nfa_dump_enabled();

/* Build the tick-edge automaton for a legacy chain (fold + prune
   included). Returns false when the chain has a shape the construction
   does not cover (caller falls back to the legacy engine). */
extern bool pform_sva_nfa_build_from_chain(sva_nfa_t&nfa,
					   const std::vector<sva_seq_step_t>&steps);

extern void pform_sva_nfa_dump(const struct vlltype&loc, const char*what,
			       const sva_nfa_t&nfa);

/* True when any cycle exists (an unbounded ##[m:$] wait loop). */
extern bool pform_sva_nfa_has_cycle(const sva_nfa_t&nfa);

/* Longest acyclic path (in tick edges) from the start state; edges
   closing a cycle are skipped. For a loop-free automaton this bounds
   an attempt's lifetime exactly. */
extern long pform_sva_nfa_depth(const sva_nfa_t&nfa);

#endif /* IVL_pform_sva_nfa_H */
