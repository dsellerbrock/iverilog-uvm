module issue917_clocking_sva_invalid;
  bit clk = 0;
  bit other = 0;
  bit a = 0;
  bit b = 0;

  property outside_other;
    @(posedge other) a;
  endproperty

  sequence outside_sequence_other;
    @(posedge other) a;
  endsequence

  property outside_multiclock;
    @(posedge clk) a |-> @(negedge clk) b;
  endproperty

  clocking cb_explicit @(posedge clk);
    sequence bad_explicit;
      @(posedge clk) a;
    endsequence
  endclocking

  clocking cb_multiclock @(posedge clk);
    property bad_multiclock;
      a |-> @(negedge clk) b;
    endproperty
  endclocking

  clocking cb_external @(posedge clk);
    property bad_external;
      outside_other;
    endproperty
  endclocking

  clocking cb_external_sequence @(posedge clk);
    property bad_external_sequence;
      outside_sequence_other;
    endproperty
  endclocking

  clocking cb_external_multiclock @(posedge clk);
    property bad_external_multiclock;
      outside_multiclock;
    endproperty
  endclocking
endmodule
