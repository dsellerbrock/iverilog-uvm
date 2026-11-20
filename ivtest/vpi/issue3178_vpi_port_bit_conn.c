#include "vpi_user.h"

static void show_conn(vpiHandle bit, PLI_INT32 relation)
{
      vpiHandle conn = vpi_handle(relation, bit);
      if (!conn) {
            vpi_printf("NULL");
            return;
      }

      PLI_INT32 type = vpi_get(vpiType, conn);
      const char*name = vpi_get_str(vpiFullName, conn);
      if (type == vpiNetBit || type == vpiRegBit)
            vpi_printf("%s:%s", type == vpiNetBit ? "net" : "var",
                       name ? name : "<unnamed>");
      else
            vpi_printf("unexpected type %d", (int)type);
}

static void show_ports(const char*instance)
{
      vpiHandle scope = vpi_handle_by_name((PLI_BYTE8*)instance, 0);
      vpiHandle ports = scope ? vpi_iterate(vpiPort, scope) : 0;
      vpiHandle port;
      while (ports && (port = vpi_scan(ports))) {
            vpiHandle bits = vpi_iterate(vpiBit, port);
            vpiHandle bit;
            unsigned pos = 0;
            while (bits && (bit = vpi_scan(bits))) {
                  vpi_printf("%s.%s bit %u high=", instance,
                             vpi_get_str(vpiName, port), pos++);
                  show_conn(bit, vpiHighConn);
                  vpi_printf(" low=");
                  show_conn(bit, vpiLowConn);
                  vpi_printf("\n");
            }
      }
}

static PLI_INT32 probe(p_cb_data cb)
{
      (void)cb;
      show_ports("top.l");
      show_ports("top.c");
      return 0;
}

static void startup(void)
{
      s_cb_data cb = {0};
      cb.reason = cbStartOfSimulation;
      cb.cb_rtn = probe;
      vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = {startup, 0};
