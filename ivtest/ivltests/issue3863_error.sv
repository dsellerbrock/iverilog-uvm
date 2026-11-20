checker unclocked_monitor(sequence s);
  check_seq: assert property (s);
endchecker

module issue3863_unclocked;
  sequence actual; 1'b1; endsequence
  unclocked_monitor inst(.s(actual));
endmodule

checker embedded_monitor(event tick, sequence s);
  whole: assert property (@tick s);
  embedded: assert property (@tick s |-> 1'b1);
endchecker

module issue3863_embedded;
  event tick;
  sequence actual; @tick 1'b1; endsequence
  embedded_monitor inst(tick, actual);
endmodule
