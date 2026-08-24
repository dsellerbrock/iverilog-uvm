/*
 * Copyright (c) 2024 LLVM Contributors
 *   This source code is subject to the terms of the GNU General Public
 *   License as published by the Free Software Foundation. See the file
 *   COPYING for details.
 *
 * vvp_mailbox.cc - VVP runtime implementation of SystemVerilog
 * built-in mailbox and semaphore.
 */

#include "vvp_mailbox.h"
#include "vthread.h"
#include "schedule.h"
#include <cassert>

/* ================================================================
 * vvp_mailbox
 * ================================================================ */

vvp_mailbox::vvp_mailbox(size_t bound)
: bound_(bound)
{
}

vvp_mailbox::~vvp_mailbox()
{
}

vvp_object* vvp_mailbox::duplicate() const
{
      vvp_mailbox* copy = new vvp_mailbox(bound_);
      copy->items_ = items_;
      /* Note: waiters are NOT copied – a duplicate mailbox has no
       * pending waiters. */
      return copy;
}

bool vvp_mailbox::try_put(const vvp_object_t& item)
{
      if (full())
	    return false;
      items_.push_back(item);
      resume_get_waiters_();
      return true;
}

bool vvp_mailbox::try_get(vvp_object_t& item)
{
      if (empty())
	    return false;
      item = items_.front();
      items_.pop_front();
      resume_put_waiters_();
      return true;
}

bool vvp_mailbox::try_peek(vvp_object_t& item)
{
      if (empty())
	    return false;
      item = items_.front();
      return true;
}

bool vvp_mailbox::put(vthread_t thr, const vvp_object_t& self,
		      const vvp_object_t& item)
{
      if (!full()) {
	    items_.push_back(item);
	    resume_get_waiters_();
	    return true;  /* completed immediately */
      }
      /* Mailbox is full – suspend the thread. Store the item in the
       * waiter record so it is available when space opens up. */
      put_waiter_t w;
      w.thr  = thr;
      w.item = item;
      put_waiters_.push_back(w);
      /* SELF retains this mailbox for as long as thr is queued: the
       * %mbx/put opcode popped its only handle off the object stack and
       * that local dies the moment the thread suspends. */
      vthread_mark_resource_wait(thr, this, self, &vvp_mailbox::cancel_waiter_cb_);
      return false;             /* thread suspended */
}

bool vvp_mailbox::get(vthread_t thr, const vvp_object_t& self,
		      vvp_object_t& item_out)
{
      if (!empty()) {
	    item_out = items_.front();
	    items_.pop_front();
	    resume_put_waiters_();
	    return true;
      }
      get_waiter_t w;
      w.thr = thr;
      w.is_peek = false;
      get_waiters_.push_back(w);
      vthread_mark_resource_wait(thr, this, self, &vvp_mailbox::cancel_waiter_cb_);
      return false;
}

bool vvp_mailbox::peek(vthread_t thr, const vvp_object_t& self,
		       vvp_object_t& item_out)
{
      if (!empty()) {
	    item_out = items_.front();
	    return true;
      }
      get_waiter_t w;
      w.thr = thr;
      w.is_peek = true;
      get_waiters_.push_back(w);
      vthread_mark_resource_wait(thr, this, self, &vvp_mailbox::cancel_waiter_cb_);
      return false;
}

void vvp_mailbox::cancel_waiter_cb_(void*owner, vthread_t thr)
{
      if (vvp_mailbox*mbx = static_cast<vvp_mailbox*>(owner))
	    mbx->cancel_waiter_(thr);
}

/*
 * Unlink a dying thread from both wait vectors. Every matching record is
 * removed rather than just the first: the registration invariant allows
 * only one, but a record that outlived the thread it names is exactly the
 * defect this code exists to prevent, so sweep defensively.
 */
void vvp_mailbox::cancel_waiter_(vthread_t thr)
{
      for (size_t idx = get_waiters_.size() ; idx > 0 ; idx -= 1) {
	    if (get_waiters_[idx-1].thr == thr)
		  get_waiters_.erase(get_waiters_.begin() + (long)(idx-1));
      }
      for (size_t idx = put_waiters_.size() ; idx > 0 ; idx -= 1) {
	    if (put_waiters_[idx-1].thr == thr)
		  put_waiters_.erase(put_waiters_.begin() + (long)(idx-1));
      }
}

void vvp_mailbox::resume_get_waiters_()
{
      /* Retain this mailbox across the whole drain. A successful claim
       * takes the retaining reference away from the waiting thread, and
       * that may have been the last one -- the loop condition below reads
       * `this' again afterwards. (Same idiom as vvp_object::touch().) */
      vvp_object_t keep_self(this);
      vvp_object_t claimed;

      while (!get_waiters_.empty() && !empty()) {
	    get_waiter_t waiter = get_waiters_.front();
	    get_waiters_.erase(get_waiters_.begin());
	    /* Claim the wait BEFORE any side effect. A record left behind by
	     * a killed thread must not touch that thread's object stack, must
	     * not consume the message, and must not be scheduled; skip it and
	     * let the next waiter have the item. */
	    if (!vthread_claim_resource_wait(waiter.thr, this, claimed))
		  continue;
	    /* Push the retrieved item onto the waiting thread's object
	     * stack so it is available when the thread resumes at the
	     * instruction following %mbx/get or %mbx/peek. */
	    vthread_push_obj_item(waiter.thr, items_.front());
	    if (!waiter.is_peek) {
		  items_.pop_front();
		  resume_put_waiters_();
	    }
	    schedule_vthread(waiter.thr, 0, true);
      }
}

void vvp_mailbox::resume_put_waiters_()
{
      vvp_object_t keep_self(this);
      vvp_object_t claimed;

      while (!put_waiters_.empty() && !full()) {
	    put_waiter_t w = put_waiters_.front();
	    put_waiters_.erase(put_waiters_.begin());
	    /* A canceled put must not insert its stored item: the thread that
	     * called put() was killed before the mailbox had room, so the
	     * message was never handed over. */
	    if (!vthread_claim_resource_wait(w.thr, this, claimed))
		  continue;
	    items_.push_back(w.item);
	    schedule_vthread(w.thr, 0, true);
	    resume_get_waiters_();
      }
}

/* ================================================================
 * vvp_semaphore
 * ================================================================ */

vvp_semaphore::vvp_semaphore(size_t initial_count)
: count_(initial_count)
{
}

vvp_semaphore::~vvp_semaphore()
{
}

vvp_object* vvp_semaphore::duplicate() const
{
      return new vvp_semaphore(count_);
}

bool vvp_semaphore::try_get(size_t n)
{
      if (count_ >= n) {
	    count_ -= n;
	    return true;
      }
      return false;
}

void vvp_semaphore::put(size_t n)
{
      count_ += n;
      resume_waiters_();
}

bool vvp_semaphore::get(vthread_t thr, const vvp_object_t& self, size_t n)
{
      if (count_ >= n) {
	    count_ -= n;
	    return true;
      }
      waiter_t w;
      w.thr = thr;
      w.n   = n;
      waiters_.push_back(w);
      vthread_mark_resource_wait(thr, this, self, &vvp_semaphore::cancel_waiter_cb_);
      return false;
}

void vvp_semaphore::cancel_waiter_cb_(void*owner, vthread_t thr)
{
      if (vvp_semaphore*sem = static_cast<vvp_semaphore*>(owner))
	    sem->cancel_waiter_(thr);
}

void vvp_semaphore::cancel_waiter_(vthread_t thr)
{
      for (size_t idx = waiters_.size() ; idx > 0 ; idx -= 1) {
	    if (waiters_[idx-1].thr == thr)
		  waiters_.erase(waiters_.begin() + (long)(idx-1));
      }
}

void vvp_semaphore::resume_waiters_()
{
      /* Retain self across the drain; a claim can release the waiting
       * thread's reference to this semaphore. */
      vvp_object_t keep_self(this);
      vvp_object_t claimed;

      bool progress = true;
      while (progress) {
	    progress = false;
	    for (size_t idx = 0; idx < waiters_.size(); ++idx) {
		  if (count_ < waiters_[idx].n)
			continue;
		  waiter_t w = waiters_[idx];
		  waiters_.erase(waiters_.begin() + (long)idx);
		  /* Claim BEFORE taking the keys. A canceled waiter must
		   * leave the key count untouched, so that a later try_get()
		   * can still acquire it. */
		  if (vthread_claim_resource_wait(w.thr, this, claimed)) {
			count_ -= w.n;
			schedule_vthread(w.thr, 0, true);
		  }
		  /* Restart the scan either way: the erase shifted every
		   * following index. */
		  progress = true;
		  break;
	    }
      }
}
