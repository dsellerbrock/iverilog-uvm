#include "vpi_user.h"
#include "sv_vpi_user.h"
#include <string.h>

/* Keep this regression buildable against an installed VPI header from
 * before these IEEE SystemVerilog constants were exposed by Icarus. */
#ifndef vpiClassObj
#define vpiClassObj 621
#endif
#ifndef vpiObjId
#define vpiObjId 660
#endif

static PLI_INT32 check_class_objects(p_cb_data data)
{
      (void)data;
      vpiHandle p = vpi_handle_by_name("top.p", 0);
      vpiHandle q = vpi_handle_by_name("top.q", 0);
      vpiHandle null_p = vpi_handle_by_name("top.null_p", 0);
      vpiHandle p_obj = p ? vpi_handle(vpiClassObj, p) : 0;
      vpiHandle q_obj = q ? vpi_handle(vpiClassObj, q) : 0;
      vpiHandle null_obj = null_p ? vpi_handle(vpiClassObj, null_p) : 0;
      vpiHandle declared_type = p ? vpi_handle(vpiClassTypespec, p) : 0;
      vpiHandle object_type = p_obj
                          ? vpi_handle(vpiClassTypespec, p_obj) : 0;
      char *object_type_name = object_type
                          ? vpi_get_str(vpiName, object_type) : 0;
      vpiHandle x = vpi_handle_by_name("top.p.x", 0);
      s_vpi_value value = { .format = vpiIntVal };
      if (x) vpi_get_value(x, &value);

      int64_t p_id = p ? vpi_get64(vpiObjId, p) : 0;
      int64_t p_obj_id = p_obj ? vpi_get64(vpiObjId, p_obj) : 0;
      int64_t q_id = q ? vpi_get64(vpiObjId, q) : 0;
      int64_t null_id = null_p ? vpi_get64(vpiObjId, null_p) : -1;

      if (p_obj && q_obj && !null_obj && p_id != 0
          && p_id == p_obj_id && q_id != 0 && q_id != p_id
          && null_id == 0 && x && value.value.integer == 7
          && vpi_get(vpiType, p_obj) == vpiClassObj
          && declared_type && object_type_name
          && strcmp(vpi_get_str(vpiName, declared_type), "Packet") == 0
          && strcmp(object_type_name, "Child") == 0) {
            vpi_printf("ISSUE1296 PASSED\nPASSED\n");
      } else {
            vpi_printf("ISSUE1296 FAIL p=%p p_obj=%p p_id=%lld p_obj_id=%lld "
                       "q_id=%lld null_obj=%p null_id=%lld x=%p xval=%d\n",
                       p, p_obj, (long long)p_id, (long long)p_obj_id,
                       (long long)q_id, null_obj, (long long)null_id,
                       x, x ? (int)value.value.integer : -1);
      }
      return 0;
}

static void register_callbacks(void)
{
      static s_vpi_time delay = { vpiSimTime, 0, 1, 0.0 };
      s_cb_data cb = {0};
      cb.reason = cbAfterDelay;
      cb.cb_rtn = check_class_objects;
      cb.time = &delay;
      vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = {
      register_callbacks,
      0
};
