module issue2618_assoc_fixed_array_copy;
  bit [7:0] m[int][3:2];
  bit [7:0] arr[3:2];

  initial begin
    m[0][3] = 8'h11;
    m[0][2] = 8'h22;
    arr = m[0];
    if (arr[3] !== 8'h11 || arr[2] !== 8'h22)
      $fatal(1, "associative fixed-array copy mismatch: %h %h",
             arr[3], arr[2]);
    $display("%h %h", arr[3], arr[2]);
  end
endmodule
