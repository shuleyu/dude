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
#include<SAC_Data.hpp>
extern "C"{
#include<sac.h>
#include<sacio.h>
#include<unistd.h>
#include<gmt/gmt.h>
#include<ASU_tools.h>
}

using namespace std;

int main(int argc, char **argv){

    enum PIenum{PO,filter_flag,normalize_flag,FLAG1};
    enum PSenum{filenames,plotfile,EQ,Tag,COMP,FLAG2};
    enum Penum{evla,evlo,evdp,evma,distmin,distmax,timemin,timemax,f1,f2,delta,FLAG3};

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

	// Read in and process sac data.
	ifstream infile;
	string tmpfilename;
	SAC_Data tmpdata;
	vector<struct SAC_Data> DATA;

	infile.open(PS[filenames]);

	while (infile>>tmpfilename){

		if (!(tmpfilename>>tmpdata)){
			tmpdata.clean();
			continue;
		}

		if (tmpdata.GCARC<P[distmin] || P[distmax]<tmpdata.GCARC){
			tmpdata.clean();
			continue;
		}

		if (!(tmpdata.cut(P[timemin],P[timemax]))){
			tmpdata.clean();
			continue;
		}

		if (!(tmpdata.bwfilter(P[f1],P[f2],PI[filter_flag]))){
			tmpdata.clean();
			continue;
		}

		tmpdata.normalize();

		tmpdata.interpolate(P[delta]);

		tmpdata.normalize();

		DATA.push_back(tmpdata);

	}
	infile.close();


	// Plot.
	void *API;
	API=GMT_Create_Session("BigProfile",2,0,NULL);

	/// texts.
	string PlotOrient=(PI[PO]==1?" ":"-P");
	char tmpname[L_tmpnam]="tmpfile_XXXXXX";
	mkstemp(tmpname);
	ofstream tmpout{tmpname};
	tmpout << "0 138 25p,1,black 0 CB " + PS[EQ].substr(4,2) + "/" + PS[EQ].substr(6,2)
			  + "/" + PS[EQ].substr(0,4) + " " + PS[EQ].substr(8,2) + ":" + PS[EQ].substr(10,2)
			  << " Comp: " << PS[COMP] << endl;
	tmpout << "0 130 15p,0,black 0 CB " + PS[EQ] + " LAT=" << P[evla] << " LON=" << P[evlo]
	       << " Z=" << P[evdp] << " Mag=" << P[evma] << " NSTA=" << DATA.size() << endl;

	switch(PI[filter_flag]){
		case 0:
			tmpout << "0 125 12p,0,black 0 CB No Filter" << endl;
			break;
		case 1:
			tmpout << "0 125 12p,0,black 0 CB Butterworth Filter: " << " < " << P[f2] << " Hz." << endl;
			break;
		case 2:
			tmpout << "0 125 12p,0,black 0 CB Butterworth Filter: " << P[f1] << " ~ " << P[f2] << " Hz." << endl;
			break;
		case 3:
			tmpout << "0 125 12p,0,black 0 CB Butterworth Filter: " << " > " << P[f1] << " Hz." << endl;
			break;
		default:
			;
	}

	

	tmpout << "0 -145 10p,0,black 0 CB " << PS[Tag] << endl;
	tmpout.close();

	char command[300];
// 	-Ba10g10/a10g10WSNE -- for positioning texts.
	sprintf(command,"-<%s -JX7.0i/11.69i -R-150/150/-150/150 -F+f+a+j -Xf0.63i -Yf0i -N %s -K ->%s",tmpname,PlotOrient.c_str(),PS[plotfile].c_str());
	GMT_Call_Module(API,"pstext",GMT_MODULE_CMD,command);
	unlink(tmpname);


	/// waveforms.
	struct GMT_DATASET *DS;
	uint64_t par[4]={1,DATA.size(),0,2};
	int ID,Cnt2;
	char filename[200];
	const double WaveformHeight=1;

	double **TransData=(double **)malloc(DATA.size()*sizeof(double *));
	double avramp=0.0;
	for (decltype(DATA.size()) Cnt=0;Cnt<DATA.size();Cnt++){
		TransData[Cnt]=(double *)malloc(DATA[Cnt].NPTS*sizeof(double));

		// Calculate average amplitude for normalize_flag==1.
		avramp+=DATA[Cnt].Amplitude;
	}
	avramp/=DATA.size();


	DS=(struct GMT_DATASET *)GMT_Create_Data(API,GMT_IS_DATASET,GMT_IS_POINT,0,par,NULL,NULL,0,-1,NULL);
	DS->n_records=0;

	for (decltype(DATA.size()) Cnt=0;Cnt<DATA.size();Cnt++){

		// Calculate data position. Turn signal to xy data.
		if (PI[normalize_flag]==0){
			for (Cnt2=0;Cnt2<DATA[Cnt].NPTS;Cnt2++){
				TransData[Cnt][Cnt2]=DATA[Cnt].GCARC+DATA[Cnt].data[Cnt2]*WaveformHeight;
			}
		}
		else{
			for (Cnt2=0;Cnt2<DATA[Cnt].NPTS;Cnt2++){
				TransData[Cnt][Cnt2]=DATA[Cnt].GCARC+DATA[Cnt].data[Cnt2]*WaveformHeight*DATA[Cnt].Amplitude/avramp;
			}
		}

		DS->n_records+=DATA[Cnt].NPTS;
		DS->table[0]->segment[Cnt]->n_rows=DATA[Cnt].NPTS;
		DS->table[0]->segment[Cnt]->n_columns=2;

		// x,y.
		DS->table[0]->segment[Cnt]->coord[0]=&DATA[Cnt].time[0];
		DS->table[0]->segment[Cnt]->coord[1]=TransData[Cnt];
	}

	ID=GMT_Register_IO(API,GMT_IS_DATASET,GMT_IS_REFERENCE+GMT_VIA_VECTOR,GMT_IS_POINT,GMT_IN,NULL,DS);
	GMT_Encode_ID(API,filename,ID);
	sprintf(command,"-<%s -JX7.0i/-9.352i -R%.2lf/%.2lf/%.2lf/%.2lf -W0.5,black -Xf0.85i -Yf1.169i -O -K ->>%s",filename,P[timemin],P[timemax],P[distmin]-1.0,P[distmax]+1.0,PS[plotfile].c_str());
	GMT_Call_Module(API,"psxy",GMT_MODULE_CMD,command);


	// Basemap.
	sprintf(command,"-J -R -Ba500f100:\"Time after earthquake origin time (sec)\":/a20f4:\"Distance (deg)\":WSne -O ->>%s",PS[plotfile].c_str());
	GMT_Call_Module(API,"psbasemap",GMT_MODULE_CMD,command);

    // Free spaces.
	for (decltype(DATA.size()) Cnt=0;Cnt<DATA.size();Cnt++){
		DS->table[0]->segment[Cnt]->coord[0]=NULL;
		DS->table[0]->segment[Cnt]->coord[1]=NULL;
	}
	GMT_Destroy_Data(API,&DS);
	GMT_Destroy_Session(API);
	unlink("gmt.history");
	for (decltype(DATA.size()) Cnt=0;Cnt<DATA.size();Cnt++){
		free(TransData[Cnt]);
	}
	free(TransData);

    return 0;
}
