#ifndef IVL_vvp_object_H
#define IVL_vvp_object_H
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

# include  <stdlib.h>
# include  <stdint.h>
# include  <limits.h>
# include  <memory>
class vvp_net_t;
struct vthread_s;
typedef struct vthread_s* vthread_t;

/*
 * Runtime layout of the variable-size container layers in a declaration.
 *
 * Queue type matching deliberately ignores the queue bound, but every write
 * uses the destination queue's declared bound. A selected physical value can
 * therefore carry a different layout than the expression type used to reach
 * it. Keep the complete Q/D/A chain on the live destination object and hand
 * the immutable tail to each newly-created child container.
 *
 * A Q layer with queue_bound_known=true and queue_max_size=0 is explicitly
 * unbounded. A Q layer with queue_bound_known=false comes only from a legacy
 * VVP image that supplied no declaration metadata and must use an opcode's
 * static fallback.
 */
enum vvp_container_layout_kind_t {
      VVP_CONTAINER_QUEUE,
      VVP_CONTAINER_DARRAY,
      VVP_CONTAINER_ASSOC
};

struct vvp_container_layout_s;
typedef std::shared_ptr<const vvp_container_layout_s>
      vvp_container_layout_t;

struct vvp_container_layout_s {
      vvp_container_layout_s(vvp_container_layout_kind_t kind,
                             bool bound_known, uint64_t max_size,
                             const vvp_container_layout_t&child)
      : kind(kind), queue_bound_known(bound_known),
        queue_max_size(max_size), element(child) { }

      vvp_container_layout_kind_t kind;
      bool queue_bound_known;
      uint64_t queue_max_size;
      vvp_container_layout_t element;
};

extern vvp_container_layout_t vvp_make_container_layout(
      vvp_container_layout_kind_t kind, bool queue_bound_known,
      uint64_t queue_max_size, const vvp_container_layout_t&element);

/* Parse the suffix of a queue/darray/associative type record. New images use
 * !Q0,D,A,Q3 (the first layer must match expected_outer); legacy @N/#N
 * spellings remain accepted. base_length receives the prefix before the
 * suffix so callers can normalize their element-kind record. */
extern bool vvp_parse_container_layout_type(
      const char*text, vvp_container_layout_kind_t expected_outer,
      vvp_container_layout_t&layout, size_t&base_length);

inline bool vvp_object_ptr_is_poisoned(const class vvp_object*ptr)
{
      uintptr_t u = reinterpret_cast<uintptr_t>(ptr);
      if (u == 0 || u < 4096)
	    return u != 0;

      if (u == UINT64_C(0xbebebebebebebebe)
          || u == UINT64_C(0xcdcdcdcdcdcdcdcd)
          || u == UINT64_C(0xfefefefefefefefe)
          || u == UINT64_C(0xdddddddddddddddd))
	    return true;

      uintptr_t lo = u & UINT64_C(0xffffffff);
      if (lo == UINT64_C(0xbebebebe)
          || lo == UINT64_C(0xcdcdcdcd)
          || lo == UINT64_C(0xfefefefe)
          || lo == UINT64_C(0xdddddddd))
	    return true;

      return false;
}

/*
 * A vvp_object is a garbage collected object such as a darray or
 * class object. The vvp_object class is a virtual base class and not
 * generally used directly. Instead, use the vvp_object_t object as a
 * smart pointer. This makes garbage collection automatic.
 */
class vvp_object {
    public:
      inline vvp_object()
      {
            ref_cnt_ = 0;
            mutation_epoch_ = 0;
            total_active_cnt_ += 1;
            register_live_ptr_(this);
      }
      virtual ~vvp_object() =0;

      virtual void shallow_copy(const vvp_object*that);
      virtual vvp_object* duplicate(void) const;

       /* Declaration layout is not passive value metadata. Named signals and
	 * class properties install their immutable destination layout after a
	 * value copy; temporary duplicates may share this immutable chain. */
      void set_declared_container_layout(const vvp_container_layout_t&value);
      const vvp_container_layout_t&declared_container_layout() const
	{ return declared_container_layout_; }
      vvp_container_layout_t declared_element_container_layout() const
	{ return declared_container_layout_
	       ? declared_container_layout_->element : vvp_container_layout_t(); }
      uint64_t declared_queue_max_size() const
	{ return declared_queue_bound_known()
	       ? declared_container_layout_->queue_max_size : 0; }
      bool declared_queue_bound_known() const
	{ return declared_container_layout_
	       && declared_container_layout_->kind == VVP_CONTAINER_QUEUE
	       && declared_container_layout_->queue_bound_known; }
      void reset_declared_queue_layout_metadata()
	{ declared_container_layout_.reset(); }
      void copy_declared_queue_layout_metadata_to(vvp_object*that) const
	{ that->set_declared_container_layout(declared_container_layout_); }

      static void cleanup(void);
      static bool pointer_is_live(const vvp_object*ptr);
      inline uint64_t mutation_epoch() const { return mutation_epoch_; }
      void touch(unsigned property = UINT_MAX, unsigned word = UINT_MAX,
                 unsigned bit = UINT_MAX);
      void add_mutation_waiter(vthread_t thread,
                               unsigned property = UINT_MAX,
                               unsigned word = UINT_MAX,
                               unsigned bit = UINT_MAX,
                               bool active = true);
      static bool cancel_mutation_waiter(vthread_t thread);
      void register_signal_alias(vvp_net_t*net, void*context);
      void unregister_signal_alias(vvp_net_t*net, void*context);
      void notify_signal_aliases() const;
      void notify_alias_mutation();

    private:
      static void register_live_ptr_(const vvp_object*ptr);
      static void unregister_live_ptr_(const vvp_object*ptr);

      friend class vvp_object_t;
      int ref_cnt_;
      uint64_t mutation_epoch_;
      vvp_container_layout_t declared_container_layout_;

    protected:
       /* A queue applies its own declared maximum before descendants are
	* rebound. Keeping this virtual here avoids teaching the common object
	* layer about darray subclasses while making whole-value assignment trim
	* every populated queue in a recursive Q/D/A layout. */
      virtual void apply_declared_container_layout_own(
	    const vvp_container_layout_t&layout);

       /* Object-valued containers override this to install ELEMENT_LAYOUT on
	 * every already-populated child. The layout chain is finite, so the
	 * recursive setter also repairs descendants copied from a differently
	 * bounded source without needing target-type operands on every load. */
      virtual void rebind_declared_element_container_layout(
	    const vvp_container_layout_t&element_layout);

      static int total_active_cnt_;
};

class vvp_object_t {
    public:
      inline vvp_object_t() : ref_(0) { }
      vvp_object_t(const vvp_object_t&that);
      explicit vvp_object_t(class vvp_object*that);
      ~vvp_object_t();

      vvp_object_t& operator = (const vvp_object_t&that);
      vvp_object_t& operator = (class vvp_object*that);

      void reset(vvp_object*tgt = 0);

      bool test_nil() const { return ref_ == 0; }
      inline bool operator == (const vvp_object_t&that) const
          { return ref_ == that.ref_; }
      inline bool operator != (const vvp_object_t&that) const
          { return ref_ != that.ref_; }
      inline uint64_t mutation_epoch() const
          { return ref_ ? ref_->mutation_epoch() : 0; }
      inline void touch(unsigned property = UINT_MAX,
                        unsigned word = UINT_MAX,
                        unsigned bit = UINT_MAX) const
          { if (ref_) ref_->touch(property, word, bit); }
      inline void register_signal_alias(vvp_net_t*net, void*context) const
          { if (ref_) ref_->register_signal_alias(net, context); }
      inline void unregister_signal_alias(vvp_net_t*net, void*context) const
          { if (ref_) ref_->unregister_signal_alias(net, context); }
      inline void notify_signal_aliases() const
          { if (ref_) ref_->notify_signal_aliases(); }
      inline void notify_alias_mutation() const
          { if (ref_) ref_->notify_alias_mutation(); }

      inline void shallow_copy(const vvp_object_t&that)
          { ref_->shallow_copy(that.ref_); }
      inline vvp_object_t duplicate(void) const
          { return vvp_object_t(ref_->duplicate()); }

	/* Value-copy policy for one CONTAINER ELEMENT (IEEE 1800-2017
	   7.5/7.9/7.10): containers (darrays, queues, assoc arrays) and
	   struct-typed objects copy BY VALUE; class objects copy as
	   handles; nil stays nil. Implemented in vvp_darray.cc. */
      vvp_object_t value_copy_element(void) const;

      template <class T> T*peek(void) const;

    private:
      class vvp_object*ref_;
};

inline vvp_object_t::vvp_object_t(const vvp_object_t&that)
{
      ref_ = that.ref_;
      if (ref_ && (vvp_object_ptr_is_poisoned(ref_) || !vvp_object::pointer_is_live(ref_)))
	    ref_ = 0;
      if (ref_)
            ref_->ref_cnt_ += 1;
}

inline vvp_object_t::vvp_object_t(class vvp_object*tgt)
{
      if (tgt && (vvp_object_ptr_is_poisoned(tgt) || !vvp_object::pointer_is_live(tgt)))
	    ref_ = 0;
      else {
	    ref_ = tgt;
            if (ref_)
                  ref_->ref_cnt_ += 1;
      }
}

inline vvp_object_t::~vvp_object_t()
{
      reset(0);
}

/*
 * This is the workhorse of the vvp_object_t class. It manages the
 * pointer to the referenced object.
 */
inline void vvp_object_t::reset(class vvp_object*tgt)
{
      if (tgt && (vvp_object_ptr_is_poisoned(tgt) || !vvp_object::pointer_is_live(tgt)))
	    tgt = 0;

      if (tgt)
            tgt->ref_cnt_ += 1;

      vvp_object*old = ref_;
      ref_ = tgt;
      if (old) {
            old->ref_cnt_ -= 1;
            if (old->ref_cnt_ <= 0)
                  delete old;
      }
}

inline vvp_object_t& vvp_object_t::operator = (const vvp_object_t&that)
{
      if (this == &that) return *this;
      reset(that.ref_);
      return *this;
}

inline vvp_object_t& vvp_object_t::operator = (class vvp_object*that)
{
      reset(that);
      return *this;
}

/*
 * This peeks at the actual pointer value in the form of a derived
 * class. It uses dynamic_cast<>() to convert the pointer to the
 * desired type.
 *
 * NOTE: The vvp_object_t object retains ownership of the pointer!
 */
template <class T> inline T*vvp_object_t::peek(void) const
{
      if (ref_ == 0 || vvp_object_ptr_is_poisoned(ref_)
          || !vvp_object::pointer_is_live(ref_))
	    return 0;
      return dynamic_cast<T*> (ref_);
}

#endif /* IVL_vvp_object_H */
