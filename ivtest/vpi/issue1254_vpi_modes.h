/*
 * The body of the IEEE 1800-2023 36.12 compatibility-mode probe. Each
 * issue1254_vpi_mode_*.c file defines one VPI_COMPATIBILITY_VERSION_*
 * symbol and then includes this file, so the calls below are bound to that
 * mode's Annex L entry points.
 */
#include <stdio.h>
#include "vpi_user.h"

#ifndef vpi_get
#error "vpi_get was not remapped for the selected VPI compatibility mode"
#endif

static void show_iteration(PLI_INT32 type, const char*label, vpiHandle ref)
{
      vpiHandle iter = vpi_iterate(type, ref), item;
      vpi_printf("  %s:", label);
      if (iter) while ((item = vpi_scan(iter))) {
	    vpi_printf(" %s=%s", vpi_get_str(vpiName, item),
	               vpi_get_str(vpiType, item));
	    if (vpi_get(vpiArray, item)) vpi_printf("[]");
      }
      vpi_printf("\n");
}

static int count_iteration(PLI_INT32 type, vpiHandle ref)
{
      vpiHandle iter = vpi_iterate(type, ref);
      int count = 0;
      if (iter) while (vpi_scan(iter)) count += 1;
      return count;
}

static void probe_mode(const char*mode)
{
      static const char*arrays[] = { "mem", "la", "ia", "ta", "xa", 0 };
      vpiHandle top = vpi_handle_by_name("top", 0);
      vpi_printf("%s\n", mode);
      show_iteration(vpiVariables,  "vpiVariables ", top);
      show_iteration(vpiReg,        "vpiReg       ", top);
      show_iteration(vpiRegArray,   "vpiRegArray  ", top);
      show_iteration(vpiMemory,     "vpiMemory    ", top);
      show_iteration(vpiIntegerVar, "vpiIntegerVar", top);
      show_iteration(vpiTimeVar,    "vpiTimeVar   ", top);
      show_iteration(vpiRealVar,    "vpiRealVar   ", top);
      for (const char**name = arrays; *name; name += 1) {
	    char full[16];
	    snprintf(full, sizeof full, "top.%s", *name);
	    vpiHandle array = vpi_handle_by_name(full, 0);
	    vpiHandle word = vpi_handle_by_index(array, 0);
	    vpi_printf("  %s: %s, word %s, vpiReg %d, vpiMemoryWord %d,"
	               " vpiVarSelect %d\n", *name,
	               vpi_get_str(vpiType, array), vpi_get_str(vpiType, word),
	               count_iteration(vpiReg, array),
	               count_iteration(vpiMemoryWord, array),
	               count_iteration(vpiVarSelect, array));
      }
}
