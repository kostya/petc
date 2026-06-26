void test_pointers() {
    int x = 42;
    int *p = &x;
    int **pp = &p;
    
    printf("ptr value: %d\n", *p);
    printf("ptr to ptr: %d\n", **pp);
    
    *p = 100;
    printf("modified: %d\n", x);
}

int main() {
	test_pointers();
    return 0;
}