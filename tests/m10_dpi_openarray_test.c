/* C side of m10_dpi_openarray_test.sv. Uses the svdpi open-array
 * accessors exported by the vvp runtime. Prototypes are declared
 * here directly so the harness can compile this file without any
 * include path; user code would `#include <svdpi.h>` instead. */
#include <stdint.h>

typedef void* svOpenArrayHandle;
extern int  svDimensions(const void*h);
extern int  svSize(const void*h, int dim);
extern int  svLow(const void*h, int dim);
extern int  svHigh(const void*h, int dim);
extern int  svSizeOfArray(const void*h);
extern void* svGetArrElemPtr1(const void*h, int indx1);

int32_t c_arr_sum(svOpenArrayHandle arr)
{
      int32_t sum = 0;
      int n = svSize(arr, 1);
      for (int i = 0; i < n; i += 1)
	    sum += *(int32_t*)svGetArrElemPtr1(arr, i);
      return sum;
}

int32_t c_arr_fill(svOpenArrayHandle arr, int32_t base)
{
      int n = svSize(arr, 1);
      for (int i = 0; i < n; i += 1)
	    *(int32_t*)svGetArrElemPtr1(arr, i) = base + i;
      return n;
}

int64_t c_arr_sum64(svOpenArrayHandle arr)
{
      int64_t sum = 0;
      int n = svSize(arr, 1);
      for (int i = 0; i < n; i += 1)
	    sum += *(int64_t*)svGetArrElemPtr1(arr, i);
      return sum;
}

int32_t c_arr_bytes(svOpenArrayHandle arr)
{
      int n = svSize(arr, 1);
      for (int i = 0; i < n; i += 1) {
	    signed char*p = (signed char*)svGetArrElemPtr1(arr, i);
	    *p = (signed char)(*p * 2);
      }
      return n;
}

double c_arr_mean(svOpenArrayHandle arr)
{
      double sum = 0.0;
      int n = svSize(arr, 1);
      if (n == 0) return 0.0;
      for (int i = 0; i < n; i += 1)
	    sum += *(double*)svGetArrElemPtr1(arr, i);
      return sum / (double)n;
}

int32_t c_arr_geom(svOpenArrayHandle arr)
{
      if (svDimensions(arr) != 1) return 0;
      if (svLow(arr, 1) != 0) return 0;
      int n = svSize(arr, 1);
      if (svHigh(arr, 1) != n - 1) return 0;
      if (svSizeOfArray(arr) != n * (int)sizeof(short)) return 0;
      /* Element spot-check through the pointer API. */
      for (int i = 0; i < n; i += 1) {
	    if (*(short*)svGetArrElemPtr1(arr, i) != (short)i)
		  return 0;
      }
      /* Out-of-range access must return NULL, not crash. */
      if (svGetArrElemPtr1(arr, n) != 0) return 0;
      if (svGetArrElemPtr1(arr, -1) != 0) return 0;
      return 1;
}
