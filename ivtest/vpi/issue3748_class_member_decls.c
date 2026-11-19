#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

/* Permit running this same probe against the pre-fix installed headers. */
#ifndef vpiRandType
# define vpiRandType 610
# define vpiNotRand 1
# define vpiRand 2
# define vpiRandC 3
# define vpiConstantVariable 612
# define vpiProtectedVis 2
# define vpiLocalVis 3
#endif

struct declaration {
    const char *name;
    int kind, automatic, visibility, const_var, rand_type;
    vpiHandle handle;
};

static struct declaration properties[] = {
    {"field",            vpiIntVar,  1, vpiPublicVis,    0, vpiNotRand, 0},
    {"shared",           vpiIntVar,  0, vpiPublicVis,    0, vpiNotRand, 0},
    {"limit",            vpiIntVar,  1, vpiLocalVis,     1, vpiNotRand, 0},
    {"randomized_field", vpiIntVar,  1, vpiProtectedVis, 0, vpiRand,    0},
    {"choices",          vpiBitVar,  1, vpiPublicVis,    0, vpiRandC,   0},
    {"child",            vpiClassVar, 1, vpiPublicVis,    0, vpiNotRand, 0},
    {"matrix",           vpiArrayVar, 1, vpiPublicVis,    0, vpiNotRand, 0},
    {"packed_value",     vpiLogicVar, 1, vpiPublicVis,    0, vpiNotRand, 0},
    {"dynamic_values",   vpiArrayVar, 1, vpiPublicVis,    0, vpiNotRand, 0},
    {"mixed",            vpiArrayVar, 1, vpiPublicVis,    0, vpiNotRand, 0},
    {"lookup",           vpiArrayVar, 1, vpiPublicVis,    0, vpiNotRand, 0},
    {"queued",           vpiArrayVar, 1, vpiPublicVis,    0, vpiNotRand, 0},
    {"link",             vpiVirtualInterfaceVar, 1, vpiPublicVis, 0, vpiNotRand, 0},
    {"links",            vpiArrayVar, 1, vpiPublicVis,    0, vpiNotRand, 0},
};

static struct declaration events[] = {
    {"ready", vpiNamedEvent, 1, 0, 0, 0, 0},
    {"updated", vpiNamedEvent, 0, 0, 0, 0, 0},
};

static struct declaration event_arrays[] = {
    {"slots", vpiNamedEventArray, 1, 0, 0, 0, 0},
    {"notifications", vpiNamedEventArray, 0, 0, 0, 0, 0},
};

#define COUNT(array) (sizeof(array) / sizeof(*(array)))

static int failures;
static vpiHandle definition;

static void check(int condition, const char *message, const char *name)
{
    if (!condition) {
        vpi_printf("FAIL: %s (%s)\n", message, name);
        ++failures;
    }
}

static int get_int(vpiHandle obj)
{
    s_vpi_value value = {0};
    value.format = vpiIntVal;
    if (obj)
        vpi_get_value(obj, &value);
    return obj && value.format == vpiIntVal ? value.value.integer : -999;
}

static void check_value_rejected(vpiHandle obj, const char *name)
{
    s_vpi_error_info error;
    s_vpi_time delay = {vpiSimTime, 0, 1, 0};
    s_vpi_value value = {0};
    value.format = vpiIntVal;
    vpi_get_value(obj, &value);
    check(value.format == vpiSuppressVal && vpi_chk_error(&error) == vpiError,
          "get rejected", name);
    value.format = vpiIntVal;
    value.value.integer = 1234;
    vpi_put_value(obj, &value, 0, vpiNoDelay);
    check(vpi_chk_error(&error) == vpiError, "immediate put rejected", name);
    check(!vpi_put_value(obj, &value, &delay, vpiTransportDelay | vpiReturnEvent)
          && vpi_chk_error(&error) == vpiError, "delayed put rejected", name);

    /* Time queries on these object kinds must also tolerate an unbound view. */
    s_vpi_time now = {vpiScaledRealTime, 0, 0, 0};
    vpi_get_time(obj, &now);
    check(now.real >= 0.0, "time query", name);
}

static void check_declarations(int selector, struct declaration *expected,
                               unsigned count, int before)
{
    vpiHandle iter = vpi_iterate(selector, definition);
    vpiHandle item;
    unsigned seen = 0, total = 0;
    while (iter && (item = vpi_scan(iter))) {
        ++total;
        const char *name = vpi_get_str(vpiName, item);
        unsigned i;
        for (i = 0; i < count; ++i)
            if (name && !strcmp(name, expected[i].name))
                break;
        check(i < count, "unexpected declaration", name ? name : "<unnamed>");
        if (i == count)
            continue;
        const struct declaration *decl = &expected[i];
        name = decl->name; /* vpi_get_str uses a temporary shared buffer. */
        check(!(seen & (1u << i)), "duplicate declaration", name);
        seen |= 1u << i;
        check(vpi_get(vpiType, item) == decl->kind, "type", name);
        check(vpi_get(vpiAutomatic, item) == decl->automatic, "lifetime", name);
        check(vpi_handle(vpiScope, item) == definition, "definition scope", name);
        check(!vpi_handle(vpiParent, item), "unfixed parent", name);
        if (selector == vpiVariables) {
            check(vpi_get(vpiVisibility, item) == decl->visibility, "visibility", name);
            check(vpi_get(vpiConstantVariable, item) == decl->const_var, "const", name);
            check(vpi_get(vpiRandType, item) == decl->rand_type, "random qualifier", name);
            const char *full_name = vpi_get_str(vpiFullName, item);
            if (decl->automatic)
                check(!full_name, "instance declaration has no full name", name);
            else
                check(full_name && !strcmp(full_name, "top.Derived.shared"),
                      "static declaration full name", name);
        }
        if (before)
            expected[i].handle = item;
        else
            check(item == decl->handle, "stable declaration handle", name);
        check_value_rejected(item, name);
    }
    check(seen == (1u << count) - 1 && total == count,
          "declaration set", selector == vpiVariables ? "variables"
                           : selector == vpiNamedEvent ? "events" : "event arrays");
}

static vpiHandle declaration_named(const char *name)
{
    for (unsigned i = 0; i < COUNT(properties); ++i)
        if (!strcmp(name, properties[i].name))
            return properties[i].handle;
    return 0;
}

static void check_bounds(vpiHandle obj, int left, int right, const char *name)
{
    check(obj && get_int(vpi_handle(vpiLeftRange, obj)) == left &&
          get_int(vpi_handle(vpiRightRange, obj)) == right, "bounds", name);
}

static void check_dimensions(vpiHandle obj, int size, const int bounds[][2],
                             unsigned count, const char *name)
{
    if (!obj)
        return; /* The declaration set check already reported the failure. */
    check(vpi_get(vpiSize, obj) == size, "size", name);
    check_bounds(obj, bounds[0][0], bounds[0][1], name);
    vpiHandle iter = vpi_iterate(vpiRange, obj);
    vpiHandle range;
    unsigned actual = 0;
    while (iter && (range = vpi_scan(iter))) {
        check(actual < count && vpi_get(vpiType, range) == vpiRange, "range type", name);
        if (actual < count) {
            check_bounds(range, bounds[actual][0], bounds[actual][1], name);
            int span = bounds[actual][0] - bounds[actual][1];
            check(vpi_get(vpiSize, range) == 1 + (span < 0 ? -span : span), "range size", name);
        }
        ++actual;
    }
    check(actual == count, "range count", name);
}

static void check_empty_dimensions(const char *name, int kind, int fixed_prefix)
{
    vpiHandle obj = declaration_named(name);
    if (!obj)
        return;
    check(vpi_get(vpiArrayType, obj) == kind && vpi_get(vpiSize, obj) == fixed_prefix,
          "array kind and size", name);
    vpiHandle iter = vpi_iterate(vpiRange, obj);
    vpiHandle range = iter ? vpi_scan(iter) : 0;
    if (fixed_prefix && range) {
        check_bounds(range, 0, fixed_prefix - 1, name);
        range = vpi_scan(iter);
    }
    check(range && !vpi_get(vpiSize, range) && !vpi_handle(vpiLeftRange, range) &&
          !vpi_handle(vpiRightRange, range), "empty range", name);
    if (range)
        check(!vpi_scan(iter), "range count", name);
}

static PLI_INT32 check_start(p_cb_data data)
{
    (void)data;
    vpiHandle empty = vpi_handle_by_name("top.empty_obj", 0);
    vpiHandle type = empty ? vpi_handle(vpiClassTypespec, empty) : 0;
    definition = type ? vpi_handle(vpiClassDefn, type) : 0;
    check(definition && empty && !vpi_handle(vpiClassObj, empty),
          "definition reachable from a null class variable", "Derived");
    if (!definition)
        return 0;

    check_declarations(vpiVariables, properties, COUNT(properties), 1);
    check_declarations(vpiNamedEvent, events, COUNT(events), 1);
    check_declarations(vpiNamedEventArray, event_arrays, COUNT(event_arrays), 1);
    check(!vpi_iterate(vpiVirtualInterfaceVar, definition), "lexical selector inapplicable", "link");

    const int matrix[][2] = {{3, 2}, {-1, 1}};
    const int packed[][2] = {{1, 0}, {-2, 1}};
    const int vif_array[][2] = {{0, 1}};
    const int slot_array[][2] = {{0, 1}};
    const int notifications[][2] = {{4, 2}};
    check_dimensions(declaration_named("matrix"), 6, matrix, COUNT(matrix), "matrix");
    check_dimensions(declaration_named("packed_value"), 8, packed, COUNT(packed), "packed_value");
    check_dimensions(declaration_named("links"), 2, vif_array, COUNT(vif_array), "links");
    check_dimensions(event_arrays[0].handle, 2, slot_array, COUNT(slot_array), "slots");
    check_dimensions(event_arrays[1].handle, 3, notifications, COUNT(notifications), "notifications");
    check_empty_dimensions("dynamic_values", vpiDynamicArray, 0);
    check_empty_dimensions("mixed", vpiStaticArray, 2);
    check_empty_dimensions("lookup", vpiAssocArray, 0);
    check_empty_dimensions("queued", vpiQueueArray, 0);

    vpiHandle child = declaration_named("child");
    if (child) {
        vpiHandle child_type = vpi_handle_by_name("top.Item", 0);
        check(child_type && vpi_handle(vpiClassTypespec, child) == child_type &&
              !vpi_handle(vpiClassObj, child), "declared class type without object", "child");
    }
    vpiHandle array = event_arrays[1].handle;
    if (array) {
        vpiHandle slot = vpi_handle_by_index(array, 3);
        check(slot && vpi_get(vpiType, slot) == vpiNamedEvent &&
              vpi_handle(vpiScope, slot) == definition && vpi_handle(vpiParent, slot) == array &&
              get_int(vpi_handle(vpiIndex, slot)) == 3, "event array element", "notifications[3]");
        check(slot == vpi_handle_by_index(array, 3) && !vpi_handle_by_index(array, 1),
              "stable in-bounds element", "notifications[3]");
        if (slot)
            check_value_rejected(slot, "notifications[3]");
    }
    return 0;
}

static PLI_INT32 check_live(PLI_BYTE8 *data)
{
    (void)data;
    if (definition) {
        check_declarations(vpiVariables, properties, COUNT(properties), 0);
        check_declarations(vpiNamedEvent, events, COUNT(events), 0);
        check_declarations(vpiNamedEventArray, event_arrays, COUNT(event_arrays), 0);
    }
    vpiHandle field = vpi_handle_by_name("top.obj.field", 0);
    vpiHandle shared = vpi_handle_by_name("top.obj.shared", 0);
    vpiHandle static_storage = vpi_handle_by_name("top.Derived.shared", 0);
    vpiHandle nested = vpi_handle_by_name("top.obj.child.number", 0);
    vpiHandle updated = vpi_handle_by_name("top.Derived.updated", 0);
    check(get_int(field) == 23 && field != declaration_named("field"),
          "live instance value", "field");
    check(get_int(shared) == 31 && get_int(static_storage) == 31 &&
          static_storage != declaration_named("shared"), "live static value", "shared");
    check(get_int(nested) == 47, "live nested value", "child.number");

    s_vpi_value value = {0};
    value.format = vpiIntVal;
    value.value.integer = 24;
    if (field)
        vpi_put_value(field, &value, 0, vpiNoDelay);
    value.value.integer = 32;
    if (shared)
        vpi_put_value(shared, &value, 0, vpiNoDelay);
    check(get_int(static_storage) == 32, "live shared storage changed", "shared");
    if (updated)
        vpi_put_value(updated, 0, 0, vpiNoDelay);
    return 0;
}

static PLI_INT32 result(PLI_BYTE8 *data)
{
    (void)data;
    if (!failures)
        vpi_printf("PASSED\n");
    return 0;
}

static void register_probe(void)
{
    s_cb_data cb = {0};
    cb.reason = cbStartOfSimulation;
    cb.cb_rtn = check_start;
    vpi_register_cb(&cb);

    s_vpi_systf_data tf = {0};
    tf.type = vpiSysTask;
    tf.tfname = "$issue3748_check_live";
    tf.calltf = check_live;
    vpi_register_systf(&tf);
    tf.tfname = "$issue3748_result";
    tf.calltf = result;
    vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {register_probe, 0};
