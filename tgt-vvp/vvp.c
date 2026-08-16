#define COPYRIGHT \
  "Copyright (c) 2001-2026 Stephen Williams (steve@icarus.com)"
/*
 *    This source code is free software; you can redistribute it
 *    and/or modify it in source code form under the terms of the GNU
 *    General Public License as published by the Free Software
 *    Foundation; either version 2 of the License, or (at your option)
 *    any later version.
 *
 *    This program is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with this program; if not, write to the Free Software
 *    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

# include  "version_base.h"
# include  "version_tag.h"
# include  "vvp_priv.h"
# include  <string.h>
# include  <assert.h>
# include  <stdlib.h>
# include  <sys/types.h>
# include  <sys/stat.h>
# include  <signal.h>
# include  <stdint.h>

static const char*version_string =
"Icarus Verilog VVP Code Generator " VERSION " (" VERSION_TAG ")\n\n"
COPYRIGHT "\n\n"
"  This program is free software; you can redistribute it and/or modify\n"
"  it under the terms of the GNU General Public License as published by\n"
"  the Free Software Foundation; either version 2 of the License, or\n"
"  (at your option) any later version.\n"
"\n"
"  This program is distributed in the hope that it will be useful,\n"
"  but WITHOUT ANY WARRANTY; without even the implied warranty of\n"
"  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\n"
"  GNU General Public License for more details.\n"
"\n"
"  You should have received a copy of the GNU General Public License along\n"
"  with this program; if not, write to the Free Software Foundation, Inc.,\n"
"  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.\n"
;

FILE*vvp_out = 0;
int vvp_errors = 0;
unsigned show_file_line = 0;

int debug_draw = 0;

static ivl_design_t saved_design = NULL;

/* Normal INITIAL processes all enter the Active region at time zero. The
 * standard deliberately leaves their relative execution order unspecified,
 * but a deterministic lexical order is both legal and important for source
 * compatibility. In particular, OpenTitan initializes a simulation-only
 * value in a module-level INITIAL and checks it from a later generate scope.
 *
 * The core/dll handoff reverses the process list, which used to put generate
 * INITIAL processes ahead of earlier module-level INITIAL processes. Collect
 * the target processes and restore source-line order for normal INITIALs from
 * the same source file and containing module instance. Pre-simulation static
 * initializers keep their existing, separately constrained order.
 */
struct process_list_s {
      ivl_process_t*items;
      size_t count;
      size_t capacity;
};

static int collect_process(ivl_process_t net, void*data)
{
      struct process_list_s*list = (struct process_list_s*)data;
      if (list->count == list->capacity) {
            size_t new_capacity = list->capacity ? 2 * list->capacity : 256;
            ivl_process_t*new_items = (ivl_process_t*)realloc(
                  list->items, new_capacity * sizeof(ivl_process_t));
            assert(new_items);
            list->items = new_items;
            list->capacity = new_capacity;
      }
      list->items[list->count++] = net;
      return 0;
}

static int process_is_normal_initial(ivl_process_t net)
{
      unsigned idx;
      if (ivl_process_type(net) != IVL_PR_INITIAL)
            return 0;

      for (idx = 0; idx < ivl_process_attr_cnt(net); idx += 1) {
            ivl_attribute_t attr = ivl_process_attr_val(net, idx);
            if (strcmp(attr->key, "_ivl_schedule_init") == 0)
                  return 0;
      }
      return 1;
}

static ivl_scope_t process_containing_module(ivl_process_t net)
{
      ivl_scope_t scope = ivl_process_scope(net);
      while (scope && ivl_scope_type(scope) != IVL_SCT_MODULE)
            scope = ivl_scope_parent(scope);
      return scope;
}

struct lexical_process_s {
      ivl_process_t process;
      ivl_scope_t module;
      const char*file;
      unsigned line;
      size_t position;
};

static int compare_lexical_group(const struct lexical_process_s*left,
                                 const struct lexical_process_s*right)
{
      /* uintptr_t gives qsort a total order without relational comparison
       * between unrelated opaque scope pointers. */
      uintptr_t left_module = (uintptr_t)left->module;
      uintptr_t right_module = (uintptr_t)right->module;
      if (left_module < right_module) return -1;
      if (left_module > right_module) return 1;
      return strcmp(left->file, right->file);
}

static int compare_lexical_line(const void*left_arg, const void*right_arg)
{
      const struct lexical_process_s*left =
            (const struct lexical_process_s*)left_arg;
      const struct lexical_process_s*right =
            (const struct lexical_process_s*)right_arg;
      int group_cmp = compare_lexical_group(left, right);
      if (group_cmp) return group_cmp;
      if (left->line < right->line) return -1;
      if (left->line > right->line) return 1;
      if (left->position < right->position) return -1;
      if (left->position > right->position) return 1;
      return 0;
}

static int compare_lexical_position(const void*left_arg, const void*right_arg)
{
      const struct lexical_process_s*left =
            (const struct lexical_process_s*)left_arg;
      const struct lexical_process_s*right =
            (const struct lexical_process_s*)right_arg;
      int group_cmp = compare_lexical_group(left, right);
      if (group_cmp) return group_cmp;
      if (left->position < right->position) return -1;
      if (left->position > right->position) return 1;
      return 0;
}

static void order_normal_initials_lexically(struct process_list_s*list)
{
      struct lexical_process_s*by_line;
      struct lexical_process_s*by_position;
      size_t eligible_count = 0;
      size_t idx;

      if (list->count < 2)
            return;

      by_line = (struct lexical_process_s*)malloc(
            list->count * sizeof(struct lexical_process_s));
      assert(by_line);

      for (idx = 0; idx < list->count; idx += 1) {
            ivl_process_t process = list->items[idx];
            ivl_scope_t module;
            const char*file;
            unsigned line;
            if (!process_is_normal_initial(process))
                  continue;
            module = process_containing_module(process);
            file = ivl_process_file(process);
            line = ivl_process_lineno(process);
            if (!module || ivl_scope_program(module) || !file || line == 0)
                  continue;
            by_line[eligible_count].process = process;
            by_line[eligible_count].module = module;
            by_line[eligible_count].file = file;
            by_line[eligible_count].line = line;
            by_line[eligible_count].position = idx;
            eligible_count += 1;
      }

      if (eligible_count < 2) {
            free(by_line);
            return;
      }

      by_position = (struct lexical_process_s*)malloc(
            eligible_count * sizeof(struct lexical_process_s));
      assert(by_position);
      memcpy(by_position, by_line,
             eligible_count * sizeof(struct lexical_process_s));

      qsort(by_line, eligible_count, sizeof(struct lexical_process_s),
            compare_lexical_line);
      qsort(by_position, eligible_count, sizeof(struct lexical_process_s),
            compare_lexical_position);

      for (idx = 0; idx < eligible_count; idx += 1) {
            assert(compare_lexical_group(&by_line[idx], &by_position[idx]) == 0);
            list->items[by_position[idx].position] = by_line[idx].process;
      }

      free(by_position);
      free(by_line);
}

/* IEEE 1800 deliberately leaves the order of evaluation events within the
 * Active region unspecified. Choose a deterministic hierarchy-ready order
 * for ordinary time-zero processes: an instantiated interface gets a chance
 * to arm event controls before the containing module can call its startup
 * methods. This is a compatibility policy, not an additional event region or
 * an IEEE-mandated precedence rule.
 *
 * Keep pre-simulation static initializers out of this ordering, just as the
 * lexical pass above does. Within each category retain the process order
 * already established by elaboration and the lexical pass.
 */
struct hierarchy_process_s {
      ivl_process_t process;
      ivl_scope_t module;
      size_t position;
      int in_interface;
};

static int process_is_in_interface(ivl_process_t net)
{
      ivl_scope_t scope = ivl_process_scope(net);
      while (scope) {
            if (ivl_scope_type(scope) == IVL_SCT_MODULE)
                  return ivl_scope_is_interface(scope) ? 1 : 0;
            scope = ivl_scope_parent(scope);
      }
      return 0;
}

static ivl_scope_t process_containing_design_module(ivl_process_t net)
{
      ivl_scope_t scope = ivl_process_scope(net);
      while (scope) {
            if (ivl_scope_type(scope) == IVL_SCT_MODULE
                && !ivl_scope_is_interface(scope))
                  return scope;
            scope = ivl_scope_parent(scope);
      }
      return NULL;
}

static int compare_hierarchy_position(const void*left_arg,
                                      const void*right_arg)
{
      const struct hierarchy_process_s*left =
            (const struct hierarchy_process_s*)left_arg;
      const struct hierarchy_process_s*right =
            (const struct hierarchy_process_s*)right_arg;
      uintptr_t left_module = (uintptr_t)left->module;
      uintptr_t right_module = (uintptr_t)right->module;
      if (left_module < right_module) return -1;
      if (left_module > right_module) return 1;
      if (left->position < right->position) return -1;
      if (left->position > right->position) return 1;
      return 0;
}

static void order_interface_initials_before_parent(struct process_list_s*list)
{
      struct hierarchy_process_s*by_position;
      struct hierarchy_process_s*partitioned;
      size_t eligible_count = 0;
      size_t idx;

      if (list->count < 2)
            return;

      by_position = (struct hierarchy_process_s*)malloc(
            list->count * sizeof(struct hierarchy_process_s));
      assert(by_position);

      for (idx = 0; idx < list->count; idx += 1) {
            ivl_process_t process = list->items[idx];
            ivl_scope_t module;
            if (!process_is_normal_initial(process))
                  continue;
            module = process_containing_design_module(process);
            if (!module || ivl_scope_program(module))
                  continue;
            by_position[eligible_count].process = process;
            by_position[eligible_count].module = module;
            by_position[eligible_count].position = idx;
            by_position[eligible_count].in_interface =
                  process_is_in_interface(process);
            eligible_count += 1;
      }

      if (eligible_count < 2) {
            free(by_position);
            return;
      }

      qsort(by_position, eligible_count, sizeof(struct hierarchy_process_s),
            compare_hierarchy_position);
      partitioned = (struct hierarchy_process_s*)malloc(
            eligible_count * sizeof(struct hierarchy_process_s));
      assert(partitioned);

      for (idx = 0; idx < eligible_count; ) {
            size_t end = idx + 1;
            size_t out = idx;
            size_t cur;
            while (end < eligible_count
                   && by_position[end].module == by_position[idx].module)
                  end += 1;

            for (cur = idx; cur < end; cur += 1)
                  if (by_position[cur].in_interface)
                        partitioned[out++] = by_position[cur];
            for (cur = idx; cur < end; cur += 1)
                  if (!by_position[cur].in_interface)
                        partitioned[out++] = by_position[cur];
            assert(out == end);

            for (cur = idx; cur < end; cur += 1)
                  list->items[by_position[cur].position] =
                        partitioned[cur].process;
            idx = end;
      }

      free(partitioned);
      free(by_position);
}

static int draw_processes(ivl_design_t des)
{
      struct process_list_s list = { 0, 0, 0 };
      size_t idx;
      int rc;

      rc = ivl_design_process(des, collect_process, &list);
      if (rc != 0) {
            free(list.items);
            return rc;
      }

      order_normal_initials_lexically(&list);
      order_interface_initials_before_parent(&list);
      for (idx = 0; idx < list.count; idx += 1) {
            rc = draw_process(list.items[idx], 0);
            if (rc != 0)
                  break;
      }
      free(list.items);
      return rc;
}

/* Accessor for tgt-vvp helpers that need design-wide scope navigation
 * (e.g. randomize() pre/post-hook lookup in eval_vec4.c). */
ivl_design_t vvp_get_saved_design(void) { return saved_design; }

static void segfault_handler(int sig)
{
      (void)sig;
      if (vvp_out && saved_design) {
            unsigned size, idx;
            // Flush any buffered content
            fflush(vvp_out);
            
            // Write the file name table that would normally be written after ivl_design_process
            size = ivl_file_table_size();
            fprintf(vvp_out, "# The file index is used to find the file name in "
                           "the following table.\n:file_names %u;\n", size);
            for (idx = 0; idx < size; idx++) {
                  fprintf(vvp_out, "    \"%s\";\n", ivl_file_table_item(idx));
            }
            fflush(vvp_out);
            fclose(vvp_out);
      }
      exit(0); // Exit cleanly with code 0 since code generation was successful
}

/* This needs to match the actual flag count in the VVP thread. */
# define FLAGS_COUNT 512

static uint32_t allocate_flag_mask[FLAGS_COUNT / 32] = { 0x000000ff, 0 };


__inline__ static void draw_execute_header(ivl_design_t des)
{
      const char*cp = ivl_design_flag(des, "VVP_EXECUTABLE");
      if (cp) {
	    const char *extra_args = ivl_design_flag(des, "VVP_EXTRA_ARGS");
	    if (!extra_args)
		  extra_args = "";
	    fprintf(vvp_out, "#! %s%s\n", cp, extra_args);
#if !defined(__MINGW32__)
	    fchmod(fileno(vvp_out), 0755);
#endif
      }
      fprintf(vvp_out, ":ivl_version \"" VERSION "\"");
	/* I am assuming that a base release will have a blank tag. */
      if (*VERSION_TAG != 0) {
	    fprintf(vvp_out, " \"(" VERSION_TAG ")\"");
      }
      fprintf(vvp_out, ";\n");
}

__inline__ static void draw_module_declarations(ivl_design_t des)
{
      const char*cp = ivl_design_flag(des, "VPI_MODULE_LIST");

      while (*cp) {
	    const char*comma = strchr(cp, ',');

	    if (comma == 0)
		  comma = cp + strlen(cp);

	    char*buffer = malloc(comma - cp + 1);
	    strncpy(buffer, cp, comma-cp);
	    buffer[comma-cp] = 0;
	    fprintf(vvp_out, ":vpi_module \"%s\";\n", buffer);
	    free(buffer);

	    cp = comma;
	    if (*cp) cp += 1;
      }
}

int allocate_flag(void)
{
      int idx;
      for (idx = 0 ; idx < FLAGS_COUNT ; idx += 1) {
	    int word = idx / 32;
	    uint32_t mask = 1U << (idx%32);
	    if (allocate_flag_mask[word] & mask)
		  continue;

	    allocate_flag_mask[word] |= mask;
	    return idx;
      }

      fprintf(stderr, "vvp.tgt error: Exceeded the maximum flag count of "
                      "%d during VVP code generation.\n", FLAGS_COUNT);
      exit(1);
}

void clr_flag(int idx)
{
      if (idx < 8) return;
      assert(idx < FLAGS_COUNT);
      int word = idx / 32;
      uint32_t mask = 1 << (idx%32);

      assert(allocate_flag_mask[word] & mask);

      allocate_flag_mask[word] &= ~mask;
}

static void process_debug_string(const char*debug_string)
{
      const char*cp = debug_string;
      debug_draw = 0;

      while (*cp) {
	    const char*tail = strchr(cp, ',');
	    if (tail == 0)
		  tail = cp + strlen(cp);

	    size_t len = tail - cp;
	    if (len == 4 && strncmp(cp,"draw", 4)==0) {
		  debug_draw = 1;
	    }

	    while (*tail == ',')
		  tail += 1;

	    cp = tail;
      }
}

int target_design(ivl_design_t des)

{
      int rc;
      ivl_scope_t *roots;
      unsigned nroots, i;
      unsigned size;
      unsigned idx;
      const char*path = ivl_design_flag(des, "-o");
	/* Use -pfileline to determine if file and line information is
	 * printed for procedural statements. (e.g. -pfileline=1).
	 * The default is no file/line information will be included. */
      const char*fileline = ivl_design_flag(des, "fileline");

      const char*debug_flags = ivl_design_flag(des, "debug_flags");
      process_debug_string(debug_flags);

      assert(path);

        /* Check to see if file/line information should be included. */
      if (strcmp(fileline, "") != 0) {
            char *eptr;
            long fl_value = strtol(fileline, &eptr, 0);
              /* Nothing usable in the file/line string. */
            if (fileline == eptr) {
                  fprintf(stderr, "vvp.tgt error: Unable to extract file/line "
                                  "information from string: %s\n", fileline);
                  return 1;
            }
              /* Extra stuff at the end. */
            if (*eptr != 0) {
                  fprintf(stderr, "vvp.tgt error: Extra characters '%s' "
                                  "included at end of file/line string: %s\n",
                                  eptr, fileline);
                  return 1;
            }
              /* The file/line flag must be positive. */
            if (fl_value < 0) {
                  fprintf(stderr, "vvp.tgt error: File/line flag (%ld) must "
                                  "be positive.\n", fl_value);
                  return 1;
            }
            show_file_line = fl_value > 0;
      }

#ifdef HAVE_FOPEN64
      vvp_out = fopen64(path, "w");
#else
      vvp_out = fopen(path, "w");
#endif
      if (vvp_out == 0) {
	    perror(path);
	    return -1;
      }

      vvp_errors = 0;
      
      // Keep default SIGSEGV behavior so sanitizer/backtrace tooling can
      // report real code generation crashes.
      saved_design = des;

      draw_execute_header(des);

      fprintf(vvp_out, ":ivl_delay_selection \"%s\";\n",
                       ivl_design_delay_sel(des));

      { int pre = ivl_design_time_precision(des);
	char sign = '+';
	if (pre < 0) {
	      pre = -pre;
	      sign = '-';
	}
	fprintf(vvp_out, ":vpi_time_precision %c %d;\n", sign, pre);
      }

      draw_module_declarations(des);

        /* This causes all structural records to be drawn. */
      reset_evcd_metadata_budget();
      ivl_design_roots(des, &roots, &nroots);
      for (i = 0; i < nroots; i++)
	    draw_scope(roots[i], 0);

        /* Finish up any modpaths that are not yet emitted. */
      cleanup_modpath();

      rc = draw_processes(des);

      emit_deferred_array_decls();

        /* Emit no-op TD stubs for referenced labels that were not
           materialized as function/task definitions. */
      emit_td_stub_definitions();

        /* DPI export (35.5): emit the runtime :export_dpi directives now
           that every TD_ label and port net has been drawn, and write the
           companion C stub file the DPI object links against. */
      emit_dpi_export_directives();
      emit_dpi_export_stub_file(path);

        /* Dump the file name table. */
      size = ivl_file_table_size();
      fprintf(vvp_out, "# The file index is used to find the file name in "
                       "the following table.\n:file_names %u;\n", size);
      for (idx = 0; idx < size; idx++) {
	    fprintf(vvp_out, "    \"%s\";\n", ivl_file_table_item(idx));
      }

      fclose(vvp_out);
      EOC_cleanup_drivers();

      return rc + vvp_errors;
}


const char* target_query(const char*key)
{
      if (strcmp(key,"version") == 0)
	    return version_string;

      return 0;
}
