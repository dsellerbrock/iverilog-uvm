/*
 * Copyright (c) 2002-2025 Stephen Williams (steve@icarus.com)
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

# include  "vvp_net.h"
# include  "compile.h"
# include  "parse_misc.h"
# include  "symbols.h"
# include  "codes.h"
# include  "ufunc.h"
# include  "vvp_darray.h"
# include  "vvp_net_sig.h"
# include  "vthread.h"
# include  "schedule.h"
#ifdef CHECK_WITH_VALGRIND
# include  "vvp_cleanup.h"
#endif
# include  <cstdlib>
# include  <cstring>
# include  <iostream>
# include  <cassert>
# include  <map>

#ifdef __MINGW32__
#include <windows.h>
#endif

class ufunc_real : public ufunc_core {
   public:
      ufunc_real(unsigned ow, vvp_net_t*ptr,
		 unsigned ninputs, unsigned nports, vvp_net_t**ports,
		 vvp_code_t start_address,
		 __vpiScope*call_scope,
		 char*scope_label,
		 resolver_kind_t resolver_kind = RESOLVER_NONE);
      ~ufunc_real() override;

      void finish_thread() override;
};

class ufunc_vec4 : public ufunc_core {
   public:
      ufunc_vec4(unsigned ow, vvp_net_t*ptr,
		 unsigned ninputs, unsigned nports, vvp_net_t**ports,
		 vvp_code_t start_address,
		 __vpiScope*call_scope,
		 char*scope_label,
		 resolver_kind_t resolver_kind = RESOLVER_NONE);
      ~ufunc_vec4() override;

      void finish_thread() override;
};

ufunc_core::ufunc_core(unsigned owid, vvp_net_t*ptr,
		       unsigned ninputs, unsigned nports, vvp_net_t**ports,
		       vvp_code_t sa, __vpiScope*call_scope__,
		       char*scope_label, resolver_kind_t resolver_kind)
: vvp_wide_fun_core(ptr, ninputs)
{
      owid_ = owid;
      ports_ = ports;
      ports_count_ = nports;
      resolver_kind_ = resolver_kind;
      input_valid_ = new bool[ninputs]();
      resolver_error_reported_ = false;
      code_ = sa;
      thread_ = 0;
      call_scope_ = call_scope__;

	/* A __vpiScope starts with a __vpiHandle structure so this is
	   a safe cast. We need the (void*) to avoid a dereferenced
	   type punned pointer warning from some gcc compilers. */
      compile_vpi_lookup((vpiHandle*)(void*)(&func_scope_), scope_label);
}

ufunc_core::~ufunc_core()
{
      delete [] ports_;
      delete [] input_valid_;
}

/*
 * This method is called by the %exec_ufunc function to prepare the
 * input variables of the function for execution. The method copies
 * the input values collected by the core to the variables.
 */
void ufunc_core::assign_bits_to_ports(vvp_context_t context)
{
      if (resolver_kind_ != RESOLVER_NONE) {
	    assign_resolver_to_port_(context);
	    return;
      }

      assert(port_count() == ports_count_);
      for (unsigned idx = 0 ; idx < ports_count_ ;  idx += 1) {
	    vvp_net_t*net = ports_[idx];
	    vvp_net_ptr_t pp (net, 0);
	    const vvp_vector4_t&tmp_val = value(idx);

	      // A fixed unpacked-array formal is flattened into one input and
	      // one fixed-address array port per word. Store through that port
	      // into the callee's current (possibly automatic) array context.
	    if (vvp_array_port_store(net, tmp_val))
		  continue;

	      // If the port is a real variable, then simply copy the
	      // propagated input to the port variable.
	    if (vvp_fun_signal_real*tmp = dynamic_cast<vvp_fun_signal_real*>(net->fun))
		  tmp->recv_real(pp, value_r(idx), context);

	      // If the port is a bit4 vector, then copy the
	      // propagated input to the port variable. Detect the
	      // special case that the input vector is nil, and
	      // convert that to an 'bx vector that matches the width
	      // of the port variable. This is to handle the uncommon
	      // startup case where the input values have not
	      // propagated useful values yet.
	    if (vvp_fun_signal_vec*tmp = dynamic_cast<vvp_fun_signal_vec*>(net->fun)) {
		  if (tmp_val.size() == 0) {
			const vvp_vector4_t&ref = tmp->vec4_unfiltered_value();
			vvp_vector4_t xxx (ref.size(), BIT4_X);
			tmp->recv_vec4(pp, xxx, context);
		  } else {
			tmp->recv_vec4(pp, tmp_val, context);
		  }
	    }
      }
}

/*
 * A user-defined nettype resolution function receives one dynamic array
 * containing a snapshot of every current driver value. The number of
 * drivers is independent of the function's single formal port, so build the
 * container atomically immediately before the function thread runs.
 */
void ufunc_core::assign_resolver_to_port_(vvp_context_t context)
{
      assert(ports_count_ == 1);

      vvp_net_t*net = ports_[0];
      vvp_fun_signal_object*formal =
	    dynamic_cast<vvp_fun_signal_object*>(net->fun);
      if (!formal) {
	    report_resolver_runtime_error_(
		  "user nettype resolver formal is not a dynamic array");
	    return;
      }

      const unsigned count = port_count();
      vvp_darray*array = 0;
      switch (resolver_kind_) {
	  case RESOLVER_VEC4:
	    array = new vvp_darray_vec4(count, owid_);
	    for (unsigned idx = 0; idx < count; idx += 1) {
		  vvp_vector4_t val = input_valid_[idx]
			? value(idx) : vvp_vector4_t(owid_, BIT4_X);
		  array->set_word(idx, val);
	    }
	    break;

	  case RESOLVER_VEC2:
	    array = new vvp_darray_vec2(count, owid_);
	    for (unsigned idx = 0; idx < count; idx += 1) {
		  vvp_vector4_t val = input_valid_[idx]
			? value(idx) : vvp_vector4_t(owid_, BIT4_0);
		  array->set_word(idx, val);
	    }
	    break;

	  case RESOLVER_REAL:
	    array = new vvp_darray_real(count);
	    for (unsigned idx = 0; idx < count; idx += 1)
		  array->set_word(idx, input_valid_[idx] ? value_r(idx) : 0.0);
	    break;

	  case RESOLVER_NONE:
	    assert(0);
	    break;
      }

      vvp_net_ptr_t port(net, 0);
      formal->recv_object(port, vvp_object_t(array), context);
}

void ufunc_core::report_resolver_runtime_error_(const char*message)
{
      if (!resolver_error_reported_) {
	    fprintf(stderr, "vvp error: %s\n", message);
	    resolver_error_reported_ = true;
      }
      vpip_set_return_value(1);
}

/*
 * This method is called by the %exec_ufunc instruction to copy the
 * result from the return code variable and deliver it to the output
 * of the functor, back into the netlist.
 */
void ufunc_core::finish_thread_real_()
{
      assert(thread_);

      double val = vthread_get_real_stack(thread_, 0);
      vthread_pop_real(thread_, 1);

      propagate_real(val);

      thread_ = 0;
}

void ufunc_core::finish_thread_vec4_()
{
      assert(thread_);

      vvp_vector4_t val = vthread_get_vec4_stack(thread_, 0);
      vthread_pop_vec4(thread_, 1);

      propagate_vec4(val);

      thread_ = 0;
}

/*
 * This method is only called when a trigger event occurs. Just arrange for
 * the function to be called.
 */
void ufunc_core::recv_vec4(vvp_net_ptr_t, const vvp_vector4_t&,
                           vvp_context_t)
{
      invoke_thread_();
}

/*
 * The recv_vec4 methods of the input functors call this to assign the
 * input value to the port of the functor. I save the input value and
 * arrange for the function to be called.
 */
void ufunc_core::recv_vec4_from_inputs(unsigned port)
{
      if (resolver_kind_ == RESOLVER_REAL) {
	    input_valid_[port] = false;
	    report_resolver_runtime_error_(
		  "real user nettype resolver received a vector driver");
	    invoke_thread_();
	    return;
      }
      input_valid_[port] = true;
      invoke_thread_();
}

void ufunc_core::recv_real_from_inputs(unsigned port)
{
      if (resolver_kind_ == RESOLVER_VEC4 || resolver_kind_ == RESOLVER_VEC2) {
	    input_valid_[port] = false;
	    report_resolver_runtime_error_(
		  "vector user nettype resolver received a real driver");
	    invoke_thread_();
	    return;
      }
      input_valid_[port] = true;
      invoke_thread_();
}

void ufunc_core::invoke_thread_()
{
      if (thread_ == 0) {
	    thread_ = vthread_new(code_, call_scope_);
	    schedule_vthread(thread_, 0);
      }
}

ufunc_vec4::ufunc_vec4(unsigned ow, vvp_net_t*ptr,
		       unsigned ninputs, unsigned nports, vvp_net_t**ports,
		       vvp_code_t start_address,
		       __vpiScope*call_scope_in,
		       char*scope_label, resolver_kind_t resolver_kind)
: ufunc_core(ow, ptr, ninputs, nports, ports, start_address, call_scope_in,
	     scope_label, resolver_kind)
{
}

ufunc_vec4::~ufunc_vec4()
{
}

void ufunc_vec4::finish_thread()
{
      finish_thread_vec4_();
}

ufunc_real::ufunc_real(unsigned ow, vvp_net_t*ptr,
		       unsigned ninputs, unsigned nports, vvp_net_t**ports,
		       vvp_code_t start_address,
		       __vpiScope*call_scope_in,
		       char*scope_label, resolver_kind_t resolver_kind)
: ufunc_core(ow, ptr, ninputs, nports, ports, start_address, call_scope_in,
	     scope_label, resolver_kind)
{
}

ufunc_real::~ufunc_real()
{
}

void ufunc_real::finish_thread()
{
      finish_thread_real_();
}

/*
 * This function compiles the .ufunc statement that is discovered in
 * the source file. Create all the functors and the thread, and
 * connect them all up.
 *
 * The argv list is a list of the inputs to the function.
 *
 * The portv list is a list of variables that the function reads as
 * inputs. The core assigns values to these nets as part of the startup.
 */
void compile_ufunc_real(char*label, char*code, unsigned wid,
		   unsigned argc,  struct symb_s*argv,
		   unsigned portc, struct symb_s*portv,
		   char*scope_label, char*trigger_label)
{
	/* The input argument list and port list must have the same
	   sizes, since internally we will be mapping the inputs list
	   to the ports list. */
      assert(argc == portc);

      __vpiScope*call_scope = vpip_peek_current_scope();
      assert(call_scope);

	/* Construct some phantom code that is the thread of the
	   function call. The first instruction, at the start_address
	   of the function, loads the ports and calls the function.
	   The second instruction collects the function result. The
	   last instruction is the usual %end. So the thread looks
	   like this:

	      %exec_ufunc/real <core>;
	      %reap_ufunc;
	      %end;

	   The %exec_ufunc copies the input values into local regs
           and runs the function code. The %reap_ufunc then copies
	   the output value to the destination net functor. */

      vvp_code_t exec_code = codespace_allocate();
      exec_code->opcode = of_EXEC_UFUNC_REAL;
      code_label_lookup(exec_code, code, false);

      vvp_code_t reap_code = codespace_allocate();
      reap_code->opcode = of_REAP_UFUNC;

      vvp_code_t end_code = codespace_allocate();
      end_code->opcode = &of_END;

	/* Run through the function ports (which are related to but
	   not the same as the input ports) and arrange for their
	   binding. */
      vvp_net_t**ports = new vvp_net_t*[portc];
      for (unsigned idx = 0 ;  idx < portc ;  idx += 1) {
	    functor_ref_lookup(&ports[idx], portv[idx].text);
      }

	/* Create the output functor and attach it to the label. Tell
	   it about the start address of the code stub, and the scope
	   that will contain the execution. */
      vvp_net_t*ptr = new vvp_net_t;
      ufunc_core*fcore = new ufunc_real(wid, ptr, argc, portc, ports,
					exec_code, call_scope,
					scope_label);
      ptr->fun = fcore;
      define_functor_symbol(label, ptr);
      free(label);

      exec_code->ufunc_core_ptr = fcore;
      reap_code->ufunc_core_ptr = fcore;

      wide_inputs_connect(fcore, argc, argv);

        /* If this function has a trigger event, connect the functor to
           that event. */
      if (trigger_label)
            input_connect(ptr, 0, trigger_label);

      free(argv);
      free(portv);
}

void compile_ufunc_vec4(char*label, char*code, unsigned wid,
		   unsigned argc,  struct symb_s*argv,
		   unsigned portc, struct symb_s*portv,
		   char*scope_label, char*trigger_label)
{
	/* The input argument list and port list must have the same
	   sizes, since internally we will be mapping the inputs list
	   to the ports list. */
      assert(argc == portc);

      __vpiScope*call_scope = vpip_peek_current_scope();
      assert(call_scope);

	/* Construct some phantom code that is the thread of the
	   function call. The first instruction, at the start_address
	   of the function, loads the ports and calls the function.
	   The second instruction collects the function result. The
	   last instruction is the usual %end. So the thread looks
	   like this:

	      %exec_ufunc/vec4 <core>;
	      %reap_ufunc;
	      %end;

	   The %exec_ufunc copies the input values into local regs
           and runs the function code. The %reap_ufunc then copies
	   the output value to the destination net functor. */

      vvp_code_t exec_code = codespace_allocate();
      exec_code->opcode = of_EXEC_UFUNC_VEC4;
      code_label_lookup(exec_code, code, false);

      vvp_code_t reap_code = codespace_allocate();
      reap_code->opcode = of_REAP_UFUNC;

      vvp_code_t end_code = codespace_allocate();
      end_code->opcode = &of_END;

	/* Run through the function ports (which are related to but
	   not the same as the input ports) and arrange for their
	   binding. */
      vvp_net_t**ports = new vvp_net_t*[portc];
      for (unsigned idx = 0 ;  idx < portc ;  idx += 1) {
	    functor_ref_lookup(&ports[idx], portv[idx].text);
      }

	/* Create the output functor and attach it to the label. Tell
	   it about the start address of the code stub, and the scope
	   that will contain the execution. */
      vvp_net_t*ptr = new vvp_net_t;
      ufunc_core*fcore = new ufunc_vec4(wid, ptr, argc, portc, ports,
					exec_code, call_scope,
					scope_label);
      ptr->fun = fcore;
      define_functor_symbol(label, ptr);
      free(label);

      exec_code->ufunc_core_ptr = fcore;
      reap_code->ufunc_core_ptr = fcore;

      wide_inputs_connect(fcore, argc, argv);

        /* If this function has a trigger event, connect the functor to
           that event. */
      if (trigger_label)
            input_connect(ptr, 0, trigger_label);

      free(argv);
      free(portv);
}

static void compile_ufunc_resolver_(char*label, char*code, unsigned wid,
		   unsigned argc, struct symb_s*argv,
		   unsigned portc, struct symb_s*portv,
		   char*scope_label,
		   ufunc_core::resolver_kind_t resolver_kind)
{
	/* A resolver always has one dynamic-array formal, but its input list
	 * contains one signal for every current driver. Reject malformed VVP
	 * records before binding or otherwise consuming either symbol list. */
      if (argc == 0 || portc != 1) {
	    yyerror(".ufunc/resolv requires at least one driver and exactly one formal");
	    compile_errors += 1;
	    for (unsigned idx = 0; idx < argc; idx += 1)
		  free(argv[idx].text);
	    for (unsigned idx = 0; idx < portc; idx += 1)
		  free(portv[idx].text);
	    free(label);
	    free(code);
	    free(argv);
	    free(portv);
	    free(scope_label);
	    return;
      }
      if (wid == 0 && resolver_kind != ufunc_core::RESOLVER_REAL) {
	    yyerror(".ufunc/resolv vector element width must be nonzero");
	    compile_errors += 1;
	    for (unsigned idx = 0; idx < argc; idx += 1)
		  free(argv[idx].text);
	    for (unsigned idx = 0; idx < portc; idx += 1)
		  free(portv[idx].text);
	    free(label);
	    free(code);
	    free(argv);
	    free(portv);
	    free(scope_label);
	    return;
      }

      __vpiScope*call_scope = vpip_peek_current_scope();
      assert(call_scope);

      vvp_code_t exec_code = codespace_allocate();
      const bool real_result = resolver_kind == ufunc_core::RESOLVER_REAL;
      exec_code->opcode = real_result ? of_EXEC_UFUNC_REAL
				      : of_EXEC_UFUNC_VEC4;
      code_label_lookup(exec_code, code, false);

      vvp_code_t reap_code = codespace_allocate();
      reap_code->opcode = of_REAP_UFUNC;

      vvp_code_t end_code = codespace_allocate();
      end_code->opcode = &of_END;

      vvp_net_t**ports = new vvp_net_t*[1];
      functor_ref_lookup(&ports[0], portv[0].text);

      vvp_net_t*ptr = new vvp_net_t;
      ufunc_core*fcore;
      if (real_result)
	    fcore = new ufunc_real(wid, ptr, argc, 1, ports, exec_code,
				   call_scope, scope_label, resolver_kind);
      else
	    fcore = new ufunc_vec4(wid, ptr, argc, 1, ports, exec_code,
				   call_scope, scope_label, resolver_kind);

      ptr->fun = fcore;
      define_functor_symbol(label, ptr);
      free(label);

      exec_code->ufunc_core_ptr = fcore;
      reap_code->ufunc_core_ptr = fcore;
      wide_inputs_connect(fcore, argc, argv);

      free(argv);
      free(portv);
}

void compile_ufunc_resolver_vec4(char*label, char*code, unsigned wid,
		   unsigned argc, struct symb_s*argv,
		   unsigned portc, struct symb_s*portv,
		   char*scope_label, bool two_state)
{
      compile_ufunc_resolver_(label, code, wid, argc, argv, portc, portv,
			      scope_label, two_state
				? ufunc_core::RESOLVER_VEC2
				: ufunc_core::RESOLVER_VEC4);
}

void compile_ufunc_resolver_real(char*label, char*code, unsigned wid,
		   unsigned argc, struct symb_s*argv,
		   unsigned portc, struct symb_s*portv,
		   char*scope_label)
{
      compile_ufunc_resolver_(label, code, wid, argc, argv, portc, portv,
			      scope_label, ufunc_core::RESOLVER_REAL);
}
#ifdef CHECK_WITH_VALGRIND
static std::map<ufunc_core*, bool> ufunc_map;

void exec_ufunc_delete(vvp_code_t euf_code)
{
      ufunc_map[euf_code->ufunc_core_ptr] = true;
}

void ufunc_pool_delete(void)
{
      std::map<ufunc_core*, bool>::iterator iter;
      for (iter = ufunc_map.begin(); iter != ufunc_map.end(); ++ iter ) {
	    delete iter->first;
      }
}
#endif
