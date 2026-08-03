`begin_keywords "1800-2012"

module main;
  logic [14:0] source;
  logic [14:0] copied;
  logic [14:0] even_bits;

  // Ibex's interrupt priority encoder walks downward with i--. The synthesis
  // unroller must calculate next = current - step for both decrement and -=.
  always_comb begin
    copied = '0;
    for (int i = 14; i >= 0; i--)
      copied[i] = source[i];

    even_bits = '0;
    for (int i = 14; i >= 0; i -= 2)
      even_bits[i] = source[i];
  end

  task automatic check(input logic [14:0] value);
    source = value;
    #1;
    if (copied !== value || even_bits !== (value & 15'h5555)) begin
      $display("FAILED -- source=%h copied=%h even_bits=%h",
               source, copied, even_bits);
      $finish;
    end
  endtask

  (* ivl_synthesis_off *)
  initial begin
    check(15'h7fff);
    check(15'h2a5a);
    check(15'h4001);
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
