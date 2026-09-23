#include <vpi_user.h>
#include <stdint.h>
#include <string.h>

/* IEEE 1800-2017/2023 Annex K: vpiForce=16, vpiRelease=50. These
 * object-type names are missing from the current public header. */
#define EXPECT_VPI_FORCE 16
#define EXPECT_VPI_RELEASE 50

static int failures;
static unsigned event_count;
static vpiHandle var_force_first;
static vpiHandle var_force_second;
static vpiHandle concat_force;
static vpiHandle concat_release;
static int concat_force_target;
static int concat_release_target;
static vpiHandle data_handle;
static vpiHandle vpi_force_statement;

static void expect(int ok, const char *what)
{
      if (!ok) {
            vpi_printf("FAIL %s\n", what);
            failures++;
      }
}

static PLI_INT32 hit(p_cb_data cb)
{
      int target = (int)(intptr_t)cb->user_data;
      int want_type = cb->reason == cbForce ? EXPECT_VPI_FORCE
                   : cb->reason == cbRelease ? EXPECT_VPI_RELEASE : -1;
      int got_type = cb->obj ? vpi_get(vpiType, cb->obj) : -1;
      expect(want_type >= 0, "callback reason");
      expect(got_type == want_type, "callback obj is force/release statement");
      if (cb->obj && event_count < 9) {
            expect(vpi_get(vpiLineNo, cb->obj) > 0,
                   "statement object has source line");
            expect(vpi_get_str(vpiFile, cb->obj) != 0,
                   "statement object has source file");
      }

      if (event_count == 0) {
            expect(target == 0 && cb->reason == cbForce, "first variable force");
            var_force_first = cb->obj;
      } else if (event_count == 1) {
            expect(target == 0 && cb->reason == cbForce, "second variable force");
            var_force_second = cb->obj;
            expect(var_force_first != var_force_second,
                   "separate force statements have distinct handles");
      } else if (event_count == 2) {
            expect(target == 0 && cb->reason == cbRelease, "variable release");
      } else if (event_count == 3) {
            expect(target == 1 && cb->reason == cbForce, "whole-net force");
      } else if (event_count == 4) {
            expect(target == 1 && cb->reason == cbRelease, "whole-net release");
      } else if (event_count == 5) {
            expect(cb->reason == cbForce, "concat force reason");
            concat_force = cb->obj;
      } else if (event_count == 6) {
            expect(cb->reason == cbForce && target != concat_force_target,
                   "concat force reaches both targets");
            expect(concat_force == cb->obj,
                   "one concat force statement has one handle");
      } else if (event_count == 7) {
            expect(cb->reason == cbRelease, "concat release reason");
            concat_release = cb->obj;
      } else if (event_count == 8) {
            expect(cb->reason == cbRelease && target != concat_release_target,
                   "concat release reaches both targets");
            expect(concat_release == cb->obj,
                   "one concat release statement has one handle");
      } else if (event_count == 9) {
            expect(target == 0 && cb->reason == cbForce,
                   "VPI-originated force callback");
            expect(vpi_get(vpiLineNo, cb->obj) == 0
                   && vpi_get_str(vpiFile, cb->obj) == 0,
                   "VPI-originated force has no source location");
            vpi_force_statement = cb->obj;
      } else if (event_count == 10) {
            expect(target == 0 && cb->reason == cbRelease,
                   "VPI-originated release callback");
            expect(vpi_get(vpiLineNo, cb->obj) == 0
                   && vpi_get_str(vpiFile, cb->obj) == 0,
                   "VPI-originated release has no source location");
            expect(vpi_force_statement != cb->obj,
                   "VPI force and release operations have distinct handles");
      } else {
            expect(0, "unexpected extra callback");
      }
      if (event_count == 5) concat_force_target = target;
      if (event_count == 7) concat_release_target = target;
      event_count++;
      return 0;
}

static void register_one(vpiHandle obj, int reason, int target)
{
      s_cb_data cb;
      memset(&cb, 0, sizeof(cb));
      cb.reason = reason;
      cb.cb_rtn = hit;
      cb.obj = obj;
      cb.user_data = (PLI_BYTE8 *)(intptr_t)target;
      expect(vpi_register_cb(&cb) != 0, "register force/release callback");
}

static PLI_INT32 setup(PLI_BYTE8 *unused)
{
      vpiHandle args;
      vpiHandle var;
      vpiHandle net;
      vpiHandle bit;
      (void)unused;

      args = vpi_iterate(vpiArgument, vpi_handle(vpiSysTfCall, 0));
      var = vpi_scan(args);
      net = vpi_scan(args);
      vpi_free_object(args);
      expect(var && net, "whole variable and net handles");
      if (!var || !net) return 0;
      data_handle = var;
      expect(vpi_get(vpiType, var) == vpiReg, "whole variable handle type");
      expect(vpi_get(vpiType, net) == vpiNet, "whole net handle type");
      register_one(var, cbForce, 0);
      register_one(var, cbRelease, 0);
      register_one(net, cbForce, 1);
      register_one(net, cbRelease, 1);
      bit = vpi_handle_by_index(var, 3);
      expect(bit && vpi_get(vpiType, bit) == vpiRegBit,
             "variable bit-select handle");
      if (bit) {
            s_cb_data cb;
            memset(&cb, 0, sizeof(cb));
            cb.reason = cbForce;
            cb.cb_rtn = hit;
            cb.obj = bit;
            expect(vpi_register_cb(&cb) == 0,
                   "variable bit-select force callback is rejected");
      }
      return 0;
}

static PLI_INT32 check(PLI_BYTE8 *unused)
{
      s_vpi_value value;
      (void)unused;
      expect(event_count == 9, "exactly nine source-statement callbacks");
      expect(var_force_first && var_force_second &&
             var_force_first != var_force_second,
             "same-target force statements remain distinct");
      memset(&value, 0, sizeof(value));
      value.format = vpiIntVal;
      value.value.integer = 7;
      vpi_put_value(data_handle, &value, 0, vpiForceFlag);
      vpi_put_value(data_handle, &value, 0, vpiReleaseFlag);
      expect(event_count == 11, "VPI force and release callbacks fired");
      vpi_printf("RESULT failures=%d events=%u\n", failures, event_count);
      if (failures) vpi_sim_control(vpiFinish, 1);
      return 0;
}

static void register_tasks(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof(tf));
      tf.type = vpiSysTask;
      tf.tfname = "$m12_force_cb_stmt_setup";
      tf.calltf = setup;
      vpi_register_systf(&tf);
      tf.tfname = "$m12_force_cb_stmt_check";
      tf.calltf = check;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
