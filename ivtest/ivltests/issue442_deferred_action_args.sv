// IEEE 1800-2017/2023 16.4: a deferred assertion's action may call a task or
// void function with arguments. By-value actuals "shall be fully evaluated at
// the instant the deferred assertion expression is evaluated"; ref and const
// ref actuals use the current values of the underlying variables when the
// action runs (Reactive for #0, Postponed for final).
module issue442_deferred_action_args;
  int v = 1;
  string tag = "a";
  int k;
  int arr[3] = '{1, 2, 3};
  int dn[2:0];
  int md[2][2];
  int q[$];

  task automatic rep(input int x, input string s);
    $display("rep x=%0d s=%s", x, s);
  endtask
  task automatic rr(input int x, ref int y);
    $display("rr x=%0d y=%0d", x, y);
  endtask
  task automatic cr(const ref int y);
    $display("cr y=%0d", y);
  endtask
  function automatic void fv(int x, real r);
    $display("fv x=%0d r=%0.1f", x, r);
  endfunction
  task automatic ra(input int a[0:2], input int m[2][2], input int d[$]);
    $display("ra a=%p a0=%0d m01=%0d m10=%0d d=%p", a, a[0], m[0][1], m[1][0], d);
  endtask
  task sfin(input int x, input string s);
    $display("final x=%0d s=%s", x, s);
  endtask

  initial begin
    v = 5;
    assert #0 (v == 0) else rep(v, tag);
    v = 6; tag = "b";
    assert #0 (v == 0) else rr(v, v);
    v = 7;
    for (k = 0; k < 3; k++)
      assert #0 (v == 0) else rep(k, "loop");
    assert final (v == 0) else sfin(v, tag);
    cover #0 (v == 7) cr(v);
    v = 9; tag = "c";
    $display("source done v=%0d", v);
    #1;
    assert #0 (v == 0) else fv(v + 1, 2.5);
    v = 3;
    #1;
    dn[2] = 12; dn[1] = 11; dn[0] = 10;
    md[0][1] = 5; md[1][0] = 6; q = {7, 8};
    assert #0 (v == 0) else ra(dn, md, q);
    dn[2] = 0; md[0][1] = 0; q[0] = 0;
  end
endmodule
