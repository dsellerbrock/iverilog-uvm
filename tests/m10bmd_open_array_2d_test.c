/* Prototypes declared directly (harness convention: compiled without
 * include paths). These resolve against the accessors the vvp runtime
 * exports (see vvp/vvp_dpi.cc). */
typedef void* svOpenArrayHandle;
extern int svDimensions(const void*h);
extern int svSize(const void*h, int dim);
extern void* svGetArrElemPtr2(const void*h, int indx1, int indx2);
extern void* svGetArrElemPtr3(const void*h, int indx1, int indx2, int indx3);
void sum2d(const svOpenArrayHandle a, int*total)
{
      int n1 = svSize(a, 1), n2 = svSize(a, 2);
      int sum = 0;
      if (svDimensions(a) != 2) { *total = -1; return; }
      for (int i = 0 ; i < n1 ; i += 1)
	    for (int j = 0 ; j < n2 ; j += 1) {
		  int*p = (int*)svGetArrElemPtr2(a, i, j);
		  if (p) sum += *p;
	    }
      *total = sum;
}
void sum3d(const svOpenArrayHandle a, int*total)
{
      int n1 = svSize(a, 1), n2 = svSize(a, 2), n3 = svSize(a, 3);
      int sum = 0;
      if (svDimensions(a) != 3) { *total = -1; return; }
      for (int i = 0 ; i < n1 ; i += 1)
	    for (int j = 0 ; j < n2 ; j += 1)
		  for (int k = 0 ; k < n3 ; k += 1) {
			char*p = (char*)svGetArrElemPtr3(a, i, j, k);
			if (p) sum += *p;
		  }
      *total = sum;
}
