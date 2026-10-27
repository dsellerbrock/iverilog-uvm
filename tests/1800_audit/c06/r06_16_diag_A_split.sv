module diag_A_getc;
  class C; string name = "obj"; endclass
  C o;
  initial begin o = new; $display("A getc=%0d", o.name.getc(1)); end
endmodule
module diag_A_idx;
  class C; string name = "obj"; endclass
  C o;
  initial begin o = new; $display("A idx=%0d", o.name[1]); end
endmodule
module diag_A_substr;
  class C; string name = "obj"; endclass
  C o;
  initial begin o = new; $display("A substr='%s'", o.name.substr(1,2)); end
endmodule
module diag_A_compare;
  class C; string name = "obj"; endclass
  C o;
  initial begin o = new; $display("A compare=%0d", o.name.compare("obj")); end
endmodule
module diag_A_upper;
  class C; string name = "obj"; endclass
  C o;
  initial begin o = new; $display("A upper='%s'", o.name.toupper()); end
endmodule
module diag_A_copy;
  class C; string name = "obj"; endclass
  C o; string n;
  initial begin o = new; n = o.name; $display("A copy src_len=%0d copy_len=%0d equal=%b", o.name.len(), n.len(), o.name == n); end
endmodule
