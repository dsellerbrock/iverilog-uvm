module sv_ref_nested_container_alias_type_fail;
  class holder;
    int values[$];
  endclass
  holder h;
  task automatic accept_byte(ref byte value);
  endtask
  initial begin
    h = new;
    h.values.push_back(1);
    accept_byte(h.values[0]);
  end
endmodule
