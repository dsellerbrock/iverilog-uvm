/* M12-8: VPI handle lifetime/free audit. */
# include  <vpi_user.h>
# include  <sv_vpi_user.h>
# include  <string.h>

static vpiHandle held_member;   /* kept across probes for use-after-null */

/* Collect the handles an iterator yields into an array (up to max).
 * The iterator auto-frees on scan exhaustion. */
static int collect(vpiHandle it, vpiHandle*out, int max)
{
      int n = 0;
      vpiHandle el;
      while (it && (el = vpi_scan(it)) && n < max)
	    out[n++] = el;
      return n;
}

static PLI_INT32 probe_calltf(PLI_BYTE8*ud)
{
      vpiHandle obj, cg, a1[16], a2[16];
      int n1, n2, i, stable;
      (void)ud;

      /* class member handles must be identical across iterate calls
       * (owned by the variable, not reallocated). */
      obj = vpi_handle_by_name((char*)"top.n", 0);
      n1 = collect(vpi_iterate(vpiMember, obj), a1, 16);
      n2 = collect(vpi_iterate(vpiMember, obj), a2, 16);
      stable = (n1 == n2);
      for (i = 0 ; i < n1 && stable ; i += 1)
	    if (a1[i] != a2[i]) stable = 0;
      vpi_printf("members n=%d stable=%d\n", n1, stable);
      held_member = vpi_handle_by_name((char*)"top.n.leaf.v", 0);

      /* covergroup item handles must also be stable (M12-8 cache). */
      cg = vpi_handle_by_name((char*)"top.c1", 0);
      n1 = collect(vpi_iterate(vpiCoverpoint, cg), a1, 16);
      n2 = collect(vpi_iterate(vpiCoverpoint, cg), a2, 16);
      stable = (n1 == n2);
      for (i = 0 ; i < n1 && stable ; i += 1)
	    if (a1[i] != a2[i]) stable = 0;
      vpi_printf("cov items n=%d stable=%d\n", n1, stable);

      /* and the bin handles of an item, across two iterate calls */
      if (n1 > 0) {
	    vpiHandle b1[16], b2[16];
	    int m1 = collect(vpi_iterate(vpiCoverBin, a1[0]), b1, 16);
	    int m2 = collect(vpi_iterate(vpiCoverBin, a2[0]), b2, 16);
	    int bstable = (m1 == m2);
	    for (i = 0 ; i < m1 && bstable ; i += 1)
		  if (b1[i] != b2[i]) bstable = 0;
	    vpi_printf("cov bins n=%d stable=%d\n", m1, bstable);
      }

      /* explicit free of a container-owned handle must be a safe
       * no-op (suppress_free), not a double-free/crash. */
      vpi_free_object(held_member);
      {
	    s_vpi_value val;
	    val.format = vpiIntVal;
	    vpi_get_value(held_member, &val);
	    vpi_printf("after free, v=%d\n", (int)val.value.integer);
      }
      return 0;
}

static PLI_INT32 after_null_calltf(PLI_BYTE8*ud)
{
      s_vpi_value val;
      (void)ud;
      /* the backing object was set to null; the deep handle must read
       * safely (suppressed / no crash). */
      val.format = vpiIntVal;
      val.value.integer = -1;
      vpi_get_value(held_member, &val);
      vpi_printf("after null, format=%d\n", (int)val.format);
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$m12lt_probe";
      tf.calltf = probe_calltf;
      vpi_register_systf(&tf);
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$m12lt_after_null";
      tf.calltf = after_null_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
