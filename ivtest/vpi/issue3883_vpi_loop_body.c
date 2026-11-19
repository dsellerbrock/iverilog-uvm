#include <vpi_user.h>
#include <sv_vpi_user.h>

static int failed;

static void check(int ok, const char *what)
{
      if (!ok) {
            vpi_printf("FAIL: %s\n", what);
            failed = 1;
      }
}

static vpiHandle statements(vpiHandle parent)
{
      return parent ? vpi_iterate(vpiStmt, parent) : 0;
}

static vpiHandle next(vpiHandle *iter, int type, const char *what)
{
      vpiHandle stmt = *iter ? vpi_scan(*iter) : 0;
      if (!stmt) *iter = 0;
      check(stmt && vpi_get(vpiType, stmt) == type, what);
      return stmt;
}

static void check_end(vpiHandle iter, const char *what)
{
      if (iter && vpi_scan(iter)) {
            check(0, what);
            vpi_free_object(iter);
      }
}

static vpiHandle body(vpiHandle loop, int type, const char *what)
{
      vpiHandle iter = statements(loop);
      vpiHandle child = next(&iter, type, what);
      vpiHandle direct = loop ? vpi_handle(vpiStmt, loop) : 0;
      vpiHandle parent = child ? vpi_handle(vpiParent, child) : 0;
      check(direct && child && vpi_compare_objects(direct, child), what);
      check(parent && vpi_compare_objects(parent, loop), "loop body parent");
      check_end(iter, "loop has extra children");
      return child;
}

static vpiHandle task_stmt(const char *name)
{
      vpiHandle task = vpi_handle_by_name(name, 0);
      return task ? vpi_handle(vpiStmt, task) : 0;
}

static PLI_INT32 probe(PLI_BYTE8 *user_data)
{
      vpiHandle root, iter, nested, loop, stmt;
      (void)user_data;

      root = task_stmt("top.exercise");
      check(root && vpi_get(vpiType, root) == vpiBegin, "task statement");
      iter = statements(root);
      next(&iter, vpiAssignment, "zero counter initialized");
      next(&iter, vpiAssignment, "continue counter initialized");
      next(&iter, vpiAssignment, "break counter initialized");
      next(&iter, vpiAssignment, "singleton counter initialized");
      loop = next(&iter, vpiRepeat, "repeat (2)");
      check_end(iter, "task has extra statements");

      iter = statements(body(loop, vpiBegin, "repeat (2) body"));
      loop = next(&iter, vpiForever, "nested forever");
      nested = statements(body(loop, vpiBegin, "forever body"));
      loop = next(&nested, vpiDoWhile, "nested do-while");
      loop = body(loop, vpiWhile, "do-while's while body");
      body(loop, vpiNullStmt, "while's explicit semicolon");
      next(&nested, vpiBreak, "forever break");
      check_end(nested, "forever body has extra statements");

      loop = next(&iter, vpiRepeat, "repeat (0)");
      body(loop, vpiAssignment, "repeat (0) body");
      loop = next(&iter, vpiRepeat, "repeat (1) with continue");
      body(loop, vpiBegin, "repeat (1) continue body");
      loop = next(&iter, vpiRepeat, "repeat (1) with break");
      body(loop, vpiBegin, "repeat (1) break body");

      loop = next(&iter, vpiWhile, "while with empty begin/end");
      stmt = body(loop, vpiBegin, "empty begin/end body");
      check(!statements(stmt), "empty begin/end has no statements");
      loop = next(&iter, vpiDoWhile, "do-while with singleton block");
      nested = statements(body(loop, vpiBegin, "singleton begin/end body"));
      next(&nested, vpiAssignment, "singleton block assignment");
      check_end(nested, "singleton begin/end has extra statements");

      loop = next(&iter, vpiWhile, "while with named begin/end");
      stmt = body(loop, vpiNamedBegin, "empty named begin/end body");
      check(!statements(stmt), "empty named begin/end has no statements");
      check_end(iter, "repeat (2) body has extra statements");

      loop = task_stmt("top.wait_ready");
      check(loop && vpi_get(vpiType, loop) == vpiWhile,
            "generated wait retry loop");
      nested = statements(loop);
      next(&nested, vpiEventControl, "retry loop child");
      check(loop && !vpi_handle(vpiStmt, loop), "retry loop has no body edge");
      check_end(nested, "retry loop has extra statements");

      if (!failed) vpi_printf("Loop body handles passed\n");
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data data = {
            vpiSysTask, 0, "$probe_loop_bodies", probe, 0, 0, 0
      };
      vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
