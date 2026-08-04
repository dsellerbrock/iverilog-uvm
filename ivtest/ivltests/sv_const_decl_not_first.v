// IEEE 1800-2017 6.18/6.20: a `const` variable declaration may appear
// anywhere among the statements of a procedural block, not only as
// the block's first item. The statement_item grammar had plain
// (non-const) alternatives for a data_type declaration appearing
// after another declaration or statement, but the only `const`
// alternative in that position required a user-defined TYPE_IDENTIFIER
// -- a `const` of a keyword-spelled type (int, string) or a
// package-scoped type never matched, and fell through to a syntax
// error ("Syntax in assignment statement l-value").
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
    $display("stmt");
    const int W = 7;              // const after an ordinary statement
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
