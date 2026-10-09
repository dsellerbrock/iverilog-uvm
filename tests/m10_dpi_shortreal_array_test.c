#include "svdpi.h"

int c_fixed_input(const float values[2])
{
      return values[0] == 1.25f && values[1] == -2.5f;
}

void c_fixed_output(float values[2])
{
      values[0] = 4.5f;
      values[1] = -6.25f;
}

void c_fixed_inout(float values[2])
{
      values[0] += 0.25f;
      values[1] += 0.5f;
}

int c_open_input(const svOpenArrayHandle values)
{
      if (svSize(values, 1) != 2) return 0;
      float*first = (float*)svGetArrElemPtr1(values, 0);
      float*second = (float*)svGetArrElemPtr1(values, 1);
      return first && second && *first == 1.5f && *second == -3.0f;
}

void c_open_output(const svOpenArrayHandle values)
{
      float*first = (float*)svGetArrElemPtr1(values, 0);
      float*second = (float*)svGetArrElemPtr1(values, 1);
      if (first) *first = 7.5f;
      if (second) *second = -8.25f;
}

void c_open_inout(const svOpenArrayHandle values)
{
      float*first = (float*)svGetArrElemPtr1(values, 0);
      float*second = (float*)svGetArrElemPtr1(values, 1);
      if (first) *first += 0.5f;
      if (second) *second += 0.75f;
}

int c_open_2d_input(const svOpenArrayHandle values)
{
      if (svDimensions(values) != 2 || svSizeOfArray(values) != 4 * sizeof(float))
	    return 0;
      float*first = (float*)svGetArrElemPtr2(values, 0, 0);
      float*second = (float*)svGetArrElemPtr2(values, 0, 1);
      float*third = (float*)svGetArrElemPtr2(values, 1, 0);
      float*fourth = (float*)svGetArrElemPtr2(values, 1, 1);
      return first && second && third && fourth
	    && *first == 1.25f && *second == 2.5f
	    && *third == 3.75f && *fourth == 5.0f;
}
