/*
 * Exact uniform sampling of bit-vector constraint sets through a reduced
 * ordered BDD. See z3_bdd.h for the contract.
 *
 * The Z3 assertions are bit-blasted structurally (LSB-first bit vectors of
 * BDD nodes). Semantic variables occupy the top levels, interleaved MSB
 * first within each solve stage; every other constant sits below them.
 * Because a non-terminal ROBDD node is never the constant false, quantifying
 * that bottom block existentially just means "any node below the semantic
 * levels counts as one solution", which the counting pass does directly.
 *
 * Sampling draws one uniform integer per stage below that stage's projected
 * solution count and decodes it while descending: at a node the low branch
 * covers [0, cl), and each run of skipped (free) levels takes its bits from
 * the low end of the remaining index. That is a bijection between
 * [0, count) and the projected assignments, so the draw is exactly uniform.
 */

# include  "z3_bdd.h"
# include  <algorithm>
# include  <map>
# include  <string>
# include  <unordered_map>

using namespace std;

namespace {

struct budget_exceeded { };
struct unsupported { };

/* Little-endian arbitrary-precision unsigned integer: just the operations
   counting and decoding need. */
struct big_t {
      vector<uint32_t> w;
      bool zero() const { return w.empty(); }
      void trim() { while (!w.empty() && !w.back()) w.pop_back(); }
      static big_t one() { big_t r; r.w.push_back(1); return r; }
      unsigned bits() const
      {
	    if (w.empty()) return 0;
	    unsigned n = 32 * (unsigned)(w.size() - 1);
	    for (uint32_t top = w.back(); top; top >>= 1) n += 1;
	    return n;
      }
      bool bit(unsigned i) const
      {
	    return i / 32 < w.size() && ((w[i / 32] >> (i % 32)) & 1);
      }
};

static big_t big_add(const big_t&a, const big_t&b)
{
      big_t r;
      uint64_t carry = 0;
      for (size_t i = 0; i < max(a.w.size(), b.w.size()) || carry; ++i) {
	    uint64_t s = carry;
	    if (i < a.w.size()) s += a.w[i];
	    if (i < b.w.size()) s += b.w[i];
	    r.w.push_back((uint32_t)s);
	    carry = s >> 32;
      }
      r.trim();
      return r;
}

static big_t big_sub(const big_t&a, const big_t&b)   /* requires a >= b */
{
      big_t r = a;
      int64_t borrow = 0;
      for (size_t i = 0; i < r.w.size(); ++i) {
	    int64_t d = (int64_t)r.w[i] - borrow - (i < b.w.size() ? b.w[i] : 0);
	    borrow = d < 0;
	    r.w[i] = (uint32_t)(d + (borrow << 32));
      }
      r.trim();
      return r;
}

static int big_cmp(const big_t&a, const big_t&b)
{
      if (a.w.size() != b.w.size()) return a.w.size() < b.w.size() ? -1 : 1;
      for (size_t i = a.w.size(); i-- > 0;)
	    if (a.w[i] != b.w[i]) return a.w[i] < b.w[i] ? -1 : 1;
      return 0;
}

static big_t big_shl(const big_t&a, unsigned k)
{
      if (a.zero() || !k) return a;
      big_t r;
      r.w.assign(k / 32, 0);
      uint32_t carry = 0;
      for (uint32_t word : a.w) {
	    r.w.push_back(k % 32 ? (word << (k % 32)) | carry : word);
	    carry = k % 32 ? word >> (32 - k % 32) : 0;
      }
      r.w.push_back(carry);
      r.trim();
      return r;
}

static big_t big_shr(const big_t&a, unsigned k)
{
      big_t r;
      for (size_t i = k / 32; i < a.w.size(); ++i) {
	    uint64_t word = a.w[i] >> (k % 32);
	    if (k % 32 && i + 1 < a.w.size())
		  word |= (uint64_t)a.w[i + 1] << (32 - k % 32);
	    r.w.push_back((uint32_t)word);
      }
      r.trim();
      return r;
}

/* Uniform integer in [0, n), n > 0, by rejection over bits(n) random bits. */
static big_t big_uniform_below(const big_t&n,
			       const function<uint32_t()>&rand32)
{
      unsigned nbits = n.bits();
      for (;;) {
	    big_t r;
	    for (unsigned i = 0; i < (nbits + 31) / 32; ++i) r.w.push_back(rand32());
	    if (nbits % 32) r.w.back() &= (UINT32_C(1) << (nbits % 32)) - 1;
	    r.trim();
	    if (big_cmp(r, n) < 0) return r;
      }
}

class bdd_t {
    public:
      explicit bdd_t(size_t budget) : budget_(budget)
      {
	    var_.assign(2, UINT32_MAX);   /* terminals sit below every level */
	    lo_.assign(2, 0);
	    hi_.assign(2, 1);
      }

      uint32_t var(uint32_t x) const { return var_[x]; }
      uint32_t lo(uint32_t x) const { return lo_[x]; }
      uint32_t hi(uint32_t x) const { return hi_[x]; }
      size_t size() const { return var_.size(); }

      uint32_t mk(uint32_t v, uint32_t l, uint32_t h)
      {
	    if (l == h) return l;
	    key_t key{v, l, h};
	    auto found = unique_.find(key);
	    if (found != unique_.end()) return found->second;
	    if (var_.size() >= budget_) throw budget_exceeded();
	    uint32_t node = (uint32_t)var_.size();
	    var_.push_back(v);
	    lo_.push_back(l);
	    hi_.push_back(h);
	    unique_.emplace(key, node);
	    return node;
      }

      uint32_t ithvar(uint32_t v) { return mk(v, 0, 1); }

      uint32_t ite(uint32_t f, uint32_t g, uint32_t h)
      {
	    if (f == 1) return g;
	    if (f == 0) return h;
	    if (g == h) return g;
	    if (g == 1 && h == 0) return f;
	    key_t key{f, g, h};
	    auto found = cache_.find(key);
	    if (found != cache_.end()) return found->second;
	    uint32_t v = min(var_[f], min(var_[g], var_[h]));
	    uint32_t r = mk(v, ite(cof_(f, v, false), cof_(g, v, false), cof_(h, v, false)),
			       ite(cof_(f, v, true), cof_(g, v, true), cof_(h, v, true)));
	    cache_.emplace(key, r);
	    return r;
      }

      uint32_t NOT(uint32_t f) { return ite(f, 0, 1); }
      uint32_t AND(uint32_t f, uint32_t g) { return ite(f, g, 0); }
      uint32_t OR(uint32_t f, uint32_t g) { return ite(f, 1, g); }
      uint32_t XOR(uint32_t f, uint32_t g) { return ite(f, NOT(g), g); }
      uint32_t XNOR(uint32_t f, uint32_t g) { return ite(f, g, NOT(g)); }

    private:
      struct key_t {
	    uint32_t a, b, c;
	    bool operator==(const key_t&o) const { return a == o.a && b == o.b && c == o.c; }
      };
      struct key_hash_t {
	    size_t operator()(const key_t&k) const
	    {
		  uint64_t h = k.a * UINT64_C(0x9e3779b97f4a7c15);
		  h ^= k.b + UINT64_C(0x7f4a7c159e3779b9) + (h << 6) + (h >> 2);
		  h ^= k.c + UINT64_C(0x94d049bb133111eb) + (h << 6) + (h >> 2);
		  return (size_t)h;
	    }
      };

      uint32_t cof_(uint32_t x, uint32_t v, bool high) const
      {
	    if (var_[x] != v) return x;
	    return high ? hi_[x] : lo_[x];
      }

      size_t budget_;
      vector<uint32_t> var_, lo_, hi_;
      unordered_map<key_t, uint32_t, key_hash_t> unique_, cache_;
};

typedef vector<uint32_t> bits_t;   /* LSB first */

class blaster_t {
    public:
      blaster_t(Z3_context ctx, bdd_t&bdd, const map<unsigned, bits_t>&levels)
      : ctx_(ctx), bdd_(bdd), levels_(levels) { }

      uint32_t boolean(Z3_ast e)
      {
	    unsigned id = Z3_get_ast_id(ctx_, e);
	    auto found = bool_memo_.find(id);
	    if (found != bool_memo_.end()) return found->second;
	    uint32_t r = boolean_(e);
	    bool_memo_[id] = r;
	    return r;
      }

    private:
      Z3_ast arg_(Z3_ast e, unsigned i)
      {
	    return Z3_get_app_arg(ctx_, Z3_to_app(ctx_, e), i);
      }
      unsigned nargs_(Z3_ast e)
      {
	    return Z3_get_app_num_args(ctx_, Z3_to_app(ctx_, e));
      }
      Z3_decl_kind kind_(Z3_ast e)
      {
	    if (Z3_get_ast_kind(ctx_, e) != Z3_APP_AST) throw unsupported();
	    return Z3_get_decl_kind(ctx_, Z3_get_app_decl(ctx_, Z3_to_app(ctx_, e)));
      }
      int param_(Z3_ast e, unsigned i)
      {
	    return Z3_get_decl_int_parameter(ctx_,
		  Z3_get_app_decl(ctx_, Z3_to_app(ctx_, e)), i);
      }
      unsigned width_(Z3_ast e)
      {
	    return Z3_get_bv_sort_size(ctx_, Z3_get_sort(ctx_, e));
      }

      bits_t add_(const bits_t&x, const bits_t&y, uint32_t carry = 0)
      {
	    bits_t r;
	    for (size_t i = 0; i < x.size(); ++i) {
		  uint32_t half = bdd_.XOR(x[i], y[i]);
		  r.push_back(bdd_.XOR(half, carry));
		  carry = bdd_.OR(bdd_.AND(x[i], y[i]), bdd_.AND(carry, half));
	    }
	    return r;
      }
      bits_t not_(const bits_t&x)
      {
	    bits_t r;
	    for (uint32_t b : x) r.push_back(bdd_.NOT(b));
	    return r;
      }
      bits_t mul_(const bits_t&x, const bits_t&y)
      {
	    bits_t acc(x.size(), 0);
	    for (size_t i = 0; i < y.size(); ++i) {
		  if (y[i] == 0) continue;
		  bits_t part(x.size(), 0);
		  for (size_t j = i; j < x.size(); ++j)
			part[j] = bdd_.AND(y[i], x[j - i]);
		  acc = add_(acc, part);
	    }
	    return acc;
      }
	/* Barrel shifter; an amount at or beyond the width yields FILL. */
      bits_t shift_(const bits_t&x, const bits_t&amount, bool left, uint32_t fill)
      {
	    bits_t r = x;
	    size_t n = x.size();
	    uint32_t over = 0;
	    for (size_t k = 0; k < amount.size(); ++k) {
		  if (k >= 32 || (size_t(1) << k) >= n) {
			over = bdd_.OR(over, amount[k]);
			continue;
		  }
		  size_t s = size_t(1) << k;
		  bits_t shifted(n, fill);
		  for (size_t i = 0; i < n; ++i) {
			if (left && i >= s) shifted[i] = r[i - s];
			if (!left && i + s < n) shifted[i] = r[i + s];
		  }
		  for (size_t i = 0; i < n; ++i)
			r[i] = bdd_.ite(amount[k], shifted[i], r[i]);
	    }
	    for (size_t i = 0; i < n; ++i) r[i] = bdd_.ite(over, fill, r[i]);
	    return r;
      }
      uint32_t ult_(const bits_t&x, const bits_t&y)
      {
	    uint32_t lt = 0;
	    for (size_t i = 0; i < x.size(); ++i)
		  lt = bdd_.OR(bdd_.AND(bdd_.NOT(x[i]), y[i]),
			       bdd_.AND(bdd_.XNOR(x[i], y[i]), lt));
	    return lt;
      }
      uint32_t eq_(const bits_t&x, const bits_t&y)
      {
	    uint32_t r = 1;
	    for (size_t i = 0; i < x.size(); ++i) r = bdd_.AND(r, bdd_.XNOR(x[i], y[i]));
	    return r;
      }

      bits_t numeral_(Z3_ast e)
      {
	    big_t value;
	    for (const char*p = Z3_get_numeral_string(ctx_, e); *p; ++p) {
		  if (*p < '0' || *p > '9') throw unsupported();
		  big_t times10 = big_add(big_shl(value, 3), big_shl(value, 1));
		  big_t digit;
		  if (*p != '0') digit.w.push_back((uint32_t)(*p - '0'));
		  value = big_add(times10, digit);
	    }
	    bits_t r;
	    for (unsigned i = 0; i < width_(e); ++i) r.push_back(value.bit(i) ? 1 : 0);
	    return r;
      }

      bits_t bv(Z3_ast e)
      {
	    unsigned id = Z3_get_ast_id(ctx_, e);
	    auto found = bv_memo_.find(id);
	    if (found != bv_memo_.end()) return found->second;
	    bits_t r = bv_(e);
	    if (r.size() != width_(e)) throw unsupported();
	    bv_memo_[id] = r;
	    return r;
      }

      bits_t bv_(Z3_ast e)
      {
	    if (Z3_get_ast_kind(ctx_, e) == Z3_NUMERAL_AST) return numeral_(e);
	    Z3_decl_kind k = kind_(e);
	    unsigned n = nargs_(e);
	    switch (k) {
		case Z3_OP_BNUM:
		  return numeral_(e);
		case Z3_OP_UNINTERPRETED: {
		  auto found = levels_.find(Z3_get_ast_id(ctx_, e));
		  if (n || found == levels_.end()) throw unsupported();
		  bits_t r;
		  for (uint32_t level : found->second) r.push_back(bdd_.ithvar(level));
		  return r;
		}
		case Z3_OP_BADD: {
		  bits_t r = bv(arg_(e, 0));
		  for (unsigned i = 1; i < n; ++i) r = add_(r, bv(arg_(e, i)));
		  return r;
		}
		case Z3_OP_BSUB:
		  return add_(bv(arg_(e, 0)), not_(bv(arg_(e, 1))), 1);
		case Z3_OP_BNEG:
		  return add_(bits_t(width_(e), 0), not_(bv(arg_(e, 0))), 1);
		case Z3_OP_BMUL: {
		  bits_t r = bv(arg_(e, 0));
		  for (unsigned i = 1; i < n; ++i) r = mul_(r, bv(arg_(e, i)));
		  return r;
		}
		case Z3_OP_BAND: case Z3_OP_BOR: case Z3_OP_BXOR:
		case Z3_OP_BNAND: case Z3_OP_BNOR: case Z3_OP_BXNOR: {
		  bits_t r = bv(arg_(e, 0));
		  for (unsigned i = 1; i < n; ++i) {
			bits_t y = bv(arg_(e, i));
			for (size_t j = 0; j < r.size(); ++j)
			      r[j] = (k == Z3_OP_BAND || k == Z3_OP_BNAND) ? bdd_.AND(r[j], y[j])
				   : (k == Z3_OP_BOR || k == Z3_OP_BNOR) ? bdd_.OR(r[j], y[j])
				   : bdd_.XOR(r[j], y[j]);
		  }
		  if (k == Z3_OP_BNAND || k == Z3_OP_BNOR || k == Z3_OP_BXNOR) r = not_(r);
		  return r;
		}
		case Z3_OP_BNOT:
		  return not_(bv(arg_(e, 0)));
		case Z3_OP_CONCAT: {
		  bits_t r;
		  for (unsigned i = n; i-- > 0;) {
			bits_t part = bv(arg_(e, i));
			r.insert(r.end(), part.begin(), part.end());
		  }
		  return r;
		}
		case Z3_OP_EXTRACT: {
		  bits_t x = bv(arg_(e, 0));
		  int hi = param_(e, 0), lo = param_(e, 1);
		  return bits_t(x.begin() + lo, x.begin() + hi + 1);
		}
		case Z3_OP_ZERO_EXT: case Z3_OP_SIGN_EXT: {
		  bits_t x = bv(arg_(e, 0));
		  uint32_t fill = k == Z3_OP_SIGN_EXT && !x.empty() ? x.back() : 0;
		  x.insert(x.end(), (size_t)param_(e, 0), fill);
		  return x;
		}
		case Z3_OP_REPEAT: {
		  bits_t x = bv(arg_(e, 0)), r;
		  for (int i = 0; i < param_(e, 0); ++i) r.insert(r.end(), x.begin(), x.end());
		  return r;
		}
		case Z3_OP_ITE: {
		  uint32_t c = boolean(arg_(e, 0));
		  bits_t t = bv(arg_(e, 1)), f = bv(arg_(e, 2));
		  for (size_t i = 0; i < t.size(); ++i) t[i] = bdd_.ite(c, t[i], f[i]);
		  return t;
		}
		case Z3_OP_BSHL: case Z3_OP_BLSHR: case Z3_OP_BASHR: {
		  bits_t x = bv(arg_(e, 0));
		  uint32_t fill = k == Z3_OP_BASHR && !x.empty() ? x.back() : 0;
		  return shift_(x, bv(arg_(e, 1)), k == Z3_OP_BSHL, fill);
		}
		case Z3_OP_BREDOR: case Z3_OP_BREDAND: {
		  bits_t x = bv(arg_(e, 0));
		  uint32_t r = k == Z3_OP_BREDAND ? 1 : 0;
		  for (uint32_t b : x) r = k == Z3_OP_BREDAND ? bdd_.AND(r, b) : bdd_.OR(r, b);
		  return bits_t(1, r);
		}
		case Z3_OP_BCOMP:
		  return bits_t(1, eq_(bv(arg_(e, 0)), bv(arg_(e, 1))));
		default:
		  throw unsupported();
	    }
      }

      uint32_t boolean_(Z3_ast e)
      {
	    Z3_decl_kind k = kind_(e);
	    unsigned n = nargs_(e);
	    switch (k) {
		case Z3_OP_TRUE: return 1;
		case Z3_OP_FALSE: return 0;
		case Z3_OP_UNINTERPRETED: {
		  auto found = levels_.find(Z3_get_ast_id(ctx_, e));
		  if (n || found == levels_.end() || found->second.size() != 1)
			throw unsupported();
		  return bdd_.ithvar(found->second[0]);
		}
		case Z3_OP_AND: case Z3_OP_OR: {
		  uint32_t r = k == Z3_OP_AND ? 1 : 0;
		  for (unsigned i = 0; i < n; ++i) {
			uint32_t x = boolean(arg_(e, i));
			r = k == Z3_OP_AND ? bdd_.AND(r, x) : bdd_.OR(r, x);
		  }
		  return r;
		}
		case Z3_OP_NOT: return bdd_.NOT(boolean(arg_(e, 0)));
		case Z3_OP_XOR: return bdd_.XOR(boolean(arg_(e, 0)), boolean(arg_(e, 1)));
		case Z3_OP_IMPLIES:
		  return bdd_.OR(bdd_.NOT(boolean(arg_(e, 0))), boolean(arg_(e, 1)));
		case Z3_OP_ITE:
		  return bdd_.ite(boolean(arg_(e, 0)), boolean(arg_(e, 1)),
				  boolean(arg_(e, 2)));
		case Z3_OP_EQ: case Z3_OP_DISTINCT: {
		  Z3_sort sort = Z3_get_sort(ctx_, arg_(e, 0));
		  bool is_bool = Z3_get_sort_kind(ctx_, sort) == Z3_BOOL_SORT;
		  if (!is_bool && Z3_get_sort_kind(ctx_, sort) != Z3_BV_SORT)
			throw unsupported();
		  auto same = [&](unsigned i, unsigned j) {
			return is_bool ? bdd_.XNOR(boolean(arg_(e, i)), boolean(arg_(e, j)))
				       : eq_(bv(arg_(e, i)), bv(arg_(e, j)));
		  };
		  uint32_t r = 1;
		  for (unsigned i = 0; i + 1 < n; ++i) {
			if (k == Z3_OP_EQ) r = bdd_.AND(r, same(i, i + 1));
			else for (unsigned j = i + 1; j < n; ++j)
			      r = bdd_.AND(r, bdd_.NOT(same(i, j)));
		  }
		  return r;
		}
		case Z3_OP_ULEQ: case Z3_OP_ULT: case Z3_OP_UGEQ: case Z3_OP_UGT:
		case Z3_OP_SLEQ: case Z3_OP_SLT: case Z3_OP_SGEQ: case Z3_OP_SGT: {
		  bits_t x = bv(arg_(e, 0)), y = bv(arg_(e, 1));
		  bool is_signed = k == Z3_OP_SLEQ || k == Z3_OP_SLT
			|| k == Z3_OP_SGEQ || k == Z3_OP_SGT;
		  if (is_signed && !x.empty()) {   /* bias the sign bit */
			x.back() = bdd_.NOT(x.back());
			y.back() = bdd_.NOT(y.back());
		  }
		  if (k == Z3_OP_UGEQ || k == Z3_OP_UGT || k == Z3_OP_SGEQ || k == Z3_OP_SGT)
			swap(x, y);
		  if (k == Z3_OP_ULT || k == Z3_OP_SLT || k == Z3_OP_UGT || k == Z3_OP_SGT)
			return ult_(x, y);
		  return bdd_.NOT(ult_(y, x));
		}
		default:
		  throw unsupported();
	    }
      }

      Z3_context ctx_;
      bdd_t&bdd_;
      const map<unsigned, bits_t>&levels_;
      unordered_map<unsigned, bits_t> bv_memo_;
      unordered_map<unsigned, uint32_t> bool_memo_;
};

static void collect_constants_(Z3_context ctx, Z3_ast e, map<unsigned, Z3_ast>&out,
			       unordered_map<unsigned, bool>&seen)
{
      if (!seen.emplace(Z3_get_ast_id(ctx, e), true).second) return;
      if (Z3_get_ast_kind(ctx, e) != Z3_APP_AST) return;
      Z3_app app = Z3_to_app(ctx, e);
      unsigned n = Z3_get_app_num_args(ctx, app);
      if (!n && Z3_get_decl_kind(ctx, Z3_get_app_decl(ctx, app)) == Z3_OP_UNINTERPRETED)
	    out[Z3_get_ast_id(ctx, e)] = e;
      for (unsigned i = 0; i < n; ++i)
	    collect_constants_(ctx, Z3_get_app_arg(ctx, app, i), out, seen);
}

static unsigned const_width_(Z3_context ctx, Z3_ast e)
{
      Z3_sort sort = Z3_get_sort(ctx, e);
      switch (Z3_get_sort_kind(ctx, sort)) {
	  case Z3_BOOL_SORT: return 1;
	  case Z3_BV_SORT: return Z3_get_bv_sort_size(ctx, sort);
	  default: throw unsupported();
      }
}

/* Projected count of node X over levels [*, HI): the number of assignments to
   the levels from var(X) up to HI that reach a non-false node. */
class counter_t {
    public:
      counter_t(const bdd_t&bdd, uint32_t hi)
      : bdd_(bdd), hi_(hi), memo_(bdd.size()), done_(bdd.size(), false) { }

      uint32_t level(uint32_t x) const { return min(bdd_.var(x), hi_); }

      const big_t&count(uint32_t x)
      {
	    if (done_[x]) return memo_[x];
	    big_t r;
	    if (x == 1 || (x != 0 && bdd_.var(x) >= hi_)) r = big_t::one();
	    else if (x != 0) r = big_add(branch(x, false), branch(x, true));
	    done_[x] = true;
	    memo_[x] = r;
	    return memo_[x];
      }

	/* The count through one branch of X, free levels included. */
      big_t branch(uint32_t x, bool high)
      {
	    uint32_t child = high ? bdd_.hi(x) : bdd_.lo(x);
	    return big_shl(count(child), level(child) - bdd_.var(x) - 1);
      }

    private:
      const bdd_t&bdd_;
      uint32_t hi_;
      vector<big_t> memo_;
      vector<bool> done_;
};

} /* namespace */

Z3_lbool z3_bdd_sample(Z3_context ctx, const vector<Z3_ast>&assertions,
		       const vector<vector<Z3_ast> >&stages,
		       const function<uint32_t()>&rand32,
		       vector<Z3_ast>&values, size_t node_budget)
{
      values.clear();
      try {
	    map<unsigned, Z3_ast> constants;
	    unordered_map<unsigned, bool> seen;
	    for (Z3_ast a : assertions) collect_constants_(ctx, a, constants, seen);

	      /* Lay out the levels: each stage interleaved MSB first, then the
	         auxiliary constants below every semantic level. */
	    map<unsigned, bits_t> levels;
	    vector<uint32_t> stage_end;
	    uint32_t next = 0;
	    auto place = [&](const vector<Z3_ast>&group) {
		  unsigned maxw = 0;
		  for (Z3_ast v : group) {
			unsigned w = const_width_(ctx, v);
			maxw = max(maxw, w);
			levels[Z3_get_ast_id(ctx, v)].assign(w, 0);
		  }
		  for (unsigned bit = maxw; bit-- > 0;)
			for (Z3_ast v : group)
			      if (bit < const_width_(ctx, v))
				    levels[Z3_get_ast_id(ctx, v)][bit] = next++;
	    };
	    for (const auto&stage : stages) {
		  for (Z3_ast v : stage)
			if (levels.count(Z3_get_ast_id(ctx, v))) throw unsupported();
		  place(stage);
		  stage_end.push_back(next);
	    }
	    vector<Z3_ast> aux;
	    for (const auto&item : constants)
		  if (!levels.count(item.first)) aux.push_back(item.second);
	    place(aux);

	    bdd_t bdd(node_budget);
	    blaster_t blaster(ctx, bdd, levels);
	    uint32_t f = 1;
	    for (Z3_ast a : assertions) f = bdd.AND(f, blaster.boolean(a));
	    if (f == 0) return Z3_L_FALSE;

	      /* Draw each stage over its projection, given the earlier ones. */
	    vector<bool> chosen(next, false);
	    uint32_t lo = 0;
	    for (uint32_t hi : stage_end) {
		  counter_t counter(bdd, hi);
		  big_t total = big_shl(counter.count(f), counter.level(f) - lo);
		  big_t r = big_uniform_below(total, rand32);
		  uint32_t cur = lo;
		  while (cur < hi) {
			if (f >= 2 && bdd.var(f) == cur) {
			      big_t low = counter.branch(f, false);
			      bool take = big_cmp(r, low) >= 0;
			      if (take) r = big_sub(r, low);
			      chosen[cur] = take;
			      f = take ? bdd.hi(f) : bdd.lo(f);
			      cur += 1;
			} else {
			      /* Free run up to the next node: low bits of the index. */
			      uint32_t stop = counter.level(f);
			      for (; cur < stop; ++cur) {
				    chosen[cur] = r.bit(0);
				    r = big_shr(r, 1);
			      }
			}
		  }
		  lo = hi;
	    }

	    for (const auto&stage : stages)
		  for (Z3_ast v : stage) {
			const bits_t&bits = levels[Z3_get_ast_id(ctx, v)];
			Z3_sort sort = Z3_get_sort(ctx, v);
			if (Z3_get_sort_kind(ctx, sort) == Z3_BOOL_SORT) {
			      values.push_back(chosen[bits[0]] ? Z3_mk_true(ctx)
							       : Z3_mk_false(ctx));
			      continue;
			}
			string digits;
			for (size_t i = bits.size(); i-- > 0;)
			      digits.push_back(chosen[bits[i]] ? '1' : '0');
			  /* Z3_mk_numeral takes decimal; build it from 64-bit chunks. */
			Z3_ast value = 0;
			for (size_t pos = 0; pos < digits.size();) {
			      size_t take = (digits.size() - pos) % 64;
			      if (!take) take = 64;
			      uint64_t chunk = stoull(digits.substr(pos, take), nullptr, 2);
			      Z3_ast part = Z3_mk_unsigned_int64(ctx, chunk,
				    Z3_mk_bv_sort(ctx, (unsigned)take));
			      value = value ? Z3_mk_concat(ctx, value, part) : part;
			      pos += take;
			}
			values.push_back(Z3_simplify(ctx, value));
		  }
	    return Z3_L_TRUE;
      } catch (const budget_exceeded&) {
      } catch (const unsupported&) {
      }
      values.clear();
      return Z3_L_UNDEF;
}
