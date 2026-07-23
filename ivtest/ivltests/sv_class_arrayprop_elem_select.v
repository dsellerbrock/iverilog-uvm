// Loud-gap closure: element access PLUS bit/part/indexed select on a packed-
// vector ARRAY property (c.arr[i][m:l]), reads and writes. Formerly a loud
// "Got 2 indices, expecting 1" error both ways. Reads split the index list
// (leading -> canonical element index, trailing -> NetESelect on the element);
// writes lower to word(elem)+part and codegen RMWs the element via
// %prop/v/i + %setbits/vec4[/x] + %store/prop/v/i. IEEE 1800-2017 7.4.6,
// 11.5.1, 8.3. Self-checking.
module sv_class_arrayprop_elem_select;
  class C; logic [15:0] arr[4]; endclass
  int errors = 0;
  initial begin
    automatic C c = new;

    c.arr[1] = 16'hBEEF;
    if (c.arr[1][7:0] !== 8'hEF) begin $display("FAIL read part"); errors++; end
    if (c.arr[1][15:12] !== 4'hB) begin $display("FAIL read hi"); errors++; end
    c.arr[2] = 16'h0000; c.arr[2][7:0] = 8'hAA;
    if (c.arr[2] !== 16'h00AA) begin $display("FAIL const write=%h", c.arr[2]); errors++; end

    foreach (c.arr[i]) c.arr[i] = 16'hFFFF;
    for (int i = 0; i < 4; i++) c.arr[i][7:0] = i[7:0];
    for (int i = 0; i < 4; i++)
      if (c.arr[i] !== (16'hFF00 | i)) begin $display("FAIL var elem i=%0d", i); errors++; end
    for (int i = 0; i < 4; i++) c.arr[i][8 +: 4] = 4'h5;
    for (int i = 0; i < 4; i++)
      if (c.arr[i] !== (16'hF500 | i)) begin $display("FAIL +: i=%0d", i); errors++; end

    if (errors == 0) $display("PASSED");
    else $display("FAILED (%0d errors)", errors);
    $finish;
  end
endmodule
