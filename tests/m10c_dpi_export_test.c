/* DPI companion for m10c_dpi_export_test: an imported context task
 * that calls back into the exported SV subroutines and self-checks each
 * result. The exported symbols (f_add, f_sub, c_byte, ...) are provided by
 * the generated m10c_dpi_export_test.dpiexport.c stub compiled alongside
 * this file. */
#include <stdint.h>
#include <stdio.h>

extern int       f_add (int a, int b);
extern int       f_sub (int a, int b);
extern char      c_byte(char x);   /* aliased C name for f_byte */
extern long long f_long(long long x);
extern double    f_real(double x);
extern void      f_void(int x);
extern int       t_task(int x);

int run_all(int *failure_count)
{
      int fails = 0;

      int s1 = f_add(3, 4);
      printf("  f_add(3,4)=%d\n", s1);
      if (s1 != 7) fails += 1;

      int s2 = f_sub(10, 25);       /* -15: signed negative return */
      printf("  f_sub(10,25)=%d\n", s2);
      if (s2 != -15) fails += 1;

      char b = c_byte(5);           /* 15 */
      printf("  c_byte(5)=%d\n", (int)b);
      if (b != 15) fails += 1;

      b = c_byte(120);              /* 8-bit result 130 (0x82) */
      printf("  c_byte(120)=0x%02x\n", (unsigned)(uint8_t)b);
      if ((uint8_t)b != UINT8_C(0x82)) fails += 1;

      long long l = f_long(3000000000LL);   /* 6e9: needs 64-bit path */
      printf("  f_long(3e9)=%lld\n", l);
      if (l != 6000000000LL) fails += 1;

      double r = f_real(4.0);       /* 6.0 */
      printf("  f_real(4.0)=%g\n", r);
      if (r != 6.0) fails += 1;

      f_void(42);
      if (t_task(99) != 0) fails += 1;

      *failure_count = fails;
      return 0; /* normal imported-task acknowledgement */
}
