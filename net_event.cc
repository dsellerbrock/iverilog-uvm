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

# include  "config.h"
# include  "compiler.h"
# include  "netlist.h"
# include  "ivl_assert.h"

using namespace std;

static bool target_release_mode = false;

void net_event_target_release_mode(bool flag)
{
      target_release_mode = flag;
}

/*
 * NOTE: The name_ is perm-allocated by the caller.
 */
NetEvent::NetEvent(perm_string n)
: name_(n)
{
      lexical_pos_ = 0;
      local_flag_ = false;
      scope_ = 0;
      snext_ = 0;
      probes_ = 0;
      trig_ = 0;
      waitref_ = 0;
      exprref_ = 0;
      wlist_ = 0;
      nb_trig_ = 0;
}

NetEvent::~NetEvent()
{
      ivl_assert(*this, waitref_ == 0);
      if (scope_) scope_->rem_event(this);
      while (probes_) {
	    NetEvProbe*tmp = probes_->enext_;
	    delete probes_;
	    probes_ = tmp;
      }
	/* name_ is lex_strings. */
}

perm_string NetEvent::name() const
{
      return name_;
}

NetScope* NetEvent::scope()
{
      ivl_assert(*this, scope_);
      return scope_;
}

const NetScope* NetEvent::scope() const
{
      ivl_assert(*this, scope_);
      return scope_;
}

unsigned NetEvent::nprobe() const
{
      unsigned cnt = 0;
      const NetEvProbe*cur = probes_;
      while (cur) {
	    cnt += 1;
	    cur = cur->enext_;
      }

      return cnt;
}

NetEvProbe* NetEvent::probe(unsigned idx)
{
      NetEvProbe*cur = probes_;
      while (cur && idx) {
	    cur = cur->enext_;
	    idx -= 1;
      }
      return cur;
}

const NetEvProbe* NetEvent::probe(unsigned idx) const
{
      NetEvProbe*cur = probes_;
      while (cur && idx) {
	    cur = cur->enext_;
	    idx -= 1;
      }
      return cur;
}

unsigned NetEvent::ntrig() const
{
      unsigned cnt = 0;
      const NetEvTrig*cur = trig_;
      while (cur) {
	    cnt += 1;
	    cur = cur->enext_;
      }

      return cnt;
}

/* Count the NONBLOCKING triggers (->>) referencing this event. They
   live on a separate list from the blocking triggers, so a liveness
   test that only asks ntrig() would delete an event whose only
   reference is a ->> statement (dangling pointer at code
   generation). */
unsigned NetEvent::nnb_trig() const
{
      unsigned cnt = 0;
      const NetEvNBTrig*cur = nb_trig_;
      while (cur) {
	    cnt += 1;
	    cur = cur->enext_;
      }

      return cnt;
}

unsigned NetEvent::nwait() const
{
      return waitref_;
}

unsigned NetEvent::nexpr() const
{
      return exprref_;
}

/*
 * A "similar" event is one that has an identical non-nil set of
 * probes.
 */
/* Two virtual-interface edge probes resolve their per-signal edge functor
   from the vif object at run time, so two vif probes on the SAME handle net
   but for DIFFERENT signals (or different edge kinds) — e.g. `@(p.a)` and
   `@(p.c)` in separate processes — are NOT the same event, even though their
   probe nets match. Merging them would collapse both to one signal's
   sensitivity and silently drop the other. Non-vif probes are unaffected. */
static bool vif_probes_match_(const NetEvProbe*a, const NetEvProbe*b)
{
      if (!a || !b)
	    return true;
      bool a_vif = a->is_vif_anyedge() || a->is_vif_posedge() || a->is_vif_negedge();
      bool b_vif = b->is_vif_anyedge() || b->is_vif_posedge() || b->is_vif_negedge();
      if (!a_vif && !b_vif)
	    return true;
      if (a_vif != b_vif)
	    return false;
      return a->is_vif_anyedge() == b->is_vif_anyedge()
	  && a->is_vif_posedge() == b->is_vif_posedge()
	  && a->is_vif_negedge() == b->is_vif_negedge()
	  && a->vif_M() == b->vif_M()
	  && a->vif_member_word() == b->vif_member_word()
	  && a->vif_path() == b->vif_path()
	  && a->vif_root_pin() == b->vif_root_pin();
}

void NetEvent::find_similar_event(list<NetEvent*>&event_list)
{
      if (probes_ == 0)
	    return;

      set<NetEvent*> candidate_events;

	/* First, get a list of all the NetEvProbes that are connected
	   to my first probe. Then use that to create a set of
	   candidate events. These candidate events are a superset of
	   the similar events, so I will be culling this list later. */
      list<NetEvProbe*>first_probes;
      probes_->find_similar_probes(first_probes);

      for (list<NetEvProbe*>::iterator idx = first_probes.begin()
		 ; idx != first_probes.end() ; ++ idx ) {

	    candidate_events.insert( (*idx)->event() );
      }

      if (candidate_events.empty())
	    return;

	/* Now scan the remaining probes, in each case checking that
	   the probe event is a candidate event. After each iteration,
	   events that don't have a similar probe will be removed from
	   the candidate_events set. If the candidate_events set
	   becomes empty, then give up. */
      unsigned probe_count = 1;
      for (NetEvProbe*cur = probes_->enext_ ; cur;  cur = cur->enext_) {
	    list<NetEvProbe*>similar_probes;
	    cur->find_similar_probes(similar_probes);

	    set<NetEvent*> candidate_tmp;
	    for (list<NetEvProbe*>::iterator idx = similar_probes.begin()
		       ; idx != similar_probes.end() ; ++ idx ) {

		  NetEvent*tmp = (*idx)->event();
		  if (candidate_events.find(tmp) != candidate_events.end())
			candidate_tmp .insert(tmp);
	    }

	      // None of the candidate events match this probe? Give up!
	    if (candidate_tmp.empty())
		  return;

	    candidate_events = candidate_tmp;
	    probe_count += 1;
      }

        /* Scan the surviving candidate events. We know that they all
	   have probes that match the current event's probes. Check
	   for remaining compatibility details and save the survivors
	   in the event_list that the caller passed. */
      for (set<NetEvent*>::iterator idx = candidate_events.begin()
		 ; idx != candidate_events.end() ; ++ idx ) {

	    NetEvent*tmp = *idx;

	      // This shouldn't be possible?
	    if (tmp == this)
		  continue;

              /* For automatic tasks, the VVP runtime holds state for events
                 in the automatically allocated context. This means we can't
                 merge similar events in different automatic tasks. */
            if (scope()->is_auto() && (tmp->scope() != scope()))
                  continue;

	    unsigned tcnt = 0;
	    for (const NetEvProbe*cur = tmp->probes_ ; cur ; cur = cur->enext_)
		  tcnt += 1;

	      // Do not merge vif edge probes that resolve to different
	      // interface signals (or edge kinds) even though their handle
	      // nets match — that would drop one signal's sensitivity.
	    if (!vif_probes_match_(this->probes_, tmp->probes_))
		  continue;

	    if (tcnt == probe_count)
		  event_list .push_back(tmp);
      }

}


void NetEvent::replace_event(NetEvent*that)
{
      while (wlist_) {
	    wlist_->obj->replace_event(this, that);
      }
}

NexusSet* NetEvent::nex_async_()
{
	/* If there are behavioral trigger statements attached to me,
	   then this is not an asynchronous event. */
      if (trig_ != 0)
	    return 0;


      NexusSet*tmp = new NexusSet;
      for (NetEvProbe*cur = probes_ ;  cur != 0 ;  cur = cur->enext_) {
	    if (cur->edge() != NetEvProbe::ANYEDGE) {
		  delete tmp;
		  return 0;
	    }

            /* A direct virtual-interface member probe is built before the
             * containing module's interface ports are connected. By the
             * synthesis pass that static binding is available, so use the
             * concrete member nexus instead of the one-bit handle nexus.
             * This makes the lowered continuous assignment a normal
             * combinational process without changing simulation probes. */
            bool resolved_interface_member = false;
            if (cur->is_vif_anyedge() && cur->vif_N() == UINT_MAX
                && cur->vif_root_pin() < cur->pin_count()) {
                  Nexus*root_nexus = cur->pin(cur->vif_root_pin()).nexus();
                  for (Link*link = root_nexus->first_nlink(); link;
                       link = link->next_nlink()) {
                        NetNet*root = dynamic_cast<NetNet*>(link->get_obj());
                        if (!root)
                              continue;
                        NetNet*member = root->resolve_interface_member(
                              link->get_pin(), cur->vif_M());
                        if (!member)
                              continue;
                        for (unsigned pin = 0; pin < member->pin_count();
                             pin += 1) {
                              Nexus*nex = member->pin(pin).nexus();
                              tmp->add(nex, 0, nex->vector_width());
                        }
                        resolved_interface_member = true;
                        break;
                  }
            }
            if (resolved_interface_member)
                  continue;

	    for (unsigned idx = 0 ;  idx < cur->pin_count() ;  idx += 1) {
		  Nexus*nex = cur->pin(idx).nexus();
		  bool precise_part = false;
		  for (Link*link = nex->first_nlink(); link;
		       link = link->next_nlink()) {
			NetPartSelect*select =
			      dynamic_cast<NetPartSelect*>(link->get_obj());
			if (!select || select->dir() != NetPartSelect::VP
			    || link->get_pin() != 0)
			      continue;
			tmp->add(select->pin(1).nexus(), select->base(),
				 select->width());
			precise_part = true;
			break;
		  }
		  if (!precise_part)
			tmp->add(nex, 0, nex->vector_width());
	    }
      }

      return tmp;
}

NetEvTrig::NetEvTrig(NetEvent*ev)
: event_(ev)
{
      enext_ = event_->trig_;
      event_->trig_ = this;
}

NetEvTrig::~NetEvTrig()
{
      if (event_->trig_ == this) {
	    event_->trig_ = enext_;

      } else {
	    NetEvTrig*cur = event_->trig_;
	    while (cur->enext_ != this) {
		  ivl_assert(*this, cur->enext_);
		  cur = cur->enext_;
	    }

	    cur->enext_ = this->enext_;
      }
}

const NetEvent* NetEvTrig::event() const
{
      return event_;
}

NetEvNBTrig::NetEvNBTrig(NetEvent*ev, NetExpr*dly)
: event_(ev), dly_(dly)
{
      enext_ = event_->nb_trig_;
      event_->nb_trig_ = this;
}

NetEvNBTrig::~NetEvNBTrig()
{
      if (event_->nb_trig_ == this) {
	    event_->nb_trig_ = enext_;

      } else {
	    NetEvNBTrig*cur = event_->nb_trig_;
	    while (cur->enext_ != this) {
		  ivl_assert(*this, cur->enext_);
		  cur = cur->enext_;
	    }

	    cur->enext_ = this->enext_;
      }

      delete dly_;
}

const NetExpr* NetEvNBTrig::delay() const
{
      return dly_;
}

const NetEvent* NetEvNBTrig::event() const
{
      return event_;
}

/*
 * Assign a design-global unique slot to a class-member event on first
 * use. A globally unique id (rather than a per-class index) guarantees
 * that base-class and derived-class events never collide within one
 * runtime object's per-instance event table.
 */
unsigned NetEvent::obj_slot()
{
      static unsigned next_obj_slot = 0;
      if (!obj_slot_set_) {
	    obj_slot_ = next_obj_slot++;
	    obj_slot_set_ = true;
      }
      return obj_slot_;
}

NetEvTrigObj::NetEvTrigObj(NetExpr*obj, unsigned slot, bool nb, NetExpr*dly)
: obj_(obj), slot_(slot), nb_(nb), dly_(dly)
{
}

NetEvTrigObj::~NetEvTrigObj()
{
      delete obj_;
      delete dly_;
}

NetEvWaitObj::NetEvWaitObj(NetExpr*obj, unsigned slot)
: obj_(obj), slot_(slot)
{
}

NetEvWaitObj::~NetEvWaitObj()
{
      delete obj_;
      delete statement_;
}

DelayType NetEvWaitObj::delay_type(bool) const
{
      return POSSIBLE_DELAY;
}

/*
 * Reserve a contiguous run of design-global slots for a named-event
 * array (IEEE 1800-2017 6.20), one per element. This counter is
 * independent of the per-class obj_slot() numbering above -- array
 * elements are looked up in a flat global table, not a per-object map,
 * so the two numbering spaces never need to interoperate.
 */
void NetEvent::set_event_array(long msb, long lsb, unsigned count)
{
      static unsigned next_array_slot = 0;

      is_event_array_ = true;
      array_msb_ = msb;
      array_lsb_ = lsb;
      array_count_ = count;
      array_base_slot_ = next_array_slot;
      next_array_slot += count;
}

bool NetEvent::array_index_to_word(long index, unsigned&word) const
{
      long lo = (array_msb_ >= array_lsb_) ? array_lsb_ : array_msb_;
      long hi = (array_msb_ >= array_lsb_) ? array_msb_ : array_lsb_;
      if (index < lo || index > hi)
	    return false;
      word = (unsigned)(index - lo);
      return true;
}

NetEvTrigArr::NetEvTrigArr(NetEvent*ev, NetExpr*idx, bool nb, NetExpr*dly)
: event_(ev), index_(idx), nb_(nb), dly_(dly)
{
}

NetEvTrigArr::~NetEvTrigArr()
{
      delete index_;
      delete dly_;
}

NetEvWaitArr::NetEvWaitArr(NetEvent*ev, NetExpr*idx)
: event_(ev), index_(idx)
{
}

NetEvWaitArr::~NetEvWaitArr()
{
      delete index_;
      delete statement_;
}

DelayType NetEvWaitArr::delay_type(bool) const
{
      return POSSIBLE_DELAY;
}

NetEvProbe::NetEvProbe(NetScope*s, perm_string n, NetEvent*tgt,
		       edge_t t, unsigned p)
: NetNode(s, n, p), event_(tgt), edge_(t)
{
      for (unsigned idx = 0 ;  idx < p ;  idx += 1) {
	    pin(idx).set_dir(Link::INPUT);
      }

      enext_ = event_->probes_;
      event_->probes_ = this;
}

void NetEvProbe::set_vif_posedge(unsigned N, unsigned M, unsigned pre_N)
{
      is_vif_posedge_ = true;
      vif_N_ = N;
      vif_M_ = M;
      vif_member_word_ = UINT_MAX;
      vif_pre_N_ = pre_N;
      vif_path_.clear();
      if (pre_N != UINT_MAX)
	    vif_path_.push_back(pre_N);
      if (N != UINT_MAX)
	    vif_path_.push_back(N);
}

void NetEvProbe::set_vif_negedge(unsigned N, unsigned M, unsigned pre_N)
{
      is_vif_negedge_ = true;
      vif_N_ = N;
      vif_M_ = M;
      vif_member_word_ = UINT_MAX;
      vif_pre_N_ = pre_N;
      vif_path_.clear();
      if (pre_N != UINT_MAX)
	    vif_path_.push_back(pre_N);
      if (N != UINT_MAX)
	    vif_path_.push_back(N);
}

void NetEvProbe::set_vif_anyedge(unsigned N, unsigned M, unsigned pre_N)
{
      is_vif_anyedge_ = true;
      vif_N_ = N;
      vif_M_ = M;
      vif_member_word_ = UINT_MAX;
      vif_pre_N_ = pre_N;
      vif_path_.clear();
      if (pre_N != UINT_MAX)
	    vif_path_.push_back(pre_N);
      if (N != UINT_MAX)
	    vif_path_.push_back(N);
}

void NetEvProbe::set_vif_posedge_path(const vector<unsigned>&path, unsigned M,
				      unsigned member_word)
{
      is_vif_posedge_ = true;
      vif_path_ = path;
      vif_M_ = M;
      vif_member_word_ = member_word;
      vif_N_ = path.empty() ? UINT_MAX : path.back();
      vif_pre_N_ = path.size() == 2 ? path.front() : UINT_MAX;
}

void NetEvProbe::set_vif_negedge_path(const vector<unsigned>&path, unsigned M,
				      unsigned member_word)
{
      is_vif_negedge_ = true;
      vif_path_ = path;
      vif_M_ = M;
      vif_member_word_ = member_word;
      vif_N_ = path.empty() ? UINT_MAX : path.back();
      vif_pre_N_ = path.size() == 2 ? path.front() : UINT_MAX;
}

void NetEvProbe::set_vif_anyedge_path(const vector<unsigned>&path, unsigned M,
				      unsigned member_word)
{
      is_vif_anyedge_ = true;
      vif_path_ = path;
      vif_M_ = M;
      vif_member_word_ = member_word;
      vif_N_ = path.empty() ? UINT_MAX : path.back();
      vif_pre_N_ = path.size() == 2 ? path.front() : UINT_MAX;
}

void NetEvProbe::set_obj_mutation(unsigned N, unsigned pre_N,
                                  unsigned root_pin)
{
      is_obj_mutation_ = true;
      obj_N_ = N;
      obj_pre_N_ = pre_N;
      obj_root_pin_ = root_pin;
      obj_mutation_N_.clear();
      obj_mutation_pre_N_.clear();
      obj_mutation_root_pin_.clear();
      add_obj_mutation(N, pre_N, root_pin);
}

void NetEvProbe::add_obj_mutation(unsigned N, unsigned pre_N,
                                  unsigned root_pin)
{
      for (unsigned idx = 0 ; idx < obj_mutation_N_.size() ; idx += 1) {
            if (obj_mutation_N_[idx] == N
                && obj_mutation_pre_N_[idx] == pre_N
                && obj_mutation_root_pin_[idx] == root_pin)
                  return;
      }

      is_obj_mutation_ = true;
      if (obj_mutation_N_.empty()) {
            obj_N_ = N;
            obj_pre_N_ = pre_N;
            obj_root_pin_ = root_pin;
      }
      obj_mutation_N_.push_back(N);
      obj_mutation_pre_N_.push_back(pre_N);
      obj_mutation_root_pin_.push_back(root_pin);
}

NetEvProbe::~NetEvProbe()
{
      if (event_->probes_ == this) {
	    event_->probes_ = enext_;

      } else {
	    NetEvProbe*cur = event_->probes_;
	    while (cur->enext_ != this) {
		  ivl_assert(*this, cur->enext_);
		  cur = cur->enext_;
	    }

	    cur->enext_ = this->enext_;
      }
}

NetEvProbe::edge_t NetEvProbe::edge() const
{
      return edge_;
}

NetEvent* NetEvProbe::event()
{
      return event_;
}

const NetEvent* NetEvProbe::event() const
{
      return event_;
}

/*
 * A similar NetEvProbe is one that is connected to all the same nexa
 * that this probe is connected to, and also is the same edge
 * type. Don't count myself as a similar probe.
 */
void NetEvProbe::find_similar_probes(list<NetEvProbe*>&plist)
{
      Nexus*nex = pin(0).nexus();

      for (Link*lcur = nex->first_nlink(); lcur; lcur = lcur->next_nlink()) {
	    NetPins*obj = lcur->get_obj();
	      // Skip NexusSet objects
	    if (obj == 0)
		  continue;

	    if (obj->pin_count() != pin_count())
		  continue;

	    NetEvProbe*tmp = dynamic_cast<NetEvProbe*>(obj);
	    if (tmp == 0)
		  continue;

	    if (tmp == this)
		  continue;

	    if (edge() != tmp->edge())
		  continue;

	    bool ok_flag = true;
	    for (unsigned idx = 1 ;  ok_flag && idx < pin_count() ;  idx += 1)
		  if (! pin(idx).is_linked(tmp->pin(idx)))
			ok_flag = false;

	    if (ok_flag == true)
		  plist .push_back(tmp);
      }
}

NetEvWait::NetEvWait(NetProc*pr)
: statement_(pr), has_t0_trigger_(false)
{
}

NetEvWait::~NetEvWait()
{
      if (! events_.empty()) {
	    for (unsigned idx = 0 ;  idx < events_.size() ;  idx += 1) {
		  NetEvent*tgt = events_[idx];
		  // A wait-fork deliberately carries a null event sentinel.
		  if (! tgt)
			continue;
		  ivl_assert(*this, tgt->waitref_ > 0);
		  tgt->waitref_ -= 1;

		  struct NetEvent::wcell_*tmp = tgt->wlist_;
		  if (tmp->obj == this) {
			tgt->wlist_ = tmp->next;
			delete tmp;
		  } else {
			ivl_assert(*this, tmp->next);
			while (tmp->next->obj != this) {
			      tmp = tmp->next;
			      ivl_assert(*this, tmp->next);
			}
			struct NetEvent::wcell_*dead = tmp->next;
			tmp->next = dead->next;
			delete dead;
		  }
		  /* Later process trees may still reference this shared event
		   * during progressive target conversion. */
		  if (! target_release_mode && tgt->waitref_ == 0
		      && tgt->ntrig() == 0 && tgt->nnb_trig() == 0
		      && tgt->nexpr() == 0 && !tgt->is_event_array())
			delete tgt;
	    }
	    events_.clear();
      }
      delete statement_;
}

void NetEvWait::add_event(NetEvent*tgt)
{
	/* A wait fork is an empty event. */
      if (! tgt) {
	    ivl_assert(*this, events_.empty());
	    events_.push_back(0);
	    return;
      }

      events_.push_back(tgt);

	// Remember to tell the NetEvent that there is someone
	// pointing to it.
      tgt->waitref_ += 1;

      struct NetEvent::wcell_*tmp = new NetEvent::wcell_;
      tmp->obj = this;
      tmp->next = tgt->wlist_;
      tgt->wlist_ = tmp;
}

void NetEvWait::replace_event(NetEvent*src, NetEvent*repl)
{
      unsigned idx;
      for (idx = 0 ;  idx < events_.size() ;  idx += 1) {
	    if (events_[idx] == src)
		  break;
      }

      ivl_assert(*this, idx < events_.size());

	// First, remove me from the list held by the src NetEvent.
      ivl_assert(*this, src->waitref_ > 0);
      src->waitref_ -= 1;
      struct NetEvent::wcell_*tmp = src->wlist_;
      if (tmp->obj == this) {
	    src->wlist_ = tmp->next;
	    delete tmp;
      } else {
	    ivl_assert(*this, tmp->next);
	    while (tmp->next->obj != this) {
		  tmp = tmp->next;
		  ivl_assert(*this, tmp->next);
	    }
	    struct NetEvent::wcell_*dead = tmp->next;
	    tmp->next = dead->next;
	    delete dead;
      }

	// Replace the src pointer with the repl pointer.
      events_[idx] = repl;

	// Remember to tell the replacement NetEvent that there is
	// someone pointing to it.
      repl->waitref_ += 1;

      tmp = new NetEvent::wcell_;
      tmp->obj = this;
      tmp->next = repl->wlist_;
      repl->wlist_ = tmp;

}

NetProc* NetEvWait::statement()
{
      return statement_;
}

const NetProc* NetEvWait::statement() const
{
      return statement_;
}
