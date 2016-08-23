#include<iostream>
#include<fstream>
#include<sstream>
#include<cstdio>
#include<cstdlib>
#include<vector>
#include<string>
#include<algorithm>
#include<random>
#include<chrono>
extern "C"{
#include<ASU_tools.h>
}

using namespace std;

struct Record{
	double Dist,Time;
};

int main(int argc, char **argv){

    enum PIenum{FLAG1};
    enum PSenum{infile,outfile,FLAG2};
    enum Penum{TimeMin,TimeMax,DistMin,DistMax,FLAG3};

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
	struct Record tmpdata;
	vector<struct Record> Data;

	fpin.open(PS[infile].c_str());
	for (int index=0;index<NPTS;index++){
		fpin >> tmpdata.Dist >> tmpdata.Time;
		Data.push_back(tmpdata);
	}
	fpin.close();

	unsigned seed=chrono::system_clock::now().time_since_epoch().count();
	shuffle(Data.begin(),Data.end(),default_random_engine(seed));

	ofstream fpout;
	fpout.open(PS[outfile].c_str());
	for (size_t index=0;index<Data.size();index++){
		if ( (Data[index].Time-P[TimeMin])*(Data[index].Time-P[TimeMax]) <0 &&
			 (Data[index].Dist-P[DistMin])*(Data[index].Dist-P[DistMax]) <0 ){

			fpout << Data[index].Time << " " << Data[index].Dist << endl;
			break;
		}
	}
	fpout.close();

    return 0;
}
