#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "svdpi.h"

static int check_scope(int id)
{
      static const char* names[] = {
            "m10m_dpi_scope_instance_test.u_model0",
            "m10m_dpi_scope_instance_test.u_model1"
      };
      if (id < 0 || id > 1)
            return 5;
      svScope before = svGetScope();
      const char* before_name = before ? svGetNameFromScope(before) : 0;
      if (!before_name || strcmp(before_name, names[id]))
            return 1;
      svScope dut = svGetScopeFromName("m10m_dpi_scope_instance_test.dut");
      const char* dut_name = dut ? svGetNameFromScope(dut) : 0;
      if (!dut_name || strcmp(dut_name, "m10m_dpi_scope_instance_test.dut"))
            return 2;
      if (svSetScope(dut) != before || svGetScope() != dut)
            return 3;
      if (svSetScope(before) != dut || svGetScope() != before)
            return 4;
      return 0;
}

int scope_check_fn(int id)
{
      return check_scope(id);
}

int scope_check_task(int id)
{
      int result = check_scope(id);
      if (result) {
            fprintf(stderr, "DPI task scope mismatch: %d\n", result);
            exit(1);
      }
      return 0;
}
