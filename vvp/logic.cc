/*
 * Copyright (c) 2001-2020 Stephen Williams (steve@icarus.com)
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

# include  "logic.h"
# include  "scalar_event_history.h"
# include  "compile.h"
# include  "bufif.h"
# include  "npmos.h"
# include  "schedule.h"
# include  "delay.h"
# include  "statistics.h"
# include  <iostream>
# include  <cstring>
# include  <cassert>
# include  <cstdlib>

struct vvp_boolean_state {
      vvp_vector4_t input[4];
      uint64_t stamp[4];
      bool dirty;
};

vvp_fun_boolean_::vvp_fun_boolean_(unsigned wid)
{
      net_ = 0;
      for (unsigned idx = 0 ;  idx < 4 ;  idx += 1)
	    input_[idx] = vvp_vector4_t(wid, BIT4_Z);
      __vpiScope*scope = vpip_peek_context_scope();
      if (scope->has_automatic_context()) {
            scope_ = scope;
            context_idx_ = vpip_add_item_to_context(this, scope_);
            history_ = new scalar_event_history(scope_);
      }
}

vvp_fun_boolean_::~vvp_fun_boolean_()
{
}

vvp_boolean_state* vvp_fun_boolean_::state(vvp_context_t context)
{
      auto*value = static_cast<vvp_boolean_state*>(vvp_get_context_item(context, context_idx_));
      for (unsigned port = 0; port < 4; ++port)
            if (const auto*old = history_->previous(context, port, value->stamp[port])) {
                  value->input[port] = old->vector;
                  value->stamp[port] = old->stamp;
            }
      return value;
}

void vvp_fun_boolean_::alloc_instance(vvp_context_t context)
{
      vvp_set_context_item(context, context_idx_, new vvp_boolean_state);
      reset_instance(context);
}

void vvp_fun_boolean_::reset_instance(vvp_context_t context)
{
      auto*value = static_cast<vvp_boolean_state*>(vvp_get_context_item(context, context_idx_));
      for (unsigned port = 0; port < 4; ++port) {
            value->input[port] = input_[port];
            value->stamp[port] = history_->static_stamp(port);
      }
      value->dirty = false;
}

void vvp_fun_boolean_::initialize_instance(vvp_context_t context)
{
      output_->send_vec4(calculate(state(context)->input), context);
}

#ifdef CHECK_WITH_VALGRIND
void vvp_fun_boolean_::free_instance(vvp_context_t context)
{
      delete static_cast<vvp_boolean_state*>(vvp_get_context_item(context, context_idx_));
}
#endif

void vvp_fun_boolean_::update(vvp_context_t context, unsigned port,
      const vvp_vector4_t&bit, uint64_t stamp, unsigned base, bool partial)
{
      auto*value = state(context);
      value->stamp[port] = stamp;
      bool changed;
      if (partial) changed = value->input[port].set_vec(base, bit);
      else {
            changed = !value->input[port].eeq(bit);
            value->input[port] = bit;
      }
      if (!changed) return;
      if (vthread_context_is_initializing(context)) {
            output_->send_vec4(calculate(value->input), context);
      } else {
            value->dirty = true;
            if (!net_) {
                  net_ = output_;
                  schedule_functor(this);
            }
      }
}

void vvp_fun_boolean_::receive(vvp_net_ptr_t ptr, const vvp_vector4_t&bit,
      vvp_context_t source, unsigned base, bool partial)
{
      unsigned port = ptr.port();
      if (scope_) {
            uint64_t stamp = history_->next();
            __vpiScope*source_scope = automatic_event_source_scope_(source, scope_);
            vvp_context_t context = scalar_event_native_context_(source, source_scope, scope_);
            if (context) update(context, port, bit, stamp, base, partial);
            else {
                  for (context = scope_->live_contexts; context; context = vvp_get_next_context(context))
                        if (!source_scope || vthread_recover_stacked_context_for_scope(context, source_scope) == source)
                              update(context, port, bit, stamp, base, partial);
            }
            // Retain raw ancestor operands even before a child activation exists.
            vvp_vector4_t sample = bit;
            if (partial) {
                  sample = input_[port];
                  if (const auto*old = history_->previous(source, port, history_->static_stamp(port)))
                        sample = old->vector;
                  sample.set_vec(base, bit);
            }
            if (!source_scope && !context && stamp >= history_->static_stamp(port))
                  input_[port] = sample;
            history_->remember(source, port, stamp, sample);
            return;
      }
      bool changed;
      if (partial) changed = input_[port].set_vec(base, bit);
      else {
            changed = !input_[port].eeq(bit);
            input_[port] = bit;
      }
      if (changed && !net_) {
            net_ = ptr.ptr();
            schedule_functor(this);
      }
}

void vvp_fun_boolean_::recv_vec4(vvp_net_ptr_t ptr, const vvp_vector4_t&bit,
                                 vvp_context_t context)
{
      receive(ptr, bit, context, 0, false);
}

void vvp_fun_boolean_::recv_vec4_pv(vvp_net_ptr_t ptr, const vvp_vector4_t&bit,
      unsigned base, unsigned vwid, vvp_context_t context)
{
      assert(base + bit.size() <= vwid);
      receive(ptr, bit, context, base, true);
}

void vvp_fun_boolean_::run_run()
{
      vvp_net_t*ptr = net_;
      net_ = nullptr;
      if (!scope_) {
            ptr->send_vec4(calculate(input_), 0);
            return;
      }
      // Queued work belongs to live frame slots, never saved context pointers.
      for (vvp_context_t context = scope_->live_contexts; context; context = vvp_get_next_context(context)) {
            auto*value = state(context);
            if (!value->dirty) continue;
            value->dirty = false;
            output_->send_vec4(calculate(value->input), context);
      }
}

void vvp_fun_boolean_::recv_real(vvp_net_ptr_t ptr, double real,
                                 vvp_context_t ctx)
{
      recv_vec4(ptr, double_to_vector4_LSB(real), ctx);
}

vvp_fun_and::vvp_fun_and(unsigned wid, bool invert)
: vvp_fun_boolean_(wid), invert_(invert)
{
      count_functors_logic += 1;
}

vvp_fun_and::~vvp_fun_and()
{
}

vvp_vector4_t vvp_fun_and::calculate(const vvp_vector4_t input[4]) const
{
      vvp_vector4_t result (input[0]);

      for (unsigned idx = 0 ;  idx < result.size() ;  idx += 1) {
	    vvp_bit4_t bitbit = result.value(idx);
	    for (unsigned pdx = 1 ;  pdx < 4 ;  pdx += 1) {
		  if (input[pdx].size() < idx) {
			bitbit = BIT4_X;
			break;
		  }

		  bitbit = bitbit & input[pdx].value(idx);
	    }

	    if (invert_)
		  bitbit = ~bitbit;
	    result.set_bit(idx, bitbit);
      }

      return result;
}

vvp_fun_equiv::vvp_fun_equiv()
: vvp_fun_boolean_(1)
{
      count_functors_logic += 1;
}

vvp_fun_equiv::~vvp_fun_equiv()
{
}

vvp_vector4_t vvp_fun_equiv::calculate(const vvp_vector4_t input[4]) const
{
      assert(input[0].size() == 1);
      assert(input[1].size() == 1);

      vvp_bit4_t bit = ~(input[0].value(0) ^ input[1].value(0));
      vvp_vector4_t result (1, bit);

      return result;
}

vvp_fun_impl::vvp_fun_impl()
: vvp_fun_boolean_(1)
{
      count_functors_logic += 1;
}

vvp_fun_impl::~vvp_fun_impl()
{
}

vvp_vector4_t vvp_fun_impl::calculate(const vvp_vector4_t input[4]) const
{
      assert(input[0].size() == 1);
      assert(input[1].size() == 1);

      vvp_bit4_t bit = ~input[0].value(0) | input[1].value(0);
      vvp_vector4_t result (1, bit);

      return result;
}

vvp_fun_buf_not_::vvp_fun_buf_not_(unsigned wid)
: input_(wid, BIT4_Z)
{
      net_ = 0;
}

vvp_fun_buf_not_::~vvp_fun_buf_not_()
{
}

void vvp_fun_buf_not_::recv_vec4(vvp_net_ptr_t ptr, const vvp_vector4_t&bit,
                                 vvp_context_t)
{
      if (ptr.port() != 0) return;

      if (input_ .eeq( bit )) return;

      input_ = bit;
      if (net_ == 0) {
	    net_ = ptr.ptr();
	    schedule_functor(this);
      }
}

void vvp_fun_buf_not_::recv_vec4_pv(vvp_net_ptr_t ptr, const vvp_vector4_t&bit,
                                    unsigned base, unsigned vwid, vvp_context_t)
{
      if (ptr.port() != 0) return;

      assert(base + bit.size() <= vwid);

	// Set the input part. If nothing changes, then break.
      bool flag = input_.set_vec(base, bit);
      if (flag == false) return;

      if (net_ == 0) {
	    net_ = ptr.ptr();
	    schedule_functor(this);
      }
}

void vvp_fun_buf_not_::recv_real(vvp_net_ptr_t ptr, double real,
                                 vvp_context_t ctx)
{
      if (ptr.port() != 0) return;

      recv_vec4(ptr, double_to_vector4_LSB(real), ctx);
}

vvp_fun_buf::vvp_fun_buf(unsigned wid)
: vvp_fun_buf_not_(wid)
{
      count_functors_logic += 1;
}

vvp_fun_buf::~vvp_fun_buf()
{
}

/*
 * The buf functor is very simple--change the z bits to x bits in the
 * vector it passes, and propagate the result.
 */
void vvp_fun_buf::run_run()
{
      vvp_net_t*ptr = net_;
      net_ = 0;

      vvp_vector4_t tmp (input_);
      tmp.change_z2x();
      ptr->send_vec4(tmp, 0);
}

vvp_fun_bufz::vvp_fun_bufz()
{
      count_functors_logic += 1;
}

vvp_fun_bufz::~vvp_fun_bufz()
{
}

/*
 * The bufz is similar to the buf device, except that it does not
 * bother translating z bits to x.
 */
void vvp_fun_bufz::recv_vec4(vvp_net_ptr_t ptr, const vvp_vector4_t&bit,
                             vvp_context_t)
{
      if (ptr.port() != 0)
	    return;

      ptr.ptr()->send_vec4(bit, 0);
}

void vvp_fun_bufz::recv_vec4_pv(vvp_net_ptr_t ptr, const vvp_vector4_t&bit,
                                unsigned base, unsigned vwid, vvp_context_t)
{
      if (ptr.port() != 0)
	    return;

      ptr.ptr()->send_vec4_pv(bit, base, vwid, 0);
}

void vvp_fun_bufz::recv_real(vvp_net_ptr_t ptr, double bit,
                             vvp_context_t)
{
      if (ptr.port() != 0)
	    return;

      ptr.ptr()->send_real(bit, 0);
}

void vvp_fun_buft::recv_vec8(vvp_net_ptr_t ptr, const vvp_vector8_t&bit)
{
      if (ptr.port() != 0)
	    return;

      ptr.ptr()->send_vec8(bit);
}

vvp_fun_muxr::vvp_fun_muxr()
: a_(0.0), b_(0.0)
{
      net_ = 0;
      count_functors_logic += 1;
      select_ = SEL_BOTH;
}

vvp_fun_muxr::~vvp_fun_muxr()
{
}

void vvp_fun_muxr::recv_vec4(vvp_net_ptr_t ptr, const vvp_vector4_t&bit,
                             vvp_context_t)
{
	/* The real valued mux can only take in the select as a
	   vector4_t. The muxed data is real. */
      if (ptr.port() != 2)
	    return;

      assert(bit.size() == 1);

      switch (bit.value(0)) {
	  case BIT4_0:
	    if (select_ == SEL_PORT0) return;
	    select_ = SEL_PORT0;
	    break;
	  case BIT4_1:
	    if (select_ == SEL_PORT1) return;
	    select_ = SEL_PORT1;
	    break;
	  default:
	    if (select_ == SEL_BOTH) return;
	    select_ = SEL_BOTH;
      }

      if (net_ == 0) {
	    net_ = ptr.ptr();
	    schedule_functor(this);
      }
}

void vvp_fun_muxr::recv_real(vvp_net_ptr_t ptr, double bit,
                             vvp_context_t)
{
      switch (ptr.port()) {
	  case 0:
	    if (a_ == bit) return;
	    a_ = bit;
	    if (select_ == SEL_PORT1) return; // The other port is selected.
	    break;

	  case 1:
	    if (b_ == bit) return;
	    b_ = bit;
	    if (select_ == SEL_PORT0) return; // The other port is selected.
	    break;

	  default:
	    fprintf(stderr, "Unsupported port type %u.\n", ptr.port());
	    assert(0);
      }

      if (net_ == 0) {
	    net_ = ptr.ptr();
	    schedule_functor(this);
      }
}

void vvp_fun_muxr::run_run()
{
      vvp_net_t*ptr = net_;
      net_ = 0;

      switch (select_) {
	  case SEL_PORT0:
	    ptr->send_real(a_, 0);
	    break;
	  case SEL_PORT1:
	    ptr->send_real(b_, 0);
	    break;
	  default:
	    if (a_ == b_) {
		  ptr->send_real(a_, 0);
	    } else {
		  ptr->send_real(0.0, 0); // Should this be NaN?
	    }
	    break;
      }
}

vvp_fun_muxz::vvp_fun_muxz(unsigned wid)
: a_(wid, BIT4_Z), b_(wid, BIT4_Z)
{
      net_ = 0;
      count_functors_logic += 1;
      select_ = SEL_BOTH;
      has_run_ = false;
}

vvp_fun_muxz::~vvp_fun_muxz()
{
}

void vvp_fun_muxz::recv_vec4(vvp_net_ptr_t ptr, const vvp_vector4_t&bit,
                             vvp_context_t)
{
      switch (ptr.port()) {
	  case 0:
	    if (a_ .eeq(bit) && has_run_) return;
	    a_ = bit;
	    if (select_ == SEL_PORT1) return; // The other port is selected.
	    break;
	  case 1:
	    if (b_ .eeq(bit) && has_run_) return;
	    b_ = bit;
	    if (select_ == SEL_PORT0) return; // The other port is selected.
	    break;
	  case 2:
	    assert(bit.size() == 1);
	    switch (bit.value(0)) {
		case BIT4_0:
		  if (select_ == SEL_PORT0) return;
		  select_ = SEL_PORT0;
		  break;
		case BIT4_1:
		  if (select_ == SEL_PORT1) return;
		  select_ = SEL_PORT1;
		  break;
		default:
		  if (select_ == SEL_BOTH && has_run_) return;
		  select_ = SEL_BOTH;
	    }
	    break;
	  default:
	    return;
      }

      if (net_ == 0) {
	    net_ = ptr.ptr();
	    schedule_functor(this);
      }
}

void vvp_fun_muxz::recv_vec4_pv(vvp_net_ptr_t ptr, const vvp_vector4_t&bit,
				unsigned base, unsigned vwid, vvp_context_t)
{
      assert(base + bit.size() <= vwid);
      bool flag;

      switch (ptr.port()) {
	  case 0:
	    flag = a_.set_vec(base, bit);
	    if (flag == false && has_run_) return;
	    if (select_ == SEL_PORT1) return; // The other port is selected.
	    break;
	  case 1:
	    flag = b_.set_vec(base, bit);
	    if (flag == false && has_run_) return;
	    if (select_ == SEL_PORT0) return; // The other port is selected.
	    break;
	  case 2:
	    assert((base == 0) && (bit.size() == 1));
	    recv_vec4(ptr, bit, 0);
	  default:
	    return;
      }
      if (net_ == 0) {
	    net_ = ptr.ptr();
	    schedule_functor(this);
      }
}

void vvp_fun_muxz::run_run()
{
      has_run_ = true;
      vvp_net_t*ptr = net_;
      net_ = 0;

      switch (select_) {
	  case SEL_PORT0:
	    ptr->send_vec4(a_, 0);
	    break;
	  case SEL_PORT1:
	    ptr->send_vec4(b_, 0);
	    break;
	  default:
	      {
		    unsigned min_size = a_.size();
		    unsigned max_size = min_size;
		    if (b_.size() < min_size)
			  min_size = b_.size();
		    if (b_.size() > max_size)
			  max_size = b_.size();

		    vvp_vector4_t res (max_size);

		    for (unsigned idx = 0 ;  idx < min_size ;  idx += 1) {
			  if (a_.value(idx) == b_.value(idx))
				res.set_bit(idx, a_.value(idx));
			  else
				res.set_bit(idx, BIT4_X);
		    }

		    for (unsigned idx = min_size ;  idx < max_size ;  idx += 1)
			  res.set_bit(idx, BIT4_X);

		    ptr->send_vec4(res, 0);
	      }
	    break;
      }
}

vvp_fun_not::vvp_fun_not(unsigned wid)
: vvp_fun_buf_not_(wid)
{
      count_functors_logic += 1;
}

vvp_fun_not::~vvp_fun_not()
{
}

/*
 * The not functor is very simple--change the z bits to x bits in the
 * vector it passes, and propagate the inverted result.
 */
void vvp_fun_not::run_run()
{
      vvp_net_t*ptr = net_;
      net_ = 0;

      vvp_vector4_t result (input_, true /* invert */);
      ptr->send_vec4(result, 0);
}

vvp_fun_or::vvp_fun_or(unsigned wid, bool invert)
: vvp_fun_boolean_(wid), invert_(invert)
{
      count_functors_logic += 1;
}

vvp_fun_or::~vvp_fun_or()
{
}

vvp_vector4_t vvp_fun_or::calculate(const vvp_vector4_t input[4]) const
{
      vvp_vector4_t result (input[0]);

      for (unsigned idx = 0 ;  idx < result.size() ;  idx += 1) {
	    vvp_bit4_t bitbit = result.value(idx);
	    for (unsigned pdx = 1 ;  pdx < 4 ;  pdx += 1) {
		  if (input[pdx].size() < idx) {
			bitbit = BIT4_X;
			break;
		  }

		  bitbit = bitbit | input[pdx].value(idx);
	    }

	    if (invert_)
		  bitbit = ~bitbit;
	    result.set_bit(idx, bitbit);
      }

      return result;
}

vvp_fun_xor::vvp_fun_xor(unsigned wid, bool invert)
: vvp_fun_boolean_(wid), invert_(invert)
{
      count_functors_logic += 1;
}

vvp_fun_xor::~vvp_fun_xor()
{
}

vvp_vector4_t vvp_fun_xor::calculate(const vvp_vector4_t input[4]) const
{
      vvp_vector4_t result (input[0]);

      for (unsigned idx = 0 ;  idx < result.size() ;  idx += 1) {
	    vvp_bit4_t bitbit = result.value(idx);
	    for (unsigned pdx = 1 ;  pdx < 4 ;  pdx += 1) {
		  if (input[pdx].size() < idx) {
			bitbit = BIT4_X;
			break;
		  }

		  bitbit = bitbit ^ input[pdx].value(idx);
	    }

	    if (invert_)
		  bitbit = ~bitbit;
	    result.set_bit(idx, bitbit);
      }

      return result;
}

/*
 * The parser calls this function to create a logic functor. I allocate a
 * functor, and map the name to the vvp_ipoint_t address for the
 * functor. Also resolve the inputs to the functor.
 */

void compile_functor(char*label, char*type, unsigned width,
		     unsigned ostr0, unsigned ostr1,
		     unsigned argc, struct symb_s*argv)
{
      vvp_net_fun_t* obj = 0;
      bool strength_aware = false;

      if (strcmp(type, "OR") == 0) {
	    obj = new vvp_fun_or(width, false);

      } else if (strcmp(type, "AND") == 0) {
	    obj = new vvp_fun_and(width, false);

      } else if (strcmp(type, "BUF") == 0) {
	    obj = new vvp_fun_buf(width);

      } else if (strcmp(type, "BUFIF0") == 0) {
	    obj = new vvp_fun_bufif(true,false, ostr0, ostr1);
	    strength_aware = true;

      } else if (strcmp(type, "BUFIF1") == 0) {
	    obj = new vvp_fun_bufif(false,false, ostr0, ostr1);
	    strength_aware = true;

      } else if (strcmp(type, "EQUIV") == 0) {
	    obj = new vvp_fun_equiv();

      } else if (strcmp(type, "IMPL") == 0) {
	    obj = new vvp_fun_impl();

      } else if (strcmp(type, "NAND") == 0) {
	    obj = new vvp_fun_and(width, true);

      } else if (strcmp(type, "NOR") == 0) {
	    obj = new vvp_fun_or(width, true);

      } else if (strcmp(type, "NOTIF0") == 0) {
	    obj = new vvp_fun_bufif(true,true, ostr0, ostr1);
	    strength_aware = true;

      } else if (strcmp(type, "NOTIF1") == 0) {
	    obj = new vvp_fun_bufif(false,true, ostr0, ostr1);
	    strength_aware = true;

      } else if (strcmp(type, "BUFT") == 0) {
	    obj = new vvp_fun_buft();

      } else if (strcmp(type, "BUFZ") == 0) {
	    obj = new vvp_fun_bufz();

      } else if (strcmp(type, "MUXR") == 0) {
	    obj = new vvp_fun_muxr;

      } else if (strcmp(type, "MUXZ") == 0) {
	    obj = new vvp_fun_muxz(width);

      } else if (strcmp(type, "CMOS") == 0) {
	    obj = new vvp_fun_cmos();

      } else if (strcmp(type, "NMOS") == 0) {
	    obj = new vvp_fun_pmos(true);

      } else if (strcmp(type, "PMOS") == 0) {
	    obj = new vvp_fun_pmos(false);

      } else if (strcmp(type, "RCMOS") == 0) {
	    obj = new vvp_fun_rcmos();

      } else if (strcmp(type, "RNMOS") == 0) {
	    obj = new vvp_fun_rpmos(true);

      } else if (strcmp(type, "RPMOS") == 0) {
	    obj = new vvp_fun_rpmos(false);

      } else if (strcmp(type, "NOT") == 0) {
	    obj = new vvp_fun_not(width);

      } else if (strcmp(type, "XNOR") == 0) {
	    obj = new vvp_fun_xor(width, true);

      } else if (strcmp(type, "XOR") == 0) {
	    obj = new vvp_fun_xor(width, false);

      } else {
	    yyerror("invalid functor type.");
	    free(type);
	    free(argv);
	    free(label);
	    return;
      }

      free(type);

      assert(argc <= 4);
      vvp_net_t*net = new vvp_net_t;
      net->fun = obj;
      if (auto*boolean = dynamic_cast<vvp_fun_boolean_*>(obj)) boolean->bind_net(net);

      inputs_connect(net, argc, argv);
      free(argv);

	/* If both the strengths are the default strong drive, then
	   there is no need for a specialized driver. Attach the label
	   to this node and we are finished. */
      if (strength_aware || (ostr0 == 6 && ostr1 == 6)) {
	    define_functor_symbol(label, net);
	    free(label);
	    return;
      }

      vvp_net_t*net_drv = new vvp_net_t;
      vvp_net_fun_t*obj_drv = new vvp_fun_drive(ostr0, ostr1);
      net_drv->fun = obj_drv;

	/* Point the gate to the drive node. */
      net->link(vvp_net_ptr_t(net_drv, 0));

      define_functor_symbol(label, net_drv);
      free(label);
}
