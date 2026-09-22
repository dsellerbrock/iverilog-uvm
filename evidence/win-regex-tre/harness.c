#include <stdio.h>
#include <stdlib.h>
#include <string.h>
void* uvm_re_comp(const char*, unsigned char);
int uvm_re_exec(void*, const char*);
void uvm_re_free(void*);
char* uvm_re_buffer(void);
#define STEP(s) do{printf("%s\n",s);fflush(stdout);}while(0)
int main(void){
  void*h; char big[2050];
  h=uvm_re_comp("*[",0); printf("strict *[ -> %s err=%s\n",h?"HANDLE":"null",uvm_re_buffer()); fflush(stdout);
  h=uvm_re_comp("*_shadowed",1); printf("glob exec=%d/%d\n",uvm_re_exec(h,"alert_shadowed"),uvm_re_exec(h,"alert_regwen")); uvm_re_free(h);
  h=uvm_re_comp("/.*_shadowed/",0); printf("slash exec=%d\n",uvm_re_exec(h,"alert_shadowed")); uvm_re_free(h);
  h=uvm_re_comp("*[",1); printf("deglob *[ exec x[=%d x=%d\n",uvm_re_exec(h,"x["),uvm_re_exec(h,"x")); uvm_re_free(h);
  memset(big,'a',2048); big[2048]=0; h=uvm_re_comp(big,0); printf("2048 -> %s\n",h?"HANDLE":uvm_re_buffer()); fflush(stdout);
  if(h){printf("2048 exec=%d\n",uvm_re_exec(h,big)); uvm_re_free(h);}
  big[2048]='a'; big[2049]=0; h=uvm_re_comp(big,0); printf("2049 -> %s err=%s\n",h?"HANDLE":"null",uvm_re_buffer());
  h=uvm_re_comp("(a)(b)",0); printf("group exec=%d\n",uvm_re_exec(h,"xaby")); uvm_re_free(h);
  STEP("DONE"); return 0;
}
