// Nonstandard compatibility under -gcommercial-unsafe: a concatenation of
// untyped assignment patterns that fills a packed array of structs. IEEE
// 1800-2017/2023 10.9 gives '{...} a type only from an assignment-like
// context, and a concatenation operand is not one, so this is illegal.
// Commercial simulators give each operand the packed element type, and
// OpenTitan's spid DV (spid_common.sv, CmdInfo) relies on that. Strict mode
// still rejects it: see sv_concat_assign_pattern_fail.
module test;
  typedef enum logic [1:0] { M0, M1, M2 } mode_e;
  typedef struct packed {
    logic       valid;
    logic [7:0] opcode;
    mode_e      mode;
    logic [2:0] size;
  } info_t;

  parameter info_t [2:0] Info = {
    '{valid: 1'b1, opcode: 8'h04, mode: M2, size: '0},
    '{valid: 1'b0, opcode: 8'h06, mode: M1, size: 3'd5},
    '{valid: 1'b1, opcode: 8'hE9, mode: M0, size: '1}
  };

  info_t [1:0] v = { '{1'b0, 8'hAA, M1, 3'd2}, '{default: '1} };
  info_t [1:0] w;

  bit ok = 1;
  task check(bit c, string what);
    if (!c) begin $display("FAILED: %s", what); ok = 0; end
  endtask

  initial begin
    w = { '{valid: 1'b1, opcode: 8'h11, mode: M2, size: 3'd3},
          '{valid: 1'b0, opcode: 8'h22, mode: M0, size: 3'd4} };
    #1;
    check(Info[2].opcode == 8'h04 && Info[2].mode == M2 && Info[2].size == 0
          && Info[2].valid, "Info[2]");
    check(Info[1].opcode == 8'h06 && Info[1].mode == M1 && Info[1].size == 5
          && !Info[1].valid, "Info[1]");
    check(Info[0].opcode == 8'hE9 && Info[0].mode == M0 && Info[0].size == 7
          && Info[0].valid, "Info[0]");
    check(v[1].opcode == 8'hAA && v[1].mode == M1 && v[1].size == 2, "v[1]");
    check(v[0] == '1, "v[0]");
    check(w[1].opcode == 8'h11 && w[1].size == 3 && w[1].valid, "w[1]");
    check(w[0].opcode == 8'h22 && w[0].size == 4 && !w[0].valid, "w[0]");
    check($bits(Info) == 3 * $bits(info_t), "width");
    if (ok) $display("PASSED");
  end
endmodule
