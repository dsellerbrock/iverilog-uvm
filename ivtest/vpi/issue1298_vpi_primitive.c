#include <string.h>
#include <vpi_user.h>

/* Keep the reducer buildable against pre-fix headers that omit these
 * standard object and subtype codes. */
#ifndef vpiPrimTerm
# define vpiPrimTerm 46
#endif
#ifndef vpiPrimitive
# define vpiPrimitive 103
#endif
#ifndef vpiTermIndex
# define vpiTermIndex 30
#endif
#ifndef vpiAndPrim
# define vpiAndPrim 1
#endif
#ifndef vpiNotPrim
# define vpiNotPrim 8
#endif
#ifndef vpiTranPrim
# define vpiTranPrim 22
#endif
#ifndef vpiTranif1Prim
# define vpiTranif1Prim 24
#endif

static int scalar_is(vpiHandle object, int expected)
{
      s_vpi_value value;
      if (!object) return 0;
      value.format = vpiScalarVal;
      vpi_get_value(object, &value);
      return value.value.scalar == expected;
}

static int scalar_value(vpiHandle object)
{
      s_vpi_value value;
      if (!object) return -1;
      value.format = vpiScalarVal;
      vpi_get_value(object, &value);
      return value.value.scalar;
}

static int check_terms(vpiHandle primitive, const int *directions,
		       const int *values, unsigned count)
{
      vpiHandle iter = vpi_iterate(vpiPrimTerm, primitive);
      vpiHandle term;
      unsigned index = 0;
      while (iter && (term = vpi_scan(iter))) {
	    vpiHandle expression = vpi_handle(vpiExpr, term);
	    int expected = values && index < count ? values[index] : vpiX;
	    if (index >= count || vpi_get(vpiType, term) != vpiPrimTerm ||
		vpi_get(vpiTermIndex, term) != (int)index ||
		vpi_get(vpiDirection, term) != directions[index] ||
		!expression || (values &&
		(!scalar_is(term, values[index]) ||
		 !scalar_is(expression, values[index])))) {
		  vpi_printf("primitive term %u type=%d index=%d direction=%d size=%d value=%d expected=%d\n",
			     index, vpi_get(vpiType, term),
			     vpi_get(vpiTermIndex, term),
			     vpi_get(vpiDirection, term),
			     expression ? vpi_get(vpiSize, expression) : -1,
			     scalar_value(term),
			     expected);
		  return 0;
	    }
	    index += 1;
      }
      return index == count;
}

static int check_primitive(const char *name, int primitive_type,
		   int input_count, const int *directions,
		   const int *values, unsigned term_count,
		   int output_value)
{
      vpiHandle primitive = vpi_handle_by_name((PLI_BYTE8 *)name, 0);
      const char *full_name;
      if (!primitive || vpi_get(vpiType, primitive) != vpiPrimitive ||
	  vpi_get(vpiPrimType, primitive) != primitive_type ||
	  vpi_get(vpiSize, primitive) != input_count) {
	    vpi_printf("primitive %s handle=%d type=%d subtype=%d inputs=%d expected subtype=%d inputs=%d\n",
		       name, primitive != 0,
		       primitive ? vpi_get(vpiType, primitive) : -1,
		       primitive ? vpi_get(vpiPrimType, primitive) : -1,
		       primitive ? vpi_get(vpiSize, primitive) : -1,
		       primitive_type, input_count);
	    return 0;
	  }
      full_name = vpi_get_str(vpiFullName, primitive);
      if (!full_name || strcmp(full_name, name) != 0) {
	    vpi_printf("primitive %s full name=%s\n", name,
		       full_name ? full_name : "(null)");
	    return 0;
	  }
      if (term_count && !check_terms(primitive, directions, values,
				     term_count)) {
	    vpi_printf("primitive %s terminal check failed\n", name);
	    return 0;
	  }
      return output_value < 0 || scalar_is(primitive, output_value);
}

static int check_udp_definition(vpiHandle primitive)
{
      static const char *rows[] = { "000", "010", "100", "111" };
      vpiHandle definition = vpi_handle(vpiUdpDefn, primitive);
      vpiHandle iter, entry;
      unsigned index = 0;
      const char *name;
      if (!definition || vpi_get(vpiType, definition) != vpiUdpDefn ||
	  vpi_get(vpiPrimType, definition) != vpiCombPrim ||
	  vpi_get(vpiSize, definition) != 2)
	    return 0;
      name = vpi_get_str(vpiDefName, definition);
      if (!name || strcmp(name, "myudp") != 0) return 0;
      iter = vpi_iterate(vpiTableEntry, definition);
      while (iter && (entry = vpi_scan(iter))) {
	    s_vpi_value value;
	    if (index >= sizeof rows / sizeof rows[0] ||
		vpi_get(vpiSize, entry) != (int)strlen(rows[index]))
		  return 0;
	    value.format = vpiStringVal;
	    vpi_get_value(entry, &value);
	    if (!value.value.str || strcmp(value.value.str, rows[index]) != 0)
		  return 0;
	    index += 1;
      }
      return index == sizeof rows / sizeof rows[0];
}

static PLI_INT32 check_primitive_vpi(PLI_BYTE8 *user_data)
{
      static const int gate_directions[] = { vpiOutput, vpiInput, vpiInput };
      static const int not_directions[] = { vpiOutput, vpiInput };
      static const int tran_directions[] = { vpiInout, vpiInout };
      static const int tranif_directions[] = { vpiInout, vpiInout, vpiInput };
      static const int and_values[] = { vpi0, vpi0, vpi0 };
      static const int not_values[] = { vpi1, vpi0 };
      static const int udp_values[] = { vpi0, vpi0, vpi0 };
      vpiHandle top, udp;
      vpiHandle iter, item;
      unsigned count = 0;
      int good;
      (void)user_data;

      top = vpi_handle_by_name((PLI_BYTE8 *)"issue1298_tb.top", 0);
      iter = top ? vpi_iterate(vpiPrimitive, top) : 0;
      while (iter && (item = vpi_scan(iter))) count += 1;
      good = top && count == 5;
      good = good && check_primitive("issue1298_tb.top.g", vpiAndPrim, 2,
					     gate_directions, and_values, 3, vpi0);
	good = good && check_primitive("issue1298_tb.top.inv", vpiNotPrim, 1,
					     not_directions, not_values, 2, vpi1);
	good = good && check_primitive("issue1298_tb.top.udp1", vpiCombPrim, 2,
					     gate_directions, udp_values, 3, vpi0);
      good = good && check_primitive("issue1298_tb.top.tr", vpiTranPrim, 0,
					     tran_directions, 0, 2, -1);
      good = good && check_primitive("issue1298_tb.top.tr_en", vpiTranif1Prim, 1,
					     tranif_directions, 0, 3, -1);
	udp = vpi_handle_by_name((PLI_BYTE8 *)"issue1298_tb.top.udp1", 0);
      good = good && udp && check_udp_definition(udp);
      if (good)
	    vpi_printf("PASS: issue1298 primitive VPI objects, terminals, and UDP definition\nPASSED\n");
      else
	    vpi_printf("FAIL: issue1298 primitive VPI object model count=%u\n", count);
      return 0;
}

static void register_check(void)
{
      s_vpi_systf_data task;
      memset(&task, 0, sizeof task);
      task.type = vpiSysTask;
      task.tfname = "$check_primitive_vpi";
      task.calltf = check_primitive_vpi;
      vpi_register_systf(&task);
}

void (*vlog_startup_routines[])(void) = { register_check, 0 };
