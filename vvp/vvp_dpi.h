#ifndef IVL_vvp_dpi_H
#define IVL_vvp_dpi_H

# include  <cstdint>

extern void vvp_dpi_load_lib(const char*path);
extern void* vvp_dpi_find_symbol(const char*name);

/*
 * One marshaled DPI argument. "type" is the base letter from the
 * compiler-emitted signature string:
 *   'b' int8   'h' int16   'i' int32   'l' int64 (longint/chandle)
 *   'g' svLogic scalar (unsigned char, 4-state encoding 0/1/2=x/3=z)
 *   'r' double 's' const char*
 * is_unsigned selects the unsigned variant of the integer letters.
 * is_output marks output/inout arguments: they are passed by pointer
 * (seeded with the incoming payload) and the callee-written value is
 * stored back into this struct after the call.
 * Integer payloads (including 'g') travel in ival; 'r' in rval; 's'
 * in sval (storage owned by the caller, must outlive the call; for
 * outputs the returned pointer is callee-owned — copy it before the
 * next DPI call).
 */
/*
 * The concrete object behind an svOpenArrayHandle ('o' arguments):
 * a one-dimensional, zero-based view of contiguous element storage
 * shared with the simulator's dynamic array. C-side writes through
 * svGetArrElemPtr land directly in simulation storage.
 */
class vvp_darray;

struct vvp_dpi_open_array_t {
      void* data;
      unsigned length;
      unsigned elem_bytes;
      bool elem_is_real;
	// M10B-md: for a MULTI-dimensional open array (an object array
	// whose words are inner dynamic arrays), the accessors walk the
	// live object tree from here instead of using data/elem_bytes
	// (the outer array is non-contiguous). Null for 1-D arrays.
      vvp_darray* outer;
};

struct vvp_dpi_arg_t {
      char type;
      bool is_unsigned;
      bool is_output;
      int64_t ival;
      double rval;
      const char* sval;
      vvp_dpi_open_array_t* aval; // 'o' only: the open-array handle
      uint32_t* vbuf;             // 'V'/'W': packed vector buffer
				  //   'V' svBitVecVal[]  (2-state, one word/32 bits)
				  //   'W' svLogicVecVal[] (4-state, aval,bval pairs)
      unsigned  vwid;             // 'V'/'W': vector width in bits
};

/*
 * Call the C function at sym with the marshaled argument list.
 * ret_type is one of 'i' (int32), 'l' (int64), 'r' (double),
 * 's' (const char*), 'v' (void); the result is written through the
 * matching ret_* pointer. Output arguments are updated in args[].
 * Returns false (with a diagnostic naming c_name) if the signature
 * cannot be marshaled on this build.
 */
extern bool vvp_dpi_call(void*sym, const char*c_name, char ret_type,
			 vvp_dpi_arg_t*args, unsigned nargs,
			 int64_t*ret_i, double*ret_r, const char**ret_s);

#endif /* IVL_vvp_dpi_H */
