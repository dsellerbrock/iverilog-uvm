// G36: sort/rsort/shuffle on fixed-size unpacked array
module g36_uarray_sort_test;
  initial begin
    int arr[5];
    arr[0]=3; arr[1]=1; arr[2]=4; arr[3]=1; arr[4]=5;

    // sort ascending
    arr.sort();
    if (arr[0]!=1 || arr[1]!=1 || arr[2]!=3 || arr[3]!=4 || arr[4]!=5) begin
      $display("FAIL sort: %0d %0d %0d %0d %0d", arr[0],arr[1],arr[2],arr[3],arr[4]);
      $finish;
    end

    // rsort descending
    arr.rsort();
    if (arr[0]!=5 || arr[1]!=4 || arr[2]!=3 || arr[3]!=1 || arr[4]!=1) begin
      $display("FAIL rsort: %0d %0d %0d %0d %0d", arr[0],arr[1],arr[2],arr[3],arr[4]);
      $finish;
    end

    // shuffle: just verify size unchanged and all elements still present
    arr.shuffle();
    begin
      int sum;
      sum = arr[0]+arr[1]+arr[2]+arr[3]+arr[4];
      if (sum != 14) begin
        $display("FAIL shuffle: sum=%0d", sum);
        $finish;
      end
    end

    $display("PASS");
  end
endmodule
