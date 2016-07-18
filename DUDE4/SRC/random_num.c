#include<stdio.h>
#include<stdlib.h>
#include<time.h>

/***********************************************************
 * This C program provides double random number array.
 * Shule Yu
***********************************************************/

void random_num(double *p,int npts){

    srand(time(NULL));

    long x;
    unsigned long num_bins,num_rand,bin_size,defect;
    int  count,max;
    max=1000000;

    num_bins=(unsigned long)max+1;
    num_rand=(unsigned long)RAND_MAX+1;
    bin_size=num_rand/num_bins;
    defect=num_rand%bin_size;

    for (count=0;count<npts;count++){
        while (num_rand-defect<=(unsigned long)(x=rand()));
        p[count]=1.0*(1+(int)x/bin_size)/max;
    }

    system("sleep 1");
    return;
}

int main(){

    int    count,npts;
    double *p;

    npts=1000;
    p=(double *)malloc(npts*sizeof(double));

    random_num(p,npts);

    // Output.
    for (count=0;count<npts;count++){
        printf("%.7lf\t",p[count]);
    }

    free(p);

    return 0;
}
