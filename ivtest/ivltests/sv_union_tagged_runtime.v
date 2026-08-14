module test;
  typedef struct {
    bit [3:0] hi;
    bit [3:0] lo;
  } pair_t;

  typedef union tagged {
    void Invalid;
    bit [7:0] Byte;
    pair_t Pair;
  } value_t;

  value_t value;
  value_t copy;

  function automatic value_t make_byte(input bit [7:0] data);
    make_byte = tagged Byte(data);
  endfunction

  initial begin
    $display("DEFAULT %p", value);

    value = tagged Byte(8'ha5);
    $display("BYTE %p", value);
    if (value.Byte !== 8'ha5)
      $fatal(1, "active byte read failed: %h", value.Byte);

    copy = value;
    value = tagged Invalid;
    $display("INVALID %p", value);
    if (copy.Byte !== 8'ha5)
      $fatal(1, "tagged copy lost active member/value: %h", copy.Byte);

    copy = make_byte(8'h5a);
    $display("RETURN %p", copy);
    if (copy.Byte !== 8'h5a)
      $fatal(1, "tagged function return failed: %h", copy.Byte);

    value = tagged Pair '{4'hc, 4'h3};
    $display("PAIR %p", value);
    if (value.Pair.hi !== 4'hc || value.Pair.lo !== 4'h3)
      $fatal(1, "tagged aggregate member failed: %h/%h",
             value.Pair.hi, value.Pair.lo);

    $display("PASSED");
  end
endmodule
