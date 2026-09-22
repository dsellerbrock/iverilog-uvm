#include <tre/tre.h>
#undef regcomp
#undef regexec
#undef regerror
#undef regfree
int regcomp(regex_t*p,const char*r,int f){return tre_regcomp(p,r,f);}
int regexec(const regex_t*p,const char*s,size_t n,regmatch_t*m,int f){return tre_regexec(p,s,n,m,f);}
size_t regerror(int e,const regex_t*p,char*b,size_t n){return tre_regerror(e,p,b,n);}
void regfree(regex_t*p){tre_regfree(p);}
