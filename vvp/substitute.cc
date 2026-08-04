/*
 * Copyright (c) 2016-2025 Stephen Williams (steve@icarus.com)
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

# include  "compile.h"
# include  "vvp_net.h"
# include  <cstdlib>
# include  <cstdint>
# include  <limits>
# include  <iostream>
# include  <cassert>


class vvp_fun_substitute : public vvp_net_fun_t {

    public:
      vvp_fun_substitute(unsigned wid, unsigned soff, unsigned swid);
      ~vvp_fun_substitute() override;

      void recv_vec4(vvp_net_ptr_t port, const vvp_vector4_t&bit, vvp_context_t) override;

      void recv_vec4_pv(vvp_net_ptr_t ptr, const vvp_vector4_t&bit,
			unsigned base, unsigned vwid, vvp_context_t ctx) override;

    private:
      unsigned wid_;
      unsigned soff_;
      unsigned swid_;

      vvp_vector4_t val_;
};

vvp_fun_substitute::vvp_fun_substitute(unsigned wid, unsigned soff, unsigned swid)
: wid_(wid), soff_(soff), swid_(swid), val_(wid)
{
      for (unsigned idx = 0 ; idx < val_.size() ; idx += 1)
	    val_.set_bit(idx, BIT4_Z);
}

vvp_fun_substitute::~vvp_fun_substitute()
{
}

void vvp_fun_substitute::recv_vec4(vvp_net_ptr_t port, const vvp_vector4_t&bit,
				   vvp_context_t)
{
      unsigned pdx = port.port();
      assert(pdx <= 1);

      if (pdx == 0) {
	    assert(bit.size() == wid_);

	    for (unsigned idx = 0 ; idx < wid_ ; idx += 1) {
		  if (idx >= soff_ && idx < (soff_+swid_))
			continue;

		  val_.set_bit(idx, bit.value(idx));
	    }

      } else {
	    assert(bit.size() == swid_);

	    for (unsigned idx = 0 ; idx < swid_ ; idx += 1)
		  val_.set_bit(idx+soff_, bit.value(idx));
      }

      port.ptr()->send_vec4(val_, 0);
}

void vvp_fun_substitute::recv_vec4_pv(vvp_net_ptr_t ptr, const vvp_vector4_t&bit,
				      unsigned base, unsigned vwid, vvp_context_t ctx)
{
      recv_vec4_pv_(ptr, bit, base, vwid, ctx);
}

void compile_substitute(char*label, unsigned width,
			unsigned soff, unsigned swidth,
			unsigned argc, struct symb_s*argv)
{
      vvp_fun_substitute*fun = new vvp_fun_substitute(width, soff, swidth);

      vvp_net_t*net = new vvp_net_t;
      net->fun = fun;

      define_functor_symbol(label, net);
      free(label);

      inputs_connect(net, argc, argv);
      free(argv);
}

static bool substitute_base_value(const vvp_vector4_t&bits, bool is_signed,
				  int64_t&value)
{
      if (bits.size() == 0)
	    return false;

      for (unsigned idx = 0; idx < bits.size(); idx += 1) {
	    if (bits.value(idx) != BIT4_0 && bits.value(idx) != BIT4_1)
		  return false;
      }

      const bool negative = is_signed
	    && bits.value(bits.size()-1) == BIT4_1;
      uint64_t low = 0;
      const unsigned low_width = bits.size() < 64 ? bits.size() : 64;
      for (unsigned idx = 0; idx < low_width; idx += 1) {
	    if (bits.value(idx) == BIT4_1)
		  low |= uint64_t(1) << idx;
      }

      if (!negative) {
	    for (unsigned idx = 63; idx < bits.size(); idx += 1) {
		  if (bits.value(idx) == BIT4_1) {
			value = std::numeric_limits<int64_t>::max();
			return true;
		  }
	    }
	    value = static_cast<int64_t>(low);
	    return true;
      }

      if (bits.size() < 64) {
	    low |= ~uint64_t(0) << bits.size();
      } else {
	    for (unsigned idx = 64; idx < bits.size(); idx += 1) {
		  if (bits.value(idx) != BIT4_1) {
			value = std::numeric_limits<int64_t>::min();
			return true;
		  }
	    }
	    if ((low & (uint64_t(1) << 63)) == 0) {
		  value = std::numeric_limits<int64_t>::min();
		  return true;
	    }
      }

      value = static_cast<int64_t>(low);
      return true;
}

class vvp_fun_substitute_var : public vvp_net_fun_t {

    public:
      vvp_fun_substitute_var(unsigned wid, unsigned swid, bool is_signed);
      ~vvp_fun_substitute_var() override;

      void recv_vec4(vvp_net_ptr_t port, const vvp_vector4_t&bit,
		     vvp_context_t) override;
      void recv_vec4_pv(vvp_net_ptr_t port, const vvp_vector4_t&bit,
			unsigned base, unsigned vwid,
			vvp_context_t context) override;

    private:
      void update_(vvp_net_ptr_t port);

      unsigned wid_;
      unsigned swid_;
      bool is_signed_;
      bool base_valid_;
      int64_t base_;
      vvp_vector4_t prior_;
      vvp_vector4_t substitute_;
      vvp_vector4_t base_bits_;
      vvp_vector4_t result_;
};

vvp_fun_substitute_var::vvp_fun_substitute_var(unsigned wid, unsigned swid,
					       bool is_signed)
: wid_(wid), swid_(swid), is_signed_(is_signed), base_valid_(false), base_(0),
  prior_(wid, BIT4_Z), substitute_(swid, BIT4_Z), result_(wid, BIT4_Z)
{
}

vvp_fun_substitute_var::~vvp_fun_substitute_var()
{
}

void vvp_fun_substitute_var::update_(vvp_net_ptr_t port)
{
      vvp_vector4_t next = prior_;
      if (base_valid_
	  && base_ > -static_cast<int64_t>(swid_)
	  && base_ < static_cast<int64_t>(wid_)) {
	    for (unsigned src = 0; src < swid_; src += 1) {
		  const int64_t dst = base_ + static_cast<int64_t>(src);
		  if (dst < 0 || dst >= static_cast<int64_t>(wid_))
			continue;
		  next.set_bit(static_cast<unsigned>(dst), substitute_.value(src));
	    }
      }

      if (result_.eeq(next))
	    return;
      result_ = next;
      port.ptr()->send_vec4(result_, 0);
}

void vvp_fun_substitute_var::recv_vec4(vvp_net_ptr_t port,
				       const vvp_vector4_t&bit,
				       vvp_context_t)
{
      switch (port.port()) {
	  case 0:
	    assert(bit.size() == wid_);
	    prior_ = bit;
	    break;
	  case 1:
	    assert(bit.size() == swid_);
	    substitute_ = bit;
	    break;
	  case 2:
	    base_bits_ = bit;
	    base_valid_ = substitute_base_value(base_bits_, is_signed_, base_);
	    break;
	  default:
	    assert(0);
      }
      update_(port);
}

void vvp_fun_substitute_var::recv_vec4_pv(vvp_net_ptr_t port,
					  const vvp_vector4_t&bit,
					  unsigned base, unsigned vwid,
					  vvp_context_t context)
{
      vvp_vector4_t tmp;
      switch (port.port()) {
	  case 0:
	    assert(vwid == wid_);
	    tmp = prior_;
	    break;
	  case 1:
	    assert(vwid == swid_);
	    tmp = substitute_;
	    break;
	  case 2:
	    tmp = base_bits_.size() == vwid
		  ? base_bits_ : vvp_vector4_t(vwid, BIT4_Z);
	    break;
	  default:
	    assert(0);
      }
      tmp.set_vec(base, bit);
      recv_vec4(port, tmp, context);
}

void compile_substitute_var(char*label, unsigned width,
			    unsigned swidth, bool signed_flag,
			    unsigned argc, struct symb_s*argv)
{
      assert(argc == 3);
      vvp_fun_substitute_var*fun =
	    new vvp_fun_substitute_var(width, swidth, signed_flag);

      vvp_net_t*net = new vvp_net_t;
      net->fun = fun;

      define_functor_symbol(label, net);
      free(label);

      inputs_connect(net, argc, argv);
      free(argv);
}
