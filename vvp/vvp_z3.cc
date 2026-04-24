/*
 * Z3 SMT solver integration for SystemVerilog constrained randomization.
 *
 * Constraint IR format (S-expression):
 *   (lt  p:N:W  c:V)     -- prop[N] <  V
 *   (le  p:N:W  c:V)     -- prop[N] <= V
 *   (gt  p:N:W  c:V)     -- prop[N] >  V
 *   (ge  p:N:W  c:V)     -- prop[N] >= V
 *   (eq  p:N:W  c:V)     -- prop[N] == V
 *   (ne  p:N:W  c:V)     -- prop[N] != V
 *   (and expr expr)      -- logical AND
 *   (or  expr expr)      -- logical OR
 *   (not expr)           -- logical NOT
 *   (inside p:N:W [c:lo,c:hi] c:val ...) -- prop[N] inside ranges/values
 *   Multiple top-level exprs in one IR string are implicitly AND'd.
 */

# include  "class_type.h"
# include  "vvp_cobject.h"
# include  "vvp_z3.h"

# include  <z3.h>
# include  <z3_optimization.h>
# include  <cstdlib>
# include  <cstring>
# include  <sstream>
# include  <string>
# include  <vector>
# include  <stdint.h>

using namespace std;

/* ---------------------------------------------------------------
 * Simple recursive-descent tokenizer/parser for the IR format.
 * --------------------------------------------------------------- */

struct IRParser {
      const char* p;
      IRParser(const string&s) : p(s.c_str()) {}

      void skip_ws() { while (*p == ' ' || *p == '\t' || *p == '\n') ++p; }

      bool at_end() { skip_ws(); return !*p; }

      // Peek at next non-whitespace char
      char peek() { skip_ws(); return *p; }

      // Consume one char
      char consume() { return *p++; }

      // Read a token until whitespace or delimiter
      string read_token() {
	    skip_ws();
	    string tok;
	    while (*p && *p != ' ' && *p != '\t' && *p != '\n'
		   && *p != '(' && *p != ')' && *p != '[' && *p != ']'
		   && *p != ',') {
		  tok += *p++;
	    }
	    return tok;
      }

      bool expect(char c) {
	    skip_ws();
	    if (*p == c) { ++p; return true; }
	    return false;
      }
};

/* ---------------------------------------------------------------
 * Z3 expression builder context
 * --------------------------------------------------------------- */

struct Z3Builder {
      Z3_context ctx;
      // One Z3 bitvector constant per property index/width pair
      struct PropVar {
	    unsigned idx;
	    unsigned width;
	    Z3_ast var;
      };
      vector<PropVar> prop_vars;
      const class_type* defn;
      vvp_cobject* cobj;

      Z3Builder(Z3_context c, const class_type* d, vvp_cobject* o)
      : ctx(c), defn(d), cobj(o) {}

      Z3_ast get_prop_var(unsigned idx, unsigned width) {
	    for (auto& v : prop_vars)
		  if (v.idx == idx) return v.var;
	    char name[32];
	    snprintf(name, sizeof(name), "p%u", idx);
	    Z3_sort sort = Z3_mk_bv_sort(ctx, width ? width : 32);
	    Z3_symbol sym = Z3_mk_string_symbol(ctx, name);
	    Z3_ast var = Z3_mk_const(ctx, sym, sort);
	    PropVar pv;  pv.idx = idx;  pv.width = width;  pv.var = var;
	    prop_vars.push_back(pv);
	    return var;
      }

      // Build a Z3 boolean from "1" (true) or "0" (false)
      Z3_ast mk_true()  { return Z3_mk_true(ctx); }
      Z3_ast mk_false() { return Z3_mk_false(ctx); }
};

// Forward declaration
static Z3_ast build_z3_expr(IRParser&, Z3Builder&);

// Parse "p:N:W" — returns Z3 bitvector variable
static Z3_ast parse_prop(IRParser&, Z3Builder& b, const string& tok)
{
      const char* s = tok.c_str() + 2; // skip "p:"
      unsigned idx = (unsigned)atoi(s);
      while (*s && *s != ':') ++s;
      unsigned width = 32;
      if (*s == ':') width = (unsigned)atoi(s + 1);
      return b.get_prop_var(idx, width);
}

// Get width from a Z3 bitvector AST
static unsigned bv_width(Z3_context ctx, Z3_ast a)
{
      Z3_sort sort = Z3_get_sort(ctx, a);
      if (Z3_get_sort_kind(ctx, sort) == Z3_BV_SORT)
	    return Z3_get_bv_sort_size(ctx, sort);
      return 32;
}

static Z3_ast build_z3_atom(IRParser& par, Z3Builder& b)
{
      par.skip_ws();
      if (par.peek() == '(') {
	    par.consume(); // '('
	    return build_z3_expr(par, b);
      }
      string tok = par.read_token();
      if (tok.empty()) return b.mk_true();
      if (tok.substr(0,2) == "p:") return parse_prop(par, b, tok);
      if (tok.substr(0,2) == "c:") {
	    uint64_t v = (uint64_t)strtoull(tok.c_str()+2, nullptr, 10);
	    Z3_sort sort = Z3_mk_bv_sort(b.ctx, 32);
	    return Z3_mk_unsigned_int64(b.ctx, v, sort);
      }
      return b.mk_true();
}

static Z3_ast build_z3_expr(IRParser& par, Z3Builder& b)
{
      par.skip_ws();
      string op = par.read_token();
      if (op.empty()) return b.mk_true();

      if (op == "and" || op == "or") {
	    Z3_ast left  = build_z3_atom(par, b);
	    Z3_ast right = build_z3_atom(par, b);
	    par.skip_ws(); par.expect(')');
	    if (op == "and") {
		  Z3_ast args[2] = {left, right};
		  return Z3_mk_and(b.ctx, 2, args);
	    } else {
		  Z3_ast args[2] = {left, right};
		  return Z3_mk_or(b.ctx, 2, args);
	    }
      }

      if (op == "not") {
	    Z3_ast sub = build_z3_atom(par, b);
	    par.skip_ws(); par.expect(')');
	    return Z3_mk_not(b.ctx, sub);
      }

      // Binary comparison: lt le gt ge eq ne
      if (op == "lt" || op == "le" || op == "gt" || op == "ge"
	  || op == "eq" || op == "ne") {
	    Z3_ast left  = build_z3_atom(par, b);
	    Z3_ast right = build_z3_atom(par, b);
	    par.skip_ws(); par.expect(')');

	    // Make sure both sides have the same BV width
	    unsigned lw = bv_width(b.ctx, left);
	    unsigned rw = bv_width(b.ctx, right);
	    if (lw != rw) {
		  // Resize the constant (right) to match left
		  // This handles cases like c:8 with a p:N:32 var
		  if (rw < lw) {
			// zero-extend right
			right = Z3_mk_zero_ext(b.ctx, lw - rw, right);
		  } else {
			left = Z3_mk_zero_ext(b.ctx, rw - lw, left);
		  }
	    }

	    if (op == "lt") return Z3_mk_bvult(b.ctx, left, right);
	    if (op == "le") return Z3_mk_bvule(b.ctx, left, right);
	    if (op == "gt") return Z3_mk_bvugt(b.ctx, left, right);
	    if (op == "ge") return Z3_mk_bvuge(b.ctx, left, right);
	    if (op == "eq") return Z3_mk_eq(b.ctx, left, right);
	    // ne
	    return Z3_mk_not(b.ctx, Z3_mk_eq(b.ctx, left, right));
      }

      if (op == "inside") {
	    // Format: (inside p:N:W [c:lo,c:hi] c:val ...)
	    Z3_ast subject = build_z3_atom(par, b);
	    unsigned sw = bv_width(b.ctx, subject);

	    vector<Z3_ast> clauses;
	    par.skip_ws();
	    while (par.peek() != ')' && !par.at_end()) {
		  if (par.peek() == '[') {
			par.consume(); // '['
			string lo_tok = par.read_token();
			par.expect(',');
			string hi_tok = par.read_token();
			par.expect(']');
			uint64_t lo_v = strtoull(lo_tok.c_str()+2, nullptr, 10);
			uint64_t hi_v = strtoull(hi_tok.c_str()+2, nullptr, 10);
			Z3_ast lo = Z3_mk_unsigned_int64(b.ctx, lo_v,
						 Z3_mk_bv_sort(b.ctx, sw));
			Z3_ast hi = Z3_mk_unsigned_int64(b.ctx, hi_v,
						 Z3_mk_bv_sort(b.ctx, sw));
			// subject >= lo && subject <= hi
			Z3_ast c1 = Z3_mk_bvuge(b.ctx, subject, lo);
			Z3_ast c2 = Z3_mk_bvule(b.ctx, subject, hi);
			Z3_ast both[2] = {c1, c2};
			clauses.push_back(Z3_mk_and(b.ctx, 2, both));
		  } else {
			// Single value
			string tok = par.read_token();
			if (tok.substr(0,2) == "c:") {
			      uint64_t v = strtoull(tok.c_str()+2, nullptr, 10);
			      Z3_ast cv = Z3_mk_unsigned_int64(b.ctx, v,
						      Z3_mk_bv_sort(b.ctx, sw));
			      clauses.push_back(Z3_mk_eq(b.ctx, subject, cv));
			}
		  }
		  par.skip_ws();
	    }
	    par.expect(')');

	    if (clauses.empty()) return b.mk_true();
	    if (clauses.size() == 1) return clauses[0];
	    return Z3_mk_or(b.ctx, (unsigned)clauses.size(), clauses.data());
      }

      // Unknown operator — skip to matching ')' and return true
      int depth = 1;
      while (!par.at_end() && depth > 0) {
	    char c = par.consume();
	    if (c == '(') ++depth;
	    else if (c == ')') --depth;
      }
      return b.mk_true();
}

// Parse the full constraint IR string into Z3 assertions (implicit AND)
static Z3_ast parse_constraint_ir(const string& ir, Z3Builder& b)
{
      IRParser par(ir);
      vector<Z3_ast> assertions;

      while (!par.at_end()) {
	    Z3_ast expr = build_z3_atom(par, b);
	    assertions.push_back(expr);
      }

      if (assertions.empty()) return b.mk_true();
      if (assertions.size() == 1) return assertions[0];
      return Z3_mk_and(b.ctx, (unsigned)assertions.size(), assertions.data());
}

/* Extract uint64 bits from a vvp_cobject property (up to 64 bits). */
static uint64_t cobj_prop_bits(vvp_cobject* cobj, unsigned idx)
{
      vvp_vector4_t vec;
      cobj->get_vec4(idx, vec);
      uint64_t bits = 0;
      unsigned wid = vec.size();
      if (wid > 64) wid = 64;
      for (unsigned b = 0; b < wid; ++b)
	    if (vec.value(b) == BIT4_1) bits |= (1ULL << b);
      return bits;
}

/* Set vvp_cobject property from uint64 bits. */
static void cobj_set_prop_bits(vvp_cobject* cobj, unsigned idx, uint64_t bits)
{
      vvp_vector4_t vec;
      cobj->get_vec4(idx, vec);
      unsigned wid = vec.size();
      if (wid == 0) return;
      for (unsigned b = 0; b < wid; ++b)
	    vec.set_bit(b, ((bits >> b) & 1) ? BIT4_1 : BIT4_0);
      cobj->set_vec4(idx, vec);
}

/* Substitute "v:N:W" value-slot tokens in an IR string with "c:V". */
static string substitute_slots(const string& ir,
                                const vector<uint64_t>& slot_vals)
{
      if (slot_vals.empty()) return ir;
      string result;
      const char* p = ir.c_str();
      while (*p) {
	    if (p[0]=='v' && p[1]==':') {
		  const char*q = p + 2;
		  unsigned slot = (unsigned)strtoul(q, const_cast<char**>(&q), 10);
		  // skip ":W" width field
		  if (*q == ':') { q++; while (*q && *q != ' ' && *q != ')') q++; }
		  if (slot < slot_vals.size()) {
			result += "c:" + to_string(slot_vals[slot]);
		  } else {
			result += "c:0";
		  }
		  p = q;
	    } else {
		  result += *p++;
	    }
      }
      return result;
}

bool vvp_z3_randomize(const class_type* defn, vvp_cobject* cobj,
                      const vector<string>& extra_ir,
                      const vector<uint64_t>& slot_vals)
{
      if (defn->constraint_count() == 0 && extra_ir.empty()) return false;

      Z3_config cfg = Z3_mk_config();
      Z3_set_param_value(cfg, "model", "true");
      Z3_context ctx = Z3_mk_context(cfg);
      Z3_del_config(cfg);

      Z3Builder builder(ctx, defn, cobj);

      // Use Z3 optimize so we can add soft "match random target" constraints
      // to guide solutions toward varied values.
      Z3_optimize opt = Z3_mk_optimize(ctx);
      Z3_optimize_inc_ref(ctx, opt);

      // Assert hard constraints (class-level), skipping disabled ones.
      for (size_t ci = 0; ci < defn->constraint_count(); ++ci) {
	    if (cobj && !cobj->constraint_mode(ci)) continue;
	    const string& ir = defn->constraint_ir(ci);
	    if (ir.empty()) continue;
	    Z3_ast assertion = parse_constraint_ir(ir, builder);
	    Z3_optimize_assert(ctx, opt, assertion);
      }
      // Assert with-constraints (call-site inline), with slot substitution.
      for (const string& wir : extra_ir) {
	    if (wir.empty()) continue;
	    string sub = substitute_slots(wir, slot_vals);
	    Z3_ast assertion = parse_constraint_ir(sub, builder);
	    Z3_optimize_assert(ctx, opt, assertion);
      }

      // Check if the already-randomized values satisfy all hard constraints.
      // Use a temporary solver for this fast-path check (opt is slow for pure
      // feasibility when we already have a candidate).
      {
	    Z3_solver chk = Z3_mk_solver(ctx);
	    Z3_solver_inc_ref(ctx, chk);
	    for (size_t ci = 0; ci < defn->constraint_count(); ++ci) {
		  if (cobj && !cobj->constraint_mode(ci)) continue;
		  const string& ir = defn->constraint_ir(ci);
		  if (ir.empty()) continue;
		  Z3_ast a = parse_constraint_ir(ir, builder);
		  Z3_solver_assert(ctx, chk, a);
	    }
	    for (const string& wir : extra_ir) {
		  if (wir.empty()) continue;
		  string sub = substitute_slots(wir, slot_vals);
		  Z3_ast a = parse_constraint_ir(sub, builder);
		  Z3_solver_assert(ctx, chk, a);
	    }
	    for (auto& pv : builder.prop_vars) {
		  uint64_t bits = cobj_prop_bits(cobj, pv.idx);
		  Z3_sort sort = Z3_mk_bv_sort(ctx, pv.width);
		  Z3_ast cv = Z3_mk_unsigned_int64(ctx, bits, sort);
		  Z3_solver_assert(ctx, chk, Z3_mk_eq(ctx, pv.var, cv));
	    }
	    Z3_lbool precheck = Z3_solver_check(ctx, chk);
	    Z3_solver_dec_ref(ctx, chk);

	    if (precheck == Z3_L_TRUE) {
		  // Random values already satisfy all constraints — keep them.
		  Z3_optimize_dec_ref(ctx, opt);
		  Z3_del_context(ctx);
		  return false;
	    }
      }

      // Random values violate constraints.  Use minimize(bvxor(prop, rand))
      // as the objective for each rand property.  When the random value is in
      // the feasible region, xor == 0 so Z3 returns it exactly.  When it is
      // not, Z3 finds the feasible value with the minimum XOR distance from the
      // random target, giving varied results across different random seeds.
      for (auto& pv : builder.prop_vars) {
	    uint64_t rand_bits = cobj_prop_bits(cobj, pv.idx);
	    Z3_sort sort = Z3_mk_bv_sort(ctx, pv.width);
	    Z3_ast rv = Z3_mk_unsigned_int64(ctx, rand_bits, sort);
	    Z3_ast xor_expr = Z3_mk_bvxor(ctx, pv.var, rv);
	    Z3_optimize_minimize(ctx, opt, xor_expr);
      }

      Z3_lbool result = Z3_optimize_check(ctx, opt, 0, nullptr);
      if (result != Z3_L_TRUE) {
	    Z3_optimize_dec_ref(ctx, opt);
	    Z3_del_context(ctx);
	    return false;
      }

      Z3_model model = Z3_optimize_get_model(ctx, opt);
      Z3_model_inc_ref(ctx, model);

      for (auto& pv : builder.prop_vars) {
	    Z3_ast interp = nullptr;
	    if (Z3_model_eval(ctx, model, pv.var, 1, &interp) && interp) {
		  uint64_t bits = 0;
		  if (Z3_get_numeral_uint64(ctx, interp, &bits))
			cobj_set_prop_bits(cobj, pv.idx, bits);
	    }
      }

      Z3_model_dec_ref(ctx, model);
      Z3_optimize_dec_ref(ctx, opt);
      Z3_del_context(ctx);
      return true;
}
