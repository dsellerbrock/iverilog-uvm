#include <stdio.h>
#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

/* Annex M value for running the probe on the pre-fix headers. */
#ifndef vpiMethods
# define vpiMethods 730
#endif

static int failures;

static void check(int condition, const char *context, const char *message)
{
    if (!condition) {
        vpi_printf("FAIL %s: %s\n", context, message);
        ++failures;
    }
}

struct member {
    const char *name;
    int type;
};

static void check_members(int relation, const char *path, vpiHandle definition,
                          const struct member *expected,
                          unsigned count)
{
    const char *context = relation == vpiMethods ? "vpiMethods" : "vpiInternalScope";
    vpiHandle iter = vpi_iterate(relation, definition);
    vpiHandle item;
    unsigned seen = 0;

    if (!iter) {
        check(count == 0, path, context);
        return;
    }
    while ((item = vpi_scan(iter))) {
        const char *name = vpi_get_str(vpiName, item);
        unsigned i;
        for (i = 0; i < count; ++i)
            if (name && strcmp(name, expected[i].name) == 0)
                break;
        if (i == count) {
            check(0, context, name ? name : "<unnamed scope>");
            continue;
        }

        check(!(seen & (1u << i)), context, "duplicate member");
        seen |= 1u << i;
        check(vpi_get(vpiType, item) == expected[i].type, context, expected[i].name);

        char full_path[128];
        snprintf(full_path, sizeof full_path, "%s.%s", path, expected[i].name);
        vpiHandle emitted = vpi_handle_by_name(full_path, 0);
        if (emitted && expected[i].type == vpiClassDefn)
            emitted = vpi_handle(vpiClassDefn, emitted);
        check(item == emitted, expected[i].name, "expected existing handle");
        if (expected[i].type == vpiTask || expected[i].type == vpiFunction)
            check(vpi_get(vpiAutomatic, item) == 1, expected[i].name,
                  "expected automatic subroutine lifetime");
    }
    check(seen == (1u << count) - 1, path, context);
    check(count != 0, path, "expected a null iterator");
}

static void check_class(const char *path, const struct member *expected,
                        unsigned methods, unsigned scopes)
{
    vpiHandle scope = vpi_handle_by_name(path, 0);
    vpiHandle defn = scope ? vpi_handle(vpiClassDefn, scope) : 0;
    check(defn && vpi_get(vpiType, defn) == vpiClassDefn, path, "expected definition");
    if (defn) {
        check_members(vpiMethods, path, defn, expected, methods);
        check_members(vpiInternalScope, path, defn, expected, scopes);
    }
}

static PLI_INT32 check_at_start(p_cb_data data)
{
    const struct member main_scopes[] = {
        {"static_value", vpiFunction},
        {"bump", vpiTask},
        {"external_value", vpiFunction},
        {"new", vpiFunction},
        {"Nested", vpiClassDefn},
    };
    const struct member nested_methods[] = {{"nested_value", vpiFunction}};
    const struct member prototypes[] = {
        {"required_value", vpiFunction},
        {"required_task", vpiTask},
    };
    (void)data;

    check_class("top.Main", main_scopes, 4, 5);
    check_class("top.Main.Nested", nested_methods, 1, 1);
    check_class("top.WithInitializer", 0, 0, 0);
    check_class("top.Prototypes", prototypes, 2, 2);

    vpiHandle implicit = vpi_handle_by_name("top.WithInitializer.new@", 0);
    check(implicit && vpi_get(vpiType, implicit) == vpiFunction, "WithInitializer",
          "expected emitted synthetic constructor");
    vpiHandle block = vpi_handle_by_name("top.Main.bump.method_block", 0);
    check(block && vpi_get(vpiType, block) == vpiNamedBegin, "bump",
          "expected emitted method-local block");
    vpiHandle proto = vpi_handle_by_name("top.Prototypes.required_value", 0);
    check(proto && !vpi_handle(vpiStmt, proto), "required_value", "expected bodyless prototype");

    if (!failures)
        vpi_printf("PASSED\n");
    return 0;
}

static void register_probe(void)
{
    s_cb_data cb = {0};
    cb.reason = cbStartOfSimulation;
    cb.cb_rtn = check_at_start;
    vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
