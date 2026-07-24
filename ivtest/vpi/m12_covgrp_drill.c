/* M12-7: drill into a covergroup object's coverage model via VPI. */
# include  <vpi_user.h>
# include  <sv_vpi_user.h>
# include  <string.h>

static void drill(const char*path)
{
      vpiHandle h, it, item, bit_, bin;
      s_vpi_value val;

      h = vpi_handle_by_name((char*)path, 0);
      if (!h) {
	    vpi_printf("%s: NO HANDLE\n", path);
	    return;
      }
      it = vpi_iterate(vpiCoverpoint, h);
      while (it && (item = vpi_scan(it))) {
	    val.format = vpiRealVal;
	    vpi_get_value(item, &val);
	    vpi_printf("%s cp %s type=%d at_least=%d weight=%d bins=%d cov=%.2f\n",
		       path, vpi_get_str(vpiName, item),
		       vpi_get(vpiType, item),
		       vpi_get(vpiCoverAtLeast, item),
		       vpi_get(vpiCoverWeight, item),
		       vpi_get(vpiSize, item), val.value.real);
	    bit_ = vpi_iterate(vpiCoverBin, item);
	    while (bit_ && (bin = vpi_scan(bit_))) {
		  vpi_printf("  bin %s count=%d type_count=%d\n",
			     vpi_get_str(vpiName, bin),
			     vpi_get(vpiCoverCount, bin),
			     vpi_get(vpiCoverTypeCount, bin));
	    }
      }
      it = vpi_iterate(vpiCoverCross, h);
      while (it && (item = vpi_scan(it))) {
	    val.format = vpiRealVal;
	    vpi_get_value(item, &val);
	    vpi_printf("%s cross %s bins=%d cov=%.2f\n",
		       path, vpi_get_str(vpiName, item),
		       vpi_get(vpiSize, item), val.value.real);
      }
}

static PLI_INT32 probe_calltf(PLI_BYTE8*ud)
{
      (void)ud;
      drill("top.c1");
      drill("top.c2");
      drill("top.wr.wcg");    /* embedded: nested member handle */
      /* a non-covergroup object yields no items */
      {
	    vpiHandle h = vpi_handle_by_name((char*)"top.wr", 0);
	    vpiHandle it = vpi_iterate(vpiCoverpoint, h);
	    vpi_printf("non-cg items=%s\n", it ? "yes" : "none");
      }
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$m12cd_probe";
      tf.calltf = probe_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
