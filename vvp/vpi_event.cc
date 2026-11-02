/*
 * Copyright (c) 2002-2017 Stephen Williams (steve@icarus.com)
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
# include  "vpi_priv.h"
# include  "event.h"
# include  <cstdio>
# include  <cstdlib>
# include  <cstring>
# include  <cassert>
# include  <algorithm>
# include  "ivl_alloc.h"

inline __vpiNamedEvent::__vpiNamedEvent(__vpiScope*sc, const char*nam,
				       bool automatic_storage)
{
      scope_ = sc;
      name_ = vpip_name_string(nam);
      automatic_storage_ = automatic_storage;
      callbacks_ = 0;
}

__vpiNamedEvent::__vpiNamedEvent(__vpiScope*sc, const char*nam,
                                 bool automatic_storage, unsigned array_base,
                                 int array_msb, int array_lsb,
                                 unsigned array_count)
: __vpiNamedEvent(sc, nam, automatic_storage)
{
      is_array_ = true;
      array_base_ = array_base;
      array_msb_ = array_msb;
      array_lsb_ = array_lsb;
      array_count_ = array_count;
      array_members_.resize(array_count, 0);
}

__vpiNamedEvent::~__vpiNamedEvent()
{
      for (std::vector<__vpiNamedEvent*>::iterator cur = array_members_.begin();
           cur != array_members_.end(); ++cur)
            delete *cur;
      while (callbacks_) {
	    struct __vpiCallback *tmp = callbacks_->next;
	    delete callbacks_;
	    callbacks_ = tmp;
      }
}

int __vpiNamedEvent::get_type_code(void) const
{ return is_array_ ? vpiNamedEventArray : vpiNamedEvent; }

vpiHandle __vpiNamedEvent::vpi_iterate(int code)
{
      if (is_array_ && code == vpiRange)
            return vpip_make_iterator(1,
                  new vpiHandle[1]{vpip_make_range(array_msb_, array_lsb_)}, true);

      if (is_array_member_ && code == vpiIndex) {
            vpiHandle*args = new vpiHandle[1];
            args[0] = &index_value_;
            return vpip_make_iterator(1, args, true);
      }

#ifndef vpiWaitingProcesses
# define vpiWaitingProcesses 734
#endif
      if (code != vpiWaitingProcesses || !funct || !funct->fun)
            return 0;

      vvp_named_event*event = dynamic_cast<vvp_named_event*>(funct->fun);
      if (!event)
            return 0;

      std::vector<vthread_t>threads;
      event->collect_waiting_threads(threads);
      if (threads.empty())
            return 0;

      vpiHandle*args = static_cast<vpiHandle*>(
            calloc(threads.size(), sizeof(vpiHandle)));
      if (!args)
            return 0;
      for (size_t idx = 0; idx < threads.size(); idx += 1)
            args[idx] = vpip_make_process_handle(threads[idx]);
      return vpip_make_iterator(threads.size(), args, true);
}

int __vpiNamedEvent::vpi_get(int code)
{
      switch (code) {

	  case vpiAutomatic:
	    return automatic_storage_ ? 1 : 0;

	  case vpiArrayMember:
	    return is_array_member_ ? 1 : 0;
      }

      return 0;
}

char* __vpiNamedEvent::vpi_get_str(int code)
{
      if (code == vpiFile) {  // Not implemented for now!
	    return simple_set_rbuf_str(file_names[0]);
      }
      return generic_get_str(code, scope_, name_, NULL);
}

vpiHandle __vpiNamedEvent::vpi_put_value(p_vpi_value, int)
{
	/* The array itself is not an event; callers must select an element. */
      if (is_array_)
	    return 0;

	// p_vpi_value may be NULL, and an event doesn't care
	// what the value is
      vvp_vector4_t val;
      vvp_net_ptr_t dest(funct, 0);
      vvp_send_vec4(dest, val, vthread_get_wt_context());

      return this;
}

vpiHandle __vpiNamedEvent::vpi_handle(int code)
{
      switch (code) {
	  case vpiScope:
	    return scope_;

	  case vpiModule:
	    return vpip_module(scope_);
      }

      return 0;
}

vpiHandle __vpiNamedEvent::vpi_index(int index)
{
      if (!is_array_ || index < std::min(array_msb_, array_lsb_) ||
          index > std::max(array_msb_, array_lsb_))
            return 0;

      unsigned offset = static_cast<unsigned>(index -
            std::min(array_msb_, array_lsb_));
      if (offset >= array_count_)
            return 0;

      if (!array_members_[offset]) {
            std::string member_name(name_);
            member_name += "[" + std::to_string(index) + "]";
            __vpiNamedEvent*member = new __vpiNamedEvent(
                  scope_, member_name.c_str(), automatic_storage_);
            member->is_array_member_ = true;
            member->index_value_.set_value(index);
            vvp_net_t*net = event_array_slot_net(array_base_ + offset);
            member->funct = net;
            vvp_named_event_dyn*event =
                  dynamic_cast<vvp_named_event_dyn*>(net->fun);
            assert(event);
            event->set_vpi_handle(member);
            array_members_[offset] = member;
      }
      return array_members_[offset];
}


vpiHandle vpip_make_named_event(const char*name, vvp_net_t*funct,
				bool automatic_storage)
{
      __vpiNamedEvent*obj = new __vpiNamedEvent(vpip_peek_current_scope(),
					       name, automatic_storage);

      obj->funct = funct;

      return obj;
}

vpiHandle vpip_make_named_event_array(const char*name, unsigned array_base,
                                     int array_msb, int array_lsb,
                                     unsigned array_count,
                                     bool automatic_storage)
{
      return new __vpiNamedEvent(vpip_peek_current_scope(), name,
                                 automatic_storage, array_base, array_msb,
                                 array_lsb, array_count);
}

/*
 * This function runs the callbacks for a named event. All the
 * callbacks are listed in the callback member of the event handle,
 * this function scans that list.
 *
 * This also handles the case where the callback has been removed. The
 * vpi_remove_cb doesn't actually remove any callbacks, it marks them
 * as canceled by clearing the cb_rtn function. This function reaps
 * those marked handles when it scans the list.
 *
 * We can not use vpi_free_object() here since it does not really
 * delete the callback.
 */
void __vpiNamedEvent::run_vpi_callbacks()
{
      struct __vpiCallback*next = callbacks_;
      struct __vpiCallback*prev = 0;
      while (next) {
	    struct __vpiCallback*cur = next;
	    next = cur->next;

	    if (cur->cb_data.cb_rtn != 0) {
		  callback_execute(cur);
		  prev = cur;

	    } else if (prev == 0) {
		  callbacks_ = next;
		  cur->next = 0;
		  delete cur;

	    } else {
		  assert(prev->next == cur);
		  prev->next = next;
		  cur->next = 0;
		  delete cur;
	    }
      }
}
