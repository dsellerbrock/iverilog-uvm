#ifndef IVL_vvp_darray_H
#define IVL_vvp_darray_H
/*
 * Copyright (c) 2012-2025 Stephen Williams (steve@icarus.com)
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
# include  <deque>
# include  <set>
# include  <string>
# include  <vector>

class vvp_darray;

/* Return true for the compact element spellings accepted by destination-
 * typed queue/dynamic-array conversion opcodes. The VVP loader and runtime
 * share this check so malformed images cannot drift between the two paths. */
extern bool vvp_container_element_encoding_is_valid(const char*text);

/* Validate the complete compact encoding used by %stream/to/dar and
 * %stream/to/queue. Queue spellings may carry a 64-bit maximum after ':'. */
extern bool vvp_stream_container_encoding_is_valid(const char*text,
						    bool as_queue);

/*
 * A stable reference to one element of a variable-size array.
 *
 * IEEE 1800-2017 13.5.2 requires an element passed by ref to continue to
 * exist until the called subroutine completes, even if the element is later
 * removed from its container. While the element is live, reads and writes
 * must address the live element. Once it is removed, this object owns the
 * last value and changes remain visible only through the outdated ref.
 */
class vvp_darray_element_ref : public vvp_object {
    public:
      enum kind_t { ELEM_VEC4, ELEM_REAL, ELEM_STRING, ELEM_OBJECT };

      vvp_darray_element_ref(vvp_darray*owner, size_t index,
                             kind_t kind, unsigned vec4_width);
      ~vvp_darray_element_ref() override;

      void set_value(const vvp_vector4_t&value, bool notify = true);
      void get_value(vvp_vector4_t&value);
      void set_value(double value, bool notify = true);
      void get_value(double&value);
      void set_value(const std::string&value, bool notify = true);
      void get_value(std::string&value);
      void set_value(const vvp_object_t&value, bool notify = true);
      void get_value(vvp_object_t&value);
      vvp_object_t attached_owner() const;

      void shallow_copy(const vvp_object*that) override;
      vvp_object* duplicate(void) const override;

    private:
      friend class vvp_darray;

      void detach();
      void shift_up(size_t at);
      void shift_down(size_t after);
      bool is_attached_to(const vvp_darray*owner) const
      { return owner_ == owner; }

      vvp_darray*owner_;
      size_t index_;
      kind_t kind_;
      bool valid_;
      vvp_vector4_t vec4_value_;
      double real_value_;
      std::string string_value_;
      vvp_object_t object_value_;
};

class vvp_darray : public vvp_object {

    public:
      inline vvp_darray() { }
      virtual ~vvp_darray() override;

      virtual size_t get_size(void) const =0;

	// Remove every element while retaining the container object itself.
	// Queue and dynamic-array delete() share this operation so references to
	// a selected container continue to observe the mutation.
      virtual void clear(void) =0;

	// Width accepted by the vec4 get/set interface for integral storage.
	// Zero identifies a non-integral element representation.
      virtual unsigned vec4_word_width(void) const { return 0; }

      virtual void set_word(unsigned adr, const vvp_vector4_t&value);
      virtual void get_word(unsigned adr, vvp_vector4_t&value);

      virtual void set_word(unsigned adr, double value);
      virtual void get_word(unsigned adr, double&value);

      virtual void set_word(unsigned adr, const std::string&value);
      virtual void get_word(unsigned adr, std::string&value);

      virtual void set_word(unsigned adr, const vvp_object_t&value);
      virtual void get_word(unsigned adr, vvp_object_t&value);

      virtual vvp_vector4_t get_bitstream(bool as_vec4);

	// Capture a stable ref formal target for one element. The returned
	// object either follows the live element through queue index shifts or,
	// after removal/reassignment, retains an outdated private value.
      vvp_object_t capture_element_ref(size_t idx, unsigned vec4_width);

	// IEEE 1800-2017 18.8: every element of an unpacked container is a
	// distinct random variable. Keep its active state with the container so
	// queue insert/erase operations can move the state with the element and
	// a newly-created element can inherit the container-wide default.
      bool rand_mode(size_t idx) const;
      bool rand_mode_any() const;
      bool rand_mode_default() const { return rand_mode_default_; }
      void set_rand_mode(size_t idx, bool mode);
      void set_all_rand_mode(bool mode);
      void inherit_rand_modes(const vvp_darray&that);
      void reorder_rand_modes(const std::vector<size_t>&source_indices);
      void reorder_element_refs(const std::vector<size_t>&source_indices);

	// Every unpacked randc element has an independent cycle. Keep the
	// committed history beside the live element so queue mutations and value
	// copies carry variable state with the same identity as rand_mode.
      const std::vector<bool>*randc_history(size_t idx) const;
      std::vector<bool>&randc_history(size_t idx);
      void inherit_randc_histories(const vvp_darray&that);

	// Copy the passive state that belongs to a container value. This carries
	// declared DPI geometry, the value-element prototype, and per-element
	// random state, but deliberately does not activate the source's temporary
	// declared-index view in the destination.
      void copy_passive_value_metadata_to(vvp_darray*that) const
	{ copy_passive_value_metadata_(that); }
      void reset_passive_value_metadata()
      {
	    dpi_left_ = 0;
	    dpi_right_ = 0;
	    dpi_has_range_ = false;
	    elem_class_ = 0;
	    rand_mode_default_ = true;
	    rand_modes_.clear();
	    randc_histories_.clear();
      }

	// M10-1: a dynamic array is 0-based, but one MARSHALED from a
	// fixed-size array carries that array's DECLARED range so the DPI
	// open-array accessors can report it (IEEE 1800-2017 H.10.2).
	//
	// Merely carrying that metadata must not change an ordinary
	// fixed-to-dynamic assignment: the resulting dynamic array is
	// still indexed 0..N-1. sv_declared_indexing_ is enabled only
	// while the object is installed in an open-array formal; the SV
	// query/index opcodes use it to expose the fixed actual's view.
      void dpi_set_decl_range(int left, int right)
      { dpi_left_ = left; dpi_right_ = right; dpi_has_range_ = true; }
      bool dpi_has_decl_range() const { return dpi_has_range_; }
      int dpi_decl_left() const  { return dpi_left_; }
      int dpi_decl_right() const { return dpi_right_; }
      void sv_set_declared_indexing(bool flag)
      { sv_declared_indexing_ = flag; }
      bool sv_uses_declared_indexing() const
      { return sv_declared_indexing_; }

	// M10 DPI open arrays: contiguous raw element storage for
	// atom-typed arrays (svOpenArrayHandle element access).
	// dpi_elem_bytes() is 0 when raw access is not available.
      virtual void* dpi_raw_data() { return 0; }
      virtual unsigned dpi_elem_bytes() const { return 0; }
      virtual bool dpi_elem_is_real() const { return false; }

	// An element PROTOTYPE for a container whose elements are
	// object-backed VALUE types (an unpacked struct). `new[]` leaves
	// the element slots nil; a member write such as `arr[i].f = v'
	// needs a live instance to store into, so a nil element is
	// materialized on first access by duplicating this prototype.
	//
	// A signal-backed container gets the same treatment from its
	// functor's declared_type(), but a container held in a CLASS
	// PROPERTY has no signal to ask -- which is why the member write
	// was silently dropped there. Carrying the prototype on the
	// container itself makes the two paths agree.
	//
	// Unset (nil) for containers of class HANDLES, whose nil elements
	// must stay null.
      void set_elem_class(const class class_type*t) { elem_class_ = t; }
      const class class_type* elem_class() const { return elem_class_; }

    protected:
	// Queue mutation hooks. Call these immediately before changing the
	// corresponding value sequence.
      void rand_mode_insert(size_t idx, bool discard_back = false);
      void rand_mode_push_back();
      void rand_mode_push_front(bool discard_back = false);
      void rand_mode_pop_back();
      void rand_mode_pop_front();
      void rand_mode_erase(size_t idx);
      void rand_mode_erase_tail(size_t idx);

	// Queue/dynamic-array element-reference lifetime hooks. Structural
	// mutations call these before changing the value sequence.
      void element_refs_detach_all();
      void element_refs_insert(size_t idx);
      void element_refs_remove(size_t idx);
      void element_refs_remove_tail(size_t idx);
      void element_refs_push_front(bool discard_back = false);
      void element_refs_pop_back();
      void element_refs_pop_front();

	// Carry passive per-object metadata onto a value copy: per-element
	// random modes, the declared fixed-range view (a duplicate of a marshaled
	// fixed-array actual describes the same geometry) and the
	// struct-element prototype. The declared-indexing ACTIVATION
	// flag is deliberately not copied — it is scoped to an
	// open-array formal installation (%store/obj/open) and a plain
	// dynamic-array copy is 0-based (IEEE 1800-2017 7.5).
      void copy_passive_value_metadata_(vvp_darray*that) const
      {
	    that->dpi_left_ = dpi_left_;
	    that->dpi_right_ = dpi_right_;
	    that->dpi_has_range_ = dpi_has_range_;
	    that->elem_class_ = elem_class_;
	    that->inherit_rand_modes(*this);
	    that->inherit_randc_histories(*this);
      }

	// A duplicate is the same declared container value in new storage, so it
	// shares the immutable declaration layout as well as passive metadata.
	// Assignment into named/property storage subsequently rebinds the copy to
	// the destination's immutable layout.
      void copy_value_metadata_(vvp_darray*that) const
      {
	    copy_passive_value_metadata_(that);
	    copy_declared_queue_layout_metadata_to(that);
      }

    private:
      friend class vvp_darray_element_ref;
      void register_element_ref(vvp_darray_element_ref*ref);
      void unregister_element_ref(vvp_darray_element_ref*ref);

      int  dpi_left_  = 0;
      int  dpi_right_ = 0;
      bool dpi_has_range_ = false;
      bool sv_declared_indexing_ = false;
      const class class_type* elem_class_ = 0;
      bool rand_mode_default_ = true;
      mutable std::vector<unsigned char> rand_modes_;
      mutable std::vector<std::vector<bool> > randc_histories_;
      std::set<vvp_darray_element_ref*> element_refs_;
};

template <class TYPE> class vvp_darray_atom : public vvp_darray {

    public:
      explicit inline vvp_darray_atom(size_t siz) : array_(siz) { }
      ~vvp_darray_atom() override;

      size_t get_size(void) const override;
      void clear(void) override;
      unsigned vec4_word_width(void) const override
      { return 8*sizeof(TYPE); }
      void set_word(unsigned adr, const vvp_vector4_t&value) override;
      void get_word(unsigned adr, vvp_vector4_t&value) override;
      void shallow_copy(const vvp_object*obj) override;
      vvp_object* duplicate(void) const override;
      vvp_vector4_t get_bitstream(bool as_vec4) override;

      void* dpi_raw_data() override
      { return array_.empty() ? (void*)0 : (void*)&array_[0]; }
      unsigned dpi_elem_bytes() const override { return sizeof(TYPE); }

    private:
      std::vector<TYPE> array_;
};

class vvp_darray_vec4 : public vvp_darray {

    public:
      inline vvp_darray_vec4(size_t siz, unsigned word_wid) :
                             array_(siz), word_wid_(word_wid) { }
      ~vvp_darray_vec4() override;

      size_t get_size(void) const override;
      void clear(void) override;
      unsigned vec4_word_width(void) const override { return word_wid_; }
      void set_word(unsigned adr, const vvp_vector4_t&value) override;
      void get_word(unsigned adr, vvp_vector4_t&value) override;
      void shallow_copy(const vvp_object*obj) override;
      vvp_object* duplicate(void) const override;
      vvp_vector4_t get_bitstream(bool as_vec4) override;

    private:
      std::vector<vvp_vector4_t> array_;
      unsigned word_wid_;
};

class vvp_darray_vec2 : public vvp_darray {

    public:
      inline vvp_darray_vec2(size_t siz, unsigned word_wid) :
                             array_(siz), word_wid_(word_wid) { }
      ~vvp_darray_vec2() override;

      size_t get_size(void) const override;
      void clear(void) override;
      unsigned vec4_word_width(void) const override { return word_wid_; }
      void set_word(unsigned adr, const vvp_vector4_t&value) override;
      void get_word(unsigned adr, vvp_vector4_t&value) override;
      void shallow_copy(const vvp_object*obj) override;
      vvp_object* duplicate(void) const override;
      vvp_vector4_t get_bitstream(bool as_vec4) override;

    private:
      std::vector<vvp_vector2_t> array_;
      unsigned word_wid_;
};

class vvp_darray_real : public vvp_darray {

    public:
      explicit inline vvp_darray_real(size_t siz) : array_(siz) { }
      ~vvp_darray_real() override;

      size_t get_size(void) const override;
      void clear(void) override;
      void set_word(unsigned adr, double value) override;
      void get_word(unsigned adr, double&value) override;
      void shallow_copy(const vvp_object*obj) override;
      vvp_object* duplicate(void) const override;
      vvp_vector4_t get_bitstream(bool as_vec4) override;

      void* dpi_raw_data() override
      { return array_.empty() ? (void*)0 : (void*)&array_[0]; }
      unsigned dpi_elem_bytes() const override { return sizeof(double); }
      bool dpi_elem_is_real() const override { return true; }

    private:
      std::vector<double> array_;
};

class vvp_darray_string : public vvp_darray {

    public:
      explicit inline vvp_darray_string(size_t siz) : array_(siz) { }
      ~vvp_darray_string() override;

      size_t get_size(void) const override;
      void clear(void) override;
      void set_word(unsigned adr, const std::string&value) override;
      void get_word(unsigned adr, std::string&value) override;
      void shallow_copy(const vvp_object*obj) override;
      vvp_object* duplicate(void) const override;
      vvp_vector4_t get_bitstream(bool as_vec4) override;

    private:
      std::vector<std::string> array_;
};

class vvp_darray_object : public vvp_darray {

    public:
      explicit inline vvp_darray_object(size_t siz) : array_(siz) { }
      ~vvp_darray_object() override;

      size_t get_size(void) const override;
      void clear(void) override;
      void set_word(unsigned adr, const vvp_object_t&value) override;
      void get_word(unsigned adr, vvp_object_t&value) override;
      void shallow_copy(const vvp_object*obj) override;
      vvp_object* duplicate(void) const override;

    protected:
      void rebind_declared_element_container_layout(
	    const vvp_container_layout_t&element_layout) override;

    private:
      std::vector<vvp_object_t> array_;
};

class vvp_queue : public vvp_darray {

    public:
      inline vvp_queue(void) { }
      ~vvp_queue() override;

      virtual size_t get_size(void) const override =0;
      void clear(void) override { erase_tail(0); }
      virtual void copy_elems(vvp_object_t src, uint64_t max_size);

      virtual void set_word_max(unsigned adr, const vvp_vector4_t&value, uint64_t max_size);
      virtual void insert(unsigned idx, const vvp_vector4_t&value, uint64_t max_size);
      virtual void push_back(const vvp_vector4_t&value, uint64_t max_size);
      virtual void push_front(const vvp_vector4_t&value, uint64_t max_size);

      virtual void set_word_max(unsigned adr, double value, uint64_t max_size);
      virtual void insert(unsigned idx, double value, uint64_t max_size);
      virtual void push_back(double value, uint64_t max_size);
      virtual void push_front(double value, uint64_t max_size);

      virtual void set_word_max(unsigned adr, const std::string&value, uint64_t max_size);
      virtual void insert(unsigned idx, const std::string&value, uint64_t max_size);
      virtual void push_back(const std::string&value, uint64_t max_size);
      virtual void push_front(const std::string&value, uint64_t max_size);

      virtual void set_word_max(unsigned adr, const vvp_object_t&value, uint64_t max_size);
      virtual void insert(unsigned idx, const vvp_object_t&value, uint64_t max_size);
      virtual void push_back(const vvp_object_t&value, uint64_t max_size);
      virtual void push_front(const vvp_object_t&value, uint64_t max_size);

      virtual void pop_back(void) =0;
      virtual void pop_front(void)=0;
      virtual void erase(unsigned idx)=0;
      virtual void erase_tail(unsigned idx)=0;

    protected:
      void apply_declared_container_layout_own(
	    const vvp_container_layout_t&layout) override;
};

class vvp_queue_real : public vvp_queue {

    public:
      ~vvp_queue_real() override;
      size_t get_size(void) const override { return queue.size(); };
      vvp_object* duplicate(void) const override;
      void copy_elems(vvp_object_t src, uint64_t max_size) override;
      void set_word_max(unsigned adr, double value, uint64_t max_size) override;
      void set_word(unsigned adr, double value) override;
      void get_word(unsigned adr, double&value) override;
      void insert(unsigned idx, double value, uint64_t max_size) override;
      void push_back(double value, uint64_t max_size) override;
      void push_front(double value, uint64_t max_size) override;
      void pop_back(void) override
      { element_refs_pop_back(); rand_mode_pop_back(); queue.pop_back(); touch(); };
      void pop_front(void) override
      { element_refs_pop_front(); rand_mode_pop_front(); queue.pop_front(); touch(); };
      void erase(unsigned idx) override;
      void erase_tail(unsigned idx) override;

    private:
      std::deque<double> queue;
};

class vvp_queue_string : public vvp_queue {

    public:
      ~vvp_queue_string() override;
      size_t get_size(void) const override { return queue.size(); };
      vvp_object* duplicate(void) const override;
      void copy_elems(vvp_object_t src, uint64_t max_size) override;
      void set_word_max(unsigned adr, const std::string&value, uint64_t max_size) override;
      void set_word(unsigned adr, const std::string&value) override;
      void get_word(unsigned adr, std::string&value) override;
      void insert(unsigned idx, const std::string&value, uint64_t max_size) override;
      void push_back(const std::string&value, uint64_t max_size) override;
      void push_front(const std::string&value, uint64_t max_size) override;
      void pop_back(void) override
      { element_refs_pop_back(); rand_mode_pop_back(); queue.pop_back(); touch(); };
      void pop_front(void) override
      { element_refs_pop_front(); rand_mode_pop_front(); queue.pop_front(); touch(); };
      void erase(unsigned idx) override;
      void erase_tail(unsigned idx) override;
      vvp_vector4_t get_bitstream(bool as_vec4) override;

    private:
      std::deque<std::string> queue;
};

class vvp_queue_vec4 : public vvp_queue {

    public:
      ~vvp_queue_vec4() override;
      size_t get_size(void) const override { return queue.size(); };
      vvp_object* duplicate(void) const override;
      void copy_elems(vvp_object_t src, uint64_t max_size) override;
      void set_word_max(unsigned adr, const vvp_vector4_t&value, uint64_t max_size) override;
      void set_word(unsigned adr, const vvp_vector4_t&value) override;
      void get_word(unsigned adr, vvp_vector4_t&value) override;
      void insert(unsigned idx, const vvp_vector4_t&value, uint64_t max_size) override;
      void push_back(const vvp_vector4_t&value, uint64_t max_size) override;
      void push_front(const vvp_vector4_t&value, uint64_t max_size) override;
      void pop_back(void) override
      { element_refs_pop_back(); rand_mode_pop_back(); queue.pop_back(); touch(); };
      void pop_front(void) override
      { element_refs_pop_front(); rand_mode_pop_front(); queue.pop_front(); touch(); };
      void erase(unsigned idx) override;
      void erase_tail(unsigned idx) override;
      vvp_vector4_t get_bitstream(bool as_vec4) override;

    private:
      std::deque<vvp_vector4_t> queue;
};

class vvp_queue_object : public vvp_queue {

    public:
      ~vvp_queue_object() override;
      size_t get_size(void) const override { return queue.size(); };
      vvp_object* duplicate(void) const override;
      void copy_elems(vvp_object_t src, uint64_t max_size) override;
      void set_word_max(unsigned adr, const vvp_object_t&value, uint64_t max_size) override;
      void set_word(unsigned adr, const vvp_object_t&value) override;
      void get_word(unsigned adr, vvp_object_t&value) override;
      // I7: silent override for the vec4 variant.  The base vvp_darray
      // emits a per-call warning when code-gen mistakenly emits the wrong
      // typed accessor on a queue of class handles.  The underlying
      // type-mismatch (caller should use the vvp_object_t variant) is a
      // separate code-gen gap; meanwhile, return an empty vec4 quietly.
      void get_word(unsigned, vvp_vector4_t&out) override { out = vvp_vector4_t(); }
      void insert(unsigned idx, const vvp_object_t&value, uint64_t max_size) override;
      void push_back(const vvp_object_t&value, uint64_t max_size) override;
      void push_front(const vvp_object_t&value, uint64_t max_size) override;
      void pop_back(void) override
      { element_refs_pop_back(); rand_mode_pop_back(); queue.pop_back(); touch(); };
      void pop_front(void) override
      { element_refs_pop_front(); rand_mode_pop_front(); queue.pop_front(); touch(); };
      void erase(unsigned idx) override;
      void erase_tail(unsigned idx) override;

    protected:
      void rebind_declared_element_container_layout(
	    const vvp_container_layout_t&element_layout) override;

    private:
      std::deque<vvp_object_t> queue;
};

extern std::string get_fileline();

#endif /* IVL_vvp_darray_H */
