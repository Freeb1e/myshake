// 读取 input_string.txt，接受字节地址参数，输出对应4字节的16进制数据
#include <iostream>
#include <fstream>
#include <vector>
#include <iomanip>
#include <cstdlib>
using namespace std;

int main() {
    uint32_t addr=0;
    cin >> hex >> addr;
	ifstream fin("input_string.txt", ios::binary);
	vector<unsigned char> buf((istreambuf_iterator<char>(fin)), istreambuf_iterator<char>());
	if (addr < 0 || addr >= (int)buf.size()) {
		cout << "00000000" << endl;
		return 0;
	}
	uint32_t data = 0;
	// 假设小端序，越界补0
	for (int i = 0; i < 4; ++i) {
		if (addr + i < (int)buf.size()) {
			data |= buf[addr + i] << (8 * i);
		} // 超出部分自动补0
	}
	cout << hex << setfill('0') << setw(8) << data << endl;
	return 0;
}