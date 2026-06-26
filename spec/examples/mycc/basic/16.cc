void test_arrays() {
    int *arr = (int *)malloc(8 * sizeof(int));

    for (int i = 0; i < 8; i++) {
        arr[i] = 0;
    }

    arr[0] = -1;
    *(int *)((char*)arr + 4) = 1;
    arr[2] = 2;
    *(arr + 3) = 3;
    *(&arr[0] + 4) = 4;
    // ((int(*)[8])arr)[0][5] = 5;

    int *p = arr + 7;
    p--;
    *p = 6;

    int *g = arr + 8;
    *(--g) = 7;

    for (int i = 0; i < 8; i++) {
        printf("array %d = %d\n", i, arr[i]);
    }

    free(arr);
}

int main() {
	test_arrays();
    
    return 0;
}
