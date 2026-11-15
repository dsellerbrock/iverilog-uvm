#include <string.h>
#include <vpi_user.h>

static int failures;

static void check(const char *name, int expected)
{
    vpiHandle word = vpi_handle_by_name((PLI_BYTE8 *)name, 0);
    vpiHandle it = word ? vpi_iterate(vpiIndex, word) : 0;
    vpiHandle idx;
    int found = 0;
    while (it && (idx = vpi_scan(it))) {
        s_vpi_value v;
        memset(&v, 0, sizeof v);
        v.format = vpiIntVal;
        vpi_get_value(idx, &v);
        if (found == 0 && v.value.integer != expected) {
            vpi_printf("FAIL %s index %d expected %d\n", name,
                       v.value.integer, expected);
            failures++;
        }
        found++;
    }
    if (found != 1) {
        vpi_printf("FAIL %s returned %d indices expected 1\n", name, found);
        failures++;
    }
}

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    (void)data;
    check("top.var_arr[3]", 3);
    check("top.var_arr[2]", 2);
    check("top.mem[0]", 0);
    check("top.mem[4]", 4);
    if (failures)
        vpi_printf("VAR WORD INDEX FAIL failures=%d\n", failures);
    else {
        vpi_printf("VAR WORD INDEX PASS\n");
        vpi_printf("PASSED\n");
    }
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$probe_var_word_index";
    data.calltf = probe;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = {register_probe, 0};
