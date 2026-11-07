#ifndef IVL_sdf_priv_h
#define IVL_sdf_priv_h
/*
 * Copyright (c) 2007-2023 Stephen Williams (steve@icarus.com)
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

# include  <stdio.h>
# include  <stdbool.h>

/*
 * Invoke the parser to parse the opened SDF file. The fd is the SDF
 * file already opened and ready for reading. The path is the path to
 * the file and is only used for error messages.
 */
extern void sdf_process_file(FILE*fd, const char*path);

extern int sdf_flag_warning;
extern int sdf_flag_inform;
  /* Set while an INCREMENT construct is parsed: its values add to the
     annotated delays instead of replacing them (IEEE 1800 32.5). */
extern int sdf_increment;

extern int sdf_min_typ_max;
extern double sdf_scale_factors[3];
extern int sdf_scale_type;
extern void sdf_reset_timescale(void);
extern void sdf_set_timescale(double value, const char*unit, int sdf_lineno);
extern double sdf_time_scale(void);

enum sdf_scale_type_e {
      SDF_SCALE_FROM_MTM,
      SDF_SCALE_FROM_MINIMUM,
      SDF_SCALE_FROM_TYPICAL,
      SDF_SCALE_FROM_MAXIMUM
};

/* ****
 * These functions are called by the parser to process the SDF file as
 * it is parsed.
 */

struct sdf_delay_s {
      int defined;
      double value;
};

struct sdf_delval_list_s {
      int count;
      struct sdf_delay_s val[12];
};

struct port_with_edge_s {
      int vpi_edge;
      char*string_val;
};

struct interconnect_port_s {
      char* name;
      bool has_index;
      int index; // invalid if has_index is false
};

/* Annotate one LABEL entry (IEEE 1800 32.4.3) onto the specparam name of
   each selected cell. */
extern void sdf_label_value(const char*name, const struct sdf_delay_s*value,
                            const int sdf_lineno);

extern void sdf_select_instance(const char*celltype, const char*inst,
                                const int sdf_lineno);
extern void sdf_clear_instance_selection(void);

extern void sdf_iopath_delays(int vpi_edge, const char*src, const char*dst,
                              const char*condition, int ifnone,
                              const struct sdf_delval_list_s*delval,
                              const int sdf_lineno);

extern void sdf_device_delays(const char*dst,
                              const struct sdf_delval_list_s*delval,
                              const int sdf_lineno);

extern void sdf_pathpulse_delays(int percent, const char*src, const char*dst,
                                 const struct sdf_delay_s*reject,
                                 const struct sdf_delay_s*error,
                                 const int sdf_lineno);

extern void sdf_interconnect_delays(struct interconnect_port_s port1,
                                    struct interconnect_port_s port2,
                                    const struct sdf_delval_list_s*delval_list,
                                    const int sdf_lineno);
extern void sdf_port_delays(struct interconnect_port_s port,
                            const struct sdf_delval_list_s*delval_list,
                            const int sdf_lineno);
extern void sdf_netdelay_delays(struct interconnect_port_s net,
                               const struct sdf_delval_list_s*delval_list,
                               const int sdf_lineno);

#endif /* IVL_sdf_priv_h */

