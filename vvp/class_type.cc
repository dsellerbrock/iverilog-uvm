/*
 * Copyright (c) 2012-2026 Stephen Williams (steve@icarus.com)
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

# include  "class_type.h"
# include  "compile.h"
# include  "vpi_priv.h"
# include  "vvp_assoc.h"
# include  "vvp_cobject.h"
# include  "vvp_darray.h"
# include  "config.h"
# include  <cinttypes>
# include  <cstring>
# include  <map>
# include  <iostream>
#ifdef CHECK_WITH_VALGRIND
# include  "vvp_cleanup.h"
#endif
# include  <cassert>

using namespace std;

static map<string, const class_type*> class_types_by_dispatch_prefix_;

static bool class_trace_enabled_(const std::string&class_name)
{
      static const char*env = 0;
      static bool init = false;
      if (!init) {
            env = getenv("IVL_CLASS_TRACE");
            init = true;
      }

      if (!(env && *env))
            return false;
      if ((strcmp(env, "1") == 0) || (strcmp(env, "ALL") == 0)
          || (strcmp(env, "*") == 0) || (strcmp(env, "true") == 0))
            return true;

      return class_name.find(env) != string::npos;
}

/*
 * This class_property_t class is an abstract base class for
 * representing a property of an instance. The definition keeps and
 * array (of pointers) of these in order to define the the class.
 */
class class_property_t {
    public:
      inline class_property_t() { offset_ = 0; }
      virtual ~class_property_t() =0;
	// How much space does an instance of this property require?
      virtual size_t instance_size() const =0;

      void set_offset(size_t off) { offset_ = off; }
      void describe(const std::string&owner_class, const std::string&prop_name,
		    const std::string&type_name)
      {
	    owner_class_ = owner_class;
	    prop_name_ = prop_name;
	    type_name_ = type_name;
      }

    public:
      virtual void construct(char*buf) const;
      virtual void destruct(char*buf) const;

      virtual void set_vec4(char*buf, const vvp_vector4_t&val);
      virtual void get_vec4(char*buf, vvp_vector4_t&val);
      virtual void set_vec4(char*buf, const vvp_vector4_t&val, uint64_t idx);
      virtual void get_vec4(char*buf, vvp_vector4_t&val, uint64_t idx);

      virtual void set_real(char*buf, double val);
      virtual double get_real(char*buf);

      virtual void set_string(char*buf, const std::string&val);
      virtual string get_string(char*buf);

      virtual void set_object(char*buf, const vvp_object_t&val, uint64_t element);
      virtual void get_object(char*buf, vvp_object_t&val, uint64_t element);

	// Implement polymorphic shallow copy.
      virtual void copy(char*buf, char*src) = 0;

    protected:
      void warn_unsupported_(const char*op, const char*detail) const;
      size_t offset_;
      std::string owner_class_;
      std::string prop_name_;
      std::string type_name_;
};

class_property_t::~class_property_t()
{
}

void class_property_t::construct(char*) const
{
}

void class_property_t::destruct(char*) const
{
}

void class_property_t::set_vec4(char*, const vvp_vector4_t&)
{
      static bool warned = false;
      if (!warned) {
	    warn_unsupported_("set_vec4", "ignoring write");
	    warned = true;
      }
}

void class_property_t::get_vec4(char*, vvp_vector4_t&)
{
      static bool warned = false;
      if (!warned) {
	    warn_unsupported_("get_vec4", "returning default value");
	    warned = true;
      }
}

void class_property_t::set_vec4(char*buf, const vvp_vector4_t&val, uint64_t)
{
      set_vec4(buf, val);
}

void class_property_t::get_vec4(char*buf, vvp_vector4_t&val, uint64_t)
{
      get_vec4(buf, val);
}

void class_property_t::set_real(char*, double)
{
      static bool warned = false;
      if (!warned) {
	    warn_unsupported_("set_real", "ignoring write");
	    warned = true;
      }
}

double class_property_t::get_real(char*)
{
      static bool warned = false;
      if (!warned) {
	    warn_unsupported_("get_real", "returning 0.0");
	    warned = true;
      }
      return 0.0;
}

void class_property_t::set_string(char*, const string&)
{
      static bool warned = false;
      if (!warned) {
	    warn_unsupported_("set_string", "ignoring write");
	    warned = true;
      }
}

string class_property_t::get_string(char*)
{
      static bool warned = false;
      if (!warned) {
	    warn_unsupported_("get_string", "returning empty string");
	    warned = true;
      }
      return string();
}

void class_property_t::set_object(char*, const vvp_object_t&, uint64_t)
{
      static bool warned = false;
      if (!warned) {
	    warn_unsupported_("set_object", "ignoring write");
	    warned = true;
      }
}

void class_property_t::get_object(char*, vvp_object_t&, uint64_t)
{
      static bool warned = false;
      if (!warned) {
	    warn_unsupported_("get_object", "returning null object");
	    warned = true;
      }
}

void class_property_t::warn_unsupported_(const char*op, const char*detail) const
{
      fprintf(stderr,
	      "Warning: class_property_t::%s on unsupported property type"
	      " (class=%s property=%s type=%s); %s"
	      " (further similar warnings suppressed)\n",
	      op,
	      owner_class_.empty() ? "<unknown>" : owner_class_.c_str(),
	      prop_name_.empty() ? "<unknown>" : prop_name_.c_str(),
	      type_name_.empty() ? "<unknown>" : type_name_.c_str(),
	      detail);
}

/*
 */
template <class T> class property_atom : public class_property_t {
    public:
      inline explicit property_atom(size_t as=0) : array_size_(as==0? 1 : as) { }
      ~property_atom() override { }

      size_t instance_size() const override { return array_size_ * sizeof(T); }

    public:
      void construct(char*buf) const override
      { T*tmp = reinterpret_cast<T*> (buf+offset_);
	for (size_t ii = 0; ii < array_size_; ii += 1)
	      tmp[ii] = 0;
      }

      void set_vec4(char*buf, const vvp_vector4_t&val) override;
      void get_vec4(char*buf, vvp_vector4_t&val) override;
      void set_vec4(char*buf, const vvp_vector4_t&val, uint64_t idx) override;
      void get_vec4(char*buf, vvp_vector4_t&val, uint64_t idx) override;

      void copy(char*dst, char*src) override;

    private:
      size_t array_size_;
};

class property_bit : public class_property_t {
    public:
      explicit inline property_bit(size_t wid, size_t as=0)
      : wid_(wid), array_size_(as==0? 1 : as) { }
      ~property_bit() override { }

      size_t instance_size() const override { return array_size_ * sizeof(vvp_vector2_t); }

    public:
      void construct(char*buf) const override
      {
	    for (size_t idx = 0 ; idx < array_size_ ; idx += 1)
		  new (buf+offset_ + idx*sizeof(vvp_vector2_t)) vvp_vector2_t (0, wid_);
      }

      void destruct(char*buf) const override
      {
	    vvp_vector2_t*tmp = reinterpret_cast<vvp_vector2_t*>(buf+offset_);
	    for (size_t idx = 0 ; idx < array_size_ ; idx += 1)
		  (tmp+idx)->~vvp_vector2_t();
      }

      void set_vec4(char*buf, const vvp_vector4_t&val) override;
      void get_vec4(char*buf, vvp_vector4_t&val) override;
      void set_vec4(char*buf, const vvp_vector4_t&val, uint64_t idx) override;
      void get_vec4(char*buf, vvp_vector4_t&val, uint64_t idx) override;

      void copy(char*dst, char*src) override;

    private:
      size_t wid_;
      size_t array_size_;
};

class property_logic : public class_property_t {
    public:
      explicit inline property_logic(size_t wid, size_t as=0)
      : wid_(wid), array_size_(as==0? 1 : as) { }
      ~property_logic() override { }

      size_t instance_size() const override { return array_size_ * sizeof(vvp_vector4_t); }

    public:
      void construct(char*buf) const override
      {
	    for (size_t idx = 0 ; idx < array_size_ ; idx += 1)
		  new (buf+offset_ + idx*sizeof(vvp_vector4_t)) vvp_vector4_t (wid_);
      }

      void destruct(char*buf) const override
      {
	    vvp_vector4_t*tmp = reinterpret_cast<vvp_vector4_t*>(buf+offset_);
	    for (size_t idx = 0 ; idx < array_size_ ; idx += 1)
		  (tmp+idx)->~vvp_vector4_t();
      }

      void set_vec4(char*buf, const vvp_vector4_t&val) override;
      void get_vec4(char*buf, vvp_vector4_t&val) override;
      void set_vec4(char*buf, const vvp_vector4_t&val, uint64_t idx) override;
      void get_vec4(char*buf, vvp_vector4_t&val, uint64_t idx) override;

      void copy(char*dst, char*src) override;

    private:
      size_t wid_;
      size_t array_size_;
};

template <class T> class property_real : public class_property_t {
    public:
      inline explicit property_real(void) { }
      ~property_real() override { }

      size_t instance_size() const override { return sizeof(T); }

    public:
      void construct(char*buf) const override
      { T*tmp = reinterpret_cast<T*> (buf+offset_);
	*tmp = 0.0;
      }

      void set_real(char*buf, double val) override;
      double get_real(char*buf) override;

      void copy(char*dst, char*src) override;
};

class property_string : public class_property_t {
    public:
      inline explicit property_string(void) { }
      ~property_string() override { }

      size_t instance_size() const override { return sizeof(std::string); }

    public:
      void construct(char*buf) const override
      { /* string*tmp = */ new (buf+offset_) string; }

      void destruct(char*buf) const override
      { string*tmp = reinterpret_cast<string*> (buf+offset_);
	tmp->~string();
      }

      void set_string(char*buf, const string&) override;
      string get_string(char*buf) override;

      void copy(char*dst, char*src) override;
};

class property_object : public class_property_t {
    public:
      inline explicit property_object(uint64_t as): array_size_(as==0? 1 : as) { }
      ~property_object() override { }

      size_t instance_size() const override { return array_size_ * sizeof(vvp_object_t); }

    public:
      void construct(char*buf) const override;

      void destruct(char*buf) const override;

      void get_vec4(char*buf, vvp_vector4_t&val) override;
      void set_object(char*buf, const vvp_object_t&, uint64_t) override;
      void get_object(char*buf, vvp_object_t&, uint64_t) override;

      void copy(char*dst, char*src) override;

    private:
      size_t array_size_;
};

class property_cobject : public class_property_t {
    public:
      inline explicit property_cobject(uint64_t as)
      : defn_(0), array_size_(as==0? 1 : as) { }
      ~property_cobject() override { }

      size_t instance_size() const override { return array_size_ * sizeof(vvp_object_t); }

      void construct(char*buf) const override;
      void destruct(char*buf) const override;
      void get_vec4(char*buf, vvp_vector4_t&val) override;
      void set_object(char*buf, const vvp_object_t&, uint64_t) override;
      void get_object(char*buf, vvp_object_t&, uint64_t) override;
      void copy(char*dst, char*src) override;

    public:
      class_type*defn_;

    private:
      size_t array_size_;
};

template <class QUEUE_TYPE> class property_queue : public class_property_t {
    public:
      inline explicit property_queue(uint64_t as): array_size_(as==0? 1 : as) { }
      ~property_queue() override { }

      size_t instance_size() const override { return array_size_ * sizeof(vvp_object_t); }

    public:
      void construct(char*buf) const override
      {
	    for (size_t idx = 0 ; idx < array_size_ ; idx += 1)
		  new (buf+offset_ + idx*sizeof(vvp_object_t)) vvp_object_t(new QUEUE_TYPE);
      }

      void destruct(char*buf) const override
      {
	    vvp_object_t*tmp = reinterpret_cast<vvp_object_t*> (buf+offset_);
	    for (size_t idx = 0 ; idx < array_size_ ; idx += 1)
		  (tmp+idx)->~vvp_object_t();
      }

      void get_vec4(char*buf, vvp_vector4_t&val) override
      {
	    const vvp_object_t*tmp = reinterpret_cast<vvp_object_t*>(buf+offset_);
	    vvp_bit4_t bit = tmp[0].test_nil() ? BIT4_0 : BIT4_1;
	    val = vvp_vector4_t(1, bit);
      }

      void set_object(char*buf, const vvp_object_t&val, uint64_t idx) override
      {
            if (idx >= array_size_) {
                  static bool warned_property_queue_oob_set = false;
                  if (!warned_property_queue_oob_set) {
                        fprintf(stderr,
                                "Warning: property_queue::set_object class=%s prop=%s type=%s"
                                " index %" PRIu64 " out of range (size=%zu); using index 0"
                                " (further similar warnings suppressed)\n",
                                owner_class_.empty() ? "<unknown>" : owner_class_.c_str(),
                                prop_name_.empty() ? "<unknown>" : prop_name_.c_str(),
                                type_name_.empty() ? "<unknown>" : type_name_.c_str(),
                                idx, array_size_);
                        warned_property_queue_oob_set = true;
                  }
                  idx = 0;
            }
	    vvp_object_t*tmp = reinterpret_cast<vvp_object_t*>(buf+offset_);
            if (val.test_nil()) {
                  tmp[idx].reset();
            } else if (val.peek<QUEUE_TYPE>()) {
                  tmp[idx] = val.duplicate();
            } else {
                  tmp[idx] = val;
            }
      }

      void get_object(char*buf, vvp_object_t&val, uint64_t idx) override
      {
            if (idx >= array_size_) {
                  static bool warned_property_queue_oob_get = false;
                  if (!warned_property_queue_oob_get) {
                        fprintf(stderr,
                                "Warning: property_queue::get_object class=%s prop=%s type=%s"
                                " index %" PRIu64 " out of range (size=%zu); using index 0"
                                " (further similar warnings suppressed)\n",
                                owner_class_.empty() ? "<unknown>" : owner_class_.c_str(),
                                prop_name_.empty() ? "<unknown>" : prop_name_.c_str(),
                                type_name_.empty() ? "<unknown>" : type_name_.c_str(),
                                idx, array_size_);
                        warned_property_queue_oob_get = true;
                  }
                  idx = 0;
            }
	    const vvp_object_t*tmp = reinterpret_cast<vvp_object_t*>(buf+offset_);
	    val = tmp[idx];
      }

      void copy(char*dst, char*src) override
      {
	    vvp_object_t*dst_obj = reinterpret_cast<vvp_object_t*>(dst+offset_);
	    const vvp_object_t*src_obj = reinterpret_cast<vvp_object_t*>(src+offset_);
	    for (size_t idx = 0 ; idx < array_size_ ; idx += 1) {
                  if (src_obj[idx].test_nil()) {
                        dst_obj[idx].reset();
                  } else if (src_obj[idx].peek<QUEUE_TYPE>()) {
                        dst_obj[idx] = src_obj[idx].duplicate();
                  } else {
		        dst_obj[idx] = src_obj[idx];
                  }
            }
      }

    private:
      size_t array_size_;
};

template <class T> void property_atom<T>::set_vec4(char*buf, const vvp_vector4_t&val)
{
      T*tmp = reinterpret_cast<T*> (buf+offset_);
      bool flag = vector4_to_value(val, *tmp, true, false);
      if (!flag) {
            static bool warned_property_atom_set_vec4 = false;
            if (!warned_property_atom_set_vec4) {
                  fprintf(stderr,
                          "Warning: property_atom::set_vec4 conversion failed;"
                          " coercing non-numeric value to 0 (further similar warnings suppressed)\n");
                  warned_property_atom_set_vec4 = true;
            }
            *tmp = 0;
      }
}

template <class T> void property_atom<T>::get_vec4(char*buf, vvp_vector4_t&val)
{
      T*src = reinterpret_cast<T*> (buf+offset_);
      const size_t tmp_cnt = sizeof(T)<sizeof(unsigned long)
				       ? 1
				       : sizeof(T) / sizeof(unsigned long);
      unsigned long tmp[tmp_cnt];
      tmp[0] = src[0];

      for (size_t idx = 1 ; idx < tmp_cnt ; idx += 1)
	    tmp[idx] = src[0] >> idx * 8 * sizeof(tmp[0]);

      val.resize(8*sizeof(T));
      val.setarray(0, val.size(), tmp);
}

template <class T> void property_atom<T>::set_vec4(char*buf, const vvp_vector4_t&val, uint64_t idx)
{
      if (idx >= array_size_) return;
      T*tmp = reinterpret_cast<T*> (buf+offset_);
      bool flag = vector4_to_value(val, tmp[idx], true, false);
      if (!flag) {
	    static bool warned = false;
	    if (!warned) {
		  fprintf(stderr,
			  "Warning: property_atom::set_vec4 indexed conversion failed;"
			  " coercing non-numeric value to 0\n");
		  warned = true;
	    }
	    tmp[idx] = 0;
      }
}

template <class T> void property_atom<T>::get_vec4(char*buf, vvp_vector4_t&val, uint64_t idx)
{
      if (idx >= array_size_) { val = vvp_vector4_t(8*sizeof(T), BIT4_0); return; }
      T*src = reinterpret_cast<T*> (buf+offset_);
      const size_t tmp_cnt = sizeof(T)<sizeof(unsigned long)
			       ? 1
			       : sizeof(T) / sizeof(unsigned long);
      unsigned long tmp[tmp_cnt];
      tmp[0] = (unsigned long)src[idx];

      for (size_t ii = 1 ; ii < tmp_cnt ; ii += 1)
	    tmp[ii] = (unsigned long)(src[idx] >> (uint64_t)(ii * 8 * sizeof(tmp[0])));

      val.resize(8*sizeof(T));
      val.setarray(0, val.size(), tmp);
}

template <class T> void property_atom<T>::copy(char*dst, char*src)
{
      T*dst_obj = reinterpret_cast<T*> (dst+offset_);
      T*src_obj = reinterpret_cast<T*> (src+offset_);
      for (size_t ii = 0; ii < array_size_; ii += 1)
	    dst_obj[ii] = src_obj[ii];
}

void property_bit::set_vec4(char*buf, const vvp_vector4_t&val)
{
      set_vec4(buf, val, 0);
}

void property_bit::get_vec4(char*buf, vvp_vector4_t&val)
{
      get_vec4(buf, val, 0);
}

void property_bit::set_vec4(char*buf, const vvp_vector4_t&val, uint64_t idx)
{
      if (idx >= array_size_) {
            // Likely an X / underflow value used as an array index. Suppress
            // and carry on rather than abort -- this is far more useful for
            // diagnosis on a test that's making real progress.
            static int warned_idx = 0;
            if (warned_idx < 8) {
                  fprintf(stderr,
                          "vvp warning: property_bit::set_vec4 idx=%lu out"
                          " of range (size=%zu); skipping assignment"
                          " (further similar warnings suppressed)\n",
                          (unsigned long)idx, (size_t)array_size_);
                  warned_idx++;
            }
            return;
      }
      vvp_vector2_t*obj = reinterpret_cast<vvp_vector2_t*> (buf+offset_);
      obj[idx] = val;
}

void property_bit::get_vec4(char*buf, vvp_vector4_t&val, uint64_t idx)
{
      if (idx >= array_size_) {
            static int warned_idx = 0;
            if (warned_idx < 8) {
                  fprintf(stderr,
                          "vvp warning: property_bit::get_vec4 idx=%lu out"
                          " of range (size=%zu); returning X"
                          " (further similar warnings suppressed)\n",
                          (unsigned long)idx, (size_t)array_size_);
                  warned_idx++;
            }
            val = vvp_vector4_t(wid_ ? wid_ : 1, BIT4_X);
            return;
      }
      const vvp_vector2_t*obj = reinterpret_cast<vvp_vector2_t*> (buf+offset_);
      val = vector2_to_vector4(obj[idx], obj[idx].size());
}

void property_bit::copy(char*dst, char*src)
{
      vvp_vector2_t*dst_obj = reinterpret_cast<vvp_vector2_t*> (dst+offset_);
      const vvp_vector2_t*src_obj = reinterpret_cast<const vvp_vector2_t*> (src+offset_);
      for (size_t idx = 0 ; idx < array_size_ ; idx += 1)
	    dst_obj[idx] = src_obj[idx];
}

void property_logic::set_vec4(char*buf, const vvp_vector4_t&val)
{
      set_vec4(buf, val, 0);
}

void property_logic::get_vec4(char*buf, vvp_vector4_t&val)
{
      get_vec4(buf, val, 0);
}

void property_logic::set_vec4(char*buf, const vvp_vector4_t&val, uint64_t idx)
{
      assert(idx < array_size_);
      vvp_vector4_t*obj = reinterpret_cast<vvp_vector4_t*> (buf+offset_);
      obj[idx] = val;
}

void property_logic::get_vec4(char*buf, vvp_vector4_t&val, uint64_t idx)
{
      assert(idx < array_size_);
      const vvp_vector4_t*obj = reinterpret_cast<const vvp_vector4_t*> (buf+offset_);
      val = obj[idx];
}

void property_logic::copy(char*dst, char*src)
{
      vvp_vector4_t*dst_obj = reinterpret_cast<vvp_vector4_t*> (dst+offset_);
      const vvp_vector4_t*src_obj = reinterpret_cast<const vvp_vector4_t*> (src+offset_);
      for (size_t idx = 0 ; idx < array_size_ ; idx += 1)
	    dst_obj[idx] = src_obj[idx];
}

template <class T> void property_real<T>::set_real(char*buf, double val)
{
      T*tmp = reinterpret_cast<T*>(buf+offset_);
      *tmp = val;
}

template <class T> double property_real<T>::get_real(char*buf)
{
      T*tmp = reinterpret_cast<T*>(buf+offset_);
      return *tmp;
}

template <class T> void property_real<T>::copy(char*dst, char*src)
{
      T*dst_obj = reinterpret_cast<T*> (dst+offset_);
      T*src_obj = reinterpret_cast<T*> (src+offset_);
      *dst_obj = *src_obj;
}

void property_string::set_string(char*buf, const string&val)
{
      string*tmp = reinterpret_cast<string*>(buf+offset_);
      *tmp = val;
}

string property_string::get_string(char*buf)
{
      const string*tmp = reinterpret_cast<string*>(buf+offset_);
      return *tmp;
}

void property_string::copy(char*dst, char*src)
{
      string*dst_obj = reinterpret_cast<string*> (dst+offset_);
      const string*src_obj = reinterpret_cast<string*> (src+offset_);
      *dst_obj = *src_obj;
}

void property_object::construct(char*buf) const
{
      for (size_t idx = 0 ; idx < array_size_ ; idx += 1)
	    new (buf+offset_ + idx*sizeof(vvp_object_t)) vvp_object_t;
}

void property_object::destruct(char*buf) const
{
      vvp_object_t*tmp = reinterpret_cast<vvp_object_t*> (buf+offset_);
      for (size_t idx = 0 ; idx < array_size_ ; idx += 1)
	    (tmp+idx)->~vvp_object_t();
}

void property_object::set_object(char*buf, const vvp_object_t&val, uint64_t idx)
{
      assert(idx < array_size_);
      vvp_object_t*tmp = reinterpret_cast<vvp_object_t*>(buf+offset_);
      tmp[idx] = val;
}

void property_object::get_vec4(char*buf, vvp_vector4_t&val)
{
      const vvp_object_t*tmp = reinterpret_cast<vvp_object_t*>(buf+offset_);
      vvp_bit4_t bit = tmp[0].test_nil() ? BIT4_0 : BIT4_1;
      val = vvp_vector4_t(1, bit);
}

void property_object::get_object(char*buf, vvp_object_t&val, uint64_t idx)
{
      assert(idx < array_size_);
      const vvp_object_t*tmp = reinterpret_cast<vvp_object_t*>(buf+offset_);
      val = tmp[idx];
}

void property_object::copy(char*dst, char*src)
{
      vvp_object_t*dst_obj = reinterpret_cast<vvp_object_t*>(dst+offset_);
      const vvp_object_t*src_obj = reinterpret_cast<vvp_object_t*>(src+offset_);
      for (size_t idx = 0 ; idx < array_size_ ; idx += 1)
	    dst_obj[idx] = src_obj[idx];
}

void property_cobject::construct(char*buf) const
{
      for (size_t idx = 0 ; idx < array_size_ ; idx += 1) {
	    if (defn_)
		  new (buf+offset_ + idx*sizeof(vvp_object_t)) vvp_object_t(new vvp_cobject(defn_));
	    else
		  new (buf+offset_ + idx*sizeof(vvp_object_t)) vvp_object_t;
      }
}

void property_cobject::destruct(char*buf) const
{
      vvp_object_t*tmp = reinterpret_cast<vvp_object_t*>(buf+offset_);
      for (size_t idx = 0 ; idx < array_size_ ; idx += 1)
	    (tmp+idx)->~vvp_object_t();
}

void property_cobject::set_object(char*buf, const vvp_object_t&val, uint64_t idx)
{
      assert(idx < array_size_);
      vvp_object_t*tmp = reinterpret_cast<vvp_object_t*>(buf+offset_);

      if (!defn_) {
	    tmp[idx] = val;
	    return;
      }

      vvp_cobject*dst_obj = tmp[idx].peek<vvp_cobject>();
      if (!dst_obj || dst_obj->get_defn() != defn_) {
	    tmp[idx] = new vvp_cobject(defn_);
	    dst_obj = tmp[idx].peek<vvp_cobject>();
      }

      if (const vvp_cobject*src_obj = val.peek<vvp_cobject>()) {
	    if (src_obj->get_defn() == defn_) {
		  dst_obj->shallow_copy(src_obj);
		  return;
	    }
      }

      if (val.test_nil()) {
	    tmp[idx] = new vvp_cobject(defn_);
	    return;
      }

      tmp[idx] = val;
}

void property_cobject::get_vec4(char*buf, vvp_vector4_t&val)
{
      const vvp_object_t*tmp = reinterpret_cast<vvp_object_t*>(buf+offset_);
      vvp_bit4_t bit = tmp[0].test_nil() ? BIT4_0 : BIT4_1;
      val = vvp_vector4_t(1, bit);
}

void property_cobject::get_object(char*buf, vvp_object_t&val, uint64_t idx)
{
      assert(idx < array_size_);
      const vvp_object_t*tmp = reinterpret_cast<vvp_object_t*>(buf+offset_);
      val = tmp[idx];
}

void property_cobject::copy(char*dst, char*src)
{
      vvp_object_t*dst_obj = reinterpret_cast<vvp_object_t*>(dst+offset_);
      const vvp_object_t*src_obj = reinterpret_cast<vvp_object_t*>(src+offset_);
      for (size_t idx = 0 ; idx < array_size_ ; idx += 1) {
	    if (!defn_) {
		  dst_obj[idx] = src_obj[idx];
		  continue;
	    }

	    vvp_cobject*dst_cobj = dst_obj[idx].peek<vvp_cobject>();
	    const vvp_cobject*src_cobj = src_obj[idx].peek<vvp_cobject>();
	    if (!dst_cobj || dst_cobj->get_defn() != defn_) {
		  dst_obj[idx] = new vvp_cobject(defn_);
		  dst_cobj = dst_obj[idx].peek<vvp_cobject>();
	    }

	    if (src_cobj && src_cobj->get_defn() == defn_) {
		  dst_cobj->shallow_copy(src_cobj);
	    } else if (src_obj[idx].test_nil()) {
		  dst_obj[idx] = new vvp_cobject(defn_);
	    } else {
		  dst_obj[idx] = src_obj[idx];
	    }
      }
}

/* **** */

class_type::class_type(const string&nam, size_t nprop)
: class_name_(nam), properties_(nprop)
{
      instance_size_ = 0;
}

class_type::~class_type()
{
      for (size_t idx = 0 ; idx < properties_.size() ; idx += 1)
	    delete properties_[idx].type;
}

const string& class_type::property_name(size_t idx) const
{
      static const string empty;
      if (idx >= properties_.size())
	    return empty;
      return properties_[idx].name;
}

bool class_type::property_is_rand(size_t idx) const
{
      if (idx >= properties_.size())
	    return false;
      return properties_[idx].rand_flag;
}

bool class_type::property_is_randc(size_t idx) const
{
      if (idx >= properties_.size())
	    return false;
      return properties_[idx].randc_flag;
}

void class_type::add_constraint(const string&name, const string&ir)
{
      constraint_t c;
      c.name = name;
      c.ir = ir;
      constraints_.push_back(c);
}

const string& class_type::constraint_name(size_t idx) const
{
      return constraints_[idx].name;
}

const string& class_type::constraint_ir(size_t idx) const
{
      return constraints_[idx].ir;
}

void class_type::set_scope_path(const string&path)
{
      scope_path_ = path;
}

void class_type::set_dispatch_prefix(const string&path)
{
      dispatch_prefix_ = path;
}

void class_type::set_super_dispatch_prefix(const string&path)
{
      super_dispatch_prefix_ = path;
}

const class_type* class_type::runtime_super(void) const
{
      if (super_dispatch_prefix_.empty())
            return 0;

      map<string, const class_type*>::const_iterator cur =
            class_types_by_dispatch_prefix_.find(super_dispatch_prefix_);
      if (cur == class_types_by_dispatch_prefix_.end())
            return 0;

      return cur->second;
}

const class_type* class_type_from_dispatch_prefix(const string&prefix)
{
      map<string, const class_type*>::const_iterator cur =
            class_types_by_dispatch_prefix_.find(prefix);
      if (cur == class_types_by_dispatch_prefix_.end())
            return 0;

      return cur->second;
}

void class_type::set_property(size_t idx, const string&name, const string&type, uint64_t array_size)
{
      assert(idx < properties_.size());
      properties_[idx].name = name;

	// Strip rand/randc prefix ("r" or "rc") from the type string.
      string base_type = type;
      if (type.compare(0, 2, "rc") == 0) {
	    properties_[idx].randc_flag = true;
	    properties_[idx].rand_flag  = true;
	    base_type = type.substr(2);
      } else if (type.compare(0, 1, "r") == 0
	         && type.size() > 1 && type[1] != '\0'
	         && type[1] != 'e' && type[1] != 'a') {
	      // Guard against "r" (real) and "rc" already handled above.
	      // The "r" prefix for rand only occurs before 's', 'b', 'L', etc.
	    properties_[idx].rand_flag = true;
	    base_type = type.substr(1);
      }
      const string&type_to_use = base_type;

      const string&t = type_to_use;
      if (t == "b8")
	    properties_[idx].type = new property_atom<uint8_t>(array_size);
      else if (t == "b16")
	    properties_[idx].type = new property_atom<uint16_t>(array_size);
      else if (t == "b32")
	    properties_[idx].type = new property_atom<uint32_t>(array_size);
      else if (t == "b64")
	    properties_[idx].type = new property_atom<uint64_t>(array_size);
      else if (t == "sb8")
	    properties_[idx].type = new property_atom<int8_t>(array_size);
      else if (t == "sb16")
	    properties_[idx].type = new property_atom<int16_t>(array_size);
      else if (t == "sb32")
	    properties_[idx].type = new property_atom<int32_t>(array_size);
      else if (t == "sb64")
	    properties_[idx].type = new property_atom<int64_t>(array_size);
      else if (t == "r")
	    properties_[idx].type = new property_real<double>;
      else if (t == "S")
	    properties_[idx].type = new property_string;
      else if (t == "o")
	    properties_[idx].type = new property_object(array_size);
      else if (t.compare(0,3,"oc:") == 0) {
	    property_cobject*prop = new property_cobject(array_size);
	    compile_vpi_lookup(reinterpret_cast<vpiHandle*>(&prop->defn_),
			       strdup(t.c_str()+3));
	    properties_[idx].type = prop;
      }
      else if (t == "Qr")
	    properties_[idx].type = new property_queue<vvp_queue_real>(array_size);
      else if (t == "QS")
	    properties_[idx].type = new property_queue<vvp_queue_string>(array_size);
      else if (t == "Qv")
	    properties_[idx].type = new property_queue<vvp_queue_vec4>(array_size);
      else if (t == "Qo")
	    properties_[idx].type = new property_queue<vvp_queue_object>(array_size);
      else if (t == "Mr")
	    properties_[idx].type = new property_queue<vvp_assoc_real>(array_size);
      else if (t == "MS")
	    properties_[idx].type = new property_queue<vvp_assoc_string>(array_size);
      else if (t == "Mo")
	    properties_[idx].type = new property_queue<vvp_assoc_object>(array_size);
      else if (t.size() >= 2 && t[0] == 'M' && t[1] == 'v')
	    properties_[idx].type = new property_queue<vvp_assoc_vec4>(array_size);
      else if (t[0] == 'b') {
	    size_t wid = strtoul(t.c_str()+1, 0, 0);
	    properties_[idx].type = new property_bit(wid, array_size);
      } else if (t.size() >= 2 && t[0] == 's' && t[1] == 'b') {
	    size_t wid = strtoul(t.c_str()+2, 0, 0);
	    properties_[idx].type = new property_bit(wid, array_size);
      } else if (t[0] == 'L') {
	    size_t wid = strtoul(t.c_str()+1,0,0);
	    properties_[idx].type = new property_logic(wid, array_size);
      } else if (t.size() >= 2 && t[0] == 's' && t[1] == 'L') {
	    size_t wid = strtoul(t.c_str()+2,0,0);
	    properties_[idx].type = new property_logic(wid, array_size);
      } else {
	    cerr << "Warning: Unknown property type '" << t << "' for property "
	         << idx << " of class " << class_name_ << "; treating as object" << endl;
	    properties_[idx].type = new property_object(array_size? array_size : 1);
      }

      if (properties_[idx].type)
	    properties_[idx].type->describe(class_name_, name, t);
}

void class_type::finish_setup(void)
{
      map<size_t, vector<size_t> > size_map;
	// Add up all the sizes to get a total instance size. This
	// figures out how much memory a complete instance will need.
      size_t accum = 0;
      for (size_t idx = 0 ; idx < properties_.size() ; idx += 1) {
	    assert(properties_[idx].type);
	    size_t instance_size = properties_[idx].type->instance_size();
	    accum += instance_size;
	    size_map[instance_size].push_back(idx);
      }

      instance_size_ = accum;

	// Now allocate the properties to offsets within an instance
	// space. Allocate the properties largest objects first so
	// that they are assured better alignment.
      accum = 0;
      for (map<size_t, vector<size_t> >::reverse_iterator cur = size_map.rbegin()
		 ; cur != size_map.rend() ; ++ cur) {
	    for (size_t idx = 0 ; idx < cur->second.size() ; idx += 1) {
		  size_t pid = cur->second[idx];
		  class_property_t*ptype = properties_[pid].type;
		  assert(ptype->instance_size() == cur->first);
		  ptype->set_offset(accum);
		  accum += cur->first;
	    }
      }
}

class_type::inst_t class_type::instance_new() const
{
      char*buf = new char [instance_size_];

      for (size_t idx = 0 ; idx < properties_.size() ; idx += 1)
	    properties_[idx].type->construct(buf);

      return reinterpret_cast<inst_t> (buf);
}

void class_type::instance_delete(class_type::inst_t obj) const
{
      char*buf = reinterpret_cast<char*> (obj);

      for (size_t idx = 0 ; idx < properties_.size() ; idx += 1)
	    properties_[idx].type->destruct(buf);

      delete[]buf;
}

void class_type::set_vec4(class_type::inst_t obj, size_t pid,
			  const vvp_vector4_t&val, size_t idx) const
{
      char*buf = reinterpret_cast<char*> (obj);
      if (pid >= properties_.size()) {
	    static bool warned = false;
	    if (!warned) {
		  fprintf(stderr, "Warning: class_type::set_vec4 pid=%zu out of range (size=%zu); ignoring write"
		                  " (further similar warnings suppressed)\n", pid, properties_.size());
		  warned = true;
	    }
	    return;
      }
      if (class_trace_enabled_(class_name_)) {
            fprintf(stderr,
                    "trace class: set_vec4 class=%s pid=%zu name=%s idx=%zu obj=%p type=%p\n",
                    class_name_.c_str(), pid, properties_[pid].name.c_str(), idx,
                    obj, properties_[pid].type);
      }
      properties_[pid].type->set_vec4(buf, val, idx);
}

void class_type::get_vec4(class_type::inst_t obj, size_t pid,
			  vvp_vector4_t&val, size_t idx) const
{
      char*buf = reinterpret_cast<char*> (obj);
      if (pid >= properties_.size()) {
	    static bool warned = false;
	    if (!warned) {
		  fprintf(stderr,
		                  "Warning: class_type::get_vec4 class=%s pid=%zu out of range (size=%zu); returning default"
		                  " (further similar warnings suppressed)\n",
		                  class_name_.c_str(), pid, properties_.size());
		  warned = true;
	    }
	    return;
      }
      if (class_trace_enabled_(class_name_)) {
            fprintf(stderr,
                    "trace class: get_vec4 class=%s pid=%zu name=%s idx=%zu obj=%p type=%p\n",
                    class_name_.c_str(), pid, properties_[pid].name.c_str(), idx,
                    obj, properties_[pid].type);
      }
      properties_[pid].type->get_vec4(buf, val, idx);
}

void class_type::set_real(class_type::inst_t obj, size_t pid,
			  double val) const
{
      char*buf = reinterpret_cast<char*> (obj);
      if (pid >= properties_.size()) {
	    static bool warned = false;
	    if (!warned) {
		  fprintf(stderr, "Warning: class_type::set_real pid=%zu out of range (size=%zu); ignoring write"
		                  " (further similar warnings suppressed)\n", pid, properties_.size());
		  warned = true;
	    }
	    return;
      }
      properties_[pid].type->set_real(buf, val);
}

double class_type::get_real(class_type::inst_t obj, size_t pid) const
{
      char*buf = reinterpret_cast<char*> (obj);
      if (pid >= properties_.size()) {
	    static bool warned = false;
	    if (!warned) {
		  fprintf(stderr, "Warning: class_type::get_real pid=%zu out of range (size=%zu); returning 0.0"
		                  " (further similar warnings suppressed)\n", pid, properties_.size());
		  warned = true;
	    }
	    return 0.0;
      }
      return properties_[pid].type->get_real(buf);
}

void class_type::set_string(class_type::inst_t obj, size_t pid,
			    const string&val) const
{
      char*buf = reinterpret_cast<char*> (obj);
      if (pid >= properties_.size()) {
	    static bool warned = false;
	    if (!warned) {
		  fprintf(stderr, "Warning: class_type::set_string pid=%zu out of range (size=%zu); ignoring write"
		                  " (further similar warnings suppressed)\n", pid, properties_.size());
		  warned = true;
	    }
	    return;
      }
      properties_[pid].type->set_string(buf, val);
}

string class_type::get_string(class_type::inst_t obj, size_t pid) const
{
      char*buf = reinterpret_cast<char*> (obj);
      if (pid >= properties_.size()) {
	    static bool warned = false;
	    if (!warned) {
		  fprintf(stderr, "Warning: class_type::get_string pid=%zu out of range (size=%zu); returning empty string"
		                  " (further similar warnings suppressed)\n", pid, properties_.size());
		  warned = true;
	    }
	    return string();
      }
      return properties_[pid].type->get_string(buf);
}

void class_type::set_object(class_type::inst_t obj, size_t pid,
			    const vvp_object_t&val, size_t idx) const
{
      char*buf = reinterpret_cast<char*> (obj);
      if (pid >= properties_.size()) {
	    static bool warned = false;
	    if (!warned) {
		  fprintf(stderr, "Warning: class_type::set_object pid=%zu out of range (size=%zu); ignoring write"
		                  " (further similar warnings suppressed)\n", pid, properties_.size());
		  warned = true;
	    }
	    return;
      }
      if (class_trace_enabled_(class_name_)) {
            const char*value_class = "<nil>";
            if (vvp_cobject*value_obj = val.peek<vvp_cobject>()) {
                  const class_type*value_defn = value_obj->get_defn();
                  if (value_defn)
                        value_class = value_defn->class_name().c_str();
                  else
                        value_class = "<cobject>";
            }
            fprintf(stderr,
                    "trace class: set_object class=%s pid=%zu name=%s idx=%zu obj=%p type=%p value_nil=%d value_class=%s\n",
                    class_name_.c_str(), pid, properties_[pid].name.c_str(), idx,
                    obj, properties_[pid].type, val.test_nil() ? 1 : 0, value_class);
      }
      properties_[pid].type->set_object(buf, val, idx);
}

void class_type::get_object(class_type::inst_t obj, size_t pid,
			    vvp_object_t&val, size_t idx) const
{
      char*buf = reinterpret_cast<char*> (obj);
      if (pid >= properties_.size()) {
	    static bool warned = false;
	    if (!warned) {
		  fprintf(stderr, "Warning: class_type::get_object class=%s pid=%zu out of range (size=%zu); returning null object"
		                  " (further similar warnings suppressed)\n",
		          class_name_.c_str(), pid, properties_.size());
		  warned = true;
	    }
	    val.reset();
	    return;
      }
      properties_[pid].type->get_object(buf, val, idx);
      if (class_trace_enabled_(class_name_)) {
            const char*value_class = "<nil>";
            if (vvp_cobject*value_obj = val.peek<vvp_cobject>()) {
                  const class_type*value_defn = value_obj->get_defn();
                  if (value_defn)
                        value_class = value_defn->class_name().c_str();
                  else
                        value_class = "<cobject>";
            }
            fprintf(stderr,
                    "trace class: get_object class=%s pid=%zu name=%s idx=%zu obj=%p type=%p value_nil=%d value_class=%s\n",
                    class_name_.c_str(), pid, properties_[pid].name.c_str(), idx,
                    obj, properties_[pid].type, val.test_nil() ? 1 : 0, value_class);
      }
}

void class_type::copy_property(class_type::inst_t dst, size_t pid, class_type::inst_t src) const
{
      char*dst_buf = reinterpret_cast<char*> (dst);
      char*src_buf = reinterpret_cast<char*> (src);

      if (pid >= properties_.size()) {
	    static bool warned = false;
	    if (!warned) {
		  fprintf(stderr, "Warning: class_type::copy_property pid=%zu out of range (size=%zu); skipping copy"
		                  " (further similar warnings suppressed)\n", pid, properties_.size());
		  warned = true;
	    }
	    return;
      }

      properties_[pid].type->copy(dst_buf, src_buf);
}

int class_type::get_type_code(void) const
{
      return vpiClassDefn;
}

char* class_type::vpi_get_str(int code)
{
      switch (code) {
          case vpiName:
            return const_cast<char*>(class_name_.c_str());

          case vpiFullName:
            if (scope_path_.empty())
                  return const_cast<char*>(class_name_.c_str());
            else {
                  string full_name = scope_path_ + "." + class_name_;
                  char*rbuf = static_cast<char*>(need_result_buf(full_name.size()+1,
                                                                 RBUF_VAL));
                  strcpy(rbuf, full_name.c_str());
                  return rbuf;
            }

          default:
            return 0;
      }
}

vpiHandle class_type::vpi_handle(int code)
{
      switch (code) {
          case vpiBaseTypespec:
            return const_cast<class_type*>(runtime_super());

          default:
            return 0;
      }
}

static class_type*compile_class = 0;

static string build_scope_path_(__vpiScope*scope)
{
      if (!scope)
            return string();

      vector<const char*> names;
      for (__vpiScope*cur = scope ; cur ; cur = cur->scope)
            names.push_back(cur->scope_name());

      string path;
      for (vector<const char*>::reverse_iterator cur = names.rbegin()
                 ; cur != names.rend() ; ++ cur) {
            const char*name = *cur;
            if (!(name && *name))
                  continue;
            if (!path.empty())
                  path += ".";
            path += name;
      }

      return path;
}

void compile_class_start(char*lab, char*nam, char*dispatch_prefix,
                         char*super_dispatch_prefix, unsigned ntype)
{
      assert(compile_class == 0);
      compile_class = new class_type(nam, ntype);
      if (dispatch_prefix && *dispatch_prefix)
            compile_class->set_dispatch_prefix(dispatch_prefix);
      if (super_dispatch_prefix && *super_dispatch_prefix)
            compile_class->set_super_dispatch_prefix(super_dispatch_prefix);
      compile_vpi_symbol(lab, compile_class);
      free(lab);
      delete[]nam;
      delete[]dispatch_prefix;
      delete[]super_dispatch_prefix;
}

void compile_class_property(unsigned idx, char*nam, char*typ, uint64_t array_size)
{
      assert(compile_class);
      compile_class->set_property(idx, nam, typ, array_size);
      delete[]nam;
      delete[]typ;
}

void compile_class_constraint(char*name, char*ir)
{
      assert(compile_class);
      compile_class->add_constraint(string(name), string(ir));
      delete[]name;
      delete[]ir;
}

void class_type::add_covgrp_bin(unsigned cp_idx, unsigned prop_idx,
				uint64_t lo, uint64_t hi)
{
      cov_bin_t b;
      b.cp_idx   = cp_idx;
      b.prop_idx = prop_idx;
      b.lo       = lo;
      b.hi       = hi;
      covgrp_bins_.push_back(b);
}

void compile_class_covgrp_bin(uint64_t cp_idx, uint64_t prop_idx,
			      uint64_t lo, uint64_t hi)
{
      assert(compile_class);
      compile_class->add_covgrp_bin((unsigned)cp_idx, (unsigned)prop_idx,
				    lo, hi);
}

void compile_class_done(void)
{
      __vpiScope*scope = vpip_peek_current_scope();
      assert(scope);
      assert(compile_class);
      compile_class->set_scope_path(build_scope_path_(scope));
      if (compile_class->dispatch_prefix().empty()) {
            string prefix = compile_class->scope_path();
            if (!prefix.empty())
                  prefix += ".";
            prefix += compile_class->class_name();
            compile_class->set_dispatch_prefix(prefix);
      }
      class_types_by_dispatch_prefix_[compile_class->dispatch_prefix()] = compile_class;
      compile_class->finish_setup();
      scope->classes[compile_class->class_name()] = compile_class;
      compile_class = 0;
}

#ifdef CHECK_WITH_VALGRIND
void class_def_delete(class_type *item)
{
      delete item;
}
#endif
