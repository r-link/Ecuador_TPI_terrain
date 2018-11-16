#############################################################################
#############################################################################
#############							
#############		Topographic position Index 		
#############		with circular neigborhood in R		
#############							
#############################################################################
#############################################################################

#############################################################################
## code: Roman Link, based on code snippets from the documentation of the  
## terrain() function of the raster package 				   
#############################################################################

library(raster)


## This code uses the focal() function of the raster package to calculate the
## topographic position index for a circular neighborhood with a radius of r 
## raster cells. 
## The results are given either as absolute or normalized values (recommended).

tpic <- function(DEM, r=5, norm=T) {
        # ----- Preparation of the weight matrix -----                                
        m <- matrix(1, nc=(2*r-1), nr=(2*r-1))   # 1. create matrix with the 
                                                 # necessary dimensions
        m[ceiling(0.5 * length(m))] <- 0         # 2. set value of central cell 
                                                 # to zero
        for (y in (1:(2*r-1)))                   # 3. set all cells outside the 
                                                 # specified radius to zero
             {for (x in (1:(2*r-1)))
                  {if (((x-r)^2 + (y-r)^2)>=r^2) m[x,y]<-0
             }
        }
        m[m>0]<-1/sum(m>0)                       # 4. calculate the correspon-
                                                 # ding weight by dividing by  
                                                 # the number of cells within 
                                                 # the moving window
        # ----- Calculation of TPI values ----- 
        f <- focal(DEM, m)                       # calculate means of elevation
                                                 # with focal() using the circu-
                                                 # lar weight matrix m
        tpi<- trim(DEM - f)                      # substract resulting values 
                                                 # from DEM to obtain raster 
                                                 # with TPI values
                                                 # (trim removes NA values at 
                                                 # the plot boundaries)
        #  ----- Output  -----  # if norm == T, the TPI values are normalized                                        
        if (norm == T) {return ( (tpi-mean(values(tpi), na.rm = T))/ 
                                   sd(values(tpi), na.rm = T)) } 
        else {return(tpi)} 
}
