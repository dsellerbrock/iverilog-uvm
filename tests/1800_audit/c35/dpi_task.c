#include "svdpi.h"

extern int sv_wait_task(int n);
extern int sv_disable_function_caller(void);
static int flag = 0;
static int function_flag = 0;

int c_add2(int a, int b) { return a + b; }
int c_task_call(int n) { return sv_wait_task(n); }
int c_dis(void) {
  int r = sv_wait_task(100);
  if (r && svIsDisabledState()) {
    flag = 1;
    return 1;
  }
  return 0;
}
int c_get_flag(void) { return flag; }
int c_disabled_function(void) {
  (void)sv_disable_function_caller();
  if (svIsDisabledState()) {
    function_flag = 1;
    svAckDisabledState();
  }
  return -1;
}
int c_get_function_flag(void) { return function_flag; }
