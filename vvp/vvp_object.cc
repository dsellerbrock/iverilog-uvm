/*
 * Copyright (c) 2012-2020 Stephen Williams (steve@icarus.com)
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

# include  "vvp_object.h"
# include  "vvp_net.h"
# include  "vthread.h"
# include  <iostream>
# include  <typeinfo>
# include  <set>
# include  <map>
# include  <unordered_set>
# include  <vector>
# include  <functional>

using namespace std;

int vvp_object::total_active_cnt_ = 0;
static std::unordered_set<const vvp_object*> live_vvp_objects_;
typedef std::pair<vvp_net_t*, void*> object_alias_key_t;
static std::map<const vvp_object*, std::set<object_alias_key_t> > object_signal_aliases_;

struct object_mutation_key_t {
      vvp_object*object;
      unsigned property;
      unsigned word;
      unsigned bit;
      bool active;

      bool operator < (const object_mutation_key_t&that) const
      {
            if (object != that.object)
                  return std::less<vvp_object*>()(object, that.object);
            if (property != that.property)
                  return property < that.property;
            if (word != that.word)
                  return word < that.word;
            if (bit != that.bit)
                  return bit < that.bit;
            return active < that.active;
      }
};

static std::map<object_mutation_key_t, std::set<vthread_t> >
      object_mutation_waiters_;
static std::map<vthread_t,
                std::map<object_mutation_key_t, vvp_object_t> >
      thread_mutation_objects_;

static bool remove_mutation_waiter_(vthread_t thread)
{
      std::map<vthread_t,
               std::map<object_mutation_key_t, vvp_object_t> >::iterator
            thread_it = thread_mutation_objects_.find(thread);
      if (thread_it == thread_mutation_objects_.end())
            return false;

      std::vector<object_mutation_key_t> keys;
      for (std::map<object_mutation_key_t, vvp_object_t>::const_iterator
           item = thread_it->second.begin(); item != thread_it->second.end();
           ++item)
            keys.push_back(item->first);

      for (std::vector<object_mutation_key_t>::const_iterator key = keys.begin();
           key != keys.end(); ++key) {
            std::map<object_mutation_key_t, std::set<vthread_t> >::iterator
                  wait_it = object_mutation_waiters_.find(*key);
            if (wait_it == object_mutation_waiters_.end())
                  continue;
            wait_it->second.erase(thread);
            if (wait_it->second.empty())
                  object_mutation_waiters_.erase(wait_it);
      }
      thread_mutation_objects_.erase(thread_it);
      return true;
}

void vvp_object::register_live_ptr_(const vvp_object*ptr)
{
      if (ptr)
            live_vvp_objects_.insert(ptr);
}

void vvp_object::unregister_live_ptr_(const vvp_object*ptr)
{
      if (ptr)
            live_vvp_objects_.erase(ptr);
}

bool vvp_object::pointer_is_live(const vvp_object*ptr)
{
      return ptr && live_vvp_objects_.count(ptr);
}

void vvp_object::cleanup(void)
{
}

void vvp_object::add_mutation_waiter(vthread_t thread, unsigned property,
                                     unsigned word, unsigned bit, bool active)
{
      if (!thread)
            return;
      object_mutation_key_t key = {this, property, word, bit, active};
      object_mutation_waiters_[key].insert(thread);
      thread_mutation_objects_[thread].insert(
            std::make_pair(key, vvp_object_t(this)));
}

bool vvp_object::cancel_mutation_waiter(vthread_t thread)
{
      return thread && remove_mutation_waiter_(thread);
}

void vvp_object::touch(unsigned property, unsigned word, unsigned bit)
{
      mutation_epoch_ += 1;

      // A wait expression may depend on a property of an object reached
      // through another class property (for example `wait(!cfg.in_reset)`).
      // The root object handle does not change when the nested property is
      // written, so a static event on that handle cannot wake the waiter.
      // Dynamic object-property waits register here and are resumed whenever
      // the observed object mutates; the wait statement then re-evaluates its
      // expression as required by IEEE 1800-2017 9.4.3.
      std::set<vthread_t> waiters;
      if (property == UINT_MAX) {
            const object_mutation_key_t first = {this, 0, 0, 0, false};
            for (std::map<object_mutation_key_t, std::set<vthread_t> >::const_iterator
                 item = object_mutation_waiters_.lower_bound(first);
                 item != object_mutation_waiters_.end()
                       && item->first.object == this; ++item)
                  if (item->first.active)
                        waiters.insert(item->second.begin(), item->second.end());
      } else {
            const object_mutation_key_t keys[] = {
                  {this, UINT_MAX, UINT_MAX, UINT_MAX, true},
                  {this, property, UINT_MAX, UINT_MAX, true},
                  {this, property, word, UINT_MAX, true},
                  {this, property, word, bit, true}
            };
            for (unsigned idx = 0 ; idx < sizeof(keys)/sizeof(keys[0]);
                 idx += 1) {
                  std::map<object_mutation_key_t, std::set<vthread_t> >::const_iterator
                        item = object_mutation_waiters_.find(keys[idx]);
                  if (item != object_mutation_waiters_.end())
                        waiters.insert(item->second.begin(), item->second.end());
            }
      }
      if (waiters.empty())
            return;

      /* A single wait expression may observe several class objects. Whichever
         object mutates first wakes the thread and atomically unregisters it
         from every sibling object, preventing duplicate scheduling later. */
      vvp_object_t keep_self(this);
      for (std::set<vthread_t>::const_iterator cur = waiters.begin();
           cur != waiters.end(); ++cur) {
            vthread_t thread = *cur;
            remove_mutation_waiter_(thread);
            vthread_schedule_mutation_waiter(thread);
      }
}

vvp_object::~vvp_object()
{
      object_signal_aliases_.erase(this);
      unregister_live_ptr_(this);
      total_active_cnt_ -= 1;
}

void vvp_object::register_signal_alias(vvp_net_t*net, void*context)
{
      if (!net)
            return;
      static int trace_alias = -1;
      if (trace_alias < 0) {
            const char*env = getenv("IVL_OBJ_ALIAS_TRACE");
            trace_alias = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
      }
      if (trace_alias) {
            fprintf(stderr, "trace obj-alias register obj=%p net=%p ctx=%p\n",
                    (const void*)this, (void*)net, context);
      }
      object_signal_aliases_[this].insert(object_alias_key_t(net, context));
}

void vvp_object::unregister_signal_alias(vvp_net_t*net, void*context)
{
      if (!net)
            return;
      static int trace_alias = -1;
      if (trace_alias < 0) {
            const char*env = getenv("IVL_OBJ_ALIAS_TRACE");
            trace_alias = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
      }
      if (trace_alias) {
            fprintf(stderr, "trace obj-alias unregister obj=%p net=%p ctx=%p\n",
                    (const void*)this, (void*)net, context);
      }
      std::map<const vvp_object*, std::set<object_alias_key_t> >::iterator it =
            object_signal_aliases_.find(this);
      if (it == object_signal_aliases_.end())
            return;
      it->second.erase(object_alias_key_t(net, context));
      if (it->second.empty())
            object_signal_aliases_.erase(it);
}

void vvp_object::notify_signal_aliases() const
{
      static int trace_alias = -1;
      if (trace_alias < 0) {
            const char*env = getenv("IVL_OBJ_ALIAS_TRACE");
            trace_alias = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
      }
      std::map<const vvp_object*, std::set<object_alias_key_t> >::const_iterator it =
            object_signal_aliases_.find(this);
      if (it == object_signal_aliases_.end())
            return;

      if (trace_alias) {
            fprintf(stderr, "trace obj-alias notify obj=%p aliases=%zu\n",
                    (const void*)this, it->second.size());
      }
      std::vector<object_alias_key_t> aliases(it->second.begin(), it->second.end());
      vvp_object_t self(const_cast<vvp_object*>(this));
      for (std::vector<object_alias_key_t>::const_iterator cur = aliases.begin()
                 ; cur != aliases.end() ; ++cur) {
            if (!cur->first)
                  continue;
            if (trace_alias) {
                  fprintf(stderr, "trace obj-alias send obj=%p net=%p ctx=%p\n",
                          (const void*)this, (void*)cur->first, cur->second);
            }
            vvp_send_object(vvp_net_ptr_t(cur->first, 0), self,
                            static_cast<vvp_context_t>(cur->second));
      }
}

void vvp_object::notify_alias_mutation()
{
      /* Provenance-root signals need a fresh epoch so same-handle signal and
         VPI delivery is not suppressed. This deliberately does not visit the
         property mutation waiter map: a nested leaf changed, not every
         filtered property on the root object. */
      mutation_epoch_ += 1;
      notify_signal_aliases();
}

void vvp_object::shallow_copy(const vvp_object*)
{
      cerr << "XXXX shallow_copy(vvp_object_t) not implemented for " << typeid(*this).name() << endl;
      assert(0);
}

vvp_object* vvp_object::duplicate(void) const
{
      cerr << "XXXX duplicate() not implemented for " << typeid(*this).name() << endl;
      assert(0);
      return 0;
}
