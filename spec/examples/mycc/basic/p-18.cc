void test_arrays() {
    int arr[5] = {1, 2, 3, 4, 5};
    int sum = 0;
    
    for (int i = 0; i < 5; i++) {
        sum = sum + arr[i];
    }
    printf("array sum: %d\n", sum);
}

int main() {
	test_arrays();
    
    return 0;
}