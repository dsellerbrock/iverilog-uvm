# Clause 29 combined UDP probe result

Slurm job 3692 on DAN-DESKTOP requested 1 CPU and 1 GiB and completed in 1 second. The job exited 1 because both `-g2017` and `-g2023` rejected the UDP instance-array declaration in `p29_more.sv`:

```text
sorry: UDPs with a range (ua [1:0]) are not supported.
```

This demonstrates a §29.8 instance-array gap, but the combined compile stopped before the mixed-sensitivity, dominance, and three-delay cases could run. Those cases were separated into the follow-up probe in [`../attempt-03-udp-isolated/`](../attempt-03-udp-isolated/).

The tested compiler was from source commit `fb584a251dd4cc91e56a75be662ccd5ee05c64e9`; executable SHA-256 `9760f8c1ab8ad03d64761b257db74ff07603a15c4d44d2bcdba75073f006911c`. Raw scheduler output and both compiler logs are in [`raw-slurm-3692/`](raw-slurm-3692/). No result is claimed for the unrun cases.

The lead filed [#893](https://github.com/dsellerbrock/iverilog-uvm/issues/893) for the instance-array gap. I posted the requested correction specifying Syntax 29-2 and Annex A A.5.4 in [this comment](https://github.com/dsellerbrock/iverilog-uvm/issues/893#issuecomment-6312780892).
