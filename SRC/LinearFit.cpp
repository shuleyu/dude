#include<iostream>
#include<fstream>
#include<sstream>
#include<cstdio>
#include<cstdlib>
#include<vector>
#include<string>
extern "C"{
#include<ASU_tools.h>
}

using namespace std;

int main(int argc, char **argv){

    enum PIenum{FLAG1};
    enum PSenum{infile,gcarcfile,outfile,FLAG2};
    enum Penum{FLAG3};

    /****************************************************************

				Deal with inputs. (Store them in PI,PS,P)

    ****************************************************************/

	if (argc!=4){
		cerr << "In C++: Argument Error!" << endl;
		return 1;
	}

    int int_num,string_num,double_num;

    vector<int> PI;
    vector<string> PS;
    vector<double> P;

    int_num=atoi(argv[1]);
    string_num=atoi(argv[2]);
    double_num=atoi(argv[3]);

	if (FLAG1!=int_num){
		cerr << "In C++: Ints Naming Error !" << endl;
	}
	if (FLAG2!=string_num){
		cerr << "In C++: Strings Naming Error !" << endl;
	}
	if (FLAG3!=double_num){
		cerr << "In C++: Doubles Naming Error !" << endl;
	}

	string tmpstr;
	int tmpint,Cnt;
	double tmpval;

	Cnt=0;
	while (getline(cin,tmpstr)){
		++Cnt;
		stringstream ss(tmpstr);
		if (Cnt<=int_num){
			if (ss >> tmpint && ss.eof()){
				PI.push_back(tmpint);
			}
			else{
				cerr << "In C++: Ints reading Error !" << endl;
				return 1;
			}
		}
		else if (Cnt<=int_num+string_num){
			PS.push_back(tmpstr);
		}
		else if (Cnt<=int_num+string_num+double_num){
			if (ss >> tmpval && ss.eof()){
				P.push_back(tmpval);
			}
			else{
				cerr << "In C++: Doubles reading Error !" << endl;
				return 1;
			}
		}
		else{
			cerr << "In C++: Redundant inputs !" << endl;
			return 1;
		}
	}
	if (Cnt!=int_num+string_num+double_num){
		cerr << "In C++: Not enough inputs !" << endl;
		return 1;
	}

    /****************************************************************

                              Job begin.

    ****************************************************************/

	ifstream fpin;
	int NPTS=filenr(PS[infile].c_str());

	double *Gcarc=new double [NPTS];
	double *Time=new double [NPTS];
	
	// Read from input.
	fpin.open(PS[infile].c_str());

	for (int index=0;index<NPTS;index++){
		fpin >> Gcarc[index] >> Time[index];
	}

	fpin.close();

	// LinearFit.
	
	double slope,intercept;
	linear_fitting(Gcarc,Time,NPTS,&slope,&intercept);


	// Output.
	ofstream fpout;
	int NPTS_gcarc=filenr(PS[gcarcfile].c_str());
	double gcarc;

	fpin.open(PS[gcarcfile].c_str());
	fpout.open(PS[outfile].c_str());
	for (int index=0;index<NPTS_gcarc;index++){
		fpin >> gcarc;
		fpout << gcarc << " " << slope*gcarc+intercept << endl;
	}

	fpin.close();
	fpout.close();
	
	delete [] Gcarc;
	delete [] Time;

    return 0;
}
