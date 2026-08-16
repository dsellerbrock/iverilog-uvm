module top;
  logic [3:0] first_value;
  logic [3:0] second_value;

  covergroup first_cg(ref logic [3:0] bus_event);
    repeated_cp: coverpoint bus_event {
      bins expected = {4'h1};
    }
  endgroup

  covergroup second_cg(ref logic [3:0] bus_event);
    repeated_cp: coverpoint bus_event {
      bins expected = {4'h2};
    }
  endgroup

  first_cg first;
  second_cg second;

  initial begin
    first_value = 4'h1;
    second_value = 4'h2;
    first = new(first_value);
    second = new(second_value);
    first.sample();
    second.sample();
    if (first.get_coverage() != 100.0)
      $fatal(1, "first covergroup did not sample its constructor formal");
    if (second.get_coverage() != 100.0)
      $fatal(1, "second covergroup did not sample its constructor formal");
    $display("PASSED");
  end
endmodule
