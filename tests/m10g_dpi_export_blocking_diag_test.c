/* M10-2: drive a zero-time export, then a time-consuming one that
 * cannot be supported from a function context, then a zero-time one
 * again -- the unsupported call must be diagnosed without crashing
 * and must not disturb the calls around it. */
# include  <stdio.h>

extern int  sv_zero(int a);
extern void sv_blocks(void);

void c_drive(void)
{
      int a = sv_zero(1);
      printf("  c_drive: sv_zero(1) = %d\n", a);

      /* Unsupported: prints a vvp sorry, returns without blocking. */
      sv_blocks();
      printf("  c_drive: returned from sv_blocks\n");

      /* The export machinery must still be usable afterwards. */
      printf("  c_drive: sv_zero(41) = %d\n", sv_zero(41));
}
