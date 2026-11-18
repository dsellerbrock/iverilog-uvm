#ifndef IVL_resolv_H
#define IVL_resolv_H
/*
 * Copyright (c) 2001-2025 Stephen Williams (steve@icarus.com)
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

# include  "config.h"
# include  "vvp_net.h"
# include  <vector>

/*
 * Resolver nodes are similar to wide functors, in that they may have
 * more than 4 inputs. Unlike wide functors, the functor that provides
 * the core functionality and delivers the output is also used to handle
 * the first 4 inputs, thus each resolver node is implemented by N/4
 * actual functors.
 */

class resolv_core : public vvp_net_fun_t {

    public:
      explicit resolv_core(unsigned nports, vvp_net_t*net);
      virtual ~resolv_core() override;

      void recv_vec4(vvp_net_ptr_t port, const vvp_vector4_t&bit,
                     vvp_context_t) override
            { recv_vec4_(port.port(), bit); }

      void recv_vec8(vvp_net_ptr_t port, const vvp_vector8_t&bit) override
            { recv_vec8_(port.port(), bit); }

      void recv_vec4_pv(vvp_net_ptr_t port, const vvp_vector4_t&bit,
			unsigned base, unsigned vwid, vvp_context_t) override
            { recv_vec4_pv_(port.port(), bit, base, vwid); }

      void recv_vec8_pv(vvp_net_ptr_t port, const vvp_vector8_t&bit,
			unsigned base, unsigned vwid) override
            { recv_vec8_pv_(port.port(), bit, base, vwid); }

      virtual void count_drivers(unsigned bit_idx, unsigned counts[3]) =0;

      void set_input_source(unsigned port, vvp_net_t*source);
      vvp_net_t* input_source(unsigned port) const
            { return input_sources_[port]; }
      unsigned port_count() const { return nports_; }
	// An empty resolver of the same kind and size, driving net, and
	// the value last received on one of this resolver's ports, sent to
	// dest. Together they copy a resolver for one load (IEEE 1800-2023
	// 32.4.4 source/load interconnect delays on multisource nets).
      virtual resolv_core* clone_empty(vvp_net_t*net) const =0;
      virtual void replay_input(unsigned port, vvp_net_ptr_t dest) const =0;
      bool sole_part_pv_source(unsigned bit, const vvp_net_t*source,
                               unsigned source_port) const;
      vvp_net_t* output_net() const { return net_; }

      void enable_driver_activity_notifications()
            { notify_driver_activity_ = true; }

    private:
      friend class resolv_extend;
      virtual void recv_vec4_(unsigned port, const vvp_vector4_t&bit) =0;
      virtual void recv_vec8_(unsigned port, const vvp_vector8_t&bit) =0;

      void recv_vec4_pv_(unsigned port, const vvp_vector4_t&bit,
			 unsigned base, unsigned vwid);
      void recv_vec8_pv_(unsigned port, const vvp_vector8_t&bit,
			 unsigned base, unsigned vwid);

    protected:
      void notify_driver_activity();
      unsigned nports_;
      vvp_net_t*net_;
      bool notify_driver_activity_;
      std::vector<vvp_net_t*> input_sources_;
};

class resolv_extend : public vvp_net_fun_t {

    public:
      resolv_extend(resolv_core*core, unsigned port_base);
      ~resolv_extend() override;

      void recv_vec4(vvp_net_ptr_t port, const vvp_vector4_t&bit,
                     vvp_context_t) override
            { core_->recv_vec4_(port_base_ + port.port(), bit); }

      void recv_vec8(vvp_net_ptr_t port, const vvp_vector8_t&bit) override
            { core_->recv_vec8_(port_base_ + port.port(), bit); }

      void recv_vec4_pv(vvp_net_ptr_t port, const vvp_vector4_t&bit,
			unsigned base, unsigned vwid, vvp_context_t) override
            { core_->recv_vec4_pv_(port_base_ + port.port(), bit,
                                   base, vwid); }

      void recv_vec8_pv(vvp_net_ptr_t port, const vvp_vector8_t&bit,
			unsigned base, unsigned vwid) override
            { core_->recv_vec8_pv_(port_base_ + port.port(), bit,
                                   base, vwid); }

      void set_input_source(unsigned port, vvp_net_t*source)
            { core_->set_input_source(port_base_ + port, source); }
      resolv_core* core() const { return core_; }
      unsigned core_port(unsigned port) const { return port_base_ + port; }

    private:
      resolv_core*core_;
      unsigned port_base_;
};

/*
 * This functor type resolves its inputs using the Verilog method of
 * combining signals, and outputs that resolved value. The puller
 * value is also blended with the result. This helps with the
 * implementation of tri0 and tri1, which have pull constants
 * attached.
 *
 * This node takes in vvp_vector8_t values, and emits a vvp_vector8_t
 * value. It also takes in vvp_vector4_t values, which it treats as
 * strong values (or HiZ) for the sake of resolution. In any case, the
 * propagated value is a vvp_vector8_t value.
 */
class resolv_tri : public resolv_core {

    public:
      explicit resolv_tri(unsigned nports, vvp_net_t*net,
                          vvp_scalar_t hiz_value);
      ~resolv_tri() override;

      void count_drivers(unsigned bit_idx, unsigned counts[3]) override;
      bool is_plain_tri() const { return hiz_value_.is_hiz(); }
      resolv_core* clone_empty(vvp_net_t*net) const override
            { return new resolv_tri(nports_, net, hiz_value_); }
      void replay_input(unsigned port, vvp_net_ptr_t dest) const override;

    private:
      void recv_vec4_(unsigned port, const vvp_vector4_t&bit) override;
      void recv_vec8_(unsigned port, const vvp_vector8_t&bit) override;

    private:
      struct strength_summary;
        // The implicit pull driver for tri0/tri1, or HiZ for a plain net.
      vvp_scalar_t hiz_value_;
      vvp_vector8_t*val_;
      std::vector<strength_summary>*branches_;
      vvp_vector8_t out_;
};

/*
 * This functor resolves inputs with the wired AND or OR logic selected
 * by each derived class.
 *
 * This node retains strengths on its inputs and output. Four-state
 * inputs are treated as strong (or high impedance).
 */
class resolv_wired_logic : public resolv_core {

    public:
      explicit resolv_wired_logic(unsigned nports, vvp_net_t*net);
      virtual ~resolv_wired_logic() override;

      void count_drivers(unsigned bit_idx, unsigned counts[3]) override;
      void replay_input(unsigned port, vvp_net_ptr_t dest) const override;

    protected:
      virtual bool wired_or_() const =0;

    private:
      void recv_vec4_(unsigned port, const vvp_vector4_t&bit) override;
      void recv_vec8_(unsigned port, const vvp_vector8_t&bit) override;

    private:
        // The array of input values.
      vvp_vector8_t*val_;
};

class resolv_triand : public resolv_wired_logic {

    public:
      explicit resolv_triand(unsigned nports, vvp_net_t*net);
      ~resolv_triand() override;
      resolv_core* clone_empty(vvp_net_t*net) const override
            { return new resolv_triand(nports_, net); }

    private:
      bool wired_or_() const override { return false; }
};

class resolv_trior : public resolv_wired_logic {

    public:
      explicit resolv_trior(unsigned nports, vvp_net_t*net);
      ~resolv_trior() override;
      resolv_core* clone_empty(vvp_net_t*net) const override
            { return new resolv_trior(nports_, net); }

    private:
      bool wired_or_() const override { return true; }
};

/*
 * The charge storage of a trireg net (IEEE 1800-2023 6.6.4, 28.15.2,
 * 28.16.2). It sits between the resolved drivers of the net and the net
 * itself (or the tran island port of the net).
 *
 *   port 0  the resolved value of the drivers of the net
 *   port 1  the final value of the net when it is in a tran island
 *           (the output of its island port); unused otherwise
 *   port 2  the charge decay time when it is not a constant
 *   port 3  the time-zero kick that sends the initial value
 *
 * Each bit is on its own. A driver bit that is not z is passed on with
 * its strength (driven state). When the driver bit is z the output is the
 * stored bit at the charge strength (capacitive state); z never gets
 * through. The stored bit starts as x (6.7.1) and follows the value of
 * the net: the last driven value, or, in a tran island, what the island
 * resolves, so that charge moves from a larger trireg to a smaller one
 * and two of equal size with different values both go to x (6.6.4.1).
 *
 * With a decay time, a stored 0 or 1 becomes x that long after the bit
 * started to hold its own charge, unless the bit was driven again in
 * between (28.16.2.1). A bit holds its own charge when it has no driver
 * and, in an island, the island gives it back exactly what it put in.
 */
class vvp_fun_trireg : public vvp_net_fun_t {

    public:
      vvp_fun_trireg(vvp_net_t*net, unsigned wid, unsigned charge,
		     bool has_decay, vvp_time64_t decay, bool has_feedback);
      ~vvp_fun_trireg() override;

      void recv_vec4(vvp_net_ptr_t port, const vvp_vector4_t&bit,
		     vvp_context_t context) override;
      void recv_vec8(vvp_net_ptr_t port, const vvp_vector8_t&bit) override;
      void recv_real(vvp_net_ptr_t port, double bit,
		     vvp_context_t context) override;

	// Called by the decay event: BITS are (bit, generation) pairs.
      void decay(const std::vector<std::pair<unsigned,unsigned> >&bits);

    private:
      void update_();

      vvp_net_t*net_;
      unsigned wid_;
      unsigned charge_;
      bool has_decay_;
      vvp_time64_t decay_;
      bool has_feedback_;
	// Scale factors for a decay time that arrives on port 2.
      vvp_time64_t round_, scale_;

      vvp_vector8_t drv_;	// port 0
      vvp_vector8_t fb_;	// port 1
      vvp_vector8_t out_;	// last value sent
      vvp_vector4_t store_;	// the stored charge
	// Per bit: whether it holds its own charge, and a counter that
	// changes whenever that stops, so a pending decay can tell.
      std::vector<bool> hold_;
      std::vector<unsigned> gen_;
};

#endif /* IVL_resolv_H */
