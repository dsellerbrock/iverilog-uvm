#include <vpi_user.h>
#include <stdio.h>
#include <string.h>

/* These Annex K names are not yet exposed by the public Icarus header. */
#define vpiSchedEvent 53
#define vpiScheduled 46
#define vpiCancelEvent 7

static vpiHandle applied_event;
static vpiHandle canceled_event;
static int failed;

static void check(int condition, const char *message)
{
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message);
        failed = 1;
    }
}

static vpiHandle argument(vpiHandle *iter)
{
    return vpi_scan(*iter);
}

static PLI_INT32 schedule_calltf(PLI_BYTE8 *data)
{
    (void)data;
    vpiHandle call = vpi_handle(vpiSysTfCall, 0);
    vpiHandle iter = vpi_iterate(vpiArgument, call);
    vpiHandle applied = argument(&iter);
    vpiHandle canceled = argument(&iter);
    vpiHandle immediate = argument(&iter);
    s_vpi_value value = { .format = vpiIntVal, .value.integer = 1 };
    s_vpi_time delay = { .type = vpiSimTime, .high = 0, .low = 5 };

    applied_event = vpi_put_value(applied, &value, &delay,
                                  vpiInertialDelay | vpiReturnEvent);
    check(applied_event != NULL, "delayed write returned a handle");
    if (applied_event) {
        check(vpi_get(vpiType, applied_event) == vpiSchedEvent,
              "returned handle has type vpiSchedEvent");
        check(vpi_get(vpiScheduled, applied_event) == 1,
              "new event reports scheduled");
    }

    delay.low = 4;
    canceled_event = vpi_put_value(canceled, &value, &delay,
                                   vpiInertialDelay | vpiReturnEvent);
    check(canceled_event != NULL, "cancelable delayed write returned a handle");
    if (canceled_event) {
        check(vpi_get(vpiScheduled, canceled_event) == 1,
              "cancelable event reports scheduled before cancellation");
        vpi_put_value(canceled_event, NULL, NULL, vpiCancelEvent);
        check(vpi_get(vpiScheduled, canceled_event) == 0,
              "canceled event reports not scheduled");
    }

    value.value.integer = 2;
    check(vpi_put_value(immediate, &value, NULL, vpiNoDelay) == NULL,
          "no-delay write returns NULL");
    return 0;
}

static PLI_INT32 check_calltf(PLI_BYTE8 *data)
{
    (void)data;
    vpiHandle call = vpi_handle(vpiSysTfCall, 0);
    vpiHandle iter = vpi_iterate(vpiArgument, call);
    vpiHandle applied = argument(&iter);
    vpiHandle canceled = argument(&iter);
    vpiHandle immediate = argument(&iter);
    s_vpi_value value = { .format = vpiIntVal };

    vpi_get_value(applied, &value);
    check(value.value.integer == 1, "delayed value was applied");
    vpi_get_value(canceled, &value);
    check(value.value.integer == 0, "canceled value was not applied");
    check(applied_event && vpi_get(vpiScheduled, applied_event) == 0,
          "completed event reports not scheduled");
    check(canceled_event && vpi_get(vpiScheduled, canceled_event) == 0,
          "canceled event remains not scheduled");

    if (!failed)
        puts("PASSED");
    return 0;
}

static void register_tasks(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$issue956_schedule";
    data.calltf = schedule_calltf;
    vpi_register_systf(&data);

    memset(&data, 0, sizeof data);
    data.type = vpiSysTask;
    data.tfname = "$issue956_check";
    data.calltf = check_calltf;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
