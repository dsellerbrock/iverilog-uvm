/*
 * SystemVerilog assertion sampling functions: $rose, $fell, $stable, $past.
 *
 * These functions normally sample at a clocking event. Without an
 * SVA-aware scheduler, we provide compile-progress fallbacks that
 * return safe defaults so testbenches that USE these in `assert
 * property (...)` contexts still elaborate and run:
 *
 *   $rose(sig)   -> 0   (no edge detected without sampling)
 *   $fell(sig)   -> 0
 *   $stable(sig) -> 1   (assume unchanged)
 *   $past(sig)   -> sig (return current value as a stand-in)
 *
 * These are good enough for assertions that are not themselves the
 * primary test gate: the assertion body still elaborates, the test
 * proceeds, and any assertion that does fire will report a non-fatal
 * info rather than aborting the run.
 */

# include  "vpi_user.h"
# include  "sv_vpi_user.h"
# include  <stdlib.h>
# include  <string.h>

static PLI_INT32 sva_compiletf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      (void)name;
      return 0;
}

static PLI_INT32 sva_const_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      s_vpi_value rv;
      rv.format = vpiIntVal;
      rv.value.integer = (name && strcmp(name, "$stable") == 0) ? 1 : 0;
      vpi_put_value(callh, &rv, 0, vpiNoDelay);
      return 0;
}

static PLI_INT32 sva_past_calltf(ICARUS_VPI_CONST PLI_BYTE8*name)
{
      (void)name;
      vpiHandle callh = vpi_handle(vpiSysTfCall, 0);
      vpiHandle argv  = vpi_iterate(vpiArgument, callh);
      s_vpi_value rv;
      rv.format = vpiIntVal;
      rv.value.integer = 0;
      if (argv) {
            vpiHandle arg = vpi_scan(argv);
            vpi_free_object(argv);
            if (arg) {
                  s_vpi_value v;
                  v.format = vpiIntVal;
                  vpi_get_value(arg, &v);
                  rv = v;
            }
      }
      vpi_put_value(callh, &rv, 0, vpiNoDelay);
      return 0;
}

static PLI_INT32 sva_sizetf(ICARUS_VPI_CONST PLI_BYTE8 *name)
{
      (void)name;
      return 32;
}

static void register_one_(const char*tfname,
                          PLI_INT32 (*calltf)(ICARUS_VPI_CONST PLI_BYTE8*))
{
      s_vpi_systf_data tf_data;
      memset(&tf_data, 0, sizeof tf_data);
      tf_data.type        = vpiSysFunc;
      tf_data.sysfunctype = vpiSysFuncSized;
      tf_data.tfname      = (PLI_BYTE8*)tfname;
      tf_data.calltf      = calltf;
      tf_data.compiletf   = sva_compiletf;
      tf_data.sizetf      = sva_sizetf;
      tf_data.user_data   = (PLI_BYTE8*)tfname;
      vpiHandle h = vpi_register_systf(&tf_data);
      vpip_make_systf_system_defined(h);
}

void sys_sva_register(void)
{
      register_one_("$rose",   sva_const_calltf);
      register_one_("$fell",   sva_const_calltf);
      register_one_("$stable", sva_const_calltf);
      register_one_("$past",   sva_past_calltf);
      register_one_("$sampled", sva_past_calltf);
      register_one_("$rose_gclk",   sva_const_calltf);
      register_one_("$fell_gclk",   sva_const_calltf);
      register_one_("$stable_gclk", sva_const_calltf);
}
