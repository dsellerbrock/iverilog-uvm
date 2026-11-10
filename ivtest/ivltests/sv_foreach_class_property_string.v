class c_t;
  string name = "a.b.c";
endclass

module main;
  c_t o = new;
  int count;
  initial begin
    foreach (o.name[k]) begin
      if (k != count) $fatal(1, "bad string index %0d at iteration %0d", k, count);
      count++;
    end
    if (count != 5) $fatal(1, "expected five iterations, got %0d", count);
    o.name = "";
    foreach (o.name[k]) count++;
    if (count != 5) $fatal(1, "empty string iterated");
    $display("PASSED");
  end
endmodule
