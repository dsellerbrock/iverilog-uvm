/*
 * Copyright (c) 2013-2020 Stephen Williams (steve@icarus.com)
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

/*
 * This file includes functions for evaluating VECTOR expressions.
 */
# include  "vvp_priv.h"
# include  <string.h>
# include  <stdlib.h>
# include  <math.h>
# include  <assert.h>
# include  <stdbool.h>

static int number_trace_enabled_(void)
{
      static int enabled = -1;
      if (enabled < 0) {
            const char*env = getenv("IVL_VVP_NUM_TRACE");
            enabled = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
      }
      return enabled;
}

void resize_vec4_wid(ivl_expr_t expr, unsigned wid)
{
      if (ivl_expr_width(expr) == wid)
	    return;

      if (ivl_expr_signed(expr))
	    fprintf(vvp_out, "    %%pad/s %u;\n", wid);
      else
	    fprintf(vvp_out, "    %%pad/u %u;\n", wid);
}

/*
 * Test if the draw_immediate_vec4 instruction can be used.
 */
int test_immediate_vec4_ok(ivl_expr_t re)
{
      const char*bits;
      unsigned idx;

      if (ivl_expr_type(re) != IVL_EX_NUMBER)
	    return 0;

      if (ivl_expr_width(re) <= 32)
	    return 1;

      bits = ivl_expr_bits(re);

      for (idx = 32 ; idx < ivl_expr_width(re) ; idx += 1) {
	    if (bits[idx] != '0')
		  return 0;
      }

      return 1;
}

static void make_immediate_vec4_words(ivl_expr_t re, unsigned long*val0p, unsigned long*valxp, unsigned*widp)
{
      unsigned long val0 = 0;
      unsigned long valx = 0;
      unsigned wid = ivl_expr_width(re);
      const char*bits = ivl_expr_bits(re);

      unsigned idx;

      for (idx = 0 ; idx < wid ; idx += 1) {
	    assert( ((val0|valx)&0x80000000UL) == 0UL );
	    val0 <<= 1;
	    valx <<= 1;
	    switch (bits[wid-idx-1]) {
		case '0':
		  break;
		case '1':
		  val0 |= 1;
		  break;
		case 'x':
		  val0 |= 1;
		  valx |= 1;
		  break;
		case 'z':
		  val0 |= 0;
		  valx |= 1;
		  break;
		default:
		  assert(0);
		  break;
	    }
      }

      *val0p = val0;
      *valxp = valx;
      *widp = wid;
}

void draw_immediate_vec4(ivl_expr_t re, const char*opcode)
{
      unsigned long val0, valx;
      unsigned wid;
      make_immediate_vec4_words(re, &val0, &valx, &wid);
      fprintf(vvp_out, "    %s %lu, %lu, %u;\n", opcode, val0, valx, wid);
}

static void draw_binary_vec4_arith(ivl_expr_t expr)
{
      ivl_expr_t le = ivl_expr_oper1(expr);
      ivl_expr_t re = ivl_expr_oper2(expr);

      unsigned lwid = ivl_expr_width(le);
      unsigned rwid = ivl_expr_width(re);
      unsigned ewid = ivl_expr_width(expr);

      int is_power_op = ivl_expr_opcode(expr) == 'p' ? 1 : 0;

	/* The power operation differs from the other arithmetic operations
	   in that we only use the signed version of the operation if the
	   right hand operand (the exponent) is signed. */
      int signed_flag = (ivl_expr_signed(le) || is_power_op) && ivl_expr_signed(re) ? 1 : 0;
      const char*signed_string = signed_flag? "/s" : "";

	/* All the arithmetic operations handled here (except for the power
	   operation) require that the operands (and the result) be the same
	   width. We further assume that the core has not given us an operand
	   wider then the expression width. So pad operands as needed. */
      draw_eval_vec4(le);
      if (lwid != ewid) {
	    fprintf(vvp_out, "    %%pad/%c %u;\n", ivl_expr_signed(le)? 's' : 'u', ewid);
      }

	/* Special case: If the re expression can be collected into an
	   immediate operand, and the instruction supports it, then
	   generate an immediate instruction instead of the generic
	   version. */
      if (rwid==ewid && test_immediate_vec4_ok(re)) {
	    switch (ivl_expr_opcode(expr)) {
		case '+':
		  draw_immediate_vec4(re, "%addi");
		  return;
		case '-':
		  draw_immediate_vec4(re, "%subi");
		  return;
		case '*':
		  draw_immediate_vec4(re, "%muli");
		  return;
		default:
		  break;
	    }
      }

      draw_eval_vec4(re);
      if ((rwid != ewid) && !is_power_op) {
	    fprintf(vvp_out, "    %%pad/%c %u;\n", ivl_expr_signed(re)? 's' : 'u', ewid);
      }

      switch (ivl_expr_opcode(expr)) {
	  case '+':
	    fprintf(vvp_out, "    %%add;\n");
	    break;
	  case '-':
	    fprintf(vvp_out, "    %%sub;\n");
	    break;
	  case '*':
	    fprintf(vvp_out, "    %%mul;\n");
	    break;
	  case '/':
	    fprintf(vvp_out, "    %%div%s;\n", signed_string);
	    break;
	  case '%':
	    fprintf(vvp_out, "    %%mod%s;\n", signed_string);
	    break;
	  case 'p':
	    fprintf(vvp_out, "    %%pow%s;\n", signed_string);
	    break;

	  default:
	    assert(0);
	    break;
      }
}

static void draw_binary_vec4_bitwise(ivl_expr_t expr)
{
      draw_eval_vec4(ivl_expr_oper1(expr));
      draw_eval_vec4(ivl_expr_oper2(expr));

      switch (ivl_expr_opcode(expr)) {
	  case '&':
	    fprintf(vvp_out, "    %%and;\n");
	    break;
	  case '|':
	    fprintf(vvp_out, "    %%or;\n");
	    break;
	  case '^':
	    fprintf(vvp_out, "    %%xor;\n");
	    break;
	  case 'A': /* ~& */
	    fprintf(vvp_out, "    %%nand;\n");
	    break;
	  case 'O': /* ~| */
	    fprintf(vvp_out, "    %%nor;\n");
	    break;
	  case 'X': /* ~^ */
	    fprintf(vvp_out, "    %%xnor;\n");
	    break;
	  default:
	    assert(0);
	    break;
      }
}

static void draw_binary_vec4_compare_real(ivl_expr_t expr)
{
      draw_eval_real(ivl_expr_oper1(expr));
      draw_eval_real(ivl_expr_oper2(expr));

      switch (ivl_expr_opcode(expr)) {
	  case 'e': /* == */
	    fprintf(vvp_out, "    %%cmp/wr;\n");
	    fprintf(vvp_out, "    %%flag_get/vec4 4;\n");
	    break;
	  case 'n': /* != */
	    fprintf(vvp_out, "    %%cmp/wr;\n");
	    fprintf(vvp_out, "    %%flag_inv 4;\n");
	    fprintf(vvp_out, "    %%flag_get/vec4 4;\n");
	    break;
	  default:
	    assert(0);
      }
}

static int expr_is_string_like_(ivl_expr_t expr)
{
      if (ivl_expr_type(expr) == IVL_EX_SIGNAL) {
            ivl_signal_t sig = ivl_expr_signal(expr);
            return sig && (ivl_signal_data_type(sig) == IVL_VT_STRING);
      }

      return (ivl_expr_value(expr) == IVL_VT_STRING)
          || (ivl_expr_type(expr) == IVL_EX_STRING);
}

static void draw_binary_vec4_compare_string(ivl_expr_t expr)
{
      draw_eval_string(ivl_expr_oper1(expr));
      draw_eval_string(ivl_expr_oper2(expr));

      switch (ivl_expr_opcode(expr)) {
	  case 'e': /* == */
	    fprintf(vvp_out, "    %%cmp/str;\n");
	    fprintf(vvp_out, "    %%flag_get/vec4 4;\n");
	    break;
	  case 'n': /* != */
	    fprintf(vvp_out, "    %%cmp/str;\n");
	    fprintf(vvp_out, "    %%flag_inv 4;\n");
	    fprintf(vvp_out, "    %%flag_get/vec4 4;\n");
	    break;
	  default:
	    assert(0);
      }
}

static void draw_binary_vec4_compare_class(ivl_expr_t expr)
{
      ivl_expr_t le = ivl_expr_oper1(expr);
      ivl_expr_t re = ivl_expr_oper2(expr);

      if (ivl_expr_type(le) == IVL_EX_NULL) {
	    ivl_expr_t tmp = le;
	    le = re;
	    re = tmp;
      }

	/* Special case: If both operands are null, then the
	   expression has a constant value. */
      if (ivl_expr_type(le)==IVL_EX_NULL && ivl_expr_type(re)==IVL_EX_NULL) {
	    switch (ivl_expr_opcode(expr)) {
		case 'e': /* == */
		  fprintf(vvp_out, "    %%pushi/vec4 1, 0, 1;\n");
		  break;
		case 'n': /* != */
		  fprintf(vvp_out, "    %%pushi/vec4 0, 0, 1;\n");
		  break;
		default:
		  assert(0);
		  break;
	    }
	    return;
      }

	/* A signal/variable is compared to null. Implement this with
	   the %test_nul statement, which peeks at the variable
	   contents directly. */
      if (ivl_expr_type(re)==IVL_EX_NULL && ivl_expr_type(le)==IVL_EX_SIGNAL) {
	    ivl_signal_t sig= ivl_expr_signal(le);

	    if (ivl_signal_dimensions(sig) == 0) {
		  fprintf(vvp_out, "    %%test_nul v%p_0;\n", sig);
	    } else {
		  ivl_expr_t word_ex = ivl_expr_oper1(le);
		  int word_ix = allocate_word();
		  draw_eval_expr_into_integer(word_ex, word_ix);
		  fprintf(vvp_out, "    %%test_nul/a v%p, %d;\n", sig, word_ix);
		  clr_word(word_ix);
	    }
	    if (ivl_expr_opcode(expr) == 'n'
	        || ivl_expr_opcode(expr) == 'N')
		  fprintf(vvp_out, "    %%flag_inv 4;\n");
	    fprintf(vvp_out, "    %%flag_get/vec4 4;\n");
	    return;
      }

      if (ivl_expr_type(re)==IVL_EX_NULL && ivl_expr_type(le)==IVL_EX_PROPERTY) {
	    ivl_signal_t sig = ivl_expr_signal(le);
	    unsigned pidx = ivl_expr_property_idx(le);
	    ivl_expr_t idx_expr = ivl_expr_oper1(le);
	    int idx = 0;
	    unsigned wid = ivl_expr_width(expr) ? ivl_expr_width(expr) : 1;

	    if (!property_is_object_expr_(le)) {
		  draw_eval_vec4(le);
		  fprintf(vvp_out, "    %%pushi/vec4 0, 0, %u;\n", wid);
		  fprintf(vvp_out, "    %%cmp/u;\n");
		  if (ivl_expr_opcode(expr) == 'n')
			fprintf(vvp_out, "    %%flag_inv 4;\n");
		  fprintf(vvp_out, "    %%flag_get/vec4 4;\n");
		  return;
	    }

	      /* If the property has an array index, then evaluate it
		 into an index register. */
	    if ( idx_expr ) {
		  idx = allocate_word();
		  draw_eval_expr_into_integer(idx_expr, idx);
	    }

	    if (sig) {
		  fprintf(vvp_out, "    %%load/obj v%p_0;\n", sig);
	    } else {
		  ivl_expr_t base_expr = ivl_expr_oper2(le);
		  draw_eval_object(base_expr);
	    }
	    fprintf(vvp_out, "    %%test_nul/prop %u, %d;\n", pidx, idx);
	    fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
	    if (ivl_expr_opcode(expr) == 'n')
		  fprintf(vvp_out, "    %%flag_inv 4;\n");
	    fprintf(vvp_out, "    %%flag_get/vec4 4;\n");

	    if (idx != 0) clr_word(idx);
	    return;
      }

      /* General case: compare two class handle expressions by pushing
         both onto the object stack and using %cmp/obj for pointer identity. */
      draw_eval_object(le);
      draw_eval_object(re);
      fprintf(vvp_out, "    %%cmp/obj;\n");
      if (ivl_expr_opcode(expr) == 'n'
          || ivl_expr_opcode(expr) == 'N')
	    fprintf(vvp_out, "    %%flag_inv 4;\n");
      fprintf(vvp_out, "    %%flag_get/vec4 4;\n");
}

static void draw_binary_vec4_compare(ivl_expr_t expr)
{
      ivl_expr_t le = ivl_expr_oper1(expr);
      ivl_expr_t re = ivl_expr_oper2(expr);

      if ((ivl_expr_value(le) == IVL_VT_REAL)
	  || (ivl_expr_value(re) == IVL_VT_REAL)) {
	    draw_binary_vec4_compare_real(expr);
	    return;
      }

      if ((ivl_expr_value(le)==IVL_VT_STRING)
	  && (ivl_expr_value(re)==IVL_VT_STRING)) {
	    draw_binary_vec4_compare_string(expr);
	    return;
      }

      if ((ivl_expr_value(le)==IVL_VT_STRING)
	  && (ivl_expr_type(re)==IVL_EX_STRING)) {
	    draw_binary_vec4_compare_string(expr);
	    return;
      }

      if ((ivl_expr_type(le)==IVL_EX_STRING)
	  && (ivl_expr_value(re)==IVL_VT_STRING)) {
	    draw_binary_vec4_compare_string(expr);
	    return;
      }

      if ((ivl_expr_value(le)==IVL_VT_CLASS)
	  && (ivl_expr_value(re)==IVL_VT_CLASS)) {
	    draw_binary_vec4_compare_class(expr);
	    return;
      }

      unsigned use_wid = ivl_expr_width(le);
      if (ivl_expr_width(re) > use_wid)
	    use_wid = ivl_expr_width(re);

      draw_eval_vec4(le);
      resize_vec4_wid(le, use_wid);

      draw_eval_vec4(re);
      resize_vec4_wid(re, use_wid);

      switch (ivl_expr_opcode(expr)) {
	  case 'e': /* == */
	    fprintf(vvp_out, "    %%cmp/e;\n");
	    fprintf(vvp_out, "    %%flag_get/vec4 4;\n");
	    break;
	  case 'n': /* != */
	    fprintf(vvp_out, "    %%cmp/ne;\n");
	    fprintf(vvp_out, "    %%flag_get/vec4 4;\n");
	    break;
	  case 'E': /* === */
	    fprintf(vvp_out, "    %%cmp/e;\n");
	    fprintf(vvp_out, "    %%flag_get/vec4 6;\n");
	    break;
	  case 'N': /* !== */
	    fprintf(vvp_out, "    %%cmp/ne;\n");
	    fprintf(vvp_out, "    %%flag_get/vec4 6;\n");
	    break;
	  case 'w': /* ==? */
	    fprintf(vvp_out, "    %%cmp/we;\n");
	    fprintf(vvp_out, "    %%flag_get/vec4 4;\n");
	    break;
	  case 'W': /* !=? */
	    fprintf(vvp_out, "    %%cmp/wne;\n");
	    fprintf(vvp_out, "    %%flag_get/vec4 4;\n");
	    break;
	  default:
	    assert(0);
      }
}

/*
 * Handle the logical implication:
 *    <le> -> <re>
 * which is the same as the expression
 *    !<le> || <re>
 *
 */
static void draw_binary_vec4_limpl(ivl_expr_t expr)
{
      ivl_expr_t le = ivl_expr_oper1(expr);
      ivl_expr_t re = ivl_expr_oper2(expr);

      /* The arguments should have alreacy been reduced. */
      assert(ivl_expr_width(le) == 1);
      assert(ivl_expr_width(re) == 1);

      draw_eval_vec4(le);
      fprintf(vvp_out, "    %%inv;\n");
      draw_eval_vec4(re);
      fprintf(vvp_out, "    %%or;\n");
}

static void draw_binary_vec4_lequiv(ivl_expr_t expr)
{
      ivl_expr_t le = ivl_expr_oper1(expr);
      ivl_expr_t re = ivl_expr_oper2(expr);

	/* The arguments should have already been reduced. */
      assert(ivl_expr_width(le) == 1);
      draw_eval_vec4(le);
      assert(ivl_expr_width(re) == 1);
      draw_eval_vec4(re);

      fprintf(vvp_out, "    %%xnor;\n");

      assert(ivl_expr_width(expr) == 1);
}

static void draw_binary_vec4_logical(ivl_expr_t expr, char op)
{
      const char *opcode;
      const char *jmp_type;

      switch (op) {
	  case 'a':
	    opcode = "and";
	    jmp_type = "0";
	    break;
	  case 'o':
	    opcode = "or";
	    jmp_type = "1";
	    break;
	  default:
	    assert(0);
	    break;
      }

      unsigned label_out = local_count++;

      ivl_expr_t le = ivl_expr_oper1(expr);
      ivl_expr_t re = ivl_expr_oper2(expr);

      /* Evaluate the left expression as a conditon and skip the right expression
       * if the left is false. */
      int flag = draw_eval_condition(le);
      fprintf(vvp_out, "    %%flag_get/vec4 %d;\n", flag);
      fprintf(vvp_out, "    %%jmp/%s T_%u.%u, %d;\n", jmp_type, thread_count,
	      label_out, flag);
      clr_flag(flag);
      /* Now push the right expression. Reduce to a single bit if necessary. */
      draw_eval_vec4(re);
      if (ivl_expr_width(re) > 1)
	    fprintf(vvp_out, "    %%or/r;\n");

      fprintf(vvp_out, "    %%%s;\n", opcode);

      fprintf(vvp_out, "T_%u.%u;\n", thread_count, label_out);
      if (ivl_expr_width(expr) > 1)
	    fprintf(vvp_out, "    %%pad/u %u;\n", ivl_expr_width(expr));
}

static void draw_binary_vec4_le_real(ivl_expr_t expr)
{
      ivl_expr_t le = ivl_expr_oper1(expr);
      ivl_expr_t re = ivl_expr_oper2(expr);

      switch (ivl_expr_opcode(expr)) {
	  case '<':
	    draw_eval_real(le);
	    draw_eval_real(re);
	    fprintf(vvp_out, "    %%cmp/wr;\n");
	    fprintf(vvp_out, "    %%flag_get/vec4 5;\n");
	    break;

	  case 'L': /* <= */
	    draw_eval_real(le);
	    draw_eval_real(re);
	    fprintf(vvp_out, "    %%cmp/wr;\n");
	    fprintf(vvp_out, "    %%flag_get/vec4 4;\n");
	    fprintf(vvp_out, "    %%flag_get/vec4 5;\n");
	    fprintf(vvp_out, "    %%or;\n");
	    break;

	  case '>':
	    draw_eval_real(re);
	    draw_eval_real(le);
	    fprintf(vvp_out, "    %%cmp/wr;\n");
	    fprintf(vvp_out, "    %%flag_get/vec4 5;\n");
	    break;

	  case 'G': /* >= */
	    draw_eval_real(re);
	    draw_eval_real(le);
	    fprintf(vvp_out, "    %%cmp/wr;\n");
	    fprintf(vvp_out, "    %%flag_get/vec4 4;\n");
	    fprintf(vvp_out, "    %%flag_get/vec4 5;\n");
	    fprintf(vvp_out, "    %%or;\n");
	    break;

	  default:
	    assert(0);
	    break;
      }
}

static void draw_binary_vec4_le_string(ivl_expr_t expr)
{
      ivl_expr_t le = ivl_expr_oper1(expr);
      ivl_expr_t re = ivl_expr_oper2(expr);

      switch (ivl_expr_opcode(expr)) {
	  case '<':
	    draw_eval_string(le);
	    draw_eval_string(re);
	    fprintf(vvp_out, "    %%cmp/str;\n");
	    fprintf(vvp_out, "    %%flag_get/vec4 5;\n");
	    break;

	  case 'L': /* <= */
	    draw_eval_string(le);
	    draw_eval_string(re);
	    fprintf(vvp_out, "    %%cmp/str;\n");
	    fprintf(vvp_out, "    %%flag_get/vec4 4;\n");
	    fprintf(vvp_out, "    %%flag_get/vec4 5;\n");
	    fprintf(vvp_out, "    %%or;\n");
	    break;

	  case '>':
	    draw_eval_string(re);
	    draw_eval_string(le);
	    fprintf(vvp_out, "    %%cmp/str;\n");
	    fprintf(vvp_out, "    %%flag_get/vec4 5;\n");
	    break;

	  case 'G': /* >= */
	    draw_eval_string(re);
	    draw_eval_string(le);
	    fprintf(vvp_out, "    %%cmp/str;\n");
	    fprintf(vvp_out, "    %%flag_get/vec4 4;\n");
	    fprintf(vvp_out, "    %%flag_get/vec4 5;\n");
	    fprintf(vvp_out, "    %%or;\n");
	    break;

	  default:
	    assert(0);
	    break;
      }
}

static void draw_binary_vec4_le(ivl_expr_t expr)
{
      ivl_expr_t le = ivl_expr_oper1(expr);
      ivl_expr_t re = ivl_expr_oper2(expr);
      ivl_expr_t tmp;

      if ((ivl_expr_value(le) == IVL_VT_REAL)
	  || (ivl_expr_value(re) == IVL_VT_REAL)) {
	    draw_binary_vec4_le_real(expr);
	    return;
      }

      char use_opcode = ivl_expr_opcode(expr);
      char s_flag = (ivl_expr_signed(le) && ivl_expr_signed(re)) ? 's' : 'u';

	/* If this is a > or >=, then convert it to < or <= by
	   swapping the operands. Adjust the opcode to match. */
      switch (use_opcode) {
	  case 'G':
	    tmp = le;
	    le = re;
	    re = tmp;
	    use_opcode = 'L';
	    break;
	  case '>':
	    tmp = le;
	    le = re;
	    re = tmp;
	    use_opcode = '<';
	    break;
      }

      if ((ivl_expr_value(le)==IVL_VT_STRING)
	  && (ivl_expr_value(re)==IVL_VT_STRING)) {
	    draw_binary_vec4_le_string(expr);
	    return;
      }

      if ((ivl_expr_value(le)==IVL_VT_STRING)
	  && (ivl_expr_type(re)==IVL_EX_STRING)) {
	    draw_binary_vec4_le_string(expr);
	    return;
      }

      if ((ivl_expr_type(le)==IVL_EX_STRING)
	  && (ivl_expr_value(re)==IVL_VT_STRING)) {
	    draw_binary_vec4_le_string(expr);
	    return;
      }

	/* NOTE: I think I would rather the elaborator handle the
	   operand widths. When that happens, take this code out. */

      unsigned use_wid = ivl_expr_width(le);
      if (ivl_expr_width(re) > use_wid)
	    use_wid = ivl_expr_width(re);

      draw_eval_vec4(le);
      resize_vec4_wid(le, use_wid);

      if (ivl_expr_width(re)==use_wid && test_immediate_vec4_ok(re)) {
	      /* Special case: If the right operand can be handled as
		 an immediate operand, then use that instead. */
	    char opcode[8];
	    snprintf(opcode, sizeof opcode, "%%cmpi/%c", s_flag);
	    draw_immediate_vec4(re, opcode);

      } else {
	    draw_eval_vec4(re);
	    resize_vec4_wid(re, use_wid);

	    fprintf(vvp_out, "    %%cmp/%c;\n", s_flag);
      }

      switch (use_opcode) {
	  case 'L':
	    fprintf(vvp_out, "    %%flag_get/vec4 4;\n");
	    fprintf(vvp_out, "    %%flag_get/vec4 5;\n");
	    fprintf(vvp_out, "    %%or;\n");
	    break;
	  case '<':
	    fprintf(vvp_out, "    %%flag_get/vec4 5;\n");
	    break;
	  default:
	    assert(0);
	    break;
      }
}

static void draw_binary_vec4_lrs(ivl_expr_t expr)
{
      ivl_expr_t le = ivl_expr_oper1(expr);
      ivl_expr_t re = ivl_expr_oper2(expr);

	// Push the left expression onto the stack.
      draw_eval_vec4(le);

	// Calculate the shift amount into an index register.
      int use_index_reg = allocate_word();
      assert(use_index_reg >= 0);
      draw_eval_expr_into_integer(re, use_index_reg);

	// Emit the actual shift instruction. This will pop the top of
	// the stack and replace it with the result of the shift.
      switch (ivl_expr_opcode(expr)) {
	  case 'l': /* << */
	    fprintf(vvp_out, "    %%shiftl %d;\n", use_index_reg);
	    break;
	  case 'r': /* >> */
	    fprintf(vvp_out, "    %%shiftr %d;\n", use_index_reg);
	    break;
	  case 'R': /* >>> */
	    if (ivl_expr_signed(le))
		  fprintf(vvp_out, "    %%shiftr/s %d;\n", use_index_reg);
	    else
		  fprintf(vvp_out, "    %%shiftr %d;\n", use_index_reg);
	    break;
	  default:
	    assert(0);
	    break;
      }

      clr_word(use_index_reg);
}

static void draw_binary_vec4(ivl_expr_t expr)
{
      switch (ivl_expr_opcode(expr)) {
	  case 'a': /* Logical && */
	  case 'o': /* || (logical or) */
	    draw_binary_vec4_logical(expr, ivl_expr_opcode(expr));
	    break;

	  case '+':
	  case '-':
	  case '*':
	  case '/':
	  case '%':
	  case 'p': /* ** (power) */
	    draw_binary_vec4_arith(expr);
	    break;

	  case '&':
	  case '|':
	  case '^':
	  case 'A': /* NAND (~&) */
	  case 'O': /* NOR  (~|) */
	  case 'X': /* exclusive nor (~^) */
	    draw_binary_vec4_bitwise(expr);
	    break;

	  case 'e': /* == */
	  case 'E': /* === */
	  case 'n': /* != */
	  case 'N': /* !== */
	  case 'w': /* ==? */
	  case 'W': /* !=? */
	    draw_binary_vec4_compare(expr);
	    break;

	  case 'G': /* >= */
	  case 'L': /* <= */
	  case '>':
	  case '<':
	    draw_binary_vec4_le(expr);
	    break;

	  case 'l': /* << */
	  case 'r': /* >> */
	  case 'R': /* >>> */
	    draw_binary_vec4_lrs(expr);
	    break;

	  case 'q': /* -> (logical implication) */
	    draw_binary_vec4_limpl(expr);
	    break;

	  case 'Q': /* <-> (logical equivalence) */
	    draw_binary_vec4_lequiv(expr);
	    break;

	  default:
	    fprintf(stderr, "vvp.tgt error: unsupported binary (%c)\n",
		    ivl_expr_opcode(expr));
	    assert(0);
      }
}

/*
 * This handles two special cases:
 *   1) Making a large IVL_EX_NUMBER as an immediate value. In this
 *   case, start with a %pushi/vec4 to get the stack started, then
 *   continue with %concati/vec4 instructions to build that number
 *   up.
 *
 *   2) Concatenating a large IVL_EX_NUMBER to the current top of the
 *   stack. In this case, start with %concati/vec4 and continue
 *   generating %concati/vec4 instructions to finish up the large number.
 */
static void draw_concat_number_vec4(ivl_expr_t expr, int as_concati)
{
      unsigned long val0 = 0;
      unsigned long valx = 0;
      unsigned wid = ivl_expr_width(expr);
      const char*bits = ivl_expr_bits(expr);

      if (number_trace_enabled_()) {
            fprintf(stderr,
                    "trace num: file=%s line=%u expr_type=%d expr_value=%d width=%u bits=",
                    ivl_expr_file(expr), ivl_expr_lineno(expr),
                    ivl_expr_type(expr), ivl_expr_value(expr), wid);
            if (bits && wid)
                  fwrite(bits, 1, wid, stderr);
            fprintf(stderr, " as_concati=%d\n", as_concati);
      }

      unsigned idx;
      int accum = 0;
      int count_pushi = as_concati? 1 : 0;

	/* Scan the literal bits, MSB first. */
      for (idx = 0 ; idx < wid ; idx += 1) {
	    val0 <<= 1;
	    valx <<= 1;
	    switch (bits[wid-idx-1]) {
		case '0':
		  break;
		case '1':
		  val0 |= 1;
		  break;
		case 'x':
		  val0 |= 1;
		  valx |= 1;
		  break;
		case 'z':
		  val0 |= 0;
		  valx |= 1;
		  break;
		default:
		  assert(0);
		  break;
	    }
	    accum += 1;

	      /* Collect as many bits as can be written by a single
		 %pushi/vec4 instruction. This may be more than 32 if
		 the higher bits are zero, but if the currently
		 accumulated value fills what a %pushi/vec4 can do,
		 then write it out, generate a %concat/vec4, and set
		 up to handle more bits. */
	    if ( (val0|valx) & 0x80000000UL ) {
		  if (count_pushi) {
			fprintf(vvp_out, "    %%concati/vec4 %lu, %lu, %d;\n",
				val0, valx, accum);

		  } else {
			fprintf(vvp_out, "    %%pushi/vec4 %lu, %lu, %d;\n",
				val0, valx, accum);
		  }

		  accum = 0;
		  val0 = 0;
		  valx = 0;

		  count_pushi += 1;
	    }
      }

      if (accum) {
	    if (count_pushi) {
		  fprintf(vvp_out, "    %%concati/vec4 %lu, %lu, %d;\n",
			  val0, valx, accum);
	    } else {
		  fprintf(vvp_out, "    %%pushi/vec4 %lu, %lu, %d;\n",
			  val0, valx, accum);
	    }
      }
}

static void draw_concat_vec4(ivl_expr_t expr)
{
	/* Repeat the concatenation this many times to make a
	   super-concatenation. */
      unsigned repeat = ivl_expr_repeat(expr);
	/* This is the number of expressions that go into the
	   concatenation. */
      unsigned num_sube = ivl_expr_parms(expr);
      unsigned sub_idx = 0;
      ivl_expr_t sube;

      assert(num_sube > 0);

	/* Start with the most-significant bits. */
      sube = ivl_expr_parm(expr, sub_idx);
      draw_eval_vec4(sube);
	/* Evaluate, but skip any zero replication expressions at the
	 * head of this concatenation. */
      while ((ivl_expr_type(sube) == IVL_EX_CONCAT) &&
             (ivl_expr_repeat(sube) == 0)) {
	    fprintf(vvp_out, "    %%pop/vec4 1; skip zero replication\n");
	    sub_idx += 1;
	    sube = ivl_expr_parm(expr, sub_idx);
	    draw_eval_vec4(sube);
      }

      for ( sub_idx += 1 ; sub_idx < num_sube ; sub_idx += 1) {
	      /* Concatenate progressively lower parts. */
	    sube = ivl_expr_parm(expr, sub_idx);

	      /* Special case: The next expression is a NUMBER that
		 can be concatenated using %concati/vec4
		 instructions. */
	    if (ivl_expr_type(sube) == IVL_EX_NUMBER) {
		  draw_concat_number_vec4(sube, 1);
		  continue;
	    }

	    draw_eval_vec4(sube);
	      /* Evaluate, but skip any zero replication expressions in the
	       * rest of this concatenation. */
	    if ((ivl_expr_type(sube) == IVL_EX_CONCAT) &&
	        (ivl_expr_repeat(sube) == 0)) {
		  fprintf(vvp_out, "    %%pop/vec4 1; skip zero replication\n");
		  continue;
	    }
	    fprintf(vvp_out, "    %%concat/vec4; draw_concat_vec4\n");
      }

      if (repeat > 1) {
	    fprintf(vvp_out, "    %%replicate %u;\n", repeat);
      }
}

/*
 * Push a number into the vec4 stack using %pushi/vec4
 * instructions. The %pushi/vec4 instruction can only handle up to 32
 * non-zero bits, so if there are more than that, then generate
 * multiple %pushi/vec4 statements, and use %concat/vec4 statements to
 * concatenate the vectors into the desired result.
 */
static void draw_number_vec4(ivl_expr_t expr)
{
      draw_concat_number_vec4(expr, 0);
}

static void draw_property_vec4(ivl_expr_t expr)
{
      ivl_signal_t sig = ivl_expr_signal(expr);
      ivl_expr_t idx_expr = ivl_expr_oper1(expr);
      ivl_expr_t base_expr = ivl_expr_oper2(expr);
      unsigned lab_null = local_count++;
      unsigned lab_out = local_count++;
      int idx_word = 0;
      int queue_indexed = property_is_indexed_queue_expr_(expr);
      int assoc_indexed = property_is_assoc_indexed_expr_(expr);
      unsigned pidx = ivl_expr_property_idx(expr);

      if (idx_expr && !queue_indexed && !assoc_indexed) {
	    idx_word = allocate_word();
	    draw_eval_expr_into_integer(idx_expr, idx_word);
      }

      if (sig) {
	    fprintf(vvp_out, "    %%load/obj v%p_0;\n", sig);
      } else if (base_expr && ivl_expr_type(base_expr) == IVL_EX_NULL) {
	      /* Compile-progress fallback: null receiver property access
	         yields all-zero vector value. */
	    fprintf(vvp_out, "    %%pushi/vec4 0, 0, %u;\n", ivl_expr_width(expr));
	    return;
      } else {
	    draw_eval_object(base_expr);
      }
      fprintf(vvp_out, "    %%test_nul/obj;\n");
      fprintf(vvp_out, "    %%jmp/1 T_%u.%u, 4;\n", thread_count, lab_null);
      if (assoc_indexed) {
            const char*key_kind;
	    fprintf(vvp_out, "    %%prop/obj %u, 0; eval_assoc_property\n", pidx);
            key_kind = draw_eval_assoc_key_(idx_expr, 0);
	    fprintf(vvp_out, "    %%aa/load/v/%s %u;\n", key_kind, ivl_expr_width(expr));
	    if (ivl_expr_value(expr) == IVL_VT_BOOL)
		  fprintf(vvp_out, "    %%cast2;\n");
	    fprintf(vvp_out, "    %%pop/obj 2, 0;\n");
	      } else if (queue_indexed) {
		    if (!emit_property_queue_last_index_(expr, pidx, 3))
			  draw_eval_expr_into_integer(idx_expr, 3);
		    fprintf(vvp_out, "    %%prop/obj %u, 0; eval_queue_property\n", pidx);
		    fprintf(vvp_out, "    %%load/qo/v %u;\n", ivl_expr_width(expr));
		    if (ivl_expr_value(expr) == IVL_VT_BOOL)
			  fprintf(vvp_out, "    %%cast2;\n");
		    fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
	      } else if (idx_word)
	    fprintf(vvp_out, "    %%prop/v/i %u, %d;\n", pidx, idx_word);
      else
	    fprintf(vvp_out, "    %%prop/v %u;\n", pidx);
      if (!assoc_indexed && !queue_indexed)
	    fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
      fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_out);
      fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_null);
      fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
      fprintf(vvp_out, "    %%pushi/vec4 0, 0, %u;\n", ivl_expr_width(expr));
      fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_out);
      if (idx_word)
	    clr_word(idx_word);
}

static void draw_select_vec4(ivl_expr_t expr)
{
	// This is the sub-expression to part-select.
      ivl_expr_t subexpr = ivl_expr_oper1(expr);
	// This is the base of the part select
      ivl_expr_t base = ivl_expr_oper2(expr);
	// This is the part select width
      unsigned wid = ivl_expr_width(expr);
	// Is the select base expression signed or unsigned?
      char sign_suff = ivl_expr_signed(base)? 's' : 'u';

	// Special Case: If the sub-expression is a STRING, then this
	// is a select from that string.
      if (ivl_expr_value(subexpr)==IVL_VT_STRING) {
	    assert(base);
	    assert(wid==8);
	    draw_eval_string(subexpr);
	    int base_idx = allocate_word();
	    draw_eval_expr_into_integer(base, base_idx);
	    fprintf(vvp_out, "    %%substr/vec4 %d, %u;\n", base_idx, wid);
	    fprintf(vvp_out, "    %%pop/str 1;\n");
	    clr_word(base_idx);
	    return;
      }

      if (expr_is_queue_container_(subexpr) &&
          ivl_expr_type(subexpr) != IVL_EX_SIGNAL) {
	    assert(base);
	    draw_eval_object(subexpr);
	    draw_eval_expr_into_integer(base, 3);
	    fprintf(vvp_out, "    %%load/qo/v %u;\n", wid);
	    if (ivl_expr_value(expr) == IVL_VT_BOOL)
		  fprintf(vvp_out, "    %%cast2;\n");
	    return;
      }

      if (ivl_expr_value(subexpr)==IVL_VT_DARRAY) {
	    ivl_signal_t sig = ivl_expr_signal(subexpr);
            ivl_type_t net_type;
	    assert(sig);
            net_type = ivl_signal_net_type(sig);
	    assert( (ivl_signal_data_type(sig)==IVL_VT_DARRAY)
		    || (ivl_signal_data_type(sig)==IVL_VT_QUEUE) );

	    assert(base);
            if (net_type && ivl_type_queue_assoc_compat(net_type)
                && expr_is_object_assoc_key_(base)) {
                  draw_eval_object(base);
                  fprintf(vvp_out, "    %%aa/load/sig/v/obj v%p_0, %u;\n", sig, wid);
                  if (ivl_expr_value(expr) == IVL_VT_BOOL)
                        fprintf(vvp_out, "    %%cast2;\n");
                  return;
            }
	    draw_eval_expr_into_integer(base, 3);
	    fprintf(vvp_out, "    %%load/dar/vec4 v%p_0;\n", sig);
	    if (ivl_expr_value(expr) == IVL_VT_BOOL)
		  fprintf(vvp_out, "    %%cast2;\n");

	    return;
      }

      if (test_immediate_vec4_ok(base)) {
	    unsigned long val0, valx;
	    unsigned base_wid;
	    make_immediate_vec4_words(base, &val0, &valx, &base_wid);
	    assert(valx == 0);

	    draw_eval_vec4(subexpr);
	    fprintf(vvp_out, "    %%parti/%c %u, %lu, %u;\n",
		    sign_suff, wid, val0, base_wid);

      } else {
	    draw_eval_vec4(subexpr);
	    draw_eval_vec4(base);
	    fprintf(vvp_out, "    %%part/%c %u;\n", sign_suff, wid);
      }
}

static void draw_select_pad_vec4(ivl_expr_t expr)
{
	// This is the sub-expression to pad/truncate
      ivl_expr_t subexpr = ivl_expr_oper1(expr);
	// This is the target width of the expression
      unsigned wid = ivl_expr_width(expr);

	// Push the sub-expression onto the stack.
      draw_eval_vec4(subexpr);

	// Special case: The expression is already the correct width,
	// so there is nothing to be done.
      if (wid == ivl_expr_width(subexpr))
	    return;

      if (ivl_expr_signed(expr))
	    fprintf(vvp_out, "    %%pad/s %u;\n", wid);
      else
	    fprintf(vvp_out, "    %%pad/u %u;\n", wid);
}

/*
 * This function handles the special case of a call to the internal
 * functions $ivl_queue_method$pop_back et al. The first (and only)
 * argument is the signal that represents a dynamic queue. Generate a
 * %qpop instruction to pop a value and push it to the vec4 stack.
 */
static void draw_darray_pop(ivl_expr_t expr)
{
      static int warned_non_signal_pop = 0;
      const char*fb;

      if (strcmp(ivl_expr_name(expr), "$ivl_queue_method$pop_back")==0)
	    fb = "b";
      else
	    fb = "f";

      ivl_expr_t arg = ivl_expr_parm(expr, 0);
      if (ivl_expr_type(arg) != IVL_EX_SIGNAL) {
	    if (expr_is_queue_container_(arg)) {
		  draw_eval_object(arg);
		  fprintf(vvp_out, "    %%qpop/o/%s/v %u;\n",
		          fb, ivl_expr_width(expr) ? ivl_expr_width(expr) : 1);
		  return;
	    }
	    if (!warned_non_signal_pop) {
		  fprintf(stderr, "Warning: %s requires signal, got expr type %d;"
			  " emitting zero fallback"
			  " (further similar warnings suppressed)\n",
			  ivl_expr_name(expr), ivl_expr_type(arg));
		  warned_non_signal_pop = 1;
	    }
	    fprintf(vvp_out, "    %%pushi/vec4 0, 0, %u;"
		    " ; pop fallback\n", ivl_expr_width(expr) ? ivl_expr_width(expr) : 1);
	    return;
      }

      fprintf(vvp_out, "    %%qpop/%s/v v%p_0, %u;\n", fb, ivl_expr_signal(arg),
                       ivl_expr_width(expr));
}

static int draw_assoc_exists_vec4(ivl_expr_t expr)
{
      ivl_expr_t recv;
      ivl_expr_t key;
      ivl_signal_t sig;
      unsigned wid = ivl_expr_width(expr) ? ivl_expr_width(expr) : 1;

      if (ivl_expr_parms(expr) != 2)
	    return 0;

      recv = ivl_expr_parm(expr, 0);
      key = ivl_expr_parm(expr, 1);
      if (!recv || !key)
	    return 0;

      sig = signal_assoc_queue_receiver_(recv);
      if (sig) {
            const char*key_kind = draw_eval_assoc_key_(key, 0);
	    fprintf(vvp_out, "    %%aa/exists/sig/%s v%p_0, %u;\n", key_kind, sig, wid);
      } else {
            const char*key_kind;
	    draw_eval_object(recv);
            key_kind = draw_eval_assoc_key_(key, 0);
	    fprintf(vvp_out, "    %%aa/exists/%s %u;\n", key_kind, wid);
      }
      return 1;
}

static int draw_assoc_traversal_vec4(ivl_expr_t expr)
{
      ivl_expr_t recv;
      ivl_expr_t key;
      ivl_signal_t recv_sig;
      ivl_signal_t key_sig;
      const char*key_kind;
      const char*method_name;
      unsigned wid = ivl_expr_width(expr) ? ivl_expr_width(expr) : 1;
      static int warned_bad_key = 0;

      if (ivl_expr_parms(expr) != 2)
	    return 0;

      recv = ivl_expr_parm(expr, 0);
      key = ivl_expr_parm(expr, 1);
      if (!recv || !key)
	    return 0;

      if ((ivl_expr_type(key) != IVL_EX_SIGNAL && ivl_expr_type(key) != IVL_EX_ARRAY)
          || !(key_sig = ivl_expr_signal(key))) {
	    if (!warned_bad_key) {
		  fprintf(stderr,
		          "Warning: assoc traversal methods require a signal key lvalue;"
		          " emitting zero fallback (further similar warnings suppressed)\n");
		  warned_bad_key = 1;
	    }
	    fprintf(vvp_out, "    %%pushi/vec4 0, 0, %u;\n", wid);
	    return 1;
      }

      if (strcmp(ivl_expr_name(expr), "$ivl_assoc_method$first") == 0)
	    method_name = "first";
      else if (strcmp(ivl_expr_name(expr), "$ivl_assoc_method$last") == 0)
	    method_name = "last";
      else if (strcmp(ivl_expr_name(expr), "$ivl_assoc_method$next") == 0)
	    method_name = "next";
      else if (strcmp(ivl_expr_name(expr), "$ivl_assoc_method$prev") == 0)
	    method_name = "prev";
      else
	    return 0;

      if (expr_is_string_assoc_key_(key))
	    key_kind = "str";
      else if (expr_is_object_assoc_key_(key))
	    key_kind = "obj";
      else
	    key_kind = "v";

      recv_sig = signal_assoc_queue_receiver_(recv);
      if (recv_sig) {
	    fprintf(vvp_out, "    %%aa/%s/sig/%s v%p_0, v%p_0;\n",
	            method_name, key_kind, recv_sig, key_sig);
      } else {
	    draw_eval_object(recv);
	    fprintf(vvp_out, "    %%aa/%s/%s v%p_0, %u;\n",
	            method_name, key_kind, key_sig, wid);
      }

      return 1;
}

static void draw_sfunc_vec4(ivl_expr_t expr)
{
      unsigned parm_count = ivl_expr_parms(expr);

	/* Special case: If there are no arguments to print, then the
	   %vpi_call statement is easy to draw. */
      if (parm_count == 0) {
	    assert(ivl_expr_value(expr)==IVL_VT_LOGIC
		   || ivl_expr_value(expr)==IVL_VT_BOOL);

	    fprintf(vvp_out, "    %%vpi_func %u %u \"%s\" %u {0 0 0 0};\n",
		    ivl_file_table_index(ivl_expr_file(expr)),
		    ivl_expr_lineno(expr), ivl_expr_name(expr),
		    ivl_expr_width(expr));
	    return;
      }

      if (strcmp(ivl_expr_name(expr), "$ivl_queue_method$pop_back")==0) {
	    draw_darray_pop(expr);
	    return;
      }
      if (strcmp(ivl_expr_name(expr),"$ivl_queue_method$pop_front")==0) {
	    draw_darray_pop(expr);
	    return;
      }
      if (strcmp(ivl_expr_name(expr),"$ivl_class_method$randomize")==0) {
	    ivl_expr_t arg = (parm_count > 0) ? ivl_expr_parm(expr, 0) : 0;
	    if (arg) {
		  draw_eval_object(arg);
	    }
	      /* %randomize peeks at the object stack and pops it, then
	       * pushes 1 (success) onto the vec4 stack. */
	    fprintf(vvp_out, "    %%randomize;\n");
	    return;
      }
      if (strcmp(ivl_expr_name(expr),"$ivl_queue_method$size")==0) {
	    ivl_expr_t arg = ivl_expr_parm(expr, 0);
	    if (arg && ivl_expr_type(arg) == IVL_EX_SIGNAL && ivl_expr_signal(arg)) {
		  fprintf(vvp_out, "    %%qsize v%p_0;\n", ivl_expr_signal(arg));
		  return;
	    }
	    if (expr_is_queue_container_(arg)) {
		  draw_eval_object(arg);
		  fprintf(vvp_out, "    %%qsize/o;\n");
		  return;
	    }
	    fprintf(vvp_out, "    %%pushi/vec4 0, 0, %u;\n",
	            ivl_expr_width(expr) ? ivl_expr_width(expr) : 1);
	    return;
      }
      if (strcmp(ivl_expr_name(expr), "$ivl_assoc_method$exists")==0) {
	    if (draw_assoc_exists_vec4(expr))
		  return;
      }
      /* AA .num() — load the array as an object then use %qsize/o which
       * calls dynamic_collection_size_() supporting vvp_assoc_base,
       * vvp_darray, and vvp_queue objects. */
      if (strcmp(ivl_expr_name(expr), "$ivl_assoc_method$num") == 0) {
	    ivl_expr_t arg = (parm_count > 0) ? ivl_expr_parm(expr, 0) : 0;
	    unsigned wid = ivl_expr_width(expr) ? ivl_expr_width(expr) : 32;
	    if (arg) {
		  draw_eval_object(arg);
		  fprintf(vvp_out, "    %%qsize/o;\n");
	    } else {
		  fprintf(vvp_out, "    %%pushi/vec4 0, 0, %u;\n", wid);
	    }
	    return;
      }
      if (strncmp(ivl_expr_name(expr), "$ivl_assoc_method$", 18) == 0) {
	    if (draw_assoc_traversal_vec4(expr))
		  return;
      }

      /* Semaphore try_get: $ivl_semaphore$try_get(sem, [n]) -> bit on vec4 */
      if (strcmp(ivl_expr_name(expr), "$ivl_semaphore$try_get") == 0) {
	    ivl_expr_t sem_e = (parm_count > 0) ? ivl_expr_parm(expr, 0) : 0;
	    if (sem_e) draw_eval_object(sem_e);
	    if (parm_count > 1) {
		  draw_eval_vec4(ivl_expr_parm(expr, 1));
	    } else {
		  fprintf(vvp_out, "    %%pushi/vec4 1, 0, 32;\n");
	    }
	    fprintf(vvp_out, "    %%sem/try_get;\n");
	    /* widen result to match expression width */
	    if (ivl_expr_width(expr) > 1)
		  fprintf(vvp_out, "    %%pad/u %u;\n", ivl_expr_width(expr));
	    return;
      }

      /* Mailbox num: $ivl_mailbox$num(mbx) -> int on vec4 */
      if (strcmp(ivl_expr_name(expr), "$ivl_mailbox$num") == 0) {
	    ivl_expr_t mbx_e = (parm_count > 0) ? ivl_expr_parm(expr, 0) : 0;
	    if (mbx_e) draw_eval_object(mbx_e);
	    fprintf(vvp_out, "    %%mbx/num;\n");
	    if (ivl_expr_width(expr) > 1)
		  fprintf(vvp_out, "    %%pad/u %u;\n", ivl_expr_width(expr));
	    return;
      }

      /* Mailbox try_put: $ivl_mailbox$try_put(mbx, item) -> bit on vec4 */
      if (strcmp(ivl_expr_name(expr), "$ivl_mailbox$try_put") == 0) {
	    ivl_expr_t mbx_e  = (parm_count > 0) ? ivl_expr_parm(expr, 0) : 0;
	    ivl_expr_t item_e = (parm_count > 1) ? ivl_expr_parm(expr, 1) : 0;
	    if (mbx_e)  draw_eval_object(mbx_e);
	    if (item_e) {
		  if (ivl_expr_value(item_e) == IVL_VT_CLASS) {
			draw_eval_object(item_e);
		  } else {
			unsigned wid = ivl_expr_width(item_e);
			if (!wid) wid = 32;
			draw_eval_vec4(item_e);
			fprintf(vvp_out, "    %%box/vec4 %u;\n", wid);
		  }
	    } else {
		  fprintf(vvp_out, "    %%null;\n");
	    }
	    fprintf(vvp_out, "    %%mbx/try_put;\n");
	    if (ivl_expr_width(expr) > 1)
		  fprintf(vvp_out, "    %%pad/u %u;\n", ivl_expr_width(expr));
	    return;
      }

      /* Mailbox try_get/try_peek: $ivl_mailbox$try_get/peek(mbx[, item]) -> bit */
      if (strcmp(ivl_expr_name(expr), "$ivl_mailbox$try_get") == 0 ||
          strcmp(ivl_expr_name(expr), "$ivl_mailbox$try_peek") == 0) {
	    int is_peek = (strcmp(ivl_expr_name(expr), "$ivl_mailbox$try_peek") == 0);
	    ivl_expr_t mbx_e  = (parm_count > 0) ? ivl_expr_parm(expr, 0) : 0;
	    ivl_expr_t item_e = (parm_count > 1) ? ivl_expr_parm(expr, 1) : 0;
	    if (mbx_e) draw_eval_object(mbx_e);
	    fprintf(vvp_out, "    %s;\n", is_peek ? "%mbx/try_peek" : "%mbx/try_get");
	    /* If there's an item output arg (signal), store the result */
	    if (item_e && ivl_expr_type(item_e) == IVL_EX_SIGNAL
		&& ivl_expr_signal(item_e)) {
		  ivl_signal_t sig = ivl_expr_signal(item_e);
		  if (ivl_signal_data_type(sig) == IVL_VT_CLASS) {
			fprintf(vvp_out, "    %%store/obj v%p_0;\n", sig);
		  } else {
			unsigned wid = ivl_signal_width(sig);
			if (!wid) wid = 32;
			fprintf(vvp_out, "    %%unbox/vec4 %u;\n", wid);
			fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, %u;\n", sig, wid);
		  }
	    } else {
		  /* No output var — discard item off obj stack */
		  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
	    }
	    if (ivl_expr_width(expr) > 1)
		  fprintf(vvp_out, "    %%pad/u %u;\n", ivl_expr_width(expr));
	    return;
      }

      draw_vpi_func_call(expr);
}

static void draw_signal_vec4(ivl_expr_t expr)
{
      ivl_signal_t sig = ivl_expr_signal(expr);

	/* Special Case: If the signal is the return value of the function,
	   then use a different opcode to get the value. */
      if (signal_is_return_value(sig)) {
	    assert(ivl_signal_dimensions(sig) == 0);
	    fprintf(vvp_out, "    %%retload/vec4 0; Load %s (draw_signal_vec4)\n",
		    ivl_signal_basename(sig));
	    return;
      }

	/* Handle the simple case, a signal expression that is a
	   simple vector, no array dimensions. */
      if (ivl_signal_dimensions(sig) == 0) {
	    fprintf(vvp_out, "    %%load/vec4 v%p_0;\n", sig);
	    return;
      }

	/* calculate the array index... */
      int addr_index = allocate_word();
      draw_eval_expr_into_integer(ivl_expr_oper1(expr), addr_index);

      note_array_signal_use(sig);
      fprintf(vvp_out, "    %%load/vec4a v%p, %d;\n", sig, addr_index);
      clr_word(addr_index);
}

static void draw_string_vec4(ivl_expr_t expr)
{
      unsigned wid = ivl_expr_width(expr);
      char*fp = process_octal_codes(ivl_expr_string(expr), wid);
      char*p = fp;

      unsigned long tmp = 0;
      unsigned tmp_wid = 0;
      int push_flag = 0;

      for (unsigned idx = 0 ; idx < wid ; idx += 8) {
	    tmp <<= 8;
	    tmp |= (unsigned long)*p;
	    p += 1;
	    tmp_wid += 8;
	    if (tmp_wid == 32) {
		  fprintf(vvp_out, "    %%pushi/vec4 %lu, 0, 32; draw_string_vec4\n", tmp);
		  tmp = 0;
		  tmp_wid = 0;
		  if (push_flag == 0)
			push_flag += 1;
		  else
			fprintf(vvp_out, "    %%concat/vec4; draw_string_vec4\n");
	    }
      }

      if (tmp_wid > 0) {
	    fprintf(vvp_out, "    %%pushi/vec4 %lu, 0, %u; draw_string_vec4\n", tmp, tmp_wid);
	    if (push_flag != 0)
		  fprintf(vvp_out, "    %%concat/vec4; draw_string_vec4\n");
      }

      free(fp);
}

static void draw_ternary_vec4(ivl_expr_t expr)
{
      ivl_expr_t cond = ivl_expr_oper1(expr);
      ivl_expr_t true_ex = ivl_expr_oper2(expr);
      ivl_expr_t false_ex = ivl_expr_oper3(expr);

      unsigned lab_true  = local_count++;
      unsigned lab_out   = local_count++;

      int use_flag = draw_eval_condition(cond);

	/* The condition flag is used after possibly other statements,
	   so we need to put it into a non-common place. Allocate a
	   safe flag bit and move the condition to the flag position. */
      if (use_flag < 8) {
	    int tmp_flag = allocate_flag();
	    assert(tmp_flag >= 8);
	    fprintf(vvp_out, "    %%flag_mov %d, %d;\n", tmp_flag, use_flag);
	    use_flag = tmp_flag;
      }

      fprintf(vvp_out, "    %%jmp/0 T_%u.%u, %d;\n", thread_count, lab_true, use_flag);

	/* If the condition is true or xz (not false), we need the true
	   expression. If the condition is true, then we ONLY need the
	   true expression. */
      draw_eval_vec4(true_ex);
      fprintf(vvp_out, "    %%jmp/1 T_%u.%u, %d;\n", thread_count, lab_out, use_flag);
      fprintf(vvp_out, "T_%u.%u ; End of true expr.\n", thread_count, lab_true);

	/* If the condition is false or xz (not true), we need the false
	   expression. If the condition is false, then we ONLY need
	   the false expression. */
      draw_eval_vec4(false_ex);
      fprintf(vvp_out, "    %%jmp/0 T_%u.%u, %d;\n", thread_count, lab_out, use_flag);
      fprintf(vvp_out, " ; End of false expr.\n");

	/* Here, the condition is not true or false, it is xz. Both
	   the true and false expressions have been pushed onto the
	   stack, we just need to blend the bits. */
      fprintf(vvp_out, "    %%blend;\n");
      fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_out);

      clr_flag(use_flag);
}

static void draw_unary_inc_dec(ivl_expr_t sub, bool incr, bool pre)
{
      ivl_signal_t sig = 0;
      unsigned wid = 0;
      unsigned pidx = 0;
      ivl_expr_t prop_base = 0;
      ivl_expr_t prop_word = 0;
      bool is_property = false;
      unsigned lab_null = 0;
      unsigned lab_out = 0;

	      switch (ivl_expr_type(sub)) {
	  case IVL_EX_SELECT: {
		ivl_expr_t e1 = ivl_expr_oper1(sub);
		sig = ivl_expr_signal(e1);
		wid = ivl_expr_width(e1);
		break;
	  }

	  case IVL_EX_SIGNAL:
	    sig = ivl_expr_signal(sub);
	    wid = ivl_expr_width(sub);
	    break;

	  case IVL_EX_PROPERTY:
	    pidx = ivl_expr_property_idx(sub);
	    prop_base = ivl_expr_oper2(sub);
	    prop_word = ivl_expr_oper1(sub);
	    wid = ivl_expr_width(sub);
	    if ((pidx == (unsigned)-1) || !prop_base || prop_word) {
		  draw_eval_vec4(sub);
		  return;
	    }
	    is_property = true;
	    lab_null = local_count++;
	    lab_out = local_count++;
	    break;

		  default:
		    fprintf(stderr, "%s:%u: vvp.tgt sorry: ++/-- on expression type %d "
		                    "not fully supported; using read-only fallback.\n",
			    ivl_expr_file(sub), ivl_expr_lineno(sub), ivl_expr_type(sub));
		    draw_eval_vec4(sub);
		    return;
	      }

      if (is_property) {
	    draw_eval_object(prop_base);
	    fprintf(vvp_out, "    %%test_nul/obj;\n");
	    fprintf(vvp_out, "    %%jmp/1 T_%u.%u, 4;\n", thread_count, lab_null);
	    fprintf(vvp_out, "    %%prop/v %u;\n", pidx);
      } else {
	    draw_eval_vec4(sub);
      }

      const char*cmd = incr? "%add" : "%sub";

      if (pre) {
	      /* prefix means we add the result first, and store the
		 result, as well as leaving a copy on the stack. */
	    fprintf(vvp_out, "    %si 1, 0, %u;\n", cmd, wid);
	    fprintf(vvp_out, "    %%dup/vec4;\n");
	    if (is_property) {
		  fprintf(vvp_out, "    %%store/prop/v %u, %u;\n", pidx, wid);
	    } else {
		  fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, %u;\n", sig, wid);
	    }

      } else {
	      /* The post-fix decrement returns the non-decremented
		 version, so there is a slight re-arrange. */
	    fprintf(vvp_out, "    %%dup/vec4;\n");
	    fprintf(vvp_out, "    %si 1, 0, %u;\n", cmd, wid);
	    if (is_property) {
		  fprintf(vvp_out, "    %%store/prop/v %u, %u;\n", pidx, wid);
	    } else {
		  fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, %u;\n", sig, wid);
	    }
      }

      if (is_property) {
	    fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
	    fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_out);
	    fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_null);
	    fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
	    fprintf(vvp_out, "    %%pushi/vec4 0, 0, %u;\n", wid);
	    fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_out);
      }
}

static void draw_unary_vec4(ivl_expr_t expr)
{
      ivl_expr_t sub = ivl_expr_oper1(expr);

      if (debug_draw) {
	    fprintf(vvp_out, " ; %s:%u:draw_unary_vec4: opcode=%c\n",
		    ivl_expr_file(expr), ivl_expr_lineno(expr),
		    ivl_expr_opcode(expr));
      }

      switch (ivl_expr_opcode(expr)) {
	  case '&':
	    draw_eval_vec4(sub);
	    fprintf(vvp_out, "    %%and/r;\n");
	    break;

	  case '|':
	    draw_eval_vec4(sub);
	    fprintf(vvp_out, "    %%or/r;\n");
	    break;

	  case '^':
	    draw_eval_vec4(sub);
	    fprintf(vvp_out, "    %%xor/r;\n");
	    break;

	  case '~':
	    draw_eval_vec4(sub);
	    fprintf(vvp_out, "    %%inv;\n");
	    break;

	  case '!':
	    draw_eval_vec4(sub);
	    fprintf(vvp_out, "    %%nor/r;\n");
	    break;

	  case '-':
	    draw_eval_vec4(sub);
	    fprintf(vvp_out, "    %%inv;\n");
	    fprintf(vvp_out, "    %%addi 1, 0, %u;\n", ivl_expr_width(sub));
	    break;

	  case 'A': /* nand (~&) */
	    draw_eval_vec4(sub);
	    fprintf(vvp_out, "    %%nand/r;\n");
	    break;

	  case 'D': /* pre-decrement (--x) */
	    draw_unary_inc_dec(sub, false, true);
	    break;

	  case 'd': /* post_decrement (x--) */
	    draw_unary_inc_dec(sub, false, false);
	    break;

	  case 'I': /* pre-increment (++x) */
	    draw_unary_inc_dec(sub, true, true);
	    break;

	  case 'i': /* post-increment (x++) */
	    draw_unary_inc_dec(sub, true, false);
	    break;

	  case 'N': /* nor (~|) */
	    draw_eval_vec4(sub);
	    fprintf(vvp_out, "    %%nor/r;\n");
	    break;

	  case 'X': /* xnor (~^) */
	    draw_eval_vec4(sub);
	    fprintf(vvp_out, "    %%xnor/r;\n");
	    break;

	  case 'm': /* abs(m) */
	    draw_eval_vec4(sub);
	    if (! ivl_expr_signed(sub))
		  break;

	      /* Test if (m) < 0 */
	    fprintf(vvp_out, "    %%dup/vec4;\n");
	    fprintf(vvp_out, "    %%cmpi/s 0, 0, %u;\n", ivl_expr_width(sub));
	    fprintf(vvp_out, "    %%jmp/0xz T_%u.%u, 5;\n", thread_count, local_count);
	      /* If so, calculate -(m) */
	    fprintf(vvp_out, "    %%inv;\n");
	    fprintf(vvp_out, "    %%addi 1, 0, %u;\n", ivl_expr_width(sub));
	    fprintf(vvp_out, "T_%u.%u ;\n", thread_count, local_count);
	    local_count += 1;
	    break;

	  case 'v': /* Cast expression to vec4 */
	    switch (ivl_expr_value(sub)) {
		case IVL_VT_REAL:
		  draw_eval_real(sub);
		  fprintf(vvp_out, "    %%cvt/vr %u;\n", ivl_expr_width(expr));
		  break;
		case IVL_VT_STRING:
		  draw_eval_string(sub);
		  fprintf(vvp_out, "    %%cast/vec4/str %u;\n", ivl_expr_width(expr));
		  break;
		case IVL_VT_DARRAY:
		  draw_eval_object(sub);
		  fprintf(vvp_out, "    %%cast/vec4/dar %u;\n", ivl_expr_width(expr));
		  break;
		default:
		  assert(0);
		  break;
	    }
	    break;

	  case '2': /* Cast expression to bool */
	    switch (ivl_expr_value(sub)) {
		case IVL_VT_LOGIC:
		  draw_eval_vec4(sub);
		  fprintf(vvp_out, "    %%cast2;\n");
		  resize_vec4_wid(sub, ivl_expr_width(expr));
		  break;
		case IVL_VT_BOOL:
		  draw_eval_vec4(sub);
		  resize_vec4_wid(sub, ivl_expr_width(expr));
		  break;
		case IVL_VT_REAL:
		  draw_eval_real(sub);
		  fprintf(vvp_out, "    %%cvt/vr %u;\n", ivl_expr_width(expr));
		  break;
		case IVL_VT_STRING:
		  draw_eval_string(sub);
		  fprintf(vvp_out, "    %%cast/vec4/str %u;\n", ivl_expr_width(expr));
		  break;
		case IVL_VT_DARRAY:
		  draw_eval_object(sub);
		  fprintf(vvp_out, "    %%cast/vec2/dar %u;\n", ivl_expr_width(expr));
		  break;
		case IVL_VT_CLASS:
		  /* Cast class handle to bool: non-null handle is true. */
		  draw_eval_object(sub);
		  fprintf(vvp_out, "    %%test_nul/obj;\n");
		  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
		  fprintf(vvp_out, "    %%flag_inv 4;\n");
		  fprintf(vvp_out, "    %%flag_get/vec4 4;\n");
		  break;
		default:
		  fprintf(stderr, "Warning: draw_unary_vec4 '2' (cast-to-bool):"
			  " unhandled sub-expression type %d; emitting 0\n",
			  ivl_expr_value(sub));
		  fprintf(vvp_out, "    %%pushi/vec4 0, 0, %u; ; cast-to-bool fallback\n",
			  ivl_expr_width(expr) ? ivl_expr_width(expr) : 1);
		  break;
	    }
	    break;

	  default:
	    fprintf(stderr, "XXXX Unary operator %c not implemented\n", ivl_expr_opcode(expr));
	    break;
      }
}

void draw_eval_vec4(ivl_expr_t expr)
{
      static unsigned char warned_unexpected_vec4_type[32];
      static int warned_unexpected_vec4_type_oob = 0;

      if (number_trace_enabled_()) {
            fprintf(stderr,
                    "trace vec4: file=%s line=%u expr_type=%d expr_value=%d width=%u signed=%d\n",
                    ivl_expr_file(expr), ivl_expr_lineno(expr),
                    ivl_expr_type(expr), ivl_expr_value(expr),
                    ivl_expr_width(expr), ivl_expr_signed(expr));
      }

      if (debug_draw) {
	    fprintf(vvp_out, " ; %s:%u:draw_eval_vec4: expr_type=%d\n",
		    ivl_expr_file(expr), ivl_expr_lineno(expr),
		    ivl_expr_type(expr));
      }

      /* Handle object-like values in vec4 contexts as handle-bool casts:
         non-null handle -> 1, null handle -> 0. */
      if (ivl_expr_value(expr) == IVL_VT_CLASS ||
          ivl_expr_value(expr) == IVL_VT_QUEUE ||
          ivl_expr_value(expr) == IVL_VT_DARRAY ||
          ivl_expr_value(expr) == IVL_VT_NO_TYPE) {
            unsigned wid = ivl_expr_width(expr) ? ivl_expr_width(expr) : 1;
            draw_eval_object(expr);
            fprintf(vvp_out, "    %%test_nul/obj;\n");
            fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
            fprintf(vvp_out, "    %%flag_inv 4;\n");
            fprintf(vvp_out, "    %%flag_get/vec4 4;\n");
            if (wid > 1)
                  fprintf(vvp_out, "    %%pad/u %u;\n", wid);
            return;
      }

      /* Explicit scalarization for non-vec4 scalar domains. */
      if (ivl_expr_value(expr) == IVL_VT_REAL) {
            unsigned wid = ivl_expr_width(expr) ? ivl_expr_width(expr) : 1;
            draw_eval_real(expr);
            fprintf(vvp_out, "    %%cvt/vr %u;\n", wid);
            return;
      }
      if (ivl_expr_type(expr) == IVL_EX_BINARY) {
            ivl_expr_t le = ivl_expr_oper1(expr);
            ivl_expr_t re = ivl_expr_oper2(expr);

            if (expr_is_string_like_(le) || expr_is_string_like_(re)) {
                  switch (ivl_expr_opcode(expr)) {
                      case 'e': /* == */
                      case 'E': /* === */
                      case 'n': /* != */
                      case 'N': /* !== */
                      case 'w': /* ==? */
                      case 'W': /* !=? */
                      case 'G': /* >= */
                      case 'L': /* <= */
                      case '>':
                      case '<':
                        draw_binary_vec4(expr);
                        return;
                      default:
                        break;
                  }
            }
      }
      if (ivl_expr_value(expr) == IVL_VT_STRING) {
            unsigned wid = ivl_expr_width(expr) ? ivl_expr_width(expr) : 1;
            switch (ivl_expr_type(expr)) {
                case IVL_EX_STRING:
                case IVL_EX_SIGNAL:
                case IVL_EX_CONCAT:
                case IVL_EX_PROPERTY:
                case IVL_EX_SELECT:
                case IVL_EX_SFUNC:
                case IVL_EX_UFUNC:
                  draw_eval_string(expr);
                  break;
                default:
                  /* Avoid draw_eval_string->fallback_eval recursion for
                     unsupported string expression node kinds. */
                  fprintf(vvp_out, "    %%pushi/str \"\";\n");
                  break;
            }
            fprintf(vvp_out, "    %%cast/vec4/str %u;\n", wid);
            return;
      }

      /* Numeric literals can arrive here before the core has assigned a
         stable vec4 expression value type. Handle them explicitly before
         the generic zero-fallback gate. */
      if (ivl_expr_type(expr) == IVL_EX_NUMBER) {
            draw_number_vec4(expr);
            return;
      }
      if (ivl_expr_type(expr) == IVL_EX_ULONG
          || ivl_expr_type(expr) == IVL_EX_DELAY) {
            uint64_t imm = (ivl_expr_type(expr) == IVL_EX_ULONG)
                         ? ivl_expr_uvalue(expr) : ivl_expr_delay_val(expr);
            unsigned wid = ivl_expr_width(expr);
            if (number_trace_enabled_()) {
                  fprintf(stderr,
                          "trace num: file=%s line=%u expr_type=%d expr_value=%d width=%u imm=%llu\n",
                          ivl_expr_file(expr), ivl_expr_lineno(expr),
                          ivl_expr_type(expr), ivl_expr_value(expr),
                          wid, (unsigned long long)imm);
            }
            if (wid == 0)
                  wid = (ivl_expr_type(expr) == IVL_EX_ULONG)
                      ? 8 * sizeof(unsigned long) : 64;
            fprintf(vvp_out, "    %%pushi/vec4 %lu, %lu, %u;\n",
                    (unsigned long)(imm & 0xffffffffUL),
                    (unsigned long)((imm >> 32) & 0xffffffffUL),
                    wid);
            return;
      }

      // Compile-progress fallback: Some UVM expressions may have unresolved
      // types from macro expansions. Emit a zero vec4.
      if (ivl_expr_value(expr) != IVL_VT_BOOL &&
          ivl_expr_value(expr) != IVL_VT_VECTOR) {
	    int vt = ivl_expr_value(expr);
	    int should_warn = 1;
	    if (vt == IVL_VT_NO_TYPE) {
		  should_warn = 0;
	    }
	    if (vt >= 0 && vt < (int)(sizeof warned_unexpected_vec4_type)) {
		  if (warned_unexpected_vec4_type[vt]) {
			should_warn = 0;
		  } else {
			warned_unexpected_vec4_type[vt] = 1;
		  }
	    } else if (warned_unexpected_vec4_type_oob) {
		  should_warn = 0;
	    } else {
		  warned_unexpected_vec4_type_oob = 1;
	    }

	    if (should_warn) {
		  fprintf(stderr, "%s:%u: Warning: Unexpected type %d in vec4 context; treating as zero"
			  " (suppressing further similar warnings)\n",
			  ivl_expr_file(expr), ivl_expr_lineno(expr), vt);
		    }
		    fprintf(vvp_out, "    %%pushi/vec4 0, 0, %u; ; zero fallback\n",
			    ivl_expr_width(expr));
		    return;
	      }

      switch (ivl_expr_type(expr)) {
	  case IVL_EX_BINARY:
	    draw_binary_vec4(expr);
	    return;

	  case IVL_EX_CONCAT:
	    draw_concat_vec4(expr);
	    return;

	  case IVL_EX_NUMBER:
	  case IVL_EX_SELECT:
	    if (ivl_expr_oper2(expr)==0)
		  draw_select_pad_vec4(expr);
	    else
		  draw_select_vec4(expr);
	    return;

	  case IVL_EX_SFUNC:
	    draw_sfunc_vec4(expr);
	    return;

	  case IVL_EX_SIGNAL:
	    draw_signal_vec4(expr);
	    return;

	  case IVL_EX_STRING:
	    draw_string_vec4(expr);
	    return;

	  case IVL_EX_TERNARY:
	    draw_ternary_vec4(expr);
	    return;

	  case IVL_EX_UFUNC:
	    draw_ufunc_vec4(expr);
	    return;

	  case IVL_EX_UNARY:
	    draw_unary_vec4(expr);
	    return;

	  case IVL_EX_PROPERTY:
	    draw_property_vec4(expr);
	    return;

	  case IVL_EX_NULL:
	    /* Null/unsupported nested property in vec4 context.
	     * Emit zero as a safe fallback (from nested property fallback). */
	    fprintf(vvp_out, "    %%pushi/vec4 0, 0, %u; ; null/nested-prop fallback\n",
	                    ivl_expr_width(expr) ? ivl_expr_width(expr) : 1);
	    return;

	  default:
	    fprintf(stderr, "%s:%u: Warning: unsupported VEC4 expression (%d); emitting zero fallback\n",
	                    ivl_expr_file(expr), ivl_expr_lineno(expr),
	                    ivl_expr_type(expr));
	    fprintf(vvp_out, "    %%pushi/vec4 0, 0, %u; ; vec4 fallback\n",
	                    ivl_expr_width(expr) ? ivl_expr_width(expr) : 1);
	    return;
      }
}
