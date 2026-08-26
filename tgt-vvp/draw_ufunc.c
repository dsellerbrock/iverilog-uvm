/*
 * Copyright (c) 2005-2016 Stephen Williams (steve@icarus.com)
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

static void function_argument_logic(ivl_signal_t port, ivl_expr_t expr)
{
      unsigned ewidth, pwidth;

	/* ports cannot be arrays. */
      assert(ivl_signal_dimensions(port) == 0);

      ewidth = ivl_expr_width(expr);
      pwidth = ivl_signal_width(port);

      draw_eval_vec4(expr);
      if (ewidth < pwidth)
	    fprintf(vvp_out, "    %%pad/u %u;\n", pwidth);

}

static void function_argument_real(ivl_signal_t port, ivl_expr_t expr)
{
	/* ports cannot be arrays. */
      assert(ivl_signal_dimensions(port) == 0);

      draw_eval_real(expr);
}

static int port_is_unsupported_aggregate_formal_(ivl_signal_t port)
{
      ivl_type_t net_type;

      if (!port)
            return 0;

      if (ivl_signal_data_type(port) != IVL_VT_NO_TYPE)
            return 0;

      net_type = ivl_signal_net_type(port);
      if (net_type && ivl_type_properties(net_type) > 0)
            return 0;

      {
	    unsigned wid = ivl_signal_width(port);
	    return (wid == 0) || (wid == ~0U);
      }
}

/* True when a `ref' actual can be named directly by %ref/bind: a whole
   variable, not a word of an array or a part of one. */
static int ref_actual_is_nameable_(ivl_expr_t expr)
{
      if (!expr) return 0;
      if (ivl_expr_type(expr) != IVL_EX_SIGNAL) return 0;
      if (ivl_expr_oper1(expr)) return 0;          /* word select */
      if (!ivl_expr_signal(expr)) return 0;
      if (ivl_signal_dimensions(ivl_expr_signal(expr)) > 0) return 0;
      return 1;
}

static int function_port_is_assoc_output_(ivl_signal_t port)
{
      ivl_type_t type;

      if (!port || ivl_signal_port(port) != IVL_SIP_OUTPUT
	  || ivl_signal_dimensions(port) > 0)
	    return 0;
      type = ivl_signal_net_type(port);
      return type && ivl_type_base(type) == IVL_VT_QUEUE
	  && ivl_type_queue_assoc_compat(type);
}

/* Bind one `ref' formal (IEEE 1800-2017 13.5.2). An actual that cannot
   be named is copied into the formal's per-frame companion word, which
   is what the formal is then bound to; draw_copy_out_function_arguments
   copies it back through the same binding. */
static void draw_bind_function_ref_argument(ivl_signal_t port, ivl_expr_t expr)
{
      if (ref_actual_is_nameable_(expr)) {
	    fprintf(vvp_out, "    %%ref/bind v%p_0, v%p_0;\n",
		    port, ivl_expr_signal(expr));
	    return;
      }

      draw_eval_vec4(expr);
      fprintf(vvp_out, "    %%store/vec4 v%p_R, 0, %u;\n",
	      port, ivl_signal_width(port));
      fprintf(vvp_out, "    %%ref/bind/f v%p_0, v%p_R;\n", port, port);
}

static void draw_eval_function_argument(ivl_signal_t port, ivl_expr_t expr)
{
      static int warned_unsupported_arg_type = 0;
      static int warned_aggregate_arg_skip = 0;
      ivl_variable_type_t dtype = ivl_signal_data_type(port);

	/* A ref formal is bound, not copied. The bind is emitted in its
	   own pass (it must land after every argument has been
	   evaluated, since evaluating one may call another function). */
      if (ivl_signal_port(port) == IVL_SIP_REF)
	    return;

	/* A pure output formal starts with its type's default value (IEEE
	 * 1800-2017 13.5.2); evaluating the caller's associative actual here
	 * copied its existing entries into the callee before the call. The send
	 * pass below installs a fresh empty value instead. */
      if (function_port_is_assoc_output_(port))
	    return;

	/* An unpacked fixed-array formal can retain its element data type
	 * (notably an implicitly typed `input a[3:0]') while still having
	 * signal dimensions. It is passed through the same temporary open-array
	 * object used by explicitly typed fixed-array formals. Treating it as a
	 * scalar reaches function_argument_logic's no-dimensions invariant and
	 * aborts the target. */
      if (ivl_signal_dimensions(port) > 0) {
	    vvp_errors += draw_eval_object(expr);
	    return;
      }
      if (port_is_unsupported_aggregate_formal_(port)) {
	    if (!warned_aggregate_arg_skip) {
		  fprintf(stderr,
		          "Warning: Skipping unsupported aggregate function argument %s"
		          " (further similar warnings suppressed)\n",
		          ivl_signal_basename(port));
		  warned_aggregate_arg_skip = 1;
	    }
	    return;
      }

      switch (dtype) {
	  case IVL_VT_BOOL:
	      /* For now, treat bit2 variables as bit4 variables. */
	  case IVL_VT_LOGIC:
	    function_argument_logic(port, expr);
	    break;
	  case IVL_VT_REAL:
	    function_argument_real(port, expr);
	    break;
	  case IVL_VT_CLASS:
	    vvp_errors += draw_eval_object(expr);
	    break;
	  case IVL_VT_STRING:
	    draw_eval_string(expr);
	    break;
	  case IVL_VT_DARRAY:
	    vvp_errors += draw_eval_object(expr);
	    break;
	  case IVL_VT_QUEUE:
	  case IVL_VT_NO_TYPE:
	    vvp_errors += draw_eval_object(expr);
	    break;
	  default:
	    if (!warned_unsupported_arg_type) {
		  fprintf(stderr, "Warning: Unsupported function argument type %d for %s; treating as object"
			  " (further similar warnings suppressed)\n",
			  dtype, ivl_signal_basename(port));
		  warned_unsupported_arg_type = 1;
	    }
	    vvp_errors += draw_eval_object(expr);
	    break;
      }
}

static int fixed_array_open_actual_(ivl_expr_t expr)
{
      return expr
	  && (ivl_expr_type(expr) == IVL_EX_ARRAY
	      || vvp_expr_is_whole_fixed_array_property(expr));
}

static void draw_send_function_argument(ivl_signal_t port, ivl_expr_t actual)
{
      static int warned_unsupported_send_type = 0;
      static int warned_aggregate_send_skip = 0;
      ivl_variable_type_t dtype = ivl_signal_data_type(port);

      if (ivl_signal_port(port) == IVL_SIP_REF)
	    return;

	/* Do not copy an associative actual into a pure output formal. Reset even
	 * a static function's port on every call; the typed signal lazily creates
	 * a fresh empty associative object when the function first reads/writes it. */
      if (function_port_is_assoc_output_(port)) {
	    fprintf(vvp_out, "    %%null; ; default value for output associative array\n");
	    fprintf(vvp_out, "    %%store/obj v%p_0;\n", port);
	    return;
      }

      if (ivl_signal_dimensions(port) > 0) {
	    unsigned kind;
	    if (uarray_container_kind_(port, &kind,
				       ivl_signal_file(port),
				       ivl_signal_lineno(port)))
		  emit_store_arr_dar_(port, kind);
	    else
		  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
	    return;
      }

      if (port_is_unsupported_aggregate_formal_(port)) {
	    if (!warned_aggregate_send_skip) {
		  fprintf(stderr,
		          "Warning: Skipping unsupported aggregate function send %s"
		          " (further similar warnings suppressed)\n",
		          ivl_signal_basename(port));
		  warned_aggregate_send_skip = 1;
	    }
	    return;
      }

      switch (dtype) {
	  case IVL_VT_BOOL:
	      /* For now, treat bit2 variables as bit4 variables. */
	  case IVL_VT_LOGIC:
	    fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, %u;\n",
				      port, ivl_signal_width(port));
	    break;
	  case IVL_VT_REAL:
	    fprintf(vvp_out, "    %%store/real v%p_0;\n", port);
	    break;
	  case IVL_VT_CLASS:
	    fprintf(vvp_out, "    %%store/obj v%p_0;\n", port);
	    break;
	  case IVL_VT_STRING:
	    fprintf(vvp_out, "    %%store/str v%p_0;\n", port);
	    break;
	  case IVL_VT_DARRAY:
	      /* IEEE 1800-2017 13.5.1: a non-`ref' argument is passed BY
		 VALUE, and a dynamic array or queue is a value container
		 (7.4, 7.5) -- not a handle like a class, which is a
		 reference and is deliberately left aliasing above.

		 The eval pass pushed the caller's container and this
		 stored it straight into the formal, so formal and actual
		 were the SAME object: a callee writing its own input
		 formal wrote through to the caller. `f(q)' with a callee
		 doing `m[0] = 32'hff' left the caller's q[0] at ff, at
		 exit 0 with no diagnostic.

		 Copy exactly the way plain assignment already does --
		 %dup/obj, %store/obj, %pop/obj. %dup/obj deep-copies
		 (of_DUP_OBJ calls src.duplicate(); the aliasing variant
		 is a separate opcode, %dup/obj/ref). The pop matters:
		 %store/obj pops ONE object, so storing the duplicate
		 would strand the original on the object stack and the
		 runtime's CLEANUP-leak check would fire.

		 A `ref' formal must alias and never gets here -- both
		 passes return early on IVL_SIP_REF. */
	    fprintf(vvp_out, "    %%dup/obj; pass by value (IEEE 13.5.1)\n");
	    fprintf(vvp_out, "    %%store/obj%s v%p_0;\n",
		    fixed_array_open_actual_(actual) ? "/open" : "", port);
	    fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
	    break;
	  case IVL_VT_QUEUE:
	    fprintf(vvp_out, "    %%dup/obj; pass by value (IEEE 13.5.1)\n");
	    fprintf(vvp_out, "    %%store/obj v%p_0;\n", port);
	    fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
	    break;
	  case IVL_VT_NO_TYPE:
	    fprintf(vvp_out, "    %%store/obj v%p_0;\n", port);
	    break;
	  default:
	    if (!warned_unsupported_send_type) {
		  fprintf(stderr, "Warning: Unsupported function send argument type %d for %s; treating as object"
			  " (further similar warnings suppressed)\n",
			  dtype, ivl_signal_basename(port));
		  warned_unsupported_send_type = 1;
	    }
	    fprintf(vvp_out, "    %%store/obj v%p_0;\n", port);
	    break;
      }
}

static int function_argument_actual_signal_(ivl_expr_t expr,
					    ivl_signal_t*sig,
					    ivl_expr_t*word)
{
      if (sig)
	    *sig = 0;
      if (word)
	    *word = 0;

      if (!expr || ivl_expr_type(expr) != IVL_EX_SIGNAL)
	    return 0;

      if (sig)
	    *sig = ivl_expr_signal(expr);
      if (word)
	    *word = ivl_expr_oper1(expr);

      return sig && *sig;
}

static void draw_copy_out_function_argument(ivl_signal_t port, ivl_expr_t actual)
{
      static int warned_unsupported_copy_out = 0;
      ivl_signal_t sig = 0;
      ivl_expr_t word = 0;
      ivl_variable_type_t dtype;

      if (port_is_unsupported_aggregate_formal_(port))
	    return;

	/* Whole fixed-array output/inout copy-back. Both sides use inline
	   word storage, so marshal the formal through the same temporary
	   container used by fixed<->dynamic assignment. This also covers a
	   fixed unpacked-array DPI formal called from an SV wrapper. */
      if (ivl_signal_dimensions(port) > 0
	  && ivl_expr_type(actual) == IVL_EX_ARRAY
	  && ivl_expr_signal(actual)
	  && ivl_signal_dimensions(ivl_expr_signal(actual)) > 0) {
	    ivl_signal_t asig = ivl_expr_signal(actual);
	    unsigned pkind, akind;
	    if (uarray_container_kind_(port, &pkind,
				       ivl_expr_file(actual),
				       ivl_expr_lineno(actual))
		&& uarray_container_kind_(asig, &akind,
					 ivl_expr_file(actual),
					 ivl_expr_lineno(actual))) {
		  emit_load_arr_dar_(port, pkind);
		  emit_store_arr_dar_(asig, akind);
	    }
	    return;
      }

      /* Phase 63b/B6 (gap close): unwrap a single-level IVL_EX_SELECT
         that's just a width/sign cast wrapping an IVL_EX_PROPERTY.
         iverilog emits this when `uvm_config_db#(T)::get(this, "",
         "name", this.m_field)` casts the formal type to the actual
         field's width.  After unwrap, the existing IVL_EX_PROPERTY
         handler below copies out via %store/prop/<v>.  Don't unwrap
         the assoc-array form (SELECT with both oper1=PROPERTY and
         oper2=key) — that's handled by its own dedicated branch. */
      if (ivl_expr_type(actual) == IVL_EX_SELECT
	  && !ivl_expr_oper2(actual)
	  && ivl_expr_oper1(actual)
	  && ivl_expr_type(ivl_expr_oper1(actual)) == IVL_EX_PROPERTY) {
	    actual = ivl_expr_oper1(actual);
      }

      /* Handle copy-out to an indexed assoc-array entry of a class
         property (e.g. cfg.vifs[key]). Iverilog represents this as
         IVL_EX_SELECT(arr, key) where `arr` is the IVL_EX_PROPERTY for
         cfg.vifs. Emit the containing cobj load + %prop/obj to push
         the assoc-array, then the key, then the port value, then
         %aa/store/<v>/<k>. */
      (void)warned_unsupported_copy_out;
      if (ivl_expr_type(actual) == IVL_EX_SELECT) {
	    ivl_expr_t arr_expr = ivl_expr_oper1(actual);
	    ivl_expr_t key_expr = ivl_expr_oper2(actual);
	    if (arr_expr && key_expr
		&& ivl_expr_type(arr_expr) == IVL_EX_PROPERTY
		&& !ivl_expr_oper1(arr_expr)) {
		  ivl_signal_t base_sig = ivl_expr_signal(arr_expr);
		  int aa_pidx = (int)ivl_expr_property_idx(arr_expr);
		  dtype = ivl_signal_data_type(port);

		  /* Push containing cobj */
		  if (base_sig) {
			fprintf(vvp_out, "    %%load/obj v%p_0;\n", base_sig);
		  } else {
			ivl_expr_t base_expr = ivl_expr_oper2(arr_expr);
			if (!base_expr) {
			      if (!warned_unsupported_copy_out) {
				    fprintf(stderr,
				            "Warning: Skipping nested-base assoc"
					    " copy-out for %s (further similar"
					    " warnings suppressed)\n",
					    ivl_signal_basename(port));
				    warned_unsupported_copy_out = 1;
			      }
			      return;
			}
			draw_eval_object(base_expr);
		  }
		  /* Load the assoc array (as obj) on top */
		  fprintf(vvp_out, "    %%prop/obj %d, 0;\n", aa_pidx);
		  fprintf(vvp_out, "    %%pop/obj 1, 1;\n"); /* drop cobj keep aa */

		  /* Push the key with the right type for the assoc store.
		     draw_eval_assoc_key_ uses iverilog's notion of which
		     key type the assoc array expects (str/obj/v). */
		  const char*key_kind = draw_eval_assoc_key_(key_expr, 0);
		  /* Push the port value, emit aa/store */
		  switch (dtype) {
		      case IVL_VT_BOOL:
		      case IVL_VT_LOGIC:
			fprintf(vvp_out, "    %%load/vec4 v%p_0;\n", port);
			fprintf(vvp_out, "    %%aa/store/v/%s %u;\n", key_kind,
				ivl_signal_width(port));
			break;
		      case IVL_VT_REAL:
			fprintf(vvp_out, "    %%load/real v%p_0;\n", port);
			fprintf(vvp_out, "    %%aa/store/r/%s;\n", key_kind);
			break;
		      case IVL_VT_STRING:
			fprintf(vvp_out, "    %%load/str v%p_0;\n", port);
			fprintf(vvp_out, "    %%aa/store/str/%s;\n", key_kind);
			break;
		      case IVL_VT_CLASS:
		      case IVL_VT_DARRAY:
		      case IVL_VT_QUEUE:
		      case IVL_VT_NO_TYPE:
		      default:
			fprintf(vvp_out, "    %%load/obj v%p_0;\n", port);
			fprintf(vvp_out, "    %%aa/store/obj/%s;\n", key_kind);
			break;
		  }
		  fprintf(vvp_out, "    %%pop/obj 1, 0;\n"); /* drop aa */
		  return;
	    }
      }

      if (ivl_expr_type(actual) == IVL_EX_PROPERTY) {
	    ivl_signal_t base_sig = ivl_expr_signal(actual);
	    /* If an index is set, the actual is an assoc-array / queue / array
	       entry of a class property (e.g. cfg.vifs[key]). We don't yet
	       emit a proper %aa/store sequence here — fall through with a
	       warning so the call still elaborates (the value just won't be
	       written back to the indexed slot). */
	    if (ivl_expr_oper1(actual)) {
		  if (!warned_unsupported_copy_out) {
			fprintf(stderr,
				"Warning: Skipping indexed property copy-out for"
				" %s (further similar warnings suppressed)\n",
				ivl_signal_basename(port));
			warned_unsupported_copy_out = 1;
		  }
		  return;
	    }
	    int pidx = (int)ivl_expr_property_idx(actual);
	    dtype = ivl_signal_data_type(port);
	    int fixed_array_property =
		  vvp_expr_is_whole_fixed_array_property(actual);

	    /* Push the containing cobj. If base_sig is set, use a direct
	       load; otherwise oper2 holds the nested-base property expression
	       (e.g. env.cfg in env.cfg.o). draw_eval_object pushes that
	       cobj's value onto the obj stack. */
	    if (base_sig) {
		  fprintf(vvp_out, "    %%load/obj v%p_0;\n", base_sig);
	    } else {
		  ivl_expr_t base_expr = ivl_expr_oper2(actual);
		  if (!base_expr) {
			if (!warned_unsupported_copy_out) {
			      fprintf(stderr,
				      "Warning: Skipping nested-base property copy-out"
				      " for %s — no base expr"
				      " (further similar warnings suppressed)\n",
				      ivl_signal_basename(port));
			      warned_unsupported_copy_out = 1;
			}
			return;
		  }
		  draw_eval_object(base_expr);
	    }
	    switch (dtype) {
		case IVL_VT_BOOL:
		case IVL_VT_LOGIC:
		  fprintf(vvp_out, "    %%load/vec4 v%p_0;\n", port);
		  fprintf(vvp_out, "    %%store/prop/v %d, %u;\n", pidx,
		          ivl_signal_width(port));
		  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
		  break;
		case IVL_VT_REAL:
		  fprintf(vvp_out, "    %%load/real v%p_0;\n", port);
		  fprintf(vvp_out, "    %%store/prop/r %d;\n", pidx);
		  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
		  break;
		case IVL_VT_STRING:
		  fprintf(vvp_out, "    %%load/str v%p_0;\n", port);
		  fprintf(vvp_out, "    %%store/prop/str %d;\n", pidx);
		  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
		  break;
	    case IVL_VT_DARRAY:
		  if (fixed_array_property) {
			fprintf(vvp_out, "    %%load/obj v%p_0;\n", port);
			fprintf(vvp_out,
				"    %%store/prop/arr/dar %d;\n", pidx);
			fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
			break;
		  }
		  /* fall through */
	    case IVL_VT_CLASS:
	    case IVL_VT_QUEUE:
		case IVL_VT_NO_TYPE:
		default:
		  fprintf(vvp_out, "    %%load/obj v%p_0;\n", port);
		  fprintf(vvp_out, "    %%store/prop/obj %d, 0;\n", pidx);
		  fprintf(vvp_out, "    %%pop/obj 1, 0;\n");
		  break;
	    }
	    return;
      }

      /* Phase 63b/B6 (real impl): handle IVL_EX_SELECT-wrapped
	 signal actuals that arise from width-cast / sign-cast
	 normalization at the call site.  When the SELECT has no
	 base (oper2 nil) and oper1 is a signal of vectorable type,
	 the SELECT is a width pad/truncate of the underlying
	 signal — we copy out from the port directly into the
	 underlying signal, padding/truncating as needed.  This
	 covers the common UVM pattern
	   uvm_config_int::get(... , tmp);
	 where iverilog wraps `tmp` in a SELECT for type
	 normalization. */
      if (ivl_expr_type(actual) == IVL_EX_SELECT
	  && !ivl_expr_oper2(actual)
	  && ivl_expr_oper1(actual)
	  && ivl_expr_type(ivl_expr_oper1(actual)) == IVL_EX_SIGNAL) {
	    ivl_expr_t op1 = ivl_expr_oper1(actual);
	    ivl_signal_t under_sig = ivl_expr_signal(op1);
	    if (under_sig && ivl_signal_dimensions(under_sig) == 0) {
		  ivl_variable_type_t udtype = ivl_signal_data_type(under_sig);
		  unsigned port_wid = ivl_signal_width(port);
		  unsigned sig_wid  = ivl_signal_width(under_sig);
		  if (udtype == IVL_VT_BOOL || udtype == IVL_VT_LOGIC) {
			fprintf(vvp_out, "    %%load/vec4 v%p_0;\n", port);
			if (sig_wid != port_wid) {
			      const char*pad = ivl_signal_signed(under_sig)
				    ? "%pad/s" : "%pad/u";
			      fprintf(vvp_out, "    %s %u;\n", pad, sig_wid);
			}
			fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, %u;\n",
				under_sig, sig_wid);
			return;
		  }
	    }
      }

	/* A `ref'/`output'/`inout' open-array formal whose actual is a
	   WHOLE fixed unpacked array. The formal holds a container and
	   the actual holds inline words, so the copy back out is the
	   same container -> fixed-array copy the 7.6 assignment makes;
	   it goes through the same %store/arr/dar.

	   Without this the actual was not an IVL_EX_SIGNAL, so the
	   generic path below skipped the copy-out and warned once --
	   after which every further such call was silent. A function
	   that wrote through its open-array formal simply had no effect
	   on the caller's array, which is what `sv_open_array_copy_back'
	   pins for both the task and the function spelling. */
      if (ivl_expr_type(actual) == IVL_EX_ARRAY
	  && ivl_expr_signal(actual)
	  && ivl_signal_dimensions(ivl_expr_signal(actual)) > 0
	  && (ivl_signal_data_type(port) == IVL_VT_DARRAY
	      || ivl_signal_data_type(port) == IVL_VT_QUEUE)) {
	    ivl_signal_t asig = ivl_expr_signal(actual);
	    unsigned kind;
	    if (uarray_container_kind_(asig, &kind, ivl_expr_file(actual),
				       ivl_expr_lineno(actual))) {
		  fprintf(vvp_out, "    %%load/obj v%p_0;\n", port);
		  note_array_signal_use(asig);
		  emit_store_arr_dar_(asig, kind);
	    }
	    return;
      }

      if (!function_argument_actual_signal_(actual, &sig, &word)) {
	    /* Phase 63b/B6: surface the file:line of the call site so
	       users can find and rewrite affected callers.  The runtime
	       behavior is unchanged — the copy-out is still silently
	       skipped — but the diagnostic is now actionable. */
	    if (!warned_unsupported_copy_out) {
		  const char*f = ivl_expr_file(actual);
		  unsigned ln = ivl_expr_lineno(actual);
		  fprintf(stderr,
		          "%s:%u: warning: Skipping unsupported function copy-out"
		          " argument for `%s' (further similar warnings"
		          " suppressed)\n",
		          f ? f : "<unknown>", ln,
		          ivl_signal_basename(port));
		  warned_unsupported_copy_out = 1;
	    }
	    return;
      }

      dtype = ivl_signal_data_type(port);

      if (word && (ivl_signal_dimensions(sig) == 0)) {
	    if (!warned_unsupported_copy_out) {
		  fprintf(stderr,
		          "Warning: Skipping unsupported function copy-out select for %s"
		          " (further similar warnings suppressed)\n",
		          ivl_signal_basename(port));
		  warned_unsupported_copy_out = 1;
	    }
	    return;
      }

      if (word) {
	    unsigned ix = allocate_word();
	    draw_eval_expr_into_integer(word, ix);
	    note_array_signal_use(sig);
	    switch (dtype) {
		case IVL_VT_BOOL:
		case IVL_VT_LOGIC:
		  fprintf(vvp_out, "    %%load/vec4 v%p_0;\n", port);
		  fprintf(vvp_out, "    %%store/vec4a v%p, %u, 0;\n", sig, ix);
		  break;
		case IVL_VT_REAL:
		  fprintf(vvp_out, "    %%load/real v%p_0;\n", port);
		  fprintf(vvp_out, "    %%store/reala v%p, %u;\n", sig, ix);
		  break;
		case IVL_VT_STRING:
		  fprintf(vvp_out, "    %%load/str v%p_0;\n", port);
		  fprintf(vvp_out, "    %%store/stra v%p, %u;\n", sig, ix);
		  break;
		case IVL_VT_CLASS:
		case IVL_VT_DARRAY:
		case IVL_VT_QUEUE:
		case IVL_VT_NO_TYPE:
		  fprintf(vvp_out, "    %%load/obj v%p_0;\n", port);
		  fprintf(vvp_out, "    %%store/obja v%p, %u;\n", sig, ix);
		  break;
		default:
		  if (!warned_unsupported_copy_out) {
			fprintf(stderr,
			        "Warning: Unsupported function copy-out type %d for %s"
			        " (further similar warnings suppressed)\n",
			        dtype, ivl_signal_basename(port));
			warned_unsupported_copy_out = 1;
		  }
		  break;
	    }
	    clr_word(ix);
	    return;
      }

      switch (dtype) {
	  case IVL_VT_BOOL:
	  case IVL_VT_LOGIC:
	    fprintf(vvp_out, "    %%load/vec4 v%p_0;\n", port);
	    if (signal_is_return_value(sig))
		  fprintf(vvp_out, "    %%ret/vec4 0, 0, %u;\n",
			  ivl_signal_width(sig));
	    else
		  fprintf(vvp_out, "    %%store/vec4 v%p_0, 0, %u;\n",
			  sig, ivl_signal_width(sig));
	    break;
	  case IVL_VT_REAL:
	    fprintf(vvp_out, "    %%load/real v%p_0;\n", port);
	    if (signal_is_return_value(sig))
		  fprintf(vvp_out, "    %%ret/real 0;\n");
	    else
		  fprintf(vvp_out, "    %%store/real v%p_0;\n", sig);
	    break;
	  case IVL_VT_STRING:
	    fprintf(vvp_out, "    %%load/str v%p_0;\n", port);
	    if (signal_is_return_value(sig))
		  fprintf(vvp_out, "    %%ret/str 0;\n");
	    else
		  fprintf(vvp_out, "    %%store/str v%p_0;\n", sig);
	    break;
	  case IVL_VT_CLASS:
	  case IVL_VT_DARRAY:
	  case IVL_VT_QUEUE:
	  case IVL_VT_NO_TYPE:
	    fprintf(vvp_out, "    %%load/obj v%p_0;\n", port);
	    fprintf(vvp_out, "    %%store/obj v%p_0;\n", sig);
	    break;
	  default:
	    if (!warned_unsupported_copy_out) {
		  fprintf(stderr,
		          "Warning: Unsupported function copy-out type %d for %s"
		          " (further similar warnings suppressed)\n",
		          dtype, ivl_signal_basename(port));
		  warned_unsupported_copy_out = 1;
	    }
	    break;
      }
}

static void draw_copy_out_function_arguments(ivl_expr_t expr)
{
      ivl_scope_t def = ivl_expr_def(expr);
      unsigned idx;

      assert(ivl_expr_parms(expr) == (ivl_scope_ports(def)-1));
      for (idx = 0 ; idx < ivl_expr_parms(expr) ; idx += 1) {
	    ivl_signal_t port = ivl_scope_port(def, idx+1);
	    ivl_signal_port_t port_type = ivl_signal_port(port);

	      /* A bound ref formal needs no copy-out -- writes through it
		 already landed in the caller's variable. One bound to a
		 companion does: reading the formal reads the companion,
		 so the ordinary copy-out is what puts it back. */
	    if (port_type == IVL_SIP_REF) {
		  if (ref_actual_is_nameable_(ivl_expr_parm(expr, idx)))
			continue;
	    } else if ((port_type != IVL_SIP_OUTPUT) &&
		       (port_type != IVL_SIP_INOUT)) {
		  continue;
	    }

	    draw_copy_out_function_argument(port, ivl_expr_parm(expr, idx));
      }
}

static void draw_ufunc_preamble(ivl_expr_t expr)
{
      ivl_scope_t def = ivl_expr_def(expr);
      unsigned idx;
      unsigned first_unbound_parm = 0;

        /* If this is an automatic function, allocate the local storage. */
      if (ivl_scope_is_auto(def)) {
            fprintf(vvp_out, "    %%alloc S_%p;\n", def);
      }

	/* A class method's first actual is its implicit `this' handle.  Bind
	 * that handle before evaluating user arguments.  A default argument is
	 * elaborated in the method's scope and may call another method or read a
	 * property through `this' (IEEE 1800-2017 13.5.3).  The old generic
	 * two-pass sequence evaluated every argument first and did not store
	 * `this' until afterwards, so such a default read a stale/null object
	 * from the callee frame.  Automatic class-method frames make this early
	 * store safe from nested calls; explicit actuals retain their existing
	 * left-to-right evaluation order. */
      if (ivl_expr_parms(expr) > 0 && ivl_scope_ports(def) > 1) {
	    ivl_signal_t this_port = ivl_scope_port(def, 1);
	    const char*name = this_port ? ivl_signal_basename(this_port) : 0;
	    if (name && strcmp(name, "@") == 0) {
		  draw_eval_function_argument(this_port, ivl_expr_parm(expr, 0));
		  draw_send_function_argument(this_port, ivl_expr_parm(expr, 0));
		  first_unbound_parm = 1;
	    }
      }

	/* Evaluate the expressions and send the results to the
	   function ports. Do this in two passes - evaluate,
	   then send - this avoids the function input variables
	   being overwritten if the same (non-automatic) function
	   is called in one of the expressions. */

      assert(ivl_expr_parms(expr) == (ivl_scope_ports(def)-1));
      for (idx = first_unbound_parm ;
	   idx < ivl_expr_parms(expr) ; idx += 1) {
	    ivl_signal_t port = ivl_scope_port(def, idx+1);
	    draw_eval_function_argument(port, ivl_expr_parm(expr, idx));
      }
	for (idx = ivl_expr_parms(expr) ;
	     idx > first_unbound_parm ; idx -= 1) {
	    ivl_signal_t port = ivl_scope_port(def, idx);
	    draw_send_function_argument(port, ivl_expr_parm(expr, idx-1));
      }

	/* Bind the ref formals last, so that evaluating any argument --
	   which may itself call a function, allocating and freeing
	   frames -- is finished before this frame's bindings are set. */
      for (idx = first_unbound_parm ;
	   idx < ivl_expr_parms(expr) ; idx += 1) {
	    ivl_signal_t port = ivl_scope_port(def, idx+1);
	    if (ivl_signal_port(port) == IVL_SIP_REF)
		  draw_bind_function_ref_argument(port, ivl_expr_parm(expr, idx));
      }

	/* Call the function */
      const char* scope_name = ivl_scope_name(def);
      if (!scope_name) {
	    fprintf(stderr, "Error: NULL scope name in draw_ufunc_preamble\n");
	    return;
      }
      const char* mangled = vvp_mangle_id(scope_name);
      if (!mangled) {
	    fprintf(stderr, "Error: NULL mangled name for scope %s\n", scope_name);
	    return;
      }
      note_td_reference(mangled);
      unsigned super_call = ivl_expr_is_super_call(expr);
      /* Only dispatch virtually for methods declared with "virtual" keyword. */
      unsigned use_virtual = !super_call && ivl_scope_is_virtual_method(def);

      /* Use the function scope's return type as the authoritative opcode
       * selector. The call-site expression type (ivl_expr_value) can be
       * stale when the called function is in a parameterized class whose
       * type parameter wasn't resolved at the time the default-argument
       * NetEUFunc was elaborated (e.g. trigger(T data=get_default_data())
       * compiled before T was bound to uvm_object). The scope's func_type
       * is set from the return-signal data_type() at dll_target export time,
       * which always reflects the finally-resolved type. */
      ivl_variable_type_t call_type = ivl_expr_value(expr);
      ivl_variable_type_t scope_type = ivl_scope_func_type(def);
      if ((call_type == IVL_VT_LOGIC || call_type == IVL_VT_BOOL)
          && (scope_type == IVL_VT_CLASS || scope_type == IVL_VT_DARRAY
              || scope_type == IVL_VT_QUEUE || scope_type == IVL_VT_NO_TYPE
              || scope_type == IVL_VT_STRING || scope_type == IVL_VT_REAL)) {
	    call_type = scope_type;
      }

	/* A function whose return type is an unpacked array delivers its
	   result through the emitted return-array signal, not through the
	   %ret machinery (which has no array representation). Call it like a
	   void function; the caller copies the words out of the return array
	   after the call, before the callee frame is freed. */
      {
	    ivl_signal_t retsig = ivl_scope_port(def, 0);
	    if (retsig && ivl_signal_dimensions(retsig) > 0)
		  call_type = IVL_VT_VOID;
      }

      switch (call_type) {
	  case IVL_VT_VOID:
	    fprintf(vvp_out, "    %%callf/void%s TD_%s",
		    use_virtual ? "/v" : "", mangled);
	    fprintf(vvp_out, ", S_%p;\n", def);
	    fflush(vvp_out);
	    break;
	  case IVL_VT_REAL:
	    fprintf(vvp_out, "    %%callf/real%s TD_%s",
		    use_virtual ? "/v" : "", mangled);
	    fprintf(vvp_out, ", S_%p;\n", def);
	    fflush(vvp_out);
	    break;
	  case IVL_VT_BOOL:
	  case IVL_VT_LOGIC:
	    fprintf(vvp_out, "    %%callf/vec4%s TD_%s",
		    use_virtual ? "/v" : "", mangled);
	    fprintf(vvp_out, ", S_%p;\n", def);
	    fflush(vvp_out);
	    break;
	  case IVL_VT_STRING:
	    fprintf(vvp_out, "    %%callf/str%s TD_%s",
		    use_virtual ? "/v" : "", mangled);
	    fprintf(vvp_out, ", S_%p;\n", def);
	    fflush(vvp_out);
	    break;
	  case IVL_VT_CLASS:
	  case IVL_VT_DARRAY:
	  case IVL_VT_QUEUE:
	  case IVL_VT_NO_TYPE:
	    fprintf(vvp_out, "    %%callf/obj%s TD_%s",
		    use_virtual ? "/v" : "", mangled);
	    fflush(vvp_out); // Flush immediately in case of crash
	    fprintf(vvp_out, ", S_%p;\n", def);
	    fflush(vvp_out); // Flush immediately in case of crash
	    break;
	  default:
	    fprintf(vvp_out, "    %%fork%s TD_%s",
		    use_virtual ? "/v" : "", mangled);
	    fprintf(vvp_out, ", S_%p;\n", def);
	    fprintf(vvp_out, "    %%join;\n");
	    fflush(vvp_out);
	    break;
      }
}

static void draw_ufunc_epilogue(ivl_expr_t expr)
{
      ivl_scope_t def = ivl_expr_def(expr);

      draw_copy_out_function_arguments(expr);

        /* If this is an automatic function, free the local storage. */
      if (ivl_scope_is_auto(def)) {
            fprintf(vvp_out, "    %%free S_%p;\n", def);
            fflush(vvp_out);
      }
}

/*
 * A call to a user defined function generates a result that is the
 * result of this expression.
 *
 * The result of the function is placed by the function execution into
 * a signal within the scope of the function that also has a basename
 * the same as the function. The ivl_target API handled the result
 * mapping already, and we get the name of the result signal as
 * parameter 0 of the function definition.
 */

void draw_ufunc_vec4(ivl_expr_t expr)
{

	/* Take in arguments to function and call function code. */
      draw_ufunc_preamble(expr);

      draw_ufunc_epilogue(expr);
}

void draw_ufunc_real(ivl_expr_t expr)
{

	/* Take in arguments to function and call the function code. */
      draw_ufunc_preamble(expr);

	/* The %callf/real function emitted by the preamble leaves
	   the result in the stack for us. */

      draw_ufunc_epilogue(expr);
}

void draw_ufunc_string(ivl_expr_t expr)
{

	/* Take in arguments to function and call the function code. */
      draw_ufunc_preamble(expr);

	/* The %callf/str function emitted by the preamble leaves
	   the result in the stack for us. */

      draw_ufunc_epilogue(expr);
}

void draw_ufunc_object(ivl_expr_t expr)
{
      ivl_scope_t def = ivl_expr_def(expr);
      ivl_signal_t retval = ivl_scope_port(def, 0);
      ivl_variable_type_t ret_type = ivl_signal_data_type(retval);
      ivl_variable_type_t want_type = ivl_expr_value(expr);
      const char*def_name = ivl_scope_name(def);
      int force_object_return = 0;
      if (def_name && strstr(def_name, "uvm_queue.get"))
            force_object_return = 1;

	/* Take in arguments to function and call the function code. */
      draw_ufunc_preamble(expr);

      if (ret_type == IVL_VT_CLASS ||
          ret_type == IVL_VT_DARRAY ||
          ret_type == IVL_VT_QUEUE ||
          ret_type == IVL_VT_NO_TYPE ||
          want_type == IVL_VT_CLASS ||
          want_type == IVL_VT_DARRAY ||
          want_type == IVL_VT_QUEUE ||
          want_type == IVL_VT_NO_TYPE ||
          force_object_return) {
	      /* Load object-like return values into the object stack. */
	    fprintf(vvp_out, "    %%load/obj v%p_0;\n", retval);
      } else {
	    /* draw_eval_object() was asked to evaluate a non-object
	     * function result. Drain any leftover call result from
	     * the type stack, then push null-object fallback. */
	    switch (ivl_expr_value(expr)) {
		case IVL_VT_BOOL:
		case IVL_VT_LOGIC:
		  fprintf(vvp_out, "    %%pop/vec4 1;\n");
		  break;
		case IVL_VT_REAL:
		  fprintf(vvp_out, "    %%pop/real 1;\n");
		  break;
		case IVL_VT_STRING:
		  fprintf(vvp_out, "    %%pop/str 1;\n");
		  break;
		default:
		  break;
	    }
	    fprintf(stderr,
		    "Warning: draw_ufunc_object: function %s returns non-object type %d; using null fallback\n",
		    ivl_scope_name(def), ret_type);
	    fprintf(vvp_out, "    %%null; ; non-object ufunc fallback\n");
      }

      draw_ufunc_epilogue(expr);
}

/* Find the rightmost destination-dimension suffix that contains exactly
 * word_count words. An unpacked-array function result can be assigned to a
 * whole array or to a fixed-prefix slice, and the latter is represented by
 * the original signal plus a flat base word. */
static unsigned uarray_suffix_first_dim_(ivl_signal_t sig,
                                         unsigned word_count)
{
      unsigned dims = ivl_signal_dimensions(sig);
      unsigned long long count = 1;
      unsigned dim = dims;

      while (dim > 0) {
            int msb;
            int lsb;
            unsigned long long width;

            dim -= 1;
            msb = ivl_signal_array_dim_msb(sig, dim);
            lsb = ivl_signal_array_dim_lsb(sig, dim);
            width = (msb >= lsb) ? (unsigned long long)(msb-lsb+1)
                                 : (unsigned long long)(lsb-msb+1);
            count *= width;
            if (count == word_count)
                  return dim;
            if (count > word_count)
                  break;
      }

      return dims;
}

/* Convert a left-to-right (declared-order) flat position within a dimension
 * suffix to the canonical low-bound-based word offset used by vvp storage.
 * Decompose from the rightmost dimension because that is the fastest-moving
 * dimension in both orderings. */
static unsigned uarray_decl_to_canonical_(ivl_signal_t sig,
                                          unsigned first_dim,
                                          unsigned declared_pos)
{
      unsigned dim = ivl_signal_dimensions(sig);
      unsigned canonical = 0;
      unsigned stride = 1;

      while (dim > first_dim) {
            int msb;
            int lsb;
            unsigned width;
            unsigned declared_coord;
            unsigned canonical_coord;

            dim -= 1;
            msb = ivl_signal_array_dim_msb(sig, dim);
            lsb = ivl_signal_array_dim_lsb(sig, dim);
            width = (msb >= lsb) ? (unsigned)(msb-lsb+1)
                                 : (unsigned)(lsb-msb+1);
            declared_coord = declared_pos % width;
            declared_pos /= width;
            canonical_coord = (msb > lsb)
                  ? width-1-declared_coord : declared_coord;
            canonical += canonical_coord * stride;
            stride *= width;
      }

      assert(declared_pos == 0);
      return canonical;
}

/*
 * Call a function whose return type is an unpacked array and copy the
 * result into dst_sig starting at flat word dst_base (0 for a whole-array
 * target; a slice target's flat base word otherwise). The preamble calls
 * the function like a void function (see draw_ufunc_preamble); the function
 * body has stored the result words into its emitted return-array signal,
 * which remains readable here because the callee frame is not freed until
 * the epilogue below. Source and destination words are mapped independently
 * through declared order, as required when equivalent-sized ranges have
 * opposite directions (IEEE 1800-2017 7.6).
 */
void draw_ufunc_uarray(ivl_expr_t expr, ivl_signal_t dst_sig,
		       unsigned dst_base)
{
      ivl_scope_t def = ivl_expr_def(expr);
      ivl_signal_t retval = ivl_scope_port(def, 0);
      unsigned word_count = ivl_signal_array_count(retval);
      unsigned dst_first = uarray_suffix_first_dim_(dst_sig, word_count);
      unsigned idx;

      if (dst_first == ivl_signal_dimensions(dst_sig)) {
            fprintf(stderr, "draw_ufunc_uarray: error: return array of %s "
                    "does not match the destination array shape\n",
                    ivl_scope_name(def));
            vvp_errors += 1;
            return;
      }

      draw_ufunc_preamble(expr);

      int ix = allocate_word();
      for (idx = 0 ; idx < word_count ; idx += 1) {
	    unsigned src_word = uarray_decl_to_canonical_(retval, 0, idx);
	    unsigned dst_word = uarray_decl_to_canonical_(dst_sig,
						     dst_first, idx);
	    switch (ivl_signal_data_type(retval)) {
		case IVL_VT_BOOL:
		case IVL_VT_LOGIC:
		  fprintf(vvp_out, "    %%ix/load %d, %u, 0;\n", ix,
			  src_word);
		  fprintf(vvp_out, "    %%load/vec4a v%p, %d;\n", retval, ix);
		  fprintf(vvp_out, "    %%ix/load %d, %u, 0;\n",
			  ix, dst_base + dst_word);
		  fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
		  fprintf(vvp_out, "    %%store/vec4a v%p, %d, 0;\n",
			  dst_sig, ix);
		  break;
		case IVL_VT_REAL:
		  fprintf(vvp_out, "    %%ix/load %d, %u, 0;\n", ix,
			  src_word);
		  fprintf(vvp_out, "    %%load/ar v%p, %d;\n", retval, ix);
		  fprintf(vvp_out, "    %%ix/load %d, %u, 0;\n",
			  ix, dst_base + dst_word);
		  fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
		  fprintf(vvp_out, "    %%store/reala v%p, %d;\n",
			  dst_sig, ix);
		  break;
		case IVL_VT_STRING:
		  fprintf(vvp_out, "    %%ix/load %d, %u, 0;\n", ix,
			  src_word);
		  fprintf(vvp_out, "    %%load/stra v%p, %d;\n", retval, ix);
		  fprintf(vvp_out, "    %%ix/load %d, %u, 0;\n",
			  ix, dst_base + dst_word);
		  fprintf(vvp_out, "    %%flag_set/imm 4, 0;\n");
		  fprintf(vvp_out, "    %%store/stra v%p, %d;\n",
			  dst_sig, ix);
		  break;
		default:
		  fprintf(stderr, "draw_ufunc_uarray: sorry: unsupported "
			  "element type %d for unpacked-array return of %s\n",
			  ivl_signal_data_type(retval), ivl_scope_name(def));
		  break;
	    }
      }
      clr_word(ix);

      draw_ufunc_epilogue(expr);
}

/*
 * Call a function whose result is a one-dimensional fixed unpacked array
 * and materialize that result as dynamic-array storage on the object stack.
 * Array methods on arbitrary expressions use this form: the function's
 * automatic frame must remain live until %load/arr/dar has copied all return
 * words, so the ordinary object-return path cannot be used.
 */
void draw_ufunc_uarray_object(ivl_expr_t expr, int as_queue,
			      unsigned queue_max_size)
{
      ivl_scope_t def = ivl_expr_def(expr);
      ivl_signal_t retval = ivl_scope_port(def, 0);
      ivl_variable_type_t dt = ivl_signal_data_type(retval);
      unsigned wid = ivl_signal_width(retval);
      unsigned kind;
      unsigned count;
      int base;
      int left;

      assert(retval);
      assert(ivl_signal_dimensions(retval) > 0);

      draw_ufunc_preamble(expr);

      if (ivl_signal_dimensions(retval) != 1) {
	    fprintf(stderr, "%s:%u: sorry: an unpacked-array function result "
		    "used as an object must be one-dimensional\n",
		    ivl_expr_file(expr), ivl_expr_lineno(expr));
	    vvp_errors += 1;
	    fprintf(vvp_out, "    %%null; ; multidimensional ufunc array\n");
	    draw_ufunc_epilogue(expr);
	    return;
      }

      switch (dt) {
	  case IVL_VT_REAL:
	    kind = 0;
	    break;
	  case IVL_VT_STRING:
	    kind = VVP_ARRDAR_STRING;
	    break;
	  case IVL_VT_BOOL:
	  case IVL_VT_LOGIC:
	    if (wid == 0) wid = 1;
	    if (wid > VVP_ARRDAR_WIDTH_MAX) {
		  fprintf(stderr, "%s:%u: sorry: fixed-array materialization "
			  "supports integral widths up to %u bits\n",
			  ivl_expr_file(expr), ivl_expr_lineno(expr),
			  VVP_ARRDAR_WIDTH_MAX);
		  vvp_errors += 1;
		  fprintf(vvp_out, "    %%null; ; wide ufunc array\n");
		  draw_ufunc_epilogue(expr);
		  return;
	    }
	    kind = VVP_ARRDAR_WIDTH_KIND(wid)
		 | (ivl_signal_signed(retval) ? VVP_ARRDAR_SIGNED : 0u)
		 | ((dt == IVL_VT_LOGIC) ? VVP_ARRDAR_FOUR : 0u);
	    break;
	  case IVL_VT_CLASS:
	    kind = VVP_ARRDAR_OBJ;
	    break;
	  default:
	    fprintf(stderr, "%s:%u: sorry: unsupported element type %d in "
		    "an unpacked-array function result\n",
		    ivl_expr_file(expr), ivl_expr_lineno(expr), (int)dt);
	    vvp_errors += 1;
	    fprintf(vvp_out, "    %%null; ; unsupported ufunc array\n");
	    draw_ufunc_epilogue(expr);
	    return;
      }

      count = ivl_signal_array_count(retval);
      base = ivl_signal_array_base(retval);
      if (ivl_signal_array_addr_swapped(retval)) {
	    left = base + (int)count - 1;
	    kind |= VVP_ARRDAR_DESC;
      } else {
	    left = base;
      }
	/* A whole queue class property has no signal-backed destination for the
	 * ordinary %store/qobj copy path. Ask the marshaller for a real queue
	 * object so later queue-only mutations remain valid. Other object
	 * contexts intentionally retain dynamic-array storage. */
      if (as_queue)
	    kind |= VVP_ARRDAR_QUEUE;

      note_array_signal_use(retval);
      fprintf(vvp_out, "    %%load/arr/dar v%p, %u, %u;\n",
	      retval, kind, as_queue ? queue_max_size : (unsigned)left);
      draw_ufunc_epilogue(expr);
}
