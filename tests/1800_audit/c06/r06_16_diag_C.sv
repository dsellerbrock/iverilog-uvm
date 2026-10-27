module t;
  string arr[3] = '{"a", "bb", "ccc"}; string d[]; string aa[string]; string q[$]; string n; int k = 2;
  initial begin
    $display("C len var=%0d const=%0d", arr[k].len(), arr[2].len());
    $display("C getc=%0d idx=%0d substr='%s' cmp=%0d upper='%s'", arr[2].getc(1), arr[2][1], arr[2].substr(0,1), arr[2].compare("ccc"), arr[2].toupper());
    arr[1][0] = "B"; $display("C idxwr arr1='%s'", arr[1]);
    n = arr[2]; $display("C copy len=%0d", n.len());
    d = new[2]; d[0] = "abc"; $display("C dyn len=%0d", d[0].len());
    aa["k"] = "abcd"; $display("C assoc len=%0d", aa["k"].len());
    q.push_back("wxyz"); $display("C queue len=%0d", q[0].len());
  end
endmodule
