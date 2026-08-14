module test;
  integer hits;
  integer eval_count [0:1];
  logic [1:0] left;
  logic [1:0] right;

  function automatic logic probe(input integer slot, input logic value);
    eval_count[slot] += 1;
    return value;
  endfunction

  initial begin
    hits = 0;

    // If truth is based on the whole expression, not comparison with 1.
    left = 2'b10;
    unique if (left) hits += 1;
    else             hits += 1000;

    // A priority chain stops after the first true condition.
    eval_count[0] = 0;
    eval_count[1] = 0;
    priority if (probe(0, 1'b1)) hits += 2;
    else if     (probe(1, 1'b1)) hits += 1000;
    if (eval_count[0] != 1 || eval_count[1] != 0) begin
      $display("FAILED priority evaluation counts %0d/%0d",
               eval_count[0], eval_count[1]);
      $finish;
    end

    // A unique chain evaluates every condition to detect overlap.
    eval_count[0] = 0;
    eval_count[1] = 0;
    unique if (probe(0, 1'b1)) hits += 4;
    else if   (probe(1, 1'b1)) hits += 1000;
    if (eval_count[0] != 1 || eval_count[1] != 1) begin
      $display("FAILED unique evaluation counts %0d/%0d",
               eval_count[0], eval_count[1]);
      $finish;
    end

    // No-match warnings differ between the three qualifiers.
    left = 0;
    right = 0;
    priority if (left)  hits += 1000;
    else if     (right) hits += 1000;
    unique if (left)    hits += 1000;
    else if   (right)   hits += 1000;
    unique0 if (left)   hits += 1000;
    else if    (right)  hits += 1000;

    // unique0 permits no match but, like unique, diagnoses overlap.
    left = 1;
    right = 2;
    unique0 if (left)       hits += 8;
    else if    (right)      hits += 1000;

    // A final else suppresses the no-match warning.
    left = 0;
    priority if (left) hits += 1000;
    else               hits += 16;
    unique if (left)   hits += 1000;
    else               hits += 32;

    if (hits == 63)
      $display("PASSED");
    else
      $display("FAILED hits=%0d", hits);
  end
endmodule
