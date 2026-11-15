#include <vpi_user.h>

static int returns, disables, assigns;

static void walk(vpiHandle stmt)
{
    vpiHandle it, child;
    PLI_INT32 type;
    if (!stmt) return;
    type = vpi_get(vpiType, stmt);
    if (type == vpiReturnStmt) returns++;
    if (type == vpiDisable) disables++;
    if (type == vpiAssignment) assigns++;
    it = vpi_iterate(vpiStmt, stmt);
    while (it && (child = vpi_scan(it)) != 0) walk(child);
}

static int failures;

/* The body of NAME holds exactly WANT_RET return statements and WANT_DIS
   disables; a return is never also seen as an assignment. */
static void check(const char *name, int want_ret, int want_dis)
{
    vpiHandle scope = vpi_handle_by_name((PLI_BYTE8 *)name, 0);
    returns = disables = assigns = 0;
    walk(scope ? vpi_handle(vpiStmt, scope) : 0);
    if (!scope || returns != want_ret || disables != want_dis || assigns) {
        vpi_printf("FAIL %s: %d returns (want %d), %d disables (want %d), "
                   "%d assignments (want 0)\n", name, returns, want_ret,
                   disables, want_dis, assigns);
        failures++;
    }
}

static PLI_INT32 probe_calltf(PLI_BYTE8 *user_data)
{
    (void)user_data;
    check("top.twice", 2, 0);
    check("top.note", 1, 0);
    check("top.waiter", 1, 0);
    check("top.stopper", 0, 1);
    vpi_printf(failures ? "FAILED\n" : "PASSED\n");
    return 0;
}

static void register_probe(void)
{
    s_vpi_systf_data data = {0};
    data.type = vpiSysTask;
    data.tfname = "$probe_return_stmt";
    data.calltf = probe_calltf;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
