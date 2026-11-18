module issue3718;
  typedef bit [7:0] pair_t[3:2];
  pair_t m[int], before_map[int];
  pair_t fixed_value;
  typedef bit [7:0] bytes_t[];
  bytes_t good, bad;
  bit [7:0] q[$], shortq[$];
  int keys, good_calls, bad_calls;
  function automatic bytes_t get_good(); good_calls++; return good; endfunction
  function automatic bytes_t get_bad(); bad_calls++; return bad; endfunction
  initial begin
    good = new[2]; good[0]=11; good[1]=22;
    bad = new[1]; bad[0]=99;
    q.push_back(33); q.push_back(44); shortq.push_back(55);
    fixed_value[3]=71; fixed_value[2]=72;
    m = '{9:fixed_value, default:fixed_value};
    keys=0; good_calls=0;
    m = '{7:get_good(), default:q};
    if (good_calls!=1 || m.num()!=1 || !m.exists(7) || m[7][3]!=11 || m[7][2]!=22 || m[8][3]!=33 || m[8][2]!=44) $fatal(1,"matching pattern");
    good[0]=77; q[0]=88;
    if (m[7][3]!=11 || m[8][3]!=33) $fatal(1,"copy isolation");
    m = '{9:fixed_value, default:fixed_value};
    keys=0; good_calls=0; bad_calls=0;
    m = '{7:get_good(), 4:get_bad(), default:shortq};
    if (good_calls!=1 || bad_calls!=1 || m.num()!=1 || !m.exists(9) || m.exists(7) || m[9][3]!=71 || m[9][2]!=72 || m[8][3]!=71 || m[8][2]!=72) $fatal(1,"mismatch transaction");
    bad_calls=0;
    m = '{default:get_bad()};
    if (bad_calls!=1 || m.num()!=1 || !m.exists(9) || m[9][3]!=71 || m[8][3]!=71) $fatal(1,"default mismatch transaction");
    $display("PASS");
  end
endmodule
