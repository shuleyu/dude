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

    enum PIenum{COMP,FLAG1};
    enum PSenum{infile,outfile,FLAG2};
    enum Penum{evdp,strike,dip,rake,FLAG3};

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

	double tmpaz,tmprayp,tmptakeoff;
	int cmp=(PI[COMP]==1?1:2);

	ifstream fpin;
	ofstream fpout;

	fpin.open(PS[infile].c_str());
	fpout.open(PS[outfile].c_str());

	// read in az and rayp, calculate takeoff.
	// convert az,takeoff angle to rad_pat.
	// output.
	while (fpin >> tmpaz >> tmprayp){
		tmptakeoff=180/M_PI*rayp2takeoff(tmprayp,P[evdp],cmp);
		fpout << tmprayp << " " << tmptakeoff << " "
		      << rad_pat(P[strike],P[dip],P[rake],tmpaz,tmptakeoff,PI[COMP]-1)
			  << endl;
	}
	fpin.close();
	fpout.close();

    return 0;
}
