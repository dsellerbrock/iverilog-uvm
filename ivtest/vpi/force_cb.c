/*
 * M12B-fr: cbForce/cbRelease callbacks (IEEE 1800-2017 38.36.1).
 * $force_monitor(sig) registers a cbForce and a cbRelease callback on
 * the signal; each fires when a force or release lands on it -- from
 * the compiled %force/%release opcodes or from vpi_put_value with
 * vpiForceFlag/vpiReleaseFlag, whole-signal or bit-select.
 * $vpi_force(sig, "bits") / $vpi_release(sig) drive the VPI side.
 */
# include  <vpi_user.h>
# include  <stdlib.h>
# include  <string.h>

static PLI_INT32 force_cb(struct t_cb_data*cb)
{
      vpi_printf("cbForce: %s = %s\n",
		 vpi_get_str(vpiName, cb->obj), cb->value->value.str);
      return 0;
}

static PLI_INT32 release_cb(struct t_cb_data*cb)
{
      vpi_printf("cbRelease: %s = %s\n",
		 vpi_get_str(vpiName, cb->obj), cb->value->value.str);
      return 0;
}

static PLI_INT32 monitor_calltf(PLI_BYTE8*name)
{
      vpiHandle sys  = vpi_handle(vpiSysTfCall,0);
      vpiHandle argv = vpi_iterate(vpiArgument, sys);
      vpiHandle arg;

      (void)name;

      while ( (arg = vpi_scan(argv)) ) {
	    s_cb_data cb_data;

	    memset(&cb_data, 0, sizeof(cb_data));
	    cb_data.cb_rtn = force_cb;
	    cb_data.reason = cbForce;
	    cb_data.obj = arg;
	    cb_data.value = malloc(sizeof(struct t_vpi_value));
	    cb_data.value->format = vpiBinStrVal;
	    cb_data.value->value.str = 0;
	    vpi_register_cb(&cb_data);

	    memset(&cb_data, 0, sizeof(cb_data));
	    cb_data.cb_rtn = release_cb;
	    cb_data.reason = cbRelease;
	    cb_data.obj = arg;
	    cb_data.value = malloc(sizeof(struct t_vpi_value));
	    cb_data.value->format = vpiBinStrVal;
	    cb_data.value->value.str = 0;
	    vpi_register_cb(&cb_data);
      }
      return 0;
}

static PLI_INT32 vpi_force_calltf(PLI_BYTE8*name)
{
      vpiHandle sys  = vpi_handle(vpiSysTfCall,0);
      vpiHandle argv = vpi_iterate(vpiArgument, sys);
      vpiHandle sig  = vpi_scan(argv);
      vpiHandle valh = vpi_scan(argv);
      s_vpi_value val;

      (void)name;
      vpi_free_object(argv);

      val.format = vpiStringVal;
      vpi_get_value(valh, &val);

      s_vpi_value put;
      put.format = vpiBinStrVal;
      put.value.str = val.value.str;
      vpi_put_value(sig, &put, 0, vpiForceFlag);
      return 0;
}

static PLI_INT32 vpi_release_calltf(PLI_BYTE8*name)
{
      vpiHandle sys  = vpi_handle(vpiSysTfCall,0);
      vpiHandle argv = vpi_iterate(vpiArgument, sys);
      vpiHandle sig  = vpi_scan(argv);
      s_vpi_value put;

      (void)name;
      vpi_free_object(argv);

      put.format = vpiBinStrVal;
      put.value.str = 0;
      vpi_put_value(sig, &put, 0, vpiReleaseFlag);
      return 0;
}

static void register_funcs(void)
{
      s_vpi_systf_data tf;

      tf.type      = vpiSysTask;
      tf.tfname    = "$force_monitor";
      tf.calltf    = monitor_calltf;
      tf.compiletf = 0;
      tf.sizetf    = 0;
      tf.user_data = 0;
      vpi_register_systf(&tf);

      tf.tfname    = "$vpi_force";
      tf.calltf    = vpi_force_calltf;
      vpi_register_systf(&tf);

      tf.tfname    = "$vpi_release";
      tf.calltf    = vpi_release_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = {
      register_funcs,
      0
};
