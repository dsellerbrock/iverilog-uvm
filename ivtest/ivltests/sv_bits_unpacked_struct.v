typedef struct {
  logic valid;
  bit [8:1] data;
} MyType;

module sv_bits_unpacked_struct;
  MyType mt;
  logic [31:0] v;

  initial begin
    if ($bits(MyType) != 9) begin
      $display("FAIL type width: %0d", $bits(MyType));
      $fatal(1);
    end
    if ($bits(mt) != 9) begin
      $display("FAIL variable width: %0d", $bits(mt));
      $fatal(1);
    end
    if ($bits(v) != 32) begin
      $display("FAIL vector width: %0d", $bits(v));
      $fatal(1);
    end
    $display("PASSED");
  end
endmodule
