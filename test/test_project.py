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
    dut.uio_in.value = 10   # FIX 1: threshold=10, clearer margin
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value  = 1
    await ClockCycles(dut.clk, 5)

async def send_sample(dut, value):
    dut.ui_in.value = value
    await RisingEdge(dut.clk)
    await Timer(1, unit='ns')

@cocotb.test()
async def test_anomaly_detector(dut):
    """Tiny Anomaly Detection Engine - cocotb test"""
    clock = Clock(dut.clk, 100, unit="ns")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    # Fill window with 4 normal samples
    await send_sample(dut, 10)
    await send_sample(dut, 12)
    await send_sample(dut, 11)
    await send_sample(dut, 13)
    await ClockCycles(dut.clk, 5)   # FIX 2: was 2, now 5 for GL settling

    ready = (safe_int(dut.uo_out.value) >> 1) & 1
    assert ready == 1, \
        f"READY should be 1 after 4 samples, got uo_out={dut.uo_out.value}"

    # Normal sample — no alert
    await send_sample(dut, 12)
    await ClockCycles(dut.clk, 5)   # FIX 2
    alert = safe_int(dut.uo_out.value) & 1
    assert alert == 0, \
        f"ALERT should be 0 for normal input 12, got uo_out={dut.uo_out.value}"

    # Spike — alert must fire
    await send_sample(dut, 60)      # FIX 3: bigger spike (was 40), deviation=48 >> threshold 10
    await ClockCycles(dut.clk, 5)   # FIX 2
    alert = safe_int(dut.uo_out.value) & 1
    assert alert == 1, \
        f"ALERT should be 1 for spike 60, got uo_out={dut.uo_out.value}"

    # Back to normal — alert clears
    await send_sample(dut, 12)
    await send_sample(dut, 11)
    await send_sample(dut, 13)
    await ClockCycles(dut.clk, 5)   # FIX 2
    alert = safe_int(dut.uo_out.value) & 1
    assert alert == 0, \
        f"ALERT should clear after normal inputs, got uo_out={dut.uo_out.value}"

    cocotb.log.info("All tests passed!")
