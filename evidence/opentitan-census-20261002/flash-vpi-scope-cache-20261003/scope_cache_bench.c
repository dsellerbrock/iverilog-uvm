#include <time.h>
#include "vpi_user.h"

static PLI_INT32 bench_calltf(PLI_BYTE8 *unused)
{
    const char *path = "top.g[1023].u_leaf.status";
    const int iterations = 20000;
    clock_t begin = clock();
    (void)unused;
    for (int i = 0; i < iterations; i++) {
        vpiHandle handle = vpi_handle_by_name((PLI_BYTE8 *)path, 0);
        if (!handle) {
            vpi_printf("lookup failed at %d\n", i);
            return 1;
        }
        vpi_free_object(handle);
    }
    double elapsed = (double)(clock() - begin) / CLOCKS_PER_SEC;
    vpi_printf("lookups=%d cpu_seconds=%.6f\n", iterations, elapsed);
    return 0;
}

static void register_bench(void)
{
    s_vpi_systf_data tf = {0};
    tf.type = vpiSysTask;
    tf.tfname = "$scope_cache_bench";
    tf.calltf = bench_calltf;
    vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_bench, 0 };
