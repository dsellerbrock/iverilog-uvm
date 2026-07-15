/* C side of m10_dpi_task_alias_test.sv */
#include <stdint.h>

static int32_t accum;

void c_log_event(int32_t code, const char*tag)
{
      (void)code; (void)tag;
      accum += 1;
}

void c_accumulate(int32_t delta)
{
      accum += delta;
}

int32_t c_get_accum(void)
{
      return accum;
}

double c_scale_add(double x, int32_t k)
{
      return x * (double)k;
}

void c_tick(void)
{
      accum += 1;
}
