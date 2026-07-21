// Member access on an element of an UNPACKED array of a PACKED struct
// (`pair_t arr[N]; arr[i].m`). Both reading and writing the member used
// to crash ivl: the read path (check_for_struct_members) hit
// `assert base_index.size()+1 == net->packed_dimensions()` and the write
// path (elaborate_lval_net_packed_member_) hit
// `assert reg->unpacked_dimensions() == 0`, because the unpacked array
// index was treated as a packed dimension.
//
// The unpacked index must select the element; the member is a part-select
// off that element. Covers constant and variable indices, read and write.
//
// Prints PASSED only if every access matches.

module sv_unpacked_array_packed_struct_member;

  typedef struct packed { logic [7:0] a; logic [7:0] b; } pair_t;

  pair_t arr [3];
  int errors = 0;

  initial begin
    // constant-index whole-element init
    arr[0] = '{a:8'h10, b:8'h20};
    arr[1] = '{a:8'h30, b:8'h40};
    arr[2] = '{a:8'h50, b:8'h60};

    // constant-index member reads
    if (arr[0].a !== 8'h10) begin $display("FAIL r arr[0].a=%h", arr[0].a); errors++; end
    if (arr[1].b !== 8'h40) begin $display("FAIL r arr[1].b=%h", arr[1].b); errors++; end
    if (arr[2].a !== 8'h50) begin $display("FAIL r arr[2].a=%h", arr[2].a); errors++; end

    // constant-index member writes
    arr[1].a = 8'hAA;
    arr[2].b = 8'hBB;
    if (arr[1].a !== 8'hAA) begin $display("FAIL w arr[1].a=%h", arr[1].a); errors++; end
    if (arr[1].b !== 8'h40) begin $display("FAIL w spill arr[1].b=%h", arr[1].b); errors++; end
    if (arr[2].b !== 8'hBB) begin $display("FAIL w arr[2].b=%h", arr[2].b); errors++; end

    // variable-index read and write
    for (int i = 0; i < 3; i++) arr[i].a = 8'(i + 1);
    for (int i = 0; i < 3; i++)
      if (arr[i].a !== 8'(i + 1)) begin $display("FAIL var i=%0d a=%h", i, arr[i].a); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish(0);
  end

endmodule
