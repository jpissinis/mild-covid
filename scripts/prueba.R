#loading packages
library(readr)
library(dplyr)
library(tidyverse)
library(ggplot2)
library(lubridate)

#creating the column names
column_names<-c("name","ID","HC","OS","phone","mail","onset",
                "test","ER_discharge_date","disnea","cough","anosmia",
                "disgeusia","throat","diarrea","cephalea","fever","sex",
                "follow_up_start","follow_up_end","cohabitants",
                "cohabitants_symptoms","observations","sat",
                "delayed_discharge","call_dates","n_calls","discharge",
                "SISA_discharge")

#creating the tab from the csv for every month
full_tab<-data.frame()
for (f in list.files("./raw")){
  month_tab<-read_csv(file.path("./raw",as.character(f)))
  month_tab<-month_tab[,4:32]%>%filter(!is.na(DNI))
  month_tab<-set_names(month_tab,column_names)
  full_tab<-bind_rows(full_tab,month_tab)
}
view(full_tab)
#changing the date format
full_tab<-full_tab%>%
  mutate(onset=dmy(onset),
         test=dmy(test),
         ER_discharge_date=dmy(ER_discharge_date),
         follow_up_start=dmy(follow_up_start),
         follow_up_end=dmy(follow_up_end))
view(full_tab)
#Analysis of the symptoms, sex and number of calls
#selecting columns
full_symptoms<-full_tab%>%
  select(sex,disnea,anosmia,disgeusia,throat,diarrea,
         fever,cough,n_calls)

#mean and confidence interval (95%)
ci95<-function(x){qnorm(0.975)*sd(x)/sqrt(length(x-1))}
mean_na_rm<-function(x){mean(x,na.rm=TRUE)}
mean_tab<-full_symptoms%>%summarise_all(mean_na_rm)
ci_95_tab<-tab%>%summarise_all(ci95)

#reshaping the data
tmp<-c("mean","se_95")
summary_tab<-bind_rows(mean_tab,se_95_tab)%>%mutate(var=tmp)
summary_tab<-summary_tab%>%gather("variable","value",-11)%>%
  spread(var,value)

#adding interval limits
summary_tab<-summary_tab%>%
  mutate(lower_95=mean-se_95,upper_95=mean+se_95)
summary_tab
#plotting symptoms
symptoms<-c("diarrea","disnea","throat","fever","disgeusia","anosmia","cough","cephalea")
symptoms_plot<-summary_tab%>%filter(variable%in%symptoms)%>%
  ggplot(aes(reorder(variable,mean),mean,fill=variable))+
  geom_bar(stat="identity")+
  scale_y_continuous(limits=c(0:1))+
  geom_errorbar(aes(x=variable,ymax=upper_95,ymin=lower_95,width=0.5))+
  geom_text(aes(label=round(mean,2)),size=3,vjust=1)+
  xlab("Síntomas")+
  ylab("Proporción")+
  ggtitle("Síntomas al momento de consulta")+
  coord_flip()+
  theme(legend.position = "none")
symptoms_plot

#Analysis of the evolution of the disease
#Selecting columns for disease onset, date of the test and discharge date
evol_tab<-full_tab%>%
  select(ID,onset,test,ER_discharge_date,follow_up_end,
         follow_up_start)%>%
  mutate(time_to_test= test-onset,
         time_ER= ER_discharge_date- test,
         time_to_discharge=follow_up_end - onset,
         time_of_follow_up=follow_up_end-follow_up_start)

#reshaping the data for the plot
evol_tab_reshape<-evol_tab%>%
  gather("variable","days",time_to_test:time_of_follow_up)

#plotting
evol_plot<-evol_tab_reshape%>%
  filter(days>-1)%>%
  group_by(variable)%>%
  count(days)%>%
  mutate(proportion = n/sum(n))%>%
  ggplot(aes(days, proportion, fill = variable))+
  geom_bar(stat="identity")+
  facet_grid(variable~.)+
  scale_x_continuous(limits = c(-1,20), breaks = seq (0,20, by = 2))

evol_plot

#Building the summary table
summary_evol<-evol_tab%>%
  summarise(mean_test=mean(time_to_test,na.rm=TRUE),
            ci_test=qnorm(0.975)*sd(time_to_test,na.rm=TRUE)/(sqrt(sum(!is.na(time_to_test))-1)),
            mean_ER=mean(time_ER, na.rm=TRUE),
            ci_ER=qnorm(0.975)*sd(time_ER, na.rm=TRUE)/(sqrt(sum(!is.na(time_ER))-1)),
            mean_discharge=mean(time_to_discharge,na.rm=TRUE),
            ci_discharge=qnorm(0.975)*sd(time_to_discharge,na.rm=TRUE)/(sqrt(sum(!is.na(time_to_discharge))-1)),
            mean_follow_up=mean(time_of_follow_up,na.rm=TRUE),
            ci_follow_up=qnorm(0.975)*sd(time_of_follow_up,na.rm=TRUE)/(sqrt(sum(!is.na(time_of_follow_up))-1))
            )
#reshaping summary table
summary_evol<-summary_evol%>%
  gather("variable","value")%>%
  separate("variable",c("key","variable"),sep="_")%>%
  spread("key","value")

summary_evol
#plotting the mean patient
mean_evol_plot<-summary_evol%>%
  filter(variable%in%c("discharge","ER","test"))%>%
  mutate(time="x")%>%
  ggplot(aes(time,mean,fill=variable))+
  geom_bar(stat="identity", position="identity",alpha=0.75, width = 0.3)+
  geom_text(aes(y=mean,label = c("Alta","ER","PCR") ,hjust=1.2))+
  geom_text(aes(y=mean, label= round(mean,2),hjust=1.2,vjust=2))+
  theme(legend.position = "none")+
  xlab("")+
  ylab("Días")+
  scale_y_continuous(breaks = seq(0,15, by = 2) )+
  scale_x_discrete(breaks= "")+
  ggtitle("Evolución Promedio")+
  coord_flip()
mean_evol_plot
