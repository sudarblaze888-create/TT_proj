import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles


async def reset_dut(dut):
    dut.rst_n.value  = 0
    dut.ena.value    = 1
    dut.ui_in.value  = 0
    dut.uio_in.value = 5   # threshold = 5
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value  = 1
    await RisingEdge(dut.clk)


async def send_sample(dut, value):
    dut.ui_in.value = value
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_anomaly_detector(dut):
    """Tiny Anomaly Detection Engine - cocotb test"""

    # Start 10 MHz clock
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    # Reset the DUT
    await reset_dut(dut)

    # ── Load 4 normal samples to fill the window ──────────────────
    await send_sample(dut, 10)
    await send_sample(dut, 12)
    await send_sample(dut, 11)
    await send_sample(dut, 13)

    # One more clock for output to settle
    await RisingEdge(dut.clk)

    # READY bit (uo_out[1]) should now be HIGH
    ready = (int(dut.uo_out.value) >> 1) & 1
    assert ready == 1, f"READY should be 1 after 4 samples, got uo_out={int(dut.uo_out.value)}"

    # ── Normal sample — no alert expected ─────────────────────────
    await send_sample(dut, 12)
    await RisingEdge(dut.clk)
    alert = int(dut.uo_out.value) & 1
    assert alert == 0, f"ALERT should be 0 for normal input 12, got uo_out={int(dut.uo_out.value)}"

    # ── Spike — alert must fire ────────────────────────────────────
    await send_sample(dut, 40)   # deviation >> threshold of 5
    await RisingEdge(dut.clk)
    alert = int(dut.uo_out.value) & 1
    assert alert == 1, f"ALERT should be 1 for spike input 40, got uo_out={int(dut.uo_out.value)}"

    # ── Back to normal — alert should clear ───────────────────────
    await send_sample(dut, 12)
    await send_sample(dut, 11)
    await send_sample(dut, 13)
    await RisingEdge(dut.clk)
    alert = int(dut.uo_out.value) & 1
    assert alert == 0, f"ALERT should clear after normal inputs, got uo_out={int(dut.uo_out.value)}"

    cocotb.log.info("All tests passed!")
