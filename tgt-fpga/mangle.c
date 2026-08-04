/*
 * Copyright (c) 2001-2021 Stephen Williams (steve@icarus.com)
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

# include  "fpga_priv.h"
# include  <string.h>
# include  <stdlib.h>
# include  "ivl_alloc.h"

/* XNF records are comma-separated and provide no quoting mechanism for
 * identifiers. Preserve ordinary Verilog names, but encode an entire name
 * component when it contains XNF delimiters (or any other character that
 * requires a Verilog escaped identifier). Encoding the reserved prefix too
 * keeps the mapping one-to-one. */
# define XNF_ESCAPE_PREFIX "__ivl_xnf_"

static void xnf_name_size_error(void)
{
      fprintf(stderr, "fpga.tgt error: XNF identifier is too long.\n");
      exit(1);
}

static int xnf_plain_component(const char*name)
{
      const unsigned char*cp = (const unsigned char*)name;

      if (strncmp(name, XNF_ESCAPE_PREFIX,
		  sizeof XNF_ESCAPE_PREFIX - 1) == 0)
	    return 0;

      if (!((*cp >= 'A' && *cp <= 'Z') ||
	    (*cp >= 'a' && *cp <= 'z') || *cp == '_'))
	    return 0;

      for (cp += 1 ; *cp ; cp += 1) {
	    if ((*cp >= 'A' && *cp <= 'Z') ||
		(*cp >= 'a' && *cp <= 'z') ||
		(*cp >= '0' && *cp <= '9') || *cp == '_' || *cp == '$')
		  continue;
	    return 0;
      }

      return 1;
}

static size_t xnf_component_size(const char*name)
{
      size_t len = strlen(name);

      if (xnf_plain_component(name))
	    return len;

      if (len > ((size_t)-1 - (sizeof XNF_ESCAPE_PREFIX - 1)) / 2)
	    xnf_name_size_error();
      return sizeof XNF_ESCAPE_PREFIX - 1 + 2 * len;
}

static char*xnf_copy_component(char*dst, const char*name)
{
      static const char hex[] = "0123456789ABCDEF";
      const unsigned char*cp;

      if (xnf_plain_component(name)) {
	    size_t len = strlen(name);
	    memcpy(dst, name, len);
	    return dst + len;
      }

      memcpy(dst, XNF_ESCAPE_PREFIX, sizeof XNF_ESCAPE_PREFIX - 1);
      dst += sizeof XNF_ESCAPE_PREFIX - 1;
      for (cp = (const unsigned char*)name ; *cp ; cp += 1) {
	    *dst++ = hex[*cp >> 4];
	    *dst++ = hex[*cp & 15];
      }

      return dst;
}

char*xnf_mangle_identifier(const char*name)
{
      size_t len = xnf_component_size(name);
      char*res;
      char*end;

      if (len == (size_t)-1)
	    xnf_name_size_error();
      res = malloc(len + 1);
      end = xnf_copy_component(res, name);
      *end = 0;
      return res;
}

static size_t xnf_scope_name_size(ivl_scope_t net)
{
      size_t len = xnf_component_size(ivl_scope_basename(net));
      ivl_scope_t parent = ivl_scope_parent(net);

      if (parent) {
	    size_t parent_len = xnf_scope_name_size(parent);
	    if (len == (size_t)-1 || parent_len > (size_t)-1 - len - 1)
		  xnf_name_size_error();
	    len += parent_len + 1;
      }

      return len;
}

static char*xnf_copy_scope_name(char*dst, ivl_scope_t net)
{
      ivl_scope_t parent = ivl_scope_parent(net);

      if (parent) {
	    dst = xnf_copy_scope_name(dst, parent);
	    *dst++ = '/';
      }

      return xnf_copy_component(dst, ivl_scope_basename(net));
}

static char*xnf_mangle_object_name(ivl_scope_t scope, const char*basename)
{
      size_t scope_len = xnf_scope_name_size(scope);
      size_t base_len = xnf_component_size(basename);
      char*res;
      char*end;

      if (base_len > (size_t)-1 - 2 ||
	  scope_len > (size_t)-1 - base_len - 2)
	    xnf_name_size_error();
      res = malloc(scope_len + base_len + 2);
      end = xnf_copy_scope_name(res, scope);
      *end++ = '/';
      end = xnf_copy_component(end, basename);
      *end = 0;
      return res;
}

char*xnf_mangle_logic_name(ivl_net_logic_t net)
{
      return xnf_mangle_object_name(ivl_logic_scope(net),
				    ivl_logic_basename(net));
}

char*xnf_mangle_lpm_name(ivl_lpm_t net)
{
      return xnf_mangle_object_name(ivl_lpm_scope(net),
				    ivl_lpm_basename(net));
}

/*
 * Nexus names are used in pin records to connect things together. It
 * almost doesn't matter what the nexus name is, but for readability
 * we choose a name that is close to the nexus name. This function
 * converts the existing name to a name that XNF can use.
 *
 * For speed, this function saves the calculated string into the real
 * nexus by using the private pointer. Every nexus is used at least
 * twice, so this cuts the mangling time in half at least.
 */
const char* xnf_mangle_nexus_name(ivl_nexus_t net)
{
      char*name = ivl_nexus_get_private(net);

      if (name != 0) {
	    return name;
      }

      name = xnf_mangle_identifier(ivl_nexus_name(net));

      ivl_nexus_set_private(net, name);
      return name;
}
