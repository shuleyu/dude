#include<iostream>
#include<sstream>
#include<fstream>
#include<cstdio>
#include<cstdlib>
#include<cmath>
#include<vector>
#include<string>
#include<cstring>
#include<algorithm>

/*******************************************************************

	This C++ code deal with station selection based on component:

	For each group of component:
		BHT, BHR, BHZ
		HHT, HHR, HHZ
		THT, THR, THZ
		BHN, BHE, BHZ
		HHN, HHE, HHZ

	each station mush has at least one complete group of component
	to be deemed as qualified and get selected.

*******************************************************************/

using namespace std;

struct record {
	string FileName,NetWork,StaName,Component,Label;
	double lat=0,lon=0;
};

struct info {
	string Label;
	int BHT=0,BHR=0,BHZ=0;
	int HHT=0,HHR=0,HHZ=0;
	int THT=0,THR=0,THZ=0;
	int BHE=0,BHN=0;
	int HHE=0,HHN=0;
};

bool tmpfunc1(const struct record &item1,const struct record &item2){
	return item1.Label<item2.Label;
}

bool tmpfunc2(const struct record &item1,const struct record &item2){
	return item1.Label==item2.Label;
}

bool tmpfunc3(const struct record &item1,const struct record &item2){
	return item1.StaName<item2.StaName;
}

bool tmpfunc4(const struct record &item1,const struct record &item2){
	return (fabs(item1.lon-item2.lon)<0.01 && fabs(item1.lat-item2.lat)<0.01);
}

int main(int argc, char **argv){

    enum PIenum{BH,FLAG1};
    enum PSenum{SACList,FileList,FLAG2};
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
		stringstream ss{tmpstr};
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

	ifstream infile;
	vector<struct record> data;

	infile.open(PS[SACList]);
	struct record item;
	while (infile >> item.FileName >> item.NetWork >> item.StaName
		          >> item.Component >> item.lat >> item.lon){
		for (auto &a:item.Component){
			a=toupper(a);
		}
		item.Label=item.NetWork+"_"+item.StaName;
		data.push_back(item);
	}
	infile.close();


	// Get unique NW_ST by Label.
	// Account for different NetWork + same StaName, while they are actually
	// different stations.
	sort(data.begin(),data.end(),tmpfunc1);
	auto it=unique(data.begin(),data.end(),tmpfunc2);


	// Get unique NW_ST by station location.
	// Account for different NetWork + same StaName, while they are actually
	// the same station.
	// Notice: Distance < ~1.1 km is considered a same station.
	sort(data.begin(),it,tmpfunc3);
	it=unique(data.begin(),it,tmpfunc4);


	// Use metadata to note down NW_ST pairs after selection.
	struct info tmpinfo;
	vector<struct info> metadata;
	for (auto index=data.begin();index<it;index++){
		tmpinfo.Label=index->Label;
		metadata.push_back(tmpinfo);
	}

	// Count components in good NW_ST pairs.
	for (auto &index: metadata){
		for (auto index2:data){
			if (index2.Label==index.Label){
				if (index2.Component=="BHT"){
					++index.BHT;
				}
				if (index2.Component=="BHR"){
					++index.BHR;
				}
				if (index2.Component=="BHZ"){
					++index.BHZ;
				}
				if (index2.Component=="HHT"){
					++index.HHT;
				}
				if (index2.Component=="HHR"){
					++index.HHR;
				}
				if (index2.Component=="HHZ"){
					++index.HHZ;
				}
				if (index2.Component=="THT"){
					++index.THT;
				}
				if (index2.Component=="THR"){
					++index.THR;
				}
				if (index2.Component=="THZ"){
					++index.THZ;
				}
				if (index2.Component=="BHE"){
					++index.BHE;
				}
				if (index2.Component=="BHN"){
					++index.BHN;
				}
				if (index2.Component=="HHE"){
					++index.HHE;
				}
				if (index2.Component=="HHN"){
					++index.HHN;
				}
			}
		}
	}


	// Select Good traces.
	sort(data.begin(),data.end(),tmpfunc1);
	vector<struct record> data_clean;

	for (auto index: metadata){

		if ((index.BHT==1 && index.BHR==1 && index.BHZ==1) ||
			(index.HHT==1 && index.HHR==1 && index.HHZ==1) ||
			(index.THT==1 && index.THR==1 && index.THZ==1) ||
			(index.BHE==1 && index.BHN==1 && index.BHZ==1) ||
			(index.HHE==1 && index.HHN==1 && index.HHZ==1) ){

			if ( index.BHT+index.BHR+index.BHZ
			     +index.HHT+index.HHR+index.HHZ==6){

				if (PI[BH]==1){
					for (auto index2: data){
						if (index2.Label==index.Label &&
							index2.Component[0]=='B'){
							data_clean.push_back(index2);
						}
					}
				}
				else{
					for (auto index2: data){
						if (index2.Label==index.Label &&
							index2.Component[0]=='H'){
							data_clean.push_back(index2);
						}
					}
				}
			}
			else if ( index.BHE+index.BHN+index.BHZ
					  +index.HHE+index.HHN+index.HHZ==6){

				if (PI[BH]==1){
					for (auto index2: data){
						if (index2.Label==index.Label &&
							index2.Component[0]=='B'){
							data_clean.push_back(index2);
						}
					}
				}
				else{
					for (auto index2: data){
						if (index2.Label==index.Label &&
							index2.Component[0]=='H'){
							data_clean.push_back(index2);
						}
					}
				}
			}
			else{
				for (auto index2: data){
					if (index2.Label==index.Label){
						data_clean.push_back(index2);
					}
				}
			}
		}
	}

	// Output good traces.
	ofstream outfile,outfile_T,outfile_R,outfile_Z,outfile_E,outfile_N;
	outfile.open(PS[FileList]);
	outfile_T.open(PS[FileList]+"_T");
	outfile_R.open(PS[FileList]+"_R");
	outfile_Z.open(PS[FileList]+"_Z");
	outfile_E.open(PS[FileList]+"_E");
	outfile_N.open(PS[FileList]+"_N");

	for (auto index: data_clean){
		if (index.Component.substr(2,1)=="T"){
			outfile_T << index.FileName << endl;
		}
		if (index.Component.substr(2,1)=="R"){
			outfile_R << index.FileName << endl;
		}
		if (index.Component.substr(2,1)=="Z"){
			outfile_Z << index.FileName << endl;
		}
		if (index.Component.substr(2,1)=="E"){
			outfile_E << index.FileName << endl;
		}
		if (index.Component.substr(2,1)=="N"){
			outfile_N << index.FileName << endl;
		}
		outfile << index.FileName << endl;
	}

	outfile.close();

    return 0;
}
