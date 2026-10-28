#include <string.h>
#include <vpi_user.h>

static int check_type(const char *name, vpiHandle object, int expected,
                      const char *expected_name)
{
    int type;
    const char *type_name;

    if (!object) {
        vpi_printf("FAIL %s handle is null\n", name);
        return 0;
    }
    type = vpi_get(vpiType, object);
    type_name = vpi_get_str(vpiType, object);
    if (type != expected || !type_name || strcmp(type_name, expected_name)) {
        vpi_printf("FAIL %s type=%d name=%s, expected %d %s\n", name,
                   type, type_name ? type_name : "<null>", expected,
                   expected_name);
        return 0;
    }
    return 1;
}

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    vpiHandle mem = vpi_handle_by_name((PLI_BYTE8 *)"top.mem", 0);
    vpiHandle top = vpi_handle_by_name((PLI_BYTE8 *)"top", 0);
    vpiHandle memories = top ? vpi_iterate(vpiMemory, top) : 0;
    vpiHandle iter_mem = memories ? vpi_scan(memories) : 0;
    vpiHandle words = mem ? vpi_iterate(vpiMemoryWord, mem) : 0;
    vpiHandle iter_word = words ? vpi_scan(words) : 0;
    vpiHandle indexed_word = mem ? vpi_handle_by_index(mem, 0) : 0;
    int ok;
    (void)data;

    ok = check_type("direct memory", mem, vpiRegArray, "vpiRegArray") &&
         check_type("iterated memory", iter_mem, vpiRegArray, "vpiRegArray") &&
         check_type("iterated word", iter_word, vpiReg, "vpiReg") &&
         check_type("indexed word", indexed_word, vpiReg, "vpiReg");
    if (ok)
        vpi_printf("PASSED\n");
    else
        vpi_control(vpiFinish, 1);
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$probe_memory_vpi_types";
    data.calltf = probe;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
