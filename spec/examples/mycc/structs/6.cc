struct Node {
    int v;
    struct Node *next;
};

int main() {
    struct Node *head = malloc(sizeof(struct Node));
    head->v = 1;
    head->next = malloc(sizeof(struct Node));
    head->next->v = 2;
    head->next->next = 0;
    
    printf("%d %d\n", head->v, head->next->v);
    
    free(head->next);
    free(head);
    return 0;
}