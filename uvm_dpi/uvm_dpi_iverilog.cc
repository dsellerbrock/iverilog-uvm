//----------------------------------------------------------------------
// Fork-owned DPI umbrella for building the UVM DPI library against Icarus
// Verilog.
//
// The upstream uvm-core is vendored UNMODIFIED, and its umbrella
// (uvm-core/src/dpi/uvm_dpi.cc) only knows about the VCS/Questa/Xcelium
// HDL backends (`#error "hdl vendor backend is missing"' otherwise) and
// pulls in polling code that assumes vendor VPI extensions. This file is
// the Icarus equivalent: it combines the vendored, tool-independent UVM
// DPI sources (regex, command-line, and the common reporting bridge) with
// an Icarus-specific HDL-backdoor backend implemented on standard IEEE
// 1800 VPI. Polling (uvm_hdl_polling.c) is intentionally excluded — it is
// only used under +define+UVM_PLI_POLLING_ENABLE.
//
// Build (see .github/uvm_test.sh):
//   g++ -shared -fPIC -I<ivl-include> -I uvm-core/src/dpi \
//       -o uvm_dpi.so uvm_dpi/uvm_dpi_iverilog.cc
//
// The DPI entry points (uvm_re_*, uvm_dpi_get_*, uvm_hdl_*) and the sv*
// scope API resolve against symbols exported by vvp/libvvp at load time
// (svGetScope/svSetScope/svGetScopeFromName are provided by the runtime).
//----------------------------------------------------------------------

// Everything is wrapped in extern "C" (mirroring uvm-core's uvm_dpi.cc) so
// the DPI entry points keep C linkage when compiled with a C++ compiler.
#ifdef __cplusplus
extern "C" {
#endif

#include <stdlib.h>
#include "uvm_dpi.h"

// -- Vendored, unmodified UVM DPI sources (tool-independent). --
#include "uvm_common.c"
#include "uvm_regex.cc"
#include "uvm_svcmd_dpi.c"

//----------------------------------------------------------------------
// Icarus HDL-backdoor backend.
//
// Implements the uvm_hdl_* DPI imports declared in uvm-core's uvm_hdl.svh
// using standard VPI (vpi_handle_by_name / vpi_get_value / vpi_put_value).
// Values use the UVM uvm_hdl_data_t contract: a packed array of
// s_vpi_vecval (aval/bval) 32-bit chunks, little-endian chunk order.
//----------------------------------------------------------------------

#ifndef UVM_HDL_MAX_WIDTH
#define UVM_HDL_MAX_WIDTH 1024
#endif

static int uvm_ivl_hdl_max_width(void) { return UVM_HDL_MAX_WIDTH; }

// Resolve a UVM HDL path to a VPI object handle, tolerating a leading
// "$root." the same way the vendor backends do.
static vpiHandle uvm_ivl_hdl_lookup(const char* path)
{
      if (path == 0)
	    return 0;
      if (!strncmp(path, "$root.", 6))
	    return vpi_handle_by_name((char*)path + 6, 0);
      return vpi_handle_by_name((char*)path, 0);
}

// Return 1 if the path resolves to an accessible object, else 0.
int uvm_hdl_check_path(char* path)
{
      vpiHandle r = uvm_ivl_hdl_lookup(path);
      if (r == 0)
	    return 0;
      vpi_release_handle(r);
      return 1;
}

// Number of bits of the signal at path, or 0 if not found.
int uvm_hdl_signal_size(char* path)
{
      vpiHandle r = uvm_ivl_hdl_lookup(path);
      if (r == 0)
	    return 0;
      int size = (int) vpi_get(vpiSize, r);
      vpi_release_handle(r);
      return size;
}

// Read the current value of path into the caller's vecval buffer.
int uvm_hdl_read(char* path, p_vpi_vecval value)
{
      vpiHandle r = uvm_ivl_hdl_lookup(path);
      if (r == 0)
	    return 0;

      int size = (int) vpi_get(vpiSize, r);
      int maxsize = uvm_ivl_hdl_max_width();
      if (size > maxsize) {
	    vpi_release_handle(r);
	    return 0;
      }
      int chunks = (size - 1) / 32 + 1;

      s_vpi_value value_s;
      value_s.format = vpiVectorVal;
      vpi_get_value(r, &value_s);
      for (int i = 0 ; i < chunks ; i += 1) {
	    value[i].aval = value_s.value.vector[i].aval;
	    value[i].bval = value_s.value.vector[i].bval;
      }
      vpi_release_handle(r);
      return 1;
}

// Common put helper: deposit (vpiNoDelay), force (vpiForceFlag) or
// release (vpiReleaseFlag).
static int uvm_ivl_hdl_put(char* path, p_vpi_vecval value, PLI_INT32 flag)
{
      vpiHandle r = uvm_ivl_hdl_lookup(path);
      if (r == 0)
	    return 0;

      s_vpi_value value_s;
      s_vpi_time  time_s;
      value_s.format = vpiVectorVal;
      value_s.value.vector = value;
      time_s.type = vpiSimTime;
      time_s.high = 0;
      time_s.low = 0;
      time_s.real = 0.0;
      vpi_put_value(r, &value_s, &time_s, flag);
      vpi_release_handle(r);
      return 1;
}

int uvm_hdl_deposit(char* path, p_vpi_vecval value)
{
      return uvm_ivl_hdl_put(path, value, vpiNoDelay);
}

int uvm_hdl_force(char* path, p_vpi_vecval value)
{
      return uvm_ivl_hdl_put(path, value, vpiForceFlag);
}

int uvm_hdl_release_and_read(char* path, p_vpi_vecval value)
{
      int result = uvm_ivl_hdl_put(path, value, vpiReleaseFlag);
      if (result > 0)
	    result = uvm_hdl_read(path, value);
      return result;
}

int uvm_hdl_release(char* path)
{
      s_vpi_vecval value;
      value.aval = 0;
      value.bval = 0;
      return uvm_ivl_hdl_put(path, &value, vpiReleaseFlag);
}

//----------------------------------------------------------------------
// VPI loadable-module entry point.
//
// vvp loads a module named by a `:vpi_module "uvm_dpi";' directive (which
// `iverilog -uvm' bakes into the compiled program) through the same path as
// a `-m' module, and that path requires a `vlog_startup_routines' table. The
// umbrella registers no system tasks/functions of its own — it exists to
// export the uvm_re_*/uvm_hdl_*/uvm_dpi_* C functions that the design
// imports through DPI (vvp makes a loaded module's symbols available to DPI
// import resolution). So the table is empty: its presence alone lets the
// module load, and simply being loaded is what publishes the DPI symbols.
void (*vlog_startup_routines[])(void) = { 0 };

#ifdef __cplusplus
}
#endif
