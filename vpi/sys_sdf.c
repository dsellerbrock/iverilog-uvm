/*
 * Copyright (c) 2007-2025 Stephen Williams (steve@icarus.com)
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
# include  "sdf_priv.h"
# include  <ctype.h>
# include  <math.h>
# include  <stdlib.h>
# include  <string.h>
# include  <strings.h>

extern vpiHandle vpip_interconnect_ports_connected(vpiHandle source,
                                                  vpiHandle load);
extern bool vpip_interconnect_port_uses_part_select(vpiHandle port);
extern bool vpip_interconnect_through_net(vpiHandle net, vpiHandle load);
extern vpiHandle vpip_interconnect_net_to_load(vpiHandle net,
                                               vpiHandle load);
# include  <assert.h>

/*
 * These are static context
 */

int sdf_flag_warning = 0;
int sdf_flag_inform = 0;
int sdf_min_typ_max;
double sdf_scale_factors[3] = { 1.0, 1.0, 1.0 };
int sdf_scale_type = SDF_SCALE_FROM_MTM;
  /* Scope of the $sdf_annotate call. Annotation starts here. */
static vpiHandle sdf_scope;
static vpiHandle sdf_callh = 0;
  /* The cell in process. */
static vpiHandle sdf_cur_cell;
static char* sdf_fname = NULL;
static int sdf_timescale_set;
static int sdf_timescale_exponent;
static double sdf_timescale_value;

void sdf_reset_timescale(void)
{
      sdf_timescale_set = 0;
      sdf_timescale_value = 1.0;
      sdf_timescale_exponent = 0;
}

void sdf_set_timescale(double value, const char*unit, int sdf_lineno)
{
      static const struct { const char*name; int exponent; } units[] = {
	    { "s", 0 }, { "ms", -3 }, { "us", -6 },
	    { "ns", -9 }, { "ps", -12 }, { "fs", -15 }
      };
      unsigned idx;

      for (idx = 0; idx < sizeof units / sizeof units[0]; idx += 1) {
	    if (strcmp(unit, units[idx].name) == 0) {
		  sdf_timescale_set = 1;
		  sdf_timescale_value = value;
		  sdf_timescale_exponent = units[idx].exponent;
		  return;
	    }
      }

      vpi_printf("SDF WARNING: %s:%d: Unknown TIMESCALE unit '%s'; "
	         "using module time unit.\n", sdf_fname, sdf_lineno, unit);
      sdf_timescale_set = 0;
}

double sdf_time_scale(void)
{
      if (!sdf_timescale_set || !sdf_cur_cell) return 1.0;
      return sdf_timescale_value *
	     pow(10.0, sdf_timescale_exponent - vpi_get(vpiTimeUnit, sdf_cur_cell));
}

static int sdf_string_is_blank(const char*value)
{
      while (*value) {
	    if (!isspace((unsigned char)*value)) return 0;
	    value += 1;
      }
      return 1;
}

static int sdf_string_arg_is_blank(vpiHandle arg)
{
      s_vpi_value value;

      if (!arg || !is_string_obj(arg)) return 0;
      value.format = vpiStringVal;
      vpi_get_value(arg, &value);
      return value.value.str && sdf_string_is_blank(value.value.str);
}

/* Percent limits depend on the final IOPATH delays, so apply pulse records after parsing. */
struct sdf_pathpulse_annotation_s {
      struct sdf_pathpulse_annotation_s*next;
      vpiHandle cell;
      char*src;
      char*dst;
      int percent;
      struct sdf_delay_s reject;
      struct sdf_delay_s error;
      int lineno;
};

static struct sdf_pathpulse_annotation_s* sdf_pathpulse_head = NULL;
static struct sdf_pathpulse_annotation_s* sdf_pathpulse_tail = NULL;

static vpiHandle find_scope(vpiHandle scope, const char*name)
{
      vpiHandle idx = vpi_iterate(vpiModule, scope);
	/* If this scope has no modules then it can't have the one we
	 * are looking for so just return 0. */
      if (idx == 0) return 0;

      vpiHandle cur;
      while ( (cur = vpi_scan(idx)) ) {

	    if ( strcmp(name, vpi_get_str(vpiName,cur)) == 0) {
		  vpi_free_object(idx);
		  return cur;
	    }
      }

      return 0;
}

void sdf_warn_file_line(const int sdf_lineno)
{
      vpi_printf("SDF WARNING: %s:%d: loaded from %s:%d: ",
                 sdf_fname, sdf_lineno,
                 vpi_get_str(vpiFile, sdf_callh),
                 (int)vpi_get(vpiLineNo, sdf_callh));
}

/*
 * These functions are called by the SDF parser during parsing to
 * handling items discovered in the parse.
 */

void sdf_select_instance(const char*celltype, const char*cellinst, const int sdf_lineno)
{
      char buffer[128];

	/* Test for wildcard character */
      if (cellinst == NULL) {
	    if (sdf_flag_warning) {
		  vpi_printf("SDF WARNING: %s:%d: sorry: "
		             "Wildcard cell instance specification (*) currently not supported.\n",
		             sdf_fname, sdf_lineno);
	    }
	    sdf_cur_cell = 0;
	    return;
      }

	/* First follow the hierarchical parts of the cellinst name to
	   get to the cell that I'm looking for. */
      vpiHandle scope = sdf_scope;
      const char*src = cellinst;
      const char*dp;
      while ( (dp=strchr(src, '.')) ) {
	    unsigned len = dp - src;
	    assert(dp >= src);
	    assert(len < sizeof buffer);
	    strncpy(buffer, src, len);
	    buffer[len] = 0;

	    vpiHandle tmp_scope = find_scope(scope, buffer);
	    if (tmp_scope == 0) {
		  vpi_printf("SDF ERROR: %s:%d: Cannot find %s in scope %s.\n",
		             sdf_fname, sdf_lineno, buffer, vpi_get_str(vpiFullName, scope));
		  break;
	    }
	    assert(tmp_scope);
	    scope = tmp_scope;

	    src = dp + 1;
      }

	/* Now find the cell. */
      if (src[0] == 0)
	    sdf_cur_cell = sdf_scope;
      else
	    sdf_cur_cell = find_scope(scope, src);
      if (sdf_cur_cell == 0) {
	    vpi_printf("SDF ERROR: %s:%d: Unable to find %s in scope %s.\n",
	               sdf_fname, sdf_lineno, src, vpi_get_str(vpiFullName, scope));
	    return;
      }

	/* The scope that matches should be a module. */
      if (vpi_get(vpiType,sdf_cur_cell) != vpiModule) {
	    vpi_printf("SDF ERROR: %s:%d: Scope %s in %s is not a module.\n",
	               sdf_fname, sdf_lineno, src, vpi_get_str(vpiFullName, scope));
      }

	/* The matching scope (a module) should have the expected type. */
      if (strcmp(celltype,vpi_get_str(vpiDefName,sdf_cur_cell)) != 0) {
	    vpi_printf("SDF ERROR: %s:%d: Module %s in %s is not a %s; it is a ",
	               sdf_fname, sdf_lineno, src, vpi_get_str(vpiFullName, scope), celltype);
	    vpi_printf("%s\n", vpi_get_str(vpiDefName, sdf_cur_cell));
      }

}

static const char*edge_str(int vpi_edge)
{
      if (vpi_edge == vpiNoEdge)
	    return "";
      if (vpi_edge == vpiPosedge)
	    return "posedge ";
      if (vpi_edge == vpiNegedge)
	    return "negedge ";
      return "edge.. ";
}

static vpiHandle get_port_handle(char* port_name, const int sdf_lineno)
{
      vpiHandle scope = sdf_cur_cell;

	// Get occurences of '.' in the name
      int submodules = 0;

      for (int i=0; port_name[i] != '\0'; i++) {
	    if (port_name[i] == '.') submodules++;
      }

	// Extract the first token
      char* token = strtok(port_name, ".");;

	// Change scope into submodule
      while (submodules--) {
	    scope = vpi_handle_by_name(token, scope);

	    if (!scope) return NULL;

	      // Extract next token
	    token = strtok(NULL, ".");
      }

	// Iterate over ports
      vpiHandle port_i = vpi_iterate(vpiPort, scope) ;
      vpiHandle port;
      vpiHandle port_handle = NULL;

      while (port_i && (port=vpi_scan(port_i)) != NULL) {
	    const char *port_name_ = vpi_get_str(vpiName, port) ;

	    if (strcmp(port_name_, token) == 0) {
		  if (port_handle != NULL) {
			if (sdf_flag_warning) vpi_printf("SDF WARNING: %s:%d: Found multiple matching ports for %s !\n", sdf_fname, sdf_lineno, token);
		  }
		  port_handle = port;
	    }
      }

      return port_handle;
}


static void sdf_put_interconnect_delays(vpiHandle path,
                                       const struct sdf_delval_list_s*delval_list,
                                       const int sdf_lineno)
{
      s_vpi_delay delays;
      struct t_vpi_time delay_vals[12];
      delays.da = delay_vals;
      delays.no_of_delays = delval_list->count;
      delays.time_type = vpiScaledRealTime;
      delays.mtm_flag = 0;
      delays.append_flag = 0;
      delays.pulsere_flag = 0;
      vpi_get_delays(path, &delays);
      for (int idx = 0; idx < delval_list->count; idx += 1) {
            delay_vals[idx].type = vpiScaledRealTime;
            if (delval_list->val[idx].defined) {
                  if (sdf_flag_inform)
                        vpi_printf("SDF INFO: %s:%d: Putting delay: %f for index %d\n",
                                   sdf_fname, sdf_lineno, delval_list->val[idx].value, idx);
                  delay_vals[idx].real = delval_list->val[idx].value;
            }
      }
      vpi_put_delays(path, &delays);
}

void sdf_interconnect_delays(struct interconnect_port_s port1, struct interconnect_port_s port2,
                             const struct sdf_delval_list_s*delval_list,
                             const int sdf_lineno)
{

	// Get handles for both ports
	// After calling get_port_handle, the name is invalid
      vpiHandle port1_handle = get_port_handle(port1.name, sdf_lineno);
      vpiHandle port2_handle = get_port_handle(port2.name, sdf_lineno);

      if (!port1_handle && sdf_flag_warning)
	    vpi_printf("SDF WARNING: %s:%d: INTERCONNECT source port %s not found; annotating load port anyway.\n",
	               sdf_fname, sdf_lineno, port1.name);

      /* Only output and inout module ports are legal INTERCONNECT sources. */
      if (port1_handle) {
	    int direction = vpi_get(vpiDirection, port1_handle);
	    if (direction != vpiOutput && direction != vpiInout) {
	          const char*name = vpi_get_str(vpiName, port1_handle);
	          const char*direction_name = direction == vpiInput ? "input" : "neither output nor inout";
	          vpi_printf("SDF WARNING: %s:%d: INTERCONNECT source port %s has %s direction; source ports must be output or inout.\n",
	                     sdf_fname, sdf_lineno, name ? name : "<unknown>", direction_name);
	          return;
	    }
      }

      /* Only input and inout module ports are legal INTERCONNECT loads. */
      if (port2_handle) {
	    int direction = vpi_get(vpiDirection, port2_handle);
	    if (direction != vpiInput && direction != vpiInout) {
	          const char*name = vpi_get_str(vpiName, port2_handle);
	          const char*direction_name = direction == vpiOutput ? "output" : "neither input nor inout";
	          vpi_printf("SDF WARNING: %s:%d: INTERCONNECT load port %s has %s direction; load ports must be input or inout.\n",
	                     sdf_fname, sdf_lineno, name ? name : "<unknown>", direction_name);
	          return;
	    }
      }

	// Check whether we have a single bit of a port for port1
      if (port1.has_index && port1_handle) {
	    vpiHandle iter, vpi_port_bit;
	    iter = vpi_iterate(vpiBit, port1_handle);

	    if (!iter) {
		  vpi_printf("SDF ERROR: %s:%d: Could not find vpiBit iterator for port1!\n", sdf_fname, sdf_lineno);
		  return;
	    }

	    while ((vpi_port_bit = vpi_scan(iter))) {
		  int bit = vpi_get(vpiBit, vpi_port_bit);

		    // If we found the correct vpiPortBit, replace the port with it
		  if (port1.index == bit) {
			if (sdf_flag_inform) vpi_printf("SDF INFO: %s:%d: Substituting vpiPort with vpiPortBit for port1\n", sdf_fname, sdf_lineno);
			port1_handle = vpi_port_bit;
			vpi_release_handle(iter); // Free the iterator
			break;
		  }
	    }
	    if (!vpi_port_bit) {
		  vpi_printf("SDF ERROR: %s:%d: Could not find port1 bit %d!\n",
		             sdf_fname, sdf_lineno, port1.index);
		  return;
	    }
      }

	// Check whether we have a single bit of a port for port2
      if (port2.has_index && port2_handle) {
	    vpiHandle iter, vpi_port_bit;
	    iter = vpi_iterate(vpiBit, port2_handle);

	    if (!iter) {
		  vpi_printf("SDF ERROR: %s:%d: Could not find vpiBit iterator for port2!\n", sdf_fname, sdf_lineno);
		  return;
	    }

	    while ((vpi_port_bit = vpi_scan(iter))) {
		  int bit = vpi_get(vpiBit, vpi_port_bit);

		    // If we found the correct vpiPortBit, replace the port with it
		  if (port2.index == bit) {
			if (sdf_flag_inform) vpi_printf("SDF INFO: %s:%d: Substituting vpiPort with vpiPortBit for port2\n", sdf_fname, sdf_lineno);
			port2_handle = vpi_port_bit;
			vpi_release_handle(iter); // Free the iterator
			break;
		  }
	    }
	    if (!vpi_port_bit) {
		  vpi_printf("SDF ERROR: %s:%d: Could not find port2 bit %d!\n",
		             sdf_fname, sdf_lineno, port2.index);
		  return;
	    }
      }

      if (port2_handle) {
	      // Get interModPath for the two ports
	    bool part_select_endpoint =
	          (port1_handle && !port1.has_index &&
	           vpip_interconnect_port_uses_part_select(port1_handle)) ||
	          (port2_handle && !port2.has_index &&
	           vpip_interconnect_port_uses_part_select(port2_handle));
	    vpiHandle intermodpath;
	    if (port1.has_index || port2.has_index || part_select_endpoint)
		  intermodpath = vpi_handle_multi(vpiInterModPath, port1_handle, port2_handle);
	    else
		  intermodpath = vpip_interconnect_ports_connected(port1_handle, port2_handle);
	    int source_direction = port1_handle ? vpi_get(vpiDirection, port1_handle) : vpiOutput;
	    int load_direction = vpi_get(vpiDirection, port2_handle);
	    bool valid_endpoint_directions =
	          (source_direction == vpiOutput || source_direction == vpiInout) &&
	          (load_direction == vpiInput || load_direction == vpiInout);
	    if (!intermodpath && port1_handle && !port1.has_index &&
	        !port2.has_index && !part_select_endpoint && valid_endpoint_directions) {
		  if (sdf_flag_warning)
			vpi_printf("SDF WARNING: %s:%d: INTERCONNECT source port %s and load port %s are not on the same net; annotating load port anyway.\n",
			           sdf_fname, sdf_lineno, port1.name, port2.name);
		  intermodpath = vpip_interconnect_ports_connected(NULL, port2_handle);
	    }

	    if (intermodpath) {
		  if (sdf_flag_inform) vpi_printf("SDF INFO: %s:%d: Created a vpiInterModPath\n", sdf_fname, sdf_lineno);

		  sdf_put_interconnect_delays(intermodpath, delval_list, sdf_lineno);
	    } else {
		  vpi_printf("SDF ERROR: %s:%d: Could not find intermodpath!\n", sdf_fname, sdf_lineno);
	    }
      } else {
	    vpi_printf("SDF WARNING: %s:%d: Cannot annotate interconnect; both endpoints must be module ports.\n",
	               sdf_fname, sdf_lineno);
      }
}

static vpiHandle get_port_bit(vpiHandle port, struct interconnect_port_s spec,
                              const int sdf_lineno)
{
      if (!spec.has_index) return port;
      vpiHandle iter = vpi_iterate(vpiBit, port);
      vpiHandle bit;
      while (iter && (bit = vpi_scan(iter))) {
            if (vpi_get(vpiBit, bit) == spec.index) {
                  vpi_free_object(iter);
                  return bit;
            }
      }
      vpi_printf("SDF ERROR: %s:%d: Could not find port bit %d!\n",
                 sdf_fname, sdf_lineno, spec.index);
      return NULL;
}

static int sdf_apply_sources_to_load(vpiHandle scope, vpiHandle load,
                                     const struct sdf_delval_list_s*delval_list,
                                     const int sdf_lineno)
{
      int matches = 0;
      vpiHandle ports = vpi_iterate(vpiPort, scope);
      vpiHandle port;
      while (ports && (port = vpi_scan(ports))) {
            int direction = vpi_get(vpiDirection, port);
            if (direction != vpiOutput && direction != vpiInout) continue;
            vpiHandle path = vpip_interconnect_ports_connected(port, load);
            if (path) {
                  sdf_put_interconnect_delays(path, delval_list, sdf_lineno);
                  matches += 1;
            }
      }
      vpiHandle modules = vpi_iterate(vpiModule, scope);
      vpiHandle module;
      while (modules && (module = vpi_scan(modules)))
            matches += sdf_apply_sources_to_load(module, load, delval_list,
                                                 sdf_lineno);
      return matches;
}

void sdf_port_delays(struct interconnect_port_s port_spec,
                     const struct sdf_delval_list_s*delval_list,
                     const int sdf_lineno)
{
      if (!sdf_cur_cell) return;
      char*name = strdup(port_spec.name);
      if (!name) return;
      vpiHandle load = get_port_handle(name, sdf_lineno);
      free(name);
      if (!load) {
            vpi_printf("SDF ERROR: %s:%d: PORT target %s not found.\n",
                       sdf_fname, sdf_lineno, port_spec.name);
            return;
      }
      int direction = vpi_get(vpiDirection, load);
      if (direction != vpiInput && direction != vpiInout) {
            vpi_printf("SDF ERROR: %s:%d: PORT target %s is not an input or inout port.\n",
                       sdf_fname, sdf_lineno, port_spec.name);
            return;
      }
      load = get_port_bit(load, port_spec, sdf_lineno);
      if (!load) return;
      int matches = sdf_apply_sources_to_load(sdf_scope, load, delval_list,
                                              sdf_lineno);
      if (!matches) {
            vpi_printf("SDF ERROR: %s:%d: Could not find intermodpath for PORT %s.\n",
                       sdf_fname, sdf_lineno, port_spec.name);
      }
}

static int sdf_apply_netdelay_to_loads(vpiHandle scope, vpiHandle net,
                                      const struct sdf_delval_list_s*delval_list,
                                      const int sdf_lineno)
{
      int matches = 0;
      vpiHandle ports = vpi_iterate(vpiPort, scope);
      vpiHandle port;
      while (ports && (port = vpi_scan(ports))) {
            int direction = vpi_get(vpiDirection, port);
            if (direction != vpiInput && direction != vpiInout) continue;
            if (vpip_interconnect_through_net(net, port)) {
                  matches += sdf_apply_sources_to_load(sdf_scope, port,
                                                       delval_list, sdf_lineno);
            }
      }
      vpiHandle modules = vpi_iterate(vpiModule, scope);
      vpiHandle module;
      while (modules && (module = vpi_scan(modules)))
            matches += sdf_apply_netdelay_to_loads(module, net, delval_list,
                                                   sdf_lineno);
      return matches;
}

void sdf_netdelay_delays(struct interconnect_port_s target,
                         const struct sdf_delval_list_s*delval_list,
                         const int sdf_lineno)
{
      if (!sdf_cur_cell) return;

      char*port_name = strdup(target.name);
      vpiHandle port = port_name ? get_port_handle(port_name, sdf_lineno) : NULL;
      free(port_name);
      if (port) {
            int direction = vpi_get(vpiDirection, port);
            if (direction != vpiInput && direction != vpiInout) {
                  vpi_printf("SDF ERROR: %s:%d: NETDELAY target %s is not an input/inout port or net.\n",
                             sdf_fname, sdf_lineno, target.name);
                  return;
            }
            port = get_port_bit(port, target, sdf_lineno);
            if (!port) return;
            int matches = sdf_apply_sources_to_load(sdf_scope, port,
                                                    delval_list, sdf_lineno);
            if (!matches)
                  vpi_printf("SDF ERROR: %s:%d: Could not find intermodpath for NETDELAY %s.\n",
                             sdf_fname, sdf_lineno, target.name);
            return;
      }

      vpiHandle net = vpi_handle_by_name(target.name, sdf_cur_cell);
      if (!net || vpi_get(vpiType, net) != vpiNet) {
            vpi_printf("SDF ERROR: %s:%d: NETDELAY target %s is not an input/inout port or net.\n",
                       sdf_fname, sdf_lineno, target.name);
            return;
      }
      if (target.has_index) {
            net = vpi_handle_by_index(net, target.index);
            if (!net) {
                  vpi_printf("SDF ERROR: %s:%d: Could not find net bit %d!\n",
                             sdf_fname, sdf_lineno, target.index);
                  return;
            }
      }
      int matches = sdf_apply_netdelay_to_loads(sdf_cur_cell, net,
                                                delval_list, sdf_lineno);
      if (matches == 0)
            vpi_printf("SDF ERROR: %s:%d: No load ports found on NETDELAY net %s.\n",
                       sdf_fname, sdf_lineno, target.name);
}

void sdf_iopath_delays(int vpi_edge, const char*src, const char*dst,
                       const char*condition, int ifnone,
                       const struct sdf_delval_list_s*delval_list,
                       const int sdf_lineno)
{
      vpiHandle iter, path;
      int match_count = 0;

      if (sdf_cur_cell == 0)
	    return;

      iter = vpi_iterate(vpiModPath, sdf_cur_cell);

	/* Search for the modpath that matches the IOPATH by looking
	   for the modpath that uses the same ports as the ports that
	   the parser has found. */
      if (iter) while ( (path = vpi_scan(iter)) ) {
	    s_vpi_delay delays;
	    struct t_vpi_time delay_vals[12];
	    int idx;

	    vpiHandle path_t_in = vpi_handle(vpiModPathIn,path);
	    vpiHandle path_t_out = vpi_handle(vpiModPathOut,path);

	    vpiHandle path_in = vpi_handle(vpiExpr,path_t_in);
	    vpiHandle path_out = vpi_handle(vpiExpr,path_t_out);

	      /* The expressions for the path terms must be signals,
	         vpiNet or vpiReg. */
	    assert(vpi_get(vpiType,path_in) == vpiNet);
	    assert(vpi_get(vpiType,path_out) == vpiNet
		   || vpi_get(vpiType,path_out) == vpiReg);

	      /* If the src name doesn't match, go on. */
	    if (strcmp(src,vpi_get_str(vpiName,path_in)) != 0)
		  continue;
	      /* The edge type must match too. But note that if this
	         IOPATH has no edge, then it matches with all edges of
	         the modpath object. */
/* --> Is this correct in the context of the 10, 01, etc. edges? */
	    if (vpi_edge != vpiNoEdge && vpi_get(vpiEdge,path_t_in) != vpi_edge)
		  continue;

	      /* If the dst name doesn't match, go on. */
	    if (strcmp(dst,vpi_get_str(vpiName,path_out)) != 0)
		  continue;

	      /* An unqualified IOPATH applies to every matching path. A COND
	       * entry applies only to the path with the same condition, while a
	       * CONDELSE entry applies only to an ifnone path. */
	    if (ifnone) {
		  if (!vpi_get(_vpiModPathIfNone, path)) continue;
	    } else if (condition) {
		  const char*path_condition =
			vpi_get_str(_vpiModPathConditionText, path);
		  if (vpi_get(_vpiModPathIfNone, path)
		      || !path_condition || strcmp(condition, path_condition) != 0)
			continue;
	    }

	      /* Ah, this must be a match! */
	    delays.da = delay_vals;
	    delays.no_of_delays = delval_list->count;
	    delays.time_type = vpiScaledRealTime;
	    delays.mtm_flag = 0;
	    delays.append_flag = 0;
	    delays.pulsere_flag = 0;
	    vpi_get_delays(path, &delays);

	    for (idx = 0 ; idx < delval_list->count ; idx += 1) {
		  delay_vals[idx].type = vpiScaledRealTime;
		  if (delval_list->val[idx].defined) {
			delay_vals[idx].real = delval_list->val[idx].value;
		  }
	    }

	    vpi_put_delays(path, &delays);
	    match_count += 1;
      }

      if (match_count == 0) {
	    vpi_printf("SDF ERROR: %s:%d: Unable to match ModPath %s%s -> %s in %s\n",
	               sdf_fname, sdf_lineno,
	               edge_str(vpi_edge), src, dst,
	               vpi_get_str(vpiFullName, sdf_cur_cell));
      }
}

void sdf_pathpulse_delays(int percent, const char*src, const char*dst,
                          const struct sdf_delay_s*reject,
                          const struct sdf_delay_s*error,
                          const int sdf_lineno)
{
      if (sdf_cur_cell == 0)
	    return;

      struct sdf_pathpulse_annotation_s*entry =
	    malloc(sizeof(struct sdf_pathpulse_annotation_s));
      if (entry == NULL) {
	    vpi_printf("SDF ERROR: %s:%d: Unable to allocate PATHPULSE annotation\n",
	               sdf_fname, sdf_lineno);
	    return;
      }

      entry->next = NULL;
      entry->cell = sdf_cur_cell;
      entry->src = src ? strdup(src) : NULL;
      entry->dst = dst ? strdup(dst) : NULL;
      entry->percent = percent;
      entry->reject = *reject;
      entry->error = *error;
      entry->lineno = sdf_lineno;
      if ((src && entry->src == NULL) || (dst && entry->dst == NULL)) {
	    vpi_printf("SDF ERROR: %s:%d: Unable to allocate PATHPULSE path\n",
	               sdf_fname, sdf_lineno);
	    free(entry->src);
	    free(entry->dst);
	    free(entry);
	    return;
      }

      if (sdf_pathpulse_tail)
	    sdf_pathpulse_tail->next = entry;
      else
	    sdf_pathpulse_head = entry;
      sdf_pathpulse_tail = entry;
}

static void sdf_apply_pathpulse_annotations(void)
{
      while (sdf_pathpulse_head) {
	    struct sdf_pathpulse_annotation_s*entry = sdf_pathpulse_head;
	    vpiHandle iter = vpi_iterate(vpiModPath, entry->cell);
	    vpiHandle path;
	    int match_count = 0;

	    if (iter) while ((path = vpi_scan(iter))) {
		  s_vpi_delay delays;
		  struct t_vpi_time delay_vals[36];
		  vpiHandle path_t_out = vpi_handle(vpiModPathOut, path);
		  vpiHandle path_out = vpi_handle(vpiExpr, path_t_out);
		  int idx;

		  if (entry->src) {
			vpiHandle path_t_in = vpi_handle(vpiModPathIn, path);
			vpiHandle path_in = vpi_handle(vpiExpr, path_t_in);

			if (strcmp(entry->src, vpi_get_str(vpiName, path_in)) != 0 ||
			    strcmp(entry->dst, vpi_get_str(vpiName, path_out)) != 0)
			      continue;
		  }

		  delays.da = delay_vals;
		  delays.no_of_delays = 12;
		  delays.time_type = vpiScaledRealTime;
		  delays.mtm_flag = 0;
		  delays.append_flag = 0;
		  delays.pulsere_flag = 1;
		  vpi_get_delays(path, &delays);

		  for (idx = 0 ; idx < 12 ; idx += 1) {
			double delay = delay_vals[idx].real;
			if (entry->reject.defined) {
			      delay_vals[12+idx].real = entry->percent ?
				    delay * entry->reject.value / 100.0 : entry->reject.value;
			}
			if (entry->error.defined) {
			      delay_vals[24+idx].real = entry->percent ?
				    delay * entry->error.value / 100.0 : entry->error.value;
			} else if (entry->reject.defined) {
			      delay_vals[24+idx].real = delay_vals[12+idx].real;
			}
			delay_vals[idx].type = vpiScaledRealTime;
			delay_vals[12+idx].type = vpiScaledRealTime;
			delay_vals[24+idx].type = vpiScaledRealTime;
		  }

		  vpi_put_delays(path, &delays);
		  if (vpi_get(vpiSize, path_out) > 1) {
			vpi_printf("SDF WARNING: %s:%d: PATHPULSE filtering for vector "
			           "module-path outputs is not supported.\n",
			           sdf_fname, entry->lineno);
		  }
		  match_count += 1;
	    }

	    if (match_count == 0) {
		  vpi_printf("SDF WARNING: %s:%d: Unable to match PATHPULSE%s%s%s%s in %s\n",
		             sdf_fname, entry->lineno, entry->src ? " " : "",
		             entry->src ? entry->src : "", entry->dst ? " " : "",
		             entry->dst ? entry->dst : "",
		             vpi_get_str(vpiFullName, entry->cell));
	    }

	    sdf_pathpulse_head = entry->next;
	    if (sdf_pathpulse_head == NULL)
		  sdf_pathpulse_tail = NULL;
	    free(entry->src);
	    free(entry->dst);
	    free(entry);
      }
}

static void check_command_line_args(void)
{
      struct t_vpi_vlog_info vlog_info;
      int idx;

      static int sdf_command_line_done = 0;
      if (sdf_command_line_done)
	    return;

      vpi_get_vlog_info(&vlog_info);

      for (idx = 0 ;  idx < vlog_info.argc ;  idx += 1) {
	    if (strcmp(vlog_info.argv[idx],"-sdf-warn") == 0) {
		  sdf_flag_warning = 1;

	    } else if (strcmp(vlog_info.argv[idx],"-sdf-info") == 0) {
		  sdf_flag_inform = 1;

	    } else if (strcmp(vlog_info.argv[idx],"-sdf-verbose") == 0) {
		  sdf_flag_warning = 1;
		  sdf_flag_inform = 1;
	    }
      }

      sdf_command_line_done = 1;
}

static PLI_INT32 sys_sdf_annotate_compiletf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall,0);
      vpiHandle argv = vpi_iterate(vpiArgument, callh);
      vpiHandle module;

      check_command_line_args();

	/* Check that we have a file name argument. */
      if (argv == 0) {
	    vpi_printf("SDF ERROR: %s:%d: ", vpi_get_str(vpiFile, callh),
	               (int)vpi_get(vpiLineNo, callh));
	    vpi_printf("%s requires a file name argument.\n", name);
	    vpip_set_return_value(1);
	    vpi_control(vpiFinish, 1);
	    return 0;
      }
      if (! is_string_obj(vpi_scan(argv))) {
	    vpi_printf("SDF ERROR: %s:%d: ", vpi_get_str(vpiFile, callh),
	               (int)vpi_get(vpiLineNo, callh));
	    vpi_printf("%s's file name must be a string.\n", name);
	    vpip_set_return_value(1);
	    vpi_control(vpiFinish, 1);
      }

      /* The module argument is optional. */
      module = vpi_scan(argv);
      if (module == 0) return 0;
      if (module != 0 && vpi_get(vpiType, module) != vpiModule &&
	  !sdf_string_arg_is_blank(module)) {
	    vpi_printf("SDF ERROR: %s:%d: ", vpi_get_str(vpiFile, callh),
	               (int)vpi_get(vpiLineNo, callh));
	    vpi_printf("%s's second argument must be a module instance.\n",
	               name);
	    vpip_set_return_value(1);
	    vpi_control(vpiFinish, 1);
      }

      /* Remaining optional arguments are consumed by the call function. */
      if (vpi_scan(argv) != 0) vpi_free_object(argv);
      return 0;
}

static PLI_INT32 sys_sdf_annotate_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv = vpi_iterate(vpiArgument, callh);
      vpiHandle scope_arg, config_arg, log_arg, mtm_arg, scale_arg, type_arg;
      int argv_exhausted = 0;
      FILE *sdf_fd;
      char *fname = get_filename(callh, name, vpi_scan(argv));

      if (fname == 0) {
	    vpi_free_object(argv);
	    return 0;
      }

      if (sdf_flag_inform) {
	    vpi_printf("SDF INFO: Loading %s from %s:%d\n",
	               fname,
	               vpi_get_str(vpiFile, callh),
	               (int)vpi_get(vpiLineNo, callh));
      }

      sdf_fd = fopen(fname, "r");
      if (sdf_fd == 0) {
	    vpi_printf("SDF WARNING: %s:%d: ", vpi_get_str(vpiFile, callh),
	               (int)vpi_get(vpiLineNo, callh));
	    vpi_printf("Unable to open SDF file \"%s\"."
		       " Skipping this annotation.\n", fname);
	    vpi_free_object(argv);
	    free(fname);
	    return 0;
      }
      sdf_fname = fname;

	/* Preserve positional argument slots, including omitted optional arguments. */
	scope_arg = vpi_scan(argv);
	if (!scope_arg) argv_exhausted = 1;
	config_arg = argv_exhausted ? 0 : vpi_scan(argv);
	if (!config_arg && !argv_exhausted) argv_exhausted = 1;
	log_arg = argv_exhausted ? 0 : vpi_scan(argv);
	if (!log_arg && !argv_exhausted) argv_exhausted = 1;
	mtm_arg = argv_exhausted ? 0 : vpi_scan(argv);
	if (!mtm_arg && !argv_exhausted) argv_exhausted = 1;
	scale_arg = argv_exhausted ? 0 : vpi_scan(argv);
	if (!scale_arg && !argv_exhausted) argv_exhausted = 1;
	type_arg = argv_exhausted ? 0 : vpi_scan(argv);
	if (!type_arg && !argv_exhausted) argv_exhausted = 1;
	(void)config_arg;
	(void)log_arg;
	sdf_scope = scope_arg;
	if (!sdf_scope || sdf_string_arg_is_blank(sdf_scope))
	      sdf_scope = vpi_handle(vpiScope, callh);

	/* Select which delay to use. */
      sdf_min_typ_max = vpi_get(_vpiDelaySelection, 0);
	if (mtm_arg) {
	      s_vpi_value value;
	      value.format = vpiStringVal;
	      vpi_get_value(mtm_arg, &value);
	      if (value.value.str && !sdf_string_is_blank(value.value.str)) {
		    if (strcasecmp(value.value.str, "MINIMUM") == 0)
			  sdf_min_typ_max = _vpiDelaySelMinimum;
		    else if (strcasecmp(value.value.str, "TYPICAL") == 0)
			  sdf_min_typ_max = _vpiDelaySelTypical;
		    else if (strcasecmp(value.value.str, "MAXIMUM") == 0)
			  sdf_min_typ_max = _vpiDelaySelMaximum;
		    else if (strcasecmp(value.value.str, "TOOL_CONTROL") != 0)
			  vpi_printf("SDF WARNING: %s:%d: Unknown mtm_spec '%s'; using TOOL_CONTROL.\n",
			             vpi_get_str(vpiFile, callh),
			             (int)vpi_get(vpiLineNo, callh), value.value.str);
	      }
	}
	sdf_scale_factors[0] = sdf_scale_factors[1] = sdf_scale_factors[2] = 1.0;
	if (scale_arg) {
	      s_vpi_value value;
	      value.format = vpiStringVal;
	      vpi_get_value(scale_arg, &value);
	      if (value.value.str && !sdf_string_is_blank(value.value.str)) {
		    char extra;
		    if (sscanf(value.value.str, "%lf:%lf:%lf%c",
		               &sdf_scale_factors[0], &sdf_scale_factors[1],
		               &sdf_scale_factors[2], &extra) != 3) {
			  vpi_printf("SDF WARNING: %s:%d: Invalid scale_factors '%s'; using 1:1:1.\n",
			             vpi_get_str(vpiFile, callh),
			             (int)vpi_get(vpiLineNo, callh), value.value.str);
			  sdf_scale_factors[0] = sdf_scale_factors[1] = sdf_scale_factors[2] = 1.0;
		    }
	      }
	}
	sdf_scale_type = SDF_SCALE_FROM_MTM;
	if (type_arg) {
	      s_vpi_value value;
	      value.format = vpiStringVal;
	      vpi_get_value(type_arg, &value);
	      if (value.value.str && !sdf_string_is_blank(value.value.str)) {
		    if (strcasecmp(value.value.str, "FROM_MINIMUM") == 0)
			  sdf_scale_type = SDF_SCALE_FROM_MINIMUM;
		    else if (strcasecmp(value.value.str, "FROM_TYPICAL") == 0)
			  sdf_scale_type = SDF_SCALE_FROM_TYPICAL;
		    else if (strcasecmp(value.value.str, "FROM_MAXIMUM") == 0)
			  sdf_scale_type = SDF_SCALE_FROM_MAXIMUM;
		    else if (strcasecmp(value.value.str, "FROM_MTM") != 0)
			  vpi_printf("SDF WARNING: %s:%d: Unknown scale_type '%s'; using FROM_MTM.\n",
			             vpi_get_str(vpiFile, callh),
			             (int)vpi_get(vpiLineNo, callh), value.value.str);
	      }
	}
	if (!argv_exhausted) vpi_free_object(argv);

      sdf_cur_cell = 0;
      sdf_callh = callh;
      sdf_reset_timescale();
      sdf_process_file(sdf_fd, fname);
      sdf_apply_pathpulse_annotations();
      sdf_callh = 0;

      fclose(sdf_fd);
      sdf_fname = NULL;
      free(fname);
      return 0;
}

void sys_sdf_register(void)
{
      s_vpi_systf_data tf_data;
      vpiHandle res;

      tf_data.type      = vpiSysTask;
      tf_data.tfname    = "$sdf_annotate";
      tf_data.calltf    = sys_sdf_annotate_calltf;
      tf_data.compiletf = sys_sdf_annotate_compiletf;
      tf_data.sizetf    = 0;
      tf_data.user_data = "$sdf_annotate";
      res = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(res);
}
