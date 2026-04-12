module test;
  class C;
    int x;
  endclass

  C a[];
  C b[];

  initial begin
    a = new[1];
    a[0] = new;
    a[0].x = 5;

    b = a;

    if (b.size() != 1) begin
      $display("FAIL: size=%0d", b.size());
      $finish_and_return(1);
    end

    if ((b[0] == null) || (b[0].x != 5)) begin
      $display("FAIL: bad copied element");
      $finish_and_return(1);
    end

    $display("PASS");
    $finish;
  end
endmodule
