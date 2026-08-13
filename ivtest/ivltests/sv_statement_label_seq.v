module test;
  int a;
  int b;
  int c;

  initial begin
    name: begin
      a = 1;
      b = a;
      c = b;
    end: name

    if (a != 1 || b != 1 || c != 1) begin
      $display("FAILED: sequential statement label lost block behavior");
      $finish;
    end

    escape: begin
      a = 2;
      disable escape;
      a = 3;
    end: escape

    if (a != 2) begin
      $display("FAILED: statement label did not create a disable target");
      $finish;
    end

    $display("PASSED");
  end
endmodule
