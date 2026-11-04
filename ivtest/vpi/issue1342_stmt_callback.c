#include <vpi_user.h>

static s_vpi_time callback_time = { vpiSimTime, 0, 0, 0.0 };
static vpiHandle module_callback;
static vpiHandle loop_callback;
static unsigned statement_count;
static unsigned assignment_count;
static unsigned repeat_count;
static unsigned while_count;
static unsigned for_count;
static int failed;
static int removed;

static PLI_INT32 on_loop_stmt(p_cb_data cb)
{
      if (!cb || !cb->obj) {
	    failed = 1;
	    return 0;
      }

      switch (vpi_get(vpiType, cb->obj)) {
	  case vpiAssignment: assignment_count += 1; break;
	  case vpiRepeat: repeat_count += 1; break;
	  case vpiWhile: while_count += 1; break;
	  case vpiFor: for_count += 1; break;
	  default: break;
      }
      return 0;
}

static PLI_INT32 on_stmt(p_cb_data cb)
{
      static const int expected_types[] = {
	    vpiBegin, vpiAssignment, vpiDelayControl
      };
      vpiHandle x = vpi_handle_by_name((PLI_BYTE8*)"top.x", 0);
      s_vpi_value value = { vpiIntVal };

      if (!cb || !cb->obj || statement_count >= 3
	  || vpi_get(vpiType, cb->obj) != expected_types[statement_count]
	  || !cb->time || cb->time->type != vpiSimTime
	  || cb->time->high != 0 || cb->time->low != 0)
	    failed = 1;

      if (x) vpi_get_value(x, &value);
      if (!x || value.value.integer != (statement_count < 2 ? 0 : 1))
	    failed = 1;

      statement_count += 1;
      if (statement_count == 3) {
	    s_cb_data data = { 0 };
	    if (vpi_remove_cb(module_callback) != 1) failed = 1;
	    removed = 1;
	    data.reason = cbStmt;
	    data.cb_rtn = on_loop_stmt;
	    data.obj = vpi_handle_by_name((PLI_BYTE8*)"top", 0);
	    data.time = &callback_time;
	    loop_callback = vpi_register_cb(&data);
	    if (!loop_callback) failed = 1;
      }
      return 0;
}

static PLI_INT32 on_end(p_cb_data cb)
{
      vpiHandle x = vpi_handle_by_name((PLI_BYTE8*)"top.x", 0);
      vpiHandle i = vpi_handle_by_name((PLI_BYTE8*)"top.i", 0);
      s_vpi_value value = { vpiIntVal };
      s_vpi_value index = { vpiIntVal };
      if (x) vpi_get_value(x, &value);
      if (i) vpi_get_value(i, &index);
      if (!cb || statement_count != 3 || !removed || !x
	  || !loop_callback || value.value.integer != 4 || !i
	  || index.value.integer != 2 || assignment_count != 13
	  || repeat_count != 3 || while_count != 3 || for_count != 3)
	    failed = 1;
      vpi_printf("ISSUE1342 callbacks=%u removed=%d %s\n",
		 statement_count, removed,
		 failed ? "FAILED" : "PASSED");
      if (!failed) vpi_printf("PASSED\n");
      return 0;
}

static PLI_INT32 start(p_cb_data cb)
{
      s_cb_data data = { 0 };
      vpiHandle top = vpi_handle_by_name((PLI_BYTE8*)"top", 0);
      (void)cb;

      data.reason = cbStmt;
      data.cb_rtn = on_stmt;
      data.obj = top;
      data.time = &callback_time;
      module_callback = vpi_register_cb(&data);
      vpi_printf("MODULE_STMT_REGISTER=%s\n",
		 module_callback ? "non-null" : "null");
      if (!module_callback) failed = 1;
      return 0;
}

static void startup(void)
{
      s_cb_data cb = { 0 };
      cb.reason = cbStartOfSimulation;
      cb.cb_rtn = start;
      vpi_register_cb(&cb);

      cb.reason = cbEndOfSimulation;
      cb.cb_rtn = on_end;
      cb.time = &callback_time;
      vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = { startup, 0 };
