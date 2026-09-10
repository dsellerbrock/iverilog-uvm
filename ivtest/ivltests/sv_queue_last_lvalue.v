class last_value;
  int value;
endclass
module test;
  string words[$];
  int values[$];
  real reals[$];
  last_value objects[$];
  last_value a,b;
  int removed;
  task automatic local_queue(input int n);
    int local_values[$];
    local_values.push_back(0);
    local_values[$]=n;
    if(local_values.size()!=1 || local_values[0]!=n) $fatal(1,"automatic queue");
  endtask
  initial begin
    words.push_back("first"); words.push_back("old"); words[$]="new";
    if(words.size()!=2 || words[0]!="first" || words[1]!="new") $fatal(1,"string last");
    values.push_back(10); values.push_back(20); values[$]=30;
    values.push_back(40); values[$]=50;
    if(values[0]!=10 || values[1]!=30 || values[2]!=50) $fatal(1,"changing last");
    removed=values.pop_back(); values[$]=60;
    if(values.size()!=2 || values[0]!=10 || values[1]!=60) $fatal(1,"shrinking last");
    values[$]+=2; values[$]++;
    if(values[0]!=10 || values[1]!=63) $fatal(1,"compound last");
    reals.push_back(1.5); reals.push_back(2.5); reals[$]=3.5;
    if(reals[0]!=1.5 || reals[1]!=3.5) $fatal(1,"real last");
    a=new; b=new; a.value=11; b.value=22;
    objects.push_back(a); objects.push_back(a); objects[$]=b;
    if(objects[0]!=a || objects[1]!=b || objects[1].value!=22) $fatal(1,"object last");
    local_queue(7); local_queue(19);
    $display("PASSED"); $finish(0);
  end
endmodule
