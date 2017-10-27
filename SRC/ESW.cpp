#include<iostream>
#include<fstream>
#include<sstream>
#include<cstdio>
#include<cstdlib>
#include<vector>
#include<string>
#include<cstring>
#include<cmath>
extern "C"{
#include<ASU_tools.h>
#include<sacio.h>
}

using namespace std;

struct Record{
	string filename,netwk,stnm;
	double radpat,snr,*data,PP,Peak;
};


int main(int argc, char **argv){

    enum PIenum{FLAG1};
    enum PSenum{eq,infile,outfile,badfilelist,stackout,nstaout,FLAG2};
    enum Penum{E1,E2,PREMbias,NBegin,NEnd,Delta,FLAG3};

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

	// Note: Implicit setting 1: SAC files are pre-cut to this time window:
	//       |    PERM+3*TimeMin(E1)  <-->  PREM+3*TimeMax(E2)    |
	//
	//       Implicit setting 2: will normalise each waveform near the PREM
	//       arrival (windowing around FirstOnSet).


	// 1. Read in data.
	ifstream fpin;
	ofstream fpout;
	vector<Record> Data;
	Record tmpdata;
	int MaxLength=200000,rawnpts,nerr,MinNpts=MaxLength,
	    FirstOnSet=(int)((P[PREMbias]-3*P[E1])/P[Delta]),pp;
	float rawdel,rawbeg,maxdata[200000];
	char tmpchar[300];
	double Amplitude;

	fpin.open(PS[infile]);
	fpout.open(PS[badfilelist]);

	while (fpin >> tmpdata.filename >> tmpdata.netwk >> tmpdata.stnm 
		        >> tmpdata.radpat >> tmpdata.snr){

		strcpy(tmpchar,tmpdata.filename.c_str());
		rsac1(tmpchar,maxdata,&rawnpts,&rawbeg,&rawdel,&MaxLength,&nerr,
		      tmpdata.filename.size());


		// Normalize amplitude.
		max_ampf( maxdata+FirstOnSet+(int(P[NBegin]/P[Delta])),
				  (int)((P[NEnd]-P[NBegin])/P[Delta]),&pp);
		tmpdata.Peak=maxdata[FirstOnSet+(int(P[NBegin]/P[Delta]))+pp];
		tmpdata.PP=rawbeg+(FirstOnSet+(int(P[NBegin]/P[Delta]))+pp)*P[Delta];

		Amplitude=fabs(tmpdata.Peak);

		// Check data amplitude.
		if (std::isnan(Amplitude) || Amplitude<=1e-20 ){
			cout << "SAC File: " << tmpdata.filename
			<< " has small amplitude, skipping ... " << endl;
			fpout << tmpdata.netwk << " " << tmpdata.stnm << endl;
			continue;
		}

		// Record this trace.
		tmpdata.data=new double [rawnpts];
		for (int index=0;index<rawnpts;index++){
			tmpdata.data[index]=maxdata[index]/Amplitude;
		}
		Data.push_back(tmpdata);

		MinNpts=MinNpts>rawnpts?rawnpts:MinNpts;
	}

	fpin.close();
	fpout.close();


	// Stack data to make Stack 0.
	double *Stack0=new double [MinNpts];
	double *Std=new double [MinNpts];
	double *Weight=new double [Data.size()];
	int *Shift=new int [Data.size()];
	double **PreStack=new double *[Data.size()];

	for (size_t index=0;index<Data.size();index++){
		PreStack[index]=Data[index].data;
		Weight[index]=Data[index].radpat>0?1:-1;
		Weight[index]*=ramp_function(Data[index].snr,1.0,3.0);
		Shift[index]=0;
	}

	shift_stack(PreStack,Data.size(),MinNpts,0,Shift,1,Weight,Stack0,Std);
	int Elen=(int)((P[E2]-P[E1])/P[Delta]);
	if (max_ampd(Stack0+FirstOnSet+(int(P[E1]/P[Delta])),Elen,&tmpint)==-1)
		for (int index=0;index<MinNpts;index++) Stack0[index]*=-1;


	// Use cross-correlation to calculate shifts and coefficients
	// between Stack 0 and each traces.
	double *CCC=new double[Data.size()];

	for (size_t index=0;index<Data.size();index++){
		CC(Stack0+FirstOnSet+(int(P[E1]/P[Delta])),Elen,
		   Data[index].data+FirstOnSet+(int(P[E1]/P[Delta])),Elen,
		   &Shift[index],&CCC[index]);
	}


	// Stack data to make Stack 1.
	double *Stack1=new double [MinNpts];

	for (size_t index=0;index<Data.size();index++){
		Weight[index]=CCC[index];
		Weight[index]*=ramp_function(Data[index].snr,1.0,3.0);
	}

	shift_stack(PreStack,Data.size(),MinNpts,1,Shift,1,Weight,Stack1,Std);

	// Use cross-correlation to calculate shifts and coefficients
	// between Stack 1 and each traces.
	for (size_t index=0;index<Data.size();index++){
		CC(Stack1+FirstOnSet+(int(P[E1]/P[Delta])),Elen,
		   Data[index].data+FirstOnSet+(int(P[E1]/P[Delta])),Elen,
		   &Shift[index],&CCC[index]);
	}

	// Stack data to make Stack 2.
	double *Stack2=new double [MinNpts];

	for (size_t index=0;index<Data.size();index++){
		Weight[index]=CCC[index];
		Weight[index]*=ramp_function(Data[index].snr,1.0,3.0);
	}

	shift_stack(PreStack,Data.size(),MinNpts,1,Shift,1,Weight,Stack2,Std);


	// Use cross-correlation to calculate coefficients
	// between Stack 2 and each traces.

	int *ShiftDummy=new int [Data.size()];

	for (size_t index=0;index<Data.size();index++){
		CC(Stack1+FirstOnSet+(int(P[E1]/P[Delta])),Elen,
		   Data[index].data+FirstOnSet+(int(P[E1]/P[Delta])),Elen,
		   &ShiftDummy[index],&CCC[index]);
	}


	// Output Stack 0, Stack 1, Stack 2, Std of Stack 2.
	// Normalize the Stack ? or not ? (we are not normalizing Stack for now)
	fpout.open(PS[stackout]);
	fpout << "<Time> <Stack0> <Stack1> <Stack2> <Std>" << endl;
	for (int index=0;index<MinNpts;index++){
		fpout << P[Delta]*(index-FirstOnSet) << " "
		      << Stack0[index] << " " << Stack1[index] << " "
		      << Stack2[index] << " " << Std[index]
			  << endl;
	}
	fpout.close();


	// Output DT,CCC,Weight
	// Notice DTs, Weights are what we used to construct Stack 2.
	//        CCCs are obtained by comparing Stack 2 and each traces.

	fpout.open(PS[outfile]);
	for (size_t index=0;index<Data.size();index++){
		fpout << P[PREMbias] - P[Delta]*Shift[index]
		      << " " << CCC[index] << " " << fabs(Weight[index])
		      << " " << Data[index].PP << " " << Data[index].Peak
			  << endl;
	}
	fpout.close();


	// Output valid NSTA.
	fpout.open(PS[nstaout]);
	fpout << Data.size();
	fpout.close();

	// Output waveform.
// 	for (auto item:Data){
// 		fpout.open(PS[eq]+"_"+item.netwk+"_"+item.stnm+".waveform");
// 		for (int index=0;index<MinNpts;index++)
// 			fpout << index*P[Delta]-3*P[E1] << " " << item.data[index] << endl;
// 		fpout.close();
// 	}


	// Free spaces.
	for (auto item:Data){
		delete [] item.data;
	}
	delete [] Stack0;
	delete [] Stack1;
	delete [] Stack2;
	delete [] Std;
	delete [] Weight;
	delete [] Shift;
	delete [] ShiftDummy;
	delete [] PreStack;
	delete [] CCC;

    return 0;
}
