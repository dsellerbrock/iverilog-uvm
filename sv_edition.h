#ifndef IVL_sv_edition_H
#define IVL_sv_edition_H
/*
 * Copyright (c) 2026 Stephen Williams (steve@icarus.com)
 *
 *    This source code is free software; you can redistribute it
 *    and/or modify it in source code form under the terms of the GNU
 *    General Public License as published by the Free Software
 *    Foundation; either version 2 of the License, or (at your option)
 *    any later version.
 *
 *    This program is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *    General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with this program; if not, write to the Free Software
 *    Foundation, Inc., 51 Franklin Street, Boston, MA 02110-1301, USA.
 */

/*
 * The single source of truth for the selectable language editions.
 *
 * Adding an edition means adding ONE row to SV_EDITION_TABLE. The
 * driver's `-g' parser, the driver's accepted-value error text, the
 * driver's SystemVerilog tests, the compiler's token -> generation_t
 * mapping, the lexer keyword-mask cascade and the verbose banner all
 * expand this same table, so an edition cannot be half-added.
 *
 * It is deliberately a plain X-macro rather than a data table: the
 * driver (`driver/main.c', C) and the compiler (`main.cc', C++) are
 * SEPARATE PROGRAMS that communicate only through the text
 * `generation:<token>' lines of the iconfig file. There is no shared
 * object file to hold a table, so the list used to be written out by
 * hand on both sides -- and in five further places besides. It had
 * already drifted: Documentation/usage/command_line_flags.rst still
 * omits `2005-sv', and driver/main.c's v2005_math.vpi test omitted it
 * too while its own comment claimed otherwise.
 *
 * Columns:
 *   TOKEN  the `-g<token>' spelling, which is also the token written
 *          into the iconfig file as `generation:<token>'
 *   GEN    the generation_t enumerator. Compiler-side only -- the
 *          driver's expansion of this table simply does not reference
 *          this parameter, so the enumerator name need not exist there.
 *   SV     1 for a SystemVerilog edition (IEEE 1800-*), else 0. This
 *          is the ONE place the driver may ask "is this edition
 *          SystemVerilog"; it mirrors the compiler's
 *          gn_system_verilog() (generation_flag >= GN_VER2005_SV).
 *   IEEE   the standard's name, used verbatim in diagnostics so a
 *          message can say which edition a construct needs.
 *
 * The rows are in edition order, oldest first. generation_t values
 * MUST keep that same order: a large amount of the compiler asks
 * ordered questions (`generation_flag >= GN_VER...'), and
 * gn_system_verilog() is exactly such a test, so a new edition placed
 * numerically above GN_VER2012 stays correct at ~275 call sites with
 * no edit. Placing one out of order would silently break all of them.
 */
#define SV_EDITION_TABLE						\
      SV_EDITION_ROW("1995",	      GN_VER1995,	   0,		\
		     "IEEE1364-1995")					\
      SV_EDITION_ROW("2001-noconfig", GN_VER2001_NOCONFIG, 0,		\
		     "IEEE1364-2001 (no config)")			\
      SV_EDITION_ROW("2001",	      GN_VER2001,	   0,		\
		     "IEEE1364-2001")					\
      SV_EDITION_ROW("2005",	      GN_VER2005,	   0,		\
		     "IEEE1364-2005")					\
      SV_EDITION_ROW("2005-sv",	      GN_VER2005_SV,	   1,		\
		     "IEEE1800-2005")					\
      SV_EDITION_ROW("2009",	      GN_VER2009,	   1,		\
		     "IEEE1800-2009")					\
      SV_EDITION_ROW("2012",	      GN_VER2012,	   1,		\
		     "IEEE1800-2012")					\
      SV_EDITION_ROW("2017",	      GN_VER2017,	   1,		\
		     "IEEE1800-2017")					\
      SV_EDITION_ROW("2023",	      GN_VER2023,	   1,		\
		     "IEEE1800-2023")

/*
 * `-glatest' selects the newest edition in the table. It is a spelling
 * of that edition, not an edition of its own: it resolves at option
 * parse time, so a design compiled with -glatest today and -g2023
 * today gets byte-identical treatment. Update this when a row is
 * appended.
 */
#define SV_EDITION_LATEST_TOKEN "2023"

/*
 * Feature -> introducing-edition table.
 *
 * This is the capability layer the compiler should ask, instead of
 * writing `generation_flag >= GN_VER...' at the use site. Asking by
 * FEATURE rather than by version number is what makes the diagnostic
 * possible: a raw comparison knows only that the test failed, while a
 * row here knows the construct's name AND the edition that introduces
 * it, so sv_require_feature() can say all three of the things a user
 * needs -- what construct, which edition, which flag -- without the
 * call site spelling any of them out.
 *
 * Columns:
 *   SYM   the sv_feature_t enumerator
 *   GEN   the generation_t of the edition that INTRODUCES the feature
 *   NAME  the construct, named as a user would recognize it in source
 *
 * NOTE ON IEEE 1800-2017: it is a maintenance/errata revision of
 * 1800-2012 and introduces NO new syntax, so no row here names
 * GN_VER2017 and none is expected to. -g2017 exists so a user can
 * state the edition they target (and because this fork documents
 * itself against 1800-2017), not because it gates anything.
 */
/* Iterator index querying was already present in SystemVerilog 3.1a
 * and IEEE 1800-2005 5.15.4. GN_VER2005 is Verilog-2005; the first
 * SystemVerilog generation in this table is GN_VER2005_SV. */
#define SV_FEATURE_TABLE						\
      SV_FEATURE_ROW(SVF_STACKTRACE, GN_VER2023,			\
		     "the $stacktrace system task")			\
      SV_FEATURE_ROW(SVF_ITERATOR_INDEX, GN_VER2005_SV,		\
		     "the `index' iterator method of an array "		\
		     "manipulation method")

#endif /* IVL_sv_edition_H */
