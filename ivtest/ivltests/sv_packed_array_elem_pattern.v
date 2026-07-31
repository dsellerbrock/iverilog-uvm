// IEEE 1800-2017 10.9.2: an assignment pattern assigned to an ELEMENT of
// a PACKED array whose element type is a packed struct.
//
//     cmd_info_t [NumTotalCmdInfo-1:0] cmd_info;
//     cmd_info[i] = '{ valid: ..., opcode: ..., ... };
//
// That is OpenTitan spi_device.sv:631, and it was silently discarded.
// The l-value select recorded only its WIDTH, so NetAssign_::net_type()
// answered null; the pattern had no context to take its member types
// from, fell into the width-driven PEAssignPattern::elaborate_expr, and
// that overload merely WARNED and returned null. The caller dropped the
// statement and the compile succeeded. spi_device's whole command table
// stayed at zero in the compiled model.
//
// Both index forms are checked, because they take different paths in
// elaborate_lval_net_bit_: a constant index folds to an offset, a
// run-time index builds a computed base. And the packed array is read
// back BOTH element-wise and as one flat vector, so a pattern that
// landed in the wrong element or at the wrong bit offset is caught.
module sv_packed_array_elem_pattern;

  typedef struct packed {
    logic       valid;
    logic [7:0] opcode;
    logic [2:0] mode;
  } ci_t;

  localparam int N = 4;

  ci_t [N-1:0] ci;
  ci_t [N-1:0] cc;

  logic [7:0] src [N];
  integer errors = 0;

  task check(input integer got, input integer exp, input [127:0] what);
    begin
      if (got !== exp) begin
        $display("MISMATCH %0s: got %0d expected %0d", what, got, exp);
        errors = errors + 1;
      end
    end
  endtask

  initial begin
    src[0] = 8'h11; src[1] = 8'h22; src[2] = 8'h33; src[3] = 8'h44;

    // Run-time index.
    for (int unsigned i = 0; i < N; i++)
      ci[i] = '{ valid: 1'b1, opcode: src[i], mode: i[2:0] };

    // Constant indices, in a deliberately scrambled order so a pattern
    // written to the wrong element cannot pass.
    cc[2] = '{ valid: 1'b1, opcode: 8'h33, mode: 3'd2 };
    cc[0] = '{ valid: 1'b1, opcode: 8'h11, mode: 3'd0 };
    cc[3] = '{ valid: 1'b1, opcode: 8'h44, mode: 3'd3 };
    cc[1] = '{ valid: 1'b1, opcode: 8'h22, mode: 3'd1 };

    for (int unsigned i = 0; i < N; i++) begin
      $display("ci[%0d] = valid=%b opcode=%h mode=%0d",
               i, ci[i].valid, ci[i].opcode, ci[i].mode);
      check(ci[i].valid,  1,       "ci valid");
      check(ci[i].opcode, src[i],  "ci opcode");
      check(ci[i].mode,   i,       "ci mode");
    end

    // The two arrays were filled by different index forms and must be
    // bit-for-bit identical as whole packed vectors.
    if (ci !== cc) begin
      $display("MISMATCH whole vector: ci=%h cc=%h", ci, cc);
      errors = errors + 1;
    end

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED -- %0d mismatches", errors);
    $finish;
  end

endmodule
