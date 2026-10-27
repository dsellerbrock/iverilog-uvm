module test;
  int descending[7:5];
  int ascending[0:2];
  int dynamic_copy[];
  logic [15:0] vector_value;
  logic [1:0][7:0] packed_copy;

  initial begin
    descending[7] = 11;
    descending[6] = 22;
    descending[5] = 33;
    ascending = descending;
    if (ascending[0] !== 11 || ascending[1] !== 22 || ascending[2] !== 33)
      $fatal(1, "whole-array copy did not preserve left-to-right order across bounds");

    dynamic_copy = descending;
    if (dynamic_copy.size() != 3 || dynamic_copy[0] !== 11
        || dynamic_copy[1] !== 22 || dynamic_copy[2] !== 33)
      $fatal(1, "fixed-to-dynamic whole-array assignment mismatch");

    vector_value = 16'hCAFE;
    packed_copy = vector_value;
    if (packed_copy[1] !== 8'hCA || packed_copy[0] !== 8'hFE)
      $fatal(1, "packed-array vector assignment mismatch");

    $display("PASS §7.6 whole-array and packed-vector assignment");
    $finish;
  end
endmodule
