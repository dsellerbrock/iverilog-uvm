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
      struct args_info *child; /* Arguments can be nested. */
};

struct deferred_vpi_call_info {
      long source_id;
      ivl_scope_t scope;
      unsigned action_lab;
      unsigned after_lab;
      int is_final;
};

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

static int get_vpi_taskfunc_signal_arg(struct args_info *result,
                                       ivl_expr_t expr)
{
      char buffer[4096];
      ivl_signal_t sig;
      int class_like;

      switch (ivl_expr_type(expr)) {
	  case IVL_EX_SIGNAL:
	  case IVL_EX_PROPERTY:
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
	      /* For a string-typed class property (e.g. obj.str_field), emit
         &CPS<vSIG_0,pidx> so the runtime handle supports both
         vpi_get_value and vpi_put_value on the specific string property.
         Only handle the simple case (direct signal base, not nested). */
	      if (ivl_expr_type(expr) == IVL_EX_PROPERTY
		  && ivl_expr_value(expr) == IVL_VT_STRING
		  && ivl_expr_signal(expr)
		  && !ivl_expr_oper1(expr)) {
		    unsigned pidx = (unsigned)ivl_expr_property_idx(expr);
		    snprintf(buffer, sizeof buffer, "&CPS<v%p_0, %u>",
			     (void*)ivl_expr_signal(expr), pidx);
		    result->text = strdup(buffer);
		    return 1;
	      }
	      /* Integral class properties need the same property-aware VPI
	         lvalue treatment as strings. In particular,
	         $value$plusargs("N=%d", obj.n) must update obj.n rather than
	         a discarded vec4 stack temporary. Encode the property index,
	         width, and signedness for the runtime handle. */
	      if (ivl_expr_type(expr) == IVL_EX_PROPERTY
		  && (ivl_expr_value(expr) == IVL_VT_LOGIC
		      || ivl_expr_value(expr) == IVL_VT_BOOL)
		  && ivl_expr_signal(expr)
		  && !ivl_expr_oper1(expr)) {
		    unsigned pidx = (unsigned)ivl_expr_property_idx(expr);
		    snprintf(buffer, sizeof buffer, "&CPV<v%p_0, %u, %u, %u>",
			     (void*)ivl_expr_signal(expr), pidx,
			     ivl_expr_width(expr), ivl_expr_signed(expr) ? 1 : 0);
		    result->text = strdup(buffer);
		    return 1;
	      }
	      /* Nested or array-indexed string property: fall back so the
	         caller dispatches to draw_eval_string (rvalue-only). */
	      if (ivl_expr_type(expr) == IVL_EX_PROPERTY
		  && ivl_expr_value(expr) == IVL_VT_STRING)
		    return 0;
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
		  snprintf(buffer, sizeof buffer, "&PV<v%p_0, %ld, %u>",
		           ivl_expr_signal(vexpr),
		           get_number_immediate(bexpr),
		           ivl_expr_width(expr));

	      /* This is an indexed bit/part select. */
	    } else if (ivl_expr_type(bexpr) == IVL_EX_SIGNAL ||
	               ivl_expr_type(bexpr) == IVL_EX_SELECT) {
		    /* Special case: the base is a signal/select. */
		  result->child = calloc(1, sizeof(struct args_info));
		  if (get_vpi_taskfunc_signal_arg(result->child, bexpr)) {
			snprintf(buffer, sizeof buffer, "&PV<v%p_0, %s, %u>",
			         ivl_expr_signal(vexpr),
			         result->child->text,
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
      fprintf(vvp_out, "    %%test/class C%p; $cast: 6.24.2 type check\n",
              dest_type);
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

      if (!sig)
            return 0;

      switch (ivl_expr_type(expr)) {
	  case IVL_EX_SIGNAL:
	  case IVL_EX_PROPERTY:
	    if (ivl_signal_dimensions(sig) != 0)
		  return 0;
	    snprintf(buffer, sizeof buffer, "v%p_0", sig);
	    result->text = strdup(buffer);
	    return 1;

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
		  if (get_vpi_taskfunc_lvalue_arg(&args[idx], expr))
			continue;
	    }

	    switch (ivl_expr_type(expr)) {

		    /* These expression types can be handled directly,
		       with VPI handles of their own. Therefore, skip
		       them in the process of evaluating expressions. */
		case IVL_EX_NONE:
		  args[idx].text = strdup("\" \"");
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
		  if (!force_value_capture) {
			args[idx].stack = vec4_stack_need;
			if (get_vpi_taskfunc_signal_arg(&args[idx], expr)) {
			      if (args[idx].vec_flag) {
				    vec4_stack_need += 1;
			      } else {
				    args[idx].stack = 0;
			      }
			      continue;
			}
			args[idx].stack = 0;
		  }
		  break;
		case IVL_EX_NULL:
		  snprintf(buffer, sizeof buffer, "null");
		  args[idx].text = strdup(buffer);
		  continue;
		    /* Everything else will need to be evaluated and
		       passed as a constant to the vpi task. */
		default:
		  break;
	    }

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
	    fprintf(vvp_out, "    %%defer/%s T_%u.%u, S_%p;\n",
		    deferred->is_final ? "final" : "enqueue",
		    thread_count, deferred->action_lab, deferred->scope);
	    fprintf(vvp_out, "    %%jmp T_%u.%u;\n",
		    thread_count, deferred->after_lab);
	    fprintf(vvp_out, "T_%u.%u ;\n",
		    thread_count, deferred->action_lab);
	    if (deferred->is_final)
		  fprintf(vvp_out, "    %%defer/final/key %ld;\n",
			  deferred->source_id);
      }

      fprintf(vvp_out, "%s", call_string);

      for (idx = 0 ;  idx < parm_count ;  idx += 1) {
	    struct args_info*ptr;

	    if (args[idx].str_flag) {
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
	    } else if (args[idx].vec_flag) {
		  unsigned pos = vec4_stack_need - args[idx].stack - 1;
		  char sign_flag = args[idx].vec_flag;
		  unsigned wid = args[idx].vec_wid;
		  fprintf(vvp_out, ", S<%u,vec4,%c%u>",pos, sign_flag, wid);
	    } else {
		  fprintf(vvp_out, ", %s", args[idx].text);
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

      if (draw_sv_cast_class_task(tnet))
            return;

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
                    ivl_stmt_lineno(tnet), ivl_stmt_name(tnet));
      } else {
	    char call_string[1024];
	    snprintf(call_string, sizeof(call_string),
		     "    %s %u %u \"%s\"", command,
		     ivl_file_table_index(ivl_stmt_file(tnet)),
		     ivl_stmt_lineno(tnet), ivl_stmt_name(tnet));
	    draw_vpi_taskfunc_args(call_string, tnet, 0, 0, 0, 0, 0);
      }
}

int draw_vpi_deferred_call(ivl_statement_t tnet, unsigned parm_base,
			   const char*task_name, long source_id,
			   ivl_scope_t scope, int is_final)
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
