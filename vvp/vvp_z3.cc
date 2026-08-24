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
 *   r:I.J.K:W[:s]        -- integral state reached through object props I.J.K
 *   (and expr expr)      -- logical AND
 *   (or  expr expr)      -- logical OR
 *   (not expr)           -- logical NOT
 *   (trunc:W[:s] expr)   -- self-determined W-bit integral result
 *   (inside p:N:W [c:lo,c:hi] c:val ...) -- prop[N] inside ranges/values
 *   Multiple top-level exprs in one IR string are implicitly AND'd.
 */

# include  "class_type.h"
# include  "vvp_cobject.h"
# include  "vvp_darray.h"
# include  "vvp_assoc.h"
# include  "vvp_z3.h"

# include  <z3.h>
# include  <z3_optimization.h>
# include  <cassert>
# include  <cctype>
# include  <cstdlib>
# include  <cstring>
# include  <sstream>
# include  <map>
# include  <set>
# include  <string>
# include  <vector>
# include  <stdint.h>
# include  <climits>

using namespace std;

/* Opt-in constraint-solver trace (set IVL_Z3_DYNDBG=1). Off by default so
 * production runs are unaffected. Used to localize the Windows-only
 * dynamic-foreach corner (m3_constraint_dynforeach_test): it prints the
 * expansion element count, the per-element index each foreach instance folds
 * to, and the solved element value written back — the values that differ
 * between the Linux/macOS (correct) and Windows (garbage) builds. */
static bool z3_dyndbg()
{
      static int on = -1;
      if (on < 0) {
	    const char*e = getenv("IVL_Z3_DYNDBG");
	    on = (e && *e && strcmp(e, "0") != 0) ? 1 : 0;
      }
      return on != 0;
}

static bool z3_solve_trace(const class_type*defn)
{
      const char*e = getenv("IVL_Z3_SOLVE_TRACE");
      if (!(e && *e) || strcmp(e, "0") == 0)
	    return false;
      if (strcmp(e, "1") == 0 || strcmp(e, "true") == 0
	  || strcmp(e, "ALL") == 0 || strcmp(e, "*") == 0)
	    return true;
      return defn && strstr(defn->class_name().c_str(), e) != 0;
}

/* Evaluate `var` under `model` and extract it as a uint64.
 *
 * Robustness note (Windows corner, m3_constraint_dynforeach_test): the
 * MSYS2/MinGW Z3 build does not fully reduce equality-eliminated variables
 * in Z3_model_eval. A constraint like `elem == base + 1` lets the solver
 * substitute `elem := base + 1` and drop `elem` from the model; evaluating
 * `elem` then returns a term still containing the `base` constant (not its
 * value), which Z3_get_numeral_uint64 rejects — the element was never
 * written back and kept its random fill. The `+ 0` equation orients the
 * other way (base := e0), which is why elem 0 and base themselves evaluated
 * fine and only the i>=1 elements failed, and only on Windows (the
 * Linux/macOS Z3 reduces to a numeral in one pass).
 *
 * So: iterate model_eval — each pass substitutes the model's known
 * interpretations into the term, so a residue like `bvadd(base, 1)` folds
 * once `base`'s own value is substituted — and Z3_simplify between passes
 * to constant-fold. On well-behaved builds the first pass is already a
 * numeral and the loop exits immediately. */
/* String-level ground evaluator: parse the SMT-LIB2 text of a term and
 * fold it. Last-resort fallback for Z3 builds whose C-API inspection
 * calls misbehave (the MSYS2/Windows probe showed z3_ground_uint64 below
 * failing on `(bvneg #xffffff92)` even though the identical AST folds
 * fine through the same code against the Linux Z3 — while
 * Z3_ast_to_string demonstrably works there, since the trace printed the
 * term). Handles numerals (#x/#b/decimal), bvneg/bvnot, and n-ary
 * bvadd/bvsub/bvmul; the caller masks to the term's width. Anything else
 * (symbols, unhandled ops) fails, so a non-ground term can never be
 * silently misread. */
static bool z3_str_fold_(const char*&p, uint64_t& out)
{
      while (*p == ' ' || *p == '\n' || *p == '\t') p++;
      if (*p == '#') {
	    p++;
	    int base = 0;
	    if (*p == 'x') base = 16;
	    else if (*p == 'b') base = 2;
	    else return false;
	    p++;
	    char*end = nullptr;
	    out = strtoull(p, &end, base);
	    if (end == p) return false;
	    p = end;
	    return true;
      }
      if (*p >= '0' && *p <= '9') {
	    char*end = nullptr;
	    out = strtoull(p, &end, 10);
	    p = end;
	    return true;
      }
      if (*p != '(') return false;
      p++;
      while (*p == ' ') p++;
      char op[16];
      size_t oi = 0;
      while (*p && *p != ' ' && *p != '(' && *p != ')' && oi + 1 < sizeof op)
	    op[oi++] = *p++;
      op[oi] = 0;
      bool is_neg = !strcmp(op, "bvneg"), is_not = !strcmp(op, "bvnot");
      bool is_add = !strcmp(op, "bvadd"), is_sub = !strcmp(op, "bvsub");
      bool is_mul = !strcmp(op, "bvmul");
      if (!(is_neg || is_not || is_add || is_sub || is_mul)) return false;
      uint64_t acc = 0;
      bool first = true;
      for (;;) {
	    while (*p == ' ' || *p == '\n' || *p == '\t') p++;
	    if (*p == ')') { p++; break; }
	    if (!*p) return false;
	    uint64_t v = 0;
	    if (!z3_str_fold_(p, v)) return false;
	    if (first) { acc = v; first = false; }
	    else if (is_add) acc += v;
	    else if (is_sub) acc -= v;
	    else if (is_mul) acc *= v;
	    else return false;   // unary op with >1 args
      }
      if (first) return false;   // no operands
      if (is_neg) acc = 0 - acc;
      if (is_not) acc = ~acc;
      out = acc;
      return true;
}

static bool z3_str_ground_uint64(Z3_context ctx, Z3_ast t, unsigned width,
                                 uint64_t& out)
{
      if (width == 0 || width > 64) return false;
      Z3_string s = Z3_ast_to_string(ctx, t);
      if (!s) return false;
      const char*p = s;
      uint64_t v = 0;
      if (!z3_str_fold_(p, v)) return false;
      while (*p == ' ' || *p == '\n') p++;
      if (*p) return false;   // trailing junk: not a fully parsed term
      uint64_t mask = (width == 64) ? ~UINT64_C(0)
                                    : ((UINT64_C(1) << width) - 1);
      out = v & mask;
      return true;
}

/* Structurally evaluate a GROUND bitvector term to uint64.
 *
 * The MSYS2/Windows Z3 build hands back model values like
 * `(bvneg #xffffff92)` — bvneg of a numeral, i.e. the correct value in an
 * unreduced wrapper — and fails to fold it in BOTH Z3_model_eval and
 * Z3_simplify (verified via the CI probe residue trace; Linux/macOS Z3
 * folds the same term to a numeral). So do the constant folding here for
 * the ground bitvector operators, masking each step to the term's width. */
/* Extract a (possibly NEGATIVE) numeral via its decimal string, reduced
 * mod 2^width. ROOT CAUSE of the whole m3 Windows corner (proven by
 * reproducing with a -DZ3_USE_LIB_GMP=ON build of Z3 4.16.0 on Linux —
 * MSYS2 builds Z3 with GMP, official Linux builds do not): the
 * GMP-backed Optimize model stores an equality-eliminated bitvector
 * value as a NEGATIVE numeral. It prints as `(bvneg #xffffff92)`, the C
 * API classifies it Z3_NUMERAL_AST, Z3_get_numeral_uint64 rejects the
 * negative, the app-inspection view is meaningless for it (decl kind is
 * not BNEG, nargs 0), and Z3_get_numeral_int64 even returns success
 * with a WRONG value (0). The one API that tells the truth is
 * Z3_get_numeral_string: "-4294967186" — i.e. -(0xffffff92), which is
 * exactly the solved value mod 2^32 (= 110 = base+1). */
static bool z3_numstr_uint64(Z3_context ctx, Z3_ast t, uint64_t& out)
{
      if (Z3_get_ast_kind(ctx, t) != Z3_NUMERAL_AST)
	    return false;
      Z3_sort s = Z3_get_sort(ctx, t);
      if (Z3_get_sort_kind(ctx, s) != Z3_BV_SORT)
	    return false;
      unsigned w = Z3_get_bv_sort_size(ctx, s);
      if (w == 0 || w > 64)
	    return false;
      Z3_string str = Z3_get_numeral_string(ctx, t);
      if (!str || !*str)
	    return false;
      bool neg = (*str == '-');
      const char*p = str + (neg ? 1 : 0);
      if (!*p)
	    return false;
      uint64_t acc = 0;
      for ( ; *p ; p += 1) {
	    if (*p < '0' || *p > '9')
		  return false;
	    acc = acc * 10 + (uint64_t)(*p - '0');   // wraps mod 2^64; we
      }						     // only need mod 2^w<=64
      if (neg)
	    acc = 0 - acc;
      uint64_t mask = (w == 64) ? ~UINT64_C(0) : ((UINT64_C(1) << w) - 1);
      out = acc & mask;
      return true;
}

static bool z3_ground_uint64(Z3_context ctx, Z3_ast t, uint64_t& out,
                             int depth = 0)
{
      if (Z3_get_numeral_uint64(ctx, t, &out))
	    return true;
      if (z3_numstr_uint64(ctx, t, out))
	    return true;
      if (depth > 8)
	    return false;
      if (Z3_get_ast_kind(ctx, t) != Z3_APP_AST)
	    return false;
      Z3_sort s = Z3_get_sort(ctx, t);
      if (Z3_get_sort_kind(ctx, s) != Z3_BV_SORT)
	    return false;
      unsigned w = Z3_get_bv_sort_size(ctx, s);
      if (w == 0 || w > 64)
	    return false;
      uint64_t mask = (w == 64) ? ~UINT64_C(0) : ((UINT64_C(1) << w) - 1);
      Z3_app app = Z3_to_app(ctx, t);
      Z3_decl_kind k = Z3_get_decl_kind(ctx, Z3_get_app_decl(ctx, app));
      unsigned n = Z3_get_app_num_args(ctx, app);
      uint64_t a = 0;
      switch (k) {
	  case Z3_OP_BNEG:
	    if (n != 1) return false;
	    if (!z3_ground_uint64(ctx, Z3_get_app_arg(ctx, app, 0), a, depth+1))
		  return false;
	    out = (0 - a) & mask;
	    return true;
	  case Z3_OP_BNOT:
	    if (n != 1) return false;
	    if (!z3_ground_uint64(ctx, Z3_get_app_arg(ctx, app, 0), a, depth+1))
		  return false;
	    out = ~a & mask;
	    return true;
	  case Z3_OP_BADD:
	  case Z3_OP_BMUL: {
		  // n-ary in Z3
		uint64_t acc = (k == Z3_OP_BADD) ? 0 : 1;
		for (unsigned i = 0 ; i < n ; i += 1) {
		      if (!z3_ground_uint64(ctx, Z3_get_app_arg(ctx, app, i),
					    a, depth+1))
			    return false;
		      acc = (k == Z3_OP_BADD) ? (acc + a) : (acc * a);
		}
		out = acc & mask;
		return true;
	  }
	  case Z3_OP_BSUB: {
		if (n != 2) return false;
		uint64_t b = 0;
		if (!z3_ground_uint64(ctx, Z3_get_app_arg(ctx, app, 0), a, depth+1))
		      return false;
		if (!z3_ground_uint64(ctx, Z3_get_app_arg(ctx, app, 1), b, depth+1))
		      return false;
		out = (a - b) & mask;
		return true;
	  }
	  case Z3_OP_ZERO_EXT:
	  case Z3_OP_SIGN_EXT: {
		if (n != 1) return false;
		Z3_ast arg = Z3_get_app_arg(ctx, app, 0);
		Z3_sort as = Z3_get_sort(ctx, arg);
		if (Z3_get_sort_kind(ctx, as) != Z3_BV_SORT) return false;
		unsigned aw = Z3_get_bv_sort_size(ctx, as);
		if (aw == 0 || aw > 64) return false;
		if (!z3_ground_uint64(ctx, arg, a, depth+1))
		      return false;
		if (k == Z3_OP_SIGN_EXT && aw < 64 && (a >> (aw - 1)) & 1)
		      a |= ~((UINT64_C(1) << aw) - 1);
		out = a & mask;
		return true;
	  }
	  default:
	    return false;
      }
}

static bool z3_eval_uint64(Z3_context ctx, Z3_model model, Z3_ast var,
                           uint64_t& out)
{
	// The variables we create are all bitvector consts of known width;
	// take the width from the var itself for the string-fallback mask.
      unsigned width = 64;
      {
	    Z3_sort vs = Z3_get_sort(ctx, var);
	    if (Z3_get_sort_kind(ctx, vs) == Z3_BV_SORT) {
		  unsigned w = Z3_get_bv_sort_size(ctx, vs);
		  if (w >= 1 && w <= 64) width = w;
	    }
      }
      Z3_ast interp = var;
      for (int pass = 0 ; pass < 4 ; pass += 1) {
	    Z3_ast next = nullptr;
	    if (!(Z3_model_eval(ctx, model, interp, 1, &next) && next))
		  break;
	    next = Z3_simplify(ctx, next);
	    if (z3_ground_uint64(ctx, next, out))
		  return true;
	    if (z3_str_ground_uint64(ctx, next, width, out))
		  return true;
	    if (next == interp)   // no progress; further passes are futile
		  break;
	    interp = next;
      }
      if (z3_dyndbg()) {
	      // Z3_ast_to_string reuses one internal buffer per context, so
	      // the two strings must be copied out before printing together.
	    std::string vs = Z3_ast_to_string(ctx, var);
	    std::string rs = interp ? Z3_ast_to_string(ctx, interp) : "(null)";
	      // Dump the raw C-API answers for the residue so a build whose
	      // inspection calls misbehave reveals exactly which one.
	    int akind = -1, skind = -1, dkind = -1, nargs = -1;
	    unsigned rw = 0;
	    if (interp) {
		  akind = (int)Z3_get_ast_kind(ctx, interp);
		  Z3_sort rs2 = Z3_get_sort(ctx, interp);
		  skind = (int)Z3_get_sort_kind(ctx, rs2);
		  if (skind == (int)Z3_BV_SORT)
			rw = Z3_get_bv_sort_size(ctx, rs2);
		  if (akind == (int)Z3_APP_AST) {
			Z3_app app = Z3_to_app(ctx, interp);
			dkind = (int)Z3_get_decl_kind(ctx,
					Z3_get_app_decl(ctx, app));
			nargs = (int)Z3_get_app_num_args(ctx, app);
		  }
	    }
	    fprintf(stderr, "[z3dyn] eval-fail var=<%s> residue=<%s> "
		    "astkind=%d sortkind=%d width=%u declkind=%d nargs=%d "
		    "(BNEG=%d APP=%d BV=%d)\n",
		    vs.c_str(), rs.c_str(), akind, skind, rw, dkind, nargs,
		    (int)Z3_OP_BNEG, (int)Z3_APP_AST, (int)Z3_BV_SORT);
      }
      return false;
}

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

	// One-level scalar members of an object-backed unpacked-struct
	// property ("m:OUTER:MEMBER:WIDTH[:s]"). The pair, rather than the
	// member index alone, is the solver identity because every synthetic
	// struct type numbers its own members from zero.
      struct MemberVar {
	    unsigned outer;
	    unsigned member;
	    unsigned width;
	    Z3_ast var;
      };
      vector<MemberVar> member_vars;
      const class_type* defn;
      vvp_cobject* cobj;
      // C7 (Phase 62b): optional optimize handle for soft asserts.
      // When non-null, dist branches emit Z3_optimize_assert_soft per
      // branch with the user-specified weight, biasing the model toward
      // higher-weight values.  The builder also collects pending soft
      // asserts here so the caller can apply them once.
      Z3_optimize opt;
      // C7/I4: pending soft assertions.  `from_soft_kw` distinguishes the
      // explicit `soft` keyword (deterministic preference — should force
      // optimize even if hard constraints are already satisfied) from
      // `dist` branches (probabilistic — bvxor diversity randomizes the
      // pick across branches; early-return on hard satisfaction is OK).
      struct VarRef {
	    enum Kind { PROP, MEMBER, ELEM, SIZE } kind;
	    unsigned idx;
	    unsigned leaf;

	    bool operator<(const VarRef&that) const {
		  if (kind != that.kind) return kind < that.kind;
		  if (idx != that.idx) return idx < that.idx;
		  return leaf < that.leaf;
	    }
	 };
      struct SoftAssert { Z3_ast a; unsigned weight; bool from_soft_kw;
			  std::set<VarRef> refs; };
      vector<SoftAssert> pending_soft;

      // A soft constraint (or a dist preference) nested on the right of
      // a constraint implication is active only while every enclosing
      // guard is true. The IR parser is recursive and records soft/dist
      // preferences as side effects, so retain those guards explicitly
      // while parsing the implication RHS.
      vector<Z3_ast> soft_guards;
      Z3_ast guard_soft_assert(Z3_ast assertion) const {
	    for (size_t i = soft_guards.size() ; i-- > 0 ; )
		  assertion = Z3_mk_implies(ctx, soft_guards[i], assertion);
	    return assertion;
      }

      // RANDOM-DIST fix #2 (18.5.4): a `dist` node's branches, recorded
      // structurally (not just as OR'd hard clauses + soft preferences)
      // so the solver can draw a value with probability proportional to
      // its weight instead of merely preferring the heaviest branch.
      // Only usable when `subject` is exactly a plain property variable
      // (the common, and only cheaply-enumerable, case); anything else
      // still falls back to the pre-existing hard-union + soft-weight
      // approximation below.
      struct DistBranch {
	    unsigned weight;
	    bool is_range;
	    uint64_t lo, hi;   // lo==hi and is_range==false for a single value
      };
      struct DistSpec {
	    Z3_ast subject;
	    unsigned width;
	    std::vector<DistBranch> branches;
      };
      std::vector<DistSpec> dist_specs;

      // M3B-3 (`disable soft <var>`, IEEE 1800-2017 18.5.14.1): keep the
      // complete variable identity. A struct member, array element, array
      // size, and their owning property can share a numeric outer index but
      // are not interchangeable leaves. Disabling an aggregate property is
      // deliberately broader and covers every descendant with that index.
      std::set<VarRef> disabled_soft_refs;
      std::set<VarRef>* collect_refs = nullptr;
      bool collect_refs_only = false;
      bool soft_ref_disabled(const VarRef&ref) const {
	    for (const VarRef&disabled : disabled_soft_refs) {
		  if (disabled.kind == ref.kind && disabled.idx == ref.idx
		      && disabled.leaf == ref.leaf)
			return true;
		  if (disabled.kind == VarRef::PROP && disabled.idx == ref.idx)
			return true;
	    }
	    return false;
      }
      bool any_soft_kw_assert() const {
            for (const auto& s : pending_soft) if (s.from_soft_kw) return true;
            return false;
      }

	// Dynamic-container size variables ("s:N:T"): one 32-bit BV per
	// property index. T is either %new/darray-style element type text,
	// or Q<MAX>:<element-type> for a queue (MAX=0 means unbounded).
	// IEEE 1800-2017 18.4 randomizes the size before the elements.
      struct SizeVar {
	    unsigned idx;
	    string container_type;
	    Z3_ast var;
      };
      vector<SizeVar> size_vars;

	// Array element variables ("e:N:W:I"): property index, element
	// width, constant element index (IEEE 1800-2017 18.5.8.1
	// iterative constraints over static arrays).
      struct ElemVar {
	    unsigned idx;
	    unsigned width;
	    unsigned elem;
	    Z3_ast var;
      };
      vector<ElemVar> elem_vars;

      Z3_ast get_size_var(unsigned idx, const string&dtype) {
	    for (auto& v : size_vars)
		  if (v.idx == idx) return v.var;
	    char name[32];
	    snprintf(name, sizeof(name), "s%u", idx);
	    Z3_sort sort = Z3_mk_bv_sort(ctx, 32);
	    Z3_ast var = Z3_mk_const(ctx, Z3_mk_string_symbol(ctx, name), sort);
	    SizeVar sv; sv.idx = idx; sv.container_type = dtype; sv.var = var;
	    size_vars.push_back(sv);
	    return var;
      }

      Z3_ast get_elem_var(unsigned idx, unsigned width, unsigned elem) {
	    for (auto& v : elem_vars)
		  if (v.idx == idx && v.elem == elem) return v.var;
	    char name[48];
	    snprintf(name, sizeof(name), "e%u_%u", idx, elem);
	    Z3_sort sort = Z3_mk_bv_sort(ctx, width ? width : 32);
	    Z3_ast var = Z3_mk_const(ctx, Z3_mk_string_symbol(ctx, name), sort);
	    ElemVar ev; ev.idx = idx; ev.width = width ? width : 32;
	    ev.elem = elem; ev.var = var;
	    elem_vars.push_back(ev);
	    return var;
      }

	// Variables whose SystemVerilog type is signed. Comparisons where
	// a signed variable participates use the signed BV predicates
	// (IEEE 1800-2017 11.8.1; integer literals are signed).
      std::set<Z3_ast> signed_vars;
      bool is_signed(Z3_ast a) const
	    { return signed_vars.find(a) != signed_vars.end(); }

	// IEEE 1800-2017 11.6.1 expression width. Arithmetic here is
	// built at FULL precision -- an 8-bit add lands in a 9-bit
	// bitvector -- so nothing is lost while the expression is being
	// assembled. What the LRM actually specifies is a truncation to
	// the CONTEXT width, and the context is not known until the
	// comparison the expression feeds is reached. So each AST also
	// carries its SELF-DETERMINED width (max of its operands' , per
	// Table 11-21), which is a property of the expression alone;
	// the comparison takes the max of its two sides and coerces both
	// to exactly that many bits, truncating or extending. An AST
	// with no entry is its own width, which is right for every leaf.
	//
	// Without this, arithmetic was evaluated at the OPERAND width:
	// `a + b == 300' with two 8-bit rand variables wrapped mod 256
	// and came back UNSAT, and `s == a * b' with a 32-bit s solved
	// s to the low 8 bits of the product.
      std::map<Z3_ast,unsigned> sv_wid;
      void set_sv(Z3_ast a, unsigned w) { sv_wid[a] = w; }
      unsigned sv_of(Z3_ast a) {
	    std::map<Z3_ast,unsigned>::const_iterator it = sv_wid.find(a);
	    if (it != sv_wid.end()) return it->second;
	    return bv_width_(a);
      }
	// Coerce to exactly `w' bits: truncate the high bits away (the
	// LRM's context truncation) or extend, signed when the value is.
      Z3_ast coerce(Z3_ast a, unsigned w) {
	    unsigned aw = bv_width_(a);
	    if (aw == w) return a;
	    if (aw > w) return Z3_mk_extract(ctx, w - 1, 0, a);
	    return is_signed(a) ? Z3_mk_sign_ext(ctx, w - aw, a)
				: Z3_mk_zero_ext(ctx, w - aw, a);
      }
      unsigned bv_width_(Z3_ast a) const {
	    Z3_sort s = Z3_get_sort(ctx, a);
	    if (Z3_get_sort_kind(ctx, s) != Z3_BV_SORT) return 1;
	    return Z3_get_bv_sort_size(ctx, s);
      }

	// Dynamic-array foreach templates "(dynforeach P:W[:s] <body>)"
	// (IEEE 1800-2017 18.5.8.2). In the size pass (dyn_sizes null)
	// the body is captured raw and the form contributes `true`; in
	// the element pass (dyn_sizes set to the solved sizes) the body
	// is expanded once per element with the loop token L bound to
	// the element index, and "(delem P:W[:s] <idx>)" references
	// resolve to e:P:W:I element variables.
      struct DynForeach {
	    unsigned pidx;
	    unsigned ewid;
	    bool esigned;
	    std::string body;
      };
      std::vector<DynForeach> dyn_foreach;
      const std::map<unsigned,uint64_t>*dyn_sizes = nullptr;

	// solve...before ordering pairs (IEEE 1800-2017 18.5.10). A
	// selected static-array element and a dynamic-container size are
	// distinct ordering variables, rather than collapsing to their owning
	// property. This preserves directives such as `solve n before a.size'.
      struct OrderRef {
	    enum Kind { PROP, MEMBER, ELEM, SIZE } kind;
	    unsigned idx;
	    unsigned elem;

	    bool operator<(const OrderRef&that) const {
		  if (kind != that.kind) return kind < that.kind;
		  if (idx != that.idx) return idx < that.idx;
		  return elem < that.elem;
	    }
	    bool operator==(const OrderRef&that) const {
		  return kind == that.kind && idx == that.idx
			&& elem == that.elem;
	    }
      };
      std::vector<std::pair<OrderRef,OrderRef> > order_pairs;

      Z3Builder(Z3_context c, const class_type* d, vvp_cobject* o)
      : ctx(c), defn(d), cobj(o), opt(0) {}

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

      Z3_ast get_member_var(unsigned outer, unsigned member,
			    unsigned width) {
	    for (auto& v : member_vars)
		  if (v.outer == outer && v.member == member) return v.var;
	    char name[48];
	    snprintf(name, sizeof(name), "m%u_%u", outer, member);
	    Z3_sort sort = Z3_mk_bv_sort(ctx, width ? width : 32);
	    Z3_ast var = Z3_mk_const(ctx, Z3_mk_string_symbol(ctx, name), sort);
	    MemberVar mv;
	    mv.outer = outer;
	    mv.member = member;
	    mv.width = width ? width : 32;
	    mv.var = var;
	    member_vars.push_back(mv);
	    return var;
      }

      // Build a Z3 boolean from "1" (true) or "0" (false)
      Z3_ast mk_true()  { return Z3_mk_true(ctx); }
      Z3_ast mk_false() { return Z3_mk_false(ctx); }
};

// Forward declaration
static Z3_ast build_z3_expr(IRParser&, Z3Builder&);
static uint64_t cobj_prop_bits(vvp_cobject* cobj, unsigned idx);
static uint64_t cobj_member_bits(vvp_cobject* cobj, unsigned outer,
				 unsigned member);
static uint64_t cobj_elem_bits(vvp_cobject* cobj, unsigned idx, unsigned elem);
static uint64_t cobj_darray_size(vvp_cobject* cobj, unsigned idx);

// Parse "p:N:W[:s]" — returns Z3 bitvector variable
static Z3_ast parse_prop(IRParser&, Z3Builder& b, const string& tok)
{
      const char* s = tok.c_str() + 2; // skip "p:"
      unsigned idx = (unsigned)atoi(s);
      while (*s && *s != ':') ++s;
      unsigned width = 32;
      if (*s == ':') { width = (unsigned)atoi(s + 1); ++s; }
      while (*s && *s != ':') ++s;
      bool sflag = (*s == ':' && s[1] == 's');
      if (b.collect_refs) {
	    Z3Builder::VarRef ref = {Z3Builder::VarRef::PROP, idx, 0};
	    b.collect_refs->insert(ref);
      }
      if (b.collect_refs_only)
	    return Z3_mk_unsigned_int64(
		  b.ctx, 0, Z3_mk_bv_sort(b.ctx, width));
      Z3_ast var = b.get_prop_var(idx, width);
      if (sflag) b.signed_vars.insert(var);
      return var;
}

// Parse "m:OUTER:MEMBER:WIDTH[:s]" -- one scalar member of an unpacked
// struct class property.
static Z3_ast parse_member(IRParser&, Z3Builder& b, const string& tok)
{
      const char*s = tok.c_str() + 2;
      unsigned outer = (unsigned)atoi(s);
      while (*s && *s != ':') ++s;
      if (*s == ':') ++s;
      unsigned member = (unsigned)atoi(s);
      while (*s && *s != ':') ++s;
      unsigned width = 32;
      if (*s == ':') { width = (unsigned)atoi(s + 1); ++s; }
      while (*s && *s != ':') ++s;
      bool sflag = (*s == ':' && s[1] == 's');
      if (b.collect_refs) {
	    Z3Builder::VarRef ref = {
		  Z3Builder::VarRef::MEMBER, outer, member
	    };
	    b.collect_refs->insert(ref);
      }
      if (b.collect_refs_only)
	    return Z3_mk_unsigned_int64(
		  b.ctx, 0, Z3_mk_bv_sort(b.ctx, width));
      Z3_ast var = b.get_member_var(outer, member, width);
      if (sflag) b.signed_vars.insert(var);
      return var;
}

// Parse "s:N:T" -- returns the 32-bit dynamic-container size variable.
static Z3_ast parse_size(Z3Builder& b, const string& tok,
			 unsigned*idx_out = nullptr)
{
      const char*s = tok.c_str() + 2;
      unsigned idx = (unsigned)atoi(s);
      while (*s && *s != ':') ++s;
      string dtype = (*s == ':') ? string(s + 1) : string("v32");
      if (idx_out) *idx_out = idx;
      if (b.collect_refs) {
	    Z3Builder::VarRef ref = {Z3Builder::VarRef::SIZE, idx, 0};
	    b.collect_refs->insert(ref);
      }
      if (b.collect_refs_only)
	    return Z3_mk_unsigned_int64(
		  b.ctx, 0, Z3_mk_bv_sort(b.ctx, 32));
      return b.get_size_var(idx, dtype);
}

// Parse "e:N:W:I[:s]" -- returns the selected array-element variable.
static Z3_ast parse_elem(IRParser&, Z3Builder& b, const string& tok)
{
      const char*s = tok.c_str() + 2; // skip "e:"
      unsigned idx = (unsigned)atoi(s);
      while (*s && *s != ':') ++s;
      unsigned width = 32;
      if (*s == ':') { width = (unsigned)atoi(s + 1); ++s; }
      while (*s && *s != ':') ++s;
      unsigned elem = 0;
      if (*s == ':') { elem = (unsigned)atoi(s + 1); ++s; }
      while (*s && *s != ':') ++s;
      bool sflag = (*s == ':' && s[1] == 's');
      if (b.collect_refs) {
	    Z3Builder::VarRef ref = {Z3Builder::VarRef::ELEM, idx, elem};
	    b.collect_refs->insert(ref);
      }
      if (b.collect_refs_only)
	    return Z3_mk_unsigned_int64(
		  b.ctx, 0, Z3_mk_bv_sort(b.ctx, width));
      Z3_ast var = b.get_elem_var(idx, width, elem);
      if (sflag) b.signed_vars.insert(var);
      return var;
}

/* Parse r:I.J.K:W[:s]. Unlike p:N:W this is not a solver variable: it is
 * ordinary object state read through the live class-property chain at the
 * moment randomize() is called (IEEE 1800-2017 18.3). */
static Z3_ast parse_state_path(Z3Builder&b, const string&tok)
{
      const char*p = tok.c_str() + 2;
      vector<unsigned> path;
      while (*p) {
	    char*end = nullptr;
	    unsigned idx = (unsigned)strtoul(p, &end, 10);
	    if (end == p) break;
	    path.push_back(idx);
	    p = end;
	    if (*p == '.') { ++p; continue; }
	    break;
      }

      unsigned width = 32;
      bool sflag = false;
      if (*p == ':') {
	    char*end = nullptr;
	    width = (unsigned)strtoul(p + 1, &end, 10);
	    if (width == 0 || width > 64) width = 32;
	    p = end;
	    sflag = (*p == ':' && p[1] == 's');
      }

      uint64_t bits = 0;
      vvp_cobject*cur = b.cobj;
      if (!path.empty()) {
	    for (size_t i = 0 ; cur && i + 1 < path.size() ; i += 1) {
		  vvp_object_t nested;
		  cur->get_object(path[i], nested, 0);
		  cur = nested.peek<vvp_cobject>();
	    }
	    if (cur) {
		  vvp_vector4_t vec;
		  cur->get_vec4(path.back(), vec);
		  unsigned nbits = vec.size();
		  if (nbits > 64) nbits = 64;
		  for (unsigned bit = 0 ; bit < nbits ; bit += 1)
			if (vec.value(bit) == BIT4_1) bits |= (1ULL << bit);
	    }
      }

      Z3_sort sort = Z3_mk_bv_sort(b.ctx, width);
      Z3_ast val = Z3_mk_unsigned_int64(b.ctx, bits, sort);
      if (sflag) b.signed_vars.insert(val);
      return val;
}

/* Capture the raw text of the remainder of the current form: the
 * parser is positioned after the form's operator/header tokens, and
 * this consumes characters through the MATCHING close paren (which is
 * consumed but not included in the returned text). */
static string capture_balanced_form(IRParser& par)
{
      string text;
      int depth = 0;
      while (*par.p) {
	    char c = *par.p;
	    if (c == '(') depth++;
	    else if (c == ')') {
		  if (depth == 0) { par.p++; break; }
		  depth--;
	    }
	    text += c;
	    par.p++;
      }
      return text;
}

/* Substitute the standalone loop token `L` with "c:<i>" (token
 * boundaries only — L may not appear inside other tokens, but guard
 * anyway). */
static string subst_loop_token(const string& body, uint64_t i)
{
      string out;
      const char* p = body.c_str();
      auto is_delim = [](char c) {
	    return c == ' ' || c == '\t' || c == '\n' || c == '('
		|| c == ')' || c == '[' || c == ']' || c == ',' || c == 0;
      };
      char prev = ' ';
      while (*p) {
	    if (*p == 'L' && is_delim(prev) && is_delim(p[1])) {
		  out += "c:" + to_string(i);
		  prev = 'L';
		  p++;
		  continue;
	    }
	    prev = *p;
	    out += *p++;
      }
      return out;
}

/* Constant-fold an index sub-expression of a (delem ...) form:
 * "c:V" tokens and (add|sub|mul|div|mod a b) forms, uint64
 * two's-complement arithmetic (matching the elaboration-side
 * folding). Returns false when anything else appears. */
static bool eval_const_ir_impl(IRParser& par, uint64_t& out)
{
      par.skip_ws();
      if (par.peek() == '(') {
	    par.consume();
	    string op = par.read_token();
	    if (op == "ite") {
		  uint64_t c = 0, t = 0, f = 0;
		  if (!eval_const_ir_impl(par, c) || !eval_const_ir_impl(par, t)
		      || !eval_const_ir_impl(par, f)) return false;
		  par.skip_ws();
		  if (!par.expect(')')) return false;
		  out = c ? t : f;
		  return true;
	    }
	    uint64_t a = 0, b = 0;
	    if (!eval_const_ir_impl(par, a)) return false;
	    if (op == "not") {
		  par.skip_ws();
		  if (!par.expect(')')) return false;
		  out = !a;
		  return true;
	    }
	    if (!eval_const_ir_impl(par, b)) return false;
	    par.skip_ws();
	    if (!par.expect(')')) return false;
	    if (op == "add") out = a + b;
	    else if (op == "sub") out = a - b;
	    else if (op == "mul") out = a * b;
	    else if (op == "div") out = b ? a / b : 0;
	    else if (op == "mod") out = b ? a % b : 0;
	    else if (op == "lt") out = a < b;
	    else if (op == "le") out = a <= b;
	    else if (op == "gt") out = a > b;
	    else if (op == "ge") out = a >= b;
	    else if (op == "eq") out = a == b;
	    else if (op == "ne") out = a != b;
	    else if (op == "and") out = (a != 0) && (b != 0);
	    else if (op == "or") out = (a != 0) || (b != 0);
	    else return false;
	    return true;
      }
      string tok = par.read_token();
      if (tok.compare(0, 2, "c:") != 0) return false;
      out = (uint64_t)strtoull(tok.c_str() + 2, nullptr, 10);
      return true;
}

/* A failed speculative constant parse must not consume part of the next
 * expression. Dist weights and range endpoints share the same token stream;
 * leaving the cursor in the middle of a parenthesized nonconstant expression
 * can strand the outer parser on its closing `)' forever. */
static bool eval_const_ir(IRParser& par, uint64_t& out)
{
      const char* start = par.p;
      if (eval_const_ir_impl(par, out))
	    return true;
      par.p = start;
      return false;
}

// Get width from a Z3 bitvector AST
static unsigned bv_width(Z3_context ctx, Z3_ast a)
{
      Z3_sort sort = Z3_get_sort(ctx, a);
      if (Z3_get_sort_kind(ctx, sort) == Z3_BV_SORT)
	    return Z3_get_bv_sort_size(ctx, sort);
      return 32;
}

/* Phase 56: coerce a Z3 AST to Bool sort.  SV logical operators (&&, ||,
 * !) accept any-width vector operands and treat zero as false / non-zero
 * as true.  Our IR uses Bool-typed Z3 ops (Z3_mk_and / Z3_mk_or /
 * Z3_mk_not) so we have to bridge BitVec inputs by comparing to zero. */
static Z3_ast bv_to_bool(Z3_context ctx, Z3_ast a)
{
      Z3_sort sort = Z3_get_sort(ctx, a);
      if (Z3_get_sort_kind(ctx, sort) == Z3_BV_SORT) {
	    unsigned w = Z3_get_bv_sort_size(ctx, sort);
	    Z3_ast zero = Z3_mk_int(ctx, 0, Z3_mk_bv_sort(ctx, w));
	    /* (a != 0) is true when a is non-zero.  Use a named array (not a
	       compound literal) — older gcc treats `(Z3_ast[]){...}` in C++ as
	       a non-conforming GNU extension and rejects taking its address. */
	    Z3_ast args[2] = { a, zero };
	    return Z3_mk_distinct(ctx, 2, args);
      }
      return a;
}

/* Relational/logical expressions are one-bit integral values when they feed
 * an ordinary SystemVerilog expression. Z3 represents them as Bool, so a
 * mixed ternary such as cond ? 16'hffff : (nco < limit) must convert the
 * Boolean branch back to bit[0:0] before branch sizing. */
static Z3_ast bool_to_bv1(Z3_context ctx, Z3_ast a)
{
      Z3_sort sort = Z3_get_sort(ctx, a);
      if (Z3_get_sort_kind(ctx, sort) != Z3_BOOL_SORT) return a;
      Z3_sort bv1 = Z3_mk_bv_sort(ctx, 1);
      Z3_ast one = Z3_mk_unsigned_int64(ctx, 1, bv1);
      Z3_ast zero = Z3_mk_unsigned_int64(ctx, 0, bv1);
      return Z3_mk_ite(ctx, a, one, zero);
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
      if (tok.substr(0,2) == "m:") return parse_member(par, b, tok);
      if (tok.substr(0,2) == "r:") return parse_state_path(b, tok);
      if (tok.substr(0,2) == "c:") {
	    const char*s = tok.c_str() + 2;
	    char*end = nullptr;
	    uint64_t v = (uint64_t)strtoull(s, &end, 10);
	    unsigned width = 32;
	    bool sflag = false;
	    if (end && *end == ':') {
		  width = (unsigned)strtoul(end + 1, &end, 10);
		  if (width == 0) width = 32;
		  if (end && *end == ':' && end[1] == 's') sflag = true;
	    }
	    Z3_sort sort = Z3_mk_bv_sort(b.ctx, width);
	    Z3_ast val = Z3_mk_unsigned_int64(b.ctx, v, sort);
	    if (sflag) b.signed_vars.insert(val);
	    return val;
      }
      if (tok.substr(0,2) == "s:") {
	      // s:N:T — size of dynamic-array property N, darray type T.
	    return parse_size(b, tok);
      }
      if (tok.substr(0,2) == "e:") {
	    return parse_elem(par, b, tok);
      }
      return b.mk_true();
}

/* Evaluate an integral expression at the point randomize() is called.
 * IEEE 1800-2017 18.5.4 permits dist weights to be integral expressions,
 * including ordinary object properties. Build the expression with the same
 * width/signedness rules as a constraint, replace every property leaf with
 * its current object value, then ground-fold it. This is deliberately
 * transactional: a nonground/malformed expression restores the cursor so a
 * caller can recover without corrupting the surrounding branch parse. */
static bool eval_runtime_integral_ir(IRParser& par, Z3Builder& b,
				     uint64_t& out)
{
      const char* start = par.p;
      Z3Builder value_builder(b.ctx, b.defn, b.cobj);
      Z3_ast value = build_z3_atom(par, value_builder);
      if (par.p == start) {
	    par.p = start;
	    return false;
      }

      Z3_sort sort = Z3_get_sort(b.ctx, value);
      if (Z3_get_sort_kind(b.ctx, sort) == Z3_BOOL_SORT)
	    value = bool_to_bv1(b.ctx, value);

      vector<Z3_ast> from;
      vector<Z3_ast> to;
      from.reserve(value_builder.prop_vars.size()
		   + value_builder.member_vars.size());
      to.reserve(value_builder.prop_vars.size()
		 + value_builder.member_vars.size());
      for (const auto& pv : value_builder.prop_vars) {
	    if (!b.cobj) {
		  par.p = start;
		  return false;
	    }
	    unsigned width = pv.width ? pv.width : 32;
	    from.push_back(pv.var);
	    to.push_back(Z3_mk_unsigned_int64(
		  b.ctx, cobj_prop_bits(b.cobj, pv.idx),
		  Z3_mk_bv_sort(b.ctx, width)));
      }
      for (const auto& mv : value_builder.member_vars) {
	    if (!b.cobj) {
		  par.p = start;
		  return false;
	    }
	    from.push_back(mv.var);
	    to.push_back(Z3_mk_unsigned_int64(
		  b.ctx, cobj_member_bits(b.cobj, mv.outer, mv.member),
		  Z3_mk_bv_sort(b.ctx, mv.width)));
      }
      if (!from.empty())
	    value = Z3_substitute(b.ctx, value, (unsigned)from.size(),
				  from.data(), to.data());
      value = Z3_simplify(b.ctx, value);
      if (z3_ground_uint64(b.ctx, value, out))
	    return true;

      par.p = start;
      return false;
}

/* Parse a "P:W[:s]" header token into property index / width / signed. */
static void parse_pws_header(const string& tok, unsigned& pidx,
			     unsigned& wid, bool& sflag)
{
      const char* s = tok.c_str();
      pidx = (unsigned)atoi(s);
      while (*s && *s != ':') ++s;
      wid = 32;
      if (*s == ':') { wid = (unsigned)atoi(s + 1); ++s; }
      while (*s && *s != ':') ++s;
      sflag = (*s == ':' && s[1] == 's');
      if (wid == 0) wid = 32;
}

/* A fresh unconstrained bitvector: fallback for element references
 * the expansion cannot resolve (non-constant index after loop-token
 * substitution, or an index outside the solved size). Nothing is
 * written back for these, so they only keep the AST well-sorted. */
static Z3_ast mk_free_bv(Z3Builder& b, unsigned wid)
{
      static unsigned counter = 0;
      char name[32];
      snprintf(name, sizeof(name), "dynfree%u", counter++);
      return Z3_mk_const(b.ctx, Z3_mk_string_symbol(b.ctx, name),
			 Z3_mk_bv_sort(b.ctx, wid));
}

static Z3_ast build_z3_expr(IRParser& par, Z3Builder& b)
{
      par.skip_ws();
      string op = par.read_token();
      if (op.empty()) return b.mk_true();

	/* Dynamic-array foreach template (IEEE 1800-2017 18.5.8.2).
	 * Size pass: capture the body and contribute `true` (the size
	 * variables elsewhere in the IR still participate). Element
	 * pass: expand the body once per element with the loop token
	 * bound to each index and conjoin the instances. */
      if (op == "dynforeach") {
	    string hdr = par.read_token();
	    unsigned pidx, ewid; bool esig;
	    parse_pws_header(hdr, pidx, ewid, esig);
	    string body = capture_balanced_form(par);
	    if (!b.dyn_sizes) {
		  bool seen = false;
		  for (const auto& d : b.dyn_foreach)
			if (d.pidx == pidx && d.body == body) { seen = true; break; }
		  if (!seen) {
			Z3Builder::DynForeach rec;
			rec.pidx = pidx; rec.ewid = ewid;
			rec.esigned = esig; rec.body = body;
			b.dyn_foreach.push_back(rec);
		  }
		  return b.mk_true();
	    }
	    uint64_t count = 0;
	    {
		  auto it = b.dyn_sizes->find(pidx);
		  if (it != b.dyn_sizes->end()) count = it->second;
	    }
	    if (z3_dyndbg())
		  fprintf(stderr, "[z3dyn] dynforeach expand prop=%u count=%llu "
			  "ewid=%u body=<%s>\n", pidx,
			  (unsigned long long)count, ewid, body.c_str());
	    Z3_ast conj = b.mk_true();
	    for (uint64_t i = 0 ; i < count ; i += 1) {
		  string inst_text = subst_loop_token(body, i);
		  if (z3_dyndbg())
			fprintf(stderr, "[z3dyn]   inst i=%llu text=<%s>\n",
				(unsigned long long)i, inst_text.c_str());
		  IRParser sub(inst_text);
		  Z3_ast inst = bv_to_bool(b.ctx, build_z3_atom(sub, b));
		  Z3_ast args[2] = { conj, inst };
		  conj = Z3_mk_and(b.ctx, 2, args);
	    }
	    return conj;
      }

	/* Element reference within an expanded dynforeach body:
	 * (delem P:W[:s] <const-index-ir>) -> element variable. */
      if (op == "delem") {
	    string hdr = par.read_token();
	    unsigned pidx, ewid; bool esig;
	    parse_pws_header(hdr, pidx, ewid, esig);
	    uint64_t idx64 = 0;
	    bool ok = eval_const_ir(par, idx64);
	    par.skip_ws(); par.expect(')');
	    uint64_t count = 0;
	    if (b.dyn_sizes) {
		  auto it = b.dyn_sizes->find(pidx);
		  if (it != b.dyn_sizes->end()) count = it->second;
	    }
	    if (!ok || idx64 >= count) {
		  static bool warned = false;
		  if (!warned) {
			fprintf(stderr, "Warning: dynamic foreach element"
				" index %s (prop %u); constraint on that"
				" element is unenforced (further similar"
				" warnings suppressed)\n",
				ok ? "out of the solved array bounds"
				   : "is not constant after expansion",
				pidx);
			warned = true;
		  }
		  return mk_free_bv(b, ewid);
	    }
	    Z3_ast var = b.get_elem_var(pidx, ewid, (unsigned)idx64);
	    if (esig) b.signed_vars.insert(var);
	    return var;
      }

	/* Variable-ordering directive: (order (vars p:../m:../e:../s:..)
	 * (vars p:../m:../e:../s:..)). Registers properties, struct members,
	 * selected elements, or dynamic-container sizes (so they become solver
	 * variables even if otherwise unconstrained) and records every
	 * before-var x after-var pair. Contributes `true` — ordering
	 * affects distribution, not satisfiability (18.5.10). */
      if (op == "order") {
	    std::vector<Z3Builder::OrderRef> groups[2];
	    for (int g = 0 ; g < 2 ; g += 1) {
		  par.skip_ws();
		  if (!par.expect('(')) break;
		  string kw = par.read_token(); // "vars"
		  (void)kw;
		  for (;;) {
			par.skip_ws();
			if (par.peek() == ')') { par.consume(); break; }
			string tok = par.read_token();
			if (tok.empty()) break;
			if (tok.compare(0, 2, "p:") == 0) {
			      parse_prop(par, b, tok);
			      Z3Builder::OrderRef ref;
			      ref.kind = Z3Builder::OrderRef::PROP;
			      ref.idx = (unsigned)atoi(tok.c_str() + 2);
			      ref.elem = 0;
			      groups[g].push_back(ref);
			} else if (tok.compare(0, 2, "m:") == 0) {
			      parse_member(par, b, tok);
			      const char*s = tok.c_str() + 2;
			      Z3Builder::OrderRef ref;
			      ref.kind = Z3Builder::OrderRef::MEMBER;
			      ref.idx = (unsigned)atoi(s);
			      while (*s && *s != ':') ++s;
			      ref.elem = (*s == ':')
				    ? (unsigned)atoi(s + 1) : 0;
			      groups[g].push_back(ref);
			} else if (tok.compare(0, 2, "e:") == 0) {
			      parse_elem(par, b, tok);
			      const char*s = tok.c_str() + 2;
			      Z3Builder::OrderRef ref;
			      ref.kind = Z3Builder::OrderRef::ELEM;
			      ref.idx = (unsigned)atoi(s);
			      while (*s && *s != ':') ++s;
			      if (*s == ':') ++s;
			      while (*s && *s != ':') ++s;
			      ref.elem = (*s == ':')
				    ? (unsigned)atoi(s + 1) : 0;
			      groups[g].push_back(ref);
			} else if (tok.compare(0, 2, "s:") == 0) {
			      Z3Builder::OrderRef ref;
			      ref.kind = Z3Builder::OrderRef::SIZE;
			      parse_size(b, tok, &ref.idx);
			      ref.elem = 0;
			      groups[g].push_back(ref);
			}
		  }
	    }
	    par.skip_ws(); par.expect(')');
	    for (const Z3Builder::OrderRef&a : groups[0])
		  for (const Z3Builder::OrderRef&c : groups[1])
			b.order_pairs.push_back(std::make_pair(a, c));
	    return b.mk_true();
      }

      /* Packed selection forms used by scope-randomization constraints.
       * The select index may itself be randomized. Fixed part-select bounds
       * have already had caller value slots substituted with constants. */
      if (op == "bit") {
	    Z3_ast base = build_z3_atom(par, b);
	    Z3_ast idx = build_z3_atom(par, b);
	    par.skip_ws(); par.expect(')');
	    unsigned bw = bv_width(b.ctx, base);
	      // A packed bit select outside the vector's declared domain does
	      // not wrap modulo the vector width.  In the two-state constraint
	      // model its unknown/out-of-range result is 0.  Previously the
	      // shift operand was truncated to `bw` bits, so a constraint such
	      // as `valid_mask[index] == 1` accepted arbitrary 32-bit indices
	      // whose low nibble happened to name a set bit.
	    bool idx_signed = b.is_signed(idx);
	    unsigned iw = bv_width(b.ctx, idx);
	    unsigned limit_w = 1;
	    uint64_t limit_cap = 2;
	    while (limit_cap <= bw && limit_w < 64) {
		  ++limit_w;
		  limit_cap <<= 1;
	    }
	    unsigned cmpw = std::max(iw, limit_w);
	    Z3_ast cmp_idx = b.coerce(idx, cmpw);
	    Z3_sort cmps = Z3_mk_bv_sort(b.ctx, cmpw);
	    Z3_ast limit = Z3_mk_unsigned_int64(b.ctx, bw, cmps);
	    Z3_ast valid = Z3_mk_bvult(b.ctx, cmp_idx, limit);
	    if (idx_signed) {
		  Z3_ast signed_bounds[2] = {
			Z3_mk_bvsge(b.ctx, cmp_idx,
			      Z3_mk_unsigned_int64(b.ctx, 0, cmps)),
			Z3_mk_bvslt(b.ctx, cmp_idx, limit)
		  };
		  valid = Z3_mk_and(b.ctx, 2, signed_bounds);
	    }
	    Z3_ast shift_idx = b.coerce(idx, bw);
	    Z3_ast shifted = Z3_mk_bvlshr(b.ctx, base, shift_idx);
	    Z3_ast selected = Z3_mk_extract(b.ctx, 0, 0, shifted);
	    Z3_ast zero = Z3_mk_unsigned_int64(b.ctx, 0,
				       Z3_mk_bv_sort(b.ctx, 1));
	    return Z3_mk_ite(b.ctx, valid, selected, zero);
      }

      if (op == "part") {
	    Z3_ast base = build_z3_atom(par, b);
	    uint64_t hi = 0, lo = 0;
	    bool ok = eval_const_ir(par, hi) && eval_const_ir(par, lo);
	    par.skip_ws(); par.expect(')');
	    unsigned bw = bv_width(b.ctx, base);
	    if (!ok || hi < lo || hi >= bw) return mk_free_bv(b, 1);
	    return Z3_mk_extract(b.ctx, (unsigned)hi, (unsigned)lo, base);
      }

      if (op == "concat") {
	    vector<Z3_ast> parts;
	    par.skip_ws();
	    while (par.peek() != ')' && !par.at_end()) {
		  parts.push_back(build_z3_atom(par, b));
		  par.skip_ws();
	    }
	    par.expect(')');
	    if (parts.empty())
		  return Z3_mk_unsigned_int64(b.ctx, 0,
					      Z3_mk_bv_sort(b.ctx, 1));
	    Z3_ast out = parts[0];
	    for (size_t i = 1 ; i < parts.size() ; i += 1)
		  out = Z3_mk_concat(b.ctx, out, parts[i]);
	    return out;
      }

      /* A method/operator with an explicitly self-determined result width
	 * (notably an array reduction) must truncate before a surrounding
	 * comparison supplies a wider context. Ordinary arithmetic deliberately
	 * delays that truncation; this node marks the semantic boundary. */
      if (op.compare(0, 6, "trunc:") == 0) {
	    const char*spec = op.c_str() + 6;
	    char*end = 0;
	    unsigned width = (unsigned)strtoul(spec, &end, 10);
	    bool is_signed = end && *end == ':' && end[1] == 's';
	    Z3_ast arg = build_z3_atom(par, b);
	    par.skip_ws(); par.expect(')');
	    if (width == 0) return mk_free_bv(b, 1);
	      /* A relational/logical with expression is an integral 1-bit
	       * SystemVerilog value but is represented internally by a Z3 Bool.
	       * Re-enter the bitvector domain at this explicit width boundary. */
	    arg = bool_to_bv1(b.ctx, arg);
	    Z3_ast out = b.coerce(arg, width);
	    b.set_sv(out, width);
	    if (is_signed) b.signed_vars.insert(out);
	    return out;
      }

      if (op == "countones") {
	    Z3_ast arg = build_z3_atom(par, b);
	    par.skip_ws(); par.expect(')');
	    unsigned aw = bv_width(b.ctx, arg);
	    Z3_sort out_sort = Z3_mk_bv_sort(b.ctx, 32);
	    Z3_ast sum = Z3_mk_unsigned_int64(b.ctx, 0, out_sort);
	    for (unsigned i = 0 ; i < aw ; i += 1) {
		  Z3_ast bit = Z3_mk_extract(b.ctx, i, i, arg);
		  Z3_ast wide = Z3_mk_zero_ext(b.ctx, 31, bit);
		  sum = Z3_mk_bvadd(b.ctx, sum, wide);
	    }
	    b.set_sv(sum, 32);
	    return sum;
      }

      if (op == "onehot" || op == "onehot0") {
	    Z3_ast arg = build_z3_atom(par, b);
	    par.skip_ws(); par.expect(')');
	    unsigned aw = bv_width(b.ctx, arg);
	    Z3_ast zero = Z3_mk_unsigned_int64(b.ctx, 0,
					     Z3_mk_bv_sort(b.ctx, aw));
	    Z3_ast one = Z3_mk_unsigned_int64(b.ctx, 1,
					    Z3_mk_bv_sort(b.ctx, aw));
	    Z3_ast minus_one = Z3_mk_bvsub(b.ctx, arg, one);
	    Z3_ast masked = Z3_mk_bvand(b.ctx, arg, minus_one);
	    Z3_ast at_most_one = Z3_mk_eq(b.ctx, masked, zero);
	    if (op == "onehot0") return at_most_one;
	    Z3_ast nonzero = Z3_mk_not(b.ctx, Z3_mk_eq(b.ctx, arg, zero));
	    Z3_ast both[2] = { at_most_one, nonzero };
	    return Z3_mk_and(b.ctx, 2, both);
      }

      if (op == "ite") {
	    Z3_ast cond = bv_to_bool(b.ctx, build_z3_atom(par, b));
	    Z3_ast yes = build_z3_atom(par, b);
	    Z3_ast no = build_z3_atom(par, b);
	    par.skip_ws(); par.expect(')');
	    Z3_sort_kind yes_kind = Z3_get_sort_kind(
		  b.ctx, Z3_get_sort(b.ctx, yes));
	    Z3_sort_kind no_kind = Z3_get_sort_kind(
		  b.ctx, Z3_get_sort(b.ctx, no));
	    if (yes_kind == Z3_BOOL_SORT && no_kind == Z3_BOOL_SORT)
		  return Z3_mk_ite(b.ctx, cond, yes, no);
	    yes = bool_to_bv1(b.ctx, yes);
	    no = bool_to_bv1(b.ctx, no);
	    unsigned sw = b.sv_of(yes);
	    if (b.sv_of(no) > sw) sw = b.sv_of(no);
	    yes = b.coerce(yes, sw);
	    no = b.coerce(no, sw);
	    Z3_ast out = Z3_mk_ite(b.ctx, cond, yes, no);
	    b.set_sv(out, sw);
	    return out;
      }

      if (op == "and" || op == "or") {
	    Z3_ast left  = bv_to_bool(b.ctx, build_z3_atom(par, b));
	    Z3_ast right = bv_to_bool(b.ctx, build_z3_atom(par, b));
	    par.skip_ws(); par.expect(')');
	    if (op == "and") {
		  Z3_ast args[2] = {left, right};
		  return Z3_mk_and(b.ctx, 2, args);
	    } else {
		  Z3_ast args[2] = {left, right};
		  return Z3_mk_or(b.ctx, 2, args);
	    }
      }

      /* Constraint implication A -> B (IEEE 1800-2017 18.5.6) and
       * equivalence A <-> B. Both operands take their boolean views. */
      if (op == "impl" || op == "iff") {
	    Z3_ast left  = bv_to_bool(b.ctx, build_z3_atom(par, b));
	    if (op == "impl") b.soft_guards.push_back(left);
	    Z3_ast right = bv_to_bool(b.ctx, build_z3_atom(par, b));
	    if (op == "impl") b.soft_guards.pop_back();
	    par.skip_ws(); par.expect(')');
	    if (op == "impl")
		  return Z3_mk_implies(b.ctx, left, right);
	    return Z3_mk_iff(b.ctx, left, right);
      }

      /* Bitvector arithmetic (IEEE 1800-2017 11.6.1, Table 11-21).
       *
       * The SELF-DETERMINED width of `i op j' is max(L(i), L(j)), and
       * that is what the result is eventually truncated to -- but only
       * once the CONTEXT width is known, which happens at the
       * comparison this feeds. So build at full precision here (an
       * 8-bit add in a 9-bit vector, a product in lw+rw bits) and
       * record the self-determined width for the comparison to use.
       * Evaluating at the operand width instead, which is what this
       * did, wrapped `a + b == 300' mod 256 and reported UNSAT. */
      if (op == "pow") {
	    Z3_ast left = build_z3_atom(par, b);
	    Z3_ast right = build_z3_atom(par, b);
	    par.skip_ws(); par.expect(')');

	    unsigned sw = b.sv_of(left);
	    if (sw == 0) sw = 32;
	    left = b.coerce(left, sw);
	    Z3_sort sort = Z3_mk_bv_sort(b.ctx, sw);
	    Z3_ast result = Z3_mk_unsigned_int64(b.ctx, 1, sort);

	      /* Most constraint exponents are state constants (array widths,
	         register widths). Use exponentiation by squaring when the AST
	         is ground; retain a bit-select ITE form for a solver exponent. */
	    uint64_t exponent = 0;
	    Z3_ast simplified = Z3_simplify(b.ctx, right);
	    if (z3_ground_uint64(b.ctx, simplified, exponent)) {
		  Z3_ast base = left;
		  while (exponent) {
			if (exponent & 1)
			      result = Z3_mk_bvmul(b.ctx, result, base);
			exponent >>= 1;
			if (exponent)
			      base = Z3_mk_bvmul(b.ctx, base, base);
		  }
	    } else {
		  unsigned rw = bv_width(b.ctx, right);
		  Z3_ast base = left;
		  for (unsigned bit = 0 ; bit < rw ; bit += 1) {
			Z3_ast use = Z3_mk_extract(b.ctx, bit, bit, right);
			Z3_ast one = Z3_mk_unsigned_int64(
			      b.ctx, 1, Z3_mk_bv_sort(b.ctx, 1));
			Z3_ast product = Z3_mk_bvmul(b.ctx, result, base);
			result = Z3_mk_ite(b.ctx, Z3_mk_eq(b.ctx, use, one),
					   product, result);
			base = Z3_mk_bvmul(b.ctx, base, base);
		  }
	    }
	    b.set_sv(result, sw);
	    return result;
      }

      if (op == "add" || op == "sub" || op == "mul"
	  || op == "div" || op == "mod") {
	    Z3_ast left  = build_z3_atom(par, b);
	    Z3_ast right = build_z3_atom(par, b);
	    par.skip_ws(); par.expect(')');

	    unsigned sv = b.sv_of(left);
	    if (b.sv_of(right) > sv) sv = b.sv_of(right);

	    unsigned lw = bv_width(b.ctx, left);
	    unsigned rw = bv_width(b.ctx, right);
	    unsigned work = lw > rw ? lw : rw;
	      /* Headroom so the operation itself cannot lose bits: one
		 carry for add/sub, the full lw+rw for a product. */
	    if (op == "add" || op == "sub") work += 1;
	    else if (op == "mul") work = lw + rw;
	    if (work < sv) work = sv;

	    left  = b.coerce(left,  work);
	    right = b.coerce(right, work);

	    Z3_ast r;
	    if (op == "add")      r = Z3_mk_bvadd(b.ctx, left, right);
	    else if (op == "sub") r = Z3_mk_bvsub(b.ctx, left, right);
	    else if (op == "mul") r = Z3_mk_bvmul(b.ctx, left, right);
	    else if (op == "div") r = Z3_mk_bvudiv(b.ctx, left, right);
	    else                  r = Z3_mk_bvurem(b.ctx, left, right);
	    b.set_sv(r, sv);
	    return r;
      }

      if (op == "band" || op == "bor" || op == "bxor") {
	    Z3_ast left = build_z3_atom(par, b);
	    Z3_ast right = build_z3_atom(par, b);
	    par.skip_ws(); par.expect(')');
	    unsigned sw = b.sv_of(left);
	    if (b.sv_of(right) > sw) sw = b.sv_of(right);
	    left = b.coerce(left, sw);
	    right = b.coerce(right, sw);
	    Z3_ast out = op == "band" ? Z3_mk_bvand(b.ctx, left, right)
		  : op == "bor" ? Z3_mk_bvor(b.ctx, left, right)
		  : Z3_mk_bvxor(b.ctx, left, right);
	    b.set_sv(out, sw);
	    return out;
      }

      if (op == "shl" || op == "lshr" || op == "ashr") {
	    Z3_ast left = build_z3_atom(par, b);
	    Z3_ast right = build_z3_atom(par, b);
	    par.skip_ws(); par.expect(')');
	    unsigned lw = b.sv_of(left);
	    left = b.coerce(left, lw);
	    right = b.coerce(right, lw);
	    Z3_ast out = op == "shl" ? Z3_mk_bvshl(b.ctx, left, right)
		  : op == "lshr" ? Z3_mk_bvlshr(b.ctx, left, right)
		  : Z3_mk_bvashr(b.ctx, left, right);
	    b.set_sv(out, lw);
	    return out;
      }

      if (op == "bnot") {
	    Z3_ast arg = build_z3_atom(par, b);
	    par.skip_ws(); par.expect(')');
	    Z3_ast out = Z3_mk_bvnot(b.ctx, arg);
	    b.set_sv(out, b.sv_of(arg));
	    return out;
      }

      if (op == "redand" || op == "redor" || op == "redxor") {
	    Z3_ast arg = build_z3_atom(par, b);
	    par.skip_ws(); par.expect(')');
	    unsigned aw = bv_width(b.ctx, arg);
	    Z3_ast bit = Z3_mk_extract(b.ctx, 0, 0, arg);
	    for (unsigned i = 1 ; i < aw ; i += 1) {
		  Z3_ast next = Z3_mk_extract(b.ctx, i, i, arg);
		  bit = op == "redand" ? Z3_mk_bvand(b.ctx, bit, next)
			: op == "redor" ? Z3_mk_bvor(b.ctx, bit, next)
			: Z3_mk_bvxor(b.ctx, bit, next);
	    }
	    return bit;
      }

      if (op == "not") {
	    /* SV `!x` returns a 1-bit value (1 if x==0 else 0).  Our IR
	     * generator uses `(not x)` for this; downstream consumers
	     * (e.g. `(eq lhs (not c:1))`) expect a BitVec result, not a
	     * Bool.  Implement as ITE over a Bool view of the operand. */
	    Z3_ast raw = build_z3_atom(par, b);
	    par.skip_ws(); par.expect(')');
	    Z3_ast cond = bv_to_bool(b.ctx, raw);
	    Z3_sort bv1 = Z3_mk_bv_sort(b.ctx, 1);
	    Z3_ast one  = Z3_mk_unsigned_int64(b.ctx, 1, bv1);
	    Z3_ast zero = Z3_mk_unsigned_int64(b.ctx, 0, bv1);
	    /* If x is true (non-zero), !x = 0; if false, !x = 1. */
	    return Z3_mk_ite(b.ctx, cond, zero, one);
      }

      // Binary comparison: lt le gt ge eq ne
      if (op == "lt" || op == "le" || op == "gt" || op == "ge"
	  || op == "eq" || op == "ne") {
	    Z3_ast left  = build_z3_atom(par, b);
	    Z3_ast right = build_z3_atom(par, b);
	    par.skip_ws(); par.expect(')');

	      // Relational operands are unsigned when either operand is
	      // unsigned (IEEE 1800-2017 11.8.1). Bare decimal literals are
	      // signed, but that must not make `bit [7:0] u; u < 5' compare
	      // u as an 8-bit signed value after extension. Both operands
	      // must be signed before selecting the signed BV predicate.
	    bool use_signed = b.is_signed(left) && b.is_signed(right);

	      // This is the CONTEXT (Table 11-21): a comparison sizes
	      // both of its operands to max(L(i), L(j)) of their
	      // SELF-DETERMINED widths, and that is where an arithmetic
	      // subexpression built at full precision above finally
	      // truncates. `a + b == 300' therefore evaluates the add at
	      // 32 bits (the literal's width) and matches; `c == a + b'
	      // with an 8-bit c evaluates it at 8 and wraps, which is
	      // equally what the LRM says.
	    unsigned ctx_w = b.sv_of(left);
	    if (b.sv_of(right) > ctx_w) ctx_w = b.sv_of(right);
	    left  = b.coerce(left,  ctx_w);
	    right = b.coerce(right, ctx_w);

	    if (op == "lt") return use_signed ? Z3_mk_bvslt(b.ctx, left, right)
					      : Z3_mk_bvult(b.ctx, left, right);
	    if (op == "le") return use_signed ? Z3_mk_bvsle(b.ctx, left, right)
					      : Z3_mk_bvule(b.ctx, left, right);
	    if (op == "gt") return use_signed ? Z3_mk_bvsgt(b.ctx, left, right)
					      : Z3_mk_bvugt(b.ctx, left, right);
	    if (op == "ge") return use_signed ? Z3_mk_bvsge(b.ctx, left, right)
					      : Z3_mk_bvuge(b.ctx, left, right);
	    if (op == "eq") return Z3_mk_eq(b.ctx, left, right);
	    // ne
	    return Z3_mk_not(b.ctx, Z3_mk_eq(b.ctx, left, right));
      }

      if (op == "inside") {
	    // Format: (inside p:N:W [lo,hi] val ...) where lo/hi/val are
	    // atoms: c:V literals or parenthesized expressions.
	    Z3_ast subject = build_z3_atom(par, b);
	    unsigned subj_sv = b.sv_of(subject);
	      // A signed subject selects signed range semantics
	      // (IEEE 1800-2017 11.4.13, 11.8.1).
	    bool subj_signed = b.is_signed(subject);

	      // `inside' compares like `==' (11.4.13), so each member is
	      // sized WITH the subject to the wider of the two -- the
	      // subject is not the ceiling. Truncating members down to the
	      // subject's width, which is what this did, silently rewrote
	      // `x inside {[0:300]}' on an 8-bit x into `x inside {[0:44]}'.
	    auto member_width = [&](Z3_ast a) -> unsigned {
		  unsigned mw = b.sv_of(a);
		  return mw > subj_sv ? mw : subj_sv;
	    };
	    auto match_width = [&](Z3_ast a) -> Z3_ast {
		  return b.coerce(a, member_width(a));
	    };
	    auto subj_at = [&](Z3_ast member) -> Z3_ast {
		  return b.coerce(subject, bv_width(b.ctx, member));
	    };
	    auto range_ge = [&](Z3_ast x, Z3_ast lo) -> Z3_ast {
		  return subj_signed ? Z3_mk_bvsge(b.ctx, x, lo)
				     : Z3_mk_bvuge(b.ctx, x, lo);
	    };
	    auto range_le = [&](Z3_ast x, Z3_ast hi) -> Z3_ast {
		  return subj_signed ? Z3_mk_bvsle(b.ctx, x, hi)
				     : Z3_mk_bvule(b.ctx, x, hi);
	    };

	    vector<Z3_ast> clauses;
	    par.skip_ws();
	    while (par.peek() != ')' && !par.at_end()) {
		  if (par.peek() == '[') {
			par.consume(); // '['
			par.skip_ws();
			bool lo_open = par.peek() == '*';
			Z3_ast lo_raw = 0;
			if (lo_open) par.consume();
			else lo_raw = build_z3_atom(par, b);
			par.expect(',');
			par.skip_ws();
			bool hi_open = par.peek() == '*';
			Z3_ast hi_raw = 0;
			if (hi_open) par.consume();
			else hi_raw = build_z3_atom(par, b);
			par.expect(']');
			  // One width for the whole range test: the widest
			  // of the subject and every present bound. `*' is the
			  // open `$' endpoint from an inside/dist range.
			unsigned rw = subj_sv;
			if (lo_raw && member_width(lo_raw) > rw) rw = member_width(lo_raw);
			if (hi_raw && member_width(hi_raw) > rw) rw = member_width(hi_raw);
			Z3_ast sx = b.coerce(subject, rw);
			Z3_ast c1 = lo_raw
			      ? range_ge(sx, b.coerce(lo_raw, rw)) : 0;
			Z3_ast c2 = hi_raw
			      ? range_le(sx, b.coerce(hi_raw, rw)) : 0;
			if (c1 && c2) {
			      Z3_ast both[2] = {c1, c2};
			      clauses.push_back(Z3_mk_and(b.ctx, 2, both));
			} else if (c1) {
			      clauses.push_back(c1);
			} else if (c2) {
			      clauses.push_back(c2);
			} else {
			      clauses.push_back(b.mk_true());
			}
		  } else if (par.peek() == '(') {
			Z3_ast v = match_width(build_z3_atom(par, b));
			clauses.push_back(Z3_mk_eq(b.ctx, subj_at(v), v));
		  } else {
			// Single value token
			string tok = par.read_token();
			if (tok.substr(0,2) == "c:") {
			      const char*cs = tok.c_str() + 2;
			      char*ce = nullptr;
			      uint64_t v = strtoull(cs, &ce, 10);
			      unsigned cw = 32;
			      bool csign = false;
			      if (ce && *ce == ':') {
				    cw = (unsigned)strtoul(ce + 1, &ce, 10);
				    if (cw == 0) cw = 32;
				    csign = ce && *ce == ':' && ce[1] == 's';
			      }
			      Z3_ast cv = Z3_mk_unsigned_int64(b.ctx, v,
						      Z3_mk_bv_sort(b.ctx, cw));
			      if (csign) b.signed_vars.insert(cv);
			      unsigned mw = member_width(cv);
			      clauses.push_back(Z3_mk_eq(b.ctx,
					    b.coerce(subject, mw),
					    b.coerce(cv, mw)));
			} else if (tok == "qempty") {
			      clauses.push_back(Z3_mk_false(b.ctx));
			} else if (tok.substr(0,2) == "q:") {
			      // Queue/darray property container: expand the
			      // membership set from the container's contents
			      // at solve time. An empty (or unallocated)
			      // container contributes an unsatisfiable
			      // clause: `x inside {empty}` has no legal
			      // values, so randomize() must fail.
			      unsigned qpidx, qewid; bool qesig;
			      parse_pws_header(tok.substr(2), qpidx, qewid, qesig);
			      if (qewid > 64) qewid = 64;
			      uint64_t qcount = b.cobj
				    ? cobj_darray_size(b.cobj, qpidx) : 0;
			      if (qcount == 0) {
				    clauses.push_back(Z3_mk_false(b.ctx));
			      } else for (uint64_t qi = 0; qi < qcount; qi += 1) {
				    uint64_t bits =
					  cobj_elem_bits(b.cobj, qpidx, (unsigned)qi);
				    if (qewid < 64)
					  bits &= (1ULL << qewid) - 1;
				    if (qesig && qewid < 64
					&& ((bits >> (qewid - 1)) & 1))
					  bits |= ~((1ULL << qewid) - 1);
				      /* Build the member at its OWN element
					 width and size it with the subject,
					 like any other `inside' member.
					 Masking it down to the subject's
					 width instead made a value that
					 cannot fit -- 300 against an 8-bit
					 subject -- match at 44. */
				    Z3_ast cv = Z3_mk_unsigned_int64(b.ctx, bits,
					    Z3_mk_bv_sort(b.ctx, qewid));
				    if (qesig) b.signed_vars.insert(cv);
				    unsigned mw = member_width(cv);
				    clauses.push_back(Z3_mk_eq(b.ctx,
					    b.coerce(subject, mw),
					    b.coerce(cv, mw)));
			      }
			} else if (tok.empty()) {
			      // Unrecognized input: consume one char so the
			      // scan always makes forward progress (a stuck
			      // parser here previously hung the simulation).
			      if (!par.at_end()) par.consume();
			}
		  }
		  par.skip_ws();
	    }
	    par.expect(')');

	    if (clauses.empty()) return b.mk_true();
	    if (clauses.size() == 1) return clauses[0];
	    return Z3_mk_or(b.ctx, (unsigned)clauses.size(), clauses.data());
      }

      if (op == "soft") {
	    // I4 (Phase 62c): soft constraint.  Build the inner expression
	    // as a Z3 boolean and queue it as a soft assert.
	    //
	    // Default weight 256: Z3's optimize check is multi-objective
	    // lex-ordered.  Our diversity bvxor minimize objectives produce
	    // costs in 0..2^width-1 (typically 0..255 for 8-bit props).  A
	    // soft default weight that's 256 ensures the soft preference
	    // dominates the bvxor diversity cost when both are feasible
	    // — soft constraints get satisfied unless a hard conflict.
	    // Hard constraints still take priority (soft asserts are
	    // optional by definition).
	    std::set<Z3Builder::VarRef> refs;
	    std::set<Z3Builder::VarRef>* saved = b.collect_refs;
	    b.collect_refs = &refs;
	    Z3_ast inner = bv_to_bool(b.ctx, build_z3_atom(par, b));
	    b.collect_refs = saved;
	    par.skip_ws();
	    par.expect(')');
	    Z3Builder::SoftAssert sa = {
		  b.guard_soft_assert(inner), 256, true /* from_soft_kw */, refs
	    };
	    b.pending_soft.push_back(sa);
	    return b.mk_true();
      }

      if (op == "disable-soft") {
	    // M3B-3: `disable soft <var>;` — record the property index(es) in
	    // the operand so any soft constraint referencing them is dropped
	    // before the pending soft asserts are applied. The operand is a
	    // plain variable reference (or a small expression over one); we
	    // collect every property it mentions.
	    std::set<Z3Builder::VarRef> refs;
	    std::set<Z3Builder::VarRef>* saved = b.collect_refs;
	    bool saved_refs_only = b.collect_refs_only;
	    b.collect_refs = &refs;
	    b.collect_refs_only = true;
	    (void) build_z3_atom(par, b);
	    b.collect_refs_only = saved_refs_only;
	    b.collect_refs = saved;
	    par.skip_ws();
	    par.expect(')');
	    b.disabled_soft_refs.insert(refs.begin(), refs.end());
	    return b.mk_true();
      }

      if (op == "dist") {
	    // C7 (Phase 62b): weighted distribution.
	    // Format: (dist <expr> (b W <range>) ...)
	    // - Hard constraint: <expr> ∈ union of all branches.
	    // - Soft preference: per branch, Z3_optimize_assert_soft of
	    //   `(<expr> matches branch)` with weight W, so the optimizer
	    //   prefers higher-weight branches when feasible.
	    Z3_ast subject = build_z3_atom(par, b);
	    unsigned sw = b.sv_of(subject);
	    bool subject_signed = b.is_signed(subject);
	      // A dist branch value is an unsized literal: 32 bits, or 64
	      // when it needs them (11.6.1). Building it at the SUBJECT's
	      // width, which is what this did, truncated it -- `x dist
	      // {[0:300] := 1}' on an 8-bit x became `[0:44]'.
	    auto lit_at = [&](uint64_t v) -> unsigned {
		  unsigned vw = (v >> 32) ? 64u : 32u;
		  return vw > sw ? vw : sw;
	    };

	    vector<Z3_ast> hard_clauses;
	      // RANDOM-DIST fix #2: structural record of this dist's branches,
	      // parallel to hard_clauses/pending_soft above, so the solver can
	      // later draw a value proportional to its weight instead of just
	      // preferring the heaviest branch (see Z3Builder::DistSpec).
	    Z3Builder::DistSpec dspec;
	    dspec.subject = subject;
	    dspec.width = sw;
	    bool saw_branch = false;
	    par.skip_ws();
	    while (par.peek() != ')' && !par.at_end()) {
		  // Each branch is `(b W <range>)`.
		  if (par.peek() != '(') break;
		  par.consume(); // '('
		  string br_op = par.read_token();
		  if (br_op != "b") {
			// Unknown branch shape; skip to matching ')'.
			int depth = 1;
			while (!par.at_end() && depth > 0) {
			      char c = par.consume();
			      if (c == '(') ++depth;
			      else if (c == ')') --depth;
			}
			par.skip_ws();
			continue;
		  }
		  saw_branch = true;
		  uint64_t weight64 = 1;
		  if (!eval_runtime_integral_ir(par, b, weight64)) {
			static bool warned_weight = false;
			if (!warned_weight) {
			      fprintf(stderr, "Warning: dist weight expression could "
				      "not be evaluated at randomize time; its branch "
				      "has zero weight (further similar warnings "
				      "suppressed).\n");
			      warned_weight = true;
			}
			/* Consume the malformed weight atom so recovery always
			 * advances to the branch value. Use a private builder to
			 * avoid turning the ignored weight into a solver variable. */
			const char* before = par.p;
			Z3Builder ignored(b.ctx, b.defn, b.cobj);
			(void) build_z3_atom(par, ignored);
			if (par.p == before && !par.at_end()) par.consume();
			weight64 = 0;
		  }
		  unsigned weight = weight64 > UINT_MAX
			? UINT_MAX : (unsigned)weight64;
		  Z3_ast clause = b.mk_false();
		  par.skip_ws();
		  if (par.peek() == '[') {
			par.consume();
			uint64_t lo_v = 0, hi_v = 0;
			par.skip_ws();
			bool lo_open = par.peek() == '*';
			bool bounds_ok = true;
			if (lo_open) par.consume();
			else bounds_ok = eval_const_ir(par, lo_v);
			par.expect(',');
			par.skip_ws();
			bool hi_open = par.peek() == '*';
			if (hi_open) par.consume();
			else bounds_ok = eval_const_ir(par, hi_v) && bounds_ok;
			par.expect(']');
			if (!bounds_ok) { lo_v = 1; hi_v = 0; }
			if (lo_open) {
			      lo_v = subject_signed && sw > 0
				    ? (sw >= 64 ? (uint64_t)1 << 63
					: (uint64_t)1 << (sw - 1))
				    : 0;
			}
			if (hi_open) {
			      hi_v = subject_signed && sw > 0
				    ? (sw >= 64 ? UINT64_MAX >> 1
					: ((uint64_t)1 << (sw - 1)) - 1)
				    : (sw >= 64 ? UINT64_MAX
					: ((uint64_t)1 << sw) - 1);
			}
			unsigned rw = lit_at(lo_v);
			if (lit_at(hi_v) > rw) rw = lit_at(hi_v);
			Z3_ast lo = Z3_mk_unsigned_int64(b.ctx, lo_v,
					 Z3_mk_bv_sort(b.ctx, rw));
			Z3_ast hi = Z3_mk_unsigned_int64(b.ctx, hi_v,
					 Z3_mk_bv_sort(b.ctx, rw));
			Z3_ast sx = b.coerce(subject, rw);
			Z3_ast c1 = subject_signed
			      ? Z3_mk_bvsge(b.ctx, sx, lo)
			      : Z3_mk_bvuge(b.ctx, sx, lo);
			Z3_ast c2 = subject_signed
			      ? Z3_mk_bvsle(b.ctx, sx, hi)
			      : Z3_mk_bvule(b.ctx, sx, hi);
			Z3_ast both[2] = {c1, c2};
			clause = Z3_mk_and(b.ctx, 2, both);
			if (weight != 0) {
			      Z3Builder::DistBranch db = {
				    weight, true, lo_v, hi_v
			      };
			      dspec.branches.push_back(db);
			}
		  } else {
			uint64_t v = 0;
			if (eval_const_ir(par, v)) {
			      unsigned vw = lit_at(v);
			      Z3_ast cv = Z3_mk_unsigned_int64(b.ctx, v,
					      Z3_mk_bv_sort(b.ctx, vw));
			      clause = Z3_mk_eq(b.ctx,
					  b.coerce(subject, vw), cv);
			      if (weight != 0) {
				    Z3Builder::DistBranch db = {
					  weight, false, v, v
				    };
				    dspec.branches.push_back(db);
			      }
			}
		  }
		  par.skip_ws();
		  par.expect(')'); // close (b ...)
		  par.skip_ws();
		  if (weight == 0)
			continue;
		  hard_clauses.push_back(clause);
		  // Queue the soft assert; caller applies it after build.
		  // dist-branch soft assert: no `soft'-keyword property refs, so
		  // `disable soft' never applies (empty refs).
		  Z3Builder::SoftAssert sa = {
			b.guard_soft_assert(clause), weight,
			false /* dist */, {}
		  };
		  b.pending_soft.push_back(sa);
	    }
	    par.expect(')');
	    // Exact weighted sampling currently represents an unconditional
	    // distribution. For a guarded dist, keep the correct guarded hard
	    // domain and guarded optimizer preferences above instead of applying
	    // the distribution when its condition is false.
	    if (!dspec.branches.empty() && b.soft_guards.empty())
		  b.dist_specs.push_back(dspec);
	    if (hard_clauses.empty())
		  return saw_branch ? b.mk_false() : b.mk_true();
	    if (hard_clauses.size() == 1) return hard_clauses[0];
	    return Z3_mk_or(b.ctx, (unsigned)hard_clauses.size(), hard_clauses.data());
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
	    Z3_ast expr = bv_to_bool(b.ctx, build_z3_atom(par, b));
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

/* Resolve the synthetic vvp_cobject that stores one unpacked-struct class
 * property. The compiler only emits member tokens for a scalar outer
 * property, so word zero is the complete value aggregate. */
static vvp_cobject*cobj_struct_prop(vvp_cobject*cobj, unsigned outer)
{
      if (!cobj) return nullptr;
      vvp_object_t object;
      cobj->get_object(outer, object, 0);
      vvp_cobject*member_owner = object.peek<vvp_cobject>();
      if (!member_owner || !member_owner->get_defn()->is_struct_type())
	    return nullptr;
      return member_owner;
}

static uint64_t cobj_member_bits(vvp_cobject*cobj, unsigned outer,
				 unsigned member)
{
      vvp_cobject*owner = cobj_struct_prop(cobj, outer);
      return owner ? cobj_prop_bits(owner, member) : 0;
}

static void cobj_set_member_bits(vvp_cobject*cobj, unsigned outer,
				 unsigned member, uint64_t bits)
{
      if (vvp_cobject*owner = cobj_struct_prop(cobj, outer))
	    cobj_set_prop_bits(owner, member, bits);
}

static bool vec4_to_uint64_(const vvp_vector4_t&value, uint64_t&bits)
{
      if (value.size() == 0 || value.size() > 64) return false;
      bits = 0;
      for (unsigned bit = 0 ; bit < value.size() ; bit += 1) {
	    if (value.value(bit) == BIT4_1)
		  bits |= UINT64_C(1) << bit;
	    else if (value.value(bit) != BIT4_0)
		  return false;
      }
      return true;
}

/* Create a fresh vvp_darray for the given %new/darray-style type text
 * (subset used by rand dynamic-array properties). */
static vvp_darray* make_darray_for_type(const string&text, size_t size)
{
      unsigned word_wid = 0;
      size_t n = 0;
      if (text == "b8")   return new vvp_darray_atom<uint8_t>(size);
      if (text == "b16")  return new vvp_darray_atom<uint16_t>(size);
      if (text == "b32")  return new vvp_darray_atom<uint32_t>(size);
      if (text == "b64")  return new vvp_darray_atom<uint64_t>(size);
      if (text == "sb8")  return new vvp_darray_atom<int8_t>(size);
      if (text == "sb16") return new vvp_darray_atom<int16_t>(size);
      if (text == "sb32") return new vvp_darray_atom<int32_t>(size);
      if (text == "sb64") return new vvp_darray_atom<int64_t>(size);
      if ((1 == sscanf(text.c_str(), "v%u%zn", &word_wid, &n))
	  && n == text.size())
	    return new vvp_darray_vec4(size, word_wid);
      if ((1 == sscanf(text.c_str(), "sv%u%zn", &word_wid, &n))
	  && n == text.size())
	    return new vvp_darray_vec4(size, word_wid);
      return new vvp_darray_vec4(size, 32);
}

/* Decode the size-variable container descriptor. Dynamic arrays retain the
 * historical bare element encoding. A queue is Q<MAX>:<ENC>, where MAX is
 * its declared maximum element count (0 for an unbounded queue). Rand queue
 * lowering currently admits only integral elements, so every queue created
 * here is the vec4 flavor and elem_width is exact. */
struct random_container_desc_t {
      bool is_queue = false;
      uint64_t max_size = 0;
      string elem_type;
      unsigned elem_width = 32;
};

static random_container_desc_t random_container_desc_(const string&text)
{
      random_container_desc_t desc;
      desc.elem_type = text;
      if (!text.empty() && text[0] == 'Q') {
	    char*end = nullptr;
	    desc.max_size = strtoull(text.c_str() + 1, &end, 10);
	    if (end != text.c_str() + 1 && end && *end == ':') {
		  desc.is_queue = true;
		  desc.elem_type = string(end + 1);
	    }
      }

      unsigned width = 0;
      size_t n = 0;
      const char*elem = desc.elem_type.c_str();
      if ((1 == sscanf(elem, "b%u%zn", &width, &n) && n == desc.elem_type.size())
	  || (1 == sscanf(elem, "sb%u%zn", &width, &n) && n == desc.elem_type.size())
	  || (1 == sscanf(elem, "v%u%zn", &width, &n) && n == desc.elem_type.size())
	  || (1 == sscanf(elem, "sv%u%zn", &width, &n) && n == desc.elem_type.size()))
	    desc.elem_width = width ? width : 32;
      return desc;
}

static uint64_t random_container_size_cap_(const string&text)
{
      random_container_desc_t desc = random_container_desc_(text);
      uint64_t cap = 65536;
      if (desc.is_queue && desc.max_size && desc.max_size < cap)
	    cap = desc.max_size;
      return cap;
}

static vvp_darray* make_random_container_(const random_container_desc_t&desc,
					  size_t size)
{
      if (desc.is_queue)
	    return new vvp_queue_vec4;
      return make_darray_for_type(desc.elem_type, size);
}

/* Read the current bits of an array-property element (darray object or
 * static array), for the satisfied-already pre-check and xor targets. */
static uint64_t cobj_elem_bits(vvp_cobject* cobj, unsigned idx, unsigned elem)
{
      vvp_object_t propobj;
      cobj->get_object(idx, propobj, 0);
      if (vvp_darray*da = propobj.peek<vvp_darray>()) {
	    if (elem >= da->get_size()) return 0;
	    vvp_vector4_t vec;
	    da->get_word(elem, vec);
	    uint64_t bits = 0;
	    unsigned wid = vec.size(); if (wid > 64) wid = 64;
	    for (unsigned b = 0; b < wid; ++b)
		  if (vec.value(b) == BIT4_1) bits |= (1ULL << b);
	    return bits;
      }
      if (vvp_assoc_base*assoc = propobj.peek<vvp_assoc_base>()) {
	    string key_text, val_str;
	    vvp_vector4_t val_vec;
	    double val_real = 0;
	    int val_kind = -1;
	    if (!assoc->peek_entry(elem, key_text, val_vec, val_real,
				   val_str, val_kind) || val_kind != 0)
		  return 0;
	    uint64_t bits = 0;
	    unsigned wid = val_vec.size();
	    if (wid > 64) wid = 64;
	    for (unsigned bit = 0 ; bit < wid ; bit += 1)
		  if (val_vec.value(bit) == BIT4_1) bits |= (UINT64_C(1) << bit);
	    return bits;
      }
      vvp_vector4_t vec;
      cobj->get_vec4(idx, vec, elem);
      uint64_t bits = 0;
      unsigned wid = vec.size(); if (wid > 64) wid = 64;
      for (unsigned b = 0; b < wid; ++b)
	    if (vec.value(b) == BIT4_1) bits |= (1ULL << b);
      return bits;
}

/* Write bits into an array-property element. */
static void cobj_set_elem_bits(vvp_cobject* cobj, unsigned idx, unsigned elem,
			       unsigned width, uint64_t bits)
{
      vvp_object_t propobj;
      cobj->get_object(idx, propobj, 0);
      if (vvp_darray*da = propobj.peek<vvp_darray>()) {
	    if (elem >= da->get_size()) return;
	    vvp_vector4_t vec(width ? width : 32, BIT4_0);
	    for (unsigned b = 0; b < vec.size() && b < 64; ++b)
		  vec.set_bit(b, ((bits >> b) & 1) ? BIT4_1 : BIT4_0);
	    da->set_word(elem, vec);
	    const class_type*defn = cobj->get_defn();
	    if (defn->property_is_static(idx))
		  defn->static_randomize_transaction_mark_dirty(idx, 0);
	    return;
      }
      if (vvp_assoc_base*assoc = propobj.peek<vvp_assoc_base>()) {
	    vvp_vector4_t vec(width ? width : 32, BIT4_0);
	    for (unsigned bit = 0 ; bit < vec.size() && bit < 64 ; bit += 1)
		  vec.set_bit(bit, ((bits >> bit) & 1) ? BIT4_1 : BIT4_0);
	    (void) assoc->poke_entry(elem, vec, 0.0, string(), 0);
	    const class_type*defn = cobj->get_defn();
	    if (defn->property_is_static(idx))
		  defn->static_randomize_transaction_mark_dirty(idx, 0);
	    return;
      }
      vvp_vector4_t vec;
      cobj->get_vec4(idx, vec, elem);
      unsigned wid = vec.size();
      if (wid == 0) return;
      for (unsigned b = 0; b < wid; ++b)
	    vec.set_bit(b, (b < 64 && ((bits >> b) & 1)) ? BIT4_1 : BIT4_0);
      cobj->set_vec4(idx, vec, elem);
}

/* Current size of a dynamic-array property (0 when unallocated). */
static uint64_t cobj_darray_size(vvp_cobject* cobj, unsigned idx)
{
      vvp_object_t propobj;
      cobj->get_object(idx, propobj, 0);
      if (vvp_darray*da = propobj.peek<vvp_darray>())
	    return da->get_size();
      if (vvp_assoc_base*assoc = propobj.peek<vvp_assoc_base>())
	    return assoc->size();
      return 0;
}

/* Substitute "v:N:W[:s]" value-slot tokens with shaped constants. The
 * runtime stack carries only raw bits, so the IR token is the authoritative
 * SystemVerilog width/sign metadata. Retaining it also prevents a signed
 * byte such as 8'h8d, widened by an intermediate runtime operation, from
 * becoming the unrelated 32-bit value 0xffffff8d in the solver. */
static string substitute_slots(const string& ir,
                                const vector<uint64_t>& slot_vals)
{
      if (slot_vals.empty()) return ir;
      string result;
      const char*begin = ir.c_str();
      const char* p = begin;
      while (*p) {
	    // Match a complete value-slot token. Queue value slots use `qv:';
	    // treating the embedded `v:' as scalar substitution rewrites qv:N:W
	    // to the invalid token qc:V before queue expansion can see it.
	    bool token_start = p == begin
		  || !(isalnum((unsigned char)p[-1]) || p[-1] == '_');
	    if (token_start && p[0]=='v' && p[1]==':') {
		  const char*q = p + 2;
		  unsigned slot = (unsigned)strtoul(q, const_cast<char**>(&q), 10);
		  unsigned width = 32;
		  bool is_signed = false;
		  if (*q == ':') {
			q++;
			width = (unsigned)strtoul(q, const_cast<char**>(&q), 10);
			if (width == 0 || width > 64) width = 32;
			if (q[0] == ':' && q[1] == 's') {
			      is_signed = true;
			      q += 2;
			}
		  }
		  if (slot < slot_vals.size()) {
			uint64_t value = slot_vals[slot];
			if (width < 64)
			      value &= (UINT64_C(1) << width) - 1;
			result += "c:" + to_string(value) + ":"
			       + to_string(width) + (is_signed ? ":s" : "");
		  } else {
			result += "c:0:" + to_string(width)
			       + (is_signed ? ":s" : "");
		  }
		  p = q;
	    } else {
		  result += *p++;
	    }
      }
      return result;
}

/* Scope std::randomize may also carry queue/darray membership operands.
 * qv:N:W[:s] expands to the current element values as ordinary inside-set
 * tokens. Keep a distinct qempty token so membership in an empty queue is
 * false rather than the vacuous true of an accidentally empty set. */
static string substitute_scope_object_slots(
      const string&ir, const vector<vector<uint64_t> >&object_vals)
{
      string result;
      const char*p = ir.c_str();
      while (*p) {
	    if (strncmp(p, "(qfield qf:", 11) == 0) {
		  const char*q = p + 11;
		  unsigned slot = (unsigned)strtoul(q,
						 const_cast<char**>(&q), 10);
		  if (*q != ':') { result += *p++; continue; }
		  q += 1;
		  (void)strtoul(q, const_cast<char**>(&q), 10); // member id
		  if (*q != ':') { result += *p++; continue; }
		  q += 1;
		  unsigned width = (unsigned)strtoul(q,
						const_cast<char**>(&q), 10);
		  if (width == 0 || width > 64) width = 32;
		  bool is_signed = false;
		  if (q[0] == ':' && q[1] == 's') {
			is_signed = true;
			q += 2;
		  }
		  if (*q != ' ') { result += *p++; continue; }
		  q += 1;
		  const char*idx_begin = q;
		  if (*q == '(') {
			int depth = 0;
			do {
			      if (*q == '(') depth += 1;
			      else if (*q == ')') depth -= 1;
			      q += 1;
			} while (*q && depth > 0);
		  } else {
			while (*q && !isspace((unsigned char)*q) && *q != ')')
			      q += 1;
		  }
		  if (*q != ')') { result += *p++; continue; }
		  string index_ir(idx_begin, q - idx_begin);
		  string suffix = is_signed ? ":s" : "";
		  string expanded = "c:0:" + to_string(width) + suffix;
		  if (slot < object_vals.size()) {
			const vector<uint64_t>&vals = object_vals[slot];
			for (size_t i = vals.size() ; i-- > 0 ; ) {
			      uint64_t value = vals[i];
			      if (width < 64)
				    value &= (UINT64_C(1) << width) - 1;
			      expanded = "(ite (eq " + index_ir + " c:"
				    + to_string(i) + ":32) c:"
				    + to_string(value) + ":" + to_string(width)
				    + suffix + " " + expanded + ")";
			}
		  }
		  result += expanded;
		  p = q + 1;
	    } else if (p[0] == 'q' && p[1] == 'v' && p[2] == ':') {
		  const char*q = p + 3;
		  unsigned slot = (unsigned)strtoul(q,
						 const_cast<char**>(&q), 10);
		  unsigned width = 32;
		  bool is_signed = false;
		  if (*q == ':') {
			q++;
			width = (unsigned)strtoul(q,
						const_cast<char**>(&q), 10);
			if (*q == ':' && q[1] == 's') { is_signed = true; q += 2; }
		  }
		  if (slot >= object_vals.size() || object_vals[slot].empty()) {
			result += "qempty";
		  } else {
			for (size_t i = 0 ; i < object_vals[slot].size() ; i += 1) {
			      if (i) result += " ";
			      result += "c:" + to_string(object_vals[slot][i])
				    + ":" + to_string(width)
				    + (is_signed ? ":s" : "");
			}
		  }
		  p = q;
	    } else {
		  result += *p++;
	    }
      }
      return result;
}

/* Result of one solve pass. SAT_APPLIED: a model was found and written
 * back. SAT_CURRENT: the pre-filled values already satisfy the
 * constraints. FAILED covers both proven UNSAT and UNKNOWN: neither may
 * commit tentative values or randc history (IEEE 1800-2017 18.6.1). */
enum z3_pass_status { Z3PASS_FAILED = 0, Z3PASS_SAT_APPLIED = 1,
		      Z3PASS_SAT_CURRENT = 2 };

/* One logical object-RNG stream for the complete solve. A dynamic foreach
 * requires a speculative size pass followed by the authoritative element
 * pass. Rewind replays pass-1 words from this tape without rewinding the
 * object's generator; only a pass that needs a longer prefix advances the
 * object further. Thus the two internal passes consume one external stream,
 * while a failed solve still leaves every word it requested consumed.
 *
 * uniform_index uses rejection against the largest multiple of `bound' in
 * [0,2^32), eliminating the low-index bias of `rng_next() % bound'. */
class z3_rng_stream_t {
    public:
      explicit z3_rng_stream_t(vvp_cobject*cobj) : cobj_(cobj) { }

      uint32_t next()
      {
	    if (cursor_ < words_.size())
		  return words_[cursor_++];
	    uint32_t word = cobj_->rng_next();
	    words_.push_back(word);
	    cursor_ += 1;
	    return word;
      }

      size_t uniform_index(size_t bound)
      {
	    assert(bound > 0 && bound <= UINT32_MAX);
	    const uint64_t span = (uint64_t)UINT32_MAX + 1;
	    const uint64_t limit = span - span % (uint64_t)bound;
	    uint32_t word;
	    do {
		  word = next();
	    } while ((uint64_t)word >= limit);
	    return (size_t)((uint64_t)word % (uint64_t)bound);
      }

      void rewind() { cursor_ = 0; }

    private:
      vvp_cobject*cobj_;
      vector<uint32_t> words_;
      size_t cursor_ = 0;
};

/* One solve pass. dyn_sizes null: dynamic-foreach templates are
 * collected (returned via dyn_out) and contribute `true`; sizes are
 * free subject to their constraints. dyn_sizes set: templates expand
 * to the given element counts and every size variable is pinned to
 * the array's current (pass-1-written) size, implementing the
 * IEEE 1800-2017 18.5.8.2 size-before-iterative-constraints order. */
/*
 * Is property `pid` a RANDOM variable for this randomize() call, or a
 * STATE variable (IEEE 1800-2017 18.3)? `sel`, when non-null, is the
 * explicit set from randomize(a, b) / randomize(null) (18.11) and
 * overrides the declaration entirely — 18.11 makes a listed variable
 * random even if it was not declared `rand`. With no explicit set the
 * answer is the declaration, gated by rand_mode() (18.8).
 */
static bool rand_active_(const class_type* defn, vvp_cobject* cobj,
			 const std::vector<bool>* sel, unsigned pid)
{
      if (sel) return pid < sel->size() ? (*sel)[pid] : false;
      if (!defn->property_is_rand(pid)) return false;
      return cobj ? cobj->rand_mode_any(pid) : true;
}

static bool rand_elem_active_(const class_type* defn, vvp_cobject* cobj,
			      const std::vector<bool>* sel, unsigned pid,
			      unsigned elem)
{
      if (sel) return pid < sel->size() ? (*sel)[pid] : false;
      if (!defn->property_is_rand(pid)) return false;
      if (!cobj) return true;
      const std::string&bt = defn->property_base_type(pid);
      if (!bt.empty() && (bt[0] == 'D' || bt[0] == 'Q' || bt[0] == 'M'))
	    return cobj->rand_mode_for_randomization(pid, elem);
      if (defn->property_array_size(pid) <= 1)
	    return cobj->rand_mode(pid);
      return cobj->rand_mode(pid, elem);
}

static bool rand_member_active_(const class_type*defn, vvp_cobject*cobj,
				const std::vector<bool>*sel,
				unsigned outer, unsigned member)
{
      if (!rand_active_(defn, cobj, sel, outer)) return false;
      vvp_cobject*owner = cobj_struct_prop(cobj, outer);
      if (!owner) return false;
      const class_type*member_defn = owner->get_defn();
      if (member >= member_defn->property_count()
	  || !member_defn->property_is_rand(member))
	    return false;
      return owner->rand_mode_for_randomization(member, 0);
}

/* ---------------------------------------------------------------
 * RANDOM-DIST fixes #1/#2/#4: exact-uniform / exact-weighted sampling
 * for the overwhelmingly common case -- a single scalar rand property
 * whose feasible set is small enough to enumerate outright.
 *
 * Why: `Z3_optimize_minimize(bvxor(prop, random_target))` (still used
 * below as the fallback for anything NOT handled here) only samples
 * uniformly when the feasible set is closed under XOR with a uniform
 * random target -- true for a full power-of-two range, false for an
 * arbitrary subset, where it instead produces a fixed "nearest in
 * Hamming distance" sink value: `x inside {[0:2]}` on a 2-bit x came
 * back close to 25/25/50 (never uniform 33/33/33), and `x inside
 * {[0:99]}' on a 7-bit x made the top of the range (96-99) up to 7x
 * hot. Enumerating the actual feasible set and choosing an index
 * uniformly at random is exact for any shape of constraint, as long as
 * the set is cheap to enumerate.
 *
 * Bound: ENUM_DOMAIN_CAP caps the property's OWN declared width (2^w),
 * not some run-time count of a big multi-variable search -- so the
 * cost is at most ENUM_DOMAIN_CAP+1 trivial bitvector SAT checks, and
 * only for a property that reaches this code at all (an unconstrained
 * property never enters the Z3 path in the first place, and a
 * constraint the pre-filled random value already satisfies takes the
 * existing fast path above and never reaches here either). Widths
 * whose full domain exceeds the cap keep the old bvxor approximation,
 * documented as such at the point of use below.
 */
static const uint64_t ENUM_DOMAIN_CAP = 1024;

/* Enumerate every value `var` (a WIDTH-bit bitvector constant) can take
 * while `base` remains satisfiable. `base` already carries every hard
 * constraint/pin relevant to this solve.
 *
 * Do NOT enumerate by repeatedly asking Z3 for a complete model and then
 * blocking the value it chose. A dense 10-bit field needs 1024 models that
 * way, and constructing each model materializes values for every other free
 * variable too. OpenTitan's adc_ctrl_filter_cfg has two such fields and 16
 * instances; model construction alone consumed most of its startup time.
 *
 * Probe each candidate with a temporary equality assumption instead. This
 * has the same bounded <=ENUM_DOMAIN_CAP SAT-check count, discovers exactly
 * the same feasible set, and leaves the solver assertion stack untouched,
 * but never builds the irrelevant full models. An UNKNOWN result makes the
 * exact enumeration fail as a whole so the caller uses its documented
 * fallback rather than sampling an incomplete set. */
static bool z3_enumerate_domain(Z3_context ctx, Z3_solver base, Z3_ast var,
                                 unsigned width, vector<uint64_t>& out)
{
      out.clear();
      if (width == 0 || width > 32) return false;
      uint64_t domain = (uint64_t)1 << width;
      if (domain > ENUM_DOMAIN_CAP) return false;

      Z3_sort sort = Z3_mk_bv_sort(ctx, width);
      for (uint64_t bits = 0 ; bits < domain ; bits += 1) {
	    Z3_ast cv = Z3_mk_unsigned_int64(ctx, bits, sort);
	    Z3_ast eq = Z3_mk_eq(ctx, var, cv);
	    Z3_lbool r = Z3_solver_check_assumptions(ctx, base, 1, &eq);
	    if (r == Z3_L_TRUE) {
		  out.push_back(bits);
	    } else if (r == Z3_L_UNDEF) {
		  out.clear();
		  return false;
	    }
      }
      return !out.empty();
}

/* Probe a wide property's ACTUAL feasible set up to a small cap.  Unlike
 * z3_enumerate_domain, this is useful for a 32/64-bit property constrained to
 * an equality or short interval (the normal shape of protocol transactions),
 * without attempting its enormous declared domain.  Returning false after
 * CAP+1 distinct models leaves sampling to the general fallback; returning
 * true means the solver proved the complete feasible set was exhausted. */
static bool z3_enumerate_sparse_wide_domain_(Z3_context ctx, Z3_solver base,
                                             Z3_ast var, unsigned width,
                                             vector<uint64_t>& out)
{
      static const size_t SPARSE_DOMAIN_CAP = 64;
      out.clear();
      if (width == 0 || width > 64) return false;

      bool exhausted = false;
      Z3_solver_push(ctx, base);
      while (out.size() <= SPARSE_DOMAIN_CAP) {
	    Z3_lbool r = Z3_solver_check(ctx, base);
	    if (r == Z3_L_FALSE) {
		  exhausted = true;
		  break;
	    }
	    if (r != Z3_L_TRUE) break;

	    Z3_model m = Z3_solver_get_model(ctx, base);
	    Z3_model_inc_ref(ctx, m);
	    uint64_t bits = 0;
	    bool ok = z3_eval_uint64(ctx, m, var, bits);
	    Z3_model_dec_ref(ctx, m);
	    if (!ok) break;

	    out.push_back(bits);
	    Z3_ast cv = Z3_mk_unsigned_int64(ctx, bits,
					 Z3_mk_bv_sort(ctx, width));
	    Z3_solver_assert(ctx, base,
			     Z3_mk_not(ctx, Z3_mk_eq(ctx, var, cv)));
      }
      Z3_solver_pop(ctx, base, 1);

      if (!exhausted || out.empty()) {
	    out.clear();
	    return false;
      }
      return true;
}

/* Performance note on z3_enumerate_domain above: it costs one cheap SAT
 * probe per value in the declared domain. That bounded exhaustive scan is
 * necessary when other free variables make `var == value` an existential
 * question, but it is still more round-trips than a dense single-variable
 * range needs. The function below discovers the SAME
 * feasible set as a small list of maximal intervals via binary search
 * -- O(log(domain)) Z3 calls per interval rather than one per value,
 * e.g. ~14 calls instead of ~100 for a single 100-value contiguous
 * range -- at the cost of only being valid when `var` is the ONLY free
 * variable anywhere in the hard-constraint set (see the caller's
 * eligibility check): with no other free variable to existentially
 * quantify away, "value v is infeasible" is simply the ground logical
 * negation of the same hard-constraint conjunction, which is what makes
 * a second solver holding that negation meaningful. When some other
 * rand property, array element, or array size is also still free, that
 * negation would need to be a FORALL over those other variables, not a
 * simple negated SAT query, so this fast path is skipped for that case
 * (z3_enumerate_domain above still handles it, just at its normal
 * per-value cost). */
static bool z3_enumerate_domain_single_var_fast_(Z3_context ctx,
                                                  Z3_solver base,
                                                  Z3_ast var, unsigned width,
                                                  vector<uint64_t>& out)
{
      out.clear();
      if (width == 0 || width > 32) return false;
      uint64_t domain = (uint64_t)1 << width;
      if (domain > ENUM_DOMAIN_CAP) return false;

      // `base` already carries exactly the hard-constraint conjunction we
      // need for the POSITIVE ("is there a feasible value in here")
      // queries -- reuse it directly rather than build a duplicate
      // solver. The NEGATIVE ("is there an infeasible value in here")
      // queries need the logical negation of that same conjunction, read
      // back from `base` once via Z3_solver_get_assertions (valid here
      // specifically because the eligibility check guarantees `var` is
      // the only free variable in it -- see the function comment above).
      Z3_ast_vector avec = Z3_solver_get_assertions(ctx, base);
      Z3_ast_vector_inc_ref(ctx, avec);
      unsigned n = Z3_ast_vector_size(ctx, avec);
      Z3_ast conj;
      if (n == 0) {
	    conj = Z3_mk_true(ctx);
      } else if (n == 1) {
	    conj = Z3_ast_vector_get(ctx, avec, 0);
      } else {
	    vector<Z3_ast> parts;
	    parts.reserve(n);
	    for (unsigned i = 0 ; i < n ; i += 1)
		  parts.push_back(Z3_ast_vector_get(ctx, avec, i));
	    conj = Z3_mk_and(ctx, n, parts.data());
      }
      Z3_ast_vector_dec_ref(ctx, avec);

      Z3_solver neg = Z3_mk_simple_solver(ctx);
      Z3_solver_inc_ref(ctx, neg);
      Z3_solver_assert(ctx, neg, Z3_mk_not(ctx, conj));

      Z3_sort sort = Z3_mk_bv_sort(ctx, width);
      auto exists_in = [&](Z3_solver s, uint64_t lo, uint64_t hi) -> bool {
	    if (lo > hi) return false;
	    Z3_ast loc = Z3_mk_unsigned_int64(ctx, lo, sort);
	    Z3_ast hic = Z3_mk_unsigned_int64(ctx, hi, sort);
	    Z3_ast c1 = Z3_mk_bvuge(ctx, var, loc);
	    Z3_ast c2 = Z3_mk_bvule(ctx, var, hic);
	    Z3_ast both[2] = { c1, c2 };
	    Z3_ast range = Z3_mk_and(ctx, 2, both);
	    Z3_solver_push(ctx, s);
	    Z3_solver_assert(ctx, s, range);
	    Z3_lbool r = Z3_solver_check(ctx, s);
	    Z3_solver_pop(ctx, s, 1);
	    return r == Z3_L_TRUE;
      };

      uint64_t cur = 0;
      const unsigned MAX_INTERVALS = 64;
      unsigned interval_count = 0;
      bool safety_ok = true;
      while (cur < domain && interval_count < MAX_INTERVALS
	     && out.size() < domain) {
	    interval_count += 1;
	    if (!exists_in(base, cur, domain - 1)) break;

	      // Binary search: smallest m in [cur,domain-1] such that a
	      // feasible value exists in [cur,m] -- that m IS the leftmost
	      // feasible value >= cur.
	    uint64_t lo = cur, hi = domain - 1;
	    while (lo < hi) {
		  uint64_t mid = lo + (hi - lo) / 2;
		  if (exists_in(base, cur, mid)) hi = mid;
		  else lo = mid + 1;
	    }
	    uint64_t start = lo;

	      // Binary search: smallest m in [start,domain-1] such that an
	      // INFEASIBLE value exists in [start,m] -- one past the end of
	      // the maximal feasible run starting at `start`. None found
	      // means the run reaches the end of the domain.
	    uint64_t end_incl;
	    if (!exists_in(neg, start, domain - 1)) {
		  end_incl = domain - 1;
	    } else {
		  uint64_t l2 = start, h2 = domain - 1;
		  while (l2 < h2) {
			uint64_t mid = l2 + (h2 - l2) / 2;
			if (exists_in(neg, start, mid)) h2 = mid;
			else l2 = mid + 1;
		  }
		  if (l2 <= start) { safety_ok = false; break; }
		  end_incl = l2 - 1;
	    }

	    for (uint64_t v = start ; v <= end_incl && out.size() < domain
		 ; v += 1)
		  out.push_back(v);
	    cur = end_incl + 1;
      }

      Z3_solver_dec_ref(ctx, neg);
      if (!safety_ok) out.clear();
      return !out.empty();
}

/* RANDOM-DIST fix #2 (18.5.4): `dist`'s weights are a PROBABILITY
 * distribution over its branch values, not a preference for the
 * heaviest branch -- so draw a value with probability proportional to
 * its weight, check it is jointly feasible with the rest of the
 * constraints (18.5.4 explicitly requires dist values to still satisfy
 * other constraints), and retry among the remaining weighted
 * alternatives if not. `:/` divides a range branch's weight equally
 * among its member values (expanded here up to RANGE_EXPAND_CAP; a
 * bigger range bails out to the caller's fallback). On success the
 * winning value is pinned as a hard equality into both `base` (so
 * later enumerations/dist picks see it) and `opt` (so the final model
 * reports it). Returns false (chosen left unset) when the subject
 * isn't usable this way -- caller keeps the pre-existing hard-union +
 * soft-weight approximation for it. */
static bool z3_resolve_dist_exact(Z3_context ctx, Z3_solver base,
                                   Z3_optimize opt,
                                   const Z3Builder::DistSpec& spec,
				   z3_rng_stream_t& rng,
                                   uint64_t& chosen)
{
      static const uint64_t RANGE_EXPAND_CAP = 4096;
      struct Cand { uint64_t val; double weight; };
      vector<Cand> cands;
      for (const auto& br : spec.branches) {
	    if (!br.is_range) {
		  Cand c = { br.lo, (double)br.weight };
		  cands.push_back(c);
		  continue;
	    }
	    if (br.hi < br.lo) continue;
	    uint64_t span = br.hi - br.lo + 1;
	    if (span == 0 || span > RANGE_EXPAND_CAP)
		  return false;
	    double each = (double)br.weight / (double)span;
	    for (uint64_t v = br.lo; v <= br.hi; v += 1) {
		  Cand c = { v, each };
		  cands.push_back(c);
	    }
      }
      if (cands.empty()) return false;

      Z3_sort sort = Z3_mk_bv_sort(ctx, spec.width ? spec.width : 32);
      while (!cands.empty()) {
	    double total = 0;
	    for (const auto& c : cands) total += c.weight;
	    if (total <= 0) return false;
	    double r = ((double)rng.next() / 4294967296.0) * total;
	    size_t pick_i = cands.size() - 1;
	    double acc = 0;
	    for (size_t i = 0 ; i < cands.size() ; i += 1) {
		  acc += cands[i].weight;
		  if (r < acc) { pick_i = i; break; }
	    }
	    uint64_t v = cands[pick_i].val;
	    Z3_ast cv = Z3_mk_unsigned_int64(ctx, v, sort);
	    Z3_ast eq = Z3_mk_eq(ctx, spec.subject, cv);

	    Z3_solver_push(ctx, base);
	    Z3_solver_assert(ctx, base, eq);
	    Z3_lbool feasible = Z3_solver_check(ctx, base);
	    Z3_solver_pop(ctx, base, 1);

	    if (feasible == Z3_L_TRUE) {
		  Z3_solver_assert(ctx, base, eq);
		  Z3_optimize_assert(ctx, opt, eq);
		  chosen = v;
		  return true;
	    }
	    cands.erase(cands.begin() + pick_i);
      }
      return false;
}

static int z3_solve_pass_(const class_type* defn, vvp_cobject* cobj,
			      z3_rng_stream_t& rng,
                      const vector<string>& extra_ir,
                      const vector<uint64_t>& slot_vals,
                      const std::map<unsigned,uint64_t>* dyn_sizes,
                      std::vector<Z3Builder::DynForeach>* dyn_out,
                      const std::vector<bool>* prop_active,
                      bool include_class_constraints)
{
      if (z3_solve_trace(defn)) {
	    fprintf(stderr,
		    "trace z3-solve: begin class=%s props=%zu constraints=%zu extra=%zu slots=%zu dyn=%d\n",
		    defn ? defn->class_name().c_str() : "<scope>",
		    defn ? defn->property_count() : 0,
		    defn ? defn->constraint_count() : 0, extra_ir.size(), slot_vals.size(),
		    dyn_sizes ? 1 : 0);
	    for (size_t i = 0; i < extra_ir.size(); ++i)
		  fprintf(stderr, "trace z3-solve: extra[%zu]=%s\n",
			  i, extra_ir[i].c_str());
	    for (size_t i = 0; i < slot_vals.size(); ++i)
		  fprintf(stderr, "trace z3-solve: slot[%zu]=0x%llx\n",
			  i, (unsigned long long)slot_vals[i]);
	    fflush(stderr);
      }
      Z3_config cfg = Z3_mk_config();
      Z3_set_param_value(cfg, "model", "true");
      Z3_context ctx = Z3_mk_context(cfg);
      Z3_del_config(cfg);

      Z3Builder builder(ctx, defn, cobj);
      builder.dyn_sizes = dyn_sizes;

      // Use Z3 optimize so we can add soft "match random target" constraints
      // to guide solutions toward varied values.
      Z3_optimize opt = Z3_mk_optimize(ctx);
      Z3_optimize_inc_ref(ctx, opt);
      builder.opt = opt; // C7: collect dist soft asserts during build

      // RANDOM-DIST fixes #1/#2/#4: a plain solver mirroring every HARD
      // assertion made on `opt` below (constraints, pins, caps -- never
      // the soft/diversity objectives), so exact feasible-set enumeration
      // and exact weighted dist sampling can ask "is this candidate value
      // jointly feasible" without the overhead/semantics of `opt`'s
      // optimization objectives. Z3_mk_simple_solver (not Z3_mk_solver):
      // measured ~7-8ms cheaper per randomize() call -- the tactic-
      // combinator setup Z3_mk_solver does is unneeded overhead for a
      // quantifier-free bitvector check like every one of these.
      Z3_solver base = Z3_mk_simple_solver(ctx);
      Z3_solver_inc_ref(ctx, base);

      // Assert hard constraints (class-level), skipping disabled ones.

      for (size_t ci = 0;
	   include_class_constraints && ci < defn->constraint_count(); ++ci) {
	    if (cobj && !cobj->constraint_mode(ci)) continue;
	    const string& ir = defn->constraint_ir(ci);
	    if (ir.empty()) continue;
	    if (z3_solve_trace(defn)) {
		  fprintf(stderr,
			  "trace z3-solve: parse[%zu] begin name=%s bytes=%zu\n",
			  ci, defn->constraint_name(ci).c_str(), ir.size());
		  fflush(stderr);
	    }
	    Z3_ast assertion = parse_constraint_ir(ir, builder);
	    if (z3_solve_trace(defn)) {
		  fprintf(stderr, "trace z3-solve: parse[%zu] end name=%s\n",
			  ci, defn->constraint_name(ci).c_str());
		  fflush(stderr);
	    }
	    Z3_optimize_assert(ctx, opt, assertion);
	    Z3_solver_assert(ctx, base, assertion);
      }
      // Assert with-constraints (call-site inline), with slot substitution.
      for (const string& wir : extra_ir) {
	    if (wir.empty()) continue;
	    string sub = substitute_slots(wir, slot_vals);
	    Z3_ast assertion = parse_constraint_ir(sub, builder);
	    Z3_optimize_assert(ctx, opt, assertion);
	    Z3_solver_assert(ctx, base, assertion);
      }
      if (dyn_out)
	    *dyn_out = builder.dyn_foreach;

      // STATE VARIABLES (IEEE 1800-2017 18.3). Every class property the
      // constraints mention became a solver variable while the IR was
      // parsed, whether or not this call randomizes it. Pin the ones it
      // does not — a plain non-rand property, a property frozen with
      // rand_mode(0) (18.8), or one left out of randomize(a, b) (18.11)
      // — to the value it holds right now, so the solver reads it as a
      // constant instead of choosing it. The pins go on before the
      // objectives below, which then skip the same properties: an
      // inactive variable gets no diversity target and no write-back.
      for (auto& pv : builder.prop_vars) {
	    if (rand_active_(defn, cobj, prop_active, pv.idx)) continue;
	    Z3_sort sort = Z3_mk_bv_sort(ctx, pv.width);
	    Z3_ast cv = Z3_mk_unsigned_int64(ctx,
		  cobj_prop_bits(cobj, pv.idx), sort);
	    Z3_ast eq = Z3_mk_eq(ctx, pv.var, cv);
	    Z3_optimize_assert(ctx, opt, eq);
	    Z3_solver_assert(ctx, base, eq);
      }
      for (auto& mv : builder.member_vars) {
	    if (rand_member_active_(defn, cobj, prop_active,
				    mv.outer, mv.member))
		  continue;
	    Z3_sort sort = Z3_mk_bv_sort(ctx, mv.width);
	    Z3_ast cv = Z3_mk_unsigned_int64(ctx,
		  cobj_member_bits(cobj, mv.outer, mv.member), sort);
	    Z3_ast eq = Z3_mk_eq(ctx, mv.var, cv);
	    Z3_optimize_assert(ctx, opt, eq);
	    Z3_solver_assert(ctx, base, eq);
      }
      for (auto& ev : builder.elem_vars) {
	    if (rand_elem_active_(defn, cobj, prop_active, ev.idx, ev.elem))
		  continue;
	    Z3_sort sort = Z3_mk_bv_sort(ctx, ev.width);
	    Z3_ast cv = Z3_mk_unsigned_int64(ctx,
		  cobj_elem_bits(cobj, ev.idx, ev.elem), sort);
	    Z3_ast eq = Z3_mk_eq(ctx, ev.var, cv);
	    Z3_optimize_assert(ctx, opt, eq);
	    Z3_solver_assert(ctx, base, eq);
      }
      for (auto& sv : builder.size_vars) {
	    if (rand_active_(defn, cobj, prop_active, sv.idx)) continue;
	    Z3_sort s32 = Z3_mk_bv_sort(ctx, 32);
	    Z3_ast cv = Z3_mk_unsigned_int64(ctx,
		  cobj_darray_size(cobj, sv.idx), s32);
	    Z3_ast eq = Z3_mk_eq(ctx, sv.var, cv);
	    Z3_optimize_assert(ctx, opt, eq);
	    Z3_solver_assert(ctx, base, eq);
      }

	// An enum member's legal domain is its declared literal set, not all
	// 2^width encodings. Assert that domain before either prechecking the
	// random pre-fill or enumerating a constrained randc cycle.
      for (auto& mv : builder.member_vars) {
	    if (!rand_member_active_(defn, cobj, prop_active,
				     mv.outer, mv.member))
		  continue;
	    vvp_cobject*owner = cobj_struct_prop(cobj, mv.outer);
	    const class_type*member_defn = owner ? owner->get_defn() : nullptr;
	    if (!member_defn || !member_defn->property_is_enum(mv.member))
		  continue;
	    vector<Z3_ast> literals;
	    const vector<vvp_vector4_t>&domain =
		  member_defn->property_enum_values(mv.member);
	    for (const vvp_vector4_t&value : domain) {
		  uint64_t bits = 0;
		  if (!vec4_to_uint64_(value, bits)) continue;
		  Z3_ast cv = Z3_mk_unsigned_int64(ctx, bits,
			Z3_mk_bv_sort(ctx, mv.width));
		  literals.push_back(Z3_mk_eq(ctx, mv.var, cv));
	    }
	    Z3_ast in_domain = literals.empty() ? Z3_mk_false(ctx)
		  : literals.size() == 1 ? literals.front()
		  : Z3_mk_or(ctx, (unsigned)literals.size(), literals.data());
	    Z3_optimize_assert(ctx, opt, in_domain);
	    Z3_solver_assert(ctx, base, in_domain);
      }

      // Dynamic-container size variables are bounded by a pragmatic hard cap
      // so an under-constrained `.size() > k` cannot demand a huge
      // allocation. A bounded queue additionally carries its declared
      // maximum count in the Q descriptor; violating that bound is UNSAT.
      for (auto& sv : builder.size_vars) {
	    Z3_sort s32 = Z3_mk_bv_sort(ctx, 32);
	    uint64_t cap_value =
		  random_container_size_cap_(sv.container_type);
	    Z3_ast cap = Z3_mk_unsigned_int64(ctx, cap_value, s32);
	    Z3_ast le = Z3_mk_bvule(ctx, sv.var, cap);
	    Z3_optimize_assert(ctx, opt, le);
	    Z3_solver_assert(ctx, base, le);
      }
      // Element pass: sizes were solved (and written back) in the size
      // pass — pin them so the re-solve cannot move them.
      if (dyn_sizes) {
	    for (auto& sv : builder.size_vars) {
		  Z3_sort s32 = Z3_mk_bv_sort(ctx, 32);
		  Z3_ast cur = Z3_mk_unsigned_int64(ctx,
			cobj_darray_size(cobj, sv.idx), s32);
		  Z3_ast eq = Z3_mk_eq(ctx, sv.var, cur);
		  Z3_optimize_assert(ctx, opt, eq);
		  Z3_solver_assert(ctx, base, eq);
	    }
      }

      // C7: apply queued soft asserts from dist branches.  Each carries a
      // weight; Z3_optimize_assert_soft prefers higher-weight branches when
      // multiple feasible solutions exist.
      auto soft_dropped = [&](const Z3Builder::SoftAssert& sa) -> bool {
	    // M3B-3: drop a soft assert that references a `disable soft'd
	    // property (regardless of the order the two constraint blocks
	    // were parsed — disabled_soft_refs is complete by now).
	    if (builder.disabled_soft_refs.empty()) return false;
	    for (const Z3Builder::VarRef&ref : sa.refs)
		  if (builder.soft_ref_disabled(ref)) return true;
	    return false;
      };

	// `dist' branch preferences first, all in one weighted group: their
	// weights ARE the distribution, so they must be traded off against
	// each other inside a single objective.
      for (const auto& sa : builder.pending_soft) {
	    if (sa.from_soft_kw || soft_dropped(sa)) continue;
	    char w_str[32];
	    snprintf(w_str, sizeof(w_str), "%u", sa.weight);
	    Z3_symbol grp = Z3_mk_string_symbol(ctx, "dist");
	    Z3_optimize_assert_soft(ctx, opt, sa.a, w_str, grp);
      }

	// Explicit `soft' constraints are PRIORITISED, not weighted
	// (IEEE 1800-2017 18.5.14.1): when two of them conflict, the one
	// declared later wins outright — no combination of earlier soft
	// constraints can outvote it. Z3 optimises separate soft groups
	// lexicographically in the order the groups are created, so each
	// gets its own group and they are applied in REVERSE declaration
	// order: last declared becomes the first, highest-priority
	// objective. Summing them into one weighted group instead (what
	// this used to do) let `soft v == 3; soft v == 200;' settle on
	// v == 3, silently.
      for (size_t si = builder.pending_soft.size() ; si-- > 0 ; ) {
	    const auto& sa = builder.pending_soft[si];
	    if (!sa.from_soft_kw || soft_dropped(sa)) continue;
	    char w_str[32];
	    snprintf(w_str, sizeof(w_str), "%u", sa.weight);
	    char gname[32];
	    snprintf(gname, sizeof(gname), "soft%u", (unsigned)si);
	    Z3_symbol grp = Z3_mk_string_symbol(ctx, gname);
	    Z3_optimize_assert_soft(ctx, opt, sa.a, w_str, grp);
      }

      // Check if the already-randomized values satisfy all hard constraints.
      // Use a temporary solver for this fast-path check (opt is slow for pure
      // feasibility when we already have a candidate). RANDOM-DIST
      // performance fix: Z3_mk_simple_solver skips the tactic-combinator
      // setup Z3_mk_solver does (irrelevant for this quantifier-free
      // bitvector check) -- measured ~7-8ms cheaper per randomize() call.
      {
	    Z3_solver chk = Z3_mk_simple_solver(ctx);
	    Z3_solver_inc_ref(ctx, chk);
	      // If the current candidate satisfies every active explicit soft
	      // constraint as well as the hard set, no other model can improve
	      // the lexicographic soft objective.  Treat the soft expressions as
	      // hard only in this candidate check; conflicting or unsatisfied soft
	      // constraints still fall through to the normal Optimize solve.
	      // This preserves 18.5.14.1 priority semantics while avoiding an
	      // expensive Optimize context for the common UVM case where callers
	      // pre-fill all of a transaction's preferred default values.
	    const size_t precheck_soft_count = builder.pending_soft.size();
	    for (size_t si = 0; si < precheck_soft_count; ++si) {
		  const auto& sa = builder.pending_soft[si];
		  if (!sa.from_soft_kw || soft_dropped(sa)) continue;
		  Z3_solver_assert(ctx, chk, sa.a);
	    }
	    for (size_t ci = 0;
		 include_class_constraints && ci < defn->constraint_count(); ++ci) {
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
	    for (auto& mv : builder.member_vars) {
		  uint64_t bits = cobj_member_bits(cobj, mv.outer, mv.member);
		  Z3_sort sort = Z3_mk_bv_sort(ctx, mv.width);
		  Z3_ast cv = Z3_mk_unsigned_int64(ctx, bits, sort);
		  Z3_solver_assert(ctx, chk, Z3_mk_eq(ctx, mv.var, cv));
		  vvp_cobject*owner = cobj_struct_prop(cobj, mv.outer);
		  const class_type*member_defn = owner ? owner->get_defn() : nullptr;
		  if (!rand_member_active_(defn, cobj, prop_active,
					   mv.outer, mv.member)
		      || !member_defn
		      || !member_defn->property_is_enum(mv.member))
			continue;
		  vector<Z3_ast> literals;
		  for (const vvp_vector4_t&value :
		       member_defn->property_enum_values(mv.member)) {
			uint64_t enum_bits = 0;
			if (!vec4_to_uint64_(value, enum_bits)) continue;
			Z3_ast ev = Z3_mk_unsigned_int64(ctx, enum_bits, sort);
			literals.push_back(Z3_mk_eq(ctx, mv.var, ev));
		  }
		  Z3_ast in_domain = literals.empty() ? Z3_mk_false(ctx)
			: literals.size() == 1 ? literals.front()
			: Z3_mk_or(ctx, (unsigned)literals.size(),
				   literals.data());
		  Z3_solver_assert(ctx, chk, in_domain);
	    }
	    for (auto& sv : builder.size_vars) {
		  uint64_t cur = cobj_darray_size(cobj, sv.idx);
		  Z3_sort sort = Z3_mk_bv_sort(ctx, 32);
		  Z3_ast cv = Z3_mk_unsigned_int64(ctx, cur, sort);
		  Z3_solver_assert(ctx, chk, Z3_mk_eq(ctx, sv.var, cv));
	    }
	    for (auto& ev : builder.elem_vars) {
		  uint64_t bits = cobj_elem_bits(cobj, ev.idx, ev.elem);
		  Z3_sort sort = Z3_mk_bv_sort(ctx, ev.width);
		  Z3_ast cv = Z3_mk_unsigned_int64(ctx, bits, sort);
		  Z3_solver_assert(ctx, chk, Z3_mk_eq(ctx, ev.var, cv));
	    }
	    Z3_lbool precheck = Z3_solver_check(ctx, chk);
	    Z3_solver_dec_ref(ctx, chk);

	      // solve...before present: always run the staged solve so
	      // the ordered variables get their stage-local diversity
	      // distribution (18.5.10 is about distribution; the
	      // accept-current fast path would sample differently).
	    if (!builder.order_pairs.empty())
		  precheck = Z3_L_FALSE;

	      // A rand dynamic array's SIZE is randomized by the solver
	      // (18.4), not by the caller's pre-fill — so unlike every
	      // scalar rand property it arrives at this check holding the
	      // PREVIOUS call's value, not a fresh random target. Taking
	      // the accept-current path on it would keep that size for
	      // the rest of the simulation: `rand int a[]' with
	      // `a.size() inside {[3:6]}' resized once and then answered
	      // 3 forever. Run the optimize pass so the size gets its
	      // randomized objective like everything else. (Only in the
	      // size pass — the element pass has them pinned already.)
	    if (!dyn_sizes)
		  for (auto& sv : builder.size_vars)
			if (rand_active_(defn, cobj, prop_active, sv.idx))
			      precheck = Z3_L_FALSE;

	      // A constrained randc variable must be selected against its
	      // committed cycle history even when the pre-fill happens to
	      // satisfy the constraints. Accept-current would skip feasible-
	      // domain enumeration and could emit a previously used value.
	    for (auto& pv : builder.prop_vars)
		  if (rand_active_(defn, cobj, prop_active, pv.idx)
		      && defn->property_is_randc(pv.idx))
			precheck = Z3_L_FALSE;
	    for (auto& mv : builder.member_vars) {
		  vvp_cobject*owner = cobj_struct_prop(cobj, mv.outer);
		  const class_type*member_defn = owner ? owner->get_defn() : nullptr;
		  if (rand_member_active_(defn, cobj, prop_active,
					  mv.outer, mv.member)
		      && member_defn
		      && member_defn->property_is_randc(mv.member))
			precheck = Z3_L_FALSE;
	    }
	    for (auto& ev : builder.elem_vars)
		  if (rand_elem_active_(defn, cobj, prop_active,
					 ev.idx, ev.elem)
		      && defn->property_is_randc(ev.idx))
			precheck = Z3_L_FALSE;

	    if (precheck == Z3_L_TRUE && builder.dist_specs.empty()) {
		  // The candidate check included every active explicit `soft`
		  // assertion, so a true result proves the current values are
		  // already a highest-priority soft solution.
		  //
		  // RANDOM-DIST fix #2: also never fast-path when a `dist`
		  // is present.  A lucky pre-fill landing inside the dist's
		  // hard union used to be accepted as-is here regardless of
		  // the branch weights (silently skipping the whole
		  // diversity mechanism, dist's included) -- now z3_resolve_
		  // dist_exact below must run every time so the weights are
		  // actually honored.
		  Z3_solver_dec_ref(ctx, base);
		  Z3_optimize_dec_ref(ctx, opt);
		  Z3_del_context(ctx);
		  return Z3PASS_SAT_CURRENT;
	    }
      }

	// Resolve explicit soft constraints into the hard solution space in
	// reverse declaration order.  IEEE 1800-2017 18.5.14.1 defines a strict
	// priority, so each lower-priority expression is retained exactly when it
	// remains jointly feasible with the hard set and every higher-priority
	// soft expression already retained.  This is equivalent to the Optimize
	// groups above, while allowing the ordinary solver to enumerate and pin
	// the preferred solution space efficiently.
      for (size_t si = builder.pending_soft.size() ; si-- > 0 ; ) {
	    const auto& sa = builder.pending_soft[si];
	    if (!sa.from_soft_kw || soft_dropped(sa)) continue;
	    Z3_solver_push(ctx, base);
	    Z3_solver_assert(ctx, base, sa.a);
	    Z3_lbool feasible = Z3_solver_check(ctx, base);
	    Z3_solver_pop(ctx, base, 1);
	    if (feasible != Z3_L_TRUE) continue;
	    Z3_solver_assert(ctx, base, sa.a);
	    Z3_optimize_assert(ctx, opt, sa.a);
      }

	// solve...before staged solving (IEEE 1800-2017 18.5.10): rank
	// the ordered scalar properties/selected array elements/container sizes
	// by longest path in the before-graph,
	// then for each non-final rank solve the FULL hard-constraint
	// set with the diversity objective applied to that rank's
	// variables alone, and pin their solved values before the next
	// stage. The final rank (and all unordered variables) solve in
	// the normal combined pass below. Pins come from a complete
	// satisfying model, so they can never make later stages UNSAT. Size
	// targets are cached across the staged and combined passes: every size
	// consumes exactly one object-RNG word regardless of its ordering rank.
      std::map<unsigned,uint64_t> size_random_targets;
      auto size_random_target = [&](unsigned idx) -> uint64_t {
	    std::map<unsigned,uint64_t>::iterator found =
		  size_random_targets.find(idx);
	    if (found != size_random_targets.end()) return found->second;
	    uint64_t target = (uint64_t)(rng.next() & 0xF);
	    size_random_targets[idx] = target;
	    return target;
      };
      if (!builder.order_pairs.empty()) {
	    std::map<Z3Builder::OrderRef,unsigned> rank;
	    auto order_ref_active = [&](const Z3Builder::OrderRef&ref) -> bool {
		  if (ref.kind == Z3Builder::OrderRef::ELEM)
			return rand_elem_active_(defn, cobj, prop_active,
					 ref.idx, ref.elem);
		  if (ref.kind == Z3Builder::OrderRef::MEMBER)
			return rand_member_active_(defn, cobj, prop_active,
					   ref.idx, ref.elem);
		  return rand_active_(defn, cobj, prop_active, ref.idx);
	    };
	    for (const auto& pr : builder.order_pairs) {
		  rank[pr.first];
		  rank[pr.second];
	    }
	    bool changed = true;
	    size_t iter = 0;
	    const size_t iter_cap = rank.size() + 1;
	    while (changed && iter <= iter_cap) {
		  changed = false;
		  iter += 1;
		  for (const auto& pr : builder.order_pairs) {
			unsigned want = rank[pr.first] + 1;
			if (rank[pr.second] < want) {
			      rank[pr.second] = want;
			      changed = true;
			}
		  }
	    }
	    if (changed) {
		  static bool warned_cycle = false;
		  if (!warned_cycle) {
			fprintf(stderr, "Warning: cyclic solve...before"
				" ordering; directive ignored (further"
				" similar warnings suppressed)\n");
			warned_cycle = true;
		  }
	    } else {
		  unsigned max_rank = 0;
		  for (const auto& rv : rank)
			if (rv.second > max_rank) max_rank = rv.second;
		  for (unsigned r = 0 ; r < max_rank ; r += 1) {
			Z3_optimize_push(ctx, opt);
			for (const auto&ranked : rank) {
			      if (ranked.second != r) continue;
			      const Z3Builder::OrderRef&ref = ranked.first;
			      if (!order_ref_active(ref))
				    continue;
			      Z3_ast var = nullptr;
			      unsigned width = 0;
			      uint64_t rand_bits = 0;
			      if (ref.kind == Z3Builder::OrderRef::ELEM) {
				    for (auto&ev : builder.elem_vars)
					  if (ev.idx == ref.idx
					      && ev.elem == ref.elem) {
						var = ev.var;
						width = ev.width;
						break;
					  }
				    rand_bits = cobj_elem_bits(cobj, ref.idx,
							     ref.elem);
			      } else if (ref.kind == Z3Builder::OrderRef::MEMBER) {
				    for (auto&mv : builder.member_vars)
					  if (mv.outer == ref.idx
					      && mv.member == ref.elem) {
						var = mv.var;
						width = mv.width;
						break;
					  }
				    rand_bits = cobj_member_bits(cobj, ref.idx,
							       ref.elem);
			      } else if (ref.kind == Z3Builder::OrderRef::PROP) {
				    for (auto&pv : builder.prop_vars)
					  if (pv.idx == ref.idx) {
						var = pv.var;
						width = pv.width;
						break;
					  }
				    rand_bits = cobj_prop_bits(cobj, ref.idx);
			      } else {
				    for (auto&sv : builder.size_vars)
					  if (sv.idx == ref.idx) {
						var = sv.var;
						width = 32;
						break;
					  }
				    rand_bits = size_random_target(ref.idx);
			      }
			      if (!var || width == 0) continue;
			      Z3_sort sort = Z3_mk_bv_sort(ctx, width);
			      Z3_ast rv = Z3_mk_unsigned_int64(ctx, rand_bits, sort);
			      Z3_optimize_minimize(ctx, opt,
				    Z3_mk_bvxor(ctx, var, rv));
			}
			Z3_lbool st = Z3_optimize_check(ctx, opt, 0, nullptr);
			if (st != Z3_L_TRUE) {
			      Z3_optimize_pop(ctx, opt);
			      break;
			}
			Z3_model stage_model = Z3_optimize_get_model(ctx, opt);
			Z3_model_inc_ref(ctx, stage_model);
			std::vector<std::pair<Z3_ast,uint64_t> > pins;
			for (const auto&ranked : rank) {
			      if (ranked.second != r) continue;
			      const Z3Builder::OrderRef&ref = ranked.first;
			      if (!order_ref_active(ref))
				    continue;
			      Z3_ast var = nullptr;
			      if (ref.kind == Z3Builder::OrderRef::ELEM) {
				    for (auto&ev : builder.elem_vars)
					  if (ev.idx == ref.idx
					      && ev.elem == ref.elem) {
						var = ev.var;
						break;
					  }
			      } else if (ref.kind == Z3Builder::OrderRef::MEMBER) {
				    for (auto&mv : builder.member_vars)
					  if (mv.outer == ref.idx
					      && mv.member == ref.elem) {
						var = mv.var;
						break;
					  }
			      } else if (ref.kind == Z3Builder::OrderRef::PROP) {
				    for (auto&pv : builder.prop_vars)
					  if (pv.idx == ref.idx) {
						var = pv.var;
						break;
					  }
			      } else {
				    for (auto&sv : builder.size_vars)
					  if (sv.idx == ref.idx) {
						var = sv.var;
						break;
					  }
			      }
			      if (!var) continue;
			      Z3_ast interp = nullptr;
			      uint64_t bits = 0;
			      if (Z3_model_eval(ctx, stage_model, var, 1,
						&interp)
				  && interp
				  && Z3_get_numeral_uint64(ctx, interp, &bits))
				    pins.push_back(std::make_pair(var, bits));
			}
			Z3_model_dec_ref(ctx, stage_model);
			Z3_optimize_pop(ctx, opt);
			for (const auto& pin : pins) {
			      Z3_sort sort = Z3_get_sort(ctx, pin.first);
			      Z3_ast cv = Z3_mk_unsigned_int64(ctx, pin.second,
							       sort);
			      Z3_ast eq = Z3_mk_eq(ctx, pin.first, cv);
			      Z3_optimize_assert(ctx, opt, eq);
			      Z3_solver_assert(ctx, base, eq);
			}
		  }
	    }
      }

      // RANDOM-DIST fix #2 (18.5.4): resolve `dist` subjects that are a
      // plain rand property with an exact weighted draw (see
      // z3_resolve_dist_exact above) BEFORE the general per-property
      // diversity loop below, so a successfully-resolved property is
      // pinned (hard) rather than re-diversified there. A spec that can't
      // be resolved this way (not a plain property, or a branch range too
      // big to expand) is simply left alone: the pre-existing hard-union
      // constraint plus soft-weight preference asserted during IR parsing
      // still apply, so correctness never depends on this succeeding --
      // only true probability-proportional sampling does.
      // Explicit soft priorities have already been admitted greedily into
      // `base` above.  Exact enumeration therefore samples only from the
      // highest-priority preferred solution space instead of accidentally
      // discarding a soft preference.

      std::set<Z3_ast> dist_resolved_vars;
      for (const auto& spec : builder.dist_specs) {
	    bool active = false;
	    for (auto& pv : builder.prop_vars) {
		  if (pv.var == spec.subject) {
			active = rand_active_(defn, cobj, prop_active, pv.idx);
			break;
		  }
	    }
	    if (!active)
		  for (auto& mv : builder.member_vars)
			if (mv.var == spec.subject) {
			      active = rand_member_active_(defn, cobj, prop_active,
						  mv.outer, mv.member);
			      break;
			}
	    if (!active) continue;
	    if (dist_resolved_vars.count(spec.subject))
		  continue; // already resolved by an earlier dist spec on it
	    uint64_t chosen = 0;
	    if (z3_resolve_dist_exact(ctx, base, opt, spec, rng, chosen))
		  dist_resolved_vars.insert(spec.subject);
      }

      // RANDOM-DIST fix #1 (also serves #4, randc): for every remaining
      // rand scalar property, enumerate its actual feasible set (subject
      // to everything asserted on `base` so far, including the dist pins
      // above) when that set is cheap to enumerate, and choose an index
      // into it uniformly at random -- exact, regardless of how lopsided
      // or gap-ridden the feasible set is. A `randc` property draws from
      // its cyclic history over that SAME feasible set instead of a flat
      // random pick, restoring cycle-completeness for a constrained randc
      // (18.4.2) as long as the feasible set is enumerable; the property
      // may have been pre-filled by a cyclic pick over its FULL (pre-
      // constraint) domain in the vthread.cc fill loop, so any such mark
      // that turns out not to be the value actually emitted is retracted.
      //
      // Only when the property's own declared width makes enumeration too
      // expensive (ENUM_DOMAIN_CAP) does this fall back to the old
      // minimize(bvxor(prop, rand)) objective -- an approximation whose
      // bias is undocumented in the general case, but which this project
      // preserves rather than block on solving #P-hard exact sampling for
      // an arbitrary multi-variable constraint. A `randc` property that
      // falls back this way gets a loud one-time warning: its cycle-
      // completeness is not maintained.
	// Eligibility for the fast interval-based enumeration above: `pv`
	// must be the ONLY free variable anywhere in the hard-constraint
	// set built so far (see z3_enumerate_domain_single_var_fast_'s
	// comment for why). True exactly when there is exactly one rand
	// scalar property in play and no array elements/sizes at all --
	// the common shape (`rand bit[N:0] x; constraint { x inside {...}
	// }`) that dominates the performance-sensitive cases.
      bool single_var_fast_ok =
	    builder.prop_vars.size() + builder.member_vars.size() == 1
	    && builder.elem_vars.empty() && builder.size_vars.empty();

      for (auto& pv : builder.prop_vars) {
	    if (!rand_active_(defn, cobj, prop_active, pv.idx)) continue;
	    if (dist_resolved_vars.count(pv.var)) continue;

	    vector<uint64_t> feasible;
	    bool enumerated = false;
	    if (single_var_fast_ok)
		  enumerated = z3_enumerate_domain_single_var_fast_(
			ctx, base, pv.var, pv.width, feasible);
	    if (!enumerated)
		  enumerated = z3_enumerate_domain(ctx, base, pv.var,
						pv.width, feasible);
	    if (!enumerated)
		  enumerated = z3_enumerate_sparse_wide_domain_(
			ctx, base, pv.var, pv.width, feasible);
	    if (enumerated) {
		  uint64_t chosen;
		  if (defn->property_is_randc(pv.idx)) {
			uint64_t prefill = cobj_prop_bits(cobj, pv.idx);
			vector<uint64_t> available;
			for (uint64_t cand : feasible)
			      if (!cobj->randc_seen(pv.idx, cand))
				    available.push_back(cand);

			// If the constrained feasible subset is exhausted, selecting
			// from the whole subset stages its atomic reset at commit.
			// Otherwise choose uniformly among ONLY the remaining values;
			// random-start linear probing weights a value by the used run
			// before it and is not a uniform permutation.
			const vector<uint64_t>&pool = available.empty()
			      ? feasible : available;
			chosen = pool[rng.uniform_index(pool.size())];
			if (chosen != prefill)
			      cobj->randc_unmark(pv.idx, prefill);
			cobj->randc_mark_feasible(pv.idx, chosen, feasible);
		  } else {
			chosen = feasible[rng.uniform_index(feasible.size())];
		  }
		  Z3_sort sort = Z3_mk_bv_sort(ctx, pv.width);
		  Z3_ast cv = Z3_mk_unsigned_int64(ctx, chosen, sort);
		  Z3_ast eq = Z3_mk_eq(ctx, pv.var, cv);
		  Z3_optimize_assert(ctx, opt, eq);
		  Z3_solver_assert(ctx, base, eq);
		  continue;
	    }

	    if (defn->property_is_randc(pv.idx)) {
		  static bool warned_randc_wide = false;
		  if (!warned_randc_wide) {
			fprintf(stderr, "Warning: randc property with a "
				"constrained domain too large to enumerate "
				"exactly (width %u); cycle-completeness is "
				"not guaranteed for it (falling back to "
				"weighted-random diversity; further similar "
				"warnings suppressed).\n", pv.width);
			warned_randc_wide = true;
		  }
	    }

	    uint64_t rand_bits = cobj_prop_bits(cobj, pv.idx);
	    Z3_sort sort = Z3_mk_bv_sort(ctx, pv.width);
	    Z3_ast rv = Z3_mk_unsigned_int64(ctx, rand_bits, sort);
	    Z3_ast xor_expr = Z3_mk_bvxor(ctx, pv.var, rv);
	    Z3_optimize_minimize(ctx, opt, xor_expr);
      }

	// Unpacked-struct scalar leaves use the same exact feasible-domain
	// selection as direct scalar properties. Their randc history and mode
	// live on the nested value-object, while their RNG remains the owning
	// class object's stream.
      for (auto& mv : builder.member_vars) {
	    if (!rand_member_active_(defn, cobj, prop_active,
				     mv.outer, mv.member))
		  continue;
	    if (dist_resolved_vars.count(mv.var)) continue;
	    vvp_cobject*owner = cobj_struct_prop(cobj, mv.outer);
	    const class_type*member_defn = owner ? owner->get_defn() : nullptr;
	    if (!owner || !member_defn) continue;

	    vector<uint64_t> feasible;
	    bool enumerated = false;
	    if (single_var_fast_ok)
		  enumerated = z3_enumerate_domain_single_var_fast_(
			ctx, base, mv.var, mv.width, feasible);
	    if (!enumerated)
		  enumerated = z3_enumerate_domain(ctx, base, mv.var,
					   mv.width, feasible);
	    if (!enumerated)
		  enumerated = z3_enumerate_sparse_wide_domain_(
			ctx, base, mv.var, mv.width, feasible);
	    if (enumerated) {
		  uint64_t chosen;
		  if (member_defn->property_is_randc(mv.member)) {
			uint64_t prefill = cobj_member_bits(cobj, mv.outer,
						      mv.member);
			vector<uint64_t> available;
			for (uint64_t cand : feasible)
			      if (!owner->randc_seen(mv.member, cand))
				    available.push_back(cand);
			const vector<uint64_t>&pool = available.empty()
			      ? feasible : available;
			chosen = pool[rng.uniform_index(pool.size())];
			if (chosen != prefill)
			      owner->randc_unmark(mv.member, prefill);
			owner->randc_mark_feasible(mv.member, chosen, feasible);
		  } else {
			chosen = feasible[rng.uniform_index(feasible.size())];
		  }
		  Z3_sort sort = Z3_mk_bv_sort(ctx, mv.width);
		  Z3_ast cv = Z3_mk_unsigned_int64(ctx, chosen, sort);
		  Z3_ast eq = Z3_mk_eq(ctx, mv.var, cv);
		  Z3_optimize_assert(ctx, opt, eq);
		  Z3_solver_assert(ctx, base, eq);
		  continue;
	    }

	    if (member_defn->property_is_randc(mv.member)
		&& Z3_solver_check(ctx, base) == Z3_L_TRUE) {
		  static bool warned_member_randc_wide = false;
		  if (!warned_member_randc_wide) {
			fprintf(stderr, "Warning: unpacked-struct randc member "
				"has a constrained domain too large to enumerate "
				"exactly (width %u); cycle-completeness is not "
				"guaranteed (further similar warnings "
				"suppressed).\n", mv.width);
			warned_member_randc_wide = true;
		  }
	    }
	    uint64_t rand_bits = cobj_member_bits(cobj, mv.outer, mv.member);
	    Z3_sort sort = Z3_mk_bv_sort(ctx, mv.width);
	    Z3_ast rv = Z3_mk_unsigned_int64(ctx, rand_bits, sort);
	    Z3_optimize_minimize(ctx, opt, Z3_mk_bvxor(ctx, mv.var, rv));
      }
      for (auto& sv : builder.size_vars) {
	    if (!rand_active_(defn, cobj, prop_active, sv.idx)) continue;
	      // Prefer small varied sizes when the constraints leave slack.
	      // R3 (IEEE 1800-2017 18.13.1): draw from the OBJECT's own
	      // generator (always seeded, see of_NEW_COBJ), not libc rand(),
	      // so a dynamic-array rand property's size diversity is part of
	      // the same hierarchical, stable sequence as its other rand
	      // properties.
	    Z3_sort sort = Z3_mk_bv_sort(ctx, 32);
	    Z3_ast rv = Z3_mk_unsigned_int64(ctx,
		  size_random_target(sv.idx), sort);
	    Z3_optimize_minimize(ctx, opt, Z3_mk_bvxor(ctx, sv.var, rv));
      }

      bool single_elem_fast_ok = builder.elem_vars.size() == 1
	    && builder.prop_vars.empty() && builder.member_vars.empty()
	    && builder.size_vars.empty();
      for (auto& ev : builder.elem_vars) {
	    if (!rand_elem_active_(defn, cobj, prop_active, ev.idx, ev.elem))
		  continue;

	    const string&elem_base_type = defn->property_base_type(ev.idx);
	    bool container_randc = defn->property_is_randc(ev.idx)
		  && !elem_base_type.empty()
		  && (elem_base_type[0] == 'D' || elem_base_type[0] == 'Q'
		      || elem_base_type[0] == 'M');
	    bool element_randc = defn->property_is_randc(ev.idx)
		  && (defn->property_array_size(ev.idx) > 1
		      || container_randc);
	    if (element_randc) {
		  vector<uint64_t> feasible;
		  bool enumerated = false;
		  if (single_elem_fast_ok)
			enumerated = z3_enumerate_domain_single_var_fast_(
			      ctx, base, ev.var, ev.width, feasible);
		  if (!enumerated)
			enumerated = z3_enumerate_domain(ctx, base, ev.var,
					 ev.width, feasible);
		  if (!enumerated)
			enumerated = z3_enumerate_sparse_wide_domain_(
			      ctx, base, ev.var, ev.width, feasible);

		  if (enumerated) {
			uint64_t chosen;
			uint64_t prefill = cobj_elem_bits(cobj, ev.idx, ev.elem);
			vector<uint64_t> available;
			for (uint64_t candidate : feasible)
			      if (container_randc
				    ? !cobj->randc_container_seen(ev.idx, ev.elem,
							    candidate)
				    : !cobj->randc_seen(ev.idx, candidate,
						       ev.elem))
				    available.push_back(candidate);
			const vector<uint64_t>&pool = available.empty()
			      ? feasible : available;
			chosen = pool[rng.uniform_index(pool.size())];
			if (container_randc) {
			      if (chosen != prefill)
				    cobj->randc_container_unmark(ev.idx, ev.elem,
							   prefill);
			      cobj->randc_container_mark_feasible(ev.idx, ev.elem,
							 chosen, feasible);
			} else {
			      if (chosen != prefill)
				    cobj->randc_unmark(ev.idx, prefill, ev.elem);
			      cobj->randc_mark_feasible(ev.idx, chosen, feasible,
							  ev.elem);
			}
			Z3_sort sort = Z3_mk_bv_sort(ctx, ev.width);
			Z3_ast cv = Z3_mk_unsigned_int64(ctx, chosen, sort);
			Z3_ast eq = Z3_mk_eq(ctx, ev.var, cv);
			Z3_optimize_assert(ctx, opt, eq);
			Z3_solver_assert(ctx, base, eq);
			continue;
		  }

		  // An empty feasible set means the overall call is UNSAT, not
		  // that this randc domain exceeded the exact-enumeration bound.
		  // The normal solver failure below reports that result without a
		  // misleading cycle-completeness warning.
		  if (Z3_solver_check(ctx, base) == Z3_L_TRUE) {
			static bool warned_randc_array_wide = false;
			if (!warned_randc_array_wide) {
			      fprintf(stderr, "Warning: constrained randc unpacked-array "
				    "element domain could not be enumerated exactly "
				    "(width %u); cycle-completeness is not guaranteed "
				    "for it (further similar warnings suppressed).\n",
				    ev.width);
			      warned_randc_array_wide = true;
			}
		  }
	    }
	    uint64_t rand_bits = 0;
	    for (unsigned b = 0; b < ev.width && b < 64; ++b)
		  if (rng.next() & 1) rand_bits |= (1ULL << b);
	    Z3_sort sort = Z3_mk_bv_sort(ctx, ev.width);
	    Z3_ast rv = Z3_mk_unsigned_int64(ctx, rand_bits, sort);
	    Z3_optimize_minimize(ctx, opt, Z3_mk_bvxor(ctx, ev.var, rv));
      }

      if (z3_solve_trace(defn)) {
	    fprintf(stderr,
		    "trace z3-solve: check class=%s vars=%zu soft=%zu dist=%zu\n",
		    defn ? defn->class_name().c_str() : "<scope>",
		    builder.prop_vars.size() + builder.member_vars.size(),
		    builder.pending_soft.size(),
		    builder.dist_specs.size());
	    fflush(stderr);
      }
      Z3_lbool result = Z3_optimize_check(ctx, opt, 0, nullptr);
      if (z3_solve_trace(defn)) {
	    fprintf(stderr, "trace z3-solve: end class=%s result=%d\n",
		    defn ? defn->class_name().c_str() : "<scope>",
		    (int)result);
	    fflush(stderr);
      }
      if (result != Z3_L_TRUE) {
	    Z3_solver_dec_ref(ctx, base);
	    Z3_optimize_dec_ref(ctx, opt);
	    Z3_del_context(ctx);
	    if (result == Z3_L_FALSE)
		  return Z3PASS_FAILED;
	      // UNKNOWN cannot establish a legal solution. The caller treats
	      // it exactly like solve failure and rolls back both values and
	      // the enclosing randc history transaction.
	    static bool warned_undef = false;
	    if (!warned_undef) {
		  fprintf(stderr, "Warning: constraint solver returned "
			  "UNKNOWN; randomize fails and restores prior "
			  "random values (further similar warnings "
			  "suppressed).\n");
		  warned_undef = true;
	    }
	    return Z3PASS_FAILED;
      }

      Z3_model model = Z3_optimize_get_model(ctx, opt);
      Z3_model_inc_ref(ctx, model);

	// Evaluate every active struct leaf before mutating any of them. A model
	// that cannot produce one requested scalar is not a successful partial
	// write-back; return failure and let the enclosing graph transaction
	// restore all pre-filled values and histories together.
      struct member_write_t {
	    unsigned outer;
	    unsigned member;
	    unsigned width;
	    uint64_t bits;
      };
      vector<member_write_t> member_writes;
      for (auto& mv : builder.member_vars) {
	    if (!rand_member_active_(defn, cobj, prop_active,
				     mv.outer, mv.member))
		  continue;
	    uint64_t bits = 0;
	    if (!z3_eval_uint64(ctx, model, mv.var, bits)) {
		  Z3_model_dec_ref(ctx, model);
		  Z3_solver_dec_ref(ctx, base);
		  Z3_optimize_dec_ref(ctx, opt);
		  Z3_del_context(ctx);
		  return Z3PASS_FAILED;
	    }
	    member_write_t write = {mv.outer, mv.member, mv.width, bits};
	    member_writes.push_back(write);
      }

      for (auto& pv : builder.prop_vars) {
	    if (!rand_active_(defn, cobj, prop_active, pv.idx)) continue;
	    uint64_t bits = 0;
	    if (z3_eval_uint64(ctx, model, pv.var, bits)) {
		  cobj_set_prop_bits(cobj, pv.idx, bits);
		  if (z3_dyndbg())
			fprintf(stderr, "[z3dyn] prop  prop=%u width=%u "
				"bits=%llu\n", pv.idx, pv.width,
				(unsigned long long)bits);
	    }
      }
      for (const member_write_t&write : member_writes) {
	    cobj_set_member_bits(cobj, write.outer, write.member, write.bits);
	    if (z3_dyndbg())
		  fprintf(stderr, "[z3dyn] member outer=%u member=%u "
			  "width=%u bits=%llu\n", write.outer,
			  write.member, write.width,
			  (unsigned long long)write.bits);
      }

	// Apply solved dynamic-array/queue sizes: create (or replace) the
	// property's correctly typed container with the solved element count
	// and fill integral elements with random bits. Element constraints,
	// when present, overwrite specific entries below.
      auto choose_container_randc = [&rng](const std::vector<bool>*history,
	    unsigned width) -> uint64_t {
	    uint64_t period = (uint64_t)1 << width;
	    bool complete = history && history->size() == period;
	    if (complete)
		  for (size_t idx = 0 ; idx < history->size() ; idx += 1)
			if (!(*history)[idx]) { complete = false; break; }
	    if (!history || history->size() != period || complete)
		  return (uint64_t)rng.uniform_index((size_t)period);

	    size_t available = 0;
	    for (size_t idx = 0 ; idx < history->size() ; idx += 1)
		  if (!(*history)[idx]) available += 1;
	    if (available == 0)
		  return (uint64_t)rng.uniform_index((size_t)period);
	    size_t target = rng.uniform_index(available);
	    for (size_t idx = 0 ; idx < history->size() ; idx += 1) {
		  if ((*history)[idx]) continue;
		  if (target-- == 0) return (uint64_t)idx;
	    }
	    return 0;
      };

      for (auto& sv : builder.size_vars) {
	    if (!rand_active_(defn, cobj, prop_active, sv.idx)) continue;
	    uint64_t new_size = 0;
	    if (!z3_eval_uint64(ctx, model, sv.var, new_size))
		  continue;
	    uint64_t cap = random_container_size_cap_(sv.container_type);
	    if (new_size > cap) new_size = cap;

	    random_container_desc_t desc =
		  random_container_desc_(sv.container_type);
	    vvp_object_t old_obj;
	    cobj->get_object(sv.idx, old_obj, 0);
	    vvp_darray*old_array = old_obj.peek<vvp_darray>();
	    vvp_darray*da = make_random_container_(desc, (size_t)new_size);
	    bool is_randc = defn->property_is_randc(sv.idx);
	    if (desc.is_queue) {
		  vvp_queue*queue = dynamic_cast<vvp_queue*>(da);
		  unsigned queue_max = desc.max_size <= UINT_MAX
			? (unsigned)desc.max_size : 0;
		  for (uint64_t adr = 0 ; queue && adr < new_size ; adr += 1) {
			vvp_vector4_t nv(desc.elem_width, BIT4_0);
			bool active = rand_elem_active_(defn, cobj, prop_active,
						 sv.idx, (unsigned)adr);
			if (old_array && adr < old_array->get_size() && !active)
			      old_array->get_word((unsigned)adr, nv);
			else if (is_randc && desc.elem_width > 0
				 && desc.elem_width <= 20) {
			      const std::vector<bool>*history = old_array
				    && adr < old_array->get_size()
				    ? static_cast<const vvp_darray*>(old_array)
					  ->randc_history((size_t)adr) : 0;
			      uint64_t bits = choose_container_randc(history,
							       desc.elem_width);
			      for (unsigned b = 0 ; b < desc.elem_width ; b += 1)
				    nv.set_bit(b, (bits >> b) & 1
						   ? BIT4_1 : BIT4_0);
			} else
			      for (unsigned b = 0 ; b < desc.elem_width ; b += 1)
				    nv.set_bit(b, (rng.next() & 1)
						  ? BIT4_1 : BIT4_0);
			queue->set_word_max((unsigned)adr, nv, queue_max);
		  }
	    } else {
		  for (uint64_t adr = 0 ; adr < new_size ; adr += 1) {
			vvp_vector4_t word;
			da->get_word((unsigned)adr, word);
			unsigned wid = word.size();
			if (wid == 0) wid = 32;
			vvp_vector4_t nv(wid, BIT4_0);
			bool active = rand_elem_active_(defn, cobj, prop_active,
						 sv.idx, (unsigned)adr);
			if (old_array && adr < old_array->get_size() && !active)
			      old_array->get_word((unsigned)adr, nv);
			else if (is_randc && wid <= 20) {
			      const std::vector<bool>*history = old_array
				    && adr < old_array->get_size()
				    ? static_cast<const vvp_darray*>(old_array)
					  ->randc_history((size_t)adr) : 0;
			      uint64_t bits = choose_container_randc(history, wid);
			      for (unsigned b = 0 ; b < wid ; b += 1)
				    nv.set_bit(b, (bits >> b) & 1
						   ? BIT4_1 : BIT4_0);
			} else
			      for (unsigned b = 0 ; b < wid ; b += 1)
				    nv.set_bit(b, (rng.next() & 1)
						  ? BIT4_1 : BIT4_0);
			da->set_word((unsigned)adr, nv);
		  }
	    }
	    vvp_object_t obj(da);
	    if (old_array) da->inherit_randc_histories(*old_array);
	    cobj->set_object(sv.idx, obj, 0);
	    if (old_array) {
		  vvp_object_t stored;
		  cobj->get_object(sv.idx, stored, 0);
		  if (vvp_darray*stored_array = stored.peek<vvp_darray>())
			{
			      stored_array->inherit_rand_modes(*old_array);
			      stored_array->inherit_randc_histories(*old_array);
			}
	    }
	    if (is_randc) {
		  vvp_object_t stored;
		  cobj->get_object(sv.idx, stored, 0);
		  if (vvp_darray*stored_array = stored.peek<vvp_darray>())
			for (size_t adr = 0 ; adr < stored_array->get_size();
			     adr += 1) {
			      if (!rand_elem_active_(defn, cobj, prop_active,
						     sv.idx, (unsigned)adr))
				    continue;
			      bool modeled_element = false;
			      for (const auto&ev : builder.elem_vars)
				    if (ev.idx == sv.idx && ev.elem == adr) {
					  modeled_element = true;
					  break;
				    }
			      if (modeled_element) continue;
			      vvp_vector4_t value;
			      stored_array->get_word((unsigned)adr, value);
			      if (value.size() == 0 || value.size() > 20) continue;
			      uint64_t bits = 0;
			      for (unsigned bit = 0 ; bit < value.size() ; bit += 1)
				    if (value.value(bit) == BIT4_1)
					  bits |= (uint64_t)1 << bit;
			      cobj->randc_container_mark(sv.idx, adr, bits);
			}
	    }
      }

	// Apply solved array-element values.
      for (auto& ev : builder.elem_vars) {
	    if (!rand_elem_active_(defn, cobj, prop_active, ev.idx, ev.elem))
		  continue;
	    uint64_t bits = 0;
	    bool ev_ok = z3_eval_uint64(ctx, model, ev.var, bits);
	    if (ev_ok)
		  cobj_set_elem_bits(cobj, ev.idx, ev.elem, ev.width, bits);
	    if (z3_dyndbg())
		  fprintf(stderr, "[z3dyn] writeback prop=%u elem=%u width=%u "
			  "eval_ok=%d bits=%llu (post-write da_size=%llu)\n",
			  ev.idx, ev.elem, ev.width, ev_ok ? 1 : 0,
			  (unsigned long long)bits,
			  (unsigned long long)cobj_darray_size(cobj, ev.idx));
      }

      Z3_model_dec_ref(ctx, model);
      Z3_solver_dec_ref(ctx, base);
      Z3_optimize_dec_ref(ctx, opt);
      Z3_del_context(ctx);
      return Z3PASS_SAT_APPLIED;
}

bool vvp_z3_randomize(const class_type* defn, vvp_cobject* cobj,
                      const vector<string>& extra_ir,
                      const vector<uint64_t>& slot_vals,
                      const std::vector<bool>* prop_active,
                      bool include_class_constraints)
{
      if ((!include_class_constraints || defn->constraint_count() == 0)
	  && extra_ir.empty()) return true;

      z3_rng_stream_t rng(cobj);

	// Size pass: dynamic-foreach bodies deferred; sizes solved and
	// written back.
      std::vector<Z3Builder::DynForeach> dyn;
      int r1 = z3_solve_pass_(defn, cobj, rng, extra_ir, slot_vals,
			      nullptr, &dyn, prop_active,
			      include_class_constraints);
      if (dyn.empty())
	    return r1 != Z3PASS_FAILED;
	// A failed size pass has no valid size state to expand. Avoid a second
	// pass over its pre-filled/writeback remnants; the caller restores the
	// complete value snapshot and discards the randc transaction.
      if (r1 == Z3PASS_FAILED)
	    return false;

	// Element pass (IEEE 1800-2017 18.5.8.2): expand each foreach
	// to the now-current element count of its array and re-solve
	// everything with the sizes pinned. Scalar properties are
	// re-solved together with the elements (only the SIZE is
	// ordered before the iterative constraints).
      std::map<unsigned,uint64_t> sizes;
      for (const auto& d : dyn)
	    sizes[d.pidx] = cobj_darray_size(cobj, d.pidx);
	// Replay the size pass's RNG prefix. The object itself remains at the
	// furthest state already consumed; only new suffix words advance it.
      rng.rewind();
      int r2 = z3_solve_pass_(defn, cobj, rng, extra_ir, slot_vals,
			      &sizes, nullptr, prop_active,
			      include_class_constraints);
      return r2 != Z3PASS_FAILED;
}

bool vvp_z3_randomize_scope(const string&ir,
			    const vector<string>&targets,
			    const vector<unsigned>&widths,
			    const vector<uint64_t>&slot_vals,
			    const vector<vector<uint64_t> >&object_vals,
			    vector<string>&values)
{
      values.clear();
      if (targets.size() != widths.size())
	    return false;

      Z3_config cfg = Z3_mk_config();
      Z3_set_param_value(cfg, "model", "true");
      Z3_context ctx = Z3_mk_context(cfg);
      Z3_del_config(cfg);

      Z3Builder builder(ctx, nullptr, nullptr);
      Z3_optimize opt = Z3_mk_optimize(ctx);
      Z3_optimize_inc_ref(ctx, opt);
      builder.opt = opt;

      string sub = substitute_slots(ir, slot_vals);
      sub = substitute_scope_object_slots(sub, object_vals);
      Z3_ast assertion = parse_constraint_ir(sub, builder);
      if (z3_dyndbg()) {
	    fprintf(stderr, "Z3 scope IR: %s\n", sub.c_str());
	    fprintf(stderr, "Z3 scope hard: %s\n",
		    Z3_ast_to_string(ctx, assertion));
	    for (size_t i = 0 ; i < builder.pending_soft.size() ; i += 1)
		  fprintf(stderr, "Z3 scope soft[%zu]: %s\n", i,
			  Z3_ast_to_string(ctx, builder.pending_soft[i].a));
      }
      Z3_optimize_assert(ctx, opt, assertion);

	// Ensure even a variable absent from the constraint is represented:
	// every argument of std::randomize is randomized, not only those
	// named in the with-clause.
      for (unsigned idx = 0 ; idx < widths.size() ; idx += 1)
	    builder.get_prop_var(idx, widths[idx] ? widths[idx] : 32);

	// Reuse the class solver's soft/dist representation. Dist alternatives
	// share one weighted group; explicit soft constraints are separate,
	// reverse-priority groups (last declaration has highest priority).
      auto soft_dropped = [&](const Z3Builder::SoftAssert&sa) -> bool {
	    for (const Z3Builder::VarRef&ref : sa.refs)
		  if (builder.soft_ref_disabled(ref)) return true;
	    return false;
      };
      for (const auto&sa : builder.pending_soft) {
	    if (sa.from_soft_kw || soft_dropped(sa)) continue;
	    char weight[32];
	    snprintf(weight, sizeof(weight), "%u", sa.weight);
	    Z3_symbol grp = Z3_mk_string_symbol(ctx, "dist");
	    Z3_optimize_assert_soft(ctx, opt, sa.a, weight, grp);
      }
      for (size_t si = builder.pending_soft.size() ; si-- > 0 ; ) {
	    const auto&sa = builder.pending_soft[si];
	    if (!sa.from_soft_kw || soft_dropped(sa)) continue;
	    char weight[32], group[32];
	    snprintf(weight, sizeof(weight), "%u", sa.weight);
	    snprintf(group, sizeof(group), "soft%u", (unsigned)si);
	    Z3_optimize_assert_soft(ctx, opt, sa.a, weight,
				   Z3_mk_string_symbol(ctx, group));
      }

      auto binary_bv = [&](const string&bits) -> Z3_ast {
	    size_t pos = 0;
	    unsigned first = (unsigned)(bits.size() % 64);
	    if (first == 0) first = 64;
	    Z3_ast out = nullptr;
	    while (pos < bits.size()) {
		  unsigned take = pos == 0 ? first : 64;
		  uint64_t chunk = 0;
		  for (unsigned i = 0 ; i < take ; i += 1)
			chunk = (chunk << 1) | (bits[pos + i] == '1' ? 1 : 0);
		  Z3_ast atom = Z3_mk_unsigned_int64(ctx, chunk,
						 Z3_mk_bv_sort(ctx, take));
		  out = out ? Z3_mk_concat(ctx, out, atom) : atom;
		  pos += take;
	    }
	    return out;
      };

      for (auto&pv : builder.prop_vars) {
	    string target = pv.idx < targets.size() ? targets[pv.idx] : "0";
	    if (target.empty()) target = "0";
	    if (target.size() < pv.width)
		  target.insert(target.begin(), pv.width - target.size(), '0');
	    else if (target.size() > pv.width)
		  target.erase(0, target.size() - pv.width);
	    Z3_ast rv = binary_bv(target);
	    Z3_optimize_minimize(ctx, opt, Z3_mk_bvxor(ctx, pv.var, rv));
      }

      Z3_lbool result = Z3_optimize_check(ctx, opt, 0, nullptr);
      if (result == Z3_L_FALSE) {
	    Z3_optimize_dec_ref(ctx, opt);
	    Z3_del_context(ctx);
	    return false;
      }

      values = targets;
      if (result == Z3_L_TRUE) {
	    Z3_model model = Z3_optimize_get_model(ctx, opt);
	    Z3_model_inc_ref(ctx, model);
	    if (z3_dyndbg())
		  fprintf(stderr, "Z3 scope model: %s\n",
			  Z3_model_to_string(ctx, model));
	    for (auto&pv : builder.prop_vars) {
		  Z3_ast val = nullptr;
		  if (pv.idx < values.size()
		      && Z3_model_eval(ctx, model, pv.var, true, &val)) {
			const char*raw = Z3_get_numeral_binary_string(ctx, val);
			if (raw) {
			      string bits(raw);
			      if (bits.size() < pv.width)
				    bits.insert(bits.begin(), pv.width - bits.size(), '0');
			      else if (bits.size() > pv.width)
				    bits.erase(0, bits.size() - pv.width);
			      values[pv.idx] = bits;
			}
		  }
	    }
	    Z3_model_dec_ref(ctx, model);
      } else {
	    static bool warned_unknown = false;
	    if (!warned_unknown) {
		  fprintf(stderr, "Warning: scope randomization solver returned "
			  "UNKNOWN; unconstrained random targets are used "
			  "(further similar warnings suppressed).\n");
		  warned_unknown = true;
	    }
      }

      Z3_optimize_dec_ref(ctx, opt);
      Z3_del_context(ctx);
      return true;
}
