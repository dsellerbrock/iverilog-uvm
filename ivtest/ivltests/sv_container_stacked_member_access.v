// Member and element selects after stacked container selects: aa[k1][k2].f,
// qa[i][key].f, dq[i][j].f.z, a3[k][n][b].f, including a bit select and a
// dynamic-array element of the struct member (IEEE 1800-2017/2023 7.8, 7.10,
// 7.5, 7.9). A write to an absent associative element creates it. These forms
// were rejected as "does not have a field named" (reads) and "only
// single-dimension index ... l-value roots" (writes); OpenTitan chip
// sw_logger_if.sv uses sw_logs[sw][addr].str_arg_idx[i] and .arg[i].
typedef struct { int a; bit [7:0] v; int arr[]; } s_t;
class k; int z; endclass

module main;
  s_t sa[string][int];
  s_t qa[$][string];
  k   dq[][$];
  s_t aq[string][$];
  s_t a3[string][int][bit[3:0]];
  k   ko[string][int];
  int errors;

  task automatic expect_int(string what, int got, int want);
    if (got !== want) begin
      $display("FAILED %s: got %0d want %0d", what, got, want);
      errors++;
    end
  endtask

  initial begin
    s_t l;
    k o;
    l.a = 1; l.v = 8'h0f; l.arr = new[2];

    sa["x"][3] = l;
    sa["x"][3].a = 7;
    sa["x"][3].v[2] = 1'b0;
    sa["x"][3].arr[1] = 5;
    expect_int("sa.a", sa["x"][3].a, 7);
    expect_int("sa.v", sa["x"][3].v, 8'h0b);
    expect_int("sa.arr", sa["x"][3].arr[1], 5);
    for (int i = 0; i < 4; i++)
      if (sa["x"][3].v[i]) expect_int("sa.v bit", i, (i == 2) ? -1 : i);

    ko["x"][3] = new;
    ko["x"][3].z = 9;
    expect_int("ko.z", ko["x"][3].z, 9);

    qa.push_back('{default: l});
    qa[0]["p"] = l;
    qa[0]["p"].a = 11;
    qa[0]["p"].v[7] = 1'b1;
    expect_int("qa.a", qa[0]["p"].a, 11);
    expect_int("qa.v", qa[0]["p"].v, 8'h8f);

    dq = new[2];
    o = new; o.z = 3;
    dq[1].push_back(o);
    dq[1][0].z = 21;
    expect_int("dq alias", o.z, 21);
    expect_int("dq.z", dq[1][0].z, 21);

    aq["r"].push_back(l);
    aq["r"][0].a = 31;
    aq["r"][0].v[0] = 1'b0;
    expect_int("aq.a", aq["r"][0].a, 31);
    expect_int("aq.v", aq["r"][0].v, 8'h0e);

    a3["x"][2][4'd5] = l;
    a3["x"][2][4'd5].a = 41;
    expect_int("a3.a", a3["x"][2][4'd5].a, 41);

    a3["y"][9][4'd1].a = 51;
    expect_int("created a3 exists", a3["y"][9].exists(4'd1), 1);
    expect_int("created a3.a", a3["y"][9][4'd1].a, 51);

    if (errors == 0) $display("PASSED");
  end
endmodule
