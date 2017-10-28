#include<iostream>
#include<fstream>
#include<sstream>
#include<cstdio>
#include<cstdlib>
#include<cmath>
#include<vector>
#include<string>
extern "C"{
#include<ASU_tools.h>
}

using namespace std;

int main(int argc, char **argv){


    /****************************************************************

                              Job begin.

    ****************************************************************/

	string evlo(argv[1]),evla(argv[2]),az(argv[3]),dist(argv[4]);
	double plo,pla;
	waypoint_az(stod(evlo),stod(evla),stod(az),stod(dist),&plo,&pla);
	printf("%.2lf\t%.2lf\n",plo,pla);

    return 0;
}
