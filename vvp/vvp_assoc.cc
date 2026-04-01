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
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with this program; if not, write to the Free Software
 *    Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

# include  "vvp_assoc.h"

vvp_assoc_base::~vvp_assoc_base()
{
}

const vvp_object* vvp_assoc_base::object_key_(const vvp_object_t&key)
{
      return key.peek<vvp_object>();
}

std::string vvp_assoc_base::vec4_key_(const vvp_vector4_t&key)
{
      unsigned wid = key.size();
      std::string out;
      out.resize(4 + wid);
      out[0] = static_cast<char>((wid >> 24) & 0xff);
      out[1] = static_cast<char>((wid >> 16) & 0xff);
      out[2] = static_cast<char>((wid >> 8) & 0xff);
      out[3] = static_cast<char>(wid & 0xff);
      for (unsigned idx = 0 ; idx < wid ; idx += 1)
	    out[4 + idx] = vvp_bit4_to_ascii(key.value(wid - idx - 1));
      return out;
}
