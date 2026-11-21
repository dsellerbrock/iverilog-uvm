#include <string.h>
#include <vpi_user.h>

struct expected_attr {
    const char *name;
    int on_definition;
    int line;
    int format;
    int integer;
    const char *text;
};

static unsigned failures;
static int compile_probe_called;

static void check(int ok, const char *path, const char *name, const char *what)
{
    if (!ok) {
        ++failures;
        vpi_printf("FAIL %s %s: %s\n", path, name, what);
    }
}

static int attribute_file(const char *file)
{
    static const char basename[] = "issue3069_vpi_module_attribute.sv";
    if (!file || strlen(file) < sizeof(basename) - 1)
        return 0;
    return strcmp(file + strlen(file) - sizeof(basename) + 1, basename) == 0;
}

static void check_value(vpiHandle attr, const char *path,
                        const struct expected_attr *expected)
{
    s_vpi_value value = {0};
    value.format = vpiObjTypeVal;
    vpi_get_value(attr, &value);
    check(value.format == expected->format, path, expected->name, "natural format");
    if (value.format != expected->format)
        return;

    int equal = 0;
    switch (expected->format) {
        case vpiScalarVal:
            equal = value.value.scalar == expected->integer;
            break;
        case vpiIntVal:
            equal = value.value.integer == expected->integer;
            break;
        case vpiRealVal:
            equal = value.value.real == 2.75;
            break;
        case vpiVectorVal:
            value.format = expected->text ? vpiBinStrVal : vpiIntVal;
            vpi_get_value(attr, &value);
            if (!expected->text) {
                equal = value.value.integer == expected->integer;
                break;
            }
            /* Compare every bit, including the declared width and X/Z. */
            /* fall through */
        case vpiStringVal:
            equal = value.value.str && strcmp(value.value.str, expected->text) == 0;
            break;
    }
    check(equal, path, expected->name, "attribute value");
}

static void check_attrs(const char *path, const struct expected_attr *expected,
                        unsigned count, int repeat)
{
    vpiHandle owner = vpi_handle_by_name(path, 0);
    check(owner && vpi_get(vpiType, owner) == vpiModule, path, "", "module handle");
    if (!owner)
        return;

    vpiHandle iter = vpi_iterate(vpiAttribute, owner);
    check(!!iter == (count != 0), path, "", "attribute iterator");
    if (!iter)
        return;

    vpiHandle first = 0;
    if (repeat) {
        first = vpi_scan(iter);
        check(first != 0, path, "", "first handle");
        check(vpi_free_object(iter), path, "", "early iterator release");
        iter = vpi_iterate(vpiAttribute, owner);
        check(iter != 0, path, "", "second iterator");
        if (!iter)
            return;
    }

    unsigned seen = 0;
    int found_first = 0;
    vpiHandle attr;
    while ((attr = vpi_scan(iter))) {
        const char *name = vpi_get_str(vpiName, attr);
        int on_definition = vpi_get(vpiDefAttribute, attr);
        unsigned idx;
        for (idx = 0; idx < count; ++idx)
            if (name && strcmp(name, expected[idx].name) == 0
                     && on_definition == expected[idx].on_definition)
                break;
        if (idx == count) {
            check(0, path, name ? name : "", "unexpected attribute or origin");
            continue;
        }
        const struct expected_attr *item = &expected[idx];
        check(!(seen & (1u << idx)), path, item->name, "duplicate attribute");
        seen |= 1u << idx;
        if (first && vpi_compare_objects(attr, first))
            found_first = 1;

        check(vpi_get(vpiType, attr) == vpiAttribute, path, item->name, "object type");
        vpiHandle parent = vpi_handle(vpiParent, attr);
        check(parent && vpi_compare_objects(parent, owner), path, item->name, "parent identity");
        check(vpi_get(vpiDefLineNo, attr) == item->line, path, item->name, "definition line");
        check(vpi_get(vpiLineNo, attr) == item->line, path, item->name, "source line");
        check(attribute_file(vpi_get_str(vpiDefFile, attr)), path, item->name, "definition file");
        check(attribute_file(vpi_get_str(vpiFile, attr)), path, item->name, "source file");
        check_value(attr, path, item);
    }
    check(seen == (1u << count) - 1, path, "", "complete attribute set");
    check(!repeat || found_first, path, "", "stable handle across iterators");
}

static PLI_INT32 compile_probe(PLI_BYTE8 *user)
{
    (void)user;
    static const struct expected_attr top[] = {
        {"flag", 1, 9, vpiScalarVal, vpi1, 0},
        {"byteattr", 1, 9, vpiVectorVal, 0, "11110001"},
    };
    compile_probe_called = 1;
    check_attrs("top", top, sizeof(top) / sizeof(top[0]), 1);
    return 0;
}

static PLI_INT32 inspect(PLI_BYTE8 *user)
{
    (void)user;
    static const struct expected_attr named[] = {
        {"shared", 1, 1, vpiIntVal, 23, 0},
        {"duplicate", 1, 2, vpiVectorVal, 0, "10100101"},
        {"shared", 0, 13, vpiIntVal, 17, 0},
        {"signed_value", 0, 13, vpiVectorVal, -13, 0},
        {"wide", 0, 13, vpiVectorVal, 0,
         "1" "00000000000000000000000000000000"
             "00000000000000000000000000000000" "xz"},
        {"fraction", 0, 14, vpiRealVal, 0, 0},
        {"text", 0, 14, vpiStringVal, 0, "A\"\\\nB"},
    };
    static const struct expected_attr positional[] = {
        {"shared", 1, 1, vpiIntVal, 23, 0},
        {"duplicate", 1, 2, vpiVectorVal, 0, "10100101"},
        {"shared", 0, 17, vpiIntVal, 17, 0},
    };

    check(compile_probe_called, "top", "", "compiletf ran");
    check_attrs("top.u", named, sizeof(named) / sizeof(named[0]), 0);
    check_attrs("top.bank[0]", named, sizeof(named) / sizeof(named[0]), 0);
    check_attrs("top.bank[1]", named, sizeof(named) / sizeof(named[0]), 0);
    check_attrs("top.v", positional, sizeof(positional) / sizeof(positional[0]), 0);
    check_attrs("top.w", positional, sizeof(positional) / sizeof(positional[0]), 0);
    check_attrs("top.unannotated", 0, 0, 0);
    check(!vpi_handle_by_name("top.flag", 0), "top", "flag", "attribute is not a member");
    if (!failures)
        vpi_printf("PASSED\n");
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data task = {0};
    task.type = vpiSysTask;
    task.tfname = "$inspect_module_attributes";
    task.compiletf = compile_probe;
    task.calltf = inspect;
    vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = {register_probe, 0};
