/*
 * A cbValueChange registered on a runtime-container element must fire for
 * both SystemVerilog and VPI writes. Class-property element handles use
 * the same callback semantics as direct container variables.
 */
#include <vpi_user.h>
#include <sv_vpi_user.h>
#include <math.h>
#include <stdio.h>
#include <string.h>

enum watch_kind {
      WATCH_INT,
      WATCH_REAL,
      WATCH_STRING
};

struct watched {
      const char*name;
      const char*path;
      enum watch_kind kind;
      vpiHandle element;
      vpiHandle callback;
      s_vpi_time time_data;
      s_vpi_value value_data;
      int count;
      int last_int;
      int want_int;
      double last_real;
      double want_real;
      char last_string[32];
      const char*want_string;
};

static struct watched watches[] = {
      {.name="direct", .path="top.q", .kind=WATCH_INT, .want_int=13},
      {.name="direct-assoc", .path="top.aa", .kind=WATCH_INT, .want_int=53},
      {.name="property", .path="top.obj.q", .kind=WATCH_INT, .want_int=23},
      {.name="dynamic", .path="top.obj.da", .kind=WATCH_INT, .want_int=33},
      {.name="assoc", .path="top.obj.aa", .kind=WATCH_INT, .want_int=43},
      {.name="string", .path="top.obj.sq", .kind=WATCH_STRING,
       .want_string="vpi"},
      {.name="real", .path="top.obj.rd", .kind=WATCH_REAL, .want_real=3.5}
};
#define WATCH_COUNT (sizeof watches / sizeof watches[0])
static int failed;

static PLI_INT32 changed_cb(p_cb_data cbd)
{
      struct watched*w = (struct watched*)cbd->user_data;
      w->count += 1;
      if (cbd->value) {
            if (w->kind == WATCH_INT) {
                  w->last_int = cbd->value->value.integer;
            } else if (w->kind == WATCH_REAL) {
                  w->last_real = cbd->value->value.real;
            } else {
                  snprintf(w->last_string, sizeof w->last_string, "%s",
                           cbd->value->value.str
                                 ? (const char*)cbd->value->value.str : "");
            }
      }
      if (w->kind == WATCH_INT)
            vpi_printf("CB %s count=%d value=%d\n",
                       w->name, w->count, w->last_int);
      else if (w->kind == WATCH_REAL)
            vpi_printf("CB %s count=%d value=%.3f\n",
                       w->name, w->count, w->last_real);
      else
            vpi_printf("CB %s count=%d value='%s'\n",
                       w->name, w->count, w->last_string);
      return 0;
}

static void register_one(struct watched*w)
{
      s_cb_data cbd;
      vpiHandle container = vpi_handle_by_name((PLI_BYTE8*)w->path, 0);

      if (!container) {
            vpi_printf("FAILED %s container handle is null\n", w->path);
            failed += 1;
            return;
      }
      w->element = vpi_handle_by_index(container, 0);
      if (!w->element) {
            vpi_printf("FAILED %s[0] handle is null\n", w->path);
            failed += 1;
            return;
      }

      memset(&w->time_data, 0, sizeof w->time_data);
      w->time_data.type = vpiSuppressTime;
      memset(&w->value_data, 0, sizeof w->value_data);
      w->value_data.format = w->kind == WATCH_INT ? vpiIntVal
                           : w->kind == WATCH_REAL ? vpiRealVal
                           : vpiStringVal;
      memset(&cbd, 0, sizeof cbd);
      cbd.reason = cbValueChange;
      cbd.cb_rtn = changed_cb;
      cbd.obj = w->element;
      cbd.time = &w->time_data;
      cbd.value = &w->value_data;
      cbd.user_data = (PLI_BYTE8*)w;
      w->callback = vpi_register_cb(&cbd);
      if (!w->callback) {
            vpi_printf("FAILED callback registration %s\n", w->path);
            failed += 1;
      }
}

static PLI_INT32 setup_calltf(PLI_BYTE8*ud)
{
      size_t idx;
      (void)ud;
      for (idx = 0; idx < WATCH_COUNT; idx += 1)
            register_one(&watches[idx]);
      return 0;
}

static void vpi_write(struct watched*w)
{
      s_vpi_value val;
      if (!w->element)
            return;
      if (w->kind == WATCH_INT) {
            val.format = vpiIntVal;
            val.value.integer = w->want_int;
      } else if (w->kind == WATCH_REAL) {
            val.format = vpiRealVal;
            val.value.real = w->want_real;
      } else {
            val.format = vpiStringVal;
            val.value.str = (PLI_BYTE8*)w->want_string;
      }
      vpi_put_value(w->element, &val, 0, vpiNoDelay);
}

static PLI_INT32 writes_calltf(PLI_BYTE8*ud)
{
      size_t idx;
      (void)ud;
      for (idx = 0; idx < WATCH_COUNT; idx += 1)
            vpi_write(&watches[idx]);
      return 0;
}

static void check_one(const struct watched*w, int count)
{
      int value_ok = w->kind == WATCH_INT ? w->last_int == w->want_int
                   : w->kind == WATCH_REAL
                         ? fabs(w->last_real - w->want_real) < 1e-9
                         : strcmp(w->last_string, w->want_string) == 0;
      if (w->count != count || !value_ok) {
            if (w->kind == WATCH_STRING) {
                  vpi_printf("FAILED %s callback count=%d last='%s' "
                             "want %d/'%s'\n", w->name, w->count,
                             w->last_string, count, w->want_string);
            } else if (w->kind == WATCH_REAL) {
                  vpi_printf("FAILED %s callback count=%d last=%f "
                             "want %d/%f\n", w->name, w->count,
                             w->last_real, count, w->want_real);
            } else {
                  vpi_printf("FAILED %s callback count=%d last=%d "
                             "want %d/%d\n", w->name, w->count,
                             w->last_int, count, w->want_int);
            }
            failed += 1;
      }
}

static PLI_INT32 check_calltf(PLI_BYTE8*ud)
{
      size_t idx;
      (void)ud;
      for (idx = 0; idx < WATCH_COUNT; idx += 1)
            check_one(&watches[idx], 2);
      if (failed == 0)
            vpi_printf("PASSED\n");
      else
            vpi_printf("FAILED total=%d\n", failed);
      return 0;
}

static void register_tasks(void)
{
      s_vpi_systf_data tf;
      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$m12_container_cb_setup";
      tf.calltf = setup_calltf;
      vpi_register_systf(&tf);

      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$m12_container_cb_vpi_writes";
      tf.calltf = writes_calltf;
      vpi_register_systf(&tf);

      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$m12_container_cb_check";
      tf.calltf = check_calltf;
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
