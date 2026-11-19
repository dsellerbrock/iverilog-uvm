package issue3830_pkg;
  int state;
endpackage

class issue3830_base;
  int a;
  static int state;
endclass

class issue3830_derived extends issue3830_base;
  rand int a, b;
  int lhs, rhs;
  int selected[2];
  int data[];

  constraint order_c {
    solve lhs, this.lhs before b, rhs, this.rhs;
    solve b before this.selected[0];
    solve super.a before b;
    solve b before a;
    solve issue3830_pkg::state before b;
    solve b before issue3830_base::state;
`ifdef ISSUE3830_SIZE
    solve this.data.size() before b;
    solve b before this.data.size;
`endif
  }
endclass

module top;
  issue3830_derived obj = new;
endmodule
