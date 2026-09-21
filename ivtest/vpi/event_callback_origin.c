#include <vpi_user.h>
#include <assert.h>
static int fired;
static PLI_INT32 on_change(p_cb_data cb)
{
 s_vpi_value value;
 vpiHandle target;
 (void)cb;
 if(fired) return 0;
 fired=1;
 target=vpi_handle_by_name("test.value",0);
 assert(target);
 value.format=vpiIntVal;
 value.value.integer=3;
 vpi_put_value(target,&value,0,vpiNoDelay);
 value.value.integer=2;
 vpi_put_value(target,&value,0,vpiNoDelay);
 return 0;
}
static PLI_INT32 arm(PLI_BYTE8*unused)
{
 s_vpi_time time={vpiSuppressTime,0,0,0};
 s_vpi_value value={.format=vpiSuppressVal};
 s_cb_data cb={0};
 (void)unused;
 cb.reason=cbValueChange; cb.cb_rtn=on_change;
 cb.obj=vpi_handle_by_name("test.tap",0);
 assert(cb.obj);
 cb.time=&time; cb.value=&value;
 assert(vpi_register_cb(&cb));
 return 0;
}
static void register_test(void)
{
 s_vpi_systf_data tf={0};
 tf.type=vpiSysTask; tf.tfname="$arm_atomic_callback"; tf.calltf=arm;
 vpi_register_systf(&tf);
}
void (*vlog_startup_routines[])(void)={register_test,0};
