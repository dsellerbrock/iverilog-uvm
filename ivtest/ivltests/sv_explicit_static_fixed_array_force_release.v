// IEEE 1800-2017/2023 6.21 and 10.6.2: an explicit-static fixed array in an
// automatic task remains forceable. Releasing a variable retains its forced
// visible value until the next procedural assignment.
module sv_explicit_static_fixed_array_force_release;
  logic [7:0] source;

  task automatic exercise;
    static logic [7:0] words[0:0];

    words[0] = 8'h12;
    source = 8'h34;
    force words[0] = source;
    #1;
    if (words[0] !== 8'h34)
      $fatal(1, "initial force was suppressed: %h", words[0]);

    source = 8'h56;
    #1;
    if (words[0] !== 8'h56)
      $fatal(1, "linked force did not track its source: %h", words[0]);

    release words[0];
    if (words[0] !== 8'h56)
      $fatal(1, "variable release did not retain forced value: %h", words[0]);

    source = 8'h78;
    #1;
    if (words[0] !== 8'h56)
      $fatal(1, "released array word still tracked force source: %h", words[0]);

    words[0] = 8'h9a;
    if (words[0] !== 8'h9a)
      $fatal(1, "procedural assignment after release failed: %h", words[0]);
  endtask

  initial begin
    exercise();
    $display("PASSED");
  end
endmodule
