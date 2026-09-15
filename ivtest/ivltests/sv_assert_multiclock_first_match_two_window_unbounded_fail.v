module sv_assert_multiclock_first_match_two_window_unbounded_fail;bit c1,c2,a,b,c;assert property(@(posedge c1)first_match(a##[1:$]b##[1:2]c)|->@(posedge c2)1);endmodule
