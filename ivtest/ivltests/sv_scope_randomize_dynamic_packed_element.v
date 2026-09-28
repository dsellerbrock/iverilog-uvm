// Runtime packed element selection in std::randomize (2017/2023).
typedef struct packed { logic [1:0][255:0] seeds; } wide_t;
typedef struct packed {
  logic [0:1][7:0] ascending;
  logic [4:3][7:0] shifted;
  logic [-1:-2][7:0] negative;
} ranges_t;
typedef struct packed { bit [1:0][7:0] seeds; } two_t;

module test;
  wide_t wide_value, saved;
  ranges_t ranges;
  two_t two_value;
  int idx;
  int unsigned random_idx;
  int signed random_negative_idx;
  longint unsigned high_idx;
  bit enable;
  initial begin
    idx = 1;
    if (!std::randomize(wide_value) with {
      wide_value.seeds[idx] inside {0, '1};
      wide_value.seeds[idx] != 0;
      wide_value.seeds[0] == 256'h1234;
    }) $fatal(1, "wide caller index");
    if (wide_value.seeds[1] !== {256{1'b1}} ||
        wide_value.seeds[0] !== 256'h1234)
      $fatal(1, "wide element or adjacent identity");

    idx = 0;
    if (!std::randomize(wide_value) with {
      wide_value.seeds[idx] == 256'hface;
      wide_value.seeds[1] == 256'hbeef;
    }) $fatal(1, "other caller index");
    if (wide_value.seeds[0] !== 256'hface ||
        wide_value.seeds[1] !== 256'hbeef)
      $fatal(1, "other element or adjacent identity");

    random_idx = 2;
    if (!std::randomize(wide_value, random_idx) with {
      random_idx == 1;
      wide_value.seeds[random_idx] == 256'h55aa;
      wide_value.seeds[0] == 256'h1122;
    }) $fatal(1, "randomized index");
    if (random_idx != 1 || wide_value.seeds[1] !== 256'h55aa ||
        wide_value.seeds[0] !== 256'h1122)
      $fatal(1, "randomized element identity");

    idx = 0;
    if (!std::randomize(ranges) with {
      ranges.ascending[idx] == 8'ha5;
      ranges.ascending[1] == 8'h5a;
    }) $fatal(1, "ascending range");
    if (ranges.ascending[0] !== 8'ha5 ||
        ranges.ascending[1] !== 8'h5a)
      $fatal(1, "ascending range orientation");

    idx = 3;
    if (!std::randomize(ranges) with {
      ranges.shifted[idx] == 8'h3c;
      ranges.shifted[4] == 8'h4d;
    }) $fatal(1, "shifted range");
    if (ranges.shifted[3] !== 8'h3c ||
        ranges.shifted[4] !== 8'h4d)
      $fatal(1, "shifted range orientation");

    idx = -1;
    if (!std::randomize(ranges) with {
      ranges.negative[idx] == 8'hc3;
      ranges.negative[-2] == 8'hd4;
    }) $fatal(1, "negative range");
    if (ranges.negative[-1] !== 8'hc3 ||
        ranges.negative[-2] !== 8'hd4)
      $fatal(1, "negative range orientation");

    random_negative_idx = 0;
    if (!std::randomize(ranges, random_negative_idx) with {
      random_negative_idx == -2;
      ranges.negative[random_negative_idx] == 8'h2b;
      ranges.negative[-1] == 8'h1a;
    }) $fatal(1, "randomized negative index");
    if (random_negative_idx != -2 ||
        ranges.negative[-2] !== 8'h2b ||
        ranges.negative[-1] !== 8'h1a)
      $fatal(1, "randomized negative identity");

    high_idx = '1;
    if (!std::randomize(two_value) with {
      two_value.seeds[high_idx] == 8'h00;
      two_value.seeds[0] == 8'h12;
    }) $fatal(1, "two-state invalid read");
    if (two_value.seeds[0] !== 8'h12)
      $fatal(1, "two-state neighbor");

    saved = wide_value;
    enable = 0;
    if (!std::randomize(wide_value) with {
      if (enable) wide_value.seeds[high_idx] == 256'hff;
      wide_value.seeds[0] == 256'h45;
      wide_value.seeds[1] == 256'h67;
    }) $fatal(1, "inactive invalid read");
    if (wide_value.seeds[0] !== 256'h45 ||
        wide_value.seeds[1] !== 256'h67)
      $fatal(1, "inactive invalid changed selection");

    saved = wide_value;
    idx = 0;
    if (std::randomize(wide_value) with {
      wide_value.seeds[idx] == 256'h11;
      wide_value.seeds[idx] == 256'h22;
    }) $fatal(1, "unsatisfiable select passed");
    if (wide_value !== saved)
      $fatal(1, "failed select mutated target");

    $display("PASSED");
  end
endmodule
