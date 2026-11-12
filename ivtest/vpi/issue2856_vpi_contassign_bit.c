#include <stdio.h>
#include <string.h>
#include "vpi_user.h"

#define IEEE_vpiContAssignBit 128
#define IEEE_vpiOffset 60

static unsigned failures;
static unsigned changes;

static void expect(int ok, const char*what)
{
      if (!ok) {
            vpi_printf("FAILED: %s\n", what);
            failures += 1;
      }
}

static PLI_INT32 changed(p_cb_data cb)
{
      int offset = vpi_get(IEEE_vpiOffset, cb->obj);
      vpi_printf("CHANGE t=%u offset=%d value=%s\n",
                 (unsigned)cb->time->low, offset, cb->value->value.str);
      expect(offset == 1, "only bit 1 changes");
      expect(cb->time->low == 2, "bit callback time");
      expect(!strcmp(cb->value->value.str, "1"), "changed bit value");
      changes += 1;
      return 0;
}

static PLI_INT32 probe(PLI_BYTE8*ud)
{
      vpiHandle top = vpi_handle_by_name((PLI_BYTE8*)"top", 0);
      vpiHandle assigns = vpi_iterate(vpiContAssign, top);
      vpiHandle ca = assigns ? vpi_scan(assigns) : 0;
      vpiHandle bits = ca ? vpi_iterate(vpiBit, ca) : 0;
      vpiHandle bit;
      static s_vpi_time time = { vpiSimTime, 0, 0, 0 };
      static s_vpi_value value = { vpiBinStrVal, { 0 } };
      unsigned count = 0;
      (void)ud;
      if (assigns) vpi_free_object(assigns);
      while (bits && (bit = vpi_scan(bits))) {
            s_vpi_value v;
            s_cb_data cb;
            v.format = vpiBinStrVal;
            vpi_get_value(bit, &v);
            vpi_printf("BIT type=%d offset=%d size=%d value=%s\n",
                       (int)vpi_get(vpiType, bit),
                       (int)vpi_get(IEEE_vpiOffset, bit),
                       (int)vpi_get(vpiSize, bit), v.value.str);
            expect(vpi_get(vpiType, bit) == IEEE_vpiContAssignBit,
                   "cont assign bit type");
            expect(vpi_get(vpiSize, bit) == 1, "scalar bit size");
            expect(vpi_handle(vpiParent, bit) == ca, "bit parent");
            memset(&cb, 0, sizeof cb);
            cb.reason = cbValueChange;
            cb.cb_rtn = changed;
            cb.obj = bit;
            cb.time = &time;
            cb.value = &value;
            expect(vpi_register_cb(&cb) != 0, "bit callback registered");
            count += 1;
      }
      vpi_printf("BITS=%u\n", count);
      expect(count == 4, "four assignment bits");
      return 0;
}

static PLI_INT32 done(PLI_BYTE8*ud)
{
      (void)ud;
      expect(changes == 1, "only one bit callback");
      if (!failures) vpi_printf("VPI CONTASSIGN BIT PASS\nPASSED\n");
      return 0;
}

static void reg(void)
{
      s_vpi_systf_data d;
      memset(&d, 0, sizeof d);
      d.type = vpiSysTask;
      d.tfname = (PLI_BYTE8*)"$probe";
      d.calltf = probe;
      vpi_register_systf(&d);
      d.tfname = (PLI_BYTE8*)"$done";
      d.calltf = done;
      vpi_register_systf(&d);
}

void (*vlog_startup_routines[])(void) = { reg, 0 };
