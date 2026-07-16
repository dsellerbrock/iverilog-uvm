/* C side of m10_dpi_mixed_test.sv */
#include <stdint.h>
#include <string.h>

double c_mix_ir(int32_t a, double b)
{
      return (double)a * b;
}

int32_t c_mix_ri(double a, int32_t b)
{
      return (int32_t)(a * (double)b);
}

double c_mix_iris(int32_t a, double b, int32_t c, const char*d)
{
      return (double)a + b + (double)c + (double)strlen(d);
}

int64_t c_add64(int64_t a, int64_t b)
{
      return a + b;
}

int32_t c_widths(signed char b, short h, int32_t i, int64_t l)
{
      return (b == -2) && (h == -300) && (i == 100000)
	  && (l == -4000000000LL);
}

int32_t c_uwidths(unsigned char b, unsigned short h, uint32_t i)
{
      return (b == 0xFF) && (h == 0xFFFF) && (i == 0xFFFFFFFFu);
}

static int32_t handle_payload;

void* c_make_handle(int32_t tag)
{
      handle_payload = tag;
      return &handle_payload;
}

int32_t c_read_handle(void*h)
{
      return h ? *(int32_t*)h : -1;
}

int32_t c_sum12(int32_t a1, int32_t a2, int32_t a3, int32_t a4,
		int32_t a5, int32_t a6, int32_t a7, int32_t a8,
		int32_t a9, int32_t a10, int32_t a11, int32_t a12)
{
      return a1+a2+a3+a4+a5+a6+a7+a8+a9+a10+a11+a12;
}

double c_avg3(double a, double b, double c)
{
      return (a + b + c) / 3.0;
}

static int note_count;

void c_note(int32_t code, const char*what, double val)
{
      (void)code; (void)what; (void)val;
      note_count += 1;
}

int32_t c_note_count(void)
{
      return note_count;
}

int32_t c_logic_scalar(unsigned char v)
{
      return (int32_t)v;
}
