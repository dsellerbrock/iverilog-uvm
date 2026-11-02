#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

#ifndef vpiPortType
#define vpiPortType 611
#endif

struct expected_port {
      const char *name;
      int type;
};

static const struct expected_port expected[] = {
      {"a", 44},
      {"y", 44},
      {"p", 1},
      {"q", 2},
      {"one", 44},
      {"z", 44}
};

static PLI_INT32 probe(PLI_BYTE8 *ud)
{
      vpiHandle u = vpi_handle_by_name((PLI_BYTE8*)"top.u", 0);
      vpiHandle it, port;
      unsigned count = 0;
      int failed = 0;
      (void)ud;

      it = u ? vpi_iterate(vpiPort, u) : 0;
      while (it && (port = vpi_scan(it))) {
            const char *name = vpi_get_str(vpiName, port);
            int type = vpi_get(vpiPortType, port);
            vpi_printf("%s %d\n", name ? name : "<null>", type);
            if (count >= sizeof expected / sizeof expected[0]
                || !name || strcmp(name, expected[count].name) != 0
                || type != expected[count].type)
                  failed = 1;
            count += 1;
      }

      if (count != sizeof expected / sizeof expected[0])
            failed = 1;
      if (failed)
            vpi_printf("ISSUE1272_VPI_PORT_TYPE_FAILED\n");
      else
            vpi_printf("ISSUE1272_VPI_PORT_TYPE_PASSED\nPASSED\n");
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$probe";
      tf.calltf = probe;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
