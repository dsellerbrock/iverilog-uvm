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
      inline vvp_object() { ref_cnt_ = 0; total_active_cnt_ += 1; register_live_ptr_(this); }
      virtual ~vvp_object() =0;

      virtual void shallow_copy(const vvp_object*that);
      virtual vvp_object* duplicate(void) const;

      static void cleanup(void);
      static bool pointer_is_live(const vvp_object*ptr);

    private:
      static void register_live_ptr_(const vvp_object*ptr);
      static void unregister_live_ptr_(const vvp_object*ptr);

      friend class vvp_object_t;
      int ref_cnt_;

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

      inline void shallow_copy(const vvp_object_t&that)
          { ref_->shallow_copy(that.ref_); }
      inline vvp_object_t duplicate(void) const
          { return vvp_object_t(ref_->duplicate()); }

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
