/*
 * Copyright (c) 2011-2025 Stephen Williams (steve@icarus.com)
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
# include  <assert.h>
# include  <stdlib.h>
# include  <limits.h>

/*
 * These functions handle the blocking assignment. Use the %set
 * instruction to perform the actual assignment, and calculate any
 * lvalues and rvalues that need calculating.
 *
 * The set_to_lvariable function takes a particular nexus and generates
 * the %set statements to assign the value.
 *
 * The show_stmt_assign function looks at the assign statement, scans
 * the l-values, and matches bits of the r-value with the correct
 * nexus.
 */

enum slice_type_e {
      SLICE_NO_TYPE = 0,
      SLICE_SIMPLE_VECTOR,
      SLICE_PART_SELECT_STATIC,
      SLICE_PART_SELECT_DYNAMIC,
      SLICE_MEMORY_WORD_STATIC,
      SLICE_MEMORY_WORD_DYNAMIC
};

struct vec_slice_info {
      enum slice_type_e type;

      union {
	    struct {
		  unsigned long use_word;
	    } simple_vector;

	    struct {
		  unsigned long part_off;
	    } part_select_static;

	    struct {
		    /* Index reg that holds the memory word index */
		  int word_idx_reg;
		    /* Stored x/non-x flag */
		  unsigned x_flag;
	    } part_select_dynamic;

	    struct {
		  unsigned long use_word;
	    } memory_word_static;

	    struct {
		    /* Index reg that holds the memory word index */
		  int word_idx_reg;
		    /* Stored x/non-x flag */
		  unsigned x_flag;
	    } memory_word_dynamic;
      } u_;
};

static int expr_is_numeric_container_index_(ivl_expr_t expr);
static int prop_is_numeric_queue_index_(ivl_type_t prop_type, ivl_expr_t idx_expr);
static int show_stmt_assign_sig_assoc_index(ivl_statement_t net,
                                            ivl_signal_t var,
                                            ivl_type_t var_type);
static int type_is_object_like_(ivl_type_t type);

static int queue_pattern_operand_is_object_collection_(ivl_expr_t expr,
                                                       ivl_type_t element_type);

static ivl_expr_t prop_lval_index_expr_(ivl_lval_t lval)
{
      ivl_expr_t idx_expr = ivl_lval_idx(lval);

      if (!idx_expr && ivl_lval_nest(lval))
            idx_expr = ivl_lval_idx(ivl_lval_nest(lval));

      return idx_expr;
}

static void get_vec_from_lval_slice(ivl_lval_t lval, struct vec_slice_info*slice,
				    unsigned wid)
{
      ivl_signal_t sig = ivl_lval_sig(lval);
      ivl_expr_t part_off_ex = ivl_lval_part_off(lval);
      unsigned long part_off = 0;

	/* Although Verilog doesn't support it, we'll handle
	   here the case of an l-value part select of an array
	   word if the address is constant. */
      ivl_expr_t word_ix = ivl_lval_idx(lval);
      unsigned long use_word = 0;

      if (part_off_ex == 0) {
	    part_off = 0;
      } else if (number_is_immediate(part_off_ex, IMM_WID, 0) &&
                 !number_is_unknown(part_off_ex)) {
	    part_off = get_number_immediate(part_off_ex);
	    part_off_ex = 0;
      }

	/* If the word index is a constant expression, then evaluate
	   it to select the word, and pay no further heed to the
	   expression itself. */
      if (word_ix && number_is_immediate(word_ix, IMM_WID, 0)) {
	    if (number_is_unknown(word_ix))
		  use_word = ULONG_MAX; // The largest valid index is ULONG_MAX - 1
	    else
		  use_word = get_number_immediate(word_ix);
	    word_ix = 0;
      }

      if (ivl_signal_dimensions(sig)==0 && part_off_ex==0 && word_ix==0
	  && part_off==0 && wid==ivl_signal_width(sig)) {

	    slice->type = SLICE_SIMPLE_VECTOR;
	    slice->u_.simple_vector.use_word = use_word;
	    if (signal_is_return_value(sig)) {
		  assert(use_word==0);
		  fprintf(vvp_out, "    %%retload/vec4 0;\n");
	    } else {
		  fprintf(vvp_out, "    %%load/vec4 v%p_%lu;\n", sig, use_word);
	    }

      } else if (ivl_signal_dimensions(sig)==0 && part_off_ex==0 && word_ix==0) {

	    assert(use_word == 0);

	    slice->type = SLICE_PART_SELECT_STATIC;
	    slice->u_.part_select_static.part_off = part_off;

	    if (signal_is_return_value(sig)) {
		  assert(use_word==0);
		  fprintf(vvp_out, "    %%retload/vec4 0;\n");
	    } else {
		  fprintf(vvp_out, "    %%load/vec4 v%p_%lu;\n", sig, use_word);
	    }
	    fprintf(vvp_out, "    %%parti/u %u, %lu, 32;\n", wid, part_off);

      } else if (ivl_signal_dimensions(sig)==0 && part_off_ex!=0 && word_ix==0) {

	    assert(use_word == 0);
	    assert(part_off == 0);
	    assert(!signal_is_return_value(sig)); // NOT IMPLEMENTED

	    slice->type = SLICE_PART_SELECT_DYNAMIC;

	    slice->u_.part_select_dynamic.word_idx_reg = allocate_word();
	    slice->u_.part_select_dynamic.x_flag = allocate_flag();

	    fprintf(vvp_out, "    %%load/vec4 v%p_%lu;\n", sig, use_word);
	    draw_eval_vec4(part_off_ex);
	    fprintf(vvp_out, "    %%dup/vec4;\n");
	    fprintf(vvp_out, "    %%ix/vec4 %d;\n", slice->u_.part_select_dynamic.word_idx_reg);
	    fprintf(vvp_out, "    %%flag_mov %u, 4;\n", slice->u_.part_select_dynamic.x_flag);
	    fprintf(vvp_out, "    %%part/u %u;\n", wid);

      } else if (ivl_signal_dimensions(sig) > 0 && word_ix == 0) {

	    assert(!signal_is_return_value(sig)); // NOT IMPLEMENTED

	    slice->type = SLICE_MEMORY_WORD_STATIC;
	    slice->u_.memory_word_static.use_word = use_word;
	    if (use_word < ivl_signal_array_count(sig)) {
		  fprintf(vvp_out, "    %%ix/load 3, %lu, 0;\n",
			  use_word);
		  fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
		  fprintf(vvp_out, "    %%load/vec4a v%p, 3;\n", sig);
	    } else {
		  if (wid <= 32) {
			fprintf(vvp_out, "    %%pushi/vec4 4294967295, 4294967295, %u;\n", wid);
		  } else {
			fprintf(vvp_out, "    %%pushi/vec4 4294967295, 4294967295, 32;\n");
			fprintf(vvp_out, "    %%pad/s %u;\n", wid);
		  }
	    }

      } else if (ivl_signal_dimensions(sig) > 0 && word_ix != 0) {

	    assert(!signal_is_return_value(sig)); // NOT IMPLEMENTED
	    slice->type = SLICE_MEMORY_WORD_DYNAMIC;

	    slice->u_.memory_word_dynamic.word_idx_reg = allocate_word();
	    slice->u_.memory_word_dynamic.x_flag = allocate_flag();

		  draw_eval_expr_into_integer(word_ix, slice->u_.memory_word_dynamic.word_idx_reg);
		  fprintf(vvp_out, "    %%flag_mov %u, 4;\n", slice->u_.memory_word_dynamic.x_flag);
		  note_array_signal_use(sig);
		  fprintf(vvp_out, "    %%load/vec4a v%p, %d;\n", sig, slice->u_.memory_word_dynamic.word_idx_reg);

      } else {
	    assert(0);
      }
}

/*
 * This loads the l-value values into the top of the stack, and also
 * leaves in the slices the information needed to store the slice
 * results back.
 */
static void get_vec_from_lval(ivl_statement_t net, struct vec_slice_info*slices)
{
      unsigned lidx;
      unsigned cur_bit;

      unsigned wid = ivl_stmt_lwidth(net);

      cur_bit = 0;
      for (lidx = ivl_stmt_lvals(net) ; lidx > 0 ; lidx -= 1) {
	    ivl_lval_t lval;
	    unsigned bit_limit = wid - cur_bit;

	    lval = ivl_stmt_lval(net, lidx-1);

	    if (bit_limit > ivl_lval_width(lval))
		  bit_limit = ivl_lval_width(lval);

	    get_vec_from_lval_slice(lval, slices+lidx-1, bit_limit);
	    if (cur_bit > 0) {
		  fprintf(vvp_out, "    %%concat/vec4;\n");
	    }

	    cur_bit += bit_limit;
      }

}

static void put_vec_to_ret_slice(ivl_signal_t sig, struct vec_slice_info*slice,
				 unsigned wid)
{
      int part_off_idx;

	/* If the slice of the l-value is a BOOL variable, then cast
	   the data to a BOOL vector so that the stores can be valid. */
      if (ivl_signal_data_type(sig) == IVL_VT_BOOL) {
	    fprintf(vvp_out, "    %%cast2;\n");
      }

      switch (slice->type) {
	  default:
	    fprintf(vvp_out, " ; XXXX slice->type=%d\n", slice->type);
	    assert(0);
	    break;

	  case SLICE_SIMPLE_VECTOR:
	    assert(slice->u_.simple_vector.use_word == 0);
	    fprintf(vvp_out, "    %%ret/vec4 0, 0, %u;\n", wid);
	    break;

	  case SLICE_PART_SELECT_STATIC:
	    part_off_idx = allocate_word();
	    fprintf(vvp_out, "    %%ix/load %d, %lu, 0;\n",
		    part_off_idx, slice->u_.part_select_static.part_off);
	    fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
	    fprintf(vvp_out, "    %%ret/vec4 0, %d, %u;\n", part_off_idx, wid);
	    clr_word(part_off_idx);
	    break;

	  case SLICE_PART_SELECT_DYNAMIC:
	    fprintf(vvp_out, "    %%flag_mov 4, %u;\n",
		    slice->u_.part_select_dynamic.x_flag);
	    fprintf(vvp_out, "    %%ret/vec4 0, %d, %u;\n",
		    slice->u_.part_select_dynamic.word_idx_reg, wid);
	    clr_word(slice->u_.part_select_dynamic.word_idx_reg);
	    clr_flag(slice->u_.part_select_dynamic.x_flag);
	    break;

      }
}

static void put_vec_to_lval_slice(ivl_lval_t lval, struct vec_slice_info*slice,
				  unsigned wid)
{
	//unsigned skip_set = transient_id++;
      ivl_signal_t sig = ivl_lval_sig(lval);
      int part_off_idx;


	/* Special Case: If the l-value signal is named after its scope,
	   and the scope is a function, then this is an assign to a return
	   value and should be handled differently. */
      if (signal_is_return_value(sig)) {
	    put_vec_to_ret_slice(sig, slice, wid);
	    return;
      }

	/* If the slice of the l-value is a BOOL variable, then cast
	   the data to a BOOL vector so that the stores can be valid. */
      if (ivl_signal_data_type(sig) == IVL_VT_BOOL) {
	    fprintf(vvp_out, "    %%cast2;\n");
      }

      switch (slice->type) {
	  default:
	    fprintf(vvp_out, " ; XXXX slice->type=%d\n", slice->type);
	    assert(0);
	    break;

	  case SLICE_SIMPLE_VECTOR:
	    fprintf(vvp_out, "    %%store/vec4 v%p_%lu, 0, %u;\n",
		    sig, slice->u_.simple_vector.use_word, wid);
	    break;

	  case SLICE_PART_SELECT_STATIC:
	    part_off_idx = allocate_word();
	    fprintf(vvp_out, "    %%ix/load %d, %lu, 0;\n",
		    part_off_idx, slice->u_.part_select_static.part_off);
	    fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
	    fprintf(vvp_out, "    %%store/vec4 v%p_0, %d, %u;\n",
		    sig, part_off_idx, wid);
	    clr_word(part_off_idx);
	    break;

	  case SLICE_PART_SELECT_DYNAMIC:
	    fprintf(vvp_out, "    %%flag_mov 4, %u;\n",
		    slice->u_.part_select_dynamic.x_flag);
	    fprintf(vvp_out, "    %%store/vec4 v%p_0, %d, %u;\n",
		    sig, slice->u_.part_select_dynamic.word_idx_reg, wid);
	    clr_word(slice->u_.part_select_dynamic.word_idx_reg);
	    clr_flag(slice->u_.part_select_dynamic.x_flag);
	    break;

	  case SLICE_MEMORY_WORD_STATIC:
	    if (slice->u_.memory_word_static.use_word < ivl_signal_array_count(sig)) {
		  int word_idx = allocate_word();
		  fprintf(vvp_out,"    %%flag_set/imm 4, 0;\n");
		  fprintf(vvp_out,"    %%ix/load %d, %lu, 0;\n", word_idx, slice->u_.memory_word_static.use_word);
		  note_array_signal_use(sig);
		  fprintf(vvp_out,"    %%store/vec4a v%p, %d, 0;\n", sig, word_idx);
		  clr_word(word_idx);
	    } else {
		  fprintf(vvp_out," ; Skip this slice write to v%p [%lu]\n", sig, slice->u_.memory_word_static.use_word);
		  fprintf(vvp_out,"    %%pop/vec4 1;\n");
	    }
	    break;

	  case SLICE_MEMORY_WORD_DYNAMIC:
	    fprintf(vvp_out, "    %%flag_mov 4, %u;\n", slice->u_.memory_word_dynamic.x_flag);
	    note_array_signal_use(sig);
	    fprintf(vvp_out, "    %%store/vec4a v%p, %d, 0;\n", sig, slice->u_.memory_word_dynamic.word_idx_reg);
	    clr_word(slice->u_.memory_word_dynamic.word_idx_reg);
	    clr_flag(slice->u_.memory_word_dynamic.x_flag);
	    break;

      }
}

static void put_vec_to_lval(ivl_statement_t net, struct vec_slice_info*slices)
{
      unsigned lidx;
      unsigned cur_bit;

      unsigned wid = ivl_stmt_lwidth(net);

      cur_bit = 0;
      for (lidx = 0 ; lidx < ivl_stmt_lvals(net) ; lidx += 1) {
	    ivl_lval_t lval;
	    unsigned bit_limit = wid - cur_bit;

	    lval = ivl_stmt_lval(net, lidx);

	    if (bit_limit > ivl_lval_width(lval))
		  bit_limit = ivl_lval_width(lval);

	    if (lidx+1 < ivl_stmt_lvals(net))
		  fprintf(vvp_out, "    %%split/vec4 %u;\n", bit_limit);

	    put_vec_to_lval_slice(lval, slices+lidx, bit_limit);

	    cur_bit += bit_limit;
      }
}

static ivl_type_t draw_lval_expr(ivl_lval_t lval)
{
      static int warned_invalid_prop_index = 0;
      ivl_lval_t lval_nest = ivl_lval_nest(lval);
      ivl_signal_t lval_sig = ivl_lval_sig(lval);
      unsigned lab_null = local_count++;
      unsigned lab_out = local_count++;

      if (lval_sig) {
	    ivl_expr_t word_ex = ivl_lval_idx(lval);
	    ivl_type_t sig_type = ivl_signal_net_type(lval_sig);

	    if (word_ex && sig_type) {
		  ivl_type_t element_type = ivl_type_element(sig_type);
		  if (element_type && ivl_type_base(element_type) == IVL_VT_CLASS) {
			draw_eval_expr_into_integer(word_ex, 3);
			if (ivl_type_base(sig_type) == IVL_VT_DARRAY ||
			    ivl_type_base(sig_type) == IVL_VT_QUEUE) {
			      fprintf(vvp_out, "    %%load/dar/obj v%p_0;\n", lval_sig);
			      return element_type;
			}
			if (ivl_signal_dimensions(lval_sig) > 0) {
			      fprintf(vvp_out, "    %%load/obja v%p, 3;\n", lval_sig);
			      return element_type;
			}
		  }
	    }

	    fprintf(vvp_out, "    %%load/obj v%p_0;\n", lval_sig);
	    return sig_type;
      }

      assert (lval_nest);
      ivl_type_t sub_type = draw_lval_expr(lval_nest);
      ivl_type_t prop_type;
      ivl_type_t element_type;
      ivl_expr_t nested_idx_expr;
      int idx_word = 0;
      int assoc_indexed = 0;
      int queue_indexed = 0;
      if ((sub_type == 0) || (ivl_type_properties(sub_type) <= 0)) {
	    /* Compile-progress fallback: nested receiver is not class-typed,
	       preserve object-stack discipline with a null object. */
	    fprintf(vvp_out, "    %%null;\n");
	    return 0;
      }

      int prop_idx = ivl_lval_property_idx(lval_nest);
      if (prop_idx < 0)
	    return sub_type;

      if ((prop_idx < 0) || (prop_idx >= ivl_type_properties(sub_type))) {
	    if (!warned_invalid_prop_index) {
		  fprintf(stderr, "Warning: invalid class property index %d in nested l-value; "
				  "using null object fallback"
				  " (further similar warnings suppressed)\n", prop_idx);
		  warned_invalid_prop_index = 1;
	    }
	    fprintf(vvp_out, "    %%pushi/vec4 0, 0, 1;\n");
	    fprintf(vvp_out, "    %%cast2;\n");
	    return 0;
      }

      prop_type = ivl_type_prop_type(sub_type, prop_idx);
      element_type = ivl_type_element(prop_type);
      nested_idx_expr = ivl_lval_idx(lval_nest);
      if (nested_idx_expr) {
	    if (prop_is_numeric_queue_index_(prop_type, nested_idx_expr)) {
		  queue_indexed = 1;
	    } else if (prop_type
	               && ivl_type_base(prop_type) == IVL_VT_QUEUE
	               && ivl_type_queue_assoc_compat(prop_type)) {
		  assoc_indexed = 1;
	    } else {
		  idx_word = allocate_word();
		  draw_eval_expr_into_integer(nested_idx_expr, idx_word);
	    }
      }

      fprintf(vvp_out, "    %%test_nul/obj;\n");
      fprintf(vvp_out, "    %%jmp/1 T_%u.%u, 4;\n", thread_count, lab_null);
      if (queue_indexed) {
	    draw_eval_expr_into_integer(nested_idx_expr, 3);
	    fprintf(vvp_out, "    %%prop/obj %d, 0; Load queue property %s\n",
	            prop_idx, ivl_type_prop_name(sub_type, prop_idx));
	    fprintf(vvp_out, "    %%load/qo/obj;\n");
	    fprintf(vvp_out, "    %%pop/obj 1, 1;\n");
      } else if (assoc_indexed) {
            const char*key_kind;
	    fprintf(vvp_out, "    %%prop/obj %d, 0; Load assoc property %s\n",
	            prop_idx, ivl_type_prop_name(sub_type, prop_idx));
            key_kind = draw_eval_assoc_key_(nested_idx_expr, 0);
	    fprintf(vvp_out, "    %%aa/load/obj/%s;\n", key_kind);
	    fprintf(vvp_out, "    %%pop/obj 2, 1;\n");
      } else if (idx_word) {
	    fprintf(vvp_out, "    %%prop/obj %d, %d; Load property %s\n", prop_idx,
	            idx_word, ivl_type_prop_name(sub_type, prop_idx));
	    fprintf(vvp_out, "    %%pop/obj 1, 1;\n");
      } else {
	    fprintf(vvp_out, "    %%prop/obj %d, 0; Load property %s\n", prop_idx,
	            ivl_type_prop_name(sub_type, prop_idx));
	    fprintf(vvp_out, "    %%pop/obj 1, 1;\n");
      }
      fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_out);
      fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_null);
      fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
      fprintf(vvp_out, "    %%null;\n");
      fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_out);

      if (idx_word) clr_word(idx_word);

      if (nested_idx_expr && element_type)
	    return element_type;

      return prop_type;
}

/*
 * Store a vector from the vec4 stack to the statement l-values. This
 * all assumes that the value to be assigned is already on the top of
 * the stack.
 *
 * NOTE TO SELF: The %store/vec4 takes a width, but the %assign/vec4
 * instructions do not, instead relying on the expression width. I
 * think that it the proper way to do it, so soon I should change the
 * %store/vec4 to not include the width operand.
 */
static void store_vec4_to_lval(ivl_statement_t net)
{
      for (unsigned lidx = 0 ; lidx < ivl_stmt_lvals(net) ; lidx += 1) {
	    ivl_lval_t lval = ivl_stmt_lval(net,lidx);
	    ivl_signal_t lsig = ivl_lval_sig(lval);
	    unsigned lwid = ivl_lval_width(lval);


	    ivl_expr_t part_off_ex = ivl_lval_part_off(lval);
	      /* This is non-nil if the l-val is the word of a memory,
		 and nil otherwise. */
	    ivl_expr_t word_ex = ivl_lval_idx(lval);

	    if (lidx+1 < ivl_stmt_lvals(net))
		  fprintf(vvp_out, "    %%split/vec4 %u;\n", lwid);

	    if (word_ex) {
		    /* Handle index into an array */
		  int word_index = allocate_word();
		  int part_index = 0;
		    /* Calculate the word address into word_index */
		  draw_eval_expr_into_integer(word_ex, word_index);
		    /* If there is a part_offset, calculate it into part_index. */
		  if (part_off_ex) {
			int flag_index = allocate_flag();
			part_index = allocate_word();
			fprintf(vvp_out, "    %%flag_mov %d, 4;\n", flag_index);
			draw_eval_expr_into_integer(part_off_ex, part_index);
			fprintf(vvp_out, "    %%flag_or 4, %d;\n", flag_index);
			clr_flag(flag_index);
		  }

		  assert(lsig);
		  note_array_signal_use(lsig);
		  fprintf(vvp_out, "    %%store/vec4a v%p, %d, %d;\n",
			  lsig, word_index, part_index);

		  clr_word(word_index);
		  if (part_index)
			clr_word(part_index);

	    } else if (part_off_ex) {
		    /* Dynamically calculated part offset */
		  int offset_index = allocate_word();
		  draw_eval_expr_into_integer(part_off_ex, offset_index);
		    /* Note that flag4 is set by the eval above. */
		  assert(lsig);
		  if (signal_is_return_value(lsig)) {
			fprintf(vvp_out, "    %%ret/vec4 0, %d, %u; Assign to %s (store_vec4_to_lval)\n",
				offset_index, lwid, ivl_signal_basename(lsig));
		  } else if (ivl_signal_type(lsig)==IVL_SIT_UWIRE) {
			fprintf(vvp_out, "    %%force/vec4/off v%p_0, %d;\n",
				lsig, offset_index);
		  } else {
			fprintf(vvp_out, "    %%store/vec4 v%p_0, %d, %u;\n",
				lsig, offset_index, lwid);
		  }
		  clr_word(offset_index);

	    } else {
		    /* No offset expression, so use simpler store function. */
		  assert(lsig);
		  assert(lwid == ivl_signal_width(lsig));
		  if (signal_is_return_value(lsig)) {
			fprintf(vvp_out, "    %%ret/vec4 0, 0, %u;  Assign to %s (store_vec4_to_lval)\n",
				lwid, ivl_signal_basename(lsig));
		  } else {
			fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, %u;\n",
				lsig, lwid);
		  }
	    }
      }
}

static unsigned int draw_array_pattern(ivl_signal_t var, ivl_expr_t rval,
					   unsigned int array_idx)
{
      ivl_type_t var_type = ivl_signal_net_type(var);
      ivl_type_t elem_type = var_type;

      /* A scalar aggregate cobject target is not an unpacked array. Build
       * the whole aggregate object and store it as a single handle. */
      if (ivl_signal_dimensions(var) == 0
          && var_type
          && ivl_type_base(var_type) == IVL_VT_NO_TYPE
          && ivl_type_properties(var_type) > 0) {
	    draw_eval_object(rval);
	    fprintf(vvp_out, "    %%store/obj v%p_0;\n", var);
	    return array_idx;
      }

      if (ivl_signal_dimensions(var) > 0) {
	    ivl_type_t unpacked_elem = ivl_type_element(var_type);
	    if (unpacked_elem)
		  elem_type = unpacked_elem;
      }

      for (unsigned int idx = 0; idx < ivl_expr_parms(rval); idx += 1) {
	    ivl_expr_t expr = ivl_expr_parm(rval, idx);

	    switch (ivl_expr_type(expr)) {
		case IVL_EX_ARRAY_PATTERN:
		    /* Object-like array elements use nested array patterns as
		     * aggregate literals, not additional unpacked dimensions. */
		  if (type_is_object_like_(elem_type)) {
			draw_eval_object(expr);
			fprintf(vvp_out, "    %%ix/load 3, %u, 0;\n", array_idx);
			fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
			fprintf(vvp_out, "    %%store/obja v%p, 3;\n", var);
			array_idx += 1;
		  } else {
			array_idx = draw_array_pattern(var, expr, array_idx);
		  }
		  break;
		default:
		  switch (ivl_type_base(elem_type)) {
		      case IVL_VT_BOOL:
		      case IVL_VT_LOGIC:
			draw_eval_vec4(expr);
			fprintf(vvp_out, "    %%ix/load 3, %u, 0;\n", array_idx);
			fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
			fprintf(vvp_out, "    %%store/vec4a v%p, 3, 0;\n", var);
			break;
		      case IVL_VT_REAL:
			draw_eval_real(expr);
			fprintf(vvp_out, "    %%ix/load 3, %u, 0;\n", array_idx);
			fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
			fprintf(vvp_out, "    %%store/reala v%p, 3;\n", var);
			break;
		      case IVL_VT_STRING:
			draw_eval_string(expr);
			fprintf(vvp_out, "    %%ix/load 3, %u, 0;\n", array_idx);
			fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
			fprintf(vvp_out, "    %%store/stra v%p, 3;\n", var);
			break;
		      case IVL_VT_CLASS:
		      case IVL_VT_DARRAY:
		      case IVL_VT_QUEUE:
		      case IVL_VT_NO_TYPE:
			draw_eval_object(expr);
			fprintf(vvp_out, "    %%ix/load 3, %u, 0;\n", array_idx);
			fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
			fprintf(vvp_out, "    %%store/obja v%p, 3;\n", var);
			break;
		      default:
			assert(0);
			break;
		  }
		  array_idx++;
		  break;
	    }
      }

      return array_idx;
}

static void draw_stmt_assign_vector_opcode(unsigned char opcode, bool is_signed)
{
      int idx_reg;

      switch (opcode) {
	  case 0:
	    break;

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
	    fprintf(vvp_out, "    %%div%s;\n", is_signed ? "/s":"");
	    break;

	  case '%':
	    fprintf(vvp_out, "    %%mod%s;\n", is_signed ? "/s":"");
	    break;

	  case '&':
	    fprintf(vvp_out, "    %%and;\n");
	    break;

	  case '|':
	    fprintf(vvp_out, "    %%or;\n");
	    break;

	  case '^':
	    fprintf(vvp_out, "    %%xor;\n");
	    break;

	  case 'l': /* lval <<= expr */
	    idx_reg = allocate_word();
	    fprintf(vvp_out, "    %%ix/vec4 %d;\n", idx_reg);
	    fprintf(vvp_out, "    %%shiftl %d;\n", idx_reg);
	    clr_word(idx_reg);
	    break;

	  case 'r': /* lval >>= expr */
	    idx_reg = allocate_word();
	    fprintf(vvp_out, "    %%ix/vec4 %d;\n", idx_reg);
	    fprintf(vvp_out, "    %%shiftr %d;\n", idx_reg);
	    clr_word(idx_reg);
	    break;

	  case 'R': /* lval >>>= expr */
	    idx_reg = allocate_word();
	    fprintf(vvp_out, "    %%ix/vec4 %d;\n", idx_reg);
	    fprintf(vvp_out, "    %%shiftr/s %d;\n", idx_reg);
	    clr_word(idx_reg);
	    break;

	  default:
	    fprintf(vvp_out, "; UNSUPPORTED ASSIGNMENT OPCODE: %c\n", opcode);
	    assert(0);
	    break;
      }
}

static int show_stmt_assign_vector(ivl_statement_t net)
{
      ivl_expr_t rval = ivl_stmt_rval(net);

      if (ivl_expr_type(rval) == IVL_EX_ARRAY_PATTERN) {
	    ivl_lval_t lval = ivl_stmt_lval(net, 0);
	    ivl_signal_t sig = ivl_lval_sig(lval);
	    draw_array_pattern(sig, rval, 0);
	    return 0;
      }

      unsigned wid = ivl_stmt_lwidth(net);

	/* If this is a compressed assignment, then get the contents
	   of the l-value. We need these values as part of the r-value
	   calculation. */
      if (ivl_stmt_opcode(net) != 0) {
	    struct vec_slice_info *slices;

	    slices = calloc(ivl_stmt_lvals(net), sizeof(struct vec_slice_info));

	    fprintf(vvp_out, "    ; show_stmt_assign_vector: Get l-value for compressed %c= operand\n", ivl_stmt_opcode(net));
	    get_vec_from_lval(net, slices);
	    draw_eval_vec4(rval);
	    resize_vec4_wid(rval, wid);
	    draw_stmt_assign_vector_opcode(ivl_stmt_opcode(net),
					   ivl_expr_signed(rval));
	    put_vec_to_lval(net, slices);
	    free(slices);
      } else {
	    draw_eval_vec4(rval);
	    resize_vec4_wid(rval, wid);
	    store_vec4_to_lval(net);
      }

      return 0;
}

enum real_lval_type_e {
      REAL_NO_TYPE = 0,
      REAL_SIMPLE_WORD,
      REAL_MEMORY_WORD_STATIC,
      REAL_MEMORY_WORD_DYNAMIC
};

struct real_lval_info {
      enum real_lval_type_e type;

      union {
	    struct {
		  unsigned long use_word;
	    } simple_word;

	    struct {
		  unsigned long use_word;
	    } memory_word_static;

	    struct {
		    /* Index reg that holds the memory word index */
		  int word_idx_reg;
		    /* Stored x/non-x flag */
		  unsigned x_flag;
	    } memory_word_dynamic;
      } u_;
};

static void get_real_from_lval(ivl_lval_t lval, struct real_lval_info*slice)
{
      ivl_signal_t sig = ivl_lval_sig(lval);
      ivl_expr_t word_ix = ivl_lval_idx(lval);
      unsigned long use_word = 0;

	/* If the word index is a constant expression, then evaluate
	   it to select the word, and pay no further heed to the
	   expression itself. */
      if (word_ix && number_is_immediate(word_ix, IMM_WID, 0)) {
	    if (number_is_unknown(word_ix))
		  use_word = ULONG_MAX; // The largest valid index is ULONG_MAX - 1
	    else
		  use_word = get_number_immediate(word_ix);
	    word_ix = 0;
      }

      if (ivl_signal_dimensions(sig)==0 && word_ix==0) {

	    slice->type = REAL_SIMPLE_WORD;
	    slice->u_.simple_word.use_word = use_word;
	    if (signal_is_return_value(sig)) {
		  assert(use_word==0);
		  fprintf(vvp_out, "    %%retload/real 0;\n");
	    } else {
		  fprintf(vvp_out, "    %%load/real v%p_%lu;\n", sig, use_word);
	    }

      } else if (ivl_signal_dimensions(sig) > 0 && word_ix == 0) {

	    assert(!signal_is_return_value(sig)); // NOT IMPLEMENTED

	    slice->type = REAL_MEMORY_WORD_STATIC;
	    slice->u_.memory_word_static.use_word = use_word;
	    if (use_word < ivl_signal_array_count(sig)) {
		  fprintf(vvp_out, "    %%ix/load 3, %lu, 0;\n",
			  use_word);
		  fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
		  fprintf(vvp_out, "    %%load/ar v%p, 3;\n", sig);
	    } else {
		  fprintf(vvp_out, "    %%pushi/real 0, 0;\n");
	    }

      } else if (ivl_signal_dimensions(sig) > 0 && word_ix != 0) {

	    assert(!signal_is_return_value(sig)); // NOT IMPLEMENTED
	    slice->type = REAL_MEMORY_WORD_DYNAMIC;

	    slice->u_.memory_word_dynamic.word_idx_reg = allocate_word();
	    slice->u_.memory_word_dynamic.x_flag = allocate_flag();

	    draw_eval_expr_into_integer(word_ix, slice->u_.memory_word_dynamic.word_idx_reg);
	    fprintf(vvp_out, "    %%flag_mov %u, 4;\n", slice->u_.memory_word_dynamic.x_flag);
	    fprintf(vvp_out, "    %%load/ar v%p, %d;\n", sig, slice->u_.memory_word_dynamic.word_idx_reg);

      } else {
	    assert(0);
      }
}

static void put_real_to_lval(ivl_lval_t lval, struct real_lval_info*slice)
{
      ivl_signal_t sig = ivl_lval_sig(lval);

	/* Special Case: If the l-value signal is named after its scope,
	   and the scope is a function, then this is an assign to a return
	   value and should be handled differently. */
      if (signal_is_return_value(sig)) {
	    assert(slice->u_.simple_word.use_word == 0);
	    fprintf(vvp_out, "    %%ret/real 0;\n");
	    return;
      }

      switch (slice->type) {
	  default:
	    fprintf(vvp_out, " ; XXXX slice->type=%d\n", slice->type);
	    assert(0);
	    break;

	  case REAL_SIMPLE_WORD:
	    fprintf(vvp_out, "    %%store/real v%p_%lu;\n",
		    sig, slice->u_.simple_word.use_word);
	    break;

	  case REAL_MEMORY_WORD_STATIC:
	    if (slice->u_.memory_word_static.use_word < ivl_signal_array_count(sig)) {
		  int word_idx = allocate_word();
		  fprintf(vvp_out,"    %%flag_set/imm 4, 0;\n");
		  fprintf(vvp_out,"    %%ix/load %d, %lu, 0;\n", word_idx, slice->u_.memory_word_static.use_word);
		  fprintf(vvp_out,"    %%store/reala v%p, %d;\n", sig, word_idx);
		  clr_word(word_idx);
	    } else {
		  fprintf(vvp_out," ; Skip this slice write to v%p [%lu]\n", sig, slice->u_.memory_word_static.use_word);
		  fprintf(vvp_out,"    %%pop/real 1;\n");
	    }
	    break;

	  case REAL_MEMORY_WORD_DYNAMIC:
	    fprintf(vvp_out, "    %%flag_mov 4, %u;\n", slice->u_.memory_word_dynamic.x_flag);
	    fprintf(vvp_out, "    %%store/reala v%p, %d;\n", sig, slice->u_.memory_word_dynamic.word_idx_reg);
	    clr_word(slice->u_.memory_word_dynamic.word_idx_reg);
	    clr_flag(slice->u_.memory_word_dynamic.x_flag);
	    break;

      }
}

static void store_real_to_lval(ivl_lval_t lval)
{
      ivl_signal_t var;

      var = ivl_lval_sig(lval);
      assert(var != 0);

	/* Special Case: If the l-value signal is named after its scope,
	   and the scope is a function, then this is an assign to a return
	   value and should be handled differently. */
      ivl_scope_t sig_scope = ivl_signal_scope(var);
      if ((ivl_scope_type(sig_scope) == IVL_SCT_FUNCTION)
	  && (strcmp(ivl_signal_basename(var), ivl_scope_basename(sig_scope)) == 0)) {
	    assert(ivl_signal_dimensions(var) == 0);
	    fprintf(vvp_out, "    %%ret/real 0; Assign to %s\n",
		    ivl_signal_basename(var));
	    return;
      }

      if (ivl_signal_dimensions(var) == 0) {
	    fprintf(vvp_out, "    %%store/real v%p_0;\n", var);
	    return;
      }

      ivl_expr_t word_ex = ivl_lval_idx(lval);
      int word_ix = allocate_word();

      draw_eval_expr_into_integer(word_ex, word_ix);
      fprintf(vvp_out, "    %%store/reala v%p, %d;\n", var, word_ix);

      clr_word(word_ix);
}

static void draw_stmt_assign_real_opcode(unsigned char opcode)
{
      switch (opcode) {
	  case 0:
	    break;

	  case '+':
	    fprintf(vvp_out, "    %%add/wr;\n");
	    break;

	  case '-':
	    fprintf(vvp_out, "    %%sub/wr;\n");
	    break;

	  case '*':
	    fprintf(vvp_out, "    %%mul/wr;\n");
	    break;

	  case '/':
	    fprintf(vvp_out, "    %%div/wr;\n");
	    break;

	  case '%':
	    fprintf(vvp_out, "    %%mod/wr;\n");
	    break;

	  default:
	    fprintf(vvp_out, "; UNSUPPORTED ASSIGNMENT OPCODE: %c\n", opcode);
	    assert(0);
	    break;
      }
}

/*
 * This function assigns a value to a real variable. This is destined
 * for /dev/null when typed ivl_signal_t takes over all the real
 * variable support.
 */
static int show_stmt_assign_sig_real(ivl_statement_t net)
{
      ivl_lval_t lval;

      assert(ivl_stmt_lvals(net) == 1);
      lval = ivl_stmt_lval(net, 0);

      ivl_expr_t rval = ivl_stmt_rval(net);
      if (ivl_expr_type(rval) == IVL_EX_ARRAY_PATTERN) {
	    ivl_signal_t sig = ivl_lval_sig(lval);
	    draw_array_pattern(sig, rval, 0);
	    return 0;
      }

	/* If this is a compressed assignment, then get the contents
	   of the l-value. We need this value as part of the r-value
	   calculation. */
      if (ivl_stmt_opcode(net) != 0) {
	    struct real_lval_info slice;

	    fprintf(vvp_out, "    ; show_stmt_assign_real: Get l-value for compressed %c= operand\n", ivl_stmt_opcode(net));
	    get_real_from_lval(lval, &slice);
	    draw_eval_real(rval);
	    draw_stmt_assign_real_opcode(ivl_stmt_opcode(net));
	    put_real_to_lval(lval, &slice);
      } else {
	    draw_eval_real(rval);
	    store_real_to_lval(lval);
      }

      return 0;
}

static int show_stmt_assign_sig_string(ivl_statement_t net)
{
      ivl_lval_t lval = ivl_stmt_lval(net, 0);
      ivl_expr_t rval = ivl_stmt_rval(net);
      ivl_expr_t part = ivl_lval_part_off(lval);
      ivl_expr_t aidx = ivl_lval_idx(lval);
      ivl_signal_t var= ivl_lval_sig(lval);

      assert(ivl_stmt_lvals(net) == 1);
      assert(ivl_stmt_opcode(net) == 0);

      if (ivl_expr_type(rval) == IVL_EX_ARRAY_PATTERN) {
	    draw_array_pattern(var, rval, 0);
	    return 0;
      }

	/* Special case: If the l-value signal (string) is named after
	   its scope, and the scope is a function, then this is an
	   assign to a return value and should be handled
	   differently. */
      if (signal_is_return_value(var)) {
	    assert(ivl_signal_dimensions(var) == 0);
	    if (part == 0 && aidx == 0) {
		  draw_eval_string(rval);
		  fprintf(vvp_out, "    %%ret/str 0; Assign to %s\n",
			  ivl_signal_basename(var));
		  return 0;
	    }
	    /* Compile-progress fallback: slice/index assignment to string return
	       value is not materialized. Preserve side effects, then discard. */
	    draw_eval_string(rval);
	    fprintf(vvp_out, "    %%pop/str 1;\n");
	    if (aidx != 0) {
		  unsigned ix = allocate_word();
		  draw_eval_expr_into_integer(aidx, ix);
		  clr_word(ix);
	    }
	    if (part != 0) {
		  int mux_word = allocate_word();
		  draw_eval_expr_into_integer(part, mux_word);
		  clr_word(mux_word);
	    }
	    return 0;
      }

	/* Simplest case: no mux. Evaluate the r-value as a string and
	   store the result into the variable. Note that the
	   %store/str opcode pops the string result. */
      if (part == 0 && aidx == 0) {
	    draw_eval_string(rval);
	    fprintf(vvp_out, "    %%store/str v%p_0;\n", var);
	    return 0;
      }

	/* Assign to array. The l-value has an index expression
	   expression so we are assigning to an array word. */
      if (aidx != 0) {
	    unsigned ix;
	    assert(part == 0);
	    draw_eval_string(rval);
	    draw_eval_expr_into_integer(aidx, (ix = allocate_word()));
	    fprintf(vvp_out, "    %%store/stra v%p, %u;\n", var, ix);
	    clr_word(ix);
	    return 0;
      }

      draw_eval_vec4(rval);
      resize_vec4_wid(rval, 8);

	/* Calculate the character select for the word. */
      int mux_word = allocate_word();
      draw_eval_expr_into_integer(part, mux_word);

      fprintf(vvp_out, "    %%putc/str/vec4 v%p_0, %d;\n", var, mux_word);

      clr_word(mux_word);
      return 0;
}

/*
 * This function handles the special case that we assign an array
 * pattern to a dynamic array. Handle this by assigning each
 * element. The array pattern will have a fixed size.
 */
static int show_stmt_assign_darray_pattern(ivl_statement_t net)
{
      int errors = 0;
      ivl_lval_t lval = ivl_stmt_lval(net, 0);
      ivl_expr_t rval = ivl_stmt_rval(net);

      ivl_signal_t var = ivl_lval_sig(lval);
      ivl_type_t var_type= ivl_signal_net_type(var);
      assert(ivl_type_base(var_type) == IVL_VT_DARRAY);

      ivl_type_t element_type = ivl_type_element(var_type);
      unsigned idx;
      unsigned size_reg = allocate_word();

#if 0
      unsigned element_width = 1;
      if (ivl_type_base(element_type) == IVL_VT_BOOL)
	    element_width = ivl_type_packed_width(element_type);
      else if (ivl_type_base(element_type) == IVL_VT_LOGIC)
	    element_width = ivl_type_packed_width(element_type);
#endif

// FIXME: At the moment we reallocate the array space.
//        This probably should be a resize to avoid values glitching
	/* Allocate at least enough space for the array pattern. */
      fprintf(vvp_out, "    %%ix/load %u, %u, 0;\n", size_reg, ivl_expr_parms(rval));
	/* This can not have have a X/Z value so clear flag 4. */
      fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
      darray_new(element_type, size_reg);
      fprintf(vvp_out, "    %%store/obj v%p_0;\n", var);

      assert(ivl_expr_type(rval) == IVL_EX_ARRAY_PATTERN);
      for (idx = 0 ; idx < ivl_expr_parms(rval) ; idx += 1) {
	    switch (ivl_type_base(element_type)) {
		case IVL_VT_BOOL:
		case IVL_VT_LOGIC:
		  draw_eval_vec4(ivl_expr_parm(rval,idx));
		  fprintf(vvp_out, "    %%ix/load 3, %u, 0;\n", idx);
		  fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
		  fprintf(vvp_out, "    %%store/dar/vec4 v%p_0;\n", var);
		  break;

		case IVL_VT_REAL:
		  draw_eval_real(ivl_expr_parm(rval,idx));
		  fprintf(vvp_out, "    %%ix/load 3, %u, 0;\n", idx);
		  fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
		  fprintf(vvp_out, "    %%store/dar/r v%p_0;\n", var);
		  break;

		case IVL_VT_STRING:
		  draw_eval_string(ivl_expr_parm(rval,idx));
		  fprintf(vvp_out, "    %%ix/load 3, %u, 0;\n", idx);
		  fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
		  fprintf(vvp_out, "    %%store/dar/str v%p_0;\n", var);
		  break;

		default:
		  fprintf(vvp_out, "; ERROR: show_stmt_assign_darray_pattern: type_base=%d not implemented\n", ivl_type_base(element_type));
		  errors += 1;
		  break;
	    }
      }

      return errors;
}

/*
 * Loading an element and updating it is identical for queues and dynamic arrays
 * and is handled here. The updated value is left on the stack and will be
 * written back using type specific functions.
 */
static void show_stmt_assign_sig_darray_queue_mux(ivl_statement_t net)
{
      ivl_lval_t lval = ivl_stmt_lval(net, 0);
      ivl_signal_t var = ivl_lval_sig(lval);
      ivl_type_t var_type = ivl_signal_net_type(var);
      ivl_type_t element_type = ivl_type_element(var_type);
      ivl_expr_t mux  = ivl_lval_idx(lval);
      ivl_expr_t rval = ivl_stmt_rval(net);

      /*
       * Queue and dynamic array load and store functions expect the element
       * address in index register 3. The index expression must only be
       * evaluated once. So in case of an assignment operator it is moved to a
       * scratch register and restored to the index register once the rvalue has
       * been evaluated.
       */

      switch (ivl_type_base(element_type)) {
	  case IVL_VT_REAL:
	    if (ivl_stmt_opcode(net) != 0) {
		  int mux_word = allocate_word();
		  int flag = allocate_flag();

		  draw_eval_expr_into_integer(mux, 3);
		  fprintf(vvp_out, "    %%ix/mov %d, 3;\n", mux_word);
		  fprintf(vvp_out, "    %%flag_mov %d, 4;\n", flag);
		  fprintf(vvp_out, "    %%load/dar/r v%p_0;\n", var);
		  draw_eval_real(rval);
		  draw_stmt_assign_real_opcode(ivl_stmt_opcode(net));
		  fprintf(vvp_out, "    %%flag_mov 4, %d;\n", flag);
		  fprintf(vvp_out, "    %%ix/mov 3, %d;\n", mux_word);
		  clr_flag(flag);
		  clr_word(mux_word);
	    } else {
		  draw_eval_real(rval);
		  draw_eval_expr_into_integer(mux, 3);
	    }
	    break;
	  case IVL_VT_STRING:
	    assert(ivl_stmt_opcode(net) == 0);
	    draw_eval_string(rval);
	    draw_eval_expr_into_integer(mux, 3);
	    break;
	  case IVL_VT_BOOL:
	  case IVL_VT_LOGIC:
	    if (ivl_stmt_opcode(net) != 0) {
		  int mux_word = allocate_word();
		  int flag = allocate_flag();

		  draw_eval_expr_into_integer(mux, 3);
		  fprintf(vvp_out, "    %%ix/mov %d, 3;\n", mux_word);
		  fprintf(vvp_out, "    %%flag_mov %d, 4;\n", flag);
		  fprintf(vvp_out, "    %%load/dar/vec4 v%p_0;\n", var);
		  draw_eval_vec4(rval);
		  resize_vec4_wid(rval, ivl_stmt_lwidth(net));
		  draw_stmt_assign_vector_opcode(ivl_stmt_opcode(net),
					         ivl_expr_signed(rval));
		  fprintf(vvp_out, "    %%flag_mov 4, %d;\n", flag);
		  fprintf(vvp_out, "    %%ix/mov 3, %d;\n", mux_word);
		  clr_flag(flag);
		  clr_word(mux_word);
	    } else {
		  draw_eval_vec4(rval);
		  resize_vec4_wid(rval, ivl_stmt_lwidth(net));
		  draw_eval_expr_into_integer(mux, 3);
		    }
		    break;
	  case IVL_VT_CLASS:
	  case IVL_VT_DARRAY:
	  case IVL_VT_QUEUE:
	  case IVL_VT_NO_TYPE:
		    assert(ivl_stmt_opcode(net) == 0);
		    draw_eval_object(rval);
		    draw_eval_expr_into_integer(mux, 3);
		    break;
	  default:
		    assert(ivl_stmt_opcode(net) == 0);
		    draw_eval_object(rval);
		    draw_eval_expr_into_integer(mux, 3);
	    break;
      }
}

static int show_stmt_assign_sig_darray(ivl_statement_t net)
{
      int errors = 0;
      ivl_lval_t lval = ivl_stmt_lval(net, 0);
      ivl_expr_t rval = ivl_stmt_rval(net);
      ivl_expr_t part = ivl_lval_part_off(lval);
      ivl_signal_t var= ivl_lval_sig(lval);
      ivl_type_t var_type= ivl_signal_net_type(var);
      assert(ivl_type_base(var_type) == IVL_VT_DARRAY);
      ivl_type_t element_type = ivl_type_element(var_type);

      assert(ivl_stmt_lvals(net) == 1);
      assert(part == 0);

      if (ivl_lval_idx(lval)) {
	    show_stmt_assign_sig_darray_queue_mux(net);
	    switch (ivl_type_base(element_type)) {
		case IVL_VT_REAL:
		  fprintf(vvp_out, "    %%store/dar/r v%p_0;\n", var);
		  break;
		case IVL_VT_STRING:
		  fprintf(vvp_out, "    %%store/dar/str v%p_0;\n", var);
		  break;
		case IVL_VT_BOOL:
		case IVL_VT_LOGIC:
		  fprintf(vvp_out, "    %%store/dar/vec4 v%p_0;\n", var);
		  break;
		case IVL_VT_CLASS:
		case IVL_VT_DARRAY:
		case IVL_VT_QUEUE:
		case IVL_VT_NO_TYPE:
		  fprintf(vvp_out, "    %%store/dar/obj v%p_0;\n", var);
		  break;
	    default:
		  fprintf(vvp_out, "    %%store/dar/obj v%p_0;\n", var);
		  break;
	    }
      } else if (ivl_expr_type(rval) == IVL_EX_ARRAY_PATTERN) {
	    assert(ivl_stmt_opcode(net) == 0);
	      /* There is no l-value mux, but the r-value is an array
		 pattern. This is a special case of an assignment to
		 elements of the l-value. */
	    errors += show_stmt_assign_darray_pattern(net);

      } else if (ivl_expr_type(rval) == IVL_EX_NEW) {
	    assert(ivl_stmt_opcode(net) == 0);
	    // There is no l-value mux, and the r-value expression is
	    // a "new" expression. Handle this by simply storing the
	    // new object to the lval.
	    errors += draw_eval_object(rval);
	    fprintf(vvp_out, "    %%store/obj v%p_0; %s:%u: %s = new ...\n",
		    var, ivl_stmt_file(net), ivl_stmt_lineno(net),
		    ivl_signal_basename(var));

      } else if (ivl_expr_type(rval) == IVL_EX_SIGNAL) {
	    assert(ivl_stmt_opcode(net) == 0);

	    // There is no l-value mux, and the r-value expression is
	    // a "signal" expression. Store a duplicate into the lvalue
	    // By using the %dup/obj. Remember to pop the rvalue that
	    // is no longer needed.
	    errors += draw_eval_object(rval);
	    fprintf(vvp_out, "    %%dup/obj;\n");
	    fprintf(vvp_out, "    %%store/obj v%p_0; %s:%u: %s = <signal>\n",
		    var, ivl_stmt_file(net), ivl_stmt_lineno(net),
		    ivl_signal_basename(var));
	    fprintf(vvp_out, "    %%pop/obj 1, 0;\n");

      } else {
	    assert(ivl_stmt_opcode(net) == 0);
	    // There is no l-value mux, so this must be an
	    // assignment to the array as a whole. Evaluate the
	    // "object", and store the evaluated result.
	    errors += draw_eval_object(rval);
	    fprintf(vvp_out, "    %%store/obj v%p_0; %s:%u: %s = <expr type %d>\n",
		    var, ivl_stmt_file(net), ivl_stmt_lineno(net),
		    ivl_signal_basename(var), ivl_expr_type(rval));
      }

      return errors;
}

/*
 * This function handles the special case that we assign an array
 * pattern to a queue. Handle this by assigning each element.
 * The array pattern will have a fixed size.
 */
static int show_stmt_assign_queue_pattern(ivl_signal_t var, ivl_expr_t rval,
                                          ivl_type_t element_type, int max_idx)
{
      int errors = 0;
      unsigned idx;
      unsigned max_size;
      unsigned max_elems;
      int use_object_collection_append = 0;
      assert(ivl_expr_type(rval) == IVL_EX_ARRAY_PATTERN);
      max_size = ivl_signal_array_count(var);
      max_elems = ivl_expr_parms(rval);

      if (type_is_object_like_(element_type)) {
            for (idx = 0 ; idx < max_elems ; idx += 1) {
                  if (queue_pattern_operand_is_object_collection_(
                              ivl_expr_parm(rval, idx), element_type)) {
                        use_object_collection_append = 1;
                        break;
                  }
            }
      }

      if (use_object_collection_append) {
            fprintf(vvp_out, "    %%null;\n");
            fprintf(vvp_out, "    %%store/obj v%p_0;\n", var);

            for (idx = 0 ; idx < max_elems ; idx += 1) {
                  ivl_expr_t parm = ivl_expr_parm(rval, idx);

                  errors += draw_eval_object(parm);
                  if (queue_pattern_operand_is_object_collection_(parm, element_type))
                        fprintf(vvp_out, "    %%append/qobj/obj v%p_0, %d;\n",
                                var, max_idx);
                  else
                        fprintf(vvp_out, "    %%store/qb/obj v%p_0, %d;\n",
                                var, max_idx);
            }

            return errors;
      }

      if ((max_size != 0) && (max_elems > max_size)) {
	    fprintf(stderr, "%s:%u: Warning: Array pattern assignment has more elements "
	                    "(%u) than bounded queue '%s' supports (%u).\n"
	                    "         Only using first %u elements.\n",
	                    ivl_expr_file(rval), ivl_expr_lineno(rval),
	                    max_elems, ivl_signal_basename(var), max_size, max_size);
	    max_elems = max_size;
      }
      for (idx = 0 ; idx < max_elems ; idx += 1) {
	    switch (ivl_type_base(element_type)) {
		case IVL_VT_BOOL:
		case IVL_VT_LOGIC:
		  draw_eval_vec4(ivl_expr_parm(rval,idx));
		  fprintf(vvp_out, "    %%ix/load 3, %u, 0;\n", idx);
		  fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
		  fprintf(vvp_out, "    %%store/qdar/v v%p_0, %d, %u;\n", var, max_idx,
		                   ivl_type_packed_width(element_type));
		  break;

		case IVL_VT_REAL:
		  draw_eval_real(ivl_expr_parm(rval,idx));
		  fprintf(vvp_out, "    %%ix/load 3, %u, 0;\n", idx);
		  fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
		  fprintf(vvp_out, "    %%store/qdar/r v%p_0, %d;\n", var, max_idx);
		  break;

		case IVL_VT_STRING:
		  draw_eval_string(ivl_expr_parm(rval,idx));
		  fprintf(vvp_out, "    %%ix/load 3, %u, 0;\n", idx);
		  fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
		  fprintf(vvp_out, "    %%store/qdar/str v%p_0, %d;\n", var, max_idx);
		  break;

		case IVL_VT_CLASS:
		case IVL_VT_DARRAY:
		case IVL_VT_QUEUE:
		case IVL_VT_NO_TYPE:
		  draw_eval_object(ivl_expr_parm(rval,idx));
		  fprintf(vvp_out, "    %%ix/load 3, %u, 0;\n", idx);
		  fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
		  fprintf(vvp_out, "    %%store/qdar/obj v%p_0, %d;\n", var, max_idx);
		  break;

		default:
		  /* Compile-progress fallback: treat any remaining element kind
		   * as object so queue pattern assignment does not silently drop
		   * elements. */
		  draw_eval_object(ivl_expr_parm(rval,idx));
		  fprintf(vvp_out, "    %%ix/load 3, %u, 0;\n", idx);
		  fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
		  fprintf(vvp_out, "    %%store/qdar/obj v%p_0, %d;\n", var, max_idx);
		  break;
	    }
      }

      if ((max_size == 0) || (max_elems < max_size)) {
	    int del_idx = allocate_word();
	    assert(del_idx >= 0);
	      /* Save the first queue element to delete. */
	    fprintf(vvp_out, "    %%ix/load %d, %u, 0;\n", del_idx, max_elems);
	    fprintf(vvp_out, "    %%delete/tail v%p_0, %d;\n", var, del_idx);
	    clr_word(del_idx);
      }

      return errors;
}

static int show_stmt_assign_sig_queue(ivl_statement_t net)
{
      int errors = 0;
      ivl_lval_t lval = ivl_stmt_lval(net, 0);
      ivl_expr_t rval = ivl_stmt_rval(net);
      ivl_expr_t part = ivl_lval_part_off(lval);
      ivl_signal_t var= ivl_lval_sig(lval);
      ivl_type_t var_type= ivl_signal_net_type(var);
      ivl_type_t element_type = ivl_type_element(var_type);

      assert(ivl_stmt_lvals(net) == 1);
      assert(part == 0);

      assert(ivl_type_base(var_type) == IVL_VT_QUEUE);

      int idx = allocate_word();
      assert(idx >= 0);
        /* Save the queue maximum index value to an integer register. */
      fprintf(vvp_out, "    %%ix/load %d, %u, 0;\n", idx, ivl_signal_array_count(var));

      if (ivl_expr_type(rval) == IVL_EX_NULL) {
	    assert(ivl_stmt_opcode(net) == 0);
	    errors += draw_eval_object(rval);
	    fprintf(vvp_out, "    %%store/obj v%p_0;\n", var);

      } else if (ivl_lval_idx(lval)) {
            if (ivl_type_queue_assoc_compat(var_type)) {
                  int handled_errors = show_stmt_assign_sig_assoc_index(net, var, var_type);
                  if (handled_errors >= 0) {
                        clr_word(idx);
                        return errors + handled_errors;
                  }
            }
	    show_stmt_assign_sig_darray_queue_mux(net);
	    switch (ivl_type_base(element_type)) {
		case IVL_VT_REAL:
		  fprintf(vvp_out, "    %%store/qdar/r v%p_0, %d;\n", var, idx);
		  break;
		case IVL_VT_STRING:
		  fprintf(vvp_out, "    %%store/qdar/str v%p_0, %d;\n", var, idx);
		  break;
		case IVL_VT_BOOL:
		case IVL_VT_LOGIC:
		  fprintf(vvp_out, "    %%store/qdar/v v%p_0, %d, %u;\n", var, idx,
	                     ivl_type_packed_width(element_type));
		  break;
		case IVL_VT_CLASS:
		case IVL_VT_DARRAY:
		case IVL_VT_QUEUE:
		case IVL_VT_NO_TYPE:
		  fprintf(vvp_out, "    %%store/qdar/obj v%p_0, %d;\n", var, idx);
		  break;
	    default:
		  fprintf(vvp_out, "    %%store/qdar/obj v%p_0, %d;\n", var, idx);
		  break;
	    }
      } else if (ivl_expr_type(rval) == IVL_EX_ARRAY_PATTERN) {
	    assert(ivl_stmt_opcode(net) == 0);

	      /* There is no l-value mux, but the r-value is an array
		 pattern. This is a special case of an assignment to
		 the l-value. */
	    errors += show_stmt_assign_queue_pattern(var, rval, element_type, idx);

      } else {
	    assert(ivl_stmt_opcode(net) == 0);

	      /* There is no l-value mux, so this must be an
		 assignment to the array as a whole. Evaluate the
		 "object", and store the evaluated result. */
	    errors += draw_eval_object(rval);
	    if (ivl_type_base(element_type) == IVL_VT_REAL)
		  fprintf(vvp_out, "    %%store/qobj/r v%p_0, %d;\n", var, idx);
	    else if (ivl_type_base(element_type) == IVL_VT_STRING)
		  fprintf(vvp_out, "    %%store/qobj/str v%p_0, %d;\n", var, idx);
	    else if (ivl_type_base(element_type) == IVL_VT_BOOL ||
		     ivl_type_base(element_type) == IVL_VT_LOGIC) {
		  fprintf(vvp_out, "    %%store/qobj/v v%p_0, %d, %u;\n",
		                   var, idx, ivl_type_packed_width(element_type));
	    } else if (ivl_type_base(element_type) == IVL_VT_CLASS ||
		       ivl_type_base(element_type) == IVL_VT_DARRAY ||
		       ivl_type_base(element_type) == IVL_VT_QUEUE ||
		       ivl_type_base(element_type) == IVL_VT_NO_TYPE) {
		  fprintf(vvp_out, "    %%store/obj v%p_0;\n", var);
	    } else {
		  fprintf(vvp_out, "    %%store/obj v%p_0;\n", var);
	    }
      }
      clr_word(idx);

      return errors;
}

static int expr_is_numeric_container_index_(ivl_expr_t expr)
{
      switch (ivl_expr_value(expr)) {
	  case IVL_VT_STRING:
	  case IVL_VT_CLASS:
	  case IVL_VT_DARRAY:
	  case IVL_VT_QUEUE:
	    return 0;
	  default:
	    return 1;
      }
}

static int show_stmt_assign_sig_assoc_index(ivl_statement_t net,
                                            ivl_signal_t var,
                                            ivl_type_t var_type)
{
      int errors = 0;
      ivl_lval_t lval = ivl_stmt_lval(net, 0);
      ivl_expr_t rval = ivl_stmt_rval(net);
      ivl_expr_t idx_expr = ivl_lval_idx(lval);
      ivl_type_t element_type = ivl_type_element(var_type);
      unsigned wid;
      const char*key_kind;
      int key_is_object;
      int key_is_string;
      int use_signal_scalar_ops;
      int object_like_elem;

      if (!element_type || !ivl_type_queue_assoc_compat(var_type))
            return -1;
      if (!idx_expr)
            return -1;
      if (ivl_stmt_opcode(net) != 0) {
            switch (ivl_type_base(element_type)) {
                case IVL_VT_REAL:
                case IVL_VT_BOOL:
                case IVL_VT_LOGIC:
                  break;
                default:
                  return -1;
            }
      }

      object_like_elem =
            ivl_type_base(element_type) == IVL_VT_CLASS
         || ivl_type_base(element_type) == IVL_VT_DARRAY
         || ivl_type_base(element_type) == IVL_VT_QUEUE
         || ivl_type_base(element_type) == IVL_VT_NO_TYPE;

      key_is_object = expr_is_object_assoc_key_(idx_expr);
      key_is_string = expr_is_string_assoc_key_(idx_expr);
      use_signal_scalar_ops = key_is_object;

      if (key_is_string) {
            key_kind = "str";
            draw_eval_string(idx_expr);
      } else if (key_is_object) {
            key_kind = "obj";
            errors += draw_eval_object(idx_expr);
      } else {
            key_kind = "v";
            draw_eval_vec4(idx_expr);
      }

      if (!object_like_elem && !use_signal_scalar_ops)
            fprintf(vvp_out, "    %%load/obj v%p_0;\n", var);

      switch (ivl_type_base(element_type)) {
          case IVL_VT_REAL:
            if (use_signal_scalar_ops && ivl_stmt_opcode(net) != 0) {
                  fprintf(vvp_out, "    %%aa/load/sig/r/obj v%p_0;\n", var);
                  draw_eval_real(rval);
                  draw_stmt_assign_real_opcode(ivl_stmt_opcode(net));
            } else if (ivl_stmt_opcode(net) != 0) {
                  fprintf(vvp_out, "    %%aa/loadk/r/%s;\n", key_kind);
                  draw_eval_real(rval);
                  draw_stmt_assign_real_opcode(ivl_stmt_opcode(net));
            } else {
                  draw_eval_real(rval);
            }
            if (use_signal_scalar_ops)
                  fprintf(vvp_out, "    %%aa/store/sig/r/obj v%p_0;\n", var);
            else
                  fprintf(vvp_out, "    %%aa/store/r/%s;\n", key_kind);
            if (!use_signal_scalar_ops)
                  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
            return errors;
          case IVL_VT_STRING:
            draw_eval_string(rval);
            if (use_signal_scalar_ops)
                  fprintf(vvp_out, "    %%aa/store/sig/str/obj v%p_0;\n", var);
            else
                  fprintf(vvp_out, "    %%aa/store/str/%s;\n", key_kind);
            if (!use_signal_scalar_ops)
                  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
            return errors;
          case IVL_VT_BOOL:
          case IVL_VT_LOGIC:
            wid = ivl_type_packed_width(element_type);
            if (wid == 0)
                  wid = ivl_stmt_lwidth(net);
            if (use_signal_scalar_ops && ivl_stmt_opcode(net) != 0) {
                  fprintf(vvp_out, "    %%aa/load/sig/v/obj v%p_0, %u;\n", var, wid);
                  draw_eval_vec4(rval);
                  resize_vec4_wid(rval, ivl_stmt_lwidth(net));
                  draw_stmt_assign_vector_opcode(ivl_stmt_opcode(net),
                                                 ivl_expr_signed(rval));
            } else if (ivl_stmt_opcode(net) != 0) {
                  fprintf(vvp_out, "    %%aa/loadk/v/%s %u;\n", key_kind, wid);
                  draw_eval_vec4(rval);
                  resize_vec4_wid(rval, ivl_stmt_lwidth(net));
                  draw_stmt_assign_vector_opcode(ivl_stmt_opcode(net),
                                                 ivl_expr_signed(rval));
            } else {
                  draw_eval_vec4(rval);
                  resize_vec4_wid(rval, ivl_stmt_lwidth(net));
            }
            if (use_signal_scalar_ops)
                  fprintf(vvp_out, "    %%aa/store/sig/v/obj v%p_0, %u;\n", var, wid);
            else
                  fprintf(vvp_out, "    %%aa/store/v/%s %u;\n", key_kind, wid);
            if (!use_signal_scalar_ops)
                  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
            return errors;
          case IVL_VT_CLASS:
          case IVL_VT_DARRAY:
          case IVL_VT_QUEUE:
          case IVL_VT_NO_TYPE:
            errors += draw_eval_object(rval);
            fprintf(vvp_out, "    %%aa/store/sig/obj/%s v%p_0;\n", key_kind, var);
            return errors;
          default:
            return -1;
      }
}

static int prop_is_numeric_queue_index_(ivl_type_t prop_type, ivl_expr_t idx_expr)
{
      if (!idx_expr || !prop_type || ivl_type_base(prop_type) != IVL_VT_QUEUE)
            return 0;

      if (ivl_type_queue_assoc_compat(prop_type))
            return 0;

      return expr_is_numeric_container_index_(idx_expr);
}

static int show_stmt_assign_sig_prop_queue_index(ivl_statement_t net,
                                                 int prop_idx,
                                                 ivl_type_t prop_type)
{
      int errors = 0;
      ivl_lval_t lval = ivl_stmt_lval(net, 0);
      ivl_signal_t recv = ivl_lval_sig(lval);
      ivl_expr_t rval = ivl_stmt_rval(net);
      ivl_expr_t idx_expr = prop_lval_index_expr_(lval);
      ivl_type_t element_type;

      if (!prop_is_numeric_queue_index_(prop_type, idx_expr))
	    return -1;

      element_type = ivl_type_element(prop_type);
      if (!element_type)
	    return -1;

      switch (ivl_type_base(element_type)) {
	  case IVL_VT_REAL:
	    if (ivl_stmt_opcode(net) != 0) {
		  int mux_word = allocate_word();
		  int flag = allocate_flag();

		  draw_eval_expr_into_integer(idx_expr, 3);
		  fprintf(vvp_out, "    %%ix/mov %d, 3;\n", mux_word);
		  fprintf(vvp_out, "    %%flag_mov %d, 4;\n", flag);
		  fprintf(vvp_out, "    %%prop/obj %d, 0;\n", prop_idx);
		  fprintf(vvp_out, "    %%pop/obj 1, 1;\n");
		  fprintf(vvp_out, "    %%load/qo/r;\n");
		  draw_eval_real(rval);
		  draw_stmt_assign_real_opcode(ivl_stmt_opcode(net));
		  fprintf(vvp_out, "    %%flag_mov 4, %d;\n", flag);
		  fprintf(vvp_out, "    %%ix/mov 3, %d;\n", mux_word);
		  fprintf(vvp_out, "    %%load/obj v%p_0;\n", recv);
		  fprintf(vvp_out, "    %%prop/obj %d, 0;\n", prop_idx);
		  fprintf(vvp_out, "    %%pop/obj 1, 1;\n");
		  fprintf(vvp_out, "    %%set/dar/obj/real 3;\n");
		  fprintf(vvp_out, "    %%pop/real 1;\n");
		  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
		  clr_flag(flag);
		  clr_word(mux_word);
	    } else {
		  int idx_word = allocate_word();
		  draw_eval_real(rval);
		  draw_eval_expr_into_integer(idx_expr, idx_word);
		  fprintf(vvp_out, "    %%prop/obj %d, 0;\n", prop_idx);
		  fprintf(vvp_out, "    %%pop/obj 1, 1;\n");
		  fprintf(vvp_out, "    %%set/dar/obj/real %d;\n", idx_word);
		  fprintf(vvp_out, "    %%pop/real 1;\n");
		  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
		  clr_word(idx_word);
	    }
	    return errors;

	  case IVL_VT_STRING:
	    if (ivl_stmt_opcode(net) != 0)
		  return -1;
	    {
		  int idx_word = allocate_word();
		  draw_eval_string(rval);
		  draw_eval_expr_into_integer(idx_expr, idx_word);
		  fprintf(vvp_out, "    %%prop/obj %d, 0;\n", prop_idx);
		  fprintf(vvp_out, "    %%pop/obj 1, 1;\n");
		  fprintf(vvp_out, "    %%set/dar/obj/str %d;\n", idx_word);
		  fprintf(vvp_out, "    %%pop/str 1;\n");
		  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
		  clr_word(idx_word);
	    }
	    return errors;

	  case IVL_VT_BOOL:
	  case IVL_VT_LOGIC: {
		unsigned wid = ivl_type_packed_width(element_type);
		if (wid == 0)
		      wid = ivl_stmt_lwidth(net);

		if (ivl_stmt_opcode(net) != 0) {
		      int mux_word = allocate_word();
		      int flag = allocate_flag();

		      draw_eval_expr_into_integer(idx_expr, 3);
		      fprintf(vvp_out, "    %%ix/mov %d, 3;\n", mux_word);
		      fprintf(vvp_out, "    %%flag_mov %d, 4;\n", flag);
		      fprintf(vvp_out, "    %%prop/obj %d, 0;\n", prop_idx);
		      fprintf(vvp_out, "    %%pop/obj 1, 1;\n");
		      fprintf(vvp_out, "    %%load/qo/v %u;\n", wid);
		      draw_eval_vec4(rval);
		      resize_vec4_wid(rval, ivl_stmt_lwidth(net));
		      draw_stmt_assign_vector_opcode(ivl_stmt_opcode(net),
					             ivl_expr_signed(rval));
		      fprintf(vvp_out, "    %%flag_mov 4, %d;\n", flag);
		      fprintf(vvp_out, "    %%ix/mov 3, %d;\n", mux_word);
		      fprintf(vvp_out, "    %%load/obj v%p_0;\n", recv);
		      fprintf(vvp_out, "    %%prop/obj %d, 0;\n", prop_idx);
		      fprintf(vvp_out, "    %%pop/obj 1, 1;\n");
		      fprintf(vvp_out, "    %%set/dar/obj/vec4 3;\n");
		      fprintf(vvp_out, "    %%pop/vec4 1;\n");
		      fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
		      clr_flag(flag);
		      clr_word(mux_word);
		} else {
		      int idx_word = allocate_word();
		      draw_eval_vec4(rval);
		      resize_vec4_wid(rval, ivl_stmt_lwidth(net));
		      draw_eval_expr_into_integer(idx_expr, idx_word);
		      fprintf(vvp_out, "    %%prop/obj %d, 0;\n", prop_idx);
		      fprintf(vvp_out, "    %%pop/obj 1, 1;\n");
		      fprintf(vvp_out, "    %%set/dar/obj/vec4 %d;\n", idx_word);
		      fprintf(vvp_out, "    %%pop/vec4 1;\n");
		      fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
		      clr_word(idx_word);
		}
		return errors;
	  }

	  case IVL_VT_CLASS:
	  case IVL_VT_DARRAY:
	  case IVL_VT_QUEUE:
	  case IVL_VT_NO_TYPE:
	    if (ivl_stmt_opcode(net) != 0)
		  return -1;
	    {
		  int idx_word = allocate_word();
		  draw_eval_expr_into_integer(idx_expr, idx_word);
		  fprintf(vvp_out, "    %%prop/obj %d, 0;\n", prop_idx);
		  fprintf(vvp_out, "    %%pop/obj 1, 1;\n");
		  errors += draw_eval_object(rval);
		  fprintf(vvp_out, "    %%set/dar/obj/obj %d;\n", idx_word);
		  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
		  clr_word(idx_word);
	    }
	    return errors;

	  default:
	    return -1;
      }
}

static int show_stmt_assign_sig_prop_darray_index(ivl_statement_t net,
                                                  int prop_idx,
                                                  ivl_type_t prop_type)
{
      int errors = 0;
      ivl_lval_t lval = ivl_stmt_lval(net, 0);
      ivl_expr_t rval = ivl_stmt_rval(net);
      ivl_expr_t idx_expr = prop_lval_index_expr_(lval);
      ivl_type_t element_type;

      if (!idx_expr || !prop_type || ivl_type_base(prop_type) != IVL_VT_DARRAY)
            return -1;

      if (ivl_stmt_opcode(net) != 0)
            return -1;

      element_type = ivl_type_element(prop_type);
      if (!element_type)
            return -1;

      switch (ivl_type_base(element_type)) {
          case IVL_VT_REAL: {
            int idx_word = allocate_word();
            draw_eval_real(rval);
            draw_eval_expr_into_integer(idx_expr, idx_word);
            fprintf(vvp_out, "    %%prop/obj %d, 0;\n", prop_idx);
            fprintf(vvp_out, "    %%pop/obj 1, 1;\n");
            fprintf(vvp_out, "    %%set/dar/obj/real %d;\n", idx_word);
            fprintf(vvp_out, "    %%pop/real 1;\n");
            fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
            clr_word(idx_word);
            return errors;
          }

          case IVL_VT_STRING: {
            int idx_word = allocate_word();
            draw_eval_string(rval);
            draw_eval_expr_into_integer(idx_expr, idx_word);
            fprintf(vvp_out, "    %%prop/obj %d, 0;\n", prop_idx);
            fprintf(vvp_out, "    %%pop/obj 1, 1;\n");
            fprintf(vvp_out, "    %%set/dar/obj/str %d;\n", idx_word);
            fprintf(vvp_out, "    %%pop/str 1;\n");
            fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
            clr_word(idx_word);
            return errors;
          }

          case IVL_VT_BOOL:
          case IVL_VT_LOGIC: {
            unsigned wid = ivl_type_packed_width(element_type);
            int idx_word = allocate_word();
            if (wid == 0)
                  wid = ivl_stmt_lwidth(net);

            draw_eval_vec4(rval);
            resize_vec4_wid(rval, ivl_stmt_lwidth(net));
            draw_eval_expr_into_integer(idx_expr, idx_word);
            fprintf(vvp_out, "    %%prop/obj %d, 0;\n", prop_idx);
            fprintf(vvp_out, "    %%pop/obj 1, 1;\n");
            fprintf(vvp_out, "    %%set/dar/obj/vec4 %d;\n", idx_word);
            fprintf(vvp_out, "    %%pop/vec4 1;\n");
            fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
            clr_word(idx_word);
            return errors;
          }

          case IVL_VT_CLASS:
          case IVL_VT_DARRAY:
          case IVL_VT_QUEUE:
          case IVL_VT_NO_TYPE: {
            int idx_word = allocate_word();
            draw_eval_expr_into_integer(idx_expr, idx_word);
            fprintf(vvp_out, "    %%prop/obj %d, 0;\n", prop_idx);
            fprintf(vvp_out, "    %%pop/obj 1, 1;\n");
            errors += draw_eval_object(rval);
            fprintf(vvp_out, "    %%set/dar/obj/obj %d;\n", idx_word);
            fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
            clr_word(idx_word);
            return errors;
          }

          default:
            return -1;
      }
}

static int show_stmt_assign_sig_prop_assoc_index(ivl_statement_t net,
                                                 int prop_idx,
                                                 ivl_type_t prop_type)
{
      int errors = 0;
      ivl_lval_t lval = ivl_stmt_lval(net, 0);
      ivl_expr_t rval = ivl_stmt_rval(net);
      ivl_expr_t idx_expr = ivl_lval_idx(lval);
      ivl_type_t element_type = ivl_type_element(prop_type);
      unsigned wid;
      const char*key_kind;

      if (!element_type || !ivl_type_queue_assoc_compat(prop_type))
	    return -1;
      if (!idx_expr)
	    return -1;
      if (ivl_stmt_opcode(net) != 0) {
	    switch (ivl_type_base(element_type)) {
		case IVL_VT_REAL:
		case IVL_VT_BOOL:
		case IVL_VT_LOGIC:
		  break;
		default:
		  return -1;
	    }
      }

      fprintf(vvp_out, "    %%prop/obj %d, 0;\n", prop_idx);

      key_kind = draw_eval_assoc_key_(idx_expr, &errors);

      switch (ivl_type_base(element_type)) {
	  case IVL_VT_REAL:
	    if (ivl_stmt_opcode(net) != 0) {
		  fprintf(vvp_out, "    %%aa/loadk/r/%s;\n", key_kind);
		  draw_eval_real(rval);
		  draw_stmt_assign_real_opcode(ivl_stmt_opcode(net));
	    } else {
		  draw_eval_real(rval);
	    }
	    fprintf(vvp_out, "    %%aa/store/r/%s;\n", key_kind);
	    fprintf(vvp_out, "    %%pop/obj 2, 0;\n");
	    return errors;
	  case IVL_VT_STRING:
	    draw_eval_string(rval);
	    fprintf(vvp_out, "    %%aa/store/str/%s;\n", key_kind);
	    fprintf(vvp_out, "    %%pop/obj 2, 0;\n");
	    return errors;
	  case IVL_VT_BOOL:
	  case IVL_VT_LOGIC:
	    wid = ivl_type_packed_width(element_type);
	    if (wid == 0)
		  wid = ivl_stmt_lwidth(net);
	    if (ivl_stmt_opcode(net) != 0) {
		  fprintf(vvp_out, "    %%aa/loadk/v/%s %u;\n", key_kind, wid);
		  draw_eval_vec4(rval);
		  resize_vec4_wid(rval, ivl_stmt_lwidth(net));
		  draw_stmt_assign_vector_opcode(ivl_stmt_opcode(net),
					         ivl_expr_signed(rval));
	    } else {
		  draw_eval_vec4(rval);
		  resize_vec4_wid(rval, ivl_stmt_lwidth(net));
	    }
	    fprintf(vvp_out, "    %%aa/store/v/%s %u;\n", key_kind, wid);
	    fprintf(vvp_out, "    %%pop/obj 2, 0;\n");
	    return errors;
	  case IVL_VT_CLASS:
	  case IVL_VT_DARRAY:
	  case IVL_VT_QUEUE:
	  case IVL_VT_NO_TYPE:
	    errors += draw_eval_object(rval);
	    fprintf(vvp_out, "    %%aa/store/obj/%s;\n", key_kind);
	    fprintf(vvp_out, "    %%pop/obj 2, 0;\n");
	    return errors;
	  default:
	    return -1;
	      }
}

static int type_is_object_like_(ivl_type_t type)
{
      if (!type)
            return 0;

      switch (ivl_type_base(type)) {
          case IVL_VT_CLASS:
          case IVL_VT_DARRAY:
          case IVL_VT_QUEUE:
          case IVL_VT_NO_TYPE:
            return 1;
          default:
            return 0;
      }
}

static int queue_pattern_operand_is_object_collection_(ivl_expr_t expr,
                                                       ivl_type_t element_type)
{
      ivl_type_t expr_type;
      ivl_type_t src_element_type;

      if (!expr || !type_is_object_like_(element_type))
            return 0;

      if (expr_is_queue_container_(expr))
            return 1;

      expr_type = ivl_expr_net_type(expr);
      if (!expr_type)
            return ivl_expr_value(expr) == IVL_VT_DARRAY;

      if (ivl_type_base(expr_type) != IVL_VT_QUEUE
          && ivl_type_base(expr_type) != IVL_VT_DARRAY)
            return 0;

      src_element_type = ivl_type_element(expr_type);
      return type_is_object_like_(src_element_type);
}

static int show_stmt_assign_nested_index_object(ivl_statement_t net)
{
      int errors = 0;
      ivl_lval_t lval = ivl_stmt_lval(net, 0);
      ivl_lval_t lval_nest = ivl_lval_nest(lval);
      ivl_expr_t idx_expr = ivl_lval_idx(lval);
      ivl_expr_t rval = ivl_stmt_rval(net);
      ivl_type_t container_type;
      ivl_type_t element_type;
      unsigned lab_null;
      unsigned lab_out;

      if (!lval_nest || !idx_expr || ivl_stmt_opcode(net) != 0)
            return -1;

      container_type = draw_lval_expr(lval_nest);
      if (!container_type) {
            fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
            return 0;
      }

      element_type = ivl_type_element(container_type);
      lab_null = local_count++;
      lab_out = local_count++;

      fprintf(vvp_out, "    %%test_nul/obj;\n");
      fprintf(vvp_out, "    %%jmp/1 T_%u.%u, 4;\n", thread_count, lab_null);

      if ((ivl_type_base(container_type) == IVL_VT_QUEUE)
          && ivl_type_queue_assoc_compat(container_type)
          && type_is_object_like_(element_type)) {
            const char*key_kind;

            key_kind = draw_eval_assoc_key_(idx_expr, &errors);

            errors += draw_eval_object(rval);
            fprintf(vvp_out, "    %%aa/store/obj/%s;\n", key_kind);
            fprintf(vvp_out, "    %%pop/obj 2, 0;\n");

      } else if ((ivl_type_base(container_type) == IVL_VT_DARRAY
                  || ivl_type_base(container_type) == IVL_VT_QUEUE)
                 && type_is_object_like_(element_type)) {
            int idx_word = allocate_word();

            draw_eval_expr_into_integer(idx_expr, idx_word);
            errors += draw_eval_object(rval);
            fprintf(vvp_out, "    %%set/dar/obj/obj %d;\n", idx_word);
            fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
            clr_word(idx_word);

      } else {
            fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
            fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_out);
            fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_null);
            fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
            fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_out);
            return 0;
      }

      fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_out);
      fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_null);
      fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
      fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_out);
      return errors;
}

static int show_stmt_assign_sig_cobject(ivl_statement_t net)
{
      int errors = 0;
      ivl_lval_t lval = ivl_stmt_lval(net, 0);
      ivl_expr_t rval = ivl_stmt_rval(net);
      unsigned lwid = ivl_lval_width(lval);
      int prop_idx = ivl_lval_property_idx(lval);
      static int warned_prop_unhandled_type = 0;


      if (prop_idx >= 0) {
	    ivl_type_t sig_type = draw_lval_expr(lval);
	    ivl_type_t prop_type = ivl_type_prop_type(sig_type, prop_idx);
	    unsigned lab_null = local_count++;
	    unsigned lab_out = local_count++;

	    /* Dynamic null-handle guard: if the receiver object is null, skip
	       property assignment and pop the receiver object without issuing
	       %store/prop* opcodes. */
	    fprintf(vvp_out, "    %%test_nul/obj;\n");
	    fprintf(vvp_out, "    %%jmp/1 T_%u.%u, 4;\n", thread_count, lab_null);

	    if (ivl_type_base(prop_type) == IVL_VT_BOOL ||
	        ivl_type_base(prop_type) == IVL_VT_LOGIC) {
		  int prop_word_idx = 0;
		  ivl_expr_t idx_expr = ivl_lval_idx(lval);
		  assert(ivl_type_packed_dimensions(prop_type) == 0 ||
		         (ivl_type_packed_dimensions(prop_type) == 1 &&
		          ivl_type_packed_msb(prop_type,0) >= ivl_type_packed_lsb(prop_type, 0)));

		  if (idx_expr) {
			prop_word_idx = allocate_word();
			draw_eval_expr_into_integer(idx_expr, prop_word_idx);
		  }

		  if (ivl_stmt_opcode(net) != 0) {
			if (prop_word_idx)
			      fprintf(vvp_out, "    %%prop/v/i %d, %d;\n", prop_idx, prop_word_idx);
			else
			      fprintf(vvp_out, "    %%prop/v %d;\n", prop_idx);
		  }

		  draw_eval_vec4(rval);
		  if (ivl_type_base(prop_type) == IVL_VT_BOOL &&
		      ivl_expr_value(rval) != IVL_VT_BOOL)
			fprintf(vvp_out, "    %%cast2;\n");

		  draw_stmt_assign_vector_opcode(ivl_stmt_opcode(net),
					         ivl_expr_signed(rval));

		  if (prop_word_idx)
			fprintf(vvp_out, "    %%store/prop/v/i %d, %d, %u; Store in logic property %s\n",
				prop_idx, prop_word_idx, lwid, ivl_type_prop_name(sig_type, prop_idx));
		  else
			fprintf(vvp_out, "    %%store/prop/v %d, %u; Store in logic property %s\n",
				prop_idx, lwid, ivl_type_prop_name(sig_type, prop_idx));
		  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
		  if (prop_word_idx) clr_word(prop_word_idx);

	    } else if (ivl_type_base(prop_type) == IVL_VT_REAL) {

		  if (ivl_stmt_opcode(net) != 0) {
			fprintf(vvp_out, "    %%prop/r %d;\n", prop_idx);
		  }

		    /* Calculate the real value into the real value
		       stack. The %store/prop/r will pop the stack
		       value. */
		  draw_eval_real(rval);

		  draw_stmt_assign_real_opcode(ivl_stmt_opcode(net));

		  fprintf(vvp_out, "    %%store/prop/r %d;\n", prop_idx);
		  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");

	    } else if (ivl_type_base(prop_type) == IVL_VT_STRING) {

		    /* Calculate the string value into the string value
		       stack. The %store/prop/r will pop the stack
		       value. */
		  draw_eval_string(rval);
		  fprintf(vvp_out, "    %%store/prop/str %d;\n", prop_idx);
		  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");

	    } else if (ivl_type_base(prop_type) == IVL_VT_DARRAY) {
		  int handled_errors = show_stmt_assign_sig_prop_darray_index(net,
		                                                           prop_idx,
		                                                           prop_type);
		  if (handled_errors >= 0) {
			errors += handled_errors;
		  } else {
			int idx = 0;

			  /* The property is a darray, and there is no mux
			     expression to the assignment is of an entire
			     array object. */
			errors += draw_eval_object(rval);
			fprintf(vvp_out, "    %%store/prop/obj %d, %d; IVL_VT_DARRAY\n",
			        prop_idx, idx);
			fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
		  }

	    } else if (ivl_type_base(prop_type) == IVL_VT_CLASS) {
		  int idx = 0;
		  ivl_expr_t idx_expr;
		  if ( (idx_expr = ivl_lval_idx(lval)) ) {
			idx = allocate_word();
		  }

		    /* The property is a class object. */
		  errors += draw_eval_object(rval);
		  if (idx_expr) draw_eval_expr_into_integer(idx_expr, idx);
		  fprintf(vvp_out, "    %%store/prop/obj %d, %d; IVL_VT_CLASS\n", prop_idx, idx);
		  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");

		  if (idx_expr) clr_word(idx);

	    } else if (ivl_type_base(prop_type) == IVL_VT_QUEUE) {
		  int handled_errors = show_stmt_assign_sig_prop_assoc_index(net,
		                                                           prop_idx,
		                                                           prop_type);
		  if (handled_errors >= 0) {
			errors += handled_errors;
		  } else {
			handled_errors = show_stmt_assign_sig_prop_queue_index(net,
		                                                           prop_idx,
		                                                           prop_type);
			if (handled_errors >= 0) {
			      errors += handled_errors;
			} else {
			ivl_variable_type_t rv_type = ivl_expr_value(rval);
			if (rv_type == IVL_VT_CLASS ||
			    rv_type == IVL_VT_DARRAY ||
			    rv_type == IVL_VT_QUEUE ||
			    ivl_expr_type(rval) == IVL_EX_NULL) {
			      /* Queue or unresolved property: object-like RHS stores as object. */
			      errors += draw_eval_object(rval);
			      fprintf(vvp_out, "    %%store/prop/obj %d, 0;"
				      " ; type-%d fallback\n", prop_idx,
				      ivl_type_base(prop_type));
			      fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
			} else {
			      /* Preserve RHS side effects, then coerce to null object. */
			      draw_eval_vec4(rval);
			      fprintf(vvp_out, "    %%pop/vec4 1;\n");
			      fprintf(vvp_out, "    %%null;\n");
			      fprintf(vvp_out, "    %%store/prop/obj %d, 0;"
				      " ; type-%d null-coerce fallback from rhs-type-%d\n",
				      prop_idx, ivl_type_base(prop_type), rv_type);
			      fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
			}
		  }
		  }

	    } else if (ivl_type_base(prop_type) == IVL_VT_NO_TYPE) {
		  ivl_variable_type_t rv_type = ivl_expr_value(rval);
		  if (rv_type == IVL_VT_CLASS ||
		      rv_type == IVL_VT_DARRAY ||
		      rv_type == IVL_VT_QUEUE ||
		      ivl_expr_type(rval) == IVL_EX_NULL) {
			/* Queue or unresolved property: object-like RHS stores as object. */
			errors += draw_eval_object(rval);
			fprintf(vvp_out, "    %%store/prop/obj %d, 0;"
				" ; type-%d fallback\n", prop_idx,
				ivl_type_base(prop_type));
			fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
		  } else {
			/* Preserve RHS side effects, then coerce to null object. */
			draw_eval_vec4(rval);
			fprintf(vvp_out, "    %%pop/vec4 1;\n");
			fprintf(vvp_out, "    %%null;\n");
			fprintf(vvp_out, "    %%store/prop/obj %d, 0;"
				" ; type-%d null-coerce fallback from rhs-type-%d\n",
				prop_idx, ivl_type_base(prop_type), rv_type);
			fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
		  }

		    } else {
			  if (!warned_prop_unhandled_type) {
				fprintf(stderr, "Warning: unhandled class property type %d;"
					" skipping assignment"
					" (further similar warnings suppressed)\n",
					ivl_type_base(prop_type));
				warned_prop_unhandled_type = 1;
			  }
			  fprintf(vvp_out, " ; skipped: unhandled prop type %d\n",
				  ivl_type_base(prop_type));
			  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
		    }
		    fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_out);
		    fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_null);
		    fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
		    fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_out);

	      } else {
		    ivl_signal_t sig = ivl_lval_sig(lval);
		    int handled_errors;

                    if (sig) {
                          ivl_type_t net_type = ivl_signal_net_type(sig);
                          handled_errors = show_stmt_assign_sig_assoc_index(net, sig, net_type);
                          if (handled_errors >= 0)
                                return errors + handled_errors;
                    }

		    handled_errors = show_stmt_assign_nested_index_object(net);
		    if (handled_errors >= 0)
			  return errors + handled_errors;

		    assert(!ivl_lval_nest(lval));

		    if (ivl_expr_type(rval) == IVL_EX_ARRAY_PATTERN) {
			  draw_array_pattern(sig, rval, 0);
		  return 0;
	    }

	      /* There is no property select, so evaluate the r-value
		 as an object and assign the entire object to the
		 variable. */
	    errors += draw_eval_object(rval);

	    if (ivl_signal_array_count(sig) > 1) {
		  unsigned ix;
		  ivl_expr_t aidx = ivl_lval_idx(lval);

		  draw_eval_expr_into_integer(aidx, (ix = allocate_word()));
		  fprintf(vvp_out, "    %%store/obja v%p, %u;\n", sig, ix);
		  clr_word(ix);

	    } else {
		    /* Not an array, so no index expression */
		  fprintf(vvp_out, "    %%store/obj v%p_0;\n", sig);
	    }
      }

      return errors;
}

int show_stmt_assign(ivl_statement_t net)
{
      ivl_lval_t lval;
      ivl_signal_t sig;

      show_stmt_file_line(net, "Blocking assignment.");

      lval = ivl_stmt_lval(net, 0);

      sig = ivl_lval_sig(lval);
      if (sig && (ivl_signal_data_type(sig) == IVL_VT_REAL)) {
	    return show_stmt_assign_sig_real(net);
      }

      if (sig && (ivl_signal_data_type(sig) == IVL_VT_STRING)) {
	    return show_stmt_assign_sig_string(net);
      }

      if (sig && (ivl_signal_data_type(sig) == IVL_VT_DARRAY)) {
	    return show_stmt_assign_sig_darray(net);
      }

      if (sig && (ivl_signal_data_type(sig) == IVL_VT_QUEUE)) {
	    return show_stmt_assign_sig_queue(net);
      }

      if ((sig && ((ivl_signal_data_type(sig) == IVL_VT_CLASS)
                || (ivl_signal_data_type(sig) == IVL_VT_NO_TYPE))) ||
          ivl_lval_nest(lval)) {
	    return show_stmt_assign_sig_cobject(net);
      }

      return show_stmt_assign_vector(net);
}
