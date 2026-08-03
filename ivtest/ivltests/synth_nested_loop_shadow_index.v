`begin_keywords "1800-2012"

module main;
  logic [1:0][1:0] source;
  logic [1:0][1:0] result;
  logic [1:0][1:0] generated_result;
  logic [1:0][1:0] sequential_result;
  integer index;

  // Both loops deliberately use the same index basename. The qualified outer
  // reference must retain its own identity and value while the inner loop is
  // active; substituting both references from a name-keyed map corrupts the
  // selected destination and the constant branch decision.
  always_comb begin : outer
    integer index;
    result = '0;
    for (index = 0; index < 2; index++) begin
      for (int index = 0; index < 2; index++) begin
        if (outer.index == 0)
          result[outer.index][index] = source[outer.index][index];
        else
          result[outer.index][index] = ~source[outer.index][index];
      end
    end
  end

  // The active outer index can be declared above the process synthesis
  // scope, too. A generate child must still find its exact value when the
  // inner loop shadows the basename.
  generate
    if (1) begin : generated
      always_comb begin
        generated_result = '0;
        sequential_result = '0;
        for (main.index = 0; main.index < 2; main.index++) begin
          for (int index = 0; index < 2; index++) begin
            if (main.index == 0)
              generated_result[main.index][index] =
                source[main.index][index];
            else
              generated_result[main.index][index] =
                ~source[main.index][index];
          end
        end
        // Reusing the same variable after, rather than inside, the first
        // loop is supported and proves the active identity entry was restored.
        for (main.index = 0; main.index < 2; main.index++) begin
          sequential_result[main.index] = source[main.index];
        end
      end
    end
  endgenerate

  task automatic check(input logic [3:0] stimulus,
                       input logic [3:0] expected);
    source = stimulus;
    #1;
    if (result !== expected || generated_result !== expected ||
        sequential_result !== source) begin
      $display("FAILED -- source=%b result=%b generated=%b sequential=%b expected=%b",
               source, result, generated_result, sequential_result, expected);
      $finish;
    end
  endtask

  (* ivl_synthesis_off *)
  initial begin
    check(4'b0110, 4'b1010);
    check(4'b1100, 4'b0000);
    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
