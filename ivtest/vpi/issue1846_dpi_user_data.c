#include <svdpi.h>
#include <string.h>

static char key_a;
static char key_b;
static int values[2][2] = {{11, 12}, {21, 22}};

int check_user_data(int phase)
{
    svScope scope = svGetScope();
    const char *name = svGetNameFromScope(scope);
    int instance;
    svScope other;

    if (name == NULL)
        return 0;
    if (strcmp(name, "issue1846_dpi_user_data.a") == 0)
        instance = 0;
    else if (strcmp(name, "issue1846_dpi_user_data.b") == 0)
        instance = 1;
    else
        return 0;

    if (phase == 0) {
        if (svGetUserData(scope, &key_a) != NULL
            || svGetUserData(scope, &key_b) != NULL)
            return 0;

        return svPutUserData(scope, &key_a, &values[instance][0]) == 0
            && svPutUserData(scope, &key_b, &values[instance][1]) == 0;
    }

    if (svGetUserData(scope, &key_a) != &values[instance][0]
        || svGetUserData(scope, &key_b) != &values[instance][1])
        return 0;

    other = svGetScopeFromName(instance == 0
                               ? "issue1846_dpi_user_data.b"
                               : "issue1846_dpi_user_data.a");
    if (other == NULL
        || svGetUserData(other, &key_a) != &values[1 - instance][0]
        || svGetUserData(other, &key_b) != &values[1 - instance][1])
        return 0;

    if (svPutUserData(scope, &key_a, NULL) != -1
        || svPutUserData(NULL, &key_a, &values[instance][0]) != -1
        || svGetUserData(NULL, &key_a) != NULL
        || svGetUserData(scope, NULL) != NULL)
        return 0;

    return 1;
}

void (*vlog_startup_routines[])(void) = { 0 };
