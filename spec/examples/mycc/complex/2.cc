typedef enum {
    RED = 0,
    GREEN = 1,
    BLUE = 2,
    YELLOW = 3,
    MAGENTA = 100,
    CYAN = -5,
} Color;

Color global_favorite = BLUE;

Color next_color(Color c) {
    return (Color)((int)c + 1);
}

const char* color_name(Color c) {
    if (c == RED)    return "red";
    if (c == GREEN)  return "green";
    if (c == BLUE)   return "blue";
    if (c == YELLOW) return "yellow";
    if (c == MAGENTA) return "magenta";
    if (c == CYAN)    return "cyan";
    return "unknown";
}

int color_to_hex(Color c) {
    switch (c) {
        case RED:    return 0xFF0000;
        case GREEN:  return 0x00FF00;
        case BLUE:   return 0x0000FF;
        case YELLOW: return 0xFFFF00;
        default:     return 0x000000;
    }
}

Color mix_colors(Color a, Color b) {
    int mixed = ((int)a + (int)b) / 2;
    
    Color result = (Color)mixed;
    return result;
}

void print_all_colors(void) {
    Color palette[] = {RED, GREEN, BLUE, YELLOW, MAGENTA, CYAN};
    int size = sizeof(palette) / sizeof(palette[0]);
    
    for (int i = 0; i < size; i++) {
        printf("%d: %s\n", i, color_name(palette[i]));
    }
}

int is_negative_color(Color c) {
    return (int)c < 0;
}

Color increment_color(Color c) {
    Color result = c;
    result = (Color)((int)result + 1);
    return result;
}

void test_color(Color c) {
    switch (c) {
        case RED:     printf("red\n"); break;
        case GREEN:   printf("green\n"); break;
        case BLUE:    printf("blue\n"); break;
        case YELLOW:  printf("yellow\n"); break;
        case MAGENTA: printf("magenta\n"); break;
        case CYAN:    printf("cyan\n"); break;
        default:      printf("unknown\n");
    }
}

int main() {
    test_color(RED);
    test_color(GREEN);
    test_color(BLUE);
    test_color(YELLOW);
    test_color(MAGENTA);
    test_color(CYAN);
    test_color((Color)42);
    
    Color next = next_color(RED);
    printf("next after RED: %s\n", color_name(next));
    next = next_color(GREEN);
    printf("next after GREEN: %s\n", color_name(next));
    
    Color a = RED, b = RED;
    if (a == b) {
        printf("RED == RED: ok\n");
    }
    
    Color saved = a;
    printf("saved color: %s\n", color_name(saved));
    
    Color mixed = mix_colors(RED, BLUE);
    printf("mixed color: %s\n", color_name(mixed));
    printf("mixed hex: %06X\n", color_to_hex(mixed));
    
    print_all_colors();
    
    printf("global favorite: %s\n", color_name(global_favorite));
    global_favorite = MAGENTA;
    printf("global favorite now: %s\n", color_name(global_favorite));
    
    Color neg = CYAN;
    printf("CYAN is negative: %d\n", is_negative_color(neg));
    printf("RED is negative: %d\n", is_negative_color(RED));
    
    Color inc = increment_color(GREEN);
    printf("incremented GREEN: %s\n", color_name(inc));
    
    return 0;
}