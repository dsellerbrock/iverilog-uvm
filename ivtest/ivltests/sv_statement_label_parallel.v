module test;
  integer sum = 0;
  integer escaped = 0;

  initial begin
    work: fork
      begin #1 sum += 1; end
      begin #2 sum += 2; end
    join: work

    escape: fork
      begin
        #1 escaped = 1;
        disable escape;
        escaped = 2;
      end
      begin #5 escaped = 3; end
    join: escape

    #6;
    if (sum != 3 || escaped != 1) begin
      $display("FAILED sum=%0d escaped=%0d", sum, escaped);
      $finish;
    end
    $display("PASSED");
  end
endmodule
