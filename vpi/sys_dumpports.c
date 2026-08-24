/*
 * Copyright (c) 2026 The Icarus Verilog Authors
 *
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

/*
 * IEEE 1800 extended VCD (EVCD) port dumping.
 *
 * EVCD is deliberately independent of the ordinary VCD dumper.  In
 * particular, the standard permits $dumpvars and multiple $dumpports files
 * in the same simulation.  Keep all state here per output file instead of
 * sharing sys_vcd.c's singleton.
 */

#include "sys_priv.h"
#include "vcd_priv.h"

#include <assert.h>
#include <ctype.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

struct evcd_file_s;

struct evcd_port_s {
      struct evcd_port_s *next;
      struct evcd_port_s *scope_next;
      struct evcd_file_s *owner;
      vpiHandle signal;
      vpiHandle callbacks[6];
      unsigned callback_count;
      vpiHandle fixture;
      vpiHandle dut;
      unsigned signal_base;
      unsigned fixture_base;
      unsigned fixture_drivers;
      unsigned dut_drivers;
      unsigned is_real : 1;
      char *name;
      unsigned ident;
      unsigned width;
      int direction;
      int left;
      int right;
      unsigned scheduled : 1;
      char *states;
      char *strength0;
      char *strength1;
      char *last_states;
      char *last_strength0;
      char *last_strength1;
      char last_real[32];
      unsigned have_last : 1;
};

struct evcd_scope_s {
      struct evcd_scope_s *next;
      vpiHandle handle;
      char *fullname;
      struct evcd_port_s *ports;
      struct evcd_port_s *ports_tail;
};

struct evcd_file_s {
      struct evcd_file_s *next;
      FILE *file;
      char *path;
      struct evcd_scope_s *scopes;
      struct evcd_scope_s *scopes_tail;
      struct evcd_port_s *ports;
      struct evcd_port_s *ports_tail;
      vpiHandle start_callback;
      vpiHandle sync_callback;
      PLI_UINT64 current_time;
      unsigned next_ident;
      size_t total_bits;
      size_t port_count;
      size_t scope_count;
      long limit;
      unsigned started : 1;
      unsigned off : 1;
      unsigned full : 1;
      unsigned sync_pending : 1;
      unsigned io_failed : 1;
};

static struct evcd_file_s *evcd_files;
static struct evcd_file_s *evcd_files_tail;
static int evcd_have_start_time;
static PLI_UINT64 evcd_start_time;
static int evcd_finish_installed;
static int evcd_no_date;
static size_t evcd_file_count;
static size_t evcd_scope_count;
static size_t evcd_port_count;
static size_t evcd_total_bits;

static struct t_vpi_time evcd_zero_delay = { vpiSimTime, 0, 0, 0.0 };

static const char *const evcd_units[] = {
      "s", "ms", "us", "ns", "ps", "fs"
};

/* Bounds malformed hand-written VVP metadata before it can drive an
 * input-sized allocation or callback loop. Ordinary HDL port widths are
 * far below this one-megabit implementation guard. */
#define EVCD_MAX_PORT_BITS (1024U * 1024U)
#define EVCD_MAX_TOTAL_BITS (4U * EVCD_MAX_PORT_BITS)
/* Bound the per-port strings, callback handles, and bookkeeping separately
 * from the aggregate bit width. A design containing only scalar ports would
 * otherwise pass EVCD_MAX_TOTAL_BITS while consuming excessive memory. */
#define EVCD_MAX_PORT_RECORDS 4096U
#define EVCD_MAX_SCOPE_RECORDS 4096U
#define EVCD_MAX_FILES 64U

static void evcd_message(vpiHandle callh, const char *level,
                         const char *name, const char *fmt, va_list ap)
{
      char text[1024];
      const char *file;
      int line;

      /* VPI string results use shared temporary storage. Format borrowed
       * object names before asking for the call-site filename, which may
       * otherwise overwrite a fullname supplied through fmt. */
      vsnprintf(text, sizeof text, fmt, ap);
      text[sizeof text - 1] = 0;
      file = vpi_get_str(vpiFile, callh);
      line = vpi_get(vpiLineNo, callh);
      vpi_printf("%s: %s:%d: %s: %s\n", level,
                 file ? file : "<unknown>", line, name, text);
}

static void evcd_compile_error(vpiHandle callh, const char *name,
                               const char *fmt, ...)
{
      va_list ap;
      va_start(ap, fmt);
      evcd_message(callh, "ERROR", name, fmt, ap);
      va_end(ap);
      vpip_set_return_value(1);
      vpi_control(vpiFinish, 1);
}

static void evcd_runtime_error(vpiHandle callh, const char *name,
                               const char *fmt, ...)
{
      va_list ap;
      va_start(ap, fmt);
      evcd_message(callh, "ERROR", name, fmt, ap);
      va_end(ap);
      vpip_set_return_value(1);
      vpi_control(vpiFinish, 1);
}

static int evcd_check_io(struct evcd_file_s *file, const char *operation)
{
      if (!file->file || !ferror(file->file)) return 1;
      if (!file->io_failed)
            vpi_printf("ERROR: EVCD %s failed for %s.\n", operation,
                       file->path);
      file->io_failed = 1;
      file->full = 1;
      vpip_set_return_value(1);
      vpi_control(vpiFinish, 1);
      return 0;
}

static PLI_UINT64 evcd_now(void)
{
      struct t_vpi_time now;
      now.type = vpiSimTime;
      vpi_get_time(0, &now);
      return timerec_to_time64(&now);
}

static int evcd_is_null(vpiHandle arg)
{
      return arg && vpi_get(vpiType, arg) == vpiConstant
             && vpi_get(vpiConstType, arg) == vpiNullConst;
}

/* Filename expressions are string values or packed/integral values that can
 * carry a character string.  Real-valued objects are intentionally excluded. */
static int evcd_is_filename(vpiHandle arg)
{
      int type;

      if (!arg || evcd_is_null(arg)) return 0;
      type = vpi_get(vpiType, arg);
      switch (type) {
          case vpiConstant:
          case vpiParameter:
            return vpi_get(vpiConstType, arg) != vpiRealConst;
          case vpiIntegerVar:
          case vpiBitVar:
          case vpiByteVar:
          case vpiShortIntVar:
          case vpiIntVar:
          case vpiLongIntVar:
          case vpiMemoryWord:
          case vpiNet:
          case vpiPartSelect:
          case vpiReg:
          case vpiTimeVar:
          case vpiStringVar:
            return 1;
          default:
            return 0;
      }
}

static int evcd_is_value_signal(vpiHandle signal)
{
      if (!signal) return 0;
      switch (vpi_get(vpiType, signal)) {
          case vpiNet:
          case vpiReg:
          case vpiIntegerVar:
          case vpiBitVar:
          case vpiByteVar:
          case vpiShortIntVar:
          case vpiIntVar:
          case vpiLongIntVar:
          case vpiRealVar:
          case vpiTimeVar:
            return 1;
          default:
            return 0;
      }
}

static int evcd_port_compare(const void *left, const void *right)
{
      vpiHandle a = *(const vpiHandle *)left;
      vpiHandle b = *(const vpiHandle *)right;
      int ai = vpi_get(vpiPortIndex, a);
      int bi = vpi_get(vpiPortIndex, b);
      return (ai > bi) - (ai < bi);
}

static struct evcd_file_s *evcd_find_file(const char *path)
{
      struct evcd_file_s *cur;
      for (cur = evcd_files; cur; cur = cur->next) {
            if (strcmp(cur->path, path) == 0) return cur;
      }
      return 0;
}

static int evcd_scope_already_used(const char *fullname,
                                   const struct evcd_file_s *pending)
{
      const struct evcd_file_s *file;
      const struct evcd_scope_s *scope;

      for (file = evcd_files; file; file = file->next)
            for (scope = file->scopes; scope; scope = scope->next)
                  if (strcmp(scope->fullname, fullname) == 0) return 1;

      if (pending)
            for (scope = pending->scopes; scope; scope = scope->next)
                  if (strcmp(scope->fullname, fullname) == 0) return 1;
      return 0;
}

static void evcd_free_port(struct evcd_port_s *port)
{
      unsigned idx;
      for (idx = 0; idx < port->callback_count; idx += 1)
            if (port->callbacks[idx]) vpi_remove_cb(port->callbacks[idx]);
      free(port->name);
      free(port->states);
      free(port->strength0);
      free(port->strength1);
      free(port->last_states);
      free(port->last_strength0);
      free(port->last_strength1);
      free(port);
}

static void evcd_free_file(struct evcd_file_s *file, int close_file)
{
      struct evcd_scope_s *scope, *scope_next;
      struct evcd_port_s *port, *port_next;

      if (file->start_callback) vpi_remove_cb(file->start_callback);
      if (file->sync_callback) vpi_remove_cb(file->sync_callback);
      if (close_file && file->file && fclose(file->file) != 0) {
            vpi_printf("ERROR: EVCD close failed for %s.\n", file->path);
            vpip_set_return_value(1);
      }
      for (port = file->ports; port; port = port_next) {
            port_next = port->next;
            evcd_free_port(port);
      }
      for (scope = file->scopes; scope; scope = scope_next) {
            scope_next = scope->next;
            free(scope->fullname);
            free(scope);
      }
      assert(evcd_file_count > 0);
      assert(evcd_scope_count >= file->scope_count);
      assert(evcd_port_count >= file->port_count);
      assert(evcd_total_bits >= file->total_bits);
      evcd_file_count -= 1;
      evcd_scope_count -= file->scope_count;
      evcd_port_count -= file->port_count;
      evcd_total_bits -= file->total_bits;
      free(file->path);
      free(file);
}

static int evcd_append_scope(struct evcd_file_s *file, vpiHandle handle,
                             vpiHandle callh, const char *task_name)
{
      struct evcd_scope_s *scope;
      const char *fullname = vpi_get_str(vpiFullName, handle);
      const unsigned char *cp;

      if (!fullname || !*fullname) {
            evcd_runtime_error(callh, task_name,
                               "selected module has no usable full name");
            return 0;
      }
      if (evcd_scope_count >= EVCD_MAX_SCOPE_RECORDS) {
            evcd_runtime_error(callh, task_name,
                               "selected modules exceed the safe aggregate EVCD scope-record limit");
            return 0;
      }
      /* IEEE 1800-2023 21.7.4.1 defines scope_identifier as printable
       * non-whitespace ASCII. EVCD has no escaped-identifier spelling. */
      for (cp = (const unsigned char *)fullname; *cp; cp += 1) {
            if (*cp < 0x21 || *cp > 0x7e) {
                  evcd_runtime_error(callh, task_name,
                                     "module scope '%s' cannot be represented as an EVCD scope_identifier",
                                     fullname);
                  return 0;
            }
      }
      if (evcd_scope_already_used(fullname, file)) {
            evcd_runtime_error(callh, task_name,
                               "module scope '%s' was selected more than once",
                               fullname);
            return 0;
      }

      scope = (struct evcd_scope_s *)calloc(1, sizeof *scope);
      if (!scope) {
            evcd_runtime_error(callh, task_name,
                               "out of memory while recording module scope");
            return 0;
      }
      scope->fullname = strdup(fullname);
      if (!scope->fullname) {
            free(scope);
            evcd_runtime_error(callh, task_name,
                               "out of memory while recording module name");
            return 0;
      }
      scope->handle = handle;
      if (file->scopes_tail) file->scopes_tail->next = scope;
      else file->scopes = scope;
      file->scopes_tail = scope;
      file->scope_count += 1;
      evcd_scope_count += 1;
      return 1;
}

static int evcd_append_port(struct evcd_file_s *file,
                            struct evcd_scope_s *scope, vpiHandle port_handle,
                            unsigned component_index, int has_component,
                            vpiHandle callh, const char *task_name)
{
      struct evcd_port_s *port;
      const char *name = 0;
      vpiHandle signal;
      unsigned width;
      int left, right;
      vpiHandle fixture = 0, dut = 0;
      unsigned fixture_base = 0;
      int fixture_connected = 0, dut_connected = 0;
      unsigned signal_width;
      unsigned signal_base = 0;
      size_t bytes;

      if (has_component) {
            if (!vpip_get_port_component(port_handle, component_index,
                                         &name, &width, &left, &right,
                                         &fixture, &fixture_base,
                                         &fixture_connected, &dut,
                                         &dut_connected)) {
                  evcd_runtime_error(callh, task_name,
                                     "invalid component metadata for module port %d in '%s'",
                                     vpi_get(vpiPortIndex, port_handle),
                                     scope->fullname);
                  return 0;
            }
      } else {
            name = vpi_get_str(vpiName, port_handle);
            width = (unsigned)vpi_get(vpiSize, port_handle);
            left = right = 0;
      }

      if (!name || !*name) {
            evcd_runtime_error(callh, task_name,
                               "module port %d in '%s' has no usable component name",
                               vpi_get(vpiPortIndex, port_handle),
                               scope->fullname);
            return 0;
      }

      signal = vpi_handle_by_name(name, scope->handle);
      if (!evcd_is_value_signal(signal)) {
            evcd_runtime_error(callh, task_name,
                               "cannot obtain the value object for port '%s.%s'",
                               scope->fullname, name);
            return 0;
      }

      signal_width = (unsigned)vpi_get(vpiSize, signal);
      if (!width || width > EVCD_MAX_PORT_BITS || !signal_width ||
          signal_width > EVCD_MAX_PORT_BITS ||
          (has_component &&
           (unsigned long long)(left >= right ?
                 (long long)left-right : (long long)right-left) + 1 != width)) {
            evcd_runtime_error(callh, task_name,
                               "port '%s.%s' has inconsistent metadata width",
                               scope->fullname, name);
            return 0;
      }
      if (vpi_get(vpiType, signal) == vpiRealVar) {
            if (width != 1) {
                  evcd_runtime_error(callh, task_name,
                                     "real port '%s.%s' must be scalar",
                                     scope->fullname, name);
                  return 0;
            }
      } else if (has_component && width != signal_width) {
            int signal_left = vpi_get(vpiLeftRange, signal);
            int signal_right = vpi_get(vpiRightRange, signal);
            long long base;
            if (signal_left >= signal_right) {
                  if (left < right || right < signal_right ||
                      left > signal_left) goto bad_value_range;
                  base = (long long)right - signal_right;
            } else {
                  if (left > right || right > signal_right ||
                      left < signal_left) goto bad_value_range;
                  base = (long long)signal_right - right;
            }
            if (base < 0 || (unsigned long long)base > signal_width ||
                width > signal_width-(unsigned)base)
                  goto bad_value_range;
            signal_base = (unsigned)base;
      } else if (width != signal_width) {
bad_value_range:
            evcd_runtime_error(callh, task_name,
                               "port component '%s.%s' has a range outside its value signal",
                               scope->fullname, name);
            return 0;
      }

      if (fixture || dut || fixture_connected || dut_connected) {
            unsigned fixture_width, dut_width;
            if (!fixture || !dut || vpi_get(vpiType, fixture) != vpiNet ||
                vpi_get(vpiType, dut) != vpiNet ||
                fixture_connected < 0 || dut_connected < 0 ||
                (unsigned)fixture_connected > EVCD_MAX_PORT_BITS ||
                (unsigned)dut_connected > EVCD_MAX_PORT_BITS) {
                  evcd_runtime_error(callh, task_name,
                                     "port '%s.%s' has invalid inout-side metadata",
                                     scope->fullname, name);
                  return 0;
            }
            fixture_width = (unsigned)vpi_get(vpiSize, fixture);
            dut_width = (unsigned)vpi_get(vpiSize, dut);
            if (!fixture_width || fixture_width > EVCD_MAX_PORT_BITS ||
                !dut_width || dut_width > EVCD_MAX_PORT_BITS ||
                fixture_base > fixture_width ||
                width > fixture_width-fixture_base || width > dut_width) {
                  evcd_runtime_error(callh, task_name,
                                     "port '%s.%s' has out-of-range inout-side metadata",
                                     scope->fullname, name);
                  return 0;
            }
      }
      bytes = (size_t)width + 1;
      if (bytes <= width) {
            evcd_runtime_error(callh, task_name,
                               "port '%s.%s' is too wide to dump safely",
                               scope->fullname, name);
            return 0;
      }
      if (evcd_total_bits > EVCD_MAX_TOTAL_BITS-width) {
            evcd_runtime_error(callh, task_name,
                               "selected ports exceed the safe EVCD aggregate width limit");
            return 0;
      }
      if (evcd_port_count >= EVCD_MAX_PORT_RECORDS) {
            evcd_runtime_error(callh, task_name,
                               "selected ports exceed the safe aggregate EVCD port-record limit");
            return 0;
      }

      port = (struct evcd_port_s *)calloc(1, sizeof *port);
      if (!port) goto no_memory;
      port->name = strdup(name);
      port->states = (char *)malloc(bytes);
      port->strength0 = (char *)malloc(bytes);
      port->strength1 = (char *)malloc(bytes);
      port->last_states = (char *)malloc(bytes);
      port->last_strength0 = (char *)malloc(bytes);
      port->last_strength1 = (char *)malloc(bytes);
      if (!port->name || !port->states || !port->strength0 ||
          !port->strength1 || !port->last_states || !port->last_strength0 ||
          !port->last_strength1) goto no_memory;

      port->owner = file;
      port->signal = signal;
      port->fixture = fixture;
      port->dut = dut;
      port->signal_base = signal_base;
      port->fixture_base = fixture_base;
      port->fixture_drivers = fixture_connected;
      port->dut_drivers = dut_connected;
      port->is_real = vpi_get(vpiType, signal) == vpiRealVar;
      port->ident = file->next_ident++;
      port->width = width;
      port->direction = vpi_get(vpiDirection, port_handle);
      port->left = has_component ? left : vpi_get(vpiLeftRange, signal);
      port->right = has_component ? right : vpi_get(vpiRightRange, signal);

      if (port->direction != vpiInput && port->direction != vpiOutput &&
          port->direction != vpiInout) {
            evcd_runtime_error(callh, task_name,
                               "port '%s.%s' has an invalid direction",
                               scope->fullname, name);
            evcd_free_port(port);
            return 0;
      }

      if (file->ports_tail) file->ports_tail->next = port;
      else file->ports = port;
      file->ports_tail = port;
      if (scope->ports_tail) scope->ports_tail->scope_next = port;
      else scope->ports = port;
      scope->ports_tail = port;
      file->total_bits += width;
      file->port_count += 1;
      evcd_total_bits += width;
      evcd_port_count += 1;
      return 1;

no_memory:
      if (port) evcd_free_port(port);
      evcd_runtime_error(callh, task_name,
                         "out of memory while recording port '%s.%s'",
                         scope->fullname, name);
      return 0;
}

static int evcd_collect_ports(struct evcd_file_s *file, vpiHandle callh,
                              const char *task_name)
{
      struct evcd_scope_s *scope;

      for (scope = file->scopes; scope; scope = scope->next) {
            vpiHandle iterator = vpi_iterate(vpiPort, scope->handle);
            vpiHandle handle;
            vpiHandle *ports = 0;
            size_t count = 0, allocated = 0, idx;

            while (iterator && (handle = vpi_scan(iterator))) {
                  /* Every logical port produces at least one record. Reject
                   * before growing the temporary handle array; component
                   * expansion is checked again below. */
                  if (evcd_port_count >= EVCD_MAX_PORT_RECORDS ||
                      count >= EVCD_MAX_PORT_RECORDS-evcd_port_count) {
                        free(ports);
                        evcd_runtime_error(callh, task_name,
                              "selected ports exceed the safe aggregate EVCD port-record limit");
                        return 0;
                  }
                  if (count == allocated) {
                        size_t next = allocated ? allocated * 2 : 8;
                        vpiHandle *tmp;
                        if (next < allocated || next > ((size_t)-1) /
                                                   sizeof *ports) {
                              free(ports);
                              evcd_runtime_error(callh, task_name,
                                                 "too many ports in module '%s'",
                                                 scope->fullname);
                              return 0;
                        }
                        tmp = (vpiHandle *)realloc(ports,
                                                   next * sizeof *ports);
                        if (!tmp) {
                              free(ports);
                              evcd_runtime_error(callh, task_name,
                                                 "out of memory while scanning module '%s'",
                                                 scope->fullname);
                              return 0;
                        }
                        ports = tmp;
                        allocated = next;
                  }
                  ports[count++] = handle;
            }

            qsort(ports, count, sizeof *ports, evcd_port_compare);
            for (idx = 0; idx < count; idx += 1) {
                  unsigned component = 0;
                  unsigned component_sum = 0;
                  const char *component_name;
                  unsigned component_width;
                  int component_left, component_right;
                  vpiHandle fixture, dut;
                  unsigned fixture_base;
                  int fixture_connected, dut_connected;

                  while (vpip_get_port_component(
                               ports[idx], component, &component_name,
                               &component_width, &component_left,
                               &component_right, &fixture, &fixture_base,
                               &fixture_connected, &dut, &dut_connected)) {
                        if (evcd_port_count >= EVCD_MAX_PORT_RECORDS ||
                            component >= EVCD_MAX_PORT_RECORDS-
                                         evcd_port_count) {
                              free(ports);
                              evcd_runtime_error(callh, task_name,
                                    "selected port components exceed the safe aggregate EVCD port-record limit");
                              return 0;
                        }
                        if (!component_width ||
                            component_width > EVCD_MAX_PORT_BITS ||
                            component_sum > EVCD_MAX_PORT_BITS-component_width) {
                              free(ports);
                              evcd_runtime_error(callh, task_name,
                                    "module port %d in '%s' has unsafe component metadata",
                                    vpi_get(vpiPortIndex, ports[idx]),
                                    scope->fullname);
                              return 0;
                        }
                        component_sum += component_width;
                        component += 1;
                  }
                  if (component &&
                      component_sum != (unsigned)vpi_get(vpiSize,
                                                          ports[idx])) {
                        free(ports);
                        evcd_runtime_error(callh, task_name,
                              "module port %d in '%s' has component widths that do not match its declared width",
                              vpi_get(vpiPortIndex, ports[idx]),
                              scope->fullname);
                        return 0;
                  }
                  if (component) {
                        unsigned cidx;
                        for (cidx = 0; cidx < component; cidx += 1)
                              if (!evcd_append_port(file, scope, ports[idx],
                                                    cidx, 1, callh,
                                                    task_name)) {
                                    free(ports);
                                    return 0;
                              }
                  } else if (!evcd_append_port(file, scope, ports[idx],
                                               0, 0, callh, task_name)) {
                              free(ports);
                              return 0;
                  }
            }
            free(ports);
      }
      return 1;
}

static unsigned evcd_strength_digit(PLI_INT32 strength)
{
      int bit;
      for (bit = 7; bit >= 0; bit -= 1)
            if (strength & (1 << bit)) return (unsigned)bit;
      return 0;
}

static unsigned evcd_active_drivers(vpiHandle signal, unsigned bit)
{
      unsigned counts[4] = { 0, 0, 0, 0 };

      if (vpi_get(vpiType, signal) != vpiNet) return 1;
      vpip_count_drivers(signal, bit, counts);
      return counts[0] + counts[1] + counts[2];
}

static char evcd_state_char(const struct evcd_port_s *port, int logic,
                            unsigned active)
{
      if (port->direction == vpiInput) {
            switch (logic) {
                case vpi0: return active > 1 ? 'd' : 'D';
                case vpi1: return active > 1 ? 'u' : 'U';
                case vpiZ: return 'Z';
                default:   return 'N';
            }
      }
      if (port->direction == vpiOutput) {
            switch (logic) {
                case vpi0: return active > 1 ? 'l' : 'L';
                case vpi1: return active > 1 ? 'h' : 'H';
                case vpiZ: return 'T';
                default:   return 'X';
            }
      }

      /* A collapsed inout nexus does not retain which hierarchy side supplied
       * a single driver.  Encode only states that are unambiguous from the
       * resolved nexus; '?' is preferable to inventing a DUT/test-fixture
       * attribution. */
      /* With no tagged hierarchy edge there are no structural drivers on
       * either side of this inout component. Connected hierarchy edges carry
       * their explicit fixture/DUT source counts and use evcd_inout_state(). */
      if (logic == vpiZ) return 'F';
      if (active > 1 && logic == vpi0) return '0';
      if (active > 1 && logic == vpi1) return '1';
      return '?';
}

static unsigned evcd_logic_strength(const s_vpi_strengthval *strength,
                                    int logic)
{
      if (logic == vpi0) return evcd_strength_digit(strength->s0);
      if (logic == vpi1) return evcd_strength_digit(strength->s1);
      return evcd_strength_digit(strength->s0 | strength->s1);
}

static unsigned evcd_strength_range(unsigned strength)
{
      if (strength >= 5) return 2;
      if (strength >= 1) return 1;
      return 0;
}

static char evcd_inout_state(int fixture_logic, int dut_logic,
                             const s_vpi_strengthval *fixture_strength,
                             const s_vpi_strengthval *dut_strength,
                             unsigned fixture_active, unsigned dut_active,
                             unsigned fixture_drivers, unsigned dut_drivers)
{
      int fixture_on = fixture_logic != vpiZ;
      int dut_on = dut_logic != vpiZ;

      if (!fixture_on && !dut_on)
            return (!fixture_drivers && !dut_drivers) ? 'F' : 'f';
      if (fixture_on && !dut_on) {
            switch (fixture_logic) {
                case vpi0: return fixture_active > 1 ? 'd' : 'D';
                case vpi1: return fixture_active > 1 ? 'u' : 'U';
                default: return 'N';
            }
      }
      if (!fixture_on && dut_on) {
            switch (dut_logic) {
                case vpi0: return dut_active > 1 ? 'l' : 'L';
                case vpi1: return dut_active > 1 ? 'h' : 'H';
                default: return 'X';
            }
      }

      if (fixture_logic == vpi0 && dut_logic == vpi1) return 'A';
      if (fixture_logic == vpi0 && dut_logic != vpi0) return 'a';
      if (fixture_logic == vpi1 && dut_logic == vpi0) return 'B';
      if (fixture_logic == vpi1 && dut_logic != vpi1) return 'b';
      if (fixture_logic != vpi0 && fixture_logic != vpi1 &&
          dut_logic == vpi0) return 'C';
      if (fixture_logic != vpi0 && fixture_logic != vpi1 &&
          dut_logic == vpi1) return 'c';

      if (fixture_logic == dut_logic &&
          (fixture_logic == vpi0 || fixture_logic == vpi1)) {
            unsigned fixture_range = evcd_strength_range(
                  evcd_logic_strength(fixture_strength, fixture_logic));
            unsigned dut_range = evcd_strength_range(
                  evcd_logic_strength(dut_strength, dut_logic));
            if (fixture_range > dut_range)
                  return fixture_logic == vpi0 ? 'd' : 'u';
            if (dut_range > fixture_range)
                  return dut_logic == vpi0 ? 'l' : 'h';
            return fixture_logic == vpi0 ? '0' : '1';
      }
      return '?';
}

static int evcd_sample_port(struct evcd_port_s *port, int force_x)
{
      s_vpi_value value;
      s_vpi_strengthval *fixture_values = 0;
      s_vpi_strengthval *dut_values = 0;
      unsigned out;

      if (port->is_real) return 1;

      if (!force_x && port->direction == vpiInout &&
          port->fixture && port->dut) {
            size_t fixture_count = (size_t)vpi_get(vpiSize, port->fixture);
            size_t dut_count = (size_t)vpi_get(vpiSize, port->dut);
            s_vpi_value side;

            if (fixture_count > ((size_t)-1)/sizeof *fixture_values ||
                dut_count > ((size_t)-1)/sizeof *dut_values) {
                  vpi_printf("ERROR: EVCD inout side is too wide to sample safely.\n");
                  vpip_set_return_value(1);
                  vpi_control(vpiFinish, 1);
                  return 0;
            } else {
                  fixture_values = (s_vpi_strengthval*)malloc(
                        fixture_count * sizeof *fixture_values);
                  dut_values = (s_vpi_strengthval*)malloc(
                        dut_count * sizeof *dut_values);
                  if (!fixture_values || !dut_values) {
                        vpi_printf("ERROR: out of memory while sampling EVCD inout sides.\n");
                        vpip_set_return_value(1);
                        vpi_control(vpiFinish, 1);
                        free(fixture_values);
                        free(dut_values);
                        return 0;
                  } else {
                        side.format = vpiStrengthVal;
                        vpi_get_value(port->fixture, &side);
                        if (side.format == vpiStrengthVal &&
                            side.value.strength) {
                              memcpy(fixture_values, side.value.strength,
                                     fixture_count * sizeof *fixture_values);
                              side.format = vpiStrengthVal;
                              vpi_get_value(port->dut, &side);
                              if (side.format == vpiStrengthVal &&
                                  side.value.strength)
                                    memcpy(dut_values, side.value.strength,
                                           dut_count * sizeof *dut_values);
                              else {
                                    free(fixture_values);
                                    free(dut_values);
                                    fixture_values = dut_values = 0;
                              }
                        } else {
                              free(fixture_values);
                              free(dut_values);
                              fixture_values = dut_values = 0;
                        }
                  }
            }
            if (!fixture_values || !dut_values) {
                  vpi_printf("ERROR: unable to sample EVCD inout-side strengths.\n");
                  vpip_set_return_value(1);
                  vpi_control(vpiFinish, 1);
                  return 0;
            }
      }

      value.format = vpiStrengthVal;
      vpi_get_value(port->signal, &value);
      if (value.format != vpiStrengthVal || !value.value.strength) {
            free(fixture_values);
            free(dut_values);
            vpi_printf("ERROR: unable to sample EVCD port strengths.\n");
            vpip_set_return_value(1);
            vpi_control(vpiFinish, 1);
            return 0;
      }

      for (out = 0; out < port->width; out += 1) {
            unsigned bit = port->width - out - 1;
            unsigned signal_bit = port->signal_base + bit;
            const s_vpi_strengthval *strength =
                  value.value.strength + signal_bit;
            if (force_x) {
                  if (port->direction == vpiInput) port->states[out] = 'N';
                  else if (port->direction == vpiOutput) port->states[out] = 'X';
                  else port->states[out] = '?';
                  port->strength0[out] = '6';
                  port->strength1[out] = '6';
            } else {
                  unsigned active = evcd_active_drivers(port->signal,
                                                        signal_bit);
                  if (port->direction == vpiInout && fixture_values &&
                      dut_values) {
                        const s_vpi_strengthval *fixture_strength =
                              fixture_values + port->fixture_base + bit;
                        const s_vpi_strengthval *dut_strength =
                              dut_values + bit;
                        unsigned fixture_active = evcd_active_drivers(
                              port->fixture, port->fixture_base + bit);
                        unsigned dut_active = evcd_active_drivers(port->dut,
                                                                  bit);
                        port->states[out] = evcd_inout_state(
                              fixture_strength->logic, dut_strength->logic,
                              fixture_strength, dut_strength,
                              fixture_active, dut_active,
                              port->fixture_drivers, port->dut_drivers);
                  } else {
                        port->states[out] = evcd_state_char(
                              port, strength->logic, active);
                  }
                  port->strength0[out] =
                        (char)('0' + evcd_strength_digit(strength->s0));
                  port->strength1[out] =
                        (char)('0' + evcd_strength_digit(strength->s1));
            }
      }
      port->states[port->width] = 0;
      port->strength0[port->width] = 0;
      port->strength1[port->width] = 0;
      free(fixture_values);
      free(dut_values);
      return 1;
}

static void evcd_write_time(struct evcd_file_s *file, PLI_UINT64 now,
                            int force);

static int evcd_write_port(struct evcd_file_s *file,
                           struct evcd_port_s *port, int force_x,
                           int write_unchanged, int write_time,
                           PLI_UINT64 now)
{
      if (port->is_real) {
            s_vpi_value value;
            char current[sizeof port->last_real];
            if (force_x) {
                  snprintf(current, sizeof current, "NaN");
            } else {
                  value.format = vpiRealVal;
                  vpi_get_value(port->signal, &value);
                  snprintf(current, sizeof current, "%.16g", value.value.real);
            }
            if (!write_unchanged && port->have_last &&
                strcmp(current, port->last_real) == 0) return 1;
            if (write_time) evcd_write_time(file, now, 0);
            fprintf(file->file, "r%s <%u\n", current, port->ident);
            strcpy(port->last_real, current);
      } else {
            if (!evcd_sample_port(port, force_x)) return 0;
            if (!write_unchanged && port->have_last &&
                strcmp(port->states, port->last_states) == 0 &&
                strcmp(port->strength0, port->last_strength0) == 0 &&
                strcmp(port->strength1, port->last_strength1) == 0)
                  return 1;
            if (write_time) evcd_write_time(file, now, 0);
            fprintf(file->file, "p%s %s %s <%u\n", port->states,
                    port->strength0, port->strength1, port->ident);
            strcpy(port->last_states, port->states);
            strcpy(port->last_strength0, port->strength0);
            strcpy(port->last_strength1, port->strength1);
      }
      port->have_last = 1;
      return 1;
}

static void evcd_write_time(struct evcd_file_s *file, PLI_UINT64 now,
                            int force)
{
      if (force || file->current_time != now) {
            fprintf(file->file, "#%" PLI_UINT64_FMT "\n", now);
            file->current_time = now;
      }
}

static void evcd_mark_full(struct evcd_file_s *file)
{
      if (file->full) return;
      file->full = 1;
      fprintf(file->file,
              "$comment Dumpports file size limit (%ld bytes) reached. $end\n",
              file->limit);
      if (fflush(file->file) != 0) (void)evcd_check_io(file, "flush");
      vpi_printf("WARNING: Dumpports file limit (%ld bytes) reached for %s.\n",
                 file->limit, file->path);
}

static void evcd_check_limit(struct evcd_file_s *file)
{
      long pos;
      if (file->full || file->limit <= 0) return;
      pos = ftell(file->file);
      if (pos < 0) {
            vpi_printf("ERROR: unable to determine EVCD file position for %s.\n",
                       file->path);
            file->io_failed = 1;
            file->full = 1;
            vpip_set_return_value(1);
            vpi_control(vpiFinish, 1);
            return;
      }
      if (pos >= file->limit) evcd_mark_full(file);
}

static void evcd_clear_scheduled(struct evcd_file_s *file)
{
      struct evcd_port_s *port;
      for (port = file->ports; port; port = port->next)
            port->scheduled = 0;
}

static void evcd_checkpoint(struct evcd_file_s *file, const char *keyword,
                            int force_x)
{
      struct evcd_port_s *port;
      PLI_UINT64 now;

      if (!file->started || file->full) return;
      now = evcd_now();
      evcd_clear_scheduled(file);
      evcd_write_time(file, now, 0);
      fprintf(file->file, "%s\n", keyword);
      for (port = file->ports; port; port = port->next)
            if (!evcd_write_port(file, port, force_x, 1, 0, now)) return;
      fprintf(file->file, "$end\n");
      if (!evcd_check_io(file, "checkpoint write")) return;
      evcd_check_limit(file);
}

static void evcd_flush_scheduled(struct evcd_file_s *file, PLI_UINT64 now)
{
      struct evcd_port_s *port;
      if (!file->started || file->off || file->full) {
            evcd_clear_scheduled(file);
            return;
      }

      for (port = file->ports; port; port = port->next) {
            if (!port->scheduled) continue;
            if (!evcd_write_port(file, port, 0, 0, 1, now)) {
                  evcd_clear_scheduled(file);
                  break;
            }
            port->scheduled = 0;
            evcd_check_limit(file);
            if (file->full) {
                  evcd_clear_scheduled(file);
                  break;
            }
      }
      (void)evcd_check_io(file, "value-change write");
}

static PLI_INT32 evcd_sync_cb(p_cb_data cause)
{
      struct evcd_file_s *file = (struct evcd_file_s *)cause->user_data;
      PLI_UINT64 now = timerec_to_time64(cause->time);

      file->sync_pending = 0;
      file->sync_callback = 0;
      evcd_flush_scheduled(file, now);
      return 0;
}

static PLI_INT32 evcd_value_cb(p_cb_data cause)
{
      struct evcd_port_s *port = (struct evcd_port_s *)cause->user_data;
      struct evcd_file_s *file = port->owner;
      struct t_cb_data cb;

      if (!file->started || file->off || file->full || port->scheduled)
            return 0;

      port->scheduled = 1;
      if (file->sync_pending) return 0;

      memset(&cb, 0, sizeof cb);
      cb.reason = cbReadOnlySynch;
      cb.cb_rtn = evcd_sync_cb;
      cb.time = &evcd_zero_delay;
      cb.user_data = (PLI_BYTE8 *)file;
      file->sync_callback = vpi_register_cb(&cb);
      if (!file->sync_callback) {
            port->scheduled = 0;
            vpi_printf("ERROR: failed to schedule EVCD update for %s.\n",
                       file->path);
            vpip_set_return_value(1);
            vpi_control(vpiFinish, 1);
            return 0;
      }
      file->sync_pending = 1;
      return 0;
}

static int evcd_install_port_callbacks(struct evcd_file_s *file)
{
      struct evcd_port_s *port;
      struct t_cb_data cb;
      struct t_vpi_time time;

      memset(&cb, 0, sizeof cb);
      time.type = vpiSimTime;
      cb.reason = cbValueChange;
      cb.cb_rtn = evcd_value_cb;
      cb.time = &time;
      /* The callback only schedules an end-of-slot sample.  Sampling there
       * uses vpiStrengthVal; asking the callback machinery to copy that
       * vector itself is unnecessary and is not supported for fun_signal. */
      cb.value = 0;

      for (port = file->ports; port; port = port->next) {
            vpiHandle targets[3];
            unsigned target_count = 0, idx, prior;
            targets[target_count++] = port->signal;
            if (port->fixture) targets[target_count++] = port->fixture;
            if (port->dut) targets[target_count++] = port->dut;

            for (idx = 0; idx < target_count; idx += 1) {
                  int duplicate = 0;
                  for (prior = 0; prior < idx; prior += 1)
                        if (vpi_compare_objects(targets[idx], targets[prior]))
                              duplicate = 1;
                  if (duplicate) continue;
                  assert(port->callback_count < 6);
                  cb.obj = targets[idx];
                  cb.user_data = (PLI_BYTE8 *)port;
                  port->callbacks[port->callback_count] = vpi_register_cb(&cb);
                  if (!port->callbacks[port->callback_count]) return 0;
                  port->callback_count += 1;
                  assert(port->callback_count < 6);
                  port->callbacks[port->callback_count] =
                        vpip_register_driver_activity_cb(&cb);
                  if (port->callbacks[port->callback_count])
                        port->callback_count += 1;
            }
      }
      return 1;
}

static PLI_INT32 evcd_start_cb(p_cb_data cause)
{
      struct evcd_file_s *file = (struct evcd_file_s *)cause->user_data;
      struct evcd_port_s *port;
      PLI_UINT64 now = timerec_to_time64(cause->time);

      file->start_callback = 0;
      file->started = 1;
      file->current_time = now;
      if (file->full) return 0;
      if (!evcd_install_port_callbacks(file)) {
            vpi_printf("ERROR: failed to install EVCD callbacks for %s.\n",
                       file->path);
            vpip_set_return_value(1);
            vpi_control(vpiFinish, 1);
            return 0;
      }

      fprintf(file->file, "#%" PLI_UINT64_FMT "\n", now);
      fprintf(file->file, file->off ? "$dumpportsoff\n" : "$dumpports\n");
      for (port = file->ports; port; port = port->next)
            if (!evcd_write_port(file, port, file->off, 1, 0, now)) return 0;
      fprintf(file->file, "$end\n");
      if (!evcd_check_io(file, "startup write")) return 0;
      evcd_check_limit(file);
      return 0;
}

static PLI_INT32 evcd_finish_cb(p_cb_data cause)
{
      struct evcd_file_s *file, *next;
      PLI_UINT64 now = timerec_to_time64(cause->time);

      for (file = evcd_files; file; file = next) {
            next = file->next;
            /* cbEndOfSimulation can run before a queued cbReadOnlySynch in
             * the same time slot. Cancel the callback while its user_data is
             * still live, then consume its scheduled samples synchronously
             * so the final port transition is neither lost nor left with a
             * callback pointing at freed file state. */
            if (file->sync_pending) {
                  if (file->sync_callback)
                        vpi_remove_cb(file->sync_callback);
                  file->sync_callback = 0;
                  file->sync_pending = 0;
                  evcd_flush_scheduled(file, now);
            }
            if (file->file) {
                  fprintf(file->file, "$vcdclose #%" PLI_UINT64_FMT
                                      " $end\n", now);
                  if (fflush(file->file) != 0 || ferror(file->file)) {
                        vpi_printf("ERROR: EVCD final write failed for %s.\n",
                                   file->path);
                        vpip_set_return_value(1);
                  }
            }
            evcd_free_file(file, 1);
      }
      evcd_files = 0;
      evcd_files_tail = 0;
      return 0;
}

static int evcd_write_header(struct evcd_file_s *file, vpiHandle callh,
                             const char *task_name)
{
      struct evcd_scope_s *scope;
      struct evcd_port_s *port;
      int precision = vpi_get(vpiTimePrecision, 0);
      unsigned scale = 1;
      unsigned units = 0;
      time_t walltime;

      file->file = fopen(file->path, "w");
      if (!file->file) {
            evcd_runtime_error(callh, task_name,
                               "unable to open '%s' for output", file->path);
            return 0;
      }

      if (!evcd_no_date) {
            struct tm *broken_down;
            const char *date_text;
            time(&walltime);
            broken_down = localtime(&walltime);
            date_text = broken_down ? asctime(broken_down) : 0;
            fprintf(file->file, "$date\n");
            fprintf(file->file, "\t%s", date_text ? date_text : "unknown\n");
            fprintf(file->file, "$end\n");
      }
      fprintf(file->file, "$version\n\tIcarus Verilog\n$end\n");

      if (precision < -15 || precision > 0) {
            evcd_runtime_error(callh, task_name,
                               "simulation time precision is outside EVCD range");
            return 0;
      }
      while (precision < 0) {
            units += 1;
            precision += 3;
      }
      while (precision > 0) {
            scale *= 10;
            precision -= 1;
      }
      assert(units < sizeof evcd_units / sizeof evcd_units[0]);
      fprintf(file->file, "$timescale\n\t%u%s\n$end\n",
              scale, evcd_units[units]);

      for (scope = file->scopes; scope; scope = scope->next) {
            fprintf(file->file, "$scope module %s $end\n", scope->fullname);
            for (port = scope->ports; port; port = port->scope_next) {
                  const char *prefix = is_escaped_id(port->name) ? "\\" : "";
                  if (port->width == 1)
                        fprintf(file->file, "$var port 1 <%u %s%s $end\n",
                                port->ident, prefix, port->name);
                  else
                        fprintf(file->file,
                                "$var port [%d:%d] <%u %s%s $end\n",
                                port->left, port->right, port->ident,
                                prefix, port->name);
            }
            fprintf(file->file, "$upscope $end\n");
      }
      fprintf(file->file, "$enddefinitions $end\n");
      return evcd_check_io(file, "header write");
}

static int evcd_schedule_start(struct evcd_file_s *file, vpiHandle callh,
                               const char *task_name)
{
      struct t_cb_data cb;

      memset(&cb, 0, sizeof cb);
      cb.reason = cbReadOnlySynch;
      cb.cb_rtn = evcd_start_cb;
      cb.time = &evcd_zero_delay;
      cb.user_data = (PLI_BYTE8 *)file;
      file->start_callback = vpi_register_cb(&cb);
      if (!file->start_callback) {
            evcd_runtime_error(callh, task_name,
                               "unable to schedule end-of-time-slot startup");
            return 0;
      }
      return 1;
}

static int evcd_install_finish(vpiHandle callh, const char *task_name)
{
      struct t_cb_data cb;
      vpiHandle handle;

      if (evcd_finish_installed) return 1;
      memset(&cb, 0, sizeof cb);
      cb.reason = cbEndOfSimulation;
      cb.cb_rtn = evcd_finish_cb;
      handle = vpi_register_cb(&cb);
      if (!handle) {
            evcd_runtime_error(callh, task_name,
                               "unable to install end-of-simulation cleanup");
            return 0;
      }
      evcd_finish_installed = 1;
      return 1;
}

static PLI_INT32 evcd_dumpports_calltf(ICARUS_VPI_CONST PLI_BYTE8 *name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle iterator = vpi_iterate(vpiArgument, callh);
      vpiHandle arg;
      vpiHandle *args = 0;
      size_t argc = 0, allocated = 0, idx, scope_count = 0;
      int explicit_null = 0;
      vpiHandle filename_arg = 0;
      char *path = 0;
      struct evcd_file_s *file = 0;
      PLI_UINT64 now = evcd_now();

      while (iterator && (arg = vpi_scan(iterator))) {
            /* At most EVCD_MAX_SCOPE_RECORDS module handles plus one
             * filename can be meaningful. Bound the argument array before
             * reallocating it. */
            if (argc >= (size_t)EVCD_MAX_SCOPE_RECORDS + 1) {
                  evcd_runtime_error(callh, name,
                                     "too many $dumpports arguments");
                  goto fail;
            }
            if (argc == allocated) {
                  size_t next = allocated ? allocated * 2 : 8;
                  vpiHandle *tmp;
                  if (next < allocated || next > ((size_t)-1) / sizeof *args)
                        goto no_memory;
                  tmp = (vpiHandle *)realloc(args, next * sizeof *args);
                  if (!tmp) goto no_memory;
                  args = tmp;
                  allocated = next;
            }
            args[argc++] = arg;
      }

      if (argc && evcd_is_null(args[0])) {
            explicit_null = 1;
            if (argc != 2 || !evcd_is_filename(args[1])) {
                  evcd_runtime_error(callh, name,
                                     "a null scope requires exactly one filename argument");
                  goto fail;
            }
            filename_arg = args[1];
      } else {
            while (scope_count < argc &&
                   vpi_get(vpiType, args[scope_count]) == vpiModule)
                  scope_count += 1;
            if (scope_count > EVCD_MAX_SCOPE_RECORDS) {
                  evcd_runtime_error(callh, name,
                                     "selected modules exceed the safe aggregate EVCD scope-record limit");
                  goto fail;
            }
            if (scope_count < argc) {
                  if (scope_count + 1 != argc ||
                      !evcd_is_filename(args[scope_count])) {
                        evcd_runtime_error(callh, name,
                                           "arguments must be module scopes followed by an optional filename");
                        goto fail;
                  }
                  if (scope_count == 0) {
                        evcd_runtime_error(callh, name,
                                           "omit the scope with a leading comma before the filename");
                        goto fail;
                  }
                  filename_arg = args[scope_count];
            }
      }

      if (filename_arg) path = get_filename(callh, name, filename_arg);
      else path = strdup("dumpports.vcd");
      if (!path) goto fail;
      if (evcd_find_file(path)) {
            evcd_runtime_error(callh, name,
                               "filename '%s' was specified more than once", path);
            goto fail;
      }
      if (evcd_have_start_time && now != evcd_start_time) {
            evcd_runtime_error(callh, name,
                               "all $dumpports calls must execute at the same simulation time");
            goto fail;
      }
      if (evcd_file_count >= EVCD_MAX_FILES) {
            evcd_runtime_error(callh, name,
                               "too many EVCD files are open");
            goto fail;
      }

      file = (struct evcd_file_s *)calloc(1, sizeof *file);
      if (!file) goto no_memory;
      evcd_file_count += 1;
      file->path = path;
      path = 0;

      if (scope_count) {
            for (idx = 0; idx < scope_count; idx += 1)
                  if (!evcd_append_scope(file, args[idx], callh, name)) goto fail;
      } else {
            vpiHandle scope = sys_func_module(callh);
            (void)explicit_null;
            if (!scope || vpi_get(vpiType, scope) != vpiModule) {
                  evcd_runtime_error(callh, name,
                                     "cannot determine the calling module scope");
                  goto fail;
            }
            if (!evcd_append_scope(file, scope, callh, name)) goto fail;
      }

      if (!evcd_collect_ports(file, callh, name)) goto fail;
      if (!evcd_write_header(file, callh, name)) goto fail;
      if (!evcd_schedule_start(file, callh, name)) goto fail;
      if (!evcd_install_finish(callh, name)) goto fail;

      if (evcd_files_tail) evcd_files_tail->next = file;
      else evcd_files = file;
      evcd_files_tail = file;
      evcd_have_start_time = 1;
      evcd_start_time = now;
      vpi_printf("EVCD info: dumpports file %s opened for output.\n",
                 file->path);
      free(args);
      return 0;

no_memory:
      evcd_runtime_error(callh, name,
                         "out of memory while processing arguments");
fail:
      free(path);
      free(args);
      if (file) evcd_free_file(file, 1);
      return 0;
}

static char *evcd_optional_filename(vpiHandle callh, const char *name,
                                    int *specified, int *valid)
{
      vpiHandle iterator = vpi_iterate(vpiArgument, callh);
      vpiHandle arg;
      char *path;

      *specified = 0;
      *valid = 1;
      if (!iterator) return 0;
      *specified = 1;
      arg = vpi_scan(iterator);
      assert(arg);
      path = get_filename(callh, name, arg);
      if (!path) *valid = 0;
      vpi_free_object(iterator);
      return path;
}

enum evcd_control_e {
      EVCD_OFF, EVCD_ON, EVCD_ALL, EVCD_FLUSH
};

static PLI_INT32 evcd_control_calltf(ICARUS_VPI_CONST PLI_BYTE8 *data)
{
      const char *name = data;
      enum evcd_control_e operation;
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      int specified, valid;
      char *path = evcd_optional_filename(callh, name, &specified, &valid);
      struct evcd_file_s *file;

      (void)specified;
      if (!valid) return 0;

      if (strcmp(name, "$dumpportsoff") == 0) operation = EVCD_OFF;
      else if (strcmp(name, "$dumpportson") == 0) operation = EVCD_ON;
      else if (strcmp(name, "$dumpportsall") == 0) operation = EVCD_ALL;
      else operation = EVCD_FLUSH;

      for (file = evcd_files; file; file = file->next) {
            if (path && strcmp(path, file->path) != 0) continue;
            switch (operation) {
                case EVCD_OFF:
                  if (!file->off) {
                        file->off = 1;
                        evcd_checkpoint(file, "$dumpportsoff", 1);
                  }
                  break;
                case EVCD_ON:
                  if (file->off) {
                        file->off = 0;
                        evcd_checkpoint(file, "$dumpportson", 0);
                  }
                  break;
                case EVCD_ALL:
                  if (!file->off) evcd_checkpoint(file, "$dumpportsall", 0);
                  break;
                case EVCD_FLUSH:
                  if (file->file &&
                      (fflush(file->file) != 0 || ferror(file->file)))
                        (void)evcd_check_io(file, "flush");
                  break;
            }
      }
      free(path);
      return 0;
}

static PLI_INT32 evcd_limit_calltf(ICARUS_VPI_CONST PLI_BYTE8 *name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle iterator = vpi_iterate(vpiArgument, callh);
      vpiHandle size_arg, file_arg;
      s_vpi_value value;
      char *path = 0;
      struct evcd_file_s *file;

      assert(iterator);
      size_arg = vpi_scan(iterator);
      assert(size_arg);
      file_arg = vpi_scan(iterator);
      if (file_arg) path = get_filename(callh, name, file_arg);
      if (file_arg) vpi_free_object(iterator);
      if (file_arg && !path) return 0;

      value.format = vpiIntVal;
      vpi_get_value(size_arg, &value);
      if (value.value.integer < 0) {
            evcd_runtime_error(callh, name,
                               "file size limit must not be negative");
            free(path);
            return 0;
      }

      for (file = evcd_files; file; file = file->next) {
            if (path && strcmp(path, file->path) != 0) continue;
            file->limit = value.value.integer;
            evcd_check_limit(file);
      }
      free(path);
      return 0;
}

static PLI_INT32 evcd_dumpports_compiletf(ICARUS_VPI_CONST PLI_BYTE8 *name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle iterator = vpi_iterate(vpiArgument, callh);
      vpiHandle arg;
      unsigned argc = 0;
      int saw_filename = 0;
      int first_null = 0;

      while (iterator && (arg = vpi_scan(iterator))) {
            argc += 1;
            if (argc == 1 && evcd_is_null(arg)) {
                  first_null = 1;
                  continue;
            }
            if (!saw_filename && !first_null &&
                vpi_get(vpiType, arg) == vpiModule)
                  continue;
            if (!saw_filename && evcd_is_filename(arg)) {
                  if (argc == 1 && !first_null) {
                        evcd_compile_error(callh, name,
                                           "a filename with no scope requires a leading comma");
                        return 0;
                  }
                  saw_filename = 1;
                  continue;
            }
            evcd_compile_error(callh, name,
                               "arguments must be module scopes followed by an optional filename");
            return 0;
      }
      if (first_null && (argc != 2 || !saw_filename))
            evcd_compile_error(callh, name,
                               "a null scope requires exactly one filename argument");
      return 0;
}

static PLI_INT32 evcd_control_compiletf(ICARUS_VPI_CONST PLI_BYTE8 *name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle iterator = vpi_iterate(vpiArgument, callh);
      vpiHandle arg;

      if (!iterator) return 0;
      arg = vpi_scan(iterator);
      if (!evcd_is_filename(arg)) {
            evcd_compile_error(callh, name,
                               "optional argument must be a filename expression");
            return 0;
      }
      if (vpi_scan(iterator))
            evcd_compile_error(callh, name,
                               "takes at most one filename argument");
      return 0;
}

static PLI_INT32 evcd_limit_compiletf(ICARUS_VPI_CONST PLI_BYTE8 *name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle iterator = vpi_iterate(vpiArgument, callh);
      vpiHandle arg;

      if (!iterator) {
            evcd_compile_error(callh, name,
                               "requires a numeric file size argument");
            return 0;
      }
      arg = vpi_scan(iterator);
      if (!is_numeric_obj(arg) || vpi_get(vpiType, arg) == vpiRealVar ||
          ((vpi_get(vpiType, arg) == vpiConstant ||
            vpi_get(vpiType, arg) == vpiParameter) &&
           vpi_get(vpiConstType, arg) == vpiRealConst)) {
            evcd_compile_error(callh, name,
                               "file size argument must be integral");
            return 0;
      }
      arg = vpi_scan(iterator);
      if (arg && !evcd_is_filename(arg)) {
            evcd_compile_error(callh, name,
                               "second argument must be a filename expression");
            return 0;
      }
      if (arg && vpi_scan(iterator))
            evcd_compile_error(callh, name,
                               "takes a file size and at most one filename");
      return 0;
}

static void evcd_register_task(
      const char *name,
      PLI_INT32 (*calltf)(ICARUS_VPI_CONST PLI_BYTE8 *),
      PLI_INT32 (*compiletf)(ICARUS_VPI_CONST PLI_BYTE8 *))
{
      s_vpi_systf_data tf_data;
      vpiHandle handle;

      memset(&tf_data, 0, sizeof tf_data);
      tf_data.type = vpiSysTask;
      tf_data.tfname = name;
      tf_data.calltf = calltf;
      tf_data.compiletf = compiletf;
      tf_data.user_data = name;
      handle = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(handle);
}

void sys_dumpports_register(void)
{
      struct t_vpi_vlog_info info;
      int idx;

      vpi_get_vlog_info(&info);
      for (idx = 0; idx < info.argc; idx += 1)
            if (strcmp(info.argv[idx], "-no-date") == 0)
                  evcd_no_date = 1;

      evcd_register_task("$dumpports", evcd_dumpports_calltf,
                         evcd_dumpports_compiletf);
      evcd_register_task("$dumpportsoff", evcd_control_calltf,
                         evcd_control_compiletf);
      evcd_register_task("$dumpportson", evcd_control_calltf,
                         evcd_control_compiletf);
      evcd_register_task("$dumpportsall", evcd_control_calltf,
                         evcd_control_compiletf);
      evcd_register_task("$dumpportslimit", evcd_limit_calltf,
                         evcd_limit_compiletf);
      evcd_register_task("$dumpportsflush", evcd_control_calltf,
                         evcd_control_compiletf);
}
