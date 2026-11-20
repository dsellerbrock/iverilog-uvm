#include <string.h>
#include <vpi_user.h>

struct observed_statement {
      vpiHandle handle;
      unsigned time;
      unsigned expected_hits;
      unsigned hits;
};

static struct observed_statement observed[] = {
      {0, 0, 1, 0}, {0, 15, 1, 0}, {0, 45, 1, 0},
      {0, 85, 1, 0}, {0, 0, 0, 0}
};
static s_vpi_time callback_time = {vpiSimTime, 0, 0, 0.0};
static int failed;

static void fail(const char *where, const char *message)
{
      vpi_printf("FAIL issue3901 %s: %s\n", where, message);
      failed = 1;
}

static int type_of(vpiHandle stmt)
{
      return stmt ? vpi_get(vpiType, stmt) : 0;
}

static int string_is(vpiHandle stmt, int property, const char *expected)
{
      const char *actual = vpi_get_str(property, stmt);
      return expected ? actual && strcmp(actual, expected) == 0 : !actual;
}

static vpiHandle check_expect(const char *task_name, int sibling_type,
                              int pass_type, int fail_type)
{
      vpiHandle task = vpi_handle_by_name(task_name, 0);
      vpiHandle root = task ? vpi_handle(vpiStmt, task) : 0;
      vpiHandle stmt = root, it, pass, otherwise;

      if (sibling_type) {
            if (type_of(root) != vpiBegin) {
                  fail(task_name, "expected task body block");
                  return 0;
            }
            it = vpi_iterate(vpiStmt, root);
            stmt = it ? vpi_scan(it) : 0;
            if (stmt) {
                  vpiHandle next = vpi_scan(it);
                  if (type_of(next) != sibling_type)
                        fail(task_name, "wrong continuation sibling");
                  if (next && vpi_scan(it)) {
                        fail(task_name, "extra task body sibling");
                        vpi_free_object(it);
                  }
            }
      }

      if (type_of(stmt) != vpiExpectStmt) {
            vpi_printf("FAIL issue3901 %s: expected vpiExpectStmt (%d), got %d\n",
                       task_name, vpiExpectStmt, type_of(stmt));
            failed = 1;
            return 0;
      }
      if (!string_is(stmt, vpiType, "vpiExpectStmt"))
            fail(task_name, "wrong vpiType string");

      pass = vpi_handle(vpiStmt, stmt);
      otherwise = vpi_handle(vpiElseStmt, stmt);
      if (type_of(pass) != pass_type || type_of(otherwise) != fail_type) {
            fail(task_name, "wrong pass or else statement type");
            return 0;
      }

      it = vpi_iterate(vpiStmt, stmt);
      vpiHandle actions[] = {pass, otherwise};
      for (unsigned i = 0; i < 2; ++i) {
            if (!actions[i]) continue;
            vpiHandle child = it ? vpi_scan(it) : 0;
            if (!child || child != actions[i] || vpi_handle(vpiParent, child) != stmt) {
                  fail(task_name, "wrong action identity, order or parent");
                  if (child) vpi_free_object(it);
                  return 0;
            }
      }
      if (it && vpi_scan(it)) {
            fail(task_name, "extra statement under expect");
            vpi_free_object(it);
            return 0;
      }
      return stmt;
}

static vpiHandle check_block(vpiHandle block, const char *where, int child_type)
{
      vpiHandle it = vpi_iterate(vpiStmt, block);
      vpiHandle child = it ? vpi_scan(it) : 0;
      if (type_of(child) != child_type)
            fail(where, "wrong source block contents");
      if (child && vpi_scan(it)) {
            fail(where, "extra source block child");
            vpi_free_object(it);
      }
      return child;
}

static PLI_INT32 on_statement(p_cb_data cb)
{
      struct observed_statement *stmt = (struct observed_statement *)cb->user_data;
      if (cb->obj != stmt->handle || !cb->time || cb->time->high
          || cb->time->low != stmt->time)
            fail("cbStmt", "wrong statement identity or execution time");
      ++stmt->hits;
      return 0;
}

static PLI_INT32 inspect(p_cb_data cb)
{
      vpiHandle stmt;
      (void)cb;

      stmt = check_expect("top.original", vpiSysTaskCall, vpiSysTaskCall, 0);
      if (stmt && !string_is(stmt, vpiName, 0))
            fail("top.original", "unlabeled expect has a name");
      stmt = check_expect("top.expect_only", 0, vpiBegin, 0);
      if (stmt) {
            observed[3].handle = vpi_handle(vpiStmt, stmt);
            check_block(observed[3].handle, "empty pass block", 0);
      }

      stmt = check_expect("top.fixed_run", vpiAssignment, vpiBegin, vpiSysTaskCall);
      if (stmt) {
            if (!string_is(stmt, vpiName, "check_fixed")
                || !string_is(stmt, vpiFile, "issue3901_labeled_source.sv")
                || vpi_get(vpiLineNo, stmt) != 121)
                  fail("top.fixed_run", "wrong expect label or source location");
            if (type_of(vpi_handle_by_name("top.fixed_run.check_fixed", 0)) != vpiNamedBegin)
                  fail("top.fixed_run", "missing lexical scope for label");
            observed[0].handle = stmt;
            observed[1].handle = check_block(vpi_handle(vpiStmt, stmt), "singleton pass block",
                                             vpiAssignment);
      }

      stmt = check_expect("top.ranged_run", vpiAssignment, vpiSysTaskCall, vpiNamedBegin);
      if (stmt) {
            vpiHandle otherwise = vpi_handle(vpiElseStmt, stmt);
            if (type_of(vpi_handle_by_name("top.ranged_run.ranged_else", 0)) != vpiNamedBegin)
                  fail("top.ranged_run", "missing lexical scope for framed action");
            observed[2].handle = check_block(otherwise, "framed else block", vpiAssignment);
      }
      check_expect("top.fail_only", vpiAssignment, 0, vpiAssignment);
      check_expect("top.null_pass", vpiAssignment, vpiNullStmt, 0);
      stmt = check_expect("top.null_else", 0, vpiBegin, vpiNullStmt);
      if (stmt) observed[4].handle = vpi_handle(vpiStmt, stmt);

      if (failed) return 0;
      for (unsigned i = 0; i < sizeof observed / sizeof observed[0]; ++i) {
            s_cb_data data = {0};
            data.reason = cbStmt;
            data.obj = observed[i].handle;
            data.time = &callback_time;
            data.cb_rtn = on_statement;
            data.user_data = (PLI_BYTE8 *)&observed[i];
            if (!vpi_register_cb(&data)) fail("cbStmt", "registration failed");
      }
      return 0;
}

static PLI_INT32 finish(p_cb_data cb)
{
      (void)cb;
      if (!failed) {
            for (unsigned i = 0; i < sizeof observed / sizeof observed[0]; ++i)
                  if (observed[i].hits != observed[i].expected_hits)
                        fail("cbStmt", "wrong execution count");
      }
      if (!failed) vpi_printf("issue3901 VPI PASSED\n");
      return 0;
}

static void register_probe(void)
{
      static int registered;
      s_cb_data cb = {0};
      if (registered) return;
      registered = 1;
      cb.reason = cbStartOfSimulation;
      cb.cb_rtn = inspect;
      vpi_register_cb(&cb);
      cb.reason = cbEndOfSimulation;
      cb.cb_rtn = finish;
      vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = {register_probe, 0};
