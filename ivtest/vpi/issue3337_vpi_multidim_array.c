/*
 * Issue #3337 (IEEE 1800-2023 37.16 detail 25, 37.17 details 5/6/18/26/28,
 * 38.19, 38.20): subarrays, word indexes, names and parents of a
 * multidimensional unpacked array.
 */
#include <string.h>
#include "vpi_user.h"

static int failures;

static void fail(const char *what, const char *got, const char *want)
{
      vpi_printf("FAILED: %s: got %s, want %s\n", what, got, want);
      failures += 1;
}

static int ival(vpiHandle h)
{
      s_vpi_value v;
      v.format = vpiIntVal;
      vpi_get_value(h, &v);
      return v.value.integer;
}

/* "name type size [L:R] idx:i,j,.. parent value" in one string */
static void describe(vpiHandle h, char *buf, size_t len)
{
      char tmp[256];
      vpiHandle x, it, parent;
      int type;
      if (!h) { strcpy(buf, "NULL"); return; }
      type = (int)vpi_get(vpiType, h);
      snprintf(buf, len, "%s %d %d", vpi_get_str(vpiName, h), type,
	       (int)vpi_get(vpiSize, h));
      if ((x = vpi_handle(vpiLeftRange, h)) && type != vpiMemoryWord
	  && type != vpiNet && type != vpiNetBit) {
	    int left = ival(x);
	    snprintf(tmp, sizeof tmp, " [%d:%d]", left,
		     ival(vpi_handle(vpiRightRange, h)));
	    strncat(buf, tmp, len - strlen(buf) - 1);
      }
      strncat(buf, " idx:", len - strlen(buf) - 1);
      it = vpi_iterate(vpiIndex, h);
      while (it && (x = vpi_scan(it))) {
	    snprintf(tmp, sizeof tmp, "%d,", ival(x));
	    strncat(buf, tmp, len - strlen(buf) - 1);
      }
      parent = vpi_handle(vpiParent, h);
      snprintf(tmp, sizeof tmp, " %s", parent ? vpi_get_str(vpiName, parent) : "-");
      strncat(buf, tmp, len - strlen(buf) - 1);
      if (type == vpiMemoryWord || type == vpiNet || type == vpiReg
	  || type == vpiNetBit || type == vpiRegBit) {
	    snprintf(tmp, sizeof tmp, " =%d", ival(h));
	    strncat(buf, tmp, len - strlen(buf) - 1);
      }
}

static void expect(const char *what, vpiHandle h, const char *want)
{
      char got[512];
      describe(h, got, sizeof got);
      if (strcmp(got, want) != 0) fail(what, got, want);
}

static void expect_words(const char *what, vpiHandle h, int code,
			 const char *want)
{
      char got[512] = "", tmp[64];
      vpiHandle it = vpi_iterate(code, h), w;
      while (it && (w = vpi_scan(it))) {
	    snprintf(tmp, sizeof tmp, "%s,", vpi_get_str(vpiName, w));
	    strncat(got, tmp, sizeof got - strlen(got) - 1);
      }
      if (strcmp(got, want) != 0) fail(what, got, want);
}

static PLI_INT32 probe(PLI_BYTE8 *data)
{
      vpiHandle vm = vpi_handle_by_name("top.vm", 0);
      vpiHandle wm = vpi_handle_by_name("top.wm", 0);
      vpiHandle v3 = vpi_handle_by_name("top.v3", 0);
      PLI_INT32 ix[3] = {0, 4, 0};
      PLI_INT32 iy[3] = {1, 0, 5};
      (void)data;

	/* 37.17 detail 6: the leftmost unpacked dimension's bounds. */
      expect("vm", vm, "vm 29 4 [1:0] idx: -");
	/* 38.19: an index of the leftmost dimension is a subarray. */
      expect("vm[1]", vpi_handle_by_index(vm, 1), "vm[1] 29 2 [5:4] idx:1, vm");
      expect("vm[3]", vpi_handle_by_index(vm, 3), "NULL");
      expect("vm[1][5]", vpi_handle_by_index(vpi_handle_by_index(vm, 1), 5),
	     "vm[1][5] 30 2 idx:5,1, vm =2");
      expect("by name vm[1][5]", vpi_handle_by_name("top.vm[1][5]", 0),
	     "vm[1][5] 30 2 idx:5,1, vm =2");
      expect("by name vm[0]", vpi_handle_by_name("top.vm[0]", 0),
	     "vm[0] 29 2 [5:4] idx:0, vm");
      expect("multi {0,4}", vpi_handle_by_multi_index(vm, 2, ix),
	     "vm[0][4] 30 2 idx:4,0, vm =1");
      expect_words("vm words", vm, vpiMemoryWord,
		   "vm[0][4],vm[0][5],vm[1][4],vm[1][5],");
      expect_words("vm[1] words", vpi_handle_by_index(vm, 1), vpiMemoryWord,
		   "vm[1][4],vm[1][5],");

      expect("wm", wm, "wm 114 4 [1:0] idx: -");
      expect("wm[1]", vpi_handle_by_index(wm, 1), "wm[1] 114 2 [5:4] idx:1, wm");
      expect("wm[1][5]", vpi_handle_by_name("top.wm[1][5]", 0),
	     "wm[1][5] 36 2 idx:5,1, wm =3");
	/* 37.16 detail 25: a bit's indexes run from the bit outward. */
      expect("wm[1][5][1]", vpi_handle_by_name("top.wm[1][5][1]", 0),
	     "wm[1][5][1] 37 1 idx:1,5,1, wm[1][5] =1");

	/* Three dimensions; a descending middle dimension. */
      expect("v3[1]", vpi_handle_by_index(v3, 1), "v3[1] 29 6 [2:0] idx:1, v3");
      expect("v3[1][0]", vpi_handle_by_name("top.v3[1][0]", 0),
	     "v3[1][0] 29 2 [4:5] idx:0,1, v3");
      expect("v3 multi {1,0,5}", vpi_handle_by_multi_index(v3, 3, iy),
	     "v3[1][0][5] 30 8 idx:5,0,1, v3 =90");

	/* #3394, 37.17 details 13 and 26: a bit of an array word. */
      expect("va[3][1]", vpi_handle_by_name("top.va[3][1]", 0),
	     "va[3][1] 49 1 idx:1,3, va[3] =1");
      expect("vm[1][5][1]", vpi_handle_by_name("top.vm[1][5][1]", 0),
	     "vm[1][5][1] 49 1 idx:1,5,1, vm[1][5] =1");

      if (failures == 0) vpi_printf("PASSED\n");
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$probe_multidim";
      tf.calltf = probe;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
