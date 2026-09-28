module sv_const_ref_forward_type_fail;
  logic [7:0] value;
  task automatic read_nibble(const ref logic [3:0] x);
    if (x) $display("nibble");
  endtask
  task automatic forward(const ref logic [7:0] x);
    read_nibble(x);
  endtask
  initial forward(value);
endmodule
