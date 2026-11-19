class probe #(parameter bit EXPECTED = 1'b1);
  int passed, failed, sibling_passed;

  function void check(logic value, bit enabled = 1);
    if (enabled)
      $asserton(0, body.verdict);
    else
      $assertoff(0, body.verdict);

    begin : body
      verdict: assert (value == EXPECTED) passed++;
               else failed++;
    end
    assert (1) sibling_passed++;
  endfunction
endclass

module top;
  initial begin
    probe #(1'b0) item;
    item = new;

    item.check(1'b1, 0);
    if (item.passed != 0 || item.failed != 0 || item.sibling_passed != 1)
      $fatal(1, "Assertion control did not suppress only the named assertion");

    item.check(1'b0);
    if (item.passed != 1 || item.failed != 0)
      $fatal(1, "True assertion did not run the pass action immediately");

    item.check(1'b1);
    item.check(1'bx);
    item.check(1'bz);
    if (item.passed != 1 || item.failed != 3)
      $fatal(1, "False and unknown assertions did not run the fail action");

    $display("PASS");
  end
endmodule
