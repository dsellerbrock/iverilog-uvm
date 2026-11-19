/*
 * Copyright (c) 2008-2025 Stephen Williams (steve@icarus.com)
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

# include  "vvp_island.h"
# include  "compile.h"
# include  "symbols.h"
# include  "schedule.h"
# include  "config.h"
# include  "vpi_priv.h"
# include  "part.h"
# include  "resolv.h"
#ifdef CHECK_WITH_VALGRIND
# include  "vvp_cleanup.h"
#endif
# include  <iostream>
# include  <algorithm>
# include  <list>
# include  <cassert>
# include  <cstdlib>
# include  <cstring>
# include  <set>
# include "ivl_alloc.h"

using namespace std;

#ifdef CHECK_WITH_VALGRIND
static bool at_EOS = false;
#endif

void island_send_value(vvp_net_t*net, const vvp_vector8_t&val, bool republish)
{
      vvp_island_port*fun = dynamic_cast<vvp_island_port*>(net->fun);
      if (!republish && fun->outvalue.eeq(val))
	    return;

      fun->outvalue = val;
      net->send_vec8(fun->outvalue);
}

vvp_vector8_t island_get_input(vvp_net_t*net, island_channel channel,
				const void*exclude)
{
      const vvp_island_port*fun = dynamic_cast<vvp_island_port*>(net->fun);
      vvp_vector8_t val = channel == island_channel::charge
	    ? fun->invalue : island_get_value(net);
      for (const auto&inj : fun->injections(channel)) {
	    if (inj.first == exclude || inj.second.size() == 0)
		  continue;
	    if (val.size() == 0)
		  val = inj.second;
	    else if (val.size() == inj.second.size())
		  val = resolve(val, inj.second);
      }
      return val;
}

void vvp_island_port::set_injection(island_channel channel, const void*from,
				    const vvp_vector8_t&val)
{
      auto&injections = injections_[static_cast<unsigned>(channel)];
      for (auto&inj : injections) {
	    if (inj.first != from)
		  continue;
	    if (inj.second.eeq(val))
		  return;
	    inj.second = val;
	    island_->flag_island();
	    return;
      }
      injections.push_back(std::make_pair(from, val));
      island_->flag_island();
}

void vvp_island::add_charge_port(vvp_island_port*port)
{
      charge_ports_.push_back(port);
}

bool vvp_island_port::attach_charge_feedback(vvp_net_ptr_t feedback)
{
      if (charge_feedback_.ptr())
	    return false;
      charge_feedback_ = feedback;
      island_->add_charge_port(this);
      return true;
}

bool vvp_island_port::send_charge_feedback()
{
      if (charge_value.size() == 0 || charge_value.eeq(charge_sent_))
	    return false;

      charge_sent_ = charge_value;
      vvp_vector8_t before = invalue;
      charge_feedback_.ptr()->fun->recv_vec8(charge_feedback_, charge_sent_);
      return !invalue.eeq(before);
}

/*
 * Implementations...
 */
vvp_island::vvp_island()
{
      flagged_ = false;
      settle_time_ = 0;
      settle_runs_ = 0;
      settle_reported_ = false;
      branches_ = 0;
      ports_ = 0;
      anodes_ = 0;
      bnodes_ = 0;
}

vvp_island::~vvp_island()
{
	// We can only delete islands at the end of simulation.
#ifdef CHECK_WITH_VALGRIND
      if (!at_EOS) assert(0);
#endif

      while (branches_) {
	    vvp_island_branch *next_br = branches_->next_branch;
	    delete branches_;
	    branches_ = next_br;
      }
}

void vvp_island::flag_island()
{
      if (flagged_ == true)
	    return;

      schedule_generic(this, 0, false, false);
      flagged_ = true;
}

/*
* This method handles the callback from the scheduler. It does basic
* housecleaning and calls the run_island() method implemented by the
* derived class.
*/
/*
 * IEEE 1800-2023 28.8 does not forbid a switch whose control is a net it
 * connects, and such a network can have no fixed point (the stronger side
 * drives the control off, the weaker driver turns it back on). The island
 * then re-runs forever in zero time. Count consecutive runs at one
 * simulation time and stop with a named error past a limit (user ruling
 * 2026-11-16, #3472). Default 10000; +vvp-settle-limit=N sets it. A network
 * that settles in fewer runs is unaffected.
 */
static unsigned long island_settle_limit_(void)
{
      static unsigned long limit = 0;
      if (limit != 0)
	    return limit;
      limit = 10000;
      s_vpi_vlog_info info;
      if (!vpi_get_vlog_info(&info))
	    return limit;
      static const char prefix[] = "+vvp-settle-limit=";
      for (int idx = 0 ; idx < info.argc ; idx += 1) {
	    const char*arg = info.argv[idx];
	    if (!arg || strncmp(arg, prefix, sizeof prefix - 1) != 0)
		  continue;
	    char*end = 0;
	    unsigned long val = strtoul(arg + sizeof prefix - 1, &end, 10);
	    if (end && *end == 0 && end != arg + sizeof prefix - 1 && val > 0)
		  limit = val;
	    else
		  cerr << "warning: ignoring " << arg
		       << ": the settle limit must be a positive integer." << endl;
      }
      return limit;
}

bool vvp_island::settle_exceeded(unsigned long iterations)
{
      unsigned long limit = island_settle_limit_();
      if (iterations <= limit)
	    return false;
      if (!settle_reported_) {
	    settle_reported_ = true;
	    cerr << "runtime error: tran island oscillates at time "
		 << schedule_simtime() << ": no fixed point after " << limit
		 << " zero-time iterations (limit set by +vvp-settle-limit=N)."
		 << " Switches:" << endl;
	    for (vvp_island_branch*br = branches_ ; br ; br = br->next_branch)
		  if (br->desc)
			cerr << "  " << br->desc << endl;
	    vpip_set_return_value(1);
	    if (!schedule_finished())
		  schedule_finish(0);
      }
      return true;
}

void vvp_island::run_run()
{
      flagged_ = false;

      vvp_time64_t now = schedule_simtime();
      if (now != settle_time_) {
	    settle_time_ = now;
	    settle_runs_ = 0;
      }
      settle_runs_ += 1;
      if (settle_exceeded(settle_runs_))
	    return;
      run_island();
      notify_evcd();
}

void vvp_island::watch_evcd(vvp_net_t*net)
{
      if (std::find(evcd_watches_.begin(), evcd_watches_.end(), net) ==
	  evcd_watches_.end())
	    evcd_watches_.push_back(net);
}

void vvp_island::notify_evcd()
{
      for (vvp_net_t*net : evcd_watches_)
	    net->fil->notify_driver_activity();
}


void vvp_island::add_port(const char*key, vvp_net_t*net)
{
      if (ports_ == 0)
	    ports_ = new symbol_map_s<vvp_net_t>;

	// each port should have a unique label
      assert(ports_->sym_get_value(key) == 0);

      ports_->sym_set_value(key, net);
}

void vvp_island::add_branch(vvp_island_branch*branch, const char*pa, const char*pb)
{
      vvp_island_branch*cur;
      assert(ports_);
      branch->a = ports_->sym_get_value(pa);
      branch->b = ports_->sym_get_value(pb);
      assert(branch->a && branch->b);

      vvp_branch_ptr_t ptra (branch, 0);
      vvp_branch_ptr_t ptrb (branch, 1);
      if (anodes_ == 0)
	    anodes_ = new symbol_map_s<vvp_island_branch>;
      if (bnodes_ == 0)
	    bnodes_ = new symbol_map_s<vvp_island_branch>;

      if ((cur = anodes_->sym_get_value(pa))) {
	    branch->link[0] = cur->link[0];
	    cur->link[0] = ptra;
      } else if ((cur = bnodes_->sym_get_value(pa))) {
	    branch->link[0] = cur->link[1];
	    cur->link[1] = ptra;
      } else {
	    branch->link[0] = ptra;
	    anodes_->sym_set_value(pa, branch);
      }

      if ((cur = anodes_->sym_get_value(pb))) {
	    branch->link[1] = cur->link[0];
	    cur->link[0] = ptrb;
      } else if ((cur = bnodes_->sym_get_value(pb))) {
	    branch->link[1] = cur->link[1];
	    cur->link[1] = ptrb;
      } else {
	    branch->link[1] = ptrb;
	    bnodes_->sym_set_value(pb, branch);
      }

      branch->next_branch = branches_;
      branches_ = branch;
}

vvp_net_t* vvp_island::find_port(const char*key)
{
      if (ports_ == 0)
	    return 0;
      else
	    return ports_->sym_get_value(key);
}

void vvp_island::compile_cleanup()
{
      delete ports_;
      ports_ = 0;

      delete anodes_;
      anodes_ = 0;

      delete bnodes_;
      bnodes_ = 0;
}

vvp_island_port::vvp_island_port(vvp_island*ip)
: island_(ip)
{
}

vvp_island_port::~vvp_island_port()
{
      delete evcd;
}

void vvp_island_port::recv_vec4(vvp_net_ptr_t, const vvp_vector4_t&bit,
                                vvp_context_t)
{
      vvp_vector8_t tmp (bit, 6, 6);
      if (invalue .eeq(tmp))
	    return;

      invalue = tmp;
      island_->flag_island();
}

void vvp_island_port::recv_vec4_pv(vvp_net_ptr_t port, const vvp_vector4_t&bit,
				   unsigned base, unsigned vwid, vvp_context_t)
{
      vvp_vector8_t tmp(bit, 6, 6);
      recv_vec8_pv(port, tmp, base, vwid);
}


void vvp_island_port::recv_vec8(vvp_net_ptr_t, const vvp_vector8_t&bit)
{
      if (invalue .eeq(bit))
	    return;

      invalue = bit;
      island_->flag_island();
}

void vvp_island_port::recv_vec8_pv(vvp_net_ptr_t, const vvp_vector8_t&bit,
                                   unsigned base, unsigned vwid)
{
      if (invalue.size() == 0) {
	    invalue = part_expand(bit, vwid, base);
      } else {
	    unsigned wid = bit.size();
	    assert(invalue.size() == vwid);
	    for (unsigned idx = 0; idx < wid ; idx += 1) {
		  if ((base+idx) >= vwid)
			break;
		  invalue.set_bit(base+idx, bit.value(idx));
	    }
      }

      island_->flag_island();
}

void vvp_island_port::force_flag(bool run_now)
{
      if (run_now)
	    island_->run_island();
      else
	    island_->flag_island();
}

vvp_island_branch::~vvp_island_branch()
{
      free(desc);
}

void island_collect_node(list<vvp_branch_ptr_t>&conn, vvp_branch_ptr_t cur)
{
      conn .push_back(cur);
      for (vvp_branch_ptr_t idx = next(cur) ; idx != cur ; idx = next(idx))
	    conn.push_back(idx);
}

/* **** COMPILE/LINK SUPPORT **** */

/*
* We need to keep an island symbol table to make island labels to
* islands, and we need a list of the islands that we can run through
* during cleanup. After linking is done, the compile_island_cleanup() is
* called to erase the symbol table, we still need the list to cleanup the
* island memory at EOS.
*/
static symbol_map_s<vvp_island>* island_table = 0;
static vvp_island** island_list = 0;
static unsigned island_count = 0;

#ifdef CHECK_WITH_VALGRIND
void island_delete()
{
      at_EOS = true;
      for (unsigned idx = 0; idx < island_count; idx += 1) {
	    delete island_list[idx];
      }
      free(island_list);
      island_list = 0;
      island_count = 0;
}
#endif

void compile_island_base(char*label, vvp_island*use_island)
{
      if (island_table == 0)
	    island_table = new symbol_map_s<vvp_island>;

      island_table->sym_set_value(label, use_island);
      island_count += 1;
      island_list = static_cast<vvp_island **>(realloc(island_list,
                                               island_count*sizeof(vvp_island **)));
      island_list[island_count-1] = use_island;
      free(label);
}

vvp_island* compile_find_island(const char*island)
{
      return island_table ? island_table->sym_get_value(island) : nullptr;
}

/*
 * This handles the compile of a .port record. A .port is a 2-way port
 * between the island and the outside. For example,
 *
 *   <label> .port <island> <src> ;
 *
 * The <src> is a label in the domain outside the island, and the
 * <label> is in the domain inside the island. Since this port is
 * bi-directional, the <label> is also available in the domain outside
 * the island. The outside should use the <label> to access the nexus
 * that this port represents, because the island will resolve internal
 * drivers with the external driver and make the output available on
 * <label>.
 */
void compile_island_port(char*label, char*island, char*src)
{
      assert(island_table);
      vvp_island*use_island = island_table->sym_get_value(island);
      assert(use_island);
      free(island);

      vvp_net_t*net = new vvp_net_t;
      vvp_island_port*fun = new vvp_island_port(use_island);
      net->fun = fun;

	// Get the source from outside the island
      input_connect(net, 0, src);

	// Define the functor outside the island.
      define_functor_symbol(label, net);

	// Also define it inside the island.
      use_island->add_port(label, net);

      free(label);
}

namespace {
const unsigned evcd_max_width = 1024U * 1024U;
const unsigned evcd_max_bits = 4U * evcd_max_width;
const unsigned evcd_max_records = 65536;

struct evcd_endpoint_record {
      vvp_net_t*net;
      std::string input;
      std::string resolver;
};

struct evcd_source_record {
      std::string endpoint, scope;
      unsigned index, base, width;
};

std::vector<evcd_endpoint_record> evcd_endpoints;
std::vector<evcd_source_record> evcd_sources;
unsigned evcd_endpoint_bits = 0, evcd_source_bits = 0;
unsigned evcd_declared_slots = 0;

void evcd_link_error(const char*record, const char*reason)
{
      fprintf(stderr, "vvp: invalid %s metadata: %s\n", record, reason);
      compile_errors += 1;
}
}

void compile_island_port_evcd(char*label, char*island, char*src,
			     uint64_t width, uint64_t count, uint64_t pull,
			     char*resolver)
{
      vvp_island*owner = compile_find_island(island);
      if (!owner || owner->find_port(label) || lookup_evcd_net(label) ||
	  !width || width > evcd_max_width || pull > 2 ||
	  count > evcd_max_records || (!resolver && count > 1) ||
	  (resolver && !count)) {
	    evcd_link_error(".port/evcd", "invalid endpoint, width or driver count");
      } else if (evcd_endpoints.size() >= evcd_max_records ||
		 count + (pull != 0) > evcd_max_records - evcd_declared_slots ||
		 width > evcd_max_bits - evcd_endpoint_bits) {
	    evcd_link_error(".port/evcd", "aggregate endpoint/slot budget exceeded");
      } else {
	    auto*net = new vvp_net_t;
	    auto*port = new vvp_island_port(owner);
	    net->fun = port;
	    port->evcd = new evcd_island_endpoint;
	    port->evcd->width = width;
	    port->evcd->driver_count = count;
	    port->evcd->pull = pull;
	    port->evcd->sources.resize(count + (pull != 0));
	    evcd_endpoint_bits += width;
	    evcd_declared_slots += port->evcd->sources.size();
	    evcd_endpoints.push_back({net, src, resolver ? resolver : ""});
	    input_connect_evcd(net, src);
	    src = nullptr;
	    define_functor_symbol(label, net);
	    owner->add_port(label, net);
      }
      free(label);
      free(island);
      free(src);
      free(resolver);
}

void compile_evcd_source(char*port, uint64_t slot, char*scope,
			 uint64_t base, uint64_t width)
{
      if (slot >= evcd_max_records || !width || base >= evcd_max_width ||
	  width > evcd_max_width - base) {
	    evcd_link_error(".evcd/source", "invalid slot or bit range");
      } else if (evcd_sources.size() >= evcd_max_records ||
		 width > evcd_max_bits - evcd_source_bits) {
	    evcd_link_error(".evcd/source", "aggregate source budget exceeded");
      } else {
	    evcd_sources.push_back({port, scope, (unsigned)slot,
				    (unsigned)base, (unsigned)width});
	    evcd_source_bits += width;
      }
      free(port);
      free(scope);
}

void link_evcd_endpoints()
{
      for (const auto&rec : evcd_sources) {
	    vvp_net_t*net = lookup_evcd_net(rec.endpoint.c_str());
	    auto*port = net ? dynamic_cast<vvp_island_port*>(net->fun) : nullptr;
	    auto*scope = dynamic_cast<__vpiScope*>(vvp_lookup_handle(rec.scope.c_str()));
	    auto*data = port ? port->evcd : nullptr;
	    if (!scope || !data || rec.index >= data->sources.size() ||
		rec.base >= data->width || rec.width > data->width - rec.base ||
		data->sources[rec.index].scope) {
		  evcd_link_error(".evcd/source", "invalid endpoint, owner, slot or bit range");
		  continue;
	    }
	    auto&slot = data->sources[rec.index];
	    slot.scope = scope;
	    slot.base = rec.base;
	    slot.width = rec.width;
      }
      evcd_sources.clear();

      std::set<vvp_island*> islands;
      for (const auto&rec : evcd_endpoints) {
	    auto*port = static_cast<vvp_island_port*>(rec.net->fun);
	    auto&data = *port->evcd;
	    islands.insert(port->island());
	    auto*filter = vvp_fil_signal_value(rec.net->fil);
	    if (filter && filter->value_size() != data.width)
		  evcd_link_error(".port/evcd", "width disagrees with endpoint net");

	    vvp_net_t*input = lookup_evcd_net(rec.input.c_str());
	    if (!rec.resolver.empty()) {
		  vvp_net_t*net = lookup_evcd_net(rec.resolver.c_str());
		  auto*resolver = net ? dynamic_cast<resolv_core*>(net->fun) : nullptr;
		  auto*tri = dynamic_cast<resolv_tri*>(resolver);
		  vvp_scalar_t pull = tri ? tri->implicit_pull() : vvp_scalar_t();
		  unsigned pull_code = pull.is_hiz() ? 0 : pull.value() == BIT4_0 ? 1 : 2;
		  if (!resolver || resolver->port_count() != data.driver_count ||
		      pull_code != data.pull ||
		      (input != net && (!input ||
			!dynamic_cast<vvp_fun_trireg*>(input->fun)))) {
			evcd_link_error(".port/evcd", "resolver does not match local driver slots");
			continue;
		  }
		  data.resolver = resolver;
		  resolver->watch_evcd(port->island());
	    } else if (data.pull && data.driver_count) {
		  evcd_link_error(".port/evcd", "missing resolver for drivers with an implicit pull");
	    }

	    for (unsigned idx = 0; idx < data.sources.size(); idx += 1) {
		  const auto&slot = data.sources[idx];
		  vvp_net_t*driver = data.resolver && idx < data.driver_count
			? data.resolver->input_source(idx) : input;
		  auto*part = driver ? dynamic_cast<vvp_fun_part_pv*>(driver->fun) : nullptr;
		  if (!slot.scope ||
		      (part && (slot.base != part->get_base() ||
				slot.width != std::min(part->get_wid(), data.width - slot.base))) ||
		      (idx == data.driver_count && (slot.base || slot.width != data.width)))
			evcd_link_error(".evcd/source", "missing slot or coverage disagrees with driver");
	    }
      }
      for (vvp_island*island : islands)
	    if (!island->link_evcd_branches())
		  evcd_link_error(".port/evcd", "invalid transparent island branch or bit range");
      for (const auto&rec : evcd_endpoints) {
	    auto*port = static_cast<vvp_island_port*>(rec.net->fun);
	    if (!port->evcd->anchor.ptr())
		  evcd_link_error(".port/evcd", "endpoint has no island branch");
      }
      evcd_endpoints.clear();
}

void compile_island_export(char*label, char*island)
{
      fprintf(stderr, "XXXX %s .export %s;\n", label, island);
      free(label);
      free(island);
}

/*
 * This handles the compile of a .import record. A .import is an input
 * port into the island from the outside domain. For example,
 *
 *   <label> .import <island> <src> ;
 *
 * The <src> is a label in the domain outside the island, and the
 * <label> is in the domain inside the island. Branches within the
 * island use the <label>.
 */
void compile_island_import(char*label, char*island, char*src)
{
      assert(island_table);
      vvp_island*use_island = island_table->sym_get_value(island);
      assert(use_island);
      free(island);

      vvp_net_t*net = new vvp_net_t;
      vvp_island_port*fun = new vvp_island_port(use_island);
      net->fun = fun;

	// Get the source from outside the island
      input_connect(net, 0, src);

	// Define the functor only inside the island.
      use_island->add_port(label, net);

      free(label);
}

void compile_island_cleanup(void)
{
	// Call the per-island cleanup to get rid of local symbol tables.
      for (unsigned idx = 0; idx < island_count; idx += 1) {
	    island_list[idx]->compile_cleanup();
      }

	// If we are not doing valgrind checking then free the list.
#ifndef CHECK_WITH_VALGRIND
      free(island_list);
      island_list = 0;
      island_count = 0;
#endif

	// Remove the island symbol table itself.
      delete island_table;
      island_table = 0;
}
