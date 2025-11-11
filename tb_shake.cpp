#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <string>
#include <verilated_vcd_c.h>
#include "VSHAKE_wrapper.h"
#include "VSHAKE_wrapper__Syms.h"

#define MAX_SIM_TIME 200
vluint64_t sim_time = 0;
void half_clock();

VSHAKE_wrapper *dut = nullptr;
VerilatedVcdC *m_trace = nullptr;

int main(int argc, char** argv, char** env) {
    dut = new VSHAKE_wrapper;

    Verilated::traceEverOn(true);
    m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");

    const char* seed="1234";
    uint32_t seed_val = 
        (static_cast<uint8_t>(seed[3]) << 24) |
        (static_cast<uint8_t>(seed[2]) << 16) |
        (static_cast<uint8_t>(seed[1]) << 8)  |
        (static_cast<uint8_t>(seed[0]));
    dut->rst_n = 1;
    half_clock();
    dut->rst_n = 0;
    half_clock();
    dut->rst_n = 1;
    dut->absorb_num=2;
    dut->last_block_bytes=5;
    half_clock();
    dut->seed_buffer=seed_val;
    dut->init=1;
    while (sim_time < MAX_SIM_TIME) {
        
        dut->clk ^= 1;
        dut->eval();
        m_trace->dump(sim_time);
        sim_time++;
    }

    m_trace->close();
    delete dut;
    exit(EXIT_SUCCESS);
} 

void half_clock() {
    dut->clk ^= 1;
    dut->eval();
    m_trace->dump(sim_time);
    sim_time++;
}