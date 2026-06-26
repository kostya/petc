void test_types() {
    char c = 'A';
    int i = 42;
    long l = 123456L;
    float f = 3.14f;
    double d = 2.71828;
    
    printf("types: %c %d %d %f %f\n", c, i, (int)l, f, d);
}

int main() {
    test_types();
    return 0;
}
