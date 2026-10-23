typedef struct {
  logic valid;
  bit [8:1] data;
} MyType;

typedef struct {
  MyType item;
  bit [1:0] mode;
} OuterType;

module sv_bits_unpacked_struct;
  MyType mt;

  initial begin
    if ($bits(MyType) !== 9 || $bits(mt) !== 9 ||
        $bits(OuterType) !== 11) begin
      $display("FAILED: type=%0d var=%0d nested=%0d",
               $bits(MyType), $bits(mt), $bits(OuterType));
      $finish;
    end
    $display("PASSED");
  end
endmodule
