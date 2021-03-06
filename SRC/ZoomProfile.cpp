#include<iostream>
#include<fstream>
#include<sstream>
#include<cstdio>
#include<cstring>
#include<cmath>
#include<cstdlib>
#include<vector>
#include<string>
extern "C"{
#include<ASU_tools.h>
#include<sacio.h>
}

#define MAXL 2000000

/*******************************************************************

	This C++ code read in sac files and make a big file for plotting.

*******************************************************************/

using namespace std;

struct Record{
	float *data;
	double BeginTime,Delta,gcarc,phasetime;
	size_t NPTS;
};

int main(int argc, char **argv){

    enum PIenum{NormalizeFlag,FLAG1};
    enum PSenum{infile,plotfile,validnum,FLAG2};
    enum Penum{AmpScale,FLAG3};

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
	string sacfile,MaxFile;
	float rawdata[MAXL],rawbeg,rawdel;
	int rawnpts,maxl=MAXL,nerr;
	double Amplitude,MaxAmplitude=0;
	char sacfile_char[300];
	Record tmp_record;
	vector<Record> Data;


	// read from sac file list.
	fpin.open(PS[infile].c_str());

	while (fpin >> sacfile >> tmp_record.gcarc >> tmp_record.phasetime){

		strcpy(sacfile_char,sacfile.c_str());
		rsac1(sacfile_char,rawdata,&rawnpts,&rawbeg,&rawdel,&maxl,&nerr,
		      sacfile.size());

		Amplitude=amplitude(rawdata,rawnpts);


		// Check data amplitude.
		if (std::isnan(Amplitude) || Amplitude<=1e-20 ){
			cout << "SAC File: " << sacfile
			<< " has small amplitude, skipping ... " << endl;
			continue;
		}

		// Normalize each trace; or noted down maximum amplitude and
		// will do the normalize later.
		if (PI[NormalizeFlag]==1){
			normalize(rawdata,rawnpts);
			MaxAmplitude=1;
		}
		else{
			if (MaxAmplitude<Amplitude){
				MaxAmplitude=Amplitude;
				MaxFile=sacfile;
			}
		}

		// record this trace.
		tmp_record.data=new float [rawnpts];
		for (int index=0;index<rawnpts;index++){
			tmp_record.data[index]=rawdata[index];
		}

		tmp_record.BeginTime=rawbeg;
		tmp_record.Delta=rawdel;
		tmp_record.NPTS=rawnpts;

		Data.push_back(tmp_record);

	}

	fpin.close();

	if (PI[NormalizeFlag]!=1){
		cout << "Amplitudes are anchored to: " << MaxFile << "." << endl;
	}

	// Count how many valid data. (after small amplitude selection)
	ofstream fpout;

	fpout.open(PS[validnum].c_str());
	fpout << Data.size() << endl;
	fpout.close();


	// output the big profile ascii file.
	fpout.open(PS[plotfile].c_str());

	for (auto item: Data){
		double Time=item.BeginTime-item.phasetime;
		for (size_t index=0;index<item.NPTS;index++){

			// Calculate the y-axis position.
			// Do normalize for the option "ALL".
			fpout << Time << " " <<
			item.gcarc-P[AmpScale]*item.data[index]/MaxAmplitude << endl;

			Time+=item.Delta;
		}
		fpout << ">" << endl;
	}

	fpout.close();

	// Free spaces.
	for (auto item: Data){
		delete[] item.data;
	}

    return 0;
}
