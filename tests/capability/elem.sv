module top;
  import "DPI-C" function void probe(input int a[], input int lo, input int hi);
  int asc [3:10];
  int desc[10:3];
  initial begin
    foreach (asc[i])  asc[i]  = i*100;
    foreach (desc[i]) desc[i] = i*100;
    $display("SV asc:  asc[3]=%0d asc[10]=%0d",  asc[3],  asc[10]);
    $display("SV desc: desc[3]=%0d desc[10]=%0d", desc[3], desc[10]);
    probe(asc, 3, 10);
    probe(desc, 3, 10);
    $finish(0);
  end
endmodule
