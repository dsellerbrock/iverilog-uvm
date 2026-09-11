/* IEEE1800-2017/2023 5.9,38.15: raw literals as packed VPI words. */
#include "vpi_user.h"
#include <string.h>
static PLI_INT32 capture(PLI_BYTE8 *unused) {
  static unsigned calls;
  (void)unused;
  vpiHandle call=vpi_handle(vpiSysTfCall,0);
  vpiHandle args=vpi_iterate(vpiArgument,call);
  vpiHandle arg=vpi_scan(args);
  int width=vpi_get(vpiSize,arg);
  s_vpi_value value; value.format=vpiVectorVal;
  vpi_get_value(arg,&value);
  vpi_printf("case%u width=%d",calls++,width);
  for(int i=0;i<(width+31)/32;i++) vpi_printf(" word%d=%08x/%08x",i,(unsigned)value.value.vector[i].aval,(unsigned)value.value.vector[i].bval);
  vpi_printf("\n");
  vpi_free_object(args);
  return 0;
}
static void register_probe(void) {
  s_vpi_systf_data data; memset(&data,0,sizeof data);
  data.type=vpiSysTask;data.tfname="$literal_vector_probe";data.calltf=capture;
  vpi_register_systf(&data);
}
void (*vlog_startup_routines[])(void)={register_probe,0};
