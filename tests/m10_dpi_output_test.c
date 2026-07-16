/* C side of m10_dpi_output_test.sv */
#include <stdint.h>

int32_t c_divmod(int32_t n, int32_t d, int32_t*quot, int32_t*rem)
{
      if (d == 0) return 0;
      *quot = n / d;
      *rem  = n % d;
      return 1;
}

void c_stats(double x, double y, double*sum, double*prod)
{
      *sum  = x + y;
      *prod = x * y;
}

void c_swap64(int64_t*a, int64_t*b)
{
      int64_t t = *a;
      *a = *b;
      *b = t;
}

int32_t c_step(int32_t*counter, int32_t delta)
{
      int32_t old = *counter;
      *counter += delta;
      return old;
}

void c_describe(int32_t code, const char**text)
{
      switch (code) {
	  case 1:  *text = "one";  break;
	  case 2:  *text = "two";  break;
	  default: *text = "many"; break;
      }
}

void c_flags(signed char v, signed char*doubled, short*widened)
{
      *doubled = (signed char)(v * 2);
      *widened = (short)v;
}

/* svBit/svLogic scalars: unsigned char; sv_x encoding is 3. */
void c_bitop(unsigned char a, unsigned char b,
	     unsigned char*xr, unsigned char*maybe)
{
      *xr = (unsigned char)((a ^ b) & 1);
      *maybe = (a & b & 1) ? 1 : 3 /* sv_x */;
}
