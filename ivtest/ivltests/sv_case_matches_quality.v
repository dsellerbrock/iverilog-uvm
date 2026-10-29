module top;
  typedef union tagged { void Empty; int Value; } U;
  U value;

  initial begin
    value = tagged Value(5);
    unique case (value) matches
      tagged Value .x: ;
      tagged Value .y: ;
    endcase

    value = tagged Empty;
    unique case (value) matches
      tagged Value .n: ;
    endcase
    priority case (value) matches
      tagged Value .n: ;
    endcase
    unique0 case (value) matches
      tagged Value .n: ;
    endcase

    $display("PASS pattern case qualifiers");
    $finish;
  end
endmodule
