// Reduced OTP shape: two packed partition access arrays and live banked RHS.
package p;
  typedef enum logic [7:0] {Zero = 8'h00} m_t;
  typedef struct packed {m_t read_lock, write_lock;} access_t;
endpackage

module dut;
  p::access_t [1:0] part_access, part_access_dai;
endmodule

module top;
  dut dut();
  p::m_t [1:0][1:0][1:0] read_values, write_values;
  bit [1:0] next_read_bank, next_write_bank;
  bit [1:0] selected_read, selected_write;
  bit [1:0] forced_read, forced_write;
  p::m_t expected_read[2][2], expected_write[2][2];
  int draws;

  function automatic p::m_t draw();
    draws++;
    return p::m_t'(8'(draws));
  endfunction

  task automatic check_all();
    for (int i = 0; i < 2; i++) begin
      if (forced_read[i]) begin
        if (dut.part_access[i].read_lock !== expected_read[i][0])
          $fatal(1, "part %0d read lane changed before re-force", i);
        if (dut.part_access_dai[i].read_lock !== expected_read[i][1])
          $fatal(1, "part %0d DAI read lane changed before re-force", i);
      end
      if (forced_write[i]) begin
        if (dut.part_access[i].write_lock !== expected_write[i][0])
          $fatal(1, "part %0d write lane changed before re-force", i);
        if (dut.part_access_dai[i].write_lock !== expected_write[i][1])
          $fatal(1, "part %0d DAI write lane changed before re-force", i);
      end
    end
  endtask

`ifdef GLOBAL_BANK
`define ADVANCE_BANK(NEXT, IDX) NEXT = ~NEXT;
`else
`define ADVANCE_BANK(NEXT, IDX) NEXT[IDX] = !NEXT[IDX];
`endif
`define FORCE_LOCK_BANKED(IDX, MEMBER, SELECTED, NEXT, VALUES, EXPECTED, FORCED) \
  if (SELECTED[IDX]) begin \
    if (NEXT[IDX]) begin \
      VALUES[1][IDX][0] = draw(); \
      #0; check_all(); \
      force dut.part_access[IDX].MEMBER = VALUES[1][IDX][0]; \
      EXPECTED[IDX][0] = VALUES[1][IDX][0]; \
      VALUES[1][IDX][1] = draw(); \
      #0; check_all(); \
      force dut.part_access_dai[IDX].MEMBER = VALUES[1][IDX][1]; \
      EXPECTED[IDX][1] = VALUES[1][IDX][1]; \
    end else begin \
      VALUES[0][IDX][0] = draw(); \
      #0; check_all(); \
      force dut.part_access[IDX].MEMBER = VALUES[0][IDX][0]; \
      EXPECTED[IDX][0] = VALUES[0][IDX][0]; \
      VALUES[0][IDX][1] = draw(); \
      #0; check_all(); \
      force dut.part_access_dai[IDX].MEMBER = VALUES[0][IDX][1]; \
      EXPECTED[IDX][1] = VALUES[0][IDX][1]; \
    end \
    FORCED[IDX] = 1; \
    `ADVANCE_BANK(NEXT, IDX) \
  end

`define FORCE_PART(IDX) \
  `FORCE_LOCK_BANKED(IDX, read_lock, selected_read, next_read_bank, read_values, expected_read, forced_read) \
  `FORCE_LOCK_BANKED(IDX, write_lock, selected_write, next_write_bank, write_values, expected_write, forced_write)

  initial begin
    dut.part_access = '0;
    dut.part_access_dai = '0;

    selected_read = 2'b01; selected_write = 2'b00;
    `FORCE_PART(0)
    #1; check_all();

    selected_read = 2'b10; selected_write = 2'b00;
    `FORCE_PART(1)
    #1; check_all(); // Partition 0 was skipped and must keep its old force.

    selected_read = 2'b01; selected_write = 2'b01;
    `FORCE_PART(0)
    #1; check_all(); // Read and write banks advance independently.

    selected_read = 2'b01; selected_write = 2'b00;
    `FORCE_PART(0)
    #1; check_all(); // Reuse partition 0 after another partition was skipped.

    selected_read = 2'b00; selected_write = 2'b10;
    `FORCE_PART(1)
    #1; check_all();

    release dut.part_access;
    release dut.part_access_dai;
    forced_read = '0;
    forced_write = '0;
    dut.part_access = '0;
    dut.part_access_dai = '0;
    #1;
    if (dut.part_access !== '0 || dut.part_access_dai !== '0)
      $fatal(1, "released packed arrays did not return to procedural drive");
    check_all();

    selected_read = 2'b01; selected_write = 2'b00;
    `FORCE_PART(0)
    #1; check_all(); // Re-force both lanes after releasing the packed arrays.
    if (draws != 14) $fatal(1, "unexpected draw count %0d", draws);
    $display("PASS %0d draws, both lanes, skipped partition, release/re-force", draws);
  end
`undef FORCE_PART
`undef FORCE_LOCK_BANKED
`undef ADVANCE_BANK
endmodule
