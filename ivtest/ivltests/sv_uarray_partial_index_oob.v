// A fixed out-of-range unpacked-subarray destination is an ignored write,
// not an internal compiler error or a false mixed-driver conflict.
module sv_uarray_partial_index_oob;
  logic [7:0] driven [1:0][0:1];
  logic [7:0] row [0:1];
  logic [7:0] ignored [0:1];

  assign driven[0] = row;

  initial begin
    row[0] = 8'h10;
    row[1] = 8'h11;
    ignored[0] = 8'h20;
    ignored[1] = 8'h21;

    // The continuous assignment above has already coerced driven to an
    // unresolved variable. The OOB slice must not be mistaken for overlap.
    driven[2] = ignored;
    #1;
    if (driven[0][0] !== 8'h10 || driven[0][1] !== 8'h11) begin
      $display("FAILED -- valid row changed by OOB subarray write");
      $finish;
    end
    $display("PASSED");
    $finish;
  end
endmodule
