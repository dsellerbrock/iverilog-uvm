module top;
  int data[2];
  initial begin
    do data[0]++; while (data[0] < 1);
    foreach (data[i]) data[i] = i;
    $check_vpi_loop_constants;
    $finish;
  end
endmodule
