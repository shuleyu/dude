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

struct arranged_city{
	string name;
	double gcp;
	double lon;
	double lat;
};

bool tmpfunc1(const struct arranged_city &item1,const struct arranged_city &item2){
	return item1.gcp<item2.gcp;
}


int main(int argc, char **argv){

    enum PIenum{FLAG1};
    enum PSenum{infile_Cities,plotfile,EQ,Tag,FLAG2};
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
	double tmplon,tmplat;
	vector<double> Lon,Lat;
	vector<string> Name;
	struct arranged_city tmparr;
	vector<struct arranged_city> Name_Gcp;

	infile.open(PS[infile_Cities]);
	while (infile>>tmplon>>tmplat && getline(infile,tmpstr)){
		tmparr.name=tmpstr;
		tmparr.gcp=gcpdistance(P[evlo],P[evla],tmplon,tmplat);
		tmparr.lon=tmplon;
		tmparr.lat=tmplat;
		Lon.push_back(tmplon);
		Lat.push_back(tmplat);
		Name.push_back(tmpstr);
		Name_Gcp.push_back(tmparr);
	}
	infile.close();

	sort(Name_Gcp.begin(),Name_Gcp.end(),tmpfunc1);

	struct GMT_VECTOR *vec_ST,*vec_EQ,*vec_Path;
	uint64_t par[2];
	void *API;
	int ID;
	double *lon=&Lon[0];
	double *lat=&Lat[0];
	union GMT_UNIVECTOR uniontmp;
	double pathlon[2],pathlat[2];

	// Plot.
	API=GMT_Create_Session("CityMap",2,0,NULL);

	// Coast line.
	char command[200];
	sprintf(command,"-JR%.2lf/7.0i -Rg -Dl -A40000 -Wfaint,100/100/100 -G150/150/100 -S100/150/200 -X0.63i -Y5.5i -P -K ->%s",P[evlo],PS[plotfile].c_str());
	GMT_Call_Module(API,"pscoast",GMT_MODULE_CMD,command);

	// Distance Contour. (Need to fix the annotation.)
	struct GMT_GRID *G;
	int pad[]={2,2,2,2};

	// * Note Here:  Since gmt -JR projection is buggy.
	// If we use -JR${evlo}, then the grid need to start from 
	// evlo-180 ~ evlo+180, and keep evlo-180 > 0.
	tmpval=lon2360(P[evlo]-180);
	double wesn[]={tmpval,tmpval+360,-90.0,90.0},inc[]={1.0,1.0};

	float dist[361*181],dist_gmt[365*185];
	for (Cnt=0;Cnt<361*181;++Cnt){
		dist[Cnt]=gcpdistance(P[evlo],P[evla],tmpval+1.0*(Cnt/181),1.0*(Cnt%181)-90.0);
	}
	gmttrans_f(dist,361,181,dist_gmt,pad);

	G=(struct GMT_GRID *)GMT_Create_Data(API,GMT_IS_GRID,GMT_IS_SURFACE,GMT_GRID_HEADER_ONLY,NULL,wesn,inc,0,-1,NULL);
	G->data=dist_gmt;
	G->header->grdtype=3;
	G->header->gn=1;
	G->header->gs=1;
	G->header->BC[0]=2;
	G->header->BC[1]=2;
	G->header->BC[2]=3;
	G->header->BC[3]=3;

	char filename[200];
	ID=GMT_Register_IO(API,GMT_IS_GRID,GMT_IS_REFERENCE,GMT_IS_SURFACE,GMT_IN,NULL,G);
	GMT_Encode_ID(API,filename,ID);

	char tmpname[L_tmpnam]="tmpfile_XXXXXX";
	mkstemp(tmpname);
	ofstream tmpout{tmpname};
	for (Cnt=10;Cnt<180;Cnt+=10){
		tmpout << Cnt << " C" << endl;
	}
	tmpout.close();

	sprintf(command,"-<%s -J -R -C%s -A10+f11,1,220/220/220 -Gl%.2lf/%.2lf/%.2lf/%.2lf -S8 -W0.25p,220/220/220 -O -K ->>%s",filename,tmpname,P[evlo],P[evla],P[evlo]+150,P[evla],PS[plotfile].c_str());
	GMT_Call_Module(API,"grdcontour",GMT_MODULE_CMD,command);
	unlink(tmpname);
	G->data=nullptr;

	// Grid line.
	sprintf(command,"-J -R -Ba0g45/a0g45wsne -O -K ->>%s",PS[plotfile].c_str());
	GMT_Call_Module(API,"psbasemap",GMT_MODULE_CMD,command);

	// Paths.
	par[0]=2;par[1]=2;
	vec_Path=(struct GMT_VECTOR *)GMT_Create_Data(API,GMT_IS_VECTOR,GMT_IS_POINT,0,par,NULL,NULL,0,-1,NULL);
	vec_Path->type[0]=(enum GMT_enum_type)GMT_DOUBLE;
	vec_Path->type[1]=(enum GMT_enum_type)GMT_DOUBLE;

	pathlon[0]=P[evlo];
	pathlat[0]=P[evla];
	for (decltype(Lon.size()) index=0;index<Lon.size();++index){
		pathlon[1]=Lon[index];
		pathlat[1]=Lat[index];
		uniontmp.f8=pathlon; vec_Path->data[0]=uniontmp;
		uniontmp.f8=pathlat; vec_Path->data[1]=uniontmp;

		ID=GMT_Register_IO(API,GMT_IS_DATASET,GMT_IS_REFERENCE+GMT_VIA_VECTOR,GMT_IS_POINT,GMT_IN,NULL,vec_Path);
		GMT_Encode_ID(API,filename,ID);
		sprintf(command,"-<%s -J -R -W2,blue -G0 -O -K ->>%s",filename,PS[plotfile].c_str());
		GMT_Call_Module(API,"psxy",GMT_MODULE_CMD,command);
	}

	// Cities.
	par[0]=2;par[1]=Lon.size();
	vec_ST=(struct GMT_VECTOR *)GMT_Create_Data(API,GMT_IS_VECTOR,GMT_IS_POINT,0,par,NULL,NULL,0,-1,NULL);
	vec_ST->type[0]=(enum GMT_enum_type)GMT_DOUBLE;
	vec_ST->type[1]=(enum GMT_enum_type)GMT_DOUBLE;

	uniontmp.f8=lon; vec_ST->data[0]=uniontmp;
	uniontmp.f8=lat; vec_ST->data[1]=uniontmp;
	ID=GMT_Register_IO(API,GMT_IS_DATASET,GMT_IS_REFERENCE+GMT_VIA_VECTOR,GMT_IS_POINT,GMT_IN,NULL,vec_ST);
	GMT_Encode_ID(API,filename,ID);
	sprintf(command,"-<%s -J -R -St0.15i -Gyellow -W0.5p,black -O -K ->>%s",filename,PS[plotfile].c_str());
	GMT_Call_Module(API,"psxy",GMT_MODULE_CMD,command);

	strcpy(tmpname,"tmpfile_XXXXXX");
	mkstemp(tmpname);
	tmpout.open(tmpname);
	for (decltype(Lon.size()) index=0;index<Lon.size();++index){
		tmpout << Lon[index]+5 << " " << Lat[index] << " 11p,5,black 0 ML " << Name[index] << endl;
	}
	tmpout.close();

	sprintf(command,"-<%s -J -R -F+f+a+j -N -O -K ->>%s",tmpname,PS[plotfile].c_str());
	GMT_Call_Module(API,"pstext",GMT_MODULE_CMD,command);
	unlink(tmpname);

	// EQ.
	par[0]=2;par[1]=1;
	vec_EQ=(struct GMT_VECTOR *)GMT_Create_Data(API,GMT_IS_VECTOR,GMT_IS_POINT,0,par,NULL,NULL,0,-1,NULL);
	vec_EQ->type[0]=(enum GMT_enum_type)GMT_DOUBLE;
	vec_EQ->type[1]=(enum GMT_enum_type)GMT_DOUBLE;

	uniontmp.f8=&P[evlo]; vec_EQ->data[0]=uniontmp;
	uniontmp.f8=&P[evla]; vec_EQ->data[1]=uniontmp;
	ID=GMT_Register_IO(API,GMT_IS_DATASET,GMT_IS_REFERENCE+GMT_VIA_VECTOR,GMT_IS_POINT,GMT_IN,NULL,vec_EQ);
	GMT_Encode_ID(API,filename,ID);
	sprintf(command,"-<%s -J -R -Sa0.2i -Gred -W1.5,black -O -K ->>%s",filename,PS[plotfile].c_str());
	GMT_Call_Module(API,"psxy",GMT_MODULE_CMD,command);


	// Texts.
	strcpy(tmpname,"tmpfile_XXXXXX");
	mkstemp(tmpname);
	tmpout.open(tmpname);
	tmpout << "0 90 25p,1,black 0 CB " + PS[EQ].substr(4,2) + "/" + PS[EQ].substr(6,2) + "/" + PS[EQ].substr(0,4) + " " + PS[EQ].substr(8,2) + ":" + PS[EQ].substr(10,2) << endl;
	tmpout << "0 80 15p,0,black 0 CB " + PS[EQ] + " LAT=" << P[evla] << " LON=" << P[evlo]
	       << " Z=" << P[evdp] << " Mag=" << P[evma] << endl;
	tmpout << "5 " << -15 << " 15p,7,black 0 LM " << "Distance (deg)" << endl;
	tmpout << "-40 " << -15 << " 15p,7,black 0 LM " << "City" << endl;
	for (decltype(Name_Gcp.size()) index=0;index<Lon.size();++index){
		tmpout << "-40 " << -20-(int)index*3.5 << " 11p,0,black 0 LM " << Name_Gcp[index].name << endl;
		tmpout << "5 " << -20-(int)index*3.5 << " 11p,0,black 0 LM " << Name_Gcp[index].gcp << endl;
	}

	tmpout << "0 -80 10p,0,black 0 CB " << PS[Tag] << endl;
	tmpout.close();

// 	-Ba10g10/a10g10WSNE -- for positioning texts.
	sprintf(command,"-<%s -JX7.0i/11.69i -R-100/100/-100/100 -F+f+a+j -Y-5.5i -N -O ->>%s",tmpname,PS[plotfile].c_str());
	GMT_Call_Module(API,"pstext",GMT_MODULE_CMD,command);
	unlink(tmpname);

	// Free spaces.
	GMT_Destroy_Data(API,&G);
    GMT_Destroy_Data(API,&vec_Path);
    GMT_Destroy_Data(API,&vec_ST);
    GMT_Destroy_Data(API,&vec_EQ);
	GMT_Destroy_Session(API);
	unlink("gmt.history");

    return 0;
}
