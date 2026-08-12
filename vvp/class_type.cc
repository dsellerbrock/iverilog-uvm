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
# include  "vvp_net.h"
# include  "vvp_net_sig.h"
# include  "config.h"
# include  <cinttypes>
# include  <cctype>
# include  <cstdlib>
# include  <cstring>
# include  <limits>
# include  <map>
# include  <set>
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

namespace {

static vvp_net_t* static_property_net_(vpiHandle storage)
{
      if (__vpiSignal*sig = dynamic_cast<__vpiSignal*>(storage))
	    return sig->node;
      if (__vpiRealVar*real = dynamic_cast<__vpiRealVar*>(storage))
	    return real->net;
      if (__vpiBaseVar*var = dynamic_cast<__vpiBaseVar*>(storage))
	    return var->get_net();
      return 0;
}

static vvp_signal_value* static_property_signal_value_(vvp_net_t*net)
{
      if (!net)
	    return 0;
      vvp_signal_value*value = dynamic_cast<vvp_signal_value*>(net->fil);
      if (!value)
	    value = dynamic_cast<vvp_signal_value*>(net->fun);
      return value;
}

static vvp_fun_signal_real* static_property_real_fun_(vvp_net_t*net)
{
      if (!net)
	    return 0;
      vvp_fun_signal_real*fun = dynamic_cast<vvp_fun_signal_real*>(net->fun);
      if (!fun)
	    fun = dynamic_cast<vvp_fun_signal_real*>(net->fil);
      return fun;
}

static vvp_fun_signal_string* static_property_string_fun_(vvp_net_t*net)
{
      if (!net)
	    return 0;
      vvp_fun_signal_string*fun = dynamic_cast<vvp_fun_signal_string*>(net->fun);
      if (!fun)
	    fun = dynamic_cast<vvp_fun_signal_string*>(net->fil);
      return fun;
}

static vvp_fun_signal_object* static_property_object_fun_(vvp_net_t*net)
{
      if (!net)
	    return 0;
      vvp_fun_signal_object*fun = dynamic_cast<vvp_fun_signal_object*>(net->fun);
      if (!fun)
	    fun = dynamic_cast<vvp_fun_signal_object*>(net->fil);
      return fun;
}

static bool static_property_uses_object_api_(const string&type)
{
      if (type == "o" || type.compare(0, 3, "oc:") == 0)
	    return true;
      return !type.empty()
	    && (type[0] == 'D' || type[0] == 'Q' || type[0] == 'M');
}

static const char*static_property_expected_kind_(const string&type,
					  bool array)
{
      const char*leaf = type == "r" ? "real"
	    : type == "S" ? "string"
	    : static_property_uses_object_api_(type) ? "object/container"
	    : "integral";
      if (!array)
	    return leaf;
      if (strcmp(leaf, "real") == 0)
	    return "fixed real array";
      if (strcmp(leaf, "string") == 0)
	    return "fixed string array";
      if (strcmp(leaf, "object/container") == 0)
	    return "fixed object/container array";
      return "fixed integral array";
}

static bool static_property_integral_shape_(const string&type,
					     unsigned&width, bool&is_signed)
{
      const char*text = type.c_str();
      is_signed = text[0] == 's';
      if (is_signed)
	    text += 1;
      if (text[0] != 'b' && text[0] != 'L')
	    return false;
      char*end = 0;
      unsigned long parsed = strtoul(text+1, &end, 10);
      if (!end || *end != '\0' || parsed == 0
	  || parsed > numeric_limits<unsigned>::max())
	    return false;
      width = (unsigned)parsed;
      return true;
}

static bool static_property_array_kind_matches_(const __vpiArray*array,
						 const string&type)
{
      if (!array)
	    return false;

      if (type == "r") {
	    if (dynamic_cast<vvp_darray_real*>(array->vals))
		  return true;
	    return array->nets && array->get_size()
		&& dynamic_cast<__vpiRealVar*>(array->nets[0]);
      }
      if (type == "S")
	    return dynamic_cast<vvp_darray_string*>(array->vals) != 0;
      if (static_property_uses_object_api_(type))
	    return dynamic_cast<vvp_darray_object*>(array->vals) != 0;

      if (array->vals4) {
	    unsigned width = 0;
	    bool is_signed = false;
	    return !static_property_integral_shape_(type, width, is_signed)
		|| ((unsigned)array->get_word_size() == width
		    && array->signed_flag == is_signed);
      }
      if (array->vals)
	    {
		  bool integral = !dynamic_cast<vvp_darray_real*>(array->vals)
		&& !dynamic_cast<vvp_darray_string*>(array->vals)
		&& !dynamic_cast<vvp_darray_object*>(array->vals);
		  unsigned width = 0;
		  bool is_signed = false;
		  return integral
			&& (!static_property_integral_shape_(type, width,
						       is_signed)
			    || ((unsigned)array->get_word_size() == width
				&& array->signed_flag == is_signed));
	    }
      return array->nets && array->get_size()
	    && dynamic_cast<__vpiSignal*>(array->nets[0])
	    && ([&]() {
		  unsigned width = 0;
		  bool is_signed = false;
		  __vpiSignal*sig =
			dynamic_cast<__vpiSignal*>(array->nets[0]);
		  return !static_property_integral_shape_(type, width, is_signed)
			|| (vpip_size(sig) == width
			    && (sig->signed_flag != 0) == is_signed);
	    })();
}

static bool static_property_scalar_kind_matches_(vpiHandle storage,
						  const string&type)
{
      if (type == "r")
	    return dynamic_cast<__vpiRealVar*>(storage) != 0;
      if (type == "S")
	    return dynamic_cast<__vpiStringVar*>(storage) != 0;
      if (static_property_uses_object_api_(type))
	    return static_property_object_fun_(static_property_net_(storage)) != 0;
      __vpiSignal*signal = dynamic_cast<__vpiSignal*>(storage);
      if (!signal)
	    return false;
      unsigned width = 0;
      bool is_signed = false;
      return !static_property_integral_shape_(type, width, is_signed)
	    || (vpip_size(signal) == width
		&& (signal->signed_flag != 0) == is_signed);
}

static void static_property_set_vec4_(vpiHandle storage, size_t idx,
				      const vvp_vector4_t&val)
{
      if (__vpiArray*array = dynamic_cast<__vpiArray*>(storage)) {
	    if (idx >= array->get_size())
		  return;

	    unsigned width = (unsigned)array->get_word_size();
	    if (width && width != val.size()) {
		  vvp_vector4_t resized(width, BIT4_0);
		  unsigned count = width < val.size() ? width : val.size();
		  for (unsigned bit = 0; bit < count; bit += 1)
			resized.set_bit(bit, val.value(bit));
		  array->set_word((unsigned)idx, 0, resized);
	    } else {
		  array->set_word((unsigned)idx, 0, val);
	    }
	    return;
      }

      vvp_net_t*net = static_property_net_(storage);
      if (!net)
	    return;

      vvp_signal_value*signal = static_property_signal_value_(net);
      unsigned width = signal ? signal->value_size() : val.size();
      if (width != val.size()) {
	    vvp_vector4_t resized(width, BIT4_0);
	    unsigned count = width < val.size() ? width : val.size();
	    for (unsigned bit = 0; bit < count; bit += 1)
		  resized.set_bit(bit, val.value(bit));
	    vvp_send_vec4(vvp_net_ptr_t(net, 0), resized, 0);
      } else {
	    vvp_send_vec4(vvp_net_ptr_t(net, 0), val, 0);
      }
}

static void static_property_get_vec4_(vpiHandle storage, size_t idx,
				      vvp_vector4_t&val)
{
      if (__vpiArray*array = dynamic_cast<__vpiArray*>(storage)) {
	    val = idx < array->get_size()
		? array->get_word((unsigned)idx) : vvp_vector4_t();
	    return;
      }

      vvp_signal_value*signal =
	    static_property_signal_value_(static_property_net_(storage));
      if (signal)
	    signal->vec4_value(val);
      else
	    val = vvp_vector4_t();
}

static void static_property_set_real_(vpiHandle storage, size_t idx, double val)
{
      if (__vpiArray*array = dynamic_cast<__vpiArray*>(storage)) {
	    if (idx < array->get_size())
		  array->set_word((unsigned)idx, val);
	    return;
      }

      vvp_net_t*net = static_property_net_(storage);
      if (net)
	    vvp_send_real(vvp_net_ptr_t(net, 0), val, 0);
}

static double static_property_get_real_(vpiHandle storage, size_t idx)
{
      if (__vpiArray*array = dynamic_cast<__vpiArray*>(storage))
	    return idx < array->get_size() ? array->get_word_r((unsigned)idx) : 0.0;

      vvp_fun_signal_real*fun =
	    static_property_real_fun_(static_property_net_(storage));
      return fun ? fun->real_unfiltered_value() : 0.0;
}

static void static_property_set_string_(vpiHandle storage, size_t idx,
					const string&val)
{
      if (__vpiArray*array = dynamic_cast<__vpiArray*>(storage)) {
	    if (idx < array->get_size())
		  array->set_word((unsigned)idx, val);
	    return;
      }

      vvp_net_t*net = static_property_net_(storage);
      if (net)
	    vvp_send_string(vvp_net_ptr_t(net, 0), val, 0);
}

static string static_property_get_string_(vpiHandle storage, size_t idx)
{
      if (__vpiArray*array = dynamic_cast<__vpiArray*>(storage))
	    return idx < array->get_size()
		? array->get_word_str((unsigned)idx) : string();

      vvp_fun_signal_string*fun =
	    static_property_string_fun_(static_property_net_(storage));
      return fun ? fun->get_string() : string();
}

static void static_property_set_object_(vpiHandle storage, size_t idx,
					const vvp_object_t&val)
{
      if (__vpiArray*array = dynamic_cast<__vpiArray*>(storage)) {
	    if (idx < array->get_size())
		  array->set_word((unsigned)idx, val);
	    return;
      }

      vvp_net_t*net = static_property_net_(storage);
      if (!net)
	    return;

      vvp_send_object(vvp_net_ptr_t(net, 0), val, 0);
      if (vvp_fun_signal_object*fun = static_property_object_fun_(net))
	    fun->set_root_provenance(net, val, 0);
}

static void static_property_get_object_(vpiHandle storage, size_t idx,
					vvp_object_t&val)
{
      if (__vpiArray*array = dynamic_cast<__vpiArray*>(storage)) {
	    if (idx < array->get_size())
		  array->get_word_obj((unsigned)idx, val);
	    else
		  val.reset();
	    return;
      }

      vvp_fun_signal_object*fun =
	    static_property_object_fun_(static_property_net_(storage));
      if (fun)
	    val = fun->get_object();
      else
	    val.reset();
}

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
      virtual void set_real(char*buf, double val, uint64_t idx);
      virtual double get_real(char*buf, uint64_t idx);

      virtual void set_string(char*buf, const std::string&val);
      virtual string get_string(char*buf);
      virtual void set_string(char*buf, const std::string&val, uint64_t idx);
      virtual string get_string(char*buf, uint64_t idx);

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
	// A rand QUEUE property's `.size() == N` constraint reaches here:
	// unlike a rand dynamic array (whose solved size resizes the
	// vvp_darray directly through a container-aware path), a queue has
	// no analogous resize hookup, so the solver's attempt to apply the
	// solved size lands on this generic "no write" fallback and the
	// queue is left empty. Name that specific limitation instead of
	// the generic message when this fires on a queue-coded property
	// (SORRY: rand queue .size() constraints are not implemented --
	// mirroring the working darray-size-constraint path, which is
	// solver-side vvp_z3.cc territory, is the way to close this).
      if (!type_name_.empty()
	  && type_name_.find('Q') != std::string::npos) {
	    static bool warned_queue_size = false;
	    if (!warned_queue_size) {
		  fprintf(stderr,
			  "Warning: sorry: rand queue '.size()' constraints are "
			  "not implemented (class=%s property=%s type=%s); the "
			  "queue is left empty instead of being sized/filled "
			  "(further similar warnings suppressed)\n",
			  owner_class_.empty() ? "<unknown>" : owner_class_.c_str(),
			  prop_name_.empty() ? "<unknown>" : prop_name_.c_str(),
			  type_name_.c_str());
		  warned_queue_size = true;
	    }
	    return;
      }

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

void class_property_t::set_real(char*buf, double val, uint64_t)
{
      set_real(buf, val);
}

double class_property_t::get_real(char*buf, uint64_t)
{
      return get_real(buf);
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

void class_property_t::set_string(char*buf, const string&val, uint64_t)
{
      set_string(buf, val);
}

string class_property_t::get_string(char*buf, uint64_t)
{
      return get_string(buf);
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

      // G49: integer properties use get_vec4; get_object returns null silently.
      void get_object(char*, vvp_object_t&, uint64_t) override {}

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

      void get_object(char*, vvp_object_t&, uint64_t) override {}

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

      void get_object(char*, vvp_object_t&, uint64_t) override {}

      void copy(char*dst, char*src) override;

    private:
      size_t wid_;
      size_t array_size_;
};

template <class T> class property_real : public class_property_t {
    public:
      inline explicit property_real(size_t as=0) : array_size_(as==0? 1 : as) { }
      ~property_real() override { }

      size_t instance_size() const override { return array_size_ * sizeof(T); }

    public:
      void construct(char*buf) const override
      { T*tmp = reinterpret_cast<T*> (buf+offset_);
	for (size_t ii = 0 ; ii < array_size_ ; ii += 1)
	      tmp[ii] = 0.0;
      }

      void set_real(char*buf, double val) override;
      double get_real(char*buf) override;
      void set_real(char*buf, double val, uint64_t idx) override;
      double get_real(char*buf, uint64_t idx) override;

      void copy(char*dst, char*src) override;

    private:
      size_t array_size_;
};

class property_string : public class_property_t {
    public:
      inline explicit property_string(size_t as=0) : array_size_(as==0? 1 : as) { }
      ~property_string() override { }

      size_t instance_size() const override { return array_size_ * sizeof(std::string); }

    public:
      void construct(char*buf) const override
      { for (size_t ii = 0 ; ii < array_size_ ; ii += 1)
	      new (buf+offset_ + ii*sizeof(string)) string;
      }

      void destruct(char*buf) const override
      { string*tmp = reinterpret_cast<string*> (buf+offset_);
	for (size_t ii = 0 ; ii < array_size_ ; ii += 1)
	      (tmp+ii)->~string();
      }

      void set_string(char*buf, const string&) override;
      string get_string(char*buf) override;
      void set_string(char*buf, const string&, uint64_t idx) override;
      string get_string(char*buf, uint64_t idx) override;

      void copy(char*dst, char*src) override;

    private:
      size_t array_size_;
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

/* A dynamic-array property is a VALUE (IEEE 1800-2017 7.5): copying
   the enclosing object must copy the container, not alias it
   (recovery D2). Storage-wise identical to property_object -- the slot
   starts nil (a darray is null until new[n]) -- only copy() differs. */
class property_darray : public property_object {
    public:
      inline explicit property_darray(uint64_t as)
      : property_object(as), array_size_(as==0? 1 : as) { }

      void copy(char*dst, char*src) override
      {
	    vvp_object_t*dst_obj = reinterpret_cast<vvp_object_t*>(dst+offset_);
	    const vvp_object_t*src_obj = reinterpret_cast<vvp_object_t*>(src+offset_);
	    for (size_t idx = 0 ; idx < array_size_ ; idx += 1) {
		  if (src_obj[idx].test_nil())
			dst_obj[idx].reset();
		  else if (src_obj[idx].peek<vvp_darray>())
			dst_obj[idx] = src_obj[idx].duplicate();
		  else
			dst_obj[idx] = src_obj[idx];
	    }
      }

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

template <class T> void property_real<T>::set_real(char*buf, double val, uint64_t idx)
{
      assert(idx < array_size_);
      T*tmp = reinterpret_cast<T*>(buf+offset_);
      tmp[idx] = val;
}

template <class T> double property_real<T>::get_real(char*buf, uint64_t idx)
{
      assert(idx < array_size_);
      T*tmp = reinterpret_cast<T*>(buf+offset_);
      return tmp[idx];
}

template <class T> void property_real<T>::copy(char*dst, char*src)
{
      T*dst_obj = reinterpret_cast<T*> (dst+offset_);
      T*src_obj = reinterpret_cast<T*> (src+offset_);
      for (size_t ii = 0 ; ii < array_size_ ; ii += 1)
	    dst_obj[ii] = src_obj[ii];
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

void property_string::set_string(char*buf, const string&val, uint64_t idx)
{
      assert(idx < array_size_);
      string*tmp = reinterpret_cast<string*>(buf+offset_);
      tmp[idx] = val;
}

string property_string::get_string(char*buf, uint64_t idx)
{
      assert(idx < array_size_);
      const string*tmp = reinterpret_cast<string*>(buf+offset_);
      return tmp[idx];
}

void property_string::copy(char*dst, char*src)
{
      string*dst_obj = reinterpret_cast<string*> (dst+offset_);
      const string*src_obj = reinterpret_cast<string*> (src+offset_);
      for (size_t ii = 0 ; ii < array_size_ ; ii += 1)
	    dst_obj[ii] = src_obj[ii];
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
: class_name_(nam), properties_(nprop), static_properties_(nprop, 0)
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

bool class_type::property_is_static(size_t idx) const
{
      return idx < properties_.size() && (properties_[idx].qualifier & 1);
}

void class_type::bind_static_property(size_t idx, char*storage)
{
      assert(idx < properties_.size());
      assert(property_is_static(idx));

	// draw_class_in_scope may emit the same runtime class record more than
	// once. Intern by the canonical declaring-signal label so every such
	// class_type -- and every inherited record that names that signal --
	// points at one VALUE+mode cell instead of splitting static state.
      static map<string, static_property_cell_t*> cells_by_storage;
      pair<map<string, static_property_cell_t*>::iterator,bool> inserted =
	    cells_by_storage.insert(make_pair(string(storage),
					      (static_property_cell_t*)0));
      if (inserted.second) {
	    inserted.first->second = new static_property_cell_t;
	    inserted.first->second->storage_label = storage;
	    compile_vpi_lookup(&inserted.first->second->storage, storage);
      } else {
	    free(storage);
      }
      static_properties_[idx] = inserted.first->second;
}

class_type::static_property_cell_t*
class_type::static_property_cell_(size_t idx) const
{
      if (idx >= properties_.size())
	    return 0;

      const class_type*super = runtime_super();
      if (super && idx < super->property_count())
	    return super->static_property_cell_(idx);

      if (!property_is_static(idx))
	    return 0;
      return static_properties_[idx];
}

vpiHandle class_type::static_property_storage_(size_t idx) const
{
      static_property_cell_t*cell = static_property_cell_(idx);
	const prop_t*prop = idx < properties_.size() ? &properties_[idx] : 0;
	__vpiArray*array = cell && cell->storage
	      ? dynamic_cast<__vpiArray*>(cell->storage) : 0;
	bool wants_array = prop && !prop->dimensions.empty();
	bool valid_storage = cell && cell->storage && prop;
	if (valid_storage && wants_array)
	      valid_storage = array
		&& array->get_size() == prop->array_size
		&& static_property_array_kind_matches_(array, prop->base_type);
	else if (valid_storage)
	      valid_storage = !array && static_property_net_(cell->storage)
		&& static_property_scalar_kind_matches_(cell->storage,
						       prop->base_type);
      if (!valid_storage) {
	    const char*name = idx < properties_.size()
		  ? properties_[idx].name.c_str() : "<out-of-range>";
	    const char*label = cell && !cell->storage_label.empty()
		  ? cell->storage_label.c_str() : "<unbound>";
	    int type_code = cell && cell->storage
		  ? cell->storage->get_type_code() : vpiUndefined;
	    const char*expected = prop
		  ? static_property_expected_kind_(prop->base_type, wants_array)
		  : "valid property";
	    fprintf(stderr,
		    "internal error: invalid canonical static class storage"
		    " (class=%s pid=%zu name=%s label=%s base_type=%s"
		    " expected=%s vpi_type=%d)\n",
		    class_name_.c_str(), idx, name, label,
		    prop ? prop->base_type.c_str() : "<none>", expected,
		    type_code);
	    abort();
      }
      return cell->storage;
}

vpiHandle class_type::static_property_storage(size_t idx) const
{
      return static_property_storage_(idx);
}

unsigned class_type::property_qualifier(size_t idx) const
{
      return idx < properties_.size() ? properties_[idx].qualifier : 0;
}

bool class_type::static_rand_mode(size_t idx) const
{
      if (!property_is_static(idx))
	    return true;
      uint64_t count = property_array_size(idx);
      if (count < 1) count = 1;
      for (uint64_t leaf = 0 ; leaf < count ; leaf += 1)
	    if (!static_rand_mode(idx, (size_t)leaf)) return false;
      return true;
}

bool class_type::static_rand_mode(size_t idx, size_t leaf) const
{
      if (!property_is_static(idx))
	    return true;
      (void)static_property_storage_(idx);
      static_property_cell_t*cell = static_property_cell_(idx);
      uint64_t count = property_array_size(idx);
      if (count < 1) count = 1;
      if (leaf >= count) return false;
      std::map<size_t, bool>::const_iterator it =
	    cell->rand_mode_leaves.find(leaf);
      return it == cell->rand_mode_leaves.end() ? cell->rand_mode
	                                           : it->second;
}

bool class_type::static_rand_mode_any(size_t idx) const
{
      if (!property_is_static(idx))
	    return true;
      uint64_t count = property_array_size(idx);
      if (count < 1) count = 1;
      for (uint64_t leaf = 0 ; leaf < count ; leaf += 1)
	    if (static_rand_mode(idx, (size_t)leaf)) return true;
      return false;
}

void class_type::set_static_rand_mode(size_t idx, bool mode) const
{
      if (!property_is_static(idx))
	    return;
      (void)static_property_storage_(idx);
      static_property_cell_t*cell = static_property_cell_(idx);
      cell->rand_mode = mode;
      cell->rand_mode_leaves.clear();
}

void class_type::set_static_rand_mode(size_t idx, size_t leaf,
				       bool mode) const
{
      if (!property_is_static(idx))
	    return;
      (void)static_property_storage_(idx);
      static_property_cell_t*cell = static_property_cell_(idx);
      uint64_t count = property_array_size(idx);
      if (count < 1) count = 1;
      if (leaf >= count) return;
      if (mode == cell->rand_mode)
	    cell->rand_mode_leaves.erase(leaf);
      else
	    cell->rand_mode_leaves[leaf] = mode;
}

std::vector<bool>&class_type::static_randc_history(size_t idx,
						    size_t leaf) const
{
	// Reuse the storage validator here. A randc history attached to an
	// unresolved or wrongly-typed static property would otherwise create
	// a second, invisible state bank and make receiver-dependent cycles.
      (void)static_property_storage_(idx);
      static_property_cell_t*cell = static_property_cell_(idx);
      assert(cell);
      return cell->randc_history[leaf];
}

bool class_type::static_randomize_transaction_begin(size_t idx) const
{
      if (!property_is_static(idx)) return false;
      vpiHandle storage = static_property_storage_(idx);
      static_property_cell_t*cell = static_property_cell_(idx);
      assert(cell);
      if (cell->randomize_transaction_active) return false;

      cell->randomize_vec4.clear();
      cell->randomize_real.clear();
      cell->randomize_string.clear();
      cell->randomize_object.clear();
      cell->randomize_dirty.clear();
      uint64_t count = property_array_size(idx);
      if (count < 1) count = 1;
      const string&type = property_base_type(idx);
      for (uint64_t leaf = 0 ; leaf < count ; leaf += 1) {
	    if (type == "r") {
		  cell->randomize_real[(size_t)leaf] =
			static_property_get_real_(storage, (size_t)leaf);
	    } else if (type == "S") {
		  cell->randomize_string[(size_t)leaf] =
			static_property_get_string_(storage, (size_t)leaf);
	    } else if (static_property_uses_object_api_(type)) {
		  vvp_object_t value;
		  static_property_get_object_(storage, (size_t)leaf, value);
		  cell->randomize_object[(size_t)leaf] =
			value.value_copy_element();
	    } else {
		  vvp_vector4_t value;
		  static_property_get_vec4_(storage, (size_t)leaf, value);
		  cell->randomize_vec4[(size_t)leaf] = value;
	    }
      }
      cell->randomize_transaction_active = true;
      return true;
}

void class_type::static_randomize_transaction_mark_dirty(size_t idx,
						   size_t leaf) const
{
      static_property_cell_t*cell = static_property_cell_(idx);
      if (cell && cell->randomize_transaction_active)
	    cell->randomize_dirty.insert(leaf);
}

void class_type::static_randomize_transaction_commit(size_t idx) const
{
      static_property_cell_t*cell = static_property_cell_(idx);
      if (!cell || !cell->randomize_transaction_active) return;
      vpiHandle storage = static_property_storage_(idx);
      for (const auto&value : cell->randomize_vec4)
	    if (cell->randomize_dirty.count(value.first))
		  static_property_set_vec4_(storage, value.first, value.second);
      for (const auto&value : cell->randomize_real)
	    if (cell->randomize_dirty.count(value.first))
		  static_property_set_real_(storage, value.first, value.second);
      for (const auto&value : cell->randomize_string)
	    if (cell->randomize_dirty.count(value.first))
		  static_property_set_string_(storage, value.first, value.second);
      for (const auto&value : cell->randomize_object)
	    if (cell->randomize_dirty.count(value.first))
		  static_property_set_object_(storage, value.first, value.second);
      cell->randomize_transaction_active = false;
      cell->randomize_vec4.clear();
      cell->randomize_real.clear();
      cell->randomize_string.clear();
      cell->randomize_object.clear();
      cell->randomize_dirty.clear();
}

void class_type::static_randomize_transaction_rollback(size_t idx) const
{
      static_property_cell_t*cell = static_property_cell_(idx);
      if (!cell || !cell->randomize_transaction_active) return;
      cell->randomize_transaction_active = false;
      cell->randomize_vec4.clear();
      cell->randomize_real.clear();
      cell->randomize_string.clear();
      cell->randomize_object.clear();
      cell->randomize_dirty.clear();
}

const std::string& class_type::property_base_type(size_t idx) const
{
      static const std::string nil;
      if (idx >= properties_.size())
	    return nil;
      return properties_[idx].base_type;
}

const class_type*class_type::property_declared_class_type(size_t idx) const
{
      if (idx >= properties_.size())
	    return 0;
      return dynamic_cast<class_type*>(properties_[idx].declared_class_type);
}

uint64_t class_type::property_array_size(size_t idx) const
{
      if (idx >= properties_.size())
	    return 1;
      return properties_[idx].array_size;
}

const vector<pair<int,int> >& class_type::property_dimensions(size_t idx) const
{
      static const vector<pair<int,int> > nil;
      if (idx >= properties_.size())
	    return nil;
      return properties_[idx].dimensions;
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

void class_type::set_property(size_t idx, const string&name, const string&type,
                             const vector<pair<int,int> >&dimensions)
{
      assert(idx < properties_.size());
      properties_[idx].name = name;

	// New class records wrap the historical type code in q<hex>: so all
	// property qualifiers survive target export without changing the .class
	// grammar. Old records have no wrapper and continue to decode below.
      string encoded_type = type;
      unsigned qualifier = 0;
      if (encoded_type.size() > 2 && encoded_type[0] == 'q') {
	    string::size_type colon = encoded_type.find(':', 1);
	    if (colon != string::npos) {
		  string text = encoded_type.substr(1, colon - 1);
		  char*end = 0;
		  unsigned long parsed = strtoul(text.c_str(), &end, 16);
		  if (end && *end == '\0') {
			qualifier = (unsigned)parsed;
			encoded_type.erase(0, colon + 1);
		  }
	    }
      }
      properties_[idx].qualifier = qualifier;
      properties_[idx].randc_flag = (qualifier & 16) != 0;
      properties_[idx].rand_flag = (qualifier & (8 | 16)) != 0;

      uint64_t array_size = 1;
      for (const pair<int,int>&range : dimensions) {
	    uint64_t count = range.first > range.second
			   ? (uint64_t)(range.first - range.second) + 1
			   : (uint64_t)(range.second - range.first) + 1;
	    array_size *= count;
      }

	// Strip rand/randc prefix ("r" or "rc") from the type string.
      string base_type = encoded_type;
      if (encoded_type.compare(0, 2, "rc") == 0) {
	    properties_[idx].randc_flag = true;
	    properties_[idx].rand_flag  = true;
	    properties_[idx].qualifier |= 16;
	    base_type = encoded_type.substr(2);
      } else if (encoded_type.compare(0, 1, "r") == 0
	         && encoded_type.size() > 1 && encoded_type[1] != '\0'
	         && encoded_type[1] != 'e' && encoded_type[1] != 'a') {
	      // Guard against "r" (real) and "rc" already handled above.
	      // The "r" prefix for rand only occurs before 's', 'b', 'L', etc.
	    properties_[idx].rand_flag = true;
	    properties_[idx].qualifier |= 8;
	    base_type = encoded_type.substr(1);
      }
	/* `oh:C<label>` is an ordinary class handle with additional declared
	 * class metadata. Resolve the metadata separately, then normalize the
	 * storage type to historical `o` so property_object reference semantics
	 * and existing randomization/value paths remain unchanged. */
      if (base_type.compare(0, 3, "oh:") == 0) {
	    compile_vpi_lookup(&properties_[idx].declared_class_type,
			       strdup(base_type.c_str()+3));
	    base_type = "o";
      }
      const string&type_to_use = base_type;

      properties_[idx].base_type = base_type;
      properties_[idx].array_size = array_size;
      properties_[idx].dimensions = dimensions;

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
	    properties_[idx].type = new property_real<double>(array_size);
      else if (t == "S")
	    properties_[idx].type = new property_string(array_size);
      else if (t == "o")
	    properties_[idx].type = new property_object(array_size);
      else if (t.compare(0,3,"oc:") == 0) {
	    compile_vpi_lookup(&properties_[idx].declared_class_type,
			       strdup(t.c_str()+3));
	    property_cobject*prop = new property_cobject(array_size);
	    compile_vpi_lookup(reinterpret_cast<vpiHandle*>(&prop->defn_),
			       strdup(t.c_str()+3));
	    properties_[idx].type = prop;
      }
      else if (!t.empty() && t[0] == 'D')
	    properties_[idx].type = new property_darray(array_size);
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
      if (property_is_static(pid)) {
	    static_property_cell_t*cell = static_property_cell_(pid);
	    if (cell && cell->randomize_transaction_active) {
		  cell->randomize_vec4[idx] = val;
		  cell->randomize_dirty.insert(idx);
		  return;
	    }
	    static_property_set_vec4_(static_property_storage_(pid), idx, val);
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
      if (property_is_static(pid)) {
	    static_property_cell_t*cell = static_property_cell_(pid);
	    if (cell && cell->randomize_transaction_active) {
		  std::map<size_t, vvp_vector4_t>::const_iterator it =
			cell->randomize_vec4.find(idx);
		  val = it == cell->randomize_vec4.end()
			? vvp_vector4_t() : it->second;
		  return;
	    }
	    static_property_get_vec4_(static_property_storage_(pid), idx, val);
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
			  double val, size_t idx) const
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
      if (property_is_static(pid)) {
	    static_property_cell_t*cell = static_property_cell_(pid);
	    if (cell && cell->randomize_transaction_active) {
		  cell->randomize_real[idx] = val;
		  cell->randomize_dirty.insert(idx);
		  return;
	    }
	    static_property_set_real_(static_property_storage_(pid), idx, val);
	    return;
      }
      properties_[pid].type->set_real(buf, val, idx);
}

double class_type::get_real(class_type::inst_t obj, size_t pid, size_t idx) const
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
      if (property_is_static(pid)) {
	    static_property_cell_t*cell = static_property_cell_(pid);
	    if (cell && cell->randomize_transaction_active) {
		  std::map<size_t, double>::const_iterator it =
			cell->randomize_real.find(idx);
		  return it == cell->randomize_real.end() ? 0.0 : it->second;
	    }
	    return static_property_get_real_(static_property_storage_(pid), idx);
      }
      return properties_[pid].type->get_real(buf, idx);
}

void class_type::set_string(class_type::inst_t obj, size_t pid,
			    const string&val, size_t idx) const
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
      if (property_is_static(pid)) {
	    static_property_cell_t*cell = static_property_cell_(pid);
	    if (cell && cell->randomize_transaction_active) {
		  cell->randomize_string[idx] = val;
		  cell->randomize_dirty.insert(idx);
		  return;
	    }
	    static_property_set_string_(static_property_storage_(pid), idx, val);
	    return;
      }
      properties_[pid].type->set_string(buf, val, idx);
}

string class_type::get_string(class_type::inst_t obj, size_t pid, size_t idx) const
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
      if (property_is_static(pid)) {
	    static_property_cell_t*cell = static_property_cell_(pid);
	    if (cell && cell->randomize_transaction_active) {
		  std::map<size_t, string>::const_iterator it =
			cell->randomize_string.find(idx);
		  return it == cell->randomize_string.end() ? string()
							 : it->second;
	    }
	    return static_property_get_string_(static_property_storage_(pid), idx);
      }
      return properties_[pid].type->get_string(buf, idx);
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
      if (property_is_static(pid)) {
	    if (static_property_uses_object_api_(properties_[pid].base_type)) {
		  static_property_cell_t*cell = static_property_cell_(pid);
		  if (cell && cell->randomize_transaction_active) {
			cell->randomize_object[idx] = val;
			cell->randomize_dirty.insert(idx);
		  } else
			static_property_set_object_(static_property_storage_(pid),
						    idx, val);
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
      if (property_is_static(pid)) {
	    if (static_property_uses_object_api_(properties_[pid].base_type)) {
		  static_property_cell_t*cell = static_property_cell_(pid);
		  if (cell && cell->randomize_transaction_active) {
			std::map<size_t, vvp_object_t>::const_iterator it =
			      cell->randomize_object.find(idx);
			if (it == cell->randomize_object.end()) val.reset();
			else val = it->second;
		  } else {
			static_property_get_object_(static_property_storage_(pid),
						    idx, val);
		  }
	    } else {
		  val.reset();
	    }
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

	// Static state belongs to the declaring class-scope signal. A class
	// handle copy must not copy (or overwrite) that shared value through
	// either object's otherwise-unused instance slot.
      if (property_is_static(pid))
	    return;

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

	    // The dispatch prefix uniquely identifies a class definition,
	    // including a distinct entry for each specialization of a
	    // parameterized class. Unlike vpiName (which is the bare class
	    // name, identical across specializations) and vpiFullName (which
	    // varies with the scope the specialization is referenced from),
	    // the dispatch prefix is a stable, one-per-specialization key.
	    // Expose it through vpiDefName so run-time type checks ($cast)
	    // can distinguish Box#(byte) from Box#(shortint).
          case vpiDefName:
            if (dispatch_prefix_.empty())
                  return const_cast<char*>(class_name_.c_str());
            return const_cast<char*>(dispatch_prefix_.c_str());

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

void compile_class_mark_struct(void)
{
      assert(compile_class);
      compile_class->set_struct_type();
}

void compile_class_property(unsigned idx, char*nam, char*typ,
                            vector<pair<int,int> >*dimensions)
{
      assert(compile_class);
      static const vector<pair<int,int> > no_dimensions;
	compile_class->set_property(idx, nam, typ,
				  dimensions ? *dimensions : no_dimensions);
      delete dimensions;
      delete[]nam;
      delete[]typ;
}

void compile_class_static_property(unsigned idx, char*storage)
{
      assert(compile_class);
      compile_class->bind_static_property(idx, storage);
}

void compile_class_constraint(char*name, char*ir)
{
      assert(compile_class);
      compile_class->add_constraint(string(name), string(ir));
      delete[]name;
      delete[]ir;
}

void class_type::add_covgrp_bin(unsigned cp_idx, unsigned prop_idx,
				uint64_t lo, uint64_t hi, unsigned kind,
				unsigned tuple, unsigned item_idx)
{
      cov_bin_t b;
      b.cp_idx   = cp_idx;
      b.prop_idx = prop_idx;
      b.lo       = lo;
      b.hi       = hi;
      b.kind     = kind;
      b.tuple    = tuple;
      b.item_idx = item_idx;
      covgrp_bins_.push_back(b);
}

void compile_class_covgrp_bin(uint64_t cp_idx, uint64_t prop_idx,
			      uint64_t lo, uint64_t hi, uint64_t kind,
			      uint64_t tuple, uint64_t item_idx)
{
      assert(compile_class);
      compile_class->add_covgrp_bin((unsigned)cp_idx, (unsigned)prop_idx,
				    lo, hi, (unsigned)kind,
				    (unsigned)tuple, (unsigned)item_idx);
}

void compile_class_covgrp_dyn_bin(uint64_t cp_idx, uint64_t item_idx,
				  uint64_t kind, uint64_t family,
				  uint64_t array_size, char*name,
				  char*lo_ir, char*hi_ir)
{
      assert(compile_class);
      compile_class->add_covgrp_dyn_bin((unsigned)cp_idx, (unsigned)item_idx,
					(unsigned)kind, (unsigned)family,
					array_size, name ? name : "",
					lo_ir ? lo_ir : "", hi_ir ? hi_ir : "");
      free(name);
      free(lo_ir);
      free(hi_ir);
}

void compile_class_covgrp_item(uint64_t at_least, uint64_t weight,
			       uint64_t is_cross, char*name, char*weight_ir,
			       uint64_t guardsrc)
{
      assert(compile_class);
      compile_class->add_covgrp_item((unsigned)at_least, (unsigned)weight,
			     is_cross != 0,
			     name ? std::string(name) : std::string(),
			     weight_ir ? std::string(weight_ir) : std::string(),
			     guardsrc ? (int)guardsrc - 1 : -1);
      free(name);
      free(weight_ir);
}

/* M11-3: event-driven sampling metadata. The .covgrp_src property
 * indexes arrive biased by +1 (0 = none) because the vvp lexer only
 * accepts unsigned numbers. */
void compile_class_covgrp_parent(uint64_t prop)
{
      assert(compile_class);
      compile_class->set_covgrp_parent_prop((int)prop);
}

void compile_class_covgrp_src(uint64_t srcprop, uint64_t guardsrc)
{
      assert(compile_class);
      compile_class->add_covgrp_src((int)srcprop - 1, (int)guardsrc - 1);
}

/* M11: type-level (merged) coverage counters and registry. */

void class_type::type_bump(unsigned prop) const
{
      if (prop >= type_counts_.size())
	    type_counts_.resize(prop + 1, 0);
      type_counts_[prop] += 1;
}

/* Evaluate the deliberately small arithmetic subset used by dynamic
 * covergroup options and bounds.  The compiler emits the same prefix IR as
 * class constraints: c:V atoms, p:PID:WIDTH property atoms, and parenthesized
 * arithmetic.  Keeping this evaluator independent of Z3 is important: a
 * coverage sample must be cheap and must also work in builds without the
 * optional solver. */
class covgrp_ir_eval_t {
    public:
      covgrp_ir_eval_t(const string&text, vvp_cobject*obj)
      : text_(text), obj_(obj), pos_(0) { }

      bool eval(uint64_t&out)
      {
	    if (!expr_(out)) return false;
	    skip_();
	    return pos_ == text_.size();
      }

    private:
      void skip_()
      {
	    while (pos_ < text_.size()
		   && isspace(static_cast<unsigned char>(text_[pos_])))
		  pos_ += 1;
      }

      string atom_()
      {
	    skip_();
	    size_t begin = pos_;
	    while (pos_ < text_.size() && text_[pos_] != ')'
		   && !isspace(static_cast<unsigned char>(text_[pos_])))
		  pos_ += 1;
	    return text_.substr(begin, pos_ - begin);
      }

      bool expr_(uint64_t&out)
      {
	    skip_();
	    if (pos_ >= text_.size()) return false;
	    if (text_[pos_] != '(') {
		  string tok = atom_();
		  if (tok.compare(0, 2, "c:") == 0) {
			char*end = 0;
			out = strtoull(tok.c_str() + 2, &end, 10);
			return end != tok.c_str() + 2;
		  }
		  if (tok.compare(0, 2, "p:") == 0 && obj_) {
			char*end = 0;
			uint64_t pid = strtoull(tok.c_str() + 2, &end, 10);
			if (end == tok.c_str() + 2 || *end != ':') return false;
			vvp_vector4_t val;
			obj_->get_vec4((size_t)pid, val);
			out = 0;
			for (unsigned bit = 0; bit < val.size() && bit < 64; bit += 1)
			      if (val.value(bit) == BIT4_1)
				    out |= (uint64_t)1 << bit;
			return true;
		  }
		  return false;
	    }

	    pos_ += 1;
	    string op = atom_();
	    uint64_t a = 0, b = 0, c = 0;
	    if (!expr_(a)) return false;
	    bool unary = op == "not" || op == "bnot" || op == "redand"
		       || op == "redor" || op == "redxor";
	    if (!unary && !expr_(b)) return false;
	    if (op == "ite" && !expr_(c)) return false;
	    skip_();
	    if (pos_ >= text_.size() || text_[pos_] != ')') return false;
	    pos_ += 1;

	    if (op == "add") out = a + b;
	    else if (op == "sub") out = a - b;
	    else if (op == "mul") out = a * b;
	    else if (op == "div") out = b ? a / b : 0;
	    else if (op == "mod") out = b ? a % b : 0;
	    else if (op == "band") out = a & b;
	    else if (op == "bor") out = a | b;
	    else if (op == "bxor") out = a ^ b;
	    else if (op == "shl") out = b < 64 ? a << b : 0;
	    else if (op == "lshr") out = b < 64 ? a >> b : 0;
	    else if (op == "ashr")
		  out = b < 64 ? (uint64_t)((int64_t)a >> b)
			       : ((int64_t)a < 0 ? ~(uint64_t)0 : 0);
	    else if (op == "eq") out = a == b;
	    else if (op == "ne") out = a != b;
	    else if (op == "lt") out = a < b;
	    else if (op == "le") out = a <= b;
	    else if (op == "gt") out = a > b;
	    else if (op == "ge") out = a >= b;
	    else if (op == "and") out = (a != 0) && (b != 0);
	    else if (op == "or") out = (a != 0) || (b != 0);
	    else if (op == "impl") out = (a == 0) || (b != 0);
	    else if (op == "iff") out = (a != 0) == (b != 0);
	    else if (op == "not") out = a == 0;
	    else if (op == "bnot") out = ~a;
	    else if (op == "redand") out = a == ~(uint64_t)0;
	    else if (op == "redor") out = a != 0;
	    else if (op == "redxor") {
		  out = 0;
		  while (a) { out ^= 1; a &= a - 1; }
	    } else if (op == "ite") out = a ? b : c;
	    else return false;
	    return true;
      }

      const string&text_;
      vvp_cobject*obj_;
      size_t pos_;
};

unsigned class_type::covgrp_item_weight(vvp_cobject*obj, size_t idx) const
{
      if (idx >= covgrp_items_.size()) return 1;
      const cov_item_t&item = covgrp_items_[idx];
      if (item.weight_ir.empty()) return item.weight;
      uint64_t val = item.weight;
      if (!covgrp_ir_eval_t(item.weight_ir, obj).eval(val))
	    return item.weight;
      if (val > numeric_limits<unsigned>::max())
	    return numeric_limits<unsigned>::max();
      return (unsigned)val;
}

bool class_type::covgrp_eval_ir(vvp_cobject*obj, const string&ir,
				uint64_t&value) const
{
      return covgrp_ir_eval_t(ir, obj).eval(value);
}

uint32_t class_type::type_count(unsigned prop) const
{
      if (prop >= type_counts_.size())
	    return 0;
      return type_counts_[prop];
}

double class_type::type_coverage(vvp_cobject*context) const
{
	// Same per-item weighted model as instance coverage, computed
	// over the type-level counters.
      std::map<unsigned, std::set<unsigned>> item_props;
      for (size_t bi = 0 ; bi < covgrp_bins_.size() ; bi += 1) {
	    const cov_bin_t&bin = covgrp_bins_[bi];
	    unsigned k = bin.kind & 7;
	    if (k == 1 || k == 2 || k == 3 || k == 5 || k == 6) continue;
	    if (bin.prop_idx == COV_NO_PROP) continue;
	    item_props[bin.item_idx].insert(bin.prop_idx);
      }
      double wsum = 0.0, wcov = 0.0;
      for (auto&ip : item_props) {
	    unsigned at_least = 1, weight = 1;
	    if (ip.first < covgrp_items_.size()) {
		  at_least = covgrp_items_[ip.first].at_least;
		  weight = covgrp_item_weight(context, ip.first);
	    }
	    if (ip.second.empty()) continue;
	    unsigned hits = 0;
	    for (unsigned prop : ip.second)
		  if (type_count(prop) >= at_least)
			hits += 1;
	    wsum += (double)weight;
	    wcov += (double)weight
		  * (100.0 * (double)hits / (double)ip.second.size());
      }
      return (wsum > 0.0) ? (wcov / wsum) : 0.0;
}

static std::vector<const class_type*> covgrp_registry_;

const std::vector<const class_type*>& class_type::covgrp_registry()
{
      return covgrp_registry_;
}

void class_type::covgrp_register(const class_type*ct)
{
	// The compiler may emit the same class definition several
	// times (once per referencing scope); each compile lands
	// here. Later compiles win everywhere else (the scope map and
	// the dispatch-prefix map are overwritten), so keep exactly
	// one registry entry per dispatch prefix - the newest. Stale
	// duplicates held zero counters and dragged the
	// $get_coverage mean toward 0.
      for (auto&slot : covgrp_registry_) {
	    if (slot->dispatch_prefix() == ct->dispatch_prefix()) {
		  slot = ct;
		  return;
	    }
      }
      covgrp_registry_.push_back(ct);
}

/* M11: end-of-simulation coverage report (durable text form).  One
 * section per covergroup TYPE: the merged (type-level) counters per
 * bin, per-item coverage, and the type coverage. */
void class_type::covgrp_report(FILE*fd)
{
      fprintf(fd, "# Icarus Verilog functional coverage report\n");
      for (const class_type*ct : covgrp_registry_) {
	    fprintf(fd, "covergroup %s.%s type_coverage %.2f\n",
		    ct->scope_path().c_str(), ct->class_name().c_str(),
		    ct->type_coverage());

	      // group props per item
	    std::map<unsigned, std::set<unsigned>> item_props;
	    std::map<unsigned, unsigned> prop_kind;
	    for (size_t bi = 0 ; bi < ct->covgrp_bins_.size() ; bi += 1) {
		  const cov_bin_t&bin = ct->covgrp_bins_[bi];
		  if (bin.prop_idx == COV_NO_PROP) continue;
		  item_props[bin.item_idx].insert(bin.prop_idx);
		  prop_kind[bin.prop_idx] = bin.kind & 7;
	    }
	    for (auto&ip : item_props) {
		  unsigned at_least = 1, weight = 1;
		  bool is_cross = false;
		  if (ip.first < ct->covgrp_items_.size()) {
			at_least = ct->covgrp_items_[ip.first].at_least;
			weight = ct->covgrp_items_[ip.first].weight;
			is_cross = ct->covgrp_items_[ip.first].is_cross;
		  }
		  fprintf(fd, "  item %u kind %s at_least %u weight %u\n",
			  ip.first, is_cross ? "cross" : "coverpoint",
			  at_least, weight);
		  for (unsigned prop : ip.second) {
			unsigned k = prop_kind[prop];
			const char*tag = (k == 2 || k == 5) ? "illegal"
				       : (k == 3 || k == 6) ? "default"
				       : "bin";
			uint32_t cnt = ct->type_count(prop);
			fprintf(fd, "    %s %s count %u %s\n", tag,
				ct->property_name(prop).c_str(), cnt,
				(k == 0 || k == 4)
				      ? (cnt >= at_least ? "hit" : "MISS")
				      : "-");
		  }
	    }
      }
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
      if (compile_class->is_covergroup())
	    class_type::covgrp_register(compile_class);
      compile_class = 0;
}

#ifdef CHECK_WITH_VALGRIND
void class_def_delete(class_type *item)
{
      delete item;
}
#endif
