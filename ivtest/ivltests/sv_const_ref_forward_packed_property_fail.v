class sv_const_ref_forward_packed_property;
  typedef struct packed {
    logic ready;
    logic [2:0] code;
  } status_t;
  const status_t value = {1'b1, 3'd5};
endclass

module sv_const_ref_forward_packed_property_fail;
  sv_const_ref_forward_packed_property item;
  task automatic read_bit(const ref logic x);
    if (x) $display("bit");
  endtask
  initial begin
    item = new;
    read_bit(item.value.ready);
  end
endmodule
