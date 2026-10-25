#include <svdpi.h>

int c_array_size(const svOpenArrayHandle values)
{
      if (svDimensions(values) != 1) return -1;
      return svSize(values, 1);
}
