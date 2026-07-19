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
      if (fixed == 0 && !first) {
	      // ##0 fusion: the step's boolean shares the arrival
	      // tick of the previous step. Duplicate every tick edge
	      // arriving in cur's backward epsilon closure (window
	      // join states reach cur via eps) with this boolean
	      // added to the guard conjunction, targeting a fresh
	      // join state. The original arrival states keep their
	      // edges (delayed-arrival branches below still need
	      // them); if nothing else uses them they die in
	      // accept-reachability pruning.
	    std::vector<bool> incl (nfa.nstates, false);
	    incl[cur] = true;
	    bool chg = true;
	    while (chg) {
		  chg = false;
		  for (size_t i = 0; i < nfa.edges.size(); i += 1) {
			const sva_nfa_edge_t&e = nfa.edges[i];
			if (e.epsilon && incl[e.to] && !incl[e.from]) {
			      incl[e.from] = true;
			      chg = true;
			}
		  }
	    }
	    unsigned join = nfa.new_state();
	    size_t nedges = nfa.edges.size();
	    bool any = false;
	    for (size_t i = 0; i < nedges; i += 1) {
		  sva_nfa_edge_t e = nfa.edges[i];
		  if (e.epsilon || !incl[e.to]) continue;
		  e.to = join;
		  e.guards.push_back(st.expr);
		  nfa.edges.push_back(e);
		  any = true;
	    }
	    if (!any) return ~0u;

	      // ##[0:n] / ##[0:$]: arrivals >= 1 are an ordinary
	      // ##[1:n]/##[1:$] fragment from the pre-fusion state,
	      // eps-joined with the fused arrival-0 state.
	    if (unbounded || hi > 0) {
		  sva_seq_step_t rest = st;
		  rest.delay_lo = 1;
		  rest.delay_hi = unbounded ? -1 : hi;
		  rest.rep_tail = 0;
		  unsigned sub = nfa_add_step_(nfa, before_expr, rest, false);
		  if (sub == ~0u) return ~0u;
		  unsigned j2 = nfa.new_state();
		  nfa.eps(join, j2);
		  nfa.eps(sub, j2);
		  cur = j2;
	    } else {
		  cur = join;
	    }

	      // Tail repetition still applies (shared code below);
	      // the delayed-arrival window is already handled.
	    goto rep_tail_only;
      } else if (fixed == 0) {
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

rep_tail_only:
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
					&& o.guards == dup.guards) {
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

static bool nfa_chain_fragment_(sva_nfa_t&nfa,
				const std::vector<sva_seq_step_t>&steps,
				unsigned&start, unsigned&exit)
{
      start = nfa.new_state();
      unsigned cur = start;
      for (size_t k = 0; k < steps.size(); k += 1) {
	    cur = nfa_add_step_(nfa, cur, steps[k], k == 0);
	    if (cur == ~0u) return false;
      }
      exit = cur;
      return true;
}

bool pform_sva_nfa_build_from_chain(sva_nfa_t&nfa,
				    const std::vector<sva_seq_step_t>&steps)
{
      unsigned s = 0, e = 0;
      if (!nfa_chain_fragment_(nfa, steps, s, e))
	    return false;
      nfa.start = s;
      nfa.accept = e;
      fold_epsilons_(nfa);
      prune_dead_states_(nfa);
      return true;
}

/*
 * Stage B: product construction for `intersect` (both sides advance
 * in lockstep, accept together — same-interval semantics, 16.9.6)
 * and `and` (both match, the match ends with the LATER side; the
 * earlier side idles in an absorbing `done` state). Sides arrive
 * fully folded+pruned (tick edges only); the product's epsilon exits
 * are folded by the caller's top-level pass.
 */
static bool nfa_product_fragment_(sva_nfa_t&nfa,
				  const sva_nfa_t&A, const sva_nfa_t&B,
				  bool and_mode,
				  unsigned&start, unsigned&exit)
{
      sva_nfa_t A2 = A, B2 = B;
      unsigned doneA = 0, doneB = 0;
      if (and_mode) {
	    doneA = A2.new_state();
	    A2.tick(A2.accept, doneA, nullptr);
	    A2.tick(doneA, doneA, nullptr);
	    doneB = B2.new_state();
	    B2.tick(B2.accept, doneB, nullptr);
	    B2.tick(doneB, doneB, nullptr);
      }
      unsigned n2 = B2.nstates;
      unsigned base = nfa.nstates;
      for (unsigned i = 0; i < A2.nstates * B2.nstates; i += 1)
	    nfa.new_state();
      for (size_t i1 = 0; i1 < A2.edges.size(); i1 += 1) {
	    const sva_nfa_edge_t&e1 = A2.edges[i1];
	    if (e1.epsilon) return false;   // sides must be folded
	    for (size_t i2 = 0; i2 < B2.edges.size(); i2 += 1) {
		  const sva_nfa_edge_t&e2 = B2.edges[i2];
		  if (e2.epsilon) return false;
		  sva_nfa_edge_t e;
		  e.from = base + e1.from * n2 + e2.from;
		  e.to   = base + e1.to   * n2 + e2.to;
		  e.guards = e1.guards;
		  e.guards.insert(e.guards.end(),
				  e2.guards.begin(), e2.guards.end());
		  nfa.edges.push_back(e);
	    }
      }
      start = base + A2.start * n2 + B2.start;
      exit = nfa.new_state();
      nfa.eps(base + A2.accept * n2 + B2.accept, exit);
      if (and_mode) {
	    nfa.eps(base + doneA * n2 + B2.accept, exit);
	    nfa.eps(base + A2.accept * n2 + doneB, exit);
      }
      return true;
}

static bool nfa_tree_fragment_(sva_nfa_t&nfa, const sva_stree_t*t,
			       unsigned&start, unsigned&exit)
{
      if (!t) return false;
      switch (t->kind) {
	  case sva_stree_t::LEAF:
	    if (!t->chain) return false;
	    return nfa_chain_fragment_(nfa, *t->chain, start, exit);
	  case sva_stree_t::SEQ_OR: {
		unsigned sa = 0, ea = 0, sb = 0, eb = 0;
		if (!nfa_tree_fragment_(nfa, t->a, sa, ea)) return false;
		if (!nfa_tree_fragment_(nfa, t->b, sb, eb)) return false;
		start = nfa.new_state();
		nfa.eps(start, sa);
		nfa.eps(start, sb);
		exit = nfa.new_state();
		nfa.eps(ea, exit);
		nfa.eps(eb, exit);
		return true;
	  }
	  case sva_stree_t::SEQ_AND:
	  case sva_stree_t::SEQ_INTERSECT: {
		  /* Each side normalizes to its own folded automaton
		     (recursion composes nested combinators), then the
		     product embeds in the parent. */
		sva_nfa_t A, B;
		if (!pform_sva_nfa_build_from_tree(A, t->a)) return false;
		if (!pform_sva_nfa_build_from_tree(B, t->b)) return false;
		return nfa_product_fragment_(nfa, A, B,
					     t->kind == sva_stree_t::SEQ_AND,
					     start, exit);
	  }
      }
      return false;
}

bool pform_sva_nfa_build_from_tree(sva_nfa_t&nfa, const sva_stree_t*tree)
{
      unsigned s = 0, e = 0;
      if (!nfa_tree_fragment_(nfa, tree, s, e))
	    return false;
      nfa.start = s;
      nfa.accept = e;
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
		 << (e.epsilon ? " ..eps.. S" : " --tick(");
	    if (!e.epsilon) {
		  if (e.guards.empty()) cerr << "1";
		  for (size_t g = 0; g < e.guards.size(); g += 1)
			cerr << (g ? "&expr" : "expr");
	    }
	    cerr << (e.epsilon ? "" : ")--> S");
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
