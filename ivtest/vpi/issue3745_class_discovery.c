#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

/* Allow the same probe to run on the pre-fix VPI headers. */
#ifndef vpiVirtual
# define vpiVirtual 635
#endif

static int failures;

static void check(int condition, const char *message)
{
    if (!condition) {
        vpi_printf("FAIL: %s\n", message);
        ++failures;
    }
}

static void check_members(PLI_INT32 type, vpiHandle scope,
                          vpiHandle *expected, unsigned count,
                          const char *message)
{
    unsigned seen = 0, actual = 0;
    vpiHandle iter = vpi_iterate(type, scope);
    vpiHandle item;

    check((iter != 0) == (count != 0), message);
    if (!iter)
        return;
    while ((item = vpi_scan(iter))) {
        unsigned i;
        for (i = 0; i < count; ++i)
            if (item == expected[i])
                break;
        check(i < count && !(seen & (1u << i)), message);
        check(vpi_get(vpiType, item) == type, message);
        if (i < count)
            seen |= 1u << i;
        ++actual;
    }
    check(actual == count && seen == (1u << count) - 1, message);
}

static vpiHandle definition(vpiHandle type, const char *name,
                            vpiHandle scope, int is_virtual)
{
    check(type && vpi_get(vpiType, type) == vpiClassTypespec, name);
    if (!type)
        return 0;
    vpiHandle defn = vpi_handle(vpiClassDefn, type);
    check(defn && vpi_get(vpiType, defn) == vpiClassDefn, name);
    if (!defn)
        return 0;
    const char *actual = vpi_get_str(vpiName, defn);
    check(actual && strcmp(actual, name) == 0, "definition name");
    check(vpi_get(vpiAutomatic, defn) == 1, "definition automatic lifetime");
    check(vpi_get(vpiVirtual, defn) == is_virtual, "definition virtual flag");
    check(vpi_handle(vpiScope, defn) == scope, "definition lexical owner");
    check(vpi_handle(vpiClassDefn, type) == defn, "stable definition handle");
    return defn;
}

static vpiHandle variable_type(const char *path)
{
    vpiHandle var = vpi_handle_by_name(path, 0);
    check(var && vpi_get(vpiType, var) == vpiClassVar, path);
    if (!var)
        return 0;
    check(!vpi_handle(vpiClassObj, var), "class variable at simulation start");
    return vpi_handle(vpiClassTypespec, var);
}

static vpiHandle package_by_name(const char *name)
{
    vpiHandle iter = vpi_iterate(vpiPackage, 0);
    vpiHandle pkg;
    while (iter && (pkg = vpi_scan(iter))) {
        const char *actual = vpi_get_str(vpiName, pkg);
        if (actual && strcmp(actual, name) == 0) {
            vpi_free_object(iter);
            return pkg;
        }
    }
    return 0;
}

static PLI_INT32 check_at_start(p_cb_data data)
{
    (void)data;
    vpiHandle top = vpi_handle_by_name("top", 0);
    vpiHandle pkg = package_by_name("decls");
    vpiHandle top_twin = vpi_handle_by_name("top.Twin", 0);
    vpiHandle pkg_twin = vpi_handle_by_name("decls::Twin", 0);
    vpiHandle defs[] = {
        definition(top_twin, "Twin", top, 0),
        definition(pkg_twin, "Twin", pkg, 1),
        definition(vpi_handle_by_name("decls::payload", 0), "payload", pkg, 0),
        definition(vpi_handle_by_name("decls::Seed", 0), "Seed", pkg, 0),
    };
    check(top && pkg && defs[0] != defs[1], "same-spelled lexical declarations");
    check_members(vpiClassDefn, top, defs, 1, "module definitions");
    check_members(vpiClassDefn, pkg, defs + 1, 3, "package definitions");
    check_members(vpiClassDefn, 0, defs, 4, "global definitions");
    check_members(vpiClassDefn, 0, defs, 4, "repeated global definitions");

    vpiHandle specs[] = { variable_type("top.first"), variable_type("top.second") };
    vpiHandle repeated = variable_type("top.repeated");
    check(specs[0] && specs[1] && specs[0] != specs[1], "distinct specializations");
    check(specs[0] && repeated == specs[0], "canonical specialization");
    for (unsigned i = 0; i < 2; ++i)
        check(specs[i] && defs[2] && vpi_get(vpiType, specs[i]) == vpiClassTypespec &&
              vpi_handle(vpiClassDefn, specs[i]) == defs[2],
              "specialization points to the generic declaration");

    if (defs[0])
        check_members(vpiClassTypespec, defs[0], &top_twin, 1, "unconstructed class typespec");
    if (defs[1])
        check_members(vpiClassTypespec, defs[1], &pkg_twin, 1, "virtual class typespec");
    if (defs[2]) {
        check_members(vpiClassTypespec, defs[2], specs, 2, "concrete payload typespecs");
        check_members(vpiClassTypespec, defs[2], specs, 2, "repeated payload typespecs");
    }
    if (defs[3])
        check_members(vpiClassTypespec, defs[3], 0, 0, "unused generic class");

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
