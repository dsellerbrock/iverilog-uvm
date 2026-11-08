/* Issue #2667: unpacked-struct DPI arguments (IEEE 1800-2017/2023 H.7.8). */
#include <stdint.h>
#include "svdpi.h"

typedef struct {
      char        b;    /* byte */
      double      r;    /* real */
      short       h;    /* shortint */
      svLogic     l;    /* logic */
      int64_t     q;    /* longint */
      unsigned    u;    /* int unsigned */
      svBit       t;    /* bit */
      float       f;    /* shortreal */
      void*       p;    /* chandle */
} s_t;

static double weigh(const s_t*s)
{
      return s->b + s->r + s->h + s->l * 1000 + (double)s->q + s->u
	   + s->t * 10000 + s->f + (s->p ? 100000 : 0);
}

double c_weigh(const s_t*s)
{
      return weigh(s);
}

void c_fill(s_t*s, int seed)
{
      s->b = (char)-seed;
      s->r = seed + 0.5;
      s->h = (short)(seed * 100);
      s->l = sv_z;
      s->q = (int64_t)seed << 40;
      s->u = 0xF0000000u | (unsigned)seed;
      s->t = 1;
      s->f = seed + 0.25f;
      s->p = (void*)(uintptr_t)(0x1000 + seed);
}

void c_bump(s_t*s)
{
      s->b += 1;
      s->r *= 2;
      s->l = s->l == sv_x ? sv_1 : sv_x;
      s->p = s->p ? 0 : (void*)(uintptr_t)0x2000;
}

double c_weigh_fixed(const s_t*a)
{
      return weigh(&a[0]) + 2 * weigh(&a[1]) + 3 * weigh(&a[2]);
}

void c_fill_fixed(s_t*a)
{
      for (int i = 0 ; i < 3 ; i += 1)
	    c_fill(&a[i], i + 1);
}

double c_weigh_open(const svOpenArrayHandle h)
{
      double sum = 0;
      for (int i = svLow(h, 1) ; i <= svHigh(h, 1) ; i += 1)
	    sum += (i - svLow(h, 1) + 1) * weigh((const s_t*)svGetArrElemPtr1(h, i));
      return sum + 1000000 * svSize(h, 1);
}

void c_bump_open(const svOpenArrayHandle h)
{
      for (int i = svLow(h, 1) ; i <= svHigh(h, 1) ; i += 1)
	    c_bump((s_t*)svGetArrElemPtr1(h, i));
}
