module p06_24f;
  int arr[2];
  int r;
  initial begin
    arr = '{7, 8};
    r = $cast(arr, 1);
    $display("INFO nonsingular_fn r=%0d arr=%0d,%0d", r, arr[0], arr[1]);
    $cast(arr, 1);
    $display("INFO nonsingular_task arr=%0d,%0d", arr[0], arr[1]);
    $display("REACHED_END");
  end
endmodule
