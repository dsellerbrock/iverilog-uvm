// Implementation-specific lowering regression. IEEE 1800-2017 7.12 makes
// locator results unpredictable when a with expression has side effects, so
// this is deliberately not a language-result oracle. It checks the compiler's
// internal contract that a key expression is lowered exactly once per source
// element, preventing duplicated function calls during decoration/dedup.
module main;
  logic [95:0] source[$];
  logic [95:0] result[$];
  int indexes[$];
  int key_calls;
  bit failed;

  function automatic logic [95:0] counted_key(input logic [95:0] value);
    key_calls = key_calls + 1;
    return value;
  endfunction

  task automatic check(input string label, input logic ok);
    if (ok !== 1'b1) begin
      $display("FAILED -- %0s", label);
      failed = 1'b1;
    end
  endtask

  initial begin
    failed = 1'b0;
    source = '{96'h000000010000000000000001,
               96'h000000020000000000000001,
               96'h000000010000000000000001,
               96'h00000003000000000000000x,
               96'h00000003000000000000000z};

    key_calls = 0;
    result = source.unique(value) with (counted_key(value));
    check("unique key lowered once per element", key_calls == source.size());

    key_calls = 0;
    indexes = source.unique_index(value) with (counted_key(value));
    check("unique_index key lowered once per element",
          key_calls == source.size());

    key_calls = 0;
    source.unique with (counted_key(item));
    check("discarded unique key lowered once per element",
          key_calls == source.size());
    check("lowering does not mutate receiver", source.size() == 5);

    if (failed)
      $fatal(1, "unique-with evaluation-count checks failed");
    $display("PASSED");
  end
endmodule
