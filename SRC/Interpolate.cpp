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

	// Safeguard for repeating x values.
	for (Cnt=0;Cnt<NPTS;Cnt++){
		fpin >> Gcarc[Cnt] >> Time[Cnt];
		if (Gcarc[Cnt]==Gcarc[Cnt-1]) --Cnt;
	}
	NPTS=Cnt;

	fpin.close();


	int NPTS_gcarc=filenr(PS[gcarcfile].c_str());
	double *gcarc=new double [NPTS_gcarc];


	fpin.open(PS[gcarcfile].c_str());
	for (int index=0;index<NPTS_gcarc;index++){
		fpin >> gcarc[index];
	}

	fpin.close();

	// Interpolate.
	
	double *Arrival=new double [NPTS_gcarc];

	wiginterpd(Gcarc,Time,NPTS,gcarc,Arrival,NPTS_gcarc,1);

	// Make the out-of-range Arrival into nan.
	int PP;
	double DistMax=max_vald(Gcarc,NPTS,&PP);
	double DistMin=min_vald(Gcarc,NPTS,&PP);
	
	for (int index=0;index<NPTS_gcarc;index++){
		if (gcarc[index]<DistMin || gcarc[index]>DistMax){
			Arrival[index]=0.0/0.0;
		}
	}

	// Output.
	ofstream fpout;
	fpout.open(PS[outfile].c_str());
	for (int index=0;index<NPTS_gcarc;index++){
		fpout << Arrival[index] << endl;
	}
	fpout.close();
	
	delete [] Gcarc;
	delete [] Time;
	delete [] gcarc;
	delete [] Arrival;

    return 0;
}
