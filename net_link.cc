/*
 * Copyright (c) 2000-2026 Stephen Williams (steve@icarus.com)
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

# include  <iostream>
# include  <algorithm>
# include  <cstdint>
# include  <unordered_map>

# include  "netlist.h"
# include  <sstream>
# include  <cstring>
# include  <string>
# include  <typeinfo>
# include  <cstdlib>
# include  "ivl_alloc.h"
# include  "ivl_assert.h"

using namespace std;

namespace {

// A Nexus identity can change when two link rings are joined. Such a join
// always deletes the superseded Nexus, so this generation lets auxiliary
// indexes notice stale identities without adding bookkeeping to every
// connect path.
uint64_t nexus_identity_generation = 0;

}

void Nexus::connect(Link&r)
{
      Nexus*r_nexus = r.next_? r.find_nexus_() : NULL;
      if (this == r_nexus)
	    return;

      delete[] name_;
      name_ = 0;

	// Special case: This nexus is empty. Simply copy all the
	// links of the other nexus to this one, and delete the old
	// nexus.
      if (list_ == 0) {
	    if (r.next_ == 0) {
		  list_ = &r;
		  r.next_ = &r;
		  r.nexus_ = this;
		  driven_ = NO_GUESS;
	    } else {
		  driven_ = r_nexus->driven_;
		  synthesized_process_driver_mask_.swap(
			r_nexus->synthesized_process_driver_mask_);
		  pre_synthesis_driver_mask_.swap(
			r_nexus->pre_synthesis_driver_mask_);
		  synthesized_process_variable_type_ =
			r_nexus->synthesized_process_variable_type_;
		  list_ = r_nexus->list_;
		  list_->nexus_ = this;
		  r_nexus->list_ = 0;
		  delete r_nexus;
	    }
	    return;
      }

	// Special case: The Link is unconnected. Put it at the end of
	// the current list and move the list_ pointer and nexus_ back
	// pointer to suit.
      if (r.next_ == 0) {
	    if (r.get_dir() != Link::INPUT)
		  driven_ = NO_GUESS;

	    r.nexus_ = this;
	    r.next_ = list_->next_;
	    list_->next_ = &r;
	    list_->nexus_ = 0;
	    list_ = &r;
	    return;
      }

      if (r_nexus->driven_ != Vz)
	    driven_ = NO_GUESS;

      if (synthesized_process_driver_mask_.size()
		  < r_nexus->synthesized_process_driver_mask_.size())
	    synthesized_process_driver_mask_.resize(
		  r_nexus->synthesized_process_driver_mask_.size(), false);
      for (unsigned bit = 0;
	   bit < r_nexus->synthesized_process_driver_mask_.size(); bit += 1)
	    synthesized_process_driver_mask_[bit] =
		  synthesized_process_driver_mask_[bit]
		  || r_nexus->synthesized_process_driver_mask_[bit];

      if (pre_synthesis_driver_mask_.size()
		  < r_nexus->pre_synthesis_driver_mask_.size())
	    pre_synthesis_driver_mask_.resize(
		  r_nexus->pre_synthesis_driver_mask_.size(), false);
      for (unsigned bit = 0;
	   bit < r_nexus->pre_synthesis_driver_mask_.size(); bit += 1)
	    pre_synthesis_driver_mask_[bit] =
		  pre_synthesis_driver_mask_[bit]
		  || r_nexus->pre_synthesis_driver_mask_[bit];

      if (synthesized_process_variable_type_ == IVL_VT_NO_TYPE) {
	    synthesized_process_variable_type_ =
		  r_nexus->synthesized_process_variable_type_;
      } else if (r_nexus->synthesized_process_variable_type_
		       != IVL_VT_NO_TYPE) {
	    assert(synthesized_process_variable_type_
		  == r_nexus->synthesized_process_variable_type_);
      }

	// Splice the list of links from the "tmp" nexus to the end of
	// this nexus. Adjust the nexus pointers as needed.
      Link*save_first = list_->next_;
      list_->next_ = r_nexus->list_->next_;
      r_nexus->list_->next_ = save_first;
      list_->nexus_ = 0;
      list_ = r_nexus->list_;
      list_->nexus_ = this;

      r_nexus->list_ = 0;
      delete r_nexus;
}

void connect(Link&l, Link&r)
{
      Nexus*tmp;
      assert(&l != &r);
	// If either the l or r link already are part of a Nexus, then
	// re-use that nexus. Go through some effort so that we are
	// not gratuitously creating Nexus object.
      if (l.next_ && (tmp=l.find_nexus_())) {
	    connect(tmp, r);
      } else if (r.next_ && (tmp=r.find_nexus_())) {
	    connect(tmp, l);
      } else {
	      // No existing Nexus (both links are so far unconnected)
	      // so start one.
	    tmp = new Nexus(l);
	    tmp->connect(r);
      }
}

Link::Link()
: dir_(PASSIVE), drive0_(IVL_DR_STRONG), drive1_(IVL_DR_STRONG),
  next_(0), nexus_(0)
{
      node_ = 0;
      pin_zero_ = true;
}

Link::~Link()
{
      if (next_) {
	    Nexus*tmp = nexus();
	    tmp->unlink(this);
	    if (tmp->list_ == 0)
		  delete tmp;
      }
}

Nexus* Link::find_nexus_() const
{
      assert(next_);
      if (nexus_) return nexus_;
      for (const Link*cur = next_ ; cur != this ; cur = cur->next_) {
	    if (cur->nexus_) return cur->nexus_;
      }
      return 0;
}

Nexus* Link::nexus()
{
      if (next_ == 0) {
	    assert(nexus_ == 0);
	    Nexus*tmp = new Nexus(*this);
	    return tmp;
      }

      return find_nexus_();
}

const Nexus* Link::nexus() const
{
      if (next_ == 0) return 0;
      return find_nexus_();
}

void Link::set_dir(DIR d)
{
      dir_ = d;
}

Link::DIR Link::get_dir() const
{
      return dir_;
}

void Link::drivers_delays(const NetExpr*rise, const NetExpr*fall, const NetExpr*decay)
{
      find_nexus_()->drivers_delays(rise, fall, decay);
}

void Link::drivers_drive(ivl_drive_t drive0__, ivl_drive_t drive1__)
{
      find_nexus_()->drivers_drive(drive0__, drive1__);
}


void Link::drive0(ivl_drive_t str)
{
      drive0_ = str;
}

void Link::drive1(ivl_drive_t str)
{
      drive1_ = str;
}

ivl_drive_t Link::drive0() const
{
      return drive0_;
}

ivl_drive_t Link::drive1() const
{
      return drive1_;
}

void Link::cur_link(NetPins*&net, unsigned &pin)
{
      net = get_obj();
      pin = get_pin();
}

void Link::cur_link(const NetPins*&net, unsigned &pin) const
{
      net = get_obj();
      pin = get_pin();
}

void Link::unlink()
{
      if (! is_linked())
	    return;

      find_nexus_()->unlink(this);
}

bool Link::is_equal(const Link&that) const
{
      return (get_obj() == that.get_obj()) && (get_pin() == that.get_pin());
}

bool Link::is_linked() const
{
      if (next_ == 0)
	    return false;
      if (next_ == this)
	    return false;

      return true;
}

bool Link::is_linked(const Link&that) const
{
	// If this or that link is linked to nothing, then they cannot
	// be linked to each other.
      if (! this->is_linked())
	    return false;
      if (! that.is_linked())
	    return false;

      const Link*cur = next_;
      while (cur != this) {
	    if (cur == &that) return true;
	    cur = cur->next_;
      }

      return false;
}

Nexus::Nexus(Link&that)
{
      name_ = 0;
      driven_ = NO_GUESS;
      t_cookie_ = 0;
      synthesized_process_variable_type_ = IVL_VT_NO_TYPE;

      if (that.next_ == 0) {
	    list_ = &that;
	    that.next_ = &that;
	    that.nexus_ = this;
	    driven_ = NO_GUESS;

      } else {
	    Nexus*tmp = that.find_nexus_();
	    list_ = tmp->list_;
	    list_->nexus_ = this;
	    driven_ = tmp->driven_;
	    name_ = tmp->name_;
	    synthesized_process_driver_mask_.swap(
		  tmp->synthesized_process_driver_mask_);
	    pre_synthesis_driver_mask_.swap(
		  tmp->pre_synthesis_driver_mask_);
	    synthesized_process_variable_type_ =
		  tmp->synthesized_process_variable_type_;

	    tmp->list_ = 0;
	    tmp->name_ = 0;
	    delete tmp;
      }
}

Nexus::~Nexus()
{
      assert(list_ == 0);
      delete[] name_;
      nexus_identity_generation += 1;
}

void Nexus::detach_all_links_()
{
      if (!list_)
            return;

      Link*first = list_->next_;
      Link*cur = first;
      do {
            Link*next = cur->next_;
            cur->next_ = 0;
            cur->nexus_ = 0;
            cur = next;
      } while (cur != first);
      list_ = 0;
}

bool Nexus::claim_synthesized_process_driver(unsigned base, unsigned wid)
{
      if (synthesized_process_driver_mask_.size() < base + wid)
	    synthesized_process_driver_mask_.resize(base + wid, false);

      bool overlap = false;
      for (unsigned bit = base; bit < base + wid; bit += 1) {
	    if (synthesized_process_driver_mask_[bit])
		  overlap = true;
	    synthesized_process_driver_mask_[bit] = true;
      }
      return overlap;
}

bool Nexus::has_synthesized_process_driver() const
{
      for (unsigned bit = 0; bit < synthesized_process_driver_mask_.size();
	   bit += 1) {
	    if (synthesized_process_driver_mask_[bit])
		  return true;
      }
      return false;
}

bool Nexus::has_synthesized_process_driver(unsigned bit) const
{
      return bit < synthesized_process_driver_mask_.size()
	    && synthesized_process_driver_mask_[bit];
}

void Nexus::synthesized_process_variable_type(ivl_variable_type_t type)
{
      assert(type != IVL_VT_NO_TYPE);
      if (synthesized_process_variable_type_ == IVL_VT_NO_TYPE) {
	    synthesized_process_variable_type_ = type;
	    return;
      }
      assert(synthesized_process_variable_type_ == type);
}

ivl_variable_type_t Nexus::synthesized_process_variable_type() const
{
      return synthesized_process_variable_type_;
}

void Nexus::capture_pre_synthesis_driver_mask()
{
      pre_synthesis_driver_mask_.assign(vector_width(), false);

      for (const Link*cur = first_nlink(); cur; cur = cur->next_nlink()) {
	    const NetPins*obj = cur->get_obj();
	    if (dynamic_cast<const NetTran*>(obj)) {
		  fill(pre_synthesis_driver_mask_.begin(),
		       pre_synthesis_driver_mask_.end(), true);
		  return;
	    }

	    if (cur->get_dir() == Link::PASSIVE) {
		  const NetNet*root_port = dynamic_cast<const NetNet*>(obj);
		  if (root_port && root_port->scope()->parent() == 0
		      && root_port->port_type() != NetNet::NOT_A_PORT
		      && root_port->port_type() != NetNet::POUTPUT) {
			fill(pre_synthesis_driver_mask_.begin(),
			     pre_synthesis_driver_mask_.end(), true);
			return;
		  }
		  continue;
	    }
	    if (cur->get_dir() != Link::OUTPUT)
		  continue;

	    if (const NetNet*sig = dynamic_cast<const NetNet*>(obj)) {
		  NetNet::Type type = sig->type();
		  if (type == NetNet::REG || type == NetNet::IMPLICIT_REG)
			continue;

		  fill(pre_synthesis_driver_mask_.begin(),
		       pre_synthesis_driver_mask_.end(), true);
		  return;
	    }

	    const NetPartSelect*part =
		  dynamic_cast<const NetPartSelect*>(obj);
	    if (!part) {
		  fill(pre_synthesis_driver_mask_.begin(),
		       pre_synthesis_driver_mask_.end(), true);
		  return;
	    }

	    if (part->dir() == NetPartSelect::VP) {
		  if (cur->get_pin() != 0)
			continue;
		  fill(pre_synthesis_driver_mask_.begin(),
		       pre_synthesis_driver_mask_.end(), true);
		  return;
	    }

	    if (cur->get_pin() != 1)
		  continue;
	    for (unsigned idx = 0; idx < part->width(); idx += 1) {
		  unsigned bit = part->base() + idx;
		  ivl_assert(*part, bit < pre_synthesis_driver_mask_.size());
		  pre_synthesis_driver_mask_[bit] = true;
	    }
      }
}

bool Nexus::has_pre_synthesis_driver(unsigned bit) const
{
      return bit < pre_synthesis_driver_mask_.size()
	    && pre_synthesis_driver_mask_[bit];
}

bool Nexus::assign_lval() const
{
      for (const Link*cur = first_nlink() ; cur ; cur = cur->next_nlink()) {

	    const NetPins*obj;
	    unsigned pin;
	    cur->cur_link(obj, pin);
	    const NetNet*net = dynamic_cast<const NetNet*> (obj);
	    if (net == 0)
		  continue;

	    if (net->peek_lref() > 0)
		  return true;
      }

      return false;
}

void Nexus::count_io(unsigned&inp, unsigned&out) const
{
      for (const Link*cur = first_nlink() ;  cur ; cur = cur->next_nlink()) {
	    switch (cur->get_dir()) {
		case Link::INPUT:
		  inp += 1;
		  break;
		case Link::OUTPUT:
		  out += 1;
		  break;
		default:
		  break;
	    }
      }
}

bool Nexus::has_floating_input() const
{
      bool found_input = false;
      for (const Link*cur = first_nlink() ;  cur ; cur = cur->next_nlink()) {
	    if (cur->get_dir() == Link::OUTPUT)
		  return false;

	    if (cur->get_dir() == Link::INPUT)
		  found_input = true;
      }

      return found_input;
}

bool Nexus::drivers_present() const
{
      for (const Link*cur = first_nlink() ;  cur ; cur = cur->next_nlink()) {
	    if (cur->get_dir() == Link::OUTPUT)
		  return true;

	    if (cur->get_dir() == Link::INPUT)
		  continue;

	      // Must be PASSIVE, so if it is some kind of net, see if
	      // it is the sort that might drive the nexus. Note that
	      // supply0/1 and tri0/1 nets are classified as OUTPUT.
	    const NetPins*obj;
	    unsigned pin;
	    cur->cur_link(obj, pin);
	    if (const NetNet*net = dynamic_cast<const NetNet*>(obj))
		  switch (net->type()) {
		      case NetNet::WAND:
		      case NetNet::WOR:
		      case NetNet::TRIAND:
		      case NetNet::TRIOR:
		      case NetNet::REG:
			return true;
		      default:
			break;
		  }
      }

      return false;
}

void Nexus::drivers_delays(const NetExpr*rise, const NetExpr*fall, const NetExpr*decay)
{
      for (Link*cur = first_nlink() ; cur ; cur = cur->next_nlink()) {
	    if (cur->get_dir() != Link::OUTPUT)
		  continue;

	    NetObj*obj = dynamic_cast<NetObj*>(cur->get_obj());
	    if (obj == 0)
		  continue;

	    obj->rise_time(rise);
	    obj->fall_time(fall);
	    obj->decay_time(decay);
      }
}

void Nexus::drivers_drive(ivl_drive_t drive0, ivl_drive_t drive1)
{
      for (Link*cur = first_nlink() ; cur ; cur = cur->next_nlink()) {
	    if (cur->get_dir() != Link::OUTPUT)
		  continue;

	    cur->drive0(drive0);
	    cur->drive1(drive1);
      }
}

void Nexus::unlink(Link*that)
{
      delete[] name_;
      name_ = 0;

      assert(that);

	// Special case: the Link is the only link in the nexus. In
	// this case, the unlink is trivial. Also clear the Nexus
	// pointers.
      if (that->next_ == that) {
	    assert(that->nexus_ == this);
	    assert(list_ == that);
	    list_ = 0;
	    driven_ = NO_GUESS;
	    that->nexus_ = 0;
	    that->next_ = 0;
	    return;
      }

	// If the link I'm removing was a driver for this nexus, then
	// cancel my guess of the driven value.
      if (that->get_dir() != Link::INPUT)
	    driven_ = NO_GUESS;

	// Look for the Link that points to "that". We know that there
	// will be one because the list is a circle. When we find the
	// prev pointer, then remove that from the list.
      Link*prev = list_;
      while (prev->next_ != that)
	    prev = prev->next_;

      prev->next_ = that->next_;

	// If "that" was the last item in the list, then change the
	// list_ pointer to point to the new end of the list.
      if (list_ == that) {
	    assert(that->nexus_ == this);
	    list_ = prev;
	    list_->nexus_ = this;
      }

      that->nexus_ = 0;
      that->next_ = 0;
}

Link* Nexus::first_nlink()
{
      if (list_) return list_->next_;
      else return 0;
}

const Link* Nexus::first_nlink() const
{
      if (list_) return list_->next_;
      else return 0;
}

/*
 * The t_cookie can be set exactly once. This attaches an ivl_nexus_t
 * object to the Nexus, and causes the Link list to be marked up for
 * efficient use by the code generator. The change is to give all the
 * links a valid nexus_ pointer. This breaks most of the other
 * methods, but they are not used during code generation.
*/
void Nexus::t_cookie(ivl_nexus_t val) const
{
      // Compile-progress fallback: SystemVerilog static class members
      // may be visited multiple times during code generation. Allow
      // idempotent re-assignment of the same cookie value.
      if (!val) {
	    cerr << "ERROR: Nexus::t_cookie called with NULL value"
		 << " for nexus " << this << endl;
	    cerr << "  Nexus name: " << name() << endl;
	    assert(val);
      }
      if (t_cookie_) {
	    // Already set - for SystemVerilog static class members,
	    // the same nexus may be visited multiple times from different
	    // code generation paths, potentially with different cookie values.
	    // This is a known issue with static member handling.
	    // Skip the duplicate assignment and keep the first value.
	    if (t_cookie_ != val) {
		  // Different value - this is expected for static members
		  // Just skip and keep the original assignment (silently)
	    }
	    // Skip duplicate assignment (keep first value)
	    return;
      }
      t_cookie_ = val;

      for (Link*cur = list_->next_ ; cur->nexus_ == 0 ; cur = cur->next_)
	    cur->nexus_ = const_cast<Nexus*> (this);
}

unsigned Nexus::vector_width() const
{
      for (const Link*cur = first_nlink() ; cur ; cur = cur->next_nlink()) {
	    const NetNet*sig = dynamic_cast<const NetNet*>(cur->get_obj());
	    if (sig == 0)
		  continue;

	    return sig->vector_width();
      }

      return 0;
}

NetNet* Nexus::pick_any_net()
{
      for (Link*cur = first_nlink() ; cur ; cur = cur->next_nlink()) {
	    NetNet*sig = dynamic_cast<NetNet*>(cur->get_obj());
	    if (sig != 0)
		  return sig;
      }

      return 0;
}

NetNode* Nexus::pick_any_node()
{
      for (Link*cur = first_nlink() ; cur ; cur = cur->next_nlink()) {
	    NetNode*node = dynamic_cast<NetNode*>(cur->get_obj());
	    if (node != 0)
		  return node;
      }

      return 0;
}

const char* Nexus::name() const
{
      if (name_)
	    return name_;

      const NetNet*sig = 0;
      unsigned pin = 0;
      for (const Link*cur = first_nlink()
		 ;  cur  ;  cur = cur->next_nlink()) {

	    const NetNet*cursig = dynamic_cast<const NetNet*>(cur->get_obj());
	    if (cursig == 0)
		  continue;

	    if (sig == 0) {
		  sig = cursig;
		  pin = cur->get_pin();
		  continue;
	    }

	    if ((cursig->pin_count() == 1) && (sig->pin_count() > 1))
		  continue;

	    if ((cursig->pin_count() > 1) && (sig->pin_count() == 1)) {
		  sig = cursig;
		  pin = cur->get_pin();
		  continue;
	    }

	    if (cursig->local_flag() && !sig->local_flag())
		  continue;

	    if (cursig->name() < sig->name())
		  continue;

	    sig = cursig;
	    pin = cur->get_pin();
      }

      if (sig == 0) {
	    const Link*lnk = first_nlink();
	    const NetObj*obj = dynamic_cast<const NetObj*>(lnk->get_obj());
	    pin = lnk->get_pin();
	    cerr << "internal error: No signal for nexus of "
		 << obj->name() << " pin " << pin
		 << " type=" << typeid(*obj).name() << "?" << endl;

	    ostringstream tmp;
	    tmp << "nex=" << this << ends;
	    const string tmps = tmp.str();
	    name_ = new char[strlen(tmps.c_str()) + 1];
	    strcpy(name_, tmps.c_str());
      } else {
	    assert(sig);
	    ostringstream tmp;
	    tmp << scope_path(sig->scope()) << "." << sig->name();
	    if (sig->pin_count() > 1)
		  tmp << "<" << pin << ">";
	    tmp << ends;

	    const string tmps = tmp.str();
	    name_ = new char[strlen(tmps.c_str()) + 1];
	    strcpy(name_, tmps.c_str());
      }

      return name_;
}


struct NexusSet::index_t {
      struct key_t {
	    const Nexus*nexus;
	    unsigned base;
	    unsigned wid;

	    bool operator == (const key_t&that) const
	    {
		  return nexus == that.nexus
		      && base == that.base && wid == that.wid;
	    }
      };

      struct hash_t {
	    size_t operator () (const key_t&key) const
	    {
		  size_t val = hash<const Nexus*>()(key.nexus);
		  val ^= hash<unsigned>()(key.base)
		       + static_cast<size_t>(0x9e3779b9U)
		       + (val << 6) + (val >> 2);
		  val ^= hash<unsigned>()(key.wid)
		       + static_cast<size_t>(0x9e3779b9U)
		       + (val << 6) + (val >> 2);
		  return val;
	    }
      };

      uint64_t generation;
      unordered_map<key_t, size_t, hash_t> exact;
};

NexusSet::NexusSet()
: index_(0)
{
}

NexusSet::~NexusSet()
{
      delete index_;
      index_ = 0;
      for (size_t idx = 0 ; idx < items_.size() ; idx += 1)
	    delete items_[idx];
}

size_t NexusSet::size() const
{
      return items_.size();
}

void NexusSet::add(Nexus*that, unsigned base, unsigned wid)
{
      assert(that);
      size_t ptr = bsearch_(that, base, wid);
      if (ptr < items_.size()) {
	    return;
      }

      assert(ptr == items_.size());

      items_.push_back(new elem_t(that, base, wid));
      if (index_ && index_->generation == nexus_identity_generation) {
	    index_t::key_t key = { that, base, wid };
	    index_->exact.emplace(key, items_.size()-1);
      }
}

void NexusSet::add(const NexusSet&that)
{
      if (this == &that)
	    return;

      for (size_t idx = 0 ; idx < that.items_.size() ; idx += 1) {
	    elem_t*cur = that.items_[idx];
	    add(cur->lnk.nexus(), cur->base, cur->wid);
      }
}

void NexusSet::rem_(const NexusSet::elem_t*that)
{
      if (items_.empty())
	    return;

      unsigned ptr = bsearch_(*that);
      if (ptr >= items_.size())
	    return;

      invalidate_index_();

      if (items_.size() == 1) {
	    delete items_[0];
	    items_.clear();
	    return;
      }

      delete items_[ptr];
      for (unsigned idx = ptr ;  idx < (items_.size()-1) ;  idx += 1)
	    items_[idx] = items_[idx+1];

      items_.pop_back();
}

void NexusSet::rem(const NexusSet&that)
{
      for (size_t idx = 0 ;  idx < that.items_.size() ;  idx += 1)
	    rem_(that.items_[idx]);
}

unsigned NexusSet::find_nexus(const NexusSet::elem_t&that) const
{
      return bsearch_(that);
}

NexusSet::elem_t& NexusSet::at (unsigned idx)
{
      assert(idx <  items_.size());
      return *items_[idx];
}

size_t NexusSet::bsearch_(const NexusSet::elem_t&that) const
{
      return bsearch_(that.lnk.nexus(), that.base, that.wid);
}

void NexusSet::invalidate_index_() const
{
      delete index_;
      index_ = 0;
}

size_t NexusSet::bsearch_(const Nexus*that, unsigned base, unsigned wid) const
{
	// Linear search is faster for the many small temporary sets. Once a set
	// is large, retain an exact-key index across lookups. Nexus merges are
	// detected by the identity generation and cause a complete rebuild.
      static const size_t index_threshold = 64;
      if (items_.size() >= index_threshold) {
	    if (!index_ || index_->generation != nexus_identity_generation) {
		  invalidate_index_();
		  index_ = new index_t;
		  index_->generation = nexus_identity_generation;
		  index_->exact.reserve(items_.size());
		  for (size_t idx = 0 ; idx < items_.size() ; idx += 1) {
			elem_t*cur = items_[idx];
			index_t::key_t key = {
			      cur->lnk.nexus(), cur->base, cur->wid
			};
			// Preserve the old linear search's first-match behavior if
			// a later Nexus merge has made two entries aliases.
			index_->exact.emplace(key, idx);
		  }
	    }

	    index_t::key_t key = { that, base, wid };
	    unordered_map<index_t::key_t, size_t,
		  index_t::hash_t>::const_iterator found =
		  index_->exact.find(key);
	    return found == index_->exact.end()? items_.size() : found->second;
      }

      for (unsigned idx = 0 ;  idx < items_.size() ;  idx += 1) {
	    elem_t*cur = items_[idx];
	    if (cur->lnk.nexus() == that
		&& cur->base == base && cur->wid == wid)
		  return idx;
      }

      return items_.size();
}

bool NexusSet::elem_t::contains(const struct elem_t&that) const
{
      if (! lnk.is_linked(that.lnk))
	    return false;
      if (that.base < base)
	    return false;
      if ((that.base+that.wid) > (base+wid))
	    return false;

      return true;
}

bool NexusSet::contains_(const NexusSet::elem_t&that) const
{
      for (unsigned idx = 0 ; idx < items_.size() ; idx += 1) {
	    if (items_[idx]->contains(that))
		  return true;
      }
      return false;
}

bool NexusSet::contains(const NexusSet&that) const
{
      for (size_t idx = 0 ;  idx < that.items_.size() ;  idx += 1) {
	    if (! contains_(*that.items_[idx]))
		return false;
      }

      return true;
}

bool NexusSet::intersect(const NexusSet&that) const
{
      for (size_t idx = 0 ;  idx < that.items_.size() ;  idx += 1) {
	    size_t where = bsearch_(*that.items_[idx]);
	    if (where == items_.size())
		  continue;

	    return true;
      }

      return false;
}
