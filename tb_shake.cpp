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

#define MAX_SIM_TIME 600
vluint64_t sim_time = 0;
void half_clock();
void LENGTH_GET();
void bram_print(uint32_t *block);
uint32_t bram_core(uint32_t addr, uint32_t din, bool we, bool clk,bool rst,uint32_t *block);

uint32_t bram1[256*4]={0};


VSHAKE_wrapper *dut = nullptr;
VerilatedVcdC *m_trace = nullptr;
uint32_t HASHRAM(uint32_t addr) ;
int bytenum=168;
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
    dut->mode = 0; // SHAKE256
    dut->squeeze_num = 2; // 32 bytes output
    if(dut->mode==0)
        bytenum=168;
    else
        bytenum=136;

    LENGTH_GET();

    half_clock();
    dut->init=1;
    half_clock();
    half_clock();
    dut->init=0;
    uint32_t addr=0;
    bram_print(bram1);
    while (sim_time < MAX_SIM_TIME) {
        addr = dut->addr_perip;
        if(dut->clk==0)
            dut->seed_buffer = HASHRAM(addr);
        bram_core(dut->addr_perip,dut->dout,dut->valid,dut->clk,dut->rst_n,bram1);
        dut->clk ^= 1;
        dut->eval();
        m_trace->dump(sim_time);
        sim_time++;
    }
    bram_print(bram1);
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
		return 0;
	}
	uint32_t data = 0;
	for (int i = 0; i < 4; ++i) {
		if (addr + i < (int)buf.size()) {
			data |= buf[addr + i] << (8 * i);
		} 
	}
	return data;
}

void LENGTH_GET() 
{
    using namespace std;
    ifstream fin("input_string.txt", ios::binary);
    fin.seekg(0, ios::end);
    int len = fin.tellg();
    uint32_t a = len / bytenum;
    uint32_t b = len % bytenum;
    a += 1;
    dut->absorb_num=a & 0xFF;
    dut->last_block_bytes=b & 0xFF;
    cout << "文件长度: " << len << endl;
    cout << "表示为: " << a << "*"<<bytenum<< "+"  << b << endl;
}

uint32_t bram_core(uint32_t addr, uint32_t din, bool we, bool clk,bool rst,uint32_t *block) {
    uint32_t word_index = addr/sizeof(uint32_t);
    if(!rst){
        memset(block,0,sizeof(uint32_t)*256);
        return 0;
    } else if(we && !clk) {
        *(block+word_index) = din;
        return 0;
    } else {
        return block[word_index];
    }
}

void bram_print(uint32_t *block) {
    using namespace std;
    cout << "BRAM内容:" << endl;
    for(int i=0;i<256;i++) {
        cout << hex << setfill('0') << setw(8) << block[i] << " ";
        if((i+1)%8==0)
            cout << endl;
    }
}