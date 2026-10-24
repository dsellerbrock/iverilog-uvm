#include <vpi_user.h>

static int cnt = 0;
static s_cb_data cb_data;
static s_vpi_time cb_time = { vpiSimTime };
static s_vpi_value cb_value = { vpiIntVal };

static PLI_INT32 cb(p_cb_data d)
{
  (void)d;
  cnt++;
  return 0;
}

static PLI_INT32 probe(PLI_BYTE8 *u)
{
  s_vpi_vlog_info vi;
  vpiHandle r, m, it, h;
  int info_ok, n = 0;
  s_vpi_value v = { vpiIntVal };
  (void)u;

  info_ok = vpi_get_vlog_info(&vi);
  r = vpi_handle_by_name("p36.r", NULL);
  if (!info_ok || !r) {
    vpi_printf("V1 FAIL %d %d\n", info_ok, r != NULL);
    return 1;
  }
  vpi_get_value(r, &v);
  vpi_printf("V1 %d %d\n", v.value.integer, info_ok && vi.product != NULL);
  v.value.integer = 9;
  vpi_put_value(r, &v, NULL, vpiNoDelay);
  vpi_get_value(r, &v);
  vpi_printf("V2 %d\n", v.value.integer);

  m = vpi_handle_by_name("p36", NULL);
  if (!m) {
    vpi_printf("V3 FAIL module lookup\n");
    return 1;
  }
  it = vpi_iterate(vpiNet, m);
  while (it && (h = vpi_scan(it))) n++;
  vpi_printf("V3 %d\n", n);

  cb_data.reason = cbValueChange;
  cb_data.cb_rtn = cb;
  cb_data.obj = r;
  cb_data.time = &cb_time;
  cb_data.value = &cb_value;
  cb_data.user_data = NULL;
  if (!vpi_register_cb(&cb_data)) vpi_printf("V4 FAIL callback registration\n");
  return 0;
}

static PLI_INT32 report(PLI_BYTE8 *u)
{
  (void)u;
  vpi_printf("V4 %d\n", cnt);
  return 0;
}

static void reg(void)
{
  static s_vpi_systf_data a = { vpiSysTask, 0, "$probe36", probe, 0, 0, 0 };
  static s_vpi_systf_data b = { vpiSysTask, 0, "$report36", report, 0, 0, 0 };
  vpi_register_systf(&a);
  vpi_register_systf(&b);
}

void (*vlog_startup_routines[])(void) = { reg, 0 };
