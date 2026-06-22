import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles, Timer


def safe_int(val):
    """Handle X/Z values in gate-level simulation."""
    try:
        return int(val)
    except ValueError:
        return 0


async def reset_dut(dut):
    dut.rst_n.value  = 0
    dut.ena.value    = 1
    dut.ui_in.value  = 0
    dut.uio_in.value = 5
    await ClockCycles(dut.clk, 10)  # extra cycles for GL to settle
    dut.rst_n.value  = 1
    await ClockCycles(dut.clk, 5)


async def send_sample(dut, value):
    dut.ui_in.value = value
    await RisingEdge(dut.clk)
    await Timer(1, unit='ns')


@cocotb.test()
async def test_anomaly_detector(dut):
    """Tiny Anomaly Detection Engine - cocotb test"""

    clock = Clock(dut.clk, 100, unit="ns")   # fixed: unit not units
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    # Fill window with 4 normal samples
    await send_sample(dut, 10)
    await send_sample(dut, 12)
    await send_sample(dut, 11)
    await send_sample(dut, 13)
    await ClockCycles(dut.clk, 2)

    # READY should be high
    ready = (safe_int(dut.uo_out.value) >> 1) & 1
    assert ready == 1, \
        f"READY should be 1 after 4 samples, got {dut.uo_out.value}"

    # Normal sample — no alert
    await send_sample(dut, 12)
    await ClockCycles(dut.clk, 2)
    alert = safe_int(dut.uo_out.value) & 1
    assert alert == 0, \
        f"ALERT should be 0 for normal input 12, got {dut.uo_out.value}"

    # Spike — alert must fire
    await send_sample(dut, 40)
    await ClockCycles(dut.clk, 2)
    alert = safe_int(dut.uo_out.value) & 1
    assert alert == 1, \
        f"ALERT should be 1 for spike 40, got {dut.uo_out.value}"

    # Back to normal — alert clears
    await send_sample(dut, 12)
    await send_sample(dut, 11)
    await send_sample(dut, 13)
    await ClockCycles(dut.clk, 2)
    alert = safe_int(dut.uo_out.value) & 1
    assert alert == 0, \
        f"ALERT should clear after normal inputs, got {dut.uo_out.value}"

    cocotb.log.info("All tests passed!")
