/* IEEE 1800-2023 17.3: a procedural checker instance's static assertions are
   placed at the instance; its module-scope copy of the checker contents has
   none of its own. List every registered assertion, sorted. */
#include <stdlib.h>
#include <string.h>
#include <vpi_user.h>
#include <sv_vpi_user.h>

static int by_name(const void *a, const void *b)
{
      return strcmp(*(char *const *)a, *(char *const *)b);
}

static PLI_INT32 list_calltf(PLI_BYTE8 *name)
{
      char *names[64];
      int count = 0, idx, copies = 0;
      vpiHandle iterator, assertion, args, arg;
      s_vpi_value expected;
      (void)name;
      expected.format = vpiIntVal;
      expected.value.integer = -1;
      args = vpi_iterate(vpiArgument, vpi_handle(vpiSysTfCall, 0));
      if (args && (arg = vpi_scan(args))) {
            vpi_get_value(arg, &expected);
            vpi_free_object(args);
      }
      iterator = vpi_iterate(vpiAssertion, 0);
      while (iterator && (assertion = vpi_scan(iterator)))
            if (count < 64)
                  names[count++] = strdup(vpi_get_str(vpiFullName, assertion));
      qsort(names, count, sizeof names[0], by_name);
      for (idx = 0 ; idx < count ; idx += 1) {
            vpi_printf("assertion %s\n", names[idx]);
            if (strstr(names[idx], "_ivl_pchk")) copies += 1;
            free(names[idx]);
      }
      vpi_printf("assertions=%d\n", count);
      if (count == expected.value.integer && copies == 0)
            vpi_printf("PASSED\n");
      else
            vpi_printf("FAILED: expected %d assertions, none in a "
                       "procedural instance's copy\n",
                       (int)expected.value.integer);
      return 0;
}

static void register_tasks(void)
{
      s_vpi_systf_data task;
      task.type = vpiSysTask;
      task.tfname = "$list_assertions";
      task.calltf = list_calltf;
      task.compiletf = 0;
      task.sizetf = 0;
      task.user_data = 0;
      vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
