/* IEEE 1800-2023 39.5.1 / 39.5.2: vpiAssertionSysReset clears step enables. */
# include  <stdio.h>
# include  <vpi_user.h>
# include  <sv_vpi_user.h>

static PLI_INT32 step_cb(PLI_INT32 reason, p_vpi_time t, vpiHandle a,
			 p_vpi_attempt_info info, PLI_BYTE8*ud)
{
      s_vpi_time now;
      (void)t; (void)info; (void)ud;
      now.type = vpiSimTime;
      vpi_get_time(0, &now);
      vpi_printf("%d: %s %s\n", (int)now.low, vpi_get_str(vpiFullName, a),
		 reason == cbAssertionStepSuccess ? "step" : "step fail");
      return 0;
}

static void watch(vpiHandle a)
{
      vpi_register_assertion_cb(a, cbAssertionStepSuccess, step_cb, 0);
      vpi_register_assertion_cb(a, cbAssertionStepFailure, step_cb, 0);
}

static PLI_INT32 setup(PLI_BYTE8*ud)
{
      const char*names[2] = { "sva_sys_reset_step.u.x", "sva_sys_reset_step.y" };
      int i;
      (void)ud;
      for (i = 0 ; i < 2 ; i += 1) {
	    vpiHandle a = vpi_handle_by_name((PLI_BYTE8*)names[i], 0);
	    s_vpi_time t;
	    t.type = vpiSimTime;
	    t.high = 0;
	    t.low = 25;
	    vpi_printf("EnableStep(%s, 25) = %d\n", vpi_get_str(vpiFullName, a),
		       (int)vpi_control(vpiAssertionEnableStep, a, &t,
					vpiAssertionClockSteps));
	    watch(a);
      }
      return 0;
}

static PLI_INT32 reset(PLI_BYTE8*ud)
{
      vpiHandle u = vpi_handle_by_name((PLI_BYTE8*)"sva_sys_reset_step.u", 0);
      (void)ud;
      vpi_printf("SysReset(u) = %d\n",
		 (int)vpi_control(vpiAssertionSysReset, u));
      return 0;
}

static PLI_INT32 rereg(PLI_BYTE8*ud)
{
      (void)ud;
      watch(vpi_handle_by_name((PLI_BYTE8*)"sva_sys_reset_step.u.x", 0));
      return 0;
}

static void reg(const char*name, PLI_INT32 (*f)(PLI_BYTE8*))
{
      s_vpi_systf_data tf = { vpiSysTask, 0, 0, 0, 0, 0, 0 };
      tf.tfname = (PLI_BYTE8*)name;
      tf.calltf = f;
      vpi_register_systf(&tf);
}

static void sys_register(void)
{
      reg("$rs_setup", setup);
      reg("$rs_reset", reset);
      reg("$rs_rereg", rereg);
}

void (*vlog_startup_routines[])(void) = { sys_register, 0 };
