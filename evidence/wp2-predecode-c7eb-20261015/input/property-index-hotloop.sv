class matrix_t;
  logic [7:0] values [1:0];
  function new();
    values[1] = 8'h13;
    values[0] = 8'h03;
  endfunction
endclass

module property_index_hotloop;
  matrix_t matrix;
  bit index;
  logic [7:0] actual;
  int unsigned checksum;

  initial begin
    matrix = new;
    for (int i = 0; i < 100000; i++) begin
      index = i[0];
      actual = matrix.values[index];
      if (actual !== (index ? 8'h13 : 8'h03))
        $fatal(1, "property index mismatch at iteration=%0d", i);
      checksum += actual;
    end
    if (checksum != 1100000)
      $fatal(1, "checksum mismatch: %0d", checksum);
    $display("PASS property-index hotloop (100000 accesses) sum=%0d", checksum);
    $finish;
  end
endmodule
