#include <vpi_user.h>
#include <sv_vpi_user.h>

#include <math.h>
#include <stdio.h>
#include <string.h>

enum value_kind { KIND_VEC, KIND_REAL, KIND_STRING, KIND_OBJECT };
enum { SCALAR = -2, WHOLE_ARRAY = -1 };

struct watch_group {
      const char*name;
      const char*direct_path;
      const char*member_name;
      enum value_kind kind;
      int word_index;
      int writes_value;
      PLI_UINT32 want_aval;
      PLI_UINT32 want_bval;
      double want_real;
      const char*want_string;
};

static struct watch_group groups[] = {
      {"vec", "top.store_t.vec_value", "vec_value", KIND_VEC, SCALAR, 1,
       0xa5, 0x0f, 0.0, 0},
      {"real", "top.store_t.real_value", "real_value", KIND_REAL, SCALAR, 1,
       0, 0, 9.75, 0},
      {"string", "top.store_t.string_value", "string_value", KIND_STRING,
       SCALAR, 1, 0, 0, 0.0, "from-vpi"},
      {"object", "top.store_t.object_value", "object_value", KIND_OBJECT,
       SCALAR, 1, 0, 0, 0.0, 0},

      {"vec-whole", "top.store_t.vec_words", "vec_words", KIND_VEC,
       WHOLE_ARRAY, 0, 0xa5, 0x0f, 0.0, 0},
      {"vec-word", "top.store_t.vec_words", "vec_words", KIND_VEC, 4, 1,
       0xa5, 0x0f, 0.0, 0},
      {"real-whole", "top.store_t.real_words", "real_words", KIND_REAL,
       WHOLE_ARRAY, 0, 0, 0, 10.5, 0},
      {"real-word", "top.store_t.real_words", "real_words", KIND_REAL, 5, 1,
       0, 0, 10.5, 0},
      {"string-whole", "top.store_t.string_words", "string_words",
       KIND_STRING, WHOLE_ARRAY, 0, 0, 0, 0.0, "vpi-word"},
      {"string-word", "top.store_t.string_words", "string_words",
       KIND_STRING, 3, 1, 0, 0, 0.0, "vpi-word"},
      {"object-whole", "top.store_t.object_words", "object_words",
       KIND_OBJECT, WHOLE_ARRAY, 0, 0, 0, 0.0, 0},
      {"object-word", "top.store_t.object_words", "object_words",
       KIND_OBJECT, 4, 1, 0, 0, 0.0, 0}
};
#define GROUP_COUNT (sizeof groups / sizeof groups[0])

struct subscription {
      struct watch_group*group;
      const char*view;
      vpiHandle object;
      vpiHandle callback;
      s_vpi_time time;
      s_vpi_value value;
      int count;
      int last_index;
      PLI_UINT32 last_aval;
      PLI_UINT32 last_bval;
      double last_real;
      char last_string[64];
};

static struct subscription subscriptions[GROUP_COUNT * 3];
static int failures;

static void fail(const char*text, const char*name)
{
      vpi_printf("FAILED %s: %s\n", name, text);
      failures += 1;
}

static vpiHandle find_handle(const char*path)
{
      vpiHandle handle = vpi_handle_by_name((PLI_BYTE8*)path, 0);
      if (!handle) {
            vpi_printf("FAILED missing VPI handle %s\n", path);
            failures += 1;
      }
      return handle;
}

static PLI_INT32 changed_cb(p_cb_data data)
{
      struct subscription*sub = (struct subscription*)data->user_data;
      sub->count += 1;
      sub->last_index = data->index;
      if (data->obj != sub->object)
            fail("cb_data.obj was replaced by canonical storage",
                 sub->group->name);
      if (data->value) {
            if (sub->group->kind == KIND_VEC && data->value->value.vector) {
                  sub->last_aval = data->value->value.vector[0].aval;
                  sub->last_bval = data->value->value.vector[0].bval;
            } else if (sub->group->kind == KIND_REAL) {
                  sub->last_real = data->value->value.real;
            } else if (sub->group->kind == KIND_STRING) {
                  snprintf(sub->last_string, sizeof sub->last_string, "%s",
                           data->value->value.str
                                 ? (const char*)data->value->value.str : "");
            }
      }
      return 0;
}

static void check_fixed_shape(vpiHandle array, const struct watch_group*group,
                              const char*path)
{
      int want_left = 0;
      int want_right = 0;
      s_vpi_value value;
      vpiHandle range;
      if (strcmp(group->member_name, "vec_words") == 0) {
            want_left = 3; want_right = 5;
      } else if (strcmp(group->member_name, "real_words") == 0) {
            want_left = 6; want_right = 4;
      } else if (strcmp(group->member_name, "string_words") == 0) {
            want_left = 2; want_right = 4;
      } else {
            want_left = 5; want_right = 3;
      }
      if (vpi_get(vpiArrayType, array) != vpiStaticArray ||
          vpi_get(vpiSize, array) != 3) {
            vpi_printf("FAILED fixed shape %s type=%d size=%d\n", path,
                       vpi_get(vpiArrayType, array), vpi_get(vpiSize, array));
            failures += 1;
      }
      value.format = vpiIntVal;
      range = vpi_handle(vpiLeftRange, array);
      if (range) vpi_get_value(range, &value);
      if (!range || value.value.integer != want_left) {
            vpi_printf("FAILED fixed left range %s got=%d want=%d\n", path,
                       range ? value.value.integer : -999, want_left);
            failures += 1;
      }
      value.format = vpiIntVal;
      range = vpi_handle(vpiRightRange, array);
      if (range) vpi_get_value(range, &value);
      if (!range || value.value.integer != want_right) {
            vpi_printf("FAILED fixed right range %s got=%d want=%d\n", path,
                       range ? value.value.integer : -999, want_right);
            failures += 1;
      }
}

static void register_group_view(struct watch_group*group, unsigned view_index,
                                const char*view)
{
      struct subscription*sub =
            &subscriptions[(group - groups) * 3 + view_index];
      char path[256];
      s_cb_data callback_data;

      memset(sub, 0, sizeof *sub);
      sub->group = group;
      sub->view = view;
      sub->last_index = -999;
      if (view_index == 0) {
            snprintf(path, sizeof path, "%s", group->direct_path);
      } else {
            snprintf(path, sizeof path, "top.%s.%s", view,
                     group->member_name);
      }
      sub->object = find_handle(path);
      if (!sub->object)
            return;
      if (group->word_index >= 0) {
	    check_fixed_shape(sub->object, group, path);
            sub->object = vpi_handle_by_index(sub->object, group->word_index);
            if (!sub->object) {
                  vpi_printf("FAILED missing VPI word %s[%d]\n", path,
                             group->word_index);
                  failures += 1;
                  return;
            }
	    if (vpi_get(vpiIndex, sub->object) != group->word_index) {
		  vpi_printf("FAILED fixed word index %s got=%d want=%d\n",
			     path, vpi_get(vpiIndex, sub->object),
			     group->word_index);
		  failures += 1;
	    }
      }

      memset(&sub->time, 0, sizeof sub->time);
      sub->time.type = vpiSuppressTime;
      memset(&sub->value, 0, sizeof sub->value);
      sub->value.format = group->kind == KIND_VEC ? vpiVectorVal
                        : group->kind == KIND_REAL ? vpiRealVal
                        : group->kind == KIND_STRING ? vpiStringVal
                        : vpiSuppressVal;
      memset(&callback_data, 0, sizeof callback_data);
      callback_data.reason = cbValueChange;
      callback_data.cb_rtn = changed_cb;
      callback_data.obj = sub->object;
      callback_data.time = &sub->time;
      callback_data.value = &sub->value;
      callback_data.user_data = (PLI_BYTE8*)sub;
      sub->callback = vpi_register_cb(&callback_data);
      if (!sub->callback)
            fail("callback registration returned null", group->name);
}

static PLI_INT32 setup_calltf(PLI_BYTE8*user_data)
{
      unsigned idx;
      (void)user_data;
      for (idx = 0; idx < GROUP_COUNT; idx += 1) {
            register_group_view(&groups[idx], 0, "direct");
            register_group_view(&groups[idx], 1, "view_a");
            register_group_view(&groups[idx], 2, "view_b");
      }
      return 0;
}

static void put_group(struct watch_group*group)
{
      struct subscription*sub =
            &subscriptions[(group - groups) * 3 + 1];
      s_vpi_value value;
      s_vpi_vecval vector;
      if (!sub->object)
            return;
      memset(&value, 0, sizeof value);
      if (group->kind == KIND_VEC) {
            vector.aval = group->want_aval;
            vector.bval = group->want_bval;
            value.format = vpiVectorVal;
            value.value.vector = &vector;
      } else if (group->kind == KIND_REAL) {
            value.format = vpiRealVal;
            value.value.real = group->want_real;
      } else if (group->kind == KIND_STRING) {
            value.format = vpiStringVal;
            value.value.str = (PLI_BYTE8*)group->want_string;
      } else {
	    s_vpi_value before;
	    s_vpi_value after;
	    s_vpi_value rejected;
	    memset(&before, 0, sizeof before);
	    before.format = vpiObjTypeVal;
	    vpi_get_value(sub->object, &before);
	    memset(&rejected, 0, sizeof rejected);
	    rejected.format = vpiIntVal;
	    rejected.value.integer = 7;
	    vpi_put_value(sub->object, &rejected, 0, vpiNoDelay);
	    memset(&after, 0, sizeof after);
	    after.format = vpiObjTypeVal;
	    vpi_get_value(sub->object, &after);
	    if (after.value.misc != before.value.misc)
		  fail("rejected nonzero integer mutated object storage",
		       group->name);
            value.format = vpiIntVal;
            value.value.integer = 0;
      }
      vpi_put_value(sub->object, &value, 0, vpiNoDelay);
}

static void put_vector_path(const char*path, PLI_UINT32 aval,
                            PLI_UINT32 bval)
{
      vpiHandle handle = find_handle(path);
      s_vpi_vecval vector;
      s_vpi_value value;
      if (!handle)
            return;
      vector.aval = aval;
      vector.bval = bval;
      value.format = vpiVectorVal;
      value.value.vector = &vector;
      vpi_put_value(handle, &value, 0, vpiNoDelay);
}

static void put_vector_element(const char*path, int index, PLI_UINT32 aval,
			       PLI_UINT32 bval)
{
      vpiHandle array = find_handle(path);
      vpiHandle element = array ? vpi_handle_by_index(array, index) : 0;
      s_vpi_vecval vector;
      s_vpi_value value;
      if (!element) {
	    if (array) {
		  vpi_printf("FAILED missing VPI element %s[%d]\n", path, index);
		  failures += 1;
	    }
	    return;
      }
      vector.aval = aval;
      vector.bval = bval;
      value.format = vpiVectorVal;
      value.value.vector = &vector;
      vpi_put_value(element, &value, 0, vpiNoDelay);
}

static PLI_INT32 write_calltf(PLI_BYTE8*user_data)
{
      unsigned idx;
      vpiHandle scalar;
      s_vpi_value value;
      (void)user_data;
      for (idx = 0; idx < GROUP_COUNT; idx += 1)
            if (groups[idx].writes_value)
                  put_group(&groups[idx]);

      // These controls reach the two historical four-state decode paths
      // directly: non-static class member and runtime darray word.
      put_vector_path("top.view_a.instance_vec", 0x5a, 0x0f);
      put_vector_element("top.view_a.dynamic_four", 0, 0xc3, 0x0f);

      scalar = find_handle("top.view_a.instance_scalar");
      if (scalar) {
            memset(&value, 0, sizeof value);
            value.format = vpiScalarVal;
            value.value.scalar = vpiX;
            vpi_put_value(scalar, &value, 0, vpiNoDelay);
            value.value.scalar = vpiZ;
            vpi_put_value(scalar, &value, 0, vpiNoDelay);
      }

      // Declared base and nested-base views must not select derived.hidden.
      value.format = vpiIntVal;
      value.value.integer = 0x91;
      vpi_put_value(find_handle("top.base_view.hidden"), &value, 0,
                    vpiNoDelay);
      value.value.integer = 0xa2;
      vpi_put_value(find_handle("top.derived_object.hidden"), &value, 0,
                    vpiNoDelay);
      if (find_handle("top.holder.nested.hidden")) {
            s_vpi_value read_value;
            read_value.format = vpiIntVal;
            vpi_get_value(find_handle("top.holder.nested.hidden"),
                          &read_value);
            if (read_value.value.integer != 0x91)
                  fail("nested base view selected derived hidden property",
                       "nested-hidden");
      }
      return 0;
}

static void check_subscription(struct subscription*sub)
{
      struct watch_group*group = sub->group;
      if (!sub->object)
            return;
      if (sub->count != 2) {
            vpi_printf("FAILED %s/%s callback count=%d want=2\n",
                       group->name, sub->view, sub->count);
            failures += 1;
      }
      if (group->word_index == WHOLE_ARRAY &&
          sub->last_index != groups[(group - groups) + 1].word_index) {
            vpi_printf("FAILED %s/%s changed index=%d\n", group->name,
                       sub->view, sub->last_index);
            failures += 1;
      }
      if (group->kind == KIND_VEC &&
          ((sub->last_aval & 0xffU) != group->want_aval ||
           (sub->last_bval & 0xffU) != group->want_bval)) {
            vpi_printf("FAILED %s/%s payload aval=%02x bval=%02x\n",
                       group->name, sub->view, (unsigned)sub->last_aval,
                       (unsigned)sub->last_bval);
            failures += 1;
      } else if (group->kind == KIND_REAL &&
                 fabs(sub->last_real - group->want_real) > 1e-9) {
            fail("real callback payload mismatch", group->name);
      } else if (group->kind == KIND_STRING &&
                 strcmp(sub->last_string, group->want_string) != 0) {
            fail("string callback payload mismatch", group->name);
      }
}

static PLI_INT32 check_calltf(PLI_BYTE8*user_data)
{
      unsigned idx;
      vpiHandle result;
      s_vpi_value value;
      (void)user_data;
      for (idx = 0; idx < GROUP_COUNT * 3; idx += 1)
            check_subscription(&subscriptions[idx]);
      result = find_handle("top.vpi_failures");
      if (result) {
            value.format = vpiIntVal;
            value.value.integer = failures;
            vpi_put_value(result, &value, 0, vpiNoDelay);
      }
      return 0;
}

static void register_tasks(void)
{
      s_vpi_systf_data task;
      memset(&task, 0, sizeof task);
      task.type = vpiSysTask;
      task.tfname = "$static_storage_cb_setup";
      task.calltf = setup_calltf;
      vpi_register_systf(&task);
      task.tfname = "$static_storage_cb_write";
      task.calltf = write_calltf;
      vpi_register_systf(&task);
      task.tfname = "$static_storage_cb_check";
      task.calltf = check_calltf;
      vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
