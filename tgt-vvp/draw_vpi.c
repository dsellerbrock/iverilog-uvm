/*
 * Copyright (c) 2003-2020 Stephen Williams (steve@icarus.com)
 *
 *    This source code is free software; you can redistribute it
 *    and/or modify it in source code form under the terms of the GNU
 *    General Public License as published by the Free Software
 *    Foundation; either version 2 of the License, or (at your option)
 *    any later version.
 *
 *    This program is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with this program; if not, write to the Free Software
 *    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

# include  "vvp_priv.h"
# include  <string.h>
# include  <stdlib.h>
# include  <assert.h>
# include  <inttypes.h>
# include  "ivl_alloc.h"

struct args_info {
      char*text;
      char*obj_type;
	/* True ('s' or 'u' if this argument is a calculated vec4. */
      char vec_flag;
	/* True if this argument is a calculated string. */
      char str_flag;
	/* True if this argument is a calculated real. */
      char real_flag;
	/* True if this argument is a calculated object. */
      char obj_flag;
	/* Stack position if this argument is a calculated value. */
      unsigned stack;
	/* Expression width: Only used of vec_flag is true. */
      unsigned vec_wid;
      /* A fixed-array word used as the receiver of an in-place string
       * method. The word address is captured on the vec4 stack before the
       * explicit method arguments are evaluated. */
      ivl_signal_t array_word_sig;
      /* Queue/dynamic-array element receiver passed as (container,index). */
      int container_word;
      unsigned index_stack;
      char index_sign;
      unsigned index_width;
      struct args_info *child; /* Arguments can be nested. */
	/* An element of a fixed-array class property (#2475): text holds the
	   &CPV<... prefix and the element index is on the vec4 stack. */
      int cpv_index;
      char cpv_index_sign;
      unsigned cpv_index_width;
};

struct deferred_vpi_call_info {
      long source_id;
      unsigned result;
      ivl_scope_t scope;
      unsigned action_lab;
      unsigned after_lab;
      int is_final;
};

static int is_live_sample_task_(const char*name)
{
      static const char*bases[] = {
	    "$strobe", "$fstrobe", "$monitor", "$fmonitor"
      };
      unsigned idx;
      if (!name) return 0;
      for (idx = 0; idx < sizeof bases / sizeof bases[0]; idx += 1) {
	    size_t len = strlen(bases[idx]);
	    const char*suffix;
	    if (strncmp(name, bases[idx], len) != 0) continue;
	    suffix = name + len;
	    if (!*suffix || ((suffix[0] == 'b' || suffix[0] == 'h'
			       || suffix[0] == 'o') && !suffix[1]))
		  return 1;
      }
      return 0;
}

/*
 * IEEE 1800-2023 37.42 detail 7: the simulator does not evaluate system
 * task and function arguments when it calls them; a value exists only when
 * the application asks for it. Icarus's own modules (vpi/) always read
 * every argument, so their calls keep the eager stack arguments and the
 * .vvp output is unchanged for them. The name list is generated from the
 * vpi/ sources; a builtin missing from it still works, because a lazy
 * handle answers vpi_get_value like a stack handle, only more slowly.
 */
static const char*vpi_builtin_names_[] = {
# include  "vpi_builtin_names.h"
};

static int cmp_name_(const void*a, const void*b)
{
      return strcmp(*(const char*const*)a, *(const char*const*)b);
}

static int vpi_args_are_lazy_(const char*name)
{
      static int sorted = 0;
      size_t count = sizeof vpi_builtin_names_ / sizeof vpi_builtin_names_[0];
      if (!name || strncmp(name, "$ivl_", 5) == 0) return 0;
      if (!sorted) {
	    qsort(vpi_builtin_names_, count, sizeof(char*), cmp_name_);
	    sorted = 1;
      }
      return !bsearch(&name, vpi_builtin_names_, count, sizeof(char*), cmp_name_);
}

/* Annex K object and operator codes used by the lazy argument records. */
enum {
      LAZY_vpiFuncCall = 19, LAZY_vpiOperation = 39, LAZY_vpiPartSelect = 42,
      LAZY_vpiSysFuncCall = 56, LAZY_vpiBitSelect = 106,
      LAZY_vpiIndexedPartSelect = 130
};

struct lazy_op_ {
      char code;
      int vpi_op;
      const char*text;
      int prec;
};

static const struct lazy_op_ lazy_binary_ops_[] = {
      {'p', 43, "**", 80}, {'*', 25, "*", 70}, {'/', 12, "/", 70},
      {'%', 13, "%", 70}, {'+', 24, "+", 60}, {'-', 11, "-", 60},
      {'l', 22, "<<", 50}, {'r', 23, ">>", 50}, {'R', 42, ">>>", 50},
      {'<', 20, "<", 40}, {'L', 21, "<=", 40}, {'>', 18, ">", 40},
      {'G', 19, ">=", 40}, {'e', 14, "==", 35}, {'n', 15, "!=", 35},
      {'E', 16, "===", 35}, {'N', 17, "!==", 35}, {'w', 69, "==?", 35},
      {'W', 70, "!=?", 35}, {'&', 28, "&", 30}, {'^', 30, "^", 28},
      {'X', 31, "~^", 28}, {'|', 29, "|", 26}, {'a', 26, "&&", 20},
      {'o', 27, "||", 18}, {'q', 94, "->", 5}, {'Q', 68, "<->", 5},
      {0, 0, 0, 0}
};

static const struct lazy_op_ lazy_unary_ops_[] = {
      {'-', 1, "-", 90}, {'+', 2, "+", 90}, {'!', 3, "!", 90},
      {'~', 4, "~", 90}, {'&', 5, "&", 90}, {'A', 6, "~&", 90},
      {'|', 7, "|", 90}, {'N', 8, "~|", 90}, {'^', 9, "^", 90},
      {'X', 10, "~^", 90}, {'I', 63, "++", 90}, {'D', 65, "--", 90},
      {'i', 62, "++", 90}, {'d', 64, "--", 90},
      {0, 0, 0, 0}
};

static const struct lazy_op_*lazy_find_op_(const struct lazy_op_*tab, char code)
{
      for (; tab->code; tab += 1)
	    if (tab->code == code) return tab;
      return 0;
}

/* A one-operand select without a base offset only pads or re-signs. */
static ivl_expr_t lazy_strip_pad_(ivl_expr_t expr)
{
      while (ivl_expr_type(expr) == IVL_EX_SELECT && !ivl_expr_oper2(expr)
	     && ivl_expr_oper1(expr))
	    expr = ivl_expr_oper1(expr);
      return expr;
}

static char lazy_value_kind_(ivl_expr_t expr)
{
      switch (ivl_expr_value(expr)) {
	  case IVL_VT_LOGIC:
	  case IVL_VT_BOOL:
	    return ivl_expr_signed(expr) ? 's' : 'u';
	  case IVL_VT_REAL:
	    return 'r';
	  case IVL_VT_STRING:
	    return 'S';
	  default:
	    return 0;
      }
}

/* Growable text for decompilation. */
struct lazy_text_ { char*buf; size_t len, cap; };

static void lazy_puts_(struct lazy_text_*t, const char*s)
{
      size_t n = strlen(s);
      if (t->len + n + 1 > t->cap) {
	    t->cap = (t->len + n + 1) * 2;
	    t->buf = realloc(t->buf, t->cap);
      }
      memcpy(t->buf + t->len, s, n + 1);
      t->len += n;
}

/* 37.59 detail 2: decompile with parentheses only where precedence needs
   them and a single space around each binary operator. Returns the
   precedence of EXPR's top operator, or 0 for a shape it cannot write. */
static int lazy_decompile_(ivl_expr_t expr, struct lazy_text_*t)
{
      char buf[128];
      expr = lazy_strip_pad_(expr);
      switch (ivl_expr_type(expr)) {
	  case IVL_EX_SIGNAL:
	    if (ivl_expr_oper1(expr)) return 0;
	    lazy_puts_(t, ivl_signal_basename(ivl_expr_signal(expr)));
	    return 100;
	  case IVL_EX_NUMBER: {
	    ivl_parameter_t par = ivl_expr_parameter(expr);
	    unsigned wid = ivl_expr_width(expr), idx;
	    const char*bits = ivl_expr_bits(expr);
	    int is_signed = ivl_expr_signed(expr), known = wid <= 64;
	    uint64_t value = 0;
	    if (par) {
		  lazy_puts_(t, ivl_parameter_basename(par));
		  return 100;
	    }
	    for (idx = 0; known && idx < wid; idx += 1) {
		  if (bits[idx] != '0' && bits[idx] != '1') known = 0;
		  else if (bits[idx] == '1') value |= (uint64_t)1 << idx;
	    }
	    if (known && is_signed && wid == 32) {
		  snprintf(buf, sizeof buf, "%" PRId64,
			   (int64_t)(int32_t)(uint32_t)value);
		  lazy_puts_(t, buf);
	    } else if (known) {
		  snprintf(buf, sizeof buf, "%u'%sd%" PRIu64, wid,
			   is_signed ? "s" : "", value);
		  lazy_puts_(t, buf);
	    } else {
		  snprintf(buf, sizeof buf, "%u'%sb", wid, is_signed ? "s" : "");
		  lazy_puts_(t, buf);
		  for (idx = wid; idx > 0; idx -= 1) {
			buf[0] = bits[idx-1];
			buf[1] = 0;
			lazy_puts_(t, buf);
		  }
	    }
	    return 100;
	  }
	  case IVL_EX_SELECT: {
	      /* A constant bit- or part-select of a vector signal, written in
		 the signal's declared range (the offset here is canonical:
		 0 is the LSB). Anything else is left undescribed. */
	    ivl_expr_t base = ivl_expr_oper1(expr);
	    ivl_expr_t off = ivl_expr_oper2(expr);
	    ivl_signal_t sig;
	    long msb, lsb, lo, hi, first;
	    unsigned wid = ivl_expr_width(expr);
	    if (!base || ivl_expr_type(base) != IVL_EX_SIGNAL
		|| ivl_expr_oper1(base) || !off || !wid
		|| !number_is_immediate(off, 32, 0))
		  return 0;
	    sig = ivl_expr_signal(base);
	    if (ivl_signal_packed_dimensions(sig) != 1) return 0;
	    msb = ivl_signal_packed_msb(sig, 0);
	    lsb = ivl_signal_packed_lsb(sig, 0);
	    first = get_number_immediate(off);
	    if (first + (long)wid > (long)ivl_signal_width(sig)) return 0;
	    if (msb >= lsb) {
		  lo = lsb + first;
		  hi = lo + (long)wid - 1;
	    } else {
		  hi = lsb - first;
		  lo = hi - (long)wid + 1;
	    }
	    lazy_puts_(t, ivl_signal_basename(sig));
	    if (wid == 1)
		  snprintf(buf, sizeof buf, "[%ld]", lo);
	    else if (msb >= lsb)
		  snprintf(buf, sizeof buf, "[%ld:%ld]", hi, lo);
	    else
		  snprintf(buf, sizeof buf, "[%ld:%ld]", lo, hi);
	    lazy_puts_(t, buf);
	    return 100;
	  }
	  case IVL_EX_REALNUM:
	    snprintf(buf, sizeof buf, "%.17g", ivl_expr_dvalue(expr));
	    if (!strpbrk(buf, ".eEn")) strcat(buf, ".0");
	    lazy_puts_(t, buf);
	    return 100;
	  case IVL_EX_STRING:
	    lazy_puts_(t, "\"");
	    lazy_puts_(t, ivl_expr_string(expr));
	    lazy_puts_(t, "\"");
	    return 100;
	  case IVL_EX_BINARY: {
	    const struct lazy_op_*op = lazy_find_op_(lazy_binary_ops_,
						     ivl_expr_opcode(expr));
	    struct lazy_text_ l = {0, 0, 0}, r = {0, 0, 0};
	    int lp, rp, ok;
	    if (!op) return 0;
	    lp = lazy_decompile_(ivl_expr_oper1(expr), &l);
	    rp = lazy_decompile_(ivl_expr_oper2(expr), &r);
	    ok = lp && rp;
	    if (ok) {
		    /* Left associative: a right operand of equal
		       precedence needs parentheses. */
		  if (lp < op->prec) lazy_puts_(t, "(");
		  lazy_puts_(t, l.buf);
		  if (lp < op->prec) lazy_puts_(t, ")");
		  lazy_puts_(t, " ");
		  lazy_puts_(t, op->text);
		  lazy_puts_(t, " ");
		  if (rp <= op->prec) lazy_puts_(t, "(");
		  lazy_puts_(t, r.buf);
		  if (rp <= op->prec) lazy_puts_(t, ")");
	    }
	    free(l.buf);
	    free(r.buf);
	    return ok ? op->prec : 0;
	  }
	  case IVL_EX_UNARY: {
	    const struct lazy_op_*op = lazy_find_op_(lazy_unary_ops_,
						     ivl_expr_opcode(expr));
	    struct lazy_text_ a = {0, 0, 0};
	    int ap, post;
	    if (!op) return 0;
	    ap = lazy_decompile_(ivl_expr_oper1(expr), &a);
	    post = op->code == 'i' || op->code == 'd';
	    if (ap) {
		  if (!post) lazy_puts_(t, op->text);
		  if (ap < op->prec) lazy_puts_(t, "(");
		  lazy_puts_(t, a.buf);
		  if (ap < op->prec) lazy_puts_(t, ")");
		  if (post) lazy_puts_(t, op->text);
	    }
	    free(a.buf);
	    return ap ? op->prec : 0;
	  }
	  case IVL_EX_TERNARY: {
	    struct lazy_text_ c = {0, 0, 0}, a = {0, 0, 0}, b = {0, 0, 0};
	    int cp = lazy_decompile_(ivl_expr_oper1(expr), &c);
	    int ap = lazy_decompile_(ivl_expr_oper2(expr), &a);
	    int bp = lazy_decompile_(ivl_expr_oper3(expr), &b);
	    int ok = cp && ap && bp;
	    if (ok) {
		  if (cp <= 10) lazy_puts_(t, "(");
		  lazy_puts_(t, c.buf);
		  if (cp <= 10) lazy_puts_(t, ")");
		  lazy_puts_(t, " ? ");
		  lazy_puts_(t, a.buf);
		  lazy_puts_(t, " : ");
		  lazy_puts_(t, b.buf);
	    }
	    free(c.buf);
	    free(a.buf);
	    free(b.buf);
	    return ok ? 10 : 0;
	  }
	  case IVL_EX_CONCAT: {
	    unsigned idx, rep = ivl_expr_repeat(expr);
	    int ok = 1;
	    if (rep != 1) {
		  snprintf(buf, sizeof buf, "{%u", rep);
		  lazy_puts_(t, buf);
	    }
	    lazy_puts_(t, "{");
	    for (idx = 0; ok && idx < ivl_expr_parms(expr); idx += 1) {
		  if (idx) lazy_puts_(t, ", ");
		  ok = lazy_decompile_(ivl_expr_parm(expr, idx), t) != 0;
	    }
	    lazy_puts_(t, rep != 1 ? "}}" : "}");
	    return ok ? 100 : 0;
	  }
	  case IVL_EX_UFUNC:
	  case IVL_EX_SFUNC: {
	    unsigned idx;
	    int ok = 1;
	    lazy_puts_(t, ivl_expr_type(expr) == IVL_EX_UFUNC
		       ? ivl_scope_basename(ivl_expr_def(expr))
		       : ivl_expr_name(expr));
	    if (ivl_expr_parms(expr)) {
		  lazy_puts_(t, "(");
		  for (idx = 0; ok && idx < ivl_expr_parms(expr); idx += 1) {
			if (idx) lazy_puts_(t, ", ");
			ok = lazy_decompile_(ivl_expr_parm(expr, idx), t) != 0;
		  }
		  lazy_puts_(t, ")");
	    }
	    return ok ? 100 : 0;
	  }
	  default:
	    return 0;
      }
}

static unsigned lazy_expr_count_ = 0;

/* Emit one .vpi_expr record (and the evaluation code it names) for each
   operation node of EXPR, and return the argument text: the root record's
   label, or a leaf's ordinary VPI argument. Returns nil when EXPR has a
   shape the records cannot describe; the caller then evaluates eagerly. */
static char* draw_lazy_expr_(ivl_expr_t expr)
{
      ivl_expr_t node = lazy_strip_pad_(expr);
      struct lazy_text_ text = {0, 0, 0};
	/* Whole unpacked-array operands are ordinary array handles, not values
	   that need an expression thunk. Use the .array label directly. */
	if (ivl_expr_type(node) == IVL_EX_ARRAY) {
	      char buffer[64];
	      snprintf(buffer, sizeof buffer, "v%p", ivl_expr_signal(node));
	      return strdup(buffer);
	}
      char kind = lazy_value_kind_(expr);
      char**ops = calloc(ivl_expr_type(node) == IVL_EX_CONCAT
			 ? ivl_expr_parms(node) + 1 : 3, sizeof(char*));
      unsigned nops = 0, idx, label, thunk, skip;
      int type = LAZY_vpiOperation, op_type = 0;
      char buffer[64];

      if (!kind || !lazy_decompile_(expr, &text)) {
	    free(text.buf);
	    free(ops);
	    return 0;
      }
	/* Leaves keep their ordinary argument handles. */
      buffer[0] = 0;
      if (ivl_expr_type(node) == IVL_EX_SIGNAL
	  && ivl_signal_dimensions(ivl_expr_signal(node)) == 0)
	    snprintf(buffer, sizeof buffer, "v%p_0", ivl_expr_signal(node));
      if (ivl_expr_type(node) == IVL_EX_NUMBER && ivl_expr_parameter(node))
	    snprintf(buffer, sizeof buffer, "P_%p", ivl_expr_parameter(node));
      if (ivl_expr_type(node) == IVL_EX_NUMBER && !ivl_expr_parameter(node)
	  && ivl_expr_width(node) < sizeof buffer - 8) {
	    unsigned bit, wid = ivl_expr_width(node);
	    const char*bits = ivl_expr_bits(node);
	    char*dp = buffer + snprintf(buffer, sizeof buffer, "%u'%sb", wid,
					ivl_expr_signed(node) ? "s" : "");
	    for (bit = wid; bit > 0; bit -= 1) *dp++ = bits[bit-1];
	    *dp = 0;
      }
      if (buffer[0]) {
	    free(text.buf);
	    free(ops);
	    return strdup(buffer);
      }
      switch (ivl_expr_type(node)) {
	  case IVL_EX_REALNUM:
	    type = 7; /* vpiConstant */
	    break;
	  case IVL_EX_STRING: {
	    size_t len = strlen(ivl_expr_string(node)) + 3;
	    char*str = malloc(len);
	    snprintf(str, len, "\"%s\"", ivl_expr_string(node));
	    free(text.buf);
	    free(ops);
	    return str;
	  }
	  case IVL_EX_BINARY:
	    op_type = lazy_find_op_(lazy_binary_ops_, ivl_expr_opcode(node))->vpi_op;
	    ops[nops++] = draw_lazy_expr_(ivl_expr_oper1(node));
	    ops[nops++] = draw_lazy_expr_(ivl_expr_oper2(node));
	    break;
	  case IVL_EX_UNARY:
	    op_type = lazy_find_op_(lazy_unary_ops_, ivl_expr_opcode(node))->vpi_op;
	    ops[nops++] = draw_lazy_expr_(ivl_expr_oper1(node));
	    break;
	  case IVL_EX_TERNARY:
	    op_type = 32; /* vpiConditionOp */
	    ops[nops++] = draw_lazy_expr_(ivl_expr_oper1(node));
	    ops[nops++] = draw_lazy_expr_(ivl_expr_oper2(node));
	    ops[nops++] = draw_lazy_expr_(ivl_expr_oper3(node));
	    break;
	  case IVL_EX_CONCAT:
	    op_type = ivl_expr_repeat(node) != 1 ? 34 : 33;
	    if (op_type == 34) {
		  unsigned bit, rep = ivl_expr_repeat(node);
		  char*dp = buffer + snprintf(buffer, sizeof buffer, "32'sb");
		  for (bit = 32; bit > 0; bit -= 1)
			*dp++ = (rep >> (bit - 1)) & 1 ? '1' : '0';
		  *dp = 0;
		  ops[nops++] = strdup(buffer);
		  buffer[0] = 0;
	    }
	    for (idx = 0; idx < ivl_expr_parms(node); idx += 1)
		  ops[nops++] = draw_lazy_expr_(ivl_expr_parm(node, idx));
	    break;
	  case IVL_EX_UFUNC:
	    type = LAZY_vpiFuncCall;
	    break;
	  case IVL_EX_SFUNC:
	    type = LAZY_vpiSysFuncCall;
	    break;
	  case IVL_EX_SELECT:
	    type = ivl_expr_width(node) == 1 ? LAZY_vpiBitSelect
		 : number_is_immediate(ivl_expr_oper2(node), 64, 0)
		 ? LAZY_vpiPartSelect : LAZY_vpiIndexedPartSelect;
	    break;
	  default:
	    break;
      }
	/* An operand that cannot be described leaves the node opaque. */
      for (idx = 0; idx < nops; idx += 1)
	    if (!ops[idx]) {
		  for (idx = 0; idx < nops; idx += 1) free(ops[idx]);
		  nops = 0;
		  break;
	    }

      label = lazy_expr_count_++;
      thunk = local_count++;
      skip = local_count++;
      fprintf(vvp_out, "XE_%u .vpi_expr %d, %d, %u, \"%c\", T_%u.%u, \"",
	      label, type, op_type, ivl_expr_width(expr), kind,
	      thread_count, thunk);
      for (idx = 0; idx < text.len; idx += 1) {
	    if (text.buf[idx] == '"' || text.buf[idx] == '\\')
		  fputc('\\', vvp_out);
	    fputc(text.buf[idx], vvp_out);
      }
      fprintf(vvp_out, "\"");
      for (idx = 0; idx < nops; idx += 1) {
	    fprintf(vvp_out, ", %s", ops[idx]);
	    free(ops[idx]);
      }
      fprintf(vvp_out, ";\n");
      free(text.buf);
      free(ops);
	/* The evaluation code sits out of line: the thread jumps over it. */
      fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, skip);
      fprintf(vvp_out, "T_%u.%u ;\n", thread_count, thunk);
      switch (kind) {
	  case 'r':
	    draw_eval_real(expr);
	    break;
	  case 'S':
	    draw_eval_string(expr);
	    break;
	  default:
	    draw_eval_vec4(expr);
	    break;
      }
      fprintf(vvp_out, "    %%end;\n");
      fprintf(vvp_out, "T_%u.%u ;\n", thread_count, skip);
      snprintf(buffer, sizeof buffer, "XE_%u", label);
      return strdup(buffer);
}

/* The functor label whose output is the driver named NAME in SCOPE (a
   logic device or LPM), or nil. An elided BUFZ is represented by its
   input. The runtime resolves this label leniently: a driver that is not
   drawn under it only loses its value-change callbacks. */
static char* contassign_driver_label_(ivl_scope_t scope, const char*name)
{
      char buf[64];
      unsigned idx, pdx;

      if (!name) return 0;
      for (idx = 0; idx < ivl_scope_logs(scope); idx += 1) {
	    ivl_net_logic_t lptr = ivl_scope_log(scope, idx);
	    ivl_nexus_t out;
	    if (strcmp(ivl_logic_basename(lptr), name) != 0) continue;
	    out = ivl_logic_pin(lptr, 0);
	    if (ivl_logic_type(lptr) == IVL_LO_BUFZ)
		  for (pdx = 0; pdx < ivl_nexus_ptrs(out); pdx += 1) {
			ivl_nexus_ptr_t nptr = ivl_nexus_ptr(out, pdx);
			const char*in;
			if (ivl_nexus_ptr_log(nptr) != lptr
			    || ivl_nexus_ptr_pin(nptr) != 0) continue;
			if (!can_elide_bufz(lptr, nptr)) break;
			if (bufz_input_is_var(lptr)) {
			      snprintf(buf, sizeof buf, "S_%p", lptr);
			      return strdup(buf);
			}
			in = draw_net_input(ivl_logic_pin(lptr, 1));
			  /* A literal input never changes. */
			return in[0] == 'C' && strchr(in, '<') ? 0 : strdup(in);
		  }
	    snprintf(buf, sizeof buf, "L_%p", lptr);
	    return strdup(buf);
      }
      for (idx = 0; idx < ivl_scope_lpms(scope); idx += 1) {
	    ivl_lpm_t lpm = ivl_scope_lpm(scope, idx);
	    if (strcmp(ivl_lpm_basename(lpm), name) != 0) continue;
	    snprintf(buf, sizeof buf, "L_%p", lpm);
	    return strdup(buf);
      }
      return 0;
}

static unsigned contassign_count_ = 0;

/* Pseudo-thread numbers for evaluation code that no thread runs. They
   start far above any real thread, so the real threads keep their labels. */
static unsigned static_thunk_count_ = 1u << 30;

/* Emit the VPI objects of SCOPE that describe source expressions: a
   .vpi_contassign record for each continuous assignment (IEEE 1800-2023
   37.47), a .vpi_param_expr record for each parameter whose default is
   not simply its value, and a .vpi_defparam record for each defparam
   (37.28). Their expressions are .vpi_expr handles whose evaluation code
   no thread runs. */
void draw_vpi_objects_in_scope(ivl_scope_t scope)
{
      unsigned idx, save_local = local_count, save_thread = thread_count;
      unsigned nports = ivl_scope_type(scope) == IVL_SCT_MODULE
	    ? ivl_scope_mod_module_ports(scope) : 0;
      int any = ivl_scope_contassigns(scope) || ivl_scope_defparams(scope);

      for (idx = 0; !any && idx < ivl_scope_params(scope); idx += 1)
	    any = ivl_parameter_default_expr(ivl_scope_param(scope, idx)) != 0;
	/* An interface port: the instance it is bound to, and the modport
	   it selects (37.14 detail 5, 37.15). These need no expression code. */
      for (idx = 0; idx < nports; idx += 1) {
	    const char*modport;
	    ivl_scope_t iface = ivl_scope_mod_module_port_iface(scope, idx,
								 &modport);
	    if (iface && modport)
		  fprintf(vvp_out, " .vpi_port_conn %u, 2, S_%p, \"%s\";\n",
			  idx, iface, modport);
	    else if (iface)
		  fprintf(vvp_out, " .vpi_port_conn %u, 2, S_%p;\n", idx, iface);
      }
      for (idx = 0; !any && idx < nports; idx += 1)
	    any = ivl_scope_mod_module_port_highconn(scope, idx) != 0
		  || ivl_scope_mod_module_port_lowconn(scope, idx) != 0;
      if (!any) return;
      thread_count = static_thunk_count_++;
      local_count = 0;
      for (idx = 0; idx < ivl_scope_params(scope); idx += 1) {
	    ivl_parameter_t par = ivl_scope_param(scope, idx);
	    ivl_expr_t def = ivl_parameter_default_expr(par);
	    char*text = def ? draw_lazy_expr_(def) : 0;
	    if (text)
		  fprintf(vvp_out, " .vpi_param_expr P_%p, %s;\n", par, text);
	    free(text);
      }
	/* The actual of each connected port (vpiHighConn, IEEE 1800-2023
	   37.14). vvp finds the port's own signal, its vpiLowConn, by name. */
      for (idx = 0; idx < nports; idx += 1) {
	    ivl_expr_t high = ivl_scope_mod_module_port_highconn(scope, idx);
	    char*text = high ? draw_lazy_expr_(high) : 0;
	    if (text)
		  fprintf(vvp_out, " .vpi_port_conn %u, 1, %s;\n", idx, text);
	    free(text);
	      /* A port expression formal is its vpiLowConn (23.2.2.1). */
	    ivl_expr_t low = ivl_scope_mod_module_port_lowconn(scope, idx);
	    text = low ? draw_lazy_expr_(low) : 0;
	    if (text)
		  fprintf(vvp_out, " .vpi_port_conn %u, 4, %s;\n", idx, text);
	    free(text);
      }
      for (idx = 0; idx < ivl_scope_defparams(scope); idx += 1) {
	    ivl_defparam_t dp = ivl_scope_defparam(scope, idx);
	    char*text = draw_lazy_expr_(ivl_defparam_rhs(dp));
	    if (text)
		  fprintf(vvp_out, " .vpi_defparam P_%p, %u, %u, %s;\n",
			  ivl_defparam_parameter(dp),
			  ivl_file_table_index(ivl_defparam_file(dp)),
			  ivl_defparam_lineno(dp), text);
	    free(text);
      }
      for (idx = 0; idx < ivl_scope_contassigns(scope); idx += 1) {
	    ivl_contassign_t ca = ivl_scope_contassign(scope, idx);
	    char*lhs = ivl_contassign_lval(ca)
		  ? draw_lazy_expr_(ivl_contassign_lval(ca)) : 0;
	    char*rhs = draw_lazy_expr_(ivl_contassign_rval(ca));
	    char*drv = rhs ? contassign_driver_label_(scope,
				ivl_contassign_driver(ca)) : 0;
	    if (rhs) {
		  fprintf(vvp_out, "CA_%u .vpi_contassign %d, %d, %d, %u, %u, "
			  "\"%s\"", contassign_count_++,
			  (ivl_contassign_net_decl(ca) ? 1 : 0) | (lhs ? 2 : 0),
			  1 << ivl_contassign_drive0(ca),
			  1 << ivl_contassign_drive1(ca),
			  ivl_file_table_index(ivl_contassign_file(ca)),
			  ivl_contassign_lineno(ca), drv ? drv : "");
		  if (lhs) fprintf(vvp_out, ", %s", lhs);
		  fprintf(vvp_out, ", %s;\n", rhs);
	    }
	    free(lhs);
	    free(rhs);
	    free(drv);
      }
      thread_count = save_thread;
      local_count = save_local;
}

static int is_mutating_string_method_(const char*name)
{
      return name && (!strcmp(name, "$ivl_string_method$itoa")
                   || !strcmp(name, "$ivl_string_method$hextoa")
                   || !strcmp(name, "$ivl_string_method$octtoa")
                   || !strcmp(name, "$ivl_string_method$bintoa")
                   || !strcmp(name, "$ivl_string_method$realtoa")
                   || !strcmp(name, "$ivl_string_method$putc"));
}

static const char* magic_sfuncs[] = {
      "$time",
      "$stime",
      "$realtime",
      "$simtime",
      0
};
static unsigned char warned_unsupported_vpi_arg_type[32];

static ivl_signal_t expr_signal_base_(ivl_expr_t expr)
{
      if (!expr)
            return 0;

      switch (ivl_expr_type(expr)) {
          case IVL_EX_SIGNAL:
          case IVL_EX_ARRAY:
          case IVL_EX_PROPERTY:
            return ivl_expr_signal(expr);

          case IVL_EX_SELECT:
            return expr_signal_base_(ivl_expr_oper1(expr));

          default:
            return 0;
      }
}

static char* vpi_class_arg_type_label_(ivl_expr_t expr)
{
      ivl_type_t net_type = ivl_expr_net_type(expr);
      char buffer[64];
      ivl_signal_t sig;

      if (!net_type) {
            sig = expr_signal_base_(expr);
            if (sig)
                  net_type = ivl_signal_net_type(sig);
      }

      if (!net_type)
            return 0;

      if (ivl_type_base(net_type) != IVL_VT_CLASS)
            return 0;

      draw_class_in_scope(net_type);
      snprintf(buffer, sizeof buffer, "C%p", net_type);
      return strdup(buffer);
}

static int expr_is_class_like_(ivl_expr_t expr)
{
      ivl_type_t net_type = ivl_expr_net_type(expr);
      ivl_signal_t sig;

	/* A selected unpacked aggregate is an object-backed r-value even when
	 * nested associative dimensions hide its leaf type from the root signal. */
      if (ivl_expr_type(expr) == IVL_EX_SELECT
	  && ivl_expr_value(expr) == IVL_VT_NO_TYPE)
	    return 1;

	/* The expression's own VALUE type is authoritative when it is
	 * a definite non-class kind: a chained element select like
	 * c.dd[0][1] evaluates to an int even though its ROOT signal
	 * is class-typed. Falling back to the root signal's type here
	 * used to classify such reads as objects — $display printed
	 * "null" for perfectly scalar values. */
      if (!net_type) {
            switch (ivl_expr_value(expr)) {
                case IVL_VT_BOOL:
                case IVL_VT_LOGIC:
                case IVL_VT_REAL:
                case IVL_VT_STRING:
                  return 0;
                default:
                  break;
            }
      }

      if (!net_type) {
            sig = expr_signal_base_(expr);
            if (sig)
                  net_type = ivl_signal_net_type(sig);
      }

      if (net_type
          && (ivl_type_base(net_type) == IVL_VT_CLASS
              || (ivl_type_base(net_type) == IVL_VT_NO_TYPE
                  && ivl_type_properties(net_type) > 0)))
            return 1;

	/* An element select of an object-backed dynamic array or queue
	   (e.g. `da[i]` where the element is a class handle or an
	   object-backed unpacked struct) is itself an object and must be
	   passed to %p / $display as an object handle, not read as a garbage
	   vector. The base signal's type is the DARRAY/QUEUE container, so the
	   check above (which matches a struct-array signal whose net_type IS
	   the element) does not fire. The whole container reads with value
	   IVL_VT_DARRAY/QUEUE and is handled elsewhere; only an element select
	   (value NO_TYPE or CLASS) is class-like here. */
      if (net_type
          && (ivl_type_base(net_type) == IVL_VT_DARRAY
              || ivl_type_base(net_type) == IVL_VT_QUEUE)) {
            ivl_type_t et = ivl_type_element(net_type);
            int ev = ivl_expr_value(expr);
            if (et
                && (ivl_type_base(et) == IVL_VT_CLASS
                    || (ivl_type_base(et) == IVL_VT_NO_TYPE
                        && ivl_type_properties(et) > 0))
                && (ev == IVL_VT_CLASS || ev == IVL_VT_NO_TYPE))
                  return 1;
      }

      return ivl_expr_value(expr) == IVL_VT_CLASS;
}

static int is_magic_sfunc(const char*name)
{
      int idx;
      for (idx = 0 ;  magic_sfuncs[idx] ;  idx += 1)
	    if (strcmp(magic_sfuncs[idx],name) == 0)
		  return 1;

      return 0;
}

static int is_fixed_memory_word(ivl_expr_t net)
{
      ivl_signal_t sig;

      if (ivl_expr_type(net) != IVL_EX_SIGNAL
          && ivl_expr_type(net) != IVL_EX_PROPERTY)
	    return 0;

      sig = expr_signal_base_(net);
      if (!sig)
            return 0;

      if (ivl_signal_dimensions(sig) == 0)
	    return 1;

      if (ivl_signal_type(sig) == IVL_SIT_REG)
	    return 0;

      if (number_is_immediate(ivl_expr_oper1(net), IMM_WID, 0))
	    return 1;

      return 0;
}

/* L33: walk a class-property chain like foo.bar.baz down to its root
 * signal, collecting each hop's property index in root-to-leaf order
 * (so for foo.bar.baz: [bar's idx, baz's idx]).
 *
 * ivl_expr_signal() on a PROPERTY node is a shortcut elaboration only
 * takes for a single, non-chained property access: it is set when this
 * property's base is directly the root signal AND nothing further
 * chains off of the parent expression. Once a property access is used
 * as the BASE of another property access (foo.bar.baz), elaboration
 * builds the intermediate node ("foo.bar") through the generic
 * base-expression path instead, even though foo really is a plain
 * signal -- ivl_expr_signal() on THAT node is null and ivl_expr_oper2()
 * gives a genuine IVL_EX_SIGNAL/IVL_EX_ARRAY expression rather than
 * another IVL_EX_PROPERTY. So the chain can terminate two ways: the
 * shortcut (checked first), or a plain-signal base (checked second,
 * below). Established empirically against a 2-level (obj.inner.s)
 * reducer; see evidence/campaign-20260908/dd046/c3.sv.
 *
 * Returns 0 (chain not usable, caller should fall back to the rvalue-only
 * path) if any hop -- leaf or intermediate -- is itself array-indexed
 * (ivl_expr_oper1() set, e.g. obj.arr[i].s or obj.arr[i].inner.s), or if
 * a hop's base is anything other than a plain signal or another
 * property (a method-call result, say): the runtime handle this feeds
 * only understands a straight-line chain of scalar object/string
 * properties. That scoping choice is deliberate; those are separate,
 * untested code paths left for a future pass. */
static int collect_property_chain_(ivl_expr_t expr, ivl_signal_t*sig,
                                    long*idx, unsigned*count, unsigned max,
                                    int leaf_index_ok)
{
      if (ivl_expr_type(expr) != IVL_EX_PROPERTY)
            return 0;
      if (ivl_expr_oper1(expr) && !leaf_index_ok)
            return 0;

      if (ivl_expr_signal(expr)) {
            *sig = ivl_expr_signal(expr);
      } else {
            ivl_expr_t base = ivl_expr_oper2(expr);
            if (!base)
                  return 0;
            switch (ivl_expr_type(base)) {
                case IVL_EX_SIGNAL:
                case IVL_EX_ARRAY:
                      /* A word-indexed array-of-objects base (e.g.
                         fixed[0].id, arr[1].tag) carries its index via
                         ivl_expr_oper1(base) -- per ivl_target.h's
                         IVL_EX_SIGNAL docs, "[the array] is addressed by
                         the expression returned by the ivl_expr_oper1
                         function". Silently ignoring that index and
                         treating the whole array as if it were the
                         scalar word this chain hardcodes ("_0" in the
                         emitted &CPS/&CPV label) resolved to an
                         unrelated/nonexistent functor at runtime
                         (observed: vvp's "unresolved functor stub"
                         diagnostic and the read coming back X instead of
                         the real value -- ivtest sv_array_port_object_event
                         and sv_cast_container_task_failure both caught
                         this). Out of scope, same as an array-indexed
                         property hop above: reject and let the caller
                         fall back to the rvalue-only path, which resolves
                         the word correctly via the generic machinery. */
                      if (ivl_expr_oper1(base))
                            return 0;
                      *sig = ivl_expr_signal(base);
                      if (!*sig)
                            return 0;
                      break;
                case IVL_EX_PROPERTY:
                      if (!collect_property_chain_(base, sig, idx, count, max, 0))
                            return 0;
                      break;
                default:
                      return 0;
            }
      }

      if (*count >= max)
            return 0;
      idx[(*count)++] = ivl_expr_property_idx(expr);
      return 1;
}

/* L33/L34: a writable &CPS (string) or &CPV (integral) handle on the class
   property PROP (a chain collect_property_chain_() accepts), so a system
   task's output updates the property rather than a discarded temporary.
   #2475, #2745: with ELEM, the handle names that element of a fixed-array,
   dynamic-array or queue property; the index is evaluated now, onto the
   vec4 stack, and read when the handle is used, and the runtime handle
   tells slots from container elements by the property's storage kind.
   VALUE is the argument itself. For &CPV it gives the width and the flags:
   bit 0 signed, bit 1 two-state (a missing element then reads 0, not X;
   IEEE 1800-2023 7.4.6). A task that samples its arguments after the call
   ($monitor, $strobe) cannot use an element handle, because the index it
   reads is a vec4 stack entry popped when the call returns. */
static int cpv_elem_live_sample_ = 0;
static int draw_cpv_arg_(struct args_info*result, ivl_expr_t prop,
                         ivl_expr_t elem, ivl_expr_t value)
{
      char buffer[4096];
      ivl_signal_t root_sig = 0;
      long chain[16];
      unsigned chain_len = 0, idx;
      int n;

      if (elem && cpv_elem_live_sample_)
            return 0;
      if (!collect_property_chain_(prop, &root_sig, chain, &chain_len,
                                   sizeof chain/sizeof chain[0], elem != 0))
            return 0;

      if (ivl_expr_value(value) == IVL_VT_STRING)
            n = snprintf(buffer, sizeof buffer, "&CPS<v%p_0", (void*)root_sig);
      else
            n = snprintf(buffer, sizeof buffer, "&CPV<v%p_0, %u, %u",
                         (void*)root_sig, ivl_expr_width(value),
                         (ivl_expr_signed(value) ? 1 : 0)
                         | (ivl_expr_value(value) == IVL_VT_BOOL ? 2 : 0));
      for (idx = 0 ; idx < chain_len && n > 0 && (size_t)n < sizeof buffer
           ; idx += 1)
            n += snprintf(buffer+n, sizeof buffer-n, ", %ld", chain[idx]);
      if (elem) {
            draw_eval_vec4(elem);
            result->cpv_index = 1;
            result->cpv_index_sign = ivl_expr_signed(elem) ? 's' : 'u';
            result->cpv_index_width = ivl_expr_width(elem);
      } else {
            snprintf(buffer+n, sizeof buffer-n, ">");
      }
      result->text = strdup(buffer);
      return 1;
}

static int get_vpi_taskfunc_signal_arg(struct args_info *result,
                                       ivl_expr_t expr)
{
      char buffer[4096];
      ivl_signal_t sig;
      int class_like;

      switch (ivl_expr_type(expr)) {
	  case IVL_EX_SIGNAL:
	  case IVL_EX_PROPERTY:
	      /* L33: for a string-typed class property, try the chain-walk
	         FIRST, before the expr_signal_base_()-based logic below --
	         that helper returns null for any nested property expression
	         (see its own IVL_EX_PROPERTY case, and the ivl_target.h docs
	         for IVL_EX_PROPERTY), which would otherwise bail out of this
	         whole function via the "if (!sig) return 0" a few lines down
	         before a nested obj.inner.s ever got a chance to be handled.
	         Emits &CPS<vSIG_0,pidx...> so the runtime handle supports
	         both vpi_get_value and vpi_put_value on the specific string
	         property. A chain with an array-indexed hop anywhere in it
	         isn't handled here; collect_property_chain_() says so and
	         this falls through to the ordinary signal-base logic below,
	         which itself falls through to the rvalue-only fallback for
	         a nested/array-indexed string property. #2745: an element of
	         a fixed-array, dynamic-array or queue string property is
	         addressed like its integral sibling below. */
	      if (ivl_expr_type(expr) == IVL_EX_PROPERTY
		  && ivl_expr_value(expr) == IVL_VT_STRING) {
		    ivl_expr_t elem = (property_selects_fixed_uarray_slot_(expr)
				       || property_is_indexed_darray_expr_(expr)
				       || property_is_indexed_queue_expr_(expr))
			  ? ivl_expr_oper1(expr) : 0;
		    if (draw_cpv_arg_(result, expr, elem, expr))
			  return 1;
	      }
	      /* L34: integral class properties need the same property-aware
	         VPI lvalue treatment as strings (L33), for the same reason --
	         $value$plusargs("N=%d", obj.inner.n) must update obj.inner.n
	         rather than a discarded vec4 stack temporary, and a nested
	         chain hits the identical expr_signal_base_()==null bailout a
	         few lines down before ever reaching the old direct-only CPV
	         check below. Tried first, same as the string case above; a
	         chain collect_property_chain_() can't take (array-indexed hop,
	         non-signal/non-property base) falls through to the old
	         direct-only check below, which itself falls through further to
	         the M14 rvalue-only fallback for anything neither handles. */
	      if (ivl_expr_type(expr) == IVL_EX_PROPERTY
		  && (ivl_expr_value(expr) == IVL_VT_LOGIC
		      || ivl_expr_value(expr) == IVL_VT_BOOL)) {
		    /* #2475: an element of a fixed-array property (c.arr[i])
		       is just as writable. #2745: so is an element of a
		       dynamic-array or queue property (c.dq[i], c.q[i]). */
		    ivl_expr_t elem = (property_selects_fixed_uarray_slot_(expr)
				       || property_is_indexed_darray_expr_(expr)
				       || property_is_indexed_queue_expr_(expr))
			  ? ivl_expr_oper1(expr) : 0;
		    if (draw_cpv_arg_(result, expr, elem, expr))
			  return 1;
	      }
	      sig = expr_signal_base_(expr);
	      if (!sig)
		    return 0;
	      class_like = expr_is_class_like_(expr);
	      /* For a class-typed property access (e.g., $cast(dst, this.m_parent)),
	         the base signal handle is the CONTAINING object, not the property
	         value. Fall back to draw_eval_object so the property is loaded at
	         runtime and pushed onto the obj_stack. */
	      if (class_like && ivl_expr_type(expr) == IVL_EX_PROPERTY)
		    return 0;
	      /* Integral (L34) and string (L33) class-property chains are both
	         tried above, before this point, so reaching here with either
	         value type means collect_property_chain_() rejected the chain
	         (an array-indexed hop somewhere in it, or a base that's
	         neither a plain signal nor another property) -- fall through
	         to the M14 rvalue-only path below (draw_eval_string /
	         draw_eval_vec4) for both. */
	      /* M14: A class data property has no standalone VPI signal
	         handle — its value lives inside the containing object, and
	         `sig` here is that object. The signal-handle fast path
	         below is only valid for real signals, so always fall back
	         to evaluating the property into a temp. Previously a
	         property whose width happened to equal the object-handle
	         width (notably ANY 1-bit bit/logic property) slipped past
	         the width-mismatch guard below and passed the OBJECT handle
	         to the system task, which printed garbage. */
	      if (ivl_expr_type(expr) == IVL_EX_PROPERTY)
		    return 0;
	      /* If the signal node is narrower than the signal itself,
	         then this is a part select so I'm going to need to
	         evaluate the expression.

	         Also, if the signedness of the expression is different
	         from the signedness of the signal. This could be
	         caused by a $signed or $unsigned system function.

	         If I don't need to do any evaluating, then skip it as
	         I'll be passing the handle to the signal itself. */
	    if ((ivl_expr_width(expr) !=
	         ivl_signal_width(sig)) &&
	         ivl_expr_value(expr) != IVL_VT_DARRAY &&
	         !class_like) {
		    /* This can happen for class/property wrapper expressions.
		       Fall back instead of asserting. */
		  return 0;

	    } else if (signal_is_return_value(sig)) {
		    /* If the signal is the return value of a function,
		       then this can't be handled as a true signal, so
		       fall back on general expression processing. */
		  return 0;

	    } else if (!class_like &&
	               ivl_expr_signed(expr) !=
	               ivl_signal_signed(sig)) {
		  return 0;
	    } else if (is_fixed_memory_word(expr)) {
		  /* This is a word of a non-array, or a word of a net
		     array, so we can address the word directly. */
		  unsigned use_word = 0;
		  ivl_expr_t word_ex = ivl_expr_oper1(expr);
		  if (word_ex) {
			  /* Some array select have been evaluated. */
			if (number_is_immediate(word_ex,IMM_WID, 0)) {
			      assert(! number_is_unknown(word_ex));
			      use_word = get_number_immediate(word_ex);
			      word_ex = 0;
			}
		  }
		  if (word_ex) return 0;

		  assert(word_ex == 0);
		  snprintf(buffer, sizeof buffer, "v%p_%u", sig, use_word);
		  result->text = strdup(buffer);
		  return 1;

	    } else {
		  /* What's left, this is the work of a var array.
		     Create the right code to handle it. */
		  unsigned use_word = 0;
		  unsigned use_word_defined = 0;
		  ivl_expr_t word_ex = ivl_expr_oper1(expr);
		  if (word_ex) {
			  /* Some array select have been evaluated. */
			if (number_is_immediate(word_ex, IMM_WID, 0)) {
			      assert(! number_is_unknown(word_ex));
			      use_word = get_number_immediate(word_ex);
			      use_word_defined = 1;
			      word_ex = 0;
			}
		  }
		  if (word_ex && (ivl_expr_type(word_ex)==IVL_EX_SIGNAL ||
		                  ivl_expr_type(word_ex)==IVL_EX_SELECT)) {
			  /* Special case: the index is a signal/select. */
			result->child = calloc(1, sizeof(struct args_info));
			if (get_vpi_taskfunc_signal_arg(result->child,
			                                word_ex)) {
			      snprintf(buffer, sizeof buffer, "&A<v%p, %s >",
			               sig, result->child->text);
			      free(result->child->text);
			} else {
			      free(result->child);
			      result->child = NULL;
			      return 0;
			}
		  } else if (word_ex) {
			/* Fallback case: Give up and evaluate expression. */
			return 0;

		  } else {
			assert(use_word_defined);
			snprintf(buffer, sizeof buffer, "&A<v%p, %u>",
			         sig, use_word);
		  }
		  result->text = strdup(buffer);
		  return 1;
	    }

	  case IVL_EX_SELECT: {
	    ivl_expr_t vexpr = ivl_expr_oper1(expr);
	    ivl_expr_t bexpr;
	    ivl_expr_t wexpr;
	    int indexed = ivl_expr_sel_type(expr) != IVL_SEL_OTHER;

	    /* #2745: an element of a dynamic-array or queue property reached
	     * through a nested chain (c.in.q[i]) arrives as a select over the
	     * unindexed container property, with the element index as its
	     * operand. A keyed (associative) container is not one. */
	    if (vexpr && ivl_expr_type(vexpr) == IVL_EX_PROPERTY
		&& !ivl_expr_oper1(vexpr) && ivl_expr_oper2(expr)
		&& (ivl_expr_value(expr) == IVL_VT_LOGIC
		    || ivl_expr_value(expr) == IVL_VT_BOOL
		    || ivl_expr_value(expr) == IVL_VT_STRING)
		&& expr_is_dynarray_container_(vexpr)
		&& !(receiver_container_type_(vexpr)
		     && ivl_type_queue_assoc_compat(receiver_container_type_(vexpr)))
		&& draw_cpv_arg_(result, vexpr, ivl_expr_oper2(expr), expr))
		  return 1;

	    /* An aggregate select is a value, not a signal handle with one
	     * array index. Let the object evaluator preserve every select. */
	    if (ivl_expr_value(expr) == IVL_VT_NO_TYPE)
	      return 0;

	    /* A direct VPI signal select bypasses vec4 evaluation, so it cannot
	     * apply the 2-state conversion required by a bit-valued result. */
	    if (ivl_expr_value(expr) == IVL_VT_BOOL)
	      return 0;

	    assert(vexpr);

	      /* This code is only for signals or selects. */
	    if (ivl_expr_type(vexpr) != IVL_EX_SIGNAL &&
	        ivl_expr_type(vexpr) != IVL_EX_SELECT) return 0;

	      /* If the expression is a substring expression, then
		 the xPV method of passing the argument will not work
		 and we have to resort to the default method. */
	    if (ivl_expr_value(vexpr) == IVL_VT_STRING)
		  return 0;

	      /* If the sub-expression is a DARRAY, then this select
		 is a dynamic-array word select. Handle that
		 elsewhere. */
	    if (ivl_expr_value(vexpr) == IVL_VT_DARRAY)
		  return 0;

	      /* Part select is always unsigned. If the expression is signed
	       * fallback. */
	    if (ivl_expr_signed(expr))
		  return 0;

	      /* The signal is part of an array. */
	      /* Add &APV<> code here when it is finished. */
	    bexpr = ivl_expr_oper2(expr);

              /* This is a pad operation. */
	    if (!bexpr) return 0;

	    wexpr = ivl_expr_oper1(vexpr);

	      /* If vexpr has an operand, then that operand is a word
		 index and we are taking a select from an array
		 word. This would come up in expressions like
		 "array[<word>][<part>]" where wexpr is <word> */
	    if (wexpr && number_is_immediate(wexpr, 64, 1)
		&& number_is_immediate(bexpr, 64, 1)) {
		  assert(! number_is_unknown(bexpr));
		  assert(! number_is_unknown(wexpr));
		  snprintf(buffer, sizeof buffer, "&APV<v%p, %ld, %ld, %u>",
			   ivl_expr_signal(vexpr),
			   get_number_immediate(wexpr),
			   get_number_immediate(bexpr),
			   ivl_expr_width(expr));

	    } else if (wexpr) {
		  return 0;

	      /* This is a constant bit/part select. */
	    } else if (number_is_immediate(bexpr, 64, 1)) {
		  assert(! number_is_unknown(bexpr));
		  if (indexed)
			snprintf(buffer, sizeof buffer,
			         "&PV<v%p_0, %" PRId64 ", %u, 1>",
			         ivl_expr_signal(vexpr),
			         (int64_t)get_number_immediate64(bexpr),
			         ivl_expr_width(expr));
		  else
			snprintf(buffer, sizeof buffer, "&PV<v%p_0, %" PRId64 ", %u>",
			         ivl_expr_signal(vexpr),
			         (int64_t)get_number_immediate64(bexpr),
			         ivl_expr_width(expr));

	      /* This is an indexed bit/part select. */
	    } else if (ivl_expr_type(bexpr) == IVL_EX_SIGNAL ||
	               ivl_expr_type(bexpr) == IVL_EX_SELECT) {
		    /* Special case: the base is a signal/select. */
		  result->child = calloc(1, sizeof(struct args_info));
		  if (get_vpi_taskfunc_signal_arg(result->child, bexpr)) {
			if (indexed)
			      snprintf(buffer, sizeof buffer,
			               "&PV<v%p_0, %s, %u, 1>",
			               ivl_expr_signal(vexpr), result->child->text,
			               ivl_expr_width(expr));
			else
			      snprintf(buffer, sizeof buffer,
			               "&PV<v%p_0, %s, %u>",
			               ivl_expr_signal(vexpr), result->child->text,
			               ivl_expr_width(expr));
			free(result->child->text);
		  } else {
			free(result->child);
			result->child = NULL;
			return 0;
		  }
	    } else {
		    /* Fallback case: Punt and let caller handle it. */
		  return 0;
	    }
	    result->text = strdup(buffer);
	    return 1;
	  }

	  default:
	    return 0;
      }
}

/*
 * $cast(dest, src) where dest is a class variable or a class-typed
 * property (IEEE 1800-2017 6.24.2). The generic VPI path cannot serve
 * this: the destination reaches the systf as a handle to the CONTAINING
 * class object rather than to the property, so the runtime checked the
 * wrong type and wrote to the wrong place. This lowers the whole thing
 * to opcodes instead.
 *
 * Three things it must get right, all of which the previous shortcut got
 * wrong, silently:
 *
 *   * the TYPE CHECK. The old code emitted an unconditional store and an
 *     unconditional 1, so a cast between unrelated classes reported
 *     success and installed the incompatible handle. 6.24.2 requires 0
 *     and the destination left alone.
 *   * the ELEMENT INDEX of a fixed unpacked array property. The store
 *     was emitted with a literal index selector of 0, so
 *     `$cast(p.arr[2], h)' wrote p.arr[0].
 *   * an element of a CONTAINER property -- a queue, dynamic array or
 *     associative array held in the property. The slot holds the
 *     container, not the element, so storing into the slot REPLACED the
 *     whole container with the handle: `$cast(p.q[1], h)' left p.q with
 *     size 0. (Same shape as M1C-3, on the one path that did not go
 *     through the assignment lowering.)
 *
 * Returns 0 for any destination shape it does not handle, leaving the
 * caller to fall back to the generic path.
 *
 * result_width == 0 means the statement form (no value pushed);
 * otherwise the 1/0 result is pushed onto the vec4 stack.
 */
static int draw_sv_cast_class_common_(ivl_expr_t dest, ivl_expr_t src,
                                      unsigned result_width,
                                      unsigned file_idx, unsigned lineno)
{
      ivl_signal_t base_sig = 0;
      ivl_type_t dest_type = 0;
      ivl_expr_t idx;
      int pidx;
      int is_container;
      int is_assoc;
      ivl_expr_t recv = 0;
      ivl_expr_t container = 0;
      ivl_signal_t container_sig = 0;
      int is_fixed_signal = 0;
      int is_select_signal = 0;
      int is_select_object = 0;
      int select_is_queue = 0;
      unsigned lab_fail, lab_done;
      int depth_on_fail;
      char src_type_buf[64];

      if (!(dest && src))
            return 0;
      if (ivl_expr_value(dest) != IVL_VT_CLASS)
            return 0;

      /* ivl_expr_signal() asserts on an expression that has no signal,
         so the shape has to be established BEFORE asking for one. Any
         other destination shape falls back to the generic path. */
      switch (ivl_expr_type(dest)) {
          case IVL_EX_SIGNAL:
          case IVL_EX_PROPERTY:
          case IVL_EX_SELECT:
            break;
          default:
            return 0;
      }

      if (ivl_expr_type(dest) == IVL_EX_SIGNAL) {
            base_sig = ivl_expr_signal(dest);
            if (!base_sig)
                  return 0;
            if (ivl_signal_dimensions(base_sig) != 0) {
                  ivl_type_t signal_type = ivl_signal_net_type(base_sig);
                  is_fixed_signal = 1;
                  idx = ivl_expr_oper1(dest);
                  dest_type = signal_type
                        ? ivl_type_element(signal_type) : 0;
                  if (!dest_type)
                        dest_type = signal_type;
            } else {
                  dest_type = ivl_signal_net_type(base_sig);
            }
      } else if (ivl_expr_type(dest) == IVL_EX_PROPERTY) {
              /* A property always carries its receiver as oper2, and a
                 NESTED receiver (p.inn.arr[i]) has no single signal to
                 ask for -- so drive everything off the receiver
                 expression and never reach for a signal here. */
            recv = ivl_expr_oper2(dest);
            if (!recv) {
                  base_sig = ivl_expr_signal(dest);
                  if (!base_sig)
                        return 0;
            }
            dest_type = ivl_expr_net_type(dest);
      } else {
            container = ivl_expr_oper1(dest);
            idx = ivl_expr_oper2(dest);
            if (!container || !idx)
                  return 0;

            is_container = 1;

            if (ivl_expr_type(container) == IVL_EX_SIGNAL) {
                  container_sig = ivl_expr_signal(container);
                  if (!container_sig)
                        return 0;
                  is_select_signal = 1;
            } else {
                  is_select_object = 1;
            }
            ivl_type_t container_type = is_select_signal
                  ? ivl_signal_net_type(container_sig)
                  : ivl_expr_net_type(container);
            dest_type = container_type
                  ? ivl_type_element(container_type) : 0;
            is_assoc = container_type
                  && ivl_type_base(container_type) == IVL_VT_QUEUE
                  && ivl_type_queue_assoc_compat(container_type);
            select_is_queue = container_type
                  && ivl_type_base(container_type) == IVL_VT_QUEUE;
      }

      /* Without the destination's class type there is nothing to check
         against; hand the call back rather than store unchecked. */
      if (!(dest_type && ivl_type_base(dest_type) == IVL_VT_CLASS))
            return 0;

      if (ivl_expr_type(dest) == IVL_EX_PROPERTY)
            idx = ivl_expr_oper1(dest);
      pidx = (ivl_expr_type(dest) == IVL_EX_PROPERTY)
            ? (int) ivl_expr_property_idx(dest) : 0;
      if (ivl_expr_type(dest) == IVL_EX_PROPERTY) {
            is_container = property_is_indexed_container_expr_(dest);
            is_assoc = property_is_assoc_indexed_expr_(dest);
      } else if (ivl_expr_type(dest) != IVL_EX_SELECT) {
            is_container = 0;
            is_assoc = 0;
      }

      lab_fail = local_count++;
      lab_done = local_count++;

      /* Push the destination context first where there is one, so the
         source ends up on top of the OBJECT stack for the type test in
         every shape. */
      if (ivl_expr_type(dest) == IVL_EX_PROPERTY) {
              /* The receiver may itself be a property path (p.inn.arr[i]),
                 so evaluate it rather than assuming the base signal IS
                 the receiver -- that would store into the wrong object. */
            if (recv)
                  draw_eval_object(recv);
            else
                  fprintf(vvp_out, "    %%load/obj v%p_0; $cast: receiver\n",
                          base_sig);
            depth_on_fail = 2;
            if (is_assoc) {
                  fprintf(vvp_out, "    %%prop/obj %d, 0; $cast: the map\n",
                          pidx);
                  depth_on_fail = 3;
            } else if (is_container) {
                  draw_eval_expr_into_integer(idx, 4);
                  fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
                  fprintf(vvp_out, "    %%prop/obj %d, 0; $cast: the container\n",
                          pidx);
                  fprintf(vvp_out, "    %%pop/obj 1, 1; $cast: drop receiver\n");
            }
      } else if (is_select_object) {
            draw_eval_object(container);
            depth_on_fail = 2;
      } else {
            depth_on_fail = 1;
      }

      draw_eval_object(src);
      ivl_type_t src_type = ivl_expr_net_type(src);
      if (!src_type && ivl_expr_type(src) == IVL_EX_SIGNAL)
            src_type = ivl_signal_net_type(ivl_expr_signal(src));
      if (src_type && ivl_type_base(src_type) == IVL_VT_CLASS)
            draw_class_in_scope(src_type);
      if (src_type && ivl_type_base(src_type) == IVL_VT_CLASS)
            snprintf(src_type_buf, sizeof src_type_buf, "C%p", src_type);
      else
            snprintf(src_type_buf, sizeof src_type_buf, "C%p", dest_type);
      fprintf(vvp_out, "    %%test/class C%p, %s; $cast: 6.24.2 type check\n",
              dest_type, src_type_buf);
      fprintf(vvp_out, "    %%jmp/0xz T_%u.%u, 4;\n",
              thread_count, lab_fail);

      if (is_fixed_signal) {
            draw_eval_expr_into_integer(idx, 4);
            fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
            note_array_signal_use(base_sig);
            fprintf(vvp_out, "    %%store/obja v%p, 4; $cast\n", base_sig);
      } else if (is_select_signal && is_assoc) {
            const char*key_kind = draw_eval_assoc_key_(idx, 0);
            fprintf(vvp_out, "    %%aa/store/sig/obj/%s v%p_0;"
                    " $cast: store assoc entry\n",
                    key_kind, container_sig);
      } else if (is_select_signal) {
            draw_eval_expr_into_integer(idx, 3);
            if (select_is_queue) {
                  fprintf(vvp_out, "    %%ix/load 5, %u, 0;\n",
                          ivl_signal_array_count(container_sig));
                  fprintf(vvp_out, "    %%store/qdar/obj v%p_0, 5;"
                          " $cast: store queue element\n", container_sig);
            } else {
                  fprintf(vvp_out, "    %%store/dar/obj v%p_0;"
                          " $cast: store darray element\n", container_sig);
            }
      } else if (is_select_object && is_assoc) {
            const char*key_kind = draw_eval_assoc_key_(idx, 0);
            fprintf(vvp_out, "    %%aa/store/obj/%s;"
                    " $cast: store nested assoc entry\n", key_kind);
            fprintf(vvp_out, "    %%pop/obj 1, 0;"
                    " $cast: drop nested map\n");
      } else if (is_select_object) {
            draw_eval_expr_into_integer(idx, 4);
            fprintf(vvp_out, "    %%set/dar/obj/obj 4;"
                    " $cast: store nested container element\n");
            fprintf(vvp_out, "    %%pop/obj 1, 0;"
                    " $cast: drop nested container\n");
      } else if (ivl_expr_type(dest) != IVL_EX_PROPERTY) {
            fprintf(vvp_out, "    %%store/obj v%p_0; $cast\n", base_sig);
      } else if (is_assoc) {
              /* The key goes on its own stack, so it may be pushed
                 after the value; the store consumes key and value and
                 leaves the map and the receiver to be dropped. */
            {     /* The shared helper pushes the key on whichever stack
                     it belongs to and names the matching store. */
                  const char*key_kind = draw_eval_assoc_key_(idx, 0);
                  fprintf(vvp_out, "    %%aa/store/obj/%s; $cast: store entry\n",
                          key_kind);
            }
            fprintf(vvp_out, "    %%pop/obj 2, 0; $cast: drop map and receiver\n");
      } else if (is_container) {
            fprintf(vvp_out, "    %%set/dar/obj/obj 4; $cast: store element\n");
            fprintf(vvp_out, "    %%pop/obj 1, 0; $cast: drop container\n");
      } else {
            if (idx) {
                  draw_eval_expr_into_integer(idx, 4);
                  fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
                  fprintf(vvp_out, "    %%store/prop/obj %d, 4; $cast\n", pidx);
            } else {
                  fprintf(vvp_out, "    %%store/prop/obj %d, 0; $cast\n", pidx);
            }
            fprintf(vvp_out, "    %%pop/obj 1, 0; $cast: drop receiver\n");
      }
      if (result_width)
            fprintf(vvp_out, "    %%pushi/vec4 1, 0, %u; $cast: success\n",
                    result_width);
      fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_done);

      /* Failure: the destination is left exactly as it was (6.24.2). */
      fprintf(vvp_out, "T_%u.%u ; $cast failed\n", thread_count, lab_fail);
      fprintf(vvp_out, "    %%pop/obj %d, 0;\n", depth_on_fail);
      if (result_width) {
            fprintf(vvp_out, "    %%pushi/vec4 0, 0, %u; $cast: failure\n",
                    result_width);
      } else {
              /* Task form: 6.24.2 requires a diagnostic, because the
                 caller has no return value to inspect. */
            fprintf(vvp_out, "    %%vpi_call %u %u \"$ivl_cast_error\" {0 0 0 0};\n",
                    file_idx, lineno);
      }
      fprintf(vvp_out, "T_%u.%u ;\n", thread_count, lab_done);
      return 1;
}

static int draw_sv_cast_class_task(ivl_statement_t tnet)
{
      if (!(tnet && ivl_stmt_name(tnet)))
            return 0;
      if (strcmp(ivl_stmt_name(tnet), "$cast") != 0)
            return 0;
      if (ivl_stmt_parm_count(tnet) != 2)
            return 0;

      return draw_sv_cast_class_common_(ivl_stmt_parm(tnet, 0),
                                        ivl_stmt_parm(tnet, 1), 0,
                                        ivl_file_table_index(ivl_stmt_file(tnet)),
                                        ivl_stmt_lineno(tnet));
}

static int get_vpi_taskfunc_lvalue_arg(struct args_info *result,
                                       ivl_expr_t expr)
{
      ivl_signal_t sig = expr_signal_base_(expr);
      char buffer[4096];

      if (!sig && ivl_expr_type(expr) != IVL_EX_PROPERTY)
            return 0;

      switch (ivl_expr_type(expr)) {
	  case IVL_EX_SIGNAL:
	    if (ivl_signal_dimensions(sig) != 0)
		  return 0;
	    snprintf(buffer, sizeof buffer, "v%p_0", sig);
	    result->text = strdup(buffer);
	    return 1;

	  case IVL_EX_PROPERTY:
	    /* The root signal is the containing class handle. $cast needs
	     * the writable property handle, not that object. */
	    return get_vpi_taskfunc_signal_arg(result, expr);

	  case IVL_EX_SELECT:
	    return get_vpi_taskfunc_signal_arg(result, expr);

	  default:
	    return 0;
      }
}

static void draw_vpi_taskfunc_args(const char*call_string,
				   ivl_statement_t tnet,
				   ivl_expr_t fnet,
				   unsigned parm_base,
				   const char*tf_name_override,
				   int force_value_capture,
				   const struct deferred_vpi_call_info*deferred)
{
      unsigned idx;
      const char*tf_name = tf_name_override ? tf_name_override
	    : (tnet ? ivl_stmt_name(tnet) : ivl_expr_name(fnet));
      unsigned parm_count = tnet
	    ? ivl_stmt_parm_count(tnet) - parm_base
	    : ivl_expr_parms(fnet);

      struct args_info *args = calloc(parm_count, sizeof(struct args_info));
      int lazy_args = !force_value_capture && !deferred
	    && !is_live_sample_task_(tf_name) && vpi_args_are_lazy_(tf_name);

      char buffer[4096];

      ivl_parameter_t par;

	/* Keep track of how much string stack this function call is
	   going to need. We'll need this for making stack references,
	   and also to clean out the stack when done. */
      unsigned vec4_stack_need = 0;
      unsigned str_stack_need = 0;
      unsigned real_stack_need = 0;
      unsigned obj_stack_need = 0;

	/* Figure out how many expressions are going to be evaluated
	   for this task call. I won't need to evaluate expressions
	   for items that are VPI objects directly. */
      for (idx = 0 ;  idx < parm_count ;  idx += 1) {
	    ivl_expr_t expr = tnet
		  ? ivl_stmt_parm(tnet, parm_base + idx)
		  : ivl_expr_parm(fnet, idx);

	      /* A selected instance-array scope can arrive as a zero-extension
	       * select around IVL_EX_SCOPE. System-task arguments use the scope as
	       * a VPI handle (for example `$asserton(0, ifs[0])'); evaluating this
	       * wrapper as a vector loses the scope and produces a zero fallback.
	       * Strip only a padding select -- a real part-select has oper2. */
	    if (ivl_expr_type(expr) == IVL_EX_SELECT
		&& ivl_expr_oper2(expr) == 0
		&& ivl_expr_oper1(expr)
		&& ivl_expr_type(ivl_expr_oper1(expr)) == IVL_EX_SCOPE) {
		  snprintf(buffer, sizeof buffer, "S_%p",
		           ivl_expr_scope(ivl_expr_oper1(expr)));
		  args[idx].text = strdup(buffer);
		  continue;
	    }

	    if (!force_value_capture && tf_name
		&& strcmp(tf_name, "$cast") == 0 && idx == 0) {
		  if (get_vpi_taskfunc_lvalue_arg(&args[idx], expr)) {
			if (args[idx].cpv_index)
			      args[idx].stack = vec4_stack_need++;
			continue;
		  }
	    }

	    /* VPI array-word aliases support fixed arrays. Queue and dynamic-array
	     * variables have a separate VPI handle, so pass the container and its
	     * captured index to the string method for a writable word lookup. */
	    if (!force_value_capture && idx == 0
		&& tf_name && !strcmp(tf_name, "$ivl_string_method$itoa")
		&& ivl_expr_type(expr) == IVL_EX_SELECT
		&& ivl_expr_value(expr) == IVL_VT_STRING
		&& ivl_expr_oper1(expr)
		&& ivl_expr_type(ivl_expr_oper1(expr)) == IVL_EX_SIGNAL
		&& (ivl_signal_data_type(ivl_expr_signal(ivl_expr_oper1(expr)))
		      == IVL_VT_DARRAY
		    || ivl_signal_data_type(ivl_expr_signal(ivl_expr_oper1(expr)))
		      == IVL_VT_QUEUE)) {
	      ivl_expr_t address = ivl_expr_oper2(expr);
	      draw_eval_vec4(address);
	      args[idx].index_stack = vec4_stack_need++;
	      args[idx].container_word = 1;
	      args[idx].index_sign = ivl_expr_signed(address) ? 's' : 'u';
	      args[idx].index_width = ivl_expr_width(address);
	      snprintf(buffer, sizeof buffer, "v%p_0",
	               ivl_expr_signal(ivl_expr_oper1(expr)));
	      args[idx].text = strdup(buffer);
	      continue;
	    }

	    switch (ivl_expr_type(expr)) {

		    /* These expression types can be handled directly,
		       with VPI handles of their own. Therefore, skip
		       them in the process of evaluating expressions. */
		case IVL_EX_NONE:
		  /* Resolve this VVP-only symbol to a vpiNullOp expression. */
		  args[idx].text = strdup("__ivl_vpi_null_op__");
		  continue;

		case IVL_EX_ARRAY:
		  snprintf(buffer, sizeof buffer,
			   "v%p", ivl_expr_signal(expr));
		  args[idx].text = strdup(buffer);
		  continue;

		case IVL_EX_NUMBER: {
		  if (( par = ivl_expr_parameter(expr) )) {
			snprintf(buffer, sizeof buffer, "P_%p", par);
		  } else {
			unsigned bit, wid = ivl_expr_width(expr);
			const char*bits = ivl_expr_bits(expr);
			char*dp;

			snprintf(buffer, sizeof buffer, "%u'%sb",
			         wid, ivl_expr_signed(expr)? "s" : "");
			dp = buffer + strlen(buffer);
			for (bit = wid ;  bit > 0 ;  bit -= 1)
			      *dp++ = bits[bit-1];
			*dp++ = 0;
			assert(dp >= buffer);
			assert((unsigned)(dp - buffer) <= sizeof buffer);
		  }
		  args[idx].text = strdup(buffer);
		  continue;
		}

		case IVL_EX_STRING:
		  if (( par = ivl_expr_parameter(expr) )) {
			snprintf(buffer, sizeof buffer, "P_%p", par);
			args[idx].text = strdup(buffer);

		  } else {
			size_t needed_len = strlen(ivl_expr_string(expr)) + 3;
			args[idx].text = malloc(needed_len);
			snprintf(args[idx].text, needed_len, "\"%s\"",
			         ivl_expr_string(expr));
		  }
		  continue;

		case IVL_EX_REALNUM:
		  if (( par = ivl_expr_parameter(expr) )) {
			snprintf(buffer, sizeof buffer, "P_%p", par);
			args[idx].text = strdup(buffer);
			continue;
		  }
		  break;

		case IVL_EX_ENUMTYPE:
		  snprintf(buffer, sizeof buffer, "enum%p", ivl_expr_enumtype(expr));
		  args[idx].text = strdup(buffer);
		  continue;
		case IVL_EX_EVENT:
		  snprintf(buffer, sizeof buffer, "E_%p", ivl_expr_event(expr));
		  args[idx].text = strdup(buffer);
		  continue;
		case IVL_EX_SCOPE:
		  snprintf(buffer, sizeof buffer, "S_%p", ivl_expr_scope(expr));
		  args[idx].text = strdup(buffer);
		  continue;

		case IVL_EX_SFUNC:
		  if (!force_value_capture
		      && is_magic_sfunc(ivl_expr_name(expr))) {
			snprintf(buffer, sizeof buffer, "%s", ivl_expr_name(expr));
			args[idx].text = strdup(buffer);
			continue;
		  }
		  break;

	case IVL_EX_SIGNAL:
	case IVL_EX_PROPERTY:
	case IVL_EX_SELECT:
	  {
	  /* These internal methods mutate their first argument. A general array
	   * word expression would normally be passed as a temporary string value,
	   * losing the update. Capture its address now and pass a writable array
	   * word handle. This also fixes receiver-before-argument evaluation. */
	  if (!force_value_capture && idx == 0
	      && is_mutating_string_method_(tf_name)
	      && ivl_expr_type(expr) == IVL_EX_SIGNAL
	      && ivl_signal_dimensions(ivl_expr_signal(expr)) != 0
	      && ivl_signal_data_type(ivl_expr_signal(expr)) == IVL_VT_STRING
	      && ivl_expr_oper1(expr)) {
		draw_eval_vec4(ivl_expr_oper1(expr));
		args[idx].vec_flag = ivl_expr_signed(ivl_expr_oper1(expr)) ? 's' : 'u';
		args[idx].vec_wid = ivl_expr_width(ivl_expr_oper1(expr));
		args[idx].stack = vec4_stack_need++;
		args[idx].array_word_sig = ivl_expr_signal(expr);
		continue;
	  }
	  int live_sample = !force_value_capture
		&& is_live_sample_task_(tf_name);
	  if (!force_value_capture) {
		args[idx].stack = vec4_stack_need;
		/* normalize_variable_unpacked represents an unsigned index as a
		 * one-bit zero extension followed by a signed wrapper. In the IVL
		 * expression both are pad selects (no base operand). Peel only those
		 * wrappers when forming a live sampled array handle. Any real
		 * bit/part selection beneath them retains its base operand. */
		if (live_sample && ivl_expr_type(expr) == IVL_EX_SIGNAL
		    && ivl_signal_dimensions(ivl_expr_signal(expr)) != 0) {
		      ivl_expr_t outer = ivl_expr_oper1(expr);
		      ivl_expr_t inner = outer && ivl_expr_type(outer) == IVL_EX_SELECT
			    && !ivl_expr_oper2(outer) ? ivl_expr_oper1(outer) : 0;
		      ivl_expr_t word = inner && ivl_expr_type(inner) == IVL_EX_SELECT
			    && !ivl_expr_oper2(inner) ? ivl_expr_oper1(inner) : 0;
		      if (!(outer && inner && word
			    && ivl_expr_signed(outer)
			    && !ivl_expr_signed(inner)
			    && !ivl_expr_signed(word)
			    && ivl_expr_width(outer) == ivl_expr_width(inner)
			    && ivl_expr_width(inner) > ivl_expr_width(word)))
			    word = 0;
		      /* An explicit leading-zero concatenation is another lossless
		       * spelling of the same live index. Preserve the selected source;
		       * nonzero/multiple data operands still use value capture. */
		      if (word && ivl_expr_type(word) == IVL_EX_CONCAT
			  && ivl_expr_repeat(word) == 1 && ivl_expr_parms(word) == 2) {
			    ivl_expr_t zero = ivl_expr_parm(word, 0);
			    ivl_expr_t data = ivl_expr_parm(word, 1);
			    if (zero && data && number_is_immediate(zero, 64, 1)
				&& !number_is_unknown(zero)
				&& get_number_immediate64(zero) == 0)
			      word = data;
			    else
			      word = 0;
		      }
		      if (word) {
			    if (ivl_expr_type(word) == IVL_EX_SIGNAL
				|| ivl_expr_type(word) == IVL_EX_SELECT) {
				  args[idx].child = calloc(1, sizeof(struct args_info));
				  if (get_vpi_taskfunc_signal_arg(args[idx].child, word)) {
					char live[4096];
					snprintf(live, sizeof live, "&A<v%p, %s >",
						 ivl_expr_signal(expr), args[idx].child->text);
					free(args[idx].child->text);
					args[idx].text = strdup(live);
					args[idx].stack = 0;
					continue;
				  }
				  free(args[idx].child);
				  args[idx].child = NULL;
			    }
		      }
		}
		cpv_elem_live_sample_ = live_sample;
		int got = get_vpi_taskfunc_signal_arg(&args[idx], expr);
		cpv_elem_live_sample_ = 0;
		if (got) {
			      if (args[idx].vec_flag || args[idx].cpv_index) {
				    vec4_stack_need += 1;
			      } else {
				    args[idx].stack = 0;
			      }
			      continue;
			}
			args[idx].stack = 0;
	  }
	  }
	  break;
		case IVL_EX_NULL:
		  snprintf(buffer, sizeof buffer, "null");
		  args[idx].text = strdup(buffer);
		  continue;
		case IVL_EX_ARRAY_PATTERN:
		    /* Unpacked aggregate constants such as array parameters are
		       represented as array-pattern expressions. They are VPI object
		       values for display formatting, not vector expressions. Keep
		       packed assignment patterns on the ordinary vector path. */
		  {
			ivl_type_t type = ivl_expr_net_type(expr);
			if (type && !ivl_type_is_packed_vector(type)
			    && (ivl_type_base(type) == IVL_VT_DARRAY
				|| ivl_type_base(type) == IVL_VT_QUEUE
				|| ivl_type_element(type)
				|| ivl_type_properties(type) > 0)) {
			      draw_eval_object(expr);
			      args[idx].vec_flag = 0;
			      args[idx].str_flag = 0;
			      args[idx].real_flag = 0;
			      args[idx].obj_flag = 1;
			      args[idx].obj_type = 0;
			      args[idx].stack = obj_stack_need;
			      obj_stack_need += 1;
			      args[idx].text = strdup("");
			      continue;
			}
		  }
		  break;
		    /* Everything else will need to be evaluated and
		       passed as a constant to the vpi task. */
		default:
		  break;
	    }

	    if (lazy_args && !expr_is_class_like_(expr)
		&& (args[idx].text = draw_lazy_expr_(expr)))
		  continue;

	    if (expr_is_class_like_(expr)) {
		  draw_eval_object(expr);
		  args[idx].vec_flag = 0;
		  args[idx].str_flag = 0;
		  args[idx].real_flag = 0;
		  args[idx].obj_flag = 1;
		  args[idx].obj_type = vpi_class_arg_type_label_(expr);
		  args[idx].stack = obj_stack_need;
		  obj_stack_need += 1;
		  buffer[0] = 0;
	    } else switch (ivl_expr_value(expr)) {
		case IVL_VT_LOGIC:
		case IVL_VT_BOOL:
		  draw_eval_vec4(expr);
		  args[idx].vec_flag = ivl_expr_signed(expr)? 's' : 'u';
		  args[idx].str_flag = 0;
		  args[idx].real_flag = 0;
		  args[idx].stack = vec4_stack_need;
		  args[idx].vec_wid = ivl_expr_width(expr);
		  vec4_stack_need += 1;
		  buffer[0] = 0;
		  break;
		case IVL_VT_REAL:
		  draw_eval_real(expr);
		  args[idx].vec_flag = 0;
		  args[idx].str_flag = 0;
		  args[idx].real_flag = 1;
		  args[idx].stack = real_stack_need;
		  real_stack_need += 1;
		  buffer[0] = 0;
		  break;
		case IVL_VT_STRING:
		    /* Eval the string into the stack, and tell VPI
		       about the stack position. */
		  draw_eval_string(expr);
		  args[idx].vec_flag = 0;
		  args[idx].str_flag = 1;
		  args[idx].real_flag = 0;
		  args[idx].obj_flag = 0;
		  args[idx].stack = str_stack_need;
		  args[idx].real_flag = 0;
			  str_stack_need += 1;
			  buffer[0] = 0;
			  break;
		case IVL_VT_DARRAY:
		case IVL_VT_QUEUE:
		    /* A whole-container EXPRESSION (e.g. a queue slice
		       q[1:2] or a container-valued function result —
		       container signals were already handled above):
		       pass the object handle so %p can render the
		       elements instead of reading a garbage vector. */
		  draw_eval_object(expr);
		  args[idx].vec_flag = 0;
		  args[idx].str_flag = 0;
		  args[idx].real_flag = 0;
		  args[idx].obj_flag = 1;
		  args[idx].obj_type = 0;
		  args[idx].stack = obj_stack_need;
		  obj_stack_need += 1;
		  buffer[0] = 0;
		  break;
		default:
		  /* Fallback: For unsupported types (CLASS, VOID, etc.), try to
		     evaluate as vec4. This handles cases like $cast which may return
		     unexpected types but can still be evaluated to a boolean/logic value. */
		  {
			int vtype = ivl_expr_value(expr);
			int emit_warn = 1;
			/* Object-like values are lowered by draw_eval_vec4 as
			   handle-bool casts, so don't warn here. */
			if (vtype == IVL_VT_CLASS || vtype == IVL_VT_QUEUE || vtype == IVL_VT_DARRAY) {
			      emit_warn = 0;
			} else if (vtype >= 0 && vtype < (int)(sizeof warned_unsupported_vpi_arg_type)) {
			      emit_warn = !warned_unsupported_vpi_arg_type[vtype];
			      warned_unsupported_vpi_arg_type[vtype] = 1;
			}
			if (emit_warn) {
			      fprintf(stderr, "Warning: Unsupported VPI argument type %d at %s:%u; "
				              "treating as logic (further similar warnings suppressed)\n",
				              vtype, ivl_expr_file(expr), ivl_expr_lineno(expr));
			}
		  }
		  draw_eval_vec4(expr);
		  args[idx].vec_flag = ivl_expr_signed(expr)? 's' : 'u';
		  args[idx].str_flag = 0;
		  args[idx].real_flag = 0;
		  args[idx].stack = vec4_stack_need;
		  args[idx].vec_wid = ivl_expr_width(expr);
		  vec4_stack_need += 1;
		  buffer[0] = 0;
	    }
	    args[idx].text = strdup(buffer);
      }
      if (deferred) {
	    if (deferred->is_final)
		  fprintf(vvp_out, "    %%defer/final T_%u.%u, S_%p;\n",
			  thread_count, deferred->action_lab, deferred->scope);
	    else
		  fprintf(vvp_out,
			  "    %%defer/enqueue T_%u.%u, S_%p;\n",
			  thread_count, deferred->action_lab, deferred->scope);
	    fprintf(vvp_out, "    %%jmp T_%u.%u;\n",
		    thread_count, deferred->after_lab);
	    fprintf(vvp_out, "T_%u.%u ;\n",
		    thread_count, deferred->action_lab);
	    if (deferred->is_final)
		  fprintf(vvp_out, "    %%defer/final/key %ld, %u;\n",
			  deferred->source_id, deferred->result);
	    else
		  fprintf(vvp_out, "    %%defer/enqueue/key %ld, %u;\n",
			  deferred->source_id, deferred->result);
      }

      fprintf(vvp_out, "%s", call_string);

      for (idx = 0 ;  idx < parm_count ;  idx += 1) {
	    struct args_info*ptr;

	    if (args[idx].array_word_sig) {
		  unsigned pos = vec4_stack_need - args[idx].stack - 1;
		  fprintf(vvp_out, ", &A<v%p, S<%u,vec4,%c%u> >",
		          args[idx].array_word_sig, pos,
		          args[idx].vec_flag, args[idx].vec_wid);
	    } else if (args[idx].str_flag) {
		    /* If this is a stack reference, then
		       calculate the stack depth and use that to
		       generate the completed string. */
		  unsigned pos = str_stack_need - args[idx].stack - 1;
		  fprintf(vvp_out, ", S<%u,str>",pos);
	    } else if (args[idx].obj_flag) {
		  unsigned pos = obj_stack_need - args[idx].stack - 1;
		  if (args[idx].obj_type) {
			fprintf(vvp_out, ", S<%u,obj,%s>", pos, args[idx].obj_type);
		  } else {
			fprintf(vvp_out, ", S<%u,obj>", pos);
		  }
	    } else if (args[idx].real_flag) {
		  unsigned pos = real_stack_need - args[idx].stack - 1;
		  fprintf(vvp_out, ", W<%u,r>",pos);
	    } else if (args[idx].cpv_index) {
		  unsigned pos = vec4_stack_need - args[idx].stack - 1;
		  fprintf(vvp_out, ", %s, S<%u,vec4,%c%u>>", args[idx].text,
		          pos, args[idx].cpv_index_sign,
		          args[idx].cpv_index_width);
	    } else if (args[idx].vec_flag) {
		  unsigned pos = vec4_stack_need - args[idx].stack - 1;
		  char sign_flag = args[idx].vec_flag;
		  unsigned wid = args[idx].vec_wid;
		  fprintf(vvp_out, ", S<%u,vec4,%c%u>",pos, sign_flag, wid);
	    } else {
		  fprintf(vvp_out, ", %s", args[idx].text);
	    }
	    if (args[idx].container_word) {
		  unsigned pos = vec4_stack_need - args[idx].index_stack - 1;
		  fprintf(vvp_out, ", S<%u,vec4,%c%u>", pos,
		          args[idx].index_sign, args[idx].index_width);
	    }

	    free(args[idx].text);
	    free(args[idx].obj_type);
	      /* Free the nested children. */
	    ptr = args[idx].child;
	    while (ptr != NULL) {
		struct args_info*tptr = ptr;
		ptr = ptr->child;
		free(tptr);
	    }
      }

      free(args);

      fprintf(vvp_out, " {%u %u %u %u}",
              vec4_stack_need, real_stack_need, str_stack_need, obj_stack_need);
      fprintf(vvp_out, ";\n");

      if (deferred) {
	    fprintf(vvp_out, "    %%end;\n");
	    fprintf(vvp_out, "T_%u.%u ;\n",
		    thread_count, deferred->after_lab);
      }
}

void draw_vpi_task_call(ivl_statement_t tnet)
{
      unsigned parm_count = ivl_stmt_parm_count(tnet);
      const char *command = "error";
      const char *task_name = ivl_stmt_name(tnet);

      if (draw_sv_cast_class_task(tnet))
            return;

      /* VPI exposes $cast as a system function even when its return value is
         discarded. Route statement-form calls through a private task callback
         so the runtime can report an invalid assignment without diagnosing
         function-form failures. */
      if (task_name && strcmp(task_name, "$cast") == 0)
            task_name = "$ivl_cast_task";

      switch (ivl_stmt_sfunc_as_task(tnet)) {
	  case IVL_SFUNC_AS_TASK_ERROR:
	    command = "%vpi_call";
	    break;
	  case IVL_SFUNC_AS_TASK_WARNING:
	    command = "%vpi_call/w";
	    break;
	  case IVL_SFUNC_AS_TASK_IGNORE:
	    command = "%vpi_call/i";
	    break;
      }

      if (parm_count == 0) {
            fprintf(vvp_out, "    %s %u %u \"%s\" {0 0 0 0};\n", command,
                    ivl_file_table_index(ivl_stmt_file(tnet)),
                    ivl_stmt_lineno(tnet), task_name);
      } else {
	    char call_string[1024];
	    snprintf(call_string, sizeof(call_string),
		     "    %s %u %u \"%s\"", command,
		     ivl_file_table_index(ivl_stmt_file(tnet)),
                     ivl_stmt_lineno(tnet), task_name);
	    draw_vpi_taskfunc_args(call_string, tnet, 0, 0, task_name, 0, 0);
      }
}

int draw_vpi_deferred_call(ivl_statement_t tnet, unsigned parm_base,
			   const char*task_name, long source_id,
			   ivl_scope_t scope, int is_final, unsigned result)
{
      unsigned total = tnet ? ivl_stmt_parm_count(tnet) : 0;

      if (!tnet || !task_name || source_id <= 0 || !scope
	  || parm_base > total
	  || (strcmp(task_name, "$display") != 0
	      && strcmp(task_name, "$error") != 0)) {
	    fprintf(stderr, "%s:%u: error: malformed deferred VPI action; "
		    "no action was emitted.\n",
		    tnet ? ivl_stmt_file(tnet) : "<internal>",
		    tnet ? ivl_stmt_lineno(tnet) : 0);
	    vvp_errors += 1;
	    return 1;
      }

      /* Validate the complete list before emitting any evaluation code. A
	 deferred marker rejected here must leave every source-thread stack
	 untouched. Fixed unpacked arrays still need a value-copy representation;
	 dynamic arrays, queues and class handles already use owned vvp_object_t
	 stack payloads and are safe to snapshot. */
      for (unsigned idx = parm_base ; idx < total ; idx += 1) {
	    ivl_expr_t expr = ivl_stmt_parm(tnet, idx);
	    int supported = expr != 0;
	    if (supported && ivl_expr_type(expr) == IVL_EX_ARRAY)
		  supported = 0;
	    if (supported && ivl_expr_type(expr) == IVL_EX_SIGNAL) {
		  ivl_signal_t sig = ivl_expr_signal(expr);
		  if (sig && ivl_signal_dimensions(sig) != 0)
			supported = 0;
	    }
	    if (supported) {
		  switch (ivl_expr_value(expr)) {
		      case IVL_VT_LOGIC:
		      case IVL_VT_BOOL:
		      case IVL_VT_REAL:
		      case IVL_VT_STRING:
		      case IVL_VT_DARRAY:
		      case IVL_VT_QUEUE:
		      case IVL_VT_CLASS:
			break;
		      default:
			switch (ivl_expr_type(expr)) {
			    case IVL_EX_NONE:
			    case IVL_EX_NULL:
			    case IVL_EX_ENUMTYPE:
			    case IVL_EX_EVENT:
			    case IVL_EX_SCOPE:
				break;
			    default:
				supported = 0;
				break;
			}
			break;
		  }
	    }
	    if (!supported) {
		  fprintf(stderr, "%s:%u: error: deferred %s argument %u "
			  "has an unsupported capture shape; no argument was "
			  "evaluated and no action was emitted.\n",
			  ivl_stmt_file(tnet), ivl_stmt_lineno(tnet), task_name,
			  idx - parm_base + 1);
		  vvp_errors += 1;
		  return 1;
	    }
      }

      struct deferred_vpi_call_info deferred;
      deferred.source_id = source_id;
      deferred.result = result;
      deferred.scope = scope;
      deferred.action_lab = local_count++;
      deferred.after_lab = local_count++;
      deferred.is_final = is_final != 0;

      char call_string[1024];
      snprintf(call_string, sizeof(call_string),
	       "    %%vpi_call %u %u \"%s\"",
	       ivl_file_table_index(ivl_stmt_file(tnet)),
	       ivl_stmt_lineno(tnet), task_name);
      draw_vpi_taskfunc_args(call_string, tnet, 0, parm_base, task_name,
			     1, &deferred);
      return 0;
}

/* Function form: the same lowering, plus the 1/0 result. */
static int draw_sv_cast_class_func(ivl_expr_t fnet)
{
      const char*name = ivl_expr_name(fnet);
      if (!(name && strcmp(name, "$cast") == 0))
            return 0;
      if (ivl_expr_parms(fnet) != 2)
            return 0;

      return draw_sv_cast_class_common_(ivl_expr_parm(fnet, 0),
                                        ivl_expr_parm(fnet, 1),
                                        ivl_expr_width(fnet),
                                        ivl_file_table_index(ivl_expr_file(fnet)),
                                        ivl_expr_lineno(fnet));
}

void draw_vpi_func_call(ivl_expr_t fnet)
{
      char call_string[1024];

      if (draw_sv_cast_class_func(fnet))
            return;

      snprintf(call_string, sizeof(call_string),
	       "    %%vpi_func %u %u \"%s\" %u",
	       ivl_file_table_index(ivl_expr_file(fnet)),
	       ivl_expr_lineno(fnet), ivl_expr_name(fnet),
	       ivl_expr_width(fnet));

      draw_vpi_taskfunc_args(call_string, 0, fnet, 0, 0, 0, 0);
}

void draw_vpi_rfunc_call(ivl_expr_t fnet)
{
      char call_string[1024];

      snprintf(call_string, sizeof(call_string),
	       "    %%vpi_func/r %u %u \"%s\"",
	       ivl_file_table_index(ivl_expr_file(fnet)),
	       ivl_expr_lineno(fnet), ivl_expr_name(fnet));

      draw_vpi_taskfunc_args(call_string, 0, fnet, 0, 0, 0, 0);
}

void draw_vpi_sfunc_call(ivl_expr_t fnet)
{
      char call_string[1024];

      snprintf(call_string, sizeof(call_string),
	       "    %%vpi_func/s %u %u \"%s\"",
	       ivl_file_table_index(ivl_expr_file(fnet)),
	       ivl_expr_lineno(fnet), ivl_expr_name(fnet));

      draw_vpi_taskfunc_args(call_string, 0, fnet, 0, 0, 0, 0);
}
