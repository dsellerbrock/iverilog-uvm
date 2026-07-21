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
# include  "vvp_darray.h"
# include  "vvp_z3.h"

# include  <z3.h>
# include  <z3_optimization.h>
# include  <cstdlib>
# include  <cstring>
# include  <sstream>
# include  <map>
# include  <set>
# include  <string>
# include  <vector>
# include  <stdint.h>

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
/* Structurally evaluate a GROUND bitvector term to uint64.
 *
 * The MSYS2/Windows Z3 build hands back model values like
 * `(bvneg #xffffff92)` — bvneg of a numeral, i.e. the correct value in an
 * unreduced wrapper — and fails to fold it in BOTH Z3_model_eval and
 * Z3_simplify (verified via the CI probe residue trace; Linux/macOS Z3
 * folds the same term to a numeral). So do the constant folding here for
 * the ground bitvector operators, masking each step to the term's width. */
static bool z3_ground_uint64(Z3_context ctx, Z3_ast t, uint64_t& out,
                             int depth = 0)
{
      if (Z3_get_numeral_uint64(ctx, t, &out))
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
      Z3_ast interp = var;
      for (int pass = 0 ; pass < 4 ; pass += 1) {
	    Z3_ast next = nullptr;
	    if (!(Z3_model_eval(ctx, model, interp, 1, &next) && next))
		  break;
	    next = Z3_simplify(ctx, next);
	    if (z3_ground_uint64(ctx, next, out))
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
	    fprintf(stderr, "[z3dyn] eval-fail var=<%s> residue=<%s>\n",
		    vs.c_str(), rs.c_str());
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
      struct SoftAssert { Z3_ast a; unsigned weight; bool from_soft_kw; };
      vector<SoftAssert> pending_soft;
      bool any_soft_kw_assert() const {
            for (const auto& s : pending_soft) if (s.from_soft_kw) return true;
            return false;
      }

	// Dynamic-array size variables ("s:N:T"): one 32-bit BV per
	// property index. T is the %new/darray type text used to create
	// the array at write-back (IEEE 1800-2017 18.4: the size of a
	// rand dynamic array is itself randomized subject to constraints).
      struct SizeVar {
	    unsigned idx;
	    string darray_type;
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
	    SizeVar sv; sv.idx = idx; sv.darray_type = dtype; sv.var = var;
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

	// solve...before ordering pairs (IEEE 1800-2017 18.5.10):
	// (first, second) means property `first` is solved in an
	// earlier stage than property `second`. Collected from
	// "(order (vars ...) (vars ...))" IR forms; drives the staged
	// solve in z3_solve_pass_.
      std::vector<std::pair<unsigned,unsigned> > order_pairs;

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

      // Build a Z3 boolean from "1" (true) or "0" (false)
      Z3_ast mk_true()  { return Z3_mk_true(ctx); }
      Z3_ast mk_false() { return Z3_mk_false(ctx); }
};

// Forward declaration
static Z3_ast build_z3_expr(IRParser&, Z3Builder&);

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
      Z3_ast var = b.get_prop_var(idx, width);
      if (sflag) b.signed_vars.insert(var);
      return var;
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
static bool eval_const_ir(IRParser& par, uint64_t& out)
{
      par.skip_ws();
      if (par.peek() == '(') {
	    par.consume();
	    string op = par.read_token();
	    uint64_t a = 0, b = 0;
	    if (!eval_const_ir(par, a)) return false;
	    if (!eval_const_ir(par, b)) return false;
	    par.skip_ws();
	    if (!par.expect(')')) return false;
	    if (op == "add") out = a + b;
	    else if (op == "sub") out = a - b;
	    else if (op == "mul") out = a * b;
	    else if (op == "div") out = b ? a / b : 0;
	    else if (op == "mod") out = b ? a % b : 0;
	    else return false;
	    return true;
      }
      string tok = par.read_token();
      if (tok.compare(0, 2, "c:") != 0) return false;
      out = (uint64_t)strtoull(tok.c_str() + 2, nullptr, 10);
      return true;
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
      if (tok.substr(0,2) == "s:") {
	      // s:N:T — size of dynamic-array property N, darray type T.
	    const char*s = tok.c_str() + 2;
	    unsigned idx = (unsigned)atoi(s);
	    while (*s && *s != ':') ++s;
	    string dtype = (*s == ':') ? string(s + 1) : string("v32");
	    return b.get_size_var(idx, dtype);
      }
      if (tok.substr(0,2) == "e:") {
	      // e:N:W:I[:s] — element I of array property N, width W.
	    const char*s = tok.c_str() + 2;
	    unsigned idx = (unsigned)atoi(s);
	    while (*s && *s != ':') ++s;
	    unsigned width = 32;
	    if (*s == ':') { width = (unsigned)atoi(s + 1); ++s; }
	    while (*s && *s != ':') ++s;
	    unsigned elem = 0;
	    if (*s == ':') { elem = (unsigned)atoi(s + 1); ++s; }
	    while (*s && *s != ':') ++s;
	    bool sflag = (*s == ':' && s[1] == 's');
	    Z3_ast var = b.get_elem_var(idx, width, elem);
	    if (sflag) b.signed_vars.insert(var);
	    return var;
      }
      return b.mk_true();
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

	/* Variable-ordering directive: (order (vars p:..) (vars p:..)).
	 * Registers the properties (so they become solver variables
	 * even if otherwise unconstrained) and records every
	 * before-var x after-var pair. Contributes `true` — ordering
	 * affects distribution, not satisfiability (18.5.10). */
      if (op == "order") {
	    std::vector<unsigned> groups[2];
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
			      groups[g].push_back(
				    (unsigned)atoi(tok.c_str() + 2));
			}
		  }
	    }
	    par.skip_ws(); par.expect(')');
	    for (unsigned a : groups[0])
		  for (unsigned c : groups[1])
			b.order_pairs.push_back(std::make_pair(a, c));
	    return b.mk_true();
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
	    Z3_ast right = bv_to_bool(b.ctx, build_z3_atom(par, b));
	    par.skip_ws(); par.expect(')');
	    if (op == "impl")
		  return Z3_mk_implies(b.ctx, left, right);
	    return Z3_mk_iff(b.ctx, left, right);
      }

      /* Bitvector arithmetic. Widths are harmonized by zero-extension
       * (same policy as the comparisons below). */
      if (op == "add" || op == "sub" || op == "mul"
	  || op == "div" || op == "mod") {
	    Z3_ast left  = build_z3_atom(par, b);
	    Z3_ast right = build_z3_atom(par, b);
	    par.skip_ws(); par.expect(')');

	    unsigned lw = bv_width(b.ctx, left);
	    unsigned rw = bv_width(b.ctx, right);
	    if (lw != rw) {
		  if (rw < lw)
			right = Z3_mk_zero_ext(b.ctx, lw - rw, right);
		  else
			left = Z3_mk_zero_ext(b.ctx, rw - lw, left);
	    }

	    if (op == "add") return Z3_mk_bvadd(b.ctx, left, right);
	    if (op == "sub") return Z3_mk_bvsub(b.ctx, left, right);
	    if (op == "mul") return Z3_mk_bvmul(b.ctx, left, right);
	    if (op == "div") return Z3_mk_bvudiv(b.ctx, left, right);
	    return Z3_mk_bvurem(b.ctx, left, right);
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

	      // A signed variable on either side selects signed compare
	      // semantics (IEEE 1800-2017 11.8.1; bare integer literals
	      // are themselves signed).
	    bool use_signed = b.is_signed(left) || b.is_signed(right);

	    // Make sure both sides have the same BV width
	    unsigned lw = bv_width(b.ctx, left);
	    unsigned rw = bv_width(b.ctx, right);
	    if (lw != rw) {
		  if (rw < lw) {
			right = use_signed
			      ? Z3_mk_sign_ext(b.ctx, lw - rw, right)
			      : Z3_mk_zero_ext(b.ctx, lw - rw, right);
		  } else {
			left = use_signed
			      ? Z3_mk_sign_ext(b.ctx, rw - lw, left)
			      : Z3_mk_zero_ext(b.ctx, rw - lw, left);
		  }
	    }

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
	    unsigned sw = bv_width(b.ctx, subject);
	      // A signed subject selects signed range semantics
	      // (IEEE 1800-2017 11.4.13, 11.8.1).
	    bool subj_signed = b.is_signed(subject);

	    // Match an atom's width to the subject for the comparisons.
	    auto match_width = [&](Z3_ast a) -> Z3_ast {
		  unsigned aw = bv_width(b.ctx, a);
		  if (aw < sw) return subj_signed
			? Z3_mk_sign_ext(b.ctx, sw - aw, a)
			: Z3_mk_zero_ext(b.ctx, sw - aw, a);
		  if (aw > sw) return Z3_mk_extract(b.ctx, sw - 1, 0, a);
		  return a;
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
			Z3_ast lo = match_width(build_z3_atom(par, b));
			par.expect(',');
			Z3_ast hi = match_width(build_z3_atom(par, b));
			par.expect(']');
			// subject >= lo && subject <= hi
			Z3_ast c1 = range_ge(subject, lo);
			Z3_ast c2 = range_le(subject, hi);
			Z3_ast both[2] = {c1, c2};
			clauses.push_back(Z3_mk_and(b.ctx, 2, both));
		  } else if (par.peek() == '(') {
			Z3_ast v = match_width(build_z3_atom(par, b));
			clauses.push_back(Z3_mk_eq(b.ctx, subject, v));
		  } else {
			// Single value token
			string tok = par.read_token();
			if (tok.substr(0,2) == "c:") {
			      uint64_t v = strtoull(tok.c_str()+2, nullptr, 10);
			      Z3_ast cv = Z3_mk_unsigned_int64(b.ctx, v,
						      Z3_mk_bv_sort(b.ctx, sw));
			      clauses.push_back(Z3_mk_eq(b.ctx, subject, cv));
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
	    Z3_ast inner = bv_to_bool(b.ctx, build_z3_atom(par, b));
	    par.skip_ws();
	    par.expect(')');
	    Z3Builder::SoftAssert sa = { inner, 256, true /* from_soft_kw */ };
	    b.pending_soft.push_back(sa);
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
	    unsigned sw = bv_width(b.ctx, subject);

	    vector<Z3_ast> hard_clauses;
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
		  string w_tok = par.read_token();
		  unsigned weight = 1;
		  if (!w_tok.empty()) {
			weight = (unsigned)strtoul(w_tok.c_str()+
				    (w_tok.substr(0,2)=="c:" ? 2 : 0), 0, 10);
			if (weight == 0) weight = 1;
		  }
		  Z3_ast clause = b.mk_false();
		  par.skip_ws();
		  if (par.peek() == '[') {
			par.consume();
			string lo_tok = par.read_token();
			par.expect(',');
			string hi_tok = par.read_token();
			par.expect(']');
			uint64_t lo_v = strtoull(lo_tok.c_str()+2, 0, 10);
			uint64_t hi_v = strtoull(hi_tok.c_str()+2, 0, 10);
			Z3_ast lo = Z3_mk_unsigned_int64(b.ctx, lo_v,
					 Z3_mk_bv_sort(b.ctx, sw));
			Z3_ast hi = Z3_mk_unsigned_int64(b.ctx, hi_v,
					 Z3_mk_bv_sort(b.ctx, sw));
			Z3_ast c1 = Z3_mk_bvuge(b.ctx, subject, lo);
			Z3_ast c2 = Z3_mk_bvule(b.ctx, subject, hi);
			Z3_ast both[2] = {c1, c2};
			clause = Z3_mk_and(b.ctx, 2, both);
		  } else {
			string tok = par.read_token();
			if (tok.substr(0,2) == "c:") {
			      uint64_t v = strtoull(tok.c_str()+2, 0, 10);
			      Z3_ast cv = Z3_mk_unsigned_int64(b.ctx, v,
					      Z3_mk_bv_sort(b.ctx, sw));
			      clause = Z3_mk_eq(b.ctx, subject, cv);
			}
		  }
		  par.skip_ws();
		  par.expect(')'); // close (b ...)
		  par.skip_ws();
		  hard_clauses.push_back(clause);
		  // Queue the soft assert; caller applies it after build.
		  Z3Builder::SoftAssert sa = { clause, weight, false /* dist */ };
		  b.pending_soft.push_back(sa);
	    }
	    par.expect(')');
	    if (hard_clauses.empty()) return b.mk_true();
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
      return 0;
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

/* One solve pass. dyn_sizes null: dynamic-foreach templates are
 * collected (returned via dyn_out) and contribute `true`; sizes are
 * free subject to their constraints. dyn_sizes set: templates expand
 * to the given element counts and every size variable is pinned to
 * the array's current (pass-1-written) size, implementing the
 * IEEE 1800-2017 18.5.8.2 size-before-iterative-constraints order. */
static bool z3_solve_pass_(const class_type* defn, vvp_cobject* cobj,
                      const vector<string>& extra_ir,
                      const vector<uint64_t>& slot_vals,
                      const std::map<unsigned,uint64_t>* dyn_sizes,
                      std::vector<Z3Builder::DynForeach>* dyn_out)
{
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
      if (dyn_out)
	    *dyn_out = builder.dyn_foreach;
      // Dynamic-array size variables are bounded by a pragmatic hard cap
      // so an under-constrained `arr.size() > k` cannot demand a huge
      // allocation. (IEEE places no bound; this is an implementation
      // limit, matching typical simulator behavior.)
      for (auto& sv : builder.size_vars) {
	    Z3_sort s32 = Z3_mk_bv_sort(ctx, 32);
	    Z3_ast cap = Z3_mk_unsigned_int64(ctx, 65536, s32);
	    Z3_optimize_assert(ctx, opt, Z3_mk_bvule(ctx, sv.var, cap));
      }
      // Element pass: sizes were solved (and written back) in the size
      // pass — pin them so the re-solve cannot move them.
      if (dyn_sizes) {
	    for (auto& sv : builder.size_vars) {
		  Z3_sort s32 = Z3_mk_bv_sort(ctx, 32);
		  Z3_ast cur = Z3_mk_unsigned_int64(ctx,
			cobj_darray_size(cobj, sv.idx), s32);
		  Z3_optimize_assert(ctx, opt, Z3_mk_eq(ctx, sv.var, cur));
	    }
      }

      // C7: apply queued soft asserts from dist branches.  Each carries a
      // weight; Z3_optimize_assert_soft prefers higher-weight branches when
      // multiple feasible solutions exist.
      for (const auto& sa : builder.pending_soft) {
	    char w_str[32];
	    snprintf(w_str, sizeof(w_str), "%u", sa.weight);
	    Z3_symbol grp = Z3_mk_string_symbol(ctx, "dist");
	    Z3_optimize_assert_soft(ctx, opt, sa.a, w_str, grp);
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

	    if (precheck == Z3_L_TRUE && !builder.any_soft_kw_assert()) {
		  // C7/I4: only fast-path early-out when there are no
		  // `soft`-keyword assertions queued.  Dist branches use the
		  // soft-assert mechanism but rely on the bvxor diversity
		  // minimize for probabilistic outcome — early-return is OK
		  // for dist (random pre-fill provides the diversity).  Plain
		  // `soft` is deterministic preference and must always run
		  // the optimize check.
		  Z3_optimize_dec_ref(ctx, opt);
		  Z3_del_context(ctx);
		  return false;
	    }
      }

	// solve...before staged solving (IEEE 1800-2017 18.5.10): rank
	// the ordered properties by longest path in the before-graph,
	// then for each non-final rank solve the FULL hard-constraint
	// set with the diversity objective applied to that rank's
	// variables alone, and pin their solved values before the next
	// stage. The final rank (and all unordered variables) solve in
	// the normal combined pass below. Pins come from a complete
	// satisfying model, so they can never make later stages UNSAT.
      if (!builder.order_pairs.empty()) {
	    std::map<unsigned,unsigned> rank;
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
			for (auto& pv : builder.prop_vars) {
			      auto it = rank.find(pv.idx);
			      if (it == rank.end() || it->second != r)
				    continue;
			      uint64_t rand_bits = cobj_prop_bits(cobj, pv.idx);
			      Z3_sort sort = Z3_mk_bv_sort(ctx, pv.width);
			      Z3_ast rv = Z3_mk_unsigned_int64(ctx, rand_bits, sort);
			      Z3_optimize_minimize(ctx, opt,
				    Z3_mk_bvxor(ctx, pv.var, rv));
			}
			Z3_lbool st = Z3_optimize_check(ctx, opt, 0, nullptr);
			if (st != Z3_L_TRUE) {
			      Z3_optimize_pop(ctx, opt);
			      break;
			}
			Z3_model stage_model = Z3_optimize_get_model(ctx, opt);
			Z3_model_inc_ref(ctx, stage_model);
			std::vector<std::pair<Z3_ast,uint64_t> > pins;
			for (auto& pv : builder.prop_vars) {
			      auto it = rank.find(pv.idx);
			      if (it == rank.end() || it->second != r)
				    continue;
			      Z3_ast interp = nullptr;
			      uint64_t bits = 0;
			      if (Z3_model_eval(ctx, stage_model, pv.var, 1,
						&interp)
				  && interp
				  && Z3_get_numeral_uint64(ctx, interp, &bits))
				    pins.push_back(std::make_pair(pv.var, bits));
			}
			Z3_model_dec_ref(ctx, stage_model);
			Z3_optimize_pop(ctx, opt);
			for (const auto& pin : pins) {
			      Z3_sort sort = Z3_get_sort(ctx, pin.first);
			      Z3_ast cv = Z3_mk_unsigned_int64(ctx, pin.second,
							       sort);
			      Z3_optimize_assert(ctx, opt,
				    Z3_mk_eq(ctx, pin.first, cv));
			}
		  }
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
      for (auto& sv : builder.size_vars) {
	      // Prefer small varied sizes when the constraints leave slack.
	    Z3_sort sort = Z3_mk_bv_sort(ctx, 32);
	    Z3_ast rv = Z3_mk_unsigned_int64(ctx, (uint64_t)(rand() & 0xF), sort);
	    Z3_optimize_minimize(ctx, opt, Z3_mk_bvxor(ctx, sv.var, rv));
      }
      for (auto& ev : builder.elem_vars) {
	    uint64_t rand_bits = 0;
	    for (unsigned b = 0; b < ev.width && b < 64; ++b)
		  if (rand() & 1) rand_bits |= (1ULL << b);
	    Z3_sort sort = Z3_mk_bv_sort(ctx, ev.width);
	    Z3_ast rv = Z3_mk_unsigned_int64(ctx, rand_bits, sort);
	    Z3_optimize_minimize(ctx, opt, Z3_mk_bvxor(ctx, ev.var, rv));
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
	    uint64_t bits = 0;
	    if (z3_eval_uint64(ctx, model, pv.var, bits)) {
		  cobj_set_prop_bits(cobj, pv.idx, bits);
		  if (z3_dyndbg())
			fprintf(stderr, "[z3dyn] prop  prop=%u width=%u "
				"bits=%llu\n", pv.idx, pv.width,
				(unsigned long long)bits);
	    }
      }

	// Apply solved dynamic-array sizes: create (or replace) the
	// property's darray with the solved element count and fill the
	// elements with random bits. Element constraints, when present,
	// overwrite specific entries below.
      for (auto& sv : builder.size_vars) {
	    uint64_t new_size = 0;
	    if (!z3_eval_uint64(ctx, model, sv.var, new_size))
		  continue;
	    if (new_size > 65536) new_size = 65536;

	    vvp_darray*da = make_darray_for_type(sv.darray_type,
						 (size_t)new_size);
	    for (uint64_t adr = 0 ; adr < new_size ; adr += 1) {
		  vvp_vector4_t word;
		  da->get_word((unsigned)adr, word);
		  unsigned wid = word.size();
		  if (wid == 0) wid = 32;
		  vvp_vector4_t nv(wid, BIT4_0);
		  for (unsigned b = 0 ; b < wid ; b += 1)
			nv.set_bit(b, (rand() & 1) ? BIT4_1 : BIT4_0);
		  da->set_word((unsigned)adr, nv);
	    }
	    vvp_object_t obj(da);
	    cobj->set_object(sv.idx, obj, 0);
      }

	// Apply solved array-element values.
      for (auto& ev : builder.elem_vars) {
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
      Z3_optimize_dec_ref(ctx, opt);
      Z3_del_context(ctx);
      return true;
}

bool vvp_z3_randomize(const class_type* defn, vvp_cobject* cobj,
                      const vector<string>& extra_ir,
                      const vector<uint64_t>& slot_vals)
{
      if (defn->constraint_count() == 0 && extra_ir.empty()) return false;

	// Size pass: dynamic-foreach bodies deferred; sizes solved and
	// written back.
      std::vector<Z3Builder::DynForeach> dyn;
      bool r1 = z3_solve_pass_(defn, cobj, extra_ir, slot_vals,
			       nullptr, &dyn);
      if (dyn.empty())
	    return r1;

	// Element pass (IEEE 1800-2017 18.5.8.2): expand each foreach
	// to the now-current element count of its array and re-solve
	// everything with the sizes pinned. Scalar properties are
	// re-solved together with the elements (only the SIZE is
	// ordered before the iterative constraints).
      std::map<unsigned,uint64_t> sizes;
      for (const auto& d : dyn)
	    sizes[d.pidx] = cobj_darray_size(cobj, d.pidx);
      bool r2 = z3_solve_pass_(defn, cobj, extra_ir, slot_vals,
			       &sizes, nullptr);
      return r1 || r2;
}
