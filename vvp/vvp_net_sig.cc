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
      vvp_send_vec4(out_, val, 0);
}

void vvp_net_t::force_vec8(const vvp_vector8_t&val, const vvp_vector2_t&mask)
{
      assert(fil);
      fil->force_fil_vec8(val, mask);
      fun->force_flag(false);
      vvp_send_vec8(out_, val);
}

void vvp_net_t::force_real(double val, const vvp_vector2_t&mask)
{
      assert(fil);
      fil->force_fil_real(val, mask);
      fun->force_flag(false);
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
      context = recover_automatic_recv_context_(context, context_scope_, "recv-vec4-aa");
      if (!context)
            return;

      signal4_aa_slot*slot = signal4_aa_get_or_make_slot(context, context_idx_, size_, init_);
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
      const signal4_aa_slot*slot =
            signal4_aa_slot_from_raw(vthread_get_rd_context_item_scoped(context_idx_, context_scope_));
      if (!slot) {
            val = vvp_vector4_t(size_, BIT4_X);
            return;
      }

      val = slot->bits;
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
      const char*scope_name = context_scope_ ? vpi_get_str(vpiFullName, context_scope_) : 0;
      bool trace_this = load_str_trace_scope_match_(scope_name);
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
      signal_object_aa_slot*slot =
            signal_object_aa_slot_from_raw(vvp_get_context_item(context, context_idx));
      if (!slot) {
            slot = new signal_object_aa_slot;
            vvp_set_context_item(context, context_idx, slot);
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
      signal_object_aa_slot*slot =
            signal_object_aa_slot_from_raw(vthread_get_rd_context_item_scoped(context_idx_,
                                                                               context_scope_));
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
      vvp_context_t input_context = context;
      vvp_context_t recovered_context =
            recover_automatic_recv_context_(context, context_scope_, "recv-object-aa");
      context = recovered_context;
      if (recv_object_trace_scope_match_(context_scope_
                                         ? vpi_get_str(vpiFullName, context_scope_) : 0)) {
            const char*scope_name = context_scope_
                                  ? vpi_get_str(vpiFullName, context_scope_) : 0;
            fprintf(stderr,
                    "trace recv-object-aa scope=%s net=%p input_ctx=%p recovered_ctx=%p final_ctx=%p val_nil=%d val=%p\n",
                    scope_name ? scope_name : "<unknown>",
                    (void*)ptr.ptr(),
                    input_context, recovered_context, context,
                    bit.test_nil() ? 1 : 0,
                    bit.peek<vvp_object>());
      }
      if (!context) {
            return;
      }

      signal_object_aa_slot*slot = signal_object_aa_get_or_make_slot(context, context_idx_);
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
	    bits4_ = bit;
      } else {
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
	    bits4_ = bit4;
      } else {
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
: bit_(0.0), force_(0.0)
{
}

vvp_net_fil_t::prop_t vvp_wire_real::filter_real(double&bit)
{
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
