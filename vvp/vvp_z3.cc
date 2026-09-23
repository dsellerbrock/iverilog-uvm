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
 *   (cast c:W c:S expr)  -- integral cast; W=0 inherits expression width,
 *                            S=0 unsigned, S=1 signed, S=2 inherits sign
 *   (trunc:W[:s] expr)   -- self-determined W-bit integral result
 *   (inside p:N:W [c:lo,c:hi] c:val ...) -- prop[N] inside ranges/values
 *   (dist expr (b MODE W item) ...) -- weighted distribution; MODE is
 *                                      `:=' (per range member) or `:/'
 *                                      (one aggregate range weight)
 *     Historical `(b W item)' branches remain accepted. An unmarked range
 *     has the old runtime meaning `:/'; MODE is immaterial for a scalar.
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
# include  <algorithm>
# include  <functional>
# include  <memory>

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

static bool z3_eval_vec4_(Z3_context ctx, Z3_model model, Z3_ast var,
                          vvp_vector4_t&out)
{
      Z3_sort sort = Z3_get_sort(ctx, var);
      if (Z3_get_sort_kind(ctx, sort) != Z3_BV_SORT) return false;
      unsigned width = Z3_get_bv_sort_size(ctx, sort);
      if (width == 0) return false;
      Z3_ast value = nullptr;
      if (!Z3_model_eval(ctx, model, var, 1, &value) || !value) return false;
      value = Z3_simplify(ctx, value);
      out = vvp_vector4_t(width, BIT4_0);
      for (unsigned low = 0; low < width; low += 64) {
            unsigned high = min(width - 1, low + 63);
            Z3_ast chunk = Z3_simplify(ctx,
                  Z3_mk_extract(ctx, high, low, value));
            uint64_t bits = 0;
            if (!z3_ground_uint64(ctx, chunk, bits)
                && !z3_str_ground_uint64(ctx, chunk, high - low + 1, bits))
                  return false;
            for (unsigned bit = low; bit <= high; ++bit)
                  out.set_bit(bit, (bits >> (bit - low)) & 1
                                    ? BIT4_1 : BIT4_0);
      }
      return true;
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

struct constraint_integral_type_t {
      unsigned width = 0;
      bool sign = false;
};

static bool infer_constraint_integral_type_(
      IRParser&par, constraint_integral_type_t&out);
static bool infer_constraint_inside_type_(
      IRParser&par, constraint_integral_type_t&out);

static bool constraint_ir_uint_token_(const string&token, uint64_t&value)
{
      if (token.compare(0, 2, "c:") != 0) return false;
      char*end = nullptr;
      value = strtoull(token.c_str() + 2, &end, 10);
      return end && (*end == 0 || *end == ':');
}

static bool constraint_ir_header_type_(const string&token,
                                        constraint_integral_type_t&out)
{
      vector<string> fields;
      string part;
      istringstream input(token);
      while (getline(input, part, ':')) fields.push_back(part);
      if (fields.empty()) return false;
      if (fields[0] == "s") {
            out.width = 32;
            out.sign = true; // size() returns int; alias in typed value pass
            return true;
      }
      bool sign = fields.back() == "s";
      size_t count = fields.size() - (sign ? 1 : 0);
      size_t width_field = 0;
      if (fields[0] == "p" || fields[0] == "g" || fields[0] == "v")
            width_field = 2;
      else if (fields[0] == "m" || fields[0] == "a") width_field = 3;
      else if (fields[0] == "e") width_field = 2;
      else if (fields[0] == "r" || fields[0] == "pp")
            width_field = count - 1;
      else return false;
      if (width_field >= count) return false;
      char*end = nullptr;
      unsigned long width = strtoul(fields[width_field].c_str(), &end, 10);
      if (end == fields[width_field].c_str() || *end || !width
          || width > UINT_MAX) return false;
      out.width = (unsigned)width;
      out.sign = sign;
      return true;
}

static bool infer_constraint_integral_type_(IRParser&par,
                                             constraint_integral_type_t&out)
{
      par.skip_ws();
      if (par.peek() != '(') {
            string token = par.read_token();
            if (token.compare(0, 2, "c:") == 0) {
                  const char*text = token.c_str() + 2;
                  char*end = nullptr;
                  (void)strtoull(text, &end, 10);
                  out.width = 32; out.sign = false;
                  if (end && *end == ':') {
                        unsigned long width = strtoul(end + 1, &end, 10);
                        if (!width || width > UINT_MAX) return false;
                        out.width = (unsigned)width;
                        out.sign = end && *end == ':' && end[1] == 's'
                              && end[2] == 0;
                        if (end && *end && !out.sign) return false;
                  }
                  return true;
            }
            return constraint_ir_header_type_(token, out);
      }
      par.consume();
      string op = par.read_token();
      if (op == "cast") {
            uint64_t width = 0, sign = 0;
            if (!constraint_ir_uint_token_(par.read_token(), width)
                || !constraint_ir_uint_token_(par.read_token(), sign)
                || width > UINT_MAX || sign > 2
                || !infer_constraint_integral_type_(par, out)
                || !par.expect(')')) return false;
            if (width) out.width = (unsigned)width;
            if (sign != 2) out.sign = sign == 1;
            return out.width != 0;
      }
      if (op.compare(0, 6, "trunc:") == 0) {
            const char*spec = op.c_str() + 6;
            char*end = nullptr;
            unsigned long width = strtoul(spec, &end, 10);
            constraint_integral_type_t ignored;
            if (!width || width > UINT_MAX
                || !infer_constraint_integral_type_(par, ignored)
                || !par.expect(')')) return false;
            out.width = (unsigned)width;
            out.sign = end && *end == ':' && end[1] == 's';
            return true;
      }
      if (op == "neg" || op == "bnot") {
            return infer_constraint_integral_type_(par, out) && par.expect(')');
      }
      if (op == "not" || op == "redand" || op == "redor"
          || op == "redxor" || op == "onehot" || op == "onehot0"
          || op == "countones") {
            constraint_integral_type_t ignored;
            if (!infer_constraint_integral_type_(par, ignored)
                || !par.expect(')')) return false;
            out.width = op == "countones" ? 32 : 1;
            out.sign = op == "countones";
            return true;
      }
      if (op == "add" || op == "sub" || op == "mul" || op == "div"
          || op == "mod" || op == "band" || op == "bor" || op == "bxor") {
            constraint_integral_type_t left, right;
            if (!infer_constraint_integral_type_(par, left)
                || !infer_constraint_integral_type_(par, right)
                || !par.expect(')')) return false;
            out.width = max(left.width, right.width);
            out.sign = left.sign && right.sign;
            return out.width != 0;
      }
      if (op == "shl" || op == "lshr" || op == "ashr" || op == "pow") {
            constraint_integral_type_t left, right;
            if (!infer_constraint_integral_type_(par, left)
                || !infer_constraint_integral_type_(par, right)
                || !par.expect(')')) return false;
            out = left; return out.width != 0;
      }
      if (op == "lt" || op == "le" || op == "gt" || op == "ge"
          || op == "eq" || op == "ne" || op == "and" || op == "or"
          || op == "impl" || op == "iff") {
            constraint_integral_type_t left, right;
            if (!infer_constraint_integral_type_(par, left)
                || !infer_constraint_integral_type_(par, right)
                || !par.expect(')')) return false;
            out.width = 1; out.sign = false; return true;
      }
      if (op == "ite") {
            constraint_integral_type_t condition, yes, no;
            if (!infer_constraint_integral_type_(par, condition)
                || !infer_constraint_integral_type_(par, yes)
                || !infer_constraint_integral_type_(par, no)
                || !par.expect(')')) return false;
            out.width = max(yes.width, no.width);
            out.sign = yes.sign && no.sign;
            return out.width != 0;
      }
      if (op == "bit") {
            constraint_integral_type_t base, index;
            if (!infer_constraint_integral_type_(par, base)
                || !infer_constraint_integral_type_(par, index)
                || !par.expect(')')) return false;
            out.width = 1; out.sign = false; return true;
      }
      if (op == "part") {
            constraint_integral_type_t base;
            uint64_t hi = 0, lo = 0;
            if (!infer_constraint_integral_type_(par, base)
                || !constraint_ir_uint_token_(par.read_token(), hi)
                || !constraint_ir_uint_token_(par.read_token(), lo)
                || hi < lo || hi - lo >= UINT_MAX || !par.expect(')'))
                  return false;
            out.width = (unsigned)(hi - lo + 1); out.sign = false; return true;
      }
      if (op == "concat") {
            out.width = 0; out.sign = false;
            while (par.peek() && par.peek() != ')') {
                  constraint_integral_type_t item;
                  if (!infer_constraint_integral_type_(par, item)
                      || item.width > UINT_MAX - out.width) return false;
                  out.width += item.width;
            }
            return out.width && par.expect(')');
      }
      if (op == "fsel" || op == "delem" || op == "qmelem"
          || op == "qfield" || op == "qkeymember" || op == "hselectfield") {
            string header = par.read_token();
            vector<string> fields;
            string field;
            istringstream input(header);
            while (getline(input, field, ':')) fields.push_back(field);
            bool sign = !fields.empty() && fields.back() == "s";
            size_t n = fields.size() - (sign ? 1 : 0);
            size_t wi = op == "qmelem" ? 2 : op == "hselectfield" ? 1
                  : op == "qfield" ? 3 : 1;
            if (wi >= n) return false;
            char*end = nullptr;
            unsigned long width = strtoul(fields[wi].c_str(), &end, 10);
            if (end == fields[wi].c_str() || *end || !width
                || width > UINT_MAX) return false;
            int depth = 0;
            while (*par.p) {
                  char c = *par.p++;
                  if (c == '(') ++depth;
                  else if (c == ')' && depth-- == 0) break;
            }
            out.width = (unsigned)width; out.sign = sign; return true;
      }
      if (op == "inside") {
            constraint_integral_type_t ignored;
            if (!infer_constraint_inside_type_(par, ignored)) return false;
            out.width = 1; out.sign = false; return true;
      }
      return false;
}

static bool infer_constraint_inside_container_type_(
      const string&token, constraint_integral_type_t&out)
{
      bool empty = token.compare(0, 7, "qempty:") == 0;
      bool bad = token.compare(0, 5, "qbad:") == 0;
      if (!empty && !bad && token.compare(0, 2, "q:") != 0) return false;
      vector<string> fields;
      string field;
      istringstream input(token);
      while (getline(input, field, ':')) fields.push_back(field);
      bool sign = !fields.empty() && fields.back() == "s";
      size_t count = fields.size() - (sign ? 1 : 0);
      size_t width_field = empty || bad ? 1 : 2;
      if (count != width_field + 1) return false;
      char*end = nullptr;
      unsigned long width = strtoul(fields[width_field].c_str(), &end, 10);
      if (end == fields[width_field].c_str() || *end || !width
          || width > UINT_MAX)
            return false;
      out.width = (unsigned)width;
      out.sign = sign;
      return true;
}

static bool infer_constraint_inside_type_(
      IRParser&par, constraint_integral_type_t&out)
{
      if (!infer_constraint_integral_type_(par, out) || !out.width)
            return false;
      auto merge = [&](const constraint_integral_type_t&item) {
            out.width = max(out.width, item.width);
            out.sign = out.sign && item.sign;
      };

      par.skip_ws();
      while (par.peek() != ')' && !par.at_end()) {
            if (par.peek() == '[') {
                  par.consume();
                  par.skip_ws();
                  if (par.peek() == '*') {
                        par.consume();
                  } else {
                        constraint_integral_type_t item;
                        if (!infer_constraint_integral_type_(par, item))
                              return false;
                        merge(item);
                  }
                  if (!par.expect(',')) return false;
                  par.skip_ws();
                  if (par.peek() == '*') {
                        par.consume();
                  } else {
                        constraint_integral_type_t item;
                        if (!infer_constraint_integral_type_(par, item))
                              return false;
                        merge(item);
                  }
                  if (!par.expect(']')) return false;
            } else if (par.peek() == '(') {
                  constraint_integral_type_t item;
                  if (!infer_constraint_integral_type_(par, item))
                        return false;
                  merge(item);
            } else {
                  string token = par.read_token();
                  if (token == "qempty") {
                        // An empty unpacked container contributes no element.
                  } else {
                        constraint_integral_type_t item;
                        if (token.compare(0, 2, "q:") == 0
                            || token.compare(0, 7, "qempty:") == 0
                            || token.compare(0, 5, "qbad:") == 0) {
                              if (!infer_constraint_inside_container_type_(
                                    token, item)) return false;
                        } else {
                              IRParser item_parser(token);
                              if (!infer_constraint_integral_type_(
                                    item_parser, item)
                                  || !item_parser.at_end()) return false;
                        }
                        merge(item);
                  }
            }
            par.skip_ws();
      }
      return par.expect(')');
}

/* ---------------------------------------------------------------
 * Z3 expression builder context
 * --------------------------------------------------------------- */

/* Canonical property identity for a complete selected object graph (IEEE
 * 1800-2017 18.5.9 / 1800-2023 18.5.8). Syntax paths are only lookups; a
 * static property shared by several instances still has one storage cell. */
class z3_object_graph_t {
    public:
      struct binding_t {
            const vvp_z3_object_s*scope;
            unsigned pid;
      };
      struct property_t {
            vvp_cobject*object;
            unsigned pid;
            vvp_cobject*rng_owner;
            vector<binding_t> bindings;
      };
      const vector<vvp_z3_object_s>&objects;
      vector<property_t> properties;
      bool valid = true;

      explicit z3_object_graph_t(const vector<vvp_z3_object_s>&selected)
      : objects(selected)
      {
            for (const auto&scope : objects) {
                  for (unsigned pid = 0;
                       pid < scope.object->get_defn()->property_count(); ++pid) {
                        unsigned idx = intern(scope.object, pid);
                        properties[idx].bindings.push_back({&scope, pid});
                        if (properties[idx].bindings.size() == 1)
                              properties[idx].rng_owner = scope.rng_owner;
                  }
            }
      }

      unsigned intern(vvp_cobject*object, unsigned pid)
      {
            if (!object || pid >= object->get_defn()->property_count()) {
                  valid = false;
                  return UINT_MAX;
            }
            auto key = make_pair(object, pid);
            auto found = instance_ids_.find(key);
            if (found != instance_ids_.end()) return found->second;
            const class_type*type = object->get_defn();
            vpiHandle storage = type->property_is_static(pid)
                  ? type->static_property_storage(pid) : nullptr;
            if (storage) {
                  auto shared = static_ids_.find(storage);
                  if (shared != static_ids_.end()) {
                        instance_ids_[key] = shared->second;
                        return shared->second;
                  }
            }
            unsigned idx = (unsigned)properties.size();
            properties.push_back({object, pid, object, {}});
            instance_ids_[key] = idx;
            if (storage) static_ids_[storage] = idx;
            return idx;
      }

      bool active(unsigned idx) const;
      bool element_active(unsigned idx, unsigned elem) const;
      bool member_active(unsigned idx, unsigned member) const;
      bool size_active(unsigned idx) const;
      void select_storage_owners();

    private:
      map<pair<vvp_cobject*, unsigned>, unsigned> instance_ids_;
      map<vpiHandle, unsigned> static_ids_;
};

struct Z3Builder {
      Z3_context ctx;
      z3_object_graph_t*graph;

      unsigned property_index(unsigned pid) const
            { return graph ? graph->intern(cobj, pid) : pid; }
      vvp_cobject*object(unsigned idx) const
            { return graph ? graph->properties.at(idx).object : cobj; }
      unsigned local_index(unsigned idx) const
            { return graph ? graph->properties.at(idx).pid : idx; }
      const class_type*type(unsigned idx) const
            { return graph ? object(idx)->get_defn() : defn; }
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

	// Legacy state-only reads through a handle collection. The graph
	// path resolves active element fields to canonical PropVars instead.
      struct QElemVar {
	    unsigned qprop; unsigned elem; unsigned member;
	    unsigned width; Z3_ast var;
      };
      vector<QElemVar> qelem_vars;

      Z3_ast get_qelem_var(unsigned qprop, unsigned elem, unsigned member,
			   unsigned width) {
	    for (auto& v : qelem_vars)
		  if (v.qprop == qprop && v.elem == elem && v.member == member)
			return v.var;
	    char nm[64];
	    snprintf(nm, sizeof(nm), "qm%u_%u_%u", qprop, elem, member);
	    Z3_sort srt = Z3_mk_bv_sort(ctx, width ? width : 32);
	    Z3_ast var = Z3_mk_const(ctx, Z3_mk_string_symbol(ctx, nm), srt);
	    QElemVar qv;
	    qv.qprop = qprop; qv.elem = elem; qv.member = member;
	    qv.width = width ? width : 32; qv.var = var;
	    qelem_vars.push_back(qv);
	    return var;
      }

      const class_type* defn;
      vvp_cobject* cobj;
      const vector<vvp_object_t>*object_vals = nullptr;
      const vector<bool>*prop_active = nullptr;
      // Keep invalid state reads until enclosing guards can exclude them
      // (IEEE 1800-2017 18.5.13 / 1800-2023 18.5.12).
      vector<string> state_errors;
      vector<Z3_ast> side_constraints;
      struct StateCheck {
            Z3_ast error;
            string message;
      };
      vector<StateCheck> state_checks;
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
	    // These values are consumed from class_type dependency metadata.
	    enum Kind {
		  PROP = class_type::constraint_dependency_t::PROP,
		  MEMBER = class_type::constraint_dependency_t::MEMBER,
		  ELEM = class_type::constraint_dependency_t::ELEM,
		  SIZE = class_type::constraint_dependency_t::SIZE,
		  MEMBER_ELEM
	    } kind;
	    unsigned idx;
	    unsigned leaf;
	    unsigned subleaf;
	    VarRef() : kind(PROP), idx(0), leaf(0), subleaf(0) { }
	    VarRef(Kind k, unsigned i, unsigned l, unsigned s = 0)
	    : kind(k), idx(i), leaf(l), subleaf(s) { }

	    bool operator<(const VarRef&that) const {
		  if (kind != that.kind) return kind < that.kind;
		  if (idx != that.idx) return idx < that.idx;
		  if (leaf != that.leaf) return leaf < that.leaf;
		  return subleaf < that.subleaf;
	    }
	 };
      struct SoftAssert { Z3_ast a; unsigned weight; bool from_soft_kw;
			  std::set<VarRef> refs; size_t priority; };
      vector<SoftAssert> pending_soft;
      size_t preference_order = 0;

	// Preference-producing nodes are parsed once while the hard constraint
	// set is built. Some later feasibility checks reparse the same IR into
	// the existing builder; suppressing side effects there prevents duplicate
	// soft/dist groups while retaining the identical hard expression.
      bool collect_preferences;
      unsigned soft_keyword_depth;

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

      // RANDOM-DIST fix #2 (2023 18.5.3; 2017 18.5.4): a `dist` node's
      // branches, recorded
      // structurally (not just as OR'd hard clauses + soft preferences)
      // so the solver can draw a value with probability proportional to
      // its weight instead of merely preferring the heaviest branch.
      // The subject may be any integral expression. Z3 represents
      // relational/logical expressions as Bool, so the parser converts
      // those subjects back to their SystemVerilog one-bit value before
      // recording the distribution.
      struct DistBranch {
	    unsigned weight;
	    bool is_range;
	    bool range_weight_per_value;
	    unsigned value_width;
	    bool comparison_signed;
	      // A range stores order-preserving coordinates at value_width;
	      // a scalar stores its coerced bit pattern in lo (lo==hi).
	    uint64_t lo, hi;
      };
      struct DistSpec {
            vvp_cobject*rng_owner = nullptr;
            size_t priority = 0;
	    Z3_ast subject;
	    unsigned width;
	    std::set<VarRef> refs;
	    std::set<VarRef> disable_refs;
	    std::vector<DistBranch> branches;
	    std::vector<SoftAssert> fallback;
	    bool exact_supported;
            bool requires_large_exact;
            bool state_weights;
	    bool disableable;
      };
      std::vector<DistSpec> dist_specs;

      // M3B-3 (`disable soft <var>`, IEEE 1800-2017 18.5.14.1): keep the
      // complete variable identity. A struct member, array element, array
      // size, and their owning property can share a numeric outer index but
      // are not interchangeable leaves. Disabling an aggregate property is
      // deliberately broader and covers every descendant with that index.
      // IEEE 1800-2017 18.5.14.2 / 1800-2023 18.5.13.2: disable soft
      // discards only lower-priority preferences, including across owners.
      std::map<VarRef, size_t> disabled_soft_refs;
      std::set<VarRef>* collect_refs = nullptr;
      bool collect_refs_only = false;
      bool allow_planner_value_slots = false;
      vvp_cobject*assoc_foreach_key = nullptr;
      bool soft_ref_disabled(const VarRef&ref, size_t priority) const {
	    for (const auto&entry : disabled_soft_refs) {
                  if (entry.second <= priority) continue;
                  const VarRef&disabled = entry.first;
		  if (disabled.kind == ref.kind && disabled.idx == ref.idx
		      && disabled.leaf == ref.leaf
		      && disabled.subleaf == ref.subleaf)
			return true;
		  if (disabled.kind == VarRef::PROP && disabled.idx == ref.idx)
			return true;
                  // Canonical struct members have their own property IDs.
                  // Disabling the containing value still covers those leaves
                  // (2017 18.5.14.2 / 2023 18.5.13.2); class handles do not
                  // establish this value-containment relationship.
                  if (graph && disabled.kind == VarRef::PROP
                      && disabled.idx < graph->properties.size()
                      && ref.idx < graph->properties.size()
                      && type(disabled.idx)->property_base_type(local_index(disabled.idx)).compare(0, 3, "oc:") == 0) {
                        vvp_object_t record;
                        object(disabled.idx)->get_object(local_index(disabled.idx), record, 0);
                        if (record.peek<vvp_cobject>() == object(ref.idx)) return true;
                  }
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

	// One selected element of a fixed unpacked array member inside an
	// unpacked-struct property ("a:OUTER:MEMBER:WIDTH:ELEM[:s]").
	// Graph solves canonicalize this to ElemVar; this form retains the same
	// identity for the legacy single-object solver.
      struct MemberElemVar {
	    unsigned outer;
	    unsigned member;
	    unsigned width;
	    unsigned elem;
	    Z3_ast var;
      };
      vector<MemberElemVar> member_elem_vars;

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

      Z3_ast get_member_elem_var(unsigned outer, unsigned member,
				 unsigned width, unsigned elem) {
	    for (auto&v : member_elem_vars)
		  if (v.outer == outer && v.member == member && v.elem == elem)
			return v.var;
	    char name[64];
	    snprintf(name, sizeof(name), "a%u_%u_%u", outer, member, elem);
	    Z3_sort sort = Z3_mk_bv_sort(ctx, width ? width : 32);
	    Z3_ast var = Z3_mk_const(ctx, Z3_mk_string_symbol(ctx, name), sort);
	    MemberElemVar value = {outer, member, width ? width : 32, elem, var};
	    member_elem_vars.push_back(value);
	    return var;
      }

	// Variables whose SystemVerilog type is signed. Comparisons where
	// a signed variable participates use the signed BV predicates
	// (IEEE 1800-2017 11.8.1; integer literals are signed).
      std::set<Z3_ast> signed_vars;
      bool is_signed(Z3_ast a) const
	    { return signed_vars.find(a) != signed_vars.end(); }

	/* Z3 bitvector sorts do not carry SystemVerilog signedness, and Z3
	 * hash-conses equal numeral/identity ASTs. Give each occurrence whose type
	 * metadata changes a fresh alias, constrained equal to its raw bits, so
	 * marking that alias cannot contaminate another occurrence of the same AST.
	 * Property/member variables stay unaliased because ordering and write-back
	 * depend on their stable raw identity. */
      std::vector<std::pair<Z3_ast,Z3_ast> > signed_constant_aliases;

	/* Replace occurrence aliases by their raw values when a caller must fold an
	 * item, endpoint, exponent, weight, or guard outside the surrounding
	 * assertion. The assertion parser separately appends alias==raw clauses. */
      Z3_ast resolve_signed_constants(Z3_ast value) const {
	    if (!value || signed_constant_aliases.empty()) return value;
	    vector<Z3_ast> from;
	    vector<Z3_ast> to;
	    from.reserve(signed_constant_aliases.size());
	    to.reserve(signed_constant_aliases.size());
	    for (const auto& alias : signed_constant_aliases) {
		  from.push_back(alias.first);
		  to.push_back(alias.second);
	    }
	    return Z3_substitute(ctx, value, (unsigned)from.size(),
				 from.data(), to.data());
      }

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
      // Width supplied by an enclosing assignment-like integral cast. A
      // nested cast replaces (and therefore fences) this context while its
      // operand is built.
      unsigned integral_context_width = 0;
      int integral_context_sign = -1; // -1 derives from this expression
      bool integral_typed_mode = false;
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
	// Binary expression propagation first determines one common signedness
	// for both operands. In an unsigned context even a narrower signed
	// operand is zero-extended; consulting that operand's leaf type here
	// would implement two different contexts for one operation.
      Z3_ast coerce_in_context(Z3_ast a, unsigned w, bool signed_context) {
	    unsigned aw = bv_width_(a);
	    if (aw == w) return a;
	    if (aw > w) return Z3_mk_extract(ctx, w - 1, 0, a);
	    return signed_context ? Z3_mk_sign_ext(ctx, w - aw, a)
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
	    enum Kind {
		  PROP = VarRef::PROP, MEMBER = VarRef::MEMBER,
		  ELEM = VarRef::ELEM, SIZE = VarRef::SIZE,
		  MEMBER_ELEM = VarRef::MEMBER_ELEM
	    } kind;
	    unsigned idx;
	    unsigned elem;
	    unsigned subelem;
	    OrderRef() : kind(PROP), idx(0), elem(0), subelem(0) { }
	    OrderRef(Kind k, unsigned i, unsigned e, unsigned s = 0)
	    : kind(k), idx(i), elem(e), subelem(s) { }

	    bool operator<(const OrderRef&that) const {
		  if (kind != that.kind) return kind < that.kind;
		  if (idx != that.idx) return idx < that.idx;
		  if (elem != that.elem) return elem < that.elem;
		  return subelem < that.subelem;
	    }
	    bool operator==(const OrderRef&that) const {
		  return kind == that.kind && idx == that.idx
			&& elem == that.elem && subelem == that.subelem;
	    }
      };
      std::vector<std::pair<OrderRef,OrderRef> > order_pairs;

      Z3Builder(Z3_context c, const class_type* d, vvp_cobject* o,
                z3_object_graph_t*g = nullptr)
      : ctx(c), graph(g), defn(d), cobj(o), opt(0), collect_preferences(true),
	soft_keyword_depth(0) {}

      Z3_ast get_prop_var(unsigned idx, unsigned width) {
            if (idx == UINT_MAX)
                  return Z3_mk_unsigned_int64(ctx, 0,
                        Z3_mk_bv_sort(ctx, width ? width : 32));
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

	/* Signedness is occurrence metadata, not part of a Z3 bitvector sort.
	 * A fresh alias is collision-free even when the source itself contains an
	 * identity expression such as -(-x); parse_constraint_ir constrains it to
	 * the raw constant, while ground evaluators substitute it directly. */
      Z3_ast tag_signed_constant(Z3_ast raw) {
	    Z3_sort sort = Z3_get_sort(ctx, raw);
	    Z3_ast alias = Z3_mk_fresh_const(ctx, "sv_signed_constant", sort);
	    set_sv(alias, sv_of(raw));
	    signed_vars.insert(alias);
	    signed_constant_aliases.push_back(std::make_pair(alias, raw));
	    return alias;
      }

	/* A cast changes occurrence-local width/sign metadata. Z3 hash-conses
	 * identity extracts/extensions, so tagging `raw' directly could change
	 * another use of the same property or arithmetic AST. Give every cast a
	 * fresh equality-constrained result, just like a signed literal. */
      Z3_ast tag_integral_cast(Z3_ast raw, unsigned width, bool is_signed) {
	    Z3_sort sort = Z3_get_sort(ctx, raw);
	    Z3_ast alias = Z3_mk_fresh_const(ctx, "sv_integral_cast", sort);
	    set_sv(alias, width);
	    if (is_signed) signed_vars.insert(alias);
	    signed_constant_aliases.push_back(std::make_pair(alias, raw));
	    return alias;
      }

      Z3_ast typed_result(Z3_ast raw, unsigned width, bool is_signed) {
	    if (integral_typed_mode)
		  return tag_integral_cast(raw, width, is_signed);
	    set_sv(raw, width);
	    if (is_signed) signed_vars.insert(raw);
	    return raw;
      }
};

static bool enter_typed_binary_context_(IRParser parser, Z3Builder&b,
                                         bool left_result,
                                         unsigned&saved_width,
                                         int&saved_sign,
                                         unsigned&width, bool&sign)
{
      saved_width = b.integral_context_width;
      saved_sign = b.integral_context_sign;
      constraint_integral_type_t left, right;
      if (!infer_constraint_integral_type_(parser, left)
          || !infer_constraint_integral_type_(parser, right)) return false;
      width = left_result ? left.width : max(left.width, right.width);
      if (saved_width > width) width = saved_width;
      sign = saved_sign >= 0 ? saved_sign != 0
            : left_result ? left.sign : left.sign && right.sign;
      b.integral_context_width = width;
      b.integral_context_sign = sign ? 1 : 0;
      return width != 0;
}

static void leave_typed_context_(Z3Builder&b, unsigned width, int sign)
{
      b.integral_context_width = width;
      b.integral_context_sign = sign;
}

// Forward declaration
static Z3_ast build_z3_expr(IRParser&, Z3Builder&, Z3_lbool* = nullptr);
static Z3_ast build_z3_atom(IRParser&, Z3Builder&, Z3_lbool* = nullptr);
static Z3_lbool state_guard_truth_(Z3Builder&, Z3_ast,
                                  const set<Z3Builder::VarRef>&);
static bool rand_elem_active_(const Z3Builder&, const vector<bool>*,
                              unsigned, unsigned);
static uint64_t cobj_prop_bits(vvp_cobject* cobj, unsigned idx);
static uint64_t cobj_member_bits(vvp_cobject* cobj, unsigned outer,
				 unsigned member);
static uint64_t cobj_member_elem_bits(vvp_cobject*cobj, unsigned outer,
				      unsigned member, unsigned elem);
static uint64_t cobj_elem_bits(vvp_cobject* cobj, unsigned idx, unsigned elem);
static bool cobj_elem_vec4_(vvp_cobject*cobj, unsigned idx, unsigned elem,
                            vvp_vector4_t&value);
static void cobj_set_elem_bits(vvp_cobject*cobj, unsigned idx, unsigned elem,
			       unsigned width, uint64_t bits);
static uint64_t cobj_qelem_member_bits(vvp_cobject* cobj, unsigned qprop,
				       unsigned elem, unsigned member);
static uint64_t cobj_darray_size(vvp_cobject* cobj, unsigned idx);
static bool vec4_to_uint64_(const vvp_vector4_t&value, uint64_t&bits);

static bool vec4_is_two_state_(const vvp_vector4_t&value)
{
      for (unsigned bit = 0; bit < value.size(); ++bit)
            if (value.value(bit) != BIT4_0 && value.value(bit) != BIT4_1)
                  return false;
      return true;
}

/* Object reads must retain identity, not property_object::get_vec4's
 * intentional nullness view (IEEE 1800-2017/2023 8.4, 11.4.5, 18.4).
 * A null final handle is a value; a null owner or invalid index is an error. */
enum constraint_handle_failure_t {
      HANDLE_FAILURE_NONE,
      HANDLE_FAILURE_STRUCTURAL,
      HANDLE_FAILURE_ACCESS
};

static bool constraint_object_property_(vvp_cobject*owner, unsigned pid,
      vvp_object_t&value, string&error, uint64_t word = 0,
      bool class_only = true,
      constraint_handle_failure_t*failure = nullptr)
{
      if (!owner) {
            error = "null/non-class constraint object owner";
            if (failure) *failure = HANDLE_FAILURE_ACCESS;
      }
      else {
            const class_type*type = owner->get_defn();
            if (pid >= type->property_count()
                || word >= type->property_array_size(pid)
                || (type->property_base_type(pid) != "o"
                    && (class_only || type->property_base_type(pid).compare(0, 3, "oc:") != 0)))
                  {
                        error = "invalid class-handle property metadata";
                        if (failure) *failure = HANDLE_FAILURE_STRUCTURAL;
                  }
            else {
                  owner->get_object(pid, value, word);
                  return true;
            }
      }
      return false;
}

static bool constraint_object_element_(vvp_cobject*owner, unsigned pid,
      uint64_t index, vvp_object_t&value, string&error,
      constraint_handle_failure_t*failure = nullptr)
{
      if (!owner || pid >= owner->get_defn()->property_count()) {
            error = "invalid constraint object collection owner";
            if (failure) *failure = owner ? HANDLE_FAILURE_STRUCTURAL
                                          : HANDLE_FAILURE_ACCESS;
            return false;
      }
      const class_type*type = owner->get_defn();
      const string&base = type->property_base_type(pid);
      if (base == "o")
            return constraint_object_property_(owner, pid, value, error, index,
                                               true, failure);
      if ((base != "Do" && base != "Qo")
          || type->property_array_size(pid) != 1) {
            error = "unsupported class-handle collection metadata";
            if (failure) *failure = HANDLE_FAILURE_STRUCTURAL;
            return false;
      }
      vvp_object_t collection;
      owner->get_object(pid, collection, 0);
      vvp_darray*array = collection.peek<vvp_darray>();
      if (!array || index >= array->get_size() || index > UINT_MAX) {
            error = "out-of-bounds class-handle constraint index";
            if (failure) *failure = HANDLE_FAILURE_ACCESS;
            return false;
      }
      array->get_word((unsigned)index, value);
      return true;
}

static Z3_ast scalar_property_ref_(Z3Builder&b, unsigned idx,
                                    unsigned width, bool sflag)
{
      if (b.collect_refs) {
	    Z3Builder::VarRef ref = {Z3Builder::VarRef::PROP, idx, 0};
	    b.collect_refs->insert(ref);
      }
      if (b.collect_refs_only)
	    return Z3_mk_unsigned_int64(
		  b.ctx, 0, Z3_mk_bv_sort(b.ctx, width));
      // IEEE 1800-2017 18.3/18.5.9 and 1800-2023 18.3/18.5.8:
      // state operands are fixed for this call. Ground them before expanding
      // operators such as power, while retaining source refs above for soft
      // priority and guards. Actual active aliases remain solver variables.
      if (b.graph && idx < b.graph->properties.size() && !b.graph->active(idx)) {
            vvp_vector4_t data;
            b.object(idx)->get_vec4(b.local_index(idx), data);
            uint64_t bits = 0;
            if (!vec4_to_uint64_(data, bits)) {
                  b.state_errors.push_back("unsupported width or X/Z value in constraint guard (IEEE 1800-2017/2023 18.3)");
                  bits = 0;
            }
            Z3_ast value = Z3_mk_unsigned_int64(b.ctx, bits, Z3_mk_bv_sort(b.ctx, width));
            return sflag ? b.tag_signed_constant(value) : value;
      }
      Z3_ast var = b.get_prop_var(idx, width);
      if (sflag) b.signed_vars.insert(var);
      return var;
}


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
      // g: is emitted only by state-foreach expansion against this graph.
      if (tok[0] == 'g') {
            if (!b.graph || idx >= b.graph->properties.size() || !width) {
                  b.state_errors.push_back("invalid canonical constraint property");
                  return b.mk_true();
            }
      } else idx = b.property_index(idx);
      return scalar_property_ref_(b, idx, width, sflag);
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
      if (b.graph) {
            vvp_object_t value;
            b.cobj->get_object(outer, value, 0);
            unsigned idx = b.graph->intern(value.peek<vvp_cobject>(), member);
            return scalar_property_ref_(b, idx, width, sflag);
      }
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
      idx = b.property_index(idx);
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
      idx = b.property_index(idx);
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

// Parse "a:OUTER:MEMBER:WIDTH:ELEM[:s]" -- one selected element of a
// fixed unpacked array member in an unpacked-struct class property.
static Z3_ast parse_member_elem(IRParser&, Z3Builder&b, const string&tok)
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
      unsigned elem = 0;
      if (*s == ':') { elem = (unsigned)atoi(s + 1); ++s; }
      while (*s && *s != ':') ++s;
      bool sflag = (*s == ':' && s[1] == 's');
      if (b.graph) {
	    vvp_object_t value;
	    b.cobj->get_object(outer, value, 0);
	    vvp_cobject*owner = value.peek<vvp_cobject>();
	    if (!owner) {
		  b.state_errors.push_back("invalid unpacked-struct member-array storage");
		  return b.mk_true();
	    }
	    unsigned idx = b.graph->intern(owner, member);
	    if (b.collect_refs) {
		  Z3Builder::VarRef ref = {Z3Builder::VarRef::ELEM, idx, elem};
		  b.collect_refs->insert(ref);
	    }
	    if (b.collect_refs_only)
		  return Z3_mk_unsigned_int64(
			b.ctx, 0, Z3_mk_bv_sort(b.ctx, width));
	    if (!b.graph->element_active(idx, elem)) {
		  vvp_vector4_t data;
		  owner->get_vec4(member, data, elem);
		  uint64_t bits = 0;
		  if (!vec4_to_uint64_(data, bits)) {
			b.state_errors.push_back(
			      "unsupported width or X/Z value in constraint guard "
			      "(IEEE 1800-2017/2023 18.3)");
			bits = 0;
		  }
		  Z3_ast value = Z3_mk_unsigned_int64(
			b.ctx, bits, Z3_mk_bv_sort(b.ctx, width));
		  return sflag ? b.tag_signed_constant(value) : value;
	    }
	    Z3_ast var = b.get_elem_var(idx, width, elem);
	    if (sflag) b.signed_vars.insert(var);
	    return var;
      }
      if (b.collect_refs) {
	    Z3Builder::VarRef ref = {
		  Z3Builder::VarRef::MEMBER_ELEM, outer, member, elem
	    };
	    b.collect_refs->insert(ref);
      }
      if (b.collect_refs_only)
	    return Z3_mk_unsigned_int64(
		  b.ctx, 0, Z3_mk_bv_sort(b.ctx, width));
      Z3_ast var = b.get_member_elem_var(outer, member, width, elem);
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
      string path_error;
      if (!path.empty()) {
	    for (size_t i = 0 ; cur && i + 1 < path.size() ; i += 1) {
		  vvp_object_t nested;
		  if (!constraint_object_property_(cur, path[i], nested,
                                                    path_error, 0, false)) break;
		  cur = nested.peek<vvp_cobject>();
	    }
	    if (!cur || path.back() >= cur->get_defn()->property_count())
                  path_error = "null/invalid constraint object path";
	    if (path_error.empty()) {
		  vvp_vector4_t vec;
		  cur->get_vec4(path.back(), vec);
		  unsigned nbits = vec.size();
		  if (nbits > 64) nbits = 64;
		  for (unsigned bit = 0 ; bit < nbits ; bit += 1)
			if (vec.value(bit) == BIT4_1) bits |= (1ULL << bit);
	    }
      }

      if (!path_error.empty()) {
            b.state_errors.push_back(path_error);
            return Z3_mk_unsigned_int64(b.ctx, 0, Z3_mk_bv_sort(b.ctx, width));
      }

      if (b.graph && cur && !path.empty())
            return scalar_property_ref_(b, b.graph->intern(cur, path.back()),
                                        width, sflag);
      Z3_sort sort = Z3_mk_bv_sort(b.ctx, width);
      Z3_ast val = Z3_mk_unsigned_int64(b.ctx, bits, sort);
	if (sflag) val = b.tag_signed_constant(val);
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

/* IEEE 1800-2017 18.5.8.1 / 1800-2023 18.5.7.1: queue/darray
 * indices are signed int. Substitute `L` with "c:<i>:32:s" (token
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
		  out += "c:" + to_string(i) + ":32:s";
		  prev = 'L';
		  p++;
		  continue;
	    }
	    prev = *p;
	    out += *p++;
      }
      return out;
}

/* Recover exact width/sign metadata for a constant or a chain of casts. The
 * legacy constant folder intentionally evaluates arithmetic in uint64
 * headroom, so only leaf/cast chains are safe to normalize here. */
static bool const_cast_source_type_(IRParser&par, unsigned&width, bool&sign)
{
      par.skip_ws();
      if (par.peek() != '(') {
	    string token = par.read_token();
	    if (token.compare(0, 2, "c:") != 0) return false;
	    const char*text = token.c_str() + 2;
	    char*end = nullptr;
	    (void)strtoull(text, &end, 10);
	    width = 32;
	    sign = false;
	    if (end && *end == ':') {
		  unsigned long parsed = strtoul(end + 1, &end, 10);
		  if (!parsed || parsed > 64) return false;
		  width = (unsigned)parsed;
		  sign = end && *end == ':' && end[1] == 's' && end[2] == 0;
		  if (end && *end && !sign) return false;
	    }
	    return true;
      }
      par.consume();
      if (par.read_token() != "cast") return false;
      auto header = [&](uint64_t&value) {
	    string token = par.read_token();
	    if (token.compare(0, 2, "c:") != 0) return false;
	    char*end = nullptr;
	    value = strtoull(token.c_str() + 2, &end, 10);
	    return end && (*end == 0 || *end == ':');
      };
      uint64_t cast_width = 0, cast_sign = 0;
      if (!header(cast_width) || !header(cast_sign)
	  || cast_width > 64 || cast_sign > 2) return false;
	if (!const_cast_source_type_(par, width, sign) || !par.expect(')'))
	  return false;
      if (cast_width) width = (unsigned)cast_width;
      if (cast_sign != 2) sign = cast_sign == 1;
      return true;
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
	    if (op == "cast") {
		  uint64_t width = 0, sign = 0, value = 0;
		  const char*value_begin = nullptr;
		  if (!eval_const_ir_impl(par, width)
		      || !eval_const_ir_impl(par, sign)) return false;
		  par.skip_ws();
		  value_begin = par.p;
		  if (!eval_const_ir_impl(par, value)
		      || width > 64 || sign > 2) return false;
		  string value_ir(value_begin, par.p - value_begin);
		  par.skip_ws();
		  if (!par.expect(')')) return false;
		  unsigned source_width = 0;
		  bool source_signed = false;
		  IRParser source(value_ir);
		  if (const_cast_source_type_(source, source_width, source_signed)
		      && source.at_end()
		      && source_width < 64) {
			uint64_t source_mask = ((uint64_t)1 << source_width) - 1;
			value &= source_mask;
			if (source_signed && (value & ((uint64_t)1 << (source_width - 1))))
			      value |= ~source_mask;
		  }
		  if (width && width < 64)
			value &= ((uint64_t)1 << width) - 1;
		  out = value;
		  return true;
	    }
	    uint64_t a = 0, b = 0;
	    if (!eval_const_ir_impl(par, a)) return false;
	    if (op == "not" || op == "neg") {
		  par.skip_ws();
		  if (!par.expect(')')) return false;
		  out = op == "not" ? !a : UINT64_C(0) - a;
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

/* Typed handle operands use the existing property/element paths, with
 * explicit h:null and h:N caller-object slots. Both solver and state-foreach
 * evaluation use this reader; neither converts an object to numeric bits. */
static bool read_constraint_handle_(IRParser&parser, vvp_cobject*receiver,
      const vector<vvp_object_t>*objects, const vector<vvp_object_t>*queues,
      const function<bool(IRParser&, uint64_t&, string&)>&index_value,
      vvp_object_t&value, string&error,
      constraint_handle_failure_t*failure = nullptr)
{
      auto fields = [](const string&text, vector<unsigned>&out, char separator) {
            istringstream input(text);
            string part;
            while (getline(input, part, separator)) {
                  if (part == "s") break;
                  char*end = nullptr;
                  unsigned long number = strtoul(part.c_str(), &end, 10);
                  if (part.empty() || end != part.c_str() + part.size()
                      || number > UINT_MAX) return false;
                  out.push_back((unsigned)number);
            }
            return !out.empty();
      };
      auto invalid = [&]() {
            if (error.empty()) error = "unsupported/malformed class-handle constraint operand";
            if (failure) *failure = HANDLE_FAILURE_STRUCTURAL;
            return false;
      };
      if (parser.peek() == '(') {
            parser.consume();
            string op = parser.read_token();
            string body = capture_balanced_form(parser);
            IRParser sub(body);
            string header = sub.read_token();
            vector<unsigned> ids;
            if (op == "qfield" && header.compare(0, 3, "qf:") == 0)
                  header.erase(0, 3);
            if (!fields(header, ids, ':')) return invalid();
            uint64_t index = 0;
            if (!index_value(sub, index, error) || !sub.at_end()) return invalid();
            vvp_object_t element;
            if (op == "qfield" || op == "qhandle") {
                  if (!queues || ids[0] >= queues->size()) return invalid();
                  vvp_darray*array = queues->at(ids[0]).peek<vvp_darray>();
                  if (!array || index >= array->get_size() || index > UINT_MAX) {
                        error = "out-of-bounds class-handle constraint index";
                        if (failure) *failure = HANDLE_FAILURE_ACCESS;
                        return false;
                  }
                  array->get_word((unsigned)index, element);
                  if (op == "qhandle" && ids.size() == 1) value = element;
                  else if (op != "qfield" || ids.size() != 3
                      || !constraint_object_property_(element.peek<vvp_cobject>(),
                            ids[1], value, error, 0, true, failure)) {
                        if (failure && *failure != HANDLE_FAILURE_NONE)
                              return false;
                        return invalid();
                  }
            } else if (op == "delem" || op == "qmelem") {
                  if (ids.size() != (op == "delem" ? 2u : 3u)) return invalid();
                  if (!constraint_object_element_(receiver, ids[0], index,
                                                  element, error, failure))
                        return false;
                  if (op == "delem") value = element;
                  else if (!constraint_object_property_(element.peek<vvp_cobject>(),
                              ids[1], value, error, 0, true, failure)) return false;
            } else return invalid();
      } else {
            string token = parser.read_token();
            if (token == "h:null") return true;
            if (token == "h:this") value = receiver;
            else if (token.compare(0, 2, "h:") == 0) {
                  vector<unsigned> ids;
                  if (!fields(token.substr(2), ids, ':') || ids.size() != 1
                      || !objects || ids[0] >= objects->size()) return invalid();
                  value = objects->at(ids[0]);
            } else {
                  if (token.size() < 3 || token[1] != ':') return invalid();
                  vector<unsigned> ids;
                  if (token[0] == 'r') {
                        size_t end = token.find(':', 2);
                        if (end == string::npos
                            || !fields(token.substr(2, end - 2), ids, '.')) return invalid();
                  } else {
                        if (!fields(token.substr(2), ids, ':')) return invalid();
                        if (token[0] == 'e' && ids.size() == 3)
                              return constraint_object_element_(receiver, ids[0],
                                    ids[2], value, error, failure);
                        if (token[0] == 'p' && ids.size() == 2) ids.resize(1);
                        else if (token[0] == 'm' && ids.size() == 3) ids.resize(2);
                        else return invalid();
                  }
                  vvp_cobject*owner = receiver;
                  for (size_t i = 0; i < ids.size(); ++i) {
                        if (!constraint_object_property_(owner, ids[i], value, error,
                              0, i + 1 == ids.size(), failure)) return false;
                        owner = value.peek<vvp_cobject>();
                  }
            }
      }
      if (!value.test_nil() && !value.peek<vvp_cobject>()) {
            error = "non-class constraint handle value";
            if (failure) *failure = HANDLE_FAILURE_ACCESS;
            return false;
      }
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

static Z3_ast constraint_side_conjunction_(Z3Builder&b,
                                            size_t begin, size_t end)
{
      if (begin >= end) return b.mk_true();
      if (end == begin + 1) return b.side_constraints[begin];
      return Z3_mk_and(b.ctx, (unsigned)(end - begin),
                       b.side_constraints.data() + begin);
}

static void constraint_guard_state_checks_(Z3Builder&b, size_t begin,
                                            size_t end, Z3_ast guard)
{
      for (size_t idx = begin; idx < end; ++idx) {
            Z3_ast guarded[2] = {guard, b.state_checks[idx].error};
            b.state_checks[idx].error = Z3_mk_and(b.ctx, 2, guarded);
      }
}

static Z3_ast constraint_state_error_disjunction_(Z3Builder&b,
                                                   size_t begin, size_t end)
{
      if (begin >= end) return Z3_mk_false(b.ctx);
      if (end == begin + 1) return b.state_checks[begin].error;
      vector<Z3_ast> errors;
      errors.reserve(end - begin);
      for (size_t idx = begin; idx < end; ++idx)
            errors.push_back(b.state_checks[idx].error);
      return Z3_mk_or(b.ctx, (unsigned)errors.size(), errors.data());
}

static Z3_ast build_z3_atom_impl_(IRParser& par, Z3Builder& b, Z3_lbool*guard)
{
      par.skip_ws();
      if (par.peek() == '(') {
	    par.consume(); // '('
	    return build_z3_expr(par, b, guard);
      }
      string tok = par.read_token();
      if (tok.empty()) return b.mk_true();
      if (tok.substr(0,2) == "p:" || tok.substr(0,2) == "g:")
            return parse_prop(par, b, tok);
      if (tok.substr(0,2) == "m:") return parse_member(par, b, tok);
      if (tok.substr(0,2) == "a:") return parse_member_elem(par, b, tok);
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
	    if (sflag) val = b.tag_signed_constant(val);
	    return val;
      }
      if (tok.substr(0,2) == "s:") {
	      // s:N:T — size of dynamic-array property N, darray type T.
	    Z3_ast size = parse_size(b, tok);
	    return b.integral_typed_mode
		  ? b.tag_integral_cast(size, 32, true) : size;
      }
      if (tok.substr(0,2) == "e:") {
	    return parse_elem(par, b, tok);
      }
	/* Function-result slots are substituted with captured constants before
	 * an actual solve. The staging planner intentionally parses the original
	 * IR first, however, so retain the token's declared bit-vector sort there.
	 * Returning the generic Bool fallback made an arithmetic consumer such as
	 * `(add p:0:32:s v:1:32:s)' ill-sorted before its call could be scheduled. */
      if (tok.substr(0,2) == "v:") {
	    if (!b.allow_planner_value_slots) {
		  b.state_errors.push_back(
			"unsubstituted class constraint function capture slot");
		  return b.mk_true();
	    }
	    const char*text = tok.c_str() + 2;
	    char*end = nullptr;
	    unsigned long slot = strtoul(text, &end, 10);
	    if (end == text || *end != ':') {
		  b.state_errors.push_back(
			"malformed class constraint function capture slot");
		  return b.mk_true();
	    }
	    text = end + 1;
	    unsigned long width_value = strtoul(text, &end, 10);
	    bool is_signed = *end == ':' && end[1] == 's' && end[2] == 0;
	    if (end == text || width_value == 0 || width_value > UINT_MAX
		|| (*end != 0 && !is_signed)) {
		  b.state_errors.push_back(
			"invalid class constraint function capture slot width");
		  return b.mk_true();
	    }
	    (void)slot;
	    unsigned width = (unsigned)width_value;
	    Z3_ast value = Z3_mk_fresh_const(
		  b.ctx, "plan_value", Z3_mk_bv_sort(b.ctx, width));
	    b.set_sv(value, width);
	    if (is_signed) b.signed_vars.insert(value);
	    return value;
      }
      return b.mk_true();
}

static Z3_ast build_z3_atom(IRParser&par, Z3Builder&b, Z3_lbool*guard)
{
      if (!guard) return build_z3_atom_impl_(par, b, nullptr);
      if (b.collect_refs_only) {
            *guard = Z3_L_UNDEF;
            return build_z3_atom_impl_(par, b, nullptr);
      }
      set<Z3Builder::VarRef> refs;
      auto*saved = b.collect_refs;
      b.collect_refs = &refs;
      size_t errors = b.state_errors.size();
      *guard = Z3_L_UNDEF;
      Z3_ast value = build_z3_atom_impl_(par, b, guard);
      b.collect_refs = saved;
      if (saved) saved->insert(refs.begin(), refs.end());
      if (b.state_errors.size() != errors) *guard = Z3_L_UNDEF;
      else if (*guard == Z3_L_UNDEF) *guard = state_guard_truth_(b, value, refs);
      return value;
}

/* Evaluate an integral expression at the point randomize() is called.
 * IEEE 1800-2017 18.5.4 permits dist weights to be integral expressions,
 * including ordinary object properties. Build the expression with the same
 * width/signedness rules as a constraint, replace every property leaf with
 * its current object value, then ground-fold it. This is deliberately
 * transactional: a nonground/malformed expression restores the cursor so a
 * caller can recover without corrupting the surrounding branch parse. */
static bool eval_runtime_integral_ir(IRParser& par, Z3Builder& b,
				     uint64_t& out, bool& overflow,
                                     bool*negative = nullptr,
                                     bool*state_value = nullptr)
{
      if (state_value) *state_value = false;
      overflow = false;
      if (negative) *negative = false;
      const char* start = par.p;
      Z3Builder value_builder(b.ctx, b.defn, b.cobj, b.graph);
      value_builder.object_vals = b.object_vals;
      value_builder.prop_active = b.prop_active;
      set<Z3Builder::VarRef> refs;
      if (state_value) value_builder.collect_refs = &refs;
      Z3_ast value = build_z3_atom(par, value_builder);
      if (par.p == start || !value_builder.state_errors.empty()) {
	    par.p = start;
	    return false;
      }

      // Retain source activity before legacy prefill substitutions. The joint
      // sampler admits state weights only (2017 18.5.4; 2023 18.5.3).
      if (state_value)
            *state_value = state_guard_truth_(value_builder, value, refs) != Z3_L_UNDEF
                  && value_builder.state_errors.empty();

      Z3_sort sort = Z3_get_sort(b.ctx, value);
      bool was_bool = Z3_get_sort_kind(b.ctx, sort) == Z3_BOOL_SORT;
      bool was_signed = !was_bool && value_builder.is_signed(value);
      unsigned semantic_width = was_bool ? 1 : value_builder.sv_of(value);
      if (was_bool)
	    value = bool_to_bv1(b.ctx, value);
	// Arithmetic ASTs retain physical carry/product headroom. A weight is
	// the value of its ordinary SystemVerilog expression, so truncate or
	// extend to the self-determined semantic width before ground folding.
      value = value_builder.coerce(value, semantic_width);

      vector<Z3_ast> from;
      vector<Z3_ast> to;
      from.reserve(value_builder.prop_vars.size()
		   + value_builder.member_vars.size()
		   + value_builder.member_elem_vars.size()
		   + value_builder.signed_constant_aliases.size());
      to.reserve(value_builder.prop_vars.size()
		 + value_builder.member_vars.size()
		 + value_builder.member_elem_vars.size()
		 + value_builder.signed_constant_aliases.size());
	/* Occurrence-specific aliases preserve constant signedness while the
	 * expression is built. Restore their raw bits before this out-of-band
	 * ground fold; unlike assertion parsing, there is no enclosing equality
	 * clause here. */
      for (const auto& alias : value_builder.signed_constant_aliases) {
	    from.push_back(alias.first);
	    to.push_back(alias.second);
      }
      for (const auto& pv : value_builder.prop_vars) {
	    if (!b.cobj) {
		  par.p = start;
		  return false;
	    }
	    unsigned width = pv.width ? pv.width : 32;
	    from.push_back(pv.var);
	    to.push_back(Z3_mk_unsigned_int64(
		  b.ctx, cobj_prop_bits(value_builder.object(pv.idx), value_builder.local_index(pv.idx)),
		  Z3_mk_bv_sort(b.ctx, width)));
      }
      for (const auto& mv : value_builder.member_vars) {
	    if (!b.cobj) {
		  par.p = start;
		  return false;
	    }
	    from.push_back(mv.var);
	    to.push_back(Z3_mk_unsigned_int64(
		  b.ctx, cobj_member_bits(value_builder.object(mv.outer), value_builder.local_index(mv.outer), mv.member),
		  Z3_mk_bv_sort(b.ctx, mv.width)));
      }
      for (const auto&av : value_builder.member_elem_vars) {
	    if (!b.cobj) { par.p = start; return false; }
	    from.push_back(av.var);
	    to.push_back(Z3_mk_unsigned_int64(
		  b.ctx, cobj_member_elem_bits(value_builder.object(av.outer),
			value_builder.local_index(av.outer), av.member, av.elem),
		  Z3_mk_bv_sort(b.ctx, av.width)));
      }
      if (!from.empty())
	    value = Z3_substitute(b.ctx, value, (unsigned)from.size(),
				  from.data(), to.data());
	/* Container sizes/elements are not currently weight value slots. Do not
	 * let the wide-value proof below mistake a genuinely free expression for
	 * a ground overflow or ground low64 result. */
      if (!value_builder.size_vars.empty() || !value_builder.elem_vars.empty()) {
	    par.p = start;
	    return false;
      }
      value = Z3_simplify(b.ctx, value);
      if (z3_ground_uint64(b.ctx, value, out)) {
            // A queue index retains its signed expression type, even when
            // narrower than int (IEEE 1800-2017/2023 7.10.1, 11.8.1).
            if (negative && was_signed && semantic_width <= 64)
                  *negative = (out >> (semantic_width - 1)) & 1;
            return true;
      }

	/* For a ground bitvector wider than uint64, prove whether every high bit
	 * is zero instead of relying on host extraction. This remains valid on
	 * Z3 builds that retain ground bvneg/arithmetic wrappers: a ground term
	 * makes exactly one of high==0 and high!=0 unsatisfiable. */
      Z3_sort value_sort = Z3_get_sort(b.ctx, value);
      if (Z3_get_sort_kind(b.ctx, value_sort) == Z3_BV_SORT) {
	    unsigned value_width = Z3_get_bv_sort_size(b.ctx, value_sort);
	    if (value_width > 64) {
		  Z3_ast high = Z3_mk_extract(b.ctx, value_width - 1, 64, value);
		  Z3_sort high_sort = Z3_get_sort(b.ctx, high);
		  Z3_ast high_zero = Z3_mk_unsigned_int64(b.ctx, 0, high_sort);
		  Z3_ast high_is_zero = Z3_mk_eq(b.ctx, high, high_zero);
		  auto check_one = [&](Z3_ast clause) -> Z3_lbool {
			Z3_solver solver = Z3_mk_simple_solver(b.ctx);
			Z3_solver_inc_ref(b.ctx, solver);
			Z3_solver_assert(b.ctx, solver, clause);
			Z3_lbool result = Z3_solver_check(b.ctx, solver);
			Z3_solver_dec_ref(b.ctx, solver);
			return result;
		  };
		  if (check_one(Z3_mk_not(b.ctx, high_is_zero)) == Z3_L_FALSE) {
			Z3_ast low = Z3_simplify(
			      b.ctx, Z3_mk_extract(b.ctx, 63, 0, value));
			if (z3_ground_uint64(b.ctx, low, out))
			      return true;
		  } else if (check_one(high_is_zero) == Z3_L_FALSE) {
			overflow = true;
			out = UINT64_MAX;
			return true;
		  }
	    }
      }

	/* A ground bitvector numeral can be wider than uint64 without being a
	 * malformed or nonground weight. Preserve that distinction: the caller
	 * keeps the branch, forces the documented weighted-soft fallback, and
	 * saturates only the approximation's host-sized objective. Small values
	 * in a wide sort remain exact when the C API can extract them above. */
      if (Z3_get_ast_kind(b.ctx, value) == Z3_NUMERAL_AST
	  && Z3_get_sort_kind(b.ctx, Z3_get_sort(b.ctx, value)) == Z3_BV_SORT) {
	    Z3_string numeral = Z3_get_numeral_string(b.ctx, value);
	    if (numeral && *numeral) {
		  const char*digits = numeral;
		  bool negative_numeral = *digits == '-';
		  if (*digits == '-' || *digits == '+') digits += 1;
		  while (*digits == '0') digits += 1;
		  size_t length = strlen(digits);
		  static const char max_uint64[] = "18446744073709551615";
		  bool fits = !negative_numeral && (length < sizeof max_uint64 - 1
			|| (length == sizeof max_uint64 - 1
			    && strcmp(digits, max_uint64) <= 0));
		  if (fits) {
			uint64_t parsed = 0;
			for (const char*p = digits ; *p ; p += 1) {
			      if (*p < '0' || *p > '9') {
				    fits = false;
				    break;
			      }
			      parsed = parsed * 10 + (uint64_t)(*p - '0');
			}
			if (fits) {
			      out = parsed;
			      return true;
			}
		  }
		  overflow = true;
		  out = UINT64_MAX;
		  return true;
	    }
      }

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

static Z3_ast build_z3_expr(IRParser& par, Z3Builder& b, Z3_lbool*guard)
{
      par.skip_ws();
      string op = par.read_token();
      if (op.empty()) return b.mk_true();

      if (op == "heq" || op == "hne") {
            auto index_value = [](IRParser&index, uint64_t&value, string&error) {
                  if (eval_const_ir(index, value)) return true;
                  error = "class-handle constraint index is not constant after foreach expansion";
                  return false;
            };
            vvp_object_t left, right;
            string left_error, right_error;
            read_constraint_handle_(par, b.cobj, b.object_vals, nullptr,
                                    index_value, left, left_error);
            read_constraint_handle_(par, b.cobj, b.object_vals, nullptr,
                                    index_value, right, right_error);
            if (!par.expect(')')) left_error = "malformed class-handle comparison";
            if (!left_error.empty()) b.state_errors.push_back(left_error);
            if (!right_error.empty()) b.state_errors.push_back(right_error);
            bool equal = left == right;
            return Z3_mk_unsigned_int64(b.ctx, op == "heq" ? equal : !equal,
                                       Z3_mk_bv_sort(b.ctx, 1));
      }

      /* A scalar member selected through a conditional class handle. Keep
       * the condition symbolic and attach null/invalid access only to the
       * branch that selects it. Header: MEMBER:WIDTH[:s]. */
      if (op == "hselectfield") {
            string header = par.read_token();
            const char*p = header.c_str();
            char*end = nullptr;
            unsigned long member_ul = strtoul(p, &end, 10);
            if (end == p || *end != ':' || member_ul > UINT_MAX) {
                  b.state_errors.push_back("malformed conditional class-member constraint");
                  capture_balanced_form(par);
                  return b.mk_true();
            }
            p = end + 1;
            unsigned long width_ul = strtoul(p, &end, 10);
            bool sflag = *end == ':' && end[1] == 's' && end[2] == 0;
            if (end == p || width_ul == 0 || width_ul > 64
                || (*end && !sflag)) {
                  b.state_errors.push_back("malformed conditional class-member width");
                  capture_balanced_form(par);
                  return b.mk_true();
            }
            unsigned member = (unsigned)member_ul;
            unsigned width = (unsigned)width_ul;
            unsigned outer_context = b.integral_context_width;
            int outer_sign = b.integral_context_sign;
            b.integral_context_width = 0;
            b.integral_context_sign = -1;
            Z3_ast cond = bv_to_bool(b.ctx, build_z3_atom(par, b));
            b.integral_context_width = outer_context;
	    b.integral_context_sign = outer_sign;
            auto index_value = [](IRParser&index, uint64_t&value, string&error) {
                  if (eval_const_ir(index, value)) return true;
                  error = "conditional class-handle index is not constant";
                  return false;
            };
            vvp_object_t yes_object, no_object;
            string yes_error, no_error;
            constraint_handle_failure_t yes_failure = HANDLE_FAILURE_NONE;
            constraint_handle_failure_t no_failure = HANDLE_FAILURE_NONE;
            bool yes_read = read_constraint_handle_(
                  par, b.cobj, b.object_vals, nullptr, index_value,
                  yes_object, yes_error, &yes_failure);
            bool no_read = read_constraint_handle_(
                  par, b.cobj, b.object_vals, nullptr, index_value,
                  no_object, no_error, &no_failure);
            if (!par.expect(')')) {
                  b.state_errors.push_back("malformed conditional class-member constraint");
                  return b.mk_true();
            }
            auto field = [&](const vvp_object_t&object, bool readable,
                             const string&read_error,
                             constraint_handle_failure_t read_failure,
                             Z3_ast validity,
                             Z3_ast&value) {
                  vvp_cobject*owner = readable ? object.peek<vvp_cobject>() : nullptr;
                  bool valid = owner && member < owner->get_defn()->property_count();
                  if (!valid) {
                        if (read_failure == HANDLE_FAILURE_STRUCTURAL
                            || (owner && member >= owner->get_defn()->property_count()))
                              b.state_errors.push_back(read_error.empty()
                                    ? "invalid conditional class-member metadata"
                                    : read_error);
                        else b.side_constraints.push_back(validity);
                        value = Z3_mk_unsigned_int64(
                              b.ctx, 0, Z3_mk_bv_sort(b.ctx, width));
                        return;
                  }
                  if (b.graph) {
                        unsigned idx = b.graph->intern(owner, member);
                        if (b.collect_refs) {
                              Z3Builder::VarRef ref = {
                                    Z3Builder::VarRef::PROP, idx, 0
                              };
                              b.collect_refs->insert(ref);
                        }
                        if (b.collect_refs_only) {
                              value = Z3_mk_unsigned_int64(
                                    b.ctx, 0, Z3_mk_bv_sort(b.ctx, width));
                              return;
                        }
                        if (b.graph->active(idx)) {
                              value = scalar_property_ref_(b, idx, width, sflag);
                              return;
                        }
                  }
                  vvp_vector4_t data;
                  owner->get_vec4(member, data);
                  uint64_t bits = 0;
                  if (!vec4_to_uint64_(data, bits)) {
                        b.side_constraints.push_back(
                              validity);
                        bits = 0;
                  }
                  value = Z3_mk_unsigned_int64(
                        b.ctx, bits, Z3_mk_bv_sort(b.ctx, width));
                  if (sflag) value = b.tag_signed_constant(value);
            };
            Z3_ast yes, no;
            field(yes_object, yes_read, yes_error, yes_failure,
                  Z3_mk_not(b.ctx, cond), yes);
            field(no_object, no_read, no_error, no_failure, cond, no);
            Z3_ast value = Z3_mk_ite(b.ctx, cond, yes, no);
            b.set_sv(value, width);
            if (sflag) b.signed_vars.insert(value);
            return value;
      }

	/* Dynamic-array foreach template (IEEE 1800-2017 18.5.8.2).
	 * Size pass: capture the body and contribute `true` (the size
	 * variables elsewhere in the IR still participate). Element
	 * pass: expand the body once per element with the loop token
	 * bound to each index and conjoin the instances. */
      if (op == "dynforeach") {
	    string hdr = par.read_token();
	    unsigned pidx, ewid; bool esig;
	    parse_pws_header(hdr, pidx, ewid, esig);
            pidx = b.property_index(pidx);
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

      /* Associative foreach over class-valued keys. The key set is state at
	 * randomize time; expand every actual key and let qkeymember read that
	 * key's current scalar state. */
      if (op == "assocforeach") {
	    string property_token = par.read_token();
	    char*end = nullptr;
	    unsigned long local = strtoul(property_token.c_str(), &end, 10);
	    string body = capture_balanced_form(par);
	    if (end == property_token.c_str() || *end) {
		  b.state_errors.push_back("malformed associative foreach constraint");
		  return b.mk_true();
	    }
	    unsigned pidx = b.property_index((unsigned)local);
	    vvp_object_t object;
	    b.object(pidx)->get_object(b.local_index(pidx), object, 0);
	    vvp_assoc_base*assoc = object.peek<vvp_assoc_base>();
	    if (!assoc) {
		  b.state_errors.push_back("associative foreach property is not a live associative array");
		  return b.mk_true();
	    }
	    Z3_ast conjunction = b.mk_true();
	    vvp_object_t key;
	    for (bool ok = assoc->first_key(key); ok; ok = assoc->next_key(key)) {
		  vvp_cobject*key_object = key.peek<vvp_cobject>();
		  if (!key_object) {
			b.state_errors.push_back("associative foreach key is not a class object");
			return b.mk_true();
		  }
		  IRParser instance(body);
		  vvp_cobject*saved = b.assoc_foreach_key;
		  b.assoc_foreach_key = key_object;
		  Z3_ast term = bv_to_bool(b.ctx, build_z3_atom(instance, b));
		  b.assoc_foreach_key = saved;
		  if (!instance.at_end()) {
			b.state_errors.push_back("malformed associative foreach body");
			return b.mk_true();
		  }
		  Z3_ast args[2] = {conjunction, term};
		  conjunction = Z3_mk_and(b.ctx, 2, args);
	    }
	    return conjunction;
      }

      if (op == "qkeymember") {
	    string header = par.read_token();
	    unsigned member = 0, width = 0; bool sign = false;
	    parse_pws_header(header, member, width, sign);
	    par.skip_ws(); par.expect(')');
	    vvp_cobject*key = b.assoc_foreach_key;
	    if (!key || member >= key->get_defn()->property_count()) {
		  b.state_errors.push_back("missing/invalid associative foreach class key member");
		  return Z3_mk_unsigned_int64(b.ctx, 0, Z3_mk_bv_sort(b.ctx, width));
	    }
	    if (b.graph) {
		  unsigned idx = b.graph->intern(key, member);
		  return scalar_property_ref_(b, idx, width, sign);
	    }
	    vvp_vector4_t value;
	    key->get_vec4(member, value, 0);
	    if (value.size() != width) {
		  b.state_errors.push_back("associative foreach key member width mismatch");
		  return Z3_mk_unsigned_int64(b.ctx, 0, Z3_mk_bv_sort(b.ctx, width));
	    }
	    uint64_t bits = 0;
	    for (unsigned bit = 0; bit < width; ++bit) {
		  if (value.value(bit) != BIT4_0 && value.value(bit) != BIT4_1) {
			b.state_errors.push_back("X/Z associative foreach key member state");
			return Z3_mk_unsigned_int64(b.ctx, 0, Z3_mk_bv_sort(b.ctx, width));
		  }
		  if (value.value(bit) == BIT4_1 && bit < 64) bits |= UINT64_C(1) << bit;
	    }
	    Z3_ast result = Z3_mk_unsigned_int64(b.ctx, bits,
		  Z3_mk_bv_sort(b.ctx, width));
	    b.set_sv(result, width);
	    if (sign) result = b.tag_signed_constant(result);
	    return result;
      }

	/* Element reference within an expanded dynforeach body:
	 * (delem P:W[:s] <const-index-ir>) -> element variable. */
      /* (qmelem <qprop>:<member>:<width>[:s] <const-index-ir>) */
      if (op == "qmelem") {
	    string hdr = par.read_token();
	    unsigned qprop = 0, member = 0, width = 32; bool sflag = false;
	    { const char*c = hdr.c_str();
	      qprop = (unsigned)atoi(c);
	      while (*c && *c != ':') ++c;
	      if (*c == ':') { member = (unsigned)atoi(c+1); ++c; }
	      while (*c && *c != ':') ++c;
	      if (*c == ':') { width = (unsigned)atoi(c+1); ++c; }
	      while (*c && *c != ':') ++c;
	      sflag = (*c == ':' && c[1] == 's'); }
	    if (width == 0) width = 32;
	    uint64_t idx64 = 0;
	    bool ok = eval_const_ir(par, idx64);
	    par.skip_ws(); par.expect(')');
            vvp_object_t element;
            string error;
            if (!ok) error = "object-member constraint index is not constant after foreach expansion";
            else constraint_object_element_(b.cobj, qprop, idx64, element, error);
            vvp_cobject*owner = element.peek<vvp_cobject>();
            if (error.empty() && (!owner || member >= owner->get_defn()->property_count()))
                  error = "null/invalid constraint object member";
            if (!error.empty()) {
                  b.state_errors.push_back(error);
                  return Z3_mk_unsigned_int64(b.ctx, 0, Z3_mk_bv_sort(b.ctx, width));
            }
            if (b.graph) {
                  unsigned idx = b.graph->intern(owner, member);
                  return scalar_property_ref_(b, idx, width, sflag);
            }
	    if (b.collect_refs_only)
		  return Z3_mk_unsigned_int64(b.ctx, 0,
					      Z3_mk_bv_sort(b.ctx, width));
	    Z3_ast var = b.get_qelem_var(qprop, (unsigned)idx64, member, width);
	    if (sflag) b.signed_vars.insert(var);
	    return var;
      }

      /* Fixed unpacked-array selection. The compiler supplies each declared
       * dimension as LOW:WIDTH followed by its index expressions. Build the
       * selection from the existing e: leaves. Table 7-1 makes an invalid
       * 2-state read zero. A ground invalid 4-state state read is an 18.3
       * evaluation error; retain symbolic validity for a random selector. */
      if (op == "fsel") {
	    string hdr = par.read_token();
	    unsigned pidx, width; bool sflag;
	    parse_pws_header(hdr, pidx, width, sflag);
	    pidx = b.property_index(pidx);
	    string count_token = par.read_token();
	    if (count_token.compare(0, 2, "c:") != 0) {
		  b.state_errors.push_back("malformed fixed-array selection rank");
		  return b.mk_true();
	    }
	    char*end = nullptr;
	    unsigned long count = strtoul(count_token.c_str() + 2, &end, 10);
	    if (end == count_token.c_str() + 2 || *end || count == 0) {
		  b.state_errors.push_back("invalid fixed-array selection rank");
		  return b.mk_true();
	    }
	    string state_token = par.read_token();
	    if (state_token.compare(0, 2, "c:") != 0
		|| state_token.size() == 2) {
		  b.state_errors.push_back("invalid fixed-array selection state kind");
		  return b.mk_true();
	    }
	    unsigned long two_state = strtoul(state_token.c_str() + 2, &end, 10);
	    if (end == state_token.c_str() + 2 || *end || two_state > 1) {
		  b.state_errors.push_back("invalid fixed-array selection state kind");
		  return b.mk_true();
	    }
	    vector<int64_t> lows(count);
	    vector<unsigned long> spans(count);
	    unsigned long words = 1;
	    for (unsigned long dim = 0; dim < count; ++dim) {
		  string descriptor = par.read_token();
		  char*colon = nullptr;
		  long long parsed_low = strtoll(descriptor.c_str(), &colon, 10);
		  if (colon == descriptor.c_str() || *colon != ':') {
			b.state_errors.push_back("malformed fixed-array selection dimension");
			return b.mk_true();
		  }
		  lows[dim] = (int64_t)parsed_low;
		  spans[dim] = strtoul(colon + 1, &end, 10);
		  if (end == colon + 1 || *end || spans[dim] == 0
		      || words > UINT_MAX / spans[dim]) {
			b.state_errors.push_back("invalid fixed-array selection dimension");
			return b.mk_true();
		  }
		  words *= spans[dim];
	    }
	    vector<Z3_ast> indices;
	    set<Z3Builder::VarRef> index_refs;
	    set<Z3Builder::VarRef>*saved_refs = b.collect_refs;
	    unsigned outer_context = b.integral_context_width;
	    int outer_sign = b.integral_context_sign;
	    b.integral_context_width = 0;
	    b.integral_context_sign = -1;
	    b.collect_refs = &index_refs;
	    indices.reserve(count);
	    for (unsigned long dim = 0; dim < count; ++dim)
		  indices.push_back(build_z3_atom(par, b));
	    b.collect_refs = saved_refs;
	    b.integral_context_width = outer_context;
	    b.integral_context_sign = outer_sign;
	    if (saved_refs) saved_refs->insert(index_refs.begin(), index_refs.end());
	    par.skip_ws(); par.expect(')');
	    Z3_ast valid = Z3_mk_false(b.ctx);
	    vector<Z3_ast> matches(words);
	    Z3_ast selected = Z3_mk_unsigned_int64(
		  b.ctx, 0, Z3_mk_bv_sort(b.ctx, width ? width : 32));
	    for (unsigned long word = words; word-- > 0;) {
		  unsigned long ordinal = word;
		  Z3_ast match = Z3_mk_true(b.ctx);
		  for (size_t dim = count; dim-- > 0;) {
			unsigned long digit = ordinal % spans[dim];
			ordinal /= spans[dim];
			if ((uint64_t)digit > (uint64_t)INT64_MAX
			    || lows[dim] > INT64_MAX - (int64_t)digit) {
			      b.state_errors.push_back(
			            "fixed-array declared index exceeds signed 64-bit representation");
			      return b.mk_true();
			}
			int64_t declared_value = lows[dim] + (int64_t)digit;
			Z3_ast declared = b.tag_signed_constant(Z3_mk_unsigned_int64(
			      b.ctx, (uint64_t)declared_value,
			      Z3_mk_bv_sort(b.ctx, 64)));
			// Compare mathematical index values, not same-width modular bit
			// patterns. The guard bit keeps unsigned 64'hffff... distinct
			// from signed -1, while each operand retains its own extension.
			unsigned common = max(b.sv_of(indices[dim]), 64u) + 1;
			Z3_ast equal = Z3_mk_eq(b.ctx,
			      b.coerce(indices[dim], common),
			      b.coerce(declared, common));
			Z3_ast both[2] = {match, equal};
			match = Z3_mk_and(b.ctx, 2, both);
		  }
		  matches[word] = match;
		  if (b.collect_refs) {
			Z3Builder::VarRef ref = {Z3Builder::VarRef::ELEM, pidx, (unsigned)word};
			b.collect_refs->insert(ref);
		  }
		  Z3_ast leaf = b.collect_refs_only
			? Z3_mk_unsigned_int64(b.ctx, 0, Z3_mk_bv_sort(b.ctx, width ? width : 32))
			: b.get_elem_var(pidx, width, (unsigned)word);
		  if (sflag) b.signed_vars.insert(leaf);
		  selected = Z3_mk_ite(b.ctx, match, leaf, selected);
		  Z3_ast either[2] = {valid, match};
		  valid = Z3_mk_or(b.ctx, 2, either);
	    }
	    if (!two_state) {
		  Z3_lbool validity = b.collect_refs_only
			? Z3_L_UNDEF : state_guard_truth_(b, valid, index_refs);
		  if (validity == Z3_L_UNDEF) {
		    if (!b.collect_refs_only && b.collect_preferences) {
			Z3Builder::StateCheck check = {
			      Z3_mk_not(b.ctx, valid),
			      "invalid 4-state fixed-array index in constraint"
			};
			b.state_checks.push_back(check);
			vector<Z3_ast> unknown_matches;
			for (unsigned long word = 0; word < words; ++word) {
			      if (rand_elem_active_(b, b.prop_active, pidx,
			                            (unsigned)word)) continue;
			      vvp_vector4_t value;
			      b.object(pidx)->get_vec4(
			            b.local_index(pidx), value, (unsigned)word);
			      if (!vec4_is_two_state_(value))
			            unknown_matches.push_back(matches[word]);
			}
			if (!unknown_matches.empty()) {
			      Z3_ast selected_unknown = unknown_matches.size() == 1
			            ? unknown_matches[0]
			            : Z3_mk_or(b.ctx, (unsigned)unknown_matches.size(),
			                       unknown_matches.data());
			      Z3Builder::StateCheck unknown_check = {
			            selected_unknown,
			            "X/Z fixed-array state element in constraint"
			      };
			      b.state_checks.push_back(unknown_check);
			}
		    }
		  }
		  else if (validity == Z3_L_FALSE)
			b.state_errors.push_back(
			      "invalid 4-state fixed-array index in constraint");
		  else for (unsigned long word = 0; word < words; ++word) {
			if (state_guard_truth_(b, matches[word], index_refs)
			    != Z3_L_TRUE) continue;
			if (!rand_elem_active_(b, b.prop_active, pidx, (unsigned)word)) {
			      vvp_vector4_t value;
			      b.object(pidx)->get_vec4(
				    b.local_index(pidx), value, (unsigned)word);
			      if (!vec4_is_two_state_(value))
				    b.state_errors.push_back(
					  "X/Z fixed-array state element in constraint");
			}
			break;
		  }
	    }
	    b.set_sv(selected, width ? width : 32);
	    if (sflag) b.signed_vars.insert(selected);
	    return selected;
      }

      if (op == "delem") {
	    string hdr = par.read_token();
	    unsigned pidx, ewid; bool esig;
	    parse_pws_header(hdr, pidx, ewid, esig);
            pidx = b.property_index(pidx);
	    uint64_t idx64 = 0;
	    bool ok = eval_const_ir(par, idx64);
	    par.skip_ws(); par.expect(')');
	    /* Element identities are represented by an unsigned leaf index.  Do
	     * not truncate a wider constant into a different live element.  Keep
	     * the full value in the parse error so every caller rejects the form
	     * before planning or sampling. */
	    if (ok && idx64 > UINT_MAX) {
		  ostringstream msg;
		  msg << "dynamic array constraint element index " << idx64
		      << " exceeds the supported index representation";
		  b.state_errors.push_back(msg.str());
		  return Z3_mk_unsigned_int64(
			b.ctx, 0, Z3_mk_bv_sort(b.ctx, ewid));
	    }
	    /* Planning precedes the size solve. An active dynamic element may be
	     * created by that solve, so retain its typed dependency without
	     * comparing it with the old container bound. The normal/second pass
	     * below validates the solved bound before enforcing the element. */
	    if (ok && b.collect_refs_only && b.graph
	        && b.graph->size_active(pidx)) {
		  if (b.collect_refs) {
			Z3Builder::VarRef ref = {
			      Z3Builder::VarRef::ELEM, pidx, (unsigned)idx64
			};
			b.collect_refs->insert(ref);
		  }
		  return Z3_mk_unsigned_int64(
			b.ctx, 0, Z3_mk_bv_sort(b.ctx, ewid));
	    }
	    if (ok && !b.dyn_sizes && b.graph
	        && b.graph->size_active(pidx)) {
		  if (b.collect_refs) {
			Z3Builder::VarRef ref = {
			      Z3Builder::VarRef::ELEM, pidx, (unsigned)idx64
			};
			b.collect_refs->insert(ref);
		  }
		  Z3_ast var = b.get_elem_var(pidx, ewid, (unsigned)idx64);
		  if (esig) b.signed_vars.insert(var);
		  return var;
	    }
	    uint64_t count = 0;
	    bool have_count = false;
	    if (b.dyn_sizes) {
		  auto it = b.dyn_sizes->find(pidx);
		  if (it != b.dyn_sizes->end()) {
			count = it->second;
			have_count = true;
		  }
	    }
	    /* Inactive dynamic arrays are absent from the solved-size map.  Their
	     * elements are state, so bound direct element references with the
	     * current object size and let the normal state pinning constrain the
	     * element value. */
	    if (!have_count) {
		  count = cobj_darray_size(b.object(pidx), b.local_index(pidx));
		  have_count = true;
	    }
	    if (!ok || idx64 >= count) {
		  ostringstream msg;
		  msg << "dynamic array constraint element index ";
		  if (!ok)
			msg << "is not constant after expansion";
		  else
			msg << idx64 << " is outside property " << pidx
			    << " size " << count;
		  b.state_errors.push_back(msg.str());
		  return Z3_mk_unsigned_int64(
			b.ctx, 0, Z3_mk_bv_sort(b.ctx, ewid));
	    }
	    if (b.collect_refs) {
		  Z3Builder::VarRef ref = {
			Z3Builder::VarRef::ELEM, pidx, (unsigned)idx64
		  };
		  b.collect_refs->insert(ref);
	    }
	    if (b.collect_refs_only)
		  return Z3_mk_unsigned_int64(
			b.ctx, 0, Z3_mk_bv_sort(b.ctx, ewid));
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
            vector<Z3Builder::OrderRef> groups[2];
            for (unsigned group = 0; group < 2; ++group) {
                  if (!par.expect('(') || par.read_token() != "vars") {
                        if (b.graph) b.graph->valid = false;
                        break;
                  }
                  while (par.peek() && par.peek() != ')') {
                        set<Z3Builder::VarRef> refs;
                        auto*saved = b.collect_refs;
                        b.collect_refs = &refs;
                        const char*start = par.p;
                        (void)build_z3_atom(par, b);
                        b.collect_refs = saved;
                        if (par.p == start) {
                              if (b.graph) b.graph->valid = false;
                              break;
                        }
                        if (refs.empty() && b.graph) b.graph->valid = false;
                        for (const auto&ref : refs) {
                              Z3Builder::OrderRef ordered;
                              ordered.kind = static_cast<Z3Builder::OrderRef::Kind>(ref.kind);
                              ordered.idx = ref.idx;
                              ordered.elem = ref.leaf;
			      ordered.subelem = ref.subleaf;
                              groups[group].push_back(ordered);
                        }
                  }
                  par.expect(')');
            }
            par.expect(')');
            for (const auto&a : groups[0])
                  for (const auto&c : groups[1]) b.order_pairs.push_back({a, c});
            return b.mk_true();
      }

      /* Packed selection forms used by scope-randomization constraints.
       * The select index may itself be randomized. Fixed part-select bounds
       * have already had caller value slots substituted with constants. */
      if (op == "bit") {
	    unsigned outer_context = b.integral_context_width;
	    int outer_sign = b.integral_context_sign;
	    b.integral_context_width = 0;
	    b.integral_context_sign = -1;
	    Z3_ast base = build_z3_atom(par, b);
	    Z3_ast idx = build_z3_atom(par, b);
	    b.integral_context_width = outer_context;
	    b.integral_context_sign = outer_sign;
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
	    unsigned outer_context = b.integral_context_width;
	    int outer_sign = b.integral_context_sign;
	    b.integral_context_width = 0;
	    b.integral_context_sign = -1;
	    Z3_ast base = build_z3_atom(par, b);
	    uint64_t hi = 0, lo = 0;
	    bool ok = eval_const_ir(par, hi) && eval_const_ir(par, lo);
	    b.integral_context_width = outer_context;
	    b.integral_context_sign = outer_sign;
	    par.skip_ws(); par.expect(')');
	    unsigned bw = bv_width(b.ctx, base);
	    if (!ok || hi < lo || hi >= bw) return mk_free_bv(b, 1);
	    return Z3_mk_extract(b.ctx, (unsigned)hi, (unsigned)lo, base);
      }

      if (op == "concat") {
	    unsigned outer_context = b.integral_context_width;
	    int outer_sign = b.integral_context_sign;
	    b.integral_context_width = 0;
	    b.integral_context_sign = -1;
	    vector<Z3_ast> parts;
	    par.skip_ws();
	    while (par.peek() != ')' && !par.at_end()) {
		  parts.push_back(build_z3_atom(par, b));
		  par.skip_ws();
	    }
	    b.integral_context_width = outer_context;
	    b.integral_context_sign = outer_sign;
	    par.expect(')');
	    if (parts.empty())
		  return Z3_mk_unsigned_int64(b.ctx, 0,
					      Z3_mk_bv_sort(b.ctx, 1));
	    Z3_ast out = parts[0];
	    for (size_t i = 1 ; i < parts.size() ; i += 1)
		  out = Z3_mk_concat(b.ctx, out, parts[i]);
	    return out;
      }

      /* Integral type/size/sign cast. WIDTH 0 and SIGN 2 preserve the
	 * operand's self-determined width and signedness, respectively. Build the
	 * operand under its propagated type before final narrowing. Extension follows the
	 * operand's signedness; the requested signedness applies to the resulting
	 * occurrence and to its later consumers. */
      if (op == "cast") {
	    uint64_t width_value = 0, sign_value = 0;
	    bool width_ok = eval_const_ir(par, width_value);
	    bool sign_ok = eval_const_ir(par, sign_value);
	    unsigned saved_context = b.integral_context_width;
	    int saved_context_sign = b.integral_context_sign;
	    bool saved_typed_mode = b.integral_typed_mode;
	    constraint_integral_type_t inner_type;
	    IRParser type_parser = par;
	    bool type_ok = infer_constraint_integral_type_(type_parser, inner_type);
	    b.integral_typed_mode = type_ok;
	    b.integral_context_width = width_ok && width_value <= UINT_MAX
		  ? (width_value ? (unsigned)width_value
		                 : type_ok ? inner_type.width : 0) : 0;
	    b.integral_context_sign = -1;
	    Z3_ast arg = build_z3_atom(par, b);
	    b.integral_context_width = saved_context;
	    b.integral_context_sign = saved_context_sign;
	    b.integral_typed_mode = saved_typed_mode;
	    par.skip_ws(); par.expect(')');
	    arg = bool_to_bv1(b.ctx, arg);
	    if (!width_ok || !sign_ok || !type_ok
		|| width_value > UINT_MAX || sign_value > 2) {
		  b.state_errors.push_back(
			"unsupported integral expression in constraint cast");
		  return mk_free_bv(b, 1);
	    }
	    unsigned width = width_value ? (unsigned)width_value : b.sv_of(arg);
	    if (!width) return mk_free_bv(b, 1);
	    bool is_signed = sign_value == 2 ? b.is_signed(arg)
		  : sign_value == 1;
	    Z3_ast value = b.coerce(arg, width);
	    return b.tag_integral_cast(value, width, is_signed);
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
	    unsigned outer_context = b.integral_context_width;
	    int outer_sign = b.integral_context_sign;
	    b.integral_context_width = 0;
	    b.integral_context_sign = -1;
	    Z3_ast arg = build_z3_atom(par, b);
	    b.integral_context_width = outer_context;
	    b.integral_context_sign = outer_sign;
	    par.skip_ws(); par.expect(')');
	    if (width == 0) return mk_free_bv(b, 1);
	      /* A relational/logical with expression is an integral 1-bit
	       * SystemVerilog value but is represented internally by a Z3 Bool.
	       * Re-enter the bitvector domain at this explicit width boundary. */
	    arg = bool_to_bv1(b.ctx, arg);
	    Z3_ast out = b.coerce(arg, width);
	    return b.typed_result(out, width, is_signed);
      }

      if (op == "countones") {
	    unsigned outer_context = b.integral_context_width;
	    int outer_sign = b.integral_context_sign;
	    b.integral_context_width = 0;
	    b.integral_context_sign = -1;
	    Z3_ast arg = build_z3_atom(par, b);
	    b.integral_context_width = outer_context;
	    b.integral_context_sign = outer_sign;
	    par.skip_ws(); par.expect(')');
	    unsigned aw = bv_width(b.ctx, arg);
	    Z3_sort out_sort = Z3_mk_bv_sort(b.ctx, 32);
	    Z3_ast sum = Z3_mk_unsigned_int64(b.ctx, 0, out_sort);
	    for (unsigned i = 0 ; i < aw ; i += 1) {
		  Z3_ast bit = Z3_mk_extract(b.ctx, i, i, arg);
		  Z3_ast wide = Z3_mk_zero_ext(b.ctx, 31, bit);
		  sum = Z3_mk_bvadd(b.ctx, sum, wide);
	    }
	    return b.typed_result(sum, 32, true);
      }

      if (op == "onehot" || op == "onehot0") {
	    unsigned outer_context = b.integral_context_width;
	    int outer_sign = b.integral_context_sign;
	    b.integral_context_width = 0;
	    b.integral_context_sign = -1;
	    Z3_ast arg = build_z3_atom(par, b);
	    b.integral_context_width = outer_context;
	    b.integral_context_sign = outer_sign;
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
	    size_t before = b.state_errors.size();
	    size_t side_before = b.side_constraints.size();
	    Z3_lbool condition, yes_guard, no_guard;
	    unsigned saved_width = b.integral_context_width;
	    int saved_sign = b.integral_context_sign;
	    unsigned expression_context = saved_width;
	    bool result_signed = false;
	    bool typed = b.integral_typed_mode;
	    if (typed) {
		  IRParser types = par;
		  constraint_integral_type_t condition_type, yes_type, no_type;
		  if (!infer_constraint_integral_type_(types, condition_type)
		      || !infer_constraint_integral_type_(types, yes_type)
		      || !infer_constraint_integral_type_(types, no_type)) {
			b.state_errors.push_back(
			      "unsupported typed conditional in constraint cast");
		  } else {
			expression_context = max(saved_width,
			      max(yes_type.width, no_type.width));
			result_signed = saved_sign >= 0 ? saved_sign != 0
			      : yes_type.sign && no_type.sign;
		  }
	    }
	    b.integral_context_width = 0; // condition is self-determined
	    b.integral_context_sign = -1;
	    Z3_ast cond = bv_to_bool(b.ctx, build_z3_atom(par, b, &condition));
	    b.integral_context_width = expression_context;
	    b.integral_context_sign = result_signed ? 1 : 0;
	    size_t after_cond = b.state_errors.size();
	    size_t side_after_cond = b.side_constraints.size();
	    size_t checks_after_cond = b.state_checks.size();
	    Z3_ast yes = build_z3_atom(par, b, &yes_guard);
	    size_t after_yes = b.state_errors.size();
	    size_t side_after_yes = b.side_constraints.size();
	    size_t checks_after_yes = b.state_checks.size();
	    Z3_ast no = build_z3_atom(par, b, &no_guard);
	    leave_typed_context_(b, saved_width, saved_sign);
	    size_t side_after_no = b.side_constraints.size();
	    size_t checks_after_no = b.state_checks.size();
	    constraint_guard_state_checks_(b, checks_after_cond,
	                                  checks_after_yes, cond);
	    constraint_guard_state_checks_(b, checks_after_yes,
	                                  checks_after_no, Z3_mk_not(b.ctx, cond));
	    Z3_ast cond_valid = constraint_side_conjunction_(
		  b, side_before, side_after_cond);
	    Z3_ast yes_valid = constraint_side_conjunction_(
		  b, side_after_cond, side_after_yes);
	    Z3_ast no_valid = constraint_side_conjunction_(
		  b, side_after_yes, side_after_no);
	    b.side_constraints.resize(side_before);
	    Z3_ast selected_valid[3] = {
		  cond_valid, Z3_mk_implies(b.ctx, cond, yes_valid),
		  Z3_mk_implies(b.ctx, Z3_mk_not(b.ctx, cond), no_valid)
	    };
	    b.side_constraints.push_back(Z3_mk_and(b.ctx, 3, selected_valid));
	    if (before == after_cond) {
                  if (condition == Z3_L_TRUE) b.state_errors.resize(after_yes);
                  else if (condition == Z3_L_FALSE)
                        b.state_errors.erase(b.state_errors.begin() + after_cond,
                                             b.state_errors.begin() + after_yes);
            }
            if (guard && condition != Z3_L_UNDEF)
                  *guard = condition == Z3_L_TRUE ? yes_guard : no_guard;
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
	    if (expression_context > sw) sw = expression_context;
            // Both arms determine the common type, including the unchosen
            // arm (IEEE 1800-2017/2023 11.6.1, 11.8.1, 11.8.2).
	    if (!typed) result_signed = b.is_signed(yes) && b.is_signed(no);
	    yes = b.coerce_in_context(yes, sw, result_signed);
	    no = b.coerce_in_context(no, sw, result_signed);
	    Z3_ast out = Z3_mk_ite(b.ctx, cond, yes, no);
	    return b.typed_result(out, sw, result_signed);
      }

      if (op == "and" || op == "or") {
	    size_t before = b.state_errors.size();
	    size_t side_before = b.side_constraints.size();
	    size_t checks_before = b.state_checks.size();
	    Z3_lbool left_guard, right_guard;
	    unsigned outer_context = b.integral_context_width;
	    int outer_sign = b.integral_context_sign;
	    b.integral_context_width = 0;
	    b.integral_context_sign = -1;
	    Z3_ast left  = bv_to_bool(b.ctx, build_z3_atom(par, b, &left_guard));
	    size_t after_left = b.state_errors.size();
	    size_t side_after_left = b.side_constraints.size();
	    size_t checks_after_left = b.state_checks.size();
	    Z3_ast right = bv_to_bool(b.ctx, build_z3_atom(par, b, &right_guard));
	    b.integral_context_width = outer_context;
	    b.integral_context_sign = outer_sign;
	    size_t side_after_right = b.side_constraints.size();
	    size_t checks_after_right = b.state_checks.size();
	    Z3_ast left_error = constraint_state_error_disjunction_(
	          b, checks_before, checks_after_left);
	    Z3_ast right_error = constraint_state_error_disjunction_(
	          b, checks_after_left, checks_after_right);
	    Z3_ast left_decides = op == "and"
		  ? Z3_mk_not(b.ctx, left) : left;
	    Z3_ast right_decides = op == "and"
		  ? Z3_mk_not(b.ctx, right) : right;
	    Z3_ast left_sift_args[2] = {
		  Z3_mk_not(b.ctx, right_error), right_decides
	    };
	    Z3_ast right_sift_args[2] = {
		  Z3_mk_not(b.ctx, left_error), left_decides
	    };
	    constraint_guard_state_checks_(b, checks_before, checks_after_left,
	          Z3_mk_not(b.ctx, Z3_mk_and(b.ctx, 2, left_sift_args)));
	    constraint_guard_state_checks_(b, checks_after_left, checks_after_right,
	          Z3_mk_not(b.ctx, Z3_mk_and(b.ctx, 2, right_sift_args)));
	    Z3_ast left_valid = constraint_side_conjunction_(
		  b, side_before, side_after_left);
	    Z3_ast right_valid = constraint_side_conjunction_(
		  b, side_after_left, side_after_right);
	    b.side_constraints.resize(side_before);
	    Z3_ast left_or_right_valid[2] = { left_decides, right_valid };
	    Z3_ast left_path[2] = {
		  left_valid, Z3_mk_or(b.ctx, 2, left_or_right_valid)
	    };
	    Z3_ast right_path[2] = { right_valid, right_decides };
	    Z3_ast either_path[2] = {
		  Z3_mk_and(b.ctx, 2, left_path),
		  Z3_mk_and(b.ctx, 2, right_path)
	    };
	    b.side_constraints.push_back(Z3_mk_or(b.ctx, 2, either_path));
            Z3_lbool deciding = op == "and" ? Z3_L_FALSE : Z3_L_TRUE;
            if ((before == after_left
                 && left_guard == deciding)
                || (after_left == b.state_errors.size()
                    && right_guard == deciding)) {
                  b.state_errors.resize(before);
                  if (guard) *guard = deciding;
            } else if (guard && left_guard != Z3_L_UNDEF && right_guard != Z3_L_UNDEF)
                  *guard = left_guard;
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
	    size_t before = b.state_errors.size();
	    size_t side_before = b.side_constraints.size();
	    Z3_lbool left_guard;
	    unsigned outer_context = b.integral_context_width;
	    int outer_sign = b.integral_context_sign;
	    b.integral_context_width = 0;
	    b.integral_context_sign = -1;
	    Z3_ast left  = bv_to_bool(b.ctx, build_z3_atom(par, b, &left_guard));
	    size_t after_left = b.state_errors.size();
	    size_t side_after_left = b.side_constraints.size();
	    size_t checks_after_left = b.state_checks.size();
            if (op == "impl" && before == after_left && left_guard == Z3_L_FALSE) {
                  // Eliminate the guarded constraint before registering any
                  // soft/disable-soft/order/foreach side effects.
		  if (par.peek() == '(') { par.consume(); capture_balanced_form(par); }
		  else par.read_token();
		  par.expect(')');
		  b.integral_context_width = outer_context;
	    b.integral_context_sign = outer_sign;
                  if (guard) *guard = Z3_L_TRUE;
                  return b.mk_true();
            }
	    if (op == "impl") b.soft_guards.push_back(left);
	    Z3_ast right = bv_to_bool(b.ctx, build_z3_atom(par, b));
	    b.integral_context_width = outer_context;
	    b.integral_context_sign = outer_sign;
	    if (op == "impl") b.soft_guards.pop_back();
	    size_t side_after_right = b.side_constraints.size();
	    size_t checks_after_right = b.state_checks.size();
	    if (op == "impl")
	          constraint_guard_state_checks_(b, checks_after_left,
	                                        checks_after_right, left);
	    Z3_ast left_valid = constraint_side_conjunction_(
		  b, side_before, side_after_left);
	    Z3_ast right_valid = constraint_side_conjunction_(
		  b, side_after_left, side_after_right);
	    b.side_constraints.resize(side_before);
	    Z3_ast validity = op == "impl"
		  ? Z3_mk_implies(b.ctx, left, right_valid)
		  : right_valid;
	    Z3_ast both_valid[2] = { left_valid, validity };
	    b.side_constraints.push_back(Z3_mk_and(b.ctx, 2, both_valid));
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
	    unsigned saved_width = b.integral_context_width;
	    int saved_sign = b.integral_context_sign;
	    unsigned typed_width = 0;
	    bool typed_sign = false;
	    bool typed = b.integral_typed_mode;
	    if (typed && !enter_typed_binary_context_(
		  par, b, true, saved_width, saved_sign,
		  typed_width, typed_sign))
		  b.state_errors.push_back(
			"unsupported typed power in constraint cast");
	    Z3_ast left = build_z3_atom(par, b);
	    unsigned expression_context = typed ? typed_width
		  : b.integral_context_width;
	    int expression_sign = b.integral_context_sign;
	    b.integral_context_width = 0; // exponent is self-determined
	    b.integral_context_sign = -1;
	    Z3_ast right = build_z3_atom(par, b);
	    if (typed) leave_typed_context_(b, saved_width, saved_sign);
	    else {
		  b.integral_context_width = expression_context;
		  b.integral_context_sign = expression_sign;
	    }
	    par.skip_ws(); par.expect(')');
	    bool result_signed = typed ? typed_sign : b.is_signed(left);

	    unsigned sw = b.sv_of(left);
	    if (expression_context > sw) sw = expression_context;
	    if (sw == 0) sw = 32;
	    left = b.coerce_in_context(left, sw, result_signed);
	    Z3_sort sort = Z3_mk_bv_sort(b.ctx, sw);
	    Z3_ast result = Z3_mk_unsigned_int64(b.ctx, 1, sort);

	      /* Most constraint exponents are state constants (array widths,
	         register widths). Use exponentiation by squaring when the AST
	         is ground; retain a bit-select ITE form for a solver exponent. */
	    uint64_t exponent = 0;
	    Z3_ast simplified = Z3_simplify(
		  b.ctx, b.resolve_signed_constants(right));
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
	    return b.typed_result(result, sw, result_signed);
      }

      if (op == "add" || op == "sub" || op == "mul"
	  || op == "div" || op == "mod") {
	    unsigned saved_width = b.integral_context_width;
	    int saved_sign = b.integral_context_sign;
	    unsigned typed_width = 0;
	    bool typed_sign = false;
	    bool typed = b.integral_typed_mode;
	    if (typed && !enter_typed_binary_context_(
		  par, b, false, saved_width, saved_sign,
		  typed_width, typed_sign))
		  b.state_errors.push_back(
			"unsupported typed arithmetic in constraint cast");
	    Z3_ast left  = build_z3_atom(par, b);
	    Z3_ast right = build_z3_atom(par, b);
	    if (typed) leave_typed_context_(b, saved_width, saved_sign);
	    par.skip_ws(); par.expect(')');
	    // IEEE 1800-2017 11.8.1: a binary arithmetic result is signed
	    // only when both operands are signed. This common context also
	    // controls how both operands extend before the operation.
	    bool result_signed = typed ? typed_sign
		  : b.is_signed(left) && b.is_signed(right);

	    unsigned sv = b.sv_of(left);
	    if (b.sv_of(right) > sv) sv = b.sv_of(right);
	    if (typed) sv = typed_width;
	    else if (b.integral_context_width > sv) sv = b.integral_context_width;

	    unsigned lw = bv_width(b.ctx, left);
	    unsigned rw = bv_width(b.ctx, right);
	    unsigned work = lw > rw ? lw : rw;
	      /* Headroom so the operation itself cannot lose bits: one
		 carry for add/sub, the full lw+rw for a product. */
	    if (!typed && (op == "add" || op == "sub")) work += 1;
	    else if (!typed && op == "mul") work = lw + rw;
	    else if (typed) work = typed_width;
	    if (work < sv) work = sv;

	    left  = b.coerce_in_context(left,  work, result_signed);
	    right = b.coerce_in_context(right, work, result_signed);

	    Z3_ast r;
	    if (op == "add")      r = Z3_mk_bvadd(b.ctx, left, right);
	    else if (op == "sub") r = Z3_mk_bvsub(b.ctx, left, right);
	    else if (op == "mul") r = Z3_mk_bvmul(b.ctx, left, right);
	    else {
		  Z3_ast zero = Z3_mk_unsigned_int64(
			b.ctx, 0, Z3_get_sort(b.ctx, right));
		  Z3_ast zero_divisor = Z3_mk_eq(b.ctx, right, zero);
		  Z3_ast folded_zero_divisor = Z3_simplify(
			b.ctx, b.resolve_signed_constants(zero_divisor));
		  bool may_be_zero = Z3_get_bool_value(
			b.ctx, folded_zero_divisor) != Z3_L_FALSE;
		  if (may_be_zero && !b.collect_refs_only && b.collect_preferences) {
			Z3Builder::StateCheck check = {
			      zero_divisor,
			      op == "div"
				? "division by zero in constraint"
				: "remainder by zero in constraint"
			};
			b.state_checks.push_back(check);
		  }

		  Z3_ast value;
		  if (op == "div") value = result_signed
			? Z3_mk_bvsdiv(b.ctx, left, right)
			: Z3_mk_bvudiv(b.ctx, left, right);
		  else value = result_signed
			? Z3_mk_bvsrem(b.ctx, left, right)
			: Z3_mk_bvurem(b.ctx, left, right);

		  /* Z3 gives division/remainder by zero a total bit-vector value,
		   * while SystemVerilog produces X (11.3.4), which is illegal in a
		   * constraint (18.3). Keep the erroneous branch satisfiable solely
		   * for the relaxed diagnostic solve. Every accepted solve excludes
		   * active zero divisors; inactive branches cannot supply a value. */
		  if (may_be_zero) {
			Z3_ast placeholder = Z3_mk_fresh_const(
			      b.ctx, op == "div" ? "sv_divzero" : "sv_modzero",
			      Z3_get_sort(b.ctx, value));
			r = Z3_mk_ite(b.ctx, zero_divisor, placeholder, value);
		  } else r = value;
	    }
	    return b.typed_result(r, sv, result_signed);
      }

      if (op == "neg") {
	    constraint_integral_type_t inferred;
	    IRParser type_parser = par;
	    bool typed = b.integral_typed_mode;
	    bool type_ok = !typed || infer_constraint_integral_type_(type_parser, inferred);
	    if (!type_ok)
		  b.state_errors.push_back(
			"unsupported typed unary expression in constraint cast");
	    Z3_ast arg = build_z3_atom(par, b);
	    par.skip_ws(); par.expect(')');
	    unsigned width = b.sv_of(arg);
	    if (b.integral_context_width > width)
		  width = b.integral_context_width;
	    bool result_signed = typed && b.integral_context_sign >= 0
		  ? b.integral_context_sign != 0
		  : typed && type_ok ? inferred.sign : b.is_signed(arg);
	    arg = b.coerce_in_context(arg, width, result_signed);
	    Z3_ast out = Z3_mk_bvneg(b.ctx, arg);
	    return b.typed_result(out, width, result_signed);
      }

      if (op == "band" || op == "bor" || op == "bxor") {
	    unsigned saved_width = b.integral_context_width;
	    int saved_sign = b.integral_context_sign;
	    unsigned typed_width = 0;
	    bool typed_sign = false;
	    bool typed = b.integral_typed_mode;
	    if (typed && !enter_typed_binary_context_(
		  par, b, false, saved_width, saved_sign,
		  typed_width, typed_sign))
		  b.state_errors.push_back(
			"unsupported typed bitwise expression in constraint cast");
	    Z3_ast left = build_z3_atom(par, b);
	    Z3_ast right = build_z3_atom(par, b);
	    if (typed) leave_typed_context_(b, saved_width, saved_sign);
	    par.skip_ws(); par.expect(')');
	    unsigned sw = b.sv_of(left);
	    if (b.sv_of(right) > sw) sw = b.sv_of(right);
	    if (typed) sw = typed_width;
	    else if (b.integral_context_width > sw) sw = b.integral_context_width;
	    bool result_signed = typed ? typed_sign
		  : b.is_signed(left) && b.is_signed(right);
	    left = b.coerce_in_context(left, sw, result_signed);
	    right = b.coerce_in_context(right, sw, result_signed);
	    Z3_ast out = op == "band" ? Z3_mk_bvand(b.ctx, left, right)
		  : op == "bor" ? Z3_mk_bvor(b.ctx, left, right)
		  : Z3_mk_bvxor(b.ctx, left, right);
	    return b.typed_result(out, sw, result_signed);
      }

      if (op == "shl" || op == "lshr" || op == "ashr") {
	    unsigned saved_width = b.integral_context_width;
	    int saved_sign = b.integral_context_sign;
	    unsigned typed_width = 0;
	    bool typed_sign = false;
	    bool typed = b.integral_typed_mode;
	    if (typed && !enter_typed_binary_context_(
		  par, b, true, saved_width, saved_sign,
		  typed_width, typed_sign))
		  b.state_errors.push_back(
			"unsupported typed shift in constraint cast");
	    Z3_ast left = build_z3_atom(par, b);
	    unsigned expression_context = typed ? typed_width
		  : b.integral_context_width;
	    int expression_sign = b.integral_context_sign;
	    b.integral_context_width = 0; // shift count is self-determined
	    b.integral_context_sign = -1;
	    Z3_ast right = build_z3_atom(par, b);
	    if (typed) leave_typed_context_(b, saved_width, saved_sign);
	    else {
		  b.integral_context_width = expression_context;
		  b.integral_context_sign = expression_sign;
	    }
	    par.skip_ws(); par.expect(')');
	    unsigned lw = b.sv_of(left);
	    if (expression_context > lw) lw = expression_context;
	    bool result_signed = typed ? typed_sign : b.is_signed(left);
	    left = b.coerce_in_context(left, lw, result_signed);
	    right = b.coerce(right, lw);
	    Z3_ast out = op == "shl" ? Z3_mk_bvshl(b.ctx, left, right)
		  : op == "lshr" || !result_signed
		    ? Z3_mk_bvlshr(b.ctx, left, right)
		    : Z3_mk_bvashr(b.ctx, left, right);
	    return b.typed_result(out, lw, result_signed);
      }

      if (op == "bnot") {
	    constraint_integral_type_t inferred;
	    IRParser type_parser = par;
	    bool typed = b.integral_typed_mode;
	    bool type_ok = !typed || infer_constraint_integral_type_(type_parser, inferred);
	    if (!type_ok)
		  b.state_errors.push_back(
			"unsupported typed unary expression in constraint cast");
	    Z3_ast arg = build_z3_atom(par, b);
	    par.skip_ws(); par.expect(')');
	    unsigned width = b.sv_of(arg);
	    if (b.integral_context_width > width)
		  width = b.integral_context_width;
	    bool result_signed = typed && b.integral_context_sign >= 0
		  ? b.integral_context_sign != 0
		  : typed && type_ok ? inferred.sign : b.is_signed(arg);
	    arg = b.coerce_in_context(arg, width, result_signed);
	    Z3_ast out = Z3_mk_bvnot(b.ctx, arg);
	    return b.typed_result(out, width, result_signed);
      }

      if (op == "redand" || op == "redor" || op == "redxor") {
	    unsigned outer_context = b.integral_context_width;
	    int outer_sign = b.integral_context_sign;
	    b.integral_context_width = 0;
	    b.integral_context_sign = -1;
	    Z3_ast arg = build_z3_atom(par, b);
	    b.integral_context_width = outer_context;
	    b.integral_context_sign = outer_sign;
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
	    Z3_lbool child_guard;
	    unsigned outer_context = b.integral_context_width;
	    int outer_sign = b.integral_context_sign;
	    b.integral_context_width = 0;
	    b.integral_context_sign = -1;
	    Z3_ast raw = build_z3_atom(par, b, guard ? &child_guard : nullptr);
	    b.integral_context_width = outer_context;
	    b.integral_context_sign = outer_sign;
            if (guard && child_guard != Z3_L_UNDEF)
                  *guard = child_guard == Z3_L_TRUE ? Z3_L_FALSE : Z3_L_TRUE;
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
	    unsigned outer_context = b.integral_context_width;
	    int outer_sign = b.integral_context_sign;
	    if (b.integral_typed_mode) {
		  IRParser types = par;
		  constraint_integral_type_t left_type, right_type;
		  if (!infer_constraint_integral_type_(types, left_type)
		      || !infer_constraint_integral_type_(types, right_type)) {
			b.state_errors.push_back(
			      "unsupported typed comparison in constraint cast");
			b.integral_context_width = 0;
			b.integral_context_sign = -1;
		  } else {
			b.integral_context_width = max(left_type.width, right_type.width);
			b.integral_context_sign = left_type.sign && right_type.sign ? 1 : 0;
		  }
	    } else {
		  b.integral_context_width = 0;
		  b.integral_context_sign = -1;
	    }
	    Z3_ast left  = build_z3_atom(par, b);
	    Z3_ast right = build_z3_atom(par, b);
	    b.integral_context_width = outer_context;
	    b.integral_context_sign = outer_sign;
	    par.skip_ws(); par.expect(')');
	      // A nested comparison is a one-bit SystemVerilog integral value,
	      // although Z3 represents it as Bool. Equality and relational
	      // operators therefore size it like bit[0:0] before comparing.
	    left = bool_to_bv1(b.ctx, left);
	    right = bool_to_bv1(b.ctx, right);

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
	    left  = b.coerce_in_context(left,  ctx_w, use_signed);
	    right = b.coerce_in_context(right, ctx_w, use_signed);

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
	    unsigned outer_context = b.integral_context_width;
	    int outer_sign = b.integral_context_sign;
	    bool typed = b.integral_typed_mode;
	    bool type_ok = false;
	    constraint_integral_type_t common_type;
	    if (typed) {
		  IRParser types = par;
		  type_ok = infer_constraint_inside_type_(types, common_type);
		  if (!type_ok) {
			b.state_errors.push_back(
			      "unsupported integral type in constraint inside expression");
		  }
	    }
	    b.integral_context_width = type_ok ? common_type.width : 0;
	    b.integral_context_sign = type_ok ? (common_type.sign ? 1 : 0) : -1;
	    Z3_ast subject = build_z3_atom(par, b);
	    if (type_ok)
		  subject = b.coerce_in_context(subject, common_type.width,
					       common_type.sign);
	    unsigned subj_sv = type_ok ? common_type.width : b.sv_of(subject);
	      // A signed subject selects signed range semantics
	      // (IEEE 1800-2017 11.4.13, 11.8.1).
	    bool subj_signed = type_ok ? common_type.sign : b.is_signed(subject);

	      // IEEE 1800-2017/2023 Table 11-21 omits inside sizing, but the
	      // reported LRM-issue consensus and interoperable implementation
	      // policy use one common type across the subject, every member, and
	      // both range bounds before doing any comparison. The typed cast
	      // path computes that type above. The helpers below retain the old
	      // pairwise behavior only for constraints outside a typed cast.
	    auto member_width = [&](Z3_ast a) -> unsigned {
		  unsigned mw = b.sv_of(a);
		  return mw > subj_sv ? mw : subj_sv;
	    };
	    auto match_width = [&](Z3_ast a) -> Z3_ast {
		  return type_ok
			? b.coerce_in_context(a, common_type.width,
					      common_type.sign)
			: b.coerce(a, member_width(a));
	    };
	    auto subj_at = [&](Z3_ast member) -> Z3_ast {
		  return type_ok ? subject
			: b.coerce(subject, bv_width(b.ctx, member));
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
			if (type_ok) rw = common_type.width;
			Z3_ast sx = type_ok ? subject : b.coerce(subject, rw);
			Z3_ast c1 = lo_raw
			      ? range_ge(sx, type_ok
				    ? b.coerce_in_context(lo_raw, rw,
							 common_type.sign)
				    : b.coerce(lo_raw, rw)) : 0;
			Z3_ast c2 = hi_raw
			      ? range_le(sx, type_ok
				    ? b.coerce_in_context(hi_raw, rw,
							 common_type.sign)
				    : b.coerce(hi_raw, rw)) : 0;
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
			      if (csign) cv = b.tag_signed_constant(cv);
			      cv = match_width(cv);
			      clauses.push_back(Z3_mk_eq(b.ctx, subj_at(cv), cv));
			} else if (tok.compare(0, 5, "qbad:") == 0) {
			      if (b.collect_preferences && !b.collect_refs_only) {
				    Z3Builder::StateCheck check = {
					  b.mk_true(),
					  "X/Z inside container state element in constraint (IEEE 1800-2017/2023 18.3)"
				    };
				    b.state_checks.push_back(check);
			      }
			      // Placeholder only; the guarded state check above
			      // prevents every active solve from accepting it.
			      clauses.push_back(Z3_mk_false(b.ctx));
			} else if (tok == "qempty"
				   || tok.compare(0, 7, "qempty:") == 0) {
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
			      if (typed && qewid > 64) {
				    b.state_errors.push_back(
					  "inside container elements wider than 64 bits are not yet supported");
			      }
			      if (qewid > 64) {
				    qewid = 64;
			      }
			      uint64_t qcount = b.cobj
				    ? cobj_darray_size(b.cobj, qpidx) : 0;
			      if (qcount == 0) {
				    clauses.push_back(Z3_mk_false(b.ctx));
			      } else for (uint64_t qi = 0; qi < qcount; qi += 1) {
				    uint64_t bits = 0;
				    vvp_vector4_t value;
				    bool known = cobj_elem_vec4_(
					  b.cobj, qpidx, (unsigned)qi, value)
					  && value.size() == qewid
					  && vec4_to_uint64_(value, bits);
				    if (b.collect_preferences
				        && !b.collect_refs_only && !known) {
					  Z3Builder::StateCheck check = {
						b.mk_true(),
						"X/Z inside container state element in constraint (IEEE 1800-2017/2023 18.3)"
					  };
					  b.state_checks.push_back(check);
				    }
				    if (!typed || !known)
					  bits = cobj_elem_bits(
						b.cobj, qpidx, (unsigned)qi);
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
				    if (qesig) cv = b.tag_signed_constant(cv);
				    cv = match_width(cv);
				    clauses.push_back(
					  Z3_mk_eq(b.ctx, subj_at(cv), cv));
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
	    b.integral_context_width = outer_context;
	    b.integral_context_sign = outer_sign;

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
	    size_t nested_soft_begin = b.pending_soft.size();
	    size_t nested_dist_begin = b.dist_specs.size();
	    size_t side_begin = b.side_constraints.size();
	    b.collect_refs = &refs;
	    b.soft_keyword_depth += 1;
	    Z3_ast inner = bv_to_bool(b.ctx, build_z3_atom(par, b));
	    size_t side_end = b.side_constraints.size();
	    if (side_end != side_begin) {
		  Z3_ast validity = constraint_side_conjunction_(
			b, side_begin, side_end);
		  Z3_ast valid_inner[2] = { validity, inner };
		  inner = Z3_mk_and(b.ctx, 2, valid_inner);
		  b.side_constraints.resize(side_begin);
	    }
	    b.soft_keyword_depth -= 1;
	    b.collect_refs = saved;
	    if (b.collect_preferences) {
		  // The owner of a nested preference is the complete outer soft
		  // expression, not just the dist subject. Thus `disable soft guard'
		  // also suppresses `(soft (guard -> x dist {...}))'. Scheduling
		  // continues to use each dist's subject-only refs.
                  ++b.preference_order;
		  for (size_t i = nested_soft_begin;
		       i < b.pending_soft.size(); ++i) {
			b.pending_soft[i].refs = refs;
                        b.pending_soft[i].priority = b.preference_order;
                  }
		  for (size_t i = nested_dist_begin;
		       i < b.dist_specs.size(); ++i) {
			b.dist_specs[i].disableable = true;
			b.dist_specs[i].disable_refs = refs;
                        b.dist_specs[i].priority = b.preference_order;
			for (auto&fallback : b.dist_specs[i].fallback) {
			      fallback.refs = refs;
                              fallback.priority = b.preference_order;
                        }
		  }
	    }
	    par.skip_ws();
	    par.expect(')');
	    Z3Builder::SoftAssert sa = {
		  b.guard_soft_assert(inner), 256, true /* from_soft_kw */, refs,
                  b.preference_order
	    };
	    if (b.collect_preferences)
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
            if (b.collect_preferences) {
                  ++b.preference_order;
                  for (const auto&ref : refs)
                        b.disabled_soft_refs[ref] = b.preference_order;
            }
	    return b.mk_true();
      }

      if (op == "dist") {
	    // C7 (Phase 62b): weighted distribution.
	    // Format: (dist <expr> (b MODE W <range>) ...)
	    // MODE is `:=' or `:/'. Historical `(b W <range>)' IR remains
	    // valid and gives a range its former aggregate `:/' meaning.
	    // - Hard constraint: <expr> ∈ union of all branches.
	    // - Soft preference: per branch, Z3_optimize_assert_soft of
	    //   `(<expr> matches branch)` with weight W, so the optimizer
	    //   prefers higher-weight branches when feasible.
	    std::set<Z3Builder::VarRef> subject_refs;
	    std::set<Z3Builder::VarRef>* saved_refs = b.collect_refs;
	    b.collect_refs = &subject_refs;
	    Z3_ast subject = bool_to_bv1(b.ctx, build_z3_atom(par, b));
	    b.collect_refs = saved_refs;
	    if (saved_refs)
		  saved_refs->insert(subject_refs.begin(), subject_refs.end());
	    unsigned sw = b.sv_of(subject);
	    bool subject_signed = b.is_signed(subject);
	    vector<Z3_ast> hard_clauses;
	      // RANDOM-DIST fix #2: structural record of this dist's branches,
	      // parallel to hard_clauses/pending_soft above, so the solver can
	      // later draw a value proportional to its weight instead of just
	      // preferring the heaviest branch (see Z3Builder::DistSpec).
	    Z3Builder::DistSpec dspec;
            dspec.rng_owner = b.cobj;
            dspec.priority = b.preference_order;
	    dspec.subject = subject;
	    dspec.width = sw;
	    dspec.refs = subject_refs;
	    dspec.disable_refs.clear();
	    dspec.exact_supported = false;
            dspec.requires_large_exact = false;
            dspec.state_weights = true;
	    dspec.disableable = b.soft_keyword_depth != 0;
	    bool exact_supported = true;
	    auto warn_exact_item_boundary = []() {
		  static bool warned = false;
		  if (!warned) {
			fprintf(stderr, "Warning: dist item is outside the "
				"ground <=64-bit common-order exact-sampling "
				"subset; using the weighted-soft fallback "
				"(further similar warnings suppressed).\n");
			warned = true;
		  }
	    };
	    auto width_mask = [](unsigned width) -> uint64_t {
		  return width >= 64 ? UINT64_MAX
			: ((uint64_t)1 << width) - 1;
	    };
	    auto ordered_coordinate = [&](uint64_t bits, unsigned width,
					  bool is_signed) -> uint64_t {
		  bits &= width_mask(width);
		  if (is_signed)
			bits ^= (uint64_t)1 << (width - 1);
		  return bits;
	    };
	    auto coerce_for_compare = [&](Z3_ast value, unsigned width,
					  bool use_signed) -> Z3_ast {
		  unsigned actual = bv_width(b.ctx, value);
		  if (actual == width) return value;
		  if (actual > width)
			return Z3_mk_extract(b.ctx, width - 1, 0, value);
		  return use_signed
			? Z3_mk_sign_ext(b.ctx, width - actual, value)
			: Z3_mk_zero_ext(b.ctx, width - actual, value);
	    };
	    auto ground_at_width = [&](Z3_ast value, unsigned width,
					 bool use_signed,
					 uint64_t& bits) -> bool {
		  if (!value || width == 0 || width > 64)
			return false;
		  value = coerce_for_compare(value, width, use_signed);
		  value = b.resolve_signed_constants(value);
		  value = Z3_simplify(b.ctx, value);
		  if (!z3_ground_uint64(b.ctx, value, bits))
			return false;
		  bits &= width_mask(width);
		  return true;
	    };
	    auto parse_integral_atom = [&](bool& ok) -> Z3_ast {
		  par.skip_ws();
		  const char* start = par.p;
		  bool recognized = *start == '('
			|| strncmp(start, "c:", 2) == 0
			|| strncmp(start, "p:", 2) == 0
			|| strncmp(start, "m:", 2) == 0
			|| strncmp(start, "a:", 2) == 0
			|| strncmp(start, "r:", 2) == 0
			|| strncmp(start, "s:", 2) == 0
			|| strncmp(start, "e:", 2) == 0;
		  Z3_ast value = build_z3_atom(par, b);
		  ok = recognized && par.p != start && value;
		  if (!ok) return 0;
		  value = bool_to_bv1(b.ctx, value);
		  Z3_sort sort = Z3_get_sort(b.ctx, value);
		  ok = Z3_get_sort_kind(b.ctx, sort) == Z3_BV_SORT;
		  return ok ? value : 0;
	    };
	    auto subject_domain_endpoint = [&](unsigned width, bool high,
					       uint64_t& bits) -> bool {
		  if (sw == 0 || sw > 64 || width < sw || width > 64)
			return false;
		  if (!subject_signed) {
			bits = high ? width_mask(sw) : 0;
			return true;
		  }
		  if (high) {
			bits = sw == 64 ? (UINT64_MAX >> 1)
			      : (((uint64_t)1 << (sw - 1)) - 1);
			return true;
		  }
		  bits = (uint64_t)1 << (sw - 1);
		  if (width > sw)
			bits |= width_mask(width) & ~width_mask(sw);
		  return true;
	    };
	    bool saw_branch = false;
	    par.skip_ws();
	    while (par.peek() != ')' && !par.at_end()) {
		  // Each branch is `(b MODE W <range>)`; MODE is absent in
		  // historical IR.
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
		  bool range_weight_per_value = false;
		  par.skip_ws();
		  if (par.peek() == ':') {
			string mode = par.read_token();
			if (mode == ":=")
			      range_weight_per_value = true;
			else if (mode != ":/") {
			      static bool warned_mode = false;
			      if (!warned_mode) {
				    fprintf(stderr, "Warning: unknown dist range-weight "
					    "mode '%s'; treating it as :/ (further "
					    "similar warnings suppressed).\n",
					    mode.c_str());
				    warned_mode = true;
			      }
			}
		  }
		  uint64_t weight64 = 1;
		  bool weight_overflow = false;
                  bool state_weight = false;
		  if (!eval_runtime_integral_ir(par, b, weight64,
						 weight_overflow, nullptr, &state_weight)) {
                        state_weight = false;
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
                  dspec.state_weights = dspec.state_weights && state_weight;
		  if (weight_overflow) {
			static bool warned_weight_overflow = false;
			if (!warned_weight_overflow) {
			      fprintf(stderr, "Warning: dist weight result exceeds "
				      "the runtime uint64 representation; using the "
				      "weighted-soft fallback with a saturated "
				      "objective (further similar warnings "
				      "suppressed).\n");
			      warned_weight_overflow = true;
			}
			exact_supported = false;
		  } else if (weight64 > UINT_MAX) {
			static bool warned_weight_width = false;
			if (!warned_weight_width) {
			      fprintf(stderr, "Warning: dist weight exceeds the "
				      "exact-sampling UINT_MAX boundary; using the "
				      "weighted-soft fallback (further similar "
				      "warnings suppressed).\n");
			      warned_weight_width = true;
			}
			exact_supported = false;
		  }
		  unsigned weight = weight_overflow || weight64 > UINT_MAX
			? UINT_MAX : (unsigned)weight64;
		  unsigned soft_weight = weight;
		  Z3_ast clause = b.mk_false();
		  par.skip_ws();
		  if (par.peek() == '[') {
			par.consume();
			par.skip_ws();
			bool lo_open = par.peek() == '*';
			if (lo_open) par.consume();
			bool lo_valid = lo_open;
			Z3_ast lo_raw = lo_open ? 0
			      : parse_integral_atom(lo_valid);
			par.expect(',');
			par.skip_ws();
			bool hi_open = par.peek() == '*';
			if (hi_open) par.consume();
			bool hi_valid = hi_open;
			Z3_ast hi_raw = hi_open ? 0
			      : parse_integral_atom(hi_valid);
			par.expect(']');
			bool lo_order_signed = subject_signed
			      && (lo_open || (lo_raw && b.is_signed(lo_raw)));
			bool hi_order_signed = subject_signed
			      && (hi_open || (hi_raw && b.is_signed(hi_raw)));

			  // Match `inside' sizing: one context width for the
			  // subject and every present endpoint. Keeping the typed
			  // endpoint AST is essential for narrow signed constants.
			unsigned rw = sw;
			if (lo_raw && b.sv_of(lo_raw) > rw) rw = b.sv_of(lo_raw);
			if (hi_raw && b.sv_of(hi_raw) > rw) rw = b.sv_of(hi_raw);
			Z3_ast c1 = lo_raw
			      ? (lo_order_signed
				    ? Z3_mk_bvsge(b.ctx,
					  coerce_for_compare(subject, rw, true),
					  coerce_for_compare(lo_raw, rw, true))
				    : Z3_mk_bvuge(b.ctx,
					  coerce_for_compare(subject, rw, false),
					  coerce_for_compare(lo_raw, rw, false)))
			      : 0;
			Z3_ast c2 = hi_raw
			      ? (hi_order_signed
				    ? Z3_mk_bvsle(b.ctx,
					  coerce_for_compare(subject, rw, true),
					  coerce_for_compare(hi_raw, rw, true))
				    : Z3_mk_bvule(b.ctx,
					  coerce_for_compare(subject, rw, false),
					  coerce_for_compare(hi_raw, rw, false)))
			      : 0;
			if (!lo_valid || !hi_valid) {
			      clause = b.mk_false();
			      exact_supported = false;
			      warn_exact_item_boundary();
			} else if (c1 && c2) {
			      Z3_ast both[2] = {c1, c2};
			      clause = Z3_mk_and(b.ctx, 2, both);
			} else if (c1) {
			      clause = c1;
			} else if (c2) {
			      clause = c2;
			} else {
			      clause = b.mk_true();
			}

			uint64_t lo_bits = 0, hi_bits = 0;
			bool common_order = lo_order_signed == hi_order_signed;
			bool bounds_ok = common_order && lo_valid && hi_valid && (lo_open
			      ? subject_domain_endpoint(rw, false, lo_bits)
			      : ground_at_width(lo_raw, rw, lo_order_signed,
						lo_bits));
			bounds_ok = (hi_valid && (hi_open
			      ? subject_domain_endpoint(rw, true, hi_bits)
			      : ground_at_width(hi_raw, rw, hi_order_signed,
						hi_bits))) && bounds_ok;
			uint64_t lo_coord = 1, hi_coord = 0;
			if (bounds_ok) {
			      lo_coord = ordered_coordinate(lo_bits, rw,
						    lo_order_signed);
			      hi_coord = ordered_coordinate(hi_bits, rw,
						    hi_order_signed);
			} else {
			      exact_supported = false;
			      warn_exact_item_boundary();
			}
			if (range_weight_per_value && weight != 0
			    && bounds_ok && hi_coord >= lo_coord) {
			      uint64_t span = hi_coord - lo_coord + 1;
			      if (span == 0 || span > UINT_MAX / weight)
				    soft_weight = UINT_MAX;
			      else
				    soft_weight = weight * (unsigned)span;
			}
			if (weight != 0 && bounds_ok) {
			      if (hi_coord >= lo_coord) {
			            uint64_t exact_span = hi_coord - lo_coord + 1;
			            if (exact_span == 0 || exact_span > 256)
			                  dspec.requires_large_exact = true;
			      }
			      Z3Builder::DistBranch db = {
				    weight, true, range_weight_per_value,
				    rw, lo_order_signed, lo_coord, hi_coord
			      };
			      dspec.branches.push_back(db);
			}
		  } else {
			bool value_valid = false;
			Z3_ast value_raw = parse_integral_atom(value_valid);
			unsigned vw = sw;
			if (value_valid && b.sv_of(value_raw) > vw)
			      vw = b.sv_of(value_raw);
			bool value_compare_signed = subject_signed && value_valid
			      && b.is_signed(value_raw);
			Z3_ast value = value_valid
			      ? coerce_for_compare(value_raw, vw,
						   value_compare_signed) : 0;
			if (value)
			      clause = Z3_mk_eq(b.ctx,
				    coerce_for_compare(subject, vw,
						       value_compare_signed), value);
			uint64_t value_bits = 0;
			bool value_ok = value_valid
			      && ground_at_width(value_raw, vw,
					 value_compare_signed, value_bits);
			if (!value_ok) {
			      exact_supported = false;
			      warn_exact_item_boundary();
			}
			if (weight != 0 && value_ok) {
			      Z3Builder::DistBranch db = {
				    weight, false, false, vw,
				    value_compare_signed,
				    value_bits, value_bits
			      };
			      dspec.branches.push_back(db);
			}
		  }
		  par.skip_ws();
		  par.expect(')'); // close (b ...)
		  par.skip_ws();
		  if (weight == 0)
			continue;
		  hard_clauses.push_back(clause);
		  // Retain the optimizer approximation with this distribution
		  // rather than installing every dist objective globally. That lets
		  // solve...before activate the group at the subject's ordering rank.
		  // An ordinary hard dist is not affected by `disable soft'; only a
		  // dist nested in an outer soft owns disableable references.
		  Z3Builder::SoftAssert sa = {
			b.guard_soft_assert(clause), soft_weight,
			false /* dist */,
			dspec.disableable ? subject_refs
					  : std::set<Z3Builder::VarRef>(), dspec.priority
		  };
		  dspec.fallback.push_back(sa);
		  // Scope std::randomize still uses its existing weighted-soft
		  // implementation; class randomize schedules the structural group
		  // below and attempts exact sampling first.
		  if (b.collect_preferences && b.defn == nullptr)
			b.pending_soft.push_back(sa);
	    }
	    par.expect(')');
	    // Exact weighted sampling currently represents an unconditional
	    // distribution. For a guarded dist, keep the correct guarded hard
	    // domain and guarded optimizer preferences above instead of applying
	    // the distribution when its condition is false.
	    dspec.exact_supported = exact_supported && !dspec.branches.empty()
		  && b.soft_guards.empty();
	    if (b.collect_preferences && b.defn != nullptr
		&& (!dspec.fallback.empty() || !dspec.state_weights))
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
	/* A builder may parse many independent constraint strings. Append only
	 * aliases created by this parse so every occurrence is constrained once
	 * without repeatedly growing earlier conjunctions. */
      size_t alias_begin = b.signed_constant_aliases.size();

      while (!par.at_end()) {
	    par.skip_ws();
	    if (par.at_end()) break;
	    const char* before = par.p;
	    size_t side_begin = b.side_constraints.size();
	    size_t checks_begin = b.state_checks.size();
	    Z3_ast expr = bv_to_bool(b.ctx, build_z3_atom(par, b));
	    size_t side_end = b.side_constraints.size();
	    size_t checks_end = b.state_checks.size();
	    if (side_end != side_begin) {
		  Z3_ast validity = constraint_side_conjunction_(
			b, side_begin, side_end);
		  Z3_ast valid_expr[2] = { validity, expr };
		  expr = Z3_mk_and(b.ctx, 2, valid_expr);
		  b.side_constraints.resize(side_begin);
	    }
	    // Keep evaluation-error branches satisfiable long enough to obtain a
	    // diagnostic model. The solve normally asserts every check false; if
	    // that is UNSAT, the relaxed assertion proves which guarded read failed.
	    if (checks_end != checks_begin) {
		  Z3_ast either[2] = {
			expr, constraint_state_error_disjunction_(
			      b, checks_begin, checks_end)
		  };
		  expr = Z3_mk_or(b.ctx, 2, either);
	    }
	    if (par.p == before) {
		  static bool warned_no_progress = false;
		  if (!warned_no_progress) {
			fprintf(stderr, "Warning: malformed constraint IR made no "
				"parser progress; skipping one byte (further "
				"similar warnings suppressed).\n");
			warned_no_progress = true;
		  }
		  if (*par.p) par.consume();
		  continue;
	    }
	    assertions.push_back(expr);
      }

      for (size_t i = alias_begin ; i < b.signed_constant_aliases.size()
	   ; i += 1) {
	    const auto& alias = b.signed_constant_aliases[i];
	    assertions.push_back(Z3_mk_eq(b.ctx, alias.first, alias.second));
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
	/* Shifting a uint64_t by 64 or more is undefined C++. The constraint
	 * model interface is intentionally bounded to uint64_t, so a successfully
	 * extracted value has zero high bits. */
      unsigned low_wid = wid < 64 ? wid : 64;
      for (unsigned b = 0; b < low_wid; ++b)
	    vec.set_bit(b, ((bits >> b) & 1) ? BIT4_1 : BIT4_0);
      for (unsigned b = low_wid; b < wid; ++b)
	    vec.set_bit(b, BIT4_0);
      cobj->set_vec4(idx, vec);
}

static bool cobj_set_prop_vec4_(vvp_cobject*cobj, unsigned idx,
                                const vvp_vector4_t&value)
{
      vvp_vector4_t current;
      cobj->get_vec4(idx, current);
      if (current.size() != value.size()) return false;
      cobj->set_vec4(idx, value);
      return true;
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

static uint64_t cobj_member_elem_bits(vvp_cobject*cobj, unsigned outer,
				      unsigned member, unsigned elem)
{
      vvp_cobject*owner = cobj_struct_prop(cobj, outer);
      return owner ? cobj_elem_bits(owner, member, elem) : 0;
}

static bool cobj_member_elem_vec4_(vvp_cobject*cobj, unsigned outer,
				   unsigned member, unsigned elem,
				   vvp_vector4_t&value)
{
      vvp_cobject*owner = cobj_struct_prop(cobj, outer);
      return owner && cobj_elem_vec4_(owner, member, elem, value);
}

static void cobj_set_member_elem_bits(vvp_cobject*cobj, unsigned outer,
				      unsigned member, unsigned elem,
				      unsigned width, uint64_t bits)
{
      if (vvp_cobject*owner = cobj_struct_prop(cobj, outer))
	    cobj_set_elem_bits(owner, member, elem, width, bits);
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
      bool elem_integral = false;
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
	  || (1 == sscanf(elem, "sv%u%zn", &width, &n) && n == desc.elem_type.size())) {
	    desc.elem_width = width ? width : 32;
	    desc.elem_integral = true;
      }
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
/* One scalar property of ONE ELEMENT of an object-handle array property. */
static uint64_t cobj_qelem_member_bits(vvp_cobject* cobj, unsigned qprop,
				       unsigned elem, unsigned member)
{
      if (!cobj) return 0;
      vvp_object_t propobj;
      cobj->get_object(qprop, propobj, 0);
      vvp_darray*da = propobj.peek<vvp_darray>();
      if (!da || elem >= da->get_size()) return 0;
      vvp_object_t elemobj;
      da->get_word(elem, elemobj);
      vvp_cobject*eco = elemobj.peek<vvp_cobject>();
      if (!eco) return 0;
      return cobj_prop_bits(eco, member);
}

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

static bool cobj_elem_vec4_(vvp_cobject*cobj, unsigned idx, unsigned elem,
                            vvp_vector4_t&value)
{
      vvp_object_t propobj;
      cobj->get_object(idx, propobj, 0);
      if (vvp_darray*da = propobj.peek<vvp_darray>()) {
            if (elem >= da->get_size()) return false;
            da->get_word(elem, value);
            return true;
      }
      if (vvp_assoc_base*assoc = propobj.peek<vvp_assoc_base>()) {
            string key_text, val_str;
            double val_real = 0;
            int val_kind = -1;
            return assoc->peek_entry(elem, key_text, value, val_real,
                                     val_str, val_kind) && val_kind == 0;
      }
      cobj->get_vec4(idx, value, elem);
      return value.size() != 0;
}

static Z3_ast z3_vec4_constant_(Z3_context ctx,
                                const vvp_vector4_t&value,
                                unsigned width)
{
      if (width == 0 || value.size() != width || !vec4_is_two_state_(value))
            return nullptr;
      vector<Z3_ast> chunks;
      for (unsigned high = width; high > 0;) {
            unsigned low = high > 64 ? high - 64 : 0;
            unsigned chunk_width = high - low;
            uint64_t bits = 0;
            for (unsigned bit = 0; bit < chunk_width; ++bit)
                  if (value.value(low + bit) == BIT4_1)
                        bits |= UINT64_C(1) << bit;
            chunks.push_back(Z3_mk_unsigned_int64(
                  ctx, bits, Z3_mk_bv_sort(ctx, chunk_width)));
            high = low;
      }
      Z3_ast result = chunks[0];
      for (size_t idx = 1; idx < chunks.size(); ++idx)
            result = Z3_mk_concat(ctx, result, chunks[idx]);
      return result;
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

/* Inline caller-state function captures use fv:N:W[:s]. Unlike ordinary
 * scalar value slots, their result must not collapse X/Z to zero before the
 * constraint solve. */
static bool substitute_function_slots_(const string&ir,
      const vector<vvp_vector4_t>&slot_vals, string&result, string&error)
{
      result.clear();
      const char*begin = ir.c_str();
      const char*p = begin;
      while (*p) {
            bool token_start = p == begin
                  || !(isalnum((unsigned char)p[-1]) || p[-1] == '_');
            if (!token_start || p[0] != 'f' || p[1] != 'v' || p[2] != ':') {
                  result += *p++;
                  continue;
            }
            const char*q = p + 3;
            char*end = nullptr;
            unsigned long slot = strtoul(q, &end, 10);
            if (end == q || *end != ':') {
                  error = "malformed inline constraint function capture";
                  return false;
            }
            q = end + 1;
            unsigned long width = strtoul(q, &end, 10);
            if (end == q || width == 0 || width > UINT_MAX) {
                  error = "invalid inline constraint function capture width";
                  return false;
            }
            q = end;
            bool is_signed = q[0] == ':' && q[1] == 's';
            if (is_signed) q += 2;
            if (slot > UINT_MAX || slot >= slot_vals.size()
                || slot_vals[(size_t)slot].size() != width) {
                  error = "missing inline constraint function capture slot "
                        + to_string(slot);
                  return false;
            }
            const vvp_vector4_t&value = slot_vals[(size_t)slot];
            for (unsigned bit = 0; bit < value.size(); ++bit)
                  if (value.value(bit) != BIT4_0 && value.value(bit) != BIT4_1) {
                        error = "X/Z value in inline constraint function capture slot "
                              + to_string(slot);
                        return false;
                  }
            string constant = "c:0:" + to_string(width)
                  + (is_signed ? ":s" : "");
            if (width <= 64) {
                  uint64_t bits = 0;
                  for (unsigned bit = 0; bit < width; ++bit)
                        if (value.value(bit) == BIT4_1) bits |= UINT64_C(1) << bit;
                  constant = "c:" + to_string(bits) + ":" + to_string(width)
                        + (is_signed ? ":s" : "");
            } else {
                  /* Constraint IR constants are bounded to 64 bits; the
                   * elaborator currently admits only representable results. */
                  error = "inline constraint function capture width exceeds 64 bits";
                  return false;
            }
            result += constant;
            p = q;
      }
      return true;
}

/* Class-constraint function captures retain their complete four-state value.
 * Build wide constants from existing concat/trunc IR instead of narrowing the
 * runtime value through uint64_t. */
static bool substitute_class_slots_(const string&ir,
      const vector<vvp_vector4_t>&slot_vals, string&result, string&error)
{
      result.clear();
      const char*begin = ir.c_str();
      const char*p = begin;
      while (*p) {
            bool token_start = p == begin
                  || !(isalnum((unsigned char)p[-1]) || p[-1] == '_');
            if (!token_start || p[0] != 'v' || p[1] != ':') {
                  result += *p++;
                  continue;
            }
            const char*q = p + 2;
            char*end = nullptr;
            unsigned long slot = strtoul(q, &end, 10);
            if (end == q || *end != ':') {
                  error = "malformed class constraint function capture";
                  return false;
            }
            q = end + 1;
            unsigned long width = strtoul(q, &end, 10);
            if (end == q || width == 0 || width > UINT_MAX) {
                  error = "invalid class constraint function capture width";
                  return false;
            }
            q = end;
            bool is_signed = q[0] == ':' && q[1] == 's';
            if (is_signed) q += 2;
            if (slot > UINT_MAX || slot >= slot_vals.size()
                || slot_vals[(size_t)slot].size() == 0) {
                  error = "missing class constraint function capture slot "
                        + to_string(slot);
                  return false;
            }
            const vvp_vector4_t&value = slot_vals[(size_t)slot];
            if (value.size() != width) {
                  error = "class constraint function capture slot "
                        + to_string(slot) + " has width "
                        + to_string(value.size()) + ", expected "
                        + to_string(width);
                  return false;
            }
            for (unsigned bit = 0; bit < value.size(); ++bit)
                  if (value.value(bit) != BIT4_0 && value.value(bit) != BIT4_1) {
                        error = "X/Z value in class constraint function capture slot "
                              + to_string(slot);
                        return false;
                  }
            string constant;
            for (unsigned high = value.size(); high > 0;) {
                  unsigned low = high > 64 ? high - 64 : 0;
                  unsigned chunk_width = high - low;
                  uint64_t bits = 0;
                  for (unsigned bit = 0; bit < chunk_width; ++bit)
                        if (value.value(low + bit) == BIT4_1)
                              bits |= UINT64_C(1) << bit;
                  constant += "c:" + to_string(bits) + ":"
                            + to_string(chunk_width) + " ";
                  high = low;
            }
            if (value.size() > 64) constant = "(concat " + constant + ")";
            else constant.resize(constant.size() - 1);
            if (is_signed)
                  constant = "(trunc:" + to_string(width) + ":s "
                           + constant + ")";
            result += constant;
            p = q;
      }
      return true;
}

/* Scope std::randomize may also carry queue/darray membership operands.
 * qv:N:W[:s] expands known elements to ordinary constants and unknown ones
 * to qbad:W[:s], which the typed inside path turns into a guard-aware 18.3
 * error. Keep qempty:W[:s] so an empty queue is false rather than vacuously
 * true, while retaining its declared type for context sizing. */
static string substitute_scope_object_slots(
      const string&ir, const vector<vector<uint64_t> >&object_vals,
      const vector<vector<bool> >&object_known)
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
			result += "qempty:" + to_string(width)
			      + (is_signed ? ":s" : "");
		  } else {
			for (size_t i = 0 ; i < object_vals[slot].size() ; i += 1) {
			      if (i) result += " ";
			      bool known = slot < object_known.size()
				    && i < object_known[slot].size()
				    && object_known[slot][i];
			      result += known
				    ? "c:" + to_string(object_vals[slot][i])
					  + ":" + to_string(width)
					  + (is_signed ? ":s" : "")
				    : "qbad:" + to_string(width)
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

static bool rand_active_(const class_type*, vvp_cobject*,
                         const vector<bool>*, unsigned);
static bool rand_member_active_(const class_type*, vvp_cobject*,
                                const vector<bool>*, unsigned, unsigned);

/* IEEE 1800-2017 18.5.8.1/18.5.13 and 1800-2023 18.5.7.1/18.5.12:
 * expand state collections before solving, preserving predicate guards.
 * Reuse IRParser and the typed Z3 evaluator. Evaluation errors are carried
 * until enclosing guards are evaluated; an excluded null/OOB read is not an
 * error, regardless of the order of the guard's subexpressions. */
struct state_foreach_value_t {
      string text;
      string error;
      bool ground = false;
};

class state_foreach_expander_t {
      const vector<vvp_vector4_t>&slots_;
      const vector<vvp_object_t>&objects_;
      vector<vvp_object_t> queues_;
      vvp_cobject*receiver_;
      const vector<bool>*active_;
      z3_object_graph_t*graph_;
      Z3_context context_;
      unsigned template_depth_ = 0;

      static bool decimal_(const string&text, uint64_t&value)
      {
            if (text.empty()) return false;
            value = 0;
            for (char c : text) {
                  if (c < '0' || c > '9'
                      || value > (UINT64_MAX - (c - '0')) / 10) return false;
                  value = value * 10 + (c - '0');
            }
            return true;
      }

      static bool unsigned_token_(const string&text, unsigned&value)
      {
            uint64_t number;
            if (!decimal_(text, number) || number > UINT_MAX) return false;
            value = number;
            return true;
      }

      static bool header_(const string&text, const char*prefix,
                          unsigned&slot, unsigned&member, unsigned&width,
                          bool&sign, bool field)
      {
            if (text.compare(0, strlen(prefix), prefix) != 0) return false;
            istringstream input(text.substr(strlen(prefix)));
            string part;
            if (!getline(input, part, ':') || !unsigned_token_(part, slot)) return false;
            if (field && (!getline(input, part, ':')
                || !unsigned_token_(part, member))) return false;
            if (!getline(input, part, ':') || !unsigned_token_(part, width)
                || width == 0 || width > 64) return false;
            sign = !input.eof();
            return !sign || (getline(input, part) && part == "s");
      }

      static void constant_(state_foreach_value_t&out, uint64_t value,
                            unsigned width = 1, bool sign = false)
      {
            out.text = "c:" + to_string(value) + ":" + to_string(width)
                  + (sign ? ":s" : "");
            out.error.clear();
            out.ground = true;
      }

      static void error_(state_foreach_value_t&out, const string&message,
                         unsigned width = 1, bool sign = false)
      {
            constant_(out, 0, width, sign);
            out.error = message;
            out.ground = false;
      }

      bool number_(const state_foreach_value_t&value, uint64_t&bits,
                   bool*negative = nullptr)
      {
            if (!value.ground || !value.error.empty()) return false;
            IRParser parser(value.text);
            // Even an inactive ternary arm determines width/signedness
            // (IEEE 1800-2017/2023 11.6.1, 11.8.2). Retain its typed
            // canonical references while evaluating a known state result.
            Z3Builder builder(context_, receiver_->get_defn(), receiver_, graph_);
            builder.prop_active = active_;
            builder.object_vals = &objects_;
            bool overflow = false;
            return eval_runtime_integral_ir(parser, builder, bits, overflow, negative)
                  && !overflow && parser.at_end();
      }

      static void word_(state_foreach_value_t&out, const vvp_vector4_t&word,
                        unsigned width, bool sign)
      {
            if (word.size() != width) {
                  error_(out, "state value width does not match constraint metadata", width, sign);
                  return;
            }
            uint64_t bits = 0;
            for (unsigned bit = 0; bit < width; ++bit) {
                  if (word.value(bit) != BIT4_0 && word.value(bit) != BIT4_1) {
                        error_(out, "X/Z state value in constraint (IEEE 1800-2017/2023 18.3)", width, sign);
                        return;
                  }
                  if (word.value(bit) == BIT4_1) bits |= UINT64_C(1) << bit;
            }
            constant_(out, bits, width, sign);
      }

      void field_(state_foreach_value_t&out, vvp_cobject*record,
                  unsigned member, unsigned width, bool sign)
      {
            if (!record) {
                  error_(out, "null/non-class state foreach element", width, sign);
                  return;
            }
            const class_type*type = record->get_defn();
            if (member >= type->property_count()
                || type->property_array_size(member) != 1
                || type->property_vec4_width(member) != width) {
                  error_(out, "invalid state foreach field metadata", width, sign);
                  return;
            }
            // IEEE 1800-2017 18.5.9 / 1800-2023 18.5.8: aliases of
            // selected fields participate in the same problem, even when
            // reached through an otherwise state-only foreach collection.
            if (graph_) {
                  unsigned idx = graph_->intern(record, member);
                  if (graph_->active(idx)) {
                        out.text = "g:" + to_string(idx) + ":" + to_string(width)
                              + (sign ? ":s" : "");
                        out.ground = false;
                        return;
                  }
            }
            vvp_vector4_t word;
            record->get_vec4(member, word);
            word_(out, word, width, sign);
      }

      bool property_(state_foreach_value_t&out)
      {
            string token = out.text;
            vector<unsigned> path;
            unsigned first = 0, member = 0, width = 0; bool sign = false;
            bool scalar = token[0] == 'p', aggregate = token[0] == 'm';
            if (scalar || aggregate) {
                  if (!header_(token, scalar ? "p:" : "m:", first, member,
                               width, sign, aggregate)) return false;
                  path.push_back(first);
                  if (aggregate) path.push_back(member);
            } else {
                  size_t end = token.find(':', 2);
                  if (end == string::npos || !header_("0:" + token.substr(end+1),
                      "", first, member, width, sign, false)) return false;
                  istringstream input(token.substr(2, end-2));
                  string part;
                  while (getline(input, part, '.')) {
                        if (!unsigned_token_(part, first)) return false;
                        path.push_back(first);
                  }
                  if (path.empty() || token[end-1] == '.') return false;
            }
            vvp_cobject*record = receiver_;
            for (size_t i = 0; record && i + 1 < path.size(); ++i) {
                  const class_type*type = record->get_defn();
                  if (path[i] >= type->property_count()
                      || type->property_array_size(path[i]) != 1
                      || type->property_base_type(path[i]) != "o") return false;
                  vvp_object_t child;
                  record->get_object(path[i], child, 0);
                  record = child.peek<vvp_cobject>();
            }
            if (record && (path.back() >= record->get_defn()->property_count()
                || record->get_defn()->property_vec4_width(path.back()) != width)) return false;
            if (!graph_ && scalar && rand_active_(receiver_->get_defn(), receiver_, active_, first))
                  return true;
            if (!graph_ && aggregate && record && rand_member_active_(receiver_->get_defn(),
                receiver_, active_, path[0], path[1])) return true;
            field_(out, record, path.back(), width, sign);
            return true;
      }

      vvp_darray*queue_(unsigned slot, state_foreach_value_t&out)
      {
            const vvp_object_t&object = queues_[slot];
            if (object.test_nil()) return nullptr; // empty, unallocated storage
            if (!object.peek<vvp_darray_object>() && !object.peek<vvp_queue_object>()) {
                  error_(out, "state foreach object is not a queue/dynamic array of objects");
                  return nullptr;
            }
            return object.peek<vvp_darray>();
      }

      /* Direct caller-state collections are integral queues/darrays. Keep
       * their scalar representation separate from queue_(), whose object
       * element check protects the existing owner/member field template. */
      vvp_darray*direct_queue_(unsigned slot, state_foreach_value_t&out)
      {
            const vvp_object_t&object = queues_[slot];
            if (object.test_nil()) return nullptr; // empty, unallocated storage
            vvp_darray*array = object.peek<vvp_darray>();
            if (!array) {
                  error_(out, "direct state foreach collection is not a queue/dynamic array");
                  return nullptr;
            }
            return array;
      }

    public:
      state_foreach_expander_t(const vector<vvp_vector4_t>&slots,
                              const vector<vvp_object_t>&objects,
                              vvp_cobject*receiver, const vector<bool>*active,
                              z3_object_graph_t*graph)
      : slots_(slots), objects_(objects), queues_(objects.size()),
        receiver_(receiver), active_(active), graph_(graph)
      {
            Z3_config config = Z3_mk_config();
            context_ = Z3_mk_context(config);
            Z3_del_config(config);
      }
      ~state_foreach_expander_t() { Z3_del_context(context_); }

      bool expression(IRParser&parser, state_foreach_value_t&out)
      {
            if (parser.peek() == '[') {
                  parser.consume();
                  state_foreach_value_t lo, hi;
                  if (!expression(parser, lo) || !parser.expect(',')
                      || !expression(parser, hi) || !parser.expect(']')) return false;
                  out.text = "[" + lo.text + "," + hi.text + "]";
                  out.error = lo.error.empty() ? hi.error : lo.error;
                  out.ground = lo.ground && hi.ground;
                  return true;
            }
            if (parser.peek() != '(') {
                  out.text = parser.read_token();
                  if (out.text.empty()) return false;
                  if (out.text == "L") return template_depth_ != 0;
                  if (out.text.compare(0, 2, "v:") == 0) {
                        unsigned slot = 0, member = 0, width = 0; bool sign = false;
                        if (!header_(out.text, "v:", slot, member, width, sign, false)
                            || slot >= slots_.size()) return false;
                        word_(out, slots_[slot], width, sign);
                  } else if (out.text.compare(0, 2, "c:") == 0) {
                        string spec = out.text.substr(2);
                        size_t colon = spec.find(':');
                        uint64_t value;
                        unsigned width = 32, member = 0, unused = 0;
                        bool sign = false;
                        if (!decimal_(spec.substr(0, colon), value)) return false;
                        if (colon != string::npos
                            && !header_("0:" + spec.substr(colon + 1), "",
                                        unused, member, width, sign, false)) return false;
                        out.ground = true;
                  } else if (out.text.compare(0, 2, "p:") == 0
                             || out.text.compare(0, 2, "m:") == 0
                             || out.text.compare(0, 2, "r:") == 0) {
                        if (!property_(out)) return false;
                  } else if (out.text.compare(0, 2, "s:") != 0
                             && out.text.compare(0, 2, "e:") != 0
			     && out.text.compare(0, 2, "a:") != 0
                             && out.text != ":=" && out.text != ":/") return false;
                  return true;
            }
            parser.consume();
            string op = parser.read_token();
            if (op.empty()) return false;
            if (op == "hselectfield") {
                  out.text = "(hselectfield" + capture_balanced_form(parser) + ")";
                  out.ground = false;
                  return true;
            }
            if (op == "heq" || op == "hne") {
                  if (template_depth_) {
                        out.text = "(" + op + capture_balanced_form(parser) + ")";
                        return true;
                  }
                  auto index_value = [&](IRParser&index, uint64_t&value, string&error) {
                        state_foreach_value_t item;
                        bool negative = false;
                        if (expression(index, item) && number_(item, value, &negative)
                            && !negative) return true;
                        error = item.error.empty() ? "invalid state class-handle index" : item.error;
                        return false;
                  };
                  vvp_object_t left, right;
                  string left_error, right_error;
                  read_constraint_handle_(parser, receiver_, &objects_, &queues_,
                                          index_value, left, left_error);
                  read_constraint_handle_(parser, receiver_, &objects_, &queues_,
                                          index_value, right, right_error);
                  if (!parser.expect(')')) return false;
                  if (!left_error.empty() || !right_error.empty())
                        error_(out, left_error.empty() ? right_error : left_error);
                  else constant_(out, op == "heq" ? left == right : left != right);
                  return true;
            }
            // Independent rand-array templates still belong to the existing
            // size/element solver passes (2017 18.5.8.1 / 2023 18.5.7.1).
            // Check their structure, then retain the original template: its
            // L is not an index into this state collection.
            if (op == "assocforeach") {
                  unsigned property = 0;
                  if (template_depth_
                      || !unsigned_token_(parser.read_token(), property)
                      || property >= receiver_->get_defn()->property_count())
                        return false;
                  const char*begin = parser.p;
                  state_foreach_value_t ignored;
                  ++template_depth_;
                  bool valid = expression(parser, ignored);
                  --template_depth_;
                  if (!valid || !parser.expect(')')) return false;
                  out.text = "(assocforeach " + to_string(property)
                        + string(begin, parser.p - begin);
                  return true;
            }
            if (op == "qkeymember") {
                  unsigned member = 0, unused = 0, width = 0; bool sign = false;
                  if (!header_(parser.read_token(), "", member, unused,
                               width, sign, false)
                      || !parser.expect(')')) return false;
                  out.text = "(qkeymember " + to_string(member) + ":"
                        + to_string(width) + (sign ? ":s)" : ")");
                  out.ground = false;
                  return true;
            }
            if (op == "dynforeach" || op == "delem" || op == "qmelem") {
                  const char*begin = parser.p;
                  unsigned property = 0, member = 0, width = 0; bool sign = false;
                  if (!header_(parser.read_token(), "", property, member, width,
                               sign, op == "qmelem")
                      || property >= receiver_->get_defn()->property_count()) return false;
                  bool loop = op == "dynforeach";
                  if (loop && template_depth_) return false;
                  if (loop) ++template_depth_;
                  state_foreach_value_t ignored;
                  bool valid = expression(parser, ignored);
                  if (loop) --template_depth_;
                  if (!valid || !parser.expect(')')) return false;
                  out.text = "(" + op + string(begin, parser.p - begin);
                  return true;
            }
            if (op == "qforeach") {
                  unsigned slot = 0, member = 0;
                  if (template_depth_ || !unsigned_token_(parser.read_token(), slot)
                      || slot >= objects_.size()
                      || !unsigned_token_(parser.read_token(), member)) return false;
                  parser.skip_ws();
                  const char*begin = parser.p;
                  state_foreach_value_t ignored;
                  ++template_depth_;
                  bool valid = expression(parser, ignored);
                  --template_depth_;
                  string body(begin, parser.p - begin);
                  if (!valid || !parser.expect(')')) return false;
                  if (member == UINT_MAX) {
                        queues_[slot] = objects_[slot];
                  } else {
                        vvp_cobject*owner = objects_[slot].peek<vvp_cobject>();
                        if (!owner) {
                              error_(out, "null/non-class state foreach collection owner");
                              return true;
                        }
                        const class_type*type = owner->get_defn();
                        if (member >= type->property_count()
                            || type->property_array_size(member) != 1) return false;
                        const string&base_type = type->property_base_type(member);
                        if (base_type.empty() || (base_type[0] != 'Q' && base_type[0] != 'D'))
                              return false;
                        owner->get_object(member, queues_[slot], 0);
                  }
                  vvp_darray*queue = member == UINT_MAX
                        ? direct_queue_(slot, out) : queue_(slot, out);
                  if (!out.error.empty()) return true;
                  constant_(out, 1);
                  for (size_t i = 0; queue && i < queue->get_size(); ++i) {
                        string instance = subst_loop_token(body, i);
                        IRParser expanded(instance);
                        state_foreach_value_t item;
                        if (!expression(expanded, item) || !expanded.at_end()) return false;
                        if (!item.error.empty()) { out = item; return true; }
                        out.text = "(and " + out.text + " " + item.text + ")";
                        out.ground = out.ground && item.ground;
                  }
                  return true;
            }
            if (op == "qfield") {
                  unsigned slot = 0, member = 0, width = 0; bool sign = false;
                  if (!header_(parser.read_token(), "qf:", slot, member, width, sign, true)
                      || slot >= objects_.size()) return false;
                  state_foreach_value_t index;
                  if (!expression(parser, index) || !parser.expect(')')) return false;
                  if (template_depth_) { out.text = "L"; return true; }
                  uint64_t offset = 0;
                  bool negative = false;
                  if (!number_(index, offset, &negative)) {
                        error_(out, index.error.empty() ? "non-state index in state foreach" : index.error, width, sign);
                        return true;
                  }
                  vvp_darray*queue = member == UINT_MAX
                        ? direct_queue_(slot, out) : queue_(slot, out);
                  if (!out.error.empty()) return true;
                  if (negative || !queue || offset >= queue->get_size() || offset > UINT_MAX) {
                        error_(out, "out-of-bounds state foreach index", width, sign);
                        return true;
                  }
                  if (member == UINT_MAX) {
                        vvp_vector4_t word;
                        queue->get_word((unsigned)offset, word);
                        word_(out, word, width, sign);
                  } else {
                        vvp_object_t object;
                        queue->get_word((unsigned)offset, object);
                        field_(out, object.peek<vvp_cobject>(), member, width, sign);
                  }
                  return true;
            }
            vector<state_foreach_value_t> args;
            while (parser.peek() && parser.peek() != ')') {
                  state_foreach_value_t arg;
                  if (!expression(parser, arg)) return false;
                  args.push_back(arg);
            }
            if (!parser.expect(')')) return false;
            // Validate before calling the older, permissive solver parser.
            static const map<string, unsigned> arities = {
                  {"not",1}, {"neg",1}, {"bnot",1}, {"redand",1},
                  {"redor",1}, {"redxor",1}, {"countones",1},
                  {"onehot",1}, {"onehot0",1}, {"soft",1}, {"disable-soft",1},
                  {"add",2}, {"sub",2}, {"mul",2}, {"div",2}, {"mod",2},
                  {"pow",2}, {"lt",2}, {"le",2}, {"gt",2}, {"ge",2},
                  {"eq",2}, {"ne",2}, {"and",2}, {"or",2}, {"impl",2},
                  {"iff",2}, {"band",2}, {"bor",2}, {"bxor",2},
                  {"shl",2}, {"lshr",2}, {"ashr",2}, {"bit",2},
                  {"order",2}, {"ite",3}, {"part",3}, {"cast",3}
            };
            auto arity = arities.find(op);
            bool directive = op == "order" || op == "vars" || op == "dist"
                  || op == "b" || op == "soft" || op == "disable-soft";
            if (arity != arities.end()) {
                  if (args.size() != arity->second) return false;
            } else if (op.compare(0, 6, "trunc:") == 0) {
                  unsigned unused = 0, member = 0, width = 0; bool sign = false;
                  if (args.size() != 1 || !header_("0:" + op.substr(6), "",
                      unused, member, width, sign, false)) return false;
            } else if (op == "inside" || op == "dist") {
                  if (args.size() < 2) return false;
            } else if (op == "b") {
                  if (args.size() != 2 && args.size() != 3) return false;
            } else if (op != "concat" && op != "vars") return false;
            out.text = "(" + op;
            out.ground = !directive;
            for (const auto&arg : args) {
                  out.text += " " + arg.text;
                  out.ground = out.ground && arg.ground;
                  if (out.error.empty()) out.error = arg.error;
            }
            out.text += ")";
            uint64_t bits = 0;
            if (op == "impl" || op == "and" || op == "or") {
                  if (args.size() != 2) return false;
                  if (op == "impl" && number_(args[0], bits)) {
                        if (!bits) constant_(out, 1);
                        else out = args[1];
                  } else if (op != "impl") {
                        for (const auto&arg : args)
                              if (number_(arg, bits) && ((op == "and" && !bits)
                                  || (op == "or" && bits))) {
                                    constant_(out, op == "or");
                                    break;
                              }
                  }
            } else if (op == "ite" && number_(args[0], bits)) {
                  // Preserve both typed arms: pruning changes ternary width
                  // and signedness (IEEE 1800-2017/2023 11.6.1, 11.8.2).
                  out.error = args[bits ? 1 : 2].error;
                  out.ground = args[bits ? 1 : 2].ground;
            } else if ((op == "div" || op == "mod")
                       && number_(args[1], bits) && !bits) {
                  // IEEE 1800-2017/2023 11.4.3, 18.3: zero division
                  // produces X, which cannot be used as a constraint value.
                  // Keep the expression's type for an enclosing ternary.
                  out.error = "division/remainder by zero in state constraint";
                  out.ground = false;
            }
            return true;
      }
};

static bool expand_state_foreach_(const string&ir,
      const vector<vvp_vector4_t>&slot_vals,
      const vector<vvp_object_t>&objects, vvp_cobject*receiver,
      const vector<bool>*active, string&expanded, z3_object_graph_t*graph)
{
      if (!receiver) {
            fprintf(stderr, "ERROR: state foreach constraint: null/non-class randomize receiver.\n");
            return false;
      }
      state_foreach_expander_t expander(slot_vals, objects, receiver, active, graph);
      IRParser parser(ir);
      expanded.clear();
      while (!parser.at_end()) {
            state_foreach_value_t result;
            if (!expander.expression(parser, result) || !result.error.empty()) {
                  fprintf(stderr, "ERROR: state foreach constraint: %s.\n",
                          result.error.empty() ? "malformed object/constraint metadata"
                                               : result.error.c_str());
                  return false;
            }
            if (!expanded.empty()) expanded += " ";
            expanded += result.text;
      }
      return true;
}

bool vvp_z3_expand_state_foreach(const string&ir,
      const vector<vvp_vector4_t>&slot_vals,
      const vector<vvp_object_t>&objects, vvp_cobject*receiver,
      const vector<bool>*active, string&expanded)
{
      return expand_state_foreach_(ir, slot_vals, objects, receiver, active,
                                   expanded, nullptr);
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
 * object further. Thus the two internal passes consume one external stream.
 * This local tape does not itself rewind the object after failure; the
 * enclosing randomize graph transaction journals and restores every visited
 * object's RNG as part of the campaign's atomic-call contract.
 *
 * uniform_index uses rejection against the largest multiple of `bound' in
 * [0,2^32), eliminating the low-index bias of `rng_next() % bound'. Exact
 * dist aggregate totals can exceed 2^32, so uniform_u64 combines two words
 * and uses the equivalent full-width rejection boundary. */
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

      uint64_t uniform_u64(uint64_t bound)
      {
	    assert(bound > 0);
	      /* Unsigned negation wraps modulo 2^64. The resulting threshold
	       * is 2^64 mod bound, so [threshold,2^64) contains an integral
	       * number of complete residue classes. */
	    const uint64_t threshold = (uint64_t)(0 - bound) % bound;
	    uint64_t word;
	    do {
		  word = ((uint64_t)next() << 32) | (uint64_t)next();
	    } while (word < threshold);
	    return word % bound;
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

static bool rand_member_elem_active_(const class_type*defn,
		vvp_cobject*cobj, const std::vector<bool>*sel,
		unsigned outer, unsigned member, unsigned elem)
{
      if (!rand_active_(defn, cobj, sel, outer)) return false;
      vvp_cobject*owner = cobj_struct_prop(cobj, outer);
      return owner && rand_elem_active_(owner->get_defn(), owner, nullptr,
				       member, elem);
}

bool z3_object_graph_t::active(unsigned idx) const
{
      for (const auto&binding : properties.at(idx).bindings)
            if (rand_active_(binding.scope->object->get_defn(),
                  binding.scope->object, binding.scope->selection(), binding.pid)
                && (!binding.scope->staged_selection
                    || any_of(binding.scope->staged_active.begin(),
                              binding.scope->staged_active.end(),
                              [&](const vvp_z3_ref_s&ref) {
                                    return ref.kind == vvp_z3_ref_s::PROP
                                          && ref.property == binding.pid;
                              })))
                  return true;
      return false;
}

void z3_object_graph_t::select_storage_owners()
{
      for (auto&property : properties)
            for (const auto&binding : property.bindings)
                  if (rand_active_(binding.scope->object->get_defn(),
                        binding.scope->object, binding.scope->selection(), binding.pid)) {
                        property.object = binding.scope->object;
                        property.pid = binding.pid;
                        property.rng_owner = binding.scope->rng_owner;
                        break;
                  }
}

bool z3_object_graph_t::element_active(unsigned idx, unsigned elem) const
{
      for (const auto&binding : properties.at(idx).bindings)
            if (rand_elem_active_(binding.scope->object->get_defn(),
                  binding.scope->object, binding.scope->selection(), binding.pid, elem)
                && (!binding.scope->staged_selection
                    || any_of(binding.scope->staged_active.begin(),
                              binding.scope->staged_active.end(),
                              [&](const vvp_z3_ref_s&ref) {
                                    return ref.kind == vvp_z3_ref_s::ELEM
                                          && ref.property == binding.pid
                                          && ref.leaf == elem;
                              })))
                  return true;
      return false;
}

bool z3_object_graph_t::member_active(unsigned idx, unsigned member) const
{
      for (const auto&binding : properties.at(idx).bindings)
            if (rand_member_active_(binding.scope->object->get_defn(),
                  binding.scope->object, binding.scope->selection(),
                  binding.pid, member)
                && (!binding.scope->staged_selection
                    || any_of(binding.scope->staged_active.begin(),
                              binding.scope->staged_active.end(),
                              [&](const vvp_z3_ref_s&ref) {
                                    return ref.kind == vvp_z3_ref_s::MEMBER
                                          && ref.property == binding.pid
                                          && ref.leaf == member;
                              })))
                  return true;
      return false;
}

bool z3_object_graph_t::size_active(unsigned idx) const
{
      for (const auto&binding : properties.at(idx).bindings)
            if (rand_active_(binding.scope->object->get_defn(),
                  binding.scope->object, binding.scope->selection(), binding.pid)
                && (!binding.scope->staged_selection
                    || any_of(binding.scope->staged_active.begin(),
                              binding.scope->staged_active.end(),
                              [&](const vvp_z3_ref_s&ref) {
                                    return ref.kind == vvp_z3_ref_s::SIZE
                                          && ref.property == binding.pid;
                              })))
                  return true;
      return false;
}

static bool rand_active_(const Z3Builder&builder,
      const vector<bool>*selection, unsigned idx)
{
      return builder.graph ? builder.graph->active(idx)
            : rand_active_(builder.defn, builder.cobj, selection, idx);
}

static bool rand_scalar_active_(const Z3Builder&builder,
      const vector<bool>*selection, unsigned idx)
{
      if (builder.graph) {
            const string&type = builder.type(idx)->property_base_type(builder.local_index(idx));
            // A rand handle selects its object; its address/non-nullness is
            // state, not a random bit (IEEE 1800-2017/2023 18.4).
            if (type == "o" || type.compare(0, 3, "oc:") == 0
                || (!type.empty() && (type[0] == 'D' || type[0] == 'Q' || type[0] == 'M')))
                  return false;
      }
      return rand_active_(builder, selection, idx);
}

static bool rand_elem_active_(const Z3Builder&builder,
      const vector<bool>*selection, unsigned idx, unsigned elem)
{
      return builder.graph ? builder.graph->element_active(idx, elem)
            : rand_elem_active_(builder.defn, builder.cobj, selection, idx, elem);
}

static bool rand_size_active_(const Z3Builder&builder,
      const vector<bool>*selection, unsigned idx)
{
      return builder.graph ? builder.graph->size_active(idx)
            : rand_active_(builder.defn, builder.cobj, selection, idx);
}

static bool rand_member_active_(const Z3Builder&builder,
      const vector<bool>*selection, unsigned outer, unsigned member)
{
      if (!builder.graph)
            return rand_member_active_(builder.defn, builder.cobj,
                                       selection, outer, member);
      if (!builder.graph->member_active(outer, member)) return false;
      vvp_cobject*owner = cobj_struct_prop(builder.object(outer),
                                          builder.local_index(outer));
      return owner != nullptr;
}

static bool rand_member_elem_active_(const Z3Builder&builder,
		const vector<bool>*selection, unsigned outer,
		unsigned member, unsigned elem)
{
      if (builder.graph) {
	    vvp_cobject*owner = cobj_struct_prop(builder.object(outer),
					  builder.local_index(outer));
	    if (!owner) return false;
	    unsigned idx = builder.graph->intern(owner, member);
	    return builder.graph->element_active(idx, elem);
      }
      return rand_member_elem_active_(builder.defn, builder.cobj, selection,
				      outer, member, elem);
}

/* IEEE 1800-2017 18.5.13 / 1800-2023 18.5.12: classify from source
 * references before simplifying. x==x or x**0 is still RANDOM when x is
 * active; ordinary state variables, including disabled rand fields, can
 * decide a guard before the solver pins them. Logical sifting is performed
 * recursively by build_z3_expr and takes precedence over this leaf check. */
static Z3_lbool state_guard_truth_(Z3Builder&b, Z3_ast value,
                                  const set<Z3Builder::VarRef>&refs)
{
      bool random = false;
      set<Z3Builder::VarRef> state_refs;
      for (const auto&ref : refs) {
            if (!b.defn) return Z3_L_UNDEF; // scope randomize arguments
            bool active = ref.kind == Z3Builder::VarRef::PROP
                  ? rand_scalar_active_(b, b.prop_active, ref.idx)
                  : ref.kind == Z3Builder::VarRef::MEMBER
                    ? rand_member_active_(b, b.prop_active, ref.idx, ref.leaf)
                    : ref.kind == Z3Builder::VarRef::MEMBER_ELEM
                      ? rand_member_elem_active_(b, b.prop_active, ref.idx,
						ref.leaf, ref.subleaf)
                    : ref.kind == Z3Builder::VarRef::ELEM
                      ? rand_elem_active_(b, b.prop_active, ref.idx, ref.leaf)
                      : !(b.dyn_sizes && b.dyn_sizes->count(ref.idx))
                        && rand_size_active_(b, b.prop_active, ref.idx);
            if (active) random = true;
            else state_refs.insert(ref);
      }
      vector<Z3_ast> from, to;
      for (const auto&alias : b.signed_constant_aliases) {
            from.push_back(alias.first);
            to.push_back(alias.second);
      }
      auto bits = [&](Z3_ast var, uint64_t number) {
            from.push_back(var);
            to.push_back(Z3_mk_unsigned_int64(b.ctx, number, Z3_get_sort(b.ctx, var)));
      };
      auto word = [&](Z3_ast var, const vvp_vector4_t&data) {
            uint64_t number = 0;
            if (!vec4_to_uint64_(data, number)) {
                  b.state_errors.push_back("unsupported width or X/Z value in constraint guard (IEEE 1800-2017/2023 18.3)");
                  return false;
            }
            bits(var, number);
            return true;
      };
      for (const auto&ref : state_refs) {
            if (ref.kind == Z3Builder::VarRef::PROP) {
                  for (const auto&var : b.prop_vars) if (var.idx == ref.idx) {
                        vvp_vector4_t data;
                        b.object(var.idx)->get_vec4(b.local_index(var.idx), data);
                        if (!word(var.var, data)) return Z3_L_UNDEF;
                  }
            } else if (ref.kind == Z3Builder::VarRef::MEMBER) {
                  for (const auto&var : b.member_vars)
                        if (var.outer == ref.idx && var.member == ref.leaf) {
                              vvp_cobject*owner = cobj_struct_prop(b.object(var.outer), b.local_index(var.outer));
                              vvp_vector4_t data;
                              if (owner) owner->get_vec4(var.member, data);
                              if (!word(var.var, data)) return Z3_L_UNDEF;
                        }
            } else if (ref.kind == Z3Builder::VarRef::ELEM) {
                  for (const auto&var : b.elem_vars)
                        if (var.idx == ref.idx && var.elem == ref.leaf) {
                              vvp_cobject*owner = b.object(var.idx);
                              unsigned pid = b.local_index(var.idx);
                              vvp_vector4_t data;
                              const string&type = owner->get_defn()->property_base_type(pid);
                              if (!type.empty() && (type[0] == 'D' || type[0] == 'Q')) {
                                    vvp_object_t collection;
                                    owner->get_object(pid, collection, 0);
                                    vvp_darray*array = collection.peek<vvp_darray>();
                                    if (array && var.elem < array->get_size()) array->get_word(var.elem, data);
                              } else if (!type.empty() && type[0] == 'M') {
                                    // ELEM identifies the same occupied entry
                                    // used by cobj_elem_bits, retaining X/Z for
                                    // IEEE 1800-2017/2023 18.3 validation.
                                    vvp_object_t collection;
                                    owner->get_object(pid, collection, 0);
                                    if (vvp_assoc_base*array = collection.peek<vvp_assoc_base>()) {
                                          string key, text;
                                          double real = 0;
                                          int kind = -1;
                                          if (!array->peek_entry(var.elem, key, data, real, text, kind)
                                              || kind != 0) data = vvp_vector4_t();
                                    }
                              } else if (!type.empty() && type[0] != 'M'
                                  && var.elem < owner->get_defn()->property_array_size(pid))
                                    owner->get_vec4(pid, data, var.elem);
                              if (!word(var.var, data)) return Z3_L_UNDEF;
                        }
            } else if (ref.kind == Z3Builder::VarRef::MEMBER_ELEM) {
                  for (const auto&var : b.member_elem_vars)
                        if (var.outer == ref.idx && var.member == ref.leaf
                            && var.elem == ref.subleaf) {
                              vvp_vector4_t data;
                              cobj_member_elem_vec4_(b.object(var.outer),
                                    b.local_index(var.outer), var.member,
                                    var.elem, data);
                              if (!word(var.var, data)) return Z3_L_UNDEF;
                        }
            } else {
                  for (const auto&var : b.size_vars) if (var.idx == ref.idx)
                        bits(var.var, cobj_darray_size(b.object(var.idx), b.local_index(var.idx)));
            }
      }
      for (const auto&var : b.qelem_vars)
            bits(var.var, cobj_qelem_member_bits(b.cobj, var.qprop, var.elem, var.member));
      if (random) return Z3_L_UNDEF;
      if (!from.empty()) value = Z3_substitute(b.ctx, value, from.size(), from.data(), to.data());
      return Z3_get_bool_value(b.ctx, Z3_simplify(b.ctx, bv_to_bool(b.ctx, value)));
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

static bool z3_direct_constant_(Z3_context ctx, Z3_ast value)
{
      if (!value || Z3_get_ast_kind(ctx, value) != Z3_APP_AST) return false;
      Z3_app app = Z3_to_app(ctx, value);
      return Z3_get_decl_kind(ctx, Z3_get_app_decl(ctx, app))
                  == Z3_OP_UNINTERPRETED
            && Z3_get_app_num_args(ctx, app) == 0;
}

static bool z3_collect_constants_(Z3_context ctx, Z3_ast value,
                                  set<Z3_ast>&constants)
{
      vector<Z3_ast> pending(1, value);
      set<Z3_ast> visited;
      while (!pending.empty()) {
            Z3_ast node = pending.back();
            pending.pop_back();
            if (!visited.insert(node).second) continue;
            Z3_ast_kind kind = Z3_get_ast_kind(ctx, node);
            if (kind == Z3_NUMERAL_AST) continue;
            if (kind != Z3_APP_AST) return false;
            Z3_app app = Z3_to_app(ctx, node);
            unsigned count = Z3_get_app_num_args(ctx, app);
            if (Z3_get_decl_kind(ctx, Z3_get_app_decl(ctx, app))
                  == Z3_OP_UNINTERPRETED) {
                  if (count != 0) return false;
                  constants.insert(node);
                  continue;
            }
            for (unsigned idx = 0; idx < count; ++idx)
                  pending.push_back(Z3_get_app_arg(ctx, app, idx));
      }
      return true;
}

static void z3_flatten_conjunction_(Z3_context ctx, Z3_ast value,
                                    vector<Z3_ast>&clauses)
{
      if (value && Z3_get_ast_kind(ctx, value) == Z3_APP_AST) {
            Z3_app app = Z3_to_app(ctx, value);
            if (Z3_get_decl_kind(ctx, Z3_get_app_decl(ctx, app)) == Z3_OP_AND) {
                  for (unsigned idx = 0; idx < Z3_get_app_num_args(ctx, app); ++idx)
                        z3_flatten_conjunction_(ctx,
                              Z3_get_app_arg(ctx, app, idx), clauses);
                  return;
            }
      }
      clauses.push_back(value);
}

/* Build the exact hard factor for one direct distribution subject. State and
 * earlier-stage pins are usable only when the solver contains a direct
 * equality that proves their ground value. Substitute those equalities to a
 * fixed point before selecting the subject clauses. A retained subject clause
 * with any other free constant is a coupled factor and is outside this exact
 * sampler; in particular, merely marking a property inactive is not proof that
 * it remains fixed under the negated-factor queries below. */
static bool z3_isolated_subject_factor_(Z3_context ctx, Z3_solver base,
                                        Z3_ast subject, Z3_ast&factor)
{
      if (!z3_direct_constant_(ctx, subject)) return false;

      vector<Z3_ast> clauses;
      Z3_ast_vector assertions = Z3_solver_get_assertions(ctx, base);
      Z3_ast_vector_inc_ref(ctx, assertions);
      for (unsigned idx = 0; idx < Z3_ast_vector_size(ctx, assertions); ++idx)
            z3_flatten_conjunction_(ctx,
                  Z3_ast_vector_get(ctx, assertions, idx), clauses);
      Z3_ast_vector_dec_ref(ctx, assertions);

      vector<Z3_ast> from;
      vector<Z3_ast> to;
      bool changed = true;
      while (changed) {
            changed = false;
            for (Z3_ast original : clauses) {
                  Z3_ast clause = original;
                  if (!from.empty())
                        clause = Z3_substitute(ctx, clause, (unsigned)from.size(),
                                               from.data(), to.data());
                  clause = Z3_simplify(ctx, clause);
                  if (Z3_get_ast_kind(ctx, clause) != Z3_APP_AST) continue;
                  Z3_app app = Z3_to_app(ctx, clause);
                  if (Z3_get_decl_kind(ctx, Z3_get_app_decl(ctx, app)) != Z3_OP_EQ
                      || Z3_get_app_num_args(ctx, app) != 2)
                        continue;
                  Z3_ast sides[2] = {Z3_get_app_arg(ctx, app, 0),
                                     Z3_get_app_arg(ctx, app, 1)};
                  for (unsigned side = 0; side < 2; ++side) {
                        Z3_ast var = sides[side];
                        Z3_ast value = Z3_simplify(ctx, sides[1 - side]);
                        if (var == subject || !z3_direct_constant_(ctx, var)
                            || find(from.begin(), from.end(), var) != from.end())
                              continue;
                        set<Z3_ast> constants;
                        if (!z3_collect_constants_(ctx, value, constants)
                            || !constants.empty())
                              continue;
                        from.push_back(var);
                        to.push_back(value);
                        changed = true;
                        break;
                  }
            }
      }

      vector<Z3_ast> local;
      for (Z3_ast clause : clauses) {
            if (!from.empty())
                  clause = Z3_substitute(ctx, clause, (unsigned)from.size(),
                                         from.data(), to.data());
            clause = Z3_simplify(ctx, clause);
            set<Z3_ast> constants;
            if (!z3_collect_constants_(ctx, clause, constants)) return false;
            if (!constants.count(subject)) continue;
            if (constants.size() != 1) return false;
            local.push_back(clause);
      }
      factor = local.empty() ? Z3_mk_true(ctx)
            : local.size() == 1 ? local[0]
            : Z3_mk_and(ctx, (unsigned)local.size(), local.data());
      return true;
}

/* RANDOM-DIST fix #2 (IEEE 1800-2023 18.5.3; 2017 18.5.4): `dist`
 * selects an ITEM with probability proportional to that item's aggregate
 * weight, then chooses uniformly among the selected item's feasible member
 * values. For `:=' on an integral range, aggregate weight is the specified
 * weight times the COMPLETE source range size, including values excluded by
 * other constraints. For `:/' it is just the specified weight. Keeping an
 * item as the sampling unit also makes overlapping items additive instead of
 * merging their equal values prematurely.
 *
 * Ranges up to RANGE_EXPAND_CAP retain the bounded enumerator. Larger ranges
 * use exact interval discovery after proving either that the direct subject's
 * local hard factor contains no other free constant or that a compound subject
 * has exactly one value in the complete hard-constraint solution set.
 * Unsupported large-range
 * shapes fail explicitly instead of silently using the probability-inexact
 * weighted-soft fallback. On success the winning value is pinned as a hard
 * equality into both `base` and `opt`. */
static bool z3_resolve_dist_exact(Z3_context ctx, Z3_solver base,
                                   Z3_optimize opt,
                                   const Z3Builder::DistSpec& spec,
				   z3_rng_stream_t& rng,
                                   uint64_t& chosen,
                                   bool require_complete_ranges = false,
                                   bool validate_only = false,
                                   bool*indeterminate = nullptr)
{
      if (indeterminate) *indeterminate = false;
      static const uint64_t RANGE_EXPAND_CAP = 256;
      auto candidate_pin = [&](uint64_t v, unsigned vw,
			       bool comparison_signed) -> Z3_ast {
	      // Match the same self-determined sizing used by the hard branch
	      // clauses above. Pinning at the subject width would truncate an
	      // impossible unsized value (for example 2 for a one-bit Boolean
	      // subject) and leak that branch's weight into a different feasible
	      // value. The parser supplies the branch comparison width so typed
	      // narrow negatives and signed ranges retain their extension.
	    Z3_ast sx = spec.subject;
	    Z3_sort subject_sort = Z3_get_sort(ctx, sx);
	    unsigned physical_width = Z3_get_bv_sort_size(ctx, subject_sort);
	    if (physical_width > vw)
		  sx = Z3_mk_extract(ctx, vw - 1, 0, sx);
	    else if (physical_width < vw) {
		  unsigned extension = vw - physical_width;
		  sx = comparison_signed
			? Z3_mk_sign_ext(ctx, extension, sx)
			: Z3_mk_zero_ext(ctx, extension, sx);
	    }
	    Z3_ast cv = Z3_mk_unsigned_int64(ctx, v,
				       Z3_mk_bv_sort(ctx, vw));
	    return Z3_mk_eq(ctx, sx, cv);
      };

      if (spec.requires_large_exact) {
            auto unsupported = [&]() -> bool {
                  if (indeterminate) *indeterminate = true;
                  return false;
            };
            if (!spec.exact_supported || spec.width == 0 || spec.width > 64)
                  return unsupported();
            Z3_lbool full = Z3_solver_check(ctx, base);
            if (full == Z3_L_UNDEF) return unsupported();
            if (full == Z3_L_FALSE) return false;

            Z3_ast sampling_subject = spec.subject;
            Z3_ast factor = nullptr;
            if (z3_direct_constant_(ctx, spec.subject)) {
                  if (!z3_isolated_subject_factor_(ctx, base, spec.subject,
                                                   factor))
                        return unsupported();
            } else {
                  Z3_sort subject_sort = Z3_get_sort(ctx, spec.subject);
                  if (Z3_get_sort_kind(ctx, subject_sort) != Z3_BV_SORT
                      || Z3_get_bv_sort_size(ctx, subject_sort) > 64)
                        return unsupported();
                  Z3_model model = Z3_solver_get_model(ctx, base);
                  Z3_model_inc_ref(ctx, model);
                  uint64_t singleton_value = 0;
                  bool value_ok = z3_eval_uint64(ctx, model, spec.subject,
                                                 singleton_value);
                  Z3_model_dec_ref(ctx, model);
                  if (!value_ok) return unsupported();
                  Z3_ast value = Z3_mk_unsigned_int64(ctx, singleton_value,
                                                      subject_sort);
                  Z3_ast different = Z3_mk_not(ctx,
                        Z3_mk_eq(ctx, spec.subject, value));
                  Z3_solver_push(ctx, base);
                  Z3_solver_assert(ctx, base, different);
                  Z3_lbool another = Z3_solver_check(ctx, base);
                  Z3_solver_pop(ctx, base, 1);
                  if (another != Z3_L_FALSE) return unsupported();

                  sampling_subject = Z3_mk_fresh_const(ctx,
                        "dist_singleton_subject", subject_sort);
                  factor = Z3_mk_eq(ctx, sampling_subject, value);
            }

            Z3_solver positive = Z3_mk_simple_solver(ctx);
            Z3_solver_inc_ref(ctx, positive);
            Z3_solver negative = Z3_mk_simple_solver(ctx);
            Z3_solver_inc_ref(ctx, negative);
            Z3_solver_assert(ctx, positive, factor);
            Z3_solver_assert(ctx, negative, Z3_mk_not(ctx, factor));
            unsigned physical_width = Z3_get_bv_sort_size(ctx,
                  Z3_get_sort(ctx, sampling_subject));
            auto finish = [&](bool result) -> bool {
                  Z3_solver_dec_ref(ctx, negative);
                  Z3_solver_dec_ref(ctx, positive);
                  return result;
            };
            auto subject_coordinate = [&](const Z3Builder::DistBranch&br)
                  -> Z3_ast {
                  Z3_ast sx = sampling_subject;
                  if (physical_width < br.value_width)
                        sx = br.comparison_signed
                              ? Z3_mk_sign_ext(ctx,
                                    br.value_width - physical_width, sx)
                              : Z3_mk_zero_ext(ctx,
                                    br.value_width - physical_width, sx);
                  if (br.comparison_signed) {
                        uint64_t sign = (uint64_t)1 << (br.value_width - 1);
                        Z3_ast sign_ast = Z3_mk_unsigned_int64(ctx, sign,
                              Z3_mk_bv_sort(ctx, br.value_width));
                        sx = Z3_mk_bvxor(ctx, sx, sign_ast);
                  }
                  return sx;
            };
            auto exists_in = [&](Z3_solver solver,
                                 const Z3Builder::DistBranch&br,
                                 uint64_t lo, uint64_t hi) -> Z3_lbool {
                  if (lo > hi) return Z3_L_FALSE;
                  Z3_ast sx = subject_coordinate(br);
                  Z3_sort sort = Z3_mk_bv_sort(ctx, br.value_width);
                  Z3_ast low = Z3_mk_unsigned_int64(ctx, lo, sort);
                  Z3_ast high = Z3_mk_unsigned_int64(ctx, hi, sort);
                  Z3_ast bounds[2] = {Z3_mk_bvuge(ctx, sx, low),
                                      Z3_mk_bvule(ctx, sx, high)};
                  Z3_ast range = Z3_mk_and(ctx, 2, bounds);
                  Z3_solver_push(ctx, solver);
                  Z3_solver_assert(ctx, solver, range);
                  Z3_lbool result = Z3_solver_check(ctx, solver);
                  Z3_solver_pop(ctx, solver, 1);
                  return result;
            };

            struct ExactInterval { uint64_t lo, hi; };
            struct ExactItem {
                  uint64_t aggregate_weight;
                  uint64_t feasible_count;
                  unsigned value_width;
                  bool comparison_signed;
                  vector<ExactInterval> intervals;
            };
            vector<ExactItem> items;
            static const unsigned MAX_EXACT_INTERVALS = 64;
            for (const auto&br : spec.branches) {
                  if (br.value_width == 0 || br.value_width > 64)
                        return finish(unsupported());
                  if (!br.weight) continue;
                  if (physical_width > br.value_width)
                        return finish(unsupported());
                  uint64_t declared_span = 1;
                  if (br.is_range) {
                        if (br.hi < br.lo) continue;
                        declared_span = br.hi - br.lo + 1;
                        if (declared_span == 0) return finish(unsupported());
                  }
                  ExactItem item = {(uint64_t)br.weight, 0,
                                    br.value_width, br.comparison_signed, {}};
                  if (br.range_weight_per_value) {
                        if (declared_span > UINT64_MAX / item.aggregate_weight)
                              return finish(unsupported());
                        item.aggregate_weight *= declared_span;
                  }

                  uint64_t first = br.lo;
                  if (!br.is_range && br.comparison_signed)
                        first ^= (uint64_t)1 << (br.value_width - 1);
                  uint64_t image_lo = 0;
                  uint64_t image_hi;
                  if (br.comparison_signed) {
                        uint64_t center = (uint64_t)1
                              << (br.value_width - 1);
                        uint64_t half = (uint64_t)1
                              << (physical_width - 1);
                        image_lo = center - half;
                        image_hi = center + half - 1;
                  } else {
                        image_hi = physical_width == 64 ? UINT64_MAX
                              : ((uint64_t)1 << physical_width) - 1;
                  }
                  uint64_t last = br.is_range ? br.hi : first;
                  if (first < image_lo) first = image_lo;
                  if (last > image_hi) last = image_hi;
                  if (first > last) continue;
                  uint64_t cur = first;
                  for (;;) {
                        Z3_lbool any = exists_in(positive, br, cur, last);
                        if (any == Z3_L_UNDEF) return finish(unsupported());
                        if (any == Z3_L_FALSE) break;

                        uint64_t left = cur, right = last;
                        while (left < right) {
                              uint64_t mid = left + (right - left) / 2;
                              Z3_lbool found = exists_in(positive, br, cur, mid);
                              if (found == Z3_L_UNDEF) return finish(unsupported());
                              if (found == Z3_L_TRUE) right = mid;
                              else left = mid + 1;
                        }
                        uint64_t start = left;
                        uint64_t end = last;
                        Z3_lbool gap = exists_in(negative, br, start, last);
                        if (gap == Z3_L_UNDEF) return finish(unsupported());
                        if (gap == Z3_L_TRUE) {
                              left = start;
                              right = last;
                              while (left < right) {
                                    uint64_t mid = left + (right - left) / 2;
                                    Z3_lbool found = exists_in(negative, br,
                                                                start, mid);
                                    if (found == Z3_L_UNDEF)
                                          return finish(unsupported());
                                    if (found == Z3_L_TRUE) right = mid;
                                    else left = mid + 1;
                              }
                              if (left == start) return finish(unsupported());
                              end = left - 1;
                        }
                        if (item.intervals.size() == MAX_EXACT_INTERVALS)
                              return finish(unsupported());
                        uint64_t count = end - start + 1;
                        if (count == 0
                            || item.feasible_count > UINT64_MAX - count)
                              return finish(unsupported());
                        item.intervals.push_back({start, end});
                        item.feasible_count += count;
                        if (end == last) break;
                        cur = end + 1;
                  }
                  if (require_complete_ranges && br.is_range
                      && item.feasible_count != declared_span)
                        return finish(false);
                  if (item.feasible_count && item.aggregate_weight)
                        items.push_back(std::move(item));
            }
            if (items.empty()) return finish(false);

            uint64_t total_weight = 0;
            for (const auto&item : items) {
                  if (total_weight > UINT64_MAX - item.aggregate_weight)
                        return finish(unsupported());
                  total_weight += item.aggregate_weight;
            }
            if (!total_weight) return finish(false);
            if (validate_only) return finish(true);

            uint64_t item_ticket = rng.uniform_u64(total_weight);
            const ExactItem*selected = &items.back();
            for (const auto&item : items) {
                  if (item_ticket < item.aggregate_weight) {
                        selected = &item;
                        break;
                  }
                  item_ticket -= item.aggregate_weight;
            }
            uint64_t value_ticket = selected->feasible_count == 1
                  ? 0 : rng.uniform_u64(selected->feasible_count);
            uint64_t coordinate = selected->intervals.back().hi;
            for (const auto&interval : selected->intervals) {
                  uint64_t count = interval.hi - interval.lo + 1;
                  if (value_ticket < count) {
                        coordinate = interval.lo + value_ticket;
                        break;
                  }
                  value_ticket -= count;
            }
            uint64_t value = coordinate;
            if (selected->comparison_signed)
                  value ^= (uint64_t)1 << (selected->value_width - 1);
            if (selected->value_width < 64)
                  value &= ((uint64_t)1 << selected->value_width) - 1;
            Z3_ast pin = candidate_pin(value, selected->value_width,
                                       selected->comparison_signed);
            Z3_solver_assert(ctx, base, pin);
            Z3_optimize_assert(ctx, opt, pin);
            chosen = value;
            return finish(true);
      }

      struct FeasibleItem {
	    uint64_t aggregate_weight;
	    unsigned value_width;
	    bool comparison_signed;
	    vector<uint64_t> values;
      };
      vector<FeasibleItem> items;
      for (const auto& br : spec.branches) {
	    uint64_t span = 1;
	    if (br.is_range) {
		  if (br.hi < br.lo) continue;
		  span = br.hi - br.lo + 1;
		  if (span == 0 || span > RANGE_EXPAND_CAP) {
			static bool warned_expand_cap = false;
			if (!warned_expand_cap) {
			      fprintf(stderr, "Warning: dist range exceeds the "
				      "%llu-member exact-sampling cap; using the "
				      "weighted-soft fallback (further similar "
				      "warnings suppressed).\n",
				      (unsigned long long)RANGE_EXPAND_CAP);
			      warned_expand_cap = true;
			}
                        if (indeterminate) *indeterminate = true;
			return false;
		  }
	    }

	    FeasibleItem item;
	    item.aggregate_weight = (uint64_t)br.weight;
	    item.value_width = br.value_width;
	    item.comparison_signed = br.comparison_signed;
	    if (br.is_range && br.range_weight_per_value)
		  item.aggregate_weight *= span;

	    uint64_t first = br.lo;
	    uint64_t last = br.is_range ? br.hi : br.lo;
	    for (uint64_t coord = first ; coord <= last ; coord += 1) {
		  uint64_t v = coord;
		  if (br.is_range && br.comparison_signed)
			v ^= (uint64_t)1 << (br.value_width - 1);
		  if (br.value_width < 64)
			v &= ((uint64_t)1 << br.value_width) - 1;
		  Z3_ast eq = candidate_pin(v, br.value_width,
					    br.comparison_signed);
		  Z3_solver_push(ctx, base);
		  Z3_solver_assert(ctx, base, eq);
		  Z3_lbool feasible = Z3_solver_check(ctx, base);
		  Z3_solver_pop(ctx, base, 1);
		    /* UNKNOWN is not evidence that this candidate is infeasible.
		     * Continuing would sample a solver-dependent partial feasible
		     * set when another candidate returned SAT. Abandon the exact
		     * enumeration transactionally and let the caller use its
		     * documented fallback instead. */
		  if (feasible == Z3_L_UNDEF) {
                        if (indeterminate) *indeterminate = true;
			return false;
                  }
		  if (feasible == Z3_L_TRUE)
			item.values.push_back(v);
		  if (coord == UINT64_MAX) break;
	    }
            // 2023 18.5.3 explicitly retains the complete range weight after
            // exclusion; 2017 18.5.4 lacks that clarification. The new shared
            // joint subset admits only fully feasible positive-weight ranges.
            if (require_complete_ranges && br.is_range && item.values.size() != span)
                  return false;
	    if (!item.values.empty() && item.aggregate_weight > 0)
		  items.push_back(item);
      }
      if (items.empty()) return false;

      uint64_t total = 0;
	for (const auto& item : items) {
	    if (item.aggregate_weight > UINT64_MAX - total) {
		  static bool warned_total_overflow = false;
		  if (!warned_total_overflow) {
			fprintf(stderr, "Warning: dist aggregate item weights exceed "
				"the runtime uint64 representation; using the "
				"weighted-soft fallback (further similar warnings "
				"suppressed).\n");
			warned_total_overflow = true;
		  }
                  if (indeterminate) *indeterminate = true;
		  return false;
	    }
	    total += item.aggregate_weight;
	}
	if (total == 0) return false;
      if (validate_only) return true;
      uint64_t ticket = rng.uniform_u64(total);
      size_t item_idx = items.size() - 1;
      for (size_t i = 0 ; i < items.size() ; i += 1) {
	    if (ticket < items[i].aggregate_weight) {
		  item_idx = i;
		  break;
	    }
	    ticket -= items[i].aggregate_weight;
      }

      const FeasibleItem& item = items[item_idx];
      size_t value_idx = item.values.size() == 1
	    ? 0 : rng.uniform_index(item.values.size());
      uint64_t v = item.values[value_idx];
      Z3_ast eq = candidate_pin(v, item.value_width,
				item.comparison_signed);
      Z3_solver_assert(ctx, base, eq);
      Z3_optimize_assert(ctx, opt, eq);
      chosen = v;
      return true;
}

/* IEEE 1800-2017 18.5.10 / 1800-2023 18.5.9: sample complete legal
 * combinations, not independently uniform conditional projections. Block
 * only semantic variables, so auxiliary model assignments are not counted.
 * ponytail: bounded enumeration within independent components; use a proved
 * symbolic sampler when a coupled component exceeds the cap. No partial sets. */
static Z3_lbool z3_enumerate_joint_(Z3_context ctx, Z3_solver base,
      const vector<Z3_ast>&variables, size_t cap,
      vector<vector<uint64_t> >&tuples, const char*&reason)
{
      tuples.clear();
      reason = nullptr;
      for (Z3_ast var : variables) {
            Z3_sort sort = Z3_get_sort(ctx, var);
            if (Z3_get_sort_kind(ctx, sort) != Z3_BV_SORT
                || Z3_get_bv_sort_size(ctx, sort) > 64) {
                  reason = "a joint variable exceeds the supported 64-bit width";
                  return Z3_L_UNDEF;
            }
      }
      Z3_solver_push(ctx, base);
      Z3_lbool result;
      for (;;) {
            result = Z3_solver_check(ctx, base);
            if (result != Z3_L_TRUE) {
                  if (result == Z3_L_UNDEF) reason = "the solver returned UNKNOWN";
                  break;
            }
            if (tuples.size() == cap) {
                  reason = "the complete joint solution set exceeds the enumeration limit";
                  result = Z3_L_UNDEF;
                  break;
            }
            Z3_model model = Z3_solver_get_model(ctx, base);
            Z3_model_inc_ref(ctx, model);
            vector<uint64_t> tuple;
            vector<Z3_ast> different;
            for (Z3_ast var : variables) {
                  uint64_t bits = 0;
                  if (!z3_eval_uint64(ctx, model, var, bits)) {
                        reason = "a joint model value could not be extracted";
                        result = Z3_L_UNDEF;
                        break;
                  }
                  tuple.push_back(bits);
                  Z3_ast value = Z3_mk_unsigned_int64(ctx, bits, Z3_get_sort(ctx, var));
                  different.push_back(Z3_mk_not(ctx, Z3_mk_eq(ctx, var, value)));
            }
            Z3_model_dec_ref(ctx, model);
            if (result != Z3_L_TRUE) break;
            tuples.push_back(std::move(tuple));
            Z3_solver_assert(ctx, base, different.empty() ? Z3_mk_false(ctx)
                  : Z3_mk_or(ctx, (unsigned)different.size(), different.data()));
      }
      Z3_solver_pop(ctx, base, 1);
      if (result == Z3_L_UNDEF) tuples.clear();
      if (result == Z3_L_FALSE && !tuples.empty()) {
            sort(tuples.begin(), tuples.end());
            return Z3_L_TRUE;
      }
      return result;
}

/* IEEE 1800-2017 18.5.9/18.5.10; IEEE 1800-2023 18.5.8/18.5.9:
 * independent factors have a Cartesian product of legal projected tuples.
 * Split only conjunctions. Include every symbolic constant, even state and
 * auxiliary bindings, so indirect dependencies cannot disappear from a factor.
 * Keep the shared solver for feasibility; this partitions sampling, not solving. */
static bool z3_joint_components_(Z3_context ctx, Z3_solver base,
      const vector<Z3_ast>&variables, vector<vector<Z3_ast> >&components)
{
      map<Z3_ast, Z3_ast> parent;
      auto root = [&](Z3_ast var) {
            if (!parent.count(var)) parent[var] = var;
            Z3_ast node = var;
            while (parent[node] != node) node = parent[node];
            while (parent[var] != var) {
                  Z3_ast next = parent[var];
                  parent[var] = node;
                  var = next;
            }
            return node;
      };
      vector<Z3_ast> clauses;
      Z3_ast_vector assertions = Z3_solver_get_assertions(ctx, base);
      Z3_ast_vector_inc_ref(ctx, assertions);
      for (unsigned i = 0; i < Z3_ast_vector_size(ctx, assertions); ++i)
            clauses.push_back(Z3_ast_vector_get(ctx, assertions, i));
      Z3_ast_vector_dec_ref(ctx, assertions);
      while (!clauses.empty()) {
            Z3_ast clause = clauses.back();
            clauses.pop_back();
            if (Z3_get_ast_kind(ctx, clause) == Z3_APP_AST) {
                  Z3_app app = Z3_to_app(ctx, clause);
                  if (Z3_get_decl_kind(ctx, Z3_get_app_decl(ctx, app)) == Z3_OP_AND) {
                        for (unsigned i = 0; i < Z3_get_app_num_args(ctx, app); ++i)
                              clauses.push_back(Z3_get_app_arg(ctx, app, i));
                        continue;
                  }
            }
            vector<Z3_ast> pending(1, clause);
            set<Z3_ast> visited;
            Z3_ast first = nullptr;
            while (!pending.empty()) {
                  Z3_ast node = pending.back();
                  pending.pop_back();
                  if (!visited.insert(node).second) continue;
                  Z3_ast_kind kind = Z3_get_ast_kind(ctx, node);
                  if (kind == Z3_NUMERAL_AST) continue;
                  if (kind != Z3_APP_AST) return false;
                  Z3_app app = Z3_to_app(ctx, node);
                  unsigned count = Z3_get_app_num_args(ctx, app);
                  if (Z3_get_decl_kind(ctx, Z3_get_app_decl(ctx, app)) == Z3_OP_UNINTERPRETED) {
                        if (count) return false;
                        if (!first) first = node;
                        parent[root(node)] = root(first);
                  }
                  for (unsigned i = 0; i < count; ++i)
                        pending.push_back(Z3_get_app_arg(ctx, app, i));
            }
      }
      // Preserve first semantic occurrence order, independent of AST addresses.
      map<Z3_ast, size_t> positions;
      components.clear();
      for (Z3_ast var : variables) {
            Z3_ast representative = root(var);
            auto inserted = positions.emplace(representative, components.size());
            if (inserted.second) components.emplace_back();
            components[inserted.first->second].push_back(var);
      }
      return true;
}

static int z3_solve_pass_(const class_type* defn, vvp_cobject* cobj,
			      z3_rng_stream_t& root_rng,
                      const vector<string>& extra_ir,
                      const vector<uint64_t>& slot_vals,
                      const vector<vvp_vector4_t>& class_slot_vals,
                      const std::map<unsigned,uint64_t>* dyn_sizes,
                      std::vector<Z3Builder::DynForeach>* dyn_out,
                      const std::vector<bool>* prop_active,
                      bool include_class_constraints,
                      z3_object_graph_t*graph = nullptr,
                      map<vvp_cobject*, unique_ptr<z3_rng_stream_t> >*streams = nullptr,
                      const vector<vvp_object_t>*object_vals = nullptr)
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

      Z3Builder builder(ctx, defn, cobj, graph);
      builder.object_vals = object_vals;
      builder.prop_active = prop_active;
      builder.dyn_sizes = dyn_sizes;
      if (graph) {
            /* A staged leaf may be unconstrained by IR. Materialized dynamic
             * ELEM selections still need solver variables so this stage owns
             * their diversity and exactly one randc history event. */
            for (const auto&scope : graph->objects)
                  if (scope.staged_selection)
                        for (const auto&ref : scope.staged_active) {
                              if (ref.kind != vvp_z3_ref_s::ELEM) continue;
                              unsigned idx = graph->intern(scope.object,
                                                          ref.property);
                              const string&type = scope.object->get_defn()
                                    ->property_base_type(ref.property);
                              if (type.empty()
                                  || (type[0] != 'D' && type[0] != 'Q'))
                                    continue;
                              vvp_object_t container;
                              scope.object->get_object(ref.property,
                                                       container, 0);
                              vvp_darray*array = container.peek<vvp_darray>();
                              if (!array || ref.leaf >= array->get_size())
                                    continue;
                              vvp_vector4_t word;
                              array->get_word(ref.leaf, word);
                              if (word.size())
                                    builder.get_elem_var(idx, word.size(),
                                                         ref.leaf);
                        }
      }
      auto owner_rng = [&](vvp_cobject*owner) -> z3_rng_stream_t& {
            if (!streams || !owner || owner == cobj) return root_rng;
            auto&stream = (*streams)[owner];
            if (!stream) stream.reset(new z3_rng_stream_t(owner));
            return *stream;
      };
      auto property_rng = [&](unsigned idx) -> z3_rng_stream_t& {
            return owner_rng(graph ? graph->properties.at(idx).rng_owner : cobj);
      };


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
      auto fail_joint = [&](const char*reason) -> int {
            if (reason) fprintf(stderr, "ERROR: global constraint sampling failed: %s.\n", reason);
            Z3_solver_dec_ref(ctx, base);
            Z3_optimize_dec_ref(ctx, opt);
            Z3_del_context(ctx);
            return Z3PASS_FAILED;
      };
      unsigned class_owners = 0;
      if (graph)
            for (const auto&owner : graph->objects)
                  if (!owner.object->get_defn()->is_struct_type()) ++class_owners;
      const bool exact_joint = class_owners > 1;

      auto parse_owner = [&](const class_type*owner_type, vvp_cobject*owner,
                             const vector<string>&inherited,
                             const vector<string>&extras,
                             const vector<string>&planned_class,
                             const vector<uint64_t>&slots,
                             const vector<vvp_vector4_t>&class_slots,
                             bool use_class, Z3_solver solver, bool optimize,
                             const vvp_z3_object_s*source) {
            builder.defn = owner_type;
            builder.cobj = owner;
            auto add = [&](const string&ir) {
                  if (ir.empty()) return;
                  Z3_ast assertion = parse_constraint_ir(ir, builder);
                  Z3_solver_assert(ctx, solver, assertion);
                  if (optimize) Z3_optimize_assert(ctx, opt, assertion);
            };
            for (const string&ir : inherited) add(ir);
            for (size_t ci = 0; use_class && ci < owner_type->constraint_count(); ++ci)
                  if (!owner || owner->constraint_mode(ci)) {
                        string ir;
                        string error;
                        if (!substitute_class_slots_(owner_type->constraint_ir(ci),
                                                    class_slots, ir, error)) {
                              builder.state_errors.push_back(error);
                              return false;
                        }
                        add(ir);
                  }
            for (const string&source_ir : planned_class) {
                  string ir;
                  string error;
                  if (!substitute_class_slots_(source_ir, class_slots, ir, error)) {
                        builder.state_errors.push_back(error);
                        return false;
                  }
                  add(ir);
            }
            for (const string&source_ir : extras) {
		  string ir;
		  string error;
		  if (!substitute_function_slots_(source_ir,
			  source ? source->slot_words : class_slots, ir, error)) {
			builder.state_errors.push_back(error);
			return false;
		  }
                  if (source && ir.find("(qforeach ") != string::npos) {
                        string expanded;
                        if (!expand_state_foreach_(ir, source->slot_words,
                            source->object_vals, owner, source->selection(),
                            expanded, graph)) return false;
                        add(expanded);
                  } else add(substitute_slots(ir, slots));
            }
            return true;
      };
      vector<const vvp_z3_object_s*> priorities;
      if (graph) {
            for (const auto&owner : graph->objects) priorities.push_back(&owner);
            stable_sort(priorities.begin(), priorities.end(),
                  [](const vvp_z3_object_s*a, const vvp_z3_object_s*b) {
                        size_t n = min(a->priority.size(), b->priority.size());
                        for (size_t i = 0; i < n; ++i)
                              if (a->priority[i] != b->priority[i])
                                    return a->priority[i] < b->priority[i];
                        return a->priority.size() > b->priority.size();
                  });
      }
      auto parse_problem = [&](Z3_solver solver, bool optimize) {
            if (graph) {
                  for (const auto*owner : priorities)
                  {
                        builder.object_vals = &owner->object_vals;
                        if (!parse_owner(owner->object->get_defn(), owner->object,
                              owner->inherited_ir, owner->extra_ir,
                              owner->planned_class_ir, owner->slot_vals,
                              owner->class_slot_vals,
                              owner->include_class_constraints, solver, optimize, owner))
                              return false;
                  }
            } else {
                  if (!parse_owner(defn, cobj, {}, extra_ir, {}, slot_vals,
                                   class_slot_vals, include_class_constraints,
                                   solver, optimize, nullptr))
                        return false;
            }
            builder.defn = defn;
            builder.cobj = cobj;
            return true;
      };
      if (!parse_problem(base, true)) {
            if (!builder.state_errors.empty())
                  fprintf(stderr, "ERROR: constraint state read: %s.\n",
                          builder.state_errors.front().c_str());
            return fail_joint(nullptr);
      }
      if (!builder.state_errors.empty()) {
            fprintf(stderr, "ERROR: constraint state read: %s.\n",
                    builder.state_errors.front().c_str());
            return fail_joint(nullptr);
      }
      if (graph && !builder.pending_soft.empty()) {
            for (const auto&owner : graph->objects)
                  if (owner.cyclic) {
                        fprintf(stderr, "ERROR: soft constraint priority on a cyclic object graph is not yet supported.\n");
                        Z3_solver_dec_ref(ctx, base);
                        Z3_optimize_dec_ref(ctx, opt);
                        Z3_del_context(ctx);
                        return Z3PASS_FAILED;
                  }
      }
      if (graph && !graph->valid) {
            fprintf(stderr, "ERROR: global constraint references invalid object storage.\n");
            Z3_solver_dec_ref(ctx, base);
            Z3_optimize_dec_ref(ctx, opt);
            Z3_del_context(ctx);
            return Z3PASS_FAILED;
      }
      if (dyn_out)
	    *dyn_out = builder.dyn_foreach;
      const bool defer_joint = exact_joint && !dyn_sizes && !builder.dyn_foreach.empty();

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
	    if (rand_scalar_active_(builder, prop_active, pv.idx)) continue;
	    Z3_sort sort = Z3_mk_bv_sort(ctx, pv.width);
	    Z3_ast cv = Z3_mk_unsigned_int64(ctx,
		  cobj_prop_bits(builder.object(pv.idx), builder.local_index(pv.idx)), sort);
	    Z3_ast eq = Z3_mk_eq(ctx, pv.var, cv);
	    Z3_optimize_assert(ctx, opt, eq);
	    Z3_solver_assert(ctx, base, eq);
      }
	// Legacy state-only object-element reads retain their current values.
	// Active graph references have already become canonical PropVars.
      for (auto& qv : builder.qelem_vars) {
	    Z3_sort qs = Z3_mk_bv_sort(ctx, qv.width);
	    Z3_ast qcv = Z3_mk_unsigned_int64(ctx,
		  cobj_qelem_member_bits(builder.object(qv.qprop), builder.local_index(qv.qprop), qv.elem, qv.member), qs);
	    Z3_ast qeq = Z3_mk_eq(ctx, qv.var, qcv);
	    Z3_optimize_assert(ctx, opt, qeq);
	    Z3_solver_assert(ctx, base, qeq);
      }
      for (auto& mv : builder.member_vars) {
	    if (rand_member_active_(builder, prop_active,
				    mv.outer, mv.member))
		  continue;
	    Z3_sort sort = Z3_mk_bv_sort(ctx, mv.width);
	    Z3_ast cv = Z3_mk_unsigned_int64(ctx,
		  cobj_member_bits(builder.object(mv.outer), builder.local_index(mv.outer), mv.member), sort);
	    Z3_ast eq = Z3_mk_eq(ctx, mv.var, cv);
	    Z3_optimize_assert(ctx, opt, eq);
	    Z3_solver_assert(ctx, base, eq);
      }
      for (auto&av : builder.member_elem_vars) {
	    if (rand_member_elem_active_(builder, prop_active, av.outer,
					av.member, av.elem))
		  continue;
	    Z3_sort sort = Z3_mk_bv_sort(ctx, av.width);
	    vvp_vector4_t value;
	    Z3_ast cv = cobj_member_elem_vec4_(builder.object(av.outer),
		  builder.local_index(av.outer), av.member, av.elem, value)
		  ? z3_vec4_constant_(ctx, value, av.width) : nullptr;
	    if (!cv) cv = Z3_mk_unsigned_int64(ctx, 0, sort);
	    Z3_ast eq = Z3_mk_eq(ctx, av.var, cv);
	    Z3_optimize_assert(ctx, opt, eq);
	    Z3_solver_assert(ctx, base, eq);
      }
      for (auto& ev : builder.elem_vars) {
	    if (rand_elem_active_(builder, prop_active, ev.idx, ev.elem))
		  continue;
	    Z3_sort sort = Z3_mk_bv_sort(ctx, ev.width);
	    vvp_vector4_t value;
	    Z3_ast cv = cobj_elem_vec4_(builder.object(ev.idx),
	          builder.local_index(ev.idx), ev.elem, value)
	          ? z3_vec4_constant_(ctx, value, ev.width) : nullptr;
	    // A selected X/Z state leaf is rejected by the guarded state check.
	    // Keep a typed placeholder for unselected leaves so they do not lose
	    // their identity while the selector is solved.
	    if (!cv) cv = Z3_mk_unsigned_int64(ctx, 0, sort);
	    Z3_ast eq = Z3_mk_eq(ctx, ev.var, cv);
	    Z3_optimize_assert(ctx, opt, eq);
	    Z3_solver_assert(ctx, base, eq);
      }
      for (auto& sv : builder.size_vars) {
	    if (rand_size_active_(builder, prop_active, sv.idx)) continue;
	    Z3_sort s32 = Z3_mk_bv_sort(ctx, 32);
	    Z3_ast cv = Z3_mk_unsigned_int64(ctx,
		  cobj_darray_size(builder.object(sv.idx), builder.local_index(sv.idx)), s32);
	    Z3_ast eq = Z3_mk_eq(ctx, sv.var, cv);
	    Z3_optimize_assert(ctx, opt, eq);
	    Z3_solver_assert(ctx, base, eq);
      }

      // IEEE 1800-2017/2023 18.4: randomized enum values belong to the
      // declared literal set, whether reached directly or through a struct.
      // Reuse these same domains in the accept-current solver below.
      vector<Z3_ast> enum_domains;
      auto add_enum_domain = [&](const class_type*type, unsigned pid,
                                 unsigned width, Z3_ast variable) {
            if (!type || !type->property_is_enum(pid)) return;
            vector<Z3_ast> literals;
            for (const auto&value : type->property_enum_values(pid)) {
                  uint64_t bits = 0;
                  if (!vec4_to_uint64_(value, bits)) continue;
                  Z3_ast literal = Z3_mk_unsigned_int64(ctx, bits,
                        Z3_mk_bv_sort(ctx, width));
                  literals.push_back(Z3_mk_eq(ctx, variable, literal));
            }
            Z3_ast domain = literals.empty() ? Z3_mk_false(ctx)
                  : literals.size() == 1 ? literals.front()
                  : Z3_mk_or(ctx, (unsigned)literals.size(), literals.data());
            enum_domains.push_back(domain);
            Z3_optimize_assert(ctx, opt, domain);
            Z3_solver_assert(ctx, base, domain);
      };
      if (graph)
            for (const auto&pv : builder.prop_vars)
                  if (rand_scalar_active_(builder, prop_active, pv.idx))
                        add_enum_domain(builder.type(pv.idx), builder.local_index(pv.idx),
                                        pv.width, pv.var);
      for (const auto&mv : builder.member_vars) {
            if (!rand_member_active_(builder, prop_active, mv.outer, mv.member)) continue;
            vvp_cobject*owner = cobj_struct_prop(builder.object(mv.outer),
                                                builder.local_index(mv.outer));
            add_enum_domain(owner ? owner->get_defn() : nullptr,
                            mv.member, mv.width, mv.var);
      }

      // Dynamic-container size variables are bounded by a pragmatic hard cap
      // so an under-constrained `.size() > k` cannot demand a huge
      // allocation. A bounded queue additionally carries its declared
      // maximum count in the Q descriptor; violating that bound is UNSAT.
      for (auto& sv : builder.size_vars) {
	    Z3_sort s32 = Z3_mk_bv_sort(ctx, 32);
	    uint64_t cap_value = random_container_size_cap_(sv.container_type);
            if (exact_joint) {
                  // Keep only the declared queue bound in the solution space.
                  // A practical allocation limit must fail, not bias sizes.
                  random_container_desc_t desc = random_container_desc_(sv.container_type);
                  if (!desc.is_queue || !desc.max_size) continue;
                  cap_value = desc.max_size;
            }
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
			cobj_darray_size(builder.object(sv.idx), builder.local_index(sv.idx)), s32);
		  Z3_ast eq = Z3_mk_eq(ctx, sv.var, cur);
		  Z3_optimize_assert(ctx, opt, eq);
		  Z3_solver_assert(ctx, base, eq);
	    }
      }

      bool state_check_scope = false;
      Z3_ast any_state_error = nullptr;
      if (!builder.state_checks.empty()) {
            any_state_error = constraint_state_error_disjunction_(
                  builder, 0, builder.state_checks.size());
            Z3_ast no_state_error = Z3_mk_not(ctx, any_state_error);
            // Keep a relaxed copy of the hard problem below this scope. It
            // is used only when the legal solve is UNSAT, to distinguish a
            // selected evaluation error from an ordinary contradiction.
            Z3_solver_push(ctx, base);
            state_check_scope = true;
            Z3_solver_assert(ctx, base, no_state_error);
            Z3_optimize_assert(ctx, opt, no_state_error);
      }

      // Apply queued explicit soft assertions. Dist preferences are retained
      // as structural groups and scheduled below at their solve-before rank.
      auto soft_dropped = [&](const Z3Builder::SoftAssert& sa) -> bool {
	    // A disable affects only preferences below it in priority.
	    if (builder.disabled_soft_refs.empty()) return false;
	    for (const Z3Builder::VarRef&ref : sa.refs)
		  if (builder.soft_ref_disabled(ref, sa.priority)) return true;
	    return false;
      };

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
      if (!exact_joint) {
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
		  /* `chk' is independent of the main hard solver, so it does not
		   * inherit the alias==raw clauses that preserve signed constant
		   * occurrence metadata. Ground those aliases in the soft expression
		   * itself; otherwise chk can choose an alias equal to the random
		   * prefill and incorrectly take the accept-current fast path. */
		  Z3_solver_assert(ctx, chk,
				   builder.resolve_signed_constants(sa.a));
	    }
	    bool saved_collect_preferences = builder.collect_preferences;
	    builder.collect_preferences = false;
	    if (!parse_problem(chk, false)) {
                  Z3_solver_dec_ref(ctx, chk);
                  return fail_joint(nullptr);
            }
	    builder.collect_preferences = saved_collect_preferences;
	    for (auto& pv : builder.prop_vars) {
		  uint64_t bits = cobj_prop_bits(builder.object(pv.idx), builder.local_index(pv.idx));
		  Z3_sort sort = Z3_mk_bv_sort(ctx, pv.width);
		  Z3_ast cv = Z3_mk_unsigned_int64(ctx, bits, sort);
		  Z3_solver_assert(ctx, chk, Z3_mk_eq(ctx, pv.var, cv));
	    }
	    for (auto& qv : builder.qelem_vars) {
		  uint64_t qb = cobj_qelem_member_bits(builder.object(qv.qprop), builder.local_index(qv.qprop),
						       qv.elem, qv.member);
		  Z3_sort qs = Z3_mk_bv_sort(ctx, qv.width);
		  Z3_ast qcv = Z3_mk_unsigned_int64(ctx, qb, qs);
		  Z3_solver_assert(ctx, chk, Z3_mk_eq(ctx, qv.var, qcv));
	    }
	    for (auto& mv : builder.member_vars) {
		  uint64_t bits = cobj_member_bits(builder.object(mv.outer), builder.local_index(mv.outer), mv.member);
		  Z3_sort sort = Z3_mk_bv_sort(ctx, mv.width);
		  Z3_ast cv = Z3_mk_unsigned_int64(ctx, bits, sort);
		  Z3_solver_assert(ctx, chk, Z3_mk_eq(ctx, mv.var, cv));
	    }
	    for (auto&av : builder.member_elem_vars) {
		  uint64_t bits = cobj_member_elem_bits(builder.object(av.outer),
			builder.local_index(av.outer), av.member, av.elem);
		  Z3_ast cv = Z3_mk_unsigned_int64(ctx, bits,
			Z3_mk_bv_sort(ctx, av.width));
		  Z3_solver_assert(ctx, chk, Z3_mk_eq(ctx, av.var, cv));
	    }
            for (Z3_ast domain : enum_domains) Z3_solver_assert(ctx, chk, domain);
	    for (auto& sv : builder.size_vars) {
		  uint64_t cur = cobj_darray_size(builder.object(sv.idx), builder.local_index(sv.idx));
		  Z3_sort sort = Z3_mk_bv_sort(ctx, 32);
		  Z3_ast cv = Z3_mk_unsigned_int64(ctx, cur, sort);
		  Z3_solver_assert(ctx, chk, Z3_mk_eq(ctx, sv.var, cv));
	    }
	    for (auto& ev : builder.elem_vars) {
		  Z3_sort sort = Z3_mk_bv_sort(ctx, ev.width);
		  vvp_vector4_t value;
		  Z3_ast cv = cobj_elem_vec4_(builder.object(ev.idx),
		        builder.local_index(ev.idx), ev.elem, value)
		        ? z3_vec4_constant_(ctx, value, ev.width) : nullptr;
		  if (!cv) cv = Z3_mk_unsigned_int64(ctx, 0, sort);
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
			if (rand_size_active_(builder, prop_active, sv.idx))
			      precheck = Z3_L_FALSE;

	      // A constrained randc variable must be selected against its
	      // committed cycle history even when the pre-fill happens to
	      // satisfy the constraints. Accept-current would skip feasible-
	      // domain enumeration and could emit a previously used value.
	    for (auto& pv : builder.prop_vars)
		  if (rand_scalar_active_(builder, prop_active, pv.idx)
		      && builder.type(pv.idx)->property_is_randc(builder.local_index(pv.idx)))
			precheck = Z3_L_FALSE;
	    for (auto& mv : builder.member_vars) {
		  vvp_cobject*owner = cobj_struct_prop(builder.object(mv.outer), builder.local_index(mv.outer));
		  const class_type*member_defn = owner ? owner->get_defn() : nullptr;
		  if (rand_member_active_(builder, prop_active,
					  mv.outer, mv.member)
		      && member_defn
		      && member_defn->property_is_randc(mv.member))
			precheck = Z3_L_FALSE;
	    }
	    for (auto&av : builder.member_elem_vars) {
		  vvp_cobject*owner = cobj_struct_prop(builder.object(av.outer),
			builder.local_index(av.outer));
		  if (rand_member_elem_active_(builder, prop_active, av.outer,
			av.member, av.elem) && owner
		      && owner->get_defn()->property_is_randc(av.member))
			precheck = Z3_L_FALSE;
	    }
	    for (auto& ev : builder.elem_vars)
		  if (rand_elem_active_(builder, prop_active,
					 ev.idx, ev.elem)
		      && builder.type(ev.idx)->property_is_randc(builder.local_index(ev.idx)))
			precheck = Z3_L_FALSE;

	    // A symbolic state selection needs the final model to decide whether
	    // its chosen index names an X/Z leaf or lies outside the declaration.
	    if (!builder.state_checks.empty()) precheck = Z3_L_FALSE;

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
            if (feasible == Z3_L_UNDEF)
                  return fail_joint("the solver returned UNKNOWN while resolving soft priority");
	    if (feasible != Z3_L_TRUE) continue;
	    Z3_solver_assert(ctx, base, sa.a);
	    Z3_optimize_assert(ctx, opt, sa.a);
      }

      auto active_randc_var = [&](Z3_ast var) -> bool {
            for (const auto&pv : builder.prop_vars)
                  if (pv.var == var
                      && rand_scalar_active_(builder, prop_active, pv.idx)
                      && builder.type(pv.idx)->property_is_randc(
                            builder.local_index(pv.idx)))
                        return true;
            for (const auto&ev : builder.elem_vars)
                  if (ev.var == var
                      && rand_elem_active_(builder, prop_active,
                            ev.idx, ev.elem)
                      && builder.type(ev.idx)->property_is_randc(
                            builder.local_index(ev.idx)))
                        return true;
            return false;
      };
      bool defer_ordered_joint_randc = false;
      if (exact_joint && !builder.order_pairs.empty()) {
            for (const auto&pv : builder.prop_vars)
                  defer_ordered_joint_randc |= active_randc_var(pv.var);
            for (const auto&ev : builder.elem_vars)
                  defer_ordered_joint_randc |= active_randc_var(ev.var);
      }

      map<unsigned, uint64_t> proved_joint_sizes;
      if (exact_joint) {
            // Ordered randc/dist and non-scalar stages need separate proofs.
            // Reject before any sampling; a cap failure after a randc draw
            // could otherwise condition successful calls on that draw.
            if (!builder.order_pairs.empty()) {
                  auto supported_element_order_ref = [&](const Z3Builder::OrderRef&ref) {
                        if (ref.kind != Z3Builder::OrderRef::ELEM) return false;
                        const class_type*type = builder.type(ref.idx);
                        unsigned pid = builder.local_index(ref.idx);
                        const string&base = type->property_base_type(pid);
                        bool fixed = type->property_array_size(pid) >= 1
                              && !base.empty() && base != "o"
                              && base.compare(0, 3, "oc:") != 0
                              && base != "r" && base != "S"
                              && base[0] != 'D' && base[0] != 'Q'
                              && base[0] != 'M';
                        const Z3Builder::SizeVar*size = nullptr;
                        for (const auto&candidate : builder.size_vars)
                              if (candidate.idx == ref.idx) {
                                    size = &candidate;
                                    break;
                              }
                        const random_container_desc_t desc = size
                              ? random_container_desc_(size->container_type)
                              : random_container_desc_t();
                        bool variable_integral = size && desc.elem_integral
                              && ((base.size() > 1 && base[0] == 'D')
                                  || desc.is_queue);
                        return fixed || variable_integral;
                  };
                  for (const auto&pair : builder.order_pairs)
                        if ((pair.first.kind != Z3Builder::OrderRef::PROP
                             && !supported_element_order_ref(pair.first))
                            || (pair.second.kind != Z3Builder::OrderRef::PROP
                                && !supported_element_order_ref(pair.second)))
                              return fail_joint("joint solve-before requires canonical scalar or supported element ordering variables");
            }
            vector<Z3_ast> sizes;
            for (const auto&sv : builder.size_vars) sizes.push_back(sv.var);
            if (!sizes.empty()) {
                  vector<vector<uint64_t> > values;
                  const char*reason = nullptr;
                  Z3_lbool fixed = z3_enumerate_joint_(ctx, base, sizes, 1, values, reason);
                  if (fixed == Z3_L_FALSE) return fail_joint(nullptr);
                  if (fixed != Z3_L_TRUE)
                        return fail_joint("global array sizes must have one proven value before element solving");
                  for (size_t i = 0; i < sizes.size(); ++i) {
                        const auto&sv = builder.size_vars[i];
                        proved_joint_sizes[sv.idx] = values[0][i];
                        if (values[0][i] > random_container_size_cap_(sv.container_type))
                              return fail_joint("a fixed array size exceeds the supported allocation limit");
                        if (!rand_size_active_(builder, prop_active, sv.idx)
                            || !builder.type(sv.idx)->property_is_randc(builder.local_index(sv.idx))
                            || random_container_desc_(sv.container_type).elem_width <= 20) continue;
                        for (uint64_t elem = 0; elem < values[0][i]; ++elem)
                              if (rand_elem_active_(builder, prop_active, sv.idx, (unsigned)elem))
                                    return fail_joint("a randc leaf exceeds the supported history representation");
                  }
            }
            for (const auto&pair : builder.order_pairs) {
                  for (const auto&ref : {pair.first, pair.second}) {
                        if (ref.kind != Z3Builder::OrderRef::ELEM) continue;
                        const string&base = builder.type(ref.idx)
                              ->property_base_type(builder.local_index(ref.idx));
                        const Z3Builder::SizeVar*size_var = nullptr;
                        for (const auto&candidate : builder.size_vars)
                              if (candidate.idx == ref.idx) {
                                    size_var = &candidate;
                                    break;
                              }
                        if (!size_var
                            || ((base.empty() || base[0] != 'D')
                                && !random_container_desc_(
                                      size_var->container_type).is_queue))
                              continue;
                        auto size = proved_joint_sizes.find(ref.idx);
                        if (size == proved_joint_sizes.end())
                              return fail_joint("dynamic element ordering requires one proved array size");
                        if (ref.elem >= size->second)
                              return fail_joint("dynamic element ordering index is outside the proved array size");
                  }
            }
      }

	// Dist groups are scheduled independently of ordinary soft constraints.
	// In particular, a future-ranked dist must not bias a variable being
	// solved at an earlier solve...before stage. Exact groups are pinned when
	// their subject becomes due; unsupported groups install their weighted-
	// soft fallback at that same point.
      auto var_ref_active = [&](const Z3Builder::VarRef&ref) -> bool {
	    if (ref.kind == Z3Builder::VarRef::MEMBER_ELEM)
		  return rand_member_elem_active_(builder, prop_active,
			ref.idx, ref.leaf, ref.subleaf);
	    if (ref.kind == Z3Builder::VarRef::ELEM)
		  return rand_elem_active_(builder, prop_active,
				   ref.idx, ref.leaf);
	    if (ref.kind == Z3Builder::VarRef::MEMBER)
		  return rand_member_active_(builder, prop_active,
				     ref.idx, ref.leaf);
	    if (ref.kind == Z3Builder::VarRef::PROP)
                  return rand_scalar_active_(builder, prop_active, ref.idx);
	    return rand_size_active_(builder, prop_active, ref.idx);
      };
      auto dist_disabled = [&](const Z3Builder::DistSpec&spec) -> bool {
	    if (!spec.disableable) return false;
	    for (const auto&ref : spec.disable_refs)
		  if (builder.soft_ref_disabled(ref, spec.priority)) return true;
	    return false;
      };
      auto dist_active = [&](const Z3Builder::DistSpec&spec) -> bool {
	    if (spec.refs.empty()) return true;
	    for (const auto&ref : spec.refs)
		  if (var_ref_active(ref)) return true;
	    return false;
      };
      auto install_dist_fallback = [&](Z3_optimize target,
					 size_t spec_index) {
	    const Z3Builder::DistSpec&spec = builder.dist_specs[spec_index];
	    char group_name[40];
	    snprintf(group_name, sizeof(group_name), "dist%u",
		     (unsigned)spec_index);
	    Z3_symbol group = Z3_mk_string_symbol(ctx, group_name);
	    for (const auto&sa : spec.fallback) {
		  char weight[32];
		  snprintf(weight, sizeof(weight), "%u", sa.weight);
		  Z3_optimize_assert_soft(ctx, target, sa.a, weight, group);
	    }
      };
      std::set<size_t> dist_handled;
      std::set<size_t> dist_fallback_active;
      std::set<Z3_ast> dist_resolved_vars;
      std::set<Z3_ast> dist_fallback_vars;
      std::set<Z3Builder::VarRef> dist_fallback_refs;
      auto resolve_dist = [&](size_t spec_index) -> bool {
            // Joint draws occur only after complete component proofs, and never
            // in the preliminary pass before dynamic foreach expansion.
            if (exact_joint) return true;
	    if (dist_handled.count(spec_index)) return true;
	    dist_handled.insert(spec_index);
	    const Z3Builder::DistSpec&spec = builder.dist_specs[spec_index];
	    if (dist_disabled(spec) || !dist_active(spec)) return true;

	    bool resolved = false;
	    bool indeterminate = false;
	    if (spec.requires_large_exact
	        && dist_resolved_vars.count(spec.subject))
		  indeterminate = true;
	    if ((spec.exact_supported || spec.requires_large_exact)
		&& !dist_resolved_vars.count(spec.subject)) {
		  uint64_t chosen = 0;
		  resolved = z3_resolve_dist_exact(ctx, base, opt, spec, owner_rng(spec.rng_owner),
						 chosen, false, false,
						 &indeterminate);
		  if (resolved) dist_resolved_vars.insert(spec.subject);
	    }
	    if (!resolved && spec.requires_large_exact && indeterminate) {
		  fprintf(stderr, "ERROR: exact dist sampling failed: a large range "
			  "requires one direct or provably singleton <=64-bit "
			  "subject with an isolated ground hard-constraint factor.\n");
		  return false;
	    }
	    if (!resolved) {
		  dist_fallback_active.insert(spec_index);
		  dist_fallback_vars.insert(spec.subject);
		  dist_fallback_refs.insert(spec.refs.begin(), spec.refs.end());
		  install_dist_fallback(opt, spec_index);
	    }
	    return true;
      };
	  auto fallback_ref = [&](Z3Builder::VarRef::Kind kind, unsigned idx,
			     unsigned leaf, unsigned subleaf = 0) -> bool {
	    Z3Builder::VarRef ref = {kind, idx, leaf, subleaf};
	    return dist_fallback_refs.count(ref);
	  };

      bool single_var_fast_ok =
	    builder.prop_vars.size() + builder.member_vars.size()
		  + builder.member_elem_vars.size() == 1
	    && builder.elem_vars.empty() && builder.size_vars.empty();

      bool joint_randc_failed = false;
      map<Z3_ast, uint64_t> sampled_randc_values;
      auto sample_scalars = [&](bool cyclic_only) {
      if (exact_joint && (defer_joint || !cyclic_only)) return;
      for (auto& pv : builder.prop_vars) {
            if (graph && builder.type(pv.idx)->property_is_randc(builder.local_index(pv.idx)) != cyclic_only)
                  continue;
	    if (!rand_scalar_active_(builder, prop_active, pv.idx)) continue;
	    if (dist_resolved_vars.count(pv.var)) continue;
	    bool fallback_managed = dist_fallback_vars.count(pv.var)
		  || fallback_ref(Z3Builder::VarRef::PROP, pv.idx, 0);

	    vector<uint64_t> feasible;
	    bool enumerated = false;
	    if (!fallback_managed && single_var_fast_ok)
		  enumerated = z3_enumerate_domain_single_var_fast_(
			ctx, base, pv.var, pv.width, feasible);
	    if (!fallback_managed && !enumerated)
		  enumerated = z3_enumerate_domain(ctx, base, pv.var,
						pv.width, feasible);
	    if (!fallback_managed && !enumerated)
		  enumerated = z3_enumerate_sparse_wide_domain_(
			ctx, base, pv.var, pv.width, feasible);
	    if (enumerated) {
		  uint64_t chosen;
		  if (builder.type(pv.idx)->property_is_randc(builder.local_index(pv.idx))) {
			uint64_t prefill = cobj_prop_bits(builder.object(pv.idx), builder.local_index(pv.idx));
			vector<uint64_t> available;
			for (uint64_t cand : feasible)
			      if (!builder.object(pv.idx)->randc_seen(builder.local_index(pv.idx), cand))
				    available.push_back(cand);

			// If the constrained feasible subset is exhausted, selecting
			// from the whole subset stages its atomic reset at commit.
			// Otherwise choose uniformly among ONLY the remaining values;
			// random-start linear probing weights a value by the used run
			// before it and is not a uniform permutation.
			const vector<uint64_t>&pool = available.empty()
			      ? feasible : available;
			chosen = pool[property_rng(pv.idx).uniform_index(pool.size())];
			if (chosen != prefill)
			      builder.object(pv.idx)->randc_unmark(builder.local_index(pv.idx), prefill);
			builder.object(pv.idx)->randc_mark_feasible(builder.local_index(pv.idx), chosen, feasible);
                        sampled_randc_values[pv.var] = chosen;
		  } else {
			chosen = feasible[property_rng(pv.idx).uniform_index(feasible.size())];
		  }
		  Z3_sort sort = Z3_mk_bv_sort(ctx, pv.width);
		  Z3_ast cv = Z3_mk_unsigned_int64(ctx, chosen, sort);
		  Z3_ast eq = Z3_mk_eq(ctx, pv.var, cv);
		  Z3_optimize_assert(ctx, opt, eq);
		  Z3_solver_assert(ctx, base, eq);
		  continue;
	    }

            if (exact_joint && builder.type(pv.idx)->property_is_randc(builder.local_index(pv.idx))) {
                  joint_randc_failed = true;
                  return;
            }
	    if (!fallback_managed && builder.type(pv.idx)->property_is_randc(builder.local_index(pv.idx))
                && Z3_solver_check(ctx, base) == Z3_L_TRUE) {
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

	    uint64_t rand_bits = cobj_prop_bits(builder.object(pv.idx), builder.local_index(pv.idx));
	    Z3_sort sort = Z3_mk_bv_sort(ctx, pv.width);
	    Z3_ast rv = Z3_mk_unsigned_int64(ctx, rand_bits, sort);
	    Z3_ast xor_expr = Z3_mk_bvxor(ctx, pv.var, rv);
	    Z3_optimize_minimize(ctx, opt, xor_expr);
      }

	// Unpacked-struct scalar leaves use the same exact feasible-domain
	// selection as direct scalar properties. Their randc history and mode
	// live on the nested value-object, while their RNG remains the owning
	// class object's stream.
      };

      bool single_elem_fast_ok = builder.elem_vars.size() == 1
	    && builder.prop_vars.empty() && builder.member_vars.empty()
	    && builder.member_elem_vars.empty()
	    && builder.size_vars.empty();
      auto sample_elements = [&](bool cyclic_only) {
      if (exact_joint && (defer_joint || !cyclic_only)) return;
      for (auto& ev : builder.elem_vars) {
            if (graph && builder.type(ev.idx)->property_is_randc(builder.local_index(ev.idx)) != cyclic_only)
                  continue;
	    if (!rand_elem_active_(builder, prop_active, ev.idx, ev.elem))
		  continue;

	    const string&elem_base_type = builder.type(ev.idx)->property_base_type(builder.local_index(ev.idx));
	    bool container_randc = builder.type(ev.idx)->property_is_randc(builder.local_index(ev.idx))
		  && !elem_base_type.empty()
		  && (elem_base_type[0] == 'D' || elem_base_type[0] == 'Q'
		      || elem_base_type[0] == 'M');
	    // ElemVar already identifies an array element, including singleton arrays.
	    bool element_randc = builder.type(ev.idx)->property_is_randc(
		  builder.local_index(ev.idx));
	    bool fallback_managed = dist_fallback_vars.count(ev.var)
		  || fallback_ref(Z3Builder::VarRef::ELEM, ev.idx, ev.elem);
	    if (element_randc && !fallback_managed) {
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
			uint64_t prefill = cobj_elem_bits(builder.object(ev.idx), builder.local_index(ev.idx), ev.elem);
			vector<uint64_t> available;
			for (uint64_t candidate : feasible)
			      if (container_randc
				    ? !builder.object(ev.idx)->randc_container_seen(builder.local_index(ev.idx), ev.elem,
							    candidate)
				    : !builder.object(ev.idx)->randc_seen(builder.local_index(ev.idx), candidate,
						       ev.elem))
				    available.push_back(candidate);
			if (available.empty()
			    && find(feasible.begin(), feasible.end(), prefill)
				 != feasible.end())
			      chosen = prefill;
			else {
			      const vector<uint64_t>&pool = available.empty()
				    ? feasible : available;
			      chosen = pool[property_rng(ev.idx).uniform_index(
				    pool.size())];
			}
			if (container_randc) {
			      if (chosen != prefill)
				    builder.object(ev.idx)->randc_container_unmark(builder.local_index(ev.idx), ev.elem,
							   prefill);
			      builder.object(ev.idx)->randc_container_mark_feasible(builder.local_index(ev.idx), ev.elem,
							 chosen, feasible);
			} else {
			      if (chosen != prefill)
				    builder.object(ev.idx)->randc_unmark(builder.local_index(ev.idx), prefill, ev.elem);
			      builder.object(ev.idx)->randc_mark_feasible(builder.local_index(ev.idx), chosen, feasible,
							  ev.elem);
			}
                        sampled_randc_values[ev.var] = chosen;
			Z3_sort sort = Z3_mk_bv_sort(ctx, ev.width);
			Z3_ast cv = Z3_mk_unsigned_int64(ctx, chosen, sort);
			Z3_ast eq = Z3_mk_eq(ctx, ev.var, cv);
			Z3_optimize_assert(ctx, opt, eq);
			Z3_solver_assert(ctx, base, eq);
			continue;
		  }

                  if (exact_joint) {
                        joint_randc_failed = true;
                        return;
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
		  if (property_rng(ev.idx).next() & 1) rand_bits |= (1ULL << b);
	    Z3_sort sort = Z3_mk_bv_sort(ctx, ev.width);
	    Z3_ast rv = Z3_mk_unsigned_int64(ctx, rand_bits, sort);
	    Z3_optimize_minimize(ctx, opt, Z3_mk_bvxor(ctx, ev.var, rv));
      }
      };

      auto sample_member_elements = [&](bool cyclic_only) {
	if (exact_joint && (defer_joint || !cyclic_only)) return;
	for (auto&av : builder.member_elem_vars) {
	      if (!rand_member_elem_active_(builder, prop_active, av.outer,
					 av.member, av.elem)) continue;
	      vvp_cobject*owner = cobj_struct_prop(builder.object(av.outer),
					    builder.local_index(av.outer));
	      bool is_randc = owner
		    && owner->get_defn()->property_is_randc(av.member);
	      if (is_randc != cyclic_only && graph) continue;
	      bool fallback_managed = dist_fallback_vars.count(av.var)
		    || fallback_ref(Z3Builder::VarRef::MEMBER_ELEM,
			av.outer, av.member, av.elem);
	      vector<uint64_t> feasible;
	      bool enumerated = false;
	      if (!fallback_managed && is_randc) {
		    enumerated = z3_enumerate_domain(ctx, base, av.var,
					      av.width, feasible);
		    if (!enumerated)
			  enumerated = z3_enumerate_sparse_wide_domain_(
				ctx, base, av.var, av.width, feasible);
	      }
	      if (enumerated) {
		    uint64_t prefill = cobj_member_elem_bits(
			  builder.object(av.outer), builder.local_index(av.outer),
			  av.member, av.elem);
		    vector<uint64_t> available;
		    for (uint64_t candidate : feasible)
			  if (!owner->randc_seen(av.member, candidate, av.elem))
				available.push_back(candidate);
		    const vector<uint64_t>&pool = available.empty()
			  ? feasible : available;
		    uint64_t chosen = pool[property_rng(av.outer).uniform_index(
			  pool.size())];
		    if (chosen != prefill)
			  owner->randc_unmark(av.member, prefill, av.elem);
		    owner->randc_mark_feasible(av.member, chosen, feasible, av.elem);
		    sampled_randc_values[av.var] = chosen;
		    Z3_ast cv = Z3_mk_unsigned_int64(ctx, chosen,
			  Z3_mk_bv_sort(ctx, av.width));
		    Z3_ast eq = Z3_mk_eq(ctx, av.var, cv);
		    Z3_optimize_assert(ctx, opt, eq);
		    Z3_solver_assert(ctx, base, eq);
		    continue;
	      }
	      uint64_t target = cobj_member_elem_bits(builder.object(av.outer),
		    builder.local_index(av.outer), av.member, av.elem);
	      Z3_ast rv = Z3_mk_unsigned_int64(ctx, target,
		    Z3_mk_bv_sort(ctx, av.width));
	      Z3_optimize_minimize(ctx, opt, Z3_mk_bvxor(ctx, av.var, rv));
	}
      };

      // IEEE 1800-2017/2023 18.4.2: randc precedes ordinary rand across
      // the complete graph, including variables in other objects' constraints.
      if (graph && !defer_ordered_joint_randc) {
            sample_scalars(true);
            sample_elements(true);
	    sample_member_elements(true);
      }
      if (joint_randc_failed) {
            if (Z3_solver_check(ctx, base) == Z3_L_FALSE) return fail_joint(nullptr);
            return fail_joint("a randc stage could not be enumerated completely");
      }
      if (exact_joint && !defer_joint) {
            vector<Z3_ast> variables;
            std::set<Z3_ast> seen;
            auto add = [&](Z3_ast var) { if (seen.insert(var).second) variables.push_back(var); };
            for (const auto&pv : builder.prop_vars)
                  if (rand_scalar_active_(builder, prop_active, pv.idx)) add(pv.var);
            for (const auto&ev : builder.elem_vars)
                  if (rand_elem_active_(builder, prop_active, ev.idx, ev.elem)) add(ev.var);
            // Canonical graph struct leaves are PropVars, not MemberVars.
	    if (!builder.member_vars.empty() || !builder.member_elem_vars.empty())
                  return fail_joint("an unpacked-struct leaf lacks canonical storage");
            // Longest distance to a sink schedules partially ordered variables
            // as late as possible, with unordered variables in the final stage
            // (IEEE 1800-2017 18.5.10; IEEE 1800-2023 18.5.9).
            map<Z3Builder::OrderRef, unsigned> remaining;
            for (const auto&pair : builder.order_pairs) {
                  remaining[pair.first];
                  remaining[pair.second];
            }
            for (size_t pass = 0; pass < remaining.size(); ++pass) {
                  bool changed = false;
                  for (const auto&pair : builder.order_pairs) {
                        unsigned want = remaining[pair.second] + 1;
                        if (remaining[pair.first] < want) {
                              remaining[pair.first] = want;
                              changed = true;
                        }
                  }
                  if (!changed) break;
                  if (pass + 1 == remaining.size())
                        return fail_joint("cyclic joint solve-before ordering");
            }
            unsigned final_stage = 0;
            for (const auto&entry : remaining)
                  final_stage = max(final_stage, entry.second);
            map<Z3_ast, unsigned> stages;
            for (const auto&pv : builder.prop_vars) {
                  Z3Builder::OrderRef ref = {
                        Z3Builder::OrderRef::PROP, pv.idx, 0
                  };
                  auto found = remaining.find(ref);
                  if (found != remaining.end())
                        stages[pv.var] = final_stage - found->second;
            }
            for (const auto&ev : builder.elem_vars) {
                  Z3Builder::OrderRef ref = {
                        Z3Builder::OrderRef::ELEM, ev.idx, ev.elem
                  };
                  auto found = remaining.find(ref);
                  if (found != remaining.end())
                        stages[ev.var] = final_stage - found->second;
            }
            vector<vector<Z3_ast> > components;
            if (!z3_joint_components_(ctx, base, variables, components))
                  return fail_joint("the joint dependency graph contains an unsupported expression");
            struct JointDistBinding {
                  const Z3Builder::DistSpec*spec;
                  size_t subject_column;
                  unsigned stage;
            };
            vector<vector<JointDistBinding> > distributions(components.size());
            for (const auto&spec : builder.dist_specs) {
                  if (dist_disabled(spec)) continue;
                  // IEEE 1800-2017 18.5.4; IEEE 1800-2023 18.5.3.
                  // A discarded soft owner, conditional activation, or active
                  // weight needs more metadata before exact marginal sampling.
                  if (spec.disableable || !spec.exact_supported || !spec.state_weights)
                        return fail_joint("joint dist requires an unconditional hard distribution with state-only weights and ground items");
                  if (!dist_active(spec)) continue;
                  bool found = false;
                  for (size_t ci = 0; ci < components.size(); ++ci) {
                        const auto&component = components[ci];
                        auto subject = find(component.begin(), component.end(), spec.subject);
                        if (subject == component.end()) continue;
                        unsigned stage = final_stage;
                        auto subject_stage = stages.find(spec.subject);
                        if (subject_stage != stages.end())
                              stage = subject_stage->second;
                        distributions[ci].push_back({
                              &spec, (size_t)(subject - component.begin()), stage
                        });
                        found = true;
                        break;
                  }
                  if (!found)
                        return fail_joint("joint dist requires a direct canonical scalar or element subject");
            }
            // Prove every complete factor before drawing. A cap/UNKNOWN after
            // choosing a weighted value could otherwise bias successful calls.
            vector<vector<vector<uint64_t> > > tables(components.size());
            for (size_t ci = 0; ci < components.size(); ++ci) {
                  bool component_has_randc = any_of(components[ci].begin(),
                        components[ci].end(), active_randc_var);
                  if (distributions[ci].size() > 1
                      && !(defer_ordered_joint_randc
                           && component_has_randc)) continue;
                  const char*reason = nullptr;
                  if (z3_enumerate_joint_(ctx, base, components[ci], ENUM_DOMAIN_CAP, tables[ci], reason) != Z3_L_TRUE)
                        return fail_joint(reason);
            }
            // IEEE 1800-2017 18.5.4 and IEEE 1800-2023 18.5.3 do
            // not define product weights (or any other combination rule) for
            // separate dist expressions in one coupled component. Resolve
            // them in stable IR order within each solve-before stage. Before
            // drawing, prove every unweighted stage projection is globally
            // bounded: any later conditional fiber is a subset of this set,
            // so a random prefix cannot decide whether the cap is exceeded.
            // The 2023 retained source-range mass policy is also a valid 2017
            // implementation choice when other constraints exclude weighted
            // choices; do not require complete ranges in this staged path.
            bool has_multiple_distributions = any_of(distributions.begin(),
                  distributions.end(), [](const vector<JointDistBinding>&v) {
                        return v.size() > 1;
                  });
            if (has_multiple_distributions) {
                  Z3_lbool feasible = Z3_solver_check(ctx, base);
                  if (feasible == Z3_L_FALSE) return fail_joint(nullptr);
                  if (feasible != Z3_L_TRUE)
                        return fail_joint("the solver returned UNKNOWN while preflighting coupled distributions");
            }
            for (size_t ci = 0; ci < components.size(); ++ci) {
                  const auto&bindings = distributions[ci];
                  if (bindings.size() <= 1) continue;
                  const auto&component = components[ci];
                  set<Z3_ast> weighted;
                  for (const auto&binding : bindings) {
                        weighted.insert(binding.spec->subject);
                        uint64_t ignored = 0;
                        if (!z3_resolve_dist_exact(ctx, base, opt,
                              *binding.spec,
                              owner_rng(binding.spec->rng_owner), ignored,
                              false, true))
                              return fail_joint("a coupled distribution cannot be sampled exactly");
                  }
                  for (unsigned stage = 0; stage <= final_stage; ++stage) {
                        vector<Z3_ast> projection;
                        for (Z3_ast var : component) {
                              unsigned due = final_stage;
                              auto found = stages.find(var);
                              if (found != stages.end()) due = found->second;
                              if (due == stage && !weighted.count(var))
                                    projection.push_back(var);
                        }
                        if (projection.empty()) continue;
                        vector<vector<uint64_t> > values;
                        const char*reason = nullptr;
                        if (z3_enumerate_joint_(ctx, base, projection,
                              ENUM_DOMAIN_CAP, values, reason) != Z3_L_TRUE)
                              return fail_joint(reason ? reason
                                    : "a coupled stage projection cannot be proved");
                  }
            }
            // Prove every ordered prefix can resolve its due distribution
            // before consuming any random draw. The common 2017/2023 subset
            // keeps the existing complete-range requirement: 2023 18.5.3
            // specifies retained source-range mass after exclusions, while
            // 2017 18.5.4 has different per-value wording. Validation moves
            // prefix-dependent exclusions, range/weight caps, and any solver
            // UNKNOWN ahead of all component/stage sampling.
            if (!builder.order_pairs.empty()) {
                  for (size_t ci = 0; ci < components.size(); ++ci) {
                        if (distributions[ci].size() != 1) continue;
                        const auto*spec = distributions[ci][0].spec;
                        const auto&component = components[ci];
                        unsigned dist_stage = final_stage;
                        auto subject_stage = stages.find(spec->subject);
                        if (subject_stage != stages.end())
                              dist_stage = subject_stage->second;
                        if (active_randc_var(spec->subject))
                              return fail_joint("a randc variable cannot be used as a distribution subject");
                        vector<size_t> prefix_columns;
                        for (size_t i = 0; i < component.size(); ++i) {
                              auto found = stages.find(component[i]);
                              if (active_randc_var(component[i])
                                  || (found != stages.end()
                                      && found->second < dist_stage))
                                    prefix_columns.push_back(i);
                        }
                        set<vector<uint64_t> > prefixes;
                        for (const auto&tuple : tables[ci]) {
                              vector<uint64_t> prefix;
                              for (size_t column : prefix_columns)
                                    prefix.push_back(tuple[column]);
                              prefixes.insert(std::move(prefix));
                        }
                        for (const auto&prefix : prefixes) {
                              Z3_solver_push(ctx, base);
                              for (size_t i = 0; i < prefix_columns.size(); ++i) {
                                    size_t column = prefix_columns[i];
                                    Z3_ast value = Z3_mk_unsigned_int64(ctx,
                                          prefix[i], Z3_get_sort(ctx, component[column]));
                                    Z3_solver_assert(ctx, base,
                                          Z3_mk_eq(ctx, component[column], value));
                              }
                              uint64_t ignored = 0;
                              bool valid = z3_resolve_dist_exact(ctx, base, opt,
                                    *spec, owner_rng(spec->rng_owner), ignored,
                                    true, true);
                              Z3_solver_pop(ctx, base, 1);
                              if (!valid)
                                    return fail_joint("an ordered distribution cannot be resolved for every proved prefix fiber");
                        }
                  }
            }
            if (defer_ordered_joint_randc) {
                  // randc has an implicit priority before every ordinary rand
                  // variable (18.4.2). Keep the established canonical
                  // per-property chooser/history transaction, but defer its
                  // draws until every exact component and ordered prefix has
                  // been proved. A cap or UNKNOWN therefore cannot make a
                  // successful call conditional on a randc draw.
                  for (size_t ci = 0; ci < components.size(); ++ci) {
                        const auto&bindings = distributions[ci];
                        if (bindings.size() <= 1) continue;
                        const auto&component = components[ci];
                        vector<size_t> randc_columns;
                        for (size_t column = 0; column < component.size(); ++column)
                              if (active_randc_var(component[column]))
                                    randc_columns.push_back(column);
                        if (randc_columns.empty()) continue;
                        for (const auto&binding : bindings)
                              if (active_randc_var(binding.spec->subject))
                                    return fail_joint("a randc variable cannot be used as a distribution subject");

                        // Traverse every possible prefix of the already-proved
                        // complete table. This is a proof only: support queries
                        // consume no RNG and install no pins. Weighted subjects
                        // use stable IR order, matching the actual sampler.
                        vector<vector<vector<uint64_t> > > fibers;
                        map<vector<uint64_t>, vector<vector<uint64_t> > > by_randc;
                        for (const auto&tuple : tables[ci]) {
                              vector<uint64_t> prefix;
                              for (size_t column : randc_columns)
                                    prefix.push_back(tuple[column]);
                              by_randc[prefix].push_back(tuple);
                        }
                        for (auto&entry : by_randc)
                              fibers.push_back(std::move(entry.second));
                        set<size_t> pinned_columns(randc_columns.begin(),
                              randc_columns.end());
                        set<Z3_ast> weighted;
                        for (const auto&binding : bindings)
                              weighted.insert(binding.spec->subject);

                        for (unsigned stage = 0; stage <= final_stage; ++stage) {
                              for (const auto&binding : bindings) {
                                    if (binding.stage != stage) continue;
                                    vector<vector<vector<uint64_t> > > next;
                                    for (const auto&fiber : fibers) {
                                          if (fiber.empty())
                                                return fail_joint("a coupled randc distribution has an empty proved prefix fiber");
                                          size_t next_before = next.size();
                                          map<uint64_t, vector<vector<uint64_t> > > candidates;
                                          for (const auto&tuple : fiber)
                                                candidates[tuple[binding.subject_column]]
                                                      .push_back(tuple);
                                          for (auto&candidate : candidates) {
                                                Z3_solver_push(ctx, base);
                                                for (size_t column : pinned_columns) {
                                                      Z3_ast value = Z3_mk_unsigned_int64(ctx,
                                                            fiber[0][column],
                                                            Z3_get_sort(ctx, component[column]));
                                                      Z3_solver_assert(ctx, base,
                                                            Z3_mk_eq(ctx, component[column], value));
                                                }
                                                // Pin the complete physical subject value
                                                // from the proved table, then ask the exact
                                                // resolver whether any positive-weight item
                                                // admits it. This reuses candidate_pin's
                                                // exact sizing/sign rules and also represents
                                                // narrow items that leave high subject bits
                                                // unconstrained.
                                                Z3_ast subject = Z3_mk_unsigned_int64(ctx,
                                                      candidate.first,
                                                      Z3_get_sort(ctx, component[
                                                            binding.subject_column]));
                                                Z3_solver_assert(ctx, base,
                                                      Z3_mk_eq(ctx, component[
                                                            binding.subject_column], subject));
                                                uint64_t ignored = 0;
                                                bool indeterminate = false;
                                                bool valid = z3_resolve_dist_exact(ctx,
                                                      base, opt, *binding.spec,
                                                      owner_rng(binding.spec->rng_owner),
                                                      ignored, false, true,
                                                      &indeterminate);
                                                Z3_solver_pop(ctx, base, 1);
                                                if (indeterminate)
                                                      return fail_joint("a coupled randc distribution prefix could not be proved exactly");
                                                if (valid)
                                                      next.push_back(std::move(candidate.second));
                                          }
                                          if (next.size() == next_before)
                                                return fail_joint("a coupled randc distribution cannot be resolved for every proved prefix fiber");
                                    }
                                    fibers.swap(next);
                                    pinned_columns.insert(binding.subject_column);
                              }

                              vector<size_t> columns;
                              for (size_t column = 0; column < component.size(); ++column) {
                                    unsigned due = final_stage;
                                    auto found = stages.find(component[column]);
                                    if (found != stages.end()) due = found->second;
                                    if (due == stage
                                        && !weighted.count(component[column])
                                        && !pinned_columns.count(column))
                                          columns.push_back(column);
                              }
                              if (columns.empty()) continue;
                              vector<vector<vector<uint64_t> > > next;
                              for (const auto&fiber : fibers) {
                                    map<vector<uint64_t>, vector<vector<uint64_t> > > split;
                                    for (const auto&tuple : fiber) {
                                          vector<uint64_t> projection;
                                          for (size_t column : columns)
                                                projection.push_back(tuple[column]);
                                          split[projection].push_back(tuple);
                                    }
                                    for (auto&entry : split)
                                          next.push_back(std::move(entry.second));
                              }
                              fibers.swap(next);
                              pinned_columns.insert(columns.begin(), columns.end());
                        }
                  }
                  sample_scalars(true);
                  sample_elements(true);
                  if (joint_randc_failed) {
                        if (Z3_solver_check(ctx, base) == Z3_L_FALSE)
                              return fail_joint(nullptr);
                        return fail_joint("a randc stage could not be enumerated completely");
                  }
                  // The tables were proved before the draw. Restrict each to
                  // the randc prefix now pinned in base; every selected randc
                  // value came from a feasible domain, so its component keeps
                  // at least one complete tuple.
                  for (size_t ci = 0; ci < components.size(); ++ci) {
                        auto&tuples = tables[ci];
                        const auto&component = components[ci];
                        for (size_t column = 0; column < component.size(); ++column) {
                              Z3_ast var = component[column];
                              if (!active_randc_var(var)) continue;
                              auto sampled = sampled_randc_values.find(var);
                              if (sampled == sampled_randc_values.end())
                                    return fail_joint("an active randc variable was not sampled");
                              uint64_t bits = sampled->second;
                              unsigned width = bv_width(ctx, var);
                              if (width < 64)
                                    bits &= (uint64_t(1) << width) - 1;
                              tuples.erase(remove_if(tuples.begin(), tuples.end(),
                                    [&](const vector<uint64_t>&tuple) {
                                          return tuple[column] != bits;
                                    }), tuples.end());
                              if (tuples.empty())
                                    return fail_joint("a sampled randc value has no proved joint tuple");
                        }
                  }
            }
            for (size_t ci = 0; ci < components.size(); ++ci) {
                  const auto&component = components[ci];
                  auto&tuples = tables[ci];
                  const auto&bindings = distributions[ci];
                  const auto*spec = bindings.size() == 1
                        ? bindings[0].spec : nullptr;
                  size_t subject_column = spec
                        ? bindings[0].subject_column : 0;
                  unsigned dist_stage = final_stage;
                  if (spec) {
                        dist_stage = bindings[0].stage;
                  }
                  auto pin_column = [&](size_t column, uint64_t bits) {
                        Z3_ast value = Z3_mk_unsigned_int64(ctx, bits,
                              Z3_get_sort(ctx, component[column]));
                        Z3_ast pin = Z3_mk_eq(ctx, component[column], value);
                        Z3_solver_assert(ctx, base, pin);
                        Z3_optimize_assert(ctx, opt, pin);
                  };
                  if (bindings.size() > 1) {
                        set<Z3_ast> weighted;
                        for (const auto&binding : bindings)
                              weighted.insert(binding.spec->subject);
                        for (unsigned stage = 0; stage <= final_stage; ++stage) {
                              // Weighted subjects are resolved before ordinary
                              // peers at the same stage. Otherwise a uniform
                              // projection could erase an ordered dist marginal.
                              for (const auto&binding : bindings) {
                                    if (binding.stage != stage) continue;
                                    uint64_t subject = 0;
                                    if (!z3_resolve_dist_exact(ctx, base, opt,
                                          *binding.spec,
                                          owner_rng(binding.spec->rng_owner),
                                          subject, false))
                                          return fail_joint("a coupled distribution could not be sampled exactly in its staged fiber");
                              }
                              vector<size_t> columns;
                              vector<Z3_ast> projection;
                              for (size_t i = 0; i < component.size(); ++i) {
                                    unsigned due = final_stage;
                                    auto found = stages.find(component[i]);
                                    if (found != stages.end())
                                          due = found->second;
                                    if (due == stage
                                        && !weighted.count(component[i])) {
                                          columns.push_back(i);
                                          projection.push_back(component[i]);
                                    }
                              }
                              if (projection.empty()) continue;
                              vector<vector<uint64_t> > values;
                              const char*reason = nullptr;
                              if (z3_enumerate_joint_(ctx, base, projection,
                                    ENUM_DOMAIN_CAP, values, reason) != Z3_L_TRUE)
                                    return fail_joint(reason ? reason
                                          : "a coupled stage projection could not be sampled");
                              const auto&chosen = values[values.size() == 1
                                    ? 0 : root_rng.uniform_index(values.size())];
                              for (size_t i = 0; i < columns.size(); ++i)
                                    pin_column(columns[i], chosen[i]);
                        }
                        continue;
                  }
                  // Resolve stages in order. Prefix pins are installed in the
                  // hard solver immediately, so a distribution on a later
                  // subject is sampled from its actual conditional fiber.
                  for (unsigned stage = 0; stage <= final_stage; ++stage) {
                        if (spec && stage == dist_stage) {
                              uint64_t subject = 0;
                              if (!z3_resolve_dist_exact(ctx, base, opt, *spec,
                                    owner_rng(spec->rng_owner), subject,
                                    true))
                                    return fail_joint("a joint distribution has an excluded range member or could not be sampled exactly");
                              unsigned width = bv_width(ctx, spec->subject);
                              if (width < 64) subject &= (uint64_t(1) << width) - 1;
                              tuples.erase(remove_if(tuples.begin(), tuples.end(),
                                    [&](const vector<uint64_t>&tuple) {
                                          return tuple[subject_column] != subject;
                                    }), tuples.end());
                              if (tuples.empty())
                                    return fail_joint("the sampled distribution value has no proved joint tuple");
                              pin_column(subject_column, subject);
                        }
                        if (stage == final_stage) break;
                        vector<size_t> columns;
                        for (size_t i = 0; i < component.size(); ++i) {
                              auto found = stages.find(component[i]);
                              if (found != stages.end() && found->second == stage)
                                    columns.push_back(i);
                        }
                        if (columns.empty()) continue;
                        // Count distinct stage assignments, not their number
                        // of later completions. Every projection has a proved
                        // nonempty fiber in the complete component table.
                        set<vector<uint64_t> > projections;
                        for (const auto&tuple : tuples) {
                              vector<uint64_t> projection;
                              for (size_t column : columns) projection.push_back(tuple[column]);
                              projections.insert(std::move(projection));
                        }
                        auto selected = projections.begin();
                        if (projections.size() > 1)
                              advance(selected, root_rng.uniform_index(projections.size()));
                        tuples.erase(remove_if(tuples.begin(), tuples.end(),
                              [&](const vector<uint64_t>&tuple) {
                                    for (size_t i = 0; i < columns.size(); ++i)
                                          if (tuple[columns[i]] != (*selected)[i]) return true;
                                    return false;
                              }), tuples.end());
                        for (size_t i = 0; i < columns.size(); ++i)
                              pin_column(columns[i], (*selected)[i]);
                  }
                  // A distribution/stage sets its marginal; the remaining
                  // complete fiber is uniform. Independent factors multiply.
                  const auto&chosen = tuples[tuples.size() == 1 ? 0 : root_rng.uniform_index(tuples.size())];
                  for (size_t i = 0; i < component.size(); ++i) {
                        Z3_ast value = Z3_mk_unsigned_int64(ctx, chosen[i], Z3_get_sort(ctx, component[i]));
                        Z3_ast pin = Z3_mk_eq(ctx, component[i], value);
                        Z3_solver_assert(ctx, base, pin);
                        Z3_optimize_assert(ctx, opt, pin);
                  }
            }
      }

	// A stage optimizer must start from the current hard base rather than
	// from the global optimizer: the latter may contain objectives belonging
	// to later ranks. Copying the base assertions retains exact/soft pins and
	// adds only fallback groups that have already become due.
      auto make_stage_optimize = [&]() -> Z3_optimize {
	    Z3_optimize stage = Z3_mk_optimize(ctx);
	    Z3_optimize_inc_ref(ctx, stage);
	    Z3_ast_vector assertions = Z3_solver_get_assertions(ctx, base);
	    Z3_ast_vector_inc_ref(ctx, assertions);
	    unsigned count = Z3_ast_vector_size(ctx, assertions);
	    for (unsigned i = 0 ; i < count ; i += 1)
		  Z3_optimize_assert(ctx, stage,
			Z3_ast_vector_get(ctx, assertions, i));
	    Z3_ast_vector_dec_ref(ctx, assertions);
	    for (size_t spec_index : dist_fallback_active)
		  install_dist_fallback(stage, spec_index);
	    return stage;
      };

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
	    uint64_t target = (uint64_t)(property_rng(idx).next() & 0xF);
	    size_random_targets[idx] = target;
	    return target;
      };
      if (!exact_joint && !builder.order_pairs.empty()) {
	    std::map<Z3Builder::OrderRef,unsigned> rank;
	    auto order_ref_active = [&](const Z3Builder::OrderRef&ref) -> bool {
		  if (ref.kind == Z3Builder::OrderRef::MEMBER_ELEM)
			return rand_member_elem_active_(builder, prop_active,
			      ref.idx, ref.elem, ref.subelem);
		  if (ref.kind == Z3Builder::OrderRef::ELEM)
			return rand_elem_active_(builder, prop_active,
					 ref.idx, ref.elem);
		  if (ref.kind == Z3Builder::OrderRef::MEMBER)
			return rand_member_active_(builder, prop_active,
					   ref.idx, ref.elem);
		  return ref.kind == Z3Builder::OrderRef::SIZE
			? rand_size_active_(builder, prop_active, ref.idx)
			: rand_active_(builder, prop_active, ref.idx);
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
		  auto dist_effective_rank = [&](const Z3Builder::DistSpec&spec)
			-> unsigned {
			unsigned effective = 0;
			bool saw_active = false;
			for (const auto&ref : spec.refs) {
			      if (!var_ref_active(ref)) continue;
			      saw_active = true;
			      Z3Builder::OrderRef ordered;
			      ordered.idx = ref.idx;
			      ordered.elem = ref.leaf;
			      ordered.subelem = ref.subleaf;
			      if (ref.kind == Z3Builder::VarRef::ELEM)
				    ordered.kind = Z3Builder::OrderRef::ELEM;
			      else if (ref.kind == Z3Builder::VarRef::MEMBER_ELEM)
				    ordered.kind = Z3Builder::OrderRef::MEMBER_ELEM;
			      else if (ref.kind == Z3Builder::VarRef::MEMBER)
				    ordered.kind = Z3Builder::OrderRef::MEMBER;
			      else if (ref.kind == Z3Builder::VarRef::SIZE)
				    ordered.kind = Z3Builder::OrderRef::SIZE;
			      else
				    ordered.kind = Z3Builder::OrderRef::PROP;
			      auto found = rank.find(ordered);
			      if (found == rank.end()) return max_rank;
			      if (found->second > effective)
				    effective = found->second;
			}
			return saw_active ? effective : max_rank;
		  };
		  for (unsigned r = 0 ; r < max_rank ; r += 1) {
			for (size_t spec_index = 0;
			     spec_index < builder.dist_specs.size(); ++spec_index)
			      if (dist_effective_rank(
				    builder.dist_specs[spec_index]) == r)
				    if (!resolve_dist(spec_index))
					  return fail_joint(nullptr);
			Z3_optimize stage_opt = make_stage_optimize();
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
				    rand_bits = cobj_elem_bits(builder.object(ref.idx), builder.local_index(ref.idx),
						     ref.elem);
			      } else if (ref.kind == Z3Builder::OrderRef::MEMBER_ELEM) {
				    for (auto&av : builder.member_elem_vars)
					  if (av.outer == ref.idx && av.member == ref.elem
					      && av.elem == ref.subelem) {
						var = av.var;
						width = av.width;
						break;
					  }
				    rand_bits = cobj_member_elem_bits(builder.object(ref.idx),
					  builder.local_index(ref.idx), ref.elem,
					  ref.subelem);
			      } else if (ref.kind == Z3Builder::OrderRef::MEMBER) {
				    for (auto&mv : builder.member_vars)
					  if (mv.outer == ref.idx
					      && mv.member == ref.elem) {
						var = mv.var;
						width = mv.width;
						break;
					  }
				    rand_bits = cobj_member_bits(builder.object(ref.idx), builder.local_index(ref.idx),
							       ref.elem);
			      } else if (ref.kind == Z3Builder::OrderRef::PROP) {
				    for (auto&pv : builder.prop_vars)
					  if (pv.idx == ref.idx) {
						var = pv.var;
						width = pv.width;
						break;
					  }
				    rand_bits = cobj_prop_bits(builder.object(ref.idx), builder.local_index(ref.idx));
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
			      Z3_optimize_minimize(ctx, stage_opt,
				    Z3_mk_bvxor(ctx, var, rv));
			}
			Z3_lbool st = Z3_optimize_check(ctx, stage_opt, 0, nullptr);
			if (st != Z3_L_TRUE) {
			      Z3_optimize_dec_ref(ctx, stage_opt);
			      break;
			}
			Z3_model stage_model = Z3_optimize_get_model(ctx, stage_opt);
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
			      } else if (ref.kind == Z3Builder::OrderRef::MEMBER_ELEM) {
				    for (auto&av : builder.member_elem_vars)
					  if (av.outer == ref.idx && av.member == ref.elem
					      && av.elem == ref.subelem) {
						var = av.var;
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
			Z3_optimize_dec_ref(ctx, stage_opt);
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

      // Resolve the final solve...before bucket (the highest listed rank
      // plus every unlisted subject), or every dist when no ordering
      // directive exists. Earlier buckets were resolved immediately before
      // their stage above, so neither their exact choice nor their fallback
      // could be biased by a future-ranked objective.
      for (size_t spec_index = 0;
	   spec_index < builder.dist_specs.size(); ++spec_index)
	    if (!resolve_dist(spec_index))
		  return fail_joint(nullptr);

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
      sample_scalars(false);
      for (auto& mv : builder.member_vars) {
	    if (!rand_member_active_(builder, prop_active,
				     mv.outer, mv.member))
		  continue;
	    if (dist_resolved_vars.count(mv.var)) continue;
	    bool fallback_managed = dist_fallback_vars.count(mv.var)
		  || fallback_ref(Z3Builder::VarRef::MEMBER, mv.outer,
				  mv.member);
	    vvp_cobject*owner = cobj_struct_prop(builder.object(mv.outer), builder.local_index(mv.outer));
	    const class_type*member_defn = owner ? owner->get_defn() : nullptr;
	    if (!owner || !member_defn) continue;

	    vector<uint64_t> feasible;
	    bool enumerated = false;
	    if (!fallback_managed && single_var_fast_ok)
		  enumerated = z3_enumerate_domain_single_var_fast_(
			ctx, base, mv.var, mv.width, feasible);
	    if (!fallback_managed && !enumerated)
		  enumerated = z3_enumerate_domain(ctx, base, mv.var,
					   mv.width, feasible);
	    if (!fallback_managed && !enumerated)
		  enumerated = z3_enumerate_sparse_wide_domain_(
			ctx, base, mv.var, mv.width, feasible);
	    if (enumerated) {
		  uint64_t chosen;
		  if (member_defn->property_is_randc(mv.member)) {
			uint64_t prefill = cobj_member_bits(builder.object(mv.outer), builder.local_index(mv.outer),
						      mv.member);
			vector<uint64_t> available;
			for (uint64_t cand : feasible)
			      if (!owner->randc_seen(mv.member, cand))
				    available.push_back(cand);
			const vector<uint64_t>&pool = available.empty()
			      ? feasible : available;
			chosen = pool[property_rng(mv.outer).uniform_index(pool.size())];
			if (chosen != prefill)
			      owner->randc_unmark(mv.member, prefill);
			owner->randc_mark_feasible(mv.member, chosen, feasible);
		  } else {
			chosen = feasible[property_rng(mv.outer).uniform_index(feasible.size())];
		  }
		  Z3_sort sort = Z3_mk_bv_sort(ctx, mv.width);
		  Z3_ast cv = Z3_mk_unsigned_int64(ctx, chosen, sort);
		  Z3_ast eq = Z3_mk_eq(ctx, mv.var, cv);
		  Z3_optimize_assert(ctx, opt, eq);
		  Z3_solver_assert(ctx, base, eq);
		  continue;
	    }

	    if (!fallback_managed && member_defn->property_is_randc(mv.member)
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
	    uint64_t rand_bits = cobj_member_bits(builder.object(mv.outer), builder.local_index(mv.outer), mv.member);
	    Z3_sort sort = Z3_mk_bv_sort(ctx, mv.width);
	    Z3_ast rv = Z3_mk_unsigned_int64(ctx, rand_bits, sort);
	    Z3_optimize_minimize(ctx, opt, Z3_mk_bvxor(ctx, mv.var, rv));
      }
      sample_member_elements(false);
      for (auto& sv : builder.size_vars) {
	    if (!rand_size_active_(builder, prop_active, sv.idx)) continue;
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

      sample_elements(false);

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
	    if (result == Z3_L_FALSE && state_check_scope) {
		  Z3_solver_pop(ctx, base, 1);
		  Z3_solver_assert(ctx, base, any_state_error);
		  if (Z3_solver_check(ctx, base) == Z3_L_TRUE) {
			Z3_model error_model = Z3_solver_get_model(ctx, base);
			Z3_model_inc_ref(ctx, error_model);
			for (const auto&check : builder.state_checks) {
			      Z3_ast value = nullptr;
			      if (!Z3_model_eval(ctx, error_model, check.error, 1,
			                         &value) || !value
			          || Z3_get_bool_value(ctx, Z3_simplify(ctx, value))
			                         != Z3_L_TRUE) continue;
			      fprintf(stderr, "ERROR: constraint state read: %s.\n",
			              check.message.c_str());
			      break;
			}
			Z3_model_dec_ref(ctx, error_model);
		  }
	    }
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

      for (const auto&check : builder.state_checks) {
            Z3_ast value = nullptr;
            Z3_lbool failed = Z3_L_UNDEF;
            if (Z3_model_eval(ctx, model, check.error, 1, &value) && value)
                  failed = Z3_get_bool_value(ctx, Z3_simplify(ctx, value));
            if (failed == Z3_L_FALSE) continue;
            fprintf(stderr, "ERROR: constraint state read: %s.\n",
                    failed == Z3_L_TRUE ? check.message.c_str()
                                        : "could not evaluate guarded state read");
            Z3_model_dec_ref(ctx, model);
            Z3_solver_dec_ref(ctx, base);
            Z3_optimize_dec_ref(ctx, opt);
            Z3_del_context(ctx);
            return Z3PASS_FAILED;
      }

      // Keep selected class handles and their retained callbacks intact.
      // IEEE 1800-2017 18.5.8.1/18.5.9 / 1800-2023 18.5.7.1/18.5.8:
      // handle-array resizing requires typed allocation and a defined graph
      // selection barrier; the integral allocator below cannot implement it.
      if (graph)
            for (const auto&sv : builder.size_vars) {
                  const string&type = builder.type(sv.idx)->property_base_type(builder.local_index(sv.idx));
                  if ((type != "Do" && type != "Qo")
                      || !rand_size_active_(builder, prop_active, sv.idx)) continue;
                  uint64_t count = 0;
                  if (!z3_eval_uint64(ctx, model, sv.var, count)
                      || count != cobj_darray_size(builder.object(sv.idx), builder.local_index(sv.idx))) {
                        fprintf(stderr, "ERROR: resizing a random class-handle collection during a global solve is not yet supported.\n");
                        Z3_model_dec_ref(ctx, model);
                        Z3_solver_dec_ref(ctx, base);
                        Z3_optimize_dec_ref(ctx, opt);
                        Z3_del_context(ctx);
                        return Z3PASS_FAILED;
                  }
            }

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
            if (defer_joint) continue;
	    if (!rand_member_active_(builder, prop_active,
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
      struct member_elem_write_t {
	    unsigned outer, member, elem, width;
	    uint64_t bits;
      };
      vector<member_elem_write_t> member_elem_writes;
      for (auto&av : builder.member_elem_vars) {
	    if (defer_joint || !rand_member_elem_active_(builder, prop_active,
						  av.outer, av.member, av.elem))
		  continue;
	    uint64_t bits = 0;
	    if (!z3_eval_uint64(ctx, model, av.var, bits)) {
		  Z3_model_dec_ref(ctx, model);
		  Z3_solver_dec_ref(ctx, base);
		  Z3_optimize_dec_ref(ctx, opt);
		  Z3_del_context(ctx);
		  return Z3PASS_FAILED;
	    }
	    member_elem_writes.push_back(
		  {av.outer, av.member, av.elem, av.width, bits});
      }

      for (auto& pv : builder.prop_vars) {
            if (defer_joint) continue;
	    if (!rand_scalar_active_(builder, prop_active, pv.idx)) continue;
	    vvp_vector4_t value;
	    if (!z3_eval_vec4_(ctx, model, pv.var, value)) {
		  Z3_model_dec_ref(ctx, model);
		  Z3_solver_dec_ref(ctx, base);
		  Z3_optimize_dec_ref(ctx, opt);
		  Z3_del_context(ctx);
		  return Z3PASS_FAILED;
	    }
	    if (!cobj_set_prop_vec4_(builder.object(pv.idx),
	                             builder.local_index(pv.idx), value)) {
		  fprintf(stderr, "ERROR: constraint model width %u does not match "
			  "property width.\n", value.size());
		  Z3_model_dec_ref(ctx, model);
		  Z3_solver_dec_ref(ctx, base);
		  Z3_optimize_dec_ref(ctx, opt);
		  Z3_del_context(ctx);
		  return Z3PASS_FAILED;
	    }
	    if (z3_dyndbg())
		  fprintf(stderr, "[z3dyn] prop  prop=%u width=%u\n",
			  pv.idx, pv.width);
      }
      for (const member_write_t&write : member_writes) {
	    cobj_set_member_bits(builder.object(write.outer), builder.local_index(write.outer), write.member, write.bits);
	    if (z3_dyndbg())
		  fprintf(stderr, "[z3dyn] member outer=%u member=%u "
			  "width=%u bits=%llu\n", write.outer,
			  write.member, write.width,
			  (unsigned long long)write.bits);
      }
      for (const member_elem_write_t&write : member_elem_writes) {
	    cobj_set_member_elem_bits(builder.object(write.outer),
		  builder.local_index(write.outer), write.member, write.elem,
		  write.width, write.bits);
	    if (z3_dyndbg())
		  fprintf(stderr, "[z3dyn] member-element outer=%u member=%u "
			  "elem=%u width=%u bits=%llu\n", write.outer,
			  write.member, write.elem, write.width,
			  (unsigned long long)write.bits);
      }

	// Apply solved dynamic-array/queue sizes: create (or replace) the
	// property's correctly typed container with the solved element count
	// and fill integral elements with random bits. Element constraints,
	// when present, overwrite specific entries below.
      auto choose_container_randc = [](z3_rng_stream_t&rng, const std::vector<bool>*history,
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
	    if (!rand_size_active_(builder, prop_active, sv.idx)) continue;
	    uint64_t new_size = 0;
            if (graph) {
                  const string&type = builder.type(sv.idx)->property_base_type(builder.local_index(sv.idx));
                  if (type == "Do" || type == "Qo") continue;
            }
	    if (!z3_eval_uint64(ctx, model, sv.var, new_size))
		  continue;
	    uint64_t cap = random_container_size_cap_(sv.container_type);
	    if (new_size > cap) new_size = cap;

	    random_container_desc_t desc =
		  random_container_desc_(sv.container_type);
	    vvp_object_t old_obj;
	    builder.object(sv.idx)->get_object(builder.local_index(sv.idx), old_obj, 0);
	    vvp_darray*old_array = old_obj.peek<vvp_darray>();
	    vvp_darray*da = make_random_container_(desc, (size_t)new_size);
	    bool is_randc = builder.type(sv.idx)->property_is_randc(builder.local_index(sv.idx));
	    if (desc.is_queue) {
		  vvp_queue*queue = dynamic_cast<vvp_queue*>(da);
		  const uint64_t queue_max = desc.max_size;
		  for (uint64_t adr = 0 ; queue && adr < new_size ; adr += 1) {
			vvp_vector4_t nv(desc.elem_width, BIT4_0);
			bool active = rand_elem_active_(builder, prop_active,
						 sv.idx, (unsigned)adr);
			if (old_array && adr < old_array->get_size() && !active)
			      old_array->get_word((unsigned)adr, nv);
			else if (is_randc && desc.elem_width > 0
				 && desc.elem_width <= 20) {
			      const std::vector<bool>*history = old_array
				    && adr < old_array->get_size()
				    ? static_cast<const vvp_darray*>(old_array)
					  ->randc_history((size_t)adr) : 0;
			      uint64_t bits = choose_container_randc(property_rng(sv.idx), history,
							       desc.elem_width);
			      for (unsigned b = 0 ; b < desc.elem_width ; b += 1)
				    nv.set_bit(b, (bits >> b) & 1
						   ? BIT4_1 : BIT4_0);
			} else
			      for (unsigned b = 0 ; b < desc.elem_width ; b += 1)
				    nv.set_bit(b, (property_rng(sv.idx).next() & 1)
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
			bool active = rand_elem_active_(builder, prop_active,
						 sv.idx, (unsigned)adr);
			if (old_array && adr < old_array->get_size() && !active)
			      old_array->get_word((unsigned)adr, nv);
			else if (is_randc && wid <= 20) {
			      const std::vector<bool>*history = old_array
				    && adr < old_array->get_size()
				    ? static_cast<const vvp_darray*>(old_array)
					  ->randc_history((size_t)adr) : 0;
			      uint64_t bits = choose_container_randc(property_rng(sv.idx), history, wid);
			      for (unsigned b = 0 ; b < wid ; b += 1)
				    nv.set_bit(b, (bits >> b) & 1
						   ? BIT4_1 : BIT4_0);
			} else
			      for (unsigned b = 0 ; b < wid ; b += 1)
				    nv.set_bit(b, (property_rng(sv.idx).next() & 1)
						  ? BIT4_1 : BIT4_0);
			da->set_word((unsigned)adr, nv);
		  }
	    }
	    vvp_object_t obj(da);
	    if (old_array) da->inherit_randc_histories(*old_array);
	    builder.object(sv.idx)->set_object(builder.local_index(sv.idx), obj, 0);
	    if (old_array) {
		  vvp_object_t stored;
		  builder.object(sv.idx)->get_object(builder.local_index(sv.idx), stored, 0);
		  if (vvp_darray*stored_array = stored.peek<vvp_darray>())
			{
			      stored_array->inherit_rand_modes(*old_array);
			      stored_array->inherit_randc_histories(*old_array);
			}
	    }
	    if (is_randc) {
		  vvp_object_t stored;
		  builder.object(sv.idx)->get_object(builder.local_index(sv.idx), stored, 0);
		  if (vvp_darray*stored_array = stored.peek<vvp_darray>())
			for (size_t adr = 0 ; adr < stored_array->get_size();
			     adr += 1) {
		      if (!rand_elem_active_(builder, prop_active,
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
			      builder.object(sv.idx)->randc_container_mark(builder.local_index(sv.idx), adr, bits);
			}
	    }
      }

      // Apply solved array-element values.
      for (auto& ev : builder.elem_vars) {
            if (defer_joint) continue;
	    if (!rand_elem_active_(builder, prop_active, ev.idx, ev.elem))
		  continue;
	    uint64_t count = cobj_darray_size(builder.object(ev.idx),
	                                      builder.local_index(ev.idx));
	    const string&type_text = builder.type(ev.idx)->property_base_type(
	          builder.local_index(ev.idx));
	    if (!type_text.empty()
	        && (type_text[0] == 'D' || type_text[0] == 'Q')
	        && ev.elem >= count) {
		  fprintf(stderr, "ERROR: constraint element %u remains outside "
		          "the solved dynamic-container size %llu.\n", ev.elem,
		          (unsigned long long)count);
		  Z3_model_dec_ref(ctx, model);
		  Z3_solver_dec_ref(ctx, base);
		  Z3_optimize_dec_ref(ctx, opt);
		  Z3_del_context(ctx);
		  return Z3PASS_FAILED;
	    }
	    uint64_t bits = 0;
	    bool ev_ok = z3_eval_uint64(ctx, model, ev.var, bits);
	    if (ev_ok)
		  cobj_set_elem_bits(builder.object(ev.idx), builder.local_index(ev.idx), ev.elem, ev.width, bits);
	    if (z3_dyndbg())
		  fprintf(stderr, "[z3dyn] writeback prop=%u elem=%u width=%u "
			  "eval_ok=%d bits=%llu (post-write da_size=%llu)\n",
			  ev.idx, ev.elem, ev.width, ev_ok ? 1 : 0,
			  (unsigned long long)bits,
			  (unsigned long long)cobj_darray_size(builder.object(ev.idx), builder.local_index(ev.idx)));
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
                      bool include_class_constraints,
                      const vector<vvp_object_t>*object_vals,
                      const vector<vvp_vector4_t>*class_slot_vals)
{
      if ((!include_class_constraints || defn->constraint_count() == 0)
	  && extra_ir.empty()) return true;

      z3_rng_stream_t rng(cobj);

	// Size pass: dynamic-foreach bodies deferred; sizes solved and
	// written back.
      std::vector<Z3Builder::DynForeach> dyn;
      static const vector<vvp_vector4_t> no_class_slots;
      const vector<vvp_vector4_t>&class_slots = class_slot_vals
	    ? *class_slot_vals : no_class_slots;
      int r1 = z3_solve_pass_(defn, cobj, rng, extra_ir, slot_vals, class_slots,
			      nullptr, &dyn, prop_active,
			      include_class_constraints, nullptr, nullptr, object_vals);
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
      int r2 = z3_solve_pass_(defn, cobj, rng, extra_ir, slot_vals, class_slots,
			      &sizes, nullptr, prop_active,
			      include_class_constraints, nullptr, nullptr, object_vals);
      return r2 != Z3PASS_FAILED;
}

/* Validate the selected graph before scalar/container prefills can reach
 * a legacy fallback. Actual solving still owns prospective sized elements. */
bool vvp_z3_graph_history_supported(const vector<vvp_z3_object_s>&objects)
{
      if (objects.empty()) return true;
      unsigned class_owners = 0;
      for (const auto&owner : objects)
            if (!owner.object->get_defn()->is_struct_type()) ++class_owners;
      if (class_owners > 1) {
            // IEEE 1800-2017/2023 18.4.2: a small feasible set does not
            // make the runtime's >20-bit history representation sufficient.
            // Include unmodeled leaves and containers before the no-IR exit.
            for (const auto&owner : objects) {
                  const class_type*type = owner.object->get_defn();
                  for (size_t pid = 0; pid < type->property_count(); ++pid) {
                        if (!type->property_is_randc(pid)
                            || !rand_active_(type, owner.object, owner.selection(), pid)) continue;
                        const string&base_type = type->property_base_type(pid);
                        unsigned width = type->property_vec4_width(pid);
                        if (base_type == "Qv") {
                              // Legacy queue property metadata has no width.
                              // Read only actual active words; prospective words
                              // are checked from typed size IR before allocation.
                              if (type->property_array_size(pid) > 1) {
                                    fprintf(stderr, "ERROR: global constraint sampling failed: randc fixed arrays of queues are not yet supported.\n");
                                    return false;
                              }
                              vvp_object_t value;
                              owner.object->get_object(pid, value, 0);
                              vvp_queue_vec4*queue = value.peek<vvp_queue_vec4>();
                              for (size_t i = 0; queue && i < queue->get_size(); ++i) {
                                    if (!rand_elem_active_(type, owner.object, owner.selection(), pid, (unsigned)i)) continue;
                                    vvp_vector4_t word;
                                    queue->get_word((unsigned)i, word);
                                    if (word.size() == 0 || word.size() > 20) {
                                          fprintf(stderr, "ERROR: global constraint sampling failed: a randc leaf exceeds the supported history representation.\n");
                                          return false;
                                    }
                              }
                              continue;
                        }
                        if (!base_type.empty() && (base_type[0] == 'D' || base_type[0] == 'M'))
                              width = random_container_desc_(base_type.substr(1)).elem_width;
                        if (width == 0 || width > 20) {
                              fprintf(stderr, "ERROR: global constraint sampling failed: a randc leaf exceeds the supported history representation.\n");
                              return false;
                        }
                  }
            }
      }
      return true;
}

namespace {
struct function_plan_item_t {
      vvp_z3_plan_item_s item;
      set<Z3Builder::VarRef> refs;
      vector<size_t> calls;
      unsigned stage = 0;
      unsigned minimum_stage = 0;
};

static bool take_top_ir_(const char*&p, string&out)
{
      while (*p && isspace((unsigned char)*p)) ++p;
      if (!*p) return false;
      const char*begin = p;
      if (*p != '(') {
            while (*p && !isspace((unsigned char)*p)) ++p;
            out.assign(begin, p - begin);
            return true;
      }
      unsigned depth = 0;
      do {
            if (*p == '(') ++depth;
            else if (*p == ')') --depth;
            ++p;
      } while (*p && depth);
      if (depth) return false;
      out.assign(begin, p - begin);
      return true;
}

static bool split_constraint_items_(const string&ir, vector<string>&items)
{
      const char*p = ir.c_str();
      for (;;) {
            while (*p && isspace((unsigned char)*p)) ++p;
            if (!*p) break;
            string form;
            if (!take_top_ir_(p, form)) return false;
            IRParser parser(form);
            if (parser.peek() == '(') {
                  parser.consume();
                  if (parser.read_token() == "and") {
                        string body = capture_balanced_form(parser);
                        if (!split_constraint_items_(body, items)) return false;
                        continue;
                  }
            }
            items.push_back(form);
      }
      return true;
}

static vector<size_t> capture_slots_(const string&ir)
{
      set<size_t> slots;
      const char*begin = ir.c_str();
      for (const char*p = begin; *p; ++p) {
            bool boundary = p == begin
                  || !(isalnum((unsigned char)p[-1]) || p[-1] == '_');
            if (!boundary || p[0] != 'v' || p[1] != ':') continue;
            char*end = nullptr;
            unsigned long slot = strtoul(p + 2, &end, 10);
            if (end != p + 2 && *end == ':') slots.insert((size_t)slot);
      }
      return vector<size_t>(slots.begin(), slots.end());
}

static bool top_dynamic_foreach_(const string&ir)
{
      IRParser parser(ir);
      if (parser.peek() != '(') return false;
      parser.consume();
      return parser.read_token() == "dynforeach";
}

}

bool vvp_z3_plan_function_stages(const vector<vvp_z3_object_s>&objects,
                                 vvp_z3_function_plan_s&plan)
{
      plan.stages.clear();
      plan.deferred_elements.clear();
      plan.error.clear();
      if (objects.empty()) return true;
      z3_object_graph_t graph(objects);
      graph.select_storage_owners();
      if (!graph.valid) {
            plan.error = "invalid object storage in constraint function plan";
            return false;
      }
      Z3_config cfg = Z3_mk_config();
      Z3_context ctx = Z3_mk_context(cfg);
      Z3_del_config(cfg);
      vector<function_plan_item_t> work;
      map<unsigned, Z3Builder::VarRef> member_aliases;
      for (unsigned outer = 0; outer < graph.properties.size(); ++outer) {
            const auto&property = graph.properties[outer];
            const string&base = property.object->get_defn()->property_base_type(
                  property.pid);
            if (base.compare(0, 3, "oc:") != 0) continue;
            vvp_cobject*record = cobj_struct_prop(property.object, property.pid);
            if (!record) continue;
            for (unsigned member = 0;
                 member < record->get_defn()->property_count(); ++member) {
                  unsigned child = graph.intern(record, member);
                  member_aliases[child] = {
                        Z3Builder::VarRef::MEMBER, outer, member};
            }
      }
      auto add_ir = [&](size_t object, const string&ir, bool class_ir,
                        unsigned constraint) -> bool {
            vector<string> split;
            if (!split_constraint_items_(ir, split)) {
                  plan.error = "malformed top-level constraint expression";
                  return false;
            }
            const class_type*type = objects[object].object->get_defn();
            for (const string&item_ir : split) {
                  function_plan_item_t entry;
                  entry.item = {object, class_ir, item_ir,
                                class_ir ? capture_slots_(item_ir)
                                         : vector<size_t>()};
                  Z3Builder builder(ctx, type, objects[object].object, &graph);
                  set<Z3Builder::VarRef> refs;
                  builder.collect_refs = &refs;
                  builder.collect_refs_only = true;
                  builder.allow_planner_value_slots = true;
                  parse_constraint_ir(item_ir, builder);
                  if (!builder.state_errors.empty()) {
                        plan.error = builder.state_errors.front();
                        return false;
                  }
                  for (const auto&ref : refs) {
                        Z3Builder::VarRef canonical = ref;
                        if (ref.kind == Z3Builder::VarRef::PROP) {
                              auto alias = member_aliases.find(ref.idx);
                              if (alias != member_aliases.end())
                                    canonical = alias->second;
                        }
                        bool active = canonical.kind == Z3Builder::VarRef::PROP
                              ? (canonical.idx < graph.properties.size()
                                 && graph.active(canonical.idx))
                              : canonical.kind == Z3Builder::VarRef::MEMBER
                              ? rand_member_active_(builder, nullptr,
                                                    canonical.idx, canonical.leaf)
                              : canonical.kind == Z3Builder::VarRef::ELEM
                              ? rand_elem_active_(builder, nullptr,
                                                  canonical.idx, canonical.leaf)
                              : canonical.idx < graph.properties.size()
                                && graph.active(canonical.idx);
                        if (active) entry.refs.insert(canonical);
                  }
                  if (class_ir)
                        for (size_t slot : entry.item.capture_slots) {
                              const auto&calls = type->constraint_state_calls();
                              if (slot >= calls.size()
                                  || (constraint != UINT_MAX
                                      && calls[slot].constraint != constraint)) {
                                    plan.error = "constraint function capture metadata does not match its IR slot";
                                    return false;
                              }
                              entry.calls.push_back(slot);
                        }
                  work.push_back(entry);
            }
            return true;
      };
      for (size_t oi = 0; oi < objects.size(); ++oi) {
            const vvp_z3_object_s&owner = objects[oi];
            const class_type*type = owner.object->get_defn();
            for (const string&ir : owner.inherited_ir)
                  if (!add_ir(oi, ir, true, UINT_MAX)) goto fail;
            if (owner.include_class_constraints)
                  for (size_t ci = 0; ci < type->constraint_count(); ++ci)
                        if (owner.object->constraint_mode(ci)
                            && !add_ir(oi, type->constraint_ir(ci), true,
                                       (unsigned)ci)) goto fail;
            for (const string&ir : owner.extra_ir)
                  if (!add_ir(oi, ir, false, UINT_MAX)) goto fail;
      }

      {
            using Ref = Z3Builder::VarRef;
            map<Ref, set<Ref> > edges;
            set<Ref> active_refs;
            auto active_ref = [&](const Ref&ref) {
                  if (ref.idx >= graph.properties.size()) return false;
                  if (ref.kind == Ref::PROP) return graph.active(ref.idx);
                  if (ref.kind == Ref::ELEM)
                        return graph.element_active(ref.idx, ref.leaf);
                  if (ref.kind == Ref::MEMBER)
                        return graph.member_active(ref.idx, ref.leaf);
                  return graph.size_active(ref.idx);
            };
            for (unsigned idx = 0; idx < graph.properties.size(); ++idx) {
                  if (member_aliases.count(idx)) continue;
                  const class_type*type = graph.properties[idx].object->get_defn();
                  unsigned pid = graph.properties[idx].pid;
                  const string&base = type->property_base_type(pid);
                  uint64_t words = type->property_array_size(pid);
                  if (words > 1) {
                        for (unsigned leaf = 0; leaf < words; ++leaf) {
                              Ref ref = {Ref::ELEM, idx, leaf};
                              if (active_ref(ref)) active_refs.insert(ref);
                        }
                  } else if (base.compare(0, 3, "oc:") == 0) {
                        vvp_cobject*record = cobj_struct_prop(
                              graph.properties[idx].object, pid);
                        if (record)
                              for (unsigned leaf = 0;
                                   leaf < record->get_defn()->property_count(); ++leaf) {
                                    Ref ref = {Ref::MEMBER, idx, leaf};
                                    if (active_ref(ref)) active_refs.insert(ref);
                              }
                  } else if (!base.empty()
                             && (base[0] == 'D' || base[0] == 'Q')) {
                        Ref size = {Ref::SIZE, idx, 0};
                        if (active_ref(size)) {
                              active_refs.insert(size);
                              uint64_t words = cobj_darray_size(
                                    graph.properties[idx].object,
                                    graph.properties[idx].pid);
                              for (unsigned leaf = 0; leaf < words; ++leaf) {
                                    Ref element = {Ref::ELEM, idx, leaf};
                                    if (active_ref(element))
                                          active_refs.insert(element);
                              }
                        }
                  } else if (!base.empty() && base[0] == 'M') {
                        if (graph.size_active(idx)) {
                              plan.error = "associative-container function priority is not yet supported";
                              goto fail;
                        }
                  } else {
                        Ref ref = {Ref::PROP, idx, 0};
                        if (active_ref(ref)) active_refs.insert(ref);
                  }
            }

            vector<pair<size_t,size_t> > state_calls;
            vector<vector<pair<size_t,size_t> > > item_calls(work.size());
            vector<vector<set<Ref> > > call_args(work.size());
            vector<set<Ref> > item_args(work.size());
            set<Ref> all_args;
            for (size_t wi = 0; wi < work.size(); ++wi) {
                  const vvp_z3_object_s&scope = objects[work[wi].item.object];
                  const class_type*type = scope.object->get_defn();
                  for (size_t slot : work[wi].calls) {
                        const auto&call = type->constraint_state_calls()[slot];
                        set<Ref> args;
                        for (const auto&dependency : call.argument_dependencies) {
                              if (dependency.kind > Ref::SIZE) {
                                    plan.error = "invalid typed constraint function dependency";
                                    goto fail;
                              }
                              unsigned idx = graph.intern(scope.object,
                                                          dependency.property);
                              Ref ref = {static_cast<Ref::Kind>(dependency.kind),
                                         idx, dependency.leaf};
                              if (active_ref(ref)) {
                                    args.insert(ref);
                                    active_refs.insert(ref);
                              }
                        }
                        item_args[wi].insert(args.begin(), args.end());
                        all_args.insert(args.begin(), args.end());
                        item_calls[wi].push_back({work[wi].item.object, slot});
                        call_args[wi].push_back(args);
                        if (args.empty())
                              state_calls.push_back({work[wi].item.object, slot});
                  }
            }
            for (const auto&entry : work)
                  active_refs.insert(entry.refs.begin(), entry.refs.end());
            for (const Ref&element : active_refs) {
                  if (element.kind != Ref::ELEM) continue;
                  const string&base = graph.properties[element.idx].object
                        ->get_defn()->property_base_type(
                              graph.properties[element.idx].pid);
                  if (!base.empty() && (base[0] == 'D' || base[0] == 'Q')) {
                        Ref size = {Ref::SIZE, element.idx, 0};
                        if (active_refs.count(size)) edges[size].insert(element);
                  }
            }
            for (size_t wi = 0; wi < work.size(); ++wi)
                  for (const auto&args : call_args[wi])
                        for (const Ref&arg : args)
                              for (const Ref&target : work[wi].refs)
                                    if (!args.count(target)
                                        && all_args.count(target))
                                          edges[arg].insert(target);
            map<Ref, unsigned> levels;
            for (const Ref&ref : active_refs) levels[ref] = 0;
            for (size_t pass = 0; pass < active_refs.size(); ++pass) {
                  bool changed = false;
                  for (const auto&edge : edges)
                        for (const Ref&to : edge.second)
                              if (levels[to] <= levels[edge.first]) {
                                    levels[to] = levels[edge.first] + 1;
                                    changed = true;
                              }
                  if (!changed) break;
                  if (pass + 1 == active_refs.size()) {
                        plan.error = "cyclic active-random constraint function dependency";
                        goto fail;
                  }
            }
            unsigned final_level = 0;
            if (!all_args.empty()) {
                  for (const Ref&arg : all_args)
                        final_level = max(final_level, levels[arg]);
                  ++final_level;
                  for (const Ref&ref : active_refs)
                        /* Dynamic size is an inherent prerequisite of its
                         * prospective elements. Keep that established tier;
                         * ordinary nonargument scalars/elements remain peers
                         * in the final lower set. */
                        if (!all_args.count(ref) && ref.kind != Ref::SIZE)
                              levels[ref] = final_level;
            }
            for (const Ref&element : active_refs) {
                  if (element.kind != Ref::ELEM) continue;
                  const string&base = graph.properties[element.idx].object
                        ->get_defn()->property_base_type(
                              graph.properties[element.idx].pid);
                  if (!base.empty() && (base[0] == 'D' || base[0] == 'Q')) {
                        Ref size = {Ref::SIZE, element.idx, 0};
                        levels[element] = max(levels[element], levels[size] + 1);
                  }
            }
            /* Foreach is one semantic scope, but after SIZE is fixed its
             * iterations can occupy different function-priority sets. Keep
             * the existing runtime expansion and partition it with L guards:
             * exact argument elements are constrained in their own tier;
             * every other iteration remains with the ordinary lower peers. */
            {
                  vector<function_plan_item_t> expanded_work;
                  vector<vector<pair<size_t,size_t> > > expanded_item_calls;
                  vector<vector<set<Ref> > > expanded_call_args;
                  vector<set<Ref> > expanded_item_args;
                  for (size_t wi = 0; wi < work.size(); ++wi) {
                        if (!top_dynamic_foreach_(work[wi].item.ir)) {
                              expanded_work.push_back(work[wi]);
                              expanded_item_calls.push_back(item_calls[wi]);
                              expanded_call_args.push_back(call_args[wi]);
                              expanded_item_args.push_back(item_args[wi]);
                              continue;
                        }
                        if (!work[wi].calls.empty()) {
                              plan.error = "function calls inside dynamic foreach priority are not yet supported";
                              goto fail;
                        }
                        IRParser parser(work[wi].item.ir);
                        parser.consume();
                        if (parser.read_token() != "dynforeach") {
                              plan.error = "malformed dynamic foreach plan item";
                              goto fail;
                        }
                        string header = parser.read_token();
                        unsigned local = 0, width = 0; bool is_signed = false;
                        parse_pws_header(header, local, width, is_signed);
                        unsigned canonical = graph.intern(
                              objects[work[wi].item.object].object, local);
                        string body = capture_balanced_form(parser);
                        vector<Ref> exact;
                        for (const Ref&arg : all_args)
                              if (arg.kind == Ref::ELEM
                                  && arg.idx == canonical)
                                    exact.push_back(arg);
                        for (const Ref&arg : exact) {
                              function_plan_item_t part = work[wi];
                              ostringstream ir;
                              ir << "(dynforeach " << header
                                 << " (impl (eq L c:" << arg.leaf
                                 << ":32) " << body << "))";
                              part.item.ir = ir.str();
                              part.refs.clear();
                              string concrete = subst_loop_token(body,
                                                                 arg.leaf);
                              Z3Builder collector(ctx,
                                    objects[part.item.object].object->get_defn(),
                                    objects[part.item.object].object, &graph);
                              set<Ref> concrete_refs;
                              collector.collect_refs = &concrete_refs;
                              Z3_ast concrete_ast = parse_constraint_ir(
                                    concrete, collector);
                              concrete_ast = Z3_simplify(ctx,
                                    collector.resolve_signed_constants(
                                          concrete_ast));
                              if (!collector.state_errors.empty()) {
                                    plan.error = collector.state_errors.front();
                                    goto fail;
                              }
                              auto contains_ast = [&](Z3_ast needle) {
                                    vector<Z3_ast> pending(1, concrete_ast);
                                    set<Z3_ast> seen;
                                    while (!pending.empty()) {
                                          Z3_ast node = pending.back();
                                          pending.pop_back();
                                          if (node == needle) return true;
                                          if (!seen.insert(node).second
                                              || Z3_get_ast_kind(ctx, node)
                                                   != Z3_APP_AST)
                                                continue;
                                          Z3_app app = Z3_to_app(ctx, node);
                                          for (unsigned ai = 0;
                                               ai < Z3_get_app_num_args(ctx, app);
                                               ++ai)
                                                pending.push_back(
                                                      Z3_get_app_arg(ctx, app,
                                                                     ai));
                                    }
                                    return false;
                              };
                              for (Ref ref : concrete_refs) {
                                    Z3_ast variable = nullptr;
                                    if (ref.kind == Ref::PROP)
                                          for (const auto&var : collector.prop_vars)
                                                if (var.idx == ref.idx)
                                                      variable = var.var;
                                    if (ref.kind == Ref::ELEM)
                                          for (const auto&var : collector.elem_vars)
                                                if (var.idx == ref.idx
                                                    && var.elem == ref.leaf)
                                                      variable = var.var;
                                    if (ref.kind == Ref::SIZE)
                                          for (const auto&var : collector.size_vars)
                                                if (var.idx == ref.idx)
                                                      variable = var.var;
                                    if (ref.kind == Ref::MEMBER)
                                          for (const auto&var : collector.member_vars)
                                                if (var.outer == ref.idx
                                                    && var.member == ref.leaf)
                                                      variable = var.var;
                                    if (!variable || !contains_ast(variable))
                                          continue;
                                    if (ref.kind == Ref::PROP) {
                                          auto alias = member_aliases.find(ref.idx);
                                          if (alias != member_aliases.end())
                                                ref = alias->second;
                                    }
                                    if (active_ref(ref)) {
                                          if (!levels.count(ref)) {
                                                unsigned level = final_level;
                                                if (ref.kind == Ref::SIZE)
                                                      level = 0;
                                                else if (ref.kind == Ref::ELEM) {
                                                      const string&base =
                                                            graph.properties[ref.idx].object
                                                                  ->get_defn()->property_base_type(
                                                                        graph.properties[ref.idx].pid);
                                                      if (!base.empty()
                                                          && (base[0] == 'D'
                                                              || base[0] == 'Q')) {
                                                            Ref size = {
                                                                  Ref::SIZE,
                                                                  ref.idx, 0};
                                                            level = max(level,
                                                                  levels[size] + 1);
                                                      }
                                                }
                                                levels[ref] = level;
                                                active_refs.insert(ref);
                                          }
                                          part.refs.insert(ref);
                                    }
                              }
                              part.minimum_stage = 0;
                              expanded_work.push_back(part);
                              expanded_item_calls.emplace_back();
                              expanded_call_args.emplace_back();
                              expanded_item_args.emplace_back();
                        }
                        function_plan_item_t remainder = work[wi];
                        if (!exact.empty()) {
                              ostringstream guard;
                              if (exact.size() > 1) guard << "(and ";
                              for (const Ref&arg : exact)
                                    guard << "(ne L c:" << arg.leaf << ":32)";
                              if (exact.size() > 1) guard << ")";
                              ostringstream ir;
                              ir << "(dynforeach " << header << " (impl "
                                 << guard.str() << " " << body << "))";
                              remainder.item.ir = ir.str();
                        }
                        remainder.minimum_stage = final_level;
                        expanded_work.push_back(remainder);
                        expanded_item_calls.emplace_back();
                        expanded_call_args.emplace_back();
                        expanded_item_args.emplace_back();
                  }
                  work.swap(expanded_work);
                  item_calls.swap(expanded_item_calls);
                  call_args.swap(expanded_call_args);
                  item_args.swap(expanded_item_args);
            }
            unsigned dynamic_element_level = 0;
            for (const Ref&ref : active_refs)
                  if (ref.kind == Ref::SIZE)
                        dynamic_element_level = max(
                              dynamic_element_level, levels[ref] + 1);
            unsigned count = 1;
            for (size_t wi = 0; wi < work.size(); ++wi) {
                  unsigned stage = work[wi].minimum_stage;
                  for (const Ref&ref : work[wi].refs)
                        if (active_ref(ref)) stage = max(stage, levels[ref]);
                  for (const Ref&arg : item_args[wi])
                        stage = max(stage, levels[arg] + 1);
                  if (top_dynamic_foreach_(work[wi].item.ir))
                        stage = max(stage, dynamic_element_level);
                  work[wi].stage = stage;
                  count = max(count, stage + 1);
            }
            for (const Ref&ref : active_refs)
                  count = max(count, levels[ref] + 1);
            plan.stages.resize(count);
            for (auto&stage : plan.stages)
                  stage.active.resize(objects.size());
            for (const Ref&ref : active_refs) {
                  for (const auto&binding : graph.properties[ref.idx].bindings)
                        for (size_t oi = 0; oi < objects.size(); ++oi)
                              if (binding.scope == &objects[oi]) {
                                    bool selected = ref.kind == Ref::ELEM
                                          ? rand_elem_active_(
                                                objects[oi].object->get_defn(),
                                                objects[oi].object,
                                                objects[oi].selection(),
                                                binding.pid, ref.leaf)
                                          : ref.kind == Ref::MEMBER
                                          ? rand_member_active_(
                                                objects[oi].object->get_defn(),
                                                objects[oi].object,
                                                objects[oi].selection(),
                                                binding.pid, ref.leaf)
                                          : rand_active_(
                                                objects[oi].object->get_defn(),
                                                objects[oi].object,
                                                objects[oi].selection(),
                                                binding.pid);
                                    if (selected) {
                                          plan.stages[levels[ref]].active[oi].push_back(
                                                {static_cast<unsigned>(ref.kind),
                                                 binding.pid, ref.leaf});
                                          /* m:OUTER:MEMBER lowers to the
                                           * synthetic struct object's scalar
                                           * property in the solver. Select
                                           * that canonical storage in the
                                           * same stage; otherwise a later
                                           * child-object pass can overwrite
                                           * the solved member. */
                                          if (ref.kind == Ref::MEMBER) {
                                                vvp_cobject*record =
                                                      cobj_struct_prop(
                                                            objects[oi].object,
                                                            binding.pid);
                                                unsigned child = graph.intern(
                                                      record, ref.leaf);
                                                for (const auto&child_binding :
                                                     graph.properties[child].bindings)
                                                      for (size_t ci = 0;
                                                           ci < objects.size(); ++ci)
                                                            if (child_binding.scope
                                                                  == &objects[ci])
                                                                  plan.stages[levels[ref]].active[ci].push_back(
                                                                        {vvp_z3_ref_s::PROP,
                                                                         child_binding.pid, 0});
                                          }
                                    }
                              }
            }
            /* A size solve may create leaves after planning. Materialize all
             * otherwise-unmentioned active leaves in the final priority set
             * after that size has been applied; exact earlier ELEM stages are
             * retained and excluded by the runtime expansion. */
            set<pair<size_t, unsigned> > deferred_bindings;
            for (unsigned idx = 0; idx < graph.properties.size(); ++idx) {
                  Ref size = {Ref::SIZE, idx, 0};
                  if (!active_refs.count(size)) continue;
                  const auto&property = graph.properties[idx];
                  const string&base = property.object->get_defn()
                        ->property_base_type(property.pid);
                  if (base.empty() || (base[0] != 'D' && base[0] != 'Q'))
                        continue;
                  for (const auto&binding : property.bindings)
                        for (size_t oi = 0; oi < objects.size(); ++oi)
                              if (binding.scope == &objects[oi]
                                  && rand_active_(
                                        objects[oi].object->get_defn(),
                                        objects[oi].object,
                                        objects[oi].selection(), binding.pid)) {
                                    if (!deferred_bindings.insert(
                                          {oi, binding.pid}).second)
                                          continue;
                                    unsigned deferred_stage =
                                          max(final_level, levels[size] + 1);
                                    while (plan.stages.size()
                                           <= deferred_stage) {
                                          plan.stages.emplace_back();
                                          plan.stages.back().active.resize(
                                                objects.size());
                                    }
                                    plan.deferred_elements.push_back(
                                          {oi, binding.pid, deferred_stage});
                              }
            }
            set<pair<size_t,size_t> > scheduled_state;
            for (const auto&call : state_calls)
                  if (scheduled_state.insert(call).second)
                        plan.stages[0].before_calls.push_back({call.first, call.second});
            map<pair<size_t,size_t>, unsigned> call_stages;
            for (size_t wi = 0; wi < work.size(); ++wi)
                  for (const auto&call : item_calls[wi])
                        if (!scheduled_state.count(call)) {
                              auto found = call_stages.find(call);
                              if (found == call_stages.end()
                                  || work[wi].stage < found->second)
                                    call_stages[call] = work[wi].stage;
                        }
            for (const auto&entry : call_stages)
                  plan.stages[entry.second].before_calls.push_back(
                        {entry.first.first, entry.first.second});
            for (size_t wi = 0; wi < work.size(); ++wi)
                  plan.stages[work[wi].stage].items.push_back(work[wi].item);
      }
      Z3_del_context(ctx);
      return true;
fail:
      Z3_del_context(ctx);
      plan.stages.clear();
      plan.deferred_elements.clear();
      return false;
}

/* Both passes use the same storage registry and replay each actual object's
 * RNG stream. No independently solved child value becomes a state pin. */
bool vvp_z3_randomize_graph(const vector<vvp_z3_object_s>&objects)
{
      if (objects.empty()) return true;
      bool constrained = false;
      for (const auto&owner : objects)
            constrained |= !owner.inherited_ir.empty() || !owner.extra_ir.empty()
                  || !owner.planned_class_ir.empty()
                  || (owner.include_class_constraints
                      && owner.object->get_defn()->constraint_count() != 0);
      if (!constrained) return true;
      z3_object_graph_t graph(objects);
      graph.select_storage_owners();
      const auto&root = objects.front();
      z3_rng_stream_t root_rng(root.object);
      map<vvp_cobject*, unique_ptr<z3_rng_stream_t> > streams;
      vector<Z3Builder::DynForeach> dyn;
      static const vector<string> no_extra;
      static const vector<uint64_t> no_slots;
      static const vector<vvp_vector4_t> no_class_slots;
      int result = z3_solve_pass_(root.object->get_defn(), root.object,
            root_rng, no_extra, no_slots, no_class_slots, nullptr, &dyn, root.selection(),
            true, &graph, &streams);
      if (result == Z3PASS_FAILED || dyn.empty()) return result != Z3PASS_FAILED;
      map<unsigned, uint64_t> sizes;
      for (const auto&loop : dyn) {
            const auto&property = graph.properties.at(loop.pidx);
            sizes[loop.pidx] = cobj_darray_size(property.object, property.pid);
      }
      root_rng.rewind();
      for (auto&stream : streams) stream.second->rewind();
      return z3_solve_pass_(root.object->get_defn(), root.object,
            root_rng, no_extra, no_slots, no_class_slots, &sizes, nullptr, root.selection(),
            true, &graph, &streams) != Z3PASS_FAILED;
}

bool vvp_z3_randomize_scope(const string&ir,
			    const vector<string>&targets,
			    const vector<unsigned>&widths,
			    const vector<uint64_t>&slot_vals,
			    const vector<vector<uint64_t> >&object_vals,
			    const vector<vector<bool> >&object_known,
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
      sub = substitute_scope_object_slots(sub, object_vals, object_known);
      Z3_ast assertion = parse_constraint_ir(sub, builder);
      if (!builder.state_errors.empty()) {
            fprintf(stderr, "ERROR: constraint state read: %s.\n",
                    builder.state_errors.front().c_str());
            Z3_optimize_dec_ref(ctx, opt);
            Z3_del_context(ctx);
            return false;
      }
      if (z3_dyndbg()) {
	    fprintf(stderr, "Z3 scope IR: %s\n", sub.c_str());
	    fprintf(stderr, "Z3 scope hard: %s\n",
		    Z3_ast_to_string(ctx, assertion));
	    for (size_t i = 0 ; i < builder.pending_soft.size() ; i += 1)
		  fprintf(stderr, "Z3 scope soft[%zu]: %s\n", i,
			  Z3_ast_to_string(ctx, builder.pending_soft[i].a));
      }
      Z3_optimize_assert(ctx, opt, assertion);
      Z3_ast any_state_error = nullptr;
      if (!builder.state_checks.empty()) {
	    any_state_error = constraint_state_error_disjunction_(
		  builder, 0, builder.state_checks.size());
	    Z3_optimize_assert(ctx, opt,
			      Z3_mk_not(ctx, any_state_error));
      }

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
		  if (builder.soft_ref_disabled(ref, sa.priority)) return true;
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
	    if (any_state_error) {
		  Z3_solver diagnostic = Z3_mk_simple_solver(ctx);
		  Z3_solver_inc_ref(ctx, diagnostic);
		  Z3_solver_assert(ctx, diagnostic, assertion);
		  Z3_solver_assert(ctx, diagnostic, any_state_error);
		  if (Z3_solver_check(ctx, diagnostic) == Z3_L_TRUE) {
			Z3_model model = Z3_solver_get_model(ctx, diagnostic);
			Z3_model_inc_ref(ctx, model);
			for (const auto&check : builder.state_checks) {
			      Z3_ast value = nullptr;
			      if (!Z3_model_eval(ctx, model, check.error, 1, &value)
			          || !value
			          || Z3_get_bool_value(ctx, Z3_simplify(ctx, value))
			                         != Z3_L_TRUE) continue;
			      fprintf(stderr,
				    "ERROR: constraint state read: %s.\n",
				    check.message.c_str());
			      break;
			}
			Z3_model_dec_ref(ctx, model);
		  }
		  Z3_solver_dec_ref(ctx, diagnostic);
	    }
	    Z3_optimize_dec_ref(ctx, opt);
	    Z3_del_context(ctx);
	    return false;
      }

      if (result == Z3_L_UNDEF) {
            fprintf(stderr, "ERROR: scope randomization solver returned UNKNOWN; "
                    "no valid randomized result was produced.\n");
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
      }

      Z3_optimize_dec_ref(ctx, opt);
      Z3_del_context(ctx);
      return true;
}
