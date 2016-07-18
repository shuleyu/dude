
        read(*,*)elat1,elon1,elat2,elon2
        x=atan(.993277*tan(elat1/57.29578))
        xlt2=atan(.993277*tan(elat2/57.29578))
        ccc=cos(x)*cos((elon1-elon2)/57.29578)
        xcdist=sin(xlt2)*sin(x)+cos(xlt2)*ccc
        r=57.29578*acos(xcdist)
        write(*,*)r
        stop
        end
