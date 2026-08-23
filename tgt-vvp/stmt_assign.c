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
# include  <inttypes.h>

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
		    /* Constant bit offset of a part-select ON the word
		       (arr[i][m:l] op= ...); part_wid != 0 marks a partial
		       slice (it can be offset 0 with a narrow width). */
		  unsigned long part_off;
		  unsigned part_wid;
		    /* Reg holding a DYNAMIC part offset, or 0. */
		  int part_off_reg;
		    /* Stored validity flag for that dynamic part offset, or 0. */
		  unsigned part_x_flag;
	    } memory_word_static;

	    struct {
		    /* Index reg that holds the memory word index */
		  int word_idx_reg;
		    /* Stored x/non-x flag */
		  unsigned x_flag;
		    /* Partial slice on the word: see memory_word_static. */
		  unsigned long part_off;
		  unsigned part_wid;
		  int part_off_reg;
		  unsigned part_x_flag;
	    } memory_word_dynamic;
      } u_;
};

static int expr_is_numeric_container_index_(ivl_expr_t expr);
static int prop_is_numeric_queue_index_(ivl_type_t prop_type, ivl_expr_t idx_expr);
static int show_stmt_assign_sig_assoc_index(ivl_statement_t net,
                                            ivl_signal_t var,
                                            ivl_type_t var_type);


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
	    long immediate = get_number_immediate(part_off_ex);
	    if (immediate >= 0) {
		  part_off = (unsigned long)immediate;
		  part_off_ex = 0;
	    }
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
	    fprintf(vvp_out, "    %%ix/vec4%s %d;\n",
		    ivl_expr_signed(part_off_ex) ? "/s" : "",
		    slice->u_.part_select_dynamic.word_idx_reg);
	    fprintf(vvp_out, "    %%flag_mov %u, 4;\n", slice->u_.part_select_dynamic.x_flag);
	    fprintf(vvp_out, "    %%part/%c %u;\n",
		    ivl_expr_signed(part_off_ex) ? 's' : 'u', wid);

      } else if (ivl_signal_dimensions(sig) > 0 && word_ix == 0) {

	    assert(!signal_is_return_value(sig)); // NOT IMPLEMENTED

	    slice->type = SLICE_MEMORY_WORD_STATIC;
	    slice->u_.memory_word_static.use_word = use_word;
	    slice->u_.memory_word_static.part_off = part_off;
	    slice->u_.memory_word_static.part_wid =
		  (wid < ivl_signal_width(sig) || part_off != 0) ? wid : 0;
	    slice->u_.memory_word_static.part_off_reg = 0;
	    slice->u_.memory_word_static.part_x_flag = 0;
	    if (use_word < ivl_signal_array_count(sig)) {
		  fprintf(vvp_out, "    %%ix/load 3, %lu, 0;\n",
			  use_word);
		  fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
		  fprintf(vvp_out, "    %%load/vec4a v%p, 3;\n", sig);
		    /* A part-select ON the array word (arr[i][m:l] op= ...):
		       extract the part so the compound opcode sees matching
		       operand widths. The old code loaded the WHOLE word,
		       crashing %add/%xor on width mismatch and applying |=
		       to the entire element; the store side then wrote back
		       at offset 0. */
		  if (part_off_ex) {
			slice->u_.memory_word_static.part_off_reg = allocate_word();
			slice->u_.memory_word_static.part_x_flag = allocate_flag();
			slice->u_.memory_word_static.part_wid = wid;
			draw_eval_vec4(part_off_ex);
			fprintf(vvp_out, "    %%dup/vec4;\n");
			fprintf(vvp_out, "    %%ix/vec4%s %d;\n",
				ivl_expr_signed(part_off_ex) ? "/s" : "",
				slice->u_.memory_word_static.part_off_reg);
			fprintf(vvp_out, "    %%flag_mov %u, 4;\n",
				slice->u_.memory_word_static.part_x_flag);
			fprintf(vvp_out, "    %%part/%c %u;\n",
				ivl_expr_signed(part_off_ex) ? 's' : 'u', wid);
		  } else if (slice->u_.memory_word_static.part_wid) {
			fprintf(vvp_out, "    %%parti/u %u, %lu, 32;\n",
				wid, part_off);
		  }
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
	    slice->u_.memory_word_dynamic.part_off = part_off;
	    slice->u_.memory_word_dynamic.part_wid =
		  (wid < ivl_signal_width(sig) || part_off != 0) ? wid : 0;
	    slice->u_.memory_word_dynamic.part_off_reg = 0;
	    slice->u_.memory_word_dynamic.part_x_flag = 0;

		  draw_eval_expr_into_integer(word_ix, slice->u_.memory_word_dynamic.word_idx_reg);
		  fprintf(vvp_out, "    %%flag_mov %u, 4;\n", slice->u_.memory_word_dynamic.x_flag);
		  note_array_signal_use(sig);
		  fprintf(vvp_out, "    %%load/vec4a v%p, %d;\n", sig, slice->u_.memory_word_dynamic.word_idx_reg);
		    /* Part-select on the dynamically-indexed word: see the
		       static-word branch above. */
		  if (part_off_ex) {
			slice->u_.memory_word_dynamic.part_off_reg = allocate_word();
			slice->u_.memory_word_dynamic.part_x_flag = allocate_flag();
			slice->u_.memory_word_dynamic.part_wid = wid;
			draw_eval_vec4(part_off_ex);
			fprintf(vvp_out, "    %%dup/vec4;\n");
			fprintf(vvp_out, "    %%ix/vec4%s %d;\n",
				ivl_expr_signed(part_off_ex) ? "/s" : "",
				slice->u_.memory_word_dynamic.part_off_reg);
			fprintf(vvp_out, "    %%flag_mov %u, 4;\n",
				slice->u_.memory_word_dynamic.part_x_flag);
			fprintf(vvp_out, "    %%part/%c %u;\n",
				ivl_expr_signed(part_off_ex) ? 's' : 'u', wid);
		  } else if (slice->u_.memory_word_dynamic.part_wid) {
			fprintf(vvp_out, "    %%parti/u %u, %lu, 32;\n",
				wid, part_off);
		  }

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
		  int off_idx = slice->u_.memory_word_static.part_off_reg;
		  fprintf(vvp_out,"    %%ix/load %d, %lu, 0;\n", word_idx, slice->u_.memory_word_static.use_word);
		  note_array_signal_use(sig);
		    /* Partial slice: store back AT the part offset — the runtime
		       set_word(adr, off, val) read-modify-writes the word (a
		       narrow in-bounds value is left alone by resize_rval_vec).
		       The old code always stored at offset 0. */
		  if (!off_idx && slice->u_.memory_word_static.part_wid
		      && slice->u_.memory_word_static.part_off) {
			off_idx = allocate_word();
			fprintf(vvp_out,"    %%ix/load %d, %lu, 0;\n",
				off_idx, slice->u_.memory_word_static.part_off);
		  }
		  if (slice->u_.memory_word_static.part_x_flag)
			fprintf(vvp_out, "    %%flag_mov 4, %u;\n",
				slice->u_.memory_word_static.part_x_flag);
		  else
			fprintf(vvp_out,"    %%flag_set/imm 4, 0;\n");
		  fprintf(vvp_out,"    %%store/vec4a v%p, %d, %d;\n", sig,
			  word_idx, off_idx);
		  clr_word(word_idx);
		  if (off_idx) clr_word(off_idx);
		  if (slice->u_.memory_word_static.part_x_flag)
			clr_flag(slice->u_.memory_word_static.part_x_flag);
	    } else {
		  fprintf(vvp_out," ; Skip this slice write to v%p [%lu]\n", sig, slice->u_.memory_word_static.use_word);
		  fprintf(vvp_out,"    %%pop/vec4 1;\n");
	    }
	    break;

	  case SLICE_MEMORY_WORD_DYNAMIC: {
	    int off_idx = slice->u_.memory_word_dynamic.part_off_reg;
	    note_array_signal_use(sig);
	    if (!off_idx && slice->u_.memory_word_dynamic.part_wid
		&& slice->u_.memory_word_dynamic.part_off) {
		  off_idx = allocate_word();
		  fprintf(vvp_out,"    %%ix/load %d, %lu, 0;\n",
			  off_idx, slice->u_.memory_word_dynamic.part_off);
	    }
	    fprintf(vvp_out, "    %%flag_mov 4, %u;\n",
		    slice->u_.memory_word_dynamic.x_flag);
	    if (slice->u_.memory_word_dynamic.part_x_flag)
		  fprintf(vvp_out, "    %%flag_or 4, %u;\n",
			  slice->u_.memory_word_dynamic.part_x_flag);
	    fprintf(vvp_out, "    %%store/vec4a v%p, %d, %d;\n", sig,
		    slice->u_.memory_word_dynamic.word_idx_reg, off_idx);
	    clr_word(slice->u_.memory_word_dynamic.word_idx_reg);
	    if (off_idx) clr_word(off_idx);
	    clr_flag(slice->u_.memory_word_dynamic.x_flag);
	    if (slice->u_.memory_word_dynamic.part_x_flag)
		  clr_flag(slice->u_.memory_word_dynamic.part_x_flag);
	    break;
	  }

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

	      /* A static unpacked array of class handles (`c arr[N]`) reports
		 its net_type as the ELEMENT class directly (no array wrapper),
		 while still carrying array dimensions. Load the indexed
		 element with %load/obja; the element type IS sig_type. Without
		 this the class-index block below (which expects an array
		 wrapper with a non-null ivl_type_element) fell through to the
		 scalar %load/obj fallback, dropping the index. */
	    if (word_ex && sig_type
		&& ivl_type_base(sig_type) == IVL_VT_CLASS
		&& ivl_signal_dimensions(lval_sig) > 0) {
		  draw_eval_expr_into_integer(word_ex, 3);
		  fprintf(vvp_out, "    %%load/obja v%p, 3;\n", lval_sig);
		  return sig_type;
	    }

	      /* A static unpacked array of an object-backed UNPACKED struct
		 (`struct{...} arr[N]`) reports the element struct directly as
		 its net_type (base IVL_VT_NO_TYPE with properties) while still
		 carrying array dimensions, like the class-array case above.
		 Load the indexed element with %load/obja so a member write
		 `arr[i].field = ...` addresses the right element; the runtime
		 lazily default-constructs a nil element on load. Without this
		 the scalar %load/obj fallback loaded the whole array-of-objects
		 as a single (nil) handle and dropped every member write. */
	    if (word_ex && sig_type
		&& ivl_type_base(sig_type) == IVL_VT_NO_TYPE
		&& ivl_type_properties(sig_type) > 0
		&& ivl_signal_dimensions(lval_sig) > 0) {
		  draw_eval_expr_into_integer(word_ex, 3);
		  fprintf(vvp_out, "    %%load/obja v%p, 3;\n", lval_sig);
		  return sig_type;
	    }

	    if (word_ex && sig_type) {
		  ivl_type_t element_type = ivl_type_element(sig_type);
		    /* The element is object-backed when it is a class handle or
		       an object-backed unpacked struct (base IVL_VT_NO_TYPE with
		       properties). A dynamic array / queue of such an element
		       stores each entry as an object, so a member write
		       `arr[i].field = ...` must load the addressed ELEMENT as an
		       object (not the whole array) and return the element type so
		       the property store selects the right opcode. Without the
		       NO_TYPE case a darray/queue of unpacked structs fell through
		       to the whole-array %load/obj below and dropped the index. */
		  int elem_is_object = element_type &&
			(ivl_type_base(element_type) == IVL_VT_CLASS
			 || (ivl_type_base(element_type) == IVL_VT_NO_TYPE
			     && ivl_type_properties(element_type) > 0));
		  if (elem_is_object) {
			  /* An associative array keyed by a class handle (or any
			     assoc key) is an IVL_VT_QUEUE with assoc-compat. Its
			     element is fetched with %aa/load using the real key —
			     NOT %load/dar/obj with the key coerced to an integer,
			     which turned `assoc[classkey].prop = v` into a store
			     against a garbage darray word (the key's null-test
			     flag), so uvm_reg's `m_regs_info[rg].addr = addrs`
			     register-address cache silently vanished. */
			if (ivl_type_base(sig_type) == IVL_VT_QUEUE &&
			    ivl_type_queue_assoc_compat(sig_type)) {
			      const char*key_kind = draw_eval_assoc_key_(word_ex, 0);
			      /* L-value path: get-or-CREATE the element so a
				 member write into a not-yet-present assoc entry
				 (`a[key].field = ...`) is inserted and persists,
				 instead of storing through a discarded default. */
			      fprintf(vvp_out, "    %%aa/loadlv/sig/obj/%s v%p_0;\n",
				      key_kind, lval_sig);
			      return element_type;
			}
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
	      /* A DYNAMIC ARRAY property indexes like a queue property:
		 the property slot holds ONE object (the container), so
		 the element index belongs inside the container, not on
		 %prop/obj. Passing it as a slot index made
		 `obj.arr[i].member = v' read the CONTAINER as the
		 receiver -- a silent wrong store for index 0 and a
		 runtime abort (assert idx < array_size_) for index >= 1.
		 %load/qo/obj accepts any vvp_darray receiver, queue or
		 plain dynamic array, so the queue lowering is exactly
		 right here. A fixed-size unpacked array property still
		 takes the slot-index path below, where the index IS a
		 slot index. */
	    if (prop_is_numeric_queue_index_(prop_type, nested_idx_expr)
		|| (prop_type
		    && ivl_type_base(prop_type) == IVL_VT_DARRAY
		    && expr_is_numeric_container_index_(nested_idx_expr))) {
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
static void store_vec4_to_one_lval(ivl_lval_t lval)
{
	    ivl_signal_t lsig = ivl_lval_sig(lval);
	    unsigned lwid = ivl_lval_width(lval);
	    ivl_expr_t part_off_ex = ivl_lval_part_off(lval);
	      /* This is non-nil if the l-val is the word of a memory,
		 and nil otherwise. */
	    ivl_expr_t word_ex = ivl_lval_idx(lval);

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

static void store_vec4_to_lval(ivl_statement_t net)
{
      for (unsigned lidx = 0 ; lidx < ivl_stmt_lvals(net) ; lidx += 1) {
	    ivl_lval_t lval = ivl_stmt_lval(net,lidx);
	    unsigned lwid = ivl_lval_width(lval);

	    if (lidx+1 < ivl_stmt_lvals(net))
		  fprintf(vvp_out, "    %%split/vec4 %u;\n", lwid);

	    store_vec4_to_one_lval(lval);
      }
}

/* Base word for an array-pattern store. A partial index on the l-value is
 * an unpacked-array slice (m[i] = '{...}); elaboration put the slice's flat
 * base word into the l-value index, so the pattern store starts there. A
 * whole-array pattern has no l-value index and starts at word 0. */
static unsigned int array_pattern_base_(ivl_lval_t lval)
{
      ivl_expr_t idx = ivl_lval_idx(lval);
      if (idx == 0)
	    return 0;
      assert(ivl_expr_type(idx) == IVL_EX_NUMBER);
      return (unsigned int) get_number_immediate(idx);
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
		    /* An object-like array element can itself be written as an
		     * assignment pattern, but a multidimensional array also uses
		     * nested IVL_EX_ARRAY_PATTERN nodes for its remaining unpacked
		     * dimensions.  The expression's net type distinguishes them:
		     * an unpacked-array node still has an element type, while the
		     * terminal struct/union aggregate has properties instead. */
		  if (type_is_object_like_(elem_type)
		      && !(ivl_expr_net_type(expr)
			   && ivl_type_element(ivl_expr_net_type(expr))
			   && !ivl_type_is_packed_vector(
				 ivl_expr_net_type(expr)))) {
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

/* Store an unpacked-array assignment pattern into a logic-array class
 * property, element by element (`obj.arr = '{...}` where arr is an
 * unpacked array of packed values).  The receiver object must already be
 * on top of the object stack: %store/prop/v/i peeks it (does not pop), so
 * one push serves every element and the caller pops once afterward.
 * word_reg is a scratch integer register carrying each element's array
 * index; array_idx is the running flat element counter.  A nested pattern
 * (a multidimensional unpacked array) recurses with the same running
 * index.  Returns the next flat element index. */
static unsigned int draw_prop_array_pattern(int prop_idx, const char*prop_name,
					    ivl_expr_t rval, int word_reg,
					    unsigned int array_idx)
{
      for (unsigned int idx = 0; idx < ivl_expr_parms(rval); idx += 1) {
	    ivl_expr_t expr = ivl_expr_parm(rval, idx);
	    if (ivl_expr_type(expr) == IVL_EX_ARRAY_PATTERN) {
		  array_idx = draw_prop_array_pattern(prop_idx, prop_name,
						      expr, word_reg, array_idx);
		  continue;
	    }
	    draw_eval_vec4(expr);
	    fprintf(vvp_out, "    %%ix/load %d, %u, 0;\n", word_reg, array_idx);
	    fprintf(vvp_out, "    %%store/prop/v/i %d, %d, %u;"
		    " array-pattern element into logic property %s\n",
		    prop_idx, word_reg, ivl_expr_width(expr), prop_name);
	    array_idx += 1;
      }
      return array_idx;
}

/* As draw_prop_array_pattern, but for a real-valued class-property array
 * (`obj.arr = '{...}` where arr is an unpacked array of real). */
static unsigned int draw_prop_real_array_pattern(int prop_idx, const char*prop_name,
						 ivl_expr_t rval, int word_reg,
						 unsigned int array_idx)
{
      for (unsigned int idx = 0; idx < ivl_expr_parms(rval); idx += 1) {
	    ivl_expr_t expr = ivl_expr_parm(rval, idx);
	    if (ivl_expr_type(expr) == IVL_EX_ARRAY_PATTERN) {
		  array_idx = draw_prop_real_array_pattern(prop_idx, prop_name,
							   expr, word_reg, array_idx);
		  continue;
	    }
	    draw_eval_real(expr);
	    fprintf(vvp_out, "    %%ix/load %d, %u, 0;\n", word_reg, array_idx);
	    fprintf(vvp_out, "    %%store/prop/r/i %d, %d;"
		    " array-pattern element into real property %s\n",
		    prop_idx, word_reg, prop_name);
	    array_idx += 1;
      }
      return array_idx;
}

/* As draw_prop_array_pattern, but for a string-valued class-property
 * array (`obj.arr = '{...}` where arr is an unpacked array of string). */
static unsigned int draw_prop_str_array_pattern(int prop_idx, const char*prop_name,
						ivl_expr_t rval, int word_reg,
						unsigned int array_idx)
{
      for (unsigned int idx = 0; idx < ivl_expr_parms(rval); idx += 1) {
	    ivl_expr_t expr = ivl_expr_parm(rval, idx);
	    if (ivl_expr_type(expr) == IVL_EX_ARRAY_PATTERN) {
		  array_idx = draw_prop_str_array_pattern(prop_idx, prop_name,
							  expr, word_reg, array_idx);
		  continue;
	    }
	    draw_eval_string(expr);
	    fprintf(vvp_out, "    %%ix/load %d, %u, 0;\n", word_reg, array_idx);
	    fprintf(vvp_out, "    %%store/prop/str/i %d, %d;"
		    " array-pattern element into string property %s\n",
		    prop_idx, word_reg, prop_name);
	    array_idx += 1;
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
	    draw_array_pattern(sig, rval, array_pattern_base_(lval));
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

static int packed_property_offset_is_unknown_(ivl_expr_t expr)
{
      return ivl_expr_type(expr) == IVL_EX_NUMBER
	  && number_is_unknown(expr);
}

static int packed_property_offset_is_negative_(ivl_expr_t expr)
{
      if (ivl_expr_type(expr) != IVL_EX_NUMBER || !ivl_expr_signed(expr)
	  || ivl_expr_width(expr) == 0 || number_is_unknown(expr))
	    return 0;

      return ivl_expr_bits(expr)[ivl_expr_width(expr)-1] == '1';
}

static int packed_property_offset_is_immediate_(ivl_expr_t expr)
{
      if (ivl_expr_type(expr) != IVL_EX_NUMBER
	  && ivl_expr_type(expr) != IVL_EX_ULONG)
	    return 0;
      if (packed_property_offset_is_unknown_(expr))
	    return 0;
      return number_is_immediate(expr, 32, 0);
}

/* Return the exact two's-complement bits of a defined negative constant when
 * it fits the run-time signed property-offset register. This deliberately
 * includes INT64_MIN, which number_is_immediate(..., 64, true) rejects because
 * that older helper assumes every negative immediate will later be negated.
 * Property offsets are never negated by code generation. */
static int packed_property_negative_offset_bits64_(ivl_expr_t expr,
						     uint64_t*value)
{
      const char*bits;
      unsigned width;
      uint64_t result = 0;

      if (!packed_property_offset_is_negative_(expr)
	  || number_is_unknown(expr))
	    return 0;

      bits = ivl_expr_bits(expr);
      width = ivl_expr_width(expr);

	/* A value wider than int64_t fits only when bit 63 and every more
	 * significant bit are sign-extension ones. */
      if (width > 64) {
	    for (unsigned idx = 63; idx < width; idx += 1)
		  if (bits[idx] != '1')
			return 0;
      }

      unsigned copy_width = width < 64 ? width : 64;
      for (unsigned idx = 0; idx < copy_width; idx += 1) {
	    if (bits[idx] == '1')
		  result |= UINT64_C(1) << idx;
	    else if (bits[idx] != '0')
		  return 0;
      }
      if (width < 64)
	    result |= ~UINT64_C(0) << width;

      *value = result;
      return 1;
}

static void emit_packed_property_negative_offset_(int word,
						    uint64_t value)
{
      fprintf(vvp_out, "    %%ix/load %d, %" PRIu32 ", %" PRIu32 ";\n",
	      word, (uint32_t)value, (uint32_t)(value >> 32));
      fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
}

/* A concatenation containing interface/class integral properties is exported
 * as multiple l-values, least-significant (source-rightmost) first. The
 * ordinary class-property path handles one l-value and would silently store
 * only index zero, while the ordinary vector path cannot store through an
 * object receiver. Split the packed r-value exactly as an ordinary
 * concatenation, dispatching each slice to either a property or vector store.
 * This also handles constant packed-field offsets within a property. */
static int show_stmt_assign_concat_cobject_(ivl_statement_t net)
{
      unsigned lvals = ivl_stmt_lvals(net);
      ivl_expr_t rval = ivl_stmt_rval(net);
      int have_property = 0;

      if (lvals < 2 || ivl_stmt_opcode(net) != 0 || !rval)
	    return -1;

	/* First distinguish this path from an ordinary vector concatenation. */
      for (unsigned idx = 0; idx < lvals; idx += 1) {
	    ivl_lval_t lval = ivl_stmt_lval(net, idx);
	    if (ivl_lval_property_idx(lval) >= 0)
		  have_property = 1;
      }
      if (!have_property)
	    return -1;

	/* Validate the complete destination before emitting any partial store. */
      for (unsigned idx = 0; idx < lvals; idx += 1) {
	    ivl_lval_t lval = ivl_stmt_lval(net, idx);
	    ivl_signal_t sig = ivl_lval_sig(lval);
	    int prop_idx = ivl_lval_property_idx(lval);
	    if (!sig || ivl_lval_nest(lval)) {
		  fprintf(stderr, "%s:%u: sorry: nested or signal-less member in "
			  "a packed property concatenation is not yet supported.\n",
			  ivl_stmt_file(net), ivl_stmt_lineno(net));
		  return 1;
	    }

	    if (prop_idx >= 0) {
		  ivl_type_t owner_type = ivl_signal_net_type(sig);
		  ivl_expr_t part_off = ivl_lval_part_off(lval);
		  if (ivl_lval_idx(lval) || (part_off
		      && ivl_expr_type(part_off) != IVL_EX_NUMBER
		      && ivl_expr_type(part_off) != IVL_EX_ULONG)) {
			fprintf(stderr, "%s:%u: sorry: indexed or dynamically "
				"selected member in a packed property concatenation "
				"is not yet supported.\n",
				ivl_stmt_file(net), ivl_stmt_lineno(net));
			return 1;
		  }
		  if (!owner_type || prop_idx >= ivl_type_properties(owner_type)) {
			fprintf(stderr, "%s:%u: error: cannot resolve property %d "
				"in packed concatenation assignment.\n",
				ivl_stmt_file(net), ivl_stmt_lineno(net), prop_idx);
			return 1;
		  }
		  ivl_type_t prop_type = ivl_type_prop_type(owner_type, prop_idx);
		  if (!prop_type || (ivl_type_base(prop_type) != IVL_VT_BOOL
			       && ivl_type_base(prop_type) != IVL_VT_LOGIC)) {
			fprintf(stderr, "%s:%u: error: property in packed "
				"concatenation assignment is not an integral packed "
				"type.\n", ivl_stmt_file(net), ivl_stmt_lineno(net));
			return 1;
		  }
	    } else {
		  ivl_type_t lval_type = ivl_lval_net_type(lval);
		  if (!lval_type)
			lval_type = ivl_signal_net_type(sig);
		  if (!lval_type || (ivl_type_base(lval_type) != IVL_VT_BOOL
			       && ivl_type_base(lval_type) != IVL_VT_LOGIC)) {
			fprintf(stderr, "%s:%u: error: nonintegral ordinary "
				"member in packed property concatenation assignment.\n",
				ivl_stmt_file(net), ivl_stmt_lineno(net));
			return 1;
		  }
	    }
      }

      draw_eval_vec4(rval);
      resize_vec4_wid(rval, ivl_stmt_lwidth(net));

      for (unsigned idx = 0; idx < lvals; idx += 1) {
	    ivl_lval_t lval = ivl_stmt_lval(net, idx);
	    unsigned width = ivl_lval_width(lval);
	    int prop_idx = ivl_lval_property_idx(lval);

	    if (idx + 1 < lvals)
		  fprintf(vvp_out, "    %%split/vec4 %u;\n", width);

	    if (prop_idx < 0) {
		  store_vec4_to_one_lval(lval);
		  continue;
	    }

	    unsigned lab_null = local_count++;
	    unsigned lab_out = local_count++;
	    ivl_type_t owner_type = draw_lval_expr(lval);
	    ivl_type_t prop_type = ivl_type_prop_type(owner_type, prop_idx);
	    ivl_expr_t part_off = ivl_lval_part_off(lval);
	    uint64_t negative_part_off_bits = 0;
	    int dynamic_part_off = part_off
		  && packed_property_negative_offset_bits64_(
			part_off, &negative_part_off_bits);
	      /* An X/Z or nonnegative constant too large for any packed property
	       * is wholly out of bounds. The assignment slice is a no-op, but the
	       * complete r-value and receiver have already been evaluated and
	       * ordinary sibling slices must still be stored. A defined negative
	       * base instead takes the dynamic opcode so a partially overlapping
	       * indexed part-select still updates its in-range bits. */
	    if (part_off && !dynamic_part_off
		  && !packed_property_offset_is_immediate_(part_off)) {
		  fprintf(vvp_out, "    %%pop/obj 1, 0; Discard receiver for "
			  "unknown/out-of-range property offset\n");
		  fprintf(vvp_out, "    %%pop/vec4 1; Discard no-op "
			  "concatenation slice\n");
		  continue;
	    }
	    int off_reg = 0;
	    int off_flag = 0;
	    if (dynamic_part_off) {
		  off_reg = allocate_word();
		  off_flag = allocate_flag();
		  emit_packed_property_negative_offset_(
			off_reg, negative_part_off_bits);
		  fprintf(vvp_out, "    %%flag_mov %d, 4;\n", off_flag);
	    }
	    fprintf(vvp_out, "    %%test_nul/obj;\n");
	    fprintf(vvp_out, "    %%jmp/1 T_%u.%u, 4;\n",
		    thread_count, lab_null);
	    if (ivl_type_base(prop_type) == IVL_VT_BOOL)
		  fprintf(vvp_out, "    %%cast2;\n");
	    if (dynamic_part_off) {
		  fprintf(vvp_out, "    %%flag_mov 4, %d;\n", off_flag);
		  fprintf(vvp_out,
			  "    %%store/prop/v/bits/x %d, %d, %u; Store "
			  "concatenation slice at signed property offset\n",
			  prop_idx, off_reg, width);
	    } else if (part_off) {
		  unsigned bitoff = (unsigned)ivl_expr_uvalue(part_off);
		  fprintf(vvp_out,
			  "    %%store/prop/v/bits %d, %u, %u; Store "
			  "concatenation slice in field [%u+:%u] of property %s\n",
			  prop_idx, bitoff, width, bitoff, width,
			  ivl_type_prop_name(owner_type, prop_idx));
	    } else {
		  fprintf(vvp_out,
			  "    %%store/prop/v %d, %u; Store concatenation slice "
			  "in logic property %s\n",
			  prop_idx, width,
			  ivl_type_prop_name(owner_type, prop_idx));
	    }
	    fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
	    fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_out);
	    fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_null);
	    fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
	    fprintf(vvp_out, "    %%pop/vec4 1;\n");
	    fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_out);
	    if (dynamic_part_off) {
		  clr_word(off_reg);
		  clr_flag(off_flag);
	    }
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
	    draw_array_pattern(sig, rval, array_pattern_base_(lval));
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
      /* Compound string assignments (+=, etc.) are not yet supported.
       * Compile-progress: skip and continue rather than asserting. */
      if (ivl_stmt_opcode(net) != 0) {
	    fprintf(stderr, "%s: warning: compound string assignment (op='%c') "
		    "not yet supported (compile-progress: skipped).\n",
		    ivl_stmt_file(net), ivl_stmt_opcode(net));
	    return 0;
      }

      if (ivl_expr_type(rval) == IVL_EX_ARRAY_PATTERN) {
	    draw_array_pattern(var, rval, array_pattern_base_(lval));
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

        /* An unpacked-array concatenation is represented as an array pattern
         * whose collection operands retain the destination container type.
         * Its size is the sum of those runtime-sized operands plus its scalar
         * operands, not simply ivl_expr_parms(). Build it in a temporary
         * queue, then convert the queue to the declared dynamic-array type. */
      int has_collection_operand = 0;
      for (idx = 0; idx < ivl_expr_parms(rval); idx += 1) {
            if (queue_pattern_operand_is_collection_(
                        ivl_expr_parm(rval, idx), element_type)) {
                  has_collection_operand = 1;
                  break;
            }
      }

      if (has_collection_operand) {
            char enc[32];
            unsigned elem_wid = ivl_type_packed_width(element_type);
            stream_elem_type_text(element_type, enc, sizeof enc);
            fprintf(vvp_out, "    %%new/queue \"%s\"; darray concat builder\n",
                    enc);

            for (idx = 0; idx < ivl_expr_parms(rval); idx += 1) {
                  ivl_expr_t parm = ivl_expr_parm(rval, idx);
                  fprintf(vvp_out, "    %%dup/obj/ref; darray concat receiver\n");
                  if (queue_pattern_operand_is_collection_(parm, element_type)) {
                        errors += draw_eval_object(parm);
                        switch (ivl_type_base(element_type)) {
                            case IVL_VT_REAL:
                              fprintf(vvp_out, "    %%append/qo/r;\n");
                              break;
                            case IVL_VT_STRING:
                              fprintf(vvp_out, "    %%append/qo/str;\n");
                              break;
                            case IVL_VT_BOOL:
                            case IVL_VT_LOGIC:
                              fprintf(vvp_out, "    %%append/qo/v %u;\n",
                                      elem_wid);
                              break;
                            default:
                              fprintf(vvp_out, "    %%append/qo/obj;\n");
                              break;
                        }
                        continue;
                  }

                  switch (ivl_type_base(element_type)) {
                      case IVL_VT_REAL:
                        draw_eval_real(parm);
                        fprintf(vvp_out, "    %%store/qo/b/r;\n");
                        break;
                      case IVL_VT_STRING:
                        draw_eval_string(parm);
                        fprintf(vvp_out, "    %%store/qo/b/str;\n");
                        break;
                      case IVL_VT_BOOL:
                      case IVL_VT_LOGIC:
                        draw_eval_vec4(parm);
                        if (ivl_expr_width(parm) != elem_wid)
                              fprintf(vvp_out, "    %%pad/%c %u;\n",
                                      (ivl_type_signed(element_type)
                                       && ivl_expr_signed(parm)) ? 's' : 'u',
                                      elem_wid);
                        fprintf(vvp_out, "    %%store/qo/b/v %u;\n", elem_wid);
                        break;
                      default:
                        errors += draw_eval_object_value_copy(parm, element_type);
                        fprintf(vvp_out, "    %%store/qo/b/obj;\n");
                        break;
                  }
            }

            fprintf(vvp_out, "    %%queue/to/darray \"%s\";\n", enc);
            if (ivl_type_base(element_type) == IVL_VT_NO_TYPE
                && ivl_type_properties(element_type) > 0) {
                  ensure_class_type_emitted(element_type);
                  fprintf(vvp_out,
                          "    %%new/cobj C%p; darray concat element prototype\n",
                          element_type);
                  fprintf(vvp_out, "    %%dar/elem/proto;\n");
            }
            fprintf(vvp_out, "    %%store/obj v%p_0;\n", var);
            clr_word(size_reg);
            return errors;
      }

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

		case IVL_VT_NO_TYPE:
		  errors += draw_eval_object_value_copy(
			  ivl_expr_parm(rval, idx), element_type);
		  fprintf(vvp_out, "    %%ix/load 3, %u, 0;\n", idx);
		  fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
		  fprintf(vvp_out, "    %%store/dar/obj v%p_0;\n", var);
		  break;

		case IVL_VT_CLASS:
		case IVL_VT_DARRAY:
		case IVL_VT_QUEUE:
		  errors += draw_eval_object(ivl_expr_parm(rval, idx));
		  fprintf(vvp_out, "    %%ix/load 3, %u, 0;\n", idx);
		  fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
		  fprintf(vvp_out, "    %%store/dar/obj v%p_0;\n", var);
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
	  case IVL_VT_NO_TYPE:
		    assert(ivl_stmt_opcode(net) == 0);
		      /* An object-backed unpacked-struct element has VALUE
			 semantics: `da[i] = x` (or `q[i] = x`) must copy x's
			 contents into a fresh object, not alias x's object.
			 draw_eval_object_value_copy clones a value-struct read;
			 a class element / fresh aggregate passes through. */
		    draw_eval_object_value_copy(rval, element_type);
		    draw_eval_expr_into_integer(mux, 3);
		    break;
	  case IVL_VT_CLASS:
	  case IVL_VT_DARRAY:
	  case IVL_VT_QUEUE:
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

	/* Part/bit-select store into a dynamic-array (or queue) element
	   whose base type is a packed vector: d[i][off +: wid] = rhs. Lower
	   as a read-modify-write with %store/dar/vec4/off. The element-
	   relative offset expression (already normalized during elaboration)
	   is evaluated into an integer register, so a run-time-variable bit
	   index works. Non-vector elements or compound assignments fall to
	   the loud sorry below. */
      if (part != 0 && ivl_lval_idx(lval) && ivl_stmt_opcode(net) == 0
	  && (ivl_type_base(element_type) == IVL_VT_BOOL
	      || ivl_type_base(element_type) == IVL_VT_LOGIC)) {
	    ivl_expr_t mux = ivl_lval_idx(lval);
	    unsigned lwid = ivl_lval_width(lval);
	    int mux_word = allocate_word();
	    int off_word = allocate_word();
	    int flag = allocate_flag();

	      /* Evaluate the element address into reg 3, then stash it (and
		 the address-undefined flag 4) across the offset and r-value
		 evaluations, which may clobber both. */
	    draw_eval_expr_into_integer(mux, 3);
	    fprintf(vvp_out, "    %%ix/mov %d, 3;\n", mux_word);
	    fprintf(vvp_out, "    %%flag_mov %d, 4;\n", flag);
	    draw_eval_expr_into_integer(part, off_word);
	    draw_eval_vec4(rval);
	    resize_vec4_wid(rval, lwid);
	    fprintf(vvp_out, "    %%flag_mov 4, %d;\n", flag);
	    fprintf(vvp_out, "    %%ix/mov 3, %d;\n", mux_word);
	    fprintf(vvp_out, "    %%store/dar/vec4/off v%p_0, %d, %u;\n",
		    var, off_word, lwid);
	    clr_flag(flag);
	    clr_word(off_word);
	    clr_word(mux_word);
	    return errors;
      }

      if (part != 0) {
	      /* A darray/queue element part-select we cannot lower yet
		 (non-vector element or a compound assignment). Loud sorry —
		 never a silent wrong store. */
	    fprintf(stderr, "%s:%u: sorry: assignment to this dynamic-array "
		    "element part-select form is not yet supported.\n",
		    ivl_stmt_file(net), ivl_stmt_lineno(net));
	    fprintf(vvp_out, "; ERROR: unsupported darray element part-select "
		    "l-value.\n");
	    return errors + 1;
      }

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

      } else if (ivl_expr_type(rval) == IVL_EX_SIGNAL
		 || ivl_expr_type(rval) == IVL_EX_PROPERTY) {
	    assert(ivl_stmt_opcode(net) == 0);

	    // There is no l-value mux, and the r-value expression is
	    // a "signal" (or class-property) expression, i.e. a live
	    // handle to existing storage. Store a duplicate into the
	    // lvalue by using the %dup/obj. Remember to pop the rvalue
	    // that is no longer needed.
	    //
	    // A whole fixed-array struct member passed to an open-array
	    // formal still needs the /open store so the DUPLICATE adopts
	    // the actual's declared-index view (the range metadata rides
	    // along on the duplicate).
	    int fixed_open_actual =
		  ivl_signal_port(var) != IVL_SIP_NONE
		  && vvp_expr_is_whole_fixed_array_property(rval);
	    errors += draw_eval_object(rval);
	    fprintf(vvp_out, "    %%dup/obj;\n");
	    fprintf(vvp_out, "    %%store/obj%s v%p_0; %s:%u: %s = <signal>\n",
		    fixed_open_actual ? "/open" : "",
		    var, ivl_stmt_file(net), ivl_stmt_lineno(net),
		    ivl_signal_basename(var));
	    fprintf(vvp_out, "    %%pop/obj 1, 0;\n");

      } else {
	    assert(ivl_stmt_opcode(net) == 0);
	    // There is no l-value mux, so this must be an
	    // assignment to the array as a whole. Evaluate the
	    // "object", and store the evaluated result.
	    errors += draw_eval_object(rval);
	    int fixed_open_actual =
		  ivl_signal_port(var) != IVL_SIP_NONE
		  && (ivl_expr_type(rval) == IVL_EX_ARRAY
		      || vvp_expr_is_whole_fixed_array_property(rval));
	    fprintf(vvp_out, "    %%store/obj%s v%p_0; %s:%u: %s = <expr type %d>\n",
		    fixed_open_actual ? "/open" : "",
		    var, ivl_stmt_file(net), ivl_stmt_lineno(net),
		    ivl_signal_basename(var), ivl_expr_type(rval));
      }

      return errors;
}

/*
 * This function handles the special case that we assign an array
 * pattern or unpacked-array concatenation to a queue. Evaluate it as a
 * complete queue value before copying it into the destination; collection
 * operands can make the resulting size depend on run-time state.
 */
static int show_stmt_assign_queue_pattern(ivl_signal_t var, ivl_expr_t rval,
                                          ivl_type_t element_type, int max_idx)
{
      int errors = 0;
      assert(ivl_expr_type(rval) == IVL_EX_ARRAY_PATTERN);

      /* Evaluate the complete right-hand concatenation into fresh queue
       * storage before changing the destination. This is required even
       * when every operand is scalar: an operand may read the destination
       * queue, and assignment must not expose partially written elements.
       * The object-context evaluator visits every operand exactly once and
       * appends its result in source order, splicing collection operands into
       * the fresh builder. The final whole-queue copy applies the destination
       * bound once. */
      errors += draw_eval_object_value_copy(rval, ivl_signal_net_type(var));
      switch (ivl_type_base(element_type)) {
          case IVL_VT_BOOL:
          case IVL_VT_LOGIC:
            fprintf(vvp_out, "    %%store/qobj/v v%p_0, %d, %u;\n",
                    var, max_idx, ivl_type_packed_width(element_type));
            break;
          case IVL_VT_REAL:
            fprintf(vvp_out, "    %%store/qobj/r v%p_0, %d;\n",
                    var, max_idx);
            break;
          case IVL_VT_STRING:
            fprintf(vvp_out, "    %%store/qobj/str v%p_0, %d;\n",
                    var, max_idx);
            break;
          default:
            fprintf(vvp_out, "    %%store/qobj/obj v%p_0, %d;\n",
                    var, max_idx);
            break;
      }

      return errors;
}

/* The elaborator represents an associative-array `'{default: value}' whole
 * assignment as an internal system-function node. Keeping the marker typed as
 * the destination container prevents ordinary assignment compatibility from
 * degrading it to a scalar. Direct assignments recognize it here; ordinary
 * object-valued expression contexts recognize the same marker in
 * eval_object_sfunc(). */
static int expr_is_assoc_default_(ivl_expr_t expr)
{
      return expr
	  && ivl_expr_type(expr) == IVL_EX_SFUNC
	  && ivl_expr_name(expr)
	  && strcmp(ivl_expr_name(expr), "$ivl_assoc_default") == 0
	  && ivl_expr_parms(expr) == 1;
}

/* Evaluate the sentinel's sole value in its declared element category, then
 * construct a fresh typed associative-array object carrying that default.
 * The fresh object is left on the object stack for an ordinary signal/property
 * store. This ordering is essential when RHS side effects replace the same
 * array: no destination container is captured until the RHS is complete. */
int draw_eval_assoc_default(ivl_expr_t marker, ivl_type_t element_type)
{
      int errors = 0;
      ivl_expr_t value = ivl_expr_parm(marker, 0);

      switch (ivl_type_base(element_type)) {
	  case IVL_VT_REAL:
	    draw_eval_real(value);
	    fprintf(vvp_out, "    %%aa/new/default/r;\n");
	    break;
	  case IVL_VT_STRING:
	    draw_eval_string(value);
	    fprintf(vvp_out, "    %%aa/new/default/str;\n");
	    break;
	  case IVL_VT_BOOL:
	  case IVL_VT_LOGIC: {
	    unsigned wid = ivl_type_packed_width(element_type);
	    draw_eval_vec4(value);
	    resize_vec4_wid(value, wid);
	    if (ivl_type_base(element_type) == IVL_VT_BOOL
		&& ivl_expr_value(value) != IVL_VT_BOOL)
		  fprintf(vvp_out, "    %%cast2;\n");
	    fprintf(vvp_out, "    %%aa/new/default/v %u;\n", wid);
	    break;
	  }
	  case IVL_VT_CLASS:
	    errors += draw_eval_object(value);
	    fprintf(vvp_out, "    %%aa/new/default/obj;\n");
	    break;
	  default:
	    fprintf(stderr, "%s:%u: internal error: unsupported associative "
		    "default element type %d\n",
		    ivl_expr_file(marker), ivl_expr_lineno(marker),
		    (int)ivl_type_base(element_type));
	    fprintf(vvp_out, "    %%null; ; unsupported associative default type\n");
	    errors += 1;
	    break;
      }

      return errors;
}

/* Store into the existing suffix selected by q[lo:$].  The l-value API bit
 * is essential here: ivl_lval_idx alone also denotes q[lo], whose assignment
 * is an element store with append-at-size behavior.  A suffix-slice store is
 * instead an exact-cardinality, no-resize operation.  The runtime opcode
 * validates the dynamic bound and source size atomically before copying. */
static int show_stmt_assign_sig_queue_slice(ivl_statement_t net,
					     ivl_lval_t lval,
					     ivl_signal_t var,
					     ivl_type_t element_type)
{
      int errors = 0;
      ivl_expr_t lo = ivl_lval_idx(lval);
      ivl_expr_t rval = ivl_stmt_rval(net);

      if (ivl_stmt_opcode(net) != 0) {
	    fprintf(stderr, "%s:%u: sorry: compound assignment to a queue "
		    "suffix slice is not supported.\n",
		    ivl_stmt_file(net), ivl_stmt_lineno(net));
	    return 1;
      }
      if (!lo) {
	    fprintf(stderr, "%s:%u: internal error: queue suffix-slice "
		    "l-value has no lower bound.\n",
		    ivl_stmt_file(net), ivl_stmt_lineno(net));
	    return 1;
      }

      /* Match ordinary blocking container assignment evaluation: form the
	 * complete RHS value first, then evaluate the l-value index exactly once.
	 * Keeping the RHS on the object stack is safe across the scalar bound
	 * evaluation and lets the runtime take a full snapshot before mutation. */
      errors += draw_eval_object(rval);
      int lo_word = allocate_word();
      draw_eval_expr_into_integer(lo, lo_word);

      switch (ivl_type_base(element_type)) {
	  case IVL_VT_BOOL:
	  case IVL_VT_LOGIC:
	    fprintf(vvp_out, "    %%store/qslice/v v%p_0, %d, %u;\n",
		    var, lo_word, ivl_type_packed_width(element_type));
	    break;
	  case IVL_VT_REAL:
	    fprintf(vvp_out, "    %%store/qslice/r v%p_0, %d;\n",
		    var, lo_word);
	    break;
	  case IVL_VT_STRING:
	    fprintf(vvp_out, "    %%store/qslice/str v%p_0, %d;\n",
		    var, lo_word);
	    break;
	  case IVL_VT_CLASS:
	  case IVL_VT_DARRAY:
	  case IVL_VT_QUEUE:
	  case IVL_VT_NO_TYPE:
	  default:
	    fprintf(vvp_out, "    %%store/qslice/obj v%p_0, %d;\n",
		    var, lo_word);
	    break;
      }

      clr_word(lo_word);
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

      if (ivl_lval_is_queue_slice(lval))
	    return show_stmt_assign_sig_queue_slice(net, lval, var,
					       element_type);

	/* Part/bit-select store into an ASSOCIATIVE-array element
	   (am[key][m:l] = v; packed-struct member writes are lowered by
	   elaboration to the member's bit range). The numeric-index queue
	   path below coerces the key to an integer element address, which
	   corrupted the store ("cannot write to an undefined darray").
	   Lower as an assoc RMW instead: load the element keeping the key,
	   merge the value at the bit offset (%setbits/vec4), store back. */
      if (part != 0 && ivl_lval_idx(lval) && ivl_stmt_opcode(net) == 0
	  && ivl_type_queue_assoc_compat(var_type)
	  && (ivl_type_base(element_type) == IVL_VT_BOOL
	      || ivl_type_base(element_type) == IVL_VT_LOGIC)) {
	    ivl_expr_t key = ivl_lval_idx(lval);
	    unsigned lwid = ivl_lval_width(lval);
	    unsigned elem_wid = ivl_type_packed_width(element_type);
	    const char*key_kind;
	    int key_is_object = expr_is_object_assoc_key_(key);
	    int key_is_string = expr_is_string_assoc_key_(key);

	    fprintf(vvp_out, "    %%load/obj v%p_0;\n", var);
	    if (key_is_string) {
		  key_kind = "str";
		  draw_eval_string(key);
	    } else if (key_is_object) {
		  key_kind = "obj";
		  errors += draw_eval_object(key);
	    } else {
		  key_kind = "v";
		  draw_eval_vec4(key);
	    }
	    fprintf(vvp_out, "    %%aa/loadk/v/%s %u;\n", key_kind, elem_wid);

	    int off_word = allocate_word();
	    int off_flag = allocate_flag();
	    draw_eval_expr_into_integer(part, off_word);
	    fprintf(vvp_out, "    %%flag_mov %d, 4;\n", off_flag);
	    draw_eval_vec4(rval);
	    resize_vec4_wid(rval, lwid);
	    fprintf(vvp_out, "    %%flag_mov 4, %d;\n", off_flag);
	    fprintf(vvp_out, "    %%setbits/vec4/x %d, %u;\n",
		    off_word, lwid);
	    clr_word(off_word);
	    clr_flag(off_flag);
	    fprintf(vvp_out, "    %%aa/store/v/%s %u;\n", key_kind, elem_wid);
	    fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
	    return errors;
      }

	/* Part/bit-select store into a queue element that is a packed
	   vector: q[i][off +: wid] = rhs. Same read-modify-write lowering as
	   for dynamic arrays (%store/dar/vec4/off operates on the shared
	   vvp_darray base, which queues subclass). */
      if (part != 0 && ivl_lval_idx(lval) && ivl_stmt_opcode(net) == 0
	  && (ivl_type_base(element_type) == IVL_VT_BOOL
	      || ivl_type_base(element_type) == IVL_VT_LOGIC)) {
	    ivl_expr_t mux = ivl_lval_idx(lval);
	    unsigned lwid = ivl_lval_width(lval);
	    int mux_word = allocate_word();
	    int off_word = allocate_word();
	    int flag = allocate_flag();

	    draw_eval_expr_into_integer(mux, 3);
	    fprintf(vvp_out, "    %%ix/mov %d, 3;\n", mux_word);
	    fprintf(vvp_out, "    %%flag_mov %d, 4;\n", flag);
	    draw_eval_expr_into_integer(part, off_word);
	    draw_eval_vec4(rval);
	    resize_vec4_wid(rval, lwid);
	    fprintf(vvp_out, "    %%flag_mov 4, %d;\n", flag);
	    fprintf(vvp_out, "    %%ix/mov 3, %d;\n", mux_word);
	    fprintf(vvp_out, "    %%store/dar/vec4/off v%p_0, %d, %u;\n",
		    var, off_word, lwid);
	    clr_flag(flag);
	    clr_word(off_word);
	    clr_word(mux_word);
	    return errors;
      }

      if (part != 0) {
	    fprintf(stderr, "%s:%u: sorry: assignment to this queue element "
		    "part-select form is not yet supported.\n",
		    ivl_stmt_file(net), ivl_stmt_lineno(net));
	    fprintf(vvp_out, "; ERROR: unsupported queue element part-select "
		    "l-value.\n");
	    return errors + 1;
      }

      assert(ivl_type_base(var_type) == IVL_VT_QUEUE);

      int idx = allocate_word();
      assert(idx >= 0);
        /* Save the queue maximum index value to an integer register. */
      fprintf(vvp_out, "    %%ix/load %d, %u, 0;\n", idx, ivl_signal_array_count(var));

      if (ivl_type_queue_assoc_compat(var_type)
	  && !ivl_lval_idx(lval)
	  && expr_is_assoc_default_(rval)) {
	    assert(ivl_stmt_opcode(net) == 0);
	    errors += draw_eval_assoc_default(rval, element_type);
	    fprintf(vvp_out, "    %%store/obj v%p_0;\n", var);
	    clr_word(idx);
	    return errors;

      } else if (ivl_expr_type(rval) == IVL_EX_NULL) {
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
	    if (ivl_type_queue_assoc_compat(var_type)) {
		  /* Assoc-compat queues are represented as associative-array
		   * objects at runtime. Copy the whole container object, do not
		   * route through the queue-element %store/qobj/* helpers. */
		  fprintf(vvp_out, "    %%dup/obj;\n");
		  fprintf(vvp_out, "    %%store/obj v%p_0;\n", var);
		  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
	    } else if (ivl_type_base(element_type) == IVL_VT_REAL)
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
		    /* A plain %store/obj here would alias the whole
		       container (and its elements) instead of copying
		       (recovery D11). Copy element-wise like the other
		       element kinds; the runtime element policy keeps
		       class handles shared. */
		  fprintf(vvp_out, "    %%store/qobj/obj v%p_0, %d;\n", var, idx);
	    } else {
		  fprintf(vvp_out, "    %%store/qobj/obj v%p_0, %d;\n", var, idx);
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
              /* `aa[k] = structvar` copies the struct by value; a class
                 handle keeps reference semantics. */
            errors += draw_eval_object_value_copy(rval, element_type);
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
		    /* An object-backed unpacked struct is a VALUE (7.2):
		       storing the r-value's handle would alias the source,
		       so every element written from one struct variable
		       ended up sharing it -- silently. The module-scope
		       store already copies; this one has to as well. */
		  errors += draw_eval_object_value_copy(rval, element_type);
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
	/* Use the property's OWN index (obj.addr[i]), never the base
	   container index inherited from a nest. A whole-darray-property
	   store through an indexed base (da[0].addr = a, or the register
	   model's m_regs_info[rg].addr = addrs) has no property index and
	   must fall through to the whole-object %store/prop/obj path — the
	   nest-index fallback misread it as an element store (%prop/obj load
	   + %set/dar), silently dropping the assignment. */
      ivl_expr_t idx_expr = ivl_lval_idx(lval);
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
              /* Value-copy an unpacked-struct element -- see above. */
            errors += draw_eval_object_value_copy(rval, element_type);
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
	      /* Value-copy an unpacked-struct element (7.2): storing the
		 r-value's handle would alias the source. */
	    errors += draw_eval_object_value_copy(rval, element_type);
	    fprintf(vvp_out, "    %%aa/store/obj/%s;\n", key_kind);
	    fprintf(vvp_out, "    %%pop/obj 2, 0;\n");
	    return errors;
	  default:
	    return -1;
	      }
}

/* type_is_object_like_, container_type_shape_eq_ and the queue-pattern
 * operand classifiers moved to vvp_priv.h (shared with eval_object.c's
 * container-literal builder). */

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

            errors += draw_eval_object_value_copy(rval, element_type);
            fprintf(vvp_out, "    %%aa/store/obj/%s;\n", key_kind);
            fprintf(vvp_out, "    %%pop/obj 2, 0;\n");

      } else if ((ivl_type_base(container_type) == IVL_VT_DARRAY
                  || ivl_type_base(container_type) == IVL_VT_QUEUE)
                 && type_is_object_like_(element_type)) {
            int idx_word = allocate_word();

            draw_eval_expr_into_integer(idx_expr, idx_word);
            errors += draw_eval_object_value_copy(rval, element_type);
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

/* A class/VIF property expression can have a run-time width that differs
   from ivl_expr_width(). In particular, a virtual handle to a parameterized
   interface currently carries the default-specialization netclass while the
   bound member produces the instance's actual width. Property store opcodes
   consume the l-value width, so do not statically elide this assignment-size
   conversion as resize_vec4_wid() normally does. */
static void resize_property_vec4_wid(ivl_expr_t expr, unsigned wid)
{
      fprintf(vvp_out, "    %%pad/%s %u; property assignment width\n",
	      ivl_expr_signed(expr) ? "s" : "u", wid);
}

/* Nonblocking assignment to a vec4 class-object / virtual-interface
   property: `obj.prop <= [#d] value` or a constant packed field thereof
   (IEEE 1800-2017 10.4.2). Evaluates the receiver and the r-value NOW and
   schedules the store in the NBA region via %assign/prop/v[/bits]. Returns
   0 on success and -1 when the l-value form is not supported here. The
   caller must reject that residual; executing it as a blocking assignment
   would be a silent event-region miscompile. */
int show_stmt_assign_nb_cobject(ivl_statement_t net, uint64_t delay)
{
      ivl_lval_t lval = ivl_stmt_lval(net, 0);
      ivl_expr_t rval = ivl_stmt_rval(net);
      ivl_expr_t part_off_ex = ivl_lval_part_off(lval);
      unsigned lwid = ivl_lval_width(lval);
      int prop_idx = ivl_lval_property_idx(lval);
      unsigned bitoff = 0;

      if (ivl_stmt_lvals(net) != 1)
	    return -1;
      if (prop_idx < 0)
	    return -1;
      if (ivl_lval_idx(lval))
	    return -1;
      if (part_off_ex) {
	    if (!number_is_immediate(part_off_ex, 32, 0) ||
	        number_is_unknown(part_off_ex))
		  return -1;
	    bitoff = (unsigned)ivl_expr_uvalue(part_off_ex);
      }
      if (ivl_stmt_opcode(net) != 0)
	    return -1;
      if (delay > 0xffffffffUL)
	    return -1;

      ivl_type_t sig_type = draw_lval_expr(lval);
      ivl_type_t prop_type = ivl_type_prop_type(sig_type, prop_idx);
      if (ivl_type_base(prop_type) != IVL_VT_BOOL &&
	  ivl_type_base(prop_type) != IVL_VT_LOGIC) {
	      /* Receiver already pushed: discard and fall back. */
	    fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
	    return -1;
      }

      draw_eval_vec4(rval);
      resize_property_vec4_wid(rval, lwid);
      if (ivl_type_base(prop_type) == IVL_VT_BOOL &&
	  ivl_expr_value(rval) != IVL_VT_BOOL)
	    fprintf(vvp_out, "    %%cast2;\n");

      if (part_off_ex) {
	    fprintf(vvp_out, "    %%assign/prop/v/bits %d, %lu, %u;"
		    " NBA store to field [%u+:%u] of property %s\n",
		    prop_idx, (unsigned long)delay, bitoff, bitoff, lwid,
		    ivl_type_prop_name(sig_type, prop_idx));
      } else {
	    fprintf(vvp_out, "    %%assign/prop/v %d, %lu, %u;"
		    " NBA store to property %s\n",
		    prop_idx, (unsigned long)delay, lwid,
		    ivl_type_prop_name(sig_type, prop_idx));
      }
      return 0;
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
	    int whole_fixed_array =
		  !ivl_lval_idx(lval) && !ivl_lval_part_off(lval)
		  && ivl_type_element(prop_type)
		  && ivl_type_packed_dimensions(prop_type) > 0
		  && ivl_type_packed_width(prop_type) == 1;

	    /* Dynamic null-handle guard: if the receiver object is null, skip
	       property assignment and pop the receiver object without issuing
	       %store/prop* opcodes. */
	    fprintf(vvp_out, "    %%test_nul/obj;\n");
	    fprintf(vvp_out, "    %%jmp/1 T_%u.%u, 4;\n", thread_count, lab_null);

	    if (whole_fixed_array
		&& (ivl_expr_value(rval) == IVL_VT_DARRAY
		    || ivl_expr_value(rval) == IVL_VT_QUEUE)) {
		  errors += draw_eval_object(rval);
		  fprintf(vvp_out, "    %%store/prop/arr/dar %d;\n", prop_idx);
		  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");

	    } else if (ivl_type_base(prop_type) == IVL_VT_BOOL ||
	        ivl_type_base(prop_type) == IVL_VT_LOGIC) {
		  int prop_word_idx = 0;
		  ivl_expr_t idx_expr = ivl_lval_idx(lval);
		  ivl_expr_t part_off_ex = ivl_lval_part_off(lval);
		  uint64_t negative_part_off_bits = 0;
		  int negative_part_off_fits = part_off_ex
			&& packed_property_negative_offset_bits64_(
			      part_off_ex, &negative_part_off_bits);

		  /* Whole-array assignment pattern into a logic-array
		     property (`obj.arr = '{...}` where arr is an unpacked
		     array of packed values).  draw_eval_vec4 cannot evaluate
		     an array pattern (it is not a single vector) and used to
		     fall through to a zero fallback, silently clobbering the
		     array.  Store each element to its own word instead. */
		  if (!idx_expr && !part_off_ex &&
		      ivl_expr_type(rval) == IVL_EX_ARRAY_PATTERN) {
			int wreg = allocate_word();
			draw_prop_array_pattern(prop_idx,
						ivl_type_prop_name(sig_type, prop_idx),
						rval, wreg, 0);
			clr_word(wreg);
			fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
			/* Emit the null-guard epilogue inline and return. */
			fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_out);
			fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_null);
			fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
			fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_out);
			return errors;
		  }

		    /* A defined constant outside the run-time signed offset range
		       is wholly out of bounds. The same is true of a nonnegative
		       constant outside the compact unsigned literal range. Evaluate
		       the RHS (and therefore any function side effects), discard its
		       converted value, and leave the property unchanged. */
		  if (part_off_ex && !idx_expr
		      && (ivl_expr_type(part_off_ex) == IVL_EX_NUMBER
			  || ivl_expr_type(part_off_ex) == IVL_EX_ULONG)
		      && !packed_property_offset_is_unknown_(part_off_ex)
		      && ((packed_property_offset_is_negative_(part_off_ex)
			   && !negative_part_off_fits)
			  || (!packed_property_offset_is_negative_(part_off_ex)
			      && !packed_property_offset_is_immediate_(
				    part_off_ex)))) {
			draw_eval_vec4(rval);
			resize_property_vec4_wid(rval, lwid);
			fprintf(vvp_out, "    %%pop/vec4 1; Discard RHS for "
				"out-of-range property offset\n");
			fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
			fprintf(vvp_out, "    %%jmp T_%u.%u;\n",
				thread_count, lab_out);
			fprintf(vvp_out, "T_%u.%u;\n",
				thread_count, lab_null);
			fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
			fprintf(vvp_out, "T_%u.%u;\n",
				thread_count, lab_out);
			return errors;
		  }

		  /* Packed struct field write via bit-offset RMW.  This is
		     generated when a VIF packed-struct property field is
		     used as an l-value (e.g. cfg.vif.h2d_int.a_valid <= 1).
		     The part_off_ex holds the field's bit offset within the
		     property and lwid is the field width. */
		  if (part_off_ex && !idx_expr &&
		      packed_property_offset_is_immediate_(part_off_ex)) {
			unsigned bitoff = (unsigned)ivl_expr_uvalue(part_off_ex);
			/* Compound assignment (`fld |= x`) needs the current
			   field value on the stack before the r-value so the
			   binary opcode has both operands. Load the whole
			   property and part-select [bitoff+:lwid]. */
			if (ivl_stmt_opcode(net) != 0) {
			      fprintf(vvp_out, "    %%prop/v %d;\n", prop_idx);
			      fprintf(vvp_out, "    %%parti/u %u, %u, 32;\n",
				      lwid, bitoff);
			}
			draw_eval_vec4(rval);
			/* %store/prop/v/bits pops lwid bits. Force the run-time
			   value to that width even when the static expression width
			   happens to match (a specialized VIF can still differ). */
			resize_property_vec4_wid(rval, lwid);
			draw_stmt_assign_vector_opcode(ivl_stmt_opcode(net),
						       ivl_expr_signed(rval));
			fprintf(vvp_out,
				"    %%store/prop/v/bits %d, %u, %u;"
				" Store field [%u+:%u] of property %s\n",
				prop_idx, bitoff, lwid, bitoff, lwid,
				ivl_type_prop_name(sig_type, prop_idx));
			fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
			/* Emit the null-guard epilogue inline and return. */
			fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_out);
			fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_null);
			fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
			fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_out);
			return errors;
		  }

		  /* Variable bit-offset RMW: a bit-select or indexed part-
		     select of a vector property with a run-time offset (e.g.
		     `obj.m_bits[i +: 4] = ...`).  The canonical bit offset is
		     evaluated into an index register and consumed by the
		     signed %store/prop/v/bits/x or unsigned
		     %store/prop/v/bits/ux handler, which read-modify-writes the
		     property so bits outside [off+:wid] are preserved. */
		  if (part_off_ex && !idx_expr) {
			int off_reg = allocate_word();
			int off_flag = allocate_flag();
			int signed_offset = ivl_expr_signed(part_off_ex);
			const char*store_opcode = signed_offset
			      ? "%store/prop/v/bits/x"
			      : "%store/prop/v/bits/ux";
			if (ivl_stmt_opcode(net) != 0) {
			      /* Compound assignment: load the current field
				 value first. Evaluate the offset once as a
				 vec4, keep a copy in off_reg (for the store),
				 and part-select [off+:lwid] off the loaded
				 property so the binary opcode has both
				 operands. */
			      fprintf(vvp_out, "    %%prop/v %d;\n", prop_idx);
			      draw_eval_vec4(part_off_ex);
			      fprintf(vvp_out, "    %%dup/vec4;\n");
			      fprintf(vvp_out, "    %%ix/vec4%s %d;\n",
				      signed_offset ? "/s" : "", off_reg);
			      fprintf(vvp_out, "    %%flag_mov %d, 4;\n",
				      off_flag);
			      fprintf(vvp_out, "    %%part/%c %u;\n",
				      signed_offset ? 's' : 'u', lwid);
			} else {
			      if (negative_part_off_fits)
				    emit_packed_property_negative_offset_(
					  off_reg, negative_part_off_bits);
			      else
				    draw_eval_expr_into_integer(part_off_ex,
							 off_reg);
			      fprintf(vvp_out, "    %%flag_mov %d, 4;\n",
				      off_flag);
			}
			draw_eval_vec4(rval);
			resize_property_vec4_wid(rval, lwid);
			draw_stmt_assign_vector_opcode(ivl_stmt_opcode(net),
						       ivl_expr_signed(rval));
			  /* R-value evaluation and a compound opcode may change flag
			     4. Restore the offset-validity flag immediately before
			     the run-time partial store consumes it. */
			fprintf(vvp_out, "    %%flag_mov 4, %d;\n", off_flag);
			fprintf(vvp_out,
				"    %s %d, %d, %u;"
				" Store field [<var>+:%u] of property %s\n",
				store_opcode, prop_idx, off_reg, lwid, lwid,
				ivl_type_prop_name(sig_type, prop_idx));
			clr_word(off_reg);
			clr_flag(off_flag);
			fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
			/* Emit the null-guard epilogue inline and return. */
			fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_out);
			fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_null);
			fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
			fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_out);
			return errors;
		  }

		  /* Element index PLUS a bit/part-select on the element
		     (c.arr[i][m:l] = v): read-modify-write the ELEMENT via
		     %prop/v/i, merge with %setbits, store back. */
		  if (idx_expr && part_off_ex && ivl_stmt_opcode(net) == 0) {
			ivl_type_t elem_t = ivl_type_element(prop_type);
			unsigned elem_wid = elem_t
			      ? ivl_type_packed_width(elem_t)
			      : ivl_type_packed_width(prop_type);
			prop_word_idx = allocate_word();
			draw_eval_expr_into_integer(idx_expr, prop_word_idx);
			fprintf(vvp_out, "    %%prop/v/i %d, %d;\n",
				prop_idx, prop_word_idx);
			int off_word = allocate_word();
			int off_flag = allocate_flag();
			draw_eval_expr_into_integer(part_off_ex, off_word);
			fprintf(vvp_out, "    %%flag_mov %d, 4;\n", off_flag);
			draw_eval_vec4(rval);
			resize_property_vec4_wid(rval, lwid);
			fprintf(vvp_out, "    %%flag_mov 4, %d;\n", off_flag);
			fprintf(vvp_out, "    %%setbits/vec4/x %d, %u;\n",
				off_word, lwid);
			clr_word(off_word);
			clr_flag(off_flag);
			fprintf(vvp_out, "    %%store/prop/v/i %d, %d, %u;"
				" RMW element part of property %s\n",
				prop_idx, prop_word_idx, elem_wid,
				ivl_type_prop_name(sig_type, prop_idx));
			fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
			fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_out);
			fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_null);
			fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
			fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_out);
			clr_word(prop_word_idx);
			return errors;
		  }

		  if (idx_expr) {
			prop_word_idx = allocate_word();
			draw_eval_expr_into_integer(idx_expr, prop_word_idx);
		  }

		  if (ivl_stmt_opcode(net) != 0) {
			if (prop_word_idx)
			      fprintf(vvp_out, "    %%prop/v/i %d, %d;\n", prop_idx, prop_word_idx);
			else
			      fprintf(vvp_out, "    %%prop/v %d;\n", prop_idx);
			fprintf(vvp_out, "    %%pad/%s %u; property l-value width\n",
				ivl_type_signed(prop_type) ? "s" : "u", lwid);
		  }

		  draw_eval_vec4(rval);
		  resize_property_vec4_wid(rval, lwid);
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
		  ivl_expr_t idx_expr = ivl_lval_idx(lval);

		    /* Whole-array pattern into a real-array property. */
		  if (!idx_expr &&
		      ivl_expr_type(rval) == IVL_EX_ARRAY_PATTERN) {
			int wreg = allocate_word();
			draw_prop_real_array_pattern(prop_idx,
						     ivl_type_prop_name(sig_type, prop_idx),
						     rval, wreg, 0);
			clr_word(wreg);
			fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
			fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_out);
			fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_null);
			fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
			fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_out);
			return errors;
		  }

		  if (idx_expr) {
			  /* Element of a real-array property (`obj.arr[i]`). */
			int wreg = allocate_word();
			draw_eval_expr_into_integer(idx_expr, wreg);
			if (ivl_stmt_opcode(net) != 0)
			      fprintf(vvp_out, "    %%prop/r/i %d, %d;\n", prop_idx, wreg);
			draw_eval_real(rval);
			draw_stmt_assign_real_opcode(ivl_stmt_opcode(net));
			fprintf(vvp_out, "    %%store/prop/r/i %d, %d;"
				" Store in real property %s\n",
				prop_idx, wreg, ivl_type_prop_name(sig_type, prop_idx));
			clr_word(wreg);
			fprintf(vvp_out, "    %%pop/obj 1, 0;\n");

		  } else {
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
		  }

	    } else if (ivl_type_base(prop_type) == IVL_VT_STRING) {
		  ivl_expr_t idx_expr = ivl_lval_idx(lval);

		    /* Whole-array pattern into a string-array property. */
		  if (!idx_expr &&
		      ivl_expr_type(rval) == IVL_EX_ARRAY_PATTERN) {
			int wreg = allocate_word();
			draw_prop_str_array_pattern(prop_idx,
						    ivl_type_prop_name(sig_type, prop_idx),
						    rval, wreg, 0);
			clr_word(wreg);
			fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
			fprintf(vvp_out, "    %%jmp T_%u.%u;\n", thread_count, lab_out);
			fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_null);
			fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
			fprintf(vvp_out, "T_%u.%u;\n", thread_count, lab_out);
			return errors;
		  }

		  if (idx_expr) {
			  /* Element of a string-array property. */
			int wreg = allocate_word();
			draw_eval_expr_into_integer(idx_expr, wreg);
			draw_eval_string(rval);
			fprintf(vvp_out, "    %%store/prop/str/i %d, %d;"
				" Store in string property %s\n",
				prop_idx, wreg, ivl_type_prop_name(sig_type, prop_idx));
			clr_word(wreg);
			fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
		  } else {
			  /* Calculate the string value into the string value
			     stack. The %store/prop/str will pop the stack
			     value. */
			draw_eval_string(rval);
			fprintf(vvp_out, "    %%store/prop/str %d;\n", prop_idx);
			fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
		  }

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
			errors += draw_eval_object_value_copy(rval, prop_type);
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
			  if (ivl_type_queue_assoc_compat(prop_type)
			      && !ivl_lval_idx(lval)
			      && expr_is_assoc_default_(rval)) {
				ivl_type_t elem_type = ivl_type_element(prop_type);
				errors += draw_eval_assoc_default(rval, elem_type);
				fprintf(vvp_out, "    %%store/prop/obj %d, 0;\n",
					prop_idx);
				fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
			  } else {
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
				ivl_scope_t rv_def = ivl_expr_type(rval) == IVL_EX_UFUNC
			      ? ivl_expr_def(rval) : 0;
			ivl_signal_t rv_ret = rv_def ? ivl_scope_port(rv_def, 0) : 0;
			if (rv_ret && ivl_signal_dimensions(rv_ret) > 0) {
			      /* NetEUFunc now carries the fixed aggregate type, so a
			       * fixed-array return is a legal queue RHS. Its IVL value
			       * category is still the element's scalar category; routing
			       * on ivl_expr_value() below would evaluate an array-returning
			       * function as vec4/real/string even though %callf/void leaves
			       * no such stack value. Materialize directly as a queue and
			       * store that queue object in the property. */
			      uint64_t queue_max_size =
				    ivl_type_queue_max_size(prop_type);
				/* VVP instruction operands are 32 bits. A larger bound
				 * cannot truncate a fixed source whose exported count is
				 * itself unsigned, so zero (unbounded) is equivalent here. */
			      unsigned marshal_max = queue_max_size > 0xffffffffULL
				    ? 0 : (unsigned)queue_max_size;
			      draw_ufunc_uarray_object(rval, 1, marshal_max);
			      fprintf(vvp_out, "    %%store/prop/obj %d, 0;"
				      " fixed-array function return to queue\n",
				      prop_idx);
			      fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
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
			  }
			  }

		    } else if (ivl_type_base(prop_type) == IVL_VT_NO_TYPE) {
		  ivl_variable_type_t rv_type = ivl_expr_value(rval);
		  ivl_type_t rval_type = ivl_expr_net_type(rval);
		  ivl_type_t nt_elem_type = ivl_type_element(prop_type);
		  int lval_is_value_struct =
			(ivl_type_properties(prop_type) > 0)
			|| (nt_elem_type
			    && ivl_type_properties(nt_elem_type) > 0);
		  int rval_is_value_struct =
			lval_is_value_struct
			&& rv_type != IVL_VT_CLASS
			&& rv_type != IVL_VT_DARRAY
			&& rv_type != IVL_VT_QUEUE
			&& ivl_expr_type(rval) != IVL_EX_NULL
			&& (rval_type == 0
			    || ivl_type_base(rval_type) == IVL_VT_NO_TYPE);
		  ivl_expr_t no_type_idx_expr = ivl_lval_idx(lval);

		    /* An unpacked struct stored into a slot of a FIXED-SIZE
		       unpacked array property. The branch below ignores the
		       l-value index entirely and, because a struct r-value
		       is not one of the object-like value kinds it tests
		       for, took the "coerce to null" path -- so the element
		       was silently left empty and every slot read back
		       zero. Store the struct as an object, value-copied
		       (7.2), into the slot the index names. */
		  if (rval_is_value_struct) {
			int nt_idx = 0;
			ivl_type_t nt_elem = nt_elem_type;
			if (no_type_idx_expr)
			      nt_idx = allocate_word();
			errors += draw_eval_object_value_copy(rval,
				      nt_elem ? nt_elem : prop_type);
			if (no_type_idx_expr)
			      draw_eval_expr_into_integer(no_type_idx_expr,
							  nt_idx);
			fprintf(vvp_out, "    %%store/prop/obj %d, %d;"
				" ; value struct\n", prop_idx, nt_idx);
			fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
			if (no_type_idx_expr) clr_word(nt_idx);
		  } else if (rv_type == IVL_VT_CLASS ||
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

		    if (ivl_expr_type(rval) == IVL_EX_ARRAY_PATTERN
			&& ivl_lval_idx(lval) == 0) {
			    /* Whole-array pattern assign (no element index):
			       draw_array_pattern distributes the pattern's
			       entries across the array's elements. */
			  draw_array_pattern(sig, rval, 0);
		  return 0;
	    }

	      /* A per-element assignment of an aggregate literal
		 (`arr[i] = '{...}`) has a word index on the l-value; the
		 pattern is a STRUCT literal for that one element, not a list
		 of array elements. Fall through to build the whole aggregate
		 object from the pattern (draw_eval_object handles the
		 IVL_EX_ARRAY_PATTERN aggregate the same way the scalar
		 `s = '{...}` case does) and store it into the indexed element
		 with %store/obja below. Feeding it to draw_array_pattern here
		 would mis-read the struct fields as successive array elements
		 and null them out. */

	      /* There is no property select, so evaluate the r-value as an
		 object and assign the entire object to the variable.

		 An object-backed unpacked struct has VALUE semantics: `y = x`
		 (or `arr[i] = x`) must copy x's contents into a fresh object,
		 not alias x's object — otherwise a later `y.field = ...` would
		 also mutate x. draw_eval_object_value_copy clones a value-struct
		 read; a class handle (reference) and a freshly built aggregate
		 pass through unchanged. (IEEE 1800-2017 7.2.) */
	    errors += draw_eval_object_value_copy(rval, ivl_signal_net_type(sig));

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

/* The element descriptor %store/arr/dar wants, in the same packed
   encoding %load/arr/dar uses (see of_LOAD_ARR_DAR). Returns 0 and
   reports if the element kind cannot be carried. */
int uarray_container_kind_(ivl_signal_t sig, unsigned*kind_out,
			   const char*file, unsigned lineno)
{
      ivl_variable_type_t dt = ivl_signal_data_type(sig);
      unsigned wid = ivl_signal_width(sig);
      unsigned kind;

      switch (dt) {
	  case IVL_VT_REAL:
	    kind = 0;                           /* ARRDAR_REAL */
	    break;
	  case IVL_VT_STRING:
	    kind = (1u << 12);                  /* ARRDAR_STRING */
	    break;
	  case IVL_VT_BOOL:
	  case IVL_VT_LOGIC:
	    if (wid == 0) wid = 1;
	    kind = (wid & 0xFFu)
		 | (ivl_signal_signed(sig) ? (1u << 8) : 0u)
		 | ((dt == IVL_VT_LOGIC) ? (1u << 9) : 0u);
	    break;
	  case IVL_VT_CLASS:
	    kind = (1u << 11);
	    break;
	  default:
	    fprintf(stderr, "%s:%u: sorry: the whole unpacked array `%s' "
		    "cannot receive a dynamic array or queue: only arrays "
		    "of integral, real, string or class-handle elements have a "
		    "matching element representation.\n",
		    file ? file : "<unknown>", lineno,
		    ivl_signal_basename(sig));
	    vvp_errors += 1;
	    return 0;
      }

      *kind_out = kind;
      return 1;
}

/* Marshal a fixed unpacked-array signal to the runtime container stack.
   This is the expression-free twin of eval_object_array(), used where a
   synthesized subroutine body has the formal signal but no IVL_EX_ARRAY
   node (notably fixed unpacked-array DPI imports). */
void emit_load_arr_dar_(ivl_signal_t sig, unsigned kind)
{
      int left = ivl_signal_array_dim_msb(sig, 0);
      int right = ivl_signal_array_dim_lsb(sig, 0);

      if (left > right)
	    kind |= (1u << 10);

      note_array_signal_use(sig);
      if (ivl_signal_dimensions(sig) > 1) {
	    unsigned dim;
	    for (dim = 0 ; dim < ivl_signal_dimensions(sig) ; dim += 1)
		  fprintf(vvp_out, "    %%dim/push %u, %u;\n",
			  (unsigned)ivl_signal_array_dim_msb(sig, dim),
			  (unsigned)ivl_signal_array_dim_lsb(sig, dim));
	    fprintf(vvp_out, "    %%load/arr/dar/md v%p, %u;\n", sig, kind);
	    return;
      }

      fprintf(vvp_out, "    %%load/arr/dar v%p, %u, %u;\n",
	      sig, kind, (unsigned)left);
}

/* Emit the container -> fixed-array store for one signal. A
   multi-dimensional destination is stored as one flat word array, so
   the declared shape has to be handed over separately before the
   nesting form of the instruction can walk the container back. */
void emit_store_arr_dar_(ivl_signal_t sig, unsigned kind)
{
      if (ivl_signal_dimensions(sig) > 1) {
	    unsigned dim;
	    for (dim = 0 ; dim < ivl_signal_dimensions(sig) ; dim += 1)
		  fprintf(vvp_out, "    %%dim/push %u, %u;\n",
			  (unsigned)ivl_signal_array_dim_msb(sig, dim),
			  (unsigned)ivl_signal_array_dim_lsb(sig, dim));
	    fprintf(vvp_out, "    %%store/arr/dar/md v%p, %u;\n", sig, kind);
	    return;
      }

      fprintf(vvp_out, "    %%store/arr/dar v%p, %u;\n", sig, kind);
}

/* `fa = da' and its siblings: a WHOLE fixed-size unpacked array l-value
   receiving a dynamic-array or queue r-value (IEEE 1800-2017 7.6).
   %load/arr/dar has marshaled the other direction since M10-1; this is
   the return trip, and it is the single instruction every legal
   container -> fixed-array copy goes through -- the plain assignment
   here, a struct member's assignment, and the copy-back of an
   `inout'/`ref'/`output' open-array formal into a fixed-array actual
   (13.5.2), which elaboration lowers to exactly this assignment. */
static int show_stmt_assign_uarray_from_container(ivl_statement_t net,
						  ivl_signal_t sig)
{
      ivl_expr_t rval = ivl_stmt_rval(net);
      unsigned kind;

      if (!uarray_container_kind_(sig, &kind, ivl_stmt_file(net),
				  ivl_stmt_lineno(net)))
	    return 1;

      draw_eval_object(rval);
      note_array_signal_use(sig);
      emit_store_arr_dar_(sig, kind);
      return 0;
}

/* True when an r-value expression is a WHOLE container value.

   ivl_expr_value() is not the test: a signal expression naming a
   dynamic array reports its ELEMENT type (IVL_VT_LOGIC for `int da[]'),
   because that is what a read of it usually yields. The container-ness
   is on the signal, so ask the signal -- and only when the expression
   carries no word index, which would make it an element read after
   all. */
static int rval_is_whole_container_(ivl_expr_t rv)
{
      ivl_type_t nt;

      if (!rv)
	    return 0;

      if (ivl_expr_type(rv) == IVL_EX_SIGNAL && !ivl_expr_oper1(rv)) {
	    ivl_signal_t rsig = ivl_expr_signal(rv);
	    ivl_variable_type_t dt = rsig ? ivl_signal_data_type(rsig)
					  : IVL_VT_NO_TYPE;
	    if (rsig && ivl_signal_dimensions(rsig) == 0
		&& (dt == IVL_VT_DARRAY || dt == IVL_VT_QUEUE))
		  return 1;
      }

      nt = ivl_expr_net_type(rv);
      if (nt && (ivl_type_base(nt) == IVL_VT_DARRAY
		 || ivl_type_base(nt) == IVL_VT_QUEUE))
	    return 1;

      return 0;
}

/* True for an l-value that names a whole unpacked array -- no word
   index, no part select, not nested inside a class object. */
static int lval_is_whole_uarray_(ivl_lval_t lval, ivl_signal_t sig)
{
      if (!sig || ivl_signal_dimensions(sig) == 0)
	    return 0;
      if (ivl_lval_nest(lval))
	    return 0;
      if (ivl_lval_idx(lval))
	    return 0;
      if (ivl_lval_part_off(lval))
	    return 0;
      return 1;
}

static int stream_lval_is_dynamic_(ivl_lval_t lval)
{
      ivl_type_t type = ivl_lval_net_type(lval);
      if (!type)
	    return 0;

      switch (ivl_type_base(type)) {
	  case IVL_VT_DARRAY:
	  case IVL_VT_QUEUE:
	  case IVL_VT_STRING:
	    return 1;
	  default:
	    return 0;
      }
}

static const char* stream_range_name_(ivl_stream_range_t kind)
{
      switch (kind) {
	  case IVL_STREAM_RANGE_INDEX: return "index";
	  case IVL_STREAM_RANGE_RANGE: return "range";
	  case IVL_STREAM_RANGE_UP:    return "up";
	  case IVL_STREAM_RANGE_DOWN:  return "down";
	  default: return "none";
      }
}

static int eval_stream_range_(ivl_lval_t lval, int*first_reg,
			      int*second_reg)
{
      ivl_expr_t first = ivl_lval_stream_range_first(lval);
      ivl_expr_t second = ivl_lval_stream_range_second(lval);
      if (!first)
	    return 0;

      *first_reg = allocate_word();
      *second_reg = allocate_word();
      draw_eval_expr_into_integer(first, *first_reg);
      fprintf(vvp_out, "    %%stream/range/mark %d, 4;\n", *first_reg);
      if (second)
	    draw_eval_expr_into_integer(second, *second_reg);
      else
	    fprintf(vvp_out, "    %%ix/load %d, 0, 0;\n", *second_reg);
      if (second)
	    fprintf(vvp_out, "    %%stream/range/mark %d, 4;\n", *second_reg);
      return 1;
}

static int validate_dynamic_stream_lval_(ivl_statement_t net,
					  ivl_lval_t lval)
{
      ivl_type_t type = ivl_lval_net_type(lval);
      ivl_signal_t sig = ivl_lval_sig(lval);
      ivl_variable_type_t base = ivl_type_base(type);

      int prop_idx = ivl_lval_property_idx(lval);
      if ((!sig && !ivl_lval_nest(lval))
	  || (prop_idx < 0 && ivl_lval_nest(lval))
	  || ivl_lval_idx(lval) || ivl_lval_part_off(lval)) {
	    fprintf(stderr, "%s:%u: sorry: this selected or nested dynamically "
		    "sized streaming target is not yet supported (IEEE "
		    "1800-2017 11.4.14.4).\n",
		    ivl_stmt_file(net), ivl_stmt_lineno(net));
	    return 1;
      }

      if (base == IVL_VT_QUEUE && ivl_type_queue_assoc_compat(type)) {
	    fprintf(stderr, "%s:%u: error: an associative array is not a "
		    "legal dynamically sized streaming target (IEEE 1800-2017 "
		    "11.4.14.4).\n", ivl_stmt_file(net),
		    ivl_stmt_lineno(net));
	    return 1;
      }

      ivl_type_t elem = (base == IVL_VT_STRING) ? 0
	    : ivl_type_element(type);
      if (base != IVL_VT_STRING
	  && (!elem || (ivl_type_base(elem) != IVL_VT_BOOL
			 && ivl_type_base(elem) != IVL_VT_LOGIC))) {
	    fprintf(stderr, "%s:%u: error: streaming into a dynamic array or "
		    "queue requires an integral bit-stream element type (IEEE "
		    "1800-2017 11.4.14.1).\n",
		    ivl_stmt_file(net), ivl_stmt_lineno(net));
	    return 1;
      }

      return 0;
}

/* Store one run-time-sized member of an IEEE 1800-2017 11.4.14.4
 * streaming target. The member's complete bit stream is on the vec4 stack.
 * The caller has already rejected selections and nested/property targets, so
 * this helper performs one typed whole-variable store. */
static int store_dynamic_stream_lval_(ivl_lval_t lval)
{
      ivl_type_t type = ivl_lval_net_type(lval);
      ivl_signal_t sig = ivl_lval_sig(lval);
      ivl_variable_type_t base = ivl_type_base(type);
      int prop_idx = ivl_lval_property_idx(lval);
      int is_property = prop_idx >= 0;

      if (is_property) {
	    ivl_type_t receiver_type = draw_lval_expr(lval);
	    if (!receiver_type || prop_idx >= ivl_type_properties(receiver_type)) {
		  fprintf(stderr, "sorry: cannot resolve dynamically sized "
			  "streaming target property %d.\n", prop_idx);
		  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
		  return 1;
	    }
      } else {
	    assert(sig);
      }

      if (base == IVL_VT_STRING) {
	    fprintf(vvp_out, "    %%pushv/str;\n");
	    if (is_property) {
		  fprintf(vvp_out, "    %%store/prop/str %d;\n", prop_idx);
		  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
	    } else {
		  fprintf(vvp_out, "    %%store/str v%p_0;\n", sig);
	    }
	    return 0;
      }

      ivl_type_t elem = ivl_type_element(type);
      assert(elem);

      char elem_text[32];
      stream_elem_type_text(elem, elem_text, sizeof elem_text);
      if (base == IVL_VT_DARRAY) {
	    fprintf(vvp_out, "    %%stream/to/dar \"%s\";\n", elem_text);
	    if (is_property) {
		  fprintf(vvp_out, "    %%store/prop/obj %d, 0;\n", prop_idx);
		  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
	    } else {
		  fprintf(vvp_out, "    %%store/obj v%p_0;\n", sig);
	    }
	    return 0;
      }

      assert(base == IVL_VT_QUEUE);
      uint64_t max_size = ivl_type_queue_max_size(type);
      unsigned max_count = max_size > UINT_MAX ? 0 : (unsigned)max_size;
      int max_idx = allocate_word();
      fprintf(vvp_out, "    %%stream/to/queue \"%s:%u\";\n",
	      elem_text, max_count);
      if (is_property) {
	    fprintf(vvp_out, "    %%store/prop/obj %d, 0;\n", prop_idx);
	    fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
      } else {
	    fprintf(vvp_out, "    %%ix/load %d, %u, 0;\n", max_idx,
	      ivl_signal_array_count(sig));
	    fprintf(vvp_out, "    %%store/qobj/v v%p_0, %d, %u;\n",
	      sig, max_idx, ivl_type_packed_width(elem));
      }
      clr_word(max_idx);
      return 0;
}

/* Store one explicitly ranged dynamic member.  The range expressions are
 * already in the two word registers and the selected field is on the vec4
 * stack.  Load the old container so elements outside the range survive, and
 * let the bounded runtime operation resize only as far as required. */
static int store_dynamic_stream_lval_with_(ivl_lval_t lval,
					    int first_reg, int second_reg,
					    int receiver_loaded)
{
      ivl_type_t type = ivl_lval_net_type(lval);
      ivl_signal_t sig = ivl_lval_sig(lval);
      ivl_variable_type_t base = ivl_type_base(type);
      ivl_type_t elem = ivl_type_element(type);
      int prop_idx = ivl_lval_property_idx(lval);
      assert(elem);

      char elem_text[32];
      stream_elem_type_text(elem, elem_text, sizeof elem_text);
      const char*kind = stream_range_name_(ivl_lval_stream_range(lval));

      if (prop_idx >= 0) {
	    if (!receiver_loaded) {
		  ivl_type_t receiver_type = draw_lval_expr(lval);
		  if (!receiver_type
		      || prop_idx >= ivl_type_properties(receiver_type)) {
			fprintf(stderr, "sorry: cannot resolve nested streaming `with' "
				"container property %d.\n", prop_idx);
			return 1;
		  }
	    }
	    fprintf(vvp_out,
		    "    %%prop/obj %d, 0; load ranged stream property\n",
		    prop_idx);
      } else {
	    assert(sig);
	    fprintf(vvp_out, "    %%load/obj v%p_0;\n", sig);
      }
      if (base == IVL_VT_DARRAY) {
	    fprintf(vvp_out, "    %%stream/to/dar/with \"%s:%s\", %d, %d;\n",
		    kind, elem_text, first_reg, second_reg);
	    if (prop_idx >= 0) {
		  fprintf(vvp_out,
			  "    %%store/prop/obj %d, 0; ranged stream property\n",
			  prop_idx);
		  fprintf(vvp_out, "    %%pop/obj 1, 0; drop property receiver\n");
	    } else {
		  fprintf(vvp_out, "    %%store/obj v%p_0;\n", sig);
	    }
	    return 0;
      }

      assert(base == IVL_VT_QUEUE);
      uint64_t max_size = ivl_type_queue_max_size(type);
      unsigned max_count = max_size > UINT_MAX ? 0 : (unsigned)max_size;
      fprintf(vvp_out,
	      "    %%stream/to/queue/with \"%s:%s:%u\", %d, %d;\n",
	      kind, elem_text, max_count, first_reg, second_reg);
      if (prop_idx >= 0) {
	    fprintf(vvp_out,
		    "    %%store/prop/obj %d, 0; ranged queue property\n",
		    prop_idx);
	    fprintf(vvp_out, "    %%pop/obj 1, 0; drop property receiver\n");
      } else {
	    int max_idx = allocate_word();
	    fprintf(vvp_out, "    %%ix/load %d, %u, 0;\n", max_idx, max_count);
	    fprintf(vvp_out, "    %%store/qobj/v v%p_0, %d, %u;\n",
		    sig, max_idx, ivl_type_packed_width(elem));
	    clr_word(max_idx);
      }
      return 0;
}

/* Return -1 when NET is not the dynamically-sized streaming-target form.
 * Otherwise lower the complete assignment and return its target error count.
 *
 * L-values are exported least-significant/source-rightmost first. Every fixed
 * member retains its declared width. The source-leftmost dynamically sized
 * member (the greatest dynamic l-value index) receives the run-time remainder
 * after all fixed widths are reserved; every later dynamic member receives an
 * empty value. This is the greedy rule in IEEE 1800-2017 11.4.14.4. */
static int show_stmt_assign_dynamic_stream_(ivl_statement_t net)
{
      ivl_expr_t rval = ivl_stmt_rval(net);
      if (ivl_stmt_opcode(net) != 0 || !rval
	  || ivl_expr_type(rval) != IVL_EX_SFUNC)
	    return -1;

      const char*name = ivl_expr_name(rval);
      if (!name || strncmp(name, "$ivl_stream$unpack$", 19) != 0)
	    return -1;

      unsigned lvals = ivl_stmt_lvals(net);
      unsigned greedy = 0;
      unsigned dynamic_count = 0;
      uint64_t fixed_width = 0;
      int have_range = 0;

      for (unsigned idx = 0 ; idx < lvals ; idx += 1) {
	    ivl_lval_t lval = ivl_stmt_lval(net, idx);
	    if (ivl_lval_stream_range(lval) != IVL_STREAM_RANGE_NONE)
		  have_range = 1;
	    if (stream_lval_is_dynamic_(lval)) {
		  greedy = idx;
		  dynamic_count += 1;
		  continue;
	    }

	    if (ivl_lval_stream_range(lval) != IVL_STREAM_RANGE_NONE) {
		  ivl_type_t fixed_type = ivl_lval_net_type(lval);
		  ivl_type_t elem = fixed_type ? ivl_type_element(fixed_type) : 0;
		  int prop_idx = ivl_lval_property_idx(lval);
		  int direct = ivl_lval_sig(lval) && !ivl_lval_nest(lval)
			&& prop_idx < 0
			&& ivl_signal_dimensions(ivl_lval_sig(lval)) == 1;
		  int property = prop_idx >= 0;
		  if ((!direct && !property)
		      || !elem || (ivl_type_base(elem) != IVL_VT_BOOL
				    && ivl_type_base(elem) != IVL_VT_LOGIC)) {
			fprintf(stderr, "%s:%u: sorry: this selected or nonintegral "
				"fixed-array streaming `with' target is not yet "
				"supported.\n", ivl_stmt_file(net),
				ivl_stmt_lineno(net));
			return 1;
		  }
		  continue;
	    }

	    if (!ivl_lval_sig(lval) || ivl_lval_nest(lval)
		|| ivl_lval_property_idx(lval) >= 0) {
		  fprintf(stderr, "%s:%u: sorry: this nested fixed member of a "
			  "dynamically sized streaming target is not yet "
			  "supported (IEEE 1800-2017 11.4.14.4).\n",
			  ivl_stmt_file(net), ivl_stmt_lineno(net));
		  return 1;
	    }
	    ivl_type_t type = ivl_lval_net_type(lval);
	    if (!type || (ivl_type_base(type) != IVL_VT_BOOL
			 && ivl_type_base(type) != IVL_VT_LOGIC)) {
		  fprintf(stderr, "%s:%u: error: this fixed member of a "
			  "streaming target is not a bit-stream type (IEEE "
			  "1800-2017 11.4.14.1).\n",
			  ivl_stmt_file(net), ivl_stmt_lineno(net));
		  return 1;
	    }
	    fixed_width += ivl_lval_width(lval);
      }

      if (dynamic_count == 0 && !have_range)
	    return -1;

      if (fixed_width > UINT_MAX) {
	    fprintf(stderr, "%s:%u: error: fixed members of this streaming "
		    "target exceed the VVP run-time width limit.\n",
		    ivl_stmt_file(net), ivl_stmt_lineno(net));
	    return 1;
      }

      /* Validate every dynamic destination before evaluating the source. A
	 * rejected target must not expose partial stores or source side effects. */
      for (unsigned idx = 0 ; idx < lvals ; idx += 1) {
	    ivl_lval_t lval = ivl_stmt_lval(net, idx);
	    if (!stream_lval_is_dynamic_(lval))
		  continue;
	    int validation_errors = validate_dynamic_stream_lval_(net, lval);
	    if (validation_errors)
		  return validation_errors;
      }

	/* An unconstrained variable-size member greedily consumes the remaining
	 * stream.  A later explicit with-range therefore has no well-defined
	 * source field; 11.4.14.4 requires all constrained variable-size fields
	 * to precede it (Slang diagnoses the same ordering). */
      int saw_unbounded = 0;
      for (unsigned pos = lvals ; pos > 0 ; pos -= 1) {
	    ivl_lval_t lval = ivl_stmt_lval(net, pos - 1);
	    if (stream_lval_is_dynamic_(lval)
		&& ivl_lval_stream_range(lval) == IVL_STREAM_RANGE_NONE) {
		  saw_unbounded = 1;
	    } else if (saw_unbounded
		       && ivl_lval_stream_range(lval) != IVL_STREAM_RANGE_NONE) {
		  fprintf(stderr, "%s:%u: error: a streaming `with' target may "
			  "not follow an unconstrained dynamically sized target "
			  "(IEEE 1800-2023 11.4.14.4).\n",
			  ivl_stmt_file(net), ivl_stmt_lineno(net));
		  return 1;
	    }
      }

      int errors = draw_stream_pack_pieces(rval, 0);
      if (errors < 0) {
	    fprintf(stderr, "%s:%u: internal error: malformed dynamic "
		    "streaming-target carrier.\n",
		    ivl_stmt_file(net), ivl_stmt_lineno(net));
	    return 1;
      }

      if (have_range) {
	    /* IVL exports concatenation members rightmost first.  Walk in reverse
	       source order so preceding fields are committed before a later
	       range expression is evaluated, exactly as 11.4.14.4 requires. */
	    int greedy_seen = 0;
	    for (unsigned pos = lvals ; pos > 0 ; pos -= 1) {
		  ivl_lval_t lval = ivl_stmt_lval(net, pos - 1);
		  ivl_stream_range_t kind = ivl_lval_stream_range(lval);
		  if (kind != IVL_STREAM_RANGE_NONE) {
			/* Evaluate a class / aggregate receiver once before its range
			   expressions. Keep that handle on the object stack until the
			   selected field has been stored, matching source evaluation
			   order even for nested or indexed receivers. */
			int prop_idx = ivl_lval_property_idx(lval);
			ivl_type_t receiver_type = 0;
			if (prop_idx >= 0) {
			      receiver_type = draw_lval_expr(lval);
			      if (!receiver_type
				  || prop_idx >= ivl_type_properties(receiver_type)) {
				    fprintf(stderr, "%s:%u: sorry: cannot resolve "
					    "streaming target property %d.\n",
					    ivl_stmt_file(net), ivl_stmt_lineno(net),
					    prop_idx);
				    fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
				    return errors + 1;
			      }
			}
			int first_reg = 0, second_reg = 0;
			if (!eval_stream_range_(lval, &first_reg, &second_reg)) {
			      fprintf(stderr, "%s:%u: internal error: streaming "
				      "range metadata has no first expression.\n",
				      ivl_stmt_file(net), ivl_stmt_lineno(net));
			      return errors + 1;
			}
			ivl_type_t elem = ivl_type_element(ivl_lval_net_type(lval));
			char elem_text[32];
			stream_elem_type_text(elem, elem_text, sizeof elem_text);
			uint64_t fixed_after = 0;
			for (unsigned tail = 0 ; tail + 1 < pos ; tail += 1) {
			      ivl_lval_t later = ivl_stmt_lval(net, tail);
			      if (!stream_lval_is_dynamic_(later)
				  && ivl_lval_stream_range(later)
					== IVL_STREAM_RANGE_NONE)
				    fixed_after += ivl_lval_width(later);
			}
			fprintf(vvp_out,
				"    %%stream/take/left/with \"%s:%s:%llu\", %d, %d;\n",
				stream_range_name_(kind), elem_text,
				(unsigned long long)(greedy_seen ? fixed_after : 0),
				first_reg, second_reg);
			unsigned lab_null = 0, lab_out = 0;
			if (prop_idx >= 0) {
			      lab_null = local_count++;
			      lab_out = local_count++;
			      fprintf(vvp_out, "    %%test_nul/obj;\n");
			      fprintf(vvp_out, "    %%jmp/1 T_%u.%u, 4;\n",
				      thread_count, lab_null);
			}
			if (stream_lval_is_dynamic_(lval)) {
			      errors += store_dynamic_stream_lval_with_(
				    lval, first_reg, second_reg, prop_idx >= 0);
			} else {
			      if (prop_idx >= 0) {
				    fprintf(vvp_out,
						"    %%stream/store/prop/fixed/%s %d, %d, %d;\n",
						stream_range_name_(kind), prop_idx,
						first_reg, second_reg);
				    fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
			      } else {
				    ivl_signal_t fsig = ivl_lval_sig(lval);
				    note_array_signal_use(fsig);
				    fprintf(vvp_out,
					  "    %%stream/store/fixed/%s v%p, %d, %d;\n",
					  stream_range_name_(kind), fsig,
					  first_reg, second_reg);
				      }
			}
			if (prop_idx >= 0) {
			      fprintf(vvp_out, "    %%jmp T_%u.%u;\n",
				      thread_count, lab_out);
			      fprintf(vvp_out, "T_%u.%u;\n",
				      thread_count, lab_null);
			      fprintf(vvp_out,
				      "    %%pop/vec4 1; null ranged property field\n");
			      fprintf(vvp_out,
				      "    %%pop/obj 1, 0; null ranged property receiver\n");
			      fprintf(vvp_out, "T_%u.%u;\n",
				      thread_count, lab_out);
			}
			clr_word(second_reg);
			clr_word(first_reg);
		  } else if (stream_lval_is_dynamic_(lval)) {
			if (greedy_seen) {
			      fprintf(vvp_out, "    %%stream/take/left 0;\n");
			} else {
			      uint64_t fixed_after = 0;
			      for (unsigned tail = 0 ; tail + 1 < pos ; tail += 1) {
				    ivl_lval_t later = ivl_stmt_lval(net, tail);
				    if (!stream_lval_is_dynamic_(later)
					&& ivl_lval_stream_range(later)
					      == IVL_STREAM_RANGE_NONE)
					  fixed_after += ivl_lval_width(later);
			      }
			      fprintf(vvp_out,
				      "    %%stream/take/left/rem %llu;\n",
				      (unsigned long long)fixed_after);
			      greedy_seen = 1;
			}
			errors += store_dynamic_stream_lval_(lval);
		  } else {
			fprintf(vvp_out, "    %%stream/take/left %u;\n",
				ivl_lval_width(lval));
			store_vec4_to_one_lval(lval);
		  }
	    }
	    /* Every take leaves the unconsumed suffix below its selected piece. */
	    fprintf(vvp_out, "    %%pop/vec4 1;\n");
	    return errors;
      }

      fprintf(vvp_out, "    %%stream/pad/min %u;\n", (unsigned)fixed_width);

      for (unsigned idx = 0 ; idx < lvals ; idx += 1) {
	    ivl_lval_t lval = ivl_stmt_lval(net, idx);
	    if (stream_lval_is_dynamic_(lval)) {
		  if (idx < greedy) {
			fprintf(vvp_out, "    %%pushi/vec4 0, 0, 0;\n");
		  } else {
			uint64_t fixed_left = 0;
			for (unsigned tail = idx + 1 ; tail < lvals ; tail += 1)
			      if (!stream_lval_is_dynamic_(
					ivl_stmt_lval(net, tail)))
				    fixed_left += ivl_lval_width(
					  ivl_stmt_lval(net, tail));
			if (fixed_left > 0)
			      fprintf(vvp_out, "    %%stream/split/rem %u;\n",
				      (unsigned)fixed_left);
		  }
		  errors += store_dynamic_stream_lval_(lval);
		  continue;
	    }

	    if (idx + 1 < lvals)
		  fprintf(vvp_out, "    %%split/vec4 %u;\n",
			  ivl_lval_width(lval));
	    store_vec4_to_one_lval(lval);
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

      {
	    int stream_errors = show_stmt_assign_dynamic_stream_(net);
	    if (stream_errors >= 0)
		  return stream_errors;
      }

      {
	    int concat_object_errors = show_stmt_assign_concat_cobject_(net);
	    if (concat_object_errors >= 0)
		  return concat_object_errors;
      }

	/* Assignment of a function returning an unpacked array into an
	   unpacked-array (or array-slice) l-value. The function is called
	   like a void function and the result words are copied out of its
	   return-array signal; see draw_ufunc_uarray. */
      {
	    ivl_expr_t rv = ivl_stmt_rval(net);
	    if (sig && ivl_signal_dimensions(sig) > 0
		&& rv && ivl_expr_type(rv) == IVL_EX_UFUNC
		&& ivl_stmt_opcode(net) == 0) {
		  ivl_scope_t def = ivl_expr_def(rv);
		  ivl_signal_t retsig = def ? ivl_scope_port(def, 0) : 0;
		  if (retsig && ivl_signal_dimensions(retsig) > 0) {
			draw_ufunc_uarray(rv, sig, array_pattern_base_(lval));
			return 0;
		  }
	    }
      }

	/* A whole fixed unpacked array receiving a container value. */
      {
	    ivl_expr_t rv = ivl_stmt_rval(net);
	    if (rv && ivl_stmt_opcode(net) == 0
		&& lval_is_whole_uarray_(lval, sig)
		&& rval_is_whole_container_(rv))
		  return show_stmt_assign_uarray_from_container(net, sig);
      }

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
