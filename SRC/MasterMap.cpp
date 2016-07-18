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
	double tmplon,tmplat,tmpgcp;
	vector<double> Lon,Lat,Gcp;
	infile.open(PS[infile_st]);
	while (infile>>tmplon>>tmplat>>tmpgcp){
		Lon.push_back(tmplon);
		Lat.push_back(tmplat);
		Gcp.push_back(tmpgcp);
	}
	infile.close();

	struct GMT_VECTOR *vec_ST,*vec_EQ,*vec_Path;
	uint64_t par[2];
	void *API;
	int ID;
	double *lon=&Lon[0];
	double *lat=&Lat[0];
	union GMT_UNIVECTOR uniontmp;
	double pathlon[2],pathlat[2];

	// Plot.
	API=GMT_Create_Session("MasterMap",2,0,NULL);

	// Colors and etc.
	const char *colors[]={
		"30/30/30",
		"0/0/250",
		"0/130/255",
		"250/0/250",
		"120/250/250",
		"130/250/0",
		"255/255/0",
		"250/180/0",
		"250/0/0",
		"255/255/255",
	};

	// Coast line.
	char command[200];
	sprintf(command,"-JR%.2lf/7.0i -Rg -Ba0g45/a0g45wsne -Dl -A40000 -Wfaint,100/100/100 -G200/200/200 -Xf0.63i -Y5.5i -P -K ->%s",P[evlo],PS[plotfile].c_str());
	GMT_Call_Module(API,"pscoast",GMT_MODULE_CMD,command);

	// Paths.
	char filename[200];
	par[0]=2;par[1]=2;
	vec_Path=(struct GMT_VECTOR *)GMT_Create_Data(API,GMT_IS_VECTOR,GMT_IS_POINT,0,par,NULL,NULL,0,-1,NULL);
	vec_Path->type[0]=(enum GMT_enum_type)GMT_DOUBLE;
	vec_Path->type[1]=(enum GMT_enum_type)GMT_DOUBLE;

	pathlon[0]=P[evlo];
	pathlat[0]=P[evla];
	for (decltype(Lon.size())index=0;index<Lon.size();++index){
		pathlon[1]=Lon[index];
		pathlat[1]=Lat[index];
		uniontmp.f8=pathlon; vec_Path->data[0]=uniontmp;
		uniontmp.f8=pathlat; vec_Path->data[1]=uniontmp;

		ID=GMT_Register_IO(API,GMT_IS_DATASET,GMT_IS_REFERENCE+GMT_VIA_VECTOR,GMT_IS_POINT,GMT_IN,NULL,vec_Path);
		GMT_Encode_ID(API,filename,ID);
		sprintf(command,"-<%s -J -R -W0.5,%s -O -K ->>%s",filename,colors[(int)floor(Gcp[index]/20)],PS[plotfile].c_str());
		GMT_Call_Module(API,"psxy",GMT_MODULE_CMD,command);
	}

	// Stations.
	par[0]=2;par[1]=Lon.size();
	vec_ST=(struct GMT_VECTOR *)GMT_Create_Data(API,GMT_IS_VECTOR,GMT_IS_POINT,0,par,NULL,NULL,0,-1,NULL);
	vec_ST->type[0]=(enum GMT_enum_type)GMT_DOUBLE;
	vec_ST->type[1]=(enum GMT_enum_type)GMT_DOUBLE;

	uniontmp.f8=lon; vec_ST->data[0]=uniontmp;
	uniontmp.f8=lat; vec_ST->data[1]=uniontmp;
	ID=GMT_Register_IO(API,GMT_IS_DATASET,GMT_IS_REFERENCE+GMT_VIA_VECTOR,GMT_IS_POINT,GMT_IN,NULL,vec_ST);
	GMT_Encode_ID(API,filename,ID);
	sprintf(command,"-<%s -J -R -St0.03i -Gblack -O -K ->>%s",filename,PS[plotfile].c_str());
	GMT_Call_Module(API,"psxy",GMT_MODULE_CMD,command);

	// EQ.
	par[0]=2;par[1]=1;
	vec_EQ=(struct GMT_VECTOR *)GMT_Create_Data(API,GMT_IS_VECTOR,GMT_IS_POINT,0,par,NULL,NULL,0,-1,NULL);
	vec_EQ->type[0]=(enum GMT_enum_type)GMT_DOUBLE;
	vec_EQ->type[1]=(enum GMT_enum_type)GMT_DOUBLE;

	uniontmp.f8=&P[evlo]; vec_EQ->data[0]=uniontmp;
	uniontmp.f8=&P[evla]; vec_EQ->data[1]=uniontmp;
	ID=GMT_Register_IO(API,GMT_IS_DATASET,GMT_IS_REFERENCE+GMT_VIA_VECTOR,GMT_IS_POINT,GMT_IN,NULL,vec_EQ);
	GMT_Encode_ID(API,filename,ID);
	sprintf(command,"-<%s -J -R -Sa0.13i -Gblack -O -K ->>%s",filename,PS[plotfile].c_str());
	GMT_Call_Module(API,"psxy",GMT_MODULE_CMD,command);


	// Texts.
	char tmpname[L_tmpnam]="tmpfile_XXXXXX";
	mkstemp(tmpname);
	ofstream tmpout{tmpname};
	tmpout << "0 90 25p,1,black 0 CB " + PS[EQ].substr(4,2) + "/" + PS[EQ].substr(6,2) + "/" + PS[EQ].substr(0,4) + " " + PS[EQ].substr(8,2) + ":" + PS[EQ].substr(10,2) << endl;
	tmpout << "0 80 15p,0,black 0 CB " + PS[EQ] + " LAT=" << P[evla] << " LON=" << P[evlo]
	       << " Z=" << P[evdp] << " Mag=" << P[evma] << " NSTA=" << Lon.size() << endl;
	for (Cnt=0;Cnt<9;++Cnt){
		tmpout << "5 " << -20-Cnt*5 << " 13p,0,black 0 LM " << 180-(Cnt+1)*20 << " - " << 180-(Cnt)*20 << " deg" << endl;
	}

	tmpout << "0 -80 10p,0,black 0 CB " << PS[Tag] << endl;
	tmpout.close();

// 	-Ba10g10/a10g10WSNE -- for positioning texts.
	sprintf(command,"-<%s -JX7.0i/11.69i -R-100/100/-100/100 -F+f+a+j -Y-5.5i -N -O -K ->>%s",tmpname,PS[plotfile].c_str());
	GMT_Call_Module(API,"pstext",GMT_MODULE_CMD,command);
	unlink(tmpname);

	// Legends.
	pathlon[0]=-20;
	pathlon[1]=-5;
	strcpy(tmpname,"-K");
	for (Cnt=0;Cnt<9;++Cnt){
		pathlat[0]=-20-Cnt*5;
		pathlat[1]=-20-Cnt*5;
		uniontmp.f8=pathlon; vec_Path->data[0]=uniontmp;
		uniontmp.f8=pathlat; vec_Path->data[1]=uniontmp;

		ID=GMT_Register_IO(API,GMT_IS_DATASET,GMT_IS_REFERENCE+GMT_VIA_VECTOR,GMT_IS_POINT,GMT_IN,NULL,vec_Path);
		GMT_Encode_ID(API,filename,ID);
		if (Cnt==8){
			strcpy(tmpname," ");
		}
		sprintf(command,"-<%s -J -R -W0.5,%s -O %s ->>%s",filename,colors[8-Cnt],tmpname,PS[plotfile].c_str());
		GMT_Call_Module(API,"psxy",GMT_MODULE_CMD,command);
	}

	// Free spaces.
    GMT_Destroy_Data(API,&vec_Path);
    GMT_Destroy_Data(API,&vec_ST);
    GMT_Destroy_Data(API,&vec_EQ);
	GMT_Destroy_Session(API);
	unlink("gmt.history");

    return 0;
}
