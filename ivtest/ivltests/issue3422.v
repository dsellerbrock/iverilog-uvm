// IEEE 1800-2017/2023 33.4.3: configuration parameter override expressions.
function automatic int f(int x);
   return x;
endfunction

package values;
   typedef struct packed { int field; } value_t;
   localparam int EXTRA = 2;
endpackage

module leaf #(parameter int W = 1) ();
endmodule

module generated_leaf #(parameter int W = 1) ();
endmodule

module array_leaf #(parameter int W = 1) ();
endmodule

module source_cell #(parameter int P = 42) ();
endmodule

module let_leaf #(parameter int W) ();
endmodule

module first_let_parent;
   let call_user(untyped n) = n + 1;
   let_leaf u();
endmodule

module second_let_parent;
   let call_user(untyped n) = f(n);
   let_leaf u();
endmodule

module required_leaf #(parameter int W) ();
endmodule

module top;
   parameter int P = 3;
   parameter int ROOT_W = 0;
   localparam values::value_t STRUCT_VALUE = '{4};
   let increment(untyped n) = n + 1;
   leaf u(), v(), w(), x(), y();
`ifdef BAD_CONFIG
   if (1) begin : g
      localparam int P = 11;
      generated_leaf u();
   end
   source_cell a[0:0]();
   array_leaf v_array[1:0]();
   first_let_parent first_let();
   second_let_parent second_let();
   required_leaf required_inst();
`else
   source_cell source_inst();
   initial begin
      if (u.W !== 3 || v.W !== 14 || w.W !== 42 || x.W !== 1)
         $fatal(1, "Unexpected config parameter values %0d %0d %0d %0d",
                u.W, v.W, w.W, x.W);
      if (ROOT_W !== 3)
         $fatal(1, "Unexpected top-level config parameter value %0d", ROOT_W);
      $display("PASSED");
   end
`endif
endmodule

config cfg;
   localparam N = 16;
   localparam IDX = 0;
   design top;
`ifdef BAD_CONFIG
   instance top.u use #(.W(top.P + top.P));
   instance top.v use #(.W(f(2)));
   instance top.w use #(.W(int'($bits(f(2)))));
   instance top.x use #(.W($bits(top.P)));
   instance top.y use #(.W($bits(0 inside {top.P})));
   instance top use #(.ROOT_W(top.P + 7));
   cell generated_leaf use #(.W(top.g.P));
   cell array_leaf use #(.W(top.a[IDX].P));
   cell let_leaf use #(.W(call_user(2)));
   instance top.required_inst use #(.W(f(2)));
`else
   instance top.u use #(.W((top.P)));
   instance top.v use #(.W($clog2(N) + increment(P) + STRUCT_VALUE.field + values::EXTRA));
   instance top.w use #(.W(top.source_inst.P));
   instance top.x use #(.W());
   instance top use #(.ROOT_W(top.P));
`endif
endconfig
