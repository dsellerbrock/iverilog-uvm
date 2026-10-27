module main;
  let sq(int v) = v*v;
  let tl(logic [3:0] v) = v+1;
  let id(untyped v) = v;

  initial begin
    if (sq(-3) !== 32'd9) $fatal(1, "typed signed let cast failed");
    if (tl(8'h1f) !== 32'd16) $fatal(1, "typed packed let cast failed");
    if (id(5) !== 5) $fatal(1, "untyped let changed behavior");
    $display("PASSED");
  end
endmodule
