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

# include  "compiler.h"
# include  "LineInfo.h"
# include  <iostream>
# include  <set>
# include  <string>

using namespace std;

static generation_t feature_edition_(sv_feature_t f)
{
#define SV_FEATURE_ROW(SYM, GEN, NAME) if (f == SYM) return GEN;
      SV_FEATURE_TABLE
#undef SV_FEATURE_ROW
      return GN_VER1995;
}

const char* sv_feature_name(sv_feature_t f)
{
#define SV_FEATURE_ROW(SYM, GEN, NAME) if (f == SYM) return NAME;
      SV_FEATURE_TABLE
#undef SV_FEATURE_ROW
      return "this construct";
}

static const char* edition_ieee_name_(generation_t g)
{
#define SV_EDITION_ROW(TOKEN, GEN, SV, IEEE) if (g == GEN) return IEEE;
      SV_EDITION_TABLE
#undef SV_EDITION_ROW
      return "a later IEEE edition";
}

static const char* edition_flag_token_(generation_t g)
{
#define SV_EDITION_ROW(TOKEN, GEN, SV, IEEE) if (g == GEN) return TOKEN;
      SV_EDITION_TABLE
#undef SV_EDITION_ROW
      return "latest";
}

bool sv_feature_available(sv_feature_t f)
{
      return generation_flag >= feature_edition_(f);
}

/*
 * Report a construct that the SELECTED edition does not include. The
 * message names all three things the user needs to act: the construct,
 * the edition that defines it, and the flag that selects that edition.
 * Callers bump their own layer's error counter (des->errors in
 * elaboration, error_count in pform) and recover however suits them.
 */
bool sv_require_feature(const LineInfo*li, sv_feature_t f)
{
      if (sv_feature_available(f))
	    return true;

	/* Report each (feature, source location) at most once.
	   Elaboration commonly visits an expression more than once (type
	   and width determination, then value), and without this the same
	   gate message printed two or three times for a single line. */
      static std::set<std::string> reported;
      generation_t need = feature_edition_(f);
      std::string key = li->get_fileline() + "|" + sv_feature_name(f);
      if (reported.insert(key).second) {
	    cerr << li->get_fileline() << ": error: " << sv_feature_name(f)
		 << " requires " << edition_ieee_name_(need)
		 << "; compile with -g" << edition_flag_token_(need)
		 << " (or -glatest)." << endl;
      }
      return false;
}
