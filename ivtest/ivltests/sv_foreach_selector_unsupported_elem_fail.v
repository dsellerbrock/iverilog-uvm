// An associative array of fixed arrays is not supported yet. A foreach
// over one of its elements must report that, not crash the compiler
// (it freed the target expression twice).
module test;
  typedef enum { PartData, PartInfo } part_e;
  int tgt[part_e][4];
  part_e p = PartData;
  initial foreach (tgt[p][i]) tgt[p][i] = i;
endmodule
