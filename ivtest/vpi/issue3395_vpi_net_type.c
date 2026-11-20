#include <stdio.h>
#include <string.h>
#include <vpi_user.h>

static const struct {
    const char *name;
    PLI_INT32 net_type;
    const char *vcd_type;
} scalars[] = {
    {"s0",           vpiSupply0, "supply0"},
    {"s1",           vpiSupply1, "supply1"},
    {"t",            vpiTri,     "tri"},
    {"t0",           vpiTri0,    "tri0"},
    {"t1",           vpiTri1,    "tri1"},
    {"delayed_pull", vpiTri1,    "tri1"},
    {"held",         vpiTriReg,  "trireg"},
    {"ta",           vpiTriAnd,  "triand"},
    {"to",           vpiTriOr,   "trior"},
    {"wa",           vpiWand,    "wand"},
    {"wo",           vpiWor,     "wor"},
    {"uw",           vpiUwire,   "wire"},
    {"ordinary",     vpiWire,    "wire"},
    {"u.cap",        vpiTriReg,  "trireg"},
};

static int check_type(vpiHandle net, const char *name, PLI_INT32 expected)
{
    if (!net) {
        vpi_printf("FAIL: missing %s\n", name);
        return 1;
    }
    PLI_INT32 actual = vpi_get(vpiNetType, net);
    if (actual != expected) {
        vpi_printf("FAIL: %s vpiNetType %d, expected %d\n",
                   name, actual, expected);
        return 1;
    }
    return 0;
}

static int check_vcd(void)
{
    FILE *file = fopen("issue3395_vpi_net_type.vcd", "r");
    if (!file) {
        vpi_printf("FAIL: cannot open VCD\n");
        return 1;
    }
    unsigned seen[sizeof scalars / sizeof scalars[0]] = {0};
    int failures = 0;
    char line[256];
    while (fgets(line, sizeof line, file)) {
        char type[32], name[64];
        unsigned width;
        if (sscanf(line, "$var %31s %u %*s %63s", type, &width, name) != 3)
            continue;
        for (unsigned i = 0; i < sizeof scalars / sizeof scalars[0]; ++i) {
            // The leaf names of the dumped declarations are unique.
            const char *leaf = strrchr(scalars[i].name, '.');
            if (strcmp(name, leaf ? leaf + 1 : scalars[i].name) != 0)
                continue;
            ++seen[i];
            if (width != 1 || strcmp(type, scalars[i].vcd_type) != 0) {
                vpi_printf("FAIL: %s VCD declaration %s %u, expected %s 1\n",
                           scalars[i].name, type, width, scalars[i].vcd_type);
                ++failures;
            }
            break;
        }
    }
    fclose(file);
    for (unsigned i = 0; i < sizeof scalars / sizeof scalars[0]; ++i) {
        if (seen[i] != 1) {
            vpi_printf("FAIL: expected one VCD declaration for %s, found %u\n",
                       scalars[i].name, seen[i]);
            ++failures;
        }
    }
    return failures;
}

static PLI_INT32 check_net_types(PLI_BYTE8 *data)
{
    (void)data;
    vpiHandle top = vpi_handle_by_name("top", 0);
    int failures = 0;
    for (unsigned i = 0; i < sizeof scalars / sizeof scalars[0]; ++i)
        failures += check_type(vpi_handle_by_name(scalars[i].name, top),
                               scalars[i].name, scalars[i].net_type);

    vpiHandle array = vpi_handle_by_name("words", top);
    failures += check_type(array, "words", vpiTriAnd);
    if (array)
        failures += check_type(vpi_handle_by_index(array, 3), "words[3]",
                               vpiTriAnd);

    vpiHandle vector = vpi_handle_by_name("vector_net", top);
    failures += check_type(vector, "vector_net", vpiWor);
    if (vector)
        failures += check_type(vpi_handle_by_index(vector, 3), "vector_net[3]",
                               vpiWor);

    vpiHandle packed = vpi_handle_by_name("packed_net", top);
    failures += check_type(packed, "packed_net", vpiWand);
    if (packed) {
        vpiHandle view = vpi_handle_by_index(packed, 1);
        failures += check_type(view, "packed_net[1]", vpiWand);
        if (view)
            failures += check_type(vpi_handle_by_index(view, 3),
                                   "packed_net[1][3]", vpiWand);
    }

    failures += check_vcd();
    if (failures == 0)
        vpi_printf("PASSED\n");
    return 0;
}

static void register_check(void)
{
    s_vpi_systf_data task = {0};
    task.type = vpiSysTask;
    task.tfname = "$issue3395_check";
    task.calltf = check_net_types;
    vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = {register_check, 0};
