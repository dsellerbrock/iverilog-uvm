#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

/* Also exercise the original compiler and runtime with their installed headers. */
#ifndef vpiConstraint
#define vpiConstraint 653
#endif

struct expected_constraint {
    const char *name;
    int automatic;
    int is_virtual;
    int access;
};

static const struct expected_constraint base_constraints[] = {
    {"z_limit", 1, 0, 0},
    {"p_pure", 1, 1, 0},
    {"empty_block", 1, 0, 0},
    {"m_extern", 0, 0, vpiExternAcc},
    {"k_implicit", 1, 0, vpiExternAcc},
    {"a_range", 1, 0, 0},
    {"b_empty_prototype", 1, 0, 0}
};

static const struct expected_constraint derived_constraints[] = {
    {"z_limit", 1, 0, 0},
    {"p_pure", 1, 0, 0}
};

static unsigned failures;

static int check(int condition, const char *owner, const char *message)
{
    if (!condition) {
        vpi_printf("FAIL %s: %s\n", owner, message);
        ++failures;
    }
    return condition;
}

static vpiHandle relation(int code, vpiHandle obj)
{
    return obj ? vpi_handle(code, obj) : 0;
}

static vpiHandle iterate(vpiHandle obj)
{
    return obj ? vpi_iterate(vpiConstraint, obj) : 0;
}

static vpiHandle check_constraints(vpiHandle obj, int kind, const char *owner,
                                   const struct expected_constraint *expected,
                                   unsigned count)
{
    vpiHandle first = 0;
    unsigned i;
    if (!check(obj && vpi_get(vpiType, obj) == kind, owner, "owner kind"))
        return 0;

    vpiHandle iter = iterate(obj);
    if (!check((iter != 0) == (count != 0), owner, "constraint iterator presence")) {
        if (iter)
            vpi_free_object(iter);
        return 0;
    }
    if (!iter)
        return 0;

    for (i = 0; i < count; ++i) {
        vpiHandle item = vpi_scan(iter);
        if (!check(item != 0, owner, expected[i].name))
            return first;
        if (!i)
            first = item;
        check(vpi_get(vpiType, item) == vpiConstraint, owner, "constraint kind");
        const char *name = vpi_get_str(vpiName, item);
        check(name && strcmp(name, expected[i].name) == 0, owner, expected[i].name);
        check(vpi_get(vpiAutomatic, item) == expected[i].automatic &&
              vpi_get(vpiVirtual, item) == expected[i].is_virtual &&
              vpi_get(vpiAccessType, item) == expected[i].access,
              owner, "constraint flags");
    }
    if (!check(!vpi_scan(iter), owner, "exact declaration count"))
        vpi_free_object(iter);

    iter = iterate(obj);
    if (check(iter != 0, owner, "second iterator")) {
        vpiHandle again = vpi_scan(iter);
        check(again && vpi_compare_objects(again, first), owner, "stable handle");
        if (again)
            vpi_free_object(iter);
    }
    return first;
}

static PLI_INT32 check_class_constraints(PLI_BYTE8 *data)
{
    (void)data;
    vpiHandle derived = relation(vpiClassTypespec, vpi_handle_by_name("top.first", 0));
    vpiHandle derived2 = relation(vpiClassTypespec, vpi_handle_by_name("top.second", 0));
    vpiHandle defn = relation(vpiClassDefn, derived);
    vpiHandle lexical_base = relation(vpiClassTypespec, relation(vpiExtends, defn));
    vpiHandle base_defn = relation(vpiClassDefn, lexical_base);
    vpiHandle base = relation(vpiExtends, derived);
    vpiHandle base2 = relation(vpiExtends, derived2);
    vpiHandle inherits = relation(vpiClassTypespec, vpi_handle_by_name("top.inherits", 0));
    unsigned base_count = sizeof base_constraints / sizeof base_constraints[0];
    unsigned derived_count = sizeof derived_constraints / sizeof derived_constraints[0];

    check(derived2 && derived2 != derived && relation(vpiClassDefn, derived2) == defn,
          "Derived", "distinct specializations of one declaration");
    check(base && base2 && base != base2 && base_defn &&
          relation(vpiClassDefn, base) == base_defn &&
          relation(vpiClassDefn, base2) == base_defn,
          "Base", "base typespecs resolve to the owning declaration");

    vpiHandle base_first = check_constraints(base_defn, vpiClassDefn, "Base definition",
                                             base_constraints, base_count);
    vpiHandle derived_first = check_constraints(defn, vpiClassDefn, "Derived definition",
                                                derived_constraints, derived_count);
    check(base_first && derived_first && !vpi_compare_objects(base_first, derived_first),
          "Derived definition", "override is a distinct declaration");
    check_constraints(lexical_base, vpiClassTypespec, "lexical Base", 0, 0);
    base_first = check_constraints(base, vpiClassTypespec, "Base#(6)",
                                   base_constraints, base_count);
    derived_first = check_constraints(derived, vpiClassTypespec, "Derived#(6)",
                                      derived_constraints, derived_count);
    check(base_first && derived_first && !vpi_compare_objects(base_first, derived_first),
          "Derived#(6)", "override is distinct from the base constraint");
    check_constraints(base2, vpiClassTypespec, "Base#(8)", base_constraints, base_count);
    check_constraints(derived2, vpiClassTypespec, "Derived#(8)",
                      derived_constraints, derived_count);
    check_constraints(inherits, vpiClassTypespec, "Inherits typespec", 0, 0);
    check_constraints(relation(vpiClassDefn, inherits), vpiClassDefn, "Inherits definition", 0, 0);

    if (!failures)
        vpi_printf("PASSED\n");
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data task = {0};
    task.type = vpiSysTask;
    task.tfname = "$check_class_constraints";
    task.calltf = check_class_constraints;
    vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = {register_probe, 0};
