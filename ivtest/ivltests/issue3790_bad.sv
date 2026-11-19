module issue3790_bad_child(output wire [7:0] q[3:2]);
  assign q[3] = 8'h12;
  assign q[2] = 8'h34;
endmodule

module issue3790_bad;
  wire [7:0] flat[3:0];
  wire [3:0] narrow[6:5][0:1];
  uwire [7:0] shared[0:1];
  uwire [7:0] rows[1:0][0:1];

  issue3790_bad_child wrong_shape[0:1](flat);
  issue3790_bad_child wrong_type[0:1](narrow);
  issue3790_bad_child broadcast[0:1](shared);
  issue3790_bad_child first[1:1](rows[0]);
  issue3790_bad_child disjoint[1:1](rows[1]);
  issue3790_bad_child overlap[1:1](rows[0]);
endmodule
