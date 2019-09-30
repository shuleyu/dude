#include<iostream>
#include<sstream>
#include<fstream>
#include<cstdio>
#include<cstdlib>
#include<vector>
#include<string>
#include<cstring>
#include<algorithm>
#include<cmath>
extern "C"{
#include<sac.h>
#include<sacio.h>
#include<unistd.h>
#include<gmt/gmt.h>
#include<ASU_tools.h>
}

using namespace std;

struct Bin{
	int X[361];
	int Y[361];
};

int main(int argc, char **argv){

    enum PIenum{FLAG1};
    enum PSenum{infile_st,plotfile,EQ,Tag,FLAG2};
    enum Penum{evla,evlo,evdp,evma,FLAG3};

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
	double tmpaz,tmpbaz,tmpgcp;
	vector<double> Az,Baz,Gcp;
	infile.open(PS[infile_st]);
	while (infile>>tmpaz>>tmpbaz>>tmpgcp){
		Az.push_back(tmpaz);
		Baz.push_back(tmpbaz);
		Gcp.push_back(tmpgcp);
	}
	infile.close();


	// Plot.
	void *API;
	API=GMT_Create_Session("MasterMap",2,0,NULL);


	// Texts.
	char tmpname[L_tmpnam]="tmpfile_XXXXXX";
	char command[200];
	close(mkstemp(tmpname));
	ofstream tmpout{tmpname};
	tmpout << "0 90 25p,1,black 0 CB " + PS[EQ].substr(4,2) + "/" + PS[EQ].substr(6,2) + "/" + PS[EQ].substr(0,4) + " " + PS[EQ].substr(8,2) + ":" + PS[EQ].substr(10,2) << endl;
	tmpout << "0 80 15p,0,black 0 CB " + PS[EQ] + " LAT=" << P[evla] << " LON=" << P[evlo]
	       << " Z=" << P[evdp] << " Mag=" << P[evma] << " NSTA=" << Gcp.size() << endl;
	tmpout << "0 -80 10p,0,black 0 CB " << PS[Tag] << endl;
	tmpout.close();

// 	-Ba10g10/a10g10WSNE -- for positioning texts.
	sprintf(command,"-<%s -JX7.0i/11.69i -R-100/100/-100/100 -F+f+a+j -Xf0.63i -Yf0i -P -N -K ->%s",tmpname,PS[plotfile].c_str());
	GMT_Call_Module(API,"pstext",GMT_MODULE_CMD,command);
	unlink(tmpname);


	// Gcp.
	struct GMT_VECTOR *vec;
	union GMT_UNIVECTOR uniontmp;
	uint64_t par[2];
	int ID,LargestPopulation;
	struct Bin bin;
	char filename[200];
	double *gcp=&Gcp[0];

	for (Cnt=0;Cnt<37;++Cnt){
		bin.X[Cnt]=Cnt*5;
		bin.Y[Cnt]=0;
	}
	for (auto index: Gcp){
		++bin.Y[(int)floor(index/5)];
	}
	LargestPopulation=max_val_i(bin.Y,37,&tmpint);
	if (LargestPopulation<10){
	    LargestPopulation=10;
	}

	par[0]=1;par[1]=Gcp.size();
	vec=(struct GMT_VECTOR *)GMT_Create_Data(API,GMT_IS_VECTOR,GMT_IS_POINT,0,par,NULL,NULL,0,-1,NULL);
	vec->type[0]=(enum GMT_enum_type)GMT_DOUBLE;
	uniontmp.f8=gcp; vec->data[0]=uniontmp;

	ID=GMT_Register_IO(API,GMT_IS_DATASET,GMT_IS_REFERENCE+GMT_VIA_VECTOR,GMT_IS_POINT,GMT_IN,NULL,vec);
	GMT_Encode_ID(API,filename,ID);
	sprintf(command,"-<%s -JX6.26i/2i -R0/180/0/%d -W5 -Ba20f5:\"Epicentral Distance (deg)\":/a%df%d:\"Frequncy\":WSne -Xf1i -Yf7.9366i -L0.5p -G50/50/250 -O -K ->>%s",filename,10*(int)floor(LargestPopulation*1.1)/10,(int)floor(LargestPopulation*1.1)/5,(int)floor(LargestPopulation*1.1)/25,PS[plotfile].c_str());
	GMT_Call_Module(API,"pshistogram",GMT_MODULE_CMD,command);

	// Az.
	double *az=&Az[0];

	for (Cnt=0;Cnt<73;++Cnt){
		bin.X[Cnt]=Cnt*5;
		bin.Y[Cnt]=0;
	}
	for (auto index: Az){
		++bin.Y[(int)floor(index/5)];
	}
	LargestPopulation=max_val_i(bin.Y,73,&tmpint);
	if (LargestPopulation<10){
	    LargestPopulation=10;
	}

	par[0]=1;par[1]=Az.size();
	vec->type[0]=(enum GMT_enum_type)GMT_DOUBLE;
	uniontmp.f8=az; vec->data[0]=uniontmp;

	ID=GMT_Register_IO(API,GMT_IS_DATASET,GMT_IS_REFERENCE+GMT_VIA_VECTOR,GMT_IS_POINT,GMT_IN,NULL,vec);
	GMT_Encode_ID(API,filename,ID);
	sprintf(command,"-<%s -JX6.26i/2i -R0/360/0/%d -W5 -Ba40f5:\"Source Azimuth (deg)\":/a%df%d:\"Frequncy\":WSne -Y-2.7277i -L0.5p -G50/50/250 -O -K ->>%s",filename,10*(int)floor(LargestPopulation*1.1)/10,(int)floor(LargestPopulation*1.1)/5,(int)floor(LargestPopulation*1.1)/25,PS[plotfile].c_str());
	GMT_Call_Module(API,"pshistogram",GMT_MODULE_CMD,command);

	// Baz.
	double *baz=&Baz[0];

	for (Cnt=0;Cnt<73;++Cnt){
		bin.X[Cnt]=Cnt*5;
		bin.Y[Cnt]=0;
	}
	for (auto index: Baz){
		++bin.Y[(int)floor(index/5)];
	}
	LargestPopulation=max_val_i(bin.Y,73,&tmpint);
	if (LargestPopulation<10){
	    LargestPopulation=10;
	}

	par[0]=1;par[1]=Baz.size();
	vec->type[0]=(enum GMT_enum_type)GMT_DOUBLE;
	uniontmp.f8=baz; vec->data[0]=uniontmp;

	ID=GMT_Register_IO(API,GMT_IS_DATASET,GMT_IS_REFERENCE+GMT_VIA_VECTOR,GMT_IS_POINT,GMT_IN,NULL,vec);
	GMT_Encode_ID(API,filename,ID);
	sprintf(command,"-<%s -JX6.26i/2i -R0/360/0/%d -W5 -Ba40f5:\"Station Back Azimuth (deg)\":/a%df%d:\"Frequncy\":WSne -Y-2.7277i -L0.5p -G50/50/250 -O ->>%s",filename,10*(int)floor(LargestPopulation*1.1)/10,(int)floor(LargestPopulation*1.1)/5,(int)floor(LargestPopulation*1.1)/25,PS[plotfile].c_str());
	GMT_Call_Module(API,"pshistogram",GMT_MODULE_CMD,command);


	// Free spaces.
    GMT_Destroy_Data(API,&vec);
	GMT_Destroy_Session(API);
	unlink("gmt.history");

    return 0;
}
