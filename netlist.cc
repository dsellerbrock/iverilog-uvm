/*
 * Copyright (c) 1998-2026 Stephen Williams (steve@icarus.com)
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

# include "config.h"

# include <iostream>

# include  <typeinfo>
# include  <cstdlib>
# include  <climits>
# include  <cstring>
# include  "compiler.h"
# include  "netlist.h"
# include  "netmisc.h"
# include  "netclass.h"
# include  "netdarray.h"
# include  "netenum.h"
# include  "netparray.h"
# include  "netscalar.h"
# include  "netqueue.h"
# include  "netstruct.h"
# include  "netvector.h"
# include  "ivl_assert.h"

using namespace std;

NetNetType::NetNetType(const nettype_t*decl, NetScope*scope)
: pform_type_(decl), declaration_scope_(scope)
{
}

const NetFuncDef* NetNetType::resolution_function() const
{
      const NetNetType*use = canonical_type_ ? canonical_type_ : this;
      return use->resolution_function_;
}

bool NetNetType::has_resolution_function() const
{
      const NetNetType*use = canonical_type_ ? canonical_type_ : this;
      return use->pform_type_ && use->pform_type_->has_resolution_function();
}

ostream& operator<< (ostream&o, NetNet::Type t)
{
      switch (t) {
	  case NetNet::NONE:
	    o << "net_none";
	    break;
	  case NetNet::IMPLICIT:
	    o << "wire /*implicit*/";
	    break;
	  case NetNet::IMPLICIT_REG:
	    o << "reg /*implicit*/";
	    break;
	  case NetNet::REG:
	    o << "reg";
	    break;
	  case NetNet::SUPPLY0:
	    o << "supply0";
	    break;
	  case NetNet::SUPPLY1:
	    o << "supply1";
	    break;
	  case NetNet::TRI:
	    o << "tri";
	    break;
	  case NetNet::TRI0:
	    o << "tri0";
	    break;
	  case NetNet::TRI1:
	    o << "tri1";
	    break;
	  case NetNet::TRIAND:
	    o << "triand";
	    break;
	  case NetNet::TRIOR:
	    o << "trior";
	    break;
	  case NetNet::WAND:
	    o << "wand";
	    break;
	  case NetNet::WOR:
	    o << "wor";
	    break;
	  case NetNet::WIRE:
	    o << "wire";
	    break;
	  case NetNet::UNRESOLVED_WIRE:
	    o << "uwire";
      }
      return o;
}

unsigned count_signals(const Link&pin)
{
      unsigned count = 0;

      const Nexus*nex = pin.nexus();
      for (const Link*clnk = nex->first_nlink()
		 ; clnk ; clnk = clnk->next_nlink()) {
	    const NetPins*cur;
	    unsigned cpin;
	    clnk->cur_link(cur, cpin);
	    if (dynamic_cast<const NetNet*>(cur))
		  count += 1;
      }

      return count;
}

const NetNet* find_link_signal(const NetObj*net, unsigned pin, unsigned&bidx)
{
      const Nexus*nex = net->pin(pin).nexus();

      for (const Link*clnk = nex->first_nlink()
		 ; clnk ; clnk = clnk->next_nlink()) {

	    const NetPins*cur;
	    unsigned cpin;
	    clnk->cur_link(cur, cpin);

	    const NetNet*sig = dynamic_cast<const NetNet*>(cur);
	    if (sig) {
		  bidx = cpin;
		  return sig;
	    }
      }

      return 0;
}

Link* find_next_output(Link*lnk)
{
      Link*cur = lnk->next_nlink();
      while (cur != lnk) {
	    if (cur->get_dir() == Link::OUTPUT)
		  return cur;

	    cur = cur->next_nlink();
	    if (cur == 0)
		  cur = lnk->nexus()->first_nlink();
      }

      return 0;
}

void NetPins::devirtualize_pins(void)
{
      ivl_assert(*this, !connectivity_released_());
      if (pins_) return;
      const unsigned count = pin_count();
      if (count > array_size_limit) {
            cerr << get_fileline() << ": error: pin count " << count <<
                " exceeds " << array_size_limit <<
                " (set by -pARRAY_SIZE_LIMIT)" << endl;
            ivl_assert(*this, 0);
      }
      if (debug_optimizer && count > 1000) cerr << "debug: devirtualizing " << count << " pins." << endl;

      pins_ = new Link[count];
      pins_[0].pin_zero_ = true;
      pins_[0].node_ = this;
      pins_[0].dir_  = default_dir_;

      for (unsigned idx = 1 ;  idx < count ;  idx += 1) {
            pins_[idx].pin_zero_ = false;
            pins_[idx].pin_      = idx;
            pins_[idx].dir_      = default_dir_;
      }
}

bool NetPins::pins_are_virtual(void) const
{
      return pins_ == NULL && !connectivity_released_();
}

NetPins::NetPins(unsigned npins)
: npins_(npins)
{
      default_dir_ = Link::PASSIVE;
      pins_ = NULL;  // Wait until someone asks.
      if (disable_virtual_pins) devirtualize_pins();  // Ask.  Bummer.
}

NetPins::~NetPins()
{
      if (pins_) {
	    ivl_assert(*this, pins_[0].node_ == this);
	    ivl_assert(*this, pins_[0].pin_zero_);
	    delete[] pins_;
      }
}

Link& NetPins::pin(unsigned idx)
{
      ivl_assert(*this, !connectivity_released_());
      if (!pins_) devirtualize_pins();
      const unsigned count = pin_count();
      if (idx >= count) {
            cerr << get_fileline() << ": internal error: pin("<<idx<<")"
                 << " out of bounds("<<count<<")" << endl;
            cerr << get_fileline() << ":               : typeid="
                 << typeid(*this).name() << endl;
      }

      ivl_assert(*this, idx < count);
      ivl_assert(*this, idx == 0? (pins_[0].pin_zero_ && pins_[0].node_==this) : pins_[idx].pin_==idx);

      return pins_[idx];
}

const Link& NetPins::pin(unsigned idx) const
{
      ivl_assert(*this, !connectivity_released_());
      if (!pins_ && !disable_virtual_pins) {
	    cerr << get_fileline() << ": internal error: pin is unexpectedly"
	      " virtual, try again with -pDISABLE_VIRTUAL_PINS=true" << endl;
	    ivl_assert(*this, 0);
      }
      ivl_assert(*this, pins_);
      ivl_assert(*this, idx < pin_count());
      ivl_assert(*this, idx == 0? (pins_[0].pin_zero_ && pins_[0].node_==this) : pins_[idx].pin_==idx);
      return pins_[idx];
}

void NetPins::set_default_dir(Link::DIR d)
{
       ivl_assert(*this, !connectivity_released_());
       default_dir_ = d;
}

bool NetPins::is_linked(void) const
{
      bool linked_flag = false;
      if (pins_ == NULL) return false;
      for (unsigned u = 0; u < pin_count(); u++) {
            if (pins_[u].is_linked()) {
		  linked_flag = true;
		  break;
	    }
      }
      return linked_flag;
}

size_t NetPins::release_terminal_connectivity()
{
      if (connectivity_released_())
            return 0;

      size_t released = 0;
      if (pins_) {
            released = pin_count();
            for (unsigned idx = 0; idx < pin_count(); idx += 1) {
                  if (!pins_[idx].next_)
                        continue;
                  Nexus*nexus = pins_[idx].find_nexus_();
                  ivl_assert(*this, nexus);
                  nexus->detach_all_links_();
                  delete nexus;
            }
            delete[] pins_;
            pins_ = 0;
      }

      default_dir_ = static_cast<Link::DIR>(TERMINAL_DIR_);
      return released;
}

NetObj::NetObj(NetScope*s, perm_string n, unsigned np)
: NetPins(np), scope_(s), name_(n), delay1_(0), delay2_(0), delay3_(0)
{
      /* Don't
      ivl_assert(*this, np > 0);
       * because it would happen before we get to print a useful
       * message in the NetNet constructor
       */
}

NetObj::~NetObj()
{
}

NetScope* NetObj::scope()
{
      return scope_;
}

const NetScope* NetObj::scope() const
{
      return scope_;
}

NetNode::NetNode(NetScope*s, perm_string n, unsigned npins)
: NetObj(s, n, npins), node_next_(0), node_prev_(0), design_(0)
{
}

NetNode::~NetNode()
{
      if (design_)
	    design_->del_node(this);
}

NetBranch::NetBranch(ivl_discipline_t dis)
: NetPins(2), IslandBranch(dis)
{
      pin(0).set_dir(Link::PASSIVE);
      pin(1).set_dir(Link::PASSIVE);
}

NetBranch::~NetBranch()
{
}

NetBus::NetBus(NetScope*s, unsigned pin_count__)
: NetObj(s, perm_string::literal(""), pin_count__)
{
      for (unsigned idx = 0 ;  idx <pin_count__ ;  idx += 1) {
	    pin(idx).set_dir(Link::PASSIVE);
      }
}

NetBus::~NetBus()
{
}

unsigned NetBus::find_link(const Link&that) const
{
      unsigned ptr = 0;

      while (ptr < pin_count()) {
	    if (pin(ptr).is_linked(that))
		  return ptr;

	    ptr += 1;
      }
      return ptr;
}

NetDelaySrc::NetDelaySrc(NetScope*s, perm_string n, unsigned npins,
                         bool condit_src, bool conditional, bool parallel)
: NetObj(s, n, npins + (condit_src?1:0))
{
      condit_flag_ = false;
      conditional_ = conditional;
      parallel_ = parallel;
      posedge_ = false;
      negedge_ = false;
      for (unsigned idx = 0 ;  idx < npins ;  idx += 1) {
	    pin(idx).set_dir(Link::INPUT);
      }
      for (unsigned dly = 0 ;  dly < 12 ;  dly += 1)
	    transition_delays_[dly] = static_cast<uint64_t>(0);

      if (condit_src) {
	    condit_flag_ = true;
	    pin(npins).set_dir(Link::INPUT);
      }
}

NetDelaySrc::~NetDelaySrc()
{
}

void NetDelaySrc::set_delays(uint64_t del)
{
      for (unsigned idx = 0 ;  idx < 12 ;  idx += 1)
	    transition_delays_[idx] = del;
}

void NetDelaySrc::set_delays(uint64_t trise, uint64_t tfall)
{
      transition_delays_[IVL_PE_01] = trise;
      transition_delays_[IVL_PE_10] = tfall;
      transition_delays_[IVL_PE_0z] = trise;
      transition_delays_[IVL_PE_z1] = trise;
      transition_delays_[IVL_PE_1z] = tfall;
      transition_delays_[IVL_PE_z0] = tfall;
      transition_delays_[IVL_PE_0x] = trise;
      transition_delays_[IVL_PE_x1] = trise;
      transition_delays_[IVL_PE_1x] = tfall;
      transition_delays_[IVL_PE_x0] = tfall;
      transition_delays_[IVL_PE_xz] = max(trise,tfall);
      transition_delays_[IVL_PE_zx] = min(trise,tfall);
}

void NetDelaySrc::set_delays(uint64_t trise, uint64_t tfall, uint64_t tz)
{
      transition_delays_[IVL_PE_01] = trise;
      transition_delays_[IVL_PE_10] = tfall;
      transition_delays_[IVL_PE_0z] = tz;
      transition_delays_[IVL_PE_z1] = trise;
      transition_delays_[IVL_PE_1z] = tz;
      transition_delays_[IVL_PE_z0] = tfall;
      transition_delays_[IVL_PE_0x] = min(trise,tz);
      transition_delays_[IVL_PE_x1] = trise;
      transition_delays_[IVL_PE_1x] = min(tfall,tz);
      transition_delays_[IVL_PE_x0] = tfall;
      transition_delays_[IVL_PE_xz] = tz;
      transition_delays_[IVL_PE_zx] = min(trise,tfall);
}

void NetDelaySrc::set_delays(uint64_t t01, uint64_t t10, uint64_t t0z,
			     uint64_t tz1, uint64_t t1z, uint64_t tz0)
{
      transition_delays_[IVL_PE_01] = t01;
      transition_delays_[IVL_PE_10] = t10;
      transition_delays_[IVL_PE_0z] = t0z;
      transition_delays_[IVL_PE_z1] = tz1;
      transition_delays_[IVL_PE_1z] = t1z;
      transition_delays_[IVL_PE_z0] = tz0;
      transition_delays_[IVL_PE_0x] = min(t01,t0z);
      transition_delays_[IVL_PE_x1] = max(t01,tz1);
      transition_delays_[IVL_PE_1x] = min(t10,t1z);
      transition_delays_[IVL_PE_x0] = max(t10,tz0);
      transition_delays_[IVL_PE_xz] = max(t1z,t0z);
      transition_delays_[IVL_PE_zx] = min(tz1,tz0);
}

void NetDelaySrc::set_delays(uint64_t t01, uint64_t t10, uint64_t t0z,
			     uint64_t tz1, uint64_t t1z, uint64_t tz0,
			     uint64_t t0x, uint64_t tx1, uint64_t t1x,
			     uint64_t tx0, uint64_t txz, uint64_t tzx)
{
      transition_delays_[IVL_PE_01] = t01;
      transition_delays_[IVL_PE_10] = t10;
      transition_delays_[IVL_PE_0z] = t0z;
      transition_delays_[IVL_PE_z1] = tz1;
      transition_delays_[IVL_PE_1z] = t1z;
      transition_delays_[IVL_PE_z0] = tz0;
      transition_delays_[IVL_PE_0x] = t0x;
      transition_delays_[IVL_PE_x1] = tx1;
      transition_delays_[IVL_PE_1x] = t1x;
      transition_delays_[IVL_PE_x0] = tx0;
      transition_delays_[IVL_PE_xz] = txz;
      transition_delays_[IVL_PE_zx] = tzx;
}

uint64_t NetDelaySrc::get_delay(unsigned idx) const
{
      ivl_assert(*this, idx < 12);
      return transition_delays_[idx];
}

void NetDelaySrc::set_posedge()
{
      posedge_ = true;
}

void NetDelaySrc::set_negedge()
{
      negedge_ = true;
}

bool NetDelaySrc::is_posedge() const
{
      return posedge_;
}

bool NetDelaySrc::is_negedge() const
{
      return negedge_;
}

unsigned NetDelaySrc::src_count() const
{
      if (condit_flag_)
	    return pin_count() - 1;
      else
	    return pin_count();
}

Link& NetDelaySrc::src_pin(unsigned idx)
{
      ivl_assert(*this, idx < src_count());
      return pin(idx);
}

const Link& NetDelaySrc::src_pin(unsigned idx) const
{
      ivl_assert(*this, idx < src_count());
      return pin(idx);
}

bool NetDelaySrc::is_condit() const
{
      return conditional_;
}

bool NetDelaySrc::has_condit() const
{
      return condit_flag_;
}

Link& NetDelaySrc::condit_pin()
{
      ivl_assert(*this, condit_flag_);
      return pin(pin_count()-1);
}

const Link& NetDelaySrc::condit_pin() const
{
      ivl_assert(*this, condit_flag_);
      return pin(pin_count()-1);
}

bool NetDelaySrc::is_parallel() const
{
      return parallel_;
}

PortType::Enum PortType::merged( Enum lhs, Enum rhs )
{
    if( lhs == NOT_A_PORT || rhs == NOT_A_PORT )
        return NOT_A_PORT;
    if( lhs == PIMPLICIT )
        return rhs;
    if( rhs == PIMPLICIT )
      return lhs;
    if( lhs == rhs ) {
        return lhs;
    }
    return PINOUT;
}

void NetNet::initialize_dir_()
{
      Link::DIR dir = Link::PASSIVE;

      switch (type_) {
	  case REG:
	  case IMPLICIT_REG:
	  case SUPPLY0:
	  case SUPPLY1:
	  case TRI0:
	  case TRI1:
	    dir = Link::OUTPUT;
	    break;
	  default:
	    break;
      }

      if (pins_are_virtual()) {
	    if (0) cerr << "NetNet setting Link default dir" << endl;
	    set_default_dir(dir);
      } else {
	    for (unsigned idx = 0 ;  idx < pin_count() ;  idx += 1) {
		  pin(idx).set_dir(dir);
	    }
      }
}

static unsigned calculate_count(const netranges_t &unpacked)
{
      unsigned long sum = netrange_width(unpacked);
      if (sum >= UINT_MAX)
	    return 0;

      return sum;
}

void NetNet::calculate_slice_dims_from_net_type_()
{
      ivl_assert(*this, net_type_);
      if (!net_type_->packed())
	    return;

      slice_dims_ = net_type_->slice_dimensions();
}

NetNet::NetNet(NetScope*s, perm_string n, Type t,
	       const netranges_t&unpacked, ivl_type_t use_net_type)
: NetObj(s, n, calculate_count(unpacked)),
    type_(t), port_type_(NOT_A_PORT), coerced_to_uwire_(false),
    local_flag_(false), lifetime_override_(IVL_VLT_INHERITED),
    lexical_pos_(0), net_type_(use_net_type),
    discipline_(0),
    eref_count_(0), lref_count_(0)
{
      calculate_slice_dims_from_net_type_();

      ivl_assert(*this, s);
      if (pin_count() == 0) {
	    cerr << "Invalid array dimensions: " << unpacked << endl;
	    ivl_assert(*this, 0);
      }

      initialize_dir_();

      if (!unpacked.empty())
	    array_type_ = new netuarray_t(unpacked, net_type_);

      s->add_signal(this);
}

NetNet::NetNet(NetScope*s, perm_string n, Type t, ivl_type_t type)
: NetObj(s, n, 1),
    type_(t), port_type_(NOT_A_PORT), coerced_to_uwire_(false),
    local_flag_(false), lifetime_override_(IVL_VLT_INHERITED),
    lexical_pos_(0), net_type_(type),
    discipline_(0),
    eref_count_(0), lref_count_(0)
{
      calculate_slice_dims_from_net_type_();

      initialize_dir_();

      s->add_signal(this);
}

NetNet::~NetNet()
{
      if (eref_count_ > 0) {
	    cerr << get_fileline() << ": internal error: attempt to delete "
		 << "signal ``" << name() << "'' which has "
		 << "expression references." << endl;
	    dump_net(cerr, 4);
      }
      ivl_assert(*this, eref_count_ == 0);
      if (lref_count_ > 0) {
	    cerr << get_fileline() << ": internal error: attempt to delete "
		 << "signal ``" << name() << "'' which has "
		 << "assign references." << endl;
	    dump_net(cerr, 4);
      }
      ivl_assert(*this, lref_count_ == 0);
      if (scope())
	    scope()->rem_signal(this);

      delete target_emit_aux_;
      target_emit_aux_ = 0;
}

void NetNet::set_net_type(ivl_type_t type)
{
      ivl_assert(*this, type);

      netuarray_t*replacement_array = array_type_
	    ? new netuarray_t(array_type_->static_dimensions(), type) : 0;
      net_type_ = type;
      slice_dims_.clear();
      calculate_slice_dims_from_net_type_();
      delete array_type_;
      array_type_ = replacement_array;
}

NetNet::target_emit_aux_t*NetNet::ensure_target_emit_aux_()
{
      if (!target_emit_aux_)
	    target_emit_aux_ = new target_emit_aux_t;
      return target_emit_aux_;
}

void NetNet::bind_interface_scope(unsigned word, NetScope*scope)
{
      ivl_assert(*this, word < pin_count());
      ivl_assert(*this, scope);
      target_emit_aux_t*aux = ensure_target_emit_aux_();
      if (aux->interface_bindings.size() < pin_count())
            aux->interface_bindings.resize(pin_count());
      interface_binding_t&binding = aux->interface_bindings[word];
      binding.scope = scope;
      binding.signal = 0;
      binding.signal_word = 0;
}

void NetNet::bind_interface_signal(unsigned word, NetNet*signal,
                                   unsigned signal_word)
{
      ivl_assert(*this, word < pin_count());
      ivl_assert(*this, signal);
      ivl_assert(*this, signal_word < signal->pin_count());
      target_emit_aux_t*aux = ensure_target_emit_aux_();
      if (aux->interface_bindings.size() < pin_count())
            aux->interface_bindings.resize(pin_count());
      interface_binding_t&binding = aux->interface_bindings[word];
      binding.scope = 0;
      binding.signal = signal;
      binding.signal_word = signal_word;
}

void NetNet::bind_interface_member(unsigned word, size_t property_idx,
                                   NetNet*member)
{
      ivl_assert(*this, word < pin_count());
      ivl_assert(*this, member);
      ensure_target_emit_aux_()->interface_synthesis_members[
            make_pair(word, property_idx)] = member;
}

NetNet* NetNet::resolve_interface_member(unsigned word,
                                         size_t property_idx) const
{
      const NetNet*signal = this;
      unsigned signal_word = word;
      set<pair<const NetNet*,unsigned> >seen;

      while (signal) {
            if (signal_word >= signal->pin_count())
                  return 0;
            if (!seen.insert(make_pair(signal, signal_word)).second)
                  return 0;

            const netclass_t*interface_type =
                  dynamic_cast<const netclass_t*>(signal->net_type());
            if (!interface_type || !interface_type->is_interface()
                || property_idx >= interface_type->get_properties())
                  return 0;
            const target_emit_aux_t*aux = signal->target_emit_aux_;
            if (!aux)
                  return 0;
            map<pair<unsigned,size_t>,NetNet*>::const_iterator bound_member =
                  aux->interface_synthesis_members.find(
                        make_pair(signal_word, property_idx));
            if (bound_member != aux->interface_synthesis_members.end())
                  return bound_member->second;
            if (aux->interface_bindings.size() <= signal_word)
                  return 0;

            const interface_binding_t&binding =
                  aux->interface_bindings[signal_word];
            if (binding.scope) {
                  perm_string member_name = lex_strings.make(
                        interface_type->get_prop_name(property_idx));
                  NetNet*member = binding.scope->find_signal(member_name);
                  if (!member)
                        return 0;

                  ivl_type_t expected = interface_type->get_prop_type(
                        property_idx);
                  ivl_type_t actual = member->unpacked_dimensions()
                        ? static_cast<ivl_type_t>(member->array_type())
                        : member->net_type();
                  if (!expected || !actual
                      || !expected->type_equivalent(actual)
                      || !actual->type_equivalent(expected)) {
                        return 0;
                  }
                  return member;
            }

            signal = binding.signal;
            signal_word = binding.signal_word;
      }

      return 0;
}

void NetNet::set_user_nettype(const NetNetType*declared)
{
      declared_user_nettype_ = declared;
      user_nettype_ = declared ? declared->canonical_type() : 0;
      if (!user_nettype_)
            user_nettype_ = declared;
}

static bool interconnect_types_equivalent_(ivl_type_t left, ivl_type_t right,
                                           bool compare_shape)
{
      if (left == right)
            return true;
      if (!left || !right)
            return false;
      if (!compare_shape)
            return left->base_type() == right->base_type();
      return left->type_equivalent(right) && right->type_equivalent(left);
}

static bool interconnect_shapes_equivalent_(const NetNet*left,
                                            const NetNet*right)
{
      return left && right
            && netrange_equivalent(left->packed_dims(), right->packed_dims())
            && netrange_equivalent(left->unpacked_dims(),
                                   right->unpacked_dims());
}

void NetNet::mark_interconnect(bool declared_shape)
{
      if (!interconnect_type_) {
            interconnect_type_.reset(new NetInterconnectType);
            interconnect_type_->members_.push_back(this);
      }
      interconnect_declared_shape_ = declared_shape;
      if (declared_shape)
            interconnect_type_->declared_shape_source_ = this;
}

bool NetNet::interconnect_type_resolved() const
{
      return interconnect_type_ && interconnect_type_->resolved();
}

bool NetNet::interconnect_type_invalid() const
{
      return interconnect_type_ && interconnect_type_->invalid();
}

void NetNet::apply_interconnect_type_(
      const shared_ptr<NetInterconnectType>&group)
{
      if (!group || !group->resolved_type_)
            return;

      for (vector<NetNet*>::iterator cur = group->members_.begin();
           cur != group->members_.end(); ++cur) {
            NetNet*net = *cur;
            if (!net)
                  continue;

            /* A selected element resolves the element kind of an explicitly
             * shaped declaration, not the declaration's aggregate shape. */
            if (!(group->selected_element_type_
                  && net->interconnect_declared_shape_))
                  net->set_net_type(group->resolved_type_);

            if (group->user_nettype_)
                  net->set_user_nettype(group->user_nettype_);

            NetNet::Type use_wire_type = static_cast<NetNet::Type>(
                  group->source_wire_type_);
            if (use_wire_type != NetNet::NONE
                && use_wire_type != NetNet::IMPLICIT
                && use_wire_type != NetNet::IMPLICIT_REG
                && use_wire_type != NetNet::REG)
                  net->type(use_wire_type);
      }
}

NetNet::interconnect_bind_result_t
NetNet::bind_interconnect_type(NetNet*source, bool selected_element)
{
      ivl_assert(*this, interconnect_type_);
      ivl_assert(*this, source);

      shared_ptr<NetInterconnectType>group = interconnect_type_;
      const NetNetType*source_udnt = source->user_nettype();

      if (group->user_nettype_ && source_udnt
          && group->user_nettype_ != source_udnt) {
            group->invalid_ = true;
            return INTERCONNECT_BIND_TYPE_CONFLICT;
      }

      NetNet*shape_source = group->declared_shape_source_;
      if (shape_source && !selected_element
          && !interconnect_shapes_equivalent_(shape_source, source)) {
            group->invalid_ = true;
            return INTERCONNECT_BIND_SHAPE_CONFLICT;
      }

      if (group->resolved_type_) {
            /* A selected edge initially supplies only an element-kind hint.
             * A later whole-net edge may upgrade that hint to the complete
             * concrete packed type after the declared shape is checked. */
            if (group->selected_element_type_ && !selected_element) {
                  group->resolved_type_ = source->net_type();
                  group->source_ = source;
                  group->source_wire_type_ =
                        static_cast<unsigned>(source->type());
                  group->selected_element_type_ = false;
                  if (!group->user_nettype_ && source_udnt)
                        group->user_nettype_ = source_udnt;
                  apply_interconnect_type_(group);
                  return INTERCONNECT_BIND_OK;
            }
            bool compare_shape = !(group->selected_element_type_
                                   || selected_element);
            if (!interconnect_types_equivalent_(group->resolved_type_,
                                                source->net_type(),
                                                compare_shape)) {
                  group->invalid_ = true;
                  return compare_shape ? INTERCONNECT_BIND_SHAPE_CONFLICT
                                       : INTERCONNECT_BIND_TYPE_CONFLICT;
            }
            if (!group->user_nettype_ && source_udnt)
                  group->user_nettype_ = source_udnt;
            return INTERCONNECT_BIND_OK;
      }

      /* set_net_type() can replace a packed type, but it deliberately does
       * not rebuild a NetNet's unpacked dimensions or pin array.  An
       * unshaped generic therefore cannot silently acquire an unpacked shape
       * from a whole-net connection.  A selected element is safe: the
       * expression denotes one element and source->net_type() is its type. */
      if (!interconnect_declared_shape_ && !selected_element
          && source->unpacked_dimensions() != 0) {
            group->invalid_ = true;
            return INTERCONNECT_BIND_SHAPE_CONFLICT;
      }

      group->resolved_type_ = source->net_type();
      group->user_nettype_ = source_udnt;
      group->source_ = source;
      group->source_wire_type_ = static_cast<unsigned>(source->type());
      group->selected_element_type_ = selected_element;
      apply_interconnect_type_(group);
      return INTERCONNECT_BIND_OK;
}

NetNet::interconnect_bind_result_t
NetNet::merge_interconnect_type(NetNet*other)
{
      ivl_assert(*this, interconnect_type_);
      ivl_assert(*this, other && other->interconnect_type_);

      shared_ptr<NetInterconnectType>left = interconnect_type_;
      shared_ptr<NetInterconnectType>right = other->interconnect_type_;
      if (left == right)
            return INTERCONNECT_BIND_OK;

      if (left->user_nettype_ && right->user_nettype_
          && left->user_nettype_ != right->user_nettype_) {
            left->invalid_ = right->invalid_ = true;
            return INTERCONNECT_BIND_TYPE_CONFLICT;
      }

      if (left->declared_shape_source_ && right->declared_shape_source_
          && !interconnect_shapes_equivalent_(left->declared_shape_source_,
                                              right->declared_shape_source_)) {
            left->invalid_ = right->invalid_ = true;
            return INTERCONNECT_BIND_SHAPE_CONFLICT;
      }

      if (left->resolved_type_ && right->resolved_type_) {
            bool compare_shape = !(left->selected_element_type_
                                   || right->selected_element_type_);
            if (!interconnect_types_equivalent_(left->resolved_type_,
                                                right->resolved_type_,
                                                compare_shape)) {
                  left->invalid_ = right->invalid_ = true;
                  return compare_shape ? INTERCONNECT_BIND_SHAPE_CONFLICT
                                       : INTERCONNECT_BIND_TYPE_CONFLICT;
            }
      }

      /* Union by size bounds the total member-pointer rewrites over a chain
       * of hierarchy connections to O(N log N). */
      if (left->members_.size() < right->members_.size())
            left.swap(right);

      if (!left->resolved_type_ && right->resolved_type_) {
            left->resolved_type_ = right->resolved_type_;
            left->source_ = right->source_;
            left->source_wire_type_ = right->source_wire_type_;
            left->selected_element_type_ = right->selected_element_type_;
      } else if (left->resolved_type_ && right->resolved_type_
                 && left->selected_element_type_
                 && !right->selected_element_type_) {
            /* Prefer a complete propagated type over an element-only hint. */
            left->resolved_type_ = right->resolved_type_;
            left->source_ = right->source_;
            left->source_wire_type_ = right->source_wire_type_;
            left->selected_element_type_ = false;
      }
      if (!left->user_nettype_)
            left->user_nettype_ = right->user_nettype_;
      if (!left->declared_shape_source_)
            left->declared_shape_source_ = right->declared_shape_source_;
      left->invalid_ = left->invalid_ || right->invalid_;

      for (vector<NetNet*>::iterator cur = right->members_.begin();
           cur != right->members_.end(); ++cur) {
            (*cur)->interconnect_type_ = left;
            left->members_.push_back(*cur);
      }
      right->members_.clear();
      apply_interconnect_type_(left);
      return INTERCONNECT_BIND_OK;
}

void NetNet::invalidate_interconnect_type()
{
      if (interconnect_type_)
            interconnect_type_->invalid_ = true;
}

void NetNet::begin_interconnect_port_use()
{
      if (interconnect_type_)
            interconnect_port_use_depth_ += 1;
}

void NetNet::end_interconnect_port_use()
{
      if (!interconnect_type_)
            return;
      ivl_assert(*this, interconnect_port_use_depth_ > 0);
      interconnect_port_use_depth_ -= 1;
}

NetNet::Type NetNet::type() const
{
      return type_;
}

void NetNet::type(NetNet::Type t)
{
      if (type_ == t)
	    return;

      if ((t == UNRESOLVED_WIRE) && ((type_ == REG) || (type_ == IMPLICIT_REG)))
	    coerced_to_uwire_ = true;

      type_ = t;

      initialize_dir_();
}


NetNet::PortType NetNet::port_type() const
{
      return port_type_;
}

void NetNet::port_type(NetNet::PortType t)
{
      port_type_ = t;
}

int NetNet::get_module_port_index() const
{
      return port_index_;
}

void NetNet::set_module_port_index(unsigned idx)
{
    port_index_ = idx;
    ivl_assert(*this, port_index_ >= 0);
}

ivl_variable_type_t NetNet::data_type() const
{
      ivl_assert(*this, net_type_);
      return net_type_->base_type();
}

bool NetNet::get_signed() const
{
      ivl_assert(*this, net_type_);
      return net_type_->get_signed();
}

bool NetNet::get_scalar() const
{
      ivl_assert(*this, net_type_);
      return net_type_->get_scalar();
}

const netenum_t*NetNet::enumeration(void) const
{
      return dynamic_cast<const netenum_t*> (net_type_);
}

const netstruct_t*NetNet::struct_type(void) const
{
      ivl_type_t cur_type = net_type_;
      while (cur_type) {
	    if (const netdarray_t*da = dynamic_cast<const netdarray_t*> (cur_type)) {
		  cur_type = da->element_type();
		  continue;
	    }
	    if (const netparray_t*da = dynamic_cast<const netparray_t*> (cur_type)) {
		  cur_type = da->element_type();
		  continue;
	    }
	    if (const netstruct_t*st = dynamic_cast<const netstruct_t*> (cur_type))
		  return st;
	    else
		  return 0;
      }

      ivl_assert(*this, 0);
      return 0;
}

const netdarray_t* NetNet::darray_type(void) const
{
      return dynamic_cast<const netdarray_t*> (net_type_);
}

const netqueue_t* NetNet::queue_type(void) const
{
      return dynamic_cast<const netqueue_t*> (net_type_);
}

const netclass_t* NetNet::class_type(void) const
{
      return dynamic_cast<const netclass_t*> (net_type_);
}

const netarray_t* NetNet::array_type() const
{
      if (array_type_)
	    return array_type_;

      return darray_type();
}

const netranges_t& NetNet::unpacked_dims() const
{
      static const netranges_t no_dimensions;
      return array_type_ ? array_type_->static_dimensions() : no_dimensions;
}

unsigned NetNet::unpacked_dimensions() const
{
      return array_type_ ? array_type_->static_dimensions().size() : 0;
}

/*
 * "depth" is the number of index expressions that the user is using
 * to index this identifier. So consider if Net was declared like so:
 *
 *   reg [5:0][3:0] foo;
 *
 * In this case, slice_width(2) == 1  (slice_width(N) where N is the
 * number of dimensions will always be 1.) and represents
 * $bits(foo[a][b]). Then, slice_width(1)==4 ($bits(foo[a]) and slice_width(0)==24.
 *
 * NOTE: The caller should already have accounted for unpacked
 * dimensions. The "depth" is only for the packed dimensions.
 */
unsigned long NetNet::slice_width(size_t depth) const
{
      ivl_assert(*this, net_type_);

      if (!net_type_->packed())
	    return depth == 0 ? 1 : 0;

	/* Packed scalar-like types have no declared dimensions, but the old
	 * width cache retained their packed width at depth zero and the scalar
	 * element width at depth one. */
      if (slice_dims_.empty()) {
	    if (depth == 0)
		  return net_type_->packed_width();
	    return depth == 1 ? 1 : 0;
      }

      if (depth > slice_dims_.size())
	    return 0;
      if (depth == slice_dims_.size())
	    return 1;

      unsigned long width = netrange_width(slice_dims_);
      for (size_t idx = 0; idx < depth; idx += 1)
	    width /= slice_dims_[idx].width();
      return width;
}

ivl_discipline_t NetNet::get_discipline() const
{
      return discipline_;
}

void NetNet::set_discipline(ivl_discipline_t dis)
{
      ivl_assert(*this, discipline_ == 0);
      discipline_ = dis;
}

bool NetNet::sb_is_valid(const list<long>&indices, long sb) const
{
      ivl_assert(*this, indices.size()+1 == packed_dims().size());
      ivl_assert(*this, packed_dims().size() == 1);
      const netrange_t&rng = packed_dims().back();
      if (rng.get_msb() >= rng.get_lsb())
	    return (sb <= rng.get_msb()) && (sb >= rng.get_lsb());
      else
	    return (sb <= rng.get_lsb()) && (sb >= rng.get_msb());
}

long NetNet::sb_to_idx(const list<long>&indices, long sb) const
{
      ivl_assert(*this, indices.size()+1 == packed_dims().size());

      netranges_t::const_iterator pcur = packed_dims().end();
      -- pcur;

      long acc_off;
      long acc_wid = pcur->width();
      if (pcur->get_msb() >= pcur->get_lsb())
	    acc_off = sb - pcur->get_lsb();
      else
	    acc_off = pcur->get_lsb() - sb;

	// The acc_off is the position within the innermost
	// dimension. If this is a multi-dimension packed array then
	// we need to add in the canonical address of the current slice.
      if (! indices.empty()) {
	    list<long>::const_iterator icur = indices.end();
	    do {
		  -- icur;
		  -- pcur;

		  long tmp_off;
		  if (pcur->get_msb() >= pcur->get_lsb())
			tmp_off = *icur - pcur->get_lsb();
		  else
			tmp_off = pcur->get_lsb() - *icur;

		  acc_off += tmp_off * acc_wid;
		  acc_wid *= pcur->width();

	    } while (icur != indices.begin());
      }

      return acc_off;
}

bool NetNet::sb_to_slice(const list<long>&indices, long sb, long&loff, unsigned long&lwid) const
{
      ivl_assert(*this, indices.size() < packed_dims().size());
      return prefix_to_slice(packed_dims(), indices, sb, loff, lwid);
}

unsigned NetNet::unpacked_count() const
{
      return netrange_width(unpacked_dims());
}

void NetNet::incr_eref()
{
      if (interconnect_type_ && interconnect_port_use_depth_ == 0)
            interconnect_value_referenced_ = true;
      eref_count_ += 1;
}

void NetNet::decr_eref()
{
      ivl_assert(*this, eref_count_ > 0);
      eref_count_ -= 1;
}

unsigned NetNet::peek_eref() const
{
      return eref_count_;
}

/*
 * Test each of the bits in the range. If any bits are set then return true.
 */
bool NetNet::test_part_driven(unsigned pmsb, unsigned plsb, int widx)
{
      if (lref_mask_.empty())
           return false;

       // If indexing a word that doesn't exist, then pretend this is
       // never driven.
      if (widx < 0)
           return false;
      if (widx >= (int)pin_count())
           return false;

      unsigned word_base = vector_width() * widx;
      for (unsigned idx = plsb ; idx <= pmsb ; idx += 1) {
           if (lref_mask_[idx+word_base])
                 return true;
      }

      return false;
}

/*
 * Test each of the bits in the range, and set them. If any bits are
 * already set then return true.
 */
bool NetNet::test_and_set_part_driver(unsigned pmsb, unsigned plsb, int widx)
{
      if (lref_mask_.empty())
	    lref_mask_.resize(vector_width() * pin_count());

	// If indexing a word that doesn't exist, then pretend this is
	// never driven.
      if (widx < 0)
	    return false;
      if (widx >= (int)pin_count())
	    return false;

      bool rc = false;
      unsigned word_base = vector_width() * widx;
      for (unsigned idx = plsb ; idx <= pmsb ; idx += 1) {
	    if (lref_mask_[idx+word_base])
		  rc = true;
	    else
		  lref_mask_[idx+word_base] = true;
      }

      return rc;
}

void NetNet::incr_lref()
{
      lref_count_ += 1;
}

void NetNet::decr_lref()
{
      ivl_assert(*this, lref_count_ > 0);
      lref_count_ -= 1;
}

void NetNet::register_lref(NetAssign_*obj)
{
      lref_objs_.push_back(obj);
}

void NetNet::unregister_lref(NetAssign_*obj)
{
      for (std::vector<NetAssign_*>::iterator cur = lref_objs_.begin()
		 ; cur != lref_objs_.end() ; ++cur) {
	    if (*cur == obj) {
		  lref_objs_.erase(cur);
		  return;
	    }
      }
}

/*
 * Does any BEHAVIOURAL l-value on this signal reach a bit of the
 * canonical range [lsb..msb] in word widx?
 *
 * lref_count_ answers only "are there any at all", which is not enough
 * to tell a real conflict from a continuous assign and an always block
 * driving DIFFERENT elements of one packed array -- legal under IEEE
 * 1800-2017 6.5, which prohibits mixing drivers on the same BITS.
 *
 * The ranges are read here rather than recorded at construction time
 * because NetAssign_::set_part() runs after the constructor; asking
 * late is what makes the answer independent of elaboration order.
 *
 * Every uncertainty answers true: no part select means the l-value
 * covers the whole signal, a run-time base could land anywhere, and an
 * unpacked word index we cannot pin down might be this word.
 */
bool NetNet::test_part_procedurally_driven(unsigned msb, unsigned lsb,
					   int widx) const
{
      for (std::vector<NetAssign_*>::const_iterator cur = lref_objs_.begin()
		 ; cur != lref_objs_.end() ; ++cur) {
	    const NetAssign_*lv = *cur;
	    if (!lv) continue;
	    if (lv->is_force_lval()) continue;

	      // An unpacked word index we cannot evaluate: assume it
	      // could be the word being asked about.
	    if (const NetExpr*w = lv->word()) {
		  const NetEConst*wc = dynamic_cast<const NetEConst*>(w);
		  if (!wc || !wc->value().is_defined())
			return true;

		  long first_word = wc->value().as_long();
		  if (lv->is_array_slice()) {
			ivl_type_t slice_type = lv->net_type();
			unsigned long word_count = slice_type
			      ? netrange_width(slice_type->slice_dimensions()) : 0;
			if (first_word < 0 || word_count == 0)
			      return true;
			if ((long)widx < first_word
			    || (unsigned long)((long)widx - first_word) >= word_count)
			      continue;
			// A subarray l-value covers the complete selected word.
			return true;
		  }

		  if (first_word != (long)widx)
			continue;
	    }

	    const NetExpr*base = lv->get_base();
	    if (base == 0)
		    // No part select: the whole signal.
		  return true;

	    const NetEConst*bc = dynamic_cast<const NetEConst*>(base);
	    if (!bc || !bc->value().is_defined())
		    // Run-time offset: could be anywhere.
		  return true;

	    long off = bc->value().as_long();
	    long wid = (long)lv->lwidth();
	    if (wid <= 0)
		  return true;

	    long l_lo = off;
	    long l_hi = off + wid - 1;
	    if (l_hi >= (long)lsb && l_lo <= (long)msb)
		  return true;
      }

      return false;
}

unsigned NetNet::get_refs() const
{
      return lref_count_ + eref_count_;
}

void NetNet::add_delay_path(NetDelaySrc*path)
{
      ensure_target_emit_aux_()->delay_paths.push_back(path);
}

unsigned NetNet::delay_paths(void)const
{
      return target_emit_aux_ ? target_emit_aux_->delay_paths.size() : 0;
}

const NetDelaySrc* NetNet::delay_path(unsigned idx) const
{
      ivl_assert(*this, target_emit_aux_);
      ivl_assert(*this, idx < target_emit_aux_->delay_paths.size());
      return target_emit_aux_->delay_paths[idx];
}

void NetNet::add_net_delay_boundary(NetBUFZ*net)
{
      ensure_target_emit_aux_()->net_delay_boundaries.push_back(net);
}

const vector<NetBUFZ*>& NetNet::net_delay_boundaries() const
{
      static const vector<NetBUFZ*> no_boundaries;
      return target_emit_aux_ ? target_emit_aux_->net_delay_boundaries
	    : no_boundaries;
}

vector<NetBUFZ*>& NetNet::mutable_net_delay_boundaries()
{
      return ensure_target_emit_aux_()->net_delay_boundaries;
}

void NetNet::release_emitted_signal_aux()
{
      if (!target_emit_aux_)
	    return;

      vector<NetDelaySrc*>().swap(target_emit_aux_->delay_paths);
      vector<NetBUFZ*>().swap(target_emit_aux_->net_delay_boundaries);

	/* Interface properties can still be resolved while later task/function
	 * definitions and processes are converted. Retain those two containers,
	 * but avoid keeping an otherwise empty auxiliary record. */
      if (target_emit_aux_->interface_bindings.empty()
	  && target_emit_aux_->interface_synthesis_members.empty()) {
	    delete target_emit_aux_;
	    target_emit_aux_ = 0;
      }
}

NetPartSelect::NetPartSelect(NetNet*sig, unsigned off, unsigned wid,
			     NetPartSelect::dir_t dir__,
			     bool signed_flag__)
: NetNode(sig->scope(), sig->scope()->local_symbol(), 2),
    off_(off), wid_(wid), dir_(dir__), signed_flag_(signed_flag__)
{
      set_line(*sig);

      switch (dir_) {
	  case NetPartSelect::VP:
	    pin(0).set_dir(Link::OUTPUT);
	    pin(1).set_dir(Link::INPUT);
	    break;
	  case NetPartSelect::PV:
	    pin(0).set_dir(Link::INPUT);
	    pin(1).set_dir(Link::OUTPUT);
	    break;
      }

      connect(pin(1), sig->pin(0));
}

NetPartSelect::NetPartSelect(NetNet*sig, NetNet*sel,
			     unsigned wid, bool signed_flag__)
: NetNode(sig->scope(), sig->scope()->local_symbol(), 3),
    off_(0), wid_(wid), dir_(VP), signed_flag_(signed_flag__)
{
      switch (dir_) {
	  case NetPartSelect::VP:
	    pin(0).set_dir(Link::OUTPUT);
	    pin(1).set_dir(Link::INPUT);
	    break;
	  case NetPartSelect::PV:
	      /* Only a vector to part can be a variable select. */
	    ivl_assert(*this, 0);
      }
      pin(2).set_dir(Link::INPUT);

      connect(pin(1), sig->pin(0));
      connect(pin(2), sel->pin(0));
}

NetPartSelect::~NetPartSelect()
{
}

unsigned NetPartSelect::width() const
{
      return wid_;
}

unsigned NetPartSelect::base() const
{
      return off_;
}

NetSubstitute::NetSubstitute(NetNet*sig, NetNet*sub, unsigned wid, unsigned off)
: NetNode(sig->scope(), sig->scope()->local_symbol(), 3), wid_(wid), off_(off),
  signed_flag_(false)
{
      pin(0).set_dir(Link::OUTPUT);
      pin(1).set_dir(Link::INPUT);
      pin(2).set_dir(Link::INPUT);
      connect(pin(1), sig->pin(0));
      connect(pin(2), sub->pin(0));
}

NetSubstitute::NetSubstitute(NetNet*sig, NetNet*sub, NetNet*sel,
			     unsigned wid, bool signed_flag)
: NetNode(sig->scope(), sig->scope()->local_symbol(), 4), wid_(wid), off_(0),
  signed_flag_(signed_flag)
{
      pin(0).set_dir(Link::OUTPUT);
      pin(1).set_dir(Link::INPUT);
      pin(2).set_dir(Link::INPUT);
      pin(3).set_dir(Link::INPUT);
      connect(pin(1), sig->pin(0));
      connect(pin(2), sub->pin(0));
      connect(pin(3), sel->pin(0));
}

NetSubstitute::~NetSubstitute()
{
}

NetProc::NetProc()
: next_(0)
{
}

NetProc::~NetProc()
{
}

NetProcTop::NetProcTop(NetScope*s, ivl_process_type_t t, NetProc*st)
: type_(t), statement_(st), scope_(s)
{
      synthesized_design_ = 0;
      next_ = nullptr;

}

NetProcTop::~NetProcTop()
{
      if (!synthesized_design_) {
	    delete statement_;
	    return;
      }
      delete statement_;
}

NetProc* NetProcTop::statement()
{
      return statement_;
}

const NetProc* NetProcTop::statement() const
{
      return statement_;
}

NetScope* NetProcTop::scope()
{
      return scope_;
}

const NetScope* NetProcTop::scope() const
{
      return scope_;
}

NetAnalogTop::NetAnalogTop(NetScope*scope__, ivl_process_type_t t, NetProc*st)
: type_(t), statement_(st), scope_(scope__)
{
      next_ = 0;
}

NetAnalogTop::~NetAnalogTop()
{
}

NetProc* NetAnalogTop::statement()
{
      return statement_;
}

const NetProc* NetAnalogTop::statement() const
{
      return statement_;
}

NetScope* NetAnalogTop::scope()
{
      return scope_;
}

const NetScope* NetAnalogTop::scope() const
{
      return scope_;
}

NetCastInt2::NetCastInt2(NetScope*scope__, perm_string n, unsigned width__)
: NetNode(scope__, n, 2), width_(width__)
{
      pin(0).set_dir(Link::OUTPUT);
      pin(1).set_dir(Link::INPUT);
}

NetCastInt4::NetCastInt4(NetScope*scope__, perm_string n, unsigned width__)
: NetNode(scope__, n, 2), width_(width__)
{
      pin(0).set_dir(Link::OUTPUT);
      pin(1).set_dir(Link::INPUT);
}

NetCastReal::NetCastReal(NetScope*scope__, perm_string n, bool signed_flag__)
: NetNode(scope__, n, 2), signed_flag_(signed_flag__)
{
      pin(0).set_dir(Link::OUTPUT);
      pin(1).set_dir(Link::INPUT);
}

NetConcat::NetConcat(NetScope*scope__, perm_string n, unsigned wid, unsigned cnt, bool trans_flag)
: NetNode(scope__, n, cnt+1), width_(wid), transparent_(trans_flag)
{
      pin(0).set_dir(Link::OUTPUT);
      for (unsigned idx = 1 ;  idx < cnt+1 ;  idx += 1) {
	    pin(idx).set_dir(Link::INPUT);
      }
}

NetConcat::~NetConcat()
{
}

unsigned NetConcat::width() const
{
      return width_;
}

NetReplicate::NetReplicate(NetScope*scope__, perm_string n,
			   unsigned wid, unsigned rpt)
: NetNode(scope__, n, 2), width_(wid), repeat_(rpt)
{
      pin(0).set_dir(Link::OUTPUT);
      pin(1).set_dir(Link::INPUT);
}

NetReplicate::~NetReplicate()
{
}

unsigned NetReplicate::width() const
{
      return width_;
}

unsigned NetReplicate::repeat() const
{
      return repeat_;
}

/*
 * The NetFF class represents an LPM_FF device. The pinout is assigned
 * like so:
 *    0  -- Clock
 *    1  -- Enable
 *    2  -- Aset
 *    3  -- Aclr
 *    4  -- Sset
 *    5  -- Sclr
 *    6  -- Data
 *    7  -- Q
 *     ...
 */

NetFF::NetFF(NetScope*s, perm_string n, bool negedge__, unsigned width__)
: NetNode(s, n, 8), negedge_(negedge__), width_(width__),
  async_set_priority_(false)
{
      pin_Clock().set_dir(Link::INPUT);
      pin_Enable().set_dir(Link::INPUT);
      pin_Aset().set_dir(Link::INPUT);
      pin_Aclr().set_dir(Link::INPUT);
      pin_Sset().set_dir(Link::INPUT);
      pin_Sclr().set_dir(Link::INPUT);
      pin_Data().set_dir(Link::INPUT);
      pin_Q().set_dir(Link::OUTPUT);
}

NetFF::~NetFF()
{
}

bool NetFF::is_negedge() const
{
      return negedge_;
}

unsigned NetFF::width() const
{
      return width_;
}

Link& NetFF::pin_Clock()
{
      return pin(0);
}

const Link& NetFF::pin_Clock() const
{
      return pin(0);
}

Link& NetFF::pin_Enable()
{
      return pin(1);
}

const Link& NetFF::pin_Enable() const
{
      return pin(1);
}

Link& NetFF::pin_Aset()
{
      return pin(2);
}

const Link& NetFF::pin_Aset() const
{
      return pin(2);
}

Link& NetFF::pin_Aclr()
{
      return pin(3);
}

const Link& NetFF::pin_Aclr() const
{
      return pin(3);
}

Link& NetFF::pin_Sset()
{
      return pin(4);
}

const Link& NetFF::pin_Sset() const
{
      return pin(4);
}

Link& NetFF::pin_Sclr()
{
      return pin(5);
}

const Link& NetFF::pin_Sclr() const
{
      return pin(5);
}

Link& NetFF::pin_Data()
{
      return pin(6);
}

const Link& NetFF::pin_Data() const
{
      return pin(6);
}

Link& NetFF::pin_Q()
{
      return pin(7);
}

const Link& NetFF::pin_Q() const
{
      return pin(7);
}

void NetFF::aset_value(const verinum&val)
{
      aset_value_ = val;
}

const verinum& NetFF::aset_value() const
{
      return aset_value_;
}

void NetFF::async_set_priority(bool flag)
{
      async_set_priority_ = flag;
}

bool NetFF::async_set_priority() const
{
      return async_set_priority_;
}

void NetFF::sset_value(const verinum&val)
{
      sset_value_ = val;
}

const verinum& NetFF::sset_value() const
{
      return sset_value_;
}

/*
 * The NetLatch class represents an LPM_LATCH device. The pinout is assigned
 * like so:
 *    0  -- Enable
 *    1  -- Data
 *    2  -- Q
 */

NetLatch::NetLatch(NetScope*s, perm_string n, unsigned width__)
: NetNode(s, n, 3), width_(width__)
{
      pin_Enable().set_dir(Link::INPUT);
      pin_Data().set_dir(Link::INPUT);
      pin_Q().set_dir(Link::OUTPUT);
}

NetLatch::~NetLatch()
{
}

unsigned NetLatch::width() const
{
      return width_;
}

Link& NetLatch::pin_Enable()
{
      return pin(0);
}

const Link& NetLatch::pin_Enable() const
{
      return pin(0);
}

Link& NetLatch::pin_Data()
{
      return pin(1);
}

const Link& NetLatch::pin_Data() const
{
      return pin(1);
}

Link& NetLatch::pin_Q()
{
      return pin(2);
}

const Link& NetLatch::pin_Q() const
{
      return pin(2);
}

NetAbs::NetAbs(NetScope*s, perm_string n, unsigned w)
: NetNode(s, n, 2), width_(w)
{
      pin(0).set_dir(Link::OUTPUT);
      pin(1).set_dir(Link::INPUT);
}

NetAbs::~NetAbs()
{
}

unsigned NetAbs::width() const
{
      return width_;
}

/*
 * The NetAddSub class represents an LPM_ADD_SUB device. The pinout is
 * assigned like so:
 *    0  -- Cout
 *    1  -- DataA (normally a vector)
 *    2  -- DataB (normally a vector)
 *    3  -- Result (normally a vector)
 */
NetAddSub::NetAddSub(NetScope*s, perm_string n, unsigned w)
: NetNode(s, n, 4), width_(w)
{
      pin(0).set_dir(Link::OUTPUT); // Cout
      pin(1).set_dir(Link::INPUT);  // DataA
      pin(2).set_dir(Link::INPUT);  // DataB
      pin(3).set_dir(Link::OUTPUT); // Result
}

NetAddSub::~NetAddSub()
{
}

unsigned NetAddSub::width()const
{
      return width_;
}

Link& NetAddSub::pin_Cout()
{
      return pin(0);
}

const Link& NetAddSub::pin_Cout() const
{
      return pin(0);
}

Link& NetAddSub::pin_DataA()
{
      return pin(1);
}

const Link& NetAddSub::pin_DataA() const
{
      return pin(1);
}

Link& NetAddSub::pin_DataB()
{
      return pin(2);
}

const Link& NetAddSub::pin_DataB() const
{
      return pin(2);
}

Link& NetAddSub::pin_Result()
{
      return pin(3);
}

const Link& NetAddSub::pin_Result() const
{
      return pin(3);
}

NetArrayDq::NetArrayDq(NetScope*s, perm_string n, NetNet*mem__, unsigned awid,
		       bool write_port, bool negedge)
: NetNode(s, n, 5),
  mem_(mem__), awidth_(awid), write_port_(write_port), negedge_(negedge)
{
      pin(0).set_dir(Link::OUTPUT); // Result
      pin(1).set_dir(Link::INPUT);  // Address
	// A read port leaves these unconnected. A synthesized synchronous
	// array-write port uses Data, Clock and Enable and leaves Result open.
      pin(2).set_dir(Link::INPUT);  // Data
      pin(3).set_dir(Link::INPUT);  // Clock
      pin(4).set_dir(Link::INPUT);  // Enable
	// Increment the expression reference count for the target
	// memory so that it is not deleted underneath me.
      mem_->incr_eref();
}

NetArrayDq::~NetArrayDq()
{
}

unsigned NetArrayDq::width() const
{
      return mem_->vector_width();
}

unsigned NetArrayDq::awidth() const
{
      return awidth_;
}

unsigned NetArrayDq::size() const
{
      return mem_->pin_count();
}

const NetNet* NetArrayDq::mem() const
{
      return mem_;
}

bool NetArrayDq::is_write_port() const
{
      return write_port_;
}

bool NetArrayDq::is_negedge() const
{
      return negedge_;
}

void NetArrayDq::is_negedge(bool flag)
{
      negedge_ = flag;
}

Link& NetArrayDq::pin_Result()
{
      return pin(0);
}

Link& NetArrayDq::pin_Address()
{
      return pin(1);
}

Link& NetArrayDq::pin_Data()
{
      return pin(2);
}

Link& NetArrayDq::pin_Clock()
{
      return pin(3);
}

Link& NetArrayDq::pin_Enable()
{
      return pin(4);
}

const Link& NetArrayDq::pin_Result() const
{
      return pin(0);
}

const Link& NetArrayDq::pin_Address() const
{
      return pin(1);
}

const Link& NetArrayDq::pin_Data() const
{
      return pin(2);
}

const Link& NetArrayDq::pin_Clock() const
{
      return pin(3);
}

const Link& NetArrayDq::pin_Enable() const
{
      return pin(4);
}

/*
 * The pinout for the NetCLShift is:
 *    0  -- Result
 *    1  -- Data
 *    2  -- Distance
 */
NetCLShift::NetCLShift(NetScope*s, perm_string n,
		       unsigned width__, unsigned width_dist__,
		       bool right_flag__, bool signed_flag__)
: NetNode(s, n, 3),
  width_(width__), width_dist_(width_dist__),
    right_flag_(right_flag__), signed_flag_(signed_flag__)
{
      pin(0).set_dir(Link::OUTPUT); // Result
      pin(1).set_dir(Link::INPUT);  // Data
      pin(2).set_dir(Link::INPUT);  // Distance
}

NetCLShift::~NetCLShift()
{
}

unsigned NetCLShift::width() const
{
      return width_;
}

unsigned NetCLShift::width_dist() const
{
      return width_dist_;
}

bool NetCLShift::right_flag() const
{
      return right_flag_;
}

bool NetCLShift::signed_flag() const
{
      return signed_flag_;
}

Link& NetCLShift::pin_Data()
{
      return pin(1);
}

const Link& NetCLShift::pin_Data() const
{
      return pin(1);
}

Link& NetCLShift::pin_Result()
{
      return pin(0);
}

const Link& NetCLShift::pin_Result() const
{
      return pin(0);
}

Link& NetCLShift::pin_Distance()
{
      return pin(2);
}

const Link& NetCLShift::pin_Distance() const
{
      return pin(2);
}

NetCompare::NetCompare(NetScope*s, perm_string n, unsigned wi)
: NetNode(s, n, 8), width_(wi)
{
      signed_flag_ = false;
      pin(0).set_dir(Link::OUTPUT); // AGB
      pin(1).set_dir(Link::OUTPUT); // AGEB
      pin(2).set_dir(Link::OUTPUT); // AEB
      pin(3).set_dir(Link::OUTPUT); // ANEB
      pin(4).set_dir(Link::OUTPUT); // ALB
      pin(5).set_dir(Link::OUTPUT); // ALEB
      pin(6).set_dir(Link::INPUT);  // DataA
      pin(7).set_dir(Link::INPUT);  // DataB
}

NetCompare::~NetCompare()
{
}

unsigned NetCompare::width() const
{
      return width_;
}

bool NetCompare::get_signed() const
{
      return signed_flag_;
}

void NetCompare::set_signed(bool flag)
{
      signed_flag_ = flag;
}


Link& NetCompare::pin_AGB()
{
      return pin(0);
}

const Link& NetCompare::pin_AGB() const
{
      return pin(0);
}

Link& NetCompare::pin_AGEB()
{
      return pin(1);
}

const Link& NetCompare::pin_AGEB() const
{
      return pin(1);
}

Link& NetCompare::pin_AEB()
{
      return pin(2);
}

const Link& NetCompare::pin_AEB() const
{
      return pin(2);
}

Link& NetCompare::pin_ANEB()
{
      return pin(3);
}

const Link& NetCompare::pin_ANEB() const
{
      return pin(3);
}

Link& NetCompare::pin_ALB()
{
      return pin(4);
}

const Link& NetCompare::pin_ALB() const
{
      return pin(4);
}

Link& NetCompare::pin_ALEB()
{
      return pin(5);
}

const Link& NetCompare::pin_ALEB() const
{
      return pin(5);
}

Link& NetCompare::pin_DataA()
{
      return pin(6);
}

const Link& NetCompare::pin_DataA() const
{
      return pin(6);
}

Link& NetCompare::pin_DataB()
{
      return pin(7);
}

const Link& NetCompare::pin_DataB() const
{
      return pin(7);
}

NetDivide::NetDivide(NetScope*sc, perm_string n, unsigned wr,
		     unsigned wa, unsigned wb)
: NetNode(sc, n, 3),
    width_r_(wr), width_a_(wa), width_b_(wb), signed_flag_(false)
{
      pin(0).set_dir(Link::OUTPUT); // Result
      pin(1).set_dir(Link::INPUT);  // DataA
      pin(2).set_dir(Link::INPUT);  // DataB
}

NetDivide::~NetDivide()
{
}

unsigned NetDivide::width_r() const
{
      return width_r_;
}

unsigned NetDivide::width_a() const
{
      return width_a_;
}

unsigned NetDivide::width_b() const
{
      return width_b_;
}

void NetDivide::set_signed(bool flag)
{
      signed_flag_ = flag;
}

bool NetDivide::get_signed() const
{
      return signed_flag_;
}

Link& NetDivide::pin_Result()
{
      return pin(0);
}

const Link& NetDivide::pin_Result() const
{
      return pin(0);
}

Link& NetDivide::pin_DataA()
{
      return pin(1);
}

const Link& NetDivide::pin_DataA() const
{
      return pin(1);
}

Link& NetDivide::pin_DataB()
{
      return pin(2);
}

const Link& NetDivide::pin_DataB() const
{
      return pin(2);
}

NetLiteral::NetLiteral(NetScope*sc, perm_string n, const verireal&val)
: NetNode(sc, n, 1), real_(val)
{
      pin(0).set_dir(Link::OUTPUT);
}

NetLiteral::~NetLiteral()
{
}

ivl_variable_type_t NetLiteral::data_type()
{
      return IVL_VT_REAL;
}

const verireal& NetLiteral::value_real() const
{
      return real_;
}

NetMult::NetMult(NetScope*sc, perm_string n, unsigned wr,
		 unsigned wa, unsigned wb)
: NetNode(sc, n, 3),
  signed_(false), width_r_(wr), width_a_(wa), width_b_(wb)
{
      pin(0).set_dir(Link::OUTPUT); // Result
      pin(1).set_dir(Link::INPUT);  // DataA
      pin(2).set_dir(Link::INPUT);  // DataB
}

NetMult::~NetMult()
{
}

void NetMult::set_signed(bool flag)
{
      signed_ = flag;
}

bool NetMult::get_signed() const
{
      return signed_;
}

unsigned NetMult::width_r() const
{
      return width_r_;
}

unsigned NetMult::width_a() const
{
      return width_a_;
}

unsigned NetMult::width_b() const
{
      return width_b_;
}

Link& NetMult::pin_Result()
{
      return pin(0);
}

const Link& NetMult::pin_Result() const
{
      return pin(0);
}

Link& NetMult::pin_DataA()
{
      return pin(1);
}

const Link& NetMult::pin_DataA() const
{
      return pin(1);
}

Link& NetMult::pin_DataB()
{
      return pin(2);
}

const Link& NetMult::pin_DataB() const
{
      return pin(2);
}

NetPow::NetPow(NetScope*sc, perm_string n, unsigned wr,
		 unsigned wa, unsigned wb)
: NetNode(sc, n, 3),
  signed_(false), width_r_(wr), width_a_(wa), width_b_(wb)
{
      pin(0).set_dir(Link::OUTPUT); // Result
      pin(1).set_dir(Link::INPUT);  // DataA
      pin(2).set_dir(Link::INPUT);  // DataB
}

NetPow::~NetPow()
{
}

void NetPow::set_signed(bool flag)
{
      signed_ = flag;
}

bool NetPow::get_signed() const
{
      return signed_;
}

unsigned NetPow::width_r() const
{
      return width_r_;
}

unsigned NetPow::width_a() const
{
      return width_a_;
}

unsigned NetPow::width_b() const
{
      return width_b_;
}

Link& NetPow::pin_Result()
{
      return pin(0);
}

const Link& NetPow::pin_Result() const
{
      return pin(0);
}

Link& NetPow::pin_DataA()
{
      return pin(1);
}

const Link& NetPow::pin_DataA() const
{
      return pin(1);
}

Link& NetPow::pin_DataB()
{
      return pin(2);
}

const Link& NetPow::pin_DataB() const
{
      return pin(2);
}

/*
 * The NetMux class represents an LPM_MUX device. The pinout is assigned
 * like so:
 *    0   -- Result
 *    1   -- Sel
 *    2+N -- Data[N]  (N is the size of the mux)
 */

NetMux::NetMux(NetScope*s, perm_string n,
	       unsigned wi, unsigned si, unsigned sw)
: NetNode(s, n, 2+si),
  width_(wi), size_(si), swidth_(sw)
{
      pin(0).set_dir(Link::OUTPUT); // Q
      pin(1).set_dir(Link::INPUT);  // Sel

      for (unsigned idx = 0 ;  idx < size_ ;  idx += 1) {
	    pin_Data(idx).set_dir(Link::INPUT); // Data[idx]
      }
}

NetMux::~NetMux()
{
}

unsigned NetMux::width()const
{
      return width_;
}

unsigned NetMux::size() const
{
      return size_;
}

unsigned NetMux::sel_width() const
{
      return swidth_;
}

Link& NetMux::pin_Result()
{
      return pin(0);
}

const Link& NetMux::pin_Result() const
{
      return pin(0);
}

Link& NetMux::pin_Sel()
{
      return pin(1);
}

const Link& NetMux::pin_Sel() const
{
      return pin(1);
}

Link& NetMux::pin_Data(unsigned s)
{
      ivl_assert(*this, s < size_);
      return pin(2+s);
}

const Link& NetMux::pin_Data(unsigned s) const
{
      ivl_assert(*this, s < size_);
      return pin(2+s);
}

NetSignExtend::NetSignExtend(NetScope*s, perm_string n, unsigned w)
: NetNode(s, n, 2), width_(w)
{
      pin(0).set_dir(Link::OUTPUT);
      pin(1).set_dir(Link::INPUT);
}

NetSignExtend::~NetSignExtend()
{
}

unsigned NetSignExtend::width() const
{
      return width_;
}

NetBUFZ::NetBUFZ(NetScope*s, perm_string n, unsigned w, bool trans, int port_info_index)
: NetNode(s, n, 2), width_(w), transparent_(trans), port_info_index_(port_info_index)
{
      pin(0).set_dir(Link::OUTPUT);
      pin(1).set_dir(Link::INPUT);
}

NetBUFZ::~NetBUFZ()
{
}

unsigned NetBUFZ::width() const
{
      return width_;
}

NetCaseCmp::NetCaseCmp(NetScope*s, perm_string n, unsigned wid, kind_t k)
: NetNode(s, n, 3), width_(wid), kind_(k)
{
      pin(0).set_dir(Link::OUTPUT);
      pin(1).set_dir(Link::INPUT);
      pin(2).set_dir(Link::INPUT);
}

NetCaseCmp::~NetCaseCmp()
{
}

unsigned NetCaseCmp::width() const
{
      return width_;
}

NetCondit::NetCondit(NetExpr*ex, NetProc*i, NetProc*e)
: expr_(ex), if_(i), else_(e)
{
}

NetCondit::~NetCondit()
{
      delete expr_;
      delete if_;
      delete else_;
}

const NetExpr* NetCondit::expr() const
{
      return expr_;
}

NetExpr* NetCondit::expr()
{
      return expr_;
}

void NetCondit::set_expr(NetExpr*ex)
{
      delete expr_;
      expr_ = ex;
}

NetProc* NetCondit::if_clause()
{
      return if_;
}

NetProc* NetCondit::else_clause()
{
      return else_;
}

NetProc* NetCondit::release_if_clause()
{
      NetProc*res = if_;
      if_ = 0;
      return res;
}

const NetProc* NetCondit::if_clause() const
{
      return if_;
}

const NetProc* NetCondit::else_clause() const
{
      return else_;
}

NetConst::NetConst(NetScope*s, perm_string n, verinum::V v)
: NetNode(s, n, 1), value_(v, 1)
{
      pin(0).set_dir(Link::OUTPUT);
}

NetConst::NetConst(NetScope*s, perm_string n, const verinum&val)
: NetNode(s, n, 1), value_(val)
{
      pin(0).set_dir(Link::OUTPUT);
}

NetConst::~NetConst()
{
}

verinum::V NetConst::value(unsigned idx) const
{
      ivl_assert(*this, idx < width());
      return value_[idx];
}

NetBaseDef::NetBaseDef(NetScope*s, const vector<NetNet*>&po, const std::vector<NetExpr*>&pd)
: scope_(s), ports_(po), pdefaults_(pd)
{
      proc_ = 0;
}

NetBaseDef::~NetBaseDef()
{
      release_port_defaults();
}

const NetScope* NetBaseDef::scope() const
{
      return scope_;
}

NetScope*NetBaseDef::scope()
{
      return scope_;
}

unsigned NetBaseDef::port_count() const
{
      return ports_.size();
}

NetNet* NetBaseDef::port(unsigned idx) const
{
      assert(idx < ports_.size());
      return ports_[idx];
}

NetExpr* NetBaseDef::port_defe(unsigned idx) const
{
      assert(idx < pdefaults_.size());
      return pdefaults_[idx];
}

void NetBaseDef::release_port_defaults()
{
      for (vector<NetExpr*>::iterator cur = pdefaults_.begin()
		 ; cur != pdefaults_.end() ; ++cur) {
	    delete *cur;
	    *cur = 0;
      }
      vector<NetExpr*>().swap(pdefaults_);
}

void NetBaseDef::set_proc(NetProc*st)
{
      assert(proc_ == 0);
      assert(st != 0);
      proc_ = st;
}

void NetBaseDef::release_proc()
{
      delete proc_;
      proc_ = 0;
}

const NetProc* NetBaseDef::proc() const
{
      return proc_;
}

NetFuncDef::NetFuncDef(NetScope*s, NetNet*result, const vector<NetNet*>&po,
		       const vector<NetExpr*>&pd)
: NetBaseDef(s, po, pd), result_sig_(result)
{
}

NetFuncDef::~NetFuncDef()
{
}

const NetNet* NetFuncDef::return_sig() const
{
      return result_sig_;
}

NetSTask::NetSTask(const char*na, ivl_sfunc_as_task_t sfat,
                   const vector<NetExpr*>&pa)
: name_(0), sfunc_as_task_(sfat), parms_(pa)
{
      name_ = lex_strings.add(na);
      ivl_assert(*this, name_[0] == '$');
}

NetSTask::~NetSTask()
{
      for (unsigned idx = 0 ;  idx < parms_.size() ;  idx += 1)
	    delete parms_[idx];

	/* The name_ string is perm-allocated in lex_strings. */
}

const char*NetSTask::name() const
{
      return name_;
}

ivl_sfunc_as_task_t NetSTask::sfunc_as_task() const
{
      return sfunc_as_task_;
}

unsigned NetSTask::nparms() const
{
      return parms_.size();
}

const NetExpr* NetSTask::parm(unsigned idx) const
{
      return parms_[idx];
}

/* A fixed unpacked function return uses the result NetNet's array_type();
 * net_type() alone describes only one element. Keep the aggregate shape on
 * the call expression so an immediately chained array method can dispatch on
 * the actual return type. */
NetEUFunc::NetEUFunc(NetScope*scope, NetScope*def, NetESignal*res,
                     vector<NetExpr*>&p, bool nc, bool super_call)
: NetExpr(res->sig()->array_type()
	? static_cast<ivl_type_t>(res->sig()->array_type()) : res->net_type()),
  scope_(scope), func_(def), result_sig_(res),
  parms_(p), need_const_(nc), super_call_(super_call)
{
}

NetEUFunc::~NetEUFunc()
{
      for (unsigned idx = 0 ;  idx < parms_.size() ;  idx += 1)
	    delete parms_[idx];
}
#if 0
const string NetEUFunc::name() const
{
      return func_->name();
}
#endif
const NetESignal*NetEUFunc::result_sig() const
{
      return result_sig_;
}

unsigned NetEUFunc::parm_count() const
{
      return parms_.size();
}

const NetExpr* NetEUFunc::parm(unsigned idx) const
{
      ivl_assert(*this, idx < parms_.size());
      return parms_[idx];
}

const NetScope* NetEUFunc::func() const
{
      return func_;
}

bool NetEUFunc::super_call() const
{
      return super_call_;
}

NetUTask::NetUTask(NetScope*def, bool super_call)
: task_(def), super_call_(super_call)
{
}

NetUTask::~NetUTask()
{
}

const NetScope* NetUTask::task() const
{
      return task_;
}

bool NetUTask::super_call() const
{
      return super_call_;
}

NetAlloc::NetAlloc(NetScope*scope__)
: scope_(scope__)
{
}

NetAlloc::~NetAlloc()
{
}
#if 0
const string NetAlloc::name() const
{
      return scope_->name();
}
#endif
const NetScope* NetAlloc::scope() const
{
      return scope_;
}

NetFree::NetFree(NetScope*scope__)
: scope_(scope__)
{
}

NetFree::~NetFree()
{
}
#if 0
const string NetFree::name() const
{
      return scope_->name();
}
#endif
const NetScope* NetFree::scope() const
{
      return scope_;
}

/*
 * Create a bitwise operator node from the opcode and the left and
 * right expressions.
 */
NetEBBits::NetEBBits(char op__, NetExpr*l, NetExpr*r, unsigned wid, bool signed_flag)
: NetEBinary(op__, l, r, wid, signed_flag)
{
}

NetEBBits::~NetEBBits()
{
}

ivl_variable_type_t NetEBBits::expr_type() const
{
      if (left_->expr_type() == IVL_VT_LOGIC ||
          right_->expr_type() == IVL_VT_LOGIC)
	    return IVL_VT_LOGIC;

      return IVL_VT_BOOL;
}

NetEBinary::NetEBinary(char op__, NetExpr*l, NetExpr*r, unsigned wid, bool signed_flag)
: op_(op__), left_(l), right_(r)
{
      expr_width(wid);
      cast_signed_base_(signed_flag);
}

NetEBinary::~NetEBinary()
{
      delete left_;
      delete right_;
}

bool NetEBinary::has_width() const
{
      return left_->has_width() && right_->has_width();
}

NetEBLogic::NetEBLogic(char op__, NetExpr*l, NetExpr*r)
: NetEBinary(op__, l, r, 1, false)
{
}

NetEBLogic::~NetEBLogic()
{
}

ivl_variable_type_t NetEBLogic::expr_type() const
{
      if (left_->expr_type() == IVL_VT_LOGIC ||
          right_->expr_type() == IVL_VT_LOGIC)
	    return IVL_VT_LOGIC;

      return IVL_VT_BOOL;
}

NetEConst::NetEConst(const verinum&val)
: NetExpr(val.len()), value_(val)
{
      if (getenv("IVL_NETECONST_TRACE")) {
            fprintf(stderr,
                    "trace neteconst ctor: width=%u as_ulong=%llu has_len=%d has_sign=%d\n",
                    value_.len(), (unsigned long long)value_.as_ulong64(),
                    value_.has_len(), value_.has_sign());
      }
      cast_signed_base_(value_.has_sign());
}

NetEConst::NetEConst(ivl_type_t type, const verinum&val)
: NetExpr(type), value_(val)
{
      ivl_assert(*this, type->packed());
      long pw = type->packed_width();
      if (pw >= 0 && (unsigned long)pw != val.len()) {
            value_ = verinum(val, (unsigned)pw);
      }
      value_.has_sign(type->get_signed());
}

NetEConst::~NetEConst()
{
}

void NetEConst::cast_signed(bool flag)
{
      if (getenv("IVL_NETECONST_TRACE")) {
            fprintf(stderr,
                    "trace neteconst cast_signed before: width=%u as_ulong=%llu has_len=%d has_sign=%d flag=%d\n",
                    value_.len(), (unsigned long long)value_.as_ulong64(),
                    value_.has_len(), value_.has_sign(), flag);
      }
      cast_signed_base_(flag);
      value_.has_sign(flag);
      if (getenv("IVL_NETECONST_TRACE")) {
            fprintf(stderr,
                    "trace neteconst cast_signed after: width=%u as_ulong=%llu has_len=%d has_sign=%d\n",
                    value_.len(), (unsigned long long)value_.as_ulong64(),
                    value_.has_len(), value_.has_sign());
      }
}

const verinum& NetEConst::value() const
{
      return value_;
}

bool NetEConst::has_width() const
{
      return value_.has_len();
}

ivl_variable_type_t NetEConst::expr_type() const
{
      if (value_.len() == 0)
	    return IVL_VT_LOGIC;
      if (value_.is_string())
	    return IVL_VT_BOOL;
      if (value_.is_defined())
	    return IVL_VT_BOOL;

      return IVL_VT_LOGIC;
}

void NetEConst::trim()

{
      if (value_.is_string())
            return;

      value_.has_len(false);
      value_ = trim_vnum(value_);
      expr_width(value_.len());
}

NetEConstParam::NetEConstParam(const NetScope*s, perm_string n,
                              const verinum&v, bool unbounded)
: NetEConst(v), scope_(s), name_(n)
{
      cast_signed_base_(v.has_sign());
      mark_unbounded(unbounded);
}

NetEConstParam::~NetEConstParam()
{
}

perm_string NetEConstParam::name() const
{
      return name_;
}

const NetScope* NetEConstParam::scope() const
{
      return scope_;
}

NetEEvent::NetEEvent(NetEvent*e)
: event_(e)
{
    e->exprref_ += 1;
}

NetEEvent::~NetEEvent()
{
      assert(event_->exprref_ > 0);
      event_->exprref_ -= 1;
}

const NetEvent* NetEEvent::event() const
{
      return event_;
}

NetEScope::NetEScope(NetScope*s, ivl_type_t type)
: NetExpr(type), scope_(s)
{
}

NetEScope::~NetEScope()
{
}

const NetScope* NetEScope::scope() const
{
      return scope_;
}

NetESignal::NetESignal(NetNet*n)
: NetExpr(n->net_type()), net_(n), word_(0)
{
      net_->incr_eref();
      set_line(*n);
}

NetESignal::NetESignal(NetNet*n, NetExpr*w)
: NetExpr(n->vector_width()), net_(n), word_(w)
{
      net_->incr_eref();
      set_line(*n);

      if (word_)
	    set_net_type(net_->net_type());
      else
	    set_net_type(net_->array_type());
}

NetESignal::~NetESignal()
{
      net_->decr_eref();
}

perm_string NetESignal::name() const
{
      return net_->name();
}

const NetExpr* NetESignal::word_index() const
{
      return word_;
}

unsigned NetESignal::vector_width() const
{
      return net_->vector_width();
}

const NetNet* NetESignal::sig() const
{
      return net_;
}

NetNet* NetESignal::sig()
{
      return net_;
}

/*
 * The lsi() and msi() methods should be removed from the NetESignal
 * class, to be replaced with packed dimensions aware methods of
 * getting at dimensions.
 */
long NetESignal::lsi() const
{
      const netranges_t&packed = net_->packed_dims();
      ivl_assert(*this, packed.size() == 1);
      return packed.back().get_lsb();
}

long NetESignal::msi() const
{
      const netranges_t&packed = net_->packed_dims();
      ivl_assert(*this, packed.size() == 1);
      return packed.back().get_msb();
}

ivl_variable_type_t NetESignal::expr_type() const
{
      if (net_->darray_type())
	    return IVL_VT_DARRAY;
      else
	    return net_->data_type();
}

/*
* Make a ternary operator from all the sub-expressions. The condition
* expression is self-determined, but the true and false expressions
* should have the same width. NOTE: This matching of the widths really
* has to be done in elaboration.
*/
NetETernary::NetETernary(NetExpr*c, NetExpr*t, NetExpr*f,
                         unsigned wid, bool signed_flag)
: cond_(c), true_val_(t), false_val_(f)
{
      expr_width(wid);
      cast_signed_base_(signed_flag);
}

NetETernary::~NetETernary()
{
      delete cond_;
      delete true_val_;
      delete false_val_;
}

const netenum_t* NetETernary::enumeration() const
{
	// IEEE 1800-2017 11.4.11: when both arms of the conditional
	// operator have the same type, that is the type of the result.
	// Two operands of the same enumeration type therefore yield that
	// enumeration type, which makes `e = cond ? A : B;' a legal
	// 6.19.3 assignment with no cast.
	//
	// A 4-state condition does NOT change the result TYPE. If the
	// condition is ambiguous the two arms are blended bit by bit and
	// the value may not name an enumeration member -- but that is a
	// runtime value question, and it is unchanged by writing the
	// cast the caller would otherwise be forced to add:
	// `e_t'(cond ? A : B)' blends to exactly the same bits. Refusing
	// to propagate the type here bought no safety and rejected the
	// conforming idiom (OpenTitan builds every multi-bit-encoded
	// control signal this way, e.g. `mubi4_bool_to_mubi').
      if (true_val_->enumeration() != false_val_->enumeration())
	    return 0;

      return true_val_->enumeration();
}

const NetExpr* NetETernary::cond_expr() const
{
      return cond_;
}

const NetExpr* NetETernary::true_expr() const
{
      return true_val_;
}

const NetExpr* NetETernary::false_expr() const
{
      return false_val_;
}

ivl_variable_type_t NetETernary::expr_type() const
{
      ivl_assert(*this, true_val_);
      ivl_assert(*this, false_val_);

	// IEEE 1800-2017 11.4.11: two operands of the same enumeration
	// type make the conditional expression that enumeration type.  In
	// particular, a 4-state condition does not change a default-base
	// (2-state int) enum into an untyped 4-state vector.  Returning LOGIC
	// here caused the generic context conversion to wrap the expression in
	// NetECast('2'), which preserved the value conversion but discarded the
	// enumeration identity reported by enumeration().  The subsequent
	// assignment check then incorrectly required an explicit cast for the
	// common `state = cond ? A : B' form.  Keep the enum's base type here;
	// enumeration() remains strict and returns null unless both arms name
	// the exact same enum type.
	if (const netenum_t*enum_type = enumeration())
	      return enum_type->base_type();

      ivl_variable_type_t tru = true_val_->expr_type();
      ivl_variable_type_t fal = false_val_->expr_type();
      ivl_variable_type_t sel = cond_->expr_type();
      if (tru == IVL_VT_LOGIC && fal == IVL_VT_BOOL)
	    return IVL_VT_LOGIC;
      if (tru == IVL_VT_BOOL && fal == IVL_VT_LOGIC)
	    return IVL_VT_LOGIC;
      if (sel == IVL_VT_LOGIC && (tru == IVL_VT_LOGIC || tru == IVL_VT_BOOL) && (fal == IVL_VT_LOGIC || fal == IVL_VT_BOOL))
	    return IVL_VT_LOGIC;
      if (tru == IVL_VT_REAL && (fal == IVL_VT_LOGIC || fal == IVL_VT_BOOL))
	    return IVL_VT_REAL;
      if (fal == IVL_VT_REAL && (tru == IVL_VT_LOGIC || tru == IVL_VT_BOOL))
	    return IVL_VT_REAL;

      if (tru != fal) {
	    cerr << get_fileline() << ": internal error:"
		 << " Unexpected ?: type clash:"
		 << " tru=" << tru << ", fal=" << fal << endl;
      }
      ivl_assert(*this, tru == fal);
      return tru;
}

NetEUnary::NetEUnary(char op__, NetExpr*ex, unsigned wid, bool signed_flag)
: NetExpr(wid), op_(op__), expr_(ex)
{
      cast_signed_base_(signed_flag);
}

NetEUnary::~NetEUnary()
{
      delete expr_;
}

ivl_variable_type_t NetEUnary::expr_type() const
{
      return expr_->expr_type();
}

NetEUBits::NetEUBits(char op__, NetExpr*ex, unsigned wid, bool signed_flag)
: NetEUnary(op__, ex, wid, signed_flag)
{
}

NetEUBits::~NetEUBits()
{
}

NetEUReduce::NetEUReduce(char op__, NetExpr*ex)
: NetEUnary(op__, ex, 1, false)
{
}

NetEUReduce::~NetEUReduce()
{
}

ivl_variable_type_t NetEUReduce::expr_type() const
{
      /* Logical NOT and reduction operators produce a one-bit unsigned
       * integral result; they do not retain an object/container operand's
       * type. A four-state operand can still produce X, while every other
       * accepted operand shape has a two-state result. */
      return expr_->expr_type() == IVL_VT_LOGIC
	    ? IVL_VT_LOGIC : IVL_VT_BOOL;
}

NetECast::NetECast(char op__, NetExpr*ex, unsigned wid, bool signed_flag)
: NetEUnary(op__, ex, wid, signed_flag)
{
}

NetECast::~NetECast()
{
}

ivl_variable_type_t NetECast::expr_type() const
{
      ivl_variable_type_t ret = IVL_VT_NO_TYPE;
      switch (op_) {
	  case 'v':
	    ret = IVL_VT_LOGIC;
	    break;
	  case 'r':
	    ret = IVL_VT_REAL;
	    break;
	  case '2':
	    ret = IVL_VT_BOOL;
	    break;
	  default:
	    ivl_assert(*this, 0);
      }

      return ret;
}

NetLogic::NetLogic(NetScope*s, perm_string n, unsigned pins,
		   TYPE t, unsigned wid, bool is_cassign__)
: NetNode(s, n, pins), type_(t), width_(wid), is_cassign_(is_cassign__)
{
      pin(0).set_dir(Link::OUTPUT);
      for (unsigned idx = 1 ;  idx < pins ;  idx += 1) {
	    pin(idx).set_dir(Link::INPUT);
      }
}

NetLogic::TYPE NetLogic::type() const
{
      return type_;
}

unsigned NetLogic::width() const
{
      return width_;
}

bool NetLogic::is_cassign() const
{
      return is_cassign_;
}

NetUReduce::NetUReduce(NetScope*scope__, perm_string n,
		       NetUReduce::TYPE t, unsigned wid)
: NetNode(scope__, n, 2), type_(t), width_(wid)
{
      pin(0).set_dir(Link::OUTPUT);
      pin(1).set_dir(Link::INPUT);
}

NetUReduce::TYPE NetUReduce::type() const
{
      return type_;
}

unsigned NetUReduce::width() const
{
      return width_;
}

NetTaskDef::NetTaskDef(NetScope*n, const vector<NetNet*>&po, const vector<NetExpr*>&pd)
: NetBaseDef(n, po, pd)
{
}

NetTaskDef::~NetTaskDef()
{
      delete proc_;
}

/*
 * These are the delay_type() functions. They are used to determine
 * the type of delay for the given object.
 */

/*
 * This function implements the following table:
 *
 * in_A  in_B   out
 *   NO    NO    NO
 *   NO  ZERO  ZERO
 *   NO   POS   POS
 *   NO   DEF   POS
 * ZERO    NO  ZERO
 * ZERO  ZERO  ZERO
 * ZERO   POS   POS
 * ZERO   DEF   POS
 *  POS    NO   POS
 *  POS  ZERO   POS
 *  POS   POS   POS
 *  POS   DEF   POS
 *  DEF    NO   POS
 *  DEF  ZERO   POS
 *  DEF   POS   POS
 *  DEF   DEF   DEF
 *
 * It is used to combine two delay values.
 */
static DelayType combine_delays(const DelayType a, const DelayType b)
{
	/* The default is POSSIBLE_DELAY. */
      DelayType result = POSSIBLE_DELAY;

	/* If both are no or zero delay then we return ZERO_DELAY. */
      if ((a == NO_DELAY || a == ZERO_DELAY) &&
          (b == NO_DELAY || b == ZERO_DELAY)) {
	    result = ZERO_DELAY;
      }

	/* Except if both are no delay then we return NO_DELAY. */
      if (a == NO_DELAY && b == NO_DELAY) {
	    result = NO_DELAY;
      }

	/* If both are definite delay then we return DEFINITE_DELAY. */
      if (a == DEFINITE_DELAY && b == DEFINITE_DELAY) {
	    result = DEFINITE_DELAY;
      }

      return result;
}

/*
 * This is used to see what we can find out about the delay when it
 * is given as an expression. We also use this for loop expressions.
 */
static DelayType delay_type_from_expr(const NetExpr*expr)
{
      DelayType result = POSSIBLE_DELAY;

      if (const NetEConst*e = dynamic_cast<const NetEConst*>(expr)) {
	    if (e->value().is_zero()) result = ZERO_DELAY;
	    else result = DEFINITE_DELAY;
      }

      if (const NetECReal*e = dynamic_cast<const NetECReal*>(expr)) {
	    if (e->value().as_double() == 0.0) result = ZERO_DELAY;
	    else result = DEFINITE_DELAY;
      }

      return result;
}

/*
 * The looping structures can use the same basic code so put it here
 * instead of duplicating it for each one (repeat and while).
 */
static DelayType get_loop_delay_type(const NetExpr*expr, const NetProc*proc, bool print_delay)
{
      DelayType result;

      switch (delay_type_from_expr(expr)) {
	    /* We have a constant false expression so the body never runs. */
	  case ZERO_DELAY:
	    result = NO_DELAY;
	    break;
	    /* We have a constant true expression so the body always runs. */
	  case DEFINITE_DELAY:
	    if (proc) {
		  result = proc->delay_type(print_delay);
	    } else {
		  result = NO_DELAY;
	    }
	    break;
	    /* We don't know if the body will run so reduce a DEFINITE_DELAY
	     * to a POSSIBLE_DELAY. All other stay the same. */
	  case POSSIBLE_DELAY:
	    if (proc) {
		  result = combine_delays(NO_DELAY, proc->delay_type(print_delay));
	    } else {
		  result = NO_DELAY;
	    }
	    break;
	    /* This should never happen since delay_type_from_expr() only
	     * returns three different values. */
	  default:
	    result = NO_DELAY;
	    ivl_assert(*expr, 0);
      }

      return result;
}

/* The default object does not have any delay. */
DelayType NetProc::delay_type(bool /* print_delay */ ) const
{
      return NO_DELAY;
}

DelayType NetBlock::delay_type(bool print_delay) const
{
	// A join_none has no delay.
      if (type() == PARA_JOIN_NONE) return NO_DELAY;

      DelayType result;
	// A join_any has the minimum delay.
      if (type() == PARA_JOIN_ANY) {
	    result = DEFINITE_DELAY;
	    for (const NetProc*cur = proc_first(); cur; cur = proc_next(cur)) {
		  DelayType dt = cur->delay_type(print_delay);
		  if (dt < result) result = dt;
		  if ((dt == NO_DELAY) && !print_delay) break;
	    }

	// A begin or join has the maximum delay.
      } else {
	    result = NO_DELAY;
	    for (const NetProc*cur = proc_first(); cur; cur = proc_next(cur)) {
		  DelayType dt = cur->delay_type(print_delay);
		  if (dt > result) result = dt;
		  if ((dt == DEFINITE_DELAY) && !print_delay) break;
	    }
      }

      return result;
}

DelayType NetCase::delay_type(bool print_delay) const
{
      DelayType result = NO_DELAY;
      bool def_stmt = false;
      unsigned nstmts = nitems();

      for (unsigned idx = 0; idx < nstmts; idx += 1) {
	    if (!expr(idx)) def_stmt = true;
	    DelayType dt = stat(idx) ? stat(idx)->delay_type(print_delay) : NO_DELAY;
            if (idx == 0) {
		  result = dt;
            } else {
		  result = combine_delays(result, dt);
            }
      }

// FIXME: If all the cases are covered (e.g. an enum) then this is not true.
	/* If we don't have a default statement we don't know for sure
	 * that we have a delay. */
      if (!def_stmt) result = combine_delays(NO_DELAY, result);

      return result;
}

DelayType NetCondit::delay_type(bool print_delay) const
{
      DelayType if_type = if_  ? if_->delay_type(print_delay)   : NO_DELAY;
      DelayType el_type = else_? else_->delay_type(print_delay) : NO_DELAY;
      return combine_delays(if_type, el_type);
}

/*
 * A do/while will execute the body at least once.
 */
DelayType NetDoWhile::delay_type(bool print_delay) const
{
      if (proc_) return proc_->delay_type(print_delay);

      return ZERO_DELAY;
}

DelayType NetEvWait::delay_type(bool print_delay) const
{
      if (print_delay) {
	    cerr << get_fileline() << ": error: an event control is not allowed "
	            "in an always_comb, always_ff or always_latch process."
	         << endl;
      }

      return DEFINITE_DELAY;
}

DelayType NetForever::delay_type(bool print_delay) const
{
      if (statement_) return statement_->delay_type(print_delay);

      return ZERO_DELAY;
}

DelayType NetForLoop::delay_type(bool print_delay) const
{
      return get_loop_delay_type(condition_, statement_, print_delay);
}

DelayType NetPDelay::delay_type(bool print_delay) const
{
      if (print_delay) {
	    cerr << get_fileline() << ": error: a blocking delay is not allowed "
	            "in an always_comb, always_ff or always_latch process."
	         << endl;
      }

      if (expr_) {
	    if (statement_) {
		  return combine_delays(delay_type_from_expr(expr_),
		                        statement_->delay_type(print_delay));
	    } else {
		  return delay_type_from_expr(expr_);
	    }
      }

      if (delay() > 0) return DEFINITE_DELAY;

      if (statement_) {
	    return combine_delays(ZERO_DELAY,
	                          statement_->delay_type(print_delay));
      } else {
	    return ZERO_DELAY;
      }
}

DelayType NetRepeat::delay_type(bool print_delay) const
{
      return get_loop_delay_type(expr_, statement_, print_delay);
}

DelayType NetTaskDef::delay_type(bool print_delay) const
{
      if (proc_) {
	    return proc_->delay_type(print_delay);
      } else {
	    return NO_DELAY;
      }
}

DelayType NetUTask::delay_type(bool print_delay) const
{
	// Is this a void function call in a final block?
      if (task()->type() == NetScope::FUNC) {
	    return NO_DELAY;
      } else {
	    return task()->task_def()->delay_type(print_delay);
      }
}

static bool do_expr_event_match(const NetExpr*expr, const NetEvWait*evwt)
{
	// The event wait should only have a single event.
      if (evwt->nevents() != 1) return false;
	// The event should have a single probe.
      const NetEvent *evt = evwt->event(0);
      if (evt->nprobe() != 1) return false;
	// The probe should be for any edge.
      const NetEvProbe *prb = evt->probe(0);
      if (prb->edge() != NetEvProbe::ANYEDGE) return false;
	// Create a NexusSet from the event probe signals.
      NexusSet *ns_evwt = new NexusSet;
      for (unsigned idx =0; idx < prb->pin_count(); idx += 1) {
	    if (! prb->pin(idx).is_linked()) {
		  delete ns_evwt;
		  return false;
	    }
	      // Casting away const is safe since this nexus set is only being read.
	    ns_evwt->add(const_cast<Nexus*> (prb->pin(idx).nexus()),
	                 0, prb->pin(idx).nexus()->vector_width());
      }
	// Get the NexusSet for the expression.
      NexusSet *ns_expr = expr->nex_input();
	// Make sure the event and expression NexusSets match exactly.
      if (ns_evwt->size() != ns_expr->size()) {
	    delete ns_evwt;
	    delete ns_expr;
	    return false;
      }
      ns_expr->rem(*ns_evwt);
      delete ns_evwt;
      if (ns_expr->size() != 0) {
	    delete ns_expr;
	    return false;
      }
      delete ns_expr;

      return true;
}

static bool while_is_wait(const NetExpr*expr, const NetProc*stmt)
{
      if (const NetEvWait*evwt = dynamic_cast<const NetEvWait*>(stmt)) {
	    if (evwt->statement()) return false;
	    const NetEBComp*cond = dynamic_cast<const NetEBComp*>(expr);
	    if (! cond) return false;
	    if (cond->op() != 'N') return false;
	    const NetEConst*cval = dynamic_cast<const NetEConst*>(cond->right());
	    if (! cval) return false;
	    const verinum val = cval->value();
	    if (val.len() != 1) return false;
	    if (val.get(0) != verinum::V1) return false;
	    if (! do_expr_event_match(cond->left(), evwt)) return false;
	    if (evwt->get_lineno() != cond->get_lineno()) return false;
	    if (evwt->get_file() != cond->get_file()) return false;
	    return true;
      }
      return false;
}

DelayType NetWhile::delay_type(bool print_delay) const
{
	// If the wait was a constant value the compiler already removed it
	// so we know we can only have a possible delay.
      if (while_is_wait(cond_, proc_)) {
	    if (print_delay) {
		  cerr << get_fileline() << ": error: a wait statement is "
		          "not allowed in an "
		          "always_comb, always_ff or always_latch process."
		       << endl;
	    }
	    return POSSIBLE_DELAY;
      }
      return get_loop_delay_type(cond_, proc_, print_delay);
}

/*
 * These are the check_synth() functions. They are used to print
 * a warning if the item is not synthesizable.
 */
static const char * get_process_type_as_string(ivl_process_type_t pr_type)
{
      switch (pr_type) {
	case IVL_PR_ALWAYS_COMB:
	    return "in an always_comb process.";
	    break;
	case IVL_PR_ALWAYS_FF:
	    return "in an always_ff process.";
	    break;
	case IVL_PR_ALWAYS_LATCH:
	    return "in an always_latch process.";
	    break;
	default:
	    assert(0);
	    return 0;
      }
}

static void print_synth_warning(const NetProc *net_proc, const char *name,
                              ivl_process_type_t pr_type)
{
      cerr << net_proc->get_fileline() << ": warning: " << name
           << " statement cannot be synthesized "
           << get_process_type_as_string(pr_type) << endl;
}

static void check_if_logic_l_value(const NetAssignBase *base,
                                   ivl_process_type_t pr_type)
{
      if (base->l_val_count() != 1) return;

      const NetAssign_*lval = base->l_val(0);
      if (! lval) return;

      const ivl_variable_type_t type = lval->expr_type();
      if (type == IVL_VT_NO_TYPE) return;

	// Class, interface and struct member l-values retain the root
	// carrier in sig(), but synthesis legality is determined by the
	// selected member. NetAssign_::expr_type() resolves that complete
	// l-value path, including indexed elements and packed selects.
      if ((type != IVL_VT_BOOL) && (type != IVL_VT_LOGIC)) {
	    const NetAssign_*object = lval;
	    while (object->nest()) object = object->nest();
	    const perm_string name = object->name();
	    cerr << base->get_fileline() << ": warning: Assigning to a "
	            "non-integral variable (" << name
	         << ") cannot be synthesized "
	         << get_process_type_as_string(pr_type) << endl;
      }
}

/* By default elements can be synthesized or ignored. */
bool NetProc::check_synth(ivl_process_type_t /* pr_type */,
                          const NetScope* /* scope */ ) const
{
      return false;
}

// FIXME: User function calls still need to be checked (NetEUFunc).
//      : Non-constant system functions need a warning (NetESFunc).
//      : Constant functions should already be elaborated.

bool NetAssign::check_synth(ivl_process_type_t pr_type,
                            const NetScope* /* scope */ ) const
{
      check_if_logic_l_value(this, pr_type);

// FIXME: Check that ff/latch only use this for internal signals.
      return false;
}

bool NetAssignNB::check_synth(ivl_process_type_t pr_type,
                              const NetScope* /* scope */ ) const
{
      bool result = false;
      if (pr_type == IVL_PR_ALWAYS_COMB) {
	    cerr << get_fileline() << ": warning: A non-blocking assignment "
	            "should not be used in an always_comb process." << endl;
      }

      if (event_) {
	    cerr << get_fileline() << ": error: A non-blocking assignment "
	            "cannot be synthesized with an event control "
	         << get_process_type_as_string(pr_type) << endl;
	    result = true;
      }

      check_if_logic_l_value(this, pr_type);

      return result;
}

bool NetBlock::check_synth(ivl_process_type_t pr_type,
                           const NetScope* scope) const
{
      bool result = false;
	// Only a begin/end can be synthesized.
      if (type() != SEQU) {
	    cerr << get_fileline() << ": error: A fork/";
	    switch (type()) {
	      case PARA:
		  cerr << "join";
		  break;
	      case PARA_JOIN_ANY:
		  cerr << "join_any";
		  break;
	      case PARA_JOIN_NONE:
		  cerr << "join_none";
		  break;
	      default:
		  ivl_assert(*this, 0);
	    }
	    cerr << " statement cannot be synthesized "
                 << get_process_type_as_string(pr_type) << endl;
	    result = true;
      }

      const NetScope*save_scope = scope;
      if (subscope()) scope = subscope();
      if (scope != save_scope) {
	    result |= scope->check_synth(pr_type, scope);
      }
      for (const NetProc*cur = proc_first(); cur; cur = proc_next(cur)) {
	    result |= cur->check_synth(pr_type, scope);
      }
      return result;
}

bool NetCase::check_synth(ivl_process_type_t pr_type,
                          const NetScope* scope) const
{
      bool result = false;
      for (unsigned idx = 0; idx < nitems(); idx += 1) {
	    if (stat(idx)) result |= stat(idx)->check_synth(pr_type, scope);
      }
// FIXME: Check for ff/latch/comb structures.
      return result;
}

bool NetCAssign::check_synth(ivl_process_type_t pr_type,
                             const NetScope* /* scope */ ) const
{
      print_synth_warning(this, "A procedural assign", pr_type);
      return false;
}

bool NetCondit::check_synth(ivl_process_type_t pr_type,
                            const NetScope* scope) const
{
      bool result = false;
      if (if_) result |= if_->check_synth(pr_type, scope);
      if (else_) result |= else_->check_synth(pr_type, scope);
// FIXME: Check for ff/latch/comb structures.
      return result;
}

bool NetDeassign::check_synth(ivl_process_type_t pr_type,
                              const NetScope* /* scope */ ) const
{
      print_synth_warning(this, "A procedural deassign", pr_type);
      return false;
}

bool NetDisable::check_synth(ivl_process_type_t pr_type,
                             const NetScope* scope) const
{
      while (scope) {
	    if (scope != target_) scope = scope->parent();
	    else break;
      }


      if (! scope) {
	    cerr << get_fileline() << ": warning: A disable statement can "
	            "only be synthesized when disabling an enclosing block "
                 << get_process_type_as_string(pr_type) << endl;
      }
      return false;
}

bool NetDoWhile::check_synth(ivl_process_type_t pr_type,
                             const NetScope* scope) const
{
      bool result = false;
      print_synth_warning(this, "A do/while", pr_type);
      if (proc_) result |= proc_->check_synth(pr_type, scope);
      return result;
}

bool NetEvTrig::check_synth(ivl_process_type_t pr_type,
                            const NetScope* /* scope */ ) const
{
      print_synth_warning(this, "An event trigger", pr_type);
      return false;
}

bool NetEvNBTrig::check_synth(ivl_process_type_t pr_type,
                              const NetScope* /* scope */ ) const
{
      print_synth_warning(this, "A non-blocking event trigger", pr_type);
      return false;
}

// The delay check above has already marked this as an error.
bool NetEvWait::check_synth(ivl_process_type_t pr_type,
                            const NetScope* scope) const
{
      bool result = false;
      if (statement_) result |= statement_->check_synth(pr_type, scope);
      return result;
}

bool NetForce::check_synth(ivl_process_type_t pr_type,
                           const NetScope* /* scope */ ) const
{
      print_synth_warning(this, "A force", pr_type);
      return false;
}

bool NetForever::check_synth(ivl_process_type_t pr_type,
                             const NetScope* scope) const
{
      bool result = false;
      print_synth_warning(this, "A forever", pr_type);
      if (statement_) result |= statement_->check_synth(pr_type, scope);
      return result;
}

/*
 * A bunch of private routines to verify that a for loop has the correct
 * structure for synthesis.
 */
static void print_for_idx_warning(const NetProc*proc, const char*check,
                                  ivl_process_type_t pr_type, const NetNet*idx)
{
      cerr << proc->get_fileline() << ": warning: A for statement must use "
              "the index (" << idx->name() << ") in the " << check
           << " expression to be synthesized "
           << get_process_type_as_string(pr_type) << endl;
}

static void check_for_const_synth(const NetExpr*expr, const NetProc*proc,
                                  const char*str, ivl_process_type_t pr_type)
{
      if (! dynamic_cast<const NetEConst*>(expr)) {
	    cerr << proc-> get_fileline() << ": warning: A for "
	            "statement must " << str
	         << " value to be synthesized "
	         << get_process_type_as_string(pr_type) << endl;
      }
}

static void check_for_bin_synth(const NetExpr*left,const NetExpr*right,
                                const char*str, const char*check,
                                const NetProc*proc,
                                ivl_process_type_t pr_type, const NetNet*index,
				bool allow_runtime_bound = false)
{
      const NetESignal*lsig = dynamic_cast<const NetESignal*>(left);
      const NetESignal*rsig = dynamic_cast<const NetESignal*>(right);

      if (!lsig) {
            const NetESelect*lsel = dynamic_cast<const NetESelect*>(left);
            if (lsel && (lsel->expr_width() >= lsel->sub_expr()->expr_width()))
                  lsig = dynamic_cast<const NetESignal*>(lsel->sub_expr());
      }
      if (!rsig) {
            const NetESelect*rsel = dynamic_cast<const NetESelect*>(right);
            if (rsel && (rsel->expr_width() >= rsel->sub_expr()->expr_width()))
                  rsig = dynamic_cast<const NetESignal*>(rsel->sub_expr());
      }

      if (lsig && (lsig->sig() == index)) {
	    if (!allow_runtime_bound)
		  check_for_const_synth(right, proc, str, pr_type);
      } else if (rsig && (rsig->sig() == index)) {
	    if (!allow_runtime_bound)
		  check_for_const_synth(left, proc, str, pr_type);
      } else {
	    print_for_idx_warning(proc, check, pr_type, index);
      }
}

static void print_for_step_warning(const NetProc*proc,
                                   ivl_process_type_t pr_type)
{
      cerr << proc->get_fileline() << ": warning: A for statement step must "
              "be a simple assignment statement to be synthesized "
           << get_process_type_as_string(pr_type) << endl;
}

static void print_for_step_warning(const NetProc*proc,
                                   ivl_process_type_t pr_type, const NetNet*idx)
{
      cerr << proc->get_fileline() << ": warning: A for statement step must "
              "be an assignment to the index variable ("
           << idx->name() << ") to be synthesized "
           << get_process_type_as_string(pr_type) << endl;
}

static void check_for_bstep_synth(const NetExpr*expr, const NetProc*proc,
                                  ivl_process_type_t pr_type, const NetNet*index)
{
      if (const NetECast*tmp = dynamic_cast<const NetECast*>(expr)) {
	    expr = tmp->expr();
      }

      if (const NetEBAdd*tmp = dynamic_cast<const NetEBAdd*>(expr)) {
	    check_for_bin_synth(tmp->left(), tmp->right(),
                                "change by a constant", "step", proc, pr_type,
	                        index);
      } else {
	    cerr << proc->get_fileline() << ": warning: A for statement "
	            "step must be a simple binary +/- "
	            "to be synthesized "
	         << get_process_type_as_string(pr_type) << endl;
      }
}

static void check_for_step_synth(const NetAssign*assign, const NetProc*proc,
                                 ivl_process_type_t pr_type, const NetNet*index)
{
      if (assign->l_val_count() != 1) {
	    print_for_step_warning(proc, pr_type);
      } else if (assign->l_val(0)->sig() != index) {
	    print_for_step_warning(proc, pr_type, index);
      } else {
	    switch (assign->assign_operator()) {
	      case '+':
	      case '-':
		    check_for_const_synth(assign->rval(), proc,
		                          "have a constant step", pr_type);
		    break;
	      case 0:
		    check_for_bstep_synth(assign->rval(), proc, pr_type, index);
		    break;
	     default:
		    cerr << proc->get_fileline() << ": warning: A for statement "
		            "step does not support operator '"
		         << assign->assign_operator()
                         << "' it must be +/- to be synthesized "
		         << get_process_type_as_string(pr_type) << endl;
		   break;
	    }
      }
}

bool NetForLoop::check_synth(ivl_process_type_t pr_type,
                             const NetScope* scope) const
{
      bool result = false;

// FIXME: What about an enum (NetEConstEnum)?
      if (! dynamic_cast<const NetEConst*>(init_expr_)) {
	    cerr << get_fileline() << ": warning: A for statement must "
	            "have a constant initial value to be synthesized "
                 << get_process_type_as_string(pr_type) << endl;
      }

// FIXME: Do the following also need to be supported in the condition?
//        It would seem like they are hard to use to find the bounds.
//          From NetEBinary
//            What about NetEBits sig & constant, etc.
//          From NetEUnary
//            What about NetEUBits ! sig or ! (sig == constat)
//            What about NetEUReduce &signal
      if (const NetESignal*tmp = dynamic_cast<const NetESignal*>(condition_)) {
	    if (tmp->sig() != index_) {
		  print_for_idx_warning(this, "condition", pr_type, index_);
	    }
      } else if (const NetEBComp*cmp = dynamic_cast<const NetEBComp*>(condition_)) {
	    check_for_bin_synth(cmp->left(), cmp->right(),
                                "compare against a constant", "condition",
	                        this, pr_type, index_, true);
      } else {
	    print_for_idx_warning(this, "condition", pr_type, index_);
      }

      if (const NetAssign*tmp = dynamic_cast<const NetAssign*>(step_statement_)) {
	    check_for_step_synth(tmp, this, pr_type, index_);
      } else {
	    print_for_step_warning(this, pr_type);
      }

      if (statement_) result |= statement_->check_synth(pr_type, scope);
      return result;
}

bool NetRelease::check_synth(ivl_process_type_t pr_type,
                             const NetScope* /* scope */ ) const
{
      print_synth_warning(this, "A release", pr_type);
      return false;
}

bool NetRepeat::check_synth(ivl_process_type_t pr_type,
                            const NetScope* scope) const
{
      bool result = false;
      print_synth_warning(this, "A repeat", pr_type);
      if (statement_) result |= statement_->check_synth(pr_type, scope);
      return result;
}

bool NetScope::check_synth(ivl_process_type_t pr_type,
                           const NetScope* /* scope */) const
{
      bool result = false;
	// Skip local events/signals
      for (const NetEvent*cur = events_ ;  cur ;  cur = cur->snext_) {
	    if (cur->local_flag()) continue;
	    cerr << cur->get_fileline() << ": warning: An event ("
	         << cur->name() << ") cannot be synthesized "
	         << get_process_type_as_string(pr_type) << endl;
      }
      for (signals_map_iter_t cur = signals_map_.begin();
           cur != signals_map_.end() ; ++ cur) {
	    const NetNet*sig = cur->second;
	    if ((sig->data_type() != IVL_VT_BOOL) &&
	        (sig->data_type() != IVL_VT_LOGIC)) {
		  cerr << sig->get_fileline() << ": warning: A non-integral "
		          "variable (" << sig->name() << ") cannot be "
		          "synthesized "
		       << get_process_type_as_string(pr_type) << endl;
	    }
      }
      return result;
}

bool NetSTask::check_synth(ivl_process_type_t pr_type,
                           const NetScope* /* scope */) const
{
      if (assertion_action_)
	    return false;

      if (strcmp(name(), "$ivl_darray_method$delete") == 0) {
	    cerr << get_fileline() << ": warning: Dynamic array "
	            "delete method cannot be synthesized "
	         << get_process_type_as_string(pr_type) << endl;
      } else {
	    cerr << get_fileline() << ": warning: System task ("
	         << name() << ") cannot be synthesized "
	         << get_process_type_as_string(pr_type) << endl;
      }
      return false;
}

/*
 * This function is called to make sure the task/function can be used
 * in a context where it must be synthesizable, such as in an always_comb
 * or always_ff.
 *
 * If this is a function, then the function must be void.
 */
bool NetBaseDef::check_synth(ivl_process_type_t pr_type,
                             const NetScope* /* scope */) const
{
      bool result = false;
      const NetScope *tscope = this->scope();
      result |= tscope->check_synth(pr_type, tscope);
      if (! tscope->is_auto()) {
	    cerr << tscope->get_def_file() << ":"
	         << tscope->get_def_lineno()
	         << ": warning: user task (" << tscope->basename()
	         << ") must be automatic to be synthesized "
	         << get_process_type_as_string(pr_type) << endl;
      }
      if (proc_) result |= proc_->check_synth(pr_type, tscope);
      return result;
}

bool NetUTask::check_synth(ivl_process_type_t pr_type,
                           const NetScope* scope) const
{
      const NetScope* task_scope = task();
      if (task_scope->type() == NetScope::FUNC) {
	    // This can happen if this a void function.
	    return task_scope->func_def()->check_synth(pr_type, scope);
      } else {
	    return task_scope->task_def()->check_synth(pr_type, scope);
      }
}

bool NetWhile::check_synth(ivl_process_type_t pr_type,
                           const NetScope* scope) const
{
      bool result = false;
	// A wait is already maked as an error in the delay check above.
      if (! while_is_wait(cond_, proc_)) {
	    print_synth_warning(this, "A while", pr_type);
	    if (proc_) result |= proc_->check_synth(pr_type, scope);
      }
      return result;
}
