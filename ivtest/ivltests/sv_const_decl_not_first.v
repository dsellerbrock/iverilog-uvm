// IEEE 1800-2017 6.21: variable declarations must precede statements in a
// procedural block. Exercise const declarations of keyword and package types
// after other declarations but before the first statement.
//
// Reduced from OpenTitan lc_ctrl_scoreboard.sv, where a task declares
// three ordinary local variables and then:
//   const string MsgFmt = "Check failed %s == %s %s [%h] vs %s [%h]";
package p;
  typedef struct packed { logic [3:0] v; } rec_t;
endpackage
class C;
  task run();
    int x;
    p::rec_t r;
    const int Y = 5;              // const after a plain decl
    const string MsgFmt = "ok";   // const string after a const decl
    p::rec_t rr;
    const p::rec_t Z = '{v: 4'hA}; // const of a package-scoped type
    const int W = 7;
    $display("stmt");
    if (Y != 5 || MsgFmt != "ok" || Z.v !== 4'hA || W != 7) begin
      $display("FAILED Y=%0d MsgFmt=%s Z=%h W=%0d", Y, MsgFmt, Z.v, W);
      $finish;
    end
    $display("PASSED");
  endtask
endclass
module main;
  initial begin
    C c = new;
    c.run();
  end
endmodule
