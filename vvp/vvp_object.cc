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
# include  <iostream>
# include  <typeinfo>
# include  <set>
# include  <map>
# include  <vector>

using namespace std;

int vvp_object::total_active_cnt_ = 0;
static std::set<const vvp_object*> live_vvp_objects_;
typedef std::pair<vvp_net_t*, void*> object_alias_key_t;
static std::map<const vvp_object*, std::set<object_alias_key_t> > object_signal_aliases_;

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
