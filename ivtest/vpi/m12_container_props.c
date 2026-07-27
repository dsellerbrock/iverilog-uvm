/*
 * Runtime-container class properties must expose the same live VPI array
 * surface as top-level dynamic arrays, queues, and associative arrays.
 */
#include <vpi_user.h>
#include <sv_vpi_user.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

static int failed;
static vpiHandle saved_q;
static vpiHandle saved_da;
static vpiHandle saved_aa;

static void fail_i(const char*what, int got, int want)
{
      vpi_printf("FAILED %s: got %d want %d\n", what, got, want);
      failed += 1;
}

static void fail_s(const char*what, const char*got, const char*want)
{
      vpi_printf("FAILED %s: got '%s' want '%s'\n", what,
                 got ? got : "<null>", want);
      failed += 1;
}

static vpiHandle check_container(const char*path, int array_type, int size)
{
      vpiHandle h = vpi_handle_by_name((PLI_BYTE8*)path, 0);
      vpiHandle it, el;
      int count = 0;

      if (!h) {
            vpi_printf("FAILED handle %s is null\n", path);
            failed += 1;
            return 0;
      }
      if (vpi_get(vpiType, h) != vpiArrayVar)
            fail_i(path, vpi_get(vpiType, h), vpiArrayVar);
      if (vpi_get(vpiArrayType, h) != array_type)
            fail_i(path, vpi_get(vpiArrayType, h), array_type);
      if (vpi_get(vpiSize, h) != size)
            fail_i(path, vpi_get(vpiSize, h), size);

      it = vpi_iterate(vpiMember, h);
      while (it && (el = vpi_scan(it)))
            count += 1;
      if (count != size) {
            char label[256];
            snprintf(label, sizeof label, "%s member count", path);
            fail_i(label, count, size);
      }
      return h;
}

static vpiHandle check_int(vpiHandle h, int pos, const char*name, int want)
{
      s_vpi_value val;
      vpiHandle el = h ? vpi_handle_by_index(h, pos) : 0;
      if (!el) {
            vpi_printf("FAILED %s element %d is null\n", name, pos);
            failed += 1;
            return 0;
      }
      if (vpi_get(vpiType, el) != vpiMemoryWord) {
            char label[256];
            snprintf(label, sizeof label, "%s element type", name);
            fail_i(label, vpi_get(vpiType, el), vpiMemoryWord);
      }
      val.format = vpiIntVal;
      vpi_get_value(el, &val);
      if (val.value.integer != want)
            fail_i(name, val.value.integer, want);
      return el;
}

static void check_member_count(vpiHandle h, const char*name, int want)
{
      vpiHandle it = h ? vpi_iterate(vpiMember, h) : 0;
      int count = 0;
      while (it && vpi_scan(it))
            count += 1;
      if (count != want)
            fail_i(name, count, want);
}

static void put_int(vpiHandle h, int pos, int value)
{
      s_vpi_value val;
      vpiHandle el = h ? vpi_handle_by_index(h, pos) : 0;
      if (!el) {
            vpi_printf("FAILED write element %d is null\n", pos);
            failed += 1;
            return;
      }
      val.format = vpiIntVal;
      val.value.integer = value;
      vpi_put_value(el, &val, 0, vpiNoDelay);
}

static void check_and_write_string(void)
{
      s_vpi_value val;
      vpiHandle h = check_container("top.obj.sq", vpiQueueArray, 2);
      vpiHandle el = h ? vpi_handle_by_index(h, 0) : 0;
      if (!el) {
            vpi_printf("FAILED top.obj.sq[0] is null\n");
            failed += 1;
            return;
      }
      val.format = vpiStringVal;
      vpi_get_value(el, &val);
      if (!val.value.str || strcmp(val.value.str, "alpha") != 0)
            fail_s("top.obj.sq[0]", val.value.str, "alpha");
      val.format = vpiStringVal;
      val.value.str = (PLI_BYTE8*)"from-vpi";
      vpi_put_value(el, &val, 0, vpiNoDelay);
}

static void check_and_write_real(void)
{
      s_vpi_value val;
      vpiHandle h = check_container("top.obj.rd", vpiDynamicArray, 2);
      vpiHandle el = h ? vpi_handle_by_index(h, 1) : 0;
      if (!el) {
            vpi_printf("FAILED top.obj.rd[1] is null\n");
            failed += 1;
            return;
      }
      val.format = vpiRealVal;
      vpi_get_value(el, &val);
      if (fabs(val.value.real - 2.5) > 1e-9) {
            vpi_printf("FAILED top.obj.rd[1]: got %f want 2.5\n",
                       val.value.real);
            failed += 1;
      }
      val.format = vpiRealVal;
      val.value.real = 9.5;
      vpi_put_value(el, &val, 0, vpiNoDelay);
}

static PLI_INT32 probe_calltf(PLI_BYTE8*ud)
{
      vpiHandle nested;
      (void)ud;

      saved_q = check_container("top.obj.q", vpiQueueArray, 2);
      saved_da = check_container("top.obj.da", vpiDynamicArray, 2);
      saved_aa = check_container("top.obj.aa", vpiAssocArray, 2);
      check_int(saved_q, 0, "top.obj.q[0]", 10);
      check_int(saved_da, 1, "top.obj.da[1]", 21);
      check_int(saved_aa, 0, "top.obj.aa['a']", 30);

      nested = check_container("top.h.inner.q", vpiQueueArray, 2);
      check_int(nested, 1, "top.h.inner.q[1]", 111);

      check_container("top.empty.q", vpiQueueArray, 0);
      check_container("top.empty.da", vpiDynamicArray, 0);
      check_container("top.empty.aa", vpiAssocArray, 0);
      check_container("top.nil.q", vpiQueueArray, 0);
      check_container("top.nil.da", vpiDynamicArray, 0);
      check_container("top.nil.aa", vpiAssocArray, 0);
      check_container("top.nil.sq", vpiQueueArray, 0);
      check_container("top.nil.rd", vpiDynamicArray, 0);

      put_int(saved_q, 1, 111);
      put_int(saved_da, 0, 120);
      put_int(saved_aa, 0, 130);
      check_and_write_string();
      check_and_write_real();
      return 0;
}

static PLI_INT32 reprobe_calltf(PLI_BYTE8*ud)
{
      (void)ud;
      if (vpi_get(vpiSize, saved_q) != 3)
            fail_i("saved q size after owner replacement",
                   vpi_get(vpiSize, saved_q), 3);
      if (vpi_get(vpiSize, saved_da) != 3)
            fail_i("saved da size after owner replacement",
                   vpi_get(vpiSize, saved_da), 3);
      if (vpi_get(vpiSize, saved_aa) != 3)
            fail_i("saved aa size after owner replacement",
                   vpi_get(vpiSize, saved_aa), 3);
      check_member_count(saved_q, "saved q members after growth", 3);
      check_member_count(saved_da, "saved da members after growth", 3);
      check_member_count(saved_aa, "saved aa members after growth", 3);
      check_int(saved_q, 0, "saved q[0] after owner replacement", 210);
      check_int(saved_da, 1, "saved da[1] after owner replacement", 221);
      check_int(saved_aa, 0, "saved aa['a'] after owner replacement", 230);
      check_int(saved_q, 2, "saved q[2] after growth", 212);
      check_int(saved_da, 2, "saved da[2] after growth", 222);
      check_int(saved_aa, 2, "saved aa['c'] after growth", 232);

      if (failed == 0)
            vpi_printf("PASSED\n");
      else
            vpi_printf("FAILED total=%d\n", failed);
      return 0;
}

static void register_tasks(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$m12_container_props_probe";
      tf.calltf = probe_calltf;
      vpi_register_systf(&tf);

      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$m12_container_props_reprobe";
      tf.calltf = reprobe_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
