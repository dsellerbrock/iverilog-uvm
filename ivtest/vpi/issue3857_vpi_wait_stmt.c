#include <vpi_user.h>

static int failed, setup_done;
static unsigned worker_count;
static vpiHandle worker_scope;
static s_vpi_time sim_time = {vpiSimTime, 0, 0, 0.0};

/* Exact body handles and times for the module callback within worker.
   The event-control callback occurs upon reaching @, and its assignment
   is delayed until the edge. The two waits have distinct entry callbacks. */
static vpiHandle worker_stmts[9];
static const unsigned worker_times[] = {1, 1, 1, 4, 4, 4, 4, 5, 5};

struct watched_stmt {
    const char *name;
    unsigned time;
    unsigned expected;
    unsigned count;
    vpiHandle handle;
};

static struct watched_stmt true_wait = {"single wait", 1, 1, 0, 0};
static struct watched_stmt true_body = {"single wait body", 1, 1, 0, 0};
static struct watched_stmt false_wait = {"permanent wait", 1, 1, 0, 0};
static struct watched_stmt dead_body = {"unreachable block", 0, 0, 0, 0};
static struct watched_stmt dead_nested = {"unreachable nested wait", 0, 0, 0, 0};

static int check(int condition, const char *message)
{
    if (!condition) {
        vpi_printf("FAIL: %s\n", message);
        failed = 1;
    }
    return condition;
}

static vpiHandle expect_type(vpiHandle obj, int type, const char *name)
{
    int actual = obj ? vpi_get(vpiType, obj) : 0;
    if (actual == type)
        return obj;
    vpi_printf("FAIL: %s has VPI type %d, expected %d\n", name, actual, type);
    failed = 1;
    return 0;
}

static vpiHandle task_root(const char *name, int type)
{
    vpiHandle task = vpi_handle_by_name((PLI_BYTE8 *)name, 0);
    return expect_type(task ? vpi_handle(vpiStmt, task) : 0, type, name);
}

static vpiHandle wait_body(vpiHandle wait, int type, const char *name)
{
    vpiHandle body, iter;
    if (!expect_type(wait, vpiWait, name))
        return 0;
    body = expect_type(vpi_handle(vpiStmt, wait), type, name);
    if (body)
        check(vpi_handle(vpiParent, body) == wait, "wait body parent");
    iter = vpi_iterate(vpiStmt, wait);
    if (!check(iter == 0, "wait body must use the one-to-one vpiStmt relation"))
        vpi_free_object(iter);
    return body;
}

static int block_children(vpiHandle block, vpiHandle *children, unsigned count)
{
    vpiHandle iter = vpi_iterate(vpiStmt, block);
    unsigned idx;
    for (idx = 0; idx < count; ++idx) {
        children[idx] = iter ? vpi_scan(iter) : 0;
        if (!check(children[idx] != 0, "missing block child"))
            return 0;
        check(vpi_handle(vpiParent, children[idx]) == block, "block child parent");
    }
    if (iter && !check(vpi_scan(iter) == 0, "extra block child")) {
        vpi_free_object(iter);
        return 0;
    }
    return 1;
}

static PLI_INT32 on_worker_stmt(p_cb_data cb)
{
    unsigned idx;
    if (vpi_handle(vpiScope, cb->obj) != worker_scope)
        return 0;
    idx = worker_count++;
    if (idx >= sizeof worker_times / sizeof worker_times[0] ||
        cb->obj != worker_stmts[idx] ||
        !cb->time || cb->time->high || cb->time->low != worker_times[idx]) {
        vpi_printf("FAIL: unexpected worker callback %u, type %d at %u\n",
                   idx, vpi_get(vpiType, cb->obj), cb->time ? cb->time->low : 0);
        failed = 1;
    }
    return 0;
}

static PLI_INT32 on_watched_stmt(p_cb_data cb)
{
    struct watched_stmt *watch = (struct watched_stmt *)cb->user_data;
    ++watch->count;
    check(cb->obj == watch->handle && cb->time && cb->time->high == 0 &&
          cb->time->low == watch->time, watch->name);
    return 0;
}

static void watch_stmt(struct watched_stmt *watch, vpiHandle obj)
{
    s_cb_data cb = {0};
    watch->handle = obj;
    cb.reason = cbStmt;
    cb.cb_rtn = on_watched_stmt;
    cb.obj = obj;
    cb.time = &sim_time;
    cb.user_data = (PLI_BYTE8 *)watch;
    check(vpi_register_cb(&cb) != 0, watch->name);
}

static PLI_INT32 probe(PLI_BYTE8 *unused)
{
    vpiHandle wait, body, kids[4], nested, named_child;
    s_cb_data cb = {0};
    (void)unused;

    /* This is the first check and fails on the original compiler. */
    wait = task_root("top.single_wait", vpiWait);
    if (!wait || !(body = wait_body(wait, vpiAssignment, "single wait body")))
        return 0;
    watch_stmt(&true_wait, wait);
    watch_stmt(&true_body, body);

    wait = task_root("top.with_initializer", vpiWait);
    if (!wait || !(body = wait_body(wait, vpiNamedBegin, "named automatic body")))
        return 0;
    if (block_children(body, &named_child, 1))
        expect_type(named_child, vpiAssignment, "named body assignment");

    wait = task_root("top.null_body", vpiWait);
    if (wait)
        wait_body(wait, vpiNullStmt, "explicit null body");
    wait = task_root("top.empty_block", vpiWait);
    if (wait && (body = wait_body(wait, vpiBegin, "empty begin/end body")))
        block_children(body, 0, 0);

    wait = task_root("top.suspended", vpiWait);
    if (!wait || !(body = wait_body(wait, vpiNamedBegin, "permanent wait body")) ||
        !block_children(body, kids, 2))
        return 0;
    expect_type(kids[0], vpiEventControl, "unreachable @");
    if (!wait_body(kids[1], vpiAssignment, "unreachable nested wait body"))
        return 0;
    watch_stmt(&false_wait, wait);
    watch_stmt(&dead_body, body);
    watch_stmt(&dead_nested, kids[1]);

    worker_stmts[0] = task_root("top.worker", vpiBegin);
    if (!worker_stmts[0] || !block_children(worker_stmts[0], kids, 4))
        return 0;
    expect_type(kids[0], vpiAssignment, "first sibling");
    body = wait_body(kids[1], vpiBegin, "dynamic wait body");
    if (!body || !block_children(body, &nested, 1))
        return 0;
    worker_stmts[1] = kids[0];
    worker_stmts[2] = kids[1];
    worker_stmts[3] = body;
    worker_stmts[4] = nested;
    worker_stmts[5] = wait_body(nested, vpiAssignment, "inner wait body");
    worker_stmts[6] = expect_type(kids[2], vpiEventControl, "ordinary @ sibling");
    if (!worker_stmts[5] || !worker_stmts[6] ||
        !block_children(kids[2], &worker_stmts[7], 1))
        return 0;
    expect_type(worker_stmts[7], vpiAssignment, "@ body");
    worker_stmts[8] = expect_type(kids[3], vpiAssignment, "last sibling");
    worker_scope = vpi_handle(vpiScope, worker_stmts[0]);
    cb.reason = cbStmt;
    cb.cb_rtn = on_worker_stmt;
    cb.obj = vpi_handle_by_name("top", 0);
    cb.time = &sim_time;
    setup_done = check(cb.obj && vpi_register_cb(&cb), "module callback");
    return 0;
}

static PLI_INT32 finish_probe(PLI_BYTE8 *unused)
{
    struct watched_stmt *watches[] = {&true_wait, &true_body, &false_wait,
                                     &dead_body, &dead_nested};
    unsigned idx;
    (void)unused;
    if (!setup_done)
        return 0;
    check(worker_count == sizeof worker_times / sizeof worker_times[0],
          "worker callback count");
    for (idx = 0; idx < sizeof watches / sizeof watches[0]; ++idx)
        check(watches[idx]->count == watches[idx]->expected, watches[idx]->name);
    if (!failed)
        vpi_printf("PASSED\n");
    return 0;
}

static void register_probes(void)
{
    s_vpi_systf_data tf = {0};
    tf.type = vpiSysTask;
    tf.tfname = "$probe_wait_stmt";
    tf.calltf = probe;
    vpi_register_systf(&tf);
    tf.tfname = "$check_wait_stmt";
    tf.calltf = finish_probe;
    vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {register_probes, 0};
