/* C side of m10_dpi_wide_vector_test.sv — packed vector DPI marshaling.
 * svBitVecVal is uint32_t; svLogicVecVal is {aval,bval} 32-bit pairs.
 * We avoid including svdpi.h (the sweep's gcc adds no include path) and
 * declare the ABI types directly. 72-bit vectors span 3 words. */
#include <stdint.h>

typedef struct { uint32_t aval; uint32_t bval; } my_svLogicVecVal;

/* 2-state: c = a ^ b, word by word (svBitVecVal[]). */
void wide_xor(const uint32_t*a, const uint32_t*b, uint32_t*c)
{
      int i;
      for (i = 0 ; i < 3 ; i += 1)
	    c[i] = a[i] ^ b[i];
}

/* 4-state: copy a to b preserving the aval/bval (0/1/x/z) encoding. */
void wide_logic_copy(const my_svLogicVecVal*a, my_svLogicVecVal*b)
{
      int i;
      for (i = 0 ; i < 3 ; i += 1) {
	    b[i].aval = a[i].aval;
	    b[i].bval = a[i].bval;
      }
}

/* 4-state: return the bitwise complement of the KNOWN bits (x/z pass
 * through unchanged) to prove the callee both reads and writes the
 * svLogicVecVal buffer. */
void wide_logic_invert(const my_svLogicVecVal*a, my_svLogicVecVal*b)
{
      int i;
      for (i = 0 ; i < 3 ; i += 1) {
	    b[i].bval = a[i].bval;
	      /* invert value bits, but leave x/z (bval=1) bits' aval as-is */
	    b[i].aval = (~a[i].aval & ~a[i].bval) | (a[i].aval & a[i].bval);
      }
}

/* Explicit packed vectors use pointer ABI at ordinary atom widths too. */
void packed64_xor(const uint32_t*a, const uint32_t*b, uint32_t*c)
{
      c[0] = a[0] ^ b[0];
      c[1] = a[1] ^ b[1];
}

void packed32_logic_copy(const my_svLogicVecVal*a, my_svLogicVecVal*b)
{
      b[0].aval = a[0].aval;
      b[0].bval = a[0].bval;
}

/* Same SV width, deliberately different C ABI shapes. */
void scalar_vector_shape_copy(uint8_t sb_i, const uint32_t*vb_i,
			      uint8_t sl_i, const my_svLogicVecVal*vl_i,
			      uint8_t*sb_o, uint32_t*vb_o,
			      uint8_t*sl_o, my_svLogicVecVal*vl_o)
{
      *sb_o = sb_i ^ 1u;
      vb_o[0] = (vb_i[0] ^ 1u) & 1u;
      *sl_o = sl_i;
      vl_o[0] = vl_i[0];
}

/* integer is one svLogicVecVal word; time is two. */
void canonical_atom_copy(const my_svLogicVecVal*integer_i,
			 my_svLogicVecVal*integer_o,
			 const my_svLogicVecVal*time_i,
			 my_svLogicVecVal*time_o)
{
      integer_o[0] = integer_i[0];
      time_o[0] = time_i[0];
      time_o[1] = time_i[1];
}

void typedef_enum_copy(const uint32_t*nested_i, uint32_t*nested_o,
		       const uint32_t*ve_i, uint32_t*ve_o,
		       int32_t ae_i, int32_t*ae_o)
{
      nested_o[0] = nested_i[0];
      ve_o[0] = ve_i[0];
      *ae_o = ae_i;
}

void packed_aggregate_copy(const uint32_t*small_i, uint32_t*small_o,
			   const uint32_t*wide_i, uint32_t*wide_o)
{
      int i;
      small_o[0] = small_i[0];
      for (i = 0 ; i < 3 ; i += 1)
	    wide_o[i] = wide_i[i];
}

void* make_test_handle(uint64_t value)
{
      return (void*)(uintptr_t)value;
}

uint64_t read_test_handle(void*value)
{
      return (uint64_t)(uintptr_t)value;
}

void advance_test_handle(void**value)
{
      *value = (void*)((uintptr_t)*value + 0x10u);
}
