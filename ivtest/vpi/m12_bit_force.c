/* M12-3: VPI force/release + cbForce/cbRelease on a single bit-select. */
# include  <vpi_user.h>
# include  <string.h>

static PLI_INT32 fcb(struct t_cb_data*d)
{
      int tm = -1;
      if (d->time)
	    tm = (int)d->time->low;
      vpi_printf("cb reason=%d name=%s time=%d\n",
		 (int)d->reason, vpi_get_str(vpiName, d->obj), tm);
      return 0;
}

static vpiHandle bit3(void)
{
      vpiHandle sig = vpi_handle_by_name((char*)"top.sig", 0);
      return vpi_handle_by_index(sig, 3);
}

static PLI_INT32 setup(PLI_BYTE8*ud)
{
      vpiHandle b = bit3();
      s_cb_data cb;
      s_vpi_time t;
      (void)ud;
      vpi_printf("bit type=%d\n", (int)vpi_get(vpiType, b));
      memset(&t, 0, sizeof t); t.type = vpiSimTime;
      memset(&cb, 0, sizeof cb); cb.obj = b; cb.time = &t; cb.cb_rtn = fcb;
      cb.reason = cbForce;   vpi_register_cb(&cb);
      cb.reason = cbRelease; vpi_register_cb(&cb);
      return 0;
}

static PLI_INT32 doforce(PLI_BYTE8*ud)
{
      vpiHandle b = bit3();
      s_vpi_value v;
      (void)ud;
      v.format = vpiIntVal; v.value.integer = 1;
      vpi_put_value(b, &v, 0, vpiForceFlag);
      return 0;
}

static PLI_INT32 dorel(PLI_BYTE8*ud)
{
      vpiHandle b = bit3();
      s_vpi_value v;
      (void)ud;
      v.format = vpiIntVal; v.value.integer = 0;
      vpi_put_value(b, &v, 0, vpiReleaseFlag);
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask; tf.tfname = "$bf_setup"; tf.calltf = setup;
      vpi_register_systf(&tf);
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask; tf.tfname = "$bf_force3"; tf.calltf = doforce;
      vpi_register_systf(&tf);
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask; tf.tfname = "$bf_rel3"; tf.calltf = dorel;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
