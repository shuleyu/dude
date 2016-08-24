#include<iostream>
#include<fstream>
#include<sstream>
#include<cstdio>
#include<cstdlib>
#include<vector>
#include<string>
#include<algorithm>
extern "C"{
#include<ASU_tools.h>
}

using namespace std;

// Template used for sort according to indexes.
template <typename T>
vector<size_t> sort_indexes(const vector<T> &v) {

	// 	initialize original index locations.
	vector<size_t> idx(v.size());
    for (size_t index=0;index<v.size();index++){
        idx[index]=index;
    }
// 	iota(idx.begin(),idx.end(),0);

	// sort indexes based on comparing values in v.
	auto f=[&v](size_t i1, size_t i2) {return v[i1] < v[i2];};
	sort(idx.begin(), idx.end(),f);

	return idx;
}

int main(int argc, char **argv){

    enum PIenum{FLAG1};
    enum PSenum{infile,outfile,FLAG2};
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
	vector<double> TravelDist,TravelTime;
	double tmptime,tmpdist;

	// Read in data.
	fpin.open(PS[infile].c_str());
	for (int index=0;index<NPTS;index++){
		fpin >> tmpdist >> tmptime;
		TravelDist.push_back(tmpdist);
		TravelTime.push_back(tmptime);
	}

	fpin.close();


	// Sort dist and time according to time increasing order, when
	// time serie is in decreasing order (which indicate no triplication);
	// this is for ScSScS, ScSScSScS, etc.
	auto f=[](const double &d1,const double &d2){return d1>d2;};
	if (is_sorted(TravelTime.begin(),TravelTime.end(),f)){
		auto Index_Time=sort_indexes(TravelTime);
		sort(TravelTime.begin(),TravelTime.end());
		vector<double> aux(TravelDist.size());
		size_t index=0;
		for (auto i:Index_Time){
			aux[index]=TravelDist[i];
			index++;
		}
		index=0;
		for (auto i:aux){
			TravelDist[index]=i;
			index++;
		}
	}


	// Find triplications in travel time curve in terms of Distance series
	// change trend.
	vector<vector<double>> TriDist;
	vector<vector<double>> TriTime;
	int LastIndex=0;
	for (int index=1;index<NPTS-1;index++){
		if ( ( TravelDist[index-1]>TravelDist[index] &&
		 	   TravelDist[index+1]>TravelDist[index]  ) ||
			 ( TravelDist[index-1]<TravelDist[index] &&
			   TravelDist[index+1]<TravelDist[index]  ) ){

			// sort each section into dist ascending order.
			vector<double> tmpvecdist(TravelDist.begin()+LastIndex,
			                      TravelDist.begin()+index+1);
			auto Index=sort_indexes(tmpvecdist);
			size_t index2=0;
			for (auto i:Index){
				tmpvecdist[index2]=TravelDist[LastIndex+i];
				index2++;
			}
			TriDist.push_back(tmpvecdist);

			// sort each section time accordingly.
			vector<double> tmpvectime(Index.size());
			index2=0;
			for (auto i:Index){
				tmpvectime[index2]=TravelTime[LastIndex+i];
				index2++;
			}
			TriTime.push_back(tmpvectime);

			LastIndex=index;

			// Small fix for exotic phases "reflect" at 180 deg.
			if (TravelDist[LastIndex]>=174){
				break;
			}
		}
	}

	// Small fix for exotic phases "reflect" at 180 deg.
	// Add the last section, if there's no "reflect" section.
	if (TravelDist[LastIndex]<174){

		vector<double> tmpvecdist(TravelDist.begin()+LastIndex,TravelDist.end());
		auto Index=sort_indexes(tmpvecdist);
		size_t index2=0;
		for (auto i:Index){
			tmpvecdist[index2]=TravelDist[LastIndex+i];
			index2++;
		}
		TriDist.push_back(tmpvecdist);

		vector<double> tmpvectime(Index.size());
		index2=0;
		for (auto i:Index){
			tmpvectime[index2]=TravelTime[LastIndex+i];
			index2++;
		}
		TriTime.push_back(tmpvectime);
	}


	// For each unique distance data point, seek (interpolate) the first
	// arrival in different sections.
	// Output to a two column dist-time file.

	ofstream fpout;

	sort(TravelDist.begin(),TravelDist.end());
	auto it_end=unique(TravelDist.begin(),TravelDist.end());

	// Loop through unique dist data point.
	fpout.open(PS[outfile].c_str());
	for (auto it=TravelDist.begin();it<it_end;it++){

		double LeastTime=1/0.0;

		for (size_t index=0;index<TriDist.size();index++){

			auto item1=TriDist[index];
			auto item2=TriTime[index];

			// Find the section contains this dist value.
			if ( ( (*(item1.begin()))-(*it) ) *
				 ( (*(item1.end()-1))-(*it) ) <=0  ){

				double *x=&item1[0];
				double *y=&item2[0];

				// Interpolate in this section, get the travel time
				// for this dist value within this section.
				double ThisTime,ThisDist=(*it);
				wiginterpd(x,y,item1.size(),&ThisDist,&ThisTime,1,1);


				// Choose the smallest travel time.
				if (LeastTime>ThisTime){
					LeastTime=ThisTime;
				}
			}
		}

		fpout << *it << " " << LeastTime << endl;
	}

	fpout.close();

    return 0;
}
