/* Test-only Z3 fault injection; never linked into the simulator. */
#include <stdio.h>
#ifdef __APPLE__
extern int Z3_optimize_check(void *, void *, unsigned, void *);
static int force_unknown(void *c, void *o, unsigned n, void *a)
#else
int Z3_optimize_check(void *c, void *o, unsigned n, void *a)
#endif
{
    (void)c; (void)o; (void)n; (void)a;
    fputs("INJECTED: Z3_optimize_check UNKNOWN\n", stderr);
    return 0;
}
#ifdef __APPLE__
__attribute__((used)) static struct { const void *replacement; const void *original; }
interpose __attribute__((section("__DATA,__interpose"))) = {
    (const void *)force_unknown, (const void *)Z3_optimize_check
};
#endif
