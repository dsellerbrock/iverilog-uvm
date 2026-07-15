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
#endif

using namespace std;

static vector<ivl_dll_t> dpi_libs;
static map<string,void*> dpi_sym_cache;

void vvp_dpi_load_lib(const char*path)
{
      ivl_dll_t dll = ivl_dlopen(path, true);
      if (dll == 0) {
	    fprintf(stderr, "DPI: failed to load '%s': %s\n", path, dlerror());
	    return;
      }
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
	    int8_t      i8;  uint8_t  u8;
	    int16_t     i16; uint16_t u16;
	    int32_t     i32; uint32_t u32;
	    int64_t     i64; uint64_t u64;
	    double      dbl;
	    const char* ptr;
      };
      vector<scratch_t> vals(nargs);

      for (unsigned idx = 0 ; idx < nargs ; idx += 1) {
	    const vvp_dpi_arg_t&arg = args[idx];
	    avalues[idx] = &vals[idx];
	    switch (arg.type) {
		case 'b':
		  atypes[idx] = arg.is_unsigned? &ffi_type_uint8 : &ffi_type_sint8;
		  if (arg.is_unsigned) vals[idx].u8 = (uint8_t)arg.ival;
		  else                 vals[idx].i8 = (int8_t)arg.ival;
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
		case 'r':
		  atypes[idx] = &ffi_type_double;
		  vals[idx].dbl = arg.rval;
		  break;
		case 's':
		  atypes[idx] = &ffi_type_pointer;
		  vals[idx].ptr = arg.sval;
		  break;
		default:
		  fprintf(stderr, "DPI error: '%s': unsupported argument "
			  "type letter '%c' at position %u\n",
			  c_name, arg.type, idx+1);
		  return false;
	    }

	      // Output/inout: the C parameter is a pointer to the
	      // (seeded) typed slot; the callee writes through it.
	    if (arg.is_output) {
		  optrs[idx] = &vals[idx];
		  atypes[idx] = &ffi_type_pointer;
		  avalues[idx] = &optrs[idx];
	    }
      }

      ffi_type*rtype = 0;
      switch (ret_type) {
	  case 'i': rtype = &ffi_type_sint32;  break;
	  case 'l': rtype = &ffi_type_sint64;  break;
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
	    double      as_dbl;
	    const char* as_str;
      } rbuf;
      rbuf.as_i64 = 0;

      ffi_call(&cif, FFI_FN(sym), &rbuf, nargs? &avalues[0] : 0);

      for (unsigned idx = 0 ; idx < nargs ; idx += 1) {
	    if (! args[idx].is_output)
		  continue;
	    switch (args[idx].type) {
		case 'b':
		  args[idx].ival = args[idx].is_unsigned
			? (int64_t)vals[idx].u8 : (int64_t)vals[idx].i8;
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
		case 'r':
		  args[idx].rval = vals[idx].dbl;
		  break;
		case 's':
		  args[idx].sval = vals[idx].ptr;
		  break;
	    }
      }

      switch (ret_type) {
	  case 'i': *ret_i = (int32_t)rbuf.as_arg; break;
	  case 'l': *ret_i = rbuf.as_i64;          break;
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
      bool any_real = false, all_real = true;
      bool any_real_output = false;
      for (unsigned idx = 0 ; idx < nargs ; idx += 1) {
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
	    const char* ptr;
      };
      scratch_t oval[8];
      memset(oval, 0, sizeof oval);
      intptr_t a[8] = {0};
      for (unsigned idx = 0 ; idx < nargs ; idx += 1) {
	    if (args[idx].is_output) {
		  switch (args[idx].type) {
		      case 'b': oval[idx].i8  = (int8_t)args[idx].ival;  break;
		      case 'h': oval[idx].i16 = (int16_t)args[idx].ival; break;
		      case 'i': oval[idx].i32 = (int32_t)args[idx].ival; break;
		      case 'l': oval[idx].i64 = args[idx].ival;          break;
		      case 'g': oval[idx].u8  = (uint8_t)args[idx].ival; break;
		      case 's': oval[idx].ptr = args[idx].sval;          break;
		  }
		  a[idx] = (intptr_t)&oval[idx];
	    } else if (args[idx].type == 's')
		  a[idx] = (intptr_t)args[idx].sval;
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
	    if (! args[idx].is_output)
		  continue;
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
		case 's': args[idx].sval = oval[idx].ptr;          break;
	    }
      }

      switch (ret_type) {
	  case 'i': *ret_i = (int32_t)result;      break;
	  case 'l': *ret_i = (int64_t)result;      break;
	  case 's': *ret_s = (const char*)result;  break;
	  default: break;
      }
      return true;
}

#endif /* USE_LIBFFI */
