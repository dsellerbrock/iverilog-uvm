module top;
  int a[2];
  int k;
  initial begin
    for (k = 0; k < 2; k++) begin
      #0;
    end
    for (int i = 0; i < 2; i++) begin
      #0;
    end
    foreach (a[j]) begin
      #0;
    end
    #1 $finish;
  end
endmodule
