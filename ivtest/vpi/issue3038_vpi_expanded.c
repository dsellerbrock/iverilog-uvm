#include <string.h>
#include <vpi_user.h>

#ifndef vpiExpanded
#define vpiExpanded 25
#endif

static int failures;

static void check(const char *name, int index, int size)
{
    vpiHandle net = vpi_handle_by_name((PLI_BYTE8 *)name, 0);
    vpiHandle bit = net ? vpi_handle_by_index(net, index) : 0;
    int expanded = net ? vpi_get(vpiExpanded, net) : -2;
    int bit_expanded = bit ? vpi_get(vpiExpanded, bit) : -2;
    if (!net || !bit || vpi_get(vpiSize, net) != size ||
        vpi_get(vpiType, bit) != vpiNetBit ||
        expanded != 1 || bit_expanded != expanded) {
        vpi_printf("FAIL %s: expanded=%d bit=%d\n", name, expanded, bit_expanded);
        failures++;
    }
}

static PLI_INT32 probe(PLI_BYTE8 *unused)
{
    (void)unused;
    check("top.bus", 2, 4);
    check("top.vec", 1, 4);
    /* The second index exercises a packed net-bit view. */
    {
        vpiHandle net = vpi_handle_by_name((PLI_BYTE8 *)"top.packed_bus", 0);
        vpiHandle part = net ? vpi_handle_by_index(net, 1) : 0;
        vpiHandle bit = part ? vpi_handle_by_index(part, 0) : 0;
        if (!net || !part || !bit || vpi_get(vpiType, bit) != vpiNetBit ||
            vpi_get(vpiExpanded, net) != 1 ||
            vpi_get(vpiExpanded, bit) != vpi_get(vpiExpanded, net)) {
            vpi_printf("FAIL packed net bit\n");
            failures++;
        }
    }
    if (!failures) vpi_printf("PASSED\n");
    return 0;
}

static void start(void)
{
    s_vpi_systf_data tf;
    memset(&tf, 0, sizeof tf);
    tf.type = vpiSysTask;
    tf.tfname = (PLI_BYTE8 *)"$check_expanded";
    tf.calltf = probe;
    vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {start, 0};
