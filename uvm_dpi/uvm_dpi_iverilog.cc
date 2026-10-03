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

#include <string>

// Everything is wrapped in extern "C" (mirroring uvm-core's uvm_dpi.cc) so
// the DPI entry points keep C linkage when compiled with a C++ compiler.
#ifdef __cplusplus
extern "C" {
#endif

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include "uvm_dpi.h"

// -- Vendored, unmodified UVM DPI sources (tool-independent). --
#include "uvm_common.c"

/* Optional diagnostic for the regex crossing. Keep the vendored UVM source
 * unchanged while making the exact POSIX expression visible when debugging a
 * simulator/DPI integration issue. */
static const regex_t*uvm_ivl_failed_regex = nullptr;

static int uvm_ivl_regcomp(regex_t*preg, const char*pattern, int flags)
{
      if (getenv("IVL_UVM_REGEX_TRACE"))
            vpi_printf("trace UVM regex: regcomp pattern=<%s> flags=%d\n",
                       pattern ? pattern : "<null>", flags);

      // Glob conversion is explicit in the upstream API, never a retry.
      // The vendored regexec passes nmatch=0, so REG_NOSUB leaves every
      // result unchanged; it lets TRE (MSYS2 libsystre) accept the full
      // UVM_REGEX_MAX_LENGTH pattern instead of failing with REG_ESPACE.
      int status = regcomp(preg, pattern, flags | REG_NOSUB);
      uvm_ivl_failed_regex = status ? preg : nullptr;
      return status;
}

/* The vendored uvm_re_comp also regfree()s a regex_t whose regcomp failed.
 * POSIX defines regfree only for compiled expressions; TRE leaves a dangling
 * pointer there and crashes. Skip exactly that failed buffer. */
static void uvm_ivl_regfree(regex_t*preg)
{
      if (preg == uvm_ivl_failed_regex) {
            uvm_ivl_failed_regex = nullptr;
            return;
      }
      regfree(preg);
}

#define regcomp uvm_ivl_regcomp
#define regfree uvm_ivl_regfree
#include "uvm_regex.cc"
#undef regfree
#undef regcomp
#include "uvm_svcmd_dpi.c"

// UVM releases through 2020.1 import these C entry points directly. Newer
// releases implement them in SV. Keep matching strict in both APIs.
static void uvm_ivl_legacy_regex_error(const char*id, const char*message)
{
      // Older UVM (including 1.1d) prints native diagnostics and has no
      // SV report callback. Do not dispatch an export it does not define.
      if (!svGetScopeFromName("uvm_pkg::m__uvm_report_dpi")) {
            vpi_printf("%s: %s\n", id, message);
            return;
      }
      m_uvm_report_dpi(M_UVM_ERROR, const_cast<char*>(id),
                      const_cast<char*>(message), M_UVM_NONE,
                      const_cast<char*>(__FILE__), __LINE__);
}

// UVM 1.1/1.2 import the cached-regex API directly from C. Keep its
// strict ERE compilation separate from the modern API.
regex_t*uvm_dpi_regcomp(const char*pattern)
{
      if (!pattern) return nullptr;
      regex_t*compiled = static_cast<regex_t*>(malloc(sizeof(regex_t)));
      if (!compiled) {
            uvm_ivl_legacy_regex_error("UVM/DPI/REGCOMP", "regex allocation failed");
            return nullptr;
      }
      int status = regcomp(compiled, pattern, REG_NOSUB | REG_EXTENDED);
      if (status != 0) {
            char message[UVM_REGEX_MAX_LENGTH];
            regerror(status, compiled, message, sizeof message);
            free(compiled);
            uvm_ivl_legacy_regex_error("UVM/DPI/REGCOMP", message);
            return nullptr;
      }
      return compiled;
}

int uvm_dpi_regexec(regex_t*compiled, const char*str)
{
      return compiled && str ? regexec(compiled, str, 0, nullptr, 0) : 1;
}

void uvm_dpi_regfree(regex_t*compiled)
{
      if (!compiled) return;
      regfree(compiled);
      free(compiled);
}

// UVM 1.0p1/1.1a use unprefixed names and restart argv iteration after NULL.
// Icarus VPI supplies flat argc/argv, not vendor -f pointer-stack extensions.
const char*dpi_get_next_arg_c()
{
      static int index = 0;
      s_vpi_vlog_info info;
      if (!vpi_get_vlog_info(&info)) return nullptr;
      if (index >= info.argc) {
            index = 0;
            return nullptr;
      }
      return info.argv[index++];
}

char*dpi_get_tool_name_c() { return uvm_dpi_get_tool_name_c(); }
char*dpi_get_tool_version_c() { return uvm_dpi_get_tool_version_c(); }
regex_t*dpi_regcomp(const char*pattern) { return uvm_dpi_regcomp(pattern); }
int dpi_regexec(regex_t*compiled, const char*str) { return uvm_dpi_regexec(compiled, str); }
void dpi_regfree(regex_t*compiled) { uvm_dpi_regfree(compiled); }

int uvm_re_match(const char*re, const char*str)
{
      if (!re || !str) return 1;
      size_t len = strlen(re);
      if (len > UVM_REGEX_MAX_LENGTH) {
            uvm_ivl_legacy_regex_error("UVM/DPI/REGEX_MAX",
                                      "regular expression exceeds 2048 characters");
            return 1;
      }
      std::string pattern(re);
      if (len > 1 && re[0] == '/' && re[len-1] == '/')
            pattern = pattern.substr(1, len-2);
      regex_t compiled;
      int result = regcomp(&compiled, pattern.c_str(), REG_EXTENDED);
      if (result != 0) {
            char message[UVM_REGEX_MAX_LENGTH];
            regerror(result, &compiled, message, sizeof message);
            uvm_ivl_legacy_regex_error("UVM/DPI/REGEX_INV", message);
            return result;
      }
      result = regexec(&compiled, str, 0, nullptr, 0);
      regfree(&compiled);
      return result;
}

const char*uvm_glob_to_re(const char*glob)
{
      if (!glob) return nullptr;
      size_t len = strlen(glob);
      if (len > 2040) {
            uvm_ivl_legacy_regex_error("UVM/DPI/REGEX_MAX",
                                      "glob expression exceeds 2040 characters");
            return glob;
      }
      if (len == 0 || (len == 1 && glob[0] == '/')) return "/^$/";
      // DPI copies the returned string; retain storage until the next call.
      static std::string converted;
      if (glob[0] == '/' && glob[len-1] == '/') {
            converted = glob;
            return converted.c_str();
      }
      converted = "/";
      if (glob[0] != '^') converted += '^';
      for (const char*p = glob; *p; ++p) {
            switch (*p) {
              case '*': case '+': converted += '.'; converted += *p; break;
              case '?': converted += '.'; break;
              case '.': case '[': case ']': case '(': case ')':
                  converted += '\\'; converted += *p; break;
              default: converted += *p; break;
            }
      }
      if (converted.back() != '$') converted += '$';
      converted += '/';
      return converted.c_str();
}


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

// A trailing bit or part select on the path ("top.u.st[6:0]", "top.r[3]")
// is accepted as the vendor backends do. It is taken only when the whole
// path names no object, so an array word such as "top.mem[2]" still wins.
struct uvm_ivl_hdl_sel {
      bool present;
      int msb, lsb;
      uvm_ivl_hdl_sel() : present(false), msb(0), lsb(0) { }
};

// Keep one borrowed handle for consecutive reads of the same object. Do not
// cache values: every call still observes the live VPI value.
static std::string uvm_ivl_hdl_last_read_path;
static vpiHandle uvm_ivl_hdl_last_read_handle = nullptr;
static uvm_ivl_hdl_sel uvm_ivl_hdl_last_read_sel;

static void uvm_ivl_hdl_clear_read_cache()
{
      if (uvm_ivl_hdl_last_read_handle)
	    vpi_release_handle(uvm_ivl_hdl_last_read_handle);
      uvm_ivl_hdl_last_read_handle = nullptr;
      uvm_ivl_hdl_last_read_path.clear();
      uvm_ivl_hdl_last_read_sel = uvm_ivl_hdl_sel();
}

static vpiHandle uvm_ivl_hdl_lookup_sel(const char*path,
					uvm_ivl_hdl_sel*sel);

static vpiHandle uvm_ivl_hdl_read_lookup(const char*path,
					 uvm_ivl_hdl_sel*sel, bool*cached)
{
      *cached = false;
      if (path && uvm_ivl_hdl_last_read_handle
	  && uvm_ivl_hdl_last_read_path == path) {
	    *sel = uvm_ivl_hdl_last_read_sel;
	    *cached = true;
	    return uvm_ivl_hdl_last_read_handle;
      }

      uvm_ivl_hdl_clear_read_cache();
      vpiHandle r = uvm_ivl_hdl_lookup_sel(path, sel);
	// Static memory words stay valid for the simulation. Do not retain
	// handles to dynamic objects, which can be invalidated by resizing.
      if (r && !sel->present && vpi_get(vpiType, r) == vpiMemoryWord) {
	    uvm_ivl_hdl_last_read_path = path;
	    uvm_ivl_hdl_last_read_sel = *sel;
	    uvm_ivl_hdl_last_read_handle = r;
	    *cached = true;
      }
      return r;
}

static vpiHandle uvm_ivl_hdl_lookup_sel(const char* path, uvm_ivl_hdl_sel* sel)
{
      vpiHandle r = uvm_ivl_hdl_lookup(path);
      if (r != 0 || path == 0)
	    return r;

      size_t len = strlen(path);
      const char* open = strrchr(path, '[');
      if (len < 3 || path[len-1] != ']' || open == 0 || open == path)
	    return 0;

      int a = 0, b = 0, used = 0;
      if (sscanf(open, "[%d:%d]%n", &a, &b, &used) != 2
	  && sscanf(open, "[%d]%n", &a, &used) != 1)
	    return 0;
      if (open[used] != 0)
	    return 0;
      if (open[used-1] == ']' && strchr(open, ':') == 0)
	    b = a;

      std::string base(path, (size_t)(open - path));
      r = uvm_ivl_hdl_lookup(base.c_str());
      if (r == 0)
	    return 0;
      sel->present = true;
      sel->msb = a;
      sel->lsb = b;
      return r;
}

// Position of declared index idx within the signal's value vector, or -1.
static int uvm_ivl_hdl_bit_pos(vpiHandle r, int size, int idx)
{
      int left = (int) vpi_get(vpiLeftRange, r);
      int right = (int) vpi_get(vpiRightRange, r);
      if (size == 1 && left == right)
	    return idx == left ? 0 : -1;
      int pos = (left < right) ? right - idx : idx - right;
      return (pos >= 0 && pos < size) ? pos : -1;
}

// Resolve the select to the low bit position and width inside the signal.
static bool uvm_ivl_hdl_sel_span(vpiHandle r, int size,
				 const uvm_ivl_hdl_sel& sel, int* low, int* width)
{
      int p1 = uvm_ivl_hdl_bit_pos(r, size, sel.msb);
      int p2 = uvm_ivl_hdl_bit_pos(r, size, sel.lsb);
      if (p1 < 0 || p2 < 0)
	    return false;
      *low = p1 < p2 ? p1 : p2;
      *width = (p1 < p2 ? p2 - p1 : p1 - p2) + 1;
      return true;
}

// Return 1 if the path resolves to an accessible object, else 0.
int uvm_hdl_check_path(char* path)
{
      uvm_ivl_hdl_clear_read_cache();
      uvm_ivl_hdl_sel sel;
      vpiHandle r = uvm_ivl_hdl_lookup_sel(path, &sel);
      if (r == 0)
	    return 0;
      int ok = 1, low, width;
      if (sel.present)
	    ok = uvm_ivl_hdl_sel_span(r, (int) vpi_get(vpiSize, r), sel, &low, &width);
      vpi_release_handle(r);
      return ok;
}

// Number of bits of the signal at path, or 0 if not found.
int uvm_hdl_signal_size(char* path)
{
      uvm_ivl_hdl_clear_read_cache();
      uvm_ivl_hdl_sel sel;
      vpiHandle r = uvm_ivl_hdl_lookup_sel(path, &sel);
      if (r == 0)
	    return 0;
      int size = (int) vpi_get(vpiSize, r);
      if (sel.present) {
	    int low, width;
	    size = uvm_ivl_hdl_sel_span(r, size, sel, &low, &width) ? width : 0;
      }
      vpi_release_handle(r);
      return size;
}

// Read the current value of path into the caller's vecval buffer.
int uvm_hdl_read(char* path, p_vpi_vecval value)
{
      uvm_ivl_hdl_sel sel;
      bool cached;
      vpiHandle r = uvm_ivl_hdl_read_lookup(path, &sel, &cached);
      if (r == 0)
	    return 0;

      int size = (int) vpi_get(vpiSize, r);
      int maxsize = uvm_ivl_hdl_max_width();
      if (size > maxsize) {
	    if (!cached) vpi_release_handle(r);
	    return 0;
      }
      int chunks = (size - 1) / 32 + 1;

      s_vpi_value value_s;
      value_s.format = vpiVectorVal;
      vpi_get_value(r, &value_s);

      if (sel.present) {
    int low, width;
    if (!uvm_ivl_hdl_sel_span(r, size, sel, &low, &width)) {
	  if (!cached) vpi_release_handle(r);
	  return 0;
    }
	    int out_chunks = (width - 1) / 32 + 1;
	    for (int i = 0 ; i < out_chunks ; i += 1)
		  value[i].aval = value[i].bval = 0;
	    for (int i = 0 ; i < width ; i += 1) {
		  int bit = low + i;
		  PLI_INT32 a = (value_s.value.vector[bit/32].aval >> (bit%32)) & 1;
		  PLI_INT32 b = (value_s.value.vector[bit/32].bval >> (bit%32)) & 1;
		  value[i/32].aval |= a << (i%32);
	    value[i/32].bval |= b << (i%32);
	    }
	    if (!cached) vpi_release_handle(r);
	    return 1;
      }

      for (int i = 0 ; i < chunks ; i += 1) {
	    value[i].aval = value_s.value.vector[i].aval;
	    value[i].bval = value_s.value.vector[i].bval;
      }
	if (!cached) vpi_release_handle(r);
      return 1;
}

// Common put helper: deposit (vpiNoDelay), force (vpiForceFlag) or
// release (vpiReleaseFlag).
static int uvm_ivl_hdl_put(char* path, p_vpi_vecval value, PLI_INT32 flag)
{
      uvm_ivl_hdl_clear_read_cache();
      uvm_ivl_hdl_sel sel;
      vpiHandle r = flag == vpiNoDelay ? uvm_ivl_hdl_lookup_sel(path, &sel)
				       : uvm_ivl_hdl_lookup(path);
      if (r == 0)
	    return 0;

      if (sel.present) {
	      // Deposit into a part: read-modify-write the whole signal.
	    int size = (int) vpi_get(vpiSize, r);
	    int low, width;
	    if (size > uvm_ivl_hdl_max_width()
		|| !uvm_ivl_hdl_sel_span(r, size, sel, &low, &width)) {
		  vpi_release_handle(r);
		  return 0;
	    }
	    s_vpi_value cur_s;
	    cur_s.format = vpiVectorVal;
	    vpi_get_value(r, &cur_s);
	    int chunks = (size - 1) / 32 + 1;
	    s_vpi_vecval merged[(UVM_HDL_MAX_WIDTH + 31) / 32];
	    for (int i = 0 ; i < chunks ; i += 1)
		  merged[i] = cur_s.value.vector[i];
	    for (int i = 0 ; i < width ; i += 1) {
		  int bit = low + i;
		  PLI_INT32 a = (value[i/32].aval >> (i%32)) & 1;
		  PLI_INT32 b = (value[i/32].bval >> (i%32)) & 1;
		  merged[bit/32].aval = (merged[bit/32].aval & ~(1 << (bit%32)))
					| (a << (bit%32));
		  merged[bit/32].bval = (merged[bit/32].bval & ~(1 << (bit%32)))
					| (b << (bit%32));
	    }
	    s_vpi_value put_s;
	    s_vpi_time  put_t;
	    put_s.format = vpiVectorVal;
	    put_s.value.vector = merged;
	    put_t.type = vpiSimTime;
	    put_t.high = 0;
	    put_t.low = 0;
	    put_t.real = 0.0;
	    vpi_put_value(r, &put_s, &put_t, vpiNoDelay);
	    vpi_release_handle(r);
	    return 1;
      }

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
// Standalone report export adapter. Match the dispatcher ABI emitted by
// tgt-vvp/vvp_scope.c for m__uvm_report_dpi: the installed umbrella has no
// per-design C stub, but vvp already holds the selected SV export. Merged
// regression builds provide their generated stub instead.
#ifdef UVM_DPI_STANDALONE
typedef union ivl_dpi_arg_u {
      int64_t i;
      double r;
      const char*s;
      void*p;
      uint32_t*v;
} ivl_dpi_arg_t;
extern void __ivl_dpi_export_call_v(const char*, int, ivl_dpi_arg_t*);

void m__uvm_report_dpi(int severity, const char* id, const char* message,
                       int verbosity, const char* file, int linenum)
{
      ivl_dpi_arg_t args[6];
      args[0].i = severity;
      args[1].s = id;
      args[2].s = message;
      args[3].i = verbosity;
      args[4].s = file;
      args[5].i = linenum;
      __ivl_dpi_export_call_v("m__uvm_report_dpi", 6, args);
}
#endif

//----------------------------------------------------------------------
// VPI loadable-module entry point.
//
// vvp loads a module named by a `:vpi_module "uvm_dpi";' directive (which
// `iverilog -uvm' bakes into the compiled program) through the same path as
// a `-m' module, and that path requires a `vlog_startup_routines' table.
// Most of the umbrella registers no system tasks/functions of its own — it
// exists to export the uvm_re_*/uvm_hdl_*/uvm_dpi_* C functions that the
// design imports through DPI (vvp makes a loaded module's symbols available
// to DPI import resolution). U15 adds one systf, registered below: unlike
// the lifecycle entry points (ivl_uvm_record_open/stream/begin/...), which
// are plain DPI imports, $ivl_uvm_record_attribute is called directly as a
// system task, so it needs vpi_register_systf like any other systf.
void ivl_uvm_record_register_systf(void);
void (*vlog_startup_routines[])(void) = { ivl_uvm_record_register_systf, 0 };

#ifdef __cplusplus
}
#endif

#include "uvm_recording.cc"
