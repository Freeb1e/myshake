#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <string>
#include <verilated_vcd_c.h>
#include "VSHAKE_wrapper.h"
#include "VSHAKE_wrapper__Syms.h"

#include <fstream>
#include <vector>
#include <iomanip>
#include <cstdlib>

#define MAX_SIM_TIME 500
vluint64_t sim_time = 0;
void half_clock();
void LENGTH_GET();
VSHAKE_wrapper *dut = nullptr;
VerilatedVcdC *m_trace = nullptr;
uint32_t HASHRAM(uint32_t addr) ;
int main(int argc, char** argv, char** env) {
    dut = new VSHAKE_wrapper;

    Verilated::traceEverOn(true);
    m_trace = new VerilatedVcdC;
    dut->trace(m_trace, 5);
    m_trace->open("waveform.vcd");
   
    dut->rst_n = 1;
    half_clock();
    dut->rst_n = 0;
    half_clock();
    dut->rst_n = 1;

    LENGTH_GET();

    half_clock();
    dut->init=1;
    uint32_t addr=0;
    while (sim_time < MAX_SIM_TIME) {
        addr = dut->addr_seed;
        if(dut->clk==0)
            dut->seed_buffer = HASHRAM(addr);
        
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

uint32_t HASHRAM(uint32_t addr) 
{
    using namespace std;
	std::ifstream fin("input_string.txt", ios::binary);
	vector<unsigned char> buf((istreambuf_iterator<char>(fin)), istreambuf_iterator<char>());
	if (addr < 0 || addr >= (int)buf.size()) {
		//cout << "00000000" << endl;
		return 0;
	}
	uint32_t data = 0;
	// 假设小端序，越界补0
	for (int i = 0; i < 4; ++i) {
		if (addr + i < (int)buf.size()) {
			data |= buf[addr + i] << (8 * i);
		} // 超出部分自动补0
	}
	//std::cout << std::hex << std::setfill('0') << std::setw(8) << data << std::endl;
	return data;
}

void LENGTH_GET() 
{
    using namespace std;
    ifstream fin("input_string.txt", ios::binary);
    fin.seekg(0, ios::end);
    int len = fin.tellg();
    uint32_t a = len / 168+1;
    uint32_t b = len % 168;
    dut->absorb_num=a & 0xFF;
    dut->last_block_bytes=b & 0xFF;
    cout << "文件长度: " << len << endl;
    cout << "表示为: " << a << "*168 + " << b << endl;
}