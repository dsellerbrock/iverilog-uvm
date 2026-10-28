module sv_union_tagged_inactive_write_fail;
  typedef union tagged {
    void Empty;
    int Number;
    bit [7:0] Byte;
  } value_t;

  value_t value;

  initial begin
    value = tagged Byte(8'h5a);
    value.Number = 32'h12345678;
    $display("after: %p", value);
  end
endmodule
