/*
 * M9-NFA (Phase 2, stage A scaffold): automaton-based SVA engine.
 * Design: docs/conformance/m9_nfa_design_2026-07-19.md
 *
 * This file builds the sequence NFA. In the current increment the
 * engine is construction + dump only: pform_make_assertion calls
 * pform_sva_nfa_try_assertion() when IVL_SVA_NFA=1, which builds the
 * automaton (verifiable with IVL_SVA_NFA_DUMP=1) and then returns
 * false so the legacy linear engine still lowers the assertion.
 * Behavior is therefore identical with the flag on or off; the
 * synthesizer lands in the next increment and flips the return.
 *
 *    This source code is free software; you can redistribute it
 *    and/or modify it in source code form under the terms of the GNU
 *    General Public License as published by the Free Software
 *    Foundation; either version 2 of the License, or (at your option)
 *    any later version.
 */

# include  "config.h"
# include  "parse_misc.h"
# include  "pform.h"
# include  "PExpr.h"
# include  <cstdlib>
# include  <cstring>
# include  <iostream>
# include  <vector>

using namespace std;

bool pform_sva_nfa_enabled()
{
      static int flag = -1;
      if (flag < 0) {
	    const char*env = getenv("IVL_SVA_NFA");
	    flag = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
      }
      return flag != 0;
}

static bool nfa_dump_enabled_()
{
      static int flag = -1;
      if (flag < 0) {
	    const char*env = getenv("IVL_SVA_NFA_DUMP");
	    flag = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
      }
      return flag != 0;
}

/*
 * The automaton. States are dense indices. Edges are TICK edges only:
 * epsilon structure from the construction is folded before the
 * automaton is handed on (fold_epsilons_), so every surviving edge
 * consumes exactly one clock tick, guarded by a sampled boolean.
 * guard == nullptr encodes the constant-true guard (a pure delay
 * tick). Guards are BORROWED PExpr pointers into the property (the
 * synthesizer clones per use, exactly like the legacy engine).
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

/*
 * Build the automaton fragment for one legacy chain step:
 *   ##[m:n] expr  followed by  expr[*1:1+rep_tail]  tail repetition.
 * m == -1 encodes ##[m0:$] (unbounded upper: loop on a true tick);
 * m == -2 / -3 are legacy sorry markers — construction fails and the
 * caller falls back. Returns the fragment's exit state or ~0u.
 */
static unsigned nfa_add_step_(sva_nfa_t&nfa, unsigned cur,
			      const sva_seq_step_t&st, bool first)
{
      long lo = st.delay_lo;
      long hi = st.delay_hi;

      if (lo < 0 || hi == -2 || hi == -3)
	    return ~0u;

	// Legacy encoding of ##[m:$]: delay_lo = m, delay_hi = -1.
	// (The parse_misc.h header comment describing the opposite is
	// stale; the parser rules at K_CYCLE_DELAY '[' e ':' '$' ']'
	// are the authority.)
      bool unbounded = (hi == -1);

	// First step with no explicit delay consumes the anchor tick
	// itself: model as delay 0 -> the expr guards the very first
	// tick edge out of the anchor state. Encode delay d as d
	// unguarded ticks for d>=1 with the expression on the LAST
	// tick; delay 0 fuses the expression onto the incoming tick
	// (anchor consumption or same-tick ##0 continuation).
      long fixed = lo;
      if (fixed < 0) fixed = 0;

	// (fixed-1) pure delay ticks, then the guarded tick.
      for (long k = 1; k < fixed; k += 1) {
	    unsigned nxt = nfa.new_state();
	    nfa.tick(cur, nxt, nullptr);
	    cur = nxt;
      }

      unsigned before_expr = cur;
      if (fixed == 0) {
	    if (!first) {
		    // ##0 continuation: same-tick conjunction is not
		    // representable as a separate tick edge; stage A
		    // does not synthesize it (legacy handles ##0 by
		    // expression fusion). Signal fallback.
		  return ~0u;
	    }
	      // Anchor tick: one guarded edge out of the start.
	    unsigned nxt = nfa.new_state();
	    nfa.tick(cur, nxt, st.expr);
	    cur = nxt;
      } else {
	    unsigned nxt = nfa.new_state();
	    nfa.tick(cur, nxt, st.expr);
	    cur = nxt;
      }

	// Optional window ticks for ##[m:n]: (n-m) more chances, each
	// one further tick out, all converging via epsilon.
      if (!unbounded && hi > lo) {
	    unsigned join = nfa.new_state();
	    nfa.eps(cur, join);
	    unsigned wait = before_expr;
	    for (long k = lo; k < hi; k += 1) {
		  unsigned w2 = nfa.new_state();
		  nfa.tick(wait, w2, nullptr);
		  unsigned hit = nfa.new_state();
		  nfa.tick(w2, hit, st.expr);
		  nfa.eps(hit, join);
		  wait = w2;
	    }
	    cur = join;
      } else if (unbounded) {
	      // ##[m:$]: loop a pure-delay tick on the wait state.
	    nfa.tick(before_expr, before_expr, nullptr);
      }

	// Tail repetition expr[*1:1+rep_tail] (legacy last-step
	// encoding): optional extra guarded ticks.
      if (st.rep_tail > 0) {
	    unsigned join = nfa.new_state();
	    nfa.eps(cur, join);
	    unsigned prev = cur;
	    for (long k = 0; k < st.rep_tail; k += 1) {
		  unsigned nxt = nfa.new_state();
		  nfa.tick(prev, nxt, st.expr);
		  nfa.eps(nxt, join);
		  prev = nxt;
	    }
	    cur = join;
      }

      return cur;
}

/*
 * Fold epsilon edges: for every epsilon a->b, every tick edge into a
 * is duplicated into b (and start/accept adjusted), until no epsilon
 * remains reachable. Small automata; the quadratic pass is fine.
 */
static void fold_epsilons_(sva_nfa_t&nfa)
{
      bool changed = true;
      while (changed) {
	    changed = false;
	    for (size_t i = 0; i < nfa.edges.size(); i += 1) {
		  if (!nfa.edges[i].epsilon) continue;
		  unsigned a = nfa.edges[i].from;
		  unsigned b = nfa.edges[i].to;
		  nfa.edges.erase(nfa.edges.begin() + i);
		  if (nfa.start == a) nfa.start = b;
		  if (nfa.accept == a) nfa.accept = b;
		  for (size_t j = 0; j < nfa.edges.size(); j += 1) {
			if (nfa.edges[j].to == a) {
			      sva_nfa_edge_t dup = nfa.edges[j];
			      dup.to = b;
			      bool have = false;
			      for (size_t k = 0; k < nfa.edges.size(); k += 1) {
				    const sva_nfa_edge_t&o = nfa.edges[k];
				    if (o.epsilon == dup.epsilon
					&& o.from == dup.from
					&& o.to == dup.to
					&& o.guard == dup.guard) {
					  have = true;
					  break;
				    }
			      }
			      if (!have) nfa.edges.push_back(dup);
			}
		  }
		  changed = true;
		  break;
	    }
      }
}

/*
 * Prune states that cannot reach the accept state. Folding leaves
 * dead-end duplicates behind (pre-fold accept copies); they are
 * harmless for matching but FATAL for the synthesizer's emptiness
 * test — a thread sitting only in dead states must count as failed,
 * so dead states must not exist. Edges from/to dead states go too.
 */
static void prune_dead_states_(sva_nfa_t&nfa)
{
      std::vector<bool> live (nfa.nstates, false);
      live[nfa.accept] = true;
      bool changed = true;
      while (changed) {
	    changed = false;
	    for (size_t i = 0; i < nfa.edges.size(); i += 1) {
		  const sva_nfa_edge_t&e = nfa.edges[i];
		  if (live[e.to] && !live[e.from]) {
			live[e.from] = true;
			changed = true;
		  }
	    }
      }
	// The start state must survive even if the automaton is
	// vacuously dead (construction bug guard).
      live[nfa.start] = true;

      std::vector<unsigned> remap (nfa.nstates, ~0u);
      unsigned next = 0;
      for (unsigned s = 0; s < nfa.nstates; s += 1)
	    if (live[s]) remap[s] = next++;

      std::vector<sva_nfa_edge_t> kept;
      for (size_t i = 0; i < nfa.edges.size(); i += 1) {
	    const sva_nfa_edge_t&e = nfa.edges[i];
	    if (!live[e.from] || !live[e.to]) continue;
	    sva_nfa_edge_t ne = e;
	    ne.from = remap[e.from];
	    ne.to = remap[e.to];
	    kept.push_back(ne);
      }
      nfa.edges.swap(kept);
      nfa.start = remap[nfa.start];
      nfa.accept = remap[nfa.accept];
      nfa.nstates = next;
}

static bool nfa_from_chain_(sva_nfa_t&nfa,
			    const std::vector<sva_seq_step_t>&steps)
{
      nfa.start = nfa.new_state();
      unsigned cur = nfa.start;
      for (size_t k = 0; k < steps.size(); k += 1) {
	    cur = nfa_add_step_(nfa, cur, steps[k], k == 0);
	    if (cur == ~0u) return false;
      }
      nfa.accept = cur;
      fold_epsilons_(nfa);
      prune_dead_states_(nfa);
      return true;
}

static void nfa_dump_(const struct vlltype&loc, const char*what,
		      const sva_nfa_t&nfa)
{
      cerr << loc.get_fileline() << ": IVL_SVA_NFA_DUMP: " << what
	   << " states=" << nfa.nstates
	   << " start=S" << nfa.start
	   << " accept=S" << nfa.accept << endl;
      for (size_t i = 0; i < nfa.edges.size(); i += 1) {
	    const sva_nfa_edge_t&e = nfa.edges[i];
	    cerr << "    S" << e.from
		 << (e.epsilon ? " ..eps.. S" : " --tick(")
		 << (e.epsilon ? "" : (e.guard ? "expr" : "1"))
		 << (e.epsilon ? "" : ")--> S");
	    if (!e.epsilon) cerr << e.to;
	    else cerr << e.to;
	    cerr << endl;
      }
}

/*
 * Entry point from pform_make_assertion. Build automata for the
 * property's sequences; in this scaffold increment ALWAYS return
 * false afterwards so the legacy engine lowers the assertion — the
 * flag is observable only through IVL_SVA_NFA_DUMP.
 */
bool pform_sva_nfa_try_assertion(const struct vlltype&loc,
				 sva_property_t*prop,
				 Statement*fail_stmt, Statement*pass_stmt,
				 int kind)
{
      (void)fail_stmt; (void)pass_stmt; (void)kind;
      if (!prop || !prop->seq) return false;

      sva_nfa_t seq_nfa;
      bool ok = nfa_from_chain_(seq_nfa, *prop->seq);
      if (nfa_dump_enabled_()) {
	    if (ok)
		  nfa_dump_(loc, prop->antecedent ? "consequent" : "sequence",
			    seq_nfa);
	    else
		  cerr << loc.get_fileline() << ": IVL_SVA_NFA_DUMP: "
		       << "sequence not NFA-buildable (falls back)" << endl;
      }

      if (prop->antecedent) {
	    sva_nfa_t ante_nfa;
	    bool aok = nfa_from_chain_(ante_nfa, *prop->antecedent);
	    if (nfa_dump_enabled_()) {
		  if (aok) nfa_dump_(loc, "antecedent", ante_nfa);
		  else cerr << loc.get_fileline() << ": IVL_SVA_NFA_DUMP: "
			    << "antecedent not NFA-buildable (falls back)"
			    << endl;
	    }
      }

	// Scaffold: construction only. The synthesizer (design doc
	// stage A) will take over and return true for supported
	// shapes in the next increment.
      return false;
}
