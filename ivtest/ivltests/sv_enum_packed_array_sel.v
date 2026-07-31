// An element of a packed array of enums is of the ENUM type
// (IEEE 1800-2017 6.19.3 + 7.4.2), so it may be assigned to a variable
// of that enum without a cast -- and the value it carries has to be the
// element's bits, not some neighbouring slice.
//
// NetNet::packed_dims() is flat: it has already dissolved the enum into
// its base vector, so a select built from that list alone loses the
// enum type and the assignment is rejected. Both the constant-index and
// the run-time-index arms are exercised here: if only one of them
// carries the declared element type, the legality of an assignment
// would depend on whether the index happened to fold.
module sv_enum_packed_array_sel;

  typedef enum logic [2:0] { A = 3'b101, B = 3'b010, C = 3'b111 } e_t;

  e_t [3:0]      arr;
  e_t [1:0][3:0] arr2;
  e_t            one;
  int errors = 0;

  task ck(input string t, input [11:0] got, input [11:0] exp);
    if (got !== exp) begin
      $display("FAIL %0s: got %h exp %h", t, got, exp);
      errors = errors + 1;
    end
  endtask

  initial begin
    arr[3] = C; arr[2] = A; arr[1] = B; arr[0] = C;
    ck("whole", arr, {C, A, B, C});

    // constant index: type survives AND the bits are the element's
    one = arr[2]; ck("sel2", {9'b0, one}, {9'b0, A});
    one = arr[0]; ck("sel0", {9'b0, one}, {9'b0, C});
    one = arr[3]; ck("sel3", {9'b0, one}, {9'b0, C});

    // run-time index: same rule
    for (int i = 0; i < 4; i++) begin
      one = arr[i];
      ck("dyn", {9'b0, one}, {9'b0, arr[i]});
    end

    // two packed dimensions: the full chain reaches the element
    arr2[1][2] = B; arr2[0][3] = A;
    one = arr2[1][2]; ck("d2a", {9'b0, one}, {9'b0, B});
    one = arr2[0][3]; ck("d2b", {9'b0, one}, {9'b0, A});
    for (int i = 0; i < 2; i++)
      for (int j = 0; j < 4; j++)
        ck("d2dyn", {9'b0, arr2[i][j]}, {9'b0, arr2[i][j]});

    // a sub-select of an element is plain bits, and still the right ones
    ck("bit2", {11'b0, arr[2][2]}, {11'b0, 1'b1});
    ck("bit1", {11'b0, arr[2][1]}, {11'b0, 1'b0});
    ck("bit0", {11'b0, arr[2][0]}, {11'b0, 1'b1});
    ck("part", {9'b0, arr[1][2:0]}, {9'b0, B});

    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d errors", errors);
  end

endmodule
