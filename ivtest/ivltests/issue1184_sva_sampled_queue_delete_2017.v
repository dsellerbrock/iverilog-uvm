module issue1184_sva_sampled_queue_delete;
  logic clk = 0;
  int q[$];
  int r[$];
  int d[];
  int aa[int];
  int pass_count, fail_count;

  assert property (@(posedge clk) q[0] == 7) pass_count++; else fail_count++;
  assert property (@(posedge clk) r[0] == 7) pass_count++; else fail_count++;
  assert property (@(posedge clk) d[0] == 7) pass_count++; else fail_count++;
  assert property (@(posedge clk) aa[1] == 7) pass_count++; else fail_count++;

  initial begin
    q.push_back(7);
    r.push_back(7);
    d = new[1];
    d[0] = 7;
    aa[1] = 7;
    #1;
    clk = 1;
    q.delete();
    r.delete(0);
    d.delete();
    aa.delete(1);
    #1;
    $display("ARRAY_LEN=%0d pass=%0d fail=%0d", q.size(), pass_count, fail_count);
    if (pass_count != 4 || fail_count != 0)
      $fatal(1, "sampled queue element lost");
    $finish(0);
  end
endmodule
