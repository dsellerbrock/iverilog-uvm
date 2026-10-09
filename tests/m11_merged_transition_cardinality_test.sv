// IEEE 1800-2017/2023 19.5.2 and 19.11.3: merged type coverage unions
// identical arrayed transition bins and retains their counts after retirement.
module test;
  covergroup cg with function sample(bit [3:0] value);
    type_option.merge_instances = 1;
    option.at_least = 2;
    cp: coverpoint value {
      bins wait_bins[] = (12 => 0 [*1:1000] => 13);
    }
  endgroup

  cg a, b;

  task automatic hit(input cg group, input int repetitions);
    group.sample(12);
    repeat (repetitions) group.sample(0);
    group.sample(13);
  endtask

  task automatic check(input string label, input real expected);
    real got = a.get_coverage();
    if (got < expected - 0.000001 || got > expected + 0.000001)
      $fatal(1, "%s got %0.6f expected %0.6f", label, got, expected);
  endtask

  initial begin
    a = new;
    b = new;

    // The same transition identity hit once in each instance satisfies
    // at_least=2, but contributes one of the 1000 bins.
    hit(a, 1);
    hit(b, 1);
    check("shared transition identity", 0.1);

    // A second repetition length is a distinct arrayed transition bin.
    hit(a, 2);
    hit(b, 2);
    check("union of distinct transition identities", 0.2);

    b = null;
    check("merged counts survive instance retirement", 0.2);
    $display("PASSED");
    $finish(0);
  end
endmodule
