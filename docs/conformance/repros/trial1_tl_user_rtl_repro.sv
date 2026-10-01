// Use the pinned trial1 FuseSoC source list, replacing its tb.sv and
// trial1_test.sv entries with this file. No UVM runtime is needed.
`timescale 1ns/1ps
`include "prim_assert_sec_cm.svh"

module trial1_tl_user_rtl_repro;
  import tlul_pkg::*;
  import trial1_reg_pkg::*;
  import prim_mubi_pkg::*;

  logic clk = 0;
  always #5 clk = ~clk;
  logic rst_n = 0;
  tl_h2d_t request, encoded_request;
  tl_d2h_t response;
  trial1_reg2hw_t reg2hw;
  trial1_hw2reg_t hw2reg;

`ifdef TRIAL1_BYPASS_CMD_INTG
  assign encoded_request = request;
`else
  tlul_cmd_intg_gen u_gen (.tl_i(request), .tl_o(encoded_request));
`endif
  trial1_reg_top u_dut (
    .clk_i(clk), .rst_ni(rst_n), .tl_i(encoded_request), .tl_o(response),
    .reg2hw(reg2hw), .hw2reg(hw2reg), .intg_err_o()
  );
  `ASSERT_PRIM_REG_WE_ONEHOT_ERROR_TRIGGER_ERR(Trial1RegWe, u_dut,
                                                u_dut.intg_err_o, 0, 2, clk, !rst_n)

  task automatic write_rwtype0(input mubi4_t instr_type,
                               input logic [31:0] data,
                               input logic expect_error);
    @(negedge clk);
    request.a_user.instr_type = instr_type;
    request.a_address = 0;
    request.a_data = data;
    request.a_mask = 4'hf;
    request.a_size = 2;
    request.a_opcode = PutFullData;
    request.a_valid = 1;
    @(posedge clk);
    #1;
    if (!response.d_valid || response.d_error !== expect_error)
      $fatal(1, "write response invalid: d_valid=%b d_error=%b expected=%b",
             response.d_valid, response.d_error, expect_error);
    @(negedge clk);
    request.a_valid = 0;
    @(posedge clk);
  endtask

  task automatic read_rwtype0(input mubi4_t instr_type,
                              input logic [31:0] expected_data,
                              input logic expect_error);
    @(negedge clk);
    request.a_user.instr_type = instr_type;
    request.a_address = 0;
    request.a_mask = 4'hf;
    request.a_size = 2;
    request.a_opcode = Get;
    request.a_valid = 1;
    @(posedge clk);
    #1;
    if (!response.d_valid || response.d_error !== expect_error
        || response.d_data !== expected_data)
      $fatal(1, "read response invalid: d_valid=%b d_error=%b data=%h expected_error=%b expected_data=%h",
             response.d_valid, response.d_error, response.d_data,
             expect_error, expected_data);
    @(negedge clk);
    request.a_valid = 0;
    @(posedge clk);
  endtask

  initial begin
    request = TL_H2D_DEFAULT;
    request.a_valid = 0;
    hw2reg = '0;
    repeat (3) @(negedge clk);
    rst_n = 1;
    // The pinned testbench's zero codeword must be rejected.
    write_rwtype0(mubi4_t'(4'h0), 32'hdeadbeef, 1'b1);
    read_rwtype0(mubi4_t'(4'h0), 32'hffffffff, 1'b1);
    if (reg2hw.rwtype0.q !== 32'd12345678)
      $fatal(1, "invalid write changed the register: %h", reg2hw.rwtype0.q);
    // The same commands with a valid MuBi codeword and generated integrity pass.
    write_rwtype0(MuBi4False, 32'hdeadbeef, 1'b0);
    read_rwtype0(MuBi4False, 32'hdeadbeef, 1'b0);
    if (reg2hw.rwtype0.q !== 32'hdeadbeef)
      $fatal(1, "valid write did not update the register: %h", reg2hw.rwtype0.q);
    $display("PASS");
    $finish;
  end
endmodule
