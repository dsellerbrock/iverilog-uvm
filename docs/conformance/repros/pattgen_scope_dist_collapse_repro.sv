module pattgen_scope_dist_collapse_repro;
  bit [31:0] word;
  int nonzero;
  initial begin
    repeat (100) begin
      if (!std::randomize(word) with {
        word dist {32'hffffffff :/ 10, 32'h0 :/ 80,
                   [32'h1:32'hfffffffe] :/ 10};
      }) $fatal(1, "scope randomize failed");
      if (word != 0) nonzero++;
    end
    if (nonzero == 0) $fatal(1, "weighted scope draw collapsed to zero");
    $display("PASS nonzero=%0d", nonzero);
  end
endmodule
