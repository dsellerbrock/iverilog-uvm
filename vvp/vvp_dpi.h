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
struct vvp_dpi_arg_t {
      char type;
      bool is_unsigned;
      bool is_output;
      int64_t ival;
      double rval;
      const char* sval;
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
