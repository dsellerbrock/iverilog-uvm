module sv_const_ref_forward_packed_select_fail;
  task automatic read_bit(const ref logic value);
    if (value) $display("bit");
  endtask
  task automatic forward(const ref logic [3:0] value);
    read_bit(value[0]);
  endtask
  task automatic from_mutable();
    logic [3:0] local_value;
    local_value = 4'h1;
    read_bit(local_value[0]);
  endtask
  logic [3:0] value;
  initial begin
    forward(value);
    from_mutable();
  end
endmodule
