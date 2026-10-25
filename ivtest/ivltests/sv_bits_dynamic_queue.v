module test;
  byte stream[$];
  bit wait_done = 0;

  initial begin
    if ($bits(stream) !== 0)
      $fatal(1, "empty queue bits=%0d", $bits(stream));

    fork
      begin
        wait ($bits(stream) > 60);
        wait_done = 1;
      end
      begin
        repeat (8) begin
          #1;
          stream.push_back(0);
        end
      end
    join

    if (!wait_done || $bits(stream) !== 64)
      $fatal(1, "wait_done=%0b queue bits=%0d", wait_done, $bits(stream));

    $display("PASSED");
    $finish;
  end
endmodule
