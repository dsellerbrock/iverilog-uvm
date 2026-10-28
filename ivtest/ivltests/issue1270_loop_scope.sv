module top;
  int a[2];

  initial begin
    for (int i = 0; i < 2; i++) begin
      #0; $probe();
    end
    foreach (a[j]) begin
      #0; $probe();
    end
    #1; $finish;
  end
endmodule
