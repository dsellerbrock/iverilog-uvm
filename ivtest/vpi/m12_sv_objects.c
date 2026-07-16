/*
 * M12: VPI SystemVerilog object model — variables, containers, class
 * members, dotted-path descent, value-change callbacks on SV types.
 */
#include <vpi_user.h>
#include <sv_vpi_user.h>
#include <string.h>

static PLI_INT32 cb_vc(p_cb_data cbd)
{
      vpi_printf("CB %s ->", vpi_get_str(vpiName, cbd->obj));
      if (cbd->value && cbd->value->format == vpiStringVal)
	    vpi_printf(" '%s'", cbd->value->value.str);
      vpi_printf("\n");
      return 0;
}

static PLI_INT32 setup_calltf(PLI_BYTE8*ud)
{
      static s_vpi_time tt;
      static s_vpi_value vv;
      s_cb_data cbd;
      vpiHandle s = vpi_handle_by_name((char*)"top.s", 0);
      (void)ud;

      tt.type = vpiSuppressTime;
      vv.format = vpiStringVal;
      memset(&cbd, 0, sizeof cbd);
      cbd.reason = cbValueChange;
      cbd.cb_rtn = cb_vc;
      cbd.obj = s;
      cbd.time = &tt;
      cbd.value = &vv;
      vpi_printf("cb-string: %s\n", vpi_register_cb(&cbd) ? "ok" : "FAILED");
      return 0;
}

static PLI_INT32 probe_calltf(PLI_BYTE8*ud)
{
      s_vpi_value val;
      vpiHandle h, el, it;
      (void)ud;

      /* SV variable types and values */
      h = vpi_handle_by_name((char*)"top.i", 0);
      vpi_printf("i: type=%d size=%d\n", vpi_get(vpiType, h),
		 vpi_get(vpiSize, h));
      h = vpi_handle_by_name((char*)"top.s", 0);
      val.format = vpiStringVal;
      vpi_get_value(h, &val);
      vpi_printf("s: type=%d '%s'\n", vpi_get(vpiType, h), val.value.str);
      val.format = vpiStringVal;
      val.value.str = (char*)"rewritten";
      vpi_put_value(h, &val, 0, vpiNoDelay);

      /* dynamic array: kind, size, element read AND write */
      h = vpi_handle_by_name((char*)"top.da", 0);
      vpi_printf("da: arraytype=%d size=%d\n", vpi_get(vpiArrayType, h),
		 vpi_get(vpiSize, h));
      el = vpi_handle_by_index(h, 1);
      val.format = vpiIntVal;
      vpi_get_value(el, &val);
      vpi_printf("da[1]=%d\n", (int)val.value.integer);
      val.format = vpiIntVal;
      val.value.integer = 99;
      vpi_put_value(el, &val, 0, vpiNoDelay);

      /* queue: kind, size, element read */
      h = vpi_handle_by_name((char*)"top.q", 0);
      vpi_printf("q: arraytype=%d size=%d\n", vpi_get(vpiArrayType, h),
		 vpi_get(vpiSize, h));
      el = vpi_handle_by_index(h, 0);
      val.format = vpiIntVal;
      vpi_get_value(el, &val);
      vpi_printf("q[0]=%d\n", (int)val.value.integer);

      /* associative array: kind, size, positional iteration (key order) */
      h = vpi_handle_by_name((char*)"top.aa", 0);
      vpi_printf("aa: arraytype=%d size=%d\n", vpi_get(vpiArrayType, h),
		 vpi_get(vpiSize, h));
      it = vpi_iterate(vpiMember, h);
      while (it && (el = vpi_scan(it))) {
	    val.format = vpiObjTypeVal;
	    vpi_get_value(el, &val);
	    if (val.format == vpiVectorVal)
		  vpi_printf("aa elem %d\n", (int)val.value.vector[0].aval);
      }

      /* class variable: member iteration, member read/write by name */
      h = vpi_handle_by_name((char*)"top.obj", 0);
      vpi_printf("obj: type=%d\n", vpi_get(vpiType, h));
      it = vpi_iterate(vpiMember, h);
      while (it && (el = vpi_scan(it))) {
	    char*nm = vpi_get_str(vpiName, el);
	    vpi_printf("member %s type=%d size=%d\n", nm,
		       vpi_get(vpiType, el), vpi_get(vpiSize, el));
      }
      el = vpi_handle_by_name((char*)"top.obj.count", 0);
      val.format = vpiIntVal;
      vpi_get_value(el, &val);
      vpi_printf("obj.count=%d\n", (int)val.value.integer);
      val.format = vpiIntVal;
      val.value.integer = -5;
      vpi_put_value(el, &val, 0, vpiNoDelay);
      el = vpi_handle_by_name((char*)"top.obj.name", 0);
      val.format = vpiStringVal;
      val.value.str = (char*)"from-vpi";
      vpi_put_value(el, &val, 0, vpiNoDelay);
      el = vpi_handle_by_name((char*)"top.obj.ratio", 0);
      val.format = vpiRealVal;
      vpi_get_value(el, &val);
      vpi_printf("obj.ratio=%.2f\n", val.value.real);

      /* vpiVariables iteration includes SV variables */
      h = vpi_handle_by_name((char*)"top", 0);
      it = vpi_iterate(vpiVariables, h);
      while (it && (el = vpi_scan(it)))
	    vpi_printf("var %s type=%d\n", vpi_get_str(vpiName, el),
		       vpi_get(vpiType, el));
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$m12_setup";
      tf.calltf = setup_calltf;
      vpi_register_systf(&tf);
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$m12_probe";
      tf.calltf = probe_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
