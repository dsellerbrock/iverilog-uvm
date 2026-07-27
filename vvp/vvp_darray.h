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
# include  <string>
# include  <vector>

class vvp_darray : public vvp_object {

    public:
      inline vvp_darray() { }
      virtual ~vvp_darray() override;

      virtual size_t get_size(void) const =0;

      virtual void set_word(unsigned adr, const vvp_vector4_t&value);
      virtual void get_word(unsigned adr, vvp_vector4_t&value);

      virtual void set_word(unsigned adr, double value);
      virtual void get_word(unsigned adr, double&value);

      virtual void set_word(unsigned adr, const std::string&value);
      virtual void get_word(unsigned adr, std::string&value);

      virtual void set_word(unsigned adr, const vvp_object_t&value);
      virtual void get_word(unsigned adr, vvp_object_t&value);

      virtual vvp_vector4_t get_bitstream(bool as_vec4);

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

    private:
      int  dpi_left_  = 0;
      int  dpi_right_ = 0;
      bool dpi_has_range_ = false;
      bool sv_declared_indexing_ = false;
      const class class_type* elem_class_ = 0;
};

template <class TYPE> class vvp_darray_atom : public vvp_darray {

    public:
      explicit inline vvp_darray_atom(size_t siz) : array_(siz) { }
      ~vvp_darray_atom() override;

      size_t get_size(void) const override;
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
      void set_word(unsigned adr, const vvp_vector4_t&value) override;
      void get_word(unsigned adr, vvp_vector4_t&value) override;
      void shallow_copy(const vvp_object*obj) override;
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
      void set_word(unsigned adr, const vvp_object_t&value) override;
      void get_word(unsigned adr, vvp_object_t&value) override;
      void shallow_copy(const vvp_object*obj) override;
      vvp_object* duplicate(void) const override;

    private:
      std::vector<vvp_object_t> array_;
};

class vvp_queue : public vvp_darray {

    public:
      inline vvp_queue(void) { }
      ~vvp_queue() override;

      virtual size_t get_size(void) const override =0;
      virtual void copy_elems(vvp_object_t src, unsigned max_size);

      virtual void set_word_max(unsigned adr, const vvp_vector4_t&value, unsigned max_size);
      virtual void insert(unsigned idx, const vvp_vector4_t&value, unsigned max_size);
      virtual void push_back(const vvp_vector4_t&value, unsigned max_size);
      virtual void push_front(const vvp_vector4_t&value, unsigned max_size);

      virtual void set_word_max(unsigned adr, double value, unsigned max_size);
      virtual void insert(unsigned idx, double value, unsigned max_size);
      virtual void push_back(double value, unsigned max_size);
      virtual void push_front(double value, unsigned max_size);

      virtual void set_word_max(unsigned adr, const std::string&value, unsigned max_size);
      virtual void insert(unsigned idx, const std::string&value, unsigned max_size);
      virtual void push_back(const std::string&value, unsigned max_size);
      virtual void push_front(const std::string&value, unsigned max_size);

      virtual void set_word_max(unsigned adr, const vvp_object_t&value, unsigned max_size);
      virtual void insert(unsigned idx, const vvp_object_t&value, unsigned max_size);
      virtual void push_back(const vvp_object_t&value, unsigned max_size);
      virtual void push_front(const vvp_object_t&value, unsigned max_size);

      virtual void pop_back(void) =0;
      virtual void pop_front(void)=0;
      virtual void erase(unsigned idx)=0;
      virtual void erase_tail(unsigned idx)=0;
};

class vvp_queue_real : public vvp_queue {

    public:
      size_t get_size(void) const override { return queue.size(); };
      vvp_object* duplicate(void) const override;
      void copy_elems(vvp_object_t src, unsigned max_size) override;
      void set_word_max(unsigned adr, double value, unsigned max_size) override;
      void set_word(unsigned adr, double value) override;
      void get_word(unsigned adr, double&value) override;
      void insert(unsigned idx, double value, unsigned max_size) override;
      void push_back(double value, unsigned max_size) override;
      void push_front(double value, unsigned max_size) override;
      void pop_back(void) override { queue.pop_back(); touch(); };
      void pop_front(void) override { queue.pop_front(); touch(); };
      void erase(unsigned idx) override;
      void erase_tail(unsigned idx) override;

    private:
      std::deque<double> queue;
};

class vvp_queue_string : public vvp_queue {

    public:
      size_t get_size(void) const override { return queue.size(); };
      vvp_object* duplicate(void) const override;
      void copy_elems(vvp_object_t src, unsigned max_size) override;
      void set_word_max(unsigned adr, const std::string&value, unsigned max_size) override;
      void set_word(unsigned adr, const std::string&value) override;
      void get_word(unsigned adr, std::string&value) override;
      void insert(unsigned idx, const std::string&value, unsigned max_size) override;
      void push_back(const std::string&value, unsigned max_size) override;
      void push_front(const std::string&value, unsigned max_size) override;
      void pop_back(void) override { queue.pop_back(); touch(); };
      void pop_front(void) override { queue.pop_front(); touch(); };
      void erase(unsigned idx) override;
      void erase_tail(unsigned idx) override;
      vvp_vector4_t get_bitstream(bool as_vec4) override;

    private:
      std::deque<std::string> queue;
};

class vvp_queue_vec4 : public vvp_queue {

    public:
      size_t get_size(void) const override { return queue.size(); };
      vvp_object* duplicate(void) const override;
      void copy_elems(vvp_object_t src, unsigned max_size) override;
      void set_word_max(unsigned adr, const vvp_vector4_t&value, unsigned max_size) override;
      void set_word(unsigned adr, const vvp_vector4_t&value) override;
      void get_word(unsigned adr, vvp_vector4_t&value) override;
      void insert(unsigned idx, const vvp_vector4_t&value, unsigned max_size) override;
      void push_back(const vvp_vector4_t&value, unsigned max_size) override;
      void push_front(const vvp_vector4_t&value, unsigned max_size) override;
      void pop_back(void) override { queue.pop_back(); touch(); };
      void pop_front(void) override { queue.pop_front(); touch(); };
      void erase(unsigned idx) override;
      void erase_tail(unsigned idx) override;
      vvp_vector4_t get_bitstream(bool as_vec4) override;

    private:
      std::deque<vvp_vector4_t> queue;
};

class vvp_queue_object : public vvp_queue {

    public:
      size_t get_size(void) const override { return queue.size(); };
      vvp_object* duplicate(void) const override;
      void copy_elems(vvp_object_t src, unsigned max_size) override;
      void set_word_max(unsigned adr, const vvp_object_t&value, unsigned max_size) override;
      void set_word(unsigned adr, const vvp_object_t&value) override;
      void get_word(unsigned adr, vvp_object_t&value) override;
      // I7: silent override for the vec4 variant.  The base vvp_darray
      // emits a per-call warning when code-gen mistakenly emits the wrong
      // typed accessor on a queue of class handles.  The underlying
      // type-mismatch (caller should use the vvp_object_t variant) is a
      // separate code-gen gap; meanwhile, return an empty vec4 quietly.
      void get_word(unsigned, vvp_vector4_t&out) override { out = vvp_vector4_t(); }
      void insert(unsigned idx, const vvp_object_t&value, unsigned max_size) override;
      void push_back(const vvp_object_t&value, unsigned max_size) override;
      void push_front(const vvp_object_t&value, unsigned max_size) override;
      void pop_back(void) override { queue.pop_back(); touch(); };
      void pop_front(void) override { queue.pop_front(); touch(); };
      void erase(unsigned idx) override;
      void erase_tail(unsigned idx) override;

    private:
      std::deque<vvp_object_t> queue;
};

extern std::string get_fileline();

#endif /* IVL_vvp_darray_H */
