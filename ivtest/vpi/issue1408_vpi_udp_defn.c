#include <string.h>
#include <vpi_user.h>

static int row_matches(vpiHandle entry, const char *expected)
{
      s_vpi_value value;
      unsigned idx, size = strlen(expected);
      value.format = vpiStringVal;
      vpi_get_value(entry, &value);
      if (!value.value.str || strcmp(value.value.str, expected) != 0)
	    return 0;

      value.format = vpiVectorVal;
      vpi_get_value(entry, &value);
      if (!value.value.vector || vpi_get(vpiSize, entry) != (int)size)
	    return 0;
      for (idx = 0; idx < size; idx += 1) {
	    const s_vpi_vecval *word = &value.value.vector[idx / 4];
	    unsigned slot = idx % 4;
	    unsigned shift = 24 - (slot % 2) * 16;
	    unsigned actual = slot < 2 ? word->aval : word->bval;
	    if (((actual >> shift) & 0xff) != (unsigned char)expected[idx])
		  return 0;
      }
      return 1;
}

static int check_defn(vpiHandle defn, const char *name, int inputs,
		      int prim_type, const char **rows, unsigned nrows)
{
      vpiHandle iter, entry;
      unsigned idx = 0;
      const char *defname = vpi_get_str(vpiDefName, defn);
      if (vpi_get(vpiType, defn) != vpiUdpDefn || !defname ||
	  strcmp(defname, name) != 0 || vpi_get(vpiSize, defn) != inputs ||
	  vpi_get(vpiProtected, defn) != 0 ||
	  vpi_get(vpiPrimType, defn) != prim_type) {
	    vpi_printf("bad UDP properties name=%s type=%d size=%d protected=%d prim=%d\n",
		       defname ? defname : "<null>", vpi_get(vpiType, defn),
		       vpi_get(vpiSize, defn), vpi_get(vpiProtected, defn),
		       vpi_get(vpiPrimType, defn));
	    return 0;
	  }

      iter = vpi_iterate(vpiTableEntry, defn);
      while (iter && (entry = vpi_scan(iter))) {
	    if (idx >= nrows || !row_matches(entry, rows[idx])) {
		  s_vpi_value value;
		  value.format = vpiStringVal;
		  vpi_get_value(entry, &value);
		  vpi_printf("bad UDP row %u actual=%s expected=%s size=%d\n", idx,
			     value.value.str ? value.value.str : "<null>",
			     idx < nrows ? rows[idx] : "<extra>", vpi_get(vpiSize, entry));
		  return 0;
	    }
	    idx += 1;
      }
      return idx == nrows;
}

static PLI_INT32 check_udp_defs(PLI_BYTE8 *user_data)
{
      static const char *comb_rows[] = { "000", "010", "100", "111" };
      static const char *seq_rows[] = { "000", "011", "100", "111" };
      vpiHandle iter, top, defn;
      unsigned root_count = 0, top_count = 0;
      int good;
      (void)user_data;

      iter = vpi_iterate(vpiUdpDefn, 0);
      while (iter && vpi_scan(iter)) root_count += 1;
      top = vpi_handle_by_name("issue1408_vpi_udp_defn", 0);
      iter = vpi_iterate(vpiUdpDefn, top);
      while (iter && vpi_scan(iter)) top_count += 1;

      defn = vpi_handle_by_name("myudp", 0);
      good = root_count == 2 && top_count == 2 && defn &&
	    check_defn(defn, "myudp", 2, vpiCombPrim,
		       comb_rows, sizeof comb_rows / sizeof comb_rows[0]);
      defn = vpi_handle_by_name("sequdp", 0);
      good = good && defn && check_defn(defn, "sequdp", 1, vpiSeqPrim,
						seq_rows, sizeof seq_rows / sizeof seq_rows[0]);
      if (good)
	    vpi_printf("PASS: issue1408 UDP definitions and table entries\nPASSED\n");
      else
	    vpi_printf("FAIL: issue1408 UDP definitions and table entries roots=%u top=%u\n",
		       root_count, top_count);
      return 0;
}

static void register_check(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$check_udp_defs";
      tf.calltf = check_udp_defs;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_check, 0 };
