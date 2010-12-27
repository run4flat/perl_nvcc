// This is a simple C program that is designed to test for file renaming,
// performed by perl_nvcc.

#ifdef __cplusplus
	#include <cstdio>
	#include <cstring>
#else
	#include <stdio.h>
	#include <string.h>
#endif

int main() {
//	printf("[[%s]]\n", __FILE__);
	if (strcmp(__FILE__, "t/rename_test.c") == 0) {
		printf("Not renamed");
	}
	else {
		printf("Renamed");
	}
}
