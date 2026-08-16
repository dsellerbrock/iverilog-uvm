#ifndef IVL_vvp_net_sig_H
#define IVL_vvp_net_sig_H
/*
 * Copyright (c) 2004-2026 Stephen Williams (steve@icarus.com)
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
# include  "vpi_user.h"
# include  "vvp_net.h"
# include  "vvp_object.h"
# include  <string>
# include  <cstddef>
# include  <cstdlib>
# include  <cstring>
# include  <new>
# include  <cassert>

class class_type;

#ifdef HAVE_IOSFWD
# include  <iosfwd>
#else
# include  <iostream>
#endif

class __vpiScope;

/* vvp_fun_signal
 * This node is the place holder in a vvp network for signals,
 * including nets of various sort. The output from a signal follows
 * the type of its port-0 input. If vvp_vector4_t values come in
 * through port-0, then vvp_vector4_t values are propagated. If
 * vvp_vector8_t values come in through port-0, then vvp_vector8_t
 * values are propagated. Thus, this node is slightly polymorphic.
 *
 * If the signal is a net (i.e. a wire or tri) then this node will
 * have an input that is the data source. The data source will connect
 * through port-0.
 *
 * If the signal is a reg, then there will be no netlist input, the
 * values will be written by behavioral statements. The %set and
 * %assign statements will write through port-0.
 *
 * In any case, behavioral code is able to read the value that this
 * node last propagated, by using the value() method. That is important
 * functionality of this node.
 *
 * Continuous assignments are made through port-1. When a value is
 * written here, continuous assign mode is activated, and input
 * through port-0 is ignored until continuous assign mode is turned
 * off again. Writing into this port can be done in behavioral code
 * using the %cassign/v instruction, or can be done by the network by
 * hooking the output of a vvp_net_t to this port.
 */


class vvp_fun_signal_base : public vvp_net_fun_t {

    public:
      vvp_fun_signal_base();

      void deassign();
      void deassign_pv(unsigned base, unsigned wid);

	// M12: VPI value-change callbacks on SystemVerilog variables.
	// String/class/darray/queue variables have no vvp_net_fil_t
	// filter node, so the functor itself carries the callback
	// list. Implemented in vpi_callback.cc.
      void add_vpi_callback(class value_callback*cb);
      void run_sv_vpi_callbacks();

    public:

	/* The %cassign/link instruction needs a place to write the
	   source node of the force, so that subsequent %cassign and
	   %deassign instructions can undo the link as needed. */
      class vvp_net_t*cassign_link;

    protected:
      bool continuous_assign_active_;
      vvp_vector2_t assign_mask_;

    protected:
	// This is true until at least one propagation happens.
      bool needs_init_;

    private:
      class value_callback*sv_vpi_callbacks_ = 0;
};

/*
 * Variables and wires can have their values accessed, so this base
 * class offers the unified concept of an accessible value.
 */
class vvp_signal_value {
    public:
      virtual ~vvp_signal_value() =0;
      virtual unsigned value_size() const =0;
      virtual vvp_bit4_t value(unsigned idx) const =0;
      virtual vvp_scalar_t scalar_value(unsigned idx) const =0;
      virtual void vec4_value(vvp_vector4_t&) const =0;
      virtual double real_value() const;

      virtual void get_signal_value(struct t_vpi_value*vp);
};

/*
 * This abstract class is a little more specific than the signal_base
 * class, in that it adds vector access methods.
 */
class vvp_fun_signal_vec : public vvp_fun_signal_base {
    public:
      virtual const vvp_vector4_t& vec4_unfiltered_value() const =0;
};

class automatic_signal_base : public vvp_signal_value, public vvp_net_fil_t {

    public:
      vvp_signal_value*as_signal_value() override { return this; }

	// Automatic variables cannot be forced or released. Provide
	// stubs that assert.
      virtual void release(vvp_net_ptr_t ptr, bool net_flag) override;
      virtual void release_pv(vvp_net_ptr_t ptr, unsigned base, unsigned wid, bool net_flag) override;

      virtual unsigned filter_size() const override;
      virtual void force_fil_vec4(const vvp_vector4_t&val, const vvp_vector2_t&mask) override;
      virtual void force_fil_vec8(const vvp_vector8_t&val, const vvp_vector2_t&mask) override;
      virtual void force_fil_real(double val, const vvp_vector2_t&mask) override;
      virtual void get_value(struct t_vpi_value*value) override;
};

/*
 * Statically allocated vvp_fun_signal4.
 */
class vvp_fun_signal4_sa : public vvp_fun_signal_vec {

    public:
      explicit vvp_fun_signal4_sa(unsigned wid, vvp_bit4_t init=BIT4_X);

      void recv_vec4(vvp_net_ptr_t port, const vvp_vector4_t&bit,
                     vvp_context_t) override;
      void recv_vec8(vvp_net_ptr_t port, const vvp_vector8_t&bit) override;

	// Part select variants of above
      void recv_vec4_pv(vvp_net_ptr_t port, const vvp_vector4_t&bit,
			unsigned base, unsigned vwid, vvp_context_t) override;
      void recv_vec8_pv(vvp_net_ptr_t port, const vvp_vector8_t&bit,
			unsigned base, unsigned vwid) override;

	// Get information about the vector value.
      const vvp_vector4_t& vec4_unfiltered_value() const override;

    private:
      vvp_vector4_t bits4_;
};

/*
 * Automatically allocated vvp_fun_signal4.
 */
class vvp_fun_signal4_aa : public vvp_fun_signal_vec, public automatic_signal_base, public automatic_hooks_s {

    public:
      explicit vvp_fun_signal4_aa(unsigned wid, vvp_bit4_t init=BIT4_X);
      ~vvp_fun_signal4_aa() override;

      void alloc_instance(vvp_context_t context) override;
      void reset_instance(vvp_context_t context) override;
#ifdef CHECK_WITH_VALGRIND
      void free_instance(vvp_context_t context) override;
#endif

      void recv_vec4(vvp_net_ptr_t port, const vvp_vector4_t&bit,
                     vvp_context_t context) override;

	// Part select variants of above
      void recv_vec4_pv(vvp_net_ptr_t port, const vvp_vector4_t&bit,
			unsigned base, unsigned vwid, vvp_context_t) override;

	// Get information about the vector value.
      unsigned   value_size() const override;
      vvp_bit4_t value(unsigned idx) const override;
      vvp_scalar_t scalar_value(unsigned idx) const override;
      void vec4_value(vvp_vector4_t&) const override;
      const vvp_vector4_t& vec4_unfiltered_value() const override;

    public: // These objects are only permallocated.
      static void* operator new(std::size_t size) { return vvp_net_fun_t::heap_.alloc(size); }
      static void operator delete(void*obj);

	    private:
	      __vpiScope*context_scope_;
	      unsigned context_idx_;
	      unsigned size_;
	      vvp_bit4_t init_;
};

class vvp_fun_signal_real : public vvp_fun_signal_base {

    public:
      explicit vvp_fun_signal_real() {};

	// Get information about the vector value.
      virtual double real_unfiltered_value() const = 0;
};

/*
 * Statically allocated vvp_fun_signal_real.
 */
class vvp_fun_signal_real_sa : public vvp_fun_signal_real {

    public:
      explicit vvp_fun_signal_real_sa();

      void recv_real(vvp_net_ptr_t port, double bit,
                     vvp_context_t) override;

	// Get information about the vector value.
      double real_unfiltered_value() const override;

    private:
      double bits_;
};

/*
 * Automatically allocated vvp_fun_signal_real.
 */
class vvp_fun_signal_real_aa : public vvp_fun_signal_real, public automatic_signal_base, public automatic_hooks_s {

    public:
      explicit vvp_fun_signal_real_aa();
      ~vvp_fun_signal_real_aa() override;

      void alloc_instance(vvp_context_t context) override;
      void reset_instance(vvp_context_t context) override;
#ifdef CHECK_WITH_VALGRIND
      void free_instance(vvp_context_t context) override;
#endif

      void recv_real(vvp_net_ptr_t port, double bit,
                     vvp_context_t context) override;

	// Get information about the vector value.
      double real_unfiltered_value() const override;

	// Get information about the vector value.
      unsigned   value_size() const override;
      vvp_bit4_t value(unsigned idx) const override;
      vvp_scalar_t scalar_value(unsigned idx) const override;
      void vec4_value(vvp_vector4_t&) const override;
      double real_value() const override;
      void get_signal_value(struct t_vpi_value*vp) override;

    public: // These objects are only permallocated.
      static void* operator new(std::size_t size);
      static void operator delete(void*obj);

    private:
      __vpiScope*context_scope_;
      unsigned context_idx_;
};


class vvp_fun_signal_string : public vvp_fun_signal_base {

    public:
      explicit vvp_fun_signal_string() {};

      virtual const std::string& get_string() const =0;
};

/*
 * Statically allocated vvp_fun_signal_string.
 */
class vvp_fun_signal_string_sa : public vvp_fun_signal_string {

    public:
      explicit vvp_fun_signal_string_sa();

      void recv_string(vvp_net_ptr_t port, const std::string&bit,
		       vvp_context_t context) override;

      const std::string& get_string() const override;

    private:
      std::string value_;
};

/*
 * Automatically allocated vvp_fun_signal_real.
 */
class vvp_fun_signal_string_aa : public vvp_fun_signal_string, public automatic_signal_base, public automatic_hooks_s {

    public:
      explicit vvp_fun_signal_string_aa();
      ~vvp_fun_signal_string_aa() override;

      void alloc_instance(vvp_context_t context) override;
      void reset_instance(vvp_context_t context) override;
#ifdef CHECK_WITH_VALGRIND
      void free_instance(vvp_context_t context) override;
#endif
      void recv_string(vvp_net_ptr_t port, const std::string&bit,
		       vvp_context_t context) override;

	// Get information about the vector value.
      unsigned   value_size() const override;
      vvp_bit4_t value(unsigned idx) const override;
      vvp_scalar_t scalar_value(unsigned idx) const override;
      void vec4_value(vvp_vector4_t&) const override;
      double real_value() const override;
      const std::string& get_string() const override;
      void get_signal_value(struct t_vpi_value*vp) override;

    public: // These objects are only permallocated.
      static void* operator new(std::size_t size);
      static void operator delete(void*obj);

    private:
      __vpiScope*context_scope_;
      unsigned context_idx_;
};

class vvp_fun_signal_object : public vvp_fun_signal_base {

    public:
      enum init_obj_kind_t {
            INIT_OBJ_NONE = 0,
            INIT_OBJ_QUEUE_REAL,
            INIT_OBJ_QUEUE_STRING,
            INIT_OBJ_QUEUE_VEC4,
            INIT_OBJ_QUEUE_OBJECT,
            INIT_OBJ_ASSOC_REAL,
            INIT_OBJ_ASSOC_STRING,
            INIT_OBJ_ASSOC_VEC4,
            INIT_OBJ_ASSOC_OBJECT
      };

      explicit vvp_fun_signal_object(unsigned size) { size_ = size; declared_type_ = 0; };
      unsigned size() const { return size_; }
      class_type* declared_type() const { return declared_type_; }
      class_type*& declared_type_ref() { return declared_type_; }
      void default_object_kind(init_obj_kind_t kind) { default_object_kind_ = kind; }
      init_obj_kind_t default_object_kind() const { return default_object_kind_; }

      virtual vvp_object_t get_object() const =0;
      virtual vvp_object_t peek_object() const =0;
      virtual vvp_net_t* get_root_net() const =0;
      virtual vvp_object_t get_root_object() const =0;
      virtual void set_root_provenance(vvp_net_t*root_net, const vvp_object_t&root_obj,
                                       vvp_context_t context) =0;
    protected:
      vvp_object_t make_default_object() const;
    private:
      unsigned size_;
      class_type* declared_type_;
      init_obj_kind_t default_object_kind_ = INIT_OBJ_NONE;
};

/*
 * Statically allocated vvp_fun_signal_string.
 */
class vvp_fun_signal_object_sa : public vvp_fun_signal_object {

    public:
      explicit vvp_fun_signal_object_sa(unsigned size);

      void recv_object(vvp_net_ptr_t port, vvp_object_t bit,
		    vvp_context_t context) override;

      vvp_object_t get_object() const override;
      vvp_object_t peek_object() const override;
      vvp_net_t* get_root_net() const override;
      vvp_object_t get_root_object() const override;
      void set_root_provenance(vvp_net_t*root_net, const vvp_object_t&root_obj,
                               vvp_context_t context) override;

      class_type* init_defn_;

    private:
      mutable vvp_object_t value_;
      mutable uint64_t value_epoch_;
      mutable vvp_net_t* root_net_;
      mutable vvp_object_t root_obj_;
      mutable vvp_net_t* attached_net_;
};

/*
 * Automatically allocated vvp_fun_signal_real.
 */
class vvp_fun_signal_object_aa : public vvp_fun_signal_object, public automatic_signal_base, public automatic_hooks_s {

    public:
      explicit vvp_fun_signal_object_aa(unsigned size);
      ~vvp_fun_signal_object_aa() override;

      void alloc_instance(vvp_context_t context) override;
      void reset_instance(vvp_context_t context) override;
#ifdef CHECK_WITH_VALGRIND
      void free_instance(vvp_context_t context) override;
#endif

      void recv_object(vvp_net_ptr_t port, vvp_object_t bit,
		    vvp_context_t context) override;

	// Get information about the vector value.
      unsigned   value_size() const override;
      vvp_bit4_t value(unsigned idx) const override;
      vvp_scalar_t scalar_value(unsigned idx) const override;
      void vec4_value(vvp_vector4_t&) const override;
	//double real_value() const;
	//void get_signal_value(struct t_vpi_value*vp);

      vvp_object_t get_object() const override;
      vvp_object_t peek_object() const override;
      vvp_net_t* get_root_net() const override;
      vvp_object_t get_root_object() const override;
      void set_root_provenance(vvp_net_t*root_net, const vvp_object_t&root_obj,
                               vvp_context_t context) override;
      void clear_current_alias(vvp_context_t context);

      class_type* init_defn_;

    public: // These objects are only permallocated.
      static void* operator new(std::size_t size);
      static void operator delete(void*obj);

	    private:
	      __vpiScope*context_scope_;
	      unsigned context_idx_;
            mutable vvp_net_t* attached_net_;
};

/*
 * A `ref' subroutine formal (IEEE 1800-2017 13.5.2).
 *
 * A ref formal is not storage. It is another name for the caller's
 * variable: a write through it is visible to the caller at once rather
 * than at return, and a read through it sees whatever the caller has
 * put there since the call. Copy-in/copy-out cannot express either --
 * it is observationally equivalent only for a subroutine that neither
 * consumes time nor shares the variable with anything else.
 *
 * So this functor holds no value at all. Each frame's context slot
 * holds the net it was bound to by %ref/bind, plus the caller's context
 * (a caller's own automatic variable resolves against the caller's
 * frame, not the callee's), and every access is forwarded there.
 *
 * The delegate is reached through the same vvp_signal_value and
 * vvp_net_fun_t interfaces the opcodes already use, so %load, %store
 * and every part/word variant work unchanged.
 *
 * A class-handle formal additionally needs the vvp_fun_signal_object
 * interface: %load/obj, %test_nul, %prop/obj and friends all reach a
 * signal through dynamic_cast<vvp_fun_signal_object*>, not through
 * vvp_signal_value, so this class also derives from vvp_fun_signal_object
 * (declared above) and forwards its five accessors to whatever the bound
 * target's own object functor is. This functor keeps no object-graph
 * state of its own (no alias bookkeeping, no root provenance) -- every
 * one of those calls is delegated, so the real functor at the far end of
 * the binding is the sole owner of that state, exactly as if the
 * caller's variable had been read or written directly.
 */
struct __vpiArray;

class vvp_ref_signal_aa : public vvp_fun_signal_object,
                          public automatic_signal_base,
                          public automatic_hooks_s {

    public:
      explicit vvp_ref_signal_aa(unsigned wid);
      ~vvp_ref_signal_aa() override;

      void alloc_instance(vvp_context_t context) override;
      void reset_instance(vvp_context_t context) override;
#ifdef CHECK_WITH_VALGRIND
      void free_instance(vvp_context_t context) override;
#endif

	// Point this frame's formal at a variable. Called by %ref/bind
	// between the callee's %alloc and its call, so the write context
	// is already the callee's frame while the read context is still
	// the caller's. in_frame says which of the two the target lives
	// in: an ordinary actual is the caller's, but an actual that
	// could not be named is copied into a companion word in the
	// callee's own frame and the formal is bound to that.
      void bind(vvp_net_t*target, bool in_frame);

	// R25: bind to storage INSIDE a variable, so an actual that is
	// not itself a whole variable is still a true reference
	// (IEEE 1800-2017 13.5.2) rather than a copy pair whose copy-out
	// at return loses writes from detached branches.
	//
	// bind_prop: a class property. The OBJECT is captured (a strong
	// handle), so the reference survives the caller's handle variable
	// being reassigned -- the ref names the property's storage, which
	// lives in the object.
	// bind_elem: an element of a dynamic array or queue. A stable
	// element cell follows that live element through queue index shifts.
	// Removing the element or replacing the whole container detaches the
	// cell with its last value, as required by 13.5.2; an initially
	// out-of-range index reads the type default and drops writes.
	// bind_word: a word of a fixed (static) unpacked array.
      void bind_prop(const vvp_object_t&obj, unsigned pid);
      void bind_elem(const vvp_object_t&container, int64_t index);
      void bind_word(struct __vpiArray*arr, unsigned index);

	// vvp_net_fun_t: forward everything to the bound net.
      void recv_vec4(vvp_net_ptr_t port, const vvp_vector4_t&bit,
                     vvp_context_t context) override;
      void recv_vec4_pv(vvp_net_ptr_t port, const vvp_vector4_t&bit,
			unsigned base, unsigned vwid, vvp_context_t) override;
      void recv_real(vvp_net_ptr_t port, double bit, vvp_context_t) override;
      void recv_string(vvp_net_ptr_t port, const std::string&bit,
                       vvp_context_t) override;
      void recv_object(vvp_net_ptr_t port, vvp_object_t bit,
                       vvp_context_t) override;

	// vvp_signal_value: read through to the bound net.
      unsigned   value_size() const override;
      vvp_bit4_t value(unsigned idx) const override;
      vvp_scalar_t scalar_value(unsigned idx) const override;
      void vec4_value(vvp_vector4_t&) const override;
      double real_value() const override;
      void get_signal_value(struct t_vpi_value*vp) override;
      const std::string& get_string() const;

	// vvp_fun_signal_object: forward to the bound target's own object
	// functor. A class-handle formal is a single machine word, so
	// unlike vvp_fun_signal_object_aa there is no per-frame value
	// slot, alias bookkeeping or root provenance here to maintain --
	// the delegate at the far end of the binding already has all of
	// that, and owns it, exactly as it would for a direct access.
      vvp_object_t get_object() const override;
      vvp_object_t peek_object() const override;
      vvp_net_t* get_root_net() const override;
      vvp_object_t get_root_object() const override;
      void set_root_provenance(vvp_net_t*root_net, const vvp_object_t&root_obj,
                               vvp_context_t context) override;

	// The net this frame is bound to, or nil if %ref/bind never ran
	// (an unbound formal is a compiler defect, not a user error).
      vvp_net_t*target() const;

	// Move a binding between frames. A virtual method call allocates
	// the OVERRIDE's frame and copies the base formals into it; a
	// bound formal has no value to copy, so its binding is what has
	// to travel or the override writes nowhere. The binding is a
	// tagged value (see ref_aa_slot in vvp_net_sig.cc): a whole
	// variable, a class property, a container element, or an array
	// word all travel intact.
      struct binding_t {
            int kind;
            vvp_net_t*target;
            vvp_context_t caller_ctx;
            vvp_object_t obj;
            unsigned prop_id;
            int64_t index;
            struct __vpiArray*arr;
            binding_t() : kind(0), target(0), caller_ctx(0), prop_id(0),
                          index(0), arr(0) { }
      };
      bool read_binding(binding_t&out) const;
      void write_binding(vvp_context_t frame, const binding_t&in);

    public: // These objects are only permallocated.
      static void* operator new(std::size_t size) { return vvp_net_fun_t::heap_.alloc(size); }
      static void operator delete(void*obj);

    private:
      __vpiScope*context_scope_;
      unsigned context_idx_;
      unsigned size_;
      mutable std::string string_cache_;
};


/* vvp_wire
 * The vvp_wire is different from vvp_variable objects in that it
 * exists only as a filter. The vvp_wire class tree is for
 * implementing Verilog wires/nets (as opposed to regs/variables).
 *
 *   vvp_vpi_callback
 *          |
 *          |
 *    vvp_net_fil_t   vvp_signal_value
 *          |               |
 *           \             /
 *            \           /
 *             \         /
 *            vvp_wire_base
 */

class vvp_wire_base  : public vvp_net_fil_t, public vvp_signal_value {

    public:
      vvp_wire_base();
      ~vvp_wire_base() override;
      vvp_signal_value*as_signal_value() override { return this; }

        // Support for $countdrivers
      virtual vvp_bit4_t driven_value(unsigned idx) const;
      virtual bool is_forced(unsigned idx) const;
};

class vvp_wire_vec4 : public vvp_wire_base {

    public:
      vvp_wire_vec4(unsigned wid, vvp_bit4_t init);

	// The main filter behavior for this class. These methods take
	// the value that the node is driven to, and applies the force
	// filters. In wires, this also saves the driven value, so
	// that when a force is released, we can revert to the driven value.
      prop_t filter_vec4(const vvp_vector4_t&bit, vvp_vector4_t&rep,
			 unsigned base, unsigned vwid) override;
      prop_t filter_vec8(const vvp_vector8_t&val, vvp_vector8_t&rep,
			 unsigned base, unsigned vwid) override;

	// Abstract methods from vvp_vpi_callback
      void get_value(struct t_vpi_value*value) override;
	// Abstract methods from vvp_net_fit_t
      unsigned filter_size() const override;
      void force_fil_vec4(const vvp_vector4_t&val, const vvp_vector2_t&mask) override;
      void force_fil_vec8(const vvp_vector8_t&val, const vvp_vector2_t&mask) override;
      void force_fil_real(double val, const vvp_vector2_t&mask) override;
      void release(vvp_net_ptr_t ptr, bool net_flag) override;
      void release_pv(vvp_net_ptr_t ptr, unsigned base, unsigned wid, bool net_flag) override;

	// Implementation of vvp_signal_value methods
      unsigned value_size() const override;
      vvp_bit4_t value(unsigned idx) const override;
      vvp_scalar_t scalar_value(unsigned idx) const override;
      void vec4_value(vvp_vector4_t&) const override;

        // Support for $countdrivers
      vvp_bit4_t driven_value(unsigned idx) const override;
      bool is_forced(unsigned idx) const override;

	// Clocking-block input sampling (IEEE 1800-2017 14.13): a
	// 1-deep driven-value history so `%load/preponed` can return
	// the value the signal held when the current time step
	// started (the Preponed-region value, i.e. the default #1step
	// sample). Off unless a `%hist/on` enables it, so unrelated
	// signals pay nothing. Note: tracks the DRIVEN value; a signal
	// under an active force samples its driven (pre-force) value.
      void enable_sample_hist() { hist_enabled_ = true; }
      void vec4_preponed_value(vvp_vector4_t&val) const;

    private:
      vvp_bit4_t filtered_value_(unsigned idx) const;
      void hist_snapshot_();

    private:
      bool needs_init_;
      vvp_vector4_t bits4_; // The tracked driven value
      vvp_vector4_t force4_; // the value being forced

      bool hist_enabled_;
      bool hist_valid_;
      vvp_time64_t hist_time_;
      vvp_vector4_t hist_prev_; // bits4_ as of the end of the time
				// step BEFORE hist_time_
};

class vvp_wire_vec8 : public vvp_wire_base {

    public:
      explicit vvp_wire_vec8(unsigned wid);

	// The main filter behavior for this class
      prop_t filter_vec4(const vvp_vector4_t&bit, vvp_vector4_t&rep,
			 unsigned base, unsigned vwid) override;
      prop_t filter_vec8(const vvp_vector8_t&val, vvp_vector8_t&rep,
			 unsigned base, unsigned vwid) override;

	// island ports use this method to filter arbitrary values
	// through the force filter.
      prop_t filter_input_vec8(const vvp_vector8_t&val, vvp_vector8_t&rep) const;


	// Abstract methods from vvp_vpi_callback
      void get_value(struct t_vpi_value*value) override;
	// Abstract methods from vvp_net_fit_t
      unsigned filter_size() const override;
      void force_fil_vec4(const vvp_vector4_t&val, const vvp_vector2_t&mask) override;
      void force_fil_vec8(const vvp_vector8_t&val, const vvp_vector2_t&mask) override;
      void force_fil_real(double val, const vvp_vector2_t&mask) override;
      void release(vvp_net_ptr_t ptr, bool net_flag) override;
      void release_pv(vvp_net_ptr_t ptr, unsigned base, unsigned wid, bool net_flag) override;

	// Implementation of vvp_signal_value methods
      unsigned value_size() const override;
      vvp_bit4_t value(unsigned idx) const override;
      vvp_scalar_t scalar_value(unsigned idx) const override;
      void vec4_value(vvp_vector4_t&) const override;
	// This is new to vvp_wire_vec8
      vvp_vector8_t vec8_value() const;

        // Support for $countdrivers
      vvp_bit4_t driven_value(unsigned idx) const override;
      bool is_forced(unsigned idx) const override;

    private:
      vvp_scalar_t filtered_value_(unsigned idx) const;

    private:
      bool needs_init_;
      bool width_error_reported_;
      vvp_vector8_t bits8_;
      vvp_vector8_t force8_; // the value being forced
};

class vvp_wire_real : public vvp_wire_base {

    public:
      explicit vvp_wire_real(void);

	// The main filter behavior for this class
      prop_t filter_real(double&bit) override;

	// Abstract methods from vvp_vpi_callback
      void get_value(struct t_vpi_value*value) override;
	// Abstract methods from vvp_net_fit_t
      unsigned filter_size() const override;
      void force_fil_vec4(const vvp_vector4_t&val, const vvp_vector2_t&mask) override;
      void force_fil_vec8(const vvp_vector8_t&val, const vvp_vector2_t&mask) override;
      void force_fil_real(double val, const vvp_vector2_t&mask) override;
      void release(vvp_net_ptr_t ptr, bool net_flag) override;
      void release_pv(vvp_net_ptr_t ptr, unsigned base, unsigned wid, bool net_flag) override;

	// Implementation of vvp_signal_value methods
      unsigned value_size() const override;
      vvp_bit4_t value(unsigned idx) const override;
      vvp_scalar_t scalar_value(unsigned idx) const override;
      void vec4_value(vvp_vector4_t&) const override;
      double real_value() const override;

      void get_signal_value(struct t_vpi_value*vp) override;

	// R11: 1-deep driven-value history, the real-valued twin of the
	// vec4 one. Preponed reads of a real assertion operand need it for
	// the same reason vectors do -- see vvp_wire_vec4::hist_snapshot_.
      void enable_sample_hist() { hist_enabled_ = true; }
      double real_preponed_value() const;

    private:
      void hist_snapshot_();

    private:
      double bit_;
      double force_;
      bool hist_enabled_;
      bool hist_valid_;
      vvp_time64_t hist_time_;
      double hist_prev_;
};

#if 0
class vvp_wire_string : public vvp_wire_base {

    public:
      explicit vvp_wire_string(void);

	// Abstract methods from vvp_vpi_callback
      void get_value(struct t_vpi_value*value);
	// Abstract methods from vvp_net_fil_t
      unsigned filter_size() const;
      void force_fil_vec4(const vvp_vector4_t&val, const vvp_vector2_t&mask);
      void force_fil_vec8(const vvp_vector8_t&val, const vvp_vector2_t&mask);
      void force_fil_real(double val, const vvp_vector2_t&mask);
      void release(vvp_net_ptr_t ptr, bool net_flag);
      void release_pv(vvp_net_ptr_t ptr, unsigned base, unsigned wid, bool net_flag);

	// Implementation of vvp_signal_value methods
      unsigned value_size() const;
      vvp_bit4_t value(unsigned idx) const;
      vvp_scalar_t scalar_value(unsigned idx) const;
      void vec4_value(vvp_vector4_t&) const;
      double real_value() const;

      void get_signal_value(struct t_vpi_value*vp);

    private:
      std::string value_;
};
#endif

#endif /* IVL_vvp_net_sig_H */
