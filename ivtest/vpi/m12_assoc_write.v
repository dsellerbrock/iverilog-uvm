// M12-4: VPI writes to associative-array elements (positional, key
// order — the mirror of the read path). Covers int (vec4), real, and
// string valued maps with string and int keys, plus the loud
// rejections: a mismatched put format and a write to an
// object-valued element.
module top;
  int aa_i[string];
  real aa_r[string];
  string aa_s[string];
  byte aa_b[int];
  class C; int x = 1; endclass
  C aa_o[string];
  initial begin
    aa_i["b"] = 5;
    aa_i["a"] = 4;
    aa_r["k"] = 1.5;
    aa_s["k"] = "before";
    aa_b[3] = 8'h11;
    aa_b[1] = 8'h22;
    aa_o["k"] = new;
    $m12aw_probe;
    #1 $display("final: aa_i[a]=%0d aa_i[b]=%0d aa_r[k]=%.2f aa_s[k]='%s'",
                aa_i["a"], aa_i["b"], aa_r["k"], aa_s["k"]);
    $display("final: aa_b[1]=%02h aa_b[3]=%02h aa_o[k].x=%0d",
             aa_b[1], aa_b[3], aa_o["k"].x);
    $finish(0);
  end
endmodule
