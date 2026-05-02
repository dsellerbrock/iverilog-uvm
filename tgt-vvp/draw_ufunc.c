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

static void draw_eval_function_argument(ivl_signal_t port, ivl_expr_t expr)
{
      static int warned_unsupported_arg_type = 0;
      static int warned_aggregate_arg_skip = 0;
      ivl_variable_type_t dtype = ivl_signal_data_type(port);
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

static void draw_send_function_argument(ivl_signal_t port)
{
      static int warned_unsupported_send_type = 0;
      static int warned_aggregate_send_skip = 0;
      ivl_variable_type_t dtype = ivl_signal_data_type(port);

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
	    fprintf(vvp_out, "    %%store/obj v%p_0;\n", port);
	    break;
	  case IVL_VT_QUEUE:
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
		case IVL_VT_CLASS:
		case IVL_VT_DARRAY:
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

	    if ((port_type != IVL_SIP_OUTPUT) &&
	        (port_type != IVL_SIP_INOUT))
		  continue;

	    draw_copy_out_function_argument(port, ivl_expr_parm(expr, idx));
      }
}

static void draw_ufunc_preamble(ivl_expr_t expr)
{
      ivl_scope_t def = ivl_expr_def(expr);
      unsigned idx;

        /* If this is an automatic function, allocate the local storage. */
      if (ivl_scope_is_auto(def)) {
            fprintf(vvp_out, "    %%alloc S_%p;\n", def);
      }

	/* Evaluate the expressions and send the results to the
	   function ports. Do this in two passes - evaluate,
	   then send - this avoids the function input variables
	   being overwritten if the same (non-automatic) function
	   is called in one of the expressions. */

      assert(ivl_expr_parms(expr) == (ivl_scope_ports(def)-1));
      for (idx = 0 ;  idx < ivl_expr_parms(expr) ;  idx += 1) {
	    ivl_signal_t port = ivl_scope_port(def, idx+1);
	    draw_eval_function_argument(port, ivl_expr_parm(expr, idx));
      }
      for (idx = ivl_expr_parms(expr) ;  idx > 0 ;  idx -= 1) {
	    ivl_signal_t port = ivl_scope_port(def, idx);
	    draw_send_function_argument(port);
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
