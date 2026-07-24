/* M12-6: modport direction metadata via vpi_iterate(vpiIODecl). */
# include  <vpi_user.h>
# include  <sv_vpi_user.h>
# include  <string.h>

static const char* dir_str(int dir)
{
      switch (dir) {
	  case vpiInput:  return "input";
	  case vpiOutput: return "output";
	  case vpiInout:  return "inout";
	  default:        return "nodir";
      }
}

static PLI_INT32 probe_calltf(PLI_BYTE8*ud)
{
      vpiHandle scope, mit, mp, pit, io;
      (void)ud;

      scope = vpi_handle_by_name((char*)"top.bus", 0);
      if (!scope) {
	    vpi_printf("no interface scope\n");
	    return 0;
      }
      mit = vpi_iterate(vpiModport, scope);
      while (mit && (mp = vpi_scan(mit))) {
	    vpi_printf("modport %s ports=%d\n",
		       vpi_get_str(vpiName, mp), vpi_get(vpiSize, mp));
	    pit = vpi_iterate(vpiIODecl, mp);
	    while (pit && (io = vpi_scan(pit))) {
		  char nm[128], fn[256];
		  /* vpi_get_str returns a shared buffer: copy before
		   * the next call. */
		  strncpy(nm, vpi_get_str(vpiName, io), sizeof nm - 1);
		  nm[sizeof nm - 1] = 0;
		  strncpy(fn, vpi_get_str(vpiFullName, io), sizeof fn - 1);
		  fn[sizeof fn - 1] = 0;
		  vpi_printf("  %s %s (full %s)\n",
			     dir_str(vpi_get(vpiDirection, io)), nm, fn);
	    }
      }
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$m12mp_probe";
      tf.calltf = probe_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
