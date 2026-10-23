module sv_repeat_xz_count;
  logic [3:0] x_count = 4'bx;
  logic [3:0] z_count = 4'bz;
  logic [3:0] mixed_count = 4'b10xz;
  integer count;

  initial begin
    count = 0;
    repeat (x_count) begin
      count++;
      if (count > 5) break;
    end
    if (count != 0) $fatal(1, "repeat with x count executed %0d times", count);

    repeat (z_count) begin
      count++;
      if (count > 5) break;
    end
    if (count != 0) $fatal(1, "repeat with z count executed %0d times", count);

    repeat (mixed_count) begin
      count++;
      if (count > 5) break;
    end
    if (count != 0) $fatal(1, "repeat with x/z count executed %0d times", count);

    repeat (2) count++;
    if (count != 2) $fatal(1, "repeat with known count executed %0d times", count);
    $display("PASSED");
    $finish;
  end
endmodule
