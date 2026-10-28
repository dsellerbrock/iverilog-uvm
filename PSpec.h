#ifndef IVL_PSpec_H
#define IVL_PSpec_H
/*
 * Copyright (c) 2006-2025 Stephen Williams <steve@icarus.com>
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

# include  "LineInfo.h"
# include  "StringHeap.h"
# include  <ostream>
# include  <vector>
# include  <list>

class PExpr;

struct pform_specify_terminal_t {
      pform_specify_terminal_t(perm_string name_arg,
                               perm_string member_arg = perm_string())
      : name(name_arg), member(member_arg) { }

      bool operator==(const pform_specify_terminal_t&that) const
      { return name == that.name && member == that.member; }
      bool operator!=(const pform_specify_terminal_t&that) const
      { return !(*this == that); }
      bool dotted() const { return !member.nil(); }

      perm_string name;
      perm_string member;
};

inline std::ostream& operator<<(std::ostream&out,
                                const pform_specify_terminal_t&terminal)
{
      out << terminal.name;
      if (terminal.dotted()) out << '.' << terminal.member;
      return out;
}

/*
* The PSpecPath is the parse of a specify path, which is in its most
* general form <path> = <delays>. The <delays> are collected into the
* "delays" vector in all cases, and the variety is in the other
* members.
*
* All paths also have a list of source names in the src vector, and a
* list of destination names in the dst vector. These pairs are the
* actual paths.
*
* If the path is a simple path, then:
*      condition == nil
*      edge == 0
*      data_source_expression == nil
*
* If the path is conditional, then conditional == true and condition
* is the condition expression. If the condition expression is nil,
* then this is an ifnone conditional path.
*
* If data_source_expression != nil, then the path is edge sensitive
* and the edge might not be 0.
*
* The full flag is used to verify that only vectors of the same size
* are used in a parallel connection. Icarus always creates a full
* connection between the source and destination. The polarity is for
* informational (display) purposes only. The polarity is either '+',
* '-' or 0.
*/
class PSpecPath  : public LineInfo {

    public:
      PSpecPath(const std::list<pform_specify_terminal_t> &src_list,
	        const std::list<pform_specify_terminal_t> &dst_list,
		char polarity, bool full_flag);
      ~PSpecPath() override;

      void elaborate(class Design*des, class NetScope*scope) const;
      void elaborate_bound_(class Design*des, class NetScope*scope) const;

      void dump(std::ostream&out, unsigned ind) const;

    public:
	// Condition expression, if present.
      bool conditional;
      class PExpr* condition;
	// Edge specification (-1==negedge, 0 = no edge, 1==posedge)
      int edge;
	// Is this a full connection.
      bool full_flag_;
	// What is the polarity of the connection.
      char polarity_;
	// Ordered set of source nodes of a path
      std::vector<pform_specify_terminal_t> src;
	// Ordered set of destination nodes of a path
      std::vector<pform_specify_terminal_t> dst;
	// Data source expression
      class PExpr* data_source_expression;

      std::vector<class PExpr*>delays;
};

#endif /* IVL_PSpec_H */
