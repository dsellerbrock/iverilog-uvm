#include <string.h>
#include <vpi_user.h>

struct expected_attr {
    const char *name;
    int line;
    int format;
    int integer;
    const char *text;
};

static int failures;

static void check(int ok, const char *path, const char *attr, const char *what)
{
    if (!ok) {
        ++failures;
        vpi_printf("FAIL %s %s: %s\n", path, attr, what);
    }
}

static void check_value(vpiHandle handle, const char *path,
                        const struct expected_attr *expected)
{
    s_vpi_value value;
    value.format = vpiObjTypeVal;
    vpi_get_value(handle, &value);
    check(value.format == expected->format, path, expected->name, "natural format");
    if (value.format != expected->format)
        return;

    int equal = 0;
    switch (value.format) {
        case vpiIntVal:
            equal = value.value.integer == expected->integer;
            break;
        case vpiScalarVal:
            equal = value.value.scalar == expected->integer;
            break;
        case vpiVectorVal:
            value.format = expected->text ? vpiBinStrVal : vpiIntVal;
            vpi_get_value(handle, &value);
            if (expected->text)
                equal = value.value.str && strcmp(value.value.str, expected->text) == 0;
            else
                equal = value.value.integer == expected->integer;
            break;
        case vpiRealVal:
            equal = value.value.real == 2.75;
            break;
        case vpiStringVal:
            equal = value.value.str && strcmp(value.value.str, expected->text) == 0;
            break;
        case vpiTimeVal:
            equal = value.value.time && value.value.time->type == vpiSimTime
                 && value.value.time->high == 1 && value.value.time->low == 3;
            break;
    }
    check(equal, path, expected->name, "attribute value");
}

static vpiHandle check_attrs(const char *path, const struct expected_attr *expected,
                             unsigned count)
{
    vpiHandle owner = vpi_handle_by_name(path, 0);
    check(owner != 0, path, "", "variable handle");
    if (!owner)
        return 0;
    vpiHandle iter = vpi_iterate(vpiAttribute, owner);
    check(!!iter == (count != 0), path, "", "attribute iterator");
    if (!iter)
        return 0;

    vpiHandle reference = vpi_handle(vpiUse, iter);
    check(reference && vpi_compare_objects(reference, owner), path, "", "iterator reference");
    unsigned seen = 0;
    vpiHandle first = 0;
    vpiHandle attr;
    while ((attr = vpi_scan(iter))) {
        const char *name = vpi_get_str(vpiName, attr);
        unsigned idx;
        for (idx = 0; idx < count; ++idx)
            if (name && strcmp(name, expected[idx].name) == 0)
                break;
        if (idx == count) {
            check(0, path, name ? name : "", "unexpected attribute");
            continue;
        }
        const struct expected_attr *item = &expected[idx];
        check(!(seen & (1u << idx)), path, item->name, "duplicate attribute object");
        seen |= 1u << idx;
        if (idx == 0)
            first = attr;

        check(vpi_get(vpiType, attr) == vpiAttribute, path, item->name, "object type");
        vpiHandle parent = vpi_handle(vpiParent, attr);
        check(parent && vpi_compare_objects(parent, owner),
              path, item->name, "parent identity");
        check(vpi_get(vpiDefAttribute, attr) == 1, path, item->name, "definition flag");
        check(vpi_get(vpiDefLineNo, attr) == item->line, path, item->name, "definition line");
        check(vpi_get(vpiLineNo, attr) == item->line, path, item->name, "source line");
        const char *file = vpi_get_str(vpiDefFile, attr);
        const char *base = file ? strrchr(file, '/') : 0;
        check(file && strcmp(base ? base + 1 : file,
                             "issue3052_vpi_variable_attribute.sv") == 0,
              path, item->name, "definition file");
        check_value(attr, path, item);
    }
    check(seen == (1u << count) - 1, path, "", "complete attribute set");
    return first;
}

static PLI_INT32 inspect(PLI_BYTE8 *user)
{
    (void)user;
    static const struct expected_attr probe[] = {
        {"probe_attr", 6, vpiVectorVal, 3, 0},
    };
    static const struct expected_attr shared[] = {
        {"flag", 9, vpiScalarVal, vpi1, 0},
        {"signed_value", 9, vpiVectorVal, -13, 0},
        {"wide", 9, vpiVectorVal, 0,
         "1" "00000000000000000000000000000000"
             "00000000000000000000000000000000" "xz"},
        {"fraction", 10, vpiRealVal, 0, 0},
        {"text", 10, vpiStringVal, 0, "A\"\\\nB"},
        {"duplicate", 11, vpiVectorVal, 16, 0},
    };
    static const struct expected_attr single[] = {
        {"array_attr", 13, vpiVectorVal, 7, 0},
        {"queue_attr", 14, vpiVectorVal, 8, 0},
        {"real_owner", 15, vpiVectorVal, 9, 0},
        {"string_owner", 16, vpiVectorVal, 10, 0},
        {"time_value", 17, vpiTimeVal, 0, 0},
        {"quote\"name", 18, vpiVectorVal, 12, 0},
        {"instance_value", 2, vpiIntVal, 21, 0},
        {"instance_value", 2, vpiIntVal, 34, 0},
        {"one_bit_vector", 25, vpiVectorVal, 0, "z"},
        {"ref_attr", 29, vpiVectorVal, 13, 0},
        {"ref_attr", 30, vpiVectorVal, 14, 0},
    };
    static const char *paths[] = {
        "top.fixed_array", "top.queue_var", "top.r", "top.s",
        "top.timed", "top.escaped", "top.u.state", "top.v.state",
        "top.vector_value", "top.refs.x", "top.refs.r",
    };

    vpiHandle first = check_attrs("top.x", probe, 1);
    vpiHandle again = check_attrs("top.x", probe, 1);
    check(first && again && vpi_compare_objects(first, again),
          "top.x", "probe_attr", "stable handle across iterators");
    check_attrs("top.plain", 0, 0);
    check_attrs("top.a", shared, sizeof(shared) / sizeof(shared[0]));
    check_attrs("top.b", shared, sizeof(shared) / sizeof(shared[0]));
    for (unsigned idx = 0; idx < sizeof(single) / sizeof(single[0]); ++idx)
        check_attrs(paths[idx], &single[idx], 1);

    if (!failures)
        vpi_printf("PASSED\n");
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data task = {0};
    task.type = vpiSysTask;
    task.tfname = "$inspect_variable_attributes";
    task.calltf = inspect;
    vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = {register_probe, 0};
