// A syntax error inside a case-matches item, after its pattern scope has
// opened, is reported and parsing continues; the discarded item's scope
// must not leak into the enclosing block (it used to abort the compiler).
module issue3506_recover;
  typedef union tagged { void None; logic [39:0] Text; } u_t;
  u_t a, b;
  initial begin
    case (a) matches
      tagged Text .v &&& : ;
      default: $display("d");
    endcase
  end
  initial begin
    case (a) matches
      tagged Text .v:
        case (b) matches
          tagged Text .w &&& : ;
        endcase
      default: $display("d");
    endcase
  end
endmodule
