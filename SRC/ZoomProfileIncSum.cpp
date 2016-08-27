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
    enum PSenum{infile,plotfile,validnum,bincount,FLAG2};
    enum Penum{AmpScale,BinSize,BinInc,TimeMin,TimeMax,delta,FLAG3};

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

	// Calc some paratemeter.
	int TotalLength=meshsize(P[TimeMin],P[TimeMax],P[delta],0);
	if (TotalLength>MAXL){
		cout << "MAXL not long enough in BigProfileDistinctSum.out ..." << endl;
		return 1;
	}
	float *AuxSum=new float [TotalLength];


	ifstream fpin;
	string sacfile;
	float rawdata[MAXL],rawbeg,rawdel;
	int rawnpts,maxl=MAXL,nerr,TotalValid=0;
	double Amplitude;
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

		tmp_record.BeginTime=rawbeg;
		tmp_record.NPTS=rawnpts;
		tmp_record.Delta=rawdel;

		TotalValid++;

		// Pad rawdata with zero.
		for (int index=rawnpts;index<MAXL;index++){
			rawdata[index]=0;
		}


		// Shift array to the correct time.
		shift_array_f(rawdata,MAXL,
		              (int)((rawbeg-P[TimeMin]-tmp_record.phasetime)/P[delta]));

		// Record this trace.
		tmp_record.data=new float [TotalLength];

		for (int index=0;index<TotalLength;index++){
			tmp_record.data[index]=rawdata[index];
		}

		Data.push_back(tmp_record);

	}

	fpin.close();


	// Output how many valid data. (after small amplitude selection)
	ofstream fpout;

	fpout.open(PS[validnum].c_str());
	fpout << TotalValid << endl;
	fpout.close();


	// For each bin, find the traces belong to this bin (count),
	// do the stack, note down the maximum amplitude (if required),
	// and push the stack trace into Data_Stack.
	
	vector<Record> Data_Stack;
	int BinCount;
	double MaxAmplitude=0,BinCenter,MaxBin=0;

	fpout.open(PS[bincount].c_str());

	for (BinCenter=0;BinCenter<=180;BinCenter+=P[BinInc]){

		// Initialize the count and the stack.
		BinCount=0;

		for (int index=0;index<TotalLength;index++){
			AuxSum[index]=0;
		}

	
		// Loop through traces to see if they locate in this bin.
		for (auto item:Data){

			if ( BinCenter-P[BinSize]/2<=item.gcarc &&
			     item.gcarc<BinCenter+P[BinSize]/2  ){

				// Stack the new trace.
				for (int index=0;index<TotalLength;index++){
					AuxSum[index]=(AuxSum[index]*BinCount+rawdata[index])
			                      /(BinCount+1);
				}

				BinCount++;
			}
		}

		// If this bin is not empty, measure the amplitude of the stack,
		// and push the stack to Data_Stack.

		if (BinCount!=0){

			// Normalize each trace; or noted down maximum amplitude and
			// will do the normalize later.

			Amplitude=amplitude(AuxSum,TotalLength);

			if (PI[NormalizeFlag]==1){
				normalize(AuxSum,TotalLength);
				MaxAmplitude=1;
			}
			else{
				if (MaxAmplitude<Amplitude){
					MaxAmplitude=Amplitude;
					MaxBin=BinCenter;
				}
			}

			// record this summation.
			tmp_record.data=new float [TotalLength];
			for (int index=0;index<TotalLength;index++){
				tmp_record.data[index]=AuxSum[index];
			}

			tmp_record.BeginTime=P[TimeMin];
			tmp_record.Delta=P[delta];
			tmp_record.NPTS=TotalLength;
			tmp_record.gcarc=BinCenter;

			Data_Stack.push_back(tmp_record);


			// Output Bin Trace count;
			fpout << BinCenter << " " << BinCount << endl;

		}
	}

	fpout.close();

	if (PI[NormalizeFlag]!=1){
		cout << "Amplitudes are anchored to bin centered at : " << MaxBin
		     << " deg" << endl;
	}


	// output the big profile ascii file.
	fpout.open(PS[plotfile].c_str());

	for (auto item: Data_Stack){
		double Time=item.BeginTime;
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
	for (auto item: Data_Stack){
		delete[] item.data;
	}
	delete [] AuxSum;

    return 0;
}
