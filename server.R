server<-shinyServer(function(input, output){
  output$Dat<-renderDataTable({
  	inFile<-input$Data
  if (is.null(inFile)) return(NULL)
  read.table(inFile$datapath,header=TRUE,sep=input$sep)
  })
  
  output$SummaryTable<-renderTable({
  	inFile<-input$Data
  	if (is.null(inFile)) return(NULL)
  	mat<-read.table(inFile$datapath,header=TRUE,sep=input$sep)
  	# Drop item columns
  IMean <- colMeans(mat)
  mat <- mat[,IMean!=1 & IMean!=0]
  # Drop person ID column
  Nitem<-ncol(mat)
  mat <- mat[,-1]
  #Delete perfect scores
  perfect<-NULL
  index<-NULL
  for (i in 1: dim(mat)[1]){
    if (sum(mat[i,])==dim(mat)[2]||sum(mat[i,])==0){
      perfect<-rbind(perfect,mat[i,])
      index<-c(index,i)
    }}
  
  if (is.null(index)==FALSE) {mat<-mat[-index,]}
  
  #Pairwise comparison
  x <- mat
  Nperson <- dim(x)[1]
  NGitem <- dim(x)[2]
  
  B <- matrix(0,NGitem, NGitem)
  
  for(k in 1:Nperson){
    for(i in 1:NGitem){
      for(j in 1:NGitem){
        if(is.na(x[k,i])==FALSE & is.na(x[k,j])==FALSE){
          if(x[k,i]>x[k,j]){B[i,j] <- B[i,j]+1}
        }}}}
  
  B2 <- B %*% B 
  B2[B2==0]<-1/(2*length(mat))
  
  D <- t(B2)/B2
  Logit <- log(D)
  
  G_items=rowMeans(Logit)
  Mean <-mean(G_items)
  SD <-sd(G_items)
 
  # Theta Estimates
  A<-matrix(0,dim(mat)[1],1)
  
  for (i in 1:dim(mat)[1]){
    NEWA=0 
    OLDA=50
    Count=0
    while (abs(OLDA-NEWA)>0.001 & Count<100){
      Count=Count+1
      NEWA=A[i,1]
      p=exp(A[i,1]-G_items)/(1+exp(A[i,1]-G_items))
      Adj=sum(mat[i,]-p)/sum(p*(1-p))
      NEWA=NEWA+Adj
      OLDA=A[i,1]
      A[i,1]=NEWA
    }
  }
  Persons <- A
  
  # Standard errors for person estimates
  
  SE=matrix(0,Nperson,1)
  
  for (i in 1:Nperson){
    sum=0
    for (j in 1: NGitem){
      p=(exp(A[i,1]-G_items[j]))/(1+exp(A[i,1]-G_items[j]))
      sum=sum+p*(1-p)
    }
    SE[i,1]=sqrt(1/sum)
  }
  SE_Persons <- SE
 
   # Reproduce expected person responses based on "A" and "Items"
  
  P.exp=matrix(0,Nperson,NGitem)
  
  for (i in 1:Nperson){
    for (j in 1:NGitem){
      P.exp[i,j]=exp(A[i,1]-G_items[j])/(1+exp(A[i,1]-G_items[j]))
      
    }
  }
  
  #Precision error (Information)
  p=matrix(0,Nperson,NGitem)
  for (i in 1:Nperson){
    for (j in 1:NGitem){
      p[i,j]=exp(A[i,1]-G_items[j])/(1+exp(A[i,1]-G_items[j]))
    }
  }
  Q=p*(1-p)
  
  Items.infor=colSums(Q) #Item information
  I.se<-1/sqrt(Items.infor)# Items S.E.
  
  Person.infor=rowSums(Q) # Person information
  P.se<-1/sqrt(Person.infor)# Person S.E.
  
  # Proportion of variance explained by the model
  SSM <- sum((P.exp - mean(P.exp))^2)
  SSE <- sum(Q)
  modelprop <- round(SSM/(SSM+SSE), digits=2)
  
  # Score residual
  Y=mat-P.exp
  Items.dis=colSums(Y) #Item score discrepancy
  Person.dis=rowSums(Y) #Person score discrepancy
  
  #Infit square residual
  Infit=Y**2
  Items.infit=colSums(Infit)/colSums(Q) # Item infit
  Person.infit=rowSums(Infit)/rowSums(Q) # Person infit
  
  #Outfit square residual
  Z.2=Infit/Q
  Items.outfit=colMeans(Z.2)  # Item outfit
  Person.outfit=rowMeans(Z.2) # Person outfit
  Z=sqrt(Z.2) # Response misfit
  
  # Reliability of item separation
  # 
  SEi=mean(I.se)**2
  SDi=var(G_items)
  Rel_i=round((SDi-SEi)/SDi, digits=2)
  
  # Reliability of person separation
  # 
  SEp=mean(SE)**2
  SDp=var(A)
  Rel_p= round((SDp-SEp)/SDp, digits=2)

  
  m_i <- round(mean(G_items), digits=2)
  sd_i <- round(sd(G_items), digits=2)
  m_infit_i <- round(mean(Items.infit), digits=2)
  sd_infit_i <-round(sd(Items.infit), digits=2)
  m_outfit_i <- round(mean(Items.outfit), digits=2)
  sd_outfit_i <- round(sd(Items.outfit), digits=2)
  m_p <- round(mean(A), digits=2)
  sd_p <- round(sd(A), digits=2)
  m_infit_p <- round(mean(Person.infit), digits=2)
  sd_infit_p <- round(sd(Person.infit), digits=2)
  m_outfit_p <- round(mean(Person.outfit), digits=2)
  sd_outfit_p <- round(sd(Person.outfit), digits=2)
  
  sumtable=data.frame("Statistics" = c("Measure", "N" , "Mean", "SD", "Infit", "Mean", "SD", 
                                       "Outfit","Mean", "SD", "Reliability of separation", "% Variance Explained"),
    "Items"= c("", NGitem, m_i, sd_i, "", m_infit_i, sd_infit_i, "", m_outfit_i, sd_outfit_i, Rel_i, modelprop),
    "Persons"= c("", Nperson, m_p, sd_p, "", m_infit_p, sd_infit_p, "", m_outfit_p, sd_outfit_p, Rel_p, ""))

  sumtable
  })
  
  output$Item<-renderTable({
  	inFile<-input$Data
  	if (is.null(inFile)) return(NULL)
  	mat<-read.table(inFile$datapath,header=TRUE,sep=input$sep)
  	# Drop item columns
  IMean <- colMeans(mat)
  mat <- mat[,IMean!=1 & IMean!=0]
  # Drop person ID column
  Nitem<-ncol(mat)
  mat <- mat[,-1]
  #Delete perfect scores
  perfect<-NULL
  index<-NULL
  for (i in 1: dim(mat)[1]){
    if (sum(mat[i,])==dim(mat)[2]||sum(mat[i,])==0){
      perfect<-rbind(perfect,mat[i,])
      index<-c(index,i)
    }}
   if (is.null(index)==FALSE) {mat<-mat[-index,]}
  #Pairwise comparison
  x <- mat
  Nperson <- dim(x)[1]
  NGitem <- dim(x)[2]
  percent<-NULL
  for (i in 1:NGitem) {percent<-c(percent, sum(x[,i])/Nperson)}
  B <- matrix(0,NGitem, NGitem)
  
  for(k in 1:Nperson){
    for(i in 1:NGitem){
      for(j in 1:NGitem){
        if(is.na(x[k,i])==FALSE & is.na(x[k,j])==FALSE){
          if(x[k,i]>x[k,j]){B[i,j] <- B[i,j]+1}
        }}}}
  
  B2 <- B %*% B 
  B2[B2==0]<-1/(2*length(mat))
  
  D <- t(B2)/B2
  Logit <- log(D)
  
  G_items=rowMeans(Logit)
  Mean <-mean(G_items)
  SD <-sd(G_items)
# Theta Estimates
  
  A<-matrix(0,dim(mat)[1],1)
  
  for (i in 1:dim(mat)[1]){
    NEWA=0 
    OLDA=50
    Count=0
    while (abs(OLDA-NEWA)>0.001 & Count<100){
      Count=Count+1
      NEWA=A[i,1]
      p=exp(A[i,1]-G_items)/(1+exp(A[i,1]-G_items))
      Adj=sum(mat[i,]-p)/sum(p*(1-p))
      NEWA=NEWA+Adj
      OLDA=A[i,1]
      A[i,1]=NEWA
    }
  }
  Persons <- A
  
  # Standard errors for person estimates
  
  SE=matrix(0,Nperson,1)
  
  for (i in 1:Nperson){
    sum=0
    for (j in 1: NGitem){
      p=(exp(A[i,1]-G_items[j]))/(1+exp(A[i,1]-G_items[j]))
      sum=sum+p*(1-p)
    }
    SE[i,1]=sqrt(1/sum)
  }
  SE_Persons <- SE
  # Reproduce expected person responses based on "A" and "Items"
  
  P.exp=matrix(0,Nperson,NGitem)
  
  for (i in 1:Nperson){
    for (j in 1:NGitem){
      P.exp[i,j]=exp(A[i,1]-G_items[j])/(1+exp(A[i,1]-G_items[j]))
      
    }
  }
  
  #Precision error (Information)
  
  p=matrix(0,Nperson,NGitem)
  for (i in 1:Nperson){
    for (j in 1:NGitem){
      p[i,j]=exp(A[i,1]-G_items[j])/(1+exp(A[i,1]-G_items[j]))
    }
  }
  Q=p*(1-p)
  Items.infor=colSums(Q) #Item information
  I.se<-1/sqrt(Items.infor)# Items S.E.
  
  for (i in 1: dim(mat)[2]){
    if (sum(mat[,i])==dim(mat)[1]){
      I.se[i]<-NA
    }
  }
  
  for (i in 1: dim(mat)[2]){
    if (sum(mat[,i])==dim(mat)[1]){
      Items.infit[i]<-NA
    }
  }
  
  # Score residual
  Y=mat-P.exp
  
  #Infit square residual
  Infit=Y**2
  Items.infit=colSums(Infit)/colSums(Q) # Item infit
  
  #Outfit square residual
  Z.2=Infit/Q
  Items.outfit=colMeans(Z.2)  # Item outfit
  Z=sqrt(Z.2) # Response misfit

  #Q1 Statistic
  Categ<-10 #Specify the number of categories
  Obs<-mat
  Obs$ptol<-rowSums(mat)
  interval<-ceiling((max(Obs$ptol)-min(Obs$ptol))/Categ)
  #Take a look at the distribution of the total score
  #hist(Obs$ptol)
  
  #Grouping
  Obs$Groupvar<-NA
  for (i in 1:10){
    for(j in 1:Nperson){
      if (Obs$ptol[j]<(min(Obs$ptol)+i*interval) & Obs$ptol[j]>=(min(Obs$ptol)+(i-1)*interval)){Obs$Groupvar[j]=i}
    }
  }
  #The frequency of persons in each score group
  #table(Obs$Groupvar)
  
  #Expected Scores
  EPred<-as.data.frame(P.exp)
  row.names(EPred)<-row.names(mat)
  EPred$Groupvar<-Obs$Groupvar
  
  #Calculate Q1-number of group is 10
  Q1F<-matrix(0,NGitem,Categ)
  for (i in 1:NGitem){
    for (j in 1:Categ){
      N<-as.data.frame(table(Obs$Groupvar))[j,2]
      O<-sum(Obs[Obs$Groupvar==j,i])/N
      E<-sum(EPred[EPred$Groupvar==j,i])/N
      Q1F[i,j]<-(N*((O-E)^2))/(E*(1-E))
    }
  }
  Q1<-rowSums(Q1F,na.rm=TRUE)
  df<-rep(Categ-1,NGitem)
  Q1.pvalue<-NULL
  for(i in 1:NGitem){Q1.pvalue<-c(Q1.pvalue,pchisq(Q1[i],Categ-1,lower.tail =F))}
  Q1.pvalue<-round(Q1.pvalue, digits = 2)
  for (i in 1:NGitem){
    q<-Q1.pvalue[i]
    Q1.pvalue[i]<-ifelse(q<.01,"<.01",ifelse(q>.99, ">.99",q))
  }
 
  IID<-seq(1,NGitem,by=1)
  ItemTable <- data.frame(percent,G_items,I.se,Items.infit,Items.outfit,Q1,df,Q1.pvalue)
  ItemTable<-cbind(as.factor(IID),ItemTable)
  names(ItemTable)<-c("Item No.","Prop.", "Measure", "Std.err", "Infit", "Outfit", "Q1", "df", "Q1.pvalue")
  ItemTable
   })
  
  output$Person<-renderTable({
  	inFile<-input$Data
  	if (is.null(inFile)) return(NULL)
  	mat<-read.table(inFile$datapath,header=TRUE,sep=input$sep)
     # Drop item columns
  IMean <- colMeans(mat)
  mat <- mat[,IMean!=1 & IMean!=0]
  # Drop person ID column
  PID <- mat[,1]
  mat <- mat[,-1]
  Nitem<-ncol(mat)
  #Delete perfect scores
  perfect<-NULL
  index<-NULL
  for (i in 1: dim(mat)[1]){
    if (sum(mat[i,])==dim(mat)[2]||sum(mat[i,])==0){
      perfect<-rbind(perfect,mat[i,])
      index<-c(index,i)
    }}
  
  if (is.null(index)==FALSE) {mat<-mat[-index,]}
  
  #Pairwise comparison
  x <- mat
  Nperson <- dim(x)[1]
  NGitem <- dim(x)[2]
  percent<-NULL
  for (i in 1:Nperson) {percent<-c(percent, sum(x[i,])/NGitem)}
  B <- matrix(0,NGitem, NGitem)
  for(k in 1:Nperson){
    for(i in 1:NGitem){
      for(j in 1:NGitem){
        if(is.na(x[k,i])==FALSE & is.na(x[k,j])==FALSE){
          if(x[k,i]>x[k,j]){B[i,j] <- B[i,j]+1}
        }}}}
  
  B2 <- B %*% B 
  B2[B2==0]<-1/(2*length(mat))
  
  D <- t(B2)/B2
  Logit <- log(D)
  
  G_items=rowMeans(Logit)
  Mean <-mean(G_items)
  SD <-sd(G_items)
# Theta Estimates
  
  A<-matrix(0,dim(mat)[1],1)
  
  for (i in 1:dim(mat)[1]){
    NEWA=0 
    OLDA=50
    Count=0
    while (abs(OLDA-NEWA)>0.001 & Count<100){
      Count=Count+1
      NEWA=A[i,1]
      p=exp(A[i,1]-G_items)/(1+exp(A[i,1]-G_items))
      Adj=sum(mat[i,]-p)/sum(p*(1-p))
      NEWA=NEWA+Adj
      OLDA=A[i,1]
      A[i,1]=NEWA
    }
  }
  Persons <- round(A, digits = 2)
  
  # Standard errors for person estimates
  
  SE=matrix(0,Nperson,1)
  
  for (i in 1:Nperson){
    sum=0
    for (j in 1: NGitem){
      p=(exp(A[i,1]-G_items[j]))/(1+exp(A[i,1]-G_items[j]))
      sum=sum+p*(1-p)
    }
    SE[i,1]=sqrt(1/sum)
  }
  SE_Persons <- SE
  # Reproduce expected person responses based on "A" and "Items"
  #
  
  P.exp=matrix(0,Nperson,NGitem)
  
  for (i in 1:Nperson){
    for (j in 1:NGitem){
      P.exp[i,j]=exp(A[i,1]-G_items[j])/(1+exp(A[i,1]-G_items[j]))
      
    }
  }
  
  #Precision error (Information)
  
  p=matrix(0,Nperson,NGitem)
  for (i in 1:Nperson){
    for (j in 1:NGitem){
      p[i,j]=exp(A[i,1]-G_items[j])/(1+exp(A[i,1]-G_items[j]))
    }
  }
  Q=p*(1-p)
  
  Person.infor=rowSums(Q) # Person information
  P.se<-1/sqrt(Person.infor)# Person S.E.
    
  # Score residual
  Y=mat-P.exp
  Person.dis=rowSums(Y) #Person score discrepancy
    
  #Infit square residual
  Infit=Y**2
  Person.infit=rowSums(Infit)/rowSums(Q) # Person infit
  
  #Outfit square residual
  Z.2=Infit/Q
  Person.outfit=rowMeans(Z.2) # Person outfit
  Z=sqrt(Z.2) # Response misfit
  
  #Fit category
  MSE.G<-numeric(Nperson)
  for (i in 1:Nperson){
    MSE.G[i]<-ifelse(Person.outfit[i]<1.50 & Person.outfit[i]>=.50,"A",
                     ifelse(Person.outfit[i]<.50,"B",
                            ifelse(Person.outfit[i]<2 & Person.outfit[i]>=1.50,"C",
                                   ifelse(Person.outfit[i]>=2,"D","NA"))))
  }
  
  if (is.null(index)==FALSE){
    perfprop <- rowSums(perfect)/Nitem
    extre <- numeric(length(index))
    for (i in 1: length(index)){
      extre[i] <- ifelse(perfprop[i] == 1, "maximum", ifelse(perfprop[i] == 0, "minimum","Error"))
    }
    extremes <- data.frame(PID[index], perfprop, extre, rep(NA,length(index)), rep(NA,length(index)), rep(NA,length(index)), rep(NA,length(index)))
    names(extremes)<-c("Person ID","Prop.","Measure","Std.err","Infit","Outfit","Fit Category")
  }
  
  if (is.null(index)==FALSE) {PID<-PID[-index]}
  PersonTable <- data.frame(PID, percent, Persons, P.se, Person.infit, Person.outfit, MSE.G)
  names(PersonTable)<-c("Person ID","Prop.","Measure","Std.err","Infit","Outfit","Fit Category")
  
  if (is.null(index)==FALSE) {PersonTable <- rbind(PersonTable, extremes)}
  PersonTable
  })
  
  
  output$HistI<-renderPlot({
  inFile<-input$Data
  if (is.null(inFile)) return(NULL)
  mat<-read.table(inFile$datapath,header=TRUE,sep=input$sep)
  # Drop item columns
  IMean <- colMeans(mat)
  mat <- mat[,IMean!=1 & IMean!=0]
  # Drop person ID column
  Nitem<-ncol(mat)
  mat <- mat[,-1]  
  #Delete perfect scores
  perfect<-NULL
  index<-NULL
  for (i in 1: dim(mat)[1]){
    if (sum(mat[i,])==dim(mat)[2]||sum(mat[i,])==0){
      perfect<-rbind(perfect,mat[i,])
      index<-c(index,i)
    }}
  if (is.null(index)==FALSE) {mat<-mat[-index,]}
  #Pairwise comparison
  x <- mat
  Nperson <- dim(x)[1]
  NGitem <- dim(x)[2]
  B <- matrix(0,NGitem, NGitem)
  for(k in 1:Nperson){
    for(i in 1:NGitem){
      for(j in 1:NGitem){
        if(is.na(x[k,i])==FALSE & is.na(x[k,j])==FALSE){
          if(x[k,i]>x[k,j]){B[i,j] <- B[i,j]+1}
        }}}}
  
  B2 <- B %*% B 
  B2[B2==0]<-1/(2*length(mat))
  D <- t(B2)/B2
  Logit <- log(D)
  G_items=rowMeans(Logit)
  Mean <-mean(G_items)
  SD <-sd(G_items)
# Theta Estimates
  A<-matrix(0,dim(mat)[1],1)
  for (i in 1:dim(mat)[1]){
    NEWA=0 
    OLDA=50
    Count=0
    while (abs(OLDA-NEWA)>0.001 & Count<100){
      Count=Count+1
      NEWA=A[i,1]
      p=exp(A[i,1]-G_items)/(1+exp(A[i,1]-G_items))
      Adj=sum(mat[i,]-p)/sum(p*(1-p))
      NEWA=NEWA+Adj
      OLDA=A[i,1]
      A[i,1]=NEWA
    }
  }
  Persons <- A
  c1<-min(G_items,Persons)
  c2<-max(G_items,Persons)
  hist(G_items,breaks=15,xlim=c(c1-1,c2+1),main="Histogram of Items",xlab="Items")
  })
  
  output$HistP<-renderPlot({
    inFile<-input$Data
    if (is.null(inFile)) return(NULL)
    mat<-read.table(inFile$datapath,header=TRUE,sep=input$sep)
    # Drop item columns
    IMean <- colMeans(mat)
    mat <- mat[,IMean!=1 & IMean!=0]
    # Drop person ID column
    Nitem<-ncol(mat)
    mat <- mat[,-1]  
    #Delete perfect scores
    perfect<-NULL
    index<-NULL
    for (i in 1: dim(mat)[1]){
      if (sum(mat[i,])==dim(mat)[2]||sum(mat[i,])==0){
        perfect<-rbind(perfect,mat[i,])
        index<-c(index,i)
      }}
    if (is.null(index)==FALSE) {mat<-mat[-index,]}
    #Pairwise comparison
    x <- mat
    Nperson <- dim(x)[1]
    NGitem <- dim(x)[2]
    B <- matrix(0,NGitem, NGitem)
    for(k in 1:Nperson){
      for(i in 1:NGitem){
        for(j in 1:NGitem){
          if(is.na(x[k,i])==FALSE & is.na(x[k,j])==FALSE){
            if(x[k,i]>x[k,j]){B[i,j] <- B[i,j]+1}
          }}}}
    
    B2 <- B %*% B 
    B2[B2==0]<-1/(2*length(mat))
    D <- t(B2)/B2
    Logit <- log(D)
    G_items=rowMeans(Logit)
    Mean <-mean(G_items)
    SD <-sd(G_items)
    # Theta Estimates
    A<-matrix(0,dim(mat)[1],1)
    for (i in 1:dim(mat)[1]){
      NEWA=0 
      OLDA=50
      Count=0
      while (abs(OLDA-NEWA)>0.001 & Count<100){
        Count=Count+1
        NEWA=A[i,1]
        p=exp(A[i,1]-G_items)/(1+exp(A[i,1]-G_items))
        Adj=sum(mat[i,]-p)/sum(p*(1-p))
        NEWA=NEWA+Adj
        OLDA=A[i,1]
        A[i,1]=NEWA
      }
    }
    Persons <- A
    c1<-min(G_items,Persons)
    c2<-max(G_items,Persons)
    hist(Persons,breaks=15,xlim=c(c1-1,c2+1))
  })
  
   output$Stem<-renderPlot({
  inFile<-input$Data
  if (is.null(inFile)) return(NULL)
  mat<-read.table(inFile$datapath,header=TRUE,sep=input$sep)
  # Drop item columns
  IMean <- colMeans(mat)
  mat <- mat[,IMean!=1 & IMean!=0]
  # Drop person ID column
  Nitem<-ncol(mat)
  mat <- mat[,-1]  
  #Delete perfect scores
  perfect<-NULL
  index<-NULL
  for (i in 1: dim(mat)[1]){
    if (sum(mat[i,])==dim(mat)[2]||sum(mat[i,])==0){
      perfect<-rbind(perfect,mat[i,])
      index<-c(index,i)
    }}
  if (is.null(index)==FALSE) {mat<-mat[-index,]}
  #Pairwise comparison
  x <- mat
  Nperson <- dim(x)[1]
  NGitem <- dim(x)[2]
  B <- matrix(0,NGitem, NGitem)
  for(k in 1:Nperson){
    for(i in 1:NGitem){
      for(j in 1:NGitem){
        if(is.na(x[k,i])==FALSE & is.na(x[k,j])==FALSE){
          if(x[k,i]>x[k,j]){B[i,j] <- B[i,j]+1}
        }}}}
  
  B2 <- B %*% B 
  B2[B2==0]<-1/(2*length(mat))
  D <- t(B2)/B2
  Logit <- log(D)
  G_items=rowMeans(Logit)
  Mean <-mean(G_items)
  SD <-sd(G_items)
# Theta Estimates
  A<-matrix(0,dim(mat)[1],1)
  for (i in 1:dim(mat)[1]){
    NEWA=0 
    OLDA=50
    Count=0
    while (abs(OLDA-NEWA)>0.001 & Count<100){
      Count=Count+1
      NEWA=A[i,1]
      p=exp(A[i,1]-G_items)/(1+exp(A[i,1]-G_items))
      Adj=sum(mat[i,]-p)/sum(p*(1-p))
      NEWA=NEWA+Adj
      OLDA=A[i,1]
      A[i,1]=NEWA
    }
  }
  Persons <- A
  par(mfrow=c(1,2))
  plot.new()
tmp1 <- capture.output(stem(Persons))
text( 0,1, paste("Persons",paste(tmp1,collapse='\n')), adj=c(0,1), family='mono' )
  plot.new()
tmp2 <- capture.output(stem(G_items))
text( 0,1, paste("Items",paste(tmp2, collapse='\n')), adj=c(0,1), family='mono' )	
  }) 

output$Inttab<-renderTable({
  c1<-c(".50 <= MSE < 1.50","MSE < .50","1.50 <= MSE < 2.00","MSE >= 2.00")
  c2<-c("A","B","C","D")
  c3<-c("Productive for measurement","Less productive for measurement, but not distorting of measures", 
        "Unproductive for measurement, but not distorting of measures", "Unproductive for measurement and distorting of measures")
  tab1<-data.frame(c1,c2,c3)
  names(tab1)<-c("Mean Squared Error (MSE)/Outfit","Fit Categories","Intepretation")
  tab1
})
})
