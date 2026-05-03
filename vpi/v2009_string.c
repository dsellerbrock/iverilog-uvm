/*
 * Copyright (c) 2012-2025 Stephen Williams (steve@icarus.com)
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

# include  "sys_priv.h"
# include  <assert.h>
# include  <ctype.h>
# include  <math.h>
# include  <stdlib.h>
# include  <string.h>

static PLI_INT32 one_arg_compiletf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv;
      vpiHandle arg;

      argv = vpi_iterate(vpiArgument, callh);
      if (argv == 0) {
	    vpi_printf("ERROR: %s:%d: ", vpi_get_str(vpiFile, callh),
	               (int)vpi_get(vpiLineNo, callh));
	    vpi_printf("%s requires a single argument.\n", name);
	    vpip_set_return_value(1);
	    vpi_control(vpiFinish, 1);
	    return 0;
      }

      arg =  vpi_scan(argv);
      if (arg == 0) return 0;

      arg = vpi_scan(argv);
      if (arg != 0) {
	    vpi_printf("ERROR: %s:%d: ", vpi_get_str(vpiFile, callh),
	               (int)vpi_get(vpiLineNo, callh));
	    vpi_printf("%s has too many arguments.\n", name);
	    vpip_set_return_value(1);
	    vpi_control(vpiFinish, 1);
	    return 0;
      }

      return 0;
}

static PLI_INT32 two_arg_compiletf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv;
      vpiHandle arg;

      argv = vpi_iterate(vpiArgument, callh);
      if (argv == 0) {
	    vpi_printf("ERROR: %s:%d: ", vpi_get_str(vpiFile, callh),
	               (int)vpi_get(vpiLineNo, callh));
	    vpi_printf("%s missing arguments.\n", name);
	    vpip_set_return_value(1);
	    vpi_control(vpiFinish, 1);
	    return 0;
      }

      arg = vpi_scan(argv);
      if (argv == 0) {
	    vpi_printf("ERROR: %s:%d: ", vpi_get_str(vpiFile, callh),
	               (int)vpi_get(vpiLineNo, callh));
	    vpi_printf("%s missing object argument.\n", name);
	    vpip_set_return_value(1);
	    vpi_control(vpiFinish, 1);
	    return 0;
      }

      arg = vpi_scan(argv);
      if (argv == 0) {
	    vpi_printf("ERROR: %s:%d: ", vpi_get_str(vpiFile, callh),
	               (int)vpi_get(vpiLineNo, callh));
	    vpi_printf("%s missing method argument.\n", name);
	    vpip_set_return_value(1);
	    vpi_control(vpiFinish, 1);
	    return 0;
      }

      arg = vpi_scan(argv);
      if (arg != 0) {
	    vpi_printf("ERROR: %s:%d: ", vpi_get_str(vpiFile, callh),
	               (int)vpi_get(vpiLineNo, callh));
	    vpi_printf("%s has too many arguments.\n", name);
	    vpip_set_return_value(1);
	    vpi_control(vpiFinish, 1);
	    return 0;
      }

      return 0;
}

static PLI_INT32 three_arg_compiletf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv;

      argv = vpi_iterate(vpiArgument, callh);
      if (argv == 0) {
	    vpi_printf("ERROR: %s:%d: %s missing arguments.\n",
	               vpi_get_str(vpiFile, callh),
	               (int)vpi_get(vpiLineNo, callh), name);
	    vpip_set_return_value(1);
	    vpi_control(vpiFinish, 1);
	    return 0;
      }
      (void)vpi_scan(argv); /* obj */
      (void)vpi_scan(argv); /* arg1 */
      (void)vpi_scan(argv); /* arg2 */
      vpi_free_object(argv);
      return 0;
}

/* G38: string.putc(index, ch) — set character at index in-place. */
static PLI_INT32 putc_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv, obj_h, idx_h, ch_h;
      s_vpi_value value;
      char buf[4096];

      (void)name;

      argv = vpi_iterate(vpiArgument, callh);
      if (!argv) return 0;
      obj_h = vpi_scan(argv);
      idx_h = vpi_scan(argv);
      ch_h  = vpi_scan(argv);
      vpi_free_object(argv);

      if (!obj_h) return 0;

      value.format = vpiStringVal;
      vpi_get_value(obj_h, &value);
      strncpy(buf, value.value.str ? value.value.str : "", sizeof(buf)-1);
      buf[sizeof(buf)-1] = '\0';

      int idx = 0;
      if (idx_h) {
	    value.format = vpiIntVal;
	    vpi_get_value(idx_h, &value);
	    idx = value.value.integer;
      }

      int ch = 0;
      if (ch_h) {
	    value.format = vpiIntVal;
	    vpi_get_value(ch_h, &value);
	    ch = value.value.integer & 0xFF;
      }

      /* SV spec: putc with ch==0 has no effect. */
      if (ch == 0) return 0;

      size_t len = strlen(buf);
      if (idx >= 0 && (size_t)idx < len) {
	    buf[idx] = (char)ch;
	    value.format = vpiStringVal;
	    value.value.str = buf;
	    vpi_put_value(obj_h, &value, 0, vpiNoDelay);
      }

      return 0;
}

static PLI_INT32 len_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv;
      vpiHandle arg;

      (void)name; /* Parameter is not used. */

      argv = vpi_iterate(vpiArgument, callh);
      assert(argv);
      arg = vpi_scan(argv);
      assert(arg);
      vpi_free_object(argv);

      int res = vpi_get(vpiSize, arg);

      s_vpi_value value;
      value.format = vpiIntVal;
      value.value.integer = res;

      vpi_put_value(callh, &value, 0, vpiNoDelay);

      return 0;
}

static PLI_INT32 atoi_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv;
      vpiHandle arg;
      s_vpi_value value;

      (void)name; /* Parameter not used */

      argv = vpi_iterate(vpiArgument, callh);
      assert(argv);
      arg = vpi_scan(argv);
      assert(arg);
      vpi_free_object(argv);

      int res = 0;

      value.format = vpiStringVal;
      vpi_get_value(arg, &value);
      const char*bufp = value.value.str;
      while (bufp && *bufp) {
	    if (isdigit((int)*bufp)) {
		  res = (res * 10) + (*bufp - '0');
		  bufp += 1;
	    } else if (*bufp == '_') {
		  bufp += 1;
	    } else {
		  bufp = 0;
	    }
      }

      value.format = vpiIntVal;
      value.value.integer = res;

      vpi_put_value(callh, &value, 0, vpiNoDelay);

      return 0;
}

static PLI_INT32 atoreal_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv;
      vpiHandle arg;
      s_vpi_value value;

      (void)name; /* Parameter not used */

      argv = vpi_iterate(vpiArgument, callh);
      assert(argv);
      arg = vpi_scan(argv);
      assert(arg);
      vpi_free_object(argv);

      double res = 0;

      value.format = vpiStringVal;
      vpi_get_value(arg, &value);

      res = strtod(value.value.str, 0);

      value.format = vpiRealVal;
      value.value.real = res;

      vpi_put_value(callh, &value, 0, vpiNoDelay);

      return 0;
}

static PLI_INT32 atohex_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv;
      vpiHandle arg;
      s_vpi_value value;

      (void)name; /* Parameter not used */

      argv = vpi_iterate(vpiArgument, callh);
      assert(argv);
      arg = vpi_scan(argv);
      assert(arg);
      vpi_free_object(argv);

      int res = 0;

      value.format = vpiStringVal;
      vpi_get_value(arg, &value);
      const char*bufp = value.value.str;
      while (bufp && *bufp) {
	    switch (*bufp) {
		case '0':
		case '1':
		case '2':
		case '3':
		case '4':
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
		  res = (res * 16) + (*bufp - '0');
		  bufp += 1;
		  break;
		case 'a': case 'A':
		case 'b': case 'B':
		case 'c': case 'C':
		case 'd': case 'D':
		case 'e': case 'E':
		case 'f': case 'F':
		  res = (res * 16) + (toupper((int)*bufp) - 'A' + 10);
		  bufp += 1;
		  break;
		case '_':
		  bufp += 1;
		  break;
		default:
		  bufp = 0;
		  break;
	    }
      }

      value.format = vpiIntVal;
      value.value.integer = res;

      vpi_put_value(callh, &value, 0, vpiNoDelay);

      return 0;
}

static PLI_INT32 atooct_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv;
      vpiHandle arg;
      s_vpi_value value;

      (void)name; /* Parameter not used */

      argv = vpi_iterate(vpiArgument, callh);
      assert(argv);
      arg = vpi_scan(argv);
      assert(arg);
      vpi_free_object(argv);

      int res = 0;

      value.format = vpiStringVal;
      vpi_get_value(arg, &value);
      const char*bufp = value.value.str;
      while (bufp && *bufp) {
	    if ((*bufp >= '0') && (*bufp <= '7')) {
		  res = (res * 8) + (*bufp - '0');
		  bufp += 1;
	    } else if (*bufp == '_') {
		  bufp += 1;
	    } else {
		  bufp = 0;
	    }
      }

      value.format = vpiIntVal;
      value.value.integer = res;

      vpi_put_value(callh, &value, 0, vpiNoDelay);

      return 0;
}

static PLI_INT32 atobin_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv;
      vpiHandle arg;
      s_vpi_value value;

      (void)name; /* Parameter not used */

      argv = vpi_iterate(vpiArgument, callh);
      assert(argv);
      arg = vpi_scan(argv);
      assert(arg);
      vpi_free_object(argv);

      int res = 0;

      value.format = vpiStringVal;
      vpi_get_value(arg, &value);
      const char*bufp = value.value.str;
      while (bufp && *bufp) {
	    if ((*bufp == '0') || (*bufp == '1')) {
		  res = (res * 2) + (*bufp - '0');
		  bufp += 1;
	    } else if (*bufp == '_') {
		  bufp += 1;
	    } else {
		  bufp = 0;
	    }
      }

      value.format = vpiIntVal;
      value.value.integer = res;

      vpi_put_value(callh, &value, 0, vpiNoDelay);

      return 0;
}

/*
 * Convert a val to a text string that represents the value. The base
 * is the integer base to use for the conversion. The base will be one
 * of the values 2, 8, 10, or 16. If the input value is negative, then
 * extract the sign out (and put a '-' in the beginning of the string and
 * write the digits for the abs(val). For example, if the input value
 * is -11 and base is 8, then the text output will be "-13".
 */
static void value_to_text_base(char*text, long val, long base)
{
      static const char digit_map[16] = { '0','1','2','3','4','5','6','7',
                                          '8','9','a','b','c','d','e','f' };
      char* ptr;

      assert(base <= 16);
      if (val == 0) {
	    text[0] = '0';
	    text[1] = 0;
	    return;
      }

      if (val < 0) {
	    *text++ = '-';
	    val = 0-val;
      }

      ptr = text;
      while (val != 0) {
	    long digit = val % base;
	    val /= base;
	    *(ptr++) = digit_map[digit];
	    *ptr = 0;
      }

      /* Now the text string is valid, but digits are reversed. */
      ptr -= 1;
      while (text < ptr) {
	    char tmp = *ptr;
	    *ptr = *text;
	    *text = tmp;
	    ptr -= 1;
	    text += 1;
      }
}

/*
 * This function implements the <string>.itoa(arg) method.
 * The first argument to this task is the <string> object, and the second
 * is the value to interpret.
 */
static PLI_INT32 xtoa_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv;
      vpiHandle obj, arg;
      s_vpi_value value;
      char text_buf[64];
      long use_base;

      use_base = strtoul(name, 0, 10);

      argv = vpi_iterate(vpiArgument, callh);
      assert(argv);
      obj = vpi_scan(argv);
      assert(obj);
      arg = vpi_scan(argv);
      assert(arg);
      vpi_free_object(argv);

      value.format = vpiIntVal;
      vpi_get_value(arg, &value);

      value_to_text_base(text_buf, value.value.integer, use_base);

      value.format = vpiStringVal;
      value.value.str = text_buf;
      vpi_put_value(obj, &value, 0, vpiNoDelay);

      return 0;
}

static PLI_INT32 realtoa_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv;
      vpiHandle obj, arg;
      s_vpi_value value;
      char text_buf[64];

      (void) name;

      argv = vpi_iterate(vpiArgument, callh);
      assert(argv);
      obj = vpi_scan(argv);
      assert(obj);
      arg = vpi_scan(argv);
      assert(arg);
      vpi_free_object(argv);

      value.format = vpiRealVal;
      vpi_get_value(arg, &value);

      snprintf(text_buf, sizeof text_buf, "%g", value.value.real);

      value.format = vpiStringVal;
      value.value.str = text_buf;
      vpi_put_value(obj, &value, 0, vpiNoDelay);

      return 0;
}

static PLI_INT32 compare_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv;
      vpiHandle str1_arg, str2_arg;
      s_vpi_value value;
      char buf1[4096], buf2[4096];

      int case_insensitive = (name && strstr(name, "icompare")) ? 1 : 0;

      argv = vpi_iterate(vpiArgument, callh);
      assert(argv);
      str1_arg = vpi_scan(argv);
      assert(str1_arg);
      str2_arg = vpi_scan(argv);
      vpi_free_object(argv);

      value.format = vpiStringVal;
      vpi_get_value(str1_arg, &value);
      strncpy(buf1, value.value.str ? value.value.str : "", sizeof(buf1)-1);
      buf1[sizeof(buf1)-1] = '\0';

      if (str2_arg) {
	    value.format = vpiStringVal;
	    vpi_get_value(str2_arg, &value);
	    strncpy(buf2, value.value.str ? value.value.str : "", sizeof(buf2)-1);
	    buf2[sizeof(buf2)-1] = '\0';
      } else {
	    buf2[0] = '\0';
      }

      int res;
      if (case_insensitive) {
	    /* icompare: case-insensitive */
	    char*p1 = buf1, *p2 = buf2;
	    while (*p1 && *p2 && tolower((unsigned char)*p1) == tolower((unsigned char)*p2)) {
		  p1++; p2++;
	    }
	    res = tolower((unsigned char)*p1) - tolower((unsigned char)*p2);
      } else {
	    res = strcmp(buf1, buf2);
      }

      value.format = vpiIntVal;
      value.value.integer = res;
      vpi_put_value(callh, &value, 0, vpiNoDelay);

      return 0;
}

static PLI_INT32 getc_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv;
      vpiHandle str_arg, idx_arg;
      s_vpi_value value;

      (void)name;

      argv = vpi_iterate(vpiArgument, callh);
      assert(argv);
      str_arg = vpi_scan(argv);
      assert(str_arg);
      idx_arg = vpi_scan(argv);
      vpi_free_object(argv);

      value.format = vpiStringVal;
      vpi_get_value(str_arg, &value);
      const char*str = value.value.str ? value.value.str : "";

      int idx = 0;
      if (idx_arg) {
	    value.format = vpiIntVal;
	    vpi_get_value(idx_arg, &value);
	    idx = value.value.integer;
      }

      int len = (int)strlen(str);
      int ch = 0;
      if (idx >= 0 && idx < len)
	    ch = (unsigned char)str[idx];

      value.format = vpiIntVal;
      value.value.integer = ch;
      vpi_put_value(callh, &value, 0, vpiNoDelay);

      return 0;
}

static PLI_INT32 toupper_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv;
      vpiHandle arg;
      s_vpi_value value;

      (void)name;

      argv = vpi_iterate(vpiArgument, callh);
      assert(argv);
      arg = vpi_scan(argv);
      assert(arg);
      vpi_free_object(argv);

      value.format = vpiStringVal;
      vpi_get_value(arg, &value);

      char*buf = 0;
      if (value.value.str) {
	    size_t len = strlen(value.value.str);
	    buf = (char*)malloc(len + 1);
	    for (size_t ii = 0 ; ii <= len ; ii += 1)
		  buf[ii] = (char)toupper((unsigned char)value.value.str[ii]);
      } else {
	    buf = (char*)malloc(1);
	    buf[0] = '\0';
      }

      value.format = vpiStringVal;
      value.value.str = buf;
      vpi_put_value(callh, &value, 0, vpiNoDelay);
      free(buf);

      return 0;
}

static PLI_INT32 tolower_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv;
      vpiHandle arg;
      s_vpi_value value;

      (void)name;

      argv = vpi_iterate(vpiArgument, callh);
      assert(argv);
      arg = vpi_scan(argv);
      assert(arg);
      vpi_free_object(argv);

      value.format = vpiStringVal;
      vpi_get_value(arg, &value);

      char*buf = 0;
      if (value.value.str) {
	    size_t len = strlen(value.value.str);
	    buf = (char*)malloc(len + 1);
	    for (size_t ii = 0 ; ii <= len ; ii += 1)
		  buf[ii] = (char)tolower((unsigned char)value.value.str[ii]);
      } else {
	    buf = (char*)malloc(1);
	    buf[0] = '\0';
      }

      value.format = vpiStringVal;
      value.value.str = buf;
      vpi_put_value(callh, &value, 0, vpiNoDelay);
      free(buf);

      return 0;
}

void v2009_string_register(void)
{
      s_vpi_systf_data tf_data;
      vpiHandle res;

      tf_data.type      = vpiSysFunc;
      tf_data.sysfunctype = vpiIntFunc;
      tf_data.tfname    = "$ivl_string_method$len";
      tf_data.calltf    = len_calltf;
      tf_data.compiletf = one_arg_compiletf;
      tf_data.sizetf    = 0;
      tf_data.user_data = "$ivl_string_method$len";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.type      = vpiSysFunc;
      tf_data.sysfunctype = vpiIntFunc;
      tf_data.tfname    = "$ivl_string_method$atoi";
      tf_data.calltf    = atoi_calltf;
      tf_data.compiletf = one_arg_compiletf;
      tf_data.sizetf    = 0;
      tf_data.user_data = "$ivl_string_method$atoi";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.type      = vpiSysFunc;
      tf_data.sysfunctype = vpiRealFunc;
      tf_data.tfname    = "$ivl_string_method$atoreal";
      tf_data.calltf    = atoreal_calltf;
      tf_data.compiletf = one_arg_compiletf;
      tf_data.sizetf    = 0;
      tf_data.user_data = "$ivl_string_method$atoreal";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.type      = vpiSysFunc;
      tf_data.sysfunctype = vpiIntFunc;
      tf_data.tfname    = "$ivl_string_method$atohex";
      tf_data.calltf    = atohex_calltf;
      tf_data.compiletf = one_arg_compiletf;
      tf_data.sizetf    = 0;
      tf_data.user_data = "$ivl_string_method$atohex";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.type      = vpiSysFunc;
      tf_data.sysfunctype = vpiIntFunc;
      tf_data.tfname    = "$ivl_string_method$atooct";
      tf_data.calltf    = atooct_calltf;
      tf_data.compiletf = one_arg_compiletf;
      tf_data.sizetf    = 0;
      tf_data.user_data = "$ivl_string_method$atooct";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.type      = vpiSysFunc;
      tf_data.sysfunctype = vpiIntFunc;
      tf_data.tfname    = "$ivl_string_method$atobin";
      tf_data.calltf    = atobin_calltf;
      tf_data.compiletf = one_arg_compiletf;
      tf_data.sizetf    = 0;
      tf_data.user_data = "$ivl_string_method$atobin";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.type      = vpiSysTask;
      tf_data.tfname    = "$ivl_string_method$itoa";
      tf_data.calltf    = xtoa_calltf;
      tf_data.compiletf = two_arg_compiletf;
      tf_data.sizetf    = 0;
      tf_data.user_data = "10";
      res = vpi_register_systf(&tf_data);

      tf_data.type      = vpiSysTask;
      tf_data.tfname    = "$ivl_string_method$hextoa";
      tf_data.calltf    = xtoa_calltf;
      tf_data.compiletf = two_arg_compiletf;
      tf_data.sizetf    = 0;
      tf_data.user_data = "16";
      res = vpi_register_systf(&tf_data);

      tf_data.type      = vpiSysTask;
      tf_data.tfname    = "$ivl_string_method$octtoa";
      tf_data.calltf    = xtoa_calltf;
      tf_data.compiletf = two_arg_compiletf;
      tf_data.sizetf    = 0;
      tf_data.user_data = "8";
      res = vpi_register_systf(&tf_data);

      tf_data.type      = vpiSysTask;
      tf_data.tfname    = "$ivl_string_method$bintoa";
      tf_data.calltf    = xtoa_calltf;
      tf_data.compiletf = two_arg_compiletf;
      tf_data.sizetf    = 0;
      tf_data.user_data = "2";
      res = vpi_register_systf(&tf_data);

      tf_data.type      = vpiSysTask;
      tf_data.tfname    = "$ivl_string_method$realtoa";
      tf_data.calltf    = realtoa_calltf;
      tf_data.compiletf = two_arg_compiletf;
      tf_data.sizetf    = 0;
      tf_data.user_data = "$ivl_string_method$realtoa";
      res = vpi_register_systf(&tf_data);

      vpip_make_systf_system_defined(res);

      tf_data.type      = vpiSysFunc;
      tf_data.sysfunctype = vpiIntFunc;
      tf_data.tfname    = "$ivl_string_method$compare";
      tf_data.calltf    = compare_calltf;
      tf_data.compiletf = two_arg_compiletf;
      tf_data.sizetf    = 0;
      tf_data.user_data = "$ivl_string_method$compare";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.type      = vpiSysFunc;
      tf_data.sysfunctype = vpiIntFunc;
      tf_data.tfname    = "$ivl_string_method$icompare";
      tf_data.calltf    = compare_calltf;
      tf_data.compiletf = two_arg_compiletf;
      tf_data.sizetf    = 0;
      tf_data.user_data = "$ivl_string_method$icompare";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.type      = vpiSysFunc;
      tf_data.sysfunctype = vpiIntFunc;
      tf_data.tfname    = "$ivl_string_method$getc";
      tf_data.calltf    = getc_calltf;
      tf_data.compiletf = two_arg_compiletf;
      tf_data.sizetf    = 0;
      tf_data.user_data = "$ivl_string_method$getc";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.type      = vpiSysTask;
      tf_data.tfname    = "$ivl_string_method$putc";
      tf_data.calltf    = putc_calltf;
      tf_data.compiletf = three_arg_compiletf;
      tf_data.sizetf    = 0;
      tf_data.user_data = "$ivl_string_method$putc";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.type      = vpiSysFunc;
      tf_data.sysfunctype = vpiStringFunc;
      tf_data.tfname    = "$ivl_string_method$toupper";
      tf_data.calltf    = toupper_calltf;
      tf_data.compiletf = one_arg_compiletf;
      tf_data.sizetf    = 0;
      tf_data.user_data = "$ivl_string_method$toupper";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);

      tf_data.type      = vpiSysFunc;
      tf_data.sysfunctype = vpiStringFunc;
      tf_data.tfname    = "$ivl_string_method$tolower";
      tf_data.calltf    = tolower_calltf;
      tf_data.compiletf = one_arg_compiletf;
      tf_data.sizetf    = 0;
      tf_data.user_data = "$ivl_string_method$tolower";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);
}
