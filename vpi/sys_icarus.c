/*
 *  Copyright (C) 2008-2025  Cary R. (cygcary@yahoo.com)
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
 */

#include "sys_priv.h"
#include <assert.h>
#include <stdlib.h>
#include <string.h>

static PLI_INT32 finish_and_return_calltf(ICARUS_VPI_CONST PLI_BYTE8* name)
{
    vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
    vpiHandle argv = vpi_iterate(vpiArgument, callh);
    vpiHandle arg;
    s_vpi_value val;
    (void) name;  /* Not used! */

    /* Get the return value. */
    arg = vpi_scan(argv);
    vpi_free_object(argv);
    val.format = vpiIntVal;
    vpi_get_value(arg, &val);

    /* Set the return value. */
    vpip_set_return_value(val.value.integer);

    /* Now finish. */
    vpi_control(vpiFinish, 1);
    return 0;
}

/* PLA modeling tasks (IEEE 1800-2017 20.17 / 1800-2023 20.16). */
typedef struct pla_task_s {
      vpiHandle memory;
      vpiHandle input;
      vpiHandle output;
      PLI_INT32 mem_left, mem_right;
      unsigned input_width, output_width;
      unsigned is_async, is_plane, is_and, invert;
      vpiHandle *words;
      unsigned word_count;
      vpiHandle *callbacks;
      unsigned callback_count;
      struct pla_task_s *next;
} pla_task_t;

static pla_task_t *pla_tasks;

static unsigned pla_bit(const s_vpi_vecval *vec, unsigned bit)
{
      unsigned word = bit / 32;
      unsigned offset = bit % 32;
      unsigned a = (vec[word].aval >> offset) & 1;
      unsigned b = (vec[word].bval >> offset) & 1;
      return b ? (a ? 2 : 3) : a;
}

static void pla_set_bit(s_vpi_vecval *vec, unsigned bit, unsigned value)
{
      unsigned word = bit / 32;
      unsigned offset = bit % 32;
      unsigned mask = 1u << offset;
      if (value == 1 || value == 2 || value == 3) vec[word].aval |= mask;
      if (value == 2 || value == 3) vec[word].bval |= mask;
}

static unsigned pla_logic(pla_task_t *task, unsigned row)
{
      s_vpi_value input_value, word_value;
      unsigned vec_words = (task->input_width + 31) / 32;
      s_vpi_vecval *input_vec = calloc(vec_words, sizeof(*input_vec));
      s_vpi_vecval *word_vec = calloc(vec_words, sizeof(*word_vec));
      unsigned result = task->is_and ? 1 : 0;
      unsigned col;
      if (!input_vec || !word_vec) {
            free(input_vec); free(word_vec); return 2;
      }
      word_value.format = vpiVectorVal;
      vpi_get_value(task->words[row], &word_value);
      memcpy(word_vec, word_value.value.vector, vec_words * sizeof(*word_vec));
      input_value.format = vpiVectorVal;
      vpi_get_value(task->input, &input_value);
      memcpy(input_vec, input_value.value.vector, vec_words * sizeof(*input_vec));
      for (col = 0; col < task->input_width; col += 1) {
            unsigned input_bit = pla_bit(input_vec,
                                          task->input_width - col - 1);
            unsigned personality = pla_bit(word_vec,
                                            task->input_width - col - 1);
            unsigned term;
            if (task->is_plane) {
                  if (personality == 3) continue; /* z: don't-care */
                  if (personality == 2) term = 2; /* x: worst case */
                  else if (personality == 1) term = input_bit;
                  else term = input_bit < 2 ? input_bit ^ 1 : 2;
            } else {
                  if (personality == 0) continue;
                  term = input_bit;
            }
            if (term == 3) term = 2;
            if (task->is_and) {
                  if (term == 0) result = 0;
                  else if (term == 2 && result != 0) result = 2;
                  else if (result == 1) result = term;
            } else {
                  if (term == 1) result = 1;
                  else if (term == 2 && result != 1) result = 2;
                  else if (result == 0) result = term;
            }
      }
      if (task->invert) {
            if (result < 2) result ^= 1;
            else result = 2;
      }
      free(input_vec); free(word_vec);
      return result;
}

static void pla_evaluate(pla_task_t *task)
{
      unsigned words = (task->output_width + 31) / 32;
      s_vpi_vecval *vec = calloc(words, sizeof(*vec));
      s_vpi_value value;
      unsigned row;
      if (!vec) return;
      for (row = 0; row < task->word_count && row < task->output_width; row += 1)
      {
            unsigned result = pla_logic(task, row);
            pla_set_bit(vec, task->output_width - row - 1, result);
      }
      value.format = vpiVectorVal;
      value.value.vector = vec;
      vpi_put_value(task->output, &value, 0, vpiNoDelay);
      free(vec);
}

static PLI_INT32 pla_value_change(p_cb_data cb)
{
      pla_evaluate((pla_task_t *)cb->user_data);
      return 0;
}

static PLI_INT32 pla_end_simulation(p_cb_data cb)
{
      pla_task_t *task = (pla_task_t *)cb->user_data;
      pla_task_t **link = &pla_tasks;
      unsigned idx;
      while (*link && *link != task) link = &(*link)->next;
      if (*link) *link = task->next;
      for (idx = 0; idx < task->callback_count; idx += 1)
            if (task->callbacks[idx]) vpi_remove_cb(task->callbacks[idx]);
      free(task->callbacks);
      free(task->words);
      free(task);
      return 0;
}

static PLI_INT32 pla_compiletf(ICARUS_VPI_CONST PLI_BYTE8* name)
{
      (void)name;
      return 0;
}

static PLI_INT32 pla_calltf(ICARUS_VPI_CONST PLI_BYTE8* name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle args = vpi_iterate(vpiArgument, callh);
      vpiHandle arg[3];
      pla_task_t *task;
      unsigned idx = 0, callbacks = 0;
      PLI_INT32 first, step;
      s_cb_data cb;
      if (!args) return 0;
      while (idx < 3 && (arg[idx] = vpi_scan(args)) != 0) idx += 1;
      vpi_free_object(args);
      if (idx != 3 || vpi_get(vpiType, arg[0]) != vpiMemory) {
            vpi_printf("ERROR: %s:%d: %s requires a memory, input expression, and output variable.\n",
                       vpi_get_str(vpiFile, callh), (int)vpi_get(vpiLineNo, callh), name);
            vpip_set_return_value(1);
            vpi_control(vpiFinish, 1);
            return 0;
      }
      task = calloc(1, sizeof(*task));
      if (!task) return 0;
      task->memory = arg[0]; task->input = arg[1]; task->output = arg[2];
      task->input_width = vpi_get(vpiSize, arg[1]);
      task->output_width = vpi_get(vpiSize, arg[2]);
      {
            s_vpi_value range_value;
            range_value.format = vpiIntVal;
            vpi_get_value(vpi_handle(vpiLeftRange, arg[0]), &range_value);
            task->mem_left = range_value.value.integer;
            vpi_get_value(vpi_handle(vpiRightRange, arg[0]), &range_value);
            task->mem_right = range_value.value.integer;
      }
      step = task->mem_left <= task->mem_right ? 1 : -1;
      task->word_count = (unsigned)(task->mem_left <= task->mem_right ?
                                    task->mem_right - task->mem_left + 1 :
                                    task->mem_left - task->mem_right + 1);
      task->words = calloc(task->word_count, sizeof(*task->words));
      task->is_async = strstr(name, "$async$") != 0;
      task->is_plane = strstr(name, "$plane") != 0;
      task->is_and = strstr(name, "$and$") || strstr(name, "$nand$");
      task->invert = strstr(name, "$nand$") || strstr(name, "$nor$");
      for (idx = 0, first = task->mem_left; idx < task->word_count; idx += 1, first += step)
            task->words[idx] = vpi_handle_by_index(task->memory, first);
      for (idx = 0; idx < task->word_count; idx += 1) {
            if (!task->words[idx]) {
                  vpi_printf("ERROR: %s:%d: %s could not access a personality word.\n",
                             vpi_get_str(vpiFile, callh), (int)vpi_get(vpiLineNo, callh), name);
                  vpip_set_return_value(1);
                  vpi_control(vpiFinish, 1);
                  free(task->words); free(task); return 0;
            }
      }
      if (!task->input_width || !task->output_width ||
          task->input_width != (unsigned)vpi_get(vpiSize, task->words[0]) ||
          task->word_count != task->output_width) {
            vpi_printf("ERROR: %s:%d: %s memory dimensions must match input and output widths.\n",
                       vpi_get_str(vpiFile, callh), (int)vpi_get(vpiLineNo, callh), name);
            vpip_set_return_value(1);
            vpi_control(vpiFinish, 1);
            free(task->words);
            free(task);
            return 0;
      }
      if (task->is_async) {
            task->callbacks = calloc(task->word_count + 2, sizeof(*task->callbacks));
            memset(&cb, 0, sizeof(cb));
            cb.reason = cbValueChange; cb.cb_rtn = pla_value_change;
            cb.user_data = (PLI_BYTE8 *)task;
            cb.obj = task->input;
            task->callbacks[callbacks++] = vpi_register_cb(&cb);
            for (idx = 0; idx < task->word_count; idx += 1) {
                  cb.obj = task->words[idx];
                  task->callbacks[callbacks++] = vpi_register_cb(&cb);
            }
            memset(&cb, 0, sizeof(cb));
            cb.reason = cbEndOfSimulation; cb.cb_rtn = pla_end_simulation;
            cb.user_data = (PLI_BYTE8 *)task;
            task->callbacks[callbacks++] = vpi_register_cb(&cb);
            task->callback_count = callbacks;
            task->next = pla_tasks; pla_tasks = task;
      }
      pla_evaluate(task);
      if (!task->is_async) {
            free(task->words);
            free(task);
      }
      return 0;
}

/*
 * Implement $system(cmd) — execute a shell command and return its status.
 */
static PLI_INT32 system_calltf(ICARUS_VPI_CONST PLI_BYTE8* name)
{
      (void)name;
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv = vpi_iterate(vpiArgument, callh);
      const char *cmd = NULL;
      int ret;
      if (argv) {
	    vpiHandle arg = vpi_scan(argv);
	    if (arg) {
		  s_vpi_value val;
		  val.format = vpiStringVal;
		  vpi_get_value(arg, &val);
		  cmd = val.value.str;
	    }
      }
      /* A missing argument passes NULL to C system(), per IEEE 1800. */
      ret = system(cmd);
      if (argv) vpi_free_object(argv);
      put_integer_value(callh, ret);
      return 0;
}

/*
 * This is used to warn the user that the specified optional system
 * task/function is not available (from Annex C 1364-2005).
 */
static PLI_INT32 missing_optional_compiletf(ICARUS_VPI_CONST PLI_BYTE8* name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);

      vpi_printf("SORRY: %s:%d: %s() is not available in Icarus Verilog.\n",
                 vpi_get_str(vpiFile, callh), (int)vpi_get(vpiLineNo, callh),
                 name);
      vpip_set_return_value(1);
      vpi_control(vpiFinish, 1);
      return 0;
}

/*
 * Register the function with Verilog.
 */
void sys_special_register(void)
{
      s_vpi_systf_data tf_data;
      vpiHandle res;

      tf_data.type        = vpiSysTask;
      tf_data.calltf      = finish_and_return_calltf;
      tf_data.compiletf   = sys_one_numeric_arg_compiletf;
      tf_data.sizetf      = 0;
      tf_data.tfname      = "$finish_and_return";
      tf_data.user_data   = "$finish_and_return";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

	/* Register the IEEE programmable logic array tasks. */
      tf_data.type        = vpiSysTask;
      tf_data.calltf      = pla_calltf;
      tf_data.sizetf      = 0;
      tf_data.compiletf   = pla_compiletf;

      tf_data.tfname      = "$async$and$array";
      tf_data.user_data   = "$async$and$array";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$async$nand$array";
      tf_data.user_data   = "$async$nand$array";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$async$or$array";
      tf_data.user_data   = "$async$or$array";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$async$nor$array";
      tf_data.user_data   = "$async$nor$array";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$async$and$plane";
      tf_data.user_data   = "$async$and$plane";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$async$nand$plane";
      tf_data.user_data   = "$async$nand$plane";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$async$or$plane";
      tf_data.user_data   = "$async$or$plane";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$async$nor$plane";
      tf_data.user_data   = "$async$nor$plane";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$sync$and$array";
      tf_data.user_data   = "$sync$and$array";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$sync$nand$array";
      tf_data.user_data   = "$sync$nand$array";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$sync$or$array";
      tf_data.user_data   = "$sync$or$array";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$sync$nor$array";
      tf_data.user_data   = "$sync$nor$array";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$sync$and$plane";
      tf_data.user_data   = "$sync$and$plane";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$sync$nand$plane";
      tf_data.user_data   = "$sync$nand$plane";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$sync$or$plane";
      tf_data.user_data   = "$sync$or$plane";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$sync$nor$plane";
      tf_data.user_data   = "$sync$nor$plane";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

	/* The following optional system tasks/functions are not implemented
	 * in Icarus Verilog (from Annex C 1364-2005). */
      tf_data.type        = vpiSysTask;
      tf_data.calltf      = 0;
      tf_data.sizetf      = 0;
      tf_data.compiletf   = missing_optional_compiletf;

      tf_data.tfname      = "$input";
      tf_data.user_data   = "$input";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$key";
      tf_data.user_data   = "$key";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$nokey";
      tf_data.user_data   = "$nokey";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$list";
      tf_data.user_data   = "$list";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$log";
      tf_data.user_data   = "$log";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$nolog";
      tf_data.user_data   = "$nolog";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$save";
      tf_data.user_data   = "$save";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$restart";
      tf_data.user_data   = "$restart";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$incsave";
      tf_data.user_data   = "$incsave";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$scope";
      tf_data.user_data   = "$scope";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$showscopes";
      tf_data.user_data   = "$showscopes";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$showvars";
      tf_data.user_data   = "$showvars";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$sreadmemb";
      tf_data.user_data   = "$sreadmemb";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$sreadmemh";
      tf_data.user_data   = "$sreadmemh";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

	/* Optional functions. */
      tf_data.type = vpiSysFunc;
      tf_data.sysfunctype = vpiIntFunc;

      tf_data.tfname      = "$getpattern";
      tf_data.user_data   = "$getpattern";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.tfname      = "$scale";
      tf_data.user_data   = "$scale";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      /* $system(cmd) — execute a shell command, return exit status. */
      tf_data.type        = vpiSysFunc;
      tf_data.sysfunctype = vpiIntFunc;
      tf_data.calltf      = system_calltf;
      tf_data.compiletf   = 0;
      tf_data.sizetf      = 0;
      tf_data.tfname      = "$system";
      tf_data.user_data   = "$system";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);
}
