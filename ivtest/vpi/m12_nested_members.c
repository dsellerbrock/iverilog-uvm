/* M12-5: nested class-member traversal through VPI. */
# include  <vpi_user.h>
# include  <sv_vpi_user.h>
# include  <string.h>

static vpiHandle deep_count;   /* kept across probes: must stay live */

static void walk(vpiHandle h, int depth)
{
      vpiHandle it = vpi_iterate(vpiMember, h);
      vpiHandle el;
      while (it && (el = vpi_scan(it))) {
	    vpi_printf("%*smember %s\n", 2*depth, "",
		       vpi_get_str(vpiName, el));
	    if (depth < 3)
		  walk(el, depth + 1);
      }
}

static PLI_INT32 probe_calltf(PLI_BYTE8*ud)
{
      s_vpi_value val;
      vpiHandle h;
      (void)ud;

      /* four-hop read and write; keep the handle for the re-probe */
      deep_count = vpi_handle_by_name((char*)"top.env.agent.cfg.leaf.count", 0);
      if (!deep_count) {
	    vpi_printf("deep count: NO HANDLE\n");
	    return 0;
      }
      val.format = vpiIntVal;
      vpi_get_value(deep_count, &val);
      vpi_printf("deep count=%d\n", (int)val.value.integer);
      vpi_printf("deep fullname=%s\n", vpi_get_str(vpiFullName, deep_count));
      val.format = vpiIntVal;
      val.value.integer = 42;
      vpi_put_value(deep_count, &val, 0, vpiNoDelay);

      h = vpi_handle_by_name((char*)"top.env.agent.cfg.leaf.tag", 0);
      val.format = vpiStringVal;
      val.value.str = (char*)"vpi";
      vpi_put_value(h, &val, 0, vpiNoDelay);

      /* null intermediate: graceful, no handle */
      h = vpi_handle_by_name((char*)"top.env.dead.cfg.leaf.count", 0);
      vpi_printf("null-mid handle=%s\n", h ? "yes" : "no");

      /* recursive member iteration from the top variable */
      h = vpi_handle_by_name((char*)"top.env", 0);
      walk(h, 0);
      return 0;
}

static PLI_INT32 reprobe_calltf(PLI_BYTE8*ud)
{
      s_vpi_value val;
      (void)ud;
      /* the same handle after env.agent was re-assigned: must read the
       * FRESH subtree */
      val.format = vpiIntVal;
      vpi_get_value(deep_count, &val);
      vpi_printf("reprobe count=%d\n", (int)val.value.integer);
      val.format = vpiIntVal;
      val.value.integer = 55;
      vpi_put_value(deep_count, &val, 0, vpiNoDelay);
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$m12nm_probe";
      tf.calltf = probe_calltf;
      vpi_register_systf(&tf);
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$m12nm_reprobe";
      tf.calltf = reprobe_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
