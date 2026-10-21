# Lead-directed §18.5.14 soft-constraint probe

Probe covers soft-constraint dropping, declaration and inheritance priority, `disable soft`, hard and inline constraint priority, and the illegal `randc` soft constraint. Run under both `-g2017` and `-g2023`, with a 20-second process-group timeout for every compile and simulation. Raw results and hashes will be copied here after completion.

## Result

The soft-constraint positive probe passed 9/9 in both editions. The `randc` soft-constraint negative was rejected in both editions with the expected error. See `RESULT.md`.
