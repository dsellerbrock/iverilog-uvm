/* libsystre-equivalent: TRE types, real POSIX function symbols. */
#ifndef SYSTRE_SHIM_H
#define SYSTRE_SHIM_H
#include <tre/tre.h>
#undef regcomp
#undef regexec
#undef regerror
#undef regfree
#ifdef __cplusplus
extern "C" {
#endif
int regcomp(regex_t*, const char*, int);
int regexec(const regex_t*, const char*, size_t, regmatch_t*, int);
size_t regerror(int, const regex_t*, char*, size_t);
void regfree(regex_t*);
#ifdef __cplusplus
}
#endif
#endif
