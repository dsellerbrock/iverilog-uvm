module main;
  typedef bit node;

  node scalar;
  node [2:0] vector;
  node [7:5] offset_vector;

  initial begin
    if ($typename(scalar) != "bit") begin
      $display("FAILED scalar: got `%s`", $typename(scalar));
    end else if ($typename(vector) != "bit [2:0]") begin
      $display("FAILED vector: got `%s`", $typename(vector));
    end else if ($typename(offset_vector) != "bit [7:5]") begin
      $display("FAILED offset vector: got `%s`", $typename(offset_vector));
    end else begin
      $display("PASSED");
    end
    $finish;
  end
endmodule
