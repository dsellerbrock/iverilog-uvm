// Reduced OpenTitan forms for IEEE 1800-2017/2023 7.9.11 associative-array
// assignment patterns:
//   * top-chip enum keys mapped to strings at declaration,
//   * CSRNG fixed outer arrays whose selected elements are string-key maps,
//   * lc_ctrl enum keys mapped to queue values at package scope.
package assoc_explicit_lc_state_pkg;
  typedef enum logic [2:0] {
    LcTestUnlocked = 3'd0,
    LcDev          = 3'd1,
    LcProd         = 3'd2,
    LcRma          = 3'd3,
    LcScrap        = 3'd4
  } lc_state_e;
endpackage

package assoc_explicit_opentitan_pkg;
  import assoc_explicit_lc_state_pkg::*;

  parameter string ROM_LCV_TEST_UNLOCKED = "02108421";
  parameter string ROM_LCV_DEV           = "21084210";
  parameter string ROM_LCV_PROD          = "2318c631";
  parameter string ROM_LCV_RMA           = "2739ce73";

  string lc_state_to_rom_lcv[assoc_explicit_lc_state_pkg::lc_state_e] = '{
    assoc_explicit_lc_state_pkg::LcTestUnlocked:ROM_LCV_TEST_UNLOCKED,
    assoc_explicit_lc_state_pkg::LcDev:ROM_LCV_DEV,
    assoc_explicit_lc_state_pkg::LcProd:ROM_LCV_PROD,
    assoc_explicit_lc_state_pkg::LcRma:ROM_LCV_RMA
  };

  // OpenTitan uses const instead of parameter because an associative array
  // cannot be a parameter. Each explicit element is a queue concatenation.
  const lc_state_e valid_next_states[lc_state_e][$] = '{
    LcRma:{LcScrap},
    LcProd:{LcScrap, LcRma},
    LcDev:{LcScrap, LcRma},
    LcTestUnlocked:{LcScrap, LcRma, LcProd, LcDev}
  };

  typedef string string_map_t[string];
  typedef string_map_t nested_string_map_t[int];

  // An explicit assignment pattern may recursively construct an associative
  // element value. Copies of the outer map must value-copy that inner map.
  nested_string_map_t nested_paths = '{
    0:'{"write":"wvld", "read":"rrdy", "state":"wrdy"},
    1:'{"write":"wrdy", "read":"rvld", "state":"rvld"}
  };
endpackage

module main;
  import assoc_explicit_lc_state_pkg::*;
  import assoc_explicit_opentitan_pkg::*;

  nested_string_map_t nested_copy;
  bit failed;

  task automatic check(input string label, input logic ok);
    if (ok !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  task automatic check_csrng_nested_maps;
    // These declarations and selected-outer-element assignments intentionally
    // retain the block-local shape used by OpenTitan's CSRNG sequences.
    string fifo_err_path[2][string];
    bit fifo_err_value[2][string];

    fifo_err_path[0] =
        '{"write":"wvld", "read":"rrdy", "state":"wrdy"};
    fifo_err_path[1] =
        '{"write":"wrdy", "read":"rvld", "state":"rvld"};
    fifo_err_value[0] =
        '{"write":1'b1, "read":1'b1, "state":1'b0};
    fifo_err_value[1] =
        '{"write":1'b0, "read":1'b0, "state":1'b0};
    check("CSRNG nested string maps",
          fifo_err_path[0].size() == 3 &&
          fifo_err_path[1].size() == 3 &&
          fifo_err_path[0]["write"] == "wvld" &&
          fifo_err_path[0]["read"] == "rrdy" &&
          fifo_err_path[1]["write"] == "wrdy" &&
          fifo_err_path[1]["state"] == "rvld");
    check("CSRNG nested integral maps",
          fifo_err_value[0].size() == 3 &&
          fifo_err_value[1].size() == 3 &&
          fifo_err_value[0]["write"] === 1'b1 &&
          fifo_err_value[0]["state"] === 1'b0 &&
          fifo_err_value[1]["read"] === 1'b0);
  endtask

  initial begin
    failed = 1'b0;

    // top-chip declaration initializer: enum-to-string map.
    check("top-chip enum map size", lc_state_to_rom_lcv.size() == 4);
    check("top-chip enum map values",
          lc_state_to_rom_lcv[LcTestUnlocked] == "02108421" &&
          lc_state_to_rom_lcv[LcDev] == "21084210" &&
          lc_state_to_rom_lcv[LcProd] == "2318c631" &&
          lc_state_to_rom_lcv[LcRma] == "2739ce73");
    check("top-chip omitted enum key",
          !lc_state_to_rom_lcv.exists(LcScrap) &&
          lc_state_to_rom_lcv[LcScrap] == "");

    // CSRNG procedural form: a selected element of a fixed outer array is a
    // complete associative-array lvalue and receives the explicit pattern.
    check_csrng_nested_maps();

    // lc_ctrl package form: enum-to-queue entries retain queue order, length,
    // and element type. The omitted key is not inserted.
    check("lc_ctrl enum-to-queue map size",
          valid_next_states.size() == 4);
    check("lc_ctrl singleton queue",
          valid_next_states[LcRma].size() == 1 &&
          valid_next_states[LcRma][0] == LcScrap);
    check("lc_ctrl ordered queue",
          valid_next_states[LcProd].size() == 2 &&
          valid_next_states[LcProd][0] == LcScrap &&
          valid_next_states[LcProd][1] == LcRma);
    check("lc_ctrl long queue",
          valid_next_states[LcTestUnlocked].size() == 4 &&
          valid_next_states[LcTestUnlocked][0] == LcScrap &&
          valid_next_states[LcTestUnlocked][1] == LcRma &&
          valid_next_states[LcTestUnlocked][2] == LcProd &&
          valid_next_states[LcTestUnlocked][3] == LcDev);
    check("lc_ctrl omitted enum key",
          !valid_next_states.exists(LcScrap));

    // Recursive associative values are independent value copies.
    nested_copy = nested_paths;
    nested_copy[0]["write"] = "changed";
    nested_copy[1].delete("state");
    check("nested associative value copy",
          nested_paths[0]["write"] == "wvld" &&
          nested_copy[0]["write"] == "changed" &&
          nested_paths[1].exists("state") &&
          !nested_copy[1].exists("state"));

    if (failed)
      $display("FAILED");
    else
      $display("PASSED");
  end
endmodule
