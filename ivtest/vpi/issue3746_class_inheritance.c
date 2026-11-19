#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

/* The regression also runs against the pre-fix headers. */
#ifndef vpiExtends
#define vpiExtends 677
#endif
#ifndef vpiDerivedClasses
#define vpiDerivedClasses 727
#endif

static unsigned failures;

static int check(int condition, const char *message)
{
    if (!condition) {
        vpi_printf("FAIL: %s\n", message);
        ++failures;
    }
    return condition;
}

static vpiHandle relation(int code, vpiHandle obj)
{
    return obj ? vpi_handle(code, obj) : 0;
}

static vpiHandle iterate(int code, vpiHandle obj)
{
    return obj ? vpi_iterate(code, obj) : 0;
}

static vpiHandle scan(vpiHandle iter)
{
    return iter ? vpi_scan(iter) : 0;
}

static int named(vpiHandle obj, const char *name)
{
    const char *actual = obj ? vpi_get_str(vpiName, obj) : 0;
    return actual && strcmp(actual, name) == 0;
}

static vpiHandle extends(vpiHandle defn, vpiHandle base_defn, const char *name)
{
    vpiHandle ext = relation(vpiExtends, defn);
    if (!check(ext && vpi_get(vpiType, ext) == vpiExtends, "definition extends object"))
        return 0;
    check(relation(vpiExtends, defn) == ext, "stable extends handle");
    vpiHandle base = relation(vpiClassTypespec, ext);
    check(base && vpi_get(vpiType, base) == vpiClassTypespec && named(base, name),
          "lexical base reference");
    check(relation(vpiClassDefn, base) == base_defn, "lexical base declaration identity");
    check(!iterate(vpiVariables, base), "lexical base has no specialization members");
    return ext;
}

static void descendants(vpiHandle defn, unsigned count, const vpiHandle *expected)
{
    vpiHandle iter = iterate(vpiDerivedClasses, defn);
    unsigned seen = 0;
    vpiHandle item;
    check((iter != 0) == (count != 0), "descendant iterator presence");
    while ((item = scan(iter))) {
        unsigned i;
        for (i = 0; i < count; ++i)
            if (item == expected[i])
                break;
        if (check(i < count && !(seen & (1u << i)), "unique expected descendant"))
            seen |= 1u << i;
        check(vpi_get(vpiType, item) == vpiClassDefn, "descendant is a class definition");
    }
    check(seen == (1u << count) - 1, "exact descendant set");
}

static int integer_is(vpiHandle obj, int expected)
{
    s_vpi_value value;
    if (!obj)
        return 0;
    value.format = vpiIntVal;
    vpi_get_value(obj, &value);
    return value.format == vpiIntVal && value.value.integer == expected;
}

static void check_args(vpiHandle ext, int type, int first, int second)
{
    vpiHandle iter = iterate(vpiArgument, ext);
    if (!check(iter != 0, "constructor actual iterator"))
        return;
    vpiHandle arg = vpi_scan(iter);
    if (check(arg && vpi_get(vpiType, arg) == type, "first constructor expression"))
        check(integer_is(arg, first), "first constructor expression value");
    if (!arg)
        return;
    arg = vpi_scan(iter);
    if (check(arg && vpi_get(vpiType, arg) == type, "second constructor expression"))
        check(integer_is(arg, second), "second constructor expression value");
    if (arg)
        check(!vpi_scan(iter), "exact constructor argument count");
}

static void check_tag(vpiHandle type, int tag)
{
    vpiHandle iter = iterate(vpiParameter, type);
    vpiHandle param = scan(iter);
    check(named(param, "Tag") && integer_is(param, tag), "concrete base parameter actual");
    if (param)
        check(!vpi_scan(iter), "exact base parameter count");
}

static vpiHandle check_base_assign(vpiHandle reference, const char *name, int by_name)
{
    vpiHandle iter = iterate(vpiParamAssign, reference);
    vpiHandle assign = scan(iter);
    if (!check(assign && vpi_get(vpiType, assign) == vpiParamAssign,
               "lexical base has parameter assignment"))
        return 0;
    vpiHandle lhs = relation(vpiLhs, assign);
    check(named(lhs, name) && vpi_get(vpiConnByName, assign) == by_name,
          "base formal and connection style");
    check(!vpi_scan(iter), "exact lexical parameter assignment count");
    return assign;
}

static PLI_INT32 check_inheritance(PLI_BYTE8 *data)
{
    (void)data;
    enum { B5, B9, D5, D5_AGAIN, D9, G, U, SAME_SCOPE, MARKER, OPEN_B, OPEN_D, COUNT };
    vpiHandle types[COUNT], defs[COUNT];
    vpiHandle runtime_type = 0;
    vpiHandle args = vpi_iterate(vpiArgument, vpi_handle(vpiSysTfCall, 0));
    unsigned i;
    for (i = 0; i < COUNT; ++i) {
        vpiHandle var = vpi_scan(args);
        if (i == D5)
            runtime_type = relation(vpiClassDefn, var);
        types[i] = relation(vpiClassTypespec, var);
        defs[i] = relation(vpiClassDefn, types[i]);
    }
    vpi_scan(args);
    if (check(defs[B5] && defs[B5] == defs[B9] && defs[D5] &&
              defs[D5] == defs[D9] && defs[D5] == defs[D5_AGAIN] &&
              defs[G] && defs[U] && defs[SAME_SCOPE] && defs[MARKER] &&
              defs[U] != defs[B5],
              "lexical identities across scopes and specializations")) {
        vpiHandle expected[] = {defs[D5], defs[G]};
        descendants(defs[B5], 2, expected);
        descendants(defs[B5], 2, expected);
        descendants(defs[D5], 1, expected + 1);
        descendants(defs[G], 0, 0);
        descendants(defs[U], 1, &defs[SAME_SCOPE]);
        descendants(defs[SAME_SCOPE], 0, 0);
        descendants(defs[MARKER], 0, 0);
        check(!relation(vpiExtends, defs[B5]) && !relation(vpiExtends, defs[U]),
              "roots and implementers have no extends object");

        vpiHandle de = extends(defs[D5], defs[B5], "Base");
        vpiHandle ge = extends(defs[G], defs[D5], "Derived");
        vpiHandle local = extends(defs[SAME_SCOPE], defs[U], "Base");
        check(local && !iterate(vpiArgument, local), "implicit empty chain");
        vpiHandle lexical_base = relation(vpiClassTypespec, de);
        vpiHandle lexical_derived = relation(vpiClassTypespec, ge);
        check(lexical_base && lexical_base != types[B5] && lexical_base != types[B9],
              "lexical base distinct from both concrete base types");
        check(lexical_base && relation(vpiExtends, lexical_derived) == lexical_base,
              "lexical typespec base round trip");
        vpiHandle tag = relation(vpiRhs, check_base_assign(lexical_base, "Tag", 1));
        check(named(tag, "N") && vpi_get(vpiType, tag) == vpiParameter &&
              relation(vpiClassDefn, relation(vpiScope, tag)) == defs[D5],
              "lexical parameter reference retains declaration identity");
        vpiHandle n = relation(vpiRhs, check_base_assign(lexical_derived, "N", 0));
        check(n && vpi_get(vpiType, n) == vpiConstant && integer_is(n, 5),
              "lexical parameter literal retains its value");
        check_args(de, vpiConstant, 31, 7);
    }

    check(types[D5] && types[D5] == types[D5_AGAIN] && types[D5] != types[D9],
          "distinct concrete specializations and stable repeated type");
    vpiHandle base5 = relation(vpiExtends, types[D5]);
    vpiHandle base9 = relation(vpiExtends, types[D9]);
    check(base5 && base5 == types[B5], "Derived#(5) returns Base#(5) directly");
    check(base9 && base9 == types[B9] && base9 != base5,
          "Derived#(9) returns Base#(9) directly");
    check(types[D5] && relation(vpiExtends, types[G]) == types[D5],
          "Grandchild returns Derived#(5) directly");
    check(types[U] && relation(vpiExtends, types[SAME_SCOPE]) == types[U],
          "unqualified base resolves to the same-scope type");
    check(!relation(vpiExtends, types[B5]) && !relation(vpiExtends, types[U]),
          "roots have no concrete base");
    check(!iterate(vpiDerivedClasses, types[B5]), "descendants require a definition receiver");
    check(named(relation(vpiBaseTypespec, runtime_type), "Base"),
          "runtime base relation used by cast");
    check_tag(base5, 5);
    check_tag(base9, 9);

    if (check(defs[OPEN_B] && defs[OPEN_D], "required type parameter definitions")) {
        descendants(defs[OPEN_B], 1, &defs[OPEN_D]);
        vpiHandle ext = extends(defs[OPEN_D], defs[OPEN_B], "OpenBase");
        check_args(ext, vpiConstant, 17, 29);
        check(types[OPEN_B] && relation(vpiExtends, types[OPEN_D]) == types[OPEN_B],
              "required type parameter specialization base");
    }
    if (!failures)
        vpi_printf("PASS\n");
    return 0;
}

static PLI_INT32 check_chain(PLI_BYTE8 *which)
{
    vpiHandle iter = vpi_iterate(vpiArgument, vpi_handle(vpiSysTfCall, 0));
    vpiHandle type = relation(vpiClassTypespec, vpi_scan(iter));
    vpiHandle first = vpi_scan(iter);
    vpiHandle second = which ? vpi_scan(iter) : 0;
    vpi_scan(iter);
    vpiHandle ext = relation(vpiExtends, relation(vpiClassDefn, type));
    if (!which) {
        check(integer_is(first, 11), "active constructor formal value");
        check_args(ext, vpiOperation, 14, 20);
        return 0;
    }

    vpiHandle assign = check_base_assign(relation(vpiClassTypespec, ext), "Kind", 0);
    vpiHandle rhs = relation(vpiRhs, assign);
    check(rhs && rhs == relation(vpiExpr, relation(vpiLhs, assign)) && integer_is(rhs, 13),
          "omitted base parameter uses its declared default expression");
    iter = iterate(vpiArgument, ext);
    if (check(iter != 0, "default forwarding arguments")) {
        vpiHandle arg = vpi_scan(iter);
        if (check(arg && arg == first, "first forwarded formal handle"))
            check(integer_is(arg, 29), "first forwarded formal value");
        if (arg) {
            arg = vpi_scan(iter);
            if (check(arg && arg == second, "second forwarded formal handle"))
                check(integer_is(arg, 47), "second forwarded formal value");
            if (arg)
                check(!vpi_scan(iter), "exact forwarded argument count");
        }
    }
    return 0;
}

static void register_checks(void)
{
    s_vpi_systf_data task = {0};
    task.type = vpiSysTask;
    task.tfname = "$check_class_inheritance";
    task.calltf = check_inheritance;
    vpi_register_systf(&task);
    task.tfname = "$check_super_call";
    task.calltf = check_chain;
    vpi_register_systf(&task);
    task.tfname = "$check_default_chain";
    task.user_data = (PLI_BYTE8 *)"default";
    vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = {register_checks, 0};
