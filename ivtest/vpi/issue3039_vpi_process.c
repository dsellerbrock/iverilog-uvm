#include <string.h>
#include <sv_vpi_user.h>

#ifndef vpiFinal
#define vpiFinal 676
#endif

struct expected_process {
    int type;
    const char *type_name;
    int always_type;
    const char *always_name;
    int body_type;
    vpiHandle process;
    vpiHandle body;
};

static struct expected_process top_processes[] = {
    {vpiInitial, "vpiInitial", 0, 0, vpiBegin, 0, 0},
    {vpiAlways, "vpiAlways", vpiAlways, "vpiAlways", vpiDelayControl, 0, 0},
};

static struct expected_process variant_processes[] = {
    {vpiInitial, "vpiInitial", 0, 0, vpiBegin, 0, 0},
    {vpiInitial, "vpiInitial", 0, 0, vpiDelayControl, 0, 0},
    {vpiAlways, "vpiAlways", vpiAlwaysComb, "vpiAlwaysComb", vpiBegin, 0, 0},
    {vpiAlways, "vpiAlways", vpiAlwaysFF, "vpiAlwaysFF", vpiEventControl, 0, 0},
    {vpiAlways, "vpiAlways", vpiAlwaysLatch, "vpiAlwaysLatch", vpiIf, 0, 0},
    {vpiFinal, "vpiFinal", 0, 0, vpiBegin, 0, 0},
    {vpiAlways, "vpiAlways", vpiAlwaysFF, "vpiAlwaysFF", vpiBegin, 0, 0},
    {vpiInitial, "vpiInitial", 0, 0, vpiNamedBegin, 0, 0},
};

static int inspect_scope(const char *path, struct expected_process *expected,
                         unsigned count)
{
    vpiHandle scope = vpi_handle_by_name((PLI_BYTE8 *)path, 0);
    vpiHandle iter = scope ? vpi_iterate(vpiProcess, scope) : 0;
    vpiHandle process = 0;
    unsigned found = 0, seen = 0;

    while (iter && (process = vpi_scan(iter))) {
        vpiHandle body = vpi_handle(vpiStmt, process);
        int body_type = body ? vpi_get(vpiType, body) : -1;
        int type = vpi_get(vpiType, process);
        int always_type = type == vpiAlways ? vpi_get(vpiAlwaysType, process) : 0;
        unsigned i;
        for (i = 0; i < count; ++i)
            if (type == expected[i].type && always_type == expected[i].always_type
                && body_type == expected[i].body_type)
                break;
        if (i == count || (seen & (1u << i))) {
            vpi_printf("FAIL %s unexpected process type=%d always_type=%d body=%d\n",
                       path, type, always_type, body_type);
            vpi_free_object(iter);
            return 0;
        }
        seen |= 1u << i;
        ++found;
        const char *type_name = vpi_get_str(vpiType, process);
        if (!type_name || strcmp(type_name, expected[i].type_name) != 0)
            break;
        if (type == vpiAlways) {
            const char *name = vpi_get_str(vpiAlwaysType, process);
            if (!name || strcmp(name, expected[i].always_name) != 0)
                break;
        }

        if (expected[i].process) {
            if (!vpi_compare_objects(expected[i].process, process)
                || !vpi_compare_objects(expected[i].body, body))
                break;
        } else {
            expected[i].process = process;
            expected[i].body = body;
        }
    }

    if (process || found != count) {
        if (process) vpi_free_object(iter);
        vpi_printf("FAIL %s process count, property or identity check (%u/%u)\n",
                   path, found, count);
        return 0;
    }
    return 1;
}

static int check_children(vpiHandle body, const int *types, unsigned count)
{
    vpiHandle iter = vpi_iterate(vpiStmt, body);
    vpiHandle child;
    unsigned i = 0;
    while (iter && (child = vpi_scan(iter))) {
        if (i == count || vpi_get(vpiType, child) != types[i]) {
            vpi_free_object(iter);
            return 0;
        }
        ++i;
    }
    return i == count;
}

static PLI_INT32 inspect(PLI_BYTE8 *ud)
{
    static unsigned calls = 0;
    const int initial_children[] = {
        vpiDelayControl, vpiSysTaskCall, vpiDelayControl, vpiSysTaskCall, vpiSysTaskCall,
    };
    const int assignment[] = {vpiAssignment};
    const int event_control[] = {vpiEventControl};
    const int framed_children[] = {vpiDelayControl, vpiIf};
    (void)ud;

    if (!inspect_scope("top", top_processes, 2)
        || !inspect_scope("top.variants", variant_processes, 8)) {
        vpi_control(vpiFinish, 1);
        return 0;
    }
    if (!check_children(top_processes[0].body, initial_children, 5)
        || !check_children(top_processes[1].body, assignment, 1)
        || !check_children(variant_processes[0].body, 0, 0)
        || !check_children(variant_processes[2].body, assignment, 1)
        || !check_children(variant_processes[3].body, assignment, 1)
        || !check_children(variant_processes[5].body, 0, 0)
        || !check_children(variant_processes[6].body, event_control, 1)
        || !check_children(variant_processes[7].body, framed_children, 2)) {
        vpi_printf("FAIL process body children\n");
        vpi_control(vpiFinish, 1);
        return 0;
    }
    if (++calls == 2)
        vpi_printf("VPI process handles PASS\n");
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data data = {0};
    data.type = vpiSysTask;
    data.tfname = "$inspect_processes";
    data.calltf = inspect;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = {register_probe, 0};
