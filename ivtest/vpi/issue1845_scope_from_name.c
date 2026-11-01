#include <stdint.h>
#include <string.h>
#include <svdpi.h>
#include <vpi_user.h>

extern int64_t __ivl_dpi_export_call_i(const char *, int, void *);

void c_pick(void)
{
    svScope u1 = svGetScopeFromName("tb.u1");
    svScope u2 = svGetScopeFromName("tb.u2");
    const char *name1 = svGetNameFromScope(u1);
    const char *name2 = svGetNameFromScope(u2);
    svScope old_scope;
    int64_t selected;

    if (!name1 || !name2 || strcmp(name1, "tb.u1") != 0 ||
        strcmp(name2, "tb.u2") != 0) {
        vpi_printf("svGetNameFromScope FAILED: u1=%s u2=%s\n",
                   name1 ? name1 : "(null)", name2 ? name2 : "(null)");
        vpi_control(vpiFinish, 1);
        return;
    }

    old_scope = svSetScope(u2);
    selected = __ivl_dpi_export_call_i("getid", 0, 0);
    svSetScope(old_scope);
    if (selected != 2) {
        vpi_printf("svSetScope export selection FAILED: %lld\n",
                   (long long)selected);
        vpi_control(vpiFinish, 1);
        return;
    }

    vpi_printf("svGetNameFromScope PASSED\nPASSED\n");
}

void (*vlog_startup_routines[])(void) = { 0 };
