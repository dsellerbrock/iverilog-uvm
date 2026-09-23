#include <vpi_user.h>
#include <string.h>

static int failures;
static int hits[3][2];
static int target_ids[3] = {0, 1, 2};
static vpiHandle targets[3];

static void expect(int ok, const char *what)
{
      if (!ok) {
	    vpi_printf("FAIL %s\n", what);
	    failures++;
      }
}

static PLI_INT32 hit(p_cb_data cb)
{
      int target = *(int *)cb->user_data;
      int event = cb->reason == cbForce ? 0 : cb->reason == cbRelease ? 1 : -1;
      expect(target >= 0 && target < 3, "callback target");
      expect(event >= 0, "callback reason");
      if (target >= 0 && target < 3 && event >= 0) {
	    hits[target][event]++;
      }
      return 0;
}

static vpiHandle add_cb(vpiHandle obj, int reason, int target)
{
      s_cb_data cb = {0};
      cb.reason = reason;
      cb.cb_rtn = hit;
      cb.obj = obj;
      cb.user_data = (PLI_BYTE8 *)&target_ids[target];
      return vpi_register_cb(&cb);
}

static PLI_INT32 setup(PLI_BYTE8 *unused)
{
      vpiHandle args;
      vpiHandle bit;
      vpiHandle net_bit;
      vpiHandle bit_force;
      vpiHandle bit_release;
      (void)unused;

      args = vpi_iterate(vpiArgument, vpi_handle(vpiSysTfCall, 0));
      targets[0] = vpi_scan(args);
      targets[1] = vpi_scan(args);
      vpi_free_object(args);
      bit = vpi_handle_by_name("m12_force_cb_regbit.data[3]", 0);
      net_bit = vpi_handle_by_name("m12_force_cb_regbit.net_data[3]", 0);
      targets[2] = net_bit;
      expect(targets[0] && targets[1] && targets[2] && bit, "test handles");
      if (!targets[0] || !targets[1] || !targets[2] || !bit) return 0;
      expect(vpi_get(vpiType, targets[0]) == vpiReg, "whole variable handle");
      expect(vpi_get(vpiType, bit) == vpiRegBit, "legacy variable bit handle");
      expect(vpi_get(vpiType, targets[1]) == vpiPartSelect,
	     "part-select boundary handle");
      expect(vpi_get(vpiType, targets[2]) == vpiNetBit, "net-bit handle");

      bit_force = add_cb(bit, cbForce, 0);
      bit_release = add_cb(bit, cbRelease, 0);
      expect(!bit_force && !bit_release, "legacy variable bit callbacks rejected");

      expect(add_cb(targets[0], cbForce, 0) &&
	     add_cb(targets[0], cbRelease, 0), "whole variable callbacks");
      expect(add_cb(targets[1], cbForce, 1) &&
	     add_cb(targets[1], cbRelease, 1), "part-select callbacks");
      expect(add_cb(targets[2], cbForce, 2) &&
	     add_cb(targets[2], cbRelease, 2), "net-bit callbacks");
      vpi_printf("REGISTER bit=%d whole=%d part=%d netbit=%d\n",
		 bit_force == 0 && bit_release == 0,
		 targets[0] != 0, targets[1] != 0, targets[2] != 0);
      return 0;
}

static PLI_INT32 check(PLI_BYTE8 *unused)
{
      (void)unused;
      expect(hits[0][0] == 1 && hits[0][1] == 1, "whole variable events");
      expect(hits[1][0] == 1 && hits[1][1] == 1, "part-select events");
      expect(hits[2][0] == 1 && hits[2][1] == 1, "net-bit events");
      vpi_printf("RESULT failures=%d whole=%d/%d part=%d/%d netbit=%d/%d\n",
		 failures, hits[0][0], hits[0][1], hits[1][0], hits[1][1],
		 hits[2][0], hits[2][1]);
      if (failures) vpi_sim_control(vpiFinish, 1);
      return 0;
}

static void register_tasks(void)
{
      s_vpi_systf_data tf = {0};
      tf.type = vpiSysTask;
      tf.tfname = "$m12_force_cb_setup";
      tf.calltf = setup;
      vpi_register_systf(&tf);
      tf.tfname = "$m12_force_cb_check";
      tf.calltf = check;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {register_tasks, 0};
