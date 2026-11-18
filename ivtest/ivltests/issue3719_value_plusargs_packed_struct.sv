module issue3719_value_plusargs_packed_struct;
  typedef struct packed {
    logic [63:0] hi;
    logic [63:0] lo;
  } pair_t;
  typedef struct packed {
    bit [7:0] hi;
    bit [7:0] lo;
  } bit_pair_t;

  logic [127:0] vec;
  pair_t pair;
  bit_pair_t bit_pair;
  int found;

  initial begin
    found = $value$plusargs("v=%h", vec);
    if (found != 1 || vec !== 128'h123456789abcdef0123)
      $fatal(1, "vector plusarg: found=%0d value=%h", found, vec);

    found = $value$plusargs("p=%h", pair);
    if (found != 1 || pair.hi !== 64'h0011223344556677 ||
                      pair.lo !== 64'h8899aabbccddeeff)
      $fatal(1, "packed struct plusarg: found=%0d value=%h", found, pair);

    found = $value$plusargs("absent=%h", pair);
    if (found != 0 || pair !== 128'h00112233445566778899aabbccddeeff)
      $fatal(1, "missing plusarg: found=%0d value=%h", found, pair);

    found = $value$plusargs("four=%h", pair);
    if (found != 1 || pair !== 128'h12xz)
      $fatal(1, "4-state packed struct plusarg: found=%0d value=%h", found, pair);

    found = $value$plusargs("two=%h", bit_pair);
    if (found != 1 || bit_pair !== 16'h1200)
      $fatal(1, "2-state packed struct plusarg: found=%0d value=%h", found, bit_pair);

    $display("PASSED");
  end
endmodule
