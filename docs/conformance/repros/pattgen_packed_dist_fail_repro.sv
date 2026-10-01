class pattgen_packed_dist_cfg;
  rand bit [63:0] data;
endclass
module pattgen_packed_dist_fail_repro;
  pattgen_packed_dist_cfg cfg;
  initial begin
    cfg = new;
    if (!cfg.randomize() with {
      data[31:0] dist {32'hffffffff :/ 10, 32'h0 :/ 80,
                       [32'h1:32'hfffffffe] :/ 10};
      data[63:32] dist {32'hffffffff :/ 10, 32'h0 :/ 80,
                        [32'h0:32'hffffffff] :/ 10};
    }) $fatal(1, "packed half distribution failed");
    $display("PASS %h", cfg.data);
  end
endmodule
