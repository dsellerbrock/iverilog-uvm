#include <stdio.h>
extern int sv_wait(int,int);
int c_slow(int d, int id){ int status;
  printf("  C c_slow enter id=%d\n", id); fflush(stdout);
  status = sv_wait(d,id);
  printf("  C c_slow exit id=%d\n", id); fflush(stdout); return status; }
