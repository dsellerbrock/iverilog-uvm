#include <vpi_user.h>

static int failures;

/* The iterator from vpi_iterate(TYPE, REF) must say it scans TYPE, and
   still yield COUNT objects (any number if COUNT is negative). */
static void check(const char *what, PLI_INT32 type, vpiHandle ref, int count)
{
    vpiHandle it = vpi_iterate(type, ref), obj;
    int seen = 0;
    if (!it) {
        vpi_printf("FAIL %s: no iterator\n", what);
        failures++;
        return;
    }
    if (vpi_get(vpiType, it) != vpiIterator
        || vpi_get(vpiIteratorType, it) != type) {
        vpi_printf("FAIL %s: type %d iterator type %d, expected %d\n", what,
                   (int)vpi_get(vpiType, it),
                   (int)vpi_get(vpiIteratorType, it), (int)type);
        failures++;
    }
    while ((obj = vpi_scan(it)) != 0) seen++;
    if (count >= 0 && seen != count) {
        vpi_printf("FAIL %s: %d objects, expected %d\n", what, seen, count);
        failures++;
    }
}

static PLI_INT32 probe_calltf(PLI_BYTE8 *user_data)
{
    vpiHandle call = vpi_handle(vpiSysTfCall, 0);
    (void)user_data;
    check("ports", vpiPort, vpi_handle_by_name("top.c", 0), 2);
    check("arguments", vpiArgument, call, 2);
    check("modules", vpiModule, 0, 1);
    check("memory words", vpiMemoryWord, vpi_handle_by_name("top.mem", 0), 2);
    check("user systfs", vpiUserSystf, 0, -1);
    vpi_printf(failures ? "FAILED\n" : "PASSED\n");
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data data = {0};
    data.type = vpiSysTask;
    data.tfname = "$probe_iterator_type";
    data.calltf = probe_calltf;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
