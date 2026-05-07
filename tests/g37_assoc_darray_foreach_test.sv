// G37: assoc[string][] foreach double-bracket syntax — now parses correctly.
// The double-bracket form foreach(arr[k][i]) previously gave a parser error.
// Full runtime iteration is compile-progress note; syntax acceptance is tested here.
module top;
  int arr[string][];
  initial begin
    arr["x"] = new[2];
    arr["x"][0] = 1;
    foreach (arr[k][i]) begin
      // body — runtime note emitted, iteration may be empty
    end
    $display("PROBE_OK_assoc_darray_foreach");
    $finish;
  end
endmodule
