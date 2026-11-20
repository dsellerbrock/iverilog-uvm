/* IEEE 1800-2017 37.74 / 1800-2023 37.76: module and generate aliases. */
#include <stdio.h>
#include <string.h>
#include "vpi_user.h"
#include "sv_vpi_user.h"

#define IEEE_vpiAssignmentPatternOp 75

static unsigned failures;

static void expect(int ok, const char*what)
{
      if (!ok) {
            ++failures;
            vpi_printf("FAILED: %s\n", what);
      }
}

static vpiHandle lookup(vpiHandle scope, const char*name)
{
      vpiHandle h = vpi_handle_by_name(name, scope);
      expect(h != 0, name);
      return h;
}

static int integer(vpiHandle h)
{
      s_vpi_value value;
      if (!h) return vpiUndefined;
      value.format = vpiIntVal;
      vpi_get_value(h, &value);
      return value.value.integer;
}

static void bits_equal(vpiHandle h, const char*want)
{
      s_vpi_value value;
      if (!h) return;
      value.format = vpiBinStrVal;
      vpi_get_value(h, &value);
      expect(value.value.str && !strcmp(value.value.str, want), "live value");
}

static void check_location(vpiHandle stmt, vpiHandle scope, int line)
{
      const char*file = vpi_get_str(vpiFile, stmt);
      const char*name = "issue3059_vpi_alias_stmt.sv";
      size_t len = file ? strlen(file) : 0;
      size_t name_len = strlen(name);
      expect(len >= name_len && !strcmp(file + len - name_len, name),
             "source file");
      expect(vpi_get(vpiType, stmt) == vpiAliasStmt, "object type");
      expect(!strcmp(vpi_get_str(vpiType, stmt), "vpiAliasStmt"), "type name");
      expect(vpi_handle(vpiScope, stmt) == scope, "declaring scope");
      expect(vpi_get(vpiLineNo, stmt) == line, "source line");
}

static void check_concat(vpiHandle lhs, int pattern, vpiHandle top)
{
      vpiHandle it = vpi_iterate(vpiOperand, lhs);
      vpiHandle high = it ? vpi_scan(it) : 0;
      vpiHandle low = high ? vpi_scan(it) : 0;
      expect(vpi_get(vpiType, lhs) == vpiOperation, "operation object");
      expect(vpi_get(vpiOpType, lhs) ==
             (pattern ? IEEE_vpiAssignmentPatternOp : vpiConcatOp),
             "operation kind");
      expect(high == lookup(top, pattern ? "pat_hi" : "cat_hi"),
             "first operand");
      expect(low == lookup(top, pattern ? "pat_lo" : "cat_lo"),
             "second operand");
      if (low) expect(!vpi_scan(it), "operation arity");
}

static vpiHandle member(vpiHandle net, const char*name)
{
      vpiHandle it = vpi_iterate(vpiMember, net), item, result = 0;
      while (it && (item = vpi_scan(it))) {
            const char*actual = vpi_get_str(vpiName, item);
            if (actual && !strcmp(actual, name)) result = item;
      }
      expect(result != 0, name);
      return result;
}

static void check_part(vpiHandle lhs, vpiHandle parent, int indexed,
                       int left, int right)
{
      expect(vpi_get(vpiType, lhs) ==
             (indexed ? vpiIndexedPartSelect : vpiPartSelect), "select type");
      expect(parent && vpi_handle(vpiParent, lhs) == parent, "select parent");
      expect(vpi_get(vpiConstantSelect, lhs) == 1, "constant select");
      expect(integer(vpi_handle(indexed ? vpiBaseExpr : vpiLeftRange, lhs))
             == left, "select left bound or base");
      expect(integer(vpi_handle(indexed ? vpiWidthExpr : vpiRightRange, lhs))
             == right, "select right bound or width");
      if (indexed)
            expect(vpi_get(vpiIndexedPartSelectType, lhs) == vpiPosIndexed,
                   "indexed select direction");
}

static vpiHandle check_generate(vpiHandle top, const char*name, int bit)
{
      vpiHandle scope = lookup(top, name);
      if (!scope) return 0;
      vpiHandle it = vpi_iterate(vpiAliasStmt, scope);
      vpiHandle stmt = it ? vpi_scan(it) : 0;
      expect(stmt != 0, "generate alias");
      if (!stmt) return 0;
      check_location(stmt, scope, 55);
      char path[48];
      snprintf(path, sizeof path, "top.%s.x", name);
      expect(vpi_handle(vpiLhs, stmt) == lookup(0, path), "generate lhs");
      vpiHandle rhs = vpi_handle(vpiRhs, stmt);
      snprintf(path, sizeof path, "top.%s.y", name);
      expect(rhs == lookup(0, path), "generate rhs");
      bits_equal(rhs, bit ? "1" : "0");
      expect(!vpi_scan(it), "one alias in generate scope");
      return stmt;
}

static unsigned check_primitives(vpiHandle scope)
{
      vpiHandle it = vpi_iterate(vpiPrimitive, scope), item;
      unsigned count = 0;
      while (it && (item = vpi_scan(it))) {
            const char*name = vpi_get_str(vpiName, item);
            expect(name && !strcmp(name, "unit_switch") &&
                   vpi_get(vpiPrimType, item) == vpiTranPrim,
                   "only the source tran is a primitive");
            ++count;
      }
      it = vpi_iterate(vpiInternalScope, scope);
      while (it && (item = vpi_scan(it)))
            count += check_primitives(item);
      return count;
}

static PLI_INT32 inspect(PLI_BYTE8*unused)
{
      vpiHandle call = vpi_handle(vpiSysTfCall, 0);
      vpiHandle args = vpi_iterate(vpiArgument, call);
      vpiHandle phase_arg = args ? vpi_scan(args) : 0;
      int phase = integer(phase_arg);
      if (phase_arg) expect(!vpi_scan(args), "one probe argument");
      const char*two_bits = phase ? "01" : "10";
      const char*chain_bit = phase ? "0" : "1";
      const char*simple_bit = phase ? "1" : "0";
      static vpiHandle first_simple;
      vpiHandle top = lookup(0, "top"), stmt;
      vpiHandle chain_lhs[3], chain_rhs, simple_rhs;
      unsigned seen = 0, chain_seen = 0, count = 0;
      vpiHandle g0, g1, it, empty, parent;
      (void)unused;

      if (!top) goto done;
      chain_lhs[0] = lookup(top, "c0");
      chain_lhs[1] = lookup(top, "c1");
      chain_lhs[2] = lookup(top, "c2");
      chain_rhs = lookup(top, "c3");
      simple_rhs = lookup(top, "b");

      it = vpi_iterate(vpiAliasStmt, top);
      while (it && (stmt = vpi_scan(it))) {
            vpiHandle lhs = vpi_handle(vpiLhs, stmt);
            vpiHandle rhs = vpi_handle(vpiRhs, stmt);
            int line = vpi_get(vpiLineNo, stmt);
            ++count;
            check_location(stmt, top, line);
            expect(lhs && rhs, "two endpoint handles");
            if (!lhs || !rhs) continue;
            if (line == 11) {
                  unsigned idx;
                  expect(rhs == chain_rhs, "chain shares final RHS");
                  for (idx = 0; idx < 3 && lhs != chain_lhs[idx]; ++idx) {}
                  expect(idx < 3 && !(chain_seen & (1u << idx)),
                         "unique chain LHS");
                  chain_seen |= 1u << idx;
                  bits_equal(lhs, chain_bit);
                  bits_equal(rhs, chain_bit);
                  continue;
            }
            switch (line) {
                case 7:
                  expect(lhs == lookup(top, "a") && rhs == simple_rhs,
                         "direct net handles");
                  if (!phase) first_simple = stmt;
                  else expect(stmt == first_simple, "persistent alias handle");
                  bits_equal(lhs, simple_bit);
                  bits_equal(rhs, simple_bit);
                  seen |= 1u;
                  continue;
                case 16:
                  check_part(lhs, lookup(top, "ascending"), 0, 3, 4);
                  expect(rhs == lookup(top, "slice_rhs"), "slice RHS");
                  seen |= 2u;
                  break;
                case 21:
                  check_concat(lhs, 0, top);
                  expect(rhs == lookup(top, "cat_rhs"), "concat RHS");
                  seen |= 4u;
                  break;
                case 26:
                  parent = vpi_handle_by_index(lookup(top, "bank"), 2);
                  check_part(lhs, parent, 0, 4, 3);
                  expect(rhs == lookup(top, "word_rhs"), "word slice RHS");
                  seen |= 8u;
                  break;
                case 31:
                  parent = vpi_handle_by_index(lookup(top, "packed_bus"), 1);
                  check_part(lhs, parent, 1, 3, 2);
                  expect(rhs == lookup(top, "packed_rhs"), "packed slice RHS");
                  seen |= 16u;
                  break;
                case 36:
                  parent = lookup(top, "rows");
                  expect(lhs == vpi_handle_by_index(parent, 0), "packed row");
                  expect(rhs == lookup(top, "row_rhs"), "packed row RHS");
                  bits_equal(lhs, phase ? "0101" : "0110");
                  bits_equal(rhs, phase ? "0101" : "0110");
                  seen |= 32u;
                  continue;
                case 41:
                  check_concat(lhs, 1, top);
                  expect(rhs == lookup(top, "pat_rhs"), "pattern RHS");
                  seen |= 64u;
                  break;
                case 46:
                  parent = lookup(top, "bits");
                  expect(lhs == vpi_handle_by_index(parent, -1), "net bit");
                  expect(rhs == lookup(top, "bit_rhs"), "bit RHS");
                  bits_equal(lhs, simple_bit);
                  bits_equal(rhs, simple_bit);
                  seen |= 128u;
                  continue;
                case 64:
                  parent = vpi_handle_by_index(member(lookup(top, "record"), "f"), 1);
                  check_part(lhs, parent, 0, 3, 2);
                  expect(vpi_get(vpiSize, parent) == 4, "packed member row width");
                  expect(rhs == lookup(top, "member_rhs"), "packed member RHS");
                  seen |= 256u;
                  break;
                case 70:
                  expect(vpi_get(vpiType, lhs) == vpiNet &&
                         !strcmp(vpi_get_str(vpiName, lhs), "field.") &&
                         vpi_handle(vpiParent, lhs) == lookup(top, "odd"),
                         "escaped packed member");
                  expect(rhs == lookup(top, "odd_rhs"), "escaped member RHS");
                  seen |= 512u;
                  break;
                case 74:
                  expect(vpi_get(vpiType, lhs) == vpiNetArray &&
                         vpi_get(vpiType, rhs) == vpiNetArray,
                         "unpacked subarray operands");
                  expect(vpi_handle(vpiParent, lhs) == lookup(top, "matrix") &&
                         vpi_handle(vpiParent, rhs) == lookup(top, "matrix_rhs"),
                         "unpacked subarray parents");
                  expect(integer(vpi_handle(vpiLeftRange, lhs)) == 1 &&
                         integer(vpi_handle(vpiRightRange, lhs)) == 1,
                         "remaining unpacked dimension");
                  parent = vpi_handle_by_index(lhs, 1);
                  expect(parent != 0, "unpacked subarray word");
                  bits_equal(parent, two_bits);
                  seen |= 1024u;
                  continue;
                default:
                  expect(0, "unexpected alias source line");
                  continue;
            }
            bits_equal(lhs, two_bits);
            bits_equal(rhs, two_bits);
      }
      expect(count == 14 && seen == 2047 && chain_seen == 7,
             "exact module alias objects");

      g0 = check_generate(top, "g[0]", phase);
      g1 = check_generate(top, "g[1]", !phase);
      expect(g0 && g1 && g0 != g1, "distinct generate occurrences");
      empty = lookup(top, "no_alias");
      expect(empty && !vpi_iterate(vpiAliasStmt, empty), "alias-free instance");

      expect(check_primitives(top) == 1, "one source tran");

done:
      if (phase) {
            if (!failures) vpi_printf("issue3059 PASSED\n");
            vpi_control(vpiFinish, failures != 0);
      }
      return 0;
}

static void register_task(void)
{
      s_vpi_systf_data task = {0};
      task.type = vpiSysTask;
      task.tfname = "$inspect_alias";
      task.calltf = inspect;
      vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = {register_task, 0};
