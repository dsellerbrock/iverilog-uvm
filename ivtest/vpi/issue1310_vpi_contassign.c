/*
 * Issue #1310: vpi_iterate(vpiContAssign, module) returns the module's
 * continuous assignments (IEEE 1800-2023 37.47) with their l-value,
 * r-value, net declaration flag, strengths and value, and a value-change
 * callback on an assignment reports its driven value.
 */
#include <stdio.h>
#include <string.h>
#include "vpi_user.h"

#define IEEE_vpiNetDeclAssign 43
#define IEEE_vpiOperation 39
#define IEEE_vpiAddOp 24

static vpiHandle assign_out, assign_sum;
static char log_buf[512];
static unsigned failures;

static void expect(int ok, const char*what)
{
      if (!ok) {
	    vpi_printf("FAILED: %s\n", what);
	    failures += 1;
      }
}

/* vpi_get_str returns a shared buffer: keep one copy per call site. */
static const char*full_name(vpiHandle h)
{
      static char names[8][64];
      static unsigned next;
      const char*name = h ? vpi_get_str(vpiFullName, h) : 0;
      char*buf = names[next++ % 8];
      snprintf(buf, sizeof names[0], "%s", name ? name : "<null>");
      return buf;
}

static PLI_INT32 changed(p_cb_data cb)
{
      char line[64];
      snprintf(line, sizeof line, "%s t=%u %s\n",
	       (vpiHandle)cb->user_data == assign_out ? "out" : "sum",
	       (unsigned)cb->time->low, cb->value->value.str);
      strncat(log_buf, line, sizeof log_buf - strlen(log_buf) - 1);
      return 0;
}

static void watch(vpiHandle ca)
{
      static s_vpi_time time = { vpiSimTime, 0, 0, 0 };
      static s_vpi_value value = { vpiBinStrVal, { 0 } };
      s_cb_data cb;
      memset(&cb, 0, sizeof cb);
      cb.reason = cbValueChange;
      cb.cb_rtn = changed;
      cb.obj = ca;
      cb.time = &time;
      cb.value = &value;
      cb.user_data = (PLI_BYTE8*)ca;
      expect(vpi_register_cb(&cb) != 0, "value-change callback placed");
}

static PLI_INT32 probe_calltf(PLI_BYTE8*ud)
{
      vpiHandle top = vpi_handle(vpiScope, vpi_handle(vpiSysTfCall, 0));
      vpiHandle it = vpi_iterate(vpiContAssign, top), ca;
      unsigned count = 0;
      (void)ud;
      while (it && (ca = vpi_scan(it))) {
	    count += 1;
	    if (vpi_get(IEEE_vpiNetDeclAssign, ca)) assign_sum = ca;
	    else assign_out = ca;
      }
      vpi_printf("CONT_ASSIGN_COUNT=%u\n", count);
      expect(count == 2 && assign_out && assign_sum, "two assignments");
      if (!assign_out || !assign_sum) return 0;

      vpi_printf("out: lhs=%s rhs=%s str0=%d str1=%d parent=%s\n",
		 full_name(vpi_handle(vpiLhs, assign_out)),
		 full_name(vpi_handle(vpiRhs, assign_out)),
		 vpi_get(vpiStrength0, assign_out),
		 vpi_get(vpiStrength1, assign_out),
		 full_name(vpi_handle(vpiParent, assign_out)));
      expect(!strcmp(full_name(vpi_handle(vpiLhs, assign_out)), "top.out"), "out lhs");
      expect(!strcmp(full_name(vpi_handle(vpiRhs, assign_out)), "top.src"), "out rhs");
      expect(vpi_get(vpiStrength0, assign_out) == vpiWeakDrive
	     && vpi_get(vpiStrength1, assign_out) == vpiWeakDrive, "out strengths");
      expect(!strcmp(full_name(vpi_handle(vpiParent, assign_out)), "top"), "out parent");
      expect(vpi_get(vpiLineNo, assign_out) == 9, "out line");
      {
	    const char*file = vpi_get_str(vpiFile, assign_out);
	    const char*tail = "issue1310_vpi_contassign.v";
	    expect(file && strlen(file) >= strlen(tail)
		   && !strcmp(file + strlen(file) - strlen(tail), tail), "out file");
      }

      vpiHandle rhs = vpi_handle(vpiRhs, assign_sum);
      vpi_printf("sum: lhs=%s rhs type=%d op=%d str0=%d decl=%d\n",
		 full_name(vpi_handle(vpiLhs, assign_sum)),
		 rhs ? vpi_get(vpiType, rhs) : -1,
		 rhs ? vpi_get(vpiOpType, rhs) : -1,
		 vpi_get(vpiStrength0, assign_sum),
		 vpi_get(IEEE_vpiNetDeclAssign, assign_sum));
      expect(!strcmp(full_name(vpi_handle(vpiLhs, assign_sum)), "top.sum"), "sum lhs");
      expect(rhs && vpi_get(vpiType, rhs) == IEEE_vpiOperation
	     && vpi_get(vpiOpType, rhs) == IEEE_vpiAddOp, "sum rhs a + b");
      expect(vpi_get(vpiStrength0, assign_sum) == vpiStrongDrive, "sum strength");
      expect(vpi_get(IEEE_vpiNetDeclAssign, assign_out) == 0, "out not a declaration");

      watch(assign_out);
      watch(assign_sum);
      return 0;
}

static const char*value_of(vpiHandle ca)
{
      static s_vpi_value value;
      value.format = vpiBinStrVal;
      vpi_get_value(ca, &value);
      return value.value.str;
}

static PLI_INT32 done_calltf(PLI_BYTE8*ud)
{
      static const char want[] =
	    "out t=0 0\nsum t=0 0011\nout t=1 1\nsum t=2 0101\n";
      (void)ud;
      vpi_printf("%s", log_buf);
      expect(!strcmp(log_buf, want), "callback log");
      if (assign_out && assign_sum) {
	    vpi_printf("VALUES out=%s", value_of(assign_out));
	    vpi_printf(" sum=%s\n", value_of(assign_sum));
	    expect(!strcmp(value_of(assign_out), "1"), "out value");
	    expect(!strcmp(value_of(assign_sum), "0101"), "sum value");
      }
      if (failures == 0) vpi_printf("VPI CONTASSIGN PASS\nPASSED\n");
      return 0;
}

static void reg(void)
{
      s_vpi_systf_data d;
      memset(&d, 0, sizeof d);
      d.type = vpiSysTask;
      d.tfname = (PLI_BYTE8*)"$caprobe";
      d.calltf = probe_calltf;
      vpi_register_systf(&d);
      d.tfname = (PLI_BYTE8*)"$cadone";
      d.calltf = done_calltf;
      vpi_register_systf(&d);
}

void (*vlog_startup_routines[])(void) = { reg, 0 };
