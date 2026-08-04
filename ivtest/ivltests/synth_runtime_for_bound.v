`begin_keywords "1800-2012"

module main;
  logic [1:0] limit;
  logic [2:0] offset;
  logic [3:0][7:0] words;
  logic [63:0] result;

  // A finite-width run-time limit is synthesizable as one guarded hardware
  // copy per representable limit value. OpenTitan's RRAM controller uses this
  // shape to copy a variable number of OTP chunks into a packed word.
  always_comb begin
    result = '0;
    for (int unsigned k = 0; k <= limit; k++) begin
      result[(offset + k)*8 +: 8] = words[k];
    end
  end

  task automatic check_byte(input int index,
                            input logic [7:0] expected,
                            input string what);
    if (result[index*8 +: 8] !== expected) begin
      $display("FAILED %s byte %0d: got %h expected %h",
               what, index, result[index*8 +: 8], expected);
      $finish;
    end
  endtask

  (* ivl_synthesis_off *)
  initial begin
    words = 32'h44332211;

    offset = 3'd1;
    limit = 2'd0;
    #1;
    check_byte(0, 8'h00, "limit 0");
    check_byte(1, 8'h11, "limit 0");
    check_byte(2, 8'h00, "limit 0");

    limit = 2'd2;
    #1;
    check_byte(0, 8'h00, "limit 2");
    check_byte(1, 8'h11, "limit 2");
    check_byte(2, 8'h22, "limit 2");
    check_byte(3, 8'h33, "limit 2");
    check_byte(4, 8'h00, "limit 2");

    offset = 3'd3;
    limit = 2'd3;
    #1;
    check_byte(2, 8'h00, "limit 3");
    check_byte(3, 8'h11, "limit 3");
    check_byte(4, 8'h22, "limit 3");
    check_byte(5, 8'h33, "limit 3");
    check_byte(6, 8'h44, "limit 3");
    check_byte(7, 8'h00, "limit 3");

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
