// A continuous subarray driver claims every selected original word. Overlap
// with another continuous or procedural driver is illegal regardless of
// source order, including overlap after the subarray's base word.
module continuous_row_first;
  logic [7:0] a [1:0][0:1];
  logic [7:0] row [0:1];
  logic [7:0] word;
  assign a[0] = row;
  assign a[0][1] = word;
endmodule

module continuous_word_first;
  logic [7:0] a [1:0][0:1];
  logic [7:0] row [0:1];
  logic [7:0] word;
  assign a[0][1] = word;
  assign a[0] = row;
endmodule

module procedural_word_first;
  logic [7:0] a [1:0][0:1];
  logic [7:0] row [0:1];
  logic [7:0] word;
  always_comb a[0][1] = word;
  assign a[0] = row;
endmodule

module procedural_slice_first;
  logic [7:0] a [1:0][0:1];
  logic [7:0] word;
  always_comb a[0] = '{8'h11, 8'h22};
  assign a[0][1] = word;
endmodule

module continuous_before_procedural_slice;
  logic [7:0] a [1:0][0:1];
  logic [7:0] word;
  assign a[0][1] = word;
  always_comb a[0] = '{8'h11, 8'h22};
endmodule


module continuous_slice_before_procedural_word;
  logic [7:0] a [1:0][0:1];
  logic [7:0] row [0:1];
  logic [7:0] word;
  assign a[0] = row;
  always_comb a[0][1] = word;
endmodule


module procedural_then_disjoint_continuous_then_overlap;
  logic [7:0] a [1:0];
  logic [7:0] proc_word;
  logic [7:0] first_cont;
  logic [7:0] overlapping_cont;
  task drive_word;
    a[1] = proc_word;
  endtask
  initial drive_word();
  assign a[0] = first_cont;
  assign a[1] = overlapping_cont;
endmodule
