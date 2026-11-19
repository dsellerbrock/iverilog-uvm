#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

/* Allow the regression to build with the pre-fix headers. */
#ifndef vpiElemTypespec
# define vpiElemTypespec 704
#endif

static int failures;

static void check(int ok, const char *message)
{
    if (!ok) {
        vpi_printf("FAIL: %s\n", message);
        ++failures;
    }
}

static int named(vpiHandle handle, const char *name)
{
    const char *actual = handle ? vpi_get_str(vpiName, handle) : 0;
    return actual && strcmp(actual, name) == 0;
}

static int kind(vpiHandle handle, int type)
{
    return handle && vpi_get(vpiType, handle) == type;
}

static vpiHandle relation(int rel, vpiHandle handle)
{
    return handle ? vpi_handle(rel, handle) : 0;
}

static int integer(vpiHandle handle, int expected)
{
    s_vpi_value value = {0};
    if (!handle) return 0;
    value.format = vpiIntVal;
    vpi_get_value(handle, &value);
    return value.format == vpiIntVal && value.value.integer == expected;
}

static void collect(vpiHandle scope, int rel, const char **names,
                    vpiHandle *items, unsigned count)
{
    vpiHandle it = scope ? vpi_iterate(rel, scope) : 0;
    vpiHandle item;
    while (it && (item = vpi_scan(it))) {
        unsigned idx;
        for (idx = 0; idx < count && !named(item, names[idx]); ++idx) {}
        check(idx < count, "unexpected declaration");
        if (idx < count) {
            check(!items[idx], "duplicate declaration");
            items[idx] = item;
        }
    }
    for (unsigned idx = 0; idx < count; ++idx)
        check(items[idx] != 0, names[idx]);
}

static void check_parameter(vpiHandle param, int type, int local)
{
    check(kind(param, type), "parameter handle kind");
    if (param) check(vpi_get(vpiLocalParam, param) == local, "vpiLocalParam");
}

static void check_add(vpiHandle expr, vpiHandle lhs, int expected)
{
    check(kind(expr, vpiOperation) && vpi_get(vpiOpType, expr) == vpiAddOp,
          "source addition default");
    check(integer(expr, expected), "default expression value");
    vpiHandle it = expr ? vpi_iterate(vpiOperand, expr) : 0;
    vpiHandle first = it ? vpi_scan(it) : 0;
    check(lhs ? first == lhs : kind(first, vpiConstant) && integer(first, 1),
          "first source operand");
    vpiHandle second = first ? vpi_scan(it) : 0;
    check(kind(second, vpiConstant) && integer(second, 2), "second source operand");
    if (second) {
        vpiHandle extra = vpi_scan(it);
        check(!extra, "source addition operand count");
        if (extra) vpi_free_object(it);
    }
}

static vpiHandle class_type(const char *path)
{
    return relation(vpiClassTypespec, vpi_handle_by_name(path, 0));
}

static void check_box(vpiHandle scope, int n, int type_kind, const char *type_name,
                      vpiHandle default_target, vpiHandle *lexical)
{
    const char *names[] = {"N", "B", "T", "BodyType", "NullValue"};
    vpiHandle items[5] = {0};
    collect(scope, vpiParameter, names, items, 5);
    for (unsigned idx = 0; idx < 5; ++idx) {
        check_parameter(items[idx], idx == 2 || idx == 3 ? vpiTypeParameter : vpiParameter,
                        idx != 0 && idx != 2);
        if (n == 3) lexical[idx] = items[idx];
        else check(items[idx] && items[idx] != lexical[idx], "specialization parameter identity");
    }

    check(integer(items[0], n) && integer(items[1], n + 2), "effective value parameters");
    check_add(relation(vpiExpr, items[0]), 0, 3);
    check_add(relation(vpiExpr, items[1]), items[0], n + 2);

    vpiHandle actual = relation(vpiTypespec, items[2]);
    vpiHandle def = relation(vpiExpr, items[2]);
    check(kind(actual, type_kind) && named(actual, type_name), "effective type and alias");
    check(kind(def, vpiClassTypespec) && named(def, "DefaultAlias")
          && relation(vpiClassDefn, def) == default_target, "lexical type default");
    if (n == 3)
        check(relation(vpiClassDefn, actual) == default_target, "definition effective class type");
    if (type_kind == vpiArrayTypespec && actual) {
        check(vpi_get(vpiArrayType, actual) == vpiStaticArray, "unpacked array kind");
        check(kind(relation(vpiElemTypespec, actual), vpiIntTypespec), "unpacked element type");
        vpiHandle it = vpi_iterate(vpiRange, actual);
        vpiHandle range = it ? vpi_scan(it) : 0;
        check(integer(relation(vpiLeftRange, range), 2)
              && integer(relation(vpiRightRange, range), 3), "unpacked array bounds");
        if (range) check(!vpi_scan(it), "unpacked array dimension count");
    }
    check(kind(relation(vpiTypespec, items[3]), vpiIntTypespec)
          && kind(relation(vpiExpr, items[3]), vpiIntTypespec), "body type parameter");

    vpiHandle null_default = relation(vpiExpr, items[4]);
    check(items[4] && vpi_get(vpiConstType, items[4]) == vpiNullConst
          && integer(items[4], 0), "class-valued parameter");
    check(kind(null_default, vpiConstant) && vpi_get(vpiConstType, null_default) == vpiNullConst,
          "class-valued parameter default");
}

static PLI_INT32 probe(p_cb_data cb)
{
    (void)cb;
    vpiHandle first = class_type("top.first");
    vpiHandle second = class_type("top.second");
    vpiHandle def = relation(vpiClassDefn, first);
    check(kind(def, vpiClassDefn) && named(def, "Box")
          && def == relation(vpiClassDefn, second) && first != second,
          "one lexical definition, two specializations");

    vpiHandle default_target = relation(vpiClassDefn, vpi_handle_by_name("top.Target", 0));
    vpiHandle alias_target = relation(vpiClassDefn, vpi_handle_by_name("other::Target", 0));
    check(default_target && alias_target && default_target != alias_target, "distinct Target definitions");
    vpiHandle lexical[5];
    check_box(def, 3, vpiClassTypespec, "DefaultAlias", default_target, lexical);
    check_box(first, 7, vpiStringTypespec, "Text", default_target, lexical);
    check_box(second, 9, vpiArrayTypespec, "Pair", default_target, lexical);

    const char *aliases[] = {"Scalar", "ClassAlias"};
    vpiHandle typedefs[2] = {0};
    collect(def, vpiTypedef, aliases, typedefs, 2);
    check(kind(typedefs[0], vpiIntTypespec), "explicit scalar typedef");
    check(kind(typedefs[1], vpiClassTypespec)
          && relation(vpiClassDefn, typedefs[1]) == alias_target,
          "class typedef targets the lexical definition of other::Target");
    if (typedefs[1])
        check(!vpi_iterate(vpiVariables, typedefs[1]), "class typedef is a lexical typespec");

    vpiHandle supplied = class_type("top.supplied");
    vpiHandle required = relation(vpiClassDefn, supplied);
    const char *required_names[] = {"N", "T"};
    vpiHandle formals[2] = {0}, actuals[2] = {0};
    collect(required, vpiParameter, required_names, formals, 2);
    collect(supplied, vpiParameter, required_names, actuals, 2);
    check_parameter(formals[0], vpiParameter, 0);
    check_parameter(formals[1], vpiTypeParameter, 0);
    check(!relation(vpiExpr, formals[0]) && !relation(vpiExpr, formals[1])
          && !relation(vpiTypespec, formals[1]), "required formals have no defaults");
    if (formals[0]) {
        s_vpi_value value = {0};
        value.format = vpiIntVal;
        vpi_get_value(formals[0], &value);
        check(value.format == vpiSuppressVal, "unbound value formal has no effective value");
    }
    check(integer(actuals[0], 13) && !relation(vpiExpr, actuals[0])
          && kind(relation(vpiTypespec, actuals[1]), vpiShortIntTypespec)
          && !relation(vpiExpr, actuals[1]), "required specialization actuals");

    if (!failures) vpi_printf("PASSED\n");
    return 0;
}

static void startup(void)
{
    s_cb_data cb = {0};
    cb.reason = cbStartOfSimulation;
    cb.cb_rtn = probe;
    vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = {startup, 0};
