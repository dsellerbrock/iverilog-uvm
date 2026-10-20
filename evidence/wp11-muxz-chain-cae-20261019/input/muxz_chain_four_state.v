module muxz_chain_four_state;
  reg [255:0] d0, d1, d2, d3;
  reg s0, s1, s2;
  wire [255:0] result = s2 ? d3 : (s1 ? d2 : (s0 ? d1 : d0));
  reg [255:0] expected;

  function automatic reg state(input integer value);
    case (value)
      0: state = 1'b0;
      1: state = 1'b1;
      2: state = 1'bx;
      default: state = 1'bz;
    endcase
  endfunction

  function automatic reg mux_bit(input reg a, input reg b, input reg select);
    case (select)
      1'b0: mux_bit = a;
      1'b1: mux_bit = b;
      default: mux_bit = (a === b) ? a : 1'bx;
    endcase
  endfunction

  integer bit_index, selector_code;
  initial begin
    for (bit_index = 0; bit_index < 256; bit_index = bit_index + 1) begin
      d0[bit_index] = state(bit_index & 3);
      d1[bit_index] = state((bit_index >> 2) & 3);
      d2[bit_index] = state((bit_index >> 4) & 3);
      d3[bit_index] = state((bit_index >> 6) & 3);
    end

    for (selector_code = 0; selector_code < 64; selector_code = selector_code + 1) begin
      s0 = state(selector_code & 3);
      s1 = state((selector_code >> 2) & 3);
      s2 = state((selector_code >> 4) & 3);
      for (bit_index = 0; bit_index < 256; bit_index = bit_index + 1)
        expected[bit_index] = mux_bit(
          mux_bit(mux_bit(d0[bit_index], d1[bit_index], s0),
                  d2[bit_index], s1), d3[bit_index], s2);
      #1;
      if (result !== expected) begin
        $display("selector code %0d produced a mismatched mux result", selector_code);
        $fatal(1);
      end
    end

    $display("PASS");
    $finish;
  end
endmodule
