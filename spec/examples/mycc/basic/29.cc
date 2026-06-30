union Value {
    int i;
    float f;
    char *s;
};

void test_union() {
    union Value v;
    
    v.i = 42;
    printf("int: %d\n", v.i);
    
    v.f = 3.14f;
    printf("float: %f\n", v.f);
    
    v.s = "hello";
    printf("string: %s\n", v.s);
}

int main() {
    test_union();
    return 0;
}