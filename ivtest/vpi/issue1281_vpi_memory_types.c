#include <assert.h>
#include <string.h>
#include "vpi_user.h"

static int failures;

static void check_type(vpiHandle obj, int expected, const char* type_name)
{
      assert(obj);
      int type = vpi_get(vpiType, obj);
      const char* name = vpi_get_str(vpiType, obj);
      if (type != expected || !name || strcmp(name, type_name) != 0) {
            vpi_printf("FAIL VPI type %d (%s), expected %d (%s)\n",
                       type, name ? name : "<null>", expected, type_name);
            failures += 1;
      }
}

#define CHECK_TYPE(obj, type) check_type(obj, type, #type)

static void check_typed_array(const char* path, int type, const char* type_name)
{
      vpiHandle array = vpi_handle_by_name(path, 0);
      CHECK_TYPE(array, vpiRegArray);
      check_type(vpi_handle_by_index(array, 0), type, type_name);
}

static PLI_INT32 check_memory_calltf(PLI_BYTE8* user_data)
{
      (void)user_data;
      vpiHandle top = vpi_handle_by_name("top", 0);
      vpiHandle mem = vpi_handle_by_name("top.mem", 0);
      assert(top);
      CHECK_TYPE(mem, vpiRegArray);

      vpiHandle memories = vpi_iterate(vpiMemory, top);
      assert(memories);
      vpiHandle scanned = vpi_scan(memories);
      CHECK_TYPE(scanned, vpiRegArray);
      assert(vpi_compare_objects(mem, scanned));
      vpiHandle extra = vpi_scan(memories);
      assert(!extra);

      vpiHandle words = vpi_iterate(vpiMemoryWord, scanned);
      assert(words);
      unsigned seen = 0;
      vpiHandle word;
      while ((word = vpi_scan(words))) {
            CHECK_TYPE(word, vpiReg);
            int idx = vpi_get(vpiIndex, word);
            assert(idx == 0 || idx == 1);
            assert(!(seen & (1U << idx)));
            seen |= 1U << idx;
            vpiHandle parent = vpi_handle(vpiParent, word);
            assert(parent && vpi_compare_objects(mem, parent));
            vpiHandle indexed = vpi_handle_by_index(mem, idx);
            CHECK_TYPE(indexed, vpiReg);
            assert(vpi_compare_objects(word, indexed));
            vpiHandle named = vpi_handle_by_name(idx ? "top.mem[1]" : "top.mem[0]", 0);
            CHECK_TYPE(named, vpiReg);
            assert(vpi_compare_objects(word, named));

            s_vpi_value val;
            val.format = vpiIntVal;
            vpi_get_value(indexed, &val);
            assert(val.value.integer == (idx ? 0xc5 : 0x2a));
      }
      assert(seen == 3);

      check_typed_array("top.typed.integers", vpiIntegerVar, "vpiIntegerVar");
      check_typed_array("top.typed.times", vpiTimeVar, "vpiTimeVar");
      check_typed_array("top.typed.reals", vpiRealVar, "vpiRealVar");
      vpiHandle nets = vpi_handle_by_name("top.typed.nets", 0);
      CHECK_TYPE(nets, vpiNetArray);
      CHECK_TYPE(vpi_handle_by_index(nets, 0), vpiNet);

      s_vpi_value updated;
      updated.format = vpiIntVal;
      updated.value.integer = 0x5c;
      vpi_put_value(vpi_handle_by_index(mem, 1), &updated, 0, vpiNoDelay);
      if (!failures) vpi_printf("VPI memory types PASS\n");
      return 0;
}

static void register_probe(void)
{
      s_vpi_systf_data tf = { vpiSysTask, 0, "$check_memory_types",
                            check_memory_calltf, 0, 0, 0 };
      vpi_register_systf(&tf);
}

void (*vlog_startup_routines[])(void) = { register_probe, 0 };
