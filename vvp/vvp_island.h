#ifndef IVL_vvp_island_H
#define IVL_vvp_island_H
/*
 * Copyright (c) 2008-2026 Stephen Williams (steve@icarus.com)
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
# include  "vvp_net_sig.h"
# include  "symbols.h"
# include  "schedule.h"
# include  <list>
# include  <vector>
# include  <cassert>

/*
* Islands are mutually connected bidirectional meshes that have a
* discipline other than the implicit ddiscipline of the rest of the
* run time.
*
* In the vvp input, an island is created with this record:
*
*    <label> .island ;
*
* The <label> is the name given to the island. Records after this
* build up the contents of the island. Ports are created like this:
*
*    <label> .port <island>, <src> ;
*    <label> .import <island>, <src> ;
*    <label> .export <island> ;
*
* The .port, .import and .export records create I/O, input and output
* ports. The <label> is the name that branches within the island can
* use to link to the port, and the <island> is the label for the
* island. The input and I/O ports have a <src> label that links to the
* source net from the ddiscrete domain.
*
* Branches within the island may only reference labels within the
* island. This keeps the nets of the ocean of digital away from the
* branches of analog within the island.
*/

struct vvp_island_branch;
class vvp_island_port;
class resolv_core;
class __vpiScope;
typedef vvp_sub_pointer_t<vvp_island_branch> vvp_branch_ptr_t;

enum class island_channel { visible, charge };

struct evcd_island_source {
      const __vpiScope*scope = nullptr;
      unsigned base = 0;
      unsigned width = 0;
};

struct evcd_island_endpoint {
      unsigned width;
      unsigned driver_count;
      unsigned pull; // 0 = none, 1 = tri0, 2 = tri1
      resolv_core*resolver = nullptr;
      vvp_branch_ptr_t anchor;
      std::vector<evcd_island_source> sources;
};

struct evcd_island_side {
      vvp_scalar_t value;
      unsigned active = 0;
      bool present = false;
};

class vvp_island  : private vvp_gen_event_s {

    public:
      vvp_island();
      virtual ~vvp_island() override;

      vvp_island(const vvp_island&) = delete;
      vvp_island& operator=(const vvp_island&) = delete;

	// Ports call this method to flag that something happened at
	// the input. The island will use this to create an active
	// event. The run_run() method will then be called by the
	// scheduler to process whatever happened.
      void flag_island();

	// This is the method that is called, eventually, to process
	// whatever happened. The derived island class implements this
	// method to give the island its character.
      virtual void run_island(vvp_net_t*released = nullptr) =0;

        // Support for $countdrivers.
      virtual void count_drivers(vvp_island_port*port, unsigned bit_idx,
                                 unsigned counts[3]) =0;

      virtual bool link_evcd_branches() = 0;
      virtual void evcd_drivers(const evcd_island_endpoint&endpoint,
				const __vpiScope*scope, unsigned bit,
				evcd_island_side sides[2]) const = 0;
      void watch_evcd(vvp_net_t*net);
      void notify_evcd();

    protected:
	// The base class collects a list of all the branches in the
	// island. The derived island class can access this list for
	// scanning the mesh.
      vvp_island_branch*branches_;

    public: /* These methods are used during linking. */

	// Add a port to the island. The key is added to the island
	// ports symbol table.
      void add_port(const char*key, vvp_net_t*net);
	// Add a branch to the island.
      void add_branch(vvp_island_branch*branch, const char*pa, const char*pb);

      vvp_net_t* find_port(const char*key);

	// Call this method when linking is done.
      void compile_cleanup(void);

	// The branch list, for SDF INTERCONNECT lookup at run time.
      vvp_island_branch* branches() const { return branches_; }

      void add_charge_port(vvp_island_port*port);
      bool has_charge_feedback() const { return !charge_ports_.empty(); }

    protected:
      std::vector<vvp_island_port*> charge_ports_;

	// True once ITERATIONS zero-time settle passes at one simulation
	// time exceed the limit: the island then reports the oscillation
	// once (naming its switches), finishes the simulation, and the
	// caller must stop iterating. See #3472.
      bool settle_exceeded(unsigned long iterations);

    private:
      void run_run() override;
      bool flagged_;
      bool settle_reported_;
	// Zero-time settle cap (#3472): consecutive island runs at one
	// simulation time, and the time they were counted at.
      vvp_time64_t settle_time_;
      unsigned long settle_runs_;
      std::vector<vvp_net_t*> evcd_watches_;

    private:
	// During link, the vvp_island keeps these symbol tables for
	// mapping labels local to the island. When linking is done,
	// the compile_cleanup() method removes these tables.
      symbol_map_s<vvp_net_t>*ports_;
      symbol_map_s<vvp_island_branch>*anodes_;
      symbol_map_s<vvp_island_branch>*bnodes_;
};

/*
* An island port is a functor that connects to the ddiscrete
* discipline outside the island. (There is also a vvp_net_t object
* that refers to this port.) When data comes to the port from outside,
* it is collected and saved, and the island is notified. When code
* inside the island sends data out of the island, it uses the "out"
* pointer from the vvp_net_t that refers to this object.
*/

class vvp_island_port  : public vvp_net_fun_t {

    public:
      explicit vvp_island_port(vvp_island*ip);
      ~vvp_island_port() override;

    public: // Implement vvp_net_fun_t methods
      virtual void recv_vec4(vvp_net_ptr_t port, const vvp_vector4_t&bit,
                             vvp_context_t) override;
      virtual void recv_vec4_pv(vvp_net_ptr_t port, const vvp_vector4_t&bit,
				unsigned base, unsigned vwid, vvp_context_t) override;
      virtual void recv_vec8(vvp_net_ptr_t port, const vvp_vector8_t&bit) override;
      virtual void recv_vec8_pv(vvp_net_ptr_t p, const vvp_vector8_t&bit,
				unsigned base, unsigned vwid) override;

	// This is painful, but necessary. If the island is connected
	// to a forced net, we need to rerun the calculations whenever
	// a force/release happens to the net. If run_now is true, we
	// rerun immediately, otherwise we schedule it for the end of
	// the current time slot.
      virtual void force_flag(bool run_now) override;

    public:
      vvp_vector8_t invalue;
      vvp_vector8_t outvalue;
      vvp_vector8_t value;
      vvp_vector8_t charge_value;
      evcd_island_endpoint* evcd = nullptr;

      bool attach_charge_feedback(vvp_net_ptr_t feedback);
      bool send_charge_feedback();
      vvp_vector8_t& resolution_value(island_channel channel)
      { return channel == island_channel::charge ? charge_value : value; }

    public: // SDF INTERCONNECT on an isolated inout port (IEEE 1800
	    // 32.4.4): delayed drivers from the other side of a branch,
	    // keyed by that branch.
      vvp_island* island() const { return island_; }
      void set_injection(island_channel channel, const void*from,
			 const vvp_vector8_t&val);
      using injection_list = std::vector<std::pair<const void*,vvp_vector8_t> >;
      const injection_list& injections(island_channel channel) const
      { return injections_[static_cast<unsigned>(channel)]; }

    private:
      vvp_island*island_;
      vvp_net_ptr_t charge_feedback_;
      vvp_vector8_t charge_sent_;
      injection_list injections_[2];

    public: // Support for $countdrivers.
      inline void count_drivers(unsigned bit_idx, unsigned counts[3])
      {
            island_->count_drivers(this, bit_idx, counts);
      }

    private: // not implemented
      vvp_island_port(const vvp_island_port&);
      vvp_island_port& operator = (const vvp_island_port&);
};

inline vvp_vector8_t island_filter_value(vvp_net_t*net, const vvp_vector8_t&raw)
{
      const vvp_wire_vec8*fil = dynamic_cast<vvp_wire_vec8*>(net->fil);

      if (fil == 0) {
	    return raw;
      } else {
	      // This is painful, but necessary. If the island is
	      // connected to a forced net, then run the input through
	      // the force filter first. The island must used the
	      // forced value for its deliberations.
	    vvp_vector8_t rep;
	    switch (fil->filter_input_vec8(raw, rep)) {
		default:
		case vvp_net_fil_t::PROP:
		  return raw;
		case vvp_net_fil_t::REPL:
		  return rep;
	    }
      }
}

inline vvp_vector8_t island_get_value(vvp_net_t*net)
{
      const auto*fun = static_cast<const vvp_island_port*>(net->fun);
      return island_filter_value(net, fun->invalue);
}

inline vvp_vector8_t island_get_sent_value(vvp_net_t*net)
{
      const vvp_island_port*fun = dynamic_cast<vvp_island_port*>(net->fun);
      return fun->outvalue;
}

extern void island_send_value(vvp_net_t*net, const vvp_vector8_t&val,
			      bool republish);

/* The port's input resolved with its injected drivers, leaving out the
   ones injected by the branch EXCLUDE. */
extern vvp_vector8_t island_get_input(vvp_net_t*net, island_channel channel,
				      const void*exclude = nullptr);

class vvp_fun_intermodpath;
/* Make the tran branch whose inner end is INNER_PORT carry delayed
   values (SDF INTERCONNECT on an inout port). Returns the intermodpath
   for outer->inner (INTO_INNER) or inner->outer, or nil if INNER_PORT is
   not the inner end of a plain whole-width tran. */
extern vvp_fun_intermodpath* island_tran_interconnect(vvp_net_t*inner_port,
						      bool into_inner,
						      unsigned width,
						      vvp_net_t*&path_net);

/*
* Branches are connected together to form a mesh of branches. Each
* endpoint (there are two) connects circularly to other branch
* endpoints that are connected together. This list of endpoints forms
* a node. Thus it is possible for branches to fully specify the mesh
* of the island.
*/

struct vvp_island_branch {
      virtual ~vvp_island_branch();
	// Keep a list of branches in the island.
      vvp_island_branch*next_branch;
	// branch mesh connectivity. There is a pointer for each end
	// that participates in a circular list.
      vvp_sub_pointer_t<vvp_island_branch> link[2];
	// Port connections
      vvp_net_t*a;
      vvp_net_t*b;
	// Source description of the branch (switch kind, file:line, nets)
	// for run-time diagnostics; null when the compiler gave none.
      char*desc = nullptr;
};

static inline vvp_branch_ptr_t next(vvp_branch_ptr_t cur)
{
      vvp_island_branch*ptr = cur.ptr();
      unsigned ab = cur.port();
      return ptr->link[ab];
}

/*
 * This function collects into the conn list all the branch ends
 * that are connected together with the reference branch endpoint
 * cur. All these branch ends together form a "node" of the branch
 * network. (In other words, this does *not* follow the branches.)
 */
extern void island_collect_node(std::list<vvp_branch_ptr_t>&conn, vvp_branch_ptr_t cur);

/*
 * These functions support compile/linking.
 */
extern void compile_island_base(char*label, vvp_island*use_island);
extern vvp_island* compile_find_island(const char*island_name);

extern void compile_island_port_evcd(char*label, char*island, char*src,
				     uint64_t width, uint64_t count,
				     uint64_t pull, char*resolver);
extern void compile_evcd_source(char*port, uint64_t slot, char*scope,
				uint64_t base, uint64_t width);
extern void compile_evcd_component(uint64_t index, uint64_t component,
				   char*signal);
extern void link_evcd_endpoints();
extern void link_evcd_components();
extern vvp_net_t* lookup_evcd_net(const char*label);
extern void input_connect_evcd(vvp_net_t*dest, char*label);

#endif /* IVL_vvp_island_H */
