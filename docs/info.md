<!--- docs/info.md --->

## How it works

This is a **Tiny Anomaly Detection Engine** implemented in digital hardware.

It maintains a 4-sample sliding window of 8-bit sensor readings. Every clock cycle it:

1. Updates the shift register with the new input sample
2. Recomputes the running sum (adds new sample, drops oldest)
3. Calculates the mean as `sum >> 2` (integer divide by 4, no divider needed)
4. Computes the absolute deviation: `|new_sample − mean|`
5. Compares deviation against a programmable threshold (set via `uio` pins)
6. Raises `ALERT` if deviation exceeds the threshold

The design uses only shift registers, adders, and a comparator — no multipliers,
no ROM, no complex logic. It fits comfortably in a 1×1 tile on SKY130.
