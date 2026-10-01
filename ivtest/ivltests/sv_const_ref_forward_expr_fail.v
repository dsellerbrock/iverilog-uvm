module sv_const_ref_forward_expr_fail;
  int value;
  task automatic read_value(const ref int x);
    if (x) $display("value");
  endtask
  initial begin
    read_value(1);
    read_value(value + 1);
  end
endmodule
