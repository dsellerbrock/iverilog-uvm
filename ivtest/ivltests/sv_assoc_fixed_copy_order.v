// IEEE 1800-2017/2023 7.6, 7.8: OpenTitan flash_ctrl enum-keyed fixed
// arrays copy by declared left-to-right position across different bounds.
module top;
  typedef bit [7:0] asc_t[8:9];
  typedef bit [7:0] desc_t[3:2];
  bit [7:0] bare_up[8:9];
  bit [7:0] bare_down[9:8];
  asc_t src[int];
  desc_t dst[int];
  asc_t default_src[int] = '{default: asc_t'{8'hA5, 8'h5A}};
  desc_t default_dst[int];

  initial begin
    bare_up[8] = 8'hA5; bare_up[9] = 8'h5A;
    dst[1] = bare_up;
    if (dst[1][3] !== 8'hA5 || dst[1][2] !== 8'h5A)
      $fatal(1, "ascending bare source order");
    bare_down[9] = 8'hC3; bare_down[8] = 8'h3C;
    dst[2] = bare_down;
    if (dst[2][3] !== 8'hC3 || dst[2][2] !== 8'h3C)
      $fatal(1, "descending bare source order");

    src[4][8] = 8'h21; src[4][9] = 8'h43;
    dst[3] = src[4];
    if (dst[3][3] !== 8'h21 || dst[3][2] !== 8'h43)
      $fatal(1, "keyed fixed value order");
    dst = src;
    if (!dst.exists(4) || dst.exists(1) || dst[4][3] !== 8'h21
        || dst[4][2] !== 8'h43)
      $fatal(1, "whole map fixed value order");

    dst[5] = desc_t'{8'h66, 8'h99};
    if (dst[5][3] !== 8'h66 || dst[5][2] !== 8'h99)
      $fatal(1, "typed pattern order");
    default_dst = default_src;
    if (default_dst.exists(7) || default_dst[7][3] !== 8'hA5
        || default_dst[7][2] !== 8'h5A || default_dst.exists(7))
      $fatal(1, "explicit default order");
    $display("PASSED");
  end
endmodule
