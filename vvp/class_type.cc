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
# include  "parse_misc.h"
# include  "vpi_priv.h"
# include  "vvp_assoc.h"
# include  "vvp_cobject.h"
# include  "vvp_darray.h"
# include  "vvp_net.h"
# include  "vvp_net_sig.h"
# include  "config.h"
# include  <cstddef>
# include  <cinttypes>
# include  <cctype>
# include  <cerrno>
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
	    if (array->vals
		&& array->value_kind == __vpiArray::ARRAY_VALUE_REAL)
		  return true;
	    return array->nets && array->get_size()
		&& dynamic_cast<__vpiRealVar*>(array->nets[0]);
      }
      if (type == "S")
	    return array->vals
		&& array->value_kind == __vpiArray::ARRAY_VALUE_STRING;
      if (static_property_uses_object_api_(type))
	    return array->vals
		&& array->value_kind == __vpiArray::ARRAY_VALUE_OBJECT;

      if (array->vals4) {
	    unsigned width = 0;
	    bool is_signed = false;
	    return !static_property_integral_shape_(type, width, is_signed)
		|| ((unsigned)array->get_word_size() == width
		    && array->signed_flag == is_signed);
      }
      if (array->vals)
	    {
		  bool integral =
			array->value_kind == __vpiArray::ARRAY_VALUE_INTEGRAL;
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
                                " index %" PRIu64 " out of range (size=%zu); ignoring write"
                                " (further similar warnings suppressed)\n",
                                owner_class_.empty() ? "<unknown>" : owner_class_.c_str(),
                                prop_name_.empty() ? "<unknown>" : prop_name_.c_str(),
                                type_name_.empty() ? "<unknown>" : type_name_.c_str(),
                                idx, array_size_);
                        warned_property_queue_oob_set = true;
                  }
                  return;
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
                                " index %" PRIu64 " out of range (size=%zu); returning null object"
                                " (further similar warnings suppressed)\n",
                                owner_class_.empty() ? "<unknown>" : owner_class_.c_str(),
                                prop_name_.empty() ? "<unknown>" : prop_name_.c_str(),
                                type_name_.empty() ? "<unknown>" : type_name_.c_str(),
                                idx, array_size_);
                        warned_property_queue_oob_get = true;
                  }
                  val.reset();
                  return;
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

bool class_type::property_is_enum(size_t idx) const
{
      return idx < properties_.size() && !properties_[idx].enum_values.empty();
}

const vector<vvp_vector4_t>&class_type::property_enum_values(size_t idx) const
{
      static const vector<vvp_vector4_t> empty;
      return idx < properties_.size() ? properties_[idx].enum_values : empty;
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

unsigned class_type::property_vec4_width(size_t idx) const
{
      if (idx >= properties_.size())
	    return 0;
      const string&type = properties_[idx].base_type;
      if (type == "V")
	    return 1;
      size_t pos = 0;
      if (pos < type.size() && type[pos] == 's')
	    pos += 1;
      if (pos >= type.size() || (type[pos] != 'b' && type[pos] != 'L'))
	    return 0;
      char*end = 0;
      unsigned long width = strtoul(type.c_str()+pos+1, &end, 10);
      if (!end || *end != '\0')
	    return 0;
      return width ? (unsigned)width : 1;
}

unsigned class_type::union_vec4_width(void) const
{
      if (!is_union_type_)
	    return 0;
      unsigned width = 0;
      for (size_t idx = 0 ; idx < properties_.size() ; idx += 1) {
	    unsigned member_width = property_vec4_width(idx);
	    if (member_width > width)
		  width = member_width;
      }
      return width;
}

bool class_type::union_is_four_state(void) const
{
      if (!is_union_type_)
	    return false;
      for (size_t idx = 0 ; idx < properties_.size() ; idx += 1) {
	    const string&type = properties_[idx].base_type;
	    size_t pos = !type.empty() && type[0] == 's' ? 1 : 0;
	    if (pos < type.size() && type[pos] == 'L')
		  return true;
      }
      return false;
}

bool class_type::property_is_void(size_t idx) const
{
      return idx < properties_.size() && properties_[idx].base_type == "V";
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

void class_type::add_interface_dispatch_prefix(const string&path)
{
      if (path.empty())
	    return;
      for (const string&cur : interface_dispatch_prefixes_)
	    if (cur == path)
		  return;
      interface_dispatch_prefixes_.push_back(path);
}

static bool class_assignment_compatible_(const class_type*have,
					 const class_type*want,
					 set<const class_type*>&seen)
{
      if (!(have && want) || !seen.insert(have).second)
	    return false;

      const string&want_key = want->dispatch_prefix();
      if (have == want || (!want_key.empty()
	  && have->dispatch_prefix() == want_key))
	    return true;

      const string&super_key = have->super_dispatch_prefix();
      if (!super_key.empty()) {
	    if (!want_key.empty() && super_key == want_key)
		  return true;
	    if (class_assignment_compatible_(
		  class_type_from_dispatch_prefix(super_key), want, seen))
		  return true;
      }

      for (const string&interface_key : have->interface_dispatch_prefixes()) {
	    if (!want_key.empty() && interface_key == want_key)
		  return true;
	    if (class_assignment_compatible_(
		  class_type_from_dispatch_prefix(interface_key), want, seen))
		  return true;
      }

      return false;
}

bool class_type::assignment_compatible_with(const class_type*want) const
{
      set<const class_type*>seen;
      return class_assignment_compatible_(this, want, seen);
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
	         && ((qualifier & (8 | 16))
		     || (encoded_type[1] != 'e' && encoded_type[1] != 'a'))) {
	      // Guard against "r" (real) and "rc" already handled above.
	      // Historical records only use the prefix before 's', 'b', 'L',
	      // etc. A q-wrapped record has authoritative qualifier bits, so
	      // q8:re{...}:bN is unambiguously a rand enum rather than "real".
	    properties_[idx].rand_flag = true;
	    properties_[idx].qualifier |= 8;
	    base_type = encoded_type.substr(1);
      }

	// An enum property is stored through the same bit/logic property class
	// as its base type, but e{LSB-first-values}: retains the finite set that
	// randomize() may choose. Keeping this metadata here prevents a sparse
	// enum from receiving an unnamed packed encoding.
      vector<string> enum_bits;
      if (base_type.compare(0, 2, "e{") == 0) {
	    string::size_type close = base_type.find("}:", 2);
	    if (close != string::npos) {
		  string domain = base_type.substr(2, close - 2);
		  string::size_type begin = 0;
		  while (begin <= domain.size()) {
			string::size_type comma = domain.find(',', begin);
			string bits = domain.substr(begin,
			      comma == string::npos ? string::npos
						    : comma - begin);
			if (!bits.empty())
			      enum_bits.push_back(bits);
			if (comma == string::npos)
			      break;
			begin = comma + 1;
		  }
		  base_type.erase(0, close + 2);
	    }
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
      if (t == "V")
	    properties_[idx].type = new property_bit(1, array_size);
      else if (t == "b8")
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

      for (const string&bits : enum_bits) {
	    vvp_vector4_t value((unsigned)bits.size(), BIT4_0);
	    for (unsigned bit = 0 ; bit < bits.size() ; bit += 1) {
		  vvp_bit4_t digit = BIT4_X;
		  switch (bits[bit]) {
		      case '0': digit = BIT4_0; break;
		      case '1': digit = BIT4_1; break;
		      case 'z': case 'Z': digit = BIT4_Z; break;
		      case 'x': case 'X': digit = BIT4_X; break;
		      default: break;
		  }
		  value.set_bit(bit, digit);
	    }
	    properties_[idx].enum_values.push_back(value);
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
static bool compile_class_covgrp_parent_required = false;
static bool compile_class_covgrp_parent_seen = false;

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

enum covgrp_ir_atom_kind_t {
      COVGRP_IR_ATOM_CONSTANT,
      COVGRP_IR_ATOM_PROPERTY,
      COVGRP_IR_ATOM_PARENT_PROPERTY
};

struct covgrp_ir_atom_t {
      covgrp_ir_atom_kind_t kind = COVGRP_IR_ATOM_CONSTANT;
      uint64_t first = 0;
      unsigned width = 32;
      bool is_signed = false;
};

/* Decode the typed scalar atoms shared by the coverage IR loader and
 * evaluator. A constant retains the historical optional width (default 32),
 * while both property forms require an explicit 1..64-bit type. Keeping this
 * parser in one place prevents malformed pp: metadata from being accepted by
 * the loader but interpreted differently at runtime. */
static bool covgrp_ir_parse_atom_(const string&tok, covgrp_ir_atom_t&out)
{
      size_t prefix = 0;
      if (tok.compare(0, 3, "pp:") == 0) {
	    out.kind = COVGRP_IR_ATOM_PARENT_PROPERTY;
	    prefix = 3;
      } else if (tok.compare(0, 2, "p:") == 0) {
	    out.kind = COVGRP_IR_ATOM_PROPERTY;
	    prefix = 2;
      } else if (tok.compare(0, 2, "c:") == 0) {
	    out.kind = COVGRP_IR_ATOM_CONSTANT;
	    prefix = 2;
      } else {
	    return false;
      }

      const char*begin = tok.c_str() + prefix;
      if (!isdigit(static_cast<unsigned char>(*begin))) return false;
      char*end = 0;
      errno = 0;
      uint64_t first = strtoull(begin, &end, 10);
      if (end == begin || errno == ERANGE) return false;

      unsigned width = 32;
      bool is_signed = false;
      if (*end == ':') {
	    const char*width_begin = end + 1;
	    if (!isdigit(static_cast<unsigned char>(*width_begin))) return false;
	    errno = 0;
	    unsigned long parsed = strtoul(width_begin, &end, 10);
	    if (end == width_begin || errno == ERANGE
		|| parsed == 0 || parsed > 64)
		  return false;
	    width = (unsigned)parsed;
	    if (*end == ':' && end[1] == 's') {
		  is_signed = true;
		  end += 2;
	    }
      } else if (out.kind != COVGRP_IR_ATOM_CONSTANT) {
	    return false;
      }
      if (*end != 0) return false;

      out.first = first;
      out.width = width;
      out.is_signed = is_signed;
      return true;
}

static bool covgrp_ir_mentions_parent_(const string&text)
{
	/* Keep this first-pass detector at least as broad as the runtime's
	 * deferred-parent check. Otherwise a malformed atom such as
	 * c:0pp:1:32 can evade load-time validation, then look parent-backed to
	 * covgrp_dyn_states_ and be deferred forever without a diagnostic. */
	if (text.find("pp:") != string::npos)
	      return true;

      for (size_t pos = 0; pos < text.size(); pos += 1) {
	    bool boundary = pos == 0 || isspace(static_cast<unsigned char>(text[pos-1]))
		  || text[pos-1] == '(';
	    if (!boundary || text.compare(pos, 2, "pp") != 0) continue;
	    size_t after = pos + 2;
	    if (after == text.size() || text[after] == ':' || text[after] == ')'
		|| isspace(static_cast<unsigned char>(text[after])))
		  return true;
      }
      return false;
}

/* Validate only the bounded expression grammar implemented by
 * covgrp_ir_eval_t. The caller deliberately invokes this for pp:-bearing
 * records only, so historical p:/c:-only bytecode keeps its existing loader
 * compatibility. */
class covgrp_ir_syntax_t {
    public:
      explicit covgrp_ir_syntax_t(const string&text)
      : text_(text), pos_(0), nodes_(0), uses_parent_(false) { }

      bool validate(bool&uses_parent)
      {
	    bool valid = expr_(0);
	    skip_();
	    uses_parent = uses_parent_;
	    return valid && pos_ == text_.size();
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

      bool expr_(unsigned depth)
      {
	    if (depth > 128 || ++nodes_ > 1024) return false;
	    skip_();
	    if (pos_ >= text_.size()) return false;
	    if (text_[pos_] != '(') {
		  covgrp_ir_atom_t atom;
		  if (!covgrp_ir_parse_atom_(atom_(), atom)) return false;
		  if (atom.kind == COVGRP_IR_ATOM_PARENT_PROPERTY)
			uses_parent_ = true;
		  return true;
	    }

	    pos_ += 1;
	    string op = atom_();
	    unsigned arity = 0;
	    if (op == "not" || op == "bnot" || op == "redand"
		|| op == "redor" || op == "redxor" || op == "neg") {
		  arity = 1;
	    } else if (op == "ite") {
		  arity = 3;
	    } else if (op == "eq" || op == "ne" || op == "lt"
		       || op == "le" || op == "gt" || op == "ge"
		       || op == "and" || op == "or" || op == "impl"
		       || op == "iff" || op == "shl" || op == "lshr"
		       || op == "ashr" || op == "add" || op == "sub"
		       || op == "mul" || op == "div" || op == "mod"
		       || op == "band" || op == "bor" || op == "bxor"
		       || op == "pow") {
		  arity = 2;
	    } else {
		  return false;
	    }
	    for (unsigned idx = 0; idx < arity; idx += 1)
		  if (!expr_(depth + 1)) return false;
	    skip_();
	    if (pos_ >= text_.size() || text_[pos_] != ')') return false;
	    pos_ += 1;
	    return true;
      }

      const string&text_;
      size_t pos_;
      unsigned nodes_;
      bool uses_parent_;
};

void compile_class_start(char*lab, char*nam, char*dispatch_prefix,
                         char*super_dispatch_prefix, unsigned ntype)
{
      assert(compile_class == 0);
      compile_class_covgrp_parent_required = false;
      compile_class_covgrp_parent_seen = false;
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

void compile_class_mark_union(bool tagged)
{
      assert(compile_class);
      compile_class->set_union_type(tagged);
}

void compile_class_interface(char*dispatch_prefix)
{
      assert(compile_class);
      if (dispatch_prefix)
	    compile_class->add_interface_dispatch_prefix(dispatch_prefix);
      delete[]dispatch_prefix;
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
				unsigned tuple, unsigned item_idx,
				unsigned trans_repeat, uint64_t trans_min,
				uint64_t trans_max, unsigned trans_alt,
				unsigned trans_alt_count, unsigned trans_family,
				uint64_t trans_base, unsigned guard_idx)
{
      cov_bin_t b;
      b.cp_idx   = cp_idx;
      b.prop_idx = prop_idx;
      b.lo       = lo;
      b.hi       = hi;
      b.kind     = kind;
      b.tuple    = tuple;
      b.item_idx = item_idx;
	 b.trans_repeat = trans_repeat;
	 b.trans_min = trans_min;
	 b.trans_max = trans_max;
	 b.trans_alt = trans_alt;
	 b.trans_alt_count = trans_alt_count;
	 b.trans_family = trans_family;
	 b.trans_base = trans_base;
	 b.guard_idx = guard_idx;
      covgrp_bins_.push_back(b);
}

void compile_class_covgrp_bin(uint64_t cp_idx, uint64_t prop_idx,
			      uint64_t lo, uint64_t hi, uint64_t kind,
			      uint64_t tuple, uint64_t item_idx,
			      uint64_t trans_repeat, uint64_t trans_min,
			      uint64_t trans_max, uint64_t trans_alt,
			      uint64_t trans_alt_count, uint64_t trans_family,
			      uint64_t trans_base, uint64_t guard_idx)
{
      assert(compile_class);
      static const uint64_t transition_repeat_limit = 65536;
      const uint64_t u32_max = std::numeric_limits<unsigned>::max();
      if (cp_idx > u32_max || prop_idx > u32_max || kind > u32_max
	  || tuple > u32_max || item_idx > u32_max
	  || trans_repeat > u32_max || trans_alt > u32_max
	  || trans_alt_count > u32_max || trans_family > u32_max
	  || guard_idx > u32_max) {
	yyerror("invalid .covgrp_bin metadata value");
	return;
      }
      if ((kind & 7) == 4
	  && (trans_repeat > 3 || trans_min == 0
	      || trans_max < trans_min
	      || trans_max > transition_repeat_limit
	      || trans_alt_count == 0
	      || trans_alt >= trans_alt_count)) {
	yyerror("invalid .covgrp_bin transition metadata");
	return;
      }
      compile_class->add_covgrp_bin((unsigned)cp_idx, (unsigned)prop_idx,
				    lo, hi, (unsigned)kind,
				    (unsigned)tuple, (unsigned)item_idx,
				    (unsigned)trans_repeat, trans_min, trans_max,
				    (unsigned)trans_alt,
				    (unsigned)trans_alt_count,
				    (unsigned)trans_family, trans_base,
				    (unsigned)guard_idx);
}

void compile_class_covgrp_dyn_bin(uint64_t cp_idx, uint64_t item_idx,
				  uint64_t kind, uint64_t family,
				  uint64_t array_size, char*name,
				  char*lo_ir, char*hi_ir,
				  uint64_t guard_idx, char*value_type)
{
      assert(compile_class);
      const uint64_t u32_max = std::numeric_limits<unsigned>::max();
	 // A zero width marks the legacy grammar, which had no coverpoint type
	 // field and therefore used raw unsigned endpoint bits at runtime.
	 unsigned value_width = 0;
	 bool value_signed = false;
	 bool bad_type = false;
	   // A typed set suffix and the typed coverpoint field form one metadata
	   // ABI. Reject either mixed-generation pairing: the first would reach
	   // runtime with value_width == 0, while the second would silently take
	   // legacy raw-set semantics despite carrying a typed coverpoint.
	 bool set_ir = lo_ir && hi_ir && strcmp(lo_ir, hi_ir) == 0
	       && (strncmp(lo_ir, "setc:", 5) == 0
		   || strncmp(lo_ir, "setp:", 5) == 0);
	 bool typed_set_ir = set_ir && strchr(lo_ir + 5, ':');
	 if ((!value_type && typed_set_ir) || (value_type && set_ir && !typed_set_ir))
	       bad_type = true;
	 bool parent_ir = lo_ir && covgrp_ir_mentions_parent_(lo_ir);
	 parent_ir = parent_ir || (hi_ir && covgrp_ir_mentions_parent_(hi_ir));
	 bool valid_parent_ir = true;
	 if (parent_ir) {
	       bool lo_uses_parent = false;
	       bool hi_uses_parent = false;
	       valid_parent_ir = value_type && lo_ir && hi_ir
		     && covgrp_ir_syntax_t(lo_ir).validate(lo_uses_parent)
		     && covgrp_ir_syntax_t(hi_ir).validate(hi_uses_parent)
		     && (lo_uses_parent || hi_uses_parent);
	       bad_type = bad_type || !valid_parent_ir;
	 }
	 if (value_type) {
	       size_t type_len = strlen(value_type);
	       value_signed = type_len > 0 && value_type[0] == 's';
	       bool value_type_bad = type_len < 2
		     || (value_type[0] != 's' && value_type[0] != 'u')
		     || !isdigit(static_cast<unsigned char>(value_type[1]));
	       char*end = 0;
	       errno = 0;
	       unsigned long parsed = value_type_bad ? 0
		     : strtoul(value_type + 1, &end, 10);
	       value_type_bad = value_type_bad || end == value_type + 1 || *end != 0
		     || errno == ERANGE || parsed == 0 || parsed > 64;
	       bad_type = bad_type || value_type_bad;
	       if (!value_type_bad) value_width = (unsigned)parsed;
	 }
      if (cp_idx > u32_max || item_idx > u32_max || kind > u32_max
	  || family > u32_max || guard_idx > u32_max || bad_type) {
	yyerror("invalid .covgrp_dyn_bin metadata value");
	free(name);
	free(lo_ir);
	free(hi_ir);
	free(value_type);
	return;
      }
	 if (parent_ir && valid_parent_ir)
	       compile_class_covgrp_parent_required = true;
      compile_class->add_covgrp_dyn_bin((unsigned)cp_idx, (unsigned)item_idx,
					(unsigned)kind, (unsigned)family,
					array_size, name ? name : "",
					lo_ir ? lo_ir : "", hi_ir ? hi_ir : "",
					value_width, value_signed,
					(unsigned)guard_idx);
      free(name);
      free(lo_ir);
      free(hi_ir);
      free(value_type);
}

void compile_class_covgrp_cross(uint64_t family, uint64_t item_idx,
				uint64_t n_dims, uint64_t retain_auto)
{
      assert(compile_class);
      const uint64_t u32_max = std::numeric_limits<unsigned>::max();
      if (family > u32_max || item_idx > u32_max || n_dims > u32_max
	  || n_dims == 0 || retain_auto > 1) {
	yyerror("invalid .covgrp_cross metadata value");
	return;
      }
      compile_class->add_covgrp_cross((unsigned)family, (unsigned)item_idx,
				      (unsigned)n_dims, retain_auto != 0);
}

void compile_class_covgrp_cross_term(uint64_t family, uint64_t dim,
				     uint64_t term_idx, uint64_t kind,
				     uint64_t source_id, uint64_t source_aux)
{
      assert(compile_class);
      const uint64_t u32_max = std::numeric_limits<unsigned>::max();
      if (family > u32_max || dim > u32_max || term_idx > u32_max
	  || kind > 3 || source_id > u32_max || source_aux > u32_max) {
	yyerror("invalid .covgrp_cross_term metadata value");
	return;
      }
      compile_class->add_covgrp_cross_term((unsigned)family, (unsigned)dim,
					   (unsigned)term_idx, (unsigned)kind,
					   (unsigned)source_id,
					   (unsigned)source_aux);
}

void compile_class_covgrp_cross_bin(uint64_t family, uint64_t kind,
				    uint64_t target, char*name, char*select_ir)
{
      assert(compile_class);
      const uint64_t u32_max = std::numeric_limits<unsigned>::max();
      if (family > u32_max || kind > 2 || target > u32_max
	  || !name || !select_ir) {
	yyerror("invalid .covgrp_cross_bin metadata value");
	free(name);
	free(select_ir);
	return;
      }
      compile_class->add_covgrp_cross_bin((unsigned)family, (unsigned)kind,
					  (unsigned)target, name, select_ir);
      free(name);
      free(select_ir);
}

void compile_class_covgrp_item(uint64_t at_least, uint64_t weight,
			       uint64_t is_cross, char*name, char*weight_ir,
			       uint64_t guardsrc)
{
      assert(compile_class);
	// Validate every narrowing conversion before retaining public VVP
	// metadata. The mutable option-property references arrive in a separate
	// tagged record so they cannot be parsed as the next numeric property.
      const uint64_t uint_max = std::numeric_limits<unsigned>::max();
      const uint64_t int_max = std::numeric_limits<int>::max();
      bool bad = at_least > uint_max || weight > uint_max
	    || is_cross > 1 || guardsrc > int_max + 1;
      if (bad) {
	    yyerror("invalid .covgrp_item metadata value");
	    free(name);
	    free(weight_ir);
	    return;
      }
      compile_class->add_covgrp_item((unsigned)at_least, (unsigned)weight,
			     is_cross != 0,
		     name ? std::string(name) : std::string(),
		     weight_ir ? std::string(weight_ir) : std::string(),
		     guardsrc ? static_cast<int>(guardsrc - 1) : -1);
      free(name);
      free(weight_ir);
}

void compile_class_covgrp_item_options(uint64_t item_idx,
				       uint64_t at_least_prop,
				       uint64_t weight_prop)
{
      assert(compile_class);
	// Property indexes are biased by +1 (zero means absent). Besides bounds,
	// require the scalar 32-bit non-static shape consumed by get/set_vec4;
	// otherwise an invalid hand-written VVP stream could select a string,
	// object, array, or static property and reach the wrong storage accessor.
      const uint64_t size_max = std::numeric_limits<size_t>::max();
      const uint64_t int_max = std::numeric_limits<int>::max();
      bool bad = item_idx > size_max || at_least_prop > int_max + 1
	    || weight_prop > int_max + 1;
      int at_prop = -1;
      int wt_prop = -1;
      if (!bad) {
	    at_prop = at_least_prop ? (int)(at_least_prop - 1) : -1;
	    wt_prop = weight_prop ? (int)(weight_prop - 1) : -1;
      }
      auto valid_property = [&](int prop) {
	    return prop < 0
		  || ((size_t)prop < compile_class->property_count()
		      && compile_class->property_vec4_width((size_t)prop) == 32
		      && compile_class->property_array_size((size_t)prop) == 1
		      && !compile_class->property_is_static((size_t)prop));
      };
      if (!bad)
	    if (!valid_property(at_prop) || !valid_property(wt_prop)
		|| !compile_class->set_covgrp_item_option_props(
		      static_cast<size_t>(item_idx), at_prop, wt_prop))
		  bad = true;
      if (bad)
	    yyerror("invalid .covgrp_item_options metadata value");
}

/* M11-3: event-driven sampling metadata. The .covgrp_src property
 * indexes arrive biased by +1 (0 = none) because the vvp lexer only
 * accepts unsigned numbers. */
void compile_class_covgrp_parent(uint64_t prop)
{
      assert(compile_class);
      compile_class_covgrp_parent_seen = true;
      bool valid = prop <= (uint64_t)std::numeric_limits<int>::max()
	    && prop < compile_class->property_count();
      if (valid) {
	    size_t idx = (size_t)prop;
	    valid = !compile_class->property_is_static(idx)
		  && compile_class->property_array_size(idx) == 1
		  && compile_class->property_name(idx) == "__covgrp_parent"
		  && compile_class->property_base_type(idx) == "o";
      }
      if (!valid) {
	    yyerror("invalid .covgrp_parent metadata value");
	    return;
      }
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

/* Evaluate the deliberately bounded arithmetic subset used by dynamic
 * covergroup options and bounds. The compiler emits the same prefix IR as
 * class constraints: c:V:WIDTH[:s] atoms, p:PID:WIDTH[:s] current-object
 * property atoms, pp:PID:WIDTH[:s] enclosing-covergroup-parent atoms, and
 * parenthesized arithmetic. Width and signedness are part of the value,
 * not decoration: dropping them changes nested arithmetic and shifts. Keep
 * this evaluator independent of Z3 so coverage construction remains cheap
 * and works in builds without the optional solver. */
class covgrp_ir_eval_t {
    public:
	 struct value_t {
	       uint64_t bits = 0;
	       unsigned width = 1;
	       bool is_signed = false;
	 };

      covgrp_ir_eval_t(const string&text, vvp_cobject*obj)
      : text_(text), obj_(obj), pos_(0), nodes_(0) { }

      bool eval(uint64_t&out)
      {
	    value_t value;
	    if (!eval(value)) return false;
	    out = value.bits;
	    return true;
      }

      bool eval(value_t&out)
      {
	    if (!expr_(out, 0)) return false;
	    skip_();
	    return pos_ == text_.size();
      }

    private:
	 static uint64_t mask_(unsigned width)
	 {
	       return width >= 64 ? UINT64_MAX
		     : (UINT64_C(1) << width) - 1;
	 }

	 static uint64_t resize_(const value_t&value, unsigned width,
				 bool sign_extend)
	 {
	       uint64_t bits = value.bits & mask_(value.width);
	       if (sign_extend && value.is_signed && value.width < width
		   && (bits & (UINT64_C(1) << (value.width - 1))))
		     bits |= ~mask_(value.width);
	       return bits & mask_(width);
	 }

	 static __int128 signed_value_(uint64_t bits, unsigned width)
	 {
	       bits &= mask_(width);
	       if (width < 64 && (bits & (UINT64_C(1) << (width - 1))))
		     return (__int128)bits - ((__int128)1 << width);
	       return (__int128)(int64_t)bits;
	 }

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

	 bool atom_value_(const string&tok, value_t&out)
	 {
	       covgrp_ir_atom_t atom;
	       if (!covgrp_ir_parse_atom_(tok, atom)) return false;
	       bool property = atom.kind == COVGRP_IR_ATOM_PROPERTY;
	       bool parent_property = atom.kind == COVGRP_IR_ATOM_PARENT_PROPERTY;

	       out.width = atom.width;
	       out.is_signed = atom.is_signed;
	       if (!property && !parent_property) {
		     out.bits = atom.first & mask_(atom.width);
		     return true;
	       }

	       vvp_cobject*owner = obj_;
	       if (parent_property) {
		     if (!owner) return false;
		     const class_type*covergroup_defn = owner->get_defn();
		     int parent_prop = covergroup_defn->covgrp_parent_prop();
		     if (parent_prop < 0
			 || (size_t)parent_prop >= covergroup_defn->property_count()
			 || covergroup_defn->property_is_static((size_t)parent_prop)
			 || covergroup_defn->property_array_size((size_t)parent_prop) != 1
			 || covergroup_defn->property_base_type((size_t)parent_prop) != "o")
			   return false;
		     vvp_object_t parent;
		     owner->get_object((size_t)parent_prop, parent, 0);
		     owner = parent.peek<vvp_cobject>();
		     const class_type*declared_parent =
			   covergroup_defn->property_declared_class_type(
				 (size_t)parent_prop);
		     if (!owner || !declared_parent
			 || !owner->get_defn()->assignment_compatible_with(
			       declared_parent))
			   return false;

		       /* pp: property indexes are compiled against the declared
			* enclosing-class type. An assignment-compatible derived object
			* may have additional properties, but those are not in the
			* lexical namespace that produced this metadata. Validate the
			* declared slot before consulting the live object's matching
			* inherited slot. */
		     unsigned declared_width = 0;
		     bool declared_signed = false;
		     if (atom.first >= declared_parent->property_count()
			 || (declared_parent->property_qualifier(
			       (size_t)atom.first) & 32) == 0
			 || declared_parent->property_array_size(
			       (size_t)atom.first) != 1
			 || !static_property_integral_shape_(
			       declared_parent->property_base_type(
				     (size_t)atom.first),
			       declared_width, declared_signed)
			 || declared_width != atom.width
			 || declared_signed != atom.is_signed)
			   return false;
	       }
	       if (!owner || atom.first >= owner->get_defn()->property_count())
		     return false;
	       if (parent_property) {
		     const class_type*parent_defn = owner->get_defn();
		     size_t parent_idx = (size_t)atom.first;
		     unsigned actual_width = 0;
		     bool actual_signed = false;
		     if ((parent_defn->property_qualifier(parent_idx) & 32) == 0
			 || parent_defn->property_array_size(parent_idx) != 1
			 || !static_property_integral_shape_(
			       parent_defn->property_base_type(parent_idx),
			       actual_width, actual_signed)
			 || actual_width != atom.width
			 || actual_signed != atom.is_signed)
			   return false;
	       }
	       vvp_vector4_t value;
	       owner->get_vec4((size_t)atom.first, value);
	       if (parent_property ? value.size() != atom.width
		   : value.size() < atom.width) return false;
	       out.bits = 0;
	       for (unsigned bit = 0; bit < atom.width; bit += 1) {
		     vvp_bit4_t digit = value.value(bit);
		     if (digit == BIT4_X || digit == BIT4_Z) return false;
		     if (digit == BIT4_1) out.bits |= UINT64_C(1) << bit;
	       }
	       return true;
	 }

	 bool expr_(value_t&out, unsigned depth)
      {
	    if (depth > 128 || ++nodes_ > 1024) return false;
	    skip_();
	    if (pos_ >= text_.size()) return false;
	    if (text_[pos_] != '(') {
		  string tok = atom_();
		  return atom_value_(tok, out);
	    }

	    pos_ += 1;
	    string op = atom_();
	    value_t a, b, c;
	    if (!expr_(a, depth + 1)) return false;
	    bool unary = op == "not" || op == "bnot" || op == "redand"
		       || op == "redor" || op == "redxor" || op == "neg";
	    if (!unary && !expr_(b, depth + 1)) return false;
	    if (op == "ite" && !expr_(c, depth + 1)) return false;
	    skip_();
	    if (pos_ >= text_.size() || text_[pos_] != ')') return false;
	    pos_ += 1;

	    auto truth = [&](const value_t&value) {
		  return (value.bits & mask_(value.width)) != 0;
	    };
	    if (op == "ite") {
		  out.width = std::max(b.width, c.width);
		  out.is_signed = b.is_signed && c.is_signed;
		  out.bits = resize_(truth(a) ? b : c, out.width,
				     out.is_signed);
		  return true;
	    }

	    bool logical = op == "eq" || op == "ne" || op == "lt"
		  || op == "le" || op == "gt" || op == "ge"
		  || op == "and" || op == "or" || op == "impl"
		  || op == "iff" || op == "not" || op == "redand"
		  || op == "redor" || op == "redxor";
	    if (logical) {
		  bool result = false;
		  if (op == "not") result = !truth(a);
		  else if (op == "redand")
			result = (a.bits & mask_(a.width)) == mask_(a.width);
		  else if (op == "redor") result = truth(a);
		  else if (op == "redxor") {
			uint64_t bits = a.bits & mask_(a.width);
			while (bits) { result = !result; bits &= bits - 1; }
		  } else if (op == "and") result = truth(a) && truth(b);
		  else if (op == "or") result = truth(a) || truth(b);
		  else if (op == "impl") result = !truth(a) || truth(b);
		  else if (op == "iff") result = truth(a) == truth(b);
		  else {
			unsigned width = std::max(a.width, b.width);
			bool signed_compare = a.is_signed && b.is_signed;
			uint64_t av = resize_(a, width, signed_compare);
			uint64_t bv = resize_(b, width, signed_compare);
			if (op == "eq") result = av == bv;
			else if (op == "ne") result = av != bv;
			else if (signed_compare) {
			      __int128 as = signed_value_(av, width);
			      __int128 bs = signed_value_(bv, width);
			      if (op == "lt") result = as < bs;
			      else if (op == "le") result = as <= bs;
			      else if (op == "gt") result = as > bs;
			      else result = as >= bs;
			} else {
			      if (op == "lt") result = av < bv;
			      else if (op == "le") result = av <= bv;
			      else if (op == "gt") result = av > bv;
			      else result = av >= bv;
			}
		  }
		  out.bits = result ? 1 : 0;
		  out.width = 1;
		  out.is_signed = false;
		  return true;
	    }

	    if (op == "neg" || op == "bnot") {
		  out.width = a.width;
		  out.is_signed = a.is_signed;
		  out.bits = op == "neg" ? UINT64_C(0) - a.bits : ~a.bits;
		  out.bits &= mask_(out.width);
		  return true;
	    }

	    if (op == "shl" || op == "lshr" || op == "ashr") {
		  out.width = a.width;
		  out.is_signed = a.is_signed;
		  uint64_t av = a.bits & mask_(a.width);
		  uint64_t count = b.bits & mask_(b.width);
		  if (count >= out.width) {
			bool fill = op == "ashr" && out.is_signed
			      && (av & (UINT64_C(1) << (out.width - 1)));
			out.bits = fill ? mask_(out.width) : 0;
		  } else if (op == "shl") {
			out.bits = (av << count) & mask_(out.width);
		  } else if (op == "lshr" || !out.is_signed) {
			out.bits = av >> count;
		  } else {
			out.bits = av >> count;
			if (count && (av & (UINT64_C(1) << (out.width - 1))))
			      out.bits |= mask_(out.width)
				    & ~mask_(out.width - (unsigned)count);
		  }
		  return true;
	    }

	    if (op == "add" || op == "sub" || op == "mul"
		|| op == "div" || op == "mod" || op == "band"
		|| op == "bor" || op == "bxor" || op == "pow") {
		  bool left_width = op == "pow";
		  out.width = left_width ? a.width : std::max(a.width, b.width);
		  out.is_signed = left_width ? a.is_signed
			: a.is_signed && b.is_signed;
		  uint64_t av = resize_(a, out.width, out.is_signed);
		  uint64_t bv = resize_(b, out.width, out.is_signed);
		  if (op == "add") out.bits = av + bv;
		  else if (op == "sub") out.bits = av - bv;
		  else if (op == "mul") out.bits = av * bv;
		  else if (op == "band") out.bits = av & bv;
		  else if (op == "bor") out.bits = av | bv;
		  else if (op == "bxor") out.bits = av ^ bv;
		  else if (op == "pow") {
			uint64_t exponent = b.bits & mask_(b.width);
			uint64_t power = 1;
			uint64_t base = av;
			while (exponent) {
			      if (exponent & 1) power = (power * base) & mask_(out.width);
			      exponent >>= 1;
			      if (exponent) base = (base * base) & mask_(out.width);
			}
			out.bits = power;
		  } else {
			if (bv == 0) return false;
			if (out.is_signed) {
			      __int128 as = signed_value_(av, out.width);
			      __int128 bs = signed_value_(bv, out.width);
			      out.bits = (uint64_t)(op == "div" ? as / bs : as % bs);
			} else {
			      out.bits = op == "div" ? av / bv : av % bv;
			}
		  }
		  out.bits &= mask_(out.width);
		  return true;
	    }
	    return false;
      }

      const string&text_;
      vvp_cobject*obj_;
      size_t pos_;
	 unsigned nodes_;
};

unsigned class_type::covgrp_decl_weight_(vvp_cobject*obj, size_t idx) const
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

static unsigned covgrp_option_prop_value_(const class_type*defn,
					  vvp_cobject*obj, int prop,
					  unsigned fallback)
{
      if (!obj || obj->get_defn() != defn || prop < 0
	  || (size_t)prop >= defn->property_count())
	    return fallback;

      vvp_vector4_t value;
      obj->get_vec4((size_t)prop, value);
      uint64_t bits = 0;
      for (unsigned idx = 0; idx < value.size() && idx < 32; idx += 1) {
	    vvp_bit4_t bit = value.value(idx);
	    if (bit == BIT4_X || bit == BIT4_Z)
		  return fallback;
	    if (bit == BIT4_1)
		  bits |= (uint64_t)1 << idx;
      }
      return (unsigned)bits;
}

unsigned class_type::covgrp_item_at_least(vvp_cobject*obj, size_t idx) const
{
      if (idx >= covgrp_items_.size()) return 1;
      const cov_item_t&item = covgrp_items_[idx];
      return covgrp_option_prop_value_(this, obj, item.at_least_prop,
					item.at_least);
}

unsigned class_type::covgrp_item_weight(vvp_cobject*obj, size_t idx) const
{
      if (idx >= covgrp_items_.size()) return 1;
      const cov_item_t&item = covgrp_items_[idx];
      unsigned declared = covgrp_decl_weight_(obj, idx);
      return covgrp_option_prop_value_(this, obj, item.weight_prop, declared);
}

unsigned class_type::covgrp_cumulative_at_least_(size_t idx) const
{
      if (idx >= covgrp_items_.size()) return 1;

      unsigned maximum = idx < covgrp_retired_at_least_.size()
	    ? covgrp_retired_at_least_[idx] : 0;
      bool found = covgrp_has_retired_options_;
      for (vvp_cobject*obj : covgrp_live_) {
	    // The destructor removes dead instances. Retain defensive checks
	    // because the same live registry drives event sampling.
	    if (!obj || obj->get_defn() != this) continue;
	    maximum = std::max(maximum, covgrp_item_at_least(obj, idx));
	    found = true;
      }
      return found ? maximum : covgrp_items_[idx].at_least;
}

void class_type::covgrp_live_add(vvp_cobject*obj) const
{
      if (obj && obj->get_defn() == this)
	    covgrp_live_.push_back(obj);
}

void class_type::covgrp_live_remove(vvp_cobject*obj) const
{
      if (obj && obj->get_defn() == this) {
	    if (covgrp_retired_at_least_.size() < covgrp_items_.size())
		  covgrp_retired_at_least_.resize(covgrp_items_.size(), 0);
	    for (size_t idx = 0; idx < covgrp_items_.size(); idx += 1)
		  covgrp_retired_at_least_[idx] = std::max(
			covgrp_retired_at_least_[idx],
			covgrp_item_at_least(obj, idx));
	    covgrp_has_retired_options_ = true;
      }

      for (size_t idx = 0; idx < covgrp_live_.size(); idx += 1)
	    if (covgrp_live_[idx] == obj) {
		  covgrp_live_.erase(covgrp_live_.begin()
			+ static_cast<std::ptrdiff_t>(idx));
		  return;
	    }
}

void class_type::covgrp_init_options(vvp_cobject*obj) const
{
      if (!obj || obj->get_defn() != this) return;

      auto store = [&](int prop, unsigned value) {
	    if (prop < 0 || (size_t)prop >= property_count()) return;
	    vvp_vector4_t bits(32, BIT4_0);
	    for (unsigned idx = 0; idx < 32; idx += 1)
		  if (value & ((uint64_t)1 << idx))
			bits.set_bit(idx, BIT4_1);
	    obj->set_vec4((size_t)prop, bits);
      };

      for (size_t idx = 0; idx < covgrp_items_.size(); idx += 1) {
	    const cov_item_t&item = covgrp_items_[idx];
	    store(item.at_least_prop, item.at_least);
	    store(item.weight_prop, covgrp_decl_weight_(obj, idx));
      }
}

bool class_type::covgrp_eval_ir(vvp_cobject*obj, const string&ir,
				uint64_t&value) const
{
      return covgrp_ir_eval_t(ir, obj).eval(value);
}

bool class_type::covgrp_eval_ir(vvp_cobject*obj, const string&ir,
				uint64_t&value, unsigned&width,
				bool&is_signed) const
{
      covgrp_ir_eval_t::value_t result;
      if (!covgrp_ir_eval_t(ir, obj).eval(result)) return false;
      value = result.bits;
      width = result.width;
      is_signed = result.is_signed;
      return true;
}

uint32_t class_type::type_count(unsigned prop) const
{
      if (prop >= type_counts_.size())
	    return 0;
      return type_counts_[prop];
}

static uint64_t cov_sat_add_(uint64_t a, uint64_t b)
{
      return a > UINT64_MAX - b ? UINT64_MAX : a + b;
}

static uint64_t cov_sat_mul_(uint64_t a, uint64_t b)
{
      if (a == 0 || b == 0) return 0;
      return a > UINT64_MAX / b ? UINT64_MAX : a * b;
}

struct cov_power_sum_t {
      uint64_t power;
      uint64_t sum;
};

/* Compose adjacent power-series blocks. A block of length n carries b^n and
 * b^1+...+b^n. Exponentiation by squaring makes large, valid transition
 * repetition bounds logarithmic while preserving the existing saturating
 * logical-bin arithmetic. */
static cov_power_sum_t cov_power_sum_join_(const cov_power_sum_t&a,
					    const cov_power_sum_t&b)
{
      cov_power_sum_t out;
      out.power = cov_sat_mul_(a.power, b.power);
      out.sum = cov_sat_add_(a.sum, cov_sat_mul_(a.power, b.sum));
      return out;
}

static cov_power_sum_t cov_power_sum_(uint64_t base, uint64_t count)
{
      cov_power_sum_t result = { 1, 0 };
      cov_power_sum_t block = { base, base };
      while (count) {
	if (count & 1) result = cov_power_sum_join_(result, block);
	count >>= 1;
	if (count) block = cov_power_sum_join_(block, block);
      }
      return result;
}

static uint64_t cov_power_sum_range_(uint64_t base, uint64_t first,
				     uint64_t last)
{
      if (last < first || last == 0) return 0;
      uint64_t hi = cov_power_sum_(base, last).sum;
      if (hi == UINT64_MAX) return UINT64_MAX;
      uint64_t lo = first > 1 ? cov_power_sum_(base, first - 1).sum : 0;
      return hi - lo;
}

uint64_t class_type::covgrp_trans_family_size(unsigned family) const
{
      std::map<unsigned, std::map<unsigned, const cov_bin_t*>> seq_terms;
      std::map<unsigned, uint64_t> seq_bases;
      for (const cov_bin_t&bin : covgrp_bins_) {
	    if ((bin.kind & 7) != 4 || bin.trans_family != family) continue;
	    unsigned seq = bin.tuple >> 8;
	    unsigned term = bin.tuple & 255;
	    if (!seq_terms[seq].count(term)) seq_terms[seq][term] = &bin;
	    seq_bases[seq] = bin.trans_base;
      }
      uint64_t total = 0;
      for (auto&seq : seq_terms) {
	    uint64_t variants = 1;
	    for (auto&term_entry : seq.second) {
		  const cov_bin_t&term = *term_entry.second;
		  uint64_t term_variants = cov_power_sum_range_(
			term.trans_alt_count, term.trans_min, term.trans_max);
		  variants = cov_sat_mul_(variants, term_variants);
	    }
	    total = std::max(total,
		      cov_sat_add_(seq_bases[seq.first], variants));
      }
      return total;
}

unsigned class_type::covgrp_trans_family_item(unsigned family) const
{
      for (const cov_bin_t&bin : covgrp_bins_)
	    if ((bin.kind & 7) == 4 && bin.trans_family == family)
		  return bin.item_idx;
      return 0;
}

double class_type::type_coverage(vvp_cobject*) const
{
	// Same per-item weighted model as instance coverage, computed
	// over the type-level counters. Until the complete 19.11.3
	// merge_instances/type_option model is represented, use stable
	// declaration weights rather than making this static result depend on
	// which instance happened to invoke get_coverage().
      std::map<unsigned, std::set<unsigned>> item_props;
	std::map<unsigned,uint64_t> item_trans_total;
	std::map<unsigned,uint64_t> item_trans_hits;
	std::set<unsigned> seen_trans_families;
      for (size_t bi = 0 ; bi < covgrp_bins_.size() ; bi += 1) {
	    const cov_bin_t&bin = covgrp_bins_[bi];
	    unsigned k = bin.kind & 7;
	    if (k == 1 || k == 2 || k == 3 || k == 5 || k == 6) continue;
	    if (k == 4 && bin.trans_family != COV_NO_FAMILY) {
		  if (seen_trans_families.insert(bin.trans_family).second) {
			uint64_t total = covgrp_trans_family_size(bin.trans_family);
			unsigned at_least = bin.item_idx < covgrp_items_.size()
			      ? covgrp_cumulative_at_least_(bin.item_idx) : 1;
			item_trans_total[bin.item_idx] = cov_sat_add_(
			      item_trans_total[bin.item_idx], total);
			item_trans_hits[bin.item_idx] = cov_sat_add_(
			      item_trans_hits[bin.item_idx],
			      at_least == 0 ? total
				    : dyn_type_hits(bin.trans_family, at_least));
		  }
		  continue;
	    }
	    if (bin.prop_idx == COV_NO_PROP) continue;
	    item_props[bin.item_idx].insert(bin.prop_idx);
      }
      double wsum = 0.0, wcov = 0.0;
	 std::set<unsigned> items;
	 for (auto&ip : item_props) items.insert(ip.first);
	 for (auto&ip : item_trans_total) items.insert(ip.first);
	 for (unsigned item_idx : items) {
	    unsigned at_least = 1, weight = 1;
	    if (item_idx < covgrp_items_.size()) {
		  at_least = covgrp_cumulative_at_least_(item_idx);
		  weight = covgrp_items_[item_idx].weight;
	    }
	    uint64_t total = item_trans_total[item_idx];
	    unsigned hits = 0;
	    for (unsigned prop : item_props[item_idx]) {
		  total += 1;
		  if (type_count(prop) >= at_least)
			hits += 1;
	    }
	    hits += item_trans_hits[item_idx];
	    if (total == 0) continue;
	    wsum += (double)weight;
	    wcov += (double)weight
		  * (100.0 * (double)hits / (double)total);
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
			at_least = ct->covgrp_cumulative_at_least_(ip.first);
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
      if (compile_class_covgrp_parent_required
	  && !compile_class_covgrp_parent_seen)
	    yyerror("parent-dependent .covgrp_dyn_bin has no .covgrp_parent metadata");
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
