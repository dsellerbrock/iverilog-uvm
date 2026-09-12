// Check that array locator methods (find/find_index/...) work on a
// PLAIN (non-class-property) fixed-size array of non-integral elements
// and with a nonzero declared index base. IEEE 1800-2017/2023 7.12.1:
// "Array locator methods operate on any unpacked array" -- no
// restriction to integral element types or a zero-based index. This
// previously hit "sorry: find() on fixed-size arrays of non-integral
// elements is not yet implemented" for a plain array, even though the
// identical call on a class property already worked (L36).

module test;

  string arr[1:4];
  string found[$];
  int idx[$];
  real rarr[3];
  real rfound[$];
  int errors;

  initial begin
    errors = 0;

    arr[1] = "a";
    arr[2] = "b";
    arr[3] = "c";
    arr[4] = "b";

    found = arr.find(x) with (x == "b");
    if (found.size() !== 2 || found[0] != "b" || found[1] != "b") begin
      $display("FAILED: find() on non-integral fixed array");
      errors = errors + 1;
    end

    idx = arr.find_index(x) with (x == "b");
    if (idx.size() !== 2 || idx[0] !== 2 || idx[1] !== 4) begin
      $display("FAILED: find_index() declared (nonzero-base) indices");
      errors = errors + 1;
    end

    rarr[0] = 1.5;
    rarr[1] = 2.5;
    rarr[2] = 1.5;
    rfound = rarr.find(x) with (x == 1.5);
    if (rfound.size() !== 2) begin
      $display("FAILED: find() on real-typed fixed array");
      errors = errors + 1;
    end

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED");
  end

endmodule
