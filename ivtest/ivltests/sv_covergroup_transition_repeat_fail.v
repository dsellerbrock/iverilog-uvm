// IEEE 1800-2017 19.5.3: a one-sample transition has length zero and is
// illegal, and a repetition range cannot be reversed.
module sv_covergroup_transition_repeat_fail;
  covergroup bad_cg with function sample(bit [3:0] value);
    cp: coverpoint value {
      bins zero_length = (1 [*1]);
      bins reversed = (1 => 2 [*4:2] => 3);
      bins unbounded_array[] = (1 => 2 [=2] => 3);
    }
  endgroup
endmodule
