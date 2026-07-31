// IEEE 1800-2017 26.6: a package may re-export a name it imported, and
// the name is then reachable through the EXPORTING package. `outer::D'
// is legal because `outer' says `export inner::D;', even though D is
// declared in `inner'.
//
// The exports were recorded at parse time and never consulted again, so
// a qualified reference only ever saw the exporting package's own
// declarations. As a module parameter default -- how OpenTitan's
// spi_device reaches spi_device_pkg::SramMailboxDepth -- that failed
// with "Unable to bind parameter `outer::D'".
//
// The values are checked, not just the binding: a resolution that found
// the wrong package's D would compile and be wrong.
package inner;
  parameter int unsigned D = 7;
  parameter int unsigned W = 5;
  typedef logic [3:0] nib_t;
endpackage

package other;
  parameter int unsigned D = 99;      // same NAME, different package
endpackage

package outer;
  import inner::D;
  export inner::D;
  import inner::W;
  export inner::W;
  parameter int unsigned E = 3;       // outer's own
endpackage

module sub #(parameter int unsigned P = outer::D,
             parameter int unsigned Q = outer::E)
            (output logic [7:0] p_o, output logic [7:0] q_o);
  assign p_o = P[7:0];
  assign q_o = Q[7:0];
endmodule

module sv_pkg_export_resolve;

  logic [7:0] p, q;
  int errors = 0;

  // exported name used as a parameter default in an instantiation
  sub u_sub (.p_o(p), .q_o(q));

  // exported name used directly in an expression context
  localparam int unsigned LOCAL_D = outer::D;
  localparam int unsigned LOCAL_W = outer::W;
  // the un-exported spelling still resolves to its own package
  localparam int unsigned OTHER_D = other::D;

  task ck(input string t, input int got, input int exp);
    if (got !== exp) begin
      $display("FAIL %0s: got %0d expected %0d", t, got, exp);
      errors = errors + 1;
    end
  endtask

  initial begin
    #1;
    ck("param_default", int'(p), 7);   // outer::D -> inner::D
    ck("own_param",     int'(q), 3);   // outer::E -> outer's own
    ck("localparam_D",  int'(LOCAL_D), 7);
    ck("localparam_W",  int'(LOCAL_W), 5);
    ck("other_D",       int'(OTHER_D), 99);
    if (errors == 0) $display("PASSED");
    else $display("FAILED with %0d errors", errors);
  end

endmodule
