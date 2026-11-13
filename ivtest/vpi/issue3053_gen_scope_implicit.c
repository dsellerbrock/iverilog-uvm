#include <vpi_user.h>
#include <string.h>

static PLI_INT32 inspect(PLI_BYTE8 *data)
{
    static const struct { const char *name; int expected; } cases[] = {
        {"top.g[0]", 0}, {"top.g[1]", 0}, {"top.genblk2", 1},
        {"top.genblk3[0]", 1}, {"top.genblk3[1]", 1},
        {"top.genblk999", 0}, {"top.genblk5", 1},
        {"top.selected", 0}, {"top.named_case", 0}, {"top.genblk8", 1}
    };
    unsigned i;
    int errors = 0;
    (void)data;
    for (i = 0; i < sizeof cases / sizeof cases[0]; i++) {
        vpiHandle scope = vpi_handle_by_name((PLI_BYTE8 *)cases[i].name, 0);
        int value = scope ? vpi_get(vpiImplicitDecl, scope) : -9;
        if (!scope || vpi_get(vpiType, scope) != vpiGenScope ||
            value != cases[i].expected) {
            vpi_printf("FAIL %s implicit=%d expected=%d\n", cases[i].name,
                       value, cases[i].expected);
            errors++;
        }
    }
    if (!errors) vpi_printf("PASSED\n");
    return 0;
}

static void start(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$inspect_3053";
    data.calltf = inspect;
    vpi_register_systf(&data);
}
void (*vlog_startup_routines[])(void) = { start, 0 };
