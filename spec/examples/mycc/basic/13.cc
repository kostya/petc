void test_pointers() {
    int x = 5;
    int *y = &x;
    *y = 10;
    printf("x val = %d\n", x);
}

int main() {
	test_pointers();
    return 0;
}