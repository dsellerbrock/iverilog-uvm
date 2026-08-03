/*
 * Copyright (c) 2004-2020 Stephen Williams (steve@icarus.com)
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
# include  "statistics.h"
# include  "schedule.h"
# include  "vthread.h"
# include  "vpi_priv.h"
# include  "vvp_assoc.h"
# include  "vvp_cobject.h"
# include  "vvp_darray.h"
# include  <vector>
# include  <cassert>
#ifdef CHECK_WITH_VALGRIND
# include  <valgrind/memcheck.h>
# include  <map>
#endif

# include  <iostream>

using namespace std;

vvp_object_t vvp_fun_signal_object::make_default_object() const
{
      switch (default_object_kind()) {
          case INIT_OBJ_QUEUE_REAL:
            return vvp_object_t(new vvp_queue_real);
          case INIT_OBJ_QUEUE_STRING:
            return vvp_object_t(new vvp_queue_string);
          case INIT_OBJ_QUEUE_VEC4:
            return vvp_object_t(new vvp_queue_vec4);
          case INIT_OBJ_QUEUE_OBJECT:
            return vvp_object_t(new vvp_queue_object);
          case INIT_OBJ_ASSOC_REAL:
            return vvp_object_t(new vvp_assoc_real);
          case INIT_OBJ_ASSOC_STRING:
            return vvp_object_t(new vvp_assoc_string);
          case INIT_OBJ_ASSOC_VEC4:
            return vvp_object_t(new vvp_assoc_vec4);
          case INIT_OBJ_ASSOC_OBJECT:
            return vvp_object_t(new vvp_assoc_object);
          case INIT_OBJ_NONE:
          default:
            return vvp_object_t();
      }
}

static vvp_context_t recover_automatic_recv_context_(vvp_context_t context,
                                                     __vpiScope*scope,
                                                     const char*where)
{
      static bool warned_missing = false;
      static bool warned_scoped = false;

      vvp_context_t resolved = vthread_recover_context_for_scope(context, scope);
      if (!context && resolved)
            ctx_stats_bump("recv-sig.missing-recovered");
      else if (context && resolved && context != resolved)
            ctx_stats_bump("recv-sig.mismatch-repaired");
      if (auto_ctx_warn_enabled()) {
            if (!warned_missing && !context && resolved) {
                  fprintf(stderr,
                          "Warning: recovered missing automatic signal context during %s"
                          " (further similar warnings suppressed)\n",
                          where ? where : "<unknown>");
                  warned_missing = true;
            }
            if (!warned_scoped && context && resolved && context != resolved) {
                  fprintf(stderr,
                          "Warning: repaired automatic signal context scope mismatch during %s"
                          " (further similar warnings suppressed)\n",
                          where ? where : "<unknown>");
                  warned_scoped = true;
            }
      }
      return resolved;
}

static bool recv_object_trace_scope_match_(const char*scope_name)
{
      static int enabled = -1;
      static string match_text;

      if (enabled < 0) {
            const char*env = getenv("IVL_RECV_OBJ_TRACE");
            enabled = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
            if (enabled && env
                && strcmp(env, "1") != 0 && strcmp(env, "ALL") != 0
                && strcmp(env, "*") != 0)
                  match_text = env;
      }

      if (!enabled)
            return false;
      if (match_text.empty())
            return true;
      return scope_name && strstr(scope_name, match_text.c_str());
}

static bool recv_object_trace_configured_()
{
      static int enabled = -1;
      if (enabled < 0) {
            const char*env = getenv("IVL_RECV_OBJ_TRACE");
            enabled = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
      }
      return enabled != 0;
}

static bool load_str_trace_scope_match_(const char*scope_name)
{
      static int enabled = -1;
      static string match_text;

      if (enabled < 0) {
            const char*env = getenv("IVL_LOAD_STR_TRACE");
            enabled = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
            if (enabled && env
                && strcmp(env, "1") != 0 && strcmp(env, "ALL") != 0
                && strcmp(env, "*") != 0)
                  match_text = env;
      }

      if (!enabled)
            return false;
      if (match_text.empty())
            return true;
      return scope_name && strstr(scope_name, match_text.c_str());
}

static bool load_str_trace_configured_()
{
      static int enabled = -1;
      if (enabled < 0) {
            const char*env = getenv("IVL_LOAD_STR_TRACE");
            enabled = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
      }
      return enabled != 0;
}

static bool recv_vec_trace_scope_match_(__vpiScope*scope)
{
      static int enabled = -1;
      static string match_text;

      if (enabled < 0) {
            const char*env = getenv("IVL_RECV_VEC_TRACE");
            enabled = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
            if (enabled && env
                && strcmp(env, "1") != 0 && strcmp(env, "ALL") != 0
                && strcmp(env, "*") != 0)
                  match_text = env;
      }

      if (!enabled)
            return false;
      if (match_text.empty())
            return true;

      const char*scope_name = scope ? vpi_get_str(vpiFullName, scope) : 0;
      return scope_name && strstr(scope_name, match_text.c_str());
}

static bool load_vec_trace_scope_match_(__vpiScope*scope)
{
      static int enabled = -1;
      static string match_text;

      if (enabled < 0) {
            const char*env = getenv("IVL_LOAD_VEC_TRACE");
            enabled = (env && *env && strcmp(env, "0") != 0) ? 1 : 0;
            if (enabled && env
                && strcmp(env, "1") != 0 && strcmp(env, "ALL") != 0
                && strcmp(env, "*") != 0)
                  match_text = env;
      }

      if (!enabled)
            return false;
      if (match_text.empty())
            return true;

      const char*scope_name = scope ? vpi_get_str(vpiFullName, scope) : 0;
      return scope_name && strstr(scope_name, match_text.c_str());
}

/*
 * The filter_mask_ method takes as an input the value to propagate,
 * the mask of what is being forced, and returns a propagation
 * mode. In the process, it may update the filtered output value.
 *
 * The input value is the subvector "val" that is placed as "base" in
 * the output. The val may be shorter then the target vector.
 *
 * The "force" vector in the value being force, with the force_mask_
 * member a bit mask of which parts of the force vector really apply.
 */
template <class T> vvp_net_fil_t::prop_t vvp_net_fil_t::filter_mask_(const T&val, const T&force, T&filter, unsigned base)
{
      if (!test_force_mask_is_zero()) {
	      // Some bits are being forced. Go through the
	      // force_mask_ and force value to see which bits are
	      // propagated and which are kept from the forced
	      // value. Update the filter with the filtered result and
	      // return REPL to indicate that some bits have changed,
	      // or STOP if no bits change.
	    bool propagate_flag = force_propagate_;
	    force_propagate_ = false;
	    assert(force_mask_.size() == force.size());
	    assert((base+val.size()) <= force_mask_.size());

	    filter = val;
	    for (unsigned idx = 0 ; idx < val.size() ; idx += 1) {
		  if (force_mask_.value(base+idx))
			filter.set_bit(idx, force.value(base+idx));
		  else
			propagate_flag = true;
	    }

	    if (propagate_flag) {
		  run_vpi_callbacks();
		  return REPL;
	    } else {
		  return STOP;
	    }

      } else {
	    run_vpi_callbacks();
	    return PROP;
      }
}

template <class T> vvp_net_fil_t::prop_t vvp_net_fil_t::filter_mask_(T&val, T force)
{

      if (test_force_mask(0)) {
	    val = force;
	    run_vpi_callbacks();
	    return REPL;
      }
      run_vpi_callbacks();
      return PROP;
}

template <class T> vvp_net_fil_t::prop_t vvp_net_fil_t::filter_input_mask_(const T&val, const T&force, T&rep) const
{
      if (test_force_mask_is_zero())
	    return PROP;

      assert(force_mask_.size() == force.size());

      rep = val;
      for (unsigned idx = 0 ; idx < val.size() ; idx += 1) {
	    if (force_mask_.value(idx))
		  rep.set_bit(idx, force.value(idx));
      }

      return REPL;
}

vvp_signal_value::~vvp_signal_value()
{
}

double vvp_signal_value::real_value() const
{
      assert(0);
      return 0;
}

void vvp_net_t::force_vec4(const vvp_vector4_t&val, const vvp_vector2_t&mask)
{
      assert(fil);
      fil->force_fil_vec4(val, mask);
      fun->force_flag(false);
	// M12B-fr: report the force to any cbForce callbacks.
      fil->run_force_callbacks(cbForce);
      vvp_send_vec4(out_, val, 0);
}

void vvp_net_t::force_vec8(const vvp_vector8_t&val, const vvp_vector2_t&mask)
{
      assert(fil);
      fil->force_fil_vec8(val, mask);
      fun->force_flag(false);
	// M12B-fr: report the force to any cbForce callbacks.
      fil->run_force_callbacks(cbForce);
      vvp_send_vec8(out_, val);
}

void vvp_net_t::force_real(double val, const vvp_vector2_t&mask)
{
      assert(fil);
      fil->force_fil_real(val, mask);
      fun->force_flag(false);
	// M12B-fr: report the force to any cbForce callbacks.
      fil->run_force_callbacks(cbForce);
      vvp_send_real(out_, val, 0);
}

/* **** vvp_fun_signal methods **** */

vvp_fun_signal_base::vvp_fun_signal_base()
{
      continuous_assign_active_ = false;
      needs_init_ = true;
      cassign_link = 0;
      count_functors_sig += 1;
}

vvp_fun_signal4_sa::vvp_fun_signal4_sa(unsigned wid, vvp_bit4_t init)
: bits4_(wid, init)
{
}

/*
 * Nets simply reflect their input to their output.
 *
 * NOTE: It is a quirk of vvp_fun_signal that it has an initial value
 * that needs to be propagated, but after that it only needs to
 * propagate if the value changes. Eliminating duplicate propagations
 * should improve performance, but has the quirk that an input that
 * matches the initial value might not be propagated. The hack used
 * herein is to keep a "needs_init_" flag that is turned false after
 * the first propagation, and forces the first propagation to happen
 * even if it matches the initial value.
 */
void vvp_fun_signal4_sa::recv_vec4(vvp_net_ptr_t ptr, const vvp_vector4_t&bit,
                                   vvp_context_t)
{
      switch (ptr.port()) {
	  case 0: // Normal input (feed from net, or set from process)
	      /* If we don't have a continuous assign mask then just
		 copy the bits, otherwise we need to see if there are
		 any holes in the mask so we can set those bits. */
	    if (assign_mask_.size() == 0) {
                  if (needs_init_ || !bits4_.eeq(bit)) {
			assert(bit.size() == bits4_.size());
			bits4_ = bit;
			needs_init_ = false;
			ptr.ptr()->send_vec4(bits4_, 0);
		  }
	    } else {
		  bool changed = false;
		  assert(bits4_.size() == assign_mask_.size());
		  for (unsigned idx = 0 ;  idx < bit.size() ;  idx += 1) {
			if (idx >= bits4_.size()) break;
			if (assign_mask_.value(idx)) continue;
			bits4_.set_bit(idx, bit.value(idx));
			changed = true;
		  }
		  if (changed) {
			needs_init_ = false;
			ptr.ptr()->send_vec4(bits4_, 0);
		  }
	    }
	    break;

	  case 1: // Continuous assign value
	      // Handle the simple case of the linked source being wider
	      // than this signal. Note we don't yet support the case of
	      // the linked source being narrower than this signal, or
	      // the case of an expression being assigned.
	    bits4_ = coerce_to_width(bit, bits4_.size());
	    assign_mask_ = vvp_vector2_t(vvp_vector2_t::FILL1, bits4_.size());
	    ptr.ptr()->send_vec4(bits4_, 0);
	    break;

	  default:
	    fprintf(stderr, "Unsupported port type %u.\n", ptr.port());
	    assert(0);
	    break;
      }
}

void vvp_fun_signal4_sa::recv_vec8(vvp_net_ptr_t ptr, const vvp_vector8_t&bit)
{
      recv_vec4(ptr, reduce4(bit), 0);
}

void vvp_fun_signal4_sa::recv_vec4_pv(vvp_net_ptr_t ptr, const vvp_vector4_t&bit,
				      unsigned base, unsigned vwid, vvp_context_t)
{
      assert(bits4_.size() == vwid);
      unsigned wid = bit.size();

      switch (ptr.port()) {
	  case 0: // Normal input
	    if (assign_mask_.size() == 0) {
                  for (unsigned idx = 0 ;  idx < wid ;  idx += 1) {
			if (base+idx >= bits4_.size()) break;
			bits4_.set_bit(base+idx, bit.value(idx));
		  }
		  needs_init_ = false;
		  ptr.ptr()->send_vec4(bits4_,0);
	    } else {
		  bool changed = false;
		  assert(bits4_.size() == assign_mask_.size());
		  for (unsigned idx = 0 ;  idx < wid ;  idx += 1) {
			if (base+idx >= bits4_.size()) break;
			if (assign_mask_.value(base+idx)) continue;
			bits4_.set_bit(base+idx, bit.value(idx));
			changed = true;
		  }
		  if (changed) {
			needs_init_ = false;
			ptr.ptr()->send_vec4(bits4_,0);
		  }
	    }
	    break;

	  case 1: // Continuous assign value
	    if (assign_mask_.size() == 0)
		  assign_mask_ = vvp_vector2_t(vvp_vector2_t::FILL0, bits4_.size());
	    for (unsigned idx = 0 ;  idx < wid ;  idx += 1) {
		  if (base+idx >= bits4_.size())
			break;
		  bits4_.set_bit(base+idx, bit.value(idx));
		  assign_mask_.set_bit(base+idx, 1);
	    }
	    ptr.ptr()->send_vec4(bits4_,0);
	    break;

	  default:
	    fprintf(stderr, "Unsupported port type %u.\n", ptr.port());
	    assert(0);
	    break;
      }
}

void vvp_fun_signal4_sa::recv_vec8_pv(vvp_net_ptr_t ptr, const vvp_vector8_t&bit,
				      unsigned base, unsigned vwid)
{
      recv_vec4_pv(ptr, reduce4(bit), base, vwid, 0);
}

void vvp_fun_signal_base::deassign()
{
      continuous_assign_active_ = false;
      assign_mask_ = vvp_vector2_t();
}

void vvp_fun_signal_base::deassign_pv(unsigned base, unsigned wid)
{
      for (unsigned idx = 0 ;  idx < wid ;  idx += 1) {
	    assign_mask_.set_bit(base+idx, 0);
      }

      if (assign_mask_.is_zero()) {
	    assign_mask_ = vvp_vector2_t();
      }
}

void automatic_signal_base::release(vvp_net_ptr_t,bool)
{
      assert(0);
}

void automatic_signal_base::release_pv(vvp_net_ptr_t,unsigned,unsigned,bool)
{
      assert(0);
}

unsigned automatic_signal_base::filter_size() const
{
      assert(0);
      return(0);
}
void automatic_signal_base::force_fil_vec4(const vvp_vector4_t&, const vvp_vector2_t&)
{
      assert(0);
}
void automatic_signal_base::force_fil_vec8(const vvp_vector8_t&, const vvp_vector2_t&)
{
      assert(0);
}
void automatic_signal_base::force_fil_real(double, const vvp_vector2_t&)
{
      assert(0);
}
void automatic_signal_base::get_value(struct t_vpi_value*)
{
      assert(0);
}

const vvp_vector4_t& vvp_fun_signal4_sa::vec4_unfiltered_value() const
{
      return bits4_;
}

namespace {
struct signal4_aa_slot {
      static const unsigned MAGIC = 0x53494734u; // "SIG4"
      unsigned magic;
      vvp_vector4_t bits;

      signal4_aa_slot(unsigned wid, vvp_bit4_t init)
      : magic(MAGIC), bits(wid, init)
      {
      }
};

static signal4_aa_slot* signal4_aa_slot_from_raw(void*raw)
{
      signal4_aa_slot*slot = static_cast<signal4_aa_slot*>(raw);
      if (!(slot && slot->magic == signal4_aa_slot::MAGIC))
            return 0;
      return slot;
}

static const signal4_aa_slot* signal4_aa_slot_from_raw(const void*raw)
{
      const signal4_aa_slot*slot = static_cast<const signal4_aa_slot*>(raw);
      if (!(slot && slot->magic == signal4_aa_slot::MAGIC))
            return 0;
      return slot;
}

static signal4_aa_slot* signal4_aa_get_or_make_slot(vvp_context_t context,
                                                     unsigned context_idx,
                                                     unsigned wid,
                                                     vvp_bit4_t init)
{
      signal4_aa_slot*slot =
            signal4_aa_slot_from_raw(vvp_get_context_item(context, context_idx));
      if (!slot) {
            slot = new signal4_aa_slot(wid, init);
            vvp_set_context_item(context, context_idx, slot);
      }
      return slot;
}
}

vvp_fun_signal4_aa::vvp_fun_signal4_aa(unsigned wid, vvp_bit4_t init)
{
      context_scope_ = vpip_peek_context_scope();
      context_idx_ = vpip_add_item_to_context(this, context_scope_);
      size_ = wid;
      init_ = init;
}

vvp_fun_signal4_aa::~vvp_fun_signal4_aa()
{
      assert(0);
}

void vvp_fun_signal4_aa::alloc_instance(vvp_context_t context)
{
      vvp_set_context_item(context, context_idx_, new signal4_aa_slot(size_, init_));
}

void vvp_fun_signal4_aa::reset_instance(vvp_context_t context)
{
      signal4_aa_slot*slot = signal4_aa_get_or_make_slot(context, context_idx_, size_, init_);
      slot->bits.fill_bits(init_);
}

#ifdef CHECK_WITH_VALGRIND
void vvp_fun_signal4_aa::free_instance(vvp_context_t context)
{
      signal4_aa_slot*slot =
            signal4_aa_slot_from_raw(vvp_get_context_item(context, context_idx_));
      delete slot;
}
#endif

/*
 * Continuous and forced assignments are not permitted on automatic
 * variables. So we only expect to receive on port 0.
 */
void vvp_fun_signal4_aa::recv_vec4(vvp_net_ptr_t ptr, const vvp_vector4_t&bit,
                                   vvp_context_t context)
{
      assert(ptr.port() == 0);
      vvp_context_t supplied_context = context;
      context = recover_automatic_recv_context_(context, context_scope_, "recv-vec4-aa");
      /* A detached automatic worker can outlive the lexical chain that
         originally reached its owning task frame. Scoped reads already
         recover that frame when the target scope has exactly one live
         activation. Apply the same unambiguous rule to scalar copy-out so
         a blocking task output (for example UVM FIFO get(dir)) is not
         silently dropped after a nested task call. Never guess when two
         recursive/sibling activations are live. */
      if (!context && supplied_context) {
            context = vthread_recover_unique_context_for_scope(context_scope_);
            if (context)
                  ctx_stats_bump("recv-vec4-aa.unique-repair");
      }
      if (!context)
            return;

      signal4_aa_slot*slot = signal4_aa_get_or_make_slot(context, context_idx_, size_, init_);
      if (recv_vec_trace_scope_match_(context_scope_)) {
            const char*scope_name = context_scope_
                                   ? vpi_get_str(vpiFullName, context_scope_) : 0;
            cerr << "trace recv-vec4-aa scope="
                 << (scope_name ? scope_name : "<unknown>")
                 << " idx=" << context_idx_ << " supplied=" << supplied_context
                 << " resolved=" << context << " old=" << slot->bits
                 << " new=" << bit << endl;
      }
      if (!slot->bits.eeq(bit)) {
            slot->bits = bit;
            ptr.ptr()->send_vec4(slot->bits, context);
      }
}

void vvp_fun_signal4_aa::recv_vec4_pv(vvp_net_ptr_t ptr, const vvp_vector4_t&bit,
				      unsigned base, unsigned vwid, vvp_context_t context)
{
      assert(ptr.port() == 0);
      assert(size_ == vwid);
      context = recover_automatic_recv_context_(context, context_scope_, "recv-vec4-pv-aa");
      if (!context)
            return;

      signal4_aa_slot*slot = signal4_aa_get_or_make_slot(context, context_idx_, size_, init_);

      unsigned wid = bit.size();
      for (unsigned idx = 0 ;  idx < wid ;  idx += 1) {
            if (base+idx >= slot->bits.size()) break;
            slot->bits.set_bit(base+idx, bit.value(idx));
      }
      ptr.ptr()->send_vec4(slot->bits, context);
}

unsigned vvp_fun_signal4_aa::value_size() const
{
      return size_;
}

vvp_bit4_t vvp_fun_signal4_aa::value(unsigned idx) const
{
      const signal4_aa_slot*slot =
            signal4_aa_slot_from_raw(vthread_get_rd_context_item_scoped(context_idx_, context_scope_));
      if (!slot) return BIT4_X;
      return slot->bits.value(idx);
}

vvp_scalar_t vvp_fun_signal4_aa::scalar_value(unsigned idx) const
{
      const signal4_aa_slot*slot =
            signal4_aa_slot_from_raw(vthread_get_rd_context_item_scoped(context_idx_, context_scope_));
      if (!slot) return vvp_scalar_t(BIT4_X, 0, 0);
      return vvp_scalar_t(slot->bits.value(idx), 6, 6);
}

void vvp_fun_signal4_aa::vec4_value(vvp_vector4_t&val) const
{
      const void*raw = vthread_get_rd_context_item_scoped(context_idx_, context_scope_);
      const signal4_aa_slot*slot = signal4_aa_slot_from_raw(raw);
      if (!slot) {
            val = vvp_vector4_t(size_, BIT4_X);
            return;
      }

      val = slot->bits;
      if (load_vec_trace_scope_match_(context_scope_)) {
            const char*scope_name = context_scope_
                                   ? vpi_get_str(vpiFullName, context_scope_) : 0;
            cerr << "trace load-vec4-aa scope="
                 << (scope_name ? scope_name : "<unknown>")
                 << " idx=" << context_idx_ << " rd=" << vthread_get_rd_context()
                 << " raw=" << raw << " value=" << val << endl;
      }
}

const vvp_vector4_t&vvp_fun_signal4_aa::vec4_unfiltered_value() const
{
      const signal4_aa_slot*slot =
            signal4_aa_slot_from_raw(vthread_get_rd_context_item_scoped(context_idx_, context_scope_));
      if (!slot) {
            static vvp_vector4_t fallback(1, BIT4_X);
            return fallback;
      }

      return slot->bits;
}

void vvp_fun_signal4_aa::operator delete(void*)
{
      assert(0);
}

/*
 * A `ref' formal (IEEE 1800-2017 13.5.2). See vvp_net_sig.h.
 */
namespace {
struct ref_aa_slot {
      static const unsigned MAGIC = 0x52454621u; // "REF!"
	/* What this frame's formal is bound to. REF_NET is the ordinary
	   whole-variable binding; the others are storage INSIDE a
	   variable (R25): a class property, a dynamic-array/queue
	   element, or a fixed-array word. */
      enum kind_t { REF_NET = 0, REF_PROP, REF_ELEM, REF_WORD };
      unsigned magic;
      kind_t kind;
      vvp_net_t*target;        // REF_NET: the net; REF_ELEM: the container variable's net
      vvp_context_t caller_ctx;
      vvp_object_t obj;        // REF_PROP: the receiver (a strong handle)
      unsigned prop_id;        // REF_PROP
      int64_t index;           // REF_ELEM / REF_WORD
      struct __vpiArray*arr;   // REF_WORD

      ref_aa_slot() : magic(MAGIC), kind(REF_NET), target(0), caller_ctx(0),
                      prop_id(0), index(0), arr(0) { }
      void clear()
      {
            kind = REF_NET;
            target = 0;
            caller_ctx = 0;
            obj = vvp_object_t();
            prop_id = 0;
            index = 0;
            arr = 0;
      }
};

static ref_aa_slot* ref_aa_slot_from_raw(void*raw)
{
      ref_aa_slot*slot = static_cast<ref_aa_slot*>(raw);
      if (!(slot && slot->magic == ref_aa_slot::MAGIC))
            return 0;
      return slot;
}
}

  /* Resolve this frame's binding. Reads and writes both use the READ
     context: %ref/bind runs between the callee's %alloc and its %fork,
     where the write context is already the callee's frame, but by the
     time the body executes both point at that same frame. */
static ref_aa_slot* ref_slot_(unsigned context_idx, __vpiScope*scope)
{
      return ref_aa_slot_from_raw(
            vthread_get_rd_context_item_scoped(context_idx, scope));
}

vvp_ref_signal_aa::vvp_ref_signal_aa(unsigned wid)
: vvp_fun_signal_object(wid)
{
      context_scope_ = vpip_peek_context_scope();
      context_idx_ = vpip_add_item_to_context(this, context_scope_);
      size_ = wid;
}

vvp_ref_signal_aa::~vvp_ref_signal_aa()
{
      assert(0);
}

void vvp_ref_signal_aa::operator delete(void*)
{
      assert(0);
}

void vvp_ref_signal_aa::alloc_instance(vvp_context_t context)
{
      vvp_set_context_item(context, context_idx_, new ref_aa_slot);
}

void vvp_ref_signal_aa::reset_instance(vvp_context_t context)
{
      ref_aa_slot*slot =
            ref_aa_slot_from_raw(vvp_get_context_item(context, context_idx_));
      if (!slot) {
            slot = new ref_aa_slot;
            vvp_set_context_item(context, context_idx_, slot);
            return;
      }
      slot->clear();
}

#ifdef CHECK_WITH_VALGRIND
void vvp_ref_signal_aa::free_instance(vvp_context_t context)
{
      ref_aa_slot*slot =
            ref_aa_slot_from_raw(vvp_get_context_item(context, context_idx_));
      delete slot;
}
#endif

void vvp_ref_signal_aa::bind(vvp_net_t*net, bool in_frame)
{
      vvp_context_t frame = vthread_get_wt_context();
      if (!frame) return;

      ref_aa_slot*slot =
            ref_aa_slot_from_raw(vvp_get_context_item(frame, context_idx_));
      if (!slot) {
            slot = new ref_aa_slot;
            vvp_set_context_item(frame, context_idx_, slot);
      }

	/* A ref actual that is itself a ref formal binds through to what
	   THAT frame names, so a chain of ref arguments still ends at the
	   one real variable. Resolving here rather than at every access
	   also keeps the caller's frame out of the recorded binding. */
      vvp_ref_signal_aa*chain = net ? dynamic_cast<vvp_ref_signal_aa*>(net->fil) : 0;
      if (chain) {
            ref_aa_slot*outer = ref_slot_(chain->context_idx_, chain->context_scope_);
            if (outer) {
                  slot->kind = outer->kind;
                  slot->target = outer->target;
                  slot->caller_ctx = outer->caller_ctx;
                  slot->obj = outer->obj;
                  slot->prop_id = outer->prop_id;
                  slot->index = outer->index;
                  slot->arr = outer->arr;
                  return;
            }
      }

      slot->clear();
      slot->target = net;
      slot->caller_ctx = in_frame ? frame : vthread_get_rd_context();
}

void vvp_ref_signal_aa::bind_prop(const vvp_object_t&obj, unsigned pid)
{
      vvp_context_t frame = vthread_get_wt_context();
      if (!frame) return;

      ref_aa_slot*slot =
            ref_aa_slot_from_raw(vvp_get_context_item(frame, context_idx_));
      if (!slot) {
            slot = new ref_aa_slot;
            vvp_set_context_item(frame, context_idx_, slot);
      }
      slot->clear();
      slot->kind = ref_aa_slot::REF_PROP;
      slot->obj = obj;
      slot->prop_id = pid;
}

void vvp_ref_signal_aa::bind_elem(vvp_net_t*container, int64_t index)
{
      vvp_context_t frame = vthread_get_wt_context();
      if (!frame) return;

      ref_aa_slot*slot =
            ref_aa_slot_from_raw(vvp_get_context_item(frame, context_idx_));
      if (!slot) {
            slot = new ref_aa_slot;
            vvp_set_context_item(frame, context_idx_, slot);
      }
      slot->clear();
      slot->kind = ref_aa_slot::REF_ELEM;
      slot->target = container;
      slot->caller_ctx = vthread_get_rd_context();
      slot->index = index;
}

void vvp_ref_signal_aa::bind_word(struct __vpiArray*arr, unsigned index)
{
      vvp_context_t frame = vthread_get_wt_context();
      if (!frame) return;

      ref_aa_slot*slot =
            ref_aa_slot_from_raw(vvp_get_context_item(frame, context_idx_));
      if (!slot) {
            slot = new ref_aa_slot;
            vvp_set_context_item(frame, context_idx_, slot);
      }
      slot->clear();
      slot->kind = ref_aa_slot::REF_WORD;
      slot->arr = arr;
      slot->index = index;
}

  /* One delegated access: put the caller's frame back for the duration
     so that a caller-local automatic actual resolves against the frame
     it actually lives in. */
namespace {
class ref_delegate_ {
    public:
      explicit ref_delegate_(const ref_aa_slot*slot)
      {
            vthread_push_ref_context(slot ? slot->caller_ctx : 0, &save_);
      }
      ~ref_delegate_() { vthread_pop_ref_context(&save_); }
    private:
      struct vthread_ref_ctx_save save_;
};
}

  /* Inside-storage accessors (REF_PROP / REF_ELEM / REF_WORD). Each
     write goes straight to the CURRENT storage and each read fetches
     the CURRENT value, so a resize of a bound container or a change
     made directly through the underlying variable is always honoured.
     An out-of-range element index reads the type default and drops the
     write, matching a direct out-of-range element access. */
namespace {

static vvp_cobject* ref_prop_receiver_(const ref_aa_slot*slot)
{
      return slot->obj.peek<vvp_cobject>();
}

  /* The current container held by the bound variable, fetched per
     access through the container variable's own object functor. */
static vvp_darray* ref_elem_container_(const ref_aa_slot*slot)
{
      if (!slot->target) return 0;
      vvp_fun_signal_object*fun =
            dynamic_cast<vvp_fun_signal_object*> (slot->target->fun);
      if (!fun)
            fun = dynamic_cast<vvp_fun_signal_object*> (slot->target->fil);
      if (!fun) return 0;
      vvp_object_t cont = fun->peek_object();
      return cont.peek<vvp_darray>();
}

static bool ref_inside_write_vec4_(ref_aa_slot*slot, const vvp_vector4_t&bit)
{
      switch (slot->kind) {
          case ref_aa_slot::REF_PROP:
            if (vvp_cobject*c = ref_prop_receiver_(slot))
                  c->set_vec4(slot->prop_id, bit);
            return true;
          case ref_aa_slot::REF_ELEM: {
            ref_delegate_ hold (slot);
            if (slot->index >= 0)
                  if (vvp_darray*d = ref_elem_container_(slot))
                        d->set_word((unsigned)slot->index, bit);
            return true;
          }
          case ref_aa_slot::REF_WORD:
            if (slot->arr)
                  slot->arr->set_word(slot->index, 0, bit);
            return true;
          default:
            return false;
      }
}

static bool ref_inside_write_real_(ref_aa_slot*slot, double bit)
{
      switch (slot->kind) {
          case ref_aa_slot::REF_PROP:
            if (vvp_cobject*c = ref_prop_receiver_(slot))
                  c->set_real(slot->prop_id, bit);
            return true;
          case ref_aa_slot::REF_ELEM: {
            ref_delegate_ hold (slot);
            if (slot->index >= 0)
                  if (vvp_darray*d = ref_elem_container_(slot))
                        d->set_word((unsigned)slot->index, bit);
            return true;
          }
          case ref_aa_slot::REF_WORD:
            if (slot->arr)
                  slot->arr->set_word(slot->index, bit);
            return true;
          default:
            return false;
      }
}

static bool ref_inside_write_string_(ref_aa_slot*slot, const std::string&bit)
{
      switch (slot->kind) {
          case ref_aa_slot::REF_PROP:
            if (vvp_cobject*c = ref_prop_receiver_(slot))
                  c->set_string(slot->prop_id, bit);
            return true;
          case ref_aa_slot::REF_ELEM: {
            ref_delegate_ hold (slot);
            if (slot->index >= 0)
                  if (vvp_darray*d = ref_elem_container_(slot))
                        d->set_word((unsigned)slot->index, bit);
            return true;
          }
          case ref_aa_slot::REF_WORD:
            if (slot->arr)
                  slot->arr->set_word(slot->index, bit);
            return true;
          default:
            return false;
      }
}

static bool ref_inside_write_object_(ref_aa_slot*slot, const vvp_object_t&bit)
{
      switch (slot->kind) {
          case ref_aa_slot::REF_PROP:
            if (vvp_cobject*c = ref_prop_receiver_(slot))
                  c->set_object(slot->prop_id, bit, 0);
            return true;
          case ref_aa_slot::REF_ELEM: {
            ref_delegate_ hold (slot);
            if (slot->index >= 0)
                  if (vvp_darray*d = ref_elem_container_(slot))
                        d->set_word((unsigned)slot->index, bit);
            return true;
          }
          case ref_aa_slot::REF_WORD:
            if (slot->arr)
                  slot->arr->set_word(slot->index, bit);
            return true;
          default:
            return false;
      }
}

static bool ref_inside_read_vec4_(const ref_aa_slot*slot, unsigned wid,
                                  vvp_vector4_t&val)
{
      switch (slot->kind) {
          case ref_aa_slot::REF_PROP:
            if (vvp_cobject*c = ref_prop_receiver_(slot))
                  c->get_vec4(slot->prop_id, val);
            else
                  val = vvp_vector4_t(wid, BIT4_X);
            return true;
          case ref_aa_slot::REF_ELEM: {
            ref_delegate_ hold (slot);
            val = vvp_vector4_t(wid, BIT4_X);
            if (slot->index >= 0)
                  if (vvp_darray*d = ref_elem_container_(slot))
                        d->get_word((unsigned)slot->index, val);
            return true;
          }
          case ref_aa_slot::REF_WORD:
            if (slot->arr)
                  val = slot->arr->get_word(slot->index);
            else
                  val = vvp_vector4_t(wid, BIT4_X);
            return true;
          default:
            return false;
      }
}

static bool ref_inside_read_real_(const ref_aa_slot*slot, double&val)
{
      switch (slot->kind) {
          case ref_aa_slot::REF_PROP:
            if (vvp_cobject*c = ref_prop_receiver_(slot))
                  val = c->get_real(slot->prop_id);
            else
                  val = 0.0;
            return true;
          case ref_aa_slot::REF_ELEM: {
            ref_delegate_ hold (slot);
            val = 0.0;
            if (slot->index >= 0)
                  if (vvp_darray*d = ref_elem_container_(slot))
                        d->get_word((unsigned)slot->index, val);
            return true;
          }
          case ref_aa_slot::REF_WORD:
            val = slot->arr ? slot->arr->get_word_r(slot->index) : 0.0;
            return true;
          default:
            return false;
      }
}

static bool ref_inside_read_string_(const ref_aa_slot*slot, std::string&val)
{
      switch (slot->kind) {
          case ref_aa_slot::REF_PROP:
            if (vvp_cobject*c = ref_prop_receiver_(slot))
                  val = c->get_string(slot->prop_id);
            else
                  val = "";
            return true;
          case ref_aa_slot::REF_ELEM: {
            ref_delegate_ hold (slot);
            val = "";
            if (slot->index >= 0)
                  if (vvp_darray*d = ref_elem_container_(slot))
                        d->get_word((unsigned)slot->index, val);
            return true;
          }
          case ref_aa_slot::REF_WORD:
            val = slot->arr ? slot->arr->get_word_str(slot->index) : "";
            return true;
          default:
            return false;
      }
}

static bool ref_inside_read_object_(const ref_aa_slot*slot, vvp_object_t&val)
{
      switch (slot->kind) {
          case ref_aa_slot::REF_PROP:
            if (vvp_cobject*c = ref_prop_receiver_(slot))
                  c->get_object(slot->prop_id, val, 0);
            else
                  val = vvp_object_t();
            return true;
          case ref_aa_slot::REF_ELEM: {
            ref_delegate_ hold (slot);
            val = vvp_object_t();
            if (slot->index >= 0)
                  if (vvp_darray*d = ref_elem_container_(slot))
                        d->get_word((unsigned)slot->index, val);
            return true;
          }
          case ref_aa_slot::REF_WORD:
            val = vvp_object_t();
            if (slot->arr)
                  slot->arr->get_word_obj(slot->index, val);
            return true;
          default:
            return false;
      }
}

}

bool vvp_ref_signal_aa::read_binding(binding_t&out) const
{
      const ref_aa_slot*slot = ref_slot_(context_idx_, context_scope_);
      if (!slot) return false;
      if (slot->kind == ref_aa_slot::REF_NET && !slot->target) return false;

      out.kind = slot->kind;
      out.target = slot->target;
      out.caller_ctx = slot->caller_ctx;
      out.obj = slot->obj;
      out.prop_id = slot->prop_id;
      out.index = slot->index;
      out.arr = slot->arr;
      return true;
}

void vvp_ref_signal_aa::write_binding(vvp_context_t frame, const binding_t&in)
{
      if (!frame) return;

      ref_aa_slot*slot =
            ref_aa_slot_from_raw(vvp_get_context_item(frame, context_idx_));
      if (!slot) {
            slot = new ref_aa_slot;
            vvp_set_context_item(frame, context_idx_, slot);
      }
      slot->kind = static_cast<ref_aa_slot::kind_t>(in.kind);
      slot->target = in.target;
      slot->caller_ctx = in.caller_ctx;
      slot->obj = in.obj;
      slot->prop_id = in.prop_id;
      slot->index = in.index;
      slot->arr = in.arr;
}

vvp_net_t*vvp_ref_signal_aa::target() const
{
      ref_aa_slot*slot = ref_slot_(context_idx_, context_scope_);
      return slot ? slot->target : 0;
}


void vvp_ref_signal_aa::recv_vec4(vvp_net_ptr_t, const vvp_vector4_t&bit,
                                  vvp_context_t)
{
      ref_aa_slot*slot = ref_slot_(context_idx_, context_scope_);
      if (!slot) return;
      if (ref_inside_write_vec4_(slot, bit)) return;
      if (!slot->target) return;

      ref_delegate_ hold (slot);
      vvp_send_vec4(vvp_net_ptr_t(slot->target, 0), bit,
                    vthread_get_wt_context());
}

void vvp_ref_signal_aa::recv_vec4_pv(vvp_net_ptr_t, const vvp_vector4_t&bit,
                                     unsigned base, unsigned vwid, vvp_context_t)
{
      ref_aa_slot*slot = ref_slot_(context_idx_, context_scope_);
      if (!slot) return;
      if (slot->kind != ref_aa_slot::REF_NET) {
	      /* Part-write into inside-storage: read-modify-write. */
            vvp_vector4_t full;
            ref_inside_read_vec4_(slot, vwid, full);
            if (full.size() < vwid)
                  full.resize(vwid, BIT4_X);
            for (unsigned idx = 0; idx < bit.size()
                       && base + idx < full.size(); idx += 1)
                  full.set_bit(base + idx, bit.value(idx));
            ref_inside_write_vec4_(slot, full);
            return;
      }
      if (!slot->target) return;

      ref_delegate_ hold (slot);
      vvp_send_vec4_pv(vvp_net_ptr_t(slot->target, 0), bit, base, vwid,
                       vthread_get_wt_context());
}

void vvp_ref_signal_aa::recv_real(vvp_net_ptr_t, double bit, vvp_context_t)
{
      ref_aa_slot*slot = ref_slot_(context_idx_, context_scope_);
      if (!slot) return;
      if (ref_inside_write_real_(slot, bit)) return;
      if (!slot->target) return;

      ref_delegate_ hold (slot);
      vvp_send_real(vvp_net_ptr_t(slot->target, 0), bit,
                    vthread_get_wt_context());
}

void vvp_ref_signal_aa::recv_string(vvp_net_ptr_t, const std::string&bit,
                                    vvp_context_t)
{
      ref_aa_slot*slot = ref_slot_(context_idx_, context_scope_);
      if (!slot) return;
      if (ref_inside_write_string_(slot, bit)) return;
      if (!slot->target) return;

      ref_delegate_ hold (slot);
      vvp_send_string(vvp_net_ptr_t(slot->target, 0), bit,
                      vthread_get_wt_context());
}

void vvp_ref_signal_aa::recv_object(vvp_net_ptr_t, vvp_object_t bit,
                                    vvp_context_t)
{
      ref_aa_slot*slot = ref_slot_(context_idx_, context_scope_);
      if (!slot) return;
      if (ref_inside_write_object_(slot, bit)) return;
      if (!slot->target) return;

      ref_delegate_ hold (slot);
      vvp_send_object(vvp_net_ptr_t(slot->target, 0), bit,
                      vthread_get_wt_context());
}

  /* Reads. An unbound formal cannot answer, so it reports the width it
     was declared with and an all-x value -- the same thing an
     unallocated automatic reports. */
static vvp_signal_value* ref_read_target_(const ref_aa_slot*slot)
{
      if (!slot || !slot->target) return 0;
      return dynamic_cast<vvp_signal_value*> (slot->target->fil);
}

unsigned vvp_ref_signal_aa::value_size() const
{
      const ref_aa_slot*slot = ref_slot_(context_idx_, context_scope_);
      if (slot && slot->kind != ref_aa_slot::REF_NET)
            return size_;
      vvp_signal_value*sig = ref_read_target_(slot);
      if (!sig) return size_;

      ref_delegate_ hold (slot);
      return sig->value_size();
}

vvp_bit4_t vvp_ref_signal_aa::value(unsigned idx) const
{
      const ref_aa_slot*slot = ref_slot_(context_idx_, context_scope_);
      if (slot && slot->kind != ref_aa_slot::REF_NET) {
            vvp_vector4_t tmp;
            ref_inside_read_vec4_(slot, size_, tmp);
            return idx < tmp.size() ? tmp.value(idx) : BIT4_X;
      }
      vvp_signal_value*sig = ref_read_target_(slot);
      if (!sig) return BIT4_X;

      ref_delegate_ hold (slot);
      return sig->value(idx);
}

vvp_scalar_t vvp_ref_signal_aa::scalar_value(unsigned idx) const
{
      const ref_aa_slot*slot = ref_slot_(context_idx_, context_scope_);
      if (slot && slot->kind != ref_aa_slot::REF_NET) {
            vvp_vector4_t tmp;
            ref_inside_read_vec4_(slot, size_, tmp);
            return vvp_scalar_t(idx < tmp.size() ? tmp.value(idx) : BIT4_X,
                                6, 6);
      }
      vvp_signal_value*sig = ref_read_target_(slot);
      if (!sig) return vvp_scalar_t();

      ref_delegate_ hold (slot);
      return sig->scalar_value(idx);
}

void vvp_ref_signal_aa::vec4_value(vvp_vector4_t&val) const
{
      const ref_aa_slot*slot = ref_slot_(context_idx_, context_scope_);
      if (slot && slot->kind != ref_aa_slot::REF_NET) {
            ref_inside_read_vec4_(slot, size_, val);
            return;
      }
      vvp_signal_value*sig = ref_read_target_(slot);
      if (!sig) {
            val = vvp_vector4_t(size_, BIT4_X);
            return;
      }

      ref_delegate_ hold (slot);
      sig->vec4_value(val);
}

double vvp_ref_signal_aa::real_value() const
{
      const ref_aa_slot*slot = ref_slot_(context_idx_, context_scope_);
      if (slot && slot->kind != ref_aa_slot::REF_NET) {
            double val = 0.0;
            ref_inside_read_real_(slot, val);
            return val;
      }
      vvp_signal_value*sig = ref_read_target_(slot);
      if (!sig) return 0.0;

      ref_delegate_ hold (slot);
      return sig->real_value();
}

void vvp_ref_signal_aa::get_signal_value(struct t_vpi_value*vp)
{
      const ref_aa_slot*slot = ref_slot_(context_idx_, context_scope_);
      if (slot && slot->kind != ref_aa_slot::REF_NET) {
	      /* Serve the common query formats from the current value.
	         (%load/str and %vpi string reads use vpiStringVal /
	         vpiObjTypeVal on string formals.) */
            vvp_vector4_t tmp;
            switch (vp->format) {
                case vpiRealVal: {
                  double rval = 0.0;
                  ref_inside_read_real_(slot, rval);
                  vp->value.real = rval;
                  return;
                }
                case vpiStringVal:
                case vpiObjTypeVal: {
                  static std::string buf;
                  ref_inside_read_string_(slot, buf);
                  vp->format = vpiStringVal;
                  vp->value.str = const_cast<char*>(buf.c_str());
                  return;
                }
                default:
                  ref_inside_read_vec4_(slot, size_, tmp);
                  vpip_vec4_get_value(tmp, size_, false, vp);
                  return;
            }
      }
      vvp_signal_value*sig = ref_read_target_(slot);
      if (!sig) return;

      ref_delegate_ hold (slot);
      sig->get_signal_value(vp);
}

  /* Object reads/writes, for a class-handle formal. Unlike the
     vvp_signal_value case above, the bound target's object functor is
     not reliably reachable through fil alone: a static (non-automatic)
     class-handle variable's fun and fil are NOT the same object (fil is
     nil there -- see compile_var_cobject in words.cc), so check fun
     first and fall back to fil, matching every other object opcode in
     vthread.cc (e.g. signal_object_fun_). */
static vvp_fun_signal_object* ref_read_target_object_(const ref_aa_slot*slot)
{
      if (!slot || !slot->target) return 0;
      vvp_fun_signal_object*fun =
            dynamic_cast<vvp_fun_signal_object*> (slot->target->fun);
      if (!fun)
            fun = dynamic_cast<vvp_fun_signal_object*> (slot->target->fil);
      return fun;
}

vvp_object_t vvp_ref_signal_aa::get_object() const
{
      const ref_aa_slot*slot = ref_slot_(context_idx_, context_scope_);
      if (slot && slot->kind != ref_aa_slot::REF_NET) {
            vvp_object_t val;
            ref_inside_read_object_(slot, val);
            return val;
      }
      vvp_fun_signal_object*obj = ref_read_target_object_(slot);
      if (!obj) return vvp_object_t();

      ref_delegate_ hold (slot);
      return obj->get_object();
}

vvp_object_t vvp_ref_signal_aa::peek_object() const
{
      const ref_aa_slot*slot = ref_slot_(context_idx_, context_scope_);
      if (slot && slot->kind != ref_aa_slot::REF_NET) {
            vvp_object_t val;
            ref_inside_read_object_(slot, val);
            return val;
      }
      vvp_fun_signal_object*obj = ref_read_target_object_(slot);
      if (!obj) return vvp_object_t();

      ref_delegate_ hold (slot);
      return obj->peek_object();
}

vvp_net_t* vvp_ref_signal_aa::get_root_net() const
{
      const ref_aa_slot*slot = ref_slot_(context_idx_, context_scope_);
      vvp_fun_signal_object*obj = ref_read_target_object_(slot);
      if (!obj) return 0;

      ref_delegate_ hold (slot);
      return obj->get_root_net();
}

vvp_object_t vvp_ref_signal_aa::get_root_object() const
{
      const ref_aa_slot*slot = ref_slot_(context_idx_, context_scope_);
      vvp_fun_signal_object*obj = ref_read_target_object_(slot);
      if (!obj) return vvp_object_t();

      ref_delegate_ hold (slot);
      return obj->get_root_object();
}

void vvp_ref_signal_aa::set_root_provenance(vvp_net_t*root_net,
                                            const vvp_object_t&root_obj,
                                            vvp_context_t)
{
      const ref_aa_slot*slot = ref_slot_(context_idx_, context_scope_);
      vvp_fun_signal_object*obj = ref_read_target_object_(slot);
      if (!obj) return;

      ref_delegate_ hold (slot);
      obj->set_root_provenance(root_net, root_obj, vthread_get_wt_context());
}

/*
 * Testing for equality, we want a bitwise test instead of an
 * arithmetic test because we want to treat for example -0 different
 * from +0.
 */
bool bits_equal(double a, double b)
{
      return memcmp(&a, &b, sizeof a) == 0;
}

vvp_fun_signal_real_sa::vvp_fun_signal_real_sa()
{
      bits_ = 0.0;
}

double vvp_fun_signal_real_sa::real_unfiltered_value() const
{
      return bits_;
}

void vvp_fun_signal_real_sa::recv_real(vvp_net_ptr_t ptr, double bit,
                                       vvp_context_t)
{
      switch (ptr.port()) {
	  case 0:
	    if (!continuous_assign_active_) {
                  if (needs_init_ || !bits_equal(bits_, bit)) {
			bits_ = bit;
			needs_init_ = false;
			ptr.ptr()->send_real(bit, 0);
		  }
	    }
	    break;

	  case 1: // Continuous assign value
	    continuous_assign_active_ = true;
	    bits_ = bit;
	    ptr.ptr()->send_real(bit, 0);
	    break;

	  default:
	    fprintf(stderr, "Unsupported port type %u.\n", ptr.port());
	    assert(0);
	    break;
      }
}

vvp_fun_signal_real_aa::vvp_fun_signal_real_aa()
{
      context_scope_ = vpip_peek_context_scope();
      context_idx_ = vpip_add_item_to_context(this, context_scope_);
}

vvp_fun_signal_real_aa::~vvp_fun_signal_real_aa()
{
      assert(0);
}

void vvp_fun_signal_real_aa::alloc_instance(vvp_context_t context)
{
      double*bits = new double;
      vvp_set_context_item(context, context_idx_, bits);

      *bits = 0.0;
}

void vvp_fun_signal_real_aa::reset_instance(vvp_context_t context)
{
      double*bits = static_cast<double*>
            (vvp_get_context_item(context, context_idx_));
      if (!bits) {
            bits = new double;
            vvp_set_context_item(context, context_idx_, bits);
      }

      *bits = 0.0;
}

#ifdef CHECK_WITH_VALGRIND
void vvp_fun_signal_real_aa::free_instance(vvp_context_t context)
{
      double*bits = static_cast<double*>
            (vvp_get_context_item(context, context_idx_));
      delete bits;
}
#endif

double vvp_fun_signal_real_aa::real_unfiltered_value() const
{
      const double*bits = static_cast<double*>
            (vthread_get_rd_context_item_scoped(context_idx_, context_scope_));
      if (!bits) return 0.0;

      return *bits;
}

double vvp_fun_signal_real_aa::real_value() const
{
      return real_unfiltered_value();
}

void vvp_fun_signal_real_aa::recv_real(vvp_net_ptr_t ptr, double bit,
                                       vvp_context_t context)
{
      assert(ptr.port() == 0);
      context = recover_automatic_recv_context_(context, context_scope_, "recv-real-aa");
      if (!context)
            return;

      double*bits = static_cast<double*>
            (vvp_get_context_item(context, context_idx_));
      if (!bits) {
            bits = new double;
            *bits = 0.0;
            vvp_set_context_item(context, context_idx_, bits);
      }

      if (!bits_equal(*bits,bit)) {
            *bits = bit;
            ptr.ptr()->send_real(bit, context);
      }
}

unsigned vvp_fun_signal_real_aa::value_size() const
{
      assert(0);
      return 1;
}

vvp_bit4_t vvp_fun_signal_real_aa::value(unsigned) const
{
      assert(0);
      return BIT4_X;
}

vvp_scalar_t vvp_fun_signal_real_aa::scalar_value(unsigned) const
{
      assert(0);
      return vvp_scalar_t();
}

void vvp_fun_signal_real_aa::vec4_value(vvp_vector4_t&) const
{
      assert(0);
}

void* vvp_fun_signal_real_aa::operator new(std::size_t size)
{
      return vvp_net_fun_t::heap_.alloc(size);
}

void vvp_fun_signal_real_aa::operator delete(void*)
{
      assert(0);
}


vvp_fun_signal_string_sa::vvp_fun_signal_string_sa()
{
}

void vvp_fun_signal_string_sa::recv_string(vvp_net_ptr_t ptr, const std::string&bit,
					   vvp_context_t)
{
      assert(ptr.port() == 0);

      if (needs_init_ || value_ != bit) {
	    value_ = bit;
	    needs_init_ = false;

	    ptr.ptr()->send_string(bit, 0);
	    run_sv_vpi_callbacks();
      }
}

const string& vvp_fun_signal_string_sa::get_string() const
{
      return value_;
}

vvp_fun_signal_string_aa::vvp_fun_signal_string_aa()
{
      context_scope_ = vpip_peek_context_scope();
      context_idx_ = vpip_add_item_to_context(this, context_scope_);
}

vvp_fun_signal_string_aa::~vvp_fun_signal_string_aa()
{
      assert(0);
}

namespace {
struct vvp_string_slot_s {
      static const uint64_t kMagic = UINT64_C(0x5656505354524e47); // "VVPSTRNG"
      uint64_t magic;
      std::string value;
      vvp_string_slot_s() : magic(kMagic), value() { }
};

static inline bool slot_ptr_poisoned_(const void*ptr)
{
      uintptr_t u = reinterpret_cast<uintptr_t>(ptr);
      if (u == 0 || u < 4096)
            return u != 0;
      if (u == UINT64_C(0xbebebebebebebebe)
          || u == UINT64_C(0xcdcdcdcdcdcdcdcd)
          || u == UINT64_C(0xfefefefefefefefe)
          || u == UINT64_C(0xdddddddddddddddd))
            return true;
      return false;
}
}

void vvp_fun_signal_string_aa::alloc_instance(vvp_context_t context)
{
      vvp_string_slot_s*slot = new vvp_string_slot_s;
      vvp_set_context_item(context, context_idx_, slot);
      slot->value = "";
}

void vvp_fun_signal_string_aa::reset_instance(vvp_context_t context)
{
      void*raw = vvp_get_context_item(context, context_idx_);
      vvp_string_slot_s*slot = static_cast<vvp_string_slot_s*>(raw);
      if (!slot || slot_ptr_poisoned_(slot) || slot->magic != vvp_string_slot_s::kMagic) {
            slot = new vvp_string_slot_s;
            vvp_set_context_item(context, context_idx_, slot);
      }
      slot->value = "";
}

#ifdef CHECK_WITH_VALGRIND
void vvp_fun_signal_string_aa::free_instance(vvp_context_t context)
{
      vvp_string_slot_s*slot = static_cast<vvp_string_slot_s*>
            (vvp_get_context_item(context, context_idx_));
      if (slot && !slot_ptr_poisoned_(slot) && slot->magic == vvp_string_slot_s::kMagic)
            delete slot;
}
#endif

void vvp_fun_signal_string_aa::recv_string(vvp_net_ptr_t ptr, const std::string&bit, vvp_context_t context)
{
      assert(ptr.port() == 0);
      context = recover_automatic_recv_context_(context, context_scope_, "recv-string-aa");
      if (!context)
            return;

      void*raw = vvp_get_context_item(context, context_idx_);
      vvp_string_slot_s*slot = static_cast<vvp_string_slot_s*>(raw);
      if (!slot || slot_ptr_poisoned_(slot) || slot->magic != vvp_string_slot_s::kMagic) {
            slot = new vvp_string_slot_s;
            slot->value = "";
            vvp_set_context_item(context, context_idx_, slot);
      }

      if (slot->value != bit) {
	    slot->value = bit;
	    ptr.ptr()->send_string(bit, context);
      }
}

unsigned vvp_fun_signal_string_aa::value_size() const
{
      return 1;
}

vvp_bit4_t vvp_fun_signal_string_aa::value(unsigned) const
{
      return BIT4_X;
}

vvp_scalar_t vvp_fun_signal_string_aa::scalar_value(unsigned) const
{
      return vvp_scalar_t();
}

void vvp_fun_signal_string_aa::vec4_value(vvp_vector4_t&val) const
{
      val = vvp_vector4_t(1, BIT4_X);
}

double vvp_fun_signal_string_aa::real_value() const
{
      return 0.0;
}

const std::string& vvp_fun_signal_string_aa::get_string() const
{
      const char*scope_name = 0;
      bool trace_this = false;
      if (load_str_trace_configured_()) {
            scope_name = context_scope_
                  ? vpi_get_str(vpiFullName, context_scope_) : 0;
            trace_this = load_str_trace_scope_match_(scope_name);
      }
      const void*raw = vthread_get_rd_context_item_scoped(context_idx_, context_scope_);
      const vvp_string_slot_s*slot = static_cast<const vvp_string_slot_s*>(raw);
      if (!slot || slot_ptr_poisoned_(slot) || slot->magic != vvp_string_slot_s::kMagic) {
            if (trace_this) {
                  __vpiScope*cur_scope = vpip_peek_current_scope();
                  const char*cur_name = cur_scope ? vpi_get_str(vpiFullName, cur_scope) : 0;
                  fprintf(stderr,
                          "trace load_str-invalid target=%s current=%s rd=%p wt=%p raw=%p\n",
                          scope_name ? scope_name : "<unknown>",
                          cur_name ? cur_name : "<unknown>",
                          vthread_get_rd_context(), vthread_get_wt_context(), raw);
            }
            static const std::string empty;
            return empty;
      }

      if (trace_this) {
            __vpiScope*cur_scope = vpip_peek_current_scope();
            const char*cur_name = cur_scope ? vpi_get_str(vpiFullName, cur_scope) : 0;
            fprintf(stderr,
                    "trace load_str-ok target=%s current=%s rd=%p wt=%p raw=%p len=%zu text=\"%.*s\"\n",
                    scope_name ? scope_name : "<unknown>",
                    cur_name ? cur_name : "<unknown>",
                    vthread_get_rd_context(), vthread_get_wt_context(), raw,
                    slot->value.size(),
                    (int)(slot->value.size() < 80 ? slot->value.size() : 80),
                    slot->value.c_str());
      }
      return slot->value;
}

void* vvp_fun_signal_string_aa::operator new(std::size_t size)
{
      return vvp_net_fun_t::heap_.alloc(size);
}

void vvp_fun_signal_string_aa::operator delete(void*)
{
      assert(0);
}

  /* OBJECT signals */

namespace {
struct signal_object_aa_slot {
      static const unsigned MAGIC = 0x5349474fu; // "SIGO"
      unsigned magic;
      vvp_object_t value;
      uint64_t epoch;
      vvp_net_t* root_net;
      vvp_object_t root_obj;

      signal_object_aa_slot() : magic(MAGIC), value(), epoch(0), root_net(0), root_obj()
      {
      }
};

static signal_object_aa_slot* signal_object_aa_slot_from_raw(void*raw)
{
      signal_object_aa_slot*slot = static_cast<signal_object_aa_slot*>(raw);
      if (!slot || slot_ptr_poisoned_(slot) || slot->magic != signal_object_aa_slot::MAGIC)
            return 0;
      return slot;
}

static const signal_object_aa_slot* signal_object_aa_slot_from_raw(const void*raw)
{
      const signal_object_aa_slot*slot = static_cast<const signal_object_aa_slot*>(raw);
      if (!slot || slot_ptr_poisoned_(slot) || slot->magic != signal_object_aa_slot::MAGIC)
            return 0;
      return slot;
}

static signal_object_aa_slot* signal_object_aa_get_or_make_slot(vvp_context_t context,
                                                                 unsigned context_idx)
{
      // Phase 61d: bypass the malloc_usable_size bounds check.  This is
      // called per recv_object (per signal-alias notification); under heavy
      // alias activity the bounds check shows up as malloc_usable_size in
      // SIGUSR1 sample backtraces.  context_idx_ is set at compile time by
      // the elaboration pass and is guaranteed to fit any allocated context
      // for the matching scope; the bounds check is purely defensive.
      if (!context)
            return 0;
      signal_object_aa_slot*slot =
            signal_object_aa_slot_from_raw((vvp_context_item_t)context[context_idx]);
      if (!slot) {
            slot = new signal_object_aa_slot;
            context[context_idx] = slot;
      }
      return slot;
}
}

vvp_fun_signal_object_sa::vvp_fun_signal_object_sa(unsigned size)
: vvp_fun_signal_object(size)
{
      init_defn_ = 0;
      value_epoch_ = 0;
      root_net_ = 0;
      attached_net_ = 0;
}

#ifdef CHECK_WITH_VALGRIND
void vvp_fun_signal_object_aa::free_instance(vvp_context_t context)
{
      signal_object_aa_slot*slot =
            signal_object_aa_slot_from_raw(vvp_get_context_item(context, context_idx_));
      if (slot && attached_net_ && !slot->value.test_nil())
            slot->value.unregister_signal_alias(attached_net_, context);
      delete slot;
}
#endif

void vvp_fun_signal_object_sa::recv_object(vvp_net_ptr_t ptr, vvp_object_t bit,
					   vvp_context_t)
{
      assert(ptr.port() == 0);
      attached_net_ = ptr.ptr();
      uint64_t bit_epoch = bit.mutation_epoch();

      if (needs_init_ || value_ != bit || value_epoch_ != bit_epoch) {
            if (attached_net_ && !value_.test_nil())
                  value_.unregister_signal_alias(attached_net_, 0);
	    value_ = bit;
	    value_epoch_ = bit_epoch;
            if (attached_net_ && !value_.test_nil())
                  value_.register_signal_alias(attached_net_, 0);
	    needs_init_ = false;

	    ptr.ptr()->send_object(bit, 0);
	    run_sv_vpi_callbacks();
      }
}

vvp_object_t vvp_fun_signal_object_sa::get_object() const
{
      if (value_.test_nil() && (init_defn_ || default_object_kind() != INIT_OBJ_NONE)) {
	    value_ = init_defn_
	           ? vvp_object_t(new vvp_cobject(init_defn_))
	           : make_default_object();
            value_epoch_ = value_.mutation_epoch();
      }
      return value_;
}

vvp_object_t vvp_fun_signal_object_sa::peek_object() const
{
      return value_;
}

vvp_net_t* vvp_fun_signal_object_sa::get_root_net() const
{
      return root_net_;
}

vvp_object_t vvp_fun_signal_object_sa::get_root_object() const
{
      return root_obj_;
}

void vvp_fun_signal_object_sa::set_root_provenance(vvp_net_t*root_net,
                                                   const vvp_object_t&root_obj,
                                                   vvp_context_t)
{
      root_net_ = root_net;
      root_obj_ = root_obj;
}

vvp_fun_signal_object_aa::vvp_fun_signal_object_aa(unsigned size)
: vvp_fun_signal_object(size)
{
      init_defn_ = 0;
      context_scope_ = vpip_peek_context_scope();
      context_idx_ = vpip_add_item_to_context(this, context_scope_);
      attached_net_ = 0;
}

vvp_fun_signal_object_aa::~vvp_fun_signal_object_aa()
{
      assert(0);
}

void vvp_fun_signal_object_aa::alloc_instance(vvp_context_t context)
{
      signal_object_aa_slot*slot = new signal_object_aa_slot;
      if (init_defn_)
	    slot->value = vvp_object_t(new vvp_cobject(init_defn_));
      else
	    slot->value = make_default_object();
      slot->epoch = slot->value.mutation_epoch();
      vvp_set_context_item(context, context_idx_, slot);
}

void vvp_fun_signal_object_aa::reset_instance(vvp_context_t context)
{
      signal_object_aa_slot*slot = signal_object_aa_get_or_make_slot(context, context_idx_);
      if (attached_net_ && !slot->value.test_nil())
            slot->value.unregister_signal_alias(attached_net_, context);
      if (init_defn_)
	    slot->value = vvp_object_t(new vvp_cobject(init_defn_));
      else
	    slot->value = make_default_object();
      slot->epoch = slot->value.mutation_epoch();
      slot->root_net = 0;
      slot->root_obj.reset();
}

vvp_object_t vvp_fun_signal_object_aa::get_object() const
{
      void*raw_item = vthread_get_rd_context_item_scoped(context_idx_, context_scope_);
      signal_object_aa_slot*slot = signal_object_aa_slot_from_raw(raw_item);
      if (!slot) {
            vvp_object_t empty;
            return empty;
      }
      if (slot->value.test_nil() && (init_defn_ || default_object_kind() != INIT_OBJ_NONE)) {
	    slot->value = init_defn_
	                ? vvp_object_t(new vvp_cobject(init_defn_))
	                : make_default_object();
            slot->epoch = slot->value.mutation_epoch();
      }
      return slot->value;
}

vvp_object_t vvp_fun_signal_object_aa::peek_object() const
{
      signal_object_aa_slot*slot =
            signal_object_aa_slot_from_raw(vthread_get_rd_context_item_scoped(context_idx_,
                                                                               context_scope_));
      if (!slot) {
            vvp_object_t empty;
            return empty;
      }
      return slot->value;
}

vvp_net_t* vvp_fun_signal_object_aa::get_root_net() const
{
      const signal_object_aa_slot*slot =
            signal_object_aa_slot_from_raw(vthread_get_rd_context_item_scoped(context_idx_,
                                                                               context_scope_));
      if (!slot)
            return 0;
      return slot->root_net;
}

vvp_object_t vvp_fun_signal_object_aa::get_root_object() const
{
      const signal_object_aa_slot*slot =
            signal_object_aa_slot_from_raw(vthread_get_rd_context_item_scoped(context_idx_,
                                                                               context_scope_));
      if (!slot) {
            vvp_object_t empty;
            return empty;
      }
      return slot->root_obj;
}

void vvp_fun_signal_object_aa::set_root_provenance(vvp_net_t*root_net,
                                                   const vvp_object_t&root_obj,
                                                   vvp_context_t context)
{
      context = recover_automatic_recv_context_(context, context_scope_,
                                                "set-root-provenance-aa");
      if (!context) {
            return;
      }

      signal_object_aa_slot*slot = signal_object_aa_get_or_make_slot(context, context_idx_);
      slot->root_net = root_net;
      slot->root_obj = root_obj;
}

void vvp_fun_signal_object_aa::recv_object(vvp_net_ptr_t ptr, vvp_object_t bit,
					   vvp_context_t context)
{
      assert(ptr.port() == 0);
      attached_net_ = ptr.ptr();

	/* An assignment executed in a nested automatic function/block carries
	   that nested frame, while its destination can be a local in an
	   enclosing automatic task. Vector, string and real automatic signals
	   already repair this through recover_automatic_recv_context_. Object
	   signals also receive mutation notifications, so do the narrower safe
	   version here. Prefer a matching frame on the supplied lexical stack.
	   A detached nested block can outlive the link to its enclosing task;
	   in that case recover the task only when (a) the supplied context is
	   lexically inside the target scope and (b) the target has exactly one
	   live activation. This never guesses between recursive/sibling frames
	   and does not redirect unrelated object-mutation notifications. This is
	   the UVM FIFO `try_get(item)' copy-back shape from a detached scoreboard
	   worker. */
      if (context
	  && !vthread_context_live_matches_scope(context, context_scope_)) {
	    vvp_context_t stacked =
		  vthread_recover_stacked_context_for_scope(context,
						     context_scope_);
	    if (stacked) {
		  context = stacked;
		  ctx_stats_bump("recv-obj-aa.stacked-repair");
	    } else if (vthread_context_owner_is_within(context, context_scope_)) {
		  vvp_context_t unique =
			vthread_recover_unique_context_for_scope(context_scope_);
		  if (unique) {
			context = unique;
			ctx_stats_bump("recv-obj-aa.unique-nested-repair");
		  }
	    }
      }
      if (recv_object_trace_configured_()) {
            const char*scope_name = context_scope_
                  ? vpi_get_str(vpiFullName, context_scope_) : 0;
            if (recv_object_trace_scope_match_(scope_name)) {
            fprintf(stderr,
                    "trace recv-object-aa scope=%s net=%p ctx=%p native=%d val_nil=%d val=%p\n",
                    scope_name ? scope_name : "<unknown>",
                    (void*)ptr.ptr(), context,
                    context && vthread_context_live_matches_scope(context, context_scope_) ? 1 : 0,
                    bit.test_nil() ? 1 : 0,
                    bit.peek<vvp_object>());
            }
      }

	/* A store executed by a thread in this functor's scope carries a
	   context that is a live frame of this scope: update that frame's
	   slot and propagate in that context. */
      if (context && vthread_context_live_matches_scope(context, context_scope_)) {
	    signal_object_aa_slot*slot =
		  signal_object_aa_get_or_make_slot(context, context_idx_);
	    uint64_t bit_epoch = bit.mutation_epoch();

	    if (slot->value != bit || slot->epoch != bit_epoch) {
		  if (attached_net_ && !slot->value.test_nil())
			slot->value.unregister_signal_alias(attached_net_, context);
		  slot->value = bit;
		  slot->epoch = bit_epoch;
		  if (attached_net_ && !slot->value.test_nil())
			slot->value.register_signal_alias(attached_net_, context);
		  ptr.ptr()->send_object(bit, context);
	    }
	    return;
      }

	/* Any other delivery is an object-mutation notification re-sent
	   through the recorded root net (notify_mutated_object_root_): the
	   sender's context belongs to the MUTATING thread's scope, not to
	   this one. Deliver the wake to every live frame of this scope
	   whose slot currently holds the same object. Frames whose slot
	   holds a different object are sibling invocations with unrelated
	   locals and must not be touched; if no live frame holds the
	   object there is nothing to wake. (This replaces the former
	   recover-to-first-live-frame repair, which delivered to one
	   arbitrary frame of the scope and could overwrite a sibling
	   invocation's local with the notifying object.) */
      if (bit.test_nil() || !context_scope_)
	    return;
      uint64_t bit_epoch = bit.mutation_epoch();
      unsigned delivered = 0;
      for (vvp_context_t scan = context_scope_->live_contexts ; scan ;
	   scan = vvp_get_next_context(scan)) {
	    signal_object_aa_slot*slot =
		  signal_object_aa_slot_from_raw(vvp_get_context_item(scan, context_idx_));
	    if (!slot)
		  continue;
	    if (slot->value != bit)
		  continue;
	    if (slot->epoch == bit_epoch)
		  continue;
	    slot->epoch = bit_epoch;
	    ptr.ptr()->send_object(bit, scan);
	    delivered += 1;
      }
      ctx_stats_bump(delivered ? "recv-obj-aa.notify-fanout"
			       : "recv-obj-aa.notify-unheld");
}

void vvp_fun_signal_object_aa::clear_current_alias(vvp_context_t context)
{
      signal_object_aa_slot*slot =
            signal_object_aa_slot_from_raw(vvp_get_context_item(context, context_idx_));
      if (!slot || !attached_net_ || slot->value.test_nil())
            return;
      slot->value.unregister_signal_alias(attached_net_, context);
}

unsigned vvp_fun_signal_object_aa::value_size() const
{
      return 1;
}

vvp_bit4_t vvp_fun_signal_object_aa::value(unsigned) const
{
      return BIT4_X;
}

vvp_scalar_t vvp_fun_signal_object_aa::scalar_value(unsigned) const
{
      return vvp_scalar_t();
}

void vvp_fun_signal_object_aa::vec4_value(vvp_vector4_t&val) const
{
      val = vvp_vector4_t(1, BIT4_X);
}

void* vvp_fun_signal_object_aa::operator new(std::size_t size)
{
      return vvp_net_fun_t::heap_.alloc(size);
}

void vvp_fun_signal_object_aa::operator delete(void*)
{
      assert(0);
}

  /* **** */

vvp_fun_force::vvp_fun_force()
{
}

vvp_fun_force::~vvp_fun_force()
{
}

void vvp_fun_force::recv_vec4(vvp_net_ptr_t ptr, const vvp_vector4_t&bit,
			      vvp_context_t)
{
      assert(ptr.port() == 0);
      vvp_net_t*net = ptr.ptr();

      vvp_net_t*dst = net->port[3].ptr();
      assert(dst->fil);

      dst->force_vec4(coerce_to_width(bit, dst->fil->filter_size()), vvp_vector2_t(vvp_vector2_t::FILL1, dst->fil->filter_size()));
}

void vvp_fun_force::recv_real(vvp_net_ptr_t ptr, double bit, vvp_context_t)
{
      assert(ptr.port() == 0);
      vvp_net_t*net = ptr.ptr();
      vvp_net_t*dst = net->port[3].ptr();
      dst->force_real(bit, vvp_vector2_t(vvp_vector2_t::FILL1, 1));
}

vvp_wire_base::vvp_wire_base()
{
}

vvp_wire_base::~vvp_wire_base()
{
}

vvp_bit4_t vvp_wire_base::driven_value(unsigned) const
{
      assert(0);
      return BIT4_X;
}

bool vvp_wire_base::is_forced(unsigned) const
{
      assert(0);
      return false;
}

vvp_wire_vec4::vvp_wire_vec4(unsigned wid, vvp_bit4_t init)
: bits4_(wid, init)
{
      needs_init_ = true;
      hist_enabled_ = false;
      hist_valid_ = false;
      hist_time_ = 0;
}

/* Record the pre-change value the first time the signal changes in a
   given time step. Later changes in the same step keep the original
   snapshot, so hist_prev_ is always the value from the end of the
   previous time step. */
void vvp_wire_vec4::hist_snapshot_()
{
      if (!hist_enabled_) return;
      vvp_time64_t now = schedule_simtime();
      if (hist_valid_ && hist_time_ == now) return;
      hist_prev_ = bits4_;
      hist_time_ = now;
      hist_valid_ = true;
}

/* The Preponed-region value: if the signal has changed during the
   current time step, the value it had when the step started;
   otherwise the current value. */
void vvp_wire_vec4::vec4_preponed_value(vvp_vector4_t&val) const
{
      if (hist_enabled_ && hist_valid_
	  && hist_time_ == schedule_simtime()) {
	    val = hist_prev_;
	    return;
      }
      vec4_value(val);
}

vvp_net_fil_t::prop_t vvp_wire_vec4::filter_vec4(const vvp_vector4_t&bit, vvp_vector4_t&rep,
						 unsigned base, unsigned vwid)
{
	// Special case! the input bit is 0 wid. Interpret this as a
	// vector of BIT4_X to match the width of the bits4_ vector.
	// FIXME! This is a hack to work around some buggy gate
	// implementations! This should be removed!
      if (base==0 && vwid==0) {
	    vvp_vector4_t tmp (bits4_.size(), BIT4_X);
	    if (bits4_ .eeq(tmp) && !needs_init_) return STOP;
	    hist_snapshot_();
	    bits4_ = tmp;
	    needs_init_ = false;
	    return filter_mask_(tmp, force4_, rep, 0);
      }

      if (vwid != bits4_.size()) {
	    cerr << "Internal error: Input vector expected width="
		 << bits4_.size() << ", got "
		 << "bit=" << bit << ", base=" << base << ", vwid=" << vwid
		 << endl;
      }
      assert(bits4_.size() == vwid);

	// Keep track of the value being driven from this net, even if
	// it is not ultimately what survives the force filter.
      if (base==0 && bit.size()==vwid) {
	    if (bits4_ .eeq( bit ) && !needs_init_) return STOP;
	    hist_snapshot_();
	    bits4_ = bit;
      } else {
	    hist_snapshot_();
	    bool rc = bits4_.set_vec(base, bit);
	    if (rc == false && !needs_init_) return STOP;
      }

      needs_init_ = false;
      return filter_mask_(bit, force4_, rep, base);
}

vvp_net_fil_t::prop_t vvp_wire_vec4::filter_vec8(const vvp_vector8_t&bit,
                                                 vvp_vector8_t&rep,
                                                 unsigned base,
                                                 unsigned vwid)
{
      assert(bits4_.size() == vwid);

	// Keep track of the value being driven from this net, even if
	// it is not ultimately what survives the force filter.
      vvp_vector4_t bit4 (reduce4(bit));
      if (base==0 && bit4.size()==vwid) {
	    if (bits4_ .eeq( bit4 ) && !needs_init_) return STOP;
	    hist_snapshot_();
	    bits4_ = bit4;
      } else {
	    hist_snapshot_();
	    bool rc = bits4_.set_vec(base, bit4);
	    if (rc == false && !needs_init_) return STOP;
      }

      needs_init_ = false;
      return filter_mask_(bit, vvp_vector8_t(force4_,6,6), rep, base);
}

unsigned vvp_wire_vec4::filter_size() const
{
      return bits4_.size();
}

void vvp_wire_vec4::force_fil_vec4(const vvp_vector4_t&val, const vvp_vector2_t&mask)
{
      force_mask(mask);

      if (force4_.size() == 0) {
	    force4_ = val;
      } else {
	    for (unsigned idx = 0; idx < mask.size() ; idx += 1) {
		  if (mask.value(idx) == 0)
			continue;

		  force4_.set_bit(idx, val.value(idx));
	    }
      }
      run_vpi_callbacks();
}

void vvp_wire_vec4::force_fil_vec8(const vvp_vector8_t&, const vvp_vector2_t&)
{
      assert(0);
}

void vvp_wire_vec4::force_fil_real(double, const vvp_vector2_t&)
{
      assert(0);
}

void vvp_wire_vec4::release(vvp_net_ptr_t ptr, bool net_flag)
{
      vvp_vector2_t mask (vvp_vector2_t::FILL1, bits4_.size());
      if (net_flag) {
	      // Wires revert to their unforced value after release.
            release_mask(mask);
	    needs_init_ = ! force4_ .eeq(bits4_);
	    ptr.ptr()->send_vec4(bits4_, 0);
	    run_vpi_callbacks();
      } else {
	      // Variables keep the current value.
	    vvp_vector4_t res (bits4_.size());
	    for (unsigned idx=0; idx<bits4_.size(); idx += 1)
		  res.set_bit(idx,value(idx));
            release_mask(mask);
	    ptr.ptr()->fun->recv_vec4(ptr, res, 0);
      }
}

void vvp_wire_vec4::release_pv(vvp_net_ptr_t ptr, unsigned base, unsigned wid, bool net_flag)
{
      assert(bits4_.size() >= base + wid);

      vvp_vector2_t mask (vvp_vector2_t::FILL0, bits4_.size());
      for (unsigned idx = 0 ; idx < wid ; idx += 1)
	    mask.set_bit(base+idx, 1);

      if (net_flag) {
	      // Wires revert to their unforced value after release.
	    release_mask(mask);
	    needs_init_ = ! force4_.subvalue(base,wid) .eeq(bits4_.subvalue(base,wid));
	    ptr.ptr()->send_vec4_pv(bits4_.subvalue(base,wid),
				    base, bits4_.size(), 0);
	    run_vpi_callbacks();
      } else {
	      // Variables keep the current value.
	    vvp_vector4_t res (wid);
	    for (unsigned idx=0; idx<wid; idx += 1)
		  res.set_bit(idx,value(base+idx));
	    release_mask(mask);
	    ptr.ptr()->fun->recv_vec4_pv(ptr, res, base, bits4_.size(), 0);
      }
}

unsigned vvp_wire_vec4::value_size() const
{
      return bits4_.size();
}

vvp_bit4_t vvp_wire_vec4::filtered_value_(unsigned idx) const
{
      if (test_force_mask(idx))
	    return force4_.value(idx);
      else
	    return bits4_.value(idx);
}

vvp_bit4_t vvp_wire_vec4::value(unsigned idx) const
{
      return filtered_value_(idx);
}

vvp_scalar_t vvp_wire_vec4::scalar_value(unsigned idx) const
{
      return vvp_scalar_t(value(idx),6,6);
}

void vvp_wire_vec4::vec4_value(vvp_vector4_t&val) const
{
      val = bits4_;
      if (test_force_mask_is_zero())
	    return;

      for (unsigned idx = 0 ; idx < bits4_.size() ; idx += 1)
	    val.set_bit(idx, filtered_value_(idx));
}

vvp_bit4_t vvp_wire_vec4::driven_value(unsigned idx) const
{
      return bits4_.value(idx);
}

bool vvp_wire_vec4::is_forced(unsigned idx) const
{
      return test_force_mask(idx);
}

vvp_wire_vec8::vvp_wire_vec8(unsigned wid)
: bits8_(wid)
{
      needs_init_ = true;
}

vvp_net_fil_t::prop_t vvp_wire_vec8::filter_vec4(const vvp_vector4_t&bit,
                                                 vvp_vector4_t&rep,
                                                 unsigned base,
                                                 unsigned vwid)
{
	// For now there is no support for a non-zero base.
      assert(0 == base);
      assert(bits8_.size() == vwid);
      assert(bits8_.size() == bit.size());
	// QUESTION: Is it really correct to propagate a vec4 if this
	// is a vec8 node? In fact, it is really possible for a vec4
	// value to get through to a vec8 filter?
      vvp_vector8_t rep8;
      prop_t rc = filter_vec8(vvp_vector8_t(bit,6,6), rep8, 0, vwid);
      if (rc == REPL)
	    rep = reduce4(rep8);

      needs_init_ = false;
      return rc;
}

vvp_net_fil_t::prop_t vvp_wire_vec8::filter_vec8(const vvp_vector8_t&bit, vvp_vector8_t&rep, unsigned base, unsigned vwid)
{
      assert(vwid == bits8_.size());
	// Keep track of the value being driven from this net, even if
	// it is not ultimately what survives the force filter.
      if (base==0 && bit.size()==vwid) {
	    bits8_ = bit;
      } else {
	    if (bits8_.size() == 0)
		  bits8_ = vvp_vector8_t(vwid);
	    assert(bits8_.size() == vwid);
	    bits8_.set_vec(base, bit);
      }
      needs_init_ = false;
      return filter_mask_(bit, force8_, rep, base);
}

vvp_net_fil_t::prop_t vvp_wire_vec8::filter_input_vec8(const vvp_vector8_t&bit, vvp_vector8_t&rep) const
{
      return filter_input_mask_(bit, force8_, rep);
}

unsigned vvp_wire_vec8::filter_size() const
{
      return bits8_.size();
}

void vvp_wire_vec8::force_fil_vec4(const vvp_vector4_t&val, const vvp_vector2_t&mask)
{
      force_fil_vec8(vvp_vector8_t(val,6,6), mask);
}

void vvp_wire_vec8::force_fil_vec8(const vvp_vector8_t&val, const vvp_vector2_t&mask)
{
      force_mask(mask);

      if (force8_.size() == 0) {
	    force8_ = val;
      } else {
	    for (unsigned idx = 0; idx < mask.size() ; idx += 1) {
		  if (mask.value(idx) == 0)
			continue;

		  force8_.set_bit(idx, val.value(idx));
	    }
      }
      run_vpi_callbacks();
}

void vvp_wire_vec8::force_fil_real(double, const vvp_vector2_t&)
{
      assert(0);
}

void vvp_wire_vec8::release(vvp_net_ptr_t ptr, bool net_flag)
{
	// Wires revert to their unforced value after release.
      vvp_vector2_t mask (vvp_vector2_t::FILL1, bits8_.size());
      release_mask(mask);
      if (net_flag) {
	    needs_init_ = !force8_ .eeq(bits8_);
	    ptr.ptr()->send_vec8(bits8_);
      } else {
	// Variable do not know about strength so this should not be able
	// to happen. If for some reason it can then it should not be too
	// hard to fix this code like was done for vvp_wire_vec4 above.
	    assert(0);
//	    ptr.ptr()->fun->recv_vec8(ptr, force8_);
      }
}

void vvp_wire_vec8::release_pv(vvp_net_ptr_t ptr, unsigned base, unsigned wid, bool net_flag)
{
      assert(bits8_.size() >= base + wid);

      vvp_vector2_t mask (vvp_vector2_t::FILL0, bits8_.size());
      for (unsigned idx = 0 ; idx < wid ; idx += 1)
	    mask.set_bit(base+idx, 1);

      release_mask(mask);

      if (net_flag) {
	    needs_init_ = !force8_.subvalue(base,wid) .eeq((bits8_.subvalue(base,wid)));
	    ptr.ptr()->send_vec8_pv(bits8_.subvalue(base,wid),
				    base, bits8_.size());
	    run_vpi_callbacks();
      } else {
	// Variable do not know about strength so this should not be able
	// to happen. If for some reason it can then it should not be too
	// hard to fix this code like was done for vvp_wire_vec4 above.
	    assert(0);
//	    ptr.ptr()->fun->recv_vec8_pv(ptr, force8_.subvalue(base,wid),
//					 base, force8_.size());
      }
}

unsigned vvp_wire_vec8::value_size() const
{
      return bits8_.size();
}

vvp_scalar_t vvp_wire_vec8::filtered_value_(unsigned idx) const
{
      if (test_force_mask(idx))
	    return force8_.value(idx);
      else
	    return bits8_.value(idx);
}

vvp_bit4_t vvp_wire_vec8::value(unsigned idx) const
{
      return filtered_value_(idx).value();
}

vvp_scalar_t vvp_wire_vec8::scalar_value(unsigned idx) const
{
      return filtered_value_(idx);
}

vvp_vector8_t vvp_wire_vec8::vec8_value() const
{
      vvp_vector8_t tmp = bits8_;
      for (unsigned idx = 0 ; idx < bits8_.size() ; idx += 1)
	    tmp.set_bit(idx, filtered_value_(idx));
      return tmp;
}

void vvp_wire_vec8::vec4_value(vvp_vector4_t&val) const
{
      val = reduce4(vec8_value());
}

vvp_bit4_t vvp_wire_vec8::driven_value(unsigned idx) const
{
      return bits8_.value(idx).value();
}

bool vvp_wire_vec8::is_forced(unsigned idx) const
{
      return test_force_mask(idx);
}

vvp_wire_real::vvp_wire_real()
: bit_(0.0), force_(0.0), hist_enabled_(false), hist_valid_(false),
  hist_time_(0), hist_prev_(0.0)
{
}

/* R11: snapshot the value the signal held when this time step began, the
   first time it changes within the step. The real twin of
   vvp_wire_vec4::hist_snapshot_. */
void vvp_wire_real::hist_snapshot_()
{
      if (!hist_enabled_) return;
      vvp_time64_t now = schedule_simtime();
      if (hist_valid_ && hist_time_ == now) return;
      hist_prev_ = bit_;
      hist_time_ = now;
      hist_valid_ = true;
}

/* The Preponed-region value: if the signal has changed during the current
   time step, the value it had when the step started; otherwise the current
   value. */
double vvp_wire_real::real_preponed_value() const
{
      if (hist_enabled_ && hist_valid_ && hist_time_ == schedule_simtime())
	    return hist_prev_;
      return real_value();
}

vvp_net_fil_t::prop_t vvp_wire_real::filter_real(double&bit)
{
      hist_snapshot_();
      bit_ = bit;
      return filter_mask_(bit, force_);
}

unsigned vvp_wire_real::filter_size() const
{
      assert(0);
      return 0;
}

void vvp_wire_real::force_fil_vec4(const vvp_vector4_t&, const vvp_vector2_t&)
{
      assert(0);
}

void vvp_wire_real::force_fil_vec8(const vvp_vector8_t&, const vvp_vector2_t&)
{
      assert(0);
}

void vvp_wire_real::force_fil_real(double val, const vvp_vector2_t&mask)
{
      force_mask(mask);
      if (mask.value(0))
	    force_ = val;

      run_vpi_callbacks();
}

void vvp_wire_real::release(vvp_net_ptr_t ptr, bool net_flag)
{
      vvp_vector2_t mask (vvp_vector2_t::FILL1, 1);
      if (net_flag) {
	      // Wires revert to their unforced value after release.
	    release_mask(mask);
	    ptr.ptr()->send_real(bit_, 0);
      } else {
	      // Variables keep the current value.
	    double res =  real_value();
	    release_mask(mask);
	    ptr.ptr()->fun->recv_real(ptr, res, 0);
      }
}

void vvp_wire_real::release_pv(vvp_net_ptr_t, unsigned, unsigned, bool)
{
      assert(0);
#if 0
	// A real is a single value. If for some reason this part release
	// can happen the following code should work correctly (requires
	// a base of 0 and a width of 1).
      vvp_vector2_t mask (vvp_vector2_t::FILL1, 1);
      assert(base == 0 && wid == 1);

      if (net_flag) {
	      // Wires revert to their unforced value after release.
	    release_mask(mask);
	    ptr.ptr()->send_real(bit_, 0);
      } else {
	      // Variables keep the current value.
	    double res =  real_value();
	    release_mask(mask);
	    ptr.ptr()->fun->recv_real(ptr, res, 0);
      }
#endif
}

unsigned vvp_wire_real::value_size() const
{
      assert(0);
      return 1;
}

vvp_bit4_t vvp_wire_real::value(unsigned) const
{
      assert(0);
      return BIT4_X;
}

vvp_scalar_t vvp_wire_real::scalar_value(unsigned) const
{
      assert(0);
      return vvp_scalar_t();
}

void vvp_wire_real::vec4_value(vvp_vector4_t&) const
{
      assert(0);
}

double vvp_wire_real::real_value() const
{
      if (test_force_mask(0))
	    return force_;
      else
	    return bit_;
}

#if 0
vvp_wire_string::vvp_wire_string()
{
}

unsigned vvp_wire_string::filter_size() const
{
      assert(0);
      return 0;
}

void vvp_wire_string::force_fil_vec4(const vvp_vector4_t&, const vvp_vector2_t&)
{
      assert(0);
}
void vvp_wire_string::force_fil_vec8(const vvp_vector8_t&, const vvp_vector2_t&)
{
      assert(0);
}
void vvp_wire_string::force_fil_real(double, const vvp_vector2_t&)
{
      assert(0);
}

void vvp_wire_string::release(vvp_net_ptr_t ptr, bool net_flag)
{
      assert(0);
}

void vvp_wire_string::release_pv(vvp_net_ptr_t, unsigned, unsigned, bool)
{
      assert(0);
}

unsigned vvp_wire_string::value_size() const
{
      assert(0);
      return 1;
}

vvp_bit4_t vvp_wire_string::value(unsigned) const
{
      assert(0);
      return BIT4_X;
}

vvp_scalar_t vvp_wire_string::scalar_value(unsigned) const
{
      assert(0);
      return vvp_scalar_t();
}

void vvp_wire_string::vec4_value(vvp_vector4_t&) const
{
      assert(0);
}

double vvp_wire_string::real_value() const
{
      assert(0);
      return 0.0;
}
#endif
