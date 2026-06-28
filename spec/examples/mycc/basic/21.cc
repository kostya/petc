int counter() {
    static int count = 0;
    count = count + 1;
    return count;
}

void test_static() {
    printf("static: %d\n", counter());
    printf("static: %d\n", counter());
    printf("static: %d\n", counter());
}

int main() {
	test_static();
    
    return 0;
}
