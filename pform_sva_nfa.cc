/*
 * M9-NFA (Phase 2, stage A): automaton-based SVA engine — the
 * construction half. Design: docs/conformance/m9_nfa_design_2026-07-19.md
 *
 * This file builds and analyzes sequence NFAs from the legacy chain
 * IR. The stage-A synthesizer that lowers an automaton to a checker
 * process lives in pform.cc (pform_sva_nfa_try_assertion), where the
 * shared sva_* statement builders are.
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
# include  "pform_sva_nfa.h"
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

bool pform_sva_nfa_dump_enabled()
{
      static int flag = -1;
      if (flag < 0) {
	    const char*env = getenv("IVL_SVA_NFA_DUMP");
	    flag = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
      }
      return flag != 0;
}

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

bool pform_sva_nfa_build_from_chain(sva_nfa_t&nfa,
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

void pform_sva_nfa_dump(const struct vlltype&loc, const char*what,
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
 * Cycle detection (iterative DFS with colors). The construction only
 * creates self-loops (##[m:$] wait states), but folding can move
 * them, so detect generally.
 */
bool pform_sva_nfa_has_cycle(const sva_nfa_t&nfa)
{
      enum { WHITE, GREY, BLACK };
      std::vector<int> color (nfa.nstates, WHITE);
	// Adjacency once, to keep the DFS linear-ish.
      std::vector< std::vector<unsigned> > adj (nfa.nstates);
      for (size_t i = 0; i < nfa.edges.size(); i += 1)
	    adj[nfa.edges[i].from].push_back(nfa.edges[i].to);

      for (unsigned root = 0; root < nfa.nstates; root += 1) {
	    if (color[root] != WHITE) continue;
	    std::vector< std::pair<unsigned,size_t> > stack;
	    stack.push_back(std::make_pair(root, (size_t)0));
	    color[root] = GREY;
	    while (!stack.empty()) {
		  unsigned s = stack.back().first;
		  size_t&idx = stack.back().second;
		  if (idx < adj[s].size()) {
			unsigned t = adj[s][idx++];
			if (color[t] == GREY) return true;
			if (color[t] == WHITE) {
			      color[t] = GREY;
			      stack.push_back(std::make_pair(t, (size_t)0));
			}
		  } else {
			color[s] = BLACK;
			stack.pop_back();
		  }
	    }
      }
      return false;
}

/*
 * Longest path from the start state, skipping edges that close a
 * cycle (memoized DFS; on-stack targets are ignored). For loop-free
 * automata this is the exact maximum attempt lifetime in ticks.
 */
static long nfa_depth_rec_(const std::vector< std::vector<unsigned> >&adj,
			   std::vector<long>&memo, std::vector<bool>&onstack,
			   unsigned s)
{
      if (memo[s] >= 0) return memo[s];
      onstack[s] = true;
      long best = 0;
      for (size_t i = 0; i < adj[s].size(); i += 1) {
	    unsigned t = adj[s][i];
	    if (onstack[t]) continue;   // cycle edge: skip
	    long d = 1 + nfa_depth_rec_(adj, memo, onstack, t);
	    if (d > best) best = d;
      }
      onstack[s] = false;
      memo[s] = best;
      return best;
}

long pform_sva_nfa_depth(const sva_nfa_t&nfa)
{
      if (nfa.nstates == 0) return 0;
      std::vector< std::vector<unsigned> > adj (nfa.nstates);
      for (size_t i = 0; i < nfa.edges.size(); i += 1)
	    adj[nfa.edges[i].from].push_back(nfa.edges[i].to);
      std::vector<long> memo (nfa.nstates, -1);
      std::vector<bool> onstack (nfa.nstates, false);
      return nfa_depth_rec_(adj, memo, onstack, nfa.start);
}
