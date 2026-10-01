// uvm_hdl_read / uvm_hdl_deposit / uvm_hdl_check_path accept a trailing bit
// or part select on the HDL path ("top.u.st[6:0]", as OpenTitan's entropy_src
// scoreboard uses). A whole-path match, such as an array word, still wins.
`timescale 1ns/1ps
import uvm_pkg::*;

module top;
  logic [15:0] r   = 16'hA5C3;
  logic [0:7]  asc = 8'b1100_1010;
  logic [7:0]  mem [0:3];
  logic [7:0]  x_reg = 8'b10xz_0101;
  int errors;

  task automatic expect_read(string path, uvm_hdl_data_t want, int width);
    uvm_hdl_data_t got = '0;
    if (!uvm_hdl_read(path, got)) begin
      $display("FAIL: read %s refused", path); errors++;
    end else begin
      uvm_hdl_data_t mask = (uvm_hdl_data_t'(1) << width) - 1;
      if ((got & mask) !== (want & mask)) begin
        $display("FAIL: read %s = %h, want %h", path, got & mask, want & mask);
        errors++;
      end
    end
  endtask

  initial begin
    uvm_hdl_data_t v;
    mem[2] = 8'h5a;

    expect_read("top.r[7:4]", 'hC, 4);
    expect_read("top.r[15:12]", 'hA, 4);
    expect_read("top.r[3]", 0, 1);
    expect_read("top.r[0]", 1, 1);
    expect_read("top.asc[4:7]", 'hA, 4);
    expect_read("top.mem[2]", 'h5a, 8);
    expect_read("top.x_reg[7:4]", 'b10xz, 4);

    if (!uvm_hdl_check_path("top.r[7:4]")) begin $display("FAIL: check_path select"); errors++; end
    if (uvm_hdl_check_path("top.r[20:16]")) begin $display("FAIL: out of range accepted"); errors++; end
    if (uvm_hdl_check_path("top.nosuch[3:0]")) begin $display("FAIL: unknown base accepted"); errors++; end
    if (uvm_hdl_read("top.r[20:16]", v)) begin $display("FAIL: read out of range"); errors++; end

    v = 'h9;
    if (!uvm_hdl_deposit("top.r[7:4]", v)) begin $display("FAIL: deposit select"); errors++; end
    if (r !== 16'hA593) begin $display("FAIL: deposit r=%h, want a593", r); errors++; end

    if (errors == 0) $display("UVM HDL PART SELECT TEST: PASS");
    else $display("UVM HDL PART SELECT TEST: FAIL (%0d)", errors);
    $finish;
  end
endmodule
