#include <vpi_user.h>

static vpiHandle outer, child, member, array, word, shared;
static int failures;
static void check(const char *label, int condition)
{
      if (!condition) { vpi_printf("FAIL: %s\n", label); failures += 1; }
}
static PLI_INT32 inspect(PLI_BYTE8 *unused)
{
      s_vpi_value arg = {0}, value = {0};
      vpiHandle call = vpi_handle(vpiSysTfCall, 0);
      vpiHandle iter = vpi_iterate(vpiArgument, call);
      int step;
      (void)unused;
      arg.format = vpiIntVal;
      vpi_get_value(vpi_scan(iter), &arg);
      step = arg.value.integer;
      if (!step) {
            outer = vpi_handle_by_name("top.n", 0);
            child = vpi_handle_by_name("top.n.child", 0);
            member = vpi_handle_by_name("top.n.child.x", 0);
            array = vpi_handle_by_name("top.n.a", 0);
            word = array ? vpi_handle_by_index(array, 0) : 0;
            shared = vpi_handle_by_name("top.n.shared", 0);
            check("handles", outer && child && member && array && word && shared);
      }
      if (!outer || !child || !member || !array || !word || !shared) return 0;
      check("child prefix", vpi_handle(vpiPrefix, child) == outer);
      check("member prefix", vpi_handle(vpiPrefix, member) == child);
      check("array prefix", vpi_handle(vpiPrefix, array) == outer);
      check("word prefix", vpi_handle(vpiPrefix, word) == outer);
      check("member allocation", vpi_get(vpiAutomatic, member) == vpi_get(vpiAutomatic, child));
      check("word allocation", vpi_get(vpiAutomatic, word) == vpi_get(vpiAutomatic, outer));
      check("static prefix", !vpi_handle(vpiPrefix, shared));
      check("child actual", vpi_get(vpiHasActual, child) == (step != 2));
      check("member actual", vpi_get(vpiHasActual, member) == (step == 0 || step == 3));
      check("array actual", vpi_get(vpiHasActual, array) == (step != 2));
      check("word actual", vpi_get(vpiHasActual, word) == (step != 2));
      check("static actual", vpi_get(vpiHasActual, shared) == 1);
      if (step == 0 || step == 3) {
            value.format = vpiIntVal; vpi_get_value(member, &value);
            check("member value", value.value.integer == 7);
      }
      if (step == 0) {
            value.format = vpiIntVal; vpi_get_value(word, &value);
            check("word value", value.value.integer == 11);
      }
      if (step == 3)
            vpi_printf(failures ? "ISSUE3055 FAIL\n" : "ISSUE3055 PASSED\nPASSED\n");
      return 0;
}
static void start(void)
{
      s_vpi_systf_data task = {0};
      task.type = vpiSysTask; task.tfname = "$check_prefix"; task.calltf = inspect;
      vpi_register_systf(&task);
}
void (*vlog_startup_routines[])(void) = {start, 0};
