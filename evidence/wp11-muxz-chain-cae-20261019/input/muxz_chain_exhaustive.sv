module muxz_chain_exhaustive;
  reg [255:0] d0, d1, d2, d3;
  reg s0, s1, s2;
  wire [255:0] y = s2 ? d3 : (s1 ? d2 : (s0 ? d1 : d0));

  function automatic reg state(input integer value);
    case (value)
      0: state = 1'b0;
      1: state = 1'b1;
      2: state = 1'bx;
      default: state = 1'bz;
    endcase
  endfunction

  integer i, selector_code;
  initial begin
    for (i = 0; i < 256; i = i + 1) begin
      d0[i] = state(i & 3);
      d1[i] = state((i >> 2) & 3);
      d2[i] = state((i >> 4) & 3);
      d3[i] = state((i >> 6) & 3);
    end
    for (selector_code = 0; selector_code < 64; selector_code = selector_code + 1) begin
      s0 = state(selector_code & 3);
      s1 = state((selector_code >> 2) & 3);
      s2 = state((selector_code >> 4) & 3);
      #1 $display("%b", y);
    end
    $finish;
  end
endmodule
