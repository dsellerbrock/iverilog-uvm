#include <stdio.h>
extern void x_s(const char *, const char **);
int c_go(void)
{
    const char *t = 0;
    x_s("dpi", &t);
    if (!t || t[0] != 'd' || t[1] != 'p' || t[2] != 'i' || t[3] != '!') {
        printf("FAILED: %s\n", t ? t : "(null)");
        return 1;
    }
    puts("PASSED");
    puts("PASSED: dpi!");
    return 0;
}
