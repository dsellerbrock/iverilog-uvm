checker check_ports(output bit o,
                    input sequence s, next_s,
                    (* formal_attr *) input property p, next_p,
                    input logic [1:0] value, next_value,
                    output bit q, next_q);
  assign o = &value;
  assign q = &next_value;
  assign next_q = |next_value;
endchecker

// A new checker starts with input direction, even after an output list.
checker implicit_input((* formal_attr *) sequence s, next_s,
                       property p, (* formal_attr *) next_p);
endchecker

module issue3861_top;
  wire o, q, next_q;
  check_ports c(o, 1'b1, 1'b0, 1'b1, 1'b0, 2'b11, 2'b01, q, next_q);

  initial begin
    #1;
    if ({o, q, next_q} !== 3'b101)
      $fatal(1, "checker output mismatch: %b", {o, q, next_q});
    $display("PASS");
  end
endmodule
