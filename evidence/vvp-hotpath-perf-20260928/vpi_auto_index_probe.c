#include <vpi_user.h>
#include <stdio.h>
#include <string.h>
static int ncb[64]; static char names[64][128]; static int nn;
static PLI_INT32 cb(p_cb_data d) { ncb[(long)d->user_data]++; return 0; }
static void walk(vpiHandle scope) {
  int types[] = { vpiVariables, vpiReg, vpiIntegerVar, 0 };
  for (int t = 0; types[t]; t++) {
    vpiHandle it = vpi_iterate(types[t], scope), v;
    if (!it) continue;
    while ((v = vpi_scan(it))) {
      const char*n = vpi_get_str(vpiFullName, v);
      if (!strstr(n, ".j") && !strstr(n, ".k")) continue;
      int dup = 0; for (int i = 0; i < nn; i++) if (!strcmp(names[i], n)) dup = 1;
      if (dup || nn >= 64) continue;
      strncpy(names[nn], n, 127);
      s_vpi_time tm = { vpiSimTime }; s_vpi_value val = { vpiIntVal };
      s_cb_data c = { cbValueChange, cb, v, &tm, &val, 0, (PLI_BYTE8*)(long)nn };
      vpiHandle h = vpi_register_cb(&c);
      vpi_printf("cbv: %s automatic=%d cb=%s\n", n, (int)vpi_get(vpiAutomatic, v), h ? "ok" : "null");
      nn++;
    }
  }
  vpiHandle it = vpi_iterate(vpiInternalScope, scope), s;
  if (it) while ((s = vpi_scan(it))) walk(s);
}
static PLI_INT32 start(p_cb_data d) {
  vpiHandle it = vpi_iterate(vpiModule, 0), m;
  while ((m = vpi_scan(it))) walk(m);
  return 0;
}
static PLI_INT32 end(p_cb_data d) { for (int i = 0; i < nn; i++) vpi_printf("cbv: %s callbacks=%d\n", names[i], ncb[i]); return 0; }
static void reg(void) {
  s_cb_data c = { cbStartOfSimulation, start }; vpi_register_cb(&c);
  s_cb_data e = { cbEndOfSimulation, end }; vpi_register_cb(&e);
}
void (*vlog_startup_routines[])(void) = { reg, 0 };
