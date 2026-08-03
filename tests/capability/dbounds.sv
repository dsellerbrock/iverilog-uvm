// Dynamic arrays DO marshal, so the bounds accessors are observable here.
// A dynamic array is always 0-based ascending with size N, so the correct
// answers are: low 0, high N-1, left 0, right N-1, increment -1.
// H.10.2 uses $increment's right-to-left convention; a left-to-right
// traversal subtracts the result. svSizeOfArray is the TOTAL byte size.
module top;
  import "DPI-C" function void probe1(input int a[]);
  import "DPI-C" function void probe2(input int a[][]);
  int d[];
  int md[][];
  initial begin
    d = new[8];
    foreach (d[i]) d[i] = i;
    md = new[2];
    for (int i=0;i<2;i++) begin md[i] = new[3]; for (int j=0;j<3;j++) md[i][j] = i*10+j; end
    probe1(d);
    probe2(md);
    $finish(0);
  end
endmodule
