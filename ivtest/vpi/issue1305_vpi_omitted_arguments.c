#include <sv_vpi_user.h>

#ifndef vpiOperation
#define vpiOperation 39
#endif

static PLI_INT32 calltf(PLI_BYTE8 *ud)
{
      (void)ud;

      vpiHandle call = vpi_handle(vpiSysTfCall, NULL);
      vpiHandle it = vpi_iterate(vpiArgument, call);
      vpiHandle arg;
      unsigned index = 0;
      int failed = 0;

      while (it && (arg = vpi_scan(it))) {
            int type = vpi_get(vpiType, arg);
            int subtype = type == vpiOperation ? vpi_get(vpiOpType, arg)
                        : type == vpiConstant ? vpi_get(vpiConstType, arg) : -1;
            int expected_type;
            int expected_subtype;

            switch (index) {
                case 0:
                  expected_type = vpiConstant;
                  expected_subtype = vpiBinaryConst;
                  break;
                case 1:
                  expected_type = vpiConstant;
                  expected_subtype = vpiStringConst;
                  break;
                case 2:
                case 4:
                  expected_type = vpiOperation;
                  expected_subtype = vpiNullOp;
                  break;
                case 3:
                  expected_type = vpiConstant;
                  expected_subtype = vpiNullConst;
                  break;
                default:
                  expected_type = -1;
                  expected_subtype = -1;
                  break;
            }

            if (type != expected_type || subtype != expected_subtype) {
                  vpi_printf("FAILED ARG %u type=%d subtype=%d\n",
                             index, type, subtype);
                  failed = 1;
            }
            index += 1;
      }

      if (index != 5) {
            vpi_printf("FAILED ARG_COUNT=%u\n", index);
            failed = 1;
      }
      if (!failed)
            vpi_printf("PASSED\n");
      return 0;
}

static void startup(void)
{
      s_vpi_systf_data data = {0};
      data.type = vpiSysTask;
      data.tfname = "$probe";
      data.calltf = calltf;
      vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = {startup, 0};
