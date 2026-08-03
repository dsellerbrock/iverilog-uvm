`begin_keywords "1800-2012"

module main;
  logic        write_enable;
  logic [11:0] address;
  logic [18:0] write_strobe;
  logic [2:0]  variable_select;
  logic [2:0]  variable_guard;
  logic [3:0]  variable_result;

  // Ibex decodes dozens of sparse 12-bit CSR addresses while updating many
  // outputs. Synthesis must scale with the explicit clauses, not construct a
  // 4,096-input mux for every output.
  always_comb begin
    write_strobe = '0;
    if (write_enable) begin
      unique case (address)
        12'h300: write_strobe[0]  = 1'b1;
        12'h304: write_strobe[1]  = 1'b1;
        12'h305: write_strobe[2]  = 1'b1;
        12'h340: write_strobe[3]  = 1'b1;
        12'h341: write_strobe[4]  = 1'b1;
        12'h342: write_strobe[5]  = 1'b1;
        12'h343: write_strobe[6]  = 1'b1;
        12'h7b0: write_strobe[7]  = 1'b1;
        12'h7b1: write_strobe[8]  = 1'b1;
        12'h7b2: write_strobe[9]  = 1'b1;
        12'h7b3: write_strobe[10] = 1'b1;
        12'hb00: write_strobe[11] = 1'b1;
        12'hb02: write_strobe[12] = 1'b1;
        12'hb03: write_strobe[13] = 1'b1;
        12'hb80: write_strobe[14] = 1'b1;
        12'hb82: write_strobe[15] = 1'b1;
        12'hb83: write_strobe[16] = 1'b1;
        12'hb9e: write_strobe[17] = 1'b1;
        12'hb9f: write_strobe[18] = 1'b1;
        default: ;
      endcase
    end
  end

  // Variable guards use exact ordinary-case matching, including X/Z bits,
  // while retaining first-match priority.
  always_comb begin
    variable_result = 4'hf;
    case (variable_select)
      3'd1:           variable_result = 4'h1;
      variable_guard: variable_result = 4'hc;
      default:        variable_result = 4'h0;
    endcase
  end

  task automatic check(input logic we, input logic [11:0] addr,
                       input logic [18:0] expected);
    write_enable = we;
    address = addr;
    #1;
    if (write_strobe !== expected) begin
      $display("FAILED -- we=%b address=%h got=%h expected=%h",
               we, addr, write_strobe, expected);
      $finish;
    end
  endtask

  task automatic check_variable(input logic [2:0] sel,
                                input logic [2:0] guard,
                                input logic [3:0] expected);
    variable_select = sel;
    variable_guard = guard;
    #1;
    if (variable_result !== expected) begin
      $display("FAILED -- select=%b guard=%b got=%h expected=%h",
               sel, guard, variable_result, expected);
      $finish;
    end
  endtask

  (* ivl_synthesis_off *)
  initial begin
    check(1'b0, 12'h300, '0);
    check(1'b1, 12'h300, 19'h0_0001);
    check(1'b1, 12'h7b2, 19'h0_0200);
    check(1'b1, 12'hb9f, 19'h4_0000);
    check(1'b1, 12'hfff, '0);
    check_variable(3'd1, 3'd1, 4'h1);
    check_variable(3'd2, 3'd2, 4'hc);
    check_variable(3'd3, 3'd2, 4'h0);
    check_variable(3'bx01, 3'bx01, 4'hc);
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
