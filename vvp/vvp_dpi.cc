/*
 * DPI (Direct Programming Interface) library loading, symbol lookup
 * and argument marshaling for Icarus Verilog VVP runtime.
 */
# include  "config.h"
# include  "vvp_dpi.h"
# include  "ivl_dlfcn.h"
# include  <cstdio>
# include  <cstring>
# include  <vector>
# include  <map>
# include  <string>

#ifdef USE_LIBFFI
# include  <ffi.h>
# include  "vvp_darray.h"
# include  "svdpi.h"
# include  <climits>
# include  <stdarg.h>
#endif

using namespace std;

static vector<ivl_dll_t> dpi_libs;
static map<string,void*> dpi_sym_cache;

static bool dpi_array_pointer_arg_(char type)
{
      return type == 'o' || type == 'O'
	  || type == 'B' || type == 'G'
	  || type == 'x' || type == 'X'
	  || type == 'y' || type == 'Y';
}

/* Open-array formals use an svOpenArrayHandle, while a fixed unpacked-array
 * formal uses the C pointer ABI from IEEE 1800 Annex H. The upper-case
 * signature letters retain the fixed/open distinction all the way to this
 * boundary so a fixed array is never accidentally passed as a handle. */
static void*dpi_array_argument_(const vvp_dpi_arg_t&arg)
{
      if (!arg.aval) return 0;
      switch (arg.type) {
	  case 'o':
	  case 'x':
	  case 'y':
	    return arg.aval;
	  case 'O':
	    return arg.aval->data;
	  case 'B':
	  case 'G':
	  case 'X':
	  case 'Y':
	    return arg.aval->elem_data;
	  default:
	    return 0;
      }
}

void vvp_dpi_load_lib(const char*path)
{
      ivl_dll_t dll = ivl_dlopen(path, true);
      if (dll == 0) {
	    fprintf(stderr, "DPI: failed to load '%s': %s\n", path, dlerror());
	    return;
      }
      dpi_libs.push_back(dll);
}

void vvp_dpi_register_lib(ivl_dll_t dll)
{
      if (dll == 0)
	    return;
	// Avoid registering the same handle twice (e.g. a module that is
	// also passed with -d): duplicate lookups are harmless but wasteful.
      for (ivl_dll_t have : dpi_libs)
	    if (have == dll)
		  return;
      dpi_libs.push_back(dll);
}

void* vvp_dpi_find_symbol(const char*name)
{
      auto it = dpi_sym_cache.find(name);
      if (it != dpi_sym_cache.end())
	    return it->second;

      for (ivl_dll_t dll : dpi_libs) {
	    void*sym = ivl_dlsym(dll, name);
	    if (sym) {
		  dpi_sym_cache[name] = sym;
		  return sym;
	    }
      }
      return 0;
}

#ifdef USE_LIBFFI

/* Annex H maps a signed SystemVerilog byte to plain C char, not signed
 * char. Plain char is unsigned on some hosts, and some ABIs distinguish
 * its zero-extension convention from signed char's sign-extension
 * convention. Keep the SystemVerilog signedness in the VVP metadata, but
 * describe the actual host C prototype exactly to libffi. */
static ffi_type*dpi_ffi_plain_char_type_(void)
{
#if CHAR_MIN < 0
      return &ffi_type_sint8;
#else
      return &ffi_type_uint8;
#endif
}

/* Recover the signed SystemVerilog byte value from its eight C object bits.
 * This is independent of whether host plain char is signed or unsigned. */
static int64_t dpi_sv_signed_byte_(unsigned char bits)
{
      return (bits & 0x80u) ? (int64_t)bits - 0x100 : (int64_t)bits;
}

/*
 * libffi marshaling: build an ffi_cif matching the exact signature and
 * dispatch. This handles arbitrary mixes of integer/real/string
 * arguments, any argument count, and all supported return kinds, with
 * the platform ABI applied by libffi (correct register classes and
 * sub-word extensions).
 */
bool vvp_dpi_call(void*sym, const char*c_name, char ret_type,
		  vvp_dpi_arg_t*args, unsigned nargs,
		  int64_t*ret_i, double*ret_r, const char**ret_s)
{
      vector<ffi_type*> atypes (nargs);
      vector<void*>     avalues(nargs);
	// For output arguments the ffi argument is a POINTER to the
	// typed scratch slot, so the pointer itself needs stable
	// storage too.
      vector<void*>     optrs  (nargs);

	// Stable, properly-typed storage for the by-value payloads that
	// ffi_call reads through avalues[]. Typed union members keep the
	// value bytes where the ffi_type expects them regardless of the
	// host endianness.
      union scratch_t {
	    char        chr; uint8_t  u8;
	    int16_t     i16; uint16_t u16;
	    int32_t     i32; uint32_t u32;
	    int64_t     i64; uint64_t u64;
	    float       flt;
	    double      dbl;
	    const char* str;
	    void*       ptr;
      };
      vector<scratch_t> vals(nargs);

      for (unsigned idx = 0 ; idx < nargs ; idx += 1) {
	    const vvp_dpi_arg_t&arg = args[idx];
	    avalues[idx] = &vals[idx];
	    switch (arg.type) {
		case 'b':
		  atypes[idx] = arg.is_unsigned? &ffi_type_uint8
		                                : dpi_ffi_plain_char_type_();
		  if (arg.is_unsigned) vals[idx].u8 = (uint8_t)arg.ival;
		  else                 vals[idx].chr = (char)(uint8_t)arg.ival;
		  break;
		case 'h':
		  atypes[idx] = arg.is_unsigned? &ffi_type_uint16 : &ffi_type_sint16;
		  if (arg.is_unsigned) vals[idx].u16 = (uint16_t)arg.ival;
		  else                 vals[idx].i16 = (int16_t)arg.ival;
		  break;
		case 'i':
		  atypes[idx] = arg.is_unsigned? &ffi_type_uint32 : &ffi_type_sint32;
		  if (arg.is_unsigned) vals[idx].u32 = (uint32_t)arg.ival;
		  else                 vals[idx].i32 = (int32_t)arg.ival;
		  break;
		case 'l':
		  atypes[idx] = arg.is_unsigned? &ffi_type_uint64 : &ffi_type_sint64;
		  vals[idx].i64 = arg.ival;
		  break;
		case 'g': // svLogic scalar: unsigned char, 4-state encoding
		  atypes[idx] = &ffi_type_uint8;
		  vals[idx].u8 = (uint8_t)arg.ival;
		  break;
		case 'p': // chandle: C void*
		  atypes[idx] = &ffi_type_pointer;
		  vals[idx].ptr = arg.pval;
		  break;
		case 'f':
		  atypes[idx] = &ffi_type_float;
		  vals[idx].flt = (float)arg.rval;
		  break;
		case 'r':
		  atypes[idx] = &ffi_type_double;
		  vals[idx].dbl = arg.rval;
		  break;
		case 's':
		  atypes[idx] = &ffi_type_pointer;
		  vals[idx].str = arg.sval;
		  break;
		case 'o': // generic dynamic/open svOpenArrayHandle
		case 'O': // generic fixed unpacked-array C pointer
		case 'B': // svBit fixed scalar unpacked-array C pointer
		case 'G': // svLogic fixed scalar unpacked-array C pointer
		case 'x': // packed bit dynamic/open svOpenArrayHandle
		case 'X': // packed bit fixed-array canonical C pointer
		case 'y': // packed logic dynamic/open svOpenArrayHandle
		case 'Y': // packed logic fixed-array canonical C pointer
		  atypes[idx] = &ffi_type_pointer;
		  vals[idx].ptr = dpi_array_argument_(arg);
		  break;
		case 'V': // svBitVecVal*  (wide 2-state packed vector)
		case 'W': // svLogicVecVal* (wide 4-state packed vector)
		  atypes[idx] = &ffi_type_pointer;
		  vals[idx].ptr = arg.vbuf;
		  break;
		default:
		  fprintf(stderr, "DPI error: '%s': unsupported argument "
			  "type letter '%c' at position %u\n",
			  c_name, arg.type, idx+1);
		  return false;
	    }

	      // Output/inout: the C parameter is a pointer to the
	      // (seeded) typed slot; the callee writes through it.
	      // Open arrays are already handles that share storage,
	      // so direction changes nothing about their marshaling.
	    if (arg.is_output && !dpi_array_pointer_arg_(arg.type)
		&& arg.type != 'V' && arg.type != 'W') {
		  optrs[idx] = &vals[idx];
		  atypes[idx] = &ffi_type_pointer;
		  avalues[idx] = &optrs[idx];
	    }
      }

      ffi_type*rtype = 0;
      switch (ret_type) {
	  case 'b': rtype = dpi_ffi_plain_char_type_(); break;
	  case 'B':
	  case 'g': rtype = &ffi_type_uint8;   break;
	  case 'h': rtype = &ffi_type_sint16;  break;
	  case 'H': rtype = &ffi_type_uint16;  break;
	  case 'i': rtype = &ffi_type_sint32;  break;
	  case 'I': rtype = &ffi_type_uint32;  break;
	  case 'l': rtype = &ffi_type_sint64;  break;
	  case 'L': rtype = &ffi_type_uint64;  break;
	  case 'p': rtype = &ffi_type_pointer; break;
	  case 'f': rtype = &ffi_type_float;   break;
	  case 'r': rtype = &ffi_type_double;  break;
	  case 's': rtype = &ffi_type_pointer; break;
	  case 'v': rtype = &ffi_type_void;    break;
	  default:
	    fprintf(stderr, "DPI error: '%s': unsupported return type "
		    "letter '%c'\n", c_name, ret_type);
	    return false;
      }

      ffi_cif cif;
      if (ffi_prep_cif(&cif, FFI_DEFAULT_ABI, nargs, rtype,
		       nargs? &atypes[0] : 0) != FFI_OK) {
	    fprintf(stderr, "DPI error: '%s': ffi_prep_cif failed\n", c_name);
	    return false;
      }

	// Return buffer: libffi requires integer returns narrower than
	// ffi_arg to be received in an ffi_arg-sized (and -aligned) slot.
      union {
	    ffi_arg     as_arg;
	    int64_t     as_i64;
	    float       as_flt;
	    double      as_dbl;
	    const char* as_str;
	    void*       as_ptr;
      } rbuf;
      rbuf.as_i64 = 0;

      ffi_call(&cif, FFI_FN(sym), &rbuf, nargs? &avalues[0] : 0);

      for (unsigned idx = 0 ; idx < nargs ; idx += 1) {
	    if (! args[idx].is_output || dpi_array_pointer_arg_(args[idx].type)
		|| args[idx].type == 'V' || args[idx].type == 'W')
		  continue;   // 'V'/'W' write in place through the buffer
	    switch (args[idx].type) {
		case 'b':
		  args[idx].ival = args[idx].is_unsigned
			? (int64_t)vals[idx].u8
			: dpi_sv_signed_byte_((unsigned char)vals[idx].chr);
		  break;
		case 'h':
		  args[idx].ival = args[idx].is_unsigned
			? (int64_t)vals[idx].u16 : (int64_t)vals[idx].i16;
		  break;
		case 'i':
		  args[idx].ival = args[idx].is_unsigned
			? (int64_t)vals[idx].u32 : (int64_t)vals[idx].i32;
		  break;
		case 'l':
		  args[idx].ival = vals[idx].i64;
		  break;
		case 'g':
		  args[idx].ival = (int64_t)vals[idx].u8;
		  break;
		case 'p':
		  args[idx].pval = vals[idx].ptr;
		  break;
		case 'f':
		  args[idx].rval = (double)vals[idx].flt;
		  break;
		case 'r':
		  args[idx].rval = vals[idx].dbl;
		  break;
		case 's':
		  args[idx].sval = vals[idx].str;
		  break;
	    }
      }

      switch (ret_type) {
	  case 'b': *ret_i = dpi_sv_signed_byte_((unsigned char)rbuf.as_arg); break;
	  case 'B':
	  case 'g': *ret_i = (uint8_t)rbuf.as_arg;   break;
	  case 'h': *ret_i = (int16_t)rbuf.as_arg;   break;
	  case 'H': *ret_i = (uint16_t)rbuf.as_arg;  break;
	  case 'i': *ret_i = (int32_t)rbuf.as_arg; break;
	  case 'I': *ret_i = (uint32_t)rbuf.as_arg; break;
	  case 'l': *ret_i = rbuf.as_i64;          break;
	  case 'L': *ret_i = (uint64_t)rbuf.as_i64; break;
	  case 'p': *ret_i = (int64_t)(uintptr_t)rbuf.as_ptr; break;
	  case 'f': *ret_r = (double)rbuf.as_flt;  break;
	  case 'r': *ret_r = rbuf.as_dbl;          break;
	  case 's': *ret_s = rbuf.as_str;          break;
	  default: break;
      }
      return true;
}

#else /* ! USE_LIBFFI */

/*
 * Legacy fallback for builds without libffi: uniform-type signatures
 * only, dispatched through a fixed set of casted function-pointer
 * shapes. Mixed integer/real signatures cannot be marshaled portably
 * this way and are diagnosed loudly instead of called with a broken
 * ABI. (Strings and integers can mix because both are passed in
 * integer registers on the supported ABIs; that is the historical
 * behavior this fallback preserves for the UVM command-line helpers.)
 */
bool vvp_dpi_call(void*sym, const char*c_name, char ret_type,
		  vvp_dpi_arg_t*args, unsigned nargs,
		  int64_t*ret_i, double*ret_r, const char**ret_s)
{
	/* The legacy dispatcher below calls non-real functions through an
	   intptr_t-return prototype. That cannot represent the Annex H char,
	   svBit, svLogic, or short-int return ABI portably (notably on Win64,
	   where the upper return-register bits may be unspecified). Refuse new
	   exact narrow-return images instead of silently making the old mismatch.
	   A libffi-enabled build handles these cases above. */
      if (ret_type == 'b' || ret_type == 'B' || ret_type == 'g'
	  || ret_type == 'h' || ret_type == 'H') {
	    fprintf(stderr, "DPI error: '%s': an 8/16-bit or scalar logic "
		    "return needs a libffi-enabled vvp build; skipping the "
		    "call.\n", c_name);
	    return false;
      }
      if (ret_type == 'f') {
	    fprintf(stderr, "DPI error: '%s': a shortreal return needs a "
		    "libffi-enabled vvp build; skipping the call.\n", c_name);
	    return false;
      }

      bool any_real = false, all_real = true;
      bool any_real_output = false;
      for (unsigned idx = 0 ; idx < nargs ; idx += 1) {
	    if (args[idx].type == 'f') {
		  fprintf(stderr, "DPI error: '%s': shortreal arguments need a "
			  "libffi-enabled vvp build; skipping the call.\n", c_name);
		  return false;
	    }
	    if (args[idx].type == 'r') {
		  any_real = true;
		  if (args[idx].is_output) any_real_output = true;
	    }
	    else                       all_real = false;
      }
      if (any_real_output) {
	    fprintf(stderr, "DPI error: '%s': real output arguments need "
		    "a libffi-enabled vvp build; skipping the call.\n",
		    c_name);
	    return false;
      }

      if (any_real && !all_real) {
	    fprintf(stderr, "DPI error: '%s': mixed real/non-real argument "
		    "signature needs a libffi-enabled vvp build; skipping "
		    "the call.\n", c_name);
	    return false;
      }
      if (nargs > 8) {
	    fprintf(stderr, "DPI error: '%s': more than 8 arguments needs "
		    "a libffi-enabled vvp build; skipping the call.\n",
		    c_name);
	    return false;
      }

      if (all_real && nargs > 0) {
	    if (ret_type != 'r') {
		  fprintf(stderr, "DPI error: '%s': real arguments with "
			  "non-real return needs a libffi-enabled vvp "
			  "build; skipping the call.\n", c_name);
		  return false;
	    }
	    double a[8] = {0};
	    for (unsigned idx = 0 ; idx < nargs ; idx += 1)
		  a[idx] = args[idx].rval;
	    typedef double(*dfn1_t)(double);
	    typedef double(*dfn2_t)(double,double);
	    typedef double(*dfn3_t)(double,double,double);
	    typedef double(*dfn4_t)(double,double,double,double);
	    typedef double(*dfn5_t)(double,double,double,double,double);
	    typedef double(*dfn6_t)(double,double,double,double,double,double);
	    typedef double(*dfn7_t)(double,double,double,double,double,double,double);
	    typedef double(*dfn8_t)(double,double,double,double,double,double,double,double);
	    switch (nargs) {
		case 1: *ret_r = ((dfn1_t)sym)(a[0]); break;
		case 2: *ret_r = ((dfn2_t)sym)(a[0],a[1]); break;
		case 3: *ret_r = ((dfn3_t)sym)(a[0],a[1],a[2]); break;
		case 4: *ret_r = ((dfn4_t)sym)(a[0],a[1],a[2],a[3]); break;
		case 5: *ret_r = ((dfn5_t)sym)(a[0],a[1],a[2],a[3],a[4]); break;
		case 6: *ret_r = ((dfn6_t)sym)(a[0],a[1],a[2],a[3],a[4],a[5]); break;
		case 7: *ret_r = ((dfn7_t)sym)(a[0],a[1],a[2],a[3],a[4],a[5],a[6]); break;
		default: *ret_r = ((dfn8_t)sym)(a[0],a[1],a[2],a[3],a[4],a[5],a[6],a[7]); break;
	    }
	    return true;
      }

	// Non-real arguments: integers, logic scalars and strings all
	// travel in pointer-width integer registers on the supported
	// ABIs, so pass them uniformly as intptr_t. Output arguments
	// pass a pointer to a typed scratch slot instead.
      union scratch_t {
	    int8_t  i8;  uint8_t  u8;
	    int16_t i16; uint16_t u16;
	    int32_t i32; uint32_t u32;
	    int64_t i64;
	    const char* str;
	    void* ptr;
      };
      scratch_t oval[8];
      memset(oval, 0, sizeof oval);
      intptr_t a[8] = {0};
      for (unsigned idx = 0 ; idx < nargs ; idx += 1) {
	    if (args[idx].is_output && !dpi_array_pointer_arg_(args[idx].type)
		&& args[idx].type != 'V' && args[idx].type != 'W') {
		  switch (args[idx].type) {
		      case 'b': oval[idx].i8  = (int8_t)args[idx].ival;  break;
		      case 'h': oval[idx].i16 = (int16_t)args[idx].ival; break;
		      case 'i': oval[idx].i32 = (int32_t)args[idx].ival; break;
		      case 'l': oval[idx].i64 = args[idx].ival;          break;
		      case 'g': oval[idx].u8  = (uint8_t)args[idx].ival; break;
		      case 'p': oval[idx].ptr = args[idx].pval;          break;
		      case 's': oval[idx].str = args[idx].sval;          break;
		  }
		  a[idx] = (intptr_t)&oval[idx];
	    } else if (args[idx].type == 's')
		  a[idx] = (intptr_t)args[idx].sval;
	    else if (args[idx].type == 'p')
		  a[idx] = (intptr_t)args[idx].pval;
	    else if (dpi_array_pointer_arg_(args[idx].type))
		  a[idx] = (intptr_t)dpi_array_argument_(args[idx]);
	    else if (args[idx].type == 'V' || args[idx].type == 'W')
		  a[idx] = (intptr_t)args[idx].vbuf;
	    else
		  a[idx] = (intptr_t)args[idx].ival;
      }

      typedef intptr_t(*fn0_t)(void);
      typedef intptr_t(*fn1_t)(intptr_t);
      typedef intptr_t(*fn2_t)(intptr_t,intptr_t);
      typedef intptr_t(*fn3_t)(intptr_t,intptr_t,intptr_t);
      typedef intptr_t(*fn4_t)(intptr_t,intptr_t,intptr_t,intptr_t);
      typedef intptr_t(*fn5_t)(intptr_t,intptr_t,intptr_t,intptr_t,intptr_t);
      typedef intptr_t(*fn6_t)(intptr_t,intptr_t,intptr_t,intptr_t,intptr_t,intptr_t);
      typedef intptr_t(*fn7_t)(intptr_t,intptr_t,intptr_t,intptr_t,intptr_t,intptr_t,intptr_t);
      typedef intptr_t(*fn8_t)(intptr_t,intptr_t,intptr_t,intptr_t,intptr_t,intptr_t,intptr_t,intptr_t);
      typedef double(*rfn0_t)(void);

      if (ret_type == 'r') {
	    if (nargs != 0) {
		  fprintf(stderr, "DPI error: '%s': real return with "
			  "non-real arguments needs a libffi-enabled vvp "
			  "build; skipping the call.\n", c_name);
		  return false;
	    }
	    *ret_r = ((rfn0_t)sym)();
	    return true;
      }

      intptr_t result = 0;
      switch (nargs) {
	  case 0: result = ((fn0_t)sym)(); break;
	  case 1: result = ((fn1_t)sym)(a[0]); break;
	  case 2: result = ((fn2_t)sym)(a[0],a[1]); break;
	  case 3: result = ((fn3_t)sym)(a[0],a[1],a[2]); break;
	  case 4: result = ((fn4_t)sym)(a[0],a[1],a[2],a[3]); break;
	  case 5: result = ((fn5_t)sym)(a[0],a[1],a[2],a[3],a[4]); break;
	  case 6: result = ((fn6_t)sym)(a[0],a[1],a[2],a[3],a[4],a[5]); break;
	  case 7: result = ((fn7_t)sym)(a[0],a[1],a[2],a[3],a[4],a[5],a[6]); break;
	  default: result = ((fn8_t)sym)(a[0],a[1],a[2],a[3],a[4],a[5],a[6],a[7]); break;
      }

      for (unsigned idx = 0 ; idx < nargs ; idx += 1) {
	    if (! args[idx].is_output || dpi_array_pointer_arg_(args[idx].type)
		|| args[idx].type == 'V' || args[idx].type == 'W')
		  continue;   // 'V'/'W' write in place through the buffer
	    switch (args[idx].type) {
		case 'b':
		  args[idx].ival = args[idx].is_unsigned
			? (int64_t)oval[idx].u8 : (int64_t)oval[idx].i8;
		  break;
		case 'h':
		  args[idx].ival = args[idx].is_unsigned
			? (int64_t)oval[idx].u16 : (int64_t)oval[idx].i16;
		  break;
		case 'i':
		  args[idx].ival = args[idx].is_unsigned
			? (int64_t)oval[idx].u32 : (int64_t)oval[idx].i32;
		  break;
		case 'l': args[idx].ival = oval[idx].i64;          break;
		case 'g': args[idx].ival = (int64_t)oval[idx].u8;  break;
		case 'p': args[idx].pval = oval[idx].ptr;          break;
		case 's': args[idx].sval = oval[idx].str;          break;
	    }
      }

      switch (ret_type) {
	  case 'b': *ret_i = (int8_t)result;       break;
	  case 'B':
	  case 'g': *ret_i = (uint8_t)result;      break;
	  case 'h': *ret_i = (int16_t)result;      break;
	  case 'H': *ret_i = (uint16_t)result;     break;
	  case 'i': *ret_i = (int32_t)result;      break;
	  case 'I': *ret_i = (uint32_t)result;     break;
	  case 'l': *ret_i = (int64_t)result;      break;
	  case 'L': *ret_i = (int64_t)(uint64_t)result; break;
	  case 'p': *ret_i = (int64_t)(uintptr_t)result; break;
	  case 's': *ret_s = (const char*)result;  break;
	  default: break;
      }
      return true;
}

#endif /* USE_LIBFFI */

/*
 * Minimal svdpi.h open-array accessors (IEEE1800-2017 Annex H.12.2),
 * exported from the vvp executable so dlopen'ed DPI libraries can
 * resolve them. One-dimensional, zero-based arrays only (the shape
 * the compiler marshals for 'o' arguments).
 */
extern "C" {

/* M10B-md: walk one level of a multidim open array: the outer word at
   idx is itself a dynamic array. Returns null when out of range or not
   multidim. */
static vvp_darray* md_inner_(const vvp_dpi_open_array_t*arr, int idx)
{
      if (!arr || !arr->outer) return 0;
      if (idx < 0 || (unsigned)idx >= arr->length) return 0;
      vvp_object_t w;
      arr->outer->get_word((unsigned)idx, w);
      return w.peek<vvp_darray>();
}

/* Return the representative array object for a dimension. Dimension 1
   is the outer object itself; deeper dimensions follow word zero because
   open fixed arrays are rectangular. */
static vvp_darray* md_dimension_(const vvp_dpi_open_array_t*arr, int dim)
{
      if (!arr || !arr->outer || dim < 1) return 0;
      vvp_darray*cur = arr->outer;
      for (int d = 1 ; cur && d < dim ; d += 1) {
	    if (cur->get_size() == 0) return 0;
	    vvp_object_t word;
	    cur->get_word(0, word);
	    cur = word.peek<vvp_darray>();
      }
      return cur;
}

int svDimensions(const void*h)
{
      const vvp_dpi_open_array_t*arr = (const vvp_dpi_open_array_t*)h;
      if (!arr) return 0;
      if (!arr->outer) return 1;
	// Count nesting depth through the first words.
      int dims = 1;
      vvp_darray*cur = md_inner_(arr, 0);
      while (cur) {
	    dims += 1;
	      // An atom-typed array is the contiguous leaf; probing it
	      // with the object-flavored get_word would just warn.
	    if (cur->dpi_elem_bytes() > 0 || cur->get_size() == 0) break;
	    vvp_object_t w;
	    cur->get_word(0, w);
	    cur = w.peek<vvp_darray>();
      }
      return dims;
}

int svSize(const void*h, int dim)
{
      const vvp_dpi_open_array_t*arr = (const vvp_dpi_open_array_t*)h;
      if (!arr) return 0;
      if (dim == 1) return (int)arr->length;
	// M10B-md: inner dimensions are queried from the first row
	// (SV unpacked arrays marshaled here are rectangular; a jagged
	// dynamic-of-dynamic reports its first row's length).
      vvp_darray*cur = md_inner_(arr, 0);
      for (int d = 2 ; cur && d < dim ; d += 1) {
	    vvp_object_t w;
	    if (cur->get_size() == 0) return 0;
	    cur->get_word(0, w);
	    cur = w.peek<vvp_darray>();
      }
      return cur ? (int)cur->get_size() : 0;
}

/*
 * M10-1/R7: array bounds (IEEE 1800-2017 H.10.2).
 *
 * A plain dynamic array is 0-based ascending, so low/left are 0 and
 * high/right are N-1. An array MARSHALED from a fixed-size one stands in
 * for that array's DECLARED range and reports it instead -- including a
 * descending range, where left > right and the increment is -1.
 *
 * A passive marshaling range does not affect a later ordinary dynamic-array
 * value. The declared range is visible only when the object has been
 * installed as an open-array formal. Multidimensional fixed actuals carry
 * and activate the range on every nested dimension.
 */
int svLeft(const void*h, int dim)
{
      const vvp_dpi_open_array_t*arr = (const vvp_dpi_open_array_t*)h;
      if (arr && arr->has_range && dim == 1) return arr->left;
      vvp_darray*dar = md_dimension_(arr, dim);
      if (dar && dar->sv_uses_declared_indexing()
	  && dar->dpi_has_decl_range())
	    return dar->dpi_decl_left();
      return 0;
}

int svRight(const void*h, int dim)
{
      const vvp_dpi_open_array_t*arr = (const vvp_dpi_open_array_t*)h;
      if (arr && arr->has_range && dim == 1) return arr->right;
      vvp_darray*dar = md_dimension_(arr, dim);
      if (dar && dar->sv_uses_declared_indexing()
	  && dar->dpi_has_decl_range())
	    return dar->dpi_decl_right();
      return svSize(h, dim) - 1;
}

int svLow(const void*h, int dim)
{
      int left  = svLeft(h, dim);
      int right = svRight(h, dim);
      return (left <= right) ? left : right;
}

int svHigh(const void*h, int dim)
{
      int left  = svLeft(h, dim);
      int right = svRight(h, dim);
      return (left <= right) ? right : left;
}

/*
 * IEEE 1800-2017 H.10.2 uses the array-query $increment semantics: this is
 * the right-to-left increment, +1 when left >= right and -1 otherwise. A
 * traversal from left to right therefore subtracts svIncrement. The old
 * natural-direction interpretation happened to work for ascending arrays
 * but disagreed with both $increment and descending open arrays.
 */
int svIncrement(const void*h, int dim)
{
      int left  = svLeft(h, dim);
      int right = svRight(h, dim);
      return (left >= right) ? 1 : -1;
}

/*
 * H.10.1: the TOTAL size of the array in bytes.
 *
 * This was `length * elem_bytes', which is right for a 1-D array but
 * returned 0 for a multi-dimensional one: the outer array of a nesting is
 * non-contiguous, so its elem_bytes is 0. A C model sizing a buffer from
 * it silently got zero. Walk every dimension and use the LEAF element
 * size, which is where the contiguous atom storage actually is.
 */
int svSizeOfArray(const void*h)
{
      const vvp_dpi_open_array_t*arr = (const vvp_dpi_open_array_t*)h;
      if (!arr) return 0;

	if (!arr->outer)
	      return arr->data ? (int)(arr->length * arr->elem_bytes) : 0;

      int dims = svDimensions(h);
      size_t words = 1;
      for (int d = 1 ; d <= dims ; d += 1) {
	    int n = svSize(h, d);
	    if (n <= 0) return 0;
	    words *= (size_t)n;
      }

	// Descend to the leaf, whose dpi_elem_bytes() is the atom size.
      vvp_darray*leaf = md_inner_(arr, 0);
      while (leaf && leaf->dpi_elem_bytes() == 0 && leaf->get_size() > 0) {
	    vvp_object_t w;
	    leaf->get_word(0, w);
	    vvp_darray*next = w.peek<vvp_darray>();
	    if (!next) break;
	    leaf = next;
      }
      unsigned ebytes = leaf ? leaf->dpi_elem_bytes() : 0;
      if (ebytes == 0) return 0;

      return (int)(words * ebytes);
}

/*
 * H.10.3: element access uses the DECLARED index, so an array marshaled
 * from `int a[3:10]' is addressed 3..10 and one from `int a[10:3]' is
 * addressed 10..3. Installing a fixed-derived value into an open-array
 * formal canonicalizes its storage to numeric-low first; passive native-SV
 * copies remain left-to-right and are never exposed through this accessor.
 * The active DPI translation is therefore the same for either declaration
 * direction: subtract the low bound.
 *
 * This has to agree with svLow/svHigh, or a C model looping
 * `for (i = svLow; i <= svHigh; i++) svGetArrElemPtr1(h, i)' reads the
 * wrong elements and runs off the end. A plain dynamic array has no
 * declared range, so its low bound is 0 and this is the identity.
 */
static int dpi_canon_index_(const vvp_dpi_open_array_t*arr, int indx1)
{
      if (!arr || !arr->has_range) return indx1;
      int low = (arr->left <= arr->right) ? arr->left : arr->right;
      return indx1 - low;
}

static int dpi_canon_darray_index_(const vvp_darray*arr, int index)
{
      if (!arr || !arr->sv_uses_declared_indexing()
	  || !arr->dpi_has_decl_range())
	    return index;
      int left = arr->dpi_decl_left();
      int right = arr->dpi_decl_right();
      int low = left <= right ? left : right;
      return index - low;
}

void* svGetArrElemPtr1(const void*h, int indx1)
{
      const vvp_dpi_open_array_t*arr = (const vvp_dpi_open_array_t*)h;
      if (!arr) return 0;
      void*base = arr->elem_data ? arr->elem_data : arr->data;
      if (!base) return 0;
      int k = dpi_canon_index_(arr, indx1);
      if (k < 0 || (unsigned)k >= arr->length) return 0;
      return (char*)base + (size_t)k * arr->elem_bytes;
}

/* M10B-md: 2-D element access — outer word indx1 is an inner dynamic
   array with contiguous atom storage; index indx2 within it. */
void* svGetArrElemPtr2(const void*h, int indx1, int indx2)
{
      const vvp_dpi_open_array_t*arr = (const vvp_dpi_open_array_t*)h;
      vvp_darray*inner = md_inner_(arr, dpi_canon_index_(arr, indx1));
      if (!inner) return 0;
      unsigned eb = inner->dpi_elem_bytes();
      void*base = inner->dpi_raw_data();
      if (eb == 0 || base == 0) return 0;
      int k2 = dpi_canon_darray_index_(inner, indx2);
      if (k2 < 0 || (size_t)k2 >= inner->get_size()) return 0;
      return (char*)base + (size_t)k2 * eb;
}

/* M10B-md: 3-D element access — two object-walk levels then the
   contiguous innermost array. */
void* svGetArrElemPtr3(const void*h, int indx1, int indx2, int indx3)
{
      const vvp_dpi_open_array_t*arr = (const vvp_dpi_open_array_t*)h;
      vvp_darray*mid = md_inner_(arr, dpi_canon_index_(arr, indx1));
      if (!mid) return 0;
      int k2 = dpi_canon_darray_index_(mid, indx2);
      if (k2 < 0 || (size_t)k2 >= mid->get_size()) return 0;
      vvp_object_t w;
      mid->get_word((unsigned)k2, w);
      vvp_darray*inner = w.peek<vvp_darray>();
      if (!inner) return 0;
      unsigned eb = inner->dpi_elem_bytes();
      void*base = inner->dpi_raw_data();
      if (eb == 0 || base == 0) return 0;
      int k3 = dpi_canon_darray_index_(inner, indx3);
      if (k3 < 0 || (size_t)k3 >= inner->get_size()) return 0;
      return (char*)base + (size_t)k3 * eb;
}

void* svGetArrElemPtr(const void*h, int indx1, ...)
{
      const vvp_dpi_open_array_t*arr = (const vvp_dpi_open_array_t*)h;
      if (arr && arr->outer) {
	    va_list ap;
	    va_start(ap, indx1);
	    int indx2 = va_arg(ap, int);
	    int dims = svDimensions(h);
	    void*r;
	    if (dims >= 3) {
		  int indx3 = va_arg(ap, int);
		  r = svGetArrElemPtr3(h, indx1, indx2, indx3);
	    } else {
		  r = svGetArrElemPtr2(h, indx1, indx2);
	    }
	    va_end(ap);
	    return r;
      }
      return svGetArrElemPtr1(h, indx1);
}

/*
 * H.12.3 canonical-copy accessors.
 *
 * svGetArrElemPtr is only available when an element has a directly usable C
 * layout. Packed bit/logic vectors are deliberately stored in vvp's native
 * vector classes instead, so the standard svGet/Put*ArrElem*VecVal routines
 * must translate between that representation and svdpi.h's canonical 32-bit
 * words. Keeping the live container in the open-array handle also makes these
 * accessors work for atom elements without relying on host byte order.
 */
static bool dpi_packed_container_(vvp_darray*array)
{
      if (!array || array->dpi_elem_is_real()) return false;
      if (array->dpi_elem_bytes() > 0) return true;
      return dynamic_cast<vvp_darray_vec2*>(array)
	  || dynamic_cast<vvp_darray_vec4*>(array)
	  || dynamic_cast<vvp_queue_vec4*>(array);
}

static bool dpi_element_slot_(const void*h, const vector<int>&indices,
			      vvp_darray*&array, unsigned&word)
{
      const vvp_dpi_open_array_t*open =
	  (const vvp_dpi_open_array_t*)h;
      if (!open || indices.empty()) return false;

      if (indices.size() == 1) {
	    array = open->storage;
	    int idx = dpi_canon_index_(open, indices[0]);
	    if (!dpi_packed_container_(array) || idx < 0
		|| (size_t)idx >= array->get_size())
		  return false;
	    word = (unsigned)idx;
	    return true;
      }

      vvp_darray*cur = open->outer;
      if (!cur) return false;
      int idx = dpi_canon_index_(open, indices[0]);
      if (idx < 0 || (size_t)idx >= cur->get_size()) return false;

      for (size_t dim = 1 ; dim < indices.size() ; dim += 1) {
	    vvp_object_t obj;
	    cur->get_word((unsigned)idx, obj);
	    cur = obj.peek<vvp_darray>();
	    if (!cur) return false;
	    idx = dpi_canon_darray_index_(cur, indices[dim]);
	    if (idx < 0 || (size_t)idx >= cur->get_size()) return false;
	    if (dim + 1 == indices.size()) {
		  if (!dpi_packed_container_(cur)) return false;
		  array = cur;
		  word = (unsigned)idx;
		  return true;
	    }
      }
      return false;
}

static vector<int> dpi_var_indices_(const void*h, int indx1, va_list ap)
{
      int dims = svDimensions(h);
      vector<int> indices;
      if (dims <= 0) return indices;
      indices.reserve((size_t)dims);
      indices.push_back(indx1);
      for (int dim = 1 ; dim < dims ; dim += 1)
	    indices.push_back(va_arg(ap, int));
      return indices;
}

static bool dpi_get_packed_(const void*h, const vector<int>&indices,
			    vvp_vector4_t&value)
{
      const vvp_dpi_open_array_t*open =
	    static_cast<const vvp_dpi_open_array_t*>(h);
      if (open && open->packed_scratch && indices.size() == 1) {
	    int idx = dpi_canon_index_(open, indices[0]);
	    if (!open->elem_data || idx < 0 || (unsigned)idx >= open->length
		|| open->packed_width == 0)
		  return false;
	    unsigned value_words = (open->packed_width + 31) / 32;
	    unsigned stride_words = value_words
		  * (open->packed_four_state ? 2 : 1);
	    const uint32_t*src = static_cast<const uint32_t*>(open->elem_data)
		  + (size_t)idx * stride_words;
	    value = vvp_vector4_t(open->packed_width, BIT4_0);
	    for (unsigned bit = 0; bit < open->packed_width; bit += 1) {
		  unsigned word = bit / 32;
		  uint32_t mask = (uint32_t)1 << (bit % 32);
		  vvp_bit4_t val;
		  if (open->packed_four_state) {
			bool aval = (src[2*word] & mask) != 0;
			bool bval = (src[2*word + 1] & mask) != 0;
			val = bval ? (aval ? BIT4_X : BIT4_Z)
			           : (aval ? BIT4_1 : BIT4_0);
		  } else {
			val = (src[word] & mask) ? BIT4_1 : BIT4_0;
		  }
		  value.set_bit(bit, val);
	    }
	    return true;
      }

      vvp_darray*array = 0;
      unsigned word = 0;
      if (!dpi_element_slot_(h, indices, array, word)) return false;
      array->get_word(word, value);
      return value.size() > 0;
}

static bool dpi_put_packed_(const void*h, const vector<int>&indices,
			    const vvp_vector4_t&value)
{
      const vvp_dpi_open_array_t*open =
	    static_cast<const vvp_dpi_open_array_t*>(h);
      if (open && open->packed_scratch && indices.size() == 1) {
	    int idx = dpi_canon_index_(open, indices[0]);
	    if (!open->elem_data || idx < 0 || (unsigned)idx >= open->length
		|| open->packed_width == 0)
		  return false;
	    unsigned value_words = (open->packed_width + 31) / 32;
	    unsigned stride_words = value_words
		  * (open->packed_four_state ? 2 : 1);
	    uint32_t*dst = static_cast<uint32_t*>(open->elem_data)
		  + (size_t)idx * stride_words;
	    memset(dst, 0, stride_words * sizeof(*dst));
	    unsigned limit = value.size() < open->packed_width
		  ? value.size() : open->packed_width;
	    for (unsigned bit = 0; bit < limit; bit += 1) {
		  vvp_bit4_t val = value.value(bit);
		  unsigned word = bit / 32;
		  uint32_t mask = (uint32_t)1 << (bit % 32);
		  if (open->packed_four_state) {
			if (val == BIT4_1 || val == BIT4_X)
			      dst[2*word] |= mask;
			if (val == BIT4_Z || val == BIT4_X)
			      dst[2*word + 1] |= mask;
		  } else if (val == BIT4_1) {
			dst[word] |= mask;
		  }
	    }
	    return true;
      }

      vvp_darray*array = 0;
      unsigned word = 0;
      if (!dpi_element_slot_(h, indices, array, word)) return false;
      array->set_word(word, value);
      return true;
}

static void dpi_get_bit_vec_(svBitVecVal*d, const void*h,
			     const vector<int>&indices)
{
      if (!d) return;
      vvp_vector4_t value;
      if (!dpi_get_packed_(h, indices, value)) {
	    d[0] = 0;
	    return;
      }
      unsigned words = (value.size() + 31) / 32;
      memset(d, 0, words * sizeof(*d));
      for (unsigned bit = 0 ; bit < value.size() ; bit += 1)
	    if (value.value(bit) == BIT4_1)
		  d[bit / 32] |= (uint32_t)1 << (bit % 32);
}

static void dpi_get_logic_vec_(svLogicVecVal*d, const void*h,
			       const vector<int>&indices)
{
      if (!d) return;
      vvp_vector4_t value;
      if (!dpi_get_packed_(h, indices, value)) {
	    d[0].aval = 0;
	    d[0].bval = 0;
	    return;
      }
      unsigned words = (value.size() + 31) / 32;
      memset(d, 0, words * sizeof(*d));
      for (unsigned bit = 0 ; bit < value.size() ; bit += 1) {
	    vvp_bit4_t val = value.value(bit);
	    uint32_t mask = (uint32_t)1 << (bit % 32);
	    if (val == BIT4_1 || val == BIT4_X)
		  d[bit / 32].aval |= mask;
	    if (val == BIT4_Z || val == BIT4_X)
		  d[bit / 32].bval |= mask;
      }
}

static void dpi_put_bit_vec_(const void*h, const svBitVecVal*s,
			     const vector<int>&indices)
{
      if (!s) return;
      vvp_vector4_t old;
      if (!dpi_get_packed_(h, indices, old)) return;
      vvp_vector4_t value(old.size(), BIT4_0);
      for (unsigned bit = 0 ; bit < value.size() ; bit += 1)
	    if (s[bit / 32] & ((uint32_t)1 << (bit % 32)))
		  value.set_bit(bit, BIT4_1);
      dpi_put_packed_(h, indices, value);
}

static void dpi_put_logic_vec_(const void*h, const svLogicVecVal*s,
			       const vector<int>&indices)
{
      if (!s) return;
      vvp_vector4_t old;
      if (!dpi_get_packed_(h, indices, old)) return;
      vvp_vector4_t value(old.size(), BIT4_0);
      for (unsigned bit = 0 ; bit < value.size() ; bit += 1) {
	    uint32_t mask = (uint32_t)1 << (bit % 32);
	    bool aval = ((uint32_t)s[bit / 32].aval & mask) != 0;
	    bool bval = ((uint32_t)s[bit / 32].bval & mask) != 0;
	    vvp_bit4_t val = bval ? (aval ? BIT4_X : BIT4_Z)
				  : (aval ? BIT4_1 : BIT4_0);
	    value.set_bit(bit, val);
      }
      dpi_put_packed_(h, indices, value);
}

void svGetBitArrElem1VecVal(svBitVecVal*d, const svOpenArrayHandle s,
			    int indx1)
{
      dpi_get_bit_vec_(d, s, vector<int>{indx1});
}

void svGetBitArrElem2VecVal(svBitVecVal*d, const svOpenArrayHandle s,
			    int indx1, int indx2)
{
      dpi_get_bit_vec_(d, s, vector<int>{indx1, indx2});
}

void svGetBitArrElem3VecVal(svBitVecVal*d, const svOpenArrayHandle s,
			    int indx1, int indx2, int indx3)
{
      dpi_get_bit_vec_(d, s, vector<int>{indx1, indx2, indx3});
}

void svGetBitArrElemVecVal(svBitVecVal*d, const svOpenArrayHandle s,
			   int indx1, ...)
{
      va_list ap;
      va_start(ap, indx1);
      vector<int> indices = dpi_var_indices_(s, indx1, ap);
      va_end(ap);
      dpi_get_bit_vec_(d, s, indices);
}

void svGetLogicArrElem1VecVal(svLogicVecVal*d, const svOpenArrayHandle s,
			      int indx1)
{
      dpi_get_logic_vec_(d, s, vector<int>{indx1});
}

void svGetLogicArrElem2VecVal(svLogicVecVal*d, const svOpenArrayHandle s,
			      int indx1, int indx2)
{
      dpi_get_logic_vec_(d, s, vector<int>{indx1, indx2});
}

void svGetLogicArrElem3VecVal(svLogicVecVal*d, const svOpenArrayHandle s,
			      int indx1, int indx2, int indx3)
{
      dpi_get_logic_vec_(d, s, vector<int>{indx1, indx2, indx3});
}

void svGetLogicArrElemVecVal(svLogicVecVal*d, const svOpenArrayHandle s,
			     int indx1, ...)
{
      va_list ap;
      va_start(ap, indx1);
      vector<int> indices = dpi_var_indices_(s, indx1, ap);
      va_end(ap);
      dpi_get_logic_vec_(d, s, indices);
}

void svPutBitArrElem1VecVal(const svOpenArrayHandle d, const svBitVecVal*s,
			    int indx1)
{
      dpi_put_bit_vec_(d, s, vector<int>{indx1});
}

void svPutBitArrElem2VecVal(const svOpenArrayHandle d, const svBitVecVal*s,
			    int indx1, int indx2)
{
      dpi_put_bit_vec_(d, s, vector<int>{indx1, indx2});
}

void svPutBitArrElem3VecVal(const svOpenArrayHandle d, const svBitVecVal*s,
			    int indx1, int indx2, int indx3)
{
      dpi_put_bit_vec_(d, s, vector<int>{indx1, indx2, indx3});
}

void svPutBitArrElemVecVal(const svOpenArrayHandle d, const svBitVecVal*s,
			   int indx1, ...)
{
      va_list ap;
      va_start(ap, indx1);
      vector<int> indices = dpi_var_indices_(d, indx1, ap);
      va_end(ap);
      dpi_put_bit_vec_(d, s, indices);
}

void svPutLogicArrElem1VecVal(const svOpenArrayHandle d,
			      const svLogicVecVal*s, int indx1)
{
      dpi_put_logic_vec_(d, s, vector<int>{indx1});
}

void svPutLogicArrElem2VecVal(const svOpenArrayHandle d,
			      const svLogicVecVal*s, int indx1, int indx2)
{
      dpi_put_logic_vec_(d, s, vector<int>{indx1, indx2});
}

void svPutLogicArrElem3VecVal(const svOpenArrayHandle d,
			      const svLogicVecVal*s, int indx1, int indx2,
			      int indx3)
{
      dpi_put_logic_vec_(d, s, vector<int>{indx1, indx2, indx3});
}

void svPutLogicArrElemVecVal(const svOpenArrayHandle d,
			     const svLogicVecVal*s, int indx1, ...)
{
      va_list ap;
      va_start(ap, indx1);
      vector<int> indices = dpi_var_indices_(d, indx1, ap);
      va_end(ap);
      dpi_put_logic_vec_(d, s, indices);
}

static svBit dpi_get_bit_scalar_(const void*h, const vector<int>&indices)
{
      vvp_vector4_t value;
      if (!dpi_get_packed_(h, indices, value) || value.size() == 0)
	    return sv_0;
      return value.value(0) == BIT4_1 ? sv_1 : sv_0;
}

static svLogic dpi_get_logic_scalar_(const void*h, const vector<int>&indices)
{
      vvp_vector4_t value;
      if (!dpi_get_packed_(h, indices, value) || value.size() == 0)
	    return sv_x;
      switch (value.value(0)) {
	  case BIT4_0: return sv_0;
	  case BIT4_1: return sv_1;
	  case BIT4_Z: return sv_z;
	  case BIT4_X: return sv_x;
      }
      return sv_x;
}

static void dpi_put_bit_scalar_(const void*h, svBit bit,
				const vector<int>&indices)
{
      vvp_vector4_t value;
      if (!dpi_get_packed_(h, indices, value) || value.size() == 0) return;
      value.set_bit(0, (bit & 1) ? BIT4_1 : BIT4_0);
      dpi_put_packed_(h, indices, value);
}

static void dpi_put_logic_scalar_(const void*h, svLogic logic,
				  const vector<int>&indices)
{
      vvp_vector4_t value;
      if (!dpi_get_packed_(h, indices, value) || value.size() == 0) return;
      static const vvp_bit4_t map[4] = {BIT4_0, BIT4_1, BIT4_Z, BIT4_X};
      value.set_bit(0, map[logic & 3]);
      dpi_put_packed_(h, indices, value);
}

svBit svGetBitArrElem1(const svOpenArrayHandle s, int indx1)
{ return dpi_get_bit_scalar_(s, vector<int>{indx1}); }
svBit svGetBitArrElem2(const svOpenArrayHandle s, int indx1, int indx2)
{ return dpi_get_bit_scalar_(s, vector<int>{indx1, indx2}); }
svBit svGetBitArrElem3(const svOpenArrayHandle s, int indx1, int indx2,
		       int indx3)
{ return dpi_get_bit_scalar_(s, vector<int>{indx1, indx2, indx3}); }
svBit svGetBitArrElem(const svOpenArrayHandle s, int indx1, ...)
{
      va_list ap; va_start(ap, indx1);
      vector<int> indices = dpi_var_indices_(s, indx1, ap);
      va_end(ap);
      return dpi_get_bit_scalar_(s, indices);
}

svLogic svGetLogicArrElem1(const svOpenArrayHandle s, int indx1)
{ return dpi_get_logic_scalar_(s, vector<int>{indx1}); }
svLogic svGetLogicArrElem2(const svOpenArrayHandle s, int indx1, int indx2)
{ return dpi_get_logic_scalar_(s, vector<int>{indx1, indx2}); }
svLogic svGetLogicArrElem3(const svOpenArrayHandle s, int indx1, int indx2,
			   int indx3)
{ return dpi_get_logic_scalar_(s, vector<int>{indx1, indx2, indx3}); }
svLogic svGetLogicArrElem(const svOpenArrayHandle s, int indx1, ...)
{
      va_list ap; va_start(ap, indx1);
      vector<int> indices = dpi_var_indices_(s, indx1, ap);
      va_end(ap);
      return dpi_get_logic_scalar_(s, indices);
}

void svPutBitArrElem1(const svOpenArrayHandle d, svBit value, int indx1)
{ dpi_put_bit_scalar_(d, value, vector<int>{indx1}); }
void svPutBitArrElem2(const svOpenArrayHandle d, svBit value, int indx1,
		      int indx2)
{ dpi_put_bit_scalar_(d, value, vector<int>{indx1, indx2}); }
void svPutBitArrElem3(const svOpenArrayHandle d, svBit value, int indx1,
		      int indx2, int indx3)
{ dpi_put_bit_scalar_(d, value, vector<int>{indx1, indx2, indx3}); }
void svPutBitArrElem(const svOpenArrayHandle d, svBit value, int indx1, ...)
{
      va_list ap; va_start(ap, indx1);
      vector<int> indices = dpi_var_indices_(d, indx1, ap);
      va_end(ap);
      dpi_put_bit_scalar_(d, value, indices);
}

void svPutLogicArrElem1(const svOpenArrayHandle d, svLogic value, int indx1)
{ dpi_put_logic_scalar_(d, value, vector<int>{indx1}); }
void svPutLogicArrElem2(const svOpenArrayHandle d, svLogic value, int indx1,
			int indx2)
{ dpi_put_logic_scalar_(d, value, vector<int>{indx1, indx2}); }
void svPutLogicArrElem3(const svOpenArrayHandle d, svLogic value, int indx1,
			int indx2, int indx3)
{ dpi_put_logic_scalar_(d, value, vector<int>{indx1, indx2, indx3}); }
void svPutLogicArrElem(const svOpenArrayHandle d, svLogic value, int indx1, ...)
{
      va_list ap; va_start(ap, indx1);
      vector<int> indices = dpi_var_indices_(d, indx1, ap);
      va_end(ap);
      dpi_put_logic_scalar_(d, value, indices);
}

void* svGetArrayPtr(const void*h)
{
      const vvp_dpi_open_array_t*arr = (const vvp_dpi_open_array_t*)h;
      return arr ? arr->data : 0;
}

} /* extern "C" */
