/*
 * Print an FST file as deterministic text, for the FST dumper regressions.
 *
 * The test calls $fst_text("file.fst") to name the file. The file is read,
 * then removed, from a cbEndOfSimulation callback registered at load time.
 * vvp runs those callbacks newest first, so this one runs after the FST
 * dumper's (which is registered by $dumpvars) has closed the file.
 *
 * The FST reader is GTKWave's fstapi, the same sources the dumper uses.
 * They are compiled hidden so the dumper in system.vpi never binds to
 * this module's copy.
 */
#include <ctype.h>
#include <errno.h>
#include <inttypes.h>
#include <limits.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <zlib.h>
#if defined(__GNUC__) && !defined(_WIN32)
#include <sys/mman.h>
#include <unistd.h>
#pragma GCC visibility push(hidden)
#endif
#ifdef __clang__
#pragma clang diagnostic ignored "-Wgnu-folding-constant"
#endif
#include "../../vpi/lz4.c"
#include "../../vpi/fastlz.c"
#include "../../vpi/fstapi.c"
#if defined(__GNUC__) && !defined(_WIN32)
#pragma GCC visibility pop
#endif
#include "vpi_user.h"

static char *fst_name = 0;
static char **names = 0;          /* full var name by handle */
static uint64_t last_time = ~(uint64_t)0;

static PLI_INT32 fst_text_calltf(PLI_BYTE8 *user)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv = vpi_iterate(vpiArgument, callh);
      s_vpi_value val;

      (void)user;
      val.format = vpiStringVal;
      vpi_get_value(vpi_scan(argv), &val);
      vpi_free_object(argv);
      free(fst_name);
      fst_name = strdup(val.value.str);
      return 0;
}

static void show_time(uint64_t time)
{
      if (time != last_time) {
	    vpi_printf("#%llu\n", (unsigned long long)time);
	    last_time = time;
      }
}

static void value_cb(void *user, uint64_t time, fstHandle h,
                     const unsigned char *value)
{
      (void)user;
      show_time(time);
      vpi_printf("  %s = %s\n", names[h], (const char *)value);
}

static void varlen_cb(void *user, uint64_t time, fstHandle h,
                      const unsigned char *value, uint32_t len)
{
      (void)user;
      show_time(time);
      vpi_printf("  %s = \"%.*s\"\n", names[h], (int)len, (const char *)value);
}

static const char *scope_type(unsigned t)
{
      static const char *tab[] = { "module", "task", "function", "begin",
            "fork", "generate", "struct", "union", "class", "interface",
            "package", "program" };
      return t < sizeof tab / sizeof tab[0] ? tab[t] : "other";
}

static const char *var_type(unsigned t)
{
      static const char *tab[] = { "event", "integer", "parameter", "real",
            "real_parameter", "reg", "supply0", "supply1", "time", "tri",
            "triand", "trior", "trireg", "tri0", "tri1", "wand", "wire", "wor",
            "port", "sparray", "realtime", "string", "bit", "logic", "int",
            "shortint", "longint", "byte", "enum", "shortreal" };
      return t < sizeof tab / sizeof tab[0] ? tab[t] : "other";
}

static PLI_INT32 fst_text_end(p_cb_data cb)
{
      fstReaderContext *ctx;
      struct fstHier *h;
      char path[4096] = "";
      size_t depth = 0, lens[256];
      uint32_t idx;

      (void)cb;
      if (!fst_name) return 0;
      ctx = fstReaderOpen(fst_name);
      if (!ctx) {
	    vpi_printf("fst_text: cannot read %s\n", fst_name);
	    return 0;
      }

      vpi_printf("--- %s: timescale 1e%d s, %llu..%llu\n", fst_name,
                 (int)fstReaderGetTimescale(ctx),
                 (unsigned long long)fstReaderGetStartTime(ctx),
                 (unsigned long long)fstReaderGetEndTime(ctx));
      names = calloc(fstReaderGetMaxHandle(ctx) + 1, sizeof(char *));
      while ((h = fstReaderIterateHier(ctx))) switch (h->htyp) {
	  case FST_HT_SCOPE:
	    vpi_printf("%*sscope %s %s%s%s\n", (int)(2*depth), "",
	               scope_type(h->u.scope.typ), h->u.scope.name,
	               h->u.scope.component_length ? " : " : "",
	               h->u.scope.component_length ? h->u.scope.component : "");
	    lens[depth++] = strlen(path);
	    if (lens[depth-1]) strcat(path, ".");
	    strcat(path, h->u.scope.name);
	    break;
	  case FST_HT_UPSCOPE:
	    path[lens[--depth]] = 0;
	    break;
	  case FST_HT_VAR:
	    vpi_printf("%*svar %s %u %s%s\n", (int)(2*depth), "",
	               var_type(h->u.var.typ), h->u.var.length, h->u.var.name,
	               h->u.var.is_alias ? " (alias)" : "");
	    if (!h->u.var.is_alias) {
		  names[h->u.var.handle] = malloc(strlen(path) + h->u.var.name_length + 2);
		  sprintf(names[h->u.var.handle], "%s.%s", path, h->u.var.name);
	    }
	    break;
	  case FST_HT_ATTRBEGIN:
	      /* Source file attributes hold paths and line numbers. */
	    if (h->u.attr.typ == FST_AT_MISC &&
	        (h->u.attr.subtype == FST_MT_PATHNAME ||
	         h->u.attr.subtype == FST_MT_SOURCESTEM ||
	         h->u.attr.subtype == FST_MT_SOURCEISTEM)) break;
	    vpi_printf("%*sattr %u %u %s %llu\n", (int)(2*depth), "",
	               h->u.attr.typ, h->u.attr.subtype,
	               h->u.attr.name ? h->u.attr.name : "",
	               (unsigned long long)h->u.attr.arg);
	    break;
      }

      for (idx = 0; idx < fstReaderGetNumberDumpActivityChanges(ctx); idx++)
	    vpi_printf("dump %s at %llu\n",
	               fstReaderGetDumpActivityChangeValue(ctx, idx) ? "on" : "off",
	               (unsigned long long)fstReaderGetDumpActivityChangeTime(ctx, idx));

      fstReaderSetFacProcessMaskAll(ctx);
      fstReaderIterBlocks2(ctx, value_cb, varlen_cb, 0, 0);
      fstReaderClose(ctx);
      remove(fst_name);
      vpi_printf("--- end\n");
      return 0;
}

static void fst_text_register(void)
{
      s_vpi_systf_data tf;
      s_cb_data cb;

      memset(&tf, 0, sizeof tf);
      tf.type = vpiSysTask;
      tf.tfname = "$fst_text";
      tf.calltf = fst_text_calltf;
      vpi_register_systf(&tf);

      memset(&cb, 0, sizeof cb);
      cb.reason = cbEndOfSimulation;
      cb.cb_rtn = fst_text_end;
      vpi_register_cb(&cb);
}

void (*vlog_startup_routines[])(void) = { fst_text_register, 0 };
