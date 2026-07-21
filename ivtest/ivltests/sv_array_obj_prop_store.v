// Store to a property of a static unpacked array-of-class element
// (`arr[i].prop = expr`). Previously this crashed ivl
// (show_stmt_assign_sig_cobject -> ivl_expr_value(NULL)) because the
// l-value elaboration dropped both the array index and the property,
// producing a degenerate whole-array assignment.
//
// The store must land in the addressed element. Verification uses BOTH
// the direct element-property read (`arr[i].prop`) and a copied handle
// (`h = arr[i]; h.prop`); both previously returned element 0 for a
// static array (the element index was dropped in the read base too).
//
// Covers: constant index, variable/loop index, a packed-vector property,
// and a 2-D array of objects.
//
// Prints PASSED only if every element read back matches what was stored.

module sv_array_obj_prop_store;

  class c;
    int         id;
    logic [7:0] b;
  endclass

  c arr[3];
  c mat[2][2];
  c h;
  int errors = 0;

  initial begin
    foreach (arr[i]) arr[i] = new;

    // constant-index stores; verify by direct read AND handle read
    arr[0].id = 10; arr[1].id = 20; arr[2].id = 30;
    arr[1].b  = 8'hA5;

    if (arr[0].id != 10) begin $display("FAIL direct arr[0]=%0d", arr[0].id); errors++; end
    if (arr[1].id != 20) begin $display("FAIL direct arr[1]=%0d", arr[1].id); errors++; end
    if (arr[2].id != 30) begin $display("FAIL direct arr[2]=%0d", arr[2].id); errors++; end
    if (arr[1].b !== 8'hA5) begin $display("FAIL direct packed=%h", arr[1].b); errors++; end
    h = arr[1]; if (h.id != 20) begin $display("FAIL handle arr[1]=%0d", h.id); errors++; end

    // variable/loop-index stores, direct read back
    for (int i = 0; i < 3; i++) arr[i].id = 100 + i;
    for (int i = 0; i < 3; i++)
      if (arr[i].id != 100 + i) begin $display("FAIL var-index i=%0d got %0d", i, arr[i].id); errors++; end

    // 2-D array of objects
    foreach (mat[i,j]) mat[i][j] = new;
    mat[1][0].id = 77;
    mat[0][1].id = 88;
    if (mat[1][0].id != 77) begin $display("FAIL mat[1][0]=%0d", mat[1][0].id); errors++; end
    if (mat[0][1].id != 88) begin $display("FAIL mat[0][1]=%0d", mat[0][1].id); errors++; end
    if (mat[0][0].id != 0)  begin $display("FAIL mat[0][0]=%0d", mat[0][0].id); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end

endmodule
