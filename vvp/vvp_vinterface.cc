/*
 * Copyright (c) 2026 Stephen Williams (steve@icarus.com)
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

# include  "vvp_vinterface.h"
# include  "class_type.h"
# include  "vpi_priv.h"
# include  "vthread.h"
# include  "vvp_net.h"
# include  "vvp_net_sig.h"
# include  <cassert>

namespace {

static vpiHandle find_named_item_(__vpiScope*scope, const std::string&name)
{
      if (!scope)
	    return 0;

      for (std::vector<__vpiHandle*>::const_iterator cur = scope->intern.begin()
		 ; cur != scope->intern.end() ; ++cur) {
	    vpiHandle item = *cur;
	    if (!item)
		  continue;

	    if (!dynamic_cast<__vpiSignal*>(item)
		&& !dynamic_cast<__vpiRealVar*>(item)
		&& !dynamic_cast<__vpiStringVar*>(item)
		&& !dynamic_cast<__vpiBaseVar*>(item))
		  continue;

	    char*item_name = item->vpi_get_str(vpiName);
	    if (item_name && name == item_name)
		  return item;
      }

      return 0;
}

static vvp_signal_value* get_signal_value_(__vpiSignal*sig)
{
      if (!sig || !sig->node)
	    return 0;

      vvp_signal_value*vsig = dynamic_cast<vvp_signal_value*>(sig->node->fil);
      if (!vsig)
	    vsig = dynamic_cast<vvp_signal_value*>(sig->node->fun);
      return vsig;
}

static __vpiSignal* resolve_signal_index_(__vpiSignal*sig, size_t idx)
{
      if (!sig || idx == 0)
	    return sig;

      vpiHandle word = sig->vpi_index((int)idx);
      __vpiSignal*word_sig = dynamic_cast<__vpiSignal*>(word);
      return word_sig ? word_sig : sig;
}

static __vpiBaseVar* resolve_basevar_index_(__vpiBaseVar*var, size_t idx)
{
      if (!var || idx == 0)
	    return var;

      vpiHandle word = var->vpi_index((int)idx);
      __vpiBaseVar*word_var = dynamic_cast<__vpiBaseVar*>(word);
      return word_var ? word_var : var;
}

static vvp_fun_signal_object* get_object_fun_(__vpiBaseVar*var)
{
      if (!var || !var->get_net())
	    return 0;

      vvp_fun_signal_object*fun = dynamic_cast<vvp_fun_signal_object*>(var->get_net()->fun);
      if (!fun)
	    fun = dynamic_cast<vvp_fun_signal_object*>(var->get_net()->fil);
      return fun;
}

static vvp_fun_signal_string* get_string_fun_(__vpiBaseVar*var)
{
      if (!var || !var->get_net())
	    return 0;

      vvp_fun_signal_string*fun = dynamic_cast<vvp_fun_signal_string*>(var->get_net()->fun);
      if (!fun)
	    fun = dynamic_cast<vvp_fun_signal_string*>(var->get_net()->fil);
      return fun;
}

static vvp_signal_value* get_real_value_(__vpiRealVar*var)
{
      if (!var || !var->net)
	    return 0;

      vvp_signal_value*vsig = dynamic_cast<vvp_signal_value*>(var->net->fun);
      if (!vsig)
	    vsig = dynamic_cast<vvp_signal_value*>(var->net->fil);
      return vsig;
}

}

vvp_vinterface::vvp_vinterface(__vpiScope*scope, const class_type*defn)
: scope_(scope), defn_(defn)
{
      resolve_slots_();
}

vvp_vinterface::~vvp_vinterface()
{
}

void vvp_vinterface::resolve_slots_(void)
{
      size_t count = defn_ ? defn_->property_count() : 0;
      slots_.assign(count, slot_t());

      for (size_t idx = 0 ; idx < count ; idx += 1) {
	    vpiHandle item = find_named_item_(scope_, defn_->property_name(idx));
	    if (!item)
		  continue;

	    slot_t&slot = slots_[idx];
	    slot.handle = item;

	    if (dynamic_cast<__vpiSignal*>(item)) {
		  slot.kind = SLOT_SIGNAL;
	    } else if (dynamic_cast<__vpiRealVar*>(item)) {
		  slot.kind = SLOT_REAL;
	    } else if (dynamic_cast<__vpiStringVar*>(item)) {
		  slot.kind = SLOT_STRING;
	    } else if (dynamic_cast<__vpiBaseVar*>(item)) {
		  slot.kind = SLOT_OBJECT;
	    }
      }
}

vvp_vinterface::slot_t vvp_vinterface::get_slot_(size_t pid) const
{
      if (pid >= slots_.size())
	    return slot_t();
      return slots_[pid];
}

void vvp_vinterface::set_vec4(size_t pid, const vvp_vector4_t&val, size_t idx)
{
      slot_t slot = get_slot_(pid);
      if (slot.kind != SLOT_SIGNAL)
	    return;

      __vpiSignal*sig = resolve_signal_index_(dynamic_cast<__vpiSignal*>(slot.handle), idx);
      if (!sig || !sig->node)
	    return;

      vvp_net_ptr_t dest(sig->node, 0);
      vvp_send_vec4(dest, val, vthread_get_wt_context());
}

void vvp_vinterface::get_vec4(size_t pid, vvp_vector4_t&val, size_t idx) const
{
      slot_t slot = get_slot_(pid);
      if (slot.kind != SLOT_SIGNAL) {
	    val = vvp_vector4_t();
	    return;
      }

      __vpiSignal*sig = resolve_signal_index_(dynamic_cast<__vpiSignal*>(slot.handle), idx);
      vvp_signal_value*vsig = get_signal_value_(sig);
      if (!sig || !vsig) {
	    val = vvp_vector4_t();
	    return;
      }

      vsig->vec4_value(val);
}

void vvp_vinterface::set_real(size_t pid, double val)
{
      slot_t slot = get_slot_(pid);
      if (slot.kind != SLOT_REAL)
	    return;

      __vpiRealVar*var = dynamic_cast<__vpiRealVar*>(slot.handle);
      if (!var || !var->net)
	    return;

      vvp_net_ptr_t dest(var->net, 0);
      vvp_send_real(dest, val, vthread_get_wt_context());
}

double vvp_vinterface::get_real(size_t pid) const
{
      slot_t slot = get_slot_(pid);
      if (slot.kind != SLOT_REAL)
	    return 0.0;

      __vpiRealVar*var = dynamic_cast<__vpiRealVar*>(slot.handle);
      vvp_signal_value*vsig = get_real_value_(var);
      if (!vsig)
	    return 0.0;

      return vsig->real_value();
}

void vvp_vinterface::set_string(size_t pid, const std::string&val)
{
      slot_t slot = get_slot_(pid);
      if (slot.kind != SLOT_STRING)
	    return;

      __vpiBaseVar*var = resolve_basevar_index_(dynamic_cast<__vpiBaseVar*>(slot.handle), 0);
      if (!var || !var->get_net())
	    return;

      vvp_net_ptr_t dest(var->get_net(), 0);
      vvp_send_string(dest, val, vthread_get_wt_context());
}

std::string vvp_vinterface::get_string(size_t pid) const
{
      slot_t slot = get_slot_(pid);
      if (slot.kind != SLOT_STRING)
	    return std::string();

      __vpiBaseVar*var = dynamic_cast<__vpiBaseVar*>(slot.handle);
      vvp_fun_signal_string*fun = get_string_fun_(var);
      if (!fun)
	    return std::string();

      return fun->get_string();
}

void vvp_vinterface::set_object(size_t pid, const vvp_object_t&val, size_t idx)
{
      slot_t slot = get_slot_(pid);
      if (slot.kind != SLOT_OBJECT)
	    return;

      __vpiBaseVar*var = resolve_basevar_index_(dynamic_cast<__vpiBaseVar*>(slot.handle), idx);
      if (!var || !var->get_net())
	    return;

      vvp_net_ptr_t dest(var->get_net(), 0);
      vvp_send_object(dest, val, vthread_get_wt_context());
}

void vvp_vinterface::get_object(size_t pid, vvp_object_t&val, size_t idx) const
{
      slot_t slot = get_slot_(pid);
      if (slot.kind != SLOT_OBJECT) {
	    val.reset();
	    return;
      }

      __vpiBaseVar*var = resolve_basevar_index_(dynamic_cast<__vpiBaseVar*>(slot.handle), idx);
      vvp_fun_signal_object*fun = get_object_fun_(var);
      if (!fun) {
	    val.reset();
	    return;
      }

      val = fun->get_object();
}

void vvp_vinterface::shallow_copy(const vvp_object*that)
{
      const vvp_vinterface*src = dynamic_cast<const vvp_vinterface*>(that);
      assert(src);
      scope_ = src->scope_;
      defn_ = src->defn_;
      slots_ = src->slots_;
}

vvp_object* vvp_vinterface::duplicate(void) const
{
      vvp_vinterface*tmp = new vvp_vinterface(scope_, defn_);
      tmp->slots_ = slots_;
      return tmp;
}
