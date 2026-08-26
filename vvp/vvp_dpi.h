#ifndef IVL_vvp_dpi_H
#define IVL_vvp_dpi_H

# include  <cstdint>
# include  "ivl_dlfcn.h"

extern void vvp_dpi_load_lib(const char*path);

/*
 * Register an already-dlopen'ed shared object as a source of DPI import
 * symbols. This lets a loadable VPI module (loaded through the normal
 * `:vpi_module`/`-m` path) also provide the C functions that SystemVerilog
 * `import "DPI-C"` declarations resolve against, so the standard UVM DPI
 * umbrella needs neither a `-d` argument nor a separate load mechanism.
 * The handle is borrowed, not owned: the module loader keeps ownership and
 * closes it at shutdown.
 */
extern void vvp_dpi_register_lib(ivl_dll_t dll);

extern void* vvp_dpi_find_symbol(const char*name);

/*
 * One marshaled DPI argument. "type" is the base letter from the
 * compiler-emitted signature string:
 *   'b' int8   'h' int16   'i' int32   'l' int64 (longint)
 *   'p' void* (chandle)
 *   'g' svLogic scalar (unsigned char, 4-state encoding 0/1/2=Z/3=X)
 *   'B' svBit fixed scalar unpacked-array C pointer
 *   'G' svLogic fixed scalar unpacked-array C pointer
 *   'r' double 's' const char*
 * is_unsigned selects the unsigned variant of the integer letters.
 * is_output marks output/inout arguments: they are passed by pointer
 * (seeded with the incoming payload) and the callee-written value is
 * stored back into this struct after the call.
 * Integer payloads (including 'g') travel in ival; 'p' in pval; 'r' in
 * rval; 's' in sval (storage owned by the caller, must outlive the call; for
 * outputs the returned pointer is callee-owned — copy it before the
 * next DPI call).
 */
/*
 * The concrete array view behind an svOpenArrayHandle (lower-case 'o'/'x'/'y')
 * or a fixed unpacked-array C pointer (upper-case 'O'/'B'/'G'/'X'/'Y').
 * Directly representable one-dimensional elements expose shared storage;
 * packed and multidimensional elements retain their live container for the
 * standard canonical-copy accessors.
 */
class vvp_darray;

struct vvp_dpi_open_array_t {
	// Whole-array direct C layout. This remains null for a queue and for
	// packed vector storage whose native representation is not Annex H layout.
      void* data;
	// Per-element canonical storage. Unlike data, this may be a call-scoped
	// scratch buffer even when the actual container has no whole-array layout.
      void* elem_data;
      unsigned length;
      unsigned elem_bytes;
      bool elem_is_real;
	// A fixed unpacked array of scalar bit/logic values uses a byte per
	// element at the C ABI boundary. The scratch buffer normalizes vvp's
	// internal scalar representation and is copied back after output/inout.
      bool scalar_scratch;
      bool scalar_four_state;
	// A packed bit/logic element needs Annex H canonical storage, which may
	// differ from vvp's native representation and is necessarily a copy for a
	// queue. The marshaler owns data for the duration of the DPI call and
	// copies it back for output/inout arguments.
      bool packed_scratch;
      unsigned packed_width;
      bool packed_four_state;
	// The live simulator container. Unlike data, this is also available
	// for packed vector elements whose canonical DPI representation must
	// be copied with svGet/Put{Bit,Logic}ArrElem*VecVal.
      vvp_darray* storage;
	// M10B-md: for a MULTI-dimensional open array (an object array
	// whose words are inner dynamic arrays), the accessors walk the
	// live object tree from here instead of using data/elem_bytes
	// (the outer array is non-contiguous). Null for 1-D arrays.
      vvp_darray* outer;
	// M10-1: declared range of dimension 1 when the array was
	// marshaled from a fixed-size array (H.10.2). has_range false
	// means an ordinary 0-based dynamic array.
      bool has_range;
      int  left;
      int  right;
};

struct vvp_dpi_arg_t {
      char type;
      bool is_unsigned;
      bool is_output;
      int64_t ival;
      double rval;
      const char* sval;
      void* pval;                    // 'p': chandle / C void*
      vvp_dpi_open_array_t* aval; // array letters: handle/view for the call
      uint32_t* vbuf;             // 'V'/'W': packed vector buffer (any width)
				  //   'V' svBitVecVal[]  (2-state, one word/32 bits)
				  //   'W' svLogicVecVal[] (4-state, aval,bval pairs)
      unsigned  vwid;             // 'V'/'W': vector width in bits
};

/*
 * Call the C function at sym with the marshaled argument list.
 * ret_type is one of 'i' (int32), 'l' (int64), 'p' (void*),
 * 'r' (double), 's' (const char*), 'v' (void); the result is written through the
 * matching ret_* pointer. Output arguments are updated in args[].
 * Returns false (with a diagnostic naming c_name) if the signature
 * cannot be marshaled on this build.
 */
extern bool vvp_dpi_call(void*sym, const char*c_name, char ret_type,
			 vvp_dpi_arg_t*args, unsigned nargs,
			 int64_t*ret_i, double*ret_r, const char**ret_s);

#endif /* IVL_vvp_dpi_H */
