%option noyywrap
%option c++

%{
#include <iostream>
#include <vector>
#include <string>
#include <fstream>

using namespace std;

vector<string> headers;
int col_idx = 0;
bool first_entry = true;
bool object_started = false;
bool first_field_in_object = true;
bool array_started = false;

void start_object_if_needed() {
    if (!object_started) {
        if (!first_entry) {
            cout << ",";
        }
        first_entry = false;
        cout << "\n\t{";
        object_started = true;
        first_field_in_object = true;
    }
}

void print_value(const char* val) {
    if (col_idx < headers.size()) {
        if (!first_field_in_object) {
            cout << ",";
        }
        cout << "\n\t\t\"" << headers[col_idx] << "\": \"" << val << "\"";
        first_field_in_object = false;
    }
}
%}

/* Exclusive state for reading the actual bank data */
%x JSON_MODE

/* Matches anything that isn't a comma or newline */
TEXT_DATA [^,\n\r]+

%%

    /* --- HEADERS STATE (INITIAL) --- */

<INITIAL>{TEXT_DATA} {
    headers.push_back(yytext);
}

<INITIAL>, { 
    /* Skip header commas */ 
}

<INITIAL>\r?\n {
    /* Headers done. Open array, switch to data mode. */
    cout << "[";
    array_started = true;
    BEGIN(JSON_MODE);
}

    /* --- DATA STATE (JSON_MODE) --- */

<JSON_MODE>{TEXT_DATA} {
    start_object_if_needed();
    print_value(yytext);
}

<JSON_MODE>, {
    /* Comma in CSV means next field in JSON */
    start_object_if_needed();
    col_idx++;
}

<JSON_MODE>\r?\n {
    /* End of CSV row means end of JSON object */
    if (object_started) {
        cout << "\n\t}";
        object_started = false;
    }
    col_idx = 0; /* Reset for next row */
}

%%

int main(int argc, char** argv) {
    ifstream in;
    if (argc > 1) {
        in.open(argv[1]);
        if (!in.is_open()) {
            perror("File error");
            return 1;
        }
    }
    
    yyFlexLexer lexer(in.is_open() ? &in : &cin);
    lexer.yylex();
    
    /* If the file ended without a newline, close the last object */
    if (object_started) {
        cout << "\n\t}";
    }
    
    /* If the file csv was blank (no data), we don't close the array (it was never opened), we just output an empty array */
    if (array_started) {
        cout << "\n]\n"; // Close the array
    }
    else{
        cout << "[]\n"; // Output empty array
    }
    return 0;
}