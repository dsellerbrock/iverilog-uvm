#include <stdio.h>
#include <string.h>
#include "vpi_user.h"

static unsigned failures;
static unsigned sample;

static void expect(int ok, const char *object, const char *what)
{
    if (!ok) {
        vpi_printf("FAIL %s: %s\n", object, what);
        failures++;
    }
}

static int index_value(vpiHandle index, int expected)
{
    s_vpi_value value;
    if (!index || vpi_get(vpiType, index) != vpiConstant)
        return 0;
    value.format = vpiIntVal;
    vpi_get_value(index, &value);
    return value.value.integer == expected;
}

static void check_port(const char *instance, int port_index, const char *actual,
                       int type, int left, int right, const char *bits)
{
    vpiHandle scope = vpi_handle_by_name(instance, NULL);
    vpiHandle ports = scope ? vpi_iterate(vpiPort, scope) : NULL;
    vpiHandle port = NULL, high, signal;
    s_vpi_value value;
    char name[64];
    snprintf(name, sizeof name, "%s port %d", instance, port_index);
    if (ports) {
        while ((port = vpi_scan(ports))) {
            if (vpi_get(vpiPortIndex, port) == port_index) {
                vpi_free_object(ports);
                break;
            }
        }
    }
    expect(port != NULL, name, "missing port");
    if (!port) return;

    high = vpi_handle(vpiHighConn, port);
    if (!actual) {
        expect(high == NULL, name, "open port has NULL vpiHighConn");
        return;
    }
    signal = vpi_handle_by_name(actual, NULL);
    expect(signal != NULL, name, "actual signal exists");
    if (type == vpiBitSelect || type == vpiPartSelect) {
        vpiHandle parent;
        expect(high && vpi_get(vpiType, high) == type, name,
               type == vpiBitSelect ? "expected vpiBitSelect" : "expected vpiPartSelect");
        if (!high || vpi_get(vpiType, high) != type) return;
        parent = vpi_handle(vpiParent, high);
        expect(parent && signal && vpi_compare_objects(parent, signal),
               name, "select parent is the actual signal");
        expect(vpi_get(vpiConstantSelect, high) == 1, name, "constant select");
        expect(vpi_get(vpiSize, high) == (int)strlen(bits), name, "select size");
        if (type == vpiBitSelect) {
            expect(index_value(vpi_handle(vpiIndex, high), right), name, "declared bit index");
        } else {
            expect(index_value(vpi_handle(vpiLeftRange, high), left), name, "declared left bound");
            expect(index_value(vpi_handle(vpiRightRange, high), right), name, "declared right bound");
        }
    } else {
        expect(high && signal && vpi_compare_objects(high, signal),
               name, "whole connection is the actual signal");
    }
    if (high) {
        value.format = vpiBinStrVal;
        vpi_get_value(high, &value);
        expect(value.value.str && strcmp(value.value.str, bits) == 0, name, "live bits");
    }
}

static void check_array_list(const char *name)
{
    vpiHandle array = vpi_handle_by_name(name, NULL);
    vpiHandle list = array ? vpi_handle(vpiExpr, array) : NULL;
    vpiHandle g = vpi_handle_by_name("top.g", NULL);
    vpiHandle iter, operand;
    int is_list = list && vpi_get(vpiType, list) == vpiOperation
                      && vpi_get(vpiOpType, list) == vpiListOp;
    expect(is_list, name, "array connection list");
    if (!is_list) return;
    iter = vpi_iterate(vpiOperand, list);
    operand = iter ? vpi_scan(iter) : NULL;
    expect(operand && g && vpi_compare_objects(operand, g),
           name, "array list operand is the unsplit actual");
    if (operand)
        expect(vpi_scan(iter) == NULL, name, "one array list operand");
}

static PLI_INT32 probe(PLI_BYTE8 *unused)
{
    (void)unused;
    check_port("top.ar[1]", 0, "top.g", vpiBitSelect, 1, 1, sample ? "0" : "1");
    check_port("top.ar[0]", 0, "top.g", vpiBitSelect, 0, 0, sample ? "1" : "0");
    check_port("top.split[2]", 0, "top.ascending", vpiPartSelect, 8, 9, sample ? "01" : "10");
    check_port("top.split[3]", 0, "top.ascending", vpiPartSelect, 10, 11, sample ? "11" : "01");
    check_port("top.split[2]", 1, "top.driven", vpiPartSelect, -2, -3, sample ? "10" : "01");
    check_port("top.split[3]", 1, "top.driven", vpiPartSelect, -4, -5, sample ? "00" : "10");
    check_port("top.split[2]", 2, NULL, 0, 0, 0, NULL);
    check_port("top.split[3]", 2, NULL, 0, 0, 0, NULL);
    check_port("top.whole[1]", 0, "top.g", 0, 0, 0, sample ? "01" : "10");
    check_port("top.whole[0]", 0, "top.g", 0, 0, 0, sample ? "01" : "10");
    check_port("top.compound_split[2]", 0, "top.ascending", vpiPartSelect, 8, 9, sample ? "01" : "10");
    check_port("top.compound_split[3]", 0, "top.ascending", vpiPartSelect, 10, 11, sample ? "11" : "01");
    check_port("top.broadcast[1]", 0, "top.g", 0, 0, 0, sample ? "01" : "10");
    check_port("top.broadcast[0]", 0, "top.g", 0, 0, 0, sample ? "01" : "10");
    check_port("top.one[7]", 0, "top.g", 0, 0, 0, sample ? "01" : "10");
    check_array_list("top.ar");
    check_array_list("top.one");
    if (failures)
        vpi_control(vpiFinish, 1);
    else if (sample)
        vpi_printf("PASSED\n");
    sample++;
    return 0;
}

static void startup(void)
{
    s_vpi_systf_data data = {0};
    data.type = vpiSysTask;
    data.tfname = "$probe_array_port_conn";
    data.calltf = probe;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { startup, NULL };
