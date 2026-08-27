// IEEE 1800-2017/2023 19.5.1: integral open bin arrays are keyed by
// resolved value (overlapping/duplicate occurrences coalesce), while fixed
// bin arrays assign floor(N/size), at least one, ordered values to the first
// size-1 bins and place the complete remainder in the last bin.
module top;
  covergroup static_open with function sample(int value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins each[] = {[1:3], [3:5], 1};
    }
  endgroup

  covergroup dynamic_open(int limit) with function sample(int value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins each[] = {[1:limit], 1, [limit-1:limit+1]};
    }
  endgroup

  covergroup static_fixed with function sample(int value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins split[4] = {[1:10], 1, 4, 7};
    }
  endgroup

  static_open static_values = new;
  dynamic_open dynamic_values = new(3);
  static_fixed fixed_values = new;

  initial begin
    static_values.sample(1);
    if (static_values.get_inst_coverage() != 20.0)
      $fatal(1, "static open bins did not coalesce duplicate value 1");

    dynamic_values.sample(1);
    if (dynamic_values.get_inst_coverage() != 25.0)
      $fatal(1, "dynamic open bins did not coalesce duplicate value 1");

    fixed_values.sample(1);
    if (fixed_values.get_inst_coverage() != 50.0)
      $fatal(1, "fixed-bin duplicate did not hit first and last bins");
    fixed_values.sample(4);
    if (fixed_values.get_inst_coverage() != 75.0)
      $fatal(1, "fixed-bin remainder was not placed in the last bin");
    fixed_values.sample(7);
    if (fixed_values.get_inst_coverage() != 100.0)
      $fatal(1, "fixed-bin normative partition did not reach all bins");

    $display("PASSED");
    $finish;
  end
endmodule
