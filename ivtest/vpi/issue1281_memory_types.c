#include <string.h>
#include <vpi_user.h>

static PLI_INT32 probe(PLI_BYTE8 *data)
{
    vpiHandle top, mem, memory_iter, iter_mem;
    vpiHandle word_iter, iter_word, indexed_word;
    (void)data;

    top = vpi_handle(vpiScope, vpi_handle(vpiSysTfCall, 0));
    mem = top ? vpi_handle_by_name((PLI_BYTE8*)"mem", top) : 0;
    memory_iter = top ? vpi_iterate(vpiMemory, top) : 0;
    iter_mem = memory_iter ? vpi_scan(memory_iter) : 0;
    word_iter = mem ? vpi_iterate(vpiMemoryWord, mem) : 0;
    iter_word = word_iter ? vpi_scan(word_iter) : 0;
    indexed_word = mem ? vpi_handle_by_index(mem, 0) : 0;

    if (!top || !mem || !iter_mem || !iter_word || !indexed_word ||
        vpi_get(vpiType, mem) != vpiRegArray ||
        vpi_get(vpiType, iter_mem) != vpiRegArray ||
        vpi_get(vpiType, iter_word) != vpiReg ||
        vpi_get(vpiType, indexed_word) != vpiReg ||
        strcmp((const char*)vpi_get_str(vpiType, mem), "vpiRegArray") ||
        strcmp((const char*)vpi_get_str(vpiType, iter_mem), "vpiRegArray") ||
        strcmp((const char*)vpi_get_str(vpiType, iter_word), "vpiReg") ||
        strcmp((const char*)vpi_get_str(vpiType, indexed_word), "vpiReg")) {
        vpi_printf("FAIL memory types: direct=%d iterated=%d; word types: iterated=%d indexed=%d\n",
                   mem ? vpi_get(vpiType, mem) : -1,
                   iter_mem ? vpi_get(vpiType, iter_mem) : -1,
                   iter_word ? vpi_get(vpiType, iter_word) : -1,
                   indexed_word ? vpi_get(vpiType, indexed_word) : -1);
        vpi_control(vpiFinish, 1);
        return 0;
    }

    vpi_printf("PASSED\n");
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$probe_memory_types";
    data.calltf = probe;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
