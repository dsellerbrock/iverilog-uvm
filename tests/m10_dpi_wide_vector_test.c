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
