/*
 * Static class-property storage reached through two different class object
 * variables.  Writes use view_a member handles; all resulting values are
 * read through independently resolved view_b member handles.
 */
#include <vpi_user.h>
#include <sv_vpi_user.h>

#include <math.h>
#include <stdio.h>
#include <string.h>

static int failures;

typedef struct view_handles_s {
      vpiHandle vec4_value;
      vpiHandle real_value;
      vpiHandle string_value;
      vpiHandle shared_object;
      vpiHandle object_marker;
      vpiHandle object_label;
      vpiHandle queue_values;
      vpiHandle dynamic_values;
} view_handles_t;

static void fail_missing(const char*path)
{
      vpi_printf("FAILED VPI missing handle %s\n", path);
      failures += 1;
}

static void fail_int(const char*what, int got, int want)
{
      vpi_printf("FAILED VPI %s got=%d want=%d\n", what, got, want);
      failures += 1;
}

static void fail_string(const char*what, const char*got, const char*want)
{
      vpi_printf("FAILED VPI %s got='%s' want='%s'\n", what,
                 got ? got : "<null>", want);
      failures += 1;
}

static vpiHandle get_handle(const char*path)
{
      vpiHandle handle = vpi_handle_by_name((PLI_BYTE8*)path, 0);
      if (!handle)
            fail_missing(path);
      return handle;
}

static vpiHandle get_view_member(const char*view, const char*member)
{
      char path[256];
      snprintf(path, sizeof path, "%s.%s", view, member);
      return get_handle(path);
}

static void load_view(const char*view, view_handles_t*handles)
{
      handles->vec4_value = get_view_member(view, "vec4_value");
      handles->real_value = get_view_member(view, "real_value");
      handles->string_value = get_view_member(view, "string_value");
      handles->shared_object = get_view_member(view, "shared_object");
      handles->object_marker = get_view_member(view, "shared_object.marker");
      handles->object_label = get_view_member(view, "shared_object.label");
      handles->queue_values = get_view_member(view, "queue_values");
      handles->dynamic_values = get_view_member(view, "dynamic_values");
}

static void check_vec4(vpiHandle handle, const char*what,
                       PLI_UINT32 aval, PLI_UINT32 bval)
{
      s_vpi_value value;
      if (!handle)
            return;
      memset(&value, 0, sizeof value);
      value.format = vpiVectorVal;
      vpi_get_value(handle, &value);
      if (!value.value.vector) {
            vpi_printf("FAILED VPI %s returned no vector\n", what);
            failures += 1;
            return;
      }
      if ((value.value.vector[0].aval & 0xffffU) != aval ||
          (value.value.vector[0].bval & 0xffffU) != bval) {
            vpi_printf("FAILED VPI %s got aval=%04x bval=%04x "
                       "want aval=%04x bval=%04x\n", what,
                       (unsigned)(value.value.vector[0].aval & 0xffffU),
                       (unsigned)(value.value.vector[0].bval & 0xffffU),
                       (unsigned)aval, (unsigned)bval);
            failures += 1;
      }
}

static void put_vec4(vpiHandle handle, PLI_UINT32 aval, PLI_UINT32 bval)
{
      s_vpi_vecval vector;
      s_vpi_value value;
      if (!handle)
            return;
      vector.aval = aval;
      vector.bval = bval;
      memset(&value, 0, sizeof value);
      value.format = vpiVectorVal;
      value.value.vector = &vector;
      vpi_put_value(handle, &value, 0, vpiNoDelay);
}

static void check_real(vpiHandle handle, const char*what, double want)
{
      s_vpi_value value;
      if (!handle)
            return;
      memset(&value, 0, sizeof value);
      value.format = vpiRealVal;
      vpi_get_value(handle, &value);
      if (fabs(value.value.real - want) > 1e-9) {
            vpi_printf("FAILED VPI %s got=%f want=%f\n", what,
                       value.value.real, want);
            failures += 1;
      }
}

static void put_real(vpiHandle handle, double number)
{
      s_vpi_value value;
      if (!handle)
            return;
      memset(&value, 0, sizeof value);
      value.format = vpiRealVal;
      value.value.real = number;
      vpi_put_value(handle, &value, 0, vpiNoDelay);
}

static void check_string(vpiHandle handle, const char*what, const char*want)
{
      s_vpi_value value;
      if (!handle)
            return;
      memset(&value, 0, sizeof value);
      value.format = vpiStringVal;
      vpi_get_value(handle, &value);
      if (!value.value.str || strcmp((const char*)value.value.str, want) != 0)
            fail_string(what, (const char*)value.value.str, want);
}

static void put_string(vpiHandle handle, const char*text)
{
      s_vpi_value value;
      if (!handle)
            return;
      memset(&value, 0, sizeof value);
      value.format = vpiStringVal;
      value.value.str = (PLI_BYTE8*)text;
      vpi_put_value(handle, &value, 0, vpiNoDelay);
}

static void check_int(vpiHandle handle, const char*what, int want)
{
      s_vpi_value value;
      if (!handle)
            return;
      memset(&value, 0, sizeof value);
      value.format = vpiIntVal;
      vpi_get_value(handle, &value);
      if (value.value.integer != want)
            fail_int(what, (int)value.value.integer, want);
}

static void put_int(vpiHandle handle, int number)
{
      s_vpi_value value;
      if (!handle)
            return;
      memset(&value, 0, sizeof value);
      value.format = vpiIntVal;
      value.value.integer = number;
      vpi_put_value(handle, &value, 0, vpiNoDelay);
}

static void check_container(vpiHandle handle, const char*what,
                            int array_type, int size)
{
      if (!handle)
            return;
      if (vpi_get(vpiType, handle) != vpiArrayVar)
            fail_int(what, vpi_get(vpiType, handle), vpiArrayVar);
      if (vpi_get(vpiArrayType, handle) != array_type)
            fail_int(what, vpi_get(vpiArrayType, handle), array_type);
      if (vpi_get(vpiSize, handle) != size)
            fail_int(what, vpi_get(vpiSize, handle), size);
}

static vpiHandle get_element(vpiHandle container, int index,
                             const char*what)
{
      vpiHandle element;
      if (!container)
            return 0;
      element = vpi_handle_by_index(container, index);
      if (!element) {
            vpi_printf("FAILED VPI missing element %s[%d]\n", what, index);
            failures += 1;
      }
      return element;
}

static void export_failures(void)
{
      vpiHandle handle = get_handle("top.vpi_failures");
      s_vpi_value value;
      if (!handle)
            return;
      memset(&value, 0, sizeof value);
      value.format = vpiIntVal;
      value.value.integer = failures;
      vpi_put_value(handle, &value, 0, vpiNoDelay);
}

static PLI_INT32 probe_calltf(PLI_BYTE8*user_data)
{
      view_handles_t view_a;
      view_handles_t view_b;
      vpiHandle a_queue_1;
      vpiHandle b_queue_1;
      vpiHandle a_dynamic_0;
      vpiHandle b_dynamic_0;
      (void)user_data;

      memset(&view_a, 0, sizeof view_a);
      memset(&view_b, 0, sizeof view_b);
      load_view("top.view_a", &view_a);
      load_view("top.view_b", &view_b);

      /* Both object views must initially reach the class-scope values. */
      check_vec4(view_a.vec4_value, "view_a.vec4_value initial", 0x1234, 0);
      check_vec4(view_b.vec4_value, "view_b.vec4_value initial", 0x1234, 0);
      check_real(view_a.real_value, "view_a.real_value initial", 1.25);
      check_real(view_b.real_value, "view_b.real_value initial", 1.25);
      check_string(view_a.string_value, "view_a.string_value initial",
                   "from-sv");
      check_string(view_b.string_value, "view_b.string_value initial",
                   "from-sv");
      if (!view_a.shared_object || !view_b.shared_object) {
            vpi_printf("FAILED VPI static shared object is not visible\n");
            failures += 1;
      }
      check_int(view_a.object_marker, "view_a.shared_object.marker initial", 77);
      check_int(view_b.object_marker, "view_b.shared_object.marker initial", 77);
      check_string(view_a.object_label, "view_a.shared_object.label initial",
                   "payload-from-sv");
      check_string(view_b.object_label, "view_b.shared_object.label initial",
                   "payload-from-sv");

      check_container(view_a.queue_values, "view_a.queue_values",
                      vpiQueueArray, 2);
      check_container(view_b.queue_values, "view_b.queue_values",
                      vpiQueueArray, 2);
      check_container(view_a.dynamic_values, "view_a.dynamic_values",
                      vpiDynamicArray, 2);
      check_container(view_b.dynamic_values, "view_b.dynamic_values",
                      vpiDynamicArray, 2);

      a_queue_1 = get_element(view_a.queue_values, 1, "view_a.queue_values");
      b_queue_1 = get_element(view_b.queue_values, 1, "view_b.queue_values");
      a_dynamic_0 = get_element(view_a.dynamic_values, 0,
                                "view_a.dynamic_values");
      b_dynamic_0 = get_element(view_b.dynamic_values, 0,
                                "view_b.dynamic_values");
      check_int(a_queue_1, "view_a.queue_values[1] initial", 20);
      check_int(b_queue_1, "view_b.queue_values[1] initial", 20);
      check_int(a_dynamic_0, "view_a.dynamic_values[0] initial", 30);
      check_int(b_dynamic_0, "view_b.dynamic_values[0] initial", 30);

      /* Write only through view_a member handles. */
      put_vec4(view_a.vec4_value, 0xa5f0, 0x00ff);
      put_real(view_a.real_value, 9.75);
      put_string(view_a.string_value, "from-vpi");
      put_int(view_a.object_marker, 88);
      put_int(a_queue_1, 222);
      put_int(a_dynamic_0, 333);

      /* Independently resolved view_b handles must observe those writes. */
      check_vec4(view_b.vec4_value, "view_b.vec4_value after write",
                 0xa5f0, 0x00ff);
      check_real(view_b.real_value, "view_b.real_value after write", 9.75);
      check_string(view_b.string_value, "view_b.string_value after write",
                   "from-vpi");
      check_int(view_b.object_marker,
                "view_b.shared_object.marker after write", 88);
      check_string(view_b.object_label,
                   "view_b.shared_object.label after write",
                   "payload-from-sv");
      check_int(b_queue_1, "view_b.queue_values[1] after write", 222);
      check_int(b_dynamic_0, "view_b.dynamic_values[0] after write", 333);

      export_failures();
      return 0;
}

static void register_tasks(void)
{
      s_vpi_systf_data task;
      memset(&task, 0, sizeof task);
      task.type = vpiSysTask;
      task.tfname = "$static_class_storage_probe";
      task.calltf = probe_calltf;
      vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
