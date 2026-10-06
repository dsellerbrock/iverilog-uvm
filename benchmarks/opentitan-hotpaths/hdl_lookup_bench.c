#include "vpi_user.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static uint64_t name_lookups;
static uint64_t index_lookups;
static uint64_t value_gets;

static uint64_t cpu_ns(clock_t start)
{
    return (uint64_t)((double)(clock() - start) * 1000000000.0 / CLOCKS_PER_SEC);
}

static unsigned get_uint_arg(vpiHandle call, unsigned wanted)
{
    vpiHandle args = vpi_iterate(vpiArgument, call);
    vpiHandle arg = NULL;
    for (unsigned i = 0; args && i <= wanted; ++i)
        arg = vpi_scan(args);
    if (!arg)
        return 0;
    s_vpi_value value = { .format = vpiIntVal };
    vpi_get_value(arg, &value);
    return (unsigned)value.value.integer;
}

static int expected_byte(unsigned index)
{
    return (int)((index * 37U + 11U) & 0xffU);
}

static PLI_INT32 name_read32_calltf(PLI_BYTE8* user_data)
{
    (void)user_data;
    vpiHandle call = vpi_handle(vpiSysTfCall, NULL);
    const unsigned words = get_uint_arg(call, 0);
    const unsigned passes = get_uint_arg(call, 1);
    if (!words || !passes || (uint64_t)words * passes * 4 > 16384) {
        vpi_printf("FAIL name_read32 bounds\n");
        vpi_control(vpiFinish, 1);
        return 0;
    }

    clock_t start = clock();
    uint64_t reconstructed_words = 0;
    for (unsigned pass = 0; pass < passes; ++pass) {
        for (unsigned word = 0; word < words; ++word) {
            uint32_t result = 0;
            for (unsigned byte = 0; byte < 4; ++byte) {
                const unsigned index = (pass * words + word) * 4 + byte;
                char path[64];
                snprintf(path, sizeof(path), "top.mem[%u]", index);
                vpiHandle h = vpi_handle_by_name(path, NULL);
                ++name_lookups;
                if (!h) {
                    vpi_printf("FAIL name lookup: %s\n", path);
                    vpi_control(vpiFinish, 1);
                    return 0;
                }
                s_vpi_value value = { .format = vpiIntVal };
                vpi_get_value(h, &value);
                ++value_gets;
                const unsigned char actual = (unsigned char)value.value.integer;
                if (actual != expected_byte(index)) {
                    vpi_printf("FAIL name read index=%u got=%u expected=%u\n",
                               index, actual, expected_byte(index));
                    vpi_control(vpiFinish, 1);
                    return 0;
                }
                result |= (uint32_t)actual << (byte * 8);
            }
            const unsigned base = (pass * words + word) * 4;
            uint32_t expected = 0;
            for (unsigned byte = 0; byte < 4; ++byte)
                expected |= (uint32_t)expected_byte(base + byte) << (byte * 8);
            if (result != expected) {
                vpi_printf("FAIL read32 value mismatch\n");
                vpi_control(vpiFinish, 1);
                return 0;
            }
            ++reconstructed_words;
        }
    }
    vpi_printf("PASS name_read32 words=%llu full_name_lookups=%llu value_gets=%llu cpu_ns=%llu\n",
               (unsigned long long)reconstructed_words,
               (unsigned long long)name_lookups,
               (unsigned long long)value_gets,
               (unsigned long long)cpu_ns(start));
    return 0;
}

static PLI_INT32 indexed_read_calltf(PLI_BYTE8* user_data)
{
    (void)user_data;
    vpiHandle call = vpi_handle(vpiSysTfCall, NULL);
    const unsigned items = get_uint_arg(call, 0);
    const unsigned passes = get_uint_arg(call, 1);
    if (!items || !passes || (uint64_t)items * passes > 16384) {
        vpi_printf("FAIL indexed_read bounds\n");
        vpi_control(vpiFinish, 1);
        return 0;
    }
    vpiHandle base = vpi_handle_by_name("top.mem", NULL);
    if (!base) {
        vpi_printf("FAIL array base lookup\n");
        vpi_control(vpiFinish, 1);
        return 0;
    }
    ++name_lookups;

    clock_t start = clock();
    for (unsigned pass = 0; pass < passes; ++pass) {
        for (unsigned item = 0; item < items; ++item) {
            const unsigned index = pass * items + item;
            vpiHandle h = vpi_handle_by_index(base, (PLI_INT32)index);
            ++index_lookups;
            if (!h) {
                vpi_printf("FAIL indexed word lookup index=%u\n", index);
                vpi_control(vpiFinish, 1);
                return 0;
            }
            s_vpi_value value = { .format = vpiIntVal };
            vpi_get_value(h, &value);
            ++value_gets;
            const unsigned char actual = (unsigned char)value.value.integer;
            if (actual != expected_byte(index)) {
                vpi_printf("FAIL indexed read index=%u got=%u expected=%u\n",
                           index, actual, expected_byte(index));
                vpi_control(vpiFinish, 1);
                return 0;
            }
        }
    }
    vpi_printf("PASS indexed_read items=%llu array_base_lookups=1 index_lookups=%llu value_gets=%llu cpu_ns=%llu\n",
               (unsigned long long)((uint64_t)items * passes),
               (unsigned long long)index_lookups,
               (unsigned long long)value_gets,
               (unsigned long long)cpu_ns(start));
    return 0;
}

static void register_tasks(void)
{
    s_vpi_systf_data tf = { .type = vpiSysTask, .tfname = "$name_read32",
                            .calltf = name_read32_calltf };
    vpi_register_systf(&tf);
    tf.tfname = "$indexed_read";
    tf.calltf = indexed_read_calltf;
    vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_tasks, 0 };
